const std = @import("std");
const causal_artifact = @import("causal_artifact");
const causal_compare = @import("causal_compare");
const causal_run = @import("causal_run");

pub const snapshot_manifest_schema = "zigeffect.causal.snapshot-manifest.v1";
pub const snapshot_manifest_schema_version: u32 = 1;
pub const snapshot_compare_schema = "zigeffect.causal.snapshot-compare.v1";
pub const snapshot_compare_schema_version: u32 = 1;

pub const SnapshotManifestOptions = struct {
    name: []const u8,
    target: []const u8 = "manual",
    phase: []const u8 = "manual",
    artifact_path: []const u8,
    baseline_path: ?[]const u8 = null,
    compare_report_path: ?[]const u8 = null,
    query_report_path: ?[]const u8 = null,
    advice_report_path: ?[]const u8 = null,
};

pub const SnapshotManifestPaths = struct {
    json_path: []const u8,
    text_path: []const u8,

    pub fn deinit(self: SnapshotManifestPaths, allocator: std.mem.Allocator) void {
        allocator.free(self.json_path);
        allocator.free(self.text_path);
    }
};

pub const SnapshotManifestReferencePath = struct {
    path: []const u8,

    pub fn deinit(self: SnapshotManifestReferencePath, allocator: std.mem.Allocator) void {
        allocator.free(self.path);
    }
};

const Artifact = struct {
    schema: ?[]const u8 = null,
    schema_version: ?u32 = null,
    event_taxonomy_version: ?u32 = null,
    events: []Event,
};

const SnapshotManifestForCompare = struct {
    schema: ?[]const u8 = null,
    schema_version: ?u32 = null,
    name: []const u8,
    target: []const u8,
    phase: []const u8,
    artifact: SnapshotManifestArtifactForCompare,
    warnings: ?[]const []const u8 = null,
};

const SnapshotManifestArtifactForCompare = struct {
    path: []const u8,
    schema: ?[]const u8 = null,
    schema_version: ?u32 = null,
    event_taxonomy_version: ?u32 = null,
    events: usize = 0,
    first_event_id: ?u64 = null,
    last_event_id: ?u64 = null,
    findings: usize = 0,
};

const Event = struct {
    id: u64,
    kind: []const u8,
    run_id: ?u64,
    parent_id: ?u64,
    fiber_id: ?u64,
    scope_id: ?u64,
    trace_id: ?u64,
    span_id: ?u64,
    label: []const u8,
    type_name: []const u8,
    status: []const u8,
    redacted_detail: []const u8,
};

const replay_reason = "snapshot manifest references observed causal artifact only";

pub fn validateSnapshotName(name: []const u8) error{InvalidSnapshotName}!void {
    if (name.len == 0 or name.len > 64) return error.InvalidSnapshotName;
    if (std.mem.eql(u8, name, ".") or std.mem.eql(u8, name, "..")) return error.InvalidSnapshotName;
    for (name) |byte| {
        const valid = (byte >= 'a' and byte <= 'z') or
            (byte >= 'A' and byte <= 'Z') or
            (byte >= '0' and byte <= '9') or
            byte == '_' or
            byte == '-';
        if (!valid) return error.InvalidSnapshotName;
    }
}

pub fn snapshotManifestPaths(allocator: std.mem.Allocator, name: []const u8) !SnapshotManifestPaths {
    try validateSnapshotName(name);
    const json_path = try std.fmt.allocPrint(allocator, "{s}/zigeffect-causal-snapshot-{s}.json", .{ causal_run.artifact_dir, name });
    errdefer allocator.free(json_path);
    const text_path = try std.fmt.allocPrint(allocator, "{s}/zigeffect-causal-snapshot-{s}.txt", .{ causal_run.artifact_dir, name });
    errdefer allocator.free(text_path);
    return .{
        .json_path = json_path,
        .text_path = text_path,
    };
}

pub fn resolveSnapshotManifestReference(allocator: std.mem.Allocator, value: []const u8) !SnapshotManifestReferencePath {
    if (isExplicitSnapshotManifestPath(value)) {
        return .{ .path = try allocator.dupe(u8, value) };
    }

    const paths = try snapshotManifestPaths(allocator, value);
    allocator.free(paths.text_path);
    return .{ .path = paths.json_path };
}

pub fn formatSnapshotCompareText(
    allocator: std.mem.Allocator,
    left_manifest_path: []const u8,
    left_manifest_json: []const u8,
    left_artifact_json: []const u8,
    right_manifest_path: []const u8,
    right_manifest_json: []const u8,
    right_artifact_json: []const u8,
) ![]const u8 {
    var left_parsed = try std.json.parseFromSlice(SnapshotManifestForCompare, allocator, left_manifest_json, .{ .ignore_unknown_fields = true });
    defer left_parsed.deinit();
    var right_parsed = try std.json.parseFromSlice(SnapshotManifestForCompare, allocator, right_manifest_json, .{ .ignore_unknown_fields = true });
    defer right_parsed.deinit();

    const compare_report = try causal_compare.runCompare(allocator, left_artifact_json, right_artifact_json);
    defer allocator.free(compare_report);

    const left = left_parsed.value;
    const right = right_parsed.value;

    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "zigeffect causal snapshot compare report\n");
    try output.print(allocator, "schema: {s}\n", .{snapshot_compare_schema});
    try output.print(allocator, "schema version: {d}\n", .{snapshot_compare_schema_version});
    try appendSnapshotManifestSummary(&output, allocator, "left", left_manifest_path, left);
    try appendSnapshotManifestSummary(&output, allocator, "right", right_manifest_path, right);
    try appendSignedDeltaText(&output, allocator, "event delta from manifests", countDelta(right.artifact.events, left.artifact.events));
    try appendSignedDeltaText(&output, allocator, "finding delta from manifests", countDelta(right.artifact.findings, left.artifact.findings));

    try output.appendSlice(allocator, "manifest warnings:\n");
    var wrote_warning = false;
    try appendSnapshotManifestWarnings(&output, allocator, "left", left, &wrote_warning);
    try appendSnapshotManifestWarnings(&output, allocator, "right", right, &wrote_warning);
    if (!wrote_warning) try output.appendSlice(allocator, "- none\n");

    try output.appendSlice(allocator, "event compare:\n");
    try output.appendSlice(allocator, compare_report);
    if (compare_report.len == 0 or compare_report[compare_report.len - 1] != '\n') {
        try output.append(allocator, '\n');
    }
    try output.appendSlice(allocator, "next queries:\n");
    try output.print(allocator, "- zig build causal-query -- --file {s} snapshot\n", .{left.artifact.path});
    try output.print(allocator, "- zig build causal-query -- --file {s} snapshot\n", .{right.artifact.path});
    try output.print(allocator, "- zig build causal-compare -- {s} {s}\n", .{ left.artifact.path, right.artifact.path });

    return output.toOwnedSlice(allocator);
}

pub fn formatSnapshotManifestJson(
    allocator: std.mem.Allocator,
    artifact_json: []const u8,
    options: SnapshotManifestOptions,
) ![]const u8 {
    try validateSnapshotName(options.name);
    var parsed = try std.json.parseFromSlice(Artifact, allocator, artifact_json, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();

    const events = parsed.value.events;
    const metadata = artifactMetadata(parsed.value);

    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "{\"schema\":");
    try appendJsonString(&output, allocator, snapshot_manifest_schema);
    try output.print(allocator, ",\"schema_version\":{d}", .{snapshot_manifest_schema_version});
    try output.appendSlice(allocator, ",\"name\":");
    try appendJsonString(&output, allocator, options.name);
    try output.appendSlice(allocator, ",\"target\":");
    try appendJsonString(&output, allocator, options.target);
    try output.appendSlice(allocator, ",\"phase\":");
    try appendJsonString(&output, allocator, options.phase);
    try output.appendSlice(allocator, ",\"artifact\":{\"path\":");
    try appendJsonString(&output, allocator, options.artifact_path);
    try output.appendSlice(allocator, ",\"schema\":");
    try appendOptionalJsonString(&output, allocator, metadata.schema);
    try output.appendSlice(allocator, ",\"schema_version\":");
    try appendOptionalJsonU32(&output, allocator, metadata.schema_version);
    try output.appendSlice(allocator, ",\"event_taxonomy_version\":");
    try appendOptionalJsonU32(&output, allocator, metadata.event_taxonomy_version);
    try output.print(allocator, ",\"events\":{d},\"first_event_id\":", .{events.len});
    try appendOptionalJsonU64(&output, allocator, firstEventId(events));
    try output.appendSlice(allocator, ",\"last_event_id\":");
    try appendOptionalJsonU64(&output, allocator, lastEventId(events));
    try output.print(allocator, ",\"findings\":{d}", .{findingCount(events)});
    try output.appendSlice(allocator, "},\"related\":{\"baseline_path\":");
    try appendOptionalJsonString(&output, allocator, options.baseline_path);
    try output.appendSlice(allocator, ",\"compare_report_path\":");
    try appendOptionalJsonString(&output, allocator, options.compare_report_path);
    try output.appendSlice(allocator, ",\"query_report_path\":");
    try appendOptionalJsonString(&output, allocator, options.query_report_path);
    try output.appendSlice(allocator, ",\"advice_report_path\":");
    try appendOptionalJsonString(&output, allocator, options.advice_report_path);
    try output.appendSlice(allocator, "},\"replay\":{\"feasible\":false,\"reason\":");
    try appendJsonString(&output, allocator, replay_reason);
    try output.appendSlice(allocator, "},\"next_queries\":[");
    try appendNextQueriesJson(&output, allocator, options);
    try output.appendSlice(allocator, "],\"warnings\":");
    try appendWarningsJsonArray(allocator, &output, metadata, events);
    try output.appendSlice(allocator, "}");

    return output.toOwnedSlice(allocator);
}

pub fn formatSnapshotManifestText(
    allocator: std.mem.Allocator,
    artifact_json: []const u8,
    options: SnapshotManifestOptions,
) ![]const u8 {
    try validateSnapshotName(options.name);
    var parsed = try std.json.parseFromSlice(Artifact, allocator, artifact_json, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();

    const events = parsed.value.events;
    const metadata = artifactMetadata(parsed.value);

    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "zigeffect causal snapshot manifest\n");
    try output.print(allocator, "schema: {s}\n", .{snapshot_manifest_schema});
    try output.print(allocator, "schema version: {d}\n", .{snapshot_manifest_schema_version});
    try output.print(allocator, "name: {s}\n", .{options.name});
    try output.print(allocator, "target: {s}\n", .{options.target});
    try output.print(allocator, "phase: {s}\n", .{options.phase});
    try output.print(allocator, "artifact: {s}\n", .{options.artifact_path});
    try output.print(allocator, "events: {d}\n", .{events.len});
    try appendEventIdRangeText(&output, allocator, events);
    try output.print(allocator, "findings: {d}\n", .{findingCount(events)});
    if (options.baseline_path) |path| try output.print(allocator, "baseline: {s}\n", .{path});
    if (options.compare_report_path) |path| try output.print(allocator, "compare report: {s}\n", .{path});
    if (options.query_report_path) |path| try output.print(allocator, "query report: {s}\n", .{path});
    if (options.advice_report_path) |path| try output.print(allocator, "advice report: {s}\n", .{path});
    try output.appendSlice(allocator, "replay feasible: false\n");
    try output.print(allocator, "replay reason: {s}\n", .{replay_reason});
    try output.appendSlice(allocator, "next queries:\n");
    try appendNextQueriesText(&output, allocator, options);
    try appendWarningsText(allocator, &output, metadata, events);

    return output.toOwnedSlice(allocator);
}

fn isExplicitSnapshotManifestPath(value: []const u8) bool {
    return std.mem.indexOfScalar(u8, value, '/') != null or std.mem.endsWith(u8, value, ".json");
}

fn snapshotArtifactPathFromManifestJson(allocator: std.mem.Allocator, manifest_json: []const u8) ![]const u8 {
    var parsed = try std.json.parseFromSlice(SnapshotManifestForCompare, allocator, manifest_json, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();
    return allocator.dupe(u8, parsed.value.artifact.path);
}

fn countDelta(after: usize, before: usize) isize {
    if (after >= before) return @intCast(after - before);
    return -@as(isize, @intCast(before - after));
}

fn appendSignedDeltaText(output: *std.ArrayList(u8), allocator: std.mem.Allocator, label: []const u8, delta: isize) !void {
    if (delta >= 0) {
        try output.print(allocator, "{s}: +{d}\n", .{ label, delta });
    } else {
        try output.print(allocator, "{s}: {d}\n", .{ label, delta });
    }
}

fn appendSnapshotManifestSummary(
    output: *std.ArrayList(u8),
    allocator: std.mem.Allocator,
    side: []const u8,
    manifest_path: []const u8,
    manifest: SnapshotManifestForCompare,
) !void {
    try output.print(allocator, "{s} snapshot: {s}\n", .{ side, manifest.name });
    try output.print(allocator, "{s} manifest: {s}\n", .{ side, manifest_path });
    try output.print(allocator, "{s} target: {s}\n", .{ side, manifest.target });
    try output.print(allocator, "{s} phase: {s}\n", .{ side, manifest.phase });
    try output.print(allocator, "{s} artifact: {s}\n", .{ side, manifest.artifact.path });
    try output.print(allocator, "{s} events: {d}\n", .{ side, manifest.artifact.events });
    if (manifest.artifact.first_event_id) |first| {
        if (manifest.artifact.last_event_id) |last| {
            try output.print(allocator, "{s} event ids: {d}..{d}\n", .{ side, first, last });
        } else {
            try output.print(allocator, "{s} event ids: {d}..unknown\n", .{ side, first });
        }
    } else {
        try output.print(allocator, "{s} event ids: none\n", .{side});
    }
    try output.print(allocator, "{s} findings: {d}\n", .{ side, manifest.artifact.findings });
}

fn appendSnapshotManifestWarnings(
    output: *std.ArrayList(u8),
    allocator: std.mem.Allocator,
    side: []const u8,
    manifest: SnapshotManifestForCompare,
    wrote: *bool,
) !void {
    if (manifest.schema) |schema| {
        if (!std.mem.eql(u8, schema, snapshot_manifest_schema)) {
            try output.print(allocator, "- warning: {s} manifest schema={s} unsupported; expected {s}\n", .{ side, schema, snapshot_manifest_schema });
            wrote.* = true;
        }
    } else {
        try output.print(allocator, "- warning: {s} manifest schema missing; expected {s}\n", .{ side, snapshot_manifest_schema });
        wrote.* = true;
    }

    if (manifest.schema_version) |version| {
        if (version > snapshot_manifest_schema_version) {
            try output.print(allocator, "- warning: {s} manifest schema_version={d} newer than supported={d}\n", .{ side, version, snapshot_manifest_schema_version });
            wrote.* = true;
        }
    } else {
        try output.print(allocator, "- warning: {s} manifest schema_version missing; expected {d}\n", .{ side, snapshot_manifest_schema_version });
        wrote.* = true;
    }

    if (manifest.warnings) |warnings| {
        for (warnings) |warning| {
            try output.print(allocator, "- {s} manifest: {s}\n", .{ side, warning });
            wrote.* = true;
        }
    }
}

fn artifactMetadata(artifact: Artifact) causal_artifact.ArtifactMetadata {
    return .{
        .schema = artifact.schema,
        .schema_version = artifact.schema_version,
        .event_taxonomy_version = artifact.event_taxonomy_version,
    };
}

fn appendJsonString(output: *std.ArrayList(u8), allocator: std.mem.Allocator, value: []const u8) !void {
    try output.append(allocator, '"');
    for (value) |byte| {
        switch (byte) {
            '"' => try output.appendSlice(allocator, "\\\""),
            '\\' => try output.appendSlice(allocator, "\\\\"),
            '\n' => try output.appendSlice(allocator, "\\n"),
            '\r' => try output.appendSlice(allocator, "\\r"),
            '\t' => try output.appendSlice(allocator, "\\t"),
            else => try output.append(allocator, byte),
        }
    }
    try output.append(allocator, '"');
}

fn appendOptionalJsonString(output: *std.ArrayList(u8), allocator: std.mem.Allocator, value: ?[]const u8) !void {
    if (value) |text| {
        try appendJsonString(output, allocator, text);
    } else {
        try output.appendSlice(allocator, "null");
    }
}

fn appendOptionalJsonU32(output: *std.ArrayList(u8), allocator: std.mem.Allocator, value: ?u32) !void {
    if (value) |number| {
        try output.print(allocator, "{d}", .{number});
    } else {
        try output.appendSlice(allocator, "null");
    }
}

fn appendOptionalJsonU64(output: *std.ArrayList(u8), allocator: std.mem.Allocator, value: ?u64) !void {
    if (value) |number| {
        try output.print(allocator, "{d}", .{number});
    } else {
        try output.appendSlice(allocator, "null");
    }
}

fn firstEventId(events: []const Event) ?u64 {
    if (events.len == 0) return null;
    return events[0].id;
}

fn lastEventId(events: []const Event) ?u64 {
    if (events.len == 0) return null;
    return events[events.len - 1].id;
}

fn appendEventIdRangeText(output: *std.ArrayList(u8), allocator: std.mem.Allocator, events: []const Event) !void {
    const first = firstEventId(events) orelse {
        try output.appendSlice(allocator, "event ids: none\n");
        return;
    };
    const last = lastEventId(events).?;
    try output.print(allocator, "event ids: {d}..{d}\n", .{ first, last });
}

fn findingCount(events: []const Event) usize {
    var count: usize = 0;
    for (events) |event| {
        if (std.mem.eql(u8, event.kind, "resource_acquired") and !hasFinalizedResource(events, event)) {
            count += 1;
        } else if (std.mem.eql(u8, event.kind, "scope_closed")) {
            count += pendingFiberCountAfterScopeClose(events, event);
        } else if (std.mem.eql(u8, event.kind, "resource_finalized") and std.mem.eql(u8, event.status, "failure")) {
            count += 1;
        } else if (std.mem.eql(u8, event.kind, "schedule_decision") and std.mem.eql(u8, event.status, "exhausted")) {
            count += 1;
        } else if (std.mem.eql(u8, event.kind, "service_required") and std.mem.eql(u8, event.status, "missing")) {
            count += 1;
        } else if (std.mem.eql(u8, event.kind, "assertion_recorded") and std.mem.eql(u8, event.status, "failure")) {
            count += 1;
        }
    }
    return count;
}

fn hasFinalizedResource(events: []const Event, acquired: Event) bool {
    for (events) |event| {
        if (!std.mem.eql(u8, event.kind, "resource_finalized")) continue;
        if (event.scope_id != acquired.scope_id) continue;
        if (!std.mem.eql(u8, event.type_name, acquired.type_name)) continue;
        return true;
    }
    return false;
}

fn pendingFiberCountAfterScopeClose(events: []const Event, closed: Event) usize {
    const scope_id = closed.scope_id orelse return 0;
    var count: usize = 0;
    for (events) |event| {
        if (event.scope_id != scope_id) continue;
        const fiber_id = event.fiber_id orelse continue;
        if (!std.mem.eql(u8, event.kind, "fiber_forked") and !std.mem.eql(u8, event.kind, "fiber_started")) continue;
        if (!std.mem.eql(u8, event.status, "pending") and !std.mem.eql(u8, event.status, "running")) continue;
        if (fiberCompletedAfter(events, fiber_id, closed.id)) continue;
        count += 1;
    }
    return count;
}

fn fiberCompletedAfter(events: []const Event, fiber_id: u64, closed_event_id: u64) bool {
    for (events) |event| {
        if (event.id < closed_event_id) continue;
        if (event.fiber_id != fiber_id) continue;
        if (std.mem.eql(u8, event.kind, "fiber_joined") or std.mem.eql(u8, event.kind, "fiber_interrupted")) return true;
    }
    return false;
}

fn appendNextQueriesJson(output: *std.ArrayList(u8), allocator: std.mem.Allocator, options: SnapshotManifestOptions) !void {
    const snapshot_query = try std.fmt.allocPrint(allocator, "zig build causal-query -- --file {s} snapshot", .{options.artifact_path});
    defer allocator.free(snapshot_query);
    try appendJsonString(output, allocator, snapshot_query);
    if (options.baseline_path) |baseline_path| {
        const compare_query = try std.fmt.allocPrint(allocator, "zig build causal-compare -- {s} {s}", .{ baseline_path, options.artifact_path });
        defer allocator.free(compare_query);
        try output.append(allocator, ',');
        try appendJsonString(output, allocator, compare_query);
    }
}

fn appendNextQueriesText(output: *std.ArrayList(u8), allocator: std.mem.Allocator, options: SnapshotManifestOptions) !void {
    try output.print(allocator, "- zig build causal-query -- --file {s} snapshot\n", .{options.artifact_path});
    if (options.baseline_path) |baseline_path| {
        try output.print(allocator, "- zig build causal-compare -- {s} {s}\n", .{ baseline_path, options.artifact_path });
    }
}

fn appendWarningsJsonArray(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    metadata: causal_artifact.ArtifactMetadata,
    events: []const Event,
) !void {
    try output.append(allocator, '[');
    var wrote = false;
    try appendCompatibilityWarningsJson(allocator, output, metadata, &wrote);
    try appendUnknownKindWarningsJson(allocator, output, events, &wrote);
    try output.append(allocator, ']');
}

fn appendWarningsText(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    metadata: causal_artifact.ArtifactMetadata,
    events: []const Event,
) !void {
    var warnings = std.ArrayList(u8).empty;
    defer warnings.deinit(allocator);
    try causal_artifact.appendArtifactCompatibilityWarnings(&warnings, allocator, "artifact", metadata);
    try causal_artifact.appendUnknownEventKindWarnings(&warnings, allocator, "artifact", events);
    if (warnings.items.len == 0) return;
    try output.appendSlice(allocator, "warnings:\n");
    var iterator = std.mem.splitScalar(u8, warnings.items, '\n');
    while (iterator.next()) |line| {
        if (line.len == 0) continue;
        try output.print(allocator, "- {s}\n", .{line});
    }
}

fn appendCompatibilityWarningsJson(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    metadata: causal_artifact.ArtifactMetadata,
    wrote: *bool,
) !void {
    var warnings = std.ArrayList(u8).empty;
    defer warnings.deinit(allocator);
    try causal_artifact.appendArtifactCompatibilityWarnings(&warnings, allocator, "artifact", metadata);
    var iterator = std.mem.splitScalar(u8, warnings.items, '\n');
    while (iterator.next()) |line| {
        if (line.len == 0) continue;
        if (wrote.*) try output.append(allocator, ',');
        try appendJsonString(output, allocator, line);
        wrote.* = true;
    }
}

fn appendUnknownKindWarningsJson(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    events: []const Event,
    wrote: *bool,
) !void {
    var seen = std.ArrayList([]const u8).empty;
    defer seen.deinit(allocator);

    for (events) |event| {
        if (causal_artifact.isKnownCausalEventKind(event.kind)) continue;
        var already_seen = false;
        for (seen.items) |kind| {
            if (std.mem.eql(u8, kind, event.kind)) {
                already_seen = true;
                break;
            }
        }
        if (already_seen) continue;
        try seen.append(allocator, event.kind);

        const warning = try std.fmt.allocPrint(
            allocator,
            "warning: artifact event kind {s} unknown to supported taxonomy={d}; query/advice role semantics may be incomplete",
            .{ event.kind, causal_artifact.supported_event_taxonomy_version },
        );
        defer allocator.free(warning);
        if (wrote.*) try output.append(allocator, ',');
        try appendJsonString(output, allocator, warning);
        wrote.* = true;
    }
}

const ManifestFormat = enum {
    json,
    text,
};

fn usage() []const u8 {
    return "usage: zig build causal-snapshot -- manifest <name> <artifact.json> [--format json|text] [--target <target>] [--phase <phase>] [--baseline <path>] [--compare-report <path>] [--query-report <path>] [--advice-report <path>]\n       zig build causal-snapshot -- capture <name> [scenario]\n       zig build causal-snapshot -- compare <left> <right>\n";
}

fn failUsage(err: anyerror) noreturn {
    std.debug.print("causal-snapshot error: {s}\n{s}", .{ @errorName(err), usage() });
    std.process.exit(2);
}

fn parseFormat(value: []const u8) error{InvalidSnapshotFormat}!ManifestFormat {
    if (std.mem.eql(u8, value, "json")) return .json;
    if (std.mem.eql(u8, value, "text")) return .text;
    return error.InvalidSnapshotFormat;
}

fn writeArtifact(io: std.Io, path: []const u8, contents: []const u8) !void {
    const slash = std.mem.lastIndexOfScalar(u8, path, '/') orelse return error.InvalidArtifactPath;
    const cwd = std.Io.Dir.cwd();
    try cwd.createDirPath(io, path[0..slash]);
    try cwd.writeFile(io, .{ .sub_path = path, .data = contents });
}

fn captureSourcePath(allocator: std.mem.Allocator, scenario_slug: ?[]const u8) ![]const u8 {
    if (scenario_slug) |slug| {
        const scenario = try causal_run.scenarioByName(slug);
        const paths = try causal_run.artifactPaths(allocator, scenario.slug);
        allocator.free(paths.report_path);
        allocator.free(paths.dot_path);
        return paths.json_path;
    }
    return allocator.dupe(u8, causal_run.artifact_dir ++ "/zigeffect-causal-dogfood.json");
}

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len < 2) {
        std.debug.print("{s}", .{usage()});
        return;
    }

    if (std.mem.eql(u8, args[1], "manifest")) {
        if (args.len < 4) failUsage(error.MissingSnapshotArgument);
        const name = args[2];
        const artifact_path = args[3];
        var format: ManifestFormat = .json;
        var options = SnapshotManifestOptions{
            .name = name,
            .artifact_path = artifact_path,
        };

        var index: usize = 4;
        while (index < args.len) {
            const flag = args[index];
            if (index + 1 >= args.len) failUsage(error.MissingSnapshotOptionValue);
            const value = args[index + 1];
            if (std.mem.eql(u8, flag, "--format")) {
                format = parseFormat(value) catch |err| failUsage(err);
            } else if (std.mem.eql(u8, flag, "--target")) {
                options.target = value;
            } else if (std.mem.eql(u8, flag, "--phase")) {
                options.phase = value;
            } else if (std.mem.eql(u8, flag, "--baseline")) {
                options.baseline_path = value;
            } else if (std.mem.eql(u8, flag, "--compare-report")) {
                options.compare_report_path = value;
            } else if (std.mem.eql(u8, flag, "--query-report")) {
                options.query_report_path = value;
            } else if (std.mem.eql(u8, flag, "--advice-report")) {
                options.advice_report_path = value;
            } else {
                failUsage(error.UnknownSnapshotOption);
            }
            index += 2;
        }

        const artifact_json = try std.Io.Dir.cwd().readFileAlloc(init.io, artifact_path, allocator, .limited(1024 * 1024));
        defer allocator.free(artifact_json);
        const manifest = switch (format) {
            .json => try formatSnapshotManifestJson(allocator, artifact_json, options),
            .text => try formatSnapshotManifestText(allocator, artifact_json, options),
        };
        defer allocator.free(manifest);
        std.debug.print("{s}", .{manifest});
        if (manifest.len == 0 or manifest[manifest.len - 1] != '\n') std.debug.print("\n", .{});
        return;
    }

    if (std.mem.eql(u8, args[1], "capture")) {
        if (args.len < 3 or args.len > 4) failUsage(error.InvalidSnapshotCaptureArguments);
        const name = args[2];
        const scenario_slug = if (args.len == 4) args[3] else null;
        const source_path = try captureSourcePath(allocator, scenario_slug);
        defer allocator.free(source_path);
        const target = scenario_slug orelse "dogfood";

        const artifact_json = try std.Io.Dir.cwd().readFileAlloc(init.io, source_path, allocator, .limited(1024 * 1024));
        defer allocator.free(artifact_json);
        const paths = try snapshotManifestPaths(allocator, name);
        defer paths.deinit(allocator);
        const options = SnapshotManifestOptions{
            .name = name,
            .target = target,
            .phase = "captured",
            .artifact_path = source_path,
        };
        const json = try formatSnapshotManifestJson(allocator, artifact_json, options);
        defer allocator.free(json);
        const text = try formatSnapshotManifestText(allocator, artifact_json, options);
        defer allocator.free(text);
        try writeArtifact(init.io, paths.json_path, json);
        try writeArtifact(init.io, paths.text_path, text);
        std.debug.print("zigeffect causal snapshot captured\njson: {s}\ntext: {s}\nquery: zig build causal-query -- --file {s} snapshot\n", .{
            paths.json_path,
            paths.text_path,
            source_path,
        });
        return;
    }

    if (std.mem.eql(u8, args[1], "compare")) {
        if (args.len != 4) failUsage(error.InvalidSnapshotCompareArguments);
        const left_manifest_ref = try resolveSnapshotManifestReference(allocator, args[2]);
        defer left_manifest_ref.deinit(allocator);
        const right_manifest_ref = try resolveSnapshotManifestReference(allocator, args[3]);
        defer right_manifest_ref.deinit(allocator);

        const left_manifest_json = try std.Io.Dir.cwd().readFileAlloc(init.io, left_manifest_ref.path, allocator, .limited(1024 * 1024));
        defer allocator.free(left_manifest_json);
        const right_manifest_json = try std.Io.Dir.cwd().readFileAlloc(init.io, right_manifest_ref.path, allocator, .limited(1024 * 1024));
        defer allocator.free(right_manifest_json);

        const left_artifact_path = try snapshotArtifactPathFromManifestJson(allocator, left_manifest_json);
        defer allocator.free(left_artifact_path);
        const right_artifact_path = try snapshotArtifactPathFromManifestJson(allocator, right_manifest_json);
        defer allocator.free(right_artifact_path);

        const left_artifact_json = try std.Io.Dir.cwd().readFileAlloc(init.io, left_artifact_path, allocator, .limited(1024 * 1024));
        defer allocator.free(left_artifact_json);
        const right_artifact_json = try std.Io.Dir.cwd().readFileAlloc(init.io, right_artifact_path, allocator, .limited(1024 * 1024));
        defer allocator.free(right_artifact_json);

        const report = try formatSnapshotCompareText(
            allocator,
            left_manifest_ref.path,
            left_manifest_json,
            left_artifact_json,
            right_manifest_ref.path,
            right_manifest_json,
            right_artifact_json,
        );
        defer allocator.free(report);
        std.debug.print("{s}", .{report});
        return;
    }

    failUsage(error.UnknownSnapshotCommand);
}

const sample_json =
    \\{
    \\  "schema": "zigeffect.causal.v1",
    \\  "schema_version": 1,
    \\  "event_taxonomy_version": 1,
    \\  "events": [
    \\    {"id":1,"kind":"run_started","run_id":1,"parent_id":null,"fiber_id":null,"scope_id":null,"trace_id":null,"span_id":null,"label":"baseline","type_name":"Command","status":"started","redacted_detail":""},
    \\    {"id":2,"kind":"service_required","run_id":1,"parent_id":1,"fiber_id":null,"scope_id":null,"trace_id":null,"span_id":null,"label":"Config","type_name":"Config","status":"missing","redacted_detail":"missing provider"},
    \\    {"id":3,"kind":"schedule_decision","run_id":1,"parent_id":1,"fiber_id":null,"scope_id":null,"trace_id":null,"span_id":null,"label":"retry","type_name":"Schedule.exponential","status":"exhausted","redacted_detail":"budget exhausted"}
    \\  ]
    \\}
;

const future_json =
    \\{
    \\  "schema": "zigeffect.causal.v1",
    \\  "schema_version": 2,
    \\  "event_taxonomy_version": 3,
    \\  "events": [
    \\    {"id":4,"kind":"run_started","run_id":1,"parent_id":null,"fiber_id":null,"scope_id":null,"trace_id":null,"span_id":null,"label":"future","type_name":"Command","status":"started","redacted_detail":""},
    \\    {"id":5,"kind":"effect_suspended","run_id":1,"parent_id":4,"fiber_id":null,"scope_id":null,"trace_id":null,"span_id":null,"label":"future event","type_name":"Command","status":"pending","redacted_detail":""}
    \\  ]
    \\}
;

const compare_before_json =
    \\{
    \\  "schema": "zigeffect.causal.v1",
    \\  "schema_version": 1,
    \\  "event_taxonomy_version": 1,
    \\  "events": [
    \\    {"id":1,"kind":"run_started","run_id":1,"parent_id":null,"fiber_id":null,"scope_id":null,"trace_id":null,"span_id":null,"label":"scenario","type_name":"Command","status":"started","redacted_detail":""},
    \\    {"id":2,"kind":"service_required","run_id":1,"parent_id":1,"fiber_id":null,"scope_id":null,"trace_id":null,"span_id":null,"label":"Config","type_name":"Config","status":"missing","redacted_detail":"missing provider"}
    \\  ]
    \\}
;

const compare_after_json =
    \\{
    \\  "schema": "zigeffect.causal.v1",
    \\  "schema_version": 1,
    \\  "event_taxonomy_version": 1,
    \\  "events": [
    \\    {"id":1,"kind":"run_started","run_id":1,"parent_id":null,"fiber_id":null,"scope_id":null,"trace_id":null,"span_id":null,"label":"scenario","type_name":"Command","status":"started","redacted_detail":""},
    \\    {"id":2,"kind":"service_required","run_id":1,"parent_id":1,"fiber_id":null,"scope_id":null,"trace_id":null,"span_id":null,"label":"Config","type_name":"Config","status":"provided","redacted_detail":"provider added"},
    \\    {"id":3,"kind":"exit_recorded","run_id":1,"parent_id":1,"fiber_id":null,"scope_id":null,"trace_id":null,"span_id":null,"label":"scenario","type_name":"Command","status":"success","redacted_detail":""}
    \\  ]
    \\}
;

const baseline_manifest_json =
    \\{
    \\  "schema": "zigeffect.causal.snapshot-manifest.v1",
    \\  "schema_version": 1,
    \\  "name": "baseline",
    \\  "target": "dogfood",
    \\  "phase": "baseline",
    \\  "artifact": {
    \\    "path": ".zig-cache/causal-artifacts/before.json",
    \\    "schema": "zigeffect.causal.v1",
    \\    "schema_version": 1,
    \\    "event_taxonomy_version": 1,
    \\    "events": 2,
    \\    "first_event_id": 1,
    \\    "last_event_id": 2,
    \\    "findings": 1
    \\  },
    \\  "warnings": []
    \\}
;

const after_manifest_json =
    \\{
    \\  "schema": "zigeffect.causal.snapshot-manifest.v1",
    \\  "schema_version": 1,
    \\  "name": "after",
    \\  "target": "dogfood",
    \\  "phase": "after",
    \\  "artifact": {
    \\    "path": ".zig-cache/causal-artifacts/after.json",
    \\    "schema": "zigeffect.causal.v1",
    \\    "schema_version": 1,
    \\    "event_taxonomy_version": 1,
    \\    "events": 3,
    \\    "first_event_id": 1,
    \\    "last_event_id": 3,
    \\    "findings": 0
    \\  },
    \\  "warnings": []
    \\}
;

const future_manifest_json =
    \\{
    \\  "schema": "zigeffect.causal.snapshot-manifest.v1",
    \\  "schema_version": 2,
    \\  "name": "future",
    \\  "target": "dogfood",
    \\  "phase": "after",
    \\  "artifact": {
    \\    "path": ".zig-cache/causal-artifacts/future.json",
    \\    "events": 2,
    \\    "first_event_id": 4,
    \\    "last_event_id": 5,
    \\    "findings": 0
    \\  },
    \\  "warnings": [
    \\    "warning: artifact event kind effect_suspended unknown to supported taxonomy=1"
    \\  ]
    \\}
;

test "snapshot manifest json names artifact and derived event metadata" {
    const manifest = try formatSnapshotManifestJson(std.testing.allocator, sample_json, .{
        .name = "baseline",
        .target = "dogfood",
        .phase = "baseline",
        .artifact_path = ".zig-cache/causal-artifacts/zigeffect-causal-dogfood.json",
    });
    defer std.testing.allocator.free(manifest);

    try std.testing.expect(std.mem.indexOf(u8, manifest, "\"schema\":\"zigeffect.causal.snapshot-manifest.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, manifest, "\"name\":\"baseline\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, manifest, "\"target\":\"dogfood\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, manifest, "\"phase\":\"baseline\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, manifest, "\"events\":3") != null);
    try std.testing.expect(std.mem.indexOf(u8, manifest, "\"first_event_id\":1") != null);
    try std.testing.expect(std.mem.indexOf(u8, manifest, "\"last_event_id\":3") != null);
    try std.testing.expect(std.mem.indexOf(u8, manifest, "\"findings\":2") != null);
    try std.testing.expect(std.mem.indexOf(u8, manifest, "\"feasible\":false") != null);
    try std.testing.expect(std.mem.indexOf(u8, manifest, "causal-query -- --file .zig-cache/causal-artifacts/zigeffect-causal-dogfood.json snapshot") != null);
}

test "snapshot manifest text includes replay posture and next query" {
    const report = try formatSnapshotManifestText(std.testing.allocator, sample_json, .{
        .name = "after",
        .target = "package-tests",
        .phase = "after",
        .artifact_path = ".zig-cache/causal-artifacts/zigeffect-causal-package-tests.json",
        .baseline_path = ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-package-tests-before.json",
        .compare_report_path = ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-package-tests-compare.txt",
    });
    defer std.testing.allocator.free(report);

    try std.testing.expect(std.mem.indexOf(u8, report, "zigeffect causal snapshot manifest") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "name: after") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "target: package-tests") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "baseline: .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-package-tests-before.json") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "compare report: .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-package-tests-compare.txt") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "replay feasible: false") != null);
}

test "snapshot manifest warns for future artifact shape and unknown event kind" {
    const manifest = try formatSnapshotManifestJson(std.testing.allocator, future_json, .{
        .name = "future",
        .artifact_path = ".zig-cache/causal-artifacts/future.json",
    });
    defer std.testing.allocator.free(manifest);

    try std.testing.expect(std.mem.indexOf(u8, manifest, "schema_version=2 newer than supported=1") != null);
    try std.testing.expect(std.mem.indexOf(u8, manifest, "event_taxonomy_version=3 newer than supported=1") != null);
    try std.testing.expect(std.mem.indexOf(u8, manifest, "event kind effect_suspended unknown") != null);
}

test "snapshot names validate before path formatting" {
    try validateSnapshotName("baseline");
    try validateSnapshotName("after_1");
    try std.testing.expectError(error.InvalidSnapshotName, validateSnapshotName(""));
    try std.testing.expectError(error.InvalidSnapshotName, validateSnapshotName("../oops"));
    try std.testing.expectError(error.InvalidSnapshotName, validateSnapshotName("bad name"));
}

test "snapshot manifest paths are deterministic" {
    const paths = try snapshotManifestPaths(std.testing.allocator, "baseline");
    defer paths.deinit(std.testing.allocator);

    try std.testing.expectEqualStrings(".zig-cache/causal-artifacts/zigeffect-causal-snapshot-baseline.json", paths.json_path);
    try std.testing.expectEqualStrings(".zig-cache/causal-artifacts/zigeffect-causal-snapshot-baseline.txt", paths.text_path);
}

test "snapshot compare report names manifests and embeds causal compare" {
    const report = try formatSnapshotCompareText(
        std.testing.allocator,
        ".zig-cache/causal-artifacts/zigeffect-causal-snapshot-baseline.json",
        baseline_manifest_json,
        compare_before_json,
        ".zig-cache/causal-artifacts/zigeffect-causal-snapshot-after.json",
        after_manifest_json,
        compare_after_json,
    );
    defer std.testing.allocator.free(report);

    try std.testing.expect(std.mem.indexOf(u8, report, "zigeffect causal snapshot compare report") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "schema: zigeffect.causal.snapshot-compare.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "left snapshot: baseline") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "left manifest: .zig-cache/causal-artifacts/zigeffect-causal-snapshot-baseline.json") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "left target: dogfood") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "left phase: baseline") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "left artifact: .zig-cache/causal-artifacts/before.json") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "right snapshot: after") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "right phase: after") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "right artifact: .zig-cache/causal-artifacts/after.json") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "event delta from manifests: +1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "finding delta from manifests: -1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "event compare:\nzigeffect causal compare report") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "changed events:") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "next queries:") != null);
}

test "snapshot compare report surfaces manifest warnings" {
    const report = try formatSnapshotCompareText(
        std.testing.allocator,
        ".zig-cache/causal-artifacts/zigeffect-causal-snapshot-baseline.json",
        baseline_manifest_json,
        compare_before_json,
        ".zig-cache/causal-artifacts/zigeffect-causal-snapshot-future.json",
        future_manifest_json,
        future_json,
    );
    defer std.testing.allocator.free(report);

    try std.testing.expect(std.mem.indexOf(u8, report, "manifest warnings:") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "warning: right manifest schema_version=2 newer than supported=1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "right manifest: warning: artifact event kind effect_suspended unknown") != null);
}

test "snapshot manifest references resolve names and explicit paths" {
    const named = try resolveSnapshotManifestReference(std.testing.allocator, "baseline");
    defer named.deinit(std.testing.allocator);
    try std.testing.expectEqualStrings(".zig-cache/causal-artifacts/zigeffect-causal-snapshot-baseline.json", named.path);

    const explicit = try resolveSnapshotManifestReference(std.testing.allocator, ".zig-cache/causal-artifacts/custom.json");
    defer explicit.deinit(std.testing.allocator);
    try std.testing.expectEqualStrings(".zig-cache/causal-artifacts/custom.json", explicit.path);

    try std.testing.expectError(error.InvalidSnapshotName, resolveSnapshotManifestReference(std.testing.allocator, "bad name"));
}
