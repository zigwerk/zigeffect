const std = @import("std");

pub const schema = "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-readiness.v1";
pub const schema_version: u32 = 1;
pub const source_branch = "codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-readiness";
pub const recommendation = "start-app-facing-production-integration-ci-advisory-remediation-report-consumption-boundary";
pub const next_branch_if_ready = "codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-boundary";

const source_publication_policy_schema = "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-publication-policy.v1";
const generated_by = "causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-readiness";
const source_publication_policy_suffix = "-ci-advisory-remediation-report-publication-policy.json";
const output_prefix_suffix = "-ci-advisory-remediation-report-consumption-readiness";
const compact_output_prefix_name = "app-facing-production-integration-ci-advisory-remediation-report-consumption-readiness";
const max_default_output_file_name_len = 240;
const max_source_bytes = 1024 * 1024;

const required_verification_commands: []const []const u8 = &.{
    "bun run zigeffect:workbench:typecheck",
    "bun run zigeffect:workbench:test",
    "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-publication-policy",
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
const solid_webui_enabled = true;
const solid_webui_renderer = "solidjs";
const webui_bridge = "webui-dev/zig-webui";
const mutation_authority = "none";

const Decision = enum { approve, reject };
const ConsumptionReadinessStatus = enum { ready, blocked };
const CheckStatus = enum { pass, fail };

const Options = struct {
    publication_policy_path: []const u8,
    decision: Decision,
    reviewed_by: []const u8 = "app-facing-ci-advisory-remediation-report-consumption-readiness-reviewer",
    policy: []const u8 = "manual-app-facing-production-integration-ci-advisory-remediation-report-consumption-readiness",
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

const ReadinessInput = struct {
    options: Options,
    source_publication_policy_json: []const u8,
};

const ReadinessReports = struct {
    json: []const u8,
    text: []const u8,

    fn deinit(self: ReadinessReports, allocator: std.mem.Allocator) void {
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

const SourceInterpretationRule = struct {
    id: []const u8,
    consumer_role: []const u8 = "",
    allowed_use: []const u8 = "",
    failure_effect: []const u8 = "",
    denied_claim: []const u8 = "",
};

const SourcePublicationSurface = struct {
    id: []const u8,
    visibility_class: []const u8 = "",
    executed_by_tool: bool = false,
    interpretation_scope: []const u8 = "",
};

const SourceNegativeFixture = struct {
    id: []const u8 = "",
    artifact_state: []const u8 = "",
    decision: []const u8 = "",
    failed_gate: []const u8 = "",
    reason: []const u8 = "",
};

const PublicationPolicyArtifact = struct {
    schema: []const u8,
    schema_version: u32,
    source_application_boundary: []const u8 = "",
    source_report_application_status: []const u8 = "",
    source_mode: []const u8 = "",
    source_applied: bool = false,
    source_mutation_authority: []const u8 = "",
    source_after_report_digest: []const u8 = "",
    decision: []const u8,
    ci_advisory_remediation_report_publication_policy_status: []const u8,
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
    github_step_summary_write_enabled: bool = false,
    pull_request_comment_enabled: bool = false,
    github_api_mutation_enabled: bool = false,
    app_mutation_controls_enabled: bool = false,
    app_mutation_enabled: bool = false,
    app_config_write_enabled: bool = false,
    app_data_write_enabled: bool = false,
    app_runtime_integration_enabled: bool = false,
    agent_query_live_projection_enabled: bool = false,
    raw_payload_capture_enabled: bool = false,
    deployment_mutation_enabled: bool = false,
    production_telemetry_ingestion: bool = false,
    live_exporter_enabled: bool = false,
    network_send_enabled: bool = false,
    collector_endpoint_configured: bool = false,
    otlp_serialization_enabled: bool = false,
    runtime_pipeline_enabled: bool = false,
    durable_write_enabled: bool = false,
    nendb_write_enabled: bool = false,
    nendb_adapter_execution_enabled: bool = false,
    advisory_report: bool = false,
    read_only_preview: bool = false,
    solid_webui_enabled: bool = false,
    solid_webui_renderer: []const u8 = "",
    webui_bridge: []const u8 = "",
    mutation_authority: []const u8,
    policy_checks: []const SourceCheck = &.{},
    interpretation_rules: []const SourceInterpretationRule = &.{},
    publication_surfaces: []const SourcePublicationSurface = &.{},
    denied_inference_rules: []const []const u8 = &.{},
    negative_fixtures: []const SourceNegativeFixture = &.{},
    blocked_claims: []const []const u8 = &.{},
    required_verification_commands: []const []const u8 = &.{},
    verified_commands: []const []const u8 = &.{},
    source_branch: []const u8 = "",
    recommendation: []const u8 = "",
    next_branch_if_ready: []const u8 = "",
};

const ReadinessCheck = struct {
    name: []const u8,
    status: CheckStatus,
    detail: []const u8,
};

const ReadinessResult = struct {
    status: ConsumptionReadinessStatus,
    ready_for_next_branch: bool,
    checks: []const ReadinessCheck,

    fn deinit(self: ReadinessResult, allocator: std.mem.Allocator) void {
        if (self.checks.len > 0) allocator.free(self.checks);
    }
};

const ConsumerProfile = struct {
    id: []const u8,
    role: []const u8,
    consumption_enabled: bool,
    allowed_inputs: []const u8,
    output_contract: []const u8,
    denied_claim: []const u8,
};

const ReadinessDimension = struct {
    id: []const u8,
    required: bool,
    evidence: []const u8,
};

const ConsumptionGuardrail = struct {
    id: []const u8,
    required_before_boundary: bool,
    reason: []const u8,
};

const NegativeFixture = struct {
    id: []const u8,
    artifact_state: []const u8,
    decision: []const u8,
    failed_gate: []const u8,
    reason: []const u8,
};

const consumer_profiles: []const ConsumerProfile = &.{
    .{ .id = "reviewer-triage-consumer", .role = "maintainer", .consumption_enabled = true, .allowed_inputs = "source ids checks denied claims and after-report digest", .output_contract = "human triage summary with no merge blocking", .denied_claim = "required status check" },
    .{ .id = "agent-readonly-consumer", .role = "agent-readonly", .consumption_enabled = true, .allowed_inputs = "bounded source refs findings checks and next-query hints", .output_contract = "bounded agent context with cited evidence ids", .denied_claim = "mutation authority" },
    .{ .id = "ci-advisory-consumer", .role = "ci-reviewer", .consumption_enabled = true, .allowed_inputs = "advisory status checks and denied CI claims", .output_contract = "non-blocking advisory context only", .denied_claim = "merge blocker" },
    .{ .id = "solid-webui-consumer", .role = "workbench-viewer", .consumption_enabled = true, .allowed_inputs = "redacted local JSON policy evidence and carried blocked claims", .output_contract = "SolidJS webui read-only view model", .denied_claim = "app mutation" },
    .{ .id = "future-consumption-boundary-input", .role = "future-consumption-boundary-tool", .consumption_enabled = true, .allowed_inputs = "ready consumption-readiness artifact", .output_contract = "record-only consumption boundary input", .denied_claim = "app runtime integration" },
};

const readiness_dimensions: []const ReadinessDimension = &.{
    .{ .id = "source-publication-policy-ready", .required = true, .evidence = "ready app-facing advisory report publication-policy artifact" },
    .{ .id = "bounded-agent-query-contract", .required = true, .evidence = "agents consume bounded ids findings checks and next-query hints only" },
    .{ .id = "source-id-citation-required", .required = true, .evidence = "consumers cite source policy application boundary and after-report digest" },
    .{ .id = "redaction-retention-reviewed", .required = true, .evidence = "consumed artifacts remain redacted and local-retention bounded" },
    .{ .id = "solid-webui-readonly-surface", .required = true, .evidence = "SolidJS webui surface is read-only and local" },
    .{ .id = "denied-claim-carryover", .required = true, .evidence = "source blocked claims and denied inference rules are preserved" },
    .{ .id = "no-runtime-integration", .required = true, .evidence = "consumption readiness does not connect to app runtime or live projections" },
    .{ .id = "no-storage-execution", .required = true, .evidence = "consumption readiness does not write NenDB or execute a NenDB adapter" },
};

const consumption_guardrails: []const ConsumptionGuardrail = &.{
    .{ .id = "bounded-source-ids-only", .required_before_boundary = true, .reason = "agents must consume bounded ids and evidence refs, not raw payloads" },
    .{ .id = "redacted-local-artifacts", .required_before_boundary = true, .reason = "workbench consumption must use redacted local artifacts" },
    .{ .id = "no-required-status-check", .required_before_boundary = true, .reason = "app-facing advisory consumption cannot become CI enforcement" },
    .{ .id = "no-github-api-mutation", .required_before_boundary = true, .reason = "this tool never calls GitHub or mutates workflows" },
    .{ .id = "no-app-mutation", .required_before_boundary = true, .reason = "consumption readiness does not write app config or app data" },
    .{ .id = "no-app-runtime-integration", .required_before_boundary = true, .reason = "live app runtime integration requires a later reviewed branch" },
    .{ .id = "no-live-agent-projection", .required_before_boundary = true, .reason = "agents receive artifact evidence, not live projections" },
    .{ .id = "no-nendb-write-or-adapter-execution", .required_before_boundary = true, .reason = "NenDB remains future adapter work and is not executed here" },
    .{ .id = "solid-webui-only", .required_before_boundary = true, .reason = "workbench direction remains SolidJS inside webui-dev/zig-webui" },
    .{ .id = "no-mutation-authority", .required_before_boundary = true, .reason = "mutation authority remains none until a later reviewed boundary grants it" },
};

const denied_inference_rules: []const []const u8 = &.{
    "required-status-check-active",
    "merge-blocker-active",
    "branch-protection-updated",
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
    "live-telemetry-coverage-proof",
    "durable-write-proof",
    "nendb-write-proof",
    "nendb-adapter-execution-proof",
    "non-nendb-durable-adapter",
    "cockroach-adapter-work",
    "react-renderer",
    "alternate-renderer",
    "auto-apply-proof",
    "mutation-authority",
};

const negative_fixtures: []const NegativeFixture = &.{
    .{ .id = "blocked-source-policy-denied", .artifact_state = "consumption_readiness_status=blocked", .decision = "deny", .failed_gate = "source-policy-ready", .reason = "blocked publication policy cannot feed consumption readiness" },
    .{ .id = "missing-consumer-profile-denied", .artifact_state = "consumer_profiles=[]", .decision = "deny", .failed_gate = "consumer-profiles-present", .reason = "readiness must name read-only consumer profiles" },
    .{ .id = "unbounded-agent-query-denied", .artifact_state = "agent_query=unbounded", .decision = "deny", .failed_gate = "readiness-dimensions-present", .reason = "agent consumption must be bounded" },
    .{ .id = "raw-payload-capture-denied", .artifact_state = "raw_payload_capture_enabled=true", .decision = "deny", .failed_gate = "source-app-authority-disabled", .reason = "raw payload capture is out of scope" },
    .{ .id = "live-projection-denied", .artifact_state = "agent_query_live_projection_enabled=true", .decision = "deny", .failed_gate = "source-app-authority-disabled", .reason = "live agent projections are out of scope" },
    .{ .id = "app-runtime-integration-denied", .artifact_state = "app_runtime_integration_enabled=true", .decision = "deny", .failed_gate = "source-app-authority-disabled", .reason = "consumption readiness is not runtime integration" },
    .{ .id = "app-mutation-denied", .artifact_state = "app_mutation_enabled=true", .decision = "deny", .failed_gate = "source-app-authority-disabled", .reason = "consumption readiness cannot mutate apps" },
    .{ .id = "required-status-check-denied", .artifact_state = "ci_required_status_check_enabled=true", .decision = "deny", .failed_gate = "source-ci-enforcement-disabled", .reason = "app-facing advisory consumption cannot require checks" },
    .{ .id = "nendb-adapter-execution-denied", .artifact_state = "nendb_adapter_execution_enabled=true", .decision = "deny", .failed_gate = "source-runtime-and-storage-disabled", .reason = "this tool does not execute the NenDB adapter" },
    .{ .id = "production-health-claim-denied", .artifact_state = "production_health=proven", .decision = "deny", .failed_gate = "source-policy-ready", .reason = "advisory report consumption is not production health evidence" },
    .{ .id = "mutation-authority-claim-denied", .artifact_state = "mutation_authority=granted", .decision = "deny", .failed_gate = "source-policy-ready", .reason = "consumption readiness grants no mutation authority" },
    .{ .id = "alternate-renderer-denied", .artifact_state = "renderer=react", .decision = "deny", .failed_gate = "source-solid-webui-readonly", .reason = "workbench direction remains SolidJS inside zig-webui" },
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
        error.MissingPublicationPolicyInput => failUsage(err),
        else => return err,
    };
}

fn parseOptions(allocator: std.mem.Allocator, args: []const []const u8) !Options {
    if (args.len < 2) return error.MissingPublicationPolicyPath;
    if (!std.mem.eql(u8, args[1], "--from-publication-policy")) return error.UnknownFlag;
    if (args.len < 3) return error.MissingPublicationPolicyPath;
    const publication_policy_path = args[2];
    if (!std.mem.endsWith(u8, publication_policy_path, ".json")) return error.InvalidPublicationPolicyPath;
    if (args.len < 4) return error.MissingDecision;
    const decision = try parseDecision(args[3]);

    var reviewed_by: []const u8 = "app-facing-ci-advisory-remediation-report-consumption-readiness-reviewer";
    var policy: []const u8 = "manual-app-facing-production-integration-ci-advisory-remediation-report-consumption-readiness";
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
        .publication_policy_path = publication_policy_path,
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

fn readinessStatusText(status: ConsumptionReadinessStatus) []const u8 {
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
    else
        try defaultOutputPrefix(allocator, options.publication_policy_path);
    defer allocator.free(prefix);

    return .{
        .json_path = try std.fmt.allocPrint(allocator, "{s}.json", .{prefix}),
        .text_path = try std.fmt.allocPrint(allocator, "{s}.txt", .{prefix}),
    };
}

fn defaultOutputPrefix(allocator: std.mem.Allocator, publication_policy_path: []const u8) ![]const u8 {
    if (!std.mem.endsWith(u8, publication_policy_path, ".json")) return error.InvalidPublicationPolicyPath;

    const base = if (std.mem.endsWith(u8, publication_policy_path, source_publication_policy_suffix))
        publication_policy_path[0 .. publication_policy_path.len - source_publication_policy_suffix.len]
    else
        publication_policy_path[0 .. publication_policy_path.len - ".json".len];
    const candidate = try std.fmt.allocPrint(allocator, "{s}{s}", .{ base, output_prefix_suffix });
    errdefer allocator.free(candidate);

    if (fileName(candidate).len + ".json".len <= max_default_output_file_name_len) {
        return candidate;
    }

    const directory = directoryPrefix(candidate);
    const digest = shortPathDigest(publication_policy_path);
    const compact_prefix = try std.fmt.allocPrint(allocator, "{s}{s}-{s}", .{ directory, compact_output_prefix_name, digest[0..] });
    allocator.free(candidate);
    return compact_prefix;
}

fn formatReports(allocator: std.mem.Allocator, input: ReadinessInput) !ReadinessReports {
    var parsed = try std.json.parseFromSlice(PublicationPolicyArtifact, allocator, input.source_publication_policy_json, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();

    const paths = try outputPathsForOptions(allocator, input.options);
    defer paths.deinit(allocator);

    const result = try evaluateReadiness(allocator, input.options, parsed.value);
    defer result.deinit(allocator);

    const json = try formatReadinessJson(allocator, input.options, parsed.value, result, paths);
    errdefer allocator.free(json);
    const text = try formatReadinessText(allocator, input.options, parsed.value, result, paths);
    errdefer allocator.free(text);

    return .{ .json = json, .text = text };
}

fn evaluateReadiness(
    allocator: std.mem.Allocator,
    options: Options,
    source: PublicationPolicyArtifact,
) !ReadinessResult {
    var checks = std.ArrayList(ReadinessCheck).empty;
    errdefer checks.deinit(allocator);

    try appendCheck(allocator, &checks, "source-schema", if (std.mem.eql(u8, source.schema, source_publication_policy_schema) and source.schema_version == 1) .pass else .fail, "source app-facing advisory report publication-policy schema is supported");
    try appendCheck(allocator, &checks, "source-policy-ready", if (sourcePolicyReady(source)) .pass else .fail, "source publication policy is approved ready and ready for next branch");
    try appendCheck(allocator, &checks, "source-evidence-present", if (sourceEvidencePresent(source)) .pass else .fail, "source publication policy carries application-boundary and after-report digest refs");
    try appendCheck(allocator, &checks, "source-policy-checks-passed", if (sourceChecksPassed(source.policy_checks)) .pass else .fail, "source policy checks contain no failures");
    try appendCheck(allocator, &checks, "source-ci-enforcement-disabled", if (sourceCiEnforcementDisabled(source)) .pass else .fail, "source keeps CI gate enforcement required checks and workflow mutation disabled");
    try appendCheck(allocator, &checks, "source-publication-execution-disabled", if (sourcePublicationExecutionDisabled(source)) .pass else .fail, "source does not claim tool-executed publication summary comment or upload behavior");
    try appendCheck(allocator, &checks, "source-app-authority-disabled", if (sourceAppAuthorityDisabled(source)) .pass else .fail, "source keeps app mutation runtime integration live projection and raw payload capture disabled");
    try appendCheck(allocator, &checks, "source-runtime-and-storage-disabled", if (sourceRuntimeAndStorageDisabled(source)) .pass else .fail, "source keeps live telemetry network runtime durable NenDB writes and NenDB adapter execution disabled");
    try appendCheck(allocator, &checks, "source-solid-webui-readonly", if (sourceSolidWebuiReadonly(source)) .pass else .fail, "source remains SolidJS webui read-only evidence");
    try appendCheck(allocator, &checks, "source-interpretation-catalogs-present", if (sourceCatalogsPresent(source)) .pass else .fail, "source interpretation publication denied negative and blocked catalogs are present");
    try appendCheck(allocator, &checks, "consumer-profiles-present", if (consumerProfilesComplete()) .pass else .fail, "read-only consumer profile catalog is complete");
    try appendCheck(allocator, &checks, "readiness-dimensions-present", if (readinessDimensionsComplete()) .pass else .fail, "consumption readiness dimensions are complete");
    try appendCheck(allocator, &checks, "consumption-guardrails-present", if (consumptionGuardrailsComplete()) .pass else .fail, "consumption guardrails denied rules and negative fixtures are complete");
    try appendCheck(allocator, &checks, "required-verification-recorded", if (verifiedCommandsContainAll(options.verified_commands, required_verification_commands)) .pass else .fail, "readiness recorded every required verification command");
    try appendCheck(allocator, &checks, "decision-approved", if (options.decision == .approve) .pass else .fail, "reviewer approved consumption readiness");

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
    checks: *std.ArrayList(ReadinessCheck),
    name: []const u8,
    status: CheckStatus,
    detail: []const u8,
) !void {
    try checks.append(allocator, .{ .name = name, .status = status, .detail = detail });
}

fn allChecksPassed(checks: []const ReadinessCheck) bool {
    for (checks) |check| {
        if (check.status != .pass) return false;
    }
    return true;
}

fn sourcePolicyReady(source: PublicationPolicyArtifact) bool {
    return std.mem.eql(u8, source.decision, "approve") and
        std.mem.eql(u8, source.ci_advisory_remediation_report_publication_policy_status, "ready") and
        source.ready_for_next_branch and
        std.mem.eql(u8, source.mutation_authority, "none");
}

fn sourceEvidencePresent(source: PublicationPolicyArtifact) bool {
    return source.source_application_boundary.len > 0 and
        source.source_after_report_digest.len > 0 and
        source.source_applied and
        std.mem.eql(u8, source.source_mutation_authority, "record-only");
}

fn sourceChecksPassed(checks: []const SourceCheck) bool {
    if (checks.len == 0) return false;
    for (checks) |check| {
        if (std.mem.eql(u8, check.status, "fail")) return false;
    }
    return true;
}

fn sourcePublicationExecutionDisabled(source: PublicationPolicyArtifact) bool {
    return !source.ci_report_publication_enabled and
        !source.github_step_summary_write_enabled and
        !source.pull_request_comment_enabled and
        !source.ci_upload_execution_enabled and
        !source.github_api_mutation_enabled;
}

fn sourceCiEnforcementDisabled(source: PublicationPolicyArtifact) bool {
    return !source.ci_gate_enabled and
        !source.ci_gate_enforcement_enabled and
        !source.ci_required_status_check_enabled and
        !source.ci_workflow_mutation_enabled;
}

fn sourceAppAuthorityDisabled(source: PublicationPolicyArtifact) bool {
    return !source.app_mutation_controls_enabled and
        !source.app_mutation_enabled and
        !source.app_config_write_enabled and
        !source.app_data_write_enabled and
        !source.deployment_mutation_enabled and
        !source.app_runtime_integration_enabled and
        !source.agent_query_live_projection_enabled and
        !source.raw_payload_capture_enabled;
}

fn sourceRuntimeAndStorageDisabled(source: PublicationPolicyArtifact) bool {
    return !source.production_telemetry_ingestion and
        !source.live_exporter_enabled and
        !source.network_send_enabled and
        !source.collector_endpoint_configured and
        !source.otlp_serialization_enabled and
        !source.runtime_pipeline_enabled and
        !source.durable_write_enabled and
        !source.nendb_write_enabled and
        !source.nendb_adapter_execution_enabled;
}

fn sourceSolidWebuiReadonly(source: PublicationPolicyArtifact) bool {
    return source.advisory_report and
        source.read_only_preview and
        source.solid_webui_enabled and
        std.mem.eql(u8, source.solid_webui_renderer, solid_webui_renderer) and
        std.mem.eql(u8, source.webui_bridge, webui_bridge);
}

fn sourceCatalogsPresent(source: PublicationPolicyArtifact) bool {
    return source.interpretation_rules.len > 0 and
        source.publication_surfaces.len > 0 and
        source.denied_inference_rules.len > 0 and
        source.negative_fixtures.len > 0 and
        source.blocked_claims.len > 0 and
        source.required_verification_commands.len > 0 and
        source.verified_commands.len > 0 and
        containsString(source.denied_inference_rules, "required-status-check") and
        containsString(source.denied_inference_rules, "app-runtime-integration-proof") and
        containsString(source.denied_inference_rules, "nendb-adapter-execution-proof");
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

fn consumerProfilesComplete() bool {
    return hasConsumerProfile("reviewer-triage-consumer") and
        hasConsumerProfile("agent-readonly-consumer") and
        hasConsumerProfile("ci-advisory-consumer") and
        hasConsumerProfile("solid-webui-consumer") and
        hasConsumerProfile("future-consumption-boundary-input");
}

fn readinessDimensionsComplete() bool {
    return hasReadinessDimension("source-publication-policy-ready") and
        hasReadinessDimension("bounded-agent-query-contract") and
        hasReadinessDimension("source-id-citation-required") and
        hasReadinessDimension("redaction-retention-reviewed") and
        hasReadinessDimension("solid-webui-readonly-surface") and
        hasReadinessDimension("denied-claim-carryover") and
        hasReadinessDimension("no-runtime-integration") and
        hasReadinessDimension("no-storage-execution");
}

fn consumptionGuardrailsComplete() bool {
    return hasConsumptionGuardrail("bounded-source-ids-only") and
        hasConsumptionGuardrail("no-required-status-check") and
        hasConsumptionGuardrail("no-app-runtime-integration") and
        hasConsumptionGuardrail("no-nendb-write-or-adapter-execution") and
        hasConsumptionGuardrail("solid-webui-only") and
        hasConsumptionGuardrail("no-mutation-authority") and
        containsString(denied_inference_rules, "app-runtime-integration-proof") and
        containsString(denied_inference_rules, "nendb-adapter-execution-proof") and
        hasNegativeFixture("unbounded-agent-query-denied") and
        hasNegativeFixture("mutation-authority-claim-denied");
}

fn hasConsumerProfile(id: []const u8) bool {
    for (consumer_profiles) |profile| {
        if (std.mem.eql(u8, profile.id, id) and profile.consumption_enabled) return true;
    }
    return false;
}

fn hasReadinessDimension(id: []const u8) bool {
    for (readiness_dimensions) |dimension| {
        if (std.mem.eql(u8, dimension.id, id) and dimension.required) return true;
    }
    return false;
}

fn hasConsumptionGuardrail(id: []const u8) bool {
    for (consumption_guardrails) |guardrail| {
        if (std.mem.eql(u8, guardrail.id, id) and guardrail.required_before_boundary) return true;
    }
    return false;
}

fn hasNegativeFixture(id: []const u8) bool {
    for (negative_fixtures) |fixture| {
        if (std.mem.eql(u8, fixture.id, id)) return true;
    }
    return false;
}

fn formatReadinessJson(
    allocator: std.mem.Allocator,
    options: Options,
    source: PublicationPolicyArtifact,
    result: ReadinessResult,
    paths: OutputPaths,
) ![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "{\n");
    try appendJsonField(allocator, &output, "schema", schema, true);
    try output.appendSlice(allocator, "  \"schema_version\": 1,\n");
    try appendJsonField(allocator, &output, "generated_by", generated_by, true);
    try appendJsonField(allocator, &output, "source_publication_policy", options.publication_policy_path, true);
    try appendJsonField(allocator, &output, "source_publication_policy_status", source.ci_advisory_remediation_report_publication_policy_status, true);
    try appendJsonField(allocator, &output, "source_policy_decision", source.decision, true);
    try output.print(allocator, "  \"source_policy_ready_for_next_branch\": {},\n", .{source.ready_for_next_branch});
    try appendJsonField(allocator, &output, "source_mutation_authority", source.mutation_authority, true);
    try appendJsonField(allocator, &output, "source_after_report_digest", source.source_after_report_digest, true);
    try appendJsonField(allocator, &output, "decision", decisionText(options.decision), true);
    try appendJsonField(allocator, &output, "consumption_readiness_status", readinessStatusText(result.status), true);
    try output.print(allocator, "  \"ready_for_next_branch\": {},\n", .{result.ready_for_next_branch});
    try appendJsonField(allocator, &output, "reviewed_by", options.reviewed_by, true);
    try appendJsonField(allocator, &output, "policy", options.policy, true);
    try appendJsonField(allocator, &output, "reason", options.reason, true);
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
    try output.print(allocator, "  \"runtime_pipeline_enabled\": {},\n", .{runtime_pipeline_enabled});
    try output.print(allocator, "  \"durable_write_enabled\": {},\n", .{durable_write_enabled});
    try output.print(allocator, "  \"nendb_write_enabled\": {},\n", .{nendb_write_enabled});
    try output.print(allocator, "  \"nendb_adapter_execution_enabled\": {},\n", .{nendb_adapter_execution_enabled});
    try output.print(allocator, "  \"advisory_report\": {},\n", .{advisory_report});
    try output.print(allocator, "  \"read_only_preview\": {},\n", .{read_only_preview});
    try output.print(allocator, "  \"solid_webui_enabled\": {},\n", .{solid_webui_enabled});
    try appendJsonField(allocator, &output, "solid_webui_renderer", solid_webui_renderer, true);
    try appendJsonField(allocator, &output, "webui_bridge", webui_bridge, true);
    try appendJsonField(allocator, &output, "mutation_authority", mutation_authority, true);
    try output.appendSlice(allocator, "  \"readiness_checks\": ");
    try appendChecksJson(allocator, &output, result.checks);
    try output.appendSlice(allocator, ",\n  \"consumer_profiles\": ");
    try appendConsumerProfilesJson(allocator, &output);
    try output.appendSlice(allocator, ",\n  \"readiness_dimensions\": ");
    try appendReadinessDimensionsJson(allocator, &output);
    try output.appendSlice(allocator, ",\n  \"consumption_guardrails\": ");
    try appendConsumptionGuardrailsJson(allocator, &output);
    try output.appendSlice(allocator, ",\n  \"denied_inference_rules\": ");
    try appendStringArray(allocator, &output, denied_inference_rules);
    try output.appendSlice(allocator, ",\n  \"negative_fixtures\": ");
    try appendNegativeFixturesJson(allocator, &output);
    try output.appendSlice(allocator, ",\n  \"blocked_claims\": ");
    try appendStringArray(allocator, &output, blockedClaims(source));
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

fn formatReadinessText(
    allocator: std.mem.Allocator,
    options: Options,
    source: PublicationPolicyArtifact,
    result: ReadinessResult,
    paths: OutputPaths,
) ![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "zigeffect app-facing CI advisory remediation report consumption readiness\n");
    try output.print(allocator, "schema: {s}\n", .{schema});
    try output.print(allocator, "source publication policy: {s}\n", .{options.publication_policy_path});
    try output.print(allocator, "source publication policy status: {s}\n", .{source.ci_advisory_remediation_report_publication_policy_status});
    try output.print(allocator, "source policy decision: {s}\n", .{source.decision});
    try output.print(allocator, "source policy ready for next branch: {}\n", .{source.ready_for_next_branch});
    try output.print(allocator, "source mutation authority: {s}\n", .{source.mutation_authority});
    try output.print(allocator, "source after report digest: {s}\n", .{source.source_after_report_digest});
    try output.print(allocator, "decision: {s}\n", .{decisionText(options.decision)});
    try output.print(allocator, "consumption_readiness_status: {s}\n", .{readinessStatusText(result.status)});
    try output.print(allocator, "ready_for_next_branch: {}\n", .{result.ready_for_next_branch});
    try output.print(allocator, "ci required status check enabled: {}\n", .{ci_required_status_check_enabled});
    try output.print(allocator, "github api mutation enabled: {}\n", .{github_api_mutation_enabled});
    try output.print(allocator, "app mutation enabled: {}\n", .{app_mutation_enabled});
    try output.print(allocator, "app runtime integration enabled: {}\n", .{app_runtime_integration_enabled});
    try output.print(allocator, "agent query live projection enabled: {}\n", .{agent_query_live_projection_enabled});
    try output.print(allocator, "raw payload capture enabled: {}\n", .{raw_payload_capture_enabled});
    try output.print(allocator, "nendb adapter execution enabled: {}\n", .{nendb_adapter_execution_enabled});
    try output.print(allocator, "solid webui renderer: {s}\n", .{solid_webui_renderer});
    try output.print(allocator, "webui bridge: {s}\n", .{webui_bridge});
    try output.print(allocator, "mutation_authority: {s}\n", .{mutation_authority});
    try output.print(allocator, "reviewed_by: {s}\n", .{options.reviewed_by});
    try output.print(allocator, "policy: {s}\n", .{options.policy});
    try output.print(allocator, "reason: {s}\n", .{options.reason});
    try output.print(allocator, "source branch: {s}\n", .{source_branch});
    try output.print(allocator, "recommendation: {s}\n", .{recommendation});
    try output.print(allocator, "next branch if ready: {s}\n", .{next_branch_if_ready});
    try output.print(allocator, "json output: {s}\n", .{paths.json_path});
    try output.print(allocator, "text output: {s}\n\n", .{paths.text_path});

    try output.appendSlice(allocator, "readiness checks:\n");
    for (result.checks) |check| {
        try output.print(allocator, "- {s}: {s} - {s}\n", .{ check.name, checkStatusText(check.status), check.detail });
    }
    try output.append(allocator, '\n');

    try appendConsumerProfilesText(allocator, &output);
    try appendReadinessDimensionsText(allocator, &output);
    try appendConsumptionGuardrailsText(allocator, &output);
    try appendTextList(allocator, &output, "denied inference rules", denied_inference_rules);
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

fn appendChecksJson(allocator: std.mem.Allocator, output: *std.ArrayList(u8), checks: []const ReadinessCheck) !void {
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

fn appendConsumerProfilesJson(allocator: std.mem.Allocator, output: *std.ArrayList(u8)) !void {
    try output.append(allocator, '[');
    for (consumer_profiles, 0..) |profile, index| {
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

fn appendReadinessDimensionsJson(allocator: std.mem.Allocator, output: *std.ArrayList(u8)) !void {
    try output.append(allocator, '[');
    for (readiness_dimensions, 0..) |dimension, index| {
        if (index > 0) try output.appendSlice(allocator, ", ");
        try output.appendSlice(allocator, "{ \"id\": ");
        try appendJsonString(allocator, output, dimension.id);
        try output.print(allocator, ", \"required\": {}, \"evidence\": ", .{dimension.required});
        try appendJsonString(allocator, output, dimension.evidence);
        try output.appendSlice(allocator, " }");
    }
    try output.append(allocator, ']');
}

fn appendConsumptionGuardrailsJson(allocator: std.mem.Allocator, output: *std.ArrayList(u8)) !void {
    try output.append(allocator, '[');
    for (consumption_guardrails, 0..) |guardrail, index| {
        if (index > 0) try output.appendSlice(allocator, ", ");
        try output.appendSlice(allocator, "{ \"id\": ");
        try appendJsonString(allocator, output, guardrail.id);
        try output.print(allocator, ", \"required_before_boundary\": {}, \"reason\": ", .{guardrail.required_before_boundary});
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

fn appendConsumerProfilesText(allocator: std.mem.Allocator, output: *std.ArrayList(u8)) !void {
    try output.appendSlice(allocator, "consumer profiles:\n");
    for (consumer_profiles) |profile| {
        try output.print(allocator, "- {s}: role={s}, enabled={}, denied={s}\n", .{ profile.id, profile.role, profile.consumption_enabled, profile.denied_claim });
    }
    try output.append(allocator, '\n');
}

fn appendReadinessDimensionsText(allocator: std.mem.Allocator, output: *std.ArrayList(u8)) !void {
    try output.appendSlice(allocator, "readiness dimensions:\n");
    for (readiness_dimensions) |dimension| {
        try output.print(allocator, "- {s}: required={}, evidence={s}\n", .{ dimension.id, dimension.required, dimension.evidence });
    }
    try output.append(allocator, '\n');
}

fn appendConsumptionGuardrailsText(allocator: std.mem.Allocator, output: *std.ArrayList(u8)) !void {
    try output.appendSlice(allocator, "consumption guardrails:\n");
    for (consumption_guardrails) |guardrail| {
        try output.print(allocator, "- {s}: required_before_boundary={}, reason={s}\n", .{ guardrail.id, guardrail.required_before_boundary, guardrail.reason });
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

fn blockedClaims(source: PublicationPolicyArtifact) []const []const u8 {
    if (source.blocked_claims.len > 0) return source.blocked_claims;
    return denied_inference_rules;
}

fn agentGuidance(status: ConsumptionReadinessStatus) []const []const u8 {
    return switch (status) {
        .ready => &.{
            "Use ready consumption readiness as read-only input for agents reviewers CI advisory views and SolidJS webui only.",
            "Consumers must cite source ids checks denied claims and after-report digest while avoiding raw payloads and live projections.",
            "Start the guarded consumption boundary branch before wiring any app or workbench consumer to this evidence.",
        },
        .blocked => &.{
            "Treat blocked consumption readiness evidence as a stop sign.",
            "Repair source publication policy readiness consumer catalogs guardrails or verification proof before continuing.",
            "Do not infer app runtime integration mutation authority required checks NenDB writes adapter execution production health or live projection from blocked readiness evidence.",
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
    const source_publication_policy_json = try readRequiredArtifact(init.io, allocator, options.publication_policy_path, error.MissingPublicationPolicyInput);
    defer allocator.free(source_publication_policy_json);

    const reports = try formatReports(allocator, .{
        .options = options,
        .source_publication_policy_json = source_publication_policy_json,
    });
    defer reports.deinit(allocator);

    const paths = try outputPathsForOptions(allocator, options);
    defer paths.deinit(allocator);

    try writeArtifact(init.io, paths.json_path, reports.json);
    try writeArtifact(init.io, paths.text_path, reports.text);
    std.debug.print("{s}", .{reports.text});
}

fn usage() []const u8 {
    return "usage: zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-readiness -- --from-publication-policy <advisory-ci-report-publication-policy.json> approve|reject --reason <reason> [--by <actor>] [--policy <policy>] [--verified-command <command>]... [--out-prefix <path-prefix>]\n";
}

fn failUsage(err: anyerror) noreturn {
    std.debug.print("causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-readiness error: {s}\n{s}", .{ @errorName(err), usage() });
    std.process.exit(2);
}

fn freeSliceOnly(allocator: std.mem.Allocator, values: []const []const u8) void {
    if (values.len > 0) allocator.free(values);
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

test "app-facing advisory remediation report consumption readiness schema and branch constants are stable" {
    try std.testing.expectEqualStrings("zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-readiness.v1", schema);
    try std.testing.expectEqual(@as(u32, 1), schema_version);
    try std.testing.expectEqualStrings("codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-readiness", source_branch);
    try std.testing.expectEqualStrings("start-app-facing-production-integration-ci-advisory-remediation-report-consumption-boundary", recommendation);
    try std.testing.expectEqualStrings("codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-boundary", next_branch_if_ready);
    try std.testing.expect(containsString(required_verification_commands, "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-publication-policy"));
    try std.testing.expect(containsString(required_verification_commands, "bun run zigeffect:workbench:typecheck"));
}

test "parses app-facing advisory remediation report consumption readiness approval and rejection options" {
    var approve_options = try parseOptions(std.testing.allocator, &.{
        "zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-readiness",
        "--from-publication-policy",
        ".zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-publication-policy.json",
        "approve",
        "--reason",
        "app-facing advisory report consumption readiness reviewed",
        "--by",
        "codex",
        "--policy",
        "manual-app-facing-production-integration-ci-advisory-remediation-report-consumption-readiness",
        "--verified-command",
        "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-publication-policy",
        "--out-prefix",
        ".zig-cache/causal-artifacts/custom-consumption-readiness",
    });
    defer approve_options.deinit(std.testing.allocator);

    try std.testing.expectEqual(Decision.approve, approve_options.decision);
    try std.testing.expectEqualStrings(".zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-publication-policy.json", approve_options.publication_policy_path);
    try std.testing.expectEqualStrings("codex", approve_options.reviewed_by);
    try std.testing.expectEqualStrings("manual-app-facing-production-integration-ci-advisory-remediation-report-consumption-readiness", approve_options.policy);
    try std.testing.expectEqual(@as(usize, 1), approve_options.verified_commands.len);
    try std.testing.expectEqualStrings(".zig-cache/causal-artifacts/custom-consumption-readiness", approve_options.out_prefix.?);

    var reject_options = try parseOptions(std.testing.allocator, &.{
        "zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-readiness",
        "--from-publication-policy",
        ".zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-publication-policy.json",
        "reject",
        "--reason",
        "negative app-facing advisory report consumption readiness path",
    });
    defer reject_options.deinit(std.testing.allocator);

    try std.testing.expectEqual(Decision.reject, reject_options.decision);
    try std.testing.expectError(error.UnknownDecision, parseOptions(std.testing.allocator, &.{ "tool", "--from-publication-policy", ".zig-cache/report.json", "maybe", "--reason", "bad" }));
    try std.testing.expectError(error.MissingReason, parseOptions(std.testing.allocator, &.{ "tool", "--from-publication-policy", ".zig-cache/report.json", "approve" }));
}

test "default output path replaces publication policy suffix and compacts long names" {
    const options = Options{
        .publication_policy_path = "../../.zig-cache/causal-artifacts/example-ci-advisory-remediation-report-publication-policy.json",
        .decision = .approve,
        .reason = "planned",
    };
    const paths = try outputPathsForOptions(std.testing.allocator, options);
    defer paths.deinit(std.testing.allocator);

    try std.testing.expectEqualStrings("../../.zig-cache/causal-artifacts/example-ci-advisory-remediation-report-consumption-readiness.json", paths.json_path);
    try std.testing.expectEqualStrings("../../.zig-cache/causal-artifacts/example-ci-advisory-remediation-report-consumption-readiness.txt", paths.text_path);

    const long_options = Options{
        .publication_policy_path = "../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures-readiness-review-implementation-proposal-app-facing-boundary-local-fixtures-nendb-handoff-fixtures-solid-webui-readonly-preview-ci-advisory-remediation-report-application-boundary-publication-policy-reviewer-policy-before-after-evidence-ci-advisory-remediation-report-publication-policy.json",
        .decision = .approve,
        .reason = "planned",
    };
    const long_paths = try outputPathsForOptions(std.testing.allocator, long_options);
    defer long_paths.deinit(std.testing.allocator);

    const file_name = fileName(long_paths.json_path);
    try std.testing.expect(file_name.len <= 240);
    try std.testing.expect(contains(long_paths.json_path, "app-facing-production-integration-ci-advisory-remediation-report-consumption-readiness-"));
}

test "approved consumption readiness is ready and preserves read-only authority" {
    const reports = try formatReports(std.testing.allocator, .{
        .options = .{
            .publication_policy_path = ".zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-publication-policy.json",
            .decision = .approve,
            .reason = "app-facing advisory report consumption readiness reviewed",
            .verified_commands = required_verification_commands,
        },
        .source_publication_policy_json = sample_ready_publication_policy_json,
    });
    defer reports.deinit(std.testing.allocator);

    try std.testing.expect(contains(reports.json, "\"schema\": \"zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-readiness.v1\""));
    try std.testing.expect(contains(reports.json, "\"consumption_readiness_status\": \"ready\""));
    try std.testing.expect(contains(reports.json, "\"ready_for_next_branch\": true"));
    try std.testing.expect(contains(reports.json, "\"mutation_authority\": \"none\""));
    try std.testing.expect(contains(reports.json, "\"app_runtime_integration_enabled\": false"));
    try std.testing.expect(contains(reports.json, "\"agent_query_live_projection_enabled\": false"));
    try std.testing.expect(contains(reports.json, "\"raw_payload_capture_enabled\": false"));
    try std.testing.expect(contains(reports.json, "\"nendb_adapter_execution_enabled\": false"));
    try std.testing.expect(contains(reports.json, "\"id\": \"agent-readonly-consumer\""));
    try std.testing.expect(contains(reports.json, "\"id\": \"bounded-agent-query-contract\""));
    try std.testing.expect(contains(reports.json, "\"id\": \"no-nendb-write-or-adapter-execution\""));
    try std.testing.expect(contains(reports.json, "\"next_branch_if_ready\": \"codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-boundary\""));
    try std.testing.expect(contains(reports.text, "consumption_readiness_status: ready"));
    try std.testing.expect(contains(reports.text, "next branch if ready: codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-boundary"));
}

test "rejection incomplete verification and invalid sources block consumption readiness" {
    const rejected = try formatReports(std.testing.allocator, .{
        .options = .{
            .publication_policy_path = ".zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-publication-policy.json",
            .decision = .reject,
            .reason = "negative app-facing advisory report consumption readiness path",
            .verified_commands = required_verification_commands,
        },
        .source_publication_policy_json = sample_ready_publication_policy_json,
    });
    defer rejected.deinit(std.testing.allocator);
    try std.testing.expect(contains(rejected.json, "\"consumption_readiness_status\": \"blocked\""));
    try std.testing.expect(contains(rejected.json, "\"name\": \"decision-approved\""));

    const incomplete = try formatReports(std.testing.allocator, .{
        .options = .{
            .publication_policy_path = ".zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-publication-policy.json",
            .decision = .approve,
            .reason = "missing verification commands",
        },
        .source_publication_policy_json = sample_ready_publication_policy_json,
    });
    defer incomplete.deinit(std.testing.allocator);
    try std.testing.expect(contains(incomplete.json, "\"name\": \"required-verification-recorded\""));
    try std.testing.expect(contains(incomplete.json, "\"status\": \"fail\""));

    const blocked_source = try formatReports(std.testing.allocator, .{
        .options = .{
            .publication_policy_path = ".zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-publication-policy.json",
            .decision = .approve,
            .reason = "blocked source",
            .verified_commands = required_verification_commands,
        },
        .source_publication_policy_json = sample_blocked_publication_policy_json,
    });
    defer blocked_source.deinit(std.testing.allocator);
    try std.testing.expect(contains(blocked_source.json, "\"name\": \"source-policy-ready\""));
    try std.testing.expect(contains(blocked_source.json, "\"consumption_readiness_status\": \"blocked\""));

    const unsafe_source = try formatReports(std.testing.allocator, .{
        .options = .{
            .publication_policy_path = ".zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-publication-policy.json",
            .decision = .approve,
            .reason = "unsafe source",
            .verified_commands = required_verification_commands,
        },
        .source_publication_policy_json = sample_unsafe_publication_policy_json,
    });
    defer unsafe_source.deinit(std.testing.allocator);
    try std.testing.expect(contains(unsafe_source.json, "\"name\": \"source-app-authority-disabled\""));
    try std.testing.expect(contains(unsafe_source.json, "\"name\": \"source-runtime-and-storage-disabled\""));
}

const sample_ready_publication_policy_json =
    \\{
    \\  "schema": "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-publication-policy.v1",
    \\  "schema_version": 1,
    \\  "source_application_boundary": ".zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-application-boundary.json",
    \\  "source_report_application_status": "applied",
    \\  "source_mode": "record-applied",
    \\  "source_applied": true,
    \\  "source_mutation_authority": "record-only",
    \\  "source_after_report_digest": "sha256:abc123",
    \\  "decision": "approve",
    \\  "ci_advisory_remediation_report_publication_policy_status": "ready",
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
    \\  "policy_checks": [
    \\    { "name": "source-schema", "status": "pass", "detail": "ok" },
    \\    { "name": "decision-approved", "status": "pass", "detail": "ok" }
    \\  ],
    \\  "interpretation_rules": [
    \\    { "id": "agent-readonly-context", "consumer_role": "agent-readonly", "allowed_use": "cite evidence", "failure_effect": "informational", "denied_claim": "mutation authority" }
    \\  ],
    \\  "publication_surfaces": [
    \\    { "id": "solid-webui-readonly-view", "visibility_class": "local-webui-redacted", "executed_by_tool": false, "interpretation_scope": "read-only" }
    \\  ],
    \\  "denied_inference_rules": ["required-status-check", "merge-blocker", "branch-protection", "app-runtime-integration-proof", "nendb-adapter-execution-proof", "production-health-proof", "mutation-authority"],
    \\  "negative_fixtures": [
    \\    { "id": "app-runtime-integration-claim-denied", "artifact_state": "app_runtime_integration_enabled=true", "decision": "deny", "failed_gate": "source-app-authority-disabled", "reason": "denied" }
    \\  ],
    \\  "blocked_claims": ["app-runtime-integration-enabled", "nendb-adapter-execution-enabled", "ci-required-status-check"],
    \\  "required_verification_commands": ["zig build causal-app-facing-production-integration-ci-advisory-remediation-report-publication-policy"],
    \\  "verified_commands": ["zig build causal-app-facing-production-integration-ci-advisory-remediation-report-publication-policy"],
    \\  "source_branch": "codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-publication-policy",
    \\  "recommendation": "start-app-facing-production-integration-ci-advisory-remediation-report-consumption-readiness",
    \\  "next_branch_if_ready": "codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-readiness"
    \\}
;

const sample_blocked_publication_policy_json =
    \\{
    \\  "schema": "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-publication-policy.v1",
    \\  "schema_version": 1,
    \\  "decision": "reject",
    \\  "ci_advisory_remediation_report_publication_policy_status": "blocked",
    \\  "ready_for_next_branch": false,
    \\  "mutation_authority": "none"
    \\}
;

const sample_unsafe_publication_policy_json =
    \\{
    \\  "schema": "zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-publication-policy.v1",
    \\  "schema_version": 1,
    \\  "source_application_boundary": ".zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-application-boundary.json",
    \\  "source_after_report_digest": "sha256:abc123",
    \\  "source_applied": true,
    \\  "source_mutation_authority": "record-only",
    \\  "decision": "approve",
    \\  "ci_advisory_remediation_report_publication_policy_status": "ready",
    \\  "ready_for_next_branch": true,
    \\  "app_runtime_integration_enabled": true,
    \\  "agent_query_live_projection_enabled": true,
    \\  "raw_payload_capture_enabled": true,
    \\  "nendb_adapter_execution_enabled": true,
    \\  "mutation_authority": "none",
    \\  "policy_checks": [{ "name": "source-schema", "status": "pass", "detail": "ok" }],
    \\  "interpretation_rules": [{ "id": "agent-readonly-context" }],
    \\  "publication_surfaces": [{ "id": "solid-webui-readonly-view" }],
    \\  "denied_inference_rules": ["required-status-check", "app-runtime-integration-proof", "nendb-adapter-execution-proof"],
    \\  "negative_fixtures": [{ "id": "app-runtime-integration-claim-denied" }],
    \\  "blocked_claims": ["app-runtime-integration-enabled"],
    \\  "required_verification_commands": ["zig build causal-app-facing-production-integration-ci-advisory-remediation-report-publication-policy"],
    \\  "verified_commands": ["zig build causal-app-facing-production-integration-ci-advisory-remediation-report-publication-policy"]
    \\}
;
