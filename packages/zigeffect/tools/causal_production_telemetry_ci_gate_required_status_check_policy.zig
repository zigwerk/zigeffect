const std = @import("std");

pub const production_telemetry_ci_gate_required_status_check_policy_schema = "zigeffect.causal.production-telemetry-ci-gate-required-status-check-policy.v1";
pub const production_telemetry_ci_gate_required_status_check_policy_schema_version: u32 = 1;
pub const source_branch = "codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-policy";
pub const recommendation = "start-production-telemetry-ci-gate-required-status-check-enforcement-readiness";
pub const next_branch_if_ready = "codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-enforcement-readiness";

const application_boundary_schema = "zigeffect.causal.production-telemetry-ci-gate-required-status-check-application-boundary.v1";
const generated_by = "causal-production-telemetry-ci-gate-required-status-check-policy";

const required_verification_commands: []const []const u8 = &.{
    "zig build causal-production-telemetry-ci-gate-required-status-check-application-boundary",
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
const ci_report_publication_enabled = false;
const github_api_mutation_enabled = false;
const github_check_run_creation_enabled = false;
const branch_protection_mutation_by_tool_enabled = false;
const github_step_summary_write_enabled = false;
const pull_request_comment_enabled = false;
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
    application_boundary_path: []const u8,
    decision: Decision,
    reviewed_by: []const u8 = "ci-gate-required-status-check-policy-reviewer",
    policy: []const u8 = "manual-production-telemetry-ci-gate-required-status-check-policy",
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
    source_application_boundary_json: []const u8,
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

const SourceRequiredStatusCheckProfile = struct {
    id: []const u8,
    activation_enabled: bool,
    source: []const u8 = "",
    intended_future_signal: []const u8 = "",
    denied_claim: []const u8 = "",
};

const ApplicationBoundaryArtifact = struct {
    schema: []const u8,
    schema_version: u32,
    source_readiness: []const u8 = "",
    source_readiness_status: []const u8 = "",
    source_decision: []const u8 = "",
    source_ready_for_next_branch: bool = false,
    source_mutation_authority: []const u8 = "",
    source_after_report_digest: []const u8 = "",
    mode: []const u8,
    required_status_check_application_status: []const u8,
    applied: bool,
    mutation_authority: []const u8,
    ci_gate_enabled: bool,
    ci_gate_enforcement_enabled: bool,
    ci_required_status_check_enabled: bool,
    ci_workflow_mutation_enabled: bool,
    ci_upload_execution_enabled: bool,
    ci_report_publication_enabled: bool,
    github_api_mutation_enabled: bool,
    github_check_run_creation_enabled: bool,
    branch_protection_mutation_by_tool_enabled: bool,
    github_step_summary_write_enabled: bool,
    pull_request_comment_enabled: bool,
    production_telemetry_ingestion: bool,
    live_exporter_enabled: bool,
    network_send_enabled: bool,
    collector_endpoint_configured: bool,
    otlp_serialization_enabled: bool,
    runtime_pipeline_enabled: bool,
    durable_write_enabled: bool,
    nendb_write_enabled: bool,
    required_check_profile: ?[]const u8 = null,
    branch_protection_changes: []const []const u8 = &.{},
    workflow_changes: []const []const u8 = &.{},
    check_run_changes: []const []const u8 = &.{},
    before_evidence: []const []const u8 = &.{},
    after_evidence: []const []const u8 = &.{},
    application_checks: []const SourceCheck = &.{},
    source_required_status_check_profiles: []const SourceRequiredStatusCheckProfile = &.{},
    denied_inference_rules: []const []const u8 = &.{},
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

const RequiredCheckSurfacePolicy = struct {
    id: []const u8,
    surface: []const u8,
    source_state: []const u8,
    source_applied: bool,
    allowed_use: []const u8,
    failure_effect: []const u8,
    tool_mutation_enabled: bool,
    merge_blocker_claim_allowed: bool,
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

const required_status_check_policy_rules: []const []const u8 = &.{
    "Required status check policy is a record-only interpretation artifact.",
    "Planned source artifacts may inform enforcement-readiness design only.",
    "Applied source artifacts may be cited as reviewed external evidence only.",
    "This tool never mutates GitHub, branch protection, workflows, or check runs.",
    "Policy readiness is not production health, deployment success, customer impact, or cluster readiness.",
};

const required_check_surface_policy: []const RequiredCheckSurfacePolicy = &.{
    .{ .id = "planned-required-check-surface", .surface = "branch-protection-required-status-check", .source_state = "planned", .source_applied = false, .allowed_use = "design enforcement-readiness evidence only", .failure_effect = "none", .tool_mutation_enabled = false, .merge_blocker_claim_allowed = false },
    .{ .id = "applied-required-check-surface", .surface = "branch-protection-required-status-check", .source_state = "applied", .source_applied = true, .allowed_use = "reviewed external evidence only", .failure_effect = "external-record-only", .tool_mutation_enabled = false, .merge_blocker_claim_allowed = false },
};

const denied_inference_rules: []const []const u8 = &.{
    "planned-policy-is-not-active-required-status-check",
    "applied-source-is-not-tool-github-mutation-proof",
    "policy-readiness-is-not-branch-protection-mutation",
    "policy-readiness-is-not-workflow-mutation",
    "policy-readiness-is-not-check-run-creation",
    "policy-readiness-is-not-github-api-mutation",
    "policy-readiness-is-not-ci-artifact-upload-execution",
    "policy-readiness-is-not-github-step-summary-or-pr-comment-proof-by-tool",
    "policy-readiness-is-not-production-health-proof",
    "policy-readiness-is-not-deployment-success-proof",
    "policy-readiness-is-not-capacity-proof",
    "policy-readiness-is-not-customer-impact-proof",
    "policy-readiness-is-not-production-cluster-readiness-proof",
    "policy-readiness-is-not-live-telemetry-coverage-proof",
    "policy-readiness-is-not-durable-or-nendb-write-proof",
    "policy-readiness-grants-no-mutation-authority",
};

const evidence_requirements: []const EvidenceRequirement = &.{
    .{ .id = "causal-json-artifacts", .allowed = true, .detail = "bounded causal JSON artifacts generated by zigeffect tests or examples" },
    .{ .id = "causal-text-artifacts", .allowed = true, .detail = "bounded causal text artifacts generated by zigeffect tests or examples" },
    .{ .id = "release-gate-json-artifacts", .allowed = true, .detail = "release-gate JSON reports from zig build release-gate" },
    .{ .id = "release-gate-text-artifacts", .allowed = true, .detail = "release-gate text reports from zig build release-gate-report" },
    .{ .id = "ci-handoff-artifacts", .allowed = true, .detail = "bounded failure handoff text or JSON generated by causal CI handoff" },
    .{ .id = "source-policy-artifacts", .allowed = true, .detail = "reviewed source policy artifacts from the causal production telemetry chain" },
    .{ .id = "secret-values", .allowed = false, .detail = "secret-shaped values credentials tokens and raw private headers are never valid evidence" },
    .{ .id = "network-or-live-telemetry", .allowed = false, .detail = "required-status-check policy must not call networks or ingest live telemetry" },
    .{ .id = "production-database-writes", .allowed = false, .detail = "required-status-check policy must not write production databases or durable stores" },
    .{ .id = "non-nendb-durable-adapters", .allowed = false, .detail = "durable direction remains NenDB adapter only" },
};

const negative_fixtures: []const NegativeFixture = &.{
    .{ .id = "blocked-source-application-denied", .artifact_state = "required_status_check_application_status=blocked", .decision = "deny", .failed_gate = "source-application-status-valid", .reason = "blocked application boundary cannot feed required-status-check policy" },
    .{ .id = "ci-gate-enforcement-claim-denied", .artifact_state = "ci_gate_enforcement_enabled=true", .decision = "deny", .failed_gate = "source-disabled-authority", .reason = "required-status-check policy cannot enable CI gate enforcement" },
    .{ .id = "required-status-check-claim-denied", .artifact_state = "ci_required_status_check_enabled=true", .decision = "deny", .failed_gate = "source-disabled-authority", .reason = "required checks are out of scope" },
    .{ .id = "workflow-mutation-claim-denied", .artifact_state = "ci_workflow_mutation_enabled=true", .decision = "deny", .failed_gate = "source-disabled-authority", .reason = "policy does not mutate workflows" },
    .{ .id = "missing-release-gate-verification-denied", .artifact_state = "verified commands omit release gate or report", .decision = "deny", .failed_gate = "policy-verification-recorded", .reason = "required-status-check policy needs release-gate and release-gate-report verification evidence" },
    .{ .id = "production-health-claim-denied", .artifact_state = "production_health=proven", .decision = "deny", .failed_gate = "required-status-check-is-not-production", .reason = "CI evidence is not live production telemetry" },
    .{ .id = "public-upload-claim-denied", .artifact_state = "artifact_visibility=public", .decision = "deny", .failed_gate = "bounded-private-evidence", .reason = "required-status-check evidence remains bounded local or CI artifact evidence" },
    .{ .id = "retention-too-long-denied", .artifact_state = "retention_days=90", .decision = "deny", .failed_gate = "bounded-retention", .reason = "required-status-check artifact retention remains fourteen days or less" },
    .{ .id = "secret-shaped-evidence-denied", .artifact_state = "evidence contains token or secret", .decision = "deny", .failed_gate = "no-secret-evidence", .reason = "secret-shaped evidence cannot enter required-status-check policy artifacts" },
    .{ .id = "live-telemetry-denied", .artifact_state = "collector_endpoint_configured=true", .decision = "deny", .failed_gate = "no-live-telemetry", .reason = "required-status-check policy does not configure collectors" },
    .{ .id = "durable-write-denied", .artifact_state = "durable_write_enabled=true", .decision = "deny", .failed_gate = "no-durable-writes", .reason = "required-status-check policy does not write durable stores" },
    .{ .id = "nendb-write-denied", .artifact_state = "nendb_write_enabled=true", .decision = "deny", .failed_gate = "no-nendb-writes", .reason = "NenDB remains future adapter work, not required-status-check policy output" },
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
        error.MissingApplicationBoundaryInput => failUsage(err),
        else => return err,
    };
}

fn parseOptions(allocator: std.mem.Allocator, args: []const []const u8) !Options {
    if (args.len < 2) return error.MissingApplicationBoundaryPath;
    if (!std.mem.eql(u8, args[1], "--from-application-boundary")) return error.UnknownFlag;
    if (args.len < 3) return error.MissingApplicationBoundaryPath;
    const application_boundary_path = args[2];
    if (!std.mem.endsWith(u8, application_boundary_path, ".json")) return error.InvalidApplicationBoundaryPath;
    if (args.len < 4) return error.MissingDecision;
    const decision = try parseDecision(args[3]);

    var reviewed_by: []const u8 = "ci-gate-required-status-check-policy-reviewer";
    var policy: []const u8 = "manual-production-telemetry-ci-gate-required-status-check-policy";
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
        .application_boundary_path = application_boundary_path,
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
        if (!std.mem.endsWith(u8, options.application_boundary_path, ".json")) return error.InvalidApplicationBoundaryPath;
        if (std.mem.endsWith(u8, options.application_boundary_path, "-ci-gate-required-status-check-application-boundary.json")) {
            const suffix_len = "-ci-gate-required-status-check-application-boundary.json".len;
            break :blk try std.fmt.allocPrint(allocator, "{s}-ci-gate-required-status-check-policy", .{options.application_boundary_path[0 .. options.application_boundary_path.len - suffix_len]});
        }
        const base = options.application_boundary_path[0 .. options.application_boundary_path.len - ".json".len];
        break :blk try std.fmt.allocPrint(allocator, "{s}-ci-gate-required-status-check-policy", .{base});
    };
    defer allocator.free(prefix);

    return .{
        .json_path = try std.fmt.allocPrint(allocator, "{s}.json", .{prefix}),
        .text_path = try std.fmt.allocPrint(allocator, "{s}.txt", .{prefix}),
    };
}

fn formatReports(allocator: std.mem.Allocator, input: PolicyInput) !PolicyReports {
    var parsed = try std.json.parseFromSlice(ApplicationBoundaryArtifact, allocator, input.source_application_boundary_json, .{ .ignore_unknown_fields = true });
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
    source: ApplicationBoundaryArtifact,
) !PolicyResult {
    var checks = std.ArrayList(PolicyCheck).empty;
    errdefer checks.deinit(allocator);

    try appendCheck(allocator, &checks, "source-schema", if (std.mem.eql(u8, source.schema, application_boundary_schema) and source.schema_version == 1) .pass else .fail, "source required status check application-boundary schema is supported");
    try appendCheck(allocator, &checks, "source-boundary-status-valid", if (sourceBoundaryStatusValid(source)) .pass else .fail, "source required status check application-boundary is planned or applied, never blocked");
    try appendCheck(allocator, &checks, "source-application-state-consistent", if (sourceApplicationStateConsistent(source)) .pass else .fail, "source mode applied flag and mutation authority are internally consistent");
    try appendCheck(allocator, &checks, "source-tool-authority-disabled", if (sourceToolAuthorityDisabled(source)) .pass else .fail, "source keeps GitHub branch protection workflow check-run upload summary and comment authority disabled");
    try appendCheck(allocator, &checks, "source-ci-enforcement-disabled", if (sourceCiEnforcementDisabled(source)) .pass else .fail, "source keeps CI gate enforcement and required checks disabled by the tool");
    try appendCheck(allocator, &checks, "source-runtime-and-storage-disabled", if (sourceRuntimeAndStorageDisabled(source)) .pass else .fail, "source keeps live telemetry network collector OTLP runtime durable and NenDB writes disabled");
    try appendCheck(allocator, &checks, "source-checks-passed", if (sourceBoundaryChecksHaveNoFailures(source.application_checks)) .pass else .fail, "source application checks contain no failures");
    try appendCheck(allocator, &checks, "source-catalogs-present", if (sourceCatalogsPresent(source)) .pass else .fail, "source profiles denied inference rules negative fixtures blocked claims and verification catalogs are present");
    try appendCheck(allocator, &checks, "source-applied-evidence-present", if (sourceAppliedEvidenceValid(source)) .pass else .fail, "applied sources include branch-protection before after and workflow or check-run evidence");
    try appendCheck(allocator, &checks, "policy-verification-recorded", if (verifiedCommandsContainAll(options.verified_commands, required_verification_commands)) .pass else .fail, "required-status-check policy review recorded every required verification command");
    try appendCheck(allocator, &checks, "release-gate-verification-recorded", if (verifiedCommandsContainAll(options.verified_commands, &.{ "zig build release-gate --summary none", "zig build release-gate-report" })) .pass else .fail, "release gate and release gate report commands are verified");
    try appendCheck(allocator, &checks, "reviewer-decision-approved", if (options.decision == .approve) .pass else .fail, "reviewer approved the required-status-check policy handoff");
    try appendCheck(allocator, &checks, "interpretation-rules-present", if (required_status_check_policy_rules.len > 0 and denied_inference_rules.len > 0) .pass else .fail, "allowed and denied interpretation rules are present");
    try appendCheck(allocator, &checks, "required-check-surface-policy-present", if (required_check_surface_policy.len > 0) .pass else .fail, "required-check surface policy is present and non-mutating");

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

fn sourceBoundaryStatusValid(source: ApplicationBoundaryArtifact) bool {
    return std.mem.eql(u8, source.required_status_check_application_status, "planned") or
        std.mem.eql(u8, source.required_status_check_application_status, "applied");
}

fn sourceApplicationStateConsistent(source: ApplicationBoundaryArtifact) bool {
    if (std.mem.eql(u8, source.required_status_check_application_status, "planned")) {
        return !source.applied and
            std.mem.eql(u8, source.mode, "plan") and
            std.mem.eql(u8, source.mutation_authority, "none");
    }
    if (std.mem.eql(u8, source.required_status_check_application_status, "applied")) {
        return source.applied and
            std.mem.eql(u8, source.mode, "record-applied") and
            std.mem.eql(u8, source.mutation_authority, "record-only");
    }
    return false;
}

fn sourceToolAuthorityDisabled(source: ApplicationBoundaryArtifact) bool {
    return !source.ci_workflow_mutation_enabled and
        !source.ci_upload_execution_enabled and
        !source.ci_report_publication_enabled and
        !source.github_api_mutation_enabled and
        !source.github_check_run_creation_enabled and
        !source.branch_protection_mutation_by_tool_enabled and
        !source.github_step_summary_write_enabled and
        !source.pull_request_comment_enabled;
}

fn sourceCiEnforcementDisabled(source: ApplicationBoundaryArtifact) bool {
    return !source.ci_gate_enabled and
        !source.ci_gate_enforcement_enabled and
        !source.ci_required_status_check_enabled;
}

fn sourceRuntimeAndStorageDisabled(source: ApplicationBoundaryArtifact) bool {
    return !source.production_telemetry_ingestion and
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

fn sourceCatalogsPresent(source: ApplicationBoundaryArtifact) bool {
    return source.source_required_status_check_profiles.len > 0 and
        source.denied_inference_rules.len > 0 and
        source.negative_fixtures.len > 0 and
        source.blocked_claims.len > 0 and
        source.required_verification_commands.len > 0;
}

fn sourceAppliedEvidenceValid(source: ApplicationBoundaryArtifact) bool {
    if (!std.mem.eql(u8, source.required_status_check_application_status, "applied")) return true;
    return source.branch_protection_changes.len > 0 and
        source.before_evidence.len > 0 and
        source.after_evidence.len > 0 and
        (source.workflow_changes.len > 0 or source.check_run_changes.len > 0);
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
    source: ApplicationBoundaryArtifact,
    result: PolicyResult,
    paths: OutputPaths,
) ![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "{\n");
    try appendJsonField(allocator, &output, "schema", production_telemetry_ci_gate_required_status_check_policy_schema, true);
    try output.appendSlice(allocator, "  \"schema_version\": 1,\n");
    try appendJsonField(allocator, &output, "source_application_boundary", options.application_boundary_path, true);
    try appendJsonField(allocator, &output, "source_application_status", source.required_status_check_application_status, true);
    try appendJsonField(allocator, &output, "source_application_mode", source.mode, true);
    try output.print(allocator, "  \"source_applied\": {},\n", .{source.applied});
    try appendJsonField(allocator, &output, "source_application_mutation_authority", source.mutation_authority, true);
    try appendJsonField(allocator, &output, "source_readiness", source.source_readiness, true);
    try appendJsonField(allocator, &output, "source_after_report_digest", source.source_after_report_digest, true);
    try appendJsonField(allocator, &output, "decision", decisionText(options.decision), true);
    try appendJsonField(allocator, &output, "reviewed_by", options.reviewed_by, true);
    try appendJsonField(allocator, &output, "policy", options.policy, true);
    try appendJsonField(allocator, &output, "reason", options.reason, true);
    try appendJsonField(allocator, &output, "required_status_check_policy_status", policyStatusText(result.status), true);
    try output.print(allocator, "  \"ready_for_next_branch\": {},\n", .{result.ready_for_next_branch});
    try output.print(allocator, "  \"ci_gate_enabled\": {},\n", .{ci_gate_enabled});
    try output.print(allocator, "  \"ci_gate_enforcement_enabled\": {},\n", .{ci_gate_enforcement_enabled});
    try output.print(allocator, "  \"ci_required_status_check_enabled\": {},\n", .{ci_required_status_check_enabled});
    try output.print(allocator, "  \"ci_workflow_mutation_enabled\": {},\n", .{ci_workflow_mutation_enabled});
    try output.print(allocator, "  \"ci_upload_execution_enabled\": {},\n", .{ci_upload_execution_enabled});
    try output.print(allocator, "  \"ci_report_publication_enabled\": {},\n", .{ci_report_publication_enabled});
    try output.print(allocator, "  \"github_api_mutation_enabled\": {},\n", .{github_api_mutation_enabled});
    try output.print(allocator, "  \"github_check_run_creation_enabled\": {},\n", .{github_check_run_creation_enabled});
    try output.print(allocator, "  \"branch_protection_mutation_by_tool_enabled\": {},\n", .{branch_protection_mutation_by_tool_enabled});
    try output.print(allocator, "  \"github_step_summary_write_enabled\": {},\n", .{github_step_summary_write_enabled});
    try output.print(allocator, "  \"pull_request_comment_enabled\": {},\n", .{pull_request_comment_enabled});
    try output.print(allocator, "  \"production_telemetry_ingestion\": {},\n", .{production_telemetry_ingestion});
    try output.print(allocator, "  \"live_exporter_enabled\": {},\n", .{live_exporter_enabled});
    try output.print(allocator, "  \"network_send_enabled\": {},\n", .{network_send_enabled});
    try output.print(allocator, "  \"collector_endpoint_configured\": {},\n", .{collector_endpoint_configured});
    try output.print(allocator, "  \"otlp_serialization_enabled\": {},\n", .{otlp_serialization_enabled});
    try output.print(allocator, "  \"runtime_pipeline_enabled\": {},\n", .{runtime_pipeline_enabled});
    try output.print(allocator, "  \"durable_write_enabled\": {},\n", .{durable_write_enabled});
    try output.print(allocator, "  \"nendb_write_enabled\": {},\n", .{nendb_write_enabled});
    try output.appendSlice(allocator, "  \"required_status_check_policy_rules\": ");
    try appendStringArray(allocator, &output, required_status_check_policy_rules);
    try output.appendSlice(allocator, ",\n  \"denied_inference_rules\": ");
    try appendStringArray(allocator, &output, denied_inference_rules);
    try output.appendSlice(allocator, ",\n  \"required_check_surface_policy\": ");
    try appendRequiredCheckSurfacePolicyJson(allocator, &output);
    try output.appendSlice(allocator, ",\n  \"evidence_requirements\": ");
    try appendEvidenceRequirementsJson(allocator, &output);
    try output.appendSlice(allocator, ",\n  \"source_application_checks\": ");
    try appendSourceChecksJson(allocator, &output, source.application_checks);
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
    source: ApplicationBoundaryArtifact,
    result: PolicyResult,
    paths: OutputPaths,
) ![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "zigeffect production telemetry CI gate required status check policy\n");
    try output.print(allocator, "schema: {s}\n", .{production_telemetry_ci_gate_required_status_check_policy_schema});
    try output.print(allocator, "source required status check application boundary: {s}\n", .{options.application_boundary_path});
    try output.print(allocator, "source application status: {s}\n", .{source.required_status_check_application_status});
    try output.print(allocator, "source application mode: {s}\n", .{source.mode});
    try output.print(allocator, "source applied: {}\n", .{source.applied});
    try output.print(allocator, "source application mutation authority: {s}\n", .{source.mutation_authority});
    try output.print(allocator, "decision: {s}\n", .{decisionText(options.decision)});
    try output.print(allocator, "required_status_check_policy_status: {s}\n", .{policyStatusText(result.status)});
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

    try appendTextList(allocator, &output, "required-status-check policy rules", required_status_check_policy_rules);
    try appendTextList(allocator, &output, "denied inference rules", denied_inference_rules);
    try appendRequiredCheckSurfacePolicyText(allocator, &output);
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

fn appendRequiredCheckSurfacePolicyJson(allocator: std.mem.Allocator, output: *std.ArrayList(u8)) !void {
    try output.append(allocator, '[');
    for (required_check_surface_policy, 0..) |policy, index| {
        if (index > 0) try output.appendSlice(allocator, ", ");
        try output.appendSlice(allocator, "{ \"id\": ");
        try appendJsonString(allocator, output, policy.id);
        try output.appendSlice(allocator, ", \"surface\": ");
        try appendJsonString(allocator, output, policy.surface);
        try output.appendSlice(allocator, ", \"source_state\": ");
        try appendJsonString(allocator, output, policy.source_state);
        try output.print(allocator, ", \"source_applied\": {}, ", .{policy.source_applied});
        try output.appendSlice(allocator, "\"allowed_use\": ");
        try appendJsonString(allocator, output, policy.allowed_use);
        try output.appendSlice(allocator, ", \"failure_effect\": ");
        try appendJsonString(allocator, output, policy.failure_effect);
        try output.print(allocator, ", \"tool_mutation_enabled\": {}, \"merge_blocker_claim_allowed\": {}", .{ policy.tool_mutation_enabled, policy.merge_blocker_claim_allowed });
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

fn appendRequiredCheckSurfacePolicyText(allocator: std.mem.Allocator, output: *std.ArrayList(u8)) !void {
    try output.appendSlice(allocator, "required check surface policy:\n");
    for (required_check_surface_policy) |policy| {
        try output.print(allocator, "- {s}: surface={s}, source_state={s}, source_applied={}, tool_mutation_enabled={}, merge_blocker_claim_allowed={}, failure_effect={s}\n", .{
            policy.id,
            policy.surface,
            policy.source_state,
            policy.source_applied,
            policy.tool_mutation_enabled,
            policy.merge_blocker_claim_allowed,
            policy.failure_effect,
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

fn blockedClaims(source: ApplicationBoundaryArtifact) []const []const u8 {
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
            "Start the required-status-check enforcement-readiness branch with bounded local or CI artifact inputs only.",
            "Enforcement-readiness findings remain record-only and must not create required checks, workflow mutations, live telemetry ingestion, or durable writes.",
            "Carry source application event ids findings next queries redaction state retention state and blocked claims into enforcement-readiness output.",
        },
        .blocked => &.{
            "Treat blocked required-status-check policy evidence as a stop sign.",
            "Repair source application validity reviewer decision or verification proof before starting the enforcement-readiness branch.",
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
    const source_application_boundary_json = try readRequiredArtifact(init.io, allocator, options.application_boundary_path, error.MissingApplicationBoundaryInput);
    defer allocator.free(source_application_boundary_json);

    const reports = try formatReports(allocator, .{
        .options = options,
        .source_application_boundary_json = source_application_boundary_json,
    });
    defer reports.deinit(allocator);

    const paths = try outputPathsForOptions(allocator, options);
    defer paths.deinit(allocator);

    try writeArtifact(init.io, paths.json_path, reports.json);
    try writeArtifact(init.io, paths.text_path, reports.text);
    std.debug.print("{s}", .{reports.text});
}

fn usage() []const u8 {
    return "usage: zig build causal-production-telemetry-ci-gate-required-status-check-policy -- --from-application-boundary <required-status-check-application-boundary.json> approve|reject --reason <reason> [--by <actor>] [--policy <policy>] [--verified-command <command>]... [--out-prefix <path-prefix>]\n";
}

fn failUsage(err: anyerror) noreturn {
    std.debug.print("causal-production-telemetry-ci-gate-required-status-check-policy error: {s}\n{s}", .{ @errorName(err), usage() });
    std.process.exit(2);
}

fn freeSliceOnly(allocator: std.mem.Allocator, values: []const []const u8) void {
    if (values.len > 0) allocator.free(values);
}

test "ci gate required status check policy schema and branch constants are stable" {
    try std.testing.expectEqualStrings("zigeffect.causal.production-telemetry-ci-gate-required-status-check-policy.v1", production_telemetry_ci_gate_required_status_check_policy_schema);
    try std.testing.expectEqual(@as(u32, 1), production_telemetry_ci_gate_required_status_check_policy_schema_version);
    try std.testing.expectEqualStrings("codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-policy", source_branch);
    try std.testing.expectEqualStrings("start-production-telemetry-ci-gate-required-status-check-enforcement-readiness", recommendation);
    try std.testing.expectEqualStrings("codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-enforcement-readiness", next_branch_if_ready);
    try std.testing.expect(containsString(required_verification_commands, "zig build causal-production-telemetry-ci-gate-required-status-check-application-boundary"));
    try std.testing.expect(containsString(required_verification_commands, "zig build release-gate-report"));
}

test "parses ci gate required status check policy approval and rejection options" {
    var approve_options = try parseOptions(std.testing.allocator, &.{
        "zigeffect-causal-production-telemetry-ci-gate-required-status-check-policy",
        "--from-application-boundary",
        ".zig-cache/causal-artifacts/required-status-check-application-boundary.json",
        "approve",
        "--reason",
        "required status check policy reviewed",
        "--by",
        "codex",
        "--policy",
        "manual-production-telemetry-ci-gate-required-status-check-policy",
        "--verified-command",
        "zig build causal-production-telemetry-ci-gate-required-status-check-application-boundary",
        "--out-prefix",
        ".zig-cache/causal-artifacts/custom-required-status-check-policy",
    });
    defer approve_options.deinit(std.testing.allocator);

    try std.testing.expectEqual(Decision.approve, approve_options.decision);
    try std.testing.expectEqualStrings(".zig-cache/causal-artifacts/required-status-check-application-boundary.json", approve_options.application_boundary_path);
    try std.testing.expectEqualStrings("codex", approve_options.reviewed_by);
    try std.testing.expectEqualStrings("manual-production-telemetry-ci-gate-required-status-check-policy", approve_options.policy);
    try std.testing.expectEqual(@as(usize, 1), approve_options.verified_commands.len);
    try std.testing.expectEqualStrings(".zig-cache/causal-artifacts/custom-required-status-check-policy", approve_options.out_prefix.?);

    var reject_options = try parseOptions(std.testing.allocator, &.{
        "zigeffect-causal-production-telemetry-ci-gate-required-status-check-policy",
        "--from-application-boundary",
        ".zig-cache/causal-artifacts/required-status-check-application-boundary.json",
        "reject",
        "--reason",
        "negative required status check policy path",
    });
    defer reject_options.deinit(std.testing.allocator);

    try std.testing.expectEqual(Decision.reject, reject_options.decision);
}

test "default output path replaces required status check application boundary suffix" {
    const options = Options{
        .application_boundary_path = "../../.zig-cache/causal-artifacts/example-ci-gate-required-status-check-application-boundary.json",
        .decision = .approve,
        .reason = "planned",
    };
    const paths = try outputPathsForOptions(std.testing.allocator, options);
    defer paths.deinit(std.testing.allocator);

    try std.testing.expectEqualStrings("../../.zig-cache/causal-artifacts/example-ci-gate-required-status-check-policy.json", paths.json_path);
    try std.testing.expectEqualStrings("../../.zig-cache/causal-artifacts/example-ci-gate-required-status-check-policy.txt", paths.text_path);
}

test "approved planned report is ready and preserves disabled authority" {
    const reports = try formatReports(std.testing.allocator, .{
        .options = .{
            .application_boundary_path = ".zig-cache/causal-artifacts/required-status-check-application-boundary.json",
            .decision = .approve,
            .reason = "required status check policy reviewed",
            .verified_commands = required_verification_commands,
        },
        .source_application_boundary_json = planned_application_boundary_json,
    });
    defer reports.deinit(std.testing.allocator);

    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"schema\": \"zigeffect.causal.production-telemetry-ci-gate-required-status-check-policy.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"required_status_check_policy_status\": \"ready\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"ready_for_next_branch\": true") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"source_applied\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"ci_gate_enforcement_enabled\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"ci_required_status_check_enabled\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"github_api_mutation_enabled\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"branch_protection_mutation_by_tool_enabled\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"durable_write_enabled\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"nendb_write_enabled\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"required_check_surface_policy\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"merge_blocker_claim_allowed\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"next_branch_if_ready\": \"codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-enforcement-readiness\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.text, "required_status_check_policy_status: ready") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.text, "source applied: false") != null);
}

test "approved applied report is ready and preserves source applied evidence" {
    const reports = try formatReports(std.testing.allocator, .{
        .options = .{
            .application_boundary_path = ".zig-cache/causal-artifacts/required-status-check-application-boundary-applied.json",
            .decision = .approve,
            .reason = "required status check policy reviewed",
            .verified_commands = required_verification_commands,
        },
        .source_application_boundary_json = applied_application_boundary_json,
    });
    defer reports.deinit(std.testing.allocator);

    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"required_status_check_policy_status\": \"ready\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"source_applied\": true") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.text, "source applied: true") != null);
}

test "rejection incomplete verification and invalid source block required-status-check policy readiness" {
    const rejected = try formatReports(std.testing.allocator, .{
        .options = .{
            .application_boundary_path = ".zig-cache/causal-artifacts/required-status-check-application-boundary.json",
            .decision = .reject,
            .reason = "negative required status check policy path",
            .verified_commands = required_verification_commands,
        },
        .source_application_boundary_json = planned_application_boundary_json,
    });
    defer rejected.deinit(std.testing.allocator);

    try std.testing.expect(std.mem.indexOf(u8, rejected.json, "\"required_status_check_policy_status\": \"blocked\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, rejected.json, "\"name\": \"reviewer-decision-approved\"") != null);

    const incomplete = try formatReports(std.testing.allocator, .{
        .options = .{
            .application_boundary_path = ".zig-cache/causal-artifacts/required-status-check-application-boundary.json",
            .decision = .approve,
            .reason = "missing verification commands",
        },
        .source_application_boundary_json = planned_application_boundary_json,
    });
    defer incomplete.deinit(std.testing.allocator);

    try std.testing.expect(std.mem.indexOf(u8, incomplete.json, "\"required_status_check_policy_status\": \"blocked\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, incomplete.json, "\"name\": \"policy-verification-recorded\"") != null);

    const invalid_source = try formatReports(std.testing.allocator, .{
        .options = .{
            .application_boundary_path = ".zig-cache/causal-artifacts/required-status-check-application-boundary.json",
            .decision = .approve,
            .reason = "invalid source",
            .verified_commands = required_verification_commands,
        },
        .source_application_boundary_json = application_boundary_json_with_enforcement,
    });
    defer invalid_source.deinit(std.testing.allocator);

    try std.testing.expect(std.mem.indexOf(u8, invalid_source.json, "\"required_status_check_policy_status\": \"blocked\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, invalid_source.json, "\"name\": \"source-ci-enforcement-disabled\"") != null);
}

fn containsString(values: []const []const u8, needle: []const u8) bool {
    for (values) |value| {
        if (std.mem.indexOf(u8, value, needle) != null) return true;
    }
    return false;
}

const planned_application_boundary_json =
    \\{
    \\  "schema": "zigeffect.causal.production-telemetry-ci-gate-required-status-check-application-boundary.v1",
    \\  "schema_version": 1,
    \\  "source_readiness": ".zig-cache/causal-artifacts/required-status-check-readiness.json",
    \\  "source_readiness_status": "ready",
    \\  "source_decision": "approve",
    \\  "source_ready_for_next_branch": true,
    \\  "source_mutation_authority": "none",
    \\  "source_after_report_digest": "sha256:source-report-digest",
    \\  "mode": "plan",
    \\  "required_status_check_application_status": "planned",
    \\  "applied": false,
    \\  "mutation_authority": "none",
    \\  "ci_gate_enabled": false,
    \\  "ci_gate_enforcement_enabled": false,
    \\  "ci_required_status_check_enabled": false,
    \\  "ci_workflow_mutation_enabled": false,
    \\  "ci_upload_execution_enabled": false,
    \\  "ci_report_publication_enabled": false,
    \\  "github_api_mutation_enabled": false,
    \\  "github_check_run_creation_enabled": false,
    \\  "branch_protection_mutation_by_tool_enabled": false,
    \\  "github_step_summary_write_enabled": false,
    \\  "pull_request_comment_enabled": false,
    \\  "production_telemetry_ingestion": false,
    \\  "live_exporter_enabled": false,
    \\  "network_send_enabled": false,
    \\  "collector_endpoint_configured": false,
    \\  "otlp_serialization_enabled": false,
    \\  "runtime_pipeline_enabled": false,
    \\  "durable_write_enabled": false,
    \\  "nendb_write_enabled": false,
    \\  "application_checks": [{ "name": "source-schema", "status": "pass", "detail": "source required-status-check readiness schema is supported" }],
    \\  "source_required_status_check_profiles": [{ "id": "release-gate", "activation_enabled": false, "source": "release gate", "intended_future_signal": "release gate report exists", "denied_claim": "active required check" }],
    \\  "denied_inference_rules": ["github-api-mutation-by-tool", "branch-protection-mutation-by-tool"],
    \\  "negative_fixtures": [{ "id": "blocked-source-denied", "artifact_state": "blocked", "decision": "deny", "failed_gate": "source-boundary-status-valid", "reason": "blocked source denied" }],
    \\  "blocked_claims": ["runtime-pipeline-enabled", "live-exporter-enabled", "nendb-write-enabled"],
    \\  "required_verification_commands": ["zig build causal-production-telemetry-ci-gate-required-status-check-readiness", "zig build causal-artifacts"],
    \\  "verified_commands": [],
    \\  "generated_by": "causal-production-telemetry-ci-gate-required-status-check-application-boundary"
    \\}
;

const applied_application_boundary_json =
    \\{
    \\  "schema": "zigeffect.causal.production-telemetry-ci-gate-required-status-check-application-boundary.v1",
    \\  "schema_version": 1,
    \\  "source_readiness": ".zig-cache/causal-artifacts/required-status-check-readiness.json",
    \\  "source_readiness_status": "ready",
    \\  "source_decision": "approve",
    \\  "source_ready_for_next_branch": true,
    \\  "source_mutation_authority": "none",
    \\  "source_after_report_digest": "sha256:source-report-digest",
    \\  "mode": "record-applied",
    \\  "required_status_check_application_status": "applied",
    \\  "applied": true,
    \\  "mutation_authority": "record-only",
    \\  "required_check_profile": "release-gate",
    \\  "branch_protection_changes": ["externally reviewed branch protection change"],
    \\  "workflow_changes": ["externally reviewed workflow change"],
    \\  "before_evidence": ["before required checks absent"],
    \\  "after_evidence": ["after required check recorded"],
    \\  "ci_gate_enabled": false,
    \\  "ci_gate_enforcement_enabled": false,
    \\  "ci_required_status_check_enabled": false,
    \\  "ci_workflow_mutation_enabled": false,
    \\  "ci_upload_execution_enabled": false,
    \\  "ci_report_publication_enabled": false,
    \\  "github_api_mutation_enabled": false,
    \\  "github_check_run_creation_enabled": false,
    \\  "branch_protection_mutation_by_tool_enabled": false,
    \\  "github_step_summary_write_enabled": false,
    \\  "pull_request_comment_enabled": false,
    \\  "production_telemetry_ingestion": false,
    \\  "live_exporter_enabled": false,
    \\  "network_send_enabled": false,
    \\  "collector_endpoint_configured": false,
    \\  "otlp_serialization_enabled": false,
    \\  "runtime_pipeline_enabled": false,
    \\  "durable_write_enabled": false,
    \\  "nendb_write_enabled": false,
    \\  "application_checks": [{ "name": "source-schema", "status": "pass", "detail": "source required-status-check readiness schema is supported" }],
    \\  "source_required_status_check_profiles": [{ "id": "release-gate", "activation_enabled": false, "source": "release gate", "intended_future_signal": "release gate report exists", "denied_claim": "active required check" }],
    \\  "denied_inference_rules": ["github-api-mutation-by-tool", "branch-protection-mutation-by-tool"],
    \\  "negative_fixtures": [{ "id": "blocked-source-denied", "artifact_state": "blocked", "decision": "deny", "failed_gate": "source-boundary-status-valid", "reason": "blocked source denied" }],
    \\  "blocked_claims": ["runtime-pipeline-enabled", "live-exporter-enabled", "nendb-write-enabled"],
    \\  "required_verification_commands": ["zig build causal-production-telemetry-ci-gate-required-status-check-readiness", "zig build causal-artifacts"],
    \\  "verified_commands": [],
    \\  "generated_by": "causal-production-telemetry-ci-gate-required-status-check-application-boundary"
    \\}
;

const application_boundary_json_with_enforcement =
    \\{
    \\  "schema": "zigeffect.causal.production-telemetry-ci-gate-required-status-check-application-boundary.v1",
    \\  "schema_version": 1,
    \\  "source_readiness": ".zig-cache/causal-artifacts/required-status-check-readiness.json",
    \\  "source_readiness_status": "ready",
    \\  "mode": "plan",
    \\  "required_status_check_application_status": "planned",
    \\  "applied": false,
    \\  "mutation_authority": "none",
    \\  "ci_gate_enabled": false,
    \\  "ci_gate_enforcement_enabled": true,
    \\  "ci_required_status_check_enabled": false,
    \\  "ci_workflow_mutation_enabled": false,
    \\  "ci_upload_execution_enabled": false,
    \\  "ci_report_publication_enabled": false,
    \\  "github_api_mutation_enabled": false,
    \\  "github_check_run_creation_enabled": false,
    \\  "branch_protection_mutation_by_tool_enabled": false,
    \\  "github_step_summary_write_enabled": false,
    \\  "pull_request_comment_enabled": false,
    \\  "production_telemetry_ingestion": false,
    \\  "live_exporter_enabled": false,
    \\  "network_send_enabled": false,
    \\  "collector_endpoint_configured": false,
    \\  "otlp_serialization_enabled": false,
    \\  "runtime_pipeline_enabled": false,
    \\  "durable_write_enabled": false,
    \\  "nendb_write_enabled": false,
    \\  "application_checks": [{ "name": "source-schema", "status": "pass", "detail": "source required-status-check readiness schema is supported" }],
    \\  "source_required_status_check_profiles": [{ "id": "release-gate", "activation_enabled": false, "source": "release gate", "intended_future_signal": "release gate report exists", "denied_claim": "active required check" }],
    \\  "denied_inference_rules": ["github-api-mutation-by-tool", "branch-protection-mutation-by-tool"],
    \\  "negative_fixtures": [{ "id": "ci-gate-enforcement-enabled-denied", "artifact_state": "ci_gate_enforcement_enabled=true", "decision": "deny", "failed_gate": "no-ci-gate-enforcement", "reason": "this branch does not enable gates" }],
    \\  "blocked_claims": ["runtime-pipeline-enabled", "live-exporter-enabled", "nendb-write-enabled"],
    \\  "required_verification_commands": ["zig build causal-production-telemetry-ci-gate-required-status-check-readiness", "zig build causal-artifacts"],
    \\  "verified_commands": [],
    \\  "generated_by": "causal-production-telemetry-ci-gate-required-status-check-application-boundary"
    \\}
;
