const std = @import("std");
const causal_run = @import("causal_run");

const registry_patch_suffix = "-registry-patch.json";
const readiness_suffix = "-registry-application-readiness";
const registry_patch_schema = "zigeffect.causal.registry-patch.v1";
const readiness_schema = "zigeffect.causal.registry-application-readiness.v1";
const scenario_docs_path = "docs/causal-scenarios.md";

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

const ReadinessReports = struct {
    json: []const u8,
    text: []const u8,

    fn deinit(self: ReadinessReports, allocator: std.mem.Allocator) void {
        allocator.free(self.json);
        allocator.free(self.text);
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

fn formatReadinessReports(allocator: std.mem.Allocator, input: ReadinessInput) !ReadinessReports {
    var parsed = try std.json.parseFromSlice(RegistryPatch, allocator, input.registry_patch_json, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();
    try validateRegistryPatch(parsed.value);

    const result = try evaluateReadiness(allocator, input);
    defer result.deinit(allocator);

    const json = try formatReadinessJson(allocator, input, parsed.value, result);
    errdefer allocator.free(json);
    const text = try formatReadinessText(allocator, input, parsed.value, result);
    errdefer allocator.free(text);

    return .{ .json = json, .text = text };
}

fn formatReadinessJson(
    allocator: std.mem.Allocator,
    input: ReadinessInput,
    patch: RegistryPatch,
    result: ReadinessResult,
) ![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "{\n");
    try output.appendSlice(allocator, "  \"schema\": ");
    try appendJsonString(allocator, &output, readiness_schema);
    try output.appendSlice(allocator, ",\n");
    try output.appendSlice(allocator, "  \"schema_version\": 1,\n");
    try output.appendSlice(allocator, "  \"source_registry_patch\": ");
    try appendJsonString(allocator, &output, input.source_registry_patch_path);
    try output.appendSlice(allocator, ",\n");
    try output.appendSlice(allocator, "  \"decision\": ");
    try appendJsonString(allocator, &output, decisionText(input.decision));
    try output.appendSlice(allocator, ",\n");
    try output.appendSlice(allocator, "  \"readiness_status\": ");
    try appendJsonString(allocator, &output, readinessStatusText(result.status));
    try output.appendSlice(allocator, ",\n");
    try output.appendSlice(allocator, "  \"decided_by\": ");
    try appendJsonString(allocator, &output, input.decided_by);
    try output.appendSlice(allocator, ",\n");
    try output.appendSlice(allocator, "  \"policy\": ");
    try appendJsonString(allocator, &output, input.policy);
    try output.appendSlice(allocator, ",\n");
    try output.appendSlice(allocator, "  \"reason\": ");
    try appendJsonString(allocator, &output, input.reason);
    try output.appendSlice(allocator, ",\n");
    try output.print(allocator, "  \"applied\": {},\n", .{result.applied});
    try output.appendSlice(allocator, "  \"target\": ");
    try appendJsonString(allocator, &output, patch.target);
    try output.appendSlice(allocator, ",\n");
    try output.appendSlice(allocator, "  \"scenario_slug\": ");
    if (patch.scenario_slug) |slug| {
        try appendJsonString(allocator, &output, slug);
    } else {
        try output.appendSlice(allocator, "null");
    }
    try output.appendSlice(allocator, ",\n");
    try output.appendSlice(allocator, "  \"checks\": ");
    try appendChecksJson(allocator, &output, result.checks);
    try output.appendSlice(allocator, ",\n");
    try output.appendSlice(allocator, "  \"required_verification_commands\": ");
    try appendStringArray(allocator, &output, result.required_verification_commands);
    try output.appendSlice(allocator, ",\n");
    try output.appendSlice(allocator, "  \"verified_commands\": ");
    try appendStringArray(allocator, &output, input.verified_commands);
    try output.appendSlice(allocator, ",\n");
    try output.appendSlice(allocator, "  \"guardrails\": ");
    try appendStringArray(allocator, &output, readinessGuardrails(result.status));
    try output.append(allocator, '\n');
    try output.appendSlice(allocator, "}\n");

    return output.toOwnedSlice(allocator);
}

fn formatReadinessText(
    allocator: std.mem.Allocator,
    input: ReadinessInput,
    patch: RegistryPatch,
    result: ReadinessResult,
) ![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "zigeffect causal registry application readiness\n");
    try output.print(allocator, "schema: {s}\n", .{readiness_schema});
    try output.print(allocator, "source registry patch: {s}\n", .{input.source_registry_patch_path});
    try output.print(allocator, "decision: {s}\n", .{decisionText(input.decision)});
    try output.print(allocator, "readiness_status: {s}\n", .{readinessStatusText(result.status)});
    try output.print(allocator, "decided_by: {s}\n", .{input.decided_by});
    try output.print(allocator, "policy: {s}\n", .{input.policy});
    try output.print(allocator, "reason: {s}\n", .{input.reason});
    try output.print(allocator, "applied: {}\n", .{result.applied});
    try output.print(allocator, "target: {s}\n", .{patch.target});
    if (patch.scenario_slug) |slug| {
        try output.print(allocator, "scenario: {s}\n", .{slug});
    } else {
        try output.appendSlice(allocator, "scenario: none\n");
    }

    try output.appendSlice(allocator, "\nchecks:\n");
    for (result.checks) |check| {
        try output.print(allocator, "- {s}: {s} - {s}\n", .{ check.name, checkStatusText(check.status), check.detail });
    }

    try output.appendSlice(allocator, "\nrequired verification:\n");
    if (result.required_verification_commands.len == 0) {
        try output.appendSlice(allocator, "- none\n");
    } else {
        for (result.required_verification_commands) |command| try output.print(allocator, "- {s}\n", .{command});
    }

    try output.appendSlice(allocator, "\nguardrails:\n");
    for (readinessGuardrails(result.status)) |guardrail| try output.print(allocator, "- {s}\n", .{guardrail});

    return output.toOwnedSlice(allocator);
}

fn readinessStatusText(status: ReadinessStatus) []const u8 {
    return switch (status) {
        .applicable => "applicable",
        .blocked => "blocked",
        .not_applicable => "not-applicable",
    };
}

fn checkStatusText(status: CheckStatus) []const u8 {
    return switch (status) {
        .pass => "pass",
        .fail => "fail",
        .skipped => "skipped",
    };
}

fn readinessGuardrails(status: ReadinessStatus) []const []const u8 {
    return switch (status) {
        .applicable => &.{
            "Readiness does not apply source changes.",
            "Apply registry changes manually or through a guarded application backend.",
            "Run recorded verification before claiming coverage.",
        },
        .blocked => &.{
            "Blocked readiness must not be treated as registry coverage.",
            "Resolve failed checks before applying registry changes.",
        },
        .not_applicable => &.{
            "No registry patch applies to this evidence.",
            "Do not create speculative scenario coverage from no-op evidence.",
        },
    };
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

fn readRequiredArtifact(io: std.Io, allocator: std.mem.Allocator, path: []const u8) ![]const u8 {
    return std.Io.Dir.cwd().readFileAlloc(io, path, allocator, .limited(1024 * 1024)) catch |err| switch (err) {
        error.FileNotFound => error.MissingRegistryPatchInput,
        else => return err,
    };
}

fn readOptionalArtifact(io: std.Io, allocator: std.mem.Allocator, path: []const u8) ![]const u8 {
    return std.Io.Dir.cwd().readFileAlloc(io, path, allocator, .limited(1024 * 1024)) catch |err| switch (err) {
        error.FileNotFound => return allocator.dupe(u8, ""),
        else => return err,
    };
}

fn writeArtifact(io: std.Io, path: []const u8, contents: []const u8) !void {
    const slash = std.mem.lastIndexOfScalar(u8, path, '/') orelse return error.InvalidArtifactPath;
    const cwd = std.Io.Dir.cwd();
    try cwd.createDirPath(io, path[0..slash]);
    try cwd.writeFile(io, .{ .sub_path = path, .data = contents });
}

fn runFromRegistryPatch(init: std.process.Init, options: Options) !void {
    const allocator = init.gpa;
    const registry_patch_json = try readRequiredArtifact(init.io, allocator, options.registry_patch_path);
    defer allocator.free(registry_patch_json);
    const scenario_docs = try readOptionalArtifact(init.io, allocator, scenario_docs_path);
    defer allocator.free(scenario_docs);

    const reports = try formatReadinessReports(allocator, .{
        .source_registry_patch_path = options.registry_patch_path,
        .registry_patch_json = registry_patch_json,
        .decision = options.decision,
        .decided_by = options.decided_by,
        .policy = options.policy,
        .reason = options.reason,
        .verified_commands = options.verified_commands,
        .scenario_docs = scenario_docs,
    });
    defer reports.deinit(allocator);

    const paths = try readinessPathsFromRegistryPatch(allocator, options.registry_patch_path);
    defer paths.deinit(allocator);

    try writeArtifact(init.io, paths.json, reports.json);
    try writeArtifact(init.io, paths.text, reports.text);
    std.debug.print("{s}", .{reports.text});
}

pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    const options = parseOptions(init.gpa, args) catch |err| failUsage(err);
    defer options.deinit(init.gpa);
    runFromRegistryPatch(init, options) catch |err| switch (err) {
        error.MissingRegistryPatchInput,
        error.InvalidRegistryPatchPath,
        error.InvalidArtifactPath,
        error.UnsupportedRegistryPatchSchema,
        error.UnknownRecommendation,
        error.MissingReason,
        => failUsage(err),
        else => return err,
    };
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

test "registry readiness formats blocked approval reports" {
    const reports = try formatReadinessReports(std.testing.allocator, .{
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
    defer reports.deinit(std.testing.allocator);

    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"schema\": \"zigeffect.causal.registry-application-readiness.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"readiness_status\": \"blocked\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"applied\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.text, "readiness_status: blocked") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.text, "scenario-present: fail") != null);
}

test "registry readiness formats applicable approval reports" {
    const reports = try formatReadinessReports(std.testing.allocator, .{
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
    defer reports.deinit(std.testing.allocator);

    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"readiness_status\": \"applicable\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.text, "required verification:") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.text, "zig build causal-run causal-scoped-fiber") != null);
}

test "registry readiness formats rejection as blocked" {
    const reports = try formatReadinessReports(std.testing.allocator, .{
        .source_registry_patch_path = ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-registry-patch.json",
        .registry_patch_json = sample_refine_existing_registry_patch_json,
        .decision = .reject,
        .decided_by = "local-reviewer",
        .policy = "manual-review",
        .reason = "reviewer chose not to apply registry coverage",
        .verified_commands = &.{},
    });
    defer reports.deinit(std.testing.allocator);

    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"decision\": \"reject\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"readiness_status\": \"blocked\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.text, "reviewer chose not to apply registry coverage") != null);
}
