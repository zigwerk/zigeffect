const std = @import("std");

pub const production_telemetry_ci_gate_dry_run_evaluator_schema = "zigeffect.causal.production-telemetry-ci-gate-dry-run-evaluator.v1";
pub const production_telemetry_ci_gate_dry_run_evaluator_schema_version: u32 = 1;
pub const source_branch = "codex/zigeffect-causal-production-telemetry-ci-gate-dry-run-evaluator";
pub const recommendation = "start-production-telemetry-ci-gate-advisory-ci-report";
pub const next_branch_if_ready = "codex/zigeffect-causal-production-telemetry-ci-gate-advisory-ci-report";

const dry_run_policy_schema = "zigeffect.causal.production-telemetry-ci-gate-dry-run-policy.v1";
const generated_by = "causal-production-telemetry-ci-gate-dry-run-evaluator";
const max_evidence_files = 32;
const max_evidence_bytes = 1024 * 1024;

const required_verification_commands: []const []const u8 = &.{
    "zig build causal-production-telemetry-ci-gate-dry-run-policy",
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

const EvaluationStatus = enum { ready, advisory_findings, blocked };
const SignalStatus = enum { observed, missing, blocked };
const CheckStatus = enum { pass, fail, skipped };
const EvidenceClass = enum { causal_json, causal_text, release_gate_json, release_gate_text, ci_handoff, source_policy, denied };

const Options = struct {
    dry_run_policy_path: []const u8,
    reason: []const u8,
    reviewed_by: []const u8 = "ci-gate-dry-run-evaluator",
    policy: []const u8 = "manual-production-telemetry-ci-gate-dry-run-evaluator",
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
    source_dry_run_policy_json: []const u8,
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

const CandidateSignalPolicy = struct {
    id: []const u8,
    evaluation_mode: []const u8 = "",
    enforcement_enabled: bool = false,
    required_status_check_enabled: bool = false,
    failure_effect: []const u8 = "",
    evidence: []const u8 = "",
    blocked_claim: []const u8 = "",
};

const EvidenceRequirement = struct {
    id: []const u8,
    allowed: bool = true,
    detail: []const u8 = "",
};

const DryRunPolicyArtifact = struct {
    schema: []const u8,
    schema_version: u32,
    source_gate_application_boundary: []const u8 = "",
    source_boundary_status: []const u8 = "",
    source_boundary_mode: []const u8 = "",
    source_boundary_applied: bool = false,
    source_boundary_mutation_authority: []const u8 = "",
    decision: []const u8 = "",
    dry_run_policy_status: []const u8,
    ready_for_next_branch: bool,
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
    candidate_signal_policies: []const CandidateSignalPolicy = &.{},
    evidence_requirements: []const EvidenceRequirement = &.{},
    checks: []const SourceCheck = &.{},
    blocked_claims: []const []const u8 = &.{},
    required_verification_commands: []const []const u8 = &.{},
    generated_by: []const u8 = "",
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
        error.MissingDryRunPolicyInput,
        error.MissingEvidenceInput,
        => failUsage(err),
        else => return err,
    };
}

fn parseOptions(allocator: std.mem.Allocator, args: []const []const u8) !Options {
    if (args.len < 2) return error.MissingDryRunPolicyPath;
    if (!std.mem.eql(u8, args[1], "--from-dry-run-policy")) return error.UnknownFlag;
    if (args.len < 3) return error.MissingDryRunPolicyPath;
    const dry_run_policy_path = args[2];
    if (!std.mem.endsWith(u8, dry_run_policy_path, ".json")) return error.InvalidDryRunPolicyPath;
    if (args.len < 4) return error.MissingCommand;
    if (!std.mem.eql(u8, args[3], "evaluate")) return error.UnknownCommand;

    var reviewed_by: []const u8 = "ci-gate-dry-run-evaluator";
    var policy: []const u8 = "manual-production-telemetry-ci-gate-dry-run-evaluator";
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
        .dry_run_policy_path = dry_run_policy_path,
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
        if (!std.mem.endsWith(u8, options.dry_run_policy_path, ".json")) return error.InvalidDryRunPolicyPath;
        if (std.mem.endsWith(u8, options.dry_run_policy_path, "-ci-gate-dry-run-policy.json")) {
            const suffix_len = "-ci-gate-dry-run-policy.json".len;
            break :blk try std.fmt.allocPrint(allocator, "{s}-ci-gate-dry-run-evaluator", .{options.dry_run_policy_path[0 .. options.dry_run_policy_path.len - suffix_len]});
        }
        const base = options.dry_run_policy_path[0 .. options.dry_run_policy_path.len - ".json".len];
        break :blk try std.fmt.allocPrint(allocator, "{s}-ci-gate-dry-run-evaluator", .{base});
    };
    defer allocator.free(prefix);

    return .{
        .json_path = try std.fmt.allocPrint(allocator, "{s}.json", .{prefix}),
        .text_path = try std.fmt.allocPrint(allocator, "{s}.txt", .{prefix}),
    };
}

fn formatReports(allocator: std.mem.Allocator, input: EvaluatorInput) !EvaluatorReports {
    var parsed = try std.json.parseFromSlice(DryRunPolicyArtifact, allocator, input.source_dry_run_policy_json, .{ .ignore_unknown_fields = true });
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
        const class = classifyEvidencePath(input.path, input.contents);
        const denied_reason = evidenceDeniedReason(input.path, input.contents, class);

        try files.append(allocator, .{
            .path = input.path,
            .class = class,
            .size_bytes = input.contents.len,
            .sha256 = sha,
            .detected_schema = schema,
            .denied_reason = denied_reason,
        });
    }

    return .{ .files = try files.toOwnedSlice(allocator) };
}

fn evaluatePolicyAndEvidence(
    allocator: std.mem.Allocator,
    source: DryRunPolicyArtifact,
    evidence: EvidenceAnalysis,
) !EvaluationResult {
    var checks = std.ArrayList(EvaluationCheck).empty;
    var signals = std.ArrayList(SignalEvaluation).empty;
    var findings = std.ArrayList(Finding).empty;
    errdefer checks.deinit(allocator);
    errdefer signals.deinit(allocator);
    errdefer findings.deinit(allocator);

    try appendCheckAndFinding(allocator, &checks, &findings, "source-policy-schema", sourceSchemaVersionSupported(source), "boundary-source-valid", "source dry-run policy schema is supported");
    try appendCheckAndFinding(allocator, &checks, &findings, "source-policy-ready", std.mem.eql(u8, source.dry_run_policy_status, "ready"), "boundary-source-valid", "source dry-run policy status is ready");
    try appendCheckAndFinding(allocator, &checks, &findings, "source-ready-for-next-branch", source.ready_for_next_branch, "boundary-source-valid", "source dry-run policy is ready for evaluator handoff");
    try appendCheckAndFinding(allocator, &checks, &findings, "source-review-approved", std.mem.eql(u8, source.decision, "approve"), "boundary-source-valid", "source dry-run policy review decision is approve");
    try appendCheckAndFinding(allocator, &checks, &findings, "source-boundary-mode-valid", sourceBoundaryModeValid(source), "boundary-source-valid", "source boundary mode is plan or record-applied");
    try appendCheckAndFinding(allocator, &checks, &findings, "source-boundary-status-valid", sourceBoundaryStatusValid(source), "boundary-source-valid", "source boundary status is planned or applied");
    try appendCheckAndFinding(allocator, &checks, &findings, "source-mutation-authority-valid", sourceMutationAuthorityValid(source), "boundary-source-valid", "source mutation authority remains none or record-only");
    try appendCheckAndFinding(allocator, &checks, &findings, "source-disabled-authority", sourceAuthorityDisabled(source), "boundary-source-valid", "source keeps gate enforcement required checks workflow mutation upload execution runtime durable and NenDB authority disabled");
    try appendCheckAndFinding(allocator, &checks, &findings, "source-policy-checks-passed", sourcePolicyChecksHaveNoFailures(source.checks), "boundary-source-valid", "source dry-run policy checks contain no failures");
    try appendCheckAndFinding(allocator, &checks, &findings, "source-catalogs-present", sourceCatalogsPresent(source), "boundary-source-valid", "source candidate signal policies evidence requirements and blocked claims are present");
    try appendCheckAndFinding(allocator, &checks, &findings, "source-candidate-signals-advisory", sourceCandidateSignalsAdvisory(source), "boundary-source-valid", "source candidate signal policies are advisory and non-enforcing");
    try appendCheckAndFinding(allocator, &checks, &findings, "evidence-files-present", evidence.files.len > 0, "archive-policy-conformance", "explicit bounded evidence files are present");

    for (evidence.files) |file| {
        if (file.denied_reason.len > 0) {
            try appendCheck(allocator, &checks, "evidence-boundary", .fail, file.denied_reason);
            try appendFinding(allocator, &findings, "evidence-denied", "blocked", signalForDeniedEvidence(file), file.denied_reason, file.path);
        }
    }

    const source_valid = checksForSignalPass(checks.items, "source-");
    const has_denied_evidence = evidenceHasDeniedFile(evidence);
    const has_release_gate = evidenceHasClass(evidence, .release_gate_json) or evidenceHasClass(evidence, .release_gate_text);
    const causal_schema_evidence = firstCausalSchemaEvidence(evidence);
    const has_handoff = evidenceHasClass(evidence, .ci_handoff);

    try appendSignal(allocator, &signals, &findings, "boundary-source-valid", if (source_valid) .observed else .blocked, if (source_valid) "source policy is ready approved and non-enforcing" else "source policy failed one or more evaluator preconditions", "");
    try appendSignal(allocator, &signals, &findings, "release-gate-artifact-present", if (has_release_gate) .observed else .missing, if (has_release_gate) "release gate JSON or text evidence is present" else "release gate evidence was not supplied", firstEvidencePathForClasses(evidence, &.{ .release_gate_json, .release_gate_text }));
    try appendSignal(allocator, &signals, &findings, "causal-artifact-schema-parse", if (causal_schema_evidence.len > 0) .observed else .missing, if (causal_schema_evidence.len > 0) "causal JSON evidence parsed as a zigeffect causal schema" else "no causal JSON evidence parsed as a zigeffect causal schema", causal_schema_evidence);
    try appendSignal(allocator, &signals, &findings, "archive-policy-conformance", if (!has_denied_evidence) .observed else .blocked, if (!has_denied_evidence) "all evidence paths are bounded local or CI artifact paths" else "one or more evidence files violates the bounded input policy", firstDeniedEvidencePath(evidence));
    try appendSignal(allocator, &signals, &findings, "redaction-retention-conformance", if (!has_denied_evidence) .observed else .blocked, if (!has_denied_evidence) "no secret-shaped marker or retention violation was found" else "one or more evidence files contains a secret-shaped marker retention violation or authority claim", firstDeniedEvidencePath(evidence));
    try appendSignal(allocator, &signals, &findings, "ci-handoff-present", if (has_handoff) .observed else .missing, if (has_handoff) "CI handoff evidence is present" else "CI handoff evidence was not supplied", firstEvidencePathForClasses(evidence, &.{.ci_handoff}));

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

fn sourceSchemaVersionSupported(source: DryRunPolicyArtifact) bool {
    return std.mem.eql(u8, source.schema, dry_run_policy_schema) and source.schema_version == 1;
}

fn sourceBoundaryModeValid(source: DryRunPolicyArtifact) bool {
    return std.mem.eql(u8, source.source_boundary_mode, "plan") or
        std.mem.eql(u8, source.source_boundary_mode, "record-applied");
}

fn sourceBoundaryStatusValid(source: DryRunPolicyArtifact) bool {
    return std.mem.eql(u8, source.source_boundary_status, "planned") or
        std.mem.eql(u8, source.source_boundary_status, "applied");
}

fn sourceMutationAuthorityValid(source: DryRunPolicyArtifact) bool {
    return std.mem.eql(u8, source.source_boundary_mutation_authority, "none") or
        std.mem.eql(u8, source.source_boundary_mutation_authority, "record-only");
}

fn sourceAuthorityDisabled(source: DryRunPolicyArtifact) bool {
    return !source.ci_gate_enabled and
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

fn sourcePolicyChecksHaveNoFailures(checks: []const SourceCheck) bool {
    if (checks.len == 0) return false;
    for (checks) |check| {
        if (std.mem.eql(u8, check.status, "fail")) return false;
    }
    return true;
}

fn sourceCatalogsPresent(source: DryRunPolicyArtifact) bool {
    return source.candidate_signal_policies.len > 0 and
        source.evidence_requirements.len > 0 and
        source.blocked_claims.len > 0;
}

fn sourceCandidateSignalsAdvisory(source: DryRunPolicyArtifact) bool {
    if (source.candidate_signal_policies.len == 0) return false;
    for (source.candidate_signal_policies) |signal| {
        if (!std.mem.eql(u8, signal.evaluation_mode, "dry-run")) return false;
        if (signal.enforcement_enabled) return false;
        if (signal.required_status_check_enabled) return false;
        if (!std.mem.eql(u8, signal.failure_effect, "advisory")) return false;
    }
    return true;
}

fn checksForSignalPass(checks: []const EvaluationCheck, prefix: []const u8) bool {
    for (checks) |check| {
        if (std.mem.startsWith(u8, check.name, prefix) and check.status == .fail) return false;
    }
    return true;
}

fn classifyEvidencePath(path: []const u8, contents: []const u8) EvidenceClass {
    const is_json = std.mem.endsWith(u8, path, ".json");
    const is_txt = std.mem.endsWith(u8, path, ".txt");
    if (!is_json and !is_txt) return .denied;

    if (std.mem.indexOf(u8, path, ".zig-cache/release-gate/") != null) {
        return if (is_json) .release_gate_json else .release_gate_text;
    }
    if (std.mem.indexOf(u8, path, ".zig-cache/causal-artifacts/") != null) {
        if (std.mem.indexOf(u8, path, "handoff") != null or
            std.mem.indexOf(u8, contents, "causal ci handoff") != null or
            std.mem.indexOf(u8, contents, "causal_handoff") != null)
        {
            return .ci_handoff;
        }
        if (std.mem.endsWith(u8, path, "-ci-gate-dry-run-policy.json")) return .source_policy;
        return if (is_json) .causal_json else .causal_text;
    }
    return .denied;
}

fn evidenceDeniedReason(path: []const u8, contents: []const u8, class: EvidenceClass) []const u8 {
    if (class == .denied) return "evidence path must be a JSON or text artifact under .zig-cache/causal-artifacts or .zig-cache/release-gate";
    if (std.mem.indexOf(u8, contents, "secrets.") != null) return "secret-shaped reference marker is not valid evaluator evidence";
    if (std.mem.indexOf(u8, contents, "PRODUCTION_") != null) return "production secret-shaped environment marker is not valid evaluator evidence";
    if (std.mem.indexOf(u8, contents, "BEGIN PRIVATE KEY") != null) return "private key material is not valid evaluator evidence";
    if (std.mem.indexOf(u8, contents, "Authorization:") != null) return "authorization header material is not valid evaluator evidence";
    if (std.mem.indexOf(u8, contents, "sk-") != null) return "OpenAI-style secret token marker is not valid evaluator evidence";
    if (std.mem.indexOf(u8, contents, "ghp_") != null) return "GitHub token marker is not valid evaluator evidence";
    if (std.mem.indexOf(u8, contents, "xoxb-") != null) return "Slack token marker is not valid evaluator evidence";
    if (std.mem.indexOf(u8, contents, "\"ci_gate_enforcement_enabled\": true") != null) return "CI gate enforcement must remain disabled";
    if (std.mem.indexOf(u8, contents, "\"ci_required_status_check_enabled\": true") != null) return "required status checks must remain disabled";
    if (std.mem.indexOf(u8, contents, "\"ci_workflow_mutation_enabled\": true") != null) return "workflow mutation by the tool must remain disabled";
    if (std.mem.indexOf(u8, contents, "\"ci_upload_execution_enabled\": true") != null) return "artifact upload execution must remain disabled";
    if (std.mem.indexOf(u8, contents, "\"production_telemetry_ingestion\": true") != null) return "live production telemetry ingestion must remain disabled";
    if (std.mem.indexOf(u8, contents, "\"live_exporter_enabled\": true") != null) return "live exporter execution must remain disabled";
    if (std.mem.indexOf(u8, contents, "\"network_send_enabled\": true") != null) return "network send must remain disabled";
    if (std.mem.indexOf(u8, contents, "\"collector_endpoint_configured\": true") != null) return "collector endpoint configuration must remain disabled";
    if (std.mem.indexOf(u8, contents, "\"otlp_serialization_enabled\": true") != null) return "OTLP serialization must remain disabled";
    if (std.mem.indexOf(u8, contents, "\"runtime_pipeline_enabled\": true") != null) return "runtime pipeline enablement must remain disabled";
    if (std.mem.indexOf(u8, contents, "\"durable_write_enabled\": true") != null) return "durable writes must remain disabled";
    if (std.mem.indexOf(u8, contents, "\"nendb_write_enabled\": true") != null) return "NenDB writes must remain disabled";
    if (std.mem.indexOf(u8, contents, "durable_adapter=non-nendb") != null) return "non-NenDB durable adapters remain out of scope";
    if (std.mem.indexOf(u8, contents, "\"durable_adapter\": \"cockroach\"") != null) return "non-NenDB durable adapters remain out of scope";
    if (std.mem.indexOf(u8, contents, "\"durable_adapter\": \"postgres\"") != null) return "non-NenDB durable adapters remain out of scope";
    if (std.mem.indexOf(u8, contents, "\"durable_adapter\": \"d1\"") != null) return "non-NenDB durable adapters remain out of scope";
    if (std.mem.indexOf(u8, contents, "renderer=react") != null) return "SolidJS inside zig-webui remains the workbench renderer direction";
    if (std.mem.indexOf(u8, contents, "\"renderer\": \"react\"") != null) return "SolidJS inside zig-webui remains the workbench renderer direction";
    if (std.mem.indexOf(u8, contents, "artifact_visibility=public") != null) return "public artifact upload claims are not valid evaluator evidence";
    if (retentionAboveLimit(contents, 14)) return "artifact retention evidence exceeds fourteen days";
    _ = path;
    return "";
}

fn retentionAboveLimit(contents: []const u8, limit: u64) bool {
    var offset: usize = 0;
    while (std.mem.indexOf(u8, contents[offset..], "retention_days")) |relative| {
        const marker = offset + relative + "retention_days".len;
        var index = marker;
        while (index < contents.len and (contents[index] == ' ' or contents[index] == '"' or contents[index] == ':' or contents[index] == '=')) : (index += 1) {}
        var value: u64 = 0;
        var saw_digit = false;
        while (index < contents.len and contents[index] >= '0' and contents[index] <= '9') : (index += 1) {
            saw_digit = true;
            value = value * 10 + (contents[index] - '0');
        }
        if (saw_digit and value > limit) return true;
        offset = marker;
    }
    return false;
}

fn signalForDeniedEvidence(file: EvidenceFile) []const u8 {
    if (file.class == .denied) return "archive-policy-conformance";
    if (std.mem.indexOf(u8, file.denied_reason, "retention") != null or
        std.mem.indexOf(u8, file.denied_reason, "secret") != null or
        std.mem.indexOf(u8, file.denied_reason, "token") != null or
        std.mem.indexOf(u8, file.denied_reason, "key material") != null)
    {
        return "redaction-retention-conformance";
    }
    return "archive-policy-conformance";
}

fn evidenceHasDeniedFile(evidence: EvidenceAnalysis) bool {
    for (evidence.files) |file| {
        if (file.denied_reason.len > 0) return true;
    }
    return false;
}

fn evidenceHasClass(evidence: EvidenceAnalysis, class: EvidenceClass) bool {
    for (evidence.files) |file| {
        if (file.class == class and file.denied_reason.len == 0) return true;
    }
    return false;
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

fn firstCausalSchemaEvidence(evidence: EvidenceAnalysis) []const u8 {
    for (evidence.files) |file| {
        if (file.class == .causal_json and
            file.denied_reason.len == 0 and
            std.mem.startsWith(u8, file.detected_schema, "zigeffect.causal."))
        {
            return file.path;
        }
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
    source: DryRunPolicyArtifact,
    evidence: EvidenceAnalysis,
    result: EvaluationResult,
    paths: OutputPaths,
) ![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "{\n");
    try appendJsonField(allocator, &output, "schema", production_telemetry_ci_gate_dry_run_evaluator_schema, true);
    try output.appendSlice(allocator, "  \"schema_version\": 1,\n");
    try appendJsonField(allocator, &output, "source_dry_run_policy", options.dry_run_policy_path, true);
    try appendJsonField(allocator, &output, "source_policy_status", source.dry_run_policy_status, true);
    try appendJsonField(allocator, &output, "source_policy_decision", source.decision, true);
    try appendJsonField(allocator, &output, "source_boundary_status", source.source_boundary_status, true);
    try appendJsonField(allocator, &output, "source_boundary_mode", source.source_boundary_mode, true);
    try appendJsonField(allocator, &output, "source_boundary_mutation_authority", source.source_boundary_mutation_authority, true);
    try appendJsonField(allocator, &output, "evaluation_mode", "dry-run", true);
    try appendJsonField(allocator, &output, "evaluation_status", evaluationStatusText(result.status), true);
    try output.print(allocator, "  \"ready_for_next_branch\": {},\n", .{result.ready_for_next_branch});
    try output.print(allocator, "  \"advisory_findings_count\": {d},\n", .{result.advisory_findings_count});
    try output.print(allocator, "  \"blocked_findings_count\": {d},\n", .{result.blocked_findings_count});
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
    try output.appendSlice(allocator, "  \"evidence_files\": ");
    try appendEvidenceFilesJson(allocator, &output, evidence.files);
    try output.appendSlice(allocator, ",\n  \"signal_evaluations\": ");
    try appendSignalEvaluationsJson(allocator, &output, result.signal_evaluations);
    try output.appendSlice(allocator, ",\n  \"findings\": ");
    try appendFindingsJson(allocator, &output, result.findings);
    try output.appendSlice(allocator, ",\n  \"next_queries\": ");
    try appendStringArray(allocator, &output, nextQueries(result.status));
    try output.appendSlice(allocator, ",\n  \"checks\": ");
    try appendChecksJson(allocator, &output, result.checks);
    try output.appendSlice(allocator, ",\n  \"blocked_claims\": ");
    try appendStringArray(allocator, &output, blockedClaims());
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
    source: DryRunPolicyArtifact,
    evidence: EvidenceAnalysis,
    result: EvaluationResult,
    paths: OutputPaths,
) ![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "zigeffect production telemetry CI gate dry-run evaluator\n");
    try output.print(allocator, "schema: {s}\n", .{production_telemetry_ci_gate_dry_run_evaluator_schema});
    try output.print(allocator, "source dry-run policy: {s}\n", .{options.dry_run_policy_path});
    try output.print(allocator, "source policy status: {s}\n", .{source.dry_run_policy_status});
    try output.print(allocator, "source policy decision: {s}\n", .{source.decision});
    try output.print(allocator, "source boundary status: {s}\n", .{source.source_boundary_status});
    try output.print(allocator, "source boundary mode: {s}\n", .{source.source_boundary_mode});
    try output.appendSlice(allocator, "evaluation mode: dry-run\n");
    try output.print(allocator, "evaluation_status: {s}\n", .{evaluationStatusText(result.status)});
    try output.print(allocator, "ready_for_next_branch: {}\n", .{result.ready_for_next_branch});
    try output.print(allocator, "advisory_findings_count: {d}\n", .{result.advisory_findings_count});
    try output.print(allocator, "blocked_findings_count: {d}\n", .{result.blocked_findings_count});
    try output.print(allocator, "ci gate enforcement enabled: {}\n", .{ci_gate_enforcement_enabled});
    try output.print(allocator, "ci required status check enabled: {}\n", .{ci_required_status_check_enabled});
    try output.print(allocator, "durable write enabled: {}\n", .{durable_write_enabled});
    try output.print(allocator, "nendb write enabled: {}\n", .{nendb_write_enabled});
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

    try appendTextList(allocator, &output, "next queries", nextQueries(result.status));
    try appendTextList(allocator, &output, "blocked claims", blockedClaims());
    try appendTextList(allocator, &output, "required verification commands", required_verification_commands);
    try appendTextList(allocator, &output, "agent guidance", agentGuidance(result.status));

    return output.toOwnedSlice(allocator);
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
        .skipped => "skipped",
    };
}

fn evidenceClassText(class: EvidenceClass) []const u8 {
    return switch (class) {
        .causal_json => "causal_json",
        .causal_text => "causal_text",
        .release_gate_json => "release_gate_json",
        .release_gate_text => "release_gate_text",
        .ci_handoff => "ci_handoff",
        .source_policy => "source_policy",
        .denied => "denied",
    };
}

fn blockedClaims() []const []const u8 {
    return &.{
        "ci-gate-enforcement-active",
        "required-status-check-active",
        "workflow-mutated-by-tool",
        "artifact-upload-executed-by-tool",
        "live-telemetry-ingested",
        "network-send-enabled",
        "collector-endpoint-configured",
        "runtime-pipeline-enabled",
        "durable-production-write-enabled",
        "nendb-write-enabled",
        "production-health-proven",
        "production-cluster-ready",
        "non-nendb-durable-adapter",
        "react-or-alternate-renderer",
        "mutation-authority-granted",
    };
}

fn nextQueries(status: EvaluationStatus) []const []const u8 {
    return switch (status) {
        .ready => &.{
            "Start codex/zigeffect-causal-production-telemetry-ci-gate-advisory-ci-report with this evaluator artifact.",
            "Compare evaluator evidence paths against release-gate and causal artifact outputs before presenting CI summaries.",
            "Keep advisory CI reporting separate from required checks, workflow mutation, live telemetry, durable writes, NenDB writes, and mutation authority.",
        },
        .advisory_findings => &.{
            "Inspect missing signal findings and decide whether advisory CI report should surface them as reviewer guidance.",
            "Add explicit release-gate, causal JSON, or CI handoff evidence when those signals are useful for the next review.",
            "Proceed only as advisory reporting; do not convert missing signals into required checks.",
        },
        .blocked => &.{
            "Repair source policy validity or denied evidence before starting the advisory CI report branch.",
            "Remove secret-shaped, live telemetry, workflow mutation, required check, durable write, NenDB write, or non-NenDB durable adapter claims from evidence.",
            "Regenerate the evaluator after source policy and bounded evidence checks pass.",
        },
    };
}

fn agentGuidance(status: EvaluationStatus) []const []const u8 {
    return switch (status) {
        .ready => &.{
            "Use this as bounded advisory evidence for the next CI report branch.",
            "Do not create required checks, mutate workflows, ingest live telemetry, write durable stores, write NenDB, or claim production cluster readiness.",
        },
        .advisory_findings => &.{
            "Missing signal evidence is reviewer guidance, not enforcement.",
            "Agents may suggest explicit evidence files or next queries, but must preserve dry-run advisory semantics.",
        },
        .blocked => &.{
            "Treat blocked findings as a stop sign for the advisory CI report branch.",
            "Do not infer CI gate readiness, production readiness, or mutation authority from blocked evaluator output.",
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
    const source_dry_run_policy_json = try readRequiredArtifact(init.io, allocator, options.dry_run_policy_path, error.MissingDryRunPolicyInput);
    defer allocator.free(source_dry_run_policy_json);

    const evidence_inputs = try readEvidenceInputs(init.io, allocator, options.evidence_paths);
    defer deinitEvidenceInputs(allocator, evidence_inputs);

    const reports = try formatReports(allocator, .{
        .options = options,
        .source_dry_run_policy_json = source_dry_run_policy_json,
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
    return "usage: zig build causal-production-telemetry-ci-gate-dry-run-evaluator -- --from-dry-run-policy <dry-run-policy.json> evaluate --reason <reason> --evidence <path>... [--by <actor>] [--policy <policy>] [--out-prefix <path-prefix>]\n";
}

fn failUsage(err: anyerror) noreturn {
    std.debug.print("causal-production-telemetry-ci-gate-dry-run-evaluator error: {s}\n{s}", .{ @errorName(err), usage() });
    std.process.exit(2);
}

fn freeSliceOnly(allocator: std.mem.Allocator, values: []const []const u8) void {
    if (values.len > 0) allocator.free(values);
}

test "ci gate dry-run evaluator schema and branch constants are stable" {
    try std.testing.expectEqualStrings("zigeffect.causal.production-telemetry-ci-gate-dry-run-evaluator.v1", production_telemetry_ci_gate_dry_run_evaluator_schema);
    try std.testing.expectEqual(@as(u32, 1), production_telemetry_ci_gate_dry_run_evaluator_schema_version);
    try std.testing.expectEqualStrings("codex/zigeffect-causal-production-telemetry-ci-gate-dry-run-evaluator", source_branch);
    try std.testing.expectEqualStrings("start-production-telemetry-ci-gate-advisory-ci-report", recommendation);
    try std.testing.expectEqualStrings("codex/zigeffect-causal-production-telemetry-ci-gate-advisory-ci-report", next_branch_if_ready);
    try std.testing.expect(containsString(required_verification_commands, "zig build causal-production-telemetry-ci-gate-dry-run-policy"));
}

test "parses evaluator options with multiple evidence paths" {
    var options = try parseOptions(std.testing.allocator, &.{
        "zigeffect-causal-production-telemetry-ci-gate-dry-run-evaluator",
        "--from-dry-run-policy",
        ".zig-cache/causal-artifacts/example-ci-gate-dry-run-policy.json",
        "evaluate",
        "--reason",
        "dry-run evidence reviewed",
        "--by",
        "codex",
        "--policy",
        "manual-production-telemetry-ci-gate-dry-run-evaluator",
        "--evidence",
        ".zig-cache/release-gate/zigeffect-release-gate.json",
        "--evidence",
        ".zig-cache/causal-artifacts/zigeffect-causal-dogfood.json",
        "--out-prefix",
        ".zig-cache/causal-artifacts/custom-evaluator",
    });
    defer options.deinit(std.testing.allocator);

    try std.testing.expectEqualStrings(".zig-cache/causal-artifacts/example-ci-gate-dry-run-policy.json", options.dry_run_policy_path);
    try std.testing.expectEqualStrings("dry-run evidence reviewed", options.reason);
    try std.testing.expectEqualStrings("codex", options.reviewed_by);
    try std.testing.expectEqual(@as(usize, 2), options.evidence_paths.len);
    try std.testing.expectEqualStrings(".zig-cache/release-gate/zigeffect-release-gate.json", options.evidence_paths[0]);
    try std.testing.expectEqualStrings(".zig-cache/causal-artifacts/zigeffect-causal-dogfood.json", options.evidence_paths[1]);
    try std.testing.expectEqualStrings(".zig-cache/causal-artifacts/custom-evaluator", options.out_prefix.?);
}

test "default output path replaces dry-run policy suffix" {
    const options = Options{
        .dry_run_policy_path = "../../.zig-cache/causal-artifacts/example-ci-gate-dry-run-policy.json",
        .reason = "planned",
        .evidence_paths = &.{".zig-cache/causal-artifacts/evidence.json"},
    };
    const paths = try outputPathsForOptions(std.testing.allocator, options);
    defer paths.deinit(std.testing.allocator);

    try std.testing.expectEqualStrings("../../.zig-cache/causal-artifacts/example-ci-gate-dry-run-evaluator.json", paths.json_path);
    try std.testing.expectEqualStrings("../../.zig-cache/causal-artifacts/example-ci-gate-dry-run-evaluator.txt", paths.text_path);
}

test "ready evaluator report observes release gate causal schema and handoff evidence" {
    const reports = try formatReports(std.testing.allocator, .{
        .options = sampleOptions(),
        .source_dry_run_policy_json = sample_dry_run_policy_json,
        .evidence_inputs = &.{
            .{ .path = ".zig-cache/release-gate/zigeffect-release-gate.json", .contents = sample_release_gate_json },
            .{ .path = ".zig-cache/causal-artifacts/zigeffect-causal-dogfood.json", .contents = sample_causal_json },
            .{ .path = ".zig-cache/causal-artifacts/failing-test-ci-handoff.txt", .contents = sample_handoff_text },
        },
    });
    defer reports.deinit(std.testing.allocator);

    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"schema\": \"zigeffect.causal.production-telemetry-ci-gate-dry-run-evaluator.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"evaluation_status\": \"ready\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"ready_for_next_branch\": true") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"blocked_findings_count\": 0") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"advisory_findings_count\": 0") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"ci_required_status_check_enabled\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"nendb_write_enabled\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"status\": \"observed\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"next_branch_if_ready\": \"codex/zigeffect-causal-production-telemetry-ci-gate-advisory-ci-report\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.text, "evaluation_status: ready") != null);
}

test "missing handoff evidence produces advisory findings not a blocked evaluator" {
    const reports = try formatReports(std.testing.allocator, .{
        .options = sampleOptions(),
        .source_dry_run_policy_json = sample_dry_run_policy_json,
        .evidence_inputs = &.{
            .{ .path = ".zig-cache/release-gate/zigeffect-release-gate.json", .contents = sample_release_gate_json },
            .{ .path = ".zig-cache/causal-artifacts/zigeffect-causal-dogfood.json", .contents = sample_causal_json },
        },
    });
    defer reports.deinit(std.testing.allocator);

    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"evaluation_status\": \"advisory-findings\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"ready_for_next_branch\": true") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"blocked_findings_count\": 0") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"id\": \"ci-handoff-present\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"severity\": \"advisory\"") != null);
}

test "invalid source policy blocks evaluator readiness" {
    const reports = try formatReports(std.testing.allocator, .{
        .options = sampleOptions(),
        .source_dry_run_policy_json = sample_blocked_dry_run_policy_json,
        .evidence_inputs = &.{
            .{ .path = ".zig-cache/release-gate/zigeffect-release-gate.json", .contents = sample_release_gate_json },
            .{ .path = ".zig-cache/causal-artifacts/zigeffect-causal-dogfood.json", .contents = sample_causal_json },
            .{ .path = ".zig-cache/causal-artifacts/failing-test-ci-handoff.txt", .contents = sample_handoff_text },
        },
    });
    defer reports.deinit(std.testing.allocator);

    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"evaluation_status\": \"blocked\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"ready_for_next_branch\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"id\": \"source-policy-ready\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"severity\": \"blocked\"") != null);
}

test "denied evidence marker blocks evaluator readiness" {
    const reports = try formatReports(std.testing.allocator, .{
        .options = sampleOptions(),
        .source_dry_run_policy_json = sample_dry_run_policy_json,
        .evidence_inputs = &.{
            .{ .path = ".zig-cache/release-gate/zigeffect-release-gate.json", .contents = sample_release_gate_json },
            .{ .path = ".zig-cache/causal-artifacts/zigeffect-causal-dogfood.json", .contents = sample_causal_json_with_secret },
            .{ .path = ".zig-cache/causal-artifacts/failing-test-ci-handoff.txt", .contents = sample_handoff_text },
        },
    });
    defer reports.deinit(std.testing.allocator);

    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"evaluation_status\": \"blocked\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"id\": \"evidence-denied\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "secret-shaped") != null);
}

test "evidence outside allowed artifact classes blocks evaluator readiness" {
    const reports = try formatReports(std.testing.allocator, .{
        .options = sampleOptions(),
        .source_dry_run_policy_json = sample_dry_run_policy_json,
        .evidence_inputs = &.{
            .{ .path = "tmp/evidence.json", .contents = sample_causal_json },
        },
    });
    defer reports.deinit(std.testing.allocator);

    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"evaluation_status\": \"blocked\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"class\": \"denied\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "evidence path must be") != null);
}

fn containsString(values: []const []const u8, needle: []const u8) bool {
    for (values) |value| {
        if (std.mem.indexOf(u8, value, needle) != null) return true;
    }
    return false;
}

fn sampleOptions() Options {
    return .{
        .dry_run_policy_path = ".zig-cache/causal-artifacts/example-ci-gate-dry-run-policy.json",
        .reason = "dry-run evidence reviewed",
        .evidence_paths = &.{".zig-cache/causal-artifacts/evidence.json"},
    };
}

const sample_release_gate_json =
    \\{
    \\  "schema": "zigeffect.release-gate.v1",
    \\  "schema_version": 1,
    \\  "status": "pass",
    \\  "generated_by": "release-gate"
    \\}
;

const sample_causal_json =
    \\{
    \\  "schema": "zigeffect.causal.v1",
    \\  "schema_version": 1,
    \\  "artifact_id": "causal-dogfood",
    \\  "retention_days": 14,
    \\  "redaction": "applied"
    \\}
;

const sample_causal_json_with_secret =
    \\{
    \\  "schema": "zigeffect.causal.v1",
    \\  "schema_version": 1,
    \\  "artifact_id": "causal-dogfood",
    \\  "redaction": "applied",
    \\  "token": "sk-test"
    \\}
;

const sample_handoff_text =
    \\causal ci handoff
    \\event ids: test.failure
    \\next queries: inspect-failing-effect
;

const sample_dry_run_policy_json =
    \\{
    \\  "schema": "zigeffect.causal.production-telemetry-ci-gate-dry-run-policy.v1",
    \\  "schema_version": 1,
    \\  "source_gate_application_boundary": ".zig-cache/causal-artifacts/ci-gate-application-boundary.json",
    \\  "source_boundary_status": "planned",
    \\  "source_boundary_mode": "plan",
    \\  "source_boundary_applied": false,
    \\  "source_boundary_mutation_authority": "none",
    \\  "decision": "approve",
    \\  "dry_run_policy_status": "ready",
    \\  "ready_for_next_branch": true,
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
    \\  "candidate_signal_policies": [
    \\    { "id": "release-gate-artifact-present", "evaluation_mode": "dry-run", "enforcement_enabled": false, "required_status_check_enabled": false, "failure_effect": "advisory", "evidence": "release gate artifact", "blocked_claim": "required-release-gate-status-check" },
    \\    { "id": "causal-artifact-schema-parse", "evaluation_mode": "dry-run", "enforcement_enabled": false, "required_status_check_enabled": false, "failure_effect": "advisory", "evidence": "causal JSON schema", "blocked_claim": "schema-parse-enforcement" },
    \\    { "id": "archive-policy-conformance", "evaluation_mode": "dry-run", "enforcement_enabled": false, "required_status_check_enabled": false, "failure_effect": "advisory", "evidence": "bounded artifact path", "blocked_claim": "archive-policy-required-check" },
    \\    { "id": "redaction-retention-conformance", "evaluation_mode": "dry-run", "enforcement_enabled": false, "required_status_check_enabled": false, "failure_effect": "advisory", "evidence": "redaction and retention state", "blocked_claim": "retention-or-redaction-enforcement" },
    \\    { "id": "ci-handoff-present", "evaluation_mode": "dry-run", "enforcement_enabled": false, "required_status_check_enabled": false, "failure_effect": "advisory", "evidence": "handoff evidence", "blocked_claim": "handoff-required-check" },
    \\    { "id": "boundary-source-valid", "evaluation_mode": "dry-run", "enforcement_enabled": false, "required_status_check_enabled": false, "failure_effect": "advisory", "evidence": "source policy", "blocked_claim": "boundary-validation-enforcement" }
    \\  ],
    \\  "evidence_requirements": [
    \\    { "id": "causal-json-artifacts", "allowed": true, "detail": "bounded causal JSON artifacts" },
    \\    { "id": "release-gate-json-artifacts", "allowed": true, "detail": "release-gate JSON artifacts" },
    \\    { "id": "secret-values", "allowed": false, "detail": "secret-shaped values are denied" }
    \\  ],
    \\  "checks": [
    \\    { "name": "source-boundary-schema", "status": "pass", "detail": "source schema is supported" },
    \\    { "name": "reviewer-decision-approved", "status": "pass", "detail": "reviewer approved handoff" }
    \\  ],
    \\  "blocked_claims": ["ci-gate-enforcement-active", "required-status-check-active", "nendb-write-enabled"],
    \\  "required_verification_commands": ["zig build causal-production-telemetry-ci-gate-dry-run-policy"],
    \\  "generated_by": "causal-production-telemetry-ci-gate-dry-run-policy"
    \\}
;

const sample_blocked_dry_run_policy_json =
    \\{
    \\  "schema": "zigeffect.causal.production-telemetry-ci-gate-dry-run-policy.v1",
    \\  "schema_version": 1,
    \\  "source_gate_application_boundary": ".zig-cache/causal-artifacts/ci-gate-application-boundary.json",
    \\  "source_boundary_status": "planned",
    \\  "source_boundary_mode": "plan",
    \\  "source_boundary_applied": false,
    \\  "source_boundary_mutation_authority": "none",
    \\  "decision": "reject",
    \\  "dry_run_policy_status": "blocked",
    \\  "ready_for_next_branch": false,
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
    \\  "candidate_signal_policies": [
    \\    { "id": "release-gate-artifact-present", "evaluation_mode": "dry-run", "enforcement_enabled": false, "required_status_check_enabled": false, "failure_effect": "advisory", "evidence": "release gate artifact", "blocked_claim": "required-release-gate-status-check" }
    \\  ],
    \\  "evidence_requirements": [
    \\    { "id": "causal-json-artifacts", "allowed": true, "detail": "bounded causal JSON artifacts" }
    \\  ],
    \\  "checks": [
    \\    { "name": "reviewer-decision-approved", "status": "fail", "detail": "reviewer rejected handoff" }
    \\  ],
    \\  "blocked_claims": ["ci-gate-enforcement-active"],
    \\  "generated_by": "causal-production-telemetry-ci-gate-dry-run-policy"
    \\}
;
