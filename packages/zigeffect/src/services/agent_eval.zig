const std = @import("std");
const causal = @import("causal.zig");
const agent_intervention = @import("agent_intervention.zig");
const counterfactual = @import("counterfactual.zig");
const causal_diff = @import("causal_diff.zig");
const causal_invariant = @import("causal_invariant.zig");

pub const agent_eval_diff_artifact_schema = "zigeffect.causal.agent-eval-diff.v1";
pub const agent_eval_diff_artifact_schema_version: u32 = 1;
pub const agent_eval_diff_artifact_link_schema = "zigeffect.causal.agent-eval-diff-link.v1";
pub const agent_eval_diff_artifact_link_schema_version: u32 = 1;
pub const agent_eval_linked_diff_manifest_schema = "zigeffect.causal.agent-eval-linked-manifest.v1";
pub const agent_eval_linked_diff_manifest_schema_version: u32 = 1;

pub const AgentEvalOptions = struct {
    name: []const u8,
    baseline: []const causal.CausalEvent,
    policy: agent_intervention.AgentInterventionPolicy,
    request: agent_intervention.AgentInterventionRequest,
    invariants: causal_invariant.CausalInvariantBuilder = .{},
    expect_improvement: bool = true,
};

pub const AgentEvalResult = struct {
    passed: bool,
    counterfactual: counterfactual.CounterfactualResult,
    diff_summary: causal_diff.CausalGraphDiffSummary,
    invariant_violations: usize,
};

pub const AgentEvalDiffArtifact = struct {
    allocator: std.mem.Allocator,
    result: AgentEvalResult,
    json: []const u8,

    pub fn deinit(self: *AgentEvalDiffArtifact) void {
        if (self.json.len > 0) self.allocator.free(self.json);
        self.json = "";
    }
};

pub const AgentEvalDiffArtifactSink = struct {
    state: ?*anyopaque = null,
    write: *const fn (?*anyopaque, json: []const u8) anyerror!void,
};

pub const AgentEvalDiffArtifactLinkOptions = struct {
    eval_name: []const u8,
    artifact_path: []const u8,
    artifact_id: []const u8 = "",
    result: AgentEvalResult,
};

pub const AgentEvalDiffArtifactLinkWriteOptions = struct {
    artifact_path: []const u8,
    artifact_id: []const u8 = "",
};

pub const AgentEvalLinkedDiffArtifactWriteOptions = struct {
    diff_artifact_path: []const u8,
    diff_artifact_id: []const u8 = "",
    link_artifact_path: []const u8,
    link_artifact_id: []const u8 = "",
};

pub const AgentEvalLinkedDiffManifestOptions = struct {
    eval_name: []const u8,
    diff_artifact_path: []const u8,
    link_artifact_path: []const u8,
    diff_artifact_id: []const u8 = "",
    link_artifact_id: []const u8 = "",
    result: AgentEvalResult,
};

fn replayEvents(store: *causal.CausalStore, events: []const causal.CausalEvent) std.mem.Allocator.Error!void {
    for (events) |event| {
        _ = try store.record(event);
    }
}

pub fn runAgentEval(allocator: std.mem.Allocator, options: AgentEvalOptions) std.mem.Allocator.Error!AgentEvalResult {
    _ = options.name;
    const cf = try counterfactual.runCounterfactual(allocator, options.baseline, options.policy, options.request);

    var after = causal.CausalStore.init(allocator);
    defer after.deinit();
    try replayEvents(&after, options.baseline);
    _ = try agent_intervention.applyAgentIntervention(&after, options.policy, options.request);

    var after_snapshot = try after.snapshot(allocator);
    defer after_snapshot.deinit();
    var invariant_check = try options.invariants.check(allocator, after_snapshot.events);
    defer invariant_check.deinit();

    const improvement_ok = if (options.expect_improvement) cf.improved else cf.finding_delta <= 0;
    return .{
        .passed = cf.intervention.applied and improvement_ok and invariant_check.violations.len == 0,
        .counterfactual = cf,
        .diff_summary = cf.diff_summary,
        .invariant_violations = invariant_check.violations.len,
    };
}

pub fn runAgentEvalWithDiffArtifact(
    allocator: std.mem.Allocator,
    options: AgentEvalOptions,
    before_artifact: []const u8,
    after_artifact: []const u8,
) std.mem.Allocator.Error!AgentEvalDiffArtifact {
    const result = try runAgentEval(allocator, options);
    const semantic_diff_json = try buildEvalSemanticDiffJson(allocator, options, before_artifact, after_artifact);
    defer allocator.free(semantic_diff_json);

    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "{\"schema\":");
    try appendJsonString(&output, allocator, agent_eval_diff_artifact_schema);
    try output.print(allocator, ",\"schema_version\":{d}", .{agent_eval_diff_artifact_schema_version});
    try output.appendSlice(allocator, ",\"eval_name\":");
    try appendJsonString(&output, allocator, options.name);
    try output.print(allocator, ",\"passed\":{s}", .{if (result.passed) "true" else "false"});
    try output.print(allocator, ",\"invariant_violations\":{d}", .{result.invariant_violations});
    try output.appendSlice(allocator, ",\"remediation_event_ids\":{");
    try output.appendSlice(allocator, "\"requested\":");
    try appendOptionalU64(&output, allocator, result.counterfactual.intervention.requested_event_id);
    try output.appendSlice(allocator, ",\"decided\":");
    try appendOptionalU64(&output, allocator, result.counterfactual.intervention.decided_event_id);
    try output.appendSlice(allocator, ",\"applied\":");
    try appendOptionalU64(&output, allocator, result.counterfactual.intervention.applied_event_id);
    try output.appendSlice(allocator, ",\"effect\":");
    try appendOptionalU64(&output, allocator, result.counterfactual.intervention.effect_event_id);
    try output.appendSlice(allocator, "},\"semantic_diff\":");
    try output.appendSlice(allocator, semantic_diff_json);
    try output.appendSlice(allocator, "}");

    return .{
        .allocator = allocator,
        .result = result,
        .json = try output.toOwnedSlice(allocator),
    };
}

pub fn runAgentEvalAndWriteDiffArtifact(
    allocator: std.mem.Allocator,
    options: AgentEvalOptions,
    before_artifact: []const u8,
    after_artifact: []const u8,
    sink: AgentEvalDiffArtifactSink,
) anyerror!AgentEvalResult {
    var artifact = try runAgentEvalWithDiffArtifact(allocator, options, before_artifact, after_artifact);
    defer artifact.deinit();
    try sink.write(sink.state, artifact.json);
    return artifact.result;
}

pub fn runAgentEvalAndWriteLinkedDiffArtifact(
    allocator: std.mem.Allocator,
    options: AgentEvalOptions,
    before_artifact: []const u8,
    after_artifact: []const u8,
    link_options: AgentEvalDiffArtifactLinkWriteOptions,
    artifact_sink: AgentEvalDiffArtifactSink,
    link_sink: AgentEvalDiffArtifactSink,
) anyerror!AgentEvalResult {
    var artifact = try runAgentEvalWithDiffArtifact(allocator, options, before_artifact, after_artifact);
    defer artifact.deinit();
    try artifact_sink.write(artifact_sink.state, artifact.json);

    const link = try formatAgentEvalDiffArtifactLinkJson(allocator, .{
        .eval_name = options.name,
        .artifact_path = link_options.artifact_path,
        .artifact_id = link_options.artifact_id,
        .result = artifact.result,
    });
    defer allocator.free(link);
    try link_sink.write(link_sink.state, link);

    return artifact.result;
}

pub fn runAgentEvalAndWriteLinkedDiffManifest(
    allocator: std.mem.Allocator,
    options: AgentEvalOptions,
    before_artifact: []const u8,
    after_artifact: []const u8,
    write_options: AgentEvalLinkedDiffArtifactWriteOptions,
    artifact_sink: AgentEvalDiffArtifactSink,
    link_sink: AgentEvalDiffArtifactSink,
    manifest_sink: AgentEvalDiffArtifactSink,
) anyerror!AgentEvalResult {
    var artifact = try runAgentEvalWithDiffArtifact(allocator, options, before_artifact, after_artifact);
    defer artifact.deinit();
    try artifact_sink.write(artifact_sink.state, artifact.json);

    const link = try formatAgentEvalDiffArtifactLinkJson(allocator, .{
        .eval_name = options.name,
        .artifact_path = write_options.diff_artifact_path,
        .artifact_id = write_options.diff_artifact_id,
        .result = artifact.result,
    });
    defer allocator.free(link);
    try link_sink.write(link_sink.state, link);

    const manifest = try formatAgentEvalLinkedDiffManifestJson(allocator, .{
        .eval_name = options.name,
        .diff_artifact_path = write_options.diff_artifact_path,
        .link_artifact_path = write_options.link_artifact_path,
        .diff_artifact_id = write_options.diff_artifact_id,
        .link_artifact_id = write_options.link_artifact_id,
        .result = artifact.result,
    });
    defer allocator.free(manifest);
    try manifest_sink.write(manifest_sink.state, manifest);

    return artifact.result;
}

pub fn formatAgentEvalDiffArtifactLinkJson(
    allocator: std.mem.Allocator,
    options: AgentEvalDiffArtifactLinkOptions,
) std.mem.Allocator.Error![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "{\"schema\":");
    try appendJsonString(&output, allocator, agent_eval_diff_artifact_link_schema);
    try output.print(allocator, ",\"schema_version\":{d}", .{agent_eval_diff_artifact_link_schema_version});
    try output.appendSlice(allocator, ",\"eval_name\":");
    try appendJsonString(&output, allocator, options.eval_name);
    try output.appendSlice(allocator, ",\"artifact_path\":");
    try appendJsonString(&output, allocator, options.artifact_path);
    try output.appendSlice(allocator, ",\"artifact_id\":");
    try appendJsonString(&output, allocator, options.artifact_id);
    try output.print(allocator, ",\"passed\":{s}", .{if (options.result.passed) "true" else "false"});
    try output.appendSlice(allocator, ",\"remediation_event_ids\":{");
    try output.appendSlice(allocator, "\"requested\":");
    try appendOptionalU64(&output, allocator, options.result.counterfactual.intervention.requested_event_id);
    try output.appendSlice(allocator, ",\"decided\":");
    try appendOptionalU64(&output, allocator, options.result.counterfactual.intervention.decided_event_id);
    try output.appendSlice(allocator, ",\"applied\":");
    try appendOptionalU64(&output, allocator, options.result.counterfactual.intervention.applied_event_id);
    try output.appendSlice(allocator, ",\"effect\":");
    try appendOptionalU64(&output, allocator, options.result.counterfactual.intervention.effect_event_id);
    try output.appendSlice(allocator, "},\"diff_summary\":{");
    try output.print(allocator, "\"resolved_findings\":{d}", .{options.result.diff_summary.resolved_findings});
    try output.print(allocator, ",\"introduced_findings\":{d}", .{options.result.diff_summary.introduced_findings});
    try output.appendSlice(allocator, "}}");

    return output.toOwnedSlice(allocator);
}

pub fn formatAgentEvalLinkedDiffManifestJson(
    allocator: std.mem.Allocator,
    options: AgentEvalLinkedDiffManifestOptions,
) std.mem.Allocator.Error![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "{\"schema\":");
    try appendJsonString(&output, allocator, agent_eval_linked_diff_manifest_schema);
    try output.print(allocator, ",\"schema_version\":{d}", .{agent_eval_linked_diff_manifest_schema_version});
    try output.appendSlice(allocator, ",\"eval_name\":");
    try appendJsonString(&output, allocator, options.eval_name);
    try output.print(allocator, ",\"passed\":{s}", .{if (options.result.passed) "true" else "false"});
    try output.appendSlice(allocator, ",\"diff_artifact_path\":");
    try appendJsonString(&output, allocator, options.diff_artifact_path);
    try output.appendSlice(allocator, ",\"link_artifact_path\":");
    try appendJsonString(&output, allocator, options.link_artifact_path);
    try output.appendSlice(allocator, ",\"artifacts\":{");
    try output.appendSlice(allocator, "\"diff\":{\"path\":");
    try appendJsonString(&output, allocator, options.diff_artifact_path);
    try output.appendSlice(allocator, ",\"id\":");
    try appendJsonString(&output, allocator, options.diff_artifact_id);
    try output.appendSlice(allocator, "},\"link\":{\"path\":");
    try appendJsonString(&output, allocator, options.link_artifact_path);
    try output.appendSlice(allocator, ",\"id\":");
    try appendJsonString(&output, allocator, options.link_artifact_id);
    try output.appendSlice(allocator, "}},\"remediation_event_ids\":{");
    try output.appendSlice(allocator, "\"requested\":");
    try appendOptionalU64(&output, allocator, options.result.counterfactual.intervention.requested_event_id);
    try output.appendSlice(allocator, ",\"decided\":");
    try appendOptionalU64(&output, allocator, options.result.counterfactual.intervention.decided_event_id);
    try output.appendSlice(allocator, ",\"applied\":");
    try appendOptionalU64(&output, allocator, options.result.counterfactual.intervention.applied_event_id);
    try output.appendSlice(allocator, ",\"effect\":");
    try appendOptionalU64(&output, allocator, options.result.counterfactual.intervention.effect_event_id);
    try output.appendSlice(allocator, "}}");

    return output.toOwnedSlice(allocator);
}

fn buildEvalSemanticDiffJson(
    allocator: std.mem.Allocator,
    options: AgentEvalOptions,
    before_artifact: []const u8,
    after_artifact: []const u8,
) std.mem.Allocator.Error![]const u8 {
    var before = causal.CausalStore.init(allocator);
    defer before.deinit();
    try replayEvents(&before, options.baseline);

    var after = causal.CausalStore.init(allocator);
    defer after.deinit();
    try replayEvents(&after, options.baseline);
    _ = try agent_intervention.applyAgentIntervention(&after, options.policy, options.request);

    var before_snapshot = try before.snapshot(allocator);
    defer before_snapshot.deinit();
    var after_snapshot = try after.snapshot(allocator);
    defer after_snapshot.deinit();

    var diff = try causal_diff.diffCausalGraphs(allocator, before_snapshot.events, after_snapshot.events);
    defer diff.deinit();
    return causal_diff.formatCausalGraphDiffJson(allocator, diff, before_artifact, after_artifact);
}

fn appendOptionalU64(output: *std.ArrayList(u8), allocator: std.mem.Allocator, value: ?u64) std.mem.Allocator.Error!void {
    if (value) |number| {
        try output.print(allocator, "{d}", .{number});
    } else {
        try output.appendSlice(allocator, "null");
    }
}

fn appendJsonString(output: *std.ArrayList(u8), allocator: std.mem.Allocator, value: []const u8) std.mem.Allocator.Error!void {
    try output.append(allocator, '"');
    for (value) |byte| {
        switch (byte) {
            '"' => try output.appendSlice(allocator, "\\\""),
            '\\' => try output.appendSlice(allocator, "\\\\"),
            '\n' => try output.appendSlice(allocator, "\\n"),
            '\r' => try output.appendSlice(allocator, "\\r"),
            '\t' => try output.appendSlice(allocator, "\\t"),
            0x00...0x08, 0x0b, 0x0c, 0x0e...0x1f => try output.print(allocator, "\\u{x:0>4}", .{byte}),
            else => try output.append(allocator, byte),
        }
    }
    try output.append(allocator, '"');
}
