const std = @import("std");

pub const production_telemetry_ci_gate_required_status_check_enforcement_report_schema = "zigeffect.causal.production-telemetry-ci-gate-required-status-check-enforcement-report.v1";
pub const production_telemetry_ci_gate_required_status_check_enforcement_report_schema_version: u32 = 1;
pub const source_branch = "codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-enforcement-report";
pub const recommendation = "start-production-telemetry-ci-gate-required-status-check-enforcement-report-application-boundary";
pub const next_branch_if_ready = "codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-enforcement-report-application-boundary";

const source_evaluator_schema = "zigeffect.causal.production-telemetry-ci-gate-required-status-check-enforcement-evaluator.v1";
const generated_by = "causal-production-telemetry-ci-gate-required-status-check-enforcement-report";
const max_source_bytes = 1024 * 1024;
const mutation_authority = "none";

const required_verification_commands: []const []const u8 = &.{
    "zig build causal-production-telemetry-ci-gate-required-status-check-enforcement-evaluator",
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
const github_api_mutation_enabled = false;
const github_check_run_creation_enabled = false;
const branch_protection_mutation_by_tool_enabled = false;
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
const CheckStatus = enum { pass, fail };

const Options = struct {
    evaluator_path: []const u8,
    reason: []const u8,
    reviewed_by: []const u8 = "ci-gate-required-status-check-enforcement-report",
    policy: []const u8 = "manual-production-telemetry-ci-gate-required-status-check-enforcement-report",
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

const SourceEvidenceFile = struct {
    path: []const u8 = "",
    class: []const u8 = "",
    size_bytes: usize = 0,
    sha256: []const u8 = "",
    detected_schema: []const u8 = "",
    denied_reason: []const u8 = "",
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
    source_enforcement_policy: []const u8 = "",
    source_policy_status: []const u8 = "",
    source_policy_ready_for_next_branch: bool = false,
    source_active_enforcement_policy_ready: bool = false,
    source_merge_blocker_policy_ready: bool = false,
    required_status_check_enforcement_evaluator_status: []const u8,
    ready_for_next_branch: bool,
    blocked_findings_count: usize = 0,
    advisory_findings_count: usize = 0,
    ci_gate_enabled: bool = false,
    ci_gate_enforcement_enabled: bool = false,
    ci_required_status_check_enabled: bool = false,
    ci_workflow_mutation_enabled: bool = false,
    ci_upload_execution_enabled: bool = false,
    ci_report_publication_enabled: bool = false,
    github_api_mutation_enabled: bool = false,
    github_check_run_creation_enabled: bool = false,
    branch_protection_mutation_by_tool_enabled: bool = false,
    github_step_summary_write_enabled: bool = false,
    pull_request_comment_enabled: bool = false,
    production_telemetry_ingestion: bool = false,
    live_exporter_enabled: bool = false,
    network_send_enabled: bool = false,
    collector_endpoint_configured: bool = false,
    otlp_serialization_enabled: bool = false,
    runtime_pipeline_enabled: bool = false,
    durable_write_enabled: bool = false,
    nendb_write_enabled: bool = false,
    mutation_authority: []const u8 = "",
    evidence_files: []const SourceEvidenceFile = &.{},
    checks: []const SourceCheck = &.{},
    signal_evaluations: []const SourceSignal = &.{},
    findings: []const SourceFinding = &.{},
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
    "evidence",
    "signals",
    "blocked-findings",
    "advisory-findings",
    "checks",
    "blocked-claims",
    "publication-boundary",
};

const publication_channels: []const PublicationChannel = &.{
    .{ .id = "local-json-artifact", .allowed = true, .executed_by_tool = true, .detail = "JSON report is written to the local artifact path." },
    .{ .id = "local-text-artifact", .allowed = true, .executed_by_tool = true, .detail = "Text report is written to the local artifact path." },
    .{ .id = "ci-upload-artifact", .allowed = false, .executed_by_tool = false, .detail = "CI artifact upload remains proposed-only and is not executed by this tool." },
    .{ .id = "github-step-summary", .allowed = false, .executed_by_tool = false, .detail = "GitHub step summary writing remains proposed-only and is not executed by this tool." },
    .{ .id = "pull-request-comment", .allowed = false, .executed_by_tool = false, .detail = "Pull request comments remain proposed-only and are not posted by this tool." },
    .{ .id = "required-status-check", .allowed = false, .executed_by_tool = false, .detail = "Required status checks remain future reviewed application work." },
    .{ .id = "branch-protection-update", .allowed = false, .executed_by_tool = false, .detail = "Branch protection updates remain future reviewed application work." },
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

    var reviewed_by: []const u8 = "ci-gate-required-status-check-enforcement-report";
    var policy: []const u8 = "manual-production-telemetry-ci-gate-required-status-check-enforcement-report";
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
        if (std.mem.endsWith(u8, options.evaluator_path, "-ci-gate-required-status-check-enforcement-evaluator.json")) {
            const suffix_len = "-ci-gate-required-status-check-enforcement-evaluator.json".len;
            break :blk try std.fmt.allocPrint(allocator, "{s}-ci-gate-required-status-check-enforcement-report", .{options.evaluator_path[0 .. options.evaluator_path.len - suffix_len]});
        }
        const base = options.evaluator_path[0 .. options.evaluator_path.len - ".json".len];
        break :blk try std.fmt.allocPrint(allocator, "{s}-ci-gate-required-status-check-enforcement-report", .{base});
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

    try appendCheck(allocator, &checks, "source-evaluator-schema", if (sourceSchemaValid(source)) .pass else .fail, "source enforcement evaluator schema is supported");
    try appendCheck(allocator, &checks, "source-evaluator-reportable", if (sourceReportable(source)) .pass else .fail, "source evaluator status is ready or advisory-findings");
    try appendCheck(allocator, &checks, "source-ready-for-next-branch", if (source.ready_for_next_branch) .pass else .fail, "source evaluator is ready for enforcement report work");
    try appendCheck(allocator, &checks, "source-no-blocked-findings", if (sourceHasNoBlockedFindings(source)) .pass else .fail, "source evaluator has no blocked findings");
    try appendCheck(allocator, &checks, "source-disabled-authority", if (sourceAuthorityDisabled(source)) .pass else .fail, "source keeps GitHub workflow check-run upload summary comment live telemetry runtime durable and NenDB authority disabled");
    try appendCheck(allocator, &checks, "source-report-sections-present", if (sourceSectionsPresent(source)) .pass else .fail, "source evaluator contains evidence signals checks blocked claims and verification commands");
    try appendCheck(allocator, &checks, "report-publication-record-only", if (publicationRecordOnly()) .pass else .fail, "report publication channels are record-only and non-executing beyond local files");

    const check_slice = try checks.toOwnedSlice(allocator);
    errdefer allocator.free(check_slice);

    const status: ReportStatus = if (!allChecksPassed(check_slice))
        .blocked
    else if (std.mem.eql(u8, source.required_status_check_enforcement_evaluator_status, "advisory-findings") or source.advisory_findings_count > 0 or countFindings(source.findings, "advisory") > 0)
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
    return std.mem.eql(u8, source.schema, source_evaluator_schema) and source.schema_version == 1;
}

fn sourceReportable(source: EvaluatorArtifact) bool {
    return std.mem.eql(u8, source.required_status_check_enforcement_evaluator_status, "ready") or
        std.mem.eql(u8, source.required_status_check_enforcement_evaluator_status, "advisory-findings");
}

fn sourceHasNoBlockedFindings(source: EvaluatorArtifact) bool {
    if (source.blocked_findings_count != 0) return false;
    return countFindings(source.findings, "blocked") == 0;
}

fn sourceAuthorityDisabled(source: EvaluatorArtifact) bool {
    return !source.ci_gate_enabled and
        !source.ci_gate_enforcement_enabled and
        !source.ci_required_status_check_enabled and
        !source.ci_workflow_mutation_enabled and
        !source.ci_upload_execution_enabled and
        !source.ci_report_publication_enabled and
        !source.github_api_mutation_enabled and
        !source.github_check_run_creation_enabled and
        !source.branch_protection_mutation_by_tool_enabled and
        !source.github_step_summary_write_enabled and
        !source.pull_request_comment_enabled and
        !source.production_telemetry_ingestion and
        !source.live_exporter_enabled and
        !source.network_send_enabled and
        !source.collector_endpoint_configured and
        !source.otlp_serialization_enabled and
        !source.runtime_pipeline_enabled and
        !source.durable_write_enabled and
        !source.nendb_write_enabled and
        std.mem.eql(u8, source.mutation_authority, "none");
}

fn sourceSectionsPresent(source: EvaluatorArtifact) bool {
    return source.evidence_files.len > 0 and
        source.signal_evaluations.len > 0 and
        source.checks.len > 0 and
        source.blocked_claims.len > 0 and
        source.required_verification_commands.len > 0;
}

fn publicationRecordOnly() bool {
    return !ci_report_publication_enabled and
        !github_step_summary_write_enabled and
        !pull_request_comment_enabled and
        !ci_upload_execution_enabled and
        !ci_workflow_mutation_enabled and
        !github_api_mutation_enabled and
        !github_check_run_creation_enabled and
        !branch_protection_mutation_by_tool_enabled and
        !ci_required_status_check_enabled;
}

fn countFindings(findings: []const SourceFinding, severity: []const u8) usize {
    var count: usize = 0;
    for (findings) |finding| {
        if (std.mem.eql(u8, finding.severity, severity)) count += 1;
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
    try appendJsonField(allocator, &output, "schema", production_telemetry_ci_gate_required_status_check_enforcement_report_schema, true);
    try output.print(allocator, "  \"schema_version\": {},\n", .{production_telemetry_ci_gate_required_status_check_enforcement_report_schema_version});
    try appendJsonField(allocator, &output, "source_evaluator", options.evaluator_path, true);
    try appendJsonField(allocator, &output, "source_evaluator_status", source.required_status_check_enforcement_evaluator_status, true);
    try output.print(allocator, "  \"source_ready_for_next_branch\": {},\n", .{source.ready_for_next_branch});
    try appendJsonField(allocator, &output, "required_status_check_enforcement_report_status", reportStatusText(result.status), true);
    try output.print(allocator, "  \"ready_for_next_branch\": {},\n", .{result.ready_for_next_branch});
    try output.print(allocator, "  \"blocked_findings_count\": {d},\n", .{source.blocked_findings_count});
    try output.print(allocator, "  \"advisory_findings_count\": {d},\n", .{source.advisory_findings_count});
    try appendAuthorityJson(allocator, &output);
    try appendJsonField(allocator, &output, "mutation_authority", mutation_authority, true);
    try appendJsonField(allocator, &output, "reviewed_by", options.reviewed_by, true);
    try appendJsonField(allocator, &output, "policy", options.policy, true);
    try appendJsonField(allocator, &output, "reason", options.reason, true);
    try appendJsonField(allocator, &output, "headline", headlineForStatus(result.status), true);
    try output.appendSlice(allocator, "  \"report_sections\": ");
    try appendStringArray(allocator, &output, report_sections);
    try output.appendSlice(allocator, ",\n  \"evidence_summary\": ");
    try appendEvidenceJson(allocator, &output, source.evidence_files);
    try output.appendSlice(allocator, ",\n  \"signal_summary\": ");
    try appendSignalsJson(allocator, &output, source.signal_evaluations);
    try output.appendSlice(allocator, ",\n  \"blocked_findings\": ");
    try appendFindingsJson(allocator, &output, source.findings, "blocked");
    try output.appendSlice(allocator, ",\n  \"advisory_findings\": ");
    try appendFindingsJson(allocator, &output, source.findings, "advisory");
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

    try output.appendSlice(allocator, "zigeffect production telemetry CI gate required status check enforcement report\n");
    try output.print(allocator, "schema: {s}\n", .{production_telemetry_ci_gate_required_status_check_enforcement_report_schema});
    try output.print(allocator, "headline: {s}\n", .{headlineForStatus(result.status)});
    try output.print(allocator, "source evaluator: {s}\n", .{options.evaluator_path});
    try output.print(allocator, "source evaluator status: {s}\n", .{source.required_status_check_enforcement_evaluator_status});
    try output.print(allocator, "source ready for next branch: {}\n", .{source.ready_for_next_branch});
    try output.print(allocator, "required status check enforcement report status: {s}\n", .{reportStatusText(result.status)});
    try output.print(allocator, "ready for next branch: {}\n", .{result.ready_for_next_branch});
    try output.print(allocator, "blocked findings count: {d}\n", .{source.blocked_findings_count});
    try output.print(allocator, "advisory findings count: {d}\n", .{source.advisory_findings_count});
    try output.print(allocator, "mutation authority: {s}\n", .{mutation_authority});
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

    try output.appendSlice(allocator, "evidence summary:\n");
    for (source.evidence_files) |evidence| {
        try output.print(allocator, "- {s}: {s}, {d} bytes", .{ evidence.path, evidence.class, evidence.size_bytes });
        if (evidence.detected_schema.len > 0) try output.print(allocator, ", schema={s}", .{evidence.detected_schema});
        if (evidence.denied_reason.len > 0) try output.print(allocator, ", denied={s}", .{evidence.denied_reason});
        try output.append(allocator, '\n');
    }
    try output.append(allocator, '\n');

    try output.appendSlice(allocator, "signals:\n");
    for (source.signal_evaluations) |signal| {
        try output.print(allocator, "- {s}: {s} - {s}", .{ signal.id, signal.status, signal.detail });
        if (signal.evidence_path.len > 0) try output.print(allocator, " ({s})", .{signal.evidence_path});
        try output.append(allocator, '\n');
    }
    try output.append(allocator, '\n');

    try appendFindingText(allocator, &output, "blocked findings", source.findings, "blocked");
    try appendFindingText(allocator, &output, "advisory findings", source.findings, "advisory");

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

fn appendAuthorityJson(allocator: std.mem.Allocator, output: *std.ArrayList(u8)) !void {
    try output.print(allocator, "  \"ci_gate_enabled\": {},\n", .{ci_gate_enabled});
    try output.print(allocator, "  \"ci_gate_enforcement_enabled\": {},\n", .{ci_gate_enforcement_enabled});
    try output.print(allocator, "  \"ci_required_status_check_enabled\": {},\n", .{ci_required_status_check_enabled});
    try output.print(allocator, "  \"ci_workflow_mutation_enabled\": {},\n", .{ci_workflow_mutation_enabled});
    try output.print(allocator, "  \"ci_upload_execution_enabled\": {},\n", .{ci_upload_execution_enabled});
    try output.print(allocator, "  \"ci_report_publication_enabled\": {},\n", .{ci_report_publication_enabled});
    try output.print(allocator, "  \"github_api_mutation_enabled\": {},\n", .{github_api_mutation_enabled});
    try output.print(allocator, "  \"github_check_run_creation_enabled\": {},\n", .{github_check_run_creation_enabled});
    try output.print(allocator, "  \"branch_protection_mutation_by_tool_enabled\": {},\n", .{branch_protection_mutation_by_tool_enabled});
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
}

fn appendEvidenceJson(allocator: std.mem.Allocator, output: *std.ArrayList(u8), evidence_files: []const SourceEvidenceFile) !void {
    try output.append(allocator, '[');
    for (evidence_files, 0..) |evidence, index| {
        if (index > 0) try output.appendSlice(allocator, ", ");
        try output.appendSlice(allocator, "{ \"path\": ");
        try appendJsonString(allocator, output, evidence.path);
        try output.appendSlice(allocator, ", \"class\": ");
        try appendJsonString(allocator, output, evidence.class);
        try output.print(allocator, ", \"size_bytes\": {d}, \"sha256\": ", .{evidence.size_bytes});
        try appendJsonString(allocator, output, evidence.sha256);
        try output.appendSlice(allocator, ", \"detected_schema\": ");
        try appendJsonString(allocator, output, evidence.detected_schema);
        try output.appendSlice(allocator, ", \"denied_reason\": ");
        try appendJsonString(allocator, output, evidence.denied_reason);
        try output.appendSlice(allocator, " }");
    }
    try output.append(allocator, ']');
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

fn appendFindingsJson(allocator: std.mem.Allocator, output: *std.ArrayList(u8), findings: []const SourceFinding, severity: []const u8) !void {
    try output.append(allocator, '[');
    var emitted: usize = 0;
    for (findings) |finding| {
        if (!std.mem.eql(u8, finding.severity, severity)) continue;
        if (emitted > 0) try output.appendSlice(allocator, ", ");
        emitted += 1;
        try output.appendSlice(allocator, "{ \"id\": ");
        try appendJsonString(allocator, output, finding.id);
        try output.appendSlice(allocator, ", \"severity\": ");
        try appendJsonString(allocator, output, finding.severity);
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

fn appendFindingText(allocator: std.mem.Allocator, output: *std.ArrayList(u8), title: []const u8, findings: []const SourceFinding, severity: []const u8) !void {
    try output.print(allocator, "{s}:\n", .{title});
    var emitted: usize = 0;
    for (findings) |finding| {
        if (!std.mem.eql(u8, finding.severity, severity)) continue;
        emitted += 1;
        try output.print(allocator, "- {s}: {s} - {s}", .{ finding.id, finding.signal, finding.detail });
        if (finding.evidence_path.len > 0) try output.print(allocator, " ({s})", .{finding.evidence_path});
        try output.append(allocator, '\n');
    }
    if (emitted == 0) try output.appendSlice(allocator, "- none\n");
    try output.append(allocator, '\n');
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
    };
}

fn headlineForStatus(status: ReportStatus) []const u8 {
    return switch (status) {
        .ready => "Required-status-check enforcement evaluator evidence is ready for report presentation.",
        .advisory => "Required-status-check enforcement evaluator evidence is reportable with advisory findings.",
        .blocked => "Required-status-check enforcement evaluator evidence is blocked and must not be treated as enforcement readiness.",
    };
}

fn agentGuidance(status: ReportStatus) []const []const u8 {
    return switch (status) {
        .ready => &.{
            "Use this local report artifact as reviewer-facing enforcement evidence.",
            "Do not convert this report into required checks, workflow mutations, branch-protection changes, live telemetry, durable writes, NenDB writes, or mutation authority.",
        },
        .advisory => &.{
            "Surface advisory findings as reviewer guidance only.",
            "Keep missing or overclaimed enforcement evidence non-authoritative unless a later reviewed boundary grants authority.",
        },
        .blocked => &.{
            "Do not present blocked evaluator output as enforcement readiness.",
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
    return "usage: zig build causal-production-telemetry-ci-gate-required-status-check-enforcement-report -- --from-evaluator <required-status-check-enforcement-evaluator.json> summarize --reason <reason> [--by <actor>] [--policy <policy>] [--out-prefix <path-prefix>]\n";
}

fn failUsage(err: anyerror) noreturn {
    std.debug.print("causal-production-telemetry-ci-gate-required-status-check-enforcement-report error: {s}\n{s}", .{ @errorName(err), usage() });
    std.process.exit(2);
}

test "required status check enforcement report constants are stable" {
    try std.testing.expectEqualStrings(
        "zigeffect.causal.production-telemetry-ci-gate-required-status-check-enforcement-report.v1",
        production_telemetry_ci_gate_required_status_check_enforcement_report_schema,
    );
    try std.testing.expectEqual(@as(u32, 1), production_telemetry_ci_gate_required_status_check_enforcement_report_schema_version);
    try std.testing.expectEqualStrings(
        "codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-enforcement-report",
        source_branch,
    );
    try std.testing.expectEqualStrings(
        "start-production-telemetry-ci-gate-required-status-check-enforcement-report-application-boundary",
        recommendation,
    );
    try std.testing.expectEqualStrings(
        "codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-enforcement-report-application-boundary",
        next_branch_if_ready,
    );
}

test "parses required status check enforcement report options" {
    const options = try parseOptions(&.{
        "zigeffect-causal-production-telemetry-ci-gate-required-status-check-enforcement-report",
        "--from-evaluator",
        ".zig-cache/causal-artifacts/example-ci-gate-required-status-check-enforcement-evaluator.json",
        "summarize",
        "--reason",
        "required status check enforcement report reviewed",
        "--by",
        "codex",
        "--policy",
        "manual-production-telemetry-ci-gate-required-status-check-enforcement-report",
        "--out-prefix",
        ".zig-cache/causal-artifacts/custom-required-status-check-enforcement-report",
    });

    try std.testing.expectEqualStrings(".zig-cache/causal-artifacts/example-ci-gate-required-status-check-enforcement-evaluator.json", options.evaluator_path);
    try std.testing.expectEqualStrings("required status check enforcement report reviewed", options.reason);
    try std.testing.expectEqualStrings("codex", options.reviewed_by);
    try std.testing.expectEqualStrings("manual-production-telemetry-ci-gate-required-status-check-enforcement-report", options.policy);
    try std.testing.expectEqualStrings(".zig-cache/causal-artifacts/custom-required-status-check-enforcement-report", options.out_prefix.?);
}

test "required status check enforcement report rejects invalid options" {
    try std.testing.expectError(error.InvalidEvaluatorPath, parseOptions(&.{ "tool", "--from-evaluator", "source.txt", "summarize", "--reason", "reviewed" }));
    try std.testing.expectError(error.UnknownCommand, parseOptions(&.{ "tool", "--from-evaluator", "source.json", "evaluate", "--reason", "reviewed" }));
    try std.testing.expectError(error.MissingReason, parseOptions(&.{ "tool", "--from-evaluator", "source.json", "summarize" }));
}

test "default output path replaces enforcement evaluator suffix" {
    const options = Options{
        .evaluator_path = "../../.zig-cache/causal-artifacts/example-ci-gate-required-status-check-enforcement-evaluator.json",
        .reason = "planned",
    };
    const paths = try outputPathsForOptions(std.testing.allocator, options);
    defer paths.deinit(std.testing.allocator);

    try std.testing.expectEqualStrings("../../.zig-cache/causal-artifacts/example-ci-gate-required-status-check-enforcement-report.json", paths.json_path);
    try std.testing.expectEqualStrings("../../.zig-cache/causal-artifacts/example-ci-gate-required-status-check-enforcement-report.txt", paths.text_path);
}

test "ready evaluator produces ready required status check enforcement report" {
    const reports = try formatReports(std.testing.allocator, .{
        .options = sampleOptions(),
        .source_evaluator_json = sample_ready_evaluator_json,
    });
    defer reports.deinit(std.testing.allocator);

    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"schema\": \"zigeffect.causal.production-telemetry-ci-gate-required-status-check-enforcement-report.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"required_status_check_enforcement_report_status\": \"ready\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"ready_for_next_branch\": true") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"mutation_authority\": \"none\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"next_branch_if_ready\": \"codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-enforcement-report-application-boundary\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.text, "required status check enforcement report status: ready") != null);
}

test "advisory evaluator produces advisory required status check enforcement report" {
    const reports = try formatReports(std.testing.allocator, .{
        .options = sampleOptions(),
        .source_evaluator_json = sample_advisory_evaluator_json,
    });
    defer reports.deinit(std.testing.allocator);

    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"required_status_check_enforcement_report_status\": \"advisory\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"ready_for_next_branch\": true") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"advisory_findings\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"id\": \"active-enforcement-evidence-missing\"") != null);
}

test "blocked evaluator produces blocked report preserving blocked findings" {
    const reports = try formatReports(std.testing.allocator, .{
        .options = sampleOptions(),
        .source_evaluator_json = sample_blocked_evaluator_json,
    });
    defer reports.deinit(std.testing.allocator);

    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"required_status_check_enforcement_report_status\": \"blocked\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"ready_for_next_branch\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"blocked_findings\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"id\": \"source-policy-ready\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.text, "blocked findings:") != null);
}

test "authority enabled in source evaluator blocks report" {
    const reports = try formatReports(std.testing.allocator, .{
        .options = sampleOptions(),
        .source_evaluator_json = sample_authority_violation_evaluator_json,
    });
    defer reports.deinit(std.testing.allocator);

    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"required_status_check_enforcement_report_status\": \"blocked\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"name\": \"source-disabled-authority\"") != null);
}

test "publication channels remain local-only and record-only" {
    const reports = try formatReports(std.testing.allocator, .{
        .options = sampleOptions(),
        .source_evaluator_json = sample_ready_evaluator_json,
    });
    defer reports.deinit(std.testing.allocator);

    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"id\": \"local-json-artifact\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"id\": \"required-status-check\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"id\": \"branch-protection-update\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"executed_by_tool\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.text, "required-status-check: allowed=false, executed_by_tool=false") != null);
}

fn sampleOptions() Options {
    return .{
        .evaluator_path = ".zig-cache/causal-artifacts/example-ci-gate-required-status-check-enforcement-evaluator.json",
        .reason = "required status check enforcement report reviewed",
    };
}

const common_evaluator_tail =
    \\  "ci_gate_enabled": false,
    \\  "ci_gate_enforcement_enabled": false,
    \\  "ci_required_status_check_enabled": false,
    \\  "ci_workflow_mutation_enabled": false,
    \\  "ci_upload_execution_enabled": false,
    \\  "ci_report_publication_enabled": false,
    \\  "github_api_mutation_enabled": false,
    \\  "github_check_run_creation_enabled": false,
    \\  "branch_protection_mutation_by_tool_enabled": false,
    \\  "github_step_summary_write_enabled": false,
    \\  "pull_request_comment_enabled": false,
    \\  "production_telemetry_ingestion": false,
    \\  "live_exporter_enabled": false,
    \\  "network_send_enabled": false,
    \\  "collector_endpoint_configured": false,
    \\  "otlp_serialization_enabled": false,
    \\  "runtime_pipeline_enabled": false,
    \\  "durable_write_enabled": false,
    \\  "nendb_write_enabled": false,
    \\  "mutation_authority": "none",
    \\  "evidence_files": [
    \\    { "path": ".zig-cache/causal-artifacts/policy.json", "class": "source_policy", "size_bytes": 100, "sha256": "sha256:policy", "detected_schema": "zigeffect.causal.production-telemetry-ci-gate-required-status-check-enforcement-policy.v1", "denied_reason": "" },
    \\    { "path": ".zig-cache/release-gate/zigeffect-release-gate.json", "class": "release_gate_json", "size_bytes": 200, "sha256": "sha256:release", "detected_schema": "zigeffect.release-gate.v1", "denied_reason": "" }
    \\  ],
    \\  "checks": [
    \\    { "name": "source-schema", "status": "pass", "detail": "source enforcement policy schema is supported" }
    \\  ],
    \\  "signal_evaluations": [
    \\    { "id": "policy-ready", "status": "observed", "detail": "source policy is ready and verified", "evidence_path": ".zig-cache/causal-artifacts/policy.json" },
    \\    { "id": "active-enforcement-observed", "status": "missing", "detail": "active required-status-check enforcement evidence was not observed", "evidence_path": "" }
    \\  ],
    \\  "blocked_claims": ["github-api-mutated-by-tool", "required-status-check-created-by-tool", "nendb-write-enabled"],
    \\  "required_verification_commands": ["zig build causal-production-telemetry-ci-gate-required-status-check-enforcement-evaluator"],
    \\  "generated_by": "causal-production-telemetry-ci-gate-required-status-check-enforcement-evaluator"
;

const sample_ready_evaluator_json =
    \\{
    \\  "schema": "zigeffect.causal.production-telemetry-ci-gate-required-status-check-enforcement-evaluator.v1",
    \\  "schema_version": 1,
    \\  "source_enforcement_policy": ".zig-cache/causal-artifacts/policy.json",
    \\  "source_policy_status": "ready",
    \\  "source_policy_ready_for_next_branch": true,
    \\  "source_active_enforcement_policy_ready": false,
    \\  "source_merge_blocker_policy_ready": false,
    \\  "required_status_check_enforcement_evaluator_status": "ready",
    \\  "ready_for_next_branch": true,
    \\  "blocked_findings_count": 0,
    \\  "advisory_findings_count": 0,
    \\  "findings": [],
    \\
++ common_evaluator_tail ++
    \\
    \\}
;

const sample_advisory_evaluator_json =
    \\{
    \\  "schema": "zigeffect.causal.production-telemetry-ci-gate-required-status-check-enforcement-evaluator.v1",
    \\  "schema_version": 1,
    \\  "source_enforcement_policy": ".zig-cache/causal-artifacts/policy.json",
    \\  "source_policy_status": "ready",
    \\  "source_policy_ready_for_next_branch": true,
    \\  "source_active_enforcement_policy_ready": true,
    \\  "source_merge_blocker_policy_ready": false,
    \\  "required_status_check_enforcement_evaluator_status": "advisory-findings",
    \\  "ready_for_next_branch": true,
    \\  "blocked_findings_count": 0,
    \\  "advisory_findings_count": 1,
    \\  "findings": [
    \\    { "id": "active-enforcement-evidence-missing", "severity": "advisory", "signal": "active-enforcement-observed", "detail": "source policy allows active enforcement evidence but no active evidence file was observed", "evidence_path": "" }
    \\  ],
    \\
++ common_evaluator_tail ++
    \\
    \\}
;

const sample_blocked_evaluator_json =
    \\{
    \\  "schema": "zigeffect.causal.production-telemetry-ci-gate-required-status-check-enforcement-evaluator.v1",
    \\  "schema_version": 1,
    \\  "source_enforcement_policy": ".zig-cache/causal-artifacts/policy.json",
    \\  "source_policy_status": "blocked",
    \\  "source_policy_ready_for_next_branch": false,
    \\  "source_active_enforcement_policy_ready": false,
    \\  "source_merge_blocker_policy_ready": false,
    \\  "required_status_check_enforcement_evaluator_status": "blocked",
    \\  "ready_for_next_branch": false,
    \\  "blocked_findings_count": 1,
    \\  "advisory_findings_count": 0,
    \\  "findings": [
    \\    { "id": "source-policy-ready", "severity": "blocked", "signal": "policy-ready", "detail": "source enforcement policy is ready for evaluator handoff", "evidence_path": ".zig-cache/causal-artifacts/policy.json" }
    \\  ],
    \\
++ common_evaluator_tail ++
    \\
    \\}
;

const sample_authority_violation_evaluator_json =
    \\{
    \\  "schema": "zigeffect.causal.production-telemetry-ci-gate-required-status-check-enforcement-evaluator.v1",
    \\  "schema_version": 1,
    \\  "source_enforcement_policy": ".zig-cache/causal-artifacts/policy.json",
    \\  "source_policy_status": "ready",
    \\  "source_policy_ready_for_next_branch": true,
    \\  "source_active_enforcement_policy_ready": false,
    \\  "source_merge_blocker_policy_ready": false,
    \\  "required_status_check_enforcement_evaluator_status": "ready",
    \\  "ready_for_next_branch": true,
    \\  "blocked_findings_count": 0,
    \\  "advisory_findings_count": 0,
    \\  "ci_gate_enabled": false,
    \\  "ci_gate_enforcement_enabled": true,
    \\  "ci_required_status_check_enabled": false,
    \\  "ci_workflow_mutation_enabled": false,
    \\  "ci_upload_execution_enabled": false,
    \\  "ci_report_publication_enabled": false,
    \\  "github_api_mutation_enabled": false,
    \\  "github_check_run_creation_enabled": false,
    \\  "branch_protection_mutation_by_tool_enabled": false,
    \\  "github_step_summary_write_enabled": false,
    \\  "pull_request_comment_enabled": false,
    \\  "production_telemetry_ingestion": false,
    \\  "live_exporter_enabled": false,
    \\  "network_send_enabled": false,
    \\  "collector_endpoint_configured": false,
    \\  "otlp_serialization_enabled": false,
    \\  "runtime_pipeline_enabled": false,
    \\  "durable_write_enabled": false,
    \\  "nendb_write_enabled": false,
    \\  "mutation_authority": "none",
    \\  "evidence_files": [
    \\    { "path": ".zig-cache/causal-artifacts/policy.json", "class": "source_policy", "size_bytes": 100, "sha256": "sha256:policy", "detected_schema": "zigeffect.causal.production-telemetry-ci-gate-required-status-check-enforcement-policy.v1", "denied_reason": "" }
    \\  ],
    \\  "checks": [
    \\    { "name": "source-schema", "status": "pass", "detail": "source enforcement policy schema is supported" }
    \\  ],
    \\  "signal_evaluations": [
    \\    { "id": "policy-ready", "status": "observed", "detail": "source policy is ready and verified", "evidence_path": ".zig-cache/causal-artifacts/policy.json" }
    \\  ],
    \\  "findings": [],
    \\  "blocked_claims": ["github-api-mutated-by-tool", "required-status-check-created-by-tool", "nendb-write-enabled"],
    \\  "required_verification_commands": ["zig build causal-production-telemetry-ci-gate-required-status-check-enforcement-evaluator"],
    \\  "generated_by": "causal-production-telemetry-ci-gate-required-status-check-enforcement-evaluator"
    \\}
;
