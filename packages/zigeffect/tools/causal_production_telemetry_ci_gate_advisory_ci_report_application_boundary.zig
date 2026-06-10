const std = @import("std");

pub const production_telemetry_ci_gate_advisory_ci_report_application_boundary_schema = "zigeffect.causal.production-telemetry-ci-gate-advisory-ci-report-application-boundary.v1";
pub const production_telemetry_ci_gate_advisory_ci_report_application_boundary_schema_version: u32 = 1;
pub const source_branch = "codex/zigeffect-causal-production-telemetry-ci-gate-advisory-ci-report-application-boundary";
pub const recommendation = "start-production-telemetry-ci-gate-advisory-ci-report-publication-policy";
pub const next_branch_if_applied = "codex/zigeffect-causal-production-telemetry-ci-gate-advisory-ci-report-publication-policy";

const source_report_schema = "zigeffect.causal.production-telemetry-ci-gate-advisory-ci-report.v1";
const generated_by = "causal-production-telemetry-ci-gate-advisory-ci-report-application-boundary";
const max_source_bytes = 1024 * 1024;
const source_report_suffix = "-ci-gate-advisory-ci-report.json";
const output_prefix_suffix = "-ci-gate-advisory-ci-report-application-boundary";
const compact_output_prefix_name = "production-telemetry-ci-gate-advisory-ci-report-application-boundary";
const max_default_output_file_name_len = 240;

const required_verification_commands: []const []const u8 = &.{
    "zig build causal-production-telemetry-ci-gate-advisory-ci-report",
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

const Mode = enum { plan, record_applied };
const ReportApplicationStatus = enum { planned, applied, blocked };
const CheckStatus = enum { pass, fail, skipped };

const Options = struct {
    report_path: []const u8,
    mode: Mode,
    reviewed_by: []const u8 = "ci-gate-advisory-ci-report-application-boundary-reviewer",
    policy: []const u8 = "manual-production-telemetry-ci-gate-advisory-ci-report-application-boundary",
    reason: []const u8,
    report_after_path: ?[]const u8 = null,
    publication_changes: []const []const u8 = &.{},
    before_evidence: []const []const u8 = &.{},
    after_evidence: []const []const u8 = &.{},
    verified_commands: []const []const u8 = &.{},
    out_prefix: ?[]const u8 = null,

    fn deinit(self: Options, allocator: std.mem.Allocator) void {
        freeSliceOnly(allocator, self.publication_changes);
        freeSliceOnly(allocator, self.before_evidence);
        freeSliceOnly(allocator, self.after_evidence);
        freeSliceOnly(allocator, self.verified_commands);
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

const BoundaryInput = struct {
    options: Options,
    source_report_json: []const u8,
    report_after_text: ?[]const u8 = null,
};

const BoundaryReports = struct {
    json: []const u8,
    text: []const u8,

    fn deinit(self: BoundaryReports, allocator: std.mem.Allocator) void {
        allocator.free(self.json);
        allocator.free(self.text);
    }
};

const SourceCheck = struct {
    name: []const u8 = "",
    status: []const u8,
    detail: []const u8 = "",
};

const SourcePublicationChannel = struct {
    id: []const u8,
    allowed: bool = false,
    executed_by_tool: bool = false,
    detail: []const u8 = "",
};

const SourceReportArtifact = struct {
    schema: []const u8,
    schema_version: u32,
    source_evaluator: []const u8 = "",
    source_evaluation_status: []const u8 = "",
    report_status: []const u8,
    ready_for_next_branch: bool,
    ci_gate_enabled: bool = false,
    ci_gate_enforcement_enabled: bool,
    ci_required_status_check_enabled: bool,
    ci_workflow_mutation_enabled: bool,
    ci_upload_execution_enabled: bool,
    ci_report_publication_enabled: bool,
    github_step_summary_write_enabled: bool,
    pull_request_comment_enabled: bool,
    production_telemetry_ingestion: bool,
    live_exporter_enabled: bool,
    network_send_enabled: bool,
    collector_endpoint_configured: bool,
    otlp_serialization_enabled: bool,
    runtime_pipeline_enabled: bool,
    durable_write_enabled: bool,
    nendb_write_enabled: bool,
    publication_channels: []const SourcePublicationChannel = &.{},
    checks: []const SourceCheck = &.{},
    blocked_claims: []const []const u8 = &.{},
    required_verification_commands: []const []const u8 = &.{},
    generated_by: []const u8 = "",
    source_branch: []const u8 = "",
    recommendation: []const u8 = "",
    next_branch_if_ready: []const u8 = "",
    agent_guidance: []const []const u8 = &.{},
};

const ApplicationCheck = struct {
    name: []const u8,
    status: CheckStatus,
    detail: []const u8,
};

const ApplicationResult = struct {
    status: ReportApplicationStatus,
    applied: bool,
    mutation_authority: []const u8,
    checks: []const ApplicationCheck,

    fn deinit(self: ApplicationResult, allocator: std.mem.Allocator) void {
        if (self.checks.len > 0) allocator.free(self.checks);
    }
};

const NegativeFixture = struct {
    id: []const u8,
    artifact_state: []const u8,
    decision: []const u8,
    failed_gate: []const u8,
    reason: []const u8,
};

const required_report_markers: []const []const u8 = &.{ "zigeffect", "causal", "advisory", "report" };

const prohibited_report_markers: []const []const u8 = &.{
    "required_status_check",
    "ci_gate_enabled=true",
    "ci_gate_enforcement_enabled=true",
    "ci_report_publication_enabled=true",
    "github_step_summary_write_enabled=true",
    "pull_request_comment_enabled=true",
    "ci_upload_execution_enabled=true",
    "production_telemetry_ingestion=true",
    "network_send_enabled=true",
    "durable_write_enabled=true",
    "nendb_write_enabled=true",
    "production_cluster_ready",
    "production_health_proven",
    "mutation_authority=granted",
    "secrets.",
    "PRODUCTION_TELEMETRY_TOKEN",
    "OTEL_EXPORTER_OTLP_ENDPOINT",
};

const application_boundary_rules: []const []const u8 = &.{
    "Plan mode records advisory CI report publication intent only and never records applied state.",
    "record-applied requires reviewed publication-change evidence, before evidence, after evidence, report-after content, report safety, and full verification commands.",
    "Applied records are evidence records only; this tool does not publish CI reports, upload artifacts, write step summaries, post comments, or mutate workflows.",
    "Future publication policy work may interpret externally published advisory CI reports without creating required checks.",
    "CI report evidence supports reviewer and agent triage but not production health, deployment success, customer impact, capacity, or cluster readiness claims.",
};

const denied_publication_claims: []const []const u8 = &.{
    "ci-gate-enforcement-active",
    "required-status-check-active",
    "workflow-mutated-by-tool",
    "artifact-upload-executed-by-tool",
    "github-step-summary-written-by-tool",
    "pull-request-comment-posted-by-tool",
    "live-telemetry-ingested",
    "runtime-pipeline-enabled",
    "durable-production-write-enabled",
    "nendb-write-enabled",
    "production-health-proven",
    "production-cluster-ready",
    "non-nendb-durable-adapter",
    "react-or-alternate-renderer",
    "mutation-authority-granted",
};

const negative_fixtures: []const NegativeFixture = &.{
    .{ .id = "blocked-source-report-denied", .artifact_state = "report_status=blocked", .decision = "deny", .failed_gate = "source-report-status", .reason = "blocked source reports cannot feed application records" },
    .{ .id = "source-publication-enabled-denied", .artifact_state = "github_step_summary_write_enabled=true", .decision = "deny", .failed_gate = "source-publication-disabled", .reason = "source report tool must remain local and non-publishing" },
    .{ .id = "source-authority-enabled-denied", .artifact_state = "ci_gate_enforcement_enabled=true", .decision = "deny", .failed_gate = "source-authority-disabled", .reason = "source report cannot grant enforcement authority" },
    .{ .id = "plan-applied-claim-denied", .artifact_state = "mode=plan applied=true", .decision = "deny", .failed_gate = "plan-is-not-applied", .reason = "plan mode is never applied" },
    .{ .id = "missing-publication-change-denied", .artifact_state = "record-applied publication_changes=[]", .decision = "deny", .failed_gate = "publication-change-present", .reason = "reviewed publication change evidence is required" },
    .{ .id = "missing-before-evidence-denied", .artifact_state = "record-applied before=[]", .decision = "deny", .failed_gate = "before-evidence-present", .reason = "before evidence is required" },
    .{ .id = "missing-after-evidence-denied", .artifact_state = "record-applied after=[]", .decision = "deny", .failed_gate = "after-evidence-present", .reason = "after evidence is required" },
    .{ .id = "missing-report-after-denied", .artifact_state = "record-applied report_after=null", .decision = "deny", .failed_gate = "after-report-present", .reason = "after report content is required" },
    .{ .id = "unsafe-report-after-required-check-denied", .artifact_state = "required_status_check present", .decision = "deny", .failed_gate = "after-report-safe", .reason = "required checks are out of scope" },
    .{ .id = "unsafe-report-after-secrets-denied", .artifact_state = "secrets.* present", .decision = "deny", .failed_gate = "after-report-safe", .reason = "report content must not expose secrets" },
    .{ .id = "missing-post-verification-denied", .artifact_state = "verified commands incomplete", .decision = "deny", .failed_gate = "post-verification-recorded", .reason = "all post-application verification commands are required" },
    .{ .id = "production-health-claim-denied", .artifact_state = "production_health=proven", .decision = "deny", .failed_gate = "ci-not-production", .reason = "CI report evidence is not live production telemetry" },
    .{ .id = "non-nendb-durable-scope-denied", .artifact_state = "durable_adapter=non-nendb", .decision = "deny", .failed_gate = "nendb-only", .reason = "durable direction remains NenDB adapter only" },
    .{ .id = "alternate-renderer-scope-denied", .artifact_state = "renderer=react", .decision = "deny", .failed_gate = "solid-webui", .reason = "workbench direction remains SolidJS inside zig-webui" },
};

pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len == 2 and (std.mem.eql(u8, args[1], "--help") or std.mem.eql(u8, args[1], "-h"))) {
        std.debug.print("{s}", .{usage()});
        return;
    }
    const options = parseOptions(init.gpa, args) catch |err| failUsage(err);
    defer options.deinit(init.gpa);
    run(init, options) catch |err| switch (err) {
        error.MissingReportInput, error.MissingReportAfterInput => failUsage(err),
        else => return err,
    };
}

fn parseOptions(allocator: std.mem.Allocator, args: []const []const u8) !Options {
    if (args.len < 2) return error.MissingReportPath;
    if (!std.mem.eql(u8, args[1], "--from-report")) return error.UnknownFlag;
    if (args.len < 3) return error.MissingReportPath;
    const report_path = args[2];
    if (!std.mem.endsWith(u8, report_path, ".json")) return error.InvalidReportPath;
    if (args.len < 4) return error.MissingMode;
    const mode = try parseMode(args[3]);

    var reviewed_by: []const u8 = "ci-gate-advisory-ci-report-application-boundary-reviewer";
    var policy: []const u8 = "manual-production-telemetry-ci-gate-advisory-ci-report-application-boundary";
    var reason: ?[]const u8 = null;
    var report_after_path: ?[]const u8 = null;
    var publication_changes = std.ArrayList([]const u8).empty;
    var before_evidence = std.ArrayList([]const u8).empty;
    var after_evidence = std.ArrayList([]const u8).empty;
    var verified_commands = std.ArrayList([]const u8).empty;
    var out_prefix: ?[]const u8 = null;
    errdefer publication_changes.deinit(allocator);
    errdefer before_evidence.deinit(allocator);
    errdefer after_evidence.deinit(allocator);
    errdefer verified_commands.deinit(allocator);

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
        } else if (std.mem.eql(u8, flag, "--report-after")) {
            if (!reportAfterPathValid(value)) return error.InvalidReportAfterPath;
            report_after_path = value;
        } else if (std.mem.eql(u8, flag, "--publication-change")) {
            try publication_changes.append(allocator, value);
        } else if (std.mem.eql(u8, flag, "--before")) {
            try before_evidence.append(allocator, value);
        } else if (std.mem.eql(u8, flag, "--after")) {
            try after_evidence.append(allocator, value);
        } else if (std.mem.eql(u8, flag, "--verified-command")) {
            try verified_commands.append(allocator, value);
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
        .report_path = report_path,
        .mode = mode,
        .reviewed_by = reviewed_by,
        .policy = policy,
        .reason = final_reason,
        .report_after_path = report_after_path,
        .publication_changes = try publication_changes.toOwnedSlice(allocator),
        .before_evidence = try before_evidence.toOwnedSlice(allocator),
        .after_evidence = try after_evidence.toOwnedSlice(allocator),
        .verified_commands = try verified_commands.toOwnedSlice(allocator),
        .out_prefix = out_prefix,
    };
}

fn parseMode(value: []const u8) !Mode {
    if (std.mem.eql(u8, value, "plan")) return .plan;
    if (std.mem.eql(u8, value, "record-applied")) return .record_applied;
    return error.UnknownMode;
}

fn reportAfterPathValid(path: []const u8) bool {
    return std.mem.endsWith(u8, path, ".txt") or
        std.mem.endsWith(u8, path, ".md") or
        std.mem.endsWith(u8, path, ".json");
}

fn modeText(mode: Mode) []const u8 {
    return switch (mode) {
        .plan => "plan",
        .record_applied => "record-applied",
    };
}

fn statusText(status: ReportApplicationStatus) []const u8 {
    return switch (status) {
        .planned => "planned",
        .applied => "applied",
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

fn outputPathsForOptions(allocator: std.mem.Allocator, options: Options) !OutputPaths {
    const prefix = if (options.out_prefix) |out_prefix|
        try allocator.dupe(u8, out_prefix)
    else
        try defaultOutputPrefix(allocator, options.report_path);
    defer allocator.free(prefix);

    return .{
        .json_path = try std.fmt.allocPrint(allocator, "{s}.json", .{prefix}),
        .text_path = try std.fmt.allocPrint(allocator, "{s}.txt", .{prefix}),
    };
}

fn defaultOutputPrefix(allocator: std.mem.Allocator, report_path: []const u8) ![]const u8 {
    if (!std.mem.endsWith(u8, report_path, ".json")) return error.InvalidReportPath;

    const base = if (std.mem.endsWith(u8, report_path, source_report_suffix))
        report_path[0 .. report_path.len - source_report_suffix.len]
    else
        report_path[0 .. report_path.len - ".json".len];
    const candidate = try std.fmt.allocPrint(allocator, "{s}{s}", .{ base, output_prefix_suffix });
    errdefer allocator.free(candidate);

    if (fileName(candidate).len + ".json".len <= max_default_output_file_name_len) {
        return candidate;
    }

    const directory = directoryPrefix(candidate);
    const digest = shortPathDigest(report_path);
    const compact_prefix = try std.fmt.allocPrint(allocator, "{s}{s}-{s}", .{ directory, compact_output_prefix_name, digest[0..] });
    allocator.free(candidate);
    return compact_prefix;
}

fn directoryPrefix(path: []const u8) []const u8 {
    const slash = std.mem.lastIndexOfScalar(u8, path, '/') orelse return "";
    return path[0 .. slash + 1];
}

fn fileName(path: []const u8) []const u8 {
    const slash = std.mem.lastIndexOfScalar(u8, path, '/') orelse return path;
    return path[slash + 1 ..];
}

fn shortPathDigest(path: []const u8) [16]u8 {
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(path, &digest, .{});

    var hex_digest: [16]u8 = undefined;
    const hex = "0123456789abcdef";
    for (digest[0..8], 0..) |byte, index| {
        hex_digest[index * 2] = hex[@intCast(byte >> 4)];
        hex_digest[index * 2 + 1] = hex[@intCast(byte & 0x0f)];
    }
    return hex_digest;
}

fn formatReports(allocator: std.mem.Allocator, input: BoundaryInput) !BoundaryReports {
    var parsed = try std.json.parseFromSlice(SourceReportArtifact, allocator, input.source_report_json, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();

    const paths = try outputPathsForOptions(allocator, input.options);
    defer paths.deinit(allocator);

    const after_report_digest = if (input.report_after_text) |report_text|
        try reportDigest(allocator, report_text)
    else
        try allocator.dupe(u8, "");
    defer allocator.free(after_report_digest);

    const result = try evaluateBoundary(allocator, input.options, parsed.value, input.report_after_text);
    defer result.deinit(allocator);

    const json = try formatBoundaryJson(allocator, input.options, parsed.value, input.report_after_text, after_report_digest, result, paths);
    errdefer allocator.free(json);
    const text = try formatBoundaryText(allocator, input.options, parsed.value, after_report_digest, result, paths);
    errdefer allocator.free(text);

    return .{ .json = json, .text = text };
}

fn evaluateBoundary(
    allocator: std.mem.Allocator,
    options: Options,
    source: SourceReportArtifact,
    report_after_text: ?[]const u8,
) !ApplicationResult {
    var checks = std.ArrayList(ApplicationCheck).empty;
    errdefer checks.deinit(allocator);

    try appendCheck(allocator, &checks, "source-report-schema", if (std.mem.eql(u8, source.schema, source_report_schema) and source.schema_version == 1) .pass else .fail, "source advisory CI report schema is supported");
    try appendCheck(allocator, &checks, "source-report-status", if (sourceReportReady(source)) .pass else .fail, "source advisory CI report is ready or advisory and ready for next branch");
    try appendCheck(allocator, &checks, "source-publication-disabled", if (sourcePublicationDisabled(source)) .pass else .fail, "source advisory CI report did not publish externally");
    try appendCheck(allocator, &checks, "source-authority-disabled", if (sourceAuthorityDisabled(source)) .pass else .fail, "source keeps CI enforcement workflow mutation uploads live telemetry runtime durable and NenDB authority disabled");
    try appendCheck(allocator, &checks, "source-publication-channels-carried", if (source.publication_channels.len > 0) .pass else .fail, "source publication channels are carried forward");
    try appendCheck(allocator, &checks, "source-checks-passed", if (sourceChecksPassed(source.checks)) .pass else .fail, "source report checks have no failures");
    try appendCheck(allocator, &checks, "source-blocked-claims-carried", if (source.blocked_claims.len > 0) .pass else .fail, "source blocked claims are carried forward");
    try appendCheck(allocator, &checks, "source-verification-recorded", if (sourceVerificationRecorded(source)) .pass else .fail, "source report records required verification commands");

    if (options.mode == .plan) {
        try appendCheck(allocator, &checks, "plan-is-not-applied", .pass, "plan mode records publication boundary intent without applied state");
        try appendCheck(allocator, &checks, "publication-change-present", .skipped, "plan mode does not claim publication change evidence");
        try appendCheck(allocator, &checks, "before-evidence-present", .skipped, "plan mode does not claim before evidence");
        try appendCheck(allocator, &checks, "after-evidence-present", .skipped, "plan mode does not claim after evidence");
        try appendCheck(allocator, &checks, "post-verification-recorded", .skipped, "plan mode does not claim post-application verification");
        try appendCheck(allocator, &checks, "after-report-present", if (report_after_text == null) .skipped else .pass, "plan mode may include optional after-report evidence");
        try appendCheck(allocator, &checks, "after-report-safe", if (report_after_text) |report_text| reportSafetyStatus(report_text) else .skipped, "optional after-report evidence preserves publication boundary constraints");

        const check_slice = try checks.toOwnedSlice(allocator);
        errdefer allocator.free(check_slice);
        const planned = requiredChecksPassed(check_slice);
        return .{
            .status = if (planned) .planned else .blocked,
            .applied = false,
            .mutation_authority = "none",
            .checks = check_slice,
        };
    }

    try appendCheck(allocator, &checks, "publication-change-present", if (options.publication_changes.len > 0) .pass else .fail, "record-applied requires reviewed publication change evidence");
    try appendCheck(allocator, &checks, "before-evidence-present", if (options.before_evidence.len > 0) .pass else .fail, "record-applied requires before evidence");
    try appendCheck(allocator, &checks, "after-evidence-present", if (options.after_evidence.len > 0) .pass else .fail, "record-applied requires after evidence");
    try appendCheck(allocator, &checks, "post-verification-recorded", if (verifiedCommandsContainAll(options.verified_commands, required_verification_commands)) .pass else .fail, "record-applied requires every post-application verification command");
    try appendCheck(allocator, &checks, "after-report-present", if (report_after_text != null) .pass else .fail, "record-applied requires after-report content");
    try appendCheck(allocator, &checks, "after-report-safe", if (report_after_text) |report_text| reportSafetyStatus(report_text) else .fail, "after-report evidence preserves publication boundary constraints");

    const check_slice = try checks.toOwnedSlice(allocator);
    errdefer allocator.free(check_slice);
    const applied = allChecksPassed(check_slice);
    return .{
        .status = if (applied) .applied else .blocked,
        .applied = applied,
        .mutation_authority = if (applied) "record-only" else "none",
        .checks = check_slice,
    };
}

fn appendCheck(
    allocator: std.mem.Allocator,
    checks: *std.ArrayList(ApplicationCheck),
    name: []const u8,
    status: CheckStatus,
    detail: []const u8,
) !void {
    try checks.append(allocator, .{ .name = name, .status = status, .detail = detail });
}

fn requiredChecksPassed(checks: []const ApplicationCheck) bool {
    for (checks) |check| {
        if (check.status == .fail) return false;
    }
    return true;
}

fn allChecksPassed(checks: []const ApplicationCheck) bool {
    for (checks) |check| {
        if (check.status != .pass) return false;
    }
    return true;
}

fn sourceReportReady(source: SourceReportArtifact) bool {
    return source.ready_for_next_branch and
        (std.mem.eql(u8, source.report_status, "ready") or std.mem.eql(u8, source.report_status, "advisory"));
}

fn sourceAuthorityDisabled(source: SourceReportArtifact) bool {
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

fn sourcePublicationDisabled(source: SourceReportArtifact) bool {
    if (source.ci_report_publication_enabled or
        source.github_step_summary_write_enabled or
        source.pull_request_comment_enabled or
        source.ci_upload_execution_enabled or
        source.ci_workflow_mutation_enabled)
    {
        return false;
    }

    if (source.publication_channels.len == 0) return false;
    for (source.publication_channels) |channel| {
        if (externalPublicationChannel(channel.id) and (channel.allowed or channel.executed_by_tool)) return false;
    }
    return true;
}

fn externalPublicationChannel(id: []const u8) bool {
    return std.mem.eql(u8, id, "ci-upload-artifact") or
        std.mem.eql(u8, id, "github-step-summary") or
        std.mem.eql(u8, id, "pull-request-comment");
}

fn sourceChecksPassed(checks: []const SourceCheck) bool {
    if (checks.len == 0) return false;
    for (checks) |check| {
        if (std.mem.eql(u8, check.status, "fail")) return false;
    }
    return true;
}

fn sourceVerificationRecorded(source: SourceReportArtifact) bool {
    return source.required_verification_commands.len > 0 and
        containsString(source.required_verification_commands, "zig build causal-production-telemetry-ci-gate-dry-run-evaluator") and
        containsString(source.required_verification_commands, "zig build release-gate-report") and
        containsString(source.required_verification_commands, "zig build causal-production-hardening-backlog -- --format json");
}

fn reportSafetyStatus(report_text: []const u8) CheckStatus {
    for (required_report_markers) |marker| {
        if (!contains(report_text, marker)) return .fail;
    }
    for (prohibited_report_markers) |marker| {
        if (contains(report_text, marker)) return .fail;
    }
    return .pass;
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

fn formatBoundaryJson(
    allocator: std.mem.Allocator,
    options: Options,
    source: SourceReportArtifact,
    report_after_text: ?[]const u8,
    after_report_digest: []const u8,
    result: ApplicationResult,
    paths: OutputPaths,
) ![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "{\n");
    try appendJsonField(allocator, &output, "schema", production_telemetry_ci_gate_advisory_ci_report_application_boundary_schema, true);
    try output.appendSlice(allocator, "  \"schema_version\": 1,\n");
    try appendJsonField(allocator, &output, "source_advisory_ci_report", options.report_path, true);
    try appendJsonField(allocator, &output, "source_report_status", source.report_status, true);
    try appendJsonField(allocator, &output, "mode", modeText(options.mode), true);
    try appendJsonField(allocator, &output, "report_application_status", statusText(result.status), true);
    try output.print(allocator, "  \"applied\": {},\n", .{result.applied});
    try appendJsonField(allocator, &output, "mutation_authority", result.mutation_authority, true);
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
    try output.appendSlice(allocator, "  \"report_after_path\": ");
    try appendOptionalJsonString(allocator, &output, options.report_after_path);
    try output.appendSlice(allocator, ",\n");
    try appendJsonField(allocator, &output, "after_report_digest", after_report_digest, true);
    try output.print(allocator, "  \"after_report_present\": {},\n", .{report_after_text != null});
    try output.appendSlice(allocator, "  \"publication_changes\": ");
    try appendStringArray(allocator, &output, options.publication_changes);
    try output.appendSlice(allocator, ",\n  \"before_evidence\": ");
    try appendStringArray(allocator, &output, options.before_evidence);
    try output.appendSlice(allocator, ",\n  \"after_evidence\": ");
    try appendStringArray(allocator, &output, options.after_evidence);
    try output.appendSlice(allocator, ",\n  \"source_checks\": ");
    try appendSourceChecksJson(allocator, &output, source.checks);
    try output.appendSlice(allocator, ",\n  \"application_checks\": ");
    try appendApplicationChecksJson(allocator, &output, result.checks);
    try output.appendSlice(allocator, ",\n  \"application_boundary_rules\": ");
    try appendStringArray(allocator, &output, application_boundary_rules);
    try output.appendSlice(allocator, ",\n  \"denied_publication_claims\": ");
    try appendStringArray(allocator, &output, denied_publication_claims);
    try output.appendSlice(allocator, ",\n  \"negative_fixtures\": ");
    try appendNegativeFixturesJson(allocator, &output);
    try output.appendSlice(allocator, ",\n  \"blocked_claims\": ");
    try appendStringArray(allocator, &output, blockedClaims(source));
    try output.appendSlice(allocator, ",\n  \"required_verification_commands\": ");
    try appendStringArray(allocator, &output, required_verification_commands);
    try output.appendSlice(allocator, ",\n  \"verified_commands\": ");
    try appendStringArray(allocator, &output, options.verified_commands);
    try appendJsonFieldPrefixComma(allocator, &output, "generated_by", generated_by);
    try appendJsonFieldPrefixComma(allocator, &output, "source_branch", source_branch);
    try appendJsonFieldPrefixComma(allocator, &output, "recommendation", recommendation);
    try appendJsonFieldPrefixComma(allocator, &output, "next_branch_if_applied", next_branch_if_applied);
    try appendJsonFieldPrefixComma(allocator, &output, "json_output", paths.json_path);
    try appendJsonFieldPrefixComma(allocator, &output, "text_output", paths.text_path);
    try output.appendSlice(allocator, ",\n  \"agent_guidance\": ");
    try appendStringArray(allocator, &output, agentGuidance(result.status));
    try output.appendSlice(allocator, "\n}\n");

    return output.toOwnedSlice(allocator);
}

fn formatBoundaryText(
    allocator: std.mem.Allocator,
    options: Options,
    source: SourceReportArtifact,
    after_report_digest: []const u8,
    result: ApplicationResult,
    paths: OutputPaths,
) ![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "zigeffect production telemetry CI gate advisory CI report application boundary\n");
    try output.print(allocator, "schema: {s}\n", .{production_telemetry_ci_gate_advisory_ci_report_application_boundary_schema});
    try output.print(allocator, "source advisory CI report: {s}\n", .{options.report_path});
    try output.print(allocator, "source report status: {s}\n", .{source.report_status});
    try output.print(allocator, "after report digest: {s}\n", .{after_report_digest});
    try output.print(allocator, "mode: {s}\n", .{modeText(options.mode)});
    try output.print(allocator, "report_application_status: {s}\n", .{statusText(result.status)});
    try output.print(allocator, "applied: {}\n", .{result.applied});
    try output.print(allocator, "mutation_authority: {s}\n", .{result.mutation_authority});
    try output.print(allocator, "ci report publication enabled: {}\n", .{ci_report_publication_enabled});
    try output.print(allocator, "github step summary write enabled: {}\n", .{github_step_summary_write_enabled});
    try output.print(allocator, "pull request comment enabled: {}\n", .{pull_request_comment_enabled});
    try output.print(allocator, "ci upload execution enabled: {}\n", .{ci_upload_execution_enabled});
    try output.print(allocator, "reviewed_by: {s}\n", .{options.reviewed_by});
    try output.print(allocator, "policy: {s}\n", .{options.policy});
    try output.print(allocator, "reason: {s}\n", .{options.reason});
    try output.print(allocator, "source branch: {s}\n", .{source_branch});
    try output.print(allocator, "recommendation: {s}\n", .{recommendation});
    try output.print(allocator, "next branch if applied: {s}\n", .{next_branch_if_applied});
    try output.print(allocator, "json output: {s}\n", .{paths.json_path});
    try output.print(allocator, "text output: {s}\n\n", .{paths.text_path});

    try output.appendSlice(allocator, "checks:\n");
    for (result.checks) |check| {
        try output.print(allocator, "- {s}: {s} - {s}\n", .{ check.name, checkStatusText(check.status), check.detail });
    }
    try output.append(allocator, '\n');

    try appendTextList(allocator, &output, "publication changes", options.publication_changes);
    try appendTextList(allocator, &output, "before evidence", options.before_evidence);
    try appendTextList(allocator, &output, "after evidence", options.after_evidence);
    try appendTextList(allocator, &output, "application boundary rules", application_boundary_rules);
    try appendTextList(allocator, &output, "denied publication claims", denied_publication_claims);
    try appendNegativeFixturesText(allocator, &output);
    try appendTextList(allocator, &output, "blocked claims", blockedClaims(source));
    try appendTextList(allocator, &output, "required verification commands", required_verification_commands);
    try appendTextList(allocator, &output, "verified commands", options.verified_commands);
    try appendTextList(allocator, &output, "agent guidance", agentGuidance(result.status));

    return output.toOwnedSlice(allocator);
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

fn appendSourceChecksJson(allocator: std.mem.Allocator, output: *std.ArrayList(u8), checks: []const SourceCheck) !void {
    try output.append(allocator, '[');
    for (checks, 0..) |check, index| {
        if (index > 0) try output.appendSlice(allocator, ", ");
        try output.appendSlice(allocator, "{ \"name\": ");
        try appendJsonString(allocator, output, check.name);
        try output.appendSlice(allocator, ", \"status\": ");
        try appendJsonString(allocator, output, check.status);
        try output.appendSlice(allocator, ", \"detail\": ");
        try appendJsonString(allocator, output, check.detail);
        try output.appendSlice(allocator, " }");
    }
    try output.append(allocator, ']');
}

fn appendApplicationChecksJson(allocator: std.mem.Allocator, output: *std.ArrayList(u8), checks: []const ApplicationCheck) !void {
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

fn appendNegativeFixturesJson(allocator: std.mem.Allocator, output: *std.ArrayList(u8)) !void {
    try output.append(allocator, '[');
    for (negative_fixtures, 0..) |fixture, index| {
        if (index > 0) try output.appendSlice(allocator, ", ");
        try output.appendSlice(allocator, "{ \"id\": ");
        try appendJsonString(allocator, output, fixture.id);
        try output.appendSlice(allocator, ", \"artifact_state\": ");
        try appendJsonString(allocator, output, fixture.artifact_state);
        try output.appendSlice(allocator, ", \"decision\": ");
        try appendJsonString(allocator, output, fixture.decision);
        try output.appendSlice(allocator, ", \"failed_gate\": ");
        try appendJsonString(allocator, output, fixture.failed_gate);
        try output.appendSlice(allocator, ", \"reason\": ");
        try appendJsonString(allocator, output, fixture.reason);
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

fn appendOptionalJsonString(allocator: std.mem.Allocator, output: *std.ArrayList(u8), value: ?[]const u8) !void {
    if (value) |text| {
        try appendJsonString(allocator, output, text);
    } else {
        try output.appendSlice(allocator, "null");
    }
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

fn appendNegativeFixturesText(allocator: std.mem.Allocator, output: *std.ArrayList(u8)) !void {
    try output.appendSlice(allocator, "negative fixtures:\n");
    for (negative_fixtures) |fixture| {
        try output.print(allocator, "- {s}\n", .{fixture.id});
    }
    try output.append(allocator, '\n');
}

fn reportDigest(allocator: std.mem.Allocator, report_text: []const u8) ![]const u8 {
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(report_text, &digest, .{});

    var hex_digest: [64]u8 = undefined;
    const hex = "0123456789abcdef";
    for (digest, 0..) |byte, index| {
        hex_digest[index * 2] = hex[@intCast(byte >> 4)];
        hex_digest[index * 2 + 1] = hex[@intCast(byte & 0x0f)];
    }
    return std.fmt.allocPrint(allocator, "sha256:{s}", .{hex_digest[0..]});
}

fn contains(haystack: []const u8, needle: []const u8) bool {
    return std.mem.indexOf(u8, haystack, needle) != null;
}

fn containsString(values: []const []const u8, needle: []const u8) bool {
    for (values) |value| {
        if (std.mem.eql(u8, value, needle)) return true;
    }
    return false;
}

fn containsSubstring(values: []const []const u8, needle: []const u8) bool {
    for (values) |value| {
        if (std.mem.indexOf(u8, value, needle) != null) return true;
    }
    return false;
}

fn blockedClaims(source: SourceReportArtifact) []const []const u8 {
    if (source.blocked_claims.len > 0) return source.blocked_claims;
    return denied_publication_claims;
}

fn agentGuidance(status: ReportApplicationStatus) []const []const u8 {
    return switch (status) {
        .planned => &.{
            "Use planned advisory CI report application boundary evidence to prepare publication policy only.",
            "Do not claim applied publication step summaries PR comments uploads required checks or CI gate enforcement from plan mode.",
        },
        .applied => &.{
            "Use applied advisory CI report application boundary evidence to start publication policy work only.",
            "Cite publication changes before evidence after evidence report-after digest post-verification commands and source advisory report.",
        },
        .blocked => &.{
            "Treat blocked advisory CI report application boundary evidence as a stop sign.",
            "Repair source report publication evidence before/after evidence report-after safety or verification proof before continuing.",
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
    const source_report_json = try readRequiredArtifact(init.io, allocator, options.report_path, error.MissingReportInput);
    defer allocator.free(source_report_json);
    const report_after_text = if (options.report_after_path) |path|
        try readRequiredArtifact(init.io, allocator, path, error.MissingReportAfterInput)
    else
        null;
    defer if (report_after_text) |contents| allocator.free(contents);

    const reports = try formatReports(allocator, .{
        .options = options,
        .source_report_json = source_report_json,
        .report_after_text = report_after_text,
    });
    defer reports.deinit(allocator);

    const paths = try outputPathsForOptions(allocator, options);
    defer paths.deinit(allocator);

    try writeArtifact(init.io, paths.json_path, reports.json);
    try writeArtifact(init.io, paths.text_path, reports.text);
    std.debug.print("{s}", .{reports.text});
}

fn usage() []const u8 {
    return "usage: zig build causal-production-telemetry-ci-gate-advisory-ci-report-application-boundary -- --from-report <advisory-ci-report.json> plan|record-applied --reason <reason> [--report-after <report.txt|report.md|report.json>] [--by <actor>] [--policy <policy>] [--publication-change <evidence>] [--before <evidence>] [--after <evidence>] [--verified-command <command>]... [--out-prefix <path-prefix>]\n";
}

fn failUsage(err: anyerror) noreturn {
    std.debug.print("causal-production-telemetry-ci-gate-advisory-ci-report-application-boundary error: {s}\n{s}", .{ @errorName(err), usage() });
    std.process.exit(2);
}

fn freeSliceOnly(allocator: std.mem.Allocator, values: []const []const u8) void {
    if (values.len > 0) allocator.free(values);
}

const ready_source_report_json =
    \\{
    \\  "schema": "zigeffect.causal.production-telemetry-ci-gate-advisory-ci-report.v1",
    \\  "schema_version": 1,
    \\  "source_evaluator": ".zig-cache/causal-artifacts/evaluator.json",
    \\  "source_evaluation_status": "advisory-findings",
    \\  "report_status": "advisory",
    \\  "ready_for_next_branch": true,
    \\  "ci_gate_enabled": false,
    \\  "ci_gate_enforcement_enabled": false,
    \\  "ci_required_status_check_enabled": false,
    \\  "ci_workflow_mutation_enabled": false,
    \\  "ci_upload_execution_enabled": false,
    \\  "ci_report_publication_enabled": false,
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
    \\  "publication_channels": [
    \\    { "id": "local-json-artifact", "allowed": true, "executed_by_tool": true, "detail": "local only" },
    \\    { "id": "local-text-artifact", "allowed": true, "executed_by_tool": true, "detail": "local only" },
    \\    { "id": "ci-upload-artifact", "allowed": false, "executed_by_tool": false, "detail": "proposed only" },
    \\    { "id": "github-step-summary", "allowed": false, "executed_by_tool": false, "detail": "proposed only" },
    \\    { "id": "pull-request-comment", "allowed": false, "executed_by_tool": false, "detail": "proposed only" }
    \\  ],
    \\  "checks": [
    \\    { "name": "source-evaluator-schema", "status": "pass", "detail": "supported" },
    \\    { "name": "report-publication-record-only", "status": "pass", "detail": "record only" }
    \\  ],
    \\  "blocked_claims": ["required-status-check-active", "workflow-mutated-by-tool"],
    \\  "required_verification_commands": [
    \\    "zig build causal-production-telemetry-ci-gate-dry-run-evaluator",
    \\    "zig build release-gate-report",
    \\    "zig build causal-production-hardening-backlog -- --format json"
    \\  ],
    \\  "generated_by": "causal-production-telemetry-ci-gate-advisory-ci-report",
    \\  "agent_guidance": ["Surface advisory findings as reviewer guidance only."]
    \\}
;

const blocked_source_report_json =
    \\{
    \\  "schema": "zigeffect.causal.production-telemetry-ci-gate-advisory-ci-report.v1",
    \\  "schema_version": 1,
    \\  "report_status": "blocked",
    \\  "ready_for_next_branch": false,
    \\  "ci_gate_enabled": false,
    \\  "ci_gate_enforcement_enabled": false,
    \\  "ci_required_status_check_enabled": false,
    \\  "ci_workflow_mutation_enabled": false,
    \\  "ci_upload_execution_enabled": false,
    \\  "ci_report_publication_enabled": false,
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
    \\  "publication_channels": [
    \\    { "id": "ci-upload-artifact", "allowed": false, "executed_by_tool": false, "detail": "proposed only" }
    \\  ],
    \\  "checks": [
    \\    { "name": "source-evaluator-reportable", "status": "fail", "detail": "blocked" }
    \\  ],
    \\  "blocked_claims": ["required-status-check-active"],
    \\  "required_verification_commands": [
    \\    "zig build causal-production-telemetry-ci-gate-dry-run-evaluator",
    \\    "zig build release-gate-report",
    \\    "zig build causal-production-hardening-backlog -- --format json"
    \\  ],
    \\  "agent_guidance": ["Repair evaluator source evidence."]
    \\}
;

const publication_enabled_source_report_json =
    \\{
    \\  "schema": "zigeffect.causal.production-telemetry-ci-gate-advisory-ci-report.v1",
    \\  "schema_version": 1,
    \\  "report_status": "advisory",
    \\  "ready_for_next_branch": true,
    \\  "ci_gate_enabled": false,
    \\  "ci_gate_enforcement_enabled": false,
    \\  "ci_required_status_check_enabled": false,
    \\  "ci_workflow_mutation_enabled": false,
    \\  "ci_upload_execution_enabled": false,
    \\  "ci_report_publication_enabled": false,
    \\  "github_step_summary_write_enabled": true,
    \\  "pull_request_comment_enabled": false,
    \\  "production_telemetry_ingestion": false,
    \\  "live_exporter_enabled": false,
    \\  "network_send_enabled": false,
    \\  "collector_endpoint_configured": false,
    \\  "otlp_serialization_enabled": false,
    \\  "runtime_pipeline_enabled": false,
    \\  "durable_write_enabled": false,
    \\  "nendb_write_enabled": false,
    \\  "publication_channels": [
    \\    { "id": "github-step-summary", "allowed": true, "executed_by_tool": true, "detail": "unsafe" }
    \\  ],
    \\  "checks": [
    \\    { "name": "source-evaluator-schema", "status": "pass", "detail": "supported" }
    \\  ],
    \\  "blocked_claims": ["github-step-summary-written-by-tool"],
    \\  "required_verification_commands": [
    \\    "zig build causal-production-telemetry-ci-gate-dry-run-evaluator",
    \\    "zig build release-gate-report",
    \\    "zig build causal-production-hardening-backlog -- --format json"
    \\  ],
    \\  "agent_guidance": ["Unsafe publication."]
    \\}
;

const safe_after_report_text = "zigeffect causal advisory report local publication evidence only";
const unsafe_after_report_text = "zigeffect causal advisory report required_status_check enabled";

test "ci gate advisory CI report application boundary schema and branch constants are stable" {
    try std.testing.expectEqualStrings("zigeffect.causal.production-telemetry-ci-gate-advisory-ci-report-application-boundary.v1", production_telemetry_ci_gate_advisory_ci_report_application_boundary_schema);
    try std.testing.expectEqual(@as(u32, 1), production_telemetry_ci_gate_advisory_ci_report_application_boundary_schema_version);
    try std.testing.expectEqualStrings("codex/zigeffect-causal-production-telemetry-ci-gate-advisory-ci-report-application-boundary", source_branch);
    try std.testing.expectEqualStrings("start-production-telemetry-ci-gate-advisory-ci-report-publication-policy", recommendation);
    try std.testing.expectEqualStrings("codex/zigeffect-causal-production-telemetry-ci-gate-advisory-ci-report-publication-policy", next_branch_if_applied);
    try std.testing.expect(containsString(required_verification_commands, "zig build causal-production-telemetry-ci-gate-advisory-ci-report"));
    try std.testing.expect(containsString(required_verification_commands, "zig build release-gate-report"));
}

test "parses advisory CI report application boundary plan and record-applied options" {
    var plan_options = try parseOptions(std.testing.allocator, &.{
        "zigeffect-causal-production-telemetry-ci-gate-advisory-ci-report-application-boundary",
        "--from-report",
        ".zig-cache/causal-artifacts/report.json",
        "plan",
        "--reason",
        "CI advisory report application boundary planned",
    });
    defer plan_options.deinit(std.testing.allocator);
    try std.testing.expectEqual(Mode.plan, plan_options.mode);
    try std.testing.expectEqualStrings("ci-gate-advisory-ci-report-application-boundary-reviewer", plan_options.reviewed_by);
    try std.testing.expectEqualStrings("manual-production-telemetry-ci-gate-advisory-ci-report-application-boundary", plan_options.policy);

    var applied_options = try parseOptions(std.testing.allocator, &.{
        "zigeffect-causal-production-telemetry-ci-gate-advisory-ci-report-application-boundary",
        "--from-report",
        ".zig-cache/causal-artifacts/report.json",
        "record-applied",
        "--reason",
        "reviewed",
        "--by",
        "reviewer",
        "--policy",
        "policy",
        "--report-after",
        ".zig-cache/causal-artifacts/report-after.txt",
        "--publication-change",
        "publication reviewed",
        "--before",
        "before report evidence",
        "--after",
        "after report evidence",
        "--verified-command",
        "zig build test",
        "--out-prefix",
        ".zig-cache/causal-artifacts/out",
    });
    defer applied_options.deinit(std.testing.allocator);
    try std.testing.expectEqual(Mode.record_applied, applied_options.mode);
    try std.testing.expectEqualStrings("reviewer", applied_options.reviewed_by);
    try std.testing.expectEqualStrings("policy", applied_options.policy);
    try std.testing.expectEqualStrings(".zig-cache/causal-artifacts/report-after.txt", applied_options.report_after_path.?);
    try std.testing.expectEqual(@as(usize, 1), applied_options.publication_changes.len);
    try std.testing.expectEqual(@as(usize, 1), applied_options.before_evidence.len);
    try std.testing.expectEqual(@as(usize, 1), applied_options.after_evidence.len);
    try std.testing.expectEqual(@as(usize, 1), applied_options.verified_commands.len);
    try std.testing.expectEqualStrings(".zig-cache/causal-artifacts/out", applied_options.out_prefix.?);

    try std.testing.expectError(error.UnknownMode, parseOptions(std.testing.allocator, &.{ "tool", "--from-report", ".zig-cache/report.json", "apply", "--reason", "bad" }));
    try std.testing.expectError(error.InvalidReportAfterPath, parseOptions(std.testing.allocator, &.{ "tool", "--from-report", ".zig-cache/report.json", "plan", "--reason", "bad", "--report-after", ".github/workflow.yml" }));
}

test "default output path replaces advisory CI report suffix" {
    const options: Options = .{
        .report_path = ".zig-cache/causal-artifacts/example-ci-gate-advisory-ci-report.json",
        .mode = .plan,
        .reason = "planned",
    };
    const paths = try outputPathsForOptions(std.testing.allocator, options);
    defer paths.deinit(std.testing.allocator);
    try std.testing.expectEqualStrings(".zig-cache/causal-artifacts/example-ci-gate-advisory-ci-report-application-boundary.json", paths.json_path);
    try std.testing.expectEqualStrings(".zig-cache/causal-artifacts/example-ci-gate-advisory-ci-report-application-boundary.txt", paths.text_path);
}

test "long default output path stays within filesystem-safe basename length" {
    const options: Options = .{
        .report_path = "../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures-nendb-retention-fixtures-workbench-readonly-preview-ci-artifact-preview-ci-harness-boundary-ci-gate-advisory-ci-report.json",
        .mode = .plan,
        .reason = "planned",
    };
    const paths = try outputPathsForOptions(std.testing.allocator, options);
    defer paths.deinit(std.testing.allocator);

    const slash = std.mem.lastIndexOfScalar(u8, paths.json_path, '/') orelse 0;
    const file_name = paths.json_path[slash + 1 ..];
    try std.testing.expect(file_name.len <= 240);
    try std.testing.expect(contains(paths.json_path, "production-telemetry-ci-gate-advisory-ci-report-application-boundary-"));
}

test "ready advisory report source produces planned application boundary" {
    const options: Options = .{
        .report_path = ".zig-cache/causal-artifacts/source-ci-gate-advisory-ci-report.json",
        .mode = .plan,
        .reason = "planned",
    };
    const reports = try formatReports(std.testing.allocator, .{ .options = options, .source_report_json = ready_source_report_json });
    defer reports.deinit(std.testing.allocator);
    try std.testing.expect(contains(reports.json, "\"report_application_status\": \"planned\""));
    try std.testing.expect(contains(reports.json, "\"applied\": false"));
    try std.testing.expect(contains(reports.text, "mutation_authority: none"));
}

test "blocked advisory report source produces blocked application boundary" {
    const options: Options = .{
        .report_path = ".zig-cache/causal-artifacts/source-ci-gate-advisory-ci-report.json",
        .mode = .plan,
        .reason = "planned",
    };
    const reports = try formatReports(std.testing.allocator, .{ .options = options, .source_report_json = blocked_source_report_json });
    defer reports.deinit(std.testing.allocator);
    try std.testing.expect(contains(reports.json, "\"report_application_status\": \"blocked\""));
    try std.testing.expect(contains(reports.json, "\"applied\": false"));
    try std.testing.expect(contains(reports.json, "\"source-report-status\", \"status\": \"fail\""));
}

test "enabled source publication authority blocks boundary" {
    const options: Options = .{
        .report_path = ".zig-cache/causal-artifacts/source-ci-gate-advisory-ci-report.json",
        .mode = .plan,
        .reason = "planned",
    };
    const reports = try formatReports(std.testing.allocator, .{ .options = options, .source_report_json = publication_enabled_source_report_json });
    defer reports.deinit(std.testing.allocator);
    try std.testing.expect(contains(reports.json, "\"report_application_status\": \"blocked\""));
    try std.testing.expect(contains(reports.json, "\"source-publication-disabled\", \"status\": \"fail\""));
}

test "record-applied missing evidence stays blocked" {
    const options: Options = .{
        .report_path = ".zig-cache/causal-artifacts/source-ci-gate-advisory-ci-report.json",
        .mode = .record_applied,
        .reason = "applied",
    };
    const reports = try formatReports(std.testing.allocator, .{ .options = options, .source_report_json = ready_source_report_json });
    defer reports.deinit(std.testing.allocator);
    try std.testing.expect(contains(reports.json, "\"report_application_status\": \"blocked\""));
    try std.testing.expect(contains(reports.json, "\"publication-change-present\", \"status\": \"fail\""));
    try std.testing.expect(contains(reports.json, "\"after-report-present\", \"status\": \"fail\""));
}

test "record-applied complete evidence produces applied boundary" {
    const options: Options = .{
        .report_path = ".zig-cache/causal-artifacts/source-ci-gate-advisory-ci-report.json",
        .mode = .record_applied,
        .reason = "applied",
        .report_after_path = ".zig-cache/causal-artifacts/after-report.txt",
        .publication_changes = &.{"reviewed local advisory CI report publication procedure"},
        .before_evidence = &.{"before local artifact evidence"},
        .after_evidence = &.{"after local artifact evidence"},
        .verified_commands = required_verification_commands,
    };
    const reports = try formatReports(std.testing.allocator, .{
        .options = options,
        .source_report_json = ready_source_report_json,
        .report_after_text = safe_after_report_text,
    });
    defer reports.deinit(std.testing.allocator);
    try std.testing.expect(contains(reports.json, "\"report_application_status\": \"applied\""));
    try std.testing.expect(contains(reports.json, "\"applied\": true"));
    try std.testing.expect(contains(reports.text, "mutation_authority: record-only"));
}

test "unsafe after report content blocks applied boundary" {
    const options: Options = .{
        .report_path = ".zig-cache/causal-artifacts/source-ci-gate-advisory-ci-report.json",
        .mode = .record_applied,
        .reason = "applied",
        .report_after_path = ".zig-cache/causal-artifacts/after-report.txt",
        .publication_changes = &.{"reviewed local advisory CI report publication procedure"},
        .before_evidence = &.{"before local artifact evidence"},
        .after_evidence = &.{"after local artifact evidence"},
        .verified_commands = required_verification_commands,
    };
    const reports = try formatReports(std.testing.allocator, .{
        .options = options,
        .source_report_json = ready_source_report_json,
        .report_after_text = unsafe_after_report_text,
    });
    defer reports.deinit(std.testing.allocator);
    try std.testing.expect(contains(reports.json, "\"report_application_status\": \"blocked\""));
    try std.testing.expect(contains(reports.json, "\"after-report-safe\", \"status\": \"fail\""));
}
