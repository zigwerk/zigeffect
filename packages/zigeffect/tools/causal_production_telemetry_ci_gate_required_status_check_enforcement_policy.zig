const std = @import("std");

pub const production_telemetry_ci_gate_required_status_check_enforcement_policy_schema = "zigeffect.causal.production-telemetry-ci-gate-required-status-check-enforcement-policy.v1";
pub const production_telemetry_ci_gate_required_status_check_enforcement_policy_schema_version: u32 = 1;
pub const source_branch = "codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-enforcement-policy";
pub const recommendation = "start-production-telemetry-ci-gate-required-status-check-enforcement-evaluator";
pub const next_branch_if_ready = "codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-enforcement-evaluator";

const source_application_boundary_schema = "zigeffect.causal.production-telemetry-ci-gate-required-status-check-enforcement-application-boundary.v1";
const generated_by = "causal-production-telemetry-ci-gate-required-status-check-enforcement-policy";

const required_verification_commands: []const []const u8 = &.{
    "zig build causal-production-telemetry-ci-gate-required-status-check-enforcement-application-boundary",
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
const mutation_authority = "none";

const Decision = enum { approve, reject };
const PolicyStatus = enum { ready, blocked };
const CheckStatus = enum { pass, fail };

const Options = struct {
    application_boundary_path: []const u8,
    decision: Decision,
    reviewed_by: []const u8 = "ci-gate-required-status-check-enforcement-policy-reviewer",
    policy: []const u8 = "manual-production-telemetry-ci-gate-required-status-check-enforcement-policy",
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

const SourceEvidenceRequirement = struct {
    id: []const u8 = "",
    allowed: bool = false,
    detail: []const u8 = "",
};

const SourceNegativeFixture = struct {
    id: []const u8 = "",
    artifact_state: []const u8 = "",
    decision: []const u8 = "",
    failed_gate: []const u8 = "",
    reason: []const u8 = "",
};

const ApplicationBoundaryArtifact = struct {
    schema: []const u8,
    schema_version: u32,
    source_enforcement_readiness: []const u8 = "",
    source_enforcement_readiness_status: []const u8 = "",
    source_decision: []const u8 = "",
    source_ready_for_next_branch: bool = false,
    source_applied: bool = false,
    mode: []const u8,
    required_status_check_enforcement_application_status: []const u8,
    applied: bool,
    active_enforcement_recorded: bool = false,
    merge_blocking_recorded: bool = false,
    active_enforcement_claim_allowed: bool = false,
    merge_blocker_claim_allowed: bool = false,
    mutation_authority: []const u8,
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
    required_check_names: []const []const u8 = &.{},
    branch_protection_before: []const []const u8 = &.{},
    branch_protection_after: []const []const u8 = &.{},
    workflow_evidence: []const []const u8 = &.{},
    check_run_evidence: []const []const u8 = &.{},
    failure_mode_evidence: []const []const u8 = &.{},
    owner_approvals: []const []const u8 = &.{},
    rollback_evidence: []const []const u8 = &.{},
    merge_blocking_evidence: []const []const u8 = &.{},
    evidence_requirements: []const SourceEvidenceRequirement = &.{},
    checks: []const SourceCheck = &.{},
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
    active_enforcement_policy_ready: bool,
    merge_blocker_policy_ready: bool,
    checks: []const PolicyCheck,

    fn deinit(self: PolicyResult, allocator: std.mem.Allocator) void {
        if (self.checks.len > 0) allocator.free(self.checks);
    }
};

const InterpretationPolicy = struct {
    id: []const u8,
    source_state: []const u8,
    allowed_claim: []const u8,
    required_source_evidence: []const u8,
    denied_claims: []const u8,
    next_use: []const u8,
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

const enforcement_interpretation_policy: []const InterpretationPolicy = &.{
    .{
        .id = "planned-enforcement",
        .source_state = "planned",
        .allowed_claim = "planned enforcement application evidence may guide evaluator design only",
        .required_source_evidence = "required_status_check_enforcement_application_status=planned applied=false active_enforcement_recorded=false",
        .denied_claims = "active enforcement, merge blocking, GitHub mutation, production health, deployment success",
        .next_use = "future evaluator may treat this as design input, not active enforcement proof",
    },
    .{
        .id = "applied-active-enforcement",
        .source_state = "applied",
        .allowed_claim = "reviewed external active required status check enforcement record",
        .required_source_evidence = "required_status_check_enforcement_application_status=applied applied=true active_enforcement_recorded=true active_enforcement_claim_allowed=true",
        .denied_claims = "tool mutation, production health, deployment success, customer impact, cluster readiness",
        .next_use = "future evaluator may compare observed evidence against this policy",
    },
    .{
        .id = "merge-blocking",
        .source_state = "applied-with-merge-blocking-evidence",
        .allowed_claim = "reviewed external merge-blocking record for the required status check",
        .required_source_evidence = "merge_blocking_recorded=true merge_blocker_claim_allowed=true merge_blocking_evidence non-empty",
        .denied_claims = "tool mutation, workflow mutation, check-run creation, production health",
        .next_use = "future evaluator may require explicit merge-blocking evidence before citing merge blocker state",
    },
};

const evidence_requirements: []const EvidenceRequirement = &.{
    .{ .id = "source-enforcement-application-boundary", .allowed = true, .detail = "reviewed required-status-check enforcement application-boundary JSON artifact" },
    .{ .id = "source-branch-protection-before-after", .allowed = true, .detail = "bounded source before and after branch-protection evidence" },
    .{ .id = "source-workflow-or-check-run-evidence", .allowed = true, .detail = "bounded source workflow or check-run evidence" },
    .{ .id = "source-failure-mode-evidence", .allowed = true, .detail = "bounded source evidence for required-check failure behavior" },
    .{ .id = "source-owner-approval-and-rollback", .allowed = true, .detail = "bounded source owner approval and rollback evidence" },
    .{ .id = "source-merge-blocking-evidence", .allowed = true, .detail = "bounded merge-blocking evidence when merge blocker claims are allowed" },
    .{ .id = "required-verification-commands", .allowed = true, .detail = "complete source and policy verification command records" },
    .{ .id = "secret-values", .allowed = false, .detail = "secret-shaped values credentials tokens and private headers are never valid evidence" },
    .{ .id = "github-mutation-enabled-claims", .allowed = false, .detail = "policy does not mutate GitHub branch protection workflows check runs uploads summaries or comments" },
    .{ .id = "network-or-live-telemetry", .allowed = false, .detail = "policy does not configure collectors send networks or ingest live telemetry" },
    .{ .id = "production-database-writes", .allowed = false, .detail = "policy does not write production stores durable backends or NenDB" },
    .{ .id = "non-nendb-durable-adapters", .allowed = false, .detail = "durable direction remains NenDB adapter only" },
    .{ .id = "alternate-renderers", .allowed = false, .detail = "workbench direction remains SolidJS inside zig-webui" },
};

const denied_inference_rules: []const []const u8 = &.{
    "enforcement-policy-is-not-github-api-mutation-by-tool",
    "enforcement-policy-is-not-branch-protection-mutation-by-tool",
    "enforcement-policy-is-not-workflow-mutation-by-tool",
    "enforcement-policy-is-not-check-run-creation-by-tool",
    "enforcement-policy-is-not-ci-upload-execution-by-tool",
    "enforcement-policy-is-not-github-step-summary-or-pr-comment-write-by-tool",
    "active-enforcement-is-not-production-health-proof",
    "active-enforcement-is-not-deployment-success-proof",
    "active-enforcement-is-not-customer-impact-proof",
    "active-enforcement-is-not-production-cluster-readiness-proof",
    "active-enforcement-is-not-live-telemetry-coverage-proof",
    "active-enforcement-is-not-durable-or-nendb-write-proof",
    "merge-blocking-is-not-tool-mutation-proof",
    "enforcement-policy-grants-no-mutation-authority",
};

const negative_fixtures: []const NegativeFixture = &.{
    .{ .id = "blocked-source-application-denied", .artifact_state = "required_status_check_enforcement_application_status=blocked", .decision = "deny", .failed_gate = "source-boundary-status-valid", .reason = "blocked source application-boundary artifacts cannot feed enforcement policy" },
    .{ .id = "source-active-claim-without-applied-denied", .artifact_state = "active_enforcement_claim_allowed=true applied=false", .decision = "deny", .failed_gate = "source-active-claims-consistent", .reason = "active claims require applied source evidence" },
    .{ .id = "merge-blocker-without-evidence-denied", .artifact_state = "merge_blocker_claim_allowed=true merge_blocking_evidence=[]", .decision = "deny", .failed_gate = "source-merge-blocker-consistent", .reason = "merge-blocker claims require merge-blocking evidence" },
    .{ .id = "reviewer-reject-denied", .artifact_state = "decision=reject", .decision = "deny", .failed_gate = "reviewer-decision-approved", .reason = "reviewer rejection blocks policy readiness" },
    .{ .id = "missing-verification-denied", .artifact_state = "verified_commands=[]", .decision = "deny", .failed_gate = "policy-verification-recorded", .reason = "policy readiness needs all required verification commands" },
    .{ .id = "missing-release-gate-verification-denied", .artifact_state = "verified commands omit release gate or report", .decision = "deny", .failed_gate = "release-gate-verification-recorded", .reason = "release-gate and report verification are required" },
    .{ .id = "github-api-mutation-by-tool-denied", .artifact_state = "github_api_mutation_enabled=true", .decision = "deny", .failed_gate = "source-tool-authority-disabled", .reason = "policy does not call GitHub APIs" },
    .{ .id = "branch-protection-mutation-by-tool-denied", .artifact_state = "branch_protection_mutation_by_tool_enabled=true", .decision = "deny", .failed_gate = "source-tool-authority-disabled", .reason = "policy does not mutate branch protection" },
    .{ .id = "workflow-mutation-by-tool-denied", .artifact_state = "ci_workflow_mutation_enabled=true", .decision = "deny", .failed_gate = "source-tool-authority-disabled", .reason = "policy does not mutate workflows" },
    .{ .id = "check-run-creation-by-tool-denied", .artifact_state = "github_check_run_creation_enabled=true", .decision = "deny", .failed_gate = "source-tool-authority-disabled", .reason = "policy does not create check runs" },
    .{ .id = "ci-upload-execution-denied", .artifact_state = "ci_upload_execution_enabled=true", .decision = "deny", .failed_gate = "source-tool-authority-disabled", .reason = "policy does not upload CI artifacts" },
    .{ .id = "live-telemetry-denied", .artifact_state = "collector_endpoint_configured=true", .decision = "deny", .failed_gate = "source-runtime-and-storage-disabled", .reason = "policy does not configure collectors" },
    .{ .id = "durable-write-denied", .artifact_state = "durable_write_enabled=true", .decision = "deny", .failed_gate = "source-runtime-and-storage-disabled", .reason = "policy does not write durable stores" },
    .{ .id = "nendb-write-denied", .artifact_state = "nendb_write_enabled=true", .decision = "deny", .failed_gate = "source-runtime-and-storage-disabled", .reason = "NenDB adapter work remains future scope" },
    .{ .id = "non-nendb-durable-denied", .artifact_state = "durable_adapter=non-nendb", .decision = "deny", .failed_gate = "evidence-requirements-present", .reason = "non-NenDB durable adapters remain out of scope" },
    .{ .id = "alternate-renderer-denied", .artifact_state = "renderer=react", .decision = "deny", .failed_gate = "evidence-requirements-present", .reason = "workbench direction remains SolidJS inside zig-webui" },
    .{ .id = "production-health-claim-denied", .artifact_state = "production_health=proven", .decision = "deny", .failed_gate = "source-catalogs-present", .reason = "policy evidence is not production health proof" },
};

const blocked_claims: []const []const u8 = &.{
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
    "active-enforcement-without-source-applied-evidence",
    "merge-blocking-without-source-merge-blocking-evidence",
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

    var reviewed_by: []const u8 = "ci-gate-required-status-check-enforcement-policy-reviewer";
    var policy: []const u8 = "manual-production-telemetry-ci-gate-required-status-check-enforcement-policy";
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
    };
}

fn outputPathsForOptions(allocator: std.mem.Allocator, options: Options) !OutputPaths {
    const prefix = if (options.out_prefix) |out_prefix|
        try allocator.dupe(u8, out_prefix)
    else blk: {
        if (!std.mem.endsWith(u8, options.application_boundary_path, ".json")) return error.InvalidApplicationBoundaryPath;
        if (std.mem.endsWith(u8, options.application_boundary_path, "-ci-gate-required-status-check-enforcement-application-boundary.json")) {
            const suffix_len = "-ci-gate-required-status-check-enforcement-application-boundary.json".len;
            break :blk try std.fmt.allocPrint(allocator, "{s}-ci-gate-required-status-check-enforcement-policy", .{options.application_boundary_path[0 .. options.application_boundary_path.len - suffix_len]});
        }
        const base = options.application_boundary_path[0 .. options.application_boundary_path.len - ".json".len];
        break :blk try std.fmt.allocPrint(allocator, "{s}-ci-gate-required-status-check-enforcement-policy", .{base});
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

    try appendCheck(allocator, &checks, "source-schema", if (std.mem.eql(u8, source.schema, source_application_boundary_schema) and source.schema_version == 1) .pass else .fail, "source required-status-check enforcement application-boundary schema is supported");
    try appendCheck(allocator, &checks, "source-boundary-status-valid", if (sourceBoundaryStatusValid(source)) .pass else .fail, "source enforcement application-boundary is planned or applied, never blocked");
    try appendCheck(allocator, &checks, "source-application-state-consistent", if (sourceApplicationStateConsistent(source)) .pass else .fail, "source mode applied flag and mutation authority are internally consistent");
    try appendCheck(allocator, &checks, "source-tool-authority-disabled", if (sourceToolAuthorityDisabled(source)) .pass else .fail, "source keeps GitHub branch protection workflow check-run upload summary and comment authority disabled");
    try appendCheck(allocator, &checks, "source-runtime-and-storage-disabled", if (sourceRuntimeAndStorageDisabled(source)) .pass else .fail, "source keeps live telemetry network collector OTLP runtime durable and NenDB writes disabled");
    try appendCheck(allocator, &checks, "source-checks-passed", if (sourceChecksHaveNoFailures(source.checks)) .pass else .fail, "source checks contain no failures");
    try appendCheck(allocator, &checks, "source-catalogs-present", if (sourceCatalogsPresent(source)) .pass else .fail, "source evidence requirements denied rules negative fixtures blocked claims and verification catalogs are present");
    try appendCheck(allocator, &checks, "source-verification-recorded", if (verifiedCommandsContainAll(source.verified_commands, source.required_verification_commands)) .pass else .fail, "source recorded every source required verification command");
    try appendCheck(allocator, &checks, "source-active-claims-consistent", if (sourceActiveClaimsConsistent(source)) .pass else .fail, "source active enforcement claims match planned or applied source state");
    try appendCheck(allocator, &checks, "source-merge-blocker-consistent", if (sourceMergeBlockerConsistent(source)) .pass else .fail, "source merge-blocker claims require applied state and merge-blocking evidence");
    try appendCheck(allocator, &checks, "reviewer-decision-approved", if (options.decision == .approve) .pass else .fail, "reviewer approved the enforcement policy handoff");
    try appendCheck(allocator, &checks, "policy-verification-recorded", if (verifiedCommandsContainAll(options.verified_commands, required_verification_commands)) .pass else .fail, "enforcement policy review recorded every required verification command");
    try appendCheck(allocator, &checks, "release-gate-verification-recorded", if (verifiedCommandsContainAll(options.verified_commands, &.{ "zig build release-gate --summary none", "zig build release-gate-report" })) .pass else .fail, "release gate and release gate report commands are verified");
    try appendCheck(allocator, &checks, "interpretation-policy-present", if (enforcement_interpretation_policy.len == 3 and denied_inference_rules.len > 0) .pass else .fail, "planned active enforcement and merge-blocking interpretation rules are present");
    try appendCheck(allocator, &checks, "evidence-requirements-present", if (evidence_requirements.len > 0) .pass else .fail, "allowed and denied evidence requirements are present");
    try appendCheck(allocator, &checks, "negative-fixtures-present", if (negative_fixtures.len > 0) .pass else .fail, "negative fixtures are present");

    const check_slice = try checks.toOwnedSlice(allocator);
    errdefer allocator.free(check_slice);
    const ready = allChecksPassed(check_slice);
    return .{
        .status = if (ready) .ready else .blocked,
        .ready_for_next_branch = ready,
        .active_enforcement_policy_ready = ready and source.active_enforcement_recorded and source.active_enforcement_claim_allowed,
        .merge_blocker_policy_ready = ready and source.merge_blocking_recorded and source.merge_blocker_claim_allowed,
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
    return std.mem.eql(u8, source.required_status_check_enforcement_application_status, "planned") or
        std.mem.eql(u8, source.required_status_check_enforcement_application_status, "applied");
}

fn sourceApplicationStateConsistent(source: ApplicationBoundaryArtifact) bool {
    if (std.mem.eql(u8, source.required_status_check_enforcement_application_status, "planned")) {
        return std.mem.eql(u8, source.mode, "plan") and
            !source.applied and
            std.mem.eql(u8, source.mutation_authority, "none");
    }
    if (std.mem.eql(u8, source.required_status_check_enforcement_application_status, "applied")) {
        return std.mem.eql(u8, source.mode, "record-applied") and
            source.applied and
            std.mem.eql(u8, source.mutation_authority, "none");
    }
    return false;
}

fn sourceToolAuthorityDisabled(source: ApplicationBoundaryArtifact) bool {
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

fn sourceChecksHaveNoFailures(checks: []const SourceCheck) bool {
    if (checks.len == 0) return false;
    for (checks) |check| {
        if (std.mem.eql(u8, check.status, "fail")) return false;
    }
    return true;
}

fn sourceCatalogsPresent(source: ApplicationBoundaryArtifact) bool {
    return source.evidence_requirements.len > 0 and
        source.denied_inference_rules.len > 0 and
        source.negative_fixtures.len > 0 and
        source.blocked_claims.len > 0 and
        source.required_verification_commands.len > 0;
}

fn sourceActiveClaimsConsistent(source: ApplicationBoundaryArtifact) bool {
    if (std.mem.eql(u8, source.required_status_check_enforcement_application_status, "planned")) {
        return !source.active_enforcement_recorded and !source.active_enforcement_claim_allowed;
    }
    if (std.mem.eql(u8, source.required_status_check_enforcement_application_status, "applied")) {
        return source.active_enforcement_recorded and source.active_enforcement_claim_allowed;
    }
    return false;
}

fn sourceMergeBlockerConsistent(source: ApplicationBoundaryArtifact) bool {
    if (std.mem.eql(u8, source.required_status_check_enforcement_application_status, "planned")) {
        return !source.merge_blocking_recorded and
            !source.merge_blocker_claim_allowed and
            source.merge_blocking_evidence.len == 0;
    }
    if (std.mem.eql(u8, source.required_status_check_enforcement_application_status, "applied")) {
        if (!source.merge_blocking_recorded and !source.merge_blocker_claim_allowed) return true;
        return source.merge_blocking_recorded and
            source.merge_blocker_claim_allowed and
            source.merge_blocking_evidence.len > 0;
    }
    return false;
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
    try appendJsonField(allocator, &output, "schema", production_telemetry_ci_gate_required_status_check_enforcement_policy_schema, true);
    try output.print(allocator, "  \"schema_version\": {},\n", .{production_telemetry_ci_gate_required_status_check_enforcement_policy_schema_version});
    try appendJsonField(allocator, &output, "source_enforcement_application_boundary", options.application_boundary_path, true);
    try appendJsonField(allocator, &output, "source_enforcement_application_status", source.required_status_check_enforcement_application_status, true);
    try appendJsonField(allocator, &output, "source_mode", source.mode, true);
    try output.print(allocator, "  \"source_applied\": {},\n", .{source.applied});
    try output.print(allocator, "  \"source_active_enforcement_recorded\": {},\n", .{source.active_enforcement_recorded});
    try output.print(allocator, "  \"source_merge_blocking_recorded\": {},\n", .{source.merge_blocking_recorded});
    try output.print(allocator, "  \"source_active_enforcement_claim_allowed\": {},\n", .{source.active_enforcement_claim_allowed});
    try output.print(allocator, "  \"source_merge_blocker_claim_allowed\": {},\n", .{source.merge_blocker_claim_allowed});
    try appendJsonField(allocator, &output, "decision", decisionText(options.decision), true);
    try appendJsonField(allocator, &output, "reviewed_by", options.reviewed_by, true);
    try appendJsonField(allocator, &output, "policy", options.policy, true);
    try appendJsonField(allocator, &output, "reason", options.reason, true);
    try appendJsonField(allocator, &output, "required_status_check_enforcement_policy_status", policyStatusText(result.status), true);
    try output.print(allocator, "  \"ready_for_next_branch\": {},\n", .{result.ready_for_next_branch});
    try output.print(allocator, "  \"active_enforcement_policy_ready\": {},\n", .{result.active_enforcement_policy_ready});
    try output.print(allocator, "  \"merge_blocker_policy_ready\": {},\n", .{result.merge_blocker_policy_ready});
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
    try appendJsonField(allocator, &output, "mutation_authority", mutation_authority, true);
    try output.appendSlice(allocator, "  \"enforcement_interpretation_policy\": ");
    try appendInterpretationPolicyJson(allocator, &output);
    try output.appendSlice(allocator, ",\n  \"evidence_requirements\": ");
    try appendEvidenceRequirementsJson(allocator, &output);
    try output.appendSlice(allocator, ",\n  \"checks\": ");
    try appendChecksJson(allocator, &output, result.checks);
    try output.appendSlice(allocator, ",\n  \"denied_inference_rules\": ");
    try appendStringArray(allocator, &output, denied_inference_rules);
    try output.appendSlice(allocator, ",\n  \"negative_fixtures\": ");
    try appendNegativeFixturesJson(allocator, &output);
    try output.appendSlice(allocator, ",\n  \"blocked_claims\": ");
    try appendStringArray(allocator, &output, blocked_claims);
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

    try output.appendSlice(allocator, "zigeffect production telemetry CI gate required status check enforcement policy\n");
    try output.print(allocator, "schema: {s}\n", .{production_telemetry_ci_gate_required_status_check_enforcement_policy_schema});
    try output.print(allocator, "source enforcement application boundary: {s}\n", .{options.application_boundary_path});
    try output.print(allocator, "source enforcement application status: {s}\n", .{source.required_status_check_enforcement_application_status});
    try output.print(allocator, "source mode: {s}\n", .{source.mode});
    try output.print(allocator, "source applied: {}\n", .{source.applied});
    try output.print(allocator, "source active enforcement recorded: {}\n", .{source.active_enforcement_recorded});
    try output.print(allocator, "source merge blocking recorded: {}\n", .{source.merge_blocking_recorded});
    try output.print(allocator, "decision: {s}\n", .{decisionText(options.decision)});
    try output.print(allocator, "required status check enforcement policy: {s}\n", .{policyStatusText(result.status)});
    try output.print(allocator, "ready for next branch: {}\n", .{result.ready_for_next_branch});
    try output.print(allocator, "active enforcement policy ready: {}\n", .{result.active_enforcement_policy_ready});
    try output.print(allocator, "merge blocker policy ready: {}\n", .{result.merge_blocker_policy_ready});
    try output.print(allocator, "mutation authority: {s}\n", .{mutation_authority});
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

    try appendInterpretationPolicyText(allocator, &output);
    try appendEvidenceRequirementsText(allocator, &output);
    try appendTextList(allocator, &output, "denied inference rules", denied_inference_rules);
    try appendNegativeFixturesText(allocator, &output);
    try appendTextList(allocator, &output, "blocked claims", blocked_claims);
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

fn appendInterpretationPolicyJson(allocator: std.mem.Allocator, output: *std.ArrayList(u8)) !void {
    try output.append(allocator, '[');
    for (enforcement_interpretation_policy, 0..) |policy, index| {
        if (index > 0) try output.appendSlice(allocator, ", ");
        try output.appendSlice(allocator, "{ \"id\": ");
        try appendJsonString(allocator, output, policy.id);
        try output.appendSlice(allocator, ", \"source_state\": ");
        try appendJsonString(allocator, output, policy.source_state);
        try output.appendSlice(allocator, ", \"allowed_claim\": ");
        try appendJsonString(allocator, output, policy.allowed_claim);
        try output.appendSlice(allocator, ", \"required_source_evidence\": ");
        try appendJsonString(allocator, output, policy.required_source_evidence);
        try output.appendSlice(allocator, ", \"denied_claims\": ");
        try appendJsonString(allocator, output, policy.denied_claims);
        try output.appendSlice(allocator, ", \"next_use\": ");
        try appendJsonString(allocator, output, policy.next_use);
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

fn appendInterpretationPolicyText(allocator: std.mem.Allocator, output: *std.ArrayList(u8)) !void {
    try output.appendSlice(allocator, "enforcement interpretation policy:\n");
    for (enforcement_interpretation_policy) |policy| {
        try output.print(allocator, "- {s}: source_state={s}; allowed={s}; required={s}; denied={s}; next_use={s}\n", .{
            policy.id,
            policy.source_state,
            policy.allowed_claim,
            policy.required_source_evidence,
            policy.denied_claims,
            policy.next_use,
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
        try output.print(allocator, "- {s}: {s}\n", .{ fixture.id, fixture.reason });
    }
    try output.append(allocator, '\n');
}

fn agentGuidance(status: PolicyStatus) []const []const u8 {
    return switch (status) {
        .ready => &.{
            "Start the required-status-check enforcement evaluator branch with bounded local or CI artifact inputs only.",
            "Active enforcement and merge-blocker claims must cite source application-boundary evidence and this interpretation policy.",
            "Do not infer GitHub mutation by this tool, live telemetry, production health, durable writes, NenDB writes, or non-NenDB adapter readiness.",
        },
        .blocked => &.{
            "Treat blocked required-status-check enforcement policy evidence as a stop sign.",
            "Repair source application-boundary validity reviewer decision or verification proof before starting the evaluator branch.",
            "Do not cite active enforcement or merge blocking from blocked policy artifacts.",
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
    return "usage: zig build causal-production-telemetry-ci-gate-required-status-check-enforcement-policy -- --from-application-boundary <required-status-check-enforcement-application-boundary.json> approve|reject --reason <reason> [--by <actor>] [--policy <policy>] [--verified-command <command>]... [--out-prefix <path-prefix>]\n";
}

fn failUsage(err: anyerror) noreturn {
    std.debug.print("causal-production-telemetry-ci-gate-required-status-check-enforcement-policy error: {s}\n{s}", .{ @errorName(err), usage() });
    std.process.exit(2);
}

fn freeSliceOnly(allocator: std.mem.Allocator, values: []const []const u8) void {
    if (values.len > 0) allocator.free(values);
}

test "required status check enforcement policy constants are stable" {
    try std.testing.expectEqualStrings(
        "zigeffect.causal.production-telemetry-ci-gate-required-status-check-enforcement-policy.v1",
        production_telemetry_ci_gate_required_status_check_enforcement_policy_schema,
    );
    try std.testing.expectEqual(@as(u32, 1), production_telemetry_ci_gate_required_status_check_enforcement_policy_schema_version);
    try std.testing.expectEqualStrings(
        "codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-enforcement-policy",
        source_branch,
    );
    try std.testing.expectEqualStrings(
        "start-production-telemetry-ci-gate-required-status-check-enforcement-evaluator",
        recommendation,
    );
    try std.testing.expectEqualStrings(
        "codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-enforcement-evaluator",
        next_branch_if_ready,
    );
    try std.testing.expect(containsString(required_verification_commands, "zig build causal-production-telemetry-ci-gate-required-status-check-enforcement-application-boundary"));
    try std.testing.expect(containsString(required_verification_commands, "zig build release-gate-report"));
}

test "parseOptions parses approval and repeated verified commands" {
    var options = try parseOptions(std.testing.allocator, &.{
        "zigeffect-causal-production-telemetry-ci-gate-required-status-check-enforcement-policy",
        "--from-application-boundary",
        ".zig-cache/causal-artifacts/required-status-check-enforcement-application-boundary.json",
        "approve",
        "--reason",
        "required status check enforcement policy reviewed",
        "--by",
        "codex",
        "--policy",
        "manual-production-telemetry-ci-gate-required-status-check-enforcement-policy",
        "--verified-command",
        "zig build test",
        "--verified-command",
        "bun run check",
        "--out-prefix",
        ".zig-cache/causal-artifacts/custom-required-status-check-enforcement-policy",
    });
    defer options.deinit(std.testing.allocator);

    try std.testing.expectEqual(Decision.approve, options.decision);
    try std.testing.expectEqualStrings(".zig-cache/causal-artifacts/required-status-check-enforcement-application-boundary.json", options.application_boundary_path);
    try std.testing.expectEqualStrings("codex", options.reviewed_by);
    try std.testing.expectEqualStrings("manual-production-telemetry-ci-gate-required-status-check-enforcement-policy", options.policy);
    try std.testing.expectEqual(@as(usize, 2), options.verified_commands.len);
    try std.testing.expectEqualStrings("zig build test", options.verified_commands[0]);
    try std.testing.expectEqualStrings("bun run check", options.verified_commands[1]);
    try std.testing.expectEqualStrings(".zig-cache/causal-artifacts/custom-required-status-check-enforcement-policy", options.out_prefix.?);
}

test "parseOptions rejects missing or invalid input" {
    try std.testing.expectError(error.MissingApplicationBoundaryPath, parseOptions(std.testing.allocator, &.{"tool"}));
    try std.testing.expectError(error.InvalidApplicationBoundaryPath, parseOptions(std.testing.allocator, &.{ "tool", "--from-application-boundary", "source.txt", "approve", "--reason", "reviewed" }));
    try std.testing.expectError(error.UnknownDecision, parseOptions(std.testing.allocator, &.{ "tool", "--from-application-boundary", "source.json", "maybe", "--reason", "reviewed" }));
    try std.testing.expectError(error.MissingReason, parseOptions(std.testing.allocator, &.{ "tool", "--from-application-boundary", "source.json", "approve" }));
}

test "default output path replaces enforcement application boundary suffix" {
    const options = Options{
        .application_boundary_path = "../../.zig-cache/causal-artifacts/example-ci-gate-required-status-check-enforcement-application-boundary.json",
        .decision = .approve,
        .reason = "planned",
    };
    const paths = try outputPathsForOptions(std.testing.allocator, options);
    defer paths.deinit(std.testing.allocator);

    try std.testing.expectEqualStrings("../../.zig-cache/causal-artifacts/example-ci-gate-required-status-check-enforcement-policy.json", paths.json_path);
    try std.testing.expectEqualStrings("../../.zig-cache/causal-artifacts/example-ci-gate-required-status-check-enforcement-policy.txt", paths.text_path);
}

test "approved planned application boundary yields ready policy without active claims" {
    const result = try evaluateFixture(planned_application_boundary_json, .approve, required_verification_commands);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(PolicyStatus.ready, result.status);
    try std.testing.expect(result.ready_for_next_branch);
    try std.testing.expect(!result.active_enforcement_policy_ready);
    try std.testing.expect(!result.merge_blocker_policy_ready);
}

test "approved applied active boundary yields active ready policy without merge blocker" {
    const result = try evaluateFixture(applied_active_application_boundary_json, .approve, required_verification_commands);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(PolicyStatus.ready, result.status);
    try std.testing.expect(result.ready_for_next_branch);
    try std.testing.expect(result.active_enforcement_policy_ready);
    try std.testing.expect(!result.merge_blocker_policy_ready);
}

test "approved applied merge-blocking boundary yields merge blocker policy" {
    const result = try evaluateFixture(applied_merge_blocking_application_boundary_json, .approve, required_verification_commands);
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(PolicyStatus.ready, result.status);
    try std.testing.expect(result.ready_for_next_branch);
    try std.testing.expect(result.active_enforcement_policy_ready);
    try std.testing.expect(result.merge_blocker_policy_ready);
}

test "blocked source reject missing verification and inconsistent active claims block policy" {
    const rejected = try evaluateFixture(planned_application_boundary_json, .reject, required_verification_commands);
    defer rejected.deinit(std.testing.allocator);
    try std.testing.expectEqual(PolicyStatus.blocked, rejected.status);

    const incomplete = try evaluateFixture(planned_application_boundary_json, .approve, &.{});
    defer incomplete.deinit(std.testing.allocator);
    try std.testing.expectEqual(PolicyStatus.blocked, incomplete.status);

    const source_blocked = try evaluateFixture(blocked_application_boundary_json, .approve, required_verification_commands);
    defer source_blocked.deinit(std.testing.allocator);
    try std.testing.expectEqual(PolicyStatus.blocked, source_blocked.status);

    const inconsistent = try evaluateFixture(inconsistent_active_application_boundary_json, .approve, required_verification_commands);
    defer inconsistent.deinit(std.testing.allocator);
    try std.testing.expectEqual(PolicyStatus.blocked, inconsistent.status);
}

test "reports include required policy fields and guidance" {
    const reports = try formatReports(std.testing.allocator, .{
        .options = .{
            .application_boundary_path = ".zig-cache/causal-artifacts/required-status-check-enforcement-application-boundary.json",
            .decision = .approve,
            .reason = "required status check enforcement policy reviewed",
            .verified_commands = required_verification_commands,
        },
        .source_application_boundary_json = planned_application_boundary_json,
    });
    defer reports.deinit(std.testing.allocator);

    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"schema\": \"zigeffect.causal.production-telemetry-ci-gate-required-status-check-enforcement-policy.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"required_status_check_enforcement_policy_status\": \"ready\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"ready_for_next_branch\": true") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"active_enforcement_policy_ready\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"merge_blocker_policy_ready\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"mutation_authority\": \"none\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"next_branch_if_ready\": \"codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-enforcement-evaluator\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.text, "required status check enforcement policy: ready") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.text, "active enforcement policy ready: false") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.text, "merge blocker policy ready: false") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.text, "recommendation: start-production-telemetry-ci-gate-required-status-check-enforcement-evaluator") != null);
}

fn evaluateFixture(source_json: []const u8, decision: Decision, verified_commands: []const []const u8) !PolicyResult {
    var parsed = try std.json.parseFromSlice(ApplicationBoundaryArtifact, std.testing.allocator, source_json, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();
    return evaluatePolicy(std.testing.allocator, .{
        .application_boundary_path = ".zig-cache/causal-artifacts/required-status-check-enforcement-application-boundary.json",
        .decision = decision,
        .reason = "required status check enforcement policy reviewed",
        .verified_commands = verified_commands,
    }, parsed.value);
}

fn containsString(values: []const []const u8, needle: []const u8) bool {
    for (values) |value| {
        if (std.mem.indexOf(u8, value, needle) != null) return true;
    }
    return false;
}

const source_required_verification_json =
    \\"zig build causal-production-telemetry-ci-gate-required-status-check-enforcement-readiness",
    \\"zig build causal-artifacts",
    \\"zig build release-gate --summary none",
    \\"zig build release-gate-report"
;

const source_common_catalog_json =
    \\"evidence_requirements": [
    \\  { "id": "required-check-name", "allowed": true, "detail": "exact required check names" },
    \\  { "id": "secret-values", "allowed": false, "detail": "secrets are denied" }
    \\],
    \\"checks": [
    \\  { "name": "source-schema", "status": "pass", "detail": "source schema is supported" },
    \\  { "name": "verification-recorded", "status": "pass", "detail": "source verification recorded" }
    \\],
    \\"denied_inference_rules": ["github-api-mutation-by-tool", "production-health-proof"],
    \\"negative_fixtures": [
    \\  { "id": "blocked-source-denied", "artifact_state": "blocked", "decision": "deny", "failed_gate": "source-boundary-status-valid", "reason": "blocked source denied" }
    \\],
    \\"blocked_claims": ["runtime-pipeline-enabled", "live-exporter-enabled", "nendb-write-enabled"],
    \\"required_verification_commands": [
    \\
++ source_required_verification_json ++
    \\],
    \\"verified_commands": [
    \\
++ source_required_verification_json ++
    \\]
;

const planned_application_boundary_json =
    \\{
    \\  "schema": "zigeffect.causal.production-telemetry-ci-gate-required-status-check-enforcement-application-boundary.v1",
    \\  "schema_version": 1,
    \\  "source_enforcement_readiness": ".zig-cache/causal-artifacts/enforcement-readiness.json",
    \\  "source_enforcement_readiness_status": "ready",
    \\  "source_decision": "approve",
    \\  "source_ready_for_next_branch": true,
    \\  "source_applied": true,
    \\  "mode": "plan",
    \\  "required_status_check_enforcement_application_status": "planned",
    \\  "applied": false,
    \\  "active_enforcement_recorded": false,
    \\  "merge_blocking_recorded": false,
    \\  "active_enforcement_claim_allowed": false,
    \\  "merge_blocker_claim_allowed": false,
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
    \\  
++ source_common_catalog_json ++
    \\
    \\}
;

const applied_active_application_boundary_json =
    \\{
    \\  "schema": "zigeffect.causal.production-telemetry-ci-gate-required-status-check-enforcement-application-boundary.v1",
    \\  "schema_version": 1,
    \\  "source_enforcement_readiness": ".zig-cache/causal-artifacts/enforcement-readiness.json",
    \\  "source_enforcement_readiness_status": "ready",
    \\  "source_decision": "approve",
    \\  "source_ready_for_next_branch": true,
    \\  "source_applied": true,
    \\  "mode": "record-applied",
    \\  "required_status_check_enforcement_application_status": "applied",
    \\  "applied": true,
    \\  "active_enforcement_recorded": true,
    \\  "merge_blocking_recorded": false,
    \\  "active_enforcement_claim_allowed": true,
    \\  "merge_blocker_claim_allowed": false,
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
    \\  "required_check_names": ["zigeffect causal release gate"],
    \\  "branch_protection_before": ["before required check absent"],
    \\  "branch_protection_after": ["after required check present"],
    \\  "workflow_evidence": ["release gate workflow evidence"],
    \\  "check_run_evidence": [],
    \\  "failure_mode_evidence": ["failed gate blocks merge"],
    \\  "owner_approvals": ["owner approved enforcement"],
    \\  "rollback_evidence": ["remove required check from branch protection"],
    \\  
++ source_common_catalog_json ++
    \\
    \\}
;

const applied_merge_blocking_application_boundary_json =
    \\{
    \\  "schema": "zigeffect.causal.production-telemetry-ci-gate-required-status-check-enforcement-application-boundary.v1",
    \\  "schema_version": 1,
    \\  "source_enforcement_readiness": ".zig-cache/causal-artifacts/enforcement-readiness.json",
    \\  "source_enforcement_readiness_status": "ready",
    \\  "source_decision": "approve",
    \\  "source_ready_for_next_branch": true,
    \\  "source_applied": true,
    \\  "mode": "record-applied",
    \\  "required_status_check_enforcement_application_status": "applied",
    \\  "applied": true,
    \\  "active_enforcement_recorded": true,
    \\  "merge_blocking_recorded": true,
    \\  "active_enforcement_claim_allowed": true,
    \\  "merge_blocker_claim_allowed": true,
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
    \\  "required_check_names": ["zigeffect causal release gate"],
    \\  "branch_protection_before": ["before required check absent"],
    \\  "branch_protection_after": ["after required check present"],
    \\  "workflow_evidence": ["release gate workflow evidence"],
    \\  "check_run_evidence": [],
    \\  "failure_mode_evidence": ["failed gate blocks merge"],
    \\  "owner_approvals": ["owner approved enforcement"],
    \\  "rollback_evidence": ["remove required check from branch protection"],
    \\  "merge_blocking_evidence": ["merge is blocked when required check fails"],
    \\  
++ source_common_catalog_json ++
    \\
    \\}
;

const blocked_application_boundary_json =
    \\{
    \\  "schema": "zigeffect.causal.production-telemetry-ci-gate-required-status-check-enforcement-application-boundary.v1",
    \\  "schema_version": 1,
    \\  "mode": "plan",
    \\  "required_status_check_enforcement_application_status": "blocked",
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
    \\  
++ source_common_catalog_json ++
    \\
    \\}
;

const inconsistent_active_application_boundary_json =
    \\{
    \\  "schema": "zigeffect.causal.production-telemetry-ci-gate-required-status-check-enforcement-application-boundary.v1",
    \\  "schema_version": 1,
    \\  "mode": "plan",
    \\  "required_status_check_enforcement_application_status": "planned",
    \\  "applied": false,
    \\  "active_enforcement_recorded": true,
    \\  "active_enforcement_claim_allowed": true,
    \\  "merge_blocking_recorded": false,
    \\  "merge_blocker_claim_allowed": false,
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
    \\  
++ source_common_catalog_json ++
    \\
    \\}
;
