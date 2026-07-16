const std = @import("std");
const owned = @import("memory.zig");
const zig_parser = @import("zig_parser.zig");

pub const schema = "zgraphy.zig-resolution.v1";
pub const schema_version: u32 = 1;
pub const resolver_version = "zig-ast-scope-import-v1";

pub const Status = enum(u8) {
    resolved,
    ambiguous,
    unresolved,
};

pub const CandidateReason = enum(u8) {
    same_file,
    import_member,
    binding_flow,
};

pub const Candidate = struct {
    resolution_index: usize,
    target_path: []const u8,
    target_name: []const u8,
    reason: CandidateReason,
};

pub const CallResolution = struct {
    source_path: []const u8,
    enclosing_declaration: []const u8,
    callee: []const u8,
    call_span: zig_parser.Span,
    status: Status,
    candidate_start: usize,
    candidate_count: usize,
};

pub const Summary = struct {
    calls: usize = 0,
    resolved: usize = 0,
    ambiguous: usize = 0,
    unresolved: usize = 0,
    candidates: usize = 0,
};

pub const Result = struct {
    allocator: std.mem.Allocator,
    resolutions: []CallResolution,
    candidates: []Candidate,
    summary: Summary,
    fingerprint: [32]u8,

    pub fn deinit(self: *Result) void {
        for (self.resolutions) |resolution| {
            self.allocator.free(resolution.source_path);
            if (resolution.enclosing_declaration.len > 0) self.allocator.free(resolution.enclosing_declaration);
            self.allocator.free(resolution.callee);
        }
        self.allocator.free(self.resolutions);
        for (self.candidates) |candidate| {
            self.allocator.free(candidate.target_path);
            self.allocator.free(candidate.target_name);
        }
        self.allocator.free(self.candidates);
        self.resolutions = &.{};
        self.candidates = &.{};
    }

    pub fn findCall(
        self: *const Result,
        source_path: []const u8,
        enclosing_declaration: []const u8,
        callee: []const u8,
    ) ?*const CallResolution {
        for (self.resolutions, 0..) |resolution, index| {
            if (std.mem.eql(u8, resolution.source_path, source_path) and
                std.mem.eql(u8, resolution.enclosing_declaration, enclosing_declaration) and
                std.mem.eql(u8, resolution.callee, callee)) return &self.resolutions[index];
        }
        return null;
    }

    pub fn candidatesFor(self: *const Result, resolution: *const CallResolution) []const Candidate {
        return self.candidates[resolution.candidate_start..][0..resolution.candidate_count];
    }
};

pub const Options = struct {
    max_files: usize = 100_000,
    max_symbols: usize = 1_000_000,
    max_resolutions: usize = 1_000_000,
    max_candidates: usize = 4_000_000,
    parser: zig_parser.Options = .{},
};

pub const Corpus = struct {
    allocator: std.mem.Allocator,
    options: Options,
    parsed_files: std.ArrayList(zig_parser.Result) = .empty,

    pub fn init(allocator: std.mem.Allocator, options: Options) !Corpus {
        if (options.max_files == 0 or options.max_symbols == 0 or options.max_resolutions == 0 or options.max_candidates == 0) {
            return error.InvalidZigResolutionOptions;
        }
        return .{ .allocator = allocator, .options = options };
    }

    pub fn deinit(self: *Corpus) void {
        for (self.parsed_files.items) |*parsed| parsed.deinit();
        self.parsed_files.deinit(self.allocator);
    }

    pub fn addSource(self: *Corpus, path: []const u8, source: []const u8) !void {
        for (self.parsed_files.items) |parsed| if (std.mem.eql(u8, parsed.path, path)) return error.DuplicateZigSourcePath;
        if (self.parsed_files.items.len >= self.options.max_files) return error.ZigResolutionFileLimitExceeded;
        var parsed = try zig_parser.parse(self.allocator, path, source, self.options.parser);
        errdefer parsed.deinit();
        try self.parsed_files.append(self.allocator, parsed);
    }

    pub fn parsedForPath(self: *const Corpus, path: []const u8) ?*const zig_parser.Result {
        for (self.parsed_files.items, 0..) |parsed, index| {
            if (std.mem.eql(u8, parsed.path, path)) return &self.parsed_files.items[index];
        }
        return null;
    }

    pub fn resolve(self: *const Corpus) !Result {
        var symbol_count: usize = 0;
        var call_count: usize = 0;
        for (self.parsed_files.items) |parsed| {
            symbol_count = std.math.add(usize, symbol_count, parsed.declarations.len) catch return error.ZigResolutionSymbolLimitExceeded;
            call_count = std.math.add(usize, call_count, parsed.calls.len) catch return error.ZigResolutionCallLimitExceeded;
        }
        if (symbol_count > self.options.max_symbols) return error.ZigResolutionSymbolLimitExceeded;
        if (call_count > self.options.max_resolutions) return error.ZigResolutionCallLimitExceeded;

        const file_order = try owned.slice(usize, self.allocator, self.parsed_files.items.len);
        defer self.allocator.free(file_order);
        for (file_order, 0..) |*index, value| index.* = value;
        std.mem.sort(usize, file_order, self, lessThanFileIndex);

        var resolutions: std.ArrayList(CallResolution) = .empty;
        errdefer deinitResolutions(self.allocator, &resolutions);
        var candidates: std.ArrayList(Candidate) = .empty;
        errdefer deinitCandidates(self.allocator, &candidates);
        var summary = Summary{};

        for (file_order) |file_index| {
            const parsed = &self.parsed_files.items[file_index];
            for (parsed.calls) |call| {
                var targets: std.ArrayList(CandidateTarget) = .empty;
                defer targets.deinit(self.allocator);
                try self.collectCallCandidates(parsed, &call, &targets);
                std.mem.sort(CandidateTarget, targets.items, {}, lessThanCandidateTarget);

                const resolution_index = resolutions.items.len;
                const candidate_start = candidates.items.len;
                const candidate_end = std.math.add(usize, candidate_start, targets.items.len) catch return error.ZigResolutionCandidateLimitExceeded;
                if (candidate_end > self.options.max_candidates) return error.ZigResolutionCandidateLimitExceeded;
                for (targets.items) |target| {
                    const target_path = try owned.copy(u8, self.allocator, target.target_path);
                    errdefer self.allocator.free(target_path);
                    const target_name = try owned.copy(u8, self.allocator, target.target_name);
                    errdefer self.allocator.free(target_name);
                    try candidates.append(self.allocator, .{
                        .resolution_index = resolution_index,
                        .target_path = target_path,
                        .target_name = target_name,
                        .reason = target.reason,
                    });
                }
                const status: Status = switch (targets.items.len) {
                    0 => .unresolved,
                    1 => .resolved,
                    else => .ambiguous,
                };
                const source_path = try owned.copy(u8, self.allocator, parsed.path);
                errdefer self.allocator.free(source_path);
                const enclosing = if (call.enclosing_declaration.len > 0) try owned.copy(u8, self.allocator, call.enclosing_declaration) else "";
                errdefer if (enclosing.len > 0) self.allocator.free(enclosing);
                const callee = try owned.copy(u8, self.allocator, call.callee);
                errdefer self.allocator.free(callee);
                try resolutions.append(self.allocator, .{
                    .source_path = source_path,
                    .enclosing_declaration = enclosing,
                    .callee = callee,
                    .call_span = call.span,
                    .status = status,
                    .candidate_start = candidate_start,
                    .candidate_count = targets.items.len,
                });
                summary.calls += 1;
                summary.candidates += targets.items.len;
                switch (status) {
                    .resolved => summary.resolved += 1,
                    .ambiguous => summary.ambiguous += 1,
                    .unresolved => summary.unresolved += 1,
                }
            }
        }

        const resolution_slice = try resolutions.toOwnedSlice(self.allocator);
        errdefer {
            var values = std.ArrayList(CallResolution).fromOwnedSlice(resolution_slice);
            deinitResolutions(self.allocator, &values);
        }
        const candidate_slice = try candidates.toOwnedSlice(self.allocator);
        errdefer {
            var values = std.ArrayList(Candidate).fromOwnedSlice(candidate_slice);
            deinitCandidates(self.allocator, &values);
        }
        var result = Result{
            .allocator = self.allocator,
            .resolutions = resolution_slice,
            .candidates = candidate_slice,
            .summary = summary,
            .fingerprint = resolutionFingerprint(resolution_slice, candidate_slice, summary),
        };
        errdefer result.deinit();
        try validate(&result);
        try self.validateAgainstCorpus(&result);
        return result;
    }

    fn collectCallCandidates(
        self: *const Corpus,
        parsed: *const zig_parser.Result,
        call: *const zig_parser.Call,
        targets: *std.ArrayList(CandidateTarget),
    ) !void {
        if (isSimpleIdentifier(call.callee)) {
            if (uniqueLocalBinding(parsed, call.callee, call.enclosing_declaration, call.callee_span.start_byte)) |binding| {
                for (parsed.binding_references) |reference| {
                    if (!std.mem.eql(u8, reference.binding, binding.name) or
                        !std.mem.eql(u8, reference.enclosing_declaration, binding.enclosing_declaration)) continue;
                    try self.collectImportedMember(parsed, reference.expression, reference.enclosing_declaration, .binding_flow, targets);
                }
                return;
            }
            if (uniqueFunctionDeclaration(parsed, call.callee)) |declaration| {
                try appendCandidateTarget(self.allocator, targets, .{
                    .target_path = parsed.path,
                    .target_name = declaration.name,
                    .reason = .same_file,
                });
                return;
            }
            return;
        }
        try self.collectImportedMember(parsed, call.callee, call.enclosing_declaration, .import_member, targets);
    }

    fn collectImportedMember(
        self: *const Corpus,
        parsed: *const zig_parser.Result,
        expression: []const u8,
        enclosing_declaration: []const u8,
        reason: CandidateReason,
        targets: *std.ArrayList(CandidateTarget),
    ) !void {
        const member = splitImportedMember(expression) orelse return;
        for (parsed.imports) |item| {
            if (!std.mem.eql(u8, item.binding, member.alias) or
                (item.enclosing_declaration.len > 0 and !std.mem.eql(u8, item.enclosing_declaration, enclosing_declaration))) continue;
            const normalized = try normalizeImportPathAlloc(self.allocator, parsed.path, item.target) orelse continue;
            defer self.allocator.free(normalized);
            const target_file = self.parsedForPath(normalized) orelse continue;
            const declaration = uniqueFunctionDeclaration(target_file, member.member) orelse continue;
            try appendCandidateTarget(self.allocator, targets, .{
                .target_path = target_file.path,
                .target_name = declaration.name,
                .reason = reason,
            });
        }
    }

    fn validateAgainstCorpus(self: *const Corpus, result: *const Result) !void {
        var expected_calls: usize = 0;
        for (self.parsed_files.items) |parsed| expected_calls = std.math.add(usize, expected_calls, parsed.calls.len) catch return error.InvalidZigResolutionCorpus;
        if (expected_calls != result.resolutions.len) return error.InvalidZigResolutionCorpus;
        for (result.resolutions) |resolution| {
            const parsed = self.parsedForPath(resolution.source_path) orelse return error.InvalidZigResolutionCorpus;
            var found_call = false;
            for (parsed.calls) |call| {
                if (call.span.start_byte == resolution.call_span.start_byte and call.span.end_byte == resolution.call_span.end_byte and
                    std.mem.eql(u8, call.callee, resolution.callee) and
                    std.mem.eql(u8, call.enclosing_declaration, resolution.enclosing_declaration))
                {
                    found_call = true;
                    break;
                }
            }
            if (!found_call) return error.InvalidZigResolutionCorpus;
        }
        for (result.candidates) |candidate| {
            const parsed = self.parsedForPath(candidate.target_path) orelse return error.InvalidZigResolutionCandidate;
            _ = uniqueFunctionDeclaration(parsed, candidate.target_name) orelse return error.InvalidZigResolutionCandidate;
        }
    }
};

pub fn validate(result: *const Result) !void {
    const decided = std.math.add(usize, result.summary.resolved, result.summary.ambiguous) catch return error.InvalidZigResolutionSummary;
    const categorized = std.math.add(usize, decided, result.summary.unresolved) catch return error.InvalidZigResolutionSummary;
    if (result.summary.calls != result.resolutions.len or result.summary.candidates != result.candidates.len or
        categorized != result.summary.calls)
    {
        return error.InvalidZigResolutionResult;
    }
    var next_candidate: usize = 0;
    var counts = Summary{};
    for (result.resolutions, 0..) |resolution, resolution_index| {
        const candidate_end = std.math.add(usize, resolution.candidate_start, resolution.candidate_count) catch return error.InvalidZigCallResolution;
        if (!validRelativePath(resolution.source_path) or resolution.callee.len == 0 or
            resolution.candidate_start != next_candidate or candidate_end > result.candidates.len or
            (resolution_index > 0 and !lessThanOrEqualResolution(result.resolutions[resolution_index - 1], resolution)))
        {
            return error.InvalidZigCallResolution;
        }
        switch (resolution.status) {
            .resolved => {
                if (resolution.candidate_count != 1) return error.InvalidZigCallResolution;
                counts.resolved += 1;
            },
            .ambiguous => {
                if (resolution.candidate_count < 2) return error.InvalidZigCallResolution;
                counts.ambiguous += 1;
            },
            .unresolved => {
                if (resolution.candidate_count != 0) return error.InvalidZigCallResolution;
                counts.unresolved += 1;
            },
        }
        const group = result.candidates[resolution.candidate_start..][0..resolution.candidate_count];
        for (group, 0..) |candidate, candidate_index| {
            if (candidate.resolution_index != resolution_index or !validRelativePath(candidate.target_path) or candidate.target_name.len == 0 or
                (candidate_index > 0 and !lessThanOrEqualCandidate(group[candidate_index - 1], candidate)))
            {
                return error.InvalidZigResolutionCandidate;
            }
            if (candidate_index > 0 and std.mem.eql(u8, group[candidate_index - 1].target_path, candidate.target_path) and
                std.mem.eql(u8, group[candidate_index - 1].target_name, candidate.target_name)) return error.DuplicateZigResolutionCandidate;
        }
        next_candidate = std.math.add(usize, next_candidate, resolution.candidate_count) catch return error.InvalidZigResolutionSummary;
        counts.calls += 1;
        counts.candidates += resolution.candidate_count;
    }
    if (next_candidate != result.candidates.len or counts.calls != result.summary.calls or counts.resolved != result.summary.resolved or
        counts.ambiguous != result.summary.ambiguous or counts.unresolved != result.summary.unresolved or counts.candidates != result.summary.candidates)
    {
        return error.InvalidZigResolutionSummary;
    }
    const expected = resolutionFingerprint(result.resolutions, result.candidates, result.summary);
    if (!std.mem.eql(u8, &expected, &result.fingerprint)) return error.InvalidZigResolutionFingerprint;
}

const CandidateTarget = struct {
    target_path: []const u8,
    target_name: []const u8,
    reason: CandidateReason,
};

const ImportedMember = struct {
    alias: []const u8,
    member: []const u8,
};

fn lessThanFileIndex(corpus: *const Corpus, left: usize, right: usize) bool {
    return std.mem.lessThan(u8, corpus.parsed_files.items[left].path, corpus.parsed_files.items[right].path);
}

fn uniqueFunctionDeclaration(parsed: *const zig_parser.Result, name: []const u8) ?*const zig_parser.Declaration {
    var found: ?*const zig_parser.Declaration = null;
    for (parsed.declarations) |*declaration| {
        if (declaration.kind != .function or !std.mem.eql(u8, declaration.name, name)) continue;
        if (found != null) return null;
        found = declaration;
    }
    return found;
}

fn uniqueLocalBinding(parsed: *const zig_parser.Result, name: []const u8, enclosing: []const u8, before_byte: usize) ?*const zig_parser.Binding {
    var found: ?*const zig_parser.Binding = null;
    for (parsed.bindings) |*binding| {
        if (binding.scope != .local or !std.mem.eql(u8, binding.name, name) or
            !std.mem.eql(u8, binding.enclosing_declaration, enclosing) or binding.name_span.start_byte >= before_byte) continue;
        if (found != null) return null;
        found = binding;
    }
    return found;
}

fn appendCandidateTarget(allocator: std.mem.Allocator, targets: *std.ArrayList(CandidateTarget), candidate: CandidateTarget) !void {
    for (targets.items) |*existing| {
        if (!std.mem.eql(u8, existing.target_path, candidate.target_path) or !std.mem.eql(u8, existing.target_name, candidate.target_name)) continue;
        if (@intFromEnum(candidate.reason) < @intFromEnum(existing.reason)) existing.reason = candidate.reason;
        return;
    }
    try targets.append(allocator, candidate);
}

fn splitImportedMember(expression: []const u8) ?ImportedMember {
    const dot = std.mem.indexOfScalar(u8, expression, '.') orelse return null;
    if (dot == 0 or dot + 1 >= expression.len or std.mem.indexOfScalarPos(u8, expression, dot + 1, '.') != null) return null;
    const alias = expression[0..dot];
    const member = expression[dot + 1 ..];
    if (!isSimpleIdentifier(alias) or !isSimpleIdentifier(member)) return null;
    return .{ .alias = alias, .member = member };
}

fn isSimpleIdentifier(value: []const u8) bool {
    if (value.len == 0 or !(std.ascii.isAlphabetic(value[0]) or value[0] == '_')) return false;
    for (value[1..]) |byte| if (!(std.ascii.isAlphanumeric(byte) or byte == '_')) return false;
    return true;
}

fn normalizeImportPathAlloc(allocator: std.mem.Allocator, importer_path: []const u8, target: []const u8) !?[]u8 {
    if (target.len == 0 or std.fs.path.isAbsolute(target) or std.mem.indexOfScalar(u8, target, '\\') != null) return null;
    const parent = std.fs.path.dirname(importer_path) orelse "";
    const normalized = try std.fs.path.resolvePosix(allocator, &.{ parent, target });
    errdefer allocator.free(normalized);
    if (std.mem.eql(u8, normalized, ".") or std.fs.path.isAbsolutePosix(normalized) or std.mem.eql(u8, normalized, "..") or
        std.mem.startsWith(u8, normalized, "../"))
    {
        allocator.free(normalized);
        return null;
    }
    return normalized;
}

fn validRelativePath(path: []const u8) bool {
    if (path.len == 0 or std.fs.path.isAbsolute(path) or std.mem.indexOfScalar(u8, path, '\\') != null) return false;
    var parts = std.mem.splitScalar(u8, path, '/');
    while (parts.next()) |part| if (part.len == 0 or std.mem.eql(u8, part, ".") or std.mem.eql(u8, part, "..")) return false;
    return true;
}

fn lessThanCandidateTarget(_: void, left: CandidateTarget, right: CandidateTarget) bool {
    const path_order = std.mem.order(u8, left.target_path, right.target_path);
    if (path_order != .eq) return path_order == .lt;
    const name_order = std.mem.order(u8, left.target_name, right.target_name);
    if (name_order != .eq) return name_order == .lt;
    return @intFromEnum(left.reason) < @intFromEnum(right.reason);
}

fn lessThanOrEqualCandidate(left: Candidate, right: Candidate) bool {
    const path_order = std.mem.order(u8, left.target_path, right.target_path);
    if (path_order != .eq) return path_order == .lt;
    const name_order = std.mem.order(u8, left.target_name, right.target_name);
    if (name_order != .eq) return name_order == .lt;
    return @intFromEnum(left.reason) <= @intFromEnum(right.reason);
}

fn lessThanOrEqualResolution(left: CallResolution, right: CallResolution) bool {
    const path_order = std.mem.order(u8, left.source_path, right.source_path);
    if (path_order != .eq) return path_order == .lt;
    if (left.call_span.start_byte != right.call_span.start_byte) return left.call_span.start_byte < right.call_span.start_byte;
    return std.mem.order(u8, left.callee, right.callee) != .gt;
}

fn deinitResolutions(allocator: std.mem.Allocator, values: *std.ArrayList(CallResolution)) void {
    for (values.items) |value| {
        allocator.free(value.source_path);
        if (value.enclosing_declaration.len > 0) allocator.free(value.enclosing_declaration);
        allocator.free(value.callee);
    }
    values.deinit(allocator);
}

fn deinitCandidates(allocator: std.mem.Allocator, values: *std.ArrayList(Candidate)) void {
    for (values.items) |value| {
        allocator.free(value.target_path);
        allocator.free(value.target_name);
    }
    values.deinit(allocator);
}

fn resolutionFingerprint(resolutions: []const CallResolution, candidates: []const Candidate, summary: Summary) [32]u8 {
    var hasher = std.crypto.hash.sha2.Sha256.init(.{});
    updateBytes(&hasher, schema);
    updateBytes(&hasher, resolver_version);
    updateU64(&hasher, summary.calls);
    updateU64(&hasher, summary.resolved);
    updateU64(&hasher, summary.ambiguous);
    updateU64(&hasher, summary.unresolved);
    updateU64(&hasher, summary.candidates);
    for (resolutions) |resolution| {
        updateBytes(&hasher, resolution.source_path);
        updateBytes(&hasher, resolution.enclosing_declaration);
        updateBytes(&hasher, resolution.callee);
        updateSpan(&hasher, resolution.call_span);
        updateU64(&hasher, @intCast(@intFromEnum(resolution.status)));
        updateU64(&hasher, @intCast(resolution.candidate_start));
        updateU64(&hasher, @intCast(resolution.candidate_count));
    }
    for (candidates) |candidate| {
        updateU64(&hasher, @intCast(candidate.resolution_index));
        updateBytes(&hasher, candidate.target_path);
        updateBytes(&hasher, candidate.target_name);
        updateU64(&hasher, @intCast(@intFromEnum(candidate.reason)));
    }
    var digest: [32]u8 = @splat(0);
    hasher.final(&digest);
    return digest;
}

fn updateSpan(hasher: *std.crypto.hash.sha2.Sha256, span: zig_parser.Span) void {
    updateU64(hasher, span.start_byte);
    updateU64(hasher, span.end_byte);
    updateU64(hasher, span.start_line);
    updateU64(hasher, span.start_column);
    updateU64(hasher, span.end_line);
    updateU64(hasher, span.end_column);
}

fn updateBytes(hasher: *std.crypto.hash.sha2.Sha256, bytes: []const u8) void {
    updateU64(hasher, bytes.len);
    hasher.update(bytes);
}

fn updateU64(hasher: *std.crypto.hash.sha2.Sha256, value: u64) void {
    var bytes: [8]u8 = @splat(0);
    std.mem.writeInt(u64, &bytes, value, .little);
    hasher.update(&bytes);
}
