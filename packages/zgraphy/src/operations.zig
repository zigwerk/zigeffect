const std = @import("std");
const discovery = @import("discovery.zig");
const freshness = @import("freshness.zig");
const indexer = @import("indexer.zig");
const ownership = @import("ownership.zig");
const project = @import("project.zig");
const store = @import("store.zig");

pub const content_manifest_schema = "zgraphy.content-manifest.v1";
pub const health_schema = "zgraphy.graph-health.v1";
pub const doctor_schema = "zgraphy.doctor.v1";
pub const effective_config_schema = "zgraphy.effective-config.v1";
pub const schema_version: u32 = 1;
pub const max_manifest_bytes: usize = 64 * 1024 * 1024;
pub const max_health_bytes: usize = 1024 * 1024;

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
    has_current: bool = false,
    has_stored: bool = false,
    nodes: usize = 0,
    edges: usize = 0,
    vectors: usize = 0,
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

const ContentManifestHeader = struct {
    schema: []const u8,
    schema_version: u32,
    repository_id: []const u8,
    discovery_manifest_digest: []const u8,
    ownership_manifest_digest: []const u8,
    complete: bool,
};

const HealthHeader = struct {
    schema: []const u8,
    schema_version: u32,
    status: HealthStatus,
    complete: bool,
};

const limitations = [_][]const u8{
    "deep semantic extraction is Zig-only in M1",
    "incremental refresh automatic pruning repair and garbage collection are not implemented in M1",
    "publication artifacts are individually atomic but not yet one transactional generation",
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

pub fn publish(
    allocator: std.mem.Allocator,
    io: std.Io,
    root: std.Io.Dir,
    config: project.Config,
    built: *const indexer.BuildResult,
) !void {
    try project.validateConfig(config);
    try discovery.validate(&built.discovery_result);
    try ownership.validate(&built.discovery_result, &built.ownership_result);
    const graph_health = freshness.inspect(&built.graph);
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
    const manifest_bytes = try std.json.Stringify.valueAlloc(allocator, manifest_view, .{ .whitespace = .indent_2 });
    defer allocator.free(manifest_bytes);
    if (manifest_bytes.len > max_manifest_bytes) return error.ContentManifestTooLarge;
    try atomicWrite(allocator, io, root, config.content_manifest, manifest_bytes);

    const dimensions = Dimensions{
        .config = .healthy,
        .discovery = .healthy,
        .ownership = .healthy,
        .freshness = .healthy,
        .storage = .healthy,
        .indexes = .healthy,
        .providers = if (built.ownership_result.summary.adapters_failed == 0) .healthy else .degraded,
        .semantics = .partial,
        .self_manager = .partial,
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
    const health_bytes = try std.json.Stringify.valueAlloc(allocator, health_view, .{ .whitespace = .indent_2 });
    defer allocator.free(health_bytes);
    if (health_bytes.len > max_health_bytes) return error.HealthReportTooLarge;
    try atomicWrite(allocator, io, root, config.health_report, health_bytes);
}

pub fn doctor(
    allocator: std.mem.Allocator,
    io: std.Io,
    root: std.Io.Dir,
    config: project.Config,
) !DoctorReport {
    try project.validateConfig(config);
    var report = DoctorReport{ .repository_id = config.repository_id };

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

    const manifest_bytes = root.readFileAlloc(io, config.content_manifest, allocator, .limited(max_manifest_bytes)) catch |failure| {
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
    if (!discovery_matches or !ownership_matches) {
        report.status = .stale;
        report.ready = false;
        report.dimensions.freshness = .stale;
        report.addDiagnostic(.{
            .code = if (!discovery_matches) "source_manifest_changed" else "ownership_manifest_changed",
            .stage = "discovery",
            .status = .stale,
            .redacted_detail = "current repository fingerprint differs from the last published graph",
            .repair_hint = "run zgraphy build before trusting repository facts",
            .replay_command = "zgraphy build --json",
        });
    } else {
        report.dimensions.freshness = .healthy;
    }

    var loaded = store.load(allocator, io, root, config.database, .{
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
    };
    defer loaded.deinit();
    const loaded_health = freshness.inspect(&loaded);
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

    const health_bytes = root.readFileAlloc(io, config.health_report, allocator, .limited(max_health_bytes)) catch |failure| {
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
    report.dimensions.self_manager = .partial;
    if (report.status != .stale) {
        report.status = .healthy;
        report.ready = true;
    }
    return report;
}

pub fn encodeDoctorAlloc(allocator: std.mem.Allocator, config: project.Config, report: *const DoctorReport) ![]u8 {
    const effective = effectiveConfig(config);
    const current_discovery = if (report.has_current) report.current_discovery_digest[0..] else "";
    const current_ownership = if (report.has_current) report.current_ownership_digest[0..] else "";
    const stored_discovery = if (report.has_stored) report.stored_discovery_digest[0..] else "";
    const stored_ownership = if (report.has_stored) report.stored_ownership_digest[0..] else "";
    return std.json.Stringify.valueAlloc(allocator, .{
        .schema = doctor_schema,
        .schema_version = schema_version,
        .status = report.status,
        .ready = report.ready,
        .repository_id = report.repository_id,
        .dimensions = report.dimensions,
        .current_discovery_manifest_digest = current_discovery,
        .current_ownership_manifest_digest = current_ownership,
        .stored_discovery_manifest_digest = stored_discovery,
        .stored_ownership_manifest_digest = stored_ownership,
        .nodes = report.nodes,
        .edges = report.edges,
        .vectors = report.vectors,
        .diagnostics = report.diagnostics(),
        .effective_config = effective,
        .limitations = &limitations,
    }, .{ .whitespace = .indent_2 });
}

fn atomicWrite(
    allocator: std.mem.Allocator,
    io: std.Io,
    root: std.Io.Dir,
    path: []const u8,
    bytes: []const u8,
) !void {
    if (std.mem.lastIndexOfScalar(u8, path, '/')) |slash| try root.createDirPath(io, path[0..slash]);
    const temporary = try std.fmt.allocPrint(allocator, "{s}.tmp", .{path});
    defer allocator.free(temporary);
    root.deleteFile(io, temporary) catch |failure| switch (failure) {
        error.FileNotFound => {},
        else => return failure,
    };
    try root.writeFile(io, .{ .sub_path = temporary, .data = bytes });
    root.rename(temporary, root, path, io) catch |failure| {
        root.deleteFile(io, temporary) catch {};
        return failure;
    };
}
