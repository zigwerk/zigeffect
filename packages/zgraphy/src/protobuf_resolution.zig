const std = @import("std");
const parser = @import("protobuf_parser.zig");
const owned = @import("memory.zig");

pub const schema = "zgraphy.protobuf-resolution.v1";
pub const schema_version: u32 = 1;
pub const resolver_version = "proto-lexical-import-v1";

pub const EntityKind = enum(u8) {
    package,
    message,
    enumeration,
    service,
    operation,
    field,
    enum_value,
};

pub const ReferenceKind = enum(u8) {
    rpc_request,
    rpc_response,
    field_type,
};

pub const Status = enum(u8) {
    resolved,
    unresolved,
    external,
    ambiguous,
};

pub const DiagnosticKind = enum(u8) {
    duplicate_definition,
    unresolved_type,
    ambiguous_type,
    ambiguous_import_path,
};

pub const Entity = struct {
    source_path: []const u8,
    kind: EntityKind,
    canonical_name: []const u8,
    display_name: []const u8,
    number: i64 = 0,
    span: parser.Span,
};

pub const Reference = struct {
    source_path: []const u8,
    owner: []const u8,
    target: []const u8,
    kind: ReferenceKind,
    status: Status,
    span: parser.Span,
    candidate_start: usize,
    candidate_count: usize,
};

pub const Candidate = struct {
    reference_index: usize,
    entity_index: usize,
    target_path: []const u8,
    target_kind: EntityKind,
    canonical_name: []const u8,
    rank: usize,
};

pub const Diagnostic = struct {
    kind: DiagnosticKind,
    source_path: []const u8,
    detail: []const u8,
};

pub const Summary = struct {
    files: usize = 0,
    entities: usize = 0,
    references: usize = 0,
    resolved: usize = 0,
    unresolved: usize = 0,
    external: usize = 0,
    ambiguous: usize = 0,
    candidates: usize = 0,
    diagnostics: usize = 0,
};

pub const Result = struct {
    allocator: std.mem.Allocator,
    entities: []Entity,
    references: []Reference,
    candidates: []Candidate,
    diagnostics: []Diagnostic,
    summary: Summary,
    fingerprint: [32]u8,

    pub fn deinit(self: *Result) void {
        deinitEntities(self.allocator, self.entities);
        for (self.references) |reference| {
            self.allocator.free(reference.source_path);
            self.allocator.free(reference.owner);
            self.allocator.free(reference.target);
        }
        self.allocator.free(self.references);
        self.allocator.free(self.candidates);
        for (self.diagnostics) |diagnostic| {
            self.allocator.free(diagnostic.source_path);
            self.allocator.free(diagnostic.detail);
        }
        self.allocator.free(self.diagnostics);
        self.entities = &.{};
        self.references = &.{};
        self.candidates = &.{};
        self.diagnostics = &.{};
    }

    pub fn findEntity(self: *const Result, kind: EntityKind, canonical_name: []const u8) ?*const Entity {
        for (self.entities, 0..) |entity, index| {
            if (entity.kind == kind and std.mem.eql(u8, entity.canonical_name, canonical_name)) return &self.entities[index];
        }
        return null;
    }

    pub fn findReference(self: *const Result, kind: ReferenceKind, owner: []const u8) ?*const Reference {
        for (self.references, 0..) |reference, index| {
            if (reference.kind == kind and std.mem.eql(u8, reference.owner, owner)) return &self.references[index];
        }
        return null;
    }

    pub fn candidatesFor(self: *const Result, reference: *const Reference) []const Candidate {
        return self.candidates[reference.candidate_start..][0..reference.candidate_count];
    }
};

pub const Options = struct {
    max_files: usize = 100_000,
    max_entities: usize = 1_000_000,
    max_references: usize = 1_000_000,
    max_candidates: usize = 4_000_000,
    max_diagnostics: usize = 100_000,
    max_result_bytes: usize = 512 * 1024 * 1024,
    parser: parser.Options = .{},
};

const File = struct {
    path: []const u8,
    parsed: parser.Result,
};

pub const Corpus = struct {
    allocator: std.mem.Allocator,
    options: Options,
    files: std.ArrayList(File) = .empty,

    pub fn init(allocator: std.mem.Allocator, options: Options) !Corpus {
        if (options.max_files == 0 or options.max_entities == 0 or options.max_references == 0 or
            options.max_candidates == 0 or options.max_diagnostics == 0 or options.max_result_bytes == 0)
        {
            return error.InvalidProtoResolutionOptions;
        }
        try options.parser.validate();
        return .{ .allocator = allocator, .options = options };
    }

    pub fn deinit(self: *Corpus) void {
        for (self.files.items) |*file| {
            self.allocator.free(file.path);
            file.parsed.deinit();
        }
        self.files.deinit(self.allocator);
    }

    pub fn addSource(self: *Corpus, path: []const u8, source: []const u8) !void {
        var parsed = try parser.parse(self.allocator, path, source, self.options.parser);
        errdefer parsed.deinit();
        try self.addParsedOwned(&parsed);
    }

    pub fn addParsedOwned(self: *Corpus, parsed: *parser.Result) !void {
        try parsed.validate();
        if (!validPath(parsed.path)) return error.InvalidProtoResolutionPath;
        for (self.files.items) |file| if (std.mem.eql(u8, file.path, parsed.path)) return error.DuplicateProtoResolutionFile;
        if (self.files.items.len >= self.options.max_files) return error.ProtoResolutionFileLimitExceeded;
        const copied_path = try owned.copy(u8, self.allocator, parsed.path);
        errdefer self.allocator.free(copied_path);
        try self.files.append(self.allocator, .{ .path = copied_path, .parsed = parsed.* });
        parsed.path = "";
        parsed.declarations = &.{};
        parsed.imports = &.{};
        parsed.import_bindings = &.{};
        parsed.exports = &.{};
        parsed.type_bindings = &.{};
        parsed.calls = &.{};
        parsed.call_arguments = &.{};
        parsed.call_bindings = &.{};
        parsed.protocol_packages = &.{};
        parsed.protocol_fields = &.{};
        parsed.protocol_enum_values = &.{};
        parsed.protocol_rpcs = &.{};
        parsed.owns_memory = false;
    }

    pub fn parsedCount(self: *const Corpus) usize {
        return self.files.items.len;
    }

    pub fn parsedAt(self: *const Corpus, index: usize) ?*const parser.Result {
        if (index >= self.files.items.len) return null;
        return &self.files.items[index].parsed;
    }

    pub fn parsedForPath(self: *const Corpus, path: []const u8) ?*const parser.Result {
        for (self.files.items) |*file| if (std.mem.eql(u8, file.path, path)) return &file.parsed;
        return null;
    }

    pub fn resolve(self: *const Corpus) !Result {
        const file_order = try owned.slice(usize, self.allocator, self.files.items.len);
        defer self.allocator.free(file_order);
        for (file_order, 0..) |*slot, index| slot.* = index;
        std.mem.sort(usize, file_order, self, lessThanFileIndex);

        var entities = std.ArrayList(Entity).empty;
        errdefer deinitEntityList(self.allocator, &entities);
        for (file_order) |file_index| try appendFileEntities(self, &self.files.items[file_index], &entities);
        if (entities.items.len > self.options.max_entities) return error.ProtoResolutionEntityLimitExceeded;

        var references = std.ArrayList(Reference).empty;
        errdefer deinitReferenceList(self.allocator, &references);
        var candidates = std.ArrayList(Candidate).empty;
        errdefer candidates.deinit(self.allocator);
        var diagnostics = std.ArrayList(Diagnostic).empty;
        errdefer deinitDiagnosticList(self.allocator, &diagnostics);

        for (file_order) |file_index| {
            const file = &self.files.items[file_index];
            const package_name = packageFor(file);
            for (file.parsed.protocol_rpcs) |rpc| {
                const service = try canonical(self.allocator, package_name, rpc.service);
                defer self.allocator.free(service);
                const operation = try std.fmt.allocPrint(self.allocator, "{s}/{s}", .{ service, rpc.name });
                defer self.allocator.free(operation);
                try appendReference(self, file, entities.items, &references, &candidates, &diagnostics, .rpc_request, operation, rpc.service, rpc.request_type, rpc.request_span);
                try appendReference(self, file, entities.items, &references, &candidates, &diagnostics, .rpc_response, operation, rpc.service, rpc.response_type, rpc.response_span);
            }
            for (file.parsed.protocol_fields) |field| {
                if (isScalar(field.type_name)) continue;
                const message = try canonical(self.allocator, package_name, field.owner);
                defer self.allocator.free(message);
                const field_identity = try std.fmt.allocPrint(self.allocator, "{s}#{d}", .{ message, field.number });
                defer self.allocator.free(field_identity);
                try appendReference(self, file, entities.items, &references, &candidates, &diagnostics, .field_type, field_identity, field.owner, field.type_name, field.type_span);
            }
        }
        if (references.items.len > self.options.max_references) return error.ProtoResolutionReferenceLimitExceeded;
        if (candidates.items.len > self.options.max_candidates) return error.ProtoResolutionCandidateLimitExceeded;

        try appendDuplicateDiagnostics(self, entities.items, &diagnostics);
        const entity_slice = try entities.toOwnedSlice(self.allocator);
        errdefer deinitEntities(self.allocator, entity_slice);
        const reference_slice = try references.toOwnedSlice(self.allocator);
        errdefer deinitReferences(self.allocator, reference_slice);
        const candidate_slice = try candidates.toOwnedSlice(self.allocator);
        errdefer self.allocator.free(candidate_slice);
        const diagnostic_slice = try diagnostics.toOwnedSlice(self.allocator);
        errdefer deinitDiagnostics(self.allocator, diagnostic_slice);
        const summary = summarize(self.files.items.len, reference_slice, entity_slice.len, candidate_slice.len, diagnostic_slice.len);
        if (estimatedBytes(entity_slice, reference_slice, candidate_slice, diagnostic_slice) > self.options.max_result_bytes) return error.ProtoResolutionResultLimitExceeded;
        var result = Result{
            .allocator = self.allocator,
            .entities = entity_slice,
            .references = reference_slice,
            .candidates = candidate_slice,
            .diagnostics = diagnostic_slice,
            .summary = summary,
            .fingerprint = fingerprint(entity_slice, reference_slice, candidate_slice, diagnostic_slice, summary),
        };
        errdefer result.deinit();
        try validate(&result);
        return result;
    }
};

pub fn validate(result: *const Result) !void {
    if (result.summary.entities != result.entities.len or result.summary.references != result.references.len or
        result.summary.candidates != result.candidates.len or result.summary.diagnostics != result.diagnostics.len)
    {
        return error.InvalidProtoResolutionSummary;
    }
    for (result.entities) |entity| {
        if (!validPath(entity.source_path) or entity.canonical_name.len == 0 or entity.display_name.len == 0 or !entity.span.valid(std.math.maxInt(usize))) {
            return error.InvalidProtoResolutionEntity;
        }
    }
    for (result.references, 0..) |reference, index| {
        if (!validPath(reference.source_path) or reference.owner.len == 0 or reference.target.len == 0 or
            reference.candidate_start + reference.candidate_count > result.candidates.len)
        {
            return error.InvalidProtoResolutionReference;
        }
        for (result.candidatesFor(&reference)) |candidate| {
            if (candidate.reference_index != index or candidate.entity_index >= result.entities.len) return error.InvalidProtoResolutionCandidate;
            const entity = result.entities[candidate.entity_index];
            if (!std.mem.eql(u8, candidate.target_path, entity.source_path) or candidate.target_kind != entity.kind or
                !std.mem.eql(u8, candidate.canonical_name, entity.canonical_name)) return error.InvalidProtoResolutionCandidate;
        }
        const expected_status: Status = if (reference.candidate_count == 0)
            (if (isExternal(reference.target)) .external else .unresolved)
        else if (reference.candidate_count == 1)
            .resolved
        else
            .ambiguous;
        if (reference.status != expected_status) return error.InvalidProtoResolutionStatus;
    }
    const expected = fingerprint(result.entities, result.references, result.candidates, result.diagnostics, result.summary);
    if (!std.mem.eql(u8, &expected, &result.fingerprint)) return error.InvalidProtoResolutionFingerprint;
}

fn appendFileEntities(corpus: *const Corpus, file: *const File, entities: *std.ArrayList(Entity)) !void {
    const package_name = packageFor(file);
    if (file.parsed.findProtocolPackage()) |package| {
        try appendEntity(corpus.allocator, entities, file.path, .package, package.name, package.name, 0, package.span);
    }
    for (file.parsed.declarations) |declaration| switch (declaration.kind) {
        .message => {
            const name = try canonical(corpus.allocator, package_name, declaration.name);
            defer corpus.allocator.free(name);
            try appendEntity(corpus.allocator, entities, file.path, .message, name, declaration.name, 0, declaration.span);
        },
        .enumeration => {
            const name = try canonical(corpus.allocator, package_name, declaration.name);
            defer corpus.allocator.free(name);
            try appendEntity(corpus.allocator, entities, file.path, .enumeration, name, declaration.name, 0, declaration.span);
        },
        .service => {
            const name = try canonical(corpus.allocator, package_name, declaration.name);
            defer corpus.allocator.free(name);
            try appendEntity(corpus.allocator, entities, file.path, .service, name, declaration.name, 0, declaration.span);
        },
        else => {},
    };
    for (file.parsed.protocol_rpcs) |rpc| {
        const service = try canonical(corpus.allocator, package_name, rpc.service);
        defer corpus.allocator.free(service);
        const name = try std.fmt.allocPrint(corpus.allocator, "{s}/{s}", .{ service, rpc.name });
        defer corpus.allocator.free(name);
        try appendEntity(corpus.allocator, entities, file.path, .operation, name, rpc.name, 0, rpc.span);
    }
    for (file.parsed.protocol_fields) |field| {
        const message = try canonical(corpus.allocator, package_name, field.owner);
        defer corpus.allocator.free(message);
        const name = try std.fmt.allocPrint(corpus.allocator, "{s}#{d}", .{ message, field.number });
        defer corpus.allocator.free(name);
        const label = try std.fmt.allocPrint(corpus.allocator, "{s}.{s}", .{ message, field.name });
        defer corpus.allocator.free(label);
        try appendEntity(corpus.allocator, entities, file.path, .field, name, label, field.number, field.span);
    }
    for (file.parsed.protocol_enum_values) |value| {
        const enum_name = try canonical(corpus.allocator, package_name, value.owner);
        defer corpus.allocator.free(enum_name);
        const name = try std.fmt.allocPrint(corpus.allocator, "{s}.{s}", .{ enum_name, value.name });
        defer corpus.allocator.free(name);
        try appendEntity(corpus.allocator, entities, file.path, .enum_value, name, value.name, value.number, value.span);
    }
}

fn appendEntity(
    allocator: std.mem.Allocator,
    entities: *std.ArrayList(Entity),
    source_path: []const u8,
    kind: EntityKind,
    canonical_name: []const u8,
    display_name: []const u8,
    number: i64,
    span: parser.Span,
) !void {
    const path_copy = try owned.copy(u8, allocator, source_path);
    errdefer allocator.free(path_copy);
    const canonical_copy = try owned.copy(u8, allocator, canonical_name);
    errdefer allocator.free(canonical_copy);
    const display_name_copy = try owned.copy(u8, allocator, display_name);
    errdefer allocator.free(display_name_copy);
    try entities.append(allocator, .{
        .source_path = path_copy,
        .kind = kind,
        .canonical_name = canonical_copy,
        .display_name = display_name_copy,
        .number = number,
        .span = span,
    });
}

fn appendReference(
    corpus: *const Corpus,
    file: *const File,
    entities: []const Entity,
    references: *std.ArrayList(Reference),
    candidates: *std.ArrayList(Candidate),
    diagnostics: *std.ArrayList(Diagnostic),
    kind: ReferenceKind,
    owner_name: []const u8,
    lexical_scope: []const u8,
    target: []const u8,
    span: parser.Span,
) !void {
    const reference_index = references.items.len;
    const candidate_start = candidates.items.len;
    var names = try candidateNames(corpus.allocator, packageFor(file), lexical_scope, target);
    defer deinitNames(corpus.allocator, &names);
    for (names.items, 0..) |name, rank| {
        for (entities, 0..) |entity, entity_index| {
            if ((entity.kind != .message and entity.kind != .enumeration) or !std.mem.eql(u8, entity.canonical_name, name)) continue;
            if (!reachable(corpus, file, entity.source_path)) continue;
            var duplicate = false;
            for (candidates.items[candidate_start..]) |candidate| if (candidate.entity_index == entity_index) {
                duplicate = true;
                break;
            };
            if (!duplicate) try candidates.append(corpus.allocator, .{
                .reference_index = reference_index,
                .entity_index = entity_index,
                .target_path = entity.source_path,
                .target_kind = entity.kind,
                .canonical_name = entity.canonical_name,
                .rank = rank,
            });
        }
        if (candidates.items.len > candidate_start) break;
    }
    const candidate_count = candidates.items.len - candidate_start;
    const status: Status = if (candidate_count == 0)
        (if (isExternal(target)) .external else .unresolved)
    else if (candidate_count == 1)
        .resolved
    else
        .ambiguous;
    const source_copy = try owned.copy(u8, corpus.allocator, file.path);
    errdefer corpus.allocator.free(source_copy);
    const owner_copy = try owned.copy(u8, corpus.allocator, owner_name);
    errdefer corpus.allocator.free(owner_copy);
    const target_copy = try owned.copy(u8, corpus.allocator, target);
    errdefer corpus.allocator.free(target_copy);
    try references.append(corpus.allocator, .{
        .source_path = source_copy,
        .owner = owner_copy,
        .target = target_copy,
        .kind = kind,
        .status = status,
        .span = span,
        .candidate_start = candidate_start,
        .candidate_count = candidate_count,
    });
    if (status == .unresolved or status == .ambiguous) {
        const diagnostic_kind: DiagnosticKind = if (status == .ambiguous) .ambiguous_type else .unresolved_type;
        try appendDiagnostic(corpus, diagnostics, diagnostic_kind, file.path, target);
    }
}

fn candidateNames(allocator: std.mem.Allocator, package_name: []const u8, lexical_owner: []const u8, target: []const u8) !std.ArrayList([]const u8) {
    var names = std.ArrayList([]const u8).empty;
    errdefer deinitNames(allocator, &names);
    if (target.len > 0 and target[0] == '.') {
        try names.append(allocator, try owned.copy(u8, allocator, target[1..]));
        return names;
    }
    var owner = lexical_owner;
    while (owner.len > 0) {
        const scoped = if (package_name.len == 0)
            try std.fmt.allocPrint(allocator, "{s}.{s}", .{ owner, target })
        else
            try std.fmt.allocPrint(allocator, "{s}.{s}.{s}", .{ package_name, owner, target });
        try names.append(allocator, scoped);
        owner = if (std.mem.lastIndexOfScalar(u8, owner, '.')) |dot| owner[0..dot] else "";
    }
    const package_scoped = if (package_name.len == 0)
        try owned.copy(u8, allocator, target)
    else
        try std.fmt.allocPrint(allocator, "{s}.{s}", .{ package_name, target });
    try names.append(allocator, package_scoped);
    // A dotted relative name may identify a declaration in an imported
    // package. It is only considered after lexical/current-package forms and
    // `reachable` still requires exact import evidence, so this is not a
    // repository-global name fallback.
    if (std.mem.indexOfScalar(u8, target, '.') != null and !std.mem.eql(u8, package_scoped, target)) {
        try names.append(allocator, try owned.copy(u8, allocator, target));
    }
    return names;
}

fn reachable(corpus: *const Corpus, source: *const File, target_path: []const u8) bool {
    if (std.mem.eql(u8, source.path, target_path)) return true;
    for (source.parsed.imports) |import| {
        for (corpus.files.items) |*imported| {
            if (!pathMatches(imported.path, import.target)) continue;
            if (std.mem.eql(u8, imported.path, target_path)) return true;
            if (reachableThroughPublicImports(corpus, imported, target_path, 1)) return true;
        }
    }
    return false;
}

fn reachableThroughPublicImports(corpus: *const Corpus, source: *const File, target_path: []const u8, depth: usize) bool {
    if (depth > corpus.files.items.len) return false;
    for (source.parsed.imports) |import| {
        if (import.kind != .proto_public) continue;
        for (corpus.files.items) |*imported| {
            if (!pathMatches(imported.path, import.target)) continue;
            if (std.mem.eql(u8, imported.path, target_path)) return true;
            if (reachableThroughPublicImports(corpus, imported, target_path, depth + 1)) return true;
        }
    }
    return false;
}

fn pathMatches(path: []const u8, import_target: []const u8) bool {
    if (std.mem.eql(u8, path, import_target)) return true;
    if (!std.mem.endsWith(u8, path, import_target) or path.len <= import_target.len) return false;
    return path[path.len - import_target.len - 1] == '/';
}

fn appendDuplicateDiagnostics(corpus: *const Corpus, entities: []const Entity, diagnostics: *std.ArrayList(Diagnostic)) !void {
    for (entities, 0..) |entity, index| {
        if (entity.kind == .package or entity.kind == .field or entity.kind == .enum_value) continue;
        var first = true;
        for (entities[0..index]) |prior| {
            if (prior.kind == entity.kind and std.mem.eql(u8, prior.canonical_name, entity.canonical_name)) {
                first = false;
                break;
            }
        }
        if (!first) try appendDiagnostic(corpus, diagnostics, .duplicate_definition, entity.source_path, entity.canonical_name);
    }
}

fn appendDiagnostic(corpus: *const Corpus, diagnostics: *std.ArrayList(Diagnostic), kind: DiagnosticKind, path: []const u8, detail: []const u8) !void {
    if (diagnostics.items.len >= corpus.options.max_diagnostics) return error.ProtoResolutionDiagnosticLimitExceeded;
    const path_copy = try owned.copy(u8, corpus.allocator, path);
    errdefer corpus.allocator.free(path_copy);
    const detail_copy = try owned.copy(u8, corpus.allocator, detail);
    errdefer corpus.allocator.free(detail_copy);
    try diagnostics.append(corpus.allocator, .{ .kind = kind, .source_path = path_copy, .detail = detail_copy });
}

fn packageFor(file: *const File) []const u8 {
    return if (file.parsed.findProtocolPackage()) |package| package.name else "";
}

fn canonical(allocator: std.mem.Allocator, package_name: []const u8, lexical_name: []const u8) ![]u8 {
    if (package_name.len == 0) return owned.copy(u8, allocator, lexical_name);
    return std.fmt.allocPrint(allocator, "{s}.{s}", .{ package_name, lexical_name });
}

fn isScalar(value: []const u8) bool {
    for ([_][]const u8{
        "double",   "float",    "int32", "int64",  "uint32", "uint64", "sint32", "sint64", "fixed32", "fixed64",
        "sfixed32", "sfixed64", "bool",  "string", "bytes",
    }) |scalar| if (std.mem.eql(u8, value, scalar)) return true;
    return false;
}

fn isExternal(value: []const u8) bool {
    const normalized = if (value.len > 0 and value[0] == '.') value[1..] else value;
    return std.mem.startsWith(u8, normalized, "google.protobuf.");
}

fn summarize(files: usize, references: []const Reference, entity_count: usize, candidate_count: usize, diagnostic_count: usize) Summary {
    var summary = Summary{
        .files = files,
        .entities = entity_count,
        .references = references.len,
        .candidates = candidate_count,
        .diagnostics = diagnostic_count,
    };
    for (references) |reference| switch (reference.status) {
        .resolved => summary.resolved += 1,
        .unresolved => summary.unresolved += 1,
        .external => summary.external += 1,
        .ambiguous => summary.ambiguous += 1,
    };
    return summary;
}

fn fingerprint(entities: []const Entity, references: []const Reference, candidates: []const Candidate, diagnostics: []const Diagnostic, summary: Summary) [32]u8 {
    var hasher = std.crypto.hash.sha2.Sha256.init(.{});
    updateBytes(&hasher, schema);
    updateBytes(&hasher, resolver_version);
    for (entities) |entity| {
        updateBytes(&hasher, entity.source_path);
        updateU64(&hasher, @intFromEnum(entity.kind));
        updateBytes(&hasher, entity.canonical_name);
        updateBytes(&hasher, entity.display_name);
        updateI64(&hasher, entity.number);
    }
    for (references) |reference| {
        updateBytes(&hasher, reference.source_path);
        updateBytes(&hasher, reference.owner);
        updateBytes(&hasher, reference.target);
        updateU64(&hasher, @intFromEnum(reference.kind));
        updateU64(&hasher, @intFromEnum(reference.status));
        updateU64(&hasher, reference.candidate_start);
        updateU64(&hasher, reference.candidate_count);
    }
    for (candidates) |candidate| {
        updateU64(&hasher, candidate.reference_index);
        updateU64(&hasher, candidate.entity_index);
        updateBytes(&hasher, candidate.target_path);
        updateU64(&hasher, @intFromEnum(candidate.target_kind));
        updateBytes(&hasher, candidate.canonical_name);
        updateU64(&hasher, candidate.rank);
    }
    for (diagnostics) |diagnostic| {
        updateU64(&hasher, @intFromEnum(diagnostic.kind));
        updateBytes(&hasher, diagnostic.source_path);
        updateBytes(&hasher, diagnostic.detail);
    }
    updateU64(&hasher, summary.files);
    updateU64(&hasher, summary.entities);
    updateU64(&hasher, summary.references);
    updateU64(&hasher, summary.resolved);
    updateU64(&hasher, summary.unresolved);
    updateU64(&hasher, summary.external);
    updateU64(&hasher, summary.ambiguous);
    updateU64(&hasher, summary.candidates);
    updateU64(&hasher, summary.diagnostics);
    var digest: [32]u8 = @splat(0);
    hasher.final(&digest);
    return digest;
}

fn estimatedBytes(entities: []const Entity, references: []const Reference, candidates: []const Candidate, diagnostics: []const Diagnostic) usize {
    var total = entities.len * @sizeOf(Entity) + references.len * @sizeOf(Reference) + candidates.len * @sizeOf(Candidate) + diagnostics.len * @sizeOf(Diagnostic);
    for (entities) |entity| total += entity.source_path.len + entity.canonical_name.len + entity.display_name.len;
    for (references) |reference| total += reference.source_path.len + reference.owner.len + reference.target.len;
    for (diagnostics) |diagnostic| total += diagnostic.source_path.len + diagnostic.detail.len;
    return total;
}

fn deinitNames(allocator: std.mem.Allocator, names: *std.ArrayList([]const u8)) void {
    for (names.items) |name| allocator.free(name);
    names.deinit(allocator);
}

fn deinitEntityList(allocator: std.mem.Allocator, entities: *std.ArrayList(Entity)) void {
    for (entities.items) |entity| {
        allocator.free(entity.source_path);
        allocator.free(entity.canonical_name);
        allocator.free(entity.display_name);
    }
    entities.deinit(allocator);
}

fn deinitEntities(allocator: std.mem.Allocator, entities: []Entity) void {
    for (entities) |entity| {
        allocator.free(entity.source_path);
        allocator.free(entity.canonical_name);
        allocator.free(entity.display_name);
    }
    allocator.free(entities);
}

fn deinitReferenceList(allocator: std.mem.Allocator, references: *std.ArrayList(Reference)) void {
    for (references.items) |reference| {
        allocator.free(reference.source_path);
        allocator.free(reference.owner);
        allocator.free(reference.target);
    }
    references.deinit(allocator);
}

fn deinitReferences(allocator: std.mem.Allocator, references: []Reference) void {
    for (references) |reference| {
        allocator.free(reference.source_path);
        allocator.free(reference.owner);
        allocator.free(reference.target);
    }
    allocator.free(references);
}

fn deinitDiagnosticList(allocator: std.mem.Allocator, diagnostics: *std.ArrayList(Diagnostic)) void {
    for (diagnostics.items) |diagnostic| {
        allocator.free(diagnostic.source_path);
        allocator.free(diagnostic.detail);
    }
    diagnostics.deinit(allocator);
}

fn deinitDiagnostics(allocator: std.mem.Allocator, diagnostics: []Diagnostic) void {
    for (diagnostics) |diagnostic| {
        allocator.free(diagnostic.source_path);
        allocator.free(diagnostic.detail);
    }
    allocator.free(diagnostics);
}

fn validPath(path: []const u8) bool {
    if (path.len == 0 or std.fs.path.isAbsolute(path) or std.mem.indexOfScalar(u8, path, '\\') != null) return false;
    var parts = std.mem.splitScalar(u8, path, '/');
    while (parts.next()) |part| if (part.len == 0 or std.mem.eql(u8, part, ".") or std.mem.eql(u8, part, "..")) return false;
    return true;
}

fn lessThanFileIndex(corpus: *const Corpus, left: usize, right: usize) bool {
    return std.mem.lessThan(u8, corpus.files.items[left].path, corpus.files.items[right].path);
}

fn updateBytes(hasher: *std.crypto.hash.sha2.Sha256, value: []const u8) void {
    updateU64(hasher, value.len);
    hasher.update(value);
}

fn updateU64(hasher: *std.crypto.hash.sha2.Sha256, value: u64) void {
    var bytes: [8]u8 = @splat(0);
    std.mem.writeInt(u64, &bytes, value, .little);
    hasher.update(&bytes);
}

fn updateI64(hasher: *std.crypto.hash.sha2.Sha256, value: i64) void {
    var bytes: [8]u8 = @splat(0);
    std.mem.writeInt(i64, &bytes, value, .little);
    hasher.update(&bytes);
}
