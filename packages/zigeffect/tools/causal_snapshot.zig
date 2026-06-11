const std = @import("std");
const causal_artifact = @import("causal_artifact");
const causal_compare = @import("causal_compare");
const causal_run = @import("causal_run");

pub const snapshot_manifest_schema = "zigeffect.causal.snapshot-manifest.v1";
pub const snapshot_manifest_schema_version: u32 = 1;
pub const snapshot_compare_schema = "zigeffect.causal.snapshot-compare.v1";
pub const snapshot_compare_schema_version: u32 = 1;
pub const audit_chain_snapshot_compare_schema = "zigeffect.causal.audit-chain-snapshot-compare.v1";
pub const audit_chain_snapshot_compare_schema_version: u32 = 1;
pub const replay_feasibility_schema = "zigeffect.causal.replay-feasibility.v1";
pub const replay_feasibility_schema_version: u32 = 1;
pub const deterministic_replay_schema = "zigeffect.causal.deterministic-replay.v1";
pub const deterministic_replay_schema_version: u32 = 1;
pub const scenario_fork_proposal_schema = "zigeffect.causal.scenario-fork-proposal.v1";
pub const scenario_fork_proposal_schema_version: u32 = 1;
pub const audit_chain_artifact_schema = "zigeffect.causal.audit-chain.v1";
pub const audit_chain_artifact_schema_version: u32 = 1;
const replay_feasibility_event_sample_limit: usize = 20;

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

const ScenarioForkProposalPaths = struct {
    json_path: []const u8,
    text_path: []const u8,

    fn deinit(self: ScenarioForkProposalPaths, allocator: std.mem.Allocator) void {
        allocator.free(self.json_path);
        allocator.free(self.text_path);
    }
};

const Artifact = struct {
    schema: ?[]const u8 = null,
    schema_version: ?u32 = null,
    event_taxonomy_version: ?u32 = null,
    events: []Event,
};

const ArtifactSchemaProbe = struct {
    schema: ?[]const u8 = null,
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

const AuditChainArtifactForCompare = struct {
    schema: ?[]const u8 = null,
    schema_version: ?u32 = null,
    mode: []const u8 = "",
    target: []const u8 = "",
    assessment: []const u8 = "",
    proposal_status: []const u8 = "",
    approval_status: []const u8 = "",
    approved: bool = false,
    applied: bool = false,
    finding_delta: ?isize = null,
    event_ids: []const u64 = &.{},
    disappeared_event_ids: []const u64 = &.{},
    persisting_event_ids: []const u64 = &.{},
    appeared_event_ids: []const u64 = &.{},
    missing_event_ids: []const u64 = &.{},
    verification_commands: []const []const u8 = &.{},
    claim_guardrails: []const []const u8 = &.{},
    proposal_guardrails: []const []const u8 = &.{},
    chain_guardrails: []const []const u8 = &.{},
};

const AuditChainSnapshotDeltas = struct {
    event_ids_delta: isize,
    disappeared_delta: isize,
    persisting_delta: isize,
    appeared_delta: isize,
    missing_delta: isize,
    finding_delta_delta: ?isize,
    verification_command_delta: isize,
};

const ReplayFeasibilityStats = struct {
    structural_events: usize = 0,
    finding_evidence_events: usize = 0,
    sampleable_events: usize = 0,
    unknown_events: usize = 0,
    redacted_detail_events: usize = 0,
    truncated_detail_events: usize = 0,
    has_service_events: bool = false,
    has_resource_events: bool = false,
    has_fiber_events: bool = false,
    has_schedule_events: bool = false,
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
const audit_chain_snapshot_compare_limitations = [_][]const u8{
    "compares retained audit-chain artifacts only",
    "does not prove source, registry, or app mutation",
    "does not grant proposal application authority",
};
const audit_chain_snapshot_compare_guardrails = [_][]const u8{
    "Audit-chain snapshot comparison is evidence, not authorization.",
    "applied=true requires a separate reviewed application artifact.",
    "Audit-chain governance JSON is not a core causal event-run artifact.",
};

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

fn deterministicReplayArtifactPaths(
    allocator: std.mem.Allocator,
    snapshot_name: []const u8,
    scenario_slug: []const u8,
) !causal_run.ArtifactPaths {
    try validateSnapshotName(snapshot_name);
    _ = try causal_run.scenarioByName(scenario_slug);

    const report_path = try std.fmt.allocPrint(allocator, "{s}/zigeffect-causal-replay-{s}-{s}.txt", .{ causal_run.artifact_dir, snapshot_name, scenario_slug });
    errdefer allocator.free(report_path);
    const json_path = try std.fmt.allocPrint(allocator, "{s}/zigeffect-causal-replay-{s}-{s}.json", .{ causal_run.artifact_dir, snapshot_name, scenario_slug });
    errdefer allocator.free(json_path);
    const dot_path = try std.fmt.allocPrint(allocator, "{s}/zigeffect-causal-replay-{s}-{s}.dot", .{ causal_run.artifact_dir, snapshot_name, scenario_slug });
    errdefer allocator.free(dot_path);

    return .{
        .report_path = report_path,
        .json_path = json_path,
        .dot_path = dot_path,
    };
}

fn scenarioForkProposalPaths(
    allocator: std.mem.Allocator,
    snapshot_name: []const u8,
    scenario_slug: []const u8,
    fork_name: []const u8,
) !ScenarioForkProposalPaths {
    try validateSnapshotName(snapshot_name);
    _ = try causal_run.scenarioByName(scenario_slug);
    try validateSnapshotName(fork_name);

    const json_path = try std.fmt.allocPrint(
        allocator,
        "{s}/zigeffect-causal-fork-proposal-{s}-{s}-{s}.json",
        .{ causal_run.artifact_dir, snapshot_name, scenario_slug, fork_name },
    );
    errdefer allocator.free(json_path);
    const text_path = try std.fmt.allocPrint(
        allocator,
        "{s}/zigeffect-causal-fork-proposal-{s}-{s}-{s}.txt",
        .{ causal_run.artifact_dir, snapshot_name, scenario_slug, fork_name },
    );

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

pub fn formatAuditChainSnapshotCompareJson(
    allocator: std.mem.Allocator,
    left_manifest_path: []const u8,
    left_manifest_json: []const u8,
    left_audit_chain_json: []const u8,
    right_manifest_path: []const u8,
    right_manifest_json: []const u8,
    right_audit_chain_json: []const u8,
) ![]const u8 {
    var left_manifest_parsed = try std.json.parseFromSlice(SnapshotManifestForCompare, allocator, left_manifest_json, .{ .ignore_unknown_fields = true });
    defer left_manifest_parsed.deinit();
    var right_manifest_parsed = try std.json.parseFromSlice(SnapshotManifestForCompare, allocator, right_manifest_json, .{ .ignore_unknown_fields = true });
    defer right_manifest_parsed.deinit();
    var left_chain_parsed = try std.json.parseFromSlice(AuditChainArtifactForCompare, allocator, left_audit_chain_json, .{ .ignore_unknown_fields = true });
    defer left_chain_parsed.deinit();
    var right_chain_parsed = try std.json.parseFromSlice(AuditChainArtifactForCompare, allocator, right_audit_chain_json, .{ .ignore_unknown_fields = true });
    defer right_chain_parsed.deinit();

    const left_manifest = left_manifest_parsed.value;
    const right_manifest = right_manifest_parsed.value;
    const left_chain = left_chain_parsed.value;
    const right_chain = right_chain_parsed.value;
    const deltas = auditChainSnapshotDeltas(left_chain, right_chain);

    var warnings = std.ArrayList([]const u8).empty;
    defer freeOwnedStringList(allocator, &warnings);
    var blocked = false;
    try collectSnapshotManifestWarnings(allocator, &warnings, "left", left_manifest);
    try collectSnapshotManifestWarnings(allocator, &warnings, "right", right_manifest);
    try collectAuditChainSnapshotWarnings(allocator, &warnings, "left", left_manifest, left_chain, &blocked);
    try collectAuditChainSnapshotWarnings(allocator, &warnings, "right", right_manifest, right_chain, &blocked);

    const status = if (blocked) "blocked" else "ready";
    const comparison = auditChainSnapshotComparison(status, left_chain, right_chain, deltas);

    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);
    try output.appendSlice(allocator, "{\"schema\":");
    try appendJsonString(&output, allocator, audit_chain_snapshot_compare_schema);
    try output.print(allocator, ",\"schema_version\":{d}", .{audit_chain_snapshot_compare_schema_version});
    try output.appendSlice(allocator, ",\"status\":");
    try appendJsonString(&output, allocator, status);
    try output.appendSlice(allocator, ",\"comparison\":");
    try appendJsonString(&output, allocator, comparison);
    try output.appendSlice(allocator, ",\"left\":");
    try appendAuditChainSnapshotSideJson(&output, allocator, left_manifest_path, left_manifest, left_chain);
    try output.appendSlice(allocator, ",\"right\":");
    try appendAuditChainSnapshotSideJson(&output, allocator, right_manifest_path, right_manifest, right_chain);
    try output.appendSlice(allocator, ",\"deltas\":");
    try appendAuditChainSnapshotDeltasJson(&output, allocator, deltas);
    try output.appendSlice(allocator, ",\"warnings\":");
    try appendStringListJson(&output, allocator, warnings.items);
    try output.appendSlice(allocator, ",\"limitations\":");
    try appendStringListJson(&output, allocator, &audit_chain_snapshot_compare_limitations);
    try output.appendSlice(allocator, ",\"guardrails\":");
    try appendStringListJson(&output, allocator, &audit_chain_snapshot_compare_guardrails);
    try output.appendSlice(allocator, ",\"next_queries\":[");
    try appendAuditChainSnapshotCompareNextQueriesJson(&output, allocator, left_manifest_path, right_manifest_path, left_manifest, right_manifest);
    try output.appendSlice(allocator, "]}");

    return output.toOwnedSlice(allocator);
}

pub fn formatAuditChainSnapshotCompareText(
    allocator: std.mem.Allocator,
    left_manifest_path: []const u8,
    left_manifest_json: []const u8,
    left_audit_chain_json: []const u8,
    right_manifest_path: []const u8,
    right_manifest_json: []const u8,
    right_audit_chain_json: []const u8,
) ![]const u8 {
    var left_manifest_parsed = try std.json.parseFromSlice(SnapshotManifestForCompare, allocator, left_manifest_json, .{ .ignore_unknown_fields = true });
    defer left_manifest_parsed.deinit();
    var right_manifest_parsed = try std.json.parseFromSlice(SnapshotManifestForCompare, allocator, right_manifest_json, .{ .ignore_unknown_fields = true });
    defer right_manifest_parsed.deinit();
    var left_chain_parsed = try std.json.parseFromSlice(AuditChainArtifactForCompare, allocator, left_audit_chain_json, .{ .ignore_unknown_fields = true });
    defer left_chain_parsed.deinit();
    var right_chain_parsed = try std.json.parseFromSlice(AuditChainArtifactForCompare, allocator, right_audit_chain_json, .{ .ignore_unknown_fields = true });
    defer right_chain_parsed.deinit();

    const left_manifest = left_manifest_parsed.value;
    const right_manifest = right_manifest_parsed.value;
    const left_chain = left_chain_parsed.value;
    const right_chain = right_chain_parsed.value;
    const deltas = auditChainSnapshotDeltas(left_chain, right_chain);

    var warnings = std.ArrayList([]const u8).empty;
    defer freeOwnedStringList(allocator, &warnings);
    var blocked = false;
    try collectSnapshotManifestWarnings(allocator, &warnings, "left", left_manifest);
    try collectSnapshotManifestWarnings(allocator, &warnings, "right", right_manifest);
    try collectAuditChainSnapshotWarnings(allocator, &warnings, "left", left_manifest, left_chain, &blocked);
    try collectAuditChainSnapshotWarnings(allocator, &warnings, "right", right_manifest, right_chain, &blocked);

    const status = if (blocked) "blocked" else "ready";
    const comparison = auditChainSnapshotComparison(status, left_chain, right_chain, deltas);

    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);
    try output.appendSlice(allocator, "zigeffect causal audit-chain snapshot compare report\n");
    try output.print(allocator, "schema: {s}\n", .{audit_chain_snapshot_compare_schema});
    try output.print(allocator, "schema version: {d}\n", .{audit_chain_snapshot_compare_schema_version});
    try output.print(allocator, "status: {s}\n", .{status});
    try output.print(allocator, "comparison: {s}\n", .{comparison});
    try appendAuditChainSnapshotSideText(&output, allocator, "left", left_manifest_path, left_manifest, left_chain);
    try appendAuditChainSnapshotSideText(&output, allocator, "right", right_manifest_path, right_manifest, right_chain);
    try appendAuditChainSnapshotDeltasText(&output, allocator, deltas);
    try appendOwnedWarningsText(&output, allocator, warnings.items);
    try output.appendSlice(allocator, "limitations:\n");
    try appendStringListText(&output, allocator, &audit_chain_snapshot_compare_limitations);
    try output.appendSlice(allocator, "guardrails:\n");
    try appendStringListText(&output, allocator, &audit_chain_snapshot_compare_guardrails);
    try output.appendSlice(allocator, "next queries:\n");
    try appendAuditChainSnapshotCompareNextQueriesText(&output, allocator, left_manifest_path, right_manifest_path, left_manifest, right_manifest);

    return output.toOwnedSlice(allocator);
}

pub fn formatDeterministicReplayText(
    allocator: std.mem.Allocator,
    manifest_path: []const u8,
    manifest_json: []const u8,
    baseline_artifact_json: []const u8,
    scenario: causal_run.Scenario,
    replay_paths: causal_run.ArtifactPaths,
    term: std.process.Child.Term,
    replay_artifact_json_input: []const u8,
) ![]const u8 {
    var manifest_parsed = try std.json.parseFromSlice(SnapshotManifestForCompare, allocator, manifest_json, .{ .ignore_unknown_fields = true });
    defer manifest_parsed.deinit();
    const manifest = manifest_parsed.value;

    const compare_report = try causal_compare.runCompare(allocator, baseline_artifact_json, replay_artifact_json_input);
    defer allocator.free(compare_report);

    const status = commandStatus(term);
    const verdict = deterministicReplayVerdict(scenario, term, compare_report);

    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "zigeffect causal deterministic replay report\n");
    try output.print(allocator, "schema: {s}\n", .{deterministic_replay_schema});
    try output.print(allocator, "schema version: {d}\n", .{deterministic_replay_schema_version});
    try output.appendSlice(allocator, "mode: registered_scenario_rerun\n");
    try output.appendSlice(allocator, "executed: true\n");
    try output.appendSlice(allocator, "arbitrary event replay: false\n");
    try output.print(allocator, "snapshot: {s}\n", .{manifest.name});
    try output.print(allocator, "manifest: {s}\n", .{manifest_path});
    try output.print(allocator, "baseline artifact: {s}\n", .{manifest.artifact.path});
    try output.print(allocator, "scenario: {s}\n", .{scenario.slug});
    try output.print(allocator, "scenario expectation: {s}\n", .{@tagName(scenario.expectation)});
    try output.print(allocator, "scenario owner: {s}\n", .{@tagName(scenario.owner)});
    try output.print(allocator, "replay report: {s}\n", .{replay_paths.report_path});
    try output.print(allocator, "replay artifact: {s}\n", .{replay_paths.json_path});
    try output.print(allocator, "replay dot: {s}\n", .{replay_paths.dot_path});
    try output.print(allocator, "command status: {s}\n", .{status});
    try output.print(allocator, "verdict: {s}\n", .{verdict});
    try output.appendSlice(allocator, "boundary:\n");
    try output.appendSlice(allocator, "- replay reruns a registered deterministic scenario command\n");
    try output.appendSlice(allocator, "- replay does not execute or reconstruct causal event logs\n");
    try output.appendSlice(allocator, "- replay does not reconstruct services, closures, resources, fibers, clocks, scheduler state, external IO, or runtime memory\n");
    try output.appendSlice(allocator, "event compare:\n");
    try output.appendSlice(allocator, compare_report);
    if (compare_report.len == 0 or compare_report[compare_report.len - 1] != '\n') {
        try output.append(allocator, '\n');
    }
    try output.appendSlice(allocator, "next queries:\n");
    try output.print(allocator, "- zig build causal-query -- --file {s} snapshot\n", .{manifest.artifact.path});
    try output.print(allocator, "- zig build causal-query -- --file {s} snapshot\n", .{replay_paths.json_path});
    try output.print(allocator, "- zig build causal-snapshot -- replay-feasibility {s}\n", .{manifest_path});

    return output.toOwnedSlice(allocator);
}

pub fn formatScenarioForkProposalJson(
    allocator: std.mem.Allocator,
    manifest_path: []const u8,
    manifest_json: []const u8,
    scenario: causal_run.Scenario,
    fork_name: []const u8,
) ![]const u8 {
    try validateSnapshotName(fork_name);
    var manifest_parsed = try std.json.parseFromSlice(SnapshotManifestForCompare, allocator, manifest_json, .{ .ignore_unknown_fields = true });
    defer manifest_parsed.deinit();
    const manifest = manifest_parsed.value;

    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "{\"schema\":");
    try appendJsonString(&output, allocator, scenario_fork_proposal_schema);
    try output.print(allocator, ",\"schema_version\":{d}", .{scenario_fork_proposal_schema_version});
    try output.appendSlice(allocator, ",\"mode\":\"registered_scenario_fork_proposal\"");
    try output.appendSlice(allocator, ",\"proposal_status\":\"draft\"");
    try output.appendSlice(allocator, ",\"approved\":false");
    try output.appendSlice(allocator, ",\"executed\":false");
    try output.appendSlice(allocator, ",\"fork_name\":");
    try appendJsonString(&output, allocator, fork_name);
    try output.appendSlice(allocator, ",\"source\":{\"manifest\":");
    try appendJsonString(&output, allocator, manifest_path);
    try output.appendSlice(allocator, ",\"snapshot\":");
    try appendJsonString(&output, allocator, manifest.name);
    try output.appendSlice(allocator, ",\"artifact\":");
    try appendJsonString(&output, allocator, manifest.artifact.path);
    try output.appendSlice(allocator, "},\"scenario\":{\"slug\":");
    try appendJsonString(&output, allocator, scenario.slug);
    try output.appendSlice(allocator, ",\"owner\":");
    try appendJsonString(&output, allocator, @tagName(scenario.owner));
    try output.appendSlice(allocator, ",\"expectation\":");
    try appendJsonString(&output, allocator, @tagName(scenario.expectation));
    try output.appendSlice(allocator, ",\"finding_policy\":");
    try appendJsonString(&output, allocator, @tagName(scenario.finding_policy));
    try output.appendSlice(allocator, "},\"allowed_commands\":[");
    try appendScenarioForkAllowedCommandsJson(&output, allocator, manifest.name, scenario.slug);
    try output.appendSlice(allocator, "],\"blocked_operations\":[");
    try appendScenarioForkBlockedOperationsJson(&output, allocator);
    try output.appendSlice(allocator, "],\"guardrails\":[");
    try appendScenarioForkGuardrailsJson(&output, allocator);
    try output.appendSlice(allocator, "],\"next_queries\":[");
    try appendScenarioForkNextQueriesJson(&output, allocator, manifest.artifact.path);
    try output.appendSlice(allocator, "]}");

    return output.toOwnedSlice(allocator);
}

pub fn formatScenarioForkProposalText(
    allocator: std.mem.Allocator,
    manifest_path: []const u8,
    manifest_json: []const u8,
    scenario: causal_run.Scenario,
    fork_name: []const u8,
) ![]const u8 {
    try validateSnapshotName(fork_name);
    var manifest_parsed = try std.json.parseFromSlice(SnapshotManifestForCompare, allocator, manifest_json, .{ .ignore_unknown_fields = true });
    defer manifest_parsed.deinit();
    const manifest = manifest_parsed.value;

    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "zigeffect causal scenario fork proposal\n");
    try output.print(allocator, "schema: {s}\n", .{scenario_fork_proposal_schema});
    try output.print(allocator, "schema version: {d}\n", .{scenario_fork_proposal_schema_version});
    try output.appendSlice(allocator, "mode: registered_scenario_fork_proposal\n");
    try output.appendSlice(allocator, "proposal status: draft\n");
    try output.appendSlice(allocator, "approved: false\n");
    try output.appendSlice(allocator, "executed: false\n");
    try output.print(allocator, "fork: {s}\n", .{fork_name});
    try output.print(allocator, "source manifest: {s}\n", .{manifest_path});
    try output.print(allocator, "source snapshot: {s}\n", .{manifest.name});
    try output.print(allocator, "source artifact: {s}\n", .{manifest.artifact.path});
    try output.print(allocator, "scenario: {s}\n", .{scenario.slug});
    try output.print(allocator, "scenario owner: {s}\n", .{@tagName(scenario.owner)});
    try output.print(allocator, "scenario expectation: {s}\n", .{@tagName(scenario.expectation)});
    try output.print(allocator, "finding policy: {s}\n", .{@tagName(scenario.finding_policy)});
    try output.appendSlice(allocator, "allowed commands:\n");
    try output.print(allocator, "- zig build causal-snapshot -- replay-scenario {s} {s}\n", .{ manifest.name, scenario.slug });
    try output.print(allocator, "- zig build causal-snapshot -- replay-feasibility {s}\n", .{manifest.name});
    try output.appendSlice(allocator, "blocked operations:\n");
    try output.appendSlice(allocator, "- runtime memory forking\n");
    try output.appendSlice(allocator, "- arbitrary causal event-log replay\n");
    try output.appendSlice(allocator, "- source mutation\n");
    try output.appendSlice(allocator, "- scenario registry mutation\n");
    try output.appendSlice(allocator, "guardrails:\n");
    try output.appendSlice(allocator, "- Proposal is advisory until reviewed.\n");
    try output.appendSlice(allocator, "- Fork proposal does not execute commands.\n");
    try output.appendSlice(allocator, "- Use replay output and compare reports before claiming behavior changed.\n");
    try output.appendSlice(allocator, "next queries:\n");
    try output.print(allocator, "- zig build causal-query -- --file {s} snapshot\n", .{manifest.artifact.path});

    return output.toOwnedSlice(allocator);
}

fn appendScenarioForkAllowedCommandsJson(output: *std.ArrayList(u8), allocator: std.mem.Allocator, snapshot_name: []const u8, scenario_slug: []const u8) !void {
    const replay_command = try std.fmt.allocPrint(allocator, "zig build causal-snapshot -- replay-scenario {s} {s}", .{ snapshot_name, scenario_slug });
    defer allocator.free(replay_command);
    const feasibility_command = try std.fmt.allocPrint(allocator, "zig build causal-snapshot -- replay-feasibility {s}", .{snapshot_name});
    defer allocator.free(feasibility_command);
    try appendJsonString(output, allocator, replay_command);
    try output.append(allocator, ',');
    try appendJsonString(output, allocator, feasibility_command);
}

fn appendScenarioForkBlockedOperationsJson(output: *std.ArrayList(u8), allocator: std.mem.Allocator) !void {
    try appendJsonString(output, allocator, "runtime memory forking");
    try output.append(allocator, ',');
    try appendJsonString(output, allocator, "arbitrary causal event-log replay");
    try output.append(allocator, ',');
    try appendJsonString(output, allocator, "source mutation");
    try output.append(allocator, ',');
    try appendJsonString(output, allocator, "scenario registry mutation");
}

fn appendScenarioForkGuardrailsJson(output: *std.ArrayList(u8), allocator: std.mem.Allocator) !void {
    try appendJsonString(output, allocator, "Proposal is advisory until reviewed.");
    try output.append(allocator, ',');
    try appendJsonString(output, allocator, "Fork proposal does not execute commands.");
    try output.append(allocator, ',');
    try appendJsonString(output, allocator, "Use replay output and compare reports before claiming behavior changed.");
}

fn appendScenarioForkNextQueriesJson(output: *std.ArrayList(u8), allocator: std.mem.Allocator, artifact_path: []const u8) !void {
    const snapshot_query = try std.fmt.allocPrint(allocator, "zig build causal-query -- --file {s} snapshot", .{artifact_path});
    defer allocator.free(snapshot_query);
    try appendJsonString(output, allocator, snapshot_query);
}

pub fn formatReplayFeasibilityText(
    allocator: std.mem.Allocator,
    manifest_path: []const u8,
    manifest_json: []const u8,
    artifact_json: []const u8,
) ![]const u8 {
    var manifest_parsed = try std.json.parseFromSlice(SnapshotManifestForCompare, allocator, manifest_json, .{ .ignore_unknown_fields = true });
    defer manifest_parsed.deinit();
    var artifact_parsed = try std.json.parseFromSlice(Artifact, allocator, artifact_json, .{ .ignore_unknown_fields = true });
    defer artifact_parsed.deinit();

    const manifest = manifest_parsed.value;
    const artifact = artifact_parsed.value;
    const stats = replayFeasibilityStats(artifact.events);

    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "zigeffect causal replay feasibility report\n");
    try output.print(allocator, "schema: {s}\n", .{replay_feasibility_schema});
    try output.print(allocator, "schema version: {d}\n", .{replay_feasibility_schema_version});
    try output.print(allocator, "snapshot: {s}\n", .{manifest.name});
    try output.print(allocator, "manifest: {s}\n", .{manifest_path});
    try output.print(allocator, "target: {s}\n", .{manifest.target});
    try output.print(allocator, "phase: {s}\n", .{manifest.phase});
    try output.print(allocator, "artifact: {s}\n", .{manifest.artifact.path});
    try output.appendSlice(allocator, "feasible: false\n");
    try output.print(allocator, "reason: {s}\n", .{replay_reason});
    try output.print(allocator, "events: {d}\n", .{artifact.events.len});
    try output.print(allocator, "structural events: {d}\n", .{stats.structural_events});
    try output.print(allocator, "finding evidence events: {d}\n", .{stats.finding_evidence_events});
    try output.print(allocator, "sampleable events: {d}\n", .{stats.sampleable_events});
    try output.print(allocator, "unknown events: {d}\n", .{stats.unknown_events});
    try output.print(allocator, "redacted detail events: {d}\n", .{stats.redacted_detail_events});
    try output.print(allocator, "truncated detail events: {d}\n", .{stats.truncated_detail_events});
    try appendReplayArtifactWarnings(&output, allocator, artifact);
    try appendReplayBlockingReasons(&output, allocator, stats);
    try appendReplayEventPostureSample(&output, allocator, artifact.events);
    try appendReplayNextQueries(&output, allocator, manifest_path, manifest.artifact.path, artifact.events);

    return output.toOwnedSlice(allocator);
}

pub fn formatSnapshotManifestJson(
    allocator: std.mem.Allocator,
    artifact_json: []const u8,
    options: SnapshotManifestOptions,
) ![]const u8 {
    try validateSnapshotName(options.name);
    if (try artifactJsonLooksLikeAuditChain(allocator, artifact_json)) {
        return formatAuditChainSnapshotManifestJson(allocator, artifact_json, options);
    }

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
    if (try artifactJsonLooksLikeAuditChain(allocator, artifact_json)) {
        return formatAuditChainSnapshotManifestText(allocator, artifact_json, options);
    }

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

fn artifactJsonLooksLikeAuditChain(allocator: std.mem.Allocator, artifact_json: []const u8) !bool {
    var probe = try std.json.parseFromSlice(ArtifactSchemaProbe, allocator, artifact_json, .{ .ignore_unknown_fields = true });
    defer probe.deinit();
    const schema = probe.value.schema orelse return false;
    return std.mem.eql(u8, schema, audit_chain_artifact_schema);
}

fn auditChainManifestFindingCount(chain: AuditChainArtifactForCompare) usize {
    return chain.persisting_event_ids.len + chain.appeared_event_ids.len + chain.missing_event_ids.len;
}

fn formatAuditChainSnapshotManifestJson(
    allocator: std.mem.Allocator,
    artifact_json: []const u8,
    options: SnapshotManifestOptions,
) ![]const u8 {
    var parsed = try std.json.parseFromSlice(AuditChainArtifactForCompare, allocator, artifact_json, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();
    const chain = parsed.value;

    var warnings = std.ArrayList([]const u8).empty;
    defer freeOwnedStringList(allocator, &warnings);
    try collectAuditChainArtifactManifestWarnings(allocator, &warnings, chain);

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
    try appendOptionalJsonString(&output, allocator, chain.schema);
    try output.appendSlice(allocator, ",\"schema_version\":");
    try appendOptionalJsonU32(&output, allocator, chain.schema_version);
    try output.appendSlice(allocator, ",\"event_taxonomy_version\":null");
    try output.print(allocator, ",\"events\":0,\"first_event_id\":null,\"last_event_id\":null,\"findings\":{d}", .{auditChainManifestFindingCount(chain)});
    try output.appendSlice(allocator, "},\"related\":{\"baseline_path\":");
    try appendOptionalJsonString(&output, allocator, options.baseline_path);
    try output.appendSlice(allocator, ",\"compare_report_path\":");
    try appendOptionalJsonString(&output, allocator, options.compare_report_path);
    try output.appendSlice(allocator, ",\"query_report_path\":");
    try appendOptionalJsonString(&output, allocator, options.query_report_path);
    try output.appendSlice(allocator, ",\"advice_report_path\":");
    try appendOptionalJsonString(&output, allocator, options.advice_report_path);
    try output.appendSlice(allocator, "},\"replay\":{\"feasible\":false,\"reason\":");
    try appendJsonString(&output, allocator, "audit-chain governance artifact is not replay input");
    try output.appendSlice(allocator, "},\"next_queries\":[");
    try appendAuditChainManifestNextQueriesJson(&output, allocator, options);
    try output.appendSlice(allocator, "],\"warnings\":");
    try appendStringListJson(&output, allocator, warnings.items);
    try output.appendSlice(allocator, "}");

    return output.toOwnedSlice(allocator);
}

fn formatAuditChainSnapshotManifestText(
    allocator: std.mem.Allocator,
    artifact_json: []const u8,
    options: SnapshotManifestOptions,
) ![]const u8 {
    var parsed = try std.json.parseFromSlice(AuditChainArtifactForCompare, allocator, artifact_json, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();
    const chain = parsed.value;

    var warnings = std.ArrayList([]const u8).empty;
    defer freeOwnedStringList(allocator, &warnings);
    try collectAuditChainArtifactManifestWarnings(allocator, &warnings, chain);

    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "zigeffect causal snapshot manifest\n");
    try output.print(allocator, "schema: {s}\n", .{snapshot_manifest_schema});
    try output.print(allocator, "schema version: {d}\n", .{snapshot_manifest_schema_version});
    try output.print(allocator, "name: {s}\n", .{options.name});
    try output.print(allocator, "target: {s}\n", .{options.target});
    try output.print(allocator, "phase: {s}\n", .{options.phase});
    try output.print(allocator, "artifact: {s}\n", .{options.artifact_path});
    try output.print(allocator, "artifact schema: {s}\n", .{chain.schema orelse "missing"});
    if (chain.schema_version) |version| {
        try output.print(allocator, "artifact schema version: {d}\n", .{version});
    } else {
        try output.appendSlice(allocator, "artifact schema version: missing\n");
    }
    try output.appendSlice(allocator, "events: 0\n");
    try output.appendSlice(allocator, "event ids: none\n");
    try output.print(allocator, "findings: {d}\n", .{auditChainManifestFindingCount(chain)});
    if (options.baseline_path) |path| try output.print(allocator, "baseline: {s}\n", .{path});
    if (options.compare_report_path) |path| try output.print(allocator, "compare report: {s}\n", .{path});
    if (options.query_report_path) |path| try output.print(allocator, "query report: {s}\n", .{path});
    if (options.advice_report_path) |path| try output.print(allocator, "advice report: {s}\n", .{path});
    try output.appendSlice(allocator, "replay feasible: false\n");
    try output.appendSlice(allocator, "replay reason: audit-chain governance artifact is not replay input\n");
    try output.appendSlice(allocator, "next queries:\n");
    try appendAuditChainManifestNextQueriesText(&output, allocator, options);
    try appendOwnedWarningsText(&output, allocator, warnings.items);

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

fn auditChainSnapshotDeltas(left: AuditChainArtifactForCompare, right: AuditChainArtifactForCompare) AuditChainSnapshotDeltas {
    return .{
        .event_ids_delta = countDelta(right.event_ids.len, left.event_ids.len),
        .disappeared_delta = countDelta(right.disappeared_event_ids.len, left.disappeared_event_ids.len),
        .persisting_delta = countDelta(right.persisting_event_ids.len, left.persisting_event_ids.len),
        .appeared_delta = countDelta(right.appeared_event_ids.len, left.appeared_event_ids.len),
        .missing_delta = countDelta(right.missing_event_ids.len, left.missing_event_ids.len),
        .finding_delta_delta = optionalFindingDeltaDelta(left.finding_delta, right.finding_delta),
        .verification_command_delta = countDelta(right.verification_commands.len, left.verification_commands.len),
    };
}

fn optionalFindingDeltaDelta(left: ?isize, right: ?isize) ?isize {
    if (left) |left_value| {
        if (right) |right_value| return right_value - left_value;
    }
    return null;
}

fn assessmentRank(assessment: []const u8) i8 {
    if (std.mem.eql(u8, assessment, "improved")) return 2;
    if (std.mem.eql(u8, assessment, "unchanged")) return 1;
    if (std.mem.eql(u8, assessment, "inconclusive")) return 0;
    if (std.mem.eql(u8, assessment, "regressed")) return -1;
    return 0;
}

fn auditChainSnapshotComparison(
    status: []const u8,
    left: AuditChainArtifactForCompare,
    right: AuditChainArtifactForCompare,
    deltas: AuditChainSnapshotDeltas,
) []const u8 {
    if (!std.mem.eql(u8, status, "ready")) return "inconclusive";

    const left_rank = assessmentRank(left.assessment);
    const right_rank = assessmentRank(right.assessment);
    if (right_rank > left_rank) return "improved";
    if (right_rank < left_rank) return "regressed";

    if (deltas.finding_delta_delta) |finding_delta_delta| {
        if (finding_delta_delta < 0) return "improved";
        if (finding_delta_delta > 0) return "regressed";
    }

    if ((deltas.persisting_delta < 0 or deltas.missing_delta < 0) and deltas.appeared_delta <= 0) return "improved";
    if (deltas.persisting_delta > 0 or deltas.missing_delta > 0 or deltas.appeared_delta > 0) return "regressed";
    if (deltas.event_ids_delta == 0 and deltas.disappeared_delta == 0 and deltas.persisting_delta == 0 and deltas.appeared_delta == 0 and deltas.missing_delta == 0 and (deltas.finding_delta_delta orelse 0) == 0) return "unchanged";

    return "inconclusive";
}

fn appendAuditChainSnapshotSideJson(
    output: *std.ArrayList(u8),
    allocator: std.mem.Allocator,
    manifest_path: []const u8,
    manifest: SnapshotManifestForCompare,
    chain: AuditChainArtifactForCompare,
) !void {
    try output.append(allocator, '{');
    try output.appendSlice(allocator, "\"snapshot\":");
    try appendJsonString(output, allocator, manifest.name);
    try output.appendSlice(allocator, ",\"manifest_path\":");
    try appendJsonString(output, allocator, manifest_path);
    try output.appendSlice(allocator, ",\"artifact_path\":");
    try appendJsonString(output, allocator, manifest.artifact.path);
    try output.appendSlice(allocator, ",\"target\":");
    try appendJsonString(output, allocator, manifest.target);
    try output.appendSlice(allocator, ",\"phase\":");
    try appendJsonString(output, allocator, manifest.phase);
    try output.appendSlice(allocator, ",\"mode\":");
    try appendJsonString(output, allocator, chain.mode);
    try output.appendSlice(allocator, ",\"assessment\":");
    try appendJsonString(output, allocator, chain.assessment);
    try output.appendSlice(allocator, ",\"proposal_status\":");
    try appendJsonString(output, allocator, chain.proposal_status);
    try output.appendSlice(allocator, ",\"approval_status\":");
    try appendJsonString(output, allocator, chain.approval_status);
    try output.print(allocator, ",\"approved\":{},\"applied\":{}", .{ chain.approved, chain.applied });
    try output.appendSlice(allocator, ",\"finding_delta\":");
    try appendOptionalJsonIsize(output, allocator, chain.finding_delta);
    try output.print(
        allocator,
        ",\"event_id_count\":{d},\"disappeared_count\":{d},\"persisting_count\":{d},\"appeared_count\":{d},\"missing_count\":{d},\"verification_command_count\":{d}",
        .{
            chain.event_ids.len,
            chain.disappeared_event_ids.len,
            chain.persisting_event_ids.len,
            chain.appeared_event_ids.len,
            chain.missing_event_ids.len,
            chain.verification_commands.len,
        },
    );
    try output.append(allocator, '}');
}

fn appendAuditChainSnapshotDeltasJson(output: *std.ArrayList(u8), allocator: std.mem.Allocator, deltas: AuditChainSnapshotDeltas) !void {
    try output.append(allocator, '{');
    try output.appendSlice(allocator, "\"finding_delta_delta\":");
    try appendOptionalJsonIsize(output, allocator, deltas.finding_delta_delta);
    try output.print(
        allocator,
        ",\"event_ids_delta\":{d},\"disappeared_delta\":{d},\"persisting_delta\":{d},\"appeared_delta\":{d},\"missing_delta\":{d},\"verification_command_delta\":{d}",
        .{
            deltas.event_ids_delta,
            deltas.disappeared_delta,
            deltas.persisting_delta,
            deltas.appeared_delta,
            deltas.missing_delta,
            deltas.verification_command_delta,
        },
    );
    try output.append(allocator, '}');
}

fn appendAuditChainSnapshotSideText(
    output: *std.ArrayList(u8),
    allocator: std.mem.Allocator,
    side: []const u8,
    manifest_path: []const u8,
    manifest: SnapshotManifestForCompare,
    chain: AuditChainArtifactForCompare,
) !void {
    try output.print(allocator, "{s} snapshot: {s}\n", .{ side, manifest.name });
    try output.print(allocator, "{s} manifest: {s}\n", .{ side, manifest_path });
    try output.print(allocator, "{s} artifact: {s}\n", .{ side, manifest.artifact.path });
    try output.print(allocator, "{s} target: {s}\n", .{ side, manifest.target });
    try output.print(allocator, "{s} phase: {s}\n", .{ side, manifest.phase });
    try output.print(allocator, "{s} mode: {s}\n", .{ side, chain.mode });
    try output.print(allocator, "{s} assessment: {s}\n", .{ side, chain.assessment });
    try output.print(allocator, "{s} proposal status: {s}\n", .{ side, chain.proposal_status });
    try output.print(allocator, "{s} approval status: {s}\n", .{ side, chain.approval_status });
    try output.print(allocator, "{s} approved: {}\n", .{ side, chain.approved });
    try output.print(allocator, "{s} applied: {}\n", .{ side, chain.applied });
    try output.print(allocator, "{s} finding delta: ", .{side});
    try appendOptionalIsizeText(output, allocator, chain.finding_delta);
    try output.print(
        allocator,
        "{s} counts: event_ids={d} disappeared={d} persisting={d} appeared={d} missing={d} verification_commands={d}\n",
        .{
            side,
            chain.event_ids.len,
            chain.disappeared_event_ids.len,
            chain.persisting_event_ids.len,
            chain.appeared_event_ids.len,
            chain.missing_event_ids.len,
            chain.verification_commands.len,
        },
    );
}

fn appendAuditChainSnapshotDeltasText(output: *std.ArrayList(u8), allocator: std.mem.Allocator, deltas: AuditChainSnapshotDeltas) !void {
    try output.appendSlice(allocator, "deltas:\n");
    try appendOptionalSignedDeltaListItem(output, allocator, "finding_delta_delta", deltas.finding_delta_delta);
    try appendSignedDeltaListItem(output, allocator, "event_ids_delta", deltas.event_ids_delta);
    try appendSignedDeltaListItem(output, allocator, "disappeared_delta", deltas.disappeared_delta);
    try appendSignedDeltaListItem(output, allocator, "persisting_delta", deltas.persisting_delta);
    try appendSignedDeltaListItem(output, allocator, "appeared_delta", deltas.appeared_delta);
    try appendSignedDeltaListItem(output, allocator, "missing_delta", deltas.missing_delta);
    try appendSignedDeltaListItem(output, allocator, "verification_command_delta", deltas.verification_command_delta);
}

fn collectSnapshotManifestWarnings(
    allocator: std.mem.Allocator,
    warnings: *std.ArrayList([]const u8),
    side: []const u8,
    manifest: SnapshotManifestForCompare,
) !void {
    if (manifest.schema) |schema| {
        if (!std.mem.eql(u8, schema, snapshot_manifest_schema)) {
            try appendOwnedWarningFmt(allocator, warnings, "warning: {s} manifest schema={s} unsupported; expected {s}", .{ side, schema, snapshot_manifest_schema });
        }
    } else {
        try appendOwnedWarningFmt(allocator, warnings, "warning: {s} manifest schema missing; expected {s}", .{ side, snapshot_manifest_schema });
    }

    if (manifest.schema_version) |version| {
        if (version > snapshot_manifest_schema_version) {
            try appendOwnedWarningFmt(allocator, warnings, "warning: {s} manifest schema_version={d} newer than supported={d}", .{ side, version, snapshot_manifest_schema_version });
        }
    } else {
        try appendOwnedWarningFmt(allocator, warnings, "warning: {s} manifest schema_version missing; expected {d}", .{ side, snapshot_manifest_schema_version });
    }

    if (manifest.warnings) |manifest_warnings| {
        for (manifest_warnings) |warning| {
            try appendOwnedWarningFmt(allocator, warnings, "{s} manifest: {s}", .{ side, warning });
        }
    }
}

fn collectAuditChainSnapshotWarnings(
    allocator: std.mem.Allocator,
    warnings: *std.ArrayList([]const u8),
    side: []const u8,
    manifest: SnapshotManifestForCompare,
    chain: AuditChainArtifactForCompare,
    blocked: *bool,
) !void {
    if (manifest.artifact.schema) |schema| {
        if (!std.mem.eql(u8, schema, audit_chain_artifact_schema)) {
            try appendOwnedWarningFmt(allocator, warnings, "warning: {s} snapshot artifact schema={s} is not audit-chain schema={s}", .{ side, schema, audit_chain_artifact_schema });
            blocked.* = true;
        }
    }

    if (chain.schema) |schema| {
        if (!std.mem.eql(u8, schema, audit_chain_artifact_schema)) {
            try appendOwnedWarningFmt(allocator, warnings, "warning: {s} audit-chain schema={s} unsupported; expected {s}", .{ side, schema, audit_chain_artifact_schema });
            blocked.* = true;
        }
    } else {
        try appendOwnedWarningFmt(allocator, warnings, "warning: {s} audit-chain schema missing; expected {s}", .{ side, audit_chain_artifact_schema });
        blocked.* = true;
    }

    if (chain.schema_version) |version| {
        if (version > audit_chain_artifact_schema_version) {
            try appendOwnedWarningFmt(allocator, warnings, "warning: {s} audit-chain schema_version={d} newer than supported={d}", .{ side, version, audit_chain_artifact_schema_version });
            blocked.* = true;
        }
    } else {
        try appendOwnedWarningFmt(allocator, warnings, "warning: {s} audit-chain schema_version missing; expected {d}", .{ side, audit_chain_artifact_schema_version });
        blocked.* = true;
    }

    if (chain.target.len > 0 and !std.mem.eql(u8, chain.target, manifest.target)) {
        try appendOwnedWarningFmt(allocator, warnings, "warning: {s} manifest target={s} differs from audit-chain target={s}", .{ side, manifest.target, chain.target });
    }

    if (chain.applied) {
        try appendOwnedWarningFmt(allocator, warnings, "{s} audit-chain applied=true requires reviewed application evidence", .{side});
        blocked.* = true;
    }
}

fn collectAuditChainArtifactManifestWarnings(
    allocator: std.mem.Allocator,
    warnings: *std.ArrayList([]const u8),
    chain: AuditChainArtifactForCompare,
) !void {
    if (chain.schema) |schema| {
        if (!std.mem.eql(u8, schema, audit_chain_artifact_schema)) {
            try appendOwnedWarningFmt(allocator, warnings, "warning: artifact audit-chain schema={s} unsupported; expected {s}", .{ schema, audit_chain_artifact_schema });
        }
    } else {
        try appendOwnedWarningFmt(allocator, warnings, "warning: artifact audit-chain schema missing; expected {s}", .{audit_chain_artifact_schema});
    }

    if (chain.schema_version) |version| {
        if (version > audit_chain_artifact_schema_version) {
            try appendOwnedWarningFmt(allocator, warnings, "warning: artifact audit-chain schema_version={d} newer than supported={d}", .{ version, audit_chain_artifact_schema_version });
        }
    } else {
        try appendOwnedWarningFmt(allocator, warnings, "warning: artifact audit-chain schema_version missing; expected {d}", .{audit_chain_artifact_schema_version});
    }
}

fn appendAuditChainManifestNextQueriesJson(output: *std.ArrayList(u8), allocator: std.mem.Allocator, options: SnapshotManifestOptions) !void {
    const compare_query = try std.fmt.allocPrint(allocator, "zig build causal-snapshot -- audit-chain-compare {s} {s}", .{ options.name, options.name });
    defer allocator.free(compare_query);
    try appendJsonString(output, allocator, compare_query);

    const inspection = try std.fmt.allocPrint(allocator, "inspect audit-chain artifact {s} from snapshot {s}", .{ options.artifact_path, options.name });
    defer allocator.free(inspection);
    try output.append(allocator, ',');
    try appendJsonString(output, allocator, inspection);
}

fn appendAuditChainManifestNextQueriesText(output: *std.ArrayList(u8), allocator: std.mem.Allocator, options: SnapshotManifestOptions) !void {
    try output.print(allocator, "- zig build causal-snapshot -- audit-chain-compare {s} {s}\n", .{ options.name, options.name });
    try output.print(allocator, "- inspect audit-chain artifact: {s} (snapshot {s})\n", .{ options.artifact_path, options.name });
}

fn appendAuditChainSnapshotCompareNextQueriesJson(
    output: *std.ArrayList(u8),
    allocator: std.mem.Allocator,
    left_manifest_path: []const u8,
    right_manifest_path: []const u8,
    left_manifest: SnapshotManifestForCompare,
    right_manifest: SnapshotManifestForCompare,
) !void {
    const compare_query = try std.fmt.allocPrint(allocator, "zig build causal-snapshot -- audit-chain-compare {s} {s}", .{ left_manifest_path, right_manifest_path });
    defer allocator.free(compare_query);
    try appendJsonString(output, allocator, compare_query);

    const left_inspection = try std.fmt.allocPrint(allocator, "inspect left audit-chain artifact {s} from snapshot {s}", .{ left_manifest.artifact.path, left_manifest.name });
    defer allocator.free(left_inspection);
    try output.append(allocator, ',');
    try appendJsonString(output, allocator, left_inspection);

    const right_inspection = try std.fmt.allocPrint(allocator, "inspect right audit-chain artifact {s} from snapshot {s}", .{ right_manifest.artifact.path, right_manifest.name });
    defer allocator.free(right_inspection);
    try output.append(allocator, ',');
    try appendJsonString(output, allocator, right_inspection);
}

fn appendAuditChainSnapshotCompareNextQueriesText(
    output: *std.ArrayList(u8),
    allocator: std.mem.Allocator,
    left_manifest_path: []const u8,
    right_manifest_path: []const u8,
    left_manifest: SnapshotManifestForCompare,
    right_manifest: SnapshotManifestForCompare,
) !void {
    try output.print(allocator, "- zig build causal-snapshot -- audit-chain-compare {s} {s}\n", .{ left_manifest_path, right_manifest_path });
    try output.print(allocator, "- inspect left audit-chain artifact: {s} (snapshot {s})\n", .{ left_manifest.artifact.path, left_manifest.name });
    try output.print(allocator, "- inspect right audit-chain artifact: {s} (snapshot {s})\n", .{ right_manifest.artifact.path, right_manifest.name });
}

fn isStructuralEventKind(kind: []const u8) bool {
    return std.mem.eql(u8, kind, "run_started") or
        std.mem.eql(u8, kind, "run_completed") or
        std.mem.eql(u8, kind, "effect_started") or
        std.mem.eql(u8, kind, "effect_completed") or
        std.mem.eql(u8, kind, "layer_started") or
        std.mem.eql(u8, kind, "layer_completed") or
        std.mem.eql(u8, kind, "service_required") or
        std.mem.eql(u8, kind, "service_provided") or
        std.mem.eql(u8, kind, "service_replaced") or
        std.mem.eql(u8, kind, "scope_opened") or
        std.mem.eql(u8, kind, "scope_closed") or
        std.mem.eql(u8, kind, "resource_acquired") or
        std.mem.eql(u8, kind, "resource_finalized") or
        std.mem.eql(u8, kind, "fiber_forked") or
        std.mem.eql(u8, kind, "fiber_started") or
        std.mem.eql(u8, kind, "fiber_joined") or
        std.mem.eql(u8, kind, "fiber_interrupted") or
        std.mem.eql(u8, kind, "schedule_decision") or
        std.mem.eql(u8, kind, "exit_recorded") or
        std.mem.eql(u8, kind, "assertion_recorded");
}

fn isFindingEvidenceEventKind(kind: []const u8) bool {
    return std.mem.eql(u8, kind, "service_required") or
        std.mem.eql(u8, kind, "scope_closed") or
        std.mem.eql(u8, kind, "resource_acquired") or
        std.mem.eql(u8, kind, "resource_finalized") or
        std.mem.eql(u8, kind, "fiber_forked") or
        std.mem.eql(u8, kind, "fiber_started") or
        std.mem.eql(u8, kind, "fiber_joined") or
        std.mem.eql(u8, kind, "fiber_interrupted") or
        std.mem.eql(u8, kind, "schedule_decision") or
        std.mem.eql(u8, kind, "assertion_recorded");
}

fn isSampleableEventKind(kind: []const u8) bool {
    return std.mem.eql(u8, kind, "log_recorded") or
        std.mem.eql(u8, kind, "metric_recorded") or
        std.mem.eql(u8, kind, "span_recorded");
}

fn isServiceEventKind(kind: []const u8) bool {
    return std.mem.startsWith(u8, kind, "service_");
}

fn isResourceEventKind(kind: []const u8) bool {
    return std.mem.startsWith(u8, kind, "resource_");
}

fn isFiberEventKind(kind: []const u8) bool {
    return std.mem.startsWith(u8, kind, "fiber_");
}

fn isScheduleEventKind(kind: []const u8) bool {
    return std.mem.eql(u8, kind, "schedule_decision");
}

fn replayEventPosture(kind: []const u8) []const u8 {
    if (!causal_artifact.isKnownCausalEventKind(kind)) return "unknown_taxonomy";
    if (isSampleableEventKind(kind)) return "sampleable_observation";
    if (isFindingEvidenceEventKind(kind)) return "finding_evidence_observation";
    return "structural_observation";
}

fn containsReplayMarker(value: []const u8, marker: []const u8) bool {
    return std.mem.indexOf(u8, value, marker) != null;
}

fn replayFeasibilityStats(events: []const Event) ReplayFeasibilityStats {
    var stats = ReplayFeasibilityStats{};
    for (events) |event| {
        if (isStructuralEventKind(event.kind)) stats.structural_events += 1;
        if (isFindingEvidenceEventKind(event.kind)) stats.finding_evidence_events += 1;
        if (isSampleableEventKind(event.kind)) stats.sampleable_events += 1;
        if (!causal_artifact.isKnownCausalEventKind(event.kind)) stats.unknown_events += 1;
        if (containsReplayMarker(event.redacted_detail, "<redacted>")) stats.redacted_detail_events += 1;
        if (containsReplayMarker(event.redacted_detail, "<truncated>")) stats.truncated_detail_events += 1;
        if (isServiceEventKind(event.kind)) stats.has_service_events = true;
        if (isResourceEventKind(event.kind)) stats.has_resource_events = true;
        if (isFiberEventKind(event.kind)) stats.has_fiber_events = true;
        if (isScheduleEventKind(event.kind)) stats.has_schedule_events = true;
    }
    return stats;
}

fn appendReplayArtifactWarnings(output: *std.ArrayList(u8), allocator: std.mem.Allocator, artifact: Artifact) !void {
    var warnings = std.ArrayList(u8).empty;
    defer warnings.deinit(allocator);
    try causal_artifact.appendArtifactCompatibilityWarnings(&warnings, allocator, "artifact", artifactMetadata(artifact));
    try causal_artifact.appendUnknownEventKindWarnings(&warnings, allocator, "artifact", artifact.events);
    try output.appendSlice(allocator, "artifact warnings:\n");
    if (warnings.items.len == 0) {
        try output.appendSlice(allocator, "- none\n");
        return;
    }
    var iterator = std.mem.splitScalar(u8, warnings.items, '\n');
    while (iterator.next()) |line| {
        if (line.len == 0) continue;
        try output.print(allocator, "- {s}\n", .{line});
    }
}

fn appendReplayBlockingReasons(output: *std.ArrayList(u8), allocator: std.mem.Allocator, stats: ReplayFeasibilityStats) !void {
    try output.appendSlice(allocator, "blocking reasons:\n");
    try output.appendSlice(allocator, "- snapshot manifest references observed artifacts, not executable programs\n");
    try output.appendSlice(allocator, "- replay engine is not implemented\n");
    try output.appendSlice(allocator, "- event records do not serialize service implementations, closures, resource constructors, scheduler state, clock transcripts, or external effects\n");
    if (stats.has_service_events) try output.appendSlice(allocator, "- service values/providers are not serialized\n");
    if (stats.has_resource_events) try output.appendSlice(allocator, "- resource constructors/finalizers are not serialized\n");
    if (stats.has_fiber_events) try output.appendSlice(allocator, "- scheduler state and fiber closures are not serialized\n");
    if (stats.has_schedule_events) try output.appendSlice(allocator, "- schedule timing and randomness decisions are observations, not replay inputs\n");
    if (stats.sampleable_events > 0) try output.appendSlice(allocator, "- logs, metrics, and spans may be sampled\n");
    if (stats.unknown_events > 0) try output.appendSlice(allocator, "- unknown event taxonomy prevents complete replay classification\n");
    if (stats.redacted_detail_events > 0 or stats.truncated_detail_events > 0) try output.appendSlice(allocator, "- redacted or truncated detail prevents faithful replay evidence\n");
}

fn appendReplayEventPostureSample(output: *std.ArrayList(u8), allocator: std.mem.Allocator, events: []const Event) !void {
    try output.print(allocator, "event posture sample limit: {d}\n", .{replay_feasibility_event_sample_limit});
    try output.appendSlice(allocator, "event posture sample:\n");
    const limit = @min(events.len, replay_feasibility_event_sample_limit);
    if (limit == 0) {
        try output.appendSlice(allocator, "- none\n");
        return;
    }
    for (events[0..limit]) |event| {
        try output.print(allocator, "- event id={d} kind={s} posture={s}", .{ event.id, event.kind, replayEventPosture(event.kind) });
        if (event.status.len > 0) try output.print(allocator, " status={s}", .{event.status});
        try output.append(allocator, '\n');
    }
}

fn appendReplayNextQueries(output: *std.ArrayList(u8), allocator: std.mem.Allocator, manifest_path: []const u8, artifact_path: []const u8, events: []const Event) !void {
    try output.appendSlice(allocator, "next queries:\n");
    try output.print(allocator, "- zig build causal-query -- --file {s} snapshot\n", .{artifact_path});
    if (firstEventId(events)) |event_id| {
        try output.print(allocator, "- zig build causal-query -- --file {s} lineage {d}\n", .{ artifact_path, event_id });
    }
    try output.print(allocator, "- zig build causal-snapshot -- compare {s} {s}\n", .{ manifest_path, manifest_path });
}

fn commandFailed(term: std.process.Child.Term) bool {
    return switch (term) {
        .exited => |code| code != 0,
        else => true,
    };
}

fn commandStatus(term: std.process.Child.Term) []const u8 {
    return if (commandFailed(term)) "failure" else "success";
}

fn commandMatchesScenarioExpectation(scenario: causal_run.Scenario, term: std.process.Child.Term) bool {
    const failed = commandFailed(term);
    return switch (scenario.expectation) {
        .expected_pass => !failed,
        .expected_failure => failed,
    };
}

fn compareReportMatched(compare_report: []const u8) bool {
    return std.mem.indexOf(u8, compare_report, "event delta: +0") != null and
        std.mem.indexOf(u8, compare_report, "finding delta: +0") != null and
        std.mem.indexOf(u8, compare_report, "added events:\n- none") != null and
        std.mem.indexOf(u8, compare_report, "removed events:\n- none") != null and
        std.mem.indexOf(u8, compare_report, "changed events:\n- none") != null;
}

fn deterministicReplayVerdict(
    scenario: causal_run.Scenario,
    term: std.process.Child.Term,
    compare_report: []const u8,
) []const u8 {
    if (!commandMatchesScenarioExpectation(scenario, term)) return "command_failed";
    return if (compareReportMatched(compare_report)) "matched" else "changed";
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

fn appendOptionalJsonIsize(output: *std.ArrayList(u8), allocator: std.mem.Allocator, value: ?isize) !void {
    if (value) |number| {
        try output.print(allocator, "{d}", .{number});
    } else {
        try output.appendSlice(allocator, "null");
    }
}

fn appendOptionalIsizeText(output: *std.ArrayList(u8), allocator: std.mem.Allocator, value: ?isize) !void {
    if (value) |number| {
        try output.print(allocator, "{d}\n", .{number});
    } else {
        try output.appendSlice(allocator, "none\n");
    }
}

fn appendSignedDeltaListItem(output: *std.ArrayList(u8), allocator: std.mem.Allocator, label: []const u8, delta: isize) !void {
    if (delta >= 0) {
        try output.print(allocator, "- {s}: +{d}\n", .{ label, delta });
    } else {
        try output.print(allocator, "- {s}: {d}\n", .{ label, delta });
    }
}

fn appendOptionalSignedDeltaListItem(output: *std.ArrayList(u8), allocator: std.mem.Allocator, label: []const u8, delta: ?isize) !void {
    if (delta) |value| {
        try appendSignedDeltaListItem(output, allocator, label, value);
    } else {
        try output.print(allocator, "- {s}: none\n", .{label});
    }
}

fn appendStringListJson(output: *std.ArrayList(u8), allocator: std.mem.Allocator, items: []const []const u8) !void {
    try output.append(allocator, '[');
    for (items, 0..) |item, index| {
        if (index > 0) try output.append(allocator, ',');
        try appendJsonString(output, allocator, item);
    }
    try output.append(allocator, ']');
}

fn appendStringListText(output: *std.ArrayList(u8), allocator: std.mem.Allocator, items: []const []const u8) !void {
    if (items.len == 0) {
        try output.appendSlice(allocator, "- none\n");
        return;
    }
    for (items) |item| {
        try output.print(allocator, "- {s}\n", .{item});
    }
}

fn appendOwnedWarningsText(output: *std.ArrayList(u8), allocator: std.mem.Allocator, warnings: []const []const u8) !void {
    try output.appendSlice(allocator, "warnings:\n");
    if (warnings.len == 0) {
        try output.appendSlice(allocator, "- none\n");
        return;
    }
    try appendStringListText(output, allocator, warnings);
}

fn appendOwnedWarningFmt(
    allocator: std.mem.Allocator,
    warnings: *std.ArrayList([]const u8),
    comptime fmt: []const u8,
    args: anytype,
) !void {
    const warning = try std.fmt.allocPrint(allocator, fmt, args);
    errdefer allocator.free(warning);
    try warnings.append(allocator, warning);
}

fn freeOwnedStringList(allocator: std.mem.Allocator, items: *std.ArrayList([]const u8)) void {
    for (items.items) |item| allocator.free(item);
    items.deinit(allocator);
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
    return "usage: zig build causal-snapshot -- manifest <name> <artifact.json> [--format json|text] [--target <target>] [--phase <phase>] [--baseline <path>] [--compare-report <path>] [--query-report <path>] [--advice-report <path>]\n       zig build causal-snapshot -- capture <name> [scenario]\n       zig build causal-snapshot -- compare <left> <right>\n       zig build causal-snapshot -- audit-chain-compare <left> <right>\n       zig build causal-snapshot -- replay-feasibility <snapshot>\n       zig build causal-snapshot -- replay-scenario <snapshot> <scenario>\n       zig build causal-snapshot -- fork-proposal <snapshot> <scenario> <fork>\n";
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

fn runScenarioCommand(
    allocator: std.mem.Allocator,
    io: std.Io,
    scenario: causal_run.Scenario,
) !causal_run.CommandResult {
    const result = std.process.run(allocator, io, .{
        .argv = scenario.argv,
        .stdout_limit = .limited(64 * 1024),
        .stderr_limit = .limited(64 * 1024),
    }) catch |err| {
        return .{
            .term = .{ .unknown = 0 },
            .stdout = try allocator.dupe(u8, ""),
            .stderr = try allocator.dupe(u8, @errorName(err)),
        };
    };
    return .{
        .term = result.term,
        .stdout = result.stdout,
        .stderr = result.stderr,
    };
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

    if (std.mem.eql(u8, args[1], "audit-chain-compare")) {
        if (args.len != 4) failUsage(error.InvalidAuditChainSnapshotCompareArguments);
        const left_manifest_ref = try resolveSnapshotManifestReference(allocator, args[2]);
        defer left_manifest_ref.deinit(allocator);
        const right_manifest_ref = try resolveSnapshotManifestReference(allocator, args[3]);
        defer right_manifest_ref.deinit(allocator);

        const left_manifest_json = try std.Io.Dir.cwd().readFileAlloc(init.io, left_manifest_ref.path, allocator, .limited(1024 * 1024));
        defer allocator.free(left_manifest_json);
        const right_manifest_json = try std.Io.Dir.cwd().readFileAlloc(init.io, right_manifest_ref.path, allocator, .limited(1024 * 1024));
        defer allocator.free(right_manifest_json);

        const left_audit_chain_path = try snapshotArtifactPathFromManifestJson(allocator, left_manifest_json);
        defer allocator.free(left_audit_chain_path);
        const right_audit_chain_path = try snapshotArtifactPathFromManifestJson(allocator, right_manifest_json);
        defer allocator.free(right_audit_chain_path);

        const left_audit_chain_json = try std.Io.Dir.cwd().readFileAlloc(init.io, left_audit_chain_path, allocator, .limited(1024 * 1024));
        defer allocator.free(left_audit_chain_json);
        const right_audit_chain_json = try std.Io.Dir.cwd().readFileAlloc(init.io, right_audit_chain_path, allocator, .limited(1024 * 1024));
        defer allocator.free(right_audit_chain_json);

        const report = try formatAuditChainSnapshotCompareText(
            allocator,
            left_manifest_ref.path,
            left_manifest_json,
            left_audit_chain_json,
            right_manifest_ref.path,
            right_manifest_json,
            right_audit_chain_json,
        );
        defer allocator.free(report);
        std.debug.print("{s}", .{report});
        return;
    }

    if (std.mem.eql(u8, args[1], "replay-scenario")) {
        if (args.len != 4) failUsage(error.InvalidDeterministicReplayArguments);
        const manifest_ref = try resolveSnapshotManifestReference(allocator, args[2]);
        defer manifest_ref.deinit(allocator);
        const scenario = causal_run.scenarioByName(args[3]) catch |err| failUsage(err);

        const manifest_json = try std.Io.Dir.cwd().readFileAlloc(init.io, manifest_ref.path, allocator, .limited(1024 * 1024));
        defer allocator.free(manifest_json);
        const baseline_artifact_path = try snapshotArtifactPathFromManifestJson(allocator, manifest_json);
        defer allocator.free(baseline_artifact_path);
        const baseline_artifact_json = try std.Io.Dir.cwd().readFileAlloc(init.io, baseline_artifact_path, allocator, .limited(1024 * 1024));
        defer allocator.free(baseline_artifact_json);

        var manifest = try std.json.parseFromSlice(SnapshotManifestForCompare, allocator, manifest_json, .{ .ignore_unknown_fields = true });
        defer manifest.deinit();
        const replay_paths = try deterministicReplayArtifactPaths(allocator, manifest.value.name, scenario.slug);
        defer replay_paths.deinit(allocator);

        const result = try runScenarioCommand(allocator, init.io, scenario);
        defer allocator.free(result.stdout);
        defer allocator.free(result.stderr);

        const artifacts = try causal_run.buildCommandArtifacts(allocator, scenario, result);
        defer artifacts.deinit(allocator);
        try writeArtifact(init.io, replay_paths.report_path, artifacts.report);
        try writeArtifact(init.io, replay_paths.json_path, artifacts.json);
        try writeArtifact(init.io, replay_paths.dot_path, artifacts.dot);

        const report = try formatDeterministicReplayText(
            allocator,
            manifest_ref.path,
            manifest_json,
            baseline_artifact_json,
            scenario,
            replay_paths,
            result.term,
            artifacts.json,
        );
        defer allocator.free(report);
        std.debug.print("{s}", .{report});
        return;
    }

    if (std.mem.eql(u8, args[1], "fork-proposal")) {
        if (args.len != 5) failUsage(error.InvalidScenarioForkProposalArguments);
        const manifest_ref = try resolveSnapshotManifestReference(allocator, args[2]);
        defer manifest_ref.deinit(allocator);
        const scenario = causal_run.scenarioByName(args[3]) catch |err| failUsage(err);
        const fork_name = args[4];
        try validateSnapshotName(fork_name);

        const manifest_json = try std.Io.Dir.cwd().readFileAlloc(init.io, manifest_ref.path, allocator, .limited(1024 * 1024));
        defer allocator.free(manifest_json);
        var manifest = try std.json.parseFromSlice(SnapshotManifestForCompare, allocator, manifest_json, .{ .ignore_unknown_fields = true });
        defer manifest.deinit();

        const paths = try scenarioForkProposalPaths(allocator, manifest.value.name, scenario.slug, fork_name);
        defer paths.deinit(allocator);
        const json = try formatScenarioForkProposalJson(allocator, manifest_ref.path, manifest_json, scenario, fork_name);
        defer allocator.free(json);
        const text = try formatScenarioForkProposalText(allocator, manifest_ref.path, manifest_json, scenario, fork_name);
        defer allocator.free(text);

        try writeArtifact(init.io, paths.json_path, json);
        try writeArtifact(init.io, paths.text_path, text);
        std.debug.print("zigeffect causal scenario fork proposal written\njson: {s}\ntext: {s}\nreplay: zig build causal-snapshot -- replay-scenario {s} {s}\n", .{
            paths.json_path,
            paths.text_path,
            manifest.value.name,
            scenario.slug,
        });
        return;
    }

    if (std.mem.eql(u8, args[1], "replay-feasibility")) {
        if (args.len != 3) failUsage(error.InvalidReplayFeasibilityArguments);
        const manifest_ref = try resolveSnapshotManifestReference(allocator, args[2]);
        defer manifest_ref.deinit(allocator);

        const manifest_json = try std.Io.Dir.cwd().readFileAlloc(init.io, manifest_ref.path, allocator, .limited(1024 * 1024));
        defer allocator.free(manifest_json);
        const artifact_path = try snapshotArtifactPathFromManifestJson(allocator, manifest_json);
        defer allocator.free(artifact_path);
        const artifact_json = try std.Io.Dir.cwd().readFileAlloc(init.io, artifact_path, allocator, .limited(1024 * 1024));
        defer allocator.free(artifact_json);

        const report = try formatReplayFeasibilityText(allocator, manifest_ref.path, manifest_json, artifact_json);
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

const replay_manifest_json =
    \\{
    \\  "schema": "zigeffect.causal.snapshot-manifest.v1",
    \\  "schema_version": 1,
    \\  "name": "baseline",
    \\  "target": "dogfood",
    \\  "phase": "captured",
    \\  "artifact": {
    \\    "path": ".zig-cache/causal-artifacts/replay.json",
    \\    "schema": "zigeffect.causal.v1",
    \\    "schema_version": 1,
    \\    "event_taxonomy_version": 1,
    \\    "events": 7,
    \\    "first_event_id": 1,
    \\    "last_event_id": 7,
    \\    "findings": 4
    \\  },
    \\  "warnings": []
    \\}
;

const audit_chain_left_manifest_json =
    \\{
    \\  "schema": "zigeffect.causal.snapshot-manifest.v1",
    \\  "schema_version": 1,
    \\  "name": "left-chain",
    \\  "target": "dogfood",
    \\  "phase": "audit-chain-baseline",
    \\  "artifact": {
    \\    "path": ".zig-cache/causal-artifacts/left-audit-chain.json",
    \\    "schema": "zigeffect.causal.audit-chain.v1",
    \\    "schema_version": 1,
    \\    "events": 0,
    \\    "first_event_id": null,
    \\    "last_event_id": null,
    \\    "findings": 1
    \\  },
    \\  "warnings": []
    \\}
;

const audit_chain_right_manifest_json =
    \\{
    \\  "schema": "zigeffect.causal.snapshot-manifest.v1",
    \\  "schema_version": 1,
    \\  "name": "right-chain",
    \\  "target": "dogfood",
    \\  "phase": "audit-chain-after",
    \\  "artifact": {
    \\    "path": ".zig-cache/causal-artifacts/right-audit-chain.json",
    \\    "schema": "zigeffect.causal.audit-chain.v1",
    \\    "schema_version": 1,
    \\    "events": 0,
    \\    "first_event_id": null,
    \\    "last_event_id": null,
    \\    "findings": 0
    \\  },
    \\  "warnings": []
    \\}
;

const audit_chain_left_json =
    \\{
    \\  "schema": "zigeffect.causal.audit-chain.v1",
    \\  "schema_version": 1,
    \\  "mode": "local",
    \\  "target": "dogfood",
    \\  "assessment": "unchanged",
    \\  "proposal_status": "approved",
    \\  "approval_status": "approved",
    \\  "approved": true,
    \\  "applied": false,
    \\  "finding_delta": 0,
    \\  "event_ids": [1, 2, 3, 5],
    \\  "disappeared_event_ids": [1],
    \\  "persisting_event_ids": [2],
    \\  "appeared_event_ids": [3],
    \\  "missing_event_ids": [5],
    \\  "verification_commands": ["zig build examples"],
    \\  "claim_guardrails": ["Do not claim a fix while evidence persists."],
    \\  "proposal_guardrails": ["This proposal does not apply source changes."],
    \\  "chain_guardrails": ["Chain comparison is evidence, not authorization to edit source."]
    \\}
;

const audit_chain_right_json =
    \\{
    \\  "schema": "zigeffect.causal.audit-chain.v1",
    \\  "schema_version": 1,
    \\  "mode": "local",
    \\  "target": "dogfood",
    \\  "assessment": "improved",
    \\  "proposal_status": "approved",
    \\  "approval_status": "approved",
    \\  "approved": true,
    \\  "applied": false,
    \\  "finding_delta": -1,
    \\  "event_ids": [1, 2, 3],
    \\  "disappeared_event_ids": [1, 2],
    \\  "persisting_event_ids": [],
    \\  "appeared_event_ids": [3],
    \\  "missing_event_ids": [],
    \\  "verification_commands": ["zig build examples", "zig build test"],
    \\  "claim_guardrails": ["Do not claim a fix while evidence persists."],
    \\  "proposal_guardrails": ["This proposal does not apply source changes."],
    \\  "chain_guardrails": ["Chain comparison is evidence, not authorization to edit source."]
    \\}
;

const replay_artifact_json =
    \\{
    \\  "schema": "zigeffect.causal.v1",
    \\  "schema_version": 1,
    \\  "event_taxonomy_version": 1,
    \\  "events": [
    \\    {"id":1,"kind":"run_started","run_id":1,"parent_id":null,"fiber_id":null,"scope_id":null,"trace_id":null,"span_id":null,"label":"scenario","type_name":"Command","status":"started","redacted_detail":""},
    \\    {"id":2,"kind":"service_required","run_id":1,"parent_id":1,"fiber_id":null,"scope_id":null,"trace_id":null,"span_id":null,"label":"Config","type_name":"Config","status":"missing","redacted_detail":"missing provider"},
    \\    {"id":3,"kind":"resource_acquired","run_id":1,"parent_id":1,"fiber_id":null,"scope_id":10,"trace_id":null,"span_id":null,"label":"db","type_name":"Resource","status":"acquired","redacted_detail":"<redacted>"},
    \\    {"id":4,"kind":"fiber_forked","run_id":1,"parent_id":1,"fiber_id":20,"scope_id":10,"trace_id":null,"span_id":null,"label":"worker","type_name":"Fiber","status":"pending","redacted_detail":""},
    \\    {"id":5,"kind":"schedule_decision","run_id":1,"parent_id":1,"fiber_id":null,"scope_id":null,"trace_id":null,"span_id":null,"label":"retry","type_name":"Schedule.exponential","status":"exhausted","redacted_detail":"budget exhausted"},
    \\    {"id":6,"kind":"log_recorded","run_id":1,"parent_id":1,"fiber_id":null,"scope_id":null,"trace_id":null,"span_id":null,"label":"logger","type_name":"Logger","status":"info","redacted_detail":"hello"},
    \\    {"id":7,"kind":"effect_suspended","run_id":1,"parent_id":1,"fiber_id":null,"scope_id":null,"trace_id":null,"span_id":null,"label":"future","type_name":"Command","status":"pending","redacted_detail":"<truncated>"}
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

test "snapshot manifest json supports audit-chain artifacts" {
    const manifest = try formatSnapshotManifestJson(std.testing.allocator, audit_chain_left_json, .{
        .name = "left-chain",
        .target = "dogfood",
        .phase = "audit-chain-baseline",
        .artifact_path = ".zig-cache/causal-artifacts/left-audit-chain.json",
    });
    defer std.testing.allocator.free(manifest);

    try std.testing.expect(std.mem.indexOf(u8, manifest, "\"schema\":\"zigeffect.causal.snapshot-manifest.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, manifest, "\"name\":\"left-chain\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, manifest, "\"schema\":\"zigeffect.causal.audit-chain.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, manifest, "\"events\":0") != null);
    try std.testing.expect(std.mem.indexOf(u8, manifest, "audit-chain-compare left-chain left-chain") != null);
    try std.testing.expect(std.mem.indexOf(u8, manifest, "causal-query -- --file") == null);
}

test "snapshot manifest text supports audit-chain artifacts" {
    const report = try formatSnapshotManifestText(std.testing.allocator, audit_chain_left_json, .{
        .name = "left-chain",
        .target = "dogfood",
        .phase = "audit-chain-baseline",
        .artifact_path = ".zig-cache/causal-artifacts/left-audit-chain.json",
    });
    defer std.testing.allocator.free(report);

    try std.testing.expect(std.mem.indexOf(u8, report, "artifact schema: zigeffect.causal.audit-chain.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "events: 0") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zig build causal-snapshot -- audit-chain-compare left-chain left-chain") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "causal-query -- --file") == null);
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

test "deterministic replay artifact paths include snapshot and scenario" {
    const paths = try deterministicReplayArtifactPaths(std.testing.allocator, "scoped-baseline", "causal-scoped-fiber");
    defer paths.deinit(std.testing.allocator);

    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-replay-scoped-baseline-causal-scoped-fiber.txt",
        paths.report_path,
    );
    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-replay-scoped-baseline-causal-scoped-fiber.json",
        paths.json_path,
    );
    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-replay-scoped-baseline-causal-scoped-fiber.dot",
        paths.dot_path,
    );
}

test "deterministic replay report states registered rerun boundary" {
    const scenario = try causal_run.scenarioByName("causal-scoped-fiber");
    const paths = try deterministicReplayArtifactPaths(std.testing.allocator, "scoped-baseline", scenario.slug);
    defer paths.deinit(std.testing.allocator);

    const report = try formatDeterministicReplayText(
        std.testing.allocator,
        ".zig-cache/causal-artifacts/zigeffect-causal-snapshot-scoped-baseline.json",
        baseline_manifest_json,
        compare_before_json,
        scenario,
        paths,
        .{ .exited = 0 },
        compare_before_json,
    );
    defer std.testing.allocator.free(report);

    try std.testing.expect(std.mem.indexOf(u8, report, "schema: zigeffect.causal.deterministic-replay.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "mode: registered_scenario_rerun") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "executed: true") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "arbitrary event replay: false") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "scenario: causal-scoped-fiber") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "command status: success") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "boundary:") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "event compare:") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zigeffect causal compare report") != null);
}

test "deterministic replay report marks command expectation mismatch" {
    const scenario = try causal_run.scenarioByName("causal-scoped-fiber");
    const paths = try deterministicReplayArtifactPaths(std.testing.allocator, "scoped-baseline", scenario.slug);
    defer paths.deinit(std.testing.allocator);

    const report = try formatDeterministicReplayText(
        std.testing.allocator,
        ".zig-cache/causal-artifacts/zigeffect-causal-snapshot-scoped-baseline.json",
        baseline_manifest_json,
        compare_before_json,
        scenario,
        paths,
        .{ .exited = 1 },
        compare_after_json,
    );
    defer std.testing.allocator.free(report);

    try std.testing.expect(std.mem.indexOf(u8, report, "command status: failure") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "verdict: command_failed") != null);
}

test "scenario fork proposal paths include snapshot scenario and fork" {
    const paths = try scenarioForkProposalPaths(std.testing.allocator, "missing-service-baseline", "missing-service-compile-fail", "missing-service-fork");
    defer paths.deinit(std.testing.allocator);

    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-fork-proposal-missing-service-baseline-missing-service-compile-fail-missing-service-fork.json",
        paths.json_path,
    );
    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-fork-proposal-missing-service-baseline-missing-service-compile-fail-missing-service-fork.txt",
        paths.text_path,
    );
}

test "scenario fork proposal json is draft non executing evidence" {
    const scenario = try causal_run.scenarioByName("missing-service-compile-fail");
    const json = try formatScenarioForkProposalJson(
        std.testing.allocator,
        ".zig-cache/causal-artifacts/zigeffect-causal-snapshot-missing-service-baseline.json",
        baseline_manifest_json,
        scenario,
        "missing-service-fork",
    );
    defer std.testing.allocator.free(json);

    try std.testing.expect(std.mem.indexOf(u8, json, "\"schema\":\"zigeffect.causal.scenario-fork-proposal.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"mode\":\"registered_scenario_fork_proposal\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"proposal_status\":\"draft\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"approved\":false") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"executed\":false") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"fork_name\":\"missing-service-fork\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"scenario\":{\"slug\":\"missing-service-compile-fail\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "replay-scenario baseline missing-service-compile-fail") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "runtime memory forking") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "arbitrary causal event-log replay") != null);
}

test "scenario fork proposal text states review boundary" {
    const scenario = try causal_run.scenarioByName("missing-service-compile-fail");
    const text = try formatScenarioForkProposalText(
        std.testing.allocator,
        ".zig-cache/causal-artifacts/zigeffect-causal-snapshot-missing-service-baseline.json",
        baseline_manifest_json,
        scenario,
        "missing-service-fork",
    );
    defer std.testing.allocator.free(text);

    try std.testing.expect(std.mem.indexOf(u8, text, "zigeffect causal scenario fork proposal") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "mode: registered_scenario_fork_proposal") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "approved: false") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "executed: false") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "blocked operations:") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "Fork proposal does not execute commands.") != null);
}

test "causal snapshot usage lists fork proposal command" {
    try std.testing.expect(std.mem.indexOf(u8, usage(), "fork-proposal <snapshot> <scenario> <fork>") != null);
}

test "causal snapshot usage lists replay scenario command" {
    try std.testing.expect(std.mem.indexOf(u8, usage(), "replay-scenario <snapshot> <scenario>") != null);
}

test "causal snapshot usage lists audit-chain compare command" {
    try std.testing.expect(std.mem.indexOf(u8, usage(), "audit-chain-compare <left> <right>") != null);
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

test "audit-chain snapshot compare json summarizes two retained chain states" {
    const json = try formatAuditChainSnapshotCompareJson(
        std.testing.allocator,
        ".zig-cache/causal-artifacts/zigeffect-causal-snapshot-left-chain.json",
        audit_chain_left_manifest_json,
        audit_chain_left_json,
        ".zig-cache/causal-artifacts/zigeffect-causal-snapshot-right-chain.json",
        audit_chain_right_manifest_json,
        audit_chain_right_json,
    );
    defer std.testing.allocator.free(json);

    try std.testing.expect(std.mem.indexOf(u8, json, "\"schema\":\"zigeffect.causal.audit-chain-snapshot-compare.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"status\":\"ready\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"comparison\":\"improved\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"finding_delta_delta\":-1") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"persisting_delta\":-1") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"missing_delta\":-1") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"left-chain\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"right-chain\"") != null);
}

test "audit-chain snapshot compare text reports status deltas and next queries" {
    const report = try formatAuditChainSnapshotCompareText(
        std.testing.allocator,
        ".zig-cache/causal-artifacts/zigeffect-causal-snapshot-left-chain.json",
        audit_chain_left_manifest_json,
        audit_chain_left_json,
        ".zig-cache/causal-artifacts/zigeffect-causal-snapshot-right-chain.json",
        audit_chain_right_manifest_json,
        audit_chain_right_json,
    );
    defer std.testing.allocator.free(report);

    try std.testing.expect(std.mem.indexOf(u8, report, "zigeffect causal audit-chain snapshot compare report") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "schema: zigeffect.causal.audit-chain-snapshot-compare.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "status: ready") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "comparison: improved") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "left snapshot: left-chain") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "right snapshot: right-chain") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "deltas:") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "next queries:") != null);
}

test "audit-chain snapshot compare blocks already applied right chain" {
    const applied_right = try std.mem.replaceOwned(
        u8,
        std.testing.allocator,
        audit_chain_right_json,
        "\"applied\": false",
        "\"applied\": true",
    );
    defer std.testing.allocator.free(applied_right);

    const json = try formatAuditChainSnapshotCompareJson(
        std.testing.allocator,
        ".zig-cache/causal-artifacts/zigeffect-causal-snapshot-left-chain.json",
        audit_chain_left_manifest_json,
        audit_chain_left_json,
        ".zig-cache/causal-artifacts/zigeffect-causal-snapshot-right-chain.json",
        audit_chain_right_manifest_json,
        applied_right,
    );
    defer std.testing.allocator.free(json);

    try std.testing.expect(std.mem.indexOf(u8, json, "\"status\":\"blocked\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"comparison\":\"inconclusive\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "right audit-chain applied=true requires reviewed application evidence") != null);
}

test "replay feasibility report refuses replay and counts event posture" {
    const report = try formatReplayFeasibilityText(
        std.testing.allocator,
        ".zig-cache/causal-artifacts/zigeffect-causal-snapshot-baseline.json",
        replay_manifest_json,
        replay_artifact_json,
    );
    defer std.testing.allocator.free(report);

    try std.testing.expect(std.mem.indexOf(u8, report, "zigeffect causal replay feasibility report") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "schema: zigeffect.causal.replay-feasibility.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "snapshot: baseline") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "artifact: .zig-cache/causal-artifacts/replay.json") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "feasible: false") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "reason: snapshot manifest references observed causal artifact only") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "events: 7") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "structural events: 5") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "finding evidence events: 4") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "sampleable events: 1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "unknown events: 1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "redacted detail events: 1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "truncated detail events: 1") != null);
}

test "replay feasibility report names blockers and event posture sample" {
    const report = try formatReplayFeasibilityText(
        std.testing.allocator,
        ".zig-cache/causal-artifacts/zigeffect-causal-snapshot-baseline.json",
        replay_manifest_json,
        replay_artifact_json,
    );
    defer std.testing.allocator.free(report);

    try std.testing.expect(std.mem.indexOf(u8, report, "blocking reasons:") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "snapshot manifest references observed artifacts, not executable programs") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "service values/providers are not serialized") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "resource constructors/finalizers are not serialized") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "scheduler state and fiber closures are not serialized") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "schedule timing and randomness decisions are observations, not replay inputs") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "logs, metrics, and spans may be sampled") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "unknown event taxonomy prevents complete replay classification") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "redacted or truncated detail prevents faithful replay evidence") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "event id=1 kind=run_started posture=structural_observation") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "event id=2 kind=service_required posture=finding_evidence_observation") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "event id=6 kind=log_recorded posture=sampleable_observation") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "event id=7 kind=effect_suspended posture=unknown_taxonomy") != null);
}

test "replay feasibility event posture sample is bounded" {
    var artifact = std.ArrayList(u8).empty;
    defer artifact.deinit(std.testing.allocator);
    try artifact.appendSlice(std.testing.allocator, "{\"events\":[");
    for (1..22) |id| {
        if (id > 1) try artifact.append(std.testing.allocator, ',');
        try artifact.print(std.testing.allocator, "{{\"id\":{d},\"kind\":\"run_started\",\"run_id\":1,\"parent_id\":null,\"fiber_id\":null,\"scope_id\":null,\"trace_id\":null,\"span_id\":null,\"label\":\"event\",\"type_name\":\"Command\",\"status\":\"started\",\"redacted_detail\":\"\"}}", .{id});
    }
    try artifact.appendSlice(std.testing.allocator, "]}");

    const report = try formatReplayFeasibilityText(
        std.testing.allocator,
        ".zig-cache/causal-artifacts/zigeffect-causal-snapshot-baseline.json",
        replay_manifest_json,
        artifact.items,
    );
    defer std.testing.allocator.free(report);

    try std.testing.expect(std.mem.indexOf(u8, report, "event posture sample limit: 20") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "event id=20 kind=run_started") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "event id=21 kind=run_started") == null);
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
