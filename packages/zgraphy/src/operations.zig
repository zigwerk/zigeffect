const std = @import("std");
const change_lineage = @import("change_lineage.zig");
const delta_journal = @import("delta_journal.zig");
const discovery = @import("discovery.zig");
const extraction_cache = @import("extraction_cache.zig");
const freshness = @import("freshness.zig");
const indexer = @import("indexer.zig");
const memory = @import("memory.zig");
const model = @import("model.zig");
const nendb = @import("nendb.zig");
const origin_ledger = @import("origin_ledger.zig");
const ownership = @import("ownership.zig");
const project = @import("project.zig");
const repair = @import("repair.zig");
const repository_context = @import("repository_context.zig");
const retention = @import("retention.zig");
const semantic_recipes = @import("semantic_recipes.zig");
const store = @import("store.zig");

pub const content_manifest_schema = "zgraphy.content-manifest.v1";
pub const health_schema = "zgraphy.graph-health.v1";
pub const doctor_schema = "zgraphy.doctor.v1";
pub const effective_config_schema = "zgraphy.effective-config.v1";
pub const schema_version: u32 = 1;
pub const max_manifest_bytes: usize = 64 * 1024 * 1024;
pub const max_health_bytes: usize = 1024 * 1024;
pub const max_generation_metadata_bytes: usize = 1024 * 1024;
pub const max_active_generation_bytes: usize = 64 * 1024;
pub const active_generation_path = ".zgraphy/active-generation.json";
pub const generation_root = ".zgraphy/generations";
pub const update_lock_path = ".zgraphy/update.lock";
pub const generation_reader_lock_path = ".zgraphy/runtime/generation-readers.lock";
pub const generation_schema = "zgraphy.generation.v7";
pub const active_generation_schema = "zgraphy.active-generation.v7";
pub const generation_schema_version: u32 = 7;
pub const freshness_recipe = "semantic-source-generation-v7";

pub const RefreshStatus = enum {
    current,
    refreshed,
    staged,
};

pub const RefreshTrigger = enum {
    unchanged,
    explicit,
    missing_generation,
    changed_manifest,
    changed_repository_context,
    invalid_generation,
    repair_generation,
};

pub const PrunedRecords = struct {
    nodes: usize = 0,
    edges: usize = 0,
    vectors: usize = 0,
    hyperedges: usize = 0,
    supernodes: usize = 0,
};

pub const RecoverySource = enum {
    full_snapshot,
    parent_delta_replay,
};

pub const ArtifactStamp = struct {
    inode: u64,
    size: u64,
    mtime_ns: i128,
    ctime_ns: i128,
};

pub const ActiveGeneration = struct {
    schema: []const u8,
    schema_version: u32,
    repository_id: []const u8,
    generation: []const u8,
    semantic_generation: []const u8,
    semantic_noop_depth: usize,
    parent_generation: []const u8,
    replaces_generation: []const u8,
    database: []const u8,
    content_manifest: []const u8,
    extraction_manifest: []const u8,
    delta_journal: []const u8,
    repository_context: []const u8,
    change_lineage: []const u8,
    origin_ledger: []const u8,
    repair_report: []const u8,
    health_report: []const u8,
    metadata: []const u8,
    database_artifact_fingerprint: []const u8,
    origin_artifact_fingerprint: []const u8,
    database_artifact_stamp: ArtifactStamp,
    origin_artifact_stamp: ArtifactStamp,
    discovery_manifest_digest: []const u8,
    ownership_manifest_digest: []const u8,
    extraction_manifest_digest: []const u8,
    repository_context_fingerprint: []const u8,
    change_lineage_input_fingerprint: []const u8,
    change_lineage_fingerprint: []const u8,
    change_lineage_summary: change_lineage.Summary,
    origin_input_fingerprint: []const u8,
    origin_fingerprint: []const u8,
    origin_summary: origin_ledger.Summary,
    origin_source_dependencies: usize,
    repair_plan_fingerprint: []const u8,
    repair_fingerprint: []const u8,
    repair_summary: repair.Summary,
    graph_fingerprint: []const u8,
    delta_schema: []const u8,
    delta_fingerprint: []const u8,
    delta_summary: delta_journal.Summary,
    secondary_index_schema: []const u8,
    secondary_index_fingerprint: []const u8,
    secondary_indexes: nendb.SecondaryIndexStats,
    complete: bool,
};

const GenerationMetadata = struct {
    schema: []const u8,
    schema_version: u32,
    repository_id: []const u8,
    generation: []const u8,
    semantic_generation: []const u8,
    semantic_noop_depth: usize,
    parent_generation: []const u8,
    replaces_generation: []const u8,
    recipe: []const u8,
    snapshot_schema: []const u8,
    embedder: []const u8,
    database_artifact_fingerprint: []const u8,
    origin_artifact_fingerprint: []const u8,
    database_artifact_stamp: ArtifactStamp,
    origin_artifact_stamp: ArtifactStamp,
    discovery_manifest_digest: []const u8,
    ownership_manifest_digest: []const u8,
    extraction_manifest_digest: []const u8,
    repository_context_schema: []const u8,
    repository_context_fingerprint: []const u8,
    change_lineage_schema: []const u8,
    change_lineage_input_fingerprint: []const u8,
    change_lineage_fingerprint: []const u8,
    change_lineage_summary: change_lineage.Summary,
    origin_schema: []const u8,
    origin_input_fingerprint: []const u8,
    origin_fingerprint: []const u8,
    origin_summary: origin_ledger.Summary,
    origin_source_dependencies: usize,
    repair_schema: []const u8,
    repair_plan_fingerprint: []const u8,
    repair_fingerprint: []const u8,
    repair_summary: repair.Summary,
    graph_fingerprint: []const u8,
    delta_schema: []const u8,
    delta_fingerprint: []const u8,
    delta_summary: delta_journal.Summary,
    secondary_index_schema: []const u8,
    secondary_index_fingerprint: []const u8,
    secondary_indexes: nendb.SecondaryIndexStats,
    build_summary: indexer.BuildSummary,
    nodes: usize,
    edges: usize,
    vectors: usize,
    hyperedges: usize,
    supernodes: usize,
    pruned: PrunedRecords,
    complete: bool,
};

pub const Publication = struct {
    allocator: std.mem.Allocator,
    /// Whether the working tree was consulted. False on the read path, which
    /// validates the published generation without hashing the repository — so
    /// the graph is sound in itself and may not match the files on disk.
    tree_verified: bool = true,
    status: RefreshStatus,
    trigger: RefreshTrigger,
    activated: bool,
    generation: []const u8,
    previous_generation: []const u8,
    database: []const u8,
    delta_journal: []const u8,
    delta_fingerprint: []const u8,
    delta_summary: delta_journal.Summary,
    checked_files: usize,
    reparsed_files: usize,
    cache_hits: usize,
    cache_misses: usize,
    cache_rejected: usize,
    cache_writes: usize,
    direct_invalidations: usize,
    invalidation_closure: usize,
    pruned: PrunedRecords,
    origin: origin_ledger.Summary,
    repair: repair.Summary,
    retention: retention.Summary,

    pub fn deinit(self: *Publication) void {
        self.allocator.free(self.generation);
        self.allocator.free(self.previous_generation);
        self.allocator.free(self.database);
        self.allocator.free(self.delta_journal);
        self.allocator.free(self.delta_fingerprint);
        self.generation = &.{};
        self.previous_generation = &.{};
        self.database = &.{};
        self.delta_journal = &.{};
        self.delta_fingerprint = &.{};
    }
};

pub const RebuildOptions = struct {
    activate: bool = true,
    use_extraction_cache: bool = true,
    origin_overlays: []const origin_ledger.Overlay = &.{},
};

pub const ManagedBuild = struct {
    built: indexer.BuildResult,
    publication: Publication,

    pub fn deinit(self: *ManagedBuild) void {
        self.publication.deinit();
        self.built.deinit();
    }
};

pub const UpdateKind = enum {
    full_rebuild,
    semantic_noop,
};

pub const ManagedUpdate = struct {
    summary: indexer.BuildSummary,
    publication: Publication,
    kind: UpdateKind,

    pub fn deinit(self: *ManagedUpdate) void {
        self.publication.deinit();
    }
};

pub const ManagedGraph = struct {
    graph: model.RepositoryGraph,
    refresh: Publication,
    recovery_source: RecoverySource,

    pub fn deinit(self: *ManagedGraph) void {
        self.graph.deinit();
        self.refresh.deinit();
    }
};

const LoadedGeneration = struct {
    graph: model.RepositoryGraph,
    recovery_source: RecoverySource,
    repair_action: repair.Action = .none,
    repair_cause: repair.Cause = .none,
};

const ArtifactSealValidation = struct {
    database: bool = true,
    origin: bool = true,
};

pub const HealthStatus = enum {
    healthy,
    degraded,
    stale,
    partial,
    incompatible,
    corrupt,
};

pub const ConfigSource = enum {
    repository,
};

pub const Authority = enum {
    repository_read,
};

pub const ConfigField = struct {
    name: []const u8,
    source: ConfigSource = .repository,
    authority: Authority = .repository_read,
    fingerprinted: bool = true,
};

const config_fields = [_]ConfigField{
    .{ .name = "repository_id" },
    .{ .name = "database" },
    .{ .name = "content_manifest" },
    .{ .name = "health_report" },
    .{ .name = "max_entries" },
    .{ .name = "max_files" },
    .{ .name = "max_file_bytes" },
    .{ .name = "max_source_bytes" },
    .{ .name = "max_depth" },
    .{ .name = "max_path_bytes" },
    .{ .name = "max_nodes" },
    .{ .name = "max_edges" },
    .{ .name = "automatic_gc" },
    .{ .name = "retention_generations" },
    .{ .name = "retention_grace_ms" },
};

pub const EffectiveConfig = struct {
    schema: []const u8 = effective_config_schema,
    schema_version: u32 = schema_version,
    config: project.Config,
    fields: []const ConfigField = &config_fields,
    maximum_repository_authority: Authority = .repository_read,
    ambient_credentials_consulted: bool = false,
};

pub const Dimensions = struct {
    generation: HealthStatus = .partial,
    config: HealthStatus = .healthy,
    discovery: HealthStatus = .partial,
    ownership: HealthStatus = .partial,
    freshness: HealthStatus = .partial,
    storage: HealthStatus = .partial,
    indexes: HealthStatus = .partial,
    providers: HealthStatus = .partial,
    semantics: HealthStatus = .partial,
    self_manager: HealthStatus = .partial,
    resources: HealthStatus = .partial,
};

pub const Diagnostic = struct {
    code: []const u8 = "",
    severity: []const u8 = "error",
    stage: []const u8 = "validation",
    status: HealthStatus = .partial,
    redacted_detail: []const u8 = "",
    source_ref: []const u8 = "",
    provider_ref: []const u8 = "zgraphy/native",
    repair_hint: []const u8 = "",
    replay_command: []const u8 = "zgraphy doctor --json",
};

pub const DoctorReport = struct {
    status: HealthStatus = .partial,
    ready: bool = false,
    repository_id: []const u8,
    dimensions: Dimensions = .{},
    current_discovery_digest: [64]u8 = @splat(0),
    current_ownership_digest: [64]u8 = @splat(0),
    stored_discovery_digest: [64]u8 = @splat(0),
    stored_ownership_digest: [64]u8 = @splat(0),
    current_repository_context_fingerprint: [71]u8 = @splat(0),
    stored_repository_context_fingerprint: [71]u8 = @splat(0),
    has_current: bool = false,
    has_stored: bool = false,
    has_current_repository_context: bool = false,
    has_stored_repository_context: bool = false,
    change_lineage_summary: change_lineage.Summary = .{},
    origin_summary: origin_ledger.Summary = .{},
    last_repair: repair.Summary = .{},
    nodes: usize = 0,
    edges: usize = 0,
    vectors: usize = 0,
    retention: retention.Summary = .{},
    diagnostic_storage: [8]Diagnostic = @splat(Diagnostic{}),
    diagnostic_count: usize = 0,

    pub fn diagnostics(self: *const DoctorReport) []const Diagnostic {
        return self.diagnostic_storage[0..self.diagnostic_count];
    }

    fn addDiagnostic(self: *DoctorReport, diagnostic: Diagnostic) void {
        if (self.diagnostic_count >= self.diagnostic_storage.len) return;
        self.diagnostic_storage[self.diagnostic_count] = diagnostic;
        self.diagnostic_count += 1;
    }
};

pub const WatchQueueStatus = enum {
    empty,
    ready,
    corrupt,
    unavailable,
};

pub const WatchDoctorView = struct {
    status: WatchQueueStatus,
    pending_requests: usize = 0,
    pending_hints: usize = 0,
    fingerprint: []const u8 = "",
    repair_hint: []const u8 = "",
};

const ContentManifestHeader = struct {
    schema: []const u8,
    schema_version: u32,
    repository_id: []const u8,
    discovery_manifest_digest: []const u8,
    ownership_manifest_digest: []const u8,
    complete: bool,
};

const ContentManifestRecords = struct {
    schema: []const u8,
    schema_version: u32,
    repository_id: []const u8,
    discovery_manifest_digest: []const u8,
    ownership_manifest_digest: []const u8,
    complete: bool,
    records: []const discovery.Record,
};

const SourceChanges = struct {
    allocator: std.mem.Allocator,
    items: []delta_journal.SourceChange,

    fn deinit(self: *SourceChanges) void {
        for (self.items) |item| self.allocator.free(item.path);
        self.allocator.free(self.items);
        self.items = &.{};
    }
};

const HealthHeader = struct {
    schema: []const u8,
    schema_version: u32,
    status: HealthStatus,
    complete: bool,
};

const limitations = [_][]const u8{
    "canonical base rows are checkpointed per generation while digest-bound deltas provide exact replay and recovery evidence",
    "foreground watch and reader-safe bounded generation/cache retention are supported while daemon and Git-hook installation remain unsupported",
    "secondary indexes are digest-bound and rebuilt from canonical rows; compact persisted posting columns remain deferred",
};

pub fn buildOptions(config: project.Config) indexer.BuildOptions {
    return .{
        .repository_id = config.repository_id,
        .max_entries = config.max_entries,
        .max_files = config.max_files,
        .max_file_bytes = config.max_file_bytes,
        .max_source_bytes = config.max_source_bytes,
        .max_depth = config.max_depth,
        .max_path_bytes = config.max_path_bytes,
        .max_nodes = config.max_nodes,
        .max_edges = config.max_edges,
    };
}

pub fn effectiveConfig(config: project.Config) EffectiveConfig {
    return .{ .config = config };
}

const UpdateLease = struct {
    io: std.Io,
    file: std.Io.File,

    fn acquire(io: std.Io, root: std.Io.Dir) !UpdateLease {
        try root.createDirPath(io, ".zgraphy");
        if (root.statFile(io, update_lock_path, .{ .follow_symlinks = false })) |stat| {
            if (stat.kind != .file) return error.InvalidUpdateLockArtifact;
        } else |failure| switch (failure) {
            error.FileNotFound => {},
            else => return failure,
        }
        const file = root.createFile(io, update_lock_path, .{
            .read = true,
            .truncate = false,
            .lock = .exclusive,
            .lock_nonblocking = true,
            .resolve_beneath = true,
        }) catch |failure| switch (failure) {
            error.WouldBlock => return error.UpdateInProgress,
            else => return failure,
        };
        return .{ .io = io, .file = file };
    }

    fn deinit(self: *UpdateLease) void {
        self.file.unlock(self.io);
        self.file.close(self.io);
    }
};

pub const GenerationReadLease = struct {
    io: std.Io,
    file: std.Io.File,

    pub fn acquireShared(io: std.Io, root: std.Io.Dir) !GenerationReadLease {
        try root.createDirPath(io, ".zgraphy/runtime");
        try validateReaderLockArtifact(io, root);
        const file = try root.createFile(io, generation_reader_lock_path, .{
            .read = true,
            .truncate = false,
            .lock = .shared,
            .resolve_beneath = true,
        });
        return .{ .io = io, .file = file };
    }

    fn tryAcquireExclusive(io: std.Io, root: std.Io.Dir) !?GenerationReadLease {
        try root.createDirPath(io, ".zgraphy/runtime");
        try validateReaderLockArtifact(io, root);
        const file = root.createFile(io, generation_reader_lock_path, .{
            .read = true,
            .truncate = false,
            .lock = .exclusive,
            .lock_nonblocking = true,
            .resolve_beneath = true,
        }) catch |failure| switch (failure) {
            error.WouldBlock => return null,
            else => return failure,
        };
        return .{ .io = io, .file = file };
    }

    pub fn deinit(self: *GenerationReadLease) void {
        self.file.unlock(self.io);
        self.file.close(self.io);
    }

    fn validateReaderLockArtifact(io: std.Io, root: std.Io.Dir) !void {
        if (root.statFile(io, generation_reader_lock_path, .{ .follow_symlinks = false })) |stat| {
            if (stat.kind != .file) return error.InvalidGenerationReaderLockArtifact;
        } else |failure| switch (failure) {
            error.FileNotFound => {},
            else => return failure,
        }
    }
};

const GenerationPaths = struct {
    allocator: std.mem.Allocator,
    directory: []const u8,
    database: []const u8,
    content_manifest: []const u8,
    extraction_manifest: []const u8,
    delta_journal: []const u8,
    repository_context: []const u8,
    change_lineage: []const u8,
    origin_ledger: []const u8,
    repair_report: []const u8,
    health_report: []const u8,
    metadata: []const u8,

    fn deinit(self: *GenerationPaths) void {
        self.allocator.free(self.directory);
        self.allocator.free(self.database);
        self.allocator.free(self.content_manifest);
        self.allocator.free(self.extraction_manifest);
        self.allocator.free(self.delta_journal);
        self.allocator.free(self.repository_context);
        self.allocator.free(self.change_lineage);
        self.allocator.free(self.origin_ledger);
        self.allocator.free(self.repair_report);
        self.allocator.free(self.health_report);
        self.allocator.free(self.metadata);
    }
};

pub fn rebuildManaged(
    allocator: std.mem.Allocator,
    io: std.Io,
    root: std.Io.Dir,
    config: project.Config,
    options: RebuildOptions,
) !ManagedBuild {
    try project.validateConfig(config);
    var lease = try UpdateLease.acquire(io, root);
    defer lease.deinit();
    return rebuildManagedLocked(allocator, io, root, config, options);
}

fn rebuildManagedLocked(
    allocator: std.mem.Allocator,
    io: std.Io,
    root: std.Io.Dir,
    config: project.Config,
    options: RebuildOptions,
) !ManagedBuild {
    var previous: ?std.json.Parsed(ActiveGeneration) = readActiveGeneration(allocator, io, root, config) catch null;
    defer if (previous) |*parsed| parsed.deinit();
    var previous_graph: ?model.RepositoryGraph = null;
    defer if (previous_graph) |*graph| graph.deinit();
    if (previous) |*parsed| {
        var loaded = loadGenerationGraph(allocator, io, root, config, parsed.value) catch null;
        if (loaded) |*value| previous_graph = value.graph;
    }
    const previous_manifest = if (previous) |*parsed| parsed.value.extraction_manifest else "";
    var options_value = buildOptions(config);
    options_value.extraction_cache_options = .{
        .enabled = options.use_extraction_cache,
        .previous_manifest = previous_manifest,
    };
    options_value.previous_graph = if (previous_graph) |*graph| graph else null;
    var built = try indexer.buildRepository(allocator, io, root, options_value);
    errdefer built.deinit();
    const publication = try publishBuiltLocked(
        allocator,
        io,
        root,
        config,
        &built,
        .explicit,
        options.activate,
        options.origin_overlays,
        .{},
    );
    return .{ .built = built, .publication = publication };
}

pub fn updateManaged(
    allocator: std.mem.Allocator,
    io: std.Io,
    root: std.Io.Dir,
    config: project.Config,
    options: RebuildOptions,
) !ManagedUpdate {
    try project.validateConfig(config);
    var lease = try UpdateLease.acquire(io, root);
    defer lease.deinit();
    if (options.activate and options.use_extraction_cache and options.origin_overlays.len == 0) {
        if (try trySemanticNoopLocked(allocator, io, root, config)) |semantic| return semantic;
    }
    var full = try rebuildManagedLocked(allocator, io, root, config, options);
    const summary = full.built.summary;
    full.built.deinit();
    return .{
        .summary = summary,
        .publication = full.publication,
        .kind = .full_rebuild,
    };
}

fn trySemanticNoopLocked(
    allocator: std.mem.Allocator,
    io: std.Io,
    root: std.Io.Dir,
    config: project.Config,
) !?ManagedUpdate {
    var active = readActiveGeneration(allocator, io, root, config) catch return null;
    defer active.deinit();
    var previous_content = readContentManifestRecords(allocator, io, root, active.value) catch return null;
    defer previous_content.deinit();
    var discovered = discovery.scan(allocator, io, root, discoveryOptions(config)) catch return null;
    defer discovered.deinit();
    if (!discoveryTopologyAllowsSemanticNoop(previous_content.value.records, discovered.records)) return null;
    var owned_context = ownership.analyze(allocator, io, root, &discovered, .{
        .max_manifest_bytes = config.max_file_bytes,
        .discovery_validated = true,
    }) catch return null;
    defer owned_context.deinit();
    const ownership_hex = std.fmt.bytesToHex(owned_context.manifest_digest, .lower);
    if (!std.mem.eql(u8, active.value.ownership_manifest_digest, &ownership_hex)) return null;
    var current_repository_context = repository_context.inspect(allocator, io, root) catch return null;
    defer current_repository_context.deinit();
    if (!std.mem.eql(u8, active.value.repository_context_fingerprint, current_repository_context.value.fingerprint)) return null;
    var extraction = (extraction_cache.proveZigSemanticNoop(
        allocator,
        io,
        root,
        &discovered,
        active.value.extraction_manifest,
        active.value.extraction_manifest_digest,
        true,
        .{ .max_source_bytes = config.max_file_bytes },
    ) catch return null) orelse return null;
    defer extraction.deinit();
    var metadata = readReusableGenerationMetadata(allocator, io, root, config, active.value) catch return null;
    defer metadata.deinit();
    const published = try publishSemanticNoopLocked(
        allocator,
        io,
        root,
        config,
        active.value,
        metadata.value,
        previous_content.value.records,
        &discovered,
        &owned_context,
        current_repository_context.value,
        &extraction,
    );
    return published;
}

fn discoveryTopologyAllowsSemanticNoop(previous: []const discovery.Record, current: []const discovery.Record) bool {
    if (previous.len != current.len) return false;
    var changed: usize = 0;
    for (previous, current) |prior, next| {
        if (!std.mem.eql(u8, prior.relative_path, next.relative_path) or !std.mem.eql(u8, &prior.path_digest, &next.path_digest) or
            !std.meta.eql(prior.classification, next.classification) or prior.disposition != next.disposition or
            !std.mem.eql(u8, prior.responsible, next.responsible))
        {
            return false;
        }
        if (prior.size == next.size and std.meta.eql(prior.content_digest, next.content_digest)) continue;
        if (next.disposition != .deeply_indexed or next.classification.language != .zig or
            next.classification.artifact != .source or next.classification.is_generated or prior.content_digest == null or
            next.content_digest == null or std.mem.eql(u8, &prior.content_digest.?, &next.content_digest.?))
        {
            return false;
        }
        changed += 1;
    }
    return changed > 0;
}

fn readReusableGenerationMetadata(
    allocator: std.mem.Allocator,
    io: std.Io,
    root: std.Io.Dir,
    config: project.Config,
    pointer: ActiveGeneration,
) !std.json.Parsed(GenerationMetadata) {
    try validateActiveGeneration(allocator, config, pointer);
    if (pointer.origin_source_dependencies != 0) return error.OriginHasSourceDependencies;
    const bytes = try root.readFileAlloc(io, pointer.metadata, allocator, .limited(max_generation_metadata_bytes));
    defer allocator.free(bytes);
    var parsed = std.json.parseFromSlice(GenerationMetadata, allocator, bytes, .{ .allocate = .alloc_always }) catch return error.CorruptGenerationMetadata;
    errdefer parsed.deinit();
    const value = parsed.value;
    const identity = generationIdentity(
        config.repository_id,
        if (std.mem.eql(u8, value.semantic_generation, value.generation)) "" else value.semantic_generation,
        value.parent_generation,
        value.replaces_generation,
        pointer.discovery_manifest_digest,
        pointer.ownership_manifest_digest,
        pointer.extraction_manifest_digest,
        pointer.graph_fingerprint,
        pointer.repository_context_fingerprint,
        pointer.change_lineage_input_fingerprint,
        pointer.origin_input_fingerprint,
        pointer.repair_plan_fingerprint,
    );
    if (!value.complete or !std.mem.eql(u8, value.schema, generation_schema) or value.schema_version != generation_schema_version or
        !std.mem.eql(u8, value.repository_id, config.repository_id) or !std.mem.eql(u8, value.generation, pointer.generation) or
        !std.mem.eql(u8, value.semantic_generation, pointer.semantic_generation) or !std.mem.eql(u8, value.parent_generation, pointer.parent_generation) or
        value.semantic_noop_depth != pointer.semantic_noop_depth or
        !std.mem.eql(u8, value.replaces_generation, pointer.replaces_generation) or !std.mem.eql(u8, &identity, pointer.generation) or
        !std.mem.eql(u8, value.recipe, freshness_recipe) or !std.mem.eql(u8, value.snapshot_schema, store.current_schema) or
        !std.mem.eql(u8, value.embedder, nendb.embedder) or
        !std.mem.eql(u8, value.database_artifact_fingerprint, pointer.database_artifact_fingerprint) or
        !std.mem.eql(u8, value.origin_artifact_fingerprint, pointer.origin_artifact_fingerprint) or
        !std.meta.eql(value.database_artifact_stamp, pointer.database_artifact_stamp) or
        !std.meta.eql(value.origin_artifact_stamp, pointer.origin_artifact_stamp) or
        !std.mem.eql(u8, value.discovery_manifest_digest, pointer.discovery_manifest_digest) or
        !std.mem.eql(u8, value.ownership_manifest_digest, pointer.ownership_manifest_digest) or
        !std.mem.eql(u8, value.extraction_manifest_digest, pointer.extraction_manifest_digest) or
        !std.mem.eql(u8, value.repository_context_fingerprint, pointer.repository_context_fingerprint) or
        !std.mem.eql(u8, value.change_lineage_input_fingerprint, pointer.change_lineage_input_fingerprint) or
        !std.mem.eql(u8, value.change_lineage_fingerprint, pointer.change_lineage_fingerprint) or
        !std.meta.eql(value.change_lineage_summary, pointer.change_lineage_summary) or
        !std.mem.eql(u8, value.origin_input_fingerprint, pointer.origin_input_fingerprint) or
        !std.mem.eql(u8, value.origin_fingerprint, pointer.origin_fingerprint) or
        !std.meta.eql(value.origin_summary, pointer.origin_summary) or value.origin_source_dependencies != pointer.origin_source_dependencies or
        !std.mem.eql(u8, value.repair_plan_fingerprint, pointer.repair_plan_fingerprint) or
        !std.mem.eql(u8, value.repair_fingerprint, pointer.repair_fingerprint) or !std.meta.eql(value.repair_summary, pointer.repair_summary) or
        !std.mem.eql(u8, value.graph_fingerprint, pointer.graph_fingerprint) or
        !std.mem.eql(u8, value.delta_fingerprint, pointer.delta_fingerprint) or !std.meta.eql(value.delta_summary, pointer.delta_summary) or
        !std.mem.eql(u8, value.secondary_index_schema, pointer.secondary_index_schema) or
        !std.mem.eql(u8, value.secondary_index_fingerprint, pointer.secondary_index_fingerprint) or
        !std.meta.eql(value.secondary_indexes, pointer.secondary_indexes) or value.build_summary.nodes != value.nodes or
        value.build_summary.edges != value.edges or value.build_summary.vectors != value.vectors or
        value.nodes != pointer.delta_summary.target_nodes or value.edges != pointer.delta_summary.target_edges or
        value.vectors != pointer.delta_summary.target_vectors or value.hyperedges != pointer.delta_summary.target_hyperedges or
        value.supernodes != pointer.delta_summary.target_supernodes)
    {
        return error.InvalidReusableGenerationMetadata;
    }
    const database_stamp = try artifactStamp(io, root, pointer.database);
    const origin_stamp = try artifactStamp(io, root, pointer.origin_ledger);
    if (!std.meta.eql(database_stamp, pointer.database_artifact_stamp) or
        !std.meta.eql(origin_stamp, pointer.origin_artifact_stamp))
    {
        return error.GenerationArtifactFingerprintMismatch;
    }
    var delta = try delta_journal.inspect(allocator, io, root, pointer.delta_journal);
    defer delta.deinit();
    try validateDeltaBindings(pointer, delta);
    try validateHealthHeader(allocator, io, root, pointer);
    var repair_report = try repair.read(allocator, io, root, pointer.repair_report);
    defer repair_report.deinit();
    try repair.validate(allocator, repair_report.value, pointer.generation, pointer.replaces_generation);
    return parsed;
}

fn countOriginDependencies(artifact: origin_ledger.Artifact) usize {
    var count: usize = 0;
    for (artifact.owners) |owner| count = std.math.add(usize, count, owner.dependencies.len) catch return std.math.maxInt(usize);
    return count;
}

fn publishSemanticNoopLocked(
    allocator: std.mem.Allocator,
    io: std.Io,
    root: std.Io.Dir,
    config: project.Config,
    active: ActiveGeneration,
    previous_metadata: GenerationMetadata,
    previous_records: []const discovery.Record,
    discovered: *const discovery.Result,
    owned_context: *const ownership.Result,
    current_repository_context: repository_context.Artifact,
    extraction: *const extraction_cache.BuildEvidence,
) !ManagedUpdate {
    const semantic_noop_depth = std.math.add(usize, active.semantic_noop_depth, 1) catch return error.SemanticNoopDepthExceeded;
    var previous_lineage = try change_lineage.read(allocator, io, root, active.change_lineage);
    defer previous_lineage.deinit();
    if (!std.mem.eql(u8, previous_lineage.value.repository_id, active.repository_id) or
        !std.mem.eql(u8, previous_lineage.value.parent_generation, active.parent_generation) or
        !std.mem.eql(u8, previous_lineage.value.target_generation, active.generation) or
        !std.mem.eql(u8, previous_lineage.value.input_fingerprint, active.change_lineage_input_fingerprint) or
        !std.mem.eql(u8, previous_lineage.value.fingerprint, active.change_lineage_fingerprint) or
        !std.meta.eql(previous_lineage.value.summary, active.change_lineage_summary))
    {
        return error.ChangeLineageBindingMismatch;
    }
    var lineage = try change_lineage.reconcile(
        allocator,
        config.repository_id,
        active.generation,
        previous_lineage.value,
        previous_records,
        discovered,
        config.max_files,
    );
    defer lineage.deinit();
    var repair_report = try repair.create(allocator, config.repository_id, active.generation, .{});
    defer repair_report.deinit();
    const discovery_hex = std.fmt.bytesToHex(discovered.manifest_digest, .lower);
    const ownership_hex = std.fmt.bytesToHex(owned_context.manifest_digest, .lower);
    const extraction_hex = std.fmt.bytesToHex(extraction.manifest.digest, .lower);
    const generation = generationIdentity(
        config.repository_id,
        active.semantic_generation,
        active.generation,
        "",
        &discovery_hex,
        &ownership_hex,
        &extraction_hex,
        active.graph_fingerprint,
        current_repository_context.fingerprint,
        lineage.value.input_fingerprint,
        active.origin_input_fingerprint,
        repair_report.value.plan_fingerprint,
    );
    try lineage.bindTargetGeneration(&generation);
    try repair_report.bindTargetGeneration(&generation);
    var paths = try generationPathsAlloc(allocator, &generation);
    defer paths.deinit();
    try root.createDirPath(io, paths.directory);

    const manifest_view = .{
        .schema = content_manifest_schema,
        .schema_version = schema_version,
        .complete = true,
        .repository_id = config.repository_id,
        .classifier_version = discovery.classifier_version,
        .policy_version = discovery.policy_version,
        .discovery_manifest_digest = discovery_hex[0..],
        .ownership_manifest_digest = ownership_hex[0..],
        .observed_entries = discovered.observed_entries,
        .hashed_bytes = discovered.hashed_bytes,
        .discovery_summary = discovered.summary,
        .ownership_summary = owned_context.summary,
        .records = discovered.records,
        .units = owned_context.units,
        .assignments = owned_context.assignments,
    };
    const manifest_bytes = try std.json.Stringify.valueAlloc(allocator, manifest_view, .{});
    defer allocator.free(manifest_bytes);
    if (manifest_bytes.len > max_manifest_bytes) return error.ContentManifestTooLarge;
    try atomicWrite(allocator, io, root, paths.content_manifest, manifest_bytes);

    const extraction_bytes = try extraction_cache.encodeManifestAlloc(allocator, &extraction.manifest);
    defer allocator.free(extraction_bytes);
    try atomicWrite(allocator, io, root, paths.extraction_manifest, extraction_bytes);
    const context_bytes = try repository_context.encodeAlloc(allocator, current_repository_context);
    defer allocator.free(context_bytes);
    try atomicWrite(allocator, io, root, paths.repository_context, context_bytes);
    const lineage_bytes = try change_lineage.encodeAlloc(allocator, lineage.value);
    defer allocator.free(lineage_bytes);
    try atomicWrite(allocator, io, root, paths.change_lineage, lineage_bytes);
    const repair_bytes = try repair.encodeAlloc(allocator, repair_report.value);
    defer allocator.free(repair_bytes);
    try atomicWrite(allocator, io, root, paths.repair_report, repair_bytes);

    var index_identity: [71]u8 = @splat(0);
    index_identity[0..7].* = "sha256:".*;
    @memcpy(index_identity[7..], active.secondary_index_fingerprint);
    const delta_result = try delta_journal.writeIdentity(allocator, io, root, paths.delta_journal, .{
        .repository_id = config.repository_id,
        .parent_generation = active.generation,
        .target_generation = &generation,
        .graph_fingerprint = active.graph_fingerprint,
        .index_fingerprint = &index_identity,
        .target_nodes = previous_metadata.nodes,
        .target_edges = previous_metadata.edges,
        .target_vectors = previous_metadata.vectors,
        .target_hyperedges = previous_metadata.hyperedges,
        .target_supernodes = previous_metadata.supernodes,
    });

    var summary = previous_metadata.build_summary;
    summary.files_discovered = discovered.summary.total;
    summary.files_placed = discovered.summary.deeply_indexed + discovered.summary.placed_unsupported + discovered.summary.placed_asset;
    summary.files_skipped = discovered.summary.total - summary.files_placed;
    summary.source_bytes = discovered.hashed_bytes;
    summary.discovery_manifest_digest = discovered.manifest_digest;
    summary.discovery = discovered.summary;
    summary.ownership_manifest_digest = owned_context.manifest_digest;
    summary.ownership = owned_context.summary;
    summary.cacheable_files = extraction.stats.cacheable_files;
    summary.cache_hits = extraction.stats.hits;
    summary.cache_misses = extraction.stats.misses;
    summary.cache_rejected = extraction.stats.rejected;
    summary.cache_writes = extraction.stats.writes;
    summary.reparsed_files = extraction.stats.reparsed_files;
    summary.direct_invalidations = extraction.stats.direct_invalidations;
    summary.invalidation_closure = extraction.stats.invalidation_closure;
    summary.derived_hyperedges_reused = previous_metadata.hyperedges;
    summary.derived_hyperedges_recomputed = 0;
    summary.derived_supernodes_reused = previous_metadata.supernodes;
    summary.derived_supernodes_recomputed = 0;

    const graph_health = freshness.Health{
        .nodes = previous_metadata.nodes,
        .edges = previous_metadata.edges,
        .vectors = previous_metadata.vectors,
        .hyperedges = previous_metadata.hyperedges,
        .supernodes = previous_metadata.supernodes,
        .dangling_edges = 0,
        .dangling_hyperedge_participants = 0,
        .dangling_supernode_members = 0,
        .missing_input_hyperedges = 0,
        .invalid_supernode_proofs = 0,
        .missing_vectors = 0,
        .unowned_vectors = 0,
        .true_orphans = 0,
    };
    const dimensions = Dimensions{
        .generation = .healthy,
        .config = .healthy,
        .discovery = .healthy,
        .ownership = .healthy,
        .freshness = .healthy,
        .storage = .healthy,
        .indexes = .healthy,
        .providers = if (owned_context.summary.adapters_failed == 0) .healthy else .degraded,
        .semantics = .partial,
        .self_manager = .healthy,
        .resources = .healthy,
    };
    const health_bytes = try std.json.Stringify.valueAlloc(allocator, .{
        .schema = health_schema,
        .schema_version = schema_version,
        .complete = true,
        .status = HealthStatus.healthy,
        .ready = true,
        .repository_id = config.repository_id,
        .discovery_manifest_digest = discovery_hex[0..],
        .ownership_manifest_digest = ownership_hex[0..],
        .dimensions = dimensions,
        .discovery = discovered.summary,
        .ownership = owned_context.summary,
        .graph = graph_health,
        .limitations = &limitations,
    }, .{});
    defer allocator.free(health_bytes);
    if (health_bytes.len > max_health_bytes) return error.HealthReportTooLarge;
    try atomicWrite(allocator, io, root, paths.health_report, health_bytes);

    const metadata = GenerationMetadata{
        .schema = generation_schema,
        .schema_version = generation_schema_version,
        .repository_id = config.repository_id,
        .generation = &generation,
        .semantic_generation = active.semantic_generation,
        .semantic_noop_depth = semantic_noop_depth,
        .parent_generation = active.generation,
        .replaces_generation = "",
        .recipe = freshness_recipe,
        .snapshot_schema = store.current_schema,
        .embedder = nendb.embedder,
        .database_artifact_fingerprint = active.database_artifact_fingerprint,
        .origin_artifact_fingerprint = active.origin_artifact_fingerprint,
        .database_artifact_stamp = active.database_artifact_stamp,
        .origin_artifact_stamp = active.origin_artifact_stamp,
        .discovery_manifest_digest = &discovery_hex,
        .ownership_manifest_digest = &ownership_hex,
        .extraction_manifest_digest = &extraction_hex,
        .repository_context_schema = repository_context.schema,
        .repository_context_fingerprint = current_repository_context.fingerprint,
        .change_lineage_schema = change_lineage.schema,
        .change_lineage_input_fingerprint = lineage.value.input_fingerprint,
        .change_lineage_fingerprint = lineage.value.fingerprint,
        .change_lineage_summary = lineage.value.summary,
        .origin_schema = origin_ledger.schema,
        .origin_input_fingerprint = active.origin_input_fingerprint,
        .origin_fingerprint = active.origin_fingerprint,
        .origin_summary = active.origin_summary,
        .origin_source_dependencies = 0,
        .repair_schema = repair.schema,
        .repair_plan_fingerprint = repair_report.value.plan_fingerprint,
        .repair_fingerprint = repair_report.value.fingerprint,
        .repair_summary = repair_report.value.summary,
        .graph_fingerprint = active.graph_fingerprint,
        .delta_schema = delta_journal.schema,
        .delta_fingerprint = &delta_result.journal_fingerprint,
        .delta_summary = delta_result.summary,
        .secondary_index_schema = nendb.secondary_index_schema,
        .secondary_index_fingerprint = active.secondary_index_fingerprint,
        .secondary_indexes = active.secondary_indexes,
        .build_summary = summary,
        .nodes = previous_metadata.nodes,
        .edges = previous_metadata.edges,
        .vectors = previous_metadata.vectors,
        .hyperedges = previous_metadata.hyperedges,
        .supernodes = previous_metadata.supernodes,
        .pruned = .{},
        .complete = true,
    };
    const metadata_bytes = try std.json.Stringify.valueAlloc(allocator, metadata, .{});
    defer allocator.free(metadata_bytes);
    try atomicWrite(allocator, io, root, paths.metadata, metadata_bytes);

    const pointer = ActiveGeneration{
        .schema = active_generation_schema,
        .schema_version = generation_schema_version,
        .repository_id = config.repository_id,
        .generation = &generation,
        .semantic_generation = active.semantic_generation,
        .semantic_noop_depth = semantic_noop_depth,
        .parent_generation = active.generation,
        .replaces_generation = "",
        .database = active.database,
        .content_manifest = paths.content_manifest,
        .extraction_manifest = paths.extraction_manifest,
        .delta_journal = paths.delta_journal,
        .repository_context = paths.repository_context,
        .change_lineage = paths.change_lineage,
        .origin_ledger = active.origin_ledger,
        .repair_report = paths.repair_report,
        .health_report = paths.health_report,
        .metadata = paths.metadata,
        .database_artifact_fingerprint = active.database_artifact_fingerprint,
        .origin_artifact_fingerprint = active.origin_artifact_fingerprint,
        .database_artifact_stamp = active.database_artifact_stamp,
        .origin_artifact_stamp = active.origin_artifact_stamp,
        .discovery_manifest_digest = &discovery_hex,
        .ownership_manifest_digest = &ownership_hex,
        .extraction_manifest_digest = &extraction_hex,
        .repository_context_fingerprint = current_repository_context.fingerprint,
        .change_lineage_input_fingerprint = lineage.value.input_fingerprint,
        .change_lineage_fingerprint = lineage.value.fingerprint,
        .change_lineage_summary = lineage.value.summary,
        .origin_input_fingerprint = active.origin_input_fingerprint,
        .origin_fingerprint = active.origin_fingerprint,
        .origin_summary = active.origin_summary,
        .origin_source_dependencies = 0,
        .repair_plan_fingerprint = repair_report.value.plan_fingerprint,
        .repair_fingerprint = repair_report.value.fingerprint,
        .repair_summary = repair_report.value.summary,
        .graph_fingerprint = active.graph_fingerprint,
        .delta_schema = delta_journal.schema,
        .delta_fingerprint = &delta_result.journal_fingerprint,
        .delta_summary = delta_result.summary,
        .secondary_index_schema = nendb.secondary_index_schema,
        .secondary_index_fingerprint = active.secondary_index_fingerprint,
        .secondary_indexes = active.secondary_indexes,
        .complete = true,
    };
    try validateSemanticCandidateInMemory(
        allocator,
        config,
        pointer,
        metadata,
        current_repository_context,
        lineage.value,
        repair_report.value,
        &extraction.manifest,
        delta_result,
    );
    try atomicWrite(allocator, io, root, config.content_manifest, manifest_bytes);
    try atomicWrite(allocator, io, root, config.health_report, health_bytes);
    const pointer_bytes = try std.json.Stringify.valueAlloc(allocator, pointer, .{});
    defer allocator.free(pointer_bytes);
    try atomicWrite(allocator, io, root, active_generation_path, pointer_bytes);
    const retention_summary = automaticSemanticRetentionLocked(allocator, io, root, config, pointer);
    const publication = try publicationAlloc(allocator, .{
        .status = .refreshed,
        .trigger = .changed_manifest,
        .activated = true,
        .generation = &generation,
        .previous_generation = active.generation,
        .database = active.database,
        .delta_journal = paths.delta_journal,
        .delta_fingerprint = &delta_result.journal_fingerprint,
        .delta_summary = delta_result.summary,
        .checked_files = discovered.summary.total,
        .reparsed_files = extraction.stats.reparsed_files,
        .cache_hits = extraction.stats.hits,
        .cache_misses = extraction.stats.misses,
        .cache_rejected = extraction.stats.rejected,
        .cache_writes = extraction.stats.writes,
        .direct_invalidations = extraction.stats.direct_invalidations,
        .invalidation_closure = extraction.stats.invalidation_closure,
        .pruned = .{},
        .origin = active.origin_summary,
        .repair = repair_report.value.summary,
        .retention = retention_summary,
    });
    return .{ .summary = summary, .publication = publication, .kind = .semantic_noop };
}

fn validateSemanticCandidateInMemory(
    allocator: std.mem.Allocator,
    config: project.Config,
    pointer: ActiveGeneration,
    metadata: GenerationMetadata,
    context: repository_context.Artifact,
    lineage: change_lineage.Artifact,
    repair_report: repair.Report,
    extraction_manifest: *const extraction_cache.Manifest,
    delta: delta_journal.WriteResult,
) !void {
    try validateActiveGeneration(allocator, config, pointer);
    try repair.validate(allocator, repair_report, pointer.generation, pointer.replaces_generation);
    if (!std.mem.eql(u8, metadata.generation, pointer.generation) or
        !std.mem.eql(u8, metadata.semantic_generation, pointer.semantic_generation) or
        metadata.semantic_noop_depth != pointer.semantic_noop_depth or
        !std.mem.eql(u8, metadata.parent_generation, pointer.parent_generation) or
        !std.mem.eql(u8, metadata.discovery_manifest_digest, pointer.discovery_manifest_digest) or
        !std.mem.eql(u8, metadata.ownership_manifest_digest, pointer.ownership_manifest_digest) or
        !std.mem.eql(u8, metadata.extraction_manifest_digest, pointer.extraction_manifest_digest) or
        !std.mem.eql(u8, metadata.repository_context_fingerprint, pointer.repository_context_fingerprint) or
        !std.mem.eql(u8, metadata.change_lineage_input_fingerprint, pointer.change_lineage_input_fingerprint) or
        !std.mem.eql(u8, metadata.change_lineage_fingerprint, pointer.change_lineage_fingerprint) or
        !std.meta.eql(metadata.change_lineage_summary, pointer.change_lineage_summary) or
        !std.mem.eql(u8, metadata.origin_input_fingerprint, pointer.origin_input_fingerprint) or
        !std.mem.eql(u8, metadata.origin_fingerprint, pointer.origin_fingerprint) or
        !std.meta.eql(metadata.origin_summary, pointer.origin_summary) or
        !std.mem.eql(u8, metadata.repair_plan_fingerprint, pointer.repair_plan_fingerprint) or
        !std.mem.eql(u8, metadata.repair_fingerprint, pointer.repair_fingerprint) or
        !std.meta.eql(metadata.repair_summary, pointer.repair_summary) or
        !std.mem.eql(u8, metadata.graph_fingerprint, pointer.graph_fingerprint) or
        !std.mem.eql(u8, metadata.delta_fingerprint, pointer.delta_fingerprint) or
        !std.meta.eql(metadata.delta_summary, pointer.delta_summary) or
        !std.mem.eql(u8, metadata.secondary_index_fingerprint, pointer.secondary_index_fingerprint) or
        !std.meta.eql(metadata.secondary_indexes, pointer.secondary_indexes) or
        !std.mem.eql(u8, context.fingerprint, pointer.repository_context_fingerprint) or
        !std.mem.eql(u8, lineage.target_generation, pointer.generation) or
        !std.mem.eql(u8, lineage.input_fingerprint, pointer.change_lineage_input_fingerprint) or
        !std.mem.eql(u8, lineage.fingerprint, pointer.change_lineage_fingerprint) or
        !std.meta.eql(lineage.summary, pointer.change_lineage_summary) or
        !std.mem.eql(u8, repair_report.target_generation, pointer.generation) or
        !std.mem.eql(u8, repair_report.plan_fingerprint, pointer.repair_plan_fingerprint) or
        !std.mem.eql(u8, repair_report.fingerprint, pointer.repair_fingerprint) or
        !std.meta.eql(repair_report.summary, pointer.repair_summary) or
        !std.mem.eql(u8, &delta.journal_fingerprint, pointer.delta_fingerprint) or
        !std.meta.eql(delta.summary, pointer.delta_summary))
    {
        return error.InvalidSemanticCandidate;
    }
    const extraction_hex = std.fmt.bytesToHex(extraction_manifest.digest, .lower);
    if (!std.mem.eql(u8, &extraction_hex, pointer.extraction_manifest_digest)) return error.InvalidSemanticCandidate;
}

pub fn ensureFresh(
    allocator: std.mem.Allocator,
    io: std.Io,
    root: std.Io.Dir,
    config: project.Config,
) !Publication {
    try project.validateConfig(config);
    var lease = try UpdateLease.acquire(io, root);
    defer lease.deinit();

    var active: ?std.json.Parsed(ActiveGeneration) = readActiveGeneration(allocator, io, root, config) catch |failure| switch (failure) {
        error.FileNotFound => null,
        error.CorruptActiveGeneration, error.IncompatibleActiveGeneration => null,
        else => return failure,
    };
    defer if (active) |*parsed| parsed.deinit();
    const missing_active = active == null;

    var discovered = try discovery.scan(allocator, io, root, discoveryOptions(config));
    defer discovered.deinit();
    var owned_context = try ownership.analyze(allocator, io, root, &discovered, .{ .discovery_validated = true });
    defer owned_context.deinit();
    var current_repository_context = try repository_context.inspect(allocator, io, root);
    defer current_repository_context.deinit();
    const discovery_hex = std.fmt.bytesToHex(discovered.manifest_digest, .lower);
    const ownership_hex = std.fmt.bytesToHex(owned_context.manifest_digest, .lower);

    var trigger: RefreshTrigger = if (missing_active) .missing_generation else .changed_manifest;
    var repair_plan = repair.Plan{};
    if (active) |*parsed| {
        const repository_context_matches = std.mem.eql(u8, parsed.value.repository_context_fingerprint, current_repository_context.value.fingerprint);
        const manifests_match = std.mem.eql(u8, parsed.value.discovery_manifest_digest, &discovery_hex) and
            std.mem.eql(u8, parsed.value.ownership_manifest_digest, &ownership_hex);
        if (manifests_match and repository_context_matches) {
            const required_repair: ?repair.Plan = activeGenerationHealthy(allocator, io, root, config, parsed.value) catch |failure| blk: {
                trigger = .invalid_generation;
                repair_plan = .{
                    .action = .clean_rebuild,
                    .cause = switch (failure) {
                        error.CorruptOriginArtifact,
                        error.InvalidOriginArtifact,
                        error.OriginLedgerBindingMismatch,
                        error.OriginInputFingerprintMismatch,
                        error.OriginFingerprintMismatch,
                        => .origin_invalid,
                        else => .delta_unavailable,
                    },
                    .replaces_generation = parsed.value.generation,
                };
                break :blk null;
            };
            if (required_repair) |plan| {
                if (plan.action == .none) {
                    const retention_summary = automaticRetentionLocked(allocator, io, root, config, parsed.value);
                    return publicationAlloc(allocator, .{
                        .status = .current,
                        .trigger = .unchanged,
                        .activated = true,
                        .generation = parsed.value.generation,
                        .previous_generation = parsed.value.generation,
                        .database = parsed.value.database,
                        .delta_journal = parsed.value.delta_journal,
                        .delta_fingerprint = parsed.value.delta_fingerprint,
                        .delta_summary = parsed.value.delta_summary,
                        .checked_files = discovered.summary.total,
                        .reparsed_files = 0,
                        .cache_hits = 0,
                        .cache_misses = 0,
                        .cache_rejected = 0,
                        .cache_writes = 0,
                        .direct_invalidations = 0,
                        .invalidation_closure = 0,
                        .pruned = .{},
                        .origin = parsed.value.origin_summary,
                        .repair = parsed.value.repair_summary,
                        .retention = retention_summary,
                    });
                }
                trigger = .repair_generation;
                repair_plan = plan;
            }
        } else if (manifests_match) {
            trigger = .changed_repository_context;
        }
    }

    if (active) |*parsed| semantic: {
        if (trigger != .changed_manifest or repair_plan.action != .none or
            !std.mem.eql(u8, parsed.value.repository_context_fingerprint, current_repository_context.value.fingerprint))
        {
            break :semantic;
        }
        var previous_content = readContentManifestRecords(allocator, io, root, parsed.value) catch break :semantic;
        defer previous_content.deinit();
        if (!discoveryTopologyAllowsSemanticNoop(previous_content.value.records, discovered.records)) break :semantic;
        if (!std.mem.eql(u8, parsed.value.ownership_manifest_digest, &ownership_hex)) break :semantic;
        var extraction = (extraction_cache.proveZigSemanticNoop(
            allocator,
            io,
            root,
            &discovered,
            parsed.value.extraction_manifest,
            parsed.value.extraction_manifest_digest,
            true,
            .{ .max_source_bytes = config.max_file_bytes },
        ) catch break :semantic) orelse break :semantic;
        defer extraction.deinit();
        var metadata = readReusableGenerationMetadata(allocator, io, root, config, parsed.value) catch break :semantic;
        defer metadata.deinit();
        const update = try publishSemanticNoopLocked(
            allocator,
            io,
            root,
            config,
            parsed.value,
            metadata.value,
            previous_content.value.records,
            &discovered,
            &owned_context,
            current_repository_context.value,
            &extraction,
        );
        return update.publication;
    }

    var options_value = buildOptions(config);
    var previous_graph: ?model.RepositoryGraph = null;
    defer if (previous_graph) |*graph| graph.deinit();
    if (active) |*parsed| {
        var loaded = loadGenerationGraph(allocator, io, root, config, parsed.value) catch null;
        if (loaded) |*value| previous_graph = value.graph;
    }
    options_value.extraction_cache_options = .{
        .enabled = true,
        .previous_manifest = if (active) |*parsed| parsed.value.extraction_manifest else "",
    };
    options_value.previous_graph = if (previous_graph) |*graph| graph else null;
    var built = try indexer.buildRepository(allocator, io, root, options_value);
    defer built.deinit();
    return publishBuiltLocked(allocator, io, root, config, &built, trigger, true, &.{}, repair_plan);
}

/// Open the published graph for reading, without consulting the working tree.
///
/// `loadManagedGraph` answers a different question than a query asks. It runs
/// `ensureFresh`, which SHA-256s every file in the repository through
/// `discovery.scan`, analyses ownership, inspects repository context, and takes
/// an **exclusive** `UpdateLease` — before the shared read lease is even
/// acquired. Two concurrent queries therefore fail with `UpdateInProgress`, and
/// on a 173-file corpus a single query costs 627 ms of which almost none is
/// retrieval.
///
/// The separation this makes: *is my index stale* is a question about the
/// working tree and belongs to build, watch and status. *Answer my question* is
/// a question about the published generation and needs only that generation to
/// be internally sound. This validates the generation exactly as thoroughly as
/// the write path does — same checks, same failures — and simply does not ask
/// the first question.
///
/// It therefore reports `tree_verified = false`. The graph is guaranteed
/// consistent with itself and *not* guaranteed to match the files on disk. A
/// reader that needs the stronger guarantee runs a build. Saying so is the
/// whole point: a fast answer that quietly might be stale is a worse trade than
/// the 627 ms it replaces.
pub fn openManagedGraph(
    allocator: std.mem.Allocator,
    io: std.Io,
    root: std.Io.Dir,
    config: project.Config,
) !ManagedGraph {
    try project.validateConfig(config);
    var reader = try GenerationReadLease.acquireShared(io, root);
    defer reader.deinit();
    var active = try readActiveGeneration(allocator, io, root, config);
    defer active.deinit();

    var loaded = try loadGenerationGraph(allocator, io, root, config, active.value);
    errdefer loaded.graph.deinit();
    const plan = try validateLoadedGeneration(allocator, io, root, config, active.value, &loaded);
    if (plan.action != .none) return error.UnhealthyActiveGeneration;

    const publication = try publicationAlloc(allocator, .{
        .status = .current,
        .trigger = .unchanged,
        .activated = true,
        .generation = active.value.generation,
        .previous_generation = active.value.generation,
        .database = active.value.database,
        .delta_journal = active.value.delta_journal,
        .delta_fingerprint = active.value.delta_fingerprint,
        .delta_summary = active.value.delta_summary,
        .checked_files = 0,
        .reparsed_files = 0,
        .cache_hits = 0,
        .cache_misses = 0,
        .cache_rejected = 0,
        .cache_writes = 0,
        .direct_invalidations = 0,
        .invalidation_closure = 0,
        .pruned = .{},
        .origin = active.value.origin_summary,
        .repair = active.value.repair_summary,
        .retention = .{},
        .tree_verified = false,
    });
    return .{ .graph = loaded.graph, .refresh = publication, .recovery_source = loaded.recovery_source };
}

pub fn loadManagedGraph(
    allocator: std.mem.Allocator,
    io: std.Io,
    root: std.Io.Dir,
    config: project.Config,
) !ManagedGraph {
    var refresh = try ensureFresh(allocator, io, root, config);
    errdefer refresh.deinit();
    var reader = try GenerationReadLease.acquireShared(io, root);
    defer reader.deinit();
    var active = try readActiveGeneration(allocator, io, root, config);
    defer active.deinit();
    if (!std.mem.eql(u8, active.value.generation, refresh.generation)) return error.ActiveGenerationChanged;
    var loaded = try loadGenerationGraph(allocator, io, root, config, active.value);
    errdefer loaded.graph.deinit();
    if (!freshness.inspect(&loaded.graph).clean()) return error.UnhealthyActiveGeneration;
    return .{ .graph = loaded.graph, .refresh = refresh, .recovery_source = loaded.recovery_source };
}

pub fn readActiveGeneration(
    allocator: std.mem.Allocator,
    io: std.Io,
    root: std.Io.Dir,
    config: project.Config,
) !std.json.Parsed(ActiveGeneration) {
    const bytes = try root.readFileAlloc(io, active_generation_path, allocator, .limited(max_active_generation_bytes));
    defer allocator.free(bytes);
    var parsed = std.json.parseFromSlice(ActiveGeneration, allocator, bytes, .{ .allocate = .alloc_always }) catch return error.CorruptActiveGeneration;
    errdefer parsed.deinit();
    try validateActiveGeneration(allocator, config, parsed.value);
    return parsed;
}

pub fn collectGarbage(
    allocator: std.mem.Allocator,
    io: std.Io,
    root: std.Io.Dir,
    config: project.Config,
    mode: retention.Mode,
) !retention.Report {
    try project.validateConfig(config);
    var update = try UpdateLease.acquire(io, root);
    defer update.deinit();
    var active = try readActiveGeneration(allocator, io, root, config);
    defer active.deinit();
    return collectGarbageLocked(allocator, io, root, config, active.value, mode);
}

pub fn pinGeneration(
    allocator: std.mem.Allocator,
    io: std.Io,
    root: std.Io.Dir,
    config: project.Config,
    generation: []const u8,
) !void {
    try setGenerationPin(allocator, io, root, config, generation, true);
}

pub fn unpinGeneration(
    allocator: std.mem.Allocator,
    io: std.Io,
    root: std.Io.Dir,
    config: project.Config,
    generation: []const u8,
) !void {
    try setGenerationPin(allocator, io, root, config, generation, false);
}

fn setGenerationPin(
    allocator: std.mem.Allocator,
    io: std.Io,
    root: std.Io.Dir,
    config: project.Config,
    generation: []const u8,
    present: bool,
) !void {
    try project.validateConfig(config);
    var update = try UpdateLease.acquire(io, root);
    defer update.deinit();
    try retention.setPin(
        allocator,
        io,
        root,
        config.repository_id,
        generation,
        generation_schema,
        generation_schema_version,
        present,
    );
}

fn collectGarbageLocked(
    allocator: std.mem.Allocator,
    io: std.Io,
    root: std.Io.Dir,
    config: project.Config,
    active: ActiveGeneration,
    mode: retention.Mode,
) !retention.Report {
    var report = try retention.plan(allocator, io, root, .{
        .repository_id = config.repository_id,
        .active_generation = active.generation,
        .active_semantic = active.semantic_generation,
        .active_parent = active.parent_generation,
        .active_replaces = active.replaces_generation,
        .generation_schema = generation_schema,
        .generation_schema_version = generation_schema_version,
        .policy = retentionPolicy(config),
        .now_ms = wallTimeMillis(io),
    });
    errdefer report.deinit();
    if (mode == .dry_run) {
        report.summary.status = .planned;
        try retention.writeLatest(allocator, io, root, &report);
        return report;
    }
    var reader = (try GenerationReadLease.tryAcquireExclusive(io, root)) orelse {
        report.summary.status = .deferred_readers;
        report.summary.reader_deferred = 1;
        try retention.writeLatest(allocator, io, root, &report);
        return report;
    };
    defer reader.deinit();
    retention.apply(io, root, &report);
    try retention.writeLatest(allocator, io, root, &report);
    return report;
}

fn automaticRetentionLocked(
    allocator: std.mem.Allocator,
    io: std.Io,
    root: std.Io.Dir,
    config: project.Config,
    active: ActiveGeneration,
) retention.Summary {
    if (!config.automatic_gc) return .{ .status = .disabled };
    var report = collectGarbageLocked(allocator, io, root, config, active, .apply) catch return .{
        .status = .failed,
        .failed_actions = 1,
    };
    defer report.deinit();
    return report.summary;
}

fn automaticSemanticRetentionLocked(
    allocator: std.mem.Allocator,
    io: std.Io,
    root: std.Io.Dir,
    config: project.Config,
    active: ActiveGeneration,
) retention.Summary {
    if (!config.automatic_gc) return .{ .status = .disabled };
    if (active.semantic_noop_depth % config.retention_generations != 0) {
        return .{
            .status = .planned,
            .retained_generations = @min(active.semantic_noop_depth + 1, config.retention_generations + 1),
            .grace_deferred = 1,
        };
    }
    return automaticRetentionLocked(allocator, io, root, config, active);
}

fn retentionPolicy(config: project.Config) retention.Policy {
    return .{
        .automatic_gc = config.automatic_gc,
        .retention_generations = config.retention_generations,
        .retention_grace_ms = config.retention_grace_ms,
    };
}

fn wallTimeMillis(io: std.Io) u64 {
    const value = std.Io.Clock.real.now(io).toMilliseconds();
    return if (value <= 0) 0 else @intCast(value);
}

const PublicationInput = struct {
    /// Defaults true so every existing construction site keeps its meaning;
    /// only the read path sets it false.
    tree_verified: bool = true,
    status: RefreshStatus,
    trigger: RefreshTrigger,
    activated: bool,
    generation: []const u8,
    previous_generation: []const u8,
    database: []const u8,
    delta_journal: []const u8,
    delta_fingerprint: []const u8,
    delta_summary: delta_journal.Summary,
    checked_files: usize,
    reparsed_files: usize,
    cache_hits: usize,
    cache_misses: usize,
    cache_rejected: usize,
    cache_writes: usize,
    direct_invalidations: usize,
    invalidation_closure: usize,
    pruned: PrunedRecords,
    origin: origin_ledger.Summary,
    repair: repair.Summary,
    retention: retention.Summary = .{},
};

fn publicationAlloc(allocator: std.mem.Allocator, input: PublicationInput) !Publication {
    const generation = try memory.copy(u8, allocator, input.generation);
    errdefer allocator.free(generation);
    const previous = try memory.copy(u8, allocator, input.previous_generation);
    errdefer allocator.free(previous);
    const database = try memory.copy(u8, allocator, input.database);
    errdefer allocator.free(database);
    const journal = try memory.copy(u8, allocator, input.delta_journal);
    errdefer allocator.free(journal);
    const delta_fingerprint = try memory.copy(u8, allocator, input.delta_fingerprint);
    errdefer allocator.free(delta_fingerprint);
    return .{
        .allocator = allocator,
        .tree_verified = input.tree_verified,
        .status = input.status,
        .trigger = input.trigger,
        .activated = input.activated,
        .generation = generation,
        .previous_generation = previous,
        .database = database,
        .delta_journal = journal,
        .delta_fingerprint = delta_fingerprint,
        .delta_summary = input.delta_summary,
        .checked_files = input.checked_files,
        .reparsed_files = input.reparsed_files,
        .cache_hits = input.cache_hits,
        .cache_misses = input.cache_misses,
        .cache_rejected = input.cache_rejected,
        .cache_writes = input.cache_writes,
        .direct_invalidations = input.direct_invalidations,
        .invalidation_closure = input.invalidation_closure,
        .pruned = input.pruned,
        .origin = input.origin,
        .repair = input.repair,
        .retention = input.retention,
    };
}

fn deriveSourceChanges(
    allocator: std.mem.Allocator,
    io: std.Io,
    root: std.Io.Dir,
    previous_active: ?std.json.Parsed(ActiveGeneration),
    built: *const indexer.BuildResult,
    lineage: change_lineage.Artifact,
) !SourceChanges {
    if (previous_active == null) return .{ .allocator = allocator, .items = try memory.slice(delta_journal.SourceChange, allocator, 0) };
    const bytes = try root.readFileAlloc(io, previous_active.?.value.content_manifest, allocator, .limited(max_manifest_bytes));
    defer allocator.free(bytes);
    var parsed = std.json.parseFromSlice(ContentManifestRecords, allocator, bytes, .{
        .allocate = .alloc_always,
        .ignore_unknown_fields = true,
    }) catch return error.CorruptGenerationManifest;
    defer parsed.deinit();
    if (!parsed.value.complete or !std.mem.eql(u8, parsed.value.schema, content_manifest_schema) or
        parsed.value.schema_version != schema_version or !std.mem.eql(u8, parsed.value.repository_id, previous_active.?.value.repository_id))
    {
        return error.InvalidGenerationManifest;
    }

    var changes: std.ArrayList(delta_journal.SourceChange) = .empty;
    errdefer {
        for (changes.items) |item| allocator.free(item.path);
        changes.deinit(allocator);
    }
    for (parsed.value.records) |prior| {
        if (prior.relative_path.len == 0 or !graphBearingDisposition(prior.disposition)) continue;
        const cause: ?delta_journal.TombstoneCause = if (built.discovery_result.findByPath(prior.relative_path)) |current| blk: {
            if (!graphBearingDisposition(current.disposition)) break :blk .excluded;
            if (!std.meta.eql(prior.content_digest, current.content_digest)) break :blk .replaced;
            if (containsPath(built.extraction.manifest.direct_invalidations, prior.relative_path)) break :blk .replaced;
            if (containsPath(built.extraction.manifest.invalidation_closure, prior.relative_path)) break :blk .dependency_invalidated;
            break :blk null;
        } else blk: {
            if (lineageCause(lineage, previous_active.?.value.generation, prior.relative_path)) |lineage_cause| break :blk lineage_cause;
            root.access(io, prior.relative_path, .{}) catch break :blk .deleted;
            break :blk .excluded;
        };
        if (cause) |value| try changes.append(allocator, .{
            .path = try memory.copy(u8, allocator, prior.relative_path),
            .cause = value,
        });
    }
    return .{ .allocator = allocator, .items = try changes.toOwnedSlice(allocator) };
}

fn lineageCause(
    lineage: change_lineage.Artifact,
    predecessor_generation: []const u8,
    predecessor_path: []const u8,
) ?delta_journal.TombstoneCause {
    for (lineage.records) |record| {
        if (!std.mem.eql(u8, record.predecessor_generation, predecessor_generation) or
            !std.mem.eql(u8, record.predecessor_path, predecessor_path)) continue;
        return switch (record.relation) {
            .renamed_from => .renamed,
            .moved_from => .moved,
        };
    }
    return null;
}

fn readContentManifestRecords(
    allocator: std.mem.Allocator,
    io: std.Io,
    root: std.Io.Dir,
    pointer: ActiveGeneration,
) !std.json.Parsed(ContentManifestRecords) {
    const bytes = try root.readFileAlloc(io, pointer.content_manifest, allocator, .limited(max_manifest_bytes));
    defer allocator.free(bytes);
    var parsed = std.json.parseFromSlice(ContentManifestRecords, allocator, bytes, .{
        .allocate = .alloc_always,
        .ignore_unknown_fields = true,
    }) catch return error.CorruptGenerationManifest;
    errdefer parsed.deinit();
    if (!parsed.value.complete or !std.mem.eql(u8, parsed.value.schema, content_manifest_schema) or
        parsed.value.schema_version != schema_version or !std.mem.eql(u8, parsed.value.repository_id, pointer.repository_id) or
        !std.mem.eql(u8, parsed.value.discovery_manifest_digest, pointer.discovery_manifest_digest) or
        !std.mem.eql(u8, parsed.value.ownership_manifest_digest, pointer.ownership_manifest_digest))
    {
        return error.InvalidGenerationManifest;
    }
    return parsed;
}

fn graphBearingDisposition(disposition: discovery.Disposition) bool {
    return disposition == .deeply_indexed or disposition == .placed_unsupported or disposition == .placed_asset;
}

fn containsPath(paths: []const []const u8, expected: []const u8) bool {
    for (paths) |path| if (std.mem.eql(u8, path, expected)) return true;
    return false;
}

fn publishBuiltLocked(
    allocator: std.mem.Allocator,
    io: std.Io,
    root: std.Io.Dir,
    config: project.Config,
    built: *const indexer.BuildResult,
    trigger: RefreshTrigger,
    activate: bool,
    overlays: []const origin_ledger.Overlay,
    requested_repair: repair.Plan,
) !Publication {
    try discovery.validate(&built.discovery_result);
    try ownership.validate(&built.discovery_result, &built.ownership_result);
    try built.graph.validateSemanticRecords();
    try semantic_recipes.validateGraph(&built.graph);
    try built.graph.validateSecondaryIndexes();
    if (!freshness.inspect(&built.graph).clean()) return error.UnhealthyBuildGraph;

    var previous_active: ?std.json.Parsed(ActiveGeneration) = readActiveGeneration(allocator, io, root, config) catch null;
    defer if (previous_active) |*parsed| parsed.deinit();
    var previous_graph: ?model.RepositoryGraph = null;
    defer if (previous_graph) |*graph| graph.deinit();
    if (previous_active) |*parsed| {
        var loaded = loadGenerationGraph(allocator, io, root, config, parsed.value) catch null;
        if (loaded) |*value| previous_graph = value.graph;
    }

    var repair_plan = requested_repair;
    if (repair_plan.action == .none and previous_active != null and previous_graph == null) {
        repair_plan = .{
            .action = .clean_rebuild,
            .cause = .delta_unavailable,
            .replaces_generation = previous_active.?.value.generation,
        };
    } else if (repair_plan.action != .none and repair_plan.replaces_generation.len == 0 and previous_active != null) {
        repair_plan.replaces_generation = previous_active.?.value.generation;
    }

    var previous_manifest: ?std.json.Parsed(ContentManifestRecords) = null;
    defer if (previous_manifest) |*parsed| parsed.deinit();
    var previous_lineage: ?std.json.Parsed(change_lineage.Artifact) = null;
    defer if (previous_lineage) |*parsed| parsed.deinit();
    var previous_origin: ?origin_ledger.Owned = null;
    defer if (previous_origin) |*owned| owned.deinit();
    if (previous_graph != null and previous_active != null) {
        previous_manifest = try readContentManifestRecords(allocator, io, root, previous_active.?.value);
        previous_lineage = try change_lineage.read(allocator, io, root, previous_active.?.value.change_lineage);
        if (!std.mem.eql(u8, previous_lineage.?.value.repository_id, config.repository_id) or
            !std.mem.eql(u8, previous_lineage.?.value.target_generation, previous_active.?.value.generation) or
            !std.mem.eql(u8, previous_lineage.?.value.fingerprint, previous_active.?.value.change_lineage_fingerprint))
        {
            return error.ChangeLineageBindingMismatch;
        }
        previous_origin = origin_ledger.read(allocator, io, root, previous_active.?.value.origin_ledger) catch null;
        if (previous_origin) |*owned| {
            origin_ledger.validate(&previous_graph.?, owned.value) catch {
                owned.deinit();
                previous_origin = null;
            };
        }
        if (previous_origin == null and repair_plan.action == .none) {
            repair_plan = .{
                .action = .clean_rebuild,
                .cause = .origin_invalid,
                .replaces_generation = previous_active.?.value.generation,
            };
        }
    }

    const previous_generation = if (previous_graph != null and previous_active != null) previous_active.?.value.generation else "";
    var current_repository_context = try repository_context.inspect(allocator, io, root);
    defer current_repository_context.deinit();
    var lineage = try change_lineage.reconcile(
        allocator,
        config.repository_id,
        previous_generation,
        if (previous_lineage) |*parsed| parsed.value else null,
        if (previous_manifest) |*parsed| parsed.value.records else &.{},
        &built.discovery_result,
        config.max_files,
    );
    defer lineage.deinit();
    const discovery_hex = std.fmt.bytesToHex(built.discovery_result.manifest_digest, .lower);
    const ownership_hex = std.fmt.bytesToHex(built.ownership_result.manifest_digest, .lower);
    const extraction_hex = std.fmt.bytesToHex(built.extraction.manifest.digest, .lower);

    var origin = try origin_ledger.reconcile(allocator, .{
        .repository_id = config.repository_id,
        .native_graph = &built.graph,
        .current_sources = built.discovery_result.records,
        .previous_graph = if (previous_origin != null) &previous_graph.? else null,
        .previous = if (previous_origin) |*owned| owned.value else null,
        .overlays = overlays,
        .options = graphOptions(config),
    });
    defer origin.deinit();
    const canonical_graph = &origin.graph;
    const origin_source_dependencies = countOriginDependencies(origin.value);
    const graph_fingerprint = try freshness.fingerprint(allocator, canonical_graph);
    const graph_identity = sha256Identity(graph_fingerprint);
    const index_fingerprint = try canonical_graph.secondaryIndexFingerprint(allocator);
    const index_fingerprint_hex = std.fmt.bytesToHex(index_fingerprint, .lower);
    const index_stats = canonical_graph.secondaryIndexStats();
    const pruned = if (previous_graph) |*graph| prunedRecords(graph, canonical_graph) else PrunedRecords{};

    var repair_report = try repair.create(
        allocator,
        config.repository_id,
        if (previous_active) |*parsed| parsed.value.generation else "",
        repair_plan,
    );
    defer repair_report.deinit();

    if (previous_active) |*parsed| {
        const same_graph = std.mem.eql(u8, parsed.value.graph_fingerprint, &graph_identity) and
            std.mem.eql(u8, parsed.value.secondary_index_fingerprint, &index_fingerprint_hex) and
            std.meta.eql(parsed.value.secondary_indexes, index_stats) and
            std.mem.eql(u8, parsed.value.discovery_manifest_digest, &discovery_hex) and
            std.mem.eql(u8, parsed.value.ownership_manifest_digest, &ownership_hex) and
            std.mem.eql(u8, parsed.value.extraction_manifest_digest, &extraction_hex) and
            std.mem.eql(u8, parsed.value.repository_context_fingerprint, current_repository_context.value.fingerprint) and
            std.mem.eql(u8, parsed.value.change_lineage_input_fingerprint, lineage.value.input_fingerprint) and
            std.mem.eql(u8, parsed.value.origin_input_fingerprint, origin.value.input_fingerprint) and
            repair_plan.action == .none;
        const checkpoint_complete = complete: {
            activeCheckpointComplete(allocator, io, root, config, parsed.value) catch break :complete false;
            break :complete true;
        };
        if (same_graph and checkpoint_complete) {
            const retention_summary = automaticRetentionLocked(allocator, io, root, config, parsed.value);
            return publicationAlloc(allocator, .{
                .status = .current,
                .trigger = trigger,
                .activated = true,
                .generation = parsed.value.generation,
                .previous_generation = parsed.value.generation,
                .database = parsed.value.database,
                .delta_journal = parsed.value.delta_journal,
                .delta_fingerprint = parsed.value.delta_fingerprint,
                .delta_summary = parsed.value.delta_summary,
                .checked_files = built.discovery_result.summary.total,
                .reparsed_files = built.summary.reparsed_files,
                .cache_hits = built.summary.cache_hits,
                .cache_misses = built.summary.cache_misses,
                .cache_rejected = built.summary.cache_rejected,
                .cache_writes = built.summary.cache_writes,
                .direct_invalidations = built.summary.direct_invalidations,
                .invalidation_closure = built.summary.invalidation_closure,
                .pruned = .{},
                .origin = parsed.value.origin_summary,
                .repair = parsed.value.repair_summary,
                .retention = retention_summary,
            });
        }
    }

    const generation = generationIdentity(
        config.repository_id,
        "",
        previous_generation,
        repair_plan.replaces_generation,
        &discovery_hex,
        &ownership_hex,
        &extraction_hex,
        &graph_identity,
        current_repository_context.value.fingerprint,
        lineage.value.input_fingerprint,
        origin.value.input_fingerprint,
        repair_report.value.plan_fingerprint,
    );
    try lineage.bindTargetGeneration(&generation);
    try origin.bindTargetGeneration(&generation);
    try repair_report.bindTargetGeneration(&generation);
    var paths = try generationPathsAlloc(allocator, &generation);
    defer paths.deinit();

    try root.createDirPath(io, paths.directory);
    try store.save(io, root, paths.database, canonical_graph);
    try publishToPaths(allocator, io, root, config, built, canonical_graph, paths.content_manifest, paths.health_report, .healthy);
    const extraction_bytes = try extraction_cache.encodeManifestAlloc(allocator, &built.extraction.manifest);
    defer allocator.free(extraction_bytes);
    if (extraction_bytes.len > extraction_cache.max_manifest_bytes) return error.ExtractionManifestTooLarge;
    try atomicWrite(allocator, io, root, paths.extraction_manifest, extraction_bytes);
    const repository_context_bytes = try repository_context.encodeAlloc(allocator, current_repository_context.value);
    defer allocator.free(repository_context_bytes);
    try atomicWrite(allocator, io, root, paths.repository_context, repository_context_bytes);
    const lineage_bytes = try change_lineage.encodeAlloc(allocator, lineage.value);
    defer allocator.free(lineage_bytes);
    try atomicWrite(allocator, io, root, paths.change_lineage, lineage_bytes);
    const origin_bytes = try origin_ledger.encodeAlloc(allocator, origin.value);
    defer allocator.free(origin_bytes);
    try atomicWrite(allocator, io, root, paths.origin_ledger, origin_bytes);
    const repair_bytes = try repair.encodeAlloc(allocator, repair_report.value);
    defer allocator.free(repair_bytes);
    try atomicWrite(allocator, io, root, paths.repair_report, repair_bytes);
    const database_artifact_fingerprint = try artifactFingerprint(io, root, paths.database);
    const origin_artifact_fingerprint = try artifactFingerprint(io, root, paths.origin_ledger);
    const database_artifact_stamp = try artifactStamp(io, root, paths.database);
    const origin_artifact_stamp = try artifactStamp(io, root, paths.origin_ledger);
    var source_changes = try deriveSourceChanges(allocator, io, root, if (previous_graph != null) previous_active else null, built, lineage.value);
    defer source_changes.deinit();
    const delta_result = try delta_journal.write(allocator, io, root, paths.delta_journal, .{
        .repository_id = config.repository_id,
        .parent_generation = previous_generation,
        .target_generation = &generation,
        .previous = if (previous_graph) |*graph| graph else null,
        .target = canonical_graph,
        .source_changes = source_changes.items,
    });

    var canonical_summary = built.summary;
    canonical_summary.nodes = canonical_graph.nodeCount();
    canonical_summary.edges = canonical_graph.edgeCount();
    canonical_summary.vectors = canonical_graph.vectorCount();
    const metadata = GenerationMetadata{
        .schema = generation_schema,
        .schema_version = generation_schema_version,
        .repository_id = config.repository_id,
        .generation = &generation,
        .semantic_generation = &generation,
        .semantic_noop_depth = 0,
        .parent_generation = previous_generation,
        .replaces_generation = repair_plan.replaces_generation,
        .recipe = freshness_recipe,
        .snapshot_schema = store.current_schema,
        .embedder = nendb.embedder,
        .database_artifact_fingerprint = &database_artifact_fingerprint,
        .origin_artifact_fingerprint = &origin_artifact_fingerprint,
        .database_artifact_stamp = database_artifact_stamp,
        .origin_artifact_stamp = origin_artifact_stamp,
        .discovery_manifest_digest = &discovery_hex,
        .ownership_manifest_digest = &ownership_hex,
        .extraction_manifest_digest = &extraction_hex,
        .repository_context_schema = repository_context.schema,
        .repository_context_fingerprint = current_repository_context.value.fingerprint,
        .change_lineage_schema = change_lineage.schema,
        .change_lineage_input_fingerprint = lineage.value.input_fingerprint,
        .change_lineage_fingerprint = lineage.value.fingerprint,
        .change_lineage_summary = lineage.value.summary,
        .origin_schema = origin_ledger.schema,
        .origin_input_fingerprint = origin.value.input_fingerprint,
        .origin_fingerprint = origin.value.fingerprint,
        .origin_summary = origin.value.summary,
        .origin_source_dependencies = origin_source_dependencies,
        .repair_schema = repair.schema,
        .repair_plan_fingerprint = repair_report.value.plan_fingerprint,
        .repair_fingerprint = repair_report.value.fingerprint,
        .repair_summary = repair_report.value.summary,
        .graph_fingerprint = &graph_identity,
        .delta_schema = delta_journal.schema,
        .delta_fingerprint = &delta_result.journal_fingerprint,
        .delta_summary = delta_result.summary,
        .secondary_index_schema = nendb.secondary_index_schema,
        .secondary_index_fingerprint = &index_fingerprint_hex,
        .secondary_indexes = index_stats,
        .build_summary = canonical_summary,
        .nodes = canonical_graph.nodeCount(),
        .edges = canonical_graph.edgeCount(),
        .vectors = canonical_graph.vectorCount(),
        .hyperedges = canonical_graph.hyperedgeCount(),
        .supernodes = canonical_graph.supernodeCount(),
        .pruned = pruned,
        .complete = true,
    };
    const metadata_bytes = try std.json.Stringify.valueAlloc(allocator, metadata, .{});
    defer allocator.free(metadata_bytes);
    if (metadata_bytes.len > max_generation_metadata_bytes) return error.GenerationMetadataTooLarge;
    try atomicWrite(allocator, io, root, paths.metadata, metadata_bytes);

    const pointer = ActiveGeneration{
        .schema = active_generation_schema,
        .schema_version = generation_schema_version,
        .repository_id = config.repository_id,
        .generation = &generation,
        .semantic_generation = &generation,
        .semantic_noop_depth = 0,
        .parent_generation = previous_generation,
        .replaces_generation = repair_plan.replaces_generation,
        .database = paths.database,
        .content_manifest = paths.content_manifest,
        .extraction_manifest = paths.extraction_manifest,
        .delta_journal = paths.delta_journal,
        .repository_context = paths.repository_context,
        .change_lineage = paths.change_lineage,
        .origin_ledger = paths.origin_ledger,
        .repair_report = paths.repair_report,
        .health_report = paths.health_report,
        .metadata = paths.metadata,
        .database_artifact_fingerprint = &database_artifact_fingerprint,
        .origin_artifact_fingerprint = &origin_artifact_fingerprint,
        .database_artifact_stamp = database_artifact_stamp,
        .origin_artifact_stamp = origin_artifact_stamp,
        .discovery_manifest_digest = &discovery_hex,
        .ownership_manifest_digest = &ownership_hex,
        .extraction_manifest_digest = &extraction_hex,
        .repository_context_fingerprint = current_repository_context.value.fingerprint,
        .change_lineage_input_fingerprint = lineage.value.input_fingerprint,
        .change_lineage_fingerprint = lineage.value.fingerprint,
        .change_lineage_summary = lineage.value.summary,
        .origin_input_fingerprint = origin.value.input_fingerprint,
        .origin_fingerprint = origin.value.fingerprint,
        .origin_summary = origin.value.summary,
        .origin_source_dependencies = origin_source_dependencies,
        .repair_plan_fingerprint = repair_report.value.plan_fingerprint,
        .repair_fingerprint = repair_report.value.fingerprint,
        .repair_summary = repair_report.value.summary,
        .graph_fingerprint = &graph_identity,
        .delta_schema = delta_journal.schema,
        .delta_fingerprint = &delta_result.journal_fingerprint,
        .delta_summary = delta_result.summary,
        .secondary_index_schema = nendb.secondary_index_schema,
        .secondary_index_fingerprint = &index_fingerprint_hex,
        .secondary_indexes = index_stats,
        .complete = true,
    };
    try validateCandidate(allocator, io, root, config, pointer, pruned, if (previous_graph) |*graph| graph else null);

    if (activate) {
        try store.save(io, root, config.database, canonical_graph);
        try publishToPaths(allocator, io, root, config, built, canonical_graph, config.content_manifest, config.health_report, .healthy);
        const pointer_bytes = try std.json.Stringify.valueAlloc(allocator, pointer, .{});
        defer allocator.free(pointer_bytes);
        if (pointer_bytes.len > max_active_generation_bytes) return error.ActiveGenerationTooLarge;
        try atomicWrite(allocator, io, root, active_generation_path, pointer_bytes);
    }

    const retention_summary = if (activate)
        automaticRetentionLocked(allocator, io, root, config, pointer)
    else
        retention.Summary{ .status = .disabled };

    return publicationAlloc(allocator, .{
        .status = if (activate) .refreshed else .staged,
        .trigger = trigger,
        .activated = activate,
        .generation = &generation,
        .previous_generation = previous_generation,
        .database = paths.database,
        .delta_journal = paths.delta_journal,
        .delta_fingerprint = &delta_result.journal_fingerprint,
        .delta_summary = delta_result.summary,
        .checked_files = built.discovery_result.summary.total,
        .reparsed_files = built.summary.reparsed_files,
        .cache_hits = built.summary.cache_hits,
        .cache_misses = built.summary.cache_misses,
        .cache_rejected = built.summary.cache_rejected,
        .cache_writes = built.summary.cache_writes,
        .direct_invalidations = built.summary.direct_invalidations,
        .invalidation_closure = built.summary.invalidation_closure,
        .pruned = pruned,
        .origin = origin.value.summary,
        .repair = repair_report.value.summary,
        .retention = retention_summary,
    });
}

fn validateCandidate(
    allocator: std.mem.Allocator,
    io: std.Io,
    root: std.Io.Dir,
    config: project.Config,
    pointer: ActiveGeneration,
    expected_pruned: PrunedRecords,
    previous_graph: ?*const model.RepositoryGraph,
) !void {
    try validateActiveGeneration(allocator, config, pointer);
    var loaded = try store.load(allocator, io, root, pointer.database, graphOptions(config));
    defer loaded.deinit();
    if (!freshness.inspect(&loaded).clean()) return error.UnhealthyCandidateGeneration;
    const fingerprint = try freshness.fingerprint(allocator, &loaded);
    const identity = sha256Identity(fingerprint);
    if (!std.mem.eql(u8, &identity, pointer.graph_fingerprint)) return error.CandidateFingerprintMismatch;
    try loaded.validateSecondaryIndexes();
    const candidate_index = try loaded.secondaryIndexFingerprintValidated(allocator);
    const candidate_index_hex = std.fmt.bytesToHex(candidate_index, .lower);
    if (!std.mem.eql(u8, pointer.secondary_index_fingerprint, &candidate_index_hex) or
        !std.meta.eql(pointer.secondary_indexes, loaded.secondaryIndexStats())) return error.CandidateSecondaryIndexMismatch;

    var delta_info = try delta_journal.inspect(allocator, io, root, pointer.delta_journal);
    defer delta_info.deinit();
    try validateDeltaBindings(pointer, delta_info);
    var replayed = try delta_journal.replay(allocator, io, root, pointer.delta_journal, previous_graph, graphOptions(config));
    defer replayed.deinit();
    const replayed_fingerprint = try freshness.fingerprint(allocator, &replayed);
    const replayed_identity = sha256Identity(replayed_fingerprint);
    const replayed_index = try replayed.secondaryIndexFingerprint(allocator);
    const replayed_index_hex = std.fmt.bytesToHex(replayed_index, .lower);
    if (!std.mem.eql(u8, &replayed_identity, pointer.graph_fingerprint) or
        !std.mem.eql(u8, &replayed_index_hex, pointer.secondary_index_fingerprint)) return error.CandidateDeltaReplayMismatch;

    try validateGenerationMetadata(allocator, io, root, config, pointer, &loaded, expected_pruned, .{}, null);
    try validatePublishedHeaders(allocator, io, root, config, pointer);
    try validateExtractionManifest(allocator, io, root, pointer);
    try validateRepositoryContextAndLineage(allocator, io, root, pointer, &loaded);
    try validateOriginAndRepair(allocator, io, root, pointer, &loaded, false);
}

fn loadGenerationGraph(
    allocator: std.mem.Allocator,
    io: std.Io,
    root: std.Io.Dir,
    config: project.Config,
    pointer: ActiveGeneration,
) !LoadedGeneration {
    var snapshot_failure: ?anyerror = null;
    // Skips the parse, not the read: the snapshot is still loaded and
    // checksummed, so a damaged one still reaches recovery with its real
    // provenance. Everything downstream runs unchanged on whichever graph
    // comes back.
    const expected = parseSha256Identity(pointer.graph_fingerprint);
    const snapshot: ?model.RepositoryGraph = (if (expected) |digest|
        store.loadPreferringIndex(allocator, io, root, pointer.database, digest, graphOptions(config))
    else
        store.load(allocator, io, root, pointer.database, graphOptions(config))) catch |failure| blk: {
        snapshot_failure = failure;
        break :blk null;
    };
    if (snapshot) |graph| return .{ .graph = graph, .recovery_source = .full_snapshot };

    const metadata_bytes = try root.readFileAlloc(io, pointer.metadata, allocator, .limited(max_generation_metadata_bytes));
    defer allocator.free(metadata_bytes);
    var parsed = std.json.parseFromSlice(GenerationMetadata, allocator, metadata_bytes, .{ .allocate = .alloc_always }) catch return error.CorruptGenerationMetadata;
    defer parsed.deinit();
    if (!parsed.value.complete or !std.mem.eql(u8, parsed.value.schema, generation_schema) or
        parsed.value.schema_version != generation_schema_version or parsed.value.parent_generation.len == 0 or
        !std.mem.eql(u8, parsed.value.parent_generation, pointer.parent_generation) or
        !validGenerationId(parsed.value.parent_generation) or !std.mem.eql(u8, parsed.value.generation, pointer.generation))
    {
        return error.InvalidGenerationMetadata;
    }
    var parent_paths = try generationPathsAlloc(allocator, parsed.value.parent_generation);
    defer parent_paths.deinit();
    var parent = try store.load(allocator, io, root, parent_paths.database, graphOptions(config));
    defer parent.deinit();
    var replayed = try delta_journal.replay(allocator, io, root, pointer.delta_journal, &parent, graphOptions(config));
    errdefer replayed.deinit();
    if (!freshness.inspect(&replayed).clean()) return error.UnhealthyRecoveredGeneration;
    const graph_identity = sha256Identity(try freshness.fingerprint(allocator, &replayed));
    const index_digest = try replayed.secondaryIndexFingerprint(allocator);
    const index_hex = std.fmt.bytesToHex(index_digest, .lower);
    if (!std.mem.eql(u8, &graph_identity, pointer.graph_fingerprint) or
        !std.mem.eql(u8, &index_hex, pointer.secondary_index_fingerprint) or
        !std.meta.eql(replayed.secondaryIndexStats(), pointer.secondary_indexes)) return error.RecoveredGenerationMismatch;
    const action: repair.Action = switch (snapshot_failure.?) {
        error.SecondaryIndexFingerprintMismatch, error.SecondaryIndexMetadataMismatch => .rebuild_secondary_indexes,
        else => .rebuild_checkpoint,
    };
    const cause: repair.Cause = switch (action) {
        .rebuild_secondary_indexes => .secondary_index_mismatch,
        else => .snapshot_unavailable,
    };
    return .{
        .graph = replayed,
        .recovery_source = .parent_delta_replay,
        .repair_action = action,
        .repair_cause = cause,
    };
}

fn activeGenerationHealthy(
    allocator: std.mem.Allocator,
    io: std.Io,
    root: std.Io.Dir,
    config: project.Config,
    pointer: ActiveGeneration,
) !repair.Plan {
    var loaded = try loadGenerationGraph(allocator, io, root, config, pointer);
    defer loaded.graph.deinit();
    return validateLoadedGeneration(allocator, io, root, config, pointer, &loaded);
}

/// Every check `activeGenerationHealthy` performs, against a generation the
/// caller has already loaded.
///
/// Split out because the read path loaded the graph, then called
/// `activeGenerationHealthy`, which loaded it a second time to validate it, and
/// then threw that copy away. On an 8,102-node graph that is the difference
/// between materialising the database once per query and twice.
fn validateLoadedGeneration(
    allocator: std.mem.Allocator,
    io: std.Io,
    root: std.Io.Dir,
    config: project.Config,
    pointer: ActiveGeneration,
    loaded: *LoadedGeneration,
) !repair.Plan {
    if (!freshness.inspect(&loaded.graph).clean()) return error.UnhealthyActiveGeneration;
    const fingerprint = try freshness.fingerprint(allocator, &loaded.graph);
    const identity = sha256Identity(fingerprint);
    if (!std.mem.eql(u8, &identity, pointer.graph_fingerprint)) return error.ActiveGenerationFingerprintMismatch;
    try loaded.graph.validateSecondaryIndexes();
    const active_index = try loaded.graph.secondaryIndexFingerprintValidated(allocator);
    const active_index_hex = std.fmt.bytesToHex(active_index, .lower);
    if (!std.mem.eql(u8, pointer.secondary_index_fingerprint, &active_index_hex) or
        !std.meta.eql(pointer.secondary_indexes, loaded.graph.secondaryIndexStats())) return error.ActiveGenerationSecondaryIndexMismatch;
    try validateGenerationMetadata(allocator, io, root, config, pointer, &loaded.graph, null, .{
        .database = loaded.recovery_source == .full_snapshot,
    }, active_index);
    try validatePublishedHeaders(allocator, io, root, config, pointer);
    try validateExtractionManifest(allocator, io, root, pointer);
    try validateRepositoryContextAndLineage(allocator, io, root, pointer, &loaded.graph);
    try validateOriginAndRepair(allocator, io, root, pointer, &loaded.graph, true);
    if (loaded.recovery_source == .full_snapshot) {
        if (delta_journal.inspect(allocator, io, root, pointer.delta_journal)) |inspection_value| {
            var inspection = inspection_value;
            defer inspection.deinit();
            validateDeltaBindings(pointer, inspection) catch {};
        } else |_| {}
    }
    return .{
        .action = loaded.repair_action,
        .cause = loaded.repair_cause,
        .replaces_generation = if (loaded.repair_action == .none) "" else pointer.generation,
    };
}

fn activeCheckpointComplete(
    allocator: std.mem.Allocator,
    io: std.Io,
    root: std.Io.Dir,
    config: project.Config,
    pointer: ActiveGeneration,
) !void {
    var graph = try store.load(allocator, io, root, pointer.database, graphOptions(config));
    defer graph.deinit();
    if (!freshness.inspect(&graph).clean()) return error.UnhealthyActiveGeneration;
    const graph_identity = sha256Identity(try freshness.fingerprint(allocator, &graph));
    const index_digest = try graph.secondaryIndexFingerprint(allocator);
    const index_hex = std.fmt.bytesToHex(index_digest, .lower);
    if (!std.mem.eql(u8, &graph_identity, pointer.graph_fingerprint) or
        !std.mem.eql(u8, &index_hex, pointer.secondary_index_fingerprint) or
        !std.meta.eql(graph.secondaryIndexStats(), pointer.secondary_indexes)) return error.ActiveGenerationFingerprintMismatch;
    var journal = try delta_journal.inspect(allocator, io, root, pointer.delta_journal);
    defer journal.deinit();
    try validateDeltaBindings(pointer, journal);
    try validateGenerationMetadata(allocator, io, root, config, pointer, &graph, null, .{}, null);
    try validatePublishedHeaders(allocator, io, root, config, pointer);
    try validateExtractionManifest(allocator, io, root, pointer);
    try validateRepositoryContextAndLineage(allocator, io, root, pointer, &graph);
    try validateOriginAndRepair(allocator, io, root, pointer, &graph, false);
}

fn validateDeltaBindings(pointer: ActiveGeneration, info: delta_journal.Inspection) !void {
    var index_identity: [71]u8 = @splat(0);
    index_identity[0..7].* = "sha256:".*;
    if (pointer.secondary_index_fingerprint.len != 64) return error.InvalidGenerationDelta;
    @memcpy(index_identity[7..], pointer.secondary_index_fingerprint);
    if (!std.mem.eql(u8, info.repository_id, pointer.repository_id) or
        !std.mem.eql(u8, info.target_generation, pointer.generation) or !std.mem.eql(u8, info.parent_generation, pointer.parent_generation) or
        !std.mem.eql(u8, info.target_graph_fingerprint, pointer.graph_fingerprint) or
        !std.mem.eql(u8, info.target_index_fingerprint, &index_identity) or
        !std.mem.eql(u8, info.journal_fingerprint, pointer.delta_fingerprint) or
        !std.meta.eql(info.summary, pointer.delta_summary)) return error.InvalidGenerationDelta;
}

fn validateGenerationMetadata(
    allocator: std.mem.Allocator,
    io: std.Io,
    root: std.Io.Dir,
    config: project.Config,
    pointer: ActiveGeneration,
    graph: *const model.RepositoryGraph,
    expected_pruned: ?PrunedRecords,
    seals: ArtifactSealValidation,
    /// The secondary-index fingerprint, when the caller already computed it over
    /// this exact graph.
    ///
    /// `secondaryIndexFingerprint` validates the indexes before computing, so
    /// asking for it here re-runs `validateSecondaryIndexes` (34 ms) and the
    /// digest (20 ms) that the caller produced moments earlier on the same graph
    /// object. Null keeps the original behaviour, so a caller that has not
    /// computed it is unaffected.
    known_index_fingerprint: ?[32]u8,
) !void {
    const metadata_bytes = try root.readFileAlloc(io, pointer.metadata, allocator, .limited(max_generation_metadata_bytes));
    defer allocator.free(metadata_bytes);
    var metadata = std.json.parseFromSlice(GenerationMetadata, allocator, metadata_bytes, .{ .allocate = .alloc_always }) catch return error.CorruptGenerationMetadata;
    defer metadata.deinit();
    const value = metadata.value;
    const identity = generationIdentity(
        config.repository_id,
        if (std.mem.eql(u8, value.semantic_generation, value.generation)) "" else value.semantic_generation,
        value.parent_generation,
        value.replaces_generation,
        pointer.discovery_manifest_digest,
        pointer.ownership_manifest_digest,
        pointer.extraction_manifest_digest,
        pointer.graph_fingerprint,
        pointer.repository_context_fingerprint,
        pointer.change_lineage_input_fingerprint,
        pointer.origin_input_fingerprint,
        pointer.repair_plan_fingerprint,
    );
    const index_fingerprint = known_index_fingerprint orelse try graph.secondaryIndexFingerprint(allocator);
    const index_fingerprint_hex = std.fmt.bytesToHex(index_fingerprint, .lower);
    const index_stats = graph.secondaryIndexStats();
    if (!value.complete or !std.mem.eql(u8, value.schema, generation_schema) or value.schema_version != generation_schema_version or
        !std.mem.eql(u8, value.repository_id, config.repository_id) or !std.mem.eql(u8, value.generation, pointer.generation) or
        !std.mem.eql(u8, value.semantic_generation, pointer.semantic_generation) or
        value.semantic_noop_depth != pointer.semantic_noop_depth or
        !std.mem.eql(u8, value.parent_generation, pointer.parent_generation) or
        !std.mem.eql(u8, value.replaces_generation, pointer.replaces_generation) or
        !std.mem.eql(u8, &identity, pointer.generation) or
        !validGenerationId(value.semantic_generation) or (value.parent_generation.len != 0 and !validGenerationId(value.parent_generation)) or
        !std.mem.eql(u8, value.recipe, freshness_recipe) or !std.mem.eql(u8, value.snapshot_schema, store.current_schema) or
        !std.mem.eql(u8, value.embedder, nendb.embedder) or !std.mem.eql(u8, value.secondary_index_schema, nendb.secondary_index_schema) or
        !std.mem.eql(u8, value.database_artifact_fingerprint, pointer.database_artifact_fingerprint) or
        !std.mem.eql(u8, value.origin_artifact_fingerprint, pointer.origin_artifact_fingerprint) or
        !std.meta.eql(value.database_artifact_stamp, pointer.database_artifact_stamp) or
        !std.meta.eql(value.origin_artifact_stamp, pointer.origin_artifact_stamp) or
        !std.mem.eql(u8, value.secondary_index_fingerprint, &index_fingerprint_hex) or !std.meta.eql(value.secondary_indexes, index_stats) or
        !std.mem.eql(u8, value.discovery_manifest_digest, pointer.discovery_manifest_digest) or
        !std.mem.eql(u8, value.ownership_manifest_digest, pointer.ownership_manifest_digest) or
        !std.mem.eql(u8, value.extraction_manifest_digest, pointer.extraction_manifest_digest) or
        !std.mem.eql(u8, value.repository_context_schema, repository_context.schema) or
        !std.mem.eql(u8, value.repository_context_fingerprint, pointer.repository_context_fingerprint) or
        !std.mem.eql(u8, value.change_lineage_schema, change_lineage.schema) or
        !std.mem.eql(u8, value.change_lineage_input_fingerprint, pointer.change_lineage_input_fingerprint) or
        !std.mem.eql(u8, value.change_lineage_fingerprint, pointer.change_lineage_fingerprint) or
        !std.meta.eql(value.change_lineage_summary, pointer.change_lineage_summary) or
        !std.mem.eql(u8, value.origin_schema, origin_ledger.schema) or
        !std.mem.eql(u8, value.origin_input_fingerprint, pointer.origin_input_fingerprint) or
        !std.mem.eql(u8, value.origin_fingerprint, pointer.origin_fingerprint) or
        !std.meta.eql(value.origin_summary, pointer.origin_summary) or value.origin_source_dependencies != pointer.origin_source_dependencies or
        !std.mem.eql(u8, value.repair_schema, repair.schema) or
        !std.mem.eql(u8, value.repair_plan_fingerprint, pointer.repair_plan_fingerprint) or
        !std.mem.eql(u8, value.repair_fingerprint, pointer.repair_fingerprint) or
        !std.meta.eql(value.repair_summary, pointer.repair_summary) or
        !std.mem.eql(u8, value.graph_fingerprint, pointer.graph_fingerprint) or
        !std.mem.eql(u8, value.delta_schema, pointer.delta_schema) or !std.mem.eql(u8, value.delta_fingerprint, pointer.delta_fingerprint) or
        !std.meta.eql(value.delta_summary, pointer.delta_summary) or value.build_summary.nodes != value.nodes or
        value.build_summary.edges != value.edges or value.build_summary.vectors != value.vectors or
        value.nodes != graph.nodeCount() or
        value.edges != graph.edgeCount() or value.vectors != graph.vectorCount() or value.hyperedges != graph.hyperedgeCount() or
        value.supernodes != graph.supernodeCount() or (expected_pruned != null and !std.meta.eql(value.pruned, expected_pruned.?)))
    {
        return error.InvalidGenerationMetadata;
    }
    if (seals.database) {
        const database_artifact_stamp = try artifactStamp(io, root, pointer.database);
        if (!std.meta.eql(database_artifact_stamp, pointer.database_artifact_stamp)) return error.GenerationArtifactFingerprintMismatch;
    }
    if (seals.origin) {
        const origin_artifact_stamp = try artifactStamp(io, root, pointer.origin_ledger);
        if (!std.meta.eql(origin_artifact_stamp, pointer.origin_artifact_stamp)) return error.GenerationArtifactFingerprintMismatch;
    }
}

fn validateExtractionManifest(
    allocator: std.mem.Allocator,
    io: std.Io,
    root: std.Io.Dir,
    pointer: ActiveGeneration,
) !void {
    var manifest = try extraction_cache.readManifest(allocator, io, root, pointer.extraction_manifest);
    defer manifest.deinit();
    const digest = std.fmt.bytesToHex(manifest.digest, .lower);
    if (!std.mem.eql(u8, &digest, pointer.extraction_manifest_digest)) return error.ExtractionManifestDigestMismatch;
}

fn validateRepositoryContextAndLineage(
    allocator: std.mem.Allocator,
    io: std.Io,
    root: std.Io.Dir,
    pointer: ActiveGeneration,
    graph: *const model.RepositoryGraph,
) !void {
    var context = try repository_context.read(allocator, io, root, pointer.repository_context);
    defer context.deinit();
    if (!std.mem.eql(u8, context.value.fingerprint, pointer.repository_context_fingerprint)) {
        return error.RepositoryContextBindingMismatch;
    }
    var lineage = try change_lineage.read(allocator, io, root, pointer.change_lineage);
    defer lineage.deinit();
    if (!std.mem.eql(u8, lineage.value.repository_id, pointer.repository_id) or
        !std.mem.eql(u8, lineage.value.parent_generation, pointer.parent_generation) or
        !std.mem.eql(u8, lineage.value.target_generation, pointer.generation) or
        !std.mem.eql(u8, lineage.value.input_fingerprint, pointer.change_lineage_input_fingerprint) or
        !std.mem.eql(u8, lineage.value.fingerprint, pointer.change_lineage_fingerprint) or
        !std.meta.eql(lineage.value.summary, pointer.change_lineage_summary))
    {
        return error.ChangeLineageBindingMismatch;
    }
    var manifest = try readContentManifestRecords(allocator, io, root, pointer);
    defer manifest.deinit();
    for (lineage.value.records) |record| {
        if (!std.mem.eql(u8, record.successor_generation, pointer.generation)) continue;
        if (manifest.value.records.len > 0) {
            const successor = findContentRecord(manifest.value.records, record.successor_path) orelse return error.ChangeLineageSuccessorMissing;
            if (!graphBearingDisposition(successor.disposition) or graph.findNode(record.successor_node_id) == null) {
                return error.ChangeLineageSuccessorMissing;
            }
            if (findContentRecord(manifest.value.records, record.predecessor_path) == null and graph.findNode(record.predecessor_node_id) != null) {
                return error.ChangeLineagePredecessorStillLive;
            }
        }
    }
}

fn validateOriginAndRepair(
    allocator: std.mem.Allocator,
    io: std.Io,
    root: std.Io.Dir,
    pointer: ActiveGeneration,
    graph: *const model.RepositoryGraph,
    graph_already_validated: bool,
) !void {
    var origin = try origin_ledger.read(allocator, io, root, pointer.origin_ledger);
    defer origin.deinit();
    // `graph_already_validated` is only true because `validateLoadedGeneration`
    // ran exactly these checks on this graph object a few statements earlier.
    // Any other caller of validateOriginAndRepair must keep it false.
    try origin_ledger.validateWithOptions(graph, origin.value, .{ .graph_already_validated = graph_already_validated });
    if (!std.mem.eql(u8, origin.value.repository_id, pointer.repository_id) or
        !std.mem.eql(u8, origin.value.target_generation, pointer.semantic_generation) or
        !std.mem.eql(u8, origin.value.input_fingerprint, pointer.origin_input_fingerprint) or
        !std.mem.eql(u8, origin.value.fingerprint, pointer.origin_fingerprint) or
        !std.meta.eql(origin.value.summary, pointer.origin_summary))
    {
        return error.OriginLedgerBindingMismatch;
    }

    var repair_report = try repair.read(allocator, io, root, pointer.repair_report);
    defer repair_report.deinit();
    try repair.validate(allocator, repair_report.value, pointer.generation, pointer.replaces_generation);
    if (!std.mem.eql(u8, repair_report.value.repository_id, pointer.repository_id) or
        !std.mem.eql(u8, repair_report.value.plan_fingerprint, pointer.repair_plan_fingerprint) or
        !std.mem.eql(u8, repair_report.value.fingerprint, pointer.repair_fingerprint) or
        !std.meta.eql(repair_report.value.summary, pointer.repair_summary))
    {
        return error.RepairReportBindingMismatch;
    }
}

fn findContentRecord(records: []const discovery.Record, path: []const u8) ?*const discovery.Record {
    for (records) |*record| if (std.mem.eql(u8, record.relative_path, path)) return record;
    return null;
}

fn validatePublishedHeaders(
    allocator: std.mem.Allocator,
    io: std.Io,
    root: std.Io.Dir,
    config: project.Config,
    pointer: ActiveGeneration,
) !void {
    const manifest_bytes = try root.readFileAlloc(io, pointer.content_manifest, allocator, .limited(max_manifest_bytes));
    defer allocator.free(manifest_bytes);
    var manifest = std.json.parseFromSlice(ContentManifestHeader, allocator, manifest_bytes, .{ .ignore_unknown_fields = true }) catch return error.CorruptGenerationManifest;
    defer manifest.deinit();
    if (!manifest.value.complete or !std.mem.eql(u8, manifest.value.schema, content_manifest_schema) or
        manifest.value.schema_version != schema_version or !std.mem.eql(u8, manifest.value.repository_id, config.repository_id) or
        !std.mem.eql(u8, manifest.value.discovery_manifest_digest, pointer.discovery_manifest_digest) or
        !std.mem.eql(u8, manifest.value.ownership_manifest_digest, pointer.ownership_manifest_digest))
    {
        return error.InvalidGenerationManifest;
    }
    try validateHealthHeader(allocator, io, root, pointer);
}

fn validateHealthHeader(
    allocator: std.mem.Allocator,
    io: std.Io,
    root: std.Io.Dir,
    pointer: ActiveGeneration,
) !void {
    const health_bytes = try root.readFileAlloc(io, pointer.health_report, allocator, .limited(max_health_bytes));
    defer allocator.free(health_bytes);
    var health = std.json.parseFromSlice(HealthHeader, allocator, health_bytes, .{ .ignore_unknown_fields = true }) catch return error.CorruptGenerationHealth;
    defer health.deinit();
    if (!health.value.complete or !std.mem.eql(u8, health.value.schema, health_schema) or
        health.value.schema_version != schema_version or health.value.status != .healthy)
    {
        return error.InvalidGenerationHealth;
    }
}

fn validateActiveGeneration(allocator: std.mem.Allocator, config: project.Config, active: ActiveGeneration) !void {
    if (!active.complete or !std.mem.eql(u8, active.schema, active_generation_schema) or active.schema_version != generation_schema_version or
        !std.mem.eql(u8, active.repository_id, config.repository_id) or !validGenerationId(active.generation) or
        !validGenerationId(active.semantic_generation) or active.semantic_noop_depth > 1_000_000_000 or
        (active.parent_generation.len != 0 and !validGenerationId(active.parent_generation)) or
        (active.replaces_generation.len != 0 and !validGenerationId(active.replaces_generation)) or
        !validHexDigest(active.discovery_manifest_digest) or !validHexDigest(active.ownership_manifest_digest) or
        !validHexDigest(active.extraction_manifest_digest) or !validArtifactStamp(active.database_artifact_stamp) or
        !validArtifactStamp(active.origin_artifact_stamp) or
        !validSha256Identity(active.database_artifact_fingerprint) or !validSha256Identity(active.origin_artifact_fingerprint) or
        !validSha256Identity(active.repository_context_fingerprint) or
        !validSha256Identity(active.change_lineage_input_fingerprint) or
        !validSha256Identity(active.change_lineage_fingerprint) or
        !validSha256Identity(active.origin_input_fingerprint) or !validSha256Identity(active.origin_fingerprint) or
        !validSha256Identity(active.repair_plan_fingerprint) or !validSha256Identity(active.repair_fingerprint) or
        !active.repair_summary.clean() or
        !validSha256Identity(active.graph_fingerprint) or !std.mem.eql(u8, active.delta_schema, delta_journal.schema) or
        !validSha256Identity(active.delta_fingerprint) or !validDeltaSummary(active.delta_summary) or
        !std.mem.eql(u8, active.secondary_index_schema, nendb.secondary_index_schema) or
        !validHexDigest(active.secondary_index_fingerprint))
    {
        return error.IncompatibleActiveGeneration;
    }
    var paths = try generationPathsAlloc(allocator, active.generation);
    defer paths.deinit();
    var semantic_paths = try generationPathsAlloc(allocator, active.semantic_generation);
    defer semantic_paths.deinit();
    if (!std.mem.eql(u8, active.database, semantic_paths.database) or !std.mem.eql(u8, active.content_manifest, paths.content_manifest) or
        !std.mem.eql(u8, active.extraction_manifest, paths.extraction_manifest) or
        !std.mem.eql(u8, active.delta_journal, paths.delta_journal) or
        !std.mem.eql(u8, active.repository_context, paths.repository_context) or
        !std.mem.eql(u8, active.change_lineage, paths.change_lineage) or
        !std.mem.eql(u8, active.origin_ledger, semantic_paths.origin_ledger) or
        !std.mem.eql(u8, active.repair_report, paths.repair_report) or
        !std.mem.eql(u8, active.health_report, paths.health_report) or !std.mem.eql(u8, active.metadata, paths.metadata))
    {
        return error.IncompatibleActiveGeneration;
    }
}

fn validDeltaSummary(summary: delta_journal.Summary) bool {
    const node_edge_tombstones = std.math.add(usize, summary.node_tombstones, summary.edge_tombstones) catch return false;
    const semantic_tombstones = std.math.add(usize, summary.hyperedge_tombstones, summary.supernode_tombstones) catch return false;
    const tombstones = std.math.add(usize, node_edge_tombstones, semantic_tombstones) catch return false;
    const node_edge_upserts = std.math.add(usize, summary.node_upserts, summary.edge_upserts) catch return false;
    const semantic_upserts = std.math.add(usize, summary.hyperedge_upserts, summary.supernode_upserts) catch return false;
    const upserts = std.math.add(usize, node_edge_upserts, semantic_upserts) catch return false;
    const operations = std.math.add(usize, tombstones, upserts) catch return false;
    const rename_causes = std.math.add(usize, summary.causes.renamed, summary.causes.moved) catch return false;
    const replacement_causes = std.math.add(usize, summary.causes.replaced, rename_causes) catch return false;
    const causes_a = std.math.add(usize, replacement_causes, summary.causes.deleted) catch return false;
    const causes_b = std.math.add(usize, summary.causes.excluded, summary.causes.dependency_invalidated) catch return false;
    const causes_ab = std.math.add(usize, causes_a, causes_b) catch return false;
    const causes = std.math.add(usize, causes_ab, summary.causes.reconciled_absent) catch return false;
    return tombstones == summary.tombstones and upserts == summary.upserts and operations == summary.operations and
        operations <= delta_journal.max_operations and causes == tombstones and summary.target_vectors == summary.target_nodes;
}

fn generationPathsAlloc(allocator: std.mem.Allocator, generation: []const u8) !GenerationPaths {
    if (!validGenerationId(generation)) return error.InvalidGenerationId;
    const directory = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ generation_root, generation });
    errdefer allocator.free(directory);
    const database = try std.fmt.allocPrint(allocator, "{s}/nendb.jsonl", .{directory});
    errdefer allocator.free(database);
    const manifest = try std.fmt.allocPrint(allocator, "{s}/content-manifest.json", .{directory});
    errdefer allocator.free(manifest);
    const extraction_manifest = try std.fmt.allocPrint(allocator, "{s}/extraction-manifest.json", .{directory});
    errdefer allocator.free(extraction_manifest);
    const journal = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ directory, delta_journal.default_name });
    errdefer allocator.free(journal);
    const context = try std.fmt.allocPrint(allocator, "{s}/repository-context.json", .{directory});
    errdefer allocator.free(context);
    const lineage = try std.fmt.allocPrint(allocator, "{s}/change-lineage.json", .{directory});
    errdefer allocator.free(lineage);
    const origin_path = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ directory, origin_ledger.default_name });
    errdefer allocator.free(origin_path);
    const repair_path = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ directory, repair.default_name });
    errdefer allocator.free(repair_path);
    const health = try std.fmt.allocPrint(allocator, "{s}/graph-health.json", .{directory});
    errdefer allocator.free(health);
    const metadata = try std.fmt.allocPrint(allocator, "{s}/generation.json", .{directory});
    errdefer allocator.free(metadata);
    return .{
        .allocator = allocator,
        .directory = directory,
        .database = database,
        .content_manifest = manifest,
        .extraction_manifest = extraction_manifest,
        .delta_journal = journal,
        .repository_context = context,
        .change_lineage = lineage,
        .origin_ledger = origin_path,
        .repair_report = repair_path,
        .health_report = health,
        .metadata = metadata,
    };
}

fn generationIdentity(
    repository_id: []const u8,
    semantic_generation: []const u8,
    parent_generation: []const u8,
    replaces_generation: []const u8,
    discovery_digest: []const u8,
    ownership_digest: []const u8,
    extraction_digest: []const u8,
    graph_fingerprint: []const u8,
    repository_context_fingerprint: []const u8,
    change_lineage_input_fingerprint: []const u8,
    origin_input_fingerprint: []const u8,
    repair_plan_fingerprint: []const u8,
) [66]u8 {
    var hasher = std.crypto.hash.sha2.Sha256.init(.{});
    updateDigestBytes(&hasher, freshness_recipe);
    updateDigestBytes(&hasher, repository_id);
    updateDigestBytes(&hasher, semantic_generation);
    updateDigestBytes(&hasher, parent_generation);
    updateDigestBytes(&hasher, replaces_generation);
    updateDigestBytes(&hasher, discovery_digest);
    updateDigestBytes(&hasher, ownership_digest);
    updateDigestBytes(&hasher, extraction_digest);
    updateDigestBytes(&hasher, graph_fingerprint);
    updateDigestBytes(&hasher, repository_context_fingerprint);
    updateDigestBytes(&hasher, change_lineage_input_fingerprint);
    updateDigestBytes(&hasher, origin_input_fingerprint);
    updateDigestBytes(&hasher, repair_plan_fingerprint);
    updateDigestBytes(&hasher, store.current_schema);
    updateDigestBytes(&hasher, nendb.embedder);
    updateDigestBytes(&hasher, nendb.secondary_index_schema);
    updateDigestBytes(&hasher, delta_journal.schema);
    updateDigestBytes(&hasher, delta_journal.canonical_order_recipe);
    updateDigestBytes(&hasher, repository_context.schema);
    updateDigestBytes(&hasher, change_lineage.schema);
    updateDigestBytes(&hasher, origin_ledger.schema);
    updateDigestBytes(&hasher, repair.schema);
    var digest: [32]u8 = @splat(0);
    hasher.final(&digest);
    var output: [66]u8 = @splat(0);
    output[0..2].* = "g-".*;
    output[2..].* = std.fmt.bytesToHex(digest, .lower);
    return output;
}

/// Inverse of `sha256Identity`. Null for anything that is not exactly the shape
/// we write, so a malformed pointer falls back rather than matching by accident.
fn parseSha256Identity(identity: []const u8) ?[32]u8 {
    if (identity.len != 71) return null;
    if (!std.mem.startsWith(u8, identity, "sha256:")) return null;
    var digest: [32]u8 = undefined;
    _ = std.fmt.hexToBytes(&digest, identity[7..]) catch return null;
    return digest;
}

fn sha256Identity(digest: [32]u8) [71]u8 {
    var output: [71]u8 = @splat(0);
    output[0..7].* = "sha256:".*;
    output[7..].* = std.fmt.bytesToHex(digest, .lower);
    return output;
}

fn updateDigestBytes(hasher: *std.crypto.hash.sha2.Sha256, value: []const u8) void {
    var size: [8]u8 = @splat(0);
    std.mem.writeInt(u64, &size, value.len, .little);
    hasher.update(&size);
    hasher.update(value);
}

fn validGenerationId(value: []const u8) bool {
    if (value.len != 66 or !std.mem.startsWith(u8, value, "g-")) return false;
    for (value[2..]) |byte| if (!std.ascii.isDigit(byte) and !(byte >= 'a' and byte <= 'f')) return false;
    return true;
}

fn validSha256Identity(value: []const u8) bool {
    if (value.len != 71 or !std.mem.startsWith(u8, value, "sha256:")) return false;
    for (value[7..]) |byte| if (!std.ascii.isDigit(byte) and !(byte >= 'a' and byte <= 'f')) return false;
    return true;
}

fn validHexDigest(value: []const u8) bool {
    if (value.len != 64) return false;
    for (value) |byte| if (!std.ascii.isDigit(byte) and !(byte >= 'a' and byte <= 'f')) return false;
    return true;
}

fn prunedRecords(previous: *const model.RepositoryGraph, candidate: *const model.RepositoryGraph) PrunedRecords {
    var result = PrunedRecords{};
    for (previous.nodes.items) |node| if (candidate.findNode(node.id) == null) {
        result.nodes += 1;
        result.vectors += 1;
    };
    for (previous.edges.items) |edge| {
        if (!candidate.hasEdge(edge.from, edge.to, edge.relation)) result.edges += 1;
    }
    for (previous.hyperedges.items) |hyperedge| {
        if (candidate.findHyperedge(hyperedge.id) == null) result.hyperedges += 1;
    }
    for (previous.supernodes.items) |supernode| {
        var found = false;
        for (candidate.supernodes.items) |next| if (next.id == supernode.id) {
            found = true;
            break;
        };
        if (!found) result.supernodes += 1;
    }
    return result;
}

fn discoveryOptions(config: project.Config) discovery.Options {
    return .{
        .repository_id = config.repository_id,
        .max_entries = config.max_entries,
        .max_files = config.max_files,
        .max_file_bytes = config.max_file_bytes,
        .max_total_bytes = config.max_source_bytes,
        .max_depth = config.max_depth,
        .max_path_bytes = config.max_path_bytes,
    };
}

fn graphOptions(config: project.Config) model.Options {
    return .{ .max_nodes = config.max_nodes, .max_edges = config.max_edges };
}

pub fn publish(
    allocator: std.mem.Allocator,
    io: std.Io,
    root: std.Io.Dir,
    config: project.Config,
    built: *const indexer.BuildResult,
) !void {
    return publishToPaths(allocator, io, root, config, built, &built.graph, config.content_manifest, config.health_report, .partial);
}

fn publishToPaths(
    allocator: std.mem.Allocator,
    io: std.Io,
    root: std.Io.Dir,
    config: project.Config,
    built: *const indexer.BuildResult,
    graph: *const model.RepositoryGraph,
    manifest_path: []const u8,
    health_path: []const u8,
    self_manager_status: HealthStatus,
) !void {
    try project.validateConfig(config);
    try discovery.validate(&built.discovery_result);
    try ownership.validate(&built.discovery_result, &built.ownership_result);
    const graph_health = freshness.inspect(graph);
    if (!graph_health.clean()) return error.UnhealthyBuildGraph;

    const discovery_hex = std.fmt.bytesToHex(built.discovery_result.manifest_digest, .lower);
    const ownership_hex = std.fmt.bytesToHex(built.ownership_result.manifest_digest, .lower);
    const manifest_view = .{
        .schema = content_manifest_schema,
        .schema_version = schema_version,
        .complete = true,
        .repository_id = config.repository_id,
        .classifier_version = discovery.classifier_version,
        .policy_version = discovery.policy_version,
        .discovery_manifest_digest = discovery_hex[0..],
        .ownership_manifest_digest = ownership_hex[0..],
        .observed_entries = built.discovery_result.observed_entries,
        .hashed_bytes = built.discovery_result.hashed_bytes,
        .discovery_summary = built.discovery_result.summary,
        .ownership_summary = built.ownership_result.summary,
        .records = built.discovery_result.records,
        .units = built.ownership_result.units,
        .assignments = built.ownership_result.assignments,
    };
    const manifest_bytes = try std.json.Stringify.valueAlloc(allocator, manifest_view, .{});
    defer allocator.free(manifest_bytes);
    if (manifest_bytes.len > max_manifest_bytes) return error.ContentManifestTooLarge;
    try atomicWrite(allocator, io, root, manifest_path, manifest_bytes);

    const dimensions = Dimensions{
        .generation = self_manager_status,
        .config = .healthy,
        .discovery = .healthy,
        .ownership = .healthy,
        .freshness = .healthy,
        .storage = .healthy,
        .indexes = .healthy,
        .providers = if (built.ownership_result.summary.adapters_failed == 0) .healthy else .degraded,
        .semantics = .partial,
        .self_manager = self_manager_status,
        .resources = .healthy,
    };
    const health_view = .{
        .schema = health_schema,
        .schema_version = schema_version,
        .complete = true,
        .status = HealthStatus.healthy,
        .ready = true,
        .repository_id = config.repository_id,
        .discovery_manifest_digest = discovery_hex[0..],
        .ownership_manifest_digest = ownership_hex[0..],
        .dimensions = dimensions,
        .discovery = built.discovery_result.summary,
        .ownership = built.ownership_result.summary,
        .graph = graph_health,
        .limitations = &limitations,
    };
    const health_bytes = try std.json.Stringify.valueAlloc(allocator, health_view, .{});
    defer allocator.free(health_bytes);
    if (health_bytes.len > max_health_bytes) return error.HealthReportTooLarge;
    try atomicWrite(allocator, io, root, health_path, health_bytes);
}

pub fn doctor(
    allocator: std.mem.Allocator,
    io: std.Io,
    root: std.Io.Dir,
    config: project.Config,
) !DoctorReport {
    try project.validateConfig(config);
    var reader = try GenerationReadLease.acquireShared(io, root);
    defer reader.deinit();
    var report = DoctorReport{ .repository_id = config.repository_id };
    report.retention = retention.readLatestSummary(allocator, io, root, config.repository_id) catch |failure| switch (failure) {
        error.FileNotFound => .{},
        else => .{ .status = .failed, .failed_actions = 1 },
    };
    if (report.retention.status == .failed or report.retention.failed_actions > 0) {
        report.status = .degraded;
        report.dimensions.self_manager = .degraded;
        report.addDiagnostic(.{
            .code = "retention_degraded",
            .stage = "garbage_collection",
            .status = .degraded,
            .redacted_detail = "the latest bounded retention pass failed or its receipt was invalid",
            .repair_hint = "run zgraphy gc for a dry-run plan, repair the reported owned artifact, then use zgraphy gc --apply",
            .replay_command = "zgraphy gc --json",
        });
    }

    var current_context = repository_context.inspect(allocator, io, root) catch |failure| {
        report.status = .partial;
        report.dimensions.freshness = .partial;
        report.addDiagnostic(.{
            .code = "repository_context_failed",
            .stage = "repository_context",
            .status = .partial,
            .redacted_detail = @errorName(failure),
            .repair_hint = "repair bounded local Git metadata or remove an invalid .git marker before rebuilding",
        });
        return report;
    };
    defer current_context.deinit();
    @memcpy(&report.current_repository_context_fingerprint, current_context.value.fingerprint);
    report.has_current_repository_context = true;

    var current = indexer.buildRepository(allocator, io, root, buildOptions(config)) catch |failure| {
        report.status = .partial;
        report.dimensions.discovery = .partial;
        report.addDiagnostic(.{
            .code = "current_discovery_failed",
            .stage = "discovery",
            .status = .partial,
            .redacted_detail = @errorName(failure),
            .repair_hint = "repair repository readability or configured bounds, then rerun doctor",
        });
        return report;
    };
    defer current.deinit();
    report.current_discovery_digest = std.fmt.bytesToHex(current.discovery_result.manifest_digest, .lower);
    report.current_ownership_digest = std.fmt.bytesToHex(current.ownership_result.manifest_digest, .lower);
    report.has_current = true;
    report.dimensions.discovery = .healthy;
    report.dimensions.ownership = .healthy;
    report.dimensions.resources = .healthy;
    report.dimensions.providers = if (current.ownership_result.summary.adapters_failed == 0) .healthy else .degraded;

    var active: ?std.json.Parsed(ActiveGeneration) = readActiveGeneration(allocator, io, root, config) catch null;
    defer if (active) |*parsed| parsed.deinit();
    const published_manifest = if (active) |*parsed| parsed.value.content_manifest else config.content_manifest;
    const published_database = if (active) |*parsed| parsed.value.database else config.database;
    const published_health = if (active) |*parsed| parsed.value.health_report else config.health_report;
    if (active) |*parsed| {
        @memcpy(&report.stored_repository_context_fingerprint, parsed.value.repository_context_fingerprint);
        report.has_stored_repository_context = true;
        report.change_lineage_summary = parsed.value.change_lineage_summary;
        report.origin_summary = parsed.value.origin_summary;
        report.last_repair = parsed.value.repair_summary;
    }

    const manifest_bytes = root.readFileAlloc(io, published_manifest, allocator, .limited(max_manifest_bytes)) catch |failure| {
        report.status = .partial;
        report.dimensions.freshness = .partial;
        report.addDiagnostic(.{
            .code = "content_manifest_missing",
            .stage = "publication",
            .status = .partial,
            .redacted_detail = @errorName(failure),
            .repair_hint = "run zgraphy build to publish a complete local manifest",
            .replay_command = "zgraphy build --json",
        });
        return report;
    };
    defer allocator.free(manifest_bytes);
    var header = std.json.parseFromSlice(ContentManifestHeader, allocator, manifest_bytes, .{ .ignore_unknown_fields = true }) catch {
        report.status = .corrupt;
        report.dimensions.freshness = .corrupt;
        report.addDiagnostic(.{
            .code = "content_manifest_corrupt",
            .stage = "validation",
            .status = .corrupt,
            .redacted_detail = "published content manifest did not parse",
            .repair_hint = "run zgraphy build to replace the corrupt owned artifact",
            .replay_command = "zgraphy build --json",
        });
        return report;
    };
    defer header.deinit();
    if (!std.mem.eql(u8, header.value.schema, content_manifest_schema) or header.value.schema_version != schema_version or !header.value.complete or
        !std.mem.eql(u8, header.value.repository_id, config.repository_id) or header.value.discovery_manifest_digest.len != 64 or
        header.value.ownership_manifest_digest.len != 64)
    {
        report.status = .incompatible;
        report.dimensions.freshness = .incompatible;
        report.addDiagnostic(.{
            .code = "content_manifest_incompatible",
            .stage = "validation",
            .status = .incompatible,
            .redacted_detail = "manifest schema identity or completeness did not match config",
            .repair_hint = "run zgraphy build with the current binary and repository config",
            .replay_command = "zgraphy build --json",
        });
        return report;
    }
    @memcpy(&report.stored_discovery_digest, header.value.discovery_manifest_digest);
    @memcpy(&report.stored_ownership_digest, header.value.ownership_manifest_digest);
    report.has_stored = true;

    const discovery_matches = std.mem.eql(u8, &report.current_discovery_digest, &report.stored_discovery_digest);
    const ownership_matches = std.mem.eql(u8, &report.current_ownership_digest, &report.stored_ownership_digest);
    const repository_context_matches = active == null or (report.has_stored_repository_context and
        std.mem.eql(u8, &report.current_repository_context_fingerprint, &report.stored_repository_context_fingerprint));
    if (!discovery_matches or !ownership_matches or !repository_context_matches) {
        report.status = .stale;
        report.ready = false;
        report.dimensions.freshness = .stale;
        report.addDiagnostic(.{
            .code = if (!discovery_matches) "source_manifest_changed" else if (!ownership_matches) "ownership_manifest_changed" else "repository_context_changed",
            .stage = "discovery",
            .status = .stale,
            .redacted_detail = "current repository fingerprint differs from the last published graph",
            .repair_hint = "run zgraphy build before trusting repository facts",
            .replay_command = "zgraphy build --json",
        });
    } else {
        report.dimensions.freshness = .healthy;
    }

    var loaded_generation: LoadedGeneration = if (active) |*parsed| loadGenerationGraph(allocator, io, root, config, parsed.value) catch |failure| {
        report.status = .corrupt;
        report.ready = false;
        report.dimensions.storage = .corrupt;
        report.dimensions.indexes = .corrupt;
        report.addDiagnostic(.{
            .code = "snapshot_unavailable",
            .stage = "storage",
            .status = .corrupt,
            .redacted_detail = @errorName(failure),
            .repair_hint = "run zgraphy build to replace the owned snapshot",
            .replay_command = "zgraphy build --json",
        });
        return report;
    } else .{ .graph = store.load(allocator, io, root, published_database, .{
        .max_nodes = config.max_nodes,
        .max_edges = config.max_edges,
    }) catch |failure| {
        report.status = .corrupt;
        report.ready = false;
        report.dimensions.storage = .corrupt;
        report.dimensions.indexes = .corrupt;
        report.addDiagnostic(.{
            .code = "snapshot_unavailable",
            .stage = "storage",
            .status = .corrupt,
            .redacted_detail = @errorName(failure),
            .repair_hint = "run zgraphy build to replace the owned snapshot",
            .replay_command = "zgraphy build --json",
        });
        return report;
    }, .recovery_source = .full_snapshot };
    defer loaded_generation.graph.deinit();
    const loaded_health = freshness.inspect(&loaded_generation.graph);
    report.nodes = loaded_health.nodes;
    report.edges = loaded_health.edges;
    report.vectors = loaded_health.vectors;
    if (!loaded_health.clean()) {
        report.status = .corrupt;
        report.ready = false;
        report.dimensions.storage = .corrupt;
        report.dimensions.indexes = .corrupt;
        report.addDiagnostic(.{
            .code = "graph_integrity_failed",
            .stage = "storage",
            .status = .corrupt,
            .redacted_detail = "snapshot has dangling edges orphan vectors or missing vectors",
            .repair_hint = "run zgraphy build and retain the corrupt artifact for diagnosis",
            .replay_command = "zgraphy build --json",
        });
        return report;
    }
    report.dimensions.storage = .healthy;
    report.dimensions.indexes = .healthy;

    if (active) |*parsed| {
        var stored_context = repository_context.read(allocator, io, root, parsed.value.repository_context) catch |failure| {
            report.status = .degraded;
            report.dimensions.self_manager = .degraded;
            report.addDiagnostic(.{
                .code = "repository_context_degraded",
                .stage = "repository_context",
                .status = .degraded,
                .redacted_detail = @errorName(failure),
                .repair_hint = "run zgraphy build to publish context evidence bound to the active generation",
                .replay_command = "zgraphy build --json",
            });
            return report;
        };
        defer stored_context.deinit();
        if (!std.mem.eql(u8, stored_context.value.fingerprint, parsed.value.repository_context_fingerprint)) {
            report.status = .degraded;
            report.dimensions.self_manager = .degraded;
            report.addDiagnostic(.{
                .code = "repository_context_binding_mismatch",
                .stage = "repository_context",
                .status = .degraded,
                .redacted_detail = "stored repository context does not match the active generation binding",
                .repair_hint = "run zgraphy build to replace inconsistent owned context evidence",
                .replay_command = "zgraphy build --json",
            });
        }
        var lineage = change_lineage.read(allocator, io, root, parsed.value.change_lineage) catch |failure| {
            report.status = .degraded;
            report.dimensions.self_manager = .degraded;
            report.addDiagnostic(.{
                .code = "change_lineage_degraded",
                .stage = "lineage",
                .status = .degraded,
                .redacted_detail = @errorName(failure),
                .repair_hint = "run zgraphy build to publish lineage evidence bound to the active generation",
                .replay_command = "zgraphy build --json",
            });
            return report;
        };
        defer lineage.deinit();
        if (!std.mem.eql(u8, lineage.value.fingerprint, parsed.value.change_lineage_fingerprint) or
            !std.mem.eql(u8, lineage.value.target_generation, parsed.value.generation))
        {
            report.status = .degraded;
            report.dimensions.self_manager = .degraded;
            report.addDiagnostic(.{
                .code = "change_lineage_binding_mismatch",
                .stage = "lineage",
                .status = .degraded,
                .redacted_detail = "stored lineage does not match the active generation binding",
                .repair_hint = "run zgraphy build to replace inconsistent owned lineage evidence",
                .replay_command = "zgraphy build --json",
            });
        }
        validateOriginAndRepair(allocator, io, root, parsed.value, &loaded_generation.graph, false) catch |failure| {
            report.status = .degraded;
            report.dimensions.self_manager = .degraded;
            report.addDiagnostic(.{
                .code = "origin_repair_binding_mismatch",
                .stage = "self_manager",
                .status = .degraded,
                .redacted_detail = @errorName(failure),
                .repair_hint = "run zgraphy build to publish exact origin ownership and repair evidence for the active graph",
                .replay_command = "zgraphy build --json",
            });
        };
        if (loaded_generation.recovery_source == .parent_delta_replay) {
            report.status = .degraded;
            report.dimensions.storage = .degraded;
            report.addDiagnostic(.{
                .code = "snapshot_recovered_from_delta",
                .stage = "recovery",
                .status = .degraded,
                .redacted_detail = "the active snapshot was unavailable and exact parent plus journal replay supplied the graph",
                .repair_hint = "run zgraphy build to publish a new complete checkpoint while retaining the damaged generation for diagnosis",
                .replay_command = "zgraphy build --json",
            });
        } else {
            var journal: ?delta_journal.Inspection = delta_journal.inspect(allocator, io, root, parsed.value.delta_journal) catch |failure| blk: {
                report.status = .degraded;
                report.dimensions.self_manager = .degraded;
                report.addDiagnostic(.{
                    .code = "delta_journal_degraded",
                    .stage = "recovery",
                    .status = .degraded,
                    .redacted_detail = @errorName(failure),
                    .repair_hint = "run zgraphy build to replace the damaged owned delta evidence; the complete snapshot remains queryable",
                    .replay_command = "zgraphy build --json",
                });
                break :blk null;
            };
            if (journal) |*info| {
                defer info.deinit();
                validateDeltaBindings(parsed.value, info.*) catch |failure| {
                    report.status = .degraded;
                    report.dimensions.self_manager = .degraded;
                    report.addDiagnostic(.{
                        .code = "delta_journal_binding_mismatch",
                        .stage = "recovery",
                        .status = .degraded,
                        .redacted_detail = @errorName(failure),
                        .repair_hint = "run zgraphy build to publish journal evidence bound to the active generation",
                        .replay_command = "zgraphy build --json",
                    });
                };
            }
        }
    }

    const health_bytes = root.readFileAlloc(io, published_health, allocator, .limited(max_health_bytes)) catch |failure| {
        report.status = .partial;
        report.ready = false;
        report.addDiagnostic(.{
            .code = "health_baseline_missing",
            .stage = "publication",
            .status = .partial,
            .redacted_detail = @errorName(failure),
            .repair_hint = "run zgraphy build to publish health evidence",
            .replay_command = "zgraphy build --json",
        });
        return report;
    };
    defer allocator.free(health_bytes);
    var health_header = std.json.parseFromSlice(HealthHeader, allocator, health_bytes, .{ .ignore_unknown_fields = true }) catch {
        report.status = .corrupt;
        report.ready = false;
        report.addDiagnostic(.{
            .code = "health_baseline_corrupt",
            .stage = "validation",
            .status = .corrupt,
            .redacted_detail = "published health baseline did not parse",
            .repair_hint = "run zgraphy build to replace the corrupt owned artifact",
            .replay_command = "zgraphy build --json",
        });
        return report;
    };
    defer health_header.deinit();
    if (!std.mem.eql(u8, health_header.value.schema, health_schema) or health_header.value.schema_version != schema_version or !health_header.value.complete) {
        report.status = .incompatible;
        report.ready = false;
        report.addDiagnostic(.{
            .code = "health_baseline_incompatible",
            .stage = "validation",
            .status = .incompatible,
            .redacted_detail = "health baseline schema or completeness did not match",
            .repair_hint = "run zgraphy build with the current binary",
            .replay_command = "zgraphy build --json",
        });
        return report;
    }

    report.dimensions.semantics = .partial;
    report.dimensions.generation = if (active != null) .healthy else .partial;
    if (report.dimensions.self_manager == .partial) report.dimensions.self_manager = if (active != null) .healthy else .partial;
    if (report.status != .stale and report.status != .degraded) {
        report.status = .healthy;
        report.ready = true;
    } else if (report.status == .degraded) {
        report.ready = true;
    }
    return report;
}

pub fn encodeDoctorAlloc(allocator: std.mem.Allocator, config: project.Config, report: *const DoctorReport) ![]u8 {
    return encodeDoctorWithWatchAlloc(allocator, config, report, .{ .status = .empty });
}

pub fn encodeDoctorWithWatchAlloc(
    allocator: std.mem.Allocator,
    config: project.Config,
    report: *const DoctorReport,
    watch: WatchDoctorView,
) ![]u8 {
    const effective = effectiveConfig(config);
    const current_discovery = if (report.has_current) report.current_discovery_digest[0..] else "";
    const current_ownership = if (report.has_current) report.current_ownership_digest[0..] else "";
    const stored_discovery = if (report.has_stored) report.stored_discovery_digest[0..] else "";
    const stored_ownership = if (report.has_stored) report.stored_ownership_digest[0..] else "";
    const current_repository_context = if (report.has_current_repository_context) report.current_repository_context_fingerprint[0..] else "";
    const stored_repository_context = if (report.has_stored_repository_context) report.stored_repository_context_fingerprint[0..] else "";
    var dimensions = report.dimensions;
    if (watch.status == .corrupt) dimensions.self_manager = .corrupt;
    if (watch.status == .unavailable) dimensions.self_manager = .degraded;
    if (report.retention.status == .failed or report.retention.failed_actions > 0) dimensions.self_manager = .degraded;
    return std.json.Stringify.valueAlloc(allocator, .{
        .schema = doctor_schema,
        .schema_version = schema_version,
        .status = if (watch.status == .corrupt) HealthStatus.corrupt else if (watch.status == .unavailable) HealthStatus.degraded else report.status,
        .ready = report.ready and watch.status != .corrupt,
        .repository_id = report.repository_id,
        .dimensions = dimensions,
        .current_discovery_manifest_digest = current_discovery,
        .current_ownership_manifest_digest = current_ownership,
        .stored_discovery_manifest_digest = stored_discovery,
        .stored_ownership_manifest_digest = stored_ownership,
        .current_repository_context_fingerprint = current_repository_context,
        .stored_repository_context_fingerprint = stored_repository_context,
        .change_lineage = report.change_lineage_summary,
        .origin = report.origin_summary,
        .last_repair = report.last_repair,
        .retention = report.retention,
        .nodes = report.nodes,
        .edges = report.edges,
        .vectors = report.vectors,
        .diagnostics = report.diagnostics(),
        .watch = watch,
        .effective_config = effective,
        .limitations = &limitations,
    }, .{ .whitespace = .indent_2 });
}

fn artifactFingerprint(io: std.Io, root: std.Io.Dir, path: []const u8) ![71]u8 {
    const file = try root.openFile(io, path, .{});
    defer file.close(io);
    var hasher = std.crypto.hash.sha2.Sha256.init(.{});
    var buffer: [64 * 1024]u8 = @splat(0);
    var offset: u64 = 0;
    while (true) {
        const vectors = [_][]u8{buffer[0..]};
        const count = try file.readPositional(io, &vectors, offset);
        if (count == 0) break;
        hasher.update(buffer[0..count]);
        offset = std.math.add(u64, offset, count) catch return error.ArtifactTooLarge;
    }
    var digest: [32]u8 = @splat(0);
    hasher.final(&digest);
    return sha256Identity(digest);
}

fn artifactStamp(io: std.Io, root: std.Io.Dir, path: []const u8) !ArtifactStamp {
    const stat = try root.statFile(io, path, .{ .follow_symlinks = false });
    if (stat.kind != .file or stat.size == 0) return error.InvalidGenerationArtifact;
    return .{
        .inode = @intCast(stat.inode),
        .size = stat.size,
        .mtime_ns = stat.mtime.nanoseconds,
        .ctime_ns = stat.ctime.nanoseconds,
    };
}

fn validArtifactStamp(stamp: ArtifactStamp) bool {
    return stamp.inode != 0 and stamp.size > 0 and stamp.mtime_ns != 0 and stamp.ctime_ns != 0;
}

fn atomicWrite(
    allocator: std.mem.Allocator,
    io: std.Io,
    root: std.Io.Dir,
    path: []const u8,
    bytes: []const u8,
) !void {
    if (std.mem.lastIndexOfScalar(u8, path, '/')) |slash| try root.createDirPath(io, path[0..slash]);
    for (0..1024) |slot| if (try atomicWriteSlot(allocator, io, root, path, bytes, slot)) return;
    return error.AtomicTemporaryPathExhausted;
}

fn atomicWriteSlot(
    allocator: std.mem.Allocator,
    io: std.Io,
    root: std.Io.Dir,
    path: []const u8,
    bytes: []const u8,
    slot: usize,
) !bool {
    const temporary = try std.fmt.allocPrint(allocator, "{s}.tmp.{d}", .{ path, slot });
    defer allocator.free(temporary);
    const file = root.createFile(io, temporary, .{ .exclusive = true }) catch |failure| switch (failure) {
        error.PathAlreadyExists => return false,
        else => return failure,
    };
    defer file.close(io);
    errdefer root.deleteFile(io, temporary) catch {};
    try file.writeStreamingAll(io, bytes);
    root.rename(temporary, root, path, io) catch |failure| {
        root.deleteFile(io, temporary) catch {};
        return failure;
    };
    return true;
}
