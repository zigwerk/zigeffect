const std = @import("std");

pub const production_telemetry_ci_harness_boundary_schema = "zigeffect.causal.production-telemetry-ci-harness-boundary.v1";
pub const production_telemetry_ci_harness_boundary_schema_version: u32 = 1;
pub const source_branch = "codex/zigeffect-causal-production-telemetry-ci-harness-boundary";
pub const recommendation = "start-production-telemetry-ci-archive-application";
pub const next_branch_if_ready = "codex/zigeffect-causal-production-telemetry-ci-archive-application";

const default_workflow_path = "../../.github/workflows/zigeffect-causal.yml";

const required_verification_commands: []const []const u8 = &.{
    "zig build causal-production-telemetry-ci-artifact-preview",
    "zig build causal-artifacts",
    "zig build release-gate --summary none",
    "zig build causal-schema-governance -- --format json",
    "zig build causal-production-hardening-backlog -- --format json",
    "zig build examples",
    "zig build test",
};

const ci_artifact_preview_schema = "zigeffect.causal.production-telemetry-ci-artifact-preview.v1";
const generated_by = "causal-production-telemetry-ci-harness-boundary";
const applied = false;
const mutation_authority = "none";
const production_telemetry_ingestion = false;
const live_exporter_enabled = false;
const network_send_enabled = false;
const collector_endpoint_configured = false;
const otlp_serialization_enabled = false;
const runtime_pipeline_enabled = false;
const durable_write_enabled = false;
const nendb_write_enabled = false;
const ci_upload_enabled = false;
const ci_upload_execution_enabled = false;
const ci_workflow_mutation_enabled = false;
const ci_gate_enabled = false;
const ci_harness_boundary_enabled = true;

const Decision = enum { approve, reject };
const BoundaryStatus = enum { ready, blocked };
const CheckStatus = enum { pass, fail };

const Options = struct {
    ci_preview_path: []const u8,
    workflow_path: []const u8 = default_workflow_path,
    decision: Decision,
    reviewed_by: []const u8 = "ci-harness-boundary-reviewer",
    policy: []const u8 = "manual-production-telemetry-ci-harness-boundary",
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
    source_ci_preview_json: []const u8,
    workflow_yml: []const u8,
};

const BoundaryReports = struct {
    json: []const u8,
    text: []const u8,

    fn deinit(self: BoundaryReports, allocator: std.mem.Allocator) void {
        allocator.free(self.json);
        allocator.free(self.text);
    }
};

const SourceCheck = struct {
    name: []const u8,
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

const CiArtifactPreviewArtifact = struct {
    schema: []const u8,
    schema_version: u32,
    source_workbench_preview: []const u8 = "",
    source_retention: []const u8 = "",
    source_local_pipeline: []const u8 = "",
    source_boundary: []const u8 = "",
    source_proposal: []const u8 = "",
    source_readiness: []const u8 = "",
    source_fixtures: []const u8 = "",
    decision: []const u8,
    ci_artifact_preview_status: []const u8,
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
    ci_gate_enabled: bool,
    ci_upload_enabled: bool,
    ci_workflow_mutation_enabled: bool,
    ci_artifact_preview_enabled: bool,
    artifact_upload_policy: ArtifactUploadPolicy = .{},
    artifact_candidates: []const ArtifactCandidate = &.{},
    checks: []const SourceCheck = &.{},
    required_verification_commands: []const []const u8 = &.{},
    verified_commands: []const []const u8 = &.{},
    blocked_claims: []const []const u8 = &.{},
};

const BoundaryCheck = struct {
    id: []const u8,
    status: CheckStatus,
    detail: []const u8,
};

const WorkflowTextCheck = struct {
    id: []const u8,
    needle: []const u8,
    detail: []const u8,
};

const BoundaryResult = struct {
    status: BoundaryStatus,
    ready_for_next_branch: bool,
    checks: []const BoundaryCheck,

    fn deinit(self: BoundaryResult, allocator: std.mem.Allocator) void {
        if (self.checks.len > 0) allocator.free(self.checks);
    }
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
        error.MissingCiPreviewInput, error.MissingWorkflowInput => failUsage(err),
        else => return err,
    };
}

fn parseOptions(allocator: std.mem.Allocator, args: []const []const u8) !Options {
    if (args.len < 2) return error.MissingCiPreviewPath;

    var ci_preview_path: ?[]const u8 = null;
    var workflow_path: []const u8 = default_workflow_path;
    var index: usize = 1;

    while (index < args.len) {
        const arg = args[index];
        if (!std.mem.startsWith(u8, arg, "--")) break;
        if (index + 1 >= args.len) return error.MissingFlagValue;
        const value = args[index + 1];

        if (std.mem.eql(u8, arg, "--from-ci-preview")) {
            if (!std.mem.endsWith(u8, value, ".json")) return error.InvalidCiPreviewPath;
            ci_preview_path = value;
        } else if (std.mem.eql(u8, arg, "--workflow")) {
            if (!workflowPathValid(value)) return error.InvalidWorkflowPath;
            workflow_path = value;
        } else {
            return error.UnknownFlag;
        }
        index += 2;
    }

    const final_ci_preview_path = ci_preview_path orelse return error.MissingCiPreviewPath;
    if (index >= args.len) return error.MissingDecision;
    const decision = try parseDecision(args[index]);
    index += 1;

    var reviewed_by: []const u8 = "ci-harness-boundary-reviewer";
    var policy: []const u8 = "manual-production-telemetry-ci-harness-boundary";
    var reason: ?[]const u8 = null;
    var out_prefix: ?[]const u8 = null;
    var verified_commands = std.ArrayList([]const u8).empty;
    errdefer verified_commands.deinit(allocator);

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
        .ci_preview_path = final_ci_preview_path,
        .workflow_path = workflow_path,
        .decision = decision,
        .reviewed_by = reviewed_by,
        .policy = policy,
        .reason = final_reason,
        .verified_commands = try verified_commands.toOwnedSlice(allocator),
        .out_prefix = out_prefix,
    };
}

fn workflowPathValid(path: []const u8) bool {
    return std.mem.endsWith(u8, path, ".yml") or std.mem.endsWith(u8, path, ".yaml");
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
        if (!std.mem.endsWith(u8, options.ci_preview_path, ".json")) return error.InvalidCiPreviewPath;
        const base = options.ci_preview_path[0 .. options.ci_preview_path.len - ".json".len];
        break :blk try std.fmt.allocPrint(allocator, "{s}-ci-harness-boundary", .{base});
    };
    defer allocator.free(prefix);

    return .{
        .json_path = try std.fmt.allocPrint(allocator, "{s}.json", .{prefix}),
        .text_path = try std.fmt.allocPrint(allocator, "{s}.txt", .{prefix}),
    };
}

fn formatReports(allocator: std.mem.Allocator, input: BoundaryInput) !BoundaryReports {
    var parsed = try std.json.parseFromSlice(CiArtifactPreviewArtifact, allocator, input.source_ci_preview_json, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();

    const paths = try outputPathsForOptions(allocator, input.options);
    defer paths.deinit(allocator);

    const workflow_digest = try workflowDigest(allocator, input.workflow_yml);
    defer allocator.free(workflow_digest);

    const result = try evaluateBoundary(allocator, input.options, parsed.value, input.workflow_yml);
    defer result.deinit(allocator);

    const json = try formatBoundaryJson(allocator, input.options, parsed.value, input.workflow_yml, workflow_digest, result, paths);
    errdefer allocator.free(json);
    const text = try formatBoundaryText(allocator, input.options, parsed.value, workflow_digest, result, paths);
    errdefer allocator.free(text);

    return .{ .json = json, .text = text };
}

fn evaluateBoundary(
    allocator: std.mem.Allocator,
    options: Options,
    preview: CiArtifactPreviewArtifact,
    workflow_yml: []const u8,
) !BoundaryResult {
    var checks = std.ArrayList(BoundaryCheck).empty;
    errdefer checks.deinit(allocator);

    try appendCheck(allocator, &checks, "source-preview-schema", if (std.mem.eql(u8, preview.schema, ci_artifact_preview_schema) and preview.schema_version == 1) .pass else .fail, "source CI artifact preview schema is supported");
    try appendCheck(allocator, &checks, "source-preview-ready", if (std.mem.eql(u8, preview.ci_artifact_preview_status, "ready")) .pass else .fail, "source CI artifact preview is ready");
    try appendCheck(allocator, &checks, "decision-approved", if (options.decision == .approve) .pass else .fail, "CI harness boundary decision approved the handoff");
    try appendCheck(allocator, &checks, "source-preview-review-approved", if (std.mem.eql(u8, preview.decision, "approve")) .pass else .fail, "source CI artifact preview reviewer approved the handoff");
    try appendCheck(allocator, &checks, "source-preview-next-branch-ready", if (preview.ready_for_next_branch) .pass else .fail, "source CI artifact preview marked the next branch ready");
    try appendCheck(allocator, &checks, "source-preview-authority-disabled", if (sourcePreviewAuthorityDisabled(preview)) .pass else .fail, "source preview and boundary keep runtime durable NenDB CI upload execution workflow mutation and gates disabled");
    try appendCheck(allocator, &checks, "source-preview-checks-passed", if (sourceChecksPassed(preview.checks)) .pass else .fail, "source preview checks passed");
    try appendCheck(allocator, &checks, "source-preview-verification-recorded", if (sourceVerificationRecorded(preview)) .pass else .fail, "source preview recorded required verification command evidence");
    try appendCheck(allocator, &checks, "source-preview-upload-policy", if (uploadPolicyValid(preview.artifact_upload_policy)) .pass else .fail, "source preview upload policy remains preview-only failure-only and bounded");
    try appendCheck(allocator, &checks, "source-preview-candidates", if (artifactCandidatesValid(preview.artifact_candidates)) .pass else .fail, "source preview artifact candidates are failure-only redacted and non-public");
    try appendCheck(allocator, &checks, "source-preview-blocked-claims-carried", if (preview.blocked_claims.len > 0) .pass else .fail, "source preview blocked claims are carried forward");
    try appendCheck(allocator, &checks, "boundary-verification-recorded", if (verifiedCommandsContainAll(options.verified_commands, required_verification_commands)) .pass else .fail, "CI harness boundary recorded every required verification command");

    for (required_workflow_features) |feature| {
        try appendCheck(allocator, &checks, feature.id, if (contains(workflow_yml, feature.needle)) .pass else .fail, feature.detail);
    }
    for (prohibited_workflow_features) |feature| {
        try appendCheck(allocator, &checks, feature.id, if (!contains(workflow_yml, feature.needle)) .pass else .fail, feature.detail);
    }

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
    checks: *std.ArrayList(BoundaryCheck),
    id: []const u8,
    status: CheckStatus,
    detail: []const u8,
) !void {
    try checks.append(allocator, .{ .id = id, .status = status, .detail = detail });
}

fn allChecksPassed(checks: []const BoundaryCheck) bool {
    for (checks) |check| {
        if (check.status != .pass) return false;
    }
    return true;
}

fn sourcePreviewAuthorityDisabled(preview: CiArtifactPreviewArtifact) bool {
    return !preview.applied and
        std.mem.eql(u8, preview.mutation_authority, "none") and
        !preview.production_telemetry_ingestion and
        !preview.live_exporter_enabled and
        !preview.network_send_enabled and
        !preview.collector_endpoint_configured and
        !preview.otlp_serialization_enabled and
        !preview.runtime_pipeline_enabled and
        !preview.durable_write_enabled and
        !preview.nendb_write_enabled and
        !preview.ci_gate_enabled and
        !preview.ci_upload_enabled and
        !preview.ci_workflow_mutation_enabled and
        preview.ci_artifact_preview_enabled and
        !production_telemetry_ingestion and
        !live_exporter_enabled and
        !network_send_enabled and
        !collector_endpoint_configured and
        !otlp_serialization_enabled and
        !runtime_pipeline_enabled and
        !durable_write_enabled and
        !nendb_write_enabled and
        !ci_upload_enabled and
        !ci_upload_execution_enabled and
        !ci_workflow_mutation_enabled and
        !ci_gate_enabled and
        ci_harness_boundary_enabled;
}

fn sourceChecksPassed(checks: []const SourceCheck) bool {
    if (checks.len == 0) return false;
    for (checks) |check| {
        if (!std.mem.eql(u8, check.status, "pass")) return false;
    }
    return true;
}

fn sourceVerificationRecorded(preview: CiArtifactPreviewArtifact) bool {
    return preview.required_verification_commands.len > 0 and
        verifiedCommandsContainAll(preview.verified_commands, preview.required_verification_commands);
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
    preview: CiArtifactPreviewArtifact,
    workflow_yml: []const u8,
    workflow_digest: []const u8,
    result: BoundaryResult,
    paths: OutputPaths,
) ![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "{\n");
    try output.appendSlice(allocator, "  \"schema\": ");
    try appendJsonString(allocator, &output, production_telemetry_ci_harness_boundary_schema);
    try output.appendSlice(allocator, ",\n  \"schema_version\": 1,\n");
    try output.appendSlice(allocator, "  \"source_ci_artifact_preview\": ");
    try appendJsonString(allocator, &output, options.ci_preview_path);
    try output.appendSlice(allocator, ",\n  \"source_workbench_preview\": ");
    try appendJsonString(allocator, &output, preview.source_workbench_preview);
    try output.appendSlice(allocator, ",\n  \"source_retention\": ");
    try appendJsonString(allocator, &output, preview.source_retention);
    try output.appendSlice(allocator, ",\n  \"source_local_pipeline\": ");
    try appendJsonString(allocator, &output, preview.source_local_pipeline);
    try output.appendSlice(allocator, ",\n  \"source_boundary\": ");
    try appendJsonString(allocator, &output, preview.source_boundary);
    try output.appendSlice(allocator, ",\n  \"source_proposal\": ");
    try appendJsonString(allocator, &output, preview.source_proposal);
    try output.appendSlice(allocator, ",\n  \"source_readiness\": ");
    try appendJsonString(allocator, &output, preview.source_readiness);
    try output.appendSlice(allocator, ",\n  \"source_fixtures\": ");
    try appendJsonString(allocator, &output, preview.source_fixtures);
    try output.appendSlice(allocator, ",\n  \"workflow_path\": ");
    try appendJsonString(allocator, &output, options.workflow_path);
    try output.appendSlice(allocator, ",\n  \"workflow_digest\": ");
    try appendJsonString(allocator, &output, workflow_digest);
    try output.appendSlice(allocator, ",\n  \"decision\": ");
    try appendJsonString(allocator, &output, decisionText(options.decision));
    try output.appendSlice(allocator, ",\n  \"ci_harness_boundary_status\": ");
    try appendJsonString(allocator, &output, boundaryStatusText(result.status));
    try output.print(allocator, ",\n  \"ready_for_next_branch\": {},\n", .{result.ready_for_next_branch});
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
    try output.print(allocator, "  \"runtime_pipeline_enabled\": {},\n", .{runtime_pipeline_enabled});
    try output.print(allocator, "  \"durable_write_enabled\": {},\n", .{durable_write_enabled});
    try output.print(allocator, "  \"nendb_write_enabled\": {},\n", .{nendb_write_enabled});
    try output.print(allocator, "  \"ci_upload_enabled\": {},\n", .{ci_upload_enabled});
    try output.print(allocator, "  \"ci_upload_execution_enabled\": {},\n", .{ci_upload_execution_enabled});
    try output.print(allocator, "  \"ci_workflow_mutation_enabled\": {},\n", .{ci_workflow_mutation_enabled});
    try output.print(allocator, "  \"ci_gate_enabled\": {},\n", .{ci_gate_enabled});
    try output.print(allocator, "  \"ci_harness_boundary_enabled\": {},\n", .{ci_harness_boundary_enabled});
    try output.appendSlice(allocator, "  \"generated_by\": ");
    try appendJsonString(allocator, &output, generated_by);
    try output.appendSlice(allocator, ",\n  \"source_branch\": ");
    try appendJsonString(allocator, &output, source_branch);
    try output.appendSlice(allocator, ",\n  \"recommendation\": ");
    try appendJsonString(allocator, &output, recommendation);
    try output.appendSlice(allocator, ",\n  \"next_branch_if_ready\": ");
    try appendJsonString(allocator, &output, next_branch_if_ready);
    try output.appendSlice(allocator, ",\n  \"source_preview_checks\": ");
    try appendSourceChecksJson(allocator, &output, preview.checks);
    try output.appendSlice(allocator, ",\n  \"workflow_required_features\": ");
    try appendWorkflowFeatureChecksJson(allocator, &output, workflow_yml, required_workflow_features, true);
    try output.appendSlice(allocator, ",\n  \"workflow_prohibited_features\": ");
    try appendWorkflowFeatureChecksJson(allocator, &output, workflow_yml, prohibited_workflow_features, false);
    try output.appendSlice(allocator, ",\n  \"allowed_future_workflow_patch_scope\": ");
    try appendStringArray(allocator, &output, allowed_future_workflow_patch_scope);
    try output.appendSlice(allocator, ",\n  \"disallowed_future_workflow_patch_scope\": ");
    try appendStringArray(allocator, &output, disallowed_future_workflow_patch_scope);
    try output.appendSlice(allocator, ",\n  \"artifact_upload_policy\": ");
    try appendArtifactUploadPolicyJson(allocator, &output, preview.artifact_upload_policy);
    try output.appendSlice(allocator, ",\n  \"artifact_candidates\": ");
    try appendArtifactCandidatesJson(allocator, &output, preview.artifact_candidates);
    try output.appendSlice(allocator, ",\n  \"cluster_release_gate_assumptions\": ");
    try appendStringArray(allocator, &output, cluster_release_gate_assumptions);
    try output.appendSlice(allocator, ",\n  \"checks\": ");
    try appendChecksJson(allocator, &output, result.checks);
    try output.appendSlice(allocator, ",\n  \"implementation_gates\": ");
    try appendStringArray(allocator, &output, implementation_gates);
    try output.appendSlice(allocator, ",\n  \"non_goals\": ");
    try appendStringArray(allocator, &output, non_goals);
    try output.appendSlice(allocator, ",\n  \"blocked_claims\": ");
    try appendStringArray(allocator, &output, blockedClaims(preview));
    try output.appendSlice(allocator, ",\n  \"required_verification_commands\": ");
    try appendStringArray(allocator, &output, required_verification_commands);
    try output.appendSlice(allocator, ",\n  \"verified_commands\": ");
    try appendStringArray(allocator, &output, options.verified_commands);
    try output.appendSlice(allocator, ",\n  \"output_paths\": { \"json\": ");
    try appendJsonString(allocator, &output, paths.json_path);
    try output.appendSlice(allocator, ", \"text\": ");
    try appendJsonString(allocator, &output, paths.text_path);
    try output.appendSlice(allocator, " },\n  \"agent_guidance\": ");
    try appendStringArray(allocator, &output, agentGuidance(result.status));
    try output.appendSlice(allocator, "\n}\n");

    return output.toOwnedSlice(allocator);
}

fn formatBoundaryText(
    allocator: std.mem.Allocator,
    options: Options,
    preview: CiArtifactPreviewArtifact,
    workflow_digest: []const u8,
    result: BoundaryResult,
    paths: OutputPaths,
) ![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "zigeffect production telemetry CI harness boundary\n");
    try output.print(allocator, "schema: {s}\n", .{production_telemetry_ci_harness_boundary_schema});
    try output.print(allocator, "source CI artifact preview: {s}\n", .{options.ci_preview_path});
    try output.print(allocator, "source workbench preview: {s}\n", .{preview.source_workbench_preview});
    try output.print(allocator, "workflow path: {s}\n", .{options.workflow_path});
    try output.print(allocator, "workflow digest: {s}\n", .{workflow_digest});
    try output.print(allocator, "decision: {s}\n", .{decisionText(options.decision)});
    try output.print(allocator, "ci_harness_boundary_status: {s}\n", .{boundaryStatusText(result.status)});
    try output.print(allocator, "ready_for_next_branch: {}\n", .{result.ready_for_next_branch});
    try output.print(allocator, "reviewed_by: {s}\n", .{options.reviewed_by});
    try output.print(allocator, "policy: {s}\n", .{options.policy});
    try output.print(allocator, "reason: {s}\n", .{options.reason});
    try output.print(allocator, "applied: {}\n", .{applied});
    try output.print(allocator, "mutation_authority: {s}\n", .{mutation_authority});
    try output.print(allocator, "ci harness boundary enabled: {}\n", .{ci_harness_boundary_enabled});
    try output.print(allocator, "ci upload enabled: {}\n", .{ci_upload_enabled});
    try output.print(allocator, "ci upload execution enabled: {}\n", .{ci_upload_execution_enabled});
    try output.print(allocator, "ci workflow mutation enabled: {}\n", .{ci_workflow_mutation_enabled});
    try output.print(allocator, "ci gate enabled: {}\n", .{ci_gate_enabled});
    try output.print(allocator, "runtime pipeline enabled: {}\n", .{runtime_pipeline_enabled});
    try output.print(allocator, "durable write enabled: {}\n", .{durable_write_enabled});
    try output.print(allocator, "nendb write enabled: {}\n", .{nendb_write_enabled});
    try output.print(allocator, "source branch: {s}\n", .{source_branch});
    try output.print(allocator, "recommendation: {s}\n", .{recommendation});
    try output.print(allocator, "next branch if ready: {s}\n", .{next_branch_if_ready});
    try output.print(allocator, "json output: {s}\n", .{paths.json_path});
    try output.print(allocator, "text output: {s}\n\n", .{paths.text_path});

    try output.appendSlice(allocator, "checks:\n");
    for (result.checks) |check| {
        try output.print(allocator, "- {s}: {s} - {s}\n", .{ check.id, checkStatusText(check.status), check.detail });
    }
    try output.append(allocator, '\n');

    try appendTextList(allocator, &output, "cluster release gate assumptions", cluster_release_gate_assumptions);
    try appendTextList(allocator, &output, "allowed future workflow patch scope", allowed_future_workflow_patch_scope);
    try appendTextList(allocator, &output, "disallowed future workflow patch scope", disallowed_future_workflow_patch_scope);
    try appendTextList(allocator, &output, "implementation gates", implementation_gates);
    try appendTextList(allocator, &output, "non-goals", non_goals);
    try appendTextList(allocator, &output, "blocked claims", blockedClaims(preview));
    try appendTextList(allocator, &output, "required verification commands", required_verification_commands);
    try appendTextList(allocator, &output, "verified commands", options.verified_commands);
    try appendTextList(allocator, &output, "agent guidance", agentGuidance(result.status));

    return output.toOwnedSlice(allocator);
}

fn appendSourceChecksJson(allocator: std.mem.Allocator, output: *std.ArrayList(u8), checks: []const SourceCheck) !void {
    try output.append(allocator, '[');
    for (checks, 0..) |check, index| {
        if (index > 0) try output.appendSlice(allocator, ", ");
        try output.appendSlice(allocator, "{ \"name\": ");
        try appendJsonString(allocator, output, check.name);
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

fn appendArtifactUploadPolicyJson(allocator: std.mem.Allocator, output: *std.ArrayList(u8), policy: ArtifactUploadPolicy) !void {
    try output.appendSlice(allocator, "{ \"mode\": ");
    try appendJsonString(allocator, output, policy.mode);
    try output.print(allocator, ", \"failure_only\": {}, ", .{policy.failure_only});
    try output.print(allocator, "\"retention_days\": {}, ", .{policy.retention_days});
    try output.appendSlice(allocator, "\"allowed_extensions\": ");
    try appendStringArray(allocator, output, policy.allowed_extensions);
    try output.print(allocator, ", \"public_upload_claim\": {}, ", .{policy.public_upload_claim});
    try output.print(allocator, "\"ci_gate_claim\": {}", .{policy.ci_gate_claim});
    try output.appendSlice(allocator, " }");
}

fn appendArtifactCandidatesJson(allocator: std.mem.Allocator, output: *std.ArrayList(u8), candidates: []const ArtifactCandidate) !void {
    try output.append(allocator, '[');
    for (candidates, 0..) |candidate, index| {
        if (index > 0) try output.appendSlice(allocator, ", ");
        try output.appendSlice(allocator, "{ \"id\": ");
        try appendJsonString(allocator, output, candidate.id);
        try output.appendSlice(allocator, ", \"path\": ");
        try appendJsonString(allocator, output, candidate.path);
        try output.appendSlice(allocator, ", \"extension\": ");
        try appendJsonString(allocator, output, candidate.extension);
        try output.print(allocator, ", \"failure_only\": {}, ", .{candidate.failure_only});
        try output.print(allocator, "\"redaction_required\": {}, ", .{candidate.redaction_required});
        try output.print(allocator, "\"public_upload_allowed\": {}", .{candidate.public_upload_allowed});
        try output.appendSlice(allocator, " }");
    }
    try output.append(allocator, ']');
}

fn appendChecksJson(allocator: std.mem.Allocator, output: *std.ArrayList(u8), checks: []const BoundaryCheck) !void {
    try output.append(allocator, '[');
    for (checks, 0..) |check, index| {
        if (index > 0) try output.appendSlice(allocator, ", ");
        try output.appendSlice(allocator, "{ \"id\": ");
        try appendJsonString(allocator, output, check.id);
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

fn blockedClaims(preview: CiArtifactPreviewArtifact) []const []const u8 {
    if (preview.blocked_claims.len > 0) return preview.blocked_claims;
    return blocked_claims;
}

fn agentGuidance(status: BoundaryStatus) []const []const u8 {
    return switch (status) {
        .ready => &.{
            "Ready CI harness boundary evidence permits starting the CI archive application branch only.",
            "Use the workflow checks and cluster release-gate assumptions to propose a minimal archive-only application.",
            "Do not infer workflow mutation artifact upload execution CI gates live telemetry durable writes NenDB writes hosted dashboards production cluster readiness or mutation authority.",
        },
        .blocked => &.{
            "Blocked CI harness boundary evidence must not start archive application work.",
            "Repair source preview evidence workflow required features prohibited workflow features or verification evidence first.",
            "Do not treat a boundary report as CI upload execution or telemetry gate enablement.",
        },
    };
}

fn usage() []const u8 {
    return "usage: zig build causal-production-telemetry-ci-harness-boundary -- --from-ci-preview <ci-artifact-preview.json> [--workflow <workflow.yml>] approve|reject --reason <reason> [--by <actor>] [--policy <policy>] [--verified-command <command>]... [--out-prefix <path-prefix>]\n";
}

fn failUsage(err: anyerror) noreturn {
    std.debug.print("causal-production-telemetry-ci-harness-boundary error: {s}\n{s}", .{ @errorName(err), usage() });
    std.process.exit(2);
}

fn readRequiredArtifact(io: std.Io, allocator: std.mem.Allocator, path: []const u8, missing_error: anyerror) ![]const u8 {
    return std.Io.Dir.cwd().readFileAlloc(io, path, allocator, .limited(1024 * 1024)) catch |err| switch (err) {
        error.FileNotFound => missing_error,
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
    const source_ci_preview_json = try readRequiredArtifact(init.io, allocator, options.ci_preview_path, error.MissingCiPreviewInput);
    defer allocator.free(source_ci_preview_json);
    const workflow_yml = try readRequiredArtifact(init.io, allocator, options.workflow_path, error.MissingWorkflowInput);
    defer allocator.free(workflow_yml);

    const reports = try formatReports(allocator, .{
        .options = options,
        .source_ci_preview_json = source_ci_preview_json,
        .workflow_yml = workflow_yml,
    });
    defer reports.deinit(allocator);

    const paths = try outputPathsForOptions(allocator, options);
    defer paths.deinit(allocator);

    try writeArtifact(init.io, paths.json_path, reports.json);
    try writeArtifact(init.io, paths.text_path, reports.text);
    std.debug.print("{s}", .{reports.text});
}

const implementation_gates: []const []const u8 = &.{
    "source CI artifact preview is ready",
    "existing causal workflow required features are present",
    "existing causal workflow prohibited features are absent",
    "cluster release-gate assumptions are recorded",
    "CI upload execution remains disabled",
    "CI workflow mutation remains disabled",
    "CI gates remain disabled",
    "durable writes and NenDB writes remain disabled",
};

const non_goals: []const []const u8 = &.{
    "Modify .github/workflows/zigeffect-causal.yml",
    "Create a new GitHub Actions workflow",
    "Enable CI artifact upload execution for telemetry-specific artifacts",
    "Enable CI telemetry gate enforcement",
    "Configure GitHub secrets or write permissions",
    "Runtime telemetry ingestion or instrumentation changes",
    "Live exporter network send collector endpoint configuration or OTLP serialization",
    "Durable production writes or NenDB writes",
    "Production cluster orchestration or hosted dashboard claims",
    "React or alternate renderer work",
    "Non-NenDB durable adapter work",
    "Cockroach adapter work",
};

const blocked_claims: []const []const u8 = &.{
    "ci-artifact-upload-enabled",
    "ci-upload-execution-enabled",
    "ci-workflow-mutated",
    "ci-telemetry-gate",
    "runtime-pipeline-enabled",
    "live-exporter-enabled",
    "network-send-enabled",
    "collector-endpoint-configured",
    "otlp-serialization-enabled",
    "durable-production-write-enabled",
    "nendb-write-enabled",
    "production-cluster-ready",
    "hosted-dashboard-production-ready",
    "mutation-authority-granted",
    "react-or-alternate-renderer",
    "non-nendb-durable-storage",
    "cockroach-adapter-work",
};

const cluster_release_gate_assumptions: []const []const u8 = &.{
    "zig build release-gate --summary none is the clustering-aware CI execution body",
    "release-gate depends on the main test step public API review storage conformance property crash testing performance bounds examples causal-test causal-artifacts and release-gate reports",
    "examples include multi-runner cluster and cluster workflow migration tests",
    "the boundary does not start cluster daemons provision infrastructure run production shards or claim production cluster readiness",
};

const allowed_future_workflow_patch_scope: []const []const u8 = &.{
    "add telemetry-specific preview artifact generation after reviewed boundary evidence",
    "add archive paths for generated telemetry CI boundary or preview artifacts",
    "keep upload failure-only",
    "keep retention bounded at fourteen days unless a later retention policy updates it",
    "keep missing files ignored for preview-only evidence",
    "keep permissions contents read",
    "keep secrets absent",
    "keep gates disabled",
};

const disallowed_future_workflow_patch_scope: []const []const u8 = &.{
    "CI gate enforcement",
    "required status checks",
    "production telemetry threshold failures",
    "live exporter network sends",
    "collector endpoint configuration",
    "secret use",
    "write permissions",
    "NenDB writes",
    "durable production writes",
    "hosted dashboard deployment",
    "production cluster orchestration",
    "app or registry mutation authority",
};

test "ci harness boundary schema and branch constants are stable" {
    try std.testing.expectEqualStrings("zigeffect.causal.production-telemetry-ci-harness-boundary.v1", production_telemetry_ci_harness_boundary_schema);
    try std.testing.expectEqual(@as(u32, 1), production_telemetry_ci_harness_boundary_schema_version);
    try std.testing.expectEqualStrings("codex/zigeffect-causal-production-telemetry-ci-harness-boundary", source_branch);
    try std.testing.expectEqualStrings("start-production-telemetry-ci-archive-application", recommendation);
    try std.testing.expectEqualStrings("codex/zigeffect-causal-production-telemetry-ci-archive-application", next_branch_if_ready);
    try std.testing.expect(containsString(required_verification_commands, "zig build causal-production-telemetry-ci-artifact-preview"));
    try std.testing.expect(containsString(required_verification_commands, "zig build release-gate --summary none"));
}

test "parses ci harness boundary options with optional workflow and verified commands" {
    var options = try parseOptions(std.testing.allocator, &.{
        "zigeffect-causal-production-telemetry-ci-harness-boundary",
        "--from-ci-preview",
        ".zig-cache/causal-artifacts/ci-preview.json",
        "--workflow",
        "../../.github/workflows/zigeffect-causal.yml",
        "approve",
        "--reason",
        "CI harness boundary reviewed",
        "--by",
        "codex",
        "--policy",
        "manual-production-telemetry-ci-harness-boundary",
        "--verified-command",
        "zig build release-gate --summary none",
        "--out-prefix",
        ".zig-cache/causal-artifacts/custom-ci-harness-boundary",
    });
    defer options.deinit(std.testing.allocator);

    try std.testing.expectEqual(Decision.approve, options.decision);
    try std.testing.expectEqualStrings(".zig-cache/causal-artifacts/ci-preview.json", options.ci_preview_path);
    try std.testing.expectEqualStrings("../../.github/workflows/zigeffect-causal.yml", options.workflow_path);
    try std.testing.expectEqualStrings("CI harness boundary reviewed", options.reason);
    try std.testing.expectEqualStrings("codex", options.reviewed_by);
    try std.testing.expectEqualStrings("manual-production-telemetry-ci-harness-boundary", options.policy);
    try std.testing.expectEqual(@as(usize, 1), options.verified_commands.len);
    try std.testing.expectEqualStrings("zig build release-gate --summary none", options.verified_commands[0]);
    try std.testing.expectEqualStrings(".zig-cache/causal-artifacts/custom-ci-harness-boundary", options.out_prefix.?);
}

test "ready and blocked ci harness boundary reports preserve record-only authority" {
    const ready = try formatReports(std.testing.allocator, .{
        .options = .{
            .ci_preview_path = ".zig-cache/causal-artifacts/ci-preview.json",
            .workflow_path = ".github/workflows/zigeffect-causal.yml",
            .decision = .approve,
            .reason = "CI harness boundary reviewed",
            .verified_commands = required_verification_commands,
        },
        .source_ci_preview_json = sample_ci_artifact_preview_json,
        .workflow_yml = sample_workflow_yml,
    });
    defer ready.deinit(std.testing.allocator);

    try std.testing.expect(std.mem.indexOf(u8, ready.json, "\"schema\": \"zigeffect.causal.production-telemetry-ci-harness-boundary.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, ready.json, "\"ci_harness_boundary_status\": \"ready\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, ready.json, "\"ready_for_next_branch\": true") != null);
    try std.testing.expect(std.mem.indexOf(u8, ready.json, "\"ci_harness_boundary_enabled\": true") != null);
    try std.testing.expect(std.mem.indexOf(u8, ready.json, "\"ci_upload_enabled\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, ready.json, "\"ci_upload_execution_enabled\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, ready.json, "\"ci_workflow_mutation_enabled\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, ready.json, "\"ci_gate_enabled\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, ready.json, "\"workflow_digest\": \"sha256:") != null);
    try std.testing.expect(std.mem.indexOf(u8, ready.json, "\"id\": \"release-gate-runs\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, ready.json, "\"id\": \"no-secrets-usage\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, ready.json, "\"cluster_release_gate_assumptions\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, ready.json, "\"next_branch_if_ready\": \"codex/zigeffect-causal-production-telemetry-ci-archive-application\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, ready.text, "ci_harness_boundary_status: ready") != null);
    try std.testing.expect(std.mem.indexOf(u8, ready.text, "ci workflow mutation enabled: false") != null);

    const blocked = try formatReports(std.testing.allocator, .{
        .options = .{
            .ci_preview_path = ".zig-cache/causal-artifacts/ci-preview.json",
            .workflow_path = ".github/workflows/zigeffect-causal.yml",
            .decision = .reject,
            .reason = "negative CI harness boundary path",
        },
        .source_ci_preview_json = sample_ci_artifact_preview_json,
        .workflow_yml = sample_workflow_yml,
    });
    defer blocked.deinit(std.testing.allocator);

    try std.testing.expect(std.mem.indexOf(u8, blocked.json, "\"ci_harness_boundary_status\": \"blocked\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, blocked.json, "\"ready_for_next_branch\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, blocked.json, "\"ci_upload_execution_enabled\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, blocked.text, "ci_harness_boundary_status: blocked") != null);
}

test "workflow prohibited features block the harness boundary" {
    const blocked = try formatReports(std.testing.allocator, .{
        .options = .{
            .ci_preview_path = ".zig-cache/causal-artifacts/ci-preview.json",
            .workflow_path = ".github/workflows/zigeffect-causal.yml",
            .decision = .approve,
            .reason = "CI harness boundary reviewed",
            .verified_commands = required_verification_commands,
        },
        .source_ci_preview_json = sample_ci_artifact_preview_json,
        .workflow_yml = sample_workflow_yml ++ "\n      - run: echo ${{ secrets.PRODUCTION_TELEMETRY_TOKEN }}\n",
    });
    defer blocked.deinit(std.testing.allocator);

    try std.testing.expect(std.mem.indexOf(u8, blocked.json, "\"ci_harness_boundary_status\": \"blocked\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, blocked.json, "\"id\": \"no-secrets-usage\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, blocked.json, "\"status\": \"fail\"") != null);
}

const sample_ci_artifact_preview_json =
    \\{
    \\  "schema": "zigeffect.causal.production-telemetry-ci-artifact-preview.v1",
    \\  "schema_version": 1,
    \\  "source_workbench_preview": ".zig-cache/causal-artifacts/workbench-preview.json",
    \\  "source_retention": ".zig-cache/causal-artifacts/nendb-retention.json",
    \\  "source_local_pipeline": ".zig-cache/causal-artifacts/local-pipeline.json",
    \\  "source_boundary": ".zig-cache/causal-artifacts/exporter-boundary.json",
    \\  "source_proposal": ".zig-cache/causal-artifacts/implementation-proposal.json",
    \\  "source_readiness": ".zig-cache/causal-artifacts/readiness-review.json",
    \\  "source_fixtures": ".zig-cache/causal-artifacts/capture-fixtures.json",
    \\  "decision": "approve",
    \\  "ci_artifact_preview_status": "ready",
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
    \\  "ci_gate_enabled": false,
    \\  "ci_upload_enabled": false,
    \\  "ci_workflow_mutation_enabled": false,
    \\  "ci_artifact_preview_enabled": true,
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
    \\  "checks": [
    \\    { "name": "decision-approved", "status": "pass", "detail": "review approved" },
    \\    { "name": "upload-preview-only", "status": "pass", "detail": "CI upload workflow mutation and gates remain disabled" }
    \\  ],
    \\  "required_verification_commands": [
    \\    "zig build causal-production-telemetry-workbench-readonly-preview",
    \\    "zig build causal-artifacts"
    \\  ],
    \\  "verified_commands": [
    \\    "zig build causal-production-telemetry-workbench-readonly-preview",
    \\    "zig build causal-artifacts"
    \\  ],
    \\  "blocked_claims": [
    \\    "ci-artifact-upload-enabled",
    \\    "ci-workflow-mutated",
    \\    "ci-telemetry-gate"
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
    \\      - name: Capture PR base causal baselines
    \\        if: ${{ github.event_name == 'pull_request' }}
    \\        run: |
    \\          zig build causal-test
    \\          zig build causal-dev-loop -- baseline package-tests
    \\      - name: Print causal artifact manifest
    \\        run: zig build causal-artifacts
    \\      - name: Run release gate
    \\        run: zig build release-gate --summary none
    \\      - name: Write causal CI handoff
    \\        if: ${{ failure() }}
    \\        run: zig build causal-ci-handoff
    \\      - name: Upload causal artifacts on failure
    \\        if: ${{ failure() }}
    \\        uses: actions/upload-artifact@v4
    \\        with:
    \\          if-no-files-found: ignore
    \\          retention-days: 14
    \\          path: |
    \\            packages/zigeffect/.zig-cache/causal-artifacts/*.txt
    \\            packages/zigeffect/.zig-cache/causal-artifacts/*.json
    \\            packages/zigeffect/.zig-cache/causal-artifacts/*.dot
    \\            packages/zigeffect/.zig-cache/release-gate/*.txt
    \\            packages/zigeffect/.zig-cache/release-gate/*.json
;
