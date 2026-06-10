const std = @import("std");

pub const production_telemetry_ci_archive_evidence_policy_schema = "zigeffect.causal.production-telemetry-ci-archive-evidence-policy.v1";
pub const production_telemetry_ci_archive_evidence_policy_schema_version: u32 = 1;
pub const source_branch = "codex/zigeffect-causal-production-telemetry-ci-archive-evidence-policy";
pub const recommendation = "start-production-telemetry-ci-gate-readiness";
pub const next_branch_if_ready = "codex/zigeffect-causal-production-telemetry-ci-gate-readiness";

const required_verification_commands: []const []const u8 = &.{
    "zig build causal-production-telemetry-ci-archive-application",
    "zig build causal-artifacts",
    "zig build release-gate --summary none",
    "zig build causal-schema-governance -- --format json",
    "zig build causal-production-hardening-backlog -- --format json",
    "zig build examples",
    "zig build test",
};

const archive_application_schema = "zigeffect.causal.production-telemetry-ci-archive-application.v1";
const generated_by = "causal-production-telemetry-ci-archive-evidence-policy";
const applied = false;
const mutation_authority = "none";
const ci_gate_enabled = false;
const ci_upload_execution_enabled = false;
const ci_workflow_mutation_enabled = false;
const production_telemetry_ingestion = false;
const live_exporter_enabled = false;
const network_send_enabled = false;
const collector_endpoint_configured = false;
const otlp_serialization_enabled = false;
const runtime_pipeline_enabled = false;
const durable_write_enabled = false;
const nendb_write_enabled = false;

const Decision = enum { approve, reject };
const PolicyStatus = enum { ready, blocked };
const CheckStatus = enum { pass, fail };

const Options = struct {
    archive_application_path: []const u8,
    decision: Decision,
    reviewed_by: []const u8 = "ci-archive-evidence-policy-reviewer",
    policy: []const u8 = "manual-production-telemetry-ci-archive-evidence-policy",
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

const PolicyInput = struct {
    options: Options,
    source_archive_application_json: []const u8,
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
    name: []const u8,
    status: []const u8,
    detail: []const u8 = "",
};

const ArchiveApplicationArtifact = struct {
    schema: []const u8,
    schema_version: u32,
    source_ci_harness_boundary: []const u8 = "",
    source_ci_artifact_preview: []const u8 = "",
    source_workbench_preview: []const u8 = "",
    workflow_path: []const u8 = "",
    source_workflow_digest: []const u8 = "",
    after_workflow_path: ?[]const u8 = null,
    after_workflow_digest: []const u8 = "",
    mode: []const u8 = "",
    application_status: []const u8,
    applied: bool,
    mutation_authority: []const u8,
    ci_archive_application_enabled: bool = false,
    ci_upload_enabled: bool = false,
    ci_upload_execution_enabled: bool,
    ci_workflow_mutation_enabled: bool,
    ci_gate_enabled: bool,
    production_telemetry_ingestion: bool,
    live_exporter_enabled: bool,
    network_send_enabled: bool,
    collector_endpoint_configured: bool,
    otlp_serialization_enabled: bool,
    runtime_pipeline_enabled: bool,
    durable_write_enabled: bool,
    nendb_write_enabled: bool,
    workflow_changes: []const []const u8 = &.{},
    before_evidence: []const []const u8 = &.{},
    after_evidence: []const []const u8 = &.{},
    source_checks: []const SourceCheck = &.{},
    checks: []const SourceCheck = &.{},
    required_verification_commands: []const []const u8 = &.{},
    verified_commands: []const []const u8 = &.{},
    cluster_release_gate_assumptions: []const []const u8 = &.{},
    blocked_claims: []const []const u8 = &.{},
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

const EvidenceClass = struct {
    id: []const u8,
    extension: []const u8,
    visibility_class: []const u8,
    consumer_role: []const u8,
    interpretation_scope: []const u8,
    denied_claim: []const u8,
};

const MetadataField = struct {
    name: []const u8,
    required: bool,
    description: []const u8,
};

const NegativeFixture = struct {
    id: []const u8,
    artifact_state: []const u8,
    decision: []const u8,
    failed_gate: []const u8,
    reason: []const u8,
};

const evidence_classes: []const EvidenceClass = &.{
    .{ .id = "causal-text-report", .extension = ".txt", .visibility_class = "ci-internal-redacted", .consumer_role = "maintainer-or-agent-readonly", .interpretation_scope = "human-readable failure triage and next-query hints", .denied_claim = "production health" },
    .{ .id = "causal-json-artifact", .extension = ".json", .visibility_class = "ci-internal-redacted", .consumer_role = "agent-readonly", .interpretation_scope = "bounded causal query input and before-after comparison", .denied_claim = "CI gate pass/fail semantics" },
    .{ .id = "causal-dot-graph", .extension = ".dot", .visibility_class = "ci-internal-redacted", .consumer_role = "maintainer-or-workbench", .interpretation_scope = "graph visualization and topology debugging", .denied_claim = "complete runtime topology" },
    .{ .id = "release-gate-text-report", .extension = ".txt", .visibility_class = "ci-internal-redacted", .consumer_role = "maintainer", .interpretation_scope = "release-gate debugging", .denied_claim = "production readiness" },
    .{ .id = "release-gate-json-report", .extension = ".json", .visibility_class = "ci-internal-redacted", .consumer_role = "agent-readonly", .interpretation_scope = "release-gate result parsing and trend review", .denied_claim = "capacity proof" },
    .{ .id = "ci-handoff-text", .extension = ".txt", .visibility_class = "ci-internal-redacted", .consumer_role = "maintainer-or-agent-readonly", .interpretation_scope = "failure handoff summary", .denied_claim = "root cause certainty" },
    .{ .id = "source-preview-json", .extension = ".json", .visibility_class = "ci-internal-redacted", .consumer_role = "agent-readonly", .interpretation_scope = "source policy provenance", .denied_claim = "live telemetry coverage" },
};

const metadata_fields: []const MetadataField = &.{
    .{ .name = "schema", .required = true, .description = "Artifact schema family and version." },
    .{ .name = "source_artifact_path", .required = true, .description = "Path archived by CI or produced locally for review." },
    .{ .name = "workflow_digest", .required = true, .description = "Digest of the workflow evidence that shaped archive policy." },
    .{ .name = "run_context_ref", .required = true, .description = "CI run, job, or local run context reference." },
    .{ .name = "commit_or_branch_ref", .required = true, .description = "Commit SHA or branch name associated with the evidence." },
    .{ .name = "redaction_state", .required = true, .description = "Reviewed redaction state before sharing." },
    .{ .name = "retention_days", .required = true, .description = "Bounded retention value, currently at most 14 days." },
    .{ .name = "visibility_class", .required = true, .description = "Access-control visibility class." },
    .{ .name = "consumer_role", .required = true, .description = "Human or agent role allowed to consume the evidence." },
    .{ .name = "interpretation_scope", .required = true, .description = "Allowed use and denied inference boundary." },
};

const interpretation_rules: []const []const u8 = &.{
    "Archived CI evidence may support local diagnosis failure triage causal query hints before/after comparison and release-gate debugging.",
    "Archived CI evidence may not prove production health capacity no-defect claims live telemetry coverage customer impact deployment success or CI gate pass/fail semantics.",
    "Agent consumers must prefer JSON evidence with schema metadata and cite source artifact paths and event ids when available.",
    "Human consumers may use text and DOT evidence for review but must not treat visual completeness as runtime completeness.",
    "Any evidence with visible secret-shaped content fails closed until redaction evidence is regenerated.",
};

const negative_fixtures: []const NegativeFixture = &.{
    .{ .id = "secret-shaped-content-denied", .artifact_state = "visible secret-shaped content", .decision = "deny", .failed_gate = "redaction-reviewed", .reason = "archive evidence must be redacted before agent or human sharing" },
    .{ .id = "missing-source-path-denied", .artifact_state = "source_artifact_path missing", .decision = "deny", .failed_gate = "source-artifact-path", .reason = "agents need stable provenance" },
    .{ .id = "retention-over-fourteen-days-denied", .artifact_state = "retention_days > 14", .decision = "deny", .failed_gate = "bounded-retention", .reason = "current CI archive policy is bounded to 14 days" },
    .{ .id = "public-upload-claim-denied", .artifact_state = "public_upload_allowed=true", .decision = "deny", .failed_gate = "visibility-ci-internal", .reason = "CI archive evidence is not public evidence" },
    .{ .id = "telemetry-gate-claim-denied", .artifact_state = "ci_gate_claim=true", .decision = "deny", .failed_gate = "no-ci-gate", .reason = "gate semantics require a later readiness branch" },
    .{ .id = "production-health-claim-denied", .artifact_state = "production_health=proven", .decision = "deny", .failed_gate = "ci-not-production", .reason = "CI archive evidence is not live production telemetry" },
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
        error.MissingArchiveApplicationInput => failUsage(err),
        else => return err,
    };
}

fn parseOptions(allocator: std.mem.Allocator, args: []const []const u8) !Options {
    if (args.len < 2) return error.MissingArchiveApplicationPath;
    if (!std.mem.eql(u8, args[1], "--from-archive-application")) return error.UnknownFlag;
    if (args.len < 3) return error.MissingArchiveApplicationPath;
    const archive_application_path = args[2];
    if (!std.mem.endsWith(u8, archive_application_path, ".json")) return error.InvalidArchiveApplicationPath;
    if (args.len < 4) return error.MissingDecision;
    const decision = try parseDecision(args[3]);

    var reviewed_by: []const u8 = "ci-archive-evidence-policy-reviewer";
    var policy: []const u8 = "manual-production-telemetry-ci-archive-evidence-policy";
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
        .archive_application_path = archive_application_path,
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

fn outputPathsForOptions(allocator: std.mem.Allocator, options: Options) !OutputPaths {
    const prefix = if (options.out_prefix) |out_prefix|
        try allocator.dupe(u8, out_prefix)
    else blk: {
        if (!std.mem.endsWith(u8, options.archive_application_path, ".json")) return error.InvalidArchiveApplicationPath;
        const base = options.archive_application_path[0 .. options.archive_application_path.len - ".json".len];
        const source_suffix = "-ci-archive-application";
        if (std.mem.endsWith(u8, base, source_suffix)) {
            break :blk try std.fmt.allocPrint(
                allocator,
                "{s}-ci-archive-evidence-policy",
                .{base[0 .. base.len - source_suffix.len]},
            );
        }
        break :blk try std.fmt.allocPrint(allocator, "{s}-ci-archive-evidence-policy", .{base});
    };
    defer allocator.free(prefix);

    return .{
        .json_path = try std.fmt.allocPrint(allocator, "{s}.json", .{prefix}),
        .text_path = try std.fmt.allocPrint(allocator, "{s}.txt", .{prefix}),
    };
}

fn formatReports(allocator: std.mem.Allocator, input: PolicyInput) !PolicyReports {
    var parsed = try std.json.parseFromSlice(ArchiveApplicationArtifact, allocator, input.source_archive_application_json, .{ .ignore_unknown_fields = true });
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

fn evaluatePolicy(allocator: std.mem.Allocator, options: Options, source: ArchiveApplicationArtifact) !PolicyResult {
    var checks = std.ArrayList(PolicyCheck).empty;
    errdefer checks.deinit(allocator);

    try appendCheck(allocator, &checks, "source-archive-application-schema", if (std.mem.eql(u8, source.schema, archive_application_schema) and source.schema_version == 1) .pass else .fail, "source CI archive application schema is supported");
    try appendCheck(allocator, &checks, "source-archive-application-status", if (sourceStatusAllowed(source.application_status)) .pass else .fail, "source archive application is planned or applied");
    try appendCheck(allocator, &checks, "source-checks-non-failing", if (sourceChecksNonFailing(source.checks)) .pass else .fail, "source archive application checks contain no failing checks");
    try appendCheck(allocator, &checks, "source-authority-disabled", if (sourceAuthorityDisabled(source)) .pass else .fail, "source archive application keeps execution gates telemetry durable and NenDB authority disabled");
    try appendCheck(allocator, &checks, "source-blocked-claims-carried", if (source.blocked_claims.len > 0) .pass else .fail, "source blocked claims are carried forward");
    try appendCheck(allocator, &checks, "decision-approved", if (options.decision == .approve) .pass else .fail, "reviewer approved the evidence policy");
    try appendCheck(allocator, &checks, "policy-verification-recorded", if (verifiedCommandsContainAll(options.verified_commands, required_verification_commands)) .pass else .fail, "evidence policy recorded every required verification command");
    try appendCheck(allocator, &checks, "evidence-classes-valid", if (evidenceClassesValid()) .pass else .fail, "evidence class catalog has required classes and bounded extensions");
    try appendCheck(allocator, &checks, "metadata-fields-valid", if (metadataFieldsValid()) .pass else .fail, "metadata field catalog includes required provenance and interpretation fields");
    try appendCheck(allocator, &checks, "negative-fixtures-present", if (negativeFixturesValid()) .pass else .fail, "negative fixtures block unsafe archive evidence claims");

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
    checks: *std.ArrayList(PolicyCheck),
    name: []const u8,
    status: CheckStatus,
    detail: []const u8,
) !void {
    try checks.append(allocator, .{ .name = name, .status = status, .detail = detail });
}

fn sourceStatusAllowed(status: []const u8) bool {
    return std.mem.eql(u8, status, "planned") or std.mem.eql(u8, status, "applied");
}

fn sourceChecksNonFailing(checks: []const SourceCheck) bool {
    if (checks.len == 0) return false;
    for (checks) |check| {
        if (std.mem.eql(u8, check.status, "fail")) return false;
    }
    return true;
}

fn sourceAuthorityDisabled(source: ArchiveApplicationArtifact) bool {
    const mutation_ok = (!source.applied and std.mem.eql(u8, source.mutation_authority, "none")) or
        (source.applied and std.mem.eql(u8, source.mutation_authority, "record-only"));
    return mutation_ok and
        source.ci_archive_application_enabled and
        !source.ci_upload_execution_enabled and
        !source.ci_workflow_mutation_enabled and
        !source.ci_gate_enabled and
        !source.production_telemetry_ingestion and
        !source.live_exporter_enabled and
        !source.network_send_enabled and
        !source.collector_endpoint_configured and
        !source.otlp_serialization_enabled and
        !source.runtime_pipeline_enabled and
        !source.durable_write_enabled and
        !source.nendb_write_enabled;
}

fn evidenceClassesValid() bool {
    return hasEvidenceClass("causal-text-report") and
        hasEvidenceClass("causal-json-artifact") and
        hasEvidenceClass("causal-dot-graph") and
        hasEvidenceClass("release-gate-text-report") and
        hasEvidenceClass("release-gate-json-report") and
        hasEvidenceClass("ci-handoff-text") and
        hasEvidenceClass("source-preview-json");
}

fn hasEvidenceClass(id: []const u8) bool {
    for (evidence_classes) |class| {
        if (std.mem.eql(u8, class.id, id) and extensionAllowed(class.extension)) return true;
    }
    return false;
}

fn extensionAllowed(extension: []const u8) bool {
    return std.mem.eql(u8, extension, ".txt") or
        std.mem.eql(u8, extension, ".json") or
        std.mem.eql(u8, extension, ".dot");
}

fn metadataFieldsValid() bool {
    return hasRequiredMetadata("schema") and
        hasRequiredMetadata("source_artifact_path") and
        hasRequiredMetadata("workflow_digest") and
        hasRequiredMetadata("run_context_ref") and
        hasRequiredMetadata("commit_or_branch_ref") and
        hasRequiredMetadata("redaction_state") and
        hasRequiredMetadata("retention_days") and
        hasRequiredMetadata("visibility_class") and
        hasRequiredMetadata("consumer_role") and
        hasRequiredMetadata("interpretation_scope");
}

fn hasRequiredMetadata(name: []const u8) bool {
    for (metadata_fields) |field| {
        if (std.mem.eql(u8, field.name, name) and field.required) return true;
    }
    return false;
}

fn negativeFixturesValid() bool {
    return hasNegativeFixture("secret-shaped-content-denied") and
        hasNegativeFixture("missing-source-path-denied") and
        hasNegativeFixture("retention-over-fourteen-days-denied") and
        hasNegativeFixture("public-upload-claim-denied") and
        hasNegativeFixture("telemetry-gate-claim-denied") and
        hasNegativeFixture("production-health-claim-denied") and
        hasNegativeFixture("non-nendb-durable-scope-denied") and
        hasNegativeFixture("alternate-renderer-scope-denied");
}

fn hasNegativeFixture(id: []const u8) bool {
    for (negative_fixtures) |fixture| {
        if (std.mem.eql(u8, fixture.id, id) and std.mem.eql(u8, fixture.decision, "deny")) return true;
    }
    return false;
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

fn allChecksPassed(checks: []const PolicyCheck) bool {
    for (checks) |check| {
        if (check.status != .pass) return false;
    }
    return true;
}

fn formatPolicyJson(
    allocator: std.mem.Allocator,
    options: Options,
    source: ArchiveApplicationArtifact,
    result: PolicyResult,
    paths: OutputPaths,
) ![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "{\n");
    try output.appendSlice(allocator, "  \"schema\": ");
    try appendJsonString(allocator, &output, production_telemetry_ci_archive_evidence_policy_schema);
    try output.appendSlice(allocator, ",\n  \"schema_version\": 1,\n");
    try output.appendSlice(allocator, "  \"source_ci_archive_application\": ");
    try appendJsonString(allocator, &output, options.archive_application_path);
    try output.appendSlice(allocator, ",\n  \"source_archive_application_status\": ");
    try appendJsonString(allocator, &output, source.application_status);
    try output.print(allocator, ",\n  \"source_archive_application_applied\": {},\n", .{source.applied});
    try output.appendSlice(allocator, "  \"source_ci_harness_boundary\": ");
    try appendJsonString(allocator, &output, source.source_ci_harness_boundary);
    try output.appendSlice(allocator, ",\n  \"source_workflow_digest\": ");
    try appendJsonString(allocator, &output, source.source_workflow_digest);
    try output.appendSlice(allocator, ",\n  \"decision\": ");
    try appendJsonString(allocator, &output, decisionText(options.decision));
    try output.appendSlice(allocator, ",\n  \"archive_evidence_policy_status\": ");
    try appendJsonString(allocator, &output, policyStatusText(result.status));
    try output.print(allocator, ",\n  \"ready_for_next_branch\": {},\n", .{result.ready_for_next_branch});
    try output.appendSlice(allocator, "  \"reviewed_by\": ");
    try appendJsonString(allocator, &output, options.reviewed_by);
    try output.appendSlice(allocator, ",\n  \"policy\": ");
    try appendJsonString(allocator, &output, options.policy);
    try output.appendSlice(allocator, ",\n  \"reason\": ");
    try appendJsonString(allocator, &output, options.reason);
    try output.print(allocator, ",\n  \"applied\": {},\n", .{applied});
    try output.appendSlice(allocator, "  \"mutation_authority\": ");
    try appendJsonString(allocator, &output, mutation_authority);
    try output.print(allocator, ",\n  \"ci_gate_enabled\": {},\n", .{ci_gate_enabled});
    try output.print(allocator, "  \"ci_upload_execution_enabled\": {},\n", .{ci_upload_execution_enabled});
    try output.print(allocator, "  \"ci_workflow_mutation_enabled\": {},\n", .{ci_workflow_mutation_enabled});
    try output.print(allocator, "  \"production_telemetry_ingestion\": {},\n", .{production_telemetry_ingestion});
    try output.print(allocator, "  \"live_exporter_enabled\": {},\n", .{live_exporter_enabled});
    try output.print(allocator, "  \"network_send_enabled\": {},\n", .{network_send_enabled});
    try output.print(allocator, "  \"collector_endpoint_configured\": {},\n", .{collector_endpoint_configured});
    try output.print(allocator, "  \"otlp_serialization_enabled\": {},\n", .{otlp_serialization_enabled});
    try output.print(allocator, "  \"runtime_pipeline_enabled\": {},\n", .{runtime_pipeline_enabled});
    try output.print(allocator, "  \"durable_write_enabled\": {},\n", .{durable_write_enabled});
    try output.print(allocator, "  \"nendb_write_enabled\": {},\n", .{nendb_write_enabled});
    try output.appendSlice(allocator, "  \"evidence_classes\": ");
    try appendEvidenceClassesJson(allocator, &output);
    try output.appendSlice(allocator, ",\n  \"required_metadata_fields\": ");
    try appendMetadataFieldsJson(allocator, &output);
    try output.appendSlice(allocator, ",\n  \"interpretation_rules\": ");
    try appendStringArray(allocator, &output, interpretation_rules);
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
    try output.appendSlice(allocator, ",\n  \"generated_by\": ");
    try appendJsonString(allocator, &output, generated_by);
    try output.appendSlice(allocator, ",\n  \"source_branch\": ");
    try appendJsonString(allocator, &output, source_branch);
    try output.appendSlice(allocator, ",\n  \"recommendation\": ");
    try appendJsonString(allocator, &output, recommendation);
    try output.appendSlice(allocator, ",\n  \"next_branch_if_ready\": ");
    try appendJsonString(allocator, &output, next_branch_if_ready);
    try output.appendSlice(allocator, ",\n  \"output_paths\": { \"json\": ");
    try appendJsonString(allocator, &output, paths.json_path);
    try output.appendSlice(allocator, ", \"text\": ");
    try appendJsonString(allocator, &output, paths.text_path);
    try output.appendSlice(allocator, " },\n  \"agent_guidance\": ");
    try appendStringArray(allocator, &output, agentGuidance(result.status));
    try output.appendSlice(allocator, "\n}\n");

    return output.toOwnedSlice(allocator);
}

fn formatPolicyText(
    allocator: std.mem.Allocator,
    options: Options,
    source: ArchiveApplicationArtifact,
    result: PolicyResult,
    paths: OutputPaths,
) ![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "zigeffect production telemetry CI archive evidence policy\n");
    try output.print(allocator, "schema: {s}\n", .{production_telemetry_ci_archive_evidence_policy_schema});
    try output.print(allocator, "source archive application: {s}\n", .{options.archive_application_path});
    try output.print(allocator, "source archive application status: {s}\n", .{source.application_status});
    try output.print(allocator, "source archive application applied: {}\n", .{source.applied});
    try output.print(allocator, "decision: {s}\n", .{decisionText(options.decision)});
    try output.print(allocator, "archive_evidence_policy_status: {s}\n", .{policyStatusText(result.status)});
    try output.print(allocator, "ready_for_next_branch: {}\n", .{result.ready_for_next_branch});
    try output.print(allocator, "reviewed_by: {s}\n", .{options.reviewed_by});
    try output.print(allocator, "policy: {s}\n", .{options.policy});
    try output.print(allocator, "reason: {s}\n", .{options.reason});
    try output.print(allocator, "applied: {}\n", .{applied});
    try output.print(allocator, "mutation_authority: {s}\n", .{mutation_authority});
    try output.print(allocator, "ci gate enabled: {}\n", .{ci_gate_enabled});
    try output.print(allocator, "ci upload execution enabled: {}\n", .{ci_upload_execution_enabled});
    try output.print(allocator, "ci workflow mutation enabled: {}\n", .{ci_workflow_mutation_enabled});
    try output.print(allocator, "recommendation: {s}\n", .{recommendation});
    try output.print(allocator, "next branch if ready: {s}\n", .{next_branch_if_ready});
    try output.print(allocator, "json output: {s}\n", .{paths.json_path});
    try output.print(allocator, "text output: {s}\n\n", .{paths.text_path});

    try output.appendSlice(allocator, "checks:\n");
    for (result.checks) |check| {
        try output.print(allocator, "- {s}: {s} - {s}\n", .{ check.name, checkStatusText(check.status), check.detail });
    }
    try output.append(allocator, '\n');

    try appendTextList(allocator, &output, "evidence classes", evidenceClassIds());
    try appendTextList(allocator, &output, "interpretation rules", interpretation_rules);
    try appendTextList(allocator, &output, "blocked claims", blockedClaims(source));
    try appendTextList(allocator, &output, "required verification commands", required_verification_commands);
    try appendTextList(allocator, &output, "verified commands", options.verified_commands);
    try appendTextList(allocator, &output, "agent guidance", agentGuidance(result.status));

    return output.toOwnedSlice(allocator);
}

fn appendEvidenceClassesJson(allocator: std.mem.Allocator, output: *std.ArrayList(u8)) !void {
    try output.append(allocator, '[');
    for (evidence_classes, 0..) |class, index| {
        if (index > 0) try output.appendSlice(allocator, ", ");
        try output.appendSlice(allocator, "{ \"id\": ");
        try appendJsonString(allocator, output, class.id);
        try output.appendSlice(allocator, ", \"extension\": ");
        try appendJsonString(allocator, output, class.extension);
        try output.appendSlice(allocator, ", \"visibility_class\": ");
        try appendJsonString(allocator, output, class.visibility_class);
        try output.appendSlice(allocator, ", \"consumer_role\": ");
        try appendJsonString(allocator, output, class.consumer_role);
        try output.appendSlice(allocator, ", \"interpretation_scope\": ");
        try appendJsonString(allocator, output, class.interpretation_scope);
        try output.appendSlice(allocator, ", \"denied_claim\": ");
        try appendJsonString(allocator, output, class.denied_claim);
        try output.appendSlice(allocator, " }");
    }
    try output.append(allocator, ']');
}

fn appendMetadataFieldsJson(allocator: std.mem.Allocator, output: *std.ArrayList(u8)) !void {
    try output.append(allocator, '[');
    for (metadata_fields, 0..) |field, index| {
        if (index > 0) try output.appendSlice(allocator, ", ");
        try output.appendSlice(allocator, "{ \"name\": ");
        try appendJsonString(allocator, output, field.name);
        try output.print(allocator, ", \"required\": {}, ", .{field.required});
        try output.appendSlice(allocator, "\"description\": ");
        try appendJsonString(allocator, output, field.description);
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

fn appendChecksJson(allocator: std.mem.Allocator, output: *std.ArrayList(u8), checks: []const PolicyCheck) !void {
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

fn containsString(values: []const []const u8, needle: []const u8) bool {
    for (values) |value| {
        if (std.mem.indexOf(u8, value, needle) != null) return true;
    }
    return false;
}

fn evidenceClassIds() []const []const u8 {
    return &.{
        "causal-text-report",
        "causal-json-artifact",
        "causal-dot-graph",
        "release-gate-text-report",
        "release-gate-json-report",
        "ci-handoff-text",
        "source-preview-json",
    };
}

fn blockedClaims(source: ArchiveApplicationArtifact) []const []const u8 {
    if (source.blocked_claims.len > 0) return source.blocked_claims;
    return blocked_claims;
}

fn agentGuidance(status: PolicyStatus) []const []const u8 {
    return switch (status) {
        .ready => &.{
            "Use ready archive evidence policy to start CI gate readiness design only.",
            "Archived CI evidence may support diagnosis and comparison but not production health capacity or gate claims.",
            "Do not infer live telemetry durable writes NenDB writes workflow mutation CI gates or mutation authority.",
        },
        .blocked => &.{
            "Blocked archive evidence policy must not feed CI gate readiness work.",
            "Repair source application evidence reviewer decision verification commands or policy catalogs first.",
            "Do not treat archived CI artifacts as production telemetry or public evidence.",
        },
    };
}

const blocked_claims: []const []const u8 = &.{
    "ci-archive-evidence-policy-not-ready",
    "ci-gate-not-enabled",
    "production-health-not-proven",
    "capacity-not-proven",
    "live-telemetry-coverage-not-proven",
    "workflow-not-mutated-by-tool",
    "artifact-upload-not-executed-by-tool",
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
    const source_archive_application_json = try readRequiredArtifact(init.io, allocator, options.archive_application_path, error.MissingArchiveApplicationInput);
    defer allocator.free(source_archive_application_json);

    const reports = try formatReports(allocator, .{
        .options = options,
        .source_archive_application_json = source_archive_application_json,
    });
    defer reports.deinit(allocator);

    const paths = try outputPathsForOptions(allocator, options);
    defer paths.deinit(allocator);

    try writeArtifact(init.io, paths.json_path, reports.json);
    try writeArtifact(init.io, paths.text_path, reports.text);
    std.debug.print("{s}", .{reports.text});
}

fn usage() []const u8 {
    return "usage: zig build causal-production-telemetry-ci-archive-evidence-policy -- --from-archive-application <ci-archive-application.json> approve|reject --reason <reason> [--by <actor>] [--policy <policy>] [--verified-command <command>]... [--out-prefix <path-prefix>]\n";
}

fn failUsage(err: anyerror) noreturn {
    std.debug.print("causal-production-telemetry-ci-archive-evidence-policy error: {s}\n{s}", .{ @errorName(err), usage() });
    std.process.exit(2);
}

test "ci archive evidence policy schema and branch constants are stable" {
    try std.testing.expectEqualStrings("zigeffect.causal.production-telemetry-ci-archive-evidence-policy.v1", production_telemetry_ci_archive_evidence_policy_schema);
    try std.testing.expectEqual(@as(u32, 1), production_telemetry_ci_archive_evidence_policy_schema_version);
    try std.testing.expectEqualStrings("codex/zigeffect-causal-production-telemetry-ci-archive-evidence-policy", source_branch);
    try std.testing.expectEqualStrings("start-production-telemetry-ci-gate-readiness", recommendation);
    try std.testing.expectEqualStrings("codex/zigeffect-causal-production-telemetry-ci-gate-readiness", next_branch_if_ready);
    try std.testing.expect(containsString(required_verification_commands, "zig build causal-production-telemetry-ci-archive-application"));
    try std.testing.expect(containsString(required_verification_commands, "zig build release-gate --summary none"));
}

test "parses ci archive evidence policy options" {
    var options = try parseOptions(std.testing.allocator, &.{
        "zigeffect-causal-production-telemetry-ci-archive-evidence-policy",
        "--from-archive-application",
        ".zig-cache/causal-artifacts/ci-archive-application.json",
        "approve",
        "--reason",
        "CI archive evidence policy reviewed",
        "--by",
        "codex",
        "--policy",
        "manual-production-telemetry-ci-archive-evidence-policy",
        "--verified-command",
        "zig build causal-production-telemetry-ci-archive-application",
        "--out-prefix",
        ".zig-cache/causal-artifacts/custom-ci-archive-evidence-policy",
    });
    defer options.deinit(std.testing.allocator);

    try std.testing.expectEqual(Decision.approve, options.decision);
    try std.testing.expectEqualStrings(".zig-cache/causal-artifacts/ci-archive-application.json", options.archive_application_path);
    try std.testing.expectEqualStrings("CI archive evidence policy reviewed", options.reason);
    try std.testing.expectEqualStrings("codex", options.reviewed_by);
    try std.testing.expectEqualStrings("manual-production-telemetry-ci-archive-evidence-policy", options.policy);
    try std.testing.expectEqual(@as(usize, 1), options.verified_commands.len);
    try std.testing.expectEqualStrings("zig build causal-production-telemetry-ci-archive-application", options.verified_commands[0]);
    try std.testing.expectEqualStrings(".zig-cache/causal-artifacts/custom-ci-archive-evidence-policy", options.out_prefix.?);
}

test "default output path replaces archive application suffix" {
    const paths = try outputPathsForOptions(std.testing.allocator, .{
        .archive_application_path = "../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures-nendb-retention-fixtures-workbench-readonly-preview-ci-artifact-preview-ci-harness-boundary-ci-archive-application.json",
        .decision = .approve,
        .reason = "CI archive evidence policy reviewed",
    });
    defer paths.deinit(std.testing.allocator);

    try std.testing.expect(std.mem.endsWith(u8, paths.json_path, "-ci-archive-evidence-policy.json"));
    try std.testing.expect(std.mem.indexOf(u8, std.fs.path.basename(paths.json_path), "-ci-archive-application-ci-archive-evidence-policy") == null);
    try std.testing.expect(std.fs.path.basename(paths.json_path).len <= 255);
    try std.testing.expect(std.fs.path.basename(paths.text_path).len <= 255);
}

test "ready and rejected policy reports preserve disabled authority" {
    const ready = try formatReports(std.testing.allocator, .{
        .options = .{
            .archive_application_path = ".zig-cache/causal-artifacts/ci-archive-application.json",
            .decision = .approve,
            .reason = "CI archive evidence policy reviewed",
            .verified_commands = required_verification_commands,
        },
        .source_archive_application_json = sample_archive_application_json,
    });
    defer ready.deinit(std.testing.allocator);

    try std.testing.expect(std.mem.indexOf(u8, ready.json, "\"schema\": \"zigeffect.causal.production-telemetry-ci-archive-evidence-policy.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, ready.json, "\"archive_evidence_policy_status\": \"ready\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, ready.json, "\"ready_for_next_branch\": true") != null);
    try std.testing.expect(std.mem.indexOf(u8, ready.json, "\"source_archive_application_applied\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, ready.json, "\"ci_gate_enabled\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, ready.json, "\"ci_upload_execution_enabled\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, ready.json, "\"ci_workflow_mutation_enabled\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, ready.json, "\"id\": \"causal-json-artifact\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, ready.json, "\"id\": \"release-gate-json-report\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, ready.json, "\"id\": \"production-health-claim-denied\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, ready.json, "\"next_branch_if_ready\": \"codex/zigeffect-causal-production-telemetry-ci-gate-readiness\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, ready.text, "archive_evidence_policy_status: ready") != null);

    const rejected = try formatReports(std.testing.allocator, .{
        .options = .{
            .archive_application_path = ".zig-cache/causal-artifacts/ci-archive-application.json",
            .decision = .reject,
            .reason = "negative CI archive evidence policy path",
        },
        .source_archive_application_json = sample_archive_application_json,
    });
    defer rejected.deinit(std.testing.allocator);

    try std.testing.expect(std.mem.indexOf(u8, rejected.json, "\"archive_evidence_policy_status\": \"blocked\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, rejected.json, "\"ready_for_next_branch\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, rejected.json, "\"ci_gate_enabled\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, rejected.text, "archive_evidence_policy_status: blocked") != null);
}

test "blocked source archive application blocks policy readiness" {
    const blocked = try formatReports(std.testing.allocator, .{
        .options = .{
            .archive_application_path = ".zig-cache/causal-artifacts/ci-archive-application.json",
            .decision = .approve,
            .reason = "CI archive evidence policy reviewed",
            .verified_commands = required_verification_commands,
        },
        .source_archive_application_json = sample_archive_application_json ++ "\n",
    });
    defer blocked.deinit(std.testing.allocator);

    const failed_source = try formatReports(std.testing.allocator, .{
        .options = .{
            .archive_application_path = ".zig-cache/causal-artifacts/ci-archive-application.json",
            .decision = .approve,
            .reason = "CI archive evidence policy reviewed",
            .verified_commands = required_verification_commands,
        },
        .source_archive_application_json = sample_blocked_archive_application_json,
    });
    defer failed_source.deinit(std.testing.allocator);

    try std.testing.expect(std.mem.indexOf(u8, blocked.json, "\"archive_evidence_policy_status\": \"ready\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, failed_source.json, "\"archive_evidence_policy_status\": \"blocked\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, failed_source.json, "\"name\": \"source-checks-non-failing\"") != null);
}

const sample_archive_application_json =
    \\{
    \\  "schema": "zigeffect.causal.production-telemetry-ci-archive-application.v1",
    \\  "schema_version": 1,
    \\  "source_ci_harness_boundary": ".zig-cache/causal-artifacts/ci-harness-boundary.json",
    \\  "source_ci_artifact_preview": ".zig-cache/causal-artifacts/ci-preview.json",
    \\  "source_workbench_preview": ".zig-cache/causal-artifacts/workbench-preview.json",
    \\  "workflow_path": ".github/workflows/zigeffect-causal.yml",
    \\  "source_workflow_digest": "sha256:source-workflow-digest",
    \\  "after_workflow_path": null,
    \\  "after_workflow_digest": "",
    \\  "mode": "plan",
    \\  "application_status": "planned",
    \\  "applied": false,
    \\  "mutation_authority": "none",
    \\  "ci_archive_application_enabled": true,
    \\  "ci_upload_enabled": false,
    \\  "ci_upload_execution_enabled": false,
    \\  "ci_workflow_mutation_enabled": false,
    \\  "ci_gate_enabled": false,
    \\  "production_telemetry_ingestion": false,
    \\  "live_exporter_enabled": false,
    \\  "network_send_enabled": false,
    \\  "collector_endpoint_configured": false,
    \\  "otlp_serialization_enabled": false,
    \\  "runtime_pipeline_enabled": false,
    \\  "durable_write_enabled": false,
    \\  "nendb_write_enabled": false,
    \\  "workflow_changes": [],
    \\  "before_evidence": [],
    \\  "after_evidence": [],
    \\  "source_checks": [
    \\    { "name": "source-harness-ready", "status": "pass", "detail": "source harness boundary is ready" }
    \\  ],
    \\  "checks": [
    \\    { "name": "source-harness-schema", "status": "pass", "detail": "source schema is supported" },
    \\    { "name": "source-harness-ready", "status": "pass", "detail": "source harness boundary is ready" },
    \\    { "name": "workflow-change-present", "status": "skipped", "detail": "plan mode does not claim a workflow change" },
    \\    { "name": "before-evidence-present", "status": "skipped", "detail": "plan mode does not claim before evidence" },
    \\    { "name": "after-evidence-present", "status": "skipped", "detail": "plan mode does not claim after evidence" }
    \\  ],
    \\  "required_verification_commands": [
    \\    "zig build causal-production-telemetry-ci-harness-boundary",
    \\    "zig build causal-artifacts"
    \\  ],
    \\  "verified_commands": [
    \\    "zig build causal-production-telemetry-ci-harness-boundary",
    \\    "zig build causal-artifacts"
    \\  ],
    \\  "cluster_release_gate_assumptions": [
    \\    "zig build release-gate --summary none is the clustering-aware CI execution body"
    \\  ],
    \\  "blocked_claims": [
    \\    "ci-upload-execution-not-run-by-tool",
    \\    "ci-telemetry-gate-not-enabled",
    \\    "production-cluster-not-claimed-ready"
    \\  ]
    \\}
;

const sample_blocked_archive_application_json =
    \\{
    \\  "schema": "zigeffect.causal.production-telemetry-ci-archive-application.v1",
    \\  "schema_version": 1,
    \\  "source_ci_harness_boundary": ".zig-cache/causal-artifacts/ci-harness-boundary.json",
    \\  "workflow_path": ".github/workflows/zigeffect-causal.yml",
    \\  "source_workflow_digest": "sha256:source-workflow-digest",
    \\  "mode": "record-applied",
    \\  "application_status": "blocked",
    \\  "applied": false,
    \\  "mutation_authority": "none",
    \\  "ci_archive_application_enabled": true,
    \\  "ci_upload_enabled": false,
    \\  "ci_upload_execution_enabled": false,
    \\  "ci_workflow_mutation_enabled": false,
    \\  "ci_gate_enabled": false,
    \\  "production_telemetry_ingestion": false,
    \\  "live_exporter_enabled": false,
    \\  "network_send_enabled": false,
    \\  "collector_endpoint_configured": false,
    \\  "otlp_serialization_enabled": false,
    \\  "runtime_pipeline_enabled": false,
    \\  "durable_write_enabled": false,
    \\  "nendb_write_enabled": false,
    \\  "checks": [
    \\    { "name": "after-evidence-present", "status": "fail", "detail": "record-applied requires after evidence" }
    \\  ],
    \\  "required_verification_commands": [
    \\    "zig build causal-production-telemetry-ci-harness-boundary"
    \\  ],
    \\  "verified_commands": [],
    \\  "cluster_release_gate_assumptions": [
    \\    "zig build release-gate --summary none is the clustering-aware CI execution body"
    \\  ],
    \\  "blocked_claims": [
    \\    "ci-upload-execution-not-run-by-tool"
    \\  ]
    \\}
;
