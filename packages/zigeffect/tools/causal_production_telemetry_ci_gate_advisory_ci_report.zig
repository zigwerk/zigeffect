const std = @import("std");

pub const production_telemetry_ci_gate_advisory_ci_report_schema = "zigeffect.causal.production-telemetry-ci-gate-advisory-ci-report.v1";
pub const production_telemetry_ci_gate_advisory_ci_report_schema_version: u32 = 1;
pub const source_branch = "codex/zigeffect-causal-production-telemetry-ci-gate-advisory-ci-report";
pub const recommendation = "start-production-telemetry-ci-gate-advisory-ci-report-application-boundary";
pub const next_branch_if_ready = "codex/zigeffect-causal-production-telemetry-ci-gate-advisory-ci-report-application-boundary";

const evaluator_schema = "zigeffect.causal.production-telemetry-ci-gate-dry-run-evaluator.v1";
const generated_by = "causal-production-telemetry-ci-gate-advisory-ci-report";
const max_source_bytes = 1024 * 1024;

const required_verification_commands: []const []const u8 = &.{
    "zig build causal-production-telemetry-ci-gate-dry-run-evaluator",
    "zig build causal-artifacts",
    "zig build release-gate --summary none",
    "zig build release-gate-report",
    "zig build causal-schema-governance -- --format json",
    "zig build causal-production-hardening-backlog -- --format json",
    "zig build examples",
    "zig build test",
};

const ci_gate_enabled = false;
const ci_gate_enforcement_enabled = false;
const ci_required_status_check_enabled = false;
const ci_workflow_mutation_enabled = false;
const ci_upload_execution_enabled = false;
const ci_report_publication_enabled = false;
const github_step_summary_write_enabled = false;
const pull_request_comment_enabled = false;
const production_telemetry_ingestion = false;
const live_exporter_enabled = false;
const network_send_enabled = false;
const collector_endpoint_configured = false;
const otlp_serialization_enabled = false;
const runtime_pipeline_enabled = false;
const durable_write_enabled = false;
const nendb_write_enabled = false;

const ReportStatus = enum { ready, advisory, blocked };
const CheckStatus = enum { pass, fail, skipped };

const Options = struct {
    evaluator_path: []const u8,
    reason: []const u8,
    reviewed_by: []const u8 = "ci-gate-advisory-ci-report",
    policy: []const u8 = "manual-production-telemetry-ci-gate-advisory-ci-report",
    out_prefix: ?[]const u8 = null,
};

const OutputPaths = struct {
    json_path: []const u8,
    text_path: []const u8,

    fn deinit(self: OutputPaths, allocator: std.mem.Allocator) void {
        allocator.free(self.json_path);
        allocator.free(self.text_path);
    }
};

const ReportInput = struct {
    options: Options,
    source_evaluator_json: []const u8,
};

const ReportArtifacts = struct {
    json: []const u8,
    text: []const u8,

    fn deinit(self: ReportArtifacts, allocator: std.mem.Allocator) void {
        allocator.free(self.json);
        allocator.free(self.text);
    }
};

const SourceSignal = struct {
    id: []const u8,
    status: []const u8,
    detail: []const u8 = "",
    evidence_path: []const u8 = "",
};

const SourceFinding = struct {
    id: []const u8,
    severity: []const u8,
    signal: []const u8 = "",
    detail: []const u8 = "",
    evidence_path: []const u8 = "",
};

const SourceCheck = struct {
    name: []const u8,
    status: []const u8,
    detail: []const u8 = "",
};

const EvaluatorArtifact = struct {
    schema: []const u8,
    schema_version: u32,
    source_dry_run_policy: []const u8 = "",
    source_policy_status: []const u8 = "",
    source_policy_decision: []const u8 = "",
    source_boundary_status: []const u8 = "",
    source_boundary_mode: []const u8 = "",
    evaluation_mode: []const u8 = "",
    evaluation_status: []const u8,
    ready_for_next_branch: bool,
    advisory_findings_count: usize = 0,
    blocked_findings_count: usize = 0,
    ci_gate_enabled: bool = false,
    ci_gate_enforcement_enabled: bool,
    ci_required_status_check_enabled: bool,
    ci_workflow_mutation_enabled: bool,
    ci_upload_execution_enabled: bool,
    production_telemetry_ingestion: bool,
    live_exporter_enabled: bool,
    network_send_enabled: bool,
    collector_endpoint_configured: bool,
    otlp_serialization_enabled: bool,
    runtime_pipeline_enabled: bool,
    durable_write_enabled: bool,
    nendb_write_enabled: bool,
    signal_evaluations: []const SourceSignal = &.{},
    findings: []const SourceFinding = &.{},
    next_queries: []const []const u8 = &.{},
    checks: []const SourceCheck = &.{},
    blocked_claims: []const []const u8 = &.{},
    required_verification_commands: []const []const u8 = &.{},
    generated_by: []const u8 = "",
};

const ReportCheck = struct {
    name: []const u8,
    status: CheckStatus,
    detail: []const u8,
};

const PublicationChannel = struct {
    id: []const u8,
    allowed: bool,
    executed_by_tool: bool,
    detail: []const u8,
};

const ReportResult = struct {
    status: ReportStatus,
    ready_for_next_branch: bool,
    checks: []const ReportCheck,

    fn deinit(self: ReportResult, allocator: std.mem.Allocator) void {
        if (self.checks.len > 0) allocator.free(self.checks);
    }
};

const report_sections: []const []const u8 = &.{
    "status",
    "source",
    "signals",
    "advisory-findings",
    "next-queries",
    "blocked-claims",
    "publication-boundary",
};

const publication_channels: []const PublicationChannel = &.{
    .{ .id = "local-json-artifact", .allowed = true, .executed_by_tool = true, .detail = "JSON report is written to the local artifact path." },
    .{ .id = "local-text-artifact", .allowed = true, .executed_by_tool = true, .detail = "Text report is written to the local artifact path." },
    .{ .id = "ci-upload-artifact", .allowed = false, .executed_by_tool = false, .detail = "CI artifact upload remains proposed-only and is not executed by this tool." },
    .{ .id = "github-step-summary", .allowed = false, .executed_by_tool = false, .detail = "GitHub step summary writing remains proposed-only and is not executed by this tool." },
    .{ .id = "pull-request-comment", .allowed = false, .executed_by_tool = false, .detail = "Pull request comments remain proposed-only and are not posted by this tool." },
};

pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len == 2 and (std.mem.eql(u8, args[1], "--help") or std.mem.eql(u8, args[1], "-h"))) {
        std.debug.print("{s}", .{usage()});
        return;
    }
    const options = parseOptions(args) catch |err| failUsage(err);
    run(init, options) catch |err| switch (err) {
        error.MissingEvaluatorInput => failUsage(err),
        else => return err,
    };
}

fn parseOptions(args: []const []const u8) !Options {
    if (args.len < 2) return error.MissingEvaluatorPath;
    if (!std.mem.eql(u8, args[1], "--from-evaluator")) return error.UnknownFlag;
    if (args.len < 3) return error.MissingEvaluatorPath;
    const evaluator_path = args[2];
    if (!std.mem.endsWith(u8, evaluator_path, ".json")) return error.InvalidEvaluatorPath;
    if (args.len < 4) return error.MissingCommand;
    if (!std.mem.eql(u8, args[3], "summarize")) return error.UnknownCommand;

    var reviewed_by: []const u8 = "ci-gate-advisory-ci-report";
    var policy: []const u8 = "manual-production-telemetry-ci-gate-advisory-ci-report";
    var reason: ?[]const u8 = null;
    var out_prefix: ?[]const u8 = null;

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
        .evaluator_path = evaluator_path,
        .reason = final_reason,
        .reviewed_by = reviewed_by,
        .policy = policy,
        .out_prefix = out_prefix,
    };
}

fn outputPathsForOptions(allocator: std.mem.Allocator, options: Options) !OutputPaths {
    const prefix = if (options.out_prefix) |out_prefix|
        try allocator.dupe(u8, out_prefix)
    else blk: {
        if (!std.mem.endsWith(u8, options.evaluator_path, ".json")) return error.InvalidEvaluatorPath;
        if (std.mem.endsWith(u8, options.evaluator_path, "-ci-gate-dry-run-evaluator.json")) {
            const suffix_len = "-ci-gate-dry-run-evaluator.json".len;
            break :blk try std.fmt.allocPrint(allocator, "{s}-ci-gate-advisory-ci-report", .{options.evaluator_path[0 .. options.evaluator_path.len - suffix_len]});
        }
        const base = options.evaluator_path[0 .. options.evaluator_path.len - ".json".len];
        break :blk try std.fmt.allocPrint(allocator, "{s}-ci-gate-advisory-ci-report", .{base});
    };
    defer allocator.free(prefix);

    return .{
        .json_path = try std.fmt.allocPrint(allocator, "{s}.json", .{prefix}),
        .text_path = try std.fmt.allocPrint(allocator, "{s}.txt", .{prefix}),
    };
}

fn formatReports(allocator: std.mem.Allocator, input: ReportInput) !ReportArtifacts {
    var parsed = try std.json.parseFromSlice(EvaluatorArtifact, allocator, input.source_evaluator_json, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();

    const paths = try outputPathsForOptions(allocator, input.options);
    defer paths.deinit(allocator);

    const result = try evaluateReport(allocator, parsed.value);
    defer result.deinit(allocator);

    const json = try formatReportJson(allocator, input.options, parsed.value, result, paths);
    errdefer allocator.free(json);
    const text = try formatReportText(allocator, input.options, parsed.value, result, paths);
    errdefer allocator.free(text);

    return .{ .json = json, .text = text };
}

fn evaluateReport(allocator: std.mem.Allocator, source: EvaluatorArtifact) !ReportResult {
    var checks = std.ArrayList(ReportCheck).empty;
    errdefer checks.deinit(allocator);

    try appendCheck(allocator, &checks, "source-evaluator-schema", if (sourceSchemaValid(source)) .pass else .fail, "source dry-run evaluator schema is supported");
    try appendCheck(allocator, &checks, "source-evaluator-reportable", if (sourceReportable(source)) .pass else .fail, "source evaluator status is ready or advisory-findings");
    try appendCheck(allocator, &checks, "source-ready-for-next-branch", if (source.ready_for_next_branch) .pass else .fail, "source evaluator is ready for advisory CI report work");
    try appendCheck(allocator, &checks, "source-no-blocked-findings", if (sourceHasNoBlockedFindings(source)) .pass else .fail, "source evaluator has no blocked findings");
    try appendCheck(allocator, &checks, "source-disabled-authority", if (sourceAuthorityDisabled(source)) .pass else .fail, "source keeps CI enforcement workflow mutation uploads live telemetry runtime durable and NenDB authority disabled");
    try appendCheck(allocator, &checks, "source-report-sections-present", if (sourceSectionsPresent(source)) .pass else .fail, "source evaluator contains signals next queries checks and blocked claims");
    try appendCheck(allocator, &checks, "report-publication-record-only", if (publicationRecordOnly()) .pass else .fail, "report publication channels are record-only and non-executing beyond local files");

    const check_slice = try checks.toOwnedSlice(allocator);
    errdefer allocator.free(check_slice);

    const status: ReportStatus = if (!allChecksPassed(check_slice))
        .blocked
    else if (std.mem.eql(u8, source.evaluation_status, "advisory-findings") or source.advisory_findings_count > 0 or countAdvisoryFindings(source.findings) > 0)
        .advisory
    else
        .ready;

    return .{
        .status = status,
        .ready_for_next_branch = status != .blocked,
        .checks = check_slice,
    };
}

fn appendCheck(
    allocator: std.mem.Allocator,
    checks: *std.ArrayList(ReportCheck),
    name: []const u8,
    status: CheckStatus,
    detail: []const u8,
) !void {
    try checks.append(allocator, .{ .name = name, .status = status, .detail = detail });
}

fn allChecksPassed(checks: []const ReportCheck) bool {
    for (checks) |check| {
        if (check.status != .pass) return false;
    }
    return true;
}

fn sourceSchemaValid(source: EvaluatorArtifact) bool {
    return std.mem.eql(u8, source.schema, evaluator_schema) and source.schema_version == 1;
}

fn sourceReportable(source: EvaluatorArtifact) bool {
    return std.mem.eql(u8, source.evaluation_status, "ready") or
        std.mem.eql(u8, source.evaluation_status, "advisory-findings");
}

fn sourceHasNoBlockedFindings(source: EvaluatorArtifact) bool {
    if (source.blocked_findings_count != 0) return false;
    for (source.findings) |finding| {
        if (std.mem.eql(u8, finding.severity, "blocked")) return false;
    }
    return true;
}

fn sourceAuthorityDisabled(source: EvaluatorArtifact) bool {
    return !source.ci_gate_enabled and
        !source.ci_gate_enforcement_enabled and
        !source.ci_required_status_check_enabled and
        !source.ci_workflow_mutation_enabled and
        !source.ci_upload_execution_enabled and
        !source.production_telemetry_ingestion and
        !source.live_exporter_enabled and
        !source.network_send_enabled and
        !source.collector_endpoint_configured and
        !source.otlp_serialization_enabled and
        !source.runtime_pipeline_enabled and
        !source.durable_write_enabled and
        !source.nendb_write_enabled;
}

fn sourceSectionsPresent(source: EvaluatorArtifact) bool {
    return source.signal_evaluations.len > 0 and
        source.next_queries.len > 0 and
        source.checks.len > 0 and
        source.blocked_claims.len > 0;
}

fn publicationRecordOnly() bool {
    return !ci_report_publication_enabled and
        !github_step_summary_write_enabled and
        !pull_request_comment_enabled and
        !ci_upload_execution_enabled and
        !ci_workflow_mutation_enabled;
}

fn countAdvisoryFindings(findings: []const SourceFinding) usize {
    var count: usize = 0;
    for (findings) |finding| {
        if (std.mem.eql(u8, finding.severity, "advisory")) count += 1;
    }
    return count;
}

fn formatReportJson(
    allocator: std.mem.Allocator,
    options: Options,
    source: EvaluatorArtifact,
    result: ReportResult,
    paths: OutputPaths,
) ![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "{\n");
    try appendJsonField(allocator, &output, "schema", production_telemetry_ci_gate_advisory_ci_report_schema, true);
    try output.appendSlice(allocator, "  \"schema_version\": 1,\n");
    try appendJsonField(allocator, &output, "source_evaluator", options.evaluator_path, true);
    try appendJsonField(allocator, &output, "source_evaluation_status", source.evaluation_status, true);
    try appendJsonField(allocator, &output, "report_status", reportStatusText(result.status), true);
    try output.print(allocator, "  \"ready_for_next_branch\": {},\n", .{result.ready_for_next_branch});
    try output.print(allocator, "  \"ci_gate_enabled\": {},\n", .{ci_gate_enabled});
    try output.print(allocator, "  \"ci_gate_enforcement_enabled\": {},\n", .{ci_gate_enforcement_enabled});
    try output.print(allocator, "  \"ci_required_status_check_enabled\": {},\n", .{ci_required_status_check_enabled});
    try output.print(allocator, "  \"ci_workflow_mutation_enabled\": {},\n", .{ci_workflow_mutation_enabled});
    try output.print(allocator, "  \"ci_upload_execution_enabled\": {},\n", .{ci_upload_execution_enabled});
    try output.print(allocator, "  \"ci_report_publication_enabled\": {},\n", .{ci_report_publication_enabled});
    try output.print(allocator, "  \"github_step_summary_write_enabled\": {},\n", .{github_step_summary_write_enabled});
    try output.print(allocator, "  \"pull_request_comment_enabled\": {},\n", .{pull_request_comment_enabled});
    try output.print(allocator, "  \"production_telemetry_ingestion\": {},\n", .{production_telemetry_ingestion});
    try output.print(allocator, "  \"live_exporter_enabled\": {},\n", .{live_exporter_enabled});
    try output.print(allocator, "  \"network_send_enabled\": {},\n", .{network_send_enabled});
    try output.print(allocator, "  \"collector_endpoint_configured\": {},\n", .{collector_endpoint_configured});
    try output.print(allocator, "  \"otlp_serialization_enabled\": {},\n", .{otlp_serialization_enabled});
    try output.print(allocator, "  \"runtime_pipeline_enabled\": {},\n", .{runtime_pipeline_enabled});
    try output.print(allocator, "  \"durable_write_enabled\": {},\n", .{durable_write_enabled});
    try output.print(allocator, "  \"nendb_write_enabled\": {},\n", .{nendb_write_enabled});
    try appendJsonField(allocator, &output, "reviewed_by", options.reviewed_by, true);
    try appendJsonField(allocator, &output, "policy", options.policy, true);
    try appendJsonField(allocator, &output, "reason", options.reason, true);
    try appendJsonField(allocator, &output, "headline", headlineForStatus(result.status), true);
    try output.appendSlice(allocator, "  \"report_sections\": ");
    try appendStringArray(allocator, &output, report_sections);
    try output.appendSlice(allocator, ",\n  \"signal_summary\": ");
    try appendSignalsJson(allocator, &output, source.signal_evaluations);
    try output.appendSlice(allocator, ",\n  \"advisory_findings\": ");
    try appendAdvisoryFindingsJson(allocator, &output, source.findings);
    try output.appendSlice(allocator, ",\n  \"next_queries\": ");
    try appendStringArray(allocator, &output, source.next_queries);
    try output.appendSlice(allocator, ",\n  \"checks\": ");
    try appendChecksJson(allocator, &output, result.checks);
    try output.appendSlice(allocator, ",\n  \"blocked_claims\": ");
    try appendStringArray(allocator, &output, source.blocked_claims);
    try output.appendSlice(allocator, ",\n  \"publication_channels\": ");
    try appendPublicationChannelsJson(allocator, &output);
    try output.appendSlice(allocator, ",\n  \"required_verification_commands\": ");
    try appendStringArray(allocator, &output, required_verification_commands);
    try appendJsonFieldPrefixComma(allocator, &output, "generated_by", generated_by);
    try appendJsonFieldPrefixComma(allocator, &output, "source_branch", source_branch);
    try appendJsonFieldPrefixComma(allocator, &output, "recommendation", recommendation);
    try appendJsonFieldPrefixComma(allocator, &output, "next_branch_if_ready", next_branch_if_ready);
    try appendJsonFieldPrefixComma(allocator, &output, "json_output", paths.json_path);
    try appendJsonFieldPrefixComma(allocator, &output, "text_output", paths.text_path);
    try output.appendSlice(allocator, ",\n  \"agent_guidance\": ");
    try appendStringArray(allocator, &output, agentGuidance(result.status));
    try output.appendSlice(allocator, "\n}\n");

    return output.toOwnedSlice(allocator);
}

fn formatReportText(
    allocator: std.mem.Allocator,
    options: Options,
    source: EvaluatorArtifact,
    result: ReportResult,
    paths: OutputPaths,
) ![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "zigeffect production telemetry CI gate advisory CI report\n");
    try output.print(allocator, "schema: {s}\n", .{production_telemetry_ci_gate_advisory_ci_report_schema});
    try output.print(allocator, "headline: {s}\n", .{headlineForStatus(result.status)});
    try output.print(allocator, "source evaluator: {s}\n", .{options.evaluator_path});
    try output.print(allocator, "source evaluation status: {s}\n", .{source.evaluation_status});
    try output.print(allocator, "report_status: {s}\n", .{reportStatusText(result.status)});
    try output.print(allocator, "ready_for_next_branch: {}\n", .{result.ready_for_next_branch});
    try output.print(allocator, "ci report publication enabled: {}\n", .{ci_report_publication_enabled});
    try output.print(allocator, "github step summary write enabled: {}\n", .{github_step_summary_write_enabled});
    try output.print(allocator, "pull request comment enabled: {}\n", .{pull_request_comment_enabled});
    try output.print(allocator, "ci upload execution enabled: {}\n", .{ci_upload_execution_enabled});
    try output.print(allocator, "reviewed_by: {s}\n", .{options.reviewed_by});
    try output.print(allocator, "policy: {s}\n", .{options.policy});
    try output.print(allocator, "reason: {s}\n", .{options.reason});
    try output.print(allocator, "source branch: {s}\n", .{source_branch});
    try output.print(allocator, "recommendation: {s}\n", .{recommendation});
    try output.print(allocator, "next branch if ready: {s}\n", .{next_branch_if_ready});
    try output.print(allocator, "json output: {s}\n", .{paths.json_path});
    try output.print(allocator, "text output: {s}\n\n", .{paths.text_path});

    try output.appendSlice(allocator, "signals:\n");
    for (source.signal_evaluations) |signal| {
        try output.print(allocator, "- {s}: {s} - {s}", .{ signal.id, signal.status, signal.detail });
        if (signal.evidence_path.len > 0) try output.print(allocator, " ({s})", .{signal.evidence_path});
        try output.append(allocator, '\n');
    }
    try output.append(allocator, '\n');

    try output.appendSlice(allocator, "advisory findings:\n");
    const advisory_count = countAdvisoryFindings(source.findings);
    if (advisory_count == 0) {
        try output.appendSlice(allocator, "- none\n");
    } else {
        for (source.findings) |finding| {
            if (!std.mem.eql(u8, finding.severity, "advisory")) continue;
            try output.print(allocator, "- {s}: {s} - {s}", .{ finding.id, finding.signal, finding.detail });
            if (finding.evidence_path.len > 0) try output.print(allocator, " ({s})", .{finding.evidence_path});
            try output.append(allocator, '\n');
        }
    }
    try output.append(allocator, '\n');

    try appendTextList(allocator, &output, "next queries", source.next_queries);
    try output.appendSlice(allocator, "checks:\n");
    for (result.checks) |check| {
        try output.print(allocator, "- {s}: {s} - {s}\n", .{ check.name, checkStatusText(check.status), check.detail });
    }
    try output.append(allocator, '\n');
    try appendTextList(allocator, &output, "blocked claims", source.blocked_claims);

    try output.appendSlice(allocator, "publication channels:\n");
    for (publication_channels) |channel| {
        try output.print(allocator, "- {s}: allowed={}, executed_by_tool={} - {s}\n", .{ channel.id, channel.allowed, channel.executed_by_tool, channel.detail });
    }
    try output.append(allocator, '\n');

    try appendTextList(allocator, &output, "required verification commands", required_verification_commands);
    try appendTextList(allocator, &output, "agent guidance", agentGuidance(result.status));

    return output.toOwnedSlice(allocator);
}

fn appendSignalsJson(allocator: std.mem.Allocator, output: *std.ArrayList(u8), signals: []const SourceSignal) !void {
    try output.append(allocator, '[');
    for (signals, 0..) |signal, index| {
        if (index > 0) try output.appendSlice(allocator, ", ");
        try output.appendSlice(allocator, "{ \"id\": ");
        try appendJsonString(allocator, output, signal.id);
        try output.appendSlice(allocator, ", \"status\": ");
        try appendJsonString(allocator, output, signal.status);
        try output.appendSlice(allocator, ", \"detail\": ");
        try appendJsonString(allocator, output, signal.detail);
        try output.appendSlice(allocator, ", \"evidence_path\": ");
        try appendJsonString(allocator, output, signal.evidence_path);
        try output.appendSlice(allocator, " }");
    }
    try output.append(allocator, ']');
}

fn appendAdvisoryFindingsJson(allocator: std.mem.Allocator, output: *std.ArrayList(u8), findings: []const SourceFinding) !void {
    try output.append(allocator, '[');
    var emitted: usize = 0;
    for (findings) |finding| {
        if (!std.mem.eql(u8, finding.severity, "advisory")) continue;
        if (emitted > 0) try output.appendSlice(allocator, ", ");
        emitted += 1;
        try output.appendSlice(allocator, "{ \"id\": ");
        try appendJsonString(allocator, output, finding.id);
        try output.appendSlice(allocator, ", \"signal\": ");
        try appendJsonString(allocator, output, finding.signal);
        try output.appendSlice(allocator, ", \"detail\": ");
        try appendJsonString(allocator, output, finding.detail);
        try output.appendSlice(allocator, ", \"evidence_path\": ");
        try appendJsonString(allocator, output, finding.evidence_path);
        try output.appendSlice(allocator, " }");
    }
    try output.append(allocator, ']');
}

fn appendChecksJson(allocator: std.mem.Allocator, output: *std.ArrayList(u8), checks: []const ReportCheck) !void {
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

fn appendPublicationChannelsJson(allocator: std.mem.Allocator, output: *std.ArrayList(u8)) !void {
    try output.append(allocator, '[');
    for (publication_channels, 0..) |channel, index| {
        if (index > 0) try output.appendSlice(allocator, ", ");
        try output.appendSlice(allocator, "{ \"id\": ");
        try appendJsonString(allocator, output, channel.id);
        try output.print(allocator, ", \"allowed\": {}, \"executed_by_tool\": {}, \"detail\": ", .{ channel.allowed, channel.executed_by_tool });
        try appendJsonString(allocator, output, channel.detail);
        try output.appendSlice(allocator, " }");
    }
    try output.append(allocator, ']');
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

fn reportStatusText(status: ReportStatus) []const u8 {
    return switch (status) {
        .ready => "ready",
        .advisory => "advisory",
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

fn headlineForStatus(status: ReportStatus) []const u8 {
    return switch (status) {
        .ready => "Dry-run evaluator evidence is ready for advisory CI report presentation.",
        .advisory => "Dry-run evaluator evidence is reportable with advisory findings.",
        .blocked => "Dry-run evaluator evidence is blocked and must not be presented as CI guidance.",
    };
}

fn agentGuidance(status: ReportStatus) []const []const u8 {
    return switch (status) {
        .ready => &.{
            "Use this local report artifact as reviewer-facing advisory CI guidance.",
            "Do not convert this report into required checks, workflow mutations, live telemetry, durable writes, NenDB writes, or mutation authority.",
        },
        .advisory => &.{
            "Surface advisory findings as reviewer guidance only.",
            "Keep missing evidence signals non-blocking unless a later reviewed policy branch changes that boundary.",
        },
        .blocked => &.{
            "Do not present blocked evaluator output as CI guidance.",
            "Repair evaluator source evidence before considering report application work.",
        },
    };
}

fn readRequiredArtifact(io: std.Io, allocator: std.mem.Allocator, path: []const u8, err: anyerror) ![]const u8 {
    return std.Io.Dir.cwd().readFileAlloc(io, path, allocator, .limited(max_source_bytes)) catch |read_err| switch (read_err) {
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
    const source_evaluator_json = try readRequiredArtifact(init.io, allocator, options.evaluator_path, error.MissingEvaluatorInput);
    defer allocator.free(source_evaluator_json);

    const reports = try formatReports(allocator, .{
        .options = options,
        .source_evaluator_json = source_evaluator_json,
    });
    defer reports.deinit(allocator);

    const paths = try outputPathsForOptions(allocator, options);
    defer paths.deinit(allocator);

    try writeArtifact(init.io, paths.json_path, reports.json);
    try writeArtifact(init.io, paths.text_path, reports.text);
    std.debug.print("{s}", .{reports.text});
}

fn usage() []const u8 {
    return "usage: zig build causal-production-telemetry-ci-gate-advisory-ci-report -- --from-evaluator <dry-run-evaluator.json> summarize --reason <reason> [--by <actor>] [--policy <policy>] [--out-prefix <path-prefix>]\n";
}

fn failUsage(err: anyerror) noreturn {
    std.debug.print("causal-production-telemetry-ci-gate-advisory-ci-report error: {s}\n{s}", .{ @errorName(err), usage() });
    std.process.exit(2);
}

test "ci gate advisory CI report schema and branch constants are stable" {
    try std.testing.expectEqualStrings("zigeffect.causal.production-telemetry-ci-gate-advisory-ci-report.v1", production_telemetry_ci_gate_advisory_ci_report_schema);
    try std.testing.expectEqual(@as(u32, 1), production_telemetry_ci_gate_advisory_ci_report_schema_version);
    try std.testing.expectEqualStrings("codex/zigeffect-causal-production-telemetry-ci-gate-advisory-ci-report", source_branch);
    try std.testing.expectEqualStrings("start-production-telemetry-ci-gate-advisory-ci-report-application-boundary", recommendation);
    try std.testing.expectEqualStrings("codex/zigeffect-causal-production-telemetry-ci-gate-advisory-ci-report-application-boundary", next_branch_if_ready);
}

test "parses advisory CI report options" {
    const options = try parseOptions(&.{
        "zigeffect-causal-production-telemetry-ci-gate-advisory-ci-report",
        "--from-evaluator",
        ".zig-cache/causal-artifacts/example-ci-gate-dry-run-evaluator.json",
        "summarize",
        "--reason",
        "CI advisory report reviewed",
        "--by",
        "codex",
        "--policy",
        "manual-production-telemetry-ci-gate-advisory-ci-report",
        "--out-prefix",
        ".zig-cache/causal-artifacts/custom-advisory-ci-report",
    });

    try std.testing.expectEqualStrings(".zig-cache/causal-artifacts/example-ci-gate-dry-run-evaluator.json", options.evaluator_path);
    try std.testing.expectEqualStrings("CI advisory report reviewed", options.reason);
    try std.testing.expectEqualStrings("codex", options.reviewed_by);
    try std.testing.expectEqualStrings("manual-production-telemetry-ci-gate-advisory-ci-report", options.policy);
    try std.testing.expectEqualStrings(".zig-cache/causal-artifacts/custom-advisory-ci-report", options.out_prefix.?);
}

test "default output path replaces dry-run evaluator suffix" {
    const options = Options{
        .evaluator_path = "../../.zig-cache/causal-artifacts/example-ci-gate-dry-run-evaluator.json",
        .reason = "planned",
    };
    const paths = try outputPathsForOptions(std.testing.allocator, options);
    defer paths.deinit(std.testing.allocator);

    try std.testing.expectEqualStrings("../../.zig-cache/causal-artifacts/example-ci-gate-advisory-ci-report.json", paths.json_path);
    try std.testing.expectEqualStrings("../../.zig-cache/causal-artifacts/example-ci-gate-advisory-ci-report.txt", paths.text_path);
}

test "ready evaluator produces ready advisory CI report" {
    const reports = try formatReports(std.testing.allocator, .{
        .options = sampleOptions(),
        .source_evaluator_json = sample_ready_evaluator_json,
    });
    defer reports.deinit(std.testing.allocator);

    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"schema\": \"zigeffect.causal.production-telemetry-ci-gate-advisory-ci-report.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"report_status\": \"ready\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"ready_for_next_branch\": true") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"github_step_summary_write_enabled\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"pull_request_comment_enabled\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"next_branch_if_ready\": \"codex/zigeffect-causal-production-telemetry-ci-gate-advisory-ci-report-application-boundary\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.text, "report_status: ready") != null);
}

test "advisory evaluator produces advisory report not blocked report" {
    const reports = try formatReports(std.testing.allocator, .{
        .options = sampleOptions(),
        .source_evaluator_json = sample_advisory_evaluator_json,
    });
    defer reports.deinit(std.testing.allocator);

    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"report_status\": \"advisory\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"ready_for_next_branch\": true") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"advisory_findings\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"id\": \"ci-handoff-present\"") != null);
}

test "blocked evaluator produces blocked advisory report" {
    const reports = try formatReports(std.testing.allocator, .{
        .options = sampleOptions(),
        .source_evaluator_json = sample_blocked_evaluator_json,
    });
    defer reports.deinit(std.testing.allocator);

    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"report_status\": \"blocked\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"ready_for_next_branch\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"name\": \"source-evaluator-reportable\"") != null);
}

test "authority enabled in evaluator blocks report" {
    const reports = try formatReports(std.testing.allocator, .{
        .options = sampleOptions(),
        .source_evaluator_json = sample_authority_violation_evaluator_json,
    });
    defer reports.deinit(std.testing.allocator);

    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"report_status\": \"blocked\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"name\": \"source-disabled-authority\"") != null);
}

test "publication channels remain record-only" {
    const reports = try formatReports(std.testing.allocator, .{
        .options = sampleOptions(),
        .source_evaluator_json = sample_ready_evaluator_json,
    });
    defer reports.deinit(std.testing.allocator);

    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"id\": \"local-json-artifact\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"id\": \"github-step-summary\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"id\": \"pull-request-comment\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"executed_by_tool\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.text, "github-step-summary: allowed=false, executed_by_tool=false") != null);
}

fn sampleOptions() Options {
    return .{
        .evaluator_path = ".zig-cache/causal-artifacts/example-ci-gate-dry-run-evaluator.json",
        .reason = "CI advisory report reviewed",
    };
}

const sample_ready_evaluator_json =
    \\{
    \\  "schema": "zigeffect.causal.production-telemetry-ci-gate-dry-run-evaluator.v1",
    \\  "schema_version": 1,
    \\  "source_dry_run_policy": ".zig-cache/causal-artifacts/example-ci-gate-dry-run-policy.json",
    \\  "source_policy_status": "ready",
    \\  "source_policy_decision": "approve",
    \\  "source_boundary_status": "planned",
    \\  "source_boundary_mode": "plan",
    \\  "evaluation_mode": "dry-run",
    \\  "evaluation_status": "ready",
    \\  "ready_for_next_branch": true,
    \\  "advisory_findings_count": 0,
    \\  "blocked_findings_count": 0,
    \\  "ci_gate_enabled": false,
    \\  "ci_gate_enforcement_enabled": false,
    \\  "ci_required_status_check_enabled": false,
    \\  "ci_workflow_mutation_enabled": false,
    \\  "ci_upload_execution_enabled": false,
    \\  "production_telemetry_ingestion": false,
    \\  "live_exporter_enabled": false,
    \\  "network_send_enabled": false,
    \\  "collector_endpoint_configured": false,
    \\  "otlp_serialization_enabled": false,
    \\  "runtime_pipeline_enabled": false,
    \\  "durable_write_enabled": false,
    \\  "nendb_write_enabled": false,
    \\  "signal_evaluations": [
    \\    { "id": "boundary-source-valid", "status": "observed", "detail": "source policy is valid", "evidence_path": "" },
    \\    { "id": "release-gate-artifact-present", "status": "observed", "detail": "release gate present", "evidence_path": ".zig-cache/release-gate/zigeffect-release-gate.json" }
    \\  ],
    \\  "findings": [],
    \\  "next_queries": ["Compare evaluator evidence paths against release-gate and causal artifact outputs before presenting CI summaries."],
    \\  "checks": [
    \\    { "name": "source-policy-schema", "status": "pass", "detail": "source dry-run policy schema is supported" }
    \\  ],
    \\  "blocked_claims": ["ci-gate-enforcement-active", "required-status-check-active", "nendb-write-enabled"],
    \\  "required_verification_commands": ["zig build causal-production-telemetry-ci-gate-dry-run-evaluator"],
    \\  "generated_by": "causal-production-telemetry-ci-gate-dry-run-evaluator"
    \\}
;

const sample_advisory_evaluator_json =
    \\{
    \\  "schema": "zigeffect.causal.production-telemetry-ci-gate-dry-run-evaluator.v1",
    \\  "schema_version": 1,
    \\  "source_dry_run_policy": ".zig-cache/causal-artifacts/example-ci-gate-dry-run-policy.json",
    \\  "source_policy_status": "ready",
    \\  "source_policy_decision": "approve",
    \\  "source_boundary_status": "planned",
    \\  "source_boundary_mode": "plan",
    \\  "evaluation_mode": "dry-run",
    \\  "evaluation_status": "advisory-findings",
    \\  "ready_for_next_branch": true,
    \\  "advisory_findings_count": 1,
    \\  "blocked_findings_count": 0,
    \\  "ci_gate_enabled": false,
    \\  "ci_gate_enforcement_enabled": false,
    \\  "ci_required_status_check_enabled": false,
    \\  "ci_workflow_mutation_enabled": false,
    \\  "ci_upload_execution_enabled": false,
    \\  "production_telemetry_ingestion": false,
    \\  "live_exporter_enabled": false,
    \\  "network_send_enabled": false,
    \\  "collector_endpoint_configured": false,
    \\  "otlp_serialization_enabled": false,
    \\  "runtime_pipeline_enabled": false,
    \\  "durable_write_enabled": false,
    \\  "nendb_write_enabled": false,
    \\  "signal_evaluations": [
    \\    { "id": "ci-handoff-present", "status": "missing", "detail": "CI handoff evidence was not supplied", "evidence_path": "" }
    \\  ],
    \\  "findings": [
    \\    { "id": "ci-handoff-present", "severity": "advisory", "signal": "ci-handoff-present", "detail": "CI handoff evidence was not supplied", "evidence_path": "" }
    \\  ],
    \\  "next_queries": ["Inspect missing signal findings and decide whether advisory CI report should surface them as reviewer guidance."],
    \\  "checks": [
    \\    { "name": "source-policy-schema", "status": "pass", "detail": "source dry-run policy schema is supported" }
    \\  ],
    \\  "blocked_claims": ["ci-gate-enforcement-active", "required-status-check-active", "nendb-write-enabled"],
    \\  "required_verification_commands": ["zig build causal-production-telemetry-ci-gate-dry-run-evaluator"],
    \\  "generated_by": "causal-production-telemetry-ci-gate-dry-run-evaluator"
    \\}
;

const sample_blocked_evaluator_json =
    \\{
    \\  "schema": "zigeffect.causal.production-telemetry-ci-gate-dry-run-evaluator.v1",
    \\  "schema_version": 1,
    \\  "source_dry_run_policy": ".zig-cache/causal-artifacts/example-ci-gate-dry-run-policy.json",
    \\  "source_policy_status": "blocked",
    \\  "source_policy_decision": "reject",
    \\  "source_boundary_status": "planned",
    \\  "source_boundary_mode": "plan",
    \\  "evaluation_mode": "dry-run",
    \\  "evaluation_status": "blocked",
    \\  "ready_for_next_branch": false,
    \\  "advisory_findings_count": 0,
    \\  "blocked_findings_count": 1,
    \\  "ci_gate_enabled": false,
    \\  "ci_gate_enforcement_enabled": false,
    \\  "ci_required_status_check_enabled": false,
    \\  "ci_workflow_mutation_enabled": false,
    \\  "ci_upload_execution_enabled": false,
    \\  "production_telemetry_ingestion": false,
    \\  "live_exporter_enabled": false,
    \\  "network_send_enabled": false,
    \\  "collector_endpoint_configured": false,
    \\  "otlp_serialization_enabled": false,
    \\  "runtime_pipeline_enabled": false,
    \\  "durable_write_enabled": false,
    \\  "nendb_write_enabled": false,
    \\  "signal_evaluations": [
    \\    { "id": "boundary-source-valid", "status": "blocked", "detail": "source policy failed", "evidence_path": "" }
    \\  ],
    \\  "findings": [
    \\    { "id": "source-policy-ready", "severity": "blocked", "signal": "boundary-source-valid", "detail": "source dry-run policy status is ready", "evidence_path": "" }
    \\  ],
    \\  "next_queries": ["Repair source policy validity before starting the advisory CI report branch."],
    \\  "checks": [
    \\    { "name": "source-policy-ready", "status": "fail", "detail": "source dry-run policy status is ready" }
    \\  ],
    \\  "blocked_claims": ["ci-gate-enforcement-active", "required-status-check-active", "nendb-write-enabled"],
    \\  "required_verification_commands": ["zig build causal-production-telemetry-ci-gate-dry-run-evaluator"],
    \\  "generated_by": "causal-production-telemetry-ci-gate-dry-run-evaluator"
    \\}
;

const sample_authority_violation_evaluator_json =
    \\{
    \\  "schema": "zigeffect.causal.production-telemetry-ci-gate-dry-run-evaluator.v1",
    \\  "schema_version": 1,
    \\  "source_dry_run_policy": ".zig-cache/causal-artifacts/example-ci-gate-dry-run-policy.json",
    \\  "source_policy_status": "ready",
    \\  "source_policy_decision": "approve",
    \\  "source_boundary_status": "planned",
    \\  "source_boundary_mode": "plan",
    \\  "evaluation_mode": "dry-run",
    \\  "evaluation_status": "ready",
    \\  "ready_for_next_branch": true,
    \\  "advisory_findings_count": 0,
    \\  "blocked_findings_count": 0,
    \\  "ci_gate_enabled": false,
    \\  "ci_gate_enforcement_enabled": true,
    \\  "ci_required_status_check_enabled": false,
    \\  "ci_workflow_mutation_enabled": false,
    \\  "ci_upload_execution_enabled": false,
    \\  "production_telemetry_ingestion": false,
    \\  "live_exporter_enabled": false,
    \\  "network_send_enabled": false,
    \\  "collector_endpoint_configured": false,
    \\  "otlp_serialization_enabled": false,
    \\  "runtime_pipeline_enabled": false,
    \\  "durable_write_enabled": false,
    \\  "nendb_write_enabled": false,
    \\  "signal_evaluations": [
    \\    { "id": "boundary-source-valid", "status": "observed", "detail": "source policy is valid", "evidence_path": "" }
    \\  ],
    \\  "findings": [],
    \\  "next_queries": ["Compare evaluator evidence paths against release-gate and causal artifact outputs before presenting CI summaries."],
    \\  "checks": [
    \\    { "name": "source-policy-schema", "status": "pass", "detail": "source dry-run policy schema is supported" }
    \\  ],
    \\  "blocked_claims": ["ci-gate-enforcement-active", "required-status-check-active", "nendb-write-enabled"],
    \\  "required_verification_commands": ["zig build causal-production-telemetry-ci-gate-dry-run-evaluator"],
    \\  "generated_by": "causal-production-telemetry-ci-gate-dry-run-evaluator"
    \\}
;
