const std = @import("std");

pub const schema = "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy.v1";
pub const schema_version: u32 = 1;
pub const source_branch = "codex/zigeffect-causal-app-facing-eleven-level-policy";
pub const recommendation = "start-app-facing-eleven-level-evaluator";
pub const next_branch_if_ready = "codex/zigeffect-causal-app-facing-eleven-level-evaluator";

const source_boundary_schema = "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary.v1";
const generated_by = "causal-app-facing-eleven-level-policy";
const source_boundary_suffix = "-ci-eleven-level-application-boundary.json";
const output_prefix_suffix = "-ci-eleven-level-policy";
const compact_output_prefix_name = "app-facing-ci-eleven-level-policy";
const max_default_output_file_name_len = 240;
const max_source_bytes = 1024 * 1024;

const required_verification_commands: []const []const u8 = &.{
    "bun run zigeffect:workbench:typecheck",
    "bun run zigeffect:workbench:test",
    "zig build causal-app-facing-eleven-level-application-boundary -- --help",
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

const Decision = enum { approve, reject };
const PolicyStatus = enum { ready, blocked };
const CheckStatus = enum { pass, fail };

const Options = struct {
    application_path: []const u8,
    decision: Decision,
    reviewed_by: []const u8 = "app-facing-eleven-level-policy-reviewer",
    policy: []const u8 = "manual-app-facing-eleven-level-policy",
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
    source_boundary_json: []const u8,
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

const SourcePublicationChannel = struct {
    id: []const u8 = "",
    allowed: bool = false,
    executed_by_tool: bool = false,
    detail: []const u8 = "",
};

const SourceApplicationArtifact = struct {
    schema: []const u8,
    schema_version: u32,
    generated_by: []const u8 = "",
    source_branch: []const u8 = "",
    recommendation: []const u8 = "",
    next_branch_if_applied: []const u8 = "",
    source_eleven_level_report: []const u8 = "",
    source_eleven_level_report_schema: []const u8 = "",
    source_eleven_level_report_status: []const u8 = "",
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
    source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report: []const u8 = "",
    source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_status: []const u8 = "",
    source_consumption_report: []const u8 = "",
    source_consumption_report_status: []const u8 = "",
    source_ready_for_next_branch: bool = false,
    source_mutation_authority: []const u8 = "",
    source_evaluator_status: []const u8 = "",
    source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy: []const u8 = "",
    source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy_schema: []const u8 = "",
    source_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy_status: []const u8 = "",
    source_policy_decision: []const u8 = "",
    source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_boundary: []const u8 = "",
    source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_boundary_schema: []const u8 = "",
    source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report: []const u8 = "",
    source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_status: []const u8 = "",
    source_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_status: []const u8 = "",
    source_consumption_report_application_boundary: []const u8 = "",
    source_report_application_status: []const u8 = "",
    source_report_policy_ready_for_next_branch: bool = false,
    source_original_evaluator_status: []const u8 = "",
    source_consumption_policy: []const u8 = "",
    source_consumption_boundary: []const u8 = "",
    source_consumption_readiness: []const u8 = "",
    source_publication_policy: []const u8 = "",
    source_after_report_digest: []const u8 = "",
    source_consumer_after_digest: []const u8 = "",
    source_report_after_digest: []const u8 = "",
    source_report_after_present: bool = false,
    mode: []const u8,
    evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_status: []const u8,
    applied: bool,
    ready_for_next_branch: bool,
    mutation_authority: []const u8,
    reviewed_by: []const u8 = "",
    policy: []const u8 = "",
    reason: []const u8 = "",
    evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_after_path: ?[]const u8 = null,
    evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_after_digest: []const u8 = "",
    evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_after_present: bool = false,
    source_blocked_findings_count: usize = 0,
    source_advisory_findings_count: usize = 0,
    evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_changes: []const []const u8 = &.{},
    before_evidence: []const []const u8 = &.{},
    after_evidence: []const []const u8 = &.{},
    application_checks: []const SourceCheck = &.{},
    source_checks: []const SourceCheck = &.{},
    source_report_application_changes: []const []const u8 = &.{},
    source_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_changes: []const []const u8 = &.{},
    source_before_evidence: []const []const u8 = &.{},
    source_after_evidence: []const []const u8 = &.{},
    source_next_queries: []const []const u8 = &.{},
    source_boundary_rules: []const []const u8 = &.{},
    source_publication_channel_ids: []const []const u8 = &.{},
    request_summary: []const SourceFile = &.{},
    support_evidence_summary: []const SourceFile = &.{},
    signal_summary: []const SourceSignal = &.{},
    blocked_findings: []const SourceFinding = &.{},
    advisory_findings: []const SourceFinding = &.{},
    source_policy_rule_ids: []const []const u8 = &.{},
    source_consumption_scope_ids: []const []const u8 = &.{},
    denied_claims: []const []const u8 = &.{},
    next_queries: []const []const u8 = &.{},
    source_publication_channels: []const SourcePublicationChannel = &.{},
    boundary_rules: []const []const u8 = &.{},
    denied_application_claims: []const []const u8 = &.{},
    negative_fixtures: []const SourceNegativeFixture = &.{},
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

const PolicyCheck = struct {
    name: []const u8,
    status: CheckStatus,
    detail: []const u8,
};

const PolicyResult = struct {
    status: PolicyStatus,
    ready_for_next_branch: bool,
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

const ConsumptionScope = struct {
    id: []const u8,
    visibility_class: []const u8,
    executed_by_tool: bool,
    mutation_authority: []const u8,
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
    .{ .id = "maintainer-consumption-review", .consumer_role = "maintainer", .allowed_use = "compare source ids boundary checks before after evidence denied claims and guardrails for triage", .failure_effect = "informational", .denied_claim = "production health" },
    .{ .id = "agent-bounded-context", .consumer_role = "agent-readonly", .allowed_use = "cite bounded source ids policy rules guardrails blocked claims and next-query guidance", .failure_effect = "informational", .denied_claim = "mutation authority" },
    .{ .id = "ci-advisory-reader", .consumer_role = "ci-advisory-reader", .allowed_use = "display non-blocking advisory context without merge-blocking or required-check semantics", .failure_effect = "informational", .denied_claim = "required status check" },
    .{ .id = "solid-webui-readonly-consumer", .consumer_role = "workbench-viewer", .allowed_use = "render local SolidJS webui consumption evidence without mutation controls or runtime wiring", .failure_effect = "informational", .denied_claim = "app mutation" },
    .{ .id = "future-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator-input", .consumer_role = "future-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator", .allowed_use = "input to bounded read-only consumption request classification only", .failure_effect = "evaluator-input", .denied_claim = "app runtime integration" },
};

const consumption_scopes: []const ConsumptionScope = &.{
    .{ .id = "local-json-artifact", .visibility_class = "local-redacted", .executed_by_tool = false, .mutation_authority = "none", .interpretation_scope = "machine-readable consumption report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report policy evidence" },
    .{ .id = "local-text-report", .visibility_class = "local-redacted", .executed_by_tool = false, .mutation_authority = "none", .interpretation_scope = "human-readable consumption report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report policy evidence" },
    .{ .id = "solid-webui-readonly-rendering", .visibility_class = "local-webui-redacted", .executed_by_tool = false, .mutation_authority = "none", .interpretation_scope = "read-only SolidJS webui rendering contract" },
    .{ .id = "bounded-agent-context", .visibility_class = "agent-context-redacted", .executed_by_tool = false, .mutation_authority = "none", .interpretation_scope = "bounded ids checks guardrails and denied claims for agents" },
    .{ .id = "non-blocking-ci-advisory-reading", .visibility_class = "ci-internal-advisory", .executed_by_tool = false, .mutation_authority = "none", .interpretation_scope = "non-blocking advisory report consumption" },
    .{ .id = "future-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator-input", .visibility_class = "local-evaluator-input", .executed_by_tool = false, .mutation_authority = "none", .interpretation_scope = "future bounded consumption report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluator input" },
};

const denied_inference_rules: []const []const u8 = &.{
    "required-status-check",
    "merge-blocker",
    "ci-enforcement",
    "branch-protection",
    "workflow-mutation-proof",
    "github-api-mutation-proof",
    "github-step-summary-proof-by-this-tool",
    "pull-request-comment-proof-by-this-tool",
    "artifact-upload-proof",
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
    .{ .id = "planned-application-boundary-denied", .artifact_state = "evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_status=planned", .decision = "deny", .failed_gate = "source-applied-application", .reason = "policy approval requires an applied consumption-report evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report application-boundary artifact" },
    .{ .id = "missing-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-evidence-denied", .artifact_state = "evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_changes=[]", .decision = "deny", .failed_gate = "source-application-evidence-present", .reason = "policy approval requires reviewed evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report application evidence" },
    .{ .id = "missing-verification-denied", .artifact_state = "approve verified_commands=[]", .decision = "deny", .failed_gate = "required-verification-commands", .reason = "policy approval requires verification evidence" },
    .{ .id = "runtime-integration-denied", .artifact_state = "app_runtime_integration_enabled=true", .decision = "deny", .failed_gate = "source-authority-disabled", .reason = "consumption report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report policy cannot infer app runtime integration" },
    .{ .id = "nendb-adapter-execution-denied", .artifact_state = "nendb_adapter_execution_enabled=true", .decision = "deny", .failed_gate = "source-authority-disabled", .reason = "consumption report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report policy cannot execute a NenDB adapter" },
    .{ .id = "public-upload-denied", .artifact_state = "public_artifact_upload_enabled=true", .decision = "deny", .failed_gate = "source-authority-disabled", .reason = "consumption report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report policy cannot publish public artifacts" },
    .{ .id = "cockroach-scope-denied", .artifact_state = "claim=cockroach-adapter-work", .decision = "deny", .failed_gate = "denied-inference-rules", .reason = "durable adapter direction remains NenDB only" },
    .{ .id = "required-status-check-denied", .artifact_state = "ci_required_status_check_enabled=true", .decision = "deny", .failed_gate = "source-authority-disabled", .reason = "consumption report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report policy cannot create or prove required status checks" },
    .{ .id = "production-health-denied", .artifact_state = "claim=production-health-proof", .decision = "deny", .failed_gate = "denied-inference-rules", .reason = "read-only consumption report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report policy cannot prove production health" },
    .{ .id = "alternate-renderer-denied", .artifact_state = "solid_webui_renderer=react", .decision = "deny", .failed_gate = "source-solid-webui", .reason = "workbench scope remains SolidJS inside webui-dev/zig-webui" },
    .{ .id = "reject-mode-not-ready", .artifact_state = "decision=reject", .decision = "deny", .failed_gate = "reviewer-decision", .reason = "explicit rejection is preserved as blocked policy evidence" },
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
        error.MissingApplicationInput => failUsage(err),
        else => return err,
    };
}

fn parseOptions(allocator: std.mem.Allocator, args: []const []const u8) !Options {
    if (args.len < 2) return error.MissingBoundaryPath;
    if (!std.mem.eql(u8, args[1], "--from-application")) return error.UnknownFlag;
    if (args.len < 3) return error.MissingBoundaryPath;
    const application_path = args[2];
    if (!std.mem.endsWith(u8, application_path, ".json")) return error.InvalidBoundaryPath;
    if (args.len < 4) return error.MissingDecision;
    const decision = try parseDecision(args[3]);

    var reviewed_by: []const u8 = "app-facing-eleven-level-policy-reviewer";
    var policy: []const u8 = "manual-app-facing-eleven-level-policy";
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
        .application_path = application_path,
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

fn defaultOutputPaths(allocator: std.mem.Allocator, application_path: []const u8) !OutputPaths {
    const prefix = try defaultOutputPrefix(allocator, application_path);
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
        try defaultOutputPrefix(allocator, options.application_path);
    defer allocator.free(prefix);

    return .{
        .json_path = try std.fmt.allocPrint(allocator, "{s}.json", .{prefix}),
        .text_path = try std.fmt.allocPrint(allocator, "{s}.txt", .{prefix}),
    };
}

fn defaultOutputPrefix(allocator: std.mem.Allocator, application_path: []const u8) ![]const u8 {
    if (!std.mem.endsWith(u8, application_path, ".json")) return error.InvalidBoundaryPath;

    const base = if (std.mem.endsWith(u8, application_path, source_boundary_suffix))
        application_path[0 .. application_path.len - source_boundary_suffix.len]
    else
        application_path[0 .. application_path.len - ".json".len];
    const candidate = try std.fmt.allocPrint(allocator, "{s}{s}", .{ base, output_prefix_suffix });
    errdefer allocator.free(candidate);

    if (fileName(candidate).len + ".json".len <= max_default_output_file_name_len) {
        return candidate;
    }

    const directory = directoryPrefix(candidate);
    const digest = shortPathDigest(application_path);
    const compact_prefix = try std.fmt.allocPrint(allocator, "{s}{s}-{s}", .{ directory, compact_output_prefix_name, digest[0..] });
    allocator.free(candidate);
    return compact_prefix;
}

fn formatReports(allocator: std.mem.Allocator, input: PolicyInput) !PolicyReports {
    var parsed = try std.json.parseFromSlice(SourceApplicationArtifact, allocator, input.source_boundary_json, .{ .ignore_unknown_fields = true });
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

fn evaluatePolicy(allocator: std.mem.Allocator, options: Options, source: SourceApplicationArtifact) !PolicyResult {
    var checks = std.ArrayList(PolicyCheck).empty;
    errdefer checks.deinit(allocator);

    try appendCheck(allocator, &checks, "source-schema", std.mem.eql(u8, source.schema, source_boundary_schema) and source.schema_version == 1, "source uses app-facing consumption-report evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report application-boundary schema v1");
    try appendCheck(allocator, &checks, "source-applied-application", sourceIsAppliedBoundary(source), "source is record-applied applied ready record-only evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report application-boundary evidence");
    try appendCheck(allocator, &checks, "source-refs-present", sourceRefsPresent(source), "source evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report evaluator policy boundary readiness publication policy and digest refs are present");
    try appendCheck(allocator, &checks, "source-application-evidence-present", sourceEvidencePresent(source), "source evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report application changes before after summaries denied claims next queries publication channels and negative fixtures are present");
    try appendCheck(allocator, &checks, "source-application-checks-pass", sourceApplicationChecksPass(source), "source application checks are present and passing");
    try appendCheck(allocator, &checks, "source-report-checks-pass", sourceReportChecksPass(source.source_checks), "source report checks have no failures");
    try appendCheck(allocator, &checks, "source-authority-disabled", sourceAuthorityDisabled(source), "source keeps CI GitHub app runtime storage deployment public upload auto-apply and adapter authority disabled");
    try appendCheck(allocator, &checks, "source-solid-webui-readonly", sourceSolidWebuiValid(source), "source remains SolidJS inside webui-dev/zig-webui with read-only consumption enabled");
    try appendCheck(allocator, &checks, "source-local-publication-only", sourcePublicationLocalOnly(source.source_publication_channels), "source publication channels remain local-only and non-mutating");
    try appendCheck(allocator, &checks, "source-verification-evidence", sourceVerificationEvidence(source), "source carries its required verification evidence");
    try appendCheck(allocator, &checks, "policy-catalogs-present", interpretation_rules.len > 0 and consumption_scopes.len > 0 and denied_inference_rules.len > 0 and negative_fixtures.len > 0, "policy catalogs are present");

    if (options.decision == .approve) {
        try appendCheck(allocator, &checks, "required-verification-commands", allCommandsPresent(required_verification_commands, options.verified_commands), "approval records required verification commands");
    } else {
        try appendCheck(allocator, &checks, "reviewer-decision", false, "reviewer rejected the consumption report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report policy");
    }

    var all_pass = true;
    for (checks.items) |check| {
        if (check.status != .pass) {
            all_pass = false;
            break;
        }
    }

    const status: PolicyStatus = if (all_pass) .ready else .blocked;
    return .{
        .status = status,
        .ready_for_next_branch = status == .ready,
        .checks = try checks.toOwnedSlice(allocator),
    };
}

fn appendCheck(allocator: std.mem.Allocator, checks: *std.ArrayList(PolicyCheck), name: []const u8, ok: bool, detail: []const u8) !void {
    try checks.append(allocator, .{
        .name = name,
        .status = if (ok) .pass else .fail,
        .detail = detail,
    });
}

fn sourceIsAppliedBoundary(source: SourceApplicationArtifact) bool {
    return std.mem.eql(u8, source.mode, "record-applied") and
        std.mem.eql(u8, source.evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_status, "applied") and
        source.applied and
        source.ready_for_next_branch and
        std.mem.eql(u8, source.mutation_authority, "record-only");
}

fn sourceRefsPresent(source: SourceApplicationArtifact) bool {
    return sourceElevenLevelReport(source).len > 0 and
        sourceElevenLevelReportSchema(source).len > 0 and
        sourceElevenLevelReportStatus(source).len > 0 and
        sourceTenLevelRefsPresent(source) and
        sourceNineLevelRefsPresent(source) and
        source.source_ready_for_next_branch and
        source.source_mutation_authority.len > 0 and
        std.mem.eql(u8, source.source_mutation_authority, "none") and
        source.source_evaluator_status.len > 0 and
        sourceEightLevelPolicy(source).len > 0 and
        sourceEightLevelPolicySchema(source).len > 0 and
        std.mem.eql(u8, sourceEightLevelPolicyStatus(source), "ready") and
        std.mem.eql(u8, source.source_policy_decision, "approve") and
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
        source.source_consumption_policy.len > 0 and
        source.source_consumption_boundary.len > 0 and
        source.source_consumption_readiness.len > 0 and
        source.source_publication_policy.len > 0 and
        source.source_after_report_digest.len > 0 and
        source.source_consumer_after_digest.len > 0 and
        source.source_report_after_digest.len > 0 and
        source.source_report_after_present and
        source.evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_after_digest.len > 0;
}

fn sourceNineLevelRefsPresent(source: SourceApplicationArtifact) bool {
    return source.source_nine_level_policy.len > 0 and
        source.source_nine_level_policy_schema.len > 0 and
        std.mem.eql(u8, source.source_nine_level_policy_status, "ready") and
        source.source_nine_level_application_boundary.len > 0 and
        source.source_nine_level_application_boundary_schema.len > 0 and
        source.source_nine_level_report.len > 0 and
        source.source_nine_level_report_schema.len > 0 and
        std.mem.eql(u8, source.source_nine_level_report_status, "ready");
}

fn sourceTenLevelRefsPresent(source: SourceApplicationArtifact) bool {
    return source.source_ten_level_policy.len > 0 and
        source.source_ten_level_policy_schema.len > 0 and
        std.mem.eql(u8, source.source_ten_level_policy_status, "ready") and
        source.source_ten_level_application_boundary.len > 0 and
        source.source_ten_level_application_boundary_schema.len > 0 and
        source.source_ten_level_report.len > 0 and
        source.source_ten_level_report_schema.len > 0 and
        std.mem.eql(u8, source.source_ten_level_report_status, "ready");
}

fn sourceElevenLevelReport(source: SourceApplicationArtifact) []const u8 {
    if (source.source_eleven_level_report.len > 0) return source.source_eleven_level_report;
    return source.source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report;
}

fn sourceElevenLevelReportSchema(source: SourceApplicationArtifact) []const u8 {
    if (source.source_eleven_level_report_schema.len > 0) return source.source_eleven_level_report_schema;
    return "";
}

fn sourceElevenLevelReportStatus(source: SourceApplicationArtifact) []const u8 {
    if (source.source_eleven_level_report_status.len > 0) return source.source_eleven_level_report_status;
    return source.source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_status;
}

fn sourceEightLevelPolicy(source: SourceApplicationArtifact) []const u8 {
    if (source.source_eight_level_policy.len > 0) return source.source_eight_level_policy;
    return source.source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy;
}

fn sourceEightLevelPolicySchema(source: SourceApplicationArtifact) []const u8 {
    if (source.source_eight_level_policy_schema.len > 0) return source.source_eight_level_policy_schema;
    return source.source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy_schema;
}

fn sourceEightLevelPolicyStatus(source: SourceApplicationArtifact) []const u8 {
    if (source.source_eight_level_policy_status.len > 0) return source.source_eight_level_policy_status;
    return source.source_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy_status;
}

fn sourceEightLevelApplicationBoundary(source: SourceApplicationArtifact) []const u8 {
    if (source.source_eight_level_application_boundary.len > 0) return source.source_eight_level_application_boundary;
    return source.source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_boundary;
}

fn sourceEightLevelApplicationBoundarySchema(source: SourceApplicationArtifact) []const u8 {
    if (source.source_eight_level_application_boundary_schema.len > 0) return source.source_eight_level_application_boundary_schema;
    return source.source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_boundary_schema;
}

fn sourceEightLevelApplicationStatus(source: SourceApplicationArtifact) []const u8 {
    if (source.source_eight_level_application_status.len > 0) return source.source_eight_level_application_status;
    return source.source_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_status;
}

fn sourceEightLevelApplicationChanges(source: SourceApplicationArtifact) []const []const u8 {
    if (source.source_eight_level_application_changes.len > 0) return source.source_eight_level_application_changes;
    return source.source_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_changes;
}

fn sourceInheritedPolicy(source: SourceApplicationArtifact) []const u8 {
    if (source.source_inherited_policy.len > 0) return source.source_inherited_policy;
    return "";
}

fn sourceInheritedPolicySchema(source: SourceApplicationArtifact) []const u8 {
    if (source.source_inherited_policy_schema.len > 0) return source.source_inherited_policy_schema;
    return "";
}

fn sourceInheritedPolicyStatus(source: SourceApplicationArtifact) []const u8 {
    if (source.source_inherited_policy_status.len > 0) return source.source_inherited_policy_status;
    return "";
}

fn sourceInheritedApplicationBoundary(source: SourceApplicationArtifact) []const u8 {
    if (source.source_inherited_application_boundary.len > 0) return source.source_inherited_application_boundary;
    return "";
}

fn sourceInheritedApplicationBoundarySchema(source: SourceApplicationArtifact) []const u8 {
    if (source.source_inherited_application_boundary_schema.len > 0) return source.source_inherited_application_boundary_schema;
    return "";
}

fn sourceInheritedReport(source: SourceApplicationArtifact) []const u8 {
    if (source.source_inherited_report.len > 0) return source.source_inherited_report;
    return "";
}

fn sourceInheritedReportStatus(source: SourceApplicationArtifact) []const u8 {
    if (source.source_inherited_report_status.len > 0) return source.source_inherited_report_status;
    return "";
}

fn sourceInheritedApplicationStatus(source: SourceApplicationArtifact) []const u8 {
    if (source.source_inherited_application_status.len > 0) return source.source_inherited_application_status;
    return source.source_report_application_status;
}

fn sourceInheritedApplicationChanges(source: SourceApplicationArtifact) []const []const u8 {
    if (source.source_inherited_application_changes.len > 0) return source.source_inherited_application_changes;
    return source.source_report_application_changes;
}

fn sourceEvidencePresent(source: SourceApplicationArtifact) bool {
    return source.evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_changes.len > 0 and
        source.before_evidence.len > 0 and
        source.after_evidence.len > 0 and
        source.evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_after_present and
        sourceEightLevelApplicationChanges(source).len > 0 and
        sourceInheritedApplicationChanges(source).len > 0 and
        source.source_report_application_changes.len > 0 and
        source.source_before_evidence.len > 0 and
        source.source_after_evidence.len > 0 and
        source.source_next_queries.len > 0 and
        source.source_boundary_rules.len > 0 and
        source.source_publication_channel_ids.len > 0 and
        source.request_summary.len > 0 and
        source.signal_summary.len > 0 and
        source.source_policy_rule_ids.len > 0 and
        source.source_consumption_scope_ids.len > 0 and
        source.denied_claims.len > 0 and
        source.next_queries.len > 0 and
        source.source_publication_channels.len > 0 and
        source.boundary_rules.len > 0 and
        source.denied_application_claims.len > 0 and
        negativeFixtureSource(source).len > 0;
}

fn negativeFixtureSource(source: SourceApplicationArtifact) []const SourceNegativeFixture {
    return source.negative_fixtures;
}

fn sourceApplicationChecksPass(source: SourceApplicationArtifact) bool {
    if (source.application_checks.len == 0) return false;
    for (source.application_checks) |check| {
        if (!std.mem.eql(u8, check.status, "pass")) return false;
    }
    return true;
}

fn sourceReportChecksPass(checks: []const SourceCheck) bool {
    if (checks.len == 0) return false;
    for (checks) |check| {
        if (std.mem.eql(u8, check.status, "fail")) return false;
    }
    return true;
}

fn sourceAuthorityDisabled(source: SourceApplicationArtifact) bool {
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

fn sourceSolidWebuiValid(source: SourceApplicationArtifact) bool {
    return source.advisory_report and
        source.read_only_preview and
        source.read_only_consumption_enabled and
        source.solid_webui_enabled and
        std.mem.eql(u8, source.solid_webui_renderer, solid_webui_renderer) and
        std.mem.eql(u8, source.webui_bridge, webui_bridge);
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

fn sourceVerificationEvidence(source: SourceApplicationArtifact) bool {
    return source.required_verification_commands.len > 0 and
        source.verified_commands.len > 0 and
        allCommandsPresent(source.required_verification_commands, source.verified_commands);
}

fn allCommandsPresent(required: []const []const u8, actual: []const []const u8) bool {
    for (required) |command| {
        if (!containsString(actual, command)) return false;
    }
    return true;
}

fn formatPolicyJson(allocator: std.mem.Allocator, options: Options, source: SourceApplicationArtifact, result: PolicyResult, paths: OutputPaths) ![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "{\n");
    try appendJsonField(allocator, &output, "schema", schema, true);
    try output.print(allocator, "  \"schema_version\": {d},\n", .{schema_version});
    try appendJsonField(allocator, &output, "generated_by", generated_by, true);
    try appendJsonField(allocator, &output, "source_branch", source_branch, true);
    try appendJsonField(allocator, &output, "recommendation", recommendation, true);
    try appendJsonField(allocator, &output, "next_branch_if_ready", next_branch_if_ready, true);
    try appendJsonField(allocator, &output, "source_eleven_level_application_boundary", options.application_path, true);
    try appendJsonField(allocator, &output, "source_eleven_level_application_boundary_schema", source.schema, true);
    try appendJsonField(allocator, &output, "source_eleven_level_report", sourceElevenLevelReport(source), true);
    try appendJsonField(allocator, &output, "source_eleven_level_report_schema", sourceElevenLevelReportSchema(source), true);
    try appendJsonField(allocator, &output, "source_eleven_level_report_status", sourceElevenLevelReportStatus(source), true);
    try appendJsonField(allocator, &output, "source_ten_level_policy", source.source_ten_level_policy, true);
    try appendJsonField(allocator, &output, "source_ten_level_policy_schema", source.source_ten_level_policy_schema, true);
    try appendJsonField(allocator, &output, "source_ten_level_policy_status", source.source_ten_level_policy_status, true);
    try appendJsonField(allocator, &output, "source_ten_level_application_boundary", source.source_ten_level_application_boundary, true);
    try appendJsonField(allocator, &output, "source_ten_level_application_boundary_schema", source.source_ten_level_application_boundary_schema, true);
    try appendJsonField(allocator, &output, "source_ten_level_report", source.source_ten_level_report, true);
    try appendJsonField(allocator, &output, "source_ten_level_report_schema", source.source_ten_level_report_schema, true);
    try appendJsonField(allocator, &output, "source_ten_level_report_status", source.source_ten_level_report_status, true);
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
    try appendJsonField(allocator, &output, "source_inherited_application_status", sourceInheritedApplicationStatus(source), true);
    try appendJsonField(allocator, &output, "source_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_status", source.evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_status, true);
    try appendJsonField(allocator, &output, "source_consumption_report", source.source_consumption_report, true);
    try appendJsonField(allocator, &output, "source_consumption_report_status", source.source_consumption_report_status, true);
    try output.print(allocator, "  \"source_ready_for_next_branch\": {},\n", .{source.source_ready_for_next_branch});
    try appendJsonField(allocator, &output, "source_mutation_authority", source.source_mutation_authority, true);
    try appendJsonField(allocator, &output, "source_evaluator_status", source.source_evaluator_status, true);
    try appendJsonField(allocator, &output, "source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy", source.source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy, true);
    try appendJsonField(allocator, &output, "source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy_schema", source.source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy_schema, true);
    try appendJsonField(allocator, &output, "source_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy_status", source.source_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy_status, true);
    try appendJsonField(allocator, &output, "source_policy_decision", source.source_policy_decision, true);
    try appendJsonField(allocator, &output, "source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_boundary", source.source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_boundary, true);
    try appendJsonField(allocator, &output, "source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_boundary_schema", source.source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_boundary_schema, true);
    try appendJsonField(allocator, &output, "source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report", source.source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report, true);
    try appendJsonField(allocator, &output, "source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_status", source.source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_status, true);
    try appendJsonField(allocator, &output, "source_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_status", source.source_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_status, true);
    try appendJsonField(allocator, &output, "source_consumption_report_application_boundary", source.source_consumption_report_application_boundary, true);
    try appendJsonField(allocator, &output, "source_report_application_status", source.source_report_application_status, true);
    try appendJsonField(allocator, &output, "source_consumption_policy", source.source_consumption_policy, true);
    try appendJsonField(allocator, &output, "source_consumption_boundary", source.source_consumption_boundary, true);
    try appendJsonField(allocator, &output, "source_consumption_readiness", source.source_consumption_readiness, true);
    try appendJsonField(allocator, &output, "source_publication_policy", source.source_publication_policy, true);
    try appendJsonField(allocator, &output, "source_after_report_digest", source.source_after_report_digest, true);
    try appendJsonField(allocator, &output, "source_consumer_after_digest", source.source_consumer_after_digest, true);
    try appendJsonField(allocator, &output, "source_report_after_digest", source.source_report_after_digest, true);
    try output.print(allocator, "  \"source_report_after_present\": {},\n", .{source.source_report_after_present});
    try appendJsonField(allocator, &output, "source_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_after_digest", source.evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_after_digest, true);
    try output.print(allocator, "  \"source_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_after_present\": {},\n", .{source.evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_after_present});
    try appendJsonField(allocator, &output, "decision", decisionText(options.decision), true);
    try appendJsonField(allocator, &output, "reviewed_by", options.reviewed_by, true);
    try appendJsonField(allocator, &output, "policy", options.policy, true);
    try appendJsonField(allocator, &output, "reason", options.reason, true);
    try appendJsonField(allocator, &output, "consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy_status", policyStatusText(result.status), true);
    try output.print(allocator, "  \"ready_for_next_branch\": {},\n", .{result.ready_for_next_branch});
    try appendJsonField(allocator, &output, "mutation_authority", mutation_authority, true);
    try appendAuthorityJson(allocator, &output);
    try output.appendSlice(allocator, "  \"source_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_changes\": ");
    try appendStringArray(allocator, &output, source.evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_changes);
    try output.appendSlice(allocator, ",\n  \"source_before_evidence\": ");
    try appendStringArray(allocator, &output, source.before_evidence);
    try output.appendSlice(allocator, ",\n  \"source_after_evidence\": ");
    try appendStringArray(allocator, &output, source.after_evidence);
    try output.appendSlice(allocator, ",\n  \"source_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_changes\": ");
    try appendStringArray(allocator, &output, source.source_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_changes);
    try output.appendSlice(allocator, ",\n  \"source_eight_level_application_changes\": ");
    try appendStringArray(allocator, &output, sourceEightLevelApplicationChanges(source));
    try output.appendSlice(allocator, ",\n  \"source_inherited_application_changes\": ");
    try appendStringArray(allocator, &output, sourceInheritedApplicationChanges(source));
    try output.appendSlice(allocator, ",\n  \"source_report_application_changes\": ");
    try appendStringArray(allocator, &output, source.source_report_application_changes);
    try output.appendSlice(allocator, ",\n  \"source_report_before_evidence\": ");
    try appendStringArray(allocator, &output, source.source_before_evidence);
    try output.appendSlice(allocator, ",\n  \"source_report_after_evidence\": ");
    try appendStringArray(allocator, &output, source.source_after_evidence);
    try output.appendSlice(allocator, ",\n  \"source_report_next_queries\": ");
    try appendStringArray(allocator, &output, source.source_next_queries);
    try output.appendSlice(allocator, ",\n  \"source_report_boundary_rules\": ");
    try appendStringArray(allocator, &output, source.source_boundary_rules);
    try output.appendSlice(allocator, ",\n  \"source_report_publication_channel_ids\": ");
    try appendStringArray(allocator, &output, source.source_publication_channel_ids);
    try output.appendSlice(allocator, ",\n  \"source_application_checks\": ");
    try appendSourceChecksJson(allocator, &output, source.application_checks);
    try output.appendSlice(allocator, ",\n  \"source_report_checks\": ");
    try appendSourceChecksJson(allocator, &output, source.source_checks);
    try output.appendSlice(allocator, ",\n  \"source_request_summary\": ");
    try appendFilesJson(allocator, &output, source.request_summary);
    try output.appendSlice(allocator, ",\n  \"source_support_evidence_summary\": ");
    try appendFilesJson(allocator, &output, source.support_evidence_summary);
    try output.appendSlice(allocator, ",\n  \"source_signal_summary\": ");
    try appendSignalsJson(allocator, &output, source.signal_summary);
    try output.appendSlice(allocator, ",\n  \"source_blocked_findings\": ");
    try appendFindingsJson(allocator, &output, source.blocked_findings);
    try output.appendSlice(allocator, ",\n  \"source_advisory_findings\": ");
    try appendFindingsJson(allocator, &output, source.advisory_findings);
    try output.appendSlice(allocator, ",\n  \"source_policy_rule_ids\": ");
    try appendStringArray(allocator, &output, source.source_policy_rule_ids);
    try output.appendSlice(allocator, ",\n  \"source_consumption_scope_ids\": ");
    try appendStringArray(allocator, &output, source.source_consumption_scope_ids);
    try output.appendSlice(allocator, ",\n  \"source_denied_claims\": ");
    try appendStringArray(allocator, &output, source.denied_claims);
    try output.appendSlice(allocator, ",\n  \"source_next_queries\": ");
    try appendStringArray(allocator, &output, source.next_queries);
    try output.appendSlice(allocator, ",\n  \"source_publication_channels\": ");
    try appendPublicationChannelsJson(allocator, &output, source.source_publication_channels);
    try output.appendSlice(allocator, ",\n  \"source_boundary_rules\": ");
    try appendStringArray(allocator, &output, source.boundary_rules);
    try output.appendSlice(allocator, ",\n  \"source_denied_application_claims\": ");
    try appendStringArray(allocator, &output, source.denied_application_claims);
    try output.appendSlice(allocator, ",\n  \"policy_checks\": ");
    try appendPolicyChecksJson(allocator, &output, result.checks);
    try output.appendSlice(allocator, ",\n  \"interpretation_rules\": ");
    try appendInterpretationRulesJson(allocator, &output);
    try output.appendSlice(allocator, ",\n  \"consumption_scopes\": ");
    try appendConsumptionScopesJson(allocator, &output);
    try output.appendSlice(allocator, ",\n  \"denied_inference_rules\": ");
    try appendStringArray(allocator, &output, denied_inference_rules);
    try output.appendSlice(allocator, ",\n  \"source_negative_fixtures\": ");
    try appendSourceNegativeFixturesJson(allocator, &output, negativeFixtureSource(source));
    try output.appendSlice(allocator, ",\n  \"negative_fixtures\": ");
    try appendNegativeFixturesJson(allocator, &output);
    try output.appendSlice(allocator, ",\n  \"required_verification_commands\": ");
    try appendStringArray(allocator, &output, required_verification_commands);
    try output.appendSlice(allocator, ",\n  \"verified_commands\": ");
    try appendStringArray(allocator, &output, options.verified_commands);
    try output.appendSlice(allocator, ",\n  \"agent_guidance\": ");
    try appendStringArray(allocator, &output, agentGuidance(result.status));
    try output.appendSlice(allocator, ",\n");
    try appendJsonField(allocator, &output, "json_output", paths.json_path, true);
    try appendJsonField(allocator, &output, "text_output", paths.text_path, false);
    try output.appendSlice(allocator, "\n}\n");

    return try output.toOwnedSlice(allocator);
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

fn appendJsonField(allocator: std.mem.Allocator, output: *std.ArrayList(u8), name: []const u8, value: []const u8, comma: bool) !void {
    try output.appendSlice(allocator, "  \"");
    try output.appendSlice(allocator, name);
    try output.appendSlice(allocator, "\": ");
    try appendJsonString(allocator, output, value);
    if (comma) try output.append(allocator, ',');
    try output.append(allocator, '\n');
}

fn appendPolicyChecksJson(allocator: std.mem.Allocator, output: *std.ArrayList(u8), checks: []const PolicyCheck) !void {
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

fn appendSourceConsumerProfilesJson(allocator: std.mem.Allocator, output: *std.ArrayList(u8), profiles: []const SourceConsumerProfile) !void {
    try output.append(allocator, '[');
    for (profiles, 0..) |profile, index| {
        if (index > 0) try output.appendSlice(allocator, ", ");
        try output.appendSlice(allocator, "{ \"id\": ");
        try appendJsonString(allocator, output, profile.id);
        try output.appendSlice(allocator, ", \"role\": ");
        try appendJsonString(allocator, output, profile.role);
        try output.print(allocator, ", \"consumption_enabled\": {}, \"allowed_inputs\": ", .{profile.consumption_enabled});
        try appendJsonString(allocator, output, profile.allowed_inputs);
        try output.appendSlice(allocator, ", \"output_contract\": ");
        try appendJsonString(allocator, output, profile.output_contract);
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
        try output.print(allocator, ", \"required\": {}, \"evidence\": ", .{dimension.required});
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
        try output.print(allocator, ", \"required_before_boundary\": {}, \"reason\": ", .{guardrail.required_before_boundary});
        try appendJsonString(allocator, output, guardrail.reason);
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

fn appendConsumptionScopesJson(allocator: std.mem.Allocator, output: *std.ArrayList(u8)) !void {
    try output.append(allocator, '[');
    for (consumption_scopes, 0..) |scope, index| {
        if (index > 0) try output.appendSlice(allocator, ", ");
        try output.appendSlice(allocator, "{ \"id\": ");
        try appendJsonString(allocator, output, scope.id);
        try output.appendSlice(allocator, ", \"visibility_class\": ");
        try appendJsonString(allocator, output, scope.visibility_class);
        try output.print(allocator, ", \"executed_by_tool\": {}, \"mutation_authority\": ", .{scope.executed_by_tool});
        try appendJsonString(allocator, output, scope.mutation_authority);
        try output.appendSlice(allocator, ", \"interpretation_scope\": ");
        try appendJsonString(allocator, output, scope.interpretation_scope);
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

fn formatPolicyText(allocator: std.mem.Allocator, options: Options, source: SourceApplicationArtifact, result: PolicyResult, paths: OutputPaths) ![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "app-facing CI advisory remediation report consumption report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report policy\n");
    try output.print(allocator, "schema: {s}\n", .{schema});
    try output.print(allocator, "schema_version: {d}\n", .{schema_version});
    try output.print(allocator, "generated_by: {s}\n", .{generated_by});
    try output.print(allocator, "decision: {s}\n", .{decisionText(options.decision)});
    try output.print(allocator, "consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy_status: {s}\n", .{policyStatusText(result.status)});
    try output.print(allocator, "ready_for_next_branch: {}\n", .{result.ready_for_next_branch});
    try output.print(allocator, "mutation_authority: {s}\n", .{mutation_authority});
    try output.print(allocator, "source_eleven_level_application_boundary: {s}\n", .{options.application_path});
    try output.print(allocator, "source_eleven_level_application_boundary_schema: {s}\n", .{source.schema});
    try output.print(allocator, "source_eleven_level_report: {s}\n", .{sourceElevenLevelReport(source)});
    try output.print(allocator, "source_eleven_level_report_schema: {s}\n", .{sourceElevenLevelReportSchema(source)});
    try output.print(allocator, "source_eleven_level_report_status: {s}\n", .{sourceElevenLevelReportStatus(source)});
    try output.print(allocator, "source_ten_level_policy: {s}\n", .{source.source_ten_level_policy});
    try output.print(allocator, "source_ten_level_policy_status: {s}\n", .{source.source_ten_level_policy_status});
    try output.print(allocator, "source_ten_level_application_boundary: {s}\n", .{source.source_ten_level_application_boundary});
    try output.print(allocator, "source_ten_level_report: {s}\n", .{source.source_ten_level_report});
    try output.print(allocator, "source_ten_level_report_status: {s}\n", .{source.source_ten_level_report_status});
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
    try output.print(allocator, "source_inherited_application_status: {s}\n", .{sourceInheritedApplicationStatus(source)});
    try output.print(allocator, "source_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_status: {s}\n", .{source.evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_status});
    try output.print(allocator, "source_consumption_report: {s}\n", .{source.source_consumption_report});
    try output.print(allocator, "source_consumption_report_status: {s}\n", .{source.source_consumption_report_status});
    try output.print(allocator, "source_evaluator_status: {s}\n", .{source.source_evaluator_status});
    try output.print(allocator, "source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy: {s}\n", .{source.source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy});
    try output.print(allocator, "source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy_schema: {s}\n", .{source.source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy_schema});
    try output.print(allocator, "source_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy_status: {s}\n", .{source.source_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy_status});
    try output.print(allocator, "source_policy_decision: {s}\n", .{source.source_policy_decision});
    try output.print(allocator, "source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_boundary: {s}\n", .{source.source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_boundary});
    try output.print(allocator, "source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_boundary_schema: {s}\n", .{source.source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_boundary_schema});
    try output.print(allocator, "source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report: {s}\n", .{source.source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report});
    try output.print(allocator, "source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_status: {s}\n", .{source.source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_status});
    try output.print(allocator, "source_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_status: {s}\n", .{source.source_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_status});
    try output.print(allocator, "source_consumption_report_application_boundary: {s}\n", .{source.source_consumption_report_application_boundary});
    try output.print(allocator, "source_report_application_status: {s}\n", .{source.source_report_application_status});
    try output.print(allocator, "source_consumption_policy: {s}\n", .{source.source_consumption_policy});
    try output.print(allocator, "source_consumption_boundary: {s}\n", .{source.source_consumption_boundary});
    try output.print(allocator, "source_consumption_readiness: {s}\n", .{source.source_consumption_readiness});
    try output.print(allocator, "source_publication_policy: {s}\n", .{source.source_publication_policy});
    try output.print(allocator, "source_after_report_digest: {s}\n", .{source.source_after_report_digest});
    try output.print(allocator, "source_consumer_after_digest: {s}\n", .{source.source_consumer_after_digest});
    try output.print(allocator, "source_report_after_digest: {s}\n", .{source.source_report_after_digest});
    try output.print(allocator, "source_report_after_present: {}\n", .{source.source_report_after_present});
    try output.print(allocator, "source_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_after_digest: {s}\n", .{source.evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_after_digest});
    try output.print(allocator, "source_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_after_present: {}\n", .{source.evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_after_present});
    try output.print(allocator, "json_output: {s}\n", .{paths.json_path});
    try output.print(allocator, "text_output: {s}\n\n", .{paths.text_path});

    try appendPolicyChecksText(allocator, &output, result.checks);
    try appendInterpretationRulesText(allocator, &output);
    try appendConsumptionScopesText(allocator, &output);
    try appendTextList(allocator, &output, "denied inference rules", denied_inference_rules);
    try appendTextList(allocator, &output, "source evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report application changes", source.evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_changes);
    try appendTextList(allocator, &output, "source before evidence", source.before_evidence);
    try appendTextList(allocator, &output, "source after evidence", source.after_evidence);
    try appendTextList(allocator, &output, "source evaluation report application changes", source.source_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_changes);
    try appendTextList(allocator, &output, "source eight-level application changes", sourceEightLevelApplicationChanges(source));
    try appendTextList(allocator, &output, "source inherited application changes", sourceInheritedApplicationChanges(source));
    try appendTextList(allocator, &output, "source report application changes", source.source_report_application_changes);
    try appendTextList(allocator, &output, "source report before evidence", source.source_before_evidence);
    try appendTextList(allocator, &output, "source report after evidence", source.source_after_evidence);
    try appendTextList(allocator, &output, "source report next queries", source.source_next_queries);
    try appendTextList(allocator, &output, "source report boundary rules", source.source_boundary_rules);
    try appendTextList(allocator, &output, "source report publication channel ids", source.source_publication_channel_ids);
    try appendSourceChecksText(allocator, &output, "source application checks", source.application_checks);
    try appendSourceChecksText(allocator, &output, "source report checks", source.source_checks);
    try appendTextList(allocator, &output, "source policy rule ids", source.source_policy_rule_ids);
    try appendTextList(allocator, &output, "source consumption scope ids", source.source_consumption_scope_ids);
    try appendTextList(allocator, &output, "source denied claims", source.denied_claims);
    try appendTextList(allocator, &output, "source next queries", source.next_queries);
    try appendTextList(allocator, &output, "source boundary rules", source.boundary_rules);
    try appendTextList(allocator, &output, "source denied application claims", source.denied_application_claims);
    try appendNegativeFixturesText(allocator, &output);
    try appendTextList(allocator, &output, "required verification commands", required_verification_commands);
    try appendTextList(allocator, &output, "verified commands", options.verified_commands);
    try appendTextList(allocator, &output, "agent guidance", agentGuidance(result.status));

    return try output.toOwnedSlice(allocator);
}

fn appendPolicyChecksText(allocator: std.mem.Allocator, output: *std.ArrayList(u8), checks: []const PolicyCheck) !void {
    try output.appendSlice(allocator, "policy checks:\n");
    for (checks) |check| {
        try output.print(allocator, "- {s}: {s} ({s})\n", .{ check.name, checkStatusText(check.status), check.detail });
    }
    try output.append(allocator, '\n');
}

fn appendInterpretationRulesText(allocator: std.mem.Allocator, output: *std.ArrayList(u8)) !void {
    try output.appendSlice(allocator, "interpretation rules:\n");
    for (interpretation_rules) |rule| {
        try output.print(allocator, "- {s}: role={s}, failure_effect={s}, denied={s}\n", .{ rule.id, rule.consumer_role, rule.failure_effect, rule.denied_claim });
    }
    try output.append(allocator, '\n');
}

fn appendConsumptionScopesText(allocator: std.mem.Allocator, output: *std.ArrayList(u8)) !void {
    try output.appendSlice(allocator, "consumption scopes:\n");
    for (consumption_scopes) |scope| {
        try output.print(allocator, "- {s}: visibility={s}, executed_by_tool={}, mutation_authority={s}\n", .{ scope.id, scope.visibility_class, scope.executed_by_tool, scope.mutation_authority });
    }
    try output.append(allocator, '\n');
}

fn appendNegativeFixturesText(allocator: std.mem.Allocator, output: *std.ArrayList(u8)) !void {
    try output.appendSlice(allocator, "negative fixtures:\n");
    for (negative_fixtures) |fixture| {
        try output.print(allocator, "- {s}: {s}\n", .{ fixture.id, fixture.reason });
    }
    try output.append(allocator, '\n');
}

fn appendSourceChecksText(allocator: std.mem.Allocator, output: *std.ArrayList(u8), title: []const u8, checks: []const SourceCheck) !void {
    try output.print(allocator, "{s}:\n", .{title});
    if (checks.len == 0) {
        try output.appendSlice(allocator, "- none\n\n");
        return;
    }
    for (checks) |check| {
        try output.print(allocator, "- {s}: {s} ({s})\n", .{ check.name, check.status, check.detail });
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

fn agentGuidance(status: PolicyStatus) []const []const u8 {
    return switch (status) {
        .ready => &.{
            "Use ready consumption report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report policy as interpretation evidence only.",
            "Agents and the SolidJS workbench may consume bounded source ids application checks denied claims and next-query guidance.",
            "Start read-only consumption report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluator work only as a separate branch; do not infer runtime integration mutation authority CI enforcement public upload or production health.",
        },
        .blocked => &.{
            "Treat blocked consumption report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report policy evidence as a stop sign.",
            "Repair source boundary evidence or verification proof before continuing.",
            "Do not infer required checks CI enforcement GitHub mutation app mutation runtime integration live projection raw payload capture NenDB writes adapter execution Cockroach work deployment production health alternate renderer auto-apply or mutation authority.",
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
    const source_boundary_json = try readRequiredArtifact(init.io, allocator, options.application_path, error.MissingApplicationInput);
    defer allocator.free(source_boundary_json);

    const reports = try formatReports(allocator, .{
        .options = options,
        .source_boundary_json = source_boundary_json,
    });
    defer reports.deinit(allocator);

    const paths = try outputPathsForOptions(allocator, options);
    defer paths.deinit(allocator);

    try writeArtifact(init.io, paths.json_path, reports.json);
    try writeArtifact(init.io, paths.text_path, reports.text);
    std.debug.print("{s}", .{reports.text});
}

fn usage() []const u8 {
    return "usage: zig build causal-app-facing-eleven-level-policy -- --from-application <eleven-level-application-boundary.json> approve|reject --reason <reason> [--by <actor>] [--policy <policy>] [--verified-command <command>]... [--out-prefix <path-prefix>]\n";
}

fn failUsage(err: anyerror) noreturn {
    std.debug.print("causal-app-facing-eleven-level-policy error: {s}\n{s}", .{ @errorName(err), usage() });
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

fn readyApplicationBoundaryJson() []const u8 {
    return
    \\{
    \\  "schema": "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary.v1",
    \\  "schema_version": 1,
    \\  "generated_by": "causal-app-facing-eleven-level-application-boundary",
    \\  "source_eleven_level_report": "app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report.json",
    \\  "source_eleven_level_report_schema": "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report.v1",
    \\  "source_eleven_level_report_status": "ready",
    \\  "source_ten_level_policy": "app-facing-ci-ten-level-policy.json",
    \\  "source_ten_level_policy_schema": "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy.v1",
    \\  "source_ten_level_policy_status": "ready",
    \\  "source_ten_level_application_boundary": "app-facing-ci-ten-level-application-boundary.json",
    \\  "source_ten_level_application_boundary_schema": "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary.v1",
    \\  "source_ten_level_report": "app-facing-ci-ten-level-report.json",
    \\  "source_ten_level_report_schema": "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report.v1",
    \\  "source_ten_level_report_status": "ready",
    \\  "source_ten_level_after_digest": "sha256:ten-level-after",
    \\  "source_ten_level_after_present": true,
    \\  "source_ten_level_application_changes": ["reviewed local ten-level application boundary"],
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
    \\  "source_eight_level_application_changes": ["reviewed local eight-level application boundary"],
    \\  "source_inherited_policy": "app-facing-ci-inherited-policy.json",
    \\  "source_inherited_policy_schema": "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-policy.v1",
    \\  "source_inherited_policy_status": "ready",
    \\  "source_inherited_application_boundary": "app-facing-ci-inherited-application-boundary.json",
    \\  "source_inherited_application_boundary_schema": "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-application-boundary.v1",
    \\  "source_inherited_report": "app-facing-ci-inherited-report.json",
    \\  "source_inherited_report_status": "ready",
    \\  "source_inherited_application_status": "applied",
    \\  "source_inherited_application_changes": ["reviewed local inherited application boundary"],
    \\  "source_consumption_report": "app-facing-ci-advisory-remediation-report-consumption-report.json",
    \\  "source_consumption_report_status": "ready",
    \\  "source_ready_for_next_branch": true,
    \\  "source_mutation_authority": "none",
    \\  "source_evaluator_status": "ready",
    \\  "source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy": "app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-policy.json",
    \\  "source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy_schema": "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-policy.v1",
    \\  "source_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy_status": "ready",
    \\  "source_policy_decision": "approve",
    \\  "source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_boundary": "app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-application-boundary.json",
    \\  "source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_boundary_schema": "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-application-boundary.v1",
    \\  "source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report": "app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report.json",
    \\  "source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_status": "ready",
    \\  "source_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_status": "applied",
    \\  "source_consumption_report_application_boundary": "app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary.json",
    \\  "source_report_application_status": "applied",
    \\  "source_report_policy_ready_for_next_branch": true,
    \\  "source_original_evaluator_status": "ready",
    \\  "source_consumption_policy": "app-facing-ci-advisory-remediation-report-consumption-policy.json",
    \\  "source_consumption_boundary": "app-facing-ci-advisory-remediation-report-consumption-boundary.json",
    \\  "source_consumption_readiness": "app-facing-ci-advisory-remediation-report-consumption-readiness.json",
    \\  "source_publication_policy": "app-facing-ci-advisory-remediation-report-publication-policy.json",
    \\  "source_after_report_digest": "sha256:source-after",
    \\  "source_consumer_after_digest": "sha256:consumer-after",
    \\  "source_report_after_digest": "sha256:source-report-after",
    \\  "source_report_after_present": true,
    \\  "mode": "record-applied",
    \\  "evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_status": "applied",
    \\  "applied": true,
    \\  "ready_for_next_branch": true,
    \\  "mutation_authority": "record-only",
    \\  "evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_after_path": "after-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report.txt",
    \\  "evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_after_digest": "sha256:after-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report",
    \\  "evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_after_present": true,
    \\  "source_blocked_findings_count": 0,
    \\  "source_advisory_findings_count": 0,
    \\  "evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_changes": ["reviewed local consumption report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report application boundary for agents reviewers CI advisory readers and SolidJS webui"],
    \\  "before_evidence": ["before local consumption report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report application boundary evidence"],
    \\  "after_evidence": ["after local consumption report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report application boundary evidence"],
    \\  "application_checks": [
    \\    { "name": "source-report-schema", "status": "pass", "detail": "supported" },
    \\    { "name": "after-report-safe", "status": "pass", "detail": "safe" }
    \\  ],
    \\  "source_checks": [
    \\    { "name": "source-evaluator-schema", "status": "pass", "detail": "supported" },
    \\    { "name": "source-publication-local-only", "status": "pass", "detail": "local only" }
    \\  ],
    \\  "source_report_application_changes": ["reviewed local report application"],
    \\  "source_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_changes": ["reviewed local evaluation report application"],
    \\  "source_before_evidence": ["before report evidence"],
    \\  "source_after_evidence": ["after report evidence"],
    \\  "source_next_queries": ["inspect source report policy"],
    \\  "source_boundary_rules": ["record-only"],
    \\  "source_publication_channel_ids": ["local-json-artifact", "local-text-artifact", "solid-webui-readonly-view"],
    \\  "request_summary": [{ "path": "request.json", "class": "request_json", "size_bytes": 12, "sha256": "sha256:req", "detected_role": "agent-readonly", "redaction_posture": "redacted-bounded" }],
    \\  "support_evidence_summary": [{ "path": "support.txt", "class": "workbench_text", "size_bytes": 14, "sha256": "sha256:support", "detected_role": "workbench-viewer", "redaction_posture": "redacted-bounded" }],
    \\  "signal_summary": [{ "id": "request-present", "status": "observed", "detail": "request present" }],
    \\  "blocked_findings": [],
    \\  "advisory_findings": [],
    \\  "source_policy_rule_ids": ["rule-agent-readonly"],
    \\  "source_consumption_scope_ids": ["scope-agent-context"],
    \\  "denied_claims": ["no-app-runtime-integration", "mutation-authority"],
    \\  "next_queries": ["inspect-source-policy-rules", "inspect-report-application-evidence"],
    \\  "source_publication_channels": [
    \\    { "id": "local-json-artifact", "allowed": true, "executed_by_tool": true, "detail": "local JSON only" },
    \\    { "id": "local-text-artifact", "allowed": true, "executed_by_tool": true, "detail": "local text only" },
    \\    { "id": "solid-webui-readonly-view", "allowed": true, "executed_by_tool": false, "detail": "read-only view" },
    \\    { "id": "ci-upload-artifact", "allowed": false, "executed_by_tool": false, "detail": "disabled" },
    \\    { "id": "github-step-summary", "allowed": false, "executed_by_tool": false, "detail": "disabled" },
    \\    { "id": "pull-request-comment", "allowed": false, "executed_by_tool": false, "detail": "disabled" },
    \\    { "id": "required-status-check", "allowed": false, "executed_by_tool": false, "detail": "disabled" },
    \\    { "id": "app-runtime-integration", "allowed": false, "executed_by_tool": false, "detail": "disabled" },
    \\    { "id": "public-artifact-upload", "allowed": false, "executed_by_tool": false, "detail": "disabled" }
    \\  ],
    \\  "boundary_rules": ["Future consumption report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report policy work may interpret applied records for agents and the SolidJS workbench without creating mutation authority."],
    \\  "denied_application_claims": ["app-runtime-integration-proof", "mutation-authority", "public-artifact-upload-executed"],
    \\  "negative_fixtures": [
    \\    { "id": "unsafe-after-report-denied", "artifact_state": "runtime enabled", "decision": "deny", "failed_gate": "after-report-safe", "reason": "runtime denied" }
    \\  ],
    \\  "required_verification_commands": [
    \\    "bun run zigeffect:workbench:typecheck",
    \\    "bun run zigeffect:workbench:test",
    \\    "zig build causal-app-facing-eleven-level-application-boundary -- --help",
    \\    "zig build causal-schema-governance -- --format json",
    \\    "zig build causal-production-hardening-backlog -- --format json",
    \\    "zig build examples",
    \\    "zig build test"
    \\  ],
    \\  "verified_commands": [
    \\    "bun run zigeffect:workbench:typecheck",
    \\    "bun run zigeffect:workbench:test",
    \\    "zig build causal-app-facing-eleven-level-application-boundary -- --help",
    \\    "zig build causal-schema-governance -- --format json",
    \\    "zig build causal-production-hardening-backlog -- --format json",
    \\    "zig build examples",
    \\    "zig build test"
    \\  ],
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

test "app-facing advisory remediation report consumption report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report policy schema and branch constants are stable" {
    try std.testing.expectEqualStrings(
        "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy.v1",
        schema,
    );
    try std.testing.expectEqual(@as(u32, 1), schema_version);
    try std.testing.expectEqualStrings(
        "codex/zigeffect-causal-app-facing-eleven-level-policy",
        source_branch,
    );
    try std.testing.expectEqualStrings(
        "start-app-facing-eleven-level-evaluator",
        recommendation,
    );
    try std.testing.expectEqualStrings(
        "codex/zigeffect-causal-app-facing-eleven-level-evaluator",
        next_branch_if_ready,
    );
}

test "parses app-facing advisory remediation report consumption report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report policy approval and rejection options" {
    var approve_options = try parseOptions(std.testing.allocator, &.{
        "zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy",
        "--from-application",
        ".zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary.json",
        "approve",
        "--reason",
        "consumption report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report policy reviewed",
        "--by",
        "codex",
        "--policy",
        "manual-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy",
        "--verified-command",
        "zig build test",
        "--out-prefix",
        ".zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy",
    });
    defer approve_options.deinit(std.testing.allocator);

    try std.testing.expectEqual(Decision.approve, approve_options.decision);
    try std.testing.expectEqualStrings(".zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary.json", approve_options.application_path);
    try std.testing.expectEqualStrings("consumption report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report policy reviewed", approve_options.reason);
    try std.testing.expectEqualStrings("codex", approve_options.reviewed_by);
    try std.testing.expectEqualStrings("manual-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy", approve_options.policy);
    try std.testing.expectEqual(@as(usize, 1), approve_options.verified_commands.len);
    try std.testing.expectEqualStrings("zig build test", approve_options.verified_commands[0]);
    try std.testing.expectEqualStrings(".zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy", approve_options.out_prefix.?);

    var reject_options = try parseOptions(std.testing.allocator, &.{
        "zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy",
        "--from-application",
        ".zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary.json",
        "reject",
        "--reason",
        "blocked consumption report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report policy",
    });
    defer reject_options.deinit(std.testing.allocator);

    try std.testing.expectEqual(Decision.reject, reject_options.decision);
    try std.testing.expectEqualStrings("blocked consumption report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report policy", reject_options.reason);
}

test "default output path replaces boundary suffix and compacts long names" {
    const paths = try defaultOutputPaths(
        std.testing.allocator,
        ".zig-cache/causal-artifacts/app-facing-ci-eleven-level-application-boundary.json",
    );
    defer paths.deinit(std.testing.allocator);

    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/app-facing-ci-eleven-level-policy.json",
        paths.json_path,
    );
    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/app-facing-ci-eleven-level-policy.txt",
        paths.text_path,
    );

    const long_path =
        ".zig-cache/causal-artifacts/app-facing-production-integration-fixtures-readiness-review-implementation-proposal-app-facing-boundary-local-fixtures-nendb-handoff-fixtures-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary-with-extra-agent-workbench-policy-evaluator-handoff-context.json";
    const compact_paths = try defaultOutputPaths(std.testing.allocator, long_path);
    defer compact_paths.deinit(std.testing.allocator);

    try std.testing.expect(std.mem.indexOf(u8, compact_paths.json_path, compact_output_prefix_name) != null);
    try std.testing.expect(std.mem.endsWith(u8, compact_paths.json_path, ".json"));
}

test "approved and rejected consumption report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report policy output preserve read-only authority" {
    const source_json = readyApplicationBoundaryJson();

    var approve_options = try parseOptions(std.testing.allocator, &.{
        "tool",
        "--from-application",
        "source-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary.json",
        "approve",
        "--reason",
        "consumption report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report policy approved",
        "--verified-command",
        "bun run zigeffect:workbench:typecheck",
        "--verified-command",
        "bun run zigeffect:workbench:test",
        "--verified-command",
        "zig build causal-app-facing-eleven-level-application-boundary -- --help",
        "--verified-command",
        "zig build causal-schema-governance -- --format json",
        "--verified-command",
        "zig build causal-production-hardening-backlog -- --format json",
        "--verified-command",
        "zig build examples",
        "--verified-command",
        "zig build test",
    });
    defer approve_options.deinit(std.testing.allocator);

    const approve_reports = try formatReports(std.testing.allocator, .{
        .options = approve_options,
        .source_boundary_json = source_json,
    });
    defer approve_reports.deinit(std.testing.allocator);

    try std.testing.expect(std.mem.indexOf(u8, approve_reports.json, "\"consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy_status\": \"ready\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, approve_reports.json, "\"ready_for_next_branch\": true") != null);
    try std.testing.expect(std.mem.indexOf(u8, approve_reports.json, "\"mutation_authority\": \"none\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, approve_reports.json, "\"source_eleven_level_application_boundary\": \"source-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary.json\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, approve_reports.json, "\"source_eleven_level_report\": \"app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report.json\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, approve_reports.json, "\"source_ten_level_policy\": \"app-facing-ci-ten-level-policy.json\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, approve_reports.json, "\"source_ten_level_application_boundary\": \"app-facing-ci-ten-level-application-boundary.json\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, approve_reports.json, "\"source_ten_level_report\": \"app-facing-ci-ten-level-report.json\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, approve_reports.json, "\"source_nine_level_policy\": \"app-facing-ci-nine-level-policy.json\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, approve_reports.json, "\"source_nine_level_application_boundary\": \"app-facing-ci-nine-level-application-boundary.json\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, approve_reports.json, "\"source_nine_level_report\": \"app-facing-ci-nine-level-report.json\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, approve_reports.json, "\"app_runtime_integration_enabled\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, approve_reports.json, "\"nendb_adapter_execution_enabled\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, approve_reports.json, "\"id\": \"agent-bounded-context\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, approve_reports.json, "\"id\": \"future-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator-input\"") != null);

    var reject_options = try parseOptions(std.testing.allocator, &.{
        "tool",
        "--from-application",
        "source-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary.json",
        "reject",
        "--reason",
        "consumption report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report policy rejected",
    });
    defer reject_options.deinit(std.testing.allocator);

    const reject_reports = try formatReports(std.testing.allocator, .{
        .options = reject_options,
        .source_boundary_json = source_json,
    });
    defer reject_reports.deinit(std.testing.allocator);

    try std.testing.expect(std.mem.indexOf(u8, reject_reports.json, "\"consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy_status\": \"blocked\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reject_reports.json, "\"ready_for_next_branch\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, reject_reports.text, "denied inference rules:") != null);
}

test "consumption report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report policy JSON output is parseable" {
    var approve_options = try parseOptions(std.testing.allocator, &.{
        "tool",
        "--from-application",
        "source-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary.json",
        "approve",
        "--reason",
        "consumption report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report policy approved",
        "--verified-command",
        "bun run zigeffect:workbench:typecheck",
        "--verified-command",
        "bun run zigeffect:workbench:test",
        "--verified-command",
        "zig build causal-app-facing-eleven-level-application-boundary -- --help",
        "--verified-command",
        "zig build causal-schema-governance -- --format json",
        "--verified-command",
        "zig build causal-production-hardening-backlog -- --format json",
        "--verified-command",
        "zig build examples",
        "--verified-command",
        "zig build test",
    });
    defer approve_options.deinit(std.testing.allocator);

    const reports = try formatReports(std.testing.allocator, .{
        .options = approve_options,
        .source_boundary_json = readyApplicationBoundaryJson(),
    });
    defer reports.deinit(std.testing.allocator);

    var parsed = try std.json.parseFromSlice(struct {
        schema: []const u8,
        consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy_status: []const u8,
        ready_for_next_branch: bool,
        json_output: []const u8,
    }, std.testing.allocator, reports.json, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();

    try std.testing.expectEqualStrings(schema, parsed.value.schema);
    try std.testing.expectEqualStrings("ready", parsed.value.consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy_status);
    try std.testing.expect(parsed.value.ready_for_next_branch);
    try std.testing.expect(std.mem.endsWith(u8, parsed.value.json_output, ".json"));
}

test "unsafe source and missing verification block approved consumption report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report policy" {
    var options = try parseOptions(std.testing.allocator, &.{
        "tool",
        "--from-application",
        "source-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary.json",
        "approve",
        "--reason",
        "consumption report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report policy approved without verification",
    });
    defer options.deinit(std.testing.allocator);

    const missing_verification = try formatReports(std.testing.allocator, .{
        .options = options,
        .source_boundary_json = readyApplicationBoundaryJson(),
    });
    defer missing_verification.deinit(std.testing.allocator);

    try std.testing.expect(std.mem.indexOf(u8, missing_verification.json, "\"consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy_status\": \"blocked\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, missing_verification.json, "\"name\": \"required-verification-commands\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, missing_verification.json, "\"status\": \"fail\"") != null);

    const unsafe_source = try formatReports(std.testing.allocator, .{
        .options = options,
        .source_boundary_json =
        \\{
        \\  "schema": "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary.v1",
        \\  "schema_version": 1,
        \\  "mode": "record-applied",
        \\  "evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_status": "applied",
        \\  "applied": true,
        \\  "ready_for_next_branch": true,
        \\  "mutation_authority": "record-only",
        \\  "source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report": "evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report.json",
        \\  "source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_status": "ready",
        \\  "source_consumption_report": "report.json",
        \\  "source_consumption_report_status": "ready",
        \\  "source_ready_for_next_branch": true,
        \\  "source_mutation_authority": "none",
        \\  "source_evaluator_status": "ready",
        \\  "source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy": "evaluation-report-policy.json",
        \\  "source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy_schema": "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-policy.v1",
        \\  "source_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy_status": "ready",
        \\  "source_policy_decision": "approve",
        \\  "source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_boundary": "evaluation-report-application-boundary.json",
        \\  "source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_boundary_schema": "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-application-boundary.v1",
        \\  "source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report": "evaluation-report.json",
        \\  "source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_status": "ready",
        \\  "source_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_status": "applied",
        \\  "source_consumption_report_application_boundary": "report-application-boundary.json",
        \\  "source_report_application_status": "applied",
        \\  "source_report_policy_ready_for_next_branch": true,
        \\  "source_consumption_policy": "policy.json",
        \\  "source_consumption_boundary": "boundary.json",
        \\  "source_consumption_readiness": "readiness.json",
        \\  "source_publication_policy": "publication-policy.json",
        \\  "source_after_report_digest": "sha256:source",
        \\  "source_consumer_after_digest": "sha256:consumer",
        \\  "source_report_after_digest": "sha256:source-report-after",
        \\  "source_report_after_present": true,
        \\  "evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_after_digest": "sha256:after",
        \\  "evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_after_present": true,
        \\  "evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_changes": ["change"],
        \\  "before_evidence": ["before"],
        \\  "after_evidence": ["after"],
        \\  "source_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_changes": ["source evaluation report change"],
        \\  "source_report_application_changes": ["source report change"],
        \\  "source_before_evidence": ["source before"],
        \\  "source_after_evidence": ["source after"],
        \\  "source_next_queries": ["source query"],
        \\  "source_boundary_rules": ["source rule"],
        \\  "source_publication_channel_ids": ["local-json-artifact", "local-text-artifact"],
        \\  "application_checks": [{ "name": "application", "status": "pass" }],
        \\  "source_checks": [{ "name": "source", "status": "pass" }],
        \\  "request_summary": [{ "path": "request.json" }],
        \\  "signal_summary": [{ "id": "signal", "status": "observed" }],
        \\  "source_policy_rule_ids": ["rule"],
        \\  "source_consumption_scope_ids": ["scope"],
        \\  "denied_claims": ["claim"],
        \\  "next_queries": ["query"],
        \\  "source_publication_channels": [
        \\    { "id": "local-json-artifact", "allowed": true, "executed_by_tool": true },
        \\    { "id": "local-text-artifact", "allowed": true, "executed_by_tool": true }
        \\  ],
        \\  "boundary_rules": ["rule"],
        \\  "denied_application_claims": ["claim"],
        \\  "negative_fixtures": [{ "id": "negative", "decision": "deny", "failed_gate": "authority", "reason": "denied" }],
        \\  "required_verification_commands": ["zig build test"],
        \\  "verified_commands": ["zig build test"],
        \\  "app_runtime_integration_enabled": true,
        \\  "advisory_report": true,
        \\  "read_only_preview": true,
        \\  "solid_webui_enabled": true,
        \\  "solid_webui_renderer": "solidjs",
        \\  "webui_bridge": "webui-dev/zig-webui",
        \\  "read_only_consumption_enabled": true
        \\}
        ,
    });
    defer unsafe_source.deinit(std.testing.allocator);

    try std.testing.expect(std.mem.indexOf(u8, unsafe_source.json, "\"name\": \"source-authority-disabled\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, unsafe_source.json, "\"consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy_status\": \"blocked\"") != null);
}
