const std = @import("std");

pub const schema = "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary.v1";
pub const schema_version: u32 = 1;
pub const source_branch = "codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary";
pub const recommendation = "start-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy";
pub const next_branch_if_applied = "codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy";

const source_report_schema = "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report.v1";
const generated_by = "causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary";
const source_report_suffix = "-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report.json";
const output_prefix_suffix = "-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary";
const compact_output_prefix_name = "app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary";
const max_default_output_file_name_len = 240;
const max_source_bytes = 1024 * 1024;

const required_verification_commands: []const []const u8 = &.{
    "bun run zigeffect:workbench:typecheck",
    "bun run zigeffect:workbench:test",
    "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report -- --help",
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
const public_artifact_upload_enabled = false;
const hosted_live_dashboard_enabled = false;
const production_health_claim_enabled = false;
const auto_apply_enabled = false;
const advisory_report = true;
const read_only_preview = true;
const read_only_consumption_enabled = true;
const solid_webui_enabled = true;
const solid_webui_renderer = "solidjs";
const webui_bridge = "webui-dev/zig-webui";

const Mode = enum { plan, record_applied };
const ReportApplicationStatus = enum { planned, applied, blocked };
const CheckStatus = enum { pass, fail, skipped };

const Options = struct {
    report_path: []const u8,
    mode: Mode,
    reviewed_by: []const u8 = "app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary-reviewer",
    policy: []const u8 = "manual-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary",
    reason: []const u8,
    report_after_path: ?[]const u8 = null,
    report_application_changes: []const []const u8 = &.{},
    before_evidence: []const []const u8 = &.{},
    after_evidence: []const []const u8 = &.{},
    verified_commands: []const []const u8 = &.{},
    out_prefix: ?[]const u8 = null,

    fn deinit(self: Options, allocator: std.mem.Allocator) void {
        freeSliceOnly(allocator, self.report_application_changes);
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
    source_report_json: []const u8,
    report_after_text: ?[]const u8 = null,
};

const BoundaryReports = struct {
    json: []const u8,
    text: []const u8,

    fn deinit(self: BoundaryReports, allocator: std.mem.Allocator) void {
        allocator.free(self.json);
        allocator.free(self.text);
    }
};

const SourceFile = struct {
    path: []const u8 = "",
    class: []const u8 = "",
    size_bytes: usize = 0,
    sha256: []const u8 = "",
    detected_schema: []const u8 = "",
    detected_role: []const u8 = "",
    redaction_posture: []const u8 = "",
    denied_reason: []const u8 = "",
};

const SourceSignal = struct {
    id: []const u8 = "",
    status: []const u8 = "",
    detail: []const u8 = "",
    evidence_path: []const u8 = "",
};

const SourceFinding = struct {
    id: []const u8 = "",
    severity: []const u8 = "",
    signal: []const u8 = "",
    detail: []const u8 = "",
    evidence_path: []const u8 = "",
};

const SourceCheck = struct {
    name: []const u8 = "",
    status: []const u8,
    detail: []const u8 = "",
};

const SourcePublicationChannel = struct {
    id: []const u8 = "",
    allowed: bool = false,
    executed_by_tool: bool = false,
    detail: []const u8 = "",
};

const SourceReportArtifact = struct {
    schema: []const u8,
    schema_version: u32,
    generated_by: []const u8 = "",
    source_branch: []const u8 = "",
    recommendation: []const u8 = "",
    next_branch_if_ready: []const u8 = "",
    source_evaluator: []const u8 = "",
    source_evaluator_schema: []const u8 = "",
    source_evaluator_status: []const u8 = "",
    source_ready_for_next_branch: bool = false,
    source_consumption_report_evaluation_report_evaluation_report_evaluation_report_policy: []const u8 = "",
    source_consumption_report_evaluation_report_evaluation_report_evaluation_report_policy_schema: []const u8 = "",
    source_evaluation_report_evaluation_report_evaluation_report_policy_status: []const u8 = "",
    source_consumption_report_evaluation_report_evaluation_report_evaluation_report_application_boundary: []const u8 = "",
    source_consumption_report_evaluation_report_evaluation_report_evaluation_report_application_boundary_schema: []const u8 = "",
    source_consumption_report_evaluation_report_evaluation_report_evaluation_report: []const u8 = "",
    source_consumption_report_evaluation_report_evaluation_report_evaluation_report_status: []const u8 = "",
    source_evaluation_report_evaluation_report_evaluation_report_application_status: []const u8 = "",
    source_evaluation_report_evaluation_report_evaluation_report_after_digest: []const u8 = "",
    source_evaluation_report_evaluation_report_evaluation_report_after_present: bool = false,
    source_evaluation_report_evaluation_report_evaluation_report_application_changes: []const []const u8 = &.{},
    source_consumption_report_evaluation_report_evaluation_report_policy: []const u8 = "",
    source_consumption_report_evaluation_report_evaluation_report_policy_schema: []const u8 = "",
    source_evaluation_report_evaluation_report_policy_status: []const u8 = "",
    source_policy_decision: []const u8 = "",
    source_consumption_report_evaluation_report_evaluation_report_application_boundary: []const u8 = "",
    source_consumption_report_evaluation_report_evaluation_report_application_boundary_schema: []const u8 = "",
    source_consumption_report_evaluation_report_evaluation_report: []const u8 = "",
    source_consumption_report_evaluation_report_evaluation_report_status: []const u8 = "",
    source_evaluation_report_evaluation_report_application_status: []const u8 = "",
    source_evaluation_report_evaluation_report_after_digest: []const u8 = "",
    source_evaluation_report_evaluation_report_after_present: bool = false,
    source_evaluation_report_evaluation_report_application_changes: []const []const u8 = &.{},
    source_consumption_report_application_boundary: []const u8 = "",
    source_report_application_status: []const u8 = "",
    source_consumption_report: []const u8 = "",
    source_consumption_report_status: []const u8 = "",
    source_report_policy_ready_for_next_branch: bool = false,
    source_mutation_authority: []const u8 = "",
    source_original_evaluator_status: []const u8 = "",
    source_consumption_policy: []const u8 = "",
    source_consumption_boundary: []const u8 = "",
    source_consumption_readiness: []const u8 = "",
    source_publication_policy: []const u8 = "",
    source_after_report_digest: []const u8 = "",
    source_consumer_after_digest: []const u8 = "",
    source_report_after_digest: []const u8 = "",
    source_report_after_present: bool = false,
    source_report_application_changes: []const []const u8 = &.{},
    source_before_evidence: []const []const u8 = &.{},
    source_after_evidence: []const []const u8 = &.{},
    source_report_before_evidence: []const []const u8 = &.{},
    source_report_after_evidence: []const []const u8 = &.{},
    source_report_next_queries: []const []const u8 = &.{},
    source_report_boundary_rules: []const []const u8 = &.{},
    source_report_publication_channel_ids: []const []const u8 = &.{},
    source_next_queries: []const []const u8 = &.{},
    source_boundary_rules: []const []const u8 = &.{},
    source_publication_channel_ids: []const []const u8 = &.{},
    source_policy_rule_ids_from_report: []const []const u8 = &.{},
    source_consumption_scope_ids_from_report: []const []const u8 = &.{},
    source_application_checks: []const SourceCheck = &.{},
    source_report_checks: []const SourceCheck = &.{},
    source_request_summary: []const SourceFile = &.{},
    source_support_evidence_summary: []const SourceFile = &.{},
    source_signal_summary: []const SourceSignal = &.{},
    source_blocked_findings: []const SourceFinding = &.{},
    source_advisory_findings: []const SourceFinding = &.{},
    report_sections: []const []const u8 = &.{},
    consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_status: []const u8,
    ready_for_next_branch: bool,
    blocked_findings_count: usize = 0,
    advisory_findings_count: usize = 0,
    mutation_authority: []const u8 = "",
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
    live_exporter_enabled: bool = true,
    network_send_enabled: bool = true,
    collector_endpoint_configured: bool = true,
    otlp_serialization_enabled: bool = true,
    runtime_pipeline_enabled: bool = true,
    durable_write_enabled: bool = true,
    nendb_write_enabled: bool = true,
    nendb_adapter_execution_enabled: bool = true,
    public_artifact_upload_enabled: bool = true,
    hosted_live_dashboard_enabled: bool = true,
    production_health_claim_enabled: bool = true,
    auto_apply_enabled: bool = true,
    advisory_report: bool = false,
    read_only_preview: bool = false,
    read_only_consumption_enabled: bool = false,
    solid_webui_enabled: bool = false,
    solid_webui_renderer: []const u8 = "",
    webui_bridge: []const u8 = "",
    request_summary: []const SourceFile = &.{},
    support_evidence_summary: []const SourceFile = &.{},
    signal_summary: []const SourceSignal = &.{},
    blocked_findings: []const SourceFinding = &.{},
    advisory_findings: []const SourceFinding = &.{},
    checks: []const SourceCheck = &.{},
    source_policy_rule_ids: []const []const u8 = &.{},
    source_consumption_scope_ids: []const []const u8 = &.{},
    denied_claims: []const []const u8 = &.{},
    next_queries: []const []const u8 = &.{},
    publication_channels: []const SourcePublicationChannel = &.{},
    required_verification_commands: []const []const u8 = &.{},
    agent_guidance: []const []const u8 = &.{},
};

const ApplicationCheck = struct {
    name: []const u8,
    status: CheckStatus,
    detail: []const u8,
};

const ApplicationResult = struct {
    status: ReportApplicationStatus,
    applied: bool,
    ready_for_next_branch: bool,
    mutation_authority: []const u8,
    checks: []const ApplicationCheck,

    fn deinit(self: ApplicationResult, allocator: std.mem.Allocator) void {
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

const required_report_after_markers: []const []const u8 = &.{ "zigeffect", "causal", "read-only", "consumption", "evaluation-report", "evaluation report", "application" };

const prohibited_report_after_markers: []const []const u8 = &.{
    "required_status_check",
    "required status check active",
    "ci_gate_enabled=true",
    "ci_gate_enforcement_enabled=true",
    "ci_required_status_check_enabled=true",
    "ci_workflow_mutation_enabled=true",
    "ci_upload_execution_enabled=true",
    "ci_report_publication_enabled=true",
    "public_artifact_upload_enabled=true",
    "github_api_mutation_enabled=true",
    "github_step_summary_write_enabled=true",
    "pull_request_comment_enabled=true",
    "app_mutation_enabled=true",
    "app_config_write_enabled=true",
    "app_data_write_enabled=true",
    "app_runtime_integration_enabled=true",
    "agent_query_live_projection_enabled=true",
    "raw_payload_capture_enabled=true",
    "raw prompt",
    "raw response",
    "deployment_mutation_enabled=true",
    "production_health_proven",
    "production health proven",
    "durable_write_enabled=true",
    "nendb_write_enabled=true",
    "nendb_adapter_execution_enabled=true",
    "cockroach",
    "non-nendb durable",
    "react renderer",
    "renderer=react",
    "auto_apply_enabled=true",
    "auto-apply",
    "mutation_authority=granted",
    "mutation authority granted",
    "secrets.",
    "PRODUCTION_TELEMETRY_TOKEN",
    "OTEL_EXPORTER_OTLP_ENDPOINT",
};

const boundary_rules: []const []const u8 = &.{
    "Plan mode records local consumption-report evaluation-report evaluation-report evaluation-report application intent only and never records applied state.",
    "record-applied requires reviewed evaluation-report evaluation-report evaluation-report application change evidence, before evidence, after evidence, safe after-report content, and full verification commands.",
    "Applied records are record-only evidence for local agents, reviewers, advisory CI readers, and the SolidJS webui; they do not mutate apps, GitHub, workflows, storage, runtimes, or adapters.",
    "Future consumption-report evaluation-report evaluation-report evaluation-report policy work may interpret applied records without creating mutation authority or public publication authority.",
};

const denied_application_claims: []const []const u8 = &.{
    "required-status-check-active",
    "merge-blocker-active",
    "ci-enforcement-active",
    "workflow-mutated-by-tool",
    "artifact-upload-executed-by-tool",
    "public-artifact-upload-executed",
    "github-api-mutated-by-tool",
    "github-step-summary-written-by-tool",
    "pull-request-comment-written-by-tool",
    "app-mutation-proof",
    "app-config-write-proof",
    "app-data-write-proof",
    "app-runtime-integration-proof",
    "agent-query-live-projection-proof",
    "raw-prompt-capture-proof",
    "raw-response-capture-proof",
    "raw-payload-capture-proof",
    "durable-write-proof",
    "nendb-write-proof",
    "nendb-adapter-execution-proof",
    "cockroach-adapter-work",
    "non-nendb-durable-storage",
    "deployment-success-proof",
    "production-health-proof",
    "cluster-readiness-proof",
    "react-renderer",
    "alternate-renderer",
    "auto-apply-proof",
    "mutation-authority",
};

const negative_fixtures: []const NegativeFixture = &.{
    .{ .id = "blocked-source-report-denied", .artifact_state = "consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_status=blocked", .decision = "deny", .failed_gate = "source-report-ready", .reason = "blocked source evaluation-report evaluation reports cannot feed application records" },
    .{ .id = "source-not-ready-denied", .artifact_state = "ready_for_next_branch=false", .decision = "deny", .failed_gate = "source-report-ready", .reason = "source report must be ready for this branch" },
    .{ .id = "blocked-findings-denied", .artifact_state = "blocked_findings_count>0", .decision = "deny", .failed_gate = "source-report-ready", .reason = "blocked findings stop evaluation-report application" },
    .{ .id = "source-authority-drift-denied", .artifact_state = "app_runtime_integration_enabled=true", .decision = "deny", .failed_gate = "source-authority-disabled", .reason = "source report cannot grant app runtime authority" },
    .{ .id = "source-publication-enabled-denied", .artifact_state = "ci-upload-artifact allowed=true", .decision = "deny", .failed_gate = "source-publication-local-only", .reason = "source report must remain local-only" },
    .{ .id = "plan-applied-claim-denied", .artifact_state = "mode=plan applied=true", .decision = "deny", .failed_gate = "plan-is-not-applied", .reason = "plan mode is never applied" },
    .{ .id = "missing-report-application-change-denied", .artifact_state = "record-applied evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_changes=[]", .decision = "deny", .failed_gate = "report-application-change-present", .reason = "reviewed evaluation report evaluation report evaluation report evaluation report application change evidence is required" },
    .{ .id = "missing-before-evidence-denied", .artifact_state = "record-applied before=[]", .decision = "deny", .failed_gate = "before-evidence-present", .reason = "before evidence is required" },
    .{ .id = "missing-after-evidence-denied", .artifact_state = "record-applied after=[]", .decision = "deny", .failed_gate = "after-evidence-present", .reason = "after evidence is required" },
    .{ .id = "missing-after-report-denied", .artifact_state = "record-applied report_after=null", .decision = "deny", .failed_gate = "after-report-present", .reason = "after-report content is required" },
    .{ .id = "unsafe-after-report-denied", .artifact_state = "app_runtime_integration_enabled=true", .decision = "deny", .failed_gate = "after-report-safe", .reason = "after-report content cannot claim app runtime integration" },
    .{ .id = "missing-post-verification-denied", .artifact_state = "verified_commands incomplete", .decision = "deny", .failed_gate = "post-verification-recorded", .reason = "all post-application verification commands are required" },
    .{ .id = "nendb-adapter-execution-denied", .artifact_state = "nendb_adapter_execution_enabled=true", .decision = "deny", .failed_gate = "source-authority-disabled", .reason = "boundary does not execute a NenDB adapter" },
    .{ .id = "cockroach-scope-denied", .artifact_state = "cockroach", .decision = "deny", .failed_gate = "after-report-safe", .reason = "durable adapter direction remains NenDB only" },
    .{ .id = "react-renderer-denied", .artifact_state = "renderer=react", .decision = "deny", .failed_gate = "after-report-safe", .reason = "workbench direction remains SolidJS inside zig-webui" },
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
        error.MissingReportInput, error.MissingReportAfterInput => failUsage(err),
        else => return err,
    };
}

fn parseOptions(allocator: std.mem.Allocator, args: []const []const u8) !Options {
    if (args.len < 2) return error.MissingReportPath;
    if (!std.mem.eql(u8, args[1], "--from-report")) return error.UnknownFlag;
    if (args.len < 3) return error.MissingReportPath;
    const report_path = args[2];
    if (!std.mem.endsWith(u8, report_path, ".json")) return error.InvalidReportPath;
    if (args.len < 4) return error.MissingMode;
    const mode = try parseMode(args[3]);

    var reviewed_by: []const u8 = "app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary-reviewer";
    var policy: []const u8 = "manual-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary";
    var reason: ?[]const u8 = null;
    var report_after_path: ?[]const u8 = null;
    var report_application_changes = std.ArrayList([]const u8).empty;
    var before_evidence = std.ArrayList([]const u8).empty;
    var after_evidence = std.ArrayList([]const u8).empty;
    var verified_commands = std.ArrayList([]const u8).empty;
    var out_prefix: ?[]const u8 = null;
    errdefer report_application_changes.deinit(allocator);
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
        } else if (std.mem.eql(u8, flag, "--evaluation-report-evaluation-report-evaluation-report-evaluation-report-after")) {
            if (!reportAfterPathValid(value)) return error.InvalidReportAfterPath;
            report_after_path = value;
        } else if (std.mem.eql(u8, flag, "--evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-change")) {
            try report_application_changes.append(allocator, value);
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
        .report_path = report_path,
        .mode = mode,
        .reviewed_by = reviewed_by,
        .policy = policy,
        .reason = final_reason,
        .report_after_path = report_after_path,
        .report_application_changes = try report_application_changes.toOwnedSlice(allocator),
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

fn reportAfterPathValid(path: []const u8) bool {
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

fn statusText(status: ReportApplicationStatus) []const u8 {
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
    else
        try defaultOutputPrefix(allocator, options.report_path);
    defer allocator.free(prefix);

    return .{
        .json_path = try std.fmt.allocPrint(allocator, "{s}.json", .{prefix}),
        .text_path = try std.fmt.allocPrint(allocator, "{s}.txt", .{prefix}),
    };
}

fn defaultOutputPrefix(allocator: std.mem.Allocator, report_path: []const u8) ![]const u8 {
    if (!std.mem.endsWith(u8, report_path, ".json")) return error.InvalidReportPath;

    const base = if (std.mem.endsWith(u8, report_path, source_report_suffix))
        report_path[0 .. report_path.len - source_report_suffix.len]
    else
        report_path[0 .. report_path.len - ".json".len];
    const candidate = try std.fmt.allocPrint(allocator, "{s}{s}", .{ base, output_prefix_suffix });
    errdefer allocator.free(candidate);

    if (fileName(candidate).len + ".json".len <= max_default_output_file_name_len) {
        return candidate;
    }

    const directory = directoryPrefix(candidate);
    const digest = shortPathDigest(report_path);
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
    var parsed = try std.json.parseFromSlice(SourceReportArtifact, allocator, input.source_report_json, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();

    const paths = try outputPathsForOptions(allocator, input.options);
    defer paths.deinit(allocator);

    const after_report_digest = if (input.report_after_text) |after_text|
        try textDigest(allocator, after_text)
    else
        try allocator.dupe(u8, "");
    defer allocator.free(after_report_digest);

    const result = try evaluateBoundary(allocator, input.options, parsed.value, input.report_after_text);
    defer result.deinit(allocator);

    const json = try formatBoundaryJson(allocator, input.options, parsed.value, input.report_after_text, after_report_digest, result, paths);
    errdefer allocator.free(json);
    const text = try formatBoundaryText(allocator, input.options, parsed.value, after_report_digest, result, paths);
    errdefer allocator.free(text);

    return .{ .json = json, .text = text };
}

fn evaluateBoundary(
    allocator: std.mem.Allocator,
    options: Options,
    source: SourceReportArtifact,
    report_after_text: ?[]const u8,
) !ApplicationResult {
    var checks = std.ArrayList(ApplicationCheck).empty;
    errdefer checks.deinit(allocator);

    try appendCheck(allocator, &checks, "source-report-schema", if (std.mem.eql(u8, source.schema, source_report_schema) and source.schema_version == 1) .pass else .fail, "source consumption-report evaluation-report evaluation-report evaluation-report schema is supported");
    try appendCheck(allocator, &checks, "source-report-ready", if (sourceReportReady(source)) .pass else .fail, "source consumption-report evaluation report evaluation report evaluation report is ready or advisory and ready for this branch with no blocked findings");
    try appendCheck(allocator, &checks, "source-authority-disabled", if (sourceAuthorityDisabled(source)) .pass else .fail, "source keeps CI GitHub app runtime storage deployment public upload and adapter authority disabled");
    try appendCheck(allocator, &checks, "source-solid-webui-readonly", if (sourceSolidWebuiReadonly(source)) .pass else .fail, "source remains SolidJS webui read-only evidence");
    try appendCheck(allocator, &checks, "source-refs-present", if (sourceRefsPresent(source)) .pass else .fail, "source evaluator report policy application boundary report and digest refs are present");
    try appendCheck(allocator, &checks, "source-summaries-present", if (sourceSummariesPresent(source)) .pass else .fail, "source request signal checks denied claims and next queries are present");
    try appendCheck(allocator, &checks, "source-checks-passed", if (sourceChecksPassed(source.checks)) .pass else .fail, "source report checks have no failures");
    try appendCheck(allocator, &checks, "source-publication-local-only", if (sourcePublicationLocalOnly(source.publication_channels)) .pass else .fail, "source publication channels remain local-only and non-mutating");
    try appendCheck(allocator, &checks, "source-verification-contract-present", if (sourceVerificationContractPresent(source)) .pass else .fail, "source report carries required verification commands");

    if (options.mode == .plan) {
        try appendCheck(allocator, &checks, "plan-is-not-applied", .pass, "plan mode records local evaluation-report evaluation-report evaluation-report application intent without applied state");
        try appendCheck(allocator, &checks, "report-application-change-present", .skipped, "plan mode does not claim evaluation-report evaluation-report evaluation-report evaluation-report application change evidence");
        try appendCheck(allocator, &checks, "before-evidence-present", .skipped, "plan mode does not claim before evidence");
        try appendCheck(allocator, &checks, "after-evidence-present", .skipped, "plan mode does not claim after evidence");
        try appendCheck(allocator, &checks, "post-verification-recorded", .skipped, "plan mode does not claim post-application verification");
        try appendCheck(allocator, &checks, "after-report-present", if (report_after_text == null) .skipped else .pass, "plan mode may include optional after-report evidence");
        try appendCheck(allocator, &checks, "after-report-safe", if (report_after_text) |after_text| reportAfterSafetyStatus(after_text) else .skipped, "optional after-report evidence preserves read-only application constraints");

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

    try appendCheck(allocator, &checks, "report-application-change-present", if (options.report_application_changes.len > 0) .pass else .fail, "record-applied requires reviewed evaluation-report evaluation-report evaluation-report evaluation-report application change evidence");
    try appendCheck(allocator, &checks, "before-evidence-present", if (options.before_evidence.len > 0) .pass else .fail, "record-applied requires before evidence");
    try appendCheck(allocator, &checks, "after-evidence-present", if (options.after_evidence.len > 0) .pass else .fail, "record-applied requires after evidence");
    try appendCheck(allocator, &checks, "post-verification-recorded", if (verifiedCommandsContainAll(options.verified_commands, required_verification_commands)) .pass else .fail, "record-applied requires every post-application verification command");
    try appendCheck(allocator, &checks, "after-report-present", if (report_after_text != null) .pass else .fail, "record-applied requires after-report content");
    try appendCheck(allocator, &checks, "after-report-safe", if (report_after_text) |after_text| reportAfterSafetyStatus(after_text) else .fail, "after-report evidence preserves read-only evaluation-report evaluation-report evaluation-report application constraints");

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

fn sourceReportReady(source: SourceReportArtifact) bool {
    return source.ready_for_next_branch and
        source.blocked_findings_count == 0 and
        (std.mem.eql(u8, source.consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_status, "ready") or std.mem.eql(u8, source.consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_status, "advisory")) and
        std.mem.eql(u8, source.mutation_authority, "none");
}

fn sourceAuthorityDisabled(source: SourceReportArtifact) bool {
    return std.mem.eql(u8, source.mutation_authority, "none") and
        std.mem.eql(u8, source.source_mutation_authority, "none") and
        !source.ci_gate_enabled and
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
        !source.nendb_adapter_execution_enabled and
        !source.public_artifact_upload_enabled and
        !source.hosted_live_dashboard_enabled and
        !source.production_health_claim_enabled and
        !source.auto_apply_enabled;
}

fn sourceSolidWebuiReadonly(source: SourceReportArtifact) bool {
    return source.advisory_report and
        source.read_only_preview and
        source.read_only_consumption_enabled and
        source.solid_webui_enabled and
        std.mem.eql(u8, source.solid_webui_renderer, solid_webui_renderer) and
        std.mem.eql(u8, source.webui_bridge, webui_bridge);
}

fn sourceRefsPresent(source: SourceReportArtifact) bool {
    return source.source_evaluator.len > 0 and
        source.source_evaluator_status.len > 0 and
        source.source_consumption_report_evaluation_report_evaluation_report_evaluation_report_policy.len > 0 and
        source.source_consumption_report_evaluation_report_evaluation_report_evaluation_report_policy_schema.len > 0 and
        std.mem.eql(u8, source.source_evaluation_report_evaluation_report_evaluation_report_policy_status, "ready") and
        source.source_consumption_report_evaluation_report_evaluation_report_evaluation_report_application_boundary.len > 0 and
        source.source_consumption_report_evaluation_report_evaluation_report_evaluation_report_application_boundary_schema.len > 0 and
        source.source_consumption_report_evaluation_report_evaluation_report_evaluation_report.len > 0 and
        source.source_consumption_report_evaluation_report_evaluation_report_evaluation_report_status.len > 0 and
        std.mem.eql(u8, source.source_evaluation_report_evaluation_report_evaluation_report_application_status, "applied") and
        source.source_evaluation_report_evaluation_report_evaluation_report_after_digest.len > 0 and
        source.source_evaluation_report_evaluation_report_evaluation_report_after_present and
        source.source_consumption_report_evaluation_report_evaluation_report_policy.len > 0 and
        source.source_consumption_report_evaluation_report_evaluation_report_policy_schema.len > 0 and
        std.mem.eql(u8, source.source_evaluation_report_evaluation_report_policy_status, "ready") and
        std.mem.eql(u8, source.source_policy_decision, "approve") and
        source.source_consumption_report_evaluation_report_evaluation_report_application_boundary.len > 0 and
        source.source_consumption_report_evaluation_report_evaluation_report_application_boundary_schema.len > 0 and
        source.source_consumption_report_evaluation_report_evaluation_report.len > 0 and
        source.source_consumption_report_evaluation_report_evaluation_report_status.len > 0 and
        std.mem.eql(u8, source.source_evaluation_report_evaluation_report_application_status, "applied") and
        source.source_consumption_report_application_boundary.len > 0 and
        std.mem.eql(u8, source.source_report_application_status, "applied") and
        source.source_consumption_report.len > 0 and
        source.source_consumption_report_status.len > 0 and
        source.source_report_policy_ready_for_next_branch and
        std.mem.eql(u8, source.source_mutation_authority, "none") and
        source.source_consumption_policy.len > 0 and
        source.source_consumption_boundary.len > 0 and
        source.source_consumption_readiness.len > 0 and
        source.source_publication_policy.len > 0 and
        source.source_after_report_digest.len > 0 and
        source.source_consumer_after_digest.len > 0 and
        source.source_report_after_digest.len > 0 and
        source.source_report_after_present;
}

fn sourceSummariesPresent(source: SourceReportArtifact) bool {
    return source.request_summary.len > 0 and
        source.signal_summary.len > 0 and
        source.checks.len > 0 and
        source.source_evaluation_report_evaluation_report_evaluation_report_application_changes.len > 0 and
        source.source_evaluation_report_evaluation_report_application_changes.len > 0 and
        source.source_report_application_changes.len > 0 and
        source.source_before_evidence.len > 0 and
        source.source_after_evidence.len > 0 and
        source.source_report_before_evidence.len > 0 and
        source.source_report_after_evidence.len > 0 and
        source.source_report_next_queries.len > 0 and
        source.source_report_boundary_rules.len > 0 and
        source.source_report_publication_channel_ids.len > 0 and
        source.source_next_queries.len > 0 and
        source.source_boundary_rules.len > 0 and
        source.source_publication_channel_ids.len > 0 and
        source.source_application_checks.len > 0 and
        source.source_report_checks.len > 0 and
        source.source_request_summary.len > 0 and
        source.source_signal_summary.len > 0 and
        source.report_sections.len > 0 and
        source.source_policy_rule_ids.len > 0 and
        source.source_consumption_scope_ids.len > 0 and
        source.denied_claims.len > 0 and
        source.next_queries.len > 0;
}

fn sourceChecksPassed(checks: []const SourceCheck) bool {
    if (checks.len == 0) return false;
    for (checks) |check| {
        if (std.mem.eql(u8, check.status, "fail")) return false;
    }
    return true;
}

fn sourcePublicationLocalOnly(channels: []const SourcePublicationChannel) bool {
    if (channels.len == 0) return false;

    var saw_local_json = false;
    var saw_local_text = false;
    for (channels) |channel| {
        if (std.mem.eql(u8, channel.id, "local-json-artifact")) {
            saw_local_json = channel.allowed and channel.executed_by_tool;
        } else if (std.mem.eql(u8, channel.id, "local-text-artifact")) {
            saw_local_text = channel.allowed and channel.executed_by_tool;
        } else if (std.mem.eql(u8, channel.id, "solid-webui-readonly-view")) {
            if (!channel.allowed or channel.executed_by_tool) return false;
        } else if (isProhibitedPublicationChannel(channel.id) and (channel.allowed or channel.executed_by_tool)) {
            return false;
        }
    }
    return saw_local_json and saw_local_text;
}

fn isProhibitedPublicationChannel(id: []const u8) bool {
    return std.mem.eql(u8, id, "ci-upload-artifact") or
        std.mem.eql(u8, id, "github-step-summary") or
        std.mem.eql(u8, id, "pull-request-comment") or
        std.mem.eql(u8, id, "required-status-check") or
        std.mem.eql(u8, id, "app-runtime-integration") or
        std.mem.eql(u8, id, "public-artifact-upload");
}

fn sourceVerificationContractPresent(source: SourceReportArtifact) bool {
    return source.required_verification_commands.len > 0 and
        containsString(source.required_verification_commands, "zig build causal-schema-governance -- --format json") and
        containsString(source.required_verification_commands, "zig build causal-production-hardening-backlog -- --format json");
}

fn reportAfterSafetyStatus(after_text: []const u8) CheckStatus {
    for (required_report_after_markers) |marker| {
        if (!contains(after_text, marker)) return .fail;
    }
    for (prohibited_report_after_markers) |marker| {
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
    source: SourceReportArtifact,
    report_after_text: ?[]const u8,
    after_report_digest: []const u8,
    result: ApplicationResult,
    paths: OutputPaths,
) ![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "{\n");
    try appendJsonField(allocator, &output, "schema", schema, true);
    try output.print(allocator, "  \"schema_version\": {d},\n", .{schema_version});
    try appendJsonField(allocator, &output, "generated_by", generated_by, true);
    try appendJsonField(allocator, &output, "source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report", options.report_path, true);
    try appendJsonField(allocator, &output, "source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_status", source.consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_status, true);
    try output.print(allocator, "  \"source_ready_for_next_branch\": {},\n", .{source.ready_for_next_branch});
    try appendJsonField(allocator, &output, "source_mutation_authority", source.mutation_authority, true);
    try appendJsonField(allocator, &output, "source_evaluator_status", source.source_evaluator_status, true);
    try appendJsonField(allocator, &output, "source_consumption_report_evaluation_report_evaluation_report_evaluation_report_policy", source.source_consumption_report_evaluation_report_evaluation_report_evaluation_report_policy, true);
    try appendJsonField(allocator, &output, "source_consumption_report_evaluation_report_evaluation_report_evaluation_report_policy_schema", source.source_consumption_report_evaluation_report_evaluation_report_evaluation_report_policy_schema, true);
    try appendJsonField(allocator, &output, "source_evaluation_report_evaluation_report_evaluation_report_policy_status", source.source_evaluation_report_evaluation_report_evaluation_report_policy_status, true);
    try appendJsonField(allocator, &output, "source_consumption_report_evaluation_report_evaluation_report_evaluation_report_application_boundary", source.source_consumption_report_evaluation_report_evaluation_report_evaluation_report_application_boundary, true);
    try appendJsonField(allocator, &output, "source_consumption_report_evaluation_report_evaluation_report_evaluation_report_application_boundary_schema", source.source_consumption_report_evaluation_report_evaluation_report_evaluation_report_application_boundary_schema, true);
    try appendJsonField(allocator, &output, "source_consumption_report_evaluation_report_evaluation_report_evaluation_report", source.source_consumption_report_evaluation_report_evaluation_report_evaluation_report, true);
    try appendJsonField(allocator, &output, "source_consumption_report_evaluation_report_evaluation_report_evaluation_report_status", source.source_consumption_report_evaluation_report_evaluation_report_evaluation_report_status, true);
    try appendJsonField(allocator, &output, "source_evaluation_report_evaluation_report_evaluation_report_application_status", source.source_evaluation_report_evaluation_report_evaluation_report_application_status, true);
    try appendJsonField(allocator, &output, "source_evaluation_report_evaluation_report_evaluation_report_after_digest", source.source_evaluation_report_evaluation_report_evaluation_report_after_digest, true);
    try output.print(allocator, "  \"source_evaluation_report_evaluation_report_evaluation_report_after_present\": {},\n", .{source.source_evaluation_report_evaluation_report_evaluation_report_after_present});
    try appendJsonField(allocator, &output, "source_consumption_report_evaluation_report_evaluation_report_policy", source.source_consumption_report_evaluation_report_evaluation_report_policy, true);
    try appendJsonField(allocator, &output, "source_consumption_report_evaluation_report_evaluation_report_policy_schema", source.source_consumption_report_evaluation_report_evaluation_report_policy_schema, true);
    try appendJsonField(allocator, &output, "source_evaluation_report_evaluation_report_policy_status", source.source_evaluation_report_evaluation_report_policy_status, true);
    try appendJsonField(allocator, &output, "source_policy_decision", source.source_policy_decision, true);
    try appendJsonField(allocator, &output, "source_consumption_report_evaluation_report_evaluation_report_application_boundary", source.source_consumption_report_evaluation_report_evaluation_report_application_boundary, true);
    try appendJsonField(allocator, &output, "source_consumption_report_evaluation_report_evaluation_report_application_boundary_schema", source.source_consumption_report_evaluation_report_evaluation_report_application_boundary_schema, true);
    try appendJsonField(allocator, &output, "source_consumption_report_evaluation_report_evaluation_report", source.source_consumption_report_evaluation_report_evaluation_report, true);
    try appendJsonField(allocator, &output, "source_consumption_report_evaluation_report_evaluation_report_status", source.source_consumption_report_evaluation_report_evaluation_report_status, true);
    try appendJsonField(allocator, &output, "source_evaluation_report_evaluation_report_application_status", source.source_evaluation_report_evaluation_report_application_status, true);
    try appendJsonField(allocator, &output, "source_consumption_report_application_boundary", source.source_consumption_report_application_boundary, true);
    try appendJsonField(allocator, &output, "source_report_application_status", source.source_report_application_status, true);
    try appendJsonField(allocator, &output, "source_consumption_report", source.source_consumption_report, true);
    try appendJsonField(allocator, &output, "source_consumption_report_status", source.source_consumption_report_status, true);
    try appendJsonField(allocator, &output, "source_consumption_policy", source.source_consumption_policy, true);
    try appendJsonField(allocator, &output, "source_consumption_boundary", source.source_consumption_boundary, true);
    try appendJsonField(allocator, &output, "source_consumption_readiness", source.source_consumption_readiness, true);
    try appendJsonField(allocator, &output, "source_publication_policy", source.source_publication_policy, true);
    try appendJsonField(allocator, &output, "source_after_report_digest", source.source_after_report_digest, true);
    try appendJsonField(allocator, &output, "source_consumer_after_digest", source.source_consumer_after_digest, true);
    try appendJsonField(allocator, &output, "source_report_after_digest", source.source_report_after_digest, true);
    try output.print(allocator, "  \"source_report_after_present\": {},\n", .{source.source_report_after_present});
    try appendJsonField(allocator, &output, "source_evaluation_report_evaluation_report_after_digest", source.source_evaluation_report_evaluation_report_after_digest, true);
    try output.print(allocator, "  \"source_evaluation_report_evaluation_report_after_present\": {},\n", .{source.source_evaluation_report_evaluation_report_after_present});
    try appendJsonField(allocator, &output, "mode", modeText(options.mode), true);
    try appendJsonField(allocator, &output, "evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_status", statusText(result.status), true);
    try output.print(allocator, "  \"applied\": {},\n", .{result.applied});
    try output.print(allocator, "  \"ready_for_next_branch\": {},\n", .{result.ready_for_next_branch});
    try appendJsonField(allocator, &output, "mutation_authority", result.mutation_authority, true);
    try appendAuthorityJson(allocator, &output);
    try appendJsonField(allocator, &output, "reviewed_by", options.reviewed_by, true);
    try appendJsonField(allocator, &output, "policy", options.policy, true);
    try appendJsonField(allocator, &output, "reason", options.reason, true);
    try output.appendSlice(allocator, "  \"evaluation_report_evaluation_report_evaluation_report_evaluation_report_after_path\": ");
    try appendOptionalJsonString(allocator, &output, options.report_after_path);
    try output.appendSlice(allocator, ",\n");
    try appendJsonField(allocator, &output, "evaluation_report_evaluation_report_evaluation_report_evaluation_report_after_digest", after_report_digest, true);
    try output.print(allocator, "  \"evaluation_report_evaluation_report_evaluation_report_evaluation_report_after_present\": {},\n", .{report_after_text != null});
    try output.print(allocator, "  \"source_blocked_findings_count\": {d},\n", .{source.blocked_findings_count});
    try output.print(allocator, "  \"source_advisory_findings_count\": {d},\n", .{source.advisory_findings_count});
    try output.appendSlice(allocator, "  \"evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_changes\": ");
    try appendStringArray(allocator, &output, options.report_application_changes);
    try output.appendSlice(allocator, ",\n  \"before_evidence\": ");
    try appendStringArray(allocator, &output, options.before_evidence);
    try output.appendSlice(allocator, ",\n  \"after_evidence\": ");
    try appendStringArray(allocator, &output, options.after_evidence);
    try output.appendSlice(allocator, ",\n  \"application_checks\": ");
    try appendApplicationChecksJson(allocator, &output, result.checks);
    try output.appendSlice(allocator, ",\n  \"source_checks\": ");
    try appendSourceChecksJson(allocator, &output, source.checks);
    try output.appendSlice(allocator, ",\n  \"source_evaluation_report_evaluation_report_evaluation_report_application_changes\": ");
    try appendStringArray(allocator, &output, source.source_evaluation_report_evaluation_report_evaluation_report_application_changes);
    try output.appendSlice(allocator, ",\n  \"source_evaluation_report_evaluation_report_application_changes\": ");
    try appendStringArray(allocator, &output, source.source_evaluation_report_evaluation_report_application_changes);
    try output.appendSlice(allocator, ",\n  \"source_report_application_changes\": ");
    try appendStringArray(allocator, &output, source.source_report_application_changes);
    try output.appendSlice(allocator, ",\n  \"source_before_evidence\": ");
    try appendStringArray(allocator, &output, source.source_before_evidence);
    try output.appendSlice(allocator, ",\n  \"source_after_evidence\": ");
    try appendStringArray(allocator, &output, source.source_after_evidence);
    try output.appendSlice(allocator, ",\n  \"source_report_before_evidence\": ");
    try appendStringArray(allocator, &output, source.source_report_before_evidence);
    try output.appendSlice(allocator, ",\n  \"source_report_after_evidence\": ");
    try appendStringArray(allocator, &output, source.source_report_after_evidence);
    try output.appendSlice(allocator, ",\n  \"source_report_next_queries\": ");
    try appendStringArray(allocator, &output, source.source_report_next_queries);
    try output.appendSlice(allocator, ",\n  \"source_report_boundary_rules\": ");
    try appendStringArray(allocator, &output, source.source_report_boundary_rules);
    try output.appendSlice(allocator, ",\n  \"source_report_publication_channel_ids\": ");
    try appendStringArray(allocator, &output, source.source_report_publication_channel_ids);
    try output.appendSlice(allocator, ",\n  \"source_next_queries\": ");
    try appendStringArray(allocator, &output, source.source_next_queries);
    try output.appendSlice(allocator, ",\n  \"source_boundary_rules\": ");
    try appendStringArray(allocator, &output, source.source_boundary_rules);
    try output.appendSlice(allocator, ",\n  \"source_publication_channel_ids\": ");
    try appendStringArray(allocator, &output, source.source_publication_channel_ids);
    try output.appendSlice(allocator, ",\n  \"source_application_checks\": ");
    try appendSourceChecksJson(allocator, &output, source.source_application_checks);
    try output.appendSlice(allocator, ",\n  \"source_report_checks\": ");
    try appendSourceChecksJson(allocator, &output, source.source_report_checks);
    try output.appendSlice(allocator, ",\n  \"source_request_summary\": ");
    try appendFilesJson(allocator, &output, source.source_request_summary);
    try output.appendSlice(allocator, ",\n  \"source_support_evidence_summary\": ");
    try appendFilesJson(allocator, &output, source.source_support_evidence_summary);
    try output.appendSlice(allocator, ",\n  \"source_signal_summary\": ");
    try appendSignalsJson(allocator, &output, source.source_signal_summary);
    try output.appendSlice(allocator, ",\n  \"source_blocked_findings\": ");
    try appendFindingsJson(allocator, &output, source.source_blocked_findings);
    try output.appendSlice(allocator, ",\n  \"source_advisory_findings\": ");
    try appendFindingsJson(allocator, &output, source.source_advisory_findings);
    try output.appendSlice(allocator, ",\n  \"request_summary\": ");
    try appendFilesJson(allocator, &output, source.request_summary);
    try output.appendSlice(allocator, ",\n  \"support_evidence_summary\": ");
    try appendFilesJson(allocator, &output, source.support_evidence_summary);
    try output.appendSlice(allocator, ",\n  \"signal_summary\": ");
    try appendSignalsJson(allocator, &output, source.signal_summary);
    try output.appendSlice(allocator, ",\n  \"blocked_findings\": ");
    try appendFindingsJson(allocator, &output, source.blocked_findings);
    try output.appendSlice(allocator, ",\n  \"advisory_findings\": ");
    try appendFindingsJson(allocator, &output, source.advisory_findings);
    try output.appendSlice(allocator, ",\n  \"source_policy_rule_ids\": ");
    try appendStringArray(allocator, &output, source.source_policy_rule_ids);
    try output.appendSlice(allocator, ",\n  \"source_consumption_scope_ids\": ");
    try appendStringArray(allocator, &output, source.source_consumption_scope_ids);
    try output.appendSlice(allocator, ",\n  \"denied_claims\": ");
    try appendStringArray(allocator, &output, source.denied_claims);
    try output.appendSlice(allocator, ",\n  \"next_queries\": ");
    try appendStringArray(allocator, &output, source.next_queries);
    try output.appendSlice(allocator, ",\n  \"source_publication_channels\": ");
    try appendPublicationChannelsJson(allocator, &output, source.publication_channels);
    try output.appendSlice(allocator, ",\n  \"boundary_rules\": ");
    try appendStringArray(allocator, &output, boundary_rules);
    try output.appendSlice(allocator, ",\n  \"denied_application_claims\": ");
    try appendStringArray(allocator, &output, denied_application_claims);
    try output.appendSlice(allocator, ",\n  \"negative_fixtures\": ");
    try appendNegativeFixturesJson(allocator, &output);
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

fn appendAuthorityJson(allocator: std.mem.Allocator, output: *std.ArrayList(u8)) !void {
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
    try output.print(allocator, "  \"public_artifact_upload_enabled\": {},\n", .{public_artifact_upload_enabled});
    try output.print(allocator, "  \"hosted_live_dashboard_enabled\": {},\n", .{hosted_live_dashboard_enabled});
    try output.print(allocator, "  \"production_health_claim_enabled\": {},\n", .{production_health_claim_enabled});
    try output.print(allocator, "  \"auto_apply_enabled\": {},\n", .{auto_apply_enabled});
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
    source: SourceReportArtifact,
    after_report_digest: []const u8,
    result: ApplicationResult,
    paths: OutputPaths,
) ![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "zigeffect app-facing CI advisory remediation report consumption report evaluation-report evaluation-report evaluation-report evaluation-report application boundary\n");
    try output.print(allocator, "schema: {s}\n", .{schema});
    try output.print(allocator, "source consumption report evaluation report evaluation report evaluation report evaluation report: {s}\n", .{options.report_path});
    try output.print(allocator, "source consumption report evaluation report evaluation report evaluation report evaluation report status: {s}\n", .{source.consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_status});
    try output.print(allocator, "source ready for next branch: {}\n", .{source.ready_for_next_branch});
    try output.print(allocator, "source evaluator status: {s}\n", .{source.source_evaluator_status});
    try output.print(allocator, "source evaluation report evaluation report evaluation report policy: {s}\n", .{source.source_consumption_report_evaluation_report_evaluation_report_evaluation_report_policy});
    try output.print(allocator, "source evaluation report evaluation report evaluation report policy status: {s}\n", .{source.source_evaluation_report_evaluation_report_evaluation_report_policy_status});
    try output.print(allocator, "source evaluation report evaluation report evaluation report application boundary: {s}\n", .{source.source_consumption_report_evaluation_report_evaluation_report_evaluation_report_application_boundary});
    try output.print(allocator, "source evaluation report evaluation report evaluation report application status: {s}\n", .{source.source_evaluation_report_evaluation_report_evaluation_report_application_status});
    try output.print(allocator, "source consumption report evaluation report evaluation report evaluation report: {s}\n", .{source.source_consumption_report_evaluation_report_evaluation_report_evaluation_report});
    try output.print(allocator, "source consumption report evaluation report evaluation report evaluation report status: {s}\n", .{source.source_consumption_report_evaluation_report_evaluation_report_evaluation_report_status});
    try output.print(allocator, "inherited source evaluation report evaluation report policy: {s}\n", .{source.source_consumption_report_evaluation_report_evaluation_report_policy});
    try output.print(allocator, "inherited source evaluation report evaluation report application boundary: {s}\n", .{source.source_consumption_report_evaluation_report_evaluation_report_application_boundary});
    try output.print(allocator, "source report application boundary: {s}\n", .{source.source_consumption_report_application_boundary});
    try output.print(allocator, "source report application status: {s}\n", .{source.source_report_application_status});
    try output.print(allocator, "source consumption report: {s}\n", .{source.source_consumption_report});
    try output.print(allocator, "source consumption report status: {s}\n", .{source.source_consumption_report_status});
    try output.print(allocator, "source mutation authority: {s}\n", .{source.mutation_authority});
    try output.print(allocator, "source after report digest: {s}\n", .{source.source_after_report_digest});
    try output.print(allocator, "source consumer after digest: {s}\n", .{source.source_consumer_after_digest});
    try output.print(allocator, "source report after digest: {s}\n", .{source.source_report_after_digest});
    try output.print(allocator, "mode: {s}\n", .{modeText(options.mode)});
    try output.print(allocator, "evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_status: {s}\n", .{statusText(result.status)});
    try output.print(allocator, "applied: {}\n", .{result.applied});
    try output.print(allocator, "ready_for_next_branch: {}\n", .{result.ready_for_next_branch});
    try output.print(allocator, "mutation_authority: {s}\n", .{result.mutation_authority});
    try output.print(allocator, "app runtime integration enabled: {}\n", .{app_runtime_integration_enabled});
    try output.print(allocator, "agent query live projection enabled: {}\n", .{agent_query_live_projection_enabled});
    try output.print(allocator, "raw payload capture enabled: {}\n", .{raw_payload_capture_enabled});
    try output.print(allocator, "nendb write enabled: {}\n", .{nendb_write_enabled});
    try output.print(allocator, "nendb adapter execution enabled: {}\n", .{nendb_adapter_execution_enabled});
    try output.print(allocator, "solid webui renderer: {s}\n", .{solid_webui_renderer});
    try output.print(allocator, "webui bridge: {s}\n", .{webui_bridge});
    try output.print(allocator, "reviewed_by: {s}\n", .{options.reviewed_by});
    try output.print(allocator, "policy: {s}\n", .{options.policy});
    try output.print(allocator, "reason: {s}\n", .{options.reason});
    try output.print(allocator, "evaluation report evaluation report evaluation report evaluation report after digest: {s}\n", .{after_report_digest});
    try output.print(allocator, "source branch: {s}\n", .{source_branch});
    try output.print(allocator, "recommendation: {s}\n", .{recommendation});
    try output.print(allocator, "next branch if applied: {s}\n", .{next_branch_if_applied});
    try output.print(allocator, "json output: {s}\n", .{paths.json_path});
    try output.print(allocator, "text output: {s}\n\n", .{paths.text_path});

    try output.appendSlice(allocator, "application checks:\n");
    for (result.checks) |check| {
        try output.print(allocator, "- {s}: {s} - {s}\n", .{ check.name, checkStatusText(check.status), check.detail });
    }
    try output.append(allocator, '\n');

    try appendTextList(allocator, &output, "evaluation report evaluation report evaluation report evaluation report application changes", options.report_application_changes);
    try appendTextList(allocator, &output, "before evidence", options.before_evidence);
    try appendTextList(allocator, &output, "after evidence", options.after_evidence);
    try appendSourceChecksText(allocator, &output, source.checks);
    try appendTextList(allocator, &output, "source evaluation report evaluation report evaluation report application changes", source.source_evaluation_report_evaluation_report_evaluation_report_application_changes);
    try appendTextList(allocator, &output, "inherited source evaluation report evaluation report application changes", source.source_evaluation_report_evaluation_report_application_changes);
    try appendTextList(allocator, &output, "source report application changes", source.source_report_application_changes);
    try appendTextList(allocator, &output, "source before evidence", source.source_before_evidence);
    try appendTextList(allocator, &output, "source after evidence", source.source_after_evidence);
    try appendTextList(allocator, &output, "source report before evidence", source.source_report_before_evidence);
    try appendTextList(allocator, &output, "source report after evidence", source.source_report_after_evidence);
    try appendTextList(allocator, &output, "source report next queries", source.source_report_next_queries);
    try appendTextList(allocator, &output, "source report boundary rules", source.source_report_boundary_rules);
    try appendTextList(allocator, &output, "source report publication channel ids", source.source_report_publication_channel_ids);
    try appendTextList(allocator, &output, "source next queries", source.source_next_queries);
    try appendTextList(allocator, &output, "source boundary rules", source.source_boundary_rules);
    try appendTextList(allocator, &output, "source policy rule ids", source.source_policy_rule_ids);
    try appendTextList(allocator, &output, "source consumption scope ids", source.source_consumption_scope_ids);
    try appendTextList(allocator, &output, "denied claims", source.denied_claims);
    try appendTextList(allocator, &output, "next queries", source.next_queries);
    try appendTextList(allocator, &output, "boundary rules", boundary_rules);
    try appendTextList(allocator, &output, "denied application claims", denied_application_claims);
    try appendNegativeFixturesText(allocator, &output);
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

fn appendApplicationChecksJson(allocator: std.mem.Allocator, output: *std.ArrayList(u8), checks: []const ApplicationCheck) !void {
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
        try appendJsonString(allocator, output, check.name);
        try output.appendSlice(allocator, ", \"status\": ");
        try appendJsonString(allocator, output, check.status);
        try output.appendSlice(allocator, ", \"detail\": ");
        try appendJsonString(allocator, output, check.detail);
        try output.appendSlice(allocator, " }");
    }
    try output.append(allocator, ']');
}

fn appendFilesJson(allocator: std.mem.Allocator, output: *std.ArrayList(u8), files: []const SourceFile) !void {
    try output.append(allocator, '[');
    for (files, 0..) |file, index| {
        if (index > 0) try output.appendSlice(allocator, ", ");
        try output.appendSlice(allocator, "{ \"path\": ");
        try appendJsonString(allocator, output, file.path);
        try output.appendSlice(allocator, ", \"class\": ");
        try appendJsonString(allocator, output, file.class);
        try output.print(allocator, ", \"size_bytes\": {d}, \"sha256\": ", .{file.size_bytes});
        try appendJsonString(allocator, output, file.sha256);
        try output.appendSlice(allocator, ", \"detected_schema\": ");
        try appendJsonString(allocator, output, file.detected_schema);
        try output.appendSlice(allocator, ", \"detected_role\": ");
        try appendJsonString(allocator, output, file.detected_role);
        try output.appendSlice(allocator, ", \"redaction_posture\": ");
        try appendJsonString(allocator, output, file.redaction_posture);
        try output.appendSlice(allocator, ", \"denied_reason\": ");
        try appendJsonString(allocator, output, file.denied_reason);
        try output.appendSlice(allocator, " }");
    }
    try output.append(allocator, ']');
}

fn appendSignalsJson(allocator: std.mem.Allocator, output: *std.ArrayList(u8), signals: []const SourceSignal) !void {
    try output.append(allocator, '[');
    for (signals, 0..) |signal, index| {
        if (index > 0) try output.appendSlice(allocator, ", ");
        try output.appendSlice(allocator, "{ \"id\": ");
        try appendJsonString(allocator, output, signal.id);
        try output.appendSlice(allocator, ", \"status\": ");
        try appendJsonString(allocator, output, signal.status);
        try output.appendSlice(allocator, ", \"detail\": ");
        try appendJsonString(allocator, output, signal.detail);
        try output.appendSlice(allocator, ", \"evidence_path\": ");
        try appendJsonString(allocator, output, signal.evidence_path);
        try output.appendSlice(allocator, " }");
    }
    try output.append(allocator, ']');
}

fn appendFindingsJson(allocator: std.mem.Allocator, output: *std.ArrayList(u8), findings: []const SourceFinding) !void {
    try output.append(allocator, '[');
    for (findings, 0..) |finding, index| {
        if (index > 0) try output.appendSlice(allocator, ", ");
        try output.appendSlice(allocator, "{ \"id\": ");
        try appendJsonString(allocator, output, finding.id);
        try output.appendSlice(allocator, ", \"severity\": ");
        try appendJsonString(allocator, output, finding.severity);
        try output.appendSlice(allocator, ", \"signal\": ");
        try appendJsonString(allocator, output, finding.signal);
        try output.appendSlice(allocator, ", \"detail\": ");
        try appendJsonString(allocator, output, finding.detail);
        try output.appendSlice(allocator, ", \"evidence_path\": ");
        try appendJsonString(allocator, output, finding.evidence_path);
        try output.appendSlice(allocator, " }");
    }
    try output.append(allocator, ']');
}

fn appendPublicationChannelsJson(allocator: std.mem.Allocator, output: *std.ArrayList(u8), channels: []const SourcePublicationChannel) !void {
    try output.append(allocator, '[');
    for (channels, 0..) |channel, index| {
        if (index > 0) try output.appendSlice(allocator, ", ");
        try output.appendSlice(allocator, "{ \"id\": ");
        try appendJsonString(allocator, output, channel.id);
        try output.print(allocator, ", \"allowed\": {}, \"executed_by_tool\": {}", .{ channel.allowed, channel.executed_by_tool });
        try output.appendSlice(allocator, ", \"detail\": ");
        try appendJsonString(allocator, output, channel.detail);
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

fn appendSourceChecksText(allocator: std.mem.Allocator, output: *std.ArrayList(u8), checks: []const SourceCheck) !void {
    try output.appendSlice(allocator, "source checks:\n");
    if (checks.len == 0) {
        try output.appendSlice(allocator, "- none\n\n");
        return;
    }
    for (checks) |check| {
        try output.print(allocator, "- {s}: {s} - {s}\n", .{ check.name, check.status, check.detail });
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

fn contains(haystack: []const u8, needle: []const u8) bool {
    return std.mem.indexOf(u8, haystack, needle) != null;
}

fn containsString(values: []const []const u8, needle: []const u8) bool {
    for (values) |value| {
        if (std.mem.eql(u8, value, needle)) return true;
    }
    return false;
}

fn agentGuidance(status: ReportApplicationStatus) []const []const u8 {
    return switch (status) {
        .planned => &.{
            "Use planned consumption-report evaluation-report evaluation-report evaluation-report application boundary evidence to prepare evaluation-report evaluation-report evaluation-report policy work only.",
            "Do not claim applied report consumption app runtime integration CI enforcement GitHub mutation public upload or NenDB execution from plan mode.",
        },
        .applied => &.{
            "Use applied consumption-report evaluation-report evaluation-report evaluation-report application boundary evidence to start evaluation-report evaluation-report evaluation-report policy work only.",
            "Cite evaluation-report evaluation-report evaluation-report application changes before evidence after evidence after-report digest source report checks denied claims and post-verification commands.",
        },
        .blocked => &.{
            "Treat blocked consumption-report evaluation-report evaluation-report evaluation-report application boundary evidence as a stop sign.",
            "Repair source report evidence before/after evidence after-report safety or verification proof before continuing.",
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
    const source_report_json = try readRequiredArtifact(init.io, allocator, options.report_path, error.MissingReportInput);
    defer allocator.free(source_report_json);
    const report_after_text = if (options.report_after_path) |path|
        try readRequiredArtifact(init.io, allocator, path, error.MissingReportAfterInput)
    else
        null;
    defer if (report_after_text) |contents| allocator.free(contents);

    const reports = try formatReports(allocator, .{
        .options = options,
        .source_report_json = source_report_json,
        .report_after_text = report_after_text,
    });
    defer reports.deinit(allocator);

    const paths = try outputPathsForOptions(allocator, options);
    defer paths.deinit(allocator);

    try writeArtifact(init.io, paths.json_path, reports.json);
    try writeArtifact(init.io, paths.text_path, reports.text);
    std.debug.print("{s}", .{reports.text});
}

fn usage() []const u8 {
    return "usage: zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary -- --from-report <consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report.json> plan|record-applied --reason <reason> [--evaluation-report-evaluation-report-evaluation-report-evaluation-report-after <report.txt|report.md|report.json>] [--evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-change <evidence>] [--before <evidence>] [--after <evidence>] [--verified-command <command>]... [--by <actor>] [--policy <policy>] [--out-prefix <path-prefix>]\n";
}

fn failUsage(err: anyerror) noreturn {
    std.debug.print("causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary error: {s}\n{s}", .{ @errorName(err), usage() });
    std.process.exit(2);
}

fn freeSliceOnly(allocator: std.mem.Allocator, values: []const []const u8) void {
    if (values.len > 0) allocator.free(values);
}

const safe_report_after_text =
    "zigeffect causal read-only consumption report evaluation-report evaluation report evaluation report evaluation report application boundary reviewed locally for agents reviewers non-blocking CI advisory readers and SolidJS webui.";

const ready_source_report_json =
    \\{
    \\  "schema": "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report.v1",
    \\  "schema_version": 1,
    \\  "generated_by": "causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report",
    \\  "source_evaluator": "evaluator.json",
    \\  "source_evaluator_schema": "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluator.v1",
    \\  "source_evaluator_status": "ready",
    \\  "source_ready_for_next_branch": true,
    \\  "source_consumption_report_evaluation_report_evaluation_report_evaluation_report_policy": "evaluation-report-evaluation-report-evaluation-report-policy.json",
    \\  "source_consumption_report_evaluation_report_evaluation_report_evaluation_report_policy_schema": "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-policy.v1",
    \\  "source_evaluation_report_evaluation_report_evaluation_report_policy_status": "ready",
    \\  "source_consumption_report_evaluation_report_evaluation_report_evaluation_report_application_boundary": "evaluation-report-evaluation-report-evaluation-report-application-boundary.json",
    \\  "source_consumption_report_evaluation_report_evaluation_report_evaluation_report_application_boundary_schema": "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-application-boundary.v1",
    \\  "source_consumption_report_evaluation_report_evaluation_report_evaluation_report": "evaluation-report-evaluation-report-evaluation-report.json",
    \\  "source_consumption_report_evaluation_report_evaluation_report_evaluation_report_status": "ready",
    \\  "source_evaluation_report_evaluation_report_evaluation_report_application_status": "applied",
    \\  "source_evaluation_report_evaluation_report_evaluation_report_after_digest": "sha256:evaluation-report-evaluation-report-evaluation-report-after",
    \\  "source_evaluation_report_evaluation_report_evaluation_report_after_present": true,
    \\  "source_evaluation_report_evaluation_report_evaluation_report_application_changes": ["reviewed local evaluation report evaluation report evaluation report application"],
    \\  "source_consumption_report_evaluation_report_evaluation_report_policy": "evaluation-report-policy.json",
    \\  "source_consumption_report_evaluation_report_evaluation_report_policy_schema": "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-policy.v1",
    \\  "source_evaluation_report_evaluation_report_policy_status": "ready",
    \\  "source_policy_decision": "approve",
    \\  "source_consumption_report_evaluation_report_evaluation_report_application_boundary": "evaluation-report-application-boundary.json",
    \\  "source_consumption_report_evaluation_report_evaluation_report_application_boundary_schema": "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-application-boundary.v1",
    \\  "source_consumption_report_evaluation_report_evaluation_report": "evaluation-report.json",
    \\  "source_consumption_report_evaluation_report_evaluation_report_status": "ready",
    \\  "source_evaluation_report_evaluation_report_application_status": "applied",
    \\  "source_evaluation_report_evaluation_report_after_digest": "sha256:evaluation-report-after",
    \\  "source_evaluation_report_evaluation_report_after_present": true,
    \\  "source_evaluation_report_evaluation_report_application_changes": ["reviewed local evaluation report application"],
    \\  "source_consumption_report_application_boundary": "report-application-boundary.json",
    \\  "source_report_application_status": "applied",
    \\  "source_consumption_report": "consumption-report.json",
    \\  "source_consumption_report_status": "ready",
    \\  "source_report_policy_ready_for_next_branch": true,
    \\  "source_mutation_authority": "none",
    \\  "source_original_evaluator_status": "ready",
    \\  "source_consumption_policy": "policy.json",
    \\  "source_consumption_boundary": "boundary.json",
    \\  "source_consumption_readiness": "readiness.json",
    \\  "source_publication_policy": "publication-policy.json",
    \\  "source_after_report_digest": "sha256:after",
    \\  "source_consumer_after_digest": "sha256:consumer",
    \\  "source_report_after_digest": "sha256:report-after",
    \\  "source_report_after_present": true,
    \\  "source_report_application_changes": ["reviewed local report application"],
    \\  "source_before_evidence": ["before report evidence"],
    \\  "source_after_evidence": ["after report evidence"],
    \\  "source_report_before_evidence": ["before report application evidence"],
    \\  "source_report_after_evidence": ["after report application evidence"],
    \\  "source_report_next_queries": ["inspect source report application"],
    \\  "source_report_boundary_rules": ["source record-only"],
    \\  "source_report_publication_channel_ids": ["local-json-artifact", "local-text-artifact"],
    \\  "source_next_queries": ["inspect source report policy"],
    \\  "source_boundary_rules": ["record-only"],
    \\  "source_publication_channel_ids": ["local-json-artifact", "local-text-artifact", "solid-webui-readonly-view"],
    \\  "source_policy_rule_ids_from_report": ["agent-bounded-context"],
    \\  "source_consumption_scope_ids_from_report": ["bounded-agent-context"],
    \\  "report_sections": ["status", "source", "checks"],
    \\  "source_application_checks": [{ "name": "source-report-schema", "status": "pass", "detail": "supported" }],
    \\  "source_report_checks": [{ "name": "source-report-ready", "status": "pass", "detail": "ready" }],
    \\  "source_request_summary": [{ "path": "source-request.json", "class": "request_json", "size_bytes": 12, "sha256": "sha256:source-req" }],
    \\  "source_support_evidence_summary": [{ "path": "source-support.txt", "class": "workbench_text", "size_bytes": 14, "sha256": "sha256:source-support" }],
    \\  "source_signal_summary": [{ "id": "source-request-present", "status": "observed", "detail": "source request present" }],
    \\  "source_blocked_findings": [],
    \\  "source_advisory_findings": [],
    \\  "consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_status": "ready",
    \\  "ready_for_next_branch": true,
    \\  "blocked_findings_count": 0,
    \\  "advisory_findings_count": 0,
    \\  "mutation_authority": "none",
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
    \\  "public_artifact_upload_enabled": false,
    \\  "hosted_live_dashboard_enabled": false,
    \\  "production_health_claim_enabled": false,
    \\  "auto_apply_enabled": false,
    \\  "advisory_report": true,
    \\  "read_only_preview": true,
    \\  "read_only_consumption_enabled": true,
    \\  "solid_webui_enabled": true,
    \\  "solid_webui_renderer": "solidjs",
    \\  "webui_bridge": "webui-dev/zig-webui",
    \\  "request_summary": [{ "path": "request.json", "class": "request_json", "size_bytes": 12, "sha256": "sha256:req", "detected_role": "agent-readonly", "redaction_posture": "redacted-bounded" }],
    \\  "support_evidence_summary": [{ "path": "support.txt", "class": "workbench_text", "size_bytes": 14, "sha256": "sha256:support", "detected_role": "workbench-viewer", "redaction_posture": "redacted-bounded" }],
    \\  "signal_summary": [{ "id": "request-present", "status": "observed", "detail": "request present" }],
    \\  "blocked_findings": [],
    \\  "advisory_findings": [],
    \\  "checks": [{ "name": "source-evaluator-schema", "status": "pass", "detail": "supported" }],
    \\  "source_policy_rule_ids": ["rule-agent-readonly"],
    \\  "source_consumption_scope_ids": ["scope-agent-context"],
    \\  "denied_claims": ["no-app-runtime-integration"],
    \\  "next_queries": ["inspect-source-policy-rules"],
    \\  "publication_channels": [
    \\    { "id": "local-json-artifact", "allowed": true, "executed_by_tool": true, "detail": "local JSON only" },
    \\    { "id": "local-text-artifact", "allowed": true, "executed_by_tool": true, "detail": "local text only" },
    \\    { "id": "solid-webui-readonly-view", "allowed": true, "executed_by_tool": false, "detail": "read-only view" },
    \\    { "id": "ci-upload-artifact", "allowed": false, "executed_by_tool": false, "detail": "disabled" },
    \\    { "id": "github-step-summary", "allowed": false, "executed_by_tool": false, "detail": "disabled" },
    \\    { "id": "pull-request-comment", "allowed": false, "executed_by_tool": false, "detail": "disabled" },
    \\    { "id": "required-status-check", "allowed": false, "executed_by_tool": false, "detail": "disabled" },
    \\    { "id": "app-runtime-integration", "allowed": false, "executed_by_tool": false, "detail": "disabled" }
    \\  ],
    \\  "required_verification_commands": [
    \\    "bun run zigeffect:workbench:typecheck",
    \\    "bun run zigeffect:workbench:test",
    \\    "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report -- --help",
    \\    "zig build causal-schema-governance -- --format json",
    \\    "zig build causal-production-hardening-backlog -- --format json",
    \\    "zig build examples",
    \\    "zig build test"
    \\  ],
    \\  "agent_guidance": ["use bounded context only"]
    \\}
;

const blocked_source_report_json =
    \\{
    \\  "schema": "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report.v1",
    \\  "schema_version": 1,
    \\  "source_evaluator": "evaluator.json",
    \\  "source_evaluator_schema": "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluator.v1",
    \\  "source_evaluator_status": "blocked",
    \\  "source_ready_for_next_branch": false,
    \\  "source_consumption_report_evaluation_report_evaluation_report_evaluation_report_policy": "evaluation-report-evaluation-report-evaluation-report-policy.json",
    \\  "source_consumption_report_evaluation_report_evaluation_report_evaluation_report_policy_schema": "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-policy.v1",
    \\  "source_evaluation_report_evaluation_report_evaluation_report_policy_status": "ready",
    \\  "source_consumption_report_evaluation_report_evaluation_report_evaluation_report_application_boundary": "evaluation-report-evaluation-report-evaluation-report-application-boundary.json",
    \\  "source_consumption_report_evaluation_report_evaluation_report_evaluation_report_application_boundary_schema": "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-application-boundary.v1",
    \\  "source_consumption_report_evaluation_report_evaluation_report_evaluation_report": "evaluation-report-evaluation-report-evaluation-report.json",
    \\  "source_consumption_report_evaluation_report_evaluation_report_evaluation_report_status": "blocked",
    \\  "source_evaluation_report_evaluation_report_evaluation_report_application_status": "applied",
    \\  "source_evaluation_report_evaluation_report_evaluation_report_after_digest": "sha256:evaluation-report-evaluation-report-evaluation-report-after",
    \\  "source_evaluation_report_evaluation_report_evaluation_report_after_present": true,
    \\  "source_evaluation_report_evaluation_report_evaluation_report_application_changes": ["reviewed blocked local evaluation report evaluation report evaluation report application"],
    \\  "source_consumption_report_evaluation_report_evaluation_report_policy": "evaluation-report-policy.json",
    \\  "source_consumption_report_evaluation_report_evaluation_report_policy_schema": "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-policy.v1",
    \\  "source_evaluation_report_evaluation_report_policy_status": "ready",
    \\  "source_policy_decision": "approve",
    \\  "source_consumption_report_evaluation_report_evaluation_report_application_boundary": "evaluation-report-application-boundary.json",
    \\  "source_consumption_report_evaluation_report_evaluation_report_application_boundary_schema": "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-application-boundary.v1",
    \\  "source_consumption_report_evaluation_report_evaluation_report": "evaluation-report.json",
    \\  "source_consumption_report_evaluation_report_evaluation_report_status": "blocked",
    \\  "source_evaluation_report_evaluation_report_application_status": "applied",
    \\  "source_evaluation_report_evaluation_report_after_digest": "sha256:evaluation-report-after",
    \\  "source_evaluation_report_evaluation_report_after_present": true,
    \\  "source_evaluation_report_evaluation_report_application_changes": ["reviewed blocked local evaluation report application"],
    \\  "source_consumption_report_application_boundary": "report-application-boundary.json",
    \\  "source_report_application_status": "applied",
    \\  "source_consumption_report": "consumption-report.json",
    \\  "source_consumption_report_status": "blocked",
    \\  "source_report_policy_ready_for_next_branch": true,
    \\  "source_mutation_authority": "none",
    \\  "source_original_evaluator_status": "blocked",
    \\  "source_consumption_policy": "policy.json",
    \\  "source_consumption_boundary": "boundary.json",
    \\  "source_consumption_readiness": "readiness.json",
    \\  "source_publication_policy": "publication-policy.json",
    \\  "source_after_report_digest": "sha256:after",
    \\  "source_consumer_after_digest": "sha256:consumer",
    \\  "source_report_after_digest": "sha256:report-after",
    \\  "source_report_after_present": true,
    \\  "source_report_application_changes": ["reviewed blocked local report application"],
    \\  "source_before_evidence": ["before report evidence"],
    \\  "source_after_evidence": ["after report evidence"],
    \\  "source_report_before_evidence": ["before blocked report application evidence"],
    \\  "source_report_after_evidence": ["after blocked report application evidence"],
    \\  "source_report_next_queries": ["inspect blocked source report application"],
    \\  "source_report_boundary_rules": ["source record-only"],
    \\  "source_report_publication_channel_ids": ["local-json-artifact", "local-text-artifact"],
    \\  "source_next_queries": ["inspect blocked source report policy"],
    \\  "source_boundary_rules": ["record-only"],
    \\  "source_publication_channel_ids": ["local-json-artifact", "local-text-artifact"],
    \\  "source_policy_rule_ids_from_report": ["agent-bounded-context"],
    \\  "source_consumption_scope_ids_from_report": ["bounded-agent-context"],
    \\  "report_sections": ["status", "source", "checks"],
    \\  "source_application_checks": [{ "name": "source-report-schema", "status": "pass", "detail": "supported" }],
    \\  "source_report_checks": [{ "name": "source-report-ready", "status": "fail", "detail": "blocked" }],
    \\  "source_request_summary": [{ "path": "source-request.json", "class": "request_json", "size_bytes": 12, "sha256": "sha256:source-req" }],
    \\  "source_support_evidence_summary": [{ "path": "source-support.txt", "class": "workbench_text", "size_bytes": 14, "sha256": "sha256:source-support" }],
    \\  "source_signal_summary": [{ "id": "source-request-present", "status": "blocked", "detail": "source request blocked" }],
    \\  "source_blocked_findings": [{ "id": "blocked-source", "severity": "blocked", "signal": "source", "detail": "blocked", "evidence_path": "source.json" }],
    \\  "source_advisory_findings": [],
    \\  "consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_status": "blocked",
    \\  "ready_for_next_branch": false,
    \\  "blocked_findings_count": 1,
    \\  "mutation_authority": "none",
    \\  "ci_gate_enabled": false, "ci_gate_enforcement_enabled": false, "ci_required_status_check_enabled": false, "ci_workflow_mutation_enabled": false,
    \\  "ci_upload_execution_enabled": false, "ci_report_publication_enabled": false, "github_step_summary_write_enabled": false, "pull_request_comment_enabled": false,
    \\  "github_api_mutation_enabled": false, "app_mutation_controls_enabled": false, "app_mutation_enabled": false, "app_config_write_enabled": false,
    \\  "app_data_write_enabled": false, "app_runtime_integration_enabled": false, "agent_query_live_projection_enabled": false, "raw_payload_capture_enabled": false,
    \\  "deployment_mutation_enabled": false, "production_telemetry_ingestion": false, "live_exporter_enabled": false, "network_send_enabled": false,
    \\  "collector_endpoint_configured": false, "otlp_serialization_enabled": false, "runtime_pipeline_enabled": false, "durable_write_enabled": false,
    \\  "nendb_write_enabled": false, "nendb_adapter_execution_enabled": false,
    \\  "public_artifact_upload_enabled": false, "hosted_live_dashboard_enabled": false, "production_health_claim_enabled": false, "auto_apply_enabled": false,
    \\  "advisory_report": true, "read_only_preview": true, "read_only_consumption_enabled": true, "solid_webui_enabled": true,
    \\  "solid_webui_renderer": "solidjs", "webui_bridge": "webui-dev/zig-webui",
    \\  "request_summary": [{ "path": "request.json", "class": "request_json", "size_bytes": 12, "sha256": "sha256:req" }],
    \\  "signal_summary": [{ "id": "request-present", "status": "blocked", "detail": "blocked" }],
    \\  "checks": [{ "name": "source-evaluator-schema", "status": "fail", "detail": "blocked" }],
    \\  "source_policy_rule_ids": ["rule-agent-readonly"],
    \\  "source_consumption_scope_ids": ["scope-agent-context"],
    \\  "denied_claims": ["no-app-runtime-integration"],
    \\  "next_queries": ["inspect-source-policy-rules"],
    \\  "publication_channels": [
    \\    { "id": "local-json-artifact", "allowed": true, "executed_by_tool": true, "detail": "local JSON only" },
    \\    { "id": "local-text-artifact", "allowed": true, "executed_by_tool": true, "detail": "local text only" }
    \\  ],
    \\  "required_verification_commands": ["zig build causal-schema-governance -- --format json", "zig build causal-production-hardening-backlog -- --format json"]
    \\}
;

const authority_drift_source_report_json =
    \\{
    \\  "schema": "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report.v1",
    \\  "schema_version": 1,
    \\  "source_evaluator": "evaluator.json",
    \\  "source_evaluator_schema": "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluator.v1",
    \\  "source_evaluator_status": "ready",
    \\  "source_ready_for_next_branch": true,
    \\  "source_consumption_report_evaluation_report_evaluation_report_evaluation_report_policy": "evaluation-report-evaluation-report-evaluation-report-policy.json",
    \\  "source_consumption_report_evaluation_report_evaluation_report_evaluation_report_policy_schema": "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-policy.v1",
    \\  "source_evaluation_report_evaluation_report_evaluation_report_policy_status": "ready",
    \\  "source_consumption_report_evaluation_report_evaluation_report_evaluation_report_application_boundary": "evaluation-report-evaluation-report-evaluation-report-application-boundary.json",
    \\  "source_consumption_report_evaluation_report_evaluation_report_evaluation_report_application_boundary_schema": "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-application-boundary.v1",
    \\  "source_consumption_report_evaluation_report_evaluation_report_evaluation_report": "evaluation-report-evaluation-report-evaluation-report.json",
    \\  "source_consumption_report_evaluation_report_evaluation_report_evaluation_report_status": "ready",
    \\  "source_evaluation_report_evaluation_report_evaluation_report_application_status": "applied",
    \\  "source_evaluation_report_evaluation_report_evaluation_report_after_digest": "sha256:evaluation-report-evaluation-report-evaluation-report-after",
    \\  "source_evaluation_report_evaluation_report_evaluation_report_after_present": true,
    \\  "source_evaluation_report_evaluation_report_evaluation_report_application_changes": ["reviewed authority local evaluation report evaluation report evaluation report application"],
    \\  "source_consumption_report_evaluation_report_evaluation_report_policy": "evaluation-report-policy.json",
    \\  "source_consumption_report_evaluation_report_evaluation_report_policy_schema": "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-policy.v1",
    \\  "source_evaluation_report_evaluation_report_policy_status": "ready",
    \\  "source_policy_decision": "approve",
    \\  "source_consumption_report_evaluation_report_evaluation_report_application_boundary": "evaluation-report-application-boundary.json",
    \\  "source_consumption_report_evaluation_report_evaluation_report_application_boundary_schema": "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-application-boundary.v1",
    \\  "source_consumption_report_evaluation_report_evaluation_report": "evaluation-report.json",
    \\  "source_consumption_report_evaluation_report_evaluation_report_status": "ready",
    \\  "source_evaluation_report_evaluation_report_application_status": "applied",
    \\  "source_evaluation_report_evaluation_report_after_digest": "sha256:evaluation-report-after",
    \\  "source_evaluation_report_evaluation_report_after_present": true,
    \\  "source_evaluation_report_evaluation_report_application_changes": ["reviewed authority local evaluation report application"],
    \\  "source_consumption_report_application_boundary": "report-application-boundary.json",
    \\  "source_report_application_status": "applied",
    \\  "source_consumption_report": "consumption-report.json",
    \\  "source_consumption_report_status": "ready",
    \\  "source_report_policy_ready_for_next_branch": true,
    \\  "source_mutation_authority": "none",
    \\  "source_original_evaluator_status": "ready",
    \\  "source_consumption_policy": "policy.json",
    \\  "source_consumption_boundary": "boundary.json",
    \\  "source_consumption_readiness": "readiness.json",
    \\  "source_publication_policy": "publication-policy.json",
    \\  "source_after_report_digest": "sha256:after",
    \\  "source_consumer_after_digest": "sha256:consumer",
    \\  "source_report_after_digest": "sha256:report-after",
    \\  "source_report_after_present": true,
    \\  "source_report_application_changes": ["reviewed authority local report application"],
    \\  "source_before_evidence": ["before report evidence"],
    \\  "source_after_evidence": ["after report evidence"],
    \\  "source_report_before_evidence": ["before authority report application evidence"],
    \\  "source_report_after_evidence": ["after authority report application evidence"],
    \\  "source_report_next_queries": ["inspect authority source report application"],
    \\  "source_report_boundary_rules": ["source record-only"],
    \\  "source_report_publication_channel_ids": ["local-json-artifact", "local-text-artifact"],
    \\  "source_next_queries": ["inspect authority source report policy"],
    \\  "source_boundary_rules": ["record-only"],
    \\  "source_publication_channel_ids": ["local-json-artifact", "local-text-artifact"],
    \\  "source_policy_rule_ids_from_report": ["agent-bounded-context"],
    \\  "source_consumption_scope_ids_from_report": ["bounded-agent-context"],
    \\  "report_sections": ["status", "source", "checks"],
    \\  "source_application_checks": [{ "name": "source-report-schema", "status": "pass", "detail": "supported" }],
    \\  "source_report_checks": [{ "name": "source-report-ready", "status": "pass", "detail": "ready" }],
    \\  "source_request_summary": [{ "path": "source-request.json", "class": "request_json", "size_bytes": 12, "sha256": "sha256:source-req" }],
    \\  "source_support_evidence_summary": [{ "path": "source-support.txt", "class": "workbench_text", "size_bytes": 14, "sha256": "sha256:source-support" }],
    \\  "source_signal_summary": [{ "id": "source-request-present", "status": "observed", "detail": "source request present" }],
    \\  "source_blocked_findings": [],
    \\  "source_advisory_findings": [],
    \\  "consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_status": "ready",
    \\  "ready_for_next_branch": true,
    \\  "blocked_findings_count": 0,
    \\  "mutation_authority": "none",
    \\  "ci_gate_enabled": false, "ci_gate_enforcement_enabled": false, "ci_required_status_check_enabled": false, "ci_workflow_mutation_enabled": false,
    \\  "ci_upload_execution_enabled": false, "ci_report_publication_enabled": false, "github_step_summary_write_enabled": false, "pull_request_comment_enabled": false,
    \\  "github_api_mutation_enabled": false, "app_mutation_controls_enabled": false, "app_mutation_enabled": false, "app_config_write_enabled": false,
    \\  "app_data_write_enabled": false, "app_runtime_integration_enabled": true, "agent_query_live_projection_enabled": false, "raw_payload_capture_enabled": false,
    \\  "deployment_mutation_enabled": false, "production_telemetry_ingestion": false, "live_exporter_enabled": false, "network_send_enabled": false,
    \\  "collector_endpoint_configured": false, "otlp_serialization_enabled": false, "runtime_pipeline_enabled": false, "durable_write_enabled": false,
    \\  "nendb_write_enabled": false, "nendb_adapter_execution_enabled": false,
    \\  "public_artifact_upload_enabled": false, "hosted_live_dashboard_enabled": false, "production_health_claim_enabled": false, "auto_apply_enabled": false,
    \\  "advisory_report": true, "read_only_preview": true, "read_only_consumption_enabled": true, "solid_webui_enabled": true,
    \\  "solid_webui_renderer": "solidjs", "webui_bridge": "webui-dev/zig-webui",
    \\  "request_summary": [{ "path": "request.json", "class": "request_json", "size_bytes": 12, "sha256": "sha256:req" }],
    \\  "signal_summary": [{ "id": "request-present", "status": "observed", "detail": "ready" }],
    \\  "checks": [{ "name": "source-evaluator-schema", "status": "pass", "detail": "supported" }],
    \\  "source_policy_rule_ids": ["rule-agent-readonly"],
    \\  "source_consumption_scope_ids": ["scope-agent-context"],
    \\  "denied_claims": ["no-app-runtime-integration"],
    \\  "next_queries": ["inspect-source-policy-rules"],
    \\  "publication_channels": [
    \\    { "id": "local-json-artifact", "allowed": true, "executed_by_tool": true, "detail": "local JSON only" },
    \\    { "id": "local-text-artifact", "allowed": true, "executed_by_tool": true, "detail": "local text only" }
    \\  ],
    \\  "required_verification_commands": ["zig build causal-schema-governance -- --format json", "zig build causal-production-hardening-backlog -- --format json"]
    \\}
;

test "app-facing consumption report evaluation-report evaluation-report evaluation-report application boundary constants are stable" {
    try std.testing.expectEqualStrings("zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary.v1", schema);
    try std.testing.expectEqual(@as(u32, 1), schema_version);
    try std.testing.expectEqualStrings("codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary", source_branch);
    try std.testing.expectEqualStrings("start-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy", recommendation);
    try std.testing.expectEqualStrings("codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy", next_branch_if_applied);
}

test "parses app-facing consumption report evaluation-report evaluation-report evaluation-report application boundary options" {
    const args = &.{
        "tool",
        "--from-report",
        "source-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report.json",
        "record-applied",
        "--reason",
        "reviewed local report application",
        "--evaluation-report-evaluation-report-evaluation-report-evaluation-report-after",
        "after-report.md",
        "--evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-change",
        "reviewed evaluation report evaluation report evaluation report application change",
        "--before",
        "before evidence",
        "--after",
        "after evidence",
        "--verified-command",
        "zig build test",
        "--out-prefix",
        ".zig-cache/causal-artifacts/report-application-boundary",
    };

    const options = try parseOptions(std.testing.allocator, args);
    defer options.deinit(std.testing.allocator);

    try std.testing.expectEqual(Mode.record_applied, options.mode);
    try std.testing.expectEqualStrings("source-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report.json", options.report_path);
    try std.testing.expectEqualStrings("after-report.md", options.report_after_path.?);
    try std.testing.expectEqual(@as(usize, 1), options.report_application_changes.len);
    try std.testing.expectEqual(@as(usize, 1), options.before_evidence.len);
    try std.testing.expectEqual(@as(usize, 1), options.after_evidence.len);
    try std.testing.expectEqual(@as(usize, 1), options.verified_commands.len);
}

test "default output path replaces consumption report suffix" {
    const prefix = try defaultOutputPrefix(std.testing.allocator, ".zig-cache/causal-artifacts/source-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report.json");
    defer std.testing.allocator.free(prefix);

    try std.testing.expectEqualStrings(".zig-cache/causal-artifacts/source-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary", prefix);
}

test "plan mode records planned state without applied authority" {
    const reports = try formatReports(std.testing.allocator, .{
        .options = .{
            .report_path = "source-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report.json",
            .mode = .plan,
            .reason = "plan local report application",
        },
        .source_report_json = ready_source_report_json,
    });
    defer reports.deinit(std.testing.allocator);

    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_status\": \"planned\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"applied\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"ready_for_next_branch\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"mutation_authority\": \"none\"") != null);
}

test "record-applied requires reviewed evidence before applied is true" {
    const options = Options{
        .report_path = "source-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report.json",
        .mode = .record_applied,
        .reason = "reviewed local report application",
        .report_application_changes = &.{"reviewed local evaluation report evaluation report evaluation report application for agents reviewers CI advisory readers and SolidJS webui"},
        .before_evidence = &.{"before local report application evidence"},
        .after_evidence = &.{"after local report application evidence"},
        .verified_commands = required_verification_commands,
    };

    const reports = try formatReports(std.testing.allocator, .{
        .options = options,
        .source_report_json = ready_source_report_json,
        .report_after_text = safe_report_after_text,
    });
    defer reports.deinit(std.testing.allocator);

    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_status\": \"applied\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"applied\": true") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"ready_for_next_branch\": true") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"mutation_authority\": \"record-only\"") != null);
}

test "record-applied without evidence is blocked" {
    const reports = try formatReports(std.testing.allocator, .{
        .options = .{
            .report_path = "source-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report.json",
            .mode = .record_applied,
            .reason = "missing evidence",
        },
        .source_report_json = ready_source_report_json,
    });
    defer reports.deinit(std.testing.allocator);

    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_status\": \"blocked\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"applied\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"report-application-change-present\"") != null);
}

test "unsafe after report blocks application" {
    const options = Options{
        .report_path = "source-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report.json",
        .mode = .record_applied,
        .reason = "unsafe after report",
        .report_application_changes = &.{"reviewed local evaluation report evaluation report evaluation report application"},
        .before_evidence = &.{"before evidence"},
        .after_evidence = &.{"after evidence"},
        .verified_commands = required_verification_commands,
    };

    const reports = try formatReports(std.testing.allocator, .{
        .options = options,
        .source_report_json = ready_source_report_json,
        .report_after_text = "zigeffect causal read-only consumption report evaluation-report evaluation report application app_runtime_integration_enabled=true",
    });
    defer reports.deinit(std.testing.allocator);

    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_status\": \"blocked\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"after-report-safe\"") != null);
}

test "blocked source report blocks application" {
    const reports = try formatReports(std.testing.allocator, .{
        .options = .{
            .report_path = "blocked-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report.json",
            .mode = .plan,
            .reason = "blocked source",
        },
        .source_report_json = blocked_source_report_json,
    });
    defer reports.deinit(std.testing.allocator);

    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_status\": \"blocked\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"applied\": false") != null);
}

test "source authority drift blocks application" {
    const reports = try formatReports(std.testing.allocator, .{
        .options = .{
            .report_path = "drift-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report.json",
            .mode = .plan,
            .reason = "drift source",
        },
        .source_report_json = authority_drift_source_report_json,
    });
    defer reports.deinit(std.testing.allocator);

    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_status\": \"blocked\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"source-authority-disabled\"") != null);
}

test "application boundary JSON is parseable" {
    const reports = try formatReports(std.testing.allocator, .{
        .options = .{
            .report_path = "source-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report.json",
            .mode = .plan,
            .reason = "parseable json",
        },
        .source_report_json = ready_source_report_json,
    });
    defer reports.deinit(std.testing.allocator);

    var parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, reports.json, .{});
    defer parsed.deinit();

    try std.testing.expect(parsed.value.object.contains("schema"));
}
