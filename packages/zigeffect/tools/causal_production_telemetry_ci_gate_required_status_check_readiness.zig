const std = @import("std");

pub const production_telemetry_ci_gate_required_status_check_readiness_schema = "zigeffect.causal.production-telemetry-ci-gate-required-status-check-readiness.v1";
pub const production_telemetry_ci_gate_required_status_check_readiness_schema_version: u32 = 1;
pub const source_branch = "codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-readiness";
pub const recommendation = "start-production-telemetry-ci-gate-required-status-check-application-boundary";
pub const next_branch_if_ready = "codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-application-boundary";

const source_publication_policy_schema = "zigeffect.causal.production-telemetry-ci-gate-advisory-ci-report-publication-policy.v1";
const generated_by = "causal-production-telemetry-ci-gate-required-status-check-readiness";
const source_publication_policy_suffix = "-ci-gate-advisory-ci-report-publication-policy.json";
const output_prefix_suffix = "-ci-gate-required-status-check-readiness";
const compact_output_prefix_name = "production-telemetry-ci-gate-required-status-check-readiness";
const max_default_output_file_name_len = 240;
const max_source_bytes = 1024 * 1024;

const required_verification_commands: []const []const u8 = &.{
    "zig build causal-production-telemetry-ci-gate-advisory-ci-report-publication-policy",
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
const RequiredStatusCheckReadinessStatus = enum { ready, blocked };
const CheckStatus = enum { pass, fail };

const Options = struct {
    publication_policy_path: []const u8,
    decision: Decision,
    reviewed_by: []const u8 = "required-status-check-readiness-reviewer",
    policy: []const u8 = "manual-production-telemetry-ci-gate-required-status-check-readiness",
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

const ReadinessInput = struct {
    options: Options,
    source_publication_policy_json: []const u8,
};

const ReadinessReports = struct {
    json: []const u8,
    text: []const u8,

    fn deinit(self: ReadinessReports, allocator: std.mem.Allocator) void {
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

const SourceInterpretationRule = struct {
    id: []const u8,
    consumer_role: []const u8 = "",
    allowed_use: []const u8 = "",
    failure_effect: []const u8 = "",
    denied_claim: []const u8 = "",
};

const SourcePublicationSurface = struct {
    id: []const u8,
    visibility_class: []const u8 = "",
    executed_by_tool: bool = false,
    interpretation_scope: []const u8 = "",
};

const SourceNegativeFixture = struct {
    id: []const u8 = "",
    artifact_state: []const u8 = "",
    decision: []const u8 = "",
    failed_gate: []const u8 = "",
    reason: []const u8 = "",
};

const PublicationPolicyArtifact = struct {
    schema: []const u8,
    schema_version: u32,
    source_application_boundary: []const u8 = "",
    source_report_application_status: []const u8 = "",
    source_mode: []const u8 = "",
    source_applied: bool = false,
    source_mutation_authority: []const u8 = "",
    source_after_report_digest: []const u8 = "",
    decision: []const u8,
    advisory_ci_report_publication_policy_status: []const u8,
    ready_for_next_branch: bool,
    reviewed_by: []const u8 = "",
    policy: []const u8 = "",
    reason: []const u8 = "",
    ci_gate_enabled: bool = false,
    ci_gate_enforcement_enabled: bool = false,
    ci_required_status_check_enabled: bool = false,
    ci_workflow_mutation_enabled: bool = false,
    ci_upload_execution_enabled: bool = false,
    ci_report_publication_enabled: bool = false,
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
    mutation_authority: []const u8,
    policy_checks: []const SourceCheck = &.{},
    interpretation_rules: []const SourceInterpretationRule = &.{},
    publication_surfaces: []const SourcePublicationSurface = &.{},
    denied_inference_rules: []const []const u8 = &.{},
    negative_fixtures: []const SourceNegativeFixture = &.{},
    blocked_claims: []const []const u8 = &.{},
    required_verification_commands: []const []const u8 = &.{},
    verified_commands: []const []const u8 = &.{},
    source_branch: []const u8 = "",
    recommendation: []const u8 = "",
    next_branch_if_ready: []const u8 = "",
};

const ReadinessCheck = struct {
    name: []const u8,
    status: CheckStatus,
    detail: []const u8,
};

const ReadinessResult = struct {
    status: RequiredStatusCheckReadinessStatus,
    ready_for_next_branch: bool,
    checks: []const ReadinessCheck,

    fn deinit(self: ReadinessResult, allocator: std.mem.Allocator) void {
        if (self.checks.len > 0) allocator.free(self.checks);
    }
};

const RequiredStatusCheckProfile = struct {
    id: []const u8,
    activation_enabled: bool,
    source: []const u8,
    intended_future_signal: []const u8,
    denied_claim: []const u8,
};

const ReadinessDimension = struct {
    id: []const u8,
    required: bool,
    evidence: []const u8,
};

const ActivationGuardrail = struct {
    id: []const u8,
    required_before_application: bool,
    reason: []const u8,
};

const NegativeFixture = struct {
    id: []const u8,
    artifact_state: []const u8,
    decision: []const u8,
    failed_gate: []const u8,
    reason: []const u8,
};

const required_status_check_profiles: []const RequiredStatusCheckProfile = &.{
    .{ .id = "zigeffect-causal-telemetry-advisory-report", .activation_enabled = false, .source = "ready advisory CI report publication policy", .intended_future_signal = "advisory report artifact exists parses and preserves non-blocking interpretation policy", .denied_claim = "merge blocking is active" },
    .{ .id = "zigeffect-causal-release-gate-report", .activation_enabled = false, .source = "zig build release-gate --summary none and zig build release-gate-report", .intended_future_signal = "release-gate report exists and parses", .denied_claim = "production deployment success" },
    .{ .id = "zigeffect-causal-required-check-contract", .activation_enabled = false, .source = "required-status-check readiness artifact and future application-boundary", .intended_future_signal = "required-check name failure semantics bypass policy retry policy and rollback plan are reviewed", .denied_claim = "branch protection is updated" },
};

const readiness_dimensions: []const ReadinessDimension = &.{
    .{ .id = "source-publication-policy-ready", .required = true, .evidence = "ready advisory CI report publication policy artifact" },
    .{ .id = "required-check-name-stability", .required = true, .evidence = "candidate required-check names are stable and reviewed" },
    .{ .id = "failure-semantics-reviewed", .required = true, .evidence = "future pass fail semantics deny production health and cluster readiness claims" },
    .{ .id = "branch-protection-evidence-required", .required = true, .evidence = "future application boundary must carry branch protection before after evidence" },
    .{ .id = "workflow-evidence-required", .required = true, .evidence = "future application boundary must carry workflow before after evidence when workflow changes are proposed" },
    .{ .id = "rollback-and-bypass-policy-required", .required = true, .evidence = "manual rollback disable and maintainer bypass policies are named" },
    .{ .id = "flake-and-retry-policy-required", .required = true, .evidence = "noise retry and flake handling are named before enforcement" },
    .{ .id = "redaction-retention-reviewed", .required = true, .evidence = "surfaced artifacts remain redacted and bounded by retention policy" },
    .{ .id = "human-review-before-application", .required = true, .evidence = "future application boundary requires reviewed approval" },
};

const activation_guardrails: []const ActivationGuardrail = &.{
    .{ .id = "stable-check-names", .required_before_application = true, .reason = "required checks need stable names before branch protection references them" },
    .{ .id = "owning-workflow-paths", .required_before_application = true, .reason = "future application evidence must identify the workflow owning each check" },
    .{ .id = "pass-fail-semantics", .required_before_application = true, .reason = "required checks must describe failure effects without production-health claims" },
    .{ .id = "advisory-to-required-review", .required_before_application = true, .reason = "moving from advisory to required semantics needs explicit human review" },
    .{ .id = "branch-protection-before-after", .required_before_application = true, .reason = "branch protection changes need before after evidence" },
    .{ .id = "workflow-before-after", .required_before_application = true, .reason = "workflow changes need before after evidence" },
    .{ .id = "manual-rollback-plan", .required_before_application = true, .reason = "required checks must have a disable rollback path" },
    .{ .id = "maintainer-bypass-policy", .required_before_application = true, .reason = "maintainer bypass rules must be reviewed before enforcement" },
    .{ .id = "flake-noise-policy", .required_before_application = true, .reason = "required checks need a noise and retry policy before blocking merges" },
    .{ .id = "redaction-retention-policy", .required_before_application = true, .reason = "surfaced evidence must remain redacted and bounded" },
    .{ .id = "no-github-mutation-by-this-tool", .required_before_application = true, .reason = "this readiness tool must not call GitHub or create required checks" },
    .{ .id = "no-mutation-authority", .required_before_application = true, .reason = "mutation authority remains none until a later reviewed boundary grants it" },
};

const denied_inference_rules: []const []const u8 = &.{
    "required-status-check-active",
    "merge-blocker-active",
    "branch-protection-updated",
    "github-check-run-created",
    "github-api-mutation",
    "workflow-mutated-by-tool",
    "artifact-upload-executed-by-tool",
    "github-step-summary-written-by-tool",
    "pull-request-comment-written-by-tool",
    "production-health-proof",
    "deployment-success-proof",
    "capacity-proof",
    "customer-impact-proof",
    "production-cluster-readiness-proof",
    "live-telemetry-coverage-proof",
    "durable-write-proof",
    "nendb-write-proof",
    "mutation-authority",
    "non-nendb-durable-adapter",
    "alternate-renderer",
};

const negative_fixtures: []const NegativeFixture = &.{
    .{ .id = "blocked-source-policy-denied", .artifact_state = "required_status_check_readiness_status=blocked", .decision = "deny", .failed_gate = "source-policy-ready", .reason = "blocked publication policy cannot feed required status check readiness" },
    .{ .id = "missing-required-status-check-denied", .artifact_state = "required status check profile missing", .decision = "deny", .failed_gate = "required-status-check-semantics-defined", .reason = "readiness must define candidate profiles before application work" },
    .{ .id = "required-status-check-active-denied", .artifact_state = "ci_required_status_check_enabled=true", .decision = "deny", .failed_gate = "source-required-status-check-disabled", .reason = "this branch is readiness-only" },
    .{ .id = "merge-blocker-active-denied", .artifact_state = "merge_blocker=true", .decision = "deny", .failed_gate = "source-advisory-non-blocking", .reason = "source advisory reports remain non-blocking" },
    .{ .id = "branch-protection-active-denied", .artifact_state = "branch_protection_updated=true", .decision = "deny", .failed_gate = "no-branch-protection-mutation", .reason = "branch protection changes require a later application boundary" },
    .{ .id = "github-check-run-created-denied", .artifact_state = "github_check_run_created=true", .decision = "deny", .failed_gate = "no-github-api-mutation", .reason = "this tool does not call GitHub" },
    .{ .id = "github-api-mutation-denied", .artifact_state = "github_api_mutation=true", .decision = "deny", .failed_gate = "no-github-api-mutation", .reason = "this readiness artifact is local record-only evidence" },
    .{ .id = "workflow-mutation-denied", .artifact_state = "workflow_mutated=true", .decision = "deny", .failed_gate = "source-ci-enforcement-disabled", .reason = "workflow mutation requires a later boundary" },
    .{ .id = "missing-release-gate-report-denied", .artifact_state = "release-gate-report command missing", .decision = "deny", .failed_gate = "required-verification-recorded", .reason = "readiness must cite release-gate report evidence" },
    .{ .id = "missing-human-review-gate-denied", .artifact_state = "human review guardrail missing", .decision = "deny", .failed_gate = "required-status-check-semantics-defined", .reason = "application work must require human review" },
    .{ .id = "production-health-claim-denied", .artifact_state = "production_health=proven", .decision = "deny", .failed_gate = "source-advisory-non-blocking", .reason = "CI readiness is not production health evidence" },
    .{ .id = "cluster-readiness-claim-denied", .artifact_state = "production_cluster_ready=true", .decision = "deny", .failed_gate = "source-advisory-non-blocking", .reason = "CI readiness cannot prove cluster readiness" },
    .{ .id = "mutation-authority-claim-denied", .artifact_state = "mutation_authority=granted", .decision = "deny", .failed_gate = "source-policy-ready", .reason = "required status check readiness grants no mutation authority" },
    .{ .id = "non-nendb-durable-scope-denied", .artifact_state = "durable_adapter=non-nendb", .decision = "deny", .failed_gate = "source-runtime-and-storage-disabled", .reason = "durable direction remains NenDB adapter only" },
    .{ .id = "alternate-renderer-scope-denied", .artifact_state = "renderer=react", .decision = "deny", .failed_gate = "source-advisory-non-blocking", .reason = "workbench direction remains SolidJS inside zig-webui" },
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
        error.MissingPublicationPolicyInput => failUsage(err),
        else => return err,
    };
}

fn parseOptions(allocator: std.mem.Allocator, args: []const []const u8) !Options {
    if (args.len < 2) return error.MissingPublicationPolicyPath;
    if (!std.mem.eql(u8, args[1], "--from-publication-policy")) return error.UnknownFlag;
    if (args.len < 3) return error.MissingPublicationPolicyPath;
    const publication_policy_path = args[2];
    if (!std.mem.endsWith(u8, publication_policy_path, ".json")) return error.InvalidPublicationPolicyPath;
    if (args.len < 4) return error.MissingDecision;
    const decision = try parseDecision(args[3]);

    var reviewed_by: []const u8 = "required-status-check-readiness-reviewer";
    var policy: []const u8 = "manual-production-telemetry-ci-gate-required-status-check-readiness";
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
        .publication_policy_path = publication_policy_path,
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

fn readinessStatusText(status: RequiredStatusCheckReadinessStatus) []const u8 {
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
        try defaultOutputPrefix(allocator, options.publication_policy_path);
    defer allocator.free(prefix);

    return .{
        .json_path = try std.fmt.allocPrint(allocator, "{s}.json", .{prefix}),
        .text_path = try std.fmt.allocPrint(allocator, "{s}.txt", .{prefix}),
    };
}

fn defaultOutputPrefix(allocator: std.mem.Allocator, publication_policy_path: []const u8) ![]const u8 {
    if (!std.mem.endsWith(u8, publication_policy_path, ".json")) return error.InvalidPublicationPolicyPath;

    const base = if (std.mem.endsWith(u8, publication_policy_path, source_publication_policy_suffix))
        publication_policy_path[0 .. publication_policy_path.len - source_publication_policy_suffix.len]
    else
        publication_policy_path[0 .. publication_policy_path.len - ".json".len];
    const candidate = try std.fmt.allocPrint(allocator, "{s}{s}", .{ base, output_prefix_suffix });
    errdefer allocator.free(candidate);

    if (fileName(candidate).len + ".json".len <= max_default_output_file_name_len) {
        return candidate;
    }

    const directory = directoryPrefix(candidate);
    const digest = shortPathDigest(publication_policy_path);
    const compact_prefix = try std.fmt.allocPrint(allocator, "{s}{s}-{s}", .{ directory, compact_output_prefix_name, digest[0..] });
    allocator.free(candidate);
    return compact_prefix;
}

fn formatReports(allocator: std.mem.Allocator, input: ReadinessInput) !ReadinessReports {
    var parsed = try std.json.parseFromSlice(PublicationPolicyArtifact, allocator, input.source_publication_policy_json, .{ .ignore_unknown_fields = true });
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
    source: PublicationPolicyArtifact,
) !ReadinessResult {
    var checks = std.ArrayList(ReadinessCheck).empty;
    errdefer checks.deinit(allocator);

    try appendCheck(allocator, &checks, "source-schema", if (std.mem.eql(u8, source.schema, source_publication_policy_schema) and source.schema_version == 1) .pass else .fail, "source advisory CI report publication-policy schema is supported");
    try appendCheck(allocator, &checks, "source-policy-ready", if (sourcePolicyReady(source)) .pass else .fail, "source publication policy is approved ready and ready for next branch");
    try appendCheck(allocator, &checks, "source-advisory-non-blocking", if (sourceAdvisoryNonBlocking(source)) .pass else .fail, "source preserves non-blocking advisory semantics and denied merge-blocker claims");
    try appendCheck(allocator, &checks, "source-required-status-check-disabled", if (!source.ci_required_status_check_enabled) .pass else .fail, "source keeps required status checks disabled");
    try appendCheck(allocator, &checks, "source-ci-enforcement-disabled", if (sourceCiEnforcementDisabled(source)) .pass else .fail, "source keeps CI gate enforcement workflow mutation and CI uploads disabled");
    try appendCheck(allocator, &checks, "source-publication-execution-disabled", if (sourcePublicationExecutionDisabled(source)) .pass else .fail, "source does not claim tool-executed publication summary comment or upload behavior");
    try appendCheck(allocator, &checks, "source-runtime-and-storage-disabled", if (sourceRuntimeAndStorageDisabled(source)) .pass else .fail, "source keeps live telemetry network runtime durable and NenDB writes disabled");
    try appendCheck(allocator, &checks, "source-interpretation-catalogs-present", if (sourceCatalogsPresent(source)) .pass else .fail, "source interpretation publication denied negative and blocked catalogs are present");
    try appendCheck(allocator, &checks, "required-status-check-semantics-defined", if (readinessCatalogsComplete()) .pass else .fail, "candidate required check profiles activation guardrails denied rules and fixtures are complete");
    try appendCheck(allocator, &checks, "required-verification-recorded", if (verifiedCommandsContainAll(options.verified_commands, required_verification_commands)) .pass else .fail, "readiness recorded every required verification command");
    try appendCheck(allocator, &checks, "decision-approved", if (options.decision == .approve) .pass else .fail, "reviewer approved required status check readiness");

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
    checks: *std.ArrayList(ReadinessCheck),
    name: []const u8,
    status: CheckStatus,
    detail: []const u8,
) !void {
    try checks.append(allocator, .{ .name = name, .status = status, .detail = detail });
}

fn allChecksPassed(checks: []const ReadinessCheck) bool {
    for (checks) |check| {
        if (check.status != .pass) return false;
    }
    return true;
}

fn sourcePolicyReady(source: PublicationPolicyArtifact) bool {
    return std.mem.eql(u8, source.decision, "approve") and
        std.mem.eql(u8, source.advisory_ci_report_publication_policy_status, "ready") and
        source.ready_for_next_branch and
        std.mem.eql(u8, source.mutation_authority, "none");
}

fn sourcePublicationExecutionDisabled(source: PublicationPolicyArtifact) bool {
    return !source.ci_report_publication_enabled and
        !source.github_step_summary_write_enabled and
        !source.pull_request_comment_enabled and
        !source.ci_upload_execution_enabled;
}

fn sourceCiEnforcementDisabled(source: PublicationPolicyArtifact) bool {
    return !source.ci_gate_enabled and
        !source.ci_gate_enforcement_enabled and
        !source.ci_required_status_check_enabled and
        !source.ci_workflow_mutation_enabled;
}

fn sourceRuntimeAndStorageDisabled(source: PublicationPolicyArtifact) bool {
    return !source.production_telemetry_ingestion and
        !source.live_exporter_enabled and
        !source.network_send_enabled and
        !source.collector_endpoint_configured and
        !source.otlp_serialization_enabled and
        !source.runtime_pipeline_enabled and
        !source.durable_write_enabled and
        !source.nendb_write_enabled;
}

fn sourceAdvisoryNonBlocking(source: PublicationPolicyArtifact) bool {
    return containsString(source.denied_inference_rules, "required-status-check") and
        containsString(source.denied_inference_rules, "merge-blocker") and
        containsString(source.denied_inference_rules, "branch-protection") and
        containsString(source.denied_inference_rules, "production-health-proof") and
        containsString(source.denied_inference_rules, "mutation-authority");
}

fn sourceChecksPassed(checks: []const SourceCheck) bool {
    if (checks.len == 0) return false;
    for (checks) |check| {
        if (std.mem.eql(u8, check.status, "fail")) return false;
    }
    return true;
}

fn sourceCatalogsPresent(source: PublicationPolicyArtifact) bool {
    return source.interpretation_rules.len > 0 and
        source.publication_surfaces.len > 0 and
        source.denied_inference_rules.len > 0 and
        source.negative_fixtures.len > 0 and
        source.blocked_claims.len > 0 and
        source.required_verification_commands.len > 0;
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

fn readinessCatalogsComplete() bool {
    return hasRequiredStatusCheckProfile("zigeffect-causal-telemetry-advisory-report") and
        hasRequiredStatusCheckProfile("zigeffect-causal-release-gate-report") and
        hasRequiredStatusCheckProfile("zigeffect-causal-required-check-contract") and
        hasActivationGuardrail("stable-check-names") and
        hasActivationGuardrail("no-github-mutation-by-this-tool") and
        hasActivationGuardrail("no-mutation-authority") and
        containsString(denied_inference_rules, "required-status-check-active") and
        containsString(denied_inference_rules, "branch-protection-updated") and
        containsString(denied_inference_rules, "github-check-run-created") and
        hasNegativeFixture("github-check-run-created-denied") and
        hasNegativeFixture("mutation-authority-claim-denied");
}

fn hasRequiredStatusCheckProfile(id: []const u8) bool {
    for (required_status_check_profiles) |profile| {
        if (std.mem.eql(u8, profile.id, id) and !profile.activation_enabled) return true;
    }
    return false;
}

fn hasActivationGuardrail(id: []const u8) bool {
    for (activation_guardrails) |guardrail| {
        if (std.mem.eql(u8, guardrail.id, id)) return true;
    }
    return false;
}

fn hasNegativeFixture(id: []const u8) bool {
    for (negative_fixtures) |fixture| {
        if (std.mem.eql(u8, fixture.id, id)) return true;
    }
    return false;
}

fn formatReadinessJson(
    allocator: std.mem.Allocator,
    options: Options,
    source: PublicationPolicyArtifact,
    result: ReadinessResult,
    paths: OutputPaths,
) ![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "{\n");
    try appendJsonField(allocator, &output, "schema", production_telemetry_ci_gate_required_status_check_readiness_schema, true);
    try output.appendSlice(allocator, "  \"schema_version\": 1,\n");
    try appendJsonField(allocator, &output, "generated_by", generated_by, true);
    try appendJsonField(allocator, &output, "source_publication_policy", options.publication_policy_path, true);
    try appendJsonField(allocator, &output, "source_publication_policy_status", source.advisory_ci_report_publication_policy_status, true);
    try appendJsonField(allocator, &output, "source_policy_decision", source.decision, true);
    try output.print(allocator, "  \"source_policy_ready_for_next_branch\": {},\n", .{source.ready_for_next_branch});
    try appendJsonField(allocator, &output, "source_mutation_authority", source.mutation_authority, true);
    try appendJsonField(allocator, &output, "source_after_report_digest", source.source_after_report_digest, true);
    try appendJsonField(allocator, &output, "decision", decisionText(options.decision), true);
    try appendJsonField(allocator, &output, "required_status_check_readiness_status", readinessStatusText(result.status), true);
    try output.print(allocator, "  \"ready_for_next_branch\": {},\n", .{result.ready_for_next_branch});
    try appendJsonField(allocator, &output, "reviewed_by", options.reviewed_by, true);
    try appendJsonField(allocator, &output, "policy", options.policy, true);
    try appendJsonField(allocator, &output, "reason", options.reason, true);
    try output.print(allocator, "  \"ci_gate_enabled\": {},\n", .{ci_gate_enabled});
    try output.print(allocator, "  \"ci_gate_enforcement_enabled\": {},\n", .{ci_gate_enforcement_enabled});
    try output.print(allocator, "  \"ci_required_status_check_enabled\": {},\n", .{ci_required_status_check_enabled});
    try output.print(allocator, "  \"ci_workflow_mutation_enabled\": {},\n", .{ci_workflow_mutation_enabled});
    try output.print(allocator, "  \"ci_upload_execution_enabled\": {},\n", .{ci_upload_execution_enabled});
    try output.print(allocator, "  \"ci_report_publication_enabled\": {},\n", .{ci_report_publication_enabled});
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
    try output.appendSlice(allocator, "  \"readiness_checks\": ");
    try appendChecksJson(allocator, &output, result.checks);
    try output.appendSlice(allocator, ",\n  \"required_status_check_profiles\": ");
    try appendRequiredStatusCheckProfilesJson(allocator, &output);
    try output.appendSlice(allocator, ",\n  \"readiness_dimensions\": ");
    try appendReadinessDimensionsJson(allocator, &output);
    try output.appendSlice(allocator, ",\n  \"activation_guardrails\": ");
    try appendActivationGuardrailsJson(allocator, &output);
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

fn formatReadinessText(
    allocator: std.mem.Allocator,
    options: Options,
    source: PublicationPolicyArtifact,
    result: ReadinessResult,
    paths: OutputPaths,
) ![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "zigeffect production telemetry CI gate required status check readiness\n");
    try output.print(allocator, "schema: {s}\n", .{production_telemetry_ci_gate_required_status_check_readiness_schema});
    try output.print(allocator, "source publication policy: {s}\n", .{options.publication_policy_path});
    try output.print(allocator, "source publication policy status: {s}\n", .{source.advisory_ci_report_publication_policy_status});
    try output.print(allocator, "source policy decision: {s}\n", .{source.decision});
    try output.print(allocator, "source policy ready for next branch: {}\n", .{source.ready_for_next_branch});
    try output.print(allocator, "source mutation authority: {s}\n", .{source.mutation_authority});
    try output.print(allocator, "source after report digest: {s}\n", .{source.source_after_report_digest});
    try output.print(allocator, "decision: {s}\n", .{decisionText(options.decision)});
    try output.print(allocator, "required_status_check_readiness_status: {s}\n", .{readinessStatusText(result.status)});
    try output.print(allocator, "ready_for_next_branch: {}\n", .{result.ready_for_next_branch});
    try output.print(allocator, "ci gate enabled: {}\n", .{ci_gate_enabled});
    try output.print(allocator, "ci gate enforcement enabled: {}\n", .{ci_gate_enforcement_enabled});
    try output.print(allocator, "ci required status check enabled: {}\n", .{ci_required_status_check_enabled});
    try output.print(allocator, "ci report publication enabled: {}\n", .{ci_report_publication_enabled});
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

    try output.appendSlice(allocator, "readiness checks:\n");
    for (result.checks) |check| {
        try output.print(allocator, "- {s}: {s} - {s}\n", .{ check.name, checkStatusText(check.status), check.detail });
    }
    try output.append(allocator, '\n');

    try appendRequiredStatusCheckProfilesText(allocator, &output);
    try appendReadinessDimensionsText(allocator, &output);
    try appendActivationGuardrailsText(allocator, &output);
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

fn appendChecksJson(allocator: std.mem.Allocator, output: *std.ArrayList(u8), checks: []const ReadinessCheck) !void {
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

fn appendRequiredStatusCheckProfilesJson(allocator: std.mem.Allocator, output: *std.ArrayList(u8)) !void {
    try output.append(allocator, '[');
    for (required_status_check_profiles, 0..) |profile, index| {
        if (index > 0) try output.appendSlice(allocator, ", ");
        try output.appendSlice(allocator, "{ \"id\": ");
        try appendJsonString(allocator, output, profile.id);
        try output.print(allocator, ", \"activation_enabled\": {}, \"source\": ", .{profile.activation_enabled});
        try appendJsonString(allocator, output, profile.source);
        try output.appendSlice(allocator, ", \"intended_future_signal\": ");
        try appendJsonString(allocator, output, profile.intended_future_signal);
        try output.appendSlice(allocator, ", \"denied_claim\": ");
        try appendJsonString(allocator, output, profile.denied_claim);
        try output.appendSlice(allocator, " }");
    }
    try output.append(allocator, ']');
}

fn appendReadinessDimensionsJson(allocator: std.mem.Allocator, output: *std.ArrayList(u8)) !void {
    try output.append(allocator, '[');
    for (readiness_dimensions, 0..) |dimension, index| {
        if (index > 0) try output.appendSlice(allocator, ", ");
        try output.appendSlice(allocator, "{ \"id\": ");
        try appendJsonString(allocator, output, dimension.id);
        try output.print(allocator, ", \"required\": {}, \"evidence\": ", .{dimension.required});
        try appendJsonString(allocator, output, dimension.evidence);
        try output.appendSlice(allocator, " }");
    }
    try output.append(allocator, ']');
}

fn appendActivationGuardrailsJson(allocator: std.mem.Allocator, output: *std.ArrayList(u8)) !void {
    try output.append(allocator, '[');
    for (activation_guardrails, 0..) |guardrail, index| {
        if (index > 0) try output.appendSlice(allocator, ", ");
        try output.appendSlice(allocator, "{ \"id\": ");
        try appendJsonString(allocator, output, guardrail.id);
        try output.print(allocator, ", \"required_before_application\": {}, \"reason\": ", .{guardrail.required_before_application});
        try appendJsonString(allocator, output, guardrail.reason);
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

fn appendRequiredStatusCheckProfilesText(allocator: std.mem.Allocator, output: *std.ArrayList(u8)) !void {
    try output.appendSlice(allocator, "required status check profiles:\n");
    for (required_status_check_profiles) |profile| {
        try output.print(allocator, "- {s}: activation_enabled={}, denied={s}\n", .{ profile.id, profile.activation_enabled, profile.denied_claim });
    }
    try output.append(allocator, '\n');
}

fn appendReadinessDimensionsText(allocator: std.mem.Allocator, output: *std.ArrayList(u8)) !void {
    try output.appendSlice(allocator, "readiness dimensions:\n");
    for (readiness_dimensions) |dimension| {
        try output.print(allocator, "- {s}: required={}\n", .{ dimension.id, dimension.required });
    }
    try output.append(allocator, '\n');
}

fn appendActivationGuardrailsText(allocator: std.mem.Allocator, output: *std.ArrayList(u8)) !void {
    try output.appendSlice(allocator, "activation guardrails:\n");
    for (activation_guardrails) |guardrail| {
        try output.print(allocator, "- {s}: required_before_application={}\n", .{ guardrail.id, guardrail.required_before_application });
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

fn blockedClaims(source: PublicationPolicyArtifact) []const []const u8 {
    if (source.blocked_claims.len > 0) return source.blocked_claims;
    return denied_inference_rules;
}

fn agentGuidance(status: RequiredStatusCheckReadinessStatus) []const []const u8 {
    return switch (status) {
        .ready => &.{
            "Use ready required-status-check readiness artifacts to start the application-boundary design only.",
            "Required check profiles are candidates with activation_enabled=false and must not block merges.",
            "Do not infer branch protection GitHub mutation production health cluster readiness durable writes NenDB writes or mutation authority.",
        },
        .blocked => &.{
            "Treat blocked required-status-check readiness artifacts as a stop sign.",
            "Repair source publication-policy evidence verification commands check profiles or activation guardrails before continuing.",
            "Do not start required-status-check application boundary work from blocked readiness evidence.",
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
    const source_publication_policy_json = try readRequiredArtifact(init.io, allocator, options.publication_policy_path, error.MissingPublicationPolicyInput);
    defer allocator.free(source_publication_policy_json);

    const reports = try formatReports(allocator, .{
        .options = options,
        .source_publication_policy_json = source_publication_policy_json,
    });
    defer reports.deinit(allocator);

    const paths = try outputPathsForOptions(allocator, options);
    defer paths.deinit(allocator);

    try writeArtifact(init.io, paths.json_path, reports.json);
    try writeArtifact(init.io, paths.text_path, reports.text);
    std.debug.print("{s}", .{reports.text});
}

fn usage() []const u8 {
    return "usage: zig build causal-production-telemetry-ci-gate-required-status-check-readiness -- --from-publication-policy <advisory-ci-report-publication-policy.json> approve|reject --reason <reason> [--by <actor>] [--policy <policy>] [--verified-command <command>]... [--out-prefix <path-prefix>]\n";
}

fn failUsage(err: anyerror) noreturn {
    std.debug.print("causal-production-telemetry-ci-gate-required-status-check-readiness error: {s}\n{s}", .{ @errorName(err), usage() });
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

test "ci gate required status check readiness schema and branch constants are stable" {
    try std.testing.expectEqualStrings("zigeffect.causal.production-telemetry-ci-gate-required-status-check-readiness.v1", production_telemetry_ci_gate_required_status_check_readiness_schema);
    try std.testing.expectEqual(@as(u32, 1), production_telemetry_ci_gate_required_status_check_readiness_schema_version);
    try std.testing.expectEqualStrings("codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-readiness", source_branch);
    try std.testing.expectEqualStrings("start-production-telemetry-ci-gate-required-status-check-application-boundary", recommendation);
    try std.testing.expectEqualStrings("codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-application-boundary", next_branch_if_ready);
    try std.testing.expect(containsString(required_verification_commands, "zig build causal-production-telemetry-ci-gate-advisory-ci-report-publication-policy"));
    try std.testing.expect(containsString(required_verification_commands, "zig build release-gate-report"));
}

test "parses ci gate required status check readiness approval and rejection options" {
    var approve_options = try parseOptions(std.testing.allocator, &.{
        "zigeffect-causal-production-telemetry-ci-gate-required-status-check-readiness",
        "--from-publication-policy",
        ".zig-cache/causal-artifacts/advisory-ci-report-publication-policy.json",
        "approve",
        "--reason",
        "required status check readiness reviewed",
        "--by",
        "codex",
        "--policy",
        "manual-production-telemetry-ci-gate-required-status-check-readiness",
        "--verified-command",
        "zig build causal-production-telemetry-ci-gate-advisory-ci-report-publication-policy",
        "--out-prefix",
        ".zig-cache/causal-artifacts/custom-required-status-check-readiness",
    });
    defer approve_options.deinit(std.testing.allocator);

    try std.testing.expectEqual(Decision.approve, approve_options.decision);
    try std.testing.expectEqualStrings(".zig-cache/causal-artifacts/advisory-ci-report-publication-policy.json", approve_options.publication_policy_path);
    try std.testing.expectEqualStrings("codex", approve_options.reviewed_by);
    try std.testing.expectEqualStrings("manual-production-telemetry-ci-gate-required-status-check-readiness", approve_options.policy);
    try std.testing.expectEqual(@as(usize, 1), approve_options.verified_commands.len);
    try std.testing.expectEqualStrings(".zig-cache/causal-artifacts/custom-required-status-check-readiness", approve_options.out_prefix.?);

    var reject_options = try parseOptions(std.testing.allocator, &.{
        "zigeffect-causal-production-telemetry-ci-gate-required-status-check-readiness",
        "--from-publication-policy",
        ".zig-cache/causal-artifacts/advisory-ci-report-publication-policy.json",
        "reject",
        "--reason",
        "negative required status check readiness path",
    });
    defer reject_options.deinit(std.testing.allocator);

    try std.testing.expectEqual(Decision.reject, reject_options.decision);
    try std.testing.expectError(error.UnknownDecision, parseOptions(std.testing.allocator, &.{ "tool", "--from-publication-policy", ".zig-cache/report.json", "maybe", "--reason", "bad" }));
    try std.testing.expectError(error.MissingReason, parseOptions(std.testing.allocator, &.{ "tool", "--from-publication-policy", ".zig-cache/report.json", "approve" }));
}

test "default output path replaces publication policy suffix and compacts long names" {
    const options = Options{
        .publication_policy_path = "../../.zig-cache/causal-artifacts/example-ci-gate-advisory-ci-report-publication-policy.json",
        .decision = .approve,
        .reason = "planned",
    };
    const paths = try outputPathsForOptions(std.testing.allocator, options);
    defer paths.deinit(std.testing.allocator);

    try std.testing.expectEqualStrings("../../.zig-cache/causal-artifacts/example-ci-gate-required-status-check-readiness.json", paths.json_path);
    try std.testing.expectEqualStrings("../../.zig-cache/causal-artifacts/example-ci-gate-required-status-check-readiness.txt", paths.text_path);

    const long_options = Options{
        .publication_policy_path = "../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures-nendb-retention-fixtures-workbench-readonly-preview-ci-artifact-preview-ci-harness-boundary-ci-gate-advisory-ci-report-publication-policy.json",
        .decision = .approve,
        .reason = "planned",
    };
    const long_paths = try outputPathsForOptions(std.testing.allocator, long_options);
    defer long_paths.deinit(std.testing.allocator);

    const file_name = fileName(long_paths.json_path);
    try std.testing.expect(file_name.len <= 240);
    try std.testing.expect(contains(long_paths.json_path, "production-telemetry-ci-gate-required-status-check-readiness-"));
}

test "approved required status check readiness preserves disabled activation" {
    const reports = try formatReports(std.testing.allocator, .{
        .options = .{
            .publication_policy_path = ".zig-cache/causal-artifacts/advisory-ci-report-publication-policy.json",
            .decision = .approve,
            .reason = "required status check readiness reviewed",
            .verified_commands = required_verification_commands,
        },
        .source_publication_policy_json = sample_ready_publication_policy_json,
    });
    defer reports.deinit(std.testing.allocator);

    try std.testing.expect(contains(reports.json, "\"schema\": \"zigeffect.causal.production-telemetry-ci-gate-required-status-check-readiness.v1\""));
    try std.testing.expect(contains(reports.json, "\"required_status_check_readiness_status\": \"ready\""));
    try std.testing.expect(contains(reports.json, "\"ready_for_next_branch\": true"));
    try std.testing.expect(contains(reports.json, "\"mutation_authority\": \"none\""));
    try std.testing.expect(contains(reports.json, "\"ci_required_status_check_enabled\": false"));
    try std.testing.expect(contains(reports.json, "\"id\": \"zigeffect-causal-telemetry-advisory-report\""));
    try std.testing.expect(contains(reports.json, "\"activation_enabled\": false"));
    try std.testing.expect(contains(reports.json, "\"id\": \"stable-check-names\""));
    try std.testing.expect(contains(reports.json, "\"required-status-check-active\""));
    try std.testing.expect(contains(reports.json, "\"github-check-run-created-denied\""));
    try std.testing.expect(contains(reports.json, "\"id\": \"mutation-authority-claim-denied\""));
    try std.testing.expect(contains(reports.json, "\"next_branch_if_ready\": \"codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-application-boundary\""));
    try std.testing.expect(contains(reports.text, "required_status_check_readiness_status: ready"));
    try std.testing.expect(contains(reports.text, "next branch if ready: codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-application-boundary"));
}

test "rejection incomplete verification and invalid sources block required status check readiness" {
    const rejected = try formatReports(std.testing.allocator, .{
        .options = .{
            .publication_policy_path = ".zig-cache/causal-artifacts/advisory-ci-report-publication-policy.json",
            .decision = .reject,
            .reason = "negative required status check readiness path",
            .verified_commands = required_verification_commands,
        },
        .source_publication_policy_json = sample_ready_publication_policy_json,
    });
    defer rejected.deinit(std.testing.allocator);
    try std.testing.expect(contains(rejected.json, "\"required_status_check_readiness_status\": \"blocked\""));
    try std.testing.expect(contains(rejected.json, "\"name\": \"decision-approved\""));

    const incomplete = try formatReports(std.testing.allocator, .{
        .options = .{
            .publication_policy_path = ".zig-cache/causal-artifacts/advisory-ci-report-publication-policy.json",
            .decision = .approve,
            .reason = "missing verification commands",
        },
        .source_publication_policy_json = sample_ready_publication_policy_json,
    });
    defer incomplete.deinit(std.testing.allocator);
    try std.testing.expect(contains(incomplete.json, "\"required_status_check_readiness_status\": \"blocked\""));
    try std.testing.expect(contains(incomplete.json, "\"name\": \"required-verification-recorded\""));

    const blocked_source = try formatReports(std.testing.allocator, .{
        .options = .{
            .publication_policy_path = ".zig-cache/causal-artifacts/advisory-ci-report-publication-policy.json",
            .decision = .approve,
            .reason = "blocked source",
            .verified_commands = required_verification_commands,
        },
        .source_publication_policy_json = sample_blocked_publication_policy_json,
    });
    defer blocked_source.deinit(std.testing.allocator);
    try std.testing.expect(contains(blocked_source.json, "\"required_status_check_readiness_status\": \"blocked\""));
    try std.testing.expect(contains(blocked_source.json, "\"name\": \"source-policy-ready\""));

    const missing_denied_source = try formatReports(std.testing.allocator, .{
        .options = .{
            .publication_policy_path = ".zig-cache/causal-artifacts/advisory-ci-report-publication-policy.json",
            .decision = .approve,
            .reason = "missing denied source",
            .verified_commands = required_verification_commands,
        },
        .source_publication_policy_json = sample_publication_policy_json_missing_denied_rule,
    });
    defer missing_denied_source.deinit(std.testing.allocator);
    try std.testing.expect(contains(missing_denied_source.json, "\"required_status_check_readiness_status\": \"blocked\""));
    try std.testing.expect(contains(missing_denied_source.json, "\"name\": \"source-advisory-non-blocking\""));

    const unsafe_source = try formatReports(std.testing.allocator, .{
        .options = .{
            .publication_policy_path = ".zig-cache/causal-artifacts/advisory-ci-report-publication-policy.json",
            .decision = .approve,
            .reason = "unsafe source",
            .verified_commands = required_verification_commands,
        },
        .source_publication_policy_json = sample_publication_policy_json_with_required_check,
    });
    defer unsafe_source.deinit(std.testing.allocator);
    try std.testing.expect(contains(unsafe_source.json, "\"required_status_check_readiness_status\": \"blocked\""));
    try std.testing.expect(contains(unsafe_source.json, "\"name\": \"source-required-status-check-disabled\""));
}

const sample_ready_publication_policy_json =
    \\{
    \\  "schema": "zigeffect.causal.production-telemetry-ci-gate-advisory-ci-report-publication-policy.v1",
    \\  "schema_version": 1,
    \\  "source_application_boundary": ".zig-cache/causal-artifacts/advisory-ci-report-application-boundary.json",
    \\  "source_report_application_status": "applied",
    \\  "source_mode": "record-applied",
    \\  "source_applied": true,
    \\  "source_mutation_authority": "record-only",
    \\  "source_after_report_digest": "sha256:after-report-digest",
    \\  "decision": "approve",
    \\  "advisory_ci_report_publication_policy_status": "ready",
    \\  "ready_for_next_branch": true,
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
    \\  "mutation_authority": "none",
    \\  "policy_checks": [{ "name": "source-schema", "status": "pass", "detail": "supported" }],
    \\  "interpretation_rules": [{ "id": "non-blocking-ci-advisory", "consumer_role": "ci-reviewer", "allowed_use": "advisory only", "failure_effect": "informational", "denied_claim": "merge blocker" }],
    \\  "publication_surfaces": [{ "id": "local-json-artifact", "visibility_class": "local", "executed_by_tool": false, "interpretation_scope": "machine evidence" }],
    \\  "denied_inference_rules": ["required-status-check", "merge-blocker", "branch-protection", "production-health-proof", "mutation-authority"],
    \\  "negative_fixtures": [{ "id": "required-status-check-claim-denied", "artifact_state": "ci_required_status_check_enabled=true", "decision": "deny", "failed_gate": "source-required-status-check-disabled", "reason": "required checks denied" }],
    \\  "blocked_claims": ["required-status-check-active", "merge-blocker-active", "production-health-proven"],
    \\  "required_verification_commands": ["zig build causal-production-telemetry-ci-gate-advisory-ci-report-publication-policy", "zig build causal-artifacts"],
    \\  "verified_commands": ["zig build causal-production-telemetry-ci-gate-advisory-ci-report-publication-policy", "zig build causal-artifacts"],
    \\  "generated_by": "causal-production-telemetry-ci-gate-advisory-ci-report-publication-policy"
    \\}
;

const sample_blocked_publication_policy_json =
    \\{
    \\  "schema": "zigeffect.causal.production-telemetry-ci-gate-advisory-ci-report-publication-policy.v1",
    \\  "schema_version": 1,
    \\  "source_application_boundary": ".zig-cache/causal-artifacts/advisory-ci-report-application-boundary-negative.json",
    \\  "source_report_application_status": "blocked",
    \\  "source_mode": "record-applied",
    \\  "source_applied": false,
    \\  "source_mutation_authority": "none",
    \\  "source_after_report_digest": "",
    \\  "decision": "reject",
    \\  "advisory_ci_report_publication_policy_status": "blocked",
    \\  "ready_for_next_branch": false,
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
    \\  "mutation_authority": "none",
    \\  "policy_checks": [{ "name": "source-applied", "status": "fail", "detail": "blocked" }],
    \\  "interpretation_rules": [{ "id": "non-blocking-ci-advisory", "consumer_role": "ci-reviewer", "allowed_use": "advisory only", "failure_effect": "informational", "denied_claim": "merge blocker" }],
    \\  "publication_surfaces": [{ "id": "local-json-artifact", "visibility_class": "local", "executed_by_tool": false, "interpretation_scope": "machine evidence" }],
    \\  "denied_inference_rules": ["required-status-check", "merge-blocker", "branch-protection", "production-health-proof", "mutation-authority"],
    \\  "negative_fixtures": [{ "id": "blocked-source-denied", "artifact_state": "blocked", "decision": "deny", "failed_gate": "source-policy-ready", "reason": "blocked" }],
    \\  "blocked_claims": ["required-status-check-active"],
    \\  "required_verification_commands": ["zig build causal-production-telemetry-ci-gate-advisory-ci-report-publication-policy"],
    \\  "verified_commands": [],
    \\  "generated_by": "causal-production-telemetry-ci-gate-advisory-ci-report-publication-policy"
    \\}
;

const sample_publication_policy_json_missing_denied_rule =
    \\{
    \\  "schema": "zigeffect.causal.production-telemetry-ci-gate-advisory-ci-report-publication-policy.v1",
    \\  "schema_version": 1,
    \\  "source_application_boundary": ".zig-cache/causal-artifacts/advisory-ci-report-application-boundary.json",
    \\  "source_report_application_status": "applied",
    \\  "source_mode": "record-applied",
    \\  "source_applied": true,
    \\  "source_mutation_authority": "record-only",
    \\  "source_after_report_digest": "sha256:after-report-digest",
    \\  "decision": "approve",
    \\  "advisory_ci_report_publication_policy_status": "ready",
    \\  "ready_for_next_branch": true,
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
    \\  "mutation_authority": "none",
    \\  "policy_checks": [{ "name": "source-schema", "status": "pass", "detail": "supported" }],
    \\  "interpretation_rules": [{ "id": "non-blocking-ci-advisory", "consumer_role": "ci-reviewer", "allowed_use": "advisory only", "failure_effect": "informational", "denied_claim": "merge blocker" }],
    \\  "publication_surfaces": [{ "id": "local-json-artifact", "visibility_class": "local", "executed_by_tool": false, "interpretation_scope": "machine evidence" }],
    \\  "denied_inference_rules": ["branch-protection", "production-health-proof", "mutation-authority"],
    \\  "negative_fixtures": [{ "id": "required-status-check-claim-denied", "artifact_state": "ci_required_status_check_enabled=true", "decision": "deny", "failed_gate": "source-required-status-check-disabled", "reason": "required checks denied" }],
    \\  "blocked_claims": ["required-status-check-active"],
    \\  "required_verification_commands": ["zig build causal-production-telemetry-ci-gate-advisory-ci-report-publication-policy"],
    \\  "verified_commands": ["zig build causal-production-telemetry-ci-gate-advisory-ci-report-publication-policy"],
    \\  "generated_by": "causal-production-telemetry-ci-gate-advisory-ci-report-publication-policy"
    \\}
;

const sample_publication_policy_json_with_required_check =
    \\{
    \\  "schema": "zigeffect.causal.production-telemetry-ci-gate-advisory-ci-report-publication-policy.v1",
    \\  "schema_version": 1,
    \\  "source_application_boundary": ".zig-cache/causal-artifacts/advisory-ci-report-application-boundary.json",
    \\  "source_report_application_status": "applied",
    \\  "source_mode": "record-applied",
    \\  "source_applied": true,
    \\  "source_mutation_authority": "record-only",
    \\  "source_after_report_digest": "sha256:after-report-digest",
    \\  "decision": "approve",
    \\  "advisory_ci_report_publication_policy_status": "ready",
    \\  "ready_for_next_branch": true,
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
    \\  "mutation_authority": "none",
    \\  "policy_checks": [{ "name": "source-schema", "status": "pass", "detail": "supported" }],
    \\  "interpretation_rules": [{ "id": "non-blocking-ci-advisory", "consumer_role": "ci-reviewer", "allowed_use": "advisory only", "failure_effect": "informational", "denied_claim": "merge blocker" }],
    \\  "publication_surfaces": [{ "id": "local-json-artifact", "visibility_class": "local", "executed_by_tool": false, "interpretation_scope": "machine evidence" }],
    \\  "denied_inference_rules": ["required-status-check", "merge-blocker", "branch-protection", "production-health-proof", "mutation-authority"],
    \\  "negative_fixtures": [{ "id": "required-status-check-claim-denied", "artifact_state": "ci_required_status_check_enabled=true", "decision": "deny", "failed_gate": "source-required-status-check-disabled", "reason": "required checks denied" }],
    \\  "blocked_claims": ["required-status-check-active"],
    \\  "required_verification_commands": ["zig build causal-production-telemetry-ci-gate-advisory-ci-report-publication-policy"],
    \\  "verified_commands": [],
    \\  "generated_by": "causal-production-telemetry-ci-gate-advisory-ci-report-publication-policy"
    \\}
;
