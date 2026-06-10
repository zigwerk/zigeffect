const std = @import("std");

pub const production_telemetry_implementation_proposal_schema = "zigeffect.causal.production-telemetry-implementation-proposal.v1";
pub const production_telemetry_implementation_proposal_schema_version: u32 = 1;
pub const source_branch = "codex/zigeffect-causal-production-telemetry-implementation-proposal";
pub const recommendation = "start-production-telemetry-exporter-boundary";
pub const next_branch_if_approved = "codex/zigeffect-causal-production-telemetry-exporter-boundary";

const readiness_schema = "zigeffect.causal.production-telemetry-readiness-review.v1";
const generated_by = "causal-production-telemetry-implementation-proposal";
const applied = false;
const mutation_authority = "none";
const production_telemetry_ingestion = false;
const live_exporter_enabled = false;
const durable_write_enabled = false;
const ci_gate_enabled = false;

const Decision = enum { approve, reject };
const ProposalStatus = enum { approved, blocked };
const CheckStatus = enum { pass, fail };

const Options = struct {
    readiness_path: []const u8,
    decision: Decision,
    proposed_by: []const u8 = "local-proposer",
    policy: []const u8 = "manual-production-telemetry-implementation-proposal",
    reason: []const u8,
    verified_commands: []const []const u8 = &.{},
    out_prefix: ?[]const u8 = null,

    fn deinit(self: Options, allocator: std.mem.Allocator) void {
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

const ProposalInput = struct {
    options: Options,
    source_readiness_json: []const u8,
};

const ProposalReports = struct {
    json: []const u8,
    text: []const u8,

    fn deinit(self: ProposalReports, allocator: std.mem.Allocator) void {
        allocator.free(self.json);
        allocator.free(self.text);
    }
};

const ReadinessCheck = struct {
    name: []const u8,
    status: []const u8,
    detail: []const u8 = "",
};

const ReadinessSummary = struct {
    source_contract_count: usize = 0,
    positive_fixture_count: usize = 0,
    negative_fixture_count: usize = 0,
    validation_check_count: usize = 0,
};

const ReadinessArtifact = struct {
    schema: []const u8,
    schema_version: u32,
    source_fixtures: []const u8 = "",
    decision: []const u8,
    readiness_status: []const u8,
    ready_for_implementation_proposal: bool,
    applied: bool,
    mutation_authority: []const u8,
    production_telemetry_ingestion: bool,
    live_exporter_enabled: bool,
    durable_write_enabled: bool,
    ci_gate_enabled: bool,
    fixture_summary: ReadinessSummary = .{},
    checks: []const ReadinessCheck = &.{},
    required_verification_commands: []const []const u8 = &.{},
    verified_commands: []const []const u8 = &.{},
};

const ProposalCheck = struct {
    name: []const u8,
    status: CheckStatus,
    detail: []const u8,
};

const ProposalResult = struct {
    status: ProposalStatus,
    approved_for_next_branch: bool,
    checks: []const ProposalCheck,
    readiness_summary: ReadinessSummary,
    source_fixtures: []const u8,

    fn deinit(self: ProposalResult, allocator: std.mem.Allocator) void {
        if (self.checks.len > 0) allocator.free(self.checks);
    }
};

fn parseOptions(allocator: std.mem.Allocator, args: []const []const u8) !Options {
    if (args.len < 2) return error.MissingReadinessPath;
    if (!std.mem.eql(u8, args[1], "--from-readiness")) return error.UnknownFlag;
    if (args.len < 3) return error.MissingReadinessPath;
    const readiness_path = args[2];
    if (!std.mem.endsWith(u8, readiness_path, ".json")) return error.InvalidReadinessPath;
    if (args.len < 4) return error.MissingDecision;
    const decision = try parseDecision(args[3]);

    var proposed_by: []const u8 = "local-proposer";
    var policy: []const u8 = "manual-production-telemetry-implementation-proposal";
    var reason: ?[]const u8 = null;
    var out_prefix: ?[]const u8 = null;
    var verified_commands = std.ArrayList([]const u8).empty;
    errdefer verified_commands.deinit(allocator);

    var index: usize = 4;
    while (index < args.len) {
        const arg = args[index];
        if (!std.mem.startsWith(u8, arg, "--")) return error.UnknownArgument;
        if (index + 1 >= args.len) return error.MissingFlagValue;
        const value = args[index + 1];

        if (std.mem.eql(u8, arg, "--reason")) {
            reason = value;
        } else if (std.mem.eql(u8, arg, "--by")) {
            proposed_by = value;
        } else if (std.mem.eql(u8, arg, "--policy")) {
            policy = value;
        } else if (std.mem.eql(u8, arg, "--verified-command")) {
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
        .readiness_path = readiness_path,
        .decision = decision,
        .proposed_by = proposed_by,
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
        if (!std.mem.endsWith(u8, options.readiness_path, ".json")) return error.InvalidReadinessPath;
        const base = options.readiness_path[0 .. options.readiness_path.len - ".json".len];
        break :blk try std.fmt.allocPrint(allocator, "{s}-implementation-proposal", .{base});
    };
    defer allocator.free(prefix);

    return .{
        .json_path = try std.fmt.allocPrint(allocator, "{s}.json", .{prefix}),
        .text_path = try std.fmt.allocPrint(allocator, "{s}.txt", .{prefix}),
    };
}

fn formatReports(allocator: std.mem.Allocator, input: ProposalInput) !ProposalReports {
    var parsed = try std.json.parseFromSlice(ReadinessArtifact, allocator, input.source_readiness_json, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();

    const result = try evaluateProposal(allocator, input.options, parsed.value);
    defer result.deinit(allocator);

    const json = try formatProposalJson(allocator, input.options, result);
    errdefer allocator.free(json);
    const text = try formatProposalText(allocator, input.options, result);
    errdefer allocator.free(text);

    return .{ .json = json, .text = text };
}

pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    const options = parseOptions(init.gpa, args) catch |err| failUsage(err);
    defer options.deinit(init.gpa);
    run(init, options) catch |err| switch (err) {
        error.MissingReadinessInput => failUsage(err),
        else => return err,
    };
}

fn parseDecision(value: []const u8) !Decision {
    if (std.mem.eql(u8, value, "approve")) return .approve;
    if (std.mem.eql(u8, value, "reject")) return .reject;
    return error.UnknownDecision;
}

fn decisionText(decision: Decision) []const u8 {
    return switch (decision) {
        .approve => "approve",
        .reject => "reject",
    };
}

fn proposalStatusText(status: ProposalStatus) []const u8 {
    return switch (status) {
        .approved => "approved",
        .blocked => "blocked",
    };
}

fn checkStatusText(status: CheckStatus) []const u8 {
    return switch (status) {
        .pass => "pass",
        .fail => "fail",
    };
}

fn evaluateProposal(
    allocator: std.mem.Allocator,
    options: Options,
    readiness: ReadinessArtifact,
) !ProposalResult {
    var checks = std.ArrayList(ProposalCheck).empty;
    errdefer checks.deinit(allocator);

    try appendCheck(allocator, &checks, "readiness-schema", if (std.mem.eql(u8, readiness.schema, readiness_schema) and readiness.schema_version == 1) .pass else .fail, "source readiness schema is supported");
    try appendCheck(allocator, &checks, "readiness-status", if (std.mem.eql(u8, readiness.readiness_status, "ready") and readiness.ready_for_implementation_proposal) .pass else .fail, "source readiness artifact is ready for implementation proposal");
    try appendCheck(allocator, &checks, "readiness-decision-approved", if (std.mem.eql(u8, readiness.decision, "approve")) .pass else .fail, "source readiness reviewer approved fixture evidence");
    try appendCheck(allocator, &checks, "proposal-decision", if (options.reason.len > 0) .pass else .fail, "proposal decision includes a reason");
    try appendCheck(allocator, &checks, "decision-approved", if (options.decision == .approve) .pass else .fail, "proposal decision must approve next branch handoff");
    try appendCheck(allocator, &checks, "authority-boundary", if (authorityBoundaryIntact(readiness)) .pass else .fail, "readiness and proposal authority fields remain disabled");
    try appendCheck(allocator, &checks, "source-fixtures-linked", if (readiness.source_fixtures.len > 0 and std.mem.endsWith(u8, readiness.source_fixtures, ".json")) .pass else .fail, "readiness artifact links source fixture JSON");
    try appendCheck(allocator, &checks, "readiness-checks-passed", if (readinessChecksPassed(readiness.checks)) .pass else .fail, "all source readiness checks passed");
    try appendCheck(allocator, &checks, "readiness-verification-recorded", if (readinessVerificationRecorded(readiness)) .pass else .fail, "source readiness recorded required verification command evidence");
    try appendCheck(allocator, &checks, "proposal-verification-recorded", if (verifiedCommandsContainAll(options.verified_commands, required_verification_commands)) .pass else .fail, "proposal recorded every required verification command");
    try appendCheck(allocator, &checks, "nendb-only-scope", if (nendbOnlyScope()) .pass else .fail, "durable direction remains future NenDB-only scope");
    try appendCheck(allocator, &checks, "solid-webui-scope", if (solidWebuiScope()) .pass else .fail, "workbench direction remains SolidJS inside webui-dev/zig-webui");

    const check_slice = try checks.toOwnedSlice(allocator);
    errdefer allocator.free(check_slice);
    const approved = allChecksPassed(check_slice);
    return .{
        .status = if (approved) .approved else .blocked,
        .approved_for_next_branch = approved,
        .checks = check_slice,
        .readiness_summary = readiness.fixture_summary,
        .source_fixtures = readiness.source_fixtures,
    };
}

fn appendCheck(
    allocator: std.mem.Allocator,
    checks: *std.ArrayList(ProposalCheck),
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

fn authorityBoundaryIntact(readiness: ReadinessArtifact) bool {
    return !readiness.applied and
        std.mem.eql(u8, readiness.mutation_authority, "none") and
        !readiness.production_telemetry_ingestion and
        !readiness.live_exporter_enabled and
        !readiness.durable_write_enabled and
        !readiness.ci_gate_enabled and
        !applied and
        std.mem.eql(u8, mutation_authority, "none") and
        !production_telemetry_ingestion and
        !live_exporter_enabled and
        !durable_write_enabled and
        !ci_gate_enabled;
}

fn readinessChecksPassed(checks: []const ReadinessCheck) bool {
    const required = [_][]const u8{
        "fixture-schema",
        "fixture-status",
        "reviewer-decision",
        "decision-approved",
        "authority-boundary",
        "source-contracts-present",
        "positive-fixture-coverage",
        "negative-fixture-coverage",
        "validation-checks-passed",
        "nendb-only-retention",
        "solid-webui-direction",
        "required-verification-recorded",
    };
    for (required) |name| {
        if (!hasReadinessCheck(checks, name, "pass")) return false;
    }
    for (checks) |check| {
        if (!std.mem.eql(u8, check.status, "pass")) return false;
    }
    return true;
}

fn hasReadinessCheck(checks: []const ReadinessCheck, name: []const u8, status: []const u8) bool {
    for (checks) |check| {
        if (std.mem.eql(u8, check.name, name) and std.mem.eql(u8, check.status, status)) return true;
    }
    return false;
}

fn readinessVerificationRecorded(readiness: ReadinessArtifact) bool {
    return readiness.required_verification_commands.len > 0 and
        verifiedCommandsContainAll(readiness.verified_commands, readiness.required_verification_commands);
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

fn nendbOnlyScope() bool {
    return containsString(non_goals, "Non-NenDB durable adapter work") and
        containsString(non_goals, "Cockroach adapter work") and
        containsString(blocked_claims, "non-nendb-durable-storage") and
        containsString(blocked_claims, "cockroach-adapter-work");
}

fn solidWebuiScope() bool {
    return containsString(non_goals, "React or alternate renderer work") and
        containsString(blocked_claims, "react-or-alternate-renderer");
}

fn containsString(values: []const []const u8, needle: []const u8) bool {
    for (values) |value| {
        if (std.mem.indexOf(u8, value, needle) != null) return true;
    }
    return false;
}

fn allChecksPassed(checks: []const ProposalCheck) bool {
    for (checks) |check| {
        if (check.status != .pass) return false;
    }
    return true;
}

fn formatProposalJson(
    allocator: std.mem.Allocator,
    options: Options,
    result: ProposalResult,
) ![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "{\n");
    try output.appendSlice(allocator, "  \"schema\": ");
    try appendJsonString(allocator, &output, production_telemetry_implementation_proposal_schema);
    try output.appendSlice(allocator, ",\n  \"schema_version\": 1,\n");
    try output.appendSlice(allocator, "  \"source_readiness\": ");
    try appendJsonString(allocator, &output, options.readiness_path);
    try output.appendSlice(allocator, ",\n  \"source_fixtures\": ");
    try appendJsonString(allocator, &output, result.source_fixtures);
    try output.appendSlice(allocator, ",\n  \"decision\": ");
    try appendJsonString(allocator, &output, decisionText(options.decision));
    try output.appendSlice(allocator, ",\n  \"proposal_status\": ");
    try appendJsonString(allocator, &output, proposalStatusText(result.status));
    try output.print(allocator, ",\n  \"approved_for_next_branch\": {},\n", .{result.approved_for_next_branch});
    try output.appendSlice(allocator, "  \"proposed_by\": ");
    try appendJsonString(allocator, &output, options.proposed_by);
    try output.appendSlice(allocator, ",\n  \"policy\": ");
    try appendJsonString(allocator, &output, options.policy);
    try output.appendSlice(allocator, ",\n  \"reason\": ");
    try appendJsonString(allocator, &output, options.reason);
    try output.print(allocator, ",\n  \"applied\": {},\n", .{applied});
    try output.appendSlice(allocator, "  \"mutation_authority\": ");
    try appendJsonString(allocator, &output, mutation_authority);
    try output.print(allocator, ",\n  \"production_telemetry_ingestion\": {},\n", .{production_telemetry_ingestion});
    try output.print(allocator, "  \"live_exporter_enabled\": {},\n", .{live_exporter_enabled});
    try output.print(allocator, "  \"durable_write_enabled\": {},\n", .{durable_write_enabled});
    try output.print(allocator, "  \"ci_gate_enabled\": {},\n", .{ci_gate_enabled});
    try output.appendSlice(allocator, "  \"source_branch\": ");
    try appendJsonString(allocator, &output, source_branch);
    try output.appendSlice(allocator, ",\n  \"recommendation\": ");
    try appendJsonString(allocator, &output, recommendation);
    try output.appendSlice(allocator, ",\n  \"next_branch_if_approved\": ");
    try appendJsonString(allocator, &output, next_branch_if_approved);
    try output.appendSlice(allocator, ",\n  \"readiness_summary\": ");
    try appendReadinessSummaryJson(allocator, &output, result.readiness_summary);
    try output.appendSlice(allocator, ",\n  \"checks\": ");
    try appendChecksJson(allocator, &output, result.checks);
    try output.appendSlice(allocator, ",\n  \"proposal_phases\": ");
    try appendStringArray(allocator, &output, proposal_phases);
    try output.appendSlice(allocator, ",\n  \"implementation_gates\": ");
    try appendStringArray(allocator, &output, implementation_gates);
    try output.appendSlice(allocator, ",\n  \"non_goals\": ");
    try appendStringArray(allocator, &output, non_goals);
    try output.appendSlice(allocator, ",\n  \"blocked_claims\": ");
    try appendStringArray(allocator, &output, blocked_claims);
    try output.appendSlice(allocator, ",\n  \"required_verification_commands\": ");
    try appendStringArray(allocator, &output, required_verification_commands);
    try output.appendSlice(allocator, ",\n  \"verified_commands\": ");
    try appendStringArray(allocator, &output, options.verified_commands);
    try output.appendSlice(allocator, ",\n  \"agent_guidance\": ");
    try appendStringArray(allocator, &output, agentGuidance(result.status));
    try output.appendSlice(allocator, "\n}\n");

    return output.toOwnedSlice(allocator);
}

fn formatProposalText(
    allocator: std.mem.Allocator,
    options: Options,
    result: ProposalResult,
) ![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "zigeffect production telemetry implementation proposal\n");
    try output.print(allocator, "schema: {s}\n", .{production_telemetry_implementation_proposal_schema});
    try output.print(allocator, "source readiness: {s}\n", .{options.readiness_path});
    try output.print(allocator, "source fixtures: {s}\n", .{result.source_fixtures});
    try output.print(allocator, "decision: {s}\n", .{decisionText(options.decision)});
    try output.print(allocator, "proposal_status: {s}\n", .{proposalStatusText(result.status)});
    try output.print(allocator, "approved_for_next_branch: {}\n", .{result.approved_for_next_branch});
    try output.print(allocator, "proposed_by: {s}\n", .{options.proposed_by});
    try output.print(allocator, "policy: {s}\n", .{options.policy});
    try output.print(allocator, "reason: {s}\n", .{options.reason});
    try output.print(allocator, "applied: {}\n", .{applied});
    try output.print(allocator, "mutation_authority: {s}\n", .{mutation_authority});
    try output.print(allocator, "production telemetry ingestion: {}\n", .{production_telemetry_ingestion});
    try output.print(allocator, "live exporter enabled: {}\n", .{live_exporter_enabled});
    try output.print(allocator, "durable write enabled: {}\n", .{durable_write_enabled});
    try output.print(allocator, "ci gate enabled: {}\n", .{ci_gate_enabled});
    try output.print(allocator, "generated by: {s}\n", .{generated_by});
    try output.print(allocator, "source branch: {s}\n", .{source_branch});
    try output.print(allocator, "recommendation: {s}\n", .{recommendation});
    try output.print(allocator, "next branch if approved: {s}\n\n", .{next_branch_if_approved});

    try output.appendSlice(allocator, "readiness summary:\n");
    try output.print(allocator, "- source contracts: {d}\n", .{result.readiness_summary.source_contract_count});
    try output.print(allocator, "- positive fixtures: {d}\n", .{result.readiness_summary.positive_fixture_count});
    try output.print(allocator, "- negative fixtures: {d}\n", .{result.readiness_summary.negative_fixture_count});
    try output.print(allocator, "- validation checks: {d}\n\n", .{result.readiness_summary.validation_check_count});

    try output.appendSlice(allocator, "checks:\n");
    for (result.checks) |check| {
        try output.print(allocator, "- {s}: {s} - {s}\n", .{ check.name, checkStatusText(check.status), check.detail });
    }
    try output.append(allocator, '\n');

    try appendTextList(allocator, &output, "proposal phases", proposal_phases);
    try appendTextList(allocator, &output, "implementation gates", implementation_gates);
    try appendTextList(allocator, &output, "non-goals", non_goals);
    try appendTextList(allocator, &output, "blocked claims", blocked_claims);
    try appendTextList(allocator, &output, "required verification commands", required_verification_commands);
    try appendTextList(allocator, &output, "verified commands", options.verified_commands);
    try appendTextList(allocator, &output, "agent guidance", agentGuidance(result.status));

    return output.toOwnedSlice(allocator);
}

fn appendReadinessSummaryJson(allocator: std.mem.Allocator, output: *std.ArrayList(u8), summary: ReadinessSummary) !void {
    try output.print(
        allocator,
        "{{ \"source_contract_count\": {d}, \"positive_fixture_count\": {d}, \"negative_fixture_count\": {d}, \"validation_check_count\": {d} }}",
        .{ summary.source_contract_count, summary.positive_fixture_count, summary.negative_fixture_count, summary.validation_check_count },
    );
}

fn appendChecksJson(allocator: std.mem.Allocator, output: *std.ArrayList(u8), checks: []const ProposalCheck) !void {
    try output.append(allocator, '[');
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

fn appendTextList(allocator: std.mem.Allocator, output: *std.ArrayList(u8), title: []const u8, values: []const []const u8) !void {
    try output.print(allocator, "{s}:\n", .{title});
    if (values.len == 0) {
        try output.appendSlice(allocator, "- none\n\n");
        return;
    }
    for (values) |value| {
        try output.print(allocator, "- {s}\n", .{value});
    }
    try output.append(allocator, '\n');
}

fn agentGuidance(status: ProposalStatus) []const []const u8 {
    return switch (status) {
        .approved => &.{
            "Approved proposal permits starting the exporter-boundary branch only.",
            "Cite source readiness source fixtures proposal checks verification commands and proposal phases.",
            "Do not infer live telemetry durable production writes CI gates non-NenDB adapters alternate renderers or mutation authority.",
        },
        .blocked => &.{
            "Blocked proposal must not start exporter boundary implementation.",
            "Repair readiness evidence proposal verification command evidence or authority boundaries first.",
            "Do not infer telemetry implementation approval from blocked proposal evidence.",
        },
    };
}

fn usage() []const u8 {
    return "usage: zig build causal-production-telemetry-implementation-proposal -- --from-readiness <readiness.json> approve|reject --reason <reason> [--by <actor>] [--policy <policy>] [--verified-command <command>]... [--out-prefix <path-prefix>]\n";
}

fn failUsage(err: anyerror) noreturn {
    std.debug.print("causal-production-telemetry-implementation-proposal error: {s}\n{s}", .{ @errorName(err), usage() });
    std.process.exit(2);
}

fn readRequiredArtifact(io: std.Io, allocator: std.mem.Allocator, path: []const u8) ![]const u8 {
    return std.Io.Dir.cwd().readFileAlloc(io, path, allocator, .limited(1024 * 1024)) catch |err| switch (err) {
        error.FileNotFound => error.MissingReadinessInput,
        else => return err,
    };
}

fn writeArtifact(io: std.Io, path: []const u8, contents: []const u8) !void {
    const slash = std.mem.lastIndexOfScalar(u8, path, '/') orelse return error.InvalidArtifactPath;
    const cwd = std.Io.Dir.cwd();
    try cwd.createDirPath(io, path[0..slash]);
    try cwd.writeFile(io, .{ .sub_path = path, .data = contents });
}

fn run(init: std.process.Init, options: Options) !void {
    const allocator = init.gpa;
    const source_readiness_json = try readRequiredArtifact(init.io, allocator, options.readiness_path);
    defer allocator.free(source_readiness_json);

    const reports = try formatReports(allocator, .{
        .options = options,
        .source_readiness_json = source_readiness_json,
    });
    defer reports.deinit(allocator);

    const paths = try outputPathsForOptions(allocator, options);
    defer paths.deinit(allocator);

    try writeArtifact(init.io, paths.json_path, reports.json);
    try writeArtifact(init.io, paths.text_path, reports.text);
    std.debug.print("{s}", .{reports.text});
}

const required_verification_commands: []const []const u8 = &.{
    "zig build causal-production-telemetry-readiness-review -- --from-fixtures ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures.json approve --reason \"fixtures reviewed for implementation proposal\" --verified-command \"zig build causal-production-telemetry-capture-fixtures -- validate --format json\" --verified-command \"zig build causal-schema-governance -- --format json\" --verified-command \"zig build causal-production-hardening-backlog -- --format json\" --verified-command \"zig build examples\" --verified-command \"zig build test\"",
    "zig build causal-schema-governance -- --format json",
    "zig build causal-production-hardening-backlog -- --format json",
    "zig build examples",
    "zig build test",
};

const proposal_phases: []const []const u8 = &.{
    "exporter-boundary: add exporter-neutral no-network boundary fixtures while live export remains disabled",
    "local-pipeline-fixtures: route approved fixture shapes through local in-process redaction and sampling checks",
    "nendb-retention-fixtures: map retained telemetry fixture records to NenDB node edge and retention records without production writes",
    "workbench-readonly-preview: expose proposal and fixture status in SolidJS zig-webui without live streaming or mutation",
    "ci-artifact-preview: emit advisory local artifacts CI may archive later without failing telemetry thresholds",
};

const implementation_gates: []const []const u8 = &.{
    "source readiness artifact is ready and approved",
    "all readiness checks remain pass",
    "proposal verification commands are recorded exactly",
    "no live exporter collector endpoint or network send is configured",
    "durable work remains NenDB-only future scope",
    "workbench work remains SolidJS inside webui-dev/zig-webui",
};

const non_goals: []const []const u8 = &.{
    "Live production telemetry ingestion",
    "OTLP serialization SDK setup collector delivery network calls or collector endpoint configuration",
    "Durable production writes",
    "Non-NenDB durable adapter work",
    "Cockroach adapter work",
    "Production capacity sizing autoscaling cost estimates or production load generation",
    "CI timing gates or telemetry gates",
    "Production dashboards multi-user hosting or dashboard streaming",
    "React or alternate renderer work",
    "Source config registry deployment rollout alert app or production mutation authority",
};

const blocked_claims: []const []const u8 = &.{
    "live-exporter-enabled",
    "otlp-collector-endpoint-configured",
    "durable-production-write-enabled",
    "non-nendb-durable-storage",
    "cockroach-adapter-work",
    "ci-telemetry-gate",
    "react-or-alternate-renderer",
    "production-capacity-claim",
    "mutation-authority-granted",
};

test "implementation proposal schema and authority constants are stable" {
    try std.testing.expectEqualStrings("zigeffect.causal.production-telemetry-implementation-proposal.v1", production_telemetry_implementation_proposal_schema);
    try std.testing.expectEqual(@as(u32, 1), production_telemetry_implementation_proposal_schema_version);
    try std.testing.expectEqualStrings("codex/zigeffect-causal-production-telemetry-implementation-proposal", source_branch);
    try std.testing.expectEqualStrings("start-production-telemetry-exporter-boundary", recommendation);
    try std.testing.expectEqualStrings("codex/zigeffect-causal-production-telemetry-exporter-boundary", next_branch_if_approved);
    try std.testing.expectEqualStrings("zigeffect.causal.production-telemetry-readiness-review.v1", readiness_schema);
    try std.testing.expectEqualStrings("causal-production-telemetry-implementation-proposal", generated_by);
    try std.testing.expect(!applied);
    try std.testing.expectEqualStrings("none", mutation_authority);
    try std.testing.expect(!production_telemetry_ingestion);
    try std.testing.expect(!live_exporter_enabled);
    try std.testing.expect(!durable_write_enabled);
    try std.testing.expect(!ci_gate_enabled);
}

test "parses approve proposal options with verified commands and output prefix" {
    var options = try parseOptions(std.testing.allocator, &.{
        "zigeffect-causal-production-telemetry-implementation-proposal",
        "--from-readiness",
        ".zig-cache/causal-artifacts/readiness.json",
        "approve",
        "--reason",
        "ready evidence reviewed",
        "--by",
        "codex",
        "--policy",
        "manual-production-telemetry-implementation-proposal",
        "--verified-command",
        "zig build test",
        "--out-prefix",
        ".zig-cache/causal-artifacts/custom-proposal",
    });
    defer options.deinit(std.testing.allocator);

    try std.testing.expectEqual(Decision.approve, options.decision);
    try std.testing.expectEqualStrings(".zig-cache/causal-artifacts/readiness.json", options.readiness_path);
    try std.testing.expectEqualStrings("ready evidence reviewed", options.reason);
    try std.testing.expectEqualStrings("codex", options.proposed_by);
    try std.testing.expectEqualStrings("manual-production-telemetry-implementation-proposal", options.policy);
    try std.testing.expectEqual(@as(usize, 1), options.verified_commands.len);
    try std.testing.expectEqualStrings("zig build test", options.verified_commands[0]);
    try std.testing.expectEqualStrings(".zig-cache/causal-artifacts/custom-proposal", options.out_prefix.?);
}

test "rejects missing readiness path decision and reason" {
    try std.testing.expectError(
        error.MissingReadinessPath,
        parseOptions(std.testing.allocator, &.{"zigeffect-causal-production-telemetry-implementation-proposal"}),
    );
    try std.testing.expectError(
        error.InvalidReadinessPath,
        parseOptions(std.testing.allocator, &.{ "zigeffect-causal-production-telemetry-implementation-proposal", "--from-readiness", "readiness.txt", "approve", "--reason", "reviewed" }),
    );
    try std.testing.expectError(
        error.MissingDecision,
        parseOptions(std.testing.allocator, &.{ "zigeffect-causal-production-telemetry-implementation-proposal", "--from-readiness", "readiness.json" }),
    );
    try std.testing.expectError(
        error.UnknownDecision,
        parseOptions(std.testing.allocator, &.{ "zigeffect-causal-production-telemetry-implementation-proposal", "--from-readiness", "readiness.json", "maybe", "--reason", "reviewed" }),
    );
    try std.testing.expectError(
        error.MissingReason,
        parseOptions(std.testing.allocator, &.{ "zigeffect-causal-production-telemetry-implementation-proposal", "--from-readiness", "readiness.json", "approve" }),
    );
}

test "derives implementation proposal output paths from readiness json path" {
    const derived = try outputPathsForOptions(std.testing.allocator, .{
        .readiness_path = ".zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review.json",
        .decision = .approve,
        .reason = "reviewed",
    });
    defer derived.deinit(std.testing.allocator);
    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal.json",
        derived.json_path,
    );
    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal.txt",
        derived.text_path,
    );

    const custom = try outputPathsForOptions(std.testing.allocator, .{
        .readiness_path = ".zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review.json",
        .decision = .approve,
        .reason = "reviewed",
        .out_prefix = ".zig-cache/causal-artifacts/custom-proposal",
    });
    defer custom.deinit(std.testing.allocator);
    try std.testing.expectEqualStrings(".zig-cache/causal-artifacts/custom-proposal.json", custom.json_path);
    try std.testing.expectEqualStrings(".zig-cache/causal-artifacts/custom-proposal.txt", custom.text_path);
}

test "approved and blocked proposal reports preserve non-live authority" {
    const approved = try formatReports(std.testing.allocator, .{
        .options = .{
            .readiness_path = "readiness.json",
            .decision = .approve,
            .reason = "ready evidence reviewed",
            .verified_commands = required_verification_commands,
        },
        .source_readiness_json = sample_readiness_json,
    });
    defer approved.deinit(std.testing.allocator);

    try std.testing.expect(std.mem.indexOf(u8, approved.json, "\"schema\": \"zigeffect.causal.production-telemetry-implementation-proposal.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, approved.json, "\"proposal_status\": \"approved\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, approved.json, "\"approved_for_next_branch\": true") != null);
    try std.testing.expect(std.mem.indexOf(u8, approved.json, "\"live_exporter_enabled\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, approved.text, "proposal_status: approved") != null);
    try std.testing.expect(std.mem.indexOf(u8, approved.text, "mutation_authority: none") != null);
    try std.testing.expect(std.mem.indexOf(u8, approved.text, "next branch if approved: codex/zigeffect-causal-production-telemetry-exporter-boundary") != null);

    const blocked = try formatReports(std.testing.allocator, .{
        .options = .{
            .readiness_path = "readiness.json",
            .decision = .reject,
            .reason = "negative proposal path",
        },
        .source_readiness_json = sample_readiness_json,
    });
    defer blocked.deinit(std.testing.allocator);

    try std.testing.expect(std.mem.indexOf(u8, blocked.json, "\"proposal_status\": \"blocked\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, blocked.json, "\"approved_for_next_branch\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, blocked.text, "proposal_status: blocked") != null);
}

const sample_readiness_json =
    \\{
    \\  "schema": "zigeffect.causal.production-telemetry-readiness-review.v1",
    \\  "schema_version": 1,
    \\  "source_fixtures": "../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures.json",
    \\  "decision": "approve",
    \\  "readiness_status": "ready",
    \\  "ready_for_implementation_proposal": true,
    \\  "reviewed_by": "local-reviewer",
    \\  "policy": "manual-production-telemetry-readiness",
    \\  "reason": "fixtures reviewed for implementation proposal",
    \\  "applied": false,
    \\  "mutation_authority": "none",
    \\  "production_telemetry_ingestion": false,
    \\  "live_exporter_enabled": false,
    \\  "durable_write_enabled": false,
    \\  "ci_gate_enabled": false,
    \\  "fixture_summary": { "source_contract_count": 7, "positive_fixture_count": 6, "negative_fixture_count": 14, "validation_check_count": 8 },
    \\  "checks": [
    \\    { "name": "fixture-schema", "status": "pass", "detail": "fixture schema is supported" },
    \\    { "name": "fixture-status", "status": "pass", "detail": "fixture artifact remains fixtures-only" },
    \\    { "name": "reviewer-decision", "status": "pass", "detail": "reviewer supplied a decision and reason" },
    \\    { "name": "decision-approved", "status": "pass", "detail": "reviewer decision must approve readiness" },
    \\    { "name": "authority-boundary", "status": "pass", "detail": "applied mutation telemetry exporter durable and CI authority are all disabled" },
    \\    { "name": "source-contracts-present", "status": "pass", "detail": "fixture catalog cites required source contracts" },
    \\    { "name": "positive-fixture-coverage", "status": "pass", "detail": "positive fixtures cover required telemetry surfaces" },
    \\    { "name": "negative-fixture-coverage", "status": "pass", "detail": "negative fixtures reject forbidden telemetry claims" },
    \\    { "name": "validation-checks-passed", "status": "pass", "detail": "all fixture validation checks passed" },
    \\    { "name": "nendb-only-retention", "status": "pass", "detail": "durable direction remains NenDB-compatible only" },
    \\    { "name": "solid-webui-direction", "status": "pass", "detail": "alternate renderers remain blocked" },
    \\    { "name": "required-verification-recorded", "status": "pass", "detail": "reviewer recorded every required verification command" }
    \\  ],
    \\  "required_verification_commands": [
    \\    "zig build causal-production-telemetry-capture-fixtures -- validate --format json",
    \\    "zig build causal-schema-governance -- --format json",
    \\    "zig build causal-production-hardening-backlog -- --format json",
    \\    "zig build examples",
    \\    "zig build test"
    \\  ],
    \\  "verified_commands": [
    \\    "zig build causal-production-telemetry-capture-fixtures -- validate --format json",
    \\    "zig build causal-schema-governance -- --format json",
    \\    "zig build causal-production-hardening-backlog -- --format json",
    \\    "zig build examples",
    \\    "zig build test"
    \\  ],
    \\  "implementation_proposal_steps": [
    \\    "Start a reviewed production telemetry implementation proposal branch."
    \\  ],
    \\  "readiness_guardrails": [
    \\    "Readiness does not ingest production telemetry configure exporters send OTLP write durable production storage or fail CI telemetry gates."
    \\  ]
    \\}
;
