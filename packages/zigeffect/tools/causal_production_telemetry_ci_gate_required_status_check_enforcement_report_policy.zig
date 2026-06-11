const std = @import("std");

pub const production_telemetry_ci_gate_required_status_check_enforcement_report_policy_schema = "zigeffect.causal.production-telemetry-ci-gate-required-status-check-enforcement-report-policy.v1";
pub const production_telemetry_ci_gate_required_status_check_enforcement_report_policy_schema_version: u32 = 1;
pub const source_branch = "codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-enforcement-report-policy";
pub const recommendation = "refresh-production-hardening-backlog";
pub const next_branch_if_ready = "codex/zigeffect-causal-production-hardening-backlog-refresh";

const source_application_boundary_schema = "zigeffect.causal.production-telemetry-ci-gate-required-status-check-enforcement-report-application-boundary.v1";
const generated_by = "causal-production-telemetry-ci-gate-required-status-check-enforcement-report-policy";
const source_application_boundary_suffix = "-ci-gate-required-status-check-enforcement-report-application-boundary.json";
const output_prefix_suffix = "-ci-gate-required-status-check-enforcement-report-policy";
const compact_output_prefix_name = "production-telemetry-ci-gate-required-status-check-enforcement-report-policy";
const max_default_output_file_name_len = 240;
const max_source_bytes = 1024 * 1024;

const required_verification_commands: []const []const u8 = &.{
    "zig build causal-production-telemetry-ci-gate-required-status-check-enforcement-report-application-boundary",
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
    reviewed_by: []const u8 = "ci-gate-required-status-check-enforcement-report-policy-reviewer",
    policy: []const u8 = "manual-production-telemetry-ci-gate-required-status-check-enforcement-report-policy",
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

const ApplicationBoundaryArtifact = struct {
    schema: []const u8,
    schema_version: u32,
    source_enforcement_report: []const u8 = "",
    source_report_status: []const u8 = "",
    mode: []const u8,
    report_application_boundary_status: []const u8,
    applied: bool,
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
    report_after_path: ?[]const u8 = null,
    after_report_digest: []const u8 = "",
    after_report_present: bool = false,
    application_changes: []const []const u8 = &.{},
    before_evidence: []const []const u8 = &.{},
    after_evidence: []const []const u8 = &.{},
    source_checks: []const SourceCheck = &.{},
    application_checks: []const SourceCheck = &.{},
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
    published_report_policy_ready: bool,
    checks: []const PolicyCheck,

    fn deinit(self: PolicyResult, allocator: std.mem.Allocator) void {
        if (self.checks.len > 0) allocator.free(self.checks);
    }
};

const InterpretationRule = struct {
    id: []const u8,
    consumer_role: []const u8,
    allowed_use: []const u8,
    failure_effect: []const u8,
    denied_claim: []const u8,
};

const PublicationSurface = struct {
    id: []const u8,
    visibility_class: []const u8,
    executed_by_tool: bool,
    interpretation_scope: []const u8,
};

const NegativeFixture = struct {
    id: []const u8,
    artifact_state: []const u8,
    decision: []const u8,
    failed_gate: []const u8,
    reason: []const u8,
};

const interpretation_rules: []const InterpretationRule = &.{
    .{ .id = "planned-report-application", .consumer_role = "reviewer", .allowed_use = "plan future report publication review only", .failure_effect = "none", .denied_claim = "published report proof" },
    .{ .id = "applied-report-publication", .consumer_role = "reviewer", .allowed_use = "cite externally reviewed report application evidence", .failure_effect = "record-only", .denied_claim = "tool publication proof" },
    .{ .id = "agent-readonly-context", .consumer_role = "agent-readonly", .allowed_use = "cite report ids checks denied claims and next-query guidance", .failure_effect = "informational", .denied_claim = "mutation authority" },
    .{ .id = "backlog-refresh-input", .consumer_role = "future-backlog-refresh", .allowed_use = "choose the next unresolved roadmap item after report policy", .failure_effect = "planning-input", .denied_claim = "production readiness" },
};

const publication_surfaces: []const PublicationSurface = &.{
    .{ .id = "local-json-artifact", .visibility_class = "local-or-ci-internal-redacted", .executed_by_tool = false, .interpretation_scope = "machine-readable report policy evidence" },
    .{ .id = "local-text-report", .visibility_class = "local-or-ci-internal-redacted", .executed_by_tool = false, .interpretation_scope = "human-readable report policy evidence" },
    .{ .id = "external-reviewed-report", .visibility_class = "reviewed-ci-internal", .executed_by_tool = false, .interpretation_scope = "externally applied report evidence already recorded by source boundary" },
};

const denied_inference_rules: []const []const u8 = &.{
    "report-policy-is-not-github-api-mutation-by-tool",
    "report-policy-is-not-branch-protection-mutation-by-tool",
    "report-policy-is-not-workflow-mutation-by-tool",
    "report-policy-is-not-check-run-creation-by-tool",
    "report-policy-is-not-required-status-check-creation-by-tool",
    "report-policy-is-not-ci-upload-execution-by-tool",
    "report-policy-is-not-github-step-summary-or-pr-comment-write-by-tool",
    "published-report-policy-is-not-production-health-proof",
    "published-report-policy-is-not-deployment-success-proof",
    "published-report-policy-is-not-customer-impact-proof",
    "published-report-policy-is-not-production-cluster-readiness-proof",
    "published-report-policy-is-not-live-telemetry-coverage-proof",
    "published-report-policy-is-not-durable-or-nendb-write-proof",
    "report-policy-grants-no-mutation-authority",
    "report-policy-does-not-authorize-non-nendb-durable-adapters",
    "report-policy-does-not-authorize-alternate-renderers",
};

const negative_fixtures: []const NegativeFixture = &.{
    .{ .id = "blocked-source-denied", .artifact_state = "report_application_boundary_status=blocked", .decision = "deny", .failed_gate = "source-boundary-status-valid", .reason = "blocked application-boundary evidence cannot feed report policy" },
    .{ .id = "planned-source-published-readiness-denied", .artifact_state = "report_application_boundary_status=planned", .decision = "allow-ready-deny-published", .failed_gate = "published-report-policy-ready", .reason = "planned source can guide policy but cannot prove published report readiness" },
    .{ .id = "missing-application-evidence-denied", .artifact_state = "applied source without application before after evidence", .decision = "deny", .failed_gate = "source-application-evidence-present", .reason = "applied report policy readiness requires bounded source application evidence" },
    .{ .id = "required-status-check-claim-denied", .artifact_state = "required_status_check=true", .decision = "deny", .failed_gate = "source-ci-enforcement-disabled", .reason = "report policy cannot create required status checks" },
    .{ .id = "merge-blocking-claim-denied", .artifact_state = "failure_effect=merge-blocking", .decision = "deny", .failed_gate = "interpretation-rules-present", .reason = "report policy evidence remains non-blocking" },
    .{ .id = "publication-execution-claim-denied", .artifact_state = "ci_report_publication_enabled=true", .decision = "deny", .failed_gate = "source-publication-execution-disabled", .reason = "this tool defines interpretation policy only" },
    .{ .id = "github-step-summary-claim-denied", .artifact_state = "github_step_summary_write_enabled=true", .decision = "deny", .failed_gate = "source-publication-execution-disabled", .reason = "this tool does not write GitHub summaries" },
    .{ .id = "pull-request-comment-claim-denied", .artifact_state = "pull_request_comment_enabled=true", .decision = "deny", .failed_gate = "source-publication-execution-disabled", .reason = "this tool does not post pull request comments" },
    .{ .id = "production-health-claim-denied", .artifact_state = "production_health=proven", .decision = "deny", .failed_gate = "interpretation-rules-present", .reason = "CI report evidence is not production health evidence" },
    .{ .id = "cluster-readiness-claim-denied", .artifact_state = "production_cluster_ready=true", .decision = "deny", .failed_gate = "interpretation-rules-present", .reason = "report evidence cannot prove cluster readiness" },
    .{ .id = "mutation-authority-claim-denied", .artifact_state = "mutation_authority=granted", .decision = "deny", .failed_gate = "source-record-only-authority", .reason = "report policy grants no mutation authority" },
    .{ .id = "non-nendb-durable-scope-denied", .artifact_state = "durable_adapter=non-nendb", .decision = "deny", .failed_gate = "source-runtime-and-storage-disabled", .reason = "durable direction remains NenDB adapter only" },
    .{ .id = "alternate-renderer-scope-denied", .artifact_state = "renderer=react", .decision = "deny", .failed_gate = "interpretation-rules-present", .reason = "workbench direction remains SolidJS inside zig-webui" },
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

    var reviewed_by: []const u8 = "ci-gate-required-status-check-enforcement-report-policy-reviewer";
    var policy: []const u8 = "manual-production-telemetry-ci-gate-required-status-check-enforcement-report-policy";
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
    else
        try defaultOutputPrefix(allocator, options.application_boundary_path);
    defer allocator.free(prefix);

    return .{
        .json_path = try std.fmt.allocPrint(allocator, "{s}.json", .{prefix}),
        .text_path = try std.fmt.allocPrint(allocator, "{s}.txt", .{prefix}),
    };
}

fn defaultOutputPrefix(allocator: std.mem.Allocator, application_boundary_path: []const u8) ![]const u8 {
    if (!std.mem.endsWith(u8, application_boundary_path, ".json")) return error.InvalidApplicationBoundaryPath;

    const base = if (std.mem.endsWith(u8, application_boundary_path, source_application_boundary_suffix))
        application_boundary_path[0 .. application_boundary_path.len - source_application_boundary_suffix.len]
    else
        application_boundary_path[0 .. application_boundary_path.len - ".json".len];
    const candidate = try std.fmt.allocPrint(allocator, "{s}{s}", .{ base, output_prefix_suffix });
    errdefer allocator.free(candidate);

    if (fileName(candidate).len + ".json".len <= max_default_output_file_name_len) {
        return candidate;
    }

    const directory = directoryPrefix(candidate);
    const digest = shortPathDigest(application_boundary_path);
    const compact_prefix = try std.fmt.allocPrint(allocator, "{s}{s}-{s}", .{ directory, compact_output_prefix_name, digest[0..] });
    allocator.free(candidate);
    return compact_prefix;
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

    try appendCheck(allocator, &checks, "source-schema", if (std.mem.eql(u8, source.schema, source_application_boundary_schema) and source.schema_version == 1) .pass else .fail, "source required status check enforcement report application-boundary schema is supported");
    try appendCheck(allocator, &checks, "source-boundary-status-valid", if (sourceBoundaryStatusValid(source)) .pass else .fail, "source report application-boundary is planned or applied, never blocked");
    try appendCheck(allocator, &checks, "source-application-state-consistent", if (sourceApplicationStateConsistent(source)) .pass else .fail, "source mode applied flag evidence and mutation authority are internally consistent");
    try appendCheck(allocator, &checks, "source-record-only-authority", if (sourceMutationAuthorityValid(source) and std.mem.eql(u8, mutation_authority, "none")) .pass else .fail, "source is record-only or none and policy grants no mutation authority");
    try appendCheck(allocator, &checks, "source-publication-execution-disabled", if (sourcePublicationExecutionDisabled(source)) .pass else .fail, "source did not publish reports upload artifacts write summaries or post comments by the tool");
    try appendCheck(allocator, &checks, "source-ci-enforcement-disabled", if (sourceCiEnforcementDisabled(source)) .pass else .fail, "source keeps CI gate enforcement required checks and workflow mutation disabled");
    try appendCheck(allocator, &checks, "source-github-authority-disabled", if (sourceGithubAuthorityDisabled(source)) .pass else .fail, "source keeps GitHub API check-run and branch-protection authority disabled");
    try appendCheck(allocator, &checks, "source-runtime-and-storage-disabled", if (sourceRuntimeAndStorageDisabled(source)) .pass else .fail, "source keeps live telemetry network runtime durable and NenDB writes disabled");
    try appendCheck(allocator, &checks, "source-application-evidence-present", if (sourceApplicationEvidencePresent(source)) .pass else .fail, "planned source does not need application evidence and applied source has application before after and after-report digest evidence");
    try appendCheck(allocator, &checks, "source-checks-passed", if (sourceChecksPassed(source.source_checks) and sourceChecksPassed(source.application_checks)) .pass else .fail, "source checks and application checks contain no failures");
    try appendCheck(allocator, &checks, "source-catalogs-present", if (sourceCatalogsPresent(source)) .pass else .fail, "source blocked claims negative fixtures and verification catalogs are present");
    try appendCheck(allocator, &checks, "source-verification-recorded", if (verifiedCommandsContainAll(source.verified_commands, source.required_verification_commands)) .pass else .fail, "source recorded every source required verification command");
    try appendCheck(allocator, &checks, "decision-approved", if (options.decision == .approve) .pass else .fail, "reviewer approved the publication interpretation policy");
    try appendCheck(allocator, &checks, "policy-verification-recorded", if (verifiedCommandsContainAll(options.verified_commands, required_verification_commands)) .pass else .fail, "report policy recorded every required verification command");
    try appendCheck(allocator, &checks, "release-gate-verification-recorded", if (verifiedCommandsContainAll(options.verified_commands, &.{ "zig build release-gate --summary none", "zig build release-gate-report" })) .pass else .fail, "release gate and report commands are verified");
    try appendCheck(allocator, &checks, "interpretation-rules-present", if (interpretationCatalogsComplete()) .pass else .fail, "allowed and denied interpretation catalogs are complete");

    const check_slice = try checks.toOwnedSlice(allocator);
    errdefer allocator.free(check_slice);
    const ready = allChecksPassed(check_slice);
    return .{
        .status = if (ready) .ready else .blocked,
        .ready_for_next_branch = ready,
        .published_report_policy_ready = ready and std.mem.eql(u8, source.report_application_boundary_status, "applied") and source.applied,
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
    return std.mem.eql(u8, source.report_application_boundary_status, "planned") or
        std.mem.eql(u8, source.report_application_boundary_status, "applied");
}

fn sourceApplicationStateConsistent(source: ApplicationBoundaryArtifact) bool {
    if (std.mem.eql(u8, source.report_application_boundary_status, "planned")) {
        return std.mem.eql(u8, source.mode, "plan") and
            !source.applied and
            std.mem.eql(u8, source.mutation_authority, "none");
    }
    if (std.mem.eql(u8, source.report_application_boundary_status, "applied")) {
        return std.mem.eql(u8, source.mode, "record-applied") and
            source.applied and
            std.mem.eql(u8, source.mutation_authority, "record-only");
    }
    return false;
}

fn sourceMutationAuthorityValid(source: ApplicationBoundaryArtifact) bool {
    return std.mem.eql(u8, source.mutation_authority, "none") or
        std.mem.eql(u8, source.mutation_authority, "record-only");
}

fn sourcePublicationExecutionDisabled(source: ApplicationBoundaryArtifact) bool {
    return !source.ci_report_publication_enabled and
        !source.github_step_summary_write_enabled and
        !source.pull_request_comment_enabled and
        !source.ci_upload_execution_enabled;
}

fn sourceCiEnforcementDisabled(source: ApplicationBoundaryArtifact) bool {
    return !source.ci_gate_enabled and
        !source.ci_gate_enforcement_enabled and
        !source.ci_required_status_check_enabled and
        !source.ci_workflow_mutation_enabled;
}

fn sourceGithubAuthorityDisabled(source: ApplicationBoundaryArtifact) bool {
    return !source.github_api_mutation_enabled and
        !source.github_check_run_creation_enabled and
        !source.branch_protection_mutation_by_tool_enabled;
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

fn sourceApplicationEvidencePresent(source: ApplicationBoundaryArtifact) bool {
    if (std.mem.eql(u8, source.report_application_boundary_status, "planned")) {
        return !source.applied and
            source.after_report_digest.len == 0 and
            !source.after_report_present and
            source.application_changes.len == 0 and
            source.before_evidence.len == 0 and
            source.after_evidence.len == 0;
    }
    if (std.mem.eql(u8, source.report_application_boundary_status, "applied")) {
        return source.after_report_digest.len > 0 and
            source.after_report_present and
            source.application_changes.len > 0 and
            source.before_evidence.len > 0 and
            source.after_evidence.len > 0;
    }
    return false;
}

fn sourceChecksPassed(checks: []const SourceCheck) bool {
    if (checks.len == 0) return false;
    for (checks) |check| {
        if (std.mem.eql(u8, check.status, "fail")) return false;
    }
    return true;
}

fn sourceCatalogsPresent(source: ApplicationBoundaryArtifact) bool {
    return source.application_boundary_rules.len > 0 and
        source.denied_application_claims.len > 0 and
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

fn interpretationCatalogsComplete() bool {
    return hasInterpretationRule("planned-report-application") and
        hasInterpretationRule("applied-report-publication") and
        hasInterpretationRule("agent-readonly-context") and
        hasInterpretationRule("backlog-refresh-input") and
        containsString(denied_inference_rules, "report-policy-is-not-github-api-mutation-by-tool") and
        containsString(denied_inference_rules, "published-report-policy-is-not-production-health-proof") and
        hasNegativeFixture("mutation-authority-claim-denied");
}

fn hasInterpretationRule(id: []const u8) bool {
    for (interpretation_rules) |rule| {
        if (std.mem.eql(u8, rule.id, id)) return true;
    }
    return false;
}

fn hasNegativeFixture(id: []const u8) bool {
    for (negative_fixtures) |fixture| {
        if (std.mem.eql(u8, fixture.id, id)) return true;
    }
    return false;
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
    try appendJsonField(allocator, &output, "schema", production_telemetry_ci_gate_required_status_check_enforcement_report_policy_schema, true);
    try output.appendSlice(allocator, "  \"schema_version\": 1,\n");
    try appendJsonField(allocator, &output, "generated_by", generated_by, true);
    try appendJsonField(allocator, &output, "source_report_application_boundary", options.application_boundary_path, true);
    try appendJsonField(allocator, &output, "source_report_application_boundary_status", source.report_application_boundary_status, true);
    try appendJsonField(allocator, &output, "source_mode", source.mode, true);
    try output.print(allocator, "  \"source_applied\": {},\n", .{source.applied});
    try appendJsonField(allocator, &output, "source_mutation_authority", source.mutation_authority, true);
    try appendJsonField(allocator, &output, "source_after_report_digest", source.after_report_digest, true);
    try appendJsonField(allocator, &output, "decision", decisionText(options.decision), true);
    try appendJsonField(allocator, &output, "required_status_check_enforcement_report_policy_status", policyStatusText(result.status), true);
    try output.print(allocator, "  \"ready_for_next_branch\": {},\n", .{result.ready_for_next_branch});
    try output.print(allocator, "  \"published_report_policy_ready\": {},\n", .{result.published_report_policy_ready});
    try appendJsonField(allocator, &output, "reviewed_by", options.reviewed_by, true);
    try appendJsonField(allocator, &output, "policy", options.policy, true);
    try appendJsonField(allocator, &output, "reason", options.reason, true);
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
    try output.appendSlice(allocator, "  \"checks\": ");
    try appendChecksJson(allocator, &output, result.checks);
    try output.appendSlice(allocator, ",\n  \"report_interpretation_policy\": ");
    try appendInterpretationRulesJson(allocator, &output);
    try output.appendSlice(allocator, ",\n  \"evidence_requirements\": ");
    try appendPublicationSurfacesJson(allocator, &output);
    try output.appendSlice(allocator, ",\n  \"denied_inference_rules\": ");
    try appendStringArray(allocator, &output, denied_inference_rules);
    try output.appendSlice(allocator, ",\n  \"negative_fixtures\": ");
    try appendNegativeFixturesJson(allocator, &output);
    try output.appendSlice(allocator, ",\n  \"blocked_claims\": ");
    try appendStringArray(allocator, &output, blockedClaims(source));
    try output.appendSlice(allocator, ",\n  \"required_verification_commands\": ");
    try appendStringArray(allocator, &output, required_verification_commands);
    try output.appendSlice(allocator, ",\n  \"verified_commands\": ");
    try appendStringArray(allocator, &output, options.verified_commands);
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

    try output.appendSlice(allocator, "zigeffect production telemetry CI gate required status check enforcement report policy\n");
    try output.print(allocator, "schema: {s}\n", .{production_telemetry_ci_gate_required_status_check_enforcement_report_policy_schema});
    try output.print(allocator, "source report application boundary: {s}\n", .{options.application_boundary_path});
    try output.print(allocator, "source report application boundary status: {s}\n", .{source.report_application_boundary_status});
    try output.print(allocator, "source mode: {s}\n", .{source.mode});
    try output.print(allocator, "source applied: {}\n", .{source.applied});
    try output.print(allocator, "source mutation authority: {s}\n", .{source.mutation_authority});
    try output.print(allocator, "source after report digest: {s}\n", .{source.after_report_digest});
    try output.print(allocator, "decision: {s}\n", .{decisionText(options.decision)});
    try output.print(allocator, "required_status_check_enforcement_report_policy_status: {s}\n", .{policyStatusText(result.status)});
    try output.print(allocator, "ready_for_next_branch: {}\n", .{result.ready_for_next_branch});
    try output.print(allocator, "published_report_policy_ready: {}\n", .{result.published_report_policy_ready});
    try output.print(allocator, "ci gate enabled: {}\n", .{ci_gate_enabled});
    try output.print(allocator, "ci gate enforcement enabled: {}\n", .{ci_gate_enforcement_enabled});
    try output.print(allocator, "ci required status check enabled: {}\n", .{ci_required_status_check_enabled});
    try output.print(allocator, "ci report publication enabled: {}\n", .{ci_report_publication_enabled});
    try output.print(allocator, "github api mutation enabled: {}\n", .{github_api_mutation_enabled});
    try output.print(allocator, "github check run creation enabled: {}\n", .{github_check_run_creation_enabled});
    try output.print(allocator, "branch protection mutation by tool enabled: {}\n", .{branch_protection_mutation_by_tool_enabled});
    try output.print(allocator, "github step summary write enabled: {}\n", .{github_step_summary_write_enabled});
    try output.print(allocator, "pull request comment enabled: {}\n", .{pull_request_comment_enabled});
    try output.print(allocator, "mutation_authority: {s}\n", .{mutation_authority});
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

    try appendInterpretationRulesText(allocator, &output);
    try appendPublicationSurfacesText(allocator, &output);
    try appendTextList(allocator, &output, "denied inference rules", denied_inference_rules);
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

fn appendInterpretationRulesJson(allocator: std.mem.Allocator, output: *std.ArrayList(u8)) !void {
    try output.append(allocator, '[');
    for (interpretation_rules, 0..) |rule, index| {
        if (index > 0) try output.appendSlice(allocator, ", ");
        try output.appendSlice(allocator, "{ \"id\": ");
        try appendJsonString(allocator, output, rule.id);
        try output.appendSlice(allocator, ", \"consumer_role\": ");
        try appendJsonString(allocator, output, rule.consumer_role);
        try output.appendSlice(allocator, ", \"allowed_use\": ");
        try appendJsonString(allocator, output, rule.allowed_use);
        try output.appendSlice(allocator, ", \"failure_effect\": ");
        try appendJsonString(allocator, output, rule.failure_effect);
        try output.appendSlice(allocator, ", \"denied_claim\": ");
        try appendJsonString(allocator, output, rule.denied_claim);
        try output.appendSlice(allocator, " }");
    }
    try output.append(allocator, ']');
}

fn appendPublicationSurfacesJson(allocator: std.mem.Allocator, output: *std.ArrayList(u8)) !void {
    try output.append(allocator, '[');
    for (publication_surfaces, 0..) |surface, index| {
        if (index > 0) try output.appendSlice(allocator, ", ");
        try output.appendSlice(allocator, "{ \"id\": ");
        try appendJsonString(allocator, output, surface.id);
        try output.appendSlice(allocator, ", \"visibility_class\": ");
        try appendJsonString(allocator, output, surface.visibility_class);
        try output.print(allocator, ", \"executed_by_tool\": {}, \"interpretation_scope\": ", .{surface.executed_by_tool});
        try appendJsonString(allocator, output, surface.interpretation_scope);
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

fn appendInterpretationRulesText(allocator: std.mem.Allocator, output: *std.ArrayList(u8)) !void {
    try output.appendSlice(allocator, "interpretation rules:\n");
    for (interpretation_rules) |rule| {
        try output.print(allocator, "- {s}: role={s}, failure_effect={s}, denied={s}\n", .{ rule.id, rule.consumer_role, rule.failure_effect, rule.denied_claim });
    }
    try output.append(allocator, '\n');
}

fn appendPublicationSurfacesText(allocator: std.mem.Allocator, output: *std.ArrayList(u8)) !void {
    try output.appendSlice(allocator, "publication surfaces:\n");
    for (publication_surfaces) |surface| {
        try output.print(allocator, "- {s}: visibility={s}, executed_by_tool={}\n", .{ surface.id, surface.visibility_class, surface.executed_by_tool });
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

fn blockedClaims(source: ApplicationBoundaryArtifact) []const []const u8 {
    if (source.blocked_claims.len > 0) return source.blocked_claims;
    return denied_inference_rules;
}

fn agentGuidance(status: PolicyStatus) []const []const u8 {
    return switch (status) {
        .ready => &.{
            "Use ready required status check enforcement report policy as interpretation evidence only.",
            "Published report readiness means externally reviewed report application evidence exists; it is not tool publication proof.",
            "Refresh the production hardening backlog before selecting the next unresolved roadmap branch.",
        },
        .blocked => &.{
            "Treat blocked required status check enforcement report policy evidence as a stop sign.",
            "Repair source application-boundary evidence reviewer decision verification proof or interpretation catalogs before continuing.",
            "Do not infer required checks CI gate enforcement report publication by the tool production health cluster readiness or mutation authority from blocked policy evidence.",
        },
    };
}

fn directoryPrefix(path: []const u8) []const u8 {
    const slash = std.mem.lastIndexOfScalar(u8, path, '/') orelse return "";
    return path[0 .. slash + 1];
}

fn fileName(path: []const u8) []const u8 {
    const slash = std.mem.lastIndexOfScalar(u8, path, '/') orelse return path;
    return path[slash + 1 ..];
}

fn shortPathDigest(path: []const u8) [16]u8 {
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(path, &digest, .{});

    var hex_digest: [16]u8 = undefined;
    const hex = "0123456789abcdef";
    for (digest[0..8], 0..) |byte, index| {
        hex_digest[index * 2] = hex[@intCast(byte >> 4)];
        hex_digest[index * 2 + 1] = hex[@intCast(byte & 0x0f)];
    }
    return hex_digest;
}

fn readRequiredArtifact(io: std.Io, allocator: std.mem.Allocator, path: []const u8, err: anyerror) ![]const u8 {
    return std.Io.Dir.cwd().readFileAlloc(io, path, allocator, .limited(max_source_bytes)) catch |read_err| switch (read_err) {
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
    return "usage: zig build causal-production-telemetry-ci-gate-required-status-check-enforcement-report-policy -- --from-application-boundary <required-status-check-enforcement-report-application-boundary.json> approve|reject --reason <reason> [--by <actor>] [--policy <policy>] [--verified-command <command>]... [--out-prefix <path-prefix>]\n";
}

fn failUsage(err: anyerror) noreturn {
    std.debug.print("causal-production-telemetry-ci-gate-required-status-check-enforcement-report-policy error: {s}\n{s}", .{ @errorName(err), usage() });
    std.process.exit(2);
}

fn freeSliceOnly(allocator: std.mem.Allocator, values: []const []const u8) void {
    if (values.len > 0) allocator.free(values);
}

fn contains(haystack: []const u8, needle: []const u8) bool {
    return std.mem.indexOf(u8, haystack, needle) != null;
}

fn containsString(values: []const []const u8, needle: []const u8) bool {
    for (values) |value| {
        if (std.mem.eql(u8, value, needle)) return true;
    }
    return false;
}

test "ci gate required status check enforcement report policy schema and branch constants are stable" {
    try std.testing.expectEqualStrings("zigeffect.causal.production-telemetry-ci-gate-required-status-check-enforcement-report-policy.v1", production_telemetry_ci_gate_required_status_check_enforcement_report_policy_schema);
    try std.testing.expectEqual(@as(u32, 1), production_telemetry_ci_gate_required_status_check_enforcement_report_policy_schema_version);
    try std.testing.expectEqualStrings("codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-enforcement-report-policy", source_branch);
    try std.testing.expectEqualStrings("refresh-production-hardening-backlog", recommendation);
    try std.testing.expectEqualStrings("codex/zigeffect-causal-production-hardening-backlog-refresh", next_branch_if_ready);
    try std.testing.expect(containsString(required_verification_commands, "zig build causal-production-telemetry-ci-gate-required-status-check-enforcement-report-application-boundary"));
    try std.testing.expect(containsString(required_verification_commands, "zig build release-gate-report"));
}

test "parses ci gate required status check enforcement report policy approval and rejection options" {
    var approve_options = try parseOptions(std.testing.allocator, &.{
        "zigeffect-causal-production-telemetry-ci-gate-required-status-check-enforcement-report-policy",
        "--from-application-boundary",
        ".zig-cache/causal-artifacts/required-status-check-enforcement-report-application-boundary.json",
        "approve",
        "--reason",
        "required status check enforcement report policy reviewed",
        "--by",
        "codex",
        "--policy",
        "manual-production-telemetry-ci-gate-required-status-check-enforcement-report-policy",
        "--verified-command",
        "zig build causal-production-telemetry-ci-gate-required-status-check-enforcement-report-application-boundary",
        "--out-prefix",
        ".zig-cache/causal-artifacts/custom-report-policy",
    });
    defer approve_options.deinit(std.testing.allocator);

    try std.testing.expectEqual(Decision.approve, approve_options.decision);
    try std.testing.expectEqualStrings(".zig-cache/causal-artifacts/required-status-check-enforcement-report-application-boundary.json", approve_options.application_boundary_path);
    try std.testing.expectEqualStrings("codex", approve_options.reviewed_by);
    try std.testing.expectEqualStrings("manual-production-telemetry-ci-gate-required-status-check-enforcement-report-policy", approve_options.policy);
    try std.testing.expectEqual(@as(usize, 1), approve_options.verified_commands.len);
    try std.testing.expectEqualStrings(".zig-cache/causal-artifacts/custom-report-policy", approve_options.out_prefix.?);

    var reject_options = try parseOptions(std.testing.allocator, &.{
        "zigeffect-causal-production-telemetry-ci-gate-required-status-check-enforcement-report-policy",
        "--from-application-boundary",
        ".zig-cache/causal-artifacts/required-status-check-enforcement-report-application-boundary.json",
        "reject",
        "--reason",
        "negative required status check enforcement report policy path",
    });
    defer reject_options.deinit(std.testing.allocator);

    try std.testing.expectEqual(Decision.reject, reject_options.decision);
    try std.testing.expectError(error.UnknownDecision, parseOptions(std.testing.allocator, &.{ "tool", "--from-application-boundary", ".zig-cache/report.json", "maybe", "--reason", "bad" }));
    try std.testing.expectError(error.MissingReason, parseOptions(std.testing.allocator, &.{ "tool", "--from-application-boundary", ".zig-cache/report.json", "approve" }));
}

test "default output path replaces application boundary suffix and compacts long names" {
    const options = Options{
        .application_boundary_path = "../../.zig-cache/causal-artifacts/example-ci-gate-required-status-check-enforcement-report-application-boundary.json",
        .decision = .approve,
        .reason = "planned",
    };
    const paths = try outputPathsForOptions(std.testing.allocator, options);
    defer paths.deinit(std.testing.allocator);

    try std.testing.expectEqualStrings("../../.zig-cache/causal-artifacts/example-ci-gate-required-status-check-enforcement-report-policy.json", paths.json_path);
    try std.testing.expectEqualStrings("../../.zig-cache/causal-artifacts/example-ci-gate-required-status-check-enforcement-report-policy.txt", paths.text_path);

    const long_options = Options{
        .application_boundary_path = "../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures-nendb-retention-fixtures-workbench-readonly-preview-ci-artifact-preview-ci-harness-boundary-ci-gate-required-status-check-enforcement-report-application-boundary.json",
        .decision = .approve,
        .reason = "planned",
    };
    const long_paths = try outputPathsForOptions(std.testing.allocator, long_options);
    defer long_paths.deinit(std.testing.allocator);

    const file_name = fileName(long_paths.json_path);
    try std.testing.expect(file_name.len <= 240);
    try std.testing.expect(contains(long_paths.json_path, "production-telemetry-ci-gate-required-status-check-enforcement-report-policy-"));
}

test "approved report policy is ready and preserves disabled authority" {
    const reports = try formatReports(std.testing.allocator, .{
        .options = .{
            .application_boundary_path = ".zig-cache/causal-artifacts/required-status-check-enforcement-report-application-boundary.json",
            .decision = .approve,
            .reason = "required status check enforcement report policy reviewed",
            .verified_commands = required_verification_commands,
        },
        .source_application_boundary_json = sample_applied_application_boundary_json,
    });
    defer reports.deinit(std.testing.allocator);

    try std.testing.expect(contains(reports.json, "\"schema\": \"zigeffect.causal.production-telemetry-ci-gate-required-status-check-enforcement-report-policy.v1\""));
    try std.testing.expect(contains(reports.json, "\"required_status_check_enforcement_report_policy_status\": \"ready\""));
    try std.testing.expect(contains(reports.json, "\"ready_for_next_branch\": true"));
    try std.testing.expect(contains(reports.json, "\"mutation_authority\": \"none\""));
    try std.testing.expect(contains(reports.json, "\"ci_required_status_check_enabled\": false"));
    try std.testing.expect(contains(reports.json, "\"github_step_summary_write_enabled\": false"));
    try std.testing.expect(contains(reports.json, "\"id\": \"agent-readonly-context\""));
    try std.testing.expect(contains(reports.json, "\"published_report_policy_ready\": true"));
    try std.testing.expect(contains(reports.json, "\"id\": \"backlog-refresh-input\""));
    try std.testing.expect(contains(reports.json, "report-policy-is-not-required-status-check-creation-by-tool"));
    try std.testing.expect(contains(reports.json, "\"id\": \"mutation-authority-claim-denied\""));
    try std.testing.expect(contains(reports.json, "\"next_branch_if_ready\": \"codex/zigeffect-causal-production-hardening-backlog-refresh\""));
    try std.testing.expect(contains(reports.text, "required_status_check_enforcement_report_policy_status: ready"));
    try std.testing.expect(contains(reports.text, "published_report_policy_ready: true"));
    try std.testing.expect(contains(reports.text, "next branch if ready: codex/zigeffect-causal-production-hardening-backlog-refresh"));
}

test "rejection incomplete verification planned and invalid source behavior" {
    const rejected = try formatReports(std.testing.allocator, .{
        .options = .{
            .application_boundary_path = ".zig-cache/causal-artifacts/required-status-check-enforcement-report-application-boundary.json",
            .decision = .reject,
            .reason = "negative required status check enforcement report policy path",
            .verified_commands = required_verification_commands,
        },
        .source_application_boundary_json = sample_applied_application_boundary_json,
    });
    defer rejected.deinit(std.testing.allocator);
    try std.testing.expect(contains(rejected.json, "\"required_status_check_enforcement_report_policy_status\": \"blocked\""));
    try std.testing.expect(contains(rejected.json, "\"name\": \"decision-approved\""));

    const incomplete = try formatReports(std.testing.allocator, .{
        .options = .{
            .application_boundary_path = ".zig-cache/causal-artifacts/required-status-check-enforcement-report-application-boundary.json",
            .decision = .approve,
            .reason = "missing verification commands",
        },
        .source_application_boundary_json = sample_applied_application_boundary_json,
    });
    defer incomplete.deinit(std.testing.allocator);
    try std.testing.expect(contains(incomplete.json, "\"required_status_check_enforcement_report_policy_status\": \"blocked\""));
    try std.testing.expect(contains(incomplete.json, "\"name\": \"policy-verification-recorded\""));

    const planned_source = try formatReports(std.testing.allocator, .{
        .options = .{
            .application_boundary_path = ".zig-cache/causal-artifacts/required-status-check-enforcement-report-application-boundary.json",
            .decision = .approve,
            .reason = "planned source",
            .verified_commands = required_verification_commands,
        },
        .source_application_boundary_json = sample_planned_application_boundary_json,
    });
    defer planned_source.deinit(std.testing.allocator);
    try std.testing.expect(contains(planned_source.json, "\"required_status_check_enforcement_report_policy_status\": \"ready\""));
    try std.testing.expect(contains(planned_source.json, "\"ready_for_next_branch\": true"));
    try std.testing.expect(contains(planned_source.json, "\"published_report_policy_ready\": false"));

    const unsafe_source = try formatReports(std.testing.allocator, .{
        .options = .{
            .application_boundary_path = ".zig-cache/causal-artifacts/required-status-check-enforcement-report-application-boundary.json",
            .decision = .approve,
            .reason = "unsafe source",
            .verified_commands = required_verification_commands,
        },
        .source_application_boundary_json = sample_application_boundary_json_with_required_check,
    });
    defer unsafe_source.deinit(std.testing.allocator);
    try std.testing.expect(contains(unsafe_source.json, "\"required_status_check_enforcement_report_policy_status\": \"blocked\""));
    try std.testing.expect(contains(unsafe_source.json, "\"name\": \"source-ci-enforcement-disabled\""));
}

test "blocked source and failed checks block report policy" {
    const blocked_source = try formatReports(std.testing.allocator, .{
        .options = .{
            .application_boundary_path = ".zig-cache/causal-artifacts/required-status-check-enforcement-report-application-boundary.json",
            .decision = .approve,
            .reason = "blocked source",
            .verified_commands = required_verification_commands,
        },
        .source_application_boundary_json = sample_blocked_application_boundary_json,
    });
    defer blocked_source.deinit(std.testing.allocator);

    try std.testing.expect(contains(blocked_source.json, "\"required_status_check_enforcement_report_policy_status\": \"blocked\""));
    try std.testing.expect(contains(blocked_source.json, "\"ready_for_next_branch\": false"));
    try std.testing.expect(contains(blocked_source.json, "\"published_report_policy_ready\": false"));
    try std.testing.expect(contains(blocked_source.json, "\"name\": \"source-boundary-status-valid\""));
    try std.testing.expect(contains(blocked_source.json, "\"name\": \"source-checks-passed\""));
}

const sample_applied_application_boundary_json =
    \\{
    \\  "schema": "zigeffect.causal.production-telemetry-ci-gate-required-status-check-enforcement-report-application-boundary.v1",
    \\  "schema_version": 1,
    \\  "source_enforcement_report": ".zig-cache/causal-artifacts/advisory-ci-report.json",
    \\  "source_report_status": "advisory",
    \\  "mode": "record-applied",
    \\  "report_application_boundary_status": "applied",
    \\  "applied": true,
    \\  "mutation_authority": "record-only",
    \\  "ci_gate_enabled": false,
    \\  "ci_gate_enforcement_enabled": false,
    \\  "ci_required_status_check_enabled": false,
    \\  "ci_workflow_mutation_enabled": false,
    \\  "ci_upload_execution_enabled": false,
    \\  "ci_report_publication_enabled": false,
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
    \\  "after_report_digest": "sha256:after-report-digest",
    \\  "after_report_present": true,
    \\  "application_changes": ["reviewed local required status check enforcement report publication procedure"],
    \\  "before_evidence": ["required status check enforcement report local artifact existed before application"],
    \\  "after_evidence": ["required status check enforcement report application boundary reviewed after publication"],
    \\  "source_checks": [{ "name": "source-evaluator-schema", "status": "pass", "detail": "supported" }],
    \\  "application_checks": [{ "name": "source-report-schema", "status": "pass", "detail": "supported" }, { "name": "post-verification-recorded", "status": "pass", "detail": "verified" }],
    \\  "application_boundary_rules": ["Applied records are evidence records only."],
    \\  "denied_application_claims": ["required-status-check-active", "github-step-summary-written-by-tool"],
    \\  "negative_fixtures": [{ "id": "missing-report-after-denied", "artifact_state": "record-applied report_after=null", "decision": "deny", "failed_gate": "after-report-present", "reason": "after report required" }],
    \\  "blocked_claims": ["ci-gate-enforcement-active", "production-health-proven"],
    \\  "required_verification_commands": ["zig build causal-production-telemetry-ci-gate-required-status-check-enforcement-report-application-boundary", "zig build causal-artifacts"],
    \\  "verified_commands": ["zig build causal-production-telemetry-ci-gate-required-status-check-enforcement-report-application-boundary", "zig build causal-artifacts"],
    \\  "generated_by": "causal-production-telemetry-ci-gate-required-status-check-enforcement-report-application-boundary"
    \\}
;

const sample_planned_application_boundary_json =
    \\{
    \\  "schema": "zigeffect.causal.production-telemetry-ci-gate-required-status-check-enforcement-report-application-boundary.v1",
    \\  "schema_version": 1,
    \\  "source_enforcement_report": ".zig-cache/causal-artifacts/advisory-ci-report.json",
    \\  "source_report_status": "advisory",
    \\  "mode": "plan",
    \\  "report_application_boundary_status": "planned",
    \\  "applied": false,
    \\  "mutation_authority": "none",
    \\  "ci_gate_enabled": false,
    \\  "ci_gate_enforcement_enabled": false,
    \\  "ci_required_status_check_enabled": false,
    \\  "ci_workflow_mutation_enabled": false,
    \\  "ci_upload_execution_enabled": false,
    \\  "ci_report_publication_enabled": false,
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
    \\  "after_report_digest": "",
    \\  "after_report_present": false,
    \\  "application_changes": [],
    \\  "before_evidence": [],
    \\  "after_evidence": [],
    \\  "source_checks": [{ "name": "source-evaluator-schema", "status": "pass", "detail": "supported" }],
    \\  "application_checks": [{ "name": "source-report-schema", "status": "pass", "detail": "supported" }],
    \\  "application_boundary_rules": ["Plan mode records intent only."],
    \\  "denied_application_claims": ["required-status-check-active"],
    \\  "negative_fixtures": [{ "id": "plan-applied-claim-denied", "artifact_state": "mode=plan applied=true", "decision": "deny", "failed_gate": "plan-is-not-applied", "reason": "plan is not applied" }],
    \\  "blocked_claims": ["ci-gate-enforcement-active"],
    \\  "required_verification_commands": ["zig build causal-production-telemetry-ci-gate-required-status-check-enforcement-report-application-boundary"],
    \\  "verified_commands": ["zig build causal-production-telemetry-ci-gate-required-status-check-enforcement-report-application-boundary"],
    \\  "generated_by": "causal-production-telemetry-ci-gate-required-status-check-enforcement-report-application-boundary"
    \\}
;

const sample_application_boundary_json_with_required_check =
    \\{
    \\  "schema": "zigeffect.causal.production-telemetry-ci-gate-required-status-check-enforcement-report-application-boundary.v1",
    \\  "schema_version": 1,
    \\  "source_enforcement_report": ".zig-cache/causal-artifacts/advisory-ci-report.json",
    \\  "source_report_status": "advisory",
    \\  "mode": "record-applied",
    \\  "report_application_boundary_status": "applied",
    \\  "applied": true,
    \\  "mutation_authority": "record-only",
    \\  "ci_gate_enabled": false,
    \\  "ci_gate_enforcement_enabled": false,
    \\  "ci_required_status_check_enabled": true,
    \\  "ci_workflow_mutation_enabled": false,
    \\  "ci_upload_execution_enabled": false,
    \\  "ci_report_publication_enabled": false,
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
    \\  "after_report_digest": "sha256:after-report-digest",
    \\  "after_report_present": true,
    \\  "application_changes": ["reviewed local required status check enforcement report publication procedure"],
    \\  "before_evidence": ["before"],
    \\  "after_evidence": ["after"],
    \\  "source_checks": [{ "name": "source-evaluator-schema", "status": "pass", "detail": "supported" }],
    \\  "application_checks": [{ "name": "source-report-schema", "status": "pass", "detail": "supported" }],
    \\  "application_boundary_rules": ["Applied records are evidence records only."],
    \\  "denied_application_claims": ["required-status-check-active"],
    \\  "negative_fixtures": [{ "id": "required-status-check-claim-denied", "artifact_state": "ci_required_status_check_enabled=true", "decision": "deny", "failed_gate": "source-ci-enforcement-disabled", "reason": "required checks denied" }],
    \\  "blocked_claims": ["ci-gate-enforcement-active"],
    \\  "required_verification_commands": ["zig build causal-production-telemetry-ci-gate-required-status-check-enforcement-report-application-boundary"],
    \\  "verified_commands": [],
    \\  "generated_by": "causal-production-telemetry-ci-gate-required-status-check-enforcement-report-application-boundary"
    \\}
;

const sample_blocked_application_boundary_json =
    \\{
    \\  "schema": "zigeffect.causal.production-telemetry-ci-gate-required-status-check-enforcement-report-application-boundary.v1",
    \\  "schema_version": 1,
    \\  "source_enforcement_report": ".zig-cache/causal-artifacts/required-status-check-enforcement-report.json",
    \\  "source_report_status": "blocked",
    \\  "mode": "plan",
    \\  "report_application_boundary_status": "blocked",
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
    \\  "after_report_digest": "",
    \\  "after_report_present": false,
    \\  "application_changes": [],
    \\  "before_evidence": [],
    \\  "after_evidence": [],
    \\  "source_checks": [{ "name": "source-report-status", "status": "fail", "detail": "blocked" }],
    \\  "application_checks": [{ "name": "source-report-status", "status": "fail", "detail": "blocked" }],
    \\  "application_boundary_rules": ["Blocked evidence is a stop sign."],
    \\  "denied_application_claims": ["required-status-check-active"],
    \\  "negative_fixtures": [{ "id": "blocked-source-report-denied", "artifact_state": "blocked", "decision": "deny", "failed_gate": "source-report-status", "reason": "blocked source denied" }],
    \\  "blocked_claims": ["ci-gate-enforcement-active"],
    \\  "required_verification_commands": ["zig build causal-production-telemetry-ci-gate-required-status-check-enforcement-report-application-boundary"],
    \\  "verified_commands": ["zig build causal-production-telemetry-ci-gate-required-status-check-enforcement-report-application-boundary"],
    \\  "generated_by": "causal-production-telemetry-ci-gate-required-status-check-enforcement-report-application-boundary"
    \\}
;
