const std = @import("std");

const app_policy_schema = "zigeffect.causal.app-policy-decision.v1";
const app_human_review_schema = "zigeffect.causal.app-human-review.v1";

const review_guardrails = [_][]const u8{
    "Human review approves proposal drafting only; it does not apply app source, config, migrations, operations, rollback plans, or deployment state.",
    "Mutation authority remains none until a later reviewed application artifact records actual source/external-state changes and post-apply verification.",
    "High-risk citations must name files, runbooks, rollback plans, or command strings only; do not include secret values.",
};

const ReviewDecision = enum {
    approve,
    reject,
    changes_requested,
};

const Options = struct {
    mode: []const u8,
    policy_path: []const u8,
    reviewer: []const u8,
    decision: ReviewDecision,
    reason: []const u8,
    source_files: []const []const u8 = &.{},
    config_keys: []const []const u8 = &.{},
    migration_files: []const []const u8 = &.{},
    runbooks: []const []const u8 = &.{},
    rollback_plans: []const []const u8 = &.{},
    reviewed_verification_commands: []const []const u8 = &.{},
    out_prefix: ?[]const u8 = null,

    fn deinit(self: *Options, allocator: std.mem.Allocator) void {
        if (self.source_files.len > 0) allocator.free(self.source_files);
        if (self.config_keys.len > 0) allocator.free(self.config_keys);
        if (self.migration_files.len > 0) allocator.free(self.migration_files);
        if (self.runbooks.len > 0) allocator.free(self.runbooks);
        if (self.rollback_plans.len > 0) allocator.free(self.rollback_plans);
        if (self.reviewed_verification_commands.len > 0) allocator.free(self.reviewed_verification_commands);
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

const ReviewInput = struct {
    options: Options,
    target: []const u8,
    source: ReviewSource,
    policy_gates: []const []const u8,
    event_ids: []const u64,
    required_verification_commands: []const []const u8,

    fn deinit(self: *ReviewInput, allocator: std.mem.Allocator) void {
        _ = self;
        _ = allocator;
    }
};

const AppHumanReviewReports = struct {
    json: []const u8,
    text: []const u8,

    fn deinit(self: *AppHumanReviewReports, allocator: std.mem.Allocator) void {
        allocator.free(self.json);
        allocator.free(self.text);
    }
};

fn usage() []const u8 {
    return "usage: zig build causal-app-human-review -- local --policy <app-policy-decision-json> --reviewer <actor> --decision <approve|reject|changes-requested> --reason <reason> [--file <path>] [--config <key>] [--migration <path>] [--runbook <path>] [--rollback <path>] [--verified <command>] [--out-prefix <path-prefix>]\n";
}

fn parseOptions(allocator: std.mem.Allocator, args: []const []const u8) !Options {
    if (args.len < 2) return error.MissingMode;
    if (!std.mem.eql(u8, args[1], "local")) return error.UnknownMode;

    var policy_path: ?[]const u8 = null;
    var reviewer: ?[]const u8 = null;
    var decision: ?ReviewDecision = null;
    var reason: ?[]const u8 = null;
    var out_prefix: ?[]const u8 = null;
    var source_files = std.ArrayList([]const u8).empty;
    var config_keys = std.ArrayList([]const u8).empty;
    var migration_files = std.ArrayList([]const u8).empty;
    var runbooks = std.ArrayList([]const u8).empty;
    var rollback_plans = std.ArrayList([]const u8).empty;
    var reviewed_verification_commands = std.ArrayList([]const u8).empty;
    errdefer {
        source_files.deinit(allocator);
        config_keys.deinit(allocator);
        migration_files.deinit(allocator);
        runbooks.deinit(allocator);
        rollback_plans.deinit(allocator);
        reviewed_verification_commands.deinit(allocator);
    }

    var index: usize = 2;
    while (index < args.len) {
        const arg = args[index];
        if (!std.mem.startsWith(u8, arg, "--")) return error.UnknownArgument;
        if (index + 1 >= args.len) return error.MissingFlagValue;
        const value = args[index + 1];
        if (std.mem.eql(u8, arg, "--policy")) {
            policy_path = value;
        } else if (std.mem.eql(u8, arg, "--reviewer")) {
            reviewer = value;
        } else if (std.mem.eql(u8, arg, "--decision")) {
            decision = try parseReviewDecision(value);
        } else if (std.mem.eql(u8, arg, "--reason")) {
            reason = value;
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
        } else if (std.mem.eql(u8, arg, "--verified")) {
            try reviewed_verification_commands.append(allocator, value);
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
        .reviewer = reviewer orelse return error.MissingReviewer,
        .decision = decision orelse return error.MissingDecision,
        .reason = reason orelse return error.MissingReason,
        .source_files = try source_files.toOwnedSlice(allocator),
        .config_keys = try config_keys.toOwnedSlice(allocator),
        .migration_files = try migration_files.toOwnedSlice(allocator),
        .runbooks = try runbooks.toOwnedSlice(allocator),
        .rollback_plans = try rollback_plans.toOwnedSlice(allocator),
        .reviewed_verification_commands = try reviewed_verification_commands.toOwnedSlice(allocator),
        .out_prefix = out_prefix,
    };
}

fn parseReviewDecision(value: []const u8) !ReviewDecision {
    if (std.mem.eql(u8, value, "approve")) return .approve;
    if (std.mem.eql(u8, value, "reject")) return .reject;
    if (std.mem.eql(u8, value, "changes-requested")) return .changes_requested;
    return error.UnknownDecision;
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
        .json_path = try std.fmt.allocPrint(allocator, "{s}-app-human-review.json", .{prefix}),
        .text_path = try std.fmt.allocPrint(allocator, "{s}-app-human-review.txt", .{prefix}),
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

fn reviewInputFromPolicy(
    allocator: std.mem.Allocator,
    options: Options,
    policy_path: []const u8,
    policy: AppPolicyRecord,
) !ReviewInput {
    _ = allocator;
    if (!std.mem.eql(u8, options.mode, "local")) return error.UnknownMode;
    if (options.reviewer.len == 0) return error.MissingReviewer;
    if (options.reason.len == 0) return error.MissingReason;
    if (!std.mem.eql(u8, policy.decision, "needs-human-review") or
        !std.mem.eql(u8, policy.approval_status, "needs-human-review"))
    {
        return error.PolicyDoesNotNeedHumanReview;
    }
    if (policy.applied) return error.PolicyAlreadyApplied;
    if (!std.mem.eql(u8, policy.mutation_authority, "none")) return error.PolicyMutationAuthorityNotNone;

    var saw_high_risk = false;
    for (policy.policy_gates) |gate| {
        if (std.mem.eql(u8, gate, "migration-required")) {
            saw_high_risk = true;
            if (options.migration_files.len == 0) return error.MissingMigrationCitation;
        } else if (std.mem.eql(u8, gate, "operational-human-required")) {
            saw_high_risk = true;
            if (options.runbooks.len == 0) return error.MissingRunbookCitation;
        } else if (std.mem.eql(u8, gate, "rollback-required")) {
            saw_high_risk = true;
            if (options.rollback_plans.len == 0) return error.MissingRollbackCitation;
        } else if (std.mem.eql(u8, gate, "source-only") or std.mem.eql(u8, gate, "config-only")) {
            continue;
        } else {
            return error.UnknownPolicyGate;
        }
    }
    if (!saw_high_risk) return error.PolicyDoesNotNeedHumanReview;

    return .{
        .options = options,
        .target = policy.target,
        .source = .{
            .policy = policy_path,
            .app_remediation_audit = policy.source.app_remediation_audit,
            .app_artifact = policy.source.app_artifact,
        },
        .policy_gates = policy.policy_gates,
        .event_ids = policy.event_ids,
        .required_verification_commands = policy.required_verification_commands,
    };
}

fn formatAppHumanReviewReports(allocator: std.mem.Allocator, input: ReviewInput) !AppHumanReviewReports {
    const json = try formatAppHumanReviewJson(allocator, input);
    errdefer allocator.free(json);
    const text = try formatAppHumanReviewText(allocator, input);
    return .{ .json = json, .text = text };
}

fn formatAppHumanReviewJson(allocator: std.mem.Allocator, input: ReviewInput) ![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "{\n");
    try output.appendSlice(allocator, "  \"schema\": ");
    try appendJsonString(allocator, &output, app_human_review_schema);
    try output.appendSlice(allocator, ",\n  \"schema_version\": 1,\n");
    try output.appendSlice(allocator, "  \"mode\": ");
    try appendJsonString(allocator, &output, input.options.mode);
    try output.appendSlice(allocator, ",\n  \"target\": ");
    try appendJsonString(allocator, &output, input.target);
    try output.appendSlice(allocator, ",\n  \"review_status\": ");
    try appendJsonString(allocator, &output, reviewStatusText(input.options.decision));
    try output.appendSlice(allocator, ",\n  \"approval_status\": ");
    try appendJsonString(allocator, &output, reviewStatusText(input.options.decision));
    try output.print(allocator, ",\n  \"approved\": {},\n", .{reviewApproved(input.options.decision)});
    try output.appendSlice(allocator, "  \"applied\": false,\n  \"mutation_authority\": \"none\",\n");
    try output.appendSlice(allocator, "  \"reviewed_by\": ");
    try appendJsonString(allocator, &output, input.options.reviewer);
    try output.appendSlice(allocator, ",\n  \"reason\": ");
    try appendJsonString(allocator, &output, input.options.reason);
    try output.appendSlice(allocator, ",\n  \"source\": {\n    \"policy\": ");
    try appendJsonString(allocator, &output, input.source.policy);
    try output.appendSlice(allocator, ",\n    \"app_remediation_audit\": ");
    try appendJsonString(allocator, &output, input.source.app_remediation_audit);
    try output.appendSlice(allocator, ",\n    \"app_artifact\": ");
    try appendJsonString(allocator, &output, input.source.app_artifact);
    try output.appendSlice(allocator, "\n  },\n  \"policy_gates\": ");
    try appendStringArray(allocator, &output, input.policy_gates);
    try output.appendSlice(allocator, ",\n  \"citations\": {\n");
    try output.appendSlice(allocator, "    \"source_files\": ");
    try appendStringArray(allocator, &output, input.options.source_files);
    try output.appendSlice(allocator, ",\n    \"config_keys\": ");
    try appendStringArray(allocator, &output, input.options.config_keys);
    try output.appendSlice(allocator, ",\n    \"migration_files\": ");
    try appendStringArray(allocator, &output, input.options.migration_files);
    try output.appendSlice(allocator, ",\n    \"runbooks\": ");
    try appendStringArray(allocator, &output, input.options.runbooks);
    try output.appendSlice(allocator, ",\n    \"rollback_plans\": ");
    try appendStringArray(allocator, &output, input.options.rollback_plans);
    try output.appendSlice(allocator, "\n  },\n  \"event_ids\": ");
    try appendU64Array(allocator, &output, input.event_ids);
    try output.appendSlice(allocator, ",\n  \"required_verification_commands\": ");
    try appendStringArray(allocator, &output, input.required_verification_commands);
    try output.appendSlice(allocator, ",\n  \"reviewed_verification_commands\": ");
    try appendStringArray(allocator, &output, input.options.reviewed_verification_commands);
    try output.appendSlice(allocator, ",\n  \"review_guardrails\": ");
    try appendStringArray(allocator, &output, &review_guardrails);
    try output.appendSlice(allocator, "\n}\n");

    return output.toOwnedSlice(allocator);
}

fn formatAppHumanReviewText(allocator: std.mem.Allocator, input: ReviewInput) ![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "zigeffect app human review\n");
    try output.print(allocator, "schema: {s}\n", .{app_human_review_schema});
    try output.print(allocator, "target: {s}\n", .{input.target});
    try output.print(allocator, "review_status: {s}\n", .{reviewStatusText(input.options.decision)});
    try output.print(allocator, "approval_status: {s}\n", .{reviewStatusText(input.options.decision)});
    try output.print(allocator, "approved: {}\n", .{reviewApproved(input.options.decision)});
    try output.appendSlice(allocator, "applied: false\n");
    try output.appendSlice(allocator, "mutation_authority: none\n");
    try output.print(allocator, "reviewed_by: {s}\n", .{input.options.reviewer});
    try output.print(allocator, "reason: {s}\n\n", .{input.options.reason});

    try output.appendSlice(allocator, "source:\n");
    try output.print(allocator, "- policy: {s}\n", .{input.source.policy});
    try output.print(allocator, "- app remediation audit: {s}\n", .{input.source.app_remediation_audit});
    try output.print(allocator, "- app artifact: {s}\n\n", .{input.source.app_artifact});

    try output.appendSlice(allocator, "policy gates:\n");
    for (input.policy_gates) |gate| try output.print(allocator, "- {s}\n", .{gate});
    try output.append(allocator, '\n');

    try appendTextList(allocator, &output, "source files", input.options.source_files);
    try appendTextList(allocator, &output, "config keys", input.options.config_keys);
    try appendTextList(allocator, &output, "migration files", input.options.migration_files);
    try appendTextList(allocator, &output, "runbooks", input.options.runbooks);
    try appendTextList(allocator, &output, "rollback plans", input.options.rollback_plans);
    try appendU64TextList(allocator, &output, "event ids", input.event_ids);
    try appendTextList(allocator, &output, "required verification commands", input.required_verification_commands);
    try appendTextList(allocator, &output, "reviewed verification commands", input.options.reviewed_verification_commands);
    try appendTextList(allocator, &output, "review guardrails", &review_guardrails);

    return output.toOwnedSlice(allocator);
}

fn reviewStatusText(decision: ReviewDecision) []const u8 {
    return switch (decision) {
        .approve => "approved",
        .reject => "rejected",
        .changes_requested => "changes-requested",
    };
}

fn reviewApproved(decision: ReviewDecision) bool {
    return decision == .approve;
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

fn appendU64TextList(allocator: std.mem.Allocator, output: *std.ArrayList(u8), label: []const u8, values: []const u64) !void {
    try output.print(allocator, "{s}:\n", .{label});
    if (values.len == 0) {
        try output.appendSlice(allocator, "- none\n\n");
        return;
    }
    for (values) |value| try output.print(allocator, "- {d}\n", .{value});
    try output.append(allocator, '\n');
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

    var input = try reviewInputFromPolicy(allocator, options, options.policy_path, parsed.value);
    defer input.deinit(allocator);

    var reports = try formatAppHumanReviewReports(allocator, input);
    defer reports.deinit(allocator);

    try writeArtifact(init.io, paths.json_path, reports.json);
    try writeArtifact(init.io, paths.text_path, reports.text);
    std.debug.print("{s}", .{reports.text});
}

fn failUsage(err: anyerror) noreturn {
    std.debug.print("causal-app-human-review error: {s}\n{s}", .{ @errorName(err), usage() });
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
        error.PolicyDoesNotNeedHumanReview,
        error.PolicyAlreadyApplied,
        error.PolicyMutationAuthorityNotNone,
        error.MissingMigrationCitation,
        error.MissingRunbookCitation,
        error.MissingRollbackCitation,
        error.UnknownPolicyGate,
        error.MissingReviewer,
        error.MissingReason,
        => failUsage(err),
        else => return err,
    };
}

const needs_review_policy_json =
    \\{
    \\  "schema": "zigeffect.causal.app-policy-decision.v1",
    \\  "schema_version": 1,
    \\  "mode": "local",
    \\  "target": "yachdee-platform",
    \\  "decision": "needs-human-review",
    \\  "approval_status": "needs-human-review",
    \\  "evaluated_by": "local-app-policy-engine",
    \\  "policy": "local-app-remediation-policy-v1",
    \\  "reason": "app audit contains high-risk gates that require human review",
    \\  "reason_codes": ["app-high-risk-gate-review-required"],
    \\  "mutation_authority": "none",
    \\  "applied": false,
    \\  "source": {
    \\    "app_remediation_audit": ".zig-cache/causal-artifacts/app-audit.json",
    \\    "app_artifact": ".zig-cache/causal-artifacts/app.json"
    \\  },
    \\  "policy_gates": ["migration-required", "operational-human-required", "rollback-required"],
    \\  "gate_results": [],
    \\  "event_ids": [4],
    \\  "required_verification_commands": ["zig build causal-query -- --file .zig-cache/causal-artifacts/app.json cause 4"],
    \\  "guardrails": ["Policy approval is advisory and does not apply app source, config, migrations, operations, or rollback actions."]
    \\}
;

const approved_policy_json =
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
    \\  "policy_gates": ["source-only"],
    \\  "event_ids": [2],
    \\  "required_verification_commands": [],
    \\  "guardrails": []
    \\}
;

const applied_needs_review_policy_json =
    \\{
    \\  "schema": "zigeffect.causal.app-policy-decision.v1",
    \\  "schema_version": 1,
    \\  "mode": "local",
    \\  "target": "yachdee-platform",
    \\  "decision": "needs-human-review",
    \\  "approval_status": "needs-human-review",
    \\  "mutation_authority": "none",
    \\  "applied": true,
    \\  "source": {"app_remediation_audit": "app-audit.json", "app_artifact": "app.json"},
    \\  "policy_gates": ["migration-required"],
    \\  "event_ids": [4],
    \\  "required_verification_commands": [],
    \\  "guardrails": []
    \\}
;

const mutating_needs_review_policy_json =
    \\{
    \\  "schema": "zigeffect.causal.app-policy-decision.v1",
    \\  "schema_version": 1,
    \\  "mode": "local",
    \\  "target": "yachdee-platform",
    \\  "decision": "needs-human-review",
    \\  "approval_status": "needs-human-review",
    \\  "mutation_authority": "app-source",
    \\  "applied": false,
    \\  "source": {"app_remediation_audit": "app-audit.json", "app_artifact": "app.json"},
    \\  "policy_gates": ["migration-required"],
    \\  "event_ids": [4],
    \\  "required_verification_commands": [],
    \\  "guardrails": []
    \\}
;

fn validHumanReviewOptions() Options {
    return .{
        .mode = "local",
        .policy_path = "app-policy.json",
        .reviewer = "local-reviewer",
        .decision = .approve,
        .reason = "reviewed evidence",
        .migration_files = &.{"packages/app/migrations/001.sql"},
        .runbooks = &.{"docs/runbooks/migration.md"},
        .rollback_plans = &.{"docs/runbooks/rollback.md"},
    };
}

test "usage text names human review inputs" {
    try std.testing.expect(std.mem.indexOf(u8, usage(), "causal-app-human-review") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage(), "--policy <app-policy-decision-json>") != null);
    try std.testing.expectEqualStrings("zigeffect.causal.app-policy-decision.v1", app_policy_schema);
    try std.testing.expectEqualStrings("zigeffect.causal.app-human-review.v1", app_human_review_schema);
}

test "human review options parse repeated citations and verified commands" {
    const args = [_][]const u8{
        "zigeffect-causal-app-human-review",
        "local",
        "--policy",
        "app-policy.json",
        "--reviewer",
        "local-reviewer",
        "--decision",
        "approve",
        "--reason",
        "reviewed migration and rollback evidence",
        "--migration",
        "packages/app/migrations/001.sql",
        "--runbook",
        "docs/runbooks/migration.md",
        "--rollback",
        "docs/runbooks/rollback.md",
        "--verified",
        "zig build causal-query -- --file app.json cause 4",
    };

    var options = try parseOptions(std.testing.allocator, &args);
    defer options.deinit(std.testing.allocator);

    try std.testing.expectEqualStrings("local", options.mode);
    try std.testing.expectEqualStrings("app-policy.json", options.policy_path);
    try std.testing.expectEqualStrings("local-reviewer", options.reviewer);
    try std.testing.expectEqual(ReviewDecision.approve, options.decision);
    try std.testing.expectEqual(@as(usize, 1), options.migration_files.len);
    try std.testing.expectEqual(@as(usize, 1), options.runbooks.len);
    try std.testing.expectEqual(@as(usize, 1), options.rollback_plans.len);
    try std.testing.expectEqual(@as(usize, 1), options.reviewed_verification_commands.len);
}

test "human review output paths derive from policy path and out prefix" {
    const defaults = try outputPathsForOptions(std.testing.allocator, .{
        .mode = "local",
        .policy_path = ".zig-cache/causal-artifacts/app-policy.json",
        .reviewer = "reviewer",
        .decision = .approve,
        .reason = "reason",
    });
    defer defaults.deinit(std.testing.allocator);

    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/app-policy-app-human-review.json",
        defaults.json_path,
    );
    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/app-policy-app-human-review.txt",
        defaults.text_path,
    );

    const custom = try outputPathsForOptions(std.testing.allocator, .{
        .mode = "local",
        .policy_path = "app-policy.json",
        .reviewer = "reviewer",
        .decision = .approve,
        .reason = "reason",
        .out_prefix = ".zig-cache/causal-artifacts/yachdee-platform",
    });
    defer custom.deinit(std.testing.allocator);

    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/yachdee-platform-app-human-review.json",
        custom.json_path,
    );
}

test "needs human review policy produces approved non-mutating review artifact" {
    var parsed = try parseAppPolicy(std.testing.allocator, needs_review_policy_json);
    defer parsed.deinit();

    const options = Options{
        .mode = "local",
        .policy_path = "app-policy.json",
        .reviewer = "local-reviewer",
        .decision = .approve,
        .reason = "reviewed migration and rollback evidence",
        .migration_files = &.{"packages/app/migrations/001.sql"},
        .runbooks = &.{"docs/runbooks/migration.md"},
        .rollback_plans = &.{"docs/runbooks/rollback.md"},
        .reviewed_verification_commands = &.{"zig build causal-query -- --file app.json cause 4"},
    };

    var input = try reviewInputFromPolicy(std.testing.allocator, options, "app-policy.json", parsed.value);
    defer input.deinit(std.testing.allocator);

    var reports = try formatAppHumanReviewReports(std.testing.allocator, input);
    defer reports.deinit(std.testing.allocator);

    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"schema\": \"zigeffect.causal.app-human-review.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"review_status\": \"approved\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"approved\": true") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"applied\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"mutation_authority\": \"none\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.text, "zigeffect app human review") != null);
}

test "human review rejects policies that do not need review" {
    var parsed = try parseAppPolicy(std.testing.allocator, approved_policy_json);
    defer parsed.deinit();

    try std.testing.expectError(error.PolicyDoesNotNeedHumanReview, reviewInputFromPolicy(std.testing.allocator, validHumanReviewOptions(), "app-policy.json", parsed.value));
}

test "human review requires high risk citations" {
    var parsed = try parseAppPolicy(std.testing.allocator, needs_review_policy_json);
    defer parsed.deinit();

    try std.testing.expectError(error.MissingMigrationCitation, reviewInputFromPolicy(std.testing.allocator, .{
        .mode = "local",
        .policy_path = "app-policy.json",
        .reviewer = "local-reviewer",
        .decision = .approve,
        .reason = "reviewed evidence",
        .runbooks = &.{"docs/runbooks/migration.md"},
        .rollback_plans = &.{"docs/runbooks/rollback.md"},
    }, "app-policy.json", parsed.value));

    try std.testing.expectError(error.MissingRunbookCitation, reviewInputFromPolicy(std.testing.allocator, .{
        .mode = "local",
        .policy_path = "app-policy.json",
        .reviewer = "local-reviewer",
        .decision = .approve,
        .reason = "reviewed evidence",
        .migration_files = &.{"packages/app/migrations/001.sql"},
        .rollback_plans = &.{"docs/runbooks/rollback.md"},
    }, "app-policy.json", parsed.value));

    try std.testing.expectError(error.MissingRollbackCitation, reviewInputFromPolicy(std.testing.allocator, .{
        .mode = "local",
        .policy_path = "app-policy.json",
        .reviewer = "local-reviewer",
        .decision = .approve,
        .reason = "reviewed evidence",
        .migration_files = &.{"packages/app/migrations/001.sql"},
        .runbooks = &.{"docs/runbooks/migration.md"},
    }, "app-policy.json", parsed.value));
}

test "human review rejects applied or mutating policies" {
    var applied = try parseAppPolicy(std.testing.allocator, applied_needs_review_policy_json);
    defer applied.deinit();
    try std.testing.expectError(error.PolicyAlreadyApplied, reviewInputFromPolicy(std.testing.allocator, validHumanReviewOptions(), "app-policy.json", applied.value));

    var mutating = try parseAppPolicy(std.testing.allocator, mutating_needs_review_policy_json);
    defer mutating.deinit();
    try std.testing.expectError(error.PolicyMutationAuthorityNotNone, reviewInputFromPolicy(std.testing.allocator, validHumanReviewOptions(), "app-policy.json", mutating.value));
}

test "human review formats rejected and changes requested outcomes without approval" {
    var parsed = try parseAppPolicy(std.testing.allocator, needs_review_policy_json);
    defer parsed.deinit();

    var rejected = try reviewInputFromPolicy(std.testing.allocator, .{
        .mode = "local",
        .policy_path = "app-policy.json",
        .reviewer = "local-reviewer",
        .decision = .reject,
        .reason = "evidence incomplete",
        .migration_files = &.{"packages/app/migrations/001.sql"},
        .runbooks = &.{"docs/runbooks/migration.md"},
        .rollback_plans = &.{"docs/runbooks/rollback.md"},
    }, "app-policy.json", parsed.value);
    defer rejected.deinit(std.testing.allocator);

    var rejected_reports = try formatAppHumanReviewReports(std.testing.allocator, rejected);
    defer rejected_reports.deinit(std.testing.allocator);
    try std.testing.expect(std.mem.indexOf(u8, rejected_reports.json, "\"review_status\": \"rejected\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, rejected_reports.json, "\"approved\": false") != null);

    var changes = try reviewInputFromPolicy(std.testing.allocator, .{
        .mode = "local",
        .policy_path = "app-policy.json",
        .reviewer = "local-reviewer",
        .decision = .changes_requested,
        .reason = "add rollback details",
        .migration_files = &.{"packages/app/migrations/001.sql"},
        .runbooks = &.{"docs/runbooks/migration.md"},
        .rollback_plans = &.{"docs/runbooks/rollback.md"},
    }, "app-policy.json", parsed.value);
    defer changes.deinit(std.testing.allocator);

    var changes_reports = try formatAppHumanReviewReports(std.testing.allocator, changes);
    defer changes_reports.deinit(std.testing.allocator);
    try std.testing.expect(std.mem.indexOf(u8, changes_reports.json, "\"review_status\": \"changes-requested\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, changes_reports.json, "\"approved\": false") != null);
}
