const std = @import("std");

pub const production_deployment_runbooks_schema = "zigeffect.causal.production-deployment-runbooks.v1";
pub const production_deployment_runbooks_schema_version: u32 = 1;
pub const aggregation_contract_schema = "zigeffect.causal.production-artifact-aggregation.v1";
pub const durable_retention_contract_schema = "zigeffect.causal.durable-production-retention.v1";
pub const recommendation = "start-artifact-access-control";
pub const recommended_next_branch = "codex/zigeffect-causal-artifact-access-control";

const OutputFormat = enum { text, json };

const generated_by = "causal-production-deployment-runbooks";

const RunbookStep = struct {
    id: []const u8,
    actor: []const u8,
    action: []const u8,
    required_evidence: []const u8,
    failure_action: []const u8,
};

const Runbook = struct {
    id: []const u8,
    title: []const u8,
    purpose: []const u8,
    steps: []const RunbookStep,
};

const ReadinessGate = struct {
    id: []const u8,
    required: bool,
    description: []const u8,
    evidence: []const u8,
    failure_action: []const u8,
};

const IncidentTemplateField = struct {
    name: []const u8,
    required: bool,
    description: []const u8,
};

const deployment_steps: []const RunbookStep = &.{
    .{
        .id = "candidate-artifact-bundle",
        .actor = "release owner",
        .action = "select the reviewed production artifact aggregation bundle for the candidate build",
        .required_evidence = aggregation_contract_schema,
        .failure_action = "block deployment readiness",
    },
    .{
        .id = "durable-retention-ready",
        .actor = "release owner",
        .action = "confirm the candidate bundle is eligible for NenDB adapter retention and recovery review",
        .required_evidence = durable_retention_contract_schema,
        .failure_action = "block deployment readiness",
    },
    .{
        .id = "redaction-reviewed",
        .actor = "human reviewer",
        .action = "review shareable txt, json, and dot artifacts for secrets and obvious PII",
        .required_evidence = "redaction review note linked to the bundle",
        .failure_action = "keep artifacts local and block sharing",
    },
    .{
        .id = "pre-deploy-baseline",
        .actor = "release owner",
        .action = "capture or select the last known causal baseline before deployment execution",
        .required_evidence = "baseline artifact path and queryable event ids",
        .failure_action = "block deployment readiness",
    },
    .{
        .id = "human-approval",
        .actor = "deployment reviewer",
        .action = "approve deployment outside zigeffect authority with owner, reason, and rollback owner",
        .required_evidence = "reviewed approval record",
        .failure_action = "do not deploy",
    },
    .{
        .id = "external-deploy",
        .actor = "deployment system",
        .action = "execute deployment outside zigeffect; zigeffect records only the evidence boundary",
        .required_evidence = "external deployment record id",
        .failure_action = "do not mark deployed in causal records",
    },
    .{
        .id = "post-deploy-causal-check",
        .actor = "release owner",
        .action = "run post-deploy causal verification and link root, terminal, and remediation event ids",
        .required_evidence = "post-deploy causal report and verification commands",
        .failure_action = "open incident or rollback review",
    },
};

const rollback_steps: []const RunbookStep = &.{
    .{
        .id = "rollback-trigger-evidence",
        .actor = "incident owner",
        .action = "identify failed verification, incident trigger, or policy evidence requiring rollback review",
        .required_evidence = "triggering event ids and failed gate id",
        .failure_action = "continue observation without rollback claim",
    },
    .{
        .id = "last-good-reference",
        .actor = "release owner",
        .action = "select the last known good build, config, or runtime state from reviewed records",
        .required_evidence = "last-good bundle id or external release record",
        .failure_action = "block rollback readiness",
    },
    .{
        .id = "rollback-approval",
        .actor = "rollback reviewer",
        .action = "approve rollback outside zigeffect authority with owner and reason",
        .required_evidence = "reviewed rollback approval record",
        .failure_action = "do not roll back",
    },
    .{
        .id = "external-rollback",
        .actor = "deployment system",
        .action = "execute rollback outside zigeffect and preserve the external rollback record id",
        .required_evidence = "external rollback record id",
        .failure_action = "do not mark rollback applied in causal records",
    },
    .{
        .id = "after-rollback-verification",
        .actor = "incident owner",
        .action = "run causal verification after rollback and retain before, failed, rollback, and after evidence",
        .required_evidence = "after-rollback causal report and retained bundle",
        .failure_action = "keep incident open",
    },
};

const verification_steps: []const RunbookStep = &.{
    .{
        .id = "aggregation-report",
        .actor = "reviewer or agent",
        .action = "print the artifact aggregation contract and confirm candidate sources are described",
        .required_evidence = "zig build causal-production-artifact-aggregation",
        .failure_action = "mark verification incomplete",
    },
    .{
        .id = "durable-retention-report",
        .actor = "reviewer or agent",
        .action = "print the durable retention contract and confirm NenDB adapter retention gates",
        .required_evidence = "zig build causal-durable-production-retention",
        .failure_action = "mark verification incomplete",
    },
    .{
        .id = "schema-governance-report",
        .actor = "reviewer or agent",
        .action = "print schema governance and confirm strict schemas are current",
        .required_evidence = "zig build causal-schema-governance",
        .failure_action = "fail closed until schema governance is updated",
    },
    .{
        .id = "event-id-queryability",
        .actor = "reviewer or agent",
        .action = "verify root, terminal failure, remediation, and incident event ids are queryable",
        .required_evidence = "causal-query output for cited event ids",
        .failure_action = "do not claim causal evidence is complete",
    },
    .{
        .id = "limitation-notes",
        .actor = "reviewer or agent",
        .action = "record sampling, truncation, stale artifact, or missing source limitations",
        .required_evidence = "limitation note in the deployment or incident record",
        .failure_action = "block production-ready claim",
    },
};

const incident_steps: []const RunbookStep = &.{
    .{
        .id = "classify-severity-impact",
        .actor = "incident owner",
        .action = "classify severity, impact, affected service, and user-visible symptoms",
        .required_evidence = "incident template severity and impact fields",
        .failure_action = "keep incident untriaged",
    },
    .{
        .id = "link-causal-evidence",
        .actor = "incident owner",
        .action = "link triggering event ids, suspected cause ids, and aggregation bundle id",
        .required_evidence = "incident template event and bundle fields",
        .failure_action = "do not claim causal diagnosis",
    },
    .{
        .id = "choose-response",
        .actor = "incident reviewer",
        .action = "choose mitigation, rollback, observe, or escalate as a reviewed decision",
        .required_evidence = "response decision and reviewer reason",
        .failure_action = "continue manual triage",
    },
    .{
        .id = "verify-response",
        .actor = "incident owner",
        .action = "run verification commands and retain follow-up artifacts after the response",
        .required_evidence = "verification command output and follow-up artifact ids",
        .failure_action = "keep incident open",
    },
};

const runbooks: []const Runbook = &.{
    .{
        .id = "deployment",
        .title = "Manual Production Deployment",
        .purpose = "Review causal evidence before and after an external deployment without giving zigeffect deployment authority.",
        .steps = deployment_steps,
    },
    .{
        .id = "rollback",
        .title = "Manual Production Rollback",
        .purpose = "Review rollback evidence, execute rollback outside zigeffect, and retain before/after causal proof.",
        .steps = rollback_steps,
    },
    .{
        .id = "causal-verification",
        .title = "Causal Verification",
        .purpose = "Prove production claims with queryable event ids, schema governance, retention evidence, and limitation notes.",
        .steps = verification_steps,
    },
    .{
        .id = "incident-response",
        .title = "Causal Incident Response",
        .purpose = "Turn production incidents into structured causal records with owner, impact, evidence, decision, and verification fields.",
        .steps = incident_steps,
    },
};

const readiness_gates: []const ReadinessGate = &.{
    .{
        .id = "artifact-aggregation-current",
        .required = true,
        .description = "Candidate deploy, rollback, and incident records cite an aggregation bundle shaped by the production artifact aggregation contract.",
        .evidence = aggregation_contract_schema,
        .failure_action = "block deployment readiness",
    },
    .{
        .id = "durable-retention-current",
        .required = true,
        .description = "Candidate evidence is eligible for NenDB adapter retention and recovery review.",
        .evidence = durable_retention_contract_schema,
        .failure_action = "block deployment readiness",
    },
    .{
        .id = "redaction-reviewed",
        .required = true,
        .description = "Shareable artifacts pass redaction review before durable sharing or incident distribution.",
        .evidence = "reviewed redaction note",
        .failure_action = "retain locally only",
    },
    .{
        .id = "pre-deploy-baseline-present",
        .required = true,
        .description = "A pre-deploy baseline or last-good causal reference exists before deployment is executed externally.",
        .evidence = "baseline artifact path and queryable event ids",
        .failure_action = "block deployment readiness",
    },
    .{
        .id = "human-approval-present",
        .required = true,
        .description = "Deployment or rollback has named human owner, reviewer, reason, and rollback owner.",
        .evidence = "reviewed approval record",
        .failure_action = "do not deploy or roll back",
    },
    .{
        .id = "rollback-readiness-present",
        .required = true,
        .description = "A last-good build, config, or runtime state is known before production deployment is called ready.",
        .evidence = "last-good reference",
        .failure_action = "block deployment readiness",
    },
    .{
        .id = "post-action-verification-present",
        .required = true,
        .description = "After deploy, rollback, or mitigation, causal verification commands are recorded with event ids.",
        .evidence = "post-action causal report",
        .failure_action = "keep incident or release review open",
    },
    .{
        .id = "incident-owner-present",
        .required = true,
        .description = "Incident response records name owner, severity, impact, and follow-up artifact expectations.",
        .evidence = "incident template fields",
        .failure_action = "keep incident untriaged",
    },
};

const incident_template_fields: []const IncidentTemplateField = &.{
    .{ .name = "severity", .required = true, .description = "Impact level such as sev1, sev2, sev3, or advisory." },
    .{ .name = "impact", .required = true, .description = "User-visible, service, data, or developer impact summary." },
    .{ .name = "owner", .required = true, .description = "Human incident owner accountable for triage and closure." },
    .{ .name = "reviewer", .required = true, .description = "Human reviewer for mitigation, rollback, or escalation decisions." },
    .{ .name = "triggering_event_ids", .required = true, .description = "Causal event ids that triggered the incident or failed verification." },
    .{ .name = "suspected_cause_ids", .required = true, .description = "Queryable event ids or finding ids currently believed to explain the incident." },
    .{ .name = "artifact_bundle_id", .required = true, .description = "Aggregation or retained bundle id containing incident evidence." },
    .{ .name = "response_decision", .required = true, .description = "Reviewed decision: mitigate, rollback, observe, or escalate." },
    .{ .name = "mitigation", .required = true, .description = "Manual mitigation summary and external record id when applicable." },
    .{ .name = "rollback_decision", .required = true, .description = "Rollback status, owner, and reason, even when rollback is declined." },
    .{ .name = "follow_up_artifacts", .required = true, .description = "Artifacts or branch names that must exist after incident handling." },
    .{ .name = "verification_commands", .required = true, .description = "Commands that proved the response or documented remaining risk." },
};

const authority_boundaries: []const []const u8 = &.{
    "deployment execution stays outside zigeffect authority",
    "rollback execution stays outside zigeffect authority",
    "zigeffect records reviewed evidence and commands only",
    "applied deployment or rollback state cannot be inferred without external reviewed records",
    "durable evidence direction remains NenDB adapter only",
    "workbench direction remains SolidJS inside webui-dev/zig-webui",
};

const non_goals: []const []const u8 = &.{
    "Cockroach adapter work",
    "D1 or R2 adapter work",
    "direct upstream NenDB dependency",
    "live production telemetry ingestion",
    "deployment automation",
    "rollback automation",
    "production mutation authority",
    "alerting or paging",
    "RBAC enforcement",
    "encryption implementation",
    "React workbench support",
};

const verification_commands: []const []const u8 = &.{
    "cd packages/zigeffect",
    "zig build causal-production-deployment-runbooks",
    "zig build causal-production-deployment-runbooks -- --format json",
    "zig build causal-durable-production-retention",
    "zig build causal-production-artifact-aggregation",
    "zig build causal-production-hardening-backlog",
    "zig build causal-schema-governance",
    "zig build examples",
    "zig build test",
    "cd ../..",
    "bun run check",
    "bun run zig:test",
    "git diff --check",
};

fn usage() []const u8 {
    return
    \\Usage:
    \\  zig build causal-production-deployment-runbooks
    \\  zig build causal-production-deployment-runbooks -- --format text
    \\  zig build causal-production-deployment-runbooks -- --format json
    \\
    ;
}

fn parseOptions(args: []const []const u8) !OutputFormat {
    if (args.len == 1) return .text;
    if (args.len == 2 and std.mem.eql(u8, args[1], "--format")) return error.MissingFormat;
    if (args.len != 3) return error.UnknownFlag;
    if (!std.mem.eql(u8, args[1], "--format")) return error.UnknownFlag;
    if (args[2].len == 0) return error.MissingFormat;
    if (std.mem.eql(u8, args[2], "text")) return .text;
    if (std.mem.eql(u8, args[2], "json")) return .json;
    return error.UnknownFormat;
}

pub fn formatProductionDeploymentRunbooksText(allocator: std.mem.Allocator) std.mem.Allocator.Error![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "zigeffect causal production deployment runbooks\n");
    try output.print(allocator, "schema: {s}\n", .{production_deployment_runbooks_schema});
    try output.print(allocator, "schema_version: {d}\n", .{production_deployment_runbooks_schema_version});
    try output.appendSlice(allocator, "status: current\n");
    try output.print(allocator, "generated by: {s}\n", .{generated_by});
    try output.print(allocator, "aggregation contract: {s}\n", .{aggregation_contract_schema});
    try output.print(allocator, "durable retention contract: {s}\n", .{durable_retention_contract_schema});
    try output.print(allocator, "recommendation: {s}\n", .{recommendation});
    try output.print(allocator, "recommended next branch: {s}\n", .{recommended_next_branch});

    try output.appendSlice(allocator, "\nrunbooks:\n");
    for (runbooks) |runbook| {
        try output.print(allocator, "- {s}: {s}\n", .{ runbook.id, runbook.title });
        try output.print(allocator, "  purpose: {s}\n", .{runbook.purpose});
        try output.appendSlice(allocator, "  steps:\n");
        for (runbook.steps) |step| {
            try output.print(allocator, "  - {s}\n", .{step.id});
            try output.print(allocator, "    actor: {s}\n", .{step.actor});
            try output.print(allocator, "    action: {s}\n", .{step.action});
            try output.print(allocator, "    required evidence: {s}\n", .{step.required_evidence});
            try output.print(allocator, "    failure action: {s}\n", .{step.failure_action});
        }
    }

    try output.appendSlice(allocator, "\nreadiness gates:\n");
    for (readiness_gates) |gate| {
        try output.print(allocator, "- {s}\n", .{gate.id});
        try output.print(allocator, "  required: {}\n", .{gate.required});
        try output.print(allocator, "  description: {s}\n", .{gate.description});
        try output.print(allocator, "  evidence: {s}\n", .{gate.evidence});
        try output.print(allocator, "  failure action: {s}\n", .{gate.failure_action});
    }

    try output.appendSlice(allocator, "\nincident_template:\n");
    for (incident_template_fields) |field| {
        try output.print(allocator, "- {s}\n", .{field.name});
        try output.print(allocator, "  required: {}\n", .{field.required});
        try output.print(allocator, "  description: {s}\n", .{field.description});
    }

    try output.appendSlice(allocator, "\nauthority boundaries:\n");
    for (authority_boundaries) |boundary| {
        try output.print(allocator, "- {s}\n", .{boundary});
    }

    try output.appendSlice(allocator, "\nnon-goals:\n");
    for (non_goals) |goal| {
        try output.print(allocator, "- {s}\n", .{goal});
    }

    try output.appendSlice(allocator, "\nverification commands:\n");
    for (verification_commands) |command| {
        try output.print(allocator, "- {s}\n", .{command});
    }

    return output.toOwnedSlice(allocator);
}

pub fn formatProductionDeploymentRunbooksJson(allocator: std.mem.Allocator) std.mem.Allocator.Error![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "{\n");
    try appendJsonStringProperty(allocator, &output, "schema", production_deployment_runbooks_schema, true);
    try appendJsonU32Property(allocator, &output, "schema_version", production_deployment_runbooks_schema_version, true);
    try appendJsonStringProperty(allocator, &output, "status", "current", true);
    try appendJsonStringProperty(allocator, &output, "generated_by", generated_by, true);
    try appendJsonStringProperty(allocator, &output, "aggregation_contract_schema", aggregation_contract_schema, true);
    try appendJsonStringProperty(allocator, &output, "durable_retention_contract_schema", durable_retention_contract_schema, true);
    try appendJsonStringProperty(allocator, &output, "recommendation", recommendation, true);
    try appendJsonStringProperty(allocator, &output, "recommended_next_branch", recommended_next_branch, true);

    try output.appendSlice(allocator, "  \"runbooks\": [\n");
    for (runbooks, 0..) |runbook, runbook_index| {
        try output.appendSlice(allocator, "    {\n");
        try appendJsonStringProperty(allocator, &output, "id", runbook.id, true);
        try appendJsonStringProperty(allocator, &output, "title", runbook.title, true);
        try appendJsonStringProperty(allocator, &output, "purpose", runbook.purpose, true);
        try output.appendSlice(allocator, "      \"steps\": [\n");
        for (runbook.steps, 0..) |step, step_index| {
            try output.appendSlice(allocator, "        {\n");
            try appendJsonStringProperty(allocator, &output, "id", step.id, true);
            try appendJsonStringProperty(allocator, &output, "actor", step.actor, true);
            try appendJsonStringProperty(allocator, &output, "action", step.action, true);
            try appendJsonStringProperty(allocator, &output, "required_evidence", step.required_evidence, true);
            try appendJsonStringProperty(allocator, &output, "failure_action", step.failure_action, false);
            try output.appendSlice(allocator, if (step_index + 1 == runbook.steps.len) "        }\n" else "        },\n");
        }
        try output.appendSlice(allocator, "      ]\n");
        try output.appendSlice(allocator, if (runbook_index + 1 == runbooks.len) "    }\n" else "    },\n");
    }
    try output.appendSlice(allocator, "  ],\n");

    try output.appendSlice(allocator, "  \"readiness_gates\": [\n");
    for (readiness_gates, 0..) |gate, index| {
        try output.appendSlice(allocator, "    {\n");
        try appendJsonStringProperty(allocator, &output, "id", gate.id, true);
        try appendJsonBoolProperty(allocator, &output, "required", gate.required, true);
        try appendJsonStringProperty(allocator, &output, "description", gate.description, true);
        try appendJsonStringProperty(allocator, &output, "evidence", gate.evidence, true);
        try appendJsonStringProperty(allocator, &output, "failure_action", gate.failure_action, false);
        try output.appendSlice(allocator, if (index + 1 == readiness_gates.len) "    }\n" else "    },\n");
    }
    try output.appendSlice(allocator, "  ],\n");

    try output.appendSlice(allocator, "  \"incident_template\": [\n");
    for (incident_template_fields, 0..) |field, index| {
        try output.appendSlice(allocator, "    {\n");
        try appendJsonStringProperty(allocator, &output, "name", field.name, true);
        try appendJsonBoolProperty(allocator, &output, "required", field.required, true);
        try appendJsonStringProperty(allocator, &output, "description", field.description, false);
        try output.appendSlice(allocator, if (index + 1 == incident_template_fields.len) "    }\n" else "    },\n");
    }
    try output.appendSlice(allocator, "  ],\n");

    try appendJsonStringArrayProperty(allocator, &output, "authority_boundaries", authority_boundaries, true);
    try appendJsonStringArrayProperty(allocator, &output, "non_goals", non_goals, true);
    try appendJsonStringArrayProperty(allocator, &output, "verification_commands", verification_commands, false);
    try output.appendSlice(allocator, "}\n");

    return output.toOwnedSlice(allocator);
}

fn appendJsonStringProperty(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    name: []const u8,
    value: []const u8,
    trailing: bool,
) std.mem.Allocator.Error!void {
    try output.appendSlice(allocator, "  \"");
    try output.appendSlice(allocator, name);
    try output.appendSlice(allocator, "\": ");
    try appendJsonString(allocator, output, value);
    try output.appendSlice(allocator, if (trailing) ",\n" else "\n");
}

fn appendJsonBoolProperty(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    name: []const u8,
    value: bool,
    trailing: bool,
) std.mem.Allocator.Error!void {
    try output.appendSlice(allocator, "  \"");
    try output.appendSlice(allocator, name);
    try output.appendSlice(allocator, "\": ");
    try output.appendSlice(allocator, if (value) "true" else "false");
    try output.appendSlice(allocator, if (trailing) ",\n" else "\n");
}

fn appendJsonU32Property(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    name: []const u8,
    value: u32,
    trailing: bool,
) std.mem.Allocator.Error!void {
    try output.print(allocator, "  \"{s}\": {d}", .{ name, value });
    try output.appendSlice(allocator, if (trailing) ",\n" else "\n");
}

fn appendJsonStringArrayProperty(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    name: []const u8,
    values: []const []const u8,
    trailing: bool,
) std.mem.Allocator.Error!void {
    try output.print(allocator, "  \"{s}\": [", .{name});
    for (values, 0..) |value, index| {
        if (index > 0) try output.appendSlice(allocator, ", ");
        try appendJsonString(allocator, output, value);
    }
    try output.appendSlice(allocator, if (trailing) "],\n" else "]\n");
}

fn appendJsonString(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    value: []const u8,
) std.mem.Allocator.Error!void {
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

fn failUsage(err: anyerror) noreturn {
    std.debug.print("causal-production-deployment-runbooks error: {s}\n{s}", .{ @errorName(err), usage() });
    std.process.exit(1);
}

pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    const format = parseOptions(args) catch |err| failUsage(err);
    const report = switch (format) {
        .text => try formatProductionDeploymentRunbooksText(init.gpa),
        .json => try formatProductionDeploymentRunbooksJson(init.gpa),
    };
    defer init.gpa.free(report);

    std.debug.print("{s}", .{report});
}

fn expectRunbook(id: []const u8) !void {
    for (runbooks) |runbook| {
        if (std.mem.eql(u8, runbook.id, id)) return;
    }
    return error.MissingRunbook;
}

fn expectGate(id: []const u8, failure_action: []const u8) !void {
    for (readiness_gates) |gate| {
        if (std.mem.eql(u8, gate.id, id)) {
            try std.testing.expect(gate.required);
            try std.testing.expectEqualStrings(failure_action, gate.failure_action);
            return;
        }
    }
    return error.MissingGate;
}

fn expectIncidentTemplateField(name: []const u8) !void {
    for (incident_template_fields) |field| {
        if (std.mem.eql(u8, field.name, name)) {
            try std.testing.expect(field.required);
            return;
        }
    }
    return error.MissingIncidentTemplateField;
}

fn expectNonGoal(value: []const u8) !void {
    for (non_goals) |goal| {
        if (std.mem.eql(u8, goal, value)) return;
    }
    return error.MissingNonGoal;
}

test "production deployment runbooks metadata names schema contracts and next branch" {
    try std.testing.expectEqualStrings("zigeffect.causal.production-deployment-runbooks.v1", production_deployment_runbooks_schema);
    try std.testing.expectEqual(@as(u32, 1), production_deployment_runbooks_schema_version);
    try std.testing.expectEqualStrings("zigeffect.causal.production-artifact-aggregation.v1", aggregation_contract_schema);
    try std.testing.expectEqualStrings("zigeffect.causal.durable-production-retention.v1", durable_retention_contract_schema);
    try std.testing.expectEqualStrings("start-artifact-access-control", recommendation);
    try std.testing.expectEqualStrings("codex/zigeffect-causal-artifact-access-control", recommended_next_branch);
}

test "production deployment runbooks preserve required manual procedures and fail-closed gates" {
    try expectRunbook("deployment");
    try expectRunbook("rollback");
    try expectRunbook("causal-verification");
    try expectRunbook("incident-response");
    try expectGate("artifact-aggregation-current", "block deployment readiness");
    try expectGate("durable-retention-current", "block deployment readiness");
    try expectGate("human-approval-present", "do not deploy or roll back");
    try expectGate("post-action-verification-present", "keep incident or release review open");
    try expectIncidentTemplateField("triggering_event_ids");
    try expectIncidentTemplateField("artifact_bundle_id");
    try expectIncidentTemplateField("verification_commands");
    try expectNonGoal("Cockroach adapter work");
    try expectNonGoal("deployment automation");
    try expectNonGoal("production mutation authority");
    try expectNonGoal("React workbench support");
}

test "production deployment runbooks text includes required runbooks and gates" {
    const report = try formatProductionDeploymentRunbooksText(std.testing.allocator);
    defer std.testing.allocator.free(report);

    try std.testing.expect(std.mem.indexOf(u8, report, "schema: zigeffect.causal.production-deployment-runbooks.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "deployment") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "rollback") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "causal-verification") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "incident-response") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "failure action: block deployment readiness") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "production mutation authority") != null);
}

test "production deployment runbooks json includes schema contracts and incident template" {
    const report = try formatProductionDeploymentRunbooksJson(std.testing.allocator);
    defer std.testing.allocator.free(report);

    try std.testing.expect(std.mem.indexOf(u8, report, "\"schema\": \"zigeffect.causal.production-deployment-runbooks.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"aggregation_contract_schema\": \"zigeffect.causal.production-artifact-aggregation.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"durable_retention_contract_schema\": \"zigeffect.causal.durable-production-retention.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"incident_template\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "triggering_event_ids") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "verification_commands") != null);
}

test "production deployment runbooks options parse text json and errors" {
    try std.testing.expectEqual(OutputFormat.text, try parseOptions(&.{"zigeffect-causal-production-deployment-runbooks"}));
    try std.testing.expectEqual(OutputFormat.text, try parseOptions(&.{ "zigeffect-causal-production-deployment-runbooks", "--format", "text" }));
    try std.testing.expectEqual(OutputFormat.json, try parseOptions(&.{ "zigeffect-causal-production-deployment-runbooks", "--format", "json" }));
    try std.testing.expectError(error.UnknownFormat, parseOptions(&.{ "zigeffect-causal-production-deployment-runbooks", "--format", "yaml" }));
    try std.testing.expectError(error.MissingFormat, parseOptions(&.{ "zigeffect-causal-production-deployment-runbooks", "--format", "" }));
    try std.testing.expectError(error.MissingFormat, parseOptions(&.{ "zigeffect-causal-production-deployment-runbooks", "--format" }));
    try std.testing.expectError(error.UnknownFlag, parseOptions(&.{ "zigeffect-causal-production-deployment-runbooks", "--json" }));
}
