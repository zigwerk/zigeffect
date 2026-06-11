const std = @import("std");

pub const app_facing_production_integration_readiness_review_schema =
    "zigeffect.causal.app-facing-production-integration-readiness-review.v1";
pub const app_facing_production_integration_readiness_review_schema_version: u32 = 1;
pub const source_branch =
    "codex/zigeffect-causal-app-facing-production-integration-readiness-review";
pub const recommendation =
    "start-app-facing-production-integration-implementation-proposal";
pub const next_branch_if_ready =
    "codex/zigeffect-causal-app-facing-production-integration-implementation-proposal";

const fixture_schema = "zigeffect.causal.app-facing-production-integration-fixtures.v1";
const generated_by = "causal-app-facing-production-integration-readiness-review";
const applied = false;
const mutation_authority = "none";
const production_telemetry_ingestion = false;
const live_exporter_enabled = false;
const durable_write_enabled = false;
const app_mutation_enabled = false;
const ci_gate_enabled = false;

const Decision = enum { approve, reject };
const ReadinessStatus = enum { ready, blocked };
const CheckStatus = enum { pass, fail, skipped };

const Options = struct {
    fixtures_path: []const u8,
    decision: Decision,
    reviewed_by: []const u8 = "local-reviewer",
    policy: []const u8 = "manual-app-facing-production-integration-readiness",
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

const ReadinessInput = struct {
    options: Options,
    source_fixtures_json: []const u8,
};

const ReadinessReports = struct {
    json: []const u8,
    text: []const u8,

    fn deinit(self: ReadinessReports, allocator: std.mem.Allocator) void {
        allocator.free(self.json);
        allocator.free(self.text);
    }
};

const SourceContract = struct {
    id: []const u8,
    schema: []const u8 = "",
};

const PositiveFixture = struct {
    fixture_id: []const u8,
    integration_surface_id: []const u8,
    retention_policy: []const u8 = "",
    telemetry_transport_state: []const u8 = "",
    durable_write_state: []const u8 = "",
    app_mutation_state: []const u8 = "",
};

const NegativeFixture = struct {
    id: []const u8,
};

const ValidationCheck = struct {
    id: []const u8,
    status: []const u8,
};

const FixtureCatalog = struct {
    schema: []const u8,
    schema_version: u32,
    status: []const u8,
    source_branch: []const u8 = "",
    recommendation: []const u8 = "",
    next_branch: []const u8 = "",
    applied: bool,
    mutation_authority: []const u8,
    production_telemetry_ingestion: bool,
    live_exporter_enabled: bool,
    durable_write_enabled: bool,
    app_mutation_enabled: bool,
    ci_gate_enabled: bool,
    source_contracts: []const SourceContract = &.{},
    positive_fixtures: []const PositiveFixture = &.{},
    negative_fixtures: []const NegativeFixture = &.{},
    validation_checks: []const ValidationCheck = &.{},
    non_goals: []const []const u8 = &.{},
};

const ReadinessCheck = struct {
    name: []const u8,
    status: CheckStatus,
    detail: []const u8,
};

const FixtureSummary = struct {
    source_contract_count: usize,
    positive_fixture_count: usize,
    negative_fixture_count: usize,
    validation_check_count: usize,
};

const ReadinessResult = struct {
    status: ReadinessStatus,
    ready_for_implementation_proposal: bool,
    checks: []const ReadinessCheck,
    summary: FixtureSummary,

    fn deinit(self: ReadinessResult, allocator: std.mem.Allocator) void {
        if (self.checks.len > 0) allocator.free(self.checks);
    }
};

fn parseOptions(allocator: std.mem.Allocator, args: []const []const u8) !Options {
    if (args.len < 2) return error.MissingFixturesPath;
    if (!std.mem.eql(u8, args[1], "--from-fixtures")) return error.UnknownFlag;
    if (args.len < 3) return error.MissingFixturesPath;
    const fixtures_path = args[2];
    if (!std.mem.endsWith(u8, fixtures_path, ".json")) return error.InvalidFixturesPath;
    if (args.len < 4) return error.MissingDecision;
    const decision = try parseDecision(args[3]);

    var reviewed_by: []const u8 = "local-reviewer";
    var policy: []const u8 = "manual-app-facing-production-integration-readiness";
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
        .fixtures_path = fixtures_path,
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
        if (!std.mem.endsWith(u8, options.fixtures_path, ".json")) return error.InvalidFixturesPath;
        const base = options.fixtures_path[0 .. options.fixtures_path.len - ".json".len];
        break :blk try std.fmt.allocPrint(allocator, "{s}-readiness-review", .{base});
    };
    defer allocator.free(prefix);

    return .{
        .json_path = try std.fmt.allocPrint(allocator, "{s}.json", .{prefix}),
        .text_path = try std.fmt.allocPrint(allocator, "{s}.txt", .{prefix}),
    };
}

fn formatReports(allocator: std.mem.Allocator, input: ReadinessInput) !ReadinessReports {
    var parsed = try std.json.parseFromSlice(FixtureCatalog, allocator, input.source_fixtures_json, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();

    const result = try evaluateReadiness(allocator, input.options, parsed.value);
    defer result.deinit(allocator);

    const json = try formatReadinessJson(allocator, input.options, result);
    errdefer allocator.free(json);
    const text = try formatReadinessText(allocator, input.options, result);
    errdefer allocator.free(text);

    return .{ .json = json, .text = text };
}

pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    const options = parseOptions(init.gpa, args) catch |err| failUsage(err);
    defer options.deinit(init.gpa);
    run(init, options) catch |err| switch (err) {
        error.MissingFixturesInput => failUsage(err),
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

fn readinessStatusText(status: ReadinessStatus) []const u8 {
    return switch (status) {
        .ready => "ready",
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

fn evaluateReadiness(
    allocator: std.mem.Allocator,
    options: Options,
    catalog: FixtureCatalog,
) !ReadinessResult {
    var checks = std.ArrayList(ReadinessCheck).empty;
    errdefer checks.deinit(allocator);

    try appendCheck(allocator, &checks, "fixture-schema", if (std.mem.eql(u8, catalog.schema, fixture_schema) and catalog.schema_version == 1) .pass else .fail, "app-facing production integration fixture schema is supported");
    try appendCheck(allocator, &checks, "fixture-status", if (std.mem.eql(u8, catalog.status, "fixtures-only")) .pass else .fail, "source artifact remains fixtures-only");
    try appendCheck(allocator, &checks, "reviewer-decision", if (options.reason.len > 0) .pass else .fail, "reviewer supplied a decision and reason");
    try appendCheck(allocator, &checks, "decision-approved", if (options.decision == .approve) .pass else .fail, "reviewer decision must approve readiness");
    try appendCheck(allocator, &checks, "authority-boundary", if (authorityBoundaryIntact(catalog)) .pass else .fail, "applied mutation telemetry exporter durable app mutation and CI authority are all disabled");
    try appendCheck(allocator, &checks, "source-contracts-present", if (sourceContractsPresent(catalog.source_contracts)) .pass else .fail, "fixture catalog cites required app-facing source contracts");
    try appendCheck(allocator, &checks, "positive-fixture-coverage", if (positiveFixtureCoverage(catalog.positive_fixtures)) .pass else .fail, "positive fixtures cover required app-facing evidence records");
    try appendCheck(allocator, &checks, "integration-surface-coverage", if (integrationSurfaceCoverage(catalog.positive_fixtures)) .pass else .fail, "positive fixtures cover required app production integration surfaces");
    try appendCheck(allocator, &checks, "negative-fixture-coverage", if (negativeFixtureCoverage(catalog.negative_fixtures)) .pass else .fail, "negative fixtures reject forbidden app production integration claims");
    try appendCheck(allocator, &checks, "validation-checks-passed", if (validationChecksPassed(catalog.validation_checks)) .pass else .fail, "all required fixture validation checks passed");
    try appendCheck(allocator, &checks, "nendb-only-durable-direction", if (nendbOnlyDurableDirection(catalog)) .pass else .fail, "durable direction remains NenDB-compatible and blocks Cockroach scope");
    try appendCheck(allocator, &checks, "app-mutation-disabled", if (appMutationDisabled(catalog)) .pass else .fail, "app mutation remains disabled in catalog and fixture records");
    try appendCheck(allocator, &checks, "telemetry-and-durable-disabled", if (telemetryAndDurableDisabled(catalog)) .pass else .fail, "positive fixtures do not enable telemetry transport or durable writes");
    try appendCheck(allocator, &checks, "solid-webui-direction", if (solidWebuiDirection(catalog)) .pass else .fail, "React or alternate renderer work remains blocked");
    try appendCheck(allocator, &checks, "required-verification-recorded", if (verifiedCommandsContainAll(options.verified_commands, required_verification_commands)) .pass else .fail, "reviewer recorded every required verification command");

    const check_slice = try checks.toOwnedSlice(allocator);
    errdefer allocator.free(check_slice);
    const ready = allChecksPassed(check_slice);
    return .{
        .status = if (ready) .ready else .blocked,
        .ready_for_implementation_proposal = ready,
        .checks = check_slice,
        .summary = .{
            .source_contract_count = catalog.source_contracts.len,
            .positive_fixture_count = catalog.positive_fixtures.len,
            .negative_fixture_count = catalog.negative_fixtures.len,
            .validation_check_count = catalog.validation_checks.len,
        },
    };
}

fn appendCheck(
    allocator: std.mem.Allocator,
    checks: *std.ArrayList(ReadinessCheck),
    name: []const u8,
    status: CheckStatus,
    detail: []const u8,
) !void {
    try checks.append(allocator, .{
        .name = name,
        .status = status,
        .detail = detail,
    });
}

fn authorityBoundaryIntact(catalog: FixtureCatalog) bool {
    return !catalog.applied and
        std.mem.eql(u8, catalog.mutation_authority, "none") and
        !catalog.production_telemetry_ingestion and
        !catalog.live_exporter_enabled and
        !catalog.durable_write_enabled and
        !catalog.app_mutation_enabled and
        !catalog.ci_gate_enabled;
}

fn sourceContractsPresent(source_contracts: []const SourceContract) bool {
    const required = [_][]const u8{
        "app-runtime",
        "agent-query",
        "audit-chain-snapshot-compare",
        "nendb-durable-history",
        "production-telemetry-capture-fixtures",
        "app-remediation-chain",
    };
    for (required) |id| {
        if (!hasSourceContract(source_contracts, id)) return false;
    }
    return true;
}

fn hasSourceContract(source_contracts: []const SourceContract, id: []const u8) bool {
    for (source_contracts) |source_contract| {
        if (std.mem.eql(u8, source_contract.id, id)) return true;
    }
    return false;
}

fn positiveFixtureCoverage(positive_fixtures: []const PositiveFixture) bool {
    const required_ids = [_][]const u8{
        "worker-request-redacted-lineage",
        "background-job-nendb-history-handoff",
        "agent-query-app-trace-data",
        "audit-chain-before-after-app-review",
        "app-remediation-governance-bridge",
        "production-telemetry-fixture-boundary",
    };
    for (required_ids) |id| {
        if (!hasPositiveFixture(positive_fixtures, id)) return false;
    }
    return true;
}

fn integrationSurfaceCoverage(positive_fixtures: []const PositiveFixture) bool {
    const required_surfaces = [_][]const u8{
        "worker-request",
        "background-job",
        "agent-query",
        "audit-chain-compare",
        "app-remediation",
        "production-telemetry-boundary",
    };
    for (required_surfaces) |surface| {
        if (!hasIntegrationSurface(positive_fixtures, surface)) return false;
    }
    return true;
}

fn hasPositiveFixture(positive_fixtures: []const PositiveFixture, id: []const u8) bool {
    for (positive_fixtures) |fixture| {
        if (std.mem.eql(u8, fixture.fixture_id, id)) return true;
    }
    return false;
}

fn hasIntegrationSurface(positive_fixtures: []const PositiveFixture, surface: []const u8) bool {
    for (positive_fixtures) |fixture| {
        if (std.mem.eql(u8, fixture.integration_surface_id, surface)) return true;
    }
    return false;
}

fn negativeFixtureCoverage(negative_fixtures: []const NegativeFixture) bool {
    const required_ids = [_][]const u8{
        "raw-request-body-capture",
        "raw-header-capture",
        "raw-prompt-capture",
        "credential-token-capture",
        "pii-or-tenant-identity-capture",
        "live-production-telemetry-ingestion",
        "live-exporter-enabled",
        "production-durable-write",
        "non-nendb-durable-storage",
        "cockroach-adapter-work",
        "app-mutation-authority",
        "audit-chain-compare-as-mutation-proof",
        "agent-query-raw-payload-scrape",
        "ci-gate-enforcement",
        "react-or-alternate-renderer",
    };
    for (required_ids) |id| {
        if (!hasNegativeFixture(negative_fixtures, id)) return false;
    }
    return true;
}

fn hasNegativeFixture(negative_fixtures: []const NegativeFixture, id: []const u8) bool {
    for (negative_fixtures) |fixture| {
        if (std.mem.eql(u8, fixture.id, id)) return true;
    }
    return false;
}

fn validationChecksPassed(validation_checks: []const ValidationCheck) bool {
    const required_ids = [_][]const u8{
        "source-contract-coverage",
        "positive-fixture-surface-coverage",
        "redaction-ref-only-lineage",
        "blocked-claim-coverage",
        "forbidden-value-absence",
        "nendb-only-durable-direction",
        "no-live-authority",
        "next-branch-handoff",
    };
    for (required_ids) |id| {
        if (!hasPassedValidationCheck(validation_checks, id)) return false;
    }
    for (validation_checks) |check| {
        if (!std.mem.eql(u8, check.status, "passed")) return false;
    }
    return true;
}

fn hasPassedValidationCheck(validation_checks: []const ValidationCheck, id: []const u8) bool {
    for (validation_checks) |check| {
        if (std.mem.eql(u8, check.id, id) and std.mem.eql(u8, check.status, "passed")) return true;
    }
    return false;
}

fn nendbOnlyDurableDirection(catalog: FixtureCatalog) bool {
    for (catalog.positive_fixtures) |fixture| {
        if (std.mem.indexOf(u8, fixture.retention_policy, "nendb") == null) return false;
    }
    return hasNegativeFixture(catalog.negative_fixtures, "non-nendb-durable-storage") and
        hasNegativeFixture(catalog.negative_fixtures, "cockroach-adapter-work") and
        nonGoalsContain(catalog.non_goals, "non-NenDB durable adapter work") and
        nonGoalsContain(catalog.non_goals, "Cockroach adapter work");
}

fn appMutationDisabled(catalog: FixtureCatalog) bool {
    if (catalog.app_mutation_enabled) return false;
    for (catalog.positive_fixtures) |fixture| {
        if (!std.mem.eql(u8, fixture.app_mutation_state, "disabled-fixture")) return false;
    }
    return hasNegativeFixture(catalog.negative_fixtures, "app-mutation-authority");
}

fn telemetryAndDurableDisabled(catalog: FixtureCatalog) bool {
    if (catalog.production_telemetry_ingestion or catalog.live_exporter_enabled or catalog.durable_write_enabled) return false;
    for (catalog.positive_fixtures) |fixture| {
        if (!std.mem.eql(u8, fixture.telemetry_transport_state, "disabled-fixture")) return false;
        if (!std.mem.eql(u8, fixture.durable_write_state, "disabled-fixture")) return false;
    }
    return hasNegativeFixture(catalog.negative_fixtures, "live-production-telemetry-ingestion") and
        hasNegativeFixture(catalog.negative_fixtures, "production-durable-write");
}

fn solidWebuiDirection(catalog: FixtureCatalog) bool {
    return hasNegativeFixture(catalog.negative_fixtures, "react-or-alternate-renderer") and
        nonGoalsContain(catalog.non_goals, "React or alternate renderer work");
}

fn nonGoalsContain(non_goals: []const []const u8, needle: []const u8) bool {
    for (non_goals) |goal| {
        if (std.mem.indexOf(u8, goal, needle) != null) return true;
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

fn allChecksPassed(checks: []const ReadinessCheck) bool {
    for (checks) |check| {
        if (check.status != .pass) return false;
    }
    return true;
}

fn formatReadinessJson(
    allocator: std.mem.Allocator,
    options: Options,
    result: ReadinessResult,
) ![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "{\n");
    try output.appendSlice(allocator, "  \"schema\": ");
    try appendJsonString(allocator, &output, app_facing_production_integration_readiness_review_schema);
    try output.appendSlice(allocator, ",\n  \"schema_version\": 1,\n");
    try output.appendSlice(allocator, "  \"generated_by\": ");
    try appendJsonString(allocator, &output, generated_by);
    try output.appendSlice(allocator, ",\n  \"source_fixtures\": ");
    try appendJsonString(allocator, &output, options.fixtures_path);
    try output.appendSlice(allocator, ",\n  \"source_fixture_schema\": ");
    try appendJsonString(allocator, &output, fixture_schema);
    try output.appendSlice(allocator, ",\n  \"decision\": ");
    try appendJsonString(allocator, &output, decisionText(options.decision));
    try output.appendSlice(allocator, ",\n  \"readiness_status\": ");
    try appendJsonString(allocator, &output, readinessStatusText(result.status));
    try output.print(allocator, ",\n  \"ready_for_implementation_proposal\": {},\n", .{result.ready_for_implementation_proposal});
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
    try output.print(allocator, "  \"durable_write_enabled\": {},\n", .{durable_write_enabled});
    try output.print(allocator, "  \"app_mutation_enabled\": {},\n", .{app_mutation_enabled});
    try output.print(allocator, "  \"ci_gate_enabled\": {},\n", .{ci_gate_enabled});
    try output.appendSlice(allocator, "  \"source_branch\": ");
    try appendJsonString(allocator, &output, source_branch);
    try output.appendSlice(allocator, ",\n  \"recommendation\": ");
    try appendJsonString(allocator, &output, recommendation);
    try output.appendSlice(allocator, ",\n  \"next_branch_if_ready\": ");
    try appendJsonString(allocator, &output, next_branch_if_ready);
    try output.appendSlice(allocator, ",\n  \"fixture_summary\": ");
    try appendFixtureSummaryJson(allocator, &output, result.summary);
    try output.appendSlice(allocator, ",\n  \"checks\": ");
    try appendChecksJson(allocator, &output, result.checks);
    try output.appendSlice(allocator, ",\n  \"required_verification_commands\": ");
    try appendStringArray(allocator, &output, required_verification_commands);
    try output.appendSlice(allocator, ",\n  \"verified_commands\": ");
    try appendStringArray(allocator, &output, options.verified_commands);
    try output.appendSlice(allocator, ",\n  \"implementation_proposal_steps\": ");
    try appendStringArray(allocator, &output, implementationProposalSteps(result.status));
    try output.appendSlice(allocator, ",\n  \"readiness_guardrails\": ");
    try appendStringArray(allocator, &output, readinessGuardrails(result.status));
    try output.appendSlice(allocator, "\n}\n");

    return output.toOwnedSlice(allocator);
}

fn formatReadinessText(
    allocator: std.mem.Allocator,
    options: Options,
    result: ReadinessResult,
) ![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "zigeffect app-facing production integration readiness review\n");
    try output.print(allocator, "schema: {s}\n", .{app_facing_production_integration_readiness_review_schema});
    try output.print(allocator, "source fixtures: {s}\n", .{options.fixtures_path});
    try output.print(allocator, "source fixture schema: {s}\n", .{fixture_schema});
    try output.print(allocator, "decision: {s}\n", .{decisionText(options.decision)});
    try output.print(allocator, "readiness_status: {s}\n", .{readinessStatusText(result.status)});
    try output.print(allocator, "ready_for_implementation_proposal: {}\n", .{result.ready_for_implementation_proposal});
    try output.print(allocator, "reviewed_by: {s}\n", .{options.reviewed_by});
    try output.print(allocator, "policy: {s}\n", .{options.policy});
    try output.print(allocator, "reason: {s}\n", .{options.reason});
    try output.print(allocator, "applied: {}\n", .{applied});
    try output.print(allocator, "mutation_authority: {s}\n", .{mutation_authority});
    try output.print(allocator, "production telemetry ingestion: {}\n", .{production_telemetry_ingestion});
    try output.print(allocator, "live exporter enabled: {}\n", .{live_exporter_enabled});
    try output.print(allocator, "durable write enabled: {}\n", .{durable_write_enabled});
    try output.print(allocator, "app mutation enabled: {}\n", .{app_mutation_enabled});
    try output.print(allocator, "ci gate enabled: {}\n", .{ci_gate_enabled});
    try output.print(allocator, "source branch: {s}\n", .{source_branch});
    try output.print(allocator, "recommendation: {s}\n", .{recommendation});
    try output.print(allocator, "next branch if ready: {s}\n\n", .{next_branch_if_ready});

    try output.appendSlice(allocator, "fixture summary:\n");
    try output.print(allocator, "- source contracts: {d}\n", .{result.summary.source_contract_count});
    try output.print(allocator, "- positive fixtures: {d}\n", .{result.summary.positive_fixture_count});
    try output.print(allocator, "- negative fixtures: {d}\n", .{result.summary.negative_fixture_count});
    try output.print(allocator, "- validation checks: {d}\n\n", .{result.summary.validation_check_count});

    try output.appendSlice(allocator, "checks:\n");
    for (result.checks) |check| {
        try output.print(allocator, "- {s}: {s} - {s}\n", .{ check.name, checkStatusText(check.status), check.detail });
    }
    try output.append(allocator, '\n');

    try appendTextList(allocator, &output, "required verification commands", required_verification_commands);
    try appendTextList(allocator, &output, "verified commands", options.verified_commands);
    try appendTextList(allocator, &output, "implementation proposal steps", implementationProposalSteps(result.status));
    try appendTextList(allocator, &output, "readiness guardrails", readinessGuardrails(result.status));

    return output.toOwnedSlice(allocator);
}

fn appendFixtureSummaryJson(allocator: std.mem.Allocator, output: *std.ArrayList(u8), summary: FixtureSummary) !void {
    try output.print(
        allocator,
        "{{ \"source_contract_count\": {d}, \"positive_fixture_count\": {d}, \"negative_fixture_count\": {d}, \"validation_check_count\": {d} }}",
        .{ summary.source_contract_count, summary.positive_fixture_count, summary.negative_fixture_count, summary.validation_check_count },
    );
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

fn implementationProposalSteps(status: ReadinessStatus) []const []const u8 {
    return switch (status) {
        .ready => &.{
            "Start a reviewed app-facing production integration implementation-proposal branch.",
            "Carry forward fixture ids readiness checks and required verification commands.",
            "Keep app mutation live telemetry durable writes CI gates Cockroach scope and alternate renderers outside proposal authority.",
        },
        .blocked => &.{
            "Resolve failed readiness checks before starting implementation proposal work.",
            "Regenerate fixture JSON after design or fixture evidence changes.",
            "Do not infer app production integration authority from blocked readiness.",
        },
    };
}

fn readinessGuardrails(status: ReadinessStatus) []const []const u8 {
    return switch (status) {
        .ready => &.{
            "Readiness does not ingest production telemetry configure exporters send OTLP write durable production storage mutate apps or fail CI gates.",
            "ready_for_implementation_proposal=true allows a future proposal branch only.",
            "applied=true remains reserved for a future artifact after a real reviewed app change and before/after verification evidence exist.",
        },
        .blocked => &.{
            "Blocked readiness must not be treated as app production integration approval.",
            "Do not start app mutation exporter storage dashboard CI gate Cockroach or renderer work from blocked evidence.",
            "Repair fixture coverage verification command evidence or authority boundaries before review is ready.",
        },
    };
}

fn usage() []const u8 {
    return "usage: zig build causal-app-facing-production-integration-readiness-review -- --from-fixtures <fixtures.json> approve|reject --reason <reason> [--by <actor>] [--policy <policy>] [--verified-command <command>]... [--out-prefix <path-prefix>]\n";
}

fn failUsage(err: anyerror) noreturn {
    std.debug.print("causal-app-facing-production-integration-readiness-review error: {s}\n{s}", .{ @errorName(err), usage() });
    std.process.exit(2);
}

fn readRequiredArtifact(io: std.Io, allocator: std.mem.Allocator, path: []const u8) ![]const u8 {
    return std.Io.Dir.cwd().readFileAlloc(io, path, allocator, .limited(1024 * 1024)) catch |err| switch (err) {
        error.FileNotFound => error.MissingFixturesInput,
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
    const source_fixtures_json = try readRequiredArtifact(init.io, allocator, options.fixtures_path);
    defer allocator.free(source_fixtures_json);

    const reports = try formatReports(allocator, .{
        .options = options,
        .source_fixtures_json = source_fixtures_json,
    });
    defer reports.deinit(allocator);

    const paths = try outputPathsForOptions(allocator, options);
    defer paths.deinit(allocator);

    try writeArtifact(init.io, paths.json_path, reports.json);
    try writeArtifact(init.io, paths.text_path, reports.text);
    std.debug.print("{s}", .{reports.text});
}

test "app-facing production integration readiness exposes schema and authority constants" {
    try std.testing.expectEqualStrings(
        "zigeffect.causal.app-facing-production-integration-readiness-review.v1",
        app_facing_production_integration_readiness_review_schema,
    );
    try std.testing.expectEqual(@as(u32, 1), app_facing_production_integration_readiness_review_schema_version);
    try std.testing.expectEqualStrings(
        "codex/zigeffect-causal-app-facing-production-integration-readiness-review",
        source_branch,
    );
    try std.testing.expectEqualStrings(
        "start-app-facing-production-integration-implementation-proposal",
        recommendation,
    );
    try std.testing.expectEqualStrings(
        "codex/zigeffect-causal-app-facing-production-integration-implementation-proposal",
        next_branch_if_ready,
    );
    try std.testing.expectEqualStrings(
        "zigeffect.causal.app-facing-production-integration-fixtures.v1",
        fixture_schema,
    );
    try std.testing.expectEqualStrings(
        "causal-app-facing-production-integration-readiness-review",
        generated_by,
    );
    try std.testing.expect(!applied);
    try std.testing.expectEqualStrings("none", mutation_authority);
    try std.testing.expect(!production_telemetry_ingestion);
    try std.testing.expect(!live_exporter_enabled);
    try std.testing.expect(!durable_write_enabled);
    try std.testing.expect(!app_mutation_enabled);
    try std.testing.expect(!ci_gate_enabled);
}

test "app-facing production integration readiness parses approve decision verified commands and output prefix" {
    var options = try parseOptions(std.testing.allocator, &.{
        "zigeffect-causal-app-facing-production-integration-readiness-review",
        "--from-fixtures",
        ".zig-cache/causal-artifacts/app-facing-production-integration-fixtures.json",
        "approve",
        "--reason",
        "fixtures reviewed",
        "--by",
        "codex",
        "--policy",
        "manual-app-facing-production-integration-readiness",
        "--verified-command",
        "zig build test",
        "--out-prefix",
        ".zig-cache/causal-artifacts/custom-app-facing",
    });
    defer options.deinit(std.testing.allocator);

    try std.testing.expectEqual(Decision.approve, options.decision);
    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/app-facing-production-integration-fixtures.json",
        options.fixtures_path,
    );
    try std.testing.expectEqualStrings("fixtures reviewed", options.reason);
    try std.testing.expectEqualStrings("codex", options.reviewed_by);
    try std.testing.expectEqualStrings("manual-app-facing-production-integration-readiness", options.policy);
    try std.testing.expectEqual(@as(usize, 1), options.verified_commands.len);
    try std.testing.expectEqualStrings("zig build test", options.verified_commands[0]);
    try std.testing.expectEqualStrings(".zig-cache/causal-artifacts/custom-app-facing", options.out_prefix.?);
}

test "app-facing production integration readiness rejects missing required arguments" {
    try std.testing.expectError(
        error.MissingFixturesPath,
        parseOptions(std.testing.allocator, &.{"zigeffect-causal-app-facing-production-integration-readiness-review"}),
    );
    try std.testing.expectError(
        error.InvalidFixturesPath,
        parseOptions(std.testing.allocator, &.{ "zigeffect-causal-app-facing-production-integration-readiness-review", "--from-fixtures", "fixtures.txt", "approve", "--reason", "reviewed" }),
    );
    try std.testing.expectError(
        error.MissingDecision,
        parseOptions(std.testing.allocator, &.{ "zigeffect-causal-app-facing-production-integration-readiness-review", "--from-fixtures", "fixtures.json" }),
    );
    try std.testing.expectError(
        error.UnknownDecision,
        parseOptions(std.testing.allocator, &.{ "zigeffect-causal-app-facing-production-integration-readiness-review", "--from-fixtures", "fixtures.json", "maybe", "--reason", "reviewed" }),
    );
    try std.testing.expectError(
        error.MissingReason,
        parseOptions(std.testing.allocator, &.{ "zigeffect-causal-app-facing-production-integration-readiness-review", "--from-fixtures", "fixtures.json", "approve" }),
    );
}

test "app-facing production integration readiness output paths derive from fixtures path and out prefix" {
    const derived = try outputPathsForOptions(std.testing.allocator, .{
        .fixtures_path = ".zig-cache/causal-artifacts/app-facing-production-integration-fixtures.json",
        .decision = .approve,
        .reason = "reviewed",
    });
    defer derived.deinit(std.testing.allocator);
    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/app-facing-production-integration-fixtures-readiness-review.json",
        derived.json_path,
    );
    try std.testing.expectEqualStrings(
        ".zig-cache/causal-artifacts/app-facing-production-integration-fixtures-readiness-review.txt",
        derived.text_path,
    );

    const custom = try outputPathsForOptions(std.testing.allocator, .{
        .fixtures_path = ".zig-cache/causal-artifacts/app-facing-production-integration-fixtures.json",
        .decision = .approve,
        .reason = "reviewed",
        .out_prefix = ".zig-cache/causal-artifacts/custom-app-facing",
    });
    defer custom.deinit(std.testing.allocator);
    try std.testing.expectEqualStrings(".zig-cache/causal-artifacts/custom-app-facing.json", custom.json_path);
    try std.testing.expectEqualStrings(".zig-cache/causal-artifacts/custom-app-facing.txt", custom.text_path);
}

test "app-facing production integration readiness reports ready and blocked status" {
    const ready_options = Options{
        .fixtures_path = "fixtures.json",
        .decision = .approve,
        .reason = "fixtures reviewed",
        .verified_commands = required_verification_commands,
    };
    const ready = try formatReports(std.testing.allocator, .{
        .options = ready_options,
        .source_fixtures_json = sample_fixture_json,
    });
    defer ready.deinit(std.testing.allocator);

    try std.testing.expect(std.mem.indexOf(u8, ready.json, "\"schema\": \"zigeffect.causal.app-facing-production-integration-readiness-review.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, ready.json, "\"readiness_status\": \"ready\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, ready.json, "\"ready_for_implementation_proposal\": true") != null);
    try std.testing.expect(std.mem.indexOf(u8, ready.json, "\"app_mutation_enabled\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, ready.json, "codex/zigeffect-causal-app-facing-production-integration-implementation-proposal") != null);
    try std.testing.expect(std.mem.indexOf(u8, ready.text, "readiness_status: ready") != null);
    try std.testing.expect(std.mem.indexOf(u8, ready.text, "app mutation enabled: false") != null);

    const blocked = try formatReports(std.testing.allocator, .{
        .options = .{
            .fixtures_path = "fixtures.json",
            .decision = .reject,
            .reason = "negative readiness path",
        },
        .source_fixtures_json = sample_fixture_json,
    });
    defer blocked.deinit(std.testing.allocator);

    try std.testing.expect(std.mem.indexOf(u8, blocked.json, "\"readiness_status\": \"blocked\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, blocked.json, "\"ready_for_implementation_proposal\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, blocked.text, "readiness_status: blocked") != null);
}

test "app-facing production integration readiness blocks unsupported schema and mutation authority" {
    var unsupported_schema = readyCatalog();
    unsupported_schema.schema = "zigeffect.causal.other.v1";
    var unsupported_result = try evaluateReadiness(std.testing.allocator, readyOptions(), unsupported_schema);
    defer unsupported_result.deinit(std.testing.allocator);
    try std.testing.expectEqual(ReadinessStatus.blocked, unsupported_result.status);
    try expectCheckStatus(unsupported_result.checks, "fixture-schema", .fail);

    var mutation_enabled = readyCatalog();
    mutation_enabled.app_mutation_enabled = true;
    var mutation_result = try evaluateReadiness(std.testing.allocator, readyOptions(), mutation_enabled);
    defer mutation_result.deinit(std.testing.allocator);
    try std.testing.expectEqual(ReadinessStatus.blocked, mutation_result.status);
    try expectCheckStatus(mutation_result.checks, "authority-boundary", .fail);
    try expectCheckStatus(mutation_result.checks, "app-mutation-disabled", .fail);
}

test "app-facing production integration readiness blocks fixture state drift and missing verification" {
    var mutation_fixture = readyCatalog();
    mutation_fixture.positive_fixtures = &.{.{
        .fixture_id = "worker-request-redacted-lineage",
        .integration_surface_id = "worker-request",
        .retention_policy = "nendb-compatible-retention-ref",
        .telemetry_transport_state = "disabled-fixture",
        .durable_write_state = "disabled-fixture",
        .app_mutation_state = "enabled",
    }};
    var mutation_fixture_result = try evaluateReadiness(std.testing.allocator, readyOptions(), mutation_fixture);
    defer mutation_fixture_result.deinit(std.testing.allocator);
    try std.testing.expectEqual(ReadinessStatus.blocked, mutation_fixture_result.status);
    try expectCheckStatus(mutation_fixture_result.checks, "app-mutation-disabled", .fail);

    var telemetry_fixture = readyCatalog();
    telemetry_fixture.positive_fixtures = &.{.{
        .fixture_id = "worker-request-redacted-lineage",
        .integration_surface_id = "worker-request",
        .retention_policy = "nendb-compatible-retention-ref",
        .telemetry_transport_state = "enabled",
        .durable_write_state = "disabled-fixture",
        .app_mutation_state = "disabled-fixture",
    }};
    var telemetry_fixture_result = try evaluateReadiness(std.testing.allocator, readyOptions(), telemetry_fixture);
    defer telemetry_fixture_result.deinit(std.testing.allocator);
    try std.testing.expectEqual(ReadinessStatus.blocked, telemetry_fixture_result.status);
    try expectCheckStatus(telemetry_fixture_result.checks, "telemetry-and-durable-disabled", .fail);

    var missing_verification = try evaluateReadiness(std.testing.allocator, .{
        .fixtures_path = "fixtures.json",
        .decision = .approve,
        .reason = "fixtures reviewed",
    }, readyCatalog());
    defer missing_verification.deinit(std.testing.allocator);
    try std.testing.expectEqual(ReadinessStatus.blocked, missing_verification.status);
    try expectCheckStatus(missing_verification.checks, "required-verification-recorded", .fail);
}

fn expectCheckStatus(checks: []const ReadinessCheck, name: []const u8, status: CheckStatus) !void {
    for (checks) |check| {
        if (std.mem.eql(u8, check.name, name)) {
            try std.testing.expectEqual(status, check.status);
            return;
        }
    }
    try std.testing.expect(false);
}

fn readyOptions() Options {
    return .{
        .fixtures_path = "fixtures.json",
        .decision = .approve,
        .reason = "fixtures reviewed",
        .verified_commands = required_verification_commands,
    };
}

fn readyCatalog() FixtureCatalog {
    return .{
        .schema = fixture_schema,
        .schema_version = 1,
        .status = "fixtures-only",
        .source_branch = "codex/zigeffect-causal-app-facing-production-integration-fixtures",
        .recommendation = "start-app-facing-production-integration-readiness-review",
        .next_branch = "codex/zigeffect-causal-app-facing-production-integration-readiness-review",
        .applied = false,
        .mutation_authority = "none",
        .production_telemetry_ingestion = false,
        .live_exporter_enabled = false,
        .durable_write_enabled = false,
        .app_mutation_enabled = false,
        .ci_gate_enabled = false,
        .source_contracts = &.{
            .{ .id = "app-runtime", .schema = "zigeffect.causal.app-runtime.v1" },
            .{ .id = "agent-query", .schema = "zigeffect.causal.agent-query.v1" },
            .{ .id = "audit-chain-snapshot-compare", .schema = "zigeffect.causal.audit-chain-snapshot-compare.v1" },
            .{ .id = "nendb-durable-history", .schema = "zigeffect.causal.nendb-durable-history.v1" },
            .{ .id = "production-telemetry-capture-fixtures", .schema = "zigeffect.causal.production-telemetry-capture-fixtures.v1" },
            .{ .id = "app-remediation-chain", .schema = "zigeffect.causal.app-remediation-audit.v1" },
        },
        .positive_fixtures = &.{
            .{ .fixture_id = "worker-request-redacted-lineage", .integration_surface_id = "worker-request", .retention_policy = "nendb-compatible-retention-ref", .telemetry_transport_state = "disabled-fixture", .durable_write_state = "disabled-fixture", .app_mutation_state = "disabled-fixture" },
            .{ .fixture_id = "background-job-nendb-history-handoff", .integration_surface_id = "background-job", .retention_policy = "nendb-compatible-retention-ref", .telemetry_transport_state = "disabled-fixture", .durable_write_state = "disabled-fixture", .app_mutation_state = "disabled-fixture" },
            .{ .fixture_id = "agent-query-app-trace-data", .integration_surface_id = "agent-query", .retention_policy = "nendb-compatible-retention-ref", .telemetry_transport_state = "disabled-fixture", .durable_write_state = "disabled-fixture", .app_mutation_state = "disabled-fixture" },
            .{ .fixture_id = "audit-chain-before-after-app-review", .integration_surface_id = "audit-chain-compare", .retention_policy = "nendb-compatible-retention-ref", .telemetry_transport_state = "disabled-fixture", .durable_write_state = "disabled-fixture", .app_mutation_state = "disabled-fixture" },
            .{ .fixture_id = "app-remediation-governance-bridge", .integration_surface_id = "app-remediation", .retention_policy = "nendb-compatible-retention-ref", .telemetry_transport_state = "disabled-fixture", .durable_write_state = "disabled-fixture", .app_mutation_state = "disabled-fixture" },
            .{ .fixture_id = "production-telemetry-fixture-boundary", .integration_surface_id = "production-telemetry-boundary", .retention_policy = "nendb-compatible-retention-ref", .telemetry_transport_state = "disabled-fixture", .durable_write_state = "disabled-fixture", .app_mutation_state = "disabled-fixture" },
        },
        .negative_fixtures = &.{
            .{ .id = "raw-request-body-capture" },
            .{ .id = "raw-header-capture" },
            .{ .id = "raw-prompt-capture" },
            .{ .id = "credential-token-capture" },
            .{ .id = "pii-or-tenant-identity-capture" },
            .{ .id = "live-production-telemetry-ingestion" },
            .{ .id = "live-exporter-enabled" },
            .{ .id = "production-durable-write" },
            .{ .id = "non-nendb-durable-storage" },
            .{ .id = "cockroach-adapter-work" },
            .{ .id = "app-mutation-authority" },
            .{ .id = "audit-chain-compare-as-mutation-proof" },
            .{ .id = "agent-query-raw-payload-scrape" },
            .{ .id = "ci-gate-enforcement" },
            .{ .id = "react-or-alternate-renderer" },
        },
        .validation_checks = &.{
            .{ .id = "source-contract-coverage", .status = "passed" },
            .{ .id = "positive-fixture-surface-coverage", .status = "passed" },
            .{ .id = "redaction-ref-only-lineage", .status = "passed" },
            .{ .id = "blocked-claim-coverage", .status = "passed" },
            .{ .id = "forbidden-value-absence", .status = "passed" },
            .{ .id = "nendb-only-durable-direction", .status = "passed" },
            .{ .id = "no-live-authority", .status = "passed" },
            .{ .id = "next-branch-handoff", .status = "passed" },
        },
        .non_goals = &.{
            "live production telemetry ingestion",
            "durable production writes",
            "non-NenDB durable adapter work",
            "Cockroach adapter work",
            "app source config migration data deployment rollout rollback or operational mutation",
            "CI enforcement gates",
            "React or alternate renderer work",
        },
    };
}

const required_verification_commands: []const []const u8 = &.{
    "zig build causal-app-facing-production-integration-fixtures -- validate --format json",
    "zig build causal-schema-governance -- --format json",
    "zig build causal-production-hardening-backlog -- --format json",
    "zig build examples",
    "zig build test",
};

const sample_fixture_json =
    \\{
    \\  "schema": "zigeffect.causal.app-facing-production-integration-fixtures.v1",
    \\  "schema_version": 1,
    \\  "status": "fixtures-only",
    \\  "source_branch": "codex/zigeffect-causal-app-facing-production-integration-fixtures",
    \\  "recommendation": "start-app-facing-production-integration-readiness-review",
    \\  "next_branch": "codex/zigeffect-causal-app-facing-production-integration-readiness-review",
    \\  "applied": false,
    \\  "mutation_authority": "none",
    \\  "production_telemetry_ingestion": false,
    \\  "live_exporter_enabled": false,
    \\  "durable_write_enabled": false,
    \\  "app_mutation_enabled": false,
    \\  "ci_gate_enabled": false,
    \\  "source_contracts": [
    \\    { "id": "app-runtime", "schema": "zigeffect.causal.app-runtime.v1" },
    \\    { "id": "agent-query", "schema": "zigeffect.causal.agent-query.v1" },
    \\    { "id": "audit-chain-snapshot-compare", "schema": "zigeffect.causal.audit-chain-snapshot-compare.v1" },
    \\    { "id": "nendb-durable-history", "schema": "zigeffect.causal.nendb-durable-history.v1" },
    \\    { "id": "production-telemetry-capture-fixtures", "schema": "zigeffect.causal.production-telemetry-capture-fixtures.v1" },
    \\    { "id": "app-remediation-chain", "schema": "zigeffect.causal.app-remediation-audit.v1" }
    \\  ],
    \\  "positive_fixtures": [
    \\    { "fixture_id": "worker-request-redacted-lineage", "integration_surface_id": "worker-request", "retention_policy": "nendb-compatible-retention-ref", "telemetry_transport_state": "disabled-fixture", "durable_write_state": "disabled-fixture", "app_mutation_state": "disabled-fixture" },
    \\    { "fixture_id": "background-job-nendb-history-handoff", "integration_surface_id": "background-job", "retention_policy": "nendb-compatible-retention-ref", "telemetry_transport_state": "disabled-fixture", "durable_write_state": "disabled-fixture", "app_mutation_state": "disabled-fixture" },
    \\    { "fixture_id": "agent-query-app-trace-data", "integration_surface_id": "agent-query", "retention_policy": "nendb-compatible-retention-ref", "telemetry_transport_state": "disabled-fixture", "durable_write_state": "disabled-fixture", "app_mutation_state": "disabled-fixture" },
    \\    { "fixture_id": "audit-chain-before-after-app-review", "integration_surface_id": "audit-chain-compare", "retention_policy": "nendb-compatible-retention-ref", "telemetry_transport_state": "disabled-fixture", "durable_write_state": "disabled-fixture", "app_mutation_state": "disabled-fixture" },
    \\    { "fixture_id": "app-remediation-governance-bridge", "integration_surface_id": "app-remediation", "retention_policy": "nendb-compatible-retention-ref", "telemetry_transport_state": "disabled-fixture", "durable_write_state": "disabled-fixture", "app_mutation_state": "disabled-fixture" },
    \\    { "fixture_id": "production-telemetry-fixture-boundary", "integration_surface_id": "production-telemetry-boundary", "retention_policy": "nendb-compatible-retention-ref", "telemetry_transport_state": "disabled-fixture", "durable_write_state": "disabled-fixture", "app_mutation_state": "disabled-fixture" }
    \\  ],
    \\  "negative_fixtures": [
    \\    { "id": "raw-request-body-capture" },
    \\    { "id": "raw-header-capture" },
    \\    { "id": "raw-prompt-capture" },
    \\    { "id": "credential-token-capture" },
    \\    { "id": "pii-or-tenant-identity-capture" },
    \\    { "id": "live-production-telemetry-ingestion" },
    \\    { "id": "live-exporter-enabled" },
    \\    { "id": "production-durable-write" },
    \\    { "id": "non-nendb-durable-storage" },
    \\    { "id": "cockroach-adapter-work" },
    \\    { "id": "app-mutation-authority" },
    \\    { "id": "audit-chain-compare-as-mutation-proof" },
    \\    { "id": "agent-query-raw-payload-scrape" },
    \\    { "id": "ci-gate-enforcement" },
    \\    { "id": "react-or-alternate-renderer" }
    \\  ],
    \\  "validation_checks": [
    \\    { "id": "source-contract-coverage", "status": "passed" },
    \\    { "id": "positive-fixture-surface-coverage", "status": "passed" },
    \\    { "id": "redaction-ref-only-lineage", "status": "passed" },
    \\    { "id": "blocked-claim-coverage", "status": "passed" },
    \\    { "id": "forbidden-value-absence", "status": "passed" },
    \\    { "id": "nendb-only-durable-direction", "status": "passed" },
    \\    { "id": "no-live-authority", "status": "passed" },
    \\    { "id": "next-branch-handoff", "status": "passed" }
    \\  ],
    \\  "non_goals": [
    \\    "live production telemetry ingestion",
    \\    "durable production writes",
    \\    "non-NenDB durable adapter work",
    \\    "Cockroach adapter work",
    \\    "app source config migration data deployment rollout rollback or operational mutation",
    \\    "CI enforcement gates",
    \\    "React or alternate renderer work"
    \\  ]
    \\}
;
