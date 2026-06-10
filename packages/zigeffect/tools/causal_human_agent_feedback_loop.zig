const std = @import("std");

pub const feedback_loop_schema = "zigeffect.causal.human-agent-feedback-loop.v1";
pub const feedback_loop_schema_version: u32 = 1;
pub const source_branch = "codex/zigeffect-causal-human-agent-feedback-loop";
pub const next_branch = "codex/zigeffect-causal-rollout-automation-guardrails";

const OutputFormat = enum { text, json };

const generated_by = "causal-human-agent-feedback-loop";
const mode = "local-record";
const mutation_authority = "none";
const durable_target = "future-nendb-adapter";

const SurfaceContract = struct {
    human_surface: []const u8,
    agent_surface: []const u8,
    durable_target: []const u8,
    workbench_mutation: bool,
    agent_mutation: bool,
};

const LoopStage = struct {
    id: []const u8,
    title: []const u8,
    status: []const u8,
    consumes: []const []const u8,
    produces: []const []const u8,
    human_action: []const u8,
    agent_action: []const u8,
    commands: []const []const u8,
    evidence_refs: []const []const u8,
    guardrails: []const []const u8,
};

const RegressionCluster = struct {
    id: []const u8,
    pattern_signature: []const u8,
    status: []const u8,
    evidence_refs: []const []const u8,
    learning_priority: []const u8,
    durable_target: []const u8,
};

const GuardedHandoff = struct {
    id: []const u8,
    status: []const u8,
    consumes: []const []const u8,
    produces: []const []const u8,
    required_boundary: []const u8,
    mutation_authority: []const u8,
    applied: bool,
};

const DurableHistoryHandoff = struct {
    id: []const u8,
    status: []const u8,
    target: []const u8,
    writes_now: bool,
    required_fields: []const []const u8,
    policy_constraints: []const []const u8,
};

const surface_contract = SurfaceContract{
    .human_surface = "solidjs-webui-workbench",
    .agent_surface = "causal-query-agent-json",
    .durable_target = durable_target,
    .workbench_mutation = false,
    .agent_mutation = false,
};

const loop_stages: []const LoopStage = &.{
    .{
        .id = "failure-to-query",
        .title = "Failure To Query",
        .status = "ready",
        .consumes = &.{
            "zigeffect.causal.v1",
            "zigeffect.causal.workbench-session.v1",
            "zigeffect.causal.ci-verdict.v1",
            "zigeffect.causal.dev-loop-verdict.v1",
        },
        .produces = &.{"zigeffect.causal.agent-query.v1"},
        .human_action = "select failed event or Visual Graph node in the read-only SolidJS WebUI workbench",
        .agent_action = "run bounded causal-query commands and cite event ids before proposing edits",
        .commands = &.{
            "zig build causal-query -- --agent --file <artifact.json> explain_event <event_id>",
            "zig build causal-query -- --agent --file <artifact.json> trace_cause <event_id>",
            "zig build causal-query -- --agent --file <artifact.json> next_queries 3",
            "zig build causal-query -- --agent --file <artifact.json> trace_data <data_subject_ref>",
        },
        .evidence_refs = &.{
            ".zig-cache/causal-artifacts/<scenario>.json",
            ".zig-cache/causal-artifacts/zigeffect-causal-ci-verdict.json",
            ".zig-cache/causal-artifacts/<scenario>-workbench-session.json",
        },
        .guardrails = &.{ "read-only", "bounded", "redacted", "cite-event-ids" },
    },
    .{
        .id = "before-after-trace-comparison",
        .title = "Before After Trace Comparison",
        .status = "ready",
        .consumes = &.{
            "baseline zigeffect.causal.v1 artifact",
            "after zigeffect.causal.v1 artifact",
            "optional causal compare report",
        },
        .produces = &.{ "compare posture", "evidence checklist" },
        .human_action = "review baseline and after artifacts before claiming a fix improved runtime behavior",
        .agent_action = "run causal-compare and cite finding deltas, event deltas, added events, removed events, and changed events",
        .commands = &.{
            "zig build causal-compare -- <before.json> <after.json>",
            "zig build causal-dev-loop -- baseline <scenario>",
            "zig build causal-dev-loop -- after <scenario>",
        },
        .evidence_refs = &.{
            ".zig-cache/causal-artifacts/<scenario>-before.json",
            ".zig-cache/causal-artifacts/<scenario>-after.json",
            ".zig-cache/causal-artifacts/<scenario>-ci-compare.txt",
        },
        .guardrails = &.{ "distinguish-planned-captured-verified", "do-not-infer-fix", "cite-compare-evidence" },
    },
    .{
        .id = "regression-clustering-records",
        .title = "Regression Clustering Records",
        .status = "ready",
        .consumes = &.{
            "findings",
            "event kinds",
            "scenario or target",
            "owner lane",
            "semantic refs when present",
        },
        .produces = &.{ "local cluster id", "pattern signature", "learning priority", "future durable handoff target" },
        .human_action = "review repeated failure patterns without treating local clusters as durable memory",
        .agent_action = "group recurring findings by bounded evidence fields and preserve limitations",
        .commands = &.{
            "zig build causal-human-agent-feedback-loop -- --format json",
            "zig build causal-query -- --agent --file <artifact.json> list_findings 1",
        },
        .evidence_refs = &.{
            "finding.kind",
            "event.kind",
            "scenario_id",
            "owner_or_scope",
            "data_subject_ref",
        },
        .guardrails = &.{ "local-advisory-only", "no-durable-write", "no-training", "redacted-refs-only" },
    },
    .{
        .id = "guarded-remediation-proposal-handoff",
        .title = "Guarded Remediation Proposal Handoff",
        .status = "ready",
        .consumes = &.{
            "zigeffect.causal.remediation-audit.v1",
            "zigeffect.causal.remediation-decision.v1",
            "zigeffect.causal.patch-proposal.v1",
            "zigeffect.causal.registry-application-readiness.v1",
            "zigeffect.causal.app-application-readiness.v1",
        },
        .produces = &.{ "handoff status", "required next reviewed command", "application boundary warning" },
        .human_action = "review proposal, policy, readiness, and application records before treating a change as applied",
        .agent_action = "handoff through existing guarded tools and never upgrade a proposal to applied",
        .commands = &.{
            "zig build causal-audit-chain -- <session> <audit> <decision> <proposal> <before> <after>",
            "zig build causal-registry-application-readiness -- --from-registry-patch <registry-patch.json> approve --reason <reason>",
            "zig build causal-app-apply -- --from-readiness <app-application-readiness.json> plan --reason <reason>",
        },
        .evidence_refs = &.{
            ".zig-cache/causal-artifacts/<scenario>-remediation-audit.json",
            ".zig-cache/causal-artifacts/<scenario>-policy-decision.json",
            ".zig-cache/causal-artifacts/<scenario>-patch-proposal.json",
            ".zig-cache/causal-artifacts/<target>-app-application.json",
        },
        .guardrails = &.{ "record-only", "applied-false-by-default", "review-required", "boundary-owned-application" },
    },
    .{
        .id = "durable-history-learning-handoff",
        .title = "Durable History Learning Handoff",
        .status = "planned",
        .consumes = &.{
            "zigeffect.causal.human-agent-feedback-loop.v1",
            "local regression cluster record",
            "retention policy",
        },
        .produces = &.{ "future NenDB adapter handoff fields", "no write operation" },
        .human_action = "review whether a local cluster is worth retaining after policy and redaction checks",
        .agent_action = "prepare future NenDB adapter fields without writing durable history",
        .commands = &.{
            "zig build causal-human-agent-feedback-loop -- --format json",
            "zig build causal-durable-production-retention -- --format json",
        },
        .evidence_refs = &.{
            "feedback_loop_record_id",
            "cluster_id",
            "source_artifact_refs",
            "query_report_refs",
            "compare_report_refs",
            "proposal_and_readiness_refs",
        },
        .guardrails = &.{ "future-nendb-adapter-only", "writes-now-false", "policy-before-retention", "redaction-before-storage" },
    },
};

const regression_clusters: []const RegressionCluster = &.{
    .{
        .id = "cluster:<target>:<finding-kind>:<event-kind>:<owner-or-scope>:<semantic-ref-or-none>",
        .pattern_signature = "target + finding kind + event kind + owner or scope + redacted semantic ref",
        .status = "local-advisory",
        .evidence_refs = &.{ "finding.event_id", "finding.kind", "event.kind", "scope_id", "data_subject_ref" },
        .learning_priority = "review repeated failures before future durable retention",
        .durable_target = durable_target,
    },
};

const guarded_handoffs: []const GuardedHandoff = &.{
    .{
        .id = "core-runtime-remediation",
        .status = "proposal-ready",
        .consumes = &.{ "remediation audit", "policy decision", "patch proposal", "before/after compare" },
        .produces = &.{ "reviewed patch handoff", "audit chain" },
        .required_boundary = "human review and existing application record before applied=true",
        .mutation_authority = mutation_authority,
        .applied = false,
    },
    .{
        .id = "app-remediation",
        .status = "readiness-handoff",
        .consumes = &.{ "app remediation audit", "app policy decision", "app patch proposal", "app application readiness" },
        .produces = &.{ "app application plan record", "optional external reviewed application record" },
        .required_boundary = "causal-app-apply records only evidence from a reviewed external app application",
        .mutation_authority = mutation_authority,
        .applied = false,
    },
};

const durable_history_handoffs: []const DurableHistoryHandoff = &.{
    .{
        .id = "nendb-history-learning",
        .status = "future-handoff",
        .target = durable_target,
        .writes_now = false,
        .required_fields = &.{
            "feedback_loop_record_id",
            "cluster_id",
            "scenario_or_target",
            "source_artifact_refs",
            "query_report_refs",
            "compare_report_refs",
            "proposal_and_readiness_refs",
            "redaction_posture",
            "retention_class",
            "expiration_or_pruning_policy",
        },
        .policy_constraints = &.{ "bounded", "redacted", "retention-governed", "adapter-owned-write" },
    },
};

const guardrails: []const []const u8 = &.{
    "mutation authority remains none",
    "applied remains false",
    "human workbench remains read-only",
    "agent query mode remains bounded and redacted",
    "compare commands must not be claimed as evidence until executed",
    "regression clusters are local advisory records",
    "durable history is future NenDB adapter handoff only",
    "app and registry application stay behind existing reviewed boundaries",
};

const verification_commands: []const []const u8 = &.{
    "cd packages/zigeffect",
    "zig build causal-human-agent-feedback-loop",
    "zig build causal-human-agent-feedback-loop -- --format json",
    "zig build causal-schema-governance -- --format json",
    "zig build causal-production-hardening-backlog -- --format json",
    "zig build examples",
    "zig build test",
    "cd ../..",
    "bun run zigeffect:workbench:test",
    "bun run zigeffect:workbench:typecheck",
    "bun run zigeffect:workbench:build",
    "bun run check",
    "bun run zig:test",
    "git diff --check",
};

fn usage() []const u8 {
    return
    \\usage:
    \\  zig build causal-human-agent-feedback-loop
    \\  zig build causal-human-agent-feedback-loop -- --format text
    \\  zig build causal-human-agent-feedback-loop -- --format json
    \\
    \\formats:
    \\  --format text|json
    \\
    ;
}

fn parseOptions(args: []const []const u8) !OutputFormat {
    if (args.len == 1) return .text;
    if (args.len == 3 and std.mem.eql(u8, args[1], "--format")) {
        if (std.mem.eql(u8, args[2], "text")) return .text;
        if (std.mem.eql(u8, args[2], "json")) return .json;
        return error.UnknownFormat;
    }
    if (args.len == 2 and std.mem.eql(u8, args[1], "--format")) return error.MissingFormat;
    return error.UnknownFlag;
}

pub fn formatHumanAgentFeedbackLoopText(allocator: std.mem.Allocator) ![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "zigeffect causal human-agent feedback loop\n");
    try output.print(allocator, "schema: {s}\n", .{feedback_loop_schema});
    try output.print(allocator, "schema_version: {d}\n", .{feedback_loop_schema_version});
    try output.print(allocator, "producer: {s}\n", .{generated_by});
    try output.print(allocator, "mode: {s}\n", .{mode});
    try output.appendSlice(allocator, "applied: false\n");
    try output.print(allocator, "mutation authority: {s}\n", .{mutation_authority});
    try output.print(allocator, "source branch: {s}\n", .{source_branch});
    try output.print(allocator, "recommended next branch: {s}\n", .{next_branch});

    try output.appendSlice(allocator, "\nsurface contract:\n");
    try output.print(allocator, "- human surface: {s}\n", .{surface_contract.human_surface});
    try output.print(allocator, "- agent surface: {s}\n", .{surface_contract.agent_surface});
    try output.print(allocator, "- durable target: future NenDB adapter ({s})\n", .{surface_contract.durable_target});
    try output.print(allocator, "- workbench mutation: {s}\n", .{if (surface_contract.workbench_mutation) "true" else "false"});
    try output.print(allocator, "- agent mutation: {s}\n", .{if (surface_contract.agent_mutation) "true" else "false"});

    try output.appendSlice(allocator, "\nstages:\n");
    for (loop_stages, 0..) |stage, index| {
        try output.print(allocator, "{d}. {s}: {s}\n", .{ index + 1, stage.id, stage.title });
        try output.print(allocator, "   status: {s}\n", .{stage.status});
        try output.print(allocator, "   human action: {s}\n", .{stage.human_action});
        try output.print(allocator, "   agent action: {s}\n", .{stage.agent_action});
        try output.appendSlice(allocator, "   consumes:");
        for (stage.consumes) |item| try output.print(allocator, " {s};", .{item});
        try output.append(allocator, '\n');
        try output.appendSlice(allocator, "   produces:");
        for (stage.produces) |item| try output.print(allocator, " {s};", .{item});
        try output.append(allocator, '\n');
        try output.appendSlice(allocator, "   commands:\n");
        for (stage.commands) |command| try output.print(allocator, "   - {s}\n", .{command});
        try output.appendSlice(allocator, "   evidence refs:");
        for (stage.evidence_refs) |item| try output.print(allocator, " {s};", .{item});
        try output.append(allocator, '\n');
        try output.appendSlice(allocator, "   guardrails:");
        for (stage.guardrails) |item| try output.print(allocator, " {s};", .{item});
        try output.append(allocator, '\n');
    }

    try output.appendSlice(allocator, "\nregression clusters:\n");
    for (regression_clusters) |cluster| {
        try output.print(allocator, "- {s}\n", .{cluster.id});
        try output.print(allocator, "  signature: {s}\n", .{cluster.pattern_signature});
        try output.print(allocator, "  status: {s}\n", .{cluster.status});
        try output.print(allocator, "  learning priority: {s}\n", .{cluster.learning_priority});
        try output.print(allocator, "  durable target: future NenDB adapter ({s})\n", .{cluster.durable_target});
    }

    try output.appendSlice(allocator, "\nguarded handoffs:\n");
    for (guarded_handoffs) |handoff| {
        try output.print(allocator, "- {s}\n", .{handoff.id});
        try output.print(allocator, "  status: {s}\n", .{handoff.status});
        try output.print(allocator, "  required boundary: {s}\n", .{handoff.required_boundary});
        try output.print(allocator, "  mutation authority: {s}\n", .{handoff.mutation_authority});
        try output.print(allocator, "  applied: {s}\n", .{if (handoff.applied) "true" else "false"});
    }

    try output.appendSlice(allocator, "\ndurable history handoffs:\n");
    for (durable_history_handoffs) |handoff| {
        try output.print(allocator, "- {s}\n", .{handoff.id});
        try output.print(allocator, "  status: {s}\n", .{handoff.status});
        try output.print(allocator, "  target: future NenDB adapter ({s})\n", .{handoff.target});
        try output.print(allocator, "  writes now: {s}\n", .{if (handoff.writes_now) "true" else "false"});
        try output.appendSlice(allocator, "  required fields:");
        for (handoff.required_fields) |item| try output.print(allocator, " {s};", .{item});
        try output.append(allocator, '\n');
        try output.appendSlice(allocator, "  policy constraints:");
        for (handoff.policy_constraints) |item| try output.print(allocator, " {s};", .{item});
        try output.append(allocator, '\n');
    }

    try output.appendSlice(allocator, "\nguardrails:\n");
    for (guardrails) |guardrail| try output.print(allocator, "- {s}\n", .{guardrail});

    try output.appendSlice(allocator, "\nverification commands:\n");
    for (verification_commands) |command| try output.print(allocator, "- {s}\n", .{command});

    return output.toOwnedSlice(allocator);
}

pub fn formatHumanAgentFeedbackLoopJson(allocator: std.mem.Allocator) ![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "{\n");
    try appendJsonStringProperty(allocator, &output, "schema", feedback_loop_schema, true, "  ");
    try appendJsonU32Property(allocator, &output, "schema_version", feedback_loop_schema_version, true, "  ");
    try appendJsonStringProperty(allocator, &output, "producer", generated_by, true, "  ");
    try appendJsonStringProperty(allocator, &output, "mode", mode, true, "  ");
    try appendJsonBoolProperty(allocator, &output, "applied", false, true, "  ");
    try appendJsonStringProperty(allocator, &output, "mutation_authority", mutation_authority, true, "  ");
    try appendJsonStringProperty(allocator, &output, "source_branch", source_branch, true, "  ");

    try output.appendSlice(allocator, "  \"surface_contract\": {\n");
    try appendJsonStringProperty(allocator, &output, "human_surface", surface_contract.human_surface, true, "    ");
    try appendJsonStringProperty(allocator, &output, "agent_surface", surface_contract.agent_surface, true, "    ");
    try appendJsonStringProperty(allocator, &output, "durable_target", surface_contract.durable_target, true, "    ");
    try appendJsonBoolProperty(allocator, &output, "workbench_mutation", surface_contract.workbench_mutation, true, "    ");
    try appendJsonBoolProperty(allocator, &output, "agent_mutation", surface_contract.agent_mutation, false, "    ");
    try output.appendSlice(allocator, "  },\n");

    try output.appendSlice(allocator, "  \"stages\": [\n");
    for (loop_stages, 0..) |stage, index| {
        try output.appendSlice(allocator, "    {\n");
        try appendJsonStringProperty(allocator, &output, "id", stage.id, true, "      ");
        try appendJsonStringProperty(allocator, &output, "title", stage.title, true, "      ");
        try appendJsonStringProperty(allocator, &output, "status", stage.status, true, "      ");
        try appendJsonStringArrayProperty(allocator, &output, "consumes", stage.consumes, true, "      ");
        try appendJsonStringArrayProperty(allocator, &output, "produces", stage.produces, true, "      ");
        try appendJsonStringProperty(allocator, &output, "human_action", stage.human_action, true, "      ");
        try appendJsonStringProperty(allocator, &output, "agent_action", stage.agent_action, true, "      ");
        try appendJsonStringArrayProperty(allocator, &output, "commands", stage.commands, true, "      ");
        try appendJsonStringArrayProperty(allocator, &output, "evidence_refs", stage.evidence_refs, true, "      ");
        try appendJsonStringArrayProperty(allocator, &output, "guardrails", stage.guardrails, false, "      ");
        try output.appendSlice(allocator, if (index + 1 == loop_stages.len) "    }\n" else "    },\n");
    }
    try output.appendSlice(allocator, "  ],\n");

    try output.appendSlice(allocator, "  \"regression_clusters\": [\n");
    for (regression_clusters, 0..) |cluster, index| {
        try output.appendSlice(allocator, "    {\n");
        try appendJsonStringProperty(allocator, &output, "id", cluster.id, true, "      ");
        try appendJsonStringProperty(allocator, &output, "pattern_signature", cluster.pattern_signature, true, "      ");
        try appendJsonStringProperty(allocator, &output, "status", cluster.status, true, "      ");
        try appendJsonStringArrayProperty(allocator, &output, "evidence_refs", cluster.evidence_refs, true, "      ");
        try appendJsonStringProperty(allocator, &output, "learning_priority", cluster.learning_priority, true, "      ");
        try appendJsonStringProperty(allocator, &output, "durable_target", cluster.durable_target, false, "      ");
        try output.appendSlice(allocator, if (index + 1 == regression_clusters.len) "    }\n" else "    },\n");
    }
    try output.appendSlice(allocator, "  ],\n");

    try output.appendSlice(allocator, "  \"guarded_handoffs\": [\n");
    for (guarded_handoffs, 0..) |handoff, index| {
        try output.appendSlice(allocator, "    {\n");
        try appendJsonStringProperty(allocator, &output, "id", handoff.id, true, "      ");
        try appendJsonStringProperty(allocator, &output, "status", handoff.status, true, "      ");
        try appendJsonStringArrayProperty(allocator, &output, "consumes", handoff.consumes, true, "      ");
        try appendJsonStringArrayProperty(allocator, &output, "produces", handoff.produces, true, "      ");
        try appendJsonStringProperty(allocator, &output, "required_boundary", handoff.required_boundary, true, "      ");
        try appendJsonStringProperty(allocator, &output, "mutation_authority", handoff.mutation_authority, true, "      ");
        try appendJsonBoolProperty(allocator, &output, "applied", handoff.applied, false, "      ");
        try output.appendSlice(allocator, if (index + 1 == guarded_handoffs.len) "    }\n" else "    },\n");
    }
    try output.appendSlice(allocator, "  ],\n");

    try output.appendSlice(allocator, "  \"durable_history_handoffs\": [\n");
    for (durable_history_handoffs, 0..) |handoff, index| {
        try output.appendSlice(allocator, "    {\n");
        try appendJsonStringProperty(allocator, &output, "id", handoff.id, true, "      ");
        try appendJsonStringProperty(allocator, &output, "status", handoff.status, true, "      ");
        try appendJsonStringProperty(allocator, &output, "target", handoff.target, true, "      ");
        try appendJsonBoolProperty(allocator, &output, "writes_now", handoff.writes_now, true, "      ");
        try appendJsonStringArrayProperty(allocator, &output, "required_fields", handoff.required_fields, true, "      ");
        try appendJsonStringArrayProperty(allocator, &output, "policy_constraints", handoff.policy_constraints, false, "      ");
        try output.appendSlice(allocator, if (index + 1 == durable_history_handoffs.len) "    }\n" else "    },\n");
    }
    try output.appendSlice(allocator, "  ],\n");

    try appendJsonStringArrayProperty(allocator, &output, "verification_commands", verification_commands, true, "  ");
    try appendJsonStringArrayProperty(allocator, &output, "guardrails", guardrails, true, "  ");
    try appendJsonStringProperty(allocator, &output, "next_branch", next_branch, false, "  ");
    try output.appendSlice(allocator, "}\n");

    return output.toOwnedSlice(allocator);
}

pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    const format = parseOptions(args) catch |err| failUsage(err);
    const report = switch (format) {
        .text => try formatHumanAgentFeedbackLoopText(init.gpa),
        .json => try formatHumanAgentFeedbackLoopJson(init.gpa),
    };
    defer init.gpa.free(report);

    std.debug.print("{s}", .{report});
}

fn failUsage(err: anyerror) noreturn {
    std.debug.print("causal-human-agent-feedback-loop error: {s}\n{s}", .{ @errorName(err), usage() });
    std.process.exit(2);
}

fn appendJsonStringProperty(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    name: []const u8,
    value: []const u8,
    trailing: bool,
    indent: []const u8,
) !void {
    try output.appendSlice(allocator, indent);
    try appendJsonString(allocator, output, name);
    try output.appendSlice(allocator, ": ");
    try appendJsonString(allocator, output, value);
    if (trailing) try output.append(allocator, ',');
    try output.append(allocator, '\n');
}

fn appendJsonU32Property(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    name: []const u8,
    value: u32,
    trailing: bool,
    indent: []const u8,
) !void {
    try output.appendSlice(allocator, indent);
    try appendJsonString(allocator, output, name);
    try output.print(allocator, ": {d}", .{value});
    if (trailing) try output.append(allocator, ',');
    try output.append(allocator, '\n');
}

fn appendJsonBoolProperty(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    name: []const u8,
    value: bool,
    trailing: bool,
    indent: []const u8,
) !void {
    try output.appendSlice(allocator, indent);
    try appendJsonString(allocator, output, name);
    try output.appendSlice(allocator, if (value) ": true" else ": false");
    if (trailing) try output.append(allocator, ',');
    try output.append(allocator, '\n');
}

fn appendJsonStringArrayProperty(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    name: []const u8,
    values: []const []const u8,
    trailing: bool,
    indent: []const u8,
) !void {
    try output.appendSlice(allocator, indent);
    try appendJsonString(allocator, output, name);
    try output.appendSlice(allocator, ": ");
    try appendStringArray(allocator, output, values);
    if (trailing) try output.append(allocator, ',');
    try output.append(allocator, '\n');
}

fn appendStringArray(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    values: []const []const u8,
) !void {
    try output.append(allocator, '[');
    for (values, 0..) |value, index| {
        if (index != 0) try output.appendSlice(allocator, ", ");
        try appendJsonString(allocator, output, value);
    }
    try output.append(allocator, ']');
}

fn appendJsonString(allocator: std.mem.Allocator, output: *std.ArrayList(u8), value: []const u8) !void {
    try output.append(allocator, '"');
    for (value) |byte| switch (byte) {
        '"' => try output.appendSlice(allocator, "\\\""),
        '\\' => try output.appendSlice(allocator, "\\\\"),
        '\n' => try output.appendSlice(allocator, "\\n"),
        '\r' => try output.appendSlice(allocator, "\\r"),
        '\t' => try output.appendSlice(allocator, "\\t"),
        else => try output.append(allocator, byte),
    };
    try output.append(allocator, '"');
}

test "human agent feedback loop constants preserve record-only branch boundary" {
    try std.testing.expectEqualStrings(
        "zigeffect.causal.human-agent-feedback-loop.v1",
        feedback_loop_schema,
    );
    try std.testing.expectEqual(@as(u32, 1), feedback_loop_schema_version);
    try std.testing.expectEqualStrings(
        "codex/zigeffect-causal-human-agent-feedback-loop",
        source_branch,
    );
    try std.testing.expectEqualStrings(
        "codex/zigeffect-causal-rollout-automation-guardrails",
        next_branch,
    );
}

test "human agent feedback loop usage names command and formats" {
    try std.testing.expect(std.mem.indexOf(u8, usage(), "causal-human-agent-feedback-loop") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage(), "--format text|json") != null);
}

test "human agent feedback loop parses supported formats" {
    try std.testing.expectEqual(OutputFormat.text, try parseOptions(&.{"zigeffect-causal-human-agent-feedback-loop"}));
    try std.testing.expectEqual(OutputFormat.text, try parseOptions(&.{ "zigeffect-causal-human-agent-feedback-loop", "--format", "text" }));
    try std.testing.expectEqual(OutputFormat.json, try parseOptions(&.{ "zigeffect-causal-human-agent-feedback-loop", "--format", "json" }));
    try std.testing.expectError(error.UnknownFormat, parseOptions(&.{ "zigeffect-causal-human-agent-feedback-loop", "--format", "yaml" }));
    try std.testing.expectError(error.MissingFormat, parseOptions(&.{ "zigeffect-causal-human-agent-feedback-loop", "--format" }));
    try std.testing.expectError(error.UnknownFlag, parseOptions(&.{ "zigeffect-causal-human-agent-feedback-loop", "--json" }));
}

test "human agent feedback loop text report contains stages and guardrails" {
    const allocator = std.testing.allocator;
    const report = try formatHumanAgentFeedbackLoopText(allocator);
    defer allocator.free(report);

    try std.testing.expect(std.mem.indexOf(u8, report, "schema: zigeffect.causal.human-agent-feedback-loop.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "applied: false") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "mutation authority: none") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "failure-to-query") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "before-after-trace-comparison") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "regression-clustering-records") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "guarded-remediation-proposal-handoff") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "durable-history-learning-handoff") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "future NenDB adapter") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "recommended next branch: codex/zigeffect-causal-rollout-automation-guardrails") != null);
}

test "human agent feedback loop JSON is agent-readable and non-mutating" {
    const allocator = std.testing.allocator;
    const report = try formatHumanAgentFeedbackLoopJson(allocator);
    defer allocator.free(report);

    try std.testing.expect(std.mem.indexOf(u8, report, "\"schema\": \"zigeffect.causal.human-agent-feedback-loop.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"schema_version\": 1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"mode\": \"local-record\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"applied\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"mutation_authority\": \"none\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"human_surface\": \"solidjs-webui-workbench\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"agent_surface\": \"causal-query-agent-json\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"durable_target\": \"future-nendb-adapter\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"workbench_mutation\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"agent_mutation\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"stages\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"id\": \"failure-to-query\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"id\": \"before-after-trace-comparison\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"id\": \"regression-clustering-records\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"id\": \"guarded-remediation-proposal-handoff\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"id\": \"durable-history-learning-handoff\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"regression_clusters\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"guarded_handoffs\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"durable_history_handoffs\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"next_branch\": \"codex/zigeffect-causal-rollout-automation-guardrails\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "unsupported-durable-target") == null);
}
