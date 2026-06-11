const std = @import("std");

pub const app_facing_production_integration_nendb_handoff_fixtures_schema = "zigeffect.causal.app-facing-production-integration-nendb-handoff-fixtures.v1";
pub const app_facing_production_integration_nendb_handoff_fixtures_schema_version: u32 = 1;
pub const source_branch = "codex/zigeffect-causal-app-facing-production-integration-nendb-handoff-fixtures";
pub const recommendation = "start-app-facing-production-integration-audit-remediation-bridge";
pub const next_branch_if_ready = "codex/zigeffect-causal-app-facing-production-integration-audit-remediation-bridge";

const local_fixtures_schema = "zigeffect.causal.app-facing-production-integration-local-fixtures.v1";
const generated_by = "causal-app-facing-production-integration-nendb-handoff-fixtures";
const applied = false;
const mutation_authority = "none";
const production_telemetry_ingestion = false;
const live_exporter_enabled = false;
const network_send_enabled = false;
const collector_endpoint_configured = false;
const otlp_serialization_enabled = false;
const durable_write_enabled = false;
const app_mutation_enabled = false;
const ci_gate_enabled = false;
const raw_payload_capture_enabled = false;
const app_config_write_enabled = false;
const app_data_write_enabled = false;
const deployment_mutation_enabled = false;
const nendb_write_enabled = false;
const nendb_adapter_execution_enabled = false;
const app_runtime_integration_enabled = false;
const agent_query_live_projection_enabled = false;
const solid_webui_preview_enabled = false;
const local_fixture_mode = true;
const nendb_handoff_fixture_mode = true;

const Decision = enum { approve, reject };
const FixtureStatus = enum { ready, blocked };
const CheckStatus = enum { pass, fail };

const Options = struct {
    local_fixtures_path: []const u8,
    decision: Decision,
    reviewed_by: []const u8 = "nendb-handoff-reviewer",
    policy: []const u8 = "manual-app-facing-production-integration-nendb-handoff-fixtures",
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

fn parseOptions(allocator: std.mem.Allocator, args: []const []const u8) !Options {
    if (args.len < 2) return error.MissingLocalFixturesPath;
    if (!std.mem.eql(u8, args[1], "--from-local-fixtures")) return error.UnknownFlag;
    if (args.len < 3) return error.MissingLocalFixturesPath;
    const local_fixtures_path = args[2];
    if (!std.mem.endsWith(u8, local_fixtures_path, ".json")) return error.InvalidLocalFixturesPath;
    if (args.len < 4) return error.MissingDecision;
    const decision = try parseDecision(args[3]);

    var reviewed_by: []const u8 = "nendb-handoff-reviewer";
    var policy: []const u8 = "manual-app-facing-production-integration-nendb-handoff-fixtures";
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
        .local_fixtures_path = local_fixtures_path,
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
        if (!std.mem.endsWith(u8, options.local_fixtures_path, ".json")) return error.InvalidLocalFixturesPath;
        const base = options.local_fixtures_path[0 .. options.local_fixtures_path.len - ".json".len];
        break :blk try std.fmt.allocPrint(allocator, "{s}-nendb-handoff-fixtures", .{base});
    };
    defer allocator.free(prefix);

    return .{
        .json_path = try std.fmt.allocPrint(allocator, "{s}.json", .{prefix}),
        .text_path = try std.fmt.allocPrint(allocator, "{s}.txt", .{prefix}),
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

const FixtureInput = struct {
    options: Options,
    source_local_fixtures_json: []const u8,
};

const FixtureReports = struct {
    json: []const u8,
    text: []const u8,

    fn deinit(self: FixtureReports, allocator: std.mem.Allocator) void {
        allocator.free(self.json);
        allocator.free(self.text);
    }
};

const LocalFixturesCheck = struct {
    name: []const u8,
    status: []const u8,
    detail: []const u8 = "",
};

const LocalFixturesSummary = struct {
    source_contract_count: usize = 0,
    positive_fixture_count: usize = 0,
    negative_fixture_count: usize = 0,
    validation_check_count: usize = 0,
};

const LocalFixture = struct {
    id: []const u8,
    source_boundary_label: []const u8,
    input_ref: []const u8,
    output_artifact: []const u8,
    output_fields: []const []const u8,
    blocked_fields: []const []const u8,
};

const LocalFixturesArtifact = struct {
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
    app_mutation_enabled: bool,
    ci_gate_enabled: bool,
    raw_payload_capture_enabled: bool,
    app_config_write_enabled: bool,
    app_data_write_enabled: bool,
    deployment_mutation_enabled: bool,
    nendb_write_enabled: bool,
    app_runtime_integration_enabled: bool,
    agent_query_live_projection_enabled: bool,
    solid_webui_preview_enabled: bool,
    local_fixture_mode: bool,
    boundary_summary: LocalFixturesSummary = .{},
    checks: []const LocalFixturesCheck = &.{},
    fixture_catalog: []const LocalFixture = &.{},
    required_verification_commands: []const []const u8 = &.{},
    verified_commands: []const []const u8 = &.{},
};

const NendbHandoffFixture = struct {
    id: []const u8,
    source_fixture: []const u8,
    target_schema: []const u8,
    handoff_kind: []const u8,
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
    local_fixtures_summary: LocalFixturesSummary,
    source_boundary: []const u8,
    source_proposal: []const u8,
    source_readiness: []const u8,
    source_fixtures: []const u8,

    fn deinit(self: FixtureResult, allocator: std.mem.Allocator) void {
        if (self.checks.len > 0) allocator.free(self.checks);
    }
};

fn formatReports(allocator: std.mem.Allocator, input: FixtureInput) !FixtureReports {
    var parsed = try std.json.parseFromSlice(LocalFixturesArtifact, allocator, input.source_local_fixtures_json, .{ .ignore_unknown_fields = true });
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
        error.MissingLocalFixturesInput => failUsage(err),
        else => return err,
    };
}

fn evaluateFixtures(
    allocator: std.mem.Allocator,
    options: Options,
    local_fixtures: LocalFixturesArtifact,
) !FixtureResult {
    var checks = std.ArrayList(FixtureCheck).empty;
    errdefer checks.deinit(allocator);

    try appendCheck(allocator, &checks, "local-fixtures-schema", if (std.mem.eql(u8, local_fixtures.schema, local_fixtures_schema) and local_fixtures.schema_version == 1) .pass else .fail, "source local fixtures schema is supported");
    try appendCheck(allocator, &checks, "local-fixtures-status", if (std.mem.eql(u8, local_fixtures.fixture_status, "ready") and local_fixtures.ready_for_next_branch) .pass else .fail, "source local fixtures are ready for NenDB handoff fixture work");
    try appendCheck(allocator, &checks, "local-fixtures-decision-approved", if (std.mem.eql(u8, local_fixtures.decision, "approve")) .pass else .fail, "source local fixtures decision approved the handoff");
    try appendCheck(allocator, &checks, "handoff-decision", if (options.reason.len > 0) .pass else .fail, "handoff decision includes a reason");
    try appendCheck(allocator, &checks, "decision-approved", if (options.decision == .approve) .pass else .fail, "handoff decision must approve the audit/remediation bridge handoff");
    try appendCheck(allocator, &checks, "authority-boundary", if (authorityLocalFixturesIntact(local_fixtures)) .pass else .fail, "source local fixtures and NenDB handoff fixture authority fields remain disabled");
    try appendCheck(allocator, &checks, "source-chain-linked", if (sourceChainLinked(local_fixtures)) .pass else .fail, "local fixtures link boundary proposal readiness and fixture JSON artifacts");
    try appendCheck(allocator, &checks, "local-fixtures-checks-passed", if (localFixturesChecksPassed(local_fixtures.checks)) .pass else .fail, "all required source local fixture checks passed");
    try appendCheck(allocator, &checks, "local-fixtures-verification-recorded", if (localFixturesVerificationRecorded(local_fixtures)) .pass else .fail, "source local fixtures recorded required verification command evidence");
    try appendCheck(allocator, &checks, "source-fixture-catalog-present", if (sourceFixtureCatalogPresent(local_fixtures.fixture_catalog)) .pass else .fail, "source local fixture catalog contains all required app-facing fixtures");
    try appendCheck(allocator, &checks, "nendb-handoff-catalog-present", if (nendbHandoffCatalogPresent()) .pass else .fail, "NenDB handoff fixture catalog contains required records");
    try appendCheck(allocator, &checks, "nendb-node-handoffs-present", if (nendbNodeHandoffsPresent()) .pass else .fail, "NenDB node handoff fixtures cover app-facing refs");
    try appendCheck(allocator, &checks, "nendb-edge-handoffs-present", if (nendbEdgeHandoffsPresent()) .pass else .fail, "NenDB edge handoff fixtures cover relationship refs");
    try appendCheck(allocator, &checks, "runtime-ref-handoff-covered", if (runtimeRefHandoffCovered(local_fixtures.fixture_catalog)) .pass else .fail, "worker and background runtime refs map to NenDB node handoff fixtures");
    try appendCheck(allocator, &checks, "agent-query-handoff-covered", if (agentQueryHandoffCovered(local_fixtures.fixture_catalog)) .pass else .fail, "bounded agent query refs map to NenDB handoff fixtures");
    try appendCheck(allocator, &checks, "audit-remediation-handoff-covered", if (auditRemediationHandoffCovered(local_fixtures.fixture_catalog)) .pass else .fail, "audit/remediation refs map to review-only NenDB handoff fixtures");
    try appendCheck(allocator, &checks, "solid-webui-handoff-covered", if (solidWebuiHandoffCovered(local_fixtures.fixture_catalog)) .pass else .fail, "SolidJS read-only preview refs map to handoff fixtures");
    try appendCheck(allocator, &checks, "ci-advisory-handoff-covered", if (ciAdvisoryHandoffCovered(local_fixtures.fixture_catalog)) .pass else .fail, "advisory CI refs map to handoff fixtures");
    try appendCheck(allocator, &checks, "handoff-validation-passed", if (handoffValidationPassed(local_fixtures.fixture_catalog)) .pass else .fail, "all NenDB handoff validation checks passed");
    try appendCheck(allocator, &checks, "handoff-verification-recorded", if (verifiedCommandsContainAll(options.verified_commands, required_verification_commands)) .pass else .fail, "handoff review recorded every required verification command");
    try appendCheck(allocator, &checks, "nendb-write-disabled", if (!local_fixtures.nendb_write_enabled and !nendb_write_enabled) .pass else .fail, "NenDB writes remain disabled");
    try appendCheck(allocator, &checks, "nendb-adapter-execution-disabled", if (!nendb_adapter_execution_enabled) .pass else .fail, "NenDB adapter execution remains disabled");
    try appendCheck(allocator, &checks, "durable-write-disabled", if (!local_fixtures.durable_write_enabled and !durable_write_enabled) .pass else .fail, "durable writes remain disabled");
    try appendCheck(allocator, &checks, "nendb-only-scope", if (nendbOnlyScope()) .pass else .fail, "durable direction remains future NenDB-only scope");
    try appendCheck(allocator, &checks, "solid-webui-scope", if (solidWebuiScope()) .pass else .fail, "workbench direction remains SolidJS inside webui-dev/zig-webui");

    const check_slice = try checks.toOwnedSlice(allocator);
    errdefer allocator.free(check_slice);
    const ready = allChecksPassed(check_slice);
    return .{
        .status = if (ready) .ready else .blocked,
        .ready_for_next_branch = ready,
        .checks = check_slice,
        .local_fixtures_summary = local_fixtures.boundary_summary,
        .source_boundary = local_fixtures.source_boundary,
        .source_proposal = local_fixtures.source_proposal,
        .source_readiness = local_fixtures.source_readiness,
        .source_fixtures = local_fixtures.source_fixtures,
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

fn authorityLocalFixturesIntact(local_fixtures: LocalFixturesArtifact) bool {
    return !local_fixtures.applied and
        std.mem.eql(u8, local_fixtures.mutation_authority, "none") and
        !local_fixtures.production_telemetry_ingestion and
        !local_fixtures.live_exporter_enabled and
        !local_fixtures.network_send_enabled and
        !local_fixtures.collector_endpoint_configured and
        !local_fixtures.otlp_serialization_enabled and
        !local_fixtures.durable_write_enabled and
        !local_fixtures.app_mutation_enabled and
        !local_fixtures.ci_gate_enabled and
        !local_fixtures.raw_payload_capture_enabled and
        !local_fixtures.app_config_write_enabled and
        !local_fixtures.app_data_write_enabled and
        !local_fixtures.deployment_mutation_enabled and
        !local_fixtures.nendb_write_enabled and
        !local_fixtures.app_runtime_integration_enabled and
        !local_fixtures.agent_query_live_projection_enabled and
        !local_fixtures.solid_webui_preview_enabled and
        local_fixtures.local_fixture_mode and
        !applied and
        std.mem.eql(u8, mutation_authority, "none") and
        !production_telemetry_ingestion and
        !live_exporter_enabled and
        !network_send_enabled and
        !collector_endpoint_configured and
        !otlp_serialization_enabled and
        !durable_write_enabled and
        !app_mutation_enabled and
        !ci_gate_enabled and
        !raw_payload_capture_enabled and
        !app_config_write_enabled and
        !app_data_write_enabled and
        !deployment_mutation_enabled and
        !nendb_write_enabled and
        !nendb_adapter_execution_enabled and
        !app_runtime_integration_enabled and
        !agent_query_live_projection_enabled and
        !solid_webui_preview_enabled and
        local_fixture_mode and
        nendb_handoff_fixture_mode;
}

fn sourceChainLinked(local_fixtures: LocalFixturesArtifact) bool {
    return local_fixtures.source_boundary.len > 0 and
        local_fixtures.source_proposal.len > 0 and
        local_fixtures.source_readiness.len > 0 and
        local_fixtures.source_fixtures.len > 0 and
        std.mem.endsWith(u8, local_fixtures.source_boundary, ".json") and
        std.mem.endsWith(u8, local_fixtures.source_proposal, ".json") and
        std.mem.endsWith(u8, local_fixtures.source_readiness, ".json") and
        std.mem.endsWith(u8, local_fixtures.source_fixtures, ".json");
}

fn localFixturesChecksPassed(checks: []const LocalFixturesCheck) bool {
    const required = [_][]const u8{
        "boundary-schema",
        "boundary-status",
        "boundary-decision-approved",
        "fixture-decision",
        "decision-approved",
        "authority-boundary",
        "source-chain-linked",
        "boundary-checks-passed",
        "boundary-contract-present",
        "projection-fixtures-present",
        "fixture-catalog-present",
        "runtime-ref-fixtures-present",
        "agent-query-fixture-present",
        "nendb-handoff-fixture-present",
        "audit-remediation-fixture-present",
        "solid-webui-fixture-present",
        "ci-advisory-fixture-present",
        "fixture-validation-passed",
        "boundary-verification-recorded",
        "fixture-verification-recorded",
        "nendb-only-scope",
        "solid-webui-scope",
    };
    for (required) |name| {
        if (!hasLocalFixturesCheck(checks, name, "pass")) return false;
    }
    for (checks) |check| {
        if (!std.mem.eql(u8, check.status, "pass")) return false;
    }
    return true;
}

fn hasLocalFixturesCheck(checks: []const LocalFixturesCheck, name: []const u8, status: []const u8) bool {
    for (checks) |check| {
        if (std.mem.eql(u8, check.name, name) and std.mem.eql(u8, check.status, status)) return true;
    }
    return false;
}

fn localFixturesVerificationRecorded(local_fixtures: LocalFixturesArtifact) bool {
    return local_fixtures.required_verification_commands.len > 0 and
        verifiedCommandsContainAll(local_fixtures.verified_commands, local_fixtures.required_verification_commands);
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

fn sourceFixtureCatalogPresent(fixtures: []const LocalFixture) bool {
    const required = [_][]const u8{
        "worker-request-runtime-ref-fixture",
        "background-job-runtime-ref-fixture",
        "agent-query-bounded-projection-fixture",
        "nendb-history-handoff-ref-fixture",
        "audit-remediation-review-link-fixture",
        "solid-webui-readonly-preview-fixture",
        "ci-advisory-artifact-preview-fixture",
    };
    for (required) |id| {
        if (!hasSourceFixture(fixtures, id)) return false;
    }
    return fixtures.len == required.len;
}

fn hasSourceFixture(fixtures: []const LocalFixture, id: []const u8) bool {
    for (fixtures) |fixture| {
        if (std.mem.eql(u8, fixture.id, id)) return true;
    }
    return false;
}

fn sourceFixtureHasOutputField(fixtures: []const LocalFixture, id: []const u8, field: []const u8) bool {
    for (fixtures) |fixture| {
        if (std.mem.eql(u8, fixture.id, id)) return containsString(fixture.output_fields, field);
    }
    return false;
}

fn sourceFixtureBlocksField(fixtures: []const LocalFixture, id: []const u8, field: []const u8) bool {
    for (fixtures) |fixture| {
        if (std.mem.eql(u8, fixture.id, id)) return containsString(fixture.blocked_fields, field);
    }
    return false;
}

fn nendbHandoffCatalogPresent() bool {
    const required = [_][]const u8{
        "nendb-worker-request-node-handoff-fixture",
        "nendb-background-job-node-handoff-fixture",
        "nendb-agent-query-projection-node-handoff-fixture",
        "nendb-audit-remediation-node-handoff-fixture",
        "nendb-solid-webui-preview-node-handoff-fixture",
        "nendb-ci-advisory-node-handoff-fixture",
        "nendb-runtime-to-agent-query-edge-handoff-fixture",
        "nendb-runtime-to-audit-remediation-edge-handoff-fixture",
        "nendb-artifact-preview-edge-handoff-fixture",
    };
    for (required) |id| {
        if (!hasHandoffFixture(id)) return false;
    }
    return nendb_handoff_fixtures.len == required.len;
}

fn nendbNodeHandoffsPresent() bool {
    return handoffKindPresent("nendb-worker-request-node-handoff-fixture", "node") and
        handoffKindPresent("nendb-background-job-node-handoff-fixture", "node") and
        handoffKindPresent("nendb-agent-query-projection-node-handoff-fixture", "node") and
        handoffKindPresent("nendb-audit-remediation-node-handoff-fixture", "node") and
        handoffKindPresent("nendb-solid-webui-preview-node-handoff-fixture", "node") and
        handoffKindPresent("nendb-ci-advisory-node-handoff-fixture", "node");
}

fn nendbEdgeHandoffsPresent() bool {
    return handoffKindPresent("nendb-runtime-to-agent-query-edge-handoff-fixture", "edge") and
        handoffKindPresent("nendb-runtime-to-audit-remediation-edge-handoff-fixture", "edge") and
        handoffKindPresent("nendb-artifact-preview-edge-handoff-fixture", "edge");
}

fn runtimeRefHandoffCovered(source_fixtures: []const LocalFixture) bool {
    return hasSourceFixture(source_fixtures, "worker-request-runtime-ref-fixture") and
        hasSourceFixture(source_fixtures, "background-job-runtime-ref-fixture") and
        sourceFixtureHasOutputField(source_fixtures, "worker-request-runtime-ref-fixture", "trace_id_ref") and
        sourceFixtureHasOutputField(source_fixtures, "worker-request-runtime-ref-fixture", "causal_event_ref") and
        sourceFixtureBlocksField(source_fixtures, "worker-request-runtime-ref-fixture", "raw_request_body") and
        sourceFixtureBlocksField(source_fixtures, "worker-request-runtime-ref-fixture", "app_mutation") and
        sourceFixtureHasOutputField(source_fixtures, "background-job-runtime-ref-fixture", "job_ref") and
        sourceFixtureBlocksField(source_fixtures, "background-job-runtime-ref-fixture", "raw_payload") and
        hasHandoffFixture("nendb-worker-request-node-handoff-fixture") and
        hasHandoffFixture("nendb-background-job-node-handoff-fixture");
}

fn agentQueryHandoffCovered(source_fixtures: []const LocalFixture) bool {
    return hasSourceFixture(source_fixtures, "agent-query-bounded-projection-fixture") and
        sourceFixtureHasOutputField(source_fixtures, "agent-query-bounded-projection-fixture", "trace_data_refs") and
        sourceFixtureHasOutputField(source_fixtures, "agent-query-bounded-projection-fixture", "finding_refs") and
        sourceFixtureHasOutputField(source_fixtures, "agent-query-bounded-projection-fixture", "next_query_refs") and
        sourceFixtureBlocksField(source_fixtures, "agent-query-bounded-projection-fixture", "unbounded_query") and
        sourceFixtureBlocksField(source_fixtures, "agent-query-bounded-projection-fixture", "raw_prompt") and
        hasHandoffFixture("nendb-agent-query-projection-node-handoff-fixture") and
        hasHandoffFixture("nendb-runtime-to-agent-query-edge-handoff-fixture");
}

fn auditRemediationHandoffCovered(source_fixtures: []const LocalFixture) bool {
    return hasSourceFixture(source_fixtures, "audit-remediation-review-link-fixture") and
        sourceFixtureHasOutputField(source_fixtures, "audit-remediation-review-link-fixture", "audit_chain_ref") and
        sourceFixtureHasOutputField(source_fixtures, "audit-remediation-review-link-fixture", "remediation_review_ref") and
        sourceFixtureBlocksField(source_fixtures, "audit-remediation-review-link-fixture", "mutation_proof_claim") and
        sourceFixtureBlocksField(source_fixtures, "audit-remediation-review-link-fixture", "auto_apply") and
        hasHandoffFixture("nendb-audit-remediation-node-handoff-fixture") and
        hasHandoffFixture("nendb-runtime-to-audit-remediation-edge-handoff-fixture");
}

fn solidWebuiHandoffCovered(source_fixtures: []const LocalFixture) bool {
    return hasSourceFixture(source_fixtures, "solid-webui-readonly-preview-fixture") and
        sourceFixtureHasOutputField(source_fixtures, "solid-webui-readonly-preview-fixture", "webui_sample_ref") and
        sourceFixtureHasOutputField(source_fixtures, "solid-webui-readonly-preview-fixture", "solid_view_ref") and
        sourceFixtureBlocksField(source_fixtures, "solid-webui-readonly-preview-fixture", "react_renderer") and
        sourceFixtureBlocksField(source_fixtures, "solid-webui-readonly-preview-fixture", "alternate_renderer") and
        hasHandoffFixture("nendb-solid-webui-preview-node-handoff-fixture");
}

fn ciAdvisoryHandoffCovered(source_fixtures: []const LocalFixture) bool {
    return hasSourceFixture(source_fixtures, "ci-advisory-artifact-preview-fixture") and
        sourceFixtureHasOutputField(source_fixtures, "ci-advisory-artifact-preview-fixture", "ci_artifact_ref") and
        sourceFixtureHasOutputField(source_fixtures, "ci-advisory-artifact-preview-fixture", "advisory_status_ref") and
        sourceFixtureBlocksField(source_fixtures, "ci-advisory-artifact-preview-fixture", "required_status_check") and
        sourceFixtureBlocksField(source_fixtures, "ci-advisory-artifact-preview-fixture", "ci_gate_enforcement") and
        hasHandoffFixture("nendb-ci-advisory-node-handoff-fixture") and
        hasHandoffFixture("nendb-artifact-preview-edge-handoff-fixture");
}

fn handoffValidationPassed(source_fixtures: []const LocalFixture) bool {
    return containsString(handoff_validation_checks, "source-local-fixtures-ready") and
        containsString(handoff_validation_checks, "source-authority-disabled") and
        containsString(handoff_validation_checks, "source-fixture-catalog-covered") and
        containsString(handoff_validation_checks, "nendb-node-handoff-fixtures-present") and
        containsString(handoff_validation_checks, "nendb-edge-handoff-fixtures-present") and
        containsString(handoff_validation_checks, "runtime-ref-handoff-covered") and
        containsString(handoff_validation_checks, "agent-query-handoff-covered") and
        containsString(handoff_validation_checks, "audit-remediation-handoff-covered") and
        containsString(handoff_validation_checks, "solid-webui-handoff-covered") and
        containsString(handoff_validation_checks, "ci-advisory-handoff-covered") and
        containsString(handoff_validation_checks, "nendb-write-disabled") and
        containsString(handoff_validation_checks, "nendb-adapter-execution-disabled") and
        containsString(handoff_validation_checks, "durable-write-disabled") and
        containsString(handoff_validation_checks, "raw-sensitive-fields-blocked") and
        containsString(handoff_validation_checks, "production-mutation-fields-blocked") and
        containsString(handoff_validation_checks, "non-nendb-scope-rejected") and
        containsString(handoff_validation_checks, "cockroach-scope-rejected") and
        containsString(handoff_validation_checks, "audit-remediation-bridge-next-only") and
        runtimeRefHandoffCovered(source_fixtures) and
        agentQueryHandoffCovered(source_fixtures) and
        auditRemediationHandoffCovered(source_fixtures) and
        solidWebuiHandoffCovered(source_fixtures) and
        ciAdvisoryHandoffCovered(source_fixtures);
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

fn hasHandoffFixture(id: []const u8) bool {
    for (nendb_handoff_fixtures) |fixture| {
        if (std.mem.eql(u8, fixture.id, id)) return true;
    }
    return false;
}

fn handoffKindPresent(id: []const u8, kind: []const u8) bool {
    for (nendb_handoff_fixtures) |fixture| {
        if (std.mem.eql(u8, fixture.id, id)) return std.mem.eql(u8, fixture.handoff_kind, kind);
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
    try appendJsonString(allocator, &output, app_facing_production_integration_nendb_handoff_fixtures_schema);
    try output.appendSlice(allocator, ",\n  \"schema_version\": 1,\n");
    try output.appendSlice(allocator, "  \"source_local_fixtures\": ");
    try appendJsonString(allocator, &output, options.local_fixtures_path);
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
    try output.appendSlice(allocator, ",\n  \"nendb_handoff_status\": ");
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
    try output.print(allocator, "  \"durable_write_enabled\": {},\n", .{durable_write_enabled});
    try output.print(allocator, "  \"app_mutation_enabled\": {},\n", .{app_mutation_enabled});
    try output.print(allocator, "  \"ci_gate_enabled\": {},\n", .{ci_gate_enabled});
    try output.print(allocator, "  \"raw_payload_capture_enabled\": {},\n", .{raw_payload_capture_enabled});
    try output.print(allocator, "  \"app_config_write_enabled\": {},\n", .{app_config_write_enabled});
    try output.print(allocator, "  \"app_data_write_enabled\": {},\n", .{app_data_write_enabled});
    try output.print(allocator, "  \"deployment_mutation_enabled\": {},\n", .{deployment_mutation_enabled});
    try output.print(allocator, "  \"nendb_write_enabled\": {},\n", .{nendb_write_enabled});
    try output.print(allocator, "  \"nendb_adapter_execution_enabled\": {},\n", .{nendb_adapter_execution_enabled});
    try output.print(allocator, "  \"app_runtime_integration_enabled\": {},\n", .{app_runtime_integration_enabled});
    try output.print(allocator, "  \"agent_query_live_projection_enabled\": {},\n", .{agent_query_live_projection_enabled});
    try output.print(allocator, "  \"solid_webui_preview_enabled\": {},\n", .{solid_webui_preview_enabled});
    try output.print(allocator, "  \"local_fixture_mode\": {},\n", .{local_fixture_mode});
    try output.print(allocator, "  \"nendb_handoff_fixture_mode\": {},\n", .{nendb_handoff_fixture_mode});
    try output.appendSlice(allocator, "  \"generated_by\": ");
    try appendJsonString(allocator, &output, generated_by);
    try output.appendSlice(allocator, ",\n  \"source_branch\": ");
    try appendJsonString(allocator, &output, source_branch);
    try output.appendSlice(allocator, ",\n  \"recommendation\": ");
    try appendJsonString(allocator, &output, recommendation);
    try output.appendSlice(allocator, ",\n  \"next_branch_if_ready\": ");
    try appendJsonString(allocator, &output, next_branch_if_ready);
    try output.appendSlice(allocator, ",\n  \"local_fixtures_summary\": ");
    try appendLocalFixturesSummaryJson(allocator, &output, result.local_fixtures_summary);
    try output.appendSlice(allocator, ",\n  \"checks\": ");
    try appendChecksJson(allocator, &output, result.checks);
    try output.appendSlice(allocator, ",\n  \"nendb_handoff_fixtures\": ");
    try appendNendbHandoffFixtureCatalogJson(allocator, &output, nendb_handoff_fixtures);
    try output.appendSlice(allocator, ",\n  \"handoff_validation_checks\": ");
    try appendStringArray(allocator, &output, handoff_validation_checks);
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

    try output.appendSlice(allocator, "zigeffect app-facing production integration nendb handoff fixtures\n");
    try output.print(allocator, "schema: {s}\n", .{app_facing_production_integration_nendb_handoff_fixtures_schema});
    try output.print(allocator, "source local fixtures: {s}\n", .{options.local_fixtures_path});
    try output.print(allocator, "source boundary: {s}\n", .{result.source_boundary});
    try output.print(allocator, "source proposal: {s}\n", .{result.source_proposal});
    try output.print(allocator, "source readiness: {s}\n", .{result.source_readiness});
    try output.print(allocator, "source fixtures: {s}\n", .{result.source_fixtures});
    try output.print(allocator, "decision: {s}\n", .{decisionText(options.decision)});
    try output.print(allocator, "nendb_handoff_status: {s}\n", .{fixtureStatusText(result.status)});
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
    try output.print(allocator, "durable write enabled: {}\n", .{durable_write_enabled});
    try output.print(allocator, "app mutation enabled: {}\n", .{app_mutation_enabled});
    try output.print(allocator, "ci gate enabled: {}\n", .{ci_gate_enabled});
    try output.print(allocator, "raw payload capture enabled: {}\n", .{raw_payload_capture_enabled});
    try output.print(allocator, "app config write enabled: {}\n", .{app_config_write_enabled});
    try output.print(allocator, "app data write enabled: {}\n", .{app_data_write_enabled});
    try output.print(allocator, "deployment mutation enabled: {}\n", .{deployment_mutation_enabled});
    try output.print(allocator, "nendb write enabled: {}\n", .{nendb_write_enabled});
    try output.print(allocator, "nendb adapter execution enabled: {}\n", .{nendb_adapter_execution_enabled});
    try output.print(allocator, "app runtime integration enabled: {}\n", .{app_runtime_integration_enabled});
    try output.print(allocator, "agent query live projection enabled: {}\n", .{agent_query_live_projection_enabled});
    try output.print(allocator, "solid webui preview enabled: {}\n", .{solid_webui_preview_enabled});
    try output.print(allocator, "local fixture mode: {}\n", .{local_fixture_mode});
    try output.print(allocator, "nendb handoff fixture mode: {}\n", .{nendb_handoff_fixture_mode});
    try output.print(allocator, "generated by: {s}\n", .{generated_by});
    try output.print(allocator, "source branch: {s}\n", .{source_branch});
    try output.print(allocator, "recommendation: {s}\n", .{recommendation});
    try output.print(allocator, "next branch if ready: {s}\n\n", .{next_branch_if_ready});

    try output.appendSlice(allocator, "local fixtures summary:\n");
    try output.print(allocator, "- source contracts: {d}\n", .{result.local_fixtures_summary.source_contract_count});
    try output.print(allocator, "- positive fixtures: {d}\n", .{result.local_fixtures_summary.positive_fixture_count});
    try output.print(allocator, "- negative fixtures: {d}\n", .{result.local_fixtures_summary.negative_fixture_count});
    try output.print(allocator, "- validation checks: {d}\n\n", .{result.local_fixtures_summary.validation_check_count});

    try output.appendSlice(allocator, "checks:\n");
    for (result.checks) |check| {
        try output.print(allocator, "- {s}: {s} - {s}\n", .{ check.name, checkStatusText(check.status), check.detail });
    }
    try output.append(allocator, '\n');

    try appendNendbHandoffFixtureCatalogText(allocator, &output, nendb_handoff_fixtures);
    try appendTextList(allocator, &output, "handoff validation checks", handoff_validation_checks);
    try appendTextList(allocator, &output, "implementation gates", implementation_gates);
    try appendTextList(allocator, &output, "non-goals", non_goals);
    try appendTextList(allocator, &output, "blocked claims", blocked_claims);
    try appendTextList(allocator, &output, "required verification commands", required_verification_commands);
    try appendTextList(allocator, &output, "verified commands", options.verified_commands);
    try appendTextList(allocator, &output, "agent guidance", agentGuidance(result.status));

    return output.toOwnedSlice(allocator);
}

fn appendLocalFixturesSummaryJson(allocator: std.mem.Allocator, output: *std.ArrayList(u8), summary: LocalFixturesSummary) !void {
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

fn appendNendbHandoffFixtureCatalogJson(allocator: std.mem.Allocator, output: *std.ArrayList(u8), fixtures: []const NendbHandoffFixture) !void {
    try output.append(allocator, '[');
    for (fixtures, 0..) |fixture, index| {
        if (index > 0) try output.appendSlice(allocator, ", ");
        try output.appendSlice(allocator, "{ \"id\": ");
        try appendJsonString(allocator, output, fixture.id);
        try output.appendSlice(allocator, ", \"source_fixture\": ");
        try appendJsonString(allocator, output, fixture.source_fixture);
        try output.appendSlice(allocator, ", \"target_schema\": ");
        try appendJsonString(allocator, output, fixture.target_schema);
        try output.appendSlice(allocator, ", \"handoff_kind\": ");
        try appendJsonString(allocator, output, fixture.handoff_kind);
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

fn appendNendbHandoffFixtureCatalogText(allocator: std.mem.Allocator, output: *std.ArrayList(u8), fixtures: []const NendbHandoffFixture) !void {
    try output.appendSlice(allocator, "nendb handoff fixtures:\n");
    for (fixtures) |fixture| {
        try output.print(allocator, "- {s}: {s} -> {s} ({s}, {s})\n", .{ fixture.id, fixture.source_fixture, fixture.target_schema, fixture.handoff_kind, fixture.label });
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
            "Ready app-facing NenDB handoff fixtures permit starting the audit/remediation bridge branch only.",
            "Cite source local fixtures checks fixture catalog NenDB handoff catalog validation checks and verification commands.",
            "Do not infer app runtime integration live agent projection raw payload capture app mutation NenDB writes NenDB adapter execution Cockroach scope CI enforcement deployment mutation or applied=true.",
        },
        .blocked => &.{
            "Blocked app-facing NenDB handoff fixtures must not start the audit/remediation bridge branch.",
            "Repair source local fixture evidence handoff catalog coverage or verification command evidence first.",
            "Do not infer production app integration or durable write approval from blocked handoff evidence.",
        },
    };
}

fn usage() []const u8 {
    return "usage: zig build causal-app-facing-production-integration-nendb-handoff-fixtures -- --from-local-fixtures <local-fixtures.json> approve|reject --reason <reason> [--by <actor>] [--policy <policy>] [--verified-command <command>]... [--out-prefix <path-prefix>]\n";
}

fn failUsage(err: anyerror) noreturn {
    std.debug.print("causal-app-facing-production-integration-nendb-handoff-fixtures error: {s}\n{s}", .{ @errorName(err), usage() });
    std.process.exit(2);
}

fn readRequiredArtifact(io: std.Io, allocator: std.mem.Allocator, path: []const u8) ![]const u8 {
    return std.Io.Dir.cwd().readFileAlloc(io, path, allocator, .limited(1024 * 1024)) catch |err| switch (err) {
        error.FileNotFound => error.MissingLocalFixturesInput,
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
    const source_local_fixtures_json = try readRequiredArtifact(init.io, allocator, options.local_fixtures_path);
    defer allocator.free(source_local_fixtures_json);

    const reports = try formatReports(allocator, .{
        .options = options,
        .source_local_fixtures_json = source_local_fixtures_json,
    });
    defer reports.deinit(allocator);

    const paths = try outputPathsForOptions(allocator, options);
    defer paths.deinit(allocator);

    try writeArtifact(init.io, paths.json_path, reports.json);
    try writeArtifact(init.io, paths.text_path, reports.text);
    std.debug.print("{s}", .{reports.text});
}

const required_verification_commands: []const []const u8 = &.{
    "zig build causal-app-facing-production-integration-local-fixtures",
    "zig build causal-schema-governance -- --format json",
    "zig build causal-production-hardening-backlog -- --format json",
    "zig build examples",
    "zig build test",
};

const nendb_handoff_fixtures: []const NendbHandoffFixture = &.{
    .{ .id = "nendb-worker-request-node-handoff-fixture", .source_fixture = "worker-request-runtime-ref-fixture", .target_schema = "zigeffect.causal.nendb_node.v1", .handoff_kind = "node", .label = "causal.app.worker_request.runtime_ref", .retained_fields = &.{ "trace_id_ref", "causal_event_ref", "route_ref", "redaction_state", "sample_state" }, .blocked_fields = &.{ "raw_request_body", "headers", "credentials", "raw_pii", "app_mutation", "nendb_write" } },
    .{ .id = "nendb-background-job-node-handoff-fixture", .source_fixture = "background-job-runtime-ref-fixture", .target_schema = "zigeffect.causal.nendb_node.v1", .handoff_kind = "node", .label = "causal.app.background_job.runtime_ref", .retained_fields = &.{ "job_ref", "trace_id_ref", "causal_event_ref", "retry_ref", "redaction_state" }, .blocked_fields = &.{ "raw_payload", "queue_body", "credentials", "app_mutation", "nendb_write" } },
    .{ .id = "nendb-agent-query-projection-node-handoff-fixture", .source_fixture = "agent-query-bounded-projection-fixture", .target_schema = "zigeffect.causal.nendb_node.v1", .handoff_kind = "node", .label = "causal.app.agent_query.bounded_projection", .retained_fields = &.{ "query_ref", "trace_data_refs", "finding_refs", "next_query_refs", "truncation_state", "redaction_state" }, .blocked_fields = &.{ "raw_payload_scrape", "unbounded_query", "raw_prompt", "raw_response", "nendb_adapter_execution" } },
    .{ .id = "nendb-audit-remediation-node-handoff-fixture", .source_fixture = "audit-remediation-review-link-fixture", .target_schema = "zigeffect.causal.nendb_node.v1", .handoff_kind = "node", .label = "causal.app.audit_remediation.review_ref", .retained_fields = &.{ "audit_chain_ref", "remediation_review_ref", "comparison_ref", "evidence_state=review-only" }, .blocked_fields = &.{ "mutation_proof_claim", "auto_apply", "fixed_claim", "deployed_claim", "nendb_write" } },
    .{ .id = "nendb-solid-webui-preview-node-handoff-fixture", .source_fixture = "solid-webui-readonly-preview-fixture", .target_schema = "zigeffect.causal.nendb_node.v1", .handoff_kind = "node", .label = "causal.app.solid_webui.readonly_preview", .retained_fields = &.{ "webui_sample_ref", "solid_view_ref", "read_only_state", "selection_ref", "artifact_ref" }, .blocked_fields = &.{ "live_dashboard_host", "app_mutation_button", "react_renderer", "alternate_renderer", "production_app_view" } },
    .{ .id = "nendb-ci-advisory-node-handoff-fixture", .source_fixture = "ci-advisory-artifact-preview-fixture", .target_schema = "zigeffect.causal.nendb_node.v1", .handoff_kind = "node", .label = "causal.app.ci.advisory_artifact_ref", .retained_fields = &.{ "ci_artifact_ref", "advisory_status_ref", "local_report_ref", "non_blocking_state" }, .blocked_fields = &.{ "required_status_check", "ci_gate_enforcement", "workflow_mutation", "github_api_mutation" } },
    .{ .id = "nendb-runtime-to-agent-query-edge-handoff-fixture", .source_fixture = "worker-request-runtime-ref-fixture+agent-query-bounded-projection-fixture", .target_schema = "zigeffect.causal.nendb_edge.v1", .handoff_kind = "edge", .label = "causal.app.runtime_to_agent_query", .retained_fields = &.{ "from_trace_ref", "to_query_ref", "causal_event_ref", "finding_refs", "next_query_refs" }, .blocked_fields = &.{ "raw_prompt", "raw_response", "raw_payload_join", "source_database_read" } },
    .{ .id = "nendb-runtime-to-audit-remediation-edge-handoff-fixture", .source_fixture = "worker-request-runtime-ref-fixture+audit-remediation-review-link-fixture", .target_schema = "zigeffect.causal.nendb_edge.v1", .handoff_kind = "edge", .label = "causal.app.runtime_to_audit_remediation", .retained_fields = &.{ "from_trace_ref", "to_audit_chain_ref", "remediation_review_ref", "comparison_ref" }, .blocked_fields = &.{ "mutation_proof_claim", "auto_apply", "deployed_claim", "source_database_read" } },
    .{ .id = "nendb-artifact-preview-edge-handoff-fixture", .source_fixture = "solid-webui-readonly-preview-fixture+ci-advisory-artifact-preview-fixture", .target_schema = "zigeffect.causal.nendb_edge.v1", .handoff_kind = "edge", .label = "causal.app.artifact_preview", .retained_fields = &.{ "from_artifact_ref", "to_webui_sample_ref", "ci_artifact_ref", "advisory_status_ref" }, .blocked_fields = &.{ "workflow_mutation", "required_status_check", "live_dashboard_host", "app_mutation_button" } },
};

const handoff_validation_checks: []const []const u8 = &.{
    "source-local-fixtures-ready",
    "source-authority-disabled",
    "source-fixture-catalog-covered",
    "nendb-node-handoff-fixtures-present",
    "nendb-edge-handoff-fixtures-present",
    "runtime-ref-handoff-covered",
    "agent-query-handoff-covered",
    "audit-remediation-handoff-covered",
    "solid-webui-handoff-covered",
    "ci-advisory-handoff-covered",
    "nendb-write-disabled",
    "nendb-adapter-execution-disabled",
    "durable-write-disabled",
    "raw-sensitive-fields-blocked",
    "production-mutation-fields-blocked",
    "non-nendb-scope-rejected",
    "cockroach-scope-rejected",
    "audit-remediation-bridge-next-only",
};

const implementation_gates: []const []const u8 = &.{
    "source app-facing local fixtures artifact is ready",
    "source local fixture checks and verification commands remain pass",
    "NenDB handoff fixtures emit node and edge records only",
    "NenDB adapter execution remains disabled",
    "NenDB and durable writes remain disabled",
    "app runtime integration and live agent projection remain disabled",
    "audit/remediation bridge must review this artifact before linking comparisons",
    "SolidJS workbench preview remains read-only and local",
    "CI artifacts remain advisory and do not enforce gates",
};

const non_goals: []const []const u8 = &.{
    "Live app runtime integration",
    "Live agent query projection over production app data",
    "Raw app payload capture",
    "App runtime mutation authority",
    "App config writes",
    "App data writes",
    "Deployment rollout rollback or registry mutation",
    "Live production telemetry ingestion",
    "Durable production writes",
    "NenDB production writes",
    "NenDB adapter execution",
    "Non-NenDB durable adapter work",
    "Cockroach adapter work",
    "CI enforcement gates or required status checks",
    "Hosted dashboard live SolidJS preview or production app view",
    "React or alternate renderer work",
    "Fixed deployed integrated healthy or applied app claim",
};

const blocked_claims: []const []const u8 = &.{
    "app-runtime-integration-enabled",
    "agent-query-live-projection-enabled",
    "solid-webui-preview-enabled",
    "app-mutation-enabled",
    "raw-payload-capture-enabled",
    "app-config-write",
    "app-data-write",
    "deployment-mutation",
    "durable-production-write-enabled",
    "nendb-write-enabled",
    "nendb-adapter-execution-enabled",
    "non-nendb-durable-storage",
    "cockroach-adapter-work",
    "ci-required-status-check",
    "react-or-alternate-renderer",
    "mutation-authority-granted",
    "applied-true",
};

test "app-facing nendb handoff constants preserve the branch boundary" {
    try std.testing.expectEqualStrings("zigeffect.causal.app-facing-production-integration-nendb-handoff-fixtures.v1", app_facing_production_integration_nendb_handoff_fixtures_schema);
    try std.testing.expectEqual(@as(u32, 1), app_facing_production_integration_nendb_handoff_fixtures_schema_version);
    try std.testing.expectEqualStrings("codex/zigeffect-causal-app-facing-production-integration-nendb-handoff-fixtures", source_branch);
    try std.testing.expectEqualStrings("start-app-facing-production-integration-audit-remediation-bridge", recommendation);
    try std.testing.expectEqualStrings("codex/zigeffect-causal-app-facing-production-integration-audit-remediation-bridge", next_branch_if_ready);
}

test "app-facing nendb handoff options require local fixtures json and reason" {
    try std.testing.expectError(error.MissingLocalFixturesPath, parseOptions(std.testing.allocator, &.{"tool"}));
    try std.testing.expectError(error.InvalidLocalFixturesPath, parseOptions(std.testing.allocator, &.{ "tool", "--from-local-fixtures", "local-fixtures.txt", "approve", "--reason", "reviewed" }));
    try std.testing.expectError(error.MissingReason, parseOptions(std.testing.allocator, &.{ "tool", "--from-local-fixtures", "local-fixtures.json", "approve" }));
}

test "app-facing nendb handoff options parse successful approval review" {
    const parsed = try parseOptions(std.testing.allocator, &.{ "tool", "--from-local-fixtures", "local-fixtures.json", "approve", "--reason", "reviewed", "--verified-command", "zig build test" });
    defer parsed.deinit(std.testing.allocator);

    try std.testing.expectEqualStrings("local-fixtures.json", parsed.local_fixtures_path);
    try std.testing.expectEqual(Decision.approve, parsed.decision);
    try std.testing.expectEqualStrings("reviewed", parsed.reason);
    try std.testing.expectEqual(@as(usize, 1), parsed.verified_commands.len);
}

test "app-facing nendb handoff output paths append handoff suffix" {
    const parsed = try parseOptions(std.testing.allocator, &.{ "tool", "--from-local-fixtures", "local-fixtures.json", "approve", "--reason", "reviewed" });
    defer parsed.deinit(std.testing.allocator);

    const paths = try outputPathsForOptions(std.testing.allocator, parsed);
    defer paths.deinit(std.testing.allocator);

    try std.testing.expectEqualStrings("local-fixtures-nendb-handoff-fixtures.json", paths.json_path);
    try std.testing.expectEqualStrings("local-fixtures-nendb-handoff-fixtures.txt", paths.text_path);
}

test "app-facing nendb handoff ready report preserves record-only authority" {
    const reports = try formatReports(std.testing.allocator, .{
        .options = .{
            .local_fixtures_path = "local-fixtures.json",
            .decision = .approve,
            .reason = "ready local app-facing fixtures reviewed for NenDB handoff fixtures",
            .verified_commands = handoff_verified_commands_for_tests,
        },
        .source_local_fixtures_json = sample_local_fixtures_json,
    });
    defer reports.deinit(std.testing.allocator);

    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"schema\": \"zigeffect.causal.app-facing-production-integration-nendb-handoff-fixtures.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"nendb_handoff_status\": \"ready\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"ready_for_next_branch\": true") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"nendb_write_enabled\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"nendb_adapter_execution_enabled\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"nendb_handoff_fixture_mode\": true") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"nendb_handoff_fixtures\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "nendb-worker-request-node-handoff-fixture") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "nendb-agent-query-projection-node-handoff-fixture") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "nendb-runtime-to-agent-query-edge-handoff-fixture") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.text, "nendb_handoff_status: ready") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.text, "nendb adapter execution enabled: false") != null);
}

test "app-facing nendb handoff reject report remains blocked and authority-disabled" {
    const reports = try formatReports(std.testing.allocator, .{
        .options = .{
            .local_fixtures_path = "local-fixtures.json",
            .decision = .reject,
            .reason = "negative nendb handoff path",
        },
        .source_local_fixtures_json = sample_local_fixtures_json,
    });
    defer reports.deinit(std.testing.allocator);

    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"nendb_handoff_status\": \"blocked\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"ready_for_next_branch\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"applied\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"nendb_write_enabled\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"nendb_adapter_execution_enabled\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"durable_write_enabled\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.text, "nendb_handoff_status: blocked") != null);
}

const handoff_verified_commands_for_tests: []const []const u8 = &.{
    "zig build causal-app-facing-production-integration-local-fixtures",
    "zig build causal-schema-governance -- --format json",
    "zig build causal-production-hardening-backlog -- --format json",
    "zig build examples",
    "zig build test",
};

const sample_local_fixtures_json =
    \\{
    \\  "schema": "zigeffect.causal.app-facing-production-integration-local-fixtures.v1",
    \\  "schema_version": 1,
    \\  "source_boundary": "../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures-readiness-review-implementation-proposal-app-facing-boundary.json",
    \\  "source_proposal": "../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures-readiness-review-implementation-proposal.json",
    \\  "source_readiness": "../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures-readiness-review.json",
    \\  "source_fixtures": "../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures.json",
    \\  "decision": "approve",
    \\  "fixture_status": "ready",
    \\  "ready_for_next_branch": true,
    \\  "applied": false,
    \\  "mutation_authority": "none",
    \\  "production_telemetry_ingestion": false,
    \\  "live_exporter_enabled": false,
    \\  "network_send_enabled": false,
    \\  "collector_endpoint_configured": false,
    \\  "otlp_serialization_enabled": false,
    \\  "durable_write_enabled": false,
    \\  "app_mutation_enabled": false,
    \\  "ci_gate_enabled": false,
    \\  "raw_payload_capture_enabled": false,
    \\  "app_config_write_enabled": false,
    \\  "app_data_write_enabled": false,
    \\  "deployment_mutation_enabled": false,
    \\  "nendb_write_enabled": false,
    \\  "app_runtime_integration_enabled": false,
    \\  "agent_query_live_projection_enabled": false,
    \\  "solid_webui_preview_enabled": false,
    \\  "local_fixture_mode": true,
    \\  "boundary_summary": { "source_contract_count": 6, "positive_fixture_count": 7, "negative_fixture_count": 15, "validation_check_count": 11 },
    \\  "checks": [
    \\    { "name": "boundary-schema", "status": "pass", "detail": "ok" },
    \\    { "name": "boundary-status", "status": "pass", "detail": "ok" },
    \\    { "name": "boundary-decision-approved", "status": "pass", "detail": "ok" },
    \\    { "name": "fixture-decision", "status": "pass", "detail": "ok" },
    \\    { "name": "decision-approved", "status": "pass", "detail": "ok" },
    \\    { "name": "authority-boundary", "status": "pass", "detail": "ok" },
    \\    { "name": "source-chain-linked", "status": "pass", "detail": "ok" },
    \\    { "name": "boundary-checks-passed", "status": "pass", "detail": "ok" },
    \\    { "name": "boundary-contract-present", "status": "pass", "detail": "ok" },
    \\    { "name": "projection-fixtures-present", "status": "pass", "detail": "ok" },
    \\    { "name": "fixture-catalog-present", "status": "pass", "detail": "ok" },
    \\    { "name": "runtime-ref-fixtures-present", "status": "pass", "detail": "ok" },
    \\    { "name": "agent-query-fixture-present", "status": "pass", "detail": "ok" },
    \\    { "name": "nendb-handoff-fixture-present", "status": "pass", "detail": "ok" },
    \\    { "name": "audit-remediation-fixture-present", "status": "pass", "detail": "ok" },
    \\    { "name": "solid-webui-fixture-present", "status": "pass", "detail": "ok" },
    \\    { "name": "ci-advisory-fixture-present", "status": "pass", "detail": "ok" },
    \\    { "name": "fixture-validation-passed", "status": "pass", "detail": "ok" },
    \\    { "name": "boundary-verification-recorded", "status": "pass", "detail": "ok" },
    \\    { "name": "fixture-verification-recorded", "status": "pass", "detail": "ok" },
    \\    { "name": "nendb-only-scope", "status": "pass", "detail": "ok" },
    \\    { "name": "solid-webui-scope", "status": "pass", "detail": "ok" }
    \\  ],
    \\  "fixture_catalog": [
    \\    { "id": "worker-request-runtime-ref-fixture", "source_boundary_label": "worker-request-runtime-ref-boundary", "input_ref": "worker-request-causal-event-ref", "output_artifact": "worker-request-runtime-ref-local-fixture", "output_fields": ["trace_id_ref", "causal_event_ref"], "blocked_fields": ["raw_request_body", "app_mutation"] },
    \\    { "id": "background-job-runtime-ref-fixture", "source_boundary_label": "background-job-runtime-ref-boundary", "input_ref": "background-job-causal-event-ref", "output_artifact": "background-job-runtime-ref-local-fixture", "output_fields": ["job_ref", "retry_ref"], "blocked_fields": ["raw_payload", "app_mutation"] },
    \\    { "id": "agent-query-bounded-projection-fixture", "source_boundary_label": "agent-query-bounded-projection-boundary", "input_ref": "agent-query-request-ref", "output_artifact": "agent-query-bounded-projection-local-fixture", "output_fields": ["trace_data_refs", "finding_refs", "next_query_refs", "truncation_state"], "blocked_fields": ["raw_payload_scrape", "unbounded_query", "raw_prompt", "raw_response"] },
    \\    { "id": "nendb-history-handoff-ref-fixture", "source_boundary_label": "nendb-history-handoff-ref-boundary", "input_ref": "nendb-history-handoff-request-ref", "output_artifact": "nendb-history-handoff-ref-local-fixture", "output_fields": ["nendb_node_ref", "nendb_edge_ref", "handoff_state=ref-only"], "blocked_fields": ["nendb_write", "production_history_mutation", "cockroach_adapter"] },
    \\    { "id": "audit-remediation-review-link-fixture", "source_boundary_label": "audit-remediation-review-link-boundary", "input_ref": "audit-remediation-review-request-ref", "output_artifact": "audit-remediation-review-link-local-fixture", "output_fields": ["audit_chain_ref", "remediation_review_ref", "evidence_state=review-only"], "blocked_fields": ["mutation_proof_claim", "auto_apply", "deployed_claim"] },
    \\    { "id": "solid-webui-readonly-preview-fixture", "source_boundary_label": "solid-webui-readonly-handoff-boundary", "input_ref": "solid-webui-preview-request-ref", "output_artifact": "solid-webui-readonly-preview-local-fixture", "output_fields": ["webui_sample_ref", "solid_view_ref", "read_only_state"], "blocked_fields": ["live_dashboard_host", "app_mutation_button", "react_renderer", "alternate_renderer"] },
    \\    { "id": "ci-advisory-artifact-preview-fixture", "source_boundary_label": "ci_state=advisory-artifacts-only", "input_ref": "ci-advisory-artifact-request-ref", "output_artifact": "ci-advisory-artifact-preview-local-fixture", "output_fields": ["ci_artifact_ref", "advisory_status_ref", "non_blocking_state"], "blocked_fields": ["required_status_check", "ci_gate_enforcement", "workflow_mutation", "github_api_mutation"] }
    \\  ],
    \\  "required_verification_commands": ["zig build causal-app-facing-production-integration-boundary"],
    \\  "verified_commands": ["zig build causal-app-facing-production-integration-boundary"]
    \\}
;
