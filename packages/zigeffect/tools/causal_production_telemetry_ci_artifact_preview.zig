const std = @import("std");

pub const production_telemetry_ci_artifact_preview_schema = "zigeffect.causal.production-telemetry-ci-artifact-preview.v1";
pub const production_telemetry_ci_artifact_preview_schema_version: u32 = 1;
pub const source_branch = "codex/zigeffect-causal-production-telemetry-ci-artifact-preview";
pub const recommendation = "start-production-telemetry-ci-harness-boundary";
pub const next_branch_if_ready = "codex/zigeffect-causal-production-telemetry-ci-harness-boundary";

const required_verification_commands: []const []const u8 = &.{
    "zig build causal-production-telemetry-workbench-readonly-preview",
    "zig build causal-artifacts",
    "zig build causal-schema-governance -- --format json",
    "zig build causal-production-hardening-backlog -- --format json",
    "zig build examples",
    "zig build test",
};

const workbench_schema = "zigeffect.causal.production-telemetry-workbench-readonly-preview.v1";
const generated_by = "causal-production-telemetry-ci-artifact-preview";
const applied = false;
const mutation_authority = "none";
const production_telemetry_ingestion = false;
const live_exporter_enabled = false;
const network_send_enabled = false;
const collector_endpoint_configured = false;
const otlp_serialization_enabled = false;
const runtime_pipeline_enabled = false;
const durable_write_enabled = false;
const nendb_write_enabled = false;
const ci_gate_enabled = false;
const ci_upload_enabled = false;
const ci_workflow_mutation_enabled = false;
const ci_artifact_preview_enabled = true;
const ci_artifact_retention_days: u32 = 14;

const Decision = enum { approve, reject };
const PreviewStatus = enum { ready, blocked };
const CheckStatus = enum { pass, fail };

const Options = struct {
    workbench_path: []const u8,
    decision: Decision,
    reviewed_by: []const u8 = "ci-artifact-preview-reviewer",
    policy: []const u8 = "manual-production-telemetry-ci-artifact-preview",
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
    source_workbench_json: []const u8,
};

const PreviewReports = struct {
    json: []const u8,
    text: []const u8,

    fn deinit(self: PreviewReports, allocator: std.mem.Allocator) void {
        allocator.free(self.json);
        allocator.free(self.text);
    }
};

const SourceCheck = struct {
    name: []const u8,
    status: []const u8,
    detail: []const u8 = "",
};

const NendbMappingFixture = struct {
    id: []const u8,
    source_envelope: []const u8 = "",
    target_schema: []const u8 = "",
    label: []const u8 = "",
    retained_fields: []const []const u8 = &.{},
    blocked_fields: []const []const u8 = &.{},
};

const WorkbenchPreviewArtifact = struct {
    schema: []const u8,
    schema_version: u32,
    source_retention: []const u8 = "",
    source_local_pipeline: []const u8 = "",
    source_boundary: []const u8 = "",
    source_proposal: []const u8 = "",
    source_readiness: []const u8 = "",
    source_fixtures: []const u8 = "",
    decision: []const u8,
    preview_status: []const u8,
    ready_for_next_branch: bool,
    applied: bool,
    mutation_authority: []const u8,
    read_only_preview: bool,
    solid_webui_enabled: bool,
    production_telemetry_ingestion: bool,
    live_exporter_enabled: bool,
    network_send_enabled: bool,
    collector_endpoint_configured: bool,
    otlp_serialization_enabled: bool,
    runtime_pipeline_enabled: bool,
    durable_write_enabled: bool,
    nendb_write_enabled: bool,
    ci_gate_enabled: bool,
    checks: []const SourceCheck = &.{},
    nendb_mapping_fixtures: []const NendbMappingFixture = &.{},
    retention_validation_checks: []const []const u8 = &.{},
    required_verification_commands: []const []const u8 = &.{},
    verified_commands: []const []const u8 = &.{},
    blocked_claims: []const []const u8 = &.{},
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

pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    const options = parseOptions(init.gpa, args) catch |err| failUsage(err);
    defer options.deinit(init.gpa);
    run(init, options) catch |err| switch (err) {
        error.MissingWorkbenchInput => failUsage(err),
        else => return err,
    };
}

fn parseOptions(allocator: std.mem.Allocator, args: []const []const u8) !Options {
    if (args.len < 2) return error.MissingWorkbenchPath;
    if (!std.mem.eql(u8, args[1], "--from-workbench")) return error.UnknownFlag;
    if (args.len < 3) return error.MissingWorkbenchPath;
    const workbench_path = args[2];
    if (!std.mem.endsWith(u8, workbench_path, ".json")) return error.InvalidWorkbenchPath;
    if (args.len < 4) return error.MissingDecision;
    const decision = try parseDecision(args[3]);

    var reviewed_by: []const u8 = "ci-artifact-preview-reviewer";
    var policy: []const u8 = "manual-production-telemetry-ci-artifact-preview";
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
        .workbench_path = workbench_path,
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

fn outputPathsForOptions(allocator: std.mem.Allocator, options: Options) !OutputPaths {
    const prefix = if (options.out_prefix) |out_prefix|
        try allocator.dupe(u8, out_prefix)
    else blk: {
        if (!std.mem.endsWith(u8, options.workbench_path, ".json")) return error.InvalidWorkbenchPath;
        const base = options.workbench_path[0 .. options.workbench_path.len - ".json".len];
        break :blk try std.fmt.allocPrint(allocator, "{s}-ci-artifact-preview", .{base});
    };
    defer allocator.free(prefix);

    return .{
        .json_path = try std.fmt.allocPrint(allocator, "{s}.json", .{prefix}),
        .text_path = try std.fmt.allocPrint(allocator, "{s}.txt", .{prefix}),
    };
}

fn formatReports(allocator: std.mem.Allocator, input: PreviewInput) !PreviewReports {
    var parsed = try std.json.parseFromSlice(WorkbenchPreviewArtifact, allocator, input.source_workbench_json, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();

    const paths = try outputPathsForOptions(allocator, input.options);
    defer paths.deinit(allocator);

    const result = try evaluatePreview(allocator, input.options, parsed.value, paths);
    defer result.deinit(allocator);

    const json = try formatPreviewJson(allocator, input.options, parsed.value, result, paths);
    errdefer allocator.free(json);
    const text = try formatPreviewText(allocator, input.options, parsed.value, result, paths);
    errdefer allocator.free(text);

    return .{ .json = json, .text = text };
}

fn evaluatePreview(
    allocator: std.mem.Allocator,
    options: Options,
    workbench: WorkbenchPreviewArtifact,
    paths: OutputPaths,
) !PreviewResult {
    var checks = std.ArrayList(PreviewCheck).empty;
    errdefer checks.deinit(allocator);

    try appendCheck(allocator, &checks, "workbench-schema", if (std.mem.eql(u8, workbench.schema, workbench_schema) and workbench.schema_version == 1) .pass else .fail, "source workbench preview schema is supported");
    try appendCheck(allocator, &checks, "workbench-ready", if (std.mem.eql(u8, workbench.preview_status, "ready")) .pass else .fail, "source workbench preview is ready");
    try appendCheck(allocator, &checks, "decision-approved", if (options.decision == .approve) .pass else .fail, "CI artifact preview decision approved the handoff");
    try appendCheck(allocator, &checks, "workbench-review-approved", if (std.mem.eql(u8, workbench.decision, "approve")) .pass else .fail, "source workbench reviewer approved the handoff");
    try appendCheck(allocator, &checks, "workbench-next-branch-ready", if (workbench.ready_for_next_branch) .pass else .fail, "source workbench preview marked the next branch ready");
    try appendCheck(allocator, &checks, "authority-disabled", if (authorityDisabled(workbench)) .pass else .fail, "live telemetry network runtime durable NenDB and CI gate authority remain disabled");
    try appendCheck(allocator, &checks, "workbench-checks-passed", if (sourceChecksPassed(workbench.checks)) .pass else .fail, "source workbench checks passed");
    try appendCheck(allocator, &checks, "workbench-verification-recorded", if (sourceVerificationRecorded(workbench)) .pass else .fail, "source workbench artifact recorded required verification command evidence");
    try appendCheck(allocator, &checks, "mapping-fixtures-carried", if (mappingFixturesPresent(workbench.nendb_mapping_fixtures)) .pass else .fail, "required NenDB mapping fixture ids are carried forward");
    try appendCheck(allocator, &checks, "artifact-candidates-present", if (artifactCandidatesPresent(paths)) .pass else .fail, "required CI artifact preview candidates are present");
    try appendCheck(allocator, &checks, "artifact-extensions-allowlisted", if (artifactExtensionsAllowlisted(paths, options.workbench_path, workbench.source_retention)) .pass else .fail, "artifact candidates use txt json or dot extensions only");
    try appendCheck(allocator, &checks, "artifact-roots-allowlisted", if (artifactRootsAllowlisted(options.workbench_path, workbench.source_retention, paths)) .pass else .fail, "artifact candidates remain in the causal artifact root or explicit source paths");
    try appendCheck(allocator, &checks, "upload-preview-only", if (!ci_upload_enabled and !ci_workflow_mutation_enabled and !ci_gate_enabled and ci_artifact_preview_enabled) .pass else .fail, "CI upload workflow mutation and gates remain disabled");
    try appendCheck(allocator, &checks, "preview-verification-recorded", if (verifiedCommandsContainAll(options.verified_commands, required_verification_commands)) .pass else .fail, "CI artifact preview recorded every required verification command");

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

fn authorityDisabled(workbench: WorkbenchPreviewArtifact) bool {
    return !workbench.applied and
        std.mem.eql(u8, workbench.mutation_authority, "none") and
        workbench.read_only_preview and
        workbench.solid_webui_enabled and
        !workbench.production_telemetry_ingestion and
        !workbench.live_exporter_enabled and
        !workbench.network_send_enabled and
        !workbench.collector_endpoint_configured and
        !workbench.otlp_serialization_enabled and
        !workbench.runtime_pipeline_enabled and
        !workbench.durable_write_enabled and
        !workbench.nendb_write_enabled and
        !workbench.ci_gate_enabled and
        !production_telemetry_ingestion and
        !live_exporter_enabled and
        !network_send_enabled and
        !collector_endpoint_configured and
        !otlp_serialization_enabled and
        !runtime_pipeline_enabled and
        !durable_write_enabled and
        !nendb_write_enabled and
        !ci_gate_enabled and
        !ci_upload_enabled and
        !ci_workflow_mutation_enabled and
        ci_artifact_preview_enabled;
}

fn sourceChecksPassed(checks: []const SourceCheck) bool {
    if (checks.len == 0) return false;
    for (checks) |check| {
        if (!std.mem.eql(u8, check.status, "pass")) return false;
    }
    return hasSourceCheck(checks, "decision-approved") or hasSourceCheck(checks, "solid-webui-readonly");
}

fn hasSourceCheck(checks: []const SourceCheck, name: []const u8) bool {
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

fn sourceVerificationRecorded(workbench: WorkbenchPreviewArtifact) bool {
    return workbench.required_verification_commands.len > 0 and
        verifiedCommandsContainAll(workbench.verified_commands, workbench.required_verification_commands);
}

fn artifactCandidatesPresent(paths: OutputPaths) bool {
    return paths.json_path.len > 0 and paths.text_path.len > 0;
}

fn artifactExtensionsAllowlisted(paths: OutputPaths, workbench_path: []const u8, retention_path: []const u8) bool {
    return extensionAllowed(workbench_path) and
        extensionAllowed(paths.json_path) and
        extensionAllowed(paths.text_path) and
        (retention_path.len == 0 or extensionAllowed(retention_path));
}

fn extensionAllowed(path: []const u8) bool {
    return std.mem.endsWith(u8, path, ".txt") or
        std.mem.endsWith(u8, path, ".json") or
        std.mem.endsWith(u8, path, ".dot");
}

fn artifactRootsAllowlisted(workbench_path: []const u8, retention_path: []const u8, paths: OutputPaths) bool {
    return causalArtifactPathAllowed(workbench_path) and
        causalArtifactPathAllowed(paths.json_path) and
        causalArtifactPathAllowed(paths.text_path) and
        (retention_path.len == 0 or causalArtifactPathAllowed(retention_path));
}

fn causalArtifactPathAllowed(path: []const u8) bool {
    return std.mem.indexOf(u8, path, ".zig-cache/causal-artifacts/") != null;
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
    workbench: WorkbenchPreviewArtifact,
    result: PreviewResult,
    paths: OutputPaths,
) ![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    const source_text_path = try jsonSiblingPath(allocator, options.workbench_path, ".txt");
    defer allocator.free(source_text_path);

    try output.appendSlice(allocator, "{\n");
    try output.appendSlice(allocator, "  \"schema\": ");
    try appendJsonString(allocator, &output, production_telemetry_ci_artifact_preview_schema);
    try output.appendSlice(allocator, ",\n  \"schema_version\": 1,\n");
    try output.appendSlice(allocator, "  \"source_workbench_preview\": ");
    try appendJsonString(allocator, &output, options.workbench_path);
    try output.appendSlice(allocator, ",\n  \"source_retention\": ");
    try appendJsonString(allocator, &output, workbench.source_retention);
    try output.appendSlice(allocator, ",\n  \"source_local_pipeline\": ");
    try appendJsonString(allocator, &output, workbench.source_local_pipeline);
    try output.appendSlice(allocator, ",\n  \"source_boundary\": ");
    try appendJsonString(allocator, &output, workbench.source_boundary);
    try output.appendSlice(allocator, ",\n  \"source_proposal\": ");
    try appendJsonString(allocator, &output, workbench.source_proposal);
    try output.appendSlice(allocator, ",\n  \"source_readiness\": ");
    try appendJsonString(allocator, &output, workbench.source_readiness);
    try output.appendSlice(allocator, ",\n  \"source_fixtures\": ");
    try appendJsonString(allocator, &output, workbench.source_fixtures);
    try output.appendSlice(allocator, ",\n  \"decision\": ");
    try appendJsonString(allocator, &output, decisionText(options.decision));
    try output.appendSlice(allocator, ",\n  \"ci_artifact_preview_status\": ");
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
    try output.print(allocator, ",\n  \"production_telemetry_ingestion\": {},\n", .{production_telemetry_ingestion});
    try output.print(allocator, "  \"live_exporter_enabled\": {},\n", .{live_exporter_enabled});
    try output.print(allocator, "  \"network_send_enabled\": {},\n", .{network_send_enabled});
    try output.print(allocator, "  \"collector_endpoint_configured\": {},\n", .{collector_endpoint_configured});
    try output.print(allocator, "  \"otlp_serialization_enabled\": {},\n", .{otlp_serialization_enabled});
    try output.print(allocator, "  \"runtime_pipeline_enabled\": {},\n", .{runtime_pipeline_enabled});
    try output.print(allocator, "  \"durable_write_enabled\": {},\n", .{durable_write_enabled});
    try output.print(allocator, "  \"nendb_write_enabled\": {},\n", .{nendb_write_enabled});
    try output.print(allocator, "  \"ci_gate_enabled\": {},\n", .{ci_gate_enabled});
    try output.print(allocator, "  \"ci_upload_enabled\": {},\n", .{ci_upload_enabled});
    try output.print(allocator, "  \"ci_workflow_mutation_enabled\": {},\n", .{ci_workflow_mutation_enabled});
    try output.print(allocator, "  \"ci_artifact_preview_enabled\": {},\n", .{ci_artifact_preview_enabled});
    try output.appendSlice(allocator, "  \"generated_by\": ");
    try appendJsonString(allocator, &output, generated_by);
    try output.appendSlice(allocator, ",\n  \"source_branch\": ");
    try appendJsonString(allocator, &output, source_branch);
    try output.appendSlice(allocator, ",\n  \"recommendation\": ");
    try appendJsonString(allocator, &output, recommendation);
    try output.appendSlice(allocator, ",\n  \"next_branch_if_ready\": ");
    try appendJsonString(allocator, &output, next_branch_if_ready);
    try output.appendSlice(allocator, ",\n  \"artifact_upload_policy\": ");
    try appendArtifactUploadPolicyJson(allocator, &output);
    try output.appendSlice(allocator, ",\n  \"artifact_candidates\": ");
    try appendArtifactCandidatesJson(allocator, &output, options, workbench, paths, source_text_path);
    try output.appendSlice(allocator, ",\n  \"mapping_fixture_ids\": ");
    try appendMappingFixtureIdsJson(allocator, &output, workbench.nendb_mapping_fixtures);
    try output.appendSlice(allocator, ",\n  \"retention_validation_checks\": ");
    try appendStringArray(allocator, &output, workbench.retention_validation_checks);
    try output.appendSlice(allocator, ",\n  \"checks\": ");
    try appendChecksJson(allocator, &output, result.checks);
    try output.appendSlice(allocator, ",\n  \"implementation_gates\": ");
    try appendStringArray(allocator, &output, implementation_gates);
    try output.appendSlice(allocator, ",\n  \"non_goals\": ");
    try appendStringArray(allocator, &output, non_goals);
    try output.appendSlice(allocator, ",\n  \"blocked_claims\": ");
    try appendStringArray(allocator, &output, blockedClaims(workbench));
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
    workbench: WorkbenchPreviewArtifact,
    result: PreviewResult,
    paths: OutputPaths,
) ![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    const source_text_path = try jsonSiblingPath(allocator, options.workbench_path, ".txt");
    defer allocator.free(source_text_path);

    try output.appendSlice(allocator, "zigeffect production telemetry CI artifact preview\n");
    try output.print(allocator, "schema: {s}\n", .{production_telemetry_ci_artifact_preview_schema});
    try output.print(allocator, "source workbench preview: {s}\n", .{options.workbench_path});
    try output.print(allocator, "source retention: {s}\n", .{workbench.source_retention});
    try output.print(allocator, "decision: {s}\n", .{decisionText(options.decision)});
    try output.print(allocator, "ci_artifact_preview_status: {s}\n", .{previewStatusText(result.status)});
    try output.print(allocator, "ready_for_next_branch: {}\n", .{result.ready_for_next_branch});
    try output.print(allocator, "reviewed_by: {s}\n", .{options.reviewed_by});
    try output.print(allocator, "policy: {s}\n", .{options.policy});
    try output.print(allocator, "reason: {s}\n", .{options.reason});
    try output.print(allocator, "applied: {}\n", .{applied});
    try output.print(allocator, "mutation_authority: {s}\n", .{mutation_authority});
    try output.print(allocator, "ci artifact preview enabled: {}\n", .{ci_artifact_preview_enabled});
    try output.print(allocator, "ci upload enabled: {}\n", .{ci_upload_enabled});
    try output.print(allocator, "ci workflow mutation enabled: {}\n", .{ci_workflow_mutation_enabled});
    try output.print(allocator, "ci gate enabled: {}\n", .{ci_gate_enabled});
    try output.print(allocator, "runtime pipeline enabled: {}\n", .{runtime_pipeline_enabled});
    try output.print(allocator, "durable write enabled: {}\n", .{durable_write_enabled});
    try output.print(allocator, "nendb write enabled: {}\n", .{nendb_write_enabled});
    try output.print(allocator, "source branch: {s}\n", .{source_branch});
    try output.print(allocator, "recommendation: {s}\n", .{recommendation});
    try output.print(allocator, "next branch if ready: {s}\n\n", .{next_branch_if_ready});

    try output.appendSlice(allocator, "artifact upload policy preview:\n");
    try output.appendSlice(allocator, "- mode: preview-only\n");
    try output.appendSlice(allocator, "- failure only: true\n");
    try output.print(allocator, "- retention days: {}\n", .{ci_artifact_retention_days});
    try output.appendSlice(allocator, "- allowed extensions: .txt .json .dot\n");
    try output.appendSlice(allocator, "- ci upload execution: false\n");
    try output.appendSlice(allocator, "- ci gate claim: false\n\n");

    try output.appendSlice(allocator, "artifact candidates:\n");
    try appendCandidateText(allocator, &output, "source-workbench-preview-json", options.workbench_path, ".json", "source-evidence", "reviewed UI and evidence handoff", "causal-production-telemetry-workbench-readonly-preview");
    try appendCandidateText(allocator, &output, "source-workbench-preview-text", source_text_path, ".txt", "source-evidence", "human-readable reviewed UI and evidence handoff", "causal-production-telemetry-workbench-readonly-preview");
    try appendCandidateText(allocator, &output, "source-retention-fixtures-json", workbench.source_retention, ".json", "source-evidence", "NenDB mapping and retention fixture evidence", "causal-production-telemetry-nendb-retention-fixtures");
    try appendCandidateText(allocator, &output, "future-ci-preview-json", paths.json_path, ".json", "preview-evidence", "agent-readable archive policy preview", generated_by);
    try appendCandidateText(allocator, &output, "future-ci-preview-text", paths.text_path, ".txt", "preview-evidence", "human-readable archive policy preview", generated_by);
    try output.append(allocator, '\n');

    try output.appendSlice(allocator, "checks:\n");
    for (result.checks) |check| {
        try output.print(allocator, "- {s}: {s} - {s}\n", .{ check.name, checkStatusText(check.status), check.detail });
    }
    try output.append(allocator, '\n');

    try appendTextList(allocator, &output, "mapping fixture ids", mappingFixtureIds(workbench.nendb_mapping_fixtures));
    try appendTextList(allocator, &output, "retention validation checks", workbench.retention_validation_checks);
    try appendTextList(allocator, &output, "implementation gates", implementation_gates);
    try appendTextList(allocator, &output, "non-goals", non_goals);
    try appendTextList(allocator, &output, "blocked claims", blockedClaims(workbench));
    try appendTextList(allocator, &output, "required verification commands", required_verification_commands);
    try appendTextList(allocator, &output, "verified commands", options.verified_commands);
    try appendTextList(allocator, &output, "agent guidance", agentGuidance(result.status));

    return output.toOwnedSlice(allocator);
}

fn appendArtifactUploadPolicyJson(allocator: std.mem.Allocator, output: *std.ArrayList(u8)) !void {
    try output.appendSlice(allocator, "{ ");
    try output.appendSlice(allocator, "\"mode\": \"preview-only\", ");
    try output.appendSlice(allocator, "\"failure_only\": true, ");
    try output.print(allocator, "\"retention_days\": {}, ", .{ci_artifact_retention_days});
    try output.appendSlice(allocator, "\"allowed_extensions\": [\".txt\", \".json\", \".dot\"], ");
    try output.appendSlice(allocator, "\"allowed_roots\": [\"packages/zigeffect/.zig-cache/causal-artifacts\", \".zig-cache/causal-artifacts\"], ");
    try output.appendSlice(allocator, "\"disallowed_roots\": [\".zig-cache\", \"packages/zigeffect/.zig-cache\"], ");
    try output.appendSlice(allocator, "\"ignore_missing_files\": true, ");
    try output.appendSlice(allocator, "\"public_upload_claim\": false, ");
    try output.appendSlice(allocator, "\"ci_gate_claim\": false");
    try output.appendSlice(allocator, " }");
}

fn appendArtifactCandidatesJson(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    options: Options,
    workbench: WorkbenchPreviewArtifact,
    paths: OutputPaths,
    source_text_path: []const u8,
) !void {
    try output.append(allocator, '[');
    try appendCandidateJson(allocator, output, "source-workbench-preview-json", options.workbench_path, ".json", "source-evidence", "reviewed UI and evidence handoff", "causal-production-telemetry-workbench-readonly-preview");
    try output.appendSlice(allocator, ", ");
    try appendCandidateJson(allocator, output, "source-workbench-preview-text", source_text_path, ".txt", "source-evidence", "human-readable reviewed UI and evidence handoff", "causal-production-telemetry-workbench-readonly-preview");
    try output.appendSlice(allocator, ", ");
    try appendCandidateJson(allocator, output, "source-retention-fixtures-json", workbench.source_retention, ".json", "source-evidence", "NenDB mapping and retention fixture evidence", "causal-production-telemetry-nendb-retention-fixtures");
    try output.appendSlice(allocator, ", ");
    try appendCandidateJson(allocator, output, "future-ci-preview-json", paths.json_path, ".json", "preview-evidence", "agent-readable archive policy preview", generated_by);
    try output.appendSlice(allocator, ", ");
    try appendCandidateJson(allocator, output, "future-ci-preview-text", paths.text_path, ".txt", "preview-evidence", "human-readable archive policy preview", generated_by);
    try output.append(allocator, ']');
}

fn appendCandidateJson(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    id: []const u8,
    path: []const u8,
    extension: []const u8,
    artifact_kind: []const u8,
    purpose: []const u8,
    produced_by: []const u8,
) !void {
    try output.appendSlice(allocator, "{ \"id\": ");
    try appendJsonString(allocator, output, id);
    try output.appendSlice(allocator, ", \"path\": ");
    try appendJsonString(allocator, output, path);
    try output.appendSlice(allocator, ", \"extension\": ");
    try appendJsonString(allocator, output, extension);
    try output.appendSlice(allocator, ", \"artifact_kind\": ");
    try appendJsonString(allocator, output, artifact_kind);
    try output.appendSlice(allocator, ", \"purpose\": ");
    try appendJsonString(allocator, output, purpose);
    try output.print(allocator, ", \"retention_days\": {}", .{ci_artifact_retention_days});
    try output.appendSlice(allocator, ", \"failure_only\": true");
    try output.appendSlice(allocator, ", \"allowed_root\": \"packages/zigeffect/.zig-cache/causal-artifacts\"");
    try output.appendSlice(allocator, ", \"produced_by\": ");
    try appendJsonString(allocator, output, produced_by);
    try output.appendSlice(allocator, ", \"consumer\": \"agents and reviewers\"");
    try output.appendSlice(allocator, ", \"redaction_required\": true");
    try output.appendSlice(allocator, ", \"public_upload_allowed\": false }");
}

fn appendCandidateText(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    id: []const u8,
    path: []const u8,
    extension: []const u8,
    artifact_kind: []const u8,
    purpose: []const u8,
    produced_by: []const u8,
) !void {
    try output.print(allocator, "- {s}: {s}\n", .{ id, path });
    try output.print(allocator, "  extension: {s}\n", .{extension});
    try output.print(allocator, "  kind: {s}\n", .{artifact_kind});
    try output.print(allocator, "  purpose: {s}\n", .{purpose});
    try output.print(allocator, "  produced by: {s}\n", .{produced_by});
    try output.appendSlice(allocator, "  failure only: true\n");
    try output.print(allocator, "  retention days: {}\n", .{ci_artifact_retention_days});
    try output.appendSlice(allocator, "  public upload allowed: false\n");
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

fn appendMappingFixtureIdsJson(allocator: std.mem.Allocator, output: *std.ArrayList(u8), fixtures: []const NendbMappingFixture) !void {
    try output.append(allocator, '[');
    for (fixtures, 0..) |fixture, index| {
        if (index > 0) try output.appendSlice(allocator, ", ");
        try appendJsonString(allocator, output, fixture.id);
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

fn jsonSiblingPath(allocator: std.mem.Allocator, json_path: []const u8, suffix: []const u8) ![]const u8 {
    if (!std.mem.endsWith(u8, json_path, ".json")) return error.InvalidWorkbenchPath;
    return std.fmt.allocPrint(allocator, "{s}{s}", .{ json_path[0 .. json_path.len - ".json".len], suffix });
}

fn mappingFixtureIds(fixtures: []const NendbMappingFixture) []const []const u8 {
    _ = fixtures;
    return &.{
        "nendb-runtime-event-node-fixture",
        "nendb-correlation-edge-fixture",
    };
}

fn blockedClaims(workbench: WorkbenchPreviewArtifact) []const []const u8 {
    if (workbench.blocked_claims.len > 0) return workbench.blocked_claims;
    return blocked_claims;
}

fn containsString(values: []const []const u8, needle: []const u8) bool {
    for (values) |value| {
        if (std.mem.indexOf(u8, value, needle) != null) return true;
    }
    return false;
}

fn usage() []const u8 {
    return "usage: zig build causal-production-telemetry-ci-artifact-preview -- --from-workbench <workbench-preview.json> approve|reject --reason <reason> [--by <actor>] [--policy <policy>] [--verified-command <command>]... [--out-prefix <path-prefix>]\n";
}

fn failUsage(err: anyerror) noreturn {
    std.debug.print("causal-production-telemetry-ci-artifact-preview error: {s}\n{s}", .{ @errorName(err), usage() });
    std.process.exit(2);
}

fn readRequiredArtifact(io: std.Io, allocator: std.mem.Allocator, path: []const u8) ![]const u8 {
    return std.Io.Dir.cwd().readFileAlloc(io, path, allocator, .limited(1024 * 1024)) catch |err| switch (err) {
        error.FileNotFound => error.MissingWorkbenchInput,
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
    const source_workbench_json = try readRequiredArtifact(init.io, allocator, options.workbench_path);
    defer allocator.free(source_workbench_json);

    const reports = try formatReports(allocator, .{
        .options = options,
        .source_workbench_json = source_workbench_json,
    });
    defer reports.deinit(allocator);

    const paths = try outputPathsForOptions(allocator, options);
    defer paths.deinit(allocator);

    try writeArtifact(init.io, paths.json_path, reports.json);
    try writeArtifact(init.io, paths.text_path, reports.text);
    std.debug.print("{s}", .{reports.text});
}

const implementation_gates: []const []const u8 = &.{
    "source workbench preview artifact is ready",
    "artifact candidates remain in preview-only allowlist",
    "CI upload execution remains disabled",
    "CI workflow mutation remains disabled",
    "CI gates remain disabled",
    "durable writes and NenDB writes remain disabled",
};

const non_goals: []const []const u8 = &.{
    "New GitHub Actions workflow or workflow mutation",
    "CI artifact upload execution",
    "CI telemetry gate enforcement",
    "Runtime telemetry ingestion or instrumentation changes",
    "Live exporter network send collector endpoint configuration or OTLP serialization",
    "Durable production writes or NenDB writes",
    "Hosted dashboard authentication authorization or mutation authority",
    "React or alternate renderer work",
    "Non-NenDB durable adapter work",
    "Cockroach adapter work",
};

const blocked_claims: []const []const u8 = &.{
    "ci-artifact-upload-enabled",
    "ci-workflow-mutated",
    "ci-telemetry-gate",
    "runtime-pipeline-enabled",
    "live-exporter-enabled",
    "network-send-enabled",
    "collector-endpoint-configured",
    "otlp-serialization-enabled",
    "durable-production-write-enabled",
    "nendb-write-enabled",
    "hosted-dashboard-production-ready",
    "mutation-authority-granted",
    "react-or-alternate-renderer",
    "non-nendb-durable-storage",
    "cockroach-adapter-work",
};

fn agentGuidance(status: PreviewStatus) []const []const u8 {
    return switch (status) {
        .ready => &.{
            "Ready CI artifact preview evidence permits starting the CI harness boundary branch only.",
            "Use the candidate catalog and upload policy preview to design archive-only CI attachments.",
            "Do not infer CI upload execution CI gates live telemetry durable writes NenDB writes hosted dashboards or mutation authority.",
        },
        .blocked => &.{
            "Blocked CI artifact preview evidence must not start CI harness boundary work.",
            "Repair source workbench evidence artifact candidate policy or required verification command evidence first.",
            "Do not treat a preview artifact as CI upload or telemetry gate enablement.",
        },
    };
}

test "ci artifact preview schema and branch constants are stable" {
    try std.testing.expectEqualStrings("zigeffect.causal.production-telemetry-ci-artifact-preview.v1", production_telemetry_ci_artifact_preview_schema);
    try std.testing.expectEqual(@as(u32, 1), production_telemetry_ci_artifact_preview_schema_version);
    try std.testing.expectEqualStrings("codex/zigeffect-causal-production-telemetry-ci-artifact-preview", source_branch);
    try std.testing.expectEqualStrings("start-production-telemetry-ci-harness-boundary", recommendation);
    try std.testing.expectEqualStrings("codex/zigeffect-causal-production-telemetry-ci-harness-boundary", next_branch_if_ready);
    try std.testing.expect(containsString(required_verification_commands, "zig build causal-production-telemetry-workbench-readonly-preview"));
    try std.testing.expect(containsString(required_verification_commands, "zig build causal-artifacts"));
    try std.testing.expect(containsString(required_verification_commands, "zig build examples"));
    try std.testing.expect(containsString(required_verification_commands, "zig build test"));
}

test "parses ci artifact preview options with verified commands" {
    var options = try parseOptions(std.testing.allocator, &.{
        "zigeffect-causal-production-telemetry-ci-artifact-preview",
        "--from-workbench",
        ".zig-cache/causal-artifacts/workbench-preview.json",
        "approve",
        "--reason",
        "CI artifact preview reviewed",
        "--by",
        "codex",
        "--policy",
        "manual-production-telemetry-ci-artifact-preview",
        "--verified-command",
        "zig build causal-artifacts",
        "--out-prefix",
        ".zig-cache/causal-artifacts/custom-ci-preview",
    });
    defer options.deinit(std.testing.allocator);

    try std.testing.expectEqual(Decision.approve, options.decision);
    try std.testing.expectEqualStrings(".zig-cache/causal-artifacts/workbench-preview.json", options.workbench_path);
    try std.testing.expectEqualStrings("CI artifact preview reviewed", options.reason);
    try std.testing.expectEqualStrings("codex", options.reviewed_by);
    try std.testing.expectEqualStrings("manual-production-telemetry-ci-artifact-preview", options.policy);
    try std.testing.expectEqual(@as(usize, 1), options.verified_commands.len);
    try std.testing.expectEqualStrings("zig build causal-artifacts", options.verified_commands[0]);
    try std.testing.expectEqualStrings(".zig-cache/causal-artifacts/custom-ci-preview", options.out_prefix.?);
}

test "ready and blocked ci artifact preview reports preserve preview-only authority" {
    const ready = try formatReports(std.testing.allocator, .{
        .options = .{
            .workbench_path = ".zig-cache/causal-artifacts/workbench-preview.json",
            .decision = .approve,
            .reason = "CI artifact preview reviewed",
            .verified_commands = required_verification_commands,
        },
        .source_workbench_json = sample_workbench_preview_json,
    });
    defer ready.deinit(std.testing.allocator);

    try std.testing.expect(std.mem.indexOf(u8, ready.json, "\"schema\": \"zigeffect.causal.production-telemetry-ci-artifact-preview.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, ready.json, "\"ci_artifact_preview_status\": \"ready\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, ready.json, "\"ready_for_next_branch\": true") != null);
    try std.testing.expect(std.mem.indexOf(u8, ready.json, "\"ci_artifact_preview_enabled\": true") != null);
    try std.testing.expect(std.mem.indexOf(u8, ready.json, "\"ci_upload_enabled\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, ready.json, "\"ci_workflow_mutation_enabled\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, ready.json, "\"ci_gate_enabled\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, ready.json, "\"allowed_extensions\": [\".txt\", \".json\", \".dot\"]") != null);
    try std.testing.expect(std.mem.indexOf(u8, ready.json, "\"id\": \"source-workbench-preview-json\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, ready.json, "\"id\": \"future-ci-preview-json\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, ready.json, "\"mapping_fixture_ids\": [\"nendb-runtime-event-node-fixture\", \"nendb-correlation-edge-fixture\"]") != null);
    try std.testing.expect(std.mem.indexOf(u8, ready.json, "\"next_branch_if_ready\": \"codex/zigeffect-causal-production-telemetry-ci-harness-boundary\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, ready.text, "ci_artifact_preview_status: ready") != null);
    try std.testing.expect(std.mem.indexOf(u8, ready.text, "ci upload enabled: false") != null);

    const blocked = try formatReports(std.testing.allocator, .{
        .options = .{
            .workbench_path = ".zig-cache/causal-artifacts/workbench-preview.json",
            .decision = .reject,
            .reason = "negative review path",
        },
        .source_workbench_json = sample_workbench_preview_json,
    });
    defer blocked.deinit(std.testing.allocator);

    try std.testing.expect(std.mem.indexOf(u8, blocked.json, "\"ci_artifact_preview_status\": \"blocked\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, blocked.json, "\"ready_for_next_branch\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, blocked.json, "\"ci_upload_enabled\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, blocked.text, "ci_artifact_preview_status: blocked") != null);
}

const sample_workbench_preview_json =
    \\{
    \\  "schema": "zigeffect.causal.production-telemetry-workbench-readonly-preview.v1",
    \\  "schema_version": 1,
    \\  "source_retention": ".zig-cache/causal-artifacts/nendb-retention.json",
    \\  "source_local_pipeline": ".zig-cache/causal-artifacts/local-pipeline.json",
    \\  "source_boundary": ".zig-cache/causal-artifacts/exporter-boundary.json",
    \\  "source_proposal": ".zig-cache/causal-artifacts/implementation-proposal.json",
    \\  "source_readiness": ".zig-cache/causal-artifacts/readiness-review.json",
    \\  "source_fixtures": ".zig-cache/causal-artifacts/capture-fixtures.json",
    \\  "decision": "approve",
    \\  "preview_status": "ready",
    \\  "ready_for_next_branch": true,
    \\  "applied": false,
    \\  "mutation_authority": "none",
    \\  "read_only_preview": true,
    \\  "solid_webui_enabled": true,
    \\  "production_telemetry_ingestion": false,
    \\  "live_exporter_enabled": false,
    \\  "network_send_enabled": false,
    \\  "collector_endpoint_configured": false,
    \\  "otlp_serialization_enabled": false,
    \\  "runtime_pipeline_enabled": false,
    \\  "durable_write_enabled": false,
    \\  "nendb_write_enabled": false,
    \\  "ci_gate_enabled": false,
    \\  "checks": [
    \\    { "name": "decision-approved", "status": "pass", "detail": "review approved" },
    \\    { "name": "solid-webui-readonly", "status": "pass", "detail": "read-only workbench" }
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
    \\    "bun run zigeffect:workbench:typecheck",
    \\    "bun run zigeffect:workbench:test"
    \\  ],
    \\  "verified_commands": [
    \\    "bun run zigeffect:workbench:typecheck",
    \\    "bun run zigeffect:workbench:test"
    \\  ],
    \\  "blocked_claims": [
    \\    "runtime-pipeline-enabled",
    \\    "ci-telemetry-gate",
    \\    "nendb-write-enabled"
    \\  ]
    \\}
;
