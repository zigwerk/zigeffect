const std = @import("std");

pub const production_telemetry_ci_gate_application_boundary_schema = "zigeffect.causal.production-telemetry-ci-gate-application-boundary.v1";
pub const production_telemetry_ci_gate_application_boundary_schema_version: u32 = 1;
pub const source_branch = "codex/zigeffect-causal-production-telemetry-ci-gate-application-boundary";
pub const recommendation = "start-production-telemetry-ci-gate-dry-run-policy";
pub const next_branch_if_applied = "codex/zigeffect-causal-production-telemetry-ci-gate-dry-run-policy";

const gate_readiness_schema = "zigeffect.causal.production-telemetry-ci-gate-readiness.v1";
const generated_by = "causal-production-telemetry-ci-gate-application-boundary";

const required_verification_commands: []const []const u8 = &.{
    "zig build causal-production-telemetry-ci-gate-readiness",
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

const Mode = enum { plan, record_applied };
const GateApplicationStatus = enum { planned, applied, blocked };
const CheckStatus = enum { pass, fail, skipped };

const Options = struct {
    gate_readiness_path: []const u8,
    mode: Mode,
    reviewed_by: []const u8 = "ci-gate-application-boundary-reviewer",
    policy: []const u8 = "manual-production-telemetry-ci-gate-application-boundary",
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

const BoundaryInput = struct {
    options: Options,
    source_gate_readiness_json: []const u8,
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

const SourceCheck = struct {
    name: []const u8 = "",
    id: []const u8 = "",
    status: []const u8,
    detail: []const u8 = "",
};

const SourceReadinessDimension = struct {
    id: []const u8 = "",
    required: bool = false,
    evidence: []const u8 = "",
};

const SourceCandidateGateSignal = struct {
    id: []const u8 = "",
    enforcement_enabled: bool = true,
    source: []const u8 = "",
    denied_claim: []const u8 = "",
};

const SourceNegativeFixture = struct {
    id: []const u8 = "",
    artifact_state: []const u8 = "",
    decision: []const u8 = "",
    failed_gate: []const u8 = "",
    reason: []const u8 = "",
};

const GateReadinessArtifact = struct {
    schema: []const u8,
    schema_version: u32,
    source_archive_evidence_policy: []const u8 = "",
    source_policy_status: []const u8 = "",
    source_ci_archive_application: []const u8 = "",
    source_workflow_digest: []const u8 = "",
    decision: []const u8,
    gate_readiness_status: []const u8,
    ready_for_next_branch: bool,
    reviewed_by: []const u8 = "",
    policy: []const u8 = "",
    reason: []const u8 = "",
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
    readiness_dimensions: []const SourceReadinessDimension = &.{},
    candidate_gate_signals: []const SourceCandidateGateSignal = &.{},
    gate_semantics: []const []const u8 = &.{},
    negative_fixtures: []const SourceNegativeFixture = &.{},
    checks: []const SourceCheck = &.{},
    required_verification_commands: []const []const u8 = &.{},
    verified_commands: []const []const u8 = &.{},
    blocked_claims: []const []const u8 = &.{},
};

const BoundaryCheck = struct {
    name: []const u8,
    status: CheckStatus,
    detail: []const u8,
};

const BoundaryResult = struct {
    status: GateApplicationStatus,
    applied: bool,
    mutation_authority: []const u8,
    checks: []const BoundaryCheck,

    fn deinit(self: BoundaryResult, allocator: std.mem.Allocator) void {
        if (self.checks.len > 0) allocator.free(self.checks);
    }
};

const WorkflowTextCheck = struct {
    id: []const u8,
    needle: []const u8,
    detail: []const u8,
};

const NegativeFixture = struct {
    id: []const u8,
    artifact_state: []const u8,
    decision: []const u8,
    failed_gate: []const u8,
    reason: []const u8,
};

const required_workflow_features: []const WorkflowTextCheck = &.{
    .{ .id = "workflow-name", .needle = "name: zigeffect causal", .detail = "causal workflow identity is preserved" },
    .{ .id = "pull-request-trigger", .needle = "pull_request:", .detail = "pull request trigger exists" },
    .{ .id = "push-master-trigger", .needle = "- master", .detail = "push trigger targets master" },
    .{ .id = "workflow-dispatch-trigger", .needle = "workflow_dispatch:", .detail = "manual dispatch trigger exists" },
    .{ .id = "permissions-read", .needle = "contents: read", .detail = "workflow permissions remain read-only" },
    .{ .id = "checkout-v4", .needle = "actions/checkout@v4", .detail = "workflow checks out source" },
    .{ .id = "setup-zig", .needle = "mlugg/setup-zig@v2.2.1", .detail = "workflow installs Zig" },
    .{ .id = "zig-016", .needle = "version: 0.16.0", .detail = "workflow uses Zig 0.16.0" },
    .{ .id = "base-causal-test", .needle = "zig build causal-test", .detail = "PR baseline runs causal-test" },
    .{ .id = "causal-artifacts-manifest", .needle = "zig build causal-artifacts", .detail = "workflow prints causal artifact manifest" },
    .{ .id = "release-gate-runs", .needle = "zig build release-gate --summary none", .detail = "workflow runs clustering-aware release gate" },
    .{ .id = "release-gate-report", .needle = "zig build release-gate-report", .detail = "workflow writes release-gate report evidence" },
    .{ .id = "failure-handoff", .needle = "zig build causal-ci-handoff", .detail = "workflow writes failure handoff" },
    .{ .id = "failure-only-upload", .needle = "if: ${{ failure() }}", .detail = "handoff and upload remain failure-only" },
    .{ .id = "upload-artifact-v4", .needle = "actions/upload-artifact@v4", .detail = "workflow uses GitHub artifact upload action" },
    .{ .id = "ignore-missing-files", .needle = "if-no-files-found: ignore", .detail = "missing preview files remain non-fatal" },
    .{ .id = "retention-fourteen-days", .needle = "retention-days: 14", .detail = "artifact retention is bounded" },
    .{ .id = "causal-txt-glob", .needle = "packages/zigeffect/.zig-cache/causal-artifacts/*.txt", .detail = "causal text artifacts are archived" },
    .{ .id = "causal-json-glob", .needle = "packages/zigeffect/.zig-cache/causal-artifacts/*.json", .detail = "causal JSON artifacts are archived" },
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
    .{ .id = "no-required-status-check", .needle = "required_status_check", .detail = "workflow does not configure required status checks" },
    .{ .id = "no-telemetry-gate-step", .needle = "production telemetry gate enabled", .detail = "workflow does not claim telemetry gate enforcement" },
};

const application_boundary_rules: []const []const u8 = &.{
    "Plan mode records a reviewed boundary proposal only and never enables CI gate enforcement.",
    "record-applied requires workflow-change before evidence after evidence after-workflow content safe workflow checks and full verification commands.",
    "Applied records are evidence records only; this tool does not mutate workflows.",
    "Future dry-run policy work may evaluate candidate signals without creating required checks.",
    "CI evidence supports agent triage but not production health capacity customer impact deployment success or cluster readiness claims.",
};

const denied_application_claims: []const []const u8 = &.{
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

const negative_fixtures: []const NegativeFixture = &.{
    .{ .id = "blocked-source-gate-readiness-denied", .artifact_state = "gate_readiness_status=blocked", .decision = "deny", .failed_gate = "source-gate-readiness-ready", .reason = "blocked readiness cannot feed application boundary" },
    .{ .id = "missing-source-approval-denied", .artifact_state = "decision=reject", .decision = "deny", .failed_gate = "source-approved", .reason = "source readiness must be approved" },
    .{ .id = "missing-source-release-gate-verification-denied", .artifact_state = "source verification incomplete", .decision = "deny", .failed_gate = "source-verification-recorded", .reason = "release-gate and release-gate-report evidence must be present" },
    .{ .id = "plan-applied-claim-denied", .artifact_state = "mode=plan applied=true", .decision = "deny", .failed_gate = "plan-is-not-applied", .reason = "plan mode is never applied" },
    .{ .id = "missing-workflow-change-denied", .artifact_state = "record-applied workflow_changes=[]", .decision = "deny", .failed_gate = "workflow-change-present", .reason = "reviewed workflow change evidence is required" },
    .{ .id = "missing-before-evidence-denied", .artifact_state = "record-applied before=[]", .decision = "deny", .failed_gate = "before-evidence-present", .reason = "before evidence is required" },
    .{ .id = "missing-after-evidence-denied", .artifact_state = "record-applied after=[]", .decision = "deny", .failed_gate = "after-evidence-present", .reason = "after evidence is required" },
    .{ .id = "missing-after-workflow-denied", .artifact_state = "record-applied workflow_after=null", .decision = "deny", .failed_gate = "after-workflow-present", .reason = "after-workflow text is required" },
    .{ .id = "unsafe-after-workflow-secrets-denied", .artifact_state = "secrets.* present", .decision = "deny", .failed_gate = "after-workflow-safe", .reason = "workflow must not reference secrets" },
    .{ .id = "unsafe-after-workflow-required-status-denied", .artifact_state = "required_status_check present", .decision = "deny", .failed_gate = "after-workflow-safe", .reason = "required checks are out of scope" },
    .{ .id = "missing-post-verification-denied", .artifact_state = "verified commands incomplete", .decision = "deny", .failed_gate = "post-verification-recorded", .reason = "all post-application verification commands are required" },
    .{ .id = "ci-gate-enforcement-enabled-denied", .artifact_state = "ci_gate_enforcement_enabled=true", .decision = "deny", .failed_gate = "no-ci-gate-enforcement", .reason = "this branch does not enable gates" },
    .{ .id = "production-health-claim-denied", .artifact_state = "production_health=proven", .decision = "deny", .failed_gate = "ci-not-production", .reason = "CI evidence is not live production telemetry" },
    .{ .id = "non-nendb-durable-scope-denied", .artifact_state = "durable_adapter=non-nendb", .decision = "deny", .failed_gate = "nendb-only", .reason = "durable direction remains NenDB adapter only" },
    .{ .id = "alternate-renderer-scope-denied", .artifact_state = "renderer=react", .decision = "deny", .failed_gate = "solid-webui", .reason = "workbench direction remains SolidJS inside zig-webui" },
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
        error.MissingGateReadinessInput, error.MissingWorkflowAfterInput => failUsage(err),
        else => return err,
    };
}

fn parseOptions(allocator: std.mem.Allocator, args: []const []const u8) !Options {
    if (args.len < 2) return error.MissingGateReadinessPath;
    if (!std.mem.eql(u8, args[1], "--from-gate-readiness")) return error.UnknownFlag;
    if (args.len < 3) return error.MissingGateReadinessPath;
    const gate_readiness_path = args[2];
    if (!std.mem.endsWith(u8, gate_readiness_path, ".json")) return error.InvalidGateReadinessPath;
    if (args.len < 4) return error.MissingMode;
    const mode = try parseMode(args[3]);

    var reviewed_by: []const u8 = "ci-gate-application-boundary-reviewer";
    var policy: []const u8 = "manual-production-telemetry-ci-gate-application-boundary";
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
        .gate_readiness_path = gate_readiness_path,
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

fn statusText(status: GateApplicationStatus) []const u8 {
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
        if (!std.mem.endsWith(u8, options.gate_readiness_path, ".json")) return error.InvalidGateReadinessPath;
        if (std.mem.endsWith(u8, options.gate_readiness_path, "-ci-gate-readiness.json")) {
            const suffix_len = "-ci-gate-readiness.json".len;
            break :blk try std.fmt.allocPrint(allocator, "{s}-ci-gate-application-boundary", .{options.gate_readiness_path[0 .. options.gate_readiness_path.len - suffix_len]});
        }
        const base = options.gate_readiness_path[0 .. options.gate_readiness_path.len - ".json".len];
        break :blk try std.fmt.allocPrint(allocator, "{s}-ci-gate-application-boundary", .{base});
    };
    defer allocator.free(prefix);

    return .{
        .json_path = try std.fmt.allocPrint(allocator, "{s}.json", .{prefix}),
        .text_path = try std.fmt.allocPrint(allocator, "{s}.txt", .{prefix}),
    };
}

fn formatReports(allocator: std.mem.Allocator, input: BoundaryInput) !BoundaryReports {
    var parsed = try std.json.parseFromSlice(GateReadinessArtifact, allocator, input.source_gate_readiness_json, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();

    const paths = try outputPathsForOptions(allocator, input.options);
    defer paths.deinit(allocator);

    const after_workflow_digest = if (input.workflow_after_yml) |workflow_yml|
        try workflowDigest(allocator, workflow_yml)
    else
        try allocator.dupe(u8, "");
    defer allocator.free(after_workflow_digest);

    const result = try evaluateBoundary(allocator, input.options, parsed.value, input.workflow_after_yml);
    defer result.deinit(allocator);

    const json = try formatBoundaryJson(allocator, input.options, parsed.value, input.workflow_after_yml, after_workflow_digest, result, paths);
    errdefer allocator.free(json);
    const text = try formatBoundaryText(allocator, input.options, parsed.value, after_workflow_digest, result, paths);
    errdefer allocator.free(text);

    return .{ .json = json, .text = text };
}

fn evaluateBoundary(
    allocator: std.mem.Allocator,
    options: Options,
    source: GateReadinessArtifact,
    workflow_after_yml: ?[]const u8,
) !BoundaryResult {
    var checks = std.ArrayList(BoundaryCheck).empty;
    errdefer checks.deinit(allocator);

    try appendCheck(allocator, &checks, "source-gate-readiness-schema", if (std.mem.eql(u8, source.schema, gate_readiness_schema) and source.schema_version == 1) .pass else .fail, "source CI gate readiness schema is supported");
    try appendCheck(allocator, &checks, "source-gate-readiness-ready", if (std.mem.eql(u8, source.gate_readiness_status, "ready") and source.ready_for_next_branch) .pass else .fail, "source CI gate readiness is ready for this branch");
    try appendCheck(allocator, &checks, "source-approved", if (std.mem.eql(u8, source.decision, "approve")) .pass else .fail, "source CI gate readiness reviewer approved handoff");
    try appendCheck(allocator, &checks, "source-authority-disabled", if (sourceAuthorityDisabled(source)) .pass else .fail, "source keeps gate enforcement required checks workflow mutation upload execution runtime durable and NenDB authority disabled");
    try appendCheck(allocator, &checks, "source-catalogs-present", if (sourceCatalogsPresent(source)) .pass else .fail, "source readiness dimensions candidate signals gate semantics and negative fixtures are present");
    try appendCheck(allocator, &checks, "source-checks-passed", if (sourceChecksPassed(source.checks)) .pass else .fail, "source readiness checks passed");
    try appendCheck(allocator, &checks, "source-verification-recorded", if (sourceVerificationRecorded(source)) .pass else .fail, "source readiness recorded required verification commands");
    try appendCheck(allocator, &checks, "source-blocked-claims-carried", if (source.blocked_claims.len > 0) .pass else .fail, "source blocked claims are carried forward");

    if (options.mode == .plan) {
        try appendCheck(allocator, &checks, "plan-is-not-applied", .pass, "plan mode records a boundary proposal without applied state");
        try appendCheck(allocator, &checks, "workflow-change-present", .skipped, "plan mode does not claim workflow change evidence");
        try appendCheck(allocator, &checks, "before-evidence-present", .skipped, "plan mode does not claim before evidence");
        try appendCheck(allocator, &checks, "after-evidence-present", .skipped, "plan mode does not claim after evidence");
        try appendCheck(allocator, &checks, "post-verification-recorded", .skipped, "plan mode does not claim post-application verification");
        try appendCheck(allocator, &checks, "after-workflow-safe", if (workflow_after_yml) |workflow_yml| workflowSafetyStatus(workflow_yml) else .skipped, "optional after-workflow evidence preserves boundary constraints");

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
    try appendCheck(allocator, &checks, "after-workflow-safe", if (workflow_after_yml) |workflow_yml| workflowSafetyStatus(workflow_yml) else .fail, "after-workflow evidence preserves boundary constraints");

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

fn allChecksPassed(checks: []const BoundaryCheck) bool {
    for (checks) |check| {
        if (check.status != .pass) return false;
    }
    return true;
}

fn sourceAuthorityDisabled(source: GateReadinessArtifact) bool {
    return !source.applied and
        std.mem.eql(u8, source.mutation_authority, "none") and
        !source.ci_gate_enabled and
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

fn sourceCatalogsPresent(source: GateReadinessArtifact) bool {
    return source.readiness_dimensions.len > 0 and
        source.candidate_gate_signals.len > 0 and
        source.gate_semantics.len > 0 and
        source.negative_fixtures.len > 0;
}

fn sourceChecksPassed(checks: []const SourceCheck) bool {
    if (checks.len == 0) return false;
    for (checks) |check| {
        if (!std.mem.eql(u8, check.status, "pass")) return false;
    }
    return true;
}

fn sourceVerificationRecorded(source: GateReadinessArtifact) bool {
    return source.required_verification_commands.len > 0 and
        verifiedCommandsContainAll(source.verified_commands, source.required_verification_commands) and
        verifiedCommandsContainAll(source.verified_commands, &.{
            "zig build release-gate --summary none",
            "zig build release-gate-report",
        });
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

fn formatBoundaryJson(
    allocator: std.mem.Allocator,
    options: Options,
    source: GateReadinessArtifact,
    workflow_after_yml: ?[]const u8,
    after_workflow_digest: []const u8,
    result: BoundaryResult,
    paths: OutputPaths,
) ![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "{\n");
    try appendJsonField(allocator, &output, "schema", production_telemetry_ci_gate_application_boundary_schema, true);
    try output.appendSlice(allocator, "  \"schema_version\": 1,\n");
    try appendJsonField(allocator, &output, "source_ci_gate_readiness", options.gate_readiness_path, true);
    try appendJsonField(allocator, &output, "source_gate_readiness_status", source.gate_readiness_status, true);
    try appendJsonField(allocator, &output, "source_archive_evidence_policy", source.source_archive_evidence_policy, true);
    try appendJsonField(allocator, &output, "source_workflow_digest", source.source_workflow_digest, true);
    try appendJsonField(allocator, &output, "mode", modeText(options.mode), true);
    try appendJsonField(allocator, &output, "gate_application_status", statusText(result.status), true);
    try output.print(allocator, "  \"applied\": {},\n", .{result.applied});
    try appendJsonField(allocator, &output, "mutation_authority", result.mutation_authority, true);
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
    try appendJsonField(allocator, &output, "reviewed_by", options.reviewed_by, true);
    try appendJsonField(allocator, &output, "policy", options.policy, true);
    try appendJsonField(allocator, &output, "reason", options.reason, true);
    try output.appendSlice(allocator, "  \"workflow_after_path\": ");
    try appendOptionalJsonString(allocator, &output, options.workflow_after_path);
    try output.appendSlice(allocator, ",\n");
    try appendJsonField(allocator, &output, "after_workflow_digest", after_workflow_digest, true);
    try output.appendSlice(allocator, "  \"workflow_changes\": ");
    try appendStringArray(allocator, &output, options.workflow_changes);
    try output.appendSlice(allocator, ",\n  \"before_evidence\": ");
    try appendStringArray(allocator, &output, options.before_evidence);
    try output.appendSlice(allocator, ",\n  \"after_evidence\": ");
    try appendStringArray(allocator, &output, options.after_evidence);
    try output.appendSlice(allocator, ",\n  \"source_checks\": ");
    try appendSourceChecksJson(allocator, &output, source.checks);
    try output.appendSlice(allocator, ",\n  \"boundary_checks\": ");
    try appendChecksJson(allocator, &output, result.checks);
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
    try output.appendSlice(allocator, ",\n  \"application_boundary_rules\": ");
    try appendStringArray(allocator, &output, application_boundary_rules);
    try output.appendSlice(allocator, ",\n  \"denied_application_claims\": ");
    try appendStringArray(allocator, &output, denied_application_claims);
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
    try appendJsonFieldPrefixComma(allocator, &output, "next_branch_if_applied", next_branch_if_applied);
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
    source: GateReadinessArtifact,
    after_workflow_digest: []const u8,
    result: BoundaryResult,
    paths: OutputPaths,
) ![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "zigeffect production telemetry CI gate application boundary\n");
    try output.print(allocator, "schema: {s}\n", .{production_telemetry_ci_gate_application_boundary_schema});
    try output.print(allocator, "source CI gate readiness: {s}\n", .{options.gate_readiness_path});
    try output.print(allocator, "source gate readiness status: {s}\n", .{source.gate_readiness_status});
    try output.print(allocator, "source workflow digest: {s}\n", .{source.source_workflow_digest});
    try output.print(allocator, "after workflow digest: {s}\n", .{after_workflow_digest});
    try output.print(allocator, "mode: {s}\n", .{modeText(options.mode)});
    try output.print(allocator, "gate_application_status: {s}\n", .{statusText(result.status)});
    try output.print(allocator, "applied: {}\n", .{result.applied});
    try output.print(allocator, "mutation_authority: {s}\n", .{result.mutation_authority});
    try output.print(allocator, "ci gate enabled: {}\n", .{ci_gate_enabled});
    try output.print(allocator, "ci gate enforcement enabled: {}\n", .{ci_gate_enforcement_enabled});
    try output.print(allocator, "ci required status check enabled: {}\n", .{ci_required_status_check_enabled});
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
    try appendTextList(allocator, &output, "application boundary rules", application_boundary_rules);
    try appendTextList(allocator, &output, "denied application claims", denied_application_claims);
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

fn appendNegativeFixturesText(allocator: std.mem.Allocator, output: *std.ArrayList(u8)) !void {
    try output.appendSlice(allocator, "negative fixtures:\n");
    for (negative_fixtures) |fixture| {
        try output.print(allocator, "- {s}\n", .{fixture.id});
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

fn blockedClaims(source: GateReadinessArtifact) []const []const u8 {
    if (source.blocked_claims.len > 0) return source.blocked_claims;
    return denied_application_claims;
}

fn agentGuidance(status: GateApplicationStatus) []const []const u8 {
    return switch (status) {
        .planned => &.{
            "Use planned gate application boundary evidence to prepare a reviewed dry-run policy only.",
            "Do not claim CI gate enforcement required checks workflow mutation or applied gate state from plan mode.",
        },
        .applied => &.{
            "Use applied gate application boundary evidence to start CI gate dry-run policy work only.",
            "Cite workflow changes before evidence after evidence post-verification commands and source gate readiness.",
        },
        .blocked => &.{
            "Treat blocked gate application boundary evidence as a stop sign.",
            "Repair source readiness workflow evidence before/after evidence after-workflow safety or verification proof before continuing.",
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
    const source_gate_readiness_json = try readRequiredArtifact(init.io, allocator, options.gate_readiness_path, error.MissingGateReadinessInput);
    defer allocator.free(source_gate_readiness_json);
    const workflow_after_yml = if (options.workflow_after_path) |path|
        try readRequiredArtifact(init.io, allocator, path, error.MissingWorkflowAfterInput)
    else
        null;
    defer if (workflow_after_yml) |contents| allocator.free(contents);

    const reports = try formatReports(allocator, .{
        .options = options,
        .source_gate_readiness_json = source_gate_readiness_json,
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
    return "usage: zig build causal-production-telemetry-ci-gate-application-boundary -- --from-gate-readiness <ci-gate-readiness.json> plan|record-applied --reason <reason> [--workflow-after <workflow.yml>] [--by <actor>] [--policy <policy>] [--workflow-change <path-or-evidence>] [--before <evidence>] [--after <evidence>] [--verified-command <command>]... [--out-prefix <path-prefix>]\n";
}

fn failUsage(err: anyerror) noreturn {
    std.debug.print("causal-production-telemetry-ci-gate-application-boundary error: {s}\n{s}", .{ @errorName(err), usage() });
    std.process.exit(2);
}

fn freeSliceOnly(allocator: std.mem.Allocator, values: []const []const u8) void {
    if (values.len > 0) allocator.free(values);
}

test "ci gate application boundary schema and branch constants are stable" {
    try std.testing.expectEqualStrings("zigeffect.causal.production-telemetry-ci-gate-application-boundary.v1", production_telemetry_ci_gate_application_boundary_schema);
    try std.testing.expectEqual(@as(u32, 1), production_telemetry_ci_gate_application_boundary_schema_version);
    try std.testing.expectEqualStrings("codex/zigeffect-causal-production-telemetry-ci-gate-application-boundary", source_branch);
    try std.testing.expectEqualStrings("start-production-telemetry-ci-gate-dry-run-policy", recommendation);
    try std.testing.expectEqualStrings("codex/zigeffect-causal-production-telemetry-ci-gate-dry-run-policy", next_branch_if_applied);
    try std.testing.expect(containsString(required_verification_commands, "zig build causal-production-telemetry-ci-gate-readiness"));
    try std.testing.expect(containsString(required_verification_commands, "zig build release-gate-report"));
}

test "parses ci gate application boundary plan and record-applied options" {
    var plan_options = try parseOptions(std.testing.allocator, &.{
        "zigeffect-causal-production-telemetry-ci-gate-application-boundary",
        "--from-gate-readiness",
        ".zig-cache/causal-artifacts/ci-gate-readiness.json",
        "plan",
        "--reason",
        "CI gate application boundary planned",
        "--workflow-after",
        ".github/workflows/zigeffect-causal.yml",
        "--by",
        "codex",
        "--policy",
        "manual-production-telemetry-ci-gate-application-boundary",
        "--out-prefix",
        ".zig-cache/causal-artifacts/custom-ci-gate-application-boundary",
    });
    defer plan_options.deinit(std.testing.allocator);

    try std.testing.expectEqual(Mode.plan, plan_options.mode);
    try std.testing.expectEqualStrings(".zig-cache/causal-artifacts/ci-gate-readiness.json", plan_options.gate_readiness_path);
    try std.testing.expectEqualStrings(".github/workflows/zigeffect-causal.yml", plan_options.workflow_after_path.?);
    try std.testing.expectEqualStrings("codex", plan_options.reviewed_by);
    try std.testing.expectEqualStrings("manual-production-telemetry-ci-gate-application-boundary", plan_options.policy);
    try std.testing.expectEqualStrings(".zig-cache/causal-artifacts/custom-ci-gate-application-boundary", plan_options.out_prefix.?);

    var applied_options = try parseOptions(std.testing.allocator, &.{
        "zigeffect-causal-production-telemetry-ci-gate-application-boundary",
        "--from-gate-readiness",
        ".zig-cache/causal-artifacts/ci-gate-readiness.json",
        "record-applied",
        "--reason",
        "reviewed CI gate boundary change applied",
        "--workflow-after",
        ".github/workflows/zigeffect-causal.yml",
        "--workflow-change",
        ".github/workflows/zigeffect-causal.yml",
        "--before",
        "source readiness workflow digest",
        "--after",
        "post-change workflow review",
        "--verified-command",
        "zig build causal-production-telemetry-ci-gate-readiness",
    });
    defer applied_options.deinit(std.testing.allocator);

    try std.testing.expectEqual(Mode.record_applied, applied_options.mode);
    try std.testing.expectEqual(@as(usize, 1), applied_options.workflow_changes.len);
    try std.testing.expectEqual(@as(usize, 1), applied_options.before_evidence.len);
    try std.testing.expectEqual(@as(usize, 1), applied_options.after_evidence.len);
    try std.testing.expectEqual(@as(usize, 1), applied_options.verified_commands.len);
}

test "default output path replaces gate readiness suffix" {
    const options = Options{
        .gate_readiness_path = "../../.zig-cache/causal-artifacts/example-ci-gate-readiness.json",
        .mode = .plan,
        .reason = "planned",
    };
    const paths = try outputPathsForOptions(std.testing.allocator, options);
    defer paths.deinit(std.testing.allocator);

    try std.testing.expectEqualStrings("../../.zig-cache/causal-artifacts/example-ci-gate-application-boundary.json", paths.json_path);
    try std.testing.expectEqualStrings("../../.zig-cache/causal-artifacts/example-ci-gate-application-boundary.txt", paths.text_path);
}

test "plan and record-applied reports preserve guarded gate authority" {
    const planned = try formatReports(std.testing.allocator, .{
        .options = .{
            .gate_readiness_path = ".zig-cache/causal-artifacts/ci-gate-readiness.json",
            .mode = .plan,
            .reason = "CI gate application boundary planned",
        },
        .source_gate_readiness_json = sample_gate_readiness_json,
        .workflow_after_yml = null,
    });
    defer planned.deinit(std.testing.allocator);

    try std.testing.expect(std.mem.indexOf(u8, planned.json, "\"schema\": \"zigeffect.causal.production-telemetry-ci-gate-application-boundary.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, planned.json, "\"gate_application_status\": \"planned\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, planned.json, "\"applied\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, planned.json, "\"mutation_authority\": \"none\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, planned.json, "\"ci_gate_enabled\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, planned.json, "\"ci_gate_enforcement_enabled\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, planned.json, "\"ci_required_status_check_enabled\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, planned.json, "\"next_branch_if_applied\": \"codex/zigeffect-causal-production-telemetry-ci-gate-dry-run-policy\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, planned.text, "gate_application_status: planned") != null);

    const applied = try formatReports(std.testing.allocator, .{
        .options = .{
            .gate_readiness_path = ".zig-cache/causal-artifacts/ci-gate-readiness.json",
            .mode = .record_applied,
            .reason = "reviewed CI gate boundary change applied",
            .workflow_after_path = ".github/workflows/zigeffect-causal.yml",
            .workflow_changes = &.{".github/workflows/zigeffect-causal.yml"},
            .before_evidence = &.{"source readiness workflow digest"},
            .after_evidence = &.{"post-change workflow review"},
            .verified_commands = required_verification_commands,
        },
        .source_gate_readiness_json = sample_gate_readiness_json,
        .workflow_after_yml = sample_workflow_yml,
    });
    defer applied.deinit(std.testing.allocator);

    try std.testing.expect(std.mem.indexOf(u8, applied.json, "\"gate_application_status\": \"applied\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, applied.json, "\"applied\": true") != null);
    try std.testing.expect(std.mem.indexOf(u8, applied.json, "\"mutation_authority\": \"record-only\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, applied.json, "\"after_workflow_digest\": \"sha256:") != null);
    try std.testing.expect(std.mem.indexOf(u8, applied.json, "\"name\": \"after-workflow-safe\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, applied.text, "gate_application_status: applied") != null);
}

test "missing evidence and prohibited workflow features block record-applied" {
    const missing_evidence = try formatReports(std.testing.allocator, .{
        .options = .{
            .gate_readiness_path = ".zig-cache/causal-artifacts/ci-gate-readiness.json",
            .mode = .record_applied,
            .reason = "negative gate application boundary path",
            .workflow_after_path = ".github/workflows/zigeffect-causal.yml",
            .workflow_changes = &.{".github/workflows/zigeffect-causal.yml"},
            .before_evidence = &.{"source readiness workflow digest"},
        },
        .source_gate_readiness_json = sample_gate_readiness_json,
        .workflow_after_yml = sample_workflow_yml,
    });
    defer missing_evidence.deinit(std.testing.allocator);

    try std.testing.expect(std.mem.indexOf(u8, missing_evidence.json, "\"gate_application_status\": \"blocked\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, missing_evidence.json, "\"applied\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, missing_evidence.json, "\"name\": \"after-evidence-present\"") != null);

    const prohibited = try formatReports(std.testing.allocator, .{
        .options = .{
            .gate_readiness_path = ".zig-cache/causal-artifacts/ci-gate-readiness.json",
            .mode = .record_applied,
            .reason = "reviewed CI gate boundary change applied",
            .workflow_after_path = ".github/workflows/zigeffect-causal.yml",
            .workflow_changes = &.{".github/workflows/zigeffect-causal.yml"},
            .before_evidence = &.{"source readiness workflow digest"},
            .after_evidence = &.{"post-change workflow review"},
            .verified_commands = required_verification_commands,
        },
        .source_gate_readiness_json = sample_gate_readiness_json,
        .workflow_after_yml = sample_workflow_yml ++ "\n      - run: echo ${{ secrets.PRODUCTION_TELEMETRY_TOKEN }}\n",
    });
    defer prohibited.deinit(std.testing.allocator);

    try std.testing.expect(std.mem.indexOf(u8, prohibited.json, "\"gate_application_status\": \"blocked\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, prohibited.json, "\"name\": \"after-workflow-safe\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, prohibited.json, "\"status\": \"fail\"") != null);
}

const sample_gate_readiness_json =
    \\{
    \\  "schema": "zigeffect.causal.production-telemetry-ci-gate-readiness.v1",
    \\  "schema_version": 1,
    \\  "source_archive_evidence_policy": ".zig-cache/causal-artifacts/ci-archive-evidence-policy.json",
    \\  "source_policy_status": "ready",
    \\  "source_ci_archive_application": ".zig-cache/causal-artifacts/ci-archive-application.json",
    \\  "source_workflow_digest": "sha256:source-workflow-digest",
    \\  "decision": "approve",
    \\  "gate_readiness_status": "ready",
    \\  "ready_for_next_branch": true,
    \\  "reviewed_by": "ci-gate-readiness-reviewer",
    \\  "policy": "manual-production-telemetry-ci-gate-readiness",
    \\  "reason": "CI gate readiness reviewed",
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
    \\  "readiness_dimensions": [{ "id": "source-policy-ready", "required": true, "evidence": "ready archive evidence policy artifact" }],
    \\  "candidate_gate_signals": [{ "id": "release-gate-artifact-present", "enforcement_enabled": false, "source": ".zig-cache/release-gate/zigeffect-release-gate.json", "denied_claim": "release success" }],
    \\  "gate_semantics": ["Future CI telemetry gates may evaluate artifact presence schema parseability archive policy conformance redaction metadata retention metadata and release-gate report availability."],
    \\  "negative_fixtures": [{ "id": "blocked-source-policy-denied", "artifact_state": "archive_evidence_policy_status=blocked", "decision": "deny", "failed_gate": "source-policy-ready", "reason": "blocked evidence policy cannot feed gate readiness" }],
    \\  "checks": [{ "name": "source-archive-evidence-policy-schema", "status": "pass", "detail": "source archive evidence policy schema is supported" }, { "name": "readiness-verification-recorded", "status": "pass", "detail": "gate readiness recorded every required verification command" }],
    \\  "required_verification_commands": ["zig build causal-production-telemetry-ci-archive-evidence-policy", "zig build causal-artifacts", "zig build release-gate --summary none", "zig build release-gate-report", "zig build causal-schema-governance -- --format json", "zig build causal-production-hardening-backlog -- --format json", "zig build examples", "zig build test"],
    \\  "verified_commands": ["zig build causal-production-telemetry-ci-archive-evidence-policy", "zig build causal-artifacts", "zig build release-gate --summary none", "zig build release-gate-report", "zig build causal-schema-governance -- --format json", "zig build causal-production-hardening-backlog -- --format json", "zig build examples", "zig build test"],
    \\  "blocked_claims": ["runtime-pipeline-enabled", "ci-telemetry-gate", "hosted-dashboard-production-ready"]
    \\}
;

const sample_workflow_yml =
    \\name: zigeffect causal
    \\
    \\on:
    \\  pull_request:
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
    \\      - uses: actions/checkout@v4
    \\      - uses: mlugg/setup-zig@v2.2.1
    \\        with:
    \\          version: 0.16.0
    \\      - run: zig build causal-test
    \\      - run: zig build causal-artifacts
    \\      - run: zig build release-gate --summary none
    \\      - run: zig build release-gate-report
    \\      - if: ${{ failure() }}
    \\        run: zig build causal-ci-handoff
    \\      - if: ${{ failure() }}
    \\        uses: actions/upload-artifact@v4
    \\        with:
    \\          if-no-files-found: ignore
    \\          retention-days: 14
    \\          path: |
    \\            packages/zigeffect/.zig-cache/causal-artifacts/*.txt
    \\            packages/zigeffect/.zig-cache/causal-artifacts/*.json
    \\            packages/zigeffect/.zig-cache/release-gate/*.txt
    \\            packages/zigeffect/.zig-cache/release-gate/*.json
;
