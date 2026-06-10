const std = @import("std");

pub const production_telemetry_nendb_retention_fixtures_schema = "zigeffect.causal.production-telemetry-nendb-retention-fixtures.v1";
pub const production_telemetry_nendb_retention_fixtures_schema_version: u32 = 1;
pub const source_branch = "codex/zigeffect-causal-production-telemetry-nendb-retention-fixtures";
pub const recommendation = "start-production-telemetry-workbench-readonly-preview";
pub const next_branch_if_ready = "codex/zigeffect-causal-production-telemetry-workbench-readonly-preview";

const local_pipeline_schema = "zigeffect.causal.production-telemetry-local-pipeline-fixtures.v1";
const generated_by = "causal-production-telemetry-nendb-retention-fixtures";
const applied = false;
const mutation_authority = "none";
const production_telemetry_ingestion = false;
const live_exporter_enabled = false;
const network_send_enabled = false;
const collector_endpoint_configured = false;
const otlp_serialization_enabled = false;
const durable_write_enabled = false;
const nendb_write_enabled = false;
const ci_gate_enabled = false;
const runtime_pipeline_enabled = false;
const local_pipeline_fixture_mode = true;
const nendb_retention_fixture_mode = true;

const Decision = enum { approve, reject };
const FixtureStatus = enum { ready, blocked };
const CheckStatus = enum { pass, fail };

const Options = struct {
    local_pipeline_path: []const u8,
    decision: Decision,
    reviewed_by: []const u8 = "nendb-retention-reviewer",
    policy: []const u8 = "manual-production-telemetry-nendb-retention-fixtures",
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

const FixtureInput = struct {
    options: Options,
    source_local_pipeline_json: []const u8,
};

const FixtureReports = struct {
    json: []const u8,
    text: []const u8,

    fn deinit(self: FixtureReports, allocator: std.mem.Allocator) void {
        allocator.free(self.json);
        allocator.free(self.text);
    }
};

const LocalPipelineCheck = struct {
    name: []const u8,
    status: []const u8,
    detail: []const u8 = "",
};

const LocalPipelineSummary = struct {
    source_contract_count: usize = 0,
    positive_fixture_count: usize = 0,
    negative_fixture_count: usize = 0,
    validation_check_count: usize = 0,
};

const LocalPipelineArtifact = struct {
    schema: []const u8,
    schema_version: u32,
    source_boundary: []const u8 = "",
    source_proposal: []const u8 = "",
    source_readiness: []const u8 = "",
    source_fixtures: []const u8 = "",
    decision: []const u8,
    fixture_status: []const u8,
    ready_for_next_branch: bool,
    applied: bool,
    mutation_authority: []const u8,
    production_telemetry_ingestion: bool,
    live_exporter_enabled: bool,
    network_send_enabled: bool,
    collector_endpoint_configured: bool,
    otlp_serialization_enabled: bool,
    durable_write_enabled: bool,
    ci_gate_enabled: bool,
    runtime_pipeline_enabled: bool,
    local_pipeline_fixture_mode: bool,
    boundary_summary: LocalPipelineSummary = .{},
    checks: []const LocalPipelineCheck = &.{},
    pipeline_fixture_catalog: []const PipelineFixture = &.{},
    pipeline_validation_checks: []const []const u8 = &.{},
    implementation_gates: []const []const u8 = &.{},
    non_goals: []const []const u8 = &.{},
    blocked_claims: []const []const u8 = &.{},
    required_verification_commands: []const []const u8 = &.{},
    verified_commands: []const []const u8 = &.{},
};

const PipelineFixture = struct {
    id: []const u8,
    input_envelope: []const u8,
    output_envelope: []const u8,
    output_fields: []const []const u8,
    blocked_fields: []const []const u8,
};

const NendbMappingFixture = struct {
    id: []const u8,
    source_envelope: []const u8,
    target_schema: []const u8,
    label: []const u8,
    retained_fields: []const []const u8,
    blocked_fields: []const []const u8,
};

const FixtureCheck = struct {
    name: []const u8,
    status: CheckStatus,
    detail: []const u8,
};

const FixtureResult = struct {
    status: FixtureStatus,
    ready_for_next_branch: bool,
    checks: []const FixtureCheck,
    local_pipeline_summary: LocalPipelineSummary,
    source_boundary: []const u8,
    source_proposal: []const u8,
    source_readiness: []const u8,
    source_fixtures: []const u8,

    fn deinit(self: FixtureResult, allocator: std.mem.Allocator) void {
        if (self.checks.len > 0) allocator.free(self.checks);
    }
};

fn parseOptions(allocator: std.mem.Allocator, args: []const []const u8) !Options {
    if (args.len < 2) return error.MissingLocalPipelinePath;
    if (!std.mem.eql(u8, args[1], "--from-local-pipeline")) return error.UnknownFlag;
    if (args.len < 3) return error.MissingLocalPipelinePath;
    const local_pipeline_path = args[2];
    if (!std.mem.endsWith(u8, local_pipeline_path, ".json")) return error.InvalidLocalPipelinePath;
    if (args.len < 4) return error.MissingDecision;
    const decision = try parseDecision(args[3]);

    var reviewed_by: []const u8 = "nendb-retention-reviewer";
    var policy: []const u8 = "manual-production-telemetry-nendb-retention-fixtures";
    var reason: ?[]const u8 = null;
    var out_prefix: ?[]const u8 = null;
    var verified_commands = std.ArrayList([]const u8).empty;
    errdefer verified_commands.deinit(allocator);

    var index: usize = 4;
    while (index < args.len) {
        const arg = args[index];
        if (!std.mem.startsWith(u8, arg, "--")) return error.UnknownArgument;
        if (index + 1 >= args.len) return error.MissingFlagValue;
        const value = args[index + 1];

        if (std.mem.eql(u8, arg, "--reason")) {
            reason = value;
        } else if (std.mem.eql(u8, arg, "--by")) {
            reviewed_by = value;
        } else if (std.mem.eql(u8, arg, "--policy")) {
            policy = value;
        } else if (std.mem.eql(u8, arg, "--verified-command")) {
            try verified_commands.append(allocator, value);
        } else if (std.mem.eql(u8, arg, "--out-prefix")) {
            out_prefix = value;
        } else {
            return error.UnknownFlag;
        }
        index += 2;
    }

    const final_reason = reason orelse return error.MissingReason;
    if (final_reason.len == 0) return error.MissingReason;

    return .{
        .local_pipeline_path = local_pipeline_path,
        .decision = decision,
        .reviewed_by = reviewed_by,
        .policy = policy,
        .reason = final_reason,
        .verified_commands = try verified_commands.toOwnedSlice(allocator),
        .out_prefix = out_prefix,
    };
}

fn outputPathsForOptions(allocator: std.mem.Allocator, options: Options) !OutputPaths {
    const prefix = if (options.out_prefix) |out_prefix|
        try allocator.dupe(u8, out_prefix)
    else blk: {
        if (!std.mem.endsWith(u8, options.local_pipeline_path, ".json")) return error.InvalidLocalPipelinePath;
        const base = options.local_pipeline_path[0 .. options.local_pipeline_path.len - ".json".len];
        break :blk try std.fmt.allocPrint(allocator, "{s}-nendb-retention-fixtures", .{base});
    };
    defer allocator.free(prefix);

    return .{
        .json_path = try std.fmt.allocPrint(allocator, "{s}.json", .{prefix}),
        .text_path = try std.fmt.allocPrint(allocator, "{s}.txt", .{prefix}),
    };
}

fn formatReports(allocator: std.mem.Allocator, input: FixtureInput) !FixtureReports {
    var parsed = try std.json.parseFromSlice(LocalPipelineArtifact, allocator, input.source_local_pipeline_json, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();

    const result = try evaluateFixtures(allocator, input.options, parsed.value);
    defer result.deinit(allocator);

    const json = try formatFixtureJson(allocator, input.options, result);
    errdefer allocator.free(json);
    const text = try formatFixtureText(allocator, input.options, result);
    errdefer allocator.free(text);

    return .{ .json = json, .text = text };
}

pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    const options = parseOptions(init.gpa, args) catch |err| failUsage(err);
    defer options.deinit(init.gpa);
    run(init, options) catch |err| switch (err) {
        error.MissingLocalPipelineInput => failUsage(err),
        else => return err,
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

fn fixtureStatusText(status: FixtureStatus) []const u8 {
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

fn evaluateFixtures(
    allocator: std.mem.Allocator,
    options: Options,
    local_pipeline: LocalPipelineArtifact,
) !FixtureResult {
    var checks = std.ArrayList(FixtureCheck).empty;
    errdefer checks.deinit(allocator);

    try appendCheck(allocator, &checks, "local-pipeline-schema", if (std.mem.eql(u8, local_pipeline.schema, local_pipeline_schema) and local_pipeline.schema_version == 1) .pass else .fail, "source local pipeline schema is supported");
    try appendCheck(allocator, &checks, "local-pipeline-status", if (std.mem.eql(u8, local_pipeline.fixture_status, "ready") and local_pipeline.ready_for_next_branch) .pass else .fail, "source local pipeline is ready for NenDB retention fixture work");
    try appendCheck(allocator, &checks, "local-pipeline-decision-approved", if (std.mem.eql(u8, local_pipeline.decision, "approve")) .pass else .fail, "source local pipeline decision approved the handoff");
    try appendCheck(allocator, &checks, "retention-fixture-decision", if (options.reason.len > 0) .pass else .fail, "retention fixture decision includes a reason");
    try appendCheck(allocator, &checks, "decision-approved", if (options.decision == .approve) .pass else .fail, "fixture decision must approve workbench preview handoff");
    try appendCheck(allocator, &checks, "authority-boundary", if (authorityLocalPipelineIntact(local_pipeline)) .pass else .fail, "source local pipeline and NenDB retention fixture authority fields remain disabled");
    try appendCheck(allocator, &checks, "no-network-retention", if (noNetworkRetention(local_pipeline)) .pass else .fail, "network send and collector endpoint stay disabled");
    try appendCheck(allocator, &checks, "no-otlp-serialization", if (noOtlpSerialization(local_pipeline)) .pass else .fail, "OTLP serialization stays out of scope");
    try appendCheck(allocator, &checks, "no-runtime-pipeline", if (noRuntimePipeline(local_pipeline)) .pass else .fail, "runtime pipeline execution remains disabled");
    try appendCheck(allocator, &checks, "no-durable-write", if (noDurableWrite(local_pipeline)) .pass else .fail, "durable production writes remain disabled");
    try appendCheck(allocator, &checks, "no-nendb-write", if (!nendb_write_enabled) .pass else .fail, "NenDB writes remain disabled");
    try appendCheck(allocator, &checks, "source-chain-linked", if (sourceChainLinked(local_pipeline)) .pass else .fail, "local pipeline links boundary proposal readiness and fixture JSON artifacts");
    try appendCheck(allocator, &checks, "local-pipeline-checks-passed", if (local_pipelineChecksPassed(local_pipeline.checks)) .pass else .fail, "all required source local pipeline checks passed");
    try appendCheck(allocator, &checks, "local-pipeline-verification-recorded", if (localPipelineVerificationRecorded(local_pipeline)) .pass else .fail, "source local pipeline recorded required verification command evidence");
    try appendCheck(allocator, &checks, "mapping-fixtures-present", if (mappingFixturesPresent(local_pipeline.pipeline_fixture_catalog)) .pass else .fail, "NenDB mapping fixture catalog contains required fixtures");
    try appendCheck(allocator, &checks, "nendb-node-mappings-present", if (nendbNodeMappingsPresent()) .pass else .fail, "NenDB node mappings cover runtime app OTel redaction and sampling fixtures");
    try appendCheck(allocator, &checks, "nendb-edge-mappings-present", if (nendbEdgeMappingsPresent()) .pass else .fail, "NenDB edge mappings cover correlation links");
    try appendCheck(allocator, &checks, "retention-policy-fixture-present", if (retentionPolicyFixturePresent()) .pass else .fail, "retention policy fixture constants are present");
    try appendCheck(allocator, &checks, "retention-validation-passed", if (retentionValidationPassed()) .pass else .fail, "all NenDB retention validation checks passed");
    try appendCheck(allocator, &checks, "fixture-verification-recorded", if (verifiedCommandsContainAll(options.verified_commands, required_verification_commands)) .pass else .fail, "fixture review recorded every required verification command");
    try appendCheck(allocator, &checks, "nendb-only-scope", if (nendbOnlyScope()) .pass else .fail, "durable direction remains future NenDB-only scope");
    try appendCheck(allocator, &checks, "solid-webui-scope", if (solidWebuiScope()) .pass else .fail, "workbench direction remains SolidJS inside webui-dev/zig-webui");

    const check_slice = try checks.toOwnedSlice(allocator);
    errdefer allocator.free(check_slice);
    const ready = allChecksPassed(check_slice);
    return .{
        .status = if (ready) .ready else .blocked,
        .ready_for_next_branch = ready,
        .checks = check_slice,
        .local_pipeline_summary = local_pipeline.boundary_summary,
        .source_boundary = local_pipeline.source_boundary,
        .source_proposal = local_pipeline.source_proposal,
        .source_readiness = local_pipeline.source_readiness,
        .source_fixtures = local_pipeline.source_fixtures,
    };
}

fn appendCheck(
    allocator: std.mem.Allocator,
    checks: *std.ArrayList(FixtureCheck),
    name: []const u8,
    status: CheckStatus,
    detail: []const u8,
) !void {
    try checks.append(allocator, .{ .name = name, .status = status, .detail = detail });
}

fn authorityLocalPipelineIntact(local_pipeline: LocalPipelineArtifact) bool {
    return !local_pipeline.applied and
        std.mem.eql(u8, local_pipeline.mutation_authority, "none") and
        !local_pipeline.production_telemetry_ingestion and
        !local_pipeline.live_exporter_enabled and
        !local_pipeline.network_send_enabled and
        !local_pipeline.collector_endpoint_configured and
        !local_pipeline.otlp_serialization_enabled and
        !local_pipeline.durable_write_enabled and
        !local_pipeline.ci_gate_enabled and
        !local_pipeline.runtime_pipeline_enabled and
        local_pipeline.local_pipeline_fixture_mode and
        !applied and
        std.mem.eql(u8, mutation_authority, "none") and
        !production_telemetry_ingestion and
        !live_exporter_enabled and
        !network_send_enabled and
        !collector_endpoint_configured and
        !otlp_serialization_enabled and
        !durable_write_enabled and
        !nendb_write_enabled and
        !ci_gate_enabled and
        !runtime_pipeline_enabled and
        local_pipeline_fixture_mode and
        nendb_retention_fixture_mode;
}

fn noNetworkRetention(local_pipeline: LocalPipelineArtifact) bool {
    return !local_pipeline.network_send_enabled and
        !local_pipeline.collector_endpoint_configured and
        !network_send_enabled and
        !collector_endpoint_configured;
}

fn noOtlpSerialization(local_pipeline: LocalPipelineArtifact) bool {
    return !local_pipeline.otlp_serialization_enabled and !otlp_serialization_enabled;
}

fn noRuntimePipeline(local_pipeline: LocalPipelineArtifact) bool {
    return !local_pipeline.runtime_pipeline_enabled and !runtime_pipeline_enabled;
}

fn noDurableWrite(local_pipeline: LocalPipelineArtifact) bool {
    return !local_pipeline.durable_write_enabled and !durable_write_enabled;
}

fn sourceChainLinked(local_pipeline: LocalPipelineArtifact) bool {
    return local_pipeline.source_boundary.len > 0 and
        local_pipeline.source_proposal.len > 0 and
        local_pipeline.source_readiness.len > 0 and
        local_pipeline.source_fixtures.len > 0 and
        std.mem.endsWith(u8, local_pipeline.source_boundary, ".json") and
        std.mem.endsWith(u8, local_pipeline.source_proposal, ".json") and
        std.mem.endsWith(u8, local_pipeline.source_readiness, ".json") and
        std.mem.endsWith(u8, local_pipeline.source_fixtures, ".json");
}

fn local_pipelineChecksPassed(checks: []const LocalPipelineCheck) bool {
    const required = [_][]const u8{
        "boundary-schema",
        "boundary-status",
        "boundary-decision-approved",
        "fixture-decision",
        "decision-approved",
        "authority-boundary",
        "no-network-pipeline",
        "no-otlp-serialization",
        "no-durable-write",
        "source-chain-linked",
        "boundary-checks-passed",
        "boundary-contract-present",
        "envelope-fixtures-present",
        "pipeline-fixtures-present",
        "redaction-fixtures-present",
        "sampling-fixtures-present",
        "pipeline-validation-passed",
        "boundary-verification-recorded",
        "fixture-verification-recorded",
        "nendb-only-scope",
        "solid-webui-scope",
    };
    for (required) |name| {
        if (!hasLocalPipelineCheck(checks, name, "pass")) return false;
    }
    for (checks) |check| {
        if (!std.mem.eql(u8, check.status, "pass")) return false;
    }
    return true;
}

fn hasLocalPipelineCheck(checks: []const LocalPipelineCheck, name: []const u8, status: []const u8) bool {
    for (checks) |check| {
        if (std.mem.eql(u8, check.name, name) and std.mem.eql(u8, check.status, status)) return true;
    }
    return false;
}

fn sourcePipelineFixturePresent(fixtures: []const PipelineFixture, id: []const u8) bool {
    for (fixtures) |fixture| {
        if (std.mem.eql(u8, fixture.id, id)) return true;
    }
    return false;
}

fn mappingFixturesPresent(source_fixtures: []const PipelineFixture) bool {
    const required = [_][]const u8{
        "runtime-span-normalized-envelope",
        "app-semantic-normalized-envelope",
        "backend-otel-local-envelope",
        "redaction-access-reviewed-envelope",
        "sampling-kept-envelope",
        "sampling-dropped-envelope",
        "correlation-link-envelope",
    };
    for (required) |id| {
        if (!sourcePipelineFixturePresent(source_fixtures, id)) return false;
    }
    return nendb_mapping_fixtures.len == 9;
}

fn nendbNodeMappingsPresent() bool {
    const required = [_][]const u8{
        "nendb-runtime-event-node-fixture",
        "nendb-app-semantic-node-fixture",
        "nendb-otel-attribute-node-fixture",
        "nendb-redaction-access-node-fixture",
        "nendb-sampling-retention-node-fixture",
    };
    for (required) |id| {
        if (!hasMappingFixture(id)) return false;
    }
    return true;
}

fn nendbEdgeMappingsPresent() bool {
    return hasMappingFixture("nendb-correlation-edge-fixture") and
        mappingTargetSchema("nendb-correlation-edge-fixture", "zigeffect.causal.nendb_edge.v1");
}

fn retentionPolicyFixturePresent() bool {
    return hasMappingFixture("nendb-retention-policy-record-fixture") and
        mappingTargetSchema("nendb-retention-policy-record-fixture", "zigeffect.causal.nendb-retention-report.v1") and
        mappingHasRetainedField("nendb-retention-policy-record-fixture", "ttl_days=14") and
        mappingHasRetainedField("nendb-retention-policy-record-fixture", "max_events=4096") and
        mappingHasRetainedField("nendb-retention-policy-record-fixture", "compaction_trigger_events=2048") and
        mappingHasRetainedField("nendb-retention-policy-record-fixture", "compact_to_events=1024") and
        mappingHasRetainedField("nendb-retention-policy-record-fixture", "backup_required=true") and
        mappingHasRetainedField("nendb-retention-policy-record-fixture", "recovery_required=true");
}

fn retentionValidationPassed() bool {
    return containsString(retention_validation_checks, "source-local-pipeline-ready") and
        containsString(retention_validation_checks, "source-authority-disabled") and
        containsString(retention_validation_checks, "source-fixture-catalog-covered") and
        containsString(retention_validation_checks, "nendb-node-mappings-present") and
        containsString(retention_validation_checks, "nendb-edge-mappings-present") and
        containsString(retention_validation_checks, "retention-policy-constants-match") and
        containsString(retention_validation_checks, "ttl-policy-record-only") and
        containsString(retention_validation_checks, "compaction-policy-record-only") and
        containsString(retention_validation_checks, "backup-recovery-markers-present") and
        containsString(retention_validation_checks, "nendb-write-disabled") and
        containsString(retention_validation_checks, "durable-write-disabled") and
        containsString(retention_validation_checks, "non-nendb-scope-rejected") and
        containsString(retention_validation_checks, "cockroach-scope-rejected") and
        containsString(retention_validation_checks, "workbench-preview-next-only") and
        nendbNodeMappingsPresent() and
        nendbEdgeMappingsPresent() and
        retentionPolicyFixturePresent() and
        hasMappingFixture("nendb-compaction-window-fixture") and
        hasMappingFixture("nendb-backup-recovery-marker-fixture") and
        mappingBlocksField("nendb-retention-policy-record-fixture", "live_deletion_decisions") and
        mappingBlocksField("nendb-compaction-window-fixture", "compaction_execution") and
        mappingBlocksField("nendb-backup-recovery-marker-fixture", "restore_execution");
}

fn localPipelineVerificationRecorded(local_pipeline: LocalPipelineArtifact) bool {
    return local_pipeline.required_verification_commands.len > 0 and
        verifiedCommandsContainAll(local_pipeline.verified_commands, local_pipeline.required_verification_commands);
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

fn nendbOnlyScope() bool {
    return containsString(non_goals, "Non-NenDB durable adapter work") and
        containsString(non_goals, "Cockroach adapter work") and
        containsString(blocked_claims, "non-nendb-durable-storage") and
        containsString(blocked_claims, "cockroach-adapter-work");
}

fn solidWebuiScope() bool {
    return containsString(non_goals, "React or alternate renderer work") and
        containsString(blocked_claims, "react-or-alternate-renderer");
}

fn hasMappingFixture(id: []const u8) bool {
    for (nendb_mapping_fixtures) |fixture| {
        if (std.mem.eql(u8, fixture.id, id)) return true;
    }
    return false;
}

fn mappingHasRetainedField(id: []const u8, field: []const u8) bool {
    for (nendb_mapping_fixtures) |fixture| {
        if (std.mem.eql(u8, fixture.id, id)) return containsString(fixture.retained_fields, field);
    }
    return false;
}

fn mappingBlocksField(id: []const u8, field: []const u8) bool {
    for (nendb_mapping_fixtures) |fixture| {
        if (std.mem.eql(u8, fixture.id, id)) return containsString(fixture.blocked_fields, field);
    }
    return false;
}

fn mappingTargetSchema(id: []const u8, schema: []const u8) bool {
    for (nendb_mapping_fixtures) |fixture| {
        if (std.mem.eql(u8, fixture.id, id)) return std.mem.eql(u8, fixture.target_schema, schema);
    }
    return false;
}

fn containsString(values: []const []const u8, needle: []const u8) bool {
    for (values) |value| {
        if (std.mem.indexOf(u8, value, needle) != null) return true;
    }
    return false;
}

fn allChecksPassed(checks: []const FixtureCheck) bool {
    for (checks) |check| {
        if (check.status != .pass) return false;
    }
    return true;
}

fn formatFixtureJson(
    allocator: std.mem.Allocator,
    options: Options,
    result: FixtureResult,
) ![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "{\n");
    try output.appendSlice(allocator, "  \"schema\": ");
    try appendJsonString(allocator, &output, production_telemetry_nendb_retention_fixtures_schema);
    try output.appendSlice(allocator, ",\n  \"schema_version\": 1,\n");
    try output.appendSlice(allocator, "  \"source_local_pipeline\": ");
    try appendJsonString(allocator, &output, options.local_pipeline_path);
    try output.appendSlice(allocator, ",\n  \"source_boundary\": ");
    try appendJsonString(allocator, &output, result.source_boundary);
    try output.appendSlice(allocator, ",\n  \"source_proposal\": ");
    try appendJsonString(allocator, &output, result.source_proposal);
    try output.appendSlice(allocator, ",\n  \"source_readiness\": ");
    try appendJsonString(allocator, &output, result.source_readiness);
    try output.appendSlice(allocator, ",\n  \"source_fixtures\": ");
    try appendJsonString(allocator, &output, result.source_fixtures);
    try output.appendSlice(allocator, ",\n  \"decision\": ");
    try appendJsonString(allocator, &output, decisionText(options.decision));
    try output.appendSlice(allocator, ",\n  \"retention_fixture_status\": ");
    try appendJsonString(allocator, &output, fixtureStatusText(result.status));
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
    try output.print(allocator, ",\n  \"production_telemetry_ingestion\": {},\n", .{production_telemetry_ingestion});
    try output.print(allocator, "  \"live_exporter_enabled\": {},\n", .{live_exporter_enabled});
    try output.print(allocator, "  \"network_send_enabled\": {},\n", .{network_send_enabled});
    try output.print(allocator, "  \"collector_endpoint_configured\": {},\n", .{collector_endpoint_configured});
    try output.print(allocator, "  \"otlp_serialization_enabled\": {},\n", .{otlp_serialization_enabled});
    try output.print(allocator, "  \"runtime_pipeline_enabled\": {},\n", .{runtime_pipeline_enabled});
    try output.print(allocator, "  \"durable_write_enabled\": {},\n", .{durable_write_enabled});
    try output.print(allocator, "  \"nendb_write_enabled\": {},\n", .{nendb_write_enabled});
    try output.print(allocator, "  \"ci_gate_enabled\": {},\n", .{ci_gate_enabled});
    try output.print(allocator, "  \"local_pipeline_fixture_mode\": {},\n", .{local_pipeline_fixture_mode});
    try output.print(allocator, "  \"nendb_retention_fixture_mode\": {},\n", .{nendb_retention_fixture_mode});
    try output.appendSlice(allocator, "  \"source_branch\": ");
    try appendJsonString(allocator, &output, source_branch);
    try output.appendSlice(allocator, ",\n  \"recommendation\": ");
    try appendJsonString(allocator, &output, recommendation);
    try output.appendSlice(allocator, ",\n  \"next_branch_if_ready\": ");
    try appendJsonString(allocator, &output, next_branch_if_ready);
    try output.appendSlice(allocator, ",\n  \"local_pipeline_summary\": ");
    try appendLocalPipelineSummaryJson(allocator, &output, result.local_pipeline_summary);
    try output.appendSlice(allocator, ",\n  \"checks\": ");
    try appendChecksJson(allocator, &output, result.checks);
    try output.appendSlice(allocator, ",\n  \"nendb_mapping_fixtures\": ");
    try appendNendbMappingFixtureCatalogJson(allocator, &output, nendb_mapping_fixtures);
    try output.appendSlice(allocator, ",\n  \"retention_validation_checks\": ");
    try appendStringArray(allocator, &output, retention_validation_checks);
    try output.appendSlice(allocator, ",\n  \"implementation_gates\": ");
    try appendStringArray(allocator, &output, implementation_gates);
    try output.appendSlice(allocator, ",\n  \"non_goals\": ");
    try appendStringArray(allocator, &output, non_goals);
    try output.appendSlice(allocator, ",\n  \"blocked_claims\": ");
    try appendStringArray(allocator, &output, blocked_claims);
    try output.appendSlice(allocator, ",\n  \"required_verification_commands\": ");
    try appendStringArray(allocator, &output, required_verification_commands);
    try output.appendSlice(allocator, ",\n  \"verified_commands\": ");
    try appendStringArray(allocator, &output, options.verified_commands);
    try output.appendSlice(allocator, ",\n  \"agent_guidance\": ");
    try appendStringArray(allocator, &output, agentGuidance(result.status));
    try output.appendSlice(allocator, "\n}\n");

    return output.toOwnedSlice(allocator);
}

fn formatFixtureText(
    allocator: std.mem.Allocator,
    options: Options,
    result: FixtureResult,
) ![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "zigeffect production telemetry nendb retention fixtures\n");
    try output.print(allocator, "schema: {s}\n", .{production_telemetry_nendb_retention_fixtures_schema});
    try output.print(allocator, "source local_pipeline: {s}\n", .{options.local_pipeline_path});
    try output.print(allocator, "source boundary: {s}\n", .{result.source_boundary});
    try output.print(allocator, "source proposal: {s}\n", .{result.source_proposal});
    try output.print(allocator, "source readiness: {s}\n", .{result.source_readiness});
    try output.print(allocator, "source fixtures: {s}\n", .{result.source_fixtures});
    try output.print(allocator, "decision: {s}\n", .{decisionText(options.decision)});
    try output.print(allocator, "retention_fixture_status: {s}\n", .{fixtureStatusText(result.status)});
    try output.print(allocator, "ready_for_next_branch: {}\n", .{result.ready_for_next_branch});
    try output.print(allocator, "reviewed_by: {s}\n", .{options.reviewed_by});
    try output.print(allocator, "policy: {s}\n", .{options.policy});
    try output.print(allocator, "reason: {s}\n", .{options.reason});
    try output.print(allocator, "applied: {}\n", .{applied});
    try output.print(allocator, "mutation_authority: {s}\n", .{mutation_authority});
    try output.print(allocator, "production telemetry ingestion: {}\n", .{production_telemetry_ingestion});
    try output.print(allocator, "live exporter enabled: {}\n", .{live_exporter_enabled});
    try output.print(allocator, "network send enabled: {}\n", .{network_send_enabled});
    try output.print(allocator, "collector endpoint configured: {}\n", .{collector_endpoint_configured});
    try output.print(allocator, "otlp serialization enabled: {}\n", .{otlp_serialization_enabled});
    try output.print(allocator, "runtime pipeline enabled: {}\n", .{runtime_pipeline_enabled});
    try output.print(allocator, "durable write enabled: {}\n", .{durable_write_enabled});
    try output.print(allocator, "nendb write enabled: {}\n", .{nendb_write_enabled});
    try output.print(allocator, "ci gate enabled: {}\n", .{ci_gate_enabled});
    try output.print(allocator, "local pipeline fixture mode: {}\n", .{local_pipeline_fixture_mode});
    try output.print(allocator, "nendb retention fixture mode: {}\n", .{nendb_retention_fixture_mode});
    try output.print(allocator, "generated by: {s}\n", .{generated_by});
    try output.print(allocator, "source branch: {s}\n", .{source_branch});
    try output.print(allocator, "recommendation: {s}\n", .{recommendation});
    try output.print(allocator, "next branch if ready: {s}\n\n", .{next_branch_if_ready});

    try output.appendSlice(allocator, "local_pipeline summary:\n");
    try output.print(allocator, "- source contracts: {d}\n", .{result.local_pipeline_summary.source_contract_count});
    try output.print(allocator, "- positive fixtures: {d}\n", .{result.local_pipeline_summary.positive_fixture_count});
    try output.print(allocator, "- negative fixtures: {d}\n", .{result.local_pipeline_summary.negative_fixture_count});
    try output.print(allocator, "- validation checks: {d}\n\n", .{result.local_pipeline_summary.validation_check_count});

    try output.appendSlice(allocator, "checks:\n");
    for (result.checks) |check| {
        try output.print(allocator, "- {s}: {s} - {s}\n", .{ check.name, checkStatusText(check.status), check.detail });
    }
    try output.append(allocator, '\n');

    try appendNendbMappingFixtureCatalogText(allocator, &output, nendb_mapping_fixtures);
    try appendTextList(allocator, &output, "retention validation checks", retention_validation_checks);
    try appendTextList(allocator, &output, "implementation gates", implementation_gates);
    try appendTextList(allocator, &output, "non-goals", non_goals);
    try appendTextList(allocator, &output, "blocked claims", blocked_claims);
    try appendTextList(allocator, &output, "required verification commands", required_verification_commands);
    try appendTextList(allocator, &output, "verified commands", options.verified_commands);
    try appendTextList(allocator, &output, "agent guidance", agentGuidance(result.status));

    return output.toOwnedSlice(allocator);
}

fn appendLocalPipelineSummaryJson(allocator: std.mem.Allocator, output: *std.ArrayList(u8), summary: LocalPipelineSummary) !void {
    try output.print(
        allocator,
        "{{ \"source_contract_count\": {d}, \"positive_fixture_count\": {d}, \"negative_fixture_count\": {d}, \"validation_check_count\": {d} }}",
        .{ summary.source_contract_count, summary.positive_fixture_count, summary.negative_fixture_count, summary.validation_check_count },
    );
}

fn appendChecksJson(allocator: std.mem.Allocator, output: *std.ArrayList(u8), checks: []const FixtureCheck) !void {
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

fn appendNendbMappingFixtureCatalogJson(allocator: std.mem.Allocator, output: *std.ArrayList(u8), fixtures: []const NendbMappingFixture) !void {
    try output.append(allocator, '[');
    for (fixtures, 0..) |fixture, index| {
        if (index > 0) try output.appendSlice(allocator, ", ");
        try output.appendSlice(allocator, "{ \"id\": ");
        try appendJsonString(allocator, output, fixture.id);
        try output.appendSlice(allocator, ", \"source_envelope\": ");
        try appendJsonString(allocator, output, fixture.source_envelope);
        try output.appendSlice(allocator, ", \"target_schema\": ");
        try appendJsonString(allocator, output, fixture.target_schema);
        try output.appendSlice(allocator, ", \"label\": ");
        try appendJsonString(allocator, output, fixture.label);
        try output.appendSlice(allocator, ", \"retained_fields\": ");
        try appendStringArray(allocator, output, fixture.retained_fields);
        try output.appendSlice(allocator, ", \"blocked_fields\": ");
        try appendStringArray(allocator, output, fixture.blocked_fields);
        try output.appendSlice(allocator, " }");
    }
    try output.append(allocator, ']');
}

fn appendNendbMappingFixtureCatalogText(allocator: std.mem.Allocator, output: *std.ArrayList(u8), fixtures: []const NendbMappingFixture) !void {
    try output.appendSlice(allocator, "nendb mapping fixtures:\n");
    for (fixtures) |fixture| {
        try output.print(allocator, "- {s}: {s} -> {s} ({s})\n", .{ fixture.id, fixture.source_envelope, fixture.target_schema, fixture.label });
        try output.appendSlice(allocator, "  retained fields:");
        for (fixture.retained_fields) |field| try output.print(allocator, " {s}", .{field});
        try output.appendSlice(allocator, "\n  blocked fields:");
        for (fixture.blocked_fields) |field| try output.print(allocator, " {s}", .{field});
        try output.append(allocator, '\n');
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

fn agentGuidance(status: FixtureStatus) []const []const u8 {
    return switch (status) {
        .ready => &.{
            "Ready NenDB retention fixtures permit starting the workbench read-only preview branch only.",
            "Cite source local pipeline boundary proposal readiness fixtures mapping catalog retention validation checks and verification commands.",
            "Do not infer runtime telemetry ingestion live pipeline network send OTLP collector NenDB writes durable writes CI gates non-NenDB adapters alternate renderers or mutation authority.",
        },
        .blocked => &.{
            "Blocked NenDB retention fixtures must not start workbench preview or durable write work.",
            "Repair local pipeline evidence mapping validation evidence or verification command evidence first.",
            "Do not infer NenDB retention write approval from blocked fixture evidence.",
        },
    };
}

fn usage() []const u8 {
    return "usage: zig build causal-production-telemetry-nendb-retention-fixtures -- --from-local-pipeline <local-pipeline.json> approve|reject --reason <reason> [--by <actor>] [--policy <policy>] [--verified-command <command>]... [--out-prefix <path-prefix>]\n";
}

fn failUsage(err: anyerror) noreturn {
    std.debug.print("causal-production-telemetry-nendb-retention-fixtures error: {s}\n{s}", .{ @errorName(err), usage() });
    std.process.exit(2);
}

fn readRequiredArtifact(io: std.Io, allocator: std.mem.Allocator, path: []const u8) ![]const u8 {
    return std.Io.Dir.cwd().readFileAlloc(io, path, allocator, .limited(1024 * 1024)) catch |err| switch (err) {
        error.FileNotFound => error.MissingLocalPipelineInput,
        else => return err,
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
    const source_local_pipeline_json = try readRequiredArtifact(init.io, allocator, options.local_pipeline_path);
    defer allocator.free(source_local_pipeline_json);

    const reports = try formatReports(allocator, .{
        .options = options,
        .source_local_pipeline_json = source_local_pipeline_json,
    });
    defer reports.deinit(allocator);

    const paths = try outputPathsForOptions(allocator, options);
    defer paths.deinit(allocator);

    try writeArtifact(init.io, paths.json_path, reports.json);
    try writeArtifact(init.io, paths.text_path, reports.text);
    std.debug.print("{s}", .{reports.text});
}

const required_verification_commands: []const []const u8 = &.{
    "zig build causal-production-telemetry-local-pipeline-fixtures",
    "zig build causal-nendb-storage-backend",
    "zig build causal-durable-production-retention -- --format json",
    "zig build causal-schema-governance -- --format json",
    "zig build causal-production-hardening-backlog -- --format json",
    "zig build examples",
    "zig build test",
};

const nendb_mapping_fixtures: []const NendbMappingFixture = &.{
    .{ .id = "nendb-runtime-event-node-fixture", .source_envelope = "runtime-span-normalized-envelope", .target_schema = "zigeffect.causal.nendb_node.v1", .label = "causal.telemetry.runtime_span", .retained_fields = &.{ "event_id_ref", "trace_id_ref", "span_id_ref", "parent_span_id_ref", "causal_event_ref", "redaction_state", "sample_state" }, .blocked_fields = &.{ "raw_payload", "headers", "prompts", "credentials", "raw_tenant_id", "raw_user_id", "collector_endpoint", "network_address" } },
    .{ .id = "nendb-app-semantic-node-fixture", .source_envelope = "app-semantic-normalized-envelope", .target_schema = "zigeffect.causal.nendb_node.v1", .label = "causal.telemetry.app_semantic", .retained_fields = &.{ "event_id_ref", "domain_entity_ref", "schema_ref", "data_subject_ref", "operation_ref", "redaction_state", "sample_state" }, .blocked_fields = &.{ "raw_request_body", "raw_response_body", "prompt_text", "credential_material", "raw_pii" } },
    .{ .id = "nendb-otel-attribute-node-fixture", .source_envelope = "backend-otel-local-envelope", .target_schema = "zigeffect.causal.nendb_node.v1", .label = "causal.telemetry.otel_ref", .retained_fields = &.{ "otel_schema_ref", "trace_id_ref", "span_id_ref", "attribute_refs", "redaction_state", "sample_state" }, .blocked_fields = &.{ "collector_endpoint", "auth_headers", "wire_payload_bytes", "exporter_sdk_configuration", "otlp_protobuf_bytes" } },
    .{ .id = "nendb-redaction-access-node-fixture", .source_envelope = "redaction-access-reviewed-envelope", .target_schema = "zigeffect.causal.nendb_node.v1", .label = "causal.telemetry.redaction_access", .retained_fields = &.{ "visibility_class", "redaction_state", "access_policy_ref", "denied_raw_fields" }, .blocked_fields = &.{ "raw_secrets", "raw_credentials", "raw_headers", "raw_prompts", "raw_tenant_id", "raw_user_id" } },
    .{ .id = "nendb-sampling-retention-node-fixture", .source_envelope = "sampling-kept-envelope+sampling-dropped-envelope", .target_schema = "zigeffect.causal.nendb_node.v1", .label = "causal.telemetry.sampling", .retained_fields = &.{ "sample_state", "sample_policy_ref", "sample_reason", "retained_fields" }, .blocked_fields = &.{ "unsampled_raw_payload_fields", "wall_clock_randomness", "production_traffic_rates", "production_capacity_claims" } },
    .{ .id = "nendb-correlation-edge-fixture", .source_envelope = "correlation-link-envelope", .target_schema = "zigeffect.causal.nendb_edge.v1", .label = "causal.telemetry.correlates", .retained_fields = &.{ "from_event_ref", "to_artifact_ref", "causal_event_ref", "trace_id_ref", "schema_ref" }, .blocked_fields = &.{ "raw_payload_joins", "source_database_reads" } },
    .{ .id = "nendb-retention-policy-record-fixture", .source_envelope = "durable-production-retention-policy", .target_schema = "zigeffect.causal.nendb-retention-report.v1", .label = "causal.telemetry.retention_policy", .retained_fields = &.{ "ttl_days=14", "max_events=4096", "compaction_trigger_events=2048", "compact_to_events=1024", "backup_required=true", "recovery_required=true" }, .blocked_fields = &.{ "production_byte_estimates", "production_cost_estimates", "live_deletion_decisions" } },
    .{ .id = "nendb-compaction-window-fixture", .source_envelope = "durable-production-retention-policy", .target_schema = "zigeffect.causal.nendb-retention-report.v1", .label = "causal.telemetry.compaction_window", .retained_fields = &.{ "compaction_required_ref", "preserve_run_roots", "preserve_terminal_failures", "preserve_governance_artifacts" }, .blocked_fields = &.{ "compaction_execution", "destructive_deletion" } },
    .{ .id = "nendb-backup-recovery-marker-fixture", .source_envelope = "durable-production-retention-policy", .target_schema = "zigeffect.causal.nendb-retention-report.v1", .label = "causal.telemetry.backup_recovery", .retained_fields = &.{ "backup_required", "recovery_required", "oldest_retained_event_id_ref", "newest_retained_event_id_ref", "lineage_recovery_check_ref" }, .blocked_fields = &.{ "backup_execution", "restore_execution", "live_credentials" } },
};

const retention_validation_checks: []const []const u8 = &.{
    "source-local-pipeline-ready",
    "source-authority-disabled",
    "source-fixture-catalog-covered",
    "nendb-node-mappings-present",
    "nendb-edge-mappings-present",
    "retention-policy-constants-match",
    "ttl-policy-record-only",
    "compaction-policy-record-only",
    "backup-recovery-markers-present",
    "nendb-write-disabled",
    "durable-write-disabled",
    "non-nendb-scope-rejected",
    "cockroach-scope-rejected",
    "workbench-preview-next-only",
};

const implementation_gates: []const []const u8 = &.{
    "source local pipeline artifact is ready",
    "source local pipeline checks and verification commands remain pass",
    "NenDB retention fixtures emit mapping records only",
    "network send collector endpoint and OTLP serialization remain disabled",
    "durable and NenDB writes remain disabled",
    "workbench work remains SolidJS inside webui-dev/zig-webui",
    "workbench read-only preview must be reviewed before UI work",
};

const non_goals: []const []const u8 = &.{
    "Runtime telemetry ingestion or instrumentation changes",
    "Live local or production pipeline execution",
    "Network sends collector endpoint configuration or outbound exporter transport",
    "OTLP serialization SDK setup or collector delivery",
    "Durable production writes",
    "NenDB writes durable writer execution compaction execution backup execution or restore execution",
    "NenDB retention record writes",
    "Non-NenDB durable adapter work",
    "Cockroach adapter work",
    "CI telemetry gates or fail thresholds",
    "Production dashboards streaming hosted workbench or workbench UI implementation",
    "React or alternate renderer work",
    "Source config registry deployment rollout alert app or production mutation authority",
};

const blocked_claims: []const []const u8 = &.{
    "runtime-pipeline-enabled",
    "live-exporter-enabled",
    "network-send-enabled",
    "collector-endpoint-configured",
    "otlp-serialization-enabled",
    "durable-production-write-enabled",
    "nendb-write-enabled",
    "nendb-retention-write-enabled",
    "non-nendb-durable-storage",
    "cockroach-adapter-work",
    "ci-telemetry-gate",
    "react-or-alternate-renderer",
    "mutation-authority-granted",
};

test "nendb retention fixture schema and authority constants are stable" {
    try std.testing.expectEqualStrings("zigeffect.causal.production-telemetry-nendb-retention-fixtures.v1", production_telemetry_nendb_retention_fixtures_schema);
    try std.testing.expectEqual(@as(u32, 1), production_telemetry_nendb_retention_fixtures_schema_version);
    try std.testing.expectEqualStrings("codex/zigeffect-causal-production-telemetry-nendb-retention-fixtures", source_branch);
    try std.testing.expectEqualStrings("start-production-telemetry-workbench-readonly-preview", recommendation);
    try std.testing.expectEqualStrings("codex/zigeffect-causal-production-telemetry-workbench-readonly-preview", next_branch_if_ready);
    try std.testing.expectEqualStrings("zigeffect.causal.production-telemetry-local-pipeline-fixtures.v1", local_pipeline_schema);
    try std.testing.expectEqualStrings("causal-production-telemetry-nendb-retention-fixtures", generated_by);
    try std.testing.expect(!applied);
    try std.testing.expectEqualStrings("none", mutation_authority);
    try std.testing.expect(!production_telemetry_ingestion);
    try std.testing.expect(!live_exporter_enabled);
    try std.testing.expect(!network_send_enabled);
    try std.testing.expect(!collector_endpoint_configured);
    try std.testing.expect(!otlp_serialization_enabled);
    try std.testing.expect(!durable_write_enabled);
    try std.testing.expect(!nendb_write_enabled);
    try std.testing.expect(!ci_gate_enabled);
    try std.testing.expect(!runtime_pipeline_enabled);
    try std.testing.expect(local_pipeline_fixture_mode);
    try std.testing.expect(nendb_retention_fixture_mode);
    try std.testing.expect(hasMappingFixture("nendb-runtime-event-node-fixture"));
    try std.testing.expect(hasMappingFixture("nendb-backup-recovery-marker-fixture"));
}

test "parses approve fixture options with verified commands and output prefix" {
    var options = try parseOptions(std.testing.allocator, &.{
        "zigeffect-causal-production-telemetry-nendb-retention-fixtures",
        "--from-local-pipeline",
        ".zig-cache/causal-artifacts/local-pipeline.json",
        "approve",
        "--reason",
        "local pipeline evidence reviewed",
        "--by",
        "codex",
        "--policy",
        "manual-production-telemetry-nendb-retention-fixtures",
        "--verified-command",
        "zig build test",
        "--out-prefix",
        ".zig-cache/causal-artifacts/custom-nendb-retention-fixtures",
    });
    defer options.deinit(std.testing.allocator);

    try std.testing.expectEqual(Decision.approve, options.decision);
    try std.testing.expectEqualStrings(".zig-cache/causal-artifacts/local-pipeline.json", options.local_pipeline_path);
    try std.testing.expectEqualStrings("local pipeline evidence reviewed", options.reason);
    try std.testing.expectEqualStrings("codex", options.reviewed_by);
    try std.testing.expectEqualStrings("manual-production-telemetry-nendb-retention-fixtures", options.policy);
    try std.testing.expectEqual(@as(usize, 1), options.verified_commands.len);
    try std.testing.expectEqualStrings("zig build test", options.verified_commands[0]);
    try std.testing.expectEqualStrings(".zig-cache/causal-artifacts/custom-nendb-retention-fixtures", options.out_prefix.?);
}

test "rejects missing local_pipeline path decision and reason" {
    try std.testing.expectError(
        error.MissingLocalPipelinePath,
        parseOptions(std.testing.allocator, &.{"zigeffect-causal-production-telemetry-nendb-retention-fixtures"}),
    );
    try std.testing.expectError(
        error.InvalidLocalPipelinePath,
        parseOptions(std.testing.allocator, &.{ "zigeffect-causal-production-telemetry-nendb-retention-fixtures", "--from-local-pipeline", "local_pipeline.txt", "approve", "--reason", "reviewed" }),
    );
    try std.testing.expectError(
        error.MissingDecision,
        parseOptions(std.testing.allocator, &.{ "zigeffect-causal-production-telemetry-nendb-retention-fixtures", "--from-local-pipeline", "local-pipeline.json" }),
    );
    try std.testing.expectError(
        error.UnknownDecision,
        parseOptions(std.testing.allocator, &.{ "zigeffect-causal-production-telemetry-nendb-retention-fixtures", "--from-local-pipeline", "local-pipeline.json", "maybe", "--reason", "reviewed" }),
    );
    try std.testing.expectError(
        error.MissingReason,
        parseOptions(std.testing.allocator, &.{ "zigeffect-causal-production-telemetry-nendb-retention-fixtures", "--from-local-pipeline", "local-pipeline.json", "approve" }),
    );
}

test "derives nendb retention output paths from local pipeline json path" {
    const derived = try outputPathsForOptions(std.testing.allocator, .{
        .local_pipeline_path = ".zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures.json",
        .decision = .approve,
        .reason = "reviewed",
    });
    defer derived.deinit(std.testing.allocator);
    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures-nendb-retention-fixtures.json",
        derived.json_path,
    );
    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures-nendb-retention-fixtures.txt",
        derived.text_path,
    );

    const custom = try outputPathsForOptions(std.testing.allocator, .{
        .local_pipeline_path = ".zig-cache/causal-artifacts/local-pipeline.json",
        .decision = .approve,
        .reason = "reviewed",
        .out_prefix = ".zig-cache/causal-artifacts/custom-nendb-retention-fixtures",
    });
    defer custom.deinit(std.testing.allocator);
    try std.testing.expectEqualStrings(".zig-cache/causal-artifacts/custom-nendb-retention-fixtures.json", custom.json_path);
    try std.testing.expectEqualStrings(".zig-cache/causal-artifacts/custom-nendb-retention-fixtures.txt", custom.text_path);
}

test "ready and blocked nendb retention reports preserve fixture-only authority" {
    const ready = try formatReports(std.testing.allocator, .{
        .options = .{
            .local_pipeline_path = "local-pipeline.json",
            .decision = .approve,
            .reason = "local pipeline evidence reviewed",
            .verified_commands = required_verification_commands,
        },
        .source_local_pipeline_json = sample_local_pipeline_json,
    });
    defer ready.deinit(std.testing.allocator);

    try std.testing.expect(std.mem.indexOf(u8, ready.json, "\"schema\": \"zigeffect.causal.production-telemetry-nendb-retention-fixtures.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, ready.json, "\"retention_fixture_status\": \"ready\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, ready.json, "\"ready_for_next_branch\": true") != null);
    try std.testing.expect(std.mem.indexOf(u8, ready.json, "\"runtime_pipeline_enabled\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, ready.json, "\"nendb_write_enabled\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, ready.json, "\"local_pipeline_fixture_mode\": true") != null);
    try std.testing.expect(std.mem.indexOf(u8, ready.json, "\"nendb_retention_fixture_mode\": true") != null);
    try std.testing.expect(std.mem.indexOf(u8, ready.json, "\"network_send_enabled\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, ready.json, "\"collector_endpoint_configured\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, ready.json, "\"otlp_serialization_enabled\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, ready.json, "\"nendb_mapping_fixtures\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, ready.json, "nendb-runtime-event-node-fixture") != null);
    try std.testing.expect(std.mem.indexOf(u8, ready.json, "nendb-backup-recovery-marker-fixture") != null);
    try std.testing.expect(std.mem.indexOf(u8, ready.text, "retention_fixture_status: ready") != null);
    try std.testing.expect(std.mem.indexOf(u8, ready.text, "runtime pipeline enabled: false") != null);
    try std.testing.expect(std.mem.indexOf(u8, ready.text, "nendb write enabled: false") != null);
    try std.testing.expect(std.mem.indexOf(u8, ready.text, "nendb retention fixture mode: true") != null);
    try std.testing.expect(std.mem.indexOf(u8, ready.text, "next branch if ready: codex/zigeffect-causal-production-telemetry-workbench-readonly-preview") != null);

    const blocked = try formatReports(std.testing.allocator, .{
        .options = .{
            .local_pipeline_path = "local-pipeline.json",
            .decision = .reject,
            .reason = "negative fixture path",
        },
        .source_local_pipeline_json = sample_local_pipeline_json,
    });
    defer blocked.deinit(std.testing.allocator);

    try std.testing.expect(std.mem.indexOf(u8, blocked.json, "\"retention_fixture_status\": \"blocked\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, blocked.json, "\"ready_for_next_branch\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, blocked.json, "\"runtime_pipeline_enabled\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, blocked.json, "\"nendb_write_enabled\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, blocked.json, "\"nendb_retention_fixture_mode\": true") != null);
    try std.testing.expect(std.mem.indexOf(u8, blocked.text, "retention_fixture_status: blocked") != null);
}

const sample_local_pipeline_json =
    \\{
    \\  "schema": "zigeffect.causal.production-telemetry-local-pipeline-fixtures.v1",
    \\  "schema_version": 1,
    \\  "source_boundary": "../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary.json",
    \\  "source_proposal": "../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal.json",
    \\  "source_readiness": "../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review.json",
    \\  "source_fixtures": "../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures.json",
    \\  "decision": "approve",
    \\  "fixture_status": "ready",
    \\  "ready_for_next_branch": true,
    \\  "reviewed_by": "local-pipeline-reviewer",
    \\  "policy": "manual-production-telemetry-local-pipeline-fixtures",
    \\  "reason": "approved boundary reviewed for local pipeline fixtures",
    \\  "applied": false,
    \\  "mutation_authority": "none",
    \\  "production_telemetry_ingestion": false,
    \\  "live_exporter_enabled": false,
    \\  "network_send_enabled": false,
    \\  "collector_endpoint_configured": false,
    \\  "otlp_serialization_enabled": false,
    \\  "durable_write_enabled": false,
    \\  "ci_gate_enabled": false,
    \\  "runtime_pipeline_enabled": false,
    \\  "local_pipeline_fixture_mode": true,
    \\  "boundary_summary": { "source_contract_count": 7, "positive_fixture_count": 6, "negative_fixture_count": 14, "validation_check_count": 8 },
    \\  "checks": [
    \\    { "name": "boundary-schema", "status": "pass", "detail": "source boundary schema is supported" },
    \\    { "name": "boundary-status", "status": "pass", "detail": "source boundary is approved for local pipeline fixture work" },
    \\    { "name": "boundary-decision-approved", "status": "pass", "detail": "source boundary decision approved the handoff" },
    \\    { "name": "fixture-decision", "status": "pass", "detail": "fixture decision includes a reason" },
    \\    { "name": "decision-approved", "status": "pass", "detail": "fixture decision must approve NenDB retention fixture handoff" },
    \\    { "name": "authority-boundary", "status": "pass", "detail": "source boundary and local pipeline fixture authority fields remain disabled" },
    \\    { "name": "no-network-pipeline", "status": "pass", "detail": "network send collector endpoint and transport stay disabled" },
    \\    { "name": "no-otlp-serialization", "status": "pass", "detail": "OTLP serialization stays out of scope" },
    \\    { "name": "no-durable-write", "status": "pass", "detail": "durable production writes remain disabled" },
    \\    { "name": "source-chain-linked", "status": "pass", "detail": "boundary links proposal readiness and fixture JSON artifacts" },
    \\    { "name": "boundary-checks-passed", "status": "pass", "detail": "all required source boundary checks passed" },
    \\    { "name": "boundary-contract-present", "status": "pass", "detail": "source boundary contract contains no-network fields" },
    \\    { "name": "envelope-fixtures-present", "status": "pass", "detail": "source boundary lists all required envelope fixtures" },
    \\    { "name": "pipeline-fixtures-present", "status": "pass", "detail": "local pipeline fixture catalog contains required fixtures" },
    \\    { "name": "redaction-fixtures-present", "status": "pass", "detail": "local pipeline fixtures include redaction and access evidence" },
    \\    { "name": "sampling-fixtures-present", "status": "pass", "detail": "local pipeline fixtures include kept and dropped sampling evidence" },
    \\    { "name": "pipeline-validation-passed", "status": "pass", "detail": "all local pipeline validation checks passed" },
    \\    { "name": "boundary-verification-recorded", "status": "pass", "detail": "source boundary recorded required verification command evidence" },
    \\    { "name": "fixture-verification-recorded", "status": "pass", "detail": "fixture review recorded every required verification command" },
    \\    { "name": "nendb-only-scope", "status": "pass", "detail": "durable direction remains future NenDB-only scope" },
    \\    { "name": "solid-webui-scope", "status": "pass", "detail": "workbench direction remains SolidJS inside webui-dev/zig-webui" }
    \\  ],
    \\  "pipeline_fixture_catalog": [
    \\    { "id": "runtime-span-normalized-envelope", "input_envelope": "runtime-span-event-envelope", "output_envelope": "runtime-span-local-json-envelope", "output_fields": ["event_id", "trace_id_ref", "span_id_ref", "redaction_state", "sample_state"], "blocked_fields": ["raw_payload", "headers", "prompts", "credentials", "raw_tenant_id", "raw_user_id", "collector_endpoint", "network_address"] },
    \\    { "id": "app-semantic-normalized-envelope", "input_envelope": "app-semantic-ref-envelope", "output_envelope": "app-semantic-local-json-envelope", "output_fields": ["event_id", "domain_entity_ref", "schema_ref", "data_subject_ref", "operation_ref", "redaction_state", "sample_state"], "blocked_fields": ["raw_request_body", "raw_response_body", "prompt_text", "credential_material", "raw_pii"] },
    \\    { "id": "backend-otel-local-envelope", "input_envelope": "backend-otel-record-envelope", "output_envelope": "backend-otel-local-json-envelope", "output_fields": ["otel_schema_ref", "trace_id_ref", "span_id_ref", "attribute_refs", "redaction_state", "sample_state"], "blocked_fields": ["collector_endpoint", "auth_headers", "wire_payload_bytes", "exporter_sdk_configuration"] },
    \\    { "id": "redaction-access-reviewed-envelope", "input_envelope": "redaction-access-envelope", "output_envelope": "redaction-access-local-json-envelope", "output_fields": ["visibility_class", "redaction_state", "access_policy_ref", "denied_raw_fields"], "blocked_fields": ["raw_secrets", "raw_credentials", "raw_headers", "raw_prompts", "raw_tenant_id", "raw_user_id"] },
    \\    { "id": "sampling-kept-envelope", "input_envelope": "sampling-boundary-envelope", "output_envelope": "sampling-kept-local-json-envelope", "output_fields": ["sample_state=kept", "sample_policy_ref", "sample_reason"], "blocked_fields": ["wall_clock_randomness", "production_traffic_rates", "production_capacity_claims"] },
    \\    { "id": "sampling-dropped-envelope", "input_envelope": "sampling-boundary-envelope", "output_envelope": "sampling-dropped-local-json-envelope", "output_fields": ["sample_state=dropped", "sample_policy_ref", "retained_fields"], "blocked_fields": ["unsampled_raw_payload_fields"] },
    \\    { "id": "correlation-link-envelope", "input_envelope": "runtime-span-event-envelope+app-semantic-ref-envelope+backend-otel-record-envelope+redaction-access-envelope+sampling-boundary-envelope", "output_envelope": "correlation-link-local-json-envelope", "output_fields": ["event_id", "trace_id_ref", "causal_event_ref", "artifact_id_ref", "schema_ref"], "blocked_fields": ["raw_payload_joins", "source_database_reads"] }
    \\  ],
    \\  "pipeline_validation_checks": [
    \\    "fixture-references-source-envelope",
    \\    "fixture-declares-output-envelope",
    \\    "fixture-declares-redaction-state",
    \\    "fixture-declares-sample-state",
    \\    "raw-sensitive-fields-blocked",
    \\    "network-and-exporter-fields-blocked",
    \\    "otlp-protobuf-absent",
    \\    "durable-write-fields-absent",
    \\    "sampled-out-retains-metadata-only",
    \\    "correlation-uses-refs-only"
    \\  ],
    \\  "non_goals": [
    \\    "Non-NenDB durable adapter work",
    \\    "Cockroach adapter work",
    \\    "React or alternate renderer work"
    \\  ],
    \\  "blocked_claims": [
    \\    "non-nendb-durable-storage",
    \\    "cockroach-adapter-work",
    \\    "react-or-alternate-renderer"
    \\  ],
    \\  "required_verification_commands": [
    \\    "zig build test"
    \\  ],
    \\  "verified_commands": [
    \\    "zig build test"
    \\  ]
    \\}
;
