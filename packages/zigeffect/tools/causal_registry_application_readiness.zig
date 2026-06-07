const std = @import("std");
const causal_run = @import("causal_run");

const registry_patch_suffix = "-registry-patch.json";
const readiness_suffix = "-registry-application-readiness";
const registry_patch_schema = "zigeffect.causal.registry-patch.v1";

const Decision = enum {
    approve,
    reject,
};

const Options = struct {
    registry_patch_path: []const u8,
    decision: Decision,
    decided_by: []const u8 = "local-reviewer",
    policy: []const u8 = "manual-review",
    reason: []const u8,
    verified_commands: []const []const u8 = &.{},

    fn deinit(self: Options, allocator: std.mem.Allocator) void {
        if (self.verified_commands.len > 0) allocator.free(self.verified_commands);
    }
};

const ReadinessPaths = struct {
    json: []const u8,
    text: []const u8,

    fn deinit(self: ReadinessPaths, allocator: std.mem.Allocator) void {
        allocator.free(self.json);
        allocator.free(self.text);
    }
};

const ReadinessStatus = enum {
    applicable,
    blocked,
    not_applicable,
};

const CheckStatus = enum {
    pass,
    fail,
    skipped,
};

const RegistryPatch = struct {
    schema: []const u8,
    schema_version: u32,
    source_proposal: []const u8,
    recommendation: []const u8,
    patch_status: []const u8,
    target: []const u8,
    scenario_slug: ?[]const u8 = null,
    scenario_conflict: bool,
    known_invariant_ids: []const []const u8 = &.{},
    new_invariant_ids: []const []const u8 = &.{},
    review_checklist: []const []const u8 = &.{},
    guardrails: []const []const u8 = &.{},
};

const ReadinessInput = struct {
    source_registry_patch_path: []const u8,
    registry_patch_json: []const u8,
    decision: Decision,
    decided_by: []const u8,
    policy: []const u8,
    reason: []const u8,
    verified_commands: []const []const u8,
    scenario_docs: []const u8 = "",
};

const ReadinessCheck = struct {
    name: []const u8,
    status: CheckStatus,
    detail: []const u8,
};

const ReadinessResult = struct {
    status: ReadinessStatus,
    applied: bool,
    checks: []const ReadinessCheck,
    required_verification_commands: []const []const u8,
    scenario_run_command: ?[]const u8,

    fn deinit(self: ReadinessResult, allocator: std.mem.Allocator) void {
        allocator.free(self.checks);
        if (self.scenario_run_command) |command| allocator.free(command);
        if (self.required_verification_commands.len > 0) allocator.free(self.required_verification_commands);
    }
};

fn parseOptions(allocator: std.mem.Allocator, args: []const []const u8) !Options {
    if (args.len < 3) return error.MissingRegistryPatchPath;
    if (!std.mem.eql(u8, args[1], "--from-registry-patch")) return error.UnknownFlag;
    if (!std.mem.endsWith(u8, args[2], registry_patch_suffix)) return error.InvalidRegistryPatchPath;
    if (args.len < 4) return error.MissingDecision;

    const decision: Decision = if (std.mem.eql(u8, args[3], "approve"))
        .approve
    else if (std.mem.eql(u8, args[3], "reject"))
        .reject
    else
        return error.UnknownDecision;

    var decided_by: []const u8 = "local-reviewer";
    var policy: []const u8 = "manual-review";
    var reason: ?[]const u8 = null;
    var verified_commands = std.ArrayList([]const u8).empty;
    errdefer verified_commands.deinit(allocator);

    var index: usize = 4;
    while (index < args.len) {
        const arg = args[index];
        if (index + 1 >= args.len) return error.MissingFlagValue;
        const value = args[index + 1];

        if (std.mem.eql(u8, arg, "--by")) {
            decided_by = value;
        } else if (std.mem.eql(u8, arg, "--policy")) {
            policy = value;
        } else if (std.mem.eql(u8, arg, "--reason")) {
            reason = value;
        } else if (std.mem.eql(u8, arg, "--verified-command")) {
            try verified_commands.append(allocator, value);
        } else {
            return error.UnknownFlag;
        }
        index += 2;
    }

    const final_reason = reason orelse return error.MissingReason;
    if (final_reason.len == 0) return error.MissingReason;

    return .{
        .registry_patch_path = args[2],
        .decision = decision,
        .decided_by = decided_by,
        .policy = policy,
        .reason = final_reason,
        .verified_commands = try verified_commands.toOwnedSlice(allocator),
    };
}

fn readinessPathsFromRegistryPatch(allocator: std.mem.Allocator, registry_patch_path: []const u8) !ReadinessPaths {
    if (!std.mem.endsWith(u8, registry_patch_path, registry_patch_suffix)) return error.InvalidRegistryPatchPath;
    const prefix = registry_patch_path[0 .. registry_patch_path.len - registry_patch_suffix.len];

    const json = try std.fmt.allocPrint(allocator, "{s}{s}.json", .{ prefix, readiness_suffix });
    errdefer allocator.free(json);
    const text = try std.fmt.allocPrint(allocator, "{s}{s}.txt", .{ prefix, readiness_suffix });

    return .{ .json = json, .text = text };
}

fn decisionText(decision: Decision) []const u8 {
    return switch (decision) {
        .approve => "approve",
        .reject => "reject",
    };
}

fn usage() []const u8 {
    return "usage: zig build causal-registry-application-readiness -- --from-registry-patch <registry-patch.json> approve|reject --reason <reason> [--by <actor>] [--policy <policy>] [--verified-command <command>]...\n";
}

fn failUsage(err: anyerror) noreturn {
    std.debug.print("causal-registry-application-readiness error: {s}\n{s}", .{ @errorName(err), usage() });
    std.process.exit(2);
}

fn validateRegistryPatch(patch: RegistryPatch) !void {
    if (!std.mem.eql(u8, patch.schema, registry_patch_schema)) return error.UnsupportedRegistryPatchSchema;
    if (patch.schema_version != 1) return error.UnsupportedRegistryPatchSchema;
    if (!std.mem.eql(u8, patch.recommendation, "add-scenario") and
        !std.mem.eql(u8, patch.recommendation, "refine-scenario") and
        !std.mem.eql(u8, patch.recommendation, "none"))
    {
        return error.UnknownRecommendation;
    }
}

fn evaluateReadiness(allocator: std.mem.Allocator, input: ReadinessInput) !ReadinessResult {
    _ = input.source_registry_patch_path;
    _ = input.decided_by;
    _ = input.policy;
    if (input.reason.len == 0) return error.MissingReason;

    var parsed = try std.json.parseFromSlice(RegistryPatch, allocator, input.registry_patch_json, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();
    try validateRegistryPatch(parsed.value);

    var checks = std.ArrayList(ReadinessCheck).empty;
    errdefer checks.deinit(allocator);

    try appendCheck(allocator, &checks, "registry-patch-schema", .pass, "registry patch schema is supported");
    try appendCheck(allocator, &checks, "reviewer-decision", .pass, "reviewer supplied a decision and reason");

    if (std.mem.eql(u8, parsed.value.recommendation, "none")) {
        const patch_status_check: CheckStatus = if (std.mem.eql(u8, parsed.value.patch_status, "no-op")) .pass else .fail;
        try appendCheck(allocator, &checks, "patch-status", patch_status_check, "no-op registry patch does not apply");
        return .{
            .status = .not_applicable,
            .applied = false,
            .checks = try checks.toOwnedSlice(allocator),
            .required_verification_commands = &.{},
            .scenario_run_command = null,
        };
    }

    const patch_status_check: CheckStatus = if (std.mem.eql(u8, parsed.value.patch_status, "review-required")) .pass else .fail;
    try appendCheck(allocator, &checks, "patch-status", patch_status_check, "review-required registry patch can be checked");

    if (input.decision == .reject) {
        return .{
            .status = .blocked,
            .applied = false,
            .checks = try checks.toOwnedSlice(allocator),
            .required_verification_commands = &.{},
            .scenario_run_command = null,
        };
    }

    const scenario_slug = parsed.value.scenario_slug orelse "";
    const scenario = if (scenario_slug.len == 0) null else scenarioBySlug(scenario_slug);
    if (scenario) |current| {
        try appendCheck(allocator, &checks, "scenario-present", .pass, "scenario exists in causal_run registry");
        const placeholder_status: CheckStatus = if (scenarioHasPlaceholderArgv(current)) .fail else .pass;
        try appendCheck(allocator, &checks, "placeholder-argv-replaced", placeholder_status, "scenario argv is not the generated placeholder");
    } else {
        try appendCheck(allocator, &checks, "scenario-present", .fail, "scenario is not present in causal_run registry");
        try appendCheck(allocator, &checks, "placeholder-argv-replaced", .skipped, "scenario argv cannot be checked until the scenario exists");
    }

    const conflict_status: CheckStatus = if (parsed.value.scenario_conflict) .fail else .pass;
    try appendCheck(allocator, &checks, "scenario-conflict", conflict_status, "registry patch conflict flag is resolved");

    const invariant_status: CheckStatus = if (allInvariantIdsKnown(parsed.value)) .pass else .fail;
    try appendCheck(allocator, &checks, "invariant-catalog-consistent", invariant_status, "registry patch invariant ids are present in the catalog");

    const docs_status: CheckStatus = if (scenario_slug.len > 0 and std.mem.indexOf(u8, input.scenario_docs, scenario_slug) != null) .pass else .fail;
    try appendCheck(allocator, &checks, "scenario-docs-updated", docs_status, "causal scenario docs mention the scenario slug");

    const required = try requiredVerificationCommands(allocator, scenario_slug);
    errdefer required.deinit(allocator);
    const verification_status: CheckStatus = if (verifiedCommandsContainAll(input.verified_commands, required.commands)) .pass else .fail;
    try appendCheck(allocator, &checks, "required-verification-recorded", verification_status, "reviewer recorded required verification commands");

    const check_slice = try checks.toOwnedSlice(allocator);
    errdefer allocator.free(check_slice);

    return .{
        .status = if (allChecksPassed(check_slice)) .applicable else .blocked,
        .applied = false,
        .checks = check_slice,
        .required_verification_commands = required.commands,
        .scenario_run_command = required.scenario_run_command,
    };
}

const RequiredCommands = struct {
    commands: []const []const u8,
    scenario_run_command: ?[]const u8,

    fn deinit(self: RequiredCommands, allocator: std.mem.Allocator) void {
        if (self.scenario_run_command) |command| allocator.free(command);
        if (self.commands.len > 0) allocator.free(self.commands);
    }
};

fn requiredVerificationCommands(allocator: std.mem.Allocator, scenario_slug: []const u8) !RequiredCommands {
    if (scenario_slug.len == 0) return .{ .commands = &.{}, .scenario_run_command = null };

    const scenario_run = try std.fmt.allocPrint(allocator, "zig build causal-run {s}", .{scenario_slug});
    errdefer allocator.free(scenario_run);

    const commands = try allocator.alloc([]const u8, 3);
    commands[0] = scenario_run;
    commands[1] = "zig build examples";
    commands[2] = "zig build test --summary none";

    return .{ .commands = commands, .scenario_run_command = scenario_run };
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

fn scenarioBySlug(slug: []const u8) ?causal_run.Scenario {
    return causal_run.scenarioByName(slug) catch null;
}

fn scenarioHasPlaceholderArgv(scenario: causal_run.Scenario) bool {
    return scenario.argv.len == 3 and
        std.mem.eql(u8, scenario.argv[0], "zig") and
        std.mem.eql(u8, scenario.argv[1], "build") and
        std.mem.eql(u8, scenario.argv[2], "examples");
}

fn allInvariantIdsKnown(patch: RegistryPatch) bool {
    for (patch.known_invariant_ids) |id| {
        _ = causal_run.invariantById(id) catch return false;
    }
    for (patch.new_invariant_ids) |id| {
        _ = causal_run.invariantById(id) catch return false;
    }
    return true;
}

fn verifiedCommandsContainAll(verified_commands: []const []const u8, required_commands: []const []const u8) bool {
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

const sample_add_registry_patch_json =
    \\{
    \\  "schema": "zigeffect.causal.registry-patch.v1",
    \\  "schema_version": 1,
    \\  "source_proposal": ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-scenario-proposal.json",
    \\  "recommendation": "add-scenario",
    \\  "patch_status": "review-required",
    \\  "target": "dogfood",
    \\  "scenario_slug": "learned-dogfood-service-resolution",
    \\  "scenario_conflict": false,
    \\  "known_invariant_ids": [],
    \\  "new_invariant_ids": ["service-resolution-errors-are-causal"],
    \\  "review_checklist": ["Replace placeholder argv with the smallest reproducing command."],
    \\  "guardrails": ["This registry patch is generated from evidence but requires explicit review."]
    \\}
;

const sample_noop_registry_patch_json =
    \\{
    \\  "schema": "zigeffect.causal.registry-patch.v1",
    \\  "schema_version": 1,
    \\  "source_proposal": ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-scenario-proposal.json",
    \\  "recommendation": "none",
    \\  "patch_status": "no-op",
    \\  "target": "causal-scoped-fiber",
    \\  "scenario_slug": null,
    \\  "scenario_conflict": false,
    \\  "known_invariant_ids": [],
    \\  "new_invariant_ids": [],
    \\  "review_checklist": ["Confirm no scenario or invariant change is needed for clear evidence."],
    \\  "guardrails": ["Do not apply registry changes for no-op proposals."]
    \\}
;

const sample_refine_existing_registry_patch_json =
    \\{
    \\  "schema": "zigeffect.causal.registry-patch.v1",
    \\  "schema_version": 1,
    \\  "source_proposal": ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-scenario-proposal.json",
    \\  "recommendation": "refine-scenario",
    \\  "patch_status": "review-required",
    \\  "target": "causal-scoped-fiber",
    \\  "scenario_slug": "causal-scoped-fiber",
    \\  "scenario_conflict": false,
    \\  "known_invariant_ids": ["scoped-fiber-must-finish-before-scope-close"],
    \\  "new_invariant_ids": [],
    \\  "review_checklist": ["Run the scenario after applying the registry patch."],
    \\  "guardrails": ["This registry patch is generated from evidence but requires explicit review."]
    \\}
;

test "registry readiness parses approve decision and verified commands" {
    const options = try parseOptions(std.testing.allocator, &.{
        "zigeffect-causal-registry-application-readiness",
        "--from-registry-patch",
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-registry-patch.json",
        "approve",
        "--reason",
        "reviewed registry entry and docs",
        "--by",
        "local-reviewer",
        "--policy",
        "manual-review",
        "--verified-command",
        "zig build causal-run learned-dogfood-service-resolution",
        "--verified-command",
        "zig build examples",
    });
    defer options.deinit(std.testing.allocator);

    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-registry-patch.json",
        options.registry_patch_path,
    );
    try std.testing.expectEqual(Decision.approve, options.decision);
    try std.testing.expectEqualStrings("local-reviewer", options.decided_by);
    try std.testing.expectEqualStrings("manual-review", options.policy);
    try std.testing.expectEqualStrings("reviewed registry entry and docs", options.reason);
    try std.testing.expectEqual(@as(usize, 2), options.verified_commands.len);
}

test "registry readiness rejects missing path reason and unknown flags" {
    try std.testing.expectError(error.MissingRegistryPatchPath, parseOptions(std.testing.allocator, &.{
        "zigeffect-causal-registry-application-readiness",
    }));
    try std.testing.expectError(error.InvalidRegistryPatchPath, parseOptions(std.testing.allocator, &.{
        "zigeffect-causal-registry-application-readiness",
        "--from-registry-patch",
        "registry-patch.json",
        "approve",
        "--reason",
        "x",
    }));
    try std.testing.expectError(error.MissingReason, parseOptions(std.testing.allocator, &.{
        "zigeffect-causal-registry-application-readiness",
        "--from-registry-patch",
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-registry-patch.json",
        "reject",
    }));
    try std.testing.expectError(error.UnknownFlag, parseOptions(std.testing.allocator, &.{
        "zigeffect-causal-registry-application-readiness",
        "--from-registry-patch",
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-registry-patch.json",
        "approve",
        "--reason",
        "x",
        "--actor",
        "reviewer",
    }));
}

test "registry readiness output paths are derived from registry patch path" {
    const paths = try readinessPathsFromRegistryPatch(
        std.testing.allocator,
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-registry-patch.json",
    );
    defer paths.deinit(std.testing.allocator);

    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-registry-application-readiness.json",
        paths.json,
    );
    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-registry-application-readiness.txt",
        paths.text,
    );
}

test "registry readiness marks no-op patches not applicable" {
    const result = try evaluateReadiness(std.testing.allocator, .{
        .source_registry_patch_path = ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-registry-patch.json",
        .registry_patch_json = sample_noop_registry_patch_json,
        .decision = .approve,
        .decided_by = "local-reviewer",
        .policy = "manual-review",
        .reason = "clear evidence needs no scenario change",
        .verified_commands = &.{},
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(ReadinessStatus.not_applicable, result.status);
    try std.testing.expect(!result.applied);
    try std.testing.expect(checkPassed(result.checks, "registry-patch-schema"));
}

test "registry readiness blocks approved add scenario when source is not applied" {
    const result = try evaluateReadiness(std.testing.allocator, .{
        .source_registry_patch_path = ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-registry-patch.json",
        .registry_patch_json = sample_add_registry_patch_json,
        .decision = .approve,
        .decided_by = "local-reviewer",
        .policy = "manual-review",
        .reason = "reviewed generated draft",
        .verified_commands = &.{
            "zig build causal-run learned-dogfood-service-resolution",
            "zig build examples",
            "zig build test --summary none",
        },
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(ReadinessStatus.blocked, result.status);
    try std.testing.expect(checkFailed(result.checks, "scenario-present"));
    try std.testing.expect(checkFailed(result.checks, "invariant-catalog-consistent"));
}

test "registry readiness approves existing refined scenario with evidence" {
    const result = try evaluateReadiness(std.testing.allocator, .{
        .source_registry_patch_path = ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-registry-patch.json",
        .registry_patch_json = sample_refine_existing_registry_patch_json,
        .decision = .approve,
        .decided_by = "local-reviewer",
        .policy = "manual-review",
        .reason = "existing scenario and invariant are reviewed",
        .verified_commands = &.{
            "zig build causal-run causal-scoped-fiber",
            "zig build examples",
            "zig build test --summary none",
        },
        .scenario_docs = "scenario causal-scoped-fiber is documented",
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(ReadinessStatus.applicable, result.status);
    try std.testing.expect(checkPassed(result.checks, "scenario-present"));
    try std.testing.expect(checkPassed(result.checks, "placeholder-argv-replaced"));
    try std.testing.expect(checkPassed(result.checks, "invariant-catalog-consistent"));
    try std.testing.expect(checkPassed(result.checks, "required-verification-recorded"));
}

test "registry readiness rejects unsupported schema and missing reason" {
    var parsed = try std.json.parseFromSlice(RegistryPatch, std.testing.allocator, sample_refine_existing_registry_patch_json, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();

    var bad_schema = parsed.value;
    bad_schema.schema = "other.schema";
    try std.testing.expectError(error.UnsupportedRegistryPatchSchema, validateRegistryPatch(bad_schema));

    try std.testing.expectError(error.MissingReason, evaluateReadiness(std.testing.allocator, .{
        .source_registry_patch_path = ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-registry-patch.json",
        .registry_patch_json = sample_refine_existing_registry_patch_json,
        .decision = .approve,
        .decided_by = "local-reviewer",
        .policy = "manual-review",
        .reason = "",
        .verified_commands = &.{},
    }));
}
