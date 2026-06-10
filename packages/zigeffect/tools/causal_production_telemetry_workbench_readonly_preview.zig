const std = @import("std");

pub const production_telemetry_workbench_readonly_preview_schema = "zigeffect.causal.production-telemetry-workbench-readonly-preview.v1";
pub const production_telemetry_workbench_readonly_preview_schema_version: u32 = 1;
pub const source_branch = "codex/zigeffect-causal-production-telemetry-workbench-readonly-preview";
pub const recommendation = "start-production-telemetry-ci-artifact-preview";
pub const next_branch_if_ready = "codex/zigeffect-causal-production-telemetry-ci-artifact-preview";

const required_verification_commands: []const []const u8 = &.{
    "bun run zigeffect:workbench:typecheck",
    "bun run zigeffect:workbench:test",
    "zig build causal-schema-governance -- --format json",
    "zig build causal-production-hardening-backlog -- --format json",
    "zig build examples",
    "zig build test",
};

const retention_schema = "zigeffect.causal.production-telemetry-nendb-retention-fixtures.v1";
const generated_by = "causal-production-telemetry-workbench-readonly-preview";
const applied = false;
const mutation_authority = "none";
const read_only_preview = true;
const solid_webui_enabled = true;
const production_telemetry_ingestion = false;
const live_exporter_enabled = false;
const network_send_enabled = false;
const collector_endpoint_configured = false;
const otlp_serialization_enabled = false;
const runtime_pipeline_enabled = false;
const durable_write_enabled = false;
const nendb_write_enabled = false;
const ci_gate_enabled = false;

const Decision = enum { approve, reject };
const PreviewStatus = enum { ready, blocked };
const CheckStatus = enum { pass, fail };

const Options = struct {
    retention_path: []const u8,
    decision: Decision,
    reviewed_by: []const u8 = "workbench-preview-reviewer",
    policy: []const u8 = "manual-production-telemetry-workbench-readonly-preview",
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

const PreviewInput = struct {
    options: Options,
    source_retention_json: []const u8,
};

const PreviewReports = struct {
    json: []const u8,
    text: []const u8,

    fn deinit(self: PreviewReports, allocator: std.mem.Allocator) void {
        allocator.free(self.json);
        allocator.free(self.text);
    }
};

const RetentionCheck = struct {
    name: []const u8,
    status: []const u8,
    detail: []const u8 = "",
};

const NendbMappingFixture = struct {
    id: []const u8,
    source_envelope: []const u8,
    target_schema: []const u8,
    label: []const u8,
    retained_fields: []const []const u8 = &.{},
    blocked_fields: []const []const u8 = &.{},
};

const RetentionArtifact = struct {
    schema: []const u8,
    schema_version: u32,
    source_local_pipeline: []const u8 = "",
    source_boundary: []const u8 = "",
    source_proposal: []const u8 = "",
    source_readiness: []const u8 = "",
    source_fixtures: []const u8 = "",
    decision: []const u8,
    retention_fixture_status: []const u8,
    ready_for_next_branch: bool,
    applied: bool,
    mutation_authority: []const u8,
    production_telemetry_ingestion: bool,
    live_exporter_enabled: bool,
    network_send_enabled: bool,
    collector_endpoint_configured: bool,
    otlp_serialization_enabled: bool,
    runtime_pipeline_enabled: bool,
    durable_write_enabled: bool,
    nendb_write_enabled: bool,
    ci_gate_enabled: bool,
    local_pipeline_fixture_mode: bool = false,
    nendb_retention_fixture_mode: bool = false,
    checks: []const RetentionCheck = &.{},
    nendb_mapping_fixtures: []const NendbMappingFixture = &.{},
    retention_validation_checks: []const []const u8 = &.{},
    required_verification_commands: []const []const u8 = &.{},
    verified_commands: []const []const u8 = &.{},
};

const PreviewCheck = struct {
    name: []const u8,
    status: CheckStatus,
    detail: []const u8,
};

const PreviewResult = struct {
    status: PreviewStatus,
    ready_for_next_branch: bool,
    checks: []const PreviewCheck,

    fn deinit(self: PreviewResult, allocator: std.mem.Allocator) void {
        if (self.checks.len > 0) allocator.free(self.checks);
    }
};

fn parseOptions(allocator: std.mem.Allocator, args: []const []const u8) !Options {
    if (args.len < 2) return error.MissingRetentionPath;
    if (!std.mem.eql(u8, args[1], "--from-retention")) return error.UnknownFlag;
    if (args.len < 3) return error.MissingRetentionPath;
    const retention_path = args[2];
    if (!std.mem.endsWith(u8, retention_path, ".json")) return error.InvalidRetentionPath;
    if (args.len < 4) return error.MissingDecision;
    const decision = try parseDecision(args[3]);

    var reviewed_by: []const u8 = "workbench-preview-reviewer";
    var policy: []const u8 = "manual-production-telemetry-workbench-readonly-preview";
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
        .retention_path = retention_path,
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
        if (!std.mem.endsWith(u8, options.retention_path, ".json")) return error.InvalidRetentionPath;
        const base = options.retention_path[0 .. options.retention_path.len - ".json".len];
        break :blk try std.fmt.allocPrint(allocator, "{s}-workbench-readonly-preview", .{base});
    };
    defer allocator.free(prefix);

    return .{
        .json_path = try std.fmt.allocPrint(allocator, "{s}.json", .{prefix}),
        .text_path = try std.fmt.allocPrint(allocator, "{s}.txt", .{prefix}),
    };
}

fn formatReports(allocator: std.mem.Allocator, input: PreviewInput) !PreviewReports {
    var parsed = try std.json.parseFromSlice(RetentionArtifact, allocator, input.source_retention_json, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();

    const result = try evaluatePreview(allocator, input.options, parsed.value);
    defer result.deinit(allocator);

    const json = try formatPreviewJson(allocator, input.options, parsed.value, result);
    errdefer allocator.free(json);
    const text = try formatPreviewText(allocator, input.options, parsed.value, result);
    errdefer allocator.free(text);

    return .{ .json = json, .text = text };
}

pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    const options = parseOptions(init.gpa, args) catch |err| failUsage(err);
    defer options.deinit(init.gpa);
    run(init, options) catch |err| switch (err) {
        error.MissingRetentionInput => failUsage(err),
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

fn previewStatusText(status: PreviewStatus) []const u8 {
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

fn evaluatePreview(
    allocator: std.mem.Allocator,
    options: Options,
    retention: RetentionArtifact,
) !PreviewResult {
    var checks = std.ArrayList(PreviewCheck).empty;
    errdefer checks.deinit(allocator);

    try appendCheck(allocator, &checks, "retention-schema", if (std.mem.eql(u8, retention.schema, retention_schema) and retention.schema_version == 1) .pass else .fail, "source retention fixture schema is supported");
    try appendCheck(allocator, &checks, "retention-status", if (std.mem.eql(u8, retention.retention_fixture_status, "ready") and retention.ready_for_next_branch) .pass else .fail, "source retention fixtures are ready for workbench preview");
    try appendCheck(allocator, &checks, "retention-decision-approved", if (std.mem.eql(u8, retention.decision, "approve")) .pass else .fail, "source retention decision approved the handoff");
    try appendCheck(allocator, &checks, "decision-approved", if (options.decision == .approve) .pass else .fail, "preview decision must approve CI artifact preview handoff");
    try appendCheck(allocator, &checks, "authority-disabled", if (authorityDisabled(retention)) .pass else .fail, "live telemetry network runtime durable NenDB and CI writes remain disabled");
    try appendCheck(allocator, &checks, "retention-checks-passed", if (retentionChecksPassed(retention.checks)) .pass else .fail, "all source retention checks passed");
    try appendCheck(allocator, &checks, "mapping-fixtures-present", if (mappingFixturesPresent(retention.nendb_mapping_fixtures)) .pass else .fail, "runtime node and correlation edge mapping fixtures are present");
    try appendCheck(allocator, &checks, "retention-validation-present", if (retentionValidationPresent(retention.retention_validation_checks)) .pass else .fail, "retention validation confirms writes are disabled and workbench preview is next");
    try appendCheck(allocator, &checks, "source-verification-recorded", if (sourceVerificationRecorded(retention)) .pass else .fail, "source retention artifact recorded its required verification command evidence");
    try appendCheck(allocator, &checks, "preview-verification-recorded", if (verifiedCommandsContainAll(options.verified_commands, required_verification_commands)) .pass else .fail, "preview review recorded every required workbench and Zig verification command");
    try appendCheck(allocator, &checks, "solid-webui-readonly", if (read_only_preview and solid_webui_enabled and !applied and std.mem.eql(u8, mutation_authority, "none")) .pass else .fail, "preview is read-only SolidJS inside webui-dev/zig-webui");

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
    checks: *std.ArrayList(PreviewCheck),
    name: []const u8,
    status: CheckStatus,
    detail: []const u8,
) !void {
    try checks.append(allocator, .{ .name = name, .status = status, .detail = detail });
}

fn allChecksPassed(checks: []const PreviewCheck) bool {
    for (checks) |check| {
        if (check.status != .pass) return false;
    }
    return true;
}

fn authorityDisabled(retention: RetentionArtifact) bool {
    return !retention.applied and
        std.mem.eql(u8, retention.mutation_authority, "none") and
        !retention.production_telemetry_ingestion and
        !retention.live_exporter_enabled and
        !retention.network_send_enabled and
        !retention.collector_endpoint_configured and
        !retention.otlp_serialization_enabled and
        !retention.runtime_pipeline_enabled and
        !retention.durable_write_enabled and
        !retention.nendb_write_enabled and
        !retention.ci_gate_enabled and
        retention.local_pipeline_fixture_mode and
        retention.nendb_retention_fixture_mode and
        !production_telemetry_ingestion and
        !live_exporter_enabled and
        !network_send_enabled and
        !collector_endpoint_configured and
        !otlp_serialization_enabled and
        !runtime_pipeline_enabled and
        !durable_write_enabled and
        !nendb_write_enabled and
        !ci_gate_enabled;
}

fn retentionChecksPassed(checks: []const RetentionCheck) bool {
    if (checks.len == 0) return false;
    for (checks) |check| {
        if (!std.mem.eql(u8, check.status, "pass")) return false;
    }
    return hasRetentionCheck(checks, "decision-approved") or hasRetentionCheck(checks, "retention-fixture-decision");
}

fn hasRetentionCheck(checks: []const RetentionCheck, name: []const u8) bool {
    for (checks) |check| {
        if (std.mem.eql(u8, check.name, name) and std.mem.eql(u8, check.status, "pass")) return true;
    }
    return false;
}

fn mappingFixturesPresent(fixtures: []const NendbMappingFixture) bool {
    return hasMappingFixture(fixtures, "nendb-runtime-event-node-fixture") and
        hasMappingFixture(fixtures, "nendb-correlation-edge-fixture");
}

fn hasMappingFixture(fixtures: []const NendbMappingFixture, id: []const u8) bool {
    for (fixtures) |fixture| {
        if (std.mem.eql(u8, fixture.id, id)) return true;
    }
    return false;
}

fn retentionValidationPresent(checks: []const []const u8) bool {
    return containsString(checks, "nendb-write-disabled") and
        containsString(checks, "durable-write-disabled") and
        containsString(checks, "workbench-preview-next-only");
}

fn sourceVerificationRecorded(retention: RetentionArtifact) bool {
    return retention.required_verification_commands.len > 0 and
        verifiedCommandsContainAll(retention.verified_commands, retention.required_verification_commands);
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

fn formatPreviewJson(
    allocator: std.mem.Allocator,
    options: Options,
    retention: RetentionArtifact,
    result: PreviewResult,
) ![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "{\n");
    try output.appendSlice(allocator, "  \"schema\": ");
    try appendJsonString(allocator, &output, production_telemetry_workbench_readonly_preview_schema);
    try output.appendSlice(allocator, ",\n  \"schema_version\": 1,\n");
    try output.appendSlice(allocator, "  \"source_retention\": ");
    try appendJsonString(allocator, &output, options.retention_path);
    try output.appendSlice(allocator, ",\n  \"source_local_pipeline\": ");
    try appendJsonString(allocator, &output, retention.source_local_pipeline);
    try output.appendSlice(allocator, ",\n  \"source_boundary\": ");
    try appendJsonString(allocator, &output, retention.source_boundary);
    try output.appendSlice(allocator, ",\n  \"source_proposal\": ");
    try appendJsonString(allocator, &output, retention.source_proposal);
    try output.appendSlice(allocator, ",\n  \"source_readiness\": ");
    try appendJsonString(allocator, &output, retention.source_readiness);
    try output.appendSlice(allocator, ",\n  \"source_fixtures\": ");
    try appendJsonString(allocator, &output, retention.source_fixtures);
    try output.appendSlice(allocator, ",\n  \"decision\": ");
    try appendJsonString(allocator, &output, decisionText(options.decision));
    try output.appendSlice(allocator, ",\n  \"preview_status\": ");
    try appendJsonString(allocator, &output, previewStatusText(result.status));
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
    try output.print(allocator, ",\n  \"read_only_preview\": {},\n", .{read_only_preview});
    try output.print(allocator, "  \"solid_webui_enabled\": {},\n", .{solid_webui_enabled});
    try output.print(allocator, "  \"production_telemetry_ingestion\": {},\n", .{production_telemetry_ingestion});
    try output.print(allocator, "  \"live_exporter_enabled\": {},\n", .{live_exporter_enabled});
    try output.print(allocator, "  \"network_send_enabled\": {},\n", .{network_send_enabled});
    try output.print(allocator, "  \"collector_endpoint_configured\": {},\n", .{collector_endpoint_configured});
    try output.print(allocator, "  \"otlp_serialization_enabled\": {},\n", .{otlp_serialization_enabled});
    try output.print(allocator, "  \"runtime_pipeline_enabled\": {},\n", .{runtime_pipeline_enabled});
    try output.print(allocator, "  \"durable_write_enabled\": {},\n", .{durable_write_enabled});
    try output.print(allocator, "  \"nendb_write_enabled\": {},\n", .{nendb_write_enabled});
    try output.print(allocator, "  \"ci_gate_enabled\": {},\n", .{ci_gate_enabled});
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
    try output.appendSlice(allocator, ",\n  \"nendb_mapping_fixtures\": ");
    try appendNendbMappingFixtureCatalogJson(allocator, &output, retention.nendb_mapping_fixtures);
    try output.appendSlice(allocator, ",\n  \"retention_validation_checks\": ");
    try appendStringArray(allocator, &output, retention.retention_validation_checks);
    try output.appendSlice(allocator, ",\n  \"preview_panels\": ");
    try appendStringArray(allocator, &output, preview_panels);
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

fn formatPreviewText(
    allocator: std.mem.Allocator,
    options: Options,
    retention: RetentionArtifact,
    result: PreviewResult,
) ![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "zigeffect production telemetry workbench readonly preview\n");
    try output.print(allocator, "schema: {s}\n", .{production_telemetry_workbench_readonly_preview_schema});
    try output.print(allocator, "source retention: {s}\n", .{options.retention_path});
    try output.print(allocator, "source local_pipeline: {s}\n", .{retention.source_local_pipeline});
    try output.print(allocator, "decision: {s}\n", .{decisionText(options.decision)});
    try output.print(allocator, "preview_status: {s}\n", .{previewStatusText(result.status)});
    try output.print(allocator, "ready_for_next_branch: {}\n", .{result.ready_for_next_branch});
    try output.print(allocator, "reviewed_by: {s}\n", .{options.reviewed_by});
    try output.print(allocator, "policy: {s}\n", .{options.policy});
    try output.print(allocator, "reason: {s}\n", .{options.reason});
    try output.print(allocator, "applied: {}\n", .{applied});
    try output.print(allocator, "mutation_authority: {s}\n", .{mutation_authority});
    try output.print(allocator, "read only preview: {}\n", .{read_only_preview});
    try output.print(allocator, "solid webui enabled: {}\n", .{solid_webui_enabled});
    try output.print(allocator, "runtime pipeline enabled: {}\n", .{runtime_pipeline_enabled});
    try output.print(allocator, "durable write enabled: {}\n", .{durable_write_enabled});
    try output.print(allocator, "nendb write enabled: {}\n", .{nendb_write_enabled});
    try output.print(allocator, "source branch: {s}\n", .{source_branch});
    try output.print(allocator, "recommendation: {s}\n", .{recommendation});
    try output.print(allocator, "next branch if ready: {s}\n\n", .{next_branch_if_ready});

    try output.appendSlice(allocator, "checks:\n");
    for (result.checks) |check| {
        try output.print(allocator, "- {s}: {s} - {s}\n", .{ check.name, checkStatusText(check.status), check.detail });
    }
    try output.append(allocator, '\n');

    try appendNendbMappingFixtureCatalogText(allocator, &output, retention.nendb_mapping_fixtures);
    try appendTextList(allocator, &output, "retention validation checks", retention.retention_validation_checks);
    try appendTextList(allocator, &output, "preview panels", preview_panels);
    try appendTextList(allocator, &output, "implementation gates", implementation_gates);
    try appendTextList(allocator, &output, "non-goals", non_goals);
    try appendTextList(allocator, &output, "blocked claims", blocked_claims);
    try appendTextList(allocator, &output, "required verification commands", required_verification_commands);
    try appendTextList(allocator, &output, "verified commands", options.verified_commands);
    try appendTextList(allocator, &output, "agent guidance", agentGuidance(result.status));

    return output.toOwnedSlice(allocator);
}

fn appendChecksJson(allocator: std.mem.Allocator, output: *std.ArrayList(u8), checks: []const PreviewCheck) !void {
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

fn containsString(values: []const []const u8, needle: []const u8) bool {
    for (values) |value| {
        if (std.mem.indexOf(u8, value, needle) != null) return true;
    }
    return false;
}

fn usage() []const u8 {
    return "usage: zig build causal-production-telemetry-workbench-readonly-preview -- --from-retention <retention.json> approve|reject --reason <reason> [--by <actor>] [--policy <policy>] [--verified-command <command>]... [--out-prefix <path-prefix>]\n";
}

fn failUsage(err: anyerror) noreturn {
    std.debug.print("causal-production-telemetry-workbench-readonly-preview error: {s}\n{s}", .{ @errorName(err), usage() });
    std.process.exit(2);
}

fn readRequiredArtifact(io: std.Io, allocator: std.mem.Allocator, path: []const u8) ![]const u8 {
    return std.Io.Dir.cwd().readFileAlloc(io, path, allocator, .limited(1024 * 1024)) catch |err| switch (err) {
        error.FileNotFound => error.MissingRetentionInput,
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
    const source_retention_json = try readRequiredArtifact(init.io, allocator, options.retention_path);
    defer allocator.free(source_retention_json);

    const reports = try formatReports(allocator, .{
        .options = options,
        .source_retention_json = source_retention_json,
    });
    defer reports.deinit(allocator);

    const paths = try outputPathsForOptions(allocator, options);
    defer paths.deinit(allocator);

    try writeArtifact(init.io, paths.json_path, reports.json);
    try writeArtifact(init.io, paths.text_path, reports.text);
    std.debug.print("{s}", .{reports.text});
}

const preview_panels: []const []const u8 = &.{
    "status",
    "source-artifacts",
    "authority-boundary",
    "checks",
    "verification",
    "nendb-mapping-fixtures",
    "validation-checks",
    "implementation-gates",
    "blocked-claims",
    "non-goals",
};

const implementation_gates: []const []const u8 = &.{
    "source NenDB retention fixture artifact is ready",
    "SolidJS webui workbench sample and Telemetry tab tests pass",
    "workbench remains a read-only local preview",
    "durable writes and NenDB writes remain disabled",
    "CI artifact preview must be reviewed before adding CI gates",
};

const non_goals: []const []const u8 = &.{
    "Runtime telemetry ingestion or instrumentation changes",
    "Live exporter network send collector endpoint configuration or OTLP serialization",
    "Durable production writes or NenDB writes",
    "CI telemetry gate enforcement",
    "Hosted dashboard authentication authorization or mutation authority",
    "React or alternate renderer work",
    "Non-NenDB durable adapter work",
    "Cockroach adapter work",
};

const blocked_claims: []const []const u8 = &.{
    "runtime-pipeline-enabled",
    "live-exporter-enabled",
    "network-send-enabled",
    "collector-endpoint-configured",
    "otlp-serialization-enabled",
    "durable-production-write-enabled",
    "nendb-write-enabled",
    "ci-telemetry-gate",
    "hosted-dashboard-production-ready",
    "mutation-authority-granted",
    "react-or-alternate-renderer",
    "non-nendb-durable-storage",
    "cockroach-adapter-work",
};

fn agentGuidance(status: PreviewStatus) []const []const u8 {
    return switch (status) {
        .ready => &.{
            "Ready workbench preview evidence permits starting the CI artifact preview branch only.",
            "Use the Telemetry tab to inspect source retention evidence mapping fixtures authority boundaries and verification commands.",
            "Do not infer live telemetry ingestion durable writes NenDB writes CI gates hosted dashboards or mutation authority.",
        },
        .blocked => &.{
            "Blocked workbench preview evidence must not start CI artifact preview work.",
            "Repair source retention evidence workbench tests or required verification command evidence first.",
            "Do not treat a read-only preview artifact as production telemetry enablement.",
        },
    };
}

test "workbench readonly preview schema and branch constants are stable" {
    try std.testing.expectEqualStrings("zigeffect.causal.production-telemetry-workbench-readonly-preview.v1", production_telemetry_workbench_readonly_preview_schema);
    try std.testing.expectEqual(@as(u32, 1), production_telemetry_workbench_readonly_preview_schema_version);
    try std.testing.expectEqualStrings("codex/zigeffect-causal-production-telemetry-workbench-readonly-preview", source_branch);
    try std.testing.expectEqualStrings("start-production-telemetry-ci-artifact-preview", recommendation);
    try std.testing.expectEqualStrings("codex/zigeffect-causal-production-telemetry-ci-artifact-preview", next_branch_if_ready);
    try std.testing.expect(containsString(required_verification_commands, "bun run zigeffect:workbench:typecheck"));
    try std.testing.expect(containsString(required_verification_commands, "bun run zigeffect:workbench:test"));
    try std.testing.expect(containsString(required_verification_commands, "zig build examples"));
    try std.testing.expect(containsString(required_verification_commands, "zig build test"));
}

test "parses workbench readonly preview options with verified commands" {
    var options = try parseOptions(std.testing.allocator, &.{
        "zigeffect-causal-production-telemetry-workbench-readonly-preview",
        "--from-retention",
        ".zig-cache/causal-artifacts/nendb-retention.json",
        "approve",
        "--reason",
        "read-only SolidJS webui preview reviewed",
        "--by",
        "codex",
        "--policy",
        "manual-production-telemetry-workbench-readonly-preview",
        "--verified-command",
        "bun run zigeffect:workbench:typecheck",
        "--out-prefix",
        ".zig-cache/causal-artifacts/custom-workbench-preview",
    });
    defer options.deinit(std.testing.allocator);

    try std.testing.expectEqual(Decision.approve, options.decision);
    try std.testing.expectEqualStrings(".zig-cache/causal-artifacts/nendb-retention.json", options.retention_path);
    try std.testing.expectEqualStrings("read-only SolidJS webui preview reviewed", options.reason);
    try std.testing.expectEqualStrings("codex", options.reviewed_by);
    try std.testing.expectEqualStrings("manual-production-telemetry-workbench-readonly-preview", options.policy);
    try std.testing.expectEqual(@as(usize, 1), options.verified_commands.len);
    try std.testing.expectEqualStrings("bun run zigeffect:workbench:typecheck", options.verified_commands[0]);
    try std.testing.expectEqualStrings(".zig-cache/causal-artifacts/custom-workbench-preview", options.out_prefix.?);
}

test "ready and blocked workbench preview reports preserve read-only authority" {
    const ready = try formatReports(std.testing.allocator, .{
        .options = .{
            .retention_path = "nendb-retention.json",
            .decision = .approve,
            .reason = "read-only SolidJS webui preview reviewed",
            .verified_commands = required_verification_commands,
        },
        .source_retention_json = sample_retention_json,
    });
    defer ready.deinit(std.testing.allocator);

    try std.testing.expect(std.mem.indexOf(u8, ready.json, "\"schema\": \"zigeffect.causal.production-telemetry-workbench-readonly-preview.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, ready.json, "\"preview_status\": \"ready\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, ready.json, "\"ready_for_next_branch\": true") != null);
    try std.testing.expect(std.mem.indexOf(u8, ready.json, "\"read_only_preview\": true") != null);
    try std.testing.expect(std.mem.indexOf(u8, ready.json, "\"solid_webui_enabled\": true") != null);
    try std.testing.expect(std.mem.indexOf(u8, ready.json, "\"durable_write_enabled\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, ready.json, "\"nendb_write_enabled\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, ready.json, "\"next_branch_if_ready\": \"codex/zigeffect-causal-production-telemetry-ci-artifact-preview\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, ready.text, "preview_status: ready") != null);
    try std.testing.expect(std.mem.indexOf(u8, ready.text, "read only preview: true") != null);
    try std.testing.expect(std.mem.indexOf(u8, ready.text, "solid webui enabled: true") != null);

    const blocked = try formatReports(std.testing.allocator, .{
        .options = .{
            .retention_path = "nendb-retention.json",
            .decision = .reject,
            .reason = "negative review path",
        },
        .source_retention_json = sample_retention_json,
    });
    defer blocked.deinit(std.testing.allocator);

    try std.testing.expect(std.mem.indexOf(u8, blocked.json, "\"preview_status\": \"blocked\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, blocked.json, "\"ready_for_next_branch\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, blocked.json, "\"durable_write_enabled\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, blocked.json, "\"nendb_write_enabled\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, blocked.text, "preview_status: blocked") != null);
}

const sample_retention_json =
    \\{
    \\  "schema": "zigeffect.causal.production-telemetry-nendb-retention-fixtures.v1",
    \\  "schema_version": 1,
    \\  "source_local_pipeline": ".zig-cache/causal-artifacts/local-pipeline.json",
    \\  "source_boundary": ".zig-cache/causal-artifacts/exporter-boundary.json",
    \\  "source_proposal": ".zig-cache/causal-artifacts/implementation-proposal.json",
    \\  "source_readiness": ".zig-cache/causal-artifacts/readiness-review.json",
    \\  "source_fixtures": ".zig-cache/causal-artifacts/capture-fixtures.json",
    \\  "decision": "approve",
    \\  "retention_fixture_status": "ready",
    \\  "ready_for_next_branch": true,
    \\  "applied": false,
    \\  "mutation_authority": "none",
    \\  "production_telemetry_ingestion": false,
    \\  "live_exporter_enabled": false,
    \\  "network_send_enabled": false,
    \\  "collector_endpoint_configured": false,
    \\  "otlp_serialization_enabled": false,
    \\  "runtime_pipeline_enabled": false,
    \\  "durable_write_enabled": false,
    \\  "nendb_write_enabled": false,
    \\  "ci_gate_enabled": false,
    \\  "local_pipeline_fixture_mode": true,
    \\  "nendb_retention_fixture_mode": true,
    \\  "checks": [
    \\    { "name": "decision-approved", "status": "pass", "detail": "fixture decision approved the handoff" },
    \\    { "name": "authority-boundary", "status": "pass", "detail": "writes remain disabled" },
    \\    { "name": "nendb-fixture-catalog-complete", "status": "pass", "detail": "mapping fixtures are present" }
    \\  ],
    \\  "nendb_mapping_fixtures": [
    \\    { "id": "nendb-runtime-event-node-fixture", "source_envelope": "runtime-span-normalized-envelope", "target_schema": "zigeffect.causal.nendb_node.v1", "label": "causal.telemetry.runtime_span", "retained_fields": ["event_id_ref"], "blocked_fields": ["raw_payload"] },
    \\    { "id": "nendb-correlation-edge-fixture", "source_envelope": "correlation-link-envelope", "target_schema": "zigeffect.causal.nendb_edge.v1", "label": "causal.telemetry.correlates", "retained_fields": ["from_event_ref"], "blocked_fields": ["raw_payload_joins"] }
    \\  ],
    \\  "retention_validation_checks": [
    \\    "nendb-write-disabled",
    \\    "durable-write-disabled",
    \\    "workbench-preview-next-only"
    \\  ],
    \\  "required_verification_commands": [
    \\    "zig build causal-production-telemetry-local-pipeline-fixtures"
    \\  ],
    \\  "verified_commands": [
    \\    "zig build causal-production-telemetry-local-pipeline-fixtures"
    \\  ]
    \\}
;
