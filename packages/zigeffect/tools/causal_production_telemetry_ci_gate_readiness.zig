const std = @import("std");

pub const production_telemetry_ci_gate_readiness_schema = "zigeffect.causal.production-telemetry-ci-gate-readiness.v1";
pub const production_telemetry_ci_gate_readiness_schema_version: u32 = 1;
pub const source_branch = "codex/zigeffect-causal-production-telemetry-ci-gate-readiness";
pub const recommendation = "start-production-telemetry-ci-gate-application-boundary";
pub const next_branch_if_ready = "codex/zigeffect-causal-production-telemetry-ci-gate-application-boundary";

const archive_evidence_policy_schema = "zigeffect.causal.production-telemetry-ci-archive-evidence-policy.v1";
const generated_by = "causal-production-telemetry-ci-gate-readiness";

const required_verification_commands: []const []const u8 = &.{
    "zig build causal-production-telemetry-ci-archive-evidence-policy",
    "zig build causal-artifacts",
    "zig build release-gate --summary none",
    "zig build release-gate-report",
    "zig build causal-schema-governance -- --format json",
    "zig build causal-production-hardening-backlog -- --format json",
    "zig build examples",
    "zig build test",
};

const applied = false;
const mutation_authority = "none";
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

const Decision = enum { approve, reject };
const GateReadinessStatus = enum { ready, blocked };
const CheckStatus = enum { pass, fail };

const Options = struct {
    archive_evidence_policy_path: []const u8,
    decision: Decision,
    reviewed_by: []const u8 = "ci-gate-readiness-reviewer",
    policy: []const u8 = "manual-production-telemetry-ci-gate-readiness",
    reason: []const u8,
    verified_commands: []const []const u8 = &.{},
    out_prefix: ?[]const u8 = null,

    fn deinit(self: Options, allocator: std.mem.Allocator) void {
        if (self.verified_commands.len > 0) allocator.free(self.verified_commands);
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

const GateReadinessInput = struct {
    options: Options,
    source_policy_json: []const u8,
};

const GateReadinessReports = struct {
    json: []const u8,
    text: []const u8,

    fn deinit(self: GateReadinessReports, allocator: std.mem.Allocator) void {
        allocator.free(self.json);
        allocator.free(self.text);
    }
};

const SourceEvidenceClass = struct {
    id: []const u8,
    extension: []const u8 = "",
    visibility_class: []const u8 = "",
    consumer_role: []const u8 = "",
    interpretation_scope: []const u8 = "",
    denied_claim: []const u8 = "",
};

const SourceMetadataField = struct {
    name: []const u8,
    required: bool = false,
    description: []const u8 = "",
};

const SourceNegativeFixture = struct {
    id: []const u8,
    artifact_state: []const u8 = "",
    decision: []const u8 = "",
    failed_gate: []const u8 = "",
    reason: []const u8 = "",
};

const SourceCheck = struct {
    name: []const u8,
    status: []const u8,
    detail: []const u8 = "",
};

const ArchiveEvidencePolicyArtifact = struct {
    schema: []const u8,
    schema_version: u32,
    source_ci_archive_application: []const u8 = "",
    source_archive_application_status: []const u8 = "",
    source_archive_application_applied: bool = false,
    source_ci_harness_boundary: []const u8 = "",
    source_workflow_digest: []const u8 = "",
    decision: []const u8 = "",
    archive_evidence_policy_status: []const u8,
    ready_for_next_branch: bool,
    reviewed_by: []const u8 = "",
    policy: []const u8 = "",
    reason: []const u8 = "",
    applied: bool,
    mutation_authority: []const u8,
    ci_gate_enabled: bool,
    ci_upload_execution_enabled: bool,
    ci_workflow_mutation_enabled: bool,
    production_telemetry_ingestion: bool,
    live_exporter_enabled: bool,
    network_send_enabled: bool,
    collector_endpoint_configured: bool,
    otlp_serialization_enabled: bool,
    runtime_pipeline_enabled: bool,
    durable_write_enabled: bool,
    nendb_write_enabled: bool,
    evidence_classes: []const SourceEvidenceClass = &.{},
    required_metadata_fields: []const SourceMetadataField = &.{},
    interpretation_rules: []const []const u8 = &.{},
    negative_fixtures: []const SourceNegativeFixture = &.{},
    checks: []const SourceCheck = &.{},
    required_verification_commands: []const []const u8 = &.{},
    verified_commands: []const []const u8 = &.{},
    blocked_claims: []const []const u8 = &.{},
};

const GateReadinessCheck = struct {
    name: []const u8,
    status: CheckStatus,
    detail: []const u8,
};

const GateReadinessResult = struct {
    status: GateReadinessStatus,
    ready_for_next_branch: bool,
    checks: []const GateReadinessCheck,

    fn deinit(self: GateReadinessResult, allocator: std.mem.Allocator) void {
        if (self.checks.len > 0) allocator.free(self.checks);
    }
};

const ReadinessDimension = struct {
    id: []const u8,
    required: bool,
    evidence: []const u8,
};

const CandidateGateSignal = struct {
    id: []const u8,
    enforcement_enabled: bool,
    source: []const u8,
    denied_claim: []const u8,
};

const NegativeFixture = struct {
    id: []const u8,
    artifact_state: []const u8,
    decision: []const u8,
    failed_gate: []const u8,
    reason: []const u8,
};

const readiness_dimensions: []const ReadinessDimension = &.{
    .{ .id = "source-policy-ready", .required = true, .evidence = "ready archive evidence policy artifact" },
    .{ .id = "archive-evidence-bounded", .required = true, .evidence = "allowed evidence classes metadata and interpretation rules" },
    .{ .id = "release-gate-contract-present", .required = true, .evidence = "zig build release-gate --summary none and release-gate-report" },
    .{ .id = "cluster-workflow-aligned", .required = true, .evidence = "existing release gate remains clustering execution body" },
    .{ .id = "gate-semantics-limited", .required = true, .evidence = "future gates are limited to artifact schema policy readiness" },
    .{ .id = "redaction-retention-reviewed", .required = true, .evidence = "redaction_state and retention_days metadata required" },
    .{ .id = "human-review-before-application", .required = true, .evidence = "future gate application boundary requires review" },
};

const candidate_gate_signals: []const CandidateGateSignal = &.{
    .{ .id = "release-gate-artifact-present", .enforcement_enabled = false, .source = ".zig-cache/release-gate/zigeffect-release-gate.json", .denied_claim = "release success" },
    .{ .id = "causal-artifact-schema-parse", .enforcement_enabled = false, .source = "causal JSON artifacts", .denied_claim = "runtime correctness" },
    .{ .id = "archive-policy-conformance", .enforcement_enabled = false, .source = "archive evidence policy", .denied_claim = "CI pass/fail semantics" },
    .{ .id = "redaction-retention-conformance", .enforcement_enabled = false, .source = "required metadata fields", .denied_claim = "public evidence safety" },
    .{ .id = "ci-handoff-present", .enforcement_enabled = false, .source = "CI handoff text", .denied_claim = "root cause certainty" },
};

const gate_semantics: []const []const u8 = &.{
    "Future CI telemetry gates may evaluate artifact presence schema parseability archive policy conformance redaction metadata retention metadata and release-gate report availability.",
    "Future CI telemetry gates must not claim production health production capacity live telemetry coverage customer impact deployment success or production cluster readiness.",
    "This readiness artifact is advisory and does not fail CI or create required status checks.",
    "A later reviewed gate application boundary must carry workflow before/after evidence before any applied gate state is recorded.",
};

const negative_fixtures: []const NegativeFixture = &.{
    .{ .id = "blocked-source-policy-denied", .artifact_state = "archive_evidence_policy_status=blocked", .decision = "deny", .failed_gate = "source-policy-ready", .reason = "blocked evidence policy cannot feed gate readiness" },
    .{ .id = "missing-release-gate-verification-denied", .artifact_state = "release gate command missing", .decision = "deny", .failed_gate = "release-gate-contract-present", .reason = "gate readiness must cite existing clustering release gate" },
    .{ .id = "missing-release-gate-report-denied", .artifact_state = "release-gate-report command missing", .decision = "deny", .failed_gate = "release-gate-contract-present", .reason = "readiness needs release gate report artifact evidence" },
    .{ .id = "ci-gate-enabled-denied", .artifact_state = "ci_gate_enabled=true", .decision = "deny", .failed_gate = "no-ci-gate-enforcement", .reason = "this branch is readiness-only" },
    .{ .id = "required-status-check-denied", .artifact_state = "ci_required_status_check_enabled=true", .decision = "deny", .failed_gate = "no-required-status-check", .reason = "required checks require a later reviewed boundary" },
    .{ .id = "production-health-claim-denied", .artifact_state = "production_health=proven", .decision = "deny", .failed_gate = "ci-not-production", .reason = "CI evidence is not live production telemetry" },
    .{ .id = "retention-over-fourteen-days-denied", .artifact_state = "retention_days > 14", .decision = "deny", .failed_gate = "bounded-retention", .reason = "current archive policy is bounded to 14 days" },
    .{ .id = "public-upload-claim-denied", .artifact_state = "public_upload_allowed=true", .decision = "deny", .failed_gate = "visibility-ci-internal", .reason = "CI archive evidence is internal redacted evidence" },
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
        error.MissingArchiveEvidencePolicyInput => failUsage(err),
        else => return err,
    };
}

fn parseOptions(allocator: std.mem.Allocator, args: []const []const u8) !Options {
    if (args.len < 2) return error.MissingArchiveEvidencePolicyPath;
    if (!std.mem.eql(u8, args[1], "--from-archive-evidence-policy")) return error.UnknownFlag;
    if (args.len < 3) return error.MissingArchiveEvidencePolicyPath;
    const source_path = args[2];
    if (!std.mem.endsWith(u8, source_path, ".json")) return error.InvalidArchiveEvidencePolicyPath;
    if (args.len < 4) return error.MissingDecision;
    const decision = try parseDecision(args[3]);

    var reviewed_by: []const u8 = "ci-gate-readiness-reviewer";
    var policy: []const u8 = "manual-production-telemetry-ci-gate-readiness";
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
        .archive_evidence_policy_path = source_path,
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

fn gateReadinessStatusText(status: GateReadinessStatus) []const u8 {
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
    else blk: {
        if (!std.mem.endsWith(u8, options.archive_evidence_policy_path, ".json")) return error.InvalidArchiveEvidencePolicyPath;
        const base = options.archive_evidence_policy_path[0 .. options.archive_evidence_policy_path.len - ".json".len];
        const source_suffix = "-ci-archive-evidence-policy";
        if (std.mem.endsWith(u8, base, source_suffix)) {
            break :blk try std.fmt.allocPrint(allocator, "{s}-ci-gate-readiness", .{base[0 .. base.len - source_suffix.len]});
        }
        break :blk try std.fmt.allocPrint(allocator, "{s}-ci-gate-readiness", .{base});
    };
    defer allocator.free(prefix);

    return .{
        .json_path = try std.fmt.allocPrint(allocator, "{s}.json", .{prefix}),
        .text_path = try std.fmt.allocPrint(allocator, "{s}.txt", .{prefix}),
    };
}

fn formatReports(allocator: std.mem.Allocator, input: GateReadinessInput) !GateReadinessReports {
    var parsed = try std.json.parseFromSlice(ArchiveEvidencePolicyArtifact, allocator, input.source_policy_json, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();

    const paths = try outputPathsForOptions(allocator, input.options);
    defer paths.deinit(allocator);

    const result = try evaluateReadiness(allocator, input.options, parsed.value);
    defer result.deinit(allocator);

    const json = try formatGateReadinessJson(allocator, input.options, parsed.value, result, paths);
    errdefer allocator.free(json);
    const text = try formatGateReadinessText(allocator, input.options, parsed.value, result, paths);
    errdefer allocator.free(text);

    return .{ .json = json, .text = text };
}

fn evaluateReadiness(allocator: std.mem.Allocator, options: Options, source: ArchiveEvidencePolicyArtifact) !GateReadinessResult {
    var checks = std.ArrayList(GateReadinessCheck).empty;
    errdefer checks.deinit(allocator);

    try appendCheck(allocator, &checks, "source-archive-evidence-policy-schema", if (std.mem.eql(u8, source.schema, archive_evidence_policy_schema) and source.schema_version == 1) .pass else .fail, "source archive evidence policy schema is supported");
    try appendCheck(allocator, &checks, "source-policy-ready", if (sourcePolicyReady(source)) .pass else .fail, "source policy is ready for gate readiness");
    try appendCheck(allocator, &checks, "source-authority-disabled", if (sourceAuthorityDisabled(source)) .pass else .fail, "source policy keeps gate workflow telemetry durable and NenDB authority disabled");
    try appendCheck(allocator, &checks, "source-evidence-classes-present", if (sourceEvidenceClassesPresent(source)) .pass else .fail, "source policy includes causal release-gate handoff and preview evidence classes");
    try appendCheck(allocator, &checks, "source-metadata-fields-present", if (sourceMetadataFieldsPresent(source)) .pass else .fail, "source policy includes provenance redaction retention visibility and interpretation metadata");
    try appendCheck(allocator, &checks, "source-negative-fixtures-present", if (sourceNegativeFixturesPresent(source)) .pass else .fail, "source policy includes unsafe claim denial fixtures");
    try appendCheck(allocator, &checks, "source-blocked-claims-carried", if (source.blocked_claims.len > 0) .pass else .fail, "source blocked claims are carried forward");
    try appendCheck(allocator, &checks, "decision-approved", if (options.decision == .approve) .pass else .fail, "reviewer approved CI gate readiness");
    try appendCheck(allocator, &checks, "readiness-verification-recorded", if (verifiedCommandsContainAll(options.verified_commands, required_verification_commands)) .pass else .fail, "gate readiness recorded every required verification command");
    try appendCheck(allocator, &checks, "release-gate-verification-recorded", if (releaseGateVerificationRecorded(options.verified_commands)) .pass else .fail, "release gate and release gate report commands are verified");
    try appendCheck(allocator, &checks, "readiness-catalogs-valid", if (readinessCatalogsValid()) .pass else .fail, "readiness dimensions candidate signals and negative fixtures are valid");

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
    checks: *std.ArrayList(GateReadinessCheck),
    name: []const u8,
    status: CheckStatus,
    detail: []const u8,
) !void {
    try checks.append(allocator, .{ .name = name, .status = status, .detail = detail });
}

fn sourcePolicyReady(source: ArchiveEvidencePolicyArtifact) bool {
    return std.mem.eql(u8, source.archive_evidence_policy_status, "ready") and source.ready_for_next_branch;
}

fn sourceAuthorityDisabled(source: ArchiveEvidencePolicyArtifact) bool {
    return !source.applied and
        std.mem.eql(u8, source.mutation_authority, "none") and
        !source.ci_gate_enabled and
        !source.ci_upload_execution_enabled and
        !source.ci_workflow_mutation_enabled and
        !source.production_telemetry_ingestion and
        !source.live_exporter_enabled and
        !source.network_send_enabled and
        !source.collector_endpoint_configured and
        !source.otlp_serialization_enabled and
        !source.runtime_pipeline_enabled and
        !source.durable_write_enabled and
        !source.nendb_write_enabled;
}

fn sourceEvidenceClassesPresent(source: ArchiveEvidencePolicyArtifact) bool {
    return hasSourceEvidenceClass(source, "causal-text-report") and
        hasSourceEvidenceClass(source, "causal-json-artifact") and
        hasSourceEvidenceClass(source, "release-gate-text-report") and
        hasSourceEvidenceClass(source, "release-gate-json-report") and
        hasSourceEvidenceClass(source, "ci-handoff-text") and
        hasSourceEvidenceClass(source, "source-preview-json");
}

fn hasSourceEvidenceClass(source: ArchiveEvidencePolicyArtifact, id: []const u8) bool {
    for (source.evidence_classes) |class| {
        if (std.mem.eql(u8, class.id, id)) return true;
    }
    return false;
}

fn sourceMetadataFieldsPresent(source: ArchiveEvidencePolicyArtifact) bool {
    return hasRequiredSourceMetadata(source, "schema") and
        hasRequiredSourceMetadata(source, "source_artifact_path") and
        hasRequiredSourceMetadata(source, "workflow_digest") and
        hasRequiredSourceMetadata(source, "run_context_ref") and
        hasRequiredSourceMetadata(source, "commit_or_branch_ref") and
        hasRequiredSourceMetadata(source, "redaction_state") and
        hasRequiredSourceMetadata(source, "retention_days") and
        hasRequiredSourceMetadata(source, "visibility_class") and
        hasRequiredSourceMetadata(source, "consumer_role") and
        hasRequiredSourceMetadata(source, "interpretation_scope");
}

fn hasRequiredSourceMetadata(source: ArchiveEvidencePolicyArtifact, name: []const u8) bool {
    for (source.required_metadata_fields) |field| {
        if (std.mem.eql(u8, field.name, name) and field.required) return true;
    }
    return false;
}

fn sourceNegativeFixturesPresent(source: ArchiveEvidencePolicyArtifact) bool {
    return hasSourceNegativeFixture(source, "secret-shaped-content-denied") and
        hasSourceNegativeFixture(source, "retention-over-fourteen-days-denied") and
        hasSourceNegativeFixture(source, "public-upload-claim-denied") and
        hasSourceNegativeFixture(source, "telemetry-gate-claim-denied") and
        hasSourceNegativeFixture(source, "production-health-claim-denied") and
        hasSourceNegativeFixture(source, "non-nendb-durable-scope-denied") and
        hasSourceNegativeFixture(source, "alternate-renderer-scope-denied");
}

fn hasSourceNegativeFixture(source: ArchiveEvidencePolicyArtifact, id: []const u8) bool {
    for (source.negative_fixtures) |fixture| {
        if (std.mem.eql(u8, fixture.id, id) and std.mem.eql(u8, fixture.decision, "deny")) return true;
    }
    return false;
}

fn releaseGateVerificationRecorded(verified_commands: []const []const u8) bool {
    return containsExactString(verified_commands, "zig build release-gate --summary none") and
        containsExactString(verified_commands, "zig build release-gate-report");
}

fn readinessCatalogsValid() bool {
    return hasReadinessDimension("source-policy-ready") and
        hasReadinessDimension("release-gate-contract-present") and
        hasCandidateGateSignal("release-gate-artifact-present") and
        hasCandidateGateSignal("archive-policy-conformance") and
        hasNegativeFixture("ci-gate-enabled-denied") and
        hasNegativeFixture("missing-release-gate-verification-denied") and
        candidateSignalsAreAdvisory();
}

fn hasReadinessDimension(id: []const u8) bool {
    for (readiness_dimensions) |dimension| {
        if (std.mem.eql(u8, dimension.id, id) and dimension.required) return true;
    }
    return false;
}

fn hasCandidateGateSignal(id: []const u8) bool {
    for (candidate_gate_signals) |signal| {
        if (std.mem.eql(u8, signal.id, id)) return true;
    }
    return false;
}

fn candidateSignalsAreAdvisory() bool {
    for (candidate_gate_signals) |signal| {
        if (signal.enforcement_enabled) return false;
    }
    return true;
}

fn hasNegativeFixture(id: []const u8) bool {
    for (negative_fixtures) |fixture| {
        if (std.mem.eql(u8, fixture.id, id) and std.mem.eql(u8, fixture.decision, "deny")) return true;
    }
    return false;
}

fn verifiedCommandsContainAll(verified_commands: []const []const u8, required_commands: []const []const u8) bool {
    for (required_commands) |required| {
        if (!containsExactString(verified_commands, required)) return false;
    }
    return true;
}

fn containsExactString(values: []const []const u8, needle: []const u8) bool {
    for (values) |value| {
        if (std.mem.eql(u8, value, needle)) return true;
    }
    return false;
}

fn allChecksPassed(checks: []const GateReadinessCheck) bool {
    for (checks) |check| {
        if (check.status != .pass) return false;
    }
    return true;
}

fn formatGateReadinessJson(
    allocator: std.mem.Allocator,
    options: Options,
    source: ArchiveEvidencePolicyArtifact,
    result: GateReadinessResult,
    paths: OutputPaths,
) ![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "{\n");
    try appendJsonField(allocator, &output, "schema", production_telemetry_ci_gate_readiness_schema, true);
    try output.appendSlice(allocator, "  \"schema_version\": 1,\n");
    try appendJsonField(allocator, &output, "source_archive_evidence_policy", options.archive_evidence_policy_path, true);
    try appendJsonField(allocator, &output, "source_policy_status", source.archive_evidence_policy_status, true);
    try output.print(allocator, "  \"source_ready_for_next_branch\": {},\n", .{source.ready_for_next_branch});
    try appendJsonField(allocator, &output, "source_ci_archive_application", source.source_ci_archive_application, true);
    try appendJsonField(allocator, &output, "source_workflow_digest", source.source_workflow_digest, true);
    try appendJsonField(allocator, &output, "decision", decisionText(options.decision), true);
    try appendJsonField(allocator, &output, "gate_readiness_status", gateReadinessStatusText(result.status), true);
    try output.print(allocator, "  \"ready_for_next_branch\": {},\n", .{result.ready_for_next_branch});
    try appendJsonField(allocator, &output, "reviewed_by", options.reviewed_by, true);
    try appendJsonField(allocator, &output, "policy", options.policy, true);
    try appendJsonField(allocator, &output, "reason", options.reason, true);
    try output.print(allocator, "  \"applied\": {},\n", .{applied});
    try appendJsonField(allocator, &output, "mutation_authority", mutation_authority, true);
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
    try output.appendSlice(allocator, "  \"readiness_dimensions\": ");
    try appendReadinessDimensionsJson(allocator, &output);
    try output.appendSlice(allocator, ",\n  \"candidate_gate_signals\": ");
    try appendCandidateGateSignalsJson(allocator, &output);
    try output.appendSlice(allocator, ",\n  \"gate_semantics\": ");
    try appendStringArray(allocator, &output, gate_semantics);
    try output.appendSlice(allocator, ",\n  \"negative_fixtures\": ");
    try appendNegativeFixturesJson(allocator, &output);
    try output.appendSlice(allocator, ",\n  \"checks\": ");
    try appendChecksJson(allocator, &output, result.checks);
    try output.appendSlice(allocator, ",\n  \"required_verification_commands\": ");
    try appendStringArray(allocator, &output, required_verification_commands);
    try output.appendSlice(allocator, ",\n  \"verified_commands\": ");
    try appendStringArray(allocator, &output, options.verified_commands);
    try output.appendSlice(allocator, ",\n  \"blocked_claims\": ");
    try appendStringArray(allocator, &output, blockedClaims(source));
    try appendJsonFieldPrefixComma(allocator, &output, "generated_by", generated_by);
    try appendJsonFieldPrefixComma(allocator, &output, "source_branch", source_branch);
    try appendJsonFieldPrefixComma(allocator, &output, "recommendation", recommendation);
    try appendJsonFieldPrefixComma(allocator, &output, "next_branch_if_ready", next_branch_if_ready);
    try output.appendSlice(allocator, ",\n  \"output_paths\": { \"json\": ");
    try appendJsonString(allocator, &output, paths.json_path);
    try output.appendSlice(allocator, ", \"text\": ");
    try appendJsonString(allocator, &output, paths.text_path);
    try output.appendSlice(allocator, " },\n  \"agent_guidance\": ");
    try appendStringArray(allocator, &output, agentGuidance(result.status));
    try output.appendSlice(allocator, "\n}\n");

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

fn formatGateReadinessText(
    allocator: std.mem.Allocator,
    options: Options,
    source: ArchiveEvidencePolicyArtifact,
    result: GateReadinessResult,
    paths: OutputPaths,
) ![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "zigeffect production telemetry CI gate readiness\n");
    try output.print(allocator, "schema: {s}\n", .{production_telemetry_ci_gate_readiness_schema});
    try output.print(allocator, "source archive evidence policy: {s}\n", .{options.archive_evidence_policy_path});
    try output.print(allocator, "source policy status: {s}\n", .{source.archive_evidence_policy_status});
    try output.print(allocator, "decision: {s}\n", .{decisionText(options.decision)});
    try output.print(allocator, "gate_readiness_status: {s}\n", .{gateReadinessStatusText(result.status)});
    try output.print(allocator, "ready_for_next_branch: {}\n", .{result.ready_for_next_branch});
    try output.print(allocator, "reviewed_by: {s}\n", .{options.reviewed_by});
    try output.print(allocator, "policy: {s}\n", .{options.policy});
    try output.print(allocator, "reason: {s}\n", .{options.reason});
    try output.print(allocator, "applied: {}\n", .{applied});
    try output.print(allocator, "mutation_authority: {s}\n", .{mutation_authority});
    try output.print(allocator, "ci gate enabled: {}\n", .{ci_gate_enabled});
    try output.print(allocator, "ci gate enforcement enabled: {}\n", .{ci_gate_enforcement_enabled});
    try output.print(allocator, "ci required status check enabled: {}\n", .{ci_required_status_check_enabled});
    try output.print(allocator, "recommendation: {s}\n", .{recommendation});
    try output.print(allocator, "next branch if ready: {s}\n", .{next_branch_if_ready});
    try output.print(allocator, "json output: {s}\n", .{paths.json_path});
    try output.print(allocator, "text output: {s}\n\n", .{paths.text_path});

    try output.appendSlice(allocator, "checks:\n");
    for (result.checks) |check| {
        try output.print(allocator, "- {s}: {s} - {s}\n", .{ check.name, checkStatusText(check.status), check.detail });
    }
    try output.append(allocator, '\n');

    try appendTextList(allocator, &output, "readiness dimensions", readinessDimensionIds());
    try appendTextList(allocator, &output, "candidate gate signals", candidateGateSignalIds());
    try appendTextList(allocator, &output, "gate semantics", gate_semantics);
    try appendTextList(allocator, &output, "negative fixtures", negativeFixtureIds());
    try appendTextList(allocator, &output, "blocked claims", blockedClaims(source));
    try appendTextList(allocator, &output, "required verification commands", required_verification_commands);
    try appendTextList(allocator, &output, "verified commands", options.verified_commands);
    try appendTextList(allocator, &output, "agent guidance", agentGuidance(result.status));

    return output.toOwnedSlice(allocator);
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

fn appendCandidateGateSignalsJson(allocator: std.mem.Allocator, output: *std.ArrayList(u8)) !void {
    try output.append(allocator, '[');
    for (candidate_gate_signals, 0..) |signal, index| {
        if (index > 0) try output.appendSlice(allocator, ", ");
        try output.appendSlice(allocator, "{ \"id\": ");
        try appendJsonString(allocator, output, signal.id);
        try output.print(allocator, ", \"enforcement_enabled\": {}, \"source\": ", .{signal.enforcement_enabled});
        try appendJsonString(allocator, output, signal.source);
        try output.appendSlice(allocator, ", \"denied_claim\": ");
        try appendJsonString(allocator, output, signal.denied_claim);
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

fn appendChecksJson(allocator: std.mem.Allocator, output: *std.ArrayList(u8), checks: []const GateReadinessCheck) !void {
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

fn readinessDimensionIds() []const []const u8 {
    return &.{
        "source-policy-ready",
        "archive-evidence-bounded",
        "release-gate-contract-present",
        "cluster-workflow-aligned",
        "gate-semantics-limited",
        "redaction-retention-reviewed",
        "human-review-before-application",
    };
}

fn candidateGateSignalIds() []const []const u8 {
    return &.{
        "release-gate-artifact-present",
        "causal-artifact-schema-parse",
        "archive-policy-conformance",
        "redaction-retention-conformance",
        "ci-handoff-present",
    };
}

fn negativeFixtureIds() []const []const u8 {
    return &.{
        "blocked-source-policy-denied",
        "missing-release-gate-verification-denied",
        "missing-release-gate-report-denied",
        "ci-gate-enabled-denied",
        "required-status-check-denied",
        "production-health-claim-denied",
        "retention-over-fourteen-days-denied",
        "public-upload-claim-denied",
        "non-nendb-durable-scope-denied",
        "alternate-renderer-scope-denied",
    };
}

fn blockedClaims(source: ArchiveEvidencePolicyArtifact) []const []const u8 {
    if (source.blocked_claims.len > 0) return source.blocked_claims;
    return blocked_claims;
}

fn agentGuidance(status: GateReadinessStatus) []const []const u8 {
    return switch (status) {
        .ready => &.{
            "Use ready CI gate readiness artifacts to start the gate application boundary only.",
            "Gate candidates are advisory and enforcement remains disabled.",
            "Do not infer CI required checks workflow mutation live telemetry durable writes NenDB writes or production readiness.",
        },
        .blocked => &.{
            "Blocked CI gate readiness artifacts must not feed gate application work.",
            "Repair source evidence policy reviewer decision verification commands or readiness catalogs first.",
            "Do not treat readiness as CI gate enforcement.",
        },
    };
}

const blocked_claims: []const []const u8 = &.{
    "ci-gate-readiness-not-ready",
    "ci-gate-enforcement-not-enabled",
    "ci-required-status-check-not-enabled",
    "workflow-not-mutated-by-tool",
    "artifact-upload-not-executed-by-tool",
    "production-health-not-proven",
    "capacity-not-proven",
    "live-telemetry-coverage-not-proven",
    "production-cluster-not-claimed-ready",
    "durable-production-write-not-enabled",
    "nendb-write-not-enabled",
    "non-nendb-durable-storage",
    "react-or-alternate-renderer",
    "mutation-authority-granted",
};

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
    const source_policy_json = try readRequiredArtifact(init.io, allocator, options.archive_evidence_policy_path, error.MissingArchiveEvidencePolicyInput);
    defer allocator.free(source_policy_json);

    const reports = try formatReports(allocator, .{
        .options = options,
        .source_policy_json = source_policy_json,
    });
    defer reports.deinit(allocator);

    const paths = try outputPathsForOptions(allocator, options);
    defer paths.deinit(allocator);

    try writeArtifact(init.io, paths.json_path, reports.json);
    try writeArtifact(init.io, paths.text_path, reports.text);
    std.debug.print("{s}", .{reports.text});
}

fn usage() []const u8 {
    return "usage: zig build causal-production-telemetry-ci-gate-readiness -- --from-archive-evidence-policy <archive-evidence-policy.json> approve|reject --reason <reason> [--by <actor>] [--policy <policy>] [--verified-command <command>]... [--out-prefix <path-prefix>]\n";
}

fn failUsage(err: anyerror) noreturn {
    std.debug.print("causal-production-telemetry-ci-gate-readiness error: {s}\n{s}", .{ @errorName(err), usage() });
    std.process.exit(2);
}

test "ci gate readiness schema and branch constants are stable" {
    try std.testing.expectEqualStrings("zigeffect.causal.production-telemetry-ci-gate-readiness.v1", production_telemetry_ci_gate_readiness_schema);
    try std.testing.expectEqual(@as(u32, 1), production_telemetry_ci_gate_readiness_schema_version);
    try std.testing.expectEqualStrings("codex/zigeffect-causal-production-telemetry-ci-gate-readiness", source_branch);
    try std.testing.expectEqualStrings("start-production-telemetry-ci-gate-application-boundary", recommendation);
    try std.testing.expectEqualStrings("codex/zigeffect-causal-production-telemetry-ci-gate-application-boundary", next_branch_if_ready);
    try std.testing.expect(containsExactString(required_verification_commands, "zig build causal-production-telemetry-ci-archive-evidence-policy"));
    try std.testing.expect(containsExactString(required_verification_commands, "zig build release-gate --summary none"));
    try std.testing.expect(containsExactString(required_verification_commands, "zig build release-gate-report"));
}

test "parses ci gate readiness options" {
    var options = try parseOptions(std.testing.allocator, &.{
        "zigeffect-causal-production-telemetry-ci-gate-readiness",
        "--from-archive-evidence-policy",
        ".zig-cache/causal-artifacts/ci-archive-evidence-policy.json",
        "approve",
        "--reason",
        "CI gate readiness reviewed",
        "--by",
        "codex",
        "--policy",
        "manual-production-telemetry-ci-gate-readiness",
        "--verified-command",
        "zig build causal-production-telemetry-ci-archive-evidence-policy",
        "--out-prefix",
        ".zig-cache/causal-artifacts/custom-ci-gate-readiness",
    });
    defer options.deinit(std.testing.allocator);

    try std.testing.expectEqual(Decision.approve, options.decision);
    try std.testing.expectEqualStrings(".zig-cache/causal-artifacts/ci-archive-evidence-policy.json", options.archive_evidence_policy_path);
    try std.testing.expectEqualStrings("CI gate readiness reviewed", options.reason);
    try std.testing.expectEqualStrings("codex", options.reviewed_by);
    try std.testing.expectEqualStrings("manual-production-telemetry-ci-gate-readiness", options.policy);
    try std.testing.expectEqual(@as(usize, 1), options.verified_commands.len);
    try std.testing.expectEqualStrings("zig build causal-production-telemetry-ci-archive-evidence-policy", options.verified_commands[0]);
    try std.testing.expectEqualStrings(".zig-cache/causal-artifacts/custom-ci-gate-readiness", options.out_prefix.?);
}

test "default output path replaces archive evidence policy suffix" {
    const paths = try outputPathsForOptions(std.testing.allocator, .{
        .archive_evidence_policy_path = "../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures-nendb-retention-fixtures-workbench-readonly-preview-ci-artifact-preview-ci-harness-boundary-ci-archive-evidence-policy.json",
        .decision = .approve,
        .reason = "CI gate readiness reviewed",
    });
    defer paths.deinit(std.testing.allocator);

    try std.testing.expect(std.mem.endsWith(u8, paths.json_path, "-ci-gate-readiness.json"));
    try std.testing.expect(std.mem.indexOf(u8, std.fs.path.basename(paths.json_path), "-ci-archive-evidence-policy-ci-gate-readiness") == null);
    try std.testing.expect(std.fs.path.basename(paths.json_path).len <= 255);
    try std.testing.expect(std.fs.path.basename(paths.text_path).len <= 255);
}

test "ready and rejected gate readiness reports preserve disabled enforcement" {
    const ready = try formatReports(std.testing.allocator, .{
        .options = .{
            .archive_evidence_policy_path = ".zig-cache/causal-artifacts/ci-archive-evidence-policy.json",
            .decision = .approve,
            .reason = "CI gate readiness reviewed",
            .verified_commands = required_verification_commands,
        },
        .source_policy_json = sample_archive_evidence_policy_json,
    });
    defer ready.deinit(std.testing.allocator);

    try std.testing.expect(std.mem.indexOf(u8, ready.json, "\"schema\": \"zigeffect.causal.production-telemetry-ci-gate-readiness.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, ready.json, "\"gate_readiness_status\": \"ready\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, ready.json, "\"ready_for_next_branch\": true") != null);
    try std.testing.expect(std.mem.indexOf(u8, ready.json, "\"ci_gate_enabled\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, ready.json, "\"ci_gate_enforcement_enabled\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, ready.json, "\"ci_required_status_check_enabled\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, ready.json, "\"id\": \"release-gate-artifact-present\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, ready.json, "\"id\": \"ci-gate-enabled-denied\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, ready.json, "\"next_branch_if_ready\": \"codex/zigeffect-causal-production-telemetry-ci-gate-application-boundary\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, ready.text, "gate_readiness_status: ready") != null);

    const rejected = try formatReports(std.testing.allocator, .{
        .options = .{
            .archive_evidence_policy_path = ".zig-cache/causal-artifacts/ci-archive-evidence-policy.json",
            .decision = .reject,
            .reason = "negative CI gate readiness path",
        },
        .source_policy_json = sample_archive_evidence_policy_json,
    });
    defer rejected.deinit(std.testing.allocator);

    try std.testing.expect(std.mem.indexOf(u8, rejected.json, "\"gate_readiness_status\": \"blocked\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, rejected.json, "\"ready_for_next_branch\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, rejected.text, "gate_readiness_status: blocked") != null);
}

test "blocked source and incomplete verification block gate readiness" {
    const blocked_source = try formatReports(std.testing.allocator, .{
        .options = .{
            .archive_evidence_policy_path = ".zig-cache/causal-artifacts/ci-archive-evidence-policy.json",
            .decision = .approve,
            .reason = "CI gate readiness reviewed",
            .verified_commands = required_verification_commands,
        },
        .source_policy_json = sample_blocked_archive_evidence_policy_json,
    });
    defer blocked_source.deinit(std.testing.allocator);

    const missing_verification = try formatReports(std.testing.allocator, .{
        .options = .{
            .archive_evidence_policy_path = ".zig-cache/causal-artifacts/ci-archive-evidence-policy.json",
            .decision = .approve,
            .reason = "CI gate readiness reviewed",
            .verified_commands = &.{
                "zig build causal-production-telemetry-ci-archive-evidence-policy",
                "zig build release-gate --summary none",
            },
        },
        .source_policy_json = sample_archive_evidence_policy_json,
    });
    defer missing_verification.deinit(std.testing.allocator);

    try std.testing.expect(std.mem.indexOf(u8, blocked_source.json, "\"gate_readiness_status\": \"blocked\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, blocked_source.json, "\"name\": \"source-policy-ready\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, missing_verification.json, "\"gate_readiness_status\": \"blocked\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, missing_verification.json, "\"name\": \"readiness-verification-recorded\"") != null);
}

const sample_archive_evidence_policy_json =
    \\{
    \\  "schema": "zigeffect.causal.production-telemetry-ci-archive-evidence-policy.v1",
    \\  "schema_version": 1,
    \\  "source_ci_archive_application": ".zig-cache/causal-artifacts/ci-archive-application.json",
    \\  "source_archive_application_status": "planned",
    \\  "source_archive_application_applied": false,
    \\  "source_ci_harness_boundary": ".zig-cache/causal-artifacts/ci-harness-boundary.json",
    \\  "source_workflow_digest": "sha256:source-workflow-digest",
    \\  "decision": "approve",
    \\  "archive_evidence_policy_status": "ready",
    \\  "ready_for_next_branch": true,
    \\  "reviewed_by": "ci-archive-evidence-policy-reviewer",
    \\  "policy": "manual-production-telemetry-ci-archive-evidence-policy",
    \\  "reason": "CI archive evidence policy reviewed",
    \\  "applied": false,
    \\  "mutation_authority": "none",
    \\  "ci_gate_enabled": false,
    \\  "ci_upload_execution_enabled": false,
    \\  "ci_workflow_mutation_enabled": false,
    \\  "production_telemetry_ingestion": false,
    \\  "live_exporter_enabled": false,
    \\  "network_send_enabled": false,
    \\  "collector_endpoint_configured": false,
    \\  "otlp_serialization_enabled": false,
    \\  "runtime_pipeline_enabled": false,
    \\  "durable_write_enabled": false,
    \\  "nendb_write_enabled": false,
    \\  "evidence_classes": [
    \\    { "id": "causal-text-report", "extension": ".txt" },
    \\    { "id": "causal-json-artifact", "extension": ".json" },
    \\    { "id": "causal-dot-graph", "extension": ".dot" },
    \\    { "id": "release-gate-text-report", "extension": ".txt" },
    \\    { "id": "release-gate-json-report", "extension": ".json" },
    \\    { "id": "ci-handoff-text", "extension": ".txt" },
    \\    { "id": "source-preview-json", "extension": ".json" }
    \\  ],
    \\  "required_metadata_fields": [
    \\    { "name": "schema", "required": true },
    \\    { "name": "source_artifact_path", "required": true },
    \\    { "name": "workflow_digest", "required": true },
    \\    { "name": "run_context_ref", "required": true },
    \\    { "name": "commit_or_branch_ref", "required": true },
    \\    { "name": "redaction_state", "required": true },
    \\    { "name": "retention_days", "required": true },
    \\    { "name": "visibility_class", "required": true },
    \\    { "name": "consumer_role", "required": true },
    \\    { "name": "interpretation_scope", "required": true }
    \\  ],
    \\  "interpretation_rules": [
    \\    "Archived CI evidence may support local diagnosis failure triage causal query hints before/after comparison and release-gate debugging."
    \\  ],
    \\  "negative_fixtures": [
    \\    { "id": "secret-shaped-content-denied", "decision": "deny" },
    \\    { "id": "retention-over-fourteen-days-denied", "decision": "deny" },
    \\    { "id": "public-upload-claim-denied", "decision": "deny" },
    \\    { "id": "telemetry-gate-claim-denied", "decision": "deny" },
    \\    { "id": "production-health-claim-denied", "decision": "deny" },
    \\    { "id": "non-nendb-durable-scope-denied", "decision": "deny" },
    \\    { "id": "alternate-renderer-scope-denied", "decision": "deny" }
    \\  ],
    \\  "checks": [
    \\    { "name": "source-archive-application-schema", "status": "pass", "detail": "source CI archive application schema is supported" }
    \\  ],
    \\  "required_verification_commands": [
    \\    "zig build causal-production-telemetry-ci-archive-application",
    \\    "zig build release-gate --summary none"
    \\  ],
    \\  "verified_commands": [
    \\    "zig build causal-production-telemetry-ci-archive-application",
    \\    "zig build release-gate --summary none"
    \\  ],
    \\  "blocked_claims": [
    \\    "ci-gate-not-enabled",
    \\    "production-health-not-proven",
    \\    "nendb-write-not-enabled"
    \\  ],
    \\  "generated_by": "causal-production-telemetry-ci-archive-evidence-policy",
    \\  "source_branch": "codex/zigeffect-causal-production-telemetry-ci-archive-evidence-policy",
    \\  "recommendation": "start-production-telemetry-ci-gate-readiness",
    \\  "next_branch_if_ready": "codex/zigeffect-causal-production-telemetry-ci-gate-readiness"
    \\}
;

const sample_blocked_archive_evidence_policy_json =
    \\{
    \\  "schema": "zigeffect.causal.production-telemetry-ci-archive-evidence-policy.v1",
    \\  "schema_version": 1,
    \\  "archive_evidence_policy_status": "blocked",
    \\  "ready_for_next_branch": false,
    \\  "applied": false,
    \\  "mutation_authority": "none",
    \\  "ci_gate_enabled": false,
    \\  "ci_upload_execution_enabled": false,
    \\  "ci_workflow_mutation_enabled": false,
    \\  "production_telemetry_ingestion": false,
    \\  "live_exporter_enabled": false,
    \\  "network_send_enabled": false,
    \\  "collector_endpoint_configured": false,
    \\  "otlp_serialization_enabled": false,
    \\  "runtime_pipeline_enabled": false,
    \\  "durable_write_enabled": false,
    \\  "nendb_write_enabled": false,
    \\  "evidence_classes": [],
    \\  "required_metadata_fields": [],
    \\  "negative_fixtures": [],
    \\  "blocked_claims": [
    \\    "ci-archive-evidence-policy-not-ready"
    \\  ]
    \\}
;
