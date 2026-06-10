const std = @import("std");

pub const production_telemetry_ci_gate_required_status_check_enforcement_readiness_schema = "zigeffect.causal.production-telemetry-ci-gate-required-status-check-enforcement-readiness.v1";
pub const production_telemetry_ci_gate_required_status_check_enforcement_readiness_schema_version: u32 = 1;
pub const source_branch = "codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-enforcement-readiness";
pub const recommendation = "start-production-telemetry-ci-gate-required-status-check-enforcement-application-boundary";
pub const next_branch_if_ready = "codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-enforcement-application-boundary";

const source_policy_schema = "zigeffect.causal.production-telemetry-ci-gate-required-status-check-policy.v1";
const generated_by = "causal-production-telemetry-ci-gate-required-status-check-enforcement-readiness";

const required_verification_commands: []const []const u8 = &.{
    "zig build causal-production-telemetry-ci-gate-required-status-check-policy",
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
const active_enforcement_claim_allowed = false;
const merge_blocker_claim_allowed = false;
const mutation_authority = "none";

const Decision = enum { approve, reject };
const EnforcementReadinessStatus = enum { ready, blocked };
const CheckStatus = enum { pass, fail, skipped };

const Options = struct {
    policy_path: []const u8,
    decision: Decision,
    reviewed_by: []const u8 = "ci-gate-required-status-check-enforcement-readiness-reviewer",
    policy: []const u8 = "manual-production-telemetry-ci-gate-required-status-check-enforcement-readiness",
    reason: []const u8,
    required_check_names: []const []const u8 = &.{},
    branch_protection_evidence: []const []const u8 = &.{},
    workflow_evidence: []const []const u8 = &.{},
    check_run_evidence: []const []const u8 = &.{},
    failure_mode_evidence: []const []const u8 = &.{},
    owner_approvals: []const []const u8 = &.{},
    rollback_evidence: []const []const u8 = &.{},
    verified_commands: []const []const u8 = &.{},
    out_prefix: ?[]const u8 = null,

    fn deinit(self: Options, allocator: std.mem.Allocator) void {
        freeSliceOnly(allocator, self.required_check_names);
        freeSliceOnly(allocator, self.branch_protection_evidence);
        freeSliceOnly(allocator, self.workflow_evidence);
        freeSliceOnly(allocator, self.check_run_evidence);
        freeSliceOnly(allocator, self.failure_mode_evidence);
        freeSliceOnly(allocator, self.owner_approvals);
        freeSliceOnly(allocator, self.rollback_evidence);
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

const EnforcementInput = struct {
    options: Options,
    source_policy_json: []const u8,
};

const EnforcementReports = struct {
    json: []const u8,
    text: []const u8,

    fn deinit(self: EnforcementReports, allocator: std.mem.Allocator) void {
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

const SourceRequiredCheckSurfacePolicy = struct {
    id: []const u8 = "",
    surface: []const u8 = "",
    source_state: []const u8 = "",
    source_applied: bool = false,
    allowed_use: []const u8 = "",
    failure_effect: []const u8 = "",
    tool_mutation_enabled: bool = false,
    merge_blocker_claim_allowed: bool = false,
};

const SourceNegativeFixture = struct {
    id: []const u8 = "",
    artifact_state: []const u8 = "",
    decision: []const u8 = "",
    failed_gate: []const u8 = "",
    reason: []const u8 = "",
};

const SourcePolicyArtifact = struct {
    schema: []const u8,
    schema_version: u32,
    source_application_boundary: []const u8 = "",
    source_application_status: []const u8 = "",
    source_application_mode: []const u8 = "",
    source_applied: bool = false,
    source_application_mutation_authority: []const u8 = "",
    source_readiness: []const u8 = "",
    source_after_report_digest: []const u8 = "",
    decision: []const u8,
    required_status_check_policy_status: []const u8,
    ready_for_next_branch: bool,
    ci_gate_enabled: bool = false,
    ci_gate_enforcement_enabled: bool = false,
    ci_required_status_check_enabled: bool = false,
    ci_workflow_mutation_enabled: bool = false,
    ci_upload_execution_enabled: bool = false,
    ci_report_publication_enabled: bool = false,
    github_api_mutation_enabled: bool = false,
    github_check_run_creation_enabled: bool = false,
    branch_protection_mutation_by_tool_enabled: bool = false,
    github_step_summary_write_enabled: bool = false,
    pull_request_comment_enabled: bool = false,
    production_telemetry_ingestion: bool = false,
    live_exporter_enabled: bool = false,
    network_send_enabled: bool = false,
    collector_endpoint_configured: bool = false,
    otlp_serialization_enabled: bool = false,
    runtime_pipeline_enabled: bool = false,
    durable_write_enabled: bool = false,
    nendb_write_enabled: bool = false,
    required_check_surface_policy: []const SourceRequiredCheckSurfacePolicy = &.{},
    source_application_checks: []const SourceCheck = &.{},
    checks: []const SourceCheck = &.{},
    denied_inference_rules: []const []const u8 = &.{},
    negative_fixtures: []const SourceNegativeFixture = &.{},
    blocked_claims: []const []const u8 = &.{},
    required_verification_commands: []const []const u8 = &.{},
    verified_commands: []const []const u8 = &.{},
};

const EnforcementCheck = struct {
    name: []const u8,
    status: CheckStatus,
    detail: []const u8,
};

const EnforcementResult = struct {
    status: EnforcementReadinessStatus,
    ready_for_next_branch: bool,
    checks: []const EnforcementCheck,

    fn deinit(self: EnforcementResult, allocator: std.mem.Allocator) void {
        if (self.checks.len > 0) allocator.free(self.checks);
    }
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

const evidence_requirements: []const EvidenceRequirement = &.{
    .{ .id = "required-check-name", .allowed = true, .detail = "exact future required status check names" },
    .{ .id = "branch-protection-evidence", .allowed = true, .detail = "bounded reviewed branch-protection snapshots or summaries" },
    .{ .id = "workflow-or-check-run-evidence", .allowed = true, .detail = "bounded reviewed workflow or check-run evidence" },
    .{ .id = "failure-mode-evidence", .allowed = true, .detail = "bounded evidence describing future required-check failure behavior" },
    .{ .id = "owner-approval", .allowed = true, .detail = "bounded reviewed owner approval evidence" },
    .{ .id = "rollback-evidence", .allowed = true, .detail = "bounded rollback or removal instructions" },
    .{ .id = "secret-values", .allowed = false, .detail = "secret-shaped values credentials tokens and raw private headers are never valid evidence" },
    .{ .id = "network-or-live-telemetry", .allowed = false, .detail = "enforcement-readiness must not call networks or ingest live telemetry" },
    .{ .id = "production-database-writes", .allowed = false, .detail = "enforcement-readiness must not write production databases or durable stores" },
    .{ .id = "non-nendb-durable-adapters", .allowed = false, .detail = "durable direction remains NenDB adapter only" },
};

const denied_inference_rules: []const []const u8 = &.{
    "enforcement-readiness-is-not-active-required-status-check",
    "enforcement-readiness-is-not-active-merge-blocking",
    "enforcement-readiness-is-not-github-api-mutation-by-tool",
    "enforcement-readiness-is-not-branch-protection-mutation-by-tool",
    "enforcement-readiness-is-not-workflow-mutation-by-tool",
    "enforcement-readiness-is-not-check-run-creation-by-tool",
    "enforcement-readiness-is-not-ci-upload-execution-by-tool",
    "enforcement-readiness-is-not-github-step-summary-or-pr-comment-write-by-tool",
    "enforcement-readiness-is-not-production-health-proof",
    "enforcement-readiness-is-not-deployment-success-proof",
    "enforcement-readiness-is-not-customer-impact-proof",
    "enforcement-readiness-is-not-production-cluster-readiness-proof",
    "enforcement-readiness-is-not-live-telemetry-coverage-proof",
    "enforcement-readiness-is-not-durable-or-nendb-write-proof",
    "enforcement-readiness-grants-no-mutation-authority",
};

const negative_fixtures: []const NegativeFixture = &.{
    .{ .id = "planned-source-policy-denied", .artifact_state = "source_applied=false", .decision = "deny", .failed_gate = "source-policy-applied", .reason = "planned policy sources are design-only" },
    .{ .id = "blocked-source-policy-denied", .artifact_state = "required_status_check_policy_status=blocked", .decision = "deny", .failed_gate = "source-policy-ready", .reason = "blocked policy cannot feed enforcement readiness" },
    .{ .id = "reviewer-reject-denied", .artifact_state = "decision=reject", .decision = "deny", .failed_gate = "reviewer-decision-approved", .reason = "reviewer rejected readiness" },
    .{ .id = "active-enforcement-claim-denied", .artifact_state = "active_enforcement_claim_allowed=true", .decision = "deny", .failed_gate = "active-claim-denied", .reason = "readiness is not active enforcement" },
    .{ .id = "merge-blocker-claim-denied", .artifact_state = "merge_blocker_claim_allowed=true", .decision = "deny", .failed_gate = "active-claim-denied", .reason = "readiness is not active merge blocking" },
    .{ .id = "missing-required-check-name-denied", .artifact_state = "required_check_names=[]", .decision = "deny", .failed_gate = "required-check-names-present", .reason = "future required check names must be explicit" },
    .{ .id = "missing-branch-protection-evidence-denied", .artifact_state = "branch_protection_evidence=[]", .decision = "deny", .failed_gate = "branch-protection-evidence-present", .reason = "branch-protection evidence is required" },
    .{ .id = "missing-workflow-or-check-run-evidence-denied", .artifact_state = "workflow_evidence=[] check_run_evidence=[]", .decision = "deny", .failed_gate = "workflow-or-check-run-evidence-present", .reason = "workflow or check-run evidence is required" },
    .{ .id = "missing-failure-mode-evidence-denied", .artifact_state = "failure_mode_evidence=[]", .decision = "deny", .failed_gate = "failure-mode-evidence-present", .reason = "future failure behavior must be reviewed" },
    .{ .id = "missing-owner-approval-denied", .artifact_state = "owner_approvals=[]", .decision = "deny", .failed_gate = "owner-approval-present", .reason = "owner approval is required" },
    .{ .id = "missing-rollback-evidence-denied", .artifact_state = "rollback_evidence=[]", .decision = "deny", .failed_gate = "rollback-evidence-present", .reason = "rollback evidence is required" },
    .{ .id = "secret-shaped-evidence-denied", .artifact_state = "evidence contains token or secret", .decision = "deny", .failed_gate = "evidence-is-safe", .reason = "secret-shaped evidence cannot enter readiness artifacts" },
    .{ .id = "live-telemetry-denied", .artifact_state = "collector_endpoint_configured=true", .decision = "deny", .failed_gate = "evidence-is-safe", .reason = "readiness does not configure collectors" },
    .{ .id = "durable-write-denied", .artifact_state = "durable_write_enabled=true", .decision = "deny", .failed_gate = "evidence-is-safe", .reason = "readiness does not write durable stores" },
    .{ .id = "nendb-write-denied", .artifact_state = "nendb_write_enabled=true", .decision = "deny", .failed_gate = "evidence-is-safe", .reason = "NenDB remains future adapter work" },
    .{ .id = "non-nendb-durable-denied", .artifact_state = "durable_adapter=non-nendb", .decision = "deny", .failed_gate = "evidence-is-safe", .reason = "non-NenDB durable adapters remain out of scope" },
    .{ .id = "alternate-renderer-denied", .artifact_state = "renderer=react", .decision = "deny", .failed_gate = "evidence-is-safe", .reason = "workbench direction remains SolidJS inside zig-webui" },
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
        error.MissingPolicyInput => failUsage(err),
        else => return err,
    };
}

fn parseOptions(allocator: std.mem.Allocator, args: []const []const u8) !Options {
    if (args.len < 2) return error.MissingPolicyPath;
    if (!std.mem.eql(u8, args[1], "--from-policy")) return error.UnknownFlag;
    if (args.len < 3) return error.MissingPolicyPath;
    const policy_path = args[2];
    if (!std.mem.endsWith(u8, policy_path, ".json")) return error.InvalidPolicyPath;
    if (args.len < 4) return error.UnknownDecision;
    const decision = try parseDecision(args[3]);

    var reviewed_by: []const u8 = "ci-gate-required-status-check-enforcement-readiness-reviewer";
    var policy: []const u8 = "manual-production-telemetry-ci-gate-required-status-check-enforcement-readiness";
    var reason: ?[]const u8 = null;
    var required_check_names = std.ArrayList([]const u8).empty;
    var branch_protection_evidence = std.ArrayList([]const u8).empty;
    var workflow_evidence = std.ArrayList([]const u8).empty;
    var check_run_evidence = std.ArrayList([]const u8).empty;
    var failure_mode_evidence = std.ArrayList([]const u8).empty;
    var owner_approvals = std.ArrayList([]const u8).empty;
    var rollback_evidence = std.ArrayList([]const u8).empty;
    var verified_commands = std.ArrayList([]const u8).empty;
    var out_prefix: ?[]const u8 = null;
    errdefer required_check_names.deinit(allocator);
    errdefer branch_protection_evidence.deinit(allocator);
    errdefer workflow_evidence.deinit(allocator);
    errdefer check_run_evidence.deinit(allocator);
    errdefer failure_mode_evidence.deinit(allocator);
    errdefer owner_approvals.deinit(allocator);
    errdefer rollback_evidence.deinit(allocator);
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
        } else if (std.mem.eql(u8, flag, "--required-check-name")) {
            try required_check_names.append(allocator, value);
        } else if (std.mem.eql(u8, flag, "--branch-protection-evidence")) {
            try branch_protection_evidence.append(allocator, value);
        } else if (std.mem.eql(u8, flag, "--workflow-evidence")) {
            try workflow_evidence.append(allocator, value);
        } else if (std.mem.eql(u8, flag, "--check-run-evidence")) {
            try check_run_evidence.append(allocator, value);
        } else if (std.mem.eql(u8, flag, "--failure-mode-evidence")) {
            try failure_mode_evidence.append(allocator, value);
        } else if (std.mem.eql(u8, flag, "--owner-approval")) {
            try owner_approvals.append(allocator, value);
        } else if (std.mem.eql(u8, flag, "--rollback-evidence")) {
            try rollback_evidence.append(allocator, value);
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
        .policy_path = policy_path,
        .decision = decision,
        .reviewed_by = reviewed_by,
        .policy = policy,
        .reason = final_reason,
        .required_check_names = try required_check_names.toOwnedSlice(allocator),
        .branch_protection_evidence = try branch_protection_evidence.toOwnedSlice(allocator),
        .workflow_evidence = try workflow_evidence.toOwnedSlice(allocator),
        .check_run_evidence = try check_run_evidence.toOwnedSlice(allocator),
        .failure_mode_evidence = try failure_mode_evidence.toOwnedSlice(allocator),
        .owner_approvals = try owner_approvals.toOwnedSlice(allocator),
        .rollback_evidence = try rollback_evidence.toOwnedSlice(allocator),
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

fn readinessStatusText(status: EnforcementReadinessStatus) []const u8 {
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
        if (!std.mem.endsWith(u8, options.policy_path, ".json")) return error.InvalidPolicyPath;
        if (std.mem.endsWith(u8, options.policy_path, "-ci-gate-required-status-check-policy.json")) {
            const suffix_len = "-ci-gate-required-status-check-policy.json".len;
            break :blk try std.fmt.allocPrint(allocator, "{s}-ci-gate-required-status-check-enforcement-readiness", .{options.policy_path[0 .. options.policy_path.len - suffix_len]});
        }
        const base = options.policy_path[0 .. options.policy_path.len - ".json".len];
        break :blk try std.fmt.allocPrint(allocator, "{s}-ci-gate-required-status-check-enforcement-readiness", .{base});
    };
    defer allocator.free(prefix);

    return .{
        .json_path = try std.fmt.allocPrint(allocator, "{s}.json", .{prefix}),
        .text_path = try std.fmt.allocPrint(allocator, "{s}.txt", .{prefix}),
    };
}

fn formatReports(allocator: std.mem.Allocator, input: EnforcementInput) !EnforcementReports {
    var parsed = try std.json.parseFromSlice(SourcePolicyArtifact, allocator, input.source_policy_json, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();

    const paths = try outputPathsForOptions(allocator, input.options);
    defer paths.deinit(allocator);

    const result = try evaluateReadiness(allocator, input.options, parsed.value);
    defer result.deinit(allocator);

    const json = try formatReadinessJson(allocator, input.options, parsed.value, result, paths);
    errdefer allocator.free(json);
    const text = try formatReadinessText(allocator, input.options, parsed.value, result, paths);
    errdefer allocator.free(text);

    return .{ .json = json, .text = text };
}

fn evaluateReadiness(
    allocator: std.mem.Allocator,
    options: Options,
    source: SourcePolicyArtifact,
) !EnforcementResult {
    var checks = std.ArrayList(EnforcementCheck).empty;
    errdefer checks.deinit(allocator);

    try appendCheck(allocator, &checks, "source-schema", if (std.mem.eql(u8, source.schema, source_policy_schema) and source.schema_version == 1) .pass else .fail, "source required-status-check policy schema is supported");
    try appendCheck(allocator, &checks, "source-policy-ready", if (sourcePolicyReady(source)) .pass else .fail, "source policy is approved ready and ready for next branch");
    try appendCheck(allocator, &checks, "source-policy-applied", if (source.source_applied) .pass else .fail, "source policy is backed by externally applied required-status-check application evidence");
    try appendCheck(allocator, &checks, "source-application-state-consistent", if (sourceApplicationStateConsistent(source)) .pass else .fail, "source application status mode applied flag and mutation authority are internally consistent");
    try appendCheck(allocator, &checks, "source-tool-authority-disabled", if (sourceToolAuthorityDisabled(source)) .pass else .fail, "source keeps GitHub branch protection workflow check-run upload summary and comment authority disabled");
    try appendCheck(allocator, &checks, "source-runtime-and-storage-disabled", if (sourceRuntimeAndStorageDisabled(source)) .pass else .fail, "source keeps live telemetry network collector OTLP runtime durable and NenDB writes disabled");
    try appendCheck(allocator, &checks, "source-checks-passed", if (sourceChecksHaveNoFailures(source)) .pass else .fail, "source policy and source application checks contain no failures");
    try appendCheck(allocator, &checks, "source-surface-policy-safe", if (sourceSurfacePolicySafe(source)) .pass else .fail, "source required-check surface policy denies tool mutation and merge-blocker claims");
    try appendCheck(allocator, &checks, "source-catalogs-present", if (sourceCatalogsPresent(source)) .pass else .fail, "source denied inference negative fixture blocked claim and verification catalogs are present");
    try appendCheck(allocator, &checks, "source-verification-recorded", if (verifiedCommandsContainAll(source.verified_commands, source.required_verification_commands)) .pass else .fail, "source policy recorded every source required verification command");
    try appendCheck(allocator, &checks, "reviewer-decision-approved", if (options.decision == .approve) .pass else .fail, "reviewer approved required-status-check enforcement-readiness handoff");
    try appendCheck(allocator, &checks, "required-check-names-present", if (options.required_check_names.len > 0) .pass else .fail, "future required check names are explicit");
    try appendCheck(allocator, &checks, "branch-protection-evidence-present", if (options.branch_protection_evidence.len > 0) .pass else .fail, "branch-protection evidence is present");
    try appendCheck(allocator, &checks, "workflow-or-check-run-evidence-present", if (options.workflow_evidence.len > 0 or options.check_run_evidence.len > 0) .pass else .fail, "workflow or check-run evidence is present");
    try appendCheck(allocator, &checks, "failure-mode-evidence-present", if (options.failure_mode_evidence.len > 0) .pass else .fail, "future failure behavior evidence is present");
    try appendCheck(allocator, &checks, "owner-approval-present", if (options.owner_approvals.len > 0) .pass else .fail, "owner approval evidence is present");
    try appendCheck(allocator, &checks, "rollback-evidence-present", if (options.rollback_evidence.len > 0) .pass else .fail, "rollback evidence is present");
    try appendCheck(allocator, &checks, "evidence-is-safe", if (allEvidenceSafe(options)) .pass else .fail, "evidence contains no secrets denied mutation claims live telemetry durable writes NenDB writes production claims or alternate renderer scope");
    try appendCheck(allocator, &checks, "verification-recorded", if (verifiedCommandsContainAll(options.verified_commands, required_verification_commands)) .pass else .fail, "enforcement-readiness review recorded every required verification command");
    try appendCheck(allocator, &checks, "release-gate-verification-recorded", if (verifiedCommandsContainAll(options.verified_commands, &.{ "zig build release-gate --summary none", "zig build release-gate-report" })) .pass else .fail, "release gate and release gate report commands are verified");
    try appendCheck(allocator, &checks, "active-claim-denied", if (!active_enforcement_claim_allowed and !merge_blocker_claim_allowed) .pass else .fail, "readiness never claims active enforcement or merge blocking");

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
    checks: *std.ArrayList(EnforcementCheck),
    name: []const u8,
    status: CheckStatus,
    detail: []const u8,
) !void {
    try checks.append(allocator, .{ .name = name, .status = status, .detail = detail });
}

fn allChecksPassed(checks: []const EnforcementCheck) bool {
    for (checks) |check| {
        if (check.status != .pass) return false;
    }
    return true;
}

fn sourcePolicyReady(source: SourcePolicyArtifact) bool {
    return std.mem.eql(u8, source.decision, "approve") and
        std.mem.eql(u8, source.required_status_check_policy_status, "ready") and
        source.ready_for_next_branch;
}

fn sourceApplicationStateConsistent(source: SourcePolicyArtifact) bool {
    if (std.mem.eql(u8, source.source_application_status, "applied")) {
        return source.source_applied and
            std.mem.eql(u8, source.source_application_mode, "record-applied") and
            std.mem.eql(u8, source.source_application_mutation_authority, "record-only");
    }
    if (std.mem.eql(u8, source.source_application_status, "planned")) {
        return !source.source_applied and
            std.mem.eql(u8, source.source_application_mode, "plan") and
            std.mem.eql(u8, source.source_application_mutation_authority, "none");
    }
    return false;
}

fn sourceToolAuthorityDisabled(source: SourcePolicyArtifact) bool {
    return !source.ci_gate_enabled and
        !source.ci_gate_enforcement_enabled and
        !source.ci_required_status_check_enabled and
        !source.ci_workflow_mutation_enabled and
        !source.ci_upload_execution_enabled and
        !source.ci_report_publication_enabled and
        !source.github_api_mutation_enabled and
        !source.github_check_run_creation_enabled and
        !source.branch_protection_mutation_by_tool_enabled and
        !source.github_step_summary_write_enabled and
        !source.pull_request_comment_enabled;
}

fn sourceRuntimeAndStorageDisabled(source: SourcePolicyArtifact) bool {
    return !source.production_telemetry_ingestion and
        !source.live_exporter_enabled and
        !source.network_send_enabled and
        !source.collector_endpoint_configured and
        !source.otlp_serialization_enabled and
        !source.runtime_pipeline_enabled and
        !source.durable_write_enabled and
        !source.nendb_write_enabled;
}

fn sourceChecksHaveNoFailures(source: SourcePolicyArtifact) bool {
    return checksHaveNoFailures(source.checks) and checksHaveNoFailures(source.source_application_checks);
}

fn checksHaveNoFailures(checks: []const SourceCheck) bool {
    if (checks.len == 0) return false;
    for (checks) |check| {
        if (std.mem.eql(u8, check.status, "fail")) return false;
    }
    return true;
}

fn sourceSurfacePolicySafe(source: SourcePolicyArtifact) bool {
    if (source.required_check_surface_policy.len == 0) return false;
    for (source.required_check_surface_policy) |policy| {
        if (policy.tool_mutation_enabled or policy.merge_blocker_claim_allowed) return false;
    }
    return true;
}

fn sourceCatalogsPresent(source: SourcePolicyArtifact) bool {
    return source.denied_inference_rules.len > 0 and
        source.negative_fixtures.len > 0 and
        source.blocked_claims.len > 0 and
        source.required_verification_commands.len > 0 and
        source.verified_commands.len > 0;
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

fn allEvidenceSafe(options: Options) bool {
    return evidenceSliceSafe(options.required_check_names) and
        evidenceSliceSafe(options.branch_protection_evidence) and
        evidenceSliceSafe(options.workflow_evidence) and
        evidenceSliceSafe(options.check_run_evidence) and
        evidenceSliceSafe(options.failure_mode_evidence) and
        evidenceSliceSafe(options.owner_approvals) and
        evidenceSliceSafe(options.rollback_evidence);
}

fn evidenceSliceSafe(values: []const []const u8) bool {
    for (values) |value| {
        if (!evidenceValueSafe(value)) return false;
    }
    return true;
}

fn evidenceValueSafe(value: []const u8) bool {
    const denied_markers: []const []const u8 = &.{
        "secret=",
        "token=",
        "password=",
        "ghp_",
        "sk-",
        "BEGIN PRIVATE KEY",
        "github_api_mutation_enabled=true",
        "branch_protection_mutation_by_tool_enabled=true",
        "ci_workflow_mutation_enabled=true",
        "github_check_run_creation_enabled=true",
        "ci_upload_execution_enabled=true",
        "ci_required_status_check_enabled=true",
        "collector_endpoint_configured=true",
        "durable_write_enabled=true",
        "nendb_write_enabled=true",
        "durable_adapter=non-nendb",
        "production_health=proven",
        "deployment_success=proven",
        "customer_impact=proven",
        "production_cluster_ready=true",
        "renderer=react",
    };
    for (denied_markers) |marker| {
        if (std.mem.indexOf(u8, value, marker) != null) return false;
    }
    return true;
}

fn formatReadinessJson(
    allocator: std.mem.Allocator,
    options: Options,
    source: SourcePolicyArtifact,
    result: EnforcementResult,
    paths: OutputPaths,
) ![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "{\n");
    try appendJsonField(allocator, &output, "schema", production_telemetry_ci_gate_required_status_check_enforcement_readiness_schema, true);
    try output.appendSlice(allocator, "  \"schema_version\": 1,\n");
    try appendJsonField(allocator, &output, "source_policy", options.policy_path, true);
    try appendJsonField(allocator, &output, "source_policy_status", source.required_status_check_policy_status, true);
    try appendJsonField(allocator, &output, "source_policy_decision", source.decision, true);
    try output.print(allocator, "  \"source_policy_ready_for_next_branch\": {},\n", .{source.ready_for_next_branch});
    try appendJsonField(allocator, &output, "source_application_status", source.source_application_status, true);
    try appendJsonField(allocator, &output, "source_application_mode", source.source_application_mode, true);
    try output.print(allocator, "  \"source_applied\": {},\n", .{source.source_applied});
    try appendJsonField(allocator, &output, "source_application_mutation_authority", source.source_application_mutation_authority, true);
    try appendJsonField(allocator, &output, "source_readiness", source.source_readiness, true);
    try appendJsonField(allocator, &output, "source_after_report_digest", source.source_after_report_digest, true);
    try appendJsonField(allocator, &output, "decision", decisionText(options.decision), true);
    try appendJsonField(allocator, &output, "reviewed_by", options.reviewed_by, true);
    try appendJsonField(allocator, &output, "policy", options.policy, true);
    try appendJsonField(allocator, &output, "reason", options.reason, true);
    try appendJsonField(allocator, &output, "enforcement_readiness_status", readinessStatusText(result.status), true);
    try output.print(allocator, "  \"ready_for_next_branch\": {},\n", .{result.ready_for_next_branch});
    try output.print(allocator, "  \"active_enforcement_claim_allowed\": {},\n", .{active_enforcement_claim_allowed});
    try output.print(allocator, "  \"merge_blocker_claim_allowed\": {},\n", .{merge_blocker_claim_allowed});
    try appendJsonField(allocator, &output, "mutation_authority", mutation_authority, true);
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
    try output.appendSlice(allocator, "  \"required_check_names\": ");
    try appendStringArray(allocator, &output, options.required_check_names);
    try output.appendSlice(allocator, ",\n  \"branch_protection_evidence\": ");
    try appendStringArray(allocator, &output, options.branch_protection_evidence);
    try output.appendSlice(allocator, ",\n  \"workflow_evidence\": ");
    try appendStringArray(allocator, &output, options.workflow_evidence);
    try output.appendSlice(allocator, ",\n  \"check_run_evidence\": ");
    try appendStringArray(allocator, &output, options.check_run_evidence);
    try output.appendSlice(allocator, ",\n  \"failure_mode_evidence\": ");
    try appendStringArray(allocator, &output, options.failure_mode_evidence);
    try output.appendSlice(allocator, ",\n  \"owner_approvals\": ");
    try appendStringArray(allocator, &output, options.owner_approvals);
    try output.appendSlice(allocator, ",\n  \"rollback_evidence\": ");
    try appendStringArray(allocator, &output, options.rollback_evidence);
    try output.appendSlice(allocator, ",\n  \"evidence_requirements\": ");
    try appendEvidenceRequirementsJson(allocator, &output);
    try output.appendSlice(allocator, ",\n  \"checks\": ");
    try appendChecksJson(allocator, &output, result.checks);
    try output.appendSlice(allocator, ",\n  \"denied_inference_rules\": ");
    try appendStringArray(allocator, &output, denied_inference_rules);
    try output.appendSlice(allocator, ",\n  \"negative_fixtures\": ");
    try appendNegativeFixturesJson(allocator, &output);
    try output.appendSlice(allocator, ",\n  \"blocked_claims\": ");
    try appendStringArray(allocator, &output, blockedClaims());
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
    try appendStringArray(allocator, &output, agentGuidance(result.status, source.source_applied));
    try output.appendSlice(allocator, "\n}\n");

    return output.toOwnedSlice(allocator);
}

fn formatReadinessText(
    allocator: std.mem.Allocator,
    options: Options,
    source: SourcePolicyArtifact,
    result: EnforcementResult,
    paths: OutputPaths,
) ![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "zigeffect production telemetry CI gate required status check enforcement readiness\n");
    try output.print(allocator, "schema: {s}\n", .{production_telemetry_ci_gate_required_status_check_enforcement_readiness_schema});
    try output.print(allocator, "source policy: {s}\n", .{options.policy_path});
    try output.print(allocator, "source policy status: {s}\n", .{source.required_status_check_policy_status});
    try output.print(allocator, "source policy decision: {s}\n", .{source.decision});
    try output.print(allocator, "source policy ready for next branch: {}\n", .{source.ready_for_next_branch});
    try output.print(allocator, "source application status: {s}\n", .{source.source_application_status});
    try output.print(allocator, "source application mode: {s}\n", .{source.source_application_mode});
    try output.print(allocator, "source applied: {}\n", .{source.source_applied});
    try output.print(allocator, "decision: {s}\n", .{decisionText(options.decision)});
    try output.print(allocator, "enforcement_readiness_status: {s}\n", .{readinessStatusText(result.status)});
    try output.print(allocator, "ready_for_next_branch: {}\n", .{result.ready_for_next_branch});
    try output.print(allocator, "active enforcement claim allowed: {}\n", .{active_enforcement_claim_allowed});
    try output.print(allocator, "merge blocker claim allowed: {}\n", .{merge_blocker_claim_allowed});
    try output.print(allocator, "mutation authority: {s}\n", .{mutation_authority});
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

    try appendTextList(allocator, &output, "required check names", options.required_check_names);
    try appendTextList(allocator, &output, "branch protection evidence", options.branch_protection_evidence);
    try appendTextList(allocator, &output, "workflow evidence", options.workflow_evidence);
    try appendTextList(allocator, &output, "check run evidence", options.check_run_evidence);
    try appendTextList(allocator, &output, "failure mode evidence", options.failure_mode_evidence);
    try appendTextList(allocator, &output, "owner approvals", options.owner_approvals);
    try appendTextList(allocator, &output, "rollback evidence", options.rollback_evidence);
    try appendEvidenceRequirementsText(allocator, &output);
    try appendTextList(allocator, &output, "denied inference rules", denied_inference_rules);
    try appendNegativeFixturesText(allocator, &output);
    try appendTextList(allocator, &output, "blocked claims", blockedClaims());
    try appendTextList(allocator, &output, "required verification commands", required_verification_commands);
    try appendTextList(allocator, &output, "verified commands", options.verified_commands);
    try appendTextList(allocator, &output, "agent guidance", agentGuidance(result.status, source.source_applied));

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

fn appendChecksJson(allocator: std.mem.Allocator, output: *std.ArrayList(u8), checks: []const EnforcementCheck) !void {
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
    for (value) |char| {
        switch (char) {
            '"' => try output.appendSlice(allocator, "\\\""),
            '\\' => try output.appendSlice(allocator, "\\\\"),
            '\n' => try output.appendSlice(allocator, "\\n"),
            '\r' => try output.appendSlice(allocator, "\\r"),
            '\t' => try output.appendSlice(allocator, "\\t"),
            else => try output.append(allocator, char),
        }
    }
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

fn blockedClaims() []const []const u8 {
    return &.{
        "required-status-check-active",
        "merge-blocker-active",
        "github-api-mutated-by-tool",
        "branch-protection-mutated-by-tool",
        "workflow-mutated-by-tool",
        "check-run-created-by-tool",
        "artifact-upload-executed-by-tool",
        "step-summary-or-pr-comment-written-by-tool",
        "live-telemetry-ingested",
        "runtime-pipeline-enabled",
        "durable-production-write-enabled",
        "nendb-write-enabled",
        "production-health-proven",
        "deployment-success-proven",
        "customer-impact-proven",
        "production-cluster-ready",
        "non-nendb-durable-adapter",
        "react-or-alternate-renderer",
    };
}

fn agentGuidance(status: EnforcementReadinessStatus, source_applied: bool) []const []const u8 {
    if (!source_applied) {
        return &.{
            "Treat planned required-status-check policy sources as design-only evidence.",
            "Return to the application-boundary branch and record reviewed external application evidence before claiming enforcement readiness.",
            "Do not infer active required checks merge blocking production health cluster readiness or mutation authority from planned policy evidence.",
        };
    }
    return switch (status) {
        .ready => &.{
            "Start the required-status-check enforcement application-boundary branch with bounded reviewed evidence only.",
            "Readiness is record-only and must not claim active required checks merge blocking GitHub mutation live telemetry or durable writes.",
            "Carry required check names evidence catalogs denied inference rules negative fixtures and verification commands into the next branch.",
        },
        .blocked => &.{
            "Treat blocked required-status-check enforcement-readiness evidence as a stop sign.",
            "Repair source policy evidence reviewer decision required check names branch protection workflow or check-run evidence failure-mode evidence owner approval rollback evidence or verification proof before proceeding.",
            "Do not infer active enforcement production readiness or mutation authority from blocked readiness evidence.",
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
    const cwd = std.Io.Dir.cwd();
    if (std.mem.lastIndexOfScalar(u8, path, '/')) |slash| {
        if (slash > 0) try cwd.createDirPath(io, path[0..slash]);
    }
    try cwd.writeFile(io, .{ .sub_path = path, .data = contents });
}

fn run(init: std.process.Init, options: Options) !void {
    const allocator = init.gpa;
    const source_policy_json = try readRequiredArtifact(init.io, allocator, options.policy_path, error.MissingPolicyInput);
    defer allocator.free(source_policy_json);

    const reports = try formatReports(allocator, .{
        .options = options,
        .source_policy_json = source_policy_json,
    });
    defer reports.deinit(allocator);

    const paths = try outputPathsForOptions(allocator, options);
    defer paths.deinit(allocator);

    try writeArtifact(init.io, paths.json_path, reports.json);
    try writeArtifact(init.io, paths.text_path, reports.text);
    std.debug.print("{s}", .{reports.text});
}

fn usage() []const u8 {
    return "usage: zig build causal-production-telemetry-ci-gate-required-status-check-enforcement-readiness -- --from-policy <required-status-check-policy.json> approve|reject --reason <reason> [--by <actor>] [--policy <policy>] [--required-check-name <name>]... [--branch-protection-evidence <path-or-summary>]... [--workflow-evidence <path-or-summary>]... [--check-run-evidence <path-or-summary>]... [--failure-mode-evidence <path-or-summary>]... [--owner-approval <path-or-summary>]... [--rollback-evidence <path-or-summary>]... [--verified-command <command>]... [--out-prefix <path-prefix>]\n";
}

fn failUsage(err: anyerror) noreturn {
    std.debug.print("causal-production-telemetry-ci-gate-required-status-check-enforcement-readiness error: {s}\n{s}", .{ @errorName(err), usage() });
    std.process.exit(1);
}

fn freeSliceOnly(allocator: std.mem.Allocator, slice: []const []const u8) void {
    if (slice.len > 0) allocator.free(slice);
}

fn contains(haystack: []const u8, needle: []const u8) bool {
    return std.mem.indexOf(u8, haystack, needle) != null;
}

fn completeOptions() Options {
    return .{
        .policy_path = "required-status-check-policy.json",
        .decision = .approve,
        .reason = "required status check enforcement readiness reviewed",
        .required_check_names = &.{"zigeffect causal release gate"},
        .branch_protection_evidence = &.{"reviewed branch protection required status check evidence"},
        .workflow_evidence = &.{"reviewed release gate workflow evidence"},
        .failure_mode_evidence = &.{"reviewed failing release gate blocks future required check"},
        .owner_approvals = &.{"reviewed owner approval for future required check enforcement"},
        .rollback_evidence = &.{"reviewed rollback removes required status check from branch protection"},
        .verified_commands = required_verification_commands,
    };
}

test "ci gate required status check enforcement readiness schema and branch constants are stable" {
    try std.testing.expectEqualStrings("zigeffect.causal.production-telemetry-ci-gate-required-status-check-enforcement-readiness.v1", production_telemetry_ci_gate_required_status_check_enforcement_readiness_schema);
    try std.testing.expectEqual(@as(u32, 1), production_telemetry_ci_gate_required_status_check_enforcement_readiness_schema_version);
    try std.testing.expectEqualStrings("codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-enforcement-readiness", source_branch);
    try std.testing.expectEqualStrings("start-production-telemetry-ci-gate-required-status-check-enforcement-application-boundary", recommendation);
    try std.testing.expectEqualStrings("codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-enforcement-application-boundary", next_branch_if_ready);
}

test "parses ci gate required status check enforcement readiness options" {
    const allocator = std.testing.allocator;
    const options = try parseOptions(allocator, &.{
        "zigeffect-causal-production-telemetry-ci-gate-required-status-check-enforcement-readiness",
        "--from-policy",
        "required-status-check-policy.json",
        "approve",
        "--reason",
        "required status check enforcement readiness reviewed",
        "--by",
        "reviewer-a",
        "--policy",
        "policy-a",
        "--required-check-name",
        "zigeffect causal release gate",
        "--branch-protection-evidence",
        "branch protection evidence",
        "--workflow-evidence",
        "workflow evidence",
        "--check-run-evidence",
        "check run evidence",
        "--failure-mode-evidence",
        "failure mode evidence",
        "--owner-approval",
        "owner approval",
        "--rollback-evidence",
        "rollback evidence",
        "--verified-command",
        "zig build causal-production-telemetry-ci-gate-required-status-check-policy",
        "--out-prefix",
        ".zig-cache/causal-artifacts/enforcement-readiness",
    });
    defer options.deinit(allocator);

    try std.testing.expectEqual(Decision.approve, options.decision);
    try std.testing.expectEqualStrings("required-status-check-policy.json", options.policy_path);
    try std.testing.expectEqualStrings("reviewer-a", options.reviewed_by);
    try std.testing.expectEqualStrings("policy-a", options.policy);
    try std.testing.expectEqual(@as(usize, 1), options.required_check_names.len);
    try std.testing.expectEqual(@as(usize, 1), options.branch_protection_evidence.len);
    try std.testing.expectEqual(@as(usize, 1), options.workflow_evidence.len);
    try std.testing.expectEqual(@as(usize, 1), options.check_run_evidence.len);
    try std.testing.expectEqual(@as(usize, 1), options.failure_mode_evidence.len);
    try std.testing.expectEqual(@as(usize, 1), options.owner_approvals.len);
    try std.testing.expectEqual(@as(usize, 1), options.rollback_evidence.len);
    try std.testing.expectEqual(@as(usize, 1), options.verified_commands.len);
    try std.testing.expectEqualStrings(".zig-cache/causal-artifacts/enforcement-readiness", options.out_prefix.?);

    const reject_options = try parseOptions(allocator, &.{
        "zigeffect-causal-production-telemetry-ci-gate-required-status-check-enforcement-readiness",
        "--from-policy",
        "required-status-check-policy.json",
        "reject",
        "--reason",
        "negative required status check enforcement readiness path",
    });
    defer reject_options.deinit(allocator);
    try std.testing.expectEqual(Decision.reject, reject_options.decision);
}

test "rejects invalid ci gate required status check enforcement readiness options" {
    const allocator = std.testing.allocator;
    try std.testing.expectError(error.MissingPolicyPath, parseOptions(allocator, &.{
        "zigeffect-causal-production-telemetry-ci-gate-required-status-check-enforcement-readiness",
    }));
    try std.testing.expectError(error.InvalidPolicyPath, parseOptions(allocator, &.{
        "zigeffect-causal-production-telemetry-ci-gate-required-status-check-enforcement-readiness",
        "--from-policy",
        "required-status-check-policy.txt",
        "approve",
        "--reason",
        "reviewed",
    }));
    try std.testing.expectError(error.UnknownDecision, parseOptions(allocator, &.{
        "zigeffect-causal-production-telemetry-ci-gate-required-status-check-enforcement-readiness",
        "--from-policy",
        "required-status-check-policy.json",
        "maybe",
        "--reason",
        "reviewed",
    }));
    try std.testing.expectError(error.MissingReason, parseOptions(allocator, &.{
        "zigeffect-causal-production-telemetry-ci-gate-required-status-check-enforcement-readiness",
        "--from-policy",
        "required-status-check-policy.json",
        "approve",
    }));
}

test "derives ci gate required status check enforcement readiness output paths" {
    const allocator = std.testing.allocator;
    const implicit = try outputPathsForOptions(allocator, .{
        .policy_path = ".zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-policy.json",
        .decision = .approve,
        .reason = "reviewed",
    });
    defer implicit.deinit(allocator);
    try std.testing.expectEqualStrings(".zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-enforcement-readiness.json", implicit.json_path);
    try std.testing.expectEqualStrings(".zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-enforcement-readiness.txt", implicit.text_path);

    const explicit = try outputPathsForOptions(allocator, .{
        .policy_path = "source.json",
        .decision = .approve,
        .reason = "reviewed",
        .out_prefix = ".zig-cache/causal-artifacts/custom-enforcement-readiness",
    });
    defer explicit.deinit(allocator);
    try std.testing.expectEqualStrings(".zig-cache/causal-artifacts/custom-enforcement-readiness.json", explicit.json_path);
    try std.testing.expectEqualStrings(".zig-cache/causal-artifacts/custom-enforcement-readiness.txt", explicit.text_path);
}

test "approved applied policy with complete evidence emits ready enforcement readiness" {
    const allocator = std.testing.allocator;
    const reports = try formatReports(allocator, .{
        .options = completeOptions(),
        .source_policy_json = appliedPolicyJson(),
    });
    defer reports.deinit(allocator);

    try std.testing.expect(contains(reports.json, "\"enforcement_readiness_status\": \"ready\""));
    try std.testing.expect(contains(reports.json, "\"ready_for_next_branch\": true"));
    try std.testing.expect(contains(reports.json, "\"active_enforcement_claim_allowed\": false"));
    try std.testing.expect(contains(reports.json, "\"merge_blocker_claim_allowed\": false"));
    try std.testing.expect(contains(reports.json, "\"next_branch_if_ready\": \"codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-enforcement-application-boundary\""));
    try std.testing.expect(contains(reports.text, "enforcement_readiness_status: ready"));
    try std.testing.expect(contains(reports.text, "active enforcement claim allowed: false"));
}

test "planned policy remains blocked and design-only" {
    const allocator = std.testing.allocator;
    const reports = try formatReports(allocator, .{
        .options = completeOptions(),
        .source_policy_json = plannedPolicyJson(),
    });
    defer reports.deinit(allocator);

    try std.testing.expect(contains(reports.json, "\"enforcement_readiness_status\": \"blocked\""));
    try std.testing.expect(contains(reports.json, "\"source_applied\": false"));
    try std.testing.expect(contains(reports.json, "source-policy-applied"));
    try std.testing.expect(contains(reports.text, "planned required-status-check policy sources as design-only evidence"));
}

test "reject decision and unsafe evidence block enforcement readiness" {
    const allocator = std.testing.allocator;
    var rejected = completeOptions();
    rejected.decision = .reject;
    const rejected_reports = try formatReports(allocator, .{
        .options = rejected,
        .source_policy_json = appliedPolicyJson(),
    });
    defer rejected_reports.deinit(allocator);
    try std.testing.expect(contains(rejected_reports.json, "\"enforcement_readiness_status\": \"blocked\""));
    try std.testing.expect(contains(rejected_reports.json, "reviewer-decision-approved"));

    var unsafe = completeOptions();
    unsafe.branch_protection_evidence = &.{"branch protection evidence token=secret"};
    const unsafe_reports = try formatReports(allocator, .{
        .options = unsafe,
        .source_policy_json = appliedPolicyJson(),
    });
    defer unsafe_reports.deinit(allocator);
    try std.testing.expect(contains(unsafe_reports.json, "\"enforcement_readiness_status\": \"blocked\""));
    try std.testing.expect(contains(unsafe_reports.json, "evidence-is-safe"));
}

test "missing evidence and unsafe source policy block enforcement readiness" {
    const allocator = std.testing.allocator;
    var missing = completeOptions();
    missing.required_check_names = &.{};
    missing.workflow_evidence = &.{};
    missing.check_run_evidence = &.{};
    const missing_reports = try formatReports(allocator, .{
        .options = missing,
        .source_policy_json = appliedPolicyJson(),
    });
    defer missing_reports.deinit(allocator);
    try std.testing.expect(contains(missing_reports.json, "\"enforcement_readiness_status\": \"blocked\""));
    try std.testing.expect(contains(missing_reports.json, "required-check-names-present"));
    try std.testing.expect(contains(missing_reports.json, "workflow-or-check-run-evidence-present"));

    const unsafe_source_reports = try formatReports(allocator, .{
        .options = completeOptions(),
        .source_policy_json = unsafeSourcePolicyJson(),
    });
    defer unsafe_source_reports.deinit(allocator);
    try std.testing.expect(contains(unsafe_source_reports.json, "\"enforcement_readiness_status\": \"blocked\""));
    try std.testing.expect(contains(unsafe_source_reports.json, "source-tool-authority-disabled"));
}

fn appliedPolicyJson() []const u8 {
    return
        \\{
        \\  "schema": "zigeffect.causal.production-telemetry-ci-gate-required-status-check-policy.v1",
        \\  "schema_version": 1,
        \\  "source_application_boundary": "required-status-check-application-boundary.json",
        \\  "source_application_status": "applied",
        \\  "source_application_mode": "record-applied",
        \\  "source_applied": true,
        \\  "source_application_mutation_authority": "record-only",
        \\  "source_readiness": "required-status-check-readiness.json",
        \\  "source_after_report_digest": "sha256:after",
        \\  "decision": "approve",
        \\  "required_status_check_policy_status": "ready",
        \\  "ready_for_next_branch": true,
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
        \\  "required_check_surface_policy": [
        \\    { "id": "applied-required-check-surface", "tool_mutation_enabled": false, "merge_blocker_claim_allowed": false }
        \\  ],
        \\  "source_application_checks": [
        \\    { "name": "source-schema", "status": "pass", "detail": "source ok" }
        \\  ],
        \\  "checks": [
        \\    { "name": "policy-verification-recorded", "status": "pass", "detail": "policy ok" }
        \\  ],
        \\  "denied_inference_rules": ["policy-readiness-is-not-branch-protection-mutation"],
        \\  "negative_fixtures": [
        \\    { "id": "required-status-check-claim-denied", "artifact_state": "ci_required_status_check_enabled=true", "decision": "deny", "failed_gate": "source-disabled-authority", "reason": "required checks denied" }
        \\  ],
        \\  "blocked_claims": ["required-status-check-active"],
        \\  "required_verification_commands": [
        \\    "zig build causal-production-telemetry-ci-gate-required-status-check-application-boundary",
        \\    "zig build causal-artifacts"
        \\  ],
        \\  "verified_commands": [
        \\    "zig build causal-production-telemetry-ci-gate-required-status-check-application-boundary",
        \\    "zig build causal-artifacts"
        \\  ]
        \\}
    ;
}

fn plannedPolicyJson() []const u8 {
    return
        \\{
        \\  "schema": "zigeffect.causal.production-telemetry-ci-gate-required-status-check-policy.v1",
        \\  "schema_version": 1,
        \\  "source_application_boundary": "required-status-check-application-boundary.json",
        \\  "source_application_status": "planned",
        \\  "source_application_mode": "plan",
        \\  "source_applied": false,
        \\  "source_application_mutation_authority": "none",
        \\  "source_readiness": "required-status-check-readiness.json",
        \\  "source_after_report_digest": "sha256:after",
        \\  "decision": "approve",
        \\  "required_status_check_policy_status": "ready",
        \\  "ready_for_next_branch": true,
        \\  "required_check_surface_policy": [
        \\    { "id": "planned-required-check-surface", "tool_mutation_enabled": false, "merge_blocker_claim_allowed": false }
        \\  ],
        \\  "source_application_checks": [
        \\    { "name": "source-schema", "status": "pass", "detail": "source ok" }
        \\  ],
        \\  "checks": [
        \\    { "name": "policy-verification-recorded", "status": "pass", "detail": "policy ok" }
        \\  ],
        \\  "denied_inference_rules": ["policy-readiness-is-not-branch-protection-mutation"],
        \\  "negative_fixtures": [
        \\    { "id": "required-status-check-claim-denied", "artifact_state": "ci_required_status_check_enabled=true", "decision": "deny", "failed_gate": "source-disabled-authority", "reason": "required checks denied" }
        \\  ],
        \\  "blocked_claims": ["required-status-check-active"],
        \\  "required_verification_commands": [
        \\    "zig build causal-production-telemetry-ci-gate-required-status-check-application-boundary"
        \\  ],
        \\  "verified_commands": [
        \\    "zig build causal-production-telemetry-ci-gate-required-status-check-application-boundary"
        \\  ]
        \\}
    ;
}

fn unsafeSourcePolicyJson() []const u8 {
    return
        \\{
        \\  "schema": "zigeffect.causal.production-telemetry-ci-gate-required-status-check-policy.v1",
        \\  "schema_version": 1,
        \\  "source_application_status": "applied",
        \\  "source_application_mode": "record-applied",
        \\  "source_applied": true,
        \\  "source_application_mutation_authority": "record-only",
        \\  "source_readiness": "required-status-check-readiness.json",
        \\  "source_after_report_digest": "sha256:after",
        \\  "decision": "approve",
        \\  "required_status_check_policy_status": "ready",
        \\  "ready_for_next_branch": true,
        \\  "github_api_mutation_enabled": true,
        \\  "required_check_surface_policy": [
        \\    { "id": "applied-required-check-surface", "tool_mutation_enabled": false, "merge_blocker_claim_allowed": false }
        \\  ],
        \\  "source_application_checks": [
        \\    { "name": "source-schema", "status": "pass", "detail": "source ok" }
        \\  ],
        \\  "checks": [
        \\    { "name": "policy-verification-recorded", "status": "pass", "detail": "policy ok" }
        \\  ],
        \\  "denied_inference_rules": ["policy-readiness-is-not-branch-protection-mutation"],
        \\  "negative_fixtures": [
        \\    { "id": "required-status-check-claim-denied", "artifact_state": "ci_required_status_check_enabled=true", "decision": "deny", "failed_gate": "source-disabled-authority", "reason": "required checks denied" }
        \\  ],
        \\  "blocked_claims": ["required-status-check-active"],
        \\  "required_verification_commands": [
        \\    "zig build causal-production-telemetry-ci-gate-required-status-check-application-boundary"
        \\  ],
        \\  "verified_commands": [
        \\    "zig build causal-production-telemetry-ci-gate-required-status-check-application-boundary"
        \\  ]
        \\}
    ;
}
