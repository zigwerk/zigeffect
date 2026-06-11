const std = @import("std");

pub const app_facing_production_integration_local_fixtures_schema = "zigeffect.causal.app-facing-production-integration-local-fixtures.v1";
pub const app_facing_production_integration_local_fixtures_schema_version: u32 = 1;
pub const source_branch = "codex/zigeffect-causal-app-facing-production-integration-local-fixtures";
pub const recommendation = "start-app-facing-production-integration-nendb-handoff-fixtures";
pub const next_branch_if_ready = "codex/zigeffect-causal-app-facing-production-integration-nendb-handoff-fixtures";

const boundary_schema = "zigeffect.causal.app-facing-production-integration-boundary.v1";
const generated_by = "causal-app-facing-production-integration-local-fixtures";
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
const app_runtime_integration_enabled = false;
const agent_query_live_projection_enabled = false;
const solid_webui_preview_enabled = false;
const local_fixture_mode = true;

const Decision = enum { approve, reject };
const FixtureStatus = enum { ready, blocked };
const CheckStatus = enum { pass, fail };

const Options = struct {
    boundary_path: []const u8,
    decision: Decision,
    reviewed_by: []const u8 = "local-fixtures-reviewer",
    policy: []const u8 = "manual-app-facing-production-integration-local-fixtures",
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
    source_boundary_json: []const u8,
};

const FixtureReports = struct {
    json: []const u8,
    text: []const u8,

    fn deinit(self: FixtureReports, allocator: std.mem.Allocator) void {
        allocator.free(self.json);
        allocator.free(self.text);
    }
};

const BoundaryCheck = struct {
    name: []const u8,
    status: []const u8,
    detail: []const u8 = "",
};

const BoundarySummary = struct {
    source_contract_count: usize = 0,
    positive_fixture_count: usize = 0,
    negative_fixture_count: usize = 0,
    validation_check_count: usize = 0,
};

const BoundaryArtifact = struct {
    schema: []const u8,
    schema_version: u32,
    source_proposal: []const u8 = "",
    source_readiness: []const u8 = "",
    source_fixtures: []const u8 = "",
    decision: []const u8,
    boundary_status: []const u8,
    approved_for_next_branch: bool,
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
    proposal_summary: BoundarySummary = .{},
    checks: []const BoundaryCheck = &.{},
    app_boundary_contract: []const []const u8 = &.{},
    local_projection_fixtures: []const []const u8 = &.{},
    implementation_gates: []const []const u8 = &.{},
    non_goals: []const []const u8 = &.{},
    blocked_claims: []const []const u8 = &.{},
    required_verification_commands: []const []const u8 = &.{},
    verified_commands: []const []const u8 = &.{},
};

const LocalFixture = struct {
    id: []const u8,
    source_boundary_label: []const u8,
    input_ref: []const u8,
    output_artifact: []const u8,
    output_fields: []const []const u8,
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
    boundary_summary: BoundarySummary,
    source_proposal: []const u8,
    source_readiness: []const u8,
    source_fixtures: []const u8,

    fn deinit(self: FixtureResult, allocator: std.mem.Allocator) void {
        if (self.checks.len > 0) allocator.free(self.checks);
    }
};

fn parseOptions(allocator: std.mem.Allocator, args: []const []const u8) !Options {
    if (args.len < 2) return error.MissingBoundaryPath;
    if (!std.mem.eql(u8, args[1], "--from-boundary")) return error.UnknownFlag;
    if (args.len < 3) return error.MissingBoundaryPath;
    const boundary_path = args[2];
    if (!std.mem.endsWith(u8, boundary_path, ".json")) return error.InvalidBoundaryPath;
    if (args.len < 4) return error.MissingDecision;
    const decision = try parseDecision(args[3]);

    var reviewed_by: []const u8 = "local-fixtures-reviewer";
    var policy: []const u8 = "manual-app-facing-production-integration-local-fixtures";
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
        .boundary_path = boundary_path,
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
        if (!std.mem.endsWith(u8, options.boundary_path, ".json")) return error.InvalidBoundaryPath;
        const base = options.boundary_path[0 .. options.boundary_path.len - ".json".len];
        break :blk try std.fmt.allocPrint(allocator, "{s}-local-fixtures", .{base});
    };
    defer allocator.free(prefix);

    return .{
        .json_path = try std.fmt.allocPrint(allocator, "{s}.json", .{prefix}),
        .text_path = try std.fmt.allocPrint(allocator, "{s}.txt", .{prefix}),
    };
}

fn formatReports(allocator: std.mem.Allocator, input: FixtureInput) !FixtureReports {
    var parsed = try std.json.parseFromSlice(BoundaryArtifact, allocator, input.source_boundary_json, .{ .ignore_unknown_fields = true });
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
        error.MissingBoundaryInput => failUsage(err),
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
    boundary: BoundaryArtifact,
) !FixtureResult {
    var checks = std.ArrayList(FixtureCheck).empty;
    errdefer checks.deinit(allocator);

    try appendCheck(allocator, &checks, "boundary-schema", if (std.mem.eql(u8, boundary.schema, boundary_schema) and boundary.schema_version == 1) .pass else .fail, "source boundary schema is supported");
    try appendCheck(allocator, &checks, "boundary-status", if (std.mem.eql(u8, boundary.boundary_status, "approved") and boundary.approved_for_next_branch) .pass else .fail, "source boundary is approved for local fixture work");
    try appendCheck(allocator, &checks, "boundary-decision-approved", if (std.mem.eql(u8, boundary.decision, "approve")) .pass else .fail, "source boundary decision approved the handoff");
    try appendCheck(allocator, &checks, "fixture-decision", if (options.reason.len > 0) .pass else .fail, "fixture decision includes a reason");
    try appendCheck(allocator, &checks, "decision-approved", if (options.decision == .approve) .pass else .fail, "fixture decision must approve NenDB handoff fixture planning");
    try appendCheck(allocator, &checks, "authority-boundary", if (authorityBoundaryIntact(boundary)) .pass else .fail, "source boundary and local fixture authority fields remain disabled");
    try appendCheck(allocator, &checks, "source-chain-linked", if (sourceChainLinked(boundary)) .pass else .fail, "boundary links proposal readiness and fixture JSON artifacts");
    try appendCheck(allocator, &checks, "boundary-checks-passed", if (boundaryChecksPassed(boundary.checks)) .pass else .fail, "all required source boundary checks passed");
    try appendCheck(allocator, &checks, "boundary-contract-present", if (boundaryContractPresent(boundary.app_boundary_contract)) .pass else .fail, "source boundary contract contains app-facing guarded states");
    try appendCheck(allocator, &checks, "projection-fixtures-present", if (projectionFixturesPresent(boundary.local_projection_fixtures)) .pass else .fail, "source boundary lists all required local projection fixture labels");
    try appendCheck(allocator, &checks, "fixture-catalog-present", if (fixtureCatalogPresent()) .pass else .fail, "local fixture catalog contains required fixtures");
    try appendCheck(allocator, &checks, "runtime-ref-fixtures-present", if (runtimeRefFixturesPresent()) .pass else .fail, "local fixtures include worker and background runtime refs");
    try appendCheck(allocator, &checks, "agent-query-fixture-present", if (agentQueryFixturePresent()) .pass else .fail, "local fixtures include bounded agent query projections");
    try appendCheck(allocator, &checks, "nendb-handoff-fixture-present", if (nendbHandoffFixturePresent()) .pass else .fail, "local fixtures include NenDB handoff refs without writes");
    try appendCheck(allocator, &checks, "audit-remediation-fixture-present", if (auditRemediationFixturePresent()) .pass else .fail, "local fixtures include review-only audit/remediation links");
    try appendCheck(allocator, &checks, "solid-webui-fixture-present", if (solidWebuiFixturePresent()) .pass else .fail, "local fixtures include SolidJS read-only webui preview handoff");
    try appendCheck(allocator, &checks, "ci-advisory-fixture-present", if (ciAdvisoryFixturePresent()) .pass else .fail, "local fixtures include advisory CI artifact previews");
    try appendCheck(allocator, &checks, "fixture-validation-passed", if (fixtureValidationPassed()) .pass else .fail, "all local fixture validation checks passed");
    try appendCheck(allocator, &checks, "boundary-verification-recorded", if (boundaryVerificationRecorded(boundary)) .pass else .fail, "source boundary recorded required verification command evidence");
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
        .boundary_summary = boundary.proposal_summary,
        .source_proposal = boundary.source_proposal,
        .source_readiness = boundary.source_readiness,
        .source_fixtures = boundary.source_fixtures,
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

fn authorityBoundaryIntact(boundary: BoundaryArtifact) bool {
    return !boundary.applied and
        std.mem.eql(u8, boundary.mutation_authority, "none") and
        !boundary.production_telemetry_ingestion and
        !boundary.live_exporter_enabled and
        !boundary.network_send_enabled and
        !boundary.collector_endpoint_configured and
        !boundary.otlp_serialization_enabled and
        !boundary.durable_write_enabled and
        !boundary.app_mutation_enabled and
        !boundary.ci_gate_enabled and
        !boundary.raw_payload_capture_enabled and
        !boundary.app_config_write_enabled and
        !boundary.app_data_write_enabled and
        !boundary.deployment_mutation_enabled and
        !boundary.nendb_write_enabled and
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
        !app_runtime_integration_enabled and
        !agent_query_live_projection_enabled and
        !solid_webui_preview_enabled and
        local_fixture_mode;
}

fn sourceChainLinked(boundary: BoundaryArtifact) bool {
    return boundary.source_proposal.len > 0 and
        boundary.source_readiness.len > 0 and
        boundary.source_fixtures.len > 0 and
        std.mem.endsWith(u8, boundary.source_proposal, ".json") and
        std.mem.endsWith(u8, boundary.source_readiness, ".json") and
        std.mem.endsWith(u8, boundary.source_fixtures, ".json");
}

fn boundaryChecksPassed(checks: []const BoundaryCheck) bool {
    const required = [_][]const u8{
        "proposal-schema",
        "proposal-status",
        "proposal-decision-approved",
        "boundary-decision",
        "decision-approved",
        "authority-boundary",
        "source-chain-linked",
        "proposal-checks-passed",
        "proposal-phase-handoff",
        "proposal-verification-recorded",
        "boundary-verification-recorded",
        "app-runtime-ref-boundary",
        "agent-query-projection-boundary",
        "nendb-handoff-boundary",
        "audit-remediation-boundary",
        "no-production-mutation-boundary",
        "nendb-only-scope",
        "solid-webui-scope",
    };
    for (required) |name| {
        if (!hasBoundaryCheck(checks, name, "pass")) return false;
    }
    for (checks) |check| {
        if (!std.mem.eql(u8, check.status, "pass")) return false;
    }
    return true;
}

fn hasBoundaryCheck(checks: []const BoundaryCheck, name: []const u8, status: []const u8) bool {
    for (checks) |check| {
        if (std.mem.eql(u8, check.name, name) and std.mem.eql(u8, check.status, status)) return true;
    }
    return false;
}

fn boundaryContractPresent(contract: []const []const u8) bool {
    return containsString(contract, "boundary_id=app-facing-production-integration-guarded") and
        containsString(contract, "source_contract=app-runtime") and
        containsString(contract, "trace_ref_state=ref-only") and
        containsString(contract, "raw_payload_state=blocked") and
        containsString(contract, "app_mutation_state=disabled") and
        containsString(contract, "agent_query_state=bounded-trace-data-only") and
        containsString(contract, "nendb_handoff_state=ref-only-no-production-write") and
        containsString(contract, "audit_compare_state=evidence-only-not-mutation-proof") and
        containsString(contract, "remediation_governance_state=handoff-only") and
        containsString(contract, "solid_webui_state=read-only-preview-only") and
        containsString(contract, "ci_state=advisory-artifacts-only");
}

fn projectionFixturesPresent(fixtures: []const []const u8) bool {
    const required = [_][]const u8{
        "worker-request-runtime-ref-boundary",
        "background-job-runtime-ref-boundary",
        "agent-query-bounded-projection-boundary",
        "nendb-history-handoff-ref-boundary",
        "audit-remediation-review-link-boundary",
        "solid-webui-readonly-handoff-boundary",
    };
    for (required) |name| {
        if (!containsString(fixtures, name)) return false;
    }
    return true;
}

fn fixtureCatalogPresent() bool {
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
        if (!hasLocalFixture(id)) return false;
    }
    return fixture_catalog.len == required.len;
}

fn runtimeRefFixturesPresent() bool {
    return hasLocalFixture("worker-request-runtime-ref-fixture") and
        hasLocalFixture("background-job-runtime-ref-fixture") and
        fixtureHasOutputField("worker-request-runtime-ref-fixture", "trace_id_ref") and
        fixtureHasOutputField("worker-request-runtime-ref-fixture", "causal_event_ref") and
        fixtureBlocksField("worker-request-runtime-ref-fixture", "raw_request_body") and
        fixtureBlocksField("worker-request-runtime-ref-fixture", "app_mutation") and
        fixtureHasOutputField("background-job-runtime-ref-fixture", "job_ref") and
        fixtureHasOutputField("background-job-runtime-ref-fixture", "retry_ref") and
        fixtureBlocksField("background-job-runtime-ref-fixture", "raw_payload") and
        fixtureBlocksField("background-job-runtime-ref-fixture", "app_mutation");
}

fn agentQueryFixturePresent() bool {
    return hasLocalFixture("agent-query-bounded-projection-fixture") and
        fixtureHasOutputField("agent-query-bounded-projection-fixture", "trace_data_refs") and
        fixtureHasOutputField("agent-query-bounded-projection-fixture", "finding_refs") and
        fixtureHasOutputField("agent-query-bounded-projection-fixture", "next_query_refs") and
        fixtureHasOutputField("agent-query-bounded-projection-fixture", "truncation_state") and
        fixtureBlocksField("agent-query-bounded-projection-fixture", "raw_payload_scrape") and
        fixtureBlocksField("agent-query-bounded-projection-fixture", "unbounded_query") and
        fixtureBlocksField("agent-query-bounded-projection-fixture", "raw_prompt") and
        fixtureBlocksField("agent-query-bounded-projection-fixture", "raw_response");
}

fn nendbHandoffFixturePresent() bool {
    return hasLocalFixture("nendb-history-handoff-ref-fixture") and
        fixtureHasOutputField("nendb-history-handoff-ref-fixture", "nendb_node_ref") and
        fixtureHasOutputField("nendb-history-handoff-ref-fixture", "nendb_edge_ref") and
        fixtureHasOutputField("nendb-history-handoff-ref-fixture", "handoff_state=ref-only") and
        fixtureBlocksField("nendb-history-handoff-ref-fixture", "nendb_write") and
        fixtureBlocksField("nendb-history-handoff-ref-fixture", "production_history_mutation") and
        fixtureBlocksField("nendb-history-handoff-ref-fixture", "cockroach_adapter");
}

fn auditRemediationFixturePresent() bool {
    return hasLocalFixture("audit-remediation-review-link-fixture") and
        fixtureHasOutputField("audit-remediation-review-link-fixture", "audit_chain_ref") and
        fixtureHasOutputField("audit-remediation-review-link-fixture", "remediation_review_ref") and
        fixtureHasOutputField("audit-remediation-review-link-fixture", "evidence_state=review-only") and
        fixtureBlocksField("audit-remediation-review-link-fixture", "mutation_proof_claim") and
        fixtureBlocksField("audit-remediation-review-link-fixture", "auto_apply") and
        fixtureBlocksField("audit-remediation-review-link-fixture", "deployed_claim");
}

fn solidWebuiFixturePresent() bool {
    return hasLocalFixture("solid-webui-readonly-preview-fixture") and
        fixtureHasOutputField("solid-webui-readonly-preview-fixture", "webui_sample_ref") and
        fixtureHasOutputField("solid-webui-readonly-preview-fixture", "solid_view_ref") and
        fixtureHasOutputField("solid-webui-readonly-preview-fixture", "read_only_state") and
        fixtureBlocksField("solid-webui-readonly-preview-fixture", "live_dashboard_host") and
        fixtureBlocksField("solid-webui-readonly-preview-fixture", "app_mutation_button") and
        fixtureBlocksField("solid-webui-readonly-preview-fixture", "react_renderer") and
        fixtureBlocksField("solid-webui-readonly-preview-fixture", "alternate_renderer");
}

fn ciAdvisoryFixturePresent() bool {
    return hasLocalFixture("ci-advisory-artifact-preview-fixture") and
        fixtureHasOutputField("ci-advisory-artifact-preview-fixture", "ci_artifact_ref") and
        fixtureHasOutputField("ci-advisory-artifact-preview-fixture", "advisory_status_ref") and
        fixtureHasOutputField("ci-advisory-artifact-preview-fixture", "non_blocking_state") and
        fixtureBlocksField("ci-advisory-artifact-preview-fixture", "required_status_check") and
        fixtureBlocksField("ci-advisory-artifact-preview-fixture", "ci_gate_enforcement") and
        fixtureBlocksField("ci-advisory-artifact-preview-fixture", "workflow_mutation") and
        fixtureBlocksField("ci-advisory-artifact-preview-fixture", "github_api_mutation");
}

fn fixtureValidationPassed() bool {
    return containsString(fixture_validation_checks, "fixture-satisfies-boundary-label") and
        containsString(fixture_validation_checks, "fixture-declares-input-ref") and
        containsString(fixture_validation_checks, "fixture-declares-output-artifact") and
        containsString(fixture_validation_checks, "runtime-refs-block-raw-payloads") and
        containsString(fixture_validation_checks, "agent-query-projection-is-bounded") and
        containsString(fixture_validation_checks, "nendb-handoff-is-ref-only") and
        containsString(fixture_validation_checks, "audit-remediation-review-only") and
        containsString(fixture_validation_checks, "solid-webui-preview-read-only") and
        containsString(fixture_validation_checks, "ci-artifacts-advisory-only") and
        containsString(fixture_validation_checks, "raw-sensitive-fields-blocked") and
        containsString(fixture_validation_checks, "production-mutation-fields-blocked") and
        fixtureCatalogPresent() and
        runtimeRefFixturesPresent() and
        agentQueryFixturePresent() and
        nendbHandoffFixturePresent() and
        auditRemediationFixturePresent() and
        solidWebuiFixturePresent() and
        ciAdvisoryFixturePresent();
}

fn boundaryVerificationRecorded(boundary: BoundaryArtifact) bool {
    return boundary.required_verification_commands.len > 0 and
        verifiedCommandsContainAll(boundary.verified_commands, boundary.required_verification_commands);
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

fn hasLocalFixture(id: []const u8) bool {
    for (fixture_catalog) |fixture| {
        if (std.mem.eql(u8, fixture.id, id)) return true;
    }
    return false;
}

fn fixtureHasOutputField(id: []const u8, field: []const u8) bool {
    for (fixture_catalog) |fixture| {
        if (std.mem.eql(u8, fixture.id, id)) return containsString(fixture.output_fields, field);
    }
    return false;
}

fn fixtureBlocksField(id: []const u8, field: []const u8) bool {
    for (fixture_catalog) |fixture| {
        if (std.mem.eql(u8, fixture.id, id)) return containsString(fixture.blocked_fields, field);
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
    try appendJsonString(allocator, &output, app_facing_production_integration_local_fixtures_schema);
    try output.appendSlice(allocator, ",\n  \"schema_version\": 1,\n");
    try output.appendSlice(allocator, "  \"source_boundary\": ");
    try appendJsonString(allocator, &output, options.boundary_path);
    try output.appendSlice(allocator, ",\n  \"source_proposal\": ");
    try appendJsonString(allocator, &output, result.source_proposal);
    try output.appendSlice(allocator, ",\n  \"source_readiness\": ");
    try appendJsonString(allocator, &output, result.source_readiness);
    try output.appendSlice(allocator, ",\n  \"source_fixtures\": ");
    try appendJsonString(allocator, &output, result.source_fixtures);
    try output.appendSlice(allocator, ",\n  \"decision\": ");
    try appendJsonString(allocator, &output, decisionText(options.decision));
    try output.appendSlice(allocator, ",\n  \"fixture_status\": ");
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
    try output.print(allocator, "  \"app_runtime_integration_enabled\": {},\n", .{app_runtime_integration_enabled});
    try output.print(allocator, "  \"agent_query_live_projection_enabled\": {},\n", .{agent_query_live_projection_enabled});
    try output.print(allocator, "  \"solid_webui_preview_enabled\": {},\n", .{solid_webui_preview_enabled});
    try output.print(allocator, "  \"local_fixture_mode\": {},\n", .{local_fixture_mode});
    try output.appendSlice(allocator, "  \"source_branch\": ");
    try appendJsonString(allocator, &output, source_branch);
    try output.appendSlice(allocator, ",\n  \"recommendation\": ");
    try appendJsonString(allocator, &output, recommendation);
    try output.appendSlice(allocator, ",\n  \"next_branch_if_ready\": ");
    try appendJsonString(allocator, &output, next_branch_if_ready);
    try output.appendSlice(allocator, ",\n  \"boundary_summary\": ");
    try appendBoundarySummaryJson(allocator, &output, result.boundary_summary);
    try output.appendSlice(allocator, ",\n  \"checks\": ");
    try appendChecksJson(allocator, &output, result.checks);
    try output.appendSlice(allocator, ",\n  \"fixture_catalog\": ");
    try appendFixtureCatalogJson(allocator, &output, fixture_catalog);
    try output.appendSlice(allocator, ",\n  \"fixture_validation_checks\": ");
    try appendStringArray(allocator, &output, fixture_validation_checks);
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

    try output.appendSlice(allocator, "zigeffect app-facing production integration local fixtures\n");
    try output.print(allocator, "schema: {s}\n", .{app_facing_production_integration_local_fixtures_schema});
    try output.print(allocator, "source boundary: {s}\n", .{options.boundary_path});
    try output.print(allocator, "source proposal: {s}\n", .{result.source_proposal});
    try output.print(allocator, "source readiness: {s}\n", .{result.source_readiness});
    try output.print(allocator, "source fixtures: {s}\n", .{result.source_fixtures});
    try output.print(allocator, "decision: {s}\n", .{decisionText(options.decision)});
    try output.print(allocator, "fixture_status: {s}\n", .{fixtureStatusText(result.status)});
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
    try output.print(allocator, "app runtime integration enabled: {}\n", .{app_runtime_integration_enabled});
    try output.print(allocator, "agent query live projection enabled: {}\n", .{agent_query_live_projection_enabled});
    try output.print(allocator, "solid webui preview enabled: {}\n", .{solid_webui_preview_enabled});
    try output.print(allocator, "local fixture mode: {}\n", .{local_fixture_mode});
    try output.print(allocator, "generated by: {s}\n", .{generated_by});
    try output.print(allocator, "source branch: {s}\n", .{source_branch});
    try output.print(allocator, "recommendation: {s}\n", .{recommendation});
    try output.print(allocator, "next branch if ready: {s}\n\n", .{next_branch_if_ready});

    try output.appendSlice(allocator, "boundary summary:\n");
    try output.print(allocator, "- source contracts: {d}\n", .{result.boundary_summary.source_contract_count});
    try output.print(allocator, "- positive fixtures: {d}\n", .{result.boundary_summary.positive_fixture_count});
    try output.print(allocator, "- negative fixtures: {d}\n", .{result.boundary_summary.negative_fixture_count});
    try output.print(allocator, "- validation checks: {d}\n\n", .{result.boundary_summary.validation_check_count});

    try output.appendSlice(allocator, "checks:\n");
    for (result.checks) |check| {
        try output.print(allocator, "- {s}: {s} - {s}\n", .{ check.name, checkStatusText(check.status), check.detail });
    }
    try output.append(allocator, '\n');

    try appendFixtureCatalogText(allocator, &output, fixture_catalog);
    try appendTextList(allocator, &output, "fixture validation checks", fixture_validation_checks);
    try appendTextList(allocator, &output, "implementation gates", implementation_gates);
    try appendTextList(allocator, &output, "non-goals", non_goals);
    try appendTextList(allocator, &output, "blocked claims", blocked_claims);
    try appendTextList(allocator, &output, "required verification commands", required_verification_commands);
    try appendTextList(allocator, &output, "verified commands", options.verified_commands);
    try appendTextList(allocator, &output, "agent guidance", agentGuidance(result.status));

    return output.toOwnedSlice(allocator);
}

fn appendBoundarySummaryJson(allocator: std.mem.Allocator, output: *std.ArrayList(u8), summary: BoundarySummary) !void {
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

fn appendFixtureCatalogJson(allocator: std.mem.Allocator, output: *std.ArrayList(u8), fixtures: []const LocalFixture) !void {
    try output.append(allocator, '[');
    for (fixtures, 0..) |fixture, index| {
        if (index > 0) try output.appendSlice(allocator, ", ");
        try output.appendSlice(allocator, "{ \"id\": ");
        try appendJsonString(allocator, output, fixture.id);
        try output.appendSlice(allocator, ", \"source_boundary_label\": ");
        try appendJsonString(allocator, output, fixture.source_boundary_label);
        try output.appendSlice(allocator, ", \"input_ref\": ");
        try appendJsonString(allocator, output, fixture.input_ref);
        try output.appendSlice(allocator, ", \"output_artifact\": ");
        try appendJsonString(allocator, output, fixture.output_artifact);
        try output.appendSlice(allocator, ", \"output_fields\": ");
        try appendStringArray(allocator, output, fixture.output_fields);
        try output.appendSlice(allocator, ", \"blocked_fields\": ");
        try appendStringArray(allocator, output, fixture.blocked_fields);
        try output.appendSlice(allocator, " }");
    }
    try output.append(allocator, ']');
}

fn appendFixtureCatalogText(allocator: std.mem.Allocator, output: *std.ArrayList(u8), fixtures: []const LocalFixture) !void {
    try output.appendSlice(allocator, "fixture catalog:\n");
    for (fixtures) |fixture| {
        try output.print(allocator, "- {s}: {s} | {s} -> {s}\n", .{ fixture.id, fixture.source_boundary_label, fixture.input_ref, fixture.output_artifact });
        try output.appendSlice(allocator, "  output fields:");
        for (fixture.output_fields) |field| try output.print(allocator, " {s}", .{field});
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
            "Ready local fixtures permit starting the app-facing NenDB handoff fixtures branch only.",
            "Cite source boundary proposal readiness fixtures fixture catalog validation checks and verification commands.",
            "Do not infer runtime integration live agent projections raw payload capture app mutation production NenDB writes CI gates non-NenDB adapters alternate renderers or deployment authority.",
        },
        .blocked => &.{
            "Blocked local fixtures must not start app-facing NenDB handoff fixture work.",
            "Repair boundary evidence fixture validation evidence or verification command evidence first.",
            "Do not infer app-facing implementation approval from blocked fixture evidence.",
        },
    };
}

fn usage() []const u8 {
    return "usage: zig build causal-app-facing-production-integration-local-fixtures -- --from-boundary <boundary.json> approve|reject --reason <reason> [--by <actor>] [--policy <policy>] [--verified-command <command>]... [--out-prefix <path-prefix>]\n";
}

fn failUsage(err: anyerror) noreturn {
    std.debug.print("causal-app-facing-production-integration-local-fixtures error: {s}\n{s}", .{ @errorName(err), usage() });
    std.process.exit(2);
}

fn readRequiredArtifact(io: std.Io, allocator: std.mem.Allocator, path: []const u8) ![]const u8 {
    return std.Io.Dir.cwd().readFileAlloc(io, path, allocator, .limited(1024 * 1024)) catch |err| switch (err) {
        error.FileNotFound => error.MissingBoundaryInput,
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
    const source_boundary_json = try readRequiredArtifact(init.io, allocator, options.boundary_path);
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

const boundary_approve_command =
    "zig build causal-app-facing-production-integration-boundary -- --from-proposal ../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures-readiness-review-implementation-proposal.json approve --reason \"proposal evidence reviewed for app-facing local fixtures\" --verified-command \"zig build causal-app-facing-production-integration-implementation-proposal -- --from-readiness ../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures-readiness-review.json approve --reason \\\"ready evidence reviewed for app-facing integration planning\\\" --verified-command \\\"zig build causal-app-facing-production-integration-readiness-review -- --from-fixtures ../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures.json approve --reason \\\\\\\"fixtures reviewed for implementation proposal\\\\\\\" --verified-command \\\\\\\"zig build causal-app-facing-production-integration-fixtures -- validate --format json\\\\\\\" --verified-command \\\\\\\"zig build causal-schema-governance -- --format json\\\\\\\" --verified-command \\\\\\\"zig build causal-production-hardening-backlog -- --format json\\\\\\\" --verified-command \\\\\\\"zig build examples\\\\\\\" --verified-command \\\\\\\"zig build test\\\\\\\"\\\" --verified-command \\\"zig build causal-schema-governance -- --format json\\\" --verified-command \\\"zig build causal-production-hardening-backlog -- --format json\\\" --verified-command \\\"zig build examples\\\" --verified-command \\\"zig build test\\\"\" --verified-command \"zig build causal-schema-governance -- --format json\" --verified-command \"zig build causal-production-hardening-backlog -- --format json\" --verified-command \"zig build examples\" --verified-command \"zig build test\"";

const required_verification_commands: []const []const u8 = &.{
    boundary_approve_command,
    "zig build causal-schema-governance -- --format json",
    "zig build causal-production-hardening-backlog -- --format json",
    "zig build examples",
    "zig build test",
};

const fixture_catalog: []const LocalFixture = &.{
    .{
        .id = "worker-request-runtime-ref-fixture",
        .source_boundary_label = "worker-request-runtime-ref-boundary",
        .input_ref = "worker-request-causal-event-ref",
        .output_artifact = "worker-request-runtime-ref-local-fixture",
        .output_fields = &.{ "trace_id_ref", "causal_event_ref", "route_ref", "redaction_state", "sample_state" },
        .blocked_fields = &.{ "raw_request_body", "headers", "credentials", "raw_pii", "app_mutation" },
    },
    .{
        .id = "background-job-runtime-ref-fixture",
        .source_boundary_label = "background-job-runtime-ref-boundary",
        .input_ref = "background-job-causal-event-ref",
        .output_artifact = "background-job-runtime-ref-local-fixture",
        .output_fields = &.{ "job_ref", "trace_id_ref", "causal_event_ref", "retry_ref", "redaction_state" },
        .blocked_fields = &.{ "raw_payload", "queue_body", "credentials", "app_mutation" },
    },
    .{
        .id = "agent-query-bounded-projection-fixture",
        .source_boundary_label = "agent-query-bounded-projection-boundary",
        .input_ref = "agent-query-request-ref",
        .output_artifact = "agent-query-bounded-projection-local-fixture",
        .output_fields = &.{ "query_ref", "trace_data_refs", "finding_refs", "next_query_refs", "truncation_state", "redaction_state" },
        .blocked_fields = &.{ "raw_payload_scrape", "unbounded_query", "raw_prompt", "raw_response" },
    },
    .{
        .id = "nendb-history-handoff-ref-fixture",
        .source_boundary_label = "nendb-history-handoff-ref-boundary",
        .input_ref = "nendb-history-handoff-request-ref",
        .output_artifact = "nendb-history-handoff-ref-local-fixture",
        .output_fields = &.{ "nendb_node_ref", "nendb_edge_ref", "trace_ref", "artifact_ref", "handoff_state=ref-only" },
        .blocked_fields = &.{ "nendb_write", "durable_payload", "production_history_mutation", "cockroach_adapter" },
    },
    .{
        .id = "audit-remediation-review-link-fixture",
        .source_boundary_label = "audit-remediation-review-link-boundary",
        .input_ref = "audit-remediation-review-request-ref",
        .output_artifact = "audit-remediation-review-link-local-fixture",
        .output_fields = &.{ "audit_chain_ref", "remediation_review_ref", "comparison_ref", "evidence_state=review-only" },
        .blocked_fields = &.{ "mutation_proof_claim", "auto_apply", "fixed_claim", "deployed_claim" },
    },
    .{
        .id = "solid-webui-readonly-preview-fixture",
        .source_boundary_label = "solid-webui-readonly-handoff-boundary",
        .input_ref = "solid-webui-preview-request-ref",
        .output_artifact = "solid-webui-readonly-preview-local-fixture",
        .output_fields = &.{ "webui_sample_ref", "solid_view_ref", "read_only_state", "selection_ref", "artifact_ref" },
        .blocked_fields = &.{ "live_dashboard_host", "app_mutation_button", "react_renderer", "alternate_renderer" },
    },
    .{
        .id = "ci-advisory-artifact-preview-fixture",
        .source_boundary_label = "ci_state=advisory-artifacts-only",
        .input_ref = "ci-advisory-artifact-request-ref",
        .output_artifact = "ci-advisory-artifact-preview-local-fixture",
        .output_fields = &.{ "ci_artifact_ref", "advisory_status_ref", "local_report_ref", "non_blocking_state" },
        .blocked_fields = &.{ "required_status_check", "ci_gate_enforcement", "workflow_mutation", "github_api_mutation" },
    },
};

const fixture_validation_checks: []const []const u8 = &.{
    "fixture-satisfies-boundary-label",
    "fixture-declares-input-ref",
    "fixture-declares-output-artifact",
    "runtime-refs-block-raw-payloads",
    "agent-query-projection-is-bounded",
    "nendb-handoff-is-ref-only",
    "audit-remediation-review-only",
    "solid-webui-preview-read-only",
    "ci-artifacts-advisory-only",
    "raw-sensitive-fields-blocked",
    "production-mutation-fields-blocked",
};

const implementation_gates: []const []const u8 = &.{
    "source app-facing boundary artifact is approved",
    "source boundary checks and verification commands remain pass",
    "local fixtures emit refs and artifact labels only",
    "runtime refs block raw payload capture and app mutation",
    "agent query fixtures stay bounded to trace data refs finding refs and next-query refs",
    "NenDB handoff is ref-only and performs no writes",
    "audit remediation does not prove mutation application or deployment",
    "SolidJS workbench preview remains read-only and local",
    "CI artifacts remain advisory and do not enforce gates",
    "NenDB handoff fixtures must be reviewed before durable work",
};

const non_goals: []const []const u8 = &.{
    "App runtime integration or instrumentation changes",
    "Live agent query projection over production app data",
    "Raw app payload capture",
    "App runtime mutation authority",
    "App config writes",
    "App data writes",
    "Deployment rollout rollback or registry mutation",
    "Live production telemetry ingestion",
    "Durable production writes",
    "NenDB production writes",
    "Non-NenDB durable adapter work",
    "Cockroach adapter work",
    "CI enforcement gates or required status checks",
    "Production dashboards streaming hosted workbench or live app view",
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
    "nendb-production-write",
    "audit-chain-compare-as-mutation-proof",
    "app-remediation-auto-apply",
    "fixed-deployed-integrated-claim",
    "live-exporter-enabled",
    "network-send-enabled",
    "collector-endpoint-configured",
    "otlp-serialization-enabled",
    "durable-production-write-enabled",
    "non-nendb-durable-storage",
    "cockroach-adapter-work",
    "ci-enforcement-gate",
    "react-or-alternate-renderer",
    "mutation-authority-granted",
};

test "app-facing local fixture schema and authority constants are stable" {
    try std.testing.expectEqualStrings("zigeffect.causal.app-facing-production-integration-local-fixtures.v1", app_facing_production_integration_local_fixtures_schema);
    try std.testing.expectEqual(@as(u32, 1), app_facing_production_integration_local_fixtures_schema_version);
    try std.testing.expectEqualStrings("codex/zigeffect-causal-app-facing-production-integration-local-fixtures", source_branch);
    try std.testing.expectEqualStrings("start-app-facing-production-integration-nendb-handoff-fixtures", recommendation);
    try std.testing.expectEqualStrings("codex/zigeffect-causal-app-facing-production-integration-nendb-handoff-fixtures", next_branch_if_ready);
    try std.testing.expectEqualStrings("zigeffect.causal.app-facing-production-integration-boundary.v1", boundary_schema);
    try std.testing.expectEqualStrings("causal-app-facing-production-integration-local-fixtures", generated_by);
    try std.testing.expect(!applied);
    try std.testing.expectEqualStrings("none", mutation_authority);
    try std.testing.expect(!production_telemetry_ingestion);
    try std.testing.expect(!live_exporter_enabled);
    try std.testing.expect(!network_send_enabled);
    try std.testing.expect(!collector_endpoint_configured);
    try std.testing.expect(!otlp_serialization_enabled);
    try std.testing.expect(!durable_write_enabled);
    try std.testing.expect(!app_mutation_enabled);
    try std.testing.expect(!ci_gate_enabled);
    try std.testing.expect(!raw_payload_capture_enabled);
    try std.testing.expect(!app_config_write_enabled);
    try std.testing.expect(!app_data_write_enabled);
    try std.testing.expect(!deployment_mutation_enabled);
    try std.testing.expect(!nendb_write_enabled);
    try std.testing.expect(!app_runtime_integration_enabled);
    try std.testing.expect(!agent_query_live_projection_enabled);
    try std.testing.expect(!solid_webui_preview_enabled);
    try std.testing.expect(local_fixture_mode);
    try std.testing.expect(hasLocalFixture("worker-request-runtime-ref-fixture"));
    try std.testing.expect(hasLocalFixture("nendb-history-handoff-ref-fixture"));
    try std.testing.expect(hasLocalFixture("ci-advisory-artifact-preview-fixture"));
}

test "parses approve fixture options with verified commands and output prefix" {
    var options = try parseOptions(std.testing.allocator, &.{
        "zigeffect-causal-app-facing-production-integration-local-fixtures",
        "--from-boundary",
        ".zig-cache/causal-artifacts/boundary.json",
        "approve",
        "--reason",
        "boundary evidence reviewed",
        "--by",
        "codex",
        "--policy",
        "manual-app-facing-production-integration-local-fixtures",
        "--verified-command",
        "zig build test",
        "--out-prefix",
        ".zig-cache/causal-artifacts/custom-local-fixtures",
    });
    defer options.deinit(std.testing.allocator);

    try std.testing.expectEqual(Decision.approve, options.decision);
    try std.testing.expectEqualStrings(".zig-cache/causal-artifacts/boundary.json", options.boundary_path);
    try std.testing.expectEqualStrings("boundary evidence reviewed", options.reason);
    try std.testing.expectEqualStrings("codex", options.reviewed_by);
    try std.testing.expectEqualStrings("manual-app-facing-production-integration-local-fixtures", options.policy);
    try std.testing.expectEqual(@as(usize, 1), options.verified_commands.len);
    try std.testing.expectEqualStrings("zig build test", options.verified_commands[0]);
    try std.testing.expectEqualStrings(".zig-cache/causal-artifacts/custom-local-fixtures", options.out_prefix.?);
}

test "rejects missing boundary path decision and reason" {
    try std.testing.expectError(
        error.MissingBoundaryPath,
        parseOptions(std.testing.allocator, &.{"zigeffect-causal-app-facing-production-integration-local-fixtures"}),
    );
    try std.testing.expectError(
        error.InvalidBoundaryPath,
        parseOptions(std.testing.allocator, &.{ "zigeffect-causal-app-facing-production-integration-local-fixtures", "--from-boundary", "boundary.txt", "approve", "--reason", "reviewed" }),
    );
    try std.testing.expectError(
        error.MissingDecision,
        parseOptions(std.testing.allocator, &.{ "zigeffect-causal-app-facing-production-integration-local-fixtures", "--from-boundary", "boundary.json" }),
    );
    try std.testing.expectError(
        error.UnknownDecision,
        parseOptions(std.testing.allocator, &.{ "zigeffect-causal-app-facing-production-integration-local-fixtures", "--from-boundary", "boundary.json", "maybe", "--reason", "reviewed" }),
    );
    try std.testing.expectError(
        error.MissingReason,
        parseOptions(std.testing.allocator, &.{ "zigeffect-causal-app-facing-production-integration-local-fixtures", "--from-boundary", "boundary.json", "approve" }),
    );
}

test "derives local fixture output paths from boundary json path" {
    const derived = try outputPathsForOptions(std.testing.allocator, .{
        .boundary_path = ".zig-cache/causal-artifacts/app-facing-production-integration-fixtures-readiness-review-implementation-proposal-app-facing-boundary.json",
        .decision = .approve,
        .reason = "reviewed",
    });
    defer derived.deinit(std.testing.allocator);
    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/app-facing-production-integration-fixtures-readiness-review-implementation-proposal-app-facing-boundary-local-fixtures.json",
        derived.json_path,
    );
    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/app-facing-production-integration-fixtures-readiness-review-implementation-proposal-app-facing-boundary-local-fixtures.txt",
        derived.text_path,
    );

    const custom = try outputPathsForOptions(std.testing.allocator, .{
        .boundary_path = ".zig-cache/causal-artifacts/boundary.json",
        .decision = .approve,
        .reason = "reviewed",
        .out_prefix = ".zig-cache/causal-artifacts/custom-local-fixtures",
    });
    defer custom.deinit(std.testing.allocator);
    try std.testing.expectEqualStrings(".zig-cache/causal-artifacts/custom-local-fixtures.json", custom.json_path);
    try std.testing.expectEqualStrings(".zig-cache/causal-artifacts/custom-local-fixtures.txt", custom.text_path);
}

test "ready and blocked app-facing local fixture reports preserve fixture-only authority" {
    const ready = try formatReports(std.testing.allocator, .{
        .options = .{
            .boundary_path = "boundary.json",
            .decision = .approve,
            .reason = "boundary evidence reviewed",
            .verified_commands = required_verification_commands,
        },
        .source_boundary_json = sample_boundary_json,
    });
    defer ready.deinit(std.testing.allocator);

    try std.testing.expect(std.mem.indexOf(u8, ready.json, "\"schema\": \"zigeffect.causal.app-facing-production-integration-local-fixtures.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, ready.json, "\"fixture_status\": \"ready\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, ready.json, "\"ready_for_next_branch\": true") != null);
    try std.testing.expect(std.mem.indexOf(u8, ready.json, "\"local_fixture_mode\": true") != null);
    try std.testing.expect(std.mem.indexOf(u8, ready.json, "\"app_runtime_integration_enabled\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, ready.json, "\"agent_query_live_projection_enabled\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, ready.json, "\"solid_webui_preview_enabled\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, ready.json, "\"nendb_write_enabled\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, ready.json, "\"fixture_catalog\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, ready.json, "worker-request-runtime-ref-fixture") != null);
    try std.testing.expect(std.mem.indexOf(u8, ready.json, "agent-query-bounded-projection-fixture") != null);
    try std.testing.expect(std.mem.indexOf(u8, ready.json, "nendb-history-handoff-ref-fixture") != null);
    try std.testing.expect(std.mem.indexOf(u8, ready.json, "audit-remediation-review-link-fixture") != null);
    try std.testing.expect(std.mem.indexOf(u8, ready.json, "solid-webui-readonly-preview-fixture") != null);
    try std.testing.expect(std.mem.indexOf(u8, ready.json, "ci-advisory-artifact-preview-fixture") != null);
    try std.testing.expect(std.mem.indexOf(u8, ready.text, "fixture_status: ready") != null);
    try std.testing.expect(std.mem.indexOf(u8, ready.text, "local fixture mode: true") != null);
    try std.testing.expect(std.mem.indexOf(u8, ready.text, "app runtime integration enabled: false") != null);
    try std.testing.expect(std.mem.indexOf(u8, ready.text, "next branch if ready: codex/zigeffect-causal-app-facing-production-integration-nendb-handoff-fixtures") != null);

    const blocked = try formatReports(std.testing.allocator, .{
        .options = .{
            .boundary_path = "boundary.json",
            .decision = .reject,
            .reason = "negative fixture path",
        },
        .source_boundary_json = sample_boundary_json,
    });
    defer blocked.deinit(std.testing.allocator);

    try std.testing.expect(std.mem.indexOf(u8, blocked.json, "\"fixture_status\": \"blocked\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, blocked.json, "\"ready_for_next_branch\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, blocked.json, "\"app_runtime_integration_enabled\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, blocked.json, "\"local_fixture_mode\": true") != null);
    try std.testing.expect(std.mem.indexOf(u8, blocked.text, "fixture_status: blocked") != null);
}

test "app-facing local fixtures block unsupported source boundary schema" {
    const bad_schema_json = try std.mem.replaceOwned(
        u8,
        std.testing.allocator,
        sample_boundary_json,
        "zigeffect.causal.app-facing-production-integration-boundary.v1",
        "zigeffect.causal.unsupported.v1",
    );
    defer std.testing.allocator.free(bad_schema_json);

    try expectBlockedBy(bad_schema_json, "boundary-schema");
}

test "app-facing local fixtures block failed source checks and authority drift" {
    const failed_check_json = try std.mem.replaceOwned(
        u8,
        std.testing.allocator,
        sample_boundary_json,
        "\"app-runtime-ref-boundary\", \"status\": \"pass\"",
        "\"app-runtime-ref-boundary\", \"status\": \"fail\"",
    );
    defer std.testing.allocator.free(failed_check_json);
    try expectBlockedBy(failed_check_json, "boundary-checks-passed");

    const authority_drift_json = try std.mem.replaceOwned(
        u8,
        std.testing.allocator,
        sample_boundary_json,
        "\"app_mutation_enabled\": false",
        "\"app_mutation_enabled\": true",
    );
    defer std.testing.allocator.free(authority_drift_json);
    try expectBlockedBy(authority_drift_json, "authority-boundary");
}

test "app-facing local fixtures block missing verification evidence and projection labels" {
    const missing_boundary_verification = try formatReports(std.testing.allocator, .{
        .options = .{
            .boundary_path = "boundary.json",
            .decision = .approve,
            .reason = "boundary evidence reviewed",
            .verified_commands = required_verification_commands,
        },
        .source_boundary_json = sample_boundary_missing_boundary_verification_json,
    });
    defer missing_boundary_verification.deinit(std.testing.allocator);

    try std.testing.expect(std.mem.indexOf(u8, missing_boundary_verification.json, "\"fixture_status\": \"blocked\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, missing_boundary_verification.json, "\"name\": \"boundary-verification-recorded\", \"status\": \"fail\"") != null);

    const missing_fixture_verification = try formatReports(std.testing.allocator, .{
        .options = .{
            .boundary_path = "boundary.json",
            .decision = .approve,
            .reason = "boundary evidence reviewed",
            .verified_commands = &.{"zig build test"},
        },
        .source_boundary_json = sample_boundary_json,
    });
    defer missing_fixture_verification.deinit(std.testing.allocator);

    try std.testing.expect(std.mem.indexOf(u8, missing_fixture_verification.json, "\"fixture_status\": \"blocked\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, missing_fixture_verification.json, "\"name\": \"fixture-verification-recorded\", \"status\": \"fail\"") != null);

    const missing_projection_json = try std.mem.replaceOwned(
        u8,
        std.testing.allocator,
        sample_boundary_json,
        "solid-webui-readonly-handoff-boundary",
        "solid-webui-missing-boundary",
    );
    defer std.testing.allocator.free(missing_projection_json);
    try expectBlockedBy(missing_projection_json, "projection-fixtures-present");
}

fn expectBlockedBy(source_boundary_json: []const u8, check_name: []const u8) !void {
    const reports = try formatReports(std.testing.allocator, .{
        .options = .{
            .boundary_path = "boundary.json",
            .decision = .approve,
            .reason = "boundary evidence reviewed",
            .verified_commands = required_verification_commands,
        },
        .source_boundary_json = source_boundary_json,
    });
    defer reports.deinit(std.testing.allocator);

    const failed_check = try std.fmt.allocPrint(std.testing.allocator, "\"name\": \"{s}\", \"status\": \"fail\"", .{check_name});
    defer std.testing.allocator.free(failed_check);

    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"fixture_status\": \"blocked\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, failed_check) != null);
}

const sample_boundary_json =
    \\{
    \\  "schema": "zigeffect.causal.app-facing-production-integration-boundary.v1",
    \\  "schema_version": 1,
    \\  "source_proposal": "../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures-readiness-review-implementation-proposal.json",
    \\  "source_readiness": "../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures-readiness-review.json",
    \\  "source_fixtures": "../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures.json",
    \\  "decision": "approve",
    \\  "boundary_status": "approved",
    \\  "approved_for_next_branch": true,
    \\  "reviewed_by": "local-boundary-reviewer",
    \\  "policy": "manual-app-facing-production-integration-boundary",
    \\  "reason": "proposal evidence reviewed for app-facing local fixtures",
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
    \\  "proposal_summary": { "source_contract_count": 6, "positive_fixture_count": 6, "negative_fixture_count": 15, "validation_check_count": 8 },
    \\  "checks": [
    \\    { "name": "proposal-schema", "status": "pass", "detail": "source proposal schema is supported" },
    \\    { "name": "proposal-status", "status": "pass", "detail": "source proposal is approved for app-facing integration boundary work" },
    \\    { "name": "proposal-decision-approved", "status": "pass", "detail": "source proposal decision approved the handoff" },
    \\    { "name": "boundary-decision", "status": "pass", "detail": "boundary decision includes a reason" },
    \\    { "name": "decision-approved", "status": "pass", "detail": "boundary decision must approve app-facing local fixture handoff" },
    \\    { "name": "authority-boundary", "status": "pass", "detail": "source proposal and app-facing integration boundary authority fields remain disabled" },
    \\    { "name": "source-chain-linked", "status": "pass", "detail": "proposal links readiness and fixture JSON artifacts" },
    \\    { "name": "proposal-checks-passed", "status": "pass", "detail": "all required source proposal checks passed" },
    \\    { "name": "proposal-phase-handoff", "status": "pass", "detail": "proposal includes app runtime agent query and NenDB handoff phases" },
    \\    { "name": "proposal-verification-recorded", "status": "pass", "detail": "source proposal recorded required verification command evidence" },
    \\    { "name": "boundary-verification-recorded", "status": "pass", "detail": "boundary review recorded every required verification command" },
    \\    { "name": "app-runtime-ref-boundary", "status": "pass", "detail": "app runtime contract uses refs only and blocks raw payload capture" },
    \\    { "name": "agent-query-projection-boundary", "status": "pass", "detail": "agent query projection remains bounded to redacted trace evidence" },
    \\    { "name": "nendb-handoff-boundary", "status": "pass", "detail": "NenDB handoff remains reference-only with no production writes" },
    \\    { "name": "audit-remediation-boundary", "status": "pass", "detail": "audit remediation evidence remains review-only and cannot prove mutation" },
    \\    { "name": "no-production-mutation-boundary", "status": "pass", "detail": "app config app data deployment NenDB write and app mutation authority stay disabled" },
    \\    { "name": "nendb-only-scope", "status": "pass", "detail": "durable direction remains future NenDB-only scope" },
    \\    { "name": "solid-webui-scope", "status": "pass", "detail": "workbench direction remains SolidJS inside webui-dev/zig-webui" }
    \\  ],
    \\  "app_boundary_contract": [
    \\    "boundary_id=app-facing-production-integration-guarded",
    \\    "source_contract=app-runtime",
    \\    "trace_ref_state=ref-only",
    \\    "raw_payload_state=blocked",
    \\    "app_mutation_state=disabled",
    \\    "agent_query_state=bounded-trace-data-only",
    \\    "nendb_handoff_state=ref-only-no-production-write",
    \\    "audit_compare_state=evidence-only-not-mutation-proof",
    \\    "remediation_governance_state=handoff-only",
    \\    "solid_webui_state=read-only-preview-only",
    \\    "ci_state=advisory-artifacts-only"
    \\  ],
    \\  "local_projection_fixtures": [
    \\    "worker-request-runtime-ref-boundary",
    \\    "background-job-runtime-ref-boundary",
    \\    "agent-query-bounded-projection-boundary",
    \\    "nendb-history-handoff-ref-boundary",
    \\    "audit-remediation-review-link-boundary",
    \\    "solid-webui-readonly-handoff-boundary"
    \\  ],
    \\  "non_goals": [
    \\    "App runtime integration or instrumentation changes",
    \\    "Raw app payload capture",
    \\    "App runtime mutation authority",
    \\    "Non-NenDB durable adapter work",
    \\    "Cockroach adapter work",
    \\    "React or alternate renderer work"
    \\  ],
    \\  "blocked_claims": [
    \\    "app-runtime-integration-enabled",
    \\    "app-mutation-enabled",
    \\    "raw-payload-capture-enabled",
    \\    "nendb-production-write",
    \\    "non-nendb-durable-storage",
    \\    "cockroach-adapter-work",
    \\    "react-or-alternate-renderer"
    \\  ],
    \\  "required_verification_commands": [
    \\    "zig build causal-app-facing-production-integration-implementation-proposal",
    \\    "zig build causal-schema-governance -- --format json",
    \\    "zig build causal-production-hardening-backlog -- --format json",
    \\    "zig build examples",
    \\    "zig build test"
    \\  ],
    \\  "verified_commands": [
    \\    "zig build causal-app-facing-production-integration-implementation-proposal",
    \\    "zig build causal-schema-governance -- --format json",
    \\    "zig build causal-production-hardening-backlog -- --format json",
    \\    "zig build examples",
    \\    "zig build test"
    \\  ]
    \\}
;

const sample_boundary_missing_boundary_verification_json =
    \\{
    \\  "schema": "zigeffect.causal.app-facing-production-integration-boundary.v1",
    \\  "schema_version": 1,
    \\  "source_proposal": "../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures-readiness-review-implementation-proposal.json",
    \\  "source_readiness": "../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures-readiness-review.json",
    \\  "source_fixtures": "../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures.json",
    \\  "decision": "approve",
    \\  "boundary_status": "approved",
    \\  "approved_for_next_branch": true,
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
    \\  "proposal_summary": { "source_contract_count": 6, "positive_fixture_count": 6, "negative_fixture_count": 15, "validation_check_count": 8 },
    \\  "checks": [
    \\    { "name": "proposal-schema", "status": "pass" },
    \\    { "name": "proposal-status", "status": "pass" },
    \\    { "name": "proposal-decision-approved", "status": "pass" },
    \\    { "name": "boundary-decision", "status": "pass" },
    \\    { "name": "decision-approved", "status": "pass" },
    \\    { "name": "authority-boundary", "status": "pass" },
    \\    { "name": "source-chain-linked", "status": "pass" },
    \\    { "name": "proposal-checks-passed", "status": "pass" },
    \\    { "name": "proposal-phase-handoff", "status": "pass" },
    \\    { "name": "proposal-verification-recorded", "status": "pass" },
    \\    { "name": "boundary-verification-recorded", "status": "pass" },
    \\    { "name": "app-runtime-ref-boundary", "status": "pass" },
    \\    { "name": "agent-query-projection-boundary", "status": "pass" },
    \\    { "name": "nendb-handoff-boundary", "status": "pass" },
    \\    { "name": "audit-remediation-boundary", "status": "pass" },
    \\    { "name": "no-production-mutation-boundary", "status": "pass" },
    \\    { "name": "nendb-only-scope", "status": "pass" },
    \\    { "name": "solid-webui-scope", "status": "pass" }
    \\  ],
    \\  "app_boundary_contract": [
    \\    "boundary_id=app-facing-production-integration-guarded",
    \\    "source_contract=app-runtime",
    \\    "trace_ref_state=ref-only",
    \\    "raw_payload_state=blocked",
    \\    "app_mutation_state=disabled",
    \\    "agent_query_state=bounded-trace-data-only",
    \\    "nendb_handoff_state=ref-only-no-production-write",
    \\    "audit_compare_state=evidence-only-not-mutation-proof",
    \\    "remediation_governance_state=handoff-only",
    \\    "solid_webui_state=read-only-preview-only",
    \\    "ci_state=advisory-artifacts-only"
    \\  ],
    \\  "local_projection_fixtures": [
    \\    "worker-request-runtime-ref-boundary",
    \\    "background-job-runtime-ref-boundary",
    \\    "agent-query-bounded-projection-boundary",
    \\    "nendb-history-handoff-ref-boundary",
    \\    "audit-remediation-review-link-boundary",
    \\    "solid-webui-readonly-handoff-boundary"
    \\  ],
    \\  "required_verification_commands": [
    \\    "zig build causal-app-facing-production-integration-implementation-proposal",
    \\    "zig build causal-schema-governance -- --format json",
    \\    "zig build causal-production-hardening-backlog -- --format json",
    \\    "zig build examples",
    \\    "zig build test"
    \\  ],
    \\  "verified_commands": [
    \\    "zig build test"
    \\  ]
    \\}
;
