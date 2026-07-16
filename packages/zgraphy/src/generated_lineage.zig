const std = @import("std");
const proto = @import("protobuf_resolution.zig");
const owned = @import("memory.zig");

pub const schema = "zgraphy.generated-protobuf-lineage.v1";
pub const schema_version: u32 = 1;
pub const analyzer_version = "strict-generator-marker-v1";

pub const Generator = enum(u8) {
    protobuf_es,
    protoc_gen_zig,
};

pub const Language = enum(u8) {
    typescript,
    zig,
};

pub const LinkKind = enum(u8) {
    file,
    message,
    enumeration,
    service,
    operation,
};

pub const BindingKind = LinkKind;

pub const Direction = enum(u8) {
    generated_from,
    generated_client_for,
    generated_server_for,
};

pub const Status = enum(u8) {
    resolved,
    ambiguous,
    unresolved,
};

pub const Document = struct {
    path: []const u8,
    source: []const u8,
    language: Language,
    is_generated: bool,
};

pub const Link = struct {
    language: Language,
    generated_path: []const u8,
    generated_symbol: []const u8,
    canonical_name: []const u8,
    generator: Generator,
    kind: LinkKind,
    direction: Direction,
    status: Status,
    candidate_start: usize,
    candidate_count: usize,
};

pub const Binding = Link;

pub const Candidate = struct {
    link_index: usize,
    entity_index: usize,
};

pub const Summary = struct {
    documents: usize = 0,
    accepted_documents: usize = 0,
    rejected_documents: usize = 0,
    links: usize = 0,
    resolved: usize = 0,
    ambiguous: usize = 0,
    unresolved: usize = 0,
    candidates: usize = 0,
};

pub const Result = struct {
    allocator: std.mem.Allocator,
    links: []Link,
    bindings: []Link,
    candidates: []Candidate,
    summary: Summary,
    fingerprint: [32]u8,

    pub fn deinit(self: *Result) void {
        for (self.links) |link| {
            self.allocator.free(link.generated_path);
            if (link.generated_symbol.len > 0) self.allocator.free(link.generated_symbol);
            self.allocator.free(link.canonical_name);
        }
        self.allocator.free(self.links);
        self.allocator.free(self.candidates);
        self.links = &.{};
        self.bindings = &.{};
        self.candidates = &.{};
    }

    pub fn findLink(self: *const Result, path: []const u8, kind: LinkKind, canonical_name: []const u8) ?*const Link {
        for (self.links, 0..) |link, index| {
            if (link.kind == kind and std.mem.eql(u8, link.generated_path, path) and std.mem.eql(u8, link.canonical_name, canonical_name)) {
                return &self.links[index];
            }
        }
        return null;
    }

    pub fn candidatesFor(self: *const Result, link: *const Link) []const Candidate {
        return self.candidates[link.candidate_start..][0..link.candidate_count];
    }

    pub fn findBinding(self: *const Result, language: Language, kind: BindingKind, path: []const u8, canonical_name: []const u8) ?*const Binding {
        for (self.bindings, 0..) |binding, index| {
            if (binding.language == language and binding.kind == kind and std.mem.eql(u8, binding.generated_path, path) and
                std.mem.eql(u8, binding.canonical_name, canonical_name)) return &self.bindings[index];
        }
        return null;
    }
};

pub const Options = struct {
    max_documents: usize = 100_000,
    max_document_bytes: usize = 4 * 1024 * 1024,
    max_links: usize = 1_000_000,
    max_candidates: usize = 4_000_000,
    max_marker_bytes: usize = 4096,
};

const OwnedDocument = struct {
    path: []const u8,
    source: []const u8,
    language: Language,
};

pub const Corpus = struct {
    allocator: std.mem.Allocator,
    options: Options,
    documents: std.ArrayList(OwnedDocument) = .empty,

    pub fn init(allocator: std.mem.Allocator, options: Options) !Corpus {
        if (options.max_documents == 0 or options.max_document_bytes == 0 or options.max_links == 0 or options.max_candidates == 0 or
            options.max_marker_bytes == 0 or options.max_marker_bytes > 64 * 1024)
        {
            return error.InvalidGeneratedLineageOptions;
        }
        return .{ .allocator = allocator, .options = options };
    }

    pub fn deinit(self: *Corpus) void {
        for (self.documents.items) |document| {
            self.allocator.free(document.path);
            self.allocator.free(document.source);
        }
        self.documents.deinit(self.allocator);
    }

    pub fn addSource(self: *Corpus, path: []const u8, source: []const u8, language: Language) !void {
        if (!validPath(path) or source.len == 0 or source.len > self.options.max_document_bytes) return error.InvalidGeneratedLineageDocument;
        for (self.documents.items) |document| if (std.mem.eql(u8, document.path, path)) return error.DuplicateGeneratedLineageDocument;
        if (self.documents.items.len >= self.options.max_documents) return error.GeneratedLineageDocumentLimitExceeded;
        const path_copy = try owned.copy(u8, self.allocator, path);
        errdefer self.allocator.free(path_copy);
        const source_copy = try owned.copy(u8, self.allocator, source);
        errdefer self.allocator.free(source_copy);
        try self.documents.append(self.allocator, .{ .path = path_copy, .source = source_copy, .language = language });
    }

    pub fn resolve(self: *const Corpus, resolution: *const proto.Result) !Result {
        const documents = try owned.slice(Document, self.allocator, self.documents.items.len);
        defer self.allocator.free(documents);
        for (self.documents.items, 0..) |document, index| documents[index] = .{
            .path = document.path,
            .source = document.source,
            .language = document.language,
            .is_generated = generatedPath(document.path),
        };
        return analyze(self.allocator, resolution, documents, self.options);
    }
};

pub fn analyze(allocator: std.mem.Allocator, resolution: *const proto.Result, documents: []const Document, options: Options) !Result {
    try proto.validate(resolution);
    if (options.max_documents == 0 or options.max_document_bytes == 0 or options.max_links == 0 or
        options.max_candidates == 0 or options.max_marker_bytes == 0 or options.max_marker_bytes > 64 * 1024)
    {
        return error.InvalidGeneratedLineageOptions;
    }
    if (documents.len > options.max_documents) return error.GeneratedLineageDocumentLimitExceeded;
    var links = std.ArrayList(Link).empty;
    errdefer deinitLinkList(allocator, &links);
    var candidates = std.ArrayList(Candidate).empty;
    errdefer candidates.deinit(allocator);
    var summary = Summary{ .documents = documents.len };
    const document_order = try owned.slice(usize, allocator, documents.len);
    defer allocator.free(document_order);
    for (document_order, 0..) |*slot, index| slot.* = index;
    std.mem.sort(usize, document_order, documents, lessThanDocumentIndex);
    for (document_order) |document_index| {
        const document = documents[document_index];
        if (!validPath(document.path) or document.source.len == 0 or document.source.len > options.max_document_bytes) {
            return error.InvalidGeneratedLineageDocument;
        }
        if (!document.is_generated) {
            summary.rejected_documents += 1;
            continue;
        }
        if (document.language == .typescript and std.mem.indexOf(u8, document.source, "@generated from file ") != null) {
            if (try analyzeProtobufEs(allocator, resolution, document, options, &links, &candidates)) {
                summary.accepted_documents += 1;
            } else summary.rejected_documents += 1;
        } else if (document.language == .zig and std.mem.indexOf(u8, document.source, "// Code generated by protoc-gen-zig") != null) {
            if (try analyzeProtocZig(allocator, resolution, document, options, &links, &candidates)) {
                summary.accepted_documents += 1;
            } else summary.rejected_documents += 1;
        } else summary.rejected_documents += 1;
        if (links.items.len > options.max_links) return error.GeneratedLineageLinkLimitExceeded;
        if (candidates.items.len > options.max_candidates) return error.GeneratedLineageCandidateLimitExceeded;
    }
    const link_slice = try links.toOwnedSlice(allocator);
    errdefer deinitLinks(allocator, link_slice);
    const candidate_slice = try candidates.toOwnedSlice(allocator);
    errdefer allocator.free(candidate_slice);
    summary.links = link_slice.len;
    summary.candidates = candidate_slice.len;
    for (link_slice) |link| switch (link.status) {
        .resolved => summary.resolved += 1,
        .ambiguous => summary.ambiguous += 1,
        .unresolved => summary.unresolved += 1,
    };
    var result = Result{
        .allocator = allocator,
        .links = link_slice,
        .bindings = link_slice,
        .candidates = candidate_slice,
        .summary = summary,
        .fingerprint = fingerprint(link_slice, candidate_slice, summary),
    };
    errdefer result.deinit();
    try validate(&result, resolution);
    return result;
}

pub fn validate(result: *const Result, resolution: *const proto.Result) !void {
    if (result.summary.links != result.links.len or result.summary.candidates != result.candidates.len or
        result.summary.accepted_documents + result.summary.rejected_documents != result.summary.documents)
    {
        return error.InvalidGeneratedLineageSummary;
    }
    for (result.links, 0..) |link, index| {
        if (!validPath(link.generated_path) or link.canonical_name.len == 0 or link.candidate_start + link.candidate_count > result.candidates.len) {
            return error.InvalidGeneratedLineageLink;
        }
        const expected: Status = if (link.candidate_count == 0) .unresolved else if (link.candidate_count == 1) .resolved else .ambiguous;
        if (link.status != expected) return error.InvalidGeneratedLineageStatus;
        for (result.candidatesFor(&link)) |candidate| {
            if (candidate.link_index != index or candidate.entity_index >= resolution.entities.len) return error.InvalidGeneratedLineageCandidate;
        }
    }
    const expected = fingerprint(result.links, result.candidates, result.summary);
    if (!std.mem.eql(u8, &expected, &result.fingerprint)) return error.InvalidGeneratedLineageFingerprint;
}

fn analyzeProtobufEs(
    allocator: std.mem.Allocator,
    resolution: *const proto.Result,
    document: Document,
    options: Options,
    links: *std.ArrayList(Link),
    candidates: *std.ArrayList(Candidate),
) !bool {
    if (!hasLinePrefix(document.source, "// @generated by protoc-gen-es")) return false;
    const file_marker = markerValue(document.source, "@generated from file ") orelse return false;
    const package_at = std.mem.indexOf(u8, file_marker, " (package ") orelse return false;
    const source_path = std.mem.trim(u8, file_marker[0..package_at], " \t\r*/");
    const package_start = package_at + " (package ".len;
    const package_end_offset = std.mem.indexOfScalar(u8, file_marker[package_start..], ',') orelse return false;
    const package_name = std.mem.trim(u8, file_marker[package_start .. package_start + package_end_offset], " \t\r");
    if (source_path.len == 0 or package_name.len == 0 or source_path.len > options.max_marker_bytes or package_name.len > options.max_marker_bytes) return false;
    try appendLink(allocator, resolution, document.path, "", source_path, package_name, .protobuf_es, .file, .generated_from, source_path, links, candidates);

    const markers = [_]struct { prefix: []const u8, kind: LinkKind, entity: proto.EntityKind, direction: Direction }{
        .{ .prefix = "@generated from message ", .kind = .message, .entity = .message, .direction = .generated_from },
        .{ .prefix = "@generated from enum ", .kind = .enumeration, .entity = .enumeration, .direction = .generated_from },
        .{ .prefix = "@generated from service ", .kind = .service, .entity = .service, .direction = .generated_client_for },
        .{ .prefix = "@generated from rpc ", .kind = .operation, .entity = .operation, .direction = .generated_from },
    };
    var lines = std.mem.splitScalar(u8, document.source, '\n');
    while (lines.next()) |line| for (markers) |marker| {
        const at = std.mem.indexOf(u8, line, marker.prefix) orelse continue;
        var value = std.mem.trim(u8, line[at + marker.prefix.len ..], " \t\r*/");
        if (value.len == 0 or value.len > options.max_marker_bytes) continue;
        var operation_buffer: [4096]u8 = @splat(0);
        if (marker.kind == .operation) {
            const dot = std.mem.lastIndexOfScalar(u8, value, '.') orelse continue;
            value = std.fmt.bufPrint(&operation_buffer, "{s}/{s}", .{ value[0..dot], value[dot + 1 ..] }) catch continue;
        }
        const symbol = lastIdentitySegment(value);
        try appendEntityLink(allocator, resolution, document.path, symbol, value, .protobuf_es, marker.kind, marker.entity, marker.direction, source_path, links, candidates);
    };
    return true;
}

fn analyzeProtocZig(
    allocator: std.mem.Allocator,
    resolution: *const proto.Result,
    document: Document,
    options: Options,
    links: *std.ArrayList(Link),
    candidates: *std.ArrayList(Candidate),
) !bool {
    if (!hasExactLine(document.source, "// Code generated by protoc-gen-zig")) return false;
    const package_marker = markerValue(document.source, "///! package ") orelse return false;
    const package_name = std.mem.trim(u8, package_marker, " \t\r*/");
    if (package_name.len == 0 or package_name.len > options.max_marker_bytes) return false;
    try appendLink(allocator, resolution, document.path, "", package_name, package_name, .protoc_gen_zig, .file, .generated_from, "", links, candidates);
    var lines = std.mem.splitScalar(u8, document.source, '\n');
    while (lines.next()) |line| {
        const trimmed = std.mem.trim(u8, line, " \t\r");
        if (std.mem.startsWith(u8, trimmed, "pub const ")) {
            const rest = trimmed["pub const ".len..];
            const name_end = std.mem.indexOfAny(u8, rest, " =") orelse continue;
            const name = rest[0..name_end];
            if (name.len == 0 or name.len > options.max_marker_bytes) continue;
            const canonical_name = try std.fmt.allocPrint(allocator, "{s}.{s}", .{ package_name, name });
            defer allocator.free(canonical_name);
            const entity_kind: proto.EntityKind = if (std.mem.indexOf(u8, rest, "enum") != null) .enumeration else if (hasEntity(resolution, .service, canonical_name)) .service else .message;
            const link_kind: LinkKind = switch (entity_kind) {
                .enumeration => .enumeration,
                .service => .service,
                else => .message,
            };
            const direction: Direction = if (entity_kind == .service) .generated_server_for else .generated_from;
            try appendEntityLink(allocator, resolution, document.path, name, canonical_name, .protoc_gen_zig, link_kind, entity_kind, direction, "", links, candidates);
        } else if (std.mem.startsWith(u8, trimmed, "pub fn ")) {
            const rest = trimmed["pub fn ".len..];
            const name_end = std.mem.indexOfScalar(u8, rest, '(') orelse continue;
            const name = rest[0..name_end];
            if (name.len == 0 or name.len > options.max_marker_bytes) continue;
            const service_name = try std.fmt.allocPrint(allocator, "{s}.{s}", .{ package_name, name });
            defer allocator.free(service_name);
            if (hasEntity(resolution, .service, service_name)) {
                try appendEntityLink(allocator, resolution, document.path, name, service_name, .protoc_gen_zig, .service, .service, .generated_server_for, "", links, candidates);
            } else {
                try appendUniqueOperationLink(allocator, resolution, document.path, package_name, name, links, candidates);
            }
        } else if (std.mem.indexOf(u8, trimmed, ": *const fn") != null) {
            const colon = std.mem.indexOfScalar(u8, trimmed, ':') orelse continue;
            const name = std.mem.trim(u8, trimmed[0..colon], " \t");
            if (name.len == 0 or name.len > options.max_marker_bytes) continue;
            try appendUniqueOperationLink(allocator, resolution, document.path, package_name, name, links, candidates);
        }
    }
    return true;
}

fn appendUniqueOperationLink(
    allocator: std.mem.Allocator,
    resolution: *const proto.Result,
    path: []const u8,
    package_name: []const u8,
    symbol: []const u8,
    links: *std.ArrayList(Link),
    candidates: *std.ArrayList(Candidate),
) !void {
    var canonical_name: ?[]const u8 = null;
    defer if (canonical_name) |value| allocator.free(value);
    const suffix = try std.fmt.allocPrint(allocator, "/{s}", .{symbol});
    defer allocator.free(suffix);
    for (resolution.entities) |entity| {
        if (entity.kind != .operation or !std.mem.startsWith(u8, entity.canonical_name, package_name) or !std.mem.endsWith(u8, entity.canonical_name, suffix)) continue;
        if (canonical_name != null and !std.mem.eql(u8, canonical_name.?, entity.canonical_name)) return;
        if (canonical_name == null) canonical_name = try owned.copy(u8, allocator, entity.canonical_name);
    }
    if (canonical_name) |value| try appendEntityLink(allocator, resolution, path, symbol, value, .protoc_gen_zig, .operation, .operation, .generated_server_for, "", links, candidates);
}

fn appendEntityLink(
    allocator: std.mem.Allocator,
    resolution: *const proto.Result,
    path: []const u8,
    symbol: []const u8,
    canonical_name: []const u8,
    generator: Generator,
    kind: LinkKind,
    entity_kind: proto.EntityKind,
    direction: Direction,
    required_source_path: []const u8,
    links: *std.ArrayList(Link),
    candidates: *std.ArrayList(Candidate),
) !void {
    const link_index = links.items.len;
    const candidate_start = candidates.items.len;
    for (resolution.entities, 0..) |entity, entity_index| {
        if (entity.kind != entity_kind or !std.mem.eql(u8, entity.canonical_name, canonical_name)) continue;
        if (required_source_path.len > 0 and !pathMatches(entity.source_path, required_source_path)) continue;
        try candidates.append(allocator, .{ .link_index = link_index, .entity_index = entity_index });
    }
    try appendOwnedLink(allocator, path, symbol, canonical_name, generator, kind, direction, candidate_start, candidates.items.len - candidate_start, links);
}

fn appendLink(
    allocator: std.mem.Allocator,
    resolution: *const proto.Result,
    path: []const u8,
    symbol: []const u8,
    canonical_name: []const u8,
    package_name: []const u8,
    generator: Generator,
    kind: LinkKind,
    direction: Direction,
    required_source_path: []const u8,
    links: *std.ArrayList(Link),
    candidates: *std.ArrayList(Candidate),
) !void {
    const link_index = links.items.len;
    const candidate_start = candidates.items.len;
    for (resolution.entities, 0..) |entity, entity_index| {
        if (entity.kind != .package or !std.mem.eql(u8, entity.canonical_name, package_name)) continue;
        if (required_source_path.len > 0 and !pathMatches(entity.source_path, required_source_path)) continue;
        try candidates.append(allocator, .{ .link_index = link_index, .entity_index = entity_index });
    }
    try appendOwnedLink(allocator, path, symbol, canonical_name, generator, kind, direction, candidate_start, candidates.items.len - candidate_start, links);
}

fn appendOwnedLink(
    allocator: std.mem.Allocator,
    path: []const u8,
    symbol: []const u8,
    canonical_name: []const u8,
    generator: Generator,
    kind: LinkKind,
    direction: Direction,
    candidate_start: usize,
    candidate_count: usize,
    links: *std.ArrayList(Link),
) !void {
    const path_copy = try owned.copy(u8, allocator, path);
    errdefer allocator.free(path_copy);
    const symbol_copy = if (symbol.len == 0) @as([]u8, &.{}) else try owned.copy(u8, allocator, symbol);
    errdefer if (symbol_copy.len > 0) allocator.free(symbol_copy);
    const canonical_copy = try owned.copy(u8, allocator, canonical_name);
    errdefer allocator.free(canonical_copy);
    try links.append(allocator, .{
        .language = switch (generator) {
            .protobuf_es => .typescript,
            .protoc_gen_zig => .zig,
        },
        .generated_path = path_copy,
        .generated_symbol = symbol_copy,
        .canonical_name = canonical_copy,
        .generator = generator,
        .kind = kind,
        .direction = direction,
        .status = if (candidate_count == 0) .unresolved else if (candidate_count == 1) .resolved else .ambiguous,
        .candidate_start = candidate_start,
        .candidate_count = candidate_count,
    });
}

fn markerValue(source: []const u8, marker: []const u8) ?[]const u8 {
    const at = std.mem.indexOf(u8, source, marker) orelse return null;
    const start = at + marker.len;
    const tail = source[start..];
    const end = std.mem.indexOfScalar(u8, tail, '\n') orelse tail.len;
    return tail[0..end];
}

fn hasLinePrefix(source: []const u8, prefix: []const u8) bool {
    var lines = std.mem.splitScalar(u8, source, '\n');
    while (lines.next()) |line| {
        if (std.mem.startsWith(u8, std.mem.trim(u8, line, " \t\r"), prefix)) return true;
    }
    return false;
}

fn hasExactLine(source: []const u8, expected: []const u8) bool {
    var lines = std.mem.splitScalar(u8, source, '\n');
    while (lines.next()) |line| {
        if (std.mem.eql(u8, std.mem.trim(u8, line, " \t\r"), expected)) return true;
    }
    return false;
}

fn lastIdentitySegment(value: []const u8) []const u8 {
    if (std.mem.lastIndexOfAny(u8, value, "./")) |index| return value[index + 1 ..];
    return value;
}

fn hasEntity(resolution: *const proto.Result, kind: proto.EntityKind, canonical_name: []const u8) bool {
    return resolution.findEntity(kind, canonical_name) != null;
}

fn pathMatches(path: []const u8, marker_path: []const u8) bool {
    if (std.mem.eql(u8, path, marker_path)) return true;
    if (!std.mem.endsWith(u8, path, marker_path) or path.len <= marker_path.len) return false;
    return path[path.len - marker_path.len - 1] == '/';
}

fn validPath(path: []const u8) bool {
    if (path.len == 0 or std.fs.path.isAbsolute(path) or std.mem.indexOfScalar(u8, path, '\\') != null) return false;
    var parts = std.mem.splitScalar(u8, path, '/');
    while (parts.next()) |part| if (part.len == 0 or std.mem.eql(u8, part, ".") or std.mem.eql(u8, part, "..")) return false;
    return true;
}

fn generatedPath(path: []const u8) bool {
    const basename = std.fs.path.basename(path);
    return std.mem.indexOf(u8, path, "/gen/") != null or std.mem.endsWith(u8, basename, ".pb.ts") or
        std.mem.endsWith(u8, basename, ".pb.zig") or std.mem.indexOf(u8, basename, "_pb.") != null;
}

fn lessThanDocumentIndex(documents: []const Document, left: usize, right: usize) bool {
    const path_order = std.mem.order(u8, documents[left].path, documents[right].path);
    if (path_order != .eq) return path_order == .lt;
    return @intFromEnum(documents[left].language) < @intFromEnum(documents[right].language);
}

fn fingerprint(links: []const Link, candidates: []const Candidate, summary: Summary) [32]u8 {
    var hasher = std.crypto.hash.sha2.Sha256.init(.{});
    updateBytes(&hasher, schema);
    updateBytes(&hasher, analyzer_version);
    for (links) |link| {
        updateU64(&hasher, @intFromEnum(link.language));
        updateBytes(&hasher, link.generated_path);
        updateBytes(&hasher, link.generated_symbol);
        updateBytes(&hasher, link.canonical_name);
        updateU64(&hasher, @intFromEnum(link.generator));
        updateU64(&hasher, @intFromEnum(link.kind));
        updateU64(&hasher, @intFromEnum(link.direction));
        updateU64(&hasher, @intFromEnum(link.status));
        updateU64(&hasher, link.candidate_start);
        updateU64(&hasher, link.candidate_count);
    }
    for (candidates) |candidate| {
        updateU64(&hasher, candidate.link_index);
        updateU64(&hasher, candidate.entity_index);
    }
    updateU64(&hasher, summary.documents);
    updateU64(&hasher, summary.accepted_documents);
    updateU64(&hasher, summary.rejected_documents);
    updateU64(&hasher, summary.links);
    updateU64(&hasher, summary.resolved);
    updateU64(&hasher, summary.ambiguous);
    updateU64(&hasher, summary.unresolved);
    updateU64(&hasher, summary.candidates);
    var digest: [32]u8 = @splat(0);
    hasher.final(&digest);
    return digest;
}

fn deinitLinkList(allocator: std.mem.Allocator, links: *std.ArrayList(Link)) void {
    for (links.items) |link| {
        allocator.free(link.generated_path);
        if (link.generated_symbol.len > 0) allocator.free(link.generated_symbol);
        allocator.free(link.canonical_name);
    }
    links.deinit(allocator);
}

fn deinitLinks(allocator: std.mem.Allocator, links: []Link) void {
    for (links) |link| {
        allocator.free(link.generated_path);
        if (link.generated_symbol.len > 0) allocator.free(link.generated_symbol);
        allocator.free(link.canonical_name);
    }
    allocator.free(links);
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
