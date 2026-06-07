const std = @import("std");
const causal_run = @import("causal_run");

const session_schema = "zigeffect.causal.dev-session.v1";
const audit_schema = "zigeffect.causal.remediation-audit.v1";
const decision_schema = "zigeffect.causal.remediation-decision.v1";
const proposal_schema = "zigeffect.causal.patch-proposal.v1";
const audit_chain_schema = "zigeffect.causal.audit-chain.v1";

const RawAuditChainInputs = struct {
    session_path: []const u8,
    audit_path: []const u8,
    decision_path: ?[]const u8,
    proposal_path: []const u8,
    before_path: []const u8,
    after_path: []const u8,
    compare_path: ?[]const u8,
    session_json: []const u8,
    audit_json: []const u8,
    decision_json: ?[]const u8,
    proposal_json: []const u8,
    before_json: []const u8,
    after_json: []const u8,
    compare_text: ?[]const u8,
};

const AuditChainReports = struct {
    json: []const u8,
    text: []const u8,

    fn deinit(self: AuditChainReports, allocator: std.mem.Allocator) void {
        allocator.free(self.json);
        allocator.free(self.text);
    }
};

const SessionRecord = struct {
    schema: []const u8,
    schema_version: u32,
    mode: []const u8,
    target: []const u8,
};

const ArtifactSource = struct {
    verdict: []const u8,
    diagnosis: []const u8,
    remediation_plan: []const u8,
    advice: []const u8,
    query: []const u8,
    compare: ?[]const u8,
};

const AuditRecord = struct {
    schema: []const u8,
    schema_version: u32,
    mode: []const u8,
    target: []const u8,
    approval_status: []const u8,
    applied: bool,
    source: ArtifactSource,
    event_ids: []const u64,
    verification_commands: []const []const u8,
    claim_guardrails: []const []const u8,
};

const DecisionSource = struct {
    audit: []const u8,
    verdict: []const u8,
    diagnosis: []const u8,
    remediation_plan: []const u8,
    advice: []const u8,
    query: []const u8,
    compare: ?[]const u8,
};

const DecisionRecord = struct {
    schema: []const u8,
    schema_version: u32,
    mode: []const u8,
    target: []const u8,
    decision: []const u8,
    approval_status: []const u8,
    applied: bool,
    source: DecisionSource,
    event_ids: []const u64,
    verification_commands: []const []const u8,
    claim_guardrails: []const []const u8,
    decision_guardrails: []const []const u8 = &.{},
};

const ProposalSource = struct {
    audit: []const u8,
    decision: ?[]const u8,
    verdict: []const u8,
    diagnosis: []const u8,
    remediation_plan: []const u8,
    advice: []const u8,
    query: []const u8,
    compare: ?[]const u8,
};

const ProposalRecord = struct {
    schema: []const u8,
    schema_version: u32,
    mode: []const u8,
    target: []const u8,
    proposal_status: []const u8,
    approval_status: []const u8,
    approved: bool,
    applied: bool,
    summary: []const u8,
    source: ProposalSource,
    event_ids: []const u64,
    verification_commands: []const []const u8,
    claim_guardrails: []const []const u8,
    proposal_guardrails: []const []const u8,
};

const CausalArtifact = struct {
    schema: ?[]const u8 = null,
    schema_version: ?u32 = null,
    events: []const CausalEvent,
};

const CausalEvent = struct {
    id: u64,
};

const EventClassification = struct {
    disappeared: []u64,
    persisting: []u64,
    appeared: []u64,
    missing: []u64,

    fn deinit(self: *EventClassification, allocator: std.mem.Allocator) void {
        allocator.free(self.disappeared);
        allocator.free(self.persisting);
        allocator.free(self.appeared);
        allocator.free(self.missing);
    }
};

fn defaultAuditChainJsonPath() []const u8 {
    return causal_run.artifact_dir ++ "/zigeffect-causal-dev-loop-audit-chain.json";
}

fn defaultAuditChainTextPath() []const u8 {
    return causal_run.artifact_dir ++ "/zigeffect-causal-dev-loop-audit-chain.txt";
}

fn scenarioAuditChainJsonPath(allocator: std.mem.Allocator, scenario_slug: []const u8) ![]const u8 {
    return std.fmt.allocPrint(
        allocator,
        "{s}/zigeffect-causal-dev-loop-{s}-audit-chain.json",
        .{ causal_run.artifact_dir, scenario_slug },
    );
}

fn scenarioAuditChainTextPath(allocator: std.mem.Allocator, scenario_slug: []const u8) ![]const u8 {
    return std.fmt.allocPrint(
        allocator,
        "{s}/zigeffect-causal-dev-loop-{s}-audit-chain.txt",
        .{ causal_run.artifact_dir, scenario_slug },
    );
}

fn classifyEventIds(
    allocator: std.mem.Allocator,
    before_event_ids: []const u64,
    after_event_ids: []const u64,
    evidence_event_ids: []const u64,
) !EventClassification {
    var disappeared = std.ArrayList(u64).empty;
    errdefer disappeared.deinit(allocator);
    var persisting = std.ArrayList(u64).empty;
    errdefer persisting.deinit(allocator);
    var appeared = std.ArrayList(u64).empty;
    errdefer appeared.deinit(allocator);
    var missing = std.ArrayList(u64).empty;
    errdefer missing.deinit(allocator);

    for (evidence_event_ids) |event_id| {
        const in_before = containsEventId(before_event_ids, event_id);
        const in_after = containsEventId(after_event_ids, event_id);
        if (in_before and !in_after) {
            try disappeared.append(allocator, event_id);
        } else if (in_before and in_after) {
            try persisting.append(allocator, event_id);
        } else if (!in_before and in_after) {
            try appeared.append(allocator, event_id);
        } else {
            try missing.append(allocator, event_id);
        }
    }

    return .{
        .disappeared = try disappeared.toOwnedSlice(allocator),
        .persisting = try persisting.toOwnedSlice(allocator),
        .appeared = try appeared.toOwnedSlice(allocator),
        .missing = try missing.toOwnedSlice(allocator),
    };
}

fn containsEventId(event_ids: []const u64, event_id: u64) bool {
    for (event_ids) |candidate| {
        if (candidate == event_id) return true;
    }
    return false;
}

fn parseFindingDelta(report: []const u8) ?isize {
    var lines = std.mem.splitScalar(u8, report, '\n');
    while (lines.next()) |line| {
        const prefix = "finding delta:";
        if (!std.mem.startsWith(u8, line, prefix)) continue;
        const value = std.mem.trim(u8, line[prefix.len..], " \t\r");
        if (value.len == 0) return null;
        return std.fmt.parseInt(isize, value, 10) catch null;
    }
    return null;
}

fn formatAuditChainReports(allocator: std.mem.Allocator, inputs: RawAuditChainInputs) !AuditChainReports {
    var parsed_session = try std.json.parseFromSlice(SessionRecord, allocator, inputs.session_json, .{ .ignore_unknown_fields = true });
    defer parsed_session.deinit();
    var parsed_audit = try std.json.parseFromSlice(AuditRecord, allocator, inputs.audit_json, .{ .ignore_unknown_fields = true });
    defer parsed_audit.deinit();
    var parsed_proposal = try std.json.parseFromSlice(ProposalRecord, allocator, inputs.proposal_json, .{ .ignore_unknown_fields = true });
    defer parsed_proposal.deinit();
    var parsed_before = try std.json.parseFromSlice(CausalArtifact, allocator, inputs.before_json, .{ .ignore_unknown_fields = true });
    defer parsed_before.deinit();
    var parsed_after = try std.json.parseFromSlice(CausalArtifact, allocator, inputs.after_json, .{ .ignore_unknown_fields = true });
    defer parsed_after.deinit();

    var parsed_decision: ?std.json.Parsed(DecisionRecord) = null;
    defer if (parsed_decision) |*decision| decision.deinit();
    if (inputs.decision_json) |decision_json| {
        parsed_decision = try std.json.parseFromSlice(DecisionRecord, allocator, decision_json, .{ .ignore_unknown_fields = true });
    }

    try validateChain(inputs, parsed_session.value, parsed_audit.value, if (parsed_decision) |decision| decision.value else null, parsed_proposal.value);

    const before_ids = try eventIdsFromArtifact(allocator, parsed_before.value);
    defer allocator.free(before_ids);
    const after_ids = try eventIdsFromArtifact(allocator, parsed_after.value);
    defer allocator.free(after_ids);

    var classification = try classifyEventIds(allocator, before_ids, after_ids, parsed_proposal.value.event_ids);
    defer classification.deinit(allocator);

    const finding_delta = if (inputs.compare_text) |compare| parseFindingDelta(compare) else null;
    const assessment = assessChain(finding_delta, classification, parsed_proposal.value.event_ids.len);

    const view = AuditChainView{
        .inputs = inputs,
        .proposal = parsed_proposal.value,
        .classification = classification,
        .finding_delta = finding_delta,
        .assessment = assessment,
    };

    const json = try formatAuditChainJson(allocator, view);
    errdefer allocator.free(json);
    const text = try formatAuditChainText(allocator, view);
    errdefer allocator.free(text);

    return .{ .json = json, .text = text };
}

const Assessment = enum {
    improved,
    regressed,
    unchanged,
    inconclusive,
};

const AuditChainView = struct {
    inputs: RawAuditChainInputs,
    proposal: ProposalRecord,
    classification: EventClassification,
    finding_delta: ?isize,
    assessment: Assessment,
};

fn validateChain(
    inputs: RawAuditChainInputs,
    session: SessionRecord,
    audit: AuditRecord,
    decision: ?DecisionRecord,
    proposal: ProposalRecord,
) !void {
    try validateSessionRecord(session);
    try validateAuditRecord(audit);
    try validateProposalRecord(proposal);

    if (!std.mem.eql(u8, session.target, audit.target)) return error.TargetMismatch;
    if (!std.mem.eql(u8, session.target, proposal.target)) return error.TargetMismatch;
    if (decision) |decision_record| {
        try validateDecisionRecord(decision_record);
        if (!std.mem.eql(u8, session.target, decision_record.target)) return error.TargetMismatch;
    }

    if (!std.mem.eql(u8, proposal.source.audit, inputs.audit_path)) return error.AuditPathMismatch;
    if (proposal.source.decision) |proposal_decision_path| {
        const input_decision_path = inputs.decision_path orelse return error.ApprovedProposalMissingDecision;
        if (!std.mem.eql(u8, proposal_decision_path, input_decision_path)) return error.DecisionPathMismatch;
        if (decision == null) return error.ApprovedProposalMissingDecision;
    } else if (proposal.approved or std.mem.eql(u8, proposal.approval_status, "approved")) {
        return error.ApprovedProposalMissingDecision;
    }
}

fn validateSessionRecord(session: SessionRecord) !void {
    if (!std.mem.eql(u8, session.schema, session_schema)) return error.UnsupportedSessionSchema;
    if (session.schema_version != 1) return error.UnsupportedSessionSchema;
    if (!std.mem.eql(u8, session.mode, "local")) return error.UnsupportedSessionSchema;
}

fn validateAuditRecord(audit: AuditRecord) !void {
    if (!std.mem.eql(u8, audit.schema, audit_schema)) return error.UnsupportedAuditSchema;
    if (audit.schema_version != 1) return error.UnsupportedAuditSchema;
    if (!std.mem.eql(u8, audit.mode, "local")) return error.UnsupportedAuditSchema;
    if (audit.applied) return error.AuditAlreadyApplied;
}

fn validateDecisionRecord(decision: DecisionRecord) !void {
    if (!std.mem.eql(u8, decision.schema, decision_schema)) return error.UnsupportedDecisionSchema;
    if (decision.schema_version != 1) return error.UnsupportedDecisionSchema;
    if (!std.mem.eql(u8, decision.mode, "local")) return error.UnsupportedDecisionSchema;
    if (decision.applied) return error.DecisionAlreadyApplied;
}

fn validateProposalRecord(proposal: ProposalRecord) !void {
    if (!std.mem.eql(u8, proposal.schema, proposal_schema)) return error.UnsupportedProposalSchema;
    if (proposal.schema_version != 1) return error.UnsupportedProposalSchema;
    if (!std.mem.eql(u8, proposal.mode, "local")) return error.UnsupportedProposalSchema;
    if (proposal.applied) return error.ProposalAlreadyApplied;
}

fn eventIdsFromArtifact(allocator: std.mem.Allocator, artifact: CausalArtifact) ![]u64 {
    const ids = try allocator.alloc(u64, artifact.events.len);
    for (artifact.events, 0..) |event, index| ids[index] = event.id;
    return ids;
}

fn assessChain(finding_delta: ?isize, classification: EventClassification, evidence_count: usize) Assessment {
    if (finding_delta) |delta| {
        if (delta < 0) return .improved;
        if (delta > 0) return .regressed;
        if (evidence_count == 0) return .inconclusive;
        if (classification.persisting.len > 0) return .unchanged;
        return .inconclusive;
    }

    if (classification.disappeared.len > classification.appeared.len) return .improved;
    if (classification.appeared.len > classification.disappeared.len) return .regressed;
    if (classification.persisting.len > 0) return .unchanged;
    return .inconclusive;
}

fn assessmentText(assessment: Assessment) []const u8 {
    return switch (assessment) {
        .improved => "improved",
        .regressed => "regressed",
        .unchanged => "unchanged",
        .inconclusive => "inconclusive",
    };
}

fn chainGuardrails() []const []const u8 {
    return &.{
        "Chain comparison is evidence, not authorization to edit source.",
        "Persisting or missing event ids prevent claiming the cited remediation is fixed.",
        "Run verification commands after source changes before claiming improvement.",
    };
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

fn appendNullableJsonString(allocator: std.mem.Allocator, output: *std.ArrayList(u8), value: ?[]const u8) !void {
    if (value) |text| {
        try appendJsonString(allocator, output, text);
    } else {
        try output.appendSlice(allocator, "null");
    }
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

fn appendFindingDeltaJson(allocator: std.mem.Allocator, output: *std.ArrayList(u8), finding_delta: ?isize) !void {
    if (finding_delta) |delta| {
        try output.print(allocator, "{d}", .{delta});
    } else {
        try output.appendSlice(allocator, "null");
    }
}

fn appendFindingDeltaText(allocator: std.mem.Allocator, output: *std.ArrayList(u8), finding_delta: ?isize) !void {
    if (finding_delta) |delta| {
        if (delta >= 0) {
            try output.print(allocator, "+{d}", .{delta});
        } else {
            try output.print(allocator, "{d}", .{delta});
        }
    } else {
        try output.appendSlice(allocator, "none");
    }
}

fn formatAuditChainJson(allocator: std.mem.Allocator, view: AuditChainView) ![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "{\n");
    try output.appendSlice(allocator, "  \"schema\": ");
    try appendJsonString(allocator, &output, audit_chain_schema);
    try output.appendSlice(allocator, ",\n");
    try output.appendSlice(allocator, "  \"schema_version\": 1,\n");
    try output.appendSlice(allocator, "  \"mode\": ");
    try appendJsonString(allocator, &output, view.proposal.mode);
    try output.appendSlice(allocator, ",\n");
    try output.appendSlice(allocator, "  \"target\": ");
    try appendJsonString(allocator, &output, view.proposal.target);
    try output.appendSlice(allocator, ",\n");
    try output.appendSlice(allocator, "  \"assessment\": ");
    try appendJsonString(allocator, &output, assessmentText(view.assessment));
    try output.appendSlice(allocator, ",\n");
    try output.appendSlice(allocator, "  \"source\": {\n");
    try output.appendSlice(allocator, "    \"session\": ");
    try appendJsonString(allocator, &output, view.inputs.session_path);
    try output.appendSlice(allocator, ",\n");
    try output.appendSlice(allocator, "    \"audit\": ");
    try appendJsonString(allocator, &output, view.inputs.audit_path);
    try output.appendSlice(allocator, ",\n");
    try output.appendSlice(allocator, "    \"decision\": ");
    try appendNullableJsonString(allocator, &output, view.inputs.decision_path);
    try output.appendSlice(allocator, ",\n");
    try output.appendSlice(allocator, "    \"proposal\": ");
    try appendJsonString(allocator, &output, view.inputs.proposal_path);
    try output.appendSlice(allocator, ",\n");
    try output.appendSlice(allocator, "    \"before\": ");
    try appendJsonString(allocator, &output, view.inputs.before_path);
    try output.appendSlice(allocator, ",\n");
    try output.appendSlice(allocator, "    \"after\": ");
    try appendJsonString(allocator, &output, view.inputs.after_path);
    try output.appendSlice(allocator, ",\n");
    try output.appendSlice(allocator, "    \"compare\": ");
    try appendNullableJsonString(allocator, &output, view.inputs.compare_path);
    try output.appendSlice(allocator, "\n");
    try output.appendSlice(allocator, "  },\n");
    try output.appendSlice(allocator, "  \"proposal_status\": ");
    try appendJsonString(allocator, &output, view.proposal.proposal_status);
    try output.appendSlice(allocator, ",\n");
    try output.appendSlice(allocator, "  \"approval_status\": ");
    try appendJsonString(allocator, &output, view.proposal.approval_status);
    try output.appendSlice(allocator, ",\n");
    try output.print(allocator, "  \"approved\": {},\n", .{view.proposal.approved});
    try output.print(allocator, "  \"applied\": {},\n", .{view.proposal.applied});
    try output.appendSlice(allocator, "  \"finding_delta\": ");
    try appendFindingDeltaJson(allocator, &output, view.finding_delta);
    try output.appendSlice(allocator, ",\n");
    try output.appendSlice(allocator, "  \"event_ids\": ");
    try appendU64Array(allocator, &output, view.proposal.event_ids);
    try output.appendSlice(allocator, ",\n");
    try output.appendSlice(allocator, "  \"disappeared_event_ids\": ");
    try appendU64Array(allocator, &output, view.classification.disappeared);
    try output.appendSlice(allocator, ",\n");
    try output.appendSlice(allocator, "  \"persisting_event_ids\": ");
    try appendU64Array(allocator, &output, view.classification.persisting);
    try output.appendSlice(allocator, ",\n");
    try output.appendSlice(allocator, "  \"appeared_event_ids\": ");
    try appendU64Array(allocator, &output, view.classification.appeared);
    try output.appendSlice(allocator, ",\n");
    try output.appendSlice(allocator, "  \"missing_event_ids\": ");
    try appendU64Array(allocator, &output, view.classification.missing);
    try output.appendSlice(allocator, ",\n");
    try output.appendSlice(allocator, "  \"verification_commands\": ");
    try appendStringArray(allocator, &output, view.proposal.verification_commands);
    try output.appendSlice(allocator, ",\n");
    try output.appendSlice(allocator, "  \"claim_guardrails\": ");
    try appendStringArray(allocator, &output, view.proposal.claim_guardrails);
    try output.appendSlice(allocator, ",\n");
    try output.appendSlice(allocator, "  \"proposal_guardrails\": ");
    try appendStringArray(allocator, &output, view.proposal.proposal_guardrails);
    try output.appendSlice(allocator, ",\n");
    try output.appendSlice(allocator, "  \"chain_guardrails\": ");
    try appendStringArray(allocator, &output, chainGuardrails());
    try output.append(allocator, '\n');
    try output.appendSlice(allocator, "}\n");

    return output.toOwnedSlice(allocator);
}

fn formatAuditChainText(allocator: std.mem.Allocator, view: AuditChainView) ![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "zigeffect causal audit-chain report\n");
    try output.print(allocator, "schema: {s}\n", .{audit_chain_schema});
    try output.print(allocator, "mode: {s}\n", .{view.proposal.mode});
    try output.print(allocator, "target: {s}\n", .{view.proposal.target});
    try output.print(allocator, "assessment: {s}\n", .{assessmentText(view.assessment)});
    try output.print(allocator, "proposal_status: {s}\n", .{view.proposal.proposal_status});
    try output.print(allocator, "approval_status: {s}\n", .{view.proposal.approval_status});
    try output.print(allocator, "approved: {}\n", .{view.proposal.approved});
    try output.print(allocator, "applied: {}\n", .{view.proposal.applied});
    try output.appendSlice(allocator, "finding_delta: ");
    try appendFindingDeltaText(allocator, &output, view.finding_delta);
    try output.appendSlice(allocator, "\n\n");

    try output.appendSlice(allocator, "source:\n");
    try output.print(allocator, "- session: {s}\n", .{view.inputs.session_path});
    try output.print(allocator, "- audit: {s}\n", .{view.inputs.audit_path});
    if (view.inputs.decision_path) |decision_path| {
        try output.print(allocator, "- decision: {s}\n", .{decision_path});
    } else {
        try output.appendSlice(allocator, "- decision: none\n");
    }
    try output.print(allocator, "- proposal: {s}\n", .{view.inputs.proposal_path});
    try output.print(allocator, "- before: {s}\n", .{view.inputs.before_path});
    try output.print(allocator, "- after: {s}\n", .{view.inputs.after_path});
    if (view.inputs.compare_path) |compare_path| {
        try output.print(allocator, "- compare: {s}\n\n", .{compare_path});
    } else {
        try output.appendSlice(allocator, "- compare: none\n\n");
    }

    try output.appendSlice(allocator, "event classification:\n");
    try appendIdLine(allocator, &output, "disappeared", view.classification.disappeared);
    try appendIdLine(allocator, &output, "persisting", view.classification.persisting);
    try appendIdLine(allocator, &output, "appeared", view.classification.appeared);
    try appendIdLine(allocator, &output, "missing", view.classification.missing);
    try output.append(allocator, '\n');

    try output.appendSlice(allocator, "verification:\n");
    for (view.proposal.verification_commands) |command| try output.print(allocator, "- `{s}`\n", .{command});
    try output.append(allocator, '\n');

    try output.appendSlice(allocator, "claim guardrails:\n");
    for (view.proposal.claim_guardrails) |guardrail| try output.print(allocator, "- {s}\n", .{guardrail});
    try output.append(allocator, '\n');

    try output.appendSlice(allocator, "proposal guardrails:\n");
    for (view.proposal.proposal_guardrails) |guardrail| try output.print(allocator, "- {s}\n", .{guardrail});
    try output.append(allocator, '\n');

    try output.appendSlice(allocator, "chain guardrails:\n");
    for (chainGuardrails()) |guardrail| try output.print(allocator, "- {s}\n", .{guardrail});

    return output.toOwnedSlice(allocator);
}

fn appendIdLine(allocator: std.mem.Allocator, output: *std.ArrayList(u8), label: []const u8, ids: []const u64) !void {
    try output.print(allocator, "- {s}: ", .{label});
    if (ids.len == 0) {
        try output.appendSlice(allocator, "none\n");
        return;
    }
    for (ids, 0..) |id, index| {
        if (index > 0) try output.appendSlice(allocator, ", ");
        try output.print(allocator, "{d}", .{id});
    }
    try output.append(allocator, '\n');
}

test "audit-chain default and scenario paths are deterministic" {
    try std.testing.expectEqualStrings(
        causal_run.artifact_dir ++ "/zigeffect-causal-dev-loop-audit-chain.json",
        defaultAuditChainJsonPath(),
    );
    try std.testing.expectEqualStrings(
        causal_run.artifact_dir ++ "/zigeffect-causal-dev-loop-audit-chain.txt",
        defaultAuditChainTextPath(),
    );

    const scenario_json = try scenarioAuditChainJsonPath(std.testing.allocator, "causal-scoped-fiber");
    defer std.testing.allocator.free(scenario_json);
    const scenario_text = try scenarioAuditChainTextPath(std.testing.allocator, "causal-scoped-fiber");
    defer std.testing.allocator.free(scenario_text);

    try std.testing.expectEqualStrings(
        causal_run.artifact_dir ++ "/zigeffect-causal-dev-loop-causal-scoped-fiber-audit-chain.json",
        scenario_json,
    );
    try std.testing.expectEqualStrings(
        causal_run.artifact_dir ++ "/zigeffect-causal-dev-loop-causal-scoped-fiber-audit-chain.txt",
        scenario_text,
    );
}

test "classifyEventIds splits disappeared persisting appeared and missing evidence" {
    const before = [_]u64{ 1, 2, 4 };
    const after = [_]u64{ 2, 3, 4 };
    const evidence = [_]u64{ 1, 2, 3, 5 };

    var classification = try classifyEventIds(std.testing.allocator, &before, &after, &evidence);
    defer classification.deinit(std.testing.allocator);

    try std.testing.expectEqualSlices(u64, &.{1}, classification.disappeared);
    try std.testing.expectEqualSlices(u64, &.{2}, classification.persisting);
    try std.testing.expectEqualSlices(u64, &.{3}, classification.appeared);
    try std.testing.expectEqualSlices(u64, &.{5}, classification.missing);
}

test "parseFindingDelta reads signed compare report delta" {
    const negative =
        \\zigeffect causal compare report
        \\before findings: 2
        \\after findings: 1
        \\finding delta: -1
        \\
    ;
    const positive =
        \\zigeffect causal compare report
        \\finding delta: +2
        \\
    ;
    const none =
        \\zigeffect causal compare report
        \\event delta: +0
        \\
    ;

    try std.testing.expectEqual(@as(?isize, -1), parseFindingDelta(negative));
    try std.testing.expectEqual(@as(?isize, 2), parseFindingDelta(positive));
    try std.testing.expectEqual(@as(?isize, null), parseFindingDelta(none));
}

const sample_session_json =
    \\{
    \\  "schema": "zigeffect.causal.dev-session.v1",
    \\  "schema_version": 1,
    \\  "mode": "local",
    \\  "target": "dogfood",
    \\  "phase": "assessed",
    \\  "status": "ok",
    \\  "commands": [],
    \\  "artifacts": {
    \\    "session_json": ".zig-cache/causal-artifacts/zigeffect-causal-dev-session.json",
    \\    "session_text": ".zig-cache/causal-artifacts/zigeffect-causal-dev-session.txt",
    \\    "before_json": ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-before.json",
    \\    "after_json": ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-after.json",
    \\    "verdict_json": ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-verdict.json",
    \\    "diagnosis_text": ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-diagnosis.txt",
    \\    "remediation_plan": ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-remediation-plan.md",
    \\    "remediation_audit_json": ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-remediation-audit.json",
    \\    "remediation_audit_text": ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-remediation-audit.txt"
    \\  }
    \\}
;

const sample_audit_json =
    \\{
    \\  "schema": "zigeffect.causal.remediation-audit.v1",
    \\  "schema_version": 1,
    \\  "mode": "local",
    \\  "target": "dogfood",
    \\  "proposer": "causal-dev-agent",
    \\  "approval_status": "pending",
    \\  "applied": false,
    \\  "posture": "needs-review",
    \\  "source": {
    \\    "verdict": ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-verdict.json",
    \\    "diagnosis": ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-diagnosis.txt",
    \\    "remediation_plan": ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-remediation-plan.md",
    \\    "advice": ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-advice.txt",
    \\    "query": ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-queries.txt",
    \\    "compare": ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-compare.txt"
    \\  },
    \\  "event_ids": [1, 2, 3, 5],
    \\  "verification_commands": ["zig build examples", "zig build test --summary none"],
    \\  "claim_guardrails": ["Do not claim a fix while evidence persists.", "Cite compare posture in summaries."]
    \\}
;

const sample_decision_json =
    \\{
    \\  "schema": "zigeffect.causal.remediation-decision.v1",
    \\  "schema_version": 1,
    \\  "mode": "local",
    \\  "target": "dogfood",
    \\  "decision": "approved",
    \\  "approval_status": "approved",
    \\  "decided_by": "local-reviewer",
    \\  "policy": "none",
    \\  "reason": "reviewed local remediation audit",
    \\  "applied": false,
    \\  "source": {
    \\    "audit": ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-remediation-audit.json",
    \\    "verdict": ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-verdict.json",
    \\    "diagnosis": ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-diagnosis.txt",
    \\    "remediation_plan": ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-remediation-plan.md",
    \\    "advice": ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-advice.txt",
    \\    "query": ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-queries.txt",
    \\    "compare": ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-compare.txt"
    \\  },
    \\  "event_ids": [1, 2, 3, 5],
    \\  "verification_commands": ["zig build examples", "zig build test --summary none"],
    \\  "claim_guardrails": ["Do not claim a fix while evidence persists.", "Cite compare posture in summaries."],
    \\  "decision_guardrails": ["Approval does not apply source changes."]
    \\}
;

const sample_proposal_json =
    \\{
    \\  "schema": "zigeffect.causal.patch-proposal.v1",
    \\  "schema_version": 1,
    \\  "mode": "local",
    \\  "target": "dogfood",
    \\  "proposal_status": "approved",
    \\  "approval_status": "approved",
    \\  "approved": true,
    \\  "applied": false,
    \\  "summary": "Audit chain integration proposal",
    \\  "source": {
    \\    "audit": ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-remediation-audit.json",
    \\    "decision": ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-remediation-decision.json",
    \\    "verdict": ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-verdict.json",
    \\    "diagnosis": ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-diagnosis.txt",
    \\    "remediation_plan": ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-remediation-plan.md",
    \\    "advice": ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-advice.txt",
    \\    "query": ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-queries.txt",
    \\    "compare": ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-compare.txt"
    \\  },
    \\  "proposed_changes": [
    \\    {
    \\      "file": "packages/zigeffect/tools/causal_audit_chain.zig",
    \\      "change": "Compare proposal evidence against after artifacts"
    \\    }
    \\  ],
    \\  "event_ids": [1, 2, 3, 5],
    \\  "verification_commands": ["zig build examples", "zig build test --summary none"],
    \\  "claim_guardrails": ["Do not claim a fix while evidence persists.", "Cite compare posture in summaries."],
    \\  "proposal_guardrails": ["This proposal does not apply source changes.", "Run required verification after any future patch before claiming a fix."]
    \\}
;

const sample_before_json =
    \\{
    \\  "schema": "zigeffect.causal.v1",
    \\  "schema_version": 1,
    \\  "events": [
    \\    {"id": 1, "kind": "service_required"},
    \\    {"id": 2, "kind": "scope_closed"},
    \\    {"id": 4, "kind": "resource_acquired"}
    \\  ]
    \\}
;

const sample_after_json =
    \\{
    \\  "schema": "zigeffect.causal.v1",
    \\  "schema_version": 1,
    \\  "events": [
    \\    {"id": 2, "kind": "scope_closed"},
    \\    {"id": 3, "kind": "service_required"},
    \\    {"id": 4, "kind": "resource_finalized"}
    \\  ]
    \\}
;

const sample_compare_text =
    \\zigeffect causal compare report
    \\before findings: 1
    \\after findings: 1
    \\finding delta: +0
    \\
;

test "audit-chain reports preserve source evidence classifications and guardrails" {
    const reports = try formatAuditChainReports(std.testing.allocator, .{
        .session_path = ".zig-cache/causal-artifacts/zigeffect-causal-dev-session.json",
        .audit_path = ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-remediation-audit.json",
        .decision_path = ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-remediation-decision.json",
        .proposal_path = ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-patch-proposal.json",
        .before_path = ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-before.json",
        .after_path = ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-after.json",
        .compare_path = ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-compare.txt",
        .session_json = sample_session_json,
        .audit_json = sample_audit_json,
        .decision_json = sample_decision_json,
        .proposal_json = sample_proposal_json,
        .before_json = sample_before_json,
        .after_json = sample_after_json,
        .compare_text = sample_compare_text,
    });
    defer reports.deinit(std.testing.allocator);

    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"schema\": \"zigeffect.causal.audit-chain.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"assessment\": \"unchanged\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"finding_delta\": 0") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"disappeared_event_ids\": [1]") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"persisting_event_ids\": [2]") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"appeared_event_ids\": [3]") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"missing_event_ids\": [5]") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"approved\": true") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"applied\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"zig build examples\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"Do not claim a fix while evidence persists.\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"This proposal does not apply source changes.\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"Chain comparison is evidence, not authorization to edit source.\"") != null);

    try std.testing.expect(std.mem.indexOf(u8, reports.text, "zigeffect causal audit-chain report") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.text, "assessment: unchanged") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.text, "finding_delta: +0") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.text, "event classification:") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.text, "- disappeared: 1") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.text, "- persisting: 2") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.text, "- appeared: 3") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.text, "- missing: 5") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.text, "chain guardrails:") != null);
}

test "audit-chain validates targets and applied proposal boundary" {
    const mismatched_session =
        \\{
        \\  "schema": "zigeffect.causal.dev-session.v1",
        \\  "schema_version": 1,
        \\  "mode": "local",
        \\  "target": "other",
        \\  "phase": "assessed",
        \\  "status": "ok",
        \\  "commands": [],
        \\  "artifacts": {}
        \\}
    ;
    const applied_proposal = std.mem.replaceOwned(
        u8,
        std.testing.allocator,
        sample_proposal_json,
        "\"applied\": false",
        "\"applied\": true",
    ) catch unreachable;
    defer std.testing.allocator.free(applied_proposal);

    const base = RawAuditChainInputs{
        .session_path = ".zig-cache/causal-artifacts/zigeffect-causal-dev-session.json",
        .audit_path = ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-remediation-audit.json",
        .decision_path = ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-remediation-decision.json",
        .proposal_path = ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-patch-proposal.json",
        .before_path = ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-before.json",
        .after_path = ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-after.json",
        .compare_path = ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-compare.txt",
        .session_json = sample_session_json,
        .audit_json = sample_audit_json,
        .decision_json = sample_decision_json,
        .proposal_json = sample_proposal_json,
        .before_json = sample_before_json,
        .after_json = sample_after_json,
        .compare_text = sample_compare_text,
    };

    var mismatch = base;
    mismatch.session_json = mismatched_session;
    try std.testing.expectError(error.TargetMismatch, formatAuditChainReports(std.testing.allocator, mismatch));

    var applied = base;
    applied.proposal_json = applied_proposal;
    try std.testing.expectError(error.ProposalAlreadyApplied, formatAuditChainReports(std.testing.allocator, applied));
}
