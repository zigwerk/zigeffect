const std = @import("std");

pub const production_telemetry_ci_archive_application_schema = "zigeffect.causal.production-telemetry-ci-archive-application.v1";
pub const production_telemetry_ci_archive_application_schema_version: u32 = 1;
pub const source_branch = "codex/zigeffect-causal-production-telemetry-ci-archive-application";
pub const recommendation = "start-production-telemetry-ci-archive-evidence-policy";
pub const next_branch_if_applied = "codex/zigeffect-causal-production-telemetry-ci-archive-evidence-policy";

const required_verification_commands: []const []const u8 = &.{
    "zig build causal-production-telemetry-ci-harness-boundary",
    "zig build causal-artifacts",
    "zig build release-gate --summary none",
    "zig build causal-schema-governance -- --format json",
    "zig build causal-production-hardening-backlog -- --format json",
    "zig build examples",
    "zig build test",
};

const ci_harness_boundary_schema = "zigeffect.causal.production-telemetry-ci-harness-boundary.v1";
const generated_by = "causal-production-telemetry-ci-archive-application";
const ci_archive_application_enabled = true;
const ci_upload_execution_enabled = false;
const ci_workflow_mutation_enabled = false;
const ci_gate_enabled = false;
const production_telemetry_ingestion = false;
const live_exporter_enabled = false;
const network_send_enabled = false;
const collector_endpoint_configured = false;
const otlp_serialization_enabled = false;
const runtime_pipeline_enabled = false;
const durable_write_enabled = false;
const nendb_write_enabled = false;

const Mode = enum { plan, record_applied };
const ApplicationStatus = enum { planned, applied, blocked };
const CheckStatus = enum { pass, fail, skipped };

const Options = struct {
    harness_path: []const u8,
    mode: Mode,
    reviewed_by: []const u8 = "ci-archive-application-reviewer",
    policy: []const u8 = "manual-production-telemetry-ci-archive-application",
    reason: []const u8,
    workflow_after_path: ?[]const u8 = null,
    workflow_changes: []const []const u8 = &.{},
    before_evidence: []const []const u8 = &.{},
    after_evidence: []const []const u8 = &.{},
    verified_commands: []const []const u8 = &.{},
    out_prefix: ?[]const u8 = null,

    fn deinit(self: Options, allocator: std.mem.Allocator) void {
        freeSliceOnly(allocator, self.workflow_changes);
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

const ApplicationInput = struct {
    options: Options,
    source_harness_json: []const u8,
    workflow_after_yml: ?[]const u8 = null,
};

const ApplicationReports = struct {
    json: []const u8,
    text: []const u8,

    fn deinit(self: ApplicationReports, allocator: std.mem.Allocator) void {
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

const ArtifactUploadPolicy = struct {
    mode: []const u8 = "",
    failure_only: bool = false,
    retention_days: u32 = 0,
    allowed_extensions: []const []const u8 = &.{},
    public_upload_claim: bool = true,
    ci_gate_claim: bool = true,
};

const ArtifactCandidate = struct {
    id: []const u8 = "",
    path: []const u8 = "",
    extension: []const u8 = "",
    failure_only: bool = false,
    redaction_required: bool = false,
    public_upload_allowed: bool = true,
};

const CiHarnessBoundaryArtifact = struct {
    schema: []const u8,
    schema_version: u32,
    source_ci_artifact_preview: []const u8 = "",
    source_workbench_preview: []const u8 = "",
    source_retention: []const u8 = "",
    source_local_pipeline: []const u8 = "",
    source_boundary: []const u8 = "",
    source_proposal: []const u8 = "",
    source_readiness: []const u8 = "",
    source_fixtures: []const u8 = "",
    workflow_path: []const u8 = "",
    workflow_digest: []const u8 = "",
    decision: []const u8,
    ci_harness_boundary_status: []const u8,
    ready_for_next_branch: bool,
    applied: bool,
    mutation_authority: []const u8,
    production_telemetry_ingestion: bool,
    live_exporter_enabled: bool,
    network_send_enabled: bool,
    collector_endpoint_configured: bool,
    otlp_serialization_enabled: bool,
    runtime_pipeline_enabled: bool,
    durable_write_enabled: bool,
    nendb_write_enabled: bool,
    ci_upload_enabled: bool,
    ci_upload_execution_enabled: bool,
    ci_workflow_mutation_enabled: bool,
    ci_gate_enabled: bool,
    ci_harness_boundary_enabled: bool,
    source_preview_checks: []const SourceCheck = &.{},
    workflow_required_features: []const SourceCheck = &.{},
    workflow_prohibited_features: []const SourceCheck = &.{},
    artifact_upload_policy: ArtifactUploadPolicy = .{},
    artifact_candidates: []const ArtifactCandidate = &.{},
    cluster_release_gate_assumptions: []const []const u8 = &.{},
    checks: []const SourceCheck = &.{},
    blocked_claims: []const []const u8 = &.{},
    required_verification_commands: []const []const u8 = &.{},
    verified_commands: []const []const u8 = &.{},
};

const ApplicationCheck = struct {
    name: []const u8,
    status: CheckStatus,
    detail: []const u8,
};

const ApplicationResult = struct {
    status: ApplicationStatus,
    applied: bool,
    mutation_authority: []const u8,
    checks: []const ApplicationCheck,

    fn deinit(self: ApplicationResult, allocator: std.mem.Allocator) void {
        if (self.checks.len > 0) allocator.free(self.checks);
    }
};

const WorkflowTextCheck = struct {
    id: []const u8,
    needle: []const u8,
    detail: []const u8,
};

const required_workflow_features: []const WorkflowTextCheck = &.{
    .{ .id = "workflow-name", .needle = "name: zigeffect causal", .detail = "causal workflow is named" },
    .{ .id = "pull-request-trigger", .needle = "pull_request:", .detail = "pull request trigger exists" },
    .{ .id = "push-master-trigger", .needle = "- master", .detail = "push trigger targets master" },
    .{ .id = "workflow-dispatch-trigger", .needle = "workflow_dispatch:", .detail = "manual dispatch trigger exists" },
    .{ .id = "permissions-read", .needle = "contents: read", .detail = "workflow permissions are read-only" },
    .{ .id = "checkout-v4", .needle = "actions/checkout@v4", .detail = "workflow checks out source" },
    .{ .id = "setup-zig", .needle = "mlugg/setup-zig@v2.2.1", .detail = "workflow installs Zig" },
    .{ .id = "zig-016", .needle = "version: 0.16.0", .detail = "workflow uses Zig 0.16.0" },
    .{ .id = "base-causal-test", .needle = "zig build causal-test", .detail = "PR baseline runs causal-test" },
    .{ .id = "base-dev-loop-baseline", .needle = "zig build causal-dev-loop -- baseline package-tests", .detail = "PR baseline writes package-test baseline" },
    .{ .id = "causal-artifacts-manifest", .needle = "zig build causal-artifacts", .detail = "workflow prints causal artifact manifest" },
    .{ .id = "release-gate-runs", .needle = "zig build release-gate --summary none", .detail = "workflow runs durable workflow and cluster release gate" },
    .{ .id = "failure-handoff", .needle = "zig build causal-ci-handoff", .detail = "workflow writes failure handoff" },
    .{ .id = "failure-only-upload", .needle = "if: ${{ failure() }}", .detail = "upload and handoff are failure-only" },
    .{ .id = "upload-artifact-v4", .needle = "actions/upload-artifact@v4", .detail = "workflow uses GitHub artifact upload action" },
    .{ .id = "ignore-missing-files", .needle = "if-no-files-found: ignore", .detail = "missing preview files remain non-fatal" },
    .{ .id = "retention-fourteen-days", .needle = "retention-days: 14", .detail = "artifact retention is bounded" },
    .{ .id = "causal-txt-glob", .needle = "packages/zigeffect/.zig-cache/causal-artifacts/*.txt", .detail = "causal text artifacts are archived" },
    .{ .id = "causal-json-glob", .needle = "packages/zigeffect/.zig-cache/causal-artifacts/*.json", .detail = "causal JSON artifacts are archived" },
    .{ .id = "causal-dot-glob", .needle = "packages/zigeffect/.zig-cache/causal-artifacts/*.dot", .detail = "causal graph artifacts are archived" },
    .{ .id = "release-gate-txt-glob", .needle = "packages/zigeffect/.zig-cache/release-gate/*.txt", .detail = "release-gate text artifacts are archived" },
    .{ .id = "release-gate-json-glob", .needle = "packages/zigeffect/.zig-cache/release-gate/*.json", .detail = "release-gate JSON artifacts are archived" },
};

const prohibited_workflow_features: []const WorkflowTextCheck = &.{
    .{ .id = "no-secrets-usage", .needle = "secrets.", .detail = "workflow does not reference secrets" },
    .{ .id = "no-write-all-permissions", .needle = "write-all", .detail = "workflow does not request write-all permissions" },
    .{ .id = "no-contents-write", .needle = "contents: write", .detail = "workflow does not request content writes" },
    .{ .id = "no-id-token-write", .needle = "id-token: write", .detail = "workflow does not request OIDC token writes" },
    .{ .id = "no-schedule-trigger", .needle = "schedule:", .detail = "workflow does not poll on a schedule" },
    .{ .id = "no-collector-endpoint", .needle = "OTEL_EXPORTER_OTLP_ENDPOINT", .detail = "workflow does not configure OTLP endpoint" },
    .{ .id = "no-production-token", .needle = "PRODUCTION_TELEMETRY_TOKEN", .detail = "workflow does not configure production telemetry token" },
    .{ .id = "no-deploy-action", .needle = "cloudflare/wrangler-action", .detail = "workflow does not deploy production surfaces" },
    .{ .id = "no-telemetry-gate-step", .needle = "production telemetry gate", .detail = "workflow does not enforce telemetry gates" },
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
        error.MissingHarnessInput, error.MissingWorkflowAfterInput => failUsage(err),
        else => return err,
    };
}

fn parseOptions(allocator: std.mem.Allocator, args: []const []const u8) !Options {
    if (args.len < 2) return error.MissingHarnessPath;
    if (!std.mem.eql(u8, args[1], "--from-harness")) return error.UnknownFlag;
    if (args.len < 3) return error.MissingHarnessPath;
    const harness_path = args[2];
    if (!std.mem.endsWith(u8, harness_path, ".json")) return error.InvalidHarnessPath;
    if (args.len < 4) return error.MissingMode;
    const mode = try parseMode(args[3]);

    var reviewed_by: []const u8 = "ci-archive-application-reviewer";
    var policy: []const u8 = "manual-production-telemetry-ci-archive-application";
    var reason: ?[]const u8 = null;
    var workflow_after_path: ?[]const u8 = null;
    var workflow_changes = std.ArrayList([]const u8).empty;
    var before_evidence = std.ArrayList([]const u8).empty;
    var after_evidence = std.ArrayList([]const u8).empty;
    var verified_commands = std.ArrayList([]const u8).empty;
    var out_prefix: ?[]const u8 = null;
    errdefer workflow_changes.deinit(allocator);
    errdefer before_evidence.deinit(allocator);
    errdefer after_evidence.deinit(allocator);
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
        } else if (std.mem.eql(u8, flag, "--workflow-after")) {
            if (!workflowPathValid(value)) return error.InvalidWorkflowAfterPath;
            workflow_after_path = value;
        } else if (std.mem.eql(u8, flag, "--workflow-change")) {
            try workflow_changes.append(allocator, value);
        } else if (std.mem.eql(u8, flag, "--before")) {
            try before_evidence.append(allocator, value);
        } else if (std.mem.eql(u8, flag, "--after")) {
            try after_evidence.append(allocator, value);
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
        .harness_path = harness_path,
        .mode = mode,
        .reviewed_by = reviewed_by,
        .policy = policy,
        .reason = final_reason,
        .workflow_after_path = workflow_after_path,
        .workflow_changes = try workflow_changes.toOwnedSlice(allocator),
        .before_evidence = try before_evidence.toOwnedSlice(allocator),
        .after_evidence = try after_evidence.toOwnedSlice(allocator),
        .verified_commands = try verified_commands.toOwnedSlice(allocator),
        .out_prefix = out_prefix,
    };
}

fn parseMode(value: []const u8) !Mode {
    if (std.mem.eql(u8, value, "plan")) return .plan;
    if (std.mem.eql(u8, value, "record-applied")) return .record_applied;
    return error.UnknownMode;
}

fn workflowPathValid(path: []const u8) bool {
    return std.mem.endsWith(u8, path, ".yml") or std.mem.endsWith(u8, path, ".yaml");
}

fn modeText(mode: Mode) []const u8 {
    return switch (mode) {
        .plan => "plan",
        .record_applied => "record-applied",
    };
}

fn applicationStatusText(status: ApplicationStatus) []const u8 {
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

fn outputPathsForOptions(allocator: std.mem.Allocator, options: Options) !OutputPaths {
    const prefix = if (options.out_prefix) |out_prefix|
        try allocator.dupe(u8, out_prefix)
    else blk: {
        if (!std.mem.endsWith(u8, options.harness_path, ".json")) return error.InvalidHarnessPath;
        const base = options.harness_path[0 .. options.harness_path.len - ".json".len];
        break :blk try std.fmt.allocPrint(allocator, "{s}-ci-archive-application", .{base});
    };
    defer allocator.free(prefix);

    return .{
        .json_path = try std.fmt.allocPrint(allocator, "{s}.json", .{prefix}),
        .text_path = try std.fmt.allocPrint(allocator, "{s}.txt", .{prefix}),
    };
}

fn formatReports(allocator: std.mem.Allocator, input: ApplicationInput) !ApplicationReports {
    var parsed = try std.json.parseFromSlice(CiHarnessBoundaryArtifact, allocator, input.source_harness_json, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();

    const paths = try outputPathsForOptions(allocator, input.options);
    defer paths.deinit(allocator);

    const after_workflow_digest = if (input.workflow_after_yml) |workflow_yml|
        try workflowDigest(allocator, workflow_yml)
    else
        try allocator.dupe(u8, "");
    defer allocator.free(after_workflow_digest);

    const result = try evaluateApplication(allocator, input.options, parsed.value, input.workflow_after_yml);
    defer result.deinit(allocator);

    const json = try formatApplicationJson(allocator, input.options, parsed.value, input.workflow_after_yml, after_workflow_digest, result, paths);
    errdefer allocator.free(json);
    const text = try formatApplicationText(allocator, input.options, parsed.value, after_workflow_digest, result, paths);
    errdefer allocator.free(text);

    return .{ .json = json, .text = text };
}

fn evaluateApplication(
    allocator: std.mem.Allocator,
    options: Options,
    harness: CiHarnessBoundaryArtifact,
    workflow_after_yml: ?[]const u8,
) !ApplicationResult {
    var checks = std.ArrayList(ApplicationCheck).empty;
    errdefer checks.deinit(allocator);

    try appendCheck(allocator, &checks, "source-harness-schema", if (std.mem.eql(u8, harness.schema, ci_harness_boundary_schema) and harness.schema_version == 1) .pass else .fail, "source CI harness boundary schema is supported");
    try appendCheck(allocator, &checks, "source-harness-ready", if (std.mem.eql(u8, harness.ci_harness_boundary_status, "ready")) .pass else .fail, "source CI harness boundary is ready");
    try appendCheck(allocator, &checks, "source-decision-approved", if (std.mem.eql(u8, harness.decision, "approve")) .pass else .fail, "source CI harness boundary reviewer approved the handoff");
    try appendCheck(allocator, &checks, "source-next-branch-ready", if (harness.ready_for_next_branch) .pass else .fail, "source CI harness boundary marked this branch ready");
    try appendCheck(allocator, &checks, "source-authority-disabled", if (sourceAuthorityDisabled(harness)) .pass else .fail, "source harness keeps runtime durable NenDB CI upload execution workflow mutation and gates disabled");
    try appendCheck(allocator, &checks, "source-workflow-checks-passed", if (sourceChecksPassed(harness.workflow_required_features) and sourceChecksPassed(harness.workflow_prohibited_features) and sourceChecksPassed(harness.checks)) .pass else .fail, "source workflow and harness checks passed");
    try appendCheck(allocator, &checks, "source-verification-recorded", if (sourceVerificationRecorded(harness)) .pass else .fail, "source harness recorded required verification command evidence");
    try appendCheck(allocator, &checks, "source-upload-policy", if (uploadPolicyValid(harness.artifact_upload_policy)) .pass else .fail, "source upload policy is preview-only failure-only and bounded");
    try appendCheck(allocator, &checks, "source-artifact-candidates", if (artifactCandidatesValid(harness.artifact_candidates)) .pass else .fail, "source artifact candidates are failure-only redacted and non-public");
    try appendCheck(allocator, &checks, "source-cluster-assumptions", if (harness.cluster_release_gate_assumptions.len > 0) .pass else .fail, "source harness records cluster release-gate assumptions");
    try appendCheck(allocator, &checks, "source-blocked-claims-carried", if (harness.blocked_claims.len > 0) .pass else .fail, "source blocked claims are carried forward");

    if (options.mode == .plan) {
        try appendCheck(allocator, &checks, "workflow-change-present", .skipped, "plan mode does not claim a workflow change");
        try appendCheck(allocator, &checks, "before-evidence-present", .skipped, "plan mode does not claim before evidence");
        try appendCheck(allocator, &checks, "after-evidence-present", .skipped, "plan mode does not claim after evidence");
        try appendCheck(allocator, &checks, "post-verification-recorded", .skipped, "plan mode does not claim post-application verification");
        try appendCheck(allocator, &checks, "after-workflow-safe", if (workflow_after_yml) |workflow_yml| workflowSafetyStatus(workflow_yml) else .skipped, "optional after-workflow evidence preserves bounded archive constraints");

        const check_slice = try checks.toOwnedSlice(allocator);
        errdefer allocator.free(check_slice);
        const planned = requiredChecksPassed(check_slice);
        return .{
            .status = if (planned) .planned else .blocked,
            .applied = false,
            .mutation_authority = "none",
            .checks = check_slice,
        };
    }

    try appendCheck(allocator, &checks, "workflow-change-present", if (options.workflow_changes.len > 0) .pass else .fail, "record-applied requires reviewed workflow change evidence");
    try appendCheck(allocator, &checks, "before-evidence-present", if (options.before_evidence.len > 0) .pass else .fail, "record-applied requires before evidence");
    try appendCheck(allocator, &checks, "after-evidence-present", if (options.after_evidence.len > 0) .pass else .fail, "record-applied requires after evidence");
    try appendCheck(allocator, &checks, "post-verification-recorded", if (verifiedCommandsContainAll(options.verified_commands, required_verification_commands)) .pass else .fail, "record-applied requires every post-application verification command");
    try appendCheck(allocator, &checks, "after-workflow-present", if (workflow_after_yml != null) .pass else .fail, "record-applied requires after-workflow text");
    try appendCheck(allocator, &checks, "after-workflow-safe", if (workflow_after_yml) |workflow_yml| workflowSafetyStatus(workflow_yml) else .fail, "after-workflow evidence preserves bounded archive constraints");

    const check_slice = try checks.toOwnedSlice(allocator);
    errdefer allocator.free(check_slice);
    const applied = allChecksPassed(check_slice);
    return .{
        .status = if (applied) .applied else .blocked,
        .applied = applied,
        .mutation_authority = if (applied) "record-only" else "none",
        .checks = check_slice,
    };
}

fn appendCheck(
    allocator: std.mem.Allocator,
    checks: *std.ArrayList(ApplicationCheck),
    name: []const u8,
    status: CheckStatus,
    detail: []const u8,
) !void {
    try checks.append(allocator, .{ .name = name, .status = status, .detail = detail });
}

fn requiredChecksPassed(checks: []const ApplicationCheck) bool {
    for (checks) |check| {
        if (check.status == .fail) return false;
    }
    return true;
}

fn allChecksPassed(checks: []const ApplicationCheck) bool {
    for (checks) |check| {
        if (check.status != .pass) return false;
    }
    return true;
}

fn sourceAuthorityDisabled(harness: CiHarnessBoundaryArtifact) bool {
    return !harness.applied and
        std.mem.eql(u8, harness.mutation_authority, "none") and
        !harness.production_telemetry_ingestion and
        !harness.live_exporter_enabled and
        !harness.network_send_enabled and
        !harness.collector_endpoint_configured and
        !harness.otlp_serialization_enabled and
        !harness.runtime_pipeline_enabled and
        !harness.durable_write_enabled and
        !harness.nendb_write_enabled and
        !harness.ci_upload_enabled and
        !harness.ci_upload_execution_enabled and
        !harness.ci_workflow_mutation_enabled and
        !harness.ci_gate_enabled and
        harness.ci_harness_boundary_enabled;
}

fn sourceChecksPassed(checks: []const SourceCheck) bool {
    if (checks.len == 0) return false;
    for (checks) |check| {
        if (!std.mem.eql(u8, check.status, "pass")) return false;
    }
    return true;
}

fn sourceVerificationRecorded(harness: CiHarnessBoundaryArtifact) bool {
    return harness.required_verification_commands.len > 0 and
        verifiedCommandsContainAll(harness.verified_commands, harness.required_verification_commands);
}

fn uploadPolicyValid(policy: ArtifactUploadPolicy) bool {
    return std.mem.eql(u8, policy.mode, "preview-only") and
        policy.failure_only and
        policy.retention_days == 14 and
        !policy.public_upload_claim and
        !policy.ci_gate_claim and
        containsString(policy.allowed_extensions, ".txt") and
        containsString(policy.allowed_extensions, ".json") and
        containsString(policy.allowed_extensions, ".dot");
}

fn artifactCandidatesValid(candidates: []const ArtifactCandidate) bool {
    if (!hasArtifactCandidate(candidates, "source-workbench-preview-json")) return false;
    if (!hasArtifactCandidate(candidates, "source-retention-fixtures-json")) return false;
    if (!hasArtifactCandidate(candidates, "future-ci-preview-json")) return false;
    for (candidates) |candidate| {
        if (!candidate.failure_only) return false;
        if (!candidate.redaction_required) return false;
        if (candidate.public_upload_allowed) return false;
        if (!extensionAllowed(candidate.extension)) return false;
    }
    return true;
}

fn hasArtifactCandidate(candidates: []const ArtifactCandidate, id: []const u8) bool {
    for (candidates) |candidate| {
        if (std.mem.eql(u8, candidate.id, id)) return true;
    }
    return false;
}

fn extensionAllowed(extension: []const u8) bool {
    return std.mem.eql(u8, extension, ".txt") or
        std.mem.eql(u8, extension, ".json") or
        std.mem.eql(u8, extension, ".dot");
}

fn workflowSafetyStatus(workflow_yml: []const u8) CheckStatus {
    for (required_workflow_features) |feature| {
        if (!contains(workflow_yml, feature.needle)) return .fail;
    }
    for (prohibited_workflow_features) |feature| {
        if (contains(workflow_yml, feature.needle)) return .fail;
    }
    return .pass;
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

fn formatApplicationJson(
    allocator: std.mem.Allocator,
    options: Options,
    harness: CiHarnessBoundaryArtifact,
    workflow_after_yml: ?[]const u8,
    after_workflow_digest: []const u8,
    result: ApplicationResult,
    paths: OutputPaths,
) ![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "{\n");
    try output.appendSlice(allocator, "  \"schema\": ");
    try appendJsonString(allocator, &output, production_telemetry_ci_archive_application_schema);
    try output.appendSlice(allocator, ",\n  \"schema_version\": 1,\n");
    try output.appendSlice(allocator, "  \"source_ci_harness_boundary\": ");
    try appendJsonString(allocator, &output, options.harness_path);
    try output.appendSlice(allocator, ",\n  \"source_ci_artifact_preview\": ");
    try appendJsonString(allocator, &output, harness.source_ci_artifact_preview);
    try output.appendSlice(allocator, ",\n  \"source_workbench_preview\": ");
    try appendJsonString(allocator, &output, harness.source_workbench_preview);
    try output.appendSlice(allocator, ",\n  \"workflow_path\": ");
    try appendJsonString(allocator, &output, harness.workflow_path);
    try output.appendSlice(allocator, ",\n  \"source_workflow_digest\": ");
    try appendJsonString(allocator, &output, harness.workflow_digest);
    try output.appendSlice(allocator, ",\n  \"after_workflow_path\": ");
    try appendOptionalJsonString(allocator, &output, options.workflow_after_path);
    try output.appendSlice(allocator, ",\n  \"after_workflow_digest\": ");
    try appendJsonString(allocator, &output, after_workflow_digest);
    try output.appendSlice(allocator, ",\n  \"mode\": ");
    try appendJsonString(allocator, &output, modeText(options.mode));
    try output.appendSlice(allocator, ",\n  \"application_status\": ");
    try appendJsonString(allocator, &output, applicationStatusText(result.status));
    try output.print(allocator, ",\n  \"applied\": {},\n", .{result.applied});
    try output.appendSlice(allocator, "  \"mutation_authority\": ");
    try appendJsonString(allocator, &output, result.mutation_authority);
    try output.print(allocator, ",\n  \"ci_archive_application_enabled\": {},\n", .{ci_archive_application_enabled});
    try output.print(allocator, "  \"ci_upload_enabled\": {},\n", .{result.applied});
    try output.print(allocator, "  \"ci_upload_execution_enabled\": {},\n", .{ci_upload_execution_enabled});
    try output.print(allocator, "  \"ci_workflow_mutation_enabled\": {},\n", .{ci_workflow_mutation_enabled});
    try output.print(allocator, "  \"ci_gate_enabled\": {},\n", .{ci_gate_enabled});
    try output.print(allocator, "  \"production_telemetry_ingestion\": {},\n", .{production_telemetry_ingestion});
    try output.print(allocator, "  \"live_exporter_enabled\": {},\n", .{live_exporter_enabled});
    try output.print(allocator, "  \"network_send_enabled\": {},\n", .{network_send_enabled});
    try output.print(allocator, "  \"collector_endpoint_configured\": {},\n", .{collector_endpoint_configured});
    try output.print(allocator, "  \"otlp_serialization_enabled\": {},\n", .{otlp_serialization_enabled});
    try output.print(allocator, "  \"runtime_pipeline_enabled\": {},\n", .{runtime_pipeline_enabled});
    try output.print(allocator, "  \"durable_write_enabled\": {},\n", .{durable_write_enabled});
    try output.print(allocator, "  \"nendb_write_enabled\": {},\n", .{nendb_write_enabled});
    try output.appendSlice(allocator, "  \"reviewed_by\": ");
    try appendJsonString(allocator, &output, options.reviewed_by);
    try output.appendSlice(allocator, ",\n  \"policy\": ");
    try appendJsonString(allocator, &output, options.policy);
    try output.appendSlice(allocator, ",\n  \"reason\": ");
    try appendJsonString(allocator, &output, options.reason);
    try output.appendSlice(allocator, ",\n  \"workflow_changes\": ");
    try appendStringArray(allocator, &output, options.workflow_changes);
    try output.appendSlice(allocator, ",\n  \"before_evidence\": ");
    try appendStringArray(allocator, &output, options.before_evidence);
    try output.appendSlice(allocator, ",\n  \"after_evidence\": ");
    try appendStringArray(allocator, &output, options.after_evidence);
    try output.appendSlice(allocator, ",\n  \"source_checks\": ");
    try appendSourceChecksJson(allocator, &output, harness.checks);
    try output.appendSlice(allocator, ",\n  \"after_workflow_required_features\": ");
    if (workflow_after_yml) |workflow_yml| {
        try appendWorkflowFeatureChecksJson(allocator, &output, workflow_yml, required_workflow_features, true);
    } else {
        try output.appendSlice(allocator, "[]");
    }
    try output.appendSlice(allocator, ",\n  \"after_workflow_prohibited_features\": ");
    if (workflow_after_yml) |workflow_yml| {
        try appendWorkflowFeatureChecksJson(allocator, &output, workflow_yml, prohibited_workflow_features, false);
    } else {
        try output.appendSlice(allocator, "[]");
    }
    try output.appendSlice(allocator, ",\n  \"checks\": ");
    try appendChecksJson(allocator, &output, result.checks);
    try output.appendSlice(allocator, ",\n  \"required_verification_commands\": ");
    try appendStringArray(allocator, &output, required_verification_commands);
    try output.appendSlice(allocator, ",\n  \"verified_commands\": ");
    try appendStringArray(allocator, &output, options.verified_commands);
    try output.appendSlice(allocator, ",\n  \"cluster_release_gate_assumptions\": ");
    try appendStringArray(allocator, &output, harness.cluster_release_gate_assumptions);
    try output.appendSlice(allocator, ",\n  \"application_steps\": ");
    try appendStringArray(allocator, &output, applicationSteps(result.status));
    try output.appendSlice(allocator, ",\n  \"guardrails\": ");
    try appendStringArray(allocator, &output, applicationGuardrails(result.status));
    try output.appendSlice(allocator, ",\n  \"blocked_claims\": ");
    try appendStringArray(allocator, &output, blockedClaims(harness));
    try output.appendSlice(allocator, ",\n  \"generated_by\": ");
    try appendJsonString(allocator, &output, generated_by);
    try output.appendSlice(allocator, ",\n  \"source_branch\": ");
    try appendJsonString(allocator, &output, source_branch);
    try output.appendSlice(allocator, ",\n  \"recommendation\": ");
    try appendJsonString(allocator, &output, recommendation);
    try output.appendSlice(allocator, ",\n  \"next_branch_if_applied\": ");
    try appendJsonString(allocator, &output, next_branch_if_applied);
    try output.appendSlice(allocator, ",\n  \"output_paths\": { \"json\": ");
    try appendJsonString(allocator, &output, paths.json_path);
    try output.appendSlice(allocator, ", \"text\": ");
    try appendJsonString(allocator, &output, paths.text_path);
    try output.appendSlice(allocator, " },\n  \"agent_guidance\": ");
    try appendStringArray(allocator, &output, agentGuidance(result.status));
    try output.appendSlice(allocator, "\n}\n");

    return output.toOwnedSlice(allocator);
}

fn formatApplicationText(
    allocator: std.mem.Allocator,
    options: Options,
    harness: CiHarnessBoundaryArtifact,
    after_workflow_digest: []const u8,
    result: ApplicationResult,
    paths: OutputPaths,
) ![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "zigeffect production telemetry CI archive application\n");
    try output.print(allocator, "schema: {s}\n", .{production_telemetry_ci_archive_application_schema});
    try output.print(allocator, "source CI harness boundary: {s}\n", .{options.harness_path});
    try output.print(allocator, "workflow path: {s}\n", .{harness.workflow_path});
    try output.print(allocator, "source workflow digest: {s}\n", .{harness.workflow_digest});
    try output.print(allocator, "after workflow digest: {s}\n", .{after_workflow_digest});
    try output.print(allocator, "mode: {s}\n", .{modeText(options.mode)});
    try output.print(allocator, "application_status: {s}\n", .{applicationStatusText(result.status)});
    try output.print(allocator, "applied: {}\n", .{result.applied});
    try output.print(allocator, "mutation_authority: {s}\n", .{result.mutation_authority});
    try output.print(allocator, "ci archive application enabled: {}\n", .{ci_archive_application_enabled});
    try output.print(allocator, "ci upload enabled: {}\n", .{result.applied});
    try output.print(allocator, "ci upload execution enabled: {}\n", .{ci_upload_execution_enabled});
    try output.print(allocator, "ci workflow mutation enabled: {}\n", .{ci_workflow_mutation_enabled});
    try output.print(allocator, "ci gate enabled: {}\n", .{ci_gate_enabled});
    try output.print(allocator, "reviewed_by: {s}\n", .{options.reviewed_by});
    try output.print(allocator, "policy: {s}\n", .{options.policy});
    try output.print(allocator, "reason: {s}\n", .{options.reason});
    try output.print(allocator, "source branch: {s}\n", .{source_branch});
    try output.print(allocator, "recommendation: {s}\n", .{recommendation});
    try output.print(allocator, "next branch if applied: {s}\n", .{next_branch_if_applied});
    try output.print(allocator, "json output: {s}\n", .{paths.json_path});
    try output.print(allocator, "text output: {s}\n\n", .{paths.text_path});

    try output.appendSlice(allocator, "checks:\n");
    for (result.checks) |check| {
        try output.print(allocator, "- {s}: {s} - {s}\n", .{ check.name, checkStatusText(check.status), check.detail });
    }
    try output.append(allocator, '\n');

    try appendTextList(allocator, &output, "workflow changes", options.workflow_changes);
    try appendTextList(allocator, &output, "before evidence", options.before_evidence);
    try appendTextList(allocator, &output, "after evidence", options.after_evidence);
    try appendTextList(allocator, &output, "cluster release gate assumptions", harness.cluster_release_gate_assumptions);
    try appendTextList(allocator, &output, "required verification commands", required_verification_commands);
    try appendTextList(allocator, &output, "verified commands", options.verified_commands);
    try appendTextList(allocator, &output, "application steps", applicationSteps(result.status));
    try appendTextList(allocator, &output, "guardrails", applicationGuardrails(result.status));
    try appendTextList(allocator, &output, "blocked claims", blockedClaims(harness));
    try appendTextList(allocator, &output, "agent guidance", agentGuidance(result.status));

    return output.toOwnedSlice(allocator);
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

fn appendWorkflowFeatureChecksJson(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    workflow_yml: []const u8,
    features: []const WorkflowTextCheck,
    required_present: bool,
) !void {
    try output.append(allocator, '[');
    for (features, 0..) |feature, index| {
        if (index > 0) try output.appendSlice(allocator, ", ");
        const has_needle = contains(workflow_yml, feature.needle);
        const status: CheckStatus = if (required_present == has_needle) .pass else .fail;
        try output.appendSlice(allocator, "{ \"id\": ");
        try appendJsonString(allocator, output, feature.id);
        try output.appendSlice(allocator, ", \"status\": ");
        try appendJsonString(allocator, output, checkStatusText(status));
        try output.appendSlice(allocator, ", \"detail\": ");
        try appendJsonString(allocator, output, feature.detail);
        try output.appendSlice(allocator, " }");
    }
    try output.append(allocator, ']');
}

fn appendChecksJson(allocator: std.mem.Allocator, output: *std.ArrayList(u8), checks: []const ApplicationCheck) !void {
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

fn appendOptionalJsonString(allocator: std.mem.Allocator, output: *std.ArrayList(u8), value: ?[]const u8) !void {
    if (value) |text| {
        try appendJsonString(allocator, output, text);
    } else {
        try output.appendSlice(allocator, "null");
    }
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

fn workflowDigest(allocator: std.mem.Allocator, workflow_yml: []const u8) ![]const u8 {
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(workflow_yml, &digest, .{});

    var hex_digest: [64]u8 = undefined;
    const hex = "0123456789abcdef";
    for (digest, 0..) |byte, index| {
        hex_digest[index * 2] = hex[@intCast(byte >> 4)];
        hex_digest[index * 2 + 1] = hex[@intCast(byte & 0x0f)];
    }
    return std.fmt.allocPrint(allocator, "sha256:{s}", .{hex_digest[0..]});
}

fn contains(haystack: []const u8, needle: []const u8) bool {
    return std.mem.indexOf(u8, haystack, needle) != null;
}

fn containsString(values: []const []const u8, needle: []const u8) bool {
    for (values) |value| {
        if (std.mem.indexOf(u8, value, needle) != null) return true;
    }
    return false;
}

fn blockedClaims(harness: CiHarnessBoundaryArtifact) []const []const u8 {
    if (harness.blocked_claims.len > 0) return harness.blocked_claims;
    return blocked_claims;
}

fn applicationSteps(status: ApplicationStatus) []const []const u8 {
    return switch (status) {
        .planned => &.{
            "Review the archive application plan against the source CI harness boundary.",
            "Apply any real workflow/archive change outside this command through normal review.",
            "Rerun record-applied only after before and after evidence plus verification commands exist.",
        },
        .applied => &.{
            "Keep this artifact with the reviewed workflow change and verification evidence.",
            "Start the archive evidence policy branch from this applied record.",
        },
        .blocked => &.{
            "Resolve failed source harness evidence workflow evidence before/after evidence or verification checks.",
            "Do not claim CI archive application until record-applied passes.",
        },
    };
}

fn applicationGuardrails(status: ApplicationStatus) []const []const u8 {
    return switch (status) {
        .planned => &.{
            "Plan mode does not edit GitHub Actions upload artifacts configure secrets or enable gates.",
            "The application remains unapplied until record-applied passes with real evidence.",
        },
        .applied => &.{
            "applied=true is record-only evidence that a separately reviewed workflow/archive change passed checks.",
            "This tool still did not execute CI upload jobs mutate workflows or enable telemetry gates.",
        },
        .blocked => &.{
            "Blocked archive application artifacts cannot justify workflow mutation upload execution or telemetry gates.",
            "Regenerate after evidence is complete and verification commands have run.",
        },
    };
}

fn agentGuidance(status: ApplicationStatus) []const []const u8 {
    return switch (status) {
        .planned => &.{
            "Use planned archive application evidence to prepare a reviewed workflow/archive patch only.",
            "Do not claim applied archive configuration from plan mode.",
        },
        .applied => &.{
            "Use applied archive application evidence to start archive evidence policy work.",
            "Cite workflow changes before evidence after evidence post-verification commands and source harness boundary.",
        },
        .blocked => &.{
            "Treat blocked archive application evidence as a stop sign.",
            "Repair source harness workflow evidence before/after evidence or verification proof before continuing.",
        },
    };
}

const blocked_claims: []const []const u8 = &.{
    "ci-archive-application-not-applied",
    "ci-upload-execution-not-run-by-tool",
    "ci-workflow-not-mutated-by-tool",
    "ci-telemetry-gate-not-enabled",
    "runtime-pipeline-not-enabled",
    "live-exporter-not-enabled",
    "network-send-not-enabled",
    "durable-production-write-not-enabled",
    "nendb-write-not-enabled",
    "production-cluster-not-claimed-ready",
};

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
    const source_harness_json = try readRequiredArtifact(init.io, allocator, options.harness_path, error.MissingHarnessInput);
    defer allocator.free(source_harness_json);
    const workflow_after_yml = if (options.workflow_after_path) |path|
        try readRequiredArtifact(init.io, allocator, path, error.MissingWorkflowAfterInput)
    else
        null;
    defer if (workflow_after_yml) |contents| allocator.free(contents);

    const reports = try formatReports(allocator, .{
        .options = options,
        .source_harness_json = source_harness_json,
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
    return "usage: zig build causal-production-telemetry-ci-archive-application -- --from-harness <ci-harness-boundary.json> plan|record-applied --reason <reason> [--workflow-after <workflow.yml>] [--by <actor>] [--policy <policy>] [--workflow-change <path-or-evidence>] [--before <evidence>] [--after <evidence>] [--verified-command <command>]... [--out-prefix <path-prefix>]\n";
}

fn failUsage(err: anyerror) noreturn {
    std.debug.print("causal-production-telemetry-ci-archive-application error: {s}\n{s}", .{ @errorName(err), usage() });
    std.process.exit(2);
}

fn freeSliceOnly(allocator: std.mem.Allocator, values: []const []const u8) void {
    if (values.len > 0) allocator.free(values);
}

test "ci archive application schema and branch constants are stable" {
    try std.testing.expectEqualStrings("zigeffect.causal.production-telemetry-ci-archive-application.v1", production_telemetry_ci_archive_application_schema);
    try std.testing.expectEqual(@as(u32, 1), production_telemetry_ci_archive_application_schema_version);
    try std.testing.expectEqualStrings("codex/zigeffect-causal-production-telemetry-ci-archive-application", source_branch);
    try std.testing.expectEqualStrings("start-production-telemetry-ci-archive-evidence-policy", recommendation);
    try std.testing.expectEqualStrings("codex/zigeffect-causal-production-telemetry-ci-archive-evidence-policy", next_branch_if_applied);
    try std.testing.expect(containsString(required_verification_commands, "zig build causal-production-telemetry-ci-harness-boundary"));
    try std.testing.expect(containsString(required_verification_commands, "zig build release-gate --summary none"));
}

test "parses ci archive application plan and record-applied options" {
    var plan_options = try parseOptions(std.testing.allocator, &.{
        "zigeffect-causal-production-telemetry-ci-archive-application",
        "--from-harness",
        ".zig-cache/causal-artifacts/ci-harness-boundary.json",
        "plan",
        "--reason",
        "CI archive application planned",
        "--workflow-after",
        ".github/workflows/zigeffect-causal.yml",
        "--by",
        "codex",
        "--policy",
        "manual-production-telemetry-ci-archive-application",
        "--out-prefix",
        ".zig-cache/causal-artifacts/custom-ci-archive-application",
    });
    defer plan_options.deinit(std.testing.allocator);

    try std.testing.expectEqual(Mode.plan, plan_options.mode);
    try std.testing.expectEqualStrings(".zig-cache/causal-artifacts/ci-harness-boundary.json", plan_options.harness_path);
    try std.testing.expectEqualStrings(".github/workflows/zigeffect-causal.yml", plan_options.workflow_after_path.?);
    try std.testing.expectEqualStrings("codex", plan_options.reviewed_by);
    try std.testing.expectEqualStrings("manual-production-telemetry-ci-archive-application", plan_options.policy);
    try std.testing.expectEqualStrings(".zig-cache/causal-artifacts/custom-ci-archive-application", plan_options.out_prefix.?);

    var applied_options = try parseOptions(std.testing.allocator, &.{
        "zigeffect-causal-production-telemetry-ci-archive-application",
        "--from-harness",
        ".zig-cache/causal-artifacts/ci-harness-boundary.json",
        "record-applied",
        "--reason",
        "reviewed archive workflow change applied",
        "--workflow-after",
        ".github/workflows/zigeffect-causal.yml",
        "--workflow-change",
        ".github/workflows/zigeffect-causal.yml",
        "--before",
        "source harness workflow digest",
        "--after",
        "post-change workflow review",
        "--verified-command",
        "zig build causal-production-telemetry-ci-harness-boundary",
    });
    defer applied_options.deinit(std.testing.allocator);

    try std.testing.expectEqual(Mode.record_applied, applied_options.mode);
    try std.testing.expectEqual(@as(usize, 1), applied_options.workflow_changes.len);
    try std.testing.expectEqual(@as(usize, 1), applied_options.before_evidence.len);
    try std.testing.expectEqual(@as(usize, 1), applied_options.after_evidence.len);
    try std.testing.expectEqual(@as(usize, 1), applied_options.verified_commands.len);
}

test "plan and record-applied reports preserve guarded authority" {
    const planned = try formatReports(std.testing.allocator, .{
        .options = .{
            .harness_path = ".zig-cache/causal-artifacts/ci-harness-boundary.json",
            .mode = .plan,
            .reason = "CI archive application planned",
        },
        .source_harness_json = sample_ci_harness_boundary_json,
        .workflow_after_yml = null,
    });
    defer planned.deinit(std.testing.allocator);

    try std.testing.expect(std.mem.indexOf(u8, planned.json, "\"schema\": \"zigeffect.causal.production-telemetry-ci-archive-application.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, planned.json, "\"application_status\": \"planned\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, planned.json, "\"applied\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, planned.json, "\"mutation_authority\": \"none\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, planned.json, "\"ci_archive_application_enabled\": true") != null);
    try std.testing.expect(std.mem.indexOf(u8, planned.json, "\"ci_upload_execution_enabled\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, planned.json, "\"ci_workflow_mutation_enabled\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, planned.json, "\"ci_gate_enabled\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, planned.json, "\"next_branch_if_applied\": \"codex/zigeffect-causal-production-telemetry-ci-archive-evidence-policy\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, planned.text, "application_status: planned") != null);
    try std.testing.expect(std.mem.indexOf(u8, planned.text, "applied: false") != null);

    const applied = try formatReports(std.testing.allocator, .{
        .options = .{
            .harness_path = ".zig-cache/causal-artifacts/ci-harness-boundary.json",
            .mode = .record_applied,
            .reason = "reviewed archive workflow change applied",
            .workflow_after_path = ".github/workflows/zigeffect-causal.yml",
            .workflow_changes = &.{".github/workflows/zigeffect-causal.yml"},
            .before_evidence = &.{"source harness workflow digest"},
            .after_evidence = &.{"post-change workflow review"},
            .verified_commands = required_verification_commands,
        },
        .source_harness_json = sample_ci_harness_boundary_json,
        .workflow_after_yml = sample_workflow_yml,
    });
    defer applied.deinit(std.testing.allocator);

    try std.testing.expect(std.mem.indexOf(u8, applied.json, "\"application_status\": \"applied\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, applied.json, "\"applied\": true") != null);
    try std.testing.expect(std.mem.indexOf(u8, applied.json, "\"mutation_authority\": \"record-only\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, applied.json, "\"after_workflow_digest\": \"sha256:") != null);
    try std.testing.expect(std.mem.indexOf(u8, applied.json, "\"name\": \"after-workflow-safe\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, applied.text, "application_status: applied") != null);
}

test "missing evidence and prohibited workflow features block record-applied" {
    const missing_evidence = try formatReports(std.testing.allocator, .{
        .options = .{
            .harness_path = ".zig-cache/causal-artifacts/ci-harness-boundary.json",
            .mode = .record_applied,
            .reason = "negative archive application path",
            .workflow_after_path = ".github/workflows/zigeffect-causal.yml",
            .workflow_changes = &.{".github/workflows/zigeffect-causal.yml"},
            .before_evidence = &.{"source harness workflow digest"},
        },
        .source_harness_json = sample_ci_harness_boundary_json,
        .workflow_after_yml = sample_workflow_yml,
    });
    defer missing_evidence.deinit(std.testing.allocator);

    try std.testing.expect(std.mem.indexOf(u8, missing_evidence.json, "\"application_status\": \"blocked\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, missing_evidence.json, "\"applied\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, missing_evidence.json, "\"name\": \"after-evidence-present\"") != null);

    const prohibited = try formatReports(std.testing.allocator, .{
        .options = .{
            .harness_path = ".zig-cache/causal-artifacts/ci-harness-boundary.json",
            .mode = .record_applied,
            .reason = "reviewed archive workflow change applied",
            .workflow_after_path = ".github/workflows/zigeffect-causal.yml",
            .workflow_changes = &.{".github/workflows/zigeffect-causal.yml"},
            .before_evidence = &.{"source harness workflow digest"},
            .after_evidence = &.{"post-change workflow review"},
            .verified_commands = required_verification_commands,
        },
        .source_harness_json = sample_ci_harness_boundary_json,
        .workflow_after_yml = sample_workflow_yml ++ "\n      - run: echo ${{ secrets.PRODUCTION_TELEMETRY_TOKEN }}\n",
    });
    defer prohibited.deinit(std.testing.allocator);

    try std.testing.expect(std.mem.indexOf(u8, prohibited.json, "\"application_status\": \"blocked\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, prohibited.json, "\"name\": \"after-workflow-safe\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, prohibited.json, "\"status\": \"fail\"") != null);
}

const sample_ci_harness_boundary_json =
    \\{
    \\  "schema": "zigeffect.causal.production-telemetry-ci-harness-boundary.v1",
    \\  "schema_version": 1,
    \\  "source_ci_artifact_preview": ".zig-cache/causal-artifacts/ci-preview.json",
    \\  "source_workbench_preview": ".zig-cache/causal-artifacts/workbench-preview.json",
    \\  "source_retention": ".zig-cache/causal-artifacts/nendb-retention.json",
    \\  "source_local_pipeline": ".zig-cache/causal-artifacts/local-pipeline.json",
    \\  "source_boundary": ".zig-cache/causal-artifacts/exporter-boundary.json",
    \\  "source_proposal": ".zig-cache/causal-artifacts/implementation-proposal.json",
    \\  "source_readiness": ".zig-cache/causal-artifacts/readiness-review.json",
    \\  "source_fixtures": ".zig-cache/causal-artifacts/capture-fixtures.json",
    \\  "workflow_path": ".github/workflows/zigeffect-causal.yml",
    \\  "workflow_digest": "sha256:source-workflow-digest",
    \\  "decision": "approve",
    \\  "ci_harness_boundary_status": "ready",
    \\  "ready_for_next_branch": true,
    \\  "applied": false,
    \\  "mutation_authority": "none",
    \\  "production_telemetry_ingestion": false,
    \\  "live_exporter_enabled": false,
    \\  "network_send_enabled": false,
    \\  "collector_endpoint_configured": false,
    \\  "otlp_serialization_enabled": false,
    \\  "runtime_pipeline_enabled": false,
    \\  "durable_write_enabled": false,
    \\  "nendb_write_enabled": false,
    \\  "ci_upload_enabled": false,
    \\  "ci_upload_execution_enabled": false,
    \\  "ci_workflow_mutation_enabled": false,
    \\  "ci_gate_enabled": false,
    \\  "ci_harness_boundary_enabled": true,
    \\  "source_preview_checks": [
    \\    { "name": "decision-approved", "status": "pass", "detail": "review approved" }
    \\  ],
    \\  "workflow_required_features": [
    \\    { "id": "workflow-name", "status": "pass", "detail": "causal workflow is named" },
    \\    { "id": "release-gate-runs", "status": "pass", "detail": "workflow runs release gate" }
    \\  ],
    \\  "workflow_prohibited_features": [
    \\    { "id": "no-secrets-usage", "status": "pass", "detail": "workflow does not reference secrets" },
    \\    { "id": "no-contents-write", "status": "pass", "detail": "workflow does not request content writes" }
    \\  ],
    \\  "artifact_upload_policy": {
    \\    "mode": "preview-only",
    \\    "failure_only": true,
    \\    "retention_days": 14,
    \\    "allowed_extensions": [".txt", ".json", ".dot"],
    \\    "public_upload_claim": false,
    \\    "ci_gate_claim": false
    \\  },
    \\  "artifact_candidates": [
    \\    { "id": "source-workbench-preview-json", "path": ".zig-cache/causal-artifacts/workbench-preview.json", "extension": ".json", "failure_only": true, "redaction_required": true, "public_upload_allowed": false },
    \\    { "id": "source-retention-fixtures-json", "path": ".zig-cache/causal-artifacts/nendb-retention.json", "extension": ".json", "failure_only": true, "redaction_required": true, "public_upload_allowed": false },
    \\    { "id": "future-ci-preview-json", "path": ".zig-cache/causal-artifacts/ci-preview.json", "extension": ".json", "failure_only": true, "redaction_required": true, "public_upload_allowed": false }
    \\  ],
    \\  "cluster_release_gate_assumptions": [
    \\    "zig build release-gate --summary none is the clustering-aware CI execution body"
    \\  ],
    \\  "checks": [
    \\    { "id": "source-preview-ready", "status": "pass", "detail": "source preview is ready" },
    \\    { "id": "workflow-name", "status": "pass", "detail": "workflow is named" },
    \\    { "id": "no-secrets-usage", "status": "pass", "detail": "workflow does not reference secrets" }
    \\  ],
    \\  "blocked_claims": [
    \\    "ci-artifact-upload-enabled",
    \\    "ci-workflow-mutated",
    \\    "ci-telemetry-gate"
    \\  ],
    \\  "required_verification_commands": [
    \\    "zig build causal-production-telemetry-ci-artifact-preview",
    \\    "zig build causal-artifacts"
    \\  ],
    \\  "verified_commands": [
    \\    "zig build causal-production-telemetry-ci-artifact-preview",
    \\    "zig build causal-artifacts"
    \\  ]
    \\}
;

const sample_workflow_yml =
    \\name: zigeffect causal
    \\
    \\on:
    \\  pull_request:
    \\    paths:
    \\      - ".github/workflows/zigeffect-causal.yml"
    \\      - "packages/zigeffect/**"
    \\      - "package.json"
    \\      - "bun.lock"
    \\  push:
    \\    branches:
    \\      - master
    \\  workflow_dispatch:
    \\
    \\permissions:
    \\  contents: read
    \\
    \\jobs:
    \\  zigeffect-causal:
    \\    steps:
    \\      - name: Checkout
    \\        uses: actions/checkout@v4
    \\      - name: Set up Zig
    \\        uses: mlugg/setup-zig@v2.2.1
    \\        with:
    \\          version: 0.16.0
    \\      - name: Base causal test
    \\        run: zig build causal-test
    \\      - name: Base causal dev loop baseline
    \\        run: zig build causal-dev-loop -- baseline package-tests
    \\      - name: Causal artifacts
    \\        run: zig build causal-artifacts
    \\      - name: Release gate
    \\        run: zig build release-gate --summary none
    \\      - name: Failure handoff
    \\        if: ${{ failure() }}
    \\        run: zig build causal-ci-handoff
    \\      - name: Upload causal artifacts
    \\        if: ${{ failure() }}
    \\        uses: actions/upload-artifact@v4
    \\        with:
    \\          name: zigeffect-causal-artifacts
    \\          if-no-files-found: ignore
    \\          retention-days: 14
    \\          path: |
    \\            packages/zigeffect/.zig-cache/causal-artifacts/*.txt
    \\            packages/zigeffect/.zig-cache/causal-artifacts/*.json
    \\            packages/zigeffect/.zig-cache/causal-artifacts/*.dot
    \\            packages/zigeffect/.zig-cache/release-gate/*.txt
    \\            packages/zigeffect/.zig-cache/release-gate/*.json
;
