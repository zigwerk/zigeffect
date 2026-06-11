const std = @import("std");

pub const app_facing_production_integration_boundary_schema = "zigeffect.causal.app-facing-production-integration-boundary.v1";
pub const app_facing_production_integration_boundary_schema_version: u32 = 1;
pub const source_branch = "codex/zigeffect-causal-app-facing-production-integration-boundary";
pub const recommendation = "start-app-facing-production-integration-local-fixtures";
pub const next_branch_if_approved = "codex/zigeffect-causal-app-facing-production-integration-local-fixtures";

const proposal_schema = "zigeffect.causal.app-facing-production-integration-implementation-proposal.v1";
const generated_by = "causal-app-facing-production-integration-boundary";
const applied = false;
const mutation_authority = "none";
const production_telemetry_ingestion = false;
const live_exporter_enabled = false;
const network_send_enabled = false;
const collector_endpoint_configured = false;
const otlp_serialization_enabled = false;
const durable_write_enabled = false;
const app_mutation_enabled = false;
const ci_gate_enabled = false;
const raw_payload_capture_enabled = false;
const app_config_write_enabled = false;
const app_data_write_enabled = false;
const deployment_mutation_enabled = false;
const nendb_write_enabled = false;

const Decision = enum { approve, reject };
const BoundaryStatus = enum { approved, blocked };
const CheckStatus = enum { pass, fail };

const Options = struct {
    proposal_path: []const u8,
    decision: Decision,
    reviewed_by: []const u8 = "local-boundary-reviewer",
    policy: []const u8 = "manual-app-facing-production-integration-boundary",
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

const BoundaryInput = struct {
    options: Options,
    source_proposal_json: []const u8,
};

const BoundaryReports = struct {
    json: []const u8,
    text: []const u8,

    fn deinit(self: BoundaryReports, allocator: std.mem.Allocator) void {
        allocator.free(self.json);
        allocator.free(self.text);
    }
};

const ProposalCheck = struct {
    name: []const u8,
    status: []const u8,
    detail: []const u8 = "",
};

const ProposalSummary = struct {
    source_contract_count: usize = 0,
    positive_fixture_count: usize = 0,
    negative_fixture_count: usize = 0,
    validation_check_count: usize = 0,
};

const ProposalArtifact = struct {
    schema: []const u8,
    schema_version: u32,
    source_readiness: []const u8 = "",
    source_fixtures: []const u8 = "",
    decision: []const u8,
    proposal_status: []const u8,
    approved_for_next_branch: bool,
    applied: bool,
    mutation_authority: []const u8,
    production_telemetry_ingestion: bool,
    live_exporter_enabled: bool,
    durable_write_enabled: bool,
    app_mutation_enabled: bool,
    ci_gate_enabled: bool,
    readiness_summary: ProposalSummary = .{},
    checks: []const ProposalCheck = &.{},
    proposal_phases: []const []const u8 = &.{},
    implementation_gates: []const []const u8 = &.{},
    non_goals: []const []const u8 = &.{},
    blocked_claims: []const []const u8 = &.{},
    required_verification_commands: []const []const u8 = &.{},
    verified_commands: []const []const u8 = &.{},
};

const BoundaryCheck = struct {
    name: []const u8,
    status: CheckStatus,
    detail: []const u8,
};

const BoundaryResult = struct {
    status: BoundaryStatus,
    approved_for_next_branch: bool,
    checks: []const BoundaryCheck,
    proposal_summary: ProposalSummary,
    source_readiness: []const u8,
    source_fixtures: []const u8,

    fn deinit(self: BoundaryResult, allocator: std.mem.Allocator) void {
        if (self.checks.len > 0) allocator.free(self.checks);
    }
};

fn parseOptions(allocator: std.mem.Allocator, args: []const []const u8) !Options {
    if (args.len < 2) return error.MissingProposalPath;
    if (!std.mem.eql(u8, args[1], "--from-proposal")) return error.UnknownFlag;
    if (args.len < 3) return error.MissingProposalPath;
    const proposal_path = args[2];
    if (!std.mem.endsWith(u8, proposal_path, ".json")) return error.InvalidProposalPath;
    if (args.len < 4) return error.MissingDecision;
    const decision = try parseDecision(args[3]);

    var reviewed_by: []const u8 = "local-boundary-reviewer";
    var policy: []const u8 = "manual-app-facing-production-integration-boundary";
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
            reviewed_by = value;
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
        if (!std.mem.endsWith(u8, options.proposal_path, ".json")) return error.InvalidProposalPath;
        const base = options.proposal_path[0 .. options.proposal_path.len - ".json".len];
        break :blk try std.fmt.allocPrint(allocator, "{s}-app-facing-boundary", .{base});
    };
    defer allocator.free(prefix);

    return .{
        .json_path = try std.fmt.allocPrint(allocator, "{s}.json", .{prefix}),
        .text_path = try std.fmt.allocPrint(allocator, "{s}.txt", .{prefix}),
    };
}

fn formatReports(allocator: std.mem.Allocator, input: BoundaryInput) !BoundaryReports {
    var parsed = try std.json.parseFromSlice(ProposalArtifact, allocator, input.source_proposal_json, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();

    const result = try evaluateBoundary(allocator, input.options, parsed.value);
    defer result.deinit(allocator);

    const json = try formatBoundaryJson(allocator, input.options, result);
    errdefer allocator.free(json);
    const text = try formatBoundaryText(allocator, input.options, result);
    errdefer allocator.free(text);

    return .{ .json = json, .text = text };
}

pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    const options = parseOptions(init.gpa, args) catch |err| failUsage(err);
    defer options.deinit(init.gpa);
    run(init, options) catch |err| switch (err) {
        error.MissingProposalInput => failUsage(err),
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

fn boundaryStatusText(status: BoundaryStatus) []const u8 {
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

fn evaluateBoundary(
    allocator: std.mem.Allocator,
    options: Options,
    proposal: ProposalArtifact,
) !BoundaryResult {
    var checks = std.ArrayList(BoundaryCheck).empty;
    errdefer checks.deinit(allocator);

    try appendCheck(allocator, &checks, "proposal-schema", if (std.mem.eql(u8, proposal.schema, proposal_schema) and proposal.schema_version == 1) .pass else .fail, "source proposal schema is supported");
    try appendCheck(allocator, &checks, "proposal-status", if (std.mem.eql(u8, proposal.proposal_status, "approved") and proposal.approved_for_next_branch) .pass else .fail, "source proposal is approved for app-facing integration boundary work");
    try appendCheck(allocator, &checks, "proposal-decision-approved", if (std.mem.eql(u8, proposal.decision, "approve")) .pass else .fail, "source proposal decision approved the handoff");
    try appendCheck(allocator, &checks, "boundary-decision", if (options.reason.len > 0) .pass else .fail, "boundary decision includes a reason");
    try appendCheck(allocator, &checks, "decision-approved", if (options.decision == .approve) .pass else .fail, "boundary decision must approve app-facing local fixture handoff");
    try appendCheck(allocator, &checks, "authority-boundary", if (authorityBoundaryIntact(proposal)) .pass else .fail, "source proposal and app-facing integration boundary authority fields remain disabled");
    try appendCheck(allocator, &checks, "source-chain-linked", if (sourceChainLinked(proposal)) .pass else .fail, "proposal links readiness and fixture JSON artifacts");
    try appendCheck(allocator, &checks, "proposal-checks-passed", if (proposalChecksPassed(proposal.checks)) .pass else .fail, "all required source proposal checks passed");
    try appendCheck(allocator, &checks, "proposal-phase-handoff", if (proposalPhaseHandoff(proposal.proposal_phases)) .pass else .fail, "proposal includes app runtime, agent query, and NenDB handoff phases");
    try appendCheck(allocator, &checks, "proposal-verification-recorded", if (proposalVerificationRecorded(proposal)) .pass else .fail, "source proposal recorded required verification command evidence");
    try appendCheck(allocator, &checks, "boundary-verification-recorded", if (verifiedCommandsContainAll(options.verified_commands, required_verification_commands)) .pass else .fail, "boundary review recorded every required verification command");
    try appendCheck(allocator, &checks, "app-runtime-ref-boundary", if (appRuntimeRefBoundary()) .pass else .fail, "app runtime contract uses refs only and blocks raw payload capture");
    try appendCheck(allocator, &checks, "agent-query-projection-boundary", if (agentQueryProjectionBoundary()) .pass else .fail, "agent query projection remains bounded to redacted trace evidence");
    try appendCheck(allocator, &checks, "nendb-handoff-boundary", if (nendbHandoffBoundary()) .pass else .fail, "NenDB handoff remains reference-only with no production writes");
    try appendCheck(allocator, &checks, "audit-remediation-boundary", if (auditRemediationBoundary()) .pass else .fail, "audit remediation evidence remains review-only and cannot prove mutation");
    try appendCheck(allocator, &checks, "no-production-mutation-boundary", if (noProductionMutationBoundary()) .pass else .fail, "app config, app data, deployment, NenDB write, and app mutation authority stay disabled");
    try appendCheck(allocator, &checks, "nendb-only-scope", if (nendbOnlyScope()) .pass else .fail, "durable direction remains future NenDB-only scope");
    try appendCheck(allocator, &checks, "solid-webui-scope", if (solidWebuiScope()) .pass else .fail, "workbench direction remains SolidJS inside webui-dev/zig-webui");

    const check_slice = try checks.toOwnedSlice(allocator);
    errdefer allocator.free(check_slice);
    const approved = allChecksPassed(check_slice);
    return .{
        .status = if (approved) .approved else .blocked,
        .approved_for_next_branch = approved,
        .checks = check_slice,
        .proposal_summary = proposal.readiness_summary,
        .source_readiness = proposal.source_readiness,
        .source_fixtures = proposal.source_fixtures,
    };
}

fn appendCheck(
    allocator: std.mem.Allocator,
    checks: *std.ArrayList(BoundaryCheck),
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

fn authorityBoundaryIntact(proposal: ProposalArtifact) bool {
    return !proposal.applied and
        std.mem.eql(u8, proposal.mutation_authority, "none") and
        !proposal.production_telemetry_ingestion and
        !proposal.live_exporter_enabled and
        !proposal.durable_write_enabled and
        !proposal.app_mutation_enabled and
        !proposal.ci_gate_enabled and
        !applied and
        std.mem.eql(u8, mutation_authority, "none") and
        !production_telemetry_ingestion and
        !live_exporter_enabled and
        !network_send_enabled and
        !collector_endpoint_configured and
        !otlp_serialization_enabled and
        !durable_write_enabled and
        !app_mutation_enabled and
        !ci_gate_enabled and
        !raw_payload_capture_enabled and
        !app_config_write_enabled and
        !app_data_write_enabled and
        !deployment_mutation_enabled and
        !nendb_write_enabled;
}

fn appRuntimeRefBoundary() bool {
    return containsString(app_boundary_contract, "source_contract=app-runtime") and
        containsString(app_boundary_contract, "trace_ref_state=ref-only") and
        containsString(app_boundary_contract, "raw_payload_state=blocked") and
        containsString(app_boundary_contract, "app_mutation_state=disabled") and
        !raw_payload_capture_enabled and
        !app_mutation_enabled;
}

fn agentQueryProjectionBoundary() bool {
    return containsString(app_boundary_contract, "agent_query_state=bounded-trace-data-only") and
        containsString(local_projection_fixtures, "agent-query-bounded-projection-boundary");
}

fn nendbHandoffBoundary() bool {
    return containsString(app_boundary_contract, "nendb_handoff_state=ref-only-no-production-write") and
        containsString(local_projection_fixtures, "nendb-history-handoff-ref-boundary") and
        !nendb_write_enabled;
}

fn auditRemediationBoundary() bool {
    return containsString(app_boundary_contract, "audit_compare_state=evidence-only-not-mutation-proof") and
        containsString(app_boundary_contract, "remediation_governance_state=handoff-only") and
        containsString(local_projection_fixtures, "audit-remediation-review-link-boundary");
}

fn noProductionMutationBoundary() bool {
    return !app_mutation_enabled and
        !raw_payload_capture_enabled and
        !app_config_write_enabled and
        !app_data_write_enabled and
        !deployment_mutation_enabled and
        !nendb_write_enabled and
        containsString(blocked_claims, "app-config-write") and
        containsString(blocked_claims, "app-data-write") and
        containsString(blocked_claims, "deployment-mutation") and
        containsString(blocked_claims, "nendb-production-write") and
        containsString(blocked_claims, "app-remediation-auto-apply");
}

fn sourceChainLinked(proposal: ProposalArtifact) bool {
    return proposal.source_readiness.len > 0 and
        proposal.source_fixtures.len > 0 and
        std.mem.endsWith(u8, proposal.source_readiness, ".json") and
        std.mem.endsWith(u8, proposal.source_fixtures, ".json");
}

fn proposalChecksPassed(checks: []const ProposalCheck) bool {
    const required = [_][]const u8{
        "readiness-schema",
        "readiness-status",
        "readiness-decision-approved",
        "proposal-decision",
        "decision-approved",
        "authority-boundary",
        "source-fixtures-linked",
        "readiness-checks-passed",
        "readiness-verification-recorded",
        "proposal-verification-recorded",
        "nendb-only-scope",
        "solid-webui-scope",
        "app-runtime-scope",
        "agent-query-scope",
    };
    for (required) |name| {
        if (!hasProposalCheck(checks, name, "pass")) return false;
    }
    for (checks) |check| {
        if (!std.mem.eql(u8, check.status, "pass")) return false;
    }
    return true;
}

fn hasProposalCheck(checks: []const ProposalCheck, name: []const u8, status: []const u8) bool {
    for (checks) |check| {
        if (std.mem.eql(u8, check.name, name) and std.mem.eql(u8, check.status, status)) return true;
    }
    return false;
}

fn proposalPhaseHandoff(phases: []const []const u8) bool {
    return containsString(phases, "app-runtime-boundary") and
        containsString(phases, "agent-query-projection") and
        containsString(phases, "nendb-history-handoff");
}

fn proposalVerificationRecorded(proposal: ProposalArtifact) bool {
    return proposal.required_verification_commands.len > 0 and
        verifiedCommandsContainAll(proposal.verified_commands, proposal.required_verification_commands);
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

fn allChecksPassed(checks: []const BoundaryCheck) bool {
    for (checks) |check| {
        if (check.status != .pass) return false;
    }
    return true;
}

fn formatBoundaryJson(
    allocator: std.mem.Allocator,
    options: Options,
    result: BoundaryResult,
) ![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "{\n");
    try output.appendSlice(allocator, "  \"schema\": ");
    try appendJsonString(allocator, &output, app_facing_production_integration_boundary_schema);
    try output.appendSlice(allocator, ",\n  \"schema_version\": 1,\n");
    try output.appendSlice(allocator, "  \"source_proposal\": ");
    try appendJsonString(allocator, &output, options.proposal_path);
    try output.appendSlice(allocator, ",\n  \"source_readiness\": ");
    try appendJsonString(allocator, &output, result.source_readiness);
    try output.appendSlice(allocator, ",\n  \"source_fixtures\": ");
    try appendJsonString(allocator, &output, result.source_fixtures);
    try output.appendSlice(allocator, ",\n  \"decision\": ");
    try appendJsonString(allocator, &output, decisionText(options.decision));
    try output.appendSlice(allocator, ",\n  \"boundary_status\": ");
    try appendJsonString(allocator, &output, boundaryStatusText(result.status));
    try output.print(allocator, ",\n  \"approved_for_next_branch\": {},\n", .{result.approved_for_next_branch});
    try output.appendSlice(allocator, "  \"reviewed_by\": ");
    try appendJsonString(allocator, &output, options.reviewed_by);
    try output.appendSlice(allocator, ",\n  \"policy\": ");
    try appendJsonString(allocator, &output, options.policy);
    try output.appendSlice(allocator, ",\n  \"reason\": ");
    try appendJsonString(allocator, &output, options.reason);
    try output.print(allocator, ",\n  \"applied\": {},\n", .{applied});
    try output.appendSlice(allocator, "  \"mutation_authority\": ");
    try appendJsonString(allocator, &output, mutation_authority);
    try output.print(allocator, ",\n  \"production_telemetry_ingestion\": {},\n", .{production_telemetry_ingestion});
    try output.print(allocator, "  \"live_exporter_enabled\": {},\n", .{live_exporter_enabled});
    try output.print(allocator, "  \"network_send_enabled\": {},\n", .{network_send_enabled});
    try output.print(allocator, "  \"collector_endpoint_configured\": {},\n", .{collector_endpoint_configured});
    try output.print(allocator, "  \"otlp_serialization_enabled\": {},\n", .{otlp_serialization_enabled});
    try output.print(allocator, "  \"durable_write_enabled\": {},\n", .{durable_write_enabled});
    try output.print(allocator, "  \"app_mutation_enabled\": {},\n", .{app_mutation_enabled});
    try output.print(allocator, "  \"ci_gate_enabled\": {},\n", .{ci_gate_enabled});
    try output.print(allocator, "  \"raw_payload_capture_enabled\": {},\n", .{raw_payload_capture_enabled});
    try output.print(allocator, "  \"app_config_write_enabled\": {},\n", .{app_config_write_enabled});
    try output.print(allocator, "  \"app_data_write_enabled\": {},\n", .{app_data_write_enabled});
    try output.print(allocator, "  \"deployment_mutation_enabled\": {},\n", .{deployment_mutation_enabled});
    try output.print(allocator, "  \"nendb_write_enabled\": {},\n", .{nendb_write_enabled});
    try output.appendSlice(allocator, "  \"source_branch\": ");
    try appendJsonString(allocator, &output, source_branch);
    try output.appendSlice(allocator, ",\n  \"recommendation\": ");
    try appendJsonString(allocator, &output, recommendation);
    try output.appendSlice(allocator, ",\n  \"next_branch_if_approved\": ");
    try appendJsonString(allocator, &output, next_branch_if_approved);
    try output.appendSlice(allocator, ",\n  \"proposal_summary\": ");
    try appendProposalSummaryJson(allocator, &output, result.proposal_summary);
    try output.appendSlice(allocator, ",\n  \"checks\": ");
    try appendChecksJson(allocator, &output, result.checks);
    try output.appendSlice(allocator, ",\n  \"app_boundary_contract\": ");
    try appendStringArray(allocator, &output, app_boundary_contract);
    try output.appendSlice(allocator, ",\n  \"local_projection_fixtures\": ");
    try appendStringArray(allocator, &output, local_projection_fixtures);
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

fn formatBoundaryText(
    allocator: std.mem.Allocator,
    options: Options,
    result: BoundaryResult,
) ![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "zigeffect app-facing production integration boundary\n");
    try output.print(allocator, "schema: {s}\n", .{app_facing_production_integration_boundary_schema});
    try output.print(allocator, "source proposal: {s}\n", .{options.proposal_path});
    try output.print(allocator, "source readiness: {s}\n", .{result.source_readiness});
    try output.print(allocator, "source fixtures: {s}\n", .{result.source_fixtures});
    try output.print(allocator, "decision: {s}\n", .{decisionText(options.decision)});
    try output.print(allocator, "boundary_status: {s}\n", .{boundaryStatusText(result.status)});
    try output.print(allocator, "approved_for_next_branch: {}\n", .{result.approved_for_next_branch});
    try output.print(allocator, "reviewed_by: {s}\n", .{options.reviewed_by});
    try output.print(allocator, "policy: {s}\n", .{options.policy});
    try output.print(allocator, "reason: {s}\n", .{options.reason});
    try output.print(allocator, "applied: {}\n", .{applied});
    try output.print(allocator, "mutation_authority: {s}\n", .{mutation_authority});
    try output.print(allocator, "production telemetry ingestion: {}\n", .{production_telemetry_ingestion});
    try output.print(allocator, "live exporter enabled: {}\n", .{live_exporter_enabled});
    try output.print(allocator, "network send enabled: {}\n", .{network_send_enabled});
    try output.print(allocator, "collector endpoint configured: {}\n", .{collector_endpoint_configured});
    try output.print(allocator, "otlp serialization enabled: {}\n", .{otlp_serialization_enabled});
    try output.print(allocator, "durable write enabled: {}\n", .{durable_write_enabled});
    try output.print(allocator, "app mutation enabled: {}\n", .{app_mutation_enabled});
    try output.print(allocator, "ci gate enabled: {}\n", .{ci_gate_enabled});
    try output.print(allocator, "raw payload capture enabled: {}\n", .{raw_payload_capture_enabled});
    try output.print(allocator, "app config write enabled: {}\n", .{app_config_write_enabled});
    try output.print(allocator, "app data write enabled: {}\n", .{app_data_write_enabled});
    try output.print(allocator, "deployment mutation enabled: {}\n", .{deployment_mutation_enabled});
    try output.print(allocator, "nendb write enabled: {}\n", .{nendb_write_enabled});
    try output.print(allocator, "generated by: {s}\n", .{generated_by});
    try output.print(allocator, "source branch: {s}\n", .{source_branch});
    try output.print(allocator, "recommendation: {s}\n", .{recommendation});
    try output.print(allocator, "next branch if approved: {s}\n\n", .{next_branch_if_approved});

    try output.appendSlice(allocator, "proposal summary:\n");
    try output.print(allocator, "- source contracts: {d}\n", .{result.proposal_summary.source_contract_count});
    try output.print(allocator, "- positive fixtures: {d}\n", .{result.proposal_summary.positive_fixture_count});
    try output.print(allocator, "- negative fixtures: {d}\n", .{result.proposal_summary.negative_fixture_count});
    try output.print(allocator, "- validation checks: {d}\n\n", .{result.proposal_summary.validation_check_count});

    try output.appendSlice(allocator, "checks:\n");
    for (result.checks) |check| {
        try output.print(allocator, "- {s}: {s} - {s}\n", .{ check.name, checkStatusText(check.status), check.detail });
    }
    try output.append(allocator, '\n');

    try appendTextList(allocator, &output, "app-facing integration boundary contract", app_boundary_contract);
    try appendTextList(allocator, &output, "local projection fixtures", local_projection_fixtures);
    try appendTextList(allocator, &output, "implementation gates", implementation_gates);
    try appendTextList(allocator, &output, "non-goals", non_goals);
    try appendTextList(allocator, &output, "blocked claims", blocked_claims);
    try appendTextList(allocator, &output, "required verification commands", required_verification_commands);
    try appendTextList(allocator, &output, "verified commands", options.verified_commands);
    try appendTextList(allocator, &output, "agent guidance", agentGuidance(result.status));

    return output.toOwnedSlice(allocator);
}

fn appendProposalSummaryJson(allocator: std.mem.Allocator, output: *std.ArrayList(u8), summary: ProposalSummary) !void {
    try output.print(
        allocator,
        "{{ \"source_contract_count\": {d}, \"positive_fixture_count\": {d}, \"negative_fixture_count\": {d}, \"validation_check_count\": {d} }}",
        .{ summary.source_contract_count, summary.positive_fixture_count, summary.negative_fixture_count, summary.validation_check_count },
    );
}

fn appendChecksJson(allocator: std.mem.Allocator, output: *std.ArrayList(u8), checks: []const BoundaryCheck) !void {
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

fn agentGuidance(status: BoundaryStatus) []const []const u8 {
    return switch (status) {
        .approved => &.{
            "Approved boundary permits starting the app-facing local fixtures branch only.",
            "Cite source proposal readiness fixtures checks verification commands app boundary contract and local projection fixture labels.",
            "Do not infer app mutation raw payload capture app config writes app data writes deployment mutation NenDB production writes CI gates non-NenDB adapters alternate renderers or applied=true.",
        },
        .blocked => &.{
            "Blocked boundary must not start app-facing local fixtures.",
            "Repair source proposal evidence boundary verification command evidence app runtime refs agent-query projection NenDB handoff or no-production-mutation boundaries first.",
            "Do not infer app integration implementation approval from blocked boundary evidence.",
        },
    };
}

fn usage() []const u8 {
    return "usage: zig build causal-app-facing-production-integration-boundary -- --from-proposal <proposal.json> approve|reject --reason <reason> [--by <actor>] [--policy <policy>] [--verified-command <command>]... [--out-prefix <path-prefix>]\n";
}

fn failUsage(err: anyerror) noreturn {
    std.debug.print("causal-app-facing-production-integration-boundary error: {s}\n{s}", .{ @errorName(err), usage() });
    std.process.exit(2);
}

fn readRequiredArtifact(io: std.Io, allocator: std.mem.Allocator, path: []const u8) ![]const u8 {
    return std.Io.Dir.cwd().readFileAlloc(io, path, allocator, .limited(1024 * 1024)) catch |err| switch (err) {
        error.FileNotFound => error.MissingProposalInput,
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
    const source_proposal_json = try readRequiredArtifact(init.io, allocator, options.proposal_path);
    defer allocator.free(source_proposal_json);

    const reports = try formatReports(allocator, .{
        .options = options,
        .source_proposal_json = source_proposal_json,
    });
    defer reports.deinit(allocator);

    const paths = try outputPathsForOptions(allocator, options);
    defer paths.deinit(allocator);

    try writeArtifact(init.io, paths.json_path, reports.json);
    try writeArtifact(init.io, paths.text_path, reports.text);
    std.debug.print("{s}", .{reports.text});
}

const required_verification_commands: []const []const u8 = &.{
    "zig build causal-app-facing-production-integration-implementation-proposal -- --from-readiness ../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures-readiness-review.json approve --reason \"ready evidence reviewed for app-facing integration planning\" --verified-command \"zig build causal-app-facing-production-integration-readiness-review -- --from-fixtures ../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures.json approve --reason \\\"fixtures reviewed for implementation proposal\\\" --verified-command \\\"zig build causal-app-facing-production-integration-fixtures -- validate --format json\\\" --verified-command \\\"zig build causal-schema-governance -- --format json\\\" --verified-command \\\"zig build causal-production-hardening-backlog -- --format json\\\" --verified-command \\\"zig build examples\\\" --verified-command \\\"zig build test\\\"\" --verified-command \"zig build causal-schema-governance -- --format json\" --verified-command \"zig build causal-production-hardening-backlog -- --format json\" --verified-command \"zig build examples\" --verified-command \"zig build test\"",
    "zig build causal-schema-governance -- --format json",
    "zig build causal-production-hardening-backlog -- --format json",
    "zig build examples",
    "zig build test",
};

const app_boundary_contract: []const []const u8 = &.{
    "boundary_id=app-facing-production-integration-guarded",
    "source_contract=app-runtime",
    "trace_ref_state=ref-only",
    "raw_payload_state=blocked",
    "app_mutation_state=disabled",
    "agent_query_state=bounded-trace-data-only",
    "nendb_handoff_state=ref-only-no-production-write",
    "audit_compare_state=evidence-only-not-mutation-proof",
    "remediation_governance_state=handoff-only",
    "solid_webui_state=read-only-preview-only",
    "ci_state=advisory-artifacts-only",
};

const local_projection_fixtures: []const []const u8 = &.{
    "worker-request-runtime-ref-boundary",
    "background-job-runtime-ref-boundary",
    "agent-query-bounded-projection-boundary",
    "nendb-history-handoff-ref-boundary",
    "audit-remediation-review-link-boundary",
    "solid-webui-readonly-handoff-boundary",
};

const implementation_gates: []const []const u8 = &.{
    "source implementation proposal artifact is approved",
    "all source proposal checks and verification commands remain pass",
    "app runtime boundary uses refs only and no raw payload capture",
    "agent query projection remains bounded trace_data and next-query hints only",
    "NenDB handoff remains ref-only with no durable production write",
    "audit/remediation evidence cannot prove mutation or application",
    "app source config data deployment rollback and operational mutation remain disabled",
    "SolidJS workbench direction remains inside webui-dev/zig-webui",
    "local fixtures must be reviewed before app-facing integration implementation",
};

const non_goals: []const []const u8 = &.{
    "App runtime mutation authority",
    "Raw app payload capture",
    "Live production telemetry ingestion",
    "Durable production writes",
    "Non-NenDB durable adapter work",
    "Cockroach adapter work",
    "CI enforcement gates or required status checks",
    "Production dashboards streaming hosted workbench or live app view",
    "React or alternate renderer work",
    "App config app data deployment rollback registry health fixed deployed integrated or applied claim",
};

const blocked_claims: []const []const u8 = &.{
    "app-mutation-enabled",
    "raw-payload-capture-enabled",
    "app-config-write",
    "app-data-write",
    "deployment-mutation",
    "nendb-production-write",
    "audit-chain-compare-as-mutation-proof",
    "app-remediation-auto-apply",
    "live-exporter-enabled",
    "durable-production-write-enabled",
    "non-nendb-durable-storage",
    "cockroach-adapter-work",
    "ci-enforcement-gate",
    "react-or-alternate-renderer",
    "mutation-authority-granted",
};

test "app-facing integration boundary schema and authority constants are stable" {
    try std.testing.expectEqualStrings("zigeffect.causal.app-facing-production-integration-boundary.v1", app_facing_production_integration_boundary_schema);
    try std.testing.expectEqual(@as(u32, 1), app_facing_production_integration_boundary_schema_version);
    try std.testing.expectEqualStrings("codex/zigeffect-causal-app-facing-production-integration-boundary", source_branch);
    try std.testing.expectEqualStrings("start-app-facing-production-integration-local-fixtures", recommendation);
    try std.testing.expectEqualStrings("codex/zigeffect-causal-app-facing-production-integration-local-fixtures", next_branch_if_approved);
    try std.testing.expectEqualStrings("zigeffect.causal.app-facing-production-integration-implementation-proposal.v1", proposal_schema);
    try std.testing.expectEqualStrings("causal-app-facing-production-integration-boundary", generated_by);
    try std.testing.expect(!applied);
    try std.testing.expectEqualStrings("none", mutation_authority);
    try std.testing.expect(!production_telemetry_ingestion);
    try std.testing.expect(!live_exporter_enabled);
    try std.testing.expect(!network_send_enabled);
    try std.testing.expect(!collector_endpoint_configured);
    try std.testing.expect(!otlp_serialization_enabled);
    try std.testing.expect(!durable_write_enabled);
    try std.testing.expect(!app_mutation_enabled);
    try std.testing.expect(!ci_gate_enabled);
    try std.testing.expect(!raw_payload_capture_enabled);
    try std.testing.expect(!app_config_write_enabled);
    try std.testing.expect(!app_data_write_enabled);
    try std.testing.expect(!deployment_mutation_enabled);
    try std.testing.expect(!nendb_write_enabled);
    try std.testing.expect(containsString(app_boundary_contract, "trace_ref_state=ref-only"));
    try std.testing.expect(containsString(app_boundary_contract, "raw_payload_state=blocked"));
    try std.testing.expect(containsString(local_projection_fixtures, "agent-query-bounded-projection-boundary"));
}

test "parses approve boundary options with verified commands and output prefix" {
    var options = try parseOptions(std.testing.allocator, &.{
        "zigeffect-causal-app-facing-production-integration-boundary",
        "--from-proposal",
        ".zig-cache/causal-artifacts/proposal.json",
        "approve",
        "--reason",
        "proposal evidence reviewed",
        "--by",
        "codex",
        "--policy",
        "manual-app-facing-production-integration-boundary",
        "--verified-command",
        "zig build test",
        "--out-prefix",
        ".zig-cache/causal-artifacts/custom-boundary",
    });
    defer options.deinit(std.testing.allocator);

    try std.testing.expectEqual(Decision.approve, options.decision);
    try std.testing.expectEqualStrings(".zig-cache/causal-artifacts/proposal.json", options.proposal_path);
    try std.testing.expectEqualStrings("proposal evidence reviewed", options.reason);
    try std.testing.expectEqualStrings("codex", options.reviewed_by);
    try std.testing.expectEqualStrings("manual-app-facing-production-integration-boundary", options.policy);
    try std.testing.expectEqual(@as(usize, 1), options.verified_commands.len);
    try std.testing.expectEqualStrings("zig build test", options.verified_commands[0]);
    try std.testing.expectEqualStrings(".zig-cache/causal-artifacts/custom-boundary", options.out_prefix.?);
}

test "rejects missing proposal path decision and reason" {
    try std.testing.expectError(
        error.MissingProposalPath,
        parseOptions(std.testing.allocator, &.{"zigeffect-causal-app-facing-production-integration-boundary"}),
    );
    try std.testing.expectError(
        error.InvalidProposalPath,
        parseOptions(std.testing.allocator, &.{ "zigeffect-causal-app-facing-production-integration-boundary", "--from-proposal", "proposal.txt", "approve", "--reason", "reviewed" }),
    );
    try std.testing.expectError(
        error.MissingDecision,
        parseOptions(std.testing.allocator, &.{ "zigeffect-causal-app-facing-production-integration-boundary", "--from-proposal", "proposal.json" }),
    );
    try std.testing.expectError(
        error.UnknownDecision,
        parseOptions(std.testing.allocator, &.{ "zigeffect-causal-app-facing-production-integration-boundary", "--from-proposal", "proposal.json", "maybe", "--reason", "reviewed" }),
    );
    try std.testing.expectError(
        error.MissingReason,
        parseOptions(std.testing.allocator, &.{ "zigeffect-causal-app-facing-production-integration-boundary", "--from-proposal", "proposal.json", "approve" }),
    );
}

test "derives app-facing integration boundary output paths from proposal json path" {
    const derived = try outputPathsForOptions(std.testing.allocator, .{
        .proposal_path = ".zig-cache/causal-artifacts/app-facing-production-integration-fixtures-readiness-review-implementation-proposal.json",
        .decision = .approve,
        .reason = "reviewed",
    });
    defer derived.deinit(std.testing.allocator);
    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/app-facing-production-integration-fixtures-readiness-review-implementation-proposal-app-facing-boundary.json",
        derived.json_path,
    );
    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/app-facing-production-integration-fixtures-readiness-review-implementation-proposal-app-facing-boundary.txt",
        derived.text_path,
    );

    const custom = try outputPathsForOptions(std.testing.allocator, .{
        .proposal_path = ".zig-cache/causal-artifacts/proposal.json",
        .decision = .approve,
        .reason = "reviewed",
        .out_prefix = ".zig-cache/causal-artifacts/custom-boundary",
    });
    defer custom.deinit(std.testing.allocator);
    try std.testing.expectEqualStrings(".zig-cache/causal-artifacts/custom-boundary.json", custom.json_path);
    try std.testing.expectEqualStrings(".zig-cache/causal-artifacts/custom-boundary.txt", custom.text_path);
}

test "approved and blocked boundary reports preserve app-facing authority" {
    const approved = try formatReports(std.testing.allocator, .{
        .options = .{
            .proposal_path = "proposal.json",
            .decision = .approve,
            .reason = "proposal evidence reviewed",
            .verified_commands = required_verification_commands,
        },
        .source_proposal_json = sample_proposal_json,
    });
    defer approved.deinit(std.testing.allocator);

    try std.testing.expect(std.mem.indexOf(u8, approved.json, "\"schema\": \"zigeffect.causal.app-facing-production-integration-boundary.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, approved.json, "\"boundary_status\": \"approved\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, approved.json, "\"approved_for_next_branch\": true") != null);
    try std.testing.expect(std.mem.indexOf(u8, approved.json, "\"app_mutation_enabled\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, approved.json, "\"raw_payload_capture_enabled\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, approved.json, "\"nendb_write_enabled\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, approved.json, "\"live_exporter_enabled\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, approved.json, "\"app_boundary_contract\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, approved.json, "\"local_projection_fixtures\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, approved.json, "worker-request-runtime-ref-boundary") != null);
    try std.testing.expect(std.mem.indexOf(u8, approved.json, "agent-query-bounded-projection-boundary") != null);
    try std.testing.expect(std.mem.indexOf(u8, approved.json, "nendb-history-handoff-ref-boundary") != null);
    try std.testing.expect(std.mem.indexOf(u8, approved.text, "boundary_status: approved") != null);
    try std.testing.expect(std.mem.indexOf(u8, approved.text, "mutation_authority: none") != null);
    try std.testing.expect(std.mem.indexOf(u8, approved.text, "app mutation enabled: false") != null);
    try std.testing.expect(std.mem.indexOf(u8, approved.text, "raw payload capture enabled: false") != null);
    try std.testing.expect(std.mem.indexOf(u8, approved.text, "nendb write enabled: false") != null);
    try std.testing.expect(std.mem.indexOf(u8, approved.text, "next branch if approved: codex/zigeffect-causal-app-facing-production-integration-local-fixtures") != null);

    const blocked = try formatReports(std.testing.allocator, .{
        .options = .{
            .proposal_path = "proposal.json",
            .decision = .reject,
            .reason = "negative boundary path",
        },
        .source_proposal_json = sample_proposal_json,
    });
    defer blocked.deinit(std.testing.allocator);

    try std.testing.expect(std.mem.indexOf(u8, blocked.json, "\"boundary_status\": \"blocked\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, blocked.json, "\"approved_for_next_branch\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, blocked.text, "boundary_status: blocked") != null);
    try std.testing.expect(std.mem.indexOf(u8, blocked.text, "app mutation enabled: false") != null);
}

test "boundary blocks unsupported source proposal schema" {
    const bad_schema_json = try std.mem.replaceOwned(
        u8,
        std.testing.allocator,
        sample_proposal_json,
        "zigeffect.causal.app-facing-production-integration-implementation-proposal.v1",
        "zigeffect.causal.unsupported.v1",
    );
    defer std.testing.allocator.free(bad_schema_json);

    try expectBlockedBy(bad_schema_json, "proposal-schema");
}

test "boundary blocks failed source checks and authority drift" {
    const failed_check_json = try std.mem.replaceOwned(
        u8,
        std.testing.allocator,
        sample_proposal_json,
        "\"app-runtime-scope\", \"status\": \"pass\"",
        "\"app-runtime-scope\", \"status\": \"fail\"",
    );
    defer std.testing.allocator.free(failed_check_json);
    try expectBlockedBy(failed_check_json, "proposal-checks-passed");

    const authority_drift_json = try std.mem.replaceOwned(
        u8,
        std.testing.allocator,
        sample_proposal_json,
        "\"app_mutation_enabled\": false",
        "\"app_mutation_enabled\": true",
    );
    defer std.testing.allocator.free(authority_drift_json);
    try expectBlockedBy(authority_drift_json, "authority-boundary");
}

test "boundary blocks missing source or boundary verification evidence" {
    const complete_verified_commands =
        \\  "verified_commands": [
        \\    "zig build causal-app-facing-production-integration-readiness-review -- --from-fixtures ../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures.json approve --reason \"fixtures reviewed for implementation proposal\" --verified-command \"zig build causal-app-facing-production-integration-fixtures -- validate --format json\" --verified-command \"zig build causal-schema-governance -- --format json\" --verified-command \"zig build causal-production-hardening-backlog -- --format json\" --verified-command \"zig build examples\" --verified-command \"zig build test\"",
        \\    "zig build causal-schema-governance -- --format json",
        \\    "zig build causal-production-hardening-backlog -- --format json",
        \\    "zig build examples",
        \\    "zig build test"
        \\  ]
    ;
    const incomplete_verified_commands =
        \\  "verified_commands": [
        \\    "zig build test"
        \\  ]
    ;
    const missing_source_verification_json = try std.mem.replaceOwned(
        u8,
        std.testing.allocator,
        sample_proposal_json,
        complete_verified_commands,
        incomplete_verified_commands,
    );
    defer std.testing.allocator.free(missing_source_verification_json);
    try expectBlockedBy(missing_source_verification_json, "proposal-verification-recorded");

    const missing_boundary_verification = try formatReports(std.testing.allocator, .{
        .options = .{
            .proposal_path = "proposal.json",
            .decision = .approve,
            .reason = "proposal evidence reviewed",
            .verified_commands = &.{"zig build test"},
        },
        .source_proposal_json = sample_proposal_json,
    });
    defer missing_boundary_verification.deinit(std.testing.allocator);

    try std.testing.expect(std.mem.indexOf(u8, missing_boundary_verification.json, "\"boundary_status\": \"blocked\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, missing_boundary_verification.json, "\"name\": \"boundary-verification-recorded\", \"status\": \"fail\"") != null);
}

fn expectBlockedBy(source_proposal_json: []const u8, check_name: []const u8) !void {
    const reports = try formatReports(std.testing.allocator, .{
        .options = .{
            .proposal_path = "proposal.json",
            .decision = .approve,
            .reason = "proposal evidence reviewed",
            .verified_commands = required_verification_commands,
        },
        .source_proposal_json = source_proposal_json,
    });
    defer reports.deinit(std.testing.allocator);

    const failed_check = try std.fmt.allocPrint(std.testing.allocator, "\"name\": \"{s}\", \"status\": \"fail\"", .{check_name});
    defer std.testing.allocator.free(failed_check);

    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"boundary_status\": \"blocked\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, failed_check) != null);
}

const sample_proposal_json =
    \\{
    \\  "schema": "zigeffect.causal.app-facing-production-integration-implementation-proposal.v1",
    \\  "schema_version": 1,
    \\  "source_readiness": "../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures-readiness-review.json",
    \\  "source_fixtures": "../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures.json",
    \\  "decision": "approve",
    \\  "proposal_status": "approved",
    \\  "approved_for_next_branch": true,
    \\  "proposed_by": "local-proposer",
    \\  "policy": "manual-app-facing-production-integration-implementation-proposal",
    \\  "reason": "ready evidence reviewed for app-facing integration planning",
    \\  "applied": false,
    \\  "mutation_authority": "none",
    \\  "production_telemetry_ingestion": false,
    \\  "live_exporter_enabled": false,
    \\  "durable_write_enabled": false,
    \\  "app_mutation_enabled": false,
    \\  "ci_gate_enabled": false,
    \\  "source_branch": "codex/zigeffect-causal-app-facing-production-integration-implementation-proposal",
    \\  "recommendation": "start-app-facing-production-integration-boundary",
    \\  "next_branch_if_approved": "codex/zigeffect-causal-app-facing-production-integration-boundary",
    \\  "readiness_summary": { "source_contract_count": 7, "positive_fixture_count": 6, "negative_fixture_count": 14, "validation_check_count": 8 },
    \\  "checks": [
    \\    { "name": "readiness-schema", "status": "pass", "detail": "source readiness schema is supported" },
    \\    { "name": "readiness-status", "status": "pass", "detail": "source readiness artifact is ready for implementation proposal" },
    \\    { "name": "readiness-decision-approved", "status": "pass", "detail": "source readiness reviewer approved fixture evidence" },
    \\    { "name": "proposal-decision", "status": "pass", "detail": "proposal decision includes a reason" },
    \\    { "name": "decision-approved", "status": "pass", "detail": "proposal decision must approve next branch handoff" },
    \\    { "name": "authority-boundary", "status": "pass", "detail": "readiness and proposal authority fields remain disabled" },
    \\    { "name": "source-fixtures-linked", "status": "pass", "detail": "readiness artifact links source fixture JSON" },
    \\    { "name": "readiness-checks-passed", "status": "pass", "detail": "all source readiness checks passed" },
    \\    { "name": "readiness-verification-recorded", "status": "pass", "detail": "source readiness recorded required verification command evidence" },
    \\    { "name": "proposal-verification-recorded", "status": "pass", "detail": "proposal recorded every required verification command" },
    \\    { "name": "nendb-only-scope", "status": "pass", "detail": "durable direction remains future NenDB-only scope" },
    \\    { "name": "solid-webui-scope", "status": "pass", "detail": "workbench direction remains SolidJS inside webui-dev/zig-webui" },
    \\    { "name": "app-runtime-scope", "status": "pass", "detail": "app runtime scope blocks raw payload capture and app mutation authority" },
    \\    { "name": "agent-query-scope", "status": "pass", "detail": "agent query scope remains bounded trace evidence instead of raw scraping" }
    \\  ],
    \\  "proposal_phases": [
    \\    "app-runtime-boundary",
    \\    "agent-query-projection",
    \\    "nendb-history-handoff",
    \\    "audit-remediation-bridge",
    \\    "solid-webui-readonly-preview",
    \\    "ci-artifact-preview"
    \\  ],
    \\  "implementation_gates": [
    \\    "source readiness artifact is ready and approved",
    \\    "all readiness checks remain pass"
    \\  ],
    \\  "non_goals": [
    \\    "Live production telemetry ingestion",
    \\    "Non-NenDB durable adapter work",
    \\    "Cockroach adapter work",
    \\    "React or alternate renderer work",
    \\    "Raw app payload capture",
    \\    "App runtime mutation authority"
    \\  ],
    \\  "blocked_claims": [
    \\    "app-mutation-enabled",
    \\    "raw-payload-capture-enabled",
    \\    "app-config-write",
    \\    "app-data-write",
    \\    "deployment-mutation",
    \\    "nendb-production-write",
    \\    "audit-chain-compare-as-mutation-proof",
    \\    "app-remediation-auto-apply",
    \\    "live-exporter-enabled",
    \\    "non-nendb-durable-storage",
    \\    "cockroach-adapter-work",
    \\    "react-or-alternate-renderer"
    \\  ],
    \\  "required_verification_commands": [
    \\    "zig build causal-app-facing-production-integration-readiness-review -- --from-fixtures ../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures.json approve --reason \"fixtures reviewed for implementation proposal\" --verified-command \"zig build causal-app-facing-production-integration-fixtures -- validate --format json\" --verified-command \"zig build causal-schema-governance -- --format json\" --verified-command \"zig build causal-production-hardening-backlog -- --format json\" --verified-command \"zig build examples\" --verified-command \"zig build test\"",
    \\    "zig build causal-schema-governance -- --format json",
    \\    "zig build causal-production-hardening-backlog -- --format json",
    \\    "zig build examples",
    \\    "zig build test"
    \\  ],
    \\  "verified_commands": [
    \\    "zig build causal-app-facing-production-integration-readiness-review -- --from-fixtures ../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures.json approve --reason \"fixtures reviewed for implementation proposal\" --verified-command \"zig build causal-app-facing-production-integration-fixtures -- validate --format json\" --verified-command \"zig build causal-schema-governance -- --format json\" --verified-command \"zig build causal-production-hardening-backlog -- --format json\" --verified-command \"zig build examples\" --verified-command \"zig build test\"",
    \\    "zig build causal-schema-governance -- --format json",
    \\    "zig build causal-production-hardening-backlog -- --format json",
    \\    "zig build examples",
    \\    "zig build test"
    \\  ]
    \\}
;
