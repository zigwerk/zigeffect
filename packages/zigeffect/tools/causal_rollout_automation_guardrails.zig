const std = @import("std");

pub const rollout_automation_guardrails_schema = "zigeffect.causal.rollout-automation-guardrails.v1";
pub const rollout_automation_guardrails_schema_version: u32 = 1;
pub const source_branch = "codex/zigeffect-causal-rollout-automation-guardrails";
pub const next_branch = "codex/zigeffect-causal-wall-clock-benchmark-baselines";

const OutputFormat = enum { text, json };

const generated_by = "causal-rollout-automation-guardrails";
const mode = "local-record";
const mutation_authority = "none";

const RolloutControl = struct {
    id: []const u8,
    purpose: []const u8,
    required_evidence: []const u8,
    authority_boundary: []const u8,
};

const CanaryEvidenceRecord = struct {
    id: []const u8,
    status: []const u8,
    target: []const u8,
    required_evidence: []const []const u8,
    exposure_ceiling: []const u8,
    decision: []const u8,
    guardrails: []const []const u8,
};

const ProgressionGate = struct {
    id: []const u8,
    decision: []const u8,
    required_evidence: []const []const u8,
    blocked_without: []const u8,
    authority_boundary: []const u8,
};

const CircuitBreakerDecision = struct {
    id: []const u8,
    trigger: []const u8,
    decision: []const u8,
    required_review: []const u8,
    action: []const u8,
};

const RollbackReadinessGate = struct {
    id: []const u8,
    status: []const u8,
    required_evidence: []const []const u8,
    failure_action: []const u8,
    external_record_required: bool,
};

const NegativeAutomationFixture = struct {
    id: []const u8,
    attempted_action: []const u8,
    decision: []const u8,
    failed_gate: []const u8,
    reason: []const u8,
};

const source_contracts: []const []const u8 = &.{
    "zigeffect.causal.production-deployment-runbooks.v1",
    "zigeffect.causal.alerting-integrations.v1",
    "zigeffect.causal.human-agent-feedback-loop.v1",
};

const rollout_controls: []const RolloutControl = &.{
    .{
        .id = "external-rollout-only",
        .purpose = "rollout execution stays outside zigeffect authority",
        .required_evidence = "external deployment or rollout system record for any applied state",
        .authority_boundary = "record-only advice cannot shift traffic",
    },
    .{
        .id = "human-progression-review",
        .purpose = "canary progression requires named human review",
        .required_evidence = "reviewer, owner, reason, and rollback owner",
        .authority_boundary = "approval records do not mutate feature flags or deployments",
    },
    .{
        .id = "bounded-canary-exposure",
        .purpose = "canary scope and exposure ceiling must be recorded before progression",
        .required_evidence = "target service, segment, exposure ceiling, and baseline refs",
        .authority_boundary = "exposure ceiling is descriptive, not a traffic command",
    },
    .{
        .id = "causal-baseline-required",
        .purpose = "baseline causal evidence must exist before canary comparison",
        .required_evidence = "baseline artifact, canary artifact, and causal compare command",
        .authority_boundary = "missing baseline blocks progression",
    },
    .{
        .id = "alert-preview-required",
        .purpose = "alert routing and escalation posture must be previewed",
        .required_evidence = "record-only alerting integrations preview",
        .authority_boundary = "previews do not send alerts tickets SIEM events or pages",
    },
    .{
        .id = "rollback-owner-required",
        .purpose = "rollback readiness must have a named owner before progression",
        .required_evidence = "last-good ref, rollback owner, reviewer, and verification commands",
        .authority_boundary = "rollback execution remains external",
    },
};

const canary_evidence_records: []const CanaryEvidenceRecord = &.{
    .{
        .id = "candidate-canary-evidence",
        .status = "record-required",
        .target = "zigeffect production candidate",
        .required_evidence = &.{
            "candidate artifact bundle",
            "baseline causal artifact",
            "human rollout owner",
            "human reviewer",
            "exposure ceiling",
            "alert preview",
            "rollback owner",
            "verification commands",
        },
        .exposure_ceiling = "bounded external canary exposure only",
        .decision = "progression-blocked until evidence is complete",
        .guardrails = &.{ "record-only", "no-traffic-shift", "no-feature-flag-mutation" },
    },
    .{
        .id = "app-boundary-canary-evidence",
        .status = "record-required",
        .target = "app built with zigeffect",
        .required_evidence = &.{
            "app application readiness or application record",
            "app causal baseline",
            "app canary artifact",
            "app rollback plan",
            "human app reviewer",
        },
        .exposure_ceiling = "external app rollout system owns exposure",
        .decision = "ready-for-review only after app boundary evidence exists",
        .guardrails = &.{ "app-application-boundary", "record-only", "no-app-mutation" },
    },
};

const progression_gates: []const ProgressionGate = &.{
    .{
        .id = "progression-blocked",
        .decision = "blocked",
        .required_evidence = &.{ "baseline", "canary artifact", "reviewer", "rollback owner", "alert preview" },
        .blocked_without = "any required canary evidence",
        .authority_boundary = "do not progress externally",
    },
    .{
        .id = "hold-for-review",
        .decision = "hold",
        .required_evidence = &.{ "partial findings", "review reason", "next query refs" },
        .blocked_without = "human review conclusion",
        .authority_boundary = "hold is advice, not traffic control",
    },
    .{
        .id = "ready-for-external-progression",
        .decision = "ready-for-external-progression",
        .required_evidence = &.{ "clear compare evidence", "reviewed alert preview", "rollback readiness" },
        .blocked_without = "external rollout record",
        .authority_boundary = "external system must execute any progression",
    },
    .{
        .id = "rollback-review-required",
        .decision = "rollback-review",
        .required_evidence = &.{ "failed verification", "last-good ref", "rollback reviewer" },
        .blocked_without = "rollback readiness gate",
        .authority_boundary = "external rollback execution required",
    },
    .{
        .id = "escalation-review-required",
        .decision = "escalate",
        .required_evidence = &.{ "critical alert preview", "incident owner", "human escalation approval" },
        .blocked_without = "human escalation approval",
        .authority_boundary = "record-only alert previews never page",
    },
};

const circuit_breaker_decisions: []const CircuitBreakerDecision = &.{
    .{ .id = "new-critical-finding", .trigger = "new critical finding kind or terminal event appears in canary", .decision = "rollback-review", .required_review = "incident owner and rollback reviewer", .action = "open rollback review record only" },
    .{ .id = "finding-count-increase", .trigger = "finding count increases against baseline", .decision = "hold", .required_review = "release owner", .action = "run causal-compare and bounded causal-query before progression" },
    .{ .id = "failed-runbook-gate", .trigger = "deployment runbook gate fails", .decision = "blocked", .required_review = "deployment reviewer", .action = "block progression evidence" },
    .{ .id = "critical-alert-preview", .trigger = "alerting integrations classify preview as critical", .decision = "escalate", .required_review = "human escalation approval", .action = "record escalation requirement without sending a page" },
    .{ .id = "redaction-or-access-denial", .trigger = "redaction review missing or artifact access denied", .decision = "blocked", .required_review = "privacy or access reviewer", .action = "block rollout evidence sharing" },
};

const rollback_readiness_gates: []const RollbackReadinessGate = &.{
    .{
        .id = "not-ready",
        .status = "blocked",
        .required_evidence = &.{ "last-good ref", "rollback owner", "rollback reviewer", "verification commands" },
        .failure_action = "block canary progression",
        .external_record_required = false,
    },
    .{
        .id = "ready-for-external-rollback",
        .status = "ready-for-external-action",
        .required_evidence = &.{ "last-good ref", "human rollback approval", "external rollback command owner" },
        .failure_action = "do not claim rollback applied",
        .external_record_required = true,
    },
    .{
        .id = "external-rollback-recorded",
        .status = "recorded",
        .required_evidence = &.{ "external rollback record id", "after-rollback causal verification", "retained before failed rollback and after refs" },
        .failure_action = "keep incident open",
        .external_record_required = true,
    },
    .{
        .id = "blocked",
        .status = "blocked",
        .required_evidence = &.{ "failed gate reason", "owner", "next reviewed action" },
        .failure_action = "do not roll back and do not progress",
        .external_record_required = false,
    },
};

const negative_automation_fixtures: []const NegativeAutomationFixture = &.{
    .{ .id = "unreviewed-canary-progression", .attempted_action = "progress canary without human review", .decision = "blocked", .failed_gate = "human-progression-review", .reason = "canary progression requires named reviewer and reason" },
    .{ .id = "missing-baseline-artifact", .attempted_action = "start canary without baseline causal artifact", .decision = "blocked", .failed_gate = "causal-baseline-required", .reason = "baseline evidence is required before compare or progression" },
    .{ .id = "missing-rollback-owner", .attempted_action = "mark rollout safe without rollback owner", .decision = "blocked", .failed_gate = "rollback-owner-required", .reason = "rollback owner and last-good ref are required" },
    .{ .id = "critical-alert-without-human-approval", .attempted_action = "escalate critical alert preview without human approval", .decision = "blocked", .failed_gate = "human-escalation-review", .reason = "record-only alert previews never page without approval evidence" },
    .{ .id = "redaction-not-reviewed", .attempted_action = "share rollout evidence before redaction review", .decision = "blocked", .failed_gate = "redaction-reviewed", .reason = "redaction review precedes sharing and escalation" },
    .{ .id = "traffic-mutation-attempt", .attempted_action = "shift traffic from a rollout guardrail report", .decision = "blocked", .failed_gate = "external-rollout-only", .reason = "traffic shifts stay in external reviewed rollout systems" },
    .{ .id = "rollback-applied-without-external-record", .attempted_action = "claim rollback applied without external rollback record", .decision = "blocked", .failed_gate = "external-rollback-record", .reason = "applied rollback state requires external reviewed evidence" },
};

const guardrails: []const []const u8 = &.{
    "mutation authority remains none",
    "applied remains false",
    "rollout progression is advice only",
    "traffic shifts stay in external reviewed systems",
    "feature flag mutation is out of scope",
    "alert ticket SIEM and paging integrations remain record-only previews",
    "rollback execution stays outside zigeffect authority",
    "human review is required before progression rollback or escalation",
};

const verification_commands: []const []const u8 = &.{
    "cd packages/zigeffect",
    "zig build causal-rollout-automation-guardrails",
    "zig build causal-rollout-automation-guardrails -- --format json",
    "zig build causal-production-deployment-runbooks -- --format json",
    "zig build causal-alerting-integrations -- --format json",
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
    \\  zig build causal-rollout-automation-guardrails
    \\  zig build causal-rollout-automation-guardrails -- --format text
    \\  zig build causal-rollout-automation-guardrails -- --format json
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

pub fn formatRolloutAutomationGuardrailsText(allocator: std.mem.Allocator) ![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "zigeffect causal rollout automation guardrails\n");
    try output.print(allocator, "schema: {s}\n", .{rollout_automation_guardrails_schema});
    try output.print(allocator, "schema_version: {d}\n", .{rollout_automation_guardrails_schema_version});
    try output.print(allocator, "producer: {s}\n", .{generated_by});
    try output.print(allocator, "mode: {s}\n", .{mode});
    try output.appendSlice(allocator, "applied: false\n");
    try output.print(allocator, "mutation authority: {s}\n", .{mutation_authority});
    try output.print(allocator, "source branch: {s}\n", .{source_branch});
    try output.print(allocator, "recommended next branch: {s}\n", .{next_branch});

    try appendTextStringList(allocator, &output, "\nsource contracts", source_contracts);

    try output.appendSlice(allocator, "\nrollout controls:\n");
    for (rollout_controls) |control| {
        try output.print(allocator, "- {s}\n", .{control.id});
        try output.print(allocator, "  purpose: {s}\n", .{control.purpose});
        try output.print(allocator, "  required evidence: {s}\n", .{control.required_evidence});
        try output.print(allocator, "  authority boundary: {s}\n", .{control.authority_boundary});
    }

    try output.appendSlice(allocator, "\ncanary evidence records:\n");
    for (canary_evidence_records) |record| {
        try output.print(allocator, "- {s}\n", .{record.id});
        try output.print(allocator, "  status: {s}\n", .{record.status});
        try output.print(allocator, "  target: {s}\n", .{record.target});
        try output.print(allocator, "  exposure ceiling: {s}\n", .{record.exposure_ceiling});
        try output.print(allocator, "  decision: {s}\n", .{record.decision});
        try appendInlineList(allocator, &output, "  required evidence", record.required_evidence);
        try appendInlineList(allocator, &output, "  guardrails", record.guardrails);
    }

    try output.appendSlice(allocator, "\nprogression gates:\n");
    for (progression_gates) |gate| {
        try output.print(allocator, "- {s}\n", .{gate.id});
        try output.print(allocator, "  decision: {s}\n", .{gate.decision});
        try output.print(allocator, "  blocked without: {s}\n", .{gate.blocked_without});
        try output.print(allocator, "  authority boundary: {s}\n", .{gate.authority_boundary});
        try appendInlineList(allocator, &output, "  required evidence", gate.required_evidence);
    }

    try output.appendSlice(allocator, "\ncircuit breaker decisions:\n");
    for (circuit_breaker_decisions) |decision| {
        try output.print(allocator, "- {s}\n", .{decision.id});
        try output.print(allocator, "  trigger: {s}\n", .{decision.trigger});
        try output.print(allocator, "  decision: {s}\n", .{decision.decision});
        try output.print(allocator, "  required review: {s}\n", .{decision.required_review});
        try output.print(allocator, "  action: {s}\n", .{decision.action});
    }

    try output.appendSlice(allocator, "\nrollback readiness gates:\n");
    for (rollback_readiness_gates) |gate| {
        try output.print(allocator, "- {s}\n", .{gate.id});
        try output.print(allocator, "  status: {s}\n", .{gate.status});
        try output.print(allocator, "  failure action: {s}\n", .{gate.failure_action});
        try output.print(allocator, "  external record required: {s}\n", .{if (gate.external_record_required) "true" else "false"});
        try appendInlineList(allocator, &output, "  required evidence", gate.required_evidence);
    }

    try output.appendSlice(allocator, "\nnegative automation fixtures:\n");
    for (negative_automation_fixtures) |fixture| {
        try output.print(allocator, "- {s}\n", .{fixture.id});
        try output.print(allocator, "  attempted action: {s}\n", .{fixture.attempted_action});
        try output.print(allocator, "  decision: {s}\n", .{fixture.decision});
        try output.print(allocator, "  failed gate: {s}\n", .{fixture.failed_gate});
        try output.print(allocator, "  reason: {s}\n", .{fixture.reason});
    }

    try appendTextStringList(allocator, &output, "\nguardrails", guardrails);
    try appendTextStringList(allocator, &output, "\nverification commands", verification_commands);

    return output.toOwnedSlice(allocator);
}

pub fn formatRolloutAutomationGuardrailsJson(allocator: std.mem.Allocator) ![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "{\n");
    try appendJsonStringProperty(allocator, &output, "schema", rollout_automation_guardrails_schema, true, "  ");
    try appendJsonU32Property(allocator, &output, "schema_version", rollout_automation_guardrails_schema_version, true, "  ");
    try appendJsonStringProperty(allocator, &output, "producer", generated_by, true, "  ");
    try appendJsonStringProperty(allocator, &output, "mode", mode, true, "  ");
    try appendJsonBoolProperty(allocator, &output, "applied", false, true, "  ");
    try appendJsonStringProperty(allocator, &output, "mutation_authority", mutation_authority, true, "  ");
    try appendJsonStringProperty(allocator, &output, "source_branch", source_branch, true, "  ");
    try appendJsonStringArrayProperty(allocator, &output, "source_contracts", source_contracts, true, "  ");

    try output.appendSlice(allocator, "  \"rollout_controls\": [\n");
    for (rollout_controls, 0..) |control, index| {
        try output.appendSlice(allocator, "    {\n");
        try appendJsonStringProperty(allocator, &output, "id", control.id, true, "      ");
        try appendJsonStringProperty(allocator, &output, "purpose", control.purpose, true, "      ");
        try appendJsonStringProperty(allocator, &output, "required_evidence", control.required_evidence, true, "      ");
        try appendJsonStringProperty(allocator, &output, "authority_boundary", control.authority_boundary, false, "      ");
        try output.appendSlice(allocator, if (index + 1 == rollout_controls.len) "    }\n" else "    },\n");
    }
    try output.appendSlice(allocator, "  ],\n");

    try output.appendSlice(allocator, "  \"canary_evidence_records\": [\n");
    for (canary_evidence_records, 0..) |record, index| {
        try output.appendSlice(allocator, "    {\n");
        try appendJsonStringProperty(allocator, &output, "id", record.id, true, "      ");
        try appendJsonStringProperty(allocator, &output, "status", record.status, true, "      ");
        try appendJsonStringProperty(allocator, &output, "target", record.target, true, "      ");
        try appendJsonStringArrayProperty(allocator, &output, "required_evidence", record.required_evidence, true, "      ");
        try appendJsonStringProperty(allocator, &output, "exposure_ceiling", record.exposure_ceiling, true, "      ");
        try appendJsonStringProperty(allocator, &output, "decision", record.decision, true, "      ");
        try appendJsonStringArrayProperty(allocator, &output, "guardrails", record.guardrails, false, "      ");
        try output.appendSlice(allocator, if (index + 1 == canary_evidence_records.len) "    }\n" else "    },\n");
    }
    try output.appendSlice(allocator, "  ],\n");

    try output.appendSlice(allocator, "  \"progression_gates\": [\n");
    for (progression_gates, 0..) |gate, index| {
        try output.appendSlice(allocator, "    {\n");
        try appendJsonStringProperty(allocator, &output, "id", gate.id, true, "      ");
        try appendJsonStringProperty(allocator, &output, "decision", gate.decision, true, "      ");
        try appendJsonStringArrayProperty(allocator, &output, "required_evidence", gate.required_evidence, true, "      ");
        try appendJsonStringProperty(allocator, &output, "blocked_without", gate.blocked_without, true, "      ");
        try appendJsonStringProperty(allocator, &output, "authority_boundary", gate.authority_boundary, false, "      ");
        try output.appendSlice(allocator, if (index + 1 == progression_gates.len) "    }\n" else "    },\n");
    }
    try output.appendSlice(allocator, "  ],\n");

    try output.appendSlice(allocator, "  \"circuit_breaker_decisions\": [\n");
    for (circuit_breaker_decisions, 0..) |decision, index| {
        try output.appendSlice(allocator, "    {\n");
        try appendJsonStringProperty(allocator, &output, "id", decision.id, true, "      ");
        try appendJsonStringProperty(allocator, &output, "trigger", decision.trigger, true, "      ");
        try appendJsonStringProperty(allocator, &output, "decision", decision.decision, true, "      ");
        try appendJsonStringProperty(allocator, &output, "required_review", decision.required_review, true, "      ");
        try appendJsonStringProperty(allocator, &output, "action", decision.action, false, "      ");
        try output.appendSlice(allocator, if (index + 1 == circuit_breaker_decisions.len) "    }\n" else "    },\n");
    }
    try output.appendSlice(allocator, "  ],\n");

    try output.appendSlice(allocator, "  \"rollback_readiness_gates\": [\n");
    for (rollback_readiness_gates, 0..) |gate, index| {
        try output.appendSlice(allocator, "    {\n");
        try appendJsonStringProperty(allocator, &output, "id", gate.id, true, "      ");
        try appendJsonStringProperty(allocator, &output, "status", gate.status, true, "      ");
        try appendJsonStringArrayProperty(allocator, &output, "required_evidence", gate.required_evidence, true, "      ");
        try appendJsonStringProperty(allocator, &output, "failure_action", gate.failure_action, true, "      ");
        try appendJsonBoolProperty(allocator, &output, "external_record_required", gate.external_record_required, false, "      ");
        try output.appendSlice(allocator, if (index + 1 == rollback_readiness_gates.len) "    }\n" else "    },\n");
    }
    try output.appendSlice(allocator, "  ],\n");

    try output.appendSlice(allocator, "  \"negative_automation_fixtures\": [\n");
    for (negative_automation_fixtures, 0..) |fixture, index| {
        try output.appendSlice(allocator, "    {\n");
        try appendJsonStringProperty(allocator, &output, "id", fixture.id, true, "      ");
        try appendJsonStringProperty(allocator, &output, "attempted_action", fixture.attempted_action, true, "      ");
        try appendJsonStringProperty(allocator, &output, "decision", fixture.decision, true, "      ");
        try appendJsonStringProperty(allocator, &output, "failed_gate", fixture.failed_gate, true, "      ");
        try appendJsonStringProperty(allocator, &output, "reason", fixture.reason, false, "      ");
        try output.appendSlice(allocator, if (index + 1 == negative_automation_fixtures.len) "    }\n" else "    },\n");
    }
    try output.appendSlice(allocator, "  ],\n");

    try appendJsonStringArrayProperty(allocator, &output, "guardrails", guardrails, true, "  ");
    try appendJsonStringArrayProperty(allocator, &output, "verification_commands", verification_commands, true, "  ");
    try appendJsonStringProperty(allocator, &output, "next_branch", next_branch, false, "  ");
    try output.appendSlice(allocator, "}\n");

    return output.toOwnedSlice(allocator);
}

pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    const format = parseOptions(args) catch |err| failUsage(err);
    const report = switch (format) {
        .text => try formatRolloutAutomationGuardrailsText(init.gpa),
        .json => try formatRolloutAutomationGuardrailsJson(init.gpa),
    };
    defer init.gpa.free(report);

    std.debug.print("{s}", .{report});
}

fn failUsage(err: anyerror) noreturn {
    std.debug.print("causal-rollout-automation-guardrails error: {s}\n{s}", .{ @errorName(err), usage() });
    std.process.exit(2);
}

fn appendTextStringList(allocator: std.mem.Allocator, output: *std.ArrayList(u8), title: []const u8, values: []const []const u8) !void {
    try output.print(allocator, "{s}:\n", .{title});
    for (values) |value| try output.print(allocator, "- {s}\n", .{value});
}

fn appendInlineList(allocator: std.mem.Allocator, output: *std.ArrayList(u8), title: []const u8, values: []const []const u8) !void {
    try output.print(allocator, "{s}:", .{title});
    for (values) |value| try output.print(allocator, " {s};", .{value});
    try output.append(allocator, '\n');
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

test "rollout automation guardrails constants preserve record-only branch boundary" {
    try std.testing.expectEqualStrings(
        "zigeffect.causal.rollout-automation-guardrails.v1",
        rollout_automation_guardrails_schema,
    );
    try std.testing.expectEqual(@as(u32, 1), rollout_automation_guardrails_schema_version);
    try std.testing.expectEqualStrings(
        "codex/zigeffect-causal-rollout-automation-guardrails",
        source_branch,
    );
    try std.testing.expectEqualStrings(
        "codex/zigeffect-causal-wall-clock-benchmark-baselines",
        next_branch,
    );
}

test "rollout automation guardrails usage names command and formats" {
    try std.testing.expect(std.mem.indexOf(u8, usage(), "causal-rollout-automation-guardrails") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage(), "--format text|json") != null);
}

test "rollout automation guardrails parses supported formats" {
    try std.testing.expectEqual(OutputFormat.text, try parseOptions(&.{"zigeffect-causal-rollout-automation-guardrails"}));
    try std.testing.expectEqual(OutputFormat.text, try parseOptions(&.{ "zigeffect-causal-rollout-automation-guardrails", "--format", "text" }));
    try std.testing.expectEqual(OutputFormat.json, try parseOptions(&.{ "zigeffect-causal-rollout-automation-guardrails", "--format", "json" }));
    try std.testing.expectError(error.UnknownFormat, parseOptions(&.{ "zigeffect-causal-rollout-automation-guardrails", "--format", "yaml" }));
    try std.testing.expectError(error.MissingFormat, parseOptions(&.{ "zigeffect-causal-rollout-automation-guardrails", "--format" }));
    try std.testing.expectError(error.UnknownFlag, parseOptions(&.{ "zigeffect-causal-rollout-automation-guardrails", "--json" }));
}

test "rollout automation guardrails text report contains records and guardrails" {
    const allocator = std.testing.allocator;
    const report = try formatRolloutAutomationGuardrailsText(allocator);
    defer allocator.free(report);

    try std.testing.expect(std.mem.indexOf(u8, report, "schema: zigeffect.causal.rollout-automation-guardrails.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "applied: false") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "mutation authority: none") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zigeffect.causal.production-deployment-runbooks.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zigeffect.causal.alerting-integrations.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zigeffect.causal.human-agent-feedback-loop.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "canary evidence records") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "progression gates") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "circuit breaker decisions") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "rollback readiness gates") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "negative automation fixtures") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "unreviewed-canary-progression") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "recommended next branch: codex/zigeffect-causal-wall-clock-benchmark-baselines") != null);
}

test "rollout automation guardrails JSON is agent-readable and non-mutating" {
    const allocator = std.testing.allocator;
    const report = try formatRolloutAutomationGuardrailsJson(allocator);
    defer allocator.free(report);

    try std.testing.expect(std.mem.indexOf(u8, report, "\"schema\": \"zigeffect.causal.rollout-automation-guardrails.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"schema_version\": 1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"mode\": \"local-record\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"applied\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"mutation_authority\": \"none\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"source_contracts\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"rollout_controls\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"canary_evidence_records\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"progression_gates\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"circuit_breaker_decisions\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"rollback_readiness_gates\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"negative_automation_fixtures\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"id\": \"unreviewed-canary-progression\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"decision\": \"blocked\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"next_branch\": \"codex/zigeffect-causal-wall-clock-benchmark-baselines\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "traffic_shift_applied") == null);
    try std.testing.expect(std.mem.indexOf(u8, report, "feature_flag_mutated") == null);
}
