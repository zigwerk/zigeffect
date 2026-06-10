const std = @import("std");

pub const alerting_integrations_schema = "zigeffect.causal.alerting-integrations.v1";
pub const alerting_integrations_schema_version: u32 = 1;
pub const recommendation = "start-live-dashboard-streaming-workbench";
pub const recommended_next_branch = "codex/zigeffect-causal-live-dashboard-streaming-workbench";

const OutputFormat = enum { text, json };
const generated_by = "causal-alerting-integrations";

const IntegrationChannel = struct {
    id: []const u8,
    payload_class: []const u8,
    required_evidence: []const u8,
    redaction_posture: []const u8,
    delivery_mode: []const u8,
    mutation_posture: []const u8,
};

const SeverityPolicy = struct {
    severity: []const u8,
    meaning: []const u8,
    allowed_routes: []const []const u8,
    escalation_gate: []const u8,
};

const RoutingPolicy = struct {
    routing_class: []const u8,
    default_channels: []const []const u8,
    required_context: []const u8,
    blocked_without: []const u8,
};

const PayloadField = struct {
    name: []const u8,
    required: bool,
    description: []const u8,
};

const IntegrationFixture = struct {
    id: []const u8,
    channel: []const u8,
    severity: []const u8,
    routing_class: []const u8,
    payload_class: []const u8,
    delivery_state: []const u8,
    mutation_authority: []const u8,
    evidence_refs: []const []const u8,
};

const NegativeFixture = struct {
    id: []const u8,
    attempted_channel: []const u8,
    decision: []const u8,
    failed_gate: []const u8,
    reason: []const u8,
};

const source_contracts: []const []const u8 = &.{
    "zigeffect.causal.production-artifact-aggregation.v1",
    "zigeffect.causal.production-deployment-runbooks.v1",
    "zigeffect.causal.artifact-access-control.v1",
    "zigeffect.causal.encryption-at-rest-policy.v1",
    "zigeffect.causal.agent-query.v1",
};

const channels: []const IntegrationChannel = &.{
    .{
        .id = "slack",
        .payload_class = "chat-summary-preview",
        .required_evidence = "redacted finding ids and runbook gate",
        .redaction_posture = "redacted-summary-only",
        .delivery_mode = "record-only not-sent",
        .mutation_posture = "no message sent",
    },
    .{
        .id = "linear",
        .payload_class = "work-item-preview",
        .required_evidence = "release gate or incident finding ids",
        .redaction_posture = "redacted issue summary",
        .delivery_mode = "record-only not-created",
        .mutation_posture = "no issue created",
    },
    .{
        .id = "jira",
        .payload_class = "ticket-preview",
        .required_evidence = "incident runbook and reviewed evidence refs",
        .redaction_posture = "redacted ticket fields",
        .delivery_mode = "record-only not-created",
        .mutation_posture = "no ticket created",
    },
    .{
        .id = "siem",
        .payload_class = "security-event-preview",
        .required_evidence = "security-review routing and redacted event refs",
        .redaction_posture = "id-only security summary",
        .delivery_mode = "record-only not-forwarded",
        .mutation_posture = "no SIEM event sent",
    },
    .{
        .id = "paging",
        .payload_class = "critical-handoff-preview",
        .required_evidence = "critical severity, incident owner review, human approval evidence",
        .redaction_posture = "minimal incident summary",
        .delivery_mode = "record-only not-paged",
        .mutation_posture = "no page sent",
    },
};

const severity_names: []const []const u8 = &.{ "info", "warning", "error", "critical" };
const routing_class_names: []const []const u8 = &.{ "dev-loop", "ci-failure", "release-gate", "production-incident", "security-review" };

const severity_policy: []const SeverityPolicy = &.{
    .{
        .severity = "info",
        .meaning = "context useful for local and CI review",
        .allowed_routes = &.{ "dev-loop", "ci-failure" },
        .escalation_gate = "never pages",
    },
    .{
        .severity = "warning",
        .meaning = "non-terminal issue that should be reviewed before release",
        .allowed_routes = &.{ "ci-failure", "release-gate" },
        .escalation_gate = "release-owner review before external ticket preview",
    },
    .{
        .severity = "error",
        .meaning = "terminal failure or release gate violation",
        .allowed_routes = &.{ "ci-failure", "release-gate", "production-incident" },
        .escalation_gate = "incident or release context required",
    },
    .{
        .severity = "critical",
        .meaning = "incident-class failure that may require human escalation",
        .allowed_routes = &.{ "production-incident", "security-review" },
        .escalation_gate = "human approval evidence required before future live paging",
    },
};

const routing_policy: []const RoutingPolicy = &.{
    .{
        .routing_class = "dev-loop",
        .default_channels = &.{"slack"},
        .required_context = "local failure summary and bounded agent query refs",
        .blocked_without = "redacted summary",
    },
    .{
        .routing_class = "ci-failure",
        .default_channels = &.{ "slack", "linear" },
        .required_context = "CI verdict, event ids, finding ids, and artifact refs",
        .blocked_without = "causal CI evidence",
    },
    .{
        .routing_class = "release-gate",
        .default_channels = &.{ "linear", "jira" },
        .required_context = "release-owner review and deployment runbook gate",
        .blocked_without = "release gate evidence",
    },
    .{
        .routing_class = "production-incident",
        .default_channels = &.{ "jira", "paging" },
        .required_context = "incident runbook, reviewed retained bundle, and access decision",
        .blocked_without = "human incident approval",
    },
    .{
        .routing_class = "security-review",
        .default_channels = &.{ "siem", "paging" },
        .required_context = "security review, redacted event refs, and auditor-readable summary",
        .blocked_without = "redaction and visibility approval",
    },
};

const escalation_policy: []const []const u8 = &.{
    "paging requires severity=critical",
    "paging requires routing_class=production-incident or security-review",
    "paging requires human approval evidence",
    "paging requires redaction_state=reviewed",
    "record-only fixtures never send pages",
};

const dedupe_rules: []const []const u8 = &.{
    "dedupe_key includes routing_class, finding_id, and run_id when available",
    "suppression_state must be explicit before repeated previews are hidden",
    "critical paging handoff cannot be suppressed without human evidence",
};

const payload_fields: []const PayloadField = &.{
    .{ .name = "alert_record_id", .required = true, .description = "Stable id for the alert or integration preview record." },
    .{ .name = "source_contract_schema", .required = true, .description = "Schema that produced the source evidence." },
    .{ .name = "run_id", .required = true, .description = "Run scope that produced the alert-worthy finding." },
    .{ .name = "event_id", .required = true, .description = "Primary causal event id." },
    .{ .name = "finding_id", .required = true, .description = "Finding or cause id cited by the preview." },
    .{ .name = "severity", .required = true, .description = "Severity label from the deterministic policy." },
    .{ .name = "routing_class", .required = true, .description = "Routing class selected from causal context." },
    .{ .name = "channel", .required = true, .description = "Integration channel label." },
    .{ .name = "payload_class", .required = true, .description = "Preview payload class for the channel." },
    .{ .name = "redaction_state", .required = true, .description = "Redaction state before external handoff." },
    .{ .name = "visibility_class", .required = true, .description = "Access-control visibility class." },
    .{ .name = "evidence_refs", .required = true, .description = "Bounded ids and artifact refs, not raw payloads." },
    .{ .name = "dedupe_key", .required = true, .description = "Stable dedupe key for repeated findings." },
    .{ .name = "suppression_state", .required = true, .description = "Suppression status and cited approval." },
    .{ .name = "escalation_state", .required = true, .description = "Escalation readiness or blocked state." },
    .{ .name = "verification_command", .required = true, .description = "Command that generated or verified the preview." },
    .{ .name = "mutation_authority", .required = true, .description = "Always none for this contract." },
};

const integration_fixtures: []const IntegrationFixture = &.{
    .{
        .id = "slack-ci-failure-preview",
        .channel = "slack",
        .severity = "error",
        .routing_class = "ci-failure",
        .payload_class = "chat-summary-preview",
        .delivery_state = "not-sent",
        .mutation_authority = "none",
        .evidence_refs = &.{ "ci-verdict:failure", "event:failed-test", "finding:causal-ci" },
    },
    .{
        .id = "linear-release-gate-preview",
        .channel = "linear",
        .severity = "warning",
        .routing_class = "release-gate",
        .payload_class = "work-item-preview",
        .delivery_state = "not-created",
        .mutation_authority = "none",
        .evidence_refs = &.{ "runbook:release-gate", "finding:release-review", "artifact:summary" },
    },
    .{
        .id = "jira-production-incident-preview",
        .channel = "jira",
        .severity = "critical",
        .routing_class = "production-incident",
        .payload_class = "ticket-preview",
        .delivery_state = "not-created",
        .mutation_authority = "none",
        .evidence_refs = &.{ "runbook:incident", "access-decision:review-required", "bundle:retained-redacted" },
    },
    .{
        .id = "siem-security-review-preview",
        .channel = "siem",
        .severity = "critical",
        .routing_class = "security-review",
        .payload_class = "security-event-preview",
        .delivery_state = "not-forwarded",
        .mutation_authority = "none",
        .evidence_refs = &.{ "security-review:redacted", "event:policy-decision", "artifact:external-summary" },
    },
    .{
        .id = "paging-critical-incident-handoff",
        .channel = "paging",
        .severity = "critical",
        .routing_class = "production-incident",
        .payload_class = "critical-handoff-preview",
        .delivery_state = "not-sent",
        .mutation_authority = "none",
        .evidence_refs = &.{ "incident-owner:approved", "runbook:incident", "redaction:reviewed" },
    },
};

const negative_fixtures: []const NegativeFixture = &.{
    .{
        .id = "unredacted-payload-blocked",
        .attempted_channel = "slack",
        .decision = "block",
        .failed_gate = "redaction-reviewed",
        .reason = "external previews require redacted summaries",
    },
    .{
        .id = "missing-evidence-refs-blocked",
        .attempted_channel = "linear",
        .decision = "block",
        .failed_gate = "evidence-refs-present",
        .reason = "tickets need causal event and finding ids",
    },
    .{
        .id = "external-mutation-attempt-denied",
        .attempted_channel = "jira",
        .decision = "deny",
        .failed_gate = "mutation-authority-none",
        .reason = "record-only preview cannot create or update external tickets",
    },
    .{
        .id = "paging-without-human-approval-denied",
        .attempted_channel = "paging",
        .decision = "deny",
        .failed_gate = "human-approval-present",
        .reason = "future live paging requires reviewed human approval evidence",
    },
    .{
        .id = "secret-shaped-content-denied",
        .attempted_channel = "siem",
        .decision = "deny",
        .failed_gate = "secret-shaped-content-redacted",
        .reason = "secret-shaped content cannot leave zigeffect in integration previews",
    },
    .{
        .id = "agent-live-delivery-denied",
        .attempted_channel = "slack",
        .decision = "deny",
        .failed_gate = "agents-record-only",
        .reason = "agents may inspect previews but cannot send alerts",
    },
};

const authority_boundaries: []const []const u8 = &.{
    "integration records are previews and handoffs, not deliveries",
    "payloads cite ids and summaries, not raw request bodies prompts headers credentials tokens key material or PII",
    "agents may inspect alert records but cannot send messages create tickets forward SIEM events or page humans",
    "mutation authority remains none",
    "durable evidence direction remains NenDB adapter only",
    "workbench direction remains SolidJS inside webui-dev/zig-webui",
};

const non_goals: []const []const u8 = &.{
    "live Slack Linear Jira SIEM paging delivery",
    "network calls",
    "credential or token loading",
    "secret storage",
    "ticket or issue mutation",
    "paging humans from deterministic tests",
    "production telemetry ingestion",
    "Cockroach adapter work",
    "React workbench support",
    "production mutation authority",
};

const verification_commands: []const []const u8 = &.{
    "cd packages/zigeffect",
    "zig build causal-alerting-integrations",
    "zig build causal-alerting-integrations -- --format json",
    "zig build causal-schema-governance",
    "zig build causal-production-hardening-backlog",
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
    \\  zig build causal-alerting-integrations
    \\  zig build causal-alerting-integrations -- --format text
    \\  zig build causal-alerting-integrations -- --format json
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

pub fn formatAlertingIntegrationsText(allocator: std.mem.Allocator) std.mem.Allocator.Error![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "zigeffect causal alerting integrations\n");
    try output.print(allocator, "schema: {s}\n", .{alerting_integrations_schema});
    try output.print(allocator, "schema_version: {d}\n", .{alerting_integrations_schema_version});
    try output.appendSlice(allocator, "status: current\n");
    try output.print(allocator, "generated by: {s}\n", .{generated_by});
    try output.print(allocator, "recommendation: {s}\n", .{recommendation});
    try output.print(allocator, "recommended next branch: {s}\n", .{recommended_next_branch});
    try output.appendSlice(allocator, "mutation authority: none\n");

    try output.appendSlice(allocator, "\nsource contracts:\n");
    for (source_contracts) |contract| {
        try output.print(allocator, "- {s}\n", .{contract});
    }

    try output.appendSlice(allocator, "\nintegration channels:\n");
    for (channels) |channel| {
        try output.print(allocator, "- {s}\n", .{channel.id});
        try output.print(allocator, "  payload class: {s}\n", .{channel.payload_class});
        try output.print(allocator, "  required evidence: {s}\n", .{channel.required_evidence});
        try output.print(allocator, "  redaction posture: {s}\n", .{channel.redaction_posture});
        try output.print(allocator, "  delivery mode: {s}\n", .{channel.delivery_mode});
        try output.print(allocator, "  mutation posture: {s}\n", .{channel.mutation_posture});
    }

    try output.appendSlice(allocator, "\nseverity policy:\n");
    for (severity_policy) |policy| {
        try output.print(allocator, "- {s}\n", .{policy.severity});
        try output.print(allocator, "  meaning: {s}\n", .{policy.meaning});
        try output.appendSlice(allocator, "  allowed routes:");
        for (policy.allowed_routes) |route| try output.print(allocator, " {s}", .{route});
        try output.appendSlice(allocator, "\n");
        try output.print(allocator, "  escalation gate: {s}\n", .{policy.escalation_gate});
    }

    try output.appendSlice(allocator, "\nrouting policy:\n");
    for (routing_policy) |policy| {
        try output.print(allocator, "- {s}\n", .{policy.routing_class});
        try output.appendSlice(allocator, "  default channels:");
        for (policy.default_channels) |channel| try output.print(allocator, " {s}", .{channel});
        try output.appendSlice(allocator, "\n");
        try output.print(allocator, "  required context: {s}\n", .{policy.required_context});
        try output.print(allocator, "  blocked without: {s}\n", .{policy.blocked_without});
    }

    try output.appendSlice(allocator, "\nescalation policy:\n");
    for (escalation_policy) |policy| {
        try output.print(allocator, "- {s}\n", .{policy});
    }

    try output.appendSlice(allocator, "\ndedupe rules:\n");
    for (dedupe_rules) |rule| {
        try output.print(allocator, "- {s}\n", .{rule});
    }

    try output.appendSlice(allocator, "\npayload fields:\n");
    for (payload_fields) |field| {
        try output.print(allocator, "- {s}\n", .{field.name});
        try output.print(allocator, "  required: {}\n", .{field.required});
        try output.print(allocator, "  description: {s}\n", .{field.description});
    }

    try output.appendSlice(allocator, "\npreview fixtures:\n");
    for (integration_fixtures) |fixture| {
        try output.print(allocator, "- {s}\n", .{fixture.id});
        try output.print(allocator, "  channel: {s}\n", .{fixture.channel});
        try output.print(allocator, "  severity: {s}\n", .{fixture.severity});
        try output.print(allocator, "  routing class: {s}\n", .{fixture.routing_class});
        try output.print(allocator, "  payload class: {s}\n", .{fixture.payload_class});
        try output.print(allocator, "  delivery state: {s}\n", .{fixture.delivery_state});
        try output.print(allocator, "  mutation authority: {s}\n", .{fixture.mutation_authority});
        try output.appendSlice(allocator, "  evidence refs:");
        for (fixture.evidence_refs) |ref| try output.print(allocator, " {s}", .{ref});
        try output.appendSlice(allocator, "\n");
    }

    try output.appendSlice(allocator, "\nnegative fixtures:\n");
    for (negative_fixtures) |fixture| {
        try output.print(allocator, "- {s}\n", .{fixture.id});
        try output.print(allocator, "  attempted channel: {s}\n", .{fixture.attempted_channel});
        try output.print(allocator, "  decision: {s}\n", .{fixture.decision});
        try output.print(allocator, "  failed gate: {s}\n", .{fixture.failed_gate});
        try output.print(allocator, "  reason: {s}\n", .{fixture.reason});
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

pub fn formatAlertingIntegrationsJson(allocator: std.mem.Allocator) std.mem.Allocator.Error![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "{\n");
    try appendJsonStringProperty(allocator, &output, "schema", alerting_integrations_schema, true);
    try appendJsonU32Property(allocator, &output, "schema_version", alerting_integrations_schema_version, true);
    try appendJsonStringProperty(allocator, &output, "status", "current", true);
    try appendJsonStringProperty(allocator, &output, "generated_by", generated_by, true);
    try appendJsonStringArrayProperty(allocator, &output, "source_contracts", source_contracts, true);
    try appendJsonStringProperty(allocator, &output, "recommendation", recommendation, true);
    try appendJsonStringProperty(allocator, &output, "recommended_next_branch", recommended_next_branch, true);

    try output.appendSlice(allocator, "  \"integration_channels\": [\n");
    for (channels, 0..) |channel, index| {
        try output.appendSlice(allocator, "    {\n");
        try appendJsonStringProperty(allocator, &output, "id", channel.id, true);
        try appendJsonStringProperty(allocator, &output, "payload_class", channel.payload_class, true);
        try appendJsonStringProperty(allocator, &output, "required_evidence", channel.required_evidence, true);
        try appendJsonStringProperty(allocator, &output, "redaction_posture", channel.redaction_posture, true);
        try appendJsonStringProperty(allocator, &output, "delivery_mode", channel.delivery_mode, true);
        try appendJsonStringProperty(allocator, &output, "mutation_posture", channel.mutation_posture, false);
        try output.appendSlice(allocator, if (index + 1 == channels.len) "    }\n" else "    },\n");
    }
    try output.appendSlice(allocator, "  ],\n");

    try output.appendSlice(allocator, "  \"severity_policy\": [\n");
    for (severity_policy, 0..) |policy, index| {
        try output.appendSlice(allocator, "    {\n");
        try appendJsonStringProperty(allocator, &output, "severity", policy.severity, true);
        try appendJsonStringProperty(allocator, &output, "meaning", policy.meaning, true);
        try appendJsonStringArrayProperty(allocator, &output, "allowed_routes", policy.allowed_routes, true);
        try appendJsonStringProperty(allocator, &output, "escalation_gate", policy.escalation_gate, false);
        try output.appendSlice(allocator, if (index + 1 == severity_policy.len) "    }\n" else "    },\n");
    }
    try output.appendSlice(allocator, "  ],\n");

    try output.appendSlice(allocator, "  \"routing_policy\": [\n");
    for (routing_policy, 0..) |policy, index| {
        try output.appendSlice(allocator, "    {\n");
        try appendJsonStringProperty(allocator, &output, "routing_class", policy.routing_class, true);
        try appendJsonStringArrayProperty(allocator, &output, "default_channels", policy.default_channels, true);
        try appendJsonStringProperty(allocator, &output, "required_context", policy.required_context, true);
        try appendJsonStringProperty(allocator, &output, "blocked_without", policy.blocked_without, false);
        try output.appendSlice(allocator, if (index + 1 == routing_policy.len) "    }\n" else "    },\n");
    }
    try output.appendSlice(allocator, "  ],\n");

    try appendJsonStringArrayProperty(allocator, &output, "escalation_policy", escalation_policy, true);
    try appendJsonStringArrayProperty(allocator, &output, "dedupe_rules", dedupe_rules, true);

    try output.appendSlice(allocator, "  \"payload_fields\": [\n");
    for (payload_fields, 0..) |field, index| {
        try output.appendSlice(allocator, "    {\n");
        try appendJsonStringProperty(allocator, &output, "name", field.name, true);
        try appendJsonBoolProperty(allocator, &output, "required", field.required, true);
        try appendJsonStringProperty(allocator, &output, "description", field.description, false);
        try output.appendSlice(allocator, if (index + 1 == payload_fields.len) "    }\n" else "    },\n");
    }
    try output.appendSlice(allocator, "  ],\n");

    try output.appendSlice(allocator, "  \"preview_fixtures\": [\n");
    for (integration_fixtures, 0..) |fixture, index| {
        try output.appendSlice(allocator, "    {\n");
        try appendJsonStringProperty(allocator, &output, "id", fixture.id, true);
        try appendJsonStringProperty(allocator, &output, "channel", fixture.channel, true);
        try appendJsonStringProperty(allocator, &output, "severity", fixture.severity, true);
        try appendJsonStringProperty(allocator, &output, "routing_class", fixture.routing_class, true);
        try appendJsonStringProperty(allocator, &output, "payload_class", fixture.payload_class, true);
        try appendJsonStringProperty(allocator, &output, "delivery_state", fixture.delivery_state, true);
        try appendJsonStringProperty(allocator, &output, "mutation_authority", fixture.mutation_authority, true);
        try appendJsonStringArrayProperty(allocator, &output, "evidence_refs", fixture.evidence_refs, false);
        try output.appendSlice(allocator, if (index + 1 == integration_fixtures.len) "    }\n" else "    },\n");
    }
    try output.appendSlice(allocator, "  ],\n");

    try output.appendSlice(allocator, "  \"negative_fixtures\": [\n");
    for (negative_fixtures, 0..) |fixture, index| {
        try output.appendSlice(allocator, "    {\n");
        try appendJsonStringProperty(allocator, &output, "id", fixture.id, true);
        try appendJsonStringProperty(allocator, &output, "attempted_channel", fixture.attempted_channel, true);
        try appendJsonStringProperty(allocator, &output, "decision", fixture.decision, true);
        try appendJsonStringProperty(allocator, &output, "failed_gate", fixture.failed_gate, true);
        try appendJsonStringProperty(allocator, &output, "reason", fixture.reason, false);
        try output.appendSlice(allocator, if (index + 1 == negative_fixtures.len) "    }\n" else "    },\n");
    }
    try output.appendSlice(allocator, "  ],\n");

    try appendJsonStringProperty(allocator, &output, "mutation_authority", "none", true);
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
    std.debug.print("causal-alerting-integrations error: {s}\n{s}", .{ @errorName(err), usage() });
    std.process.exit(1);
}

pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    const format = parseOptions(args) catch |err| failUsage(err);
    const report = switch (format) {
        .text => try formatAlertingIntegrationsText(init.gpa),
        .json => try formatAlertingIntegrationsJson(init.gpa),
    };
    defer init.gpa.free(report);

    std.debug.print("{s}", .{report});
}

fn expectSourceContract(schema: []const u8) !void {
    for (source_contracts) |contract| {
        if (std.mem.eql(u8, contract, schema)) return;
    }
    return error.MissingSourceContract;
}

fn expectChannel(id: []const u8) !void {
    for (channels) |channel| {
        if (std.mem.eql(u8, channel.id, id)) return;
    }
    return error.MissingChannel;
}

fn expectSeverity(name: []const u8) !void {
    for (severity_names) |severity| {
        if (std.mem.eql(u8, severity, name)) return;
    }
    return error.MissingSeverity;
}

fn expectRoutingClass(name: []const u8) !void {
    for (routing_class_names) |routing_class| {
        if (std.mem.eql(u8, routing_class, name)) return;
    }
    return error.MissingRoutingClass;
}

fn expectPayloadField(name: []const u8) !void {
    for (payload_fields) |field| {
        if (std.mem.eql(u8, field.name, name)) {
            try std.testing.expect(field.required);
            return;
        }
    }
    return error.MissingPayloadField;
}

fn expectFixture(id: []const u8) !void {
    for (integration_fixtures) |fixture| {
        if (std.mem.eql(u8, fixture.id, id)) {
            try std.testing.expectEqualStrings("none", fixture.mutation_authority);
            return;
        }
    }
    return error.MissingFixture;
}

fn expectNegativeFixture(id: []const u8) !void {
    for (negative_fixtures) |fixture| {
        if (std.mem.eql(u8, fixture.id, id)) {
            try std.testing.expect(std.mem.eql(u8, fixture.decision, "block") or std.mem.eql(u8, fixture.decision, "deny"));
            return;
        }
    }
    return error.MissingNegativeFixture;
}

fn expectNonGoal(value: []const u8) !void {
    for (non_goals) |goal| {
        if (std.mem.eql(u8, goal, value)) return;
    }
    return error.MissingNonGoal;
}

test "alerting integrations metadata names schema source contracts and next branch" {
    try std.testing.expectEqualStrings("zigeffect.causal.alerting-integrations.v1", alerting_integrations_schema);
    try std.testing.expectEqual(@as(u32, 1), alerting_integrations_schema_version);
    try expectSourceContract("zigeffect.causal.production-artifact-aggregation.v1");
    try expectSourceContract("zigeffect.causal.production-deployment-runbooks.v1");
    try expectSourceContract("zigeffect.causal.artifact-access-control.v1");
    try expectSourceContract("zigeffect.causal.encryption-at-rest-policy.v1");
    try expectSourceContract("zigeffect.causal.agent-query.v1");
    try std.testing.expectEqualStrings("start-live-dashboard-streaming-workbench", recommendation);
    try std.testing.expectEqualStrings("codex/zigeffect-causal-live-dashboard-streaming-workbench", recommended_next_branch);
}

test "alerting integrations preserves channels severity routing fixtures and non-goals" {
    try expectChannel("slack");
    try expectChannel("linear");
    try expectChannel("jira");
    try expectChannel("siem");
    try expectChannel("paging");
    try expectSeverity("critical");
    try expectRoutingClass("production-incident");
    try expectPayloadField("alert_record_id");
    try expectPayloadField("dedupe_key");
    try expectFixture("slack-ci-failure-preview");
    try expectFixture("linear-release-gate-preview");
    try expectFixture("jira-production-incident-preview");
    try expectFixture("siem-security-review-preview");
    try expectFixture("paging-critical-incident-handoff");
    try expectNegativeFixture("unredacted-payload-blocked");
    try expectNegativeFixture("paging-without-human-approval-denied");
    try expectNegativeFixture("agent-live-delivery-denied");
    try expectNonGoal("live Slack Linear Jira SIEM paging delivery");
    try expectNonGoal("network calls");
    try expectNonGoal("production mutation authority");
}

test "alerting integrations text report includes boundaries" {
    const report = try formatAlertingIntegrationsText(std.testing.allocator);
    defer std.testing.allocator.free(report);

    try std.testing.expect(std.mem.indexOf(u8, report, "schema: zigeffect.causal.alerting-integrations.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "integration channels:") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "paging-critical-incident-handoff") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "delivery state: not-sent") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "mutation authority: none") != null);
}

test "alerting integrations json report is machine readable" {
    const report = try formatAlertingIntegrationsJson(std.testing.allocator);
    defer std.testing.allocator.free(report);

    try std.testing.expect(std.mem.indexOf(u8, report, "\"schema\": \"zigeffect.causal.alerting-integrations.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"integration_channels\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"severity_policy\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"routing_policy\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"negative_fixtures\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"mutation_authority\": \"none\"") != null);
}

test "alerting integrations json report parses" {
    const ReportEnvelope = struct {
        schema: []const u8,
        schema_version: u32,
        mutation_authority: []const u8,
        recommended_next_branch: []const u8,
    };

    const report = try formatAlertingIntegrationsJson(std.testing.allocator);
    defer std.testing.allocator.free(report);

    var parsed = try std.json.parseFromSlice(ReportEnvelope, std.testing.allocator, report, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();

    try std.testing.expectEqualStrings(alerting_integrations_schema, parsed.value.schema);
    try std.testing.expectEqual(alerting_integrations_schema_version, parsed.value.schema_version);
    try std.testing.expectEqualStrings("none", parsed.value.mutation_authority);
    try std.testing.expectEqualStrings(recommended_next_branch, parsed.value.recommended_next_branch);
}

test "alerting integrations parses text json and errors" {
    try std.testing.expectEqual(OutputFormat.text, try parseOptions(&.{"zigeffect-causal-alerting-integrations"}));
    try std.testing.expectEqual(OutputFormat.text, try parseOptions(&.{ "zigeffect-causal-alerting-integrations", "--format", "text" }));
    try std.testing.expectEqual(OutputFormat.json, try parseOptions(&.{ "zigeffect-causal-alerting-integrations", "--format", "json" }));
    try std.testing.expectError(error.UnknownFormat, parseOptions(&.{ "zigeffect-causal-alerting-integrations", "--format", "yaml" }));
    try std.testing.expectError(error.MissingFormat, parseOptions(&.{ "zigeffect-causal-alerting-integrations", "--format", "" }));
    try std.testing.expectError(error.MissingFormat, parseOptions(&.{ "zigeffect-causal-alerting-integrations", "--format" }));
    try std.testing.expectError(error.UnknownFlag, parseOptions(&.{ "zigeffect-causal-alerting-integrations", "--json" }));
}
