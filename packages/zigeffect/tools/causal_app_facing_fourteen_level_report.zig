const std = @import("std");

pub const schema = "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report.v1";
pub const schema_version: u32 = 1;
pub const source_branch = "codex/zigeffect-causal-app-facing-fourteen-level-report";
pub const recommendation = "start-app-facing-fourteen-level-application-boundary";
pub const next_branch_if_ready = "codex/zigeffect-causal-app-facing-fourteen-level-application-boundary";

const source_evaluator_schema = "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator.v1";
const generated_by = "causal-app-facing-fourteen-level-report";
const evaluator_suffix = "-ci-thirteen-level-evaluator.json";
const output_suffix = "-ci-fourteen-level-report";
const compact_output_prefix_name = "app-facing-ci-fourteen-level-report";
const max_default_output_file_name_len = 240;
const max_source_bytes = 1024 * 1024;
const mutation_authority = "none";

const required_verification_commands: []const []const u8 = &.{
    "bun run zigeffect:workbench:typecheck",
    "bun run zigeffect:workbench:test",
    "zig build causal-app-facing-thirteen-level-evaluator -- --help",
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

const ReportStatus = enum { ready, advisory, blocked };
const CheckStatus = enum { pass, fail };

const Options = struct {
    evaluator_path: []const u8,
    reason: []const u8,
    reviewed_by: []const u8 = "app-facing-fourteen-level-report-reviewer",
    policy: []const u8 = "manual-app-facing-fourteen-level-report",
    out_prefix: ?[]const u8 = null,
};

const OutputPaths = struct {
    json_path: []const u8,
    text_path: []const u8,

    fn deinit(self: OutputPaths, allocator: std.mem.Allocator) void {
        allocator.free(self.json_path);
        allocator.free(self.text_path);
    }
};

const ReportInput = struct {
    options: Options,
    source_evaluator_json: []const u8,
};

const ReportArtifacts = struct {
    json: []const u8,
    text: []const u8,

    fn deinit(self: ReportArtifacts, allocator: std.mem.Allocator) void {
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

const SourceCheck = struct {
    name: []const u8 = "",
    status: []const u8,
    detail: []const u8 = "",
};

const SourceSignal = struct {
    id: []const u8,
    status: []const u8,
    detail: []const u8 = "",
    evidence_path: []const u8 = "",
};

const SourceFinding = struct {
    id: []const u8,
    severity: []const u8,
    signal: []const u8 = "",
    detail: []const u8 = "",
    evidence_path: []const u8 = "",
};

const EvaluatorArtifact = struct {
    schema: []const u8,
    schema_version: u32,
    generated_by: []const u8 = "",
    source_thirteen_level_policy: []const u8 = "",
    source_thirteen_level_policy_schema: []const u8 = "",
    source_thirteen_level_policy_status: []const u8 = "",
    source_thirteen_level_application_boundary: []const u8 = "",
    source_thirteen_level_application_boundary_schema: []const u8 = "",
    source_thirteen_level_application_boundary_status: []const u8 = "",
    source_thirteen_level_report: []const u8 = "",
    source_thirteen_level_report_schema: []const u8 = "",
    source_thirteen_level_report_status: []const u8 = "",
    source_thirteen_level_after_digest: []const u8 = "",
    source_thirteen_level_after_present: bool = false,
    source_thirteen_level_application_changes: []const []const u8 = &.{},
    source_twelve_level_evaluator: []const u8 = "",
    source_twelve_level_evaluator_schema: []const u8 = "",
    source_twelve_level_evaluator_status: []const u8 = "",
    source_twelve_level_policy: []const u8 = "",
    source_twelve_level_policy_schema: []const u8 = "",
    source_twelve_level_policy_status: []const u8 = "",
    source_twelve_level_application_boundary: []const u8 = "",
    source_twelve_level_application_boundary_schema: []const u8 = "",
    source_twelve_level_report: []const u8 = "",
    source_twelve_level_report_schema: []const u8 = "",
    source_twelve_level_report_status: []const u8 = "",
    source_twelve_level_after_digest: []const u8 = "",
    source_twelve_level_after_present: bool = false,
    source_twelve_level_application_changes: []const []const u8 = &.{},
    source_eleven_level_policy: []const u8 = "",
    source_eleven_level_policy_schema: []const u8 = "",
    source_eleven_level_policy_status: []const u8 = "",
    source_eleven_level_application_boundary: []const u8 = "",
    source_eleven_level_application_boundary_schema: []const u8 = "",
    source_eleven_level_report: []const u8 = "",
    source_eleven_level_report_schema: []const u8 = "",
    source_eleven_level_report_status: []const u8 = "",
    source_eleven_level_after_digest: []const u8 = "",
    source_eleven_level_after_present: bool = false,
    source_eleven_level_application_changes: []const []const u8 = &.{},
    source_ten_level_policy: []const u8 = "",
    source_ten_level_policy_schema: []const u8 = "",
    source_ten_level_policy_status: []const u8 = "",
    source_ten_level_application_boundary: []const u8 = "",
    source_ten_level_application_boundary_schema: []const u8 = "",
    source_ten_level_report: []const u8 = "",
    source_ten_level_report_schema: []const u8 = "",
    source_ten_level_report_status: []const u8 = "",
    source_ten_level_after_digest: []const u8 = "",
    source_ten_level_after_present: bool = false,
    source_ten_level_application_changes: []const []const u8 = &.{},
    source_nine_level_policy: []const u8 = "",
    source_nine_level_policy_schema: []const u8 = "",
    source_nine_level_policy_status: []const u8 = "",
    source_nine_level_application_boundary: []const u8 = "",
    source_nine_level_application_boundary_schema: []const u8 = "",
    source_nine_level_report: []const u8 = "",
    source_nine_level_report_schema: []const u8 = "",
    source_nine_level_report_status: []const u8 = "",
    source_eight_level_policy: []const u8 = "",
    source_eight_level_policy_schema: []const u8 = "",
    source_eight_level_policy_status: []const u8 = "",
    source_eight_level_application_boundary: []const u8 = "",
    source_eight_level_application_boundary_schema: []const u8 = "",
    source_eight_level_report: []const u8 = "",
    source_eight_level_report_status: []const u8 = "",
    source_eight_level_application_status: []const u8 = "",
    source_eight_level_after_digest: []const u8 = "",
    source_eight_level_after_present: bool = false,
    source_eight_level_application_changes: []const []const u8 = &.{},
    source_inherited_policy: []const u8 = "",
    source_inherited_policy_schema: []const u8 = "",
    source_inherited_policy_status: []const u8 = "",
    source_inherited_application_boundary: []const u8 = "",
    source_inherited_application_boundary_schema: []const u8 = "",
    source_inherited_report: []const u8 = "",
    source_inherited_report_status: []const u8 = "",
    source_inherited_application_status: []const u8 = "",
    source_inherited_application_changes: []const []const u8 = &.{},
    source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy: []const u8 = "",
    source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy_schema: []const u8 = "",
    source_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy_status: []const u8 = "",
    source_policy_decision: []const u8 = "",
    source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_boundary: []const u8 = "",
    source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_boundary_schema: []const u8 = "",
    source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report: []const u8 = "",
    source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_status: []const u8 = "",
    source_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_status: []const u8 = "",
    source_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_after_digest: []const u8 = "",
    source_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_after_present: bool = false,
    source_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_changes: []const []const u8 = &.{},
    source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy: []const u8 = "",
    source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy_schema: []const u8 = "",
    source_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy_status: []const u8 = "",
    source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_boundary: []const u8 = "",
    source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_boundary_schema: []const u8 = "",
    source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report: []const u8 = "",
    source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_status: []const u8 = "",
    source_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_status: []const u8 = "",
    source_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_changes: []const []const u8 = &.{},
    source_consumption_report_application_boundary: []const u8 = "",
    source_report_application_status: []const u8 = "",
    source_consumption_report: []const u8 = "",
    source_consumption_report_status: []const u8 = "",
    source_ready_for_next_branch: bool = false,
    source_mutation_authority: []const u8 = "",
    source_evaluator_status: []const u8 = "",
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
    evaluation_status: []const u8,
    ready_for_next_branch: bool,
    advisory_findings_count: usize = 0,
    blocked_findings_count: usize = 0,
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
    request_files: []const SourceFile = &.{},
    evidence_files: []const SourceFile = &.{},
    checks: []const SourceCheck = &.{},
    signal_evaluations: []const SourceSignal = &.{},
    findings: []const SourceFinding = &.{},
    source_policy_rule_ids: []const []const u8 = &.{},
    source_consumption_scope_ids: []const []const u8 = &.{},
    denied_claims: []const []const u8 = &.{},
    next_queries: []const []const u8 = &.{},
    agent_guidance: []const []const u8 = &.{},
};

const ReportCheck = struct {
    name: []const u8,
    status: CheckStatus,
    detail: []const u8,
};

const PublicationChannel = struct {
    id: []const u8,
    allowed: bool,
    executed_by_tool: bool,
    detail: []const u8,
};

const ReportResult = struct {
    status: ReportStatus,
    ready_for_next_branch: bool,
    checks: []const ReportCheck,

    fn deinit(self: ReportResult, allocator: std.mem.Allocator) void {
        allocator.free(self.checks);
    }
};

const report_sections: []const []const u8 = &.{
    "status",
    "source",
    "request-summary",
    "support-evidence",
    "signals",
    "findings",
    "checks",
    "policy-rules",
    "denied-claims",
    "next-queries",
    "publication-boundary",
};

const publication_channels: []const PublicationChannel = &.{
    .{ .id = "local-json-artifact", .allowed = true, .executed_by_tool = true, .detail = "JSON report is written to the local artifact path." },
    .{ .id = "local-text-artifact", .allowed = true, .executed_by_tool = true, .detail = "Text report is written to the local artifact path." },
    .{ .id = "solid-webui-readonly-view", .allowed = true, .executed_by_tool = false, .detail = "SolidJS webui-dev/zig-webui can read the artifact later without mutation authority." },
    .{ .id = "ci-upload-artifact", .allowed = false, .executed_by_tool = false, .detail = "CI artifact upload remains disabled and requires a later reviewed boundary." },
    .{ .id = "github-step-summary", .allowed = false, .executed_by_tool = false, .detail = "GitHub step summary writing remains disabled." },
    .{ .id = "pull-request-comment", .allowed = false, .executed_by_tool = false, .detail = "Pull request comments are not posted by this tool." },
    .{ .id = "required-status-check", .allowed = false, .executed_by_tool = false, .detail = "Required status checks remain outside this app-facing consumption report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report." },
    .{ .id = "app-runtime-integration", .allowed = false, .executed_by_tool = false, .detail = "App runtime integration remains disabled." },
};

pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len == 2 and (std.mem.eql(u8, args[1], "--help") or std.mem.eql(u8, args[1], "-h"))) {
        std.debug.print("{s}", .{usage()});
        return;
    }
    const options = parseOptions(args) catch |err| failUsage(err);
    run(init, options) catch |err| switch (err) {
        error.MissingEvaluatorInput => failUsage(err),
        else => return err,
    };
}

fn parseOptions(args: []const []const u8) !Options {
    if (args.len < 2) return error.MissingEvaluatorPath;
    if (!std.mem.eql(u8, args[1], "--from-evaluator")) return error.UnknownFlag;
    if (args.len < 3) return error.MissingEvaluatorPath;
    const evaluator_path = args[2];
    if (!std.mem.endsWith(u8, evaluator_path, ".json")) return error.InvalidEvaluatorPath;
    if (args.len < 4) return error.MissingCommand;
    if (!std.mem.eql(u8, args[3], "summarize")) return error.UnknownCommand;

    var reviewed_by: []const u8 = "app-facing-fourteen-level-report-reviewer";
    var policy: []const u8 = "manual-app-facing-fourteen-level-report";
    var reason: ?[]const u8 = null;
    var out_prefix: ?[]const u8 = null;

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
        .evaluator_path = evaluator_path,
        .reason = final_reason,
        .reviewed_by = reviewed_by,
        .policy = policy,
        .out_prefix = out_prefix,
    };
}

fn outputPathsForOptions(allocator: std.mem.Allocator, options: Options) !OutputPaths {
    const prefix = if (options.out_prefix) |out_prefix|
        try allocator.dupe(u8, out_prefix)
    else
        try defaultOutputPrefix(allocator, options.evaluator_path);
    defer allocator.free(prefix);

    return .{
        .json_path = try std.fmt.allocPrint(allocator, "{s}.json", .{prefix}),
        .text_path = try std.fmt.allocPrint(allocator, "{s}.txt", .{prefix}),
    };
}

fn defaultOutputPrefix(allocator: std.mem.Allocator, evaluator_path: []const u8) ![]const u8 {
    if (!std.mem.endsWith(u8, evaluator_path, ".json")) return error.InvalidEvaluatorPath;

    const base = if (std.mem.endsWith(u8, evaluator_path, evaluator_suffix))
        evaluator_path[0 .. evaluator_path.len - evaluator_suffix.len]
    else
        evaluator_path[0 .. evaluator_path.len - ".json".len];
    const candidate = try std.fmt.allocPrint(allocator, "{s}{s}", .{ base, output_suffix });
    errdefer allocator.free(candidate);

    if (fileName(candidate).len + ".json".len <= max_default_output_file_name_len) {
        return candidate;
    }

    const directory = directoryPrefix(candidate);
    const digest = shortPathDigest(evaluator_path);
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

fn formatReports(allocator: std.mem.Allocator, input: ReportInput) !ReportArtifacts {
    var parsed = try std.json.parseFromSlice(EvaluatorArtifact, allocator, input.source_evaluator_json, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();

    const paths = try outputPathsForOptions(allocator, input.options);
    defer paths.deinit(allocator);

    const result = try evaluateReport(allocator, parsed.value);
    defer result.deinit(allocator);

    const json = try formatReportJson(allocator, input.options, parsed.value, result, paths);
    errdefer allocator.free(json);
    const text = try formatReportText(allocator, input.options, parsed.value, result, paths);
    errdefer allocator.free(text);

    return .{ .json = json, .text = text };
}

fn evaluateReport(allocator: std.mem.Allocator, source: EvaluatorArtifact) !ReportResult {
    var checks = std.ArrayList(ReportCheck).empty;
    errdefer checks.deinit(allocator);

    try appendCheck(allocator, &checks, "source-thirteen-level-evaluator-schema", if (sourceSchemaValid(source)) .pass else .fail, "source thirteen-level evaluator schema is supported");
    try appendCheck(allocator, &checks, "source-thirteen-level-evaluator-reportable", if (sourceReportable(source)) .pass else .fail, "source evaluator status is ready or advisory-findings");
    try appendCheck(allocator, &checks, "source-thirteen-level-ready-for-next-branch", if (source.ready_for_next_branch) .pass else .fail, "source evaluator is ready for fourteen-level report work");
    try appendCheck(allocator, &checks, "source-thirteen-level-no-blocked-findings", if (sourceHasNoBlockedFindings(source)) .pass else .fail, "source evaluator has no blocked findings");
    try appendCheck(allocator, &checks, "source-thirteen-level-policy-ready", if (sourcePolicyReady(source)) .pass else .fail, "source thirteen-level policy application report twelve-level evaluator and lower lineage remain ready");
    try appendCheck(allocator, &checks, "source-thirteen-level-application-evidence", if (sourceReportApplicationEvidencePresent(source)) .pass else .fail, "source thirteen-level twelve-level eleven-level ten-level and inherited report application evidence next queries and local channels are present");
    try appendCheck(allocator, &checks, "source-file-analysis-present", if (sourceFileAnalysisPresent(source)) .pass else .fail, "source request analysis is present and support evidence may be advisory");
    try appendCheck(allocator, &checks, "source-report-sections-present", if (sourceSectionsPresent(source)) .pass else .fail, "source evaluator contains checks signals denied claims next queries and guidance");
    try appendCheck(allocator, &checks, "source-disabled-authority", if (sourceAuthorityDisabled(source)) .pass else .fail, "source keeps CI GitHub app runtime storage deployment and adapter authority disabled");
    try appendCheck(allocator, &checks, "source-solid-webui", if (sourceSolidWebuiValid(source)) .pass else .fail, "source remains SolidJS inside webui-dev/zig-webui with read-only consumption enabled");
    try appendCheck(allocator, &checks, "report-publication-local-only", if (publicationLocalOnly()) .pass else .fail, "report publication channels remain local-only and non-mutating");

    const check_slice = try checks.toOwnedSlice(allocator);
    errdefer allocator.free(check_slice);

    const status: ReportStatus = if (!allChecksPassed(check_slice))
        .blocked
    else if (std.mem.eql(u8, source.evaluation_status, "advisory-findings") or source.advisory_findings_count > 0 or countFindings(source.findings, "advisory") > 0)
        .advisory
    else
        .ready;

    return .{
        .status = status,
        .ready_for_next_branch = status != .blocked,
        .checks = check_slice,
    };
}

fn appendCheck(
    allocator: std.mem.Allocator,
    checks: *std.ArrayList(ReportCheck),
    name: []const u8,
    status: CheckStatus,
    detail: []const u8,
) !void {
    try checks.append(allocator, .{ .name = name, .status = status, .detail = detail });
}

fn sourceSchemaValid(source: EvaluatorArtifact) bool {
    return std.mem.eql(u8, source.schema, source_evaluator_schema) and source.schema_version == 1;
}

fn sourceReportable(source: EvaluatorArtifact) bool {
    return std.mem.eql(u8, source.evaluation_status, "ready") or std.mem.eql(u8, source.evaluation_status, "advisory-findings");
}

fn sourceHasNoBlockedFindings(source: EvaluatorArtifact) bool {
    if (source.blocked_findings_count != 0) return false;
    return countFindings(source.findings, "blocked") == 0;
}

fn sourceThirteenLevelPolicy(source: EvaluatorArtifact) []const u8 {
    return source.source_thirteen_level_policy;
}

fn sourceThirteenLevelPolicySchema(source: EvaluatorArtifact) []const u8 {
    return source.source_thirteen_level_policy_schema;
}

fn sourceThirteenLevelPolicyStatus(source: EvaluatorArtifact) []const u8 {
    return source.source_thirteen_level_policy_status;
}

fn sourceThirteenLevelApplicationBoundary(source: EvaluatorArtifact) []const u8 {
    return source.source_thirteen_level_application_boundary;
}

fn sourceThirteenLevelApplicationBoundarySchema(source: EvaluatorArtifact) []const u8 {
    return source.source_thirteen_level_application_boundary_schema;
}

fn sourceThirteenLevelApplicationBoundaryStatus(source: EvaluatorArtifact) []const u8 {
    return source.source_thirteen_level_application_boundary_status;
}

fn sourceThirteenLevelReport(source: EvaluatorArtifact) []const u8 {
    return source.source_thirteen_level_report;
}

fn sourceThirteenLevelReportSchema(source: EvaluatorArtifact) []const u8 {
    return source.source_thirteen_level_report_schema;
}

fn sourceThirteenLevelReportStatus(source: EvaluatorArtifact) []const u8 {
    return source.source_thirteen_level_report_status;
}

fn sourceTwelveLevelEvaluator(source: EvaluatorArtifact) []const u8 {
    return source.source_twelve_level_evaluator;
}

fn sourceTwelveLevelEvaluatorSchema(source: EvaluatorArtifact) []const u8 {
    return source.source_twelve_level_evaluator_schema;
}

fn sourceTwelveLevelEvaluatorStatus(source: EvaluatorArtifact) []const u8 {
    return source.source_twelve_level_evaluator_status;
}

fn sourceTwelveLevelPolicy(source: EvaluatorArtifact) []const u8 {
    return source.source_twelve_level_policy;
}

fn sourceTwelveLevelPolicySchema(source: EvaluatorArtifact) []const u8 {
    return source.source_twelve_level_policy_schema;
}

fn sourceTwelveLevelPolicyStatus(source: EvaluatorArtifact) []const u8 {
    return source.source_twelve_level_policy_status;
}

fn sourceTwelveLevelApplicationBoundary(source: EvaluatorArtifact) []const u8 {
    return source.source_twelve_level_application_boundary;
}

fn sourceTwelveLevelApplicationBoundarySchema(source: EvaluatorArtifact) []const u8 {
    return source.source_twelve_level_application_boundary_schema;
}

fn sourceTwelveLevelReport(source: EvaluatorArtifact) []const u8 {
    return source.source_twelve_level_report;
}

fn sourceTwelveLevelReportSchema(source: EvaluatorArtifact) []const u8 {
    return source.source_twelve_level_report_schema;
}

fn sourceTwelveLevelReportStatus(source: EvaluatorArtifact) []const u8 {
    return source.source_twelve_level_report_status;
}

fn sourceElevenLevelPolicy(source: EvaluatorArtifact) []const u8 {
    return source.source_eleven_level_policy;
}

fn sourceElevenLevelPolicySchema(source: EvaluatorArtifact) []const u8 {
    return source.source_eleven_level_policy_schema;
}

fn sourceElevenLevelPolicyStatus(source: EvaluatorArtifact) []const u8 {
    return source.source_eleven_level_policy_status;
}

fn sourceElevenLevelApplicationBoundary(source: EvaluatorArtifact) []const u8 {
    return source.source_eleven_level_application_boundary;
}

fn sourceElevenLevelApplicationBoundarySchema(source: EvaluatorArtifact) []const u8 {
    return source.source_eleven_level_application_boundary_schema;
}

fn sourceElevenLevelReport(source: EvaluatorArtifact) []const u8 {
    return source.source_eleven_level_report;
}

fn sourceElevenLevelReportSchema(source: EvaluatorArtifact) []const u8 {
    return source.source_eleven_level_report_schema;
}

fn sourceElevenLevelReportStatus(source: EvaluatorArtifact) []const u8 {
    return source.source_eleven_level_report_status;
}

fn sourceTenLevelPolicy(source: EvaluatorArtifact) []const u8 {
    return source.source_ten_level_policy;
}

fn sourceTenLevelPolicySchema(source: EvaluatorArtifact) []const u8 {
    return source.source_ten_level_policy_schema;
}

fn sourceTenLevelPolicyStatus(source: EvaluatorArtifact) []const u8 {
    return source.source_ten_level_policy_status;
}

fn sourceTenLevelApplicationBoundary(source: EvaluatorArtifact) []const u8 {
    return source.source_ten_level_application_boundary;
}

fn sourceTenLevelApplicationBoundarySchema(source: EvaluatorArtifact) []const u8 {
    return source.source_ten_level_application_boundary_schema;
}

fn sourceTenLevelReport(source: EvaluatorArtifact) []const u8 {
    return source.source_ten_level_report;
}

fn sourceTenLevelReportSchema(source: EvaluatorArtifact) []const u8 {
    return source.source_ten_level_report_schema;
}

fn sourceTenLevelReportStatus(source: EvaluatorArtifact) []const u8 {
    return source.source_ten_level_report_status;
}

fn sourceNineLevelPolicy(source: EvaluatorArtifact) []const u8 {
    if (source.source_nine_level_policy.len > 0) return source.source_nine_level_policy;
    return source.source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy;
}

fn sourceNineLevelPolicySchema(source: EvaluatorArtifact) []const u8 {
    if (source.source_nine_level_policy_schema.len > 0) return source.source_nine_level_policy_schema;
    return source.source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy_schema;
}

fn sourceNineLevelPolicyStatus(source: EvaluatorArtifact) []const u8 {
    if (source.source_nine_level_policy_status.len > 0) return source.source_nine_level_policy_status;
    return source.source_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy_status;
}

fn sourceNineLevelApplicationBoundary(source: EvaluatorArtifact) []const u8 {
    if (source.source_nine_level_application_boundary.len > 0) return source.source_nine_level_application_boundary;
    return source.source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_boundary;
}

fn sourceNineLevelApplicationBoundarySchema(source: EvaluatorArtifact) []const u8 {
    if (source.source_nine_level_application_boundary_schema.len > 0) return source.source_nine_level_application_boundary_schema;
    return source.source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_boundary_schema;
}

fn sourceNineLevelReport(source: EvaluatorArtifact) []const u8 {
    if (source.source_nine_level_report.len > 0) return source.source_nine_level_report;
    return source.source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report;
}

fn sourceNineLevelReportSchema(source: EvaluatorArtifact) []const u8 {
    if (source.source_nine_level_report_schema.len > 0) return source.source_nine_level_report_schema;
    return schema;
}

fn sourceNineLevelReportStatus(source: EvaluatorArtifact) []const u8 {
    if (source.source_nine_level_report_status.len > 0) return source.source_nine_level_report_status;
    return source.source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_status;
}

fn sourceEightLevelPolicy(source: EvaluatorArtifact) []const u8 {
    if (source.source_eight_level_policy.len > 0) return source.source_eight_level_policy;
    return source.source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy;
}

fn sourceEightLevelPolicySchema(source: EvaluatorArtifact) []const u8 {
    if (source.source_eight_level_policy_schema.len > 0) return source.source_eight_level_policy_schema;
    return source.source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy_schema;
}

fn sourceEightLevelPolicyStatus(source: EvaluatorArtifact) []const u8 {
    if (source.source_eight_level_policy_status.len > 0) return source.source_eight_level_policy_status;
    return source.source_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy_status;
}

fn sourceEightLevelApplicationBoundary(source: EvaluatorArtifact) []const u8 {
    if (source.source_eight_level_application_boundary.len > 0) return source.source_eight_level_application_boundary;
    return source.source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_boundary;
}

fn sourceEightLevelApplicationBoundarySchema(source: EvaluatorArtifact) []const u8 {
    if (source.source_eight_level_application_boundary_schema.len > 0) return source.source_eight_level_application_boundary_schema;
    return source.source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_boundary_schema;
}

fn sourceEightLevelReport(source: EvaluatorArtifact) []const u8 {
    if (source.source_eight_level_report.len > 0) return source.source_eight_level_report;
    return source.source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report;
}

fn sourceEightLevelReportStatus(source: EvaluatorArtifact) []const u8 {
    if (source.source_eight_level_report_status.len > 0) return source.source_eight_level_report_status;
    return source.source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_status;
}

fn sourceEightLevelApplicationStatus(source: EvaluatorArtifact) []const u8 {
    if (source.source_eight_level_application_status.len > 0) return source.source_eight_level_application_status;
    return source.source_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_status;
}

fn sourceEightLevelAfterDigest(source: EvaluatorArtifact) []const u8 {
    if (source.source_eight_level_after_digest.len > 0) return source.source_eight_level_after_digest;
    return source.source_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_after_digest;
}

fn sourceEightLevelAfterPresent(source: EvaluatorArtifact) bool {
    return source.source_eight_level_after_present or
        source.source_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_after_present;
}

fn sourceEightLevelApplicationChanges(source: EvaluatorArtifact) []const []const u8 {
    if (source.source_eight_level_application_changes.len > 0) return source.source_eight_level_application_changes;
    return source.source_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_changes;
}

fn sourceInheritedPolicy(source: EvaluatorArtifact) []const u8 {
    if (source.source_inherited_policy.len > 0) return source.source_inherited_policy;
    return source.source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy;
}

fn sourceInheritedPolicySchema(source: EvaluatorArtifact) []const u8 {
    if (source.source_inherited_policy_schema.len > 0) return source.source_inherited_policy_schema;
    return source.source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy_schema;
}

fn sourceInheritedPolicyStatus(source: EvaluatorArtifact) []const u8 {
    if (source.source_inherited_policy_status.len > 0) return source.source_inherited_policy_status;
    return source.source_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy_status;
}

fn sourceInheritedApplicationBoundary(source: EvaluatorArtifact) []const u8 {
    if (source.source_inherited_application_boundary.len > 0) return source.source_inherited_application_boundary;
    return source.source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_boundary;
}

fn sourceInheritedApplicationBoundarySchema(source: EvaluatorArtifact) []const u8 {
    if (source.source_inherited_application_boundary_schema.len > 0) return source.source_inherited_application_boundary_schema;
    return source.source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_boundary_schema;
}

fn sourceInheritedReport(source: EvaluatorArtifact) []const u8 {
    if (source.source_inherited_report.len > 0) return source.source_inherited_report;
    return source.source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report;
}

fn sourceInheritedReportStatus(source: EvaluatorArtifact) []const u8 {
    if (source.source_inherited_report_status.len > 0) return source.source_inherited_report_status;
    return source.source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_status;
}

fn sourceInheritedApplicationStatus(source: EvaluatorArtifact) []const u8 {
    if (source.source_inherited_application_status.len > 0) return source.source_inherited_application_status;
    if (source.source_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_status.len > 0) {
        return source.source_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_status;
    }
    return source.source_report_application_status;
}

fn sourceInheritedApplicationChanges(source: EvaluatorArtifact) []const []const u8 {
    if (source.source_inherited_application_changes.len > 0) return source.source_inherited_application_changes;
    if (source.source_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_changes.len > 0) {
        return source.source_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_changes;
    }
    return source.source_report_application_changes;
}

fn sourcePolicyReady(source: EvaluatorArtifact) bool {
    return sourceThirteenLevelPolicy(source).len > 0 and
        sourceThirteenLevelPolicySchema(source).len > 0 and
        std.mem.eql(u8, sourceThirteenLevelPolicyStatus(source), "ready") and
        sourceThirteenLevelApplicationBoundary(source).len > 0 and
        sourceThirteenLevelApplicationBoundarySchema(source).len > 0 and
        std.mem.eql(u8, sourceThirteenLevelApplicationBoundaryStatus(source), "applied") and
        sourceThirteenLevelReport(source).len > 0 and
        sourceThirteenLevelReportSchema(source).len > 0 and
        std.mem.eql(u8, sourceThirteenLevelReportStatus(source), "ready") and
        source.source_thirteen_level_after_digest.len > 0 and
        source.source_thirteen_level_after_present and
        sourceTwelveLevelEvaluator(source).len > 0 and
        sourceTwelveLevelEvaluatorSchema(source).len > 0 and
        std.mem.eql(u8, sourceTwelveLevelEvaluatorStatus(source), "ready") and
        sourceTwelveLevelPolicy(source).len > 0 and
        sourceTwelveLevelPolicySchema(source).len > 0 and
        std.mem.eql(u8, sourceTwelveLevelPolicyStatus(source), "ready") and
        sourceTwelveLevelApplicationBoundary(source).len > 0 and
        sourceTwelveLevelApplicationBoundarySchema(source).len > 0 and
        sourceTwelveLevelReport(source).len > 0 and
        sourceTwelveLevelReportSchema(source).len > 0 and
        std.mem.eql(u8, sourceTwelveLevelReportStatus(source), "ready") and
        sourceElevenLevelPolicy(source).len > 0 and
        sourceElevenLevelPolicySchema(source).len > 0 and
        std.mem.eql(u8, sourceElevenLevelPolicyStatus(source), "ready") and
        sourceElevenLevelApplicationBoundary(source).len > 0 and
        sourceElevenLevelApplicationBoundarySchema(source).len > 0 and
        sourceElevenLevelReport(source).len > 0 and
        sourceElevenLevelReportSchema(source).len > 0 and
        std.mem.eql(u8, sourceElevenLevelReportStatus(source), "ready") and
        sourceTenLevelPolicy(source).len > 0 and
        sourceTenLevelPolicySchema(source).len > 0 and
        std.mem.eql(u8, sourceTenLevelPolicyStatus(source), "ready") and
        std.mem.eql(u8, source.source_policy_decision, "approve") and
        sourceTenLevelApplicationBoundary(source).len > 0 and
        sourceTenLevelApplicationBoundarySchema(source).len > 0 and
        sourceTenLevelReport(source).len > 0 and
        sourceTenLevelReportSchema(source).len > 0 and
        std.mem.eql(u8, sourceTenLevelReportStatus(source), "ready") and
        sourceNineLevelPolicy(source).len > 0 and
        sourceNineLevelPolicySchema(source).len > 0 and
        std.mem.eql(u8, sourceNineLevelPolicyStatus(source), "ready") and
        sourceNineLevelApplicationBoundary(source).len > 0 and
        sourceNineLevelApplicationBoundarySchema(source).len > 0 and
        sourceNineLevelReport(source).len > 0 and
        sourceNineLevelReportSchema(source).len > 0 and
        std.mem.eql(u8, sourceNineLevelReportStatus(source), "ready") and
        sourceEightLevelPolicy(source).len > 0 and
        sourceEightLevelPolicySchema(source).len > 0 and
        std.mem.eql(u8, sourceEightLevelPolicyStatus(source), "ready") and
        sourceEightLevelApplicationBoundary(source).len > 0 and
        sourceEightLevelApplicationBoundarySchema(source).len > 0 and
        std.mem.eql(u8, sourceEightLevelApplicationStatus(source), "applied") and
        sourceInheritedPolicy(source).len > 0 and
        sourceInheritedPolicySchema(source).len > 0 and
        std.mem.eql(u8, sourceInheritedPolicyStatus(source), "ready") and
        sourceInheritedApplicationBoundary(source).len > 0 and
        sourceInheritedApplicationBoundarySchema(source).len > 0 and
        sourceInheritedReport(source).len > 0 and
        sourceInheritedReportStatus(source).len > 0 and
        std.mem.eql(u8, sourceInheritedApplicationStatus(source), "applied") and
        source.source_consumption_report_application_boundary.len > 0 and
        std.mem.eql(u8, source.source_report_application_status, "applied") and
        source.source_consumption_report.len > 0 and
        source.source_consumption_report_status.len > 0 and
        source.source_ready_for_next_branch and
        std.mem.eql(u8, source.source_mutation_authority, "none") and
        source.source_evaluator_status.len > 0 and
        source.source_consumption_policy.len > 0 and
        source.source_consumption_boundary.len > 0 and
        source.source_consumption_readiness.len > 0 and
        source.source_publication_policy.len > 0 and
        source.source_after_report_digest.len > 0 and
        source.source_consumer_after_digest.len > 0 and
        source.source_report_after_digest.len > 0 and
        source.source_report_after_present;
}

fn sourceReportApplicationEvidencePresent(source: EvaluatorArtifact) bool {
    return source.source_thirteen_level_application_changes.len > 0 and
        source.source_twelve_level_application_changes.len > 0 and
        source.source_eleven_level_application_changes.len > 0 and
        sourceEightLevelApplicationChanges(source).len > 0 and
        sourceInheritedApplicationChanges(source).len > 0 and
        source.source_before_evidence.len > 0 and
        source.source_after_evidence.len > 0 and
        source.source_report_application_changes.len > 0 and
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
        source.source_support_evidence_summary.len > 0 and
        source.source_signal_summary.len > 0;
}

fn sourceFileAnalysisPresent(source: EvaluatorArtifact) bool {
    return source.request_files.len > 0;
}

fn sourceSectionsPresent(source: EvaluatorArtifact) bool {
    return source.checks.len > 0 and
        source.signal_evaluations.len > 0 and
        source.source_application_checks.len > 0 and
        source.source_report_checks.len > 0 and
        source.source_request_summary.len > 0 and
        source.source_signal_summary.len > 0 and
        source.source_policy_rule_ids.len > 0 and
        source.source_consumption_scope_ids.len > 0 and
        source.denied_claims.len > 0 and
        source.next_queries.len > 0 and
        source.agent_guidance.len > 0;
}

fn sourceAuthorityDisabled(source: EvaluatorArtifact) bool {
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
        !source.nendb_adapter_execution_enabled and
        !source.public_artifact_upload_enabled and
        !source.hosted_live_dashboard_enabled and
        !source.production_health_claim_enabled and
        !source.auto_apply_enabled and
        std.mem.eql(u8, source.mutation_authority, "none");
}

fn sourceSolidWebuiValid(source: EvaluatorArtifact) bool {
    return source.advisory_report and
        source.read_only_preview and
        source.read_only_consumption_enabled and
        source.solid_webui_enabled and
        std.mem.eql(u8, source.solid_webui_renderer, solid_webui_renderer) and
        std.mem.eql(u8, source.webui_bridge, webui_bridge);
}

fn publicationLocalOnly() bool {
    return !ci_report_publication_enabled and
        !github_step_summary_write_enabled and
        !pull_request_comment_enabled and
        !ci_upload_execution_enabled and
        !ci_workflow_mutation_enabled and
        !github_api_mutation_enabled and
        !ci_required_status_check_enabled and
        !public_artifact_upload_enabled and
        !hosted_live_dashboard_enabled and
        !app_runtime_integration_enabled;
}

fn allChecksPassed(checks: []const ReportCheck) bool {
    for (checks) |check| {
        if (check.status != .pass) return false;
    }
    return true;
}

fn countFindings(findings: []const SourceFinding, severity: []const u8) usize {
    var count: usize = 0;
    for (findings) |finding| {
        if (std.mem.eql(u8, finding.severity, severity)) count += 1;
    }
    return count;
}

fn formatReportJson(
    allocator: std.mem.Allocator,
    options: Options,
    source: EvaluatorArtifact,
    result: ReportResult,
    paths: OutputPaths,
) ![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "{\n");
    try appendJsonField(allocator, &output, "schema", schema, true);
    try output.print(allocator, "  \"schema_version\": {d},\n", .{schema_version});
    try appendJsonField(allocator, &output, "generated_by", generated_by, true);
    try appendJsonField(allocator, &output, "source_branch", source_branch, true);
    try appendJsonField(allocator, &output, "recommendation", recommendation, true);
    try appendJsonField(allocator, &output, "next_branch_if_ready", next_branch_if_ready, true);
    try appendJsonField(allocator, &output, "source_evaluator", options.evaluator_path, true);
    try appendJsonField(allocator, &output, "source_evaluator_schema", source.schema, true);
    try appendJsonField(allocator, &output, "source_evaluator_status", source.evaluation_status, true);
    try output.print(allocator, "  \"source_ready_for_next_branch\": {},\n", .{source.ready_for_next_branch});
    try appendJsonField(allocator, &output, "source_thirteen_level_evaluator", options.evaluator_path, true);
    try appendJsonField(allocator, &output, "source_thirteen_level_evaluator_schema", source.schema, true);
    try appendJsonField(allocator, &output, "source_thirteen_level_evaluator_status", source.evaluation_status, true);
    try appendJsonField(allocator, &output, "source_thirteen_level_policy", sourceThirteenLevelPolicy(source), true);
    try appendJsonField(allocator, &output, "source_thirteen_level_policy_schema", sourceThirteenLevelPolicySchema(source), true);
    try appendJsonField(allocator, &output, "source_thirteen_level_policy_status", sourceThirteenLevelPolicyStatus(source), true);
    try appendJsonField(allocator, &output, "source_thirteen_level_application_boundary", sourceThirteenLevelApplicationBoundary(source), true);
    try appendJsonField(allocator, &output, "source_thirteen_level_application_boundary_schema", sourceThirteenLevelApplicationBoundarySchema(source), true);
    try appendJsonField(allocator, &output, "source_thirteen_level_application_boundary_status", sourceThirteenLevelApplicationBoundaryStatus(source), true);
    try appendJsonField(allocator, &output, "source_thirteen_level_report", sourceThirteenLevelReport(source), true);
    try appendJsonField(allocator, &output, "source_thirteen_level_report_schema", sourceThirteenLevelReportSchema(source), true);
    try appendJsonField(allocator, &output, "source_thirteen_level_report_status", sourceThirteenLevelReportStatus(source), true);
    try appendJsonField(allocator, &output, "source_thirteen_level_after_digest", source.source_thirteen_level_after_digest, true);
    try output.print(allocator, "  \"source_thirteen_level_after_present\": {},\n", .{source.source_thirteen_level_after_present});
    try appendJsonField(allocator, &output, "source_twelve_level_evaluator", sourceTwelveLevelEvaluator(source), true);
    try appendJsonField(allocator, &output, "source_twelve_level_evaluator_schema", sourceTwelveLevelEvaluatorSchema(source), true);
    try appendJsonField(allocator, &output, "source_twelve_level_evaluator_status", sourceTwelveLevelEvaluatorStatus(source), true);
    try appendJsonField(allocator, &output, "source_twelve_level_policy", sourceTwelveLevelPolicy(source), true);
    try appendJsonField(allocator, &output, "source_twelve_level_policy_schema", sourceTwelveLevelPolicySchema(source), true);
    try appendJsonField(allocator, &output, "source_twelve_level_policy_status", sourceTwelveLevelPolicyStatus(source), true);
    try appendJsonField(allocator, &output, "source_twelve_level_application_boundary", sourceTwelveLevelApplicationBoundary(source), true);
    try appendJsonField(allocator, &output, "source_twelve_level_application_boundary_schema", sourceTwelveLevelApplicationBoundarySchema(source), true);
    try appendJsonField(allocator, &output, "source_twelve_level_report", sourceTwelveLevelReport(source), true);
    try appendJsonField(allocator, &output, "source_twelve_level_report_schema", sourceTwelveLevelReportSchema(source), true);
    try appendJsonField(allocator, &output, "source_twelve_level_report_status", sourceTwelveLevelReportStatus(source), true);
    try appendJsonField(allocator, &output, "source_twelve_level_after_digest", source.source_twelve_level_after_digest, true);
    try output.print(allocator, "  \"source_twelve_level_after_present\": {},\n", .{source.source_twelve_level_after_present});
    try appendJsonField(allocator, &output, "source_eleven_level_policy", sourceElevenLevelPolicy(source), true);
    try appendJsonField(allocator, &output, "source_eleven_level_policy_schema", sourceElevenLevelPolicySchema(source), true);
    try appendJsonField(allocator, &output, "source_eleven_level_policy_status", sourceElevenLevelPolicyStatus(source), true);
    try appendJsonField(allocator, &output, "source_eleven_level_application_boundary", sourceElevenLevelApplicationBoundary(source), true);
    try appendJsonField(allocator, &output, "source_eleven_level_application_boundary_schema", sourceElevenLevelApplicationBoundarySchema(source), true);
    try appendJsonField(allocator, &output, "source_eleven_level_report", sourceElevenLevelReport(source), true);
    try appendJsonField(allocator, &output, "source_eleven_level_report_schema", sourceElevenLevelReportSchema(source), true);
    try appendJsonField(allocator, &output, "source_eleven_level_report_status", sourceElevenLevelReportStatus(source), true);
    try appendJsonField(allocator, &output, "source_eleven_level_after_digest", source.source_eleven_level_after_digest, true);
    try output.print(allocator, "  \"source_eleven_level_after_present\": {},\n", .{source.source_eleven_level_after_present});
    try appendJsonField(allocator, &output, "source_ten_level_policy", sourceTenLevelPolicy(source), true);
    try appendJsonField(allocator, &output, "source_ten_level_policy_schema", sourceTenLevelPolicySchema(source), true);
    try appendJsonField(allocator, &output, "source_ten_level_policy_status", sourceTenLevelPolicyStatus(source), true);
    try appendJsonField(allocator, &output, "source_ten_level_application_boundary", sourceTenLevelApplicationBoundary(source), true);
    try appendJsonField(allocator, &output, "source_ten_level_application_boundary_schema", sourceTenLevelApplicationBoundarySchema(source), true);
    try appendJsonField(allocator, &output, "source_ten_level_report", sourceTenLevelReport(source), true);
    try appendJsonField(allocator, &output, "source_ten_level_report_schema", sourceTenLevelReportSchema(source), true);
    try appendJsonField(allocator, &output, "source_ten_level_report_status", sourceTenLevelReportStatus(source), true);
    try appendJsonField(allocator, &output, "source_nine_level_policy", sourceNineLevelPolicy(source), true);
    try appendJsonField(allocator, &output, "source_nine_level_policy_schema", sourceNineLevelPolicySchema(source), true);
    try appendJsonField(allocator, &output, "source_nine_level_policy_status", sourceNineLevelPolicyStatus(source), true);
    try appendJsonField(allocator, &output, "source_nine_level_application_boundary", sourceNineLevelApplicationBoundary(source), true);
    try appendJsonField(allocator, &output, "source_nine_level_application_boundary_schema", sourceNineLevelApplicationBoundarySchema(source), true);
    try appendJsonField(allocator, &output, "source_nine_level_report", sourceNineLevelReport(source), true);
    try appendJsonField(allocator, &output, "source_nine_level_report_schema", sourceNineLevelReportSchema(source), true);
    try appendJsonField(allocator, &output, "source_nine_level_report_status", sourceNineLevelReportStatus(source), true);
    try appendJsonField(allocator, &output, "source_eight_level_policy", sourceEightLevelPolicy(source), true);
    try appendJsonField(allocator, &output, "source_eight_level_policy_schema", sourceEightLevelPolicySchema(source), true);
    try appendJsonField(allocator, &output, "source_eight_level_policy_status", sourceEightLevelPolicyStatus(source), true);
    try appendJsonField(allocator, &output, "source_policy_decision", source.source_policy_decision, true);
    try appendJsonField(allocator, &output, "source_eight_level_application_boundary", sourceEightLevelApplicationBoundary(source), true);
    try appendJsonField(allocator, &output, "source_eight_level_application_boundary_schema", sourceEightLevelApplicationBoundarySchema(source), true);
    try appendJsonField(allocator, &output, "source_eight_level_report", sourceEightLevelReport(source), true);
    try appendJsonField(allocator, &output, "source_eight_level_report_status", sourceEightLevelReportStatus(source), true);
    try appendJsonField(allocator, &output, "source_eight_level_application_status", sourceEightLevelApplicationStatus(source), true);
    try appendJsonField(allocator, &output, "source_inherited_policy", sourceInheritedPolicy(source), true);
    try appendJsonField(allocator, &output, "source_inherited_policy_schema", sourceInheritedPolicySchema(source), true);
    try appendJsonField(allocator, &output, "source_inherited_policy_status", sourceInheritedPolicyStatus(source), true);
    try appendJsonField(allocator, &output, "source_inherited_application_boundary", sourceInheritedApplicationBoundary(source), true);
    try appendJsonField(allocator, &output, "source_inherited_application_boundary_schema", sourceInheritedApplicationBoundarySchema(source), true);
    try appendJsonField(allocator, &output, "source_inherited_report", sourceInheritedReport(source), true);
    try appendJsonField(allocator, &output, "source_inherited_report_status", sourceInheritedReportStatus(source), true);
    try appendJsonField(allocator, &output, "source_inherited_application_status", sourceInheritedApplicationStatus(source), true);
    try appendJsonField(allocator, &output, "source_consumption_report_application_boundary", source.source_consumption_report_application_boundary, true);
    try appendJsonField(allocator, &output, "source_report_application_status", source.source_report_application_status, true);
    try appendJsonField(allocator, &output, "source_consumption_report", source.source_consumption_report, true);
    try appendJsonField(allocator, &output, "source_consumption_report_status", source.source_consumption_report_status, true);
    try output.print(allocator, "  \"source_report_policy_ready_for_next_branch\": {},\n", .{source.source_ready_for_next_branch});
    try appendJsonField(allocator, &output, "source_mutation_authority", source.source_mutation_authority, true);
    try appendJsonField(allocator, &output, "source_original_evaluator_status", source.source_evaluator_status, true);
    try appendJsonField(allocator, &output, "source_consumption_policy", source.source_consumption_policy, true);
    try appendJsonField(allocator, &output, "source_consumption_boundary", source.source_consumption_boundary, true);
    try appendJsonField(allocator, &output, "source_consumption_readiness", source.source_consumption_readiness, true);
    try appendJsonField(allocator, &output, "source_publication_policy", source.source_publication_policy, true);
    try appendJsonField(allocator, &output, "source_after_report_digest", source.source_after_report_digest, true);
    try appendJsonField(allocator, &output, "source_consumer_after_digest", source.source_consumer_after_digest, true);
    try appendJsonField(allocator, &output, "source_report_after_digest", source.source_report_after_digest, true);
    try output.print(allocator, "  \"source_report_after_present\": {},\n", .{source.source_report_after_present});
    try appendJsonField(allocator, &output, "source_eight_level_after_digest", sourceEightLevelAfterDigest(source), true);
    try output.print(allocator, "  \"source_eight_level_after_present\": {},\n", .{sourceEightLevelAfterPresent(source)});
    try appendJsonField(allocator, &output, "consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_status", reportStatusText(result.status), true);
    try output.print(allocator, "  \"ready_for_next_branch\": {},\n", .{result.ready_for_next_branch});
    try output.print(allocator, "  \"blocked_findings_count\": {d},\n", .{source.blocked_findings_count});
    try output.print(allocator, "  \"advisory_findings_count\": {d},\n", .{source.advisory_findings_count});
    try appendJsonField(allocator, &output, "mutation_authority", mutation_authority, true);
    try appendAuthorityJson(allocator, &output);
    try appendJsonField(allocator, &output, "reviewed_by", options.reviewed_by, true);
    try appendJsonField(allocator, &output, "policy", options.policy, true);
    try appendJsonField(allocator, &output, "reason", options.reason, true);
    try appendJsonField(allocator, &output, "headline", headlineForStatus(result.status), true);
    try output.appendSlice(allocator, "  \"source_thirteen_level_application_changes\": ");
    try appendStringArray(allocator, &output, source.source_thirteen_level_application_changes);
    try output.appendSlice(allocator, ",\n  \"source_twelve_level_application_changes\": ");
    try appendStringArray(allocator, &output, source.source_twelve_level_application_changes);
    try output.appendSlice(allocator, ",\n  \"source_eleven_level_application_changes\": ");
    try appendStringArray(allocator, &output, source.source_eleven_level_application_changes);
    try output.appendSlice(allocator, ",\n  \"source_ten_level_application_changes\": ");
    try appendStringArray(allocator, &output, source.source_ten_level_application_changes);
    try output.appendSlice(allocator, ",\n  \"source_eight_level_application_changes\": ");
    try appendStringArray(allocator, &output, sourceEightLevelApplicationChanges(source));
    try output.appendSlice(allocator, ",\n  \"source_inherited_application_changes\": ");
    try appendStringArray(allocator, &output, sourceInheritedApplicationChanges(source));
    try output.appendSlice(allocator, ",\n  \"source_before_evidence\": ");
    try appendStringArray(allocator, &output, source.source_before_evidence);
    try output.appendSlice(allocator, ",\n  \"source_after_evidence\": ");
    try appendStringArray(allocator, &output, source.source_after_evidence);
    try output.appendSlice(allocator, ",\n  \"source_report_application_changes\": ");
    try appendStringArray(allocator, &output, source.source_report_application_changes);
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
    try output.appendSlice(allocator, ",\n  \"source_policy_rule_ids_from_report\": ");
    try appendStringArray(allocator, &output, source.source_policy_rule_ids_from_report);
    try output.appendSlice(allocator, ",\n  \"source_consumption_scope_ids_from_report\": ");
    try appendStringArray(allocator, &output, source.source_consumption_scope_ids_from_report);
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
    try appendFindingsJson(allocator, &output, source.source_blocked_findings, "blocked");
    try output.appendSlice(allocator, ",\n  \"source_advisory_findings\": ");
    try appendFindingsJson(allocator, &output, source.source_advisory_findings, "advisory");
    try output.appendSlice(allocator, ",\n");
    try output.appendSlice(allocator, "  \"report_sections\": ");
    try appendStringArray(allocator, &output, report_sections);
    try output.appendSlice(allocator, ",\n  \"request_summary\": ");
    try appendFilesJson(allocator, &output, source.request_files);
    try output.appendSlice(allocator, ",\n  \"support_evidence_summary\": ");
    try appendFilesJson(allocator, &output, source.evidence_files);
    try output.appendSlice(allocator, ",\n  \"signal_summary\": ");
    try appendSignalsJson(allocator, &output, source.signal_evaluations);
    try output.appendSlice(allocator, ",\n  \"blocked_findings\": ");
    try appendFindingsJson(allocator, &output, source.findings, "blocked");
    try output.appendSlice(allocator, ",\n  \"advisory_findings\": ");
    try appendFindingsJson(allocator, &output, source.findings, "advisory");
    try output.appendSlice(allocator, ",\n  \"checks\": ");
    try appendChecksJson(allocator, &output, result.checks);
    try output.appendSlice(allocator, ",\n  \"source_policy_rule_ids\": ");
    try appendStringArray(allocator, &output, source.source_policy_rule_ids);
    try output.appendSlice(allocator, ",\n  \"source_consumption_scope_ids\": ");
    try appendStringArray(allocator, &output, source.source_consumption_scope_ids);
    try output.appendSlice(allocator, ",\n  \"denied_claims\": ");
    try appendStringArray(allocator, &output, source.denied_claims);
    try output.appendSlice(allocator, ",\n  \"next_queries\": ");
    try appendReportNextQueriesJson(allocator, &output, result.status, paths);
    try output.appendSlice(allocator, ",\n  \"publication_channels\": ");
    try appendPublicationChannelsJson(allocator, &output);
    try output.appendSlice(allocator, ",\n  \"required_verification_commands\": ");
    try appendStringArray(allocator, &output, required_verification_commands);
    try appendJsonFieldPrefixComma(allocator, &output, "json_output", paths.json_path);
    try appendJsonFieldPrefixComma(allocator, &output, "text_output", paths.text_path);
    try output.appendSlice(allocator, ",\n  \"agent_guidance\": ");
    try appendStringArray(allocator, &output, agentGuidance(result.status));
    try output.appendSlice(allocator, "\n}\n");

    return output.toOwnedSlice(allocator);
}

fn formatReportText(
    allocator: std.mem.Allocator,
    options: Options,
    source: EvaluatorArtifact,
    result: ReportResult,
    paths: OutputPaths,
) ![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "zigeffect app-facing fourteen-level report\n");
    try output.print(allocator, "schema: {s}\n", .{schema});
    try output.print(allocator, "headline: {s}\n", .{headlineForStatus(result.status)});
    try output.print(allocator, "source evaluator: {s}\n", .{options.evaluator_path});
    try output.print(allocator, "source evaluator status: {s}\n", .{source.evaluation_status});
    try output.print(allocator, "source ready for next branch: {}\n", .{source.ready_for_next_branch});
    try output.print(allocator, "source thirteen-level evaluator: {s}\n", .{options.evaluator_path});
    try output.print(allocator, "source thirteen-level evaluator status: {s}\n", .{source.evaluation_status});
    try output.print(allocator, "source thirteen-level policy: {s}\n", .{sourceThirteenLevelPolicy(source)});
    try output.print(allocator, "source thirteen-level policy status: {s}\n", .{sourceThirteenLevelPolicyStatus(source)});
    try output.print(allocator, "source thirteen-level application boundary: {s}\n", .{sourceThirteenLevelApplicationBoundary(source)});
    try output.print(allocator, "source thirteen-level application boundary status: {s}\n", .{sourceThirteenLevelApplicationBoundaryStatus(source)});
    try output.print(allocator, "source thirteen-level report: {s}\n", .{sourceThirteenLevelReport(source)});
    try output.print(allocator, "source thirteen-level report status: {s}\n", .{sourceThirteenLevelReportStatus(source)});
    try output.print(allocator, "source thirteen-level after digest: {s}\n", .{source.source_thirteen_level_after_digest});
    try output.print(allocator, "source thirteen-level after present: {}\n", .{source.source_thirteen_level_after_present});
    try output.print(allocator, "source twelve-level evaluator: {s}\n", .{sourceTwelveLevelEvaluator(source)});
    try output.print(allocator, "source twelve-level evaluator status: {s}\n", .{sourceTwelveLevelEvaluatorStatus(source)});
    try output.print(allocator, "source twelve-level policy: {s}\n", .{sourceTwelveLevelPolicy(source)});
    try output.print(allocator, "source twelve-level policy status: {s}\n", .{sourceTwelveLevelPolicyStatus(source)});
    try output.print(allocator, "source twelve-level application boundary: {s}\n", .{sourceTwelveLevelApplicationBoundary(source)});
    try output.print(allocator, "source twelve-level report: {s}\n", .{sourceTwelveLevelReport(source)});
    try output.print(allocator, "source twelve-level report status: {s}\n", .{sourceTwelveLevelReportStatus(source)});
    try output.print(allocator, "source twelve-level after digest: {s}\n", .{source.source_twelve_level_after_digest});
    try output.print(allocator, "source twelve-level after present: {}\n", .{source.source_twelve_level_after_present});
    try output.print(allocator, "source eleven-level policy: {s}\n", .{sourceElevenLevelPolicy(source)});
    try output.print(allocator, "source eleven-level policy status: {s}\n", .{sourceElevenLevelPolicyStatus(source)});
    try output.print(allocator, "source eleven-level application boundary: {s}\n", .{sourceElevenLevelApplicationBoundary(source)});
    try output.print(allocator, "source eleven-level report: {s}\n", .{sourceElevenLevelReport(source)});
    try output.print(allocator, "source eleven-level report status: {s}\n", .{sourceElevenLevelReportStatus(source)});
    try output.print(allocator, "source eleven-level after digest: {s}\n", .{source.source_eleven_level_after_digest});
    try output.print(allocator, "source eleven-level after present: {}\n", .{source.source_eleven_level_after_present});
    try output.print(allocator, "source ten-level policy: {s}\n", .{sourceTenLevelPolicy(source)});
    try output.print(allocator, "source ten-level policy status: {s}\n", .{sourceTenLevelPolicyStatus(source)});
    try output.print(allocator, "source ten-level application boundary: {s}\n", .{sourceTenLevelApplicationBoundary(source)});
    try output.print(allocator, "source ten-level report: {s}\n", .{sourceTenLevelReport(source)});
    try output.print(allocator, "source ten-level report status: {s}\n", .{sourceTenLevelReportStatus(source)});
    try output.print(allocator, "source nine-level policy: {s}\n", .{sourceNineLevelPolicy(source)});
    try output.print(allocator, "source nine-level policy status: {s}\n", .{sourceNineLevelPolicyStatus(source)});
    try output.print(allocator, "source nine-level application boundary: {s}\n", .{sourceNineLevelApplicationBoundary(source)});
    try output.print(allocator, "source nine-level report: {s}\n", .{sourceNineLevelReport(source)});
    try output.print(allocator, "source nine-level report status: {s}\n", .{sourceNineLevelReportStatus(source)});
    try output.print(allocator, "source eight-level policy: {s}\n", .{sourceEightLevelPolicy(source)});
    try output.print(allocator, "source eight-level policy status: {s}\n", .{sourceEightLevelPolicyStatus(source)});
    try output.print(allocator, "source eight-level application boundary: {s}\n", .{sourceEightLevelApplicationBoundary(source)});
    try output.print(allocator, "source eight-level application status: {s}\n", .{sourceEightLevelApplicationStatus(source)});
    try output.print(allocator, "source eight-level report: {s}\n", .{sourceEightLevelReport(source)});
    try output.print(allocator, "source eight-level report status: {s}\n", .{sourceEightLevelReportStatus(source)});
    try output.print(allocator, "source inherited policy: {s}\n", .{sourceInheritedPolicy(source)});
    try output.print(allocator, "source inherited policy status: {s}\n", .{sourceInheritedPolicyStatus(source)});
    try output.print(allocator, "source inherited application boundary: {s}\n", .{sourceInheritedApplicationBoundary(source)});
    try output.print(allocator, "source inherited application status: {s}\n", .{sourceInheritedApplicationStatus(source)});
    try output.print(allocator, "source inherited report: {s}\n", .{sourceInheritedReport(source)});
    try output.print(allocator, "source inherited report status: {s}\n", .{sourceInheritedReportStatus(source)});
    try output.print(allocator, "source report application boundary: {s}\n", .{source.source_consumption_report_application_boundary});
    try output.print(allocator, "source report application status: {s}\n", .{source.source_report_application_status});
    try output.print(allocator, "source consumption report: {s}\n", .{source.source_consumption_report});
    try output.print(allocator, "source eight-level after digest: {s}\n", .{sourceEightLevelAfterDigest(source)});
    try output.print(allocator, "source eight-level after present: {}\n", .{sourceEightLevelAfterPresent(source)});
    try output.print(allocator, "consumption report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report status: {s}\n", .{reportStatusText(result.status)});
    try output.print(allocator, "ready for next branch: {}\n", .{result.ready_for_next_branch});
    try output.print(allocator, "blocked findings count: {d}\n", .{source.blocked_findings_count});
    try output.print(allocator, "advisory findings count: {d}\n", .{source.advisory_findings_count});
    try output.print(allocator, "mutation authority: {s}\n", .{mutation_authority});
    try output.print(allocator, "app runtime integration enabled: {}\n", .{app_runtime_integration_enabled});
    try output.print(allocator, "nendb write enabled: {}\n", .{nendb_write_enabled});
    try output.print(allocator, "nendb adapter execution enabled: {}\n", .{nendb_adapter_execution_enabled});
    try output.print(allocator, "solid webui renderer: {s}\n", .{solid_webui_renderer});
    try output.print(allocator, "webui bridge: {s}\n", .{webui_bridge});
    try output.print(allocator, "reviewed_by: {s}\n", .{options.reviewed_by});
    try output.print(allocator, "policy: {s}\n", .{options.policy});
    try output.print(allocator, "reason: {s}\n", .{options.reason});
    try output.print(allocator, "source branch: {s}\n", .{source_branch});
    try output.print(allocator, "recommendation: {s}\n", .{recommendation});
    try output.print(allocator, "next branch if ready: {s}\n", .{next_branch_if_ready});
    try output.print(allocator, "json output: {s}\n", .{paths.json_path});
    try output.print(allocator, "text output: {s}\n\n", .{paths.text_path});

    try appendTextList(allocator, &output, "source thirteen-level application changes", source.source_thirteen_level_application_changes);
    try appendTextList(allocator, &output, "source twelve-level application changes", source.source_twelve_level_application_changes);
    try appendTextList(allocator, &output, "source eleven-level application changes", source.source_eleven_level_application_changes);
    try appendTextList(allocator, &output, "source ten-level application changes", source.source_ten_level_application_changes);
    try appendTextList(allocator, &output, "source eight-level application changes", sourceEightLevelApplicationChanges(source));
    try appendTextList(allocator, &output, "source inherited application changes", sourceInheritedApplicationChanges(source));
    try appendTextList(allocator, &output, "source before evidence", source.source_before_evidence);
    try appendTextList(allocator, &output, "source after evidence", source.source_after_evidence);
    try appendTextList(allocator, &output, "source report application changes", source.source_report_application_changes);
    try appendTextList(allocator, &output, "source report before evidence", source.source_report_before_evidence);
    try appendTextList(allocator, &output, "source report after evidence", source.source_report_after_evidence);
    try appendTextList(allocator, &output, "source report next queries", source.source_report_next_queries);
    try appendTextList(allocator, &output, "source report boundary rules", source.source_report_boundary_rules);
    try appendTextList(allocator, &output, "source report publication channel ids", source.source_report_publication_channel_ids);
    try appendFilesText(allocator, &output, "source request summary", source.source_request_summary);
    try appendFilesText(allocator, &output, "source support evidence summary", source.source_support_evidence_summary);
    try appendSignalsText(allocator, &output, source.source_signal_summary);
    try appendFindingText(allocator, &output, "source blocked findings", source.source_blocked_findings, "blocked");
    try appendFindingText(allocator, &output, "source advisory findings", source.source_advisory_findings, "advisory");
    try appendFilesText(allocator, &output, "request summary", source.request_files);
    try appendFilesText(allocator, &output, "support evidence summary", source.evidence_files);
    try appendSignalsText(allocator, &output, source.signal_evaluations);
    try appendFindingText(allocator, &output, "blocked findings", source.findings, "blocked");
    try appendFindingText(allocator, &output, "advisory findings", source.findings, "advisory");

    try output.appendSlice(allocator, "checks:\n");
    for (result.checks) |check| {
        try output.print(allocator, "- {s}: {s} - {s}\n", .{ check.name, checkStatusText(check.status), check.detail });
    }
    try output.append(allocator, '\n');

    try appendTextList(allocator, &output, "source policy rule ids", source.source_policy_rule_ids);
    try appendTextList(allocator, &output, "source consumption scope ids", source.source_consumption_scope_ids);
    try appendTextList(allocator, &output, "denied claims", source.denied_claims);
    try appendReportNextQueriesText(allocator, &output, result.status, paths);

    try output.appendSlice(allocator, "publication channels:\n");
    for (publication_channels) |channel| {
        try output.print(allocator, "- {s}: allowed={}, executed_by_tool={} - {s}\n", .{ channel.id, channel.allowed, channel.executed_by_tool, channel.detail });
    }
    try output.append(allocator, '\n');

    try appendTextList(allocator, &output, "required verification commands", required_verification_commands);
    try appendTextList(allocator, &output, "agent guidance", agentGuidance(result.status));

    return output.toOwnedSlice(allocator);
}

fn appendAuthorityJson(allocator: std.mem.Allocator, output: *std.ArrayList(u8)) !void {
    try output.print(allocator,
        \\  "ci_gate_enabled": {},
        \\  "ci_gate_enforcement_enabled": {},
        \\  "ci_required_status_check_enabled": {},
        \\  "ci_workflow_mutation_enabled": {},
        \\  "ci_upload_execution_enabled": {},
        \\  "ci_report_publication_enabled": {},
        \\  "github_step_summary_write_enabled": {},
        \\  "pull_request_comment_enabled": {},
        \\  "github_api_mutation_enabled": {},
        \\  "app_mutation_controls_enabled": {},
        \\  "app_mutation_enabled": {},
        \\  "app_config_write_enabled": {},
        \\  "app_data_write_enabled": {},
        \\  "app_runtime_integration_enabled": {},
        \\  "agent_query_live_projection_enabled": {},
        \\  "raw_payload_capture_enabled": {},
        \\  "deployment_mutation_enabled": {},
        \\  "production_telemetry_ingestion": {},
        \\  "live_exporter_enabled": {},
        \\  "network_send_enabled": {},
        \\  "collector_endpoint_configured": {},
        \\  "otlp_serialization_enabled": {},
        \\  "runtime_pipeline_enabled": {},
        \\  "durable_write_enabled": {},
        \\  "nendb_write_enabled": {},
        \\  "nendb_adapter_execution_enabled": {},
        \\
    , .{
        ci_gate_enabled,
        ci_gate_enforcement_enabled,
        ci_required_status_check_enabled,
        ci_workflow_mutation_enabled,
        ci_upload_execution_enabled,
        ci_report_publication_enabled,
        github_step_summary_write_enabled,
        pull_request_comment_enabled,
        github_api_mutation_enabled,
        app_mutation_controls_enabled,
        app_mutation_enabled,
        app_config_write_enabled,
        app_data_write_enabled,
        app_runtime_integration_enabled,
        agent_query_live_projection_enabled,
        raw_payload_capture_enabled,
        deployment_mutation_enabled,
        production_telemetry_ingestion,
        live_exporter_enabled,
        network_send_enabled,
        collector_endpoint_configured,
        otlp_serialization_enabled,
        runtime_pipeline_enabled,
        durable_write_enabled,
        nendb_write_enabled,
        nendb_adapter_execution_enabled,
    });
    try output.print(allocator,
        \\  "public_artifact_upload_enabled": {},
        \\  "hosted_live_dashboard_enabled": {},
        \\  "production_health_claim_enabled": {},
        \\  "auto_apply_enabled": {},
        \\  "advisory_report": {},
        \\  "read_only_preview": {},
        \\  "read_only_consumption_enabled": {},
        \\  "solid_webui_enabled": {},
        \\  "solid_webui_renderer": "{s}",
        \\  "webui_bridge": "{s}",
        \\
    , .{
        public_artifact_upload_enabled,
        hosted_live_dashboard_enabled,
        production_health_claim_enabled,
        auto_apply_enabled,
        advisory_report,
        read_only_preview,
        read_only_consumption_enabled,
        solid_webui_enabled,
        solid_webui_renderer,
        webui_bridge,
    });
}

fn appendJsonField(allocator: std.mem.Allocator, output: *std.ArrayList(u8), name: []const u8, value: []const u8, comma: bool) !void {
    try output.appendSlice(allocator, "  \"");
    try output.appendSlice(allocator, name);
    try output.appendSlice(allocator, "\": ");
    try appendJsonString(allocator, output, value);
    if (comma) try output.append(allocator, ',');
    try output.append(allocator, '\n');
}

fn appendJsonFieldPrefixComma(allocator: std.mem.Allocator, output: *std.ArrayList(u8), name: []const u8, value: []const u8) !void {
    try output.appendSlice(allocator, ",\n");
    try appendJsonField(allocator, output, name, value, false);
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

fn appendFindingsJson(allocator: std.mem.Allocator, output: *std.ArrayList(u8), findings: []const SourceFinding, severity: []const u8) !void {
    try output.append(allocator, '[');
    var emitted: usize = 0;
    for (findings) |finding| {
        if (!std.mem.eql(u8, finding.severity, severity)) continue;
        if (emitted > 0) try output.appendSlice(allocator, ", ");
        emitted += 1;
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

fn appendChecksJson(allocator: std.mem.Allocator, output: *std.ArrayList(u8), checks: []const ReportCheck) !void {
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

fn appendPublicationChannelsJson(allocator: std.mem.Allocator, output: *std.ArrayList(u8)) !void {
    try output.append(allocator, '[');
    for (publication_channels, 0..) |channel, index| {
        if (index > 0) try output.appendSlice(allocator, ", ");
        try output.appendSlice(allocator, "{ \"id\": ");
        try appendJsonString(allocator, output, channel.id);
        try output.print(allocator, ", \"allowed\": {}, \"executed_by_tool\": {}, \"detail\": ", .{ channel.allowed, channel.executed_by_tool });
        try appendJsonString(allocator, output, channel.detail);
        try output.appendSlice(allocator, " }");
    }
    try output.append(allocator, ']');
}

fn appendReportNextQueriesJson(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    status: ReportStatus,
    paths: OutputPaths,
) !void {
    try output.append(allocator, '[');
    switch (status) {
        .ready, .advisory => {
            const query_artifact = try std.fmt.allocPrint(allocator, "causal-query --artifact {s} --kind checks", .{paths.json_path});
            defer allocator.free(query_artifact);
            const branch_handoff = try std.fmt.allocPrint(allocator, "start {s} with {s}", .{ next_branch_if_ready, paths.json_path });
            defer allocator.free(branch_handoff);
            try appendJsonString(allocator, output, query_artifact);
            try output.appendSlice(allocator, ", ");
            try appendJsonString(allocator, output, branch_handoff);
        },
        .blocked => {
            try appendJsonString(allocator, output, "repair blocked source evaluator evidence before application-boundary work");
            try output.appendSlice(allocator, ", ");
            try appendJsonString(allocator, output, "do not start fourteen-level application-boundary work from blocked report evidence");
        },
    }
    try output.append(allocator, ']');
}

fn appendReportNextQueriesText(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    status: ReportStatus,
    paths: OutputPaths,
) !void {
    try output.appendSlice(allocator, "next queries:\n");
    switch (status) {
        .ready, .advisory => {
            try output.print(allocator, "- causal-query --artifact {s} --kind checks\n", .{paths.json_path});
            try output.print(allocator, "- start {s} with {s}\n", .{ next_branch_if_ready, paths.json_path });
        },
        .blocked => {
            try output.appendSlice(allocator, "- repair blocked source evaluator evidence before application-boundary work\n");
            try output.appendSlice(allocator, "- do not start fourteen-level application-boundary work from blocked report evidence\n");
        },
    }
    try output.append(allocator, '\n');
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

fn appendFilesText(allocator: std.mem.Allocator, output: *std.ArrayList(u8), title: []const u8, files: []const SourceFile) !void {
    try output.print(allocator, "{s}:\n", .{title});
    if (files.len == 0) {
        try output.appendSlice(allocator, "- none\n\n");
        return;
    }
    for (files) |file| {
        try output.print(allocator, "- {s}: {s}, {d} bytes, redaction={s}", .{ file.path, file.class, file.size_bytes, file.redaction_posture });
        if (file.detected_role.len > 0) try output.print(allocator, ", role={s}", .{file.detected_role});
        if (file.denied_reason.len > 0) try output.print(allocator, ", denied={s}", .{file.denied_reason});
        try output.append(allocator, '\n');
    }
    try output.append(allocator, '\n');
}

fn appendSignalsText(allocator: std.mem.Allocator, output: *std.ArrayList(u8), signals: []const SourceSignal) !void {
    try output.appendSlice(allocator, "signals:\n");
    for (signals) |signal| {
        try output.print(allocator, "- {s}: {s} - {s}", .{ signal.id, signal.status, signal.detail });
        if (signal.evidence_path.len > 0) try output.print(allocator, " ({s})", .{signal.evidence_path});
        try output.append(allocator, '\n');
    }
    try output.append(allocator, '\n');
}

fn appendFindingText(allocator: std.mem.Allocator, output: *std.ArrayList(u8), title: []const u8, findings: []const SourceFinding, severity: []const u8) !void {
    try output.print(allocator, "{s}:\n", .{title});
    var emitted: usize = 0;
    for (findings) |finding| {
        if (!std.mem.eql(u8, finding.severity, severity)) continue;
        emitted += 1;
        try output.print(allocator, "- {s}: {s} - {s}", .{ finding.id, finding.signal, finding.detail });
        if (finding.evidence_path.len > 0) try output.print(allocator, " ({s})", .{finding.evidence_path});
        try output.append(allocator, '\n');
    }
    if (emitted == 0) try output.appendSlice(allocator, "- none\n");
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

fn reportStatusText(status: ReportStatus) []const u8 {
    return switch (status) {
        .ready => "ready",
        .advisory => "advisory",
        .blocked => "blocked",
    };
}

fn checkStatusText(status: CheckStatus) []const u8 {
    return switch (status) {
        .pass => "pass",
        .fail => "fail",
    };
}

fn headlineForStatus(status: ReportStatus) []const u8 {
    return switch (status) {
        .ready => "App-facing thirteen-level evaluator evidence is ready for fourteen-level report presentation.",
        .advisory => "App-facing thirteen-level evaluator evidence is reportable with advisory findings.",
        .blocked => "App-facing thirteen-level evaluator evidence is blocked and must not be used as reportable context.",
    };
}

fn agentGuidance(status: ReportStatus) []const []const u8 {
    return switch (status) {
        .ready => &.{
            "Use this local report as bounded agent and reviewer context.",
            "Start the application-boundary branch only for reviewed local report application evidence.",
            "Do not infer app runtime integration, GitHub mutation, Nendb writes, deployment authority, production health, or mutation authority.",
        },
        .advisory => &.{
            "Surface advisory findings as context quality notes.",
            "Do not treat missing support evidence as blocked unless a later policy says so.",
            "Keep this report local and non-mutating.",
        },
        .blocked => &.{
            "Do not present blocked evaluator evidence as reportable app-facing context.",
            "Repair evaluator source evidence before report application work.",
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
    const source_evaluator_json = try readRequiredArtifact(init.io, allocator, options.evaluator_path, error.MissingEvaluatorInput);
    defer allocator.free(source_evaluator_json);

    const reports = try formatReports(allocator, .{
        .options = options,
        .source_evaluator_json = source_evaluator_json,
    });
    defer reports.deinit(allocator);

    const paths = try outputPathsForOptions(allocator, options);
    defer paths.deinit(allocator);

    try writeArtifact(init.io, paths.json_path, reports.json);
    try writeArtifact(init.io, paths.text_path, reports.text);
    std.debug.print("{s}", .{reports.text});
}

fn usage() []const u8 {
    return "usage: zig build causal-app-facing-fourteen-level-report -- --from-evaluator <thirteen-level-evaluator.json> summarize --reason <reason> [--by <actor>] [--policy <policy>] [--out-prefix <path-prefix>]\n";
}

fn failUsage(err: anyerror) noreturn {
    std.debug.print("causal-app-facing-fourteen-level-report error: {s}\n{s}", .{ @errorName(err), usage() });
    std.process.exit(2);
}

test "app-facing fourteen-level report constants are stable" {
    try std.testing.expectEqualStrings("zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report.v1", schema);
    try std.testing.expectEqual(@as(u32, 1), schema_version);
    try std.testing.expectEqualStrings("codex/zigeffect-causal-app-facing-fourteen-level-report", source_branch);
    try std.testing.expectEqualStrings("start-app-facing-fourteen-level-application-boundary", recommendation);
    try std.testing.expectEqualStrings("codex/zigeffect-causal-app-facing-fourteen-level-application-boundary", next_branch_if_ready);
}

test "parses app-facing fourteen-level report options" {
    const options = try parseOptions(&.{
        "zigeffect-causal-app-facing-fourteen-level-report",
        "--from-evaluator",
        ".zig-cache/causal-artifacts/app-facing-ci-thirteen-level-evaluator.json",
        "summarize",
        "--reason",
        "reviewed app-facing fourteen-level report",
        "--by",
        "codex",
        "--policy",
        "manual-app-facing-fourteen-level-report",
        "--out-prefix",
        ".zig-cache/causal-artifacts/custom-fourteen-level-report",
    });

    try std.testing.expectEqualStrings(".zig-cache/causal-artifacts/app-facing-ci-thirteen-level-evaluator.json", options.evaluator_path);
    try std.testing.expectEqualStrings("reviewed app-facing fourteen-level report", options.reason);
    try std.testing.expectEqualStrings("codex", options.reviewed_by);
    try std.testing.expectEqualStrings("manual-app-facing-fourteen-level-report", options.policy);
    try std.testing.expectEqualStrings(".zig-cache/causal-artifacts/custom-fourteen-level-report", options.out_prefix.?);
}

test "app-facing fourteen-level report rejects invalid options" {
    try std.testing.expectError(error.InvalidEvaluatorPath, parseOptions(&.{ "tool", "--from-evaluator", "source.txt", "summarize", "--reason", "reviewed" }));
    try std.testing.expectError(error.UnknownCommand, parseOptions(&.{ "tool", "--from-evaluator", "source.json", "evaluate", "--reason", "reviewed" }));
    try std.testing.expectError(error.MissingReason, parseOptions(&.{ "tool", "--from-evaluator", "source.json", "summarize" }));
}

test "default output path replaces thirteen-level evaluator suffix" {
    const paths = try outputPathsForOptions(std.testing.allocator, .{
        .evaluator_path = "../../.zig-cache/causal-artifacts/example-ci-thirteen-level-evaluator.json",
        .reason = "reviewed",
    });
    defer paths.deinit(std.testing.allocator);

    try std.testing.expectEqualStrings("../../.zig-cache/causal-artifacts/example-ci-fourteen-level-report.json", paths.json_path);
    try std.testing.expectEqualStrings("../../.zig-cache/causal-artifacts/example-ci-fourteen-level-report.txt", paths.text_path);
}

test "default output path compacts long real evaluator names" {
    const paths = try outputPathsForOptions(std.testing.allocator, .{
        .evaluator_path = "../../.zig-cache/causal-artifacts/app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator-88227538b2cab4f7.json",
        .reason = "reviewed",
    });
    defer paths.deinit(std.testing.allocator);

    const slash = std.mem.lastIndexOfScalar(u8, paths.json_path, '/');
    const json_name = if (slash) |index| paths.json_path[index + 1 ..] else paths.json_path;
    try std.testing.expect(json_name.len <= max_default_output_file_name_len);
    try std.testing.expect(std.mem.indexOf(u8, paths.json_path, compact_output_prefix_name) != null);
    try std.testing.expect(std.mem.endsWith(u8, paths.json_path, ".json"));
    try std.testing.expect(std.mem.endsWith(u8, paths.text_path, ".txt"));
}

test "ready evaluator produces ready fourteen-level report" {
    const reports = try formatReports(std.testing.allocator, .{
        .options = sampleOptions(),
        .source_evaluator_json = sample_ready_evaluator_json,
    });
    defer reports.deinit(std.testing.allocator);

    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"schema\": \"zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_status\": \"ready\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"ready_for_next_branch\": true") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"mutation_authority\": \"none\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"next_branch_if_ready\": \"codex/zigeffect-causal-app-facing-fourteen-level-application-boundary\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"source_thirteen_level_evaluator\": \"../../.zig-cache/causal-artifacts/app-facing-ci-thirteen-level-evaluator.json\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"source_thirteen_level_policy\": \"app-facing-ci-thirteen-level-policy.json\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"source_thirteen_level_application_boundary\": \"app-facing-ci-thirteen-level-application-boundary.json\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"source_thirteen_level_report\": \"app-facing-ci-thirteen-level-report.json\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"source_twelve_level_evaluator\": \"app-facing-ci-twelve-level-evaluator.json\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "codex/zigeffect-causal-app-facing-fourteen-level-application-boundary") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"source_twelve_level_policy\": \"app-facing-ci-twelve-level-policy.json\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"source_twelve_level_application_boundary\": \"app-facing-ci-twelve-level-application-boundary.json\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"source_twelve_level_report\": \"app-facing-ci-twelve-level-report.json\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"source_eleven_level_policy\": \"app-facing-ci-eleven-level-policy.json\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"source_eleven_level_application_boundary\": \"app-facing-ci-eleven-level-application-boundary.json\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"source_eleven_level_report\": \"app-facing-ci-eleven-level-report.json\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"source_ten_level_policy\": \"app-facing-ci-ten-level-policy.json\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"source_ten_level_application_boundary\": \"app-facing-ci-ten-level-application-boundary.json\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"source_ten_level_report\": \"app-facing-ci-ten-level-report.json\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"source_nine_level_policy\": \"app-facing-ci-nine-level-policy.json\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"source_nine_level_application_boundary\": \"app-facing-ci-nine-level-application-boundary.json\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"source_nine_level_report\": \"app-facing-ci-nine-level-report.json\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.text, "consumption report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report status: ready") != null);

    var parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, reports.json, .{});
    parsed.deinit();
}

test "advisory evaluator produces advisory fourteen-level report" {
    const reports = try formatReports(std.testing.allocator, .{
        .options = sampleOptions(),
        .source_evaluator_json = sample_advisory_evaluator_json,
    });
    defer reports.deinit(std.testing.allocator);

    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_status\": \"advisory\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"ready_for_next_branch\": true") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"id\": \"support-evidence-present\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.text, "advisory findings:") != null);
}

test "blocked evaluator produces blocked fourteen-level report" {
    const reports = try formatReports(std.testing.allocator, .{
        .options = sampleOptions(),
        .source_evaluator_json = sample_blocked_evaluator_json,
    });
    defer reports.deinit(std.testing.allocator);

    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_status\": \"blocked\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"ready_for_next_branch\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"id\": \"request-denied\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.text, "blocked findings:") != null);
}

test "authority drift in source evaluator blocks report" {
    const reports = try formatReports(std.testing.allocator, .{
        .options = sampleOptions(),
        .source_evaluator_json = sample_authority_violation_evaluator_json,
    });
    defer reports.deinit(std.testing.allocator);

    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_status\": \"blocked\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"name\": \"source-disabled-authority\"") != null);
}

test "publication channels remain local-only and record-only" {
    const reports = try formatReports(std.testing.allocator, .{
        .options = sampleOptions(),
        .source_evaluator_json = sample_ready_evaluator_json,
    });
    defer reports.deinit(std.testing.allocator);

    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"id\": \"local-json-artifact\", \"allowed\": true, \"executed_by_tool\": true") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"id\": \"ci-upload-artifact\", \"allowed\": false, \"executed_by_tool\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"id\": \"app-runtime-integration\", \"allowed\": false, \"executed_by_tool\": false") != null);
}

fn sampleOptions() Options {
    return .{
        .evaluator_path = "../../.zig-cache/causal-artifacts/app-facing-ci-thirteen-level-evaluator.json",
        .reason = "reviewed app-facing fourteen-level report",
    };
}

const sample_ready_evaluator_json =
    \\{
    \\  "schema": "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator.v1",
    \\  "schema_version": 1,
    \\  "generated_by": "causal-app-facing-thirteen-level-evaluator",
    \\  "source_thirteen_level_policy": "app-facing-ci-thirteen-level-policy.json",
    \\  "source_thirteen_level_policy_schema": "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy.v1",
    \\  "source_thirteen_level_policy_status": "ready",
    \\  "source_thirteen_level_application_boundary": "app-facing-ci-thirteen-level-application-boundary.json",
    \\  "source_thirteen_level_application_boundary_schema": "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary.v1",
    \\  "source_thirteen_level_application_boundary_status": "applied",
    \\  "source_thirteen_level_report": "app-facing-ci-thirteen-level-report.json",
    \\  "source_thirteen_level_report_schema": "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report.v1",
    \\  "source_thirteen_level_report_status": "ready",
    \\  "source_thirteen_level_after_digest": "sha256:thirteen-after",
    \\  "source_thirteen_level_after_present": true,
    \\  "source_thirteen_level_application_changes": ["reviewed local thirteen-level application boundary"],
    \\  "source_twelve_level_evaluator": "app-facing-ci-twelve-level-evaluator.json",
    \\  "source_twelve_level_evaluator_schema": "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator.v1",
    \\  "source_twelve_level_evaluator_status": "ready",
    \\  "source_twelve_level_policy": "app-facing-ci-twelve-level-policy.json",
    \\  "source_twelve_level_policy_schema": "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy.v1",
    \\  "source_twelve_level_policy_status": "ready",
    \\  "source_twelve_level_application_boundary": "app-facing-ci-twelve-level-application-boundary.json",
    \\  "source_twelve_level_application_boundary_schema": "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary.v1",
    \\  "source_twelve_level_report": "app-facing-ci-twelve-level-report.json",
    \\  "source_twelve_level_report_schema": "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report.v1",
    \\  "source_twelve_level_report_status": "ready",
    \\  "source_twelve_level_after_digest": "sha256:twelve-after",
    \\  "source_twelve_level_after_present": true,
    \\  "source_twelve_level_application_changes": ["reviewed local twelve-level application boundary"],
    \\  "source_eleven_level_policy": "app-facing-ci-eleven-level-policy.json",
    \\  "source_eleven_level_policy_schema": "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy.v1",
    \\  "source_eleven_level_policy_status": "ready",
    \\  "source_eleven_level_application_boundary": "app-facing-ci-eleven-level-application-boundary.json",
    \\  "source_eleven_level_application_boundary_schema": "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary.v1",
    \\  "source_eleven_level_report": "app-facing-ci-eleven-level-report.json",
    \\  "source_eleven_level_report_schema": "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report.v1",
    \\  "source_eleven_level_report_status": "ready",
    \\  "source_eleven_level_after_digest": "sha256:eleven-after",
    \\  "source_eleven_level_after_present": true,
    \\  "source_eleven_level_application_changes": ["reviewed local eleven-level application boundary"],
    \\  "source_ten_level_policy": "app-facing-ci-ten-level-policy.json",
    \\  "source_ten_level_policy_schema": "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy.v1",
    \\  "source_ten_level_policy_status": "ready",
    \\  "source_ten_level_application_boundary": "app-facing-ci-ten-level-application-boundary.json",
    \\  "source_ten_level_application_boundary_schema": "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary.v1",
    \\  "source_ten_level_report": "app-facing-ci-ten-level-report.json",
    \\  "source_ten_level_report_schema": "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report.v1",
    \\  "source_ten_level_report_status": "ready",
    \\  "source_nine_level_policy": "app-facing-ci-nine-level-policy.json",
    \\  "source_nine_level_policy_schema": "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy.v1",
    \\  "source_nine_level_policy_status": "ready",
    \\  "source_nine_level_application_boundary": "app-facing-ci-nine-level-application-boundary.json",
    \\  "source_nine_level_application_boundary_schema": "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary.v1",
    \\  "source_nine_level_report": "app-facing-ci-nine-level-report.json",
    \\  "source_nine_level_report_schema": "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report.v1",
    \\  "source_nine_level_report_status": "ready",
    \\  "source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy": "evaluation-report-evaluation-report-policy.json",
    \\  "source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy_schema": "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy.v1",
    \\  "source_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy_status": "ready",
    \\  "source_policy_decision": "approve",
    \\  "source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_boundary": "evaluation-report-evaluation-report-application-boundary.json",
    \\  "source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_boundary_schema": "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary.v1",
    \\  "source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report": "evaluation-report-evaluation-report.json",
    \\  "source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_status": "ready",
    \\  "source_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_status": "applied",
    \\  "source_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_after_digest": "sha256:evaluation-report-evaluation-report-after",
    \\  "source_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_after_present": true,
    \\  "source_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_changes": ["reviewed local evaluation report evaluation report application"],
    \\  "source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy": "inherited-evaluation-report-evaluation-report-policy.json",
    \\  "source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy_schema": "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy.v1",
    \\  "source_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy_status": "ready",
    \\  "source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_boundary": "inherited-evaluation-report-evaluation-report-application-boundary.json",
    \\  "source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_boundary_schema": "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary.v1",
    \\  "source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report": "inherited-evaluation-report-evaluation-report.json",
    \\  "source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_status": "ready",
    \\  "source_consumption_report_application_boundary": "report-application-boundary.json",
    \\  "source_report_application_status": "applied",
    \\  "source_consumption_report": "consumption-report.json",
    \\  "source_consumption_report_status": "ready",
    \\  "source_ready_for_next_branch": true,
    \\  "source_mutation_authority": "none",
    \\  "source_evaluator_status": "ready",
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
    \\  "source_report_before_evidence": ["before source report evidence"],
    \\  "source_report_after_evidence": ["after source report evidence"],
    \\  "source_report_next_queries": ["inspect source report policy"],
    \\  "source_report_boundary_rules": ["record-only"],
    \\  "source_report_publication_channel_ids": ["local-json-artifact", "local-text-artifact", "solid-webui-readonly-view"],
    \\  "source_next_queries": ["inspect source report policy"],
    \\  "source_boundary_rules": ["record-only"],
    \\  "source_publication_channel_ids": ["local-json-artifact"],
    \\  "source_policy_rule_ids_from_report": ["agent-bounded-context"],
    \\  "source_consumption_scope_ids_from_report": ["bounded-agent-context"],
    \\  "source_application_checks": [{"name":"source-report-schema","status":"pass","detail":"supported"}],
    \\  "source_report_checks": [{"name":"source-evaluator-schema","status":"pass","detail":"supported"}],
    \\  "source_request_summary": [{"path":"source-request.json","class":"request_json","size_bytes":12,"sha256":"sha256:source-req","detected_role":"agent-readonly","redaction_posture":"redacted-bounded"}],
    \\  "source_support_evidence_summary": [{"path":"source-support.txt","class":"workbench_text","size_bytes":14,"sha256":"sha256:source-support","detected_role":"workbench-viewer","redaction_posture":"redacted-bounded"}],
    \\  "source_signal_summary": [{"id":"request-present","status":"observed","detail":"request present"}],
    \\  "source_blocked_findings": [],
    \\  "source_advisory_findings": [],
    \\  "evaluation_status": "ready",
    \\  "ready_for_next_branch": true,
    \\  "advisory_findings_count": 0,
    \\  "blocked_findings_count": 0,
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
    \\  "request_files": [{"path":"request.json","class":"request_json","size_bytes":10,"sha256":"sha256:req","detected_role":"agent-readonly","redaction_posture":"redacted-bounded"}],
    \\  "evidence_files": [{"path":"support.txt","class":"workbench_text","size_bytes":12,"sha256":"sha256:support","detected_role":"workbench-viewer","redaction_posture":"redacted-bounded"}],
    \\  "checks": [{"name":"source-policy-ready","status":"pass","detail":"ready"}],
    \\  "signal_evaluations": [{"id":"request-present","status":"observed","detail":"request present"}],
    \\  "findings": [],
    \\  "source_policy_rule_ids": ["rule-agent-readonly"],
    \\  "source_consumption_scope_ids": ["scope-agent-context"],
    \\  "denied_claims": ["no-app-runtime-integration"],
    \\  "next_queries": ["inspect-source-policy-rules"],
    \\  "agent_guidance": ["use bounded context only"]
    \\}
;

const sample_advisory_evaluator_json =
    \\{
    \\  "schema": "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator.v1",
    \\  "schema_version": 1,
    \\  "generated_by": "causal-app-facing-thirteen-level-evaluator",
    \\  "source_thirteen_level_policy": "app-facing-ci-thirteen-level-policy.json",
    \\  "source_thirteen_level_policy_schema": "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy.v1",
    \\  "source_thirteen_level_policy_status": "ready",
    \\  "source_thirteen_level_application_boundary": "app-facing-ci-thirteen-level-application-boundary.json",
    \\  "source_thirteen_level_application_boundary_schema": "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary.v1",
    \\  "source_thirteen_level_application_boundary_status": "applied",
    \\  "source_thirteen_level_report": "app-facing-ci-thirteen-level-report.json",
    \\  "source_thirteen_level_report_schema": "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report.v1",
    \\  "source_thirteen_level_report_status": "ready",
    \\  "source_thirteen_level_after_digest": "sha256:thirteen-after",
    \\  "source_thirteen_level_after_present": true,
    \\  "source_thirteen_level_application_changes": ["reviewed local thirteen-level application boundary"],
    \\  "source_twelve_level_evaluator": "app-facing-ci-twelve-level-evaluator.json",
    \\  "source_twelve_level_evaluator_schema": "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator.v1",
    \\  "source_twelve_level_evaluator_status": "ready",
    \\  "source_twelve_level_policy": "app-facing-ci-twelve-level-policy.json",
    \\  "source_twelve_level_policy_schema": "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy.v1",
    \\  "source_twelve_level_policy_status": "ready",
    \\  "source_twelve_level_application_boundary": "app-facing-ci-twelve-level-application-boundary.json",
    \\  "source_twelve_level_application_boundary_schema": "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary.v1",
    \\  "source_twelve_level_report": "app-facing-ci-twelve-level-report.json",
    \\  "source_twelve_level_report_schema": "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report.v1",
    \\  "source_twelve_level_report_status": "ready",
    \\  "source_twelve_level_after_digest": "sha256:twelve-after",
    \\  "source_twelve_level_after_present": true,
    \\  "source_twelve_level_application_changes": ["reviewed local twelve-level application boundary"],
    \\  "source_eleven_level_policy": "app-facing-ci-eleven-level-policy.json",
    \\  "source_eleven_level_policy_schema": "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy.v1",
    \\  "source_eleven_level_policy_status": "ready",
    \\  "source_eleven_level_application_boundary": "app-facing-ci-eleven-level-application-boundary.json",
    \\  "source_eleven_level_application_boundary_schema": "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary.v1",
    \\  "source_eleven_level_report": "app-facing-ci-eleven-level-report.json",
    \\  "source_eleven_level_report_schema": "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report.v1",
    \\  "source_eleven_level_report_status": "ready",
    \\  "source_eleven_level_after_digest": "sha256:eleven-after",
    \\  "source_eleven_level_after_present": true,
    \\  "source_eleven_level_application_changes": ["reviewed local eleven-level application boundary"],
    \\  "source_ten_level_policy": "app-facing-ci-ten-level-policy.json",
    \\  "source_ten_level_policy_schema": "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy.v1",
    \\  "source_ten_level_policy_status": "ready",
    \\  "source_ten_level_application_boundary": "app-facing-ci-ten-level-application-boundary.json",
    \\  "source_ten_level_application_boundary_schema": "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary.v1",
    \\  "source_ten_level_report": "app-facing-ci-ten-level-report.json",
    \\  "source_ten_level_report_schema": "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report.v1",
    \\  "source_ten_level_report_status": "ready",
    \\  "source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy": "evaluation-report-evaluation-report-policy.json",
    \\  "source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy_schema": "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy.v1",
    \\  "source_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy_status": "ready",
    \\  "source_policy_decision": "approve",
    \\  "source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_boundary": "evaluation-report-evaluation-report-application-boundary.json",
    \\  "source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_boundary_schema": "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary.v1",
    \\  "source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report": "evaluation-report-evaluation-report.json",
    \\  "source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_status": "ready",
    \\  "source_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_status": "applied",
    \\  "source_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_after_digest": "sha256:evaluation-report-evaluation-report-after",
    \\  "source_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_after_present": true,
    \\  "source_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_changes": ["reviewed local evaluation report evaluation report application"],
    \\  "source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy": "inherited-evaluation-report-evaluation-report-policy.json",
    \\  "source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy_schema": "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy.v1",
    \\  "source_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy_status": "ready",
    \\  "source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_boundary": "inherited-evaluation-report-evaluation-report-application-boundary.json",
    \\  "source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_boundary_schema": "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary.v1",
    \\  "source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report": "inherited-evaluation-report-evaluation-report.json",
    \\  "source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_status": "ready",
    \\  "source_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_status": "applied",
    \\  "source_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_changes": ["reviewed inherited local evaluation report evaluation report application"],
    \\  "source_consumption_report_application_boundary": "report-application-boundary.json",
    \\  "source_report_application_status": "applied",
    \\  "source_consumption_report": "consumption-report.json",
    \\  "source_consumption_report_status": "ready",
    \\  "source_ready_for_next_branch": true,
    \\  "source_mutation_authority": "none",
    \\  "source_evaluator_status": "advisory-findings",
    \\  "source_consumption_policy": "policy.json",
    \\  "source_consumption_boundary": "boundary.json",
    \\  "source_consumption_readiness": "readiness.json",
    \\  "source_publication_policy": "publication-policy.json",
    \\  "source_after_report_digest": "sha256:after",
    \\  "source_consumer_after_digest": "sha256:consumer",
    \\  "source_report_after_digest": "sha256:report-after",
    \\  "source_report_after_present": true,
    \\  "source_report_application_changes": ["reviewed advisory local report application"],
    \\  "source_before_evidence": ["before report evidence"],
    \\  "source_after_evidence": ["after report evidence"],
    \\  "source_report_before_evidence": ["before source report evidence"],
    \\  "source_report_after_evidence": ["after source report evidence"],
    \\  "source_report_next_queries": ["inspect source report policy"],
    \\  "source_report_boundary_rules": ["record-only"],
    \\  "source_report_publication_channel_ids": ["local-json-artifact", "local-text-artifact", "solid-webui-readonly-view"],
    \\  "source_next_queries": ["inspect advisory source report policy"],
    \\  "source_boundary_rules": ["record-only"],
    \\  "source_publication_channel_ids": ["local-json-artifact"],
    \\  "source_policy_rule_ids_from_report": ["agent-bounded-context"],
    \\  "source_consumption_scope_ids_from_report": ["bounded-agent-context"],
    \\  "source_application_checks": [{"name":"source-report-schema","status":"pass","detail":"supported"}],
    \\  "source_report_checks": [{"name":"source-evaluator-schema","status":"pass","detail":"supported"}],
    \\  "source_request_summary": [{"path":"source-request.json","class":"request_json","size_bytes":12,"sha256":"sha256:source-req","detected_role":"agent-readonly","redaction_posture":"redacted-bounded"}],
    \\  "source_support_evidence_summary": [{"path":"source-support.txt","class":"workbench_text","size_bytes":14,"sha256":"sha256:source-support","detected_role":"workbench-viewer","redaction_posture":"redacted-bounded"}],
    \\  "source_signal_summary": [{"id":"request-present","status":"observed","detail":"request present"}],
    \\  "source_blocked_findings": [],
    \\  "source_advisory_findings": [],
    \\  "evaluation_status": "advisory-findings",
    \\  "ready_for_next_branch": true,
    \\  "advisory_findings_count": 1,
    \\  "blocked_findings_count": 0,
    \\  "mutation_authority": "none",
    \\  "ci_gate_enabled": false, "ci_gate_enforcement_enabled": false, "ci_required_status_check_enabled": false, "ci_workflow_mutation_enabled": false,
    \\  "ci_upload_execution_enabled": false, "ci_report_publication_enabled": false, "github_step_summary_write_enabled": false, "pull_request_comment_enabled": false,
    \\  "github_api_mutation_enabled": false, "app_mutation_controls_enabled": false, "app_mutation_enabled": false, "app_config_write_enabled": false,
    \\  "app_data_write_enabled": false, "app_runtime_integration_enabled": false, "agent_query_live_projection_enabled": false, "raw_payload_capture_enabled": false,
    \\  "deployment_mutation_enabled": false, "production_telemetry_ingestion": false, "live_exporter_enabled": false, "network_send_enabled": false,
    \\  "collector_endpoint_configured": false, "otlp_serialization_enabled": false, "runtime_pipeline_enabled": false, "durable_write_enabled": false,
    \\  "nendb_write_enabled": false, "nendb_adapter_execution_enabled": false,
    \\  "public_artifact_upload_enabled": false,
    \\  "hosted_live_dashboard_enabled": false,
    \\  "production_health_claim_enabled": false,
    \\  "auto_apply_enabled": false,
    \\  "advisory_report": true, "read_only_preview": true, "read_only_consumption_enabled": true, "solid_webui_enabled": true,
    \\  "solid_webui_renderer": "solidjs", "webui_bridge": "webui-dev/zig-webui",
    \\  "request_files": [{"path":"request.json","class":"request_json","size_bytes":10,"sha256":"sha256:req","redaction_posture":"redacted-bounded"}],
    \\  "evidence_files": [],
    \\  "checks": [{"name":"request-files-present","status":"pass","detail":"ready"}],
    \\  "signal_evaluations": [{"id":"support-evidence-present","status":"missing","detail":"support evidence missing"}],
    \\  "findings": [{"id":"support-evidence-present","severity":"advisory","signal":"support-evidence-present","detail":"support evidence missing"}],
    \\  "source_policy_rule_ids": ["rule-agent-readonly"],
    \\  "source_consumption_scope_ids": ["scope-agent-context"],
    \\  "denied_claims": ["no-app-runtime-integration"],
    \\  "next_queries": ["inspect-source-policy-rules"],
    \\  "agent_guidance": ["use bounded context only"]
    \\}
;

const sample_blocked_evaluator_json =
    \\{
    \\  "schema": "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator.v1",
    \\  "schema_version": 1,
    \\  "source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy": "evaluation-report-evaluation-report-policy.json",
    \\  "source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy_schema": "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy.v1",
    \\  "source_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy_status": "ready",
    \\  "source_policy_decision": "approve",
    \\  "source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_boundary": "evaluation-report-evaluation-report-application-boundary.json",
    \\  "source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_boundary_schema": "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary.v1",
    \\  "source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report": "evaluation-report-evaluation-report.json",
    \\  "source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_status": "ready",
    \\  "source_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_status": "applied",
    \\  "source_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_after_digest": "sha256:evaluation-report-evaluation-report-after",
    \\  "source_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_after_present": true,
    \\  "source_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_changes": ["reviewed local evaluation report evaluation report application"],
    \\  "source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy": "inherited-evaluation-report-evaluation-report-policy.json",
    \\  "source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy_schema": "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy.v1",
    \\  "source_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy_status": "ready",
    \\  "source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_boundary": "inherited-evaluation-report-evaluation-report-application-boundary.json",
    \\  "source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_boundary_schema": "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary.v1",
    \\  "source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report": "inherited-evaluation-report-evaluation-report.json",
    \\  "source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_status": "ready",
    \\  "source_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_status": "applied",
    \\  "source_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_changes": ["reviewed inherited local evaluation report evaluation report application"],
    \\  "source_consumption_report_application_boundary": "report-application-boundary.json",
    \\  "source_report_application_status": "applied",
    \\  "source_consumption_report": "consumption-report.json",
    \\  "source_consumption_report_status": "blocked",
    \\  "source_ready_for_next_branch": false,
    \\  "source_mutation_authority": "none",
    \\  "source_evaluator_status": "blocked",
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
    \\  "source_report_before_evidence": ["before source report evidence"],
    \\  "source_report_after_evidence": ["after source report evidence"],
    \\  "source_report_next_queries": ["inspect source report policy"],
    \\  "source_report_boundary_rules": ["record-only"],
    \\  "source_report_publication_channel_ids": ["local-json-artifact", "local-text-artifact", "solid-webui-readonly-view"],
    \\  "source_next_queries": ["inspect blocked source report policy"],
    \\  "source_boundary_rules": ["record-only"],
    \\  "source_publication_channel_ids": ["local-json-artifact"],
    \\  "source_policy_rule_ids_from_report": ["agent-bounded-context"],
    \\  "source_consumption_scope_ids_from_report": ["bounded-agent-context"],
    \\  "source_application_checks": [{"name":"source-report-schema","status":"pass","detail":"supported"}],
    \\  "source_report_checks": [{"name":"source-evaluator-schema","status":"pass","detail":"supported"}],
    \\  "source_request_summary": [{"path":"source-request.json","class":"request_json","size_bytes":12,"sha256":"sha256:source-req","detected_role":"agent-readonly","redaction_posture":"redacted-bounded"}],
    \\  "source_support_evidence_summary": [{"path":"source-support.txt","class":"workbench_text","size_bytes":14,"sha256":"sha256:source-support","detected_role":"workbench-viewer","redaction_posture":"redacted-bounded"}],
    \\  "source_signal_summary": [{"id":"request-present","status":"observed","detail":"request present"}],
    \\  "source_blocked_findings": [],
    \\  "source_advisory_findings": [],
    \\  "evaluation_status": "blocked",
    \\  "ready_for_next_branch": false,
    \\  "advisory_findings_count": 1,
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
    \\  "request_files": [{"path":"request-unsafe.json","class":"request_json","size_bytes":10,"sha256":"sha256:req","redaction_posture":"blocked","denied_reason":"app runtime integration must remain disabled"}],
    \\  "evidence_files": [],
    \\  "checks": [{"name":"request-boundary","status":"fail","detail":"blocked"}],
    \\  "signal_evaluations": [{"id":"request-present","status":"blocked","detail":"safe request missing"}],
    \\  "findings": [{"id":"request-denied","severity":"blocked","signal":"request-boundary","detail":"app runtime integration must remain disabled"}],
    \\  "source_policy_rule_ids": ["rule-agent-readonly"],
    \\  "source_consumption_scope_ids": ["scope-agent-context"],
    \\  "denied_claims": ["no-app-runtime-integration"],
    \\  "next_queries": ["inspect-source-policy-rules"],
    \\  "agent_guidance": ["repair blocked source"]
    \\}
;

const sample_authority_violation_evaluator_json =
    \\{
    \\  "schema": "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator.v1",
    \\  "schema_version": 1,
    \\  "source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy": "evaluation-report-evaluation-report-policy.json",
    \\  "source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy_schema": "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy.v1",
    \\  "source_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy_status": "ready",
    \\  "source_policy_decision": "approve",
    \\  "source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_boundary": "evaluation-report-evaluation-report-application-boundary.json",
    \\  "source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_boundary_schema": "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary.v1",
    \\  "source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report": "evaluation-report-evaluation-report.json",
    \\  "source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_status": "ready",
    \\  "source_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_status": "applied",
    \\  "source_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_after_digest": "sha256:evaluation-report-evaluation-report-after",
    \\  "source_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_after_present": true,
    \\  "source_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_changes": ["reviewed local evaluation report evaluation report application"],
    \\  "source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy": "inherited-evaluation-report-evaluation-report-policy.json",
    \\  "source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy_schema": "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy.v1",
    \\  "source_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy_status": "ready",
    \\  "source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_boundary": "inherited-evaluation-report-evaluation-report-application-boundary.json",
    \\  "source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_boundary_schema": "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary.v1",
    \\  "source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report": "inherited-evaluation-report-evaluation-report.json",
    \\  "source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_status": "ready",
    \\  "source_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_status": "applied",
    \\  "source_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_changes": ["reviewed inherited local evaluation report evaluation report application"],
    \\  "source_consumption_report_application_boundary": "report-application-boundary.json",
    \\  "source_report_application_status": "applied",
    \\  "source_consumption_report": "consumption-report.json",
    \\  "source_consumption_report_status": "ready",
    \\  "source_ready_for_next_branch": true,
    \\  "source_mutation_authority": "none",
    \\  "source_evaluator_status": "ready",
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
    \\  "source_report_before_evidence": ["before source report evidence"],
    \\  "source_report_after_evidence": ["after source report evidence"],
    \\  "source_report_next_queries": ["inspect source report policy"],
    \\  "source_report_boundary_rules": ["record-only"],
    \\  "source_report_publication_channel_ids": ["local-json-artifact", "local-text-artifact", "solid-webui-readonly-view"],
    \\  "source_next_queries": ["inspect authority source report policy"],
    \\  "source_boundary_rules": ["record-only"],
    \\  "source_publication_channel_ids": ["local-json-artifact"],
    \\  "source_policy_rule_ids_from_report": ["agent-bounded-context"],
    \\  "source_consumption_scope_ids_from_report": ["bounded-agent-context"],
    \\  "source_application_checks": [{"name":"source-report-schema","status":"pass","detail":"supported"}],
    \\  "source_report_checks": [{"name":"source-evaluator-schema","status":"pass","detail":"supported"}],
    \\  "source_request_summary": [{"path":"source-request.json","class":"request_json","size_bytes":12,"sha256":"sha256:source-req","detected_role":"agent-readonly","redaction_posture":"redacted-bounded"}],
    \\  "source_support_evidence_summary": [{"path":"source-support.txt","class":"workbench_text","size_bytes":14,"sha256":"sha256:source-support","detected_role":"workbench-viewer","redaction_posture":"redacted-bounded"}],
    \\  "source_signal_summary": [{"id":"request-present","status":"observed","detail":"request present"}],
    \\  "source_blocked_findings": [],
    \\  "source_advisory_findings": [],
    \\  "evaluation_status": "ready",
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
    \\  "request_files": [{"path":"request.json","class":"request_json","size_bytes":10,"sha256":"sha256:req","redaction_posture":"redacted-bounded"}],
    \\  "checks": [{"name":"source-policy-ready","status":"pass","detail":"ready"}],
    \\  "signal_evaluations": [{"id":"request-present","status":"observed","detail":"request present"}],
    \\  "source_policy_rule_ids": ["rule-agent-readonly"],
    \\  "source_consumption_scope_ids": ["scope-agent-context"],
    \\  "denied_claims": ["no-app-runtime-integration"],
    \\  "next_queries": ["inspect-source-policy-rules"],
    \\  "agent_guidance": ["use bounded context only"]
    \\}
;
