const std = @import("std");

pub const production_telemetry_ci_gate_required_status_check_application_boundary_schema = "zigeffect.causal.production-telemetry-ci-gate-required-status-check-application-boundary.v1";
pub const production_telemetry_ci_gate_required_status_check_application_boundary_schema_version: u32 = 1;
pub const source_branch = "codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-application-boundary";
pub const recommendation = "start-production-telemetry-ci-gate-required-status-check-policy";
pub const next_branch_if_ready = "codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-policy";

const source_readiness_schema = "zigeffect.causal.production-telemetry-ci-gate-required-status-check-readiness.v1";
const generated_by = "causal-production-telemetry-ci-gate-required-status-check-application-boundary";
const source_readiness_suffix = "-ci-gate-required-status-check-readiness.json";
const output_prefix_suffix = "-ci-gate-required-status-check-application-boundary";
const compact_output_prefix_name = "production-telemetry-ci-gate-required-status-check-application-boundary";
const max_default_output_file_name_len = 240;
const max_source_bytes = 1024 * 1024;

const required_verification_commands: []const []const u8 = &.{
    "zig build causal-production-telemetry-ci-gate-required-status-check-readiness",
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

const Mode = enum { plan, record_applied };
const RequiredStatusCheckApplicationStatus = enum { planned, applied, blocked };
const CheckStatus = enum { pass, fail, skipped };

const Options = struct {
    readiness_path: []const u8,
    mode: Mode,
    reviewed_by: []const u8 = "required-status-check-application-boundary-reviewer",
    policy: []const u8 = "manual-production-telemetry-ci-gate-required-status-check-application-boundary",
    reason: []const u8,
    required_check_profile: ?[]const u8 = null,
    branch_protection_changes: []const []const u8 = &.{},
    workflow_changes: []const []const u8 = &.{},
    check_run_changes: []const []const u8 = &.{},
    before_evidence: []const []const u8 = &.{},
    after_evidence: []const []const u8 = &.{},
    branch_protection_after_path: ?[]const u8 = null,
    workflow_after_path: ?[]const u8 = null,
    verified_commands: []const []const u8 = &.{},
    out_prefix: ?[]const u8 = null,

    fn deinit(self: Options, allocator: std.mem.Allocator) void {
        freeSliceOnly(allocator, self.branch_protection_changes);
        freeSliceOnly(allocator, self.workflow_changes);
        freeSliceOnly(allocator, self.check_run_changes);
        freeSliceOnly(allocator, self.before_evidence);
        freeSliceOnly(allocator, self.after_evidence);
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

const BoundaryInput = struct {
    options: Options,
    source_readiness_json: []const u8,
    branch_protection_after_text: ?[]const u8 = null,
    workflow_after_yml: ?[]const u8 = null,
};

const BoundaryReports = struct {
    json: []const u8,
    text: []const u8,

    fn deinit(self: BoundaryReports, allocator: std.mem.Allocator) void {
        allocator.free(self.json);
        allocator.free(self.text);
    }
};

const SourceReadinessCheck = struct {
    name: []const u8 = "",
    id: []const u8 = "",
    status: []const u8,
    detail: []const u8 = "",
};

const SourceRequiredStatusCheckProfile = struct {
    id: []const u8,
    activation_enabled: bool,
    source: []const u8 = "",
    intended_future_signal: []const u8 = "",
    denied_claim: []const u8 = "",
};

const SourceReadinessDimension = struct {
    id: []const u8,
    required: bool = false,
    evidence: []const u8 = "",
};

const SourceActivationGuardrail = struct {
    id: []const u8,
    required_before_application: bool = false,
    reason: []const u8 = "",
};

const SourceNegativeFixture = struct {
    id: []const u8 = "",
    artifact_state: []const u8 = "",
    decision: []const u8 = "",
    failed_gate: []const u8 = "",
    reason: []const u8 = "",
};

const RequiredStatusCheckReadinessArtifact = struct {
    schema: []const u8,
    schema_version: u32,
    generated_by: []const u8 = "",
    source_branch: []const u8 = "",
    recommendation: []const u8 = "",
    next_branch_if_ready: []const u8 = "",
    source_publication_policy: []const u8 = "",
    source_publication_policy_status: []const u8 = "",
    source_policy_decision: []const u8 = "",
    source_mutation_authority: []const u8 = "",
    source_after_report_digest: []const u8 = "",
    decision: []const u8,
    required_status_check_readiness_status: []const u8,
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
    mutation_authority: []const u8,
    readiness_checks: []const SourceReadinessCheck = &.{},
    required_status_check_profiles: []const SourceRequiredStatusCheckProfile = &.{},
    readiness_dimensions: []const SourceReadinessDimension = &.{},
    activation_guardrails: []const SourceActivationGuardrail = &.{},
    denied_inference_rules: []const []const u8 = &.{},
    negative_fixtures: []const SourceNegativeFixture = &.{},
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
    status: RequiredStatusCheckApplicationStatus,
    applied: bool,
    checks: []const BoundaryCheck,

    fn deinit(self: BoundaryResult, allocator: std.mem.Allocator) void {
        if (self.checks.len > 0) allocator.free(self.checks);
    }
};

const NegativeFixture = struct {
    id: []const u8,
    artifact_state: []const u8,
    decision: []const u8,
    failed_gate: []const u8,
    reason: []const u8,
};

const denied_inference_rules: []const []const u8 = &.{
    "github-api-mutation-by-tool",
    "branch-protection-mutation-by-tool",
    "workflow-mutation-by-tool",
    "github-check-run-created-by-tool",
    "artifact-upload-executed-by-tool",
    "github-step-summary-written-by-tool",
    "pull-request-comment-written-by-tool",
    "ci-gate-enforcement-by-tool",
    "live-telemetry-ingestion",
    "network-send",
    "runtime-pipeline-activation",
    "durable-production-write",
    "nendb-write",
    "non-nendb-durable-adapter",
    "alternate-renderer",
    "deployment-success-proof",
    "production-health-proof",
    "production-cluster-readiness-proof",
    "customer-impact-proof",
    "capacity-proof",
    "mutation-authority",
};

const blocked_claims: []const []const u8 = &.{
    "github-api-mutation-by-tool",
    "branch-protection-mutation-by-tool",
    "workflow-mutation-by-tool",
    "github-check-run-created-by-tool",
    "artifact-upload-executed-by-tool",
    "github-step-summary-written-by-tool",
    "pull-request-comment-written-by-tool",
    "ci-gate-enforcement-active",
    "required-status-check-created-by-tool",
    "live-telemetry-ingested",
    "network-send-enabled",
    "runtime-pipeline-enabled",
    "durable-production-write-enabled",
    "nendb-write-enabled",
    "production-health-proven",
    "production-cluster-ready",
    "non-nendb-durable-adapter",
    "react-or-alternate-renderer",
    "mutation-authority-granted",
};

const negative_fixtures: []const NegativeFixture = &.{
    .{ .id = "blocked-source-readiness-denied", .artifact_state = "required_status_check_readiness_status=blocked", .decision = "deny", .failed_gate = "source-readiness-ready", .reason = "blocked readiness cannot feed application-boundary evidence" },
    .{ .id = "missing-required-check-profile-denied", .artifact_state = "record-applied required_check_profile=null", .decision = "deny", .failed_gate = "required-check-profile-present", .reason = "record-applied requires a selected required-check profile" },
    .{ .id = "active-source-required-check-profile-denied", .artifact_state = "source profile activation_enabled=true", .decision = "deny", .failed_gate = "selected-profile-inactive", .reason = "source profiles must remain inactive in this record-only boundary" },
    .{ .id = "missing-branch-protection-change-denied", .artifact_state = "record-applied branch_protection_changes=[]", .decision = "deny", .failed_gate = "branch-protection-change-present", .reason = "reviewed branch-protection evidence is required" },
    .{ .id = "missing-workflow-or-check-run-change-denied", .artifact_state = "record-applied workflow_changes=[] check_run_changes=[]", .decision = "deny", .failed_gate = "workflow-or-check-run-change-present", .reason = "reviewed workflow or check-run evidence is required" },
    .{ .id = "missing-before-evidence-denied", .artifact_state = "record-applied before=[]", .decision = "deny", .failed_gate = "before-evidence-present", .reason = "before evidence is required" },
    .{ .id = "missing-after-evidence-denied", .artifact_state = "record-applied after=[]", .decision = "deny", .failed_gate = "after-evidence-present", .reason = "after evidence is required" },
    .{ .id = "missing-release-gate-report-verification-denied", .artifact_state = "verified commands missing release-gate-report", .decision = "deny", .failed_gate = "post-verification-recorded", .reason = "release-gate report verification is required" },
    .{ .id = "unsafe-branch-protection-after-secret-denied", .artifact_state = "branch_protection_after contains github_pat_", .decision = "deny", .failed_gate = "branch-protection-after-safe", .reason = "branch-protection after-state must not contain secrets" },
    .{ .id = "unsafe-workflow-after-upload-denied", .artifact_state = "workflow_after contains upload-artifact", .decision = "deny", .failed_gate = "workflow-after-safe", .reason = "this tool does not execute artifact uploads" },
    .{ .id = "github-api-mutation-claim-denied", .artifact_state = "github_api_mutation=true", .decision = "deny", .failed_gate = "no-github-api-mutation-by-tool", .reason = "this tool does not call GitHub APIs" },
    .{ .id = "live-telemetry-claim-denied", .artifact_state = "live_telemetry_ingested=true", .decision = "deny", .failed_gate = "no-live-telemetry", .reason = "this boundary does not ingest live telemetry" },
    .{ .id = "durable-write-claim-denied", .artifact_state = "durable_write_enabled=true", .decision = "deny", .failed_gate = "no-durable-write", .reason = "this boundary does not write durable production storage" },
    .{ .id = "nendb-write-claim-denied", .artifact_state = "nendb_write_enabled=true", .decision = "deny", .failed_gate = "no-nendb-write", .reason = "this boundary does not write NenDB" },
    .{ .id = "production-health-claim-denied", .artifact_state = "production_health=proven", .decision = "deny", .failed_gate = "ci-not-production", .reason = "CI evidence is not production health proof" },
    .{ .id = "production-cluster-readiness-claim-denied", .artifact_state = "production_cluster_ready=true", .decision = "deny", .failed_gate = "ci-not-cluster", .reason = "CI evidence is not cluster readiness proof" },
    .{ .id = "alternate-renderer-claim-denied", .artifact_state = "renderer=react", .decision = "deny", .failed_gate = "solid-webui", .reason = "workbench direction remains SolidJS inside zig-webui" },
    .{ .id = "mutation-authority-claim-denied", .artifact_state = "mutation_authority=granted", .decision = "deny", .failed_gate = "mutation-authority-none", .reason = "mutation authority remains none" },
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
        error.MissingReadinessInput, error.MissingBranchProtectionAfterInput, error.MissingWorkflowAfterInput => failUsage(err),
        else => return err,
    };
}

fn parseOptions(allocator: std.mem.Allocator, args: []const []const u8) !Options {
    if (args.len < 2) return error.MissingSourceReadiness;
    if (!std.mem.eql(u8, args[1], "--from-readiness")) return error.UnknownOption;
    if (args.len < 3) return error.MissingSourceReadiness;
    const readiness_path = args[2];
    if (!std.mem.endsWith(u8, readiness_path, ".json")) return error.InvalidSourceReadinessPath;
    if (args.len < 4) return error.UnknownMode;
    const mode = try parseMode(args[3]);

    var reviewed_by: []const u8 = "required-status-check-application-boundary-reviewer";
    var policy: []const u8 = "manual-production-telemetry-ci-gate-required-status-check-application-boundary";
    var reason: ?[]const u8 = null;
    var required_check_profile: ?[]const u8 = null;
    var branch_protection_changes = std.ArrayList([]const u8).empty;
    var workflow_changes = std.ArrayList([]const u8).empty;
    var check_run_changes = std.ArrayList([]const u8).empty;
    var before_evidence = std.ArrayList([]const u8).empty;
    var after_evidence = std.ArrayList([]const u8).empty;
    var verified_commands = std.ArrayList([]const u8).empty;
    var branch_protection_after_path: ?[]const u8 = null;
    var workflow_after_path: ?[]const u8 = null;
    var out_prefix: ?[]const u8 = null;
    errdefer branch_protection_changes.deinit(allocator);
    errdefer workflow_changes.deinit(allocator);
    errdefer check_run_changes.deinit(allocator);
    errdefer before_evidence.deinit(allocator);
    errdefer after_evidence.deinit(allocator);
    errdefer verified_commands.deinit(allocator);

    var index: usize = 4;
    while (index < args.len) {
        if (index + 1 >= args.len) return error.MissingOptionValue;
        const flag = args[index];
        const value = args[index + 1];
        if (!std.mem.startsWith(u8, flag, "--")) return error.UnknownOption;

        if (std.mem.eql(u8, flag, "--by")) {
            reviewed_by = value;
        } else if (std.mem.eql(u8, flag, "--policy")) {
            policy = value;
        } else if (std.mem.eql(u8, flag, "--reason")) {
            reason = value;
        } else if (std.mem.eql(u8, flag, "--required-check-profile")) {
            required_check_profile = value;
        } else if (std.mem.eql(u8, flag, "--branch-protection-change")) {
            try branch_protection_changes.append(allocator, value);
        } else if (std.mem.eql(u8, flag, "--workflow-change")) {
            try workflow_changes.append(allocator, value);
        } else if (std.mem.eql(u8, flag, "--check-run-change")) {
            try check_run_changes.append(allocator, value);
        } else if (std.mem.eql(u8, flag, "--before")) {
            try before_evidence.append(allocator, value);
        } else if (std.mem.eql(u8, flag, "--after")) {
            try after_evidence.append(allocator, value);
        } else if (std.mem.eql(u8, flag, "--branch-protection-after")) {
            if (!branchProtectionAfterPathValid(value)) return error.InvalidBranchProtectionAfterPath;
            branch_protection_after_path = value;
        } else if (std.mem.eql(u8, flag, "--workflow-after")) {
            if (!workflowAfterPathValid(value)) return error.InvalidWorkflowAfterPath;
            workflow_after_path = value;
        } else if (std.mem.eql(u8, flag, "--verified-command")) {
            try verified_commands.append(allocator, value);
        } else if (std.mem.eql(u8, flag, "--out-prefix")) {
            out_prefix = value;
        } else {
            return error.UnknownOption;
        }
        index += 2;
    }

    const final_reason = reason orelse return error.MissingReason;
    if (final_reason.len == 0) return error.MissingReason;

    return .{
        .readiness_path = readiness_path,
        .mode = mode,
        .reviewed_by = reviewed_by,
        .policy = policy,
        .reason = final_reason,
        .required_check_profile = required_check_profile,
        .branch_protection_changes = try branch_protection_changes.toOwnedSlice(allocator),
        .workflow_changes = try workflow_changes.toOwnedSlice(allocator),
        .check_run_changes = try check_run_changes.toOwnedSlice(allocator),
        .before_evidence = try before_evidence.toOwnedSlice(allocator),
        .after_evidence = try after_evidence.toOwnedSlice(allocator),
        .branch_protection_after_path = branch_protection_after_path,
        .workflow_after_path = workflow_after_path,
        .verified_commands = try verified_commands.toOwnedSlice(allocator),
        .out_prefix = out_prefix,
    };
}

fn parseMode(value: []const u8) !Mode {
    if (std.mem.eql(u8, value, "plan")) return .plan;
    if (std.mem.eql(u8, value, "record-applied")) return .record_applied;
    return error.UnknownMode;
}

fn modeText(mode: Mode) []const u8 {
    return switch (mode) {
        .plan => "plan",
        .record_applied => "record-applied",
    };
}

fn statusText(status: RequiredStatusCheckApplicationStatus) []const u8 {
    return switch (status) {
        .planned => "planned",
        .applied => "applied",
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

fn branchProtectionAfterPathValid(path: []const u8) bool {
    return std.mem.endsWith(u8, path, ".json") or std.mem.endsWith(u8, path, ".md") or std.mem.endsWith(u8, path, ".txt");
}

fn workflowAfterPathValid(path: []const u8) bool {
    return std.mem.endsWith(u8, path, ".yml") or std.mem.endsWith(u8, path, ".yaml");
}

fn outputPathsForOptions(allocator: std.mem.Allocator, options: Options) !OutputPaths {
    const prefix = if (options.out_prefix) |out_prefix|
        try allocator.dupe(u8, out_prefix)
    else blk: {
        if (!std.mem.endsWith(u8, options.readiness_path, ".json")) return error.InvalidSourceReadinessPath;
        const directory = directoryPrefix(options.readiness_path);
        if (std.mem.endsWith(u8, options.readiness_path, source_readiness_suffix)) {
            const suffix_len = source_readiness_suffix.len;
            const candidate = try std.fmt.allocPrint(allocator, "{s}{s}", .{
                options.readiness_path[0 .. options.readiness_path.len - suffix_len],
                output_prefix_suffix,
            });
            if (fileName(candidate).len <= max_default_output_file_name_len) break :blk candidate;
            allocator.free(candidate);
        }

        const digest = shortPathDigest(options.readiness_path);
        break :blk try std.fmt.allocPrint(allocator, "{s}{s}-{s}", .{ directory, compact_output_prefix_name, &digest });
    };
    defer allocator.free(prefix);

    return .{
        .json_path = try std.fmt.allocPrint(allocator, "{s}.json", .{prefix}),
        .text_path = try std.fmt.allocPrint(allocator, "{s}.txt", .{prefix}),
    };
}

fn formatReports(allocator: std.mem.Allocator, input: BoundaryInput) !BoundaryReports {
    var parsed = try std.json.parseFromSlice(RequiredStatusCheckReadinessArtifact, allocator, input.source_readiness_json, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();

    const paths = try outputPathsForOptions(allocator, input.options);
    defer paths.deinit(allocator);

    const result = try evaluateBoundary(
        allocator,
        input.options,
        parsed.value,
        input.branch_protection_after_text,
        input.workflow_after_yml,
    );
    defer result.deinit(allocator);

    const branch_protection_after_digest = if (input.branch_protection_after_text) |text|
        try textDigest(allocator, text)
    else
        try allocator.dupe(u8, "");
    defer allocator.free(branch_protection_after_digest);

    const workflow_after_digest = if (input.workflow_after_yml) |text|
        try textDigest(allocator, text)
    else
        try allocator.dupe(u8, "");
    defer allocator.free(workflow_after_digest);

    const json = try formatBoundaryJson(
        allocator,
        input.options,
        parsed.value,
        branch_protection_after_digest,
        workflow_after_digest,
        result,
        paths,
    );
    errdefer allocator.free(json);
    const text = try formatBoundaryText(
        allocator,
        input.options,
        parsed.value,
        branch_protection_after_digest,
        workflow_after_digest,
        result,
        paths,
    );
    errdefer allocator.free(text);

    return .{ .json = json, .text = text };
}

fn evaluateBoundary(
    allocator: std.mem.Allocator,
    options: Options,
    source: RequiredStatusCheckReadinessArtifact,
    branch_protection_after_text: ?[]const u8,
    workflow_after_yml: ?[]const u8,
) !BoundaryResult {
    var checks = std.ArrayList(BoundaryCheck).empty;
    errdefer checks.deinit(allocator);

    try appendCheck(allocator, &checks, "source-schema", if (std.mem.eql(u8, source.schema, source_readiness_schema) and source.schema_version == 1) .pass else .fail, "source required-status-check readiness schema is supported");
    try appendCheck(allocator, &checks, "source-readiness-ready", if (sourceReadinessReady(source)) .pass else .fail, "source required-status-check readiness is approved ready and ready for next branch");
    try appendCheck(allocator, &checks, "source-decision-approved", if (std.mem.eql(u8, source.decision, "approve")) .pass else .fail, "source readiness reviewer approved handoff");
    try appendCheck(allocator, &checks, "source-required-checks-disabled", if (sourceRequiredProfilesInactive(source)) .pass else .fail, "source required-check profiles remain activation_enabled=false");
    try appendCheck(allocator, &checks, "source-branch-protection-disabled", if (!source.branch_protection_mutation_by_tool_enabled) .pass else .fail, "source does not mutate branch protection");
    try appendCheck(allocator, &checks, "source-github-api-disabled", if (!source.github_api_mutation_enabled and !source.github_check_run_creation_enabled) .pass else .fail, "source does not call GitHub APIs or create check runs");
    try appendCheck(allocator, &checks, "source-ci-execution-disabled", if (sourceCiExecutionDisabled(source)) .pass else .fail, "source keeps CI gate enforcement workflow mutation upload publication summary and comments disabled");
    try appendCheck(allocator, &checks, "source-runtime-and-storage-disabled", if (sourceRuntimeAndStorageDisabled(source)) .pass else .fail, "source keeps live telemetry network runtime durable and NenDB writes disabled");
    try appendCheck(allocator, &checks, "source-catalogs-present", if (sourceCatalogsPresent(source)) .pass else .fail, "source profiles dimensions guardrails denied rules negative fixtures and blocked claims are present");
    try appendCheck(allocator, &checks, "source-verification-recorded", if (sourceVerificationRecorded(source)) .pass else .fail, "source readiness recorded required verification commands");
    try appendCheck(allocator, &checks, "source-checks-pass", if (sourceChecksPassed(source.readiness_checks)) .pass else .fail, "source readiness checks all passed");
    try appendCheck(allocator, &checks, "mutation-authority-none", .pass, "this tool has no mutation authority");

    const selected_profile = selectedProfile(source, options.required_check_profile);
    if (options.mode == .plan) {
        try appendCheck(allocator, &checks, "mode-plan", .pass, "plan mode records a proposal without applying branch protection");
        try appendCheck(allocator, &checks, "selected-profile-known", if (options.required_check_profile == null or selected_profile != null) .pass else .fail, "optional selected required-check profile exists");
        try appendCheck(allocator, &checks, "selected-profile-inactive", if (selected_profile) |profile| if (!profile.activation_enabled) .pass else .fail else .skipped, "selected required-check profile remains inactive");
        try appendCheck(allocator, &checks, "branch-protection-after-safe", if (branch_protection_after_text) |text| branchProtectionAfterSafetyStatus(text) else .skipped, "optional branch-protection after-state is safe");
        try appendCheck(allocator, &checks, "workflow-after-safe", if (workflow_after_yml) |text| workflowAfterSafetyStatus(text) else .skipped, "optional workflow after-state is safe");

        const check_slice = try checks.toOwnedSlice(allocator);
        errdefer allocator.free(check_slice);
        const planned = requiredChecksPassed(check_slice);
        return .{
            .status = if (planned) .planned else .blocked,
            .applied = false,
            .checks = check_slice,
        };
    }

    try appendCheck(allocator, &checks, "mode-record-applied", .pass, "record-applied mode records external reviewed application evidence");
    try appendCheck(allocator, &checks, "required-check-profile-present", if (options.required_check_profile != null) .pass else .fail, "record-applied requires a selected required-check profile");
    try appendCheck(allocator, &checks, "selected-profile-known", if (selected_profile != null) .pass else .fail, "selected required-check profile exists");
    try appendCheck(allocator, &checks, "selected-profile-inactive", if (selected_profile) |profile| if (!profile.activation_enabled) .pass else .fail else .fail, "selected required-check profile remains inactive in source readiness evidence");
    try appendCheck(allocator, &checks, "branch-protection-change-present", if (options.branch_protection_changes.len > 0) .pass else .fail, "record-applied requires reviewed branch-protection change evidence");
    try appendCheck(allocator, &checks, "workflow-or-check-run-change-present", if (options.workflow_changes.len > 0 or options.check_run_changes.len > 0) .pass else .fail, "record-applied requires reviewed workflow or check-run evidence");
    try appendCheck(allocator, &checks, "before-evidence-present", if (options.before_evidence.len > 0) .pass else .fail, "record-applied requires before evidence");
    try appendCheck(allocator, &checks, "after-evidence-present", if (options.after_evidence.len > 0) .pass else .fail, "record-applied requires after evidence");
    try appendCheck(allocator, &checks, "post-verification-recorded", if (verifiedCommandsContainAll(options.verified_commands, required_verification_commands)) .pass else .fail, "record-applied requires every post-application verification command");
    try appendCheck(allocator, &checks, "branch-protection-after-safe", if (branch_protection_after_text) |text| branchProtectionAfterSafetyStatus(text) else .skipped, "branch-protection after-state is safe when provided");
    try appendCheck(allocator, &checks, "workflow-after-safe", if (workflow_after_yml) |text| workflowAfterSafetyStatus(text) else .skipped, "workflow after-state is safe when provided");

    const check_slice = try checks.toOwnedSlice(allocator);
    errdefer allocator.free(check_slice);
    const applied = requiredChecksPassed(check_slice);
    return .{
        .status = if (applied) .applied else .blocked,
        .applied = applied,
        .checks = check_slice,
    };
}

fn appendCheck(
    allocator: std.mem.Allocator,
    checks: *std.ArrayList(BoundaryCheck),
    name: []const u8,
    status: CheckStatus,
    detail: []const u8,
) !void {
    try checks.append(allocator, .{ .name = name, .status = status, .detail = detail });
}

fn requiredChecksPassed(checks: []const BoundaryCheck) bool {
    for (checks) |check| {
        if (check.status == .fail) return false;
    }
    return true;
}

fn sourceReadinessReady(source: RequiredStatusCheckReadinessArtifact) bool {
    return std.mem.eql(u8, source.required_status_check_readiness_status, "ready") and
        source.ready_for_next_branch and
        std.mem.eql(u8, source.decision, "approve") and
        std.mem.eql(u8, source.mutation_authority, "none");
}

fn sourceRequiredProfilesInactive(source: RequiredStatusCheckReadinessArtifact) bool {
    if (source.required_status_check_profiles.len == 0) return false;
    for (source.required_status_check_profiles) |profile| {
        if (profile.activation_enabled) return false;
    }
    return true;
}

fn sourceCiExecutionDisabled(source: RequiredStatusCheckReadinessArtifact) bool {
    return !source.ci_gate_enabled and
        !source.ci_gate_enforcement_enabled and
        !source.ci_required_status_check_enabled and
        !source.ci_workflow_mutation_enabled and
        !source.ci_upload_execution_enabled and
        !source.ci_report_publication_enabled and
        !source.github_step_summary_write_enabled and
        !source.pull_request_comment_enabled;
}

fn sourceRuntimeAndStorageDisabled(source: RequiredStatusCheckReadinessArtifact) bool {
    return !source.production_telemetry_ingestion and
        !source.live_exporter_enabled and
        !source.network_send_enabled and
        !source.collector_endpoint_configured and
        !source.otlp_serialization_enabled and
        !source.runtime_pipeline_enabled and
        !source.durable_write_enabled and
        !source.nendb_write_enabled;
}

fn sourceCatalogsPresent(source: RequiredStatusCheckReadinessArtifact) bool {
    return source.required_status_check_profiles.len >= 3 and
        source.readiness_dimensions.len > 0 and
        source.activation_guardrails.len > 0 and
        source.denied_inference_rules.len > 0 and
        source.negative_fixtures.len > 0 and
        source.blocked_claims.len > 0;
}

fn sourceVerificationRecorded(source: RequiredStatusCheckReadinessArtifact) bool {
    return source.required_verification_commands.len > 0 and
        verifiedCommandsContainAll(source.verified_commands, source.required_verification_commands) and
        verifiedCommandsContainAll(source.verified_commands, &.{
            "zig build release-gate --summary none",
            "zig build release-gate-report",
        });
}

fn sourceChecksPassed(checks: []const SourceReadinessCheck) bool {
    if (checks.len == 0) return false;
    for (checks) |check| {
        if (!std.mem.eql(u8, check.status, "pass")) return false;
    }
    return true;
}

fn selectedProfile(source: RequiredStatusCheckReadinessArtifact, profile_id: ?[]const u8) ?SourceRequiredStatusCheckProfile {
    const id = profile_id orelse return null;
    for (source.required_status_check_profiles) |profile| {
        if (std.mem.eql(u8, profile.id, id)) return profile;
    }
    return null;
}

fn branchProtectionAfterSafetyStatus(content: []const u8) CheckStatus {
    if (!containsAll(content, &.{ "required", "status", "check", "branch" })) return .fail;
    if (containsAny(content, prohibited_branch_protection_after_markers)) return .fail;
    return .pass;
}

fn workflowAfterSafetyStatus(content: []const u8) CheckStatus {
    if (!containsAll(content, &.{ "zigeffect", "causal" })) return .fail;
    if (!containsAny(content, &.{ "release-gate", "required" })) return .fail;
    if (containsAny(content, prohibited_workflow_after_markers)) return .fail;
    return .pass;
}

const prohibited_branch_protection_after_markers: []const []const u8 = &.{
    "ghp_",
    "github_pat_",
    "secret",
    "token",
    "otlp endpoint",
    "deployment success",
    "production health",
    "production cluster ready",
    "durable write enabled",
    "nendb write enabled",
    "mutation_authority=granted",
    "\"mutation_authority\": \"granted\"",
};

const prohibited_workflow_after_markers: []const []const u8 = &.{
    "workflow mutated by tool",
    "github api mutation enabled",
    "create check run",
    "upload-artifact",
    "GITHUB_STEP_SUMMARY",
    "pull_request_comment",
    "otlp endpoint",
    "network send enabled",
    "durable write enabled",
    "nendb write enabled",
    "react renderer enabled",
    "mutation_authority=granted",
    "\"mutation_authority\": \"granted\"",
};

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

fn formatBoundaryJson(
    allocator: std.mem.Allocator,
    options: Options,
    source: RequiredStatusCheckReadinessArtifact,
    branch_protection_after_digest: []const u8,
    workflow_after_digest: []const u8,
    result: BoundaryResult,
    paths: OutputPaths,
) ![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "{\n");
    try appendJsonField(allocator, &output, "schema", production_telemetry_ci_gate_required_status_check_application_boundary_schema, true);
    try output.appendSlice(allocator, "  \"schema_version\": 1,\n");
    try appendJsonField(allocator, &output, "generated_by", generated_by, true);
    try appendJsonField(allocator, &output, "source_readiness", options.readiness_path, true);
    try appendJsonField(allocator, &output, "source_readiness_status", source.required_status_check_readiness_status, true);
    try appendJsonField(allocator, &output, "source_decision", source.decision, true);
    try output.print(allocator, "  \"source_ready_for_next_branch\": {},\n", .{source.ready_for_next_branch});
    try appendJsonField(allocator, &output, "source_mutation_authority", source.mutation_authority, true);
    try appendJsonField(allocator, &output, "source_after_report_digest", source.source_after_report_digest, true);
    try appendJsonField(allocator, &output, "mode", modeText(options.mode), true);
    try appendJsonField(allocator, &output, "required_status_check_application_status", statusText(result.status), true);
    try output.print(allocator, "  \"applied\": {},\n", .{result.applied});
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
    try appendJsonField(allocator, &output, "reviewed_by", options.reviewed_by, true);
    try appendJsonField(allocator, &output, "policy", options.policy, true);
    try appendJsonField(allocator, &output, "reason", options.reason, true);
    try output.appendSlice(allocator, "  \"required_check_profile\": ");
    try appendOptionalJsonString(allocator, &output, options.required_check_profile);
    try output.appendSlice(allocator, ",\n  \"branch_protection_changes\": ");
    try appendStringArray(allocator, &output, options.branch_protection_changes);
    try output.appendSlice(allocator, ",\n  \"workflow_changes\": ");
    try appendStringArray(allocator, &output, options.workflow_changes);
    try output.appendSlice(allocator, ",\n  \"check_run_changes\": ");
    try appendStringArray(allocator, &output, options.check_run_changes);
    try output.appendSlice(allocator, ",\n  \"before_evidence\": ");
    try appendStringArray(allocator, &output, options.before_evidence);
    try output.appendSlice(allocator, ",\n  \"after_evidence\": ");
    try appendStringArray(allocator, &output, options.after_evidence);
    try output.appendSlice(allocator, ",\n  \"branch_protection_after_path\": ");
    try appendOptionalJsonString(allocator, &output, options.branch_protection_after_path);
    try output.appendSlice(allocator, ",\n");
    try appendJsonField(allocator, &output, "branch_protection_after_digest", branch_protection_after_digest, true);
    try output.appendSlice(allocator, "  \"workflow_after_path\": ");
    try appendOptionalJsonString(allocator, &output, options.workflow_after_path);
    try output.appendSlice(allocator, ",\n");
    try appendJsonField(allocator, &output, "workflow_after_digest", workflow_after_digest, true);
    try output.appendSlice(allocator, "  \"application_checks\": ");
    try appendChecksJson(allocator, &output, result.checks);
    try output.appendSlice(allocator, ",\n  \"source_required_status_check_profiles\": ");
    try appendSourceProfilesJson(allocator, &output, source.required_status_check_profiles);
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

fn formatBoundaryText(
    allocator: std.mem.Allocator,
    options: Options,
    source: RequiredStatusCheckReadinessArtifact,
    branch_protection_after_digest: []const u8,
    workflow_after_digest: []const u8,
    result: BoundaryResult,
    paths: OutputPaths,
) ![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "zigeffect production telemetry CI gate required status check application boundary\n");
    try output.print(allocator, "schema: {s}\n", .{production_telemetry_ci_gate_required_status_check_application_boundary_schema});
    try output.print(allocator, "source readiness: {s}\n", .{options.readiness_path});
    try output.print(allocator, "source readiness status: {s}\n", .{source.required_status_check_readiness_status});
    try output.print(allocator, "source decision: {s}\n", .{source.decision});
    try output.print(allocator, "source ready for next branch: {}\n", .{source.ready_for_next_branch});
    try output.print(allocator, "source mutation authority: {s}\n", .{source.mutation_authority});
    try output.print(allocator, "source after report digest: {s}\n", .{source.source_after_report_digest});
    try output.print(allocator, "mode: {s}\n", .{modeText(options.mode)});
    try output.print(allocator, "required status check application status: {s}\n", .{statusText(result.status)});
    try output.print(allocator, "applied: {}\n", .{result.applied});
    try output.print(allocator, "mutation_authority: {s}\n", .{mutation_authority});
    try output.print(allocator, "ci gate enforcement enabled: {}\n", .{ci_gate_enforcement_enabled});
    try output.print(allocator, "ci required status check enabled: {}\n", .{ci_required_status_check_enabled});
    try output.print(allocator, "github api mutation enabled: {}\n", .{github_api_mutation_enabled});
    try output.print(allocator, "github check run creation enabled: {}\n", .{github_check_run_creation_enabled});
    try output.print(allocator, "branch protection mutation by tool enabled: {}\n", .{branch_protection_mutation_by_tool_enabled});
    try output.print(allocator, "reviewed_by: {s}\n", .{options.reviewed_by});
    try output.print(allocator, "policy: {s}\n", .{options.policy});
    try output.print(allocator, "reason: {s}\n", .{options.reason});
    try output.print(allocator, "required check profile: {s}\n", .{options.required_check_profile orelse "none"});
    try output.print(allocator, "branch protection after digest: {s}\n", .{branch_protection_after_digest});
    try output.print(allocator, "workflow after digest: {s}\n", .{workflow_after_digest});
    try output.print(allocator, "source branch: {s}\n", .{source_branch});
    try output.print(allocator, "recommendation: {s}\n", .{recommendation});
    try output.print(allocator, "next branch if ready: {s}\n", .{next_branch_if_ready});
    try output.print(allocator, "json output: {s}\n", .{paths.json_path});
    try output.print(allocator, "text output: {s}\n\n", .{paths.text_path});

    try output.appendSlice(allocator, "application checks:\n");
    for (result.checks) |check| {
        try output.print(allocator, "- {s}: {s} - {s}\n", .{ check.name, checkStatusText(check.status), check.detail });
    }
    try output.append(allocator, '\n');

    try appendTextList(allocator, &output, "branch protection changes", options.branch_protection_changes);
    try appendTextList(allocator, &output, "workflow changes", options.workflow_changes);
    try appendTextList(allocator, &output, "check run changes", options.check_run_changes);
    try appendTextList(allocator, &output, "before evidence", options.before_evidence);
    try appendTextList(allocator, &output, "after evidence", options.after_evidence);
    try appendSourceProfilesText(allocator, &output, source.required_status_check_profiles);
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

fn appendOptionalJsonString(allocator: std.mem.Allocator, output: *std.ArrayList(u8), value: ?[]const u8) !void {
    if (value) |actual| {
        try appendJsonString(allocator, output, actual);
    } else {
        try output.appendSlice(allocator, "null");
    }
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

fn appendSourceProfilesJson(allocator: std.mem.Allocator, output: *std.ArrayList(u8), profiles: []const SourceRequiredStatusCheckProfile) !void {
    try output.append(allocator, '[');
    for (profiles, 0..) |profile, index| {
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

fn appendSourceProfilesText(allocator: std.mem.Allocator, output: *std.ArrayList(u8), profiles: []const SourceRequiredStatusCheckProfile) !void {
    try output.appendSlice(allocator, "source required status check profiles:\n");
    if (profiles.len == 0) {
        try output.appendSlice(allocator, "- none\n\n");
        return;
    }
    for (profiles) |profile| {
        try output.print(allocator, "- {s}: activation_enabled={}, denied={s}\n", .{ profile.id, profile.activation_enabled, profile.denied_claim });
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

fn agentGuidance(status: RequiredStatusCheckApplicationStatus) []const []const u8 {
    return switch (status) {
        .planned => &.{
            "Use planned required-status-check application-boundary artifacts to prepare policy work only.",
            "Plan mode does not apply branch protection or create required checks.",
            "Do not infer GitHub mutation workflow mutation check-run creation live telemetry durable writes NenDB writes production health cluster readiness or mutation authority.",
        },
        .applied => &.{
            "Use applied required-status-check application-boundary artifacts as reviewed evidence for policy definition only.",
            "Applied records describe external reviewed state; this tool still did not mutate GitHub or workflows.",
            "Do not infer production health cluster readiness durable writes NenDB writes alternate renderer scope or mutation authority.",
        },
        .blocked => &.{
            "Treat blocked required-status-check application-boundary artifacts as a stop sign.",
            "Repair source readiness selected profile change evidence before after evidence after-state safety or verification commands before continuing.",
            "Do not start required-status-check policy work from blocked application-boundary evidence.",
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

fn textDigest(allocator: std.mem.Allocator, text: []const u8) ![]const u8 {
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(text, &digest, .{});

    var hex_digest: [64]u8 = undefined;
    const hex = "0123456789abcdef";
    for (digest, 0..) |byte, index| {
        hex_digest[index * 2] = hex[@intCast(byte >> 4)];
        hex_digest[index * 2 + 1] = hex[@intCast(byte & 0x0f)];
    }
    return std.fmt.allocPrint(allocator, "sha256:{s}", .{hex_digest[0..]});
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
    const source_readiness_json = try readRequiredArtifact(init.io, allocator, options.readiness_path, error.MissingReadinessInput);
    defer allocator.free(source_readiness_json);

    const branch_protection_after_text = if (options.branch_protection_after_path) |path|
        try readRequiredArtifact(init.io, allocator, path, error.MissingBranchProtectionAfterInput)
    else
        null;
    defer if (branch_protection_after_text) |text| allocator.free(text);

    const workflow_after_yml = if (options.workflow_after_path) |path|
        try readRequiredArtifact(init.io, allocator, path, error.MissingWorkflowAfterInput)
    else
        null;
    defer if (workflow_after_yml) |text| allocator.free(text);

    const reports = try formatReports(allocator, .{
        .options = options,
        .source_readiness_json = source_readiness_json,
        .branch_protection_after_text = branch_protection_after_text,
        .workflow_after_yml = workflow_after_yml,
    });
    defer reports.deinit(allocator);

    const paths = try outputPathsForOptions(allocator, options);
    defer paths.deinit(allocator);

    try writeArtifact(init.io, paths.json_path, reports.json);
    try writeArtifact(init.io, paths.text_path, reports.text);
    std.debug.print("{s}", .{reports.text});
}

fn usage() []const u8 {
    return "usage: zig build causal-production-telemetry-ci-gate-required-status-check-application-boundary -- --from-readiness <required-status-check-readiness.json> plan|record-applied --reason <reason> [--by <actor>] [--policy <policy>] [--required-check-profile <profile-id>] [--branch-protection-change <evidence>]... [--workflow-change <path-or-evidence>]... [--check-run-change <evidence>]... [--before <evidence>]... [--after <evidence>]... [--branch-protection-after <branch-protection.json|branch-protection.md|branch-protection.txt>] [--workflow-after <workflow.yml|workflow.yaml>] [--verified-command <command>]... [--out-prefix <path-prefix>]\n";
}

fn failUsage(err: anyerror) noreturn {
    std.debug.print("causal-production-telemetry-ci-gate-required-status-check-application-boundary error: {s}\n{s}", .{ @errorName(err), usage() });
    std.process.exit(2);
}

fn freeSliceOnly(allocator: std.mem.Allocator, values: []const []const u8) void {
    if (values.len > 0) allocator.free(values);
}

fn contains(haystack: []const u8, needle: []const u8) bool {
    return std.mem.indexOf(u8, haystack, needle) != null;
}

fn containsAny(haystack: []const u8, needles: []const []const u8) bool {
    for (needles) |needle| {
        if (contains(haystack, needle)) return true;
    }
    return false;
}

fn containsAll(haystack: []const u8, needles: []const []const u8) bool {
    for (needles) |needle| {
        if (!contains(haystack, needle)) return false;
    }
    return true;
}

test "ci gate required status check application boundary schema and branch constants are stable" {
    try std.testing.expectEqualStrings("zigeffect.causal.production-telemetry-ci-gate-required-status-check-application-boundary.v1", production_telemetry_ci_gate_required_status_check_application_boundary_schema);
    try std.testing.expectEqual(@as(u32, 1), production_telemetry_ci_gate_required_status_check_application_boundary_schema_version);
    try std.testing.expectEqualStrings("codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-application-boundary", source_branch);
    try std.testing.expectEqualStrings("start-production-telemetry-ci-gate-required-status-check-policy", recommendation);
    try std.testing.expectEqualStrings("codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-policy", next_branch_if_ready);
}

test "parses required status check application boundary plan and record-applied options" {
    const plan_args = &.{
        "tool",
        "--from-readiness",
        "required-status-check-readiness.json",
        "plan",
        "--reason",
        "planning boundary",
    };
    const plan_options = try parseOptions(std.testing.allocator, plan_args);
    defer plan_options.deinit(std.testing.allocator);
    try std.testing.expectEqual(Mode.plan, plan_options.mode);
    try std.testing.expectEqualStrings("required-status-check-application-boundary-reviewer", plan_options.reviewed_by);
    try std.testing.expectEqualStrings("manual-production-telemetry-ci-gate-required-status-check-application-boundary", plan_options.policy);

    const applied_args = &.{
        "tool",
        "--from-readiness",
        "required-status-check-readiness.json",
        "record-applied",
        "--reason",
        "recorded external application",
        "--by",
        "reviewer",
        "--policy",
        "policy-1",
        "--required-check-profile",
        "zigeffect-causal-release-gate-report",
        "--branch-protection-change",
        "branch protection required zigeffect check",
        "--workflow-change",
        ".github/workflows/zigeffect-causal.yml",
        "--check-run-change",
        "required check configured externally",
        "--before",
        "before digest",
        "--after",
        "after digest",
        "--branch-protection-after",
        "branch-protection.json",
        "--workflow-after",
        "workflow.yml",
        "--verified-command",
        "zig build test",
        "--out-prefix",
        ".zig-cache/required-status-check-application-boundary",
    };
    const applied_options = try parseOptions(std.testing.allocator, applied_args);
    defer applied_options.deinit(std.testing.allocator);
    try std.testing.expectEqual(Mode.record_applied, applied_options.mode);
    try std.testing.expectEqualStrings("reviewer", applied_options.reviewed_by);
    try std.testing.expectEqualStrings("policy-1", applied_options.policy);
    try std.testing.expectEqualStrings("zigeffect-causal-release-gate-report", applied_options.required_check_profile.?);
    try std.testing.expectEqual(@as(usize, 1), applied_options.branch_protection_changes.len);
    try std.testing.expectEqual(@as(usize, 1), applied_options.workflow_changes.len);
    try std.testing.expectEqual(@as(usize, 1), applied_options.check_run_changes.len);
    try std.testing.expectEqual(@as(usize, 1), applied_options.before_evidence.len);
    try std.testing.expectEqual(@as(usize, 1), applied_options.after_evidence.len);
    try std.testing.expectEqualStrings("branch-protection.json", applied_options.branch_protection_after_path.?);
    try std.testing.expectEqualStrings("workflow.yml", applied_options.workflow_after_path.?);
    try std.testing.expectEqualStrings(".zig-cache/required-status-check-application-boundary", applied_options.out_prefix.?);

    try std.testing.expectError(error.UnknownMode, parseOptions(std.testing.allocator, &.{ "tool", "--from-readiness", "x.json", "apply", "--reason", "x" }));
    try std.testing.expectError(error.MissingReason, parseOptions(std.testing.allocator, &.{ "tool", "--from-readiness", "x.json", "plan" }));
    try std.testing.expectError(error.InvalidBranchProtectionAfterPath, parseOptions(std.testing.allocator, &.{ "tool", "--from-readiness", "x.json", "plan", "--reason", "x", "--branch-protection-after", "x.yml" }));
    try std.testing.expectError(error.InvalidWorkflowAfterPath, parseOptions(std.testing.allocator, &.{ "tool", "--from-readiness", "x.json", "plan", "--reason", "x", "--workflow-after", "x.txt" }));
}

test "plan and record-applied reports preserve guarded required status check authority" {
    const plan_options = Options{
        .readiness_path = "required-status-check-readiness.json",
        .mode = .plan,
        .reason = "plan boundary",
        .out_prefix = ".zig-cache/required-status-check-application-boundary",
    };
    const plan_reports = try formatReports(std.testing.allocator, .{
        .options = plan_options,
        .source_readiness_json = readyReadinessJson(),
    });
    defer plan_reports.deinit(std.testing.allocator);
    try std.testing.expect(contains(plan_reports.json, "\"required_status_check_application_status\": \"planned\""));
    try std.testing.expect(contains(plan_reports.json, "\"applied\": false"));
    try std.testing.expect(contains(plan_reports.json, "\"mutation_authority\": \"none\""));
    try std.testing.expect(contains(plan_reports.json, "\"branch_protection_mutation_by_tool_enabled\": false"));
    try std.testing.expect(contains(plan_reports.text, "required status check application status: planned"));

    const applied_options = Options{
        .readiness_path = "required-status-check-readiness.json",
        .mode = .record_applied,
        .reason = "record external application",
        .required_check_profile = "zigeffect-causal-release-gate-report",
        .branch_protection_changes = &.{"reviewed branch protection required zigeffect status check"},
        .workflow_changes = &.{"reviewed workflow changed externally"},
        .before_evidence = &.{"before branch protection digest"},
        .after_evidence = &.{"after branch protection digest"},
        .verified_commands = required_verification_commands,
        .out_prefix = ".zig-cache/required-status-check-application-boundary-applied",
    };
    const applied_reports = try formatReports(std.testing.allocator, .{
        .options = applied_options,
        .source_readiness_json = readyReadinessJson(),
        .branch_protection_after_text = "branch protection required status check zigeffect-causal-release-gate-report",
        .workflow_after_yml = "name: zigeffect causal\njobs:\n  release-gate:\n    steps:\n      - run: zig build release-gate --summary none\n      - run: echo required status check\n",
    });
    defer applied_reports.deinit(std.testing.allocator);
    try std.testing.expect(contains(applied_reports.json, "\"required_status_check_application_status\": \"applied\""));
    try std.testing.expect(contains(applied_reports.json, "\"applied\": true"));
    try std.testing.expect(contains(applied_reports.json, "\"github_api_mutation_enabled\": false"));
    try std.testing.expect(contains(applied_reports.json, "\"next_branch_if_ready\": \"codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-policy\""));
    try std.testing.expect(contains(applied_reports.text, "required status check application status: applied"));
    try std.testing.expect(contains(applied_reports.text, "applied: true"));
}

test "blocked sources missing evidence and unsafe after-state block application" {
    const blocked_plan_options = Options{
        .readiness_path = "required-status-check-readiness-negative.json",
        .mode = .plan,
        .reason = "blocked source",
        .out_prefix = ".zig-cache/required-status-check-application-boundary-blocked",
    };
    const blocked_plan = try formatReports(std.testing.allocator, .{
        .options = blocked_plan_options,
        .source_readiness_json = blockedReadinessJson(),
    });
    defer blocked_plan.deinit(std.testing.allocator);
    try std.testing.expect(contains(blocked_plan.json, "\"required_status_check_application_status\": \"blocked\""));
    try std.testing.expect(contains(blocked_plan.json, "\"applied\": false"));

    const missing_evidence_options = Options{
        .readiness_path = "required-status-check-readiness.json",
        .mode = .record_applied,
        .reason = "missing evidence",
        .required_check_profile = "zigeffect-causal-release-gate-report",
        .verified_commands = required_verification_commands,
        .out_prefix = ".zig-cache/required-status-check-application-boundary-missing",
    };
    const missing_evidence = try formatReports(std.testing.allocator, .{
        .options = missing_evidence_options,
        .source_readiness_json = readyReadinessJson(),
    });
    defer missing_evidence.deinit(std.testing.allocator);
    try std.testing.expect(contains(missing_evidence.json, "\"required_status_check_application_status\": \"blocked\""));
    try std.testing.expect(contains(missing_evidence.json, "\"branch-protection-change-present\", \"status\": \"fail\""));

    const unsafe_options = Options{
        .readiness_path = "required-status-check-readiness.json",
        .mode = .record_applied,
        .reason = "unsafe after state",
        .required_check_profile = "zigeffect-causal-release-gate-report",
        .branch_protection_changes = &.{"branch protection change"},
        .workflow_changes = &.{"workflow change"},
        .before_evidence = &.{"before"},
        .after_evidence = &.{"after"},
        .verified_commands = required_verification_commands,
        .out_prefix = ".zig-cache/required-status-check-application-boundary-unsafe",
    };
    const unsafe = try formatReports(std.testing.allocator, .{
        .options = unsafe_options,
        .source_readiness_json = readyReadinessJson(),
        .branch_protection_after_text = "branch required status check github_pat_secret",
        .workflow_after_yml = "name: zigeffect causal\nrelease-gate required upload-artifact\n",
    });
    defer unsafe.deinit(std.testing.allocator);
    try std.testing.expect(contains(unsafe.json, "\"required_status_check_application_status\": \"blocked\""));
    try std.testing.expect(contains(unsafe.json, "\"branch-protection-after-safe\", \"status\": \"fail\""));
    try std.testing.expect(contains(unsafe.json, "\"workflow-after-safe\", \"status\": \"fail\""));
    try std.testing.expect(contains(unsafe.text, "Treat blocked required-status-check application-boundary artifacts as a stop sign."));
}

fn readyReadinessJson() []const u8 {
    return
    \\{
    \\  "schema": "zigeffect.causal.production-telemetry-ci-gate-required-status-check-readiness.v1",
    \\  "schema_version": 1,
    \\  "generated_by": "causal-production-telemetry-ci-gate-required-status-check-readiness",
    \\  "source_branch": "codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-readiness",
    \\  "recommendation": "start-production-telemetry-ci-gate-required-status-check-application-boundary",
    \\  "next_branch_if_ready": "codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-application-boundary",
    \\  "source_publication_policy": "publication-policy.json",
    \\  "source_publication_policy_status": "ready",
    \\  "source_policy_decision": "approve",
    \\  "source_mutation_authority": "none",
    \\  "source_after_report_digest": "sha256:1234",
    \\  "decision": "approve",
    \\  "required_status_check_readiness_status": "ready",
    \\  "ready_for_next_branch": true,
    \\  "reviewed_by": "reviewer",
    \\  "policy": "policy",
    \\  "reason": "reason",
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
    \\  "readiness_checks": [
    \\    { "name": "source-schema", "status": "pass", "detail": "ok" },
    \\    { "name": "source-policy-ready", "status": "pass", "detail": "ok" },
    \\    { "name": "source-required-status-check-disabled", "status": "pass", "detail": "ok" }
    \\  ],
    \\  "required_status_check_profiles": [
    \\    { "id": "zigeffect-causal-telemetry-advisory-report", "activation_enabled": false, "source": "report", "intended_future_signal": "advisory", "denied_claim": "merge blocking" },
    \\    { "id": "zigeffect-causal-release-gate-report", "activation_enabled": false, "source": "release gate", "intended_future_signal": "release gate", "denied_claim": "deployment success" },
    \\    { "id": "zigeffect-causal-required-check-contract", "activation_enabled": false, "source": "contract", "intended_future_signal": "contract", "denied_claim": "branch protection updated" }
    \\  ],
    \\  "readiness_dimensions": [{ "id": "source-publication-policy-ready", "required": true, "evidence": "ready" }],
    \\  "activation_guardrails": [{ "id": "stable-check-names", "required_before_application": true, "reason": "stable" }],
    \\  "denied_inference_rules": ["required-status-check-active"],
    \\  "negative_fixtures": [{ "id": "required-status-check-active-denied", "artifact_state": "active", "decision": "deny", "failed_gate": "required-status-check-active", "reason": "denied" }],
    \\  "blocked_claims": ["required-status-check-active", "github-api-mutation"],
    \\  "required_verification_commands": [
    \\    "zig build causal-production-telemetry-ci-gate-advisory-ci-report-publication-policy",
    \\    "zig build causal-artifacts",
    \\    "zig build release-gate --summary none",
    \\    "zig build release-gate-report",
    \\    "zig build causal-schema-governance -- --format json",
    \\    "zig build causal-production-hardening-backlog -- --format json",
    \\    "zig build examples",
    \\    "zig build test"
    \\  ],
    \\  "verified_commands": [
    \\    "zig build causal-production-telemetry-ci-gate-advisory-ci-report-publication-policy",
    \\    "zig build causal-artifacts",
    \\    "zig build release-gate --summary none",
    \\    "zig build release-gate-report",
    \\    "zig build causal-schema-governance -- --format json",
    \\    "zig build causal-production-hardening-backlog -- --format json",
    \\    "zig build examples",
    \\    "zig build test"
    \\  ]
    \\}
    ;
}

fn blockedReadinessJson() []const u8 {
    return
    \\{
    \\  "schema": "zigeffect.causal.production-telemetry-ci-gate-required-status-check-readiness.v1",
    \\  "schema_version": 1,
    \\  "decision": "reject",
    \\  "required_status_check_readiness_status": "blocked",
    \\  "ready_for_next_branch": false,
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
    \\  "readiness_checks": [{ "name": "source-policy-ready", "status": "fail", "detail": "blocked" }],
    \\  "required_status_check_profiles": [
    \\    { "id": "zigeffect-causal-release-gate-report", "activation_enabled": false, "source": "release gate", "intended_future_signal": "release gate", "denied_claim": "deployment success" },
    \\    { "id": "zigeffect-causal-telemetry-advisory-report", "activation_enabled": false, "source": "report", "intended_future_signal": "advisory", "denied_claim": "merge blocking" },
    \\    { "id": "zigeffect-causal-required-check-contract", "activation_enabled": false, "source": "contract", "intended_future_signal": "contract", "denied_claim": "branch protection updated" }
    \\  ],
    \\  "readiness_dimensions": [{ "id": "source-publication-policy-ready", "required": true, "evidence": "ready" }],
    \\  "activation_guardrails": [{ "id": "stable-check-names", "required_before_application": true, "reason": "stable" }],
    \\  "denied_inference_rules": ["required-status-check-active"],
    \\  "negative_fixtures": [{ "id": "required-status-check-active-denied", "artifact_state": "active", "decision": "deny", "failed_gate": "required-status-check-active", "reason": "denied" }],
    \\  "blocked_claims": ["required-status-check-active"],
    \\  "required_verification_commands": ["zig build release-gate --summary none", "zig build release-gate-report"],
    \\  "verified_commands": []
    \\}
    ;
}
