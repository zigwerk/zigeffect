const std = @import("std");
const discovery = @import("discovery.zig");
const owned = @import("memory.zig");
const model = @import("model.zig");
const zig_parser = @import("zig_parser.zig");
const typescript_parser = @import("typescript_parser.zig");
const protobuf_parser = @import("protobuf_parser.zig");

pub const entry_schema = "zgraphy.extraction-cache-entry.v2";
pub const manifest_schema = "zgraphy.extraction-manifest.v2";
pub const schema_version: u32 = 2;
pub const recipe = "structural-facts-v2";
pub const cache_root = ".zgraphy/cache/extraction";
pub const max_entry_bytes: usize = 64 * 1024 * 1024;
pub const max_manifest_bytes: usize = 64 * 1024 * 1024;

pub const CacheKind = enum {
    zig,
    document,
};

pub const Stats = struct {
    cacheable_files: usize = 0,
    hits: usize = 0,
    misses: usize = 0,
    rejected: usize = 0,
    writes: usize = 0,
    reparsed_files: usize = 0,
    direct_invalidations: usize = 0,
    invalidation_closure: usize = 0,
};

pub const Options = struct {
    enabled: bool = false,
    previous_manifest: []const u8 = "",
    max_entry_bytes: usize = max_entry_bytes,
    max_manifest_bytes: usize = max_manifest_bytes,
};

pub const Unit = struct {
    path: []const u8,
    language: discovery.Language,
    content_digest: []const u8,
    cache_key: []const u8,
    parser_schema: []const u8,
    parser_id: []const u8,
    parser_version: []const u8,
    structural_fingerprint: []const u8,
    graph_projection_fingerprint: []const u8,
    dependencies: []const []const u8,
};

pub const Manifest = struct {
    allocator: std.mem.Allocator,
    units: []Unit,
    direct_invalidations: []const []const u8,
    invalidation_closure: []const []const u8,
    digest: [32]u8,

    pub fn deinit(self: *Manifest) void {
        deinitUnits(self.allocator, self.units);
        deinitStrings(self.allocator, self.direct_invalidations);
        deinitStrings(self.allocator, self.invalidation_closure);
        self.units = &.{};
        self.direct_invalidations = &.{};
        self.invalidation_closure = &.{};
    }

    pub fn find(self: *const Manifest, path: []const u8) ?*const Unit {
        for (self.units, 0..) |unit, index| {
            if (std.mem.eql(u8, unit.path, path)) return &self.units[index];
        }
        return null;
    }
};

pub const BuildEvidence = struct {
    manifest: Manifest,
    stats: Stats,

    pub fn deinit(self: *BuildEvidence) void {
        self.manifest.deinit();
    }
};

pub const InvalidationPreview = struct {
    allocator: std.mem.Allocator,
    direct: []const []const u8,
    closure: []const []const u8,

    pub fn deinit(self: *InvalidationPreview) void {
        deinitStrings(self.allocator, self.direct);
        deinitStrings(self.allocator, self.closure);
        self.direct = &.{};
        self.closure = &.{};
    }

    pub fn contains(self: *const InvalidationPreview, path: []const u8) bool {
        return containsString(self.closure, path);
    }
};

const ParserLimits = struct {
    max_source_bytes: usize,
    max_nodes: usize = 0,
    max_depth: usize = 0,
    max_facts: usize,
    max_label_bytes: usize,
};

const ZigEntry = struct {
    schema: []const u8,
    schema_version: u32,
    recipe: []const u8,
    kind: CacheKind,
    cache_key: []const u8,
    path: []const u8,
    language: discovery.Language,
    content_digest: []const u8,
    parser_schema: []const u8,
    parser_id: []const u8,
    parser_version: []const u8,
    limits: ParserLimits,
    source_bytes: usize,
    declarations: []const zig_parser.Declaration,
    imports: []const zig_parser.Import,
    calls: []const zig_parser.Call,
    call_arguments: []const zig_parser.CallArgument,
    bindings: []const zig_parser.Binding,
    binding_references: []const zig_parser.BindingReference,
    summary: zig_parser.Summary,
    structural_fingerprint: []const u8,
    graph_projection_fingerprint: []const u8,
    complete: bool,
};

const DocumentEntry = struct {
    schema: []const u8,
    schema_version: u32,
    recipe: []const u8,
    kind: CacheKind,
    cache_key: []const u8,
    path: []const u8,
    language: discovery.Language,
    content_digest: []const u8,
    parser_schema: []const u8,
    parser_id: []const u8,
    parser_version: []const u8,
    limits: ParserLimits,
    mode: typescript_parser.LanguageMode,
    source_bytes: usize,
    declarations: []const typescript_parser.Declaration,
    imports: []const typescript_parser.Import,
    import_bindings: []const typescript_parser.ImportBinding,
    exports: []const typescript_parser.Export,
    type_bindings: []const typescript_parser.TypeBinding,
    calls: []const typescript_parser.Call,
    call_arguments: []const typescript_parser.CallArgument,
    call_bindings: []const typescript_parser.CallBinding,
    protocol_packages: []const protobuf_parser.ProtocolPackage,
    protocol_fields: []const protobuf_parser.ProtocolField,
    protocol_enum_values: []const protobuf_parser.ProtocolEnumValue,
    protocol_rpcs: []const protobuf_parser.ProtocolRpc,
    summary: typescript_parser.Summary,
    structural_fingerprint: []const u8,
    graph_projection_fingerprint: []const u8,
    complete: bool,
};

const DecodedZig = struct {
    result: zig_parser.Result,
    graph_projection_fingerprint: [32]u8,
};

const DecodedDocument = struct {
    result: typescript_parser.Result,
    graph_projection_fingerprint: [32]u8,
};

const ManifestData = struct {
    schema: []const u8,
    schema_version: u32,
    recipe: []const u8,
    units: []const Unit,
    direct_invalidations: []const []const u8,
    invalidation_closure: []const []const u8,
    complete: bool,
};

const UnitBuilder = struct {
    allocator: std.mem.Allocator,
    path: []const u8,
    language: discovery.Language,
    content_digest: [32]u8,
    cache_key: [64]u8,
    parser_schema: []const u8,
    parser_id: []const u8,
    parser_version: []const u8,
    structural_fingerprint: [32]u8,
    graph_projection_fingerprint: [32]u8,
    dependencies: std.ArrayList([]const u8) = .empty,

    fn deinit(self: *UnitBuilder) void {
        self.allocator.free(self.path);
        for (self.dependencies.items) |dependency| self.allocator.free(dependency);
        self.dependencies.deinit(self.allocator);
    }

    fn addDependency(self: *UnitBuilder, path: []const u8) !void {
        if (std.mem.eql(u8, self.path, path)) return;
        for (self.dependencies.items) |existing| if (std.mem.eql(u8, existing, path)) return;
        const copy = try owned.copy(u8, self.allocator, path);
        errdefer self.allocator.free(copy);
        try self.dependencies.append(self.allocator, copy);
    }
};

pub const Session = struct {
    allocator: std.mem.Allocator,
    io: std.Io,
    root: std.Io.Dir,
    options: Options,
    units: std.ArrayList(UnitBuilder) = .empty,
    stats: Stats = .{},

    pub fn init(allocator: std.mem.Allocator, io: std.Io, root: std.Io.Dir, options: Options) !Session {
        if (options.max_entry_bytes == 0 or options.max_manifest_bytes == 0) return error.InvalidExtractionCacheLimits;
        if (options.previous_manifest.len > 0 and !validRelativePath(options.previous_manifest)) return error.InvalidExtractionManifestPath;
        return .{ .allocator = allocator, .io = io, .root = root, .options = options };
    }

    pub fn deinit(self: *Session) void {
        for (self.units.items) |*unit| unit.deinit();
        self.units.deinit(self.allocator);
    }

    pub fn loadZig(
        self: *Session,
        path: []const u8,
        digest: [32]u8,
        source: []const u8,
        options: zig_parser.Options,
    ) !?zig_parser.Result {
        const key = zigKey(path, digest, options);
        if (!self.options.enabled) {
            self.stats.misses += 1;
            return null;
        }
        const cache_path = try entryPathAlloc(self.allocator, &key);
        defer self.allocator.free(cache_path);
        const bytes = self.root.readFileAlloc(self.io, cache_path, self.allocator, .limited(self.options.max_entry_bytes)) catch |failure| switch (failure) {
            error.FileNotFound => {
                self.stats.misses += 1;
                return null;
            },
            error.StreamTooLong => {
                self.stats.misses += 1;
                self.stats.rejected += 1;
                return null;
            },
            else => return failure,
        };
        defer self.allocator.free(bytes);
        const decoded = decodeZig(self.allocator, bytes, path, digest, key, source, options) catch {
            self.stats.misses += 1;
            self.stats.rejected += 1;
            return null;
        };
        var result = decoded.result;
        errdefer result.deinit();
        try self.recordUnit(path, .zig, digest, key, zig_parser.schema, zig_parser.parser_id, zig_parser.parser_version, result.fingerprint, decoded.graph_projection_fingerprint);
        self.stats.hits += 1;
        return result;
    }

    pub fn storeZig(
        self: *Session,
        path: []const u8,
        digest: [32]u8,
        source: []const u8,
        options: zig_parser.Options,
        result: *const zig_parser.Result,
    ) !void {
        const key = zigKey(path, digest, options);
        try zig_parser.validate(result);
        if (!std.mem.eql(u8, result.path, path)) return error.ExtractionCachePathMismatch;
        if (self.options.enabled) {
            const bytes = try encodeZigAlloc(self.allocator, path, digest, key, source, options, result);
            defer self.allocator.free(bytes);
            if (bytes.len > self.options.max_entry_bytes) return error.ExtractionCacheEntryTooLarge;
            const cache_path = try entryPathAlloc(self.allocator, &key);
            defer self.allocator.free(cache_path);
            try atomicWrite(self.allocator, self.io, self.root, cache_path, bytes);
            self.stats.writes += 1;
        }
        const projection = try zigGraphProjectionFingerprint(self.allocator, path, source, result);
        try self.recordUnit(path, .zig, digest, key, zig_parser.schema, zig_parser.parser_id, zig_parser.parser_version, result.fingerprint, projection);
        self.stats.reparsed_files += 1;
    }

    pub fn loadDocument(
        self: *Session,
        path: []const u8,
        language: discovery.Language,
        digest: [32]u8,
        source: []const u8,
        mode: typescript_parser.LanguageMode,
        parser_id: []const u8,
        parser_version: []const u8,
        options: typescript_parser.Options,
    ) !?typescript_parser.Result {
        const key = documentKey(path, language, digest, mode, parser_id, parser_version, options);
        if (!self.options.enabled) {
            self.stats.misses += 1;
            return null;
        }
        const cache_path = try entryPathAlloc(self.allocator, &key);
        defer self.allocator.free(cache_path);
        const bytes = self.root.readFileAlloc(self.io, cache_path, self.allocator, .limited(self.options.max_entry_bytes)) catch |failure| switch (failure) {
            error.FileNotFound => {
                self.stats.misses += 1;
                return null;
            },
            error.StreamTooLong => {
                self.stats.misses += 1;
                self.stats.rejected += 1;
                return null;
            },
            else => return failure,
        };
        defer self.allocator.free(bytes);
        const decoded = decodeDocument(self.allocator, bytes, path, language, digest, key, source, mode, parser_id, parser_version, options) catch {
            self.stats.misses += 1;
            self.stats.rejected += 1;
            return null;
        };
        var result = decoded.result;
        errdefer result.deinit();
        try self.recordUnit(path, language, digest, key, typescript_parser.schema, parser_id, parser_version, result.fingerprint, decoded.graph_projection_fingerprint);
        self.stats.hits += 1;
        return result;
    }

    pub fn storeDocument(
        self: *Session,
        path: []const u8,
        language: discovery.Language,
        digest: [32]u8,
        source: []const u8,
        mode: typescript_parser.LanguageMode,
        parser_id: []const u8,
        parser_version: []const u8,
        options: typescript_parser.Options,
        result: *const typescript_parser.Result,
    ) !void {
        const key = documentKey(path, language, digest, mode, parser_id, parser_version, options);
        try typescript_parser.validate(result);
        if (!std.mem.eql(u8, result.path, path) or result.language != mode or
            !std.mem.eql(u8, result.parser_id, parser_id) or !std.mem.eql(u8, result.parser_version, parser_version))
        {
            return error.ExtractionCacheParserMismatch;
        }
        if (self.options.enabled) {
            const bytes = try encodeDocumentAlloc(self.allocator, path, language, digest, key, source, mode, parser_id, parser_version, options, result);
            defer self.allocator.free(bytes);
            if (bytes.len > self.options.max_entry_bytes) return error.ExtractionCacheEntryTooLarge;
            const cache_path = try entryPathAlloc(self.allocator, &key);
            defer self.allocator.free(cache_path);
            try atomicWrite(self.allocator, self.io, self.root, cache_path, bytes);
            self.stats.writes += 1;
        }
        const projection = try documentGraphProjectionFingerprint(self.allocator, path, source, result);
        try self.recordUnit(path, language, digest, key, typescript_parser.schema, parser_id, parser_version, result.fingerprint, projection);
        self.stats.reparsed_files += 1;
    }

    pub fn finish(self: *Session, graph: *const model.RepositoryGraph) !BuildEvidence {
        try self.prepareDependencies(graph);
        const units = try self.materializeUnits();
        errdefer deinitUnits(self.allocator, units);
        var previous: ?Manifest = try self.readPreviousManifest();
        defer if (previous) |*manifest| manifest.deinit();
        const direct = try directInvalidations(self.allocator, if (previous) |*manifest| manifest.units else &.{}, units);
        errdefer deinitStrings(self.allocator, direct);
        const closure = try invalidationClosure(self.allocator, if (previous) |*manifest| manifest.units else &.{}, units, direct);
        errdefer deinitStrings(self.allocator, closure);
        const digest = manifestFingerprint(units, direct, closure);
        self.stats.cacheable_files = units.len;
        self.stats.direct_invalidations = direct.len;
        self.stats.invalidation_closure = closure.len;
        return .{
            .manifest = .{
                .allocator = self.allocator,
                .units = units,
                .direct_invalidations = direct,
                .invalidation_closure = closure,
                .digest = digest,
            },
            .stats = self.stats,
        };
    }

    pub fn previewInvalidations(self: *Session, graph: *const model.RepositoryGraph) !InvalidationPreview {
        try self.prepareDependencies(graph);
        const units = try self.materializeUnits();
        defer deinitUnits(self.allocator, units);
        var previous: ?Manifest = try self.readPreviousManifest();
        defer if (previous) |*manifest| manifest.deinit();
        const direct = try directInvalidations(self.allocator, if (previous) |*manifest| manifest.units else &.{}, units);
        errdefer deinitStrings(self.allocator, direct);
        const closure = try invalidationClosure(self.allocator, if (previous) |*manifest| manifest.units else &.{}, units, direct);
        return .{ .allocator = self.allocator, .direct = direct, .closure = closure };
    }

    fn prepareDependencies(self: *Session, graph: *const model.RepositoryGraph) !void {
        std.mem.sort(UnitBuilder, self.units.items, {}, lessThanBuilder);
        for (graph.edges.items) |edge| {
            const source_index = self.unitIndex(edge.source_path) orelse continue;
            if (graph.findNode(edge.from)) |node| if (self.unitIndex(node.path) != null) try self.units.items[source_index].addDependency(node.path);
            if (graph.findNode(edge.to)) |node| if (self.unitIndex(node.path) != null) try self.units.items[source_index].addDependency(node.path);
        }
        for (graph.hyperedges.items) |hyperedge| try self.addEvidenceDependencies(hyperedge.evidence);
        for (graph.supernodes.items) |supernode| try self.addEvidenceDependencies(supernode.evidence);
        for (self.units.items) |*unit| std.mem.sort([]const u8, unit.dependencies.items, {}, lessThanString);
    }

    fn readPreviousManifest(self: *Session) !?Manifest {
        return if (self.options.previous_manifest.len > 0)
            readManifest(self.allocator, self.io, self.root, self.options.previous_manifest) catch null
        else
            null;
    }

    fn recordUnit(
        self: *Session,
        path: []const u8,
        language: discovery.Language,
        digest: [32]u8,
        key: [64]u8,
        parser_schema: []const u8,
        parser_id: []const u8,
        parser_version: []const u8,
        fingerprint: [32]u8,
        graph_projection_fingerprint: [32]u8,
    ) !void {
        if (!validRelativePath(path) or !cacheableLanguage(language)) return error.InvalidExtractionCacheUnit;
        if (self.unitIndex(path) != null) return error.DuplicateExtractionCacheUnit;
        const path_copy = try owned.copy(u8, self.allocator, path);
        errdefer self.allocator.free(path_copy);
        try self.units.append(self.allocator, .{
            .allocator = self.allocator,
            .path = path_copy,
            .language = language,
            .content_digest = digest,
            .cache_key = key,
            .parser_schema = parser_schema,
            .parser_id = parser_id,
            .parser_version = parser_version,
            .structural_fingerprint = fingerprint,
            .graph_projection_fingerprint = graph_projection_fingerprint,
        });
    }

    fn unitIndex(self: *const Session, path: []const u8) ?usize {
        if (path.len == 0) return null;
        for (self.units.items, 0..) |unit, index| if (std.mem.eql(u8, unit.path, path)) return index;
        return null;
    }

    fn addEvidenceDependencies(self: *Session, evidence: []const model.SourceEvidence) !void {
        for (evidence) |source| {
            const source_index = self.unitIndex(source.source_path) orelse continue;
            for (evidence) |target| if (self.unitIndex(target.source_path) != null) try self.units.items[source_index].addDependency(target.source_path);
        }
    }

    fn materializeUnits(self: *const Session) ![]Unit {
        const units = try owned.slice(Unit, self.allocator, self.units.items.len);
        errdefer self.allocator.free(units);
        var initialized: usize = 0;
        errdefer deinitUnits(self.allocator, units[0..initialized]);
        for (self.units.items, 0..) |builder, index| {
            const content_hex = std.fmt.bytesToHex(builder.content_digest, .lower);
            const fingerprint_hex = std.fmt.bytesToHex(builder.structural_fingerprint, .lower);
            const projection_hex = std.fmt.bytesToHex(builder.graph_projection_fingerprint, .lower);
            units[index] = try cloneUnit(self.allocator, .{
                .path = builder.path,
                .language = builder.language,
                .content_digest = &content_hex,
                .cache_key = &builder.cache_key,
                .parser_schema = builder.parser_schema,
                .parser_id = builder.parser_id,
                .parser_version = builder.parser_version,
                .structural_fingerprint = &fingerprint_hex,
                .graph_projection_fingerprint = &projection_hex,
                .dependencies = builder.dependencies.items,
            });
            initialized += 1;
        }
        return units;
    }
};

pub fn encodeManifestAlloc(allocator: std.mem.Allocator, manifest: *const Manifest) ![]u8 {
    try validateManifest(manifest);
    return std.json.Stringify.valueAlloc(allocator, ManifestData{
        .schema = manifest_schema,
        .schema_version = schema_version,
        .recipe = recipe,
        .units = manifest.units,
        .direct_invalidations = manifest.direct_invalidations,
        .invalidation_closure = manifest.invalidation_closure,
        .complete = true,
    }, .{});
}

pub fn readManifest(allocator: std.mem.Allocator, io: std.Io, root: std.Io.Dir, path: []const u8) !Manifest {
    if (!validRelativePath(path)) return error.InvalidExtractionManifestPath;
    const bytes = try root.readFileAlloc(io, path, allocator, .limited(max_manifest_bytes));
    defer allocator.free(bytes);
    var parsed = std.json.parseFromSlice(ManifestData, allocator, bytes, .{ .allocate = .alloc_always }) catch return error.CorruptExtractionManifest;
    defer parsed.deinit();
    if (!parsed.value.complete or !std.mem.eql(u8, parsed.value.schema, manifest_schema) or
        parsed.value.schema_version != schema_version or !std.mem.eql(u8, parsed.value.recipe, recipe))
    {
        return error.IncompatibleExtractionManifest;
    }
    const units = try cloneUnits(allocator, parsed.value.units);
    errdefer deinitUnits(allocator, units);
    const direct = try cloneStrings(allocator, parsed.value.direct_invalidations);
    errdefer deinitStrings(allocator, direct);
    const closure = try cloneStrings(allocator, parsed.value.invalidation_closure);
    errdefer deinitStrings(allocator, closure);
    var manifest = Manifest{
        .allocator = allocator,
        .units = units,
        .direct_invalidations = direct,
        .invalidation_closure = closure,
        .digest = manifestFingerprint(units, direct, closure),
    };
    errdefer manifest.deinit();
    try validateManifestStructure(&manifest);
    return manifest;
}

pub fn proveZigSemanticNoop(
    allocator: std.mem.Allocator,
    io: std.Io,
    root: std.Io.Dir,
    current: *const discovery.Result,
    previous_manifest_path: []const u8,
    previous_manifest_digest: []const u8,
    current_validated: bool,
    options: zig_parser.Options,
) !?BuildEvidence {
    if (!current_validated) try discovery.validate(current);
    if (previous_manifest_path.len == 0 or !validHex(previous_manifest_digest) or options.max_source_bytes == 0) return null;
    var previous = readManifest(allocator, io, root, previous_manifest_path) catch return null;
    var previous_transferred = false;
    defer if (!previous_transferred) previous.deinit();
    const previous_digest_hex = std.fmt.bytesToHex(previous.digest, .lower);
    if (!std.mem.eql(u8, &previous_digest_hex, previous_manifest_digest)) return null;

    var cacheable_count: usize = 0;
    for (current.records) |record| {
        if (record.disposition != .deeply_indexed or !cacheableLanguage(record.classification.language)) continue;
        cacheable_count += 1;
        if (previous.find(record.relative_path) == null) return null;
    }
    if (cacheable_count != previous.units.len) return null;

    var direct_paths: std.ArrayList([]const u8) = .empty;
    var direct_owned = false;
    defer if (!direct_owned) deinitStringList(allocator, &direct_paths);
    var stats = Stats{ .cacheable_files = previous.units.len };
    var changed: usize = 0;

    for (previous.units) |*prior| {
        const record = current.findByPath(prior.path) orelse return null;
        if (record.disposition != .deeply_indexed or record.classification.language != prior.language) return null;
        const digest = record.content_digest orelse return null;
        const digest_hex = std.fmt.bytesToHex(digest, .lower);
        if (std.mem.eql(u8, prior.content_digest, &digest_hex)) {
            stats.hits += 1;
            continue;
        }
        if (record.classification.language != .zig or record.classification.artifact != .source or record.classification.is_generated or
            !std.mem.eql(u8, prior.parser_schema, zig_parser.schema) or !std.mem.eql(u8, prior.parser_id, zig_parser.parser_id) or
            !std.mem.eql(u8, prior.parser_version, zig_parser.parser_version))
        {
            return null;
        }
        var old_digest: [32]u8 = @splat(0);
        _ = std.fmt.hexToBytes(&old_digest, prior.content_digest) catch return null;
        const expected_old_key = zigKey(prior.path, old_digest, options);
        if (!std.mem.eql(u8, prior.cache_key, &expected_old_key)) return null;

        const source = root.readFileAlloc(io, prior.path, allocator, .limited(options.max_source_bytes)) catch return null;
        defer allocator.free(source);
        var observed_digest: [32]u8 = @splat(0);
        std.crypto.hash.sha2.Sha256.hash(source, &observed_digest, .{});
        if (!std.mem.eql(u8, &observed_digest, &digest)) return null;
        var parsed = zig_parser.parse(allocator, prior.path, source, options) catch return null;
        defer parsed.deinit();
        const projection = zigGraphProjectionFingerprint(allocator, prior.path, source, &parsed) catch return null;
        const projection_hex = std.fmt.bytesToHex(projection, .lower);
        if (!std.mem.eql(u8, prior.graph_projection_fingerprint, &projection_hex)) return null;
        const key = zigKey(prior.path, digest, options);
        const bytes = try encodeZigWithProjectionAlloc(allocator, prior.path, digest, key, source, options, &parsed, projection);
        defer allocator.free(bytes);
        if (bytes.len > max_entry_bytes) return error.ExtractionCacheEntryTooLarge;
        const cache_path = try entryPathAlloc(allocator, &key);
        defer allocator.free(cache_path);
        try atomicWrite(allocator, io, root, cache_path, bytes);
        const structural_hex = std.fmt.bytesToHex(parsed.fingerprint, .lower);
        try appendUniqueOwned(allocator, &direct_paths, prior.path);
        const replacement = try cloneUnit(allocator, .{
            .path = prior.path,
            .language = .zig,
            .content_digest = &digest_hex,
            .cache_key = &key,
            .parser_schema = zig_parser.schema,
            .parser_id = zig_parser.parser_id,
            .parser_version = zig_parser.parser_version,
            .structural_fingerprint = &structural_hex,
            .graph_projection_fingerprint = &projection_hex,
            .dependencies = prior.dependencies,
        });
        deinitUnit(allocator, prior.*);
        prior.* = replacement;
        changed += 1;
        stats.misses += 1;
        stats.writes += 1;
        stats.reparsed_files += 1;
    }
    if (changed == 0) return null;

    std.mem.sort([]const u8, direct_paths.items, {}, lessThanString);
    const direct = try direct_paths.toOwnedSlice(allocator);
    direct_owned = true;
    errdefer deinitStrings(allocator, direct);
    if (direct.len != changed) return error.SemanticNoopInvalidationMismatch;
    const closure = try invalidationClosure(allocator, previous.units, previous.units, direct);
    errdefer deinitStrings(allocator, closure);
    const digest = manifestFingerprint(previous.units, direct, closure);
    stats.direct_invalidations = direct.len;
    stats.invalidation_closure = closure.len;
    deinitStrings(allocator, previous.direct_invalidations);
    previous.direct_invalidations = &.{};
    deinitStrings(allocator, previous.invalidation_closure);
    previous.invalidation_closure = &.{};
    const units = previous.units;
    previous.units = &.{};
    previous_transferred = true;
    return .{
        .manifest = .{
            .allocator = allocator,
            .units = units,
            .direct_invalidations = direct,
            .invalidation_closure = closure,
            .digest = digest,
        },
        .stats = stats,
    };
}

pub fn validateManifest(manifest: *const Manifest) !void {
    try validateManifestStructure(manifest);
    const expected = manifestFingerprint(manifest.units, manifest.direct_invalidations, manifest.invalidation_closure);
    if (!std.mem.eql(u8, &expected, &manifest.digest)) return error.ExtractionManifestFingerprintMismatch;
}

fn validateManifestStructure(manifest: *const Manifest) !void {
    var previous_path: []const u8 = "";
    for (manifest.units) |unit| {
        if (!validRelativePath(unit.path) or !cacheableLanguage(unit.language) or !validHex(unit.content_digest) or
            !validHex(unit.cache_key) or !validHex(unit.structural_fingerprint) or !validHex(unit.graph_projection_fingerprint) or unit.parser_schema.len == 0 or
            unit.parser_id.len == 0 or unit.parser_version.len == 0 or !validParserIdentity(unit))
        {
            return error.InvalidExtractionManifestUnit;
        }
        if (previous_path.len > 0 and !std.mem.lessThan(u8, previous_path, unit.path)) return error.UnsortedExtractionManifestUnits;
        previous_path = unit.path;
        var previous_dependency: []const u8 = "";
        for (unit.dependencies) |dependency| {
            if (!validRelativePath(dependency) or std.mem.eql(u8, dependency, unit.path) or findUnit(manifest.units, dependency) == null) return error.InvalidExtractionManifestDependency;
            if (previous_dependency.len > 0 and !std.mem.lessThan(u8, previous_dependency, dependency)) return error.UnsortedExtractionManifestDependencies;
            previous_dependency = dependency;
        }
    }
    try validateSortedPaths(manifest.direct_invalidations);
    try validateSortedPaths(manifest.invalidation_closure);
    for (manifest.direct_invalidations) |path| if (!containsString(manifest.invalidation_closure, path)) return error.IncompleteExtractionInvalidationClosure;
}

pub fn entryPathAlloc(allocator: std.mem.Allocator, cache_key: []const u8) ![]u8 {
    if (!validHex(cache_key)) return error.InvalidExtractionCacheKey;
    return std.fmt.allocPrint(allocator, "{s}/{s}/{s}/{s}.json", .{ cache_root, recipe, cache_key[0..2], cache_key });
}

fn encodeZigAlloc(
    allocator: std.mem.Allocator,
    path: []const u8,
    digest: [32]u8,
    key: [64]u8,
    source: []const u8,
    options: zig_parser.Options,
    result: *const zig_parser.Result,
) ![]u8 {
    return encodeZigWithProjectionAlloc(
        allocator,
        path,
        digest,
        key,
        source,
        options,
        result,
        try zigGraphProjectionFingerprint(allocator, path, source, result),
    );
}

fn encodeZigWithProjectionAlloc(
    allocator: std.mem.Allocator,
    path: []const u8,
    digest: [32]u8,
    key: [64]u8,
    source: []const u8,
    options: zig_parser.Options,
    result: *const zig_parser.Result,
    projection: [32]u8,
) ![]u8 {
    if (source.len != result.source_bytes) return error.ExtractionCacheSourceLengthMismatch;
    const content_hex = std.fmt.bytesToHex(digest, .lower);
    const fingerprint_hex = std.fmt.bytesToHex(result.fingerprint, .lower);
    const projection_hex = std.fmt.bytesToHex(projection, .lower);
    return std.json.Stringify.valueAlloc(allocator, ZigEntry{
        .schema = entry_schema,
        .schema_version = schema_version,
        .recipe = recipe,
        .kind = .zig,
        .cache_key = &key,
        .path = path,
        .language = .zig,
        .content_digest = &content_hex,
        .parser_schema = zig_parser.schema,
        .parser_id = zig_parser.parser_id,
        .parser_version = zig_parser.parser_version,
        .limits = zigLimits(options),
        .source_bytes = result.source_bytes,
        .declarations = result.declarations,
        .imports = result.imports,
        .calls = result.calls,
        .call_arguments = result.call_arguments,
        .bindings = result.bindings,
        .binding_references = result.binding_references,
        .summary = result.summary,
        .structural_fingerprint = &fingerprint_hex,
        .graph_projection_fingerprint = &projection_hex,
        .complete = true,
    }, .{});
}

fn decodeZig(
    allocator: std.mem.Allocator,
    bytes: []const u8,
    path: []const u8,
    digest: [32]u8,
    key: [64]u8,
    source: []const u8,
    options: zig_parser.Options,
) !DecodedZig {
    var parsed = try std.json.parseFromSlice(ZigEntry, allocator, bytes, .{ .allocate = .alloc_always });
    defer parsed.deinit();
    const value = parsed.value;
    const content_hex = std.fmt.bytesToHex(digest, .lower);
    if (!value.complete or !std.mem.eql(u8, value.schema, entry_schema) or value.schema_version != schema_version or
        !std.mem.eql(u8, value.recipe, recipe) or value.kind != .zig or !std.mem.eql(u8, value.cache_key, &key) or
        !std.mem.eql(u8, value.path, path) or value.language != .zig or !std.mem.eql(u8, value.content_digest, &content_hex) or
        !std.mem.eql(u8, value.parser_schema, zig_parser.schema) or !std.mem.eql(u8, value.parser_id, zig_parser.parser_id) or
        !std.mem.eql(u8, value.parser_version, zig_parser.parser_version) or
        !std.meta.eql(value.limits, zigLimits(options)) or value.source_bytes == 0 or value.source_bytes > options.max_source_bytes or
        source.len != value.source_bytes or !validHex(value.structural_fingerprint) or !validHex(value.graph_projection_fingerprint))
    {
        return error.InvalidExtractionCacheEntry;
    }
    var fingerprint = [_]u8{0} ** 32;
    _ = try std.fmt.hexToBytes(&fingerprint, value.structural_fingerprint);
    var projection = [_]u8{0} ** 32;
    _ = try std.fmt.hexToBytes(&projection, value.graph_projection_fingerprint);
    const borrowed = zig_parser.Result{
        .allocator = allocator,
        .path = value.path,
        .source_bytes = value.source_bytes,
        .declarations = @constCast(value.declarations),
        .imports = @constCast(value.imports),
        .calls = @constCast(value.calls),
        .call_arguments = @constCast(value.call_arguments),
        .bindings = @constCast(value.bindings),
        .binding_references = @constCast(value.binding_references),
        .summary = value.summary,
        .fingerprint = fingerprint,
    };
    try zig_parser.validate(&borrowed);
    const expected_projection = try zigGraphProjectionFingerprint(allocator, path, source, &borrowed);
    if (!std.mem.eql(u8, &expected_projection, &projection)) return error.InvalidExtractionGraphProjection;
    const declarations = try cloneStructSlice(zig_parser.Declaration, allocator, value.declarations);
    errdefer deinitStructSlice(zig_parser.Declaration, allocator, declarations);
    const imports = try cloneStructSlice(zig_parser.Import, allocator, value.imports);
    errdefer deinitStructSlice(zig_parser.Import, allocator, imports);
    const calls = try cloneStructSlice(zig_parser.Call, allocator, value.calls);
    errdefer deinitStructSlice(zig_parser.Call, allocator, calls);
    const call_arguments = try cloneStructSlice(zig_parser.CallArgument, allocator, value.call_arguments);
    errdefer deinitStructSlice(zig_parser.CallArgument, allocator, call_arguments);
    const bindings = try cloneStructSlice(zig_parser.Binding, allocator, value.bindings);
    errdefer deinitStructSlice(zig_parser.Binding, allocator, bindings);
    const references = try cloneStructSlice(zig_parser.BindingReference, allocator, value.binding_references);
    errdefer deinitStructSlice(zig_parser.BindingReference, allocator, references);
    const copied_path = try owned.copy(u8, allocator, path);
    errdefer allocator.free(copied_path);
    return .{
        .result = zig_parser.Result{
            .allocator = allocator,
            .path = copied_path,
            .source_bytes = value.source_bytes,
            .declarations = declarations,
            .imports = imports,
            .calls = calls,
            .call_arguments = call_arguments,
            .bindings = bindings,
            .binding_references = references,
            .summary = value.summary,
            .fingerprint = fingerprint,
        },
        .graph_projection_fingerprint = projection,
    };
}

fn encodeDocumentAlloc(
    allocator: std.mem.Allocator,
    path: []const u8,
    language: discovery.Language,
    digest: [32]u8,
    key: [64]u8,
    source: []const u8,
    mode: typescript_parser.LanguageMode,
    parser_id: []const u8,
    parser_version: []const u8,
    options: typescript_parser.Options,
    result: *const typescript_parser.Result,
) ![]u8 {
    if (source.len != result.source_bytes) return error.ExtractionCacheSourceLengthMismatch;
    const content_hex = std.fmt.bytesToHex(digest, .lower);
    const fingerprint_hex = std.fmt.bytesToHex(result.fingerprint, .lower);
    const projection_hex = std.fmt.bytesToHex(try documentGraphProjectionFingerprint(allocator, path, source, result), .lower);
    return std.json.Stringify.valueAlloc(allocator, DocumentEntry{
        .schema = entry_schema,
        .schema_version = schema_version,
        .recipe = recipe,
        .kind = .document,
        .cache_key = &key,
        .path = path,
        .language = language,
        .content_digest = &content_hex,
        .parser_schema = typescript_parser.schema,
        .parser_id = parser_id,
        .parser_version = parser_version,
        .limits = documentLimits(options),
        .mode = mode,
        .source_bytes = result.source_bytes,
        .declarations = result.declarations,
        .imports = result.imports,
        .import_bindings = result.import_bindings,
        .exports = result.exports,
        .type_bindings = result.type_bindings,
        .calls = result.calls,
        .call_arguments = result.call_arguments,
        .call_bindings = result.call_bindings,
        .protocol_packages = result.protocol_packages,
        .protocol_fields = result.protocol_fields,
        .protocol_enum_values = result.protocol_enum_values,
        .protocol_rpcs = result.protocol_rpcs,
        .summary = result.summary,
        .structural_fingerprint = &fingerprint_hex,
        .graph_projection_fingerprint = &projection_hex,
        .complete = true,
    }, .{});
}

fn decodeDocument(
    allocator: std.mem.Allocator,
    bytes: []const u8,
    path: []const u8,
    language: discovery.Language,
    digest: [32]u8,
    key: [64]u8,
    source: []const u8,
    mode: typescript_parser.LanguageMode,
    parser_id: []const u8,
    parser_version: []const u8,
    options: typescript_parser.Options,
) !DecodedDocument {
    var parsed = try std.json.parseFromSlice(DocumentEntry, allocator, bytes, .{ .allocate = .alloc_always });
    defer parsed.deinit();
    const value = parsed.value;
    const content_hex = std.fmt.bytesToHex(digest, .lower);
    if (!value.complete or !std.mem.eql(u8, value.schema, entry_schema) or value.schema_version != schema_version or
        !std.mem.eql(u8, value.recipe, recipe) or value.kind != .document or !std.mem.eql(u8, value.cache_key, &key) or
        !std.mem.eql(u8, value.path, path) or value.language != language or !std.mem.eql(u8, value.content_digest, &content_hex) or
        !std.mem.eql(u8, value.parser_schema, typescript_parser.schema) or !std.mem.eql(u8, value.parser_id, parser_id) or
        !std.mem.eql(u8, value.parser_version, parser_version) or !std.meta.eql(value.limits, documentLimits(options)) or
        value.mode != mode or value.source_bytes == 0 or value.source_bytes > options.max_source_bytes or source.len != value.source_bytes or
        !validHex(value.structural_fingerprint) or !validHex(value.graph_projection_fingerprint))
    {
        return error.InvalidExtractionCacheEntry;
    }
    var expected = [_]u8{0} ** 32;
    _ = try std.fmt.hexToBytes(&expected, value.structural_fingerprint);
    var projection = [_]u8{0} ** 32;
    _ = try std.fmt.hexToBytes(&projection, value.graph_projection_fingerprint);
    const borrowed = typescript_parser.Result{
        .allocator = allocator,
        .path = value.path,
        .language = value.mode,
        .source_bytes = value.source_bytes,
        .parser_id = value.parser_id,
        .parser_version = value.parser_version,
        .declarations = @constCast(value.declarations),
        .imports = @constCast(value.imports),
        .import_bindings = @constCast(value.import_bindings),
        .exports = @constCast(value.exports),
        .type_bindings = @constCast(value.type_bindings),
        .calls = @constCast(value.calls),
        .call_arguments = @constCast(value.call_arguments),
        .call_bindings = @constCast(value.call_bindings),
        .protocol_packages = @constCast(value.protocol_packages),
        .protocol_fields = @constCast(value.protocol_fields),
        .protocol_enum_values = @constCast(value.protocol_enum_values),
        .protocol_rpcs = @constCast(value.protocol_rpcs),
        .summary = value.summary,
        .fingerprint = expected,
    };
    try typescript_parser.validate(&borrowed);
    const expected_projection = try documentGraphProjectionFingerprint(allocator, path, source, &borrowed);
    if (!std.mem.eql(u8, &expected_projection, &projection)) return error.InvalidExtractionGraphProjection;
    const declarations = try cloneStructSlice(typescript_parser.Declaration, allocator, value.declarations);
    errdefer deinitStructSlice(typescript_parser.Declaration, allocator, declarations);
    const imports = try cloneStructSlice(typescript_parser.Import, allocator, value.imports);
    errdefer deinitStructSlice(typescript_parser.Import, allocator, imports);
    const import_bindings = try cloneStructSlice(typescript_parser.ImportBinding, allocator, value.import_bindings);
    errdefer deinitStructSlice(typescript_parser.ImportBinding, allocator, import_bindings);
    const exports = try cloneStructSlice(typescript_parser.Export, allocator, value.exports);
    errdefer deinitStructSlice(typescript_parser.Export, allocator, exports);
    const type_bindings = try cloneStructSlice(typescript_parser.TypeBinding, allocator, value.type_bindings);
    errdefer deinitStructSlice(typescript_parser.TypeBinding, allocator, type_bindings);
    const calls = try cloneStructSlice(typescript_parser.Call, allocator, value.calls);
    errdefer deinitStructSlice(typescript_parser.Call, allocator, calls);
    const call_arguments = try cloneStructSlice(typescript_parser.CallArgument, allocator, value.call_arguments);
    errdefer deinitStructSlice(typescript_parser.CallArgument, allocator, call_arguments);
    const call_bindings = try cloneStructSlice(typescript_parser.CallBinding, allocator, value.call_bindings);
    errdefer deinitStructSlice(typescript_parser.CallBinding, allocator, call_bindings);
    const protocol_packages = try cloneStructSlice(protobuf_parser.ProtocolPackage, allocator, value.protocol_packages);
    errdefer deinitStructSlice(protobuf_parser.ProtocolPackage, allocator, protocol_packages);
    const protocol_fields = try cloneStructSlice(protobuf_parser.ProtocolField, allocator, value.protocol_fields);
    errdefer deinitStructSlice(protobuf_parser.ProtocolField, allocator, protocol_fields);
    const protocol_enum_values = try cloneStructSlice(protobuf_parser.ProtocolEnumValue, allocator, value.protocol_enum_values);
    errdefer deinitStructSlice(protobuf_parser.ProtocolEnumValue, allocator, protocol_enum_values);
    const protocol_rpcs = try cloneStructSlice(protobuf_parser.ProtocolRpc, allocator, value.protocol_rpcs);
    errdefer deinitStructSlice(protobuf_parser.ProtocolRpc, allocator, protocol_rpcs);
    const result = try typescript_parser.Result.initOwned(
        allocator,
        path,
        mode,
        value.source_bytes,
        parser_id,
        parser_version,
        declarations,
        imports,
        import_bindings,
        exports,
        type_bindings,
        calls,
        call_arguments,
        call_bindings,
        protocol_packages,
        protocol_fields,
        protocol_enum_values,
        protocol_rpcs,
        value.summary.traversed_nodes,
    );
    return .{ .result = result, .graph_projection_fingerprint = projection };
}

fn zigKey(path: []const u8, digest: [32]u8, options: zig_parser.Options) [64]u8 {
    var hasher = std.crypto.hash.sha2.Sha256.init(.{});
    updateDigest(&hasher, entry_schema);
    updateDigest(&hasher, recipe);
    updateDigest(&hasher, path);
    hasher.update(&digest);
    updateDigest(&hasher, "zig");
    updateDigest(&hasher, zig_parser.schema);
    updateDigest(&hasher, zig_parser.parser_id);
    updateDigest(&hasher, zig_parser.parser_version);
    updateInteger(&hasher, options.max_source_bytes);
    updateInteger(&hasher, options.max_nodes);
    updateInteger(&hasher, options.max_depth);
    updateInteger(&hasher, options.max_facts);
    updateInteger(&hasher, options.max_label_bytes);
    var output = [_]u8{0} ** 32;
    hasher.final(&output);
    return std.fmt.bytesToHex(output, .lower);
}

fn documentKey(
    path: []const u8,
    language: discovery.Language,
    digest: [32]u8,
    mode: typescript_parser.LanguageMode,
    parser_id: []const u8,
    parser_version: []const u8,
    options: typescript_parser.Options,
) [64]u8 {
    var hasher = std.crypto.hash.sha2.Sha256.init(.{});
    updateDigest(&hasher, entry_schema);
    updateDigest(&hasher, recipe);
    updateDigest(&hasher, path);
    hasher.update(&digest);
    updateDigest(&hasher, @tagName(language));
    updateDigest(&hasher, @tagName(mode));
    updateDigest(&hasher, typescript_parser.schema);
    updateDigest(&hasher, parser_id);
    updateDigest(&hasher, parser_version);
    updateInteger(&hasher, options.max_source_bytes);
    updateInteger(&hasher, options.max_nodes);
    updateInteger(&hasher, options.max_depth);
    updateInteger(&hasher, options.max_facts);
    updateInteger(&hasher, options.max_label_bytes);
    var output = [_]u8{0} ** 32;
    hasher.final(&output);
    return std.fmt.bytesToHex(output, .lower);
}

fn zigLimits(options: zig_parser.Options) ParserLimits {
    return .{
        .max_source_bytes = options.max_source_bytes,
        .max_nodes = options.max_nodes,
        .max_depth = options.max_depth,
        .max_facts = options.max_facts,
        .max_label_bytes = options.max_label_bytes,
    };
}

fn documentLimits(options: typescript_parser.Options) ParserLimits {
    return .{
        .max_source_bytes = options.max_source_bytes,
        .max_nodes = options.max_nodes,
        .max_depth = options.max_depth,
        .max_facts = options.max_facts,
        .max_label_bytes = options.max_label_bytes,
    };
}

fn zigGraphProjectionFingerprint(
    allocator: std.mem.Allocator,
    path: []const u8,
    source: []const u8,
    result: *const zig_parser.Result,
) ![32]u8 {
    try zig_parser.validate(result);
    if (!std.mem.eql(u8, result.path, path) or result.source_bytes != source.len) {
        return error.ExtractionGraphProjectionSourceMismatch;
    }
    const facts = try std.json.Stringify.valueAlloc(allocator, .{
        .schema = "zgraphy.zig-graph-projection.v1",
        .path = path,
        .declarations = result.declarations,
        .imports = result.imports,
        .calls = result.calls,
        .call_arguments = result.call_arguments,
        .bindings = result.bindings,
        .binding_references = result.binding_references,
        .summary = result.summary,
    }, .{});
    defer allocator.free(facts);
    var hasher = std.crypto.hash.sha2.Sha256.init(.{});
    updateDigest(&hasher, "zgraphy.zig-graph-projection.v1");
    updateDigest(&hasher, facts);
    for (result.declarations) |declaration| try updateProjectionSource(&hasher, source, declaration.span.start_byte, declaration.span.end_byte);
    for (result.bindings) |binding| {
        if (binding.scope != .local) continue;
        try updateProjectionSource(&hasher, source, binding.span.start_byte, binding.span.end_byte);
    }
    var digest: [32]u8 = @splat(0);
    hasher.final(&digest);
    return digest;
}

fn documentGraphProjectionFingerprint(
    allocator: std.mem.Allocator,
    path: []const u8,
    source: []const u8,
    result: *const typescript_parser.Result,
) ![32]u8 {
    try typescript_parser.validate(result);
    if (!std.mem.eql(u8, result.path, path) or result.source_bytes != source.len) {
        return error.ExtractionGraphProjectionSourceMismatch;
    }
    const facts = try std.json.Stringify.valueAlloc(allocator, .{
        .schema = "zgraphy.document-graph-projection.v1",
        .path = path,
        .language = result.language,
        .parser_id = result.parser_id,
        .parser_version = result.parser_version,
        .declarations = result.declarations,
        .imports = result.imports,
        .import_bindings = result.import_bindings,
        .exports = result.exports,
        .type_bindings = result.type_bindings,
        .calls = result.calls,
        .call_arguments = result.call_arguments,
        .call_bindings = result.call_bindings,
        .protocol_packages = result.protocol_packages,
        .protocol_fields = result.protocol_fields,
        .protocol_enum_values = result.protocol_enum_values,
        .protocol_rpcs = result.protocol_rpcs,
        .summary = result.summary,
    }, .{});
    defer allocator.free(facts);
    var hasher = std.crypto.hash.sha2.Sha256.init(.{});
    updateDigest(&hasher, "zgraphy.document-graph-projection.v1");
    updateDigest(&hasher, facts);
    for (result.declarations) |declaration| try updateProjectionSource(&hasher, source, declaration.span.start_byte, declaration.span.end_byte);
    var digest: [32]u8 = @splat(0);
    hasher.final(&digest);
    return digest;
}

fn updateProjectionSource(hasher: *std.crypto.hash.sha2.Sha256, source: []const u8, start: usize, end: usize) !void {
    if (start >= end or end > source.len) return error.InvalidExtractionGraphProjectionSpan;
    updateInteger(hasher, start);
    updateInteger(hasher, end);
    updateDigest(hasher, source[start..end]);
}

fn directInvalidations(allocator: std.mem.Allocator, previous: []const Unit, current: []const Unit) ![]const []const u8 {
    var paths: std.ArrayList([]const u8) = .empty;
    errdefer deinitStringList(allocator, &paths);
    for (current) |unit| {
        const old = findUnit(previous, unit.path);
        if (old == null or !sameUnitIdentity(old.?.*, unit)) try appendUniqueOwned(allocator, &paths, unit.path);
    }
    for (previous) |unit| if (findUnit(current, unit.path) == null) try appendUniqueOwned(allocator, &paths, unit.path);
    std.mem.sort([]const u8, paths.items, {}, lessThanString);
    return paths.toOwnedSlice(allocator);
}

fn invalidationClosure(
    allocator: std.mem.Allocator,
    previous: []const Unit,
    current: []const Unit,
    direct: []const []const u8,
) ![]const []const u8 {
    var closure: std.ArrayList([]const u8) = .empty;
    errdefer deinitStringList(allocator, &closure);
    for (direct) |path| try appendUniqueOwned(allocator, &closure, path);
    var changed = true;
    while (changed) {
        changed = false;
        for (previous) |unit| if (!containsString(closure.items, unit.path)) {
            for (unit.dependencies) |dependency| if (containsString(closure.items, dependency)) {
                try appendUniqueOwned(allocator, &closure, unit.path);
                changed = true;
                break;
            };
        };
        for (current) |unit| if (!containsString(closure.items, unit.path)) {
            for (unit.dependencies) |dependency| if (containsString(closure.items, dependency)) {
                try appendUniqueOwned(allocator, &closure, unit.path);
                changed = true;
                break;
            };
        };
    }
    std.mem.sort([]const u8, closure.items, {}, lessThanString);
    return closure.toOwnedSlice(allocator);
}

fn manifestFingerprint(units: []const Unit, direct: []const []const u8, closure: []const []const u8) [32]u8 {
    _ = direct;
    _ = closure;
    var hasher = std.crypto.hash.sha2.Sha256.init(.{});
    updateDigest(&hasher, manifest_schema);
    updateDigest(&hasher, recipe);
    updateInteger(&hasher, units.len);
    for (units) |unit| {
        updateDigest(&hasher, unit.path);
        updateDigest(&hasher, @tagName(unit.language));
        updateDigest(&hasher, unit.content_digest);
        updateDigest(&hasher, unit.cache_key);
        updateDigest(&hasher, unit.parser_schema);
        updateDigest(&hasher, unit.parser_id);
        updateDigest(&hasher, unit.parser_version);
        updateDigest(&hasher, unit.structural_fingerprint);
        updateDigest(&hasher, unit.graph_projection_fingerprint);
        updateInteger(&hasher, unit.dependencies.len);
        for (unit.dependencies) |dependency| updateDigest(&hasher, dependency);
    }
    var digest = [_]u8{0} ** 32;
    hasher.final(&digest);
    return digest;
}

fn cloneUnits(allocator: std.mem.Allocator, input: []const Unit) ![]Unit {
    const units = try owned.slice(Unit, allocator, input.len);
    errdefer allocator.free(units);
    var initialized: usize = 0;
    errdefer deinitUnits(allocator, units[0..initialized]);
    for (input, 0..) |unit, index| {
        units[index] = try cloneUnit(allocator, unit);
        initialized += 1;
    }
    return units;
}

fn cloneUnit(allocator: std.mem.Allocator, unit: Unit) !Unit {
    const path = try owned.copy(u8, allocator, unit.path);
    errdefer allocator.free(path);
    const content_digest = try owned.copy(u8, allocator, unit.content_digest);
    errdefer allocator.free(content_digest);
    const cache_key = try owned.copy(u8, allocator, unit.cache_key);
    errdefer allocator.free(cache_key);
    const parser_schema = try owned.copy(u8, allocator, unit.parser_schema);
    errdefer allocator.free(parser_schema);
    const parser_id = try owned.copy(u8, allocator, unit.parser_id);
    errdefer allocator.free(parser_id);
    const parser_version = try owned.copy(u8, allocator, unit.parser_version);
    errdefer allocator.free(parser_version);
    const structural_fingerprint = try owned.copy(u8, allocator, unit.structural_fingerprint);
    errdefer allocator.free(structural_fingerprint);
    const graph_projection_fingerprint = try owned.copy(u8, allocator, unit.graph_projection_fingerprint);
    errdefer allocator.free(graph_projection_fingerprint);
    const dependencies = try cloneStrings(allocator, unit.dependencies);
    errdefer deinitStrings(allocator, dependencies);
    return .{
        .path = path,
        .language = unit.language,
        .content_digest = content_digest,
        .cache_key = cache_key,
        .parser_schema = parser_schema,
        .parser_id = parser_id,
        .parser_version = parser_version,
        .structural_fingerprint = structural_fingerprint,
        .graph_projection_fingerprint = graph_projection_fingerprint,
        .dependencies = dependencies,
    };
}

fn deinitUnits(allocator: std.mem.Allocator, units: []Unit) void {
    for (units) |unit| deinitUnit(allocator, unit);
    allocator.free(units);
}

fn deinitUnit(allocator: std.mem.Allocator, unit: Unit) void {
    allocator.free(unit.path);
    allocator.free(unit.content_digest);
    allocator.free(unit.cache_key);
    allocator.free(unit.parser_schema);
    allocator.free(unit.parser_id);
    allocator.free(unit.parser_version);
    allocator.free(unit.structural_fingerprint);
    allocator.free(unit.graph_projection_fingerprint);
    deinitStrings(allocator, unit.dependencies);
}

fn cloneStrings(allocator: std.mem.Allocator, input: []const []const u8) ![]const []const u8 {
    const output = try owned.slice([]const u8, allocator, input.len);
    errdefer allocator.free(output);
    var initialized: usize = 0;
    errdefer {
        for (output[0..initialized]) |value| allocator.free(value);
    }
    for (input, 0..) |value, index| {
        output[index] = try owned.copy(u8, allocator, value);
        initialized += 1;
    }
    return output;
}

fn deinitStrings(allocator: std.mem.Allocator, strings: []const []const u8) void {
    for (strings) |value| allocator.free(value);
    allocator.free(strings);
}

fn deinitStringList(allocator: std.mem.Allocator, list: *std.ArrayList([]const u8)) void {
    for (list.items) |value| allocator.free(value);
    list.deinit(allocator);
}

fn appendUniqueOwned(allocator: std.mem.Allocator, list: *std.ArrayList([]const u8), value: []const u8) !void {
    if (containsString(list.items, value)) return;
    const copy = try owned.copy(u8, allocator, value);
    errdefer allocator.free(copy);
    try list.append(allocator, copy);
}

fn cloneStructSlice(comptime T: type, allocator: std.mem.Allocator, input: []const T) ![]T {
    const output = try owned.slice(T, allocator, input.len);
    errdefer allocator.free(output);
    var initialized: usize = 0;
    errdefer deinitStructSlice(T, allocator, output[0..initialized]);
    for (input, 0..) |value, index| {
        output[index] = try cloneStruct(T, allocator, value);
        initialized += 1;
    }
    return output;
}

fn cloneStruct(comptime T: type, allocator: std.mem.Allocator, value: T) !T {
    var output = value;
    var copied_through: usize = 0;
    errdefer inline for (std.meta.fields(T), 0..) |field, field_index| {
        if (field.type == []const u8 and field_index < copied_through) {
            const bytes = @field(output, field.name);
            if (bytes.len > 0) allocator.free(bytes);
        }
    };
    inline for (std.meta.fields(T), 0..) |field, field_index| {
        if (field.type == []const u8) {
            const bytes = @field(value, field.name);
            @field(output, field.name) = if (bytes.len == 0) "" else try owned.copy(u8, allocator, bytes);
        }
        copied_through = field_index + 1;
    }
    return output;
}

fn deinitStructSlice(comptime T: type, allocator: std.mem.Allocator, values: []T) void {
    for (values) |value| inline for (std.meta.fields(T)) |field| {
        if (field.type == []const u8) {
            const bytes = @field(value, field.name);
            if (bytes.len > 0) allocator.free(bytes);
        }
    };
    allocator.free(values);
}

fn findUnit(units: []const Unit, path: []const u8) ?*const Unit {
    for (units, 0..) |unit, index| if (std.mem.eql(u8, unit.path, path)) return &units[index];
    return null;
}

fn sameUnitIdentity(a: Unit, b: Unit) bool {
    return a.language == b.language and std.mem.eql(u8, a.content_digest, b.content_digest) and
        std.mem.eql(u8, a.cache_key, b.cache_key) and std.mem.eql(u8, a.parser_schema, b.parser_schema) and
        std.mem.eql(u8, a.parser_id, b.parser_id) and std.mem.eql(u8, a.parser_version, b.parser_version) and
        std.mem.eql(u8, a.structural_fingerprint, b.structural_fingerprint) and
        std.mem.eql(u8, a.graph_projection_fingerprint, b.graph_projection_fingerprint);
}

fn validateSortedPaths(paths: []const []const u8) !void {
    var previous: []const u8 = "";
    for (paths) |path| {
        if (!validRelativePath(path)) return error.InvalidExtractionManifestPath;
        if (previous.len > 0 and !std.mem.lessThan(u8, previous, path)) return error.UnsortedExtractionManifestPaths;
        previous = path;
    }
}

fn containsString(values: []const []const u8, target: []const u8) bool {
    for (values) |value| if (std.mem.eql(u8, value, target)) return true;
    return false;
}

fn cacheableLanguage(language: discovery.Language) bool {
    return switch (language) {
        .zig, .typescript, .javascript, .proto => true,
        else => false,
    };
}

fn validParserIdentity(unit: Unit) bool {
    return switch (unit.language) {
        .zig => std.mem.eql(u8, unit.parser_schema, zig_parser.schema) and
            std.mem.eql(u8, unit.parser_id, zig_parser.parser_id) and std.mem.eql(u8, unit.parser_version, zig_parser.parser_version),
        .typescript, .javascript => std.mem.eql(u8, unit.parser_schema, typescript_parser.schema) and
            std.mem.eql(u8, unit.parser_id, typescript_parser.parser_id) and std.mem.eql(u8, unit.parser_version, typescript_parser.parser_version),
        .proto => std.mem.eql(u8, unit.parser_schema, protobuf_parser.schema) and
            std.mem.eql(u8, unit.parser_id, protobuf_parser.parser_id) and std.mem.eql(u8, unit.parser_version, protobuf_parser.parser_version),
        else => false,
    };
}

fn validHex(value: []const u8) bool {
    if (value.len != 64) return false;
    for (value) |byte| if (!std.ascii.isDigit(byte) and !(byte >= 'a' and byte <= 'f')) return false;
    return true;
}

fn validRelativePath(path: []const u8) bool {
    if (path.len == 0 or path.len > std.fs.max_path_bytes or std.fs.path.isAbsolute(path) or std.mem.indexOfScalar(u8, path, '\\') != null) return false;
    var parts = std.mem.splitScalar(u8, path, '/');
    while (parts.next()) |part| if (part.len == 0 or std.mem.eql(u8, part, ".") or std.mem.eql(u8, part, "..")) return false;
    return true;
}

fn lessThanBuilder(_: void, a: UnitBuilder, b: UnitBuilder) bool {
    return std.mem.lessThan(u8, a.path, b.path);
}

fn lessThanString(_: void, a: []const u8, b: []const u8) bool {
    return std.mem.lessThan(u8, a, b);
}

fn updateDigest(hasher: *std.crypto.hash.sha2.Sha256, value: []const u8) void {
    updateInteger(hasher, value.len);
    hasher.update(value);
}

fn updateInteger(hasher: *std.crypto.hash.sha2.Sha256, value: usize) void {
    var bytes = [_]u8{0} ** 8;
    std.mem.writeInt(u64, &bytes, value, .little);
    hasher.update(&bytes);
}

fn atomicWrite(allocator: std.mem.Allocator, io: std.Io, root: std.Io.Dir, path: []const u8, bytes: []const u8) !void {
    if (!validRelativePath(path)) return error.InvalidExtractionCachePath;
    if (std.mem.lastIndexOfScalar(u8, path, '/')) |slash| try root.createDirPath(io, path[0..slash]);
    for (0..1024) |slot| {
        const temporary = try std.fmt.allocPrint(allocator, "{s}.tmp.{d}", .{ path, slot });
        defer allocator.free(temporary);
        const file = root.createFile(io, temporary, .{ .exclusive = true }) catch |failure| switch (failure) {
            error.PathAlreadyExists => continue,
            else => return failure,
        };
        defer file.close(io);
        errdefer root.deleteFile(io, temporary) catch {};
        try file.writeStreamingAll(io, bytes);
        root.rename(temporary, root, path, io) catch |failure| {
            root.deleteFile(io, temporary) catch {};
            return failure;
        };
        return;
    }
    return error.AtomicTemporaryPathExhausted;
}
