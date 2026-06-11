const std = @import("std");

pub const schema = "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-policy.v1";
pub const schema_version: u32 = 1;
pub const source_branch = "codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-policy";
pub const recommendation = "start-app-facing-production-integration-ci-advisory-remediation-report-consumption-evaluator";
pub const next_branch_if_ready = "codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-evaluator";

const source_boundary_schema = "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-boundary.v1";
const generated_by = "causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-policy";
const source_boundary_suffix = "-ci-advisory-remediation-report-consumption-boundary.json";
const output_prefix_suffix = "-ci-advisory-remediation-report-consumption-policy";
const compact_output_prefix_name = "app-facing-production-integration-ci-advisory-remediation-report-consumption-policy";
const max_default_output_file_name_len = 240;
const max_source_bytes = 1024 * 1024;

const required_verification_commands: []const []const u8 = &.{
    "bun run zigeffect:workbench:typecheck",
    "bun run zigeffect:workbench:test",
    "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-boundary",
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
const mutation_authority = "none";

const Decision = enum { approve, reject };
const PolicyStatus = enum { ready, blocked };
const CheckStatus = enum { pass, fail };

const Options = struct {
    boundary_path: []const u8,
    decision: Decision,
    reviewed_by: []const u8 = "app-facing-ci-advisory-remediation-report-consumption-policy-reviewer",
    policy: []const u8 = "manual-app-facing-production-integration-ci-advisory-remediation-report-consumption-policy",
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

const SourceBoundaryArtifact = struct {
    schema: []const u8,
    schema_version: u32,
    mode: []const u8,
    consumption_boundary_status: []const u8,
    applied: bool,
    ready_for_next_branch: bool,
    mutation_authority: []const u8,
    source_consumption_readiness: []const u8 = "",
    source_consumption_readiness_status: []const u8 = "",
    source_publication_policy: []const u8 = "",
    source_after_report_digest: []const u8 = "",
    consumer_after_digest: []const u8 = "",
    consumer_changes: []const []const u8 = &.{},
    before_evidence: []const []const u8 = &.{},
    after_evidence: []const []const u8 = &.{},
    boundary_checks: []const SourceCheck = &.{},
    boundary_rules: []const []const u8 = &.{},
    denied_boundary_claims: []const []const u8 = &.{},
    source_consumer_profiles: []const SourceConsumerProfile = &.{},
    source_readiness_dimensions: []const SourceReadinessDimension = &.{},
    source_consumption_guardrails: []const SourceConsumptionGuardrail = &.{},
    source_denied_inference_rules: []const []const u8 = &.{},
    source_negative_fixtures: []const SourceNegativeFixture = &.{},
    negative_fixtures: []const SourceNegativeFixture = &.{},
    blocked_claims: []const []const u8 = &.{},
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
    .{ .id = "future-consumption-evaluator-input", .consumer_role = "future-consumption-evaluator", .allowed_use = "input to bounded read-only consumption request classification only", .failure_effect = "evaluator-input", .denied_claim = "app runtime integration" },
};

const consumption_scopes: []const ConsumptionScope = &.{
    .{ .id = "local-json-artifact", .visibility_class = "local-redacted", .executed_by_tool = false, .mutation_authority = "none", .interpretation_scope = "machine-readable consumption policy evidence" },
    .{ .id = "local-text-report", .visibility_class = "local-redacted", .executed_by_tool = false, .mutation_authority = "none", .interpretation_scope = "human-readable consumption policy evidence" },
    .{ .id = "solid-webui-readonly-rendering", .visibility_class = "local-webui-redacted", .executed_by_tool = false, .mutation_authority = "none", .interpretation_scope = "read-only SolidJS webui rendering contract" },
    .{ .id = "bounded-agent-context", .visibility_class = "agent-context-redacted", .executed_by_tool = false, .mutation_authority = "none", .interpretation_scope = "bounded ids checks guardrails and denied claims for agents" },
    .{ .id = "non-blocking-ci-advisory-reading", .visibility_class = "ci-internal-advisory", .executed_by_tool = false, .mutation_authority = "none", .interpretation_scope = "non-blocking advisory report consumption" },
    .{ .id = "future-consumption-evaluator-input", .visibility_class = "local-evaluator-input", .executed_by_tool = false, .mutation_authority = "none", .interpretation_scope = "future bounded consumption evaluator input" },
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
    .{ .id = "planned-boundary-denied", .artifact_state = "consumption_boundary_status=planned", .decision = "deny", .failed_gate = "source-applied-boundary", .reason = "policy approval requires an applied consumption-boundary artifact" },
    .{ .id = "missing-verification-denied", .artifact_state = "approve verified_commands=[]", .decision = "deny", .failed_gate = "required-verification-commands", .reason = "policy approval requires verification evidence" },
    .{ .id = "runtime-integration-denied", .artifact_state = "app_runtime_integration_enabled=true", .decision = "deny", .failed_gate = "source-authority-disabled", .reason = "consumption policy cannot infer app runtime integration" },
    .{ .id = "nendb-adapter-execution-denied", .artifact_state = "nendb_adapter_execution_enabled=true", .decision = "deny", .failed_gate = "source-authority-disabled", .reason = "consumption policy cannot execute a NenDB adapter" },
    .{ .id = "required-status-check-denied", .artifact_state = "ci_required_status_check_enabled=true", .decision = "deny", .failed_gate = "source-authority-disabled", .reason = "consumption policy cannot create or prove required status checks" },
    .{ .id = "production-health-denied", .artifact_state = "claim=production-health-proof", .decision = "deny", .failed_gate = "denied-inference-rules", .reason = "read-only consumption policy cannot prove production health" },
    .{ .id = "alternate-renderer-denied", .artifact_state = "solid_webui_renderer=react", .decision = "deny", .failed_gate = "source-solid-webui", .reason = "workbench scope remains SolidJS inside webui-dev/zig-webui" },
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
        error.MissingBoundaryInput => failUsage(err),
        else => return err,
    };
}

fn parseOptions(allocator: std.mem.Allocator, args: []const []const u8) !Options {
    if (args.len < 2) return error.MissingBoundaryPath;
    if (!std.mem.eql(u8, args[1], "--from-boundary")) return error.UnknownFlag;
    if (args.len < 3) return error.MissingBoundaryPath;
    const boundary_path = args[2];
    if (!std.mem.endsWith(u8, boundary_path, ".json")) return error.InvalidBoundaryPath;
    if (args.len < 4) return error.MissingDecision;
    const decision = try parseDecision(args[3]);

    var reviewed_by: []const u8 = "app-facing-ci-advisory-remediation-report-consumption-policy-reviewer";
    var policy: []const u8 = "manual-app-facing-production-integration-ci-advisory-remediation-report-consumption-policy";
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
        .boundary_path = boundary_path,
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

fn defaultOutputPaths(allocator: std.mem.Allocator, boundary_path: []const u8) !OutputPaths {
    const prefix = try defaultOutputPrefix(allocator, boundary_path);
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
        try defaultOutputPrefix(allocator, options.boundary_path);
    defer allocator.free(prefix);

    return .{
        .json_path = try std.fmt.allocPrint(allocator, "{s}.json", .{prefix}),
        .text_path = try std.fmt.allocPrint(allocator, "{s}.txt", .{prefix}),
    };
}

fn defaultOutputPrefix(allocator: std.mem.Allocator, boundary_path: []const u8) ![]const u8 {
    if (!std.mem.endsWith(u8, boundary_path, ".json")) return error.InvalidBoundaryPath;

    const base = if (std.mem.endsWith(u8, boundary_path, source_boundary_suffix))
        boundary_path[0 .. boundary_path.len - source_boundary_suffix.len]
    else
        boundary_path[0 .. boundary_path.len - ".json".len];
    const candidate = try std.fmt.allocPrint(allocator, "{s}{s}", .{ base, output_prefix_suffix });
    errdefer allocator.free(candidate);

    if (fileName(candidate).len + ".json".len <= max_default_output_file_name_len) {
        return candidate;
    }

    const directory = directoryPrefix(candidate);
    const digest = shortPathDigest(boundary_path);
    const compact_prefix = try std.fmt.allocPrint(allocator, "{s}{s}-{s}", .{ directory, compact_output_prefix_name, digest[0..] });
    allocator.free(candidate);
    return compact_prefix;
}

fn formatReports(allocator: std.mem.Allocator, input: PolicyInput) !PolicyReports {
    var parsed = try std.json.parseFromSlice(SourceBoundaryArtifact, allocator, input.source_boundary_json, .{ .ignore_unknown_fields = true });
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

fn evaluatePolicy(allocator: std.mem.Allocator, options: Options, source: SourceBoundaryArtifact) !PolicyResult {
    var checks = std.ArrayList(PolicyCheck).empty;
    errdefer checks.deinit(allocator);

    try appendCheck(allocator, &checks, "source-schema", std.mem.eql(u8, source.schema, source_boundary_schema), "source uses app-facing consumption-boundary schema");
    try appendCheck(allocator, &checks, "source-applied-boundary", sourceIsAppliedBoundary(source), "source is record-applied applied ready record-only boundary evidence");
    try appendCheck(allocator, &checks, "source-refs-present", sourceRefsPresent(source), "source readiness publication policy and digest refs are present");
    try appendCheck(allocator, &checks, "source-evidence-present", sourceEvidencePresent(source), "source consumer changes before after profiles guardrails rules and denied claims are present");
    try appendCheck(allocator, &checks, "source-boundary-checks-pass", sourceBoundaryChecksPass(source), "source boundary checks are present and passing");
    try appendCheck(allocator, &checks, "source-authority-disabled", sourceAuthorityDisabled(source), "source keeps CI GitHub app runtime storage deployment and adapter authority disabled");
    try appendCheck(allocator, &checks, "source-solid-webui", sourceSolidWebuiValid(source), "source remains SolidJS inside webui-dev/zig-webui with read-only consumption enabled");
    try appendCheck(allocator, &checks, "source-verification-evidence", allCommandsPresent(source.required_verification_commands, source.verified_commands), "source carries its required verification evidence");
    try appendCheck(allocator, &checks, "policy-catalogs-present", interpretation_rules.len > 0 and consumption_scopes.len > 0 and denied_inference_rules.len > 0 and negative_fixtures.len > 0, "policy catalogs are present");

    if (options.decision == .approve) {
        try appendCheck(allocator, &checks, "required-verification-commands", allCommandsPresent(required_verification_commands, options.verified_commands), "approval records required verification commands");
    } else {
        try appendCheck(allocator, &checks, "reviewer-decision", false, "reviewer rejected the consumption policy");
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

fn sourceIsAppliedBoundary(source: SourceBoundaryArtifact) bool {
    return std.mem.eql(u8, source.mode, "record-applied") and
        std.mem.eql(u8, source.consumption_boundary_status, "applied") and
        source.applied and
        source.ready_for_next_branch and
        std.mem.eql(u8, source.mutation_authority, "record-only");
}

fn sourceRefsPresent(source: SourceBoundaryArtifact) bool {
    return source.source_consumption_readiness.len > 0 and
        std.mem.eql(u8, source.source_consumption_readiness_status, "ready") and
        source.source_publication_policy.len > 0 and
        source.source_after_report_digest.len > 0 and
        source.consumer_after_digest.len > 0;
}

fn sourceEvidencePresent(source: SourceBoundaryArtifact) bool {
    return source.consumer_changes.len > 0 and
        source.before_evidence.len > 0 and
        source.after_evidence.len > 0 and
        source.boundary_rules.len > 0 and
        source.denied_boundary_claims.len > 0 and
        source.source_consumer_profiles.len > 0 and
        source.source_readiness_dimensions.len > 0 and
        source.source_consumption_guardrails.len > 0 and
        source.source_denied_inference_rules.len > 0 and
        negativeFixtureSource(source).len > 0 and
        source.blocked_claims.len > 0;
}

fn negativeFixtureSource(source: SourceBoundaryArtifact) []const SourceNegativeFixture {
    if (source.negative_fixtures.len > 0) return source.negative_fixtures;
    return source.source_negative_fixtures;
}

fn sourceBoundaryChecksPass(source: SourceBoundaryArtifact) bool {
    if (source.boundary_checks.len == 0) return false;
    for (source.boundary_checks) |check| {
        if (!std.mem.eql(u8, check.status, "pass")) return false;
    }
    return true;
}

fn sourceAuthorityDisabled(source: SourceBoundaryArtifact) bool {
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

fn sourceSolidWebuiValid(source: SourceBoundaryArtifact) bool {
    return source.advisory_report and
        source.read_only_preview and
        source.read_only_consumption_enabled and
        source.solid_webui_enabled and
        std.mem.eql(u8, source.solid_webui_renderer, solid_webui_renderer) and
        std.mem.eql(u8, source.webui_bridge, webui_bridge);
}

fn allCommandsPresent(required: []const []const u8, actual: []const []const u8) bool {
    for (required) |command| {
        if (!containsString(actual, command)) return false;
    }
    return true;
}

fn formatPolicyJson(allocator: std.mem.Allocator, options: Options, source: SourceBoundaryArtifact, result: PolicyResult, paths: OutputPaths) ![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "{\n");
    try appendJsonField(allocator, &output, "schema", schema, true);
    try output.print(allocator, "  \"schema_version\": {d},\n", .{schema_version});
    try appendJsonField(allocator, &output, "generated_by", generated_by, true);
    try appendJsonField(allocator, &output, "source_branch", source_branch, true);
    try appendJsonField(allocator, &output, "recommendation", recommendation, true);
    try appendJsonField(allocator, &output, "next_branch_if_ready", next_branch_if_ready, true);
    try appendJsonField(allocator, &output, "source_consumption_boundary", options.boundary_path, true);
    try appendJsonField(allocator, &output, "source_consumption_boundary_schema", source.schema, true);
    try appendJsonField(allocator, &output, "source_consumption_boundary_status", source.consumption_boundary_status, true);
    try appendJsonField(allocator, &output, "source_consumption_readiness", source.source_consumption_readiness, true);
    try appendJsonField(allocator, &output, "source_consumption_readiness_status", source.source_consumption_readiness_status, true);
    try appendJsonField(allocator, &output, "source_publication_policy", source.source_publication_policy, true);
    try appendJsonField(allocator, &output, "source_after_report_digest", source.source_after_report_digest, true);
    try appendJsonField(allocator, &output, "source_consumer_after_digest", source.consumer_after_digest, true);
    try appendJsonField(allocator, &output, "decision", decisionText(options.decision), true);
    try appendJsonField(allocator, &output, "reviewed_by", options.reviewed_by, true);
    try appendJsonField(allocator, &output, "policy", options.policy, true);
    try appendJsonField(allocator, &output, "reason", options.reason, true);
    try appendJsonField(allocator, &output, "consumption_policy_status", policyStatusText(result.status), true);
    try output.print(allocator, "  \"ready_for_next_branch\": {},\n", .{result.ready_for_next_branch});
    try appendJsonField(allocator, &output, "mutation_authority", mutation_authority, true);
    try appendAuthorityJson(allocator, &output);
    try output.appendSlice(allocator, "  \"source_consumer_changes\": ");
    try appendStringArray(allocator, &output, source.consumer_changes);
    try output.appendSlice(allocator, ",\n  \"source_before_evidence\": ");
    try appendStringArray(allocator, &output, source.before_evidence);
    try output.appendSlice(allocator, ",\n  \"source_after_evidence\": ");
    try appendStringArray(allocator, &output, source.after_evidence);
    try output.appendSlice(allocator, ",\n  \"source_boundary_rules\": ");
    try appendStringArray(allocator, &output, source.boundary_rules);
    try output.appendSlice(allocator, ",\n  \"source_denied_boundary_claims\": ");
    try appendStringArray(allocator, &output, source.denied_boundary_claims);
    try output.appendSlice(allocator, ",\n  \"source_denied_inference_rules\": ");
    try appendStringArray(allocator, &output, source.source_denied_inference_rules);
    try output.appendSlice(allocator, ",\n  \"source_blocked_claims\": ");
    try appendStringArray(allocator, &output, source.blocked_claims);
    try output.appendSlice(allocator, ",\n  \"source_consumer_profiles\": ");
    try appendSourceConsumerProfilesJson(allocator, &output, source.source_consumer_profiles);
    try output.appendSlice(allocator, ",\n  \"source_readiness_dimensions\": ");
    try appendSourceReadinessDimensionsJson(allocator, &output, source.source_readiness_dimensions);
    try output.appendSlice(allocator, ",\n  \"source_consumption_guardrails\": ");
    try appendSourceConsumptionGuardrailsJson(allocator, &output, source.source_consumption_guardrails);
    try output.appendSlice(allocator, ",\n  \"source_boundary_checks\": ");
    try appendSourceChecksJson(allocator, &output, source.boundary_checks);
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
    try appendJsonField(allocator, &output, "json_output", paths.json_path, true);
    try appendJsonField(allocator, &output, "text_output", paths.text_path, false);
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
        \\  "advisory_report": {},
        \\  "read_only_preview": {},
        \\  "read_only_consumption_enabled": {},
        \\  "solid_webui_enabled": {},
        \\  "solid_webui_renderer": "{s}",
        \\  "webui_bridge": "{s}",
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

fn formatPolicyText(allocator: std.mem.Allocator, options: Options, source: SourceBoundaryArtifact, result: PolicyResult, paths: OutputPaths) ![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "app-facing CI advisory remediation report consumption policy\n");
    try output.print(allocator, "schema: {s}\n", .{schema});
    try output.print(allocator, "schema_version: {d}\n", .{schema_version});
    try output.print(allocator, "generated_by: {s}\n", .{generated_by});
    try output.print(allocator, "decision: {s}\n", .{decisionText(options.decision)});
    try output.print(allocator, "consumption_policy_status: {s}\n", .{policyStatusText(result.status)});
    try output.print(allocator, "ready_for_next_branch: {}\n", .{result.ready_for_next_branch});
    try output.print(allocator, "mutation_authority: {s}\n", .{mutation_authority});
    try output.print(allocator, "source_consumption_boundary: {s}\n", .{options.boundary_path});
    try output.print(allocator, "source_consumption_boundary_status: {s}\n", .{source.consumption_boundary_status});
    try output.print(allocator, "source_consumption_readiness: {s}\n", .{source.source_consumption_readiness});
    try output.print(allocator, "source_publication_policy: {s}\n", .{source.source_publication_policy});
    try output.print(allocator, "source_after_report_digest: {s}\n", .{source.source_after_report_digest});
    try output.print(allocator, "source_consumer_after_digest: {s}\n", .{source.consumer_after_digest});
    try output.print(allocator, "json_output: {s}\n", .{paths.json_path});
    try output.print(allocator, "text_output: {s}\n\n", .{paths.text_path});

    try appendPolicyChecksText(allocator, &output, result.checks);
    try appendInterpretationRulesText(allocator, &output);
    try appendConsumptionScopesText(allocator, &output);
    try appendTextList(allocator, &output, "denied inference rules", denied_inference_rules);
    try appendTextList(allocator, &output, "source denied boundary claims", source.denied_boundary_claims);
    try appendTextList(allocator, &output, "source blocked claims", source.blocked_claims);
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
            "Use ready consumption policy as interpretation evidence only.",
            "Agents and the SolidJS workbench may consume bounded source ids guardrails denied claims and next-query guidance.",
            "Start read-only consumption evaluator work only as a separate branch; do not infer runtime integration mutation authority CI enforcement or production health.",
        },
        .blocked => &.{
            "Treat blocked consumption policy evidence as a stop sign.",
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
    const source_boundary_json = try readRequiredArtifact(init.io, allocator, options.boundary_path, error.MissingBoundaryInput);
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
    return "usage: zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-policy -- --from-boundary <consumption-boundary.json> approve|reject --reason <reason> [--by <actor>] [--policy <policy>] [--verified-command <command>]... [--out-prefix <path-prefix>]\n";
}

fn failUsage(err: anyerror) noreturn {
    std.debug.print("causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-policy error: {s}\n{s}", .{ @errorName(err), usage() });
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

fn readyConsumptionBoundaryJson() []const u8 {
    return
        \\{
        \\  "schema": "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-boundary.v1",
        \\  "schema_version": 1,
        \\  "mode": "record-applied",
        \\  "consumption_boundary_status": "applied",
        \\  "applied": true,
        \\  "ready_for_next_branch": true,
        \\  "mutation_authority": "record-only",
        \\  "source_consumption_readiness": "app-facing-ci-advisory-remediation-report-consumption-readiness.json",
        \\  "source_consumption_readiness_status": "ready",
        \\  "source_publication_policy": "app-facing-ci-advisory-remediation-report-publication-policy.json",
        \\  "source_after_report_digest": "sha256:source-after",
        \\  "consumer_after_digest": "sha256:consumer-after",
        \\  "consumer_changes": ["reviewed read-only consumer boundary"],
        \\  "before_evidence": ["before local read-only consumption boundary evidence"],
        \\  "after_evidence": ["after local read-only consumption boundary evidence"],
        \\  "boundary_checks": [
        \\    { "name": "source-readiness-ready", "status": "pass", "detail": "ready" },
        \\    { "name": "consumer-after-safe", "status": "pass", "detail": "safe" }
        \\  ],
        \\  "boundary_rules": ["Future consumption policy work may interpret applied boundary records for agents and the SolidJS workbench without creating mutation authority."],
        \\  "denied_boundary_claims": ["app-runtime-integration-proof", "mutation-authority"],
        \\  "source_consumer_profiles": [
        \\    { "id": "agent-readonly-context", "role": "agent-readonly", "consumption_enabled": true, "allowed_inputs": "source ids", "output_contract": "bounded context", "denied_claim": "mutation authority" }
        \\  ],
        \\  "source_readiness_dimensions": [
        \\    { "id": "bounded-query-expectations", "required": true, "evidence": "bounded ids" }
        \\  ],
        \\  "source_consumption_guardrails": [
        \\    { "id": "redacted-source-ids-only", "required_before_boundary": true, "reason": "no raw payload capture" }
        \\  ],
        \\  "source_denied_inference_rules": ["required-status-check", "app-runtime-integration-proof"],
        \\  "negative_fixtures": [
        \\    { "id": "unsafe-consumer-after-denied", "artifact_state": "runtime enabled", "decision": "deny", "failed_gate": "consumer-after-safe", "reason": "runtime denied" }
        \\  ],
        \\  "blocked_claims": ["app-runtime-integration-enabled", "mutation-authority-granted"],
        \\  "required_verification_commands": [
        \\    "bun run zigeffect:workbench:typecheck",
        \\    "bun run zigeffect:workbench:test",
        \\    "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-readiness",
        \\    "zig build causal-schema-governance -- --format json",
        \\    "zig build causal-production-hardening-backlog -- --format json",
        \\    "zig build examples",
        \\    "zig build test"
        \\  ],
        \\  "verified_commands": [
        \\    "bun run zigeffect:workbench:typecheck",
        \\    "bun run zigeffect:workbench:test",
        \\    "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-readiness",
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
        \\  "advisory_report": true,
        \\  "read_only_preview": true,
        \\  "read_only_consumption_enabled": true,
        \\  "solid_webui_enabled": true,
        \\  "solid_webui_renderer": "solidjs",
        \\  "webui_bridge": "webui-dev/zig-webui"
        \\}
    ;
}

test "app-facing advisory remediation report consumption policy schema and branch constants are stable" {
    try std.testing.expectEqualStrings(
        "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-policy.v1",
        schema,
    );
    try std.testing.expectEqual(@as(u32, 1), schema_version);
    try std.testing.expectEqualStrings(
        "codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-policy",
        source_branch,
    );
    try std.testing.expectEqualStrings(
        "start-app-facing-production-integration-ci-advisory-remediation-report-consumption-evaluator",
        recommendation,
    );
    try std.testing.expectEqualStrings(
        "codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-evaluator",
        next_branch_if_ready,
    );
}

test "parses app-facing advisory remediation report consumption policy approval and rejection options" {
    var approve_options = try parseOptions(std.testing.allocator, &.{
        "zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-policy",
        "--from-boundary",
        ".zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-boundary.json",
        "approve",
        "--reason",
        "consumption policy reviewed",
        "--by",
        "codex",
        "--policy",
        "manual-consumption-policy",
        "--verified-command",
        "zig build test",
        "--out-prefix",
        ".zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-policy",
    });
    defer approve_options.deinit(std.testing.allocator);

    try std.testing.expectEqual(Decision.approve, approve_options.decision);
    try std.testing.expectEqualStrings(".zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-boundary.json", approve_options.boundary_path);
    try std.testing.expectEqualStrings("consumption policy reviewed", approve_options.reason);
    try std.testing.expectEqualStrings("codex", approve_options.reviewed_by);
    try std.testing.expectEqualStrings("manual-consumption-policy", approve_options.policy);
    try std.testing.expectEqual(@as(usize, 1), approve_options.verified_commands.len);
    try std.testing.expectEqualStrings("zig build test", approve_options.verified_commands[0]);
    try std.testing.expectEqualStrings(".zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-policy", approve_options.out_prefix.?);

    var reject_options = try parseOptions(std.testing.allocator, &.{
        "zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-policy",
        "--from-boundary",
        ".zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-boundary.json",
        "reject",
        "--reason",
        "blocked consumption policy",
    });
    defer reject_options.deinit(std.testing.allocator);

    try std.testing.expectEqual(Decision.reject, reject_options.decision);
    try std.testing.expectEqualStrings("blocked consumption policy", reject_options.reason);
}

test "default output path replaces boundary suffix and compacts long names" {
    const paths = try defaultOutputPaths(
        std.testing.allocator,
        ".zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-boundary.json",
    );
    defer paths.deinit(std.testing.allocator);

    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-policy.json",
        paths.json_path,
    );
    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-policy.txt",
        paths.text_path,
    );

    const long_path =
        ".zig-cache/causal-artifacts/app-facing-production-integration-fixtures-readiness-review-implementation-proposal-app-facing-boundary-local-fixtures-nendb-handoff-fixtures-ci-advisory-remediation-report-consumption-boundary-with-extra-agent-workbench-policy-evaluator-handoff-context.json";
    const compact_paths = try defaultOutputPaths(std.testing.allocator, long_path);
    defer compact_paths.deinit(std.testing.allocator);

    try std.testing.expect(std.mem.indexOf(u8, compact_paths.json_path, compact_output_prefix_name) != null);
    try std.testing.expect(std.mem.endsWith(u8, compact_paths.json_path, ".json"));
}

test "approved and rejected consumption policy output preserve read-only authority" {
    const source_json = readyConsumptionBoundaryJson();

    var approve_options = try parseOptions(std.testing.allocator, &.{
        "tool",
        "--from-boundary",
        "source-consumption-boundary.json",
        "approve",
        "--reason",
        "consumption policy approved",
        "--verified-command",
        "bun run zigeffect:workbench:typecheck",
        "--verified-command",
        "bun run zigeffect:workbench:test",
        "--verified-command",
        "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-boundary",
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

    try std.testing.expect(std.mem.indexOf(u8, approve_reports.json, "\"consumption_policy_status\": \"ready\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, approve_reports.json, "\"ready_for_next_branch\": true") != null);
    try std.testing.expect(std.mem.indexOf(u8, approve_reports.json, "\"mutation_authority\": \"none\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, approve_reports.json, "\"app_runtime_integration_enabled\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, approve_reports.json, "\"nendb_adapter_execution_enabled\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, approve_reports.json, "\"id\": \"agent-bounded-context\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, approve_reports.json, "\"id\": \"future-consumption-evaluator-input\"") != null);

    var reject_options = try parseOptions(std.testing.allocator, &.{
        "tool",
        "--from-boundary",
        "source-consumption-boundary.json",
        "reject",
        "--reason",
        "consumption policy rejected",
    });
    defer reject_options.deinit(std.testing.allocator);

    const reject_reports = try formatReports(std.testing.allocator, .{
        .options = reject_options,
        .source_boundary_json = source_json,
    });
    defer reject_reports.deinit(std.testing.allocator);

    try std.testing.expect(std.mem.indexOf(u8, reject_reports.json, "\"consumption_policy_status\": \"blocked\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reject_reports.json, "\"ready_for_next_branch\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, reject_reports.text, "denied inference rules:") != null);
}

test "unsafe source and missing verification block approved consumption policy" {
    var options = try parseOptions(std.testing.allocator, &.{
        "tool",
        "--from-boundary",
        "source-consumption-boundary.json",
        "approve",
        "--reason",
        "consumption policy approved without verification",
    });
    defer options.deinit(std.testing.allocator);

    const missing_verification = try formatReports(std.testing.allocator, .{
        .options = options,
        .source_boundary_json = readyConsumptionBoundaryJson(),
    });
    defer missing_verification.deinit(std.testing.allocator);

    try std.testing.expect(std.mem.indexOf(u8, missing_verification.json, "\"consumption_policy_status\": \"blocked\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, missing_verification.json, "\"name\": \"required-verification-commands\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, missing_verification.json, "\"status\": \"fail\"") != null);

    const unsafe_source = try formatReports(std.testing.allocator, .{
        .options = options,
        .source_boundary_json =
            \\{
            \\  "schema": "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-boundary.v1",
            \\  "schema_version": 1,
            \\  "mode": "record-applied",
            \\  "consumption_boundary_status": "applied",
            \\  "applied": true,
            \\  "ready_for_next_branch": true,
            \\  "mutation_authority": "record-only",
            \\  "source_consumption_readiness": "readiness.json",
            \\  "source_consumption_readiness_status": "ready",
            \\  "source_publication_policy": "policy.json",
            \\  "source_after_report_digest": "sha256:source",
            \\  "consumer_after_digest": "sha256:consumer",
            \\  "consumer_changes": ["change"],
            \\  "before_evidence": ["before"],
            \\  "after_evidence": ["after"],
            \\  "boundary_rules": ["rule"],
            \\  "denied_boundary_claims": ["claim"],
            \\  "source_consumer_profiles": [{ "id": "agent", "consumption_enabled": true }],
            \\  "source_readiness_dimensions": [{ "id": "bounded-query", "required": true }],
            \\  "source_consumption_guardrails": [{ "id": "redaction", "required_before_boundary": true }],
            \\  "source_denied_inference_rules": ["no-runtime"],
            \\  "negative_fixtures": [{ "id": "negative", "decision": "deny", "failed_gate": "authority", "reason": "denied" }],
            \\  "blocked_claims": ["claim"],
            \\  "boundary_checks": [{ "name": "source", "status": "pass" }],
            \\  "required_verification_commands": ["zig build test"],
            \\  "verified_commands": ["zig build test"],
            \\  "app_runtime_integration_enabled": true,
            \\  "solid_webui_enabled": true,
            \\  "solid_webui_renderer": "solidjs",
            \\  "webui_bridge": "webui-dev/zig-webui",
            \\  "read_only_consumption_enabled": true
            \\}
        ,
    });
    defer unsafe_source.deinit(std.testing.allocator);

    try std.testing.expect(std.mem.indexOf(u8, unsafe_source.json, "\"name\": \"source-authority-disabled\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, unsafe_source.json, "\"consumption_policy_status\": \"blocked\"") != null);
}
