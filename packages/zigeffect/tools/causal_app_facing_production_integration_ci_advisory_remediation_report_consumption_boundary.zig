const std = @import("std");

pub const schema = "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-boundary.v1";
pub const schema_version: u32 = 1;
pub const source_branch = "codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-boundary";
pub const recommendation = "start-app-facing-production-integration-ci-advisory-remediation-report-consumption-policy";
pub const next_branch_if_applied = "codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-policy";

const source_readiness_schema = "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-readiness.v1";
const source_publication_policy_schema = "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-publication-policy.v1";
const generated_by = "causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-boundary";
const source_readiness_suffix = "-ci-advisory-remediation-report-consumption-readiness.json";
const output_prefix_suffix = "-ci-advisory-remediation-report-consumption-boundary";
const compact_output_prefix_name = "app-facing-production-integration-ci-advisory-remediation-report-consumption-boundary";
const max_default_output_file_name_len = 240;
const max_source_bytes = 1024 * 1024;

const required_verification_commands: []const []const u8 = &.{
    "bun run zigeffect:workbench:typecheck",
    "bun run zigeffect:workbench:test",
    "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-readiness",
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
const github_api_mutation_enabled = false;
const app_mutation_controls_enabled = false;
const app_mutation_enabled = false;
const app_config_write_enabled = false;
const app_data_write_enabled = false;
const app_runtime_integration_enabled = false;
const agent_query_live_projection_enabled = false;
const raw_payload_capture_enabled = false;
const deployment_mutation_enabled = false;
const production_telemetry_ingestion = false;
const live_exporter_enabled = false;
const network_send_enabled = false;
const collector_endpoint_configured = false;
const otlp_serialization_enabled = false;
const runtime_pipeline_enabled = false;
const durable_write_enabled = false;
const nendb_write_enabled = false;
const nendb_adapter_execution_enabled = false;
const advisory_report = true;
const read_only_preview = true;
const read_only_consumption_enabled = true;
const solid_webui_enabled = true;
const solid_webui_renderer = "solidjs";
const webui_bridge = "webui-dev/zig-webui";

const Mode = enum { plan, record_applied };
const BoundaryStatus = enum { planned, applied, blocked };
const CheckStatus = enum { pass, fail, skipped };

const Options = struct {
    readiness_path: []const u8,
    mode: Mode,
    reviewed_by: []const u8 = "app-facing-ci-advisory-remediation-report-consumption-boundary-reviewer",
    policy: []const u8 = "manual-app-facing-production-integration-ci-advisory-remediation-report-consumption-boundary",
    reason: []const u8,
    consumer_after_path: ?[]const u8 = null,
    consumer_changes: []const []const u8 = &.{},
    before_evidence: []const []const u8 = &.{},
    after_evidence: []const []const u8 = &.{},
    verified_commands: []const []const u8 = &.{},
    out_prefix: ?[]const u8 = null,

    fn deinit(self: Options, allocator: std.mem.Allocator) void {
        freeSliceOnly(allocator, self.consumer_changes);
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
    consumer_after_text: ?[]const u8 = null,
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

const SourceConsumerProfile = struct {
    id: []const u8,
    role: []const u8 = "",
    consumption_enabled: bool = false,
    allowed_inputs: []const u8 = "",
    output_contract: []const u8 = "",
    denied_claim: []const u8 = "",
};

const SourceReadinessDimension = struct {
    id: []const u8,
    required: bool = false,
    evidence: []const u8 = "",
};

const SourceConsumptionGuardrail = struct {
    id: []const u8,
    required_before_boundary: bool = false,
    reason: []const u8 = "",
};

const SourceNegativeFixture = struct {
    id: []const u8 = "",
    artifact_state: []const u8 = "",
    decision: []const u8 = "",
    failed_gate: []const u8 = "",
    reason: []const u8 = "",
};

const SourceReadinessArtifact = struct {
    schema: []const u8,
    schema_version: u32,
    source_publication_policy: []const u8 = "",
    source_publication_policy_schema: []const u8 = "",
    source_after_report_digest: []const u8 = "",
    decision: []const u8,
    consumption_readiness_status: []const u8,
    ready_for_next_branch: bool,
    ci_gate_enabled: bool = true,
    ci_gate_enforcement_enabled: bool = true,
    ci_required_status_check_enabled: bool = true,
    ci_workflow_mutation_enabled: bool = true,
    ci_upload_execution_enabled: bool = true,
    ci_report_publication_enabled: bool = true,
    github_step_summary_write_enabled: bool = true,
    pull_request_comment_enabled: bool = true,
    github_api_mutation_enabled: bool = true,
    app_mutation_controls_enabled: bool = true,
    app_mutation_enabled: bool = true,
    app_config_write_enabled: bool = true,
    app_data_write_enabled: bool = true,
    app_runtime_integration_enabled: bool = true,
    agent_query_live_projection_enabled: bool = true,
    raw_payload_capture_enabled: bool = true,
    deployment_mutation_enabled: bool = true,
    production_telemetry_ingestion: bool = true,
    live_exporter_enabled: bool = false,
    network_send_enabled: bool = false,
    collector_endpoint_configured: bool = false,
    otlp_serialization_enabled: bool = false,
    runtime_pipeline_enabled: bool = true,
    durable_write_enabled: bool = true,
    nendb_write_enabled: bool = true,
    nendb_adapter_execution_enabled: bool = true,
    advisory_report: bool = false,
    read_only_preview: bool = false,
    solid_webui_enabled: bool = false,
    solid_webui_renderer: []const u8 = "",
    webui_bridge: []const u8 = "",
    mutation_authority: []const u8,
    readiness_checks: []const SourceCheck = &.{},
    consumer_profiles: []const SourceConsumerProfile = &.{},
    readiness_dimensions: []const SourceReadinessDimension = &.{},
    consumption_guardrails: []const SourceConsumptionGuardrail = &.{},
    denied_inference_rules: []const []const u8 = &.{},
    negative_fixtures: []const SourceNegativeFixture = &.{},
    blocked_claims: []const []const u8 = &.{},
    required_verification_commands: []const []const u8 = &.{},
    verified_commands: []const []const u8 = &.{},
    source_branch: []const u8 = "",
    recommendation: []const u8 = "",
    next_branch_if_ready: []const u8 = "",
};

const BoundaryCheck = struct {
    name: []const u8,
    status: CheckStatus,
    detail: []const u8,
};

const BoundaryResult = struct {
    status: BoundaryStatus,
    applied: bool,
    ready_for_next_branch: bool,
    mutation_authority: []const u8,
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

const required_consumer_after_markers: []const []const u8 = &.{ "zigeffect", "causal", "read-only", "consumption", "boundary" };

const prohibited_consumer_after_markers: []const []const u8 = &.{
    "required_status_check",
    "required status check active",
    "ci_gate_enabled=true",
    "ci_gate_enforcement_enabled=true",
    "ci_required_status_check_enabled=true",
    "ci_workflow_mutation_enabled=true",
    "ci_upload_execution_enabled=true",
    "ci_report_publication_enabled=true",
    "github_api_mutation_enabled=true",
    "github_step_summary_write_enabled=true",
    "pull_request_comment_enabled=true",
    "app_mutation_enabled=true",
    "app_config_write_enabled=true",
    "app_data_write_enabled=true",
    "app_runtime_integration_enabled=true",
    "agent_query_live_projection_enabled=true",
    "raw_payload_capture_enabled=true",
    "deployment_mutation_enabled=true",
    "durable_write_enabled=true",
    "nendb_write_enabled=true",
    "nendb_adapter_execution_enabled=true",
    "cockroach",
    "non-nendb durable",
    "production_health_proven",
    "production health proven",
    "deployment success",
    "cluster ready",
    "auto_apply_enabled=true",
    "auto-apply",
    "mutation_authority=granted",
    "mutation authority granted",
    "react renderer",
    "renderer=react",
    "raw prompt",
    "raw response",
};

const boundary_rules: []const []const u8 = &.{
    "Plan mode records read-only consumption boundary intent only and never records applied state.",
    "record-applied requires reviewed consumer-change evidence, before evidence, after evidence, consumer-after content, content safety, and full verification commands.",
    "Applied records are evidence records only; this tool does not mutate apps, workbench state, GitHub, workflows, CI gates, storage, or runtime integrations.",
    "Future consumption policy work may interpret applied boundary records for agents and the SolidJS workbench without creating mutation authority.",
};

const denied_boundary_claims: []const []const u8 = &.{
    "required-status-check-active",
    "merge-blocker-active",
    "github-api-mutation",
    "workflow-mutated-by-tool",
    "artifact-upload-executed-by-tool",
    "github-step-summary-written-by-tool",
    "pull-request-comment-written-by-tool",
    "app-mutation-proof",
    "app-config-write-proof",
    "app-data-write-proof",
    "app-runtime-integration-proof",
    "agent-query-live-projection-proof",
    "raw-payload-capture-proof",
    "production-health-proof",
    "deployment-success-proof",
    "durable-write-proof",
    "nendb-write-proof",
    "nendb-adapter-execution-proof",
    "cockroach-adapter-work",
    "react-renderer",
    "alternate-renderer",
    "auto-apply-proof",
    "mutation-authority",
};

const negative_fixtures: []const NegativeFixture = &.{
    .{ .id = "blocked-consumption-readiness-denied", .artifact_state = "consumption_readiness_status=blocked", .decision = "deny", .failed_gate = "source-readiness-ready", .reason = "blocked readiness cannot feed consumption boundary application" },
    .{ .id = "missing-consumer-change-denied", .artifact_state = "record-applied consumer_changes=[]", .decision = "deny", .failed_gate = "consumer-change-present", .reason = "reviewed consumer boundary evidence is required" },
    .{ .id = "missing-before-evidence-denied", .artifact_state = "record-applied before=[]", .decision = "deny", .failed_gate = "before-evidence-present", .reason = "before evidence is required" },
    .{ .id = "missing-after-evidence-denied", .artifact_state = "record-applied after=[]", .decision = "deny", .failed_gate = "after-evidence-present", .reason = "after evidence is required" },
    .{ .id = "missing-consumer-after-denied", .artifact_state = "record-applied consumer_after=null", .decision = "deny", .failed_gate = "consumer-after-present", .reason = "consumer-after content is required" },
    .{ .id = "unsafe-consumer-after-denied", .artifact_state = "consumer_after app_runtime_integration_enabled=true", .decision = "deny", .failed_gate = "consumer-after-safe", .reason = "consumer-after evidence cannot claim runtime integration" },
    .{ .id = "nendb-adapter-execution-denied", .artifact_state = "nendb_adapter_execution_enabled=true", .decision = "deny", .failed_gate = "source-authority-disabled", .reason = "consumption boundary does not execute a NenDB adapter" },
    .{ .id = "mutation-authority-claim-denied", .artifact_state = "mutation_authority=granted", .decision = "deny", .failed_gate = "source-readiness-ready", .reason = "consumption boundary grants record-only authority only after review" },
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
        error.MissingReadinessInput, error.MissingConsumerAfterInput => failUsage(err),
        else => return err,
    };
}

fn parseOptions(allocator: std.mem.Allocator, args: []const []const u8) !Options {
    if (args.len < 2) return error.MissingReadinessPath;
    if (!std.mem.eql(u8, args[1], "--from-readiness")) return error.UnknownFlag;
    if (args.len < 3) return error.MissingReadinessPath;
    const readiness_path = args[2];
    if (!std.mem.endsWith(u8, readiness_path, ".json")) return error.InvalidReadinessPath;
    if (args.len < 4) return error.MissingMode;
    const mode = try parseMode(args[3]);

    var reviewed_by: []const u8 = "app-facing-ci-advisory-remediation-report-consumption-boundary-reviewer";
    var policy: []const u8 = "manual-app-facing-production-integration-ci-advisory-remediation-report-consumption-boundary";
    var reason: ?[]const u8 = null;
    var consumer_after_path: ?[]const u8 = null;
    var consumer_changes = std.ArrayList([]const u8).empty;
    var before_evidence = std.ArrayList([]const u8).empty;
    var after_evidence = std.ArrayList([]const u8).empty;
    var verified_commands = std.ArrayList([]const u8).empty;
    var out_prefix: ?[]const u8 = null;
    errdefer consumer_changes.deinit(allocator);
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
        } else if (std.mem.eql(u8, flag, "--consumer-after")) {
            if (!consumerAfterPathValid(value)) return error.InvalidConsumerAfterPath;
            consumer_after_path = value;
        } else if (std.mem.eql(u8, flag, "--consumer-change")) {
            try consumer_changes.append(allocator, value);
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
        .readiness_path = readiness_path,
        .mode = mode,
        .reviewed_by = reviewed_by,
        .policy = policy,
        .reason = final_reason,
        .consumer_after_path = consumer_after_path,
        .consumer_changes = try consumer_changes.toOwnedSlice(allocator),
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

fn consumerAfterPathValid(path: []const u8) bool {
    return std.mem.endsWith(u8, path, ".txt") or
        std.mem.endsWith(u8, path, ".md") or
        std.mem.endsWith(u8, path, ".json");
}

fn modeText(mode: Mode) []const u8 {
    return switch (mode) {
        .plan => "plan",
        .record_applied => "record-applied",
    };
}

fn boundaryStatusText(status: BoundaryStatus) []const u8 {
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

fn defaultOutputPaths(allocator: std.mem.Allocator, readiness_path: []const u8) !OutputPaths {
    const prefix = try defaultOutputPrefix(allocator, readiness_path);
    defer allocator.free(prefix);
    return .{
        .json_path = try std.fmt.allocPrint(allocator, "{s}.json", .{prefix}),
        .text_path = try std.fmt.allocPrint(allocator, "{s}.txt", .{prefix}),
    };
}

fn outputPathsForOptions(allocator: std.mem.Allocator, options: Options) !OutputPaths {
    const prefix = if (options.out_prefix) |out_prefix|
        try allocator.dupe(u8, out_prefix)
    else
        try defaultOutputPrefix(allocator, options.readiness_path);
    defer allocator.free(prefix);

    return .{
        .json_path = try std.fmt.allocPrint(allocator, "{s}.json", .{prefix}),
        .text_path = try std.fmt.allocPrint(allocator, "{s}.txt", .{prefix}),
    };
}

fn defaultOutputPrefix(allocator: std.mem.Allocator, readiness_path: []const u8) ![]const u8 {
    if (!std.mem.endsWith(u8, readiness_path, ".json")) return error.InvalidReadinessPath;

    const base = if (std.mem.endsWith(u8, readiness_path, source_readiness_suffix))
        readiness_path[0 .. readiness_path.len - source_readiness_suffix.len]
    else
        readiness_path[0 .. readiness_path.len - ".json".len];
    const candidate = try std.fmt.allocPrint(allocator, "{s}{s}", .{ base, output_prefix_suffix });
    errdefer allocator.free(candidate);

    if (fileName(candidate).len + ".json".len <= max_default_output_file_name_len) {
        return candidate;
    }

    const directory = directoryPrefix(candidate);
    const digest = shortPathDigest(readiness_path);
    const compact_prefix = try std.fmt.allocPrint(allocator, "{s}{s}-{s}", .{ directory, compact_output_prefix_name, digest[0..] });
    allocator.free(candidate);
    return compact_prefix;
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

fn formatReports(allocator: std.mem.Allocator, input: BoundaryInput) !BoundaryReports {
    var parsed = try std.json.parseFromSlice(SourceReadinessArtifact, allocator, input.source_readiness_json, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();

    const paths = try outputPathsForOptions(allocator, input.options);
    defer paths.deinit(allocator);

    const consumer_after_digest = if (input.consumer_after_text) |after_text|
        try textDigest(allocator, after_text)
    else
        try allocator.dupe(u8, "");
    defer allocator.free(consumer_after_digest);

    const result = try evaluateBoundary(allocator, input.options, parsed.value, input.consumer_after_text);
    defer result.deinit(allocator);

    const json = try formatBoundaryJson(allocator, input.options, parsed.value, input.consumer_after_text, consumer_after_digest, result, paths);
    errdefer allocator.free(json);
    const text = try formatBoundaryText(allocator, input.options, parsed.value, consumer_after_digest, result, paths);
    errdefer allocator.free(text);

    return .{ .json = json, .text = text };
}

fn evaluateBoundary(
    allocator: std.mem.Allocator,
    options: Options,
    source: SourceReadinessArtifact,
    consumer_after_text: ?[]const u8,
) !BoundaryResult {
    var checks = std.ArrayList(BoundaryCheck).empty;
    errdefer checks.deinit(allocator);

    try appendCheck(allocator, &checks, "source-schema", if (std.mem.eql(u8, source.schema, source_readiness_schema) and source.schema_version == 1) .pass else .fail, "source consumption-readiness schema is supported");
    try appendCheck(allocator, &checks, "source-readiness-ready", if (sourceReadinessReady(source)) .pass else .fail, "source consumption readiness is approved ready and ready for next branch");
    try appendCheck(allocator, &checks, "source-publication-policy-carried", if (sourcePublicationPolicyCarried(source)) .pass else .fail, "source carries publication-policy and after-report digest refs");
    try appendCheck(allocator, &checks, "source-checks-passed", if (sourceChecksPassed(source.readiness_checks)) .pass else .fail, "source readiness checks contain no failures");
    try appendCheck(allocator, &checks, "source-authority-disabled", if (sourceAuthorityDisabled(source)) .pass else .fail, "source keeps CI GitHub app runtime deployment storage and adapter authority disabled");
    try appendCheck(allocator, &checks, "source-solid-webui-readonly", if (sourceSolidWebuiReadonly(source)) .pass else .fail, "source remains SolidJS webui read-only evidence");
    try appendCheck(allocator, &checks, "source-consumer-catalogs-present", if (sourceConsumerCatalogsPresent(source)) .pass else .fail, "source carries consumer profiles readiness dimensions guardrails denied rules negative fixtures and blocked claims");
    try appendCheck(allocator, &checks, "source-verification-recorded", if (sourceVerificationRecorded(source)) .pass else .fail, "source records every required verification command");

    if (options.mode == .plan) {
        try appendCheck(allocator, &checks, "plan-is-not-applied", .pass, "plan mode records read-only consumption boundary intent without applied state");
        try appendCheck(allocator, &checks, "consumer-change-present", .skipped, "plan mode does not claim consumer-change evidence");
        try appendCheck(allocator, &checks, "before-evidence-present", .skipped, "plan mode does not claim before evidence");
        try appendCheck(allocator, &checks, "after-evidence-present", .skipped, "plan mode does not claim after evidence");
        try appendCheck(allocator, &checks, "post-verification-recorded", .skipped, "plan mode does not claim post-application verification");
        try appendCheck(allocator, &checks, "consumer-after-present", if (consumer_after_text == null) .skipped else .pass, "plan mode may include optional consumer-after evidence");
        try appendCheck(allocator, &checks, "consumer-after-safe", if (consumer_after_text) |after_text| consumerAfterSafetyStatus(after_text) else .skipped, "optional consumer-after evidence preserves read-only boundary constraints");

        const check_slice = try checks.toOwnedSlice(allocator);
        errdefer allocator.free(check_slice);
        const planned = requiredChecksPassed(check_slice);
        return .{
            .status = if (planned) .planned else .blocked,
            .applied = false,
            .ready_for_next_branch = false,
            .mutation_authority = "none",
            .checks = check_slice,
        };
    }

    try appendCheck(allocator, &checks, "consumer-change-present", if (options.consumer_changes.len > 0) .pass else .fail, "record-applied requires reviewed consumer boundary change evidence");
    try appendCheck(allocator, &checks, "before-evidence-present", if (options.before_evidence.len > 0) .pass else .fail, "record-applied requires before evidence");
    try appendCheck(allocator, &checks, "after-evidence-present", if (options.after_evidence.len > 0) .pass else .fail, "record-applied requires after evidence");
    try appendCheck(allocator, &checks, "post-verification-recorded", if (verifiedCommandsContainAll(options.verified_commands, required_verification_commands)) .pass else .fail, "record-applied requires every post-application verification command");
    try appendCheck(allocator, &checks, "consumer-after-present", if (consumer_after_text != null) .pass else .fail, "record-applied requires consumer-after content");
    try appendCheck(allocator, &checks, "consumer-after-safe", if (consumer_after_text) |after_text| consumerAfterSafetyStatus(after_text) else .fail, "consumer-after evidence preserves read-only boundary constraints");

    const check_slice = try checks.toOwnedSlice(allocator);
    errdefer allocator.free(check_slice);
    const applied = allChecksPassed(check_slice);
    return .{
        .status = if (applied) .applied else .blocked,
        .applied = applied,
        .ready_for_next_branch = applied,
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

fn sourceReadinessReady(source: SourceReadinessArtifact) bool {
    return std.mem.eql(u8, source.decision, "approve") and
        std.mem.eql(u8, source.consumption_readiness_status, "ready") and
        source.ready_for_next_branch and
        std.mem.eql(u8, source.mutation_authority, "none");
}

fn sourcePublicationPolicyCarried(source: SourceReadinessArtifact) bool {
    return (std.mem.eql(u8, source.source_publication_policy_schema, source_publication_policy_schema) or source.source_publication_policy_schema.len == 0) and
        source.source_publication_policy.len > 0 and
        std.mem.endsWith(u8, source.source_publication_policy, "-ci-advisory-remediation-report-publication-policy.json") and
        source.source_after_report_digest.len > 0;
}

fn sourceChecksPassed(checks: []const SourceCheck) bool {
    if (checks.len == 0) return false;
    for (checks) |check| {
        if (std.mem.eql(u8, check.status, "fail")) return false;
    }
    return true;
}

fn sourceAuthorityDisabled(source: SourceReadinessArtifact) bool {
    return !source.ci_gate_enabled and
        !source.ci_gate_enforcement_enabled and
        !source.ci_required_status_check_enabled and
        !source.ci_workflow_mutation_enabled and
        !source.ci_upload_execution_enabled and
        !source.ci_report_publication_enabled and
        !source.github_step_summary_write_enabled and
        !source.pull_request_comment_enabled and
        !source.github_api_mutation_enabled and
        !source.app_mutation_controls_enabled and
        !source.app_mutation_enabled and
        !source.app_config_write_enabled and
        !source.app_data_write_enabled and
        !source.app_runtime_integration_enabled and
        !source.agent_query_live_projection_enabled and
        !source.raw_payload_capture_enabled and
        !source.deployment_mutation_enabled and
        !source.production_telemetry_ingestion and
        !source.live_exporter_enabled and
        !source.network_send_enabled and
        !source.collector_endpoint_configured and
        !source.otlp_serialization_enabled and
        !source.runtime_pipeline_enabled and
        !source.durable_write_enabled and
        !source.nendb_write_enabled and
        !source.nendb_adapter_execution_enabled;
}

fn sourceSolidWebuiReadonly(source: SourceReadinessArtifact) bool {
    return source.advisory_report and
        source.read_only_preview and
        source.solid_webui_enabled and
        std.mem.eql(u8, source.solid_webui_renderer, solid_webui_renderer) and
        std.mem.eql(u8, source.webui_bridge, webui_bridge);
}

fn sourceConsumerCatalogsPresent(source: SourceReadinessArtifact) bool {
    return hasSourceConsumerProfile(source, "reviewer-triage-consumer") and
        hasSourceConsumerProfile(source, "agent-readonly-consumer") and
        hasSourceConsumerProfile(source, "ci-advisory-consumer") and
        hasSourceConsumerProfile(source, "solid-webui-consumer") and
        hasSourceConsumerProfile(source, "future-consumption-boundary-input") and
        hasSourceReadinessDimension(source, "bounded-agent-query-contract") and
        hasSourceReadinessDimension(source, "source-id-citation-required") and
        hasSourceReadinessDimension(source, "no-runtime-integration") and
        hasSourceConsumptionGuardrail(source, "bounded-source-ids-only") and
        hasSourceConsumptionGuardrail(source, "no-app-runtime-integration") and
        hasSourceConsumptionGuardrail(source, "no-nendb-write-or-adapter-execution") and
        containsString(source.denied_inference_rules, "app-runtime-integration-proof") and
        containsString(source.denied_inference_rules, "nendb-adapter-execution-proof") and
        hasSourceNegativeFixture(source, "mutation-authority-claim-denied") and
        source.blocked_claims.len > 0;
}

fn hasSourceConsumerProfile(source: SourceReadinessArtifact, id: []const u8) bool {
    for (source.consumer_profiles) |profile| {
        if (std.mem.eql(u8, profile.id, id) and profile.consumption_enabled) return true;
    }
    return false;
}

fn hasSourceReadinessDimension(source: SourceReadinessArtifact, id: []const u8) bool {
    for (source.readiness_dimensions) |dimension| {
        if (std.mem.eql(u8, dimension.id, id) and dimension.required) return true;
    }
    return false;
}

fn hasSourceConsumptionGuardrail(source: SourceReadinessArtifact, id: []const u8) bool {
    for (source.consumption_guardrails) |guardrail| {
        if (std.mem.eql(u8, guardrail.id, id) and guardrail.required_before_boundary) return true;
    }
    return false;
}

fn hasSourceNegativeFixture(source: SourceReadinessArtifact, id: []const u8) bool {
    for (source.negative_fixtures) |fixture| {
        if (std.mem.eql(u8, fixture.id, id)) return true;
    }
    return false;
}

fn sourceVerificationRecorded(source: SourceReadinessArtifact) bool {
    return source.required_verification_commands.len > 0 and
        source.verified_commands.len > 0 and
        verifiedCommandsContainAll(source.verified_commands, source.required_verification_commands);
}

fn consumerAfterSafetyStatus(after_text: []const u8) CheckStatus {
    for (required_consumer_after_markers) |marker| {
        if (!contains(after_text, marker)) return .fail;
    }
    for (prohibited_consumer_after_markers) |marker| {
        if (contains(after_text, marker)) return .fail;
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
    source: SourceReadinessArtifact,
    consumer_after_text: ?[]const u8,
    consumer_after_digest: []const u8,
    result: BoundaryResult,
    paths: OutputPaths,
) ![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "{\n");
    try appendJsonField(allocator, &output, "schema", schema, true);
    try output.appendSlice(allocator, "  \"schema_version\": 1,\n");
    try appendJsonField(allocator, &output, "generated_by", generated_by, true);
    try appendJsonField(allocator, &output, "source_consumption_readiness", options.readiness_path, true);
    try appendJsonField(allocator, &output, "source_consumption_readiness_status", source.consumption_readiness_status, true);
    try appendJsonField(allocator, &output, "source_readiness_decision", source.decision, true);
    try output.print(allocator, "  \"source_ready_for_next_branch\": {},\n", .{source.ready_for_next_branch});
    try appendJsonField(allocator, &output, "source_mutation_authority", source.mutation_authority, true);
    try appendJsonField(allocator, &output, "source_publication_policy", source.source_publication_policy, true);
    try appendJsonField(allocator, &output, "source_after_report_digest", source.source_after_report_digest, true);
    try appendJsonField(allocator, &output, "mode", modeText(options.mode), true);
    try appendJsonField(allocator, &output, "consumption_boundary_status", boundaryStatusText(result.status), true);
    try output.print(allocator, "  \"applied\": {},\n", .{result.applied});
    try output.print(allocator, "  \"ready_for_next_branch\": {},\n", .{result.ready_for_next_branch});
    try appendJsonField(allocator, &output, "mutation_authority", result.mutation_authority, true);
    try appendJsonField(allocator, &output, "reviewed_by", options.reviewed_by, true);
    try appendJsonField(allocator, &output, "policy", options.policy, true);
    try appendJsonField(allocator, &output, "reason", options.reason, true);
    try output.appendSlice(allocator, "  \"consumer_after_path\": ");
    try appendOptionalJsonString(allocator, &output, options.consumer_after_path);
    try output.appendSlice(allocator, ",\n");
    try appendJsonField(allocator, &output, "consumer_after_digest", consumer_after_digest, true);
    try output.print(allocator, "  \"consumer_after_present\": {},\n", .{consumer_after_text != null});
    try appendAuthorityBooleansJson(allocator, &output);
    try output.appendSlice(allocator, "  \"consumer_changes\": ");
    try appendStringArray(allocator, &output, options.consumer_changes);
    try output.appendSlice(allocator, ",\n  \"before_evidence\": ");
    try appendStringArray(allocator, &output, options.before_evidence);
    try output.appendSlice(allocator, ",\n  \"after_evidence\": ");
    try appendStringArray(allocator, &output, options.after_evidence);
    try output.appendSlice(allocator, ",\n  \"boundary_checks\": ");
    try appendBoundaryChecksJson(allocator, &output, result.checks);
    try output.appendSlice(allocator, ",\n  \"source_readiness_checks\": ");
    try appendSourceChecksJson(allocator, &output, source.readiness_checks);
    try output.appendSlice(allocator, ",\n  \"source_consumer_profiles\": ");
    try appendSourceConsumerProfilesJson(allocator, &output, source.consumer_profiles);
    try output.appendSlice(allocator, ",\n  \"source_readiness_dimensions\": ");
    try appendSourceReadinessDimensionsJson(allocator, &output, source.readiness_dimensions);
    try output.appendSlice(allocator, ",\n  \"source_consumption_guardrails\": ");
    try appendSourceConsumptionGuardrailsJson(allocator, &output, source.consumption_guardrails);
    try output.appendSlice(allocator, ",\n  \"boundary_rules\": ");
    try appendStringArray(allocator, &output, boundary_rules);
    try output.appendSlice(allocator, ",\n  \"denied_boundary_claims\": ");
    try appendStringArray(allocator, &output, denied_boundary_claims);
    try output.appendSlice(allocator, ",\n  \"source_denied_inference_rules\": ");
    try appendStringArray(allocator, &output, source.denied_inference_rules);
    try output.appendSlice(allocator, ",\n  \"negative_fixtures\": ");
    try appendNegativeFixturesJson(allocator, &output);
    try output.appendSlice(allocator, ",\n  \"source_negative_fixtures\": ");
    try appendSourceNegativeFixturesJson(allocator, &output, source.negative_fixtures);
    try output.appendSlice(allocator, ",\n  \"blocked_claims\": ");
    try appendStringArray(allocator, &output, blockedClaims(source));
    try output.appendSlice(allocator, ",\n  \"required_verification_commands\": ");
    try appendStringArray(allocator, &output, required_verification_commands);
    try output.appendSlice(allocator, ",\n  \"verified_commands\": ");
    try appendStringArray(allocator, &output, options.verified_commands);
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

fn appendAuthorityBooleansJson(allocator: std.mem.Allocator, output: *std.ArrayList(u8)) !void {
    try output.print(allocator, "  \"ci_gate_enabled\": {},\n", .{ci_gate_enabled});
    try output.print(allocator, "  \"ci_gate_enforcement_enabled\": {},\n", .{ci_gate_enforcement_enabled});
    try output.print(allocator, "  \"ci_required_status_check_enabled\": {},\n", .{ci_required_status_check_enabled});
    try output.print(allocator, "  \"ci_workflow_mutation_enabled\": {},\n", .{ci_workflow_mutation_enabled});
    try output.print(allocator, "  \"ci_upload_execution_enabled\": {},\n", .{ci_upload_execution_enabled});
    try output.print(allocator, "  \"ci_report_publication_enabled\": {},\n", .{ci_report_publication_enabled});
    try output.print(allocator, "  \"github_step_summary_write_enabled\": {},\n", .{github_step_summary_write_enabled});
    try output.print(allocator, "  \"pull_request_comment_enabled\": {},\n", .{pull_request_comment_enabled});
    try output.print(allocator, "  \"github_api_mutation_enabled\": {},\n", .{github_api_mutation_enabled});
    try output.print(allocator, "  \"app_mutation_controls_enabled\": {},\n", .{app_mutation_controls_enabled});
    try output.print(allocator, "  \"app_mutation_enabled\": {},\n", .{app_mutation_enabled});
    try output.print(allocator, "  \"app_config_write_enabled\": {},\n", .{app_config_write_enabled});
    try output.print(allocator, "  \"app_data_write_enabled\": {},\n", .{app_data_write_enabled});
    try output.print(allocator, "  \"app_runtime_integration_enabled\": {},\n", .{app_runtime_integration_enabled});
    try output.print(allocator, "  \"agent_query_live_projection_enabled\": {},\n", .{agent_query_live_projection_enabled});
    try output.print(allocator, "  \"raw_payload_capture_enabled\": {},\n", .{raw_payload_capture_enabled});
    try output.print(allocator, "  \"deployment_mutation_enabled\": {},\n", .{deployment_mutation_enabled});
    try output.print(allocator, "  \"production_telemetry_ingestion\": {},\n", .{production_telemetry_ingestion});
    try output.print(allocator, "  \"live_exporter_enabled\": {},\n", .{live_exporter_enabled});
    try output.print(allocator, "  \"network_send_enabled\": {},\n", .{network_send_enabled});
    try output.print(allocator, "  \"collector_endpoint_configured\": {},\n", .{collector_endpoint_configured});
    try output.print(allocator, "  \"otlp_serialization_enabled\": {},\n", .{otlp_serialization_enabled});
    try output.print(allocator, "  \"runtime_pipeline_enabled\": {},\n", .{runtime_pipeline_enabled});
    try output.print(allocator, "  \"durable_write_enabled\": {},\n", .{durable_write_enabled});
    try output.print(allocator, "  \"nendb_write_enabled\": {},\n", .{nendb_write_enabled});
    try output.print(allocator, "  \"nendb_adapter_execution_enabled\": {},\n", .{nendb_adapter_execution_enabled});
    try output.print(allocator, "  \"advisory_report\": {},\n", .{advisory_report});
    try output.print(allocator, "  \"read_only_preview\": {},\n", .{read_only_preview});
    try output.print(allocator, "  \"read_only_consumption_enabled\": {},\n", .{read_only_consumption_enabled});
    try output.print(allocator, "  \"solid_webui_enabled\": {},\n", .{solid_webui_enabled});
    try appendJsonField(allocator, output, "solid_webui_renderer", solid_webui_renderer, true);
    try appendJsonField(allocator, output, "webui_bridge", webui_bridge, true);
}

fn formatBoundaryText(
    allocator: std.mem.Allocator,
    options: Options,
    source: SourceReadinessArtifact,
    consumer_after_digest: []const u8,
    result: BoundaryResult,
    paths: OutputPaths,
) ![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "zigeffect app-facing CI advisory remediation report consumption boundary\n");
    try output.print(allocator, "schema: {s}\n", .{schema});
    try output.print(allocator, "source consumption readiness: {s}\n", .{options.readiness_path});
    try output.print(allocator, "source readiness status: {s}\n", .{source.consumption_readiness_status});
    try output.print(allocator, "source readiness decision: {s}\n", .{source.decision});
    try output.print(allocator, "source mutation authority: {s}\n", .{source.mutation_authority});
    try output.print(allocator, "source after report digest: {s}\n", .{source.source_after_report_digest});
    try output.print(allocator, "mode: {s}\n", .{modeText(options.mode)});
    try output.print(allocator, "consumption_boundary_status: {s}\n", .{boundaryStatusText(result.status)});
    try output.print(allocator, "applied: {}\n", .{result.applied});
    try output.print(allocator, "ready_for_next_branch: {}\n", .{result.ready_for_next_branch});
    try output.print(allocator, "mutation_authority: {s}\n", .{result.mutation_authority});
    try output.print(allocator, "ci required status check enabled: {}\n", .{ci_required_status_check_enabled});
    try output.print(allocator, "github api mutation enabled: {}\n", .{github_api_mutation_enabled});
    try output.print(allocator, "app mutation enabled: {}\n", .{app_mutation_enabled});
    try output.print(allocator, "app runtime integration enabled: {}\n", .{app_runtime_integration_enabled});
    try output.print(allocator, "agent query live projection enabled: {}\n", .{agent_query_live_projection_enabled});
    try output.print(allocator, "raw payload capture enabled: {}\n", .{raw_payload_capture_enabled});
    try output.print(allocator, "nendb adapter execution enabled: {}\n", .{nendb_adapter_execution_enabled});
    try output.print(allocator, "solid webui renderer: {s}\n", .{solid_webui_renderer});
    try output.print(allocator, "webui bridge: {s}\n", .{webui_bridge});
    try output.print(allocator, "reviewed_by: {s}\n", .{options.reviewed_by});
    try output.print(allocator, "policy: {s}\n", .{options.policy});
    try output.print(allocator, "reason: {s}\n", .{options.reason});
    try output.print(allocator, "consumer after digest: {s}\n", .{consumer_after_digest});
    try output.print(allocator, "source branch: {s}\n", .{source_branch});
    try output.print(allocator, "recommendation: {s}\n", .{recommendation});
    try output.print(allocator, "next branch if applied: {s}\n", .{next_branch_if_applied});
    try output.print(allocator, "json output: {s}\n", .{paths.json_path});
    try output.print(allocator, "text output: {s}\n\n", .{paths.text_path});

    try output.appendSlice(allocator, "boundary checks:\n");
    for (result.checks) |check| {
        try output.print(allocator, "- {s}: {s} - {s}\n", .{ check.name, checkStatusText(check.status), check.detail });
    }
    try output.append(allocator, '\n');

    try appendTextList(allocator, &output, "consumer changes", options.consumer_changes);
    try appendTextList(allocator, &output, "before evidence", options.before_evidence);
    try appendTextList(allocator, &output, "after evidence", options.after_evidence);
    try appendTextList(allocator, &output, "boundary rules", boundary_rules);
    try appendTextList(allocator, &output, "denied boundary claims", denied_boundary_claims);
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

fn appendBoundaryChecksJson(allocator: std.mem.Allocator, output: *std.ArrayList(u8), checks: []const BoundaryCheck) !void {
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

fn appendSourceChecksJson(allocator: std.mem.Allocator, output: *std.ArrayList(u8), checks: []const SourceCheck) !void {
    try output.append(allocator, '[');
    for (checks, 0..) |check, index| {
        if (index > 0) try output.appendSlice(allocator, ", ");
        try output.appendSlice(allocator, "{ \"name\": ");
        try appendJsonString(allocator, output, checkName(check));
        try output.appendSlice(allocator, ", \"status\": ");
        try appendJsonString(allocator, output, check.status);
        try output.appendSlice(allocator, ", \"detail\": ");
        try appendJsonString(allocator, output, check.detail);
        try output.appendSlice(allocator, " }");
    }
    try output.append(allocator, ']');
}

fn appendSourceConsumerProfilesJson(allocator: std.mem.Allocator, output: *std.ArrayList(u8), profiles: []const SourceConsumerProfile) !void {
    try output.append(allocator, '[');
    for (profiles, 0..) |profile, index| {
        if (index > 0) try output.appendSlice(allocator, ", ");
        try output.appendSlice(allocator, "{ \"id\": ");
        try appendJsonString(allocator, output, profile.id);
        try output.appendSlice(allocator, ", \"role\": ");
        try appendJsonString(allocator, output, profile.role);
        try output.print(allocator, ", \"consumption_enabled\": {}", .{profile.consumption_enabled});
        try output.appendSlice(allocator, ", \"denied_claim\": ");
        try appendJsonString(allocator, output, profile.denied_claim);
        try output.appendSlice(allocator, " }");
    }
    try output.append(allocator, ']');
}

fn appendSourceReadinessDimensionsJson(allocator: std.mem.Allocator, output: *std.ArrayList(u8), dimensions: []const SourceReadinessDimension) !void {
    try output.append(allocator, '[');
    for (dimensions, 0..) |dimension, index| {
        if (index > 0) try output.appendSlice(allocator, ", ");
        try output.appendSlice(allocator, "{ \"id\": ");
        try appendJsonString(allocator, output, dimension.id);
        try output.print(allocator, ", \"required\": {}", .{dimension.required});
        try output.appendSlice(allocator, ", \"evidence\": ");
        try appendJsonString(allocator, output, dimension.evidence);
        try output.appendSlice(allocator, " }");
    }
    try output.append(allocator, ']');
}

fn appendSourceConsumptionGuardrailsJson(allocator: std.mem.Allocator, output: *std.ArrayList(u8), guardrails: []const SourceConsumptionGuardrail) !void {
    try output.append(allocator, '[');
    for (guardrails, 0..) |guardrail, index| {
        if (index > 0) try output.appendSlice(allocator, ", ");
        try output.appendSlice(allocator, "{ \"id\": ");
        try appendJsonString(allocator, output, guardrail.id);
        try output.print(allocator, ", \"required_before_boundary\": {}", .{guardrail.required_before_boundary});
        try output.appendSlice(allocator, ", \"reason\": ");
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

fn appendSourceNegativeFixturesJson(allocator: std.mem.Allocator, output: *std.ArrayList(u8), fixtures: []const SourceNegativeFixture) !void {
    try output.append(allocator, '[');
    for (fixtures, 0..) |fixture, index| {
        if (index > 0) try output.appendSlice(allocator, ", ");
        try output.appendSlice(allocator, "{ \"id\": ");
        try appendJsonString(allocator, output, fixture.id);
        try output.appendSlice(allocator, ", \"failed_gate\": ");
        try appendJsonString(allocator, output, fixture.failed_gate);
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

fn checkName(check: SourceCheck) []const u8 {
    if (check.name.len > 0) return check.name;
    return check.id;
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

fn blockedClaims(source: SourceReadinessArtifact) []const []const u8 {
    if (source.blocked_claims.len > 0) return source.blocked_claims;
    return denied_boundary_claims;
}

fn agentGuidance(status: BoundaryStatus) []const []const u8 {
    return switch (status) {
        .planned => &.{
            "Use planned consumption boundary evidence to prepare read-only agent and SolidJS webui consumption only.",
            "Do not claim applied consumers app runtime integration CI enforcement GitHub mutation or NenDB execution from plan mode.",
        },
        .applied => &.{
            "Use applied consumption boundary evidence to start consumption policy work only.",
            "Cite consumer changes before evidence after evidence consumer-after digest source readiness checks and denied claims.",
        },
        .blocked => &.{
            "Treat blocked consumption boundary evidence as a stop sign.",
            "Repair source readiness consumer evidence before/after evidence consumer-after safety or verification proof before continuing.",
        },
    };
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
    const consumer_after_text = if (options.consumer_after_path) |path|
        try readRequiredArtifact(init.io, allocator, path, error.MissingConsumerAfterInput)
    else
        null;
    defer if (consumer_after_text) |contents| allocator.free(contents);

    const reports = try formatReports(allocator, .{
        .options = options,
        .source_readiness_json = source_readiness_json,
        .consumer_after_text = consumer_after_text,
    });
    defer reports.deinit(allocator);

    const paths = try outputPathsForOptions(allocator, options);
    defer paths.deinit(allocator);

    try writeArtifact(init.io, paths.json_path, reports.json);
    try writeArtifact(init.io, paths.text_path, reports.text);
    std.debug.print("{s}", .{reports.text});
}

fn usage() []const u8 {
    return "usage: zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-boundary -- --from-readiness <consumption-readiness.json> plan|record-applied --reason <reason> [--consumer-after <report.txt|report.md|report.json>] [--by <actor>] [--policy <policy>] [--consumer-change <evidence>] [--before <evidence>] [--after <evidence>] [--verified-command <command>]... [--out-prefix <path-prefix>]\n";
}

fn failUsage(err: anyerror) noreturn {
    std.debug.print("causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-boundary error: {s}\n{s}", .{ @errorName(err), usage() });
    std.process.exit(2);
}

fn freeSliceOnly(allocator: std.mem.Allocator, values: []const []const u8) void {
    if (values.len > 0) allocator.free(values);
}

fn readyConsumptionReadinessJson() []const u8 {
    return ready_consumption_readiness_json;
}

fn blockedConsumptionReadinessJson() []const u8 {
    return blocked_consumption_readiness_json;
}

const ready_consumption_readiness_json =
    \\{
    \\  "schema": "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-readiness.v1",
    \\  "schema_version": 1,
    \\  "source_publication_policy": ".zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-publication-policy.json",
    \\  "source_publication_policy_schema": "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-publication-policy.v1",
    \\  "source_after_report_digest": "sha256:abc123",
    \\  "decision": "approve",
    \\  "consumption_readiness_status": "ready",
    \\  "ready_for_next_branch": true,
    \\  "ci_gate_enabled": false,
    \\  "ci_gate_enforcement_enabled": false,
    \\  "ci_required_status_check_enabled": false,
    \\  "ci_workflow_mutation_enabled": false,
    \\  "ci_upload_execution_enabled": false,
    \\  "ci_report_publication_enabled": false,
    \\  "github_step_summary_write_enabled": false,
    \\  "pull_request_comment_enabled": false,
    \\  "github_api_mutation_enabled": false,
    \\  "app_mutation_controls_enabled": false,
    \\  "app_mutation_enabled": false,
    \\  "app_config_write_enabled": false,
    \\  "app_data_write_enabled": false,
    \\  "app_runtime_integration_enabled": false,
    \\  "agent_query_live_projection_enabled": false,
    \\  "raw_payload_capture_enabled": false,
    \\  "deployment_mutation_enabled": false,
    \\  "production_telemetry_ingestion": false,
    \\  "live_exporter_enabled": false,
    \\  "network_send_enabled": false,
    \\  "collector_endpoint_configured": false,
    \\  "otlp_serialization_enabled": false,
    \\  "runtime_pipeline_enabled": false,
    \\  "durable_write_enabled": false,
    \\  "nendb_write_enabled": false,
    \\  "nendb_adapter_execution_enabled": false,
    \\  "advisory_report": true,
    \\  "read_only_preview": true,
    \\  "solid_webui_enabled": true,
    \\  "solid_webui_renderer": "solidjs",
    \\  "webui_bridge": "webui-dev/zig-webui",
    \\  "mutation_authority": "none",
    \\  "readiness_checks": [
    \\    { "name": "source-schema", "status": "pass", "detail": "supported" },
    \\    { "name": "source-policy-ready", "status": "pass", "detail": "ready" },
    \\    { "name": "consumption-guardrails-present", "status": "pass", "detail": "present" }
    \\  ],
    \\  "consumer_profiles": [
    \\    { "id": "reviewer-triage-consumer", "role": "maintainer", "consumption_enabled": true, "denied_claim": "required status check" },
    \\    { "id": "agent-readonly-consumer", "role": "agent-readonly", "consumption_enabled": true, "denied_claim": "mutation authority" },
    \\    { "id": "ci-advisory-consumer", "role": "ci-reviewer", "consumption_enabled": true, "denied_claim": "merge blocker" },
    \\    { "id": "solid-webui-consumer", "role": "workbench-viewer", "consumption_enabled": true, "denied_claim": "app mutation" },
    \\    { "id": "future-consumption-boundary-input", "role": "future-consumption-boundary-tool", "consumption_enabled": true, "denied_claim": "app runtime integration" }
    \\  ],
    \\  "readiness_dimensions": [
    \\    { "id": "bounded-agent-query-contract", "required": true, "evidence": "bounded ids only" },
    \\    { "id": "source-id-citation-required", "required": true, "evidence": "source ids carried" },
    \\    { "id": "no-runtime-integration", "required": true, "evidence": "runtime disabled" }
    \\  ],
    \\  "consumption_guardrails": [
    \\    { "id": "bounded-source-ids-only", "required_before_boundary": true, "reason": "bounded source ids" },
    \\    { "id": "no-app-runtime-integration", "required_before_boundary": true, "reason": "runtime disabled" },
    \\    { "id": "no-nendb-write-or-adapter-execution", "required_before_boundary": true, "reason": "NenDB not executed" }
    \\  ],
    \\  "denied_inference_rules": ["app-runtime-integration-proof", "nendb-adapter-execution-proof", "required-status-check-active"],
    \\  "negative_fixtures": [
    \\    { "id": "mutation-authority-claim-denied", "artifact_state": "mutation_authority=granted", "decision": "deny", "failed_gate": "source-policy-ready", "reason": "no mutation authority" }
    \\  ],
    \\  "blocked_claims": ["required-status-check-active", "github-api-mutation", "app-runtime-integration-proof", "nendb-adapter-execution-proof"],
    \\  "required_verification_commands": [
    \\    "bun run zigeffect:workbench:typecheck",
    \\    "bun run zigeffect:workbench:test",
    \\    "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-publication-policy",
    \\    "zig build causal-schema-governance -- --format json",
    \\    "zig build causal-production-hardening-backlog -- --format json",
    \\    "zig build examples",
    \\    "zig build test"
    \\  ],
    \\  "verified_commands": [
    \\    "bun run zigeffect:workbench:typecheck",
    \\    "bun run zigeffect:workbench:test",
    \\    "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-publication-policy",
    \\    "zig build causal-schema-governance -- --format json",
    \\    "zig build causal-production-hardening-backlog -- --format json",
    \\    "zig build examples",
    \\    "zig build test"
    \\  ],
    \\  "source_branch": "codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-readiness",
    \\  "recommendation": "start-app-facing-production-integration-ci-advisory-remediation-report-consumption-boundary",
    \\  "next_branch_if_ready": "codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-boundary"
    \\}
;

const blocked_consumption_readiness_json =
    \\{
    \\  "schema": "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-readiness.v1",
    \\  "schema_version": 1,
    \\  "source_publication_policy": ".zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-publication-policy.json",
    \\  "source_publication_policy_schema": "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-publication-policy.v1",
    \\  "source_after_report_digest": "sha256:abc123",
    \\  "decision": "reject",
    \\  "consumption_readiness_status": "blocked",
    \\  "ready_for_next_branch": false,
    \\  "ci_gate_enabled": false,
    \\  "ci_gate_enforcement_enabled": false,
    \\  "ci_required_status_check_enabled": false,
    \\  "ci_workflow_mutation_enabled": false,
    \\  "ci_upload_execution_enabled": false,
    \\  "ci_report_publication_enabled": false,
    \\  "github_step_summary_write_enabled": false,
    \\  "pull_request_comment_enabled": false,
    \\  "github_api_mutation_enabled": false,
    \\  "app_mutation_controls_enabled": false,
    \\  "app_mutation_enabled": false,
    \\  "app_config_write_enabled": false,
    \\  "app_data_write_enabled": false,
    \\  "app_runtime_integration_enabled": false,
    \\  "agent_query_live_projection_enabled": false,
    \\  "raw_payload_capture_enabled": false,
    \\  "deployment_mutation_enabled": false,
    \\  "production_telemetry_ingestion": false,
    \\  "live_exporter_enabled": false,
    \\  "network_send_enabled": false,
    \\  "collector_endpoint_configured": false,
    \\  "otlp_serialization_enabled": false,
    \\  "runtime_pipeline_enabled": false,
    \\  "durable_write_enabled": false,
    \\  "nendb_write_enabled": false,
    \\  "nendb_adapter_execution_enabled": false,
    \\  "advisory_report": true,
    \\  "read_only_preview": true,
    \\  "solid_webui_enabled": true,
    \\  "solid_webui_renderer": "solidjs",
    \\  "webui_bridge": "webui-dev/zig-webui",
    \\  "mutation_authority": "none",
    \\  "readiness_checks": [
    \\    { "name": "source-policy-ready", "status": "fail", "detail": "blocked" }
    \\  ],
    \\  "consumer_profiles": [
    \\    { "id": "reviewer-triage-consumer", "role": "maintainer", "consumption_enabled": true, "denied_claim": "required status check" },
    \\    { "id": "agent-readonly-consumer", "role": "agent-readonly", "consumption_enabled": true, "denied_claim": "mutation authority" },
    \\    { "id": "ci-advisory-consumer", "role": "ci-reviewer", "consumption_enabled": true, "denied_claim": "merge blocker" },
    \\    { "id": "solid-webui-consumer", "role": "workbench-viewer", "consumption_enabled": true, "denied_claim": "app mutation" },
    \\    { "id": "future-consumption-boundary-input", "role": "future-consumption-boundary-tool", "consumption_enabled": true, "denied_claim": "app runtime integration" }
    \\  ],
    \\  "readiness_dimensions": [
    \\    { "id": "bounded-agent-query-contract", "required": true, "evidence": "bounded ids only" },
    \\    { "id": "source-id-citation-required", "required": true, "evidence": "source ids carried" },
    \\    { "id": "no-runtime-integration", "required": true, "evidence": "runtime disabled" }
    \\  ],
    \\  "consumption_guardrails": [
    \\    { "id": "bounded-source-ids-only", "required_before_boundary": true, "reason": "bounded source ids" },
    \\    { "id": "no-app-runtime-integration", "required_before_boundary": true, "reason": "runtime disabled" },
    \\    { "id": "no-nendb-write-or-adapter-execution", "required_before_boundary": true, "reason": "NenDB not executed" }
    \\  ],
    \\  "denied_inference_rules": ["app-runtime-integration-proof", "nendb-adapter-execution-proof"],
    \\  "negative_fixtures": [
    \\    { "id": "mutation-authority-claim-denied", "artifact_state": "mutation_authority=granted", "decision": "deny", "failed_gate": "source-policy-ready", "reason": "no mutation authority" }
    \\  ],
    \\  "blocked_claims": ["required-status-check-active"],
    \\  "required_verification_commands": ["zig build examples"],
    \\  "verified_commands": ["zig build examples"]
    \\}
;

test "app-facing advisory remediation report consumption boundary schema and branch constants are stable" {
    try std.testing.expectEqualStrings("zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-boundary.v1", schema);
    try std.testing.expectEqual(@as(u32, 1), schema_version);
    try std.testing.expectEqualStrings("codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-boundary", source_branch);
    try std.testing.expectEqualStrings("start-app-facing-production-integration-ci-advisory-remediation-report-consumption-policy", recommendation);
    try std.testing.expectEqualStrings("codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-policy", next_branch_if_applied);
}

test "parses app-facing advisory remediation report consumption boundary plan and record-applied options" {
    var plan_options = try parseOptions(std.testing.allocator, &.{
        "zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-boundary",
        "--from-readiness",
        "readiness.json",
        "plan",
        "--reason",
        "planned",
    });
    defer plan_options.deinit(std.testing.allocator);
    try std.testing.expectEqual(Mode.plan, plan_options.mode);
    try std.testing.expectEqualStrings("readiness.json", plan_options.readiness_path);
    try std.testing.expectEqualStrings("planned", plan_options.reason);

    var applied_options = try parseOptions(std.testing.allocator, &.{
        "zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-boundary",
        "--from-readiness",
        "readiness.json",
        "record-applied",
        "--reason",
        "reviewed",
        "--consumer-after",
        "after.txt",
        "--consumer-change",
        "consumer boundary reviewed",
        "--before",
        "before evidence",
        "--after",
        "after evidence",
        "--verified-command",
        "zig build test",
        "--out-prefix",
        "out/boundary",
    });
    defer applied_options.deinit(std.testing.allocator);
    try std.testing.expectEqual(Mode.record_applied, applied_options.mode);
    try std.testing.expectEqualStrings("after.txt", applied_options.consumer_after_path.?);
    try std.testing.expectEqual(@as(usize, 1), applied_options.consumer_changes.len);
    try std.testing.expectEqual(@as(usize, 1), applied_options.before_evidence.len);
    try std.testing.expectEqual(@as(usize, 1), applied_options.after_evidence.len);
    try std.testing.expectEqual(@as(usize, 1), applied_options.verified_commands.len);
    try std.testing.expectEqualStrings("out/boundary", applied_options.out_prefix.?);
}

test "default output path replaces readiness suffix and compacts long names" {
    const paths = try defaultOutputPaths(
        std.testing.allocator,
        ".zig-cache/causal-artifacts/example-ci-advisory-remediation-report-consumption-readiness.json",
    );
    defer paths.deinit(std.testing.allocator);
    try std.testing.expectEqualStrings(".zig-cache/causal-artifacts/example-ci-advisory-remediation-report-consumption-boundary.json", paths.json_path);
    try std.testing.expectEqualStrings(".zig-cache/causal-artifacts/example-ci-advisory-remediation-report-consumption-boundary.txt", paths.text_path);

    const long_paths = try defaultOutputPaths(
        std.testing.allocator,
        "../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures-readiness-review-implementation-proposal-app-facing-boundary-local-fixtures-nendb-handoff-fixtures-ci-advisory-remediation-report-publication-policy-local-solid-webui-readonly-consumption-reviewer-boundary-consumption-readiness.json",
    );
    defer long_paths.deinit(std.testing.allocator);
    try std.testing.expect(fileName(long_paths.json_path).len <= max_default_output_file_name_len);
    try std.testing.expect(contains(long_paths.json_path, compact_output_prefix_name));
}

test "plan and record-applied boundary output preserve read-only authority" {
    const source = readyConsumptionReadinessJson();
    const plan_options = Options{
        .readiness_path = "readiness.json",
        .mode = .plan,
        .reason = "planned",
    };
    const plan_reports = try formatReports(std.testing.allocator, .{
        .options = plan_options,
        .source_readiness_json = source,
    });
    defer plan_reports.deinit(std.testing.allocator);
    try std.testing.expect(contains(plan_reports.text, "consumption_boundary_status: planned"));
    try std.testing.expect(contains(plan_reports.text, "applied: false"));
    try std.testing.expect(contains(plan_reports.text, "mutation_authority: none"));

    const applied_options = Options{
        .readiness_path = "readiness.json",
        .mode = .record_applied,
        .reason = "reviewed",
        .consumer_after_path = "after.txt",
        .consumer_changes = &.{"reviewed read-only consumer boundary"},
        .before_evidence = &.{"before evidence"},
        .after_evidence = &.{"after evidence"},
        .verified_commands = required_verification_commands,
    };
    const applied_reports = try formatReports(std.testing.allocator, .{
        .options = applied_options,
        .source_readiness_json = source,
        .consumer_after_text = "zigeffect causal read-only consumption boundary reviewed for local agents and SolidJS webui",
    });
    defer applied_reports.deinit(std.testing.allocator);
    try std.testing.expect(contains(applied_reports.text, "consumption_boundary_status: applied"));
    try std.testing.expect(contains(applied_reports.text, "applied: true"));
    try std.testing.expect(contains(applied_reports.text, "mutation_authority: record-only"));
    try std.testing.expect(contains(applied_reports.json, "\"app_runtime_integration_enabled\": false"));
    try std.testing.expect(contains(applied_reports.json, "\"nendb_adapter_execution_enabled\": false"));
}

test "missing evidence unsafe source and unsafe consumer-after block applied boundary" {
    const source = readyConsumptionReadinessJson();
    const missing_options = Options{
        .readiness_path = "readiness.json",
        .mode = .record_applied,
        .reason = "missing evidence",
    };
    const missing_reports = try formatReports(std.testing.allocator, .{
        .options = missing_options,
        .source_readiness_json = source,
    });
    defer missing_reports.deinit(std.testing.allocator);
    try std.testing.expect(contains(missing_reports.text, "consumption_boundary_status: blocked"));
    try std.testing.expect(contains(missing_reports.text, "applied: false"));

    const unsafe_source_reports = try formatReports(std.testing.allocator, .{
        .options = missing_options,
        .source_readiness_json = blockedConsumptionReadinessJson(),
    });
    defer unsafe_source_reports.deinit(std.testing.allocator);
    try std.testing.expect(contains(unsafe_source_reports.text, "source-readiness-ready: fail"));

    const unsafe_after_options = Options{
        .readiness_path = "readiness.json",
        .mode = .record_applied,
        .reason = "unsafe after",
        .consumer_after_path = "after.txt",
        .consumer_changes = &.{"reviewed read-only consumer boundary"},
        .before_evidence = &.{"before evidence"},
        .after_evidence = &.{"after evidence"},
        .verified_commands = required_verification_commands,
    };
    const unsafe_after_reports = try formatReports(std.testing.allocator, .{
        .options = unsafe_after_options,
        .source_readiness_json = source,
        .consumer_after_text = "zigeffect causal read-only consumption boundary with app_runtime_integration_enabled=true",
    });
    defer unsafe_after_reports.deinit(std.testing.allocator);
    try std.testing.expect(contains(unsafe_after_reports.text, "consumer-after-safe: fail"));
    try std.testing.expect(contains(unsafe_after_reports.text, "consumption_boundary_status: blocked"));
}
