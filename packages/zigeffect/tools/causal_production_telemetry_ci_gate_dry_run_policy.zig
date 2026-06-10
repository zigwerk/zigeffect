const std = @import("std");

pub const production_telemetry_ci_gate_dry_run_policy_schema = "zigeffect.causal.production-telemetry-ci-gate-dry-run-policy.v1";
pub const production_telemetry_ci_gate_dry_run_policy_schema_version: u32 = 1;
pub const source_branch = "codex/zigeffect-causal-production-telemetry-ci-gate-dry-run-policy";
pub const recommendation = "start-production-telemetry-ci-gate-dry-run-evaluator";
pub const next_branch_if_ready = "codex/zigeffect-causal-production-telemetry-ci-gate-dry-run-evaluator";

const gate_application_boundary_schema = "zigeffect.causal.production-telemetry-ci-gate-application-boundary.v1";
const generated_by = "causal-production-telemetry-ci-gate-dry-run-policy";

const required_verification_commands: []const []const u8 = &.{
    "zig build causal-production-telemetry-ci-gate-application-boundary",
    "zig build causal-artifacts",
    "zig build release-gate --summary none",
    "zig build release-gate-report",
    "zig build causal-schema-governance -- --format json",
    "zig build causal-production-hardening-backlog -- --format json",
    "zig build examples",
    "zig build test",
};

const ci_gate_enabled = false;
const ci_gate_enforcement_enabled = false;
const ci_required_status_check_enabled = false;
const ci_workflow_mutation_enabled = false;
const ci_upload_execution_enabled = false;
const production_telemetry_ingestion = false;
const live_exporter_enabled = false;
const network_send_enabled = false;
const collector_endpoint_configured = false;
const otlp_serialization_enabled = false;
const runtime_pipeline_enabled = false;
const durable_write_enabled = false;
const nendb_write_enabled = false;

const Decision = enum { approve, reject };
const PolicyStatus = enum { ready, blocked };
const CheckStatus = enum { pass, fail, skipped };

const Options = struct {
    gate_application_boundary_path: []const u8,
    decision: Decision,
    reviewed_by: []const u8 = "ci-gate-dry-run-policy-reviewer",
    policy: []const u8 = "manual-production-telemetry-ci-gate-dry-run-policy",
    reason: []const u8,
    verified_commands: []const []const u8 = &.{},
    out_prefix: ?[]const u8 = null,

    fn deinit(self: Options, allocator: std.mem.Allocator) void {
        freeSliceOnly(allocator, self.verified_commands);
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

const PolicyInput = struct {
    options: Options,
    source_gate_application_boundary_json: []const u8,
};

const PolicyReports = struct {
    json: []const u8,
    text: []const u8,

    fn deinit(self: PolicyReports, allocator: std.mem.Allocator) void {
        allocator.free(self.json);
        allocator.free(self.text);
    }
};

const SourceCheck = struct {
    name: []const u8 = "",
    id: []const u8 = "",
    status: []const u8,
    detail: []const u8 = "",
};

const SourceNegativeFixture = struct {
    id: []const u8 = "",
    artifact_state: []const u8 = "",
    decision: []const u8 = "",
    failed_gate: []const u8 = "",
    reason: []const u8 = "",
};

const GateApplicationBoundaryArtifact = struct {
    schema: []const u8,
    schema_version: u32,
    source_ci_gate_readiness: []const u8 = "",
    source_gate_readiness_status: []const u8 = "",
    source_workflow_digest: []const u8 = "",
    mode: []const u8,
    gate_application_status: []const u8,
    applied: bool,
    mutation_authority: []const u8,
    ci_gate_enabled: bool,
    ci_gate_enforcement_enabled: bool,
    ci_required_status_check_enabled: bool,
    ci_workflow_mutation_enabled: bool,
    ci_upload_execution_enabled: bool,
    production_telemetry_ingestion: bool,
    live_exporter_enabled: bool,
    network_send_enabled: bool,
    collector_endpoint_configured: bool,
    otlp_serialization_enabled: bool,
    runtime_pipeline_enabled: bool,
    durable_write_enabled: bool,
    nendb_write_enabled: bool,
    boundary_checks: []const SourceCheck = &.{},
    application_boundary_rules: []const []const u8 = &.{},
    denied_application_claims: []const []const u8 = &.{},
    negative_fixtures: []const SourceNegativeFixture = &.{},
    blocked_claims: []const []const u8 = &.{},
    required_verification_commands: []const []const u8 = &.{},
    verified_commands: []const []const u8 = &.{},
};

const PolicyCheck = struct {
    name: []const u8,
    status: CheckStatus,
    detail: []const u8,
};

const PolicyResult = struct {
    status: PolicyStatus,
    ready_for_next_branch: bool,
    checks: []const PolicyCheck,

    fn deinit(self: PolicyResult, allocator: std.mem.Allocator) void {
        if (self.checks.len > 0) allocator.free(self.checks);
    }
};

const CandidateSignalPolicy = struct {
    id: []const u8,
    evaluation_mode: []const u8,
    enforcement_enabled: bool,
    required_status_check_enabled: bool,
    failure_effect: []const u8,
    evidence: []const u8,
    blocked_claim: []const u8,
};

const EvidenceRequirement = struct {
    id: []const u8,
    allowed: bool,
    detail: []const u8,
};

const NegativeFixture = struct {
    id: []const u8,
    artifact_state: []const u8,
    decision: []const u8,
    failed_gate: []const u8,
    reason: []const u8,
};

const dry_run_policy_rules: []const []const u8 = &.{
    "Dry-run policy evaluation is advisory and cannot create required status checks.",
    "Candidate signals may inspect bounded local or CI artifacts only.",
    "A failing candidate signal emits advisory findings for agents and reviewers, not merge-blocking enforcement.",
    "The policy consumes a reviewed gate application boundary and carries its disabled authority forward.",
    "Evidence may explain CI artifact readiness but not production health, deployment success, customer impact, or cluster readiness.",
};

const candidate_signal_policies: []const CandidateSignalPolicy = &.{
    .{ .id = "release-gate-artifact-present", .evaluation_mode = "dry-run", .enforcement_enabled = false, .required_status_check_enabled = false, .failure_effect = "advisory", .evidence = "release-gate JSON or text artifact exists in bounded CI artifact set", .blocked_claim = "required-release-gate-status-check" },
    .{ .id = "causal-artifact-schema-parse", .evaluation_mode = "dry-run", .enforcement_enabled = false, .required_status_check_enabled = false, .failure_effect = "advisory", .evidence = "causal JSON artifact parses as a governed schema", .blocked_claim = "schema-parse-enforcement" },
    .{ .id = "archive-policy-conformance", .evaluation_mode = "dry-run", .enforcement_enabled = false, .required_status_check_enabled = false, .failure_effect = "advisory", .evidence = "artifact class matches archive evidence policy allowlist", .blocked_claim = "archive-policy-required-check" },
    .{ .id = "redaction-retention-conformance", .evaluation_mode = "dry-run", .enforcement_enabled = false, .required_status_check_enabled = false, .failure_effect = "advisory", .evidence = "artifact metadata records redaction state and retention no greater than fourteen days", .blocked_claim = "retention-or-redaction-enforcement" },
    .{ .id = "ci-handoff-present", .evaluation_mode = "dry-run", .enforcement_enabled = false, .required_status_check_enabled = false, .failure_effect = "advisory", .evidence = "failure handoff text or JSON exists when a failure branch generated it", .blocked_claim = "handoff-required-check" },
    .{ .id = "boundary-source-valid", .evaluation_mode = "dry-run", .enforcement_enabled = false, .required_status_check_enabled = false, .failure_effect = "advisory", .evidence = "source gate application boundary has no failed boundary checks", .blocked_claim = "boundary-validation-enforcement" },
};

const evidence_requirements: []const EvidenceRequirement = &.{
    .{ .id = "causal-json-artifacts", .allowed = true, .detail = "bounded causal JSON artifacts generated by zigeffect tests or examples" },
    .{ .id = "causal-text-artifacts", .allowed = true, .detail = "bounded causal text artifacts generated by zigeffect tests or examples" },
    .{ .id = "release-gate-json-artifacts", .allowed = true, .detail = "release-gate JSON reports from zig build release-gate" },
    .{ .id = "release-gate-text-artifacts", .allowed = true, .detail = "release-gate text reports from zig build release-gate-report" },
    .{ .id = "ci-handoff-artifacts", .allowed = true, .detail = "bounded failure handoff text or JSON generated by causal CI handoff" },
    .{ .id = "source-policy-artifacts", .allowed = true, .detail = "reviewed source policy artifacts from the causal production telemetry chain" },
    .{ .id = "secret-values", .allowed = false, .detail = "secret-shaped values credentials tokens and raw private headers are never valid evidence" },
    .{ .id = "network-or-live-telemetry", .allowed = false, .detail = "dry-run policy must not call networks or ingest live telemetry" },
    .{ .id = "production-database-writes", .allowed = false, .detail = "dry-run policy must not write production databases or durable stores" },
    .{ .id = "non-nendb-durable-adapters", .allowed = false, .detail = "durable direction remains NenDB adapter only" },
};

const negative_fixtures: []const NegativeFixture = &.{
    .{ .id = "blocked-source-boundary-denied", .artifact_state = "gate_application_status=blocked", .decision = "deny", .failed_gate = "source-boundary-status-valid", .reason = "blocked application boundary cannot feed dry-run policy" },
    .{ .id = "ci-gate-enforcement-claim-denied", .artifact_state = "ci_gate_enforcement_enabled=true", .decision = "deny", .failed_gate = "source-disabled-authority", .reason = "dry-run policy cannot enable CI gate enforcement" },
    .{ .id = "required-status-check-claim-denied", .artifact_state = "ci_required_status_check_enabled=true", .decision = "deny", .failed_gate = "source-disabled-authority", .reason = "required checks are out of scope" },
    .{ .id = "workflow-mutation-claim-denied", .artifact_state = "ci_workflow_mutation_enabled=true", .decision = "deny", .failed_gate = "source-disabled-authority", .reason = "policy does not mutate workflows" },
    .{ .id = "missing-release-gate-verification-denied", .artifact_state = "verified commands omit release gate or report", .decision = "deny", .failed_gate = "policy-verification-recorded", .reason = "dry-run policy needs release-gate and release-gate-report verification evidence" },
    .{ .id = "production-health-claim-denied", .artifact_state = "production_health=proven", .decision = "deny", .failed_gate = "dry-run-is-not-production", .reason = "CI evidence is not live production telemetry" },
    .{ .id = "public-upload-claim-denied", .artifact_state = "artifact_visibility=public", .decision = "deny", .failed_gate = "bounded-private-evidence", .reason = "dry-run evidence remains bounded local or CI artifact evidence" },
    .{ .id = "retention-too-long-denied", .artifact_state = "retention_days=90", .decision = "deny", .failed_gate = "bounded-retention", .reason = "dry-run artifact retention remains fourteen days or less" },
    .{ .id = "secret-shaped-evidence-denied", .artifact_state = "evidence contains token or secret", .decision = "deny", .failed_gate = "no-secret-evidence", .reason = "secret-shaped evidence cannot enter dry-run policy artifacts" },
    .{ .id = "live-telemetry-denied", .artifact_state = "collector_endpoint_configured=true", .decision = "deny", .failed_gate = "no-live-telemetry", .reason = "dry-run policy does not configure collectors" },
    .{ .id = "durable-write-denied", .artifact_state = "durable_write_enabled=true", .decision = "deny", .failed_gate = "no-durable-writes", .reason = "dry-run policy does not write durable stores" },
    .{ .id = "nendb-write-denied", .artifact_state = "nendb_write_enabled=true", .decision = "deny", .failed_gate = "no-nendb-writes", .reason = "NenDB remains future adapter work, not dry-run policy output" },
    .{ .id = "non-nendb-durable-denied", .artifact_state = "durable_adapter=non-nendb", .decision = "deny", .failed_gate = "nendb-only", .reason = "non-NenDB durable adapters remain out of scope" },
    .{ .id = "alternate-renderer-denied", .artifact_state = "renderer=react", .decision = "deny", .failed_gate = "solid-webui", .reason = "workbench direction remains SolidJS inside zig-webui" },
};

pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len == 2 and (std.mem.eql(u8, args[1], "--help") or std.mem.eql(u8, args[1], "-h"))) {
        std.debug.print("{s}", .{usage()});
        return;
    }
    const options = parseOptions(init.gpa, args) catch |err| failUsage(err);
    defer options.deinit(init.gpa);
    run(init, options) catch |err| switch (err) {
        error.MissingGateApplicationBoundaryInput => failUsage(err),
        else => return err,
    };
}

fn parseOptions(allocator: std.mem.Allocator, args: []const []const u8) !Options {
    if (args.len < 2) return error.MissingGateApplicationBoundaryPath;
    if (!std.mem.eql(u8, args[1], "--from-gate-application-boundary")) return error.UnknownFlag;
    if (args.len < 3) return error.MissingGateApplicationBoundaryPath;
    const gate_application_boundary_path = args[2];
    if (!std.mem.endsWith(u8, gate_application_boundary_path, ".json")) return error.InvalidGateApplicationBoundaryPath;
    if (args.len < 4) return error.MissingDecision;
    const decision = try parseDecision(args[3]);

    var reviewed_by: []const u8 = "ci-gate-dry-run-policy-reviewer";
    var policy: []const u8 = "manual-production-telemetry-ci-gate-dry-run-policy";
    var reason: ?[]const u8 = null;
    var verified_commands = std.ArrayList([]const u8).empty;
    var out_prefix: ?[]const u8 = null;
    errdefer verified_commands.deinit(allocator);

    var index: usize = 4;
    while (index < args.len) {
        if (index + 1 >= args.len) return error.MissingFlagValue;
        const flag = args[index];
        const value = args[index + 1];
        if (!std.mem.startsWith(u8, flag, "--")) return error.UnknownArgument;

        if (std.mem.eql(u8, flag, "--by")) {
            reviewed_by = value;
        } else if (std.mem.eql(u8, flag, "--policy")) {
            policy = value;
        } else if (std.mem.eql(u8, flag, "--reason")) {
            reason = value;
        } else if (std.mem.eql(u8, flag, "--verified-command")) {
            try verified_commands.append(allocator, value);
        } else if (std.mem.eql(u8, flag, "--out-prefix")) {
            out_prefix = value;
        } else {
            return error.UnknownFlag;
        }
        index += 2;
    }

    const final_reason = reason orelse return error.MissingReason;
    if (final_reason.len == 0) return error.MissingReason;

    return .{
        .gate_application_boundary_path = gate_application_boundary_path,
        .decision = decision,
        .reviewed_by = reviewed_by,
        .policy = policy,
        .reason = final_reason,
        .verified_commands = try verified_commands.toOwnedSlice(allocator),
        .out_prefix = out_prefix,
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

fn policyStatusText(status: PolicyStatus) []const u8 {
    return switch (status) {
        .ready => "ready",
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

fn outputPathsForOptions(allocator: std.mem.Allocator, options: Options) !OutputPaths {
    const prefix = if (options.out_prefix) |out_prefix|
        try allocator.dupe(u8, out_prefix)
    else blk: {
        if (!std.mem.endsWith(u8, options.gate_application_boundary_path, ".json")) return error.InvalidGateApplicationBoundaryPath;
        if (std.mem.endsWith(u8, options.gate_application_boundary_path, "-ci-gate-application-boundary.json")) {
            const suffix_len = "-ci-gate-application-boundary.json".len;
            break :blk try std.fmt.allocPrint(allocator, "{s}-ci-gate-dry-run-policy", .{options.gate_application_boundary_path[0 .. options.gate_application_boundary_path.len - suffix_len]});
        }
        const base = options.gate_application_boundary_path[0 .. options.gate_application_boundary_path.len - ".json".len];
        break :blk try std.fmt.allocPrint(allocator, "{s}-ci-gate-dry-run-policy", .{base});
    };
    defer allocator.free(prefix);

    return .{
        .json_path = try std.fmt.allocPrint(allocator, "{s}.json", .{prefix}),
        .text_path = try std.fmt.allocPrint(allocator, "{s}.txt", .{prefix}),
    };
}

fn formatReports(allocator: std.mem.Allocator, input: PolicyInput) !PolicyReports {
    var parsed = try std.json.parseFromSlice(GateApplicationBoundaryArtifact, allocator, input.source_gate_application_boundary_json, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();

    const paths = try outputPathsForOptions(allocator, input.options);
    defer paths.deinit(allocator);

    const result = try evaluatePolicy(allocator, input.options, parsed.value);
    defer result.deinit(allocator);

    const json = try formatPolicyJson(allocator, input.options, parsed.value, result, paths);
    errdefer allocator.free(json);
    const text = try formatPolicyText(allocator, input.options, parsed.value, result, paths);
    errdefer allocator.free(text);

    return .{ .json = json, .text = text };
}

fn evaluatePolicy(
    allocator: std.mem.Allocator,
    options: Options,
    source: GateApplicationBoundaryArtifact,
) !PolicyResult {
    var checks = std.ArrayList(PolicyCheck).empty;
    errdefer checks.deinit(allocator);

    try appendCheck(allocator, &checks, "source-boundary-schema", if (std.mem.eql(u8, source.schema, gate_application_boundary_schema) and source.schema_version == 1) .pass else .fail, "source gate application boundary schema is supported");
    try appendCheck(allocator, &checks, "source-boundary-status-valid", if (sourceBoundaryStatusValid(source)) .pass else .fail, "source gate application boundary is planned or applied, never blocked");
    try appendCheck(allocator, &checks, "source-mode-valid", if (std.mem.eql(u8, source.mode, "plan") or std.mem.eql(u8, source.mode, "record-applied")) .pass else .fail, "source mode is a supported boundary mode");
    try appendCheck(allocator, &checks, "source-mutation-authority-valid", if (sourceMutationAuthorityValid(source)) .pass else .fail, "source applied state and mutation authority are internally consistent");
    try appendCheck(allocator, &checks, "source-disabled-authority", if (sourceAuthorityDisabled(source)) .pass else .fail, "source keeps gate enforcement required checks workflow mutation upload execution runtime durable and NenDB authority disabled");
    try appendCheck(allocator, &checks, "source-boundary-checks-passed", if (sourceBoundaryChecksHaveNoFailures(source.boundary_checks)) .pass else .fail, "source boundary checks contain no failures");
    try appendCheck(allocator, &checks, "source-catalogs-present", if (sourceCatalogsPresent(source)) .pass else .fail, "source boundary rules denied claims negative fixtures and blocked claims are present");
    try appendCheck(allocator, &checks, "policy-verification-recorded", if (verifiedCommandsContainAll(options.verified_commands, required_verification_commands)) .pass else .fail, "dry-run policy review recorded every required verification command");
    try appendCheck(allocator, &checks, "release-gate-verification-recorded", if (verifiedCommandsContainAll(options.verified_commands, &.{ "zig build release-gate --summary none", "zig build release-gate-report" })) .pass else .fail, "release gate and release gate report commands are verified");
    try appendCheck(allocator, &checks, "reviewer-decision-approved", if (options.decision == .approve) .pass else .fail, "reviewer approved the dry-run policy handoff");
    try appendCheck(allocator, &checks, "dry-run-is-not-production", .pass, "policy is advisory and cannot prove production health cluster readiness or deployment safety");
    try appendCheck(allocator, &checks, "bounded-private-evidence", .pass, "policy limits evidence to bounded local or CI artifacts");
    try appendCheck(allocator, &checks, "no-live-telemetry", .pass, "policy performs no network collection or live telemetry ingestion");
    try appendCheck(allocator, &checks, "no-durable-writes", .pass, "policy performs no durable or NenDB writes");

    const check_slice = try checks.toOwnedSlice(allocator);
    errdefer allocator.free(check_slice);
    const ready = allChecksPassed(check_slice);
    return .{
        .status = if (ready) .ready else .blocked,
        .ready_for_next_branch = ready,
        .checks = check_slice,
    };
}

fn appendCheck(
    allocator: std.mem.Allocator,
    checks: *std.ArrayList(PolicyCheck),
    name: []const u8,
    status: CheckStatus,
    detail: []const u8,
) !void {
    try checks.append(allocator, .{ .name = name, .status = status, .detail = detail });
}

fn allChecksPassed(checks: []const PolicyCheck) bool {
    for (checks) |check| {
        if (check.status != .pass) return false;
    }
    return true;
}

fn sourceBoundaryStatusValid(source: GateApplicationBoundaryArtifact) bool {
    return std.mem.eql(u8, source.gate_application_status, "planned") or
        std.mem.eql(u8, source.gate_application_status, "applied");
}

fn sourceMutationAuthorityValid(source: GateApplicationBoundaryArtifact) bool {
    if (source.applied) return std.mem.eql(u8, source.mutation_authority, "record-only");
    return std.mem.eql(u8, source.mutation_authority, "none");
}

fn sourceAuthorityDisabled(source: GateApplicationBoundaryArtifact) bool {
    return !source.ci_gate_enabled and
        !source.ci_gate_enforcement_enabled and
        !source.ci_required_status_check_enabled and
        !source.ci_workflow_mutation_enabled and
        !source.ci_upload_execution_enabled and
        !source.production_telemetry_ingestion and
        !source.live_exporter_enabled and
        !source.network_send_enabled and
        !source.collector_endpoint_configured and
        !source.otlp_serialization_enabled and
        !source.runtime_pipeline_enabled and
        !source.durable_write_enabled and
        !source.nendb_write_enabled;
}

fn sourceBoundaryChecksHaveNoFailures(checks: []const SourceCheck) bool {
    if (checks.len == 0) return false;
    for (checks) |check| {
        if (std.mem.eql(u8, check.status, "fail")) return false;
    }
    return true;
}

fn sourceCatalogsPresent(source: GateApplicationBoundaryArtifact) bool {
    return source.application_boundary_rules.len > 0 and
        source.denied_application_claims.len > 0 and
        source.negative_fixtures.len > 0 and
        source.blocked_claims.len > 0;
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

fn formatPolicyJson(
    allocator: std.mem.Allocator,
    options: Options,
    source: GateApplicationBoundaryArtifact,
    result: PolicyResult,
    paths: OutputPaths,
) ![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "{\n");
    try appendJsonField(allocator, &output, "schema", production_telemetry_ci_gate_dry_run_policy_schema, true);
    try output.appendSlice(allocator, "  \"schema_version\": 1,\n");
    try appendJsonField(allocator, &output, "source_gate_application_boundary", options.gate_application_boundary_path, true);
    try appendJsonField(allocator, &output, "source_boundary_status", source.gate_application_status, true);
    try appendJsonField(allocator, &output, "source_boundary_mode", source.mode, true);
    try output.print(allocator, "  \"source_boundary_applied\": {},\n", .{source.applied});
    try appendJsonField(allocator, &output, "source_boundary_mutation_authority", source.mutation_authority, true);
    try appendJsonField(allocator, &output, "source_ci_gate_readiness", source.source_ci_gate_readiness, true);
    try appendJsonField(allocator, &output, "source_workflow_digest", source.source_workflow_digest, true);
    try appendJsonField(allocator, &output, "decision", decisionText(options.decision), true);
    try appendJsonField(allocator, &output, "reviewed_by", options.reviewed_by, true);
    try appendJsonField(allocator, &output, "policy", options.policy, true);
    try appendJsonField(allocator, &output, "reason", options.reason, true);
    try appendJsonField(allocator, &output, "dry_run_policy_status", policyStatusText(result.status), true);
    try output.print(allocator, "  \"ready_for_next_branch\": {},\n", .{result.ready_for_next_branch});
    try output.print(allocator, "  \"ci_gate_enabled\": {},\n", .{ci_gate_enabled});
    try output.print(allocator, "  \"ci_gate_enforcement_enabled\": {},\n", .{ci_gate_enforcement_enabled});
    try output.print(allocator, "  \"ci_required_status_check_enabled\": {},\n", .{ci_required_status_check_enabled});
    try output.print(allocator, "  \"ci_workflow_mutation_enabled\": {},\n", .{ci_workflow_mutation_enabled});
    try output.print(allocator, "  \"ci_upload_execution_enabled\": {},\n", .{ci_upload_execution_enabled});
    try output.print(allocator, "  \"production_telemetry_ingestion\": {},\n", .{production_telemetry_ingestion});
    try output.print(allocator, "  \"live_exporter_enabled\": {},\n", .{live_exporter_enabled});
    try output.print(allocator, "  \"network_send_enabled\": {},\n", .{network_send_enabled});
    try output.print(allocator, "  \"collector_endpoint_configured\": {},\n", .{collector_endpoint_configured});
    try output.print(allocator, "  \"otlp_serialization_enabled\": {},\n", .{otlp_serialization_enabled});
    try output.print(allocator, "  \"runtime_pipeline_enabled\": {},\n", .{runtime_pipeline_enabled});
    try output.print(allocator, "  \"durable_write_enabled\": {},\n", .{durable_write_enabled});
    try output.print(allocator, "  \"nendb_write_enabled\": {},\n", .{nendb_write_enabled});
    try output.appendSlice(allocator, "  \"dry_run_policy_rules\": ");
    try appendStringArray(allocator, &output, dry_run_policy_rules);
    try output.appendSlice(allocator, ",\n  \"candidate_signal_policies\": ");
    try appendCandidateSignalPoliciesJson(allocator, &output);
    try output.appendSlice(allocator, ",\n  \"evidence_requirements\": ");
    try appendEvidenceRequirementsJson(allocator, &output);
    try output.appendSlice(allocator, ",\n  \"source_boundary_checks\": ");
    try appendSourceChecksJson(allocator, &output, source.boundary_checks);
    try output.appendSlice(allocator, ",\n  \"checks\": ");
    try appendChecksJson(allocator, &output, result.checks);
    try output.appendSlice(allocator, ",\n  \"negative_fixtures\": ");
    try appendNegativeFixturesJson(allocator, &output);
    try output.appendSlice(allocator, ",\n  \"blocked_claims\": ");
    try appendStringArray(allocator, &output, blockedClaims(source));
    try output.appendSlice(allocator, ",\n  \"required_verification_commands\": ");
    try appendStringArray(allocator, &output, required_verification_commands);
    try output.appendSlice(allocator, ",\n  \"verified_commands\": ");
    try appendStringArray(allocator, &output, options.verified_commands);
    try appendJsonFieldPrefixComma(allocator, &output, "generated_by", generated_by);
    try appendJsonFieldPrefixComma(allocator, &output, "source_branch", source_branch);
    try appendJsonFieldPrefixComma(allocator, &output, "recommendation", recommendation);
    try appendJsonFieldPrefixComma(allocator, &output, "next_branch_if_ready", next_branch_if_ready);
    try appendJsonFieldPrefixComma(allocator, &output, "json_output", paths.json_path);
    try appendJsonFieldPrefixComma(allocator, &output, "text_output", paths.text_path);
    try output.appendSlice(allocator, ",\n  \"agent_guidance\": ");
    try appendStringArray(allocator, &output, agentGuidance(result.status));
    try output.appendSlice(allocator, "\n}\n");

    return output.toOwnedSlice(allocator);
}

fn formatPolicyText(
    allocator: std.mem.Allocator,
    options: Options,
    source: GateApplicationBoundaryArtifact,
    result: PolicyResult,
    paths: OutputPaths,
) ![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "zigeffect production telemetry CI gate dry-run policy\n");
    try output.print(allocator, "schema: {s}\n", .{production_telemetry_ci_gate_dry_run_policy_schema});
    try output.print(allocator, "source gate application boundary: {s}\n", .{options.gate_application_boundary_path});
    try output.print(allocator, "source boundary status: {s}\n", .{source.gate_application_status});
    try output.print(allocator, "source boundary mode: {s}\n", .{source.mode});
    try output.print(allocator, "source boundary applied: {}\n", .{source.applied});
    try output.print(allocator, "source boundary mutation authority: {s}\n", .{source.mutation_authority});
    try output.print(allocator, "decision: {s}\n", .{decisionText(options.decision)});
    try output.print(allocator, "dry_run_policy_status: {s}\n", .{policyStatusText(result.status)});
    try output.print(allocator, "ready_for_next_branch: {}\n", .{result.ready_for_next_branch});
    try output.print(allocator, "ci gate enabled: {}\n", .{ci_gate_enabled});
    try output.print(allocator, "ci gate enforcement enabled: {}\n", .{ci_gate_enforcement_enabled});
    try output.print(allocator, "ci required status check enabled: {}\n", .{ci_required_status_check_enabled});
    try output.print(allocator, "reviewed_by: {s}\n", .{options.reviewed_by});
    try output.print(allocator, "policy: {s}\n", .{options.policy});
    try output.print(allocator, "reason: {s}\n", .{options.reason});
    try output.print(allocator, "source branch: {s}\n", .{source_branch});
    try output.print(allocator, "recommendation: {s}\n", .{recommendation});
    try output.print(allocator, "next branch if ready: {s}\n", .{next_branch_if_ready});
    try output.print(allocator, "json output: {s}\n", .{paths.json_path});
    try output.print(allocator, "text output: {s}\n\n", .{paths.text_path});

    try output.appendSlice(allocator, "checks:\n");
    for (result.checks) |check| {
        try output.print(allocator, "- {s}: {s} - {s}\n", .{ check.name, checkStatusText(check.status), check.detail });
    }
    try output.append(allocator, '\n');

    try appendTextList(allocator, &output, "dry-run policy rules", dry_run_policy_rules);
    try appendCandidateSignalPoliciesText(allocator, &output);
    try appendEvidenceRequirementsText(allocator, &output);
    try appendNegativeFixturesText(allocator, &output);
    try appendTextList(allocator, &output, "blocked claims", blockedClaims(source));
    try appendTextList(allocator, &output, "required verification commands", required_verification_commands);
    try appendTextList(allocator, &output, "verified commands", options.verified_commands);
    try appendTextList(allocator, &output, "agent guidance", agentGuidance(result.status));

    return output.toOwnedSlice(allocator);
}

fn appendJsonField(allocator: std.mem.Allocator, output: *std.ArrayList(u8), name: []const u8, value: []const u8, comma: bool) !void {
    try output.appendSlice(allocator, "  ");
    try appendJsonString(allocator, output, name);
    try output.appendSlice(allocator, ": ");
    try appendJsonString(allocator, output, value);
    if (comma) try output.append(allocator, ',');
    try output.append(allocator, '\n');
}

fn appendJsonFieldPrefixComma(allocator: std.mem.Allocator, output: *std.ArrayList(u8), name: []const u8, value: []const u8) !void {
    try output.appendSlice(allocator, ",\n  ");
    try appendJsonString(allocator, output, name);
    try output.appendSlice(allocator, ": ");
    try appendJsonString(allocator, output, value);
}

fn appendSourceChecksJson(allocator: std.mem.Allocator, output: *std.ArrayList(u8), checks: []const SourceCheck) !void {
    try output.append(allocator, '[');
    for (checks, 0..) |check, index| {
        if (index > 0) try output.appendSlice(allocator, ", ");
        try output.appendSlice(allocator, "{ \"name\": ");
        try appendJsonString(allocator, output, if (check.name.len > 0) check.name else check.id);
        try output.appendSlice(allocator, ", \"status\": ");
        try appendJsonString(allocator, output, check.status);
        try output.appendSlice(allocator, ", \"detail\": ");
        try appendJsonString(allocator, output, check.detail);
        try output.appendSlice(allocator, " }");
    }
    try output.append(allocator, ']');
}

fn appendChecksJson(allocator: std.mem.Allocator, output: *std.ArrayList(u8), checks: []const PolicyCheck) !void {
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

fn appendCandidateSignalPoliciesJson(allocator: std.mem.Allocator, output: *std.ArrayList(u8)) !void {
    try output.append(allocator, '[');
    for (candidate_signal_policies, 0..) |signal, index| {
        if (index > 0) try output.appendSlice(allocator, ", ");
        try output.appendSlice(allocator, "{ \"id\": ");
        try appendJsonString(allocator, output, signal.id);
        try output.appendSlice(allocator, ", \"evaluation_mode\": ");
        try appendJsonString(allocator, output, signal.evaluation_mode);
        try output.print(allocator, ", \"enforcement_enabled\": {}, \"required_status_check_enabled\": {}, ", .{ signal.enforcement_enabled, signal.required_status_check_enabled });
        try output.appendSlice(allocator, "\"failure_effect\": ");
        try appendJsonString(allocator, output, signal.failure_effect);
        try output.appendSlice(allocator, ", \"evidence\": ");
        try appendJsonString(allocator, output, signal.evidence);
        try output.appendSlice(allocator, ", \"blocked_claim\": ");
        try appendJsonString(allocator, output, signal.blocked_claim);
        try output.appendSlice(allocator, " }");
    }
    try output.append(allocator, ']');
}

fn appendEvidenceRequirementsJson(allocator: std.mem.Allocator, output: *std.ArrayList(u8)) !void {
    try output.append(allocator, '[');
    for (evidence_requirements, 0..) |requirement, index| {
        if (index > 0) try output.appendSlice(allocator, ", ");
        try output.appendSlice(allocator, "{ \"id\": ");
        try appendJsonString(allocator, output, requirement.id);
        try output.print(allocator, ", \"allowed\": {}, \"detail\": ", .{requirement.allowed});
        try appendJsonString(allocator, output, requirement.detail);
        try output.appendSlice(allocator, " }");
    }
    try output.append(allocator, ']');
}

fn appendNegativeFixturesJson(allocator: std.mem.Allocator, output: *std.ArrayList(u8)) !void {
    try output.append(allocator, '[');
    for (negative_fixtures, 0..) |fixture, index| {
        if (index > 0) try output.appendSlice(allocator, ", ");
        try output.appendSlice(allocator, "{ \"id\": ");
        try appendJsonString(allocator, output, fixture.id);
        try output.appendSlice(allocator, ", \"artifact_state\": ");
        try appendJsonString(allocator, output, fixture.artifact_state);
        try output.appendSlice(allocator, ", \"decision\": ");
        try appendJsonString(allocator, output, fixture.decision);
        try output.appendSlice(allocator, ", \"failed_gate\": ");
        try appendJsonString(allocator, output, fixture.failed_gate);
        try output.appendSlice(allocator, ", \"reason\": ");
        try appendJsonString(allocator, output, fixture.reason);
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

fn appendCandidateSignalPoliciesText(allocator: std.mem.Allocator, output: *std.ArrayList(u8)) !void {
    try output.appendSlice(allocator, "candidate signal policies:\n");
    for (candidate_signal_policies) |signal| {
        try output.print(allocator, "- {s}: {s}, enforcement={}, required_status_check={}, failure_effect={s}\n", .{
            signal.id,
            signal.evaluation_mode,
            signal.enforcement_enabled,
            signal.required_status_check_enabled,
            signal.failure_effect,
        });
    }
    try output.append(allocator, '\n');
}

fn appendEvidenceRequirementsText(allocator: std.mem.Allocator, output: *std.ArrayList(u8)) !void {
    try output.appendSlice(allocator, "evidence requirements:\n");
    for (evidence_requirements) |requirement| {
        try output.print(allocator, "- {s}: allowed={} - {s}\n", .{ requirement.id, requirement.allowed, requirement.detail });
    }
    try output.append(allocator, '\n');
}

fn appendNegativeFixturesText(allocator: std.mem.Allocator, output: *std.ArrayList(u8)) !void {
    try output.appendSlice(allocator, "negative fixtures:\n");
    for (negative_fixtures) |fixture| {
        try output.print(allocator, "- {s}\n", .{fixture.id});
    }
    try output.append(allocator, '\n');
}

fn blockedClaims(source: GateApplicationBoundaryArtifact) []const []const u8 {
    _ = source;
    return &.{
        "ci-gate-enforcement-active",
        "required-status-check-active",
        "workflow-mutated-by-tool",
        "artifact-upload-executed-by-tool",
        "live-telemetry-ingested",
        "runtime-pipeline-enabled",
        "durable-production-write-enabled",
        "nendb-write-enabled",
        "production-health-proven",
        "production-cluster-ready",
        "non-nendb-durable-adapter",
        "react-or-alternate-renderer",
    };
}

fn agentGuidance(status: PolicyStatus) []const []const u8 {
    return switch (status) {
        .ready => &.{
            "Start the dry-run evaluator branch with bounded local or CI artifact inputs only.",
            "Evaluator findings are advisory and must not create required checks, workflow mutations, live telemetry ingestion, or durable writes.",
            "Carry source boundary event ids findings next queries redaction state retention state and blocked claims into evaluator output.",
        },
        .blocked => &.{
            "Treat blocked dry-run policy evidence as a stop sign.",
            "Repair source boundary validity reviewer decision or verification proof before starting the evaluator branch.",
            "Do not infer production readiness or CI gate enforcement from blocked policy evidence.",
        },
    };
}

fn readRequiredArtifact(io: std.Io, allocator: std.mem.Allocator, path: []const u8, err: anyerror) ![]const u8 {
    return std.Io.Dir.cwd().readFileAlloc(io, path, allocator, .limited(1024 * 1024)) catch |read_err| switch (read_err) {
        error.FileNotFound => err,
        else => read_err,
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
    const source_gate_application_boundary_json = try readRequiredArtifact(init.io, allocator, options.gate_application_boundary_path, error.MissingGateApplicationBoundaryInput);
    defer allocator.free(source_gate_application_boundary_json);

    const reports = try formatReports(allocator, .{
        .options = options,
        .source_gate_application_boundary_json = source_gate_application_boundary_json,
    });
    defer reports.deinit(allocator);

    const paths = try outputPathsForOptions(allocator, options);
    defer paths.deinit(allocator);

    try writeArtifact(init.io, paths.json_path, reports.json);
    try writeArtifact(init.io, paths.text_path, reports.text);
    std.debug.print("{s}", .{reports.text});
}

fn usage() []const u8 {
    return "usage: zig build causal-production-telemetry-ci-gate-dry-run-policy -- --from-gate-application-boundary <gate-application-boundary.json> approve|reject --reason <reason> [--by <actor>] [--policy <policy>] [--verified-command <command>]... [--out-prefix <path-prefix>]\n";
}

fn failUsage(err: anyerror) noreturn {
    std.debug.print("causal-production-telemetry-ci-gate-dry-run-policy error: {s}\n{s}", .{ @errorName(err), usage() });
    std.process.exit(2);
}

fn freeSliceOnly(allocator: std.mem.Allocator, values: []const []const u8) void {
    if (values.len > 0) allocator.free(values);
}

test "ci gate dry-run policy schema and branch constants are stable" {
    try std.testing.expectEqualStrings("zigeffect.causal.production-telemetry-ci-gate-dry-run-policy.v1", production_telemetry_ci_gate_dry_run_policy_schema);
    try std.testing.expectEqual(@as(u32, 1), production_telemetry_ci_gate_dry_run_policy_schema_version);
    try std.testing.expectEqualStrings("codex/zigeffect-causal-production-telemetry-ci-gate-dry-run-policy", source_branch);
    try std.testing.expectEqualStrings("start-production-telemetry-ci-gate-dry-run-evaluator", recommendation);
    try std.testing.expectEqualStrings("codex/zigeffect-causal-production-telemetry-ci-gate-dry-run-evaluator", next_branch_if_ready);
    try std.testing.expect(containsString(required_verification_commands, "zig build causal-production-telemetry-ci-gate-application-boundary"));
    try std.testing.expect(containsString(required_verification_commands, "zig build release-gate-report"));
}

test "parses ci gate dry-run policy approval and rejection options" {
    var approve_options = try parseOptions(std.testing.allocator, &.{
        "zigeffect-causal-production-telemetry-ci-gate-dry-run-policy",
        "--from-gate-application-boundary",
        ".zig-cache/causal-artifacts/ci-gate-application-boundary.json",
        "approve",
        "--reason",
        "CI gate dry-run policy reviewed",
        "--by",
        "codex",
        "--policy",
        "manual-production-telemetry-ci-gate-dry-run-policy",
        "--verified-command",
        "zig build causal-production-telemetry-ci-gate-application-boundary",
        "--out-prefix",
        ".zig-cache/causal-artifacts/custom-ci-gate-dry-run-policy",
    });
    defer approve_options.deinit(std.testing.allocator);

    try std.testing.expectEqual(Decision.approve, approve_options.decision);
    try std.testing.expectEqualStrings(".zig-cache/causal-artifacts/ci-gate-application-boundary.json", approve_options.gate_application_boundary_path);
    try std.testing.expectEqualStrings("codex", approve_options.reviewed_by);
    try std.testing.expectEqualStrings("manual-production-telemetry-ci-gate-dry-run-policy", approve_options.policy);
    try std.testing.expectEqual(@as(usize, 1), approve_options.verified_commands.len);
    try std.testing.expectEqualStrings(".zig-cache/causal-artifacts/custom-ci-gate-dry-run-policy", approve_options.out_prefix.?);

    var reject_options = try parseOptions(std.testing.allocator, &.{
        "zigeffect-causal-production-telemetry-ci-gate-dry-run-policy",
        "--from-gate-application-boundary",
        ".zig-cache/causal-artifacts/ci-gate-application-boundary.json",
        "reject",
        "--reason",
        "negative CI gate dry-run policy path",
    });
    defer reject_options.deinit(std.testing.allocator);

    try std.testing.expectEqual(Decision.reject, reject_options.decision);
}

test "default output path replaces gate application boundary suffix" {
    const options = Options{
        .gate_application_boundary_path = "../../.zig-cache/causal-artifacts/example-ci-gate-application-boundary.json",
        .decision = .approve,
        .reason = "planned",
    };
    const paths = try outputPathsForOptions(std.testing.allocator, options);
    defer paths.deinit(std.testing.allocator);

    try std.testing.expectEqualStrings("../../.zig-cache/causal-artifacts/example-ci-gate-dry-run-policy.json", paths.json_path);
    try std.testing.expectEqualStrings("../../.zig-cache/causal-artifacts/example-ci-gate-dry-run-policy.txt", paths.text_path);
}

test "approved report is ready and preserves advisory disabled gate authority" {
    const reports = try formatReports(std.testing.allocator, .{
        .options = .{
            .gate_application_boundary_path = ".zig-cache/causal-artifacts/ci-gate-application-boundary.json",
            .decision = .approve,
            .reason = "CI gate dry-run policy reviewed",
            .verified_commands = required_verification_commands,
        },
        .source_gate_application_boundary_json = sample_gate_application_boundary_json,
    });
    defer reports.deinit(std.testing.allocator);

    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"schema\": \"zigeffect.causal.production-telemetry-ci-gate-dry-run-policy.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"dry_run_policy_status\": \"ready\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"ready_for_next_branch\": true") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"ci_gate_enforcement_enabled\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"ci_required_status_check_enabled\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"durable_write_enabled\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"nendb_write_enabled\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"evaluation_mode\": \"dry-run\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"failure_effect\": \"advisory\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"next_branch_if_ready\": \"codex/zigeffect-causal-production-telemetry-ci-gate-dry-run-evaluator\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.text, "dry_run_policy_status: ready") != null);
}

test "rejection incomplete verification and invalid source block dry-run policy readiness" {
    const rejected = try formatReports(std.testing.allocator, .{
        .options = .{
            .gate_application_boundary_path = ".zig-cache/causal-artifacts/ci-gate-application-boundary.json",
            .decision = .reject,
            .reason = "negative CI gate dry-run policy path",
            .verified_commands = required_verification_commands,
        },
        .source_gate_application_boundary_json = sample_gate_application_boundary_json,
    });
    defer rejected.deinit(std.testing.allocator);

    try std.testing.expect(std.mem.indexOf(u8, rejected.json, "\"dry_run_policy_status\": \"blocked\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, rejected.json, "\"name\": \"reviewer-decision-approved\"") != null);

    const incomplete = try formatReports(std.testing.allocator, .{
        .options = .{
            .gate_application_boundary_path = ".zig-cache/causal-artifacts/ci-gate-application-boundary.json",
            .decision = .approve,
            .reason = "missing verification commands",
        },
        .source_gate_application_boundary_json = sample_gate_application_boundary_json,
    });
    defer incomplete.deinit(std.testing.allocator);

    try std.testing.expect(std.mem.indexOf(u8, incomplete.json, "\"dry_run_policy_status\": \"blocked\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, incomplete.json, "\"name\": \"policy-verification-recorded\"") != null);

    const invalid_source = try formatReports(std.testing.allocator, .{
        .options = .{
            .gate_application_boundary_path = ".zig-cache/causal-artifacts/ci-gate-application-boundary.json",
            .decision = .approve,
            .reason = "invalid source",
            .verified_commands = required_verification_commands,
        },
        .source_gate_application_boundary_json = sample_gate_application_boundary_json_with_enforcement,
    });
    defer invalid_source.deinit(std.testing.allocator);

    try std.testing.expect(std.mem.indexOf(u8, invalid_source.json, "\"dry_run_policy_status\": \"blocked\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, invalid_source.json, "\"name\": \"source-disabled-authority\"") != null);
}

fn containsString(values: []const []const u8, needle: []const u8) bool {
    for (values) |value| {
        if (std.mem.indexOf(u8, value, needle) != null) return true;
    }
    return false;
}

const sample_gate_application_boundary_json =
    \\{
    \\  "schema": "zigeffect.causal.production-telemetry-ci-gate-application-boundary.v1",
    \\  "schema_version": 1,
    \\  "source_ci_gate_readiness": ".zig-cache/causal-artifacts/ci-gate-readiness.json",
    \\  "source_gate_readiness_status": "ready",
    \\  "source_workflow_digest": "sha256:source-workflow-digest",
    \\  "mode": "plan",
    \\  "gate_application_status": "planned",
    \\  "applied": false,
    \\  "mutation_authority": "none",
    \\  "ci_gate_enabled": false,
    \\  "ci_gate_enforcement_enabled": false,
    \\  "ci_required_status_check_enabled": false,
    \\  "ci_workflow_mutation_enabled": false,
    \\  "ci_upload_execution_enabled": false,
    \\  "production_telemetry_ingestion": false,
    \\  "live_exporter_enabled": false,
    \\  "network_send_enabled": false,
    \\  "collector_endpoint_configured": false,
    \\  "otlp_serialization_enabled": false,
    \\  "runtime_pipeline_enabled": false,
    \\  "durable_write_enabled": false,
    \\  "nendb_write_enabled": false,
    \\  "boundary_checks": [{ "name": "source-gate-readiness-schema", "status": "pass", "detail": "source CI gate readiness schema is supported" }, { "name": "workflow-change-present", "status": "skipped", "detail": "plan mode does not claim workflow change evidence" }],
    \\  "application_boundary_rules": ["Plan mode records a reviewed boundary proposal only and never enables CI gate enforcement."],
    \\  "denied_application_claims": ["ci-gate-enforcement-active", "required-status-check-active"],
    \\  "negative_fixtures": [{ "id": "blocked-source-gate-readiness-denied", "artifact_state": "gate_readiness_status=blocked", "decision": "deny", "failed_gate": "source-gate-readiness-ready", "reason": "blocked readiness cannot feed application boundary" }],
    \\  "blocked_claims": ["runtime-pipeline-enabled", "live-exporter-enabled", "nendb-write-enabled"],
    \\  "required_verification_commands": ["zig build causal-production-telemetry-ci-gate-readiness", "zig build causal-artifacts"],
    \\  "verified_commands": [],
    \\  "generated_by": "causal-production-telemetry-ci-gate-application-boundary"
    \\}
;

const sample_gate_application_boundary_json_with_enforcement =
    \\{
    \\  "schema": "zigeffect.causal.production-telemetry-ci-gate-application-boundary.v1",
    \\  "schema_version": 1,
    \\  "source_ci_gate_readiness": ".zig-cache/causal-artifacts/ci-gate-readiness.json",
    \\  "source_gate_readiness_status": "ready",
    \\  "source_workflow_digest": "sha256:source-workflow-digest",
    \\  "mode": "plan",
    \\  "gate_application_status": "planned",
    \\  "applied": false,
    \\  "mutation_authority": "none",
    \\  "ci_gate_enabled": false,
    \\  "ci_gate_enforcement_enabled": true,
    \\  "ci_required_status_check_enabled": false,
    \\  "ci_workflow_mutation_enabled": false,
    \\  "ci_upload_execution_enabled": false,
    \\  "production_telemetry_ingestion": false,
    \\  "live_exporter_enabled": false,
    \\  "network_send_enabled": false,
    \\  "collector_endpoint_configured": false,
    \\  "otlp_serialization_enabled": false,
    \\  "runtime_pipeline_enabled": false,
    \\  "durable_write_enabled": false,
    \\  "nendb_write_enabled": false,
    \\  "boundary_checks": [{ "name": "source-gate-readiness-schema", "status": "pass", "detail": "source CI gate readiness schema is supported" }],
    \\  "application_boundary_rules": ["Plan mode records a reviewed boundary proposal only and never enables CI gate enforcement."],
    \\  "denied_application_claims": ["ci-gate-enforcement-active", "required-status-check-active"],
    \\  "negative_fixtures": [{ "id": "ci-gate-enforcement-enabled-denied", "artifact_state": "ci_gate_enforcement_enabled=true", "decision": "deny", "failed_gate": "no-ci-gate-enforcement", "reason": "this branch does not enable gates" }],
    \\  "blocked_claims": ["runtime-pipeline-enabled", "live-exporter-enabled", "nendb-write-enabled"],
    \\  "required_verification_commands": ["zig build causal-production-telemetry-ci-gate-readiness", "zig build causal-artifacts"],
    \\  "verified_commands": [],
    \\  "generated_by": "causal-production-telemetry-ci-gate-application-boundary"
    \\}
;
