const std = @import("std");

const app_policy_schema = "zigeffect.causal.app-policy-decision.v1";
const app_patch_proposal_schema = "zigeffect.causal.app-patch-proposal.v1";
const app_human_review_schema = "zigeffect.causal.app-human-review.v1";

const Options = struct {
    mode: []const u8,
    policy_path: []const u8,
    summary: []const u8,
    change: []const u8,
    source_files: []const []const u8 = &.{},
    config_keys: []const []const u8 = &.{},
    migration_files: []const []const u8 = &.{},
    runbooks: []const []const u8 = &.{},
    rollback_plans: []const []const u8 = &.{},
    review_path: ?[]const u8 = null,
    out_prefix: ?[]const u8 = null,

    fn deinit(self: *Options, allocator: std.mem.Allocator) void {
        if (self.source_files.len > 0) allocator.free(self.source_files);
        if (self.config_keys.len > 0) allocator.free(self.config_keys);
        if (self.migration_files.len > 0) allocator.free(self.migration_files);
        if (self.runbooks.len > 0) allocator.free(self.runbooks);
        if (self.rollback_plans.len > 0) allocator.free(self.rollback_plans);
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

const PolicySource = struct {
    app_remediation_audit: []const u8,
    app_artifact: []const u8,
};

const AppPolicyRecord = struct {
    schema: []const u8,
    schema_version: u32,
    mode: []const u8,
    target: []const u8,
    decision: []const u8,
    approval_status: []const u8,
    mutation_authority: []const u8,
    applied: bool,
    source: PolicySource,
    policy_gates: []const []const u8,
    event_ids: []const u64 = &.{},
    required_verification_commands: []const []const u8 = &.{},
    guardrails: []const []const u8 = &.{},
};

const ReviewSource = struct {
    policy: []const u8,
    app_remediation_audit: []const u8,
    app_artifact: []const u8,
};

const ReviewCitations = struct {
    source_files: []const []const u8 = &.{},
    config_keys: []const []const u8 = &.{},
    migration_files: []const []const u8 = &.{},
    runbooks: []const []const u8 = &.{},
    rollback_plans: []const []const u8 = &.{},
};

const AppHumanReviewRecord = struct {
    schema: []const u8,
    schema_version: u32,
    mode: []const u8,
    target: []const u8,
    review_status: []const u8,
    approval_status: []const u8,
    approved: bool,
    applied: bool,
    mutation_authority: []const u8,
    source: ReviewSource,
    policy_gates: []const []const u8,
    citations: ReviewCitations,
};

const AppHumanReviewInput = struct {
    path: []const u8,
    record: AppHumanReviewRecord,
};

const ProposalSource = struct {
    policy: []const u8,
    app_remediation_audit: []const u8,
    app_artifact: []const u8,
    human_review: ?[]const u8 = null,
};

const ProposalInput = struct {
    options: Options,
    target: []const u8,
    source: ProposalSource,
    policy_gates: []const []const u8,
    event_ids: []const u64,
    required_verification_commands: []const []const u8,
    claim_guardrails: []const []const u8,
    review_citations: ?ReviewCitations = null,

    fn deinit(self: *ProposalInput, allocator: std.mem.Allocator) void {
        _ = self;
        _ = allocator;
    }
};

const AppPatchProposalReports = struct {
    json: []const u8,
    text: []const u8,

    fn deinit(self: *AppPatchProposalReports, allocator: std.mem.Allocator) void {
        allocator.free(self.json);
        allocator.free(self.text);
    }
};

fn usage() []const u8 {
    return "usage: zig build causal-app-patch-proposal -- local --policy <app-policy-decision-json> --summary <summary> --change <description> [--review <app-human-review-json>] [--file <path>] [--config <key>] [--migration <path>] [--runbook <path>] [--rollback <path>] [--out-prefix <path-prefix>]\n";
}

fn parseOptions(allocator: std.mem.Allocator, args: []const []const u8) !Options {
    if (args.len < 2) return error.MissingMode;
    if (!std.mem.eql(u8, args[1], "local")) return error.UnknownMode;

    var policy_path: ?[]const u8 = null;
    var summary: ?[]const u8 = null;
    var change: ?[]const u8 = null;
    var review_path: ?[]const u8 = null;
    var out_prefix: ?[]const u8 = null;
    var source_files = std.ArrayList([]const u8).empty;
    var config_keys = std.ArrayList([]const u8).empty;
    var migration_files = std.ArrayList([]const u8).empty;
    var runbooks = std.ArrayList([]const u8).empty;
    var rollback_plans = std.ArrayList([]const u8).empty;
    errdefer {
        source_files.deinit(allocator);
        config_keys.deinit(allocator);
        migration_files.deinit(allocator);
        runbooks.deinit(allocator);
        rollback_plans.deinit(allocator);
    }

    var index: usize = 2;
    while (index < args.len) {
        const arg = args[index];
        if (!std.mem.startsWith(u8, arg, "--")) return error.UnknownArgument;
        if (index + 1 >= args.len) return error.MissingFlagValue;
        const value = args[index + 1];
        if (std.mem.eql(u8, arg, "--policy")) {
            policy_path = value;
        } else if (std.mem.eql(u8, arg, "--summary")) {
            summary = value;
        } else if (std.mem.eql(u8, arg, "--change")) {
            change = value;
        } else if (std.mem.eql(u8, arg, "--file")) {
            try source_files.append(allocator, value);
        } else if (std.mem.eql(u8, arg, "--config")) {
            try config_keys.append(allocator, value);
        } else if (std.mem.eql(u8, arg, "--migration")) {
            try migration_files.append(allocator, value);
        } else if (std.mem.eql(u8, arg, "--runbook")) {
            try runbooks.append(allocator, value);
        } else if (std.mem.eql(u8, arg, "--rollback")) {
            try rollback_plans.append(allocator, value);
        } else if (std.mem.eql(u8, arg, "--review")) {
            review_path = value;
        } else if (std.mem.eql(u8, arg, "--out-prefix")) {
            out_prefix = value;
        } else {
            return error.UnknownFlag;
        }
        index += 2;
    }

    return .{
        .mode = "local",
        .policy_path = policy_path orelse return error.MissingPolicy,
        .summary = summary orelse return error.MissingSummary,
        .change = change orelse return error.MissingChange,
        .source_files = try source_files.toOwnedSlice(allocator),
        .config_keys = try config_keys.toOwnedSlice(allocator),
        .migration_files = try migration_files.toOwnedSlice(allocator),
        .runbooks = try runbooks.toOwnedSlice(allocator),
        .rollback_plans = try rollback_plans.toOwnedSlice(allocator),
        .review_path = review_path,
        .out_prefix = out_prefix,
    };
}

fn outputPathsForOptions(allocator: std.mem.Allocator, options: Options) !OutputPaths {
    const prefix = if (options.out_prefix) |out_prefix|
        try allocator.dupe(u8, out_prefix)
    else blk: {
        if (!std.mem.endsWith(u8, options.policy_path, ".json")) return error.InvalidArtifactPath;
        break :blk try allocator.dupe(u8, options.policy_path[0 .. options.policy_path.len - ".json".len]);
    };
    defer allocator.free(prefix);

    return .{
        .json_path = try std.fmt.allocPrint(allocator, "{s}-app-patch-proposal.json", .{prefix}),
        .text_path = try std.fmt.allocPrint(allocator, "{s}-app-patch-proposal.txt", .{prefix}),
    };
}

fn parseAppPolicy(allocator: std.mem.Allocator, json: []const u8) !std.json.Parsed(AppPolicyRecord) {
    var parsed = try std.json.parseFromSlice(AppPolicyRecord, allocator, json, .{ .ignore_unknown_fields = true });
    errdefer parsed.deinit();
    try validateAppPolicy(parsed.value);
    return parsed;
}

fn validateAppPolicy(policy: AppPolicyRecord) !void {
    if (!std.mem.eql(u8, policy.schema, app_policy_schema)) return error.UnsupportedAppPolicySchema;
    if (policy.schema_version != 1) return error.UnsupportedAppPolicySchema;
    if (!std.mem.eql(u8, policy.mode, "local")) return error.UnsupportedAppPolicySchema;
}

fn parseAppHumanReview(allocator: std.mem.Allocator, json: []const u8) !std.json.Parsed(AppHumanReviewRecord) {
    var parsed = try std.json.parseFromSlice(AppHumanReviewRecord, allocator, json, .{ .ignore_unknown_fields = true });
    errdefer parsed.deinit();
    try validateAppHumanReview(parsed.value);
    return parsed;
}

fn validateAppHumanReview(review: AppHumanReviewRecord) !void {
    if (!std.mem.eql(u8, review.schema, app_human_review_schema)) return error.UnsupportedAppHumanReviewSchema;
    if (review.schema_version != 1) return error.UnsupportedAppHumanReviewSchema;
    if (!std.mem.eql(u8, review.mode, "local")) return error.UnsupportedAppHumanReviewSchema;
}

fn proposalInputFromPolicy(
    allocator: std.mem.Allocator,
    options: Options,
    policy_path: []const u8,
    policy: AppPolicyRecord,
    review: ?AppHumanReviewInput,
) !ProposalInput {
    _ = allocator;
    if (!std.mem.eql(u8, options.mode, "local")) return error.UnknownMode;
    if (options.summary.len == 0) return error.MissingSummary;
    if (options.change.len == 0) return error.MissingChange;
    const low_risk_policy = std.mem.eql(u8, policy.decision, "approve") and std.mem.eql(u8, policy.approval_status, "approve");
    const needs_review_policy = std.mem.eql(u8, policy.decision, "needs-human-review") and std.mem.eql(u8, policy.approval_status, "needs-human-review");
    if (!low_risk_policy and !needs_review_policy) {
        return error.PolicyNotApproved;
    }
    if (policy.applied) return error.PolicyAlreadyApplied;
    if (!std.mem.eql(u8, policy.mutation_authority, "none")) return error.PolicyMutationAuthorityNotNone;
    if (low_risk_policy and !hasAnyCitation(options)) return error.MissingProposalCitation;
    if (needs_review_policy and review == null) return error.HumanReviewRequired;
    if (review) |review_input| try validateReviewMatchesPolicy(policy_path, policy, review_input);

    for (policy.policy_gates) |gate| {
        if (std.mem.eql(u8, gate, "source-only")) {
            if (!hasSourceCitation(options, review)) return error.MissingSourceCitation;
        } else if (std.mem.eql(u8, gate, "config-only")) {
            if (!hasConfigCitation(options, review)) return error.MissingConfigCitation;
        } else if (isHighRiskGate(gate)) {
            if (low_risk_policy) return error.HighRiskGateRequiresHumanReview;
            try validateReviewCitationForGate(gate, review.?);
        } else {
            return error.UnknownPolicyGate;
        }
    }

    return .{
        .options = options,
        .target = policy.target,
        .source = .{
            .policy = policy_path,
            .app_remediation_audit = policy.source.app_remediation_audit,
            .app_artifact = policy.source.app_artifact,
            .human_review = if (review) |review_input| review_input.path else null,
        },
        .policy_gates = policy.policy_gates,
        .event_ids = policy.event_ids,
        .required_verification_commands = policy.required_verification_commands,
        .claim_guardrails = policy.guardrails,
        .review_citations = if (review) |review_input| review_input.record.citations else null,
    };
}

fn hasAnyCitation(options: Options) bool {
    return options.source_files.len > 0 or
        options.config_keys.len > 0 or
        options.migration_files.len > 0 or
        options.runbooks.len > 0 or
        options.rollback_plans.len > 0;
}

fn isHighRiskGate(gate: []const u8) bool {
    return std.mem.eql(u8, gate, "migration-required") or
        std.mem.eql(u8, gate, "operational-human-required") or
        std.mem.eql(u8, gate, "rollback-required");
}

fn validateReviewMatchesPolicy(policy_path: []const u8, policy: AppPolicyRecord, review: AppHumanReviewInput) !void {
    const record = review.record;
    if (!std.mem.eql(u8, record.review_status, "approved") or
        !std.mem.eql(u8, record.approval_status, "approved") or
        !record.approved)
    {
        return error.HumanReviewNotApproved;
    }
    if (record.applied) return error.HumanReviewAlreadyApplied;
    if (!std.mem.eql(u8, record.mutation_authority, "none")) return error.HumanReviewMutationAuthorityNotNone;
    if (!std.mem.eql(u8, record.source.policy, policy_path)) return error.HumanReviewPolicyMismatch;
    if (!std.mem.eql(u8, record.target, policy.target)) return error.HumanReviewTargetMismatch;
    if (!sameStringSet(record.policy_gates, policy.policy_gates)) return error.HumanReviewGateMismatch;
}

fn validateReviewCitationForGate(gate: []const u8, review: AppHumanReviewInput) !void {
    if (std.mem.eql(u8, gate, "migration-required")) {
        if (review.record.citations.migration_files.len == 0) return error.MissingMigrationCitation;
    } else if (std.mem.eql(u8, gate, "operational-human-required")) {
        if (review.record.citations.runbooks.len == 0) return error.MissingRunbookCitation;
    } else if (std.mem.eql(u8, gate, "rollback-required")) {
        if (review.record.citations.rollback_plans.len == 0) return error.MissingRollbackCitation;
    }
}

fn hasSourceCitation(options: Options, review: ?AppHumanReviewInput) bool {
    if (options.source_files.len > 0) return true;
    if (review) |review_input| return review_input.record.citations.source_files.len > 0;
    return false;
}

fn hasConfigCitation(options: Options, review: ?AppHumanReviewInput) bool {
    if (options.config_keys.len > 0) return true;
    if (review) |review_input| return review_input.record.citations.config_keys.len > 0;
    return false;
}

fn sameStringSet(left: []const []const u8, right: []const []const u8) bool {
    if (left.len != right.len) return false;
    for (left) |value| {
        if (!containsString(right, value)) return false;
    }
    for (right) |value| {
        if (!containsString(left, value)) return false;
    }
    return true;
}

fn containsString(values: []const []const u8, candidate: []const u8) bool {
    for (values) |value| {
        if (std.mem.eql(u8, value, candidate)) return true;
    }
    return false;
}

fn firstProposalGuardrail() []const u8 {
    return "This proposal does not edit app source, config, migrations, operations, or rollback plans.";
}

fn secondProposalGuardrail() []const u8 {
    return "Policy approval only authorizes drafting; the proposal still requires review before application.";
}

fn thirdProposalGuardrail() []const u8 {
    return "Config citations name keys or bindings only; never include secret values.";
}

fn formatAppPatchProposalReports(allocator: std.mem.Allocator, input: ProposalInput) !AppPatchProposalReports {
    const json = try formatAppPatchProposalJson(allocator, input);
    errdefer allocator.free(json);
    const text = try formatAppPatchProposalText(allocator, input);
    return .{ .json = json, .text = text };
}

fn formatAppPatchProposalJson(allocator: std.mem.Allocator, input: ProposalInput) ![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "{\n");
    try output.appendSlice(allocator, "  \"schema\": ");
    try appendJsonString(allocator, &output, app_patch_proposal_schema);
    try output.appendSlice(allocator, ",\n  \"schema_version\": 1,\n");
    try output.appendSlice(allocator, "  \"mode\": ");
    try appendJsonString(allocator, &output, input.options.mode);
    try output.appendSlice(allocator, ",\n  \"target\": ");
    try appendJsonString(allocator, &output, input.target);
    try output.appendSlice(allocator, ",\n  \"proposal_status\": \"draft\",\n");
    try output.appendSlice(allocator, "  \"approval_status\": \"pending\",\n");
    try output.appendSlice(allocator, "  \"approved\": false,\n");
    try output.appendSlice(allocator, "  \"applied\": false,\n");
    try output.appendSlice(allocator, "  \"mutation_authority\": \"none\",\n");
    try output.appendSlice(allocator, "  \"summary\": ");
    try appendJsonString(allocator, &output, input.options.summary);
    try output.appendSlice(allocator, ",\n  \"change\": ");
    try appendJsonString(allocator, &output, input.options.change);
    try output.appendSlice(allocator, ",\n  \"source\": {\n");
    try output.appendSlice(allocator, "    \"policy\": ");
    try appendJsonString(allocator, &output, input.source.policy);
    try output.appendSlice(allocator, ",\n    \"app_remediation_audit\": ");
    try appendJsonString(allocator, &output, input.source.app_remediation_audit);
    try output.appendSlice(allocator, ",\n    \"app_artifact\": ");
    try appendJsonString(allocator, &output, input.source.app_artifact);
    if (input.source.human_review) |human_review| {
        try output.appendSlice(allocator, ",\n    \"human_review\": ");
        try appendJsonString(allocator, &output, human_review);
    }
    try output.appendSlice(allocator, "\n  },\n  \"policy_gates\": ");
    try appendStringArray(allocator, &output, input.policy_gates);
    try output.appendSlice(allocator, ",\n  \"citations\": {\n");
    try output.appendSlice(allocator, "    \"source_files\": ");
    try appendStringArray(allocator, &output, proposalSourceFiles(input));
    try output.appendSlice(allocator, ",\n    \"config_keys\": ");
    try appendStringArray(allocator, &output, proposalConfigKeys(input));
    try output.appendSlice(allocator, ",\n    \"migration_files\": ");
    try appendStringArray(allocator, &output, proposalMigrationFiles(input));
    try output.appendSlice(allocator, ",\n    \"runbooks\": ");
    try appendStringArray(allocator, &output, proposalRunbooks(input));
    try output.appendSlice(allocator, ",\n    \"rollback_plans\": ");
    try appendStringArray(allocator, &output, proposalRollbackPlans(input));
    try output.appendSlice(allocator, "\n  },\n  \"event_ids\": ");
    try appendU64Array(allocator, &output, input.event_ids);
    try output.appendSlice(allocator, ",\n  \"required_verification_commands\": ");
    try appendStringArray(allocator, &output, input.required_verification_commands);
    try output.appendSlice(allocator, ",\n  \"claim_guardrails\": ");
    try appendStringArray(allocator, &output, input.claim_guardrails);
    try output.appendSlice(allocator, ",\n  \"proposal_guardrails\": [");
    try appendJsonString(allocator, &output, firstProposalGuardrail());
    try output.appendSlice(allocator, ", ");
    try appendJsonString(allocator, &output, secondProposalGuardrail());
    try output.appendSlice(allocator, ", ");
    try appendJsonString(allocator, &output, thirdProposalGuardrail());
    try output.appendSlice(allocator, "]\n}\n");

    return output.toOwnedSlice(allocator);
}

fn formatAppPatchProposalText(allocator: std.mem.Allocator, input: ProposalInput) ![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "zigeffect app patch proposal\n");
    try output.print(allocator, "schema: {s}\n", .{app_patch_proposal_schema});
    try output.print(allocator, "target: {s}\n", .{input.target});
    try output.appendSlice(allocator, "proposal_status: draft\n");
    try output.appendSlice(allocator, "approval_status: pending\n");
    try output.appendSlice(allocator, "approved: false\n");
    try output.appendSlice(allocator, "applied: false\n");
    try output.appendSlice(allocator, "mutation_authority: none\n");
    try output.print(allocator, "summary: {s}\n", .{input.options.summary});
    try output.print(allocator, "change: {s}\n\n", .{input.options.change});

    try output.appendSlice(allocator, "source:\n");
    try output.print(allocator, "- policy: {s}\n", .{input.source.policy});
    try output.print(allocator, "- app remediation audit: {s}\n", .{input.source.app_remediation_audit});
    try output.print(allocator, "- app artifact: {s}\n", .{input.source.app_artifact});
    if (input.source.human_review) |human_review| {
        try output.print(allocator, "- human review: {s}\n", .{human_review});
    }
    try output.append(allocator, '\n');

    try output.appendSlice(allocator, "policy gates:\n");
    for (input.policy_gates) |gate| try output.print(allocator, "- {s}\n", .{gate});
    try output.append(allocator, '\n');

    try appendTextList(allocator, &output, "source files", proposalSourceFiles(input));
    try appendTextList(allocator, &output, "config keys", proposalConfigKeys(input));
    try appendTextList(allocator, &output, "migration files", proposalMigrationFiles(input));
    try appendTextList(allocator, &output, "runbooks", proposalRunbooks(input));
    try appendTextList(allocator, &output, "rollback plans", proposalRollbackPlans(input));

    try output.appendSlice(allocator, "event ids:\n");
    if (input.event_ids.len == 0) {
        try output.appendSlice(allocator, "- none\n");
    } else {
        for (input.event_ids) |event_id| try output.print(allocator, "- {d}\n", .{event_id});
    }

    try output.appendSlice(allocator, "\nrequired verification commands:\n");
    if (input.required_verification_commands.len == 0) {
        try output.appendSlice(allocator, "- none\n");
    } else {
        for (input.required_verification_commands) |command| try output.print(allocator, "- {s}\n", .{command});
    }

    try output.appendSlice(allocator, "\nclaim guardrails:\n");
    if (input.claim_guardrails.len == 0) {
        try output.appendSlice(allocator, "- none\n");
    } else {
        for (input.claim_guardrails) |guardrail| try output.print(allocator, "- {s}\n", .{guardrail});
    }

    try output.appendSlice(allocator, "\nproposal guardrails:\n");
    try output.print(allocator, "- {s}\n", .{firstProposalGuardrail()});
    try output.print(allocator, "- {s}\n", .{secondProposalGuardrail()});
    try output.print(allocator, "- {s}\n", .{thirdProposalGuardrail()});

    return output.toOwnedSlice(allocator);
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

fn proposalSourceFiles(input: ProposalInput) []const []const u8 {
    if (input.options.source_files.len > 0) return input.options.source_files;
    if (input.review_citations) |citations| return citations.source_files;
    return &.{};
}

fn proposalConfigKeys(input: ProposalInput) []const []const u8 {
    if (input.options.config_keys.len > 0) return input.options.config_keys;
    if (input.review_citations) |citations| return citations.config_keys;
    return &.{};
}

fn proposalMigrationFiles(input: ProposalInput) []const []const u8 {
    if (input.options.migration_files.len > 0) return input.options.migration_files;
    if (input.review_citations) |citations| return citations.migration_files;
    return &.{};
}

fn proposalRunbooks(input: ProposalInput) []const []const u8 {
    if (input.options.runbooks.len > 0) return input.options.runbooks;
    if (input.review_citations) |citations| return citations.runbooks;
    return &.{};
}

fn proposalRollbackPlans(input: ProposalInput) []const []const u8 {
    if (input.options.rollback_plans.len > 0) return input.options.rollback_plans;
    if (input.review_citations) |citations| return citations.rollback_plans;
    return &.{};
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

fn readArtifact(io: std.Io, allocator: std.mem.Allocator, path: []const u8) ![]const u8 {
    return std.Io.Dir.cwd().readFileAlloc(io, path, allocator, .limited(1024 * 1024)) catch |err| switch (err) {
        error.FileNotFound => error.MissingAppPolicyInput,
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

    const policy_json = try readArtifact(init.io, allocator, options.policy_path);
    defer allocator.free(policy_json);
    var parsed = try parseAppPolicy(allocator, policy_json);
    defer parsed.deinit();

    if (options.review_path) |review_path| {
        const review_json = try readArtifact(init.io, allocator, review_path);
        defer allocator.free(review_json);
        var parsed_review = try parseAppHumanReview(allocator, review_json);
        defer parsed_review.deinit();
        var input = try proposalInputFromPolicy(allocator, options, options.policy_path, parsed.value, .{
            .path = review_path,
            .record = parsed_review.value,
        });
        defer input.deinit(allocator);
        var reports = try formatAppPatchProposalReports(allocator, input);
        defer reports.deinit(allocator);
        try writeArtifact(init.io, paths.json_path, reports.json);
        try writeArtifact(init.io, paths.text_path, reports.text);
        std.debug.print("{s}", .{reports.text});
    } else {
        var input = try proposalInputFromPolicy(allocator, options, options.policy_path, parsed.value, null);
        defer input.deinit(allocator);
        var reports = try formatAppPatchProposalReports(allocator, input);
        defer reports.deinit(allocator);
        try writeArtifact(init.io, paths.json_path, reports.json);
        try writeArtifact(init.io, paths.text_path, reports.text);
        std.debug.print("{s}", .{reports.text});
    }
}

fn failUsage(err: anyerror) noreturn {
    std.debug.print("causal-app-patch-proposal error: {s}\n{s}", .{ @errorName(err), usage() });
    std.process.exit(2);
}

pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    var options = parseOptions(init.gpa, args) catch |err| failUsage(err);
    defer options.deinit(init.gpa);

    runLocal(init, options) catch |err| switch (err) {
        error.MissingAppPolicyInput,
        error.InvalidArtifactPath,
        error.UnsupportedAppPolicySchema,
        error.UnsupportedAppHumanReviewSchema,
        error.PolicyNotApproved,
        error.PolicyAlreadyApplied,
        error.PolicyMutationAuthorityNotNone,
        error.HumanReviewRequired,
        error.HumanReviewNotApproved,
        error.HumanReviewAlreadyApplied,
        error.HumanReviewMutationAuthorityNotNone,
        error.HumanReviewPolicyMismatch,
        error.HumanReviewTargetMismatch,
        error.HumanReviewGateMismatch,
        error.MissingMigrationCitation,
        error.MissingRunbookCitation,
        error.MissingRollbackCitation,
        error.MissingProposalCitation,
        error.MissingSourceCitation,
        error.MissingConfigCitation,
        error.HighRiskGateRequiresHumanReview,
        error.UnknownPolicyGate,
        => failUsage(err),
        else => return err,
    };
}

const approved_policy_json =
    \\{
    \\  "schema": "zigeffect.causal.app-policy-decision.v1",
    \\  "schema_version": 1,
    \\  "mode": "local",
    \\  "target": "yachdee-platform",
    \\  "decision": "approve",
    \\  "approval_status": "approve",
    \\  "evaluated_by": "local-app-policy-engine",
    \\  "policy": "local-app-remediation-policy-v1",
    \\  "reason": "app audit is eligible for proposal drafting",
    \\  "reason_codes": ["app-gates-proposal-eligible"],
    \\  "mutation_authority": "none",
    \\  "applied": false,
    \\  "source": {
    \\    "app_remediation_audit": ".zig-cache/causal-artifacts/app-audit.json",
    \\    "app_artifact": ".zig-cache/causal-artifacts/app.json"
    \\  },
    \\  "policy_gates": ["config-only", "source-only"],
    \\  "gate_results": [],
    \\  "event_ids": [2, 3],
    \\  "required_verification_commands": ["zig build causal-query -- --file .zig-cache/causal-artifacts/app.json cause 2"],
    \\  "guardrails": ["Policy approval is advisory and does not apply app source, config, migrations, operations, or rollback actions."]
    \\}
;

const rejected_policy_json =
    \\{
    \\  "schema": "zigeffect.causal.app-policy-decision.v1",
    \\  "schema_version": 1,
    \\  "mode": "local",
    \\  "target": "yachdee-platform",
    \\  "decision": "reject",
    \\  "approval_status": "reject",
    \\  "mutation_authority": "none",
    \\  "applied": false,
    \\  "source": {"app_remediation_audit": "app-audit.json", "app_artifact": "app.json"},
    \\  "policy_gates": ["source-only"],
    \\  "event_ids": [2],
    \\  "required_verification_commands": [],
    \\  "guardrails": []
    \\}
;

const high_risk_approved_policy_json =
    \\{
    \\  "schema": "zigeffect.causal.app-policy-decision.v1",
    \\  "schema_version": 1,
    \\  "mode": "local",
    \\  "target": "yachdee-platform",
    \\  "decision": "approve",
    \\  "approval_status": "approve",
    \\  "mutation_authority": "none",
    \\  "applied": false,
    \\  "source": {"app_remediation_audit": "app-audit.json", "app_artifact": "app.json"},
    \\  "policy_gates": ["migration-required"],
    \\  "event_ids": [4],
    \\  "required_verification_commands": [],
    \\  "guardrails": []
    \\}
;

const needs_review_policy_json =
    \\{
    \\  "schema": "zigeffect.causal.app-policy-decision.v1",
    \\  "schema_version": 1,
    \\  "mode": "local",
    \\  "target": "yachdee-platform",
    \\  "decision": "needs-human-review",
    \\  "approval_status": "needs-human-review",
    \\  "mutation_authority": "none",
    \\  "applied": false,
    \\  "source": {"app_remediation_audit": "app-audit.json", "app_artifact": "app.json"},
    \\  "policy_gates": ["migration-required"],
    \\  "event_ids": [4],
    \\  "required_verification_commands": ["zig build causal-query -- --file app.json cause 4"],
    \\  "guardrails": []
    \\}
;

const approved_human_review_json =
    \\{
    \\  "schema": "zigeffect.causal.app-human-review.v1",
    \\  "schema_version": 1,
    \\  "mode": "local",
    \\  "target": "yachdee-platform",
    \\  "review_status": "approved",
    \\  "approval_status": "approved",
    \\  "approved": true,
    \\  "applied": false,
    \\  "mutation_authority": "none",
    \\  "source": {"policy": "app-policy.json", "app_remediation_audit": "app-audit.json", "app_artifact": "app.json"},
    \\  "policy_gates": ["migration-required"],
    \\  "citations": {"source_files": [], "config_keys": [], "migration_files": ["packages/app/migrations/001.sql"], "runbooks": [], "rollback_plans": []}
    \\}
;

const rejected_human_review_json =
    \\{
    \\  "schema": "zigeffect.causal.app-human-review.v1",
    \\  "schema_version": 1,
    \\  "mode": "local",
    \\  "target": "yachdee-platform",
    \\  "review_status": "rejected",
    \\  "approval_status": "rejected",
    \\  "approved": false,
    \\  "applied": false,
    \\  "mutation_authority": "none",
    \\  "source": {"policy": "app-policy.json", "app_remediation_audit": "app-audit.json", "app_artifact": "app.json"},
    \\  "policy_gates": ["migration-required"],
    \\  "citations": {"source_files": [], "config_keys": [], "migration_files": ["packages/app/migrations/001.sql"], "runbooks": [], "rollback_plans": []}
    \\}
;

const mismatched_human_review_json =
    \\{
    \\  "schema": "zigeffect.causal.app-human-review.v1",
    \\  "schema_version": 1,
    \\  "mode": "local",
    \\  "target": "yachdee-platform",
    \\  "review_status": "approved",
    \\  "approval_status": "approved",
    \\  "approved": true,
    \\  "applied": false,
    \\  "mutation_authority": "none",
    \\  "source": {"policy": "other-policy.json", "app_remediation_audit": "app-audit.json", "app_artifact": "app.json"},
    \\  "policy_gates": ["migration-required"],
    \\  "citations": {"source_files": [], "config_keys": [], "migration_files": ["packages/app/migrations/001.sql"], "runbooks": [], "rollback_plans": []}
    \\}
;

test "usage text names app proposal inputs" {
    try std.testing.expect(std.mem.indexOf(u8, usage(), "causal-app-patch-proposal") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage(), "--policy <app-policy-decision-json>") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage(), "--config <key>") != null);
    try std.testing.expectEqualStrings("zigeffect.causal.app-policy-decision.v1", app_policy_schema);
    try std.testing.expectEqualStrings("zigeffect.causal.app-patch-proposal.v1", app_patch_proposal_schema);
}

test "app proposal options parse repeated citations" {
    const args = [_][]const u8{
        "zigeffect-causal-app-patch-proposal",
        "local",
        "--policy",
        "app-policy.json",
        "--summary",
        "wire app requirement",
        "--change",
        "add provider layer",
        "--review",
        "app-human-review.json",
        "--file",
        "apps/platform/src/worker.ts",
        "--config",
        "YACHDEE_ENV",
        "--rollback",
        "docs/runbooks/revert-yachdee.md",
    };

    var options = try parseOptions(std.testing.allocator, &args);
    defer options.deinit(std.testing.allocator);

    try std.testing.expectEqualStrings("local", options.mode);
    try std.testing.expectEqualStrings("app-policy.json", options.policy_path);
    try std.testing.expectEqualStrings("app-human-review.json", options.review_path.?);
    try std.testing.expectEqual(@as(usize, 1), options.source_files.len);
    try std.testing.expectEqual(@as(usize, 1), options.config_keys.len);
    try std.testing.expectEqual(@as(usize, 1), options.rollback_plans.len);
    try std.testing.expectEqualStrings("apps/platform/src/worker.ts", options.source_files[0]);
    try std.testing.expectEqualStrings("YACHDEE_ENV", options.config_keys[0]);
}

test "app proposal output paths derive from policy path and out prefix" {
    const defaults = try outputPathsForOptions(std.testing.allocator, .{
        .mode = "local",
        .policy_path = ".zig-cache/causal-artifacts/app-policy.json",
        .summary = "summary",
        .change = "change",
    });
    defer defaults.deinit(std.testing.allocator);

    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/app-policy-app-patch-proposal.json",
        defaults.json_path,
    );
    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/app-policy-app-patch-proposal.txt",
        defaults.text_path,
    );

    const custom = try outputPathsForOptions(std.testing.allocator, .{
        .mode = "local",
        .policy_path = "app-policy.json",
        .summary = "summary",
        .change = "change",
        .out_prefix = ".zig-cache/causal-artifacts/yachdee-platform",
    });
    defer custom.deinit(std.testing.allocator);

    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/yachdee-platform-app-patch-proposal.json",
        custom.json_path,
    );
}

test "approved app policy produces pending non-mutating app patch proposal" {
    var parsed = try parseAppPolicy(std.testing.allocator, approved_policy_json);
    defer parsed.deinit();

    const options = Options{
        .mode = "local",
        .policy_path = "app-policy.json",
        .summary = "wire app requirement",
        .change = "add provider layer and document config binding",
        .source_files = &.{"apps/platform/src/worker.ts"},
        .config_keys = &.{"YACHDEE_ENV"},
    };
    var input = try proposalInputFromPolicy(std.testing.allocator, options, "app-policy.json", parsed.value, null);
    defer input.deinit(std.testing.allocator);

    var reports = try formatAppPatchProposalReports(std.testing.allocator, input);
    defer reports.deinit(std.testing.allocator);

    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"schema\": \"zigeffect.causal.app-patch-proposal.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"approval_status\": \"pending\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"approved\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"applied\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"mutation_authority\": \"none\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"source_files\": [\"apps/platform/src/worker.ts\"]") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"config_keys\": [\"YACHDEE_ENV\"]") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.text, "zigeffect app patch proposal") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.text, "proposal_status: draft") != null);
}

test "app proposal rejects non-approved policy decisions" {
    var parsed = try parseAppPolicy(std.testing.allocator, rejected_policy_json);
    defer parsed.deinit();

    try std.testing.expectError(error.PolicyNotApproved, proposalInputFromPolicy(std.testing.allocator, .{
        .mode = "local",
        .policy_path = "app-policy.json",
        .summary = "summary",
        .change = "change",
        .source_files = &.{"apps/platform/src/worker.ts"},
    }, "app-policy.json", parsed.value, null));
}

test "app proposal requires citations matching low-risk gates" {
    var parsed = try parseAppPolicy(std.testing.allocator, approved_policy_json);
    defer parsed.deinit();

    try std.testing.expectError(error.MissingProposalCitation, proposalInputFromPolicy(std.testing.allocator, .{
        .mode = "local",
        .policy_path = "app-policy.json",
        .summary = "summary",
        .change = "change",
    }, "app-policy.json", parsed.value, null));

    try std.testing.expectError(error.MissingSourceCitation, proposalInputFromPolicy(std.testing.allocator, .{
        .mode = "local",
        .policy_path = "app-policy.json",
        .summary = "summary",
        .change = "change",
        .config_keys = &.{"YACHDEE_ENV"},
    }, "app-policy.json", parsed.value, null));

    try std.testing.expectError(error.MissingConfigCitation, proposalInputFromPolicy(std.testing.allocator, .{
        .mode = "local",
        .policy_path = "app-policy.json",
        .summary = "summary",
        .change = "change",
        .source_files = &.{"apps/platform/src/worker.ts"},
    }, "app-policy.json", parsed.value, null));
}

test "app proposal rejects high-risk gates until human-reviewed flow exists" {
    var parsed = try parseAppPolicy(std.testing.allocator, high_risk_approved_policy_json);
    defer parsed.deinit();

    try std.testing.expectError(error.HighRiskGateRequiresHumanReview, proposalInputFromPolicy(std.testing.allocator, .{
        .mode = "local",
        .policy_path = "app-policy.json",
        .summary = "summary",
        .change = "change",
        .migration_files = &.{"packages/app/migrations/001.sql"},
    }, "app-policy.json", parsed.value, null));
}

test "app proposal rejects high-risk needs-review policy without review artifact" {
    var parsed = try parseAppPolicy(std.testing.allocator, needs_review_policy_json);
    defer parsed.deinit();

    try std.testing.expectError(error.HumanReviewRequired, proposalInputFromPolicy(std.testing.allocator, .{
        .mode = "local",
        .policy_path = "app-policy.json",
        .summary = "summary",
        .change = "change",
        .migration_files = &.{"packages/app/migrations/001.sql"},
    }, "app-policy.json", parsed.value, null));
}

test "app proposal accepts high-risk policy with approved human review" {
    var policy = try parseAppPolicy(std.testing.allocator, needs_review_policy_json);
    defer policy.deinit();
    var review = try parseAppHumanReview(std.testing.allocator, approved_human_review_json);
    defer review.deinit();

    var input = try proposalInputFromPolicy(std.testing.allocator, .{
        .mode = "local",
        .policy_path = "app-policy.json",
        .summary = "reviewed migration",
        .change = "draft reviewed migration plan",
    }, "app-policy.json", policy.value, .{ .path = "app-human-review.json", .record = review.value });
    defer input.deinit(std.testing.allocator);

    var reports = try formatAppPatchProposalReports(std.testing.allocator, input);
    defer reports.deinit(std.testing.allocator);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"human_review\": \"app-human-review.json\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"applied\": false") != null);
}

test "app proposal rejects rejected human review" {
    var policy = try parseAppPolicy(std.testing.allocator, needs_review_policy_json);
    defer policy.deinit();
    var review = try parseAppHumanReview(std.testing.allocator, rejected_human_review_json);
    defer review.deinit();

    try std.testing.expectError(error.HumanReviewNotApproved, proposalInputFromPolicy(std.testing.allocator, .{
        .mode = "local",
        .policy_path = "app-policy.json",
        .summary = "summary",
        .change = "change",
    }, "app-policy.json", policy.value, .{ .path = "app-human-review.json", .record = review.value }));
}

test "app proposal rejects human review for a different policy path" {
    var policy = try parseAppPolicy(std.testing.allocator, needs_review_policy_json);
    defer policy.deinit();
    var review = try parseAppHumanReview(std.testing.allocator, mismatched_human_review_json);
    defer review.deinit();

    try std.testing.expectError(error.HumanReviewPolicyMismatch, proposalInputFromPolicy(std.testing.allocator, .{
        .mode = "local",
        .policy_path = "app-policy.json",
        .summary = "summary",
        .change = "change",
    }, "app-policy.json", policy.value, .{ .path = "app-human-review.json", .record = review.value }));
}
