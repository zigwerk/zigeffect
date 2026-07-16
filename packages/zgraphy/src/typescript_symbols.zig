const std = @import("std");
const owned = @import("memory.zig");
const typescript_parser = @import("typescript_parser.zig");
const typescript_resolution = @import("typescript_resolution.zig");

pub const schema = "zgraphy.typescript-symbol-resolution.v1";
pub const schema_version: u32 = 1;
pub const resolver_version = "exports-imports-scoped-receivers-v1";

pub const Status = enum(u8) {
    resolved,
    ambiguous,
    unresolved,
    invalid,
    exhausted,
};

pub const FactKind = enum(u8) {
    import_binding,
    export_binding,
    direct_call,
    member_call,
    constructor_call,
};

pub const CandidateReason = enum(u8) {
    same_file,
    named_import,
    default_import,
    namespace_member,
    named_re_export,
    star_re_export,
    local_export_alias,
    static_receiver,
    typed_receiver,
};

pub const Resolution = struct {
    kind: FactKind,
    source_path: []const u8,
    subject: []const u8,
    enclosing_declaration: []const u8,
    span: typescript_parser.Span,
    status: Status,
    candidate_start: usize,
    candidate_count: usize,
};

pub const Candidate = struct {
    resolution_index: usize,
    target_path: []const u8,
    target_enclosing_declaration: []const u8,
    target_name: []const u8,
    reason: CandidateReason,
    rank: usize,
};

pub const DiagnosticKind = enum(u8) {
    module_mismatch,
    export_cycle,
    export_limit,
    candidate_limit,
    result_limit,
};

pub const Diagnostic = struct {
    kind: DiagnosticKind,
    source_path: []const u8,
    detail: []const u8,
};

pub const Summary = struct {
    facts: usize = 0,
    resolved: usize = 0,
    ambiguous: usize = 0,
    unresolved: usize = 0,
    invalid: usize = 0,
    exhausted: usize = 0,
    candidates: usize = 0,
    diagnostics: usize = 0,
};

pub const Result = struct {
    allocator: std.mem.Allocator,
    resolutions: []Resolution,
    candidates: []Candidate,
    diagnostics: []Diagnostic,
    summary: Summary,
    corpus_fingerprint: [32]u8,
    module_fingerprint: [32]u8,
    fingerprint: [32]u8,

    pub fn deinit(self: *Result) void {
        deinitResolutionSlice(self.allocator, self.resolutions);
        deinitCandidateSlice(self.allocator, self.candidates);
        deinitDiagnosticSlice(self.allocator, self.diagnostics);
        self.resolutions = &.{};
        self.candidates = &.{};
        self.diagnostics = &.{};
    }

    pub fn findResolution(self: *const Result, kind: FactKind, source_path: []const u8, subject: []const u8) ?*const Resolution {
        for (self.resolutions, 0..) |resolution, index| {
            if (resolution.kind == kind and std.mem.eql(u8, resolution.source_path, source_path) and std.mem.eql(u8, resolution.subject, subject)) {
                return &self.resolutions[index];
            }
        }
        return null;
    }

    pub fn candidatesFor(self: *const Result, resolution: *const Resolution) []const Candidate {
        return self.candidates[resolution.candidate_start..][0..resolution.candidate_count];
    }
};

pub const Options = struct {
    max_files: usize = 100_000,
    max_facts: usize = 1_000_000,
    max_export_depth: usize = 128,
    max_export_work: usize = 4_000_000,
    max_candidates_per_fact: usize = 64,
    max_candidates: usize = 4_000_000,
    max_diagnostics: usize = 100_000,
    max_result_bytes: usize = 512 * 1024 * 1024,
    parser: typescript_parser.Options = .{},
};

pub const Corpus = struct {
    allocator: std.mem.Allocator,
    options: Options,
    parsed_files: std.ArrayList(typescript_parser.Result) = .empty,
    fact_count: usize = 0,

    pub fn init(allocator: std.mem.Allocator, options: Options) !Corpus {
        if (options.max_files == 0 or options.max_facts == 0 or options.max_export_depth == 0 or options.max_export_depth > 1024 or
            options.max_export_work == 0 or options.max_candidates_per_fact == 0 or options.max_candidates == 0 or
            options.max_diagnostics == 0 or options.max_result_bytes == 0)
        {
            return error.InvalidTypeScriptSymbolOptions;
        }
        return .{ .allocator = allocator, .options = options };
    }

    pub fn deinit(self: *Corpus) void {
        for (self.parsed_files.items) |*parsed| parsed.deinit();
        self.parsed_files.deinit(self.allocator);
    }

    pub fn addSource(self: *Corpus, path: []const u8, source: []const u8, mode: typescript_parser.LanguageMode) !void {
        var parsed = try typescript_parser.parse(self.allocator, path, source, mode, self.options.parser);
        errdefer parsed.deinit();
        try self.addParsedOwned(&parsed);
    }

    pub fn addParsedOwned(self: *Corpus, parsed: *typescript_parser.Result) !void {
        try typescript_parser.validate(parsed);
        if (self.parsed_files.items.len >= self.options.max_files) return error.TypeScriptSymbolFileLimitExceeded;
        for (self.parsed_files.items) |existing| if (std.mem.eql(u8, existing.path, parsed.path)) return error.DuplicateTypeScriptSymbolSource;
        const file_facts = parsed.declarations.len + parsed.imports.len + parsed.import_bindings.len + parsed.exports.len + parsed.type_bindings.len + parsed.calls.len;
        const next_facts = std.math.add(usize, self.fact_count, file_facts) catch return error.TypeScriptSymbolFactLimitExceeded;
        if (next_facts > self.options.max_facts) return error.TypeScriptSymbolFactLimitExceeded;
        try self.parsed_files.append(self.allocator, parsed.*);
        parsed.path = "";
        parsed.declarations = &.{};
        parsed.imports = &.{};
        parsed.import_bindings = &.{};
        parsed.exports = &.{};
        parsed.type_bindings = &.{};
        parsed.calls = &.{};
        parsed.protocol_packages = &.{};
        parsed.protocol_fields = &.{};
        parsed.protocol_enum_values = &.{};
        parsed.protocol_rpcs = &.{};
        parsed.owns_memory = false;
        self.fact_count = next_facts;
    }

    pub fn parsedForPath(self: *const Corpus, path: []const u8) ?*const typescript_parser.Result {
        for (self.parsed_files.items, 0..) |parsed, index| if (std.mem.eql(u8, parsed.path, path)) return &self.parsed_files.items[index];
        return null;
    }

    pub fn resolve(self: *const Corpus, modules: *const typescript_resolution.Result) !Result {
        try typescript_resolution.validate(modules);
        var engine = Engine.init(self, modules);
        defer engine.deinit();
        return engine.run();
    }
};

pub fn validate(result: *const Result) !void {
    var expected = Summary{};
    var candidate_cursor: usize = 0;
    var previous: ?Resolution = null;
    for (result.resolutions, 0..) |resolution, resolution_index| {
        const end = std.math.add(usize, resolution.candidate_start, resolution.candidate_count) catch return error.InvalidTypeScriptSymbolCandidateRange;
        if (resolution.candidate_start != candidate_cursor or end > result.candidates.len or
            !validRelativePath(resolution.source_path) or resolution.subject.len == 0)
        {
            return error.InvalidTypeScriptSymbolResolution;
        }
        if (previous) |value| if (!lessThanOrEqualResolution(value, resolution)) return error.UnsortedTypeScriptSymbolResolutions;
        previous = resolution;
        expected.facts += 1;
        switch (resolution.status) {
            .resolved => expected.resolved += 1,
            .ambiguous => expected.ambiguous += 1,
            .unresolved => expected.unresolved += 1,
            .invalid => expected.invalid += 1,
            .exhausted => expected.exhausted += 1,
        }
        if ((resolution.status == .resolved and resolution.candidate_count != 1) or
            (resolution.status == .ambiguous and resolution.candidate_count < 2) or
            ((resolution.status == .unresolved or resolution.status == .invalid or resolution.status == .exhausted) and resolution.candidate_count != 0))
        {
            return error.InvalidTypeScriptSymbolStatus;
        }
        for (result.candidates[resolution.candidate_start..end], 0..) |candidate, rank| {
            if (candidate.resolution_index != resolution_index or candidate.rank != rank or
                !validRelativePath(candidate.target_path) or candidate.target_name.len == 0)
            {
                return error.InvalidTypeScriptSymbolCandidate;
            }
        }
        candidate_cursor = end;
    }
    expected.candidates = result.candidates.len;
    expected.diagnostics = result.diagnostics.len;
    if (!std.meta.eql(expected, result.summary) or candidate_cursor != result.candidates.len) return error.InvalidTypeScriptSymbolSummary;
    var previous_diagnostic: ?Diagnostic = null;
    for (result.diagnostics) |diagnostic| {
        if (!validRelativePath(diagnostic.source_path) or diagnostic.detail.len == 0) return error.InvalidTypeScriptSymbolDiagnostic;
        if (previous_diagnostic) |value| if (!lessThanOrEqualDiagnostic(value, diagnostic)) return error.UnsortedTypeScriptSymbolDiagnostics;
        previous_diagnostic = diagnostic;
    }
    const expected_fingerprint = resultFingerprint(
        result.resolutions,
        result.candidates,
        result.diagnostics,
        result.summary,
        result.corpus_fingerprint,
        result.module_fingerprint,
    );
    if (!std.mem.eql(u8, &expected_fingerprint, &result.fingerprint)) return error.InvalidTypeScriptSymbolFingerprint;
}

const Fact = struct {
    kind: FactKind,
    source_path: []const u8,
    subject: []const u8,
    enclosing_declaration: []const u8,
    span: typescript_parser.Span,
    export_fact: ?*const typescript_parser.Export = null,
    import_binding: ?*const typescript_parser.ImportBinding = null,
    call: ?*const typescript_parser.Call = null,
};

const TempCandidate = struct {
    target_path: []const u8,
    target_enclosing_declaration: []const u8,
    target_name: []const u8,
    reason: CandidateReason,
};

const TempDiagnostic = struct {
    kind: DiagnosticKind,
    source_path: []const u8,
    detail: []const u8,
};

const ExportKey = struct {
    path: []const u8,
    name: []const u8,
};

const Hint = enum {
    normal,
    invalid,
    exhausted,
};

const Engine = struct {
    corpus: *const Corpus,
    modules: *const typescript_resolution.Result,
    arena: std.heap.ArenaAllocator,
    diagnostics: std.ArrayList(TempDiagnostic) = .empty,
    export_work: usize = 0,

    fn init(corpus: *const Corpus, modules: *const typescript_resolution.Result) Engine {
        return .{
            .corpus = corpus,
            .modules = modules,
            .arena = std.heap.ArenaAllocator.init(corpus.allocator),
        };
    }

    fn deinit(self: *Engine) void {
        self.arena.deinit();
    }

    fn run(self: *Engine) !Result {
        try self.validateModuleSnapshot();
        var facts: std.ArrayList(Fact) = .empty;
        defer facts.deinit(self.arena.allocator());
        try self.collectFacts(&facts);
        std.mem.sort(Fact, facts.items, {}, lessThanFact);

        var resolutions: std.ArrayList(Resolution) = .empty;
        errdefer deinitResolutionList(self.corpus.allocator, &resolutions);
        var candidates: std.ArrayList(Candidate) = .empty;
        errdefer deinitCandidateList(self.corpus.allocator, &candidates);
        var diagnostics: std.ArrayList(Diagnostic) = .empty;
        errdefer deinitDiagnosticList(self.corpus.allocator, &diagnostics);
        var summary = Summary{};
        var result_bytes: usize = 0;

        for (facts.items) |fact| {
            var temporary: std.ArrayList(TempCandidate) = .empty;
            defer temporary.deinit(self.arena.allocator());
            var hint: Hint = .normal;
            try self.resolveFact(fact, &temporary, &hint);
            std.mem.sort(TempCandidate, temporary.items, {}, lessThanTempCandidate);
            deduplicateTempCandidates(&temporary);

            const candidate_end = std.math.add(usize, candidates.items.len, temporary.items.len) catch return error.TypeScriptSymbolCandidateLimitExceeded;
            if (temporary.items.len > self.corpus.options.max_candidates_per_fact or candidate_end > self.corpus.options.max_candidates) {
                temporary.items.len = 0;
                hint = .exhausted;
                try self.appendDiagnostic(.candidate_limit, fact.source_path, "symbol candidate limit was exhausted");
            }
            if (hint == .exhausted) temporary.items.len = 0;
            const status: Status = if (hint == .exhausted)
                .exhausted
            else switch (temporary.items.len) {
                0 => if (hint == .invalid) .invalid else .unresolved,
                1 => .resolved,
                else => .ambiguous,
            };

            const resolution_index = resolutions.items.len;
            const candidate_start = candidates.items.len;
            for (temporary.items, 0..) |candidate, rank| {
                result_bytes = try consumeResultBytes(
                    result_bytes,
                    @sizeOf(Candidate) + candidate.target_path.len + candidate.target_enclosing_declaration.len + candidate.target_name.len,
                    self.corpus.options.max_result_bytes,
                );
                const target_path = try owned.copy(u8, self.corpus.allocator, candidate.target_path);
                errdefer self.corpus.allocator.free(target_path);
                const target_enclosing = if (candidate.target_enclosing_declaration.len > 0)
                    try owned.copy(u8, self.corpus.allocator, candidate.target_enclosing_declaration)
                else
                    "";
                errdefer if (target_enclosing.len > 0) self.corpus.allocator.free(target_enclosing);
                const target_name = try owned.copy(u8, self.corpus.allocator, candidate.target_name);
                errdefer self.corpus.allocator.free(target_name);
                try candidates.append(self.corpus.allocator, .{
                    .resolution_index = resolution_index,
                    .target_path = target_path,
                    .target_enclosing_declaration = target_enclosing,
                    .target_name = target_name,
                    .reason = candidate.reason,
                    .rank = rank,
                });
            }

            result_bytes = try consumeResultBytes(
                result_bytes,
                @sizeOf(Resolution) + fact.source_path.len + fact.subject.len + fact.enclosing_declaration.len,
                self.corpus.options.max_result_bytes,
            );
            const source_path = try owned.copy(u8, self.corpus.allocator, fact.source_path);
            errdefer self.corpus.allocator.free(source_path);
            const subject = try owned.copy(u8, self.corpus.allocator, fact.subject);
            errdefer self.corpus.allocator.free(subject);
            const enclosing = if (fact.enclosing_declaration.len > 0)
                try owned.copy(u8, self.corpus.allocator, fact.enclosing_declaration)
            else
                "";
            errdefer if (enclosing.len > 0) self.corpus.allocator.free(enclosing);
            try resolutions.append(self.corpus.allocator, .{
                .kind = fact.kind,
                .source_path = source_path,
                .subject = subject,
                .enclosing_declaration = enclosing,
                .span = fact.span,
                .status = status,
                .candidate_start = candidate_start,
                .candidate_count = temporary.items.len,
            });
            summary.facts += 1;
            switch (status) {
                .resolved => summary.resolved += 1,
                .ambiguous => summary.ambiguous += 1,
                .unresolved => summary.unresolved += 1,
                .invalid => summary.invalid += 1,
                .exhausted => summary.exhausted += 1,
            }
        }
        summary.candidates = candidates.items.len;

        std.mem.sort(TempDiagnostic, self.diagnostics.items, {}, lessThanTempDiagnostic);
        deduplicateTempDiagnostics(&self.diagnostics);
        for (self.diagnostics.items) |diagnostic| {
            result_bytes = consumeResultBytes(
                result_bytes,
                @sizeOf(Diagnostic) + diagnostic.source_path.len + diagnostic.detail.len,
                self.corpus.options.max_result_bytes,
            ) catch return error.TypeScriptSymbolResultLimitExceeded;
            const source_path = try owned.copy(u8, self.corpus.allocator, diagnostic.source_path);
            errdefer self.corpus.allocator.free(source_path);
            const detail = try owned.copy(u8, self.corpus.allocator, diagnostic.detail);
            errdefer self.corpus.allocator.free(detail);
            try diagnostics.append(self.corpus.allocator, .{
                .kind = diagnostic.kind,
                .source_path = source_path,
                .detail = detail,
            });
        }
        summary.diagnostics = diagnostics.items.len;

        const corpus_fingerprint = try self.corpusFingerprint();
        const resolution_slice = try resolutions.toOwnedSlice(self.corpus.allocator);
        errdefer deinitResolutionSlice(self.corpus.allocator, resolution_slice);
        const candidate_slice = try candidates.toOwnedSlice(self.corpus.allocator);
        errdefer deinitCandidateSlice(self.corpus.allocator, candidate_slice);
        const diagnostic_slice = try diagnostics.toOwnedSlice(self.corpus.allocator);
        errdefer deinitDiagnosticSlice(self.corpus.allocator, diagnostic_slice);
        var result = Result{
            .allocator = self.corpus.allocator,
            .resolutions = resolution_slice,
            .candidates = candidate_slice,
            .diagnostics = diagnostic_slice,
            .summary = summary,
            .corpus_fingerprint = corpus_fingerprint,
            .module_fingerprint = self.modules.fingerprint,
            .fingerprint = resultFingerprint(
                resolution_slice,
                candidate_slice,
                diagnostic_slice,
                summary,
                corpus_fingerprint,
                self.modules.fingerprint,
            ),
        };
        try validate(&result);
        return result;
    }

    fn validateModuleSnapshot(self: *Engine) !void {
        for (self.corpus.parsed_files.items) |parsed| {
            for (parsed.imports) |item| {
                if (self.modules.findResolution(parsed.path, item.target, item.kind) == null) {
                    try self.appendDiagnostic(.module_mismatch, parsed.path, "parser import has no module-resolution occurrence");
                }
            }
        }
    }

    fn collectFacts(self: *Engine, facts: *std.ArrayList(Fact)) !void {
        for (self.corpus.parsed_files.items) |*parsed| {
            for (parsed.exports) |*item| try facts.append(self.arena.allocator(), .{
                .kind = .export_binding,
                .source_path = parsed.path,
                .subject = item.exported,
                .enclosing_declaration = "",
                .span = item.span,
                .export_fact = item,
            });
            for (parsed.import_bindings) |*item| try facts.append(self.arena.allocator(), .{
                .kind = .import_binding,
                .source_path = parsed.path,
                .subject = item.local,
                .enclosing_declaration = "",
                .span = item.span,
                .import_binding = item,
            });
            for (parsed.calls) |*item| {
                const kind: ?FactKind = switch (item.kind) {
                    .direct => .direct_call,
                    .member => .member_call,
                    .constructor => .constructor_call,
                    .dynamic_import => null,
                };
                if (kind) |fact_kind| try facts.append(self.arena.allocator(), .{
                    .kind = fact_kind,
                    .source_path = parsed.path,
                    .subject = item.callee,
                    .enclosing_declaration = item.enclosing_declaration,
                    .span = item.span,
                    .call = item,
                });
            }
        }
    }

    fn resolveFact(self: *Engine, fact: Fact, output: *std.ArrayList(TempCandidate), hint: *Hint) !void {
        switch (fact.kind) {
            .export_binding => {
                const item = fact.export_fact.?;
                if (item.kind == .re_export_star) {
                    try self.appendModuleNamespaces(fact.source_path, item.target, .static, .star_re_export, output, hint);
                } else if (item.kind != .default_expression) {
                    var stack: std.ArrayList(ExportKey) = .empty;
                    defer stack.deinit(self.arena.allocator());
                    try self.resolveExportName(fact.source_path, item.exported, 0, &stack, output, hint);
                }
            },
            .import_binding => try self.resolveImportBinding(fact.source_path, fact.import_binding.?.*, output, hint),
            .direct_call => try self.resolveDirectCall(fact.source_path, fact.call.?.*, output, hint),
            .member_call => try self.resolveMemberCall(fact.source_path, fact.call.?.*, output, hint),
            .constructor_call => try self.resolveConstructorCall(fact.source_path, fact.call.?.*, output, hint),
        }
    }

    fn resolveExportName(
        self: *Engine,
        path: []const u8,
        requested: []const u8,
        depth: usize,
        stack: *std.ArrayList(ExportKey),
        output: *std.ArrayList(TempCandidate),
        hint: *Hint,
    ) anyerror!void {
        if (depth >= self.corpus.options.max_export_depth) {
            hint.* = .exhausted;
            try self.appendDiagnostic(.export_limit, path, "re-export depth limit was exhausted");
            return;
        }
        self.export_work = std.math.add(usize, self.export_work, 1) catch self.corpus.options.max_export_work;
        if (self.export_work > self.corpus.options.max_export_work) {
            hint.* = .exhausted;
            try self.appendDiagnostic(.export_limit, path, "re-export work limit was exhausted");
            return;
        }
        for (stack.items) |key| {
            if (std.mem.eql(u8, key.path, path) and std.mem.eql(u8, key.name, requested)) {
                try self.appendDiagnostic(.export_cycle, path, "re-export cycle branch was stopped");
                return;
            }
        }
        const parsed = self.corpus.parsedForPath(path) orelse {
            try self.appendDiagnostic(.module_mismatch, path, "module candidate has no parsed symbol snapshot");
            return;
        };
        try stack.append(self.arena.allocator(), .{ .path = path, .name = requested });
        defer _ = stack.pop();

        for (parsed.exports) |item| {
            switch (item.kind) {
                .local_named, .local_default, .commonjs_named, .commonjs_default => {
                    if (!std.mem.eql(u8, item.exported, requested)) continue;
                    const before = output.items.len;
                    try self.resolveLocalName(path, item.imported, output, hint);
                    if (before < output.items.len and !std.mem.eql(u8, item.imported, item.exported)) {
                        setReasons(output.items[before..], .local_export_alias);
                    }
                },
                .re_export_named => {
                    if (!std.mem.eql(u8, item.exported, requested)) continue;
                    const before = output.items.len;
                    try self.resolveFromModule(path, item.target, .static, item.imported, depth + 1, stack, output, hint);
                    setReasons(output.items[before..], .named_re_export);
                },
                .re_export_namespace => {
                    if (!std.mem.eql(u8, item.exported, requested)) continue;
                    try self.appendModuleNamespaces(path, item.target, .static, .namespace_member, output, hint);
                },
                .re_export_star => {
                    if (std.mem.eql(u8, requested, "default")) continue;
                    const before = output.items.len;
                    try self.resolveFromModule(path, item.target, .static, requested, depth + 1, stack, output, hint);
                    setReasons(output.items[before..], .star_re_export);
                },
                .default_expression => {},
            }
        }
    }

    fn resolveFromModule(
        self: *Engine,
        source_path: []const u8,
        specifier: []const u8,
        import_kind: typescript_parser.ImportKind,
        requested: []const u8,
        depth: usize,
        stack: *std.ArrayList(ExportKey),
        output: *std.ArrayList(TempCandidate),
        hint: *Hint,
    ) anyerror!void {
        const resolution = self.moduleResolution(source_path, specifier, import_kind, hint) orelse return;
        for (self.modules.candidatesFor(resolution)) |candidate| {
            try self.resolveExportName(candidate.target_path, requested, depth, stack, output, hint);
        }
    }

    fn resolveLocalName(self: *Engine, path: []const u8, name: []const u8, output: *std.ArrayList(TempCandidate), hint: *Hint) !void {
        const parsed = self.corpus.parsedForPath(path) orelse return;
        var found_declaration = false;
        for (parsed.declarations) |declaration| {
            if (!std.mem.eql(u8, declaration.name, name) or declaration.enclosing_declaration.len != 0) continue;
            found_declaration = true;
            try appendTempCandidate(output, self.arena.allocator(), .{
                .target_path = path,
                .target_enclosing_declaration = declaration.enclosing_declaration,
                .target_name = declaration.name,
                .reason = .same_file,
            });
        }
        if (found_declaration) return;
        for (parsed.import_bindings) |binding| {
            if (!std.mem.eql(u8, binding.local, name)) continue;
            const before = output.items.len;
            try self.resolveImportBinding(path, binding, output, hint);
            setReasons(output.items[before..], .local_export_alias);
        }
    }

    fn resolveImportBinding(
        self: *Engine,
        source_path: []const u8,
        binding: typescript_parser.ImportBinding,
        output: *std.ArrayList(TempCandidate),
        hint: *Hint,
    ) !void {
        const import_kind: typescript_parser.ImportKind = switch (binding.kind) {
            .default, .named, .namespace => .static,
            .import_require => .import_require,
            .commonjs_require => .commonjs_require,
        };
        const reason: CandidateReason = switch (binding.kind) {
            .default => .default_import,
            .named => .named_import,
            .namespace, .import_require, .commonjs_require => .namespace_member,
        };
        if (binding.kind == .namespace or binding.kind == .import_require or binding.kind == .commonjs_require) {
            try self.appendModuleNamespaces(source_path, binding.target, import_kind, reason, output, hint);
            return;
        }
        const resolution = self.moduleResolution(source_path, binding.target, import_kind, hint) orelse return;
        for (self.modules.candidatesFor(resolution)) |module_candidate| {
            var stack: std.ArrayList(ExportKey) = .empty;
            defer stack.deinit(self.arena.allocator());
            const before = output.items.len;
            try self.resolveExportName(module_candidate.target_path, binding.imported, 0, &stack, output, hint);
            setReasons(output.items[before..], reason);
        }
    }

    fn resolveDirectCall(
        self: *Engine,
        source_path: []const u8,
        call: typescript_parser.Call,
        output: *std.ArrayList(TempCandidate),
        hint: *Hint,
    ) !void {
        const parsed = self.corpus.parsedForPath(source_path) orelse return;
        var exact_count: usize = 0;
        for (parsed.declarations) |declaration| {
            if (!callableDeclaration(declaration.kind) or !std.mem.eql(u8, declaration.name, call.callee) or
                !std.mem.eql(u8, declaration.enclosing_declaration, call.enclosing_declaration)) continue;
            exact_count += 1;
            try appendDeclarationCandidate(output, self.arena.allocator(), source_path, declaration, .same_file);
        }
        if (exact_count > 0) return;
        for (parsed.declarations) |declaration| {
            if (!callableDeclaration(declaration.kind) or !std.mem.eql(u8, declaration.name, call.callee) or declaration.enclosing_declaration.len != 0) continue;
            try appendDeclarationCandidate(output, self.arena.allocator(), source_path, declaration, .same_file);
        }
        if (output.items.len > 0) return;
        for (parsed.import_bindings) |binding| {
            if (std.mem.eql(u8, binding.local, call.callee)) try self.resolveImportBinding(source_path, binding, output, hint);
        }
    }

    fn resolveMemberCall(
        self: *Engine,
        source_path: []const u8,
        call: typescript_parser.Call,
        output: *std.ArrayList(TempCandidate),
        hint: *Hint,
    ) !void {
        if (!supportedReceiver(call.receiver)) return;
        const parsed = self.corpus.parsedForPath(source_path) orelse return;

        for (parsed.import_bindings) |binding| {
            if (!std.mem.eql(u8, binding.local, call.receiver)) continue;
            var receiver_candidates: std.ArrayList(TempCandidate) = .empty;
            defer receiver_candidates.deinit(self.arena.allocator());
            try self.resolveImportBinding(source_path, binding, &receiver_candidates, hint);
            try self.resolveReceiverCandidates(receiver_candidates.items, call.member, .static_receiver, output, hint);
        }
        if (output.items.len > 0) return;

        var same_file_types: std.ArrayList(TempCandidate) = .empty;
        defer same_file_types.deinit(self.arena.allocator());
        for (parsed.declarations) |declaration| {
            if (declaration.kind == .class and declaration.enclosing_declaration.len == 0 and std.mem.eql(u8, declaration.name, call.receiver)) {
                try appendDeclarationCandidate(&same_file_types, self.arena.allocator(), source_path, declaration, .same_file);
            }
        }
        try self.resolveClassMethods(same_file_types.items, call.member, .static_receiver, output);
        if (output.items.len > 0) return;

        const best_scope = bestBindingScope(parsed.type_bindings, call);
        if (best_scope == null) return;
        for (parsed.type_bindings) |binding| {
            if (!std.mem.eql(u8, binding.binding, call.receiver) or !spanContains(binding.scope_span, call.callee_span) or
                binding.scope_span.end_byte - binding.scope_span.start_byte != best_scope.?) continue;
            var type_candidates: std.ArrayList(TempCandidate) = .empty;
            defer type_candidates.deinit(self.arena.allocator());
            try self.resolveNameInFile(source_path, binding.type_name, &type_candidates, hint);
            try self.resolveClassMethods(type_candidates.items, call.member, .typed_receiver, output);
        }
    }

    fn resolveReceiverCandidates(
        self: *Engine,
        receivers: []const TempCandidate,
        member: []const u8,
        class_reason: CandidateReason,
        output: *std.ArrayList(TempCandidate),
        hint: *Hint,
    ) !void {
        for (receivers) |receiver| {
            if (std.mem.eql(u8, receiver.target_name, "*")) {
                var stack: std.ArrayList(ExportKey) = .empty;
                defer stack.deinit(self.arena.allocator());
                const before = output.items.len;
                try self.resolveExportName(receiver.target_path, member, 0, &stack, output, hint);
                setReasons(output.items[before..], .namespace_member);
            } else {
                try self.resolveClassMethods((&[_]TempCandidate{receiver})[0..], member, class_reason, output);
            }
        }
    }

    fn resolveClassMethods(
        self: *Engine,
        class_candidates: []const TempCandidate,
        member: []const u8,
        reason: CandidateReason,
        output: *std.ArrayList(TempCandidate),
    ) !void {
        for (class_candidates) |class_candidate| {
            const parsed = self.corpus.parsedForPath(class_candidate.target_path) orelse continue;
            if (!hasClassDeclaration(parsed, class_candidate)) continue;
            for (parsed.declarations) |declaration| {
                if (declaration.kind != .method or !std.mem.eql(u8, declaration.name, member) or
                    !std.mem.eql(u8, declaration.enclosing_declaration, class_candidate.target_name)) continue;
                try appendTempCandidate(output, self.arena.allocator(), .{
                    .target_path = class_candidate.target_path,
                    .target_enclosing_declaration = declaration.enclosing_declaration,
                    .target_name = declaration.name,
                    .reason = reason,
                });
            }
        }
    }

    fn resolveConstructorCall(
        self: *Engine,
        source_path: []const u8,
        call: typescript_parser.Call,
        output: *std.ArrayList(TempCandidate),
        hint: *Hint,
    ) !void {
        if (!bareIdentifier(call.callee)) return;
        var candidates: std.ArrayList(TempCandidate) = .empty;
        defer candidates.deinit(self.arena.allocator());
        try self.resolveNameInFile(source_path, call.callee, &candidates, hint);
        for (candidates.items) |candidate| {
            const parsed = self.corpus.parsedForPath(candidate.target_path) orelse continue;
            if (!hasClassDeclaration(parsed, candidate)) continue;
            try appendTempCandidate(output, self.arena.allocator(), candidate);
        }
    }

    fn resolveNameInFile(
        self: *Engine,
        source_path: []const u8,
        name: []const u8,
        output: *std.ArrayList(TempCandidate),
        hint: *Hint,
    ) !void {
        const parsed = self.corpus.parsedForPath(source_path) orelse return;
        for (parsed.declarations) |declaration| {
            if (declaration.enclosing_declaration.len == 0 and std.mem.eql(u8, declaration.name, name)) {
                try appendDeclarationCandidate(output, self.arena.allocator(), source_path, declaration, .same_file);
            }
        }
        for (parsed.import_bindings) |binding| {
            if (std.mem.eql(u8, binding.local, name)) try self.resolveImportBinding(source_path, binding, output, hint);
        }
    }

    fn appendModuleNamespaces(
        self: *Engine,
        source_path: []const u8,
        specifier: []const u8,
        import_kind: typescript_parser.ImportKind,
        reason: CandidateReason,
        output: *std.ArrayList(TempCandidate),
        hint: *Hint,
    ) !void {
        const resolution = self.moduleResolution(source_path, specifier, import_kind, hint) orelse return;
        for (self.modules.candidatesFor(resolution)) |candidate| try appendTempCandidate(output, self.arena.allocator(), .{
            .target_path = candidate.target_path,
            .target_enclosing_declaration = "",
            .target_name = "*",
            .reason = reason,
        });
    }

    fn moduleResolution(
        self: *Engine,
        source_path: []const u8,
        specifier: []const u8,
        import_kind: typescript_parser.ImportKind,
        hint: *Hint,
    ) ?*const typescript_resolution.Resolution {
        const resolution = self.modules.findResolution(source_path, specifier, import_kind) orelse {
            self.appendDiagnostic(.module_mismatch, source_path, "symbol fact has no matching module-resolution occurrence") catch {
                hint.* = .exhausted;
            };
            return null;
        };
        switch (resolution.status) {
            .resolved, .ambiguous => {},
            .invalid => hint.* = .invalid,
            .exhausted => hint.* = .exhausted,
            .external, .unresolved => {},
        }
        return resolution;
    }

    fn appendDiagnostic(self: *Engine, kind: DiagnosticKind, source_path: []const u8, detail: []const u8) !void {
        for (self.diagnostics.items) |existing| {
            if (existing.kind == kind and std.mem.eql(u8, existing.source_path, source_path) and std.mem.eql(u8, existing.detail, detail)) return;
        }
        if (self.diagnostics.items.len >= self.corpus.options.max_diagnostics) return error.TypeScriptSymbolDiagnosticLimitExceeded;
        try self.diagnostics.append(self.arena.allocator(), .{ .kind = kind, .source_path = source_path, .detail = detail });
    }

    fn corpusFingerprint(self: *Engine) ![32]u8 {
        const order = try self.arena.allocator().alloc(usize, self.corpus.parsed_files.items.len);
        for (order, 0..) |*value, index| value.* = index;
        std.mem.sort(usize, order, self.corpus, lessThanParsedIndex);
        var hasher = std.crypto.hash.sha2.Sha256.init(.{});
        updateBytes(&hasher, typescript_parser.schema);
        updateBytes(&hasher, typescript_parser.parser_version);
        for (order) |index| {
            const parsed = self.corpus.parsed_files.items[index];
            updateBytes(&hasher, parsed.path);
            hasher.update(&parsed.fingerprint);
        }
        var digest: [32]u8 = @splat(0);
        hasher.final(&digest);
        return digest;
    }
};

fn appendDeclarationCandidate(
    output: *std.ArrayList(TempCandidate),
    allocator: std.mem.Allocator,
    path: []const u8,
    declaration: typescript_parser.Declaration,
    reason: CandidateReason,
) !void {
    try appendTempCandidate(output, allocator, .{
        .target_path = path,
        .target_enclosing_declaration = declaration.enclosing_declaration,
        .target_name = declaration.name,
        .reason = reason,
    });
}

fn appendTempCandidate(output: *std.ArrayList(TempCandidate), allocator: std.mem.Allocator, candidate: TempCandidate) !void {
    try output.append(allocator, candidate);
}

fn setReasons(values: []TempCandidate, reason: CandidateReason) void {
    for (values) |*candidate| candidate.reason = reason;
}

fn hasClassDeclaration(parsed: *const typescript_parser.Result, candidate: TempCandidate) bool {
    for (parsed.declarations) |declaration| {
        if (declaration.kind == .class and std.mem.eql(u8, declaration.name, candidate.target_name) and
            std.mem.eql(u8, declaration.enclosing_declaration, candidate.target_enclosing_declaration)) return true;
    }
    return false;
}

fn callableDeclaration(kind: typescript_parser.DeclarationKind) bool {
    return kind == .function or kind == .function_value or kind == .class;
}

fn bareIdentifier(value: []const u8) bool {
    if (value.len == 0 or !(std.ascii.isAlphabetic(value[0]) or value[0] == '_' or value[0] == '$')) return false;
    for (value[1..]) |byte| if (!(std.ascii.isAlphanumeric(byte) or byte == '_' or byte == '$')) return false;
    return true;
}

fn supportedReceiver(receiver: []const u8) bool {
    if (bareIdentifier(receiver)) return true;
    if (!std.mem.startsWith(u8, receiver, "this.")) return false;
    return bareIdentifier(receiver["this.".len..]);
}

fn spanContains(outer: typescript_parser.Span, inner: typescript_parser.Span) bool {
    return outer.start_byte <= inner.start_byte and outer.end_byte >= inner.end_byte;
}

fn bestBindingScope(bindings: []const typescript_parser.TypeBinding, call: typescript_parser.Call) ?usize {
    var best: ?usize = null;
    for (bindings) |binding| {
        if (!std.mem.eql(u8, binding.binding, call.receiver) or !spanContains(binding.scope_span, call.callee_span)) continue;
        const width = binding.scope_span.end_byte - binding.scope_span.start_byte;
        if (best == null or width < best.?) best = width;
    }
    return best;
}

fn lessThanFact(_: void, left: Fact, right: Fact) bool {
    const path_order = std.mem.order(u8, left.source_path, right.source_path);
    if (path_order != .eq) return path_order == .lt;
    if (left.span.start_byte != right.span.start_byte) return left.span.start_byte < right.span.start_byte;
    if (left.kind != right.kind) return @intFromEnum(left.kind) < @intFromEnum(right.kind);
    return std.mem.lessThan(u8, left.subject, right.subject);
}

fn lessThanParsedIndex(corpus: *const Corpus, left_index: usize, right_index: usize) bool {
    return std.mem.lessThan(u8, corpus.parsed_files.items[left_index].path, corpus.parsed_files.items[right_index].path);
}

fn lessThanTempCandidate(_: void, left: TempCandidate, right: TempCandidate) bool {
    const path_order = std.mem.order(u8, left.target_path, right.target_path);
    if (path_order != .eq) return path_order == .lt;
    const owner_order = std.mem.order(u8, left.target_enclosing_declaration, right.target_enclosing_declaration);
    if (owner_order != .eq) return owner_order == .lt;
    const name_order = std.mem.order(u8, left.target_name, right.target_name);
    if (name_order != .eq) return name_order == .lt;
    return @intFromEnum(left.reason) < @intFromEnum(right.reason);
}

fn deduplicateTempCandidates(values: *std.ArrayList(TempCandidate)) void {
    if (values.items.len < 2) return;
    var write_index: usize = 1;
    for (values.items[1..]) |candidate| {
        const previous = values.items[write_index - 1];
        if (std.mem.eql(u8, previous.target_path, candidate.target_path) and
            std.mem.eql(u8, previous.target_enclosing_declaration, candidate.target_enclosing_declaration) and
            std.mem.eql(u8, previous.target_name, candidate.target_name)) continue;
        values.items[write_index] = candidate;
        write_index += 1;
    }
    values.items.len = write_index;
}

fn lessThanTempDiagnostic(_: void, left: TempDiagnostic, right: TempDiagnostic) bool {
    const path_order = std.mem.order(u8, left.source_path, right.source_path);
    if (path_order != .eq) return path_order == .lt;
    if (left.kind != right.kind) return @intFromEnum(left.kind) < @intFromEnum(right.kind);
    return std.mem.lessThan(u8, left.detail, right.detail);
}

fn deduplicateTempDiagnostics(values: *std.ArrayList(TempDiagnostic)) void {
    if (values.items.len < 2) return;
    var write_index: usize = 1;
    for (values.items[1..]) |diagnostic| {
        const previous = values.items[write_index - 1];
        if (previous.kind == diagnostic.kind and std.mem.eql(u8, previous.source_path, diagnostic.source_path) and
            std.mem.eql(u8, previous.detail, diagnostic.detail)) continue;
        values.items[write_index] = diagnostic;
        write_index += 1;
    }
    values.items.len = write_index;
}

fn lessThanOrEqualResolution(left: Resolution, right: Resolution) bool {
    const path_order = std.mem.order(u8, left.source_path, right.source_path);
    if (path_order != .eq) return path_order == .lt;
    if (left.span.start_byte != right.span.start_byte) return left.span.start_byte < right.span.start_byte;
    if (left.kind != right.kind) return @intFromEnum(left.kind) < @intFromEnum(right.kind);
    return std.mem.order(u8, left.subject, right.subject) != .gt;
}

fn lessThanOrEqualDiagnostic(left: Diagnostic, right: Diagnostic) bool {
    const path_order = std.mem.order(u8, left.source_path, right.source_path);
    if (path_order != .eq) return path_order == .lt;
    if (left.kind != right.kind) return @intFromEnum(left.kind) < @intFromEnum(right.kind);
    return std.mem.order(u8, left.detail, right.detail) != .gt;
}

fn validRelativePath(path: []const u8) bool {
    if (path.len == 0 or std.fs.path.isAbsolute(path) or std.mem.indexOfScalar(u8, path, '\\') != null) return false;
    var parts = std.mem.splitScalar(u8, path, '/');
    while (parts.next()) |part| if (part.len == 0 or std.mem.eql(u8, part, ".") or std.mem.eql(u8, part, "..")) return false;
    return true;
}

fn consumeResultBytes(current: usize, amount: usize, limit: usize) !usize {
    const next = std.math.add(usize, current, amount) catch return error.TypeScriptSymbolResultLimitExceeded;
    if (next > limit) return error.TypeScriptSymbolResultLimitExceeded;
    return next;
}

fn deinitResolutionList(allocator: std.mem.Allocator, values: *std.ArrayList(Resolution)) void {
    for (values.items) |value| {
        allocator.free(value.source_path);
        allocator.free(value.subject);
        if (value.enclosing_declaration.len > 0) allocator.free(value.enclosing_declaration);
    }
    values.deinit(allocator);
}

fn deinitCandidateList(allocator: std.mem.Allocator, values: *std.ArrayList(Candidate)) void {
    for (values.items) |value| {
        allocator.free(value.target_path);
        if (value.target_enclosing_declaration.len > 0) allocator.free(value.target_enclosing_declaration);
        allocator.free(value.target_name);
    }
    values.deinit(allocator);
}

fn deinitDiagnosticList(allocator: std.mem.Allocator, values: *std.ArrayList(Diagnostic)) void {
    for (values.items) |value| {
        allocator.free(value.source_path);
        allocator.free(value.detail);
    }
    values.deinit(allocator);
}

fn deinitResolutionSlice(allocator: std.mem.Allocator, values: []Resolution) void {
    for (values) |value| {
        allocator.free(value.source_path);
        allocator.free(value.subject);
        if (value.enclosing_declaration.len > 0) allocator.free(value.enclosing_declaration);
    }
    allocator.free(values);
}

fn deinitCandidateSlice(allocator: std.mem.Allocator, values: []Candidate) void {
    for (values) |value| {
        allocator.free(value.target_path);
        if (value.target_enclosing_declaration.len > 0) allocator.free(value.target_enclosing_declaration);
        allocator.free(value.target_name);
    }
    allocator.free(values);
}

fn deinitDiagnosticSlice(allocator: std.mem.Allocator, values: []Diagnostic) void {
    for (values) |value| {
        allocator.free(value.source_path);
        allocator.free(value.detail);
    }
    allocator.free(values);
}

fn resultFingerprint(
    resolutions: []const Resolution,
    candidates: []const Candidate,
    diagnostics: []const Diagnostic,
    summary: Summary,
    corpus_fingerprint: [32]u8,
    module_fingerprint: [32]u8,
) [32]u8 {
    var hasher = std.crypto.hash.sha2.Sha256.init(.{});
    updateBytes(&hasher, schema);
    updateBytes(&hasher, resolver_version);
    hasher.update(&corpus_fingerprint);
    hasher.update(&module_fingerprint);
    updateU64(&hasher, summary.facts);
    updateU64(&hasher, summary.resolved);
    updateU64(&hasher, summary.ambiguous);
    updateU64(&hasher, summary.unresolved);
    updateU64(&hasher, summary.invalid);
    updateU64(&hasher, summary.exhausted);
    updateU64(&hasher, summary.candidates);
    updateU64(&hasher, summary.diagnostics);
    for (resolutions) |resolution| {
        updateU64(&hasher, @intFromEnum(resolution.kind));
        updateBytes(&hasher, resolution.source_path);
        updateBytes(&hasher, resolution.subject);
        updateBytes(&hasher, resolution.enclosing_declaration);
        updateSpan(&hasher, resolution.span);
        updateU64(&hasher, @intFromEnum(resolution.status));
        updateU64(&hasher, resolution.candidate_start);
        updateU64(&hasher, resolution.candidate_count);
    }
    for (candidates) |candidate| {
        updateU64(&hasher, candidate.resolution_index);
        updateBytes(&hasher, candidate.target_path);
        updateBytes(&hasher, candidate.target_enclosing_declaration);
        updateBytes(&hasher, candidate.target_name);
        updateU64(&hasher, @intFromEnum(candidate.reason));
        updateU64(&hasher, candidate.rank);
    }
    for (diagnostics) |diagnostic| {
        updateU64(&hasher, @intFromEnum(diagnostic.kind));
        updateBytes(&hasher, diagnostic.source_path);
        updateBytes(&hasher, diagnostic.detail);
    }
    var digest: [32]u8 = @splat(0);
    hasher.final(&digest);
    return digest;
}

fn updateSpan(hasher: *std.crypto.hash.sha2.Sha256, span: typescript_parser.Span) void {
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
