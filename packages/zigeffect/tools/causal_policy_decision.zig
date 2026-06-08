const std = @import("std");
const causal_run = @import("causal_run");

const audit_schema = "zigeffect.causal.remediation-audit.v1";
const decision_schema = "zigeffect.causal.remediation-decision.v1";
const proposal_schema = "zigeffect.causal.patch-proposal.v1";
const audit_chain_schema = "zigeffect.causal.audit-chain.v1";
const scenario_proposal_schema = "zigeffect.causal.scenario-proposal.v1";
const registry_patch_schema = "zigeffect.causal.registry-patch.v1";
const readiness_schema = "zigeffect.causal.registry-application-readiness.v1";
const application_schema = "zigeffect.causal.registry-application.v1";
const policy_schema = "zigeffect.causal.policy-decision.v1";
const default_policy_name = "local-causal-self-improvement-v1";

const reason_codes_approved = [_][]const u8{"manual-decision-approved"};
const reason_codes_manual_missing = [_][]const u8{"manual-decision-missing"};
const reason_codes_manual_rejected = [_][]const u8{"manual-decision-rejected"};
const reason_codes_target_mismatch = [_][]const u8{"target-mismatch"};
const reason_codes_registry_blocked = [_][]const u8{"registry-readiness-blocked"};

const Options = struct {
    mode: []const u8,
    scenario_slug: ?[]const u8 = null,
    evaluated_by: []const u8 = "local-policy-engine",
    policy: []const u8 = default_policy_name,
};

const PolicyDecisionPaths = struct {
    audit_json: []const u8,
    decision_json: []const u8,
    proposal_json: []const u8,
    audit_chain_json: []const u8,
    scenario_proposal_json: []const u8,
    registry_patch_json: []const u8,
    registry_readiness_json: []const u8,
    registry_application_json: []const u8,
    output_json: []const u8,
    output_text: []const u8,

    fn deinit(self: PolicyDecisionPaths, allocator: std.mem.Allocator, options: Options) void {
        if (options.scenario_slug == null) return;
        allocator.free(self.audit_json);
        allocator.free(self.decision_json);
        allocator.free(self.proposal_json);
        allocator.free(self.audit_chain_json);
        allocator.free(self.scenario_proposal_json);
        allocator.free(self.registry_patch_json);
        allocator.free(self.registry_readiness_json);
        allocator.free(self.registry_application_json);
        allocator.free(self.output_json);
        allocator.free(self.output_text);
    }
};

fn parseOptions(args: []const []const u8) !Options {
    if (args.len < 2) return error.MissingMode;
    if (!std.mem.eql(u8, args[1], "local")) return error.UnknownMode;

    var scenario_slug: ?[]const u8 = null;
    var evaluated_by: []const u8 = "local-policy-engine";
    var policy: []const u8 = default_policy_name;

    var index: usize = 2;
    while (index < args.len) {
        const arg = args[index];
        if (std.mem.startsWith(u8, arg, "--")) {
            if (index + 1 >= args.len) return error.MissingFlagValue;
            const value = args[index + 1];
            if (std.mem.eql(u8, arg, "--by")) {
                evaluated_by = value;
            } else if (std.mem.eql(u8, arg, "--policy")) {
                if (!std.mem.eql(u8, value, default_policy_name)) return error.UnknownPolicy;
                policy = value;
            } else {
                return error.UnknownFlag;
            }
            index += 2;
        } else {
            if (scenario_slug != null) return error.DuplicateScenarioArgument;
            _ = try causal_run.scenarioByName(arg);
            scenario_slug = arg;
            index += 1;
        }
    }

    return .{
        .mode = "local",
        .scenario_slug = scenario_slug,
        .evaluated_by = evaluated_by,
        .policy = policy,
    };
}

fn defaultPolicyDecisionPaths() PolicyDecisionPaths {
    return .{
        .audit_json = causal_run.artifact_dir ++ "/zigeffect-causal-dev-loop-remediation-audit.json",
        .decision_json = causal_run.artifact_dir ++ "/zigeffect-causal-dev-loop-remediation-decision.json",
        .proposal_json = causal_run.artifact_dir ++ "/zigeffect-causal-dev-loop-patch-proposal.json",
        .audit_chain_json = causal_run.artifact_dir ++ "/zigeffect-causal-dev-loop-audit-chain.json",
        .scenario_proposal_json = causal_run.artifact_dir ++ "/zigeffect-causal-dev-loop-scenario-proposal.json",
        .registry_patch_json = causal_run.artifact_dir ++ "/zigeffect-causal-dev-loop-registry-patch.json",
        .registry_readiness_json = causal_run.artifact_dir ++ "/zigeffect-causal-dev-loop-registry-application-readiness.json",
        .registry_application_json = causal_run.artifact_dir ++ "/zigeffect-causal-dev-loop-registry-application.json",
        .output_json = causal_run.artifact_dir ++ "/zigeffect-causal-dev-loop-policy-decision.json",
        .output_text = causal_run.artifact_dir ++ "/zigeffect-causal-dev-loop-policy-decision.txt",
    };
}

fn scenarioPolicyDecisionPaths(allocator: std.mem.Allocator, scenario_slug: []const u8) !PolicyDecisionPaths {
    const audit_json = try std.fmt.allocPrint(allocator, "{s}/zigeffect-causal-dev-loop-{s}-remediation-audit.json", .{ causal_run.artifact_dir, scenario_slug });
    errdefer allocator.free(audit_json);
    const decision_json = try std.fmt.allocPrint(allocator, "{s}/zigeffect-causal-dev-loop-{s}-remediation-decision.json", .{ causal_run.artifact_dir, scenario_slug });
    errdefer allocator.free(decision_json);
    const proposal_json = try std.fmt.allocPrint(allocator, "{s}/zigeffect-causal-dev-loop-{s}-patch-proposal.json", .{ causal_run.artifact_dir, scenario_slug });
    errdefer allocator.free(proposal_json);
    const audit_chain_json = try std.fmt.allocPrint(allocator, "{s}/zigeffect-causal-dev-loop-{s}-audit-chain.json", .{ causal_run.artifact_dir, scenario_slug });
    errdefer allocator.free(audit_chain_json);
    const scenario_proposal_json = try std.fmt.allocPrint(allocator, "{s}/zigeffect-causal-dev-loop-{s}-scenario-proposal.json", .{ causal_run.artifact_dir, scenario_slug });
    errdefer allocator.free(scenario_proposal_json);
    const registry_patch_json = try std.fmt.allocPrint(allocator, "{s}/zigeffect-causal-dev-loop-{s}-registry-patch.json", .{ causal_run.artifact_dir, scenario_slug });
    errdefer allocator.free(registry_patch_json);
    const registry_readiness_json = try std.fmt.allocPrint(allocator, "{s}/zigeffect-causal-dev-loop-{s}-registry-application-readiness.json", .{ causal_run.artifact_dir, scenario_slug });
    errdefer allocator.free(registry_readiness_json);
    const registry_application_json = try std.fmt.allocPrint(allocator, "{s}/zigeffect-causal-dev-loop-{s}-registry-application.json", .{ causal_run.artifact_dir, scenario_slug });
    errdefer allocator.free(registry_application_json);
    const output_json = try std.fmt.allocPrint(allocator, "{s}/zigeffect-causal-dev-loop-{s}-policy-decision.json", .{ causal_run.artifact_dir, scenario_slug });
    errdefer allocator.free(output_json);
    const output_text = try std.fmt.allocPrint(allocator, "{s}/zigeffect-causal-dev-loop-{s}-policy-decision.txt", .{ causal_run.artifact_dir, scenario_slug });

    return .{
        .audit_json = audit_json,
        .decision_json = decision_json,
        .proposal_json = proposal_json,
        .audit_chain_json = audit_chain_json,
        .scenario_proposal_json = scenario_proposal_json,
        .registry_patch_json = registry_patch_json,
        .registry_readiness_json = registry_readiness_json,
        .registry_application_json = registry_application_json,
        .output_json = output_json,
        .output_text = output_text,
    };
}

fn policyDecisionPathsForOptions(allocator: std.mem.Allocator, options: Options) !PolicyDecisionPaths {
    if (options.scenario_slug) |slug| return scenarioPolicyDecisionPaths(allocator, slug);
    return defaultPolicyDecisionPaths();
}

const ArtifactSource = struct {
    verdict: []const u8,
    diagnosis: []const u8,
    remediation_plan: []const u8,
    advice: []const u8,
    query: []const u8,
    compare: ?[]const u8 = null,
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
    compare: ?[]const u8 = null,
};

const DecisionRecord = struct {
    schema: []const u8,
    schema_version: u32,
    mode: []const u8,
    target: []const u8,
    decision: []const u8,
    approval_status: []const u8,
    decided_by: []const u8,
    policy: []const u8,
    reason: []const u8,
    applied: bool,
    source: DecisionSource,
    event_ids: []const u64,
    verification_commands: []const []const u8,
    claim_guardrails: []const []const u8,
    decision_guardrails: []const []const u8 = &.{},
};

const ProposalSource = struct {
    audit: []const u8,
    decision: ?[]const u8 = null,
    verdict: []const u8,
    diagnosis: []const u8,
    remediation_plan: []const u8,
    advice: []const u8,
    query: []const u8,
    compare: ?[]const u8 = null,
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
    proposal_guardrails: []const []const u8 = &.{},
};

const AuditChainRecord = struct {
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

const ScenarioProposalRecord = struct {
    schema: []const u8,
    schema_version: u32,
    mode: []const u8,
    target: []const u8,
    recommendation: []const u8,
};

const RegistryPatchRecord = struct {
    schema: []const u8,
    schema_version: u32,
    source_proposal: []const u8,
    recommendation: []const u8,
    patch_status: []const u8,
    target: []const u8,
    scenario_slug: ?[]const u8 = null,
    scenario_conflict: bool = false,
};

const ReadinessReport = struct {
    schema: []const u8,
    schema_version: u32,
    source_registry_patch: []const u8,
    decision: []const u8,
    readiness_status: []const u8,
    decided_by: []const u8,
    policy: []const u8,
    reason: []const u8,
    applied: bool,
    target: []const u8,
    scenario_slug: ?[]const u8 = null,
};

const SchemaEnvelope = struct {
    schema: []const u8,
    schema_version: u32,
};

const ApplicationReport = struct {
    schema: []const u8,
    schema_version: u32,
    source_readiness: []const u8,
    source_registry_patch: []const u8,
    mode: []const u8,
    application_status: []const u8,
    applied: bool,
    applied_by: []const u8,
    policy: []const u8,
    reason: []const u8,
    readiness_status: []const u8,
    target: []const u8,
    scenario_slug: ?[]const u8 = null,
};

const PolicyDecision = enum {
    approve,
    reject,
    needs_human_review,
};

const RuleStatus = enum {
    pass,
    fail,
    skipped,
};

const PolicyRuleResult = struct {
    id: []const u8,
    status: RuleStatus,
    detail: []const u8,
};

const PolicyInput = struct {
    options: Options,
    paths: PolicyDecisionPaths,
    audit_json: []const u8,
    decision_json: ?[]const u8,
    proposal_json: []const u8,
    audit_chain_json: []const u8,
    scenario_proposal_json: ?[]const u8,
    registry_patch_json: ?[]const u8,
    registry_readiness_json: ?[]const u8,
    registry_application_json: ?[]const u8,
};

const PolicyResult = struct {
    decision: PolicyDecision,
    reason: []const u8,
    reason_codes: []const []const u8,
    mutation_authority: []const u8,
    applied: bool,
    target: []const u8,
    event_ids: []const u64,
    required_verification_commands: []const []const u8,
    rules: []const PolicyRuleResult,

    fn deinit(self: PolicyResult, allocator: std.mem.Allocator) void {
        allocator.free(self.event_ids);
        freeStringSlice(allocator, self.required_verification_commands);
        allocator.free(self.rules);
    }
};

fn validateAudit(audit: AuditRecord) !void {
    if (!std.mem.eql(u8, audit.schema, audit_schema)) return error.UnsupportedAuditSchema;
    if (audit.schema_version != 1) return error.UnsupportedAuditSchema;
    if (!std.mem.eql(u8, audit.mode, "local")) return error.UnsupportedAuditSchema;
}

fn validateDecision(decision: DecisionRecord) !void {
    if (!std.mem.eql(u8, decision.schema, decision_schema)) return error.UnsupportedDecisionSchema;
    if (decision.schema_version != 1) return error.UnsupportedDecisionSchema;
    if (!std.mem.eql(u8, decision.mode, "local")) return error.UnsupportedDecisionSchema;
    if (!std.mem.eql(u8, decision.decision, "approved") and !std.mem.eql(u8, decision.decision, "rejected")) {
        return error.UnknownDecision;
    }
}

fn validateProposal(proposal: ProposalRecord) !void {
    if (!std.mem.eql(u8, proposal.schema, proposal_schema)) return error.UnsupportedProposalSchema;
    if (proposal.schema_version != 1) return error.UnsupportedProposalSchema;
    if (!std.mem.eql(u8, proposal.mode, "local")) return error.UnsupportedProposalSchema;
}

fn validateAuditChain(chain: AuditChainRecord) !void {
    if (!std.mem.eql(u8, chain.schema, audit_chain_schema)) return error.UnsupportedAuditChainSchema;
    if (chain.schema_version != 1) return error.UnsupportedAuditChainSchema;
    if (!std.mem.eql(u8, chain.mode, "local")) return error.UnsupportedAuditChainSchema;
}

fn validateOptionalScenarioProposal(proposal: ScenarioProposalRecord) !void {
    if (!std.mem.eql(u8, proposal.schema, scenario_proposal_schema)) return error.UnsupportedScenarioProposalSchema;
    if (proposal.schema_version != 1) return error.UnsupportedScenarioProposalSchema;
    if (!std.mem.eql(u8, proposal.mode, "local")) return error.UnsupportedScenarioProposalSchema;
}

fn validateOptionalRegistryPatch(patch: RegistryPatchRecord) !void {
    if (!std.mem.eql(u8, patch.schema, registry_patch_schema)) return error.UnsupportedRegistryPatchSchema;
    if (patch.schema_version != 1) return error.UnsupportedRegistryPatchSchema;
}

fn validateOptionalReadiness(report: ReadinessReport) !void {
    if (!std.mem.eql(u8, report.schema, readiness_schema)) return error.UnsupportedReadinessSchema;
    if (report.schema_version != 1) return error.UnsupportedReadinessSchema;
    if (!std.mem.eql(u8, report.readiness_status, "applicable") and
        !std.mem.eql(u8, report.readiness_status, "blocked") and
        !std.mem.eql(u8, report.readiness_status, "not-applicable"))
    {
        return error.UnknownReadinessStatus;
    }
}

fn validateOptionalApplication(report: ApplicationReport) !void {
    if (!std.mem.eql(u8, report.schema, application_schema)) return error.UnsupportedApplicationSchema;
    if (report.schema_version != 1) return error.UnsupportedApplicationSchema;
    if (!std.mem.eql(u8, report.application_status, "planned") and
        !std.mem.eql(u8, report.application_status, "applied") and
        !std.mem.eql(u8, report.application_status, "blocked") and
        !std.mem.eql(u8, report.application_status, "not-applicable"))
    {
        return error.UnknownApplicationStatus;
    }
}

fn appendRule(
    allocator: std.mem.Allocator,
    rules: *std.ArrayList(PolicyRuleResult),
    id: []const u8,
    status: RuleStatus,
    detail: []const u8,
) !void {
    try rules.append(allocator, .{
        .id = id,
        .status = status,
        .detail = detail,
    });
}

fn duplicateU64Slice(allocator: std.mem.Allocator, values: []const u64) ![]const u64 {
    if (values.len == 0) return &.{};
    const copy = try allocator.alloc(u64, values.len);
    @memcpy(copy, values);
    return copy;
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

fn evaluatePolicy(allocator: std.mem.Allocator, input: PolicyInput) !PolicyResult {
    _ = input.options;

    var parsed_audit = try std.json.parseFromSlice(AuditRecord, allocator, input.audit_json, .{ .ignore_unknown_fields = true });
    defer parsed_audit.deinit();
    var parsed_proposal = try std.json.parseFromSlice(ProposalRecord, allocator, input.proposal_json, .{ .ignore_unknown_fields = true });
    defer parsed_proposal.deinit();
    var parsed_chain = try std.json.parseFromSlice(AuditChainRecord, allocator, input.audit_chain_json, .{ .ignore_unknown_fields = true });
    defer parsed_chain.deinit();

    try validateAudit(parsed_audit.value);
    try validateProposal(parsed_proposal.value);
    try validateAuditChain(parsed_chain.value);

    var rules = std.ArrayList(PolicyRuleResult).empty;
    errdefer rules.deinit(allocator);

    try appendRule(allocator, &rules, "audit-schema-supported", .pass, "remediation audit schema is supported");
    try appendRule(allocator, &rules, "patch-proposal-schema-supported", .pass, "patch proposal schema is supported");
    try appendRule(allocator, &rules, "audit-chain-schema-supported", .pass, "audit-chain schema is supported");

    var reject = false;
    var review = false;
    var manual_approved = false;
    var manual_rejected = false;
    var downstream_blocked = false;
    var target_mismatch = false;

    if (!std.mem.eql(u8, parsed_audit.value.approval_status, "pending") or parsed_audit.value.applied) {
        reject = true;
        try appendRule(allocator, &rules, "audit-pending-review", .fail, "audit must remain pending and unapplied");
    } else {
        try appendRule(allocator, &rules, "audit-pending-review", .pass, "audit remains pending and unapplied");
    }

    if (parsed_proposal.value.applied) {
        reject = true;
        try appendRule(allocator, &rules, "patch-proposal-unapplied", .fail, "patch proposal must remain unapplied");
    } else {
        try appendRule(allocator, &rules, "patch-proposal-unapplied", .pass, "patch proposal remains unapplied");
    }

    if (!std.mem.eql(u8, parsed_audit.value.target, parsed_proposal.value.target) or
        !std.mem.eql(u8, parsed_audit.value.target, parsed_chain.value.target))
    {
        reject = true;
        target_mismatch = true;
        try appendRule(allocator, &rules, "audit-chain-target-matches", .fail, "audit, proposal, and audit-chain targets must match");
    } else {
        try appendRule(allocator, &rules, "audit-chain-target-matches", .pass, "audit, proposal, and audit-chain targets match");
    }

    if (input.decision_json) |decision_json| {
        var parsed_decision = try std.json.parseFromSlice(DecisionRecord, allocator, decision_json, .{ .ignore_unknown_fields = true });
        defer parsed_decision.deinit();
        try validateDecision(parsed_decision.value);

        if (parsed_decision.value.applied or !std.mem.eql(u8, parsed_decision.value.target, parsed_audit.value.target)) {
            reject = true;
            target_mismatch = true;
            try appendRule(allocator, &rules, "manual-decision-consistent", .fail, "manual decision must be unapplied and target the same audit evidence");
        } else if (std.mem.eql(u8, parsed_decision.value.decision, "rejected")) {
            reject = true;
            manual_rejected = true;
            try appendRule(allocator, &rules, "manual-decision-consistent", .fail, "manual decision rejected the remediation evidence");
        } else {
            manual_approved = true;
            try appendRule(allocator, &rules, "manual-decision-consistent", .pass, "manual decision approved the remediation evidence");
        }

        if (parsed_proposal.value.source.decision) |proposal_decision_path| {
            const source_matches = std.mem.eql(u8, parsed_decision.value.source.audit, parsed_proposal.value.source.audit) and proposal_decision_path.len > 0;
            try appendRule(
                allocator,
                &rules,
                "proposal-source-matches-audit",
                if (source_matches) .pass else .fail,
                "proposal source points at the reviewed audit and decision evidence",
            );
            if (!source_matches) reject = true;
        } else if (manual_approved) {
            review = true;
            try appendRule(allocator, &rules, "proposal-source-matches-audit", .skipped, "approved manual decision exists but proposal does not cite it");
        } else {
            try appendRule(allocator, &rules, "proposal-source-matches-audit", .skipped, "proposal has no manual decision source");
        }
    } else {
        review = true;
        try appendRule(allocator, &rules, "manual-decision-consistent", .skipped, "manual decision artifact is absent");
        try appendRule(allocator, &rules, "proposal-source-matches-audit", .skipped, "proposal has no manual decision source");
    }

    if (input.scenario_proposal_json) |scenario_json| {
        var parsed_scenario = try std.json.parseFromSlice(ScenarioProposalRecord, allocator, scenario_json, .{ .ignore_unknown_fields = true });
        defer parsed_scenario.deinit();
        try validateOptionalScenarioProposal(parsed_scenario.value);
        if (!std.mem.eql(u8, parsed_scenario.value.target, parsed_audit.value.target)) {
            reject = true;
            target_mismatch = true;
        }
    }

    if (input.registry_patch_json) |patch_json| {
        var parsed_patch = try std.json.parseFromSlice(RegistryPatchRecord, allocator, patch_json, .{ .ignore_unknown_fields = true });
        defer parsed_patch.deinit();
        try validateOptionalRegistryPatch(parsed_patch.value);
        if (!std.mem.eql(u8, parsed_patch.value.target, parsed_audit.value.target)) {
            reject = true;
            target_mismatch = true;
        }
    }

    if (input.registry_readiness_json) |readiness_json| {
        var parsed_readiness = try std.json.parseFromSlice(ReadinessReport, allocator, readiness_json, .{ .ignore_unknown_fields = true });
        defer parsed_readiness.deinit();
        try validateOptionalReadiness(parsed_readiness.value);
        if (parsed_readiness.value.applied or !std.mem.eql(u8, parsed_readiness.value.target, parsed_audit.value.target)) {
            reject = true;
            target_mismatch = true;
            try appendRule(allocator, &rules, "registry-readiness-consistent", .fail, "registry readiness must be unapplied and target the same evidence");
        } else if (std.mem.eql(u8, parsed_readiness.value.readiness_status, "blocked")) {
            review = true;
            downstream_blocked = true;
            try appendRule(allocator, &rules, "registry-readiness-consistent", .fail, "registry readiness is blocked");
        } else {
            try appendRule(allocator, &rules, "registry-readiness-consistent", .pass, "registry readiness is consistent with policy evidence");
        }
    } else {
        try appendRule(allocator, &rules, "registry-readiness-consistent", .skipped, "registry readiness artifact is absent");
    }

    if (input.registry_application_json) |application_json| {
        var parsed_application_schema = try std.json.parseFromSlice(SchemaEnvelope, allocator, application_json, .{ .ignore_unknown_fields = true });
        defer parsed_application_schema.deinit();
        if (!std.mem.eql(u8, parsed_application_schema.value.schema, application_schema) or
            parsed_application_schema.value.schema_version != 1)
        {
            return error.UnsupportedApplicationSchema;
        }

        var parsed_application = try std.json.parseFromSlice(ApplicationReport, allocator, application_json, .{ .ignore_unknown_fields = true });
        defer parsed_application.deinit();
        try validateOptionalApplication(parsed_application.value);
        if (!std.mem.eql(u8, parsed_application.value.target, parsed_audit.value.target)) {
            reject = true;
            target_mismatch = true;
            try appendRule(allocator, &rules, "registry-application-consistent", .fail, "registry application target must match policy evidence");
        } else if (std.mem.eql(u8, parsed_application.value.application_status, "blocked")) {
            review = true;
            downstream_blocked = true;
            try appendRule(allocator, &rules, "registry-application-consistent", .fail, "registry application is blocked");
        } else {
            try appendRule(allocator, &rules, "registry-application-consistent", .pass, "registry application is consistent with policy evidence");
        }
    } else {
        try appendRule(allocator, &rules, "registry-application-consistent", .skipped, "registry application artifact is absent");
    }

    try appendRule(allocator, &rules, "mutation-authority-none", .pass, "policy decisions do not authorize source mutation");

    const decision: PolicyDecision = if (reject)
        .reject
    else if (review or !manual_approved)
        .needs_human_review
    else
        .approve;

    const reason_codes: []const []const u8 = if (target_mismatch)
        reason_codes_target_mismatch[0..]
    else if (manual_rejected)
        reason_codes_manual_rejected[0..]
    else if (downstream_blocked)
        reason_codes_registry_blocked[0..]
    else if (manual_approved and decision == .approve)
        reason_codes_approved[0..]
    else
        reason_codes_manual_missing[0..];

    const reason: []const u8 = if (target_mismatch)
        "source artifact targets do not match"
    else if (manual_rejected)
        "manual decision rejected the remediation evidence"
    else if (downstream_blocked)
        "registry readiness or application evidence is blocked"
    else if (manual_approved and decision == .approve)
        "manual decision approved the remediation evidence"
    else
        "manual approval is required before policy can recommend approval";

    const event_ids = try duplicateU64Slice(allocator, parsed_audit.value.event_ids);
    errdefer if (event_ids.len > 0) allocator.free(event_ids);
    const required_verification_commands = try duplicateStringSlice(allocator, parsed_audit.value.verification_commands);
    errdefer freeStringSlice(allocator, required_verification_commands);
    const rule_slice = try rules.toOwnedSlice(allocator);

    return .{
        .decision = decision,
        .reason = reason,
        .reason_codes = reason_codes,
        .mutation_authority = "none",
        .applied = false,
        .target = parsed_audit.value.target,
        .event_ids = event_ids,
        .required_verification_commands = required_verification_commands,
        .rules = rule_slice,
    };
}

fn expectStringInSlice(expected: []const u8, values: []const []const u8) !void {
    for (values) |value| {
        if (std.mem.eql(u8, expected, value)) return;
    }
    return error.ExpectedStringNotFound;
}

const sample_audit_json =
    \\{
    \\  "schema": "zigeffect.causal.remediation-audit.v1",
    \\  "schema_version": 1,
    \\  "mode": "local",
    \\  "target": "causal-scoped-fiber",
    \\  "approval_status": "pending",
    \\  "applied": false,
    \\  "source": {
    \\    "verdict": ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-verdict.json",
    \\    "diagnosis": ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-diagnosis.txt",
    \\    "remediation_plan": ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-remediation-plan.md",
    \\    "advice": ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-advice.txt",
    \\    "query": ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-queries.txt",
    \\    "compare": ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-compare.txt"
    \\  },
    \\  "event_ids": [7, 9],
    \\  "verification_commands": ["zig build examples"],
    \\  "claim_guardrails": ["Do not claim remediation without verification."]
    \\}
;

const sample_approved_decision_json =
    \\{
    \\  "schema": "zigeffect.causal.remediation-decision.v1",
    \\  "schema_version": 1,
    \\  "mode": "local",
    \\  "target": "causal-scoped-fiber",
    \\  "decision": "approved",
    \\  "approval_status": "approved",
    \\  "decided_by": "local-reviewer",
    \\  "policy": "manual-review",
    \\  "reason": "reviewed evidence",
    \\  "applied": false,
    \\  "source": {
    \\    "audit": ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-remediation-audit.json",
    \\    "verdict": ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-verdict.json",
    \\    "diagnosis": ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-diagnosis.txt",
    \\    "remediation_plan": ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-remediation-plan.md",
    \\    "advice": ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-advice.txt",
    \\    "query": ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-queries.txt",
    \\    "compare": ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-compare.txt"
    \\  },
    \\  "event_ids": [7, 9],
    \\  "verification_commands": ["zig build examples"],
    \\  "claim_guardrails": ["Do not claim remediation without verification."],
    \\  "decision_guardrails": ["Approval does not apply source changes."]
    \\}
;

const sample_rejected_decision_json =
    \\{
    \\  "schema": "zigeffect.causal.remediation-decision.v1",
    \\  "schema_version": 1,
    \\  "mode": "local",
    \\  "target": "causal-scoped-fiber",
    \\  "decision": "rejected",
    \\  "approval_status": "rejected",
    \\  "decided_by": "local-reviewer",
    \\  "policy": "manual-review",
    \\  "reason": "insufficient evidence",
    \\  "applied": false,
    \\  "source": {
    \\    "audit": ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-remediation-audit.json",
    \\    "verdict": ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-verdict.json",
    \\    "diagnosis": ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-diagnosis.txt",
    \\    "remediation_plan": ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-remediation-plan.md",
    \\    "advice": ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-advice.txt",
    \\    "query": ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-queries.txt",
    \\    "compare": ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-compare.txt"
    \\  },
    \\  "event_ids": [7, 9],
    \\  "verification_commands": ["zig build examples"],
    \\  "claim_guardrails": ["Do not claim remediation without verification."],
    \\  "decision_guardrails": ["Rejected proposals must not authorize edits."]
    \\}
;

const sample_patch_proposal_json =
    \\{
    \\  "schema": "zigeffect.causal.patch-proposal.v1",
    \\  "schema_version": 1,
    \\  "mode": "local",
    \\  "target": "causal-scoped-fiber",
    \\  "proposal_status": "draft",
    \\  "approval_status": "pending",
    \\  "approved": false,
    \\  "applied": false,
    \\  "summary": "capture scoped fiber evidence",
    \\  "source": {
    \\    "audit": ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-remediation-audit.json",
    \\    "decision": null,
    \\    "verdict": ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-verdict.json",
    \\    "diagnosis": ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-diagnosis.txt",
    \\    "remediation_plan": ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-remediation-plan.md",
    \\    "advice": ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-advice.txt",
    \\    "query": ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-queries.txt",
    \\    "compare": ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-compare.txt"
    \\  },
    \\  "event_ids": [7, 9],
    \\  "verification_commands": ["zig build examples"],
    \\  "claim_guardrails": ["Do not claim remediation without verification."],
    \\  "proposal_guardrails": ["Proposal does not apply source changes."]
    \\}
;

const sample_patch_proposal_with_decision_json =
    \\{
    \\  "schema": "zigeffect.causal.patch-proposal.v1",
    \\  "schema_version": 1,
    \\  "mode": "local",
    \\  "target": "causal-scoped-fiber",
    \\  "proposal_status": "approved",
    \\  "approval_status": "approved",
    \\  "approved": true,
    \\  "applied": false,
    \\  "summary": "capture scoped fiber evidence",
    \\  "source": {
    \\    "audit": ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-remediation-audit.json",
    \\    "decision": ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-remediation-decision.json",
    \\    "verdict": ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-verdict.json",
    \\    "diagnosis": ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-diagnosis.txt",
    \\    "remediation_plan": ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-remediation-plan.md",
    \\    "advice": ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-advice.txt",
    \\    "query": ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-queries.txt",
    \\    "compare": ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-compare.txt"
    \\  },
    \\  "event_ids": [7, 9],
    \\  "verification_commands": ["zig build examples"],
    \\  "claim_guardrails": ["Do not claim remediation without verification."],
    \\  "proposal_guardrails": ["Proposal does not apply source changes."]
    \\}
;

const sample_patch_proposal_wrong_target_json =
    \\{
    \\  "schema": "zigeffect.causal.patch-proposal.v1",
    \\  "schema_version": 1,
    \\  "mode": "local",
    \\  "target": "package-tests",
    \\  "proposal_status": "approved",
    \\  "approval_status": "approved",
    \\  "approved": true,
    \\  "applied": false,
    \\  "summary": "wrong target",
    \\  "source": {
    \\    "audit": ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-remediation-audit.json",
    \\    "decision": ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-remediation-decision.json",
    \\    "verdict": ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-verdict.json",
    \\    "diagnosis": ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-diagnosis.txt",
    \\    "remediation_plan": ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-remediation-plan.md",
    \\    "advice": ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-advice.txt",
    \\    "query": ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-queries.txt",
    \\    "compare": ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-compare.txt"
    \\  },
    \\  "event_ids": [7, 9],
    \\  "verification_commands": ["zig build examples"],
    \\  "claim_guardrails": ["Do not claim remediation without verification."],
    \\  "proposal_guardrails": ["Proposal does not apply source changes."]
    \\}
;

const sample_audit_chain_json =
    \\{
    \\  "schema": "zigeffect.causal.audit-chain.v1",
    \\  "schema_version": 1,
    \\  "mode": "local",
    \\  "target": "causal-scoped-fiber",
    \\  "assessment": "unchanged",
    \\  "event_ids": [7, 9],
    \\  "persisting_event_ids": [7],
    \\  "appeared_event_ids": [],
    \\  "missing_event_ids": []
    \\}
;

const sample_registry_patch_json =
    \\{
    \\  "schema": "zigeffect.causal.registry-patch.v1",
    \\  "schema_version": 1,
    \\  "source_proposal": ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-scenario-proposal.json",
    \\  "recommendation": "add-scenario",
    \\  "patch_status": "review-required",
    \\  "target": "causal-scoped-fiber",
    \\  "scenario_slug": "causal-scoped-fiber",
    \\  "scenario_conflict": false,
    \\  "known_invariant_ids": [],
    \\  "new_invariant_ids": [],
    \\  "review_checklist": [],
    \\  "guardrails": []
    \\}
;

const sample_blocked_readiness_json =
    \\{
    \\  "schema": "zigeffect.causal.registry-application-readiness.v1",
    \\  "schema_version": 1,
    \\  "source_registry_patch": ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-registry-patch.json",
    \\  "decision": "approve",
    \\  "readiness_status": "blocked",
    \\  "decided_by": "local-reviewer",
    \\  "policy": "manual-review",
    \\  "reason": "registry not updated",
    \\  "applied": false,
    \\  "target": "causal-scoped-fiber",
    \\  "scenario_slug": "causal-scoped-fiber",
    \\  "checks": [{"name": "scenario-present", "status": "fail", "detail": "scenario missing"}],
    \\  "required_verification_commands": ["zig build examples"],
    \\  "verified_commands": [],
    \\  "guardrails": []
    \\}
;

const sample_wrong_schema_json =
    \\{
    \\  "schema": "zigeffect.causal.unknown.v1",
    \\  "schema_version": 1
    \\}
;

test "policy decision parses default and scenario local invocations" {
    const default_args = [_][]const u8{
        "zigeffect-causal-policy-decision",
        "local",
        "--by",
        "local-agent",
    };
    const default_options = try parseOptions(default_args[0..]);
    try std.testing.expectEqualStrings("local", default_options.mode);
    try std.testing.expect(default_options.scenario_slug == null);
    try std.testing.expectEqualStrings(default_policy_name, default_options.policy);
    try std.testing.expectEqualStrings("local-agent", default_options.evaluated_by);

    const scenario_args = [_][]const u8{
        "zigeffect-causal-policy-decision",
        "local",
        "causal-scoped-fiber",
        "--policy",
        default_policy_name,
    };
    const scenario_options = try parseOptions(scenario_args[0..]);
    try std.testing.expectEqualStrings("causal-scoped-fiber", scenario_options.scenario_slug.?);
    try std.testing.expectEqualStrings(default_policy_name, scenario_options.policy);
}

test "policy decision rejects unknown local policy" {
    const args = [_][]const u8{
        "zigeffect-causal-policy-decision",
        "local",
        "--policy",
        "experimental-remote-policy",
    };
    try std.testing.expectError(error.UnknownPolicy, parseOptions(args[0..]));
}

test "policy decision output paths are stable for default and scenario targets" {
    const default_options = Options{ .mode = "local", .scenario_slug = null };
    const default_paths = try policyDecisionPathsForOptions(std.testing.allocator, default_options);
    defer default_paths.deinit(std.testing.allocator, default_options);

    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-policy-decision.json",
        default_paths.output_json,
    );
    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-policy-decision.txt",
        default_paths.output_text,
    );

    const scenario_options = Options{ .mode = "local", .scenario_slug = "causal-scoped-fiber" };
    const scenario_paths = try policyDecisionPathsForOptions(std.testing.allocator, scenario_options);
    defer scenario_paths.deinit(std.testing.allocator, scenario_options);

    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-policy-decision.json",
        scenario_paths.output_json,
    );
    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-policy-decision.txt",
        scenario_paths.output_text,
    );
}

test "policy evaluator requires human review without manual decision" {
    const input = PolicyInput{
        .options = .{ .mode = "local" },
        .paths = defaultPolicyDecisionPaths(),
        .audit_json = sample_audit_json,
        .decision_json = null,
        .proposal_json = sample_patch_proposal_json,
        .audit_chain_json = sample_audit_chain_json,
        .scenario_proposal_json = null,
        .registry_patch_json = null,
        .registry_readiness_json = null,
        .registry_application_json = null,
    };
    var result = try evaluatePolicy(std.testing.allocator, input);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(PolicyDecision.needs_human_review, result.decision);
    try expectStringInSlice("manual-decision-missing", result.reason_codes);
    try std.testing.expectEqualStrings("none", result.mutation_authority);
    try std.testing.expect(!result.applied);
}

test "policy evaluator approves approved manual decision with matching evidence" {
    const input = PolicyInput{
        .options = .{ .mode = "local" },
        .paths = defaultPolicyDecisionPaths(),
        .audit_json = sample_audit_json,
        .decision_json = sample_approved_decision_json,
        .proposal_json = sample_patch_proposal_with_decision_json,
        .audit_chain_json = sample_audit_chain_json,
        .scenario_proposal_json = null,
        .registry_patch_json = null,
        .registry_readiness_json = null,
        .registry_application_json = null,
    };
    var result = try evaluatePolicy(std.testing.allocator, input);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(PolicyDecision.approve, result.decision);
    try expectStringInSlice("manual-decision-approved", result.reason_codes);
}

test "policy evaluator rejects rejected manual decision" {
    const input = PolicyInput{
        .options = .{ .mode = "local" },
        .paths = defaultPolicyDecisionPaths(),
        .audit_json = sample_audit_json,
        .decision_json = sample_rejected_decision_json,
        .proposal_json = sample_patch_proposal_json,
        .audit_chain_json = sample_audit_chain_json,
        .scenario_proposal_json = null,
        .registry_patch_json = null,
        .registry_readiness_json = null,
        .registry_application_json = null,
    };
    var result = try evaluatePolicy(std.testing.allocator, input);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(PolicyDecision.reject, result.decision);
    try expectStringInSlice("manual-decision-rejected", result.reason_codes);
}

test "policy evaluator rejects target mismatch" {
    const input = PolicyInput{
        .options = .{ .mode = "local" },
        .paths = defaultPolicyDecisionPaths(),
        .audit_json = sample_audit_json,
        .decision_json = sample_approved_decision_json,
        .proposal_json = sample_patch_proposal_wrong_target_json,
        .audit_chain_json = sample_audit_chain_json,
        .scenario_proposal_json = null,
        .registry_patch_json = null,
        .registry_readiness_json = null,
        .registry_application_json = null,
    };
    var result = try evaluatePolicy(std.testing.allocator, input);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(PolicyDecision.reject, result.decision);
    try expectStringInSlice("target-mismatch", result.reason_codes);
}

test "policy evaluator sends blocked registry readiness to human review" {
    const input = PolicyInput{
        .options = .{ .mode = "local" },
        .paths = defaultPolicyDecisionPaths(),
        .audit_json = sample_audit_json,
        .decision_json = sample_approved_decision_json,
        .proposal_json = sample_patch_proposal_with_decision_json,
        .audit_chain_json = sample_audit_chain_json,
        .scenario_proposal_json = null,
        .registry_patch_json = sample_registry_patch_json,
        .registry_readiness_json = sample_blocked_readiness_json,
        .registry_application_json = null,
    };
    var result = try evaluatePolicy(std.testing.allocator, input);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(PolicyDecision.needs_human_review, result.decision);
    try expectStringInSlice("registry-readiness-blocked", result.reason_codes);
}

test "policy evaluator rejects unsupported optional artifact schema" {
    const input = PolicyInput{
        .options = .{ .mode = "local" },
        .paths = defaultPolicyDecisionPaths(),
        .audit_json = sample_audit_json,
        .decision_json = null,
        .proposal_json = sample_patch_proposal_json,
        .audit_chain_json = sample_audit_chain_json,
        .scenario_proposal_json = null,
        .registry_patch_json = null,
        .registry_readiness_json = null,
        .registry_application_json = sample_wrong_schema_json,
    };
    try std.testing.expectError(error.UnsupportedApplicationSchema, evaluatePolicy(std.testing.allocator, input));
}
