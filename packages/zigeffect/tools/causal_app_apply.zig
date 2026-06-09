const std = @import("std");

const app_application_readiness_schema = "zigeffect.causal.app-application-readiness.v1";
const app_application_schema = "zigeffect.causal.app-application.v1";
const readiness_suffix = "-app-application-readiness.json";
const application_suffix = "-app-application";

const Mode = enum {
    plan,
    record_applied,
};

const ApplicationStatus = enum {
    planned,
    applied,
    blocked,
};

const CheckStatus = enum {
    pass,
    fail,
    skipped,
};

const ChangeEvidence = struct {
    source_changes: []const []const u8 = &.{},
    config_changes: []const []const u8 = &.{},
    migration_changes: []const []const u8 = &.{},
    operation_changes: []const []const u8 = &.{},
    rollback_changes: []const []const u8 = &.{},

    fn deinit(self: ChangeEvidence, allocator: std.mem.Allocator) void {
        freeSliceOnly(allocator, self.source_changes);
        freeSliceOnly(allocator, self.config_changes);
        freeSliceOnly(allocator, self.migration_changes);
        freeSliceOnly(allocator, self.operation_changes);
        freeSliceOnly(allocator, self.rollback_changes);
    }
};

const Options = struct {
    readiness_path: []const u8,
    mode: Mode,
    applied_by: []const u8 = "local-reviewer",
    policy: []const u8 = "manual-app-application",
    reason: []const u8,
    verified_commands: []const []const u8 = &.{},
    change_evidence: ChangeEvidence = .{},
    before_evidence: []const []const u8 = &.{},
    after_evidence: []const []const u8 = &.{},

    fn deinit(self: Options, allocator: std.mem.Allocator) void {
        freeSliceOnly(allocator, self.verified_commands);
        self.change_evidence.deinit(allocator);
        freeSliceOnly(allocator, self.before_evidence);
        freeSliceOnly(allocator, self.after_evidence);
    }
};

const ApplicationPaths = struct {
    json: []const u8,
    text: []const u8,

    fn deinit(self: ApplicationPaths, allocator: std.mem.Allocator) void {
        allocator.free(self.json);
        allocator.free(self.text);
    }
};

const ReadinessSource = struct {
    proposal: []const u8 = "",
    policy: []const u8 = "",
    human_review: ?[]const u8 = null,
    app_remediation_audit: []const u8 = "",
    app_artifact: []const u8 = "",
};

const ReadinessCitations = struct {
    source_files: []const []const u8 = &.{},
    config_keys: []const []const u8 = &.{},
    migration_files: []const []const u8 = &.{},
    runbooks: []const []const u8 = &.{},
    rollback_plans: []const []const u8 = &.{},
};

const ReadinessCheck = struct {
    name: []const u8,
    status: []const u8,
    detail: []const u8,
};

const ReadinessReport = struct {
    schema: []const u8,
    schema_version: u32,
    mode: []const u8,
    source_proposal: []const u8,
    decision: []const u8,
    readiness_status: []const u8,
    ready_for_application: bool,
    reviewed_by: []const u8,
    policy: []const u8,
    reason: []const u8,
    applied: bool,
    mutation_authority: []const u8,
    target: []const u8,
    summary: []const u8,
    change: []const u8,
    source: ReadinessSource,
    policy_gates: []const []const u8 = &.{},
    citations: ReadinessCitations = .{},
    event_ids: []const u64 = &.{},
    checks: []const ReadinessCheck = &.{},
    required_verification_commands: []const []const u8 = &.{},
    verified_commands: []const []const u8 = &.{},
    application_steps: []const []const u8 = &.{},
    readiness_guardrails: []const []const u8 = &.{},
};

const ApplicationCheck = struct {
    name: []const u8,
    status: CheckStatus,
    detail: []const u8,
};

const ApplicationInput = struct {
    source_readiness_path: []const u8,
    readiness_json: []const u8,
    mode: Mode,
    applied_by: []const u8,
    policy: []const u8,
    reason: []const u8,
    verified_commands: []const []const u8,
    change_evidence: ChangeEvidence,
    before_evidence: []const []const u8,
    after_evidence: []const []const u8,
};

const ApplicationResult = struct {
    status: ApplicationStatus,
    applied: bool,
    mutation_authority: []const u8,
    checks: []const ApplicationCheck,
    required_verification_commands: []const []const u8,

    fn deinit(self: ApplicationResult, allocator: std.mem.Allocator) void {
        if (self.checks.len > 0) allocator.free(self.checks);
        freeOwnedStringSlice(allocator, self.required_verification_commands);
    }
};

const ApplicationReports = struct {
    json: []const u8,
    text: []const u8,

    fn deinit(self: ApplicationReports, allocator: std.mem.Allocator) void {
        allocator.free(self.json);
        allocator.free(self.text);
    }
};

fn usage() []const u8 {
    return "usage: zig build causal-app-apply -- --from-readiness <app-application-readiness.json> plan|record-applied --reason <reason> [--by <actor>] [--policy <policy>] [--verified-command <command>] [--source-change <path>] [--config-change <key-or-binding>] [--migration-change <path>] [--operation-change <runbook-or-operation>] [--rollback-change <path>] [--before <artifact-or-evidence>] [--after <artifact-or-evidence>]\n";
}

fn parseOptions(allocator: std.mem.Allocator, args: []const []const u8) !Options {
    if (args.len < 3) return error.MissingReadinessPath;
    if (!std.mem.eql(u8, args[1], "--from-readiness")) return error.UnknownFlag;
    if (!std.mem.endsWith(u8, args[2], readiness_suffix)) return error.InvalidReadinessPath;
    if (args.len < 4) return error.MissingMode;

    const mode = try parseMode(args[3]);
    var applied_by: []const u8 = "local-reviewer";
    var policy: []const u8 = "manual-app-application";
    var reason: ?[]const u8 = null;
    var verified_commands = std.ArrayList([]const u8).empty;
    var source_changes = std.ArrayList([]const u8).empty;
    var config_changes = std.ArrayList([]const u8).empty;
    var migration_changes = std.ArrayList([]const u8).empty;
    var operation_changes = std.ArrayList([]const u8).empty;
    var rollback_changes = std.ArrayList([]const u8).empty;
    var before_evidence = std.ArrayList([]const u8).empty;
    var after_evidence = std.ArrayList([]const u8).empty;
    errdefer verified_commands.deinit(allocator);
    errdefer source_changes.deinit(allocator);
    errdefer config_changes.deinit(allocator);
    errdefer migration_changes.deinit(allocator);
    errdefer operation_changes.deinit(allocator);
    errdefer rollback_changes.deinit(allocator);
    errdefer before_evidence.deinit(allocator);
    errdefer after_evidence.deinit(allocator);

    var index: usize = 4;
    while (index < args.len) {
        if (index + 1 >= args.len) return error.MissingFlagValue;
        const flag = args[index];
        const value = args[index + 1];
        if (!std.mem.startsWith(u8, flag, "--")) return error.UnknownArgument;

        if (std.mem.eql(u8, flag, "--by")) {
            applied_by = value;
        } else if (std.mem.eql(u8, flag, "--policy")) {
            policy = value;
        } else if (std.mem.eql(u8, flag, "--reason")) {
            reason = value;
        } else if (std.mem.eql(u8, flag, "--verified-command")) {
            try verified_commands.append(allocator, value);
        } else if (std.mem.eql(u8, flag, "--source-change")) {
            try source_changes.append(allocator, value);
        } else if (std.mem.eql(u8, flag, "--config-change")) {
            try config_changes.append(allocator, value);
        } else if (std.mem.eql(u8, flag, "--migration-change")) {
            try migration_changes.append(allocator, value);
        } else if (std.mem.eql(u8, flag, "--operation-change")) {
            try operation_changes.append(allocator, value);
        } else if (std.mem.eql(u8, flag, "--rollback-change")) {
            try rollback_changes.append(allocator, value);
        } else if (std.mem.eql(u8, flag, "--before")) {
            try before_evidence.append(allocator, value);
        } else if (std.mem.eql(u8, flag, "--after")) {
            try after_evidence.append(allocator, value);
        } else {
            return error.UnknownFlag;
        }
        index += 2;
    }

    const final_reason = reason orelse return error.MissingReason;
    if (final_reason.len == 0) return error.MissingReason;

    return .{
        .readiness_path = args[2],
        .mode = mode,
        .applied_by = applied_by,
        .policy = policy,
        .reason = final_reason,
        .verified_commands = try verified_commands.toOwnedSlice(allocator),
        .change_evidence = .{
            .source_changes = try source_changes.toOwnedSlice(allocator),
            .config_changes = try config_changes.toOwnedSlice(allocator),
            .migration_changes = try migration_changes.toOwnedSlice(allocator),
            .operation_changes = try operation_changes.toOwnedSlice(allocator),
            .rollback_changes = try rollback_changes.toOwnedSlice(allocator),
        },
        .before_evidence = try before_evidence.toOwnedSlice(allocator),
        .after_evidence = try after_evidence.toOwnedSlice(allocator),
    };
}

fn parseMode(value: []const u8) !Mode {
    if (std.mem.eql(u8, value, "plan")) return .plan;
    if (std.mem.eql(u8, value, "record-applied")) return .record_applied;
    return error.UnknownMode;
}

fn modeText(mode: Mode) []const u8 {
    return switch (mode) {
        .plan => "plan",
        .record_applied => "record-applied",
    };
}

fn applicationPathsFromReadiness(allocator: std.mem.Allocator, readiness_path: []const u8) !ApplicationPaths {
    if (!std.mem.endsWith(u8, readiness_path, readiness_suffix)) return error.InvalidReadinessPath;
    const prefix = readiness_path[0 .. readiness_path.len - readiness_suffix.len];

    const json = try std.fmt.allocPrint(allocator, "{s}{s}.json", .{ prefix, application_suffix });
    errdefer allocator.free(json);
    const text = try std.fmt.allocPrint(allocator, "{s}{s}.txt", .{ prefix, application_suffix });
    return .{ .json = json, .text = text };
}

fn validateReadiness(report: ReadinessReport) !void {
    if (!std.mem.eql(u8, report.schema, app_application_readiness_schema)) return error.UnsupportedReadinessSchema;
    if (report.schema_version != 1) return error.UnsupportedReadinessSchema;
    if (!std.mem.eql(u8, report.mode, "local")) return error.UnsupportedReadinessSchema;
    if (report.target.len == 0) return error.MissingTarget;
    if (report.summary.len == 0) return error.MissingSummary;
    if (report.change.len == 0) return error.MissingChange;
    if (report.reason.len == 0) return error.MissingReadinessReason;
    if (report.applied) return error.ReadinessAlreadyApplied;
    if (!std.mem.eql(u8, report.mutation_authority, "none")) return error.ReadinessMutationAuthorityNotNone;
    if (!std.mem.endsWith(u8, report.source_proposal, "-app-patch-proposal.json")) return error.InvalidProposalPath;
    if (!std.mem.eql(u8, report.readiness_status, "ready") and !std.mem.eql(u8, report.readiness_status, "blocked")) {
        return error.UnknownReadinessStatus;
    }
    if (report.ready_for_application != std.mem.eql(u8, report.readiness_status, "ready")) {
        return error.InconsistentReadinessStatus;
    }
}

fn evaluateApplication(allocator: std.mem.Allocator, input: ApplicationInput) !ApplicationResult {
    if (input.reason.len == 0) return error.MissingReason;

    var parsed = try std.json.parseFromSlice(ReadinessReport, allocator, input.readiness_json, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();
    try validateReadiness(parsed.value);

    var checks = std.ArrayList(ApplicationCheck).empty;
    errdefer checks.deinit(allocator);

    try appendCheck(allocator, &checks, "readiness-schema", .pass, "app application readiness schema is supported");

    const required_commands = try duplicateStringSlice(allocator, parsed.value.required_verification_commands);
    errdefer freeOwnedStringSlice(allocator, required_commands);

    const readiness_ready = std.mem.eql(u8, parsed.value.readiness_status, "ready") and parsed.value.ready_for_application;
    const approved = std.mem.eql(u8, parsed.value.decision, "approve");

    try appendCheck(
        allocator,
        &checks,
        "readiness-ready",
        if (readiness_ready) .pass else .fail,
        "readiness is ready for app application",
    );
    try appendCheck(
        allocator,
        &checks,
        "decision-approved",
        if (approved) .pass else .fail,
        "readiness decision approved application",
    );

    if (input.mode == .plan) {
        try appendCheck(allocator, &checks, "change-evidence-present", .skipped, "plan mode does not claim application change evidence");
        try appendCheck(allocator, &checks, "before-after-evidence-present", .skipped, "plan mode does not claim before or after evidence");
        try appendCheck(allocator, &checks, "post-verification-recorded", .skipped, "plan mode does not claim post-application verification");
        const check_slice = try checks.toOwnedSlice(allocator);
        errdefer allocator.free(check_slice);
        const planned = readiness_ready and approved;
        return .{
            .status = if (planned) .planned else .blocked,
            .applied = false,
            .mutation_authority = "none",
            .checks = check_slice,
            .required_verification_commands = required_commands,
        };
    }

    try appendCheck(
        allocator,
        &checks,
        "change-evidence-present",
        if (changeEvidenceSatisfiesGates(parsed.value.policy_gates, input.change_evidence)) .pass else .fail,
        "caller recorded evidence for every policy-gate change category",
    );
    try appendCheck(
        allocator,
        &checks,
        "before-after-evidence-present",
        if (input.before_evidence.len > 0 and input.after_evidence.len > 0) .pass else .fail,
        "caller recorded before and after evidence",
    );
    try appendCheck(
        allocator,
        &checks,
        "post-verification-recorded",
        if (requiredCommandsSatisfied(input.verified_commands, parsed.value.required_verification_commands)) .pass else .fail,
        "caller recorded required post-application verification commands",
    );

    const check_slice = try checks.toOwnedSlice(allocator);
    errdefer allocator.free(check_slice);
    const applied = allChecksPassed(check_slice);
    return .{
        .status = if (applied) .applied else .blocked,
        .applied = applied,
        .mutation_authority = if (applied) "record-only" else "none",
        .checks = check_slice,
        .required_verification_commands = required_commands,
    };
}

fn appendCheck(
    allocator: std.mem.Allocator,
    checks: *std.ArrayList(ApplicationCheck),
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

fn changeEvidenceSatisfiesGates(gates: []const []const u8, evidence: ChangeEvidence) bool {
    for (gates) |gate| {
        if (std.mem.eql(u8, gate, "source-only")) {
            if (evidence.source_changes.len == 0) return false;
        } else if (std.mem.eql(u8, gate, "config-only")) {
            if (evidence.config_changes.len == 0) return false;
        } else if (std.mem.eql(u8, gate, "migration-required")) {
            if (evidence.migration_changes.len == 0) return false;
        } else if (std.mem.eql(u8, gate, "operational-human-required")) {
            if (evidence.operation_changes.len == 0) return false;
        } else if (std.mem.eql(u8, gate, "rollback-required")) {
            if (evidence.rollback_changes.len == 0) return false;
        } else {
            return false;
        }
    }
    return true;
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

fn allChecksPassed(checks: []const ApplicationCheck) bool {
    for (checks) |check| {
        if (check.status != .pass) return false;
    }
    return true;
}

fn checkPassed(checks: []const ApplicationCheck, name: []const u8) bool {
    for (checks) |check| {
        if (std.mem.eql(u8, check.name, name)) return check.status == .pass;
    }
    return false;
}

fn checkFailed(checks: []const ApplicationCheck, name: []const u8) bool {
    for (checks) |check| {
        if (std.mem.eql(u8, check.name, name)) return check.status == .fail;
    }
    return false;
}

fn checkSkipped(checks: []const ApplicationCheck, name: []const u8) bool {
    for (checks) |check| {
        if (std.mem.eql(u8, check.name, name)) return check.status == .skipped;
    }
    return false;
}

fn formatApplicationReports(allocator: std.mem.Allocator, input: ApplicationInput) !ApplicationReports {
    var parsed = try std.json.parseFromSlice(ReadinessReport, allocator, input.readiness_json, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();
    try validateReadiness(parsed.value);

    const result = try evaluateApplication(allocator, input);
    defer result.deinit(allocator);

    const json = try formatApplicationJson(allocator, input, parsed.value, result);
    errdefer allocator.free(json);
    const text = try formatApplicationText(allocator, input, parsed.value, result);
    errdefer allocator.free(text);
    return .{ .json = json, .text = text };
}

fn formatApplicationJson(
    allocator: std.mem.Allocator,
    input: ApplicationInput,
    readiness: ReadinessReport,
    result: ApplicationResult,
) ![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "{\n");
    try output.appendSlice(allocator, "  \"schema\": ");
    try appendJsonString(allocator, &output, app_application_schema);
    try output.appendSlice(allocator, ",\n  \"schema_version\": 1,\n");
    try output.appendSlice(allocator, "  \"source_readiness\": ");
    try appendJsonString(allocator, &output, input.source_readiness_path);
    try output.appendSlice(allocator, ",\n  \"source_proposal\": ");
    try appendJsonString(allocator, &output, readiness.source_proposal);
    try output.appendSlice(allocator, ",\n  \"mode\": ");
    try appendJsonString(allocator, &output, modeText(input.mode));
    try output.appendSlice(allocator, ",\n  \"application_status\": ");
    try appendJsonString(allocator, &output, applicationStatusText(result.status));
    try output.print(allocator, ",\n  \"applied\": {},\n", .{result.applied});
    try output.appendSlice(allocator, "  \"mutation_authority\": ");
    try appendJsonString(allocator, &output, result.mutation_authority);
    try output.appendSlice(allocator, ",\n  \"applied_by\": ");
    try appendJsonString(allocator, &output, input.applied_by);
    try output.appendSlice(allocator, ",\n  \"policy\": ");
    try appendJsonString(allocator, &output, input.policy);
    try output.appendSlice(allocator, ",\n  \"reason\": ");
    try appendJsonString(allocator, &output, input.reason);
    try output.appendSlice(allocator, ",\n  \"readiness_status\": ");
    try appendJsonString(allocator, &output, readiness.readiness_status);
    try output.print(allocator, ",\n  \"ready_for_application\": {},\n", .{readiness.ready_for_application});
    try output.appendSlice(allocator, "  \"target\": ");
    try appendJsonString(allocator, &output, readiness.target);
    try output.appendSlice(allocator, ",\n  \"summary\": ");
    try appendJsonString(allocator, &output, readiness.summary);
    try output.appendSlice(allocator, ",\n  \"change\": ");
    try appendJsonString(allocator, &output, readiness.change);
    try output.appendSlice(allocator, ",\n  \"source\": ");
    try appendSourceJson(allocator, &output, input, readiness.source);
    try output.appendSlice(allocator, ",\n  \"policy_gates\": ");
    try appendStringArray(allocator, &output, readiness.policy_gates);
    try output.appendSlice(allocator, ",\n  \"citations\": ");
    try appendCitationsJson(allocator, &output, readiness.citations);
    try output.appendSlice(allocator, ",\n  \"event_ids\": ");
    try appendU64Array(allocator, &output, readiness.event_ids);
    try output.appendSlice(allocator, ",\n  \"checks\": ");
    try appendChecksJson(allocator, &output, result.checks);
    try output.appendSlice(allocator, ",\n  \"required_verification_commands\": ");
    try appendStringArray(allocator, &output, result.required_verification_commands);
    try output.appendSlice(allocator, ",\n  \"verified_commands\": ");
    try appendStringArray(allocator, &output, input.verified_commands);
    try output.appendSlice(allocator, ",\n  \"change_evidence\": ");
    try appendChangeEvidenceJson(allocator, &output, input.change_evidence);
    try output.appendSlice(allocator, ",\n  \"before_evidence\": ");
    try appendStringArray(allocator, &output, input.before_evidence);
    try output.appendSlice(allocator, ",\n  \"after_evidence\": ");
    try appendStringArray(allocator, &output, input.after_evidence);
    try output.appendSlice(allocator, ",\n  \"application_steps\": ");
    try appendStringArray(allocator, &output, applicationSteps(result.status));
    try output.appendSlice(allocator, ",\n  \"guardrails\": ");
    try appendStringArray(allocator, &output, applicationGuardrails(result.status));
    try output.append(allocator, '\n');
    try output.appendSlice(allocator, "}\n");
    return output.toOwnedSlice(allocator);
}

fn formatApplicationText(
    allocator: std.mem.Allocator,
    input: ApplicationInput,
    readiness: ReadinessReport,
    result: ApplicationResult,
) ![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "zigeffect app application\n");
    try output.print(allocator, "schema: {s}\n", .{app_application_schema});
    try output.print(allocator, "source readiness: {s}\n", .{input.source_readiness_path});
    try output.print(allocator, "source proposal: {s}\n", .{readiness.source_proposal});
    try output.print(allocator, "mode: {s}\n", .{modeText(input.mode)});
    try output.print(allocator, "application_status: {s}\n", .{applicationStatusText(result.status)});
    try output.print(allocator, "applied: {}\n", .{result.applied});
    try output.print(allocator, "mutation_authority: {s}\n", .{result.mutation_authority});
    try output.print(allocator, "applied_by: {s}\n", .{input.applied_by});
    try output.print(allocator, "policy: {s}\n", .{input.policy});
    try output.print(allocator, "reason: {s}\n", .{input.reason});
    try output.print(allocator, "readiness_status: {s}\n", .{readiness.readiness_status});
    try output.print(allocator, "ready_for_application: {}\n", .{readiness.ready_for_application});
    try output.print(allocator, "target: {s}\n", .{readiness.target});
    try output.print(allocator, "summary: {s}\n", .{readiness.summary});
    try output.print(allocator, "change: {s}\n\n", .{readiness.change});

    try output.appendSlice(allocator, "checks:\n");
    for (result.checks) |check| {
        try output.print(allocator, "- {s}: {s} - {s}\n", .{ check.name, checkStatusText(check.status), check.detail });
    }
    try output.append(allocator, '\n');

    try appendTextList(allocator, &output, "source changes", input.change_evidence.source_changes);
    try appendTextList(allocator, &output, "config changes", input.change_evidence.config_changes);
    try appendTextList(allocator, &output, "migration changes", input.change_evidence.migration_changes);
    try appendTextList(allocator, &output, "operation changes", input.change_evidence.operation_changes);
    try appendTextList(allocator, &output, "rollback changes", input.change_evidence.rollback_changes);
    try appendTextList(allocator, &output, "before evidence", input.before_evidence);
    try appendTextList(allocator, &output, "after evidence", input.after_evidence);
    try appendTextList(allocator, &output, "required verification", result.required_verification_commands);
    try appendTextList(allocator, &output, "verified commands", input.verified_commands);
    try appendTextList(allocator, &output, "application steps", applicationSteps(result.status));
    try appendTextList(allocator, &output, "guardrails", applicationGuardrails(result.status));

    return output.toOwnedSlice(allocator);
}

fn applicationStatusText(status: ApplicationStatus) []const u8 {
    return switch (status) {
        .planned => "planned",
        .applied => "applied",
        .blocked => "blocked",
    };
}

fn checkStatusText(status: CheckStatus) []const u8 {
    return switch (status) {
        .pass => "pass",
        .fail => "fail",
        .skipped => "skipped",
    };
}

fn applicationSteps(status: ApplicationStatus) []const []const u8 {
    return switch (status) {
        .planned => &.{
            "Apply the reviewed app source, config, migration, operational, or rollback changes outside this command.",
            "Capture before and after evidence around the real change.",
            "Run causal-app-apply record-applied only after post-application verification exists.",
        },
        .applied => &.{
            "Keep this application artifact with the reviewed change evidence.",
            "Do not rerun application unless source, external state, or verification evidence changes.",
        },
        .blocked => &.{
            "Resolve failed readiness, change evidence, before/after evidence, or verification checks before claiming app remediation.",
            "Regenerate app application evidence after the missing proof is available.",
        },
    };
}

fn applicationGuardrails(status: ApplicationStatus) []const []const u8 {
    return switch (status) {
        .planned => &.{
            "Plan mode does not edit source, config, migrations, operations, rollback plans, deployments, databases, queues, or external state.",
            "The application remains unapplied until a later record-applied artifact says applied=true.",
        },
        .applied => &.{
            "applied=true means reviewed changes and before/after verification evidence passed every application check.",
            "This command records application state; it does not silently mutate source or external systems.",
        },
        .blocked => &.{
            "Blocked application must not be treated as app fix coverage.",
            "Do not set applied=true until every application check passes.",
        },
    };
}

fn appendSourceJson(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    input: ApplicationInput,
    source: ReadinessSource,
) !void {
    try output.appendSlice(allocator, "{\n");
    try output.appendSlice(allocator, "    \"readiness\": ");
    try appendJsonString(allocator, output, input.source_readiness_path);
    try output.appendSlice(allocator, ",\n    \"proposal\": ");
    try appendJsonString(allocator, output, source.proposal);
    try output.appendSlice(allocator, ",\n    \"policy\": ");
    try appendJsonString(allocator, output, source.policy);
    if (source.human_review) |human_review| {
        try output.appendSlice(allocator, ",\n    \"human_review\": ");
        try appendJsonString(allocator, output, human_review);
    }
    try output.appendSlice(allocator, ",\n    \"app_remediation_audit\": ");
    try appendJsonString(allocator, output, source.app_remediation_audit);
    try output.appendSlice(allocator, ",\n    \"app_artifact\": ");
    try appendJsonString(allocator, output, source.app_artifact);
    try output.appendSlice(allocator, "\n  }");
}

fn appendCitationsJson(allocator: std.mem.Allocator, output: *std.ArrayList(u8), citations: ReadinessCitations) !void {
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

fn appendChangeEvidenceJson(allocator: std.mem.Allocator, output: *std.ArrayList(u8), evidence: ChangeEvidence) !void {
    try output.appendSlice(allocator, "{\n");
    try output.appendSlice(allocator, "    \"source_changes\": ");
    try appendStringArray(allocator, output, evidence.source_changes);
    try output.appendSlice(allocator, ",\n    \"config_changes\": ");
    try appendStringArray(allocator, output, evidence.config_changes);
    try output.appendSlice(allocator, ",\n    \"migration_changes\": ");
    try appendStringArray(allocator, output, evidence.migration_changes);
    try output.appendSlice(allocator, ",\n    \"operation_changes\": ");
    try appendStringArray(allocator, output, evidence.operation_changes);
    try output.appendSlice(allocator, ",\n    \"rollback_changes\": ");
    try appendStringArray(allocator, output, evidence.rollback_changes);
    try output.appendSlice(allocator, "\n  }");
}

fn appendChecksJson(allocator: std.mem.Allocator, output: *std.ArrayList(u8), checks: []const ApplicationCheck) !void {
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

fn duplicateStringSlice(allocator: std.mem.Allocator, values: []const []const u8) ![]const []const u8 {
    if (values.len == 0) return &.{};
    const copy = try allocator.alloc([]const u8, values.len);
    for (values, 0..) |value, index| copy[index] = try allocator.dupe(u8, value);
    return copy;
}

fn freeOwnedStringSlice(allocator: std.mem.Allocator, values: []const []const u8) void {
    if (values.len == 0) return;
    for (values) |value| allocator.free(value);
    allocator.free(values);
}

fn freeSliceOnly(allocator: std.mem.Allocator, values: []const []const u8) void {
    if (values.len > 0) allocator.free(values);
}

fn emptyChangeEvidence() ChangeEvidence {
    return .{};
}

fn readArtifact(io: std.Io, allocator: std.mem.Allocator, path: []const u8) ![]const u8 {
    return std.Io.Dir.cwd().readFileAlloc(io, path, allocator, .limited(1024 * 1024)) catch |err| switch (err) {
        error.FileNotFound => error.MissingAppApplicationReadinessInput,
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
    const paths = try applicationPathsFromReadiness(allocator, options.readiness_path);
    defer paths.deinit(allocator);

    const readiness_json = try readArtifact(init.io, allocator, options.readiness_path);
    defer allocator.free(readiness_json);

    const reports = try formatApplicationReports(allocator, .{
        .source_readiness_path = options.readiness_path,
        .readiness_json = readiness_json,
        .mode = options.mode,
        .applied_by = options.applied_by,
        .policy = options.policy,
        .reason = options.reason,
        .verified_commands = options.verified_commands,
        .change_evidence = options.change_evidence,
        .before_evidence = options.before_evidence,
        .after_evidence = options.after_evidence,
    });
    defer reports.deinit(allocator);

    try writeArtifact(init.io, paths.json, reports.json);
    try writeArtifact(init.io, paths.text, reports.text);
    std.debug.print("{s}", .{reports.text});
}

fn failUsage(err: anyerror) noreturn {
    std.debug.print("causal-app-apply error: {s}\n{s}", .{ @errorName(err), usage() });
    std.process.exit(2);
}

pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    const options = parseOptions(init.gpa, args) catch |err| failUsage(err);
    defer options.deinit(init.gpa);

    runLocal(init, options) catch |err| switch (err) {
        error.MissingAppApplicationReadinessInput,
        error.InvalidReadinessPath,
        error.InvalidProposalPath,
        error.UnsupportedReadinessSchema,
        error.MissingTarget,
        error.MissingSummary,
        error.MissingChange,
        error.MissingReadinessReason,
        error.ReadinessAlreadyApplied,
        error.ReadinessMutationAuthorityNotNone,
        error.UnknownReadinessStatus,
        error.InconsistentReadinessStatus,
        error.MissingReason,
        => failUsage(err),
        else => return err,
    };
}

fn readyReadinessJson() []const u8 {
    return ready_readiness_json;
}

fn blockedReadinessJson() []const u8 {
    return blocked_readiness_json;
}

fn highRiskReadinessJson() []const u8 {
    return high_risk_readiness_json;
}

const ready_readiness_json =
    \\{
    \\  "schema": "zigeffect.causal.app-application-readiness.v1",
    \\  "schema_version": 1,
    \\  "mode": "local",
    \\  "source_proposal": ".zig-cache/causal-artifacts/yachdee-platform-app-patch-proposal.json",
    \\  "decision": "approve",
    \\  "readiness_status": "ready",
    \\  "ready_for_application": true,
    \\  "reviewed_by": "local-reviewer",
    \\  "policy": "manual-app-application-readiness",
    \\  "reason": "reviewed proposal citations and verification evidence",
    \\  "applied": false,
    \\  "mutation_authority": "none",
    \\  "target": "yachdee-platform",
    \\  "summary": "Wire HealthService and document config binding",
    \\  "change": "Add provider layer and document YACHDEE_ENV.",
    \\  "source": {
    \\    "proposal": ".zig-cache/causal-artifacts/yachdee-platform-app-patch-proposal.json",
    \\    "policy": ".zig-cache/causal-artifacts/yachdee-platform-app-policy-decision.json",
    \\    "app_remediation_audit": ".zig-cache/causal-artifacts/yachdee-platform-app-remediation-audit.json",
    \\    "app_artifact": ".zig-cache/causal-artifacts/app.json",
    \\    "human_review": ".zig-cache/causal-artifacts/yachdee-platform-app-human-review.json"
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
    \\  "checks": [{ "name": "proposal-state", "status": "pass", "detail": "proposal is draft" }],
    \\  "required_verification_commands": ["zig build causal-query -- --file app.json cause 2"],
    \\  "verified_commands": ["zig build causal-query -- --file app.json cause 2"],
    \\  "application_steps": ["Apply the reviewed change outside this readiness command."],
    \\  "readiness_guardrails": ["Readiness does not edit app source."]
    \\}
;

const blocked_readiness_json =
    \\{
    \\  "schema": "zigeffect.causal.app-application-readiness.v1",
    \\  "schema_version": 1,
    \\  "mode": "local",
    \\  "source_proposal": ".zig-cache/causal-artifacts/yachdee-platform-app-patch-proposal.json",
    \\  "decision": "reject",
    \\  "readiness_status": "blocked",
    \\  "ready_for_application": false,
    \\  "reviewed_by": "local-reviewer",
    \\  "policy": "manual-app-application-readiness",
    \\  "reason": "proposal evidence is incomplete",
    \\  "applied": false,
    \\  "mutation_authority": "none",
    \\  "target": "yachdee-platform",
    \\  "summary": "Wire HealthService and document config binding",
    \\  "change": "Add provider layer and document YACHDEE_ENV.",
    \\  "source": {
    \\    "proposal": ".zig-cache/causal-artifacts/yachdee-platform-app-patch-proposal.json",
    \\    "policy": ".zig-cache/causal-artifacts/yachdee-platform-app-policy-decision.json",
    \\    "app_remediation_audit": ".zig-cache/causal-artifacts/yachdee-platform-app-remediation-audit.json",
    \\    "app_artifact": ".zig-cache/causal-artifacts/app.json"
    \\  },
    \\  "policy_gates": ["source-only"],
    \\  "citations": {
    \\    "source_files": ["apps/platform/src/worker.ts"],
    \\    "config_keys": [],
    \\    "migration_files": [],
    \\    "runbooks": [],
    \\    "rollback_plans": []
    \\  },
    \\  "event_ids": [2],
    \\  "checks": [{ "name": "decision-approved", "status": "fail", "detail": "reviewer rejected readiness" }],
    \\  "required_verification_commands": [],
    \\  "verified_commands": [],
    \\  "application_steps": ["Resolve failed readiness checks before attempting app application."],
    \\  "readiness_guardrails": ["Blocked readiness must not be treated as app application approval."]
    \\}
;

const high_risk_readiness_json =
    \\{
    \\  "schema": "zigeffect.causal.app-application-readiness.v1",
    \\  "schema_version": 1,
    \\  "mode": "local",
    \\  "source_proposal": ".zig-cache/causal-artifacts/yachdee-platform-app-patch-proposal.json",
    \\  "decision": "approve",
    \\  "readiness_status": "ready",
    \\  "ready_for_application": true,
    \\  "reviewed_by": "local-reviewer",
    \\  "policy": "manual-app-application-readiness",
    \\  "reason": "reviewed high risk proposal evidence",
    \\  "applied": false,
    \\  "mutation_authority": "none",
    \\  "target": "yachdee-platform",
    \\  "summary": "Run migration and rollback remediation",
    \\  "change": "Apply migration, operational runbook, and rollback plan.",
    \\  "source": {
    \\    "proposal": ".zig-cache/causal-artifacts/yachdee-platform-app-patch-proposal.json",
    \\    "policy": ".zig-cache/causal-artifacts/yachdee-platform-app-policy-decision.json",
    \\    "app_remediation_audit": ".zig-cache/causal-artifacts/yachdee-platform-app-remediation-audit.json",
    \\    "app_artifact": ".zig-cache/causal-artifacts/app.json",
    \\    "human_review": ".zig-cache/causal-artifacts/yachdee-platform-app-human-review.json"
    \\  },
    \\  "policy_gates": ["migration-required", "operational-human-required", "rollback-required"],
    \\  "citations": {
    \\    "source_files": [],
    \\    "config_keys": [],
    \\    "migration_files": ["packages/app/migrations/001.sql"],
    \\    "runbooks": ["docs/runbooks/migration.md"],
    \\    "rollback_plans": ["docs/runbooks/rollback.md"]
    \\  },
    \\  "event_ids": [4],
    \\  "checks": [{ "name": "proposal-state", "status": "pass", "detail": "proposal is draft" }],
    \\  "required_verification_commands": ["zig build causal-query -- --file app.json cause 4"],
    \\  "verified_commands": ["zig build causal-query -- --file app.json cause 4"],
    \\  "application_steps": ["Apply the reviewed high-risk change outside this readiness command."],
    \\  "readiness_guardrails": ["Readiness does not edit app source."]
    \\}
;

test "app apply usage names guarded app application command" {
    try std.testing.expect(std.mem.indexOf(u8, usage(), "causal-app-apply") != null);
    try std.testing.expectEqualStrings("zigeffect.causal.app-application.v1", app_application_schema);
}

test "app apply output paths derive from readiness path" {
    const paths = try applicationPathsFromReadiness(
        std.testing.allocator,
        ".zig-cache/causal-artifacts/yachdee-platform-app-application-readiness.json",
    );
    defer paths.deinit(std.testing.allocator);

    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/yachdee-platform-app-application.json",
        paths.json,
    );
    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/yachdee-platform-app-application.txt",
        paths.text,
    );
}

test "app apply plan creates planned report for ready readiness" {
    const options = try parseOptions(std.testing.allocator, &.{
        "zigeffect-causal-app-apply",
        "--from-readiness",
        ".zig-cache/causal-artifacts/yachdee-platform-app-application-readiness.json",
        "plan",
        "--reason",
        "plan reviewed app application",
    });
    defer options.deinit(std.testing.allocator);

    const result = try evaluateApplication(std.testing.allocator, .{
        .source_readiness_path = options.readiness_path,
        .readiness_json = readyReadinessJson(),
        .mode = options.mode,
        .applied_by = options.applied_by,
        .policy = options.policy,
        .reason = options.reason,
        .verified_commands = options.verified_commands,
        .change_evidence = options.change_evidence,
        .before_evidence = options.before_evidence,
        .after_evidence = options.after_evidence,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(ApplicationStatus.planned, result.status);
    try std.testing.expect(!result.applied);
    try std.testing.expect(checkPassed(result.checks, "readiness-ready"));
    try std.testing.expect(checkSkipped(result.checks, "change-evidence-present"));
}

test "app apply blocks blocked readiness" {
    const result = try evaluateApplication(std.testing.allocator, .{
        .source_readiness_path = ".zig-cache/causal-artifacts/yachdee-platform-app-application-readiness.json",
        .readiness_json = blockedReadinessJson(),
        .mode = .record_applied,
        .applied_by = "local-reviewer",
        .policy = "manual-app-application",
        .reason = "attempted blocked application",
        .verified_commands = &.{},
        .change_evidence = emptyChangeEvidence(),
        .before_evidence = &.{},
        .after_evidence = &.{},
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(ApplicationStatus.blocked, result.status);
    try std.testing.expect(!result.applied);
    try std.testing.expect(checkFailed(result.checks, "readiness-ready"));
}

test "app apply record-applied requires change and before after evidence" {
    const result = try evaluateApplication(std.testing.allocator, .{
        .source_readiness_path = ".zig-cache/causal-artifacts/yachdee-platform-app-application-readiness.json",
        .readiness_json = readyReadinessJson(),
        .mode = .record_applied,
        .applied_by = "local-reviewer",
        .policy = "manual-app-application",
        .reason = "missing application evidence",
        .verified_commands = &.{"zig build causal-query -- --file app.json cause 2"},
        .change_evidence = emptyChangeEvidence(),
        .before_evidence = &.{},
        .after_evidence = &.{},
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(ApplicationStatus.blocked, result.status);
    try std.testing.expect(!result.applied);
    try std.testing.expect(checkFailed(result.checks, "change-evidence-present"));
    try std.testing.expect(checkFailed(result.checks, "before-after-evidence-present"));
}

test "app apply record-applied emits applied true with complete low risk evidence" {
    const options = try parseOptions(std.testing.allocator, &.{
        "zigeffect-causal-app-apply",
        "--from-readiness",
        ".zig-cache/causal-artifacts/yachdee-platform-app-application-readiness.json",
        "record-applied",
        "--reason",
        "source and config change landed",
        "--verified-command",
        "zig build causal-query -- --file app.json cause 2",
        "--source-change",
        "apps/platform/src/worker.ts",
        "--config-change",
        "YACHDEE_API_BASE_URL",
        "--before",
        ".zig-cache/causal-artifacts/yachdee-platform-before-app.json",
        "--after",
        ".zig-cache/causal-artifacts/yachdee-platform-after-app.json",
    });
    defer options.deinit(std.testing.allocator);

    const reports = try formatApplicationReports(std.testing.allocator, .{
        .source_readiness_path = options.readiness_path,
        .readiness_json = readyReadinessJson(),
        .mode = options.mode,
        .applied_by = options.applied_by,
        .policy = options.policy,
        .reason = options.reason,
        .verified_commands = options.verified_commands,
        .change_evidence = options.change_evidence,
        .before_evidence = options.before_evidence,
        .after_evidence = options.after_evidence,
    });
    defer reports.deinit(std.testing.allocator);

    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"application_status\": \"applied\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"applied\": true") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"mutation_authority\": \"record-only\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"source_changes\": [\"apps/platform/src/worker.ts\"]") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"before_evidence\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.text, "application_status: applied") != null);
}

test "app apply high risk gates require matching evidence categories" {
    const result = try evaluateApplication(std.testing.allocator, .{
        .source_readiness_path = ".zig-cache/causal-artifacts/yachdee-platform-app-application-readiness.json",
        .readiness_json = highRiskReadinessJson(),
        .mode = .record_applied,
        .applied_by = "local-reviewer",
        .policy = "manual-app-application",
        .reason = "missing rollback evidence",
        .verified_commands = &.{"zig build causal-query -- --file app.json cause 4"},
        .change_evidence = .{
            .source_changes = &.{},
            .config_changes = &.{},
            .migration_changes = &.{"packages/app/migrations/001.sql"},
            .operation_changes = &.{"docs/runbooks/migration.md"},
            .rollback_changes = &.{},
        },
        .before_evidence = &.{".zig-cache/causal-artifacts/before.json"},
        .after_evidence = &.{".zig-cache/causal-artifacts/after.json"},
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(ApplicationStatus.blocked, result.status);
    try std.testing.expect(checkFailed(result.checks, "change-evidence-present"));
}
