const std = @import("std");

pub const production_telemetry_local_pipeline_fixtures_schema = "zigeffect.causal.production-telemetry-local-pipeline-fixtures.v1";
pub const production_telemetry_local_pipeline_fixtures_schema_version: u32 = 1;
pub const source_branch = "codex/zigeffect-causal-production-telemetry-local-pipeline-fixtures";
pub const recommendation = "start-production-telemetry-nendb-retention-fixtures";
pub const next_branch_if_ready = "codex/zigeffect-causal-production-telemetry-nendb-retention-fixtures";

const boundary_schema = "zigeffect.causal.production-telemetry-exporter-boundary.v1";
const generated_by = "causal-production-telemetry-local-pipeline-fixtures";
const applied = false;
const mutation_authority = "none";
const production_telemetry_ingestion = false;
const live_exporter_enabled = false;
const network_send_enabled = false;
const collector_endpoint_configured = false;
const otlp_serialization_enabled = false;
const durable_write_enabled = false;
const ci_gate_enabled = false;
const runtime_pipeline_enabled = false;
const local_pipeline_fixture_mode = true;

const Decision = enum { approve, reject };
const FixtureStatus = enum { ready, blocked };
const CheckStatus = enum { pass, fail };

const Options = struct {
    boundary_path: []const u8,
    decision: Decision,
    reviewed_by: []const u8 = "local-pipeline-reviewer",
    policy: []const u8 = "manual-production-telemetry-local-pipeline-fixtures",
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
    ci_gate_enabled: bool,
    proposal_summary: BoundarySummary = .{},
    checks: []const BoundaryCheck = &.{},
    exporter_boundary_contract: []const []const u8 = &.{},
    local_envelope_fixtures: []const []const u8 = &.{},
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

    var reviewed_by: []const u8 = "local-pipeline-reviewer";
    var policy: []const u8 = "manual-production-telemetry-local-pipeline-fixtures";
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
        break :blk try std.fmt.allocPrint(allocator, "{s}-local-pipeline-fixtures", .{base});
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
    try appendCheck(allocator, &checks, "boundary-status", if (std.mem.eql(u8, boundary.boundary_status, "approved") and boundary.approved_for_next_branch) .pass else .fail, "source boundary is approved for local pipeline fixture work");
    try appendCheck(allocator, &checks, "boundary-decision-approved", if (std.mem.eql(u8, boundary.decision, "approve")) .pass else .fail, "source boundary decision approved the handoff");
    try appendCheck(allocator, &checks, "fixture-decision", if (options.reason.len > 0) .pass else .fail, "fixture decision includes a reason");
    try appendCheck(allocator, &checks, "decision-approved", if (options.decision == .approve) .pass else .fail, "fixture decision must approve NenDB retention fixture handoff");
    try appendCheck(allocator, &checks, "authority-boundary", if (authorityBoundaryIntact(boundary)) .pass else .fail, "source boundary and local pipeline fixture authority fields remain disabled");
    try appendCheck(allocator, &checks, "no-network-pipeline", if (noNetworkPipeline(boundary)) .pass else .fail, "network send collector endpoint and transport stay disabled");
    try appendCheck(allocator, &checks, "no-otlp-serialization", if (noOtlpSerialization(boundary)) .pass else .fail, "OTLP serialization stays out of scope");
    try appendCheck(allocator, &checks, "no-durable-write", if (noDurableWrite(boundary)) .pass else .fail, "durable production writes remain disabled");
    try appendCheck(allocator, &checks, "source-chain-linked", if (sourceChainLinked(boundary)) .pass else .fail, "boundary links proposal readiness and fixture JSON artifacts");
    try appendCheck(allocator, &checks, "boundary-checks-passed", if (boundaryChecksPassed(boundary.checks)) .pass else .fail, "all required source boundary checks passed");
    try appendCheck(allocator, &checks, "boundary-contract-present", if (boundaryContractPresent(boundary.exporter_boundary_contract)) .pass else .fail, "source boundary contract contains no-network fields");
    try appendCheck(allocator, &checks, "envelope-fixtures-present", if (envelopeFixturesPresent(boundary.local_envelope_fixtures)) .pass else .fail, "source boundary lists all required envelope fixtures");
    try appendCheck(allocator, &checks, "pipeline-fixtures-present", if (pipelineFixturesPresent()) .pass else .fail, "local pipeline fixture catalog contains required fixtures");
    try appendCheck(allocator, &checks, "redaction-fixtures-present", if (redactionFixturesPresent()) .pass else .fail, "local pipeline fixtures include redaction and access evidence");
    try appendCheck(allocator, &checks, "sampling-fixtures-present", if (samplingFixturesPresent()) .pass else .fail, "local pipeline fixtures include kept and dropped sampling evidence");
    try appendCheck(allocator, &checks, "pipeline-validation-passed", if (pipelineValidationPassed()) .pass else .fail, "all local pipeline validation checks passed");
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
        !boundary.ci_gate_enabled and
        !applied and
        std.mem.eql(u8, mutation_authority, "none") and
        !production_telemetry_ingestion and
        !live_exporter_enabled and
        !network_send_enabled and
        !collector_endpoint_configured and
        !otlp_serialization_enabled and
        !durable_write_enabled and
        !ci_gate_enabled and
        !runtime_pipeline_enabled and
        local_pipeline_fixture_mode;
}

fn noNetworkPipeline(boundary: BoundaryArtifact) bool {
    return !boundary.network_send_enabled and
        !boundary.collector_endpoint_configured and
        !network_send_enabled and
        !collector_endpoint_configured and
        boundaryContractPresent(boundary.exporter_boundary_contract);
}

fn noOtlpSerialization(boundary: BoundaryArtifact) bool {
    return !boundary.otlp_serialization_enabled and
        !otlp_serialization_enabled and
        containsString(boundary.exporter_boundary_contract, "serialization_state=boundary-json-only-not-otlp");
}

fn noDurableWrite(boundary: BoundaryArtifact) bool {
    return !boundary.durable_write_enabled and !durable_write_enabled;
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
        "no-network-boundary",
        "no-otlp-serialization",
        "source-chain-linked",
        "proposal-checks-passed",
        "proposal-phase-handoff",
        "proposal-verification-recorded",
        "boundary-verification-recorded",
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
    return containsString(contract, "boundary_id=exporter-neutral-no-network") and
        containsString(contract, "input_contract=redacted-causal-otel-record-or-fixture-ref") and
        containsString(contract, "output_contract=local-export-envelope-fixture") and
        containsString(contract, "transport_state=disabled") and
        containsString(contract, "network_state=disabled") and
        containsString(contract, "collector_endpoint_state=not-configured") and
        containsString(contract, "serialization_state=boundary-json-only-not-otlp") and
        containsString(contract, "durable_write_state=disabled") and
        containsString(contract, "review_gate=local-pipeline-fixtures-review");
}

fn envelopeFixturesPresent(envelopes: []const []const u8) bool {
    const required = [_][]const u8{
        "runtime-span-event-envelope",
        "app-semantic-ref-envelope",
        "backend-otel-record-envelope",
        "redaction-access-envelope",
        "sampling-boundary-envelope",
    };
    for (required) |name| {
        if (!containsString(envelopes, name)) return false;
    }
    return true;
}

fn pipelineFixturesPresent() bool {
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
        if (!hasPipelineFixture(id)) return false;
    }
    return pipeline_fixture_catalog.len == required.len;
}

fn redactionFixturesPresent() bool {
    return fixtureBlocksField("runtime-span-normalized-envelope", "raw_payload") and
        fixtureBlocksField("app-semantic-normalized-envelope", "raw_request_body") and
        fixtureBlocksField("redaction-access-reviewed-envelope", "raw_secrets") and
        fixtureHasOutputField("redaction-access-reviewed-envelope", "redaction_state") and
        fixtureHasOutputField("redaction-access-reviewed-envelope", "access_policy_ref");
}

fn samplingFixturesPresent() bool {
    return hasPipelineFixture("sampling-kept-envelope") and
        hasPipelineFixture("sampling-dropped-envelope") and
        fixtureHasOutputField("sampling-kept-envelope", "sample_state=kept") and
        fixtureHasOutputField("sampling-dropped-envelope", "sample_state=dropped") and
        fixtureBlocksField("sampling-dropped-envelope", "unsampled_raw_payload_fields");
}

fn pipelineValidationPassed() bool {
    return containsString(pipeline_validation_checks, "fixture-references-source-envelope") and
        containsString(pipeline_validation_checks, "fixture-declares-output-envelope") and
        containsString(pipeline_validation_checks, "fixture-declares-redaction-state") and
        containsString(pipeline_validation_checks, "fixture-declares-sample-state") and
        containsString(pipeline_validation_checks, "raw-sensitive-fields-blocked") and
        containsString(pipeline_validation_checks, "network-and-exporter-fields-blocked") and
        containsString(pipeline_validation_checks, "otlp-protobuf-absent") and
        containsString(pipeline_validation_checks, "durable-write-fields-absent") and
        containsString(pipeline_validation_checks, "sampled-out-retains-metadata-only") and
        containsString(pipeline_validation_checks, "correlation-uses-refs-only") and
        pipelineFixturesPresent() and
        redactionFixturesPresent() and
        samplingFixturesPresent() and
        fixtureBlocksField("backend-otel-local-envelope", "collector_endpoint") and
        fixtureBlocksField("backend-otel-local-envelope", "wire_payload_bytes") and
        fixtureBlocksField("correlation-link-envelope", "raw_payload_joins");
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

fn hasPipelineFixture(id: []const u8) bool {
    for (pipeline_fixture_catalog) |fixture| {
        if (std.mem.eql(u8, fixture.id, id)) return true;
    }
    return false;
}

fn fixtureHasOutputField(id: []const u8, field: []const u8) bool {
    for (pipeline_fixture_catalog) |fixture| {
        if (std.mem.eql(u8, fixture.id, id)) return containsString(fixture.output_fields, field);
    }
    return false;
}

fn fixtureBlocksField(id: []const u8, field: []const u8) bool {
    for (pipeline_fixture_catalog) |fixture| {
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
    try appendJsonString(allocator, &output, production_telemetry_local_pipeline_fixtures_schema);
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
    try output.print(allocator, "  \"ci_gate_enabled\": {},\n", .{ci_gate_enabled});
    try output.print(allocator, "  \"runtime_pipeline_enabled\": {},\n", .{runtime_pipeline_enabled});
    try output.print(allocator, "  \"local_pipeline_fixture_mode\": {},\n", .{local_pipeline_fixture_mode});
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
    try output.appendSlice(allocator, ",\n  \"pipeline_fixture_catalog\": ");
    try appendPipelineFixtureCatalogJson(allocator, &output, pipeline_fixture_catalog);
    try output.appendSlice(allocator, ",\n  \"pipeline_validation_checks\": ");
    try appendStringArray(allocator, &output, pipeline_validation_checks);
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

    try output.appendSlice(allocator, "zigeffect production telemetry local pipeline fixtures\n");
    try output.print(allocator, "schema: {s}\n", .{production_telemetry_local_pipeline_fixtures_schema});
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
    try output.print(allocator, "ci gate enabled: {}\n", .{ci_gate_enabled});
    try output.print(allocator, "runtime pipeline enabled: {}\n", .{runtime_pipeline_enabled});
    try output.print(allocator, "local pipeline fixture mode: {}\n", .{local_pipeline_fixture_mode});
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

    try appendPipelineFixtureCatalogText(allocator, &output, pipeline_fixture_catalog);
    try appendTextList(allocator, &output, "pipeline validation checks", pipeline_validation_checks);
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

fn appendPipelineFixtureCatalogJson(allocator: std.mem.Allocator, output: *std.ArrayList(u8), fixtures: []const PipelineFixture) !void {
    try output.append(allocator, '[');
    for (fixtures, 0..) |fixture, index| {
        if (index > 0) try output.appendSlice(allocator, ", ");
        try output.appendSlice(allocator, "{ \"id\": ");
        try appendJsonString(allocator, output, fixture.id);
        try output.appendSlice(allocator, ", \"input_envelope\": ");
        try appendJsonString(allocator, output, fixture.input_envelope);
        try output.appendSlice(allocator, ", \"output_envelope\": ");
        try appendJsonString(allocator, output, fixture.output_envelope);
        try output.appendSlice(allocator, ", \"output_fields\": ");
        try appendStringArray(allocator, output, fixture.output_fields);
        try output.appendSlice(allocator, ", \"blocked_fields\": ");
        try appendStringArray(allocator, output, fixture.blocked_fields);
        try output.appendSlice(allocator, " }");
    }
    try output.append(allocator, ']');
}

fn appendPipelineFixtureCatalogText(allocator: std.mem.Allocator, output: *std.ArrayList(u8), fixtures: []const PipelineFixture) !void {
    try output.appendSlice(allocator, "pipeline fixture catalog:\n");
    for (fixtures) |fixture| {
        try output.print(allocator, "- {s}: {s} -> {s}\n", .{ fixture.id, fixture.input_envelope, fixture.output_envelope });
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
            "Ready local pipeline fixtures permit starting the NenDB retention fixtures branch only.",
            "Cite source boundary proposal readiness fixtures fixture catalog validation checks and verification commands.",
            "Do not infer runtime telemetry ingestion live pipeline network send OTLP collector durable writes CI gates non-NenDB adapters alternate renderers or mutation authority.",
        },
        .blocked => &.{
            "Blocked local pipeline fixtures must not start NenDB retention fixture work.",
            "Repair boundary evidence fixture validation evidence or verification command evidence first.",
            "Do not infer telemetry pipeline implementation approval from blocked fixture evidence.",
        },
    };
}

fn usage() []const u8 {
    return "usage: zig build causal-production-telemetry-local-pipeline-fixtures -- --from-boundary <boundary.json> approve|reject --reason <reason> [--by <actor>] [--policy <policy>] [--verified-command <command>]... [--out-prefix <path-prefix>]\n";
}

fn failUsage(err: anyerror) noreturn {
    std.debug.print("causal-production-telemetry-local-pipeline-fixtures error: {s}\n{s}", .{ @errorName(err), usage() });
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

const exporter_boundary_approve_command =
    "zig build causal-production-telemetry-exporter-boundary -- --from-proposal ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal.json approve --reason \"proposal evidence reviewed for local pipeline fixtures\" --verified-command \"zig build causal-production-telemetry-implementation-proposal -- --from-readiness ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review.json approve --reason \\\"ready evidence reviewed for exporter boundary planning\\\" --verified-command \\\"zig build causal-production-telemetry-readiness-review -- --from-fixtures ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures.json approve --reason \\\\\\\"fixtures reviewed for implementation proposal\\\\\\\" --verified-command \\\\\\\"zig build causal-production-telemetry-capture-fixtures -- validate --format json\\\\\\\" --verified-command \\\\\\\"zig build causal-schema-governance -- --format json\\\\\\\" --verified-command \\\\\\\"zig build causal-production-hardening-backlog -- --format json\\\\\\\" --verified-command \\\\\\\"zig build examples\\\\\\\" --verified-command \\\\\\\"zig build test\\\\\\\"\\\" --verified-command \\\"zig build causal-schema-governance -- --format json\\\" --verified-command \\\"zig build causal-production-hardening-backlog -- --format json\\\" --verified-command \\\"zig build examples\\\" --verified-command \\\"zig build test\\\"\" --verified-command \"zig build causal-schema-governance -- --format json\" --verified-command \"zig build causal-production-hardening-backlog -- --format json\" --verified-command \"zig build examples\" --verified-command \"zig build test\"";

const required_verification_commands: []const []const u8 = &.{
    exporter_boundary_approve_command,
    "zig build causal-schema-governance -- --format json",
    "zig build causal-production-hardening-backlog -- --format json",
    "zig build examples",
    "zig build test",
};

const pipeline_fixture_catalog: []const PipelineFixture = &.{
    .{
        .id = "runtime-span-normalized-envelope",
        .input_envelope = "runtime-span-event-envelope",
        .output_envelope = "runtime-span-local-json-envelope",
        .output_fields = &.{ "event_id", "trace_id_ref", "span_id_ref", "parent_span_id_ref", "causal_event_ref", "redaction_state", "sample_state" },
        .blocked_fields = &.{ "raw_payload", "headers", "prompts", "credentials", "raw_tenant_id", "raw_user_id", "collector_endpoint", "network_address" },
    },
    .{
        .id = "app-semantic-normalized-envelope",
        .input_envelope = "app-semantic-ref-envelope",
        .output_envelope = "app-semantic-local-json-envelope",
        .output_fields = &.{ "event_id", "domain_entity_ref", "schema_ref", "data_subject_ref", "operation_ref", "redaction_state", "sample_state" },
        .blocked_fields = &.{ "raw_request_body", "raw_response_body", "prompt_text", "credential_material", "raw_pii" },
    },
    .{
        .id = "backend-otel-local-envelope",
        .input_envelope = "backend-otel-record-envelope",
        .output_envelope = "backend-otel-local-json-envelope",
        .output_fields = &.{ "otel_schema_ref", "trace_id_ref", "span_id_ref", "attribute_refs", "redaction_state", "sample_state" },
        .blocked_fields = &.{ "collector_endpoint", "auth_headers", "wire_payload_bytes", "exporter_sdk_configuration" },
    },
    .{
        .id = "redaction-access-reviewed-envelope",
        .input_envelope = "redaction-access-envelope",
        .output_envelope = "redaction-access-local-json-envelope",
        .output_fields = &.{ "visibility_class", "redaction_state", "access_policy_ref", "denied_raw_fields" },
        .blocked_fields = &.{ "raw_secrets", "raw_credentials", "raw_headers", "raw_prompts", "raw_tenant_id", "raw_user_id" },
    },
    .{
        .id = "sampling-kept-envelope",
        .input_envelope = "sampling-boundary-envelope",
        .output_envelope = "sampling-kept-local-json-envelope",
        .output_fields = &.{ "sample_state=kept", "sample_policy_ref", "sample_reason" },
        .blocked_fields = &.{ "wall_clock_randomness", "production_traffic_rates", "production_capacity_claims" },
    },
    .{
        .id = "sampling-dropped-envelope",
        .input_envelope = "sampling-boundary-envelope",
        .output_envelope = "sampling-dropped-local-json-envelope",
        .output_fields = &.{ "sample_state=dropped", "sample_policy_ref", "retained_fields" },
        .blocked_fields = &.{"unsampled_raw_payload_fields"},
    },
    .{
        .id = "correlation-link-envelope",
        .input_envelope = "runtime-span-event-envelope+app-semantic-ref-envelope+backend-otel-record-envelope+redaction-access-envelope+sampling-boundary-envelope",
        .output_envelope = "correlation-link-local-json-envelope",
        .output_fields = &.{ "event_id", "trace_id_ref", "causal_event_ref", "artifact_id_ref", "schema_ref" },
        .blocked_fields = &.{ "raw_payload_joins", "source_database_reads" },
    },
};

const pipeline_validation_checks: []const []const u8 = &.{
    "fixture-references-source-envelope",
    "fixture-declares-output-envelope",
    "fixture-declares-redaction-state",
    "fixture-declares-sample-state",
    "raw-sensitive-fields-blocked",
    "network-and-exporter-fields-blocked",
    "otlp-protobuf-absent",
    "durable-write-fields-absent",
    "sampled-out-retains-metadata-only",
    "correlation-uses-refs-only",
};

const implementation_gates: []const []const u8 = &.{
    "source exporter boundary artifact is approved",
    "source boundary checks and verification commands remain pass",
    "local pipeline fixtures emit envelope records only",
    "network send collector endpoint and OTLP serialization remain disabled",
    "durable work remains NenDB-only future scope",
    "workbench work remains SolidJS inside webui-dev/zig-webui",
    "NenDB retention fixtures must be reviewed before durable mapping work",
};

const non_goals: []const []const u8 = &.{
    "Runtime telemetry ingestion or instrumentation changes",
    "Live local or production pipeline execution",
    "Network sends collector endpoint configuration or outbound exporter transport",
    "OTLP serialization SDK setup or collector delivery",
    "Durable production writes",
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
    "nendb-retention-write-enabled",
    "non-nendb-durable-storage",
    "cockroach-adapter-work",
    "ci-telemetry-gate",
    "react-or-alternate-renderer",
    "mutation-authority-granted",
};

test "local pipeline fixture schema and authority constants are stable" {
    try std.testing.expectEqualStrings("zigeffect.causal.production-telemetry-local-pipeline-fixtures.v1", production_telemetry_local_pipeline_fixtures_schema);
    try std.testing.expectEqual(@as(u32, 1), production_telemetry_local_pipeline_fixtures_schema_version);
    try std.testing.expectEqualStrings("codex/zigeffect-causal-production-telemetry-local-pipeline-fixtures", source_branch);
    try std.testing.expectEqualStrings("start-production-telemetry-nendb-retention-fixtures", recommendation);
    try std.testing.expectEqualStrings("codex/zigeffect-causal-production-telemetry-nendb-retention-fixtures", next_branch_if_ready);
    try std.testing.expectEqualStrings("zigeffect.causal.production-telemetry-exporter-boundary.v1", boundary_schema);
    try std.testing.expectEqualStrings("causal-production-telemetry-local-pipeline-fixtures", generated_by);
    try std.testing.expect(!applied);
    try std.testing.expectEqualStrings("none", mutation_authority);
    try std.testing.expect(!production_telemetry_ingestion);
    try std.testing.expect(!live_exporter_enabled);
    try std.testing.expect(!network_send_enabled);
    try std.testing.expect(!collector_endpoint_configured);
    try std.testing.expect(!otlp_serialization_enabled);
    try std.testing.expect(!durable_write_enabled);
    try std.testing.expect(!ci_gate_enabled);
    try std.testing.expect(!runtime_pipeline_enabled);
    try std.testing.expect(local_pipeline_fixture_mode);
    try std.testing.expect(hasPipelineFixture("runtime-span-normalized-envelope"));
    try std.testing.expect(hasPipelineFixture("sampling-dropped-envelope"));
}

test "parses approve fixture options with verified commands and output prefix" {
    var options = try parseOptions(std.testing.allocator, &.{
        "zigeffect-causal-production-telemetry-local-pipeline-fixtures",
        "--from-boundary",
        ".zig-cache/causal-artifacts/boundary.json",
        "approve",
        "--reason",
        "boundary evidence reviewed",
        "--by",
        "codex",
        "--policy",
        "manual-production-telemetry-local-pipeline-fixtures",
        "--verified-command",
        "zig build test",
        "--out-prefix",
        ".zig-cache/causal-artifacts/custom-local-pipeline-fixtures",
    });
    defer options.deinit(std.testing.allocator);

    try std.testing.expectEqual(Decision.approve, options.decision);
    try std.testing.expectEqualStrings(".zig-cache/causal-artifacts/boundary.json", options.boundary_path);
    try std.testing.expectEqualStrings("boundary evidence reviewed", options.reason);
    try std.testing.expectEqualStrings("codex", options.reviewed_by);
    try std.testing.expectEqualStrings("manual-production-telemetry-local-pipeline-fixtures", options.policy);
    try std.testing.expectEqual(@as(usize, 1), options.verified_commands.len);
    try std.testing.expectEqualStrings("zig build test", options.verified_commands[0]);
    try std.testing.expectEqualStrings(".zig-cache/causal-artifacts/custom-local-pipeline-fixtures", options.out_prefix.?);
}

test "rejects missing boundary path decision and reason" {
    try std.testing.expectError(
        error.MissingBoundaryPath,
        parseOptions(std.testing.allocator, &.{"zigeffect-causal-production-telemetry-local-pipeline-fixtures"}),
    );
    try std.testing.expectError(
        error.InvalidBoundaryPath,
        parseOptions(std.testing.allocator, &.{ "zigeffect-causal-production-telemetry-local-pipeline-fixtures", "--from-boundary", "boundary.txt", "approve", "--reason", "reviewed" }),
    );
    try std.testing.expectError(
        error.MissingDecision,
        parseOptions(std.testing.allocator, &.{ "zigeffect-causal-production-telemetry-local-pipeline-fixtures", "--from-boundary", "boundary.json" }),
    );
    try std.testing.expectError(
        error.UnknownDecision,
        parseOptions(std.testing.allocator, &.{ "zigeffect-causal-production-telemetry-local-pipeline-fixtures", "--from-boundary", "boundary.json", "maybe", "--reason", "reviewed" }),
    );
    try std.testing.expectError(
        error.MissingReason,
        parseOptions(std.testing.allocator, &.{ "zigeffect-causal-production-telemetry-local-pipeline-fixtures", "--from-boundary", "boundary.json", "approve" }),
    );
}

test "derives local pipeline output paths from boundary json path" {
    const derived = try outputPathsForOptions(std.testing.allocator, .{
        .boundary_path = ".zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary.json",
        .decision = .approve,
        .reason = "reviewed",
    });
    defer derived.deinit(std.testing.allocator);
    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures.json",
        derived.json_path,
    );
    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures.txt",
        derived.text_path,
    );

    const custom = try outputPathsForOptions(std.testing.allocator, .{
        .boundary_path = ".zig-cache/causal-artifacts/boundary.json",
        .decision = .approve,
        .reason = "reviewed",
        .out_prefix = ".zig-cache/causal-artifacts/custom-local-pipeline-fixtures",
    });
    defer custom.deinit(std.testing.allocator);
    try std.testing.expectEqualStrings(".zig-cache/causal-artifacts/custom-local-pipeline-fixtures.json", custom.json_path);
    try std.testing.expectEqualStrings(".zig-cache/causal-artifacts/custom-local-pipeline-fixtures.txt", custom.text_path);
}

test "ready and blocked local pipeline reports preserve fixture-only authority" {
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

    try std.testing.expect(std.mem.indexOf(u8, ready.json, "\"schema\": \"zigeffect.causal.production-telemetry-local-pipeline-fixtures.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, ready.json, "\"fixture_status\": \"ready\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, ready.json, "\"ready_for_next_branch\": true") != null);
    try std.testing.expect(std.mem.indexOf(u8, ready.json, "\"runtime_pipeline_enabled\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, ready.json, "\"local_pipeline_fixture_mode\": true") != null);
    try std.testing.expect(std.mem.indexOf(u8, ready.json, "\"network_send_enabled\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, ready.json, "\"collector_endpoint_configured\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, ready.json, "\"otlp_serialization_enabled\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, ready.json, "\"pipeline_fixture_catalog\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, ready.json, "runtime-span-normalized-envelope") != null);
    try std.testing.expect(std.mem.indexOf(u8, ready.json, "sampling-dropped-envelope") != null);
    try std.testing.expect(std.mem.indexOf(u8, ready.text, "fixture_status: ready") != null);
    try std.testing.expect(std.mem.indexOf(u8, ready.text, "runtime pipeline enabled: false") != null);
    try std.testing.expect(std.mem.indexOf(u8, ready.text, "local pipeline fixture mode: true") != null);
    try std.testing.expect(std.mem.indexOf(u8, ready.text, "next branch if ready: codex/zigeffect-causal-production-telemetry-nendb-retention-fixtures") != null);

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
    try std.testing.expect(std.mem.indexOf(u8, blocked.json, "\"runtime_pipeline_enabled\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, blocked.json, "\"local_pipeline_fixture_mode\": true") != null);
    try std.testing.expect(std.mem.indexOf(u8, blocked.text, "fixture_status: blocked") != null);
}

const sample_boundary_json =
    \\{
    \\  "schema": "zigeffect.causal.production-telemetry-exporter-boundary.v1",
    \\  "schema_version": 1,
    \\  "source_proposal": "../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal.json",
    \\  "source_readiness": "../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review.json",
    \\  "source_fixtures": "../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures.json",
    \\  "decision": "approve",
    \\  "boundary_status": "approved",
    \\  "approved_for_next_branch": true,
    \\  "reviewed_by": "local-boundary-reviewer",
    \\  "policy": "manual-production-telemetry-exporter-boundary",
    \\  "reason": "proposal evidence reviewed for local pipeline fixtures",
    \\  "applied": false,
    \\  "mutation_authority": "none",
    \\  "production_telemetry_ingestion": false,
    \\  "live_exporter_enabled": false,
    \\  "network_send_enabled": false,
    \\  "collector_endpoint_configured": false,
    \\  "otlp_serialization_enabled": false,
    \\  "durable_write_enabled": false,
    \\  "ci_gate_enabled": false,
    \\  "proposal_summary": { "source_contract_count": 7, "positive_fixture_count": 6, "negative_fixture_count": 14, "validation_check_count": 8 },
    \\  "checks": [
    \\    { "name": "proposal-schema", "status": "pass", "detail": "source proposal schema is supported" },
    \\    { "name": "proposal-status", "status": "pass", "detail": "source proposal is approved for exporter boundary work" },
    \\    { "name": "proposal-decision-approved", "status": "pass", "detail": "source proposal decision approved the handoff" },
    \\    { "name": "boundary-decision", "status": "pass", "detail": "boundary decision includes a reason" },
    \\    { "name": "decision-approved", "status": "pass", "detail": "boundary decision must approve local pipeline fixture handoff" },
    \\    { "name": "authority-boundary", "status": "pass", "detail": "source proposal and exporter boundary authority fields remain disabled" },
    \\    { "name": "no-network-boundary", "status": "pass", "detail": "network send and collector endpoint stay disabled" },
    \\    { "name": "no-otlp-serialization", "status": "pass", "detail": "OTLP serialization stays out of scope" },
    \\    { "name": "source-chain-linked", "status": "pass", "detail": "proposal links readiness and fixture JSON artifacts" },
    \\    { "name": "proposal-checks-passed", "status": "pass", "detail": "all required source proposal checks passed" },
    \\    { "name": "proposal-phase-handoff", "status": "pass", "detail": "proposal includes exporter-boundary phase handoff" },
    \\    { "name": "proposal-verification-recorded", "status": "pass", "detail": "source proposal recorded required verification command evidence" },
    \\    { "name": "boundary-verification-recorded", "status": "pass", "detail": "boundary review recorded every required verification command" },
    \\    { "name": "nendb-only-scope", "status": "pass", "detail": "durable direction remains future NenDB-only scope" },
    \\    { "name": "solid-webui-scope", "status": "pass", "detail": "workbench direction remains SolidJS inside webui-dev/zig-webui" }
    \\  ],
    \\  "exporter_boundary_contract": [
    \\    "boundary_id=exporter-neutral-no-network",
    \\    "input_contract=redacted-causal-otel-record-or-fixture-ref",
    \\    "output_contract=local-export-envelope-fixture",
    \\    "transport_state=disabled",
    \\    "network_state=disabled",
    \\    "collector_endpoint_state=not-configured",
    \\    "serialization_state=boundary-json-only-not-otlp",
    \\    "durable_write_state=disabled",
    \\    "review_gate=local-pipeline-fixtures-review"
    \\  ],
    \\  "local_envelope_fixtures": [
    \\    "runtime-span-event-envelope",
    \\    "app-semantic-ref-envelope",
    \\    "backend-otel-record-envelope",
    \\    "redaction-access-envelope",
    \\    "sampling-boundary-envelope"
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
    \\    "zig build causal-production-telemetry-implementation-proposal -- --from-readiness ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review.json approve --reason \"ready evidence reviewed for exporter boundary planning\"",
    \\    "zig build causal-schema-governance -- --format json",
    \\    "zig build causal-production-hardening-backlog -- --format json",
    \\    "zig build examples",
    \\    "zig build test"
    \\  ],
    \\  "verified_commands": [
    \\    "zig build causal-production-telemetry-implementation-proposal -- --from-readiness ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review.json approve --reason \"ready evidence reviewed for exporter boundary planning\"",
    \\    "zig build causal-schema-governance -- --format json",
    \\    "zig build causal-production-hardening-backlog -- --format json",
    \\    "zig build examples",
    \\    "zig build test"
    \\  ]
    \\}
;
