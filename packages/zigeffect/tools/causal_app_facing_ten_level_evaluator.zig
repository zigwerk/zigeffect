const std = @import("std");

pub const schema = "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator.v1";
pub const schema_version: u32 = 1;
pub const source_branch = "codex/zigeffect-causal-app-facing-ten-level-evaluator";
pub const recommendation = "start-app-facing-eleven-level-report";
pub const next_branch_if_ready = "codex/zigeffect-causal-app-facing-eleven-level-report";

const source_policy_schema = "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy.v1";
const generated_by = "causal-app-facing-ten-level-evaluator";
const source_policy_suffix = "-ci-ten-level-policy.json";
const output_prefix_suffix = "-ci-ten-level-evaluator";
const compact_output_prefix_name = "app-facing-ci-ten-level-evaluator";
const max_default_output_file_name_len = 240;
const max_input_files = 32;
const max_input_bytes = 1024 * 1024;

const required_verification_commands: []const []const u8 = &.{
    "bun run zigeffect:workbench:typecheck",
    "bun run zigeffect:workbench:test",
    "zig build causal-app-facing-ten-level-policy -- --help",
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
const mutation_authority = "none";

const EvaluationStatus = enum { ready, advisory_findings, blocked };
const SignalStatus = enum { observed, missing, blocked };
const CheckStatus = enum { pass, fail };
const FileClass = enum { request_json, request_text, policy_json, causal_json, causal_text, workbench_text, denied };

const Options = struct {
    policy_path: []const u8,
    reason: []const u8,
    reviewed_by: []const u8 = "app-facing-ten-level-evaluator-reviewer",
    policy: []const u8 = "manual-app-facing-ten-level-evaluator",
    request_paths: []const []const u8 = &.{},
    evidence_paths: []const []const u8 = &.{},
    out_prefix: ?[]const u8 = null,

    fn deinit(self: Options, allocator: std.mem.Allocator) void {
        freeSliceOnly(allocator, self.request_paths);
        freeSliceOnly(allocator, self.evidence_paths);
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

const FileInput = struct {
    path: []const u8,
    contents: []const u8,
};

const EvaluatorInput = struct {
    options: Options,
    source_policy_json: []const u8,
    request_inputs: []const FileInput,
    evidence_inputs: []const FileInput,
};

const EvaluatorReports = struct {
    json: []const u8,
    text: []const u8,

    fn deinit(self: EvaluatorReports, allocator: std.mem.Allocator) void {
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

const InterpretationRule = struct {
    id: []const u8,
    consumer_role: []const u8 = "",
    allowed_use: []const u8 = "",
    failure_effect: []const u8 = "",
    denied_claim: []const u8 = "",
};

const ConsumptionScope = struct {
    id: []const u8,
    visibility_class: []const u8 = "",
    executed_by_tool: bool = false,
    mutation_authority: []const u8 = "",
    interpretation_scope: []const u8 = "",
};

const NegativeFixture = struct {
    id: []const u8 = "",
    artifact_state: []const u8 = "",
    decision: []const u8 = "",
    failed_gate: []const u8 = "",
    reason: []const u8 = "",
};

const SourcePublicationChannel = struct {
    id: []const u8 = "",
    allowed: bool = false,
    executed_by_tool: bool = false,
    detail: []const u8 = "",
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

const SourcePolicyArtifact = struct {
    schema: []const u8,
    schema_version: u32,
    decision: []const u8,
    consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy_status: []const u8,
    ready_for_next_branch: bool,
    mutation_authority: []const u8,
    source_ten_level_application_boundary: []const u8 = "",
    source_ten_level_application_boundary_schema: []const u8 = "",
    source_ten_level_report: []const u8 = "",
    source_ten_level_report_schema: []const u8 = "",
    source_ten_level_report_status: []const u8 = "",
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
    source_eight_level_application_status: []const u8 = "",
    source_eight_level_after_digest: []const u8 = "",
    source_eight_level_after_present: bool = false,
    source_eight_level_application_changes: []const []const u8 = &.{},
    source_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_status: []const u8 = "",
    source_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_after_digest: []const u8 = "",
    source_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_after_present: bool = false,
    source_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_changes: []const []const u8 = &.{},
    source_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_status: []const u8 = "",
    source_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_after_digest: []const u8 = "",
    source_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_after_present: bool = false,
    source_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_changes: []const []const u8 = &.{},
    source_inherited_policy: []const u8 = "",
    source_inherited_policy_schema: []const u8 = "",
    source_inherited_policy_status: []const u8 = "",
    source_inherited_application_boundary: []const u8 = "",
    source_inherited_application_boundary_schema: []const u8 = "",
    source_inherited_report: []const u8 = "",
    source_inherited_report_status: []const u8 = "",
    source_inherited_application_status: []const u8 = "",
    source_inherited_application_changes: []const []const u8 = &.{},
    source_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_status: []const u8 = "",
    source_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_after_digest: []const u8 = "",
    source_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_after_present: bool = false,
    source_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_changes: []const []const u8 = &.{},
    source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_boundary: []const u8 = "",
    source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_boundary_schema: []const u8 = "",
    source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report: []const u8 = "",
    source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_status: []const u8 = "",
    source_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_status: []const u8 = "",
    source_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_after_digest: []const u8 = "",
    source_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_after_present: bool = false,
    source_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_changes: []const []const u8 = &.{},
    source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy: []const u8 = "",
    source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy_schema: []const u8 = "",
    source_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy_status: []const u8 = "",
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
    source_consumption_report_application_boundary_schema: []const u8 = "",
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
    source_application_checks: []const SourceCheck = &.{},
    source_report_checks: []const SourceCheck = &.{},
    source_request_summary: []const SourceFile = &.{},
    source_support_evidence_summary: []const SourceFile = &.{},
    source_signal_summary: []const SourceSignal = &.{},
    source_blocked_findings: []const SourceFinding = &.{},
    source_advisory_findings: []const SourceFinding = &.{},
    source_policy_rule_ids: []const []const u8 = &.{},
    source_consumption_scope_ids: []const []const u8 = &.{},
    source_denied_claims: []const []const u8 = &.{},
    source_next_queries: []const []const u8 = &.{},
    source_publication_channels: []const SourcePublicationChannel = &.{},
    source_boundary_rules: []const []const u8 = &.{},
    source_denied_application_claims: []const []const u8 = &.{},
    source_negative_fixtures: []const NegativeFixture = &.{},
    policy_checks: []const SourceCheck = &.{},
    interpretation_rules: []const InterpretationRule = &.{},
    consumption_scopes: []const ConsumptionScope = &.{},
    denied_inference_rules: []const []const u8 = &.{},
    negative_fixtures: []const NegativeFixture = &.{},
    required_verification_commands: []const []const u8 = &.{},
    verified_commands: []const []const u8 = &.{},
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
};

const GenericArtifact = struct {
    schema: []const u8 = "",
    schema_version: u32 = 0,
};

const FileAnalysis = struct {
    path: []const u8,
    class: FileClass,
    size_bytes: usize,
    sha256: []const u8,
    detected_schema: []const u8,
    detected_role: []const u8,
    redaction_posture: []const u8,
    denied_reason: []const u8 = "",

    fn deinit(self: FileAnalysis, allocator: std.mem.Allocator) void {
        allocator.free(self.sha256);
        allocator.free(self.detected_schema);
    }
};

const FileSetAnalysis = struct {
    files: []const FileAnalysis,

    fn deinit(self: FileSetAnalysis, allocator: std.mem.Allocator) void {
        for (self.files) |file| file.deinit(allocator);
        if (self.files.len > 0) allocator.free(self.files);
    }
};

const EvaluationCheck = struct {
    name: []const u8,
    status: CheckStatus,
    detail: []const u8,
};

const SignalEvaluation = struct {
    id: []const u8,
    status: SignalStatus,
    detail: []const u8,
    evidence_path: []const u8 = "",
};

const Finding = struct {
    id: []const u8,
    severity: []const u8,
    signal: []const u8,
    detail: []const u8,
    evidence_path: []const u8 = "",
};

const EvaluationResult = struct {
    status: EvaluationStatus,
    ready_for_next_branch: bool,
    blocked_findings_count: usize,
    advisory_findings_count: usize,
    checks: []const EvaluationCheck,
    signal_evaluations: []const SignalEvaluation,
    findings: []const Finding,

    fn deinit(self: EvaluationResult, allocator: std.mem.Allocator) void {
        if (self.checks.len > 0) allocator.free(self.checks);
        if (self.signal_evaluations.len > 0) allocator.free(self.signal_evaluations);
        if (self.findings.len > 0) allocator.free(self.findings);
    }
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
        error.MissingPolicyInput, error.MissingRequestInput => failUsage(err),
        else => return err,
    };
}

fn parseOptions(allocator: std.mem.Allocator, args: []const []const u8) !Options {
    if (args.len < 2) return error.MissingPolicyPath;
    if (!std.mem.eql(u8, args[1], "--from-policy")) return error.UnknownFlag;
    if (args.len < 3) return error.MissingPolicyPath;
    const policy_path = args[2];
    if (!std.mem.endsWith(u8, policy_path, ".json")) return error.InvalidPolicyPath;
    if (args.len < 4) return error.MissingCommand;
    if (!std.mem.eql(u8, args[3], "evaluate")) return error.UnknownCommand;

    var reviewed_by: []const u8 = "app-facing-ten-level-evaluator-reviewer";
    var policy: []const u8 = "manual-app-facing-ten-level-evaluator";
    var reason: ?[]const u8 = null;
    var request_paths = std.ArrayList([]const u8).empty;
    var evidence_paths = std.ArrayList([]const u8).empty;
    var out_prefix: ?[]const u8 = null;
    errdefer request_paths.deinit(allocator);
    errdefer evidence_paths.deinit(allocator);

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
        } else if (std.mem.eql(u8, flag, "--request")) {
            if (!pathExtensionSupported(value)) return error.InvalidRequestPath;
            try request_paths.append(allocator, value);
        } else if (std.mem.eql(u8, flag, "--evidence")) {
            if (!pathExtensionSupported(value)) return error.InvalidEvidencePath;
            try evidence_paths.append(allocator, value);
        } else if (std.mem.eql(u8, flag, "--out-prefix")) {
            out_prefix = value;
        } else {
            return error.UnknownFlag;
        }
        index += 2;
    }

    const final_reason = reason orelse return error.MissingReason;
    if (final_reason.len == 0) return error.MissingReason;
    if (request_paths.items.len == 0) return error.MissingRequestInput;
    if (request_paths.items.len + evidence_paths.items.len > max_input_files) return error.TooManyInputFiles;

    return .{
        .policy_path = policy_path,
        .reason = final_reason,
        .reviewed_by = reviewed_by,
        .policy = policy,
        .request_paths = try request_paths.toOwnedSlice(allocator),
        .evidence_paths = try evidence_paths.toOwnedSlice(allocator),
        .out_prefix = out_prefix,
    };
}

fn pathExtensionSupported(path: []const u8) bool {
    return std.mem.endsWith(u8, path, ".json") or std.mem.endsWith(u8, path, ".txt");
}

fn defaultOutputPaths(allocator: std.mem.Allocator, policy_path: []const u8) !OutputPaths {
    const prefix = try defaultOutputPrefix(allocator, policy_path);
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
        try defaultOutputPrefix(allocator, options.policy_path);
    defer allocator.free(prefix);

    return .{
        .json_path = try std.fmt.allocPrint(allocator, "{s}.json", .{prefix}),
        .text_path = try std.fmt.allocPrint(allocator, "{s}.txt", .{prefix}),
    };
}

fn defaultOutputPrefix(allocator: std.mem.Allocator, policy_path: []const u8) ![]const u8 {
    if (!std.mem.endsWith(u8, policy_path, ".json")) return error.InvalidPolicyPath;

    const base = if (std.mem.endsWith(u8, policy_path, source_policy_suffix))
        policy_path[0 .. policy_path.len - source_policy_suffix.len]
    else
        policy_path[0 .. policy_path.len - ".json".len];
    const candidate = try std.fmt.allocPrint(allocator, "{s}{s}", .{ base, output_prefix_suffix });
    errdefer allocator.free(candidate);

    if (fileName(candidate).len + ".json".len <= max_default_output_file_name_len) {
        return candidate;
    }

    const directory = directoryPrefix(candidate);
    const digest = shortPathDigest(policy_path);
    const compact_prefix = try std.fmt.allocPrint(allocator, "{s}{s}-{s}", .{ directory, compact_output_prefix_name, digest[0..] });
    allocator.free(candidate);
    return compact_prefix;
}

fn formatReports(allocator: std.mem.Allocator, input: EvaluatorInput) !EvaluatorReports {
    var parsed = try std.json.parseFromSlice(SourcePolicyArtifact, allocator, input.source_policy_json, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();

    const paths = try outputPathsForOptions(allocator, input.options);
    defer paths.deinit(allocator);

    const request_analysis = try analyzeFiles(allocator, input.request_inputs);
    defer request_analysis.deinit(allocator);
    const evidence_analysis = try analyzeFiles(allocator, input.evidence_inputs);
    defer evidence_analysis.deinit(allocator);

    const result = try evaluatePolicyAndFiles(allocator, parsed.value, request_analysis, evidence_analysis);
    defer result.deinit(allocator);

    const json = try formatEvaluatorJson(allocator, input.options, parsed.value, request_analysis, evidence_analysis, result, paths);
    errdefer allocator.free(json);
    const text = try formatEvaluatorText(allocator, input.options, parsed.value, request_analysis, evidence_analysis, result, paths);
    errdefer allocator.free(text);

    return .{ .json = json, .text = text };
}

fn analyzeFiles(allocator: std.mem.Allocator, inputs: []const FileInput) !FileSetAnalysis {
    if (inputs.len > max_input_files) return error.TooManyInputFiles;
    var files = std.ArrayList(FileAnalysis).empty;
    errdefer {
        for (files.items) |file| file.deinit(allocator);
        files.deinit(allocator);
    }

    for (inputs) |input| {
        if (input.contents.len > max_input_bytes) return error.InputTooLarge;
        const sha = try sha256Digest(allocator, input.contents);
        errdefer allocator.free(sha);
        const detected_schema = try detectJsonSchema(allocator, input.path, input.contents);
        errdefer allocator.free(detected_schema);
        const class = classifyFile(input.path, input.contents, detected_schema);
        const denied_reason = fileDeniedReason(input.path, input.contents, class);

        try files.append(allocator, .{
            .path = input.path,
            .class = class,
            .size_bytes = input.contents.len,
            .sha256 = sha,
            .detected_schema = detected_schema,
            .detected_role = detectRole(input.contents),
            .redaction_posture = redactionPosture(input.contents, denied_reason),
            .denied_reason = denied_reason,
        });
    }

    return .{ .files = try files.toOwnedSlice(allocator) };
}

fn classifyFile(path: []const u8, contents: []const u8, detected_schema: []const u8) FileClass {
    const bounded = std.mem.indexOf(u8, path, ".zig-cache/causal-artifacts/") != null;
    const is_json = std.mem.endsWith(u8, path, ".json");
    const is_txt = std.mem.endsWith(u8, path, ".txt");
    if (!bounded or (!is_json and !is_txt)) return .denied;

    if (is_json and (std.mem.indexOf(u8, path, "ten-level-policy") != null or std.mem.indexOf(u8, path, "consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy") != null or std.mem.eql(u8, detected_schema, source_policy_schema))) return .policy_json;
    if (is_json and (std.mem.indexOf(u8, path, "request") != null or std.mem.indexOf(u8, contents, "\"request_id\"") != null or std.mem.indexOf(u8, contents, "\"consumer_role\"") != null)) return .request_json;
    if (is_txt and (std.mem.indexOf(u8, contents, "webui-dev/zig-webui") != null or std.mem.indexOf(u8, contents, "SolidJS") != null)) return .workbench_text;
    if (is_txt and (std.mem.indexOf(u8, path, "request") != null or std.mem.indexOf(u8, contents, "consumer_role") != null or std.mem.indexOf(u8, contents, "request_id") != null)) return .request_text;
    if (is_json and std.mem.startsWith(u8, detected_schema, "zigeffect.causal.")) return .causal_json;
    if (is_txt) return .causal_text;
    return .denied;
}

fn fileDeniedReason(path: []const u8, contents: []const u8, class: FileClass) []const u8 {
    if (class == .denied) return "input path must be JSON or text under .zig-cache/causal-artifacts";
    if (std.mem.indexOf(u8, contents, "secrets.") != null) return "secret-shaped reference marker is not valid consumption report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluator input";
    if (std.mem.indexOf(u8, contents, "PRODUCTION_") != null) return "production secret-shaped environment marker is not valid consumption report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluator input";
    if (std.mem.indexOf(u8, contents, "BEGIN PRIVATE KEY") != null) return "private key material is not valid consumption report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluator input";
    if (std.mem.indexOf(u8, contents, "Authorization:") != null) return "authorization header material is not valid consumption report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluator input";
    if (std.mem.indexOf(u8, contents, "sk-") != null) return "OpenAI-style secret token marker is not valid consumption report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluator input";
    if (std.mem.indexOf(u8, contents, "ghp_") != null) return "GitHub token marker is not valid consumption report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluator input";
    if (std.mem.indexOf(u8, contents, "xoxb-") != null) return "Slack token marker is not valid consumption report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluator input";
    if (std.mem.indexOf(u8, contents, "\"raw_prompt\"") != null) return "raw prompt capture is not valid consumption report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluator input";
    if (std.mem.indexOf(u8, contents, "\"raw_response\"") != null) return "raw response capture is not valid consumption report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluator input";
    if (jsonBoolTrue(contents, "raw_payload_capture_enabled")) return "raw payload capture must remain disabled";
    if (jsonBoolTrue(contents, "ci_gate_enforcement_enabled")) return "CI enforcement must remain disabled";
    if (jsonBoolTrue(contents, "ci_required_status_check_enabled")) return "required status checks must remain disabled";
    if (jsonBoolTrue(contents, "ci_workflow_mutation_enabled")) return "workflow mutation must remain disabled";
    if (jsonBoolTrue(contents, "github_api_mutation_enabled")) return "GitHub API mutation must remain disabled";
    if (jsonBoolTrue(contents, "app_mutation_enabled")) return "app mutation must remain disabled";
    if (jsonBoolTrue(contents, "app_runtime_integration_enabled")) return "app runtime integration must remain disabled";
    if (jsonBoolTrue(contents, "agent_query_live_projection_enabled")) return "live agent projection must remain disabled";
    if (jsonBoolTrue(contents, "durable_write_enabled")) return "durable writes must remain disabled";
    if (jsonBoolTrue(contents, "nendb_write_enabled")) return "NenDB writes must remain disabled";
    if (jsonBoolTrue(contents, "nendb_adapter_execution_enabled")) return "NenDB adapter execution must remain disabled";
    if (jsonBoolTrue(contents, "public_artifact_upload_enabled")) return "public artifact upload must remain disabled";
    if (jsonBoolTrue(contents, "hosted_live_dashboard_enabled")) return "hosted live dashboards must remain disabled";
    if (jsonBoolTrue(contents, "production_health_claim_enabled")) return "production health claims must remain disabled";
    if (jsonBoolTrue(contents, "auto_apply_enabled")) return "auto-apply must remain disabled";
    if (std.mem.indexOf(u8, contents, "cockroach") != null) return "Cockroach scope is not valid consumption report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluator input";
    if (std.mem.indexOf(u8, contents, "deployment success") != null or jsonBoolTrue(contents, "deployment_mutation_enabled")) return "deployment claims are not valid consumption report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluator input";
    if (std.mem.indexOf(u8, contents, "production health") != null or std.mem.indexOf(u8, contents, "production_health") != null) return "production health claims are not valid consumption report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluator input";
    if (std.mem.indexOf(u8, contents, "renderer=react") != null or std.mem.indexOf(u8, contents, "\"renderer\": \"react\"") != null) return "SolidJS inside webui-dev/zig-webui remains the renderer direction";
    if (std.mem.indexOf(u8, contents, "auto-apply") != null or std.mem.indexOf(u8, contents, "auto_apply") != null) return "auto-apply claims are not valid consumption report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluator input";
    if (std.mem.indexOf(u8, contents, "\"mutation_authority\": \"granted\"") != null) return "mutation authority must remain none";
    if (std.mem.indexOf(u8, contents, "artifact_visibility=public") != null) return "public artifact upload claims are not valid consumption report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluator input";
    _ = path;
    return "";
}

fn jsonBoolTrue(contents: []const u8, field: []const u8) bool {
    var spaced: [256]u8 = undefined;
    var compact: [256]u8 = undefined;
    const spaced_pattern = std.fmt.bufPrint(&spaced, "\"{s}\": true", .{field}) catch return false;
    const compact_pattern = std.fmt.bufPrint(&compact, "\"{s}\":true", .{field}) catch return false;
    return std.mem.indexOf(u8, contents, spaced_pattern) != null or
        std.mem.indexOf(u8, contents, compact_pattern) != null;
}

fn detectRole(contents: []const u8) []const u8 {
    if (std.mem.indexOf(u8, contents, "agent-readonly") != null or std.mem.indexOf(u8, contents, "agent") != null) return "agent-readonly";
    if (std.mem.indexOf(u8, contents, "workbench") != null or std.mem.indexOf(u8, contents, "webui-dev/zig-webui") != null) return "workbench-viewer";
    if (std.mem.indexOf(u8, contents, "ci-advisory") != null) return "ci-advisory-reader";
    if (std.mem.indexOf(u8, contents, "reviewer") != null or std.mem.indexOf(u8, contents, "maintainer") != null) return "maintainer";
    return "unspecified";
}

fn redactionPosture(contents: []const u8, denied_reason: []const u8) []const u8 {
    if (denied_reason.len > 0) return "blocked";
    if (std.mem.indexOf(u8, contents, "redacted") != null or std.mem.indexOf(u8, contents, "redaction") != null) return "redacted-bounded";
    return "bounded-unspecified";
}

fn evaluatePolicyAndFiles(
    allocator: std.mem.Allocator,
    source: SourcePolicyArtifact,
    requests: FileSetAnalysis,
    evidence: FileSetAnalysis,
) !EvaluationResult {
    var checks = std.ArrayList(EvaluationCheck).empty;
    var signals = std.ArrayList(SignalEvaluation).empty;
    var findings = std.ArrayList(Finding).empty;
    errdefer checks.deinit(allocator);
    errdefer signals.deinit(allocator);
    errdefer findings.deinit(allocator);

    try appendCheckAndFinding(allocator, &checks, &findings, "source-report-policy-schema", sourceSchemaVersionSupported(source), "source-report-policy-valid", "source consumption report policy schema is supported");
    try appendCheckAndFinding(allocator, &checks, &findings, "source-report-policy-ready", std.mem.eql(u8, source.consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy_status, "ready"), "source-report-policy-valid", "source consumption report policy status is ready");
    try appendCheckAndFinding(allocator, &checks, &findings, "source-ready-for-next-branch", source.ready_for_next_branch, "source-report-policy-valid", "source consumption report policy is ready for evaluator handoff");
    try appendCheckAndFinding(allocator, &checks, &findings, "source-review-approved", std.mem.eql(u8, source.decision, "approve"), "source-report-policy-valid", "source consumption report policy review decision is approve");
    try appendCheckAndFinding(allocator, &checks, &findings, "source-mutation-authority-none", std.mem.eql(u8, source.mutation_authority, "none"), "source-report-policy-valid", "source mutation authority remains none");
    try appendCheckAndFinding(allocator, &checks, &findings, "source-refs-present", sourceRefsPresent(source), "source-report-policy-valid", "source report application policy boundary readiness publication and digest refs are present");
    try appendCheckAndFinding(allocator, &checks, &findings, "source-evidence-present", sourceEvidencePresent(source), "source-report-policy-valid", "source report application changes before after evidence denied claims next queries and publication channels are present");
    try appendCheckAndFinding(allocator, &checks, &findings, "source-report-policy-checks-passed", sourcePolicyChecksPass(source.policy_checks), "source-report-policy-valid", "source policy checks contain no failures");
    try appendCheckAndFinding(allocator, &checks, &findings, "source-catalogs-present", sourceCatalogsPresent(source), "source-report-policy-valid", "source interpretation rules scopes denied claims fixtures and verification catalogs are present");
    try appendCheckAndFinding(allocator, &checks, &findings, "source-authority-disabled", sourceAuthorityDisabled(source), "source-report-policy-valid", "source keeps CI GitHub app runtime storage deployment and adapter authority disabled");
    try appendCheckAndFinding(allocator, &checks, &findings, "source-solid-webui", sourceSolidWebuiValid(source), "source-report-policy-valid", "source remains SolidJS inside webui-dev/zig-webui with read-only consumption enabled");
    try appendCheckAndFinding(allocator, &checks, &findings, "request-files-present", requests.files.len > 0, "request-present", "explicit read-only report consumption request files are present");

    for (requests.files) |file| {
        if (file.denied_reason.len > 0) {
            try appendCheck(allocator, &checks, "request-boundary", .fail, file.denied_reason);
            try appendFinding(allocator, &findings, "request-denied", "blocked", "request-boundary", file.denied_reason, file.path);
        }
    }
    for (evidence.files) |file| {
        if (file.denied_reason.len > 0) {
            try appendCheck(allocator, &checks, "evidence-boundary", .fail, file.denied_reason);
            try appendFinding(allocator, &findings, "evidence-denied", "blocked", "evidence-boundary", file.denied_reason, file.path);
        }
    }

    const source_valid = checksForPrefixPass(checks.items, "source-");
    const request_safe = !filesHaveDenied(requests);
    const evidence_safe = !filesHaveDenied(evidence);
    const has_request = requests.files.len > 0 and request_safe;
    const has_support_evidence = evidenceHasSupport(evidence);
    const redaction_bounded = filesRedactionBounded(requests) and (evidence.files.len == 0 or filesRedactionBounded(evidence));

    try appendSignal(allocator, &signals, &findings, "source-report-policy-valid", if (source_valid) .observed else .blocked, if (source_valid) "source report policy is ready approved and non-mutating" else "source policy failed evaluator preconditions", "");
    try appendSignal(allocator, &signals, &findings, "request-present", if (has_request) .observed else .blocked, if (has_request) "safe read-only report consumption request is present" else "safe read-only report consumption request is missing", firstFilePath(requests));
    try appendSignal(allocator, &signals, &findings, "support-evidence-present", if (has_support_evidence) .observed else .missing, if (has_support_evidence) "support evidence is present" else "support evidence was not supplied", firstFilePath(evidence));
    try appendSignal(allocator, &signals, &findings, "policy-rules-present", if (source.interpretation_rules.len > 0 and source.consumption_scopes.len > 0) .observed else .blocked, "source policy rule and scope catalogs are present", "");
    try appendSignal(allocator, &signals, &findings, "denied-claims-present", if (sourceDeniedClaimsPresent(source)) .observed else .blocked, "source denied claims are available for carryover", "");
    try appendSignal(allocator, &signals, &findings, "redaction-posture-bounded", if (redaction_bounded and request_safe and evidence_safe) .observed else .blocked, if (redaction_bounded) "request and evidence stay in a bounded redaction posture" else "request or evidence lacks a bounded redaction posture", firstProblemFilePath(requests, evidence));

    const finding_slice = try findings.toOwnedSlice(allocator);
    errdefer allocator.free(finding_slice);
    const check_slice = try checks.toOwnedSlice(allocator);
    errdefer allocator.free(check_slice);
    const signal_slice = try signals.toOwnedSlice(allocator);
    errdefer allocator.free(signal_slice);

    const blocked_count = countFindings(finding_slice, "blocked");
    const advisory_count = countFindings(finding_slice, "advisory");
    const status: EvaluationStatus = if (blocked_count > 0)
        .blocked
    else if (advisory_count > 0)
        .advisory_findings
    else
        .ready;

    return .{
        .status = status,
        .ready_for_next_branch = status != .blocked,
        .blocked_findings_count = blocked_count,
        .advisory_findings_count = advisory_count,
        .checks = check_slice,
        .signal_evaluations = signal_slice,
        .findings = finding_slice,
    };
}

fn sourceSchemaVersionSupported(source: SourcePolicyArtifact) bool {
    return std.mem.eql(u8, source.schema, source_policy_schema) and source.schema_version == 1;
}

fn sourceRefsPresent(source: SourcePolicyArtifact) bool {
    return sourceTenLevelApplicationBoundary(source).len > 0 and
        sourceTenLevelApplicationBoundarySchema(source).len > 0 and
        sourceTenLevelReport(source).len > 0 and
        sourceTenLevelReportSchema(source).len > 0 and
        std.mem.eql(u8, sourceTenLevelReportStatus(source), "ready") and
        sourceNineLevelRefsPresent(source) and
        sourceEightLevelPolicy(source).len > 0 and
        sourceEightLevelPolicySchema(source).len > 0 and
        std.mem.eql(u8, sourceEightLevelPolicyStatus(source), "ready") and
        sourceEightLevelApplicationBoundary(source).len > 0 and
        sourceEightLevelApplicationBoundarySchema(source).len > 0 and
        std.mem.eql(u8, sourceEightLevelApplicationStatus(source), "applied") and
        sourceTenLevelAfterDigest(source).len > 0 and
        sourceTenLevelAfterPresent(source) and
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
        source.source_mutation_authority.len > 0 and
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

fn sourceNineLevelRefsPresent(source: SourcePolicyArtifact) bool {
    return source.source_nine_level_policy.len > 0 and
        source.source_nine_level_policy_schema.len > 0 and
        std.mem.eql(u8, source.source_nine_level_policy_status, "ready") and
        source.source_nine_level_application_boundary.len > 0 and
        source.source_nine_level_application_boundary_schema.len > 0 and
        source.source_nine_level_report.len > 0 and
        source.source_nine_level_report_schema.len > 0 and
        std.mem.eql(u8, source.source_nine_level_report_status, "ready");
}

fn sourceTenLevelApplicationBoundary(source: SourcePolicyArtifact) []const u8 {
    return source.source_ten_level_application_boundary;
}

fn sourceTenLevelApplicationBoundarySchema(source: SourcePolicyArtifact) []const u8 {
    return source.source_ten_level_application_boundary_schema;
}

fn sourceTenLevelReport(source: SourcePolicyArtifact) []const u8 {
    return source.source_ten_level_report;
}

fn sourceTenLevelReportSchema(source: SourcePolicyArtifact) []const u8 {
    return source.source_ten_level_report_schema;
}

fn sourceTenLevelReportStatus(source: SourcePolicyArtifact) []const u8 {
    return source.source_ten_level_report_status;
}

fn sourceEightLevelPolicy(source: SourcePolicyArtifact) []const u8 {
    return source.source_eight_level_policy;
}

fn sourceEightLevelPolicySchema(source: SourcePolicyArtifact) []const u8 {
    return source.source_eight_level_policy_schema;
}

fn sourceEightLevelPolicyStatus(source: SourcePolicyArtifact) []const u8 {
    return source.source_eight_level_policy_status;
}

fn sourceTenLevelAfterDigest(source: SourcePolicyArtifact) []const u8 {
    if (source.source_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_after_digest.len > 0) return source.source_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_after_digest;
    return source.source_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_after_digest;
}

fn sourceTenLevelAfterPresent(source: SourcePolicyArtifact) bool {
    return source.source_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_after_present or
        source.source_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_after_present;
}

fn sourceEightLevelApplicationBoundary(source: SourcePolicyArtifact) []const u8 {
    if (source.source_eight_level_application_boundary.len > 0) return source.source_eight_level_application_boundary;
    return source.source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_boundary;
}

fn sourceEightLevelApplicationBoundarySchema(source: SourcePolicyArtifact) []const u8 {
    if (source.source_eight_level_application_boundary_schema.len > 0) return source.source_eight_level_application_boundary_schema;
    return source.source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_boundary_schema;
}

fn sourceEightLevelApplicationStatus(source: SourcePolicyArtifact) []const u8 {
    if (source.source_eight_level_application_status.len > 0) return source.source_eight_level_application_status;
    if (source.source_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_status.len > 0) return source.source_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_status;
    return source.source_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_status;
}

fn sourceEightLevelAfterDigest(source: SourcePolicyArtifact) []const u8 {
    if (source.source_eight_level_after_digest.len > 0) return source.source_eight_level_after_digest;
    if (source.source_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_after_digest.len > 0) return source.source_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_after_digest;
    return source.source_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_after_digest;
}

fn sourceEightLevelAfterPresent(source: SourcePolicyArtifact) bool {
    return source.source_eight_level_after_present or
        source.source_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_after_present or
        source.source_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_after_present;
}

fn sourceEightLevelApplicationChanges(source: SourcePolicyArtifact) []const []const u8 {
    if (source.source_eight_level_application_changes.len > 0) return source.source_eight_level_application_changes;
    if (source.source_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_changes.len > 0) return source.source_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_changes;
    return source.source_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_changes;
}

fn sourceInheritedPolicy(source: SourcePolicyArtifact) []const u8 {
    if (source.source_inherited_policy.len > 0) return source.source_inherited_policy;
    if (source.source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy.len > 0) return source.source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy;
    return source.source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy;
}

fn sourceInheritedPolicySchema(source: SourcePolicyArtifact) []const u8 {
    if (source.source_inherited_policy_schema.len > 0) return source.source_inherited_policy_schema;
    if (source.source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy_schema.len > 0) return source.source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy_schema;
    return source.source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy_schema;
}

fn sourceInheritedPolicyStatus(source: SourcePolicyArtifact) []const u8 {
    if (source.source_inherited_policy_status.len > 0) return source.source_inherited_policy_status;
    if (source.source_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy_status.len > 0) return source.source_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy_status;
    return source.source_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy_status;
}

fn sourceInheritedApplicationBoundary(source: SourcePolicyArtifact) []const u8 {
    if (source.source_inherited_application_boundary.len > 0) return source.source_inherited_application_boundary;
    if (source.source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_boundary.len > 0) return source.source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_boundary;
    return source.source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_boundary;
}

fn sourceInheritedApplicationBoundarySchema(source: SourcePolicyArtifact) []const u8 {
    if (source.source_inherited_application_boundary_schema.len > 0) return source.source_inherited_application_boundary_schema;
    if (source.source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_boundary_schema.len > 0) return source.source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_boundary_schema;
    return source.source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_boundary_schema;
}

fn sourceInheritedReport(source: SourcePolicyArtifact) []const u8 {
    if (source.source_inherited_report.len > 0) return source.source_inherited_report;
    if (source.source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report.len > 0) return source.source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report;
    return source.source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report;
}

fn sourceInheritedReportStatus(source: SourcePolicyArtifact) []const u8 {
    if (source.source_inherited_report_status.len > 0) return source.source_inherited_report_status;
    if (source.source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_status.len > 0) return source.source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_status;
    return source.source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_status;
}

fn sourceInheritedApplicationStatus(source: SourcePolicyArtifact) []const u8 {
    if (source.source_inherited_application_status.len > 0) return source.source_inherited_application_status;
    if (source.source_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_status.len > 0) return source.source_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_status;
    return source.source_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_status;
}

fn sourceInheritedApplicationChanges(source: SourcePolicyArtifact) []const []const u8 {
    if (source.source_inherited_application_changes.len > 0) return source.source_inherited_application_changes;
    if (source.source_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_changes.len > 0) return source.source_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_changes;
    return source.source_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_changes;
}

fn sourceEvidencePresent(source: SourcePolicyArtifact) bool {
    return sourceEightLevelApplicationChanges(source).len > 0 and
        sourceInheritedApplicationChanges(source).len > 0 and
        source.source_before_evidence.len > 0 and
        source.source_after_evidence.len > 0 and
        source.source_report_application_changes.len > 0 and
        source.source_report_before_evidence.len > 0 and
        source.source_report_after_evidence.len > 0 and
        source.source_report_next_queries.len > 0 and
        source.source_report_boundary_rules.len > 0 and
        source.source_report_publication_channel_ids.len > 0 and
        source.source_application_checks.len > 0 and
        source.source_report_checks.len > 0 and
        source.source_request_summary.len > 0 and
        source.source_support_evidence_summary.len > 0 and
        source.source_signal_summary.len > 0 and
        source.source_denied_claims.len > 0 and
        source.source_denied_application_claims.len > 0 and
        source.source_next_queries.len > 0 and
        source.source_publication_channels.len > 0;
}

fn sourcePolicyChecksPass(checks: []const SourceCheck) bool {
    if (checks.len == 0) return false;
    for (checks) |check| {
        if (std.mem.eql(u8, check.status, "fail")) return false;
    }
    return true;
}

fn sourceCatalogsPresent(source: SourcePolicyArtifact) bool {
    return source.interpretation_rules.len > 0 and
        source.consumption_scopes.len > 0 and
        source.denied_inference_rules.len > 0 and
        source.source_denied_claims.len > 0 and
        source.source_denied_application_claims.len > 0 and
        source.source_negative_fixtures.len > 0 and
        source.negative_fixtures.len > 0 and
        source.required_verification_commands.len > 0 and
        allCommandsPresent(source.required_verification_commands, source.verified_commands);
}

fn sourceAuthorityDisabled(source: SourcePolicyArtifact) bool {
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
        !source.auto_apply_enabled;
}

fn sourceSolidWebuiValid(source: SourcePolicyArtifact) bool {
    return source.advisory_report and
        source.read_only_preview and
        source.read_only_consumption_enabled and
        source.solid_webui_enabled and
        std.mem.eql(u8, source.solid_webui_renderer, solid_webui_renderer) and
        std.mem.eql(u8, source.webui_bridge, webui_bridge);
}

fn sourceDeniedClaimsPresent(source: SourcePolicyArtifact) bool {
    return source.denied_inference_rules.len > 0 and source.source_denied_claims.len > 0 and source.source_denied_application_claims.len > 0;
}

fn filesHaveDenied(files: FileSetAnalysis) bool {
    for (files.files) |file| {
        if (file.denied_reason.len > 0) return true;
    }
    return false;
}

fn evidenceHasSupport(files: FileSetAnalysis) bool {
    for (files.files) |file| {
        if (file.denied_reason.len == 0 and file.class != .request_json and file.class != .request_text) return true;
    }
    return false;
}

fn filesRedactionBounded(files: FileSetAnalysis) bool {
    for (files.files) |file| {
        if (file.denied_reason.len > 0) return false;
        if (std.mem.eql(u8, file.redaction_posture, "blocked")) return false;
    }
    return true;
}

fn firstFilePath(files: FileSetAnalysis) []const u8 {
    if (files.files.len == 0) return "";
    return files.files[0].path;
}

fn firstProblemFilePath(requests: FileSetAnalysis, evidence: FileSetAnalysis) []const u8 {
    for (requests.files) |file| {
        if (file.denied_reason.len > 0 or std.mem.eql(u8, file.redaction_posture, "blocked")) return file.path;
    }
    for (evidence.files) |file| {
        if (file.denied_reason.len > 0 or std.mem.eql(u8, file.redaction_posture, "blocked")) return file.path;
    }
    return "";
}

fn appendCheckAndFinding(
    allocator: std.mem.Allocator,
    checks: *std.ArrayList(EvaluationCheck),
    findings: *std.ArrayList(Finding),
    name: []const u8,
    passed: bool,
    signal: []const u8,
    detail: []const u8,
) !void {
    try appendCheck(allocator, checks, name, if (passed) .pass else .fail, detail);
    if (!passed) try appendFinding(allocator, findings, name, "blocked", signal, detail, "");
}

fn appendCheck(
    allocator: std.mem.Allocator,
    checks: *std.ArrayList(EvaluationCheck),
    name: []const u8,
    status: CheckStatus,
    detail: []const u8,
) !void {
    try checks.append(allocator, .{ .name = name, .status = status, .detail = detail });
}

fn appendSignal(
    allocator: std.mem.Allocator,
    signals: *std.ArrayList(SignalEvaluation),
    findings: *std.ArrayList(Finding),
    id: []const u8,
    status: SignalStatus,
    detail: []const u8,
    evidence_path: []const u8,
) !void {
    try signals.append(allocator, .{ .id = id, .status = status, .detail = detail, .evidence_path = evidence_path });
    switch (status) {
        .observed => {},
        .missing => try appendFinding(allocator, findings, id, "advisory", id, detail, evidence_path),
        .blocked => try appendFinding(allocator, findings, id, "blocked", id, detail, evidence_path),
    }
}

fn appendFinding(
    allocator: std.mem.Allocator,
    findings: *std.ArrayList(Finding),
    id: []const u8,
    severity: []const u8,
    signal: []const u8,
    detail: []const u8,
    evidence_path: []const u8,
) !void {
    try findings.append(allocator, .{ .id = id, .severity = severity, .signal = signal, .detail = detail, .evidence_path = evidence_path });
}

fn checksForPrefixPass(checks: []const EvaluationCheck, prefix: []const u8) bool {
    for (checks) |check| {
        if (std.mem.startsWith(u8, check.name, prefix) and check.status == .fail) return false;
    }
    return true;
}

fn countFindings(findings: []const Finding, severity: []const u8) usize {
    var count: usize = 0;
    for (findings) |finding| {
        if (std.mem.eql(u8, finding.severity, severity)) count += 1;
    }
    return count;
}

fn allCommandsPresent(required: []const []const u8, actual: []const []const u8) bool {
    for (required) |command| {
        if (!containsString(actual, command)) return false;
    }
    return true;
}

fn sha256Digest(allocator: std.mem.Allocator, contents: []const u8) ![]const u8 {
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(contents, &digest, .{});

    var hex_digest: [64]u8 = undefined;
    const hex = "0123456789abcdef";
    for (digest, 0..) |byte, index| {
        hex_digest[index * 2] = hex[@intCast(byte >> 4)];
        hex_digest[index * 2 + 1] = hex[@intCast(byte & 0x0f)];
    }
    return std.fmt.allocPrint(allocator, "sha256:{s}", .{hex_digest[0..]});
}

fn detectJsonSchema(allocator: std.mem.Allocator, path: []const u8, contents: []const u8) ![]const u8 {
    if (!std.mem.endsWith(u8, path, ".json")) return allocator.dupe(u8, "");
    var parsed = std.json.parseFromSlice(GenericArtifact, allocator, contents, .{ .ignore_unknown_fields = true }) catch return allocator.dupe(u8, "");
    defer parsed.deinit();
    return allocator.dupe(u8, parsed.value.schema);
}

fn formatEvaluatorJson(
    allocator: std.mem.Allocator,
    options: Options,
    source: SourcePolicyArtifact,
    requests: FileSetAnalysis,
    evidence: FileSetAnalysis,
    result: EvaluationResult,
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
    try appendJsonField(allocator, &output, "source_ten_level_policy", options.policy_path, true);
    try appendJsonField(allocator, &output, "source_ten_level_policy_schema", source.schema, true);
    try appendJsonField(allocator, &output, "source_ten_level_policy_status", source.consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy_status, true);
    try appendJsonField(allocator, &output, "source_policy_decision", source.decision, true);
    try appendJsonField(allocator, &output, "source_ten_level_application_boundary", sourceTenLevelApplicationBoundary(source), true);
    try appendJsonField(allocator, &output, "source_ten_level_application_boundary_schema", sourceTenLevelApplicationBoundarySchema(source), true);
    try appendJsonField(allocator, &output, "source_ten_level_report", sourceTenLevelReport(source), true);
    try appendJsonField(allocator, &output, "source_ten_level_report_schema", sourceTenLevelReportSchema(source), true);
    try appendJsonField(allocator, &output, "source_ten_level_report_status", sourceTenLevelReportStatus(source), true);
    try appendJsonField(allocator, &output, "source_ten_level_after_digest", sourceTenLevelAfterDigest(source), true);
    try output.print(allocator, "  \"source_ten_level_after_present\": {},\n", .{sourceTenLevelAfterPresent(source)});
    try appendJsonField(allocator, &output, "source_nine_level_policy", source.source_nine_level_policy, true);
    try appendJsonField(allocator, &output, "source_nine_level_policy_schema", source.source_nine_level_policy_schema, true);
    try appendJsonField(allocator, &output, "source_nine_level_policy_status", source.source_nine_level_policy_status, true);
    try appendJsonField(allocator, &output, "source_nine_level_application_boundary", source.source_nine_level_application_boundary, true);
    try appendJsonField(allocator, &output, "source_nine_level_application_boundary_schema", source.source_nine_level_application_boundary_schema, true);
    try appendJsonField(allocator, &output, "source_nine_level_report", source.source_nine_level_report, true);
    try appendJsonField(allocator, &output, "source_nine_level_report_schema", source.source_nine_level_report_schema, true);
    try appendJsonField(allocator, &output, "source_nine_level_report_status", source.source_nine_level_report_status, true);
    try appendJsonField(allocator, &output, "source_eight_level_policy", sourceEightLevelPolicy(source), true);
    try appendJsonField(allocator, &output, "source_eight_level_policy_schema", sourceEightLevelPolicySchema(source), true);
    try appendJsonField(allocator, &output, "source_eight_level_policy_status", sourceEightLevelPolicyStatus(source), true);
    try appendJsonField(allocator, &output, "source_eight_level_application_boundary", sourceEightLevelApplicationBoundary(source), true);
    try appendJsonField(allocator, &output, "source_eight_level_application_boundary_schema", sourceEightLevelApplicationBoundarySchema(source), true);
    try appendJsonField(allocator, &output, "source_eight_level_application_status", sourceEightLevelApplicationStatus(source), true);
    try appendJsonField(allocator, &output, "source_inherited_policy", sourceInheritedPolicy(source), true);
    try appendJsonField(allocator, &output, "source_inherited_policy_schema", sourceInheritedPolicySchema(source), true);
    try appendJsonField(allocator, &output, "source_inherited_policy_status", sourceInheritedPolicyStatus(source), true);
    try appendJsonField(allocator, &output, "source_inherited_application_boundary", sourceInheritedApplicationBoundary(source), true);
    try appendJsonField(allocator, &output, "source_inherited_application_boundary_schema", sourceInheritedApplicationBoundarySchema(source), true);
    try appendJsonField(allocator, &output, "source_inherited_report", sourceInheritedReport(source), true);
    try appendJsonField(allocator, &output, "source_inherited_report_status", sourceInheritedReportStatus(source), true);
    try appendJsonField(allocator, &output, "source_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_status", source.source_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_status, true);
    try appendJsonField(allocator, &output, "source_consumption_report_application_boundary", source.source_consumption_report_application_boundary, true);
    try appendJsonField(allocator, &output, "source_report_application_status", source.source_report_application_status, true);
    try appendJsonField(allocator, &output, "source_consumption_report", source.source_consumption_report, true);
    try appendJsonField(allocator, &output, "source_consumption_report_status", source.source_consumption_report_status, true);
    try output.print(allocator, "  \"source_ready_for_next_branch\": {},\n", .{source.source_ready_for_next_branch});
    try appendJsonField(allocator, &output, "source_mutation_authority", source.source_mutation_authority, true);
    try appendJsonField(allocator, &output, "source_evaluator_status", source.source_evaluator_status, true);
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
    try appendJsonField(allocator, &output, "evaluation_mode", "read-only-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-consumption", true);
    try appendJsonField(allocator, &output, "evaluation_status", evaluationStatusText(result.status), true);
    try appendJsonField(allocator, &output, "consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluator_status", evaluationStatusText(result.status), true);
    try output.print(allocator, "  \"ready_for_next_branch\": {},\n", .{result.ready_for_next_branch});
    try output.print(allocator, "  \"advisory_findings_count\": {d},\n", .{result.advisory_findings_count});
    try output.print(allocator, "  \"blocked_findings_count\": {d},\n", .{result.blocked_findings_count});
    try appendJsonField(allocator, &output, "mutation_authority", mutation_authority, true);
    try appendAuthorityJson(allocator, &output);
    try appendJsonField(allocator, &output, "reviewed_by", options.reviewed_by, true);
    try appendJsonField(allocator, &output, "policy", options.policy, true);
    try appendJsonField(allocator, &output, "reason", options.reason, true);
    try output.appendSlice(allocator, "  \"source_eight_level_application_changes\": ");
    try appendStringArray(allocator, &output, sourceEightLevelApplicationChanges(source));
    try output.appendSlice(allocator, ",\n  \"source_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_changes\": ");
    try appendStringArray(allocator, &output, source.source_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_changes);
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
    try appendPublicationChannelIdsJson(allocator, &output, source.source_publication_channels);
    try output.appendSlice(allocator, ",\n  \"source_policy_rule_ids_from_report\": ");
    try appendStringArray(allocator, &output, source.source_policy_rule_ids);
    try output.appendSlice(allocator, ",\n  \"source_consumption_scope_ids_from_report\": ");
    try appendStringArray(allocator, &output, source.source_consumption_scope_ids);
    try output.appendSlice(allocator, ",\n  \"source_application_checks\": ");
    try appendSourceChecksJson(allocator, &output, source.source_application_checks);
    try output.appendSlice(allocator, ",\n  \"source_report_checks\": ");
    try appendSourceChecksJson(allocator, &output, source.source_report_checks);
    try output.appendSlice(allocator, ",\n  \"source_request_summary\": ");
    try appendSourceFilesJson(allocator, &output, source.source_request_summary);
    try output.appendSlice(allocator, ",\n  \"source_support_evidence_summary\": ");
    try appendSourceFilesJson(allocator, &output, source.source_support_evidence_summary);
    try output.appendSlice(allocator, ",\n  \"source_signal_summary\": ");
    try appendSourceSignalsJson(allocator, &output, source.source_signal_summary);
    try output.appendSlice(allocator, ",\n  \"source_blocked_findings\": ");
    try appendSourceFindingsJson(allocator, &output, source.source_blocked_findings);
    try output.appendSlice(allocator, ",\n  \"source_advisory_findings\": ");
    try appendSourceFindingsJson(allocator, &output, source.source_advisory_findings);
    try output.appendSlice(allocator, ",\n");
    try output.appendSlice(allocator, "  \"request_files\": ");
    try appendFilesJson(allocator, &output, requests.files);
    try output.appendSlice(allocator, ",\n  \"evidence_files\": ");
    try appendFilesJson(allocator, &output, evidence.files);
    try output.appendSlice(allocator, ",\n  \"checks\": ");
    try appendChecksJson(allocator, &output, result.checks);
    try output.appendSlice(allocator, ",\n  \"signal_evaluations\": ");
    try appendSignalsJson(allocator, &output, result.signal_evaluations);
    try output.appendSlice(allocator, ",\n  \"findings\": ");
    try appendFindingsJson(allocator, &output, result.findings);
    try output.appendSlice(allocator, ",\n  \"source_policy_rule_ids\": ");
    try appendRuleIdsJson(allocator, &output, source.interpretation_rules);
    try output.appendSlice(allocator, ",\n  \"source_consumption_scope_ids\": ");
    try appendScopeIdsJson(allocator, &output, source.consumption_scopes);
    try output.appendSlice(allocator, ",\n  \"denied_claims\": ");
    try appendCombinedDeniedClaimsJson(allocator, &output, source);
    try output.appendSlice(allocator, ",\n  \"next_queries\": ");
    try appendStringArray(allocator, &output, nextQueries(result.status));
    try output.appendSlice(allocator, ",\n  \"required_verification_commands\": ");
    try appendStringArray(allocator, &output, required_verification_commands);
    try appendJsonFieldPrefixComma(allocator, &output, "json_output", paths.json_path);
    try appendJsonFieldPrefixComma(allocator, &output, "text_output", paths.text_path);
    try output.appendSlice(allocator, ",\n  \"agent_guidance\": ");
    try appendStringArray(allocator, &output, agentGuidance(result.status));
    try output.appendSlice(allocator, "\n}\n");

    return try output.toOwnedSlice(allocator);
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

fn appendFilesJson(allocator: std.mem.Allocator, output: *std.ArrayList(u8), files: []const FileAnalysis) !void {
    try output.append(allocator, '[');
    for (files, 0..) |file, index| {
        if (index > 0) try output.appendSlice(allocator, ", ");
        try output.appendSlice(allocator, "{ \"path\": ");
        try appendJsonString(allocator, output, file.path);
        try output.appendSlice(allocator, ", \"class\": ");
        try appendJsonString(allocator, output, fileClassText(file.class));
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

fn appendChecksJson(allocator: std.mem.Allocator, output: *std.ArrayList(u8), checks: []const EvaluationCheck) !void {
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

fn appendSignalsJson(allocator: std.mem.Allocator, output: *std.ArrayList(u8), signals: []const SignalEvaluation) !void {
    try output.append(allocator, '[');
    for (signals, 0..) |signal, index| {
        if (index > 0) try output.appendSlice(allocator, ", ");
        try output.appendSlice(allocator, "{ \"id\": ");
        try appendJsonString(allocator, output, signal.id);
        try output.appendSlice(allocator, ", \"status\": ");
        try appendJsonString(allocator, output, signalStatusText(signal.status));
        try output.appendSlice(allocator, ", \"detail\": ");
        try appendJsonString(allocator, output, signal.detail);
        try output.appendSlice(allocator, ", \"evidence_path\": ");
        try appendJsonString(allocator, output, signal.evidence_path);
        try output.appendSlice(allocator, " }");
    }
    try output.append(allocator, ']');
}

fn appendFindingsJson(allocator: std.mem.Allocator, output: *std.ArrayList(u8), findings: []const Finding) !void {
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

fn appendSourceChecksJson(allocator: std.mem.Allocator, output: *std.ArrayList(u8), checks: []const SourceCheck) !void {
    try output.append(allocator, '[');
    for (checks, 0..) |check, index| {
        if (index > 0) try output.appendSlice(allocator, ", ");
        try output.appendSlice(allocator, "{ \"name\": ");
        try appendJsonString(allocator, output, check.name);
        try output.appendSlice(allocator, ", \"id\": ");
        try appendJsonString(allocator, output, check.id);
        try output.appendSlice(allocator, ", \"status\": ");
        try appendJsonString(allocator, output, check.status);
        try output.appendSlice(allocator, ", \"detail\": ");
        try appendJsonString(allocator, output, check.detail);
        try output.appendSlice(allocator, " }");
    }
    try output.append(allocator, ']');
}

fn appendSourceFilesJson(allocator: std.mem.Allocator, output: *std.ArrayList(u8), files: []const SourceFile) !void {
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

fn appendSourceSignalsJson(allocator: std.mem.Allocator, output: *std.ArrayList(u8), signals: []const SourceSignal) !void {
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

fn appendSourceFindingsJson(allocator: std.mem.Allocator, output: *std.ArrayList(u8), findings: []const SourceFinding) !void {
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

fn appendRuleIdsJson(allocator: std.mem.Allocator, output: *std.ArrayList(u8), rules: []const InterpretationRule) !void {
    try output.append(allocator, '[');
    for (rules, 0..) |rule, index| {
        if (index > 0) try output.appendSlice(allocator, ", ");
        try appendJsonString(allocator, output, rule.id);
    }
    try output.append(allocator, ']');
}

fn appendScopeIdsJson(allocator: std.mem.Allocator, output: *std.ArrayList(u8), scopes: []const ConsumptionScope) !void {
    try output.append(allocator, '[');
    for (scopes, 0..) |scope, index| {
        if (index > 0) try output.appendSlice(allocator, ", ");
        try appendJsonString(allocator, output, scope.id);
    }
    try output.append(allocator, ']');
}

fn appendPublicationChannelIdsJson(allocator: std.mem.Allocator, output: *std.ArrayList(u8), channels: []const SourcePublicationChannel) !void {
    try output.append(allocator, '[');
    for (channels, 0..) |channel, index| {
        if (index > 0) try output.appendSlice(allocator, ", ");
        try appendJsonString(allocator, output, channel.id);
    }
    try output.append(allocator, ']');
}

fn appendCombinedDeniedClaimsJson(allocator: std.mem.Allocator, output: *std.ArrayList(u8), source: SourcePolicyArtifact) !void {
    try output.append(allocator, '[');
    var written: usize = 0;
    for (source.denied_inference_rules) |claim| {
        if (written > 0) try output.appendSlice(allocator, ", ");
        try appendJsonString(allocator, output, claim);
        written += 1;
    }
    for (source.source_denied_claims) |claim| {
        if (written > 0) try output.appendSlice(allocator, ", ");
        try appendJsonString(allocator, output, claim);
        written += 1;
    }
    for (source.source_denied_application_claims) |claim| {
        if (written > 0) try output.appendSlice(allocator, ", ");
        try appendJsonString(allocator, output, claim);
        written += 1;
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

fn formatEvaluatorText(
    allocator: std.mem.Allocator,
    options: Options,
    source: SourcePolicyArtifact,
    requests: FileSetAnalysis,
    evidence: FileSetAnalysis,
    result: EvaluationResult,
    paths: OutputPaths,
) ![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "app-facing CI advisory remediation report consumption report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluator\n");
    try output.print(allocator, "schema: {s}\n", .{schema});
    try output.print(allocator, "schema_version: {d}\n", .{schema_version});
    try output.print(allocator, "generated_by: {s}\n", .{generated_by});
    try output.print(allocator, "evaluation_status: {s}\n", .{evaluationStatusText(result.status)});
    try output.print(allocator, "consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluator_status: {s}\n", .{evaluationStatusText(result.status)});
    try output.print(allocator, "ready_for_next_branch: {}\n", .{result.ready_for_next_branch});
    try output.print(allocator, "advisory_findings_count: {d}\n", .{result.advisory_findings_count});
    try output.print(allocator, "blocked_findings_count: {d}\n", .{result.blocked_findings_count});
    try output.print(allocator, "mutation_authority: {s}\n", .{mutation_authority});
    try output.print(allocator, "source_ten_level_policy: {s}\n", .{options.policy_path});
    try output.print(allocator, "source_ten_level_policy_schema: {s}\n", .{source.schema});
    try output.print(allocator, "source_ten_level_policy_status: {s}\n", .{source.consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy_status});
    try output.print(allocator, "source_ten_level_application_boundary: {s}\n", .{sourceTenLevelApplicationBoundary(source)});
    try output.print(allocator, "source_ten_level_application_boundary_schema: {s}\n", .{sourceTenLevelApplicationBoundarySchema(source)});
    try output.print(allocator, "source_ten_level_report: {s}\n", .{sourceTenLevelReport(source)});
    try output.print(allocator, "source_ten_level_report_schema: {s}\n", .{sourceTenLevelReportSchema(source)});
    try output.print(allocator, "source_ten_level_report_status: {s}\n", .{sourceTenLevelReportStatus(source)});
    try output.print(allocator, "source_ten_level_after_digest: {s}\n", .{sourceTenLevelAfterDigest(source)});
    try output.print(allocator, "source_ten_level_after_present: {}\n", .{sourceTenLevelAfterPresent(source)});
    try output.print(allocator, "source_nine_level_policy: {s}\n", .{source.source_nine_level_policy});
    try output.print(allocator, "source_nine_level_policy_status: {s}\n", .{source.source_nine_level_policy_status});
    try output.print(allocator, "source_nine_level_application_boundary: {s}\n", .{source.source_nine_level_application_boundary});
    try output.print(allocator, "source_nine_level_report: {s}\n", .{source.source_nine_level_report});
    try output.print(allocator, "source_nine_level_report_status: {s}\n", .{source.source_nine_level_report_status});
    try output.print(allocator, "source_eight_level_policy: {s}\n", .{sourceEightLevelPolicy(source)});
    try output.print(allocator, "source_eight_level_policy_schema: {s}\n", .{sourceEightLevelPolicySchema(source)});
    try output.print(allocator, "source_eight_level_policy_status: {s}\n", .{sourceEightLevelPolicyStatus(source)});
    try output.print(allocator, "source_eight_level_application_boundary: {s}\n", .{sourceEightLevelApplicationBoundary(source)});
    try output.print(allocator, "source_eight_level_application_boundary_schema: {s}\n", .{sourceEightLevelApplicationBoundarySchema(source)});
    try output.print(allocator, "source_eight_level_application_status: {s}\n", .{sourceEightLevelApplicationStatus(source)});
    try output.print(allocator, "source_inherited_policy: {s}\n", .{sourceInheritedPolicy(source)});
    try output.print(allocator, "source_inherited_policy_schema: {s}\n", .{sourceInheritedPolicySchema(source)});
    try output.print(allocator, "source_inherited_policy_status: {s}\n", .{sourceInheritedPolicyStatus(source)});
    try output.print(allocator, "source_inherited_application_boundary: {s}\n", .{sourceInheritedApplicationBoundary(source)});
    try output.print(allocator, "source_inherited_application_boundary_schema: {s}\n", .{sourceInheritedApplicationBoundarySchema(source)});
    try output.print(allocator, "source_inherited_report: {s}\n", .{sourceInheritedReport(source)});
    try output.print(allocator, "source_inherited_report_status: {s}\n", .{sourceInheritedReportStatus(source)});
    try output.print(allocator, "source_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_status: {s}\n", .{source.source_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_status});
    try output.print(allocator, "source_consumption_report_application_boundary: {s}\n", .{source.source_consumption_report_application_boundary});
    try output.print(allocator, "source_report_application_status: {s}\n", .{source.source_report_application_status});
    try output.print(allocator, "source_consumption_report: {s}\n", .{source.source_consumption_report});
    try output.print(allocator, "source_eight_level_after_digest: {s}\n", .{sourceEightLevelAfterDigest(source)});
    try output.print(allocator, "source_eight_level_after_present: {}\n", .{sourceEightLevelAfterPresent(source)});
    try output.print(allocator, "json_output: {s}\n", .{paths.json_path});
    try output.print(allocator, "text_output: {s}\n\n", .{paths.text_path});
    try appendTextList(allocator, &output, "source evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report application changes", source.source_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_changes);
    try appendTextList(allocator, &output, "source evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report application changes", source.source_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_changes);
    try appendTextList(allocator, &output, "source before evidence", source.source_before_evidence);
    try appendTextList(allocator, &output, "source after evidence", source.source_after_evidence);
    try appendTextList(allocator, &output, "source report application changes", source.source_report_application_changes);
    try appendTextList(allocator, &output, "source report before evidence", source.source_report_before_evidence);
    try appendTextList(allocator, &output, "source report after evidence", source.source_report_after_evidence);
    try appendTextList(allocator, &output, "source report next queries", source.source_report_next_queries);
    try appendTextList(allocator, &output, "source report boundary rules", source.source_report_boundary_rules);
    try appendTextList(allocator, &output, "source report publication channel ids", source.source_report_publication_channel_ids);
    try appendFilesText(allocator, &output, "request files", requests.files);
    try appendFilesText(allocator, &output, "evidence files", evidence.files);
    try appendChecksText(allocator, &output, result.checks);
    try appendSignalsText(allocator, &output, result.signal_evaluations);
    try appendFindingsText(allocator, &output, result.findings);
    try appendTextList(allocator, &output, "next queries", nextQueries(result.status));
    try appendTextList(allocator, &output, "agent guidance", agentGuidance(result.status));
    return try output.toOwnedSlice(allocator);
}

fn appendFilesText(allocator: std.mem.Allocator, output: *std.ArrayList(u8), title: []const u8, files: []const FileAnalysis) !void {
    try output.print(allocator, "{s}:\n", .{title});
    if (files.len == 0) {
        try output.appendSlice(allocator, "- none\n\n");
        return;
    }
    for (files) |file| {
        try output.print(allocator, "- {s}: class={s}, redaction={s}, denied={s}\n", .{ file.path, fileClassText(file.class), file.redaction_posture, if (file.denied_reason.len == 0) "none" else file.denied_reason });
    }
    try output.append(allocator, '\n');
}

fn appendChecksText(allocator: std.mem.Allocator, output: *std.ArrayList(u8), checks: []const EvaluationCheck) !void {
    try output.appendSlice(allocator, "checks:\n");
    for (checks) |check| {
        try output.print(allocator, "- {s}: {s} ({s})\n", .{ check.name, checkStatusText(check.status), check.detail });
    }
    try output.append(allocator, '\n');
}

fn appendSignalsText(allocator: std.mem.Allocator, output: *std.ArrayList(u8), signals: []const SignalEvaluation) !void {
    try output.appendSlice(allocator, "signal evaluations:\n");
    for (signals) |signal| {
        try output.print(allocator, "- {s}: {s} ({s})\n", .{ signal.id, signalStatusText(signal.status), signal.detail });
    }
    try output.append(allocator, '\n');
}

fn appendFindingsText(allocator: std.mem.Allocator, output: *std.ArrayList(u8), findings: []const Finding) !void {
    try output.appendSlice(allocator, "findings:\n");
    if (findings.len == 0) {
        try output.appendSlice(allocator, "- none\n\n");
        return;
    }
    for (findings) |finding| {
        try output.print(allocator, "- {s}: {s} ({s})\n", .{ finding.id, finding.severity, finding.detail });
    }
    try output.append(allocator, '\n');
}

fn appendTextList(allocator: std.mem.Allocator, output: *std.ArrayList(u8), title: []const u8, values: []const []const u8) !void {
    try output.print(allocator, "{s}:\n", .{title});
    if (values.len == 0) {
        try output.appendSlice(allocator, "- none\n\n");
        return;
    }
    for (values) |value| try output.print(allocator, "- {s}\n", .{value});
    try output.append(allocator, '\n');
}

fn nextQueries(status: EvaluationStatus) []const []const u8 {
    return switch (status) {
        .ready => &.{
            "causal-query --artifact <app-facing-ci-ten-level-evaluator.json> --kind request",
            "causal-query --artifact <app-facing-ci-ten-level-evaluator.json> --kind denied-claim",
            "start codex/zigeffect-causal-app-facing-eleven-level-report with this evaluator artifact",
        },
        .advisory_findings => &.{
            "add support evidence for the request and rerun the evaluator",
            "inspect advisory findings before rendering an eleven-level report",
        },
        .blocked => &.{
            "repair blocked source policy or unsafe request evidence before continuing",
            "do not infer runtime mutation CI enforcement storage deployment or production health",
        },
    };
}

fn agentGuidance(status: EvaluationStatus) []const []const u8 {
    return switch (status) {
        .ready => &.{
            "Ready ten-level evaluator artifacts may feed a local eleven-level report.",
            "Use only bounded redacted source ids policy rule ids denied claims and next-query guidance.",
            "Do not infer app runtime integration mutation authority required checks GitHub mutation NenDB writes adapter execution public upload auto-apply deployment or production health.",
        },
        .advisory_findings => &.{
            "Advisory evaluator artifacts are usable for review but should collect missing support evidence before report handoff.",
            "Keep all consumption read-only and bounded.",
        },
        .blocked => &.{
            "Blocked evaluator artifacts are stop signs.",
            "Repair source policy or request evidence and rerun the evaluator before continuing.",
        },
    };
}

fn evaluationStatusText(status: EvaluationStatus) []const u8 {
    return switch (status) {
        .ready => "ready",
        .advisory_findings => "advisory-findings",
        .blocked => "blocked",
    };
}

fn signalStatusText(status: SignalStatus) []const u8 {
    return switch (status) {
        .observed => "observed",
        .missing => "missing",
        .blocked => "blocked",
    };
}

fn checkStatusText(status: CheckStatus) []const u8 {
    return switch (status) {
        .pass => "pass",
        .fail => "fail",
    };
}

fn fileClassText(class: FileClass) []const u8 {
    return switch (class) {
        .request_json => "request_json",
        .request_text => "request_text",
        .policy_json => "policy_json",
        .causal_json => "causal_json",
        .causal_text => "causal_text",
        .workbench_text => "workbench_text",
        .denied => "denied",
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
    return std.Io.Dir.cwd().readFileAlloc(io, path, allocator, .limited(max_input_bytes)) catch |read_err| switch (read_err) {
        error.FileNotFound => err,
        else => read_err,
    };
}

fn readInputs(io: std.Io, allocator: std.mem.Allocator, paths: []const []const u8, missing_err: anyerror) ![]const FileInput {
    var inputs = std.ArrayList(FileInput).empty;
    errdefer {
        for (inputs.items) |input| allocator.free(input.contents);
        inputs.deinit(allocator);
    }
    for (paths) |path| {
        const contents = try readRequiredArtifact(io, allocator, path, missing_err);
        try inputs.append(allocator, .{ .path = path, .contents = contents });
    }
    return try inputs.toOwnedSlice(allocator);
}

fn freeInputs(allocator: std.mem.Allocator, inputs: []const FileInput) void {
    for (inputs) |input| allocator.free(input.contents);
    if (inputs.len > 0) allocator.free(inputs);
}

fn writeArtifact(io: std.Io, path: []const u8, contents: []const u8) !void {
    const slash = std.mem.lastIndexOfScalar(u8, path, '/') orelse return error.InvalidArtifactPath;
    const cwd = std.Io.Dir.cwd();
    try cwd.createDirPath(io, path[0..slash]);
    try cwd.writeFile(io, .{ .sub_path = path, .data = contents });
}

fn run(init: std.process.Init, options: Options) !void {
    const allocator = init.gpa;
    const source_policy_json = try readRequiredArtifact(init.io, allocator, options.policy_path, error.MissingPolicyInput);
    defer allocator.free(source_policy_json);

    const request_inputs = try readInputs(init.io, allocator, options.request_paths, error.MissingRequestInput);
    defer freeInputs(allocator, request_inputs);
    const evidence_inputs = try readInputs(init.io, allocator, options.evidence_paths, error.MissingEvidenceInput);
    defer freeInputs(allocator, evidence_inputs);

    const reports = try formatReports(allocator, .{
        .options = options,
        .source_policy_json = source_policy_json,
        .request_inputs = request_inputs,
        .evidence_inputs = evidence_inputs,
    });
    defer reports.deinit(allocator);

    const paths = try outputPathsForOptions(allocator, options);
    defer paths.deinit(allocator);

    try writeArtifact(init.io, paths.json_path, reports.json);
    try writeArtifact(init.io, paths.text_path, reports.text);
    std.debug.print("{s}", .{reports.text});
}

fn usage() []const u8 {
    return "usage: zig build causal-app-facing-ten-level-evaluator -- --from-policy <ten-level-policy.json> evaluate --reason <reason> --request <path>... [--evidence <path>]... [--by <actor>] [--policy <policy>] [--out-prefix <path-prefix>]\n";
}

fn failUsage(err: anyerror) noreturn {
    std.debug.print("causal-app-facing-ten-level-evaluator error: {s}\n{s}", .{ @errorName(err), usage() });
    std.process.exit(2);
}

fn freeSliceOnly(allocator: std.mem.Allocator, values: []const []const u8) void {
    if (values.len > 0) allocator.free(values);
}

fn containsString(values: []const []const u8, needle: []const u8) bool {
    for (values) |value| {
        if (std.mem.eql(u8, value, needle)) return true;
    }
    return false;
}

const sample_request_json =
    \\{"request_id":"agent-bounded-context","consumer_role":"agent-readonly","requested_fields":["source ids","policy rules","guardrails","denied claims"],"redaction":"redacted","raw_payload_capture_enabled":false,"mutation_authority":"none"}
;

const sample_unsafe_request_json =
    \\{"request_id":"unsafe-runtime","consumer_role":"agent-readonly","app_runtime_integration_enabled":true}
;

const sample_request_text =
    \\request_id=reviewer-consumption consumer_role=reviewer redacted source ids only mutation_authority=none
;

const sample_workbench_text =
    \\SolidJS webui-dev/zig-webui read-only consumption support evidence with redacted source ids and no mutation authority.
;

const sample_causal_json =
    \\{"schema":"zigeffect.causal.example.v1","schema_version":1,"redaction":"redacted","mutation_authority":"none"}
;

fn readyPolicyJson() []const u8 {
    return
    \\{
    \\  "schema": "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy.v1",
    \\  "schema_version": 1,
    \\  "decision": "approve",
    \\  "consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy_status": "ready",
    \\  "ready_for_next_branch": true,
    \\  "mutation_authority": "none",
    \\  "source_ten_level_application_boundary": "app-facing-ci-ten-level-application-boundary.json",
    \\  "source_ten_level_application_boundary_schema": "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary.v1",
    \\  "source_ten_level_report": "app-facing-ci-ten-level-report.json",
    \\  "source_ten_level_report_schema": "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report.v1",
    \\  "source_ten_level_report_status": "ready",
    \\  "source_nine_level_policy": "app-facing-ci-nine-level-policy.json",
    \\  "source_nine_level_policy_schema": "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy.v1",
    \\  "source_nine_level_policy_status": "ready",
    \\  "source_nine_level_application_boundary": "app-facing-ci-nine-level-application-boundary.json",
    \\  "source_nine_level_application_boundary_schema": "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary.v1",
    \\  "source_nine_level_report": "app-facing-ci-nine-level-report.json",
    \\  "source_nine_level_report_schema": "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report.v1",
    \\  "source_nine_level_report_status": "ready",
    \\  "source_eight_level_policy": "app-facing-ci-eight-level-policy.json",
    \\  "source_eight_level_policy_schema": "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy.v1",
    \\  "source_eight_level_policy_status": "ready",
    \\  "source_eight_level_application_boundary": "app-facing-ci-eight-level-application-boundary.json",
    \\  "source_eight_level_application_boundary_schema": "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary.v1",
    \\  "source_eight_level_application_status": "applied",
    \\  "source_eight_level_after_digest": "sha256:eight-after",
    \\  "source_eight_level_after_present": true,
    \\  "source_eight_level_application_changes": ["reviewed local eight-level application boundary"],
    \\  "source_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_status": "applied",
    \\  "source_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_after_digest": "sha256:nine-after",
    \\  "source_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_after_present": true,
    \\  "source_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_changes": ["reviewed local ten-level application boundary"],
    \\  "source_inherited_policy": "app-facing-ci-inherited-policy.json",
    \\  "source_inherited_policy_schema": "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-policy.v1",
    \\  "source_inherited_policy_status": "ready",
    \\  "source_inherited_application_boundary": "app-facing-ci-inherited-application-boundary.json",
    \\  "source_inherited_application_boundary_schema": "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-application-boundary.v1",
    \\  "source_inherited_report": "app-facing-ci-inherited-report.json",
    \\  "source_inherited_report_status": "ready",
    \\  "source_inherited_application_status": "applied",
    \\  "source_inherited_application_changes": ["reviewed local inherited application boundary"],
    \\  "source_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_status": "applied",
    \\  "source_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_after_digest": "sha256:evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-after",
    \\  "source_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_after_present": true,
    \\  "source_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_changes": ["reviewed local eight-level application boundary"],
    \\  "source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy": "consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy.json",
    \\  "source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy_schema": "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy.v1",
    \\  "source_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy_status": "ready",
    \\  "source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_boundary": "consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary.json",
    \\  "source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_boundary_schema": "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary.v1",
    \\  "source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report": "consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report.json",
    \\  "source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_status": "ready",
    \\  "source_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_status": "applied",
    \\  "source_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_changes": ["reviewed local evaluation report evaluation report evaluation report evaluation report application"],
    \\  "source_consumption_report_application_boundary": "consumption-report-application-boundary.json",
    \\  "source_consumption_report_application_boundary_schema": "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-application-boundary.v1",
    \\  "source_report_application_status": "applied",
    \\  "source_consumption_report": "consumption-report.json",
    \\  "source_consumption_report_status": "ready",
    \\  "source_ready_for_next_branch": true,
    \\  "source_mutation_authority": "none",
    \\  "source_evaluator_status": "ready",
    \\  "source_consumption_policy": "consumption-policy.json",
    \\  "source_consumption_boundary": "consumption-boundary.json",
    \\  "source_consumption_readiness": "consumption-readiness.json",
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
    \\  "source_application_checks": [
    \\    { "name": "source-report-schema", "status": "pass", "detail": "supported" },
    \\    { "name": "after-report-safe", "status": "pass", "detail": "safe" }
    \\  ],
    \\  "source_report_checks": [
    \\    { "name": "source-evaluator-schema", "status": "pass", "detail": "supported" },
    \\    { "name": "source-publication-local-only", "status": "pass", "detail": "local only" }
    \\  ],
    \\  "source_request_summary": [
    \\    { "path": "request.json", "class": "request_json", "size_bytes": 12, "sha256": "sha256:req", "detected_role": "agent-readonly", "redaction_posture": "redacted-bounded" }
    \\  ],
    \\  "source_support_evidence_summary": [
    \\    { "path": "support.txt", "class": "workbench_text", "size_bytes": 14, "sha256": "sha256:support", "detected_role": "workbench-viewer", "redaction_posture": "redacted-bounded" }
    \\  ],
    \\  "source_signal_summary": [
    \\    { "id": "request-present", "status": "observed", "detail": "request present" }
    \\  ],
    \\  "source_blocked_findings": [],
    \\  "source_advisory_findings": [],
    \\  "policy_checks": [
    \\    { "name": "source-schema", "status": "pass", "detail": "schema" },
    \\    { "name": "required-verification-commands", "status": "pass", "detail": "verified" }
    \\  ],
    \\  "interpretation_rules": [
    \\    { "id": "agent-bounded-context", "consumer_role": "agent-readonly", "allowed_use": "bounded context", "failure_effect": "informational", "denied_claim": "mutation authority" }
    \\  ],
    \\  "consumption_scopes": [
    \\    { "id": "bounded-agent-context", "visibility_class": "agent-context-redacted", "executed_by_tool": false, "mutation_authority": "none", "interpretation_scope": "bounded ids" }
    \\  ],
    \\  "denied_inference_rules": ["required-status-check", "app-runtime-integration-proof"],
    \\  "source_policy_rule_ids": ["agent-bounded-context"],
    \\  "source_consumption_scope_ids": ["bounded-agent-context"],
    \\  "source_denied_claims": ["app-runtime-integration-proof"],
    \\  "source_next_queries": ["inspect consumption report"],
    \\  "source_publication_channels": [
    \\    { "id": "local-json-artifact", "allowed": true, "executed_by_tool": false, "detail": "local only" }
    \\  ],
    \\  "source_boundary_rules": ["record-only"],
    \\  "source_denied_application_claims": ["mutation-authority-granted"],
    \\  "source_negative_fixtures": [
    \\    { "id": "unsafe-after-report-denied", "decision": "deny", "failed_gate": "after-report-safe", "reason": "runtime denied" }
    \\  ],
    \\  "negative_fixtures": [
    \\    { "id": "runtime-integration-denied", "decision": "deny", "failed_gate": "source-authority-disabled", "reason": "runtime denied" }
    \\  ],
    \\  "required_verification_commands": ["zig build test"],
    \\  "verified_commands": ["zig build test"],
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
    \\  "webui_bridge": "webui-dev/zig-webui"
    \\}
    ;
}

fn blockedPolicyJson() []const u8 {
    return
    \\{
    \\  "schema": "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy.v1",
    \\  "schema_version": 1,
    \\  "decision": "reject",
    \\  "consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy_status": "blocked",
    \\  "ready_for_next_branch": false,
    \\  "mutation_authority": "none",
    \\  "policy_checks": [{ "name": "reviewer-decision", "status": "fail", "detail": "rejected" }]
    \\}
    ;
}

test "app-facing ten-level evaluator constants are stable" {
    try std.testing.expectEqualStrings(
        "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator.v1",
        schema,
    );
    try std.testing.expectEqual(@as(u32, 1), schema_version);
    try std.testing.expectEqualStrings("codex/zigeffect-causal-app-facing-ten-level-evaluator", source_branch);
    try std.testing.expectEqualStrings("start-app-facing-eleven-level-report", recommendation);
    try std.testing.expectEqualStrings("codex/zigeffect-causal-app-facing-eleven-level-report", next_branch_if_ready);
}

test "parses app-facing ten-level evaluator options with requests and evidence" {
    var options = try parseOptions(std.testing.allocator, &.{
        "zigeffect-causal-app-facing-ten-level-evaluator",
        "--from-policy",
        ".zig-cache/causal-artifacts/app-facing-ci-ten-level-policy.json",
        "evaluate",
        "--reason",
        "report consumption request evaluated",
        "--by",
        "codex",
        "--policy",
        "manual-app-facing-ten-level-evaluator",
        "--request",
        ".zig-cache/causal-artifacts/app-facing-consumption-request.json",
        "--request",
        ".zig-cache/causal-artifacts/app-facing-consumption-request.txt",
        "--evidence",
        ".zig-cache/causal-artifacts/app-facing-consumption-support.txt",
        "--out-prefix",
        ".zig-cache/causal-artifacts/custom-app-facing-ci-ten-level-evaluator",
    });
    defer options.deinit(std.testing.allocator);

    try std.testing.expectEqualStrings(".zig-cache/causal-artifacts/app-facing-ci-ten-level-policy.json", options.policy_path);
    try std.testing.expectEqualStrings("report consumption request evaluated", options.reason);
    try std.testing.expectEqualStrings("codex", options.reviewed_by);
    try std.testing.expectEqualStrings("manual-app-facing-ten-level-evaluator", options.policy);
    try std.testing.expectEqual(@as(usize, 2), options.request_paths.len);
    try std.testing.expectEqual(@as(usize, 1), options.evidence_paths.len);
    try std.testing.expectEqualStrings(".zig-cache/causal-artifacts/custom-app-facing-ci-ten-level-evaluator", options.out_prefix.?);
}

test "default output path replaces report policy suffix" {
    const paths = try defaultOutputPaths(
        std.testing.allocator,
        ".zig-cache/causal-artifacts/app-facing-ci-ten-level-policy.json",
    );
    defer paths.deinit(std.testing.allocator);

    try std.testing.expectEqualStrings(".zig-cache/causal-artifacts/app-facing-ci-ten-level-evaluator.json", paths.json_path);
    try std.testing.expectEqualStrings(".zig-cache/causal-artifacts/app-facing-ci-ten-level-evaluator.txt", paths.text_path);
}

test "classifies request policy causal workbench and denied files" {
    var evidence = try analyzeFiles(std.testing.allocator, &.{
        .{ .path = ".zig-cache/causal-artifacts/app-facing-consumption-request.json", .contents = sample_request_json },
        .{ .path = ".zig-cache/causal-artifacts/app-facing-consumption-request.txt", .contents = sample_request_text },
        .{ .path = ".zig-cache/causal-artifacts/app-facing-ci-ten-level-policy.json", .contents = readyPolicyJson() },
        .{ .path = ".zig-cache/causal-artifacts/causal.json", .contents = sample_causal_json },
        .{ .path = ".zig-cache/causal-artifacts/workbench.txt", .contents = sample_workbench_text },
        .{ .path = "tmp/outside.json", .contents = sample_request_json },
    });
    defer evidence.deinit(std.testing.allocator);

    try std.testing.expectEqual(FileClass.request_json, evidence.files[0].class);
    try std.testing.expectEqual(FileClass.request_text, evidence.files[1].class);
    try std.testing.expectEqual(FileClass.policy_json, evidence.files[2].class);
    try std.testing.expectEqual(FileClass.causal_json, evidence.files[3].class);
    try std.testing.expectEqual(FileClass.workbench_text, evidence.files[4].class);
    try std.testing.expectEqual(FileClass.denied, evidence.files[5].class);
    try std.testing.expect(evidence.files[5].denied_reason.len > 0);
}

test "ready advisory and blocked evaluator output preserve read-only authority" {
    var ready_options = try parseOptions(std.testing.allocator, &.{
        "tool",
        "--from-policy",
        "source-app-facing-ci-ten-level-policy.json",
        "evaluate",
        "--reason",
        "ready report consumption request",
        "--request",
        ".zig-cache/causal-artifacts/app-facing-consumption-request.json",
        "--evidence",
        ".zig-cache/causal-artifacts/workbench.txt",
    });
    defer ready_options.deinit(std.testing.allocator);

    const ready_reports = try formatReports(std.testing.allocator, .{
        .options = ready_options,
        .source_policy_json = readyPolicyJson(),
        .request_inputs = &.{.{ .path = ".zig-cache/causal-artifacts/app-facing-consumption-request.json", .contents = sample_request_json }},
        .evidence_inputs = &.{.{ .path = ".zig-cache/causal-artifacts/workbench.txt", .contents = sample_workbench_text }},
    });
    defer ready_reports.deinit(std.testing.allocator);

    try std.testing.expect(std.mem.indexOf(u8, ready_reports.json, "\"evaluation_status\": \"ready\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, ready_reports.json, "\"consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluator_status\": \"ready\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, ready_reports.json, "\"ready_for_next_branch\": true") != null);
    try std.testing.expect(std.mem.indexOf(u8, ready_reports.json, "\"mutation_authority\": \"none\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, ready_reports.json, "\"source_ten_level_policy\": \"source-app-facing-ci-ten-level-policy.json\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, ready_reports.json, "\"source_ten_level_application_boundary\": \"app-facing-ci-ten-level-application-boundary.json\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, ready_reports.json, "\"source_ten_level_report\": \"app-facing-ci-ten-level-report.json\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, ready_reports.json, "\"source_ten_level_after_digest\": \"sha256:nine-after\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, ready_reports.json, "\"source_ten_level_after_present\": true") != null);
    try std.testing.expect(std.mem.indexOf(u8, ready_reports.json, "\"source_nine_level_policy\": \"app-facing-ci-nine-level-policy.json\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, ready_reports.json, "\"source_nine_level_application_boundary\": \"app-facing-ci-nine-level-application-boundary.json\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, ready_reports.json, "\"source_nine_level_report\": \"app-facing-ci-nine-level-report.json\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, ready_reports.json, "\"source_eight_level_policy\": \"app-facing-ci-eight-level-policy.json\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, ready_reports.json, "\"source_eight_level_application_boundary\": \"app-facing-ci-eight-level-application-boundary.json\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, ready_reports.json, "\"app_runtime_integration_enabled\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, ready_reports.json, "\"nendb_adapter_execution_enabled\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, ready_reports.json, "\"redaction_posture\": \"redacted-bounded\"") != null);

    var advisory_options = try parseOptions(std.testing.allocator, &.{
        "tool",
        "--from-policy",
        "source-app-facing-ci-ten-level-policy.json",
        "evaluate",
        "--reason",
        "advisory report consumption request",
        "--request",
        ".zig-cache/causal-artifacts/app-facing-consumption-request.json",
    });
    defer advisory_options.deinit(std.testing.allocator);

    const advisory_reports = try formatReports(std.testing.allocator, .{
        .options = advisory_options,
        .source_policy_json = readyPolicyJson(),
        .request_inputs = &.{.{ .path = ".zig-cache/causal-artifacts/app-facing-consumption-request.json", .contents = sample_request_json }},
        .evidence_inputs = &.{},
    });
    defer advisory_reports.deinit(std.testing.allocator);

    try std.testing.expect(std.mem.indexOf(u8, advisory_reports.json, "\"evaluation_status\": \"advisory-findings\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, advisory_reports.json, "\"id\": \"support-evidence-present\"") != null);

    const blocked_reports = try formatReports(std.testing.allocator, .{
        .options = ready_options,
        .source_policy_json = readyPolicyJson(),
        .request_inputs = &.{.{ .path = ".zig-cache/causal-artifacts/app-facing-consumption-request.json", .contents = sample_unsafe_request_json }},
        .evidence_inputs = &.{},
    });
    defer blocked_reports.deinit(std.testing.allocator);

    try std.testing.expect(std.mem.indexOf(u8, blocked_reports.json, "\"evaluation_status\": \"blocked\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, blocked_reports.json, "app runtime integration") != null);
}

test "invalid source policy blocks evaluator readiness" {
    var options = try parseOptions(std.testing.allocator, &.{
        "tool",
        "--from-policy",
        "source-app-facing-ci-ten-level-policy.json",
        "evaluate",
        "--reason",
        "invalid source policy",
        "--request",
        ".zig-cache/causal-artifacts/app-facing-consumption-request.json",
    });
    defer options.deinit(std.testing.allocator);

    const reports = try formatReports(std.testing.allocator, .{
        .options = options,
        .source_policy_json = blockedPolicyJson(),
        .request_inputs = &.{.{ .path = ".zig-cache/causal-artifacts/app-facing-consumption-request.json", .contents = sample_request_json }},
        .evidence_inputs = &.{},
    });
    defer reports.deinit(std.testing.allocator);

    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"evaluation_status\": \"blocked\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"id\": \"source-report-policy-ready\"") != null);
}
