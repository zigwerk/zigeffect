const std = @import("std");

pub const app_facing_production_integration_audit_remediation_bridge_schema = "zigeffect.causal.app-facing-production-integration-audit-remediation-bridge.v1";
pub const app_facing_production_integration_audit_remediation_bridge_schema_version: u32 = 1;
pub const source_branch = "codex/zigeffect-causal-app-facing-production-integration-audit-remediation-bridge";
pub const recommendation = "start-app-facing-production-integration-solid-webui-readonly-preview";
pub const next_branch_if_ready = "codex/zigeffect-causal-app-facing-production-integration-solid-webui-readonly-preview";

const handoff_fixtures_schema = "zigeffect.causal.app-facing-production-integration-nendb-handoff-fixtures.v1";
const generated_by = "causal-app-facing-production-integration-audit-remediation-bridge";
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
const audit_remediation_bridge_mode = true;
const mutation_proof_claim_enabled = false;
const auto_apply_enabled = false;
const production_health_claim_enabled = false;

const Decision = enum { approve, reject };
const BridgeStatus = enum { ready, blocked };
const CheckStatus = enum { pass, fail };

const Options = struct {
    handoff_path: []const u8,
    decision: Decision,
    reviewed_by: []const u8 = "audit-remediation-bridge-reviewer",
    policy: []const u8 = "manual-app-facing-production-integration-audit-remediation-bridge",
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
    if (args.len < 2) return error.MissingHandoffPath;
    if (!std.mem.eql(u8, args[1], "--from-handoff")) return error.UnknownFlag;
    if (args.len < 3) return error.MissingHandoffPath;
    const handoff_path = args[2];
    if (!std.mem.endsWith(u8, handoff_path, ".json")) return error.InvalidHandoffPath;
    if (args.len < 4) return error.MissingDecision;
    const decision = try parseDecision(args[3]);

    var reviewed_by: []const u8 = "audit-remediation-bridge-reviewer";
    var policy: []const u8 = "manual-app-facing-production-integration-audit-remediation-bridge";
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
        .handoff_path = handoff_path,
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
        if (!std.mem.endsWith(u8, options.handoff_path, ".json")) return error.InvalidHandoffPath;
        const base = options.handoff_path[0 .. options.handoff_path.len - ".json".len];
        break :blk try std.fmt.allocPrint(allocator, "{s}-audit-remediation-bridge", .{base});
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

fn bridgeStatusText(status: BridgeStatus) []const u8 {
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

const BridgeInput = struct {
    options: Options,
    source_handoff_json: []const u8,
};

const BridgeReports = struct {
    json: []const u8,
    text: []const u8,

    fn deinit(self: BridgeReports, allocator: std.mem.Allocator) void {
        allocator.free(self.json);
        allocator.free(self.text);
    }
};

const HandoffCheck = struct {
    name: []const u8,
    status: []const u8,
    detail: []const u8 = "",
};

const HandoffFixture = struct {
    id: []const u8,
    source_fixture: []const u8 = "",
    target_schema: []const u8 = "",
    handoff_kind: []const u8 = "",
    label: []const u8 = "",
    retained_fields: []const []const u8 = &.{},
    blocked_fields: []const []const u8 = &.{},
};

const HandoffArtifact = struct {
    schema: []const u8,
    schema_version: u32,
    source_boundary: []const u8 = "",
    source_proposal: []const u8 = "",
    source_readiness: []const u8 = "",
    source_fixtures: []const u8 = "",
    decision: []const u8,
    nendb_handoff_status: []const u8,
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
    nendb_adapter_execution_enabled: bool,
    app_runtime_integration_enabled: bool,
    agent_query_live_projection_enabled: bool,
    solid_webui_preview_enabled: bool,
    local_fixture_mode: bool,
    nendb_handoff_fixture_mode: bool,
    checks: []const HandoffCheck = &.{},
    nendb_handoff_fixtures: []const HandoffFixture = &.{},
    handoff_validation_checks: []const []const u8 = &.{},
    required_verification_commands: []const []const u8 = &.{},
    verified_commands: []const []const u8 = &.{},
};

const BridgeRecord = struct {
    id: []const u8,
    source_handoff_fixture: []const u8,
    audit_ref: []const u8,
    remediation_ref: []const u8,
    bridge_kind: []const u8,
    review_state: []const u8,
    retained_refs: []const []const u8,
    blocked_claims: []const []const u8,
};

const BridgeCheck = struct {
    name: []const u8,
    status: CheckStatus,
    detail: []const u8,
};

const BridgeResult = struct {
    status: BridgeStatus,
    ready_for_next_branch: bool,
    checks: []const BridgeCheck,
    source_boundary: []const u8,
    source_proposal: []const u8,
    source_readiness: []const u8,
    source_fixtures: []const u8,

    fn deinit(self: BridgeResult, allocator: std.mem.Allocator) void {
        if (self.checks.len > 0) allocator.free(self.checks);
    }
};

fn formatReports(allocator: std.mem.Allocator, input: BridgeInput) !BridgeReports {
    var parsed = try std.json.parseFromSlice(HandoffArtifact, allocator, input.source_handoff_json, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();

    const result = try evaluateBridge(allocator, input.options, parsed.value);
    defer result.deinit(allocator);

    const json = try formatBridgeJson(allocator, input.options, result);
    errdefer allocator.free(json);
    const text = try formatBridgeText(allocator, input.options, result);
    errdefer allocator.free(text);

    return .{ .json = json, .text = text };
}

pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    const options = parseOptions(init.gpa, args) catch |err| failUsage(err);
    defer options.deinit(init.gpa);
    run(init, options) catch |err| switch (err) {
        error.MissingHandoffInput => failUsage(err),
        else => return err,
    };
}

fn evaluateBridge(
    allocator: std.mem.Allocator,
    options: Options,
    handoff: HandoffArtifact,
) !BridgeResult {
    var checks = std.ArrayList(BridgeCheck).empty;
    errdefer checks.deinit(allocator);

    try appendCheck(allocator, &checks, "handoff-schema", if (std.mem.eql(u8, handoff.schema, handoff_fixtures_schema) and handoff.schema_version == 1) .pass else .fail, "source handoff fixture schema is supported");
    try appendCheck(allocator, &checks, "handoff-status", if (std.mem.eql(u8, handoff.nendb_handoff_status, "ready") and handoff.ready_for_next_branch) .pass else .fail, "source handoff fixture artifact is ready");
    try appendCheck(allocator, &checks, "handoff-decision-approved", if (std.mem.eql(u8, handoff.decision, "approve")) .pass else .fail, "source handoff fixture decision approved the bridge");
    try appendCheck(allocator, &checks, "bridge-decision", if (options.reason.len > 0) .pass else .fail, "bridge decision includes a reason");
    try appendCheck(allocator, &checks, "decision-approved", if (options.decision == .approve) .pass else .fail, "bridge decision must approve the SolidJS read-only preview handoff");
    try appendCheck(allocator, &checks, "authority-boundary", if (authorityHandoffIntact(handoff)) .pass else .fail, "source handoff and bridge authority fields remain disabled");
    try appendCheck(allocator, &checks, "source-chain-linked", if (sourceChainLinked(handoff)) .pass else .fail, "source handoff links boundary proposal readiness and fixture JSON artifacts");
    try appendCheck(allocator, &checks, "handoff-checks-passed", if (handoffChecksPassed(handoff.checks)) .pass else .fail, "all required source handoff checks passed");
    try appendCheck(allocator, &checks, "handoff-verification-recorded", if (handoffVerificationRecorded(handoff)) .pass else .fail, "source handoff recorded required verification command evidence");
    try appendCheck(allocator, &checks, "handoff-catalog-present", if (handoffCatalogPresent(handoff.nendb_handoff_fixtures)) .pass else .fail, "source handoff catalog contains all required records");
    try appendCheck(allocator, &checks, "audit-remediation-handoff-present", if (auditRemediationHandoffPresent(handoff.nendb_handoff_fixtures)) .pass else .fail, "audit/remediation handoff fixture is present");
    try appendCheck(allocator, &checks, "audit-chain-comparison-ref-present", if (auditChainComparisonRefPresent(handoff.nendb_handoff_fixtures)) .pass else .fail, "audit chain and comparison refs are retained");
    try appendCheck(allocator, &checks, "remediation-review-ref-present", if (remediationReviewRefPresent(handoff.nendb_handoff_fixtures)) .pass else .fail, "remediation review refs are retained");
    try appendCheck(allocator, &checks, "runtime-remediation-edge-present", if (runtimeRemediationEdgePresent(handoff.nendb_handoff_fixtures)) .pass else .fail, "runtime to remediation edge handoff is present");
    try appendCheck(allocator, &checks, "agent-query-remediation-edge-present", if (agentQueryRemediationEdgePresent(handoff.nendb_handoff_fixtures)) .pass else .fail, "agent query handoff refs can link to remediation next queries");
    try appendCheck(allocator, &checks, "solid-webui-review-preview-covered", if (solidWebuiReviewPreviewCovered(handoff.nendb_handoff_fixtures)) .pass else .fail, "SolidJS read-only preview handoff refs are covered");
    try appendCheck(allocator, &checks, "ci-advisory-remediation-covered", if (ciAdvisoryRemediationCovered(handoff.nendb_handoff_fixtures)) .pass else .fail, "CI advisory refs are covered");
    try appendCheck(allocator, &checks, "bridge-catalog-present", if (bridgeCatalogPresent()) .pass else .fail, "audit/remediation bridge catalog contains required records");
    try appendCheck(allocator, &checks, "bridge-validation-passed", if (bridgeValidationPassed(handoff)) .pass else .fail, "all bridge validation checks passed");
    try appendCheck(allocator, &checks, "bridge-verification-recorded", if (verifiedCommandsContainAll(options.verified_commands, required_verification_commands)) .pass else .fail, "bridge review recorded every required verification command");
    try appendCheck(allocator, &checks, "mutation-proof-disabled", if (!mutation_proof_claim_enabled) .pass else .fail, "mutation proof claims remain disabled");
    try appendCheck(allocator, &checks, "auto-apply-disabled", if (!auto_apply_enabled) .pass else .fail, "auto-apply remains disabled");
    try appendCheck(allocator, &checks, "app-writes-disabled", if (!app_config_write_enabled and !app_data_write_enabled and !handoff.app_config_write_enabled and !handoff.app_data_write_enabled) .pass else .fail, "app writes remain disabled");
    try appendCheck(allocator, &checks, "nendb-write-disabled", if (!nendb_write_enabled and !handoff.nendb_write_enabled) .pass else .fail, "NenDB writes remain disabled");
    try appendCheck(allocator, &checks, "nendb-adapter-execution-disabled", if (!nendb_adapter_execution_enabled and !handoff.nendb_adapter_execution_enabled) .pass else .fail, "NenDB adapter execution remains disabled");
    try appendCheck(allocator, &checks, "durable-write-disabled", if (!durable_write_enabled and !handoff.durable_write_enabled) .pass else .fail, "durable writes remain disabled");
    try appendCheck(allocator, &checks, "deployment-mutation-disabled", if (!deployment_mutation_enabled and !handoff.deployment_mutation_enabled) .pass else .fail, "deployment mutation remains disabled");
    try appendCheck(allocator, &checks, "production-health-claim-disabled", if (!production_health_claim_enabled) .pass else .fail, "production health claims remain disabled");
    try appendCheck(allocator, &checks, "nendb-only-scope", if (nendbOnlyScope()) .pass else .fail, "durable direction remains future NenDB-only scope");
    try appendCheck(allocator, &checks, "solid-webui-scope", if (solidWebuiScope()) .pass else .fail, "workbench direction remains SolidJS inside webui-dev/zig-webui");

    const check_slice = try checks.toOwnedSlice(allocator);
    errdefer allocator.free(check_slice);
    const ready = allChecksPassed(check_slice);
    return .{
        .status = if (ready) .ready else .blocked,
        .ready_for_next_branch = ready,
        .checks = check_slice,
        .source_boundary = handoff.source_boundary,
        .source_proposal = handoff.source_proposal,
        .source_readiness = handoff.source_readiness,
        .source_fixtures = handoff.source_fixtures,
    };
}

fn appendCheck(
    allocator: std.mem.Allocator,
    checks: *std.ArrayList(BridgeCheck),
    name: []const u8,
    status: CheckStatus,
    detail: []const u8,
) !void {
    try checks.append(allocator, .{ .name = name, .status = status, .detail = detail });
}

fn authorityHandoffIntact(handoff: HandoffArtifact) bool {
    return !handoff.applied and
        std.mem.eql(u8, handoff.mutation_authority, "none") and
        !handoff.production_telemetry_ingestion and
        !handoff.live_exporter_enabled and
        !handoff.network_send_enabled and
        !handoff.collector_endpoint_configured and
        !handoff.otlp_serialization_enabled and
        !handoff.durable_write_enabled and
        !handoff.app_mutation_enabled and
        !handoff.ci_gate_enabled and
        !handoff.raw_payload_capture_enabled and
        !handoff.app_config_write_enabled and
        !handoff.app_data_write_enabled and
        !handoff.deployment_mutation_enabled and
        !handoff.nendb_write_enabled and
        !handoff.nendb_adapter_execution_enabled and
        !handoff.app_runtime_integration_enabled and
        !handoff.agent_query_live_projection_enabled and
        !handoff.solid_webui_preview_enabled and
        handoff.local_fixture_mode and
        handoff.nendb_handoff_fixture_mode and
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
        audit_remediation_bridge_mode and
        !mutation_proof_claim_enabled and
        !auto_apply_enabled and
        !production_health_claim_enabled;
}

fn sourceChainLinked(handoff: HandoffArtifact) bool {
    return handoff.source_boundary.len > 0 and
        handoff.source_proposal.len > 0 and
        handoff.source_readiness.len > 0 and
        handoff.source_fixtures.len > 0 and
        std.mem.endsWith(u8, handoff.source_boundary, ".json") and
        std.mem.endsWith(u8, handoff.source_proposal, ".json") and
        std.mem.endsWith(u8, handoff.source_readiness, ".json") and
        std.mem.endsWith(u8, handoff.source_fixtures, ".json");
}

fn handoffChecksPassed(checks: []const HandoffCheck) bool {
    const required = [_][]const u8{
        "local-fixtures-schema",
        "local-fixtures-status",
        "local-fixtures-decision-approved",
        "handoff-decision",
        "decision-approved",
        "authority-boundary",
        "source-chain-linked",
        "local-fixtures-checks-passed",
        "local-fixtures-verification-recorded",
        "source-fixture-catalog-present",
        "nendb-handoff-catalog-present",
        "nendb-node-handoffs-present",
        "nendb-edge-handoffs-present",
        "runtime-ref-handoff-covered",
        "agent-query-handoff-covered",
        "audit-remediation-handoff-covered",
        "solid-webui-handoff-covered",
        "ci-advisory-handoff-covered",
        "handoff-validation-passed",
        "handoff-verification-recorded",
        "nendb-write-disabled",
        "nendb-adapter-execution-disabled",
        "durable-write-disabled",
        "nendb-only-scope",
        "solid-webui-scope",
    };
    for (required) |name| {
        if (!hasHandoffCheck(checks, name, "pass")) return false;
    }
    for (checks) |check| {
        if (!std.mem.eql(u8, check.status, "pass")) return false;
    }
    return true;
}

fn hasHandoffCheck(checks: []const HandoffCheck, name: []const u8, status: []const u8) bool {
    for (checks) |check| {
        if (std.mem.eql(u8, check.name, name) and std.mem.eql(u8, check.status, status)) return true;
    }
    return false;
}

fn handoffVerificationRecorded(handoff: HandoffArtifact) bool {
    return handoff.required_verification_commands.len > 0 and
        verifiedCommandsContainAll(handoff.verified_commands, handoff.required_verification_commands);
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

fn handoffCatalogPresent(fixtures: []const HandoffFixture) bool {
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
        if (!hasHandoffFixture(fixtures, id)) return false;
    }
    return fixtures.len == required.len;
}

fn auditRemediationHandoffPresent(fixtures: []const HandoffFixture) bool {
    return hasHandoffFixture(fixtures, "nendb-audit-remediation-node-handoff-fixture");
}

fn auditChainComparisonRefPresent(fixtures: []const HandoffFixture) bool {
    return handoffFixtureHasRetainedField(fixtures, "nendb-audit-remediation-node-handoff-fixture", "audit_chain_ref") and
        handoffFixtureHasRetainedField(fixtures, "nendb-audit-remediation-node-handoff-fixture", "comparison_ref");
}

fn remediationReviewRefPresent(fixtures: []const HandoffFixture) bool {
    return handoffFixtureHasRetainedField(fixtures, "nendb-audit-remediation-node-handoff-fixture", "remediation_review_ref");
}

fn runtimeRemediationEdgePresent(fixtures: []const HandoffFixture) bool {
    return handoffFixtureHasRetainedField(fixtures, "nendb-runtime-to-audit-remediation-edge-handoff-fixture", "from_trace_ref") and
        handoffFixtureHasRetainedField(fixtures, "nendb-runtime-to-audit-remediation-edge-handoff-fixture", "to_audit_chain_ref") and
        handoffFixtureHasRetainedField(fixtures, "nendb-runtime-to-audit-remediation-edge-handoff-fixture", "remediation_review_ref") and
        handoffFixtureBlocksField(fixtures, "nendb-runtime-to-audit-remediation-edge-handoff-fixture", "source_database_read");
}

fn agentQueryRemediationEdgePresent(fixtures: []const HandoffFixture) bool {
    return handoffFixtureHasRetainedField(fixtures, "nendb-agent-query-projection-node-handoff-fixture", "finding_refs") and
        handoffFixtureHasRetainedField(fixtures, "nendb-agent-query-projection-node-handoff-fixture", "next_query_refs") and
        handoffFixtureHasRetainedField(fixtures, "nendb-runtime-to-agent-query-edge-handoff-fixture", "finding_refs") and
        handoffFixtureHasRetainedField(fixtures, "nendb-runtime-to-agent-query-edge-handoff-fixture", "next_query_refs") and
        handoffFixtureBlocksField(fixtures, "nendb-runtime-to-agent-query-edge-handoff-fixture", "raw_prompt") and
        handoffFixtureBlocksField(fixtures, "nendb-runtime-to-agent-query-edge-handoff-fixture", "raw_response");
}

fn solidWebuiReviewPreviewCovered(fixtures: []const HandoffFixture) bool {
    return handoffFixtureHasRetainedField(fixtures, "nendb-solid-webui-preview-node-handoff-fixture", "webui_sample_ref") and
        handoffFixtureHasRetainedField(fixtures, "nendb-solid-webui-preview-node-handoff-fixture", "solid_view_ref") and
        handoffFixtureBlocksField(fixtures, "nendb-solid-webui-preview-node-handoff-fixture", "react_renderer") and
        handoffFixtureBlocksField(fixtures, "nendb-solid-webui-preview-node-handoff-fixture", "alternate_renderer");
}

fn ciAdvisoryRemediationCovered(fixtures: []const HandoffFixture) bool {
    return handoffFixtureHasRetainedField(fixtures, "nendb-ci-advisory-node-handoff-fixture", "ci_artifact_ref") and
        handoffFixtureHasRetainedField(fixtures, "nendb-ci-advisory-node-handoff-fixture", "advisory_status_ref") and
        handoffFixtureBlocksField(fixtures, "nendb-ci-advisory-node-handoff-fixture", "required_status_check") and
        handoffFixtureBlocksField(fixtures, "nendb-ci-advisory-node-handoff-fixture", "github_api_mutation");
}

fn hasHandoffFixture(fixtures: []const HandoffFixture, id: []const u8) bool {
    for (fixtures) |fixture| {
        if (std.mem.eql(u8, fixture.id, id)) return true;
    }
    return false;
}

fn handoffFixtureHasRetainedField(fixtures: []const HandoffFixture, id: []const u8, field: []const u8) bool {
    for (fixtures) |fixture| {
        if (std.mem.eql(u8, fixture.id, id)) return containsString(fixture.retained_fields, field);
    }
    return false;
}

fn handoffFixtureBlocksField(fixtures: []const HandoffFixture, id: []const u8, field: []const u8) bool {
    for (fixtures) |fixture| {
        if (std.mem.eql(u8, fixture.id, id)) return containsString(fixture.blocked_fields, field);
    }
    return false;
}

fn bridgeCatalogPresent() bool {
    const required = [_][]const u8{
        "audit-chain-comparison-review-bridge",
        "remediation-review-policy-gate-bridge",
        "runtime-to-remediation-evidence-bridge",
        "agent-query-to-remediation-next-query-bridge",
        "solid-webui-review-preview-bridge",
        "ci-advisory-remediation-report-bridge",
    };
    for (required) |id| {
        if (!hasBridgeRecord(id)) return false;
    }
    return audit_remediation_bridge_records.len == required.len;
}

fn hasBridgeRecord(id: []const u8) bool {
    for (audit_remediation_bridge_records) |record| {
        if (std.mem.eql(u8, record.id, id)) return true;
    }
    return false;
}

fn bridgeValidationPassed(handoff: HandoffArtifact) bool {
    return containsString(bridge_validation_checks, "source-handoff-ready") and
        containsString(bridge_validation_checks, "source-authority-disabled") and
        containsString(bridge_validation_checks, "source-handoff-catalog-covered") and
        containsString(bridge_validation_checks, "audit-remediation-node-handoff-present") and
        containsString(bridge_validation_checks, "runtime-to-audit-remediation-edge-present") and
        containsString(bridge_validation_checks, "audit-chain-comparison-ref-present") and
        containsString(bridge_validation_checks, "remediation-review-ref-present") and
        containsString(bridge_validation_checks, "runtime-remediation-evidence-linked") and
        containsString(bridge_validation_checks, "agent-query-remediation-evidence-linked") and
        containsString(bridge_validation_checks, "solid-webui-review-preview-linked") and
        containsString(bridge_validation_checks, "ci-advisory-remediation-linked") and
        containsString(bridge_validation_checks, "mutation-proof-disabled") and
        containsString(bridge_validation_checks, "auto-apply-disabled") and
        containsString(bridge_validation_checks, "app-writes-disabled") and
        containsString(bridge_validation_checks, "nendb-write-disabled") and
        containsString(bridge_validation_checks, "nendb-adapter-execution-disabled") and
        containsString(bridge_validation_checks, "durable-write-disabled") and
        containsString(bridge_validation_checks, "deployment-mutation-disabled") and
        containsString(bridge_validation_checks, "production-health-claim-disabled") and
        containsString(bridge_validation_checks, "raw-sensitive-fields-blocked") and
        containsString(bridge_validation_checks, "production-mutation-fields-blocked") and
        containsString(bridge_validation_checks, "non-nendb-scope-rejected") and
        containsString(bridge_validation_checks, "cockroach-scope-rejected") and
        containsString(bridge_validation_checks, "solid-webui-readonly-preview-next-only") and
        handoffCatalogPresent(handoff.nendb_handoff_fixtures) and
        auditRemediationHandoffPresent(handoff.nendb_handoff_fixtures) and
        auditChainComparisonRefPresent(handoff.nendb_handoff_fixtures) and
        remediationReviewRefPresent(handoff.nendb_handoff_fixtures) and
        runtimeRemediationEdgePresent(handoff.nendb_handoff_fixtures) and
        agentQueryRemediationEdgePresent(handoff.nendb_handoff_fixtures) and
        solidWebuiReviewPreviewCovered(handoff.nendb_handoff_fixtures) and
        ciAdvisoryRemediationCovered(handoff.nendb_handoff_fixtures);
}

fn nendbOnlyScope() bool {
    return containsString(non_goals, "non-NenDB durable adapters") and
        containsString(non_goals, "Cockroach adapter work") and
        containsString(blocked_claims, "non-nendb-durable-storage") and
        containsString(blocked_claims, "cockroach-adapter-work");
}

fn solidWebuiScope() bool {
    return containsString(non_goals, "React or alternate renderer work") and
        containsString(blocked_claims, "react-or-alternate-renderer") and
        std.mem.indexOf(u8, next_branch_if_ready, "solid-webui-readonly-preview") != null;
}

fn containsString(values: []const []const u8, needle: []const u8) bool {
    for (values) |value| {
        if (std.mem.indexOf(u8, value, needle) != null) return true;
    }
    return false;
}

fn allChecksPassed(checks: []const BridgeCheck) bool {
    for (checks) |check| {
        if (check.status != .pass) return false;
    }
    return true;
}

fn formatBridgeJson(
    allocator: std.mem.Allocator,
    options: Options,
    result: BridgeResult,
) ![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "{\n");
    try output.appendSlice(allocator, "  \"schema\": ");
    try appendJsonString(allocator, &output, app_facing_production_integration_audit_remediation_bridge_schema);
    try output.appendSlice(allocator, ",\n  \"schema_version\": 1,\n");
    try output.appendSlice(allocator, "  \"source_handoff\": ");
    try appendJsonString(allocator, &output, options.handoff_path);
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
    try output.appendSlice(allocator, ",\n  \"audit_remediation_bridge_status\": ");
    try appendJsonString(allocator, &output, bridgeStatusText(result.status));
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
    try output.print(allocator, "  \"audit_remediation_bridge_mode\": {},\n", .{audit_remediation_bridge_mode});
    try output.print(allocator, "  \"mutation_proof_claim_enabled\": {},\n", .{mutation_proof_claim_enabled});
    try output.print(allocator, "  \"auto_apply_enabled\": {},\n", .{auto_apply_enabled});
    try output.print(allocator, "  \"production_health_claim_enabled\": {},\n", .{production_health_claim_enabled});
    try output.appendSlice(allocator, "  \"generated_by\": ");
    try appendJsonString(allocator, &output, generated_by);
    try output.appendSlice(allocator, ",\n  \"source_branch\": ");
    try appendJsonString(allocator, &output, source_branch);
    try output.appendSlice(allocator, ",\n  \"recommendation\": ");
    try appendJsonString(allocator, &output, recommendation);
    try output.appendSlice(allocator, ",\n  \"next_branch_if_ready\": ");
    try appendJsonString(allocator, &output, next_branch_if_ready);
    try output.appendSlice(allocator, ",\n  \"checks\": ");
    try appendChecksJson(allocator, &output, result.checks);
    try output.appendSlice(allocator, ",\n  \"audit_remediation_bridge_records\": ");
    try appendBridgeRecordsJson(allocator, &output, audit_remediation_bridge_records);
    try output.appendSlice(allocator, ",\n  \"bridge_validation_checks\": ");
    try appendStringArray(allocator, &output, bridge_validation_checks);
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

fn formatBridgeText(
    allocator: std.mem.Allocator,
    options: Options,
    result: BridgeResult,
) ![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "zigeffect app-facing production integration audit remediation bridge\n");
    try output.print(allocator, "schema: {s}\n", .{app_facing_production_integration_audit_remediation_bridge_schema});
    try output.print(allocator, "source handoff: {s}\n", .{options.handoff_path});
    try output.print(allocator, "source boundary: {s}\n", .{result.source_boundary});
    try output.print(allocator, "source proposal: {s}\n", .{result.source_proposal});
    try output.print(allocator, "source readiness: {s}\n", .{result.source_readiness});
    try output.print(allocator, "source fixtures: {s}\n", .{result.source_fixtures});
    try output.print(allocator, "decision: {s}\n", .{decisionText(options.decision)});
    try output.print(allocator, "audit_remediation_bridge_status: {s}\n", .{bridgeStatusText(result.status)});
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
    try output.print(allocator, "audit remediation bridge mode: {}\n", .{audit_remediation_bridge_mode});
    try output.print(allocator, "mutation proof claim enabled: {}\n", .{mutation_proof_claim_enabled});
    try output.print(allocator, "auto apply enabled: {}\n", .{auto_apply_enabled});
    try output.print(allocator, "production health claim enabled: {}\n", .{production_health_claim_enabled});
    try output.print(allocator, "generated by: {s}\n", .{generated_by});
    try output.print(allocator, "source branch: {s}\n", .{source_branch});
    try output.print(allocator, "recommendation: {s}\n", .{recommendation});
    try output.print(allocator, "next branch if ready: {s}\n\n", .{next_branch_if_ready});

    try output.appendSlice(allocator, "checks:\n");
    for (result.checks) |check| {
        try output.print(allocator, "- {s}: {s} - {s}\n", .{ check.name, checkStatusText(check.status), check.detail });
    }
    try output.append(allocator, '\n');

    try appendBridgeRecordsText(allocator, &output, audit_remediation_bridge_records);
    try appendTextList(allocator, &output, "bridge validation checks", bridge_validation_checks);
    try appendTextList(allocator, &output, "implementation gates", implementation_gates);
    try appendTextList(allocator, &output, "non-goals", non_goals);
    try appendTextList(allocator, &output, "blocked claims", blocked_claims);
    try appendTextList(allocator, &output, "required verification commands", required_verification_commands);
    try appendTextList(allocator, &output, "verified commands", options.verified_commands);
    try appendTextList(allocator, &output, "agent guidance", agentGuidance(result.status));

    return output.toOwnedSlice(allocator);
}

fn appendChecksJson(allocator: std.mem.Allocator, output: *std.ArrayList(u8), checks: []const BridgeCheck) !void {
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

fn appendBridgeRecordsJson(allocator: std.mem.Allocator, output: *std.ArrayList(u8), records: []const BridgeRecord) !void {
    try output.append(allocator, '[');
    for (records, 0..) |record, index| {
        if (index > 0) try output.appendSlice(allocator, ", ");
        try output.appendSlice(allocator, "{ \"id\": ");
        try appendJsonString(allocator, output, record.id);
        try output.appendSlice(allocator, ", \"source_handoff_fixture\": ");
        try appendJsonString(allocator, output, record.source_handoff_fixture);
        try output.appendSlice(allocator, ", \"audit_ref\": ");
        try appendJsonString(allocator, output, record.audit_ref);
        try output.appendSlice(allocator, ", \"remediation_ref\": ");
        try appendJsonString(allocator, output, record.remediation_ref);
        try output.appendSlice(allocator, ", \"bridge_kind\": ");
        try appendJsonString(allocator, output, record.bridge_kind);
        try output.appendSlice(allocator, ", \"review_state\": ");
        try appendJsonString(allocator, output, record.review_state);
        try output.appendSlice(allocator, ", \"retained_refs\": ");
        try appendStringArray(allocator, output, record.retained_refs);
        try output.appendSlice(allocator, ", \"blocked_claims\": ");
        try appendStringArray(allocator, output, record.blocked_claims);
        try output.appendSlice(allocator, " }");
    }
    try output.append(allocator, ']');
}

fn appendBridgeRecordsText(allocator: std.mem.Allocator, output: *std.ArrayList(u8), records: []const BridgeRecord) !void {
    try output.appendSlice(allocator, "audit remediation bridge records:\n");
    for (records) |record| {
        try output.print(allocator, "- {s}: {s} ({s}, {s})\n", .{ record.id, record.source_handoff_fixture, record.bridge_kind, record.review_state });
        try output.print(allocator, "  audit ref: {s}\n", .{record.audit_ref});
        try output.print(allocator, "  remediation ref: {s}\n", .{record.remediation_ref});
        try output.appendSlice(allocator, "  retained refs:");
        for (record.retained_refs) |ref| try output.print(allocator, " {s}", .{ref});
        try output.appendSlice(allocator, "\n  blocked claims:");
        for (record.blocked_claims) |claim| try output.print(allocator, " {s}", .{claim});
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

fn agentGuidance(status: BridgeStatus) []const []const u8 {
    return switch (status) {
        .ready => &.{
            "Ready audit/remediation bridge artifacts permit starting the SolidJS read-only preview branch only.",
            "Cite source handoff checks bridge records validation checks and verification commands.",
            "Do not infer app runtime integration live agent projection raw payload capture app mutation NenDB writes NenDB adapter execution Cockroach scope CI enforcement deployment mutation production health mutation proof auto-apply or applied=true.",
        },
        .blocked => &.{
            "Blocked audit/remediation bridge artifacts must not start the SolidJS read-only preview branch.",
            "Repair source handoff evidence bridge catalog coverage or verification command evidence first.",
            "Do not infer production app integration remediation application or durable write approval from blocked bridge evidence.",
        },
    };
}

fn usage() []const u8 {
    return "usage: zig build causal-app-facing-production-integration-audit-remediation-bridge -- --from-handoff <handoff.json> approve|reject --reason <reason> [--by <actor>] [--policy <policy>] [--verified-command <command>]... [--out-prefix <path-prefix>]\n";
}

fn failUsage(err: anyerror) noreturn {
    std.debug.print("causal-app-facing-production-integration-audit-remediation-bridge error: {s}\n{s}", .{ @errorName(err), usage() });
    std.process.exit(2);
}

fn readRequiredArtifact(io: std.Io, allocator: std.mem.Allocator, path: []const u8) ![]const u8 {
    return std.Io.Dir.cwd().readFileAlloc(io, path, allocator, .limited(1024 * 1024)) catch |err| switch (err) {
        error.FileNotFound => error.MissingHandoffInput,
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
    const source_handoff_json = try readRequiredArtifact(init.io, allocator, options.handoff_path);
    defer allocator.free(source_handoff_json);

    const reports = try formatReports(allocator, .{
        .options = options,
        .source_handoff_json = source_handoff_json,
    });
    defer reports.deinit(allocator);

    const paths = try outputPathsForOptions(allocator, options);
    defer paths.deinit(allocator);

    try writeArtifact(init.io, paths.json_path, reports.json);
    try writeArtifact(init.io, paths.text_path, reports.text);
    std.debug.print("{s}", .{reports.text});
}

const required_verification_commands: []const []const u8 = &.{
    "zig build causal-app-facing-production-integration-nendb-handoff-fixtures",
    "zig build causal-schema-governance -- --format json",
    "zig build causal-production-hardening-backlog -- --format json",
    "zig build examples",
    "zig build test",
};

const audit_remediation_bridge_records: []const BridgeRecord = &.{
    .{ .id = "audit-chain-comparison-review-bridge", .source_handoff_fixture = "nendb-audit-remediation-node-handoff-fixture", .audit_ref = "audit_chain_ref", .remediation_ref = "remediation_review_ref", .bridge_kind = "audit-chain-comparison", .review_state = "review-only", .retained_refs = &.{ "audit_chain_ref", "comparison_ref", "nendb-runtime-to-audit-remediation-edge-handoff-fixture" }, .blocked_claims = &.{ "mutation-proof", "fixed-claim", "deployed-claim" } },
    .{ .id = "remediation-review-policy-gate-bridge", .source_handoff_fixture = "nendb-audit-remediation-node-handoff-fixture", .audit_ref = "policy_gate_ref", .remediation_ref = "remediation_review_ref", .bridge_kind = "remediation-policy-gate", .review_state = "review-only", .retained_refs = &.{ "remediation_review_ref", "policy_gate_ref", "review_status_ref" }, .blocked_claims = &.{ "auto-apply", "app-config-write", "app-data-write" } },
    .{ .id = "runtime-to-remediation-evidence-bridge", .source_handoff_fixture = "nendb-runtime-to-audit-remediation-edge-handoff-fixture", .audit_ref = "runtime_trace_ref", .remediation_ref = "remediation_review_ref", .bridge_kind = "runtime-remediation-evidence", .review_state = "review-only", .retained_refs = &.{ "trace_id_ref", "causal_event_ref", "remediation_review_ref" }, .blocked_claims = &.{ "raw-payload-join", "source-database-read" } },
    .{ .id = "agent-query-to-remediation-next-query-bridge", .source_handoff_fixture = "nendb-runtime-to-agent-query-edge-handoff-fixture", .audit_ref = "agent_query_ref", .remediation_ref = "remediation_review_ref", .bridge_kind = "agent-query-remediation", .review_state = "review-only", .retained_refs = &.{ "trace_data_refs", "finding_refs", "next_query_refs", "remediation_review_ref" }, .blocked_claims = &.{ "raw-prompt", "raw-response", "unbounded-query" } },
    .{ .id = "solid-webui-review-preview-bridge", .source_handoff_fixture = "nendb-solid-webui-preview-node-handoff-fixture", .audit_ref = "solid_view_ref", .remediation_ref = "review_state_ref", .bridge_kind = "solid-webui-preview", .review_state = "read-only-preview-next", .retained_refs = &.{ "webui_sample_ref", "solid_view_ref", "review_state_ref" }, .blocked_claims = &.{ "live-dashboard-host", "app-mutation-button", "react-renderer", "alternate-renderer" } },
    .{ .id = "ci-advisory-remediation-report-bridge", .source_handoff_fixture = "nendb-ci-advisory-node-handoff-fixture", .audit_ref = "ci_artifact_ref", .remediation_ref = "advisory_status_ref", .bridge_kind = "ci-advisory-report", .review_state = "advisory-only", .retained_refs = &.{ "ci_artifact_ref", "advisory_status_ref", "review_state_ref" }, .blocked_claims = &.{ "required-status-check", "ci-enforcement", "workflow-mutation", "github-api-mutation" } },
};

const bridge_validation_checks: []const []const u8 = &.{
    "source-handoff-ready",
    "source-authority-disabled",
    "source-handoff-catalog-covered",
    "audit-remediation-node-handoff-present",
    "runtime-to-audit-remediation-edge-present",
    "audit-chain-comparison-ref-present",
    "remediation-review-ref-present",
    "runtime-remediation-evidence-linked",
    "agent-query-remediation-evidence-linked",
    "solid-webui-review-preview-linked",
    "ci-advisory-remediation-linked",
    "mutation-proof-disabled",
    "auto-apply-disabled",
    "app-writes-disabled",
    "nendb-write-disabled",
    "nendb-adapter-execution-disabled",
    "durable-write-disabled",
    "deployment-mutation-disabled",
    "production-health-claim-disabled",
    "raw-sensitive-fields-blocked",
    "production-mutation-fields-blocked",
    "non-nendb-scope-rejected",
    "cockroach-scope-rejected",
    "solid-webui-readonly-preview-next-only",
};

const implementation_gates: []const []const u8 = &.{
    "source app-facing NenDB handoff fixture artifact is ready",
    "source handoff checks and source verification commands remain pass",
    "audit/remediation bridge emits review-only records",
    "mutation proof and auto-apply remain disabled",
    "app config and app data writes remain disabled",
    "NenDB writes and NenDB adapter execution remain disabled",
    "durable writes and deployment mutation remain disabled",
    "SolidJS read-only preview is the next branch only",
    "CI artifacts remain advisory and do not enforce gates",
};

const non_goals: []const []const u8 = &.{
    "live app runtime integration",
    "live agent query projection",
    "raw app payload capture",
    "raw prompt or raw response capture",
    "app config writes",
    "app data writes",
    "remediation auto-apply",
    "mutation proof",
    "fixed deployed or healthy app claims",
    "deployment mutation",
    "CI enforcement or required status checks",
    "NenDB production writes",
    "NenDB adapter execution",
    "durable production writes",
    "non-NenDB durable adapters",
    "Cockroach adapter work",
    "hosted live dashboard",
    "React or alternate renderer work",
    "applied=true",
};

const blocked_claims: []const []const u8 = &.{
    "app-runtime-integration-enabled",
    "agent-query-live-projection-enabled",
    "solid-webui-preview-enabled",
    "app-mutation-enabled",
    "raw-payload-capture-enabled",
    "raw-prompt-capture-enabled",
    "raw-response-capture-enabled",
    "app-config-write",
    "app-data-write",
    "remediation-auto-apply",
    "mutation-proof-claim",
    "fixed-deployed-healthy-claim",
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

test "app-facing audit remediation bridge constants preserve the branch boundary" {
    try std.testing.expectEqualStrings("zigeffect.causal.app-facing-production-integration-audit-remediation-bridge.v1", app_facing_production_integration_audit_remediation_bridge_schema);
    try std.testing.expectEqual(@as(u32, 1), app_facing_production_integration_audit_remediation_bridge_schema_version);
    try std.testing.expectEqualStrings("codex/zigeffect-causal-app-facing-production-integration-audit-remediation-bridge", source_branch);
    try std.testing.expectEqualStrings("start-app-facing-production-integration-solid-webui-readonly-preview", recommendation);
    try std.testing.expectEqualStrings("codex/zigeffect-causal-app-facing-production-integration-solid-webui-readonly-preview", next_branch_if_ready);
}

test "app-facing audit remediation bridge options require handoff json and reason" {
    try std.testing.expectError(error.MissingHandoffPath, parseOptions(std.testing.allocator, &.{"tool"}));
    try std.testing.expectError(error.UnknownFlag, parseOptions(std.testing.allocator, &.{ "tool", "--from-local-fixtures", "handoff.json", "approve", "--reason", "reviewed" }));
    try std.testing.expectError(error.InvalidHandoffPath, parseOptions(std.testing.allocator, &.{ "tool", "--from-handoff", "handoff.txt", "approve", "--reason", "reviewed" }));
    try std.testing.expectError(error.MissingDecision, parseOptions(std.testing.allocator, &.{ "tool", "--from-handoff", "handoff.json" }));
    try std.testing.expectError(error.MissingReason, parseOptions(std.testing.allocator, &.{ "tool", "--from-handoff", "handoff.json", "approve" }));
}

test "app-facing audit remediation bridge options parse successful approval review" {
    const parsed = try parseOptions(std.testing.allocator, &.{ "tool", "--from-handoff", "handoff.json", "approve", "--reason", "reviewed", "--verified-command", "zig build test" });
    defer parsed.deinit(std.testing.allocator);

    try std.testing.expectEqualStrings("handoff.json", parsed.handoff_path);
    try std.testing.expectEqual(Decision.approve, parsed.decision);
    try std.testing.expectEqualStrings("reviewed", parsed.reason);
    try std.testing.expectEqual(@as(usize, 1), parsed.verified_commands.len);
    try std.testing.expectEqualStrings("zig build test", parsed.verified_commands[0]);
}

test "app-facing audit remediation bridge output paths append bridge suffix" {
    const parsed = try parseOptions(std.testing.allocator, &.{ "tool", "--from-handoff", "handoff.json", "approve", "--reason", "reviewed" });
    defer parsed.deinit(std.testing.allocator);

    const paths = try outputPathsForOptions(std.testing.allocator, parsed);
    defer paths.deinit(std.testing.allocator);

    try std.testing.expectEqualStrings("handoff-audit-remediation-bridge.json", paths.json_path);
    try std.testing.expectEqualStrings("handoff-audit-remediation-bridge.txt", paths.text_path);
}

test "app-facing audit remediation bridge ready report preserves review-only authority" {
    const reports = try formatReports(std.testing.allocator, .{
        .options = .{
            .handoff_path = "handoff.json",
            .decision = .approve,
            .reason = "ready app-facing NenDB handoff fixtures reviewed for audit remediation bridge",
            .verified_commands = bridge_verified_commands_for_tests,
        },
        .source_handoff_json = sample_handoff_json,
    });
    defer reports.deinit(std.testing.allocator);

    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"schema\": \"zigeffect.causal.app-facing-production-integration-audit-remediation-bridge.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"audit_remediation_bridge_status\": \"ready\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"ready_for_next_branch\": true") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"audit_remediation_bridge_mode\": true") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"mutation_proof_claim_enabled\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"auto_apply_enabled\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"nendb_adapter_execution_enabled\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "audit-chain-comparison-review-bridge") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "remediation-review-policy-gate-bridge") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "solid-webui-review-preview-bridge") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.text, "audit_remediation_bridge_status: ready") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.text, "auto apply enabled: false") != null);
}

test "app-facing audit remediation bridge reject report remains blocked and authority-disabled" {
    const reports = try formatReports(std.testing.allocator, .{
        .options = .{
            .handoff_path = "handoff.json",
            .decision = .reject,
            .reason = "negative audit remediation bridge path",
        },
        .source_handoff_json = sample_handoff_json,
    });
    defer reports.deinit(std.testing.allocator);

    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"audit_remediation_bridge_status\": \"blocked\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"ready_for_next_branch\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"applied\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"app_data_write_enabled\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"auto_apply_enabled\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"production_health_claim_enabled\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.text, "audit_remediation_bridge_status: blocked") != null);
}

test "app-facing audit remediation bridge blocks source authority drift" {
    const adapter_execution_json = try std.mem.replaceOwned(
        u8,
        std.testing.allocator,
        sample_handoff_json,
        "\"nendb_adapter_execution_enabled\": false",
        "\"nendb_adapter_execution_enabled\": true",
    );
    defer std.testing.allocator.free(adapter_execution_json);
    try expectBridgeBlockedBy(adapter_execution_json, "nendb-adapter-execution-disabled");

    const applied_json = try std.mem.replaceOwned(
        u8,
        std.testing.allocator,
        sample_handoff_json,
        "\"applied\": false",
        "\"applied\": true",
    );
    defer std.testing.allocator.free(applied_json);
    try expectBridgeBlockedBy(applied_json, "authority-boundary");
}

test "app-facing audit remediation bridge blocks missing audit remediation refs" {
    const missing_audit_ref_json = try std.mem.replaceOwned(
        u8,
        std.testing.allocator,
        sample_handoff_json,
        "audit_chain_ref",
        "audit_missing_ref",
    );
    defer std.testing.allocator.free(missing_audit_ref_json);
    try expectBridgeBlockedBy(missing_audit_ref_json, "audit-chain-comparison-ref-present");

    const missing_remediation_ref_json = try std.mem.replaceOwned(
        u8,
        std.testing.allocator,
        sample_handoff_json,
        "remediation_review_ref",
        "remediation_missing_ref",
    );
    defer std.testing.allocator.free(missing_remediation_ref_json);
    try expectBridgeBlockedBy(missing_remediation_ref_json, "remediation-review-ref-present");
}

fn expectBridgeBlockedBy(source_handoff_json: []const u8, check_name: []const u8) !void {
    const reports = try formatReports(std.testing.allocator, .{
        .options = .{
            .handoff_path = "handoff.json",
            .decision = .approve,
            .reason = "ready app-facing NenDB handoff fixtures reviewed for audit remediation bridge",
            .verified_commands = bridge_verified_commands_for_tests,
        },
        .source_handoff_json = source_handoff_json,
    });
    defer reports.deinit(std.testing.allocator);

    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"audit_remediation_bridge_status\": \"blocked\"") != null);
    const needle = try std.fmt.allocPrint(std.testing.allocator, "\"name\": \"{s}\", \"status\": \"fail\"", .{check_name});
    defer std.testing.allocator.free(needle);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, needle) != null);
}

const bridge_verified_commands_for_tests: []const []const u8 = &.{
    "zig build causal-app-facing-production-integration-nendb-handoff-fixtures",
    "zig build causal-schema-governance -- --format json",
    "zig build causal-production-hardening-backlog -- --format json",
    "zig build examples",
    "zig build test",
};

const sample_handoff_json =
    \\{
    \\  "schema": "zigeffect.causal.app-facing-production-integration-nendb-handoff-fixtures.v1",
    \\  "schema_version": 1,
    \\  "source_boundary": "../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures-readiness-review-implementation-proposal-app-facing-boundary.json",
    \\  "source_proposal": "../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures-readiness-review-implementation-proposal.json",
    \\  "source_readiness": "../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures-readiness-review.json",
    \\  "source_fixtures": "../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures.json",
    \\  "decision": "approve",
    \\  "nendb_handoff_status": "ready",
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
    \\  "nendb_adapter_execution_enabled": false,
    \\  "app_runtime_integration_enabled": false,
    \\  "agent_query_live_projection_enabled": false,
    \\  "solid_webui_preview_enabled": false,
    \\  "local_fixture_mode": true,
    \\  "nendb_handoff_fixture_mode": true,
    \\  "checks": [
    \\    { "name": "local-fixtures-schema", "status": "pass" },
    \\    { "name": "local-fixtures-status", "status": "pass" },
    \\    { "name": "local-fixtures-decision-approved", "status": "pass" },
    \\    { "name": "handoff-decision", "status": "pass" },
    \\    { "name": "decision-approved", "status": "pass" },
    \\    { "name": "authority-boundary", "status": "pass" },
    \\    { "name": "source-chain-linked", "status": "pass" },
    \\    { "name": "local-fixtures-checks-passed", "status": "pass" },
    \\    { "name": "local-fixtures-verification-recorded", "status": "pass" },
    \\    { "name": "source-fixture-catalog-present", "status": "pass" },
    \\    { "name": "nendb-handoff-catalog-present", "status": "pass" },
    \\    { "name": "nendb-node-handoffs-present", "status": "pass" },
    \\    { "name": "nendb-edge-handoffs-present", "status": "pass" },
    \\    { "name": "runtime-ref-handoff-covered", "status": "pass" },
    \\    { "name": "agent-query-handoff-covered", "status": "pass" },
    \\    { "name": "audit-remediation-handoff-covered", "status": "pass" },
    \\    { "name": "solid-webui-handoff-covered", "status": "pass" },
    \\    { "name": "ci-advisory-handoff-covered", "status": "pass" },
    \\    { "name": "handoff-validation-passed", "status": "pass" },
    \\    { "name": "handoff-verification-recorded", "status": "pass" },
    \\    { "name": "nendb-write-disabled", "status": "pass" },
    \\    { "name": "nendb-adapter-execution-disabled", "status": "pass" },
    \\    { "name": "durable-write-disabled", "status": "pass" },
    \\    { "name": "nendb-only-scope", "status": "pass" },
    \\    { "name": "solid-webui-scope", "status": "pass" }
    \\  ],
    \\  "nendb_handoff_fixtures": [
    \\    { "id": "nendb-worker-request-node-handoff-fixture", "retained_fields": ["trace_id_ref", "causal_event_ref"], "blocked_fields": ["raw_request_body", "app_mutation"] },
    \\    { "id": "nendb-background-job-node-handoff-fixture", "retained_fields": ["job_ref", "trace_id_ref"], "blocked_fields": ["raw_payload", "app_mutation"] },
    \\    { "id": "nendb-agent-query-projection-node-handoff-fixture", "retained_fields": ["trace_data_refs", "finding_refs", "next_query_refs"], "blocked_fields": ["raw_prompt", "raw_response", "unbounded_query"] },
    \\    { "id": "nendb-audit-remediation-node-handoff-fixture", "retained_fields": ["audit_chain_ref", "remediation_review_ref", "comparison_ref"], "blocked_fields": ["mutation_proof_claim", "auto_apply", "fixed_claim", "deployed_claim"] },
    \\    { "id": "nendb-solid-webui-preview-node-handoff-fixture", "retained_fields": ["webui_sample_ref", "solid_view_ref"], "blocked_fields": ["react_renderer", "alternate_renderer", "live_dashboard_host", "app_mutation_button"] },
    \\    { "id": "nendb-ci-advisory-node-handoff-fixture", "retained_fields": ["ci_artifact_ref", "advisory_status_ref"], "blocked_fields": ["required_status_check", "ci_gate_enforcement", "workflow_mutation", "github_api_mutation"] },
    \\    { "id": "nendb-runtime-to-agent-query-edge-handoff-fixture", "retained_fields": ["from_trace_ref", "to_query_ref", "finding_refs", "next_query_refs"], "blocked_fields": ["raw_prompt", "raw_response", "raw_payload_join", "source_database_read"] },
    \\    { "id": "nendb-runtime-to-audit-remediation-edge-handoff-fixture", "retained_fields": ["from_trace_ref", "to_audit_chain_ref", "remediation_review_ref", "comparison_ref"], "blocked_fields": ["mutation_proof_claim", "auto_apply", "source_database_read"] },
    \\    { "id": "nendb-artifact-preview-edge-handoff-fixture", "retained_fields": ["from_artifact_ref", "to_webui_sample_ref", "ci_artifact_ref", "advisory_status_ref"], "blocked_fields": ["workflow_mutation", "required_status_check"] }
    \\  ],
    \\  "handoff_validation_checks": ["source-local-fixtures-ready", "source-authority-disabled", "source-fixture-catalog-covered", "nendb-node-handoff-fixtures-present", "nendb-edge-handoff-fixtures-present", "runtime-ref-handoff-covered", "agent-query-handoff-covered", "audit-remediation-handoff-covered", "solid-webui-handoff-covered", "ci-advisory-handoff-covered", "nendb-write-disabled", "nendb-adapter-execution-disabled", "durable-write-disabled", "raw-sensitive-fields-blocked", "production-mutation-fields-blocked", "non-nendb-scope-rejected", "cockroach-scope-rejected", "audit-remediation-bridge-next-only"],
    \\  "required_verification_commands": ["zig build causal-app-facing-production-integration-local-fixtures", "zig build causal-schema-governance -- --format json", "zig build causal-production-hardening-backlog -- --format json", "zig build examples", "zig build test"],
    \\  "verified_commands": ["zig build causal-app-facing-production-integration-local-fixtures", "zig build causal-schema-governance -- --format json", "zig build causal-production-hardening-backlog -- --format json", "zig build examples", "zig build test"]
    \\}
;
