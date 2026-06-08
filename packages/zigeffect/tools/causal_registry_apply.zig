const std = @import("std");
const causal_run = @import("causal_run");

const readiness_suffix = "-registry-application-readiness.json";
const application_suffix = "-registry-application";
const readiness_schema = "zigeffect.causal.registry-application-readiness.v1";
const application_schema = "zigeffect.causal.registry-application.v1";

const Mode = enum {
    plan,
    record_applied,
};

const ApplicationStatus = enum {
    planned,
    applied,
    blocked,
    not_applicable,
};

const CheckStatus = enum {
    pass,
    fail,
    skipped,
};

const Options = struct {
    readiness_path: []const u8,
    mode: Mode,
    applied_by: []const u8 = "local-reviewer",
    policy: []const u8 = "manual-application",
    reason: []const u8,
    verified_commands: []const []const u8 = &.{},

    fn deinit(self: Options, allocator: std.mem.Allocator) void {
        if (self.verified_commands.len > 0) allocator.free(self.verified_commands);
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

const ReadinessCheck = struct {
    name: []const u8,
    status: []const u8,
    detail: []const u8,
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
    checks: []const ReadinessCheck = &.{},
    required_verification_commands: []const []const u8 = &.{},
    verified_commands: []const []const u8 = &.{},
    guardrails: []const []const u8 = &.{},
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
    scenario_docs: []const u8 = "",
};

const ApplicationResult = struct {
    status: ApplicationStatus,
    applied: bool,
    checks: []const ApplicationCheck,
    required_verification_commands: []const []const u8,

    fn deinit(self: ApplicationResult, allocator: std.mem.Allocator) void {
        if (self.checks.len > 0) allocator.free(self.checks);
        freeStringSlice(allocator, self.required_verification_commands);
    }
};

fn parseOptions(allocator: std.mem.Allocator, args: []const []const u8) !Options {
    if (args.len < 3) return error.MissingReadinessPath;
    if (!std.mem.eql(u8, args[1], "--from-readiness")) return error.UnknownFlag;
    if (!std.mem.endsWith(u8, args[2], readiness_suffix)) return error.InvalidReadinessPath;
    if (args.len < 4) return error.MissingMode;

    const mode: Mode = if (std.mem.eql(u8, args[3], "plan"))
        .plan
    else if (std.mem.eql(u8, args[3], "record-applied"))
        .record_applied
    else
        return error.UnknownMode;

    var applied_by: []const u8 = "local-reviewer";
    var policy: []const u8 = "manual-application";
    var reason: ?[]const u8 = null;
    var verified_commands = std.ArrayList([]const u8).empty;
    errdefer verified_commands.deinit(allocator);

    var index: usize = 4;
    while (index < args.len) {
        if (index + 1 >= args.len) return error.MissingFlagValue;
        const flag = args[index];
        const value = args[index + 1];

        if (std.mem.eql(u8, flag, "--by")) {
            applied_by = value;
        } else if (std.mem.eql(u8, flag, "--policy")) {
            policy = value;
        } else if (std.mem.eql(u8, flag, "--reason")) {
            reason = value;
        } else if (std.mem.eql(u8, flag, "--verified-command")) {
            try verified_commands.append(allocator, value);
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

fn modeText(mode: Mode) []const u8 {
    return switch (mode) {
        .plan => "plan",
        .record_applied => "record-applied",
    };
}

fn usage() []const u8 {
    return "usage: zig build causal-registry-apply -- --from-readiness <registry-application-readiness.json> plan|record-applied --reason <reason> [--by <actor>] [--policy <policy>] [--verified-command <command>]...\n";
}

fn failUsage(err: anyerror) noreturn {
    std.debug.print("causal-registry-apply error: {s}\n{s}", .{ @errorName(err), usage() });
    std.process.exit(2);
}

fn validateReadiness(report: ReadinessReport) !void {
    if (!std.mem.eql(u8, report.schema, readiness_schema)) return error.UnsupportedReadinessSchema;
    if (report.schema_version != 1) return error.UnsupportedReadinessSchema;
    if (report.applied) return error.ReadinessAlreadyApplied;
    if (!std.mem.endsWith(u8, report.source_registry_patch, "-registry-patch.json")) return error.InvalidRegistryPatchPath;
    if (!std.mem.eql(u8, report.readiness_status, "applicable") and
        !std.mem.eql(u8, report.readiness_status, "blocked") and
        !std.mem.eql(u8, report.readiness_status, "not-applicable"))
    {
        return error.UnknownReadinessStatus;
    }
}

fn evaluateApplication(allocator: std.mem.Allocator, input: ApplicationInput) !ApplicationResult {
    _ = input.source_readiness_path;
    _ = input.applied_by;
    _ = input.policy;
    if (input.reason.len == 0) return error.MissingReason;

    var parsed = try std.json.parseFromSlice(ReadinessReport, allocator, input.readiness_json, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();
    try validateReadiness(parsed.value);

    var checks = std.ArrayList(ApplicationCheck).empty;
    errdefer checks.deinit(allocator);

    try appendCheck(allocator, &checks, "readiness-schema", .pass, "readiness schema is supported");

    const required_commands = try duplicateStringSlice(allocator, parsed.value.required_verification_commands);
    errdefer freeStringSlice(allocator, required_commands);

    if (std.mem.eql(u8, parsed.value.readiness_status, "not-applicable")) {
        try appendCheck(allocator, &checks, "readiness-applicable", .skipped, "readiness report says no registry patch applies");
        return .{
            .status = .not_applicable,
            .applied = false,
            .checks = try checks.toOwnedSlice(allocator),
            .required_verification_commands = required_commands,
        };
    }

    if (!std.mem.eql(u8, parsed.value.readiness_status, "applicable")) {
        try appendCheck(allocator, &checks, "readiness-applicable", .fail, "readiness report is blocked");
        return .{
            .status = .blocked,
            .applied = false,
            .checks = try checks.toOwnedSlice(allocator),
            .required_verification_commands = required_commands,
        };
    }

    try appendCheck(allocator, &checks, "readiness-applicable", .pass, "readiness report is applicable");

    const approved = std.mem.eql(u8, parsed.value.decision, "approve");
    try appendCheck(
        allocator,
        &checks,
        "decision-approved",
        if (approved) .pass else .fail,
        "readiness decision must approve application",
    );

    if (!approved) {
        return .{
            .status = .blocked,
            .applied = false,
            .checks = try checks.toOwnedSlice(allocator),
            .required_verification_commands = required_commands,
        };
    }

    if (input.mode == .plan) {
        return .{
            .status = .planned,
            .applied = false,
            .checks = try checks.toOwnedSlice(allocator),
            .required_verification_commands = required_commands,
        };
    }

    const scenario_slug = parsed.value.scenario_slug orelse "";
    const scenario = if (scenario_slug.len == 0) null else scenarioBySlug(scenario_slug);
    if (scenario) |current| {
        try appendCheck(allocator, &checks, "source-registry-present", .pass, "current source registry contains scenario slug");
        try appendCheck(
            allocator,
            &checks,
            "source-placeholder-cleared",
            if (scenarioHasPlaceholderArgv(current)) .fail else .pass,
            "current scenario argv is not the generated placeholder",
        );
        try appendCheck(
            allocator,
            &checks,
            "source-invariants-known",
            if (scenarioInvariantIdsKnown(current)) .pass else .fail,
            "current scenario invariant ids are present in the catalog",
        );
    } else {
        try appendCheck(allocator, &checks, "source-registry-present", .fail, "current source registry does not contain scenario slug");
        try appendCheck(allocator, &checks, "source-placeholder-cleared", .skipped, "scenario argv cannot be checked until the scenario exists");
        try appendCheck(allocator, &checks, "source-invariants-known", .skipped, "scenario invariants cannot be checked until the scenario exists");
    }

    try appendCheck(
        allocator,
        &checks,
        "source-docs-present",
        if (scenario_slug.len > 0 and std.mem.indexOf(u8, input.scenario_docs, scenario_slug) != null) .pass else .fail,
        "current causal scenario docs mention the scenario slug",
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

    return .{
        .status = if (allChecksPassed(check_slice)) .applied else .blocked,
        .applied = allChecksPassed(check_slice),
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

fn duplicateStringSlice(allocator: std.mem.Allocator, values: []const []const u8) ![]const []const u8 {
    if (values.len == 0) return &.{};
    const copy = try allocator.alloc([]const u8, values.len);
    errdefer allocator.free(copy);
    for (values, 0..) |value, index| {
        copy[index] = try allocator.dupe(u8, value);
        errdefer allocator.free(copy[index]);
    }
    return copy;
}

fn freeStringSlice(allocator: std.mem.Allocator, values: []const []const u8) void {
    if (values.len == 0) return;
    for (values) |value| allocator.free(value);
    allocator.free(values);
}

fn scenarioBySlug(slug: []const u8) ?causal_run.Scenario {
    return causal_run.scenarioByName(slug) catch null;
}

fn scenarioHasPlaceholderArgv(scenario: causal_run.Scenario) bool {
    return scenario.argv.len == 3 and
        std.mem.eql(u8, scenario.argv[0], "zig") and
        std.mem.eql(u8, scenario.argv[1], "build") and
        std.mem.eql(u8, scenario.argv[2], "examples");
}

fn scenarioInvariantIdsKnown(scenario: causal_run.Scenario) bool {
    for (scenario.invariant_ids) |id| {
        _ = causal_run.invariantById(id) catch return false;
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

const sample_applicable_readiness_json =
    \\{
    \\  "schema": "zigeffect.causal.registry-application-readiness.v1",
    \\  "schema_version": 1,
    \\  "source_registry_patch": ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-package-tests-registry-patch.json",
    \\  "decision": "approve",
    \\  "readiness_status": "applicable",
    \\  "decided_by": "local-reviewer",
    \\  "policy": "manual-review",
    \\  "reason": "reviewed registry patch draft",
    \\  "applied": false,
    \\  "target": "package-tests",
    \\  "scenario_slug": "package-tests",
    \\  "checks": [],
    \\  "required_verification_commands": ["zig build causal-run package-tests", "zig build examples", "zig build test --summary none"],
    \\  "verified_commands": ["zig build causal-run package-tests", "zig build examples", "zig build test --summary none"],
    \\  "guardrails": ["Readiness does not apply source changes."]
    \\}
;

const sample_blocked_readiness_json =
    \\{
    \\  "schema": "zigeffect.causal.registry-application-readiness.v1",
    \\  "schema_version": 1,
    \\  "source_registry_patch": ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-registry-patch.json",
    \\  "decision": "approve",
    \\  "readiness_status": "blocked",
    \\  "decided_by": "local-reviewer",
    \\  "policy": "manual-review",
    \\  "reason": "reviewed registry patch draft",
    \\  "applied": false,
    \\  "target": "dogfood",
    \\  "scenario_slug": "learned-dogfood-service-resolution",
    \\  "checks": [],
    \\  "required_verification_commands": ["zig build causal-run learned-dogfood-service-resolution", "zig build examples", "zig build test --summary none"],
    \\  "verified_commands": ["zig build examples"],
    \\  "guardrails": ["Blocked readiness must not be treated as registry coverage."]
    \\}
;

const sample_noop_readiness_json =
    \\{
    \\  "schema": "zigeffect.causal.registry-application-readiness.v1",
    \\  "schema_version": 1,
    \\  "source_registry_patch": ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-registry-patch.json",
    \\  "decision": "approve",
    \\  "readiness_status": "not-applicable",
    \\  "decided_by": "local-reviewer",
    \\  "policy": "manual-review",
    \\  "reason": "no registry patch applies",
    \\  "applied": false,
    \\  "target": "causal-scoped-fiber",
    \\  "scenario_slug": null,
    \\  "checks": [],
    \\  "required_verification_commands": [],
    \\  "verified_commands": [],
    \\  "guardrails": ["No registry patch applies to this evidence."]
    \\}
;

test "registry apply parses plan mode and metadata" {
    const options = try parseOptions(std.testing.allocator, &.{
        "zigeffect-causal-registry-apply",
        "--from-readiness",
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-registry-application-readiness.json",
        "plan",
        "--reason",
        "prepare manual registry application",
        "--by",
        "local-reviewer",
        "--policy",
        "manual-application",
    });
    defer options.deinit(std.testing.allocator);

    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-registry-application-readiness.json",
        options.readiness_path,
    );
    try std.testing.expectEqual(Mode.plan, options.mode);
    try std.testing.expectEqualStrings("local-reviewer", options.applied_by);
    try std.testing.expectEqualStrings("manual-application", options.policy);
    try std.testing.expectEqualStrings("prepare manual registry application", options.reason);
    try std.testing.expectEqual(@as(usize, 0), options.verified_commands.len);
}

test "registry apply parses record-applied verification commands" {
    const options = try parseOptions(std.testing.allocator, &.{
        "zigeffect-causal-registry-apply",
        "--from-readiness",
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-package-tests-registry-application-readiness.json",
        "record-applied",
        "--reason",
        "registry and docs updated",
        "--verified-command",
        "zig build causal-run package-tests",
        "--verified-command",
        "zig build examples",
        "--verified-command",
        "zig build test --summary none",
    });
    defer options.deinit(std.testing.allocator);

    try std.testing.expectEqual(Mode.record_applied, options.mode);
    try std.testing.expectEqual(@as(usize, 3), options.verified_commands.len);
}

test "registry apply rejects missing path reason unknown mode and bad suffix" {
    try std.testing.expectError(error.MissingReadinessPath, parseOptions(std.testing.allocator, &.{
        "zigeffect-causal-registry-apply",
    }));
    try std.testing.expectError(error.InvalidReadinessPath, parseOptions(std.testing.allocator, &.{
        "zigeffect-causal-registry-apply",
        "--from-readiness",
        ".zig-cache/causal-artifacts/readiness.json",
        "plan",
        "--reason",
        "x",
    }));
    try std.testing.expectError(error.UnknownMode, parseOptions(std.testing.allocator, &.{
        "zigeffect-causal-registry-apply",
        "--from-readiness",
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-registry-application-readiness.json",
        "apply",
        "--reason",
        "x",
    }));
    try std.testing.expectError(error.MissingReason, parseOptions(std.testing.allocator, &.{
        "zigeffect-causal-registry-apply",
        "--from-readiness",
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-registry-application-readiness.json",
        "plan",
    }));
}

test "registry apply output paths derive from readiness path" {
    const paths = try applicationPathsFromReadiness(
        std.testing.allocator,
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-registry-application-readiness.json",
    );
    defer paths.deinit(std.testing.allocator);

    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-registry-application.json",
        paths.json,
    );
    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-registry-application.txt",
        paths.text,
    );
}

test "registry apply plan creates planned report for applicable readiness" {
    const result = try evaluateApplication(std.testing.allocator, .{
        .source_readiness_path = ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-package-tests-registry-application-readiness.json",
        .readiness_json = sample_applicable_readiness_json,
        .mode = .plan,
        .applied_by = "local-reviewer",
        .policy = "manual-application",
        .reason = "prepare manual application",
        .verified_commands = &.{},
        .scenario_docs = "package-tests",
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(ApplicationStatus.planned, result.status);
    try std.testing.expect(!result.applied);
    try std.testing.expect(checkPassed(result.checks, "readiness-applicable"));
}

test "registry apply blocks blocked readiness" {
    const result = try evaluateApplication(std.testing.allocator, .{
        .source_readiness_path = ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-registry-application-readiness.json",
        .readiness_json = sample_blocked_readiness_json,
        .mode = .plan,
        .applied_by = "local-reviewer",
        .policy = "manual-application",
        .reason = "blocked readiness cannot apply",
        .verified_commands = &.{},
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(ApplicationStatus.blocked, result.status);
    try std.testing.expect(!result.applied);
    try std.testing.expect(checkFailed(result.checks, "readiness-applicable"));
}

test "registry apply records no-op readiness as not applicable" {
    const result = try evaluateApplication(std.testing.allocator, .{
        .source_readiness_path = ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-registry-application-readiness.json",
        .readiness_json = sample_noop_readiness_json,
        .mode = .record_applied,
        .applied_by = "local-reviewer",
        .policy = "manual-application",
        .reason = "no patch applies",
        .verified_commands = &.{},
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(ApplicationStatus.not_applicable, result.status);
    try std.testing.expect(!result.applied);
}

test "registry apply record-applied requires source and verification evidence" {
    const result = try evaluateApplication(std.testing.allocator, .{
        .source_readiness_path = ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-package-tests-registry-application-readiness.json",
        .readiness_json = sample_applicable_readiness_json,
        .mode = .record_applied,
        .applied_by = "local-reviewer",
        .policy = "manual-application",
        .reason = "registry applied",
        .verified_commands = &.{
            "zig build causal-run package-tests",
            "zig build examples",
            "zig build test --summary none",
        },
        .scenario_docs = "package-tests",
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(ApplicationStatus.applied, result.status);
    try std.testing.expect(result.applied);
    try std.testing.expect(checkPassed(result.checks, "source-registry-present"));
    try std.testing.expect(checkPassed(result.checks, "post-verification-recorded"));
}
