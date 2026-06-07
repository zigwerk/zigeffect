const std = @import("std");
const causal_run = @import("causal_run");

const proposal_schema = "zigeffect.causal.scenario-proposal.v1";
const verdict_schema = "zigeffect.causal.dev-loop-verdict.v1";
const audit_chain_schema = "zigeffect.causal.audit-chain.v1";

const Options = struct {
    mode: []const u8,
    scenario_slug: ?[]const u8 = null,
};

const Recommendation = enum {
    add_scenario,
    refine_scenario,
    none,
};

const RecommendationInput = struct {
    scenario_slug: ?[]const u8,
    verdict_status: []const u8,
    actions: usize,
    new_actions: usize,
    persisting_actions: usize,
    audit_chain_assessment: []const u8,
    persisting_event_ids: []const u64,
    appeared_event_ids: []const u64,
};

const RawScenarioProposalInputs = struct {
    options: Options,
    verdict_path: []const u8,
    diagnosis_path: []const u8,
    remediation_plan_path: []const u8,
    audit_chain_path: []const u8,
    verdict_json: []const u8,
    diagnosis_text: []const u8,
    remediation_plan_text: []const u8,
    audit_chain_json: []const u8,
};

const ScenarioProposalReports = struct {
    json: []const u8,
    text: []const u8,

    fn deinit(self: ScenarioProposalReports, allocator: std.mem.Allocator) void {
        allocator.free(self.json);
        allocator.free(self.text);
    }
};

const ScenarioProposalPaths = struct {
    verdict_json: []const u8,
    diagnosis_text: []const u8,
    remediation_plan_md: []const u8,
    audit_chain_json: []const u8,
    output_json: []const u8,
    output_text: []const u8,

    fn deinit(self: ScenarioProposalPaths, allocator: std.mem.Allocator, options: Options) void {
        if (options.scenario_slug == null) return;
        allocator.free(self.verdict_json);
        allocator.free(self.diagnosis_text);
        allocator.free(self.remediation_plan_md);
        allocator.free(self.audit_chain_json);
        allocator.free(self.output_json);
        allocator.free(self.output_text);
    }
};

const Verdict = struct {
    schema: []const u8,
    schema_version: u32,
    status: []const u8,
    actions: usize,
    new_actions: usize,
    persisting_actions: usize,
    observed_actions: usize,
};

const AuditChain = struct {
    schema: []const u8,
    schema_version: u32,
    mode: []const u8,
    target: []const u8,
    assessment: []const u8,
    event_ids: []const u64,
    persisting_event_ids: []const u64,
    appeared_event_ids: []const u64,
    missing_event_ids: []const u64,
};

const EvidenceItem = struct {
    event_id: u64,
    status: []const u8,
    kind: []const u8,
    label: []const u8,
    subsystem: []const u8,
    fix_category: []const u8,
    diagnosis: []const u8,
};

const EvidenceSummary = struct {
    items: []const EvidenceItem,
    dominant_subsystem: []const u8,
    dominant_kind: []const u8,
    dominant_fix_category: []const u8,
    dominant_diagnosis: []const u8,

    fn deinit(self: EvidenceSummary, allocator: std.mem.Allocator) void {
        allocator.free(self.items);
    }
};

const ProposedInvariant = struct {
    id: []const u8,
    subsystem: []const u8,
    rule: []const u8,
    detection_query: []const u8,
};

fn defaultScenarioProposalJsonPath() []const u8 {
    return causal_run.artifact_dir ++ "/zigeffect-causal-dev-loop-scenario-proposal.json";
}

fn defaultScenarioProposalTextPath() []const u8 {
    return causal_run.artifact_dir ++ "/zigeffect-causal-dev-loop-scenario-proposal.txt";
}

fn scenarioScenarioProposalJsonPath(allocator: std.mem.Allocator, scenario_slug: []const u8) ![]const u8 {
    return std.fmt.allocPrint(
        allocator,
        "{s}/zigeffect-causal-dev-loop-{s}-scenario-proposal.json",
        .{ causal_run.artifact_dir, scenario_slug },
    );
}

fn scenarioScenarioProposalTextPath(allocator: std.mem.Allocator, scenario_slug: []const u8) ![]const u8 {
    return std.fmt.allocPrint(
        allocator,
        "{s}/zigeffect-causal-dev-loop-{s}-scenario-proposal.txt",
        .{ causal_run.artifact_dir, scenario_slug },
    );
}

fn defaultScenarioProposalPaths() ScenarioProposalPaths {
    return .{
        .verdict_json = causal_run.artifact_dir ++ "/zigeffect-causal-dev-loop-verdict.json",
        .diagnosis_text = causal_run.artifact_dir ++ "/zigeffect-causal-dev-loop-diagnosis.txt",
        .remediation_plan_md = causal_run.artifact_dir ++ "/zigeffect-causal-dev-loop-remediation-plan.md",
        .audit_chain_json = causal_run.artifact_dir ++ "/zigeffect-causal-dev-loop-audit-chain.json",
        .output_json = defaultScenarioProposalJsonPath(),
        .output_text = defaultScenarioProposalTextPath(),
    };
}

fn scenarioScenarioProposalPaths(allocator: std.mem.Allocator, scenario_slug: []const u8) !ScenarioProposalPaths {
    const verdict_json = try std.fmt.allocPrint(allocator, "{s}/zigeffect-causal-dev-loop-{s}-verdict.json", .{ causal_run.artifact_dir, scenario_slug });
    errdefer allocator.free(verdict_json);
    const diagnosis_text = try std.fmt.allocPrint(allocator, "{s}/zigeffect-causal-dev-loop-{s}-diagnosis.txt", .{ causal_run.artifact_dir, scenario_slug });
    errdefer allocator.free(diagnosis_text);
    const remediation_plan_md = try std.fmt.allocPrint(allocator, "{s}/zigeffect-causal-dev-loop-{s}-remediation-plan.md", .{ causal_run.artifact_dir, scenario_slug });
    errdefer allocator.free(remediation_plan_md);
    const audit_chain_json = try std.fmt.allocPrint(allocator, "{s}/zigeffect-causal-dev-loop-{s}-audit-chain.json", .{ causal_run.artifact_dir, scenario_slug });
    errdefer allocator.free(audit_chain_json);
    const output_json = try scenarioScenarioProposalJsonPath(allocator, scenario_slug);
    errdefer allocator.free(output_json);
    const output_text = try scenarioScenarioProposalTextPath(allocator, scenario_slug);

    return .{
        .verdict_json = verdict_json,
        .diagnosis_text = diagnosis_text,
        .remediation_plan_md = remediation_plan_md,
        .audit_chain_json = audit_chain_json,
        .output_json = output_json,
        .output_text = output_text,
    };
}

fn scenarioProposalPathsForOptions(allocator: std.mem.Allocator, options: Options) !ScenarioProposalPaths {
    if (options.scenario_slug) |slug| return scenarioScenarioProposalPaths(allocator, slug);
    return defaultScenarioProposalPaths();
}

fn parseOptions(args: []const []const u8) !Options {
    if (args.len < 2) return error.MissingMode;
    if (!std.mem.eql(u8, args[1], "local")) return error.UnknownMode;
    if (args.len > 3) return error.DuplicateScenarioArgument;

    const scenario_slug = if (args.len == 3) blk: {
        _ = try causal_run.scenarioByName(args[2]);
        break :blk args[2];
    } else null;

    return .{ .mode = "local", .scenario_slug = scenario_slug };
}

fn chooseRecommendation(input: RecommendationInput) Recommendation {
    const has_new_evidence =
        input.new_actions > 0 or
        input.appeared_event_ids.len > 0 or
        std.mem.eql(u8, input.audit_chain_assessment, "regressed");
    const has_persisting_evidence =
        input.persisting_actions > 0 or
        input.persisting_event_ids.len > 0 or
        std.mem.eql(u8, input.audit_chain_assessment, "unchanged");
    const has_action_evidence =
        input.actions > 0 or
        !std.mem.eql(u8, input.verdict_status, "clear");

    if (!has_new_evidence and !has_persisting_evidence and !has_action_evidence) return .none;
    return if (input.scenario_slug == null) .add_scenario else .refine_scenario;
}

fn recommendationText(recommendation: Recommendation) []const u8 {
    return switch (recommendation) {
        .add_scenario => "add-scenario",
        .refine_scenario => "refine-scenario",
        .none => "none",
    };
}

fn recommendationReason(recommendation: Recommendation, verdict: Verdict, audit_chain: AuditChain) []const u8 {
    if (recommendation == .none) return "clear evidence does not justify scenario work";
    if (verdict.new_actions > 0 or audit_chain.appeared_event_ids.len > 0 or std.mem.eql(u8, audit_chain.assessment, "regressed")) {
        return "new or regressed evidence should become reviewed regression coverage";
    }
    if (verdict.persisting_actions > 0 or audit_chain.persisting_event_ids.len > 0 or std.mem.eql(u8, audit_chain.assessment, "unchanged")) {
        return "persisting evidence should become reviewed regression coverage";
    }
    return "actionable causal evidence should become reviewed scenario coverage";
}

fn formatScenarioProposalReports(allocator: std.mem.Allocator, inputs: RawScenarioProposalInputs) !ScenarioProposalReports {
    var parsed_verdict = try std.json.parseFromSlice(Verdict, allocator, inputs.verdict_json, .{ .ignore_unknown_fields = true });
    defer parsed_verdict.deinit();
    var parsed_audit_chain = try std.json.parseFromSlice(AuditChain, allocator, inputs.audit_chain_json, .{ .ignore_unknown_fields = true });
    defer parsed_audit_chain.deinit();

    try validateInputs(inputs, parsed_verdict.value, parsed_audit_chain.value);

    const evidence = try parseDiagnosisEvidence(allocator, inputs.diagnosis_text);
    defer evidence.deinit(allocator);

    const recommendation = chooseRecommendation(.{
        .scenario_slug = inputs.options.scenario_slug,
        .verdict_status = parsed_verdict.value.status,
        .actions = parsed_verdict.value.actions,
        .new_actions = parsed_verdict.value.new_actions,
        .persisting_actions = parsed_verdict.value.persisting_actions,
        .audit_chain_assessment = parsed_audit_chain.value.assessment,
        .persisting_event_ids = parsed_audit_chain.value.persisting_event_ids,
        .appeared_event_ids = parsed_audit_chain.value.appeared_event_ids,
    });
    const reason = recommendationReason(recommendation, parsed_verdict.value, parsed_audit_chain.value);

    const json = try formatScenarioProposalJson(allocator, inputs, parsed_verdict.value, parsed_audit_chain.value, evidence, recommendation, reason);
    errdefer allocator.free(json);
    const text = try formatScenarioProposalText(allocator, inputs, parsed_verdict.value, parsed_audit_chain.value, evidence, recommendation, reason);
    errdefer allocator.free(text);

    return .{ .json = json, .text = text };
}

fn validateInputs(inputs: RawScenarioProposalInputs, verdict: Verdict, audit_chain: AuditChain) !void {
    if (!std.mem.eql(u8, verdict.schema, verdict_schema)) return error.UnsupportedVerdictSchema;
    if (verdict.schema_version != 1) return error.UnsupportedVerdictSchema;
    if (!std.mem.eql(u8, audit_chain.schema, audit_chain_schema)) return error.UnsupportedAuditChainSchema;
    if (audit_chain.schema_version != 1) return error.UnsupportedAuditChainSchema;
    if (!std.mem.eql(u8, audit_chain.mode, inputs.options.mode)) return error.ModeMismatch;
    if (!std.mem.eql(u8, inputs.options.mode, "local")) return error.UnknownMode;
    if (inputs.diagnosis_text.len == 0) return error.MissingDiagnosisInput;
    if (inputs.remediation_plan_text.len == 0) return error.MissingRemediationInput;
    if (inputs.options.scenario_slug) |slug| _ = try causal_run.scenarioByName(slug);
}

fn parseDiagnosisEvidence(allocator: std.mem.Allocator, diagnosis_text: []const u8) !EvidenceSummary {
    var items = std.ArrayList(EvidenceItem).empty;
    errdefer items.deinit(allocator);
    var current: ?EvidenceItem = null;

    var lines = std.mem.splitScalar(u8, diagnosis_text, '\n');
    while (lines.next()) |line| {
        if (std.mem.startsWith(u8, line, "- action ")) {
            if (current) |item| try items.append(allocator, item);
            current = try parseActionLine(line);
        } else if (std.mem.startsWith(u8, line, "  subsystem: ")) {
            if (current) |*item| item.subsystem = std.mem.trim(u8, line["  subsystem: ".len..], " \t\r");
        } else if (std.mem.startsWith(u8, line, "  fix category: ")) {
            if (current) |*item| item.fix_category = std.mem.trim(u8, line["  fix category: ".len..], " \t\r");
        } else if (std.mem.startsWith(u8, line, "  diagnosis: ")) {
            if (current) |*item| item.diagnosis = std.mem.trim(u8, line["  diagnosis: ".len..], " \t\r");
        }
    }
    if (current) |item| try items.append(allocator, item);

    const owned = try items.toOwnedSlice(allocator);
    const dominant = dominantEvidence(owned);
    if (dominant) |item| {
        return .{
            .items = owned,
            .dominant_subsystem = item.subsystem,
            .dominant_kind = item.kind,
            .dominant_fix_category = item.fix_category,
            .dominant_diagnosis = item.diagnosis,
        };
    }

    return .{
        .items = owned,
        .dominant_subsystem = "command_harness",
        .dominant_kind = "command",
        .dominant_fix_category = "scenario-learning",
        .dominant_diagnosis = "no actionable diagnosis evidence was emitted",
    };
}

fn parseActionLine(line: []const u8) !EvidenceItem {
    var item = EvidenceItem{
        .event_id = 0,
        .status = "unknown",
        .kind = "unknown",
        .label = "unknown",
        .subsystem = "unknown",
        .fix_category = "unknown",
        .diagnosis = "no diagnosis line found",
    };

    var tokens = std.mem.splitScalar(u8, line, ' ');
    while (tokens.next()) |token| {
        if (std.mem.startsWith(u8, token, "status=")) {
            item.status = token["status=".len..];
        } else if (std.mem.startsWith(u8, token, "event=")) {
            item.event_id = try std.fmt.parseInt(u64, token["event=".len..], 10);
        } else if (std.mem.startsWith(u8, token, "kind=")) {
            item.kind = token["kind=".len..];
        }
    }

    if (std.mem.indexOf(u8, line, " label=")) |label_index| {
        item.label = std.mem.trim(u8, line[label_index + " label=".len..], " \t\r");
    }

    return item;
}

fn dominantEvidence(items: []const EvidenceItem) ?EvidenceItem {
    for (items) |item| {
        if (!std.mem.eql(u8, item.subsystem, "unknown")) return item;
    }
    return null;
}

fn invariantForEvidence(evidence: EvidenceSummary) ProposedInvariant {
    const subsystem = evidence.dominant_subsystem;
    if (std.mem.eql(u8, subsystem, "scope_lifecycle")) {
        if (std.mem.eql(u8, evidence.dominant_kind, "resource_finalized") or std.mem.indexOf(u8, evidence.dominant_fix_category, "finalizer-failure") != null) {
            return .{
                .id = "finalizer-failures-are-causal-evidence",
                .subsystem = "scope_lifecycle",
                .rule = "failed finalizers remain causal evidence until a reviewer verifies the failure path",
                .detection_query = "kind=resource_finalized status=failure",
            };
        }
        return .{
            .id = "resource-finalized-after-acquire",
            .subsystem = "scope_lifecycle",
            .rule = "every acquired resource must have matching finalization evidence",
            .detection_query = "kind=resource_acquired without matching resource_finalized",
        };
    }
    if (std.mem.eql(u8, subsystem, "fiber_runtime")) {
        return .{
            .id = "scoped-fiber-must-finish-before-scope-close",
            .subsystem = "fiber_runtime",
            .rule = "scoped fibers must finish or interrupt before their owning scope closes",
            .detection_query = "kind=fiber_forked status=pending",
        };
    }
    if (std.mem.eql(u8, subsystem, "schedule_retry")) {
        return .{
            .id = "retry-exhaustion-is-recorded",
            .subsystem = "schedule_retry",
            .rule = "retry exhaustion must be recorded as causal evidence",
            .detection_query = "kind=schedule_decision status=exhausted",
        };
    }
    if (std.mem.eql(u8, subsystem, "service_resolution")) {
        return .{
            .id = "service-requirement-has-provider",
            .subsystem = "service_resolution",
            .rule = "service requirements must cite the missing provider boundary",
            .detection_query = "kind=service_required status=missing",
        };
    }
    if (std.mem.eql(u8, subsystem, "package") or std.mem.eql(u8, subsystem, "command_harness") or std.mem.eql(u8, subsystem, "development_command")) {
        return .{
            .id = "command-failure-is-causal-evidence",
            .subsystem = subsystem,
            .rule = "command failures must produce causal failure artifacts",
            .detection_query = "kind=assertion_recorded status=failure",
        };
    }
    return .{
        .id = "learned-causal-invariant",
        .subsystem = subsystem,
        .rule = "reviewer should define the smallest causal invariant for this evidence",
        .detection_query = "review cited event ids and diagnosis evidence",
    };
}

fn formatScenarioProposalJson(
    allocator: std.mem.Allocator,
    inputs: RawScenarioProposalInputs,
    verdict: Verdict,
    audit_chain: AuditChain,
    evidence: EvidenceSummary,
    recommendation: Recommendation,
    reason: []const u8,
) ![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "{\n");
    try output.appendSlice(allocator, "  \"schema\": ");
    try appendJsonString(allocator, &output, proposal_schema);
    try output.appendSlice(allocator, ",\n");
    try output.appendSlice(allocator, "  \"schema_version\": 1,\n");
    try output.appendSlice(allocator, "  \"mode\": ");
    try appendJsonString(allocator, &output, inputs.options.mode);
    try output.appendSlice(allocator, ",\n");
    try output.appendSlice(allocator, "  \"target\": ");
    try appendJsonString(allocator, &output, audit_chain.target);
    try output.appendSlice(allocator, ",\n");
    try output.appendSlice(allocator, "  \"recommendation\": ");
    try appendJsonString(allocator, &output, recommendationText(recommendation));
    try output.appendSlice(allocator, ",\n");
    try output.appendSlice(allocator, "  \"reason\": ");
    try appendJsonString(allocator, &output, reason);
    try output.appendSlice(allocator, ",\n");
    try appendSourceJson(allocator, &output, inputs);
    try output.appendSlice(allocator, ",\n");
    try appendEvidenceJson(allocator, &output, verdict, audit_chain, evidence);
    try output.appendSlice(allocator, ",\n");
    try output.appendSlice(allocator, "  \"proposed_scenario\": ");
    try appendProposedScenarioJson(allocator, &output, inputs, audit_chain.target, evidence, recommendation);
    try output.appendSlice(allocator, ",\n");
    try output.appendSlice(allocator, "  \"proposed_invariants\": ");
    try appendProposedInvariantsJson(allocator, &output, evidence, recommendation);
    try output.appendSlice(allocator, ",\n");
    try output.appendSlice(allocator, "  \"review_checklist\": ");
    try appendStringArray(allocator, &output, reviewChecklist());
    try output.appendSlice(allocator, ",\n");
    try output.appendSlice(allocator, "  \"guardrails\": ");
    try appendStringArray(allocator, &output, guardrails());
    try output.append(allocator, '\n');
    try output.appendSlice(allocator, "}\n");

    return output.toOwnedSlice(allocator);
}

fn appendSourceJson(allocator: std.mem.Allocator, output: *std.ArrayList(u8), inputs: RawScenarioProposalInputs) !void {
    try output.appendSlice(allocator, "  \"source\": {\n");
    try output.appendSlice(allocator, "    \"verdict\": ");
    try appendJsonString(allocator, output, inputs.verdict_path);
    try output.appendSlice(allocator, ",\n");
    try output.appendSlice(allocator, "    \"diagnosis\": ");
    try appendJsonString(allocator, output, inputs.diagnosis_path);
    try output.appendSlice(allocator, ",\n");
    try output.appendSlice(allocator, "    \"remediation_plan\": ");
    try appendJsonString(allocator, output, inputs.remediation_plan_path);
    try output.appendSlice(allocator, ",\n");
    try output.appendSlice(allocator, "    \"audit_chain\": ");
    try appendJsonString(allocator, output, inputs.audit_chain_path);
    try output.appendSlice(allocator, "\n");
    try output.appendSlice(allocator, "  }");
}

fn appendEvidenceJson(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    verdict: Verdict,
    audit_chain: AuditChain,
    evidence: EvidenceSummary,
) !void {
    try output.appendSlice(allocator, "  \"evidence\": {\n");
    try output.appendSlice(allocator, "    \"verdict_status\": ");
    try appendJsonString(allocator, output, verdict.status);
    try output.appendSlice(allocator, ",\n");
    try output.print(allocator, "    \"actions\": {d},\n", .{verdict.actions});
    try output.print(allocator, "    \"new_actions\": {d},\n", .{verdict.new_actions});
    try output.print(allocator, "    \"persisting_actions\": {d},\n", .{verdict.persisting_actions});
    try output.print(allocator, "    \"observed_actions\": {d},\n", .{verdict.observed_actions});
    try output.appendSlice(allocator, "    \"audit_chain_assessment\": ");
    try appendJsonString(allocator, output, audit_chain.assessment);
    try output.appendSlice(allocator, ",\n");
    try output.appendSlice(allocator, "    \"event_ids\": ");
    try appendU64Array(allocator, output, audit_chain.event_ids);
    try output.appendSlice(allocator, ",\n");
    try output.appendSlice(allocator, "    \"persisting_event_ids\": ");
    try appendU64Array(allocator, output, audit_chain.persisting_event_ids);
    try output.appendSlice(allocator, ",\n");
    try output.appendSlice(allocator, "    \"appeared_event_ids\": ");
    try appendU64Array(allocator, output, audit_chain.appeared_event_ids);
    try output.appendSlice(allocator, ",\n");
    try output.appendSlice(allocator, "    \"missing_event_ids\": ");
    try appendU64Array(allocator, output, audit_chain.missing_event_ids);
    try output.appendSlice(allocator, ",\n");
    try output.appendSlice(allocator, "    \"dominant_subsystem\": ");
    try appendJsonString(allocator, output, evidence.dominant_subsystem);
    try output.appendSlice(allocator, ",\n");
    try output.appendSlice(allocator, "    \"dominant_kind\": ");
    try appendJsonString(allocator, output, evidence.dominant_kind);
    try output.appendSlice(allocator, ",\n");
    try output.appendSlice(allocator, "    \"dominant_fix_category\": ");
    try appendJsonString(allocator, output, evidence.dominant_fix_category);
    try output.appendSlice(allocator, ",\n");
    try output.appendSlice(allocator, "    \"dominant_diagnosis\": ");
    try appendJsonString(allocator, output, evidence.dominant_diagnosis);
    try output.append(allocator, '\n');
    try output.appendSlice(allocator, "  }");
}

fn appendProposedScenarioJson(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    inputs: RawScenarioProposalInputs,
    target: []const u8,
    evidence: EvidenceSummary,
    recommendation: Recommendation,
) !void {
    if (recommendation == .none) {
        try output.appendSlice(allocator, "null");
        return;
    }

    const slug = try proposedScenarioSlug(allocator, inputs.options.scenario_slug, target, evidence.dominant_subsystem);
    defer allocator.free(slug);
    const label = try proposedScenarioLabel(allocator, inputs.options.scenario_slug, target, evidence.dominant_subsystem);
    defer allocator.free(label);

    try output.appendSlice(allocator, "{\n");
    try output.appendSlice(allocator, "    \"slug\": ");
    try appendJsonString(allocator, output, slug);
    try output.appendSlice(allocator, ",\n");
    try output.appendSlice(allocator, "    \"label\": ");
    try appendJsonString(allocator, output, label);
    try output.appendSlice(allocator, ",\n");
    try output.appendSlice(allocator, "    \"owner\": ");
    try appendJsonString(allocator, output, evidence.dominant_subsystem);
    try output.appendSlice(allocator, ",\n");
    try output.appendSlice(allocator, "    \"expectation\": \"expected_pass\",\n");
    try output.appendSlice(allocator, "    \"finding_policy\": \"failure_artifact_on_command_failure\",\n");
    try output.appendSlice(allocator, "    \"purpose\": ");
    try appendJsonString(allocator, output, evidence.dominant_diagnosis);
    try output.appendSlice(allocator, ",\n");
    try output.appendSlice(allocator, "    \"minimal_command\": ");
    if (inputs.options.scenario_slug) |existing_slug| {
        const command = try std.fmt.allocPrint(allocator, "review existing scenario '{s}' and keep the smallest reproducing command", .{existing_slug});
        defer allocator.free(command);
        try appendJsonString(allocator, output, command);
    } else {
        try appendJsonString(allocator, output, "choose the smallest command that reproduces the cited event ids");
    }
    try output.append(allocator, '\n');
    try output.appendSlice(allocator, "  }");
}

fn appendProposedInvariantsJson(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    evidence: EvidenceSummary,
    recommendation: Recommendation,
) !void {
    if (recommendation == .none) {
        try output.appendSlice(allocator, "[]");
        return;
    }

    const invariant = invariantForEvidence(evidence);
    try output.appendSlice(allocator, "[\n");
    try output.appendSlice(allocator, "    {\n");
    try output.appendSlice(allocator, "      \"id\": ");
    try appendJsonString(allocator, output, invariant.id);
    try output.appendSlice(allocator, ",\n");
    try output.appendSlice(allocator, "      \"subsystem\": ");
    try appendJsonString(allocator, output, invariant.subsystem);
    try output.appendSlice(allocator, ",\n");
    try output.appendSlice(allocator, "      \"rule\": ");
    try appendJsonString(allocator, output, invariant.rule);
    try output.appendSlice(allocator, ",\n");
    try output.appendSlice(allocator, "      \"detection_query\": ");
    try appendJsonString(allocator, output, invariant.detection_query);
    try output.append(allocator, '\n');
    try output.appendSlice(allocator, "    }\n");
    try output.appendSlice(allocator, "  ]");
}

fn formatScenarioProposalText(
    allocator: std.mem.Allocator,
    inputs: RawScenarioProposalInputs,
    verdict: Verdict,
    audit_chain: AuditChain,
    evidence: EvidenceSummary,
    recommendation: Recommendation,
    reason: []const u8,
) ![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "zigeffect causal scenario proposal\n");
    try output.print(allocator, "schema: {s}\n", .{proposal_schema});
    try output.print(allocator, "mode: {s}\n", .{inputs.options.mode});
    try output.print(allocator, "target: {s}\n", .{audit_chain.target});
    try output.print(allocator, "recommendation: {s}\n", .{recommendationText(recommendation)});
    try output.print(allocator, "reason: {s}\n\n", .{reason});

    try output.appendSlice(allocator, "source:\n");
    try output.print(allocator, "- verdict: {s}\n", .{inputs.verdict_path});
    try output.print(allocator, "- diagnosis: {s}\n", .{inputs.diagnosis_path});
    try output.print(allocator, "- remediation_plan: {s}\n", .{inputs.remediation_plan_path});
    try output.print(allocator, "- audit_chain: {s}\n\n", .{inputs.audit_chain_path});

    try output.appendSlice(allocator, "evidence:\n");
    try output.print(allocator, "- verdict_status: {s}\n", .{verdict.status});
    try output.print(allocator, "- actions: {d}\n", .{verdict.actions});
    try output.print(allocator, "- new_actions: {d}\n", .{verdict.new_actions});
    try output.print(allocator, "- persisting_actions: {d}\n", .{verdict.persisting_actions});
    try output.print(allocator, "- audit_chain_assessment: {s}\n", .{audit_chain.assessment});
    try appendIdLine(allocator, &output, "event_ids", audit_chain.event_ids);
    try appendIdLine(allocator, &output, "persisting_event_ids", audit_chain.persisting_event_ids);
    try appendIdLine(allocator, &output, "appeared_event_ids", audit_chain.appeared_event_ids);
    try appendIdLine(allocator, &output, "missing_event_ids", audit_chain.missing_event_ids);
    try output.print(allocator, "- dominant_subsystem: {s}\n\n", .{evidence.dominant_subsystem});

    try output.appendSlice(allocator, "proposed scenario: ");
    if (recommendation == .none) {
        try output.appendSlice(allocator, "none\n\n");
    } else {
        const slug = try proposedScenarioSlug(allocator, inputs.options.scenario_slug, audit_chain.target, evidence.dominant_subsystem);
        defer allocator.free(slug);
        try output.print(allocator, "{s}\n", .{slug});
        try output.print(allocator, "- owner: {s}\n", .{evidence.dominant_subsystem});
        try output.appendSlice(allocator, "- expectation: expected_pass\n");
        try output.appendSlice(allocator, "- finding_policy: failure_artifact_on_command_failure\n\n");
    }

    try output.appendSlice(allocator, "proposed invariants:\n");
    if (recommendation == .none) {
        try output.appendSlice(allocator, "- none\n\n");
    } else {
        const invariant = invariantForEvidence(evidence);
        try output.print(allocator, "- {s}: {s}\n\n", .{ invariant.id, invariant.rule });
    }

    try output.appendSlice(allocator, "review checklist:\n");
    for (reviewChecklist()) |item| try output.print(allocator, "- {s}\n", .{item});
    try output.append(allocator, '\n');

    try output.appendSlice(allocator, "guardrails:\n");
    for (guardrails()) |guardrail| try output.print(allocator, "- {s}\n", .{guardrail});

    return output.toOwnedSlice(allocator);
}

fn proposedScenarioSlug(
    allocator: std.mem.Allocator,
    scenario_slug: ?[]const u8,
    target: []const u8,
    subsystem: []const u8,
) ![]const u8 {
    if (scenario_slug) |slug| return allocator.dupe(u8, slug);

    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);
    try output.appendSlice(allocator, "learned-");
    try appendSlugPart(allocator, &output, target);
    try output.append(allocator, '-');
    try appendSlugPart(allocator, &output, subsystem);
    return output.toOwnedSlice(allocator);
}

fn proposedScenarioLabel(
    allocator: std.mem.Allocator,
    scenario_slug: ?[]const u8,
    target: []const u8,
    subsystem: []const u8,
) ![]const u8 {
    if (scenario_slug) |slug| return std.fmt.allocPrint(allocator, "Refine {s}", .{slug});
    return std.fmt.allocPrint(allocator, "Learned {s} {s}", .{ target, subsystem });
}

fn appendSlugPart(allocator: std.mem.Allocator, output: *std.ArrayList(u8), value: []const u8) !void {
    var previous_dash = false;
    for (value) |byte| {
        const normalized = switch (byte) {
            'A'...'Z' => byte + 32,
            'a'...'z', '0'...'9' => byte,
            else => '-',
        };
        if (normalized == '-') {
            if (!previous_dash and output.items.len > 0) try output.append(allocator, '-');
            previous_dash = true;
        } else {
            try output.append(allocator, normalized);
            previous_dash = false;
        }
    }
    while (output.items.len > 0 and output.items[output.items.len - 1] == '-') {
        output.items.len -= 1;
    }
}

fn reviewChecklist() []const []const u8 {
    return &.{
        "Verify cited event ids reproduce on the smallest command.",
        "Confirm the proposed scenario or invariant is not already covered.",
        "Create or refine scenario registry entries only in a reviewed patch.",
    };
}

fn guardrails() []const []const u8 {
    return &.{
        "This proposal is read-only.",
        "Do not claim scenario coverage until source changes and verification exist.",
        "Cite verdict and audit-chain paths when summarizing this proposal.",
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
        0...7,
        11,
        12,
        14...31,
        => {
            const hex = "0123456789abcdef";
            try output.appendSlice(allocator, "\\u00");
            try output.append(allocator, hex[@intCast(byte >> 4)]);
            try output.append(allocator, hex[@intCast(byte & 0x0f)]);
        },
        else => try output.append(allocator, byte),
    };
    try output.append(allocator, '"');
}

fn appendStringArray(allocator: std.mem.Allocator, output: *std.ArrayList(u8), values: []const []const u8) !void {
    try output.append(allocator, '[');
    for (values, 0..) |value, index| {
        if (index > 0) try output.appendSlice(allocator, ", ");
        try appendJsonString(allocator, output, value);
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

fn appendIdLine(allocator: std.mem.Allocator, output: *std.ArrayList(u8), label: []const u8, values: []const u64) !void {
    try output.print(allocator, "- {s}: ", .{label});
    if (values.len == 0) {
        try output.appendSlice(allocator, "none\n");
        return;
    }
    for (values, 0..) |value, index| {
        if (index > 0) try output.appendSlice(allocator, ", ");
        try output.print(allocator, "{d}", .{value});
    }
    try output.append(allocator, '\n');
}

fn usage() []const u8 {
    return "usage: zig build causal-scenario-proposal -- local [scenario]\n";
}

fn failUsage(err: anyerror) noreturn {
    std.debug.print("causal-scenario-proposal error: {s}\n{s}", .{ @errorName(err), usage() });
    std.process.exit(2);
}

fn readRequiredArtifact(io: std.Io, allocator: std.mem.Allocator, path: []const u8) ![]const u8 {
    return std.Io.Dir.cwd().readFileAlloc(io, path, allocator, .limited(1024 * 1024)) catch |err| switch (err) {
        error.FileNotFound => error.MissingScenarioProposalInput,
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
    const paths = try scenarioProposalPathsForOptions(allocator, options);
    defer paths.deinit(allocator, options);

    const verdict_json = try readRequiredArtifact(init.io, allocator, paths.verdict_json);
    defer allocator.free(verdict_json);
    const diagnosis_text = try readRequiredArtifact(init.io, allocator, paths.diagnosis_text);
    defer allocator.free(diagnosis_text);
    const remediation_plan_text = try readRequiredArtifact(init.io, allocator, paths.remediation_plan_md);
    defer allocator.free(remediation_plan_text);
    const audit_chain_json = try readRequiredArtifact(init.io, allocator, paths.audit_chain_json);
    defer allocator.free(audit_chain_json);

    const reports = try formatScenarioProposalReports(allocator, .{
        .options = options,
        .verdict_path = paths.verdict_json,
        .diagnosis_path = paths.diagnosis_text,
        .remediation_plan_path = paths.remediation_plan_md,
        .audit_chain_path = paths.audit_chain_json,
        .verdict_json = verdict_json,
        .diagnosis_text = diagnosis_text,
        .remediation_plan_text = remediation_plan_text,
        .audit_chain_json = audit_chain_json,
    });
    defer reports.deinit(allocator);

    try writeArtifact(init.io, paths.output_json, reports.json);
    try writeArtifact(init.io, paths.output_text, reports.text);
    std.debug.print("{s}", .{reports.text});
}

pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    const options = parseOptions(args) catch |err| failUsage(err);
    runLocal(init, options) catch |err| switch (err) {
        error.MissingScenarioProposalInput,
        error.UnsupportedVerdictSchema,
        error.UnsupportedAuditChainSchema,
        error.ModeMismatch,
        error.UnknownMode,
        error.InvalidArtifactPath,
        => failUsage(err),
        else => return err,
    };
}

test "scenario proposal default and scenario paths are deterministic" {
    try std.testing.expectEqualStrings(
        causal_run.artifact_dir ++ "/zigeffect-causal-dev-loop-scenario-proposal.json",
        defaultScenarioProposalJsonPath(),
    );
    try std.testing.expectEqualStrings(
        causal_run.artifact_dir ++ "/zigeffect-causal-dev-loop-scenario-proposal.txt",
        defaultScenarioProposalTextPath(),
    );

    const json = try scenarioScenarioProposalJsonPath(std.testing.allocator, "causal-scoped-fiber");
    defer std.testing.allocator.free(json);
    const text = try scenarioScenarioProposalTextPath(std.testing.allocator, "causal-scoped-fiber");
    defer std.testing.allocator.free(text);

    try std.testing.expectEqualStrings(
        causal_run.artifact_dir ++ "/zigeffect-causal-dev-loop-causal-scoped-fiber-scenario-proposal.json",
        json,
    );
    try std.testing.expectEqualStrings(
        causal_run.artifact_dir ++ "/zigeffect-causal-dev-loop-causal-scoped-fiber-scenario-proposal.txt",
        text,
    );
}

test "scenario proposal parses local default and scenario options" {
    const default_options = try parseOptions(&.{ "zigeffect-causal-scenario-proposal", "local" });
    try std.testing.expectEqual(@as(?[]const u8, null), default_options.scenario_slug);

    const scenario_options = try parseOptions(&.{ "zigeffect-causal-scenario-proposal", "local", "causal-scoped-fiber" });
    try std.testing.expectEqualStrings("causal-scoped-fiber", scenario_options.scenario_slug.?);

    try std.testing.expectError(error.MissingMode, parseOptions(&.{"zigeffect-causal-scenario-proposal"}));
    try std.testing.expectError(error.UnknownMode, parseOptions(&.{ "zigeffect-causal-scenario-proposal", "remote" }));
}

test "scenario proposal recommendation uses verdict and audit-chain posture" {
    try std.testing.expectEqual(Recommendation.none, chooseRecommendation(.{
        .scenario_slug = "causal-scoped-fiber",
        .verdict_status = "clear",
        .actions = 0,
        .new_actions = 0,
        .persisting_actions = 0,
        .audit_chain_assessment = "inconclusive",
        .persisting_event_ids = &.{},
        .appeared_event_ids = &.{},
    }));
    try std.testing.expectEqual(Recommendation.add_scenario, chooseRecommendation(.{
        .scenario_slug = null,
        .verdict_status = "attention",
        .actions = 2,
        .new_actions = 0,
        .persisting_actions = 2,
        .audit_chain_assessment = "unchanged",
        .persisting_event_ids = &.{ 3, 4 },
        .appeared_event_ids = &.{},
    }));
    try std.testing.expectEqual(Recommendation.refine_scenario, chooseRecommendation(.{
        .scenario_slug = "causal-scoped-fiber",
        .verdict_status = "attention",
        .actions = 1,
        .new_actions = 1,
        .persisting_actions = 0,
        .audit_chain_assessment = "regressed",
        .persisting_event_ids = &.{},
        .appeared_event_ids = &.{9},
    }));
}

const sample_persisting_verdict_json =
    \\{
    \\  "schema": "zigeffect.causal.dev-loop-verdict.v1",
    \\  "schema_version": 1,
    \\  "status": "attention",
    \\  "next_action": "inspect-persisting-advice",
    \\  "json_artifacts": 1,
    \\  "baseline_pairs": 1,
    \\  "actions": 2,
    \\  "new_actions": 0,
    \\  "persisting_actions": 2,
    \\  "observed_actions": 0,
    \\  "artifacts": []
    \\}
;

const sample_persisting_diagnosis_text =
    \\zigeffect causal diagnosis
    \\mode: local
    \\target: dogfood
    \\verdict: .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-verdict.json
    \\
    \\- action close-resource status=persisting event=4 kind=resource_acquired label=dogfood database
    \\  subsystem: scope_lifecycle
    \\  fix category: resource-finalizer
    \\  diagnosis: an acquired resource lacks matching finalization evidence
    \\  citations: event=4 advice=.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-advice.txt query=.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-queries.txt
    \\- action resolve-scoped-fiber status=persisting event=5 kind=fiber_forked label=dogfood child fiber
    \\  subsystem: fiber_runtime
    \\  fix category: structured-concurrency
    \\  diagnosis: a scoped fiber remains active in captured evidence
    \\  citations: event=5 advice=.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-advice.txt query=.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-queries.txt
    \\
;

const sample_remediation_plan_text =
    \\# zigeffect causal remediation plan
    \\
    \\target: dogfood
    \\diagnosis: .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-diagnosis.txt
    \\
    \\## Strategy
    \\
    \\1. Resource cleanup: scope_lifecycle / resource-finalizer
    \\
;

const sample_persisting_audit_chain_json =
    \\{
    \\  "schema": "zigeffect.causal.audit-chain.v1",
    \\  "schema_version": 1,
    \\  "mode": "local",
    \\  "target": "dogfood",
    \\  "assessment": "unchanged",
    \\  "source": {
    \\    "session": ".zig-cache/causal-artifacts/zigeffect-causal-dev-session.json",
    \\    "audit": ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-remediation-audit.json",
    \\    "decision": ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-remediation-decision.json",
    \\    "proposal": ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-patch-proposal.json",
    \\    "before": ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-before.json",
    \\    "after": ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-after.json",
    \\    "compare": ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-compare.txt"
    \\  },
    \\  "proposal_status": "approved",
    \\  "approval_status": "approved",
    \\  "approved": true,
    \\  "applied": false,
    \\  "finding_delta": 0,
    \\  "event_ids": [4, 5],
    \\  "disappeared_event_ids": [],
    \\  "persisting_event_ids": [4, 5],
    \\  "appeared_event_ids": [],
    \\  "missing_event_ids": [],
    \\  "verification_commands": ["zig build examples", "zig build test --summary none"],
    \\  "claim_guardrails": ["Do not claim a fix while evidence persists."],
    \\  "proposal_guardrails": ["This proposal does not apply source changes."],
    \\  "chain_guardrails": ["Chain comparison is evidence, not authorization to edit source."]
    \\}
;

const sample_clear_verdict_json =
    \\{
    \\  "schema": "zigeffect.causal.dev-loop-verdict.v1",
    \\  "schema_version": 1,
    \\  "status": "clear",
    \\  "next_action": "none",
    \\  "json_artifacts": 1,
    \\  "baseline_pairs": 1,
    \\  "actions": 0,
    \\  "new_actions": 0,
    \\  "persisting_actions": 0,
    \\  "observed_actions": 0,
    \\  "artifacts": []
    \\}
;

const sample_clear_diagnosis_text =
    \\zigeffect causal diagnosis
    \\mode: local
    \\target: causal-scoped-fiber
    \\verdict: .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-verdict.json
    \\
    \\No causal remediation actions found.
    \\
;

const sample_clear_audit_chain_json =
    \\{
    \\  "schema": "zigeffect.causal.audit-chain.v1",
    \\  "schema_version": 1,
    \\  "mode": "local",
    \\  "target": "causal-scoped-fiber",
    \\  "assessment": "inconclusive",
    \\  "source": {
    \\    "session": ".zig-cache/causal-artifacts/zigeffect-causal-dev-session-causal-scoped-fiber.json",
    \\    "audit": ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-remediation-audit.json",
    \\    "decision": ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-remediation-decision.json",
    \\    "proposal": ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-patch-proposal.json",
    \\    "before": ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-before.json",
    \\    "after": ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-after.json",
    \\    "compare": ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-compare.txt"
    \\  },
    \\  "proposal_status": "approved",
    \\  "approval_status": "approved",
    \\  "approved": true,
    \\  "applied": false,
    \\  "finding_delta": null,
    \\  "event_ids": [],
    \\  "disappeared_event_ids": [],
    \\  "persisting_event_ids": [],
    \\  "appeared_event_ids": [],
    \\  "missing_event_ids": [],
    \\  "verification_commands": ["zig build examples"],
    \\  "claim_guardrails": [],
    \\  "proposal_guardrails": [],
    \\  "chain_guardrails": []
    \\}
;

test "scenario proposal reports recommend learning from persisting dogfood evidence" {
    const reports = try formatScenarioProposalReports(std.testing.allocator, .{
        .options = .{ .mode = "local", .scenario_slug = null },
        .verdict_path = ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-verdict.json",
        .diagnosis_path = ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-diagnosis.txt",
        .remediation_plan_path = ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-remediation-plan.md",
        .audit_chain_path = ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-audit-chain.json",
        .verdict_json = sample_persisting_verdict_json,
        .diagnosis_text = sample_persisting_diagnosis_text,
        .remediation_plan_text = sample_remediation_plan_text,
        .audit_chain_json = sample_persisting_audit_chain_json,
    });
    defer reports.deinit(std.testing.allocator);

    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"schema\": \"zigeffect.causal.scenario-proposal.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"recommendation\": \"add-scenario\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"target\": \"dogfood\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"audit_chain\": \".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-audit-chain.json\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"persisting_event_ids\": [4, 5]") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"dominant_subsystem\": \"scope_lifecycle\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"slug\": \"learned-dogfood-scope-lifecycle\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"resource-finalized-after-acquire\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"review_checklist\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"This proposal is read-only.\"") != null);

    try std.testing.expect(std.mem.indexOf(u8, reports.text, "zigeffect causal scenario proposal") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.text, "recommendation: add-scenario") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.text, "reason: persisting evidence should become reviewed regression coverage") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.text, "- persisting_event_ids: 4, 5") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.text, "proposed scenario: learned-dogfood-scope-lifecycle") != null);
}

test "scenario proposal reports no learning recommendation for clear scenario evidence" {
    const reports = try formatScenarioProposalReports(std.testing.allocator, .{
        .options = .{ .mode = "local", .scenario_slug = "causal-scoped-fiber" },
        .verdict_path = ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-verdict.json",
        .diagnosis_path = ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-diagnosis.txt",
        .remediation_plan_path = ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-remediation-plan.md",
        .audit_chain_path = ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-audit-chain.json",
        .verdict_json = sample_clear_verdict_json,
        .diagnosis_text = sample_clear_diagnosis_text,
        .remediation_plan_text = sample_remediation_plan_text,
        .audit_chain_json = sample_clear_audit_chain_json,
    });
    defer reports.deinit(std.testing.allocator);

    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"recommendation\": \"none\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"reason\": \"clear evidence does not justify scenario work\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"proposed_scenario\": null") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"proposed_invariants\": []") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.text, "recommendation: none") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.text, "proposed scenario: none") != null);
}

test "scenario proposal CLI paths include inputs and outputs for default and scenario" {
    const default_options = try parseOptions(&.{ "zigeffect-causal-scenario-proposal", "local" });
    const default_paths = try scenarioProposalPathsForOptions(std.testing.allocator, default_options);
    defer default_paths.deinit(std.testing.allocator, default_options);

    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-verdict.json",
        default_paths.verdict_json,
    );
    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-audit-chain.json",
        default_paths.audit_chain_json,
    );
    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-scenario-proposal.json",
        default_paths.output_json,
    );

    const scenario_options = try parseOptions(&.{ "zigeffect-causal-scenario-proposal", "local", "causal-scoped-fiber" });
    const scenario_paths = try scenarioProposalPathsForOptions(std.testing.allocator, scenario_options);
    defer scenario_paths.deinit(std.testing.allocator, scenario_options);

    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-verdict.json",
        scenario_paths.verdict_json,
    );
    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-remediation-plan.md",
        scenario_paths.remediation_plan_md,
    );
    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-scenario-proposal.txt",
        scenario_paths.output_text,
    );
}

test "scenario proposal usage names local shape" {
    try std.testing.expectEqualStrings(
        "usage: zig build causal-scenario-proposal -- local [scenario]\n",
        usage(),
    );
}
