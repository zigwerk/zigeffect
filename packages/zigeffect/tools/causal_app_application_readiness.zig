const std = @import("std");

const app_patch_proposal_schema = "zigeffect.causal.app-patch-proposal.v1";
const app_application_readiness_schema = "zigeffect.causal.app-application-readiness.v1";
const app_patch_proposal_suffix = "-app-patch-proposal.json";
const app_application_readiness_suffix = "-app-application-readiness";

const ReadinessDecision = enum {
    approve,
    reject,
};

const ReadinessStatus = enum {
    ready,
    blocked,
};

const CheckStatus = enum {
    pass,
    fail,
    skipped,
};

const Options = struct {
    mode: []const u8,
    proposal_path: []const u8,
    decision: ReadinessDecision,
    reviewed_by: []const u8 = "local-reviewer",
    policy: []const u8 = "manual-app-application-readiness",
    reason: []const u8,
    verified_commands: []const []const u8 = &.{},
    out_prefix: ?[]const u8 = null,

    fn deinit(self: *Options, allocator: std.mem.Allocator) void {
        if (self.verified_commands.len > 0) allocator.free(self.verified_commands);
    }
};

const OutputPaths = struct {
    json_path: []const u8,
    text_path: []const u8,

    fn deinit(self: OutputPaths, allocator: std.mem.Allocator) void {
        allocator.free(self.json_path);
        allocator.free(self.text_path);
    }
};

const ProposalSource = struct {
    policy: []const u8,
    app_remediation_audit: []const u8,
    app_artifact: []const u8,
    human_review: ?[]const u8 = null,
};

const ProposalCitations = struct {
    source_files: []const []const u8 = &.{},
    config_keys: []const []const u8 = &.{},
    migration_files: []const []const u8 = &.{},
    runbooks: []const []const u8 = &.{},
    rollback_plans: []const []const u8 = &.{},
};

const AppPatchProposalRecord = struct {
    schema: []const u8,
    schema_version: u32,
    mode: []const u8,
    target: []const u8,
    proposal_status: []const u8,
    approval_status: []const u8,
    approved: bool,
    applied: bool,
    mutation_authority: []const u8,
    summary: []const u8,
    change: []const u8,
    source: ProposalSource,
    policy_gates: []const []const u8,
    citations: ProposalCitations,
    event_ids: []const u64 = &.{},
    required_verification_commands: []const []const u8 = &.{},
    claim_guardrails: []const []const u8 = &.{},
    proposal_guardrails: []const []const u8 = &.{},
};

const ReadinessCheck = struct {
    name: []const u8,
    status: CheckStatus,
    detail: []const u8,
};

const ReadinessInput = struct {
    options: Options,
    source_proposal_path: []const u8,
    proposal: AppPatchProposalRecord,

    fn deinit(self: *ReadinessInput, allocator: std.mem.Allocator) void {
        _ = self;
        _ = allocator;
    }
};

const ReadinessResult = struct {
    status: ReadinessStatus,
    ready_for_application: bool,
    applied: bool,
    mutation_authority: []const u8,
    checks: []const ReadinessCheck,

    fn deinit(self: ReadinessResult, allocator: std.mem.Allocator) void {
        if (self.checks.len > 0) allocator.free(self.checks);
    }
};

const AppApplicationReadinessReports = struct {
    json: []const u8,
    text: []const u8,

    fn deinit(self: *AppApplicationReadinessReports, allocator: std.mem.Allocator) void {
        allocator.free(self.json);
        allocator.free(self.text);
    }
};

fn usage() []const u8 {
    return "usage: zig build causal-app-application-readiness -- local --proposal <app-patch-proposal-json> approve|reject --reason <reason> [--by <actor>] [--policy <policy>] [--verified <command>] [--out-prefix <path-prefix>]\n";
}

fn parseOptions(allocator: std.mem.Allocator, args: []const []const u8) !Options {
    if (args.len < 2) return error.MissingMode;
    if (!std.mem.eql(u8, args[1], "local")) return error.UnknownMode;
    if (args.len < 5) return error.MissingProposal;
    if (!std.mem.eql(u8, args[2], "--proposal")) return error.UnknownFlag;

    const proposal_path = args[3];
    const decision = try parseReadinessDecision(args[4]);
    var reviewed_by: []const u8 = "local-reviewer";
    var policy: []const u8 = "manual-app-application-readiness";
    var reason: ?[]const u8 = null;
    var out_prefix: ?[]const u8 = null;
    var verified_commands = std.ArrayList([]const u8).empty;
    errdefer verified_commands.deinit(allocator);

    var index: usize = 5;
    while (index < args.len) {
        const arg = args[index];
        if (!std.mem.startsWith(u8, arg, "--")) return error.UnknownArgument;
        if (index + 1 >= args.len) return error.MissingFlagValue;
        const value = args[index + 1];
        if (std.mem.eql(u8, arg, "--by")) {
            reviewed_by = value;
        } else if (std.mem.eql(u8, arg, "--policy")) {
            policy = value;
        } else if (std.mem.eql(u8, arg, "--reason")) {
            reason = value;
        } else if (std.mem.eql(u8, arg, "--verified")) {
            try verified_commands.append(allocator, value);
        } else if (std.mem.eql(u8, arg, "--out-prefix")) {
            out_prefix = value;
        } else {
            return error.UnknownFlag;
        }
        index += 2;
    }

    const final_reason = reason orelse return error.MissingReason;
    if (final_reason.len == 0) return error.MissingReason;

    return .{
        .mode = "local",
        .proposal_path = proposal_path,
        .decision = decision,
        .reviewed_by = reviewed_by,
        .policy = policy,
        .reason = final_reason,
        .verified_commands = try verified_commands.toOwnedSlice(allocator),
        .out_prefix = out_prefix,
    };
}

fn outputPathsForOptions(allocator: std.mem.Allocator, options: Options) !OutputPaths {
    const prefix = if (options.out_prefix) |out_prefix|
        try allocator.dupe(u8, out_prefix)
    else blk: {
        if (!std.mem.endsWith(u8, options.proposal_path, app_patch_proposal_suffix)) return error.InvalidProposalPath;
        break :blk try allocator.dupe(u8, options.proposal_path[0 .. options.proposal_path.len - app_patch_proposal_suffix.len]);
    };
    defer allocator.free(prefix);

    return .{
        .json_path = try std.fmt.allocPrint(allocator, "{s}{s}.json", .{ prefix, app_application_readiness_suffix }),
        .text_path = try std.fmt.allocPrint(allocator, "{s}{s}.txt", .{ prefix, app_application_readiness_suffix }),
    };
}

fn parseProposal(allocator: std.mem.Allocator, json: []const u8) !std.json.Parsed(AppPatchProposalRecord) {
    var parsed = try std.json.parseFromSlice(AppPatchProposalRecord, allocator, json, .{ .ignore_unknown_fields = true });
    errdefer parsed.deinit();
    try validateProposal(parsed.value);
    return parsed;
}

fn readinessInputFromProposal(
    allocator: std.mem.Allocator,
    options: Options,
    proposal_path: []const u8,
    proposal: AppPatchProposalRecord,
) !ReadinessInput {
    _ = allocator;
    if (!std.mem.eql(u8, options.mode, "local")) return error.UnknownMode;
    if (options.reason.len == 0) return error.MissingReason;
    if (proposal_path.len == 0) return error.MissingProposal;
    return .{
        .options = options,
        .source_proposal_path = proposal_path,
        .proposal = proposal,
    };
}

fn evaluateReadiness(allocator: std.mem.Allocator, input: ReadinessInput) !ReadinessResult {
    var checks = std.ArrayList(ReadinessCheck).empty;
    errdefer checks.deinit(allocator);

    try appendCheck(allocator, &checks, "app-proposal-schema", .pass, "app patch proposal schema is supported");
    try appendCheck(allocator, &checks, "proposal-state", .pass, "proposal is draft, pending, unapplied, and non-mutating");
    try appendCheck(allocator, &checks, "reviewer-decision", .pass, "reviewer supplied a decision and reason");
    try appendCheck(
        allocator,
        &checks,
        "decision-approved",
        if (input.options.decision == .approve) .pass else .fail,
        "reviewer decision must approve application readiness",
    );
    try appendCheck(
        allocator,
        &checks,
        "source-chain-present",
        if (sourceChainPresent(input.proposal.source)) .pass else .fail,
        "proposal links policy, app remediation audit, and app artifact sources",
    );
    try appendCheck(
        allocator,
        &checks,
        "policy-gates-known",
        if (policyGatesKnown(input.proposal.policy_gates)) .pass else .fail,
        "every app policy gate is recognized",
    );
    try appendCheck(
        allocator,
        &checks,
        "citations-complete",
        if (citationsComplete(input.proposal)) .pass else .fail,
        "policy gates have matching source, config, migration, runbook, or rollback citations",
    );
    try appendCheck(
        allocator,
        &checks,
        "high-risk-human-review-linked",
        if (highRiskReviewLinked(input.proposal)) .pass else .fail,
        "high-risk gates link approved human-review evidence through the proposal source",
    );
    try appendCheck(
        allocator,
        &checks,
        "required-verification-recorded",
        if (requiredCommandsSatisfied(input.options.verified_commands, input.proposal.required_verification_commands)) .pass else .fail,
        "reviewer recorded every required verification command",
    );

    const check_slice = try checks.toOwnedSlice(allocator);
    errdefer allocator.free(check_slice);
    const ready = allChecksPassed(check_slice);
    return .{
        .status = if (ready) .ready else .blocked,
        .ready_for_application = ready,
        .applied = false,
        .mutation_authority = "none",
        .checks = check_slice,
    };
}

fn formatAppApplicationReadinessReports(
    allocator: std.mem.Allocator,
    input: ReadinessInput,
) !AppApplicationReadinessReports {
    const result = try evaluateReadiness(allocator, input);
    defer result.deinit(allocator);

    const json = try formatAppApplicationReadinessJson(allocator, input, result);
    errdefer allocator.free(json);
    const text = try formatAppApplicationReadinessText(allocator, input, result);
    errdefer allocator.free(text);
    return .{ .json = json, .text = text };
}

fn readinessStatusText(status: ReadinessStatus) []const u8 {
    return switch (status) {
        .ready => "ready",
        .blocked => "blocked",
    };
}

fn checkPassed(checks: []const ReadinessCheck, name: []const u8) bool {
    for (checks) |check| {
        if (std.mem.eql(u8, check.name, name)) return check.status == .pass;
    }
    return false;
}

fn checkFailed(checks: []const ReadinessCheck, name: []const u8) bool {
    for (checks) |check| {
        if (std.mem.eql(u8, check.name, name)) return check.status == .fail;
    }
    return false;
}

fn parseReadinessDecision(value: []const u8) !ReadinessDecision {
    if (std.mem.eql(u8, value, "approve")) return .approve;
    if (std.mem.eql(u8, value, "reject")) return .reject;
    return error.UnknownDecision;
}

fn decisionText(decision: ReadinessDecision) []const u8 {
    return switch (decision) {
        .approve => "approve",
        .reject => "reject",
    };
}

fn checkStatusText(status: CheckStatus) []const u8 {
    return switch (status) {
        .pass => "pass",
        .fail => "fail",
        .skipped => "skipped",
    };
}

fn validateProposal(proposal: AppPatchProposalRecord) !void {
    if (!std.mem.eql(u8, proposal.schema, app_patch_proposal_schema)) return error.UnsupportedAppPatchProposalSchema;
    if (proposal.schema_version != 1) return error.UnsupportedAppPatchProposalSchema;
    if (!std.mem.eql(u8, proposal.mode, "local")) return error.UnsupportedAppPatchProposalSchema;
    if (proposal.target.len == 0) return error.MissingTarget;
    if (proposal.summary.len == 0) return error.MissingSummary;
    if (proposal.change.len == 0) return error.MissingChange;
    if (!std.mem.eql(u8, proposal.proposal_status, "draft")) return error.ProposalNotDraft;
    if (!std.mem.eql(u8, proposal.approval_status, "pending")) return error.ProposalApprovalNotPending;
    if (proposal.approved) return error.ProposalAlreadyApproved;
    if (proposal.applied) return error.ProposalAlreadyApplied;
    if (!std.mem.eql(u8, proposal.mutation_authority, "none")) return error.ProposalMutationAuthorityNotNone;
}

fn appendCheck(
    allocator: std.mem.Allocator,
    checks: *std.ArrayList(ReadinessCheck),
    name: []const u8,
    status: CheckStatus,
    detail: []const u8,
) !void {
    try checks.append(allocator, .{
        .name = name,
        .status = status,
        .detail = detail,
    });
}

fn sourceChainPresent(source: ProposalSource) bool {
    return source.policy.len > 0 and source.app_remediation_audit.len > 0 and source.app_artifact.len > 0;
}

fn policyGatesKnown(gates: []const []const u8) bool {
    for (gates) |gate| {
        if (!isKnownPolicyGate(gate)) return false;
    }
    return true;
}

fn isKnownPolicyGate(gate: []const u8) bool {
    return std.mem.eql(u8, gate, "source-only") or
        std.mem.eql(u8, gate, "config-only") or
        std.mem.eql(u8, gate, "migration-required") or
        std.mem.eql(u8, gate, "operational-human-required") or
        std.mem.eql(u8, gate, "rollback-required");
}

fn isHighRiskGate(gate: []const u8) bool {
    return std.mem.eql(u8, gate, "migration-required") or
        std.mem.eql(u8, gate, "operational-human-required") or
        std.mem.eql(u8, gate, "rollback-required");
}

fn citationsComplete(proposal: AppPatchProposalRecord) bool {
    for (proposal.policy_gates) |gate| {
        if (std.mem.eql(u8, gate, "source-only")) {
            if (proposal.citations.source_files.len == 0) return false;
        } else if (std.mem.eql(u8, gate, "config-only")) {
            if (proposal.citations.config_keys.len == 0) return false;
        } else if (std.mem.eql(u8, gate, "migration-required")) {
            if (proposal.citations.migration_files.len == 0) return false;
        } else if (std.mem.eql(u8, gate, "operational-human-required")) {
            if (proposal.citations.runbooks.len == 0) return false;
        } else if (std.mem.eql(u8, gate, "rollback-required")) {
            if (proposal.citations.rollback_plans.len == 0) return false;
        } else {
            return false;
        }
    }
    return true;
}

fn highRiskReviewLinked(proposal: AppPatchProposalRecord) bool {
    var saw_high_risk = false;
    for (proposal.policy_gates) |gate| {
        if (isHighRiskGate(gate)) {
            saw_high_risk = true;
            break;
        }
    }
    if (!saw_high_risk) return true;
    return proposal.source.human_review != null and proposal.source.human_review.?.len > 0;
}

fn requiredCommandsSatisfied(verified_commands: []const []const u8, required_commands: []const []const u8) bool {
    for (required_commands) |required| {
        var found = false;
        for (verified_commands) |verified| {
            if (std.mem.eql(u8, verified, required)) {
                found = true;
                break;
            }
        }
        if (!found) return false;
    }
    return true;
}

fn allChecksPassed(checks: []const ReadinessCheck) bool {
    for (checks) |check| {
        if (check.status != .pass) return false;
    }
    return true;
}

fn applicationSteps(status: ReadinessStatus) []const []const u8 {
    return switch (status) {
        .ready => &.{
            "Apply the reviewed source, config, migration, operational, or rollback changes outside this readiness command.",
            "Run every required verification command after applying the real change.",
            "Record a guarded app application artifact only after before/after evidence exists.",
        },
        .blocked => &.{
            "Resolve failed readiness checks before attempting app application.",
            "Regenerate app application readiness after proposal evidence changes.",
            "Do not record app application until readiness is ready and before/after evidence exists.",
        },
    };
}

fn readinessGuardrails(status: ReadinessStatus) []const []const u8 {
    return switch (status) {
        .ready => &.{
            "Readiness does not edit app source, config, migrations, operations, rollback plans, deployments, databases, queues, or external state.",
            "ready_for_application=true means the proposal is ready to attempt, not that it was applied.",
            "applied=true is reserved for a future guarded app application artifact with before/after verification.",
        },
        .blocked => &.{
            "Blocked readiness must not be treated as app application approval.",
            "Do not edit or apply app changes from blocked readiness evidence.",
            "Resolve missing citations, human-review links, or verification evidence before trying again.",
        },
    };
}

fn formatAppApplicationReadinessJson(
    allocator: std.mem.Allocator,
    input: ReadinessInput,
    result: ReadinessResult,
) ![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "{\n");
    try output.appendSlice(allocator, "  \"schema\": ");
    try appendJsonString(allocator, &output, app_application_readiness_schema);
    try output.appendSlice(allocator, ",\n  \"schema_version\": 1,\n");
    try output.appendSlice(allocator, "  \"mode\": ");
    try appendJsonString(allocator, &output, input.options.mode);
    try output.appendSlice(allocator, ",\n  \"source_proposal\": ");
    try appendJsonString(allocator, &output, input.source_proposal_path);
    try output.appendSlice(allocator, ",\n  \"decision\": ");
    try appendJsonString(allocator, &output, decisionText(input.options.decision));
    try output.appendSlice(allocator, ",\n  \"readiness_status\": ");
    try appendJsonString(allocator, &output, readinessStatusText(result.status));
    try output.print(allocator, ",\n  \"ready_for_application\": {},\n", .{result.ready_for_application});
    try output.appendSlice(allocator, "  \"reviewed_by\": ");
    try appendJsonString(allocator, &output, input.options.reviewed_by);
    try output.appendSlice(allocator, ",\n  \"policy\": ");
    try appendJsonString(allocator, &output, input.options.policy);
    try output.appendSlice(allocator, ",\n  \"reason\": ");
    try appendJsonString(allocator, &output, input.options.reason);
    try output.print(allocator, ",\n  \"applied\": {},\n", .{result.applied});
    try output.appendSlice(allocator, "  \"mutation_authority\": ");
    try appendJsonString(allocator, &output, result.mutation_authority);
    try output.appendSlice(allocator, ",\n  \"target\": ");
    try appendJsonString(allocator, &output, input.proposal.target);
    try output.appendSlice(allocator, ",\n  \"summary\": ");
    try appendJsonString(allocator, &output, input.proposal.summary);
    try output.appendSlice(allocator, ",\n  \"change\": ");
    try appendJsonString(allocator, &output, input.proposal.change);
    try output.appendSlice(allocator, ",\n  \"source\": ");
    try appendSourceJson(allocator, &output, input);
    try output.appendSlice(allocator, ",\n  \"policy_gates\": ");
    try appendStringArray(allocator, &output, input.proposal.policy_gates);
    try output.appendSlice(allocator, ",\n  \"citations\": ");
    try appendCitationsJson(allocator, &output, input.proposal.citations);
    try output.appendSlice(allocator, ",\n  \"event_ids\": ");
    try appendU64Array(allocator, &output, input.proposal.event_ids);
    try output.appendSlice(allocator, ",\n  \"checks\": ");
    try appendChecksJson(allocator, &output, result.checks);
    try output.appendSlice(allocator, ",\n  \"required_verification_commands\": ");
    try appendStringArray(allocator, &output, input.proposal.required_verification_commands);
    try output.appendSlice(allocator, ",\n  \"verified_commands\": ");
    try appendStringArray(allocator, &output, input.options.verified_commands);
    try output.appendSlice(allocator, ",\n  \"application_steps\": ");
    try appendStringArray(allocator, &output, applicationSteps(result.status));
    try output.appendSlice(allocator, ",\n  \"readiness_guardrails\": ");
    try appendStringArray(allocator, &output, readinessGuardrails(result.status));
    try output.append(allocator, '\n');
    try output.appendSlice(allocator, "}\n");

    return output.toOwnedSlice(allocator);
}

fn formatAppApplicationReadinessText(
    allocator: std.mem.Allocator,
    input: ReadinessInput,
    result: ReadinessResult,
) ![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "zigeffect app application readiness\n");
    try output.print(allocator, "schema: {s}\n", .{app_application_readiness_schema});
    try output.print(allocator, "source proposal: {s}\n", .{input.source_proposal_path});
    try output.print(allocator, "decision: {s}\n", .{decisionText(input.options.decision)});
    try output.print(allocator, "readiness_status: {s}\n", .{readinessStatusText(result.status)});
    try output.print(allocator, "ready_for_application: {}\n", .{result.ready_for_application});
    try output.print(allocator, "reviewed_by: {s}\n", .{input.options.reviewed_by});
    try output.print(allocator, "policy: {s}\n", .{input.options.policy});
    try output.print(allocator, "reason: {s}\n", .{input.options.reason});
    try output.print(allocator, "applied: {}\n", .{result.applied});
    try output.print(allocator, "mutation_authority: {s}\n", .{result.mutation_authority});
    try output.print(allocator, "target: {s}\n", .{input.proposal.target});
    try output.print(allocator, "summary: {s}\n", .{input.proposal.summary});
    try output.print(allocator, "change: {s}\n\n", .{input.proposal.change});

    try output.appendSlice(allocator, "source:\n");
    try output.print(allocator, "- proposal: {s}\n", .{input.source_proposal_path});
    try output.print(allocator, "- policy: {s}\n", .{input.proposal.source.policy});
    try output.print(allocator, "- app remediation audit: {s}\n", .{input.proposal.source.app_remediation_audit});
    try output.print(allocator, "- app artifact: {s}\n", .{input.proposal.source.app_artifact});
    if (input.proposal.source.human_review) |human_review| try output.print(allocator, "- human review: {s}\n", .{human_review});
    try output.append(allocator, '\n');

    try appendTextList(allocator, &output, "policy gates", input.proposal.policy_gates);
    try appendTextList(allocator, &output, "source files", input.proposal.citations.source_files);
    try appendTextList(allocator, &output, "config keys", input.proposal.citations.config_keys);
    try appendTextList(allocator, &output, "migration files", input.proposal.citations.migration_files);
    try appendTextList(allocator, &output, "runbooks", input.proposal.citations.runbooks);
    try appendTextList(allocator, &output, "rollback plans", input.proposal.citations.rollback_plans);

    try output.appendSlice(allocator, "event ids:\n");
    if (input.proposal.event_ids.len == 0) {
        try output.appendSlice(allocator, "- none\n\n");
    } else {
        for (input.proposal.event_ids) |event_id| try output.print(allocator, "- {d}\n", .{event_id});
        try output.append(allocator, '\n');
    }

    try output.appendSlice(allocator, "checks:\n");
    for (result.checks) |check| {
        try output.print(allocator, "- {s}: {s} - {s}\n", .{ check.name, checkStatusText(check.status), check.detail });
    }
    try output.append(allocator, '\n');

    try appendTextList(allocator, &output, "required verification commands", input.proposal.required_verification_commands);
    try appendTextList(allocator, &output, "verified commands", input.options.verified_commands);
    try appendTextList(allocator, &output, "application steps", applicationSteps(result.status));
    try appendTextList(allocator, &output, "readiness guardrails", readinessGuardrails(result.status));

    return output.toOwnedSlice(allocator);
}

fn appendSourceJson(allocator: std.mem.Allocator, output: *std.ArrayList(u8), input: ReadinessInput) !void {
    try output.appendSlice(allocator, "{\n");
    try output.appendSlice(allocator, "    \"proposal\": ");
    try appendJsonString(allocator, output, input.source_proposal_path);
    try output.appendSlice(allocator, ",\n    \"policy\": ");
    try appendJsonString(allocator, output, input.proposal.source.policy);
    try output.appendSlice(allocator, ",\n    \"app_remediation_audit\": ");
    try appendJsonString(allocator, output, input.proposal.source.app_remediation_audit);
    try output.appendSlice(allocator, ",\n    \"app_artifact\": ");
    try appendJsonString(allocator, output, input.proposal.source.app_artifact);
    if (input.proposal.source.human_review) |human_review| {
        try output.appendSlice(allocator, ",\n    \"human_review\": ");
        try appendJsonString(allocator, output, human_review);
    }
    try output.appendSlice(allocator, "\n  }");
}

fn appendCitationsJson(allocator: std.mem.Allocator, output: *std.ArrayList(u8), citations: ProposalCitations) !void {
    try output.appendSlice(allocator, "{\n");
    try output.appendSlice(allocator, "    \"source_files\": ");
    try appendStringArray(allocator, output, citations.source_files);
    try output.appendSlice(allocator, ",\n    \"config_keys\": ");
    try appendStringArray(allocator, output, citations.config_keys);
    try output.appendSlice(allocator, ",\n    \"migration_files\": ");
    try appendStringArray(allocator, output, citations.migration_files);
    try output.appendSlice(allocator, ",\n    \"runbooks\": ");
    try appendStringArray(allocator, output, citations.runbooks);
    try output.appendSlice(allocator, ",\n    \"rollback_plans\": ");
    try appendStringArray(allocator, output, citations.rollback_plans);
    try output.appendSlice(allocator, "\n  }");
}

fn appendChecksJson(allocator: std.mem.Allocator, output: *std.ArrayList(u8), checks: []const ReadinessCheck) !void {
    try output.appendSlice(allocator, "[");
    for (checks, 0..) |check, index| {
        if (index > 0) try output.appendSlice(allocator, ", ");
        try output.appendSlice(allocator, "{ \"name\": ");
        try appendJsonString(allocator, output, check.name);
        try output.appendSlice(allocator, ", \"status\": ");
        try appendJsonString(allocator, output, checkStatusText(check.status));
        try output.appendSlice(allocator, ", \"detail\": ");
        try appendJsonString(allocator, output, check.detail);
        try output.appendSlice(allocator, " }");
    }
    try output.appendSlice(allocator, "]");
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

fn appendTextList(allocator: std.mem.Allocator, output: *std.ArrayList(u8), label: []const u8, values: []const []const u8) !void {
    try output.print(allocator, "{s}:\n", .{label});
    if (values.len == 0) {
        try output.appendSlice(allocator, "- none\n\n");
        return;
    }
    for (values) |value| try output.print(allocator, "- {s}\n", .{value});
    try output.append(allocator, '\n');
}

fn readArtifact(io: std.Io, allocator: std.mem.Allocator, path: []const u8) ![]const u8 {
    return std.Io.Dir.cwd().readFileAlloc(io, path, allocator, .limited(1024 * 1024)) catch |err| switch (err) {
        error.FileNotFound => error.MissingAppPatchProposalInput,
        else => return err,
    };
}

fn writeArtifact(io: std.Io, path: []const u8, contents: []const u8) !void {
    const cwd = std.Io.Dir.cwd();
    if (std.mem.lastIndexOfScalar(u8, path, '/')) |slash| {
        try cwd.createDirPath(io, path[0..slash]);
    }
    try cwd.writeFile(io, .{ .sub_path = path, .data = contents });
}

fn runLocal(init: std.process.Init, options: Options) !void {
    const allocator = init.gpa;
    const paths = try outputPathsForOptions(allocator, options);
    defer paths.deinit(allocator);

    const proposal_json = try readArtifact(init.io, allocator, options.proposal_path);
    defer allocator.free(proposal_json);
    var parsed = try parseProposal(allocator, proposal_json);
    defer parsed.deinit();

    var input = try readinessInputFromProposal(allocator, options, options.proposal_path, parsed.value);
    defer input.deinit(allocator);
    var reports = try formatAppApplicationReadinessReports(allocator, input);
    defer reports.deinit(allocator);

    try writeArtifact(init.io, paths.json_path, reports.json);
    try writeArtifact(init.io, paths.text_path, reports.text);
    std.debug.print("{s}", .{reports.text});
}

fn failUsage(err: anyerror) noreturn {
    std.debug.print("causal-app-application-readiness error: {s}\n{s}", .{ @errorName(err), usage() });
    std.process.exit(2);
}

pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    var options = parseOptions(init.gpa, args) catch |err| failUsage(err);
    defer options.deinit(init.gpa);

    runLocal(init, options) catch |err| switch (err) {
        error.MissingAppPatchProposalInput,
        error.InvalidProposalPath,
        error.UnsupportedAppPatchProposalSchema,
        error.ProposalNotDraft,
        error.ProposalApprovalNotPending,
        error.ProposalAlreadyApproved,
        error.ProposalAlreadyApplied,
        error.ProposalMutationAuthorityNotNone,
        error.MissingTarget,
        error.MissingSummary,
        error.MissingChange,
        error.MissingReason,
        => failUsage(err),
        else => return err,
    };
}

const low_risk_proposal_json =
    \\{
    \\  "schema": "zigeffect.causal.app-patch-proposal.v1",
    \\  "schema_version": 1,
    \\  "mode": "local",
    \\  "target": "yachdee-platform",
    \\  "proposal_status": "draft",
    \\  "approval_status": "pending",
    \\  "approved": false,
    \\  "applied": false,
    \\  "mutation_authority": "none",
    \\  "summary": "Wire missing app requirement",
    \\  "change": "Update app source and config citation",
    \\  "source": {
    \\    "policy": ".zig-cache/causal-artifacts/yachdee-platform-app-policy-decision.json",
    \\    "app_remediation_audit": ".zig-cache/causal-artifacts/yachdee-platform-app-remediation-audit.json",
    \\    "app_artifact": ".zig-cache/causal-artifacts/app.json"
    \\  },
    \\  "policy_gates": ["source-only", "config-only"],
    \\  "citations": {
    \\    "source_files": ["apps/platform/src/worker.ts"],
    \\    "config_keys": ["YACHDEE_API_BASE_URL"],
    \\    "migration_files": [],
    \\    "runbooks": [],
    \\    "rollback_plans": []
    \\  },
    \\  "event_ids": [2],
    \\  "required_verification_commands": ["zig build causal-query -- --file app.json cause 2"],
    \\  "claim_guardrails": [],
    \\  "proposal_guardrails": ["This proposal does not edit app source, config, migrations, operations, or rollback plans."]
    \\}
;

const high_risk_proposal_json =
    \\{
    \\  "schema": "zigeffect.causal.app-patch-proposal.v1",
    \\  "schema_version": 1,
    \\  "mode": "local",
    \\  "target": "yachdee-platform",
    \\  "proposal_status": "draft",
    \\  "approval_status": "pending",
    \\  "approved": false,
    \\  "applied": false,
    \\  "mutation_authority": "none",
    \\  "summary": "Apply app migration",
    \\  "change": "Update migration, runbook, and rollback plan",
    \\  "source": {
    \\    "policy": "app-policy.json",
    \\    "app_remediation_audit": "app-audit.json",
    \\    "app_artifact": "app.json",
    \\    "human_review": "app-human-review.json"
    \\  },
    \\  "policy_gates": ["migration-required", "operational-human-required", "rollback-required"],
    \\  "citations": {
    \\    "source_files": [],
    \\    "config_keys": [],
    \\    "migration_files": ["packages/app/migrations/001.sql"],
    \\    "runbooks": ["docs/runbooks/app-migration.md"],
    \\    "rollback_plans": ["docs/runbooks/app-rollback.md"]
    \\  },
    \\  "event_ids": [4],
    \\  "required_verification_commands": ["zig build causal-query -- --file app.json cause 4"]
    \\}
;

const unknown_gate_proposal_json =
    \\{
    \\  "schema": "zigeffect.causal.app-patch-proposal.v1",
    \\  "schema_version": 1,
    \\  "mode": "local",
    \\  "target": "yachdee-platform",
    \\  "proposal_status": "draft",
    \\  "approval_status": "pending",
    \\  "approved": false,
    \\  "applied": false,
    \\  "mutation_authority": "none",
    \\  "summary": "Unknown gate",
    \\  "change": "Unknown gate",
    \\  "source": {"policy": "app-policy.json", "app_remediation_audit": "app-audit.json", "app_artifact": "app.json"},
    \\  "policy_gates": ["surprise-required"],
    \\  "citations": {"source_files": ["apps/platform/src/worker.ts"], "config_keys": [], "migration_files": [], "runbooks": [], "rollback_plans": []},
    \\  "event_ids": [],
    \\  "required_verification_commands": []
    \\}
;

const missing_source_citation_proposal_json =
    \\{
    \\  "schema": "zigeffect.causal.app-patch-proposal.v1",
    \\  "schema_version": 1,
    \\  "mode": "local",
    \\  "target": "yachdee-platform",
    \\  "proposal_status": "draft",
    \\  "approval_status": "pending",
    \\  "approved": false,
    \\  "applied": false,
    \\  "mutation_authority": "none",
    \\  "summary": "Missing source",
    \\  "change": "Missing source",
    \\  "source": {"policy": "app-policy.json", "app_remediation_audit": "app-audit.json", "app_artifact": "app.json"},
    \\  "policy_gates": ["source-only"],
    \\  "citations": {"source_files": [], "config_keys": [], "migration_files": [], "runbooks": [], "rollback_plans": []},
    \\  "event_ids": [],
    \\  "required_verification_commands": []
    \\}
;

const high_risk_missing_review_proposal_json =
    \\{
    \\  "schema": "zigeffect.causal.app-patch-proposal.v1",
    \\  "schema_version": 1,
    \\  "mode": "local",
    \\  "target": "yachdee-platform",
    \\  "proposal_status": "draft",
    \\  "approval_status": "pending",
    \\  "approved": false,
    \\  "applied": false,
    \\  "mutation_authority": "none",
    \\  "summary": "Missing human review",
    \\  "change": "Missing human review",
    \\  "source": {"policy": "app-policy.json", "app_remediation_audit": "app-audit.json", "app_artifact": "app.json"},
    \\  "policy_gates": ["migration-required"],
    \\  "citations": {"source_files": [], "config_keys": [], "migration_files": ["packages/app/migrations/001.sql"], "runbooks": [], "rollback_plans": []},
    \\  "event_ids": [],
    \\  "required_verification_commands": []
    \\}
;

fn readyOptions() Options {
    return .{
        .mode = "local",
        .proposal_path = ".zig-cache/causal-artifacts/yachdee-platform-app-patch-proposal.json",
        .decision = .approve,
        .reviewed_by = "local-reviewer",
        .policy = "manual-app-application-readiness",
        .reason = "reviewed proposal citations and verification",
        .verified_commands = &.{"zig build causal-query -- --file app.json cause 2"},
    };
}

test "usage text names app application readiness inputs" {
    try std.testing.expect(std.mem.indexOf(u8, usage(), "causal-app-application-readiness") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage(), "--proposal <app-patch-proposal-json>") != null);
    try std.testing.expectEqualStrings("zigeffect.causal.app-patch-proposal.v1", app_patch_proposal_schema);
    try std.testing.expectEqualStrings("zigeffect.causal.app-application-readiness.v1", app_application_readiness_schema);
}

test "app readiness options parse reviewer policy decision reason verified commands and out prefix" {
    const args = [_][]const u8{
        "zigeffect-causal-app-application-readiness",
        "local",
        "--proposal",
        ".zig-cache/causal-artifacts/yachdee-platform-app-patch-proposal.json",
        "approve",
        "--by",
        "sean",
        "--policy",
        "local-app-readiness",
        "--reason",
        "reviewed proposal evidence",
        "--verified",
        "zig build causal-query -- --file app.json cause 2",
        "--out-prefix",
        ".zig-cache/causal-artifacts/yachdee-platform",
    };

    var options = try parseOptions(std.testing.allocator, &args);
    defer options.deinit(std.testing.allocator);

    try std.testing.expectEqualStrings("local", options.mode);
    try std.testing.expectEqualStrings(".zig-cache/causal-artifacts/yachdee-platform-app-patch-proposal.json", options.proposal_path);
    try std.testing.expectEqual(ReadinessDecision.approve, options.decision);
    try std.testing.expectEqualStrings("sean", options.reviewed_by);
    try std.testing.expectEqualStrings("local-app-readiness", options.policy);
    try std.testing.expectEqualStrings("reviewed proposal evidence", options.reason);
    try std.testing.expectEqual(@as(usize, 1), options.verified_commands.len);
    try std.testing.expectEqualStrings(".zig-cache/causal-artifacts/yachdee-platform", options.out_prefix.?);
}

test "app readiness output paths derive from proposal path and out prefix" {
    const defaults = try outputPathsForOptions(std.testing.allocator, readyOptions());
    defer defaults.deinit(std.testing.allocator);

    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/yachdee-platform-app-application-readiness.json",
        defaults.json_path,
    );
    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/yachdee-platform-app-application-readiness.txt",
        defaults.text_path,
    );

    const custom = try outputPathsForOptions(std.testing.allocator, .{
        .mode = "local",
        .proposal_path = ".zig-cache/causal-artifacts/yachdee-platform-app-patch-proposal.json",
        .decision = .approve,
        .reason = "reviewed",
        .out_prefix = ".zig-cache/causal-artifacts/custom",
    });
    defer custom.deinit(std.testing.allocator);

    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/custom-app-application-readiness.json",
        custom.json_path,
    );
}

test "approved low-risk proposal with verification becomes ready without mutation authority" {
    var parsed = try parseProposal(std.testing.allocator, low_risk_proposal_json);
    defer parsed.deinit();

    var input = try readinessInputFromProposal(std.testing.allocator, readyOptions(), readyOptions().proposal_path, parsed.value);
    defer input.deinit(std.testing.allocator);

    const result = try evaluateReadiness(std.testing.allocator, input);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(ReadinessStatus.ready, result.status);
    try std.testing.expect(result.ready_for_application);
    try std.testing.expect(!result.applied);
    try std.testing.expectEqualStrings("none", result.mutation_authority);
    try std.testing.expect(checkPassed(result.checks, "required-verification-recorded"));

    var reports = try formatAppApplicationReadinessReports(std.testing.allocator, input);
    defer reports.deinit(std.testing.allocator);

    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"schema\": \"zigeffect.causal.app-application-readiness.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"readiness_status\": \"ready\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"ready_for_application\": true") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"applied\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"mutation_authority\": \"none\"") != null);
}

test "reject decision blocks readiness without applying" {
    var parsed = try parseProposal(std.testing.allocator, low_risk_proposal_json);
    defer parsed.deinit();

    const options = Options{
        .mode = "local",
        .proposal_path = ".zig-cache/causal-artifacts/yachdee-platform-app-patch-proposal.json",
        .decision = .reject,
        .reason = "not ready to apply",
    };
    var input = try readinessInputFromProposal(std.testing.allocator, options, options.proposal_path, parsed.value);
    defer input.deinit(std.testing.allocator);

    const result = try evaluateReadiness(std.testing.allocator, input);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(ReadinessStatus.blocked, result.status);
    try std.testing.expect(!result.ready_for_application);
    try std.testing.expect(!result.applied);
    try std.testing.expect(checkFailed(result.checks, "decision-approved"));
}

test "missing required verification blocks readiness" {
    var parsed = try parseProposal(std.testing.allocator, low_risk_proposal_json);
    defer parsed.deinit();

    const options = Options{
        .mode = "local",
        .proposal_path = ".zig-cache/causal-artifacts/yachdee-platform-app-patch-proposal.json",
        .decision = .approve,
        .reason = "reviewed but forgot verification",
    };
    var input = try readinessInputFromProposal(std.testing.allocator, options, options.proposal_path, parsed.value);
    defer input.deinit(std.testing.allocator);

    const result = try evaluateReadiness(std.testing.allocator, input);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(ReadinessStatus.blocked, result.status);
    try std.testing.expect(checkFailed(result.checks, "required-verification-recorded"));
}

test "app readiness rejects unsupported or already applied proposal state" {
    const applied_json = try std.mem.replaceOwned(
        u8,
        std.testing.allocator,
        low_risk_proposal_json,
        "\"applied\": false",
        "\"applied\": true",
    );
    defer std.testing.allocator.free(applied_json);
    try std.testing.expectError(error.ProposalAlreadyApplied, parseProposal(std.testing.allocator, applied_json));

    const mutating_json = try std.mem.replaceOwned(
        u8,
        std.testing.allocator,
        low_risk_proposal_json,
        "\"mutation_authority\": \"none\"",
        "\"mutation_authority\": \"app-source\"",
    );
    defer std.testing.allocator.free(mutating_json);
    try std.testing.expectError(error.ProposalMutationAuthorityNotNone, parseProposal(std.testing.allocator, mutating_json));
}

test "app readiness blocks unknown policy gates" {
    var parsed = try parseProposal(std.testing.allocator, unknown_gate_proposal_json);
    defer parsed.deinit();

    var input = try readinessInputFromProposal(std.testing.allocator, readyOptions(), readyOptions().proposal_path, parsed.value);
    defer input.deinit(std.testing.allocator);
    const result = try evaluateReadiness(std.testing.allocator, input);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(ReadinessStatus.blocked, result.status);
    try std.testing.expect(checkFailed(result.checks, "policy-gates-known"));
}

test "app readiness requires source and config citations" {
    var parsed = try parseProposal(std.testing.allocator, missing_source_citation_proposal_json);
    defer parsed.deinit();

    var input = try readinessInputFromProposal(std.testing.allocator, readyOptions(), readyOptions().proposal_path, parsed.value);
    defer input.deinit(std.testing.allocator);
    const result = try evaluateReadiness(std.testing.allocator, input);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(ReadinessStatus.blocked, result.status);
    try std.testing.expect(checkFailed(result.checks, "citations-complete"));
}

test "app readiness requires high risk citations and human review link" {
    var parsed = try parseProposal(std.testing.allocator, high_risk_proposal_json);
    defer parsed.deinit();

    var input = try readinessInputFromProposal(std.testing.allocator, .{
        .mode = "local",
        .proposal_path = "app-app-patch-proposal.json",
        .decision = .approve,
        .reason = "reviewed high-risk evidence",
        .verified_commands = &.{"zig build causal-query -- --file app.json cause 4"},
    }, "app-app-patch-proposal.json", parsed.value);
    defer input.deinit(std.testing.allocator);
    const ready_result = try evaluateReadiness(std.testing.allocator, input);
    defer ready_result.deinit(std.testing.allocator);
    try std.testing.expectEqual(ReadinessStatus.ready, ready_result.status);

    var missing_review = try parseProposal(std.testing.allocator, high_risk_missing_review_proposal_json);
    defer missing_review.deinit();
    var blocked_input = try readinessInputFromProposal(std.testing.allocator, readyOptions(), readyOptions().proposal_path, missing_review.value);
    defer blocked_input.deinit(std.testing.allocator);
    const blocked_result = try evaluateReadiness(std.testing.allocator, blocked_input);
    defer blocked_result.deinit(std.testing.allocator);
    try std.testing.expectEqual(ReadinessStatus.blocked, blocked_result.status);
    try std.testing.expect(checkFailed(blocked_result.checks, "high-risk-human-review-linked"));
}

test "app readiness text output includes checks verification steps and guardrails" {
    var parsed = try parseProposal(std.testing.allocator, low_risk_proposal_json);
    defer parsed.deinit();

    var input = try readinessInputFromProposal(std.testing.allocator, readyOptions(), readyOptions().proposal_path, parsed.value);
    defer input.deinit(std.testing.allocator);
    var reports = try formatAppApplicationReadinessReports(std.testing.allocator, input);
    defer reports.deinit(std.testing.allocator);

    try std.testing.expect(std.mem.indexOf(u8, reports.text, "zigeffect app application readiness") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.text, "checks:") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.text, "required verification commands:") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.text, "verified commands:") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.text, "application steps:") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.text, "readiness guardrails:") != null);
}
