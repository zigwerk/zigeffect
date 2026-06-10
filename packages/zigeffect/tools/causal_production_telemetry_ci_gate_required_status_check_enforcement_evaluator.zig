const std = @import("std");

pub const production_telemetry_ci_gate_required_status_check_enforcement_evaluator_schema = "zigeffect.causal.production-telemetry-ci-gate-required-status-check-enforcement-evaluator.v1";
pub const production_telemetry_ci_gate_required_status_check_enforcement_evaluator_schema_version: u32 = 1;
pub const source_branch = "codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-enforcement-evaluator";
pub const recommendation = "start-production-telemetry-ci-gate-required-status-check-enforcement-report";
pub const next_branch_if_ready = "codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-enforcement-report";

const source_policy_schema = "zigeffect.causal.production-telemetry-ci-gate-required-status-check-enforcement-policy.v1";
const source_application_boundary_schema = "zigeffect.causal.production-telemetry-ci-gate-required-status-check-enforcement-application-boundary.v1";
const generated_by = "causal-production-telemetry-ci-gate-required-status-check-enforcement-evaluator";
const max_evidence_files = 32;
const max_evidence_bytes = 1024 * 1024;

const required_verification_commands: []const []const u8 = &.{
    "zig build causal-production-telemetry-ci-gate-required-status-check-enforcement-policy",
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
const ci_report_publication_enabled = false;
const github_api_mutation_enabled = false;
const github_check_run_creation_enabled = false;
const branch_protection_mutation_by_tool_enabled = false;
const github_step_summary_write_enabled = false;
const pull_request_comment_enabled = false;
const production_telemetry_ingestion = false;
const live_exporter_enabled = false;
const network_send_enabled = false;
const collector_endpoint_configured = false;
const otlp_serialization_enabled = false;
const runtime_pipeline_enabled = false;
const durable_write_enabled = false;
const nendb_write_enabled = false;
const mutation_authority = "none";

const EvaluationStatus = enum { ready, advisory_findings, blocked };
const SignalStatus = enum { observed, missing, blocked };
const CheckStatus = enum { pass, fail };
const EvidenceClass = enum {
    source_policy,
    source_application_boundary,
    release_gate_json,
    release_gate_text,
    causal_json,
    causal_text,
    denied,
};

const Options = struct {
    policy_path: []const u8,
    reason: []const u8,
    reviewed_by: []const u8 = "ci-gate-required-status-check-enforcement-evaluator",
    policy: []const u8 = "manual-production-telemetry-ci-gate-required-status-check-enforcement-evaluator",
    evidence_paths: []const []const u8 = &.{},
    out_prefix: ?[]const u8 = null,

    fn deinit(self: Options, allocator: std.mem.Allocator) void {
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

const EvidenceInput = struct {
    path: []const u8,
    contents: []const u8,
};

const EvaluatorInput = struct {
    options: Options,
    source_policy_json: []const u8,
    evidence_inputs: []const EvidenceInput,
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

const SourceInterpretationPolicy = struct {
    id: []const u8 = "",
    source_state: []const u8 = "",
    allowed_claim: []const u8 = "",
    required_source_evidence: []const u8 = "",
    denied_claims: []const u8 = "",
    next_use: []const u8 = "",
};

const SourceEvidenceRequirement = struct {
    id: []const u8 = "",
    allowed: bool = false,
    detail: []const u8 = "",
};

const SourceNegativeFixture = struct {
    id: []const u8 = "",
    artifact_state: []const u8 = "",
    decision: []const u8 = "",
    failed_gate: []const u8 = "",
    reason: []const u8 = "",
};

const EnforcementPolicyArtifact = struct {
    schema: []const u8,
    schema_version: u32,
    source_enforcement_application_boundary: []const u8 = "",
    source_enforcement_application_status: []const u8 = "",
    source_mode: []const u8 = "",
    source_applied: bool = false,
    source_active_enforcement_recorded: bool = false,
    source_merge_blocking_recorded: bool = false,
    source_active_enforcement_claim_allowed: bool = false,
    source_merge_blocker_claim_allowed: bool = false,
    required_status_check_enforcement_policy_status: []const u8,
    ready_for_next_branch: bool,
    active_enforcement_policy_ready: bool = false,
    merge_blocker_policy_ready: bool = false,
    mutation_authority: []const u8 = "",
    ci_gate_enabled: bool = false,
    ci_gate_enforcement_enabled: bool = false,
    ci_required_status_check_enabled: bool = false,
    ci_workflow_mutation_enabled: bool = false,
    ci_upload_execution_enabled: bool = false,
    ci_report_publication_enabled: bool = false,
    github_api_mutation_enabled: bool = false,
    github_check_run_creation_enabled: bool = false,
    branch_protection_mutation_by_tool_enabled: bool = false,
    github_step_summary_write_enabled: bool = false,
    pull_request_comment_enabled: bool = false,
    production_telemetry_ingestion: bool = false,
    live_exporter_enabled: bool = false,
    network_send_enabled: bool = false,
    collector_endpoint_configured: bool = false,
    otlp_serialization_enabled: bool = false,
    runtime_pipeline_enabled: bool = false,
    durable_write_enabled: bool = false,
    nendb_write_enabled: bool = false,
    enforcement_interpretation_policy: []const SourceInterpretationPolicy = &.{},
    evidence_requirements: []const SourceEvidenceRequirement = &.{},
    checks: []const SourceCheck = &.{},
    denied_inference_rules: []const []const u8 = &.{},
    negative_fixtures: []const SourceNegativeFixture = &.{},
    blocked_claims: []const []const u8 = &.{},
    required_verification_commands: []const []const u8 = &.{},
    verified_commands: []const []const u8 = &.{},
};

const GenericArtifact = struct {
    schema: []const u8 = "",
    schema_version: u32 = 0,
    generated_by: []const u8 = "",
};

const EvidenceFile = struct {
    path: []const u8,
    class: EvidenceClass,
    size_bytes: usize,
    sha256: []const u8,
    detected_schema: []const u8,
    denied_reason: []const u8 = "",
    active_marker_observed: bool = false,
    merge_marker_observed: bool = false,
    mutation_marker_observed: bool = false,
    production_marker_observed: bool = false,

    fn deinit(self: EvidenceFile, allocator: std.mem.Allocator) void {
        allocator.free(self.sha256);
        allocator.free(self.detected_schema);
    }
};

const EvidenceAnalysis = struct {
    files: []const EvidenceFile,

    fn deinit(self: EvidenceAnalysis, allocator: std.mem.Allocator) void {
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
        error.MissingPolicyInput,
        error.MissingEvidenceInput,
        => failUsage(err),
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

    var reviewed_by: []const u8 = "ci-gate-required-status-check-enforcement-evaluator";
    var policy: []const u8 = "manual-production-telemetry-ci-gate-required-status-check-enforcement-evaluator";
    var reason: ?[]const u8 = null;
    var evidence_paths = std.ArrayList([]const u8).empty;
    var out_prefix: ?[]const u8 = null;
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
        } else if (std.mem.eql(u8, flag, "--evidence")) {
            if (!std.mem.endsWith(u8, value, ".json") and !std.mem.endsWith(u8, value, ".txt")) return error.InvalidEvidencePath;
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
    if (evidence_paths.items.len == 0) return error.MissingEvidenceInput;
    if (evidence_paths.items.len > max_evidence_files) return error.TooManyEvidenceFiles;

    return .{
        .policy_path = policy_path,
        .reason = final_reason,
        .reviewed_by = reviewed_by,
        .policy = policy,
        .evidence_paths = try evidence_paths.toOwnedSlice(allocator),
        .out_prefix = out_prefix,
    };
}

fn outputPathsForOptions(allocator: std.mem.Allocator, options: Options) !OutputPaths {
    const prefix = if (options.out_prefix) |out_prefix|
        try allocator.dupe(u8, out_prefix)
    else blk: {
        if (!std.mem.endsWith(u8, options.policy_path, ".json")) return error.InvalidPolicyPath;
        if (std.mem.endsWith(u8, options.policy_path, "-ci-gate-required-status-check-enforcement-policy.json")) {
            const suffix_len = "-ci-gate-required-status-check-enforcement-policy.json".len;
            break :blk try std.fmt.allocPrint(allocator, "{s}-ci-gate-required-status-check-enforcement-evaluator", .{options.policy_path[0 .. options.policy_path.len - suffix_len]});
        }
        const base = options.policy_path[0 .. options.policy_path.len - ".json".len];
        break :blk try std.fmt.allocPrint(allocator, "{s}-ci-gate-required-status-check-enforcement-evaluator", .{base});
    };
    defer allocator.free(prefix);

    return .{
        .json_path = try std.fmt.allocPrint(allocator, "{s}.json", .{prefix}),
        .text_path = try std.fmt.allocPrint(allocator, "{s}.txt", .{prefix}),
    };
}

fn formatReports(allocator: std.mem.Allocator, input: EvaluatorInput) !EvaluatorReports {
    var parsed = try std.json.parseFromSlice(EnforcementPolicyArtifact, allocator, input.source_policy_json, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();

    const paths = try outputPathsForOptions(allocator, input.options);
    defer paths.deinit(allocator);

    const evidence = try analyzeEvidence(allocator, input.evidence_inputs);
    defer evidence.deinit(allocator);

    const result = try evaluatePolicyAndEvidence(allocator, parsed.value, evidence);
    defer result.deinit(allocator);

    const json = try formatEvaluatorJson(allocator, input.options, parsed.value, evidence, result, paths);
    errdefer allocator.free(json);
    const text = try formatEvaluatorText(allocator, input.options, parsed.value, evidence, result, paths);
    errdefer allocator.free(text);

    return .{ .json = json, .text = text };
}

fn analyzeEvidence(allocator: std.mem.Allocator, inputs: []const EvidenceInput) !EvidenceAnalysis {
    if (inputs.len == 0) return error.MissingEvidenceInput;
    if (inputs.len > max_evidence_files) return error.TooManyEvidenceFiles;

    var files = std.ArrayList(EvidenceFile).empty;
    errdefer {
        for (files.items) |file| file.deinit(allocator);
        files.deinit(allocator);
    }

    for (inputs) |input| {
        if (input.contents.len > max_evidence_bytes) return error.EvidenceTooLarge;
        const sha = try sha256Digest(allocator, input.contents);
        errdefer allocator.free(sha);
        const schema = try detectJsonSchema(allocator, input.path, input.contents);
        errdefer allocator.free(schema);
        const class = classifyEvidence(input.path, input.contents, schema);
        const denied_reason = evidenceDeniedReason(input.path, input.contents, class);
        const active_marker_observed = contentsContainActiveEnforcement(input.contents);
        const merge_marker_observed = contentsContainMergeBlocking(input.contents);
        const mutation_marker_observed = evidenceContainsMutationMarker(input.contents);
        const production_marker_observed = evidenceContainsProductionMarker(input.contents);

        try files.append(allocator, .{
            .path = input.path,
            .class = class,
            .size_bytes = input.contents.len,
            .sha256 = sha,
            .detected_schema = schema,
            .denied_reason = denied_reason,
            .active_marker_observed = active_marker_observed,
            .merge_marker_observed = merge_marker_observed,
            .mutation_marker_observed = mutation_marker_observed,
            .production_marker_observed = production_marker_observed,
        });
    }

    return .{ .files = try files.toOwnedSlice(allocator) };
}

fn evaluatePolicyAndEvidence(
    allocator: std.mem.Allocator,
    source: EnforcementPolicyArtifact,
    evidence: EvidenceAnalysis,
) !EvaluationResult {
    var checks = std.ArrayList(EvaluationCheck).empty;
    var signals = std.ArrayList(SignalEvaluation).empty;
    var findings = std.ArrayList(Finding).empty;
    errdefer checks.deinit(allocator);
    errdefer signals.deinit(allocator);
    errdefer findings.deinit(allocator);

    try appendCheckAndFinding(allocator, &checks, &findings, "source-schema", sourceSchemaVersionSupported(source), "policy-ready", "source enforcement policy schema is supported");
    try appendCheckAndFinding(allocator, &checks, &findings, "source-policy-ready", sourcePolicyReady(source), "policy-ready", "source enforcement policy is ready for evaluator handoff");
    try appendCheckAndFinding(allocator, &checks, &findings, "source-tool-authority-disabled", sourceToolAuthorityDisabled(source), "tool-mutation-denied", "source keeps GitHub workflow check-run upload summary and comment authority disabled");
    try appendCheckAndFinding(allocator, &checks, &findings, "source-runtime-and-storage-disabled", sourceRuntimeAndStorageDisabled(source), "production-claim-denied", "source keeps live telemetry network collector OTLP runtime durable and NenDB writes disabled");
    try appendCheckAndFinding(allocator, &checks, &findings, "source-checks-passed", sourceChecksHaveNoFailures(source.checks), "policy-ready", "source checks contain no failures");
    try appendCheckAndFinding(allocator, &checks, &findings, "source-catalogs-present", sourceCatalogsPresent(source), "policy-ready", "source interpretation evidence requirement denied rule negative fixture and blocked claim catalogs are present");
    try appendCheckAndFinding(allocator, &checks, &findings, "source-verification-recorded", verifiedCommandsContainAll(source.verified_commands, source.required_verification_commands), "policy-ready", "source recorded every source required verification command");
    try appendCheckAndFinding(allocator, &checks, &findings, "evidence-count-bounded", evidence.files.len > 0 and evidence.files.len <= max_evidence_files, "tool-mutation-denied", "explicit bounded evidence file count is within policy");
    try appendCheckAndFinding(allocator, &checks, &findings, "evidence-size-bounded", evidenceFilesWithinSizeLimit(evidence), "tool-mutation-denied", "every evidence file is within the one MiB bound");
    try appendCheckAndFinding(allocator, &checks, &findings, "evidence-safe", !evidenceHasDeniedFile(evidence), "tool-mutation-denied", "evidence contains no denied secret mutation telemetry storage production or renderer claims");
    try appendCheckAndFinding(allocator, &checks, &findings, "source-policy-evidence-present", evidenceHasClass(evidence, .source_policy), "policy-ready", "explicit evidence includes the source enforcement policy artifact");
    try appendCheckAndFinding(allocator, &checks, &findings, "mutation-claims-denied", !evidenceContainsDeniedMutationClaim(evidence), "tool-mutation-denied", "no evidence claims mutation by this evaluator or tool chain");
    try appendCheckAndFinding(allocator, &checks, &findings, "production-claims-denied", !evidenceContainsDeniedProductionClaim(evidence), "production-claim-denied", "no evidence claims production health deployment success customer impact or cluster readiness");

    const active_observed = evidenceContainsActiveEnforcement(evidence);
    const merge_observed = evidenceContainsMergeBlocking(evidence);

    try appendSignalNoFinding(allocator, &signals, "policy-ready", if (sourcePolicyReady(source)) .observed else .blocked, if (sourcePolicyReady(source)) "source policy is ready and verified" else "source policy is not ready or verified", firstEvidencePathForClasses(evidence, &.{.source_policy}));
    try appendSignalNoFinding(allocator, &signals, "active-enforcement-observed", if (active_observed) .observed else .missing, if (active_observed) "active required-status-check enforcement evidence was observed" else "active required-status-check enforcement evidence was not observed", firstActiveEvidencePath(evidence));
    try appendSignalNoFinding(allocator, &signals, "merge-blocking-observed", if (merge_observed) .observed else .missing, if (merge_observed) "merge-blocking evidence was observed" else "merge-blocking evidence was not observed", firstMergeEvidencePath(evidence));
    try appendSignalNoFinding(allocator, &signals, "tool-mutation-denied", if (!evidenceContainsDeniedMutationClaim(evidence)) .observed else .blocked, if (!evidenceContainsDeniedMutationClaim(evidence)) "no tool mutation claim was accepted" else "evidence contains a denied tool mutation claim", firstDeniedEvidencePath(evidence));
    try appendSignalNoFinding(allocator, &signals, "production-claim-denied", if (!evidenceContainsDeniedProductionClaim(evidence)) .observed else .blocked, if (!evidenceContainsDeniedProductionClaim(evidence)) "no production health or deployment claim was accepted" else "evidence contains a denied production claim", firstDeniedEvidencePath(evidence));

    if (source.active_enforcement_policy_ready and !active_observed) {
        try appendFinding(allocator, &findings, "active-enforcement-evidence-missing", "advisory", "active-enforcement-observed", "source policy allows active enforcement evidence but no active evidence file was observed", "");
    }
    if (!source.active_enforcement_policy_ready and active_observed) {
        try appendFinding(allocator, &findings, "active-enforcement-overclaim-observed", "advisory", "active-enforcement-observed", "active enforcement evidence was observed although source policy does not allow active enforcement claims", firstActiveEvidencePath(evidence));
    }
    if (source.merge_blocker_policy_ready and !merge_observed) {
        try appendFinding(allocator, &findings, "merge-blocking-evidence-missing", "advisory", "merge-blocking-observed", "source policy allows merge-blocking evidence but no merge-blocking evidence file was observed", "");
    }
    if (!source.merge_blocker_policy_ready and merge_observed) {
        try appendFinding(allocator, &findings, "merge-blocking-overclaim-observed", "advisory", "merge-blocking-observed", "merge-blocking evidence was observed although source policy does not allow merge-blocker claims", firstMergeEvidencePath(evidence));
    }

    const finding_slice = try findings.toOwnedSlice(allocator);
    errdefer allocator.free(finding_slice);
    const checks_slice = try checks.toOwnedSlice(allocator);
    errdefer allocator.free(checks_slice);
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
        .checks = checks_slice,
        .signal_evaluations = signal_slice,
        .findings = finding_slice,
    };
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

fn appendSignalNoFinding(
    allocator: std.mem.Allocator,
    signals: *std.ArrayList(SignalEvaluation),
    id: []const u8,
    status: SignalStatus,
    detail: []const u8,
    evidence_path: []const u8,
) !void {
    try signals.append(allocator, .{ .id = id, .status = status, .detail = detail, .evidence_path = evidence_path });
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

fn sourceSchemaVersionSupported(source: EnforcementPolicyArtifact) bool {
    return std.mem.eql(u8, source.schema, source_policy_schema) and source.schema_version == 1;
}

fn sourcePolicyReady(source: EnforcementPolicyArtifact) bool {
    return std.mem.eql(u8, source.required_status_check_enforcement_policy_status, "ready") and
        source.ready_for_next_branch and
        std.mem.eql(u8, source.mutation_authority, "none");
}

fn sourceToolAuthorityDisabled(source: EnforcementPolicyArtifact) bool {
    return !source.ci_gate_enabled and
        !source.ci_gate_enforcement_enabled and
        !source.ci_required_status_check_enabled and
        !source.ci_workflow_mutation_enabled and
        !source.ci_upload_execution_enabled and
        !source.ci_report_publication_enabled and
        !source.github_api_mutation_enabled and
        !source.github_check_run_creation_enabled and
        !source.branch_protection_mutation_by_tool_enabled and
        !source.github_step_summary_write_enabled and
        !source.pull_request_comment_enabled;
}

fn sourceRuntimeAndStorageDisabled(source: EnforcementPolicyArtifact) bool {
    return !source.production_telemetry_ingestion and
        !source.live_exporter_enabled and
        !source.network_send_enabled and
        !source.collector_endpoint_configured and
        !source.otlp_serialization_enabled and
        !source.runtime_pipeline_enabled and
        !source.durable_write_enabled and
        !source.nendb_write_enabled;
}

fn sourceChecksHaveNoFailures(checks: []const SourceCheck) bool {
    if (checks.len == 0) return false;
    for (checks) |check| {
        if (std.mem.eql(u8, check.status, "fail")) return false;
    }
    return true;
}

fn sourceCatalogsPresent(source: EnforcementPolicyArtifact) bool {
    return source.enforcement_interpretation_policy.len > 0 and
        source.evidence_requirements.len > 0 and
        source.denied_inference_rules.len > 0 and
        source.negative_fixtures.len > 0 and
        source.blocked_claims.len > 0 and
        source.required_verification_commands.len > 0;
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

fn evidenceFilesWithinSizeLimit(evidence: EvidenceAnalysis) bool {
    for (evidence.files) |file| {
        if (file.size_bytes > max_evidence_bytes) return false;
    }
    return true;
}

fn classifyEvidence(path: []const u8, contents: []const u8, detected_schema: []const u8) EvidenceClass {
    const is_json = std.mem.endsWith(u8, path, ".json");
    const is_txt = std.mem.endsWith(u8, path, ".txt");
    if (!is_json and !is_txt) return .denied;

    if (is_json and std.mem.eql(u8, detected_schema, source_policy_schema)) return .source_policy;
    if (is_json and std.mem.eql(u8, detected_schema, source_application_boundary_schema)) return .source_application_boundary;
    if (is_json and (std.mem.indexOf(u8, detected_schema, "release-gate") != null or std.mem.indexOf(u8, contents, "\"generated_by\": \"release-gate\"") != null)) return .release_gate_json;
    if (is_txt and (std.mem.indexOf(u8, contents, "release gate") != null or std.mem.indexOf(u8, contents, "release-gate") != null)) return .release_gate_text;
    if (is_json and std.mem.startsWith(u8, detected_schema, "zigeffect.causal.")) return .causal_json;
    if (is_txt and (std.mem.indexOf(u8, contents, "zigeffect causal") != null or std.mem.indexOf(u8, contents, "causal ci handoff") != null)) return .causal_text;
    return .denied;
}

fn evidenceDeniedReason(path: []const u8, contents: []const u8, class: EvidenceClass) []const u8 {
    if (class == .denied) return "evidence must be a supported JSON or text artifact";
    if (containsAny(contents, &.{ "secret=", "token=", "password=", "ghp_", "sk-", "xoxb-", "BEGIN PRIVATE KEY", "Authorization:" })) return "secret-shaped evidence is denied";
    if (class == .source_policy or class == .source_application_boundary) return "";
    if (evidenceContainsMutationMarker(contents)) return "tool mutation claims are denied";
    if (evidenceContainsProductionMarker(contents)) return "production health deployment customer impact and cluster readiness claims are denied";
    if (containsAny(contents, &.{ "durable_write_enabled=true", "\"durable_write_enabled\": true", "nendb_write_enabled=true", "\"nendb_write_enabled\": true" })) return "durable and NenDB writes are denied";
    if (containsAny(contents, &.{ "durable_adapter=non-nendb", "\"durable_adapter\": \"cockroach\"", "\"durable_adapter\": \"postgres\"", "\"durable_adapter\": \"d1\"" })) return "non-NenDB durable adapters are denied";
    if (containsAny(contents, &.{ "renderer=react", "\"renderer\": \"react\"" })) return "alternate renderers are denied; workbench direction remains SolidJS inside zig-webui";
    _ = path;
    return "";
}

fn evidenceContainsMutationMarker(contents: []const u8) bool {
    return containsAny(contents, &.{
        "github_api_mutation_enabled=true",
        "\"github_api_mutation_enabled\": true",
        "branch_protection_mutation_by_tool_enabled=true",
        "\"branch_protection_mutation_by_tool_enabled\": true",
        "ci_workflow_mutation_enabled=true",
        "\"ci_workflow_mutation_enabled\": true",
        "github_check_run_creation_enabled=true",
        "\"github_check_run_creation_enabled\": true",
        "ci_upload_execution_enabled=true",
        "\"ci_upload_execution_enabled\": true",
        "github_step_summary_write_enabled=true",
        "\"github_step_summary_write_enabled\": true",
        "pull_request_comment_enabled=true",
        "\"pull_request_comment_enabled\": true",
    });
}

fn evidenceContainsProductionMarker(contents: []const u8) bool {
    return containsAny(contents, &.{
        "collector_endpoint_configured=true",
        "\"collector_endpoint_configured\": true",
        "production_telemetry_ingestion=true",
        "\"production_telemetry_ingestion\": true",
        "live_exporter_enabled=true",
        "\"live_exporter_enabled\": true",
        "network_send_enabled=true",
        "\"network_send_enabled\": true",
        "runtime_pipeline_enabled=true",
        "\"runtime_pipeline_enabled\": true",
        "production_health=proven",
        "\"production_health\": \"proven\"",
        "deployment_success=proven",
        "\"deployment_success\": \"proven\"",
        "customer_impact=proven",
        "\"customer_impact\": \"proven\"",
        "production_cluster_ready=true",
        "\"production_cluster_ready\": true",
    });
}

fn containsAny(contents: []const u8, markers: []const []const u8) bool {
    for (markers) |marker| {
        if (std.mem.indexOf(u8, contents, marker) != null) return true;
    }
    return false;
}

fn evidenceHasDeniedFile(evidence: EvidenceAnalysis) bool {
    for (evidence.files) |file| {
        if (file.denied_reason.len > 0) return true;
    }
    return false;
}

fn evidenceContainsDeniedMutationClaim(evidence: EvidenceAnalysis) bool {
    for (evidence.files) |file| {
        if ((file.mutation_marker_observed and file.denied_reason.len > 0) or
            std.mem.indexOf(u8, file.denied_reason, "mutation") != null or
            std.mem.indexOf(u8, file.denied_reason, "upload") != null or
            std.mem.indexOf(u8, file.denied_reason, "comment") != null)
        {
            return true;
        }
    }
    return false;
}

fn evidenceContainsDeniedProductionClaim(evidence: EvidenceAnalysis) bool {
    for (evidence.files) |file| {
        if ((file.production_marker_observed and file.denied_reason.len > 0) or
            std.mem.indexOf(u8, file.denied_reason, "production") != null or
            std.mem.indexOf(u8, file.denied_reason, "telemetry") != null)
        {
            return true;
        }
    }
    return false;
}

fn evidenceHasClass(evidence: EvidenceAnalysis, class: EvidenceClass) bool {
    for (evidence.files) |file| {
        if (file.class == class and file.denied_reason.len == 0) return true;
    }
    return false;
}

fn evidenceContainsActiveEnforcement(evidence: EvidenceAnalysis) bool {
    for (evidence.files) |file| {
        if (file.class == .source_policy or file.denied_reason.len > 0) continue;
        if (file.active_marker_observed) return true;
    }
    return false;
}

fn evidenceContainsMergeBlocking(evidence: EvidenceAnalysis) bool {
    for (evidence.files) |file| {
        if (file.class == .source_policy or file.denied_reason.len > 0) continue;
        if (file.merge_marker_observed) return true;
    }
    return false;
}

fn contentsContainActiveEnforcement(contents: []const u8) bool {
    return containsAny(contents, &.{
        "active_enforcement_recorded=true",
        "\"active_enforcement_recorded\": true",
        "active_enforcement_claim_allowed=true",
        "\"active_enforcement_claim_allowed\": true",
        "active required-status-check enforcement",
        "active required check enforcement",
    });
}

fn contentsContainMergeBlocking(contents: []const u8) bool {
    return containsAny(contents, &.{
        "merge_blocking_recorded=true",
        "\"merge_blocking_recorded\": true",
        "merge_blocker_claim_allowed=true",
        "\"merge_blocker_claim_allowed\": true",
        "merge-blocking evidence",
        "merge is blocked",
        "blocks merges",
    });
}

fn firstEvidencePathForClasses(evidence: EvidenceAnalysis, classes: []const EvidenceClass) []const u8 {
    for (evidence.files) |file| {
        if (file.denied_reason.len > 0) continue;
        for (classes) |class| {
            if (file.class == class) return file.path;
        }
    }
    return "";
}

fn firstDeniedEvidencePath(evidence: EvidenceAnalysis) []const u8 {
    for (evidence.files) |file| {
        if (file.denied_reason.len > 0) return file.path;
    }
    return "";
}

fn firstActiveEvidencePath(evidence: EvidenceAnalysis) []const u8 {
    for (evidence.files) |file| {
        if (file.class == .source_policy or file.denied_reason.len > 0) continue;
        if (file.active_marker_observed) return file.path;
    }
    return "";
}

fn firstMergeEvidencePath(evidence: EvidenceAnalysis) []const u8 {
    for (evidence.files) |file| {
        if (file.class == .source_policy or file.denied_reason.len > 0) continue;
        if (file.merge_marker_observed) return file.path;
    }
    return "";
}

fn countFindings(findings: []const Finding, severity: []const u8) usize {
    var count: usize = 0;
    for (findings) |finding| {
        if (std.mem.eql(u8, finding.severity, severity)) count += 1;
    }
    return count;
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
    source: EnforcementPolicyArtifact,
    evidence: EvidenceAnalysis,
    result: EvaluationResult,
    paths: OutputPaths,
) ![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "{\n");
    try appendJsonField(allocator, &output, "schema", production_telemetry_ci_gate_required_status_check_enforcement_evaluator_schema, true);
    try output.print(allocator, "  \"schema_version\": {},\n", .{production_telemetry_ci_gate_required_status_check_enforcement_evaluator_schema_version});
    try appendJsonField(allocator, &output, "source_enforcement_policy", options.policy_path, true);
    try appendJsonField(allocator, &output, "source_policy_status", source.required_status_check_enforcement_policy_status, true);
    try output.print(allocator, "  \"source_policy_ready_for_next_branch\": {},\n", .{source.ready_for_next_branch});
    try output.print(allocator, "  \"source_active_enforcement_policy_ready\": {},\n", .{source.active_enforcement_policy_ready});
    try output.print(allocator, "  \"source_merge_blocker_policy_ready\": {},\n", .{source.merge_blocker_policy_ready});
    try appendJsonField(allocator, &output, "reason", options.reason, true);
    try appendJsonField(allocator, &output, "reviewed_by", options.reviewed_by, true);
    try appendJsonField(allocator, &output, "policy", options.policy, true);
    try appendJsonField(allocator, &output, "required_status_check_enforcement_evaluator_status", evaluationStatusText(result.status), true);
    try output.print(allocator, "  \"ready_for_next_branch\": {},\n", .{result.ready_for_next_branch});
    try output.print(allocator, "  \"blocked_findings_count\": {d},\n", .{result.blocked_findings_count});
    try output.print(allocator, "  \"advisory_findings_count\": {d},\n", .{result.advisory_findings_count});
    try appendAuthorityJson(allocator, &output);
    try appendJsonField(allocator, &output, "mutation_authority", mutation_authority, true);
    try output.appendSlice(allocator, "  \"evidence_files\": ");
    try appendEvidenceFilesJson(allocator, &output, evidence.files);
    try output.appendSlice(allocator, ",\n  \"checks\": ");
    try appendChecksJson(allocator, &output, result.checks);
    try output.appendSlice(allocator, ",\n  \"signal_evaluations\": ");
    try appendSignalEvaluationsJson(allocator, &output, result.signal_evaluations);
    try output.appendSlice(allocator, ",\n  \"findings\": ");
    try appendFindingsJson(allocator, &output, result.findings);
    try output.appendSlice(allocator, ",\n  \"blocked_claims\": ");
    try appendStringArray(allocator, &output, blocked_claims);
    try output.appendSlice(allocator, ",\n  \"required_verification_commands\": ");
    try appendStringArray(allocator, &output, required_verification_commands);
    try appendJsonFieldPrefixComma(allocator, &output, "generated_by", generated_by);
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

fn formatEvaluatorText(
    allocator: std.mem.Allocator,
    options: Options,
    source: EnforcementPolicyArtifact,
    evidence: EvidenceAnalysis,
    result: EvaluationResult,
    paths: OutputPaths,
) ![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "zigeffect production telemetry CI gate required status check enforcement evaluator\n");
    try output.print(allocator, "schema: {s}\n", .{production_telemetry_ci_gate_required_status_check_enforcement_evaluator_schema});
    try output.print(allocator, "source enforcement policy: {s}\n", .{options.policy_path});
    try output.print(allocator, "source policy status: {s}\n", .{source.required_status_check_enforcement_policy_status});
    try output.print(allocator, "source policy ready for next branch: {}\n", .{source.ready_for_next_branch});
    try output.print(allocator, "source active enforcement policy ready: {}\n", .{source.active_enforcement_policy_ready});
    try output.print(allocator, "source merge blocker policy ready: {}\n", .{source.merge_blocker_policy_ready});
    try output.print(allocator, "required status check enforcement evaluator: {s}\n", .{evaluationStatusText(result.status)});
    try output.print(allocator, "ready for next branch: {}\n", .{result.ready_for_next_branch});
    try output.print(allocator, "blocked findings count: {d}\n", .{result.blocked_findings_count});
    try output.print(allocator, "advisory findings count: {d}\n", .{result.advisory_findings_count});
    try output.print(allocator, "mutation authority: {s}\n", .{mutation_authority});
    try output.print(allocator, "reviewed_by: {s}\n", .{options.reviewed_by});
    try output.print(allocator, "policy: {s}\n", .{options.policy});
    try output.print(allocator, "reason: {s}\n", .{options.reason});
    try output.print(allocator, "source branch: {s}\n", .{source_branch});
    try output.print(allocator, "recommendation: {s}\n", .{recommendation});
    try output.print(allocator, "next branch if ready: {s}\n", .{next_branch_if_ready});
    try output.print(allocator, "json output: {s}\n", .{paths.json_path});
    try output.print(allocator, "text output: {s}\n\n", .{paths.text_path});

    try output.appendSlice(allocator, "evidence files:\n");
    for (evidence.files) |file| {
        try output.print(allocator, "- {s}: {s}, {d} bytes, {s}", .{ file.path, evidenceClassText(file.class), file.size_bytes, file.sha256 });
        if (file.detected_schema.len > 0) try output.print(allocator, ", schema={s}", .{file.detected_schema});
        if (file.denied_reason.len > 0) try output.print(allocator, ", denied={s}", .{file.denied_reason});
        try output.append(allocator, '\n');
    }
    try output.append(allocator, '\n');

    try output.appendSlice(allocator, "signals:\n");
    for (result.signal_evaluations) |signal| {
        try output.print(allocator, "- {s}: {s} - {s}", .{ signal.id, signalStatusText(signal.status), signal.detail });
        if (signal.evidence_path.len > 0) try output.print(allocator, " ({s})", .{signal.evidence_path});
        try output.append(allocator, '\n');
    }
    try output.append(allocator, '\n');

    try output.appendSlice(allocator, "findings:\n");
    if (result.findings.len == 0) {
        try output.appendSlice(allocator, "- none\n");
    } else {
        for (result.findings) |finding| {
            try output.print(allocator, "- {s}: {s} {s} - {s}", .{ finding.severity, finding.id, finding.signal, finding.detail });
            if (finding.evidence_path.len > 0) try output.print(allocator, " ({s})", .{finding.evidence_path});
            try output.append(allocator, '\n');
        }
    }
    try output.append(allocator, '\n');

    try output.appendSlice(allocator, "checks:\n");
    for (result.checks) |check| {
        try output.print(allocator, "- {s}: {s} - {s}\n", .{ check.name, checkStatusText(check.status), check.detail });
    }
    try output.append(allocator, '\n');

    try appendTextList(allocator, &output, "blocked claims", blocked_claims);
    try appendTextList(allocator, &output, "required verification commands", required_verification_commands);
    try appendTextList(allocator, &output, "agent guidance", agentGuidance(result.status));

    return output.toOwnedSlice(allocator);
}

fn appendAuthorityJson(allocator: std.mem.Allocator, output: *std.ArrayList(u8)) !void {
    try output.print(allocator, "  \"ci_gate_enabled\": {},\n", .{ci_gate_enabled});
    try output.print(allocator, "  \"ci_gate_enforcement_enabled\": {},\n", .{ci_gate_enforcement_enabled});
    try output.print(allocator, "  \"ci_required_status_check_enabled\": {},\n", .{ci_required_status_check_enabled});
    try output.print(allocator, "  \"ci_workflow_mutation_enabled\": {},\n", .{ci_workflow_mutation_enabled});
    try output.print(allocator, "  \"ci_upload_execution_enabled\": {},\n", .{ci_upload_execution_enabled});
    try output.print(allocator, "  \"ci_report_publication_enabled\": {},\n", .{ci_report_publication_enabled});
    try output.print(allocator, "  \"github_api_mutation_enabled\": {},\n", .{github_api_mutation_enabled});
    try output.print(allocator, "  \"github_check_run_creation_enabled\": {},\n", .{github_check_run_creation_enabled});
    try output.print(allocator, "  \"branch_protection_mutation_by_tool_enabled\": {},\n", .{branch_protection_mutation_by_tool_enabled});
    try output.print(allocator, "  \"github_step_summary_write_enabled\": {},\n", .{github_step_summary_write_enabled});
    try output.print(allocator, "  \"pull_request_comment_enabled\": {},\n", .{pull_request_comment_enabled});
    try output.print(allocator, "  \"production_telemetry_ingestion\": {},\n", .{production_telemetry_ingestion});
    try output.print(allocator, "  \"live_exporter_enabled\": {},\n", .{live_exporter_enabled});
    try output.print(allocator, "  \"network_send_enabled\": {},\n", .{network_send_enabled});
    try output.print(allocator, "  \"collector_endpoint_configured\": {},\n", .{collector_endpoint_configured});
    try output.print(allocator, "  \"otlp_serialization_enabled\": {},\n", .{otlp_serialization_enabled});
    try output.print(allocator, "  \"runtime_pipeline_enabled\": {},\n", .{runtime_pipeline_enabled});
    try output.print(allocator, "  \"durable_write_enabled\": {},\n", .{durable_write_enabled});
    try output.print(allocator, "  \"nendb_write_enabled\": {},\n", .{nendb_write_enabled});
}

fn appendEvidenceFilesJson(allocator: std.mem.Allocator, output: *std.ArrayList(u8), files: []const EvidenceFile) !void {
    try output.append(allocator, '[');
    for (files, 0..) |file, index| {
        if (index > 0) try output.appendSlice(allocator, ", ");
        try output.appendSlice(allocator, "{ \"path\": ");
        try appendJsonString(allocator, output, file.path);
        try output.appendSlice(allocator, ", \"class\": ");
        try appendJsonString(allocator, output, evidenceClassText(file.class));
        try output.print(allocator, ", \"size_bytes\": {d}, \"sha256\": ", .{file.size_bytes});
        try appendJsonString(allocator, output, file.sha256);
        try output.appendSlice(allocator, ", \"detected_schema\": ");
        try appendJsonString(allocator, output, file.detected_schema);
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

fn appendSignalEvaluationsJson(allocator: std.mem.Allocator, output: *std.ArrayList(u8), signals: []const SignalEvaluation) !void {
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

fn evidenceClassText(class: EvidenceClass) []const u8 {
    return switch (class) {
        .source_policy => "source_policy",
        .source_application_boundary => "source_application_boundary",
        .release_gate_json => "release_gate_json",
        .release_gate_text => "release_gate_text",
        .causal_json => "causal_json",
        .causal_text => "causal_text",
        .denied => "denied",
    };
}

const blocked_claims: []const []const u8 = &.{
    "github-api-mutated-by-tool",
    "branch-protection-mutated-by-tool",
    "workflow-mutated-by-tool",
    "check-run-created-by-tool",
    "artifact-upload-executed-by-tool",
    "step-summary-or-pr-comment-written-by-tool",
    "live-telemetry-ingested",
    "runtime-pipeline-enabled",
    "durable-production-write-enabled",
    "nendb-write-enabled",
    "production-health-proven",
    "deployment-success-proven",
    "customer-impact-proven",
    "production-cluster-ready",
    "non-nendb-durable-adapter",
    "react-or-alternate-renderer",
    "mutation-authority-granted",
};

fn agentGuidance(status: EvaluationStatus) []const []const u8 {
    return switch (status) {
        .ready => &.{
            "Use this evaluator artifact as bounded evidence for the next enforcement report branch.",
            "Do not mutate GitHub, branch protection, workflows, check runs, uploads, comments, live telemetry, durable stores, or NenDB.",
        },
        .advisory_findings => &.{
            "Surface advisory findings in the next enforcement report without converting them into required checks or production claims.",
            "Add explicit bounded evidence when active enforcement or merge-blocking observations are missing.",
        },
        .blocked => &.{
            "Treat blocked evaluator findings as a stop sign for the enforcement report branch.",
            "Repair source policy readiness or remove denied evidence claims before proceeding.",
        },
    };
}

fn readRequiredArtifact(io: std.Io, allocator: std.mem.Allocator, path: []const u8, err: anyerror) ![]const u8 {
    return std.Io.Dir.cwd().readFileAlloc(io, path, allocator, .limited(max_evidence_bytes)) catch |read_err| switch (read_err) {
        error.FileNotFound => err,
        else => read_err,
    };
}

fn readEvidenceInputs(io: std.Io, allocator: std.mem.Allocator, paths: []const []const u8) ![]const EvidenceInput {
    if (paths.len == 0) return error.MissingEvidenceInput;
    var inputs = std.ArrayList(EvidenceInput).empty;
    errdefer {
        for (inputs.items) |input| allocator.free(input.contents);
        inputs.deinit(allocator);
    }

    for (paths) |path| {
        const contents = try readRequiredArtifact(io, allocator, path, error.MissingEvidenceInput);
        errdefer allocator.free(contents);
        try inputs.append(allocator, .{ .path = path, .contents = contents });
    }

    return inputs.toOwnedSlice(allocator);
}

fn deinitEvidenceInputs(allocator: std.mem.Allocator, inputs: []const EvidenceInput) void {
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

    const evidence_inputs = try readEvidenceInputs(init.io, allocator, options.evidence_paths);
    defer deinitEvidenceInputs(allocator, evidence_inputs);

    const reports = try formatReports(allocator, .{
        .options = options,
        .source_policy_json = source_policy_json,
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
    return "usage: zig build causal-production-telemetry-ci-gate-required-status-check-enforcement-evaluator -- --from-policy <required-status-check-enforcement-policy.json> evaluate --reason <reason> --evidence <path>... [--by <actor>] [--policy <policy>] [--out-prefix <path-prefix>]\n";
}

fn failUsage(err: anyerror) noreturn {
    std.debug.print("causal-production-telemetry-ci-gate-required-status-check-enforcement-evaluator error: {s}\n{s}", .{ @errorName(err), usage() });
    std.process.exit(2);
}

fn freeSliceOnly(allocator: std.mem.Allocator, values: []const []const u8) void {
    if (values.len > 0) allocator.free(values);
}

test "required status check enforcement evaluator constants are stable" {
    try std.testing.expectEqualStrings(
        "zigeffect.causal.production-telemetry-ci-gate-required-status-check-enforcement-evaluator.v1",
        production_telemetry_ci_gate_required_status_check_enforcement_evaluator_schema,
    );
    try std.testing.expectEqual(@as(u32, 1), production_telemetry_ci_gate_required_status_check_enforcement_evaluator_schema_version);
    try std.testing.expectEqualStrings(
        "codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-enforcement-evaluator",
        source_branch,
    );
    try std.testing.expectEqualStrings(
        "start-production-telemetry-ci-gate-required-status-check-enforcement-report",
        recommendation,
    );
    try std.testing.expectEqualStrings(
        "codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-enforcement-report",
        next_branch_if_ready,
    );
    try std.testing.expect(containsString(required_verification_commands, "zig build causal-production-telemetry-ci-gate-required-status-check-enforcement-policy"));
}

test "parseOptions parses evaluate command and repeated evidence files" {
    var options = try parseOptions(std.testing.allocator, &.{
        "zigeffect-causal-production-telemetry-ci-gate-required-status-check-enforcement-evaluator",
        "--from-policy",
        ".zig-cache/causal-artifacts/required-status-check-enforcement-policy.json",
        "evaluate",
        "--reason",
        "required status check enforcement evidence evaluated",
        "--by",
        "codex",
        "--policy",
        "manual-production-telemetry-ci-gate-required-status-check-enforcement-evaluator",
        "--evidence",
        ".zig-cache/causal-artifacts/required-status-check-enforcement-policy.json",
        "--evidence",
        ".zig-cache/causal-artifacts/required-status-check-enforcement-application-boundary.txt",
        "--out-prefix",
        ".zig-cache/causal-artifacts/custom-required-status-check-enforcement-evaluator",
    });
    defer options.deinit(std.testing.allocator);

    try std.testing.expectEqualStrings(".zig-cache/causal-artifacts/required-status-check-enforcement-policy.json", options.policy_path);
    try std.testing.expectEqualStrings("required status check enforcement evidence evaluated", options.reason);
    try std.testing.expectEqualStrings("codex", options.reviewed_by);
    try std.testing.expectEqual(@as(usize, 2), options.evidence_paths.len);
    try std.testing.expectEqualStrings(".zig-cache/causal-artifacts/required-status-check-enforcement-policy.json", options.evidence_paths[0]);
    try std.testing.expectEqualStrings(".zig-cache/causal-artifacts/required-status-check-enforcement-application-boundary.txt", options.evidence_paths[1]);
    try std.testing.expectEqualStrings(".zig-cache/causal-artifacts/custom-required-status-check-enforcement-evaluator", options.out_prefix.?);
}

test "parseOptions rejects invalid policy and evidence paths" {
    try std.testing.expectError(error.InvalidPolicyPath, parseOptions(std.testing.allocator, &.{ "tool", "--from-policy", "source.txt", "evaluate", "--reason", "reviewed", "--evidence", "a.json" }));
    try std.testing.expectError(error.UnknownCommand, parseOptions(std.testing.allocator, &.{ "tool", "--from-policy", "source.json", "summarize", "--reason", "reviewed", "--evidence", "a.json" }));
    try std.testing.expectError(error.MissingReason, parseOptions(std.testing.allocator, &.{ "tool", "--from-policy", "source.json", "evaluate", "--evidence", "a.json" }));
    try std.testing.expectError(error.InvalidEvidencePath, parseOptions(std.testing.allocator, &.{ "tool", "--from-policy", "source.json", "evaluate", "--reason", "reviewed", "--evidence", "a.bin" }));
}

test "default output path replaces enforcement policy suffix" {
    const options = Options{
        .policy_path = "../../.zig-cache/causal-artifacts/example-ci-gate-required-status-check-enforcement-policy.json",
        .reason = "planned",
        .evidence_paths = &.{".zig-cache/causal-artifacts/evidence.json"},
    };
    const paths = try outputPathsForOptions(std.testing.allocator, options);
    defer paths.deinit(std.testing.allocator);

    try std.testing.expectEqualStrings("../../.zig-cache/causal-artifacts/example-ci-gate-required-status-check-enforcement-evaluator.json", paths.json_path);
    try std.testing.expectEqualStrings("../../.zig-cache/causal-artifacts/example-ci-gate-required-status-check-enforcement-evaluator.txt", paths.text_path);
}

test "classifyEvidence detects source policy application boundary release gate and causal files" {
    var evidence = try analyzeEvidence(std.testing.allocator, &.{
        .{ .path = ".zig-cache/causal-artifacts/policy.json", .contents = ready_planned_policy_json },
        .{ .path = ".zig-cache/causal-artifacts/application-boundary.json", .contents = active_application_boundary_json },
        .{ .path = ".zig-cache/release-gate/zigeffect-release-gate.json", .contents = release_gate_json },
        .{ .path = ".zig-cache/release-gate/zigeffect-release-gate.txt", .contents = release_gate_text },
        .{ .path = ".zig-cache/causal-artifacts/causal.json", .contents = causal_json },
        .{ .path = ".zig-cache/causal-artifacts/causal.txt", .contents = causal_text },
    });
    defer evidence.deinit(std.testing.allocator);

    try std.testing.expectEqual(EvidenceClass.source_policy, evidence.files[0].class);
    try std.testing.expectEqual(EvidenceClass.source_application_boundary, evidence.files[1].class);
    try std.testing.expectEqual(EvidenceClass.release_gate_json, evidence.files[2].class);
    try std.testing.expectEqual(EvidenceClass.release_gate_text, evidence.files[3].class);
    try std.testing.expectEqual(EvidenceClass.causal_json, evidence.files[4].class);
    try std.testing.expectEqual(EvidenceClass.causal_text, evidence.files[5].class);
}

test "classifyEvidence denies secret mutation production storage and renderer claims" {
    const markers = [_][]const u8{
        "ghp_secret",
        "github_api_mutation_enabled=true",
        "branch_protection_mutation_by_tool_enabled=true",
        "ci_workflow_mutation_enabled=true",
        "github_check_run_creation_enabled=true",
        "ci_upload_execution_enabled=true",
        "collector_endpoint_configured=true",
        "durable_write_enabled=true",
        "nendb_write_enabled=true",
        "durable_adapter=non-nendb",
        "production_health=proven",
        "renderer=react",
    };
    for (markers) |marker| {
        const contents = try std.fmt.allocPrint(std.testing.allocator, "{{\"schema\":\"zigeffect.causal.v1\",\"claim\":\"{s}\"}}", .{marker});
        defer std.testing.allocator.free(contents);
        var evidence = try analyzeEvidence(std.testing.allocator, &.{.{ .path = ".zig-cache/causal-artifacts/denied.json", .contents = contents }});
        defer evidence.deinit(std.testing.allocator);
        try std.testing.expect(evidence.files[0].denied_reason.len > 0);
    }
}

test "ready planned policy with safe evidence yields ready evaluator" {
    const result = try evaluateFixture(ready_planned_policy_json, &.{
        .{ .path = ".zig-cache/causal-artifacts/policy.json", .contents = ready_planned_policy_json },
        .{ .path = ".zig-cache/release-gate/zigeffect-release-gate.json", .contents = release_gate_json },
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(EvaluationStatus.ready, result.status);
    try std.testing.expect(result.ready_for_next_branch);
    try std.testing.expectEqual(@as(usize, 0), result.blocked_findings_count);
    try std.testing.expectEqual(@as(usize, 0), result.advisory_findings_count);
}

test "active policy without active evidence yields advisory findings" {
    const result = try evaluateFixture(active_policy_json, &.{
        .{ .path = ".zig-cache/causal-artifacts/policy.json", .contents = active_policy_json },
        .{ .path = ".zig-cache/release-gate/zigeffect-release-gate.json", .contents = release_gate_json },
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(EvaluationStatus.advisory_findings, result.status);
    try std.testing.expect(result.ready_for_next_branch);
    try std.testing.expect(result.advisory_findings_count > 0);
}

test "merge policy without merge evidence yields advisory findings" {
    const result = try evaluateFixture(merge_policy_json, &.{
        .{ .path = ".zig-cache/causal-artifacts/policy.json", .contents = merge_policy_json },
        .{ .path = ".zig-cache/causal-artifacts/application-boundary.json", .contents = active_application_boundary_json },
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(EvaluationStatus.advisory_findings, result.status);
    try std.testing.expect(result.ready_for_next_branch);
    try std.testing.expect(result.advisory_findings_count > 0);
}

test "active and merge evidence matching policy yields ready evaluator" {
    const result = try evaluateFixture(merge_policy_json, &.{
        .{ .path = ".zig-cache/causal-artifacts/policy.json", .contents = merge_policy_json },
        .{ .path = ".zig-cache/causal-artifacts/application-boundary.json", .contents = merge_application_boundary_json },
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(EvaluationStatus.ready, result.status);
    try std.testing.expect(result.ready_for_next_branch);
}

test "blocked source policy or denied evidence blocks evaluator" {
    const blocked_source = try evaluateFixture(blocked_policy_json, &.{
        .{ .path = ".zig-cache/causal-artifacts/policy.json", .contents = blocked_policy_json },
    });
    defer blocked_source.deinit(std.testing.allocator);
    try std.testing.expectEqual(EvaluationStatus.blocked, blocked_source.status);

    const denied_evidence = try evaluateFixture(ready_planned_policy_json, &.{
        .{ .path = ".zig-cache/causal-artifacts/policy.json", .contents = ready_planned_policy_json },
        .{ .path = ".zig-cache/causal-artifacts/denied.json", .contents = denied_mutation_json },
    });
    defer denied_evidence.deinit(std.testing.allocator);
    try std.testing.expectEqual(EvaluationStatus.blocked, denied_evidence.status);
}

test "reports include required evaluator fields and guidance" {
    const reports = try formatReports(std.testing.allocator, .{
        .options = sampleOptions(),
        .source_policy_json = ready_planned_policy_json,
        .evidence_inputs = &.{
            .{ .path = ".zig-cache/causal-artifacts/policy.json", .contents = ready_planned_policy_json },
            .{ .path = ".zig-cache/release-gate/zigeffect-release-gate.json", .contents = release_gate_json },
        },
    });
    defer reports.deinit(std.testing.allocator);

    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"schema\": \"zigeffect.causal.production-telemetry-ci-gate-required-status-check-enforcement-evaluator.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"required_status_check_enforcement_evaluator_status\": \"ready\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"ready_for_next_branch\": true") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"mutation_authority\": \"none\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"next_branch_if_ready\": \"codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-enforcement-report\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.text, "required status check enforcement evaluator: ready") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.text, "recommendation: start-production-telemetry-ci-gate-required-status-check-enforcement-report") != null);
}

fn evaluateFixture(source_json: []const u8, evidence_inputs: []const EvidenceInput) !EvaluationResult {
    var parsed = try std.json.parseFromSlice(EnforcementPolicyArtifact, std.testing.allocator, source_json, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();
    var evidence = try analyzeEvidence(std.testing.allocator, evidence_inputs);
    defer evidence.deinit(std.testing.allocator);
    return evaluatePolicyAndEvidence(std.testing.allocator, parsed.value, evidence);
}

fn sampleOptions() Options {
    return .{
        .policy_path = ".zig-cache/causal-artifacts/required-status-check-enforcement-policy.json",
        .reason = "required status check enforcement evidence evaluated",
        .evidence_paths = &.{".zig-cache/causal-artifacts/evidence.json"},
    };
}

fn containsString(values: []const []const u8, needle: []const u8) bool {
    for (values) |value| {
        if (std.mem.indexOf(u8, value, needle) != null) return true;
    }
    return false;
}

const common_policy_catalog_json =
    \\"enforcement_interpretation_policy": [
    \\  { "id": "planned-enforcement", "source_state": "planned", "allowed_claim": "design only", "required_source_evidence": "planned", "denied_claims": "active enforcement", "next_use": "evaluator" }
    \\],
    \\"evidence_requirements": [
    \\  { "id": "source-enforcement-application-boundary", "allowed": true, "detail": "source boundary" }
    \\],
    \\"checks": [
    \\  { "name": "source-schema", "status": "pass", "detail": "source schema supported" }
    \\],
    \\"denied_inference_rules": ["enforcement-policy-is-not-github-api-mutation-by-tool"],
    \\"negative_fixtures": [
    \\  { "id": "blocked-source-denied", "artifact_state": "blocked", "decision": "deny", "failed_gate": "source-policy-ready", "reason": "blocked source denied" }
    \\],
    \\"blocked_claims": ["github-api-mutated-by-tool", "nendb-write-enabled"],
    \\"required_verification_commands": [
    \\  "zig build causal-production-telemetry-ci-gate-required-status-check-enforcement-policy",
    \\  "zig build causal-artifacts"
    \\],
    \\"verified_commands": [
    \\  "zig build causal-production-telemetry-ci-gate-required-status-check-enforcement-policy",
    \\  "zig build causal-artifacts"
    \\]
;

const ready_planned_policy_json =
    \\{
    \\  "schema": "zigeffect.causal.production-telemetry-ci-gate-required-status-check-enforcement-policy.v1",
    \\  "schema_version": 1,
    \\  "source_enforcement_application_boundary": ".zig-cache/causal-artifacts/application-boundary.json",
    \\  "source_enforcement_application_status": "planned",
    \\  "source_mode": "plan",
    \\  "source_applied": false,
    \\  "source_active_enforcement_recorded": false,
    \\  "source_merge_blocking_recorded": false,
    \\  "source_active_enforcement_claim_allowed": false,
    \\  "source_merge_blocker_claim_allowed": false,
    \\  "required_status_check_enforcement_policy_status": "ready",
    \\  "ready_for_next_branch": true,
    \\  "active_enforcement_policy_ready": false,
    \\  "merge_blocker_policy_ready": false,
    \\  "mutation_authority": "none",
    \\  "ci_gate_enabled": false,
    \\  "ci_gate_enforcement_enabled": false,
    \\  "ci_required_status_check_enabled": false,
    \\  "ci_workflow_mutation_enabled": false,
    \\  "ci_upload_execution_enabled": false,
    \\  "ci_report_publication_enabled": false,
    \\  "github_api_mutation_enabled": false,
    \\  "github_check_run_creation_enabled": false,
    \\  "branch_protection_mutation_by_tool_enabled": false,
    \\  "github_step_summary_write_enabled": false,
    \\  "pull_request_comment_enabled": false,
    \\  "production_telemetry_ingestion": false,
    \\  "live_exporter_enabled": false,
    \\  "network_send_enabled": false,
    \\  "collector_endpoint_configured": false,
    \\  "otlp_serialization_enabled": false,
    \\  "runtime_pipeline_enabled": false,
    \\  "durable_write_enabled": false,
    \\  "nendb_write_enabled": false,
    \\
++ common_policy_catalog_json ++
    \\
    \\}
;

const active_policy_json =
    \\{
    \\  "schema": "zigeffect.causal.production-telemetry-ci-gate-required-status-check-enforcement-policy.v1",
    \\  "schema_version": 1,
    \\  "source_enforcement_application_status": "applied",
    \\  "source_mode": "record-applied",
    \\  "source_applied": true,
    \\  "source_active_enforcement_recorded": true,
    \\  "source_merge_blocking_recorded": false,
    \\  "source_active_enforcement_claim_allowed": true,
    \\  "source_merge_blocker_claim_allowed": false,
    \\  "required_status_check_enforcement_policy_status": "ready",
    \\  "ready_for_next_branch": true,
    \\  "active_enforcement_policy_ready": true,
    \\  "merge_blocker_policy_ready": false,
    \\  "mutation_authority": "none",
    \\  "ci_gate_enabled": false,
    \\  "ci_gate_enforcement_enabled": false,
    \\  "ci_required_status_check_enabled": false,
    \\  "ci_workflow_mutation_enabled": false,
    \\  "ci_upload_execution_enabled": false,
    \\  "ci_report_publication_enabled": false,
    \\  "github_api_mutation_enabled": false,
    \\  "github_check_run_creation_enabled": false,
    \\  "branch_protection_mutation_by_tool_enabled": false,
    \\  "github_step_summary_write_enabled": false,
    \\  "pull_request_comment_enabled": false,
    \\  "production_telemetry_ingestion": false,
    \\  "live_exporter_enabled": false,
    \\  "network_send_enabled": false,
    \\  "collector_endpoint_configured": false,
    \\  "otlp_serialization_enabled": false,
    \\  "runtime_pipeline_enabled": false,
    \\  "durable_write_enabled": false,
    \\  "nendb_write_enabled": false,
    \\
++ common_policy_catalog_json ++
    \\
    \\}
;

const merge_policy_json =
    \\{
    \\  "schema": "zigeffect.causal.production-telemetry-ci-gate-required-status-check-enforcement-policy.v1",
    \\  "schema_version": 1,
    \\  "source_enforcement_application_status": "applied",
    \\  "source_mode": "record-applied",
    \\  "source_applied": true,
    \\  "source_active_enforcement_recorded": true,
    \\  "source_merge_blocking_recorded": true,
    \\  "source_active_enforcement_claim_allowed": true,
    \\  "source_merge_blocker_claim_allowed": true,
    \\  "required_status_check_enforcement_policy_status": "ready",
    \\  "ready_for_next_branch": true,
    \\  "active_enforcement_policy_ready": true,
    \\  "merge_blocker_policy_ready": true,
    \\  "mutation_authority": "none",
    \\  "ci_gate_enabled": false,
    \\  "ci_gate_enforcement_enabled": false,
    \\  "ci_required_status_check_enabled": false,
    \\  "ci_workflow_mutation_enabled": false,
    \\  "ci_upload_execution_enabled": false,
    \\  "ci_report_publication_enabled": false,
    \\  "github_api_mutation_enabled": false,
    \\  "github_check_run_creation_enabled": false,
    \\  "branch_protection_mutation_by_tool_enabled": false,
    \\  "github_step_summary_write_enabled": false,
    \\  "pull_request_comment_enabled": false,
    \\  "production_telemetry_ingestion": false,
    \\  "live_exporter_enabled": false,
    \\  "network_send_enabled": false,
    \\  "collector_endpoint_configured": false,
    \\  "otlp_serialization_enabled": false,
    \\  "runtime_pipeline_enabled": false,
    \\  "durable_write_enabled": false,
    \\  "nendb_write_enabled": false,
    \\
++ common_policy_catalog_json ++
    \\
    \\}
;

const blocked_policy_json =
    \\{
    \\  "schema": "zigeffect.causal.production-telemetry-ci-gate-required-status-check-enforcement-policy.v1",
    \\  "schema_version": 1,
    \\  "required_status_check_enforcement_policy_status": "blocked",
    \\  "ready_for_next_branch": false,
    \\  "active_enforcement_policy_ready": false,
    \\  "merge_blocker_policy_ready": false,
    \\  "mutation_authority": "none",
    \\  "ci_gate_enabled": false,
    \\  "ci_gate_enforcement_enabled": false,
    \\  "ci_required_status_check_enabled": false,
    \\  "ci_workflow_mutation_enabled": false,
    \\  "ci_upload_execution_enabled": false,
    \\  "ci_report_publication_enabled": false,
    \\  "github_api_mutation_enabled": false,
    \\  "github_check_run_creation_enabled": false,
    \\  "branch_protection_mutation_by_tool_enabled": false,
    \\  "github_step_summary_write_enabled": false,
    \\  "pull_request_comment_enabled": false,
    \\  "production_telemetry_ingestion": false,
    \\  "live_exporter_enabled": false,
    \\  "network_send_enabled": false,
    \\  "collector_endpoint_configured": false,
    \\  "otlp_serialization_enabled": false,
    \\  "runtime_pipeline_enabled": false,
    \\  "durable_write_enabled": false,
    \\  "nendb_write_enabled": false,
    \\
++ common_policy_catalog_json ++
    \\
    \\}
;

const active_application_boundary_json =
    \\{
    \\  "schema": "zigeffect.causal.production-telemetry-ci-gate-required-status-check-enforcement-application-boundary.v1",
    \\  "schema_version": 1,
    \\  "required_status_check_enforcement_application_status": "applied",
    \\  "applied": true,
    \\  "active_enforcement_recorded": true,
    \\  "active_enforcement_claim_allowed": true,
    \\  "merge_blocking_recorded": false,
    \\  "merge_blocker_claim_allowed": false,
    \\  "mutation_authority": "none"
    \\}
;

const merge_application_boundary_json =
    \\{
    \\  "schema": "zigeffect.causal.production-telemetry-ci-gate-required-status-check-enforcement-application-boundary.v1",
    \\  "schema_version": 1,
    \\  "required_status_check_enforcement_application_status": "applied",
    \\  "applied": true,
    \\  "active_enforcement_recorded": true,
    \\  "active_enforcement_claim_allowed": true,
    \\  "merge_blocking_recorded": true,
    \\  "merge_blocker_claim_allowed": true,
    \\  "merge_blocking_evidence": ["merge is blocked when required check fails"],
    \\  "mutation_authority": "none"
    \\}
;

const release_gate_json =
    \\{
    \\  "schema": "zigeffect.release-gate.v1",
    \\  "schema_version": 1,
    \\  "generated_by": "release-gate",
    \\  "status": "pass"
    \\}
;

const release_gate_text =
    \\zigeffect release gate
    \\status: pass
;

const causal_json =
    \\{
    \\  "schema": "zigeffect.causal.v1",
    \\  "schema_version": 1,
    \\  "artifact_id": "causal-dogfood"
    \\}
;

const causal_text =
    \\zigeffect causal artifact
    \\event ids: test.failure
;

const denied_mutation_json =
    \\{
    \\  "schema": "zigeffect.causal.v1",
    \\  "schema_version": 1,
    \\  "github_api_mutation_enabled": true
    \\}
;
