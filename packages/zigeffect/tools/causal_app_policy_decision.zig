const std = @import("std");

const app_policy_schema = "zigeffect.causal.app-policy-decision.v1";
const app_audit_schema = "zigeffect.causal.app-remediation-audit.v1";
const default_policy_name = "local-app-remediation-policy-v1";
const default_evaluator = "local-app-policy-engine";

const reason_codes_eligible = [_][]const u8{"app-gates-proposal-eligible"};
const reason_codes_human_review = [_][]const u8{"app-high-risk-gate-review-required"};
const reason_codes_unknown_gate = [_][]const u8{"unknown-app-policy-gate"};
const reason_codes_audit_not_pending = [_][]const u8{"app-audit-not-pending"};
const reason_codes_gate_mismatch = [_][]const u8{"app-policy-gate-mismatch"};

const policy_guardrails = [_][]const u8{
    "Policy approval is advisory and does not apply app source, config, migrations, operations, or rollback actions.",
    "Mutation authority remains none; app changes require a later reviewed proposal and application artifact.",
};

const Options = struct {
    mode: []const u8,
    audit_path: []const u8,
    policy: []const u8 = default_policy_name,
    evaluated_by: []const u8 = default_evaluator,
    out_prefix: ?[]const u8 = null,
};

const OutputPaths = struct {
    json_path: []const u8,
    text_path: []const u8,

    fn deinit(self: OutputPaths, allocator: std.mem.Allocator) void {
        allocator.free(self.json_path);
        allocator.free(self.text_path);
    }
};

const AuditSource = struct {
    app_artifact: []const u8,
    advice: []const u8,
};

const AuditIncident = struct {
    action: []const u8,
    event_id: u64,
    event_kind: []const u8,
    label: []const u8,
    subsystem: []const u8,
    fix_category: []const u8,
    policy_gate: []const u8,
    query_commands: []const []const u8 = &.{},
};

const AppAuditRecord = struct {
    schema: []const u8,
    schema_version: u32,
    mode: []const u8,
    target: []const u8,
    source: AuditSource,
    approval_status: []const u8,
    applied: bool,
    mutation_authority: []const u8,
    incident_count: usize,
    incidents: []const AuditIncident,
    policy_gates: []const []const u8,
    verification_commands: []const []const u8,
    claim_guardrails: []const []const u8 = &.{},
};

const AppPolicyDecision = enum {
    approve,
    reject,
    needs_human_review,
};

const GateStatus = enum {
    allow_proposal,
    human_review_required,
    blocked,
};

const GateResult = struct {
    gate: []const u8,
    status: GateStatus,
    detail: []const u8,
};

const AppPolicyInput = struct {
    options: Options,
    audit_path: []const u8,
    audit: AppAuditRecord,
};

const AppPolicyResult = struct {
    decision: AppPolicyDecision,
    reason: []const u8,
    reason_codes: []const []const u8,
    mutation_authority: []const u8,
    applied: bool,
    target: []const u8,
    app_artifact: []const u8,
    event_ids: []const u64,
    required_verification_commands: []const []const u8,
    gate_results: []const GateResult,

    fn deinit(self: *AppPolicyResult, allocator: std.mem.Allocator) void {
        allocator.free(self.target);
        allocator.free(self.app_artifact);
        if (self.event_ids.len > 0) allocator.free(self.event_ids);
        freeStringSlice(allocator, self.required_verification_commands);
        for (self.gate_results) |result| allocator.free(result.gate);
        allocator.free(self.gate_results);
    }
};

const AppPolicyReports = struct {
    json: []const u8,
    text: []const u8,

    fn deinit(self: *AppPolicyReports, allocator: std.mem.Allocator) void {
        allocator.free(self.json);
        allocator.free(self.text);
    }
};

const source_config_audit_json =
    \\{
    \\  "schema": "zigeffect.causal.app-remediation-audit.v1",
    \\  "schema_version": 1,
    \\  "mode": "local",
    \\  "target": "yachdee-platform",
    \\  "proposer": "local-agent",
    \\  "source": {
    \\    "app_artifact": ".zig-cache/causal-artifacts/app.json",
    \\    "advice": "inline-generated"
    \\  },
    \\  "approval_status": "pending",
    \\  "applied": false,
    \\  "mutation_authority": "none",
    \\  "incident_count": 2,
    \\  "incidents": [
    \\    {"action":"fix-app-config","event_id":2,"event_kind":"assertion_recorded","label":"YACHDEE_ENV","subsystem":"app_config","fix_category":"config-or-secret-binding","policy_gate":"config-only","query_commands":["zig build causal-query -- --file .zig-cache/causal-artifacts/app.json cause 2"]},
    \\    {"action":"wire-app-requirement","event_id":3,"event_kind":"assertion_recorded","label":"HealthService","subsystem":"app_service_layer","fix_category":"service-provider-or-layer","policy_gate":"source-only","query_commands":["zig build causal-query -- --file .zig-cache/causal-artifacts/app.json cause 3"]}
    \\  ],
    \\  "policy_gates": ["config-only", "source-only"],
    \\  "verification_commands": ["zig build causal-query -- --file .zig-cache/causal-artifacts/app.json cause 2"],
    \\  "claim_guardrails": ["Do not claim an app fix without rerunning the app request/job scenario."]
    \\}
;

const migration_audit_json =
    \\{
    \\  "schema": "zigeffect.causal.app-remediation-audit.v1",
    \\  "schema_version": 1,
    \\  "mode": "local",
    \\  "target": "yachdee-platform",
    \\  "source": {"app_artifact": ".zig-cache/causal-artifacts/app.json", "advice": "inline-generated"},
    \\  "approval_status": "pending",
    \\  "applied": false,
    \\  "mutation_authority": "none",
    \\  "incident_count": 1,
    \\  "incidents": [
    \\    {"action":"inspect-app-response-failure","event_id":4,"event_kind":"span_recorded","label":"app.response","subsystem":"app_request_path","fix_category":"migration-or-data-fix","policy_gate":"migration-required","query_commands":[]}
    \\  ],
    \\  "policy_gates": ["migration-required"],
    \\  "verification_commands": ["zig build causal-query -- --file .zig-cache/causal-artifacts/app.json cause 4"],
    \\  "claim_guardrails": []
    \\}
;

const unknown_gate_audit_json =
    \\{
    \\  "schema": "zigeffect.causal.app-remediation-audit.v1",
    \\  "schema_version": 1,
    \\  "mode": "local",
    \\  "target": "yachdee-platform",
    \\  "source": {"app_artifact": ".zig-cache/causal-artifacts/app.json", "advice": "inline-generated"},
    \\  "approval_status": "pending",
    \\  "applied": false,
    \\  "mutation_authority": "none",
    \\  "incident_count": 1,
    \\  "incidents": [
    \\    {"action":"inspect-app-response-failure","event_id":4,"event_kind":"span_recorded","label":"app.response","subsystem":"app_request_path","fix_category":"unknown","policy_gate":"database-maybe","query_commands":[]}
    \\  ],
    \\  "policy_gates": ["database-maybe"],
    \\  "verification_commands": [],
    \\  "claim_guardrails": []
    \\}
;

const applied_audit_json =
    \\{
    \\  "schema": "zigeffect.causal.app-remediation-audit.v1",
    \\  "schema_version": 1,
    \\  "mode": "local",
    \\  "target": "yachdee-platform",
    \\  "source": {"app_artifact": ".zig-cache/causal-artifacts/app.json", "advice": "inline-generated"},
    \\  "approval_status": "pending",
    \\  "applied": true,
    \\  "mutation_authority": "none",
    \\  "incident_count": 1,
    \\  "incidents": [
    \\    {"action":"fix-app-config","event_id":2,"event_kind":"assertion_recorded","label":"YACHDEE_ENV","subsystem":"app_config","fix_category":"config-or-secret-binding","policy_gate":"config-only","query_commands":[]}
    \\  ],
    \\  "policy_gates": ["config-only"],
    \\  "verification_commands": [],
    \\  "claim_guardrails": []
    \\}
;

fn usage() []const u8 {
    return "usage: zig build causal-app-policy-decision -- local --audit <app-remediation-audit-json> [--policy <policy>] [--by <actor>] [--out-prefix <path-prefix>]\n";
}

fn parseOptions(args: []const []const u8) !Options {
    if (args.len < 2) return error.MissingMode;
    if (!std.mem.eql(u8, args[1], "local")) return error.UnknownMode;

    var audit_path: ?[]const u8 = null;
    var policy: []const u8 = default_policy_name;
    var evaluated_by: []const u8 = default_evaluator;
    var out_prefix: ?[]const u8 = null;

    var index: usize = 2;
    while (index < args.len) {
        const arg = args[index];
        if (!std.mem.startsWith(u8, arg, "--")) return error.UnknownArgument;
        if (index + 1 >= args.len) return error.MissingFlagValue;
        const value = args[index + 1];
        if (std.mem.eql(u8, arg, "--audit")) {
            audit_path = value;
        } else if (std.mem.eql(u8, arg, "--policy")) {
            if (!std.mem.eql(u8, value, default_policy_name)) return error.UnknownPolicy;
            policy = value;
        } else if (std.mem.eql(u8, arg, "--by")) {
            evaluated_by = value;
        } else if (std.mem.eql(u8, arg, "--out-prefix")) {
            out_prefix = value;
        } else {
            return error.UnknownFlag;
        }
        index += 2;
    }

    return .{
        .mode = "local",
        .audit_path = audit_path orelse return error.MissingAudit,
        .policy = policy,
        .evaluated_by = evaluated_by,
        .out_prefix = out_prefix,
    };
}

fn outputPathsForOptions(allocator: std.mem.Allocator, options: Options) !OutputPaths {
    const prefix = if (options.out_prefix) |out_prefix|
        try allocator.dupe(u8, out_prefix)
    else blk: {
        if (!std.mem.endsWith(u8, options.audit_path, ".json")) return error.InvalidArtifactPath;
        break :blk try allocator.dupe(u8, options.audit_path[0 .. options.audit_path.len - ".json".len]);
    };
    defer allocator.free(prefix);

    return .{
        .json_path = try std.fmt.allocPrint(allocator, "{s}-app-policy-decision.json", .{prefix}),
        .text_path = try std.fmt.allocPrint(allocator, "{s}-app-policy-decision.txt", .{prefix}),
    };
}

fn parseAppAudit(allocator: std.mem.Allocator, json: []const u8) !std.json.Parsed(AppAuditRecord) {
    var parsed = try std.json.parseFromSlice(AppAuditRecord, allocator, json, .{ .ignore_unknown_fields = true });
    errdefer parsed.deinit();
    try validateAppAudit(parsed.value);
    return parsed;
}

fn validateAppAudit(audit: AppAuditRecord) !void {
    if (!std.mem.eql(u8, audit.schema, app_audit_schema)) return error.UnsupportedAppAuditSchema;
    if (audit.schema_version != 1) return error.UnsupportedAppAuditSchema;
    if (!std.mem.eql(u8, audit.mode, "local")) return error.UnsupportedAppAuditSchema;
}

fn evaluateAppPolicy(allocator: std.mem.Allocator, input: AppPolicyInput) !AppPolicyResult {
    const gates = try collectUniqueGates(allocator, input.audit);
    defer allocator.free(gates);

    var gate_results = std.ArrayList(GateResult).empty;
    errdefer {
        for (gate_results.items) |result| allocator.free(result.gate);
        gate_results.deinit(allocator);
    }

    var has_blocked_gate = false;
    var has_human_review_gate = false;
    for (gates) |gate| {
        const result = evaluateGate(gate);
        if (result.status == .blocked) has_blocked_gate = true;
        if (result.status == .human_review_required) has_human_review_gate = true;
        try gate_results.append(allocator, result);
    }

    var audit_not_pending = false;
    if (!std.mem.eql(u8, input.audit.approval_status, "pending") or
        input.audit.applied or
        !std.mem.eql(u8, input.audit.mutation_authority, "none"))
    {
        audit_not_pending = true;
    }

    var gate_mismatch = false;
    for (input.audit.incidents) |incident| {
        if (!containsString(input.audit.policy_gates, incident.policy_gate)) {
            gate_mismatch = true;
            break;
        }
    }

    const decision: AppPolicyDecision = if (audit_not_pending or has_blocked_gate or gate_mismatch)
        .reject
    else if (has_human_review_gate)
        .needs_human_review
    else
        .approve;

    const reason_codes: []const []const u8 = if (audit_not_pending)
        reason_codes_audit_not_pending[0..]
    else if (gate_mismatch)
        reason_codes_gate_mismatch[0..]
    else if (has_blocked_gate)
        reason_codes_unknown_gate[0..]
    else if (has_human_review_gate)
        reason_codes_human_review[0..]
    else
        reason_codes_eligible[0..];

    const reason: []const u8 = if (audit_not_pending)
        "app audit must remain pending, unapplied, and mutation_authority=none"
    else if (gate_mismatch)
        "app audit top-level policy_gates must include every incident gate"
    else if (has_blocked_gate)
        "app audit contains an unknown policy gate"
    else if (has_human_review_gate)
        "app audit contains high-risk gates that require human review"
    else
        "app audit is eligible for proposal drafting";

    const event_ids = try duplicateEventIds(allocator, input.audit.incidents);
    errdefer if (event_ids.len > 0) allocator.free(event_ids);
    const verification = try duplicateStringSlice(allocator, input.audit.verification_commands);
    errdefer freeStringSlice(allocator, verification);
    const target = try allocator.dupe(u8, input.audit.target);
    errdefer allocator.free(target);
    const app_artifact = try allocator.dupe(u8, input.audit.source.app_artifact);
    errdefer allocator.free(app_artifact);

    return .{
        .decision = decision,
        .reason = reason,
        .reason_codes = reason_codes,
        .mutation_authority = "none",
        .applied = false,
        .target = target,
        .app_artifact = app_artifact,
        .event_ids = event_ids,
        .required_verification_commands = verification,
        .gate_results = try gate_results.toOwnedSlice(allocator),
    };
}

fn evaluateGate(gate: []const u8) GateResult {
    if (std.mem.eql(u8, gate, "source-only")) return .{
        .gate = gate,
        .status = .allow_proposal,
        .detail = "source-only app patch proposal may be drafted",
    };
    if (std.mem.eql(u8, gate, "config-only")) return .{
        .gate = gate,
        .status = .allow_proposal,
        .detail = "configuration proposal may be drafted without exposing secrets",
    };
    if (std.mem.eql(u8, gate, "migration-required")) return .{
        .gate = gate,
        .status = .human_review_required,
        .detail = "migration plan requires human review before proposals proceed",
    };
    if (std.mem.eql(u8, gate, "operational-human-required")) return .{
        .gate = gate,
        .status = .human_review_required,
        .detail = "operator-run action or runbook requires human review",
    };
    if (std.mem.eql(u8, gate, "rollback-required")) return .{
        .gate = gate,
        .status = .human_review_required,
        .detail = "rollback plan requires human review before proposals proceed",
    };
    return .{
        .gate = gate,
        .status = .blocked,
        .detail = "unknown app policy gate",
    };
}

fn collectUniqueGates(allocator: std.mem.Allocator, audit: AppAuditRecord) ![]const []const u8 {
    var gates = std.ArrayList([]const u8).empty;
    errdefer {
        for (gates.items) |gate| allocator.free(gate);
        gates.deinit(allocator);
    }

    for (audit.policy_gates) |gate| {
        if (!containsString(gates.items, gate)) try gates.append(allocator, try allocator.dupe(u8, gate));
    }
    for (audit.incidents) |incident| {
        if (!containsString(gates.items, incident.policy_gate)) try gates.append(allocator, try allocator.dupe(u8, incident.policy_gate));
    }

    return gates.toOwnedSlice(allocator);
}

fn duplicateEventIds(allocator: std.mem.Allocator, incidents: []const AuditIncident) ![]const u64 {
    var ids = std.ArrayList(u64).empty;
    errdefer ids.deinit(allocator);
    for (incidents) |incident| {
        var seen = false;
        for (ids.items) |id| {
            if (id == incident.event_id) {
                seen = true;
                break;
            }
        }
        if (!seen) try ids.append(allocator, incident.event_id);
    }
    return ids.toOwnedSlice(allocator);
}

fn duplicateStringSlice(allocator: std.mem.Allocator, values: []const []const u8) ![]const []const u8 {
    if (values.len == 0) return &.{};
    const copy = try allocator.alloc([]const u8, values.len);
    var copied: usize = 0;
    errdefer {
        for (copy[0..copied]) |item| allocator.free(item);
        allocator.free(copy);
    }
    for (values) |value| {
        copy[copied] = try allocator.dupe(u8, value);
        copied += 1;
    }
    return copy;
}

fn freeStringSlice(allocator: std.mem.Allocator, values: []const []const u8) void {
    if (values.len == 0) return;
    for (values) |value| allocator.free(value);
    allocator.free(values);
}

fn decisionText(decision: AppPolicyDecision) []const u8 {
    return switch (decision) {
        .approve => "approve",
        .reject => "reject",
        .needs_human_review => "needs-human-review",
    };
}

fn gateStatusText(status: GateStatus) []const u8 {
    return switch (status) {
        .allow_proposal => "allow-proposal",
        .human_review_required => "human-review-required",
        .blocked => "blocked",
    };
}

fn formatAppPolicyDecisionReports(allocator: std.mem.Allocator, input: AppPolicyInput) !AppPolicyReports {
    var result = try evaluateAppPolicy(allocator, input);
    defer result.deinit(allocator);

    const json = try formatAppPolicyDecisionJson(allocator, input, result);
    errdefer allocator.free(json);
    const text = try formatAppPolicyDecisionText(allocator, input, result);
    return .{ .json = json, .text = text };
}

fn formatAppPolicyDecisionJson(allocator: std.mem.Allocator, input: AppPolicyInput, result: AppPolicyResult) ![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "{\n");
    try output.appendSlice(allocator, "  \"schema\": ");
    try appendJsonString(allocator, &output, app_policy_schema);
    try output.appendSlice(allocator, ",\n  \"schema_version\": 1,\n");
    try output.appendSlice(allocator, "  \"mode\": ");
    try appendJsonString(allocator, &output, input.options.mode);
    try output.appendSlice(allocator, ",\n  \"target\": ");
    try appendJsonString(allocator, &output, result.target);
    try output.appendSlice(allocator, ",\n  \"decision\": ");
    try appendJsonString(allocator, &output, decisionText(result.decision));
    try output.appendSlice(allocator, ",\n  \"approval_status\": ");
    try appendJsonString(allocator, &output, decisionText(result.decision));
    try output.appendSlice(allocator, ",\n  \"evaluated_by\": ");
    try appendJsonString(allocator, &output, input.options.evaluated_by);
    try output.appendSlice(allocator, ",\n  \"policy\": ");
    try appendJsonString(allocator, &output, input.options.policy);
    try output.appendSlice(allocator, ",\n  \"reason\": ");
    try appendJsonString(allocator, &output, result.reason);
    try output.appendSlice(allocator, ",\n  \"reason_codes\": ");
    try appendStringArray(allocator, &output, result.reason_codes);
    try output.appendSlice(allocator, ",\n  \"mutation_authority\": ");
    try appendJsonString(allocator, &output, result.mutation_authority);
    try output.print(allocator, ",\n  \"applied\": {},\n", .{result.applied});
    try output.appendSlice(allocator, "  \"source\": {\n    \"app_remediation_audit\": ");
    try appendJsonString(allocator, &output, input.audit_path);
    try output.appendSlice(allocator, ",\n    \"app_artifact\": ");
    try appendJsonString(allocator, &output, result.app_artifact);
    try output.appendSlice(allocator, "\n  },\n  \"policy_gates\": ");
    try appendGateNamesJson(allocator, &output, result.gate_results);
    try output.appendSlice(allocator, ",\n  \"gate_results\": ");
    try appendGateResultsJson(allocator, &output, result.gate_results);
    try output.appendSlice(allocator, ",\n  \"event_ids\": ");
    try appendU64Array(allocator, &output, result.event_ids);
    try output.appendSlice(allocator, ",\n  \"required_verification_commands\": ");
    try appendStringArray(allocator, &output, result.required_verification_commands);
    try output.appendSlice(allocator, ",\n  \"guardrails\": ");
    try appendStringArray(allocator, &output, &policy_guardrails);
    try output.appendSlice(allocator, "\n}\n");

    return output.toOwnedSlice(allocator);
}

fn formatAppPolicyDecisionText(allocator: std.mem.Allocator, input: AppPolicyInput, result: AppPolicyResult) ![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "zigeffect app policy decision\n");
    try output.print(allocator, "schema: {s}\n", .{app_policy_schema});
    try output.print(allocator, "target: {s}\n", .{result.target});
    try output.print(allocator, "decision: {s}\n", .{decisionText(result.decision)});
    try output.print(allocator, "approval_status: {s}\n", .{decisionText(result.decision)});
    try output.print(allocator, "evaluated_by: {s}\n", .{input.options.evaluated_by});
    try output.print(allocator, "policy: {s}\n", .{input.options.policy});
    try output.print(allocator, "reason: {s}\n", .{result.reason});
    try output.print(allocator, "mutation_authority: {s}\n", .{result.mutation_authority});
    try output.print(allocator, "applied: {}\n\n", .{result.applied});

    try output.appendSlice(allocator, "source:\n");
    try output.print(allocator, "- app remediation audit: {s}\n", .{input.audit_path});
    try output.print(allocator, "- app artifact: {s}\n\n", .{result.app_artifact});

    try output.appendSlice(allocator, "policy gates:\n");
    for (result.gate_results) |gate| try output.print(allocator, "- {s} {s}: {s}\n", .{ gate.gate, gateStatusText(gate.status), gate.detail });

    try output.appendSlice(allocator, "\nevent ids:\n");
    for (result.event_ids) |id| try output.print(allocator, "- {d}\n", .{id});

    try output.appendSlice(allocator, "\nrequired verification commands:\n");
    for (result.required_verification_commands) |command| try output.print(allocator, "- {s}\n", .{command});

    try output.appendSlice(allocator, "\nguardrails:\n");
    for (policy_guardrails) |guardrail| try output.print(allocator, "- {s}\n", .{guardrail});

    return output.toOwnedSlice(allocator);
}

fn appendGateNamesJson(allocator: std.mem.Allocator, output: *std.ArrayList(u8), gates: []const GateResult) !void {
    try output.append(allocator, '[');
    for (gates, 0..) |gate, index| {
        if (index > 0) try output.appendSlice(allocator, ", ");
        try appendJsonString(allocator, output, gate.gate);
    }
    try output.append(allocator, ']');
}

fn appendGateResultsJson(allocator: std.mem.Allocator, output: *std.ArrayList(u8), gates: []const GateResult) !void {
    try output.append(allocator, '[');
    for (gates, 0..) |gate, index| {
        if (index > 0) try output.appendSlice(allocator, ", ");
        try output.appendSlice(allocator, "{\"gate\": ");
        try appendJsonString(allocator, output, gate.gate);
        try output.appendSlice(allocator, ", \"status\": ");
        try appendJsonString(allocator, output, gateStatusText(gate.status));
        try output.appendSlice(allocator, ", \"detail\": ");
        try appendJsonString(allocator, output, gate.detail);
        try output.append(allocator, '}');
    }
    try output.append(allocator, ']');
}

fn appendU64Array(allocator: std.mem.Allocator, output: *std.ArrayList(u8), values: []const u64) !void {
    try output.append(allocator, '[');
    for (values, 0..) |value, index| {
        if (index > 0) try output.appendSlice(allocator, ", ");
        try output.print(allocator, "{d}", .{value});
    }
    try output.append(allocator, ']');
}

fn appendStringArray(allocator: std.mem.Allocator, output: *std.ArrayList(u8), values: []const []const u8) !void {
    try output.append(allocator, '[');
    for (values, 0..) |value, index| {
        if (index > 0) try output.appendSlice(allocator, ", ");
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

fn containsString(values: []const []const u8, candidate: []const u8) bool {
    for (values) |value| {
        if (std.mem.eql(u8, value, candidate)) return true;
    }
    return false;
}

fn expectGateStatus(results: []const GateResult, gate: []const u8, status: GateStatus) !void {
    for (results) |result| {
        if (std.mem.eql(u8, result.gate, gate)) {
            try std.testing.expectEqual(status, result.status);
            return;
        }
    }
    return error.ExpectedGateNotFound;
}

fn expectReasonCode(codes: []const []const u8, expected: []const u8) !void {
    for (codes) |code| {
        if (std.mem.eql(u8, code, expected)) return;
    }
    return error.ExpectedReasonCodeNotFound;
}

fn readArtifact(io: std.Io, allocator: std.mem.Allocator, path: []const u8) ![]const u8 {
    return std.Io.Dir.cwd().readFileAlloc(io, path, allocator, .limited(1024 * 1024)) catch |err| switch (err) {
        error.FileNotFound => error.MissingAppPolicyInput,
        else => return err,
    };
}

fn writeArtifact(io: std.Io, path: []const u8, contents: []const u8) !void {
    const slash = std.mem.lastIndexOfScalar(u8, path, '/') orelse return error.InvalidArtifactPath;
    const cwd = std.Io.Dir.cwd();
    try cwd.createDirPath(io, path[0..slash]);
    try cwd.writeFile(io, .{ .sub_path = path, .data = contents });
}

fn runLocal(init: std.process.Init, options: Options) !void {
    const allocator = init.gpa;
    const paths = try outputPathsForOptions(allocator, options);
    defer paths.deinit(allocator);

    const audit_json = try readArtifact(init.io, allocator, options.audit_path);
    defer allocator.free(audit_json);
    var parsed = try parseAppAudit(allocator, audit_json);
    defer parsed.deinit();

    var reports = try formatAppPolicyDecisionReports(allocator, .{
        .options = options,
        .audit_path = options.audit_path,
        .audit = parsed.value,
    });
    defer reports.deinit(allocator);

    try writeArtifact(init.io, paths.json_path, reports.json);
    try writeArtifact(init.io, paths.text_path, reports.text);
    std.debug.print("{s}", .{reports.text});
}

fn failUsage(err: anyerror) noreturn {
    std.debug.print("causal-app-policy-decision error: {s}\n{s}", .{ @errorName(err), usage() });
    std.process.exit(2);
}

pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    const options = parseOptions(args) catch |err| failUsage(err);
    runLocal(init, options) catch |err| switch (err) {
        error.MissingAppPolicyInput,
        error.InvalidArtifactPath,
        error.UnsupportedAppAuditSchema,
        => failUsage(err),
        else => return err,
    };
}

test "usage text names app policy audit flag" {
    try std.testing.expectEqualStrings(
        "usage: zig build causal-app-policy-decision -- local --audit <app-remediation-audit-json> [--policy <policy>] [--by <actor>] [--out-prefix <path-prefix>]\n",
        usage(),
    );
}

test "output paths derive from audit path and out prefix" {
    const defaults = try outputPathsForOptions(std.testing.allocator, .{
        .mode = "local",
        .audit_path = ".zig-cache/causal-artifacts/app-app-remediation-audit.json",
    });
    defer defaults.deinit(std.testing.allocator);

    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/app-app-remediation-audit-app-policy-decision.json",
        defaults.json_path,
    );
    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/app-app-remediation-audit-app-policy-decision.txt",
        defaults.text_path,
    );

    const custom = try outputPathsForOptions(std.testing.allocator, .{
        .mode = "local",
        .audit_path = ".zig-cache/causal-artifacts/app-app-remediation-audit.json",
        .out_prefix = ".zig-cache/causal-artifacts/yachdee-platform",
    });
    defer custom.deinit(std.testing.allocator);

    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/yachdee-platform-app-policy-decision.json",
        custom.json_path,
    );
}

test "source and config gates approve proposal drafting without mutation authority" {
    var parsed = try parseAppAudit(std.testing.allocator, source_config_audit_json);
    defer parsed.deinit();

    var result = try evaluateAppPolicy(std.testing.allocator, .{
        .options = .{ .mode = "local", .audit_path = "app-audit.json" },
        .audit_path = "app-audit.json",
        .audit = parsed.value,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(AppPolicyDecision.approve, result.decision);
    try std.testing.expectEqualStrings("none", result.mutation_authority);
    try std.testing.expect(!result.applied);
    try expectGateStatus(result.gate_results, "config-only", GateStatus.allow_proposal);
    try expectGateStatus(result.gate_results, "source-only", GateStatus.allow_proposal);
}

test "high risk gates require human review" {
    var parsed = try parseAppAudit(std.testing.allocator, migration_audit_json);
    defer parsed.deinit();

    var result = try evaluateAppPolicy(std.testing.allocator, .{
        .options = .{ .mode = "local", .audit_path = "app-audit.json" },
        .audit_path = "app-audit.json",
        .audit = parsed.value,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(AppPolicyDecision.needs_human_review, result.decision);
    try expectGateStatus(result.gate_results, "migration-required", GateStatus.human_review_required);
}

test "unknown gates reject the app policy decision" {
    var parsed = try parseAppAudit(std.testing.allocator, unknown_gate_audit_json);
    defer parsed.deinit();

    var result = try evaluateAppPolicy(std.testing.allocator, .{
        .options = .{ .mode = "local", .audit_path = "app-audit.json" },
        .audit_path = "app-audit.json",
        .audit = parsed.value,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(AppPolicyDecision.reject, result.decision);
    try expectGateStatus(result.gate_results, "database-maybe", GateStatus.blocked);
}

test "applied audits reject policy evaluation" {
    var parsed = try parseAppAudit(std.testing.allocator, applied_audit_json);
    defer parsed.deinit();

    var result = try evaluateAppPolicy(std.testing.allocator, .{
        .options = .{ .mode = "local", .audit_path = "app-audit.json" },
        .audit_path = "app-audit.json",
        .audit = parsed.value,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(AppPolicyDecision.reject, result.decision);
    try expectReasonCode(result.reason_codes, "app-audit-not-pending");
}

test "app policy reports serialize advisory decision and gates" {
    var parsed = try parseAppAudit(std.testing.allocator, source_config_audit_json);
    defer parsed.deinit();

    var reports = try formatAppPolicyDecisionReports(std.testing.allocator, .{
        .options = .{ .mode = "local", .audit_path = "app-audit.json" },
        .audit_path = "app-audit.json",
        .audit = parsed.value,
    });
    defer reports.deinit(std.testing.allocator);

    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"schema\": \"zigeffect.causal.app-policy-decision.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"decision\": \"approve\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"mutation_authority\": \"none\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"applied\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"gate\": \"config-only\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"status\": \"allow-proposal\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.text, "zigeffect app policy decision") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.text, "config-only allow-proposal") != null);
}
