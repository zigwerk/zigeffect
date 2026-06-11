const std = @import("std");

pub const production_hardening_backlog_refresh_schema = "zigeffect.causal.production-hardening-backlog-refresh.v1";
pub const production_hardening_backlog_refresh_schema_version: u32 = 1;
pub const source_backlog_schema = "zigeffect.causal.production-hardening-backlog.v1";
pub const source_branch = "codex/zigeffect-causal-production-hardening-backlog-refresh";
pub const recommendation = "start-nendb-durable-history-hardening";
pub const next_branch_if_ready = "codex/zigeffect-causal-nendb-durable-history-hardening";

const generated_by = "causal-production-hardening-backlog-refresh";
const terminal_item_id = "production-telemetry-ci-gate-required-status-check-enforcement-report-policy";
const terminal_build_command = "zig build causal-production-telemetry-ci-gate-required-status-check-enforcement-report-policy";
const source_transition_recommendation = "refresh-production-hardening-backlog";
const source_transition_branch = "codex/zigeffect-causal-production-hardening-backlog-refresh";
const default_output_prefix = "../../.zig-cache/causal-artifacts/production-hardening-backlog-refresh";
const max_source_bytes = 1024 * 1024;

const github_api_mutation_enabled = false;
const github_check_run_creation_enabled = false;
const branch_protection_mutation_by_tool_enabled = false;
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
const cockroach_adapter_enabled = false;
const mutation_authority = "none";

const RefreshStatus = enum { ready, blocked };
const CheckStatus = enum { pass, fail };

const Options = struct {
    backlog_path: []const u8,
    reason: []const u8,
    verified_commands: []const []const u8 = &.{},
    out_prefix: ?[]const u8 = null,

    fn deinit(self: Options, allocator: std.mem.Allocator) void {
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

const RefreshReports = struct {
    json: []const u8,
    text: []const u8,

    fn deinit(self: RefreshReports, allocator: std.mem.Allocator) void {
        allocator.free(self.json);
        allocator.free(self.text);
    }
};

const BacklogArtifact = struct {
    schema: []const u8,
    schema_version: u32,
    recommendation: []const u8 = "",
    recommended_next_branch: []const u8 = "",
    backlog_items: []const BacklogItem = &.{},
    verification_commands: []const []const u8 = &.{},
};

const BacklogItem = struct {
    id: []const u8 = "",
    status: []const u8 = "",
    branch: []const u8 = "",
};

const Candidate = struct {
    id: []const u8,
    title: []const u8,
    recommended_branch: []const u8,
    priority: []const u8,
    why_now: []const u8,
    depends_on: []const []const u8,
    blocked_claims: []const []const u8,
};

const RefreshCheck = struct {
    name: []const u8,
    status: CheckStatus,
    detail: []const u8,
};

const RefreshResult = struct {
    status: RefreshStatus,
    ready_for_next_branch: bool,
    delivered_item_count: usize,
    selected_candidate: Candidate,
    checks: []const RefreshCheck,

    fn deinit(self: RefreshResult, allocator: std.mem.Allocator) void {
        if (self.checks.len > 0) allocator.free(self.checks);
    }
};

const unresolved_candidates: []const Candidate = &.{
    .{
        .id = "nendb-durable-history-hardening",
        .title = "NenDB Durable History Hardening",
        .recommended_branch = "codex/zigeffect-causal-nendb-durable-history-hardening",
        .priority = "P0",
        .why_now = "Durable causal history is the next foundation for self-improving agents, cross-run comparison, replay evidence, and app-facing reuse.",
        .depends_on = &.{ "production-hardening-backlog-refresh", "causal-nendb-storage-backend", "production-telemetry-nendb-retention-fixtures" },
        .blocked_claims = &.{ "cockroach adapter scope", "live production write", "production health proof", "mutation authority" },
    },
    .{
        .id = "agent-query-cross-run-comparison",
        .title = "Agent Query Cross-Run Comparison",
        .recommended_branch = "codex/zigeffect-causal-agent-query-compare-runs",
        .priority = "P1",
        .why_now = "The existing agent query interface is partial because compare_runs remains future work.",
        .depends_on = &.{"nendb-durable-history-hardening"},
        .blocked_claims = &.{ "unbounded query response", "unredacted trace payload" },
    },
    .{
        .id = "audit-chain-snapshot-compare",
        .title = "Named Audit-Chain Snapshot Comparison",
        .recommended_branch = "codex/zigeffect-causal-audit-chain-snapshot-compare",
        .priority = "P2",
        .why_now = "Agents need arbitrary named audit-chain comparison after durable history evidence is hardened.",
        .depends_on = &.{ "nendb-durable-history-hardening", "agent-query-cross-run-comparison" },
        .blocked_claims = &.{ "nondeterministic replay proof", "unbounded snapshot payload" },
    },
    .{
        .id = "app-facing-production-integration-fixtures",
        .title = "App-Facing Production Integration Fixtures",
        .recommended_branch = "codex/zigeffect-causal-app-facing-production-integration-fixtures",
        .priority = "P2",
        .why_now = "Application-facing reuse needs durable history and redaction-ready fixtures before production adapters.",
        .depends_on = &.{ "nendb-durable-history-hardening", "app-semantic-trace-api" },
        .blocked_claims = &.{ "raw request body capture", "worker-incompatible API", "production data capture" },
    },
};

const denied_claims: []const []const u8 = &.{
    "backlog-refresh-is-not-production-health-proof",
    "backlog-refresh-is-not-deployment-success-proof",
    "backlog-refresh-is-not-customer-impact-proof",
    "backlog-refresh-is-not-production-capacity-proof",
    "backlog-refresh-is-not-production-cluster-readiness-proof",
    "backlog-refresh-does-not-enable-live-telemetry",
    "backlog-refresh-does-not-write-durable-state",
    "backlog-refresh-does-not-write-nendb",
    "backlog-refresh-does-not-authorize-cockroach-or-non-nendb-adapters",
    "backlog-refresh-does-not-create-github-checks-or-required-status-checks",
    "backlog-refresh-does-not-mutate-source-config-registry-app-workflow-branch-protection-or-deployment-state",
    "backlog-refresh-grants-no-mutation-authority",
    "backlog-refresh-does-not-authorize-alternate-renderers",
};

const required_verification_commands: []const []const u8 = &.{
    "zig build causal-production-hardening-backlog -- --format json",
    "zig build causal-schema-governance -- --format json",
    "zig build examples",
    "zig build test",
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
        error.MissingBacklogInput => failUsage(err),
        else => return err,
    };
}

fn parseOptions(allocator: std.mem.Allocator, args: []const []const u8) !Options {
    if (args.len < 2) return error.MissingBacklogPath;
    if (!std.mem.eql(u8, args[1], "--from-backlog")) return error.UnknownFlag;
    if (args.len < 3) return error.MissingBacklogPath;
    const backlog_path = args[2];
    if (!std.mem.endsWith(u8, backlog_path, ".json")) return error.InvalidBacklogPath;
    if (args.len < 4) return error.MissingRefreshCommand;
    if (!std.mem.eql(u8, args[3], "refresh")) return error.UnknownCommand;

    var reason: ?[]const u8 = null;
    var verified_commands = std.ArrayList([]const u8).empty;
    var out_prefix: ?[]const u8 = null;
    errdefer verified_commands.deinit(allocator);

    var index: usize = 4;
    while (index < args.len) {
        if (index + 1 >= args.len) return error.MissingFlagValue;
        const flag = args[index];
        const value = args[index + 1];
        if (!std.mem.startsWith(u8, flag, "--")) return error.UnknownArgument;

        if (std.mem.eql(u8, flag, "--reason")) {
            reason = value;
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
        .backlog_path = backlog_path,
        .reason = final_reason,
        .verified_commands = try verified_commands.toOwnedSlice(allocator),
        .out_prefix = out_prefix,
    };
}

fn run(init: std.process.Init, options: Options) !void {
    const allocator = init.gpa;
    const source_backlog_json = try readRequiredArtifact(init.io, allocator, options.backlog_path, error.MissingBacklogInput);
    defer allocator.free(source_backlog_json);

    const reports = try formatReports(allocator, options, source_backlog_json);
    defer reports.deinit(allocator);

    const paths = try outputPathsForOptions(allocator, options);
    defer paths.deinit(allocator);

    try writeArtifact(init.io, paths.json_path, reports.json);
    try writeArtifact(init.io, paths.text_path, reports.text);
    std.debug.print("{s}", .{reports.text});
}

fn outputPathsForOptions(allocator: std.mem.Allocator, options: Options) !OutputPaths {
    const prefix = if (options.out_prefix) |out_prefix|
        try allocator.dupe(u8, out_prefix)
    else
        try allocator.dupe(u8, default_output_prefix);
    defer allocator.free(prefix);

    return .{
        .json_path = try std.fmt.allocPrint(allocator, "{s}.json", .{prefix}),
        .text_path = try std.fmt.allocPrint(allocator, "{s}.txt", .{prefix}),
    };
}

fn formatReports(allocator: std.mem.Allocator, options: Options, source_backlog_json: []const u8) !RefreshReports {
    var parsed = try std.json.parseFromSlice(BacklogArtifact, allocator, source_backlog_json, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();

    const result = try evaluateRefresh(allocator, parsed.value);
    defer result.deinit(allocator);

    const paths = try outputPathsForOptions(allocator, options);
    defer paths.deinit(allocator);

    const json = try formatRefreshJson(allocator, options, parsed.value, result, paths);
    errdefer allocator.free(json);
    const text = try formatRefreshText(allocator, options, parsed.value, result, paths);
    errdefer allocator.free(text);

    return .{ .json = json, .text = text };
}

fn formatTextReport(
    allocator: std.mem.Allocator,
    source_backlog_json: []const u8,
    reason: []const u8,
    verified_commands: []const []const u8,
) ![]const u8 {
    const options = Options{
        .backlog_path = "fixture-production-hardening-backlog.json",
        .reason = reason,
        .verified_commands = verified_commands,
    };
    const reports = try formatReports(allocator, options, source_backlog_json);
    allocator.free(reports.json);
    return reports.text;
}

fn evaluateRefresh(allocator: std.mem.Allocator, source: BacklogArtifact) !RefreshResult {
    var checks = std.ArrayList(RefreshCheck).empty;
    errdefer checks.deinit(allocator);

    try appendCheck(allocator, &checks, "source-schema", if (sourceSchemaValid(source)) .pass else .fail, "source production hardening backlog schema is supported");
    try appendCheck(allocator, &checks, "source-recommendation-supported", if (sourceRecommendationSupported(source.recommendation)) .pass else .fail, "source backlog recommendation is transition or post-refresh handoff");
    try appendCheck(allocator, &checks, "source-branch-supported", if (sourceBranchSupported(source.recommended_next_branch)) .pass else .fail, "source backlog branch is refresh or selected NenDB durable-history branch");
    try appendCheck(allocator, &checks, "terminal-item-delivered", if (terminalItemDelivered(source)) .pass else .fail, "terminal required-status-check enforcement report policy item is delivered");
    try appendCheck(allocator, &checks, "terminal-command-recorded", if (terminalCommandRecorded(source)) .pass else .fail, "terminal report policy build command is present in source verification commands");
    try appendCheck(allocator, &checks, "selected-branch-nendb-only", if (selectedBranchNendbOnly()) .pass else .fail, "selected branch is NenDB durable-history hardening and not a cockroach branch");
    try appendCheck(allocator, &checks, "selected-work-record-only", if (recordOnlyAuthority()) .pass else .fail, "refresh grants no mutation live telemetry durable write or NenDB write authority");
    try appendCheck(allocator, &checks, "candidate-catalog-present", if (candidateCatalogPresent()) .pass else .fail, "unresolved candidate catalog includes durable history agent comparison snapshot and app-facing follow-ups");
    try appendCheck(allocator, &checks, "denied-claims-present", if (deniedClaimsPresent()) .pass else .fail, "denied inference catalog blocks production health cluster capacity durable write and mutation claims");

    const check_slice = try checks.toOwnedSlice(allocator);
    errdefer allocator.free(check_slice);
    const ready = allChecksPassed(check_slice);

    return .{
        .status = if (ready) .ready else .blocked,
        .ready_for_next_branch = ready,
        .delivered_item_count = deliveredItemCount(source),
        .selected_candidate = selectedCandidate(),
        .checks = check_slice,
    };
}

fn appendCheck(
    allocator: std.mem.Allocator,
    checks: *std.ArrayList(RefreshCheck),
    name: []const u8,
    status: CheckStatus,
    detail: []const u8,
) !void {
    try checks.append(allocator, .{ .name = name, .status = status, .detail = detail });
}

fn sourceSchemaValid(source: BacklogArtifact) bool {
    return std.mem.eql(u8, source.schema, source_backlog_schema) and source.schema_version == 1;
}

fn sourceRecommendationSupported(value: []const u8) bool {
    return std.mem.eql(u8, value, source_transition_recommendation) or
        std.mem.eql(u8, value, recommendation);
}

fn sourceBranchSupported(value: []const u8) bool {
    return std.mem.eql(u8, value, source_transition_branch) or
        std.mem.eql(u8, value, next_branch_if_ready);
}

fn terminalItemDelivered(source: BacklogArtifact) bool {
    for (source.backlog_items) |item| {
        if (std.mem.eql(u8, item.id, terminal_item_id) and std.mem.eql(u8, item.status, "delivered")) return true;
    }
    return false;
}

fn terminalCommandRecorded(source: BacklogArtifact) bool {
    for (source.verification_commands) |command| {
        if (std.mem.indexOf(u8, command, terminal_build_command) != null) return true;
    }
    return false;
}

fn deliveredItemCount(source: BacklogArtifact) usize {
    var count: usize = 0;
    for (source.backlog_items) |item| {
        if (std.mem.eql(u8, item.status, "delivered")) count += 1;
    }
    return count;
}

fn selectedBranchNendbOnly() bool {
    return std.mem.indexOf(u8, next_branch_if_ready, "nendb") != null and
        std.mem.indexOf(u8, next_branch_if_ready, "cockroach") == null;
}

fn recordOnlyAuthority() bool {
    return !github_api_mutation_enabled and
        !github_check_run_creation_enabled and
        !branch_protection_mutation_by_tool_enabled and
        !ci_gate_enabled and
        !ci_gate_enforcement_enabled and
        !ci_required_status_check_enabled and
        !ci_workflow_mutation_enabled and
        !ci_upload_execution_enabled and
        !ci_report_publication_enabled and
        !github_step_summary_write_enabled and
        !pull_request_comment_enabled and
        !production_telemetry_ingestion and
        !live_exporter_enabled and
        !network_send_enabled and
        !collector_endpoint_configured and
        !otlp_serialization_enabled and
        !runtime_pipeline_enabled and
        !durable_write_enabled and
        !nendb_write_enabled and
        !cockroach_adapter_enabled and
        std.mem.eql(u8, mutation_authority, "none");
}

fn candidateCatalogPresent() bool {
    return hasCandidate("nendb-durable-history-hardening") and
        hasCandidate("agent-query-cross-run-comparison") and
        hasCandidate("audit-chain-snapshot-compare") and
        hasCandidate("app-facing-production-integration-fixtures");
}

fn deniedClaimsPresent() bool {
    return containsString(denied_claims, "backlog-refresh-is-not-production-health-proof") and
        containsString(denied_claims, "backlog-refresh-is-not-production-cluster-readiness-proof") and
        containsString(denied_claims, "backlog-refresh-does-not-write-durable-state") and
        containsString(denied_claims, "backlog-refresh-does-not-authorize-cockroach-or-non-nendb-adapters") and
        containsString(denied_claims, "backlog-refresh-grants-no-mutation-authority");
}

fn hasCandidate(id: []const u8) bool {
    for (unresolved_candidates) |candidate| {
        if (std.mem.eql(u8, candidate.id, id)) return true;
    }
    return false;
}

fn selectedCandidate() Candidate {
    return unresolved_candidates[0];
}

fn allChecksPassed(checks: []const RefreshCheck) bool {
    for (checks) |check| {
        if (check.status != .pass) return false;
    }
    return true;
}

fn refreshStatusText(status: RefreshStatus) []const u8 {
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

fn formatRefreshText(
    allocator: std.mem.Allocator,
    options: Options,
    source: BacklogArtifact,
    result: RefreshResult,
    paths: OutputPaths,
) ![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "zigeffect causal production hardening backlog refresh\n");
    try output.print(allocator, "schema: {s}\n", .{production_hardening_backlog_refresh_schema});
    try output.print(allocator, "schema_version: {d}\n", .{production_hardening_backlog_refresh_schema_version});
    try output.print(allocator, "generated by: {s}\n", .{generated_by});
    try output.print(allocator, "source backlog: {s}\n", .{options.backlog_path});
    try output.print(allocator, "source backlog schema: {s}\n", .{source.schema});
    try output.print(allocator, "source recommendation: {s}\n", .{source.recommendation});
    try output.print(allocator, "source recommended branch: {s}\n", .{source.recommended_next_branch});
    try output.print(allocator, "source delivered item count: {d}\n", .{result.delivered_item_count});
    try output.print(allocator, "terminal delivered item: {s}\n", .{terminal_item_id});
    try output.print(allocator, "backlog refresh status: {s}\n", .{refreshStatusText(result.status)});
    try output.print(allocator, "ready for next branch: {}\n", .{result.ready_for_next_branch});
    try output.print(allocator, "selected next work: {s}\n", .{result.selected_candidate.id});
    try output.print(allocator, "selected next branch: {s}\n", .{result.selected_candidate.recommended_branch});
    try output.print(allocator, "recommendation: {s}\n", .{recommendation});
    try output.print(allocator, "mutation authority: {s}\n", .{mutation_authority});
    try output.print(allocator, "reason: {s}\n", .{options.reason});
    try output.print(allocator, "json output: {s}\n", .{paths.json_path});
    try output.print(allocator, "text output: {s}\n\n", .{paths.text_path});

    try output.appendSlice(allocator, "checks:\n");
    for (result.checks) |check| {
        try output.print(allocator, "- {s}: {s} - {s}\n", .{ check.name, checkStatusText(check.status), check.detail });
    }
    try output.append(allocator, '\n');

    try appendCandidatesText(allocator, &output);
    try appendTextList(allocator, &output, "denied claims", denied_claims);
    try appendTextList(allocator, &output, "required verification commands", required_verification_commands);
    try appendTextList(allocator, &output, "verified commands", options.verified_commands);
    try appendTextList(allocator, &output, "agent guidance", agentGuidance(result.status));

    return output.toOwnedSlice(allocator);
}

fn formatRefreshJson(
    allocator: std.mem.Allocator,
    options: Options,
    source: BacklogArtifact,
    result: RefreshResult,
    paths: OutputPaths,
) ![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "{\n");
    try appendJsonProperty(allocator, &output, "schema", production_hardening_backlog_refresh_schema, true);
    try output.print(allocator, "  \"schema_version\": {d},\n", .{production_hardening_backlog_refresh_schema_version});
    try appendJsonProperty(allocator, &output, "generated_by", generated_by, true);
    try appendJsonProperty(allocator, &output, "source_backlog", options.backlog_path, true);
    try appendJsonProperty(allocator, &output, "source_schema", source.schema, true);
    try output.print(allocator, "  \"source_schema_version\": {d},\n", .{source.schema_version});
    try appendJsonProperty(allocator, &output, "source_recommendation", source.recommendation, true);
    try appendJsonProperty(allocator, &output, "source_recommended_next_branch", source.recommended_next_branch, true);
    try output.print(allocator, "  \"source_delivered_item_count\": {d},\n", .{result.delivered_item_count});
    try appendJsonProperty(allocator, &output, "terminal_delivered_item", terminal_item_id, true);
    try appendJsonProperty(allocator, &output, "backlog_refresh_status", refreshStatusText(result.status), true);
    try output.print(allocator, "  \"ready_for_next_branch\": {},\n", .{result.ready_for_next_branch});
    try appendJsonProperty(allocator, &output, "selected_next_work", result.selected_candidate.id, true);
    try appendJsonProperty(allocator, &output, "selected_next_branch", result.selected_candidate.recommended_branch, true);
    try appendJsonProperty(allocator, &output, "recommendation", recommendation, true);
    try appendJsonProperty(allocator, &output, "next_branch_if_ready", next_branch_if_ready, true);
    try appendJsonProperty(allocator, &output, "reason", options.reason, true);
    try output.print(allocator, "  \"github_api_mutation_enabled\": {},\n", .{github_api_mutation_enabled});
    try output.print(allocator, "  \"github_check_run_creation_enabled\": {},\n", .{github_check_run_creation_enabled});
    try output.print(allocator, "  \"branch_protection_mutation_by_tool_enabled\": {},\n", .{branch_protection_mutation_by_tool_enabled});
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
    try output.print(allocator, "  \"cockroach_adapter_enabled\": {},\n", .{cockroach_adapter_enabled});
    try appendJsonProperty(allocator, &output, "mutation_authority", mutation_authority, true);
    try output.appendSlice(allocator, "  \"checks\": ");
    try appendChecksJson(allocator, &output, result.checks);
    try output.appendSlice(allocator, ",\n  \"unresolved_candidates\": ");
    try appendCandidatesJson(allocator, &output);
    try output.appendSlice(allocator, ",\n  \"denied_claims\": ");
    try appendStringArray(allocator, &output, denied_claims);
    try output.appendSlice(allocator, ",\n  \"required_verification_commands\": ");
    try appendStringArray(allocator, &output, required_verification_commands);
    try output.appendSlice(allocator, ",\n  \"verified_commands\": ");
    try appendStringArray(allocator, &output, options.verified_commands);
    try appendJsonPropertyPrefixComma(allocator, &output, "json_output", paths.json_path);
    try appendJsonPropertyPrefixComma(allocator, &output, "text_output", paths.text_path);
    try output.appendSlice(allocator, ",\n  \"agent_guidance\": ");
    try appendStringArray(allocator, &output, agentGuidance(result.status));
    try output.appendSlice(allocator, "\n}\n");

    return output.toOwnedSlice(allocator);
}

fn appendJsonProperty(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    name: []const u8,
    value: []const u8,
    comma: bool,
) !void {
    try output.appendSlice(allocator, "  ");
    try appendJsonString(allocator, output, name);
    try output.appendSlice(allocator, ": ");
    try appendJsonString(allocator, output, value);
    if (comma) try output.append(allocator, ',');
    try output.append(allocator, '\n');
}

fn appendJsonPropertyPrefixComma(allocator: std.mem.Allocator, output: *std.ArrayList(u8), name: []const u8, value: []const u8) !void {
    try output.appendSlice(allocator, ",\n  ");
    try appendJsonString(allocator, output, name);
    try output.appendSlice(allocator, ": ");
    try appendJsonString(allocator, output, value);
}

fn appendChecksJson(allocator: std.mem.Allocator, output: *std.ArrayList(u8), checks: []const RefreshCheck) !void {
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

fn appendCandidatesJson(allocator: std.mem.Allocator, output: *std.ArrayList(u8)) !void {
    try output.append(allocator, '[');
    for (unresolved_candidates, 0..) |candidate, index| {
        if (index > 0) try output.appendSlice(allocator, ", ");
        try output.appendSlice(allocator, "{ \"id\": ");
        try appendJsonString(allocator, output, candidate.id);
        try output.appendSlice(allocator, ", \"title\": ");
        try appendJsonString(allocator, output, candidate.title);
        try output.appendSlice(allocator, ", \"recommended_branch\": ");
        try appendJsonString(allocator, output, candidate.recommended_branch);
        try output.appendSlice(allocator, ", \"priority\": ");
        try appendJsonString(allocator, output, candidate.priority);
        try output.appendSlice(allocator, ", \"why_now\": ");
        try appendJsonString(allocator, output, candidate.why_now);
        try output.appendSlice(allocator, ", \"depends_on\": ");
        try appendStringArray(allocator, output, candidate.depends_on);
        try output.appendSlice(allocator, ", \"blocked_claims\": ");
        try appendStringArray(allocator, output, candidate.blocked_claims);
        try output.appendSlice(allocator, " }");
    }
    try output.append(allocator, ']');
}

fn appendCandidatesText(allocator: std.mem.Allocator, output: *std.ArrayList(u8)) !void {
    try output.appendSlice(allocator, "unresolved candidates:\n");
    for (unresolved_candidates) |candidate| {
        try output.print(allocator, "- {s}: {s}\n", .{ candidate.id, candidate.title });
        try output.print(allocator, "  branch: {s}\n", .{candidate.recommended_branch});
        try output.print(allocator, "  priority: {s}\n", .{candidate.priority});
        try output.print(allocator, "  why now: {s}\n", .{candidate.why_now});
        try output.appendSlice(allocator, "  depends on:");
        for (candidate.depends_on) |dependency| try output.print(allocator, " {s}", .{dependency});
        try output.append(allocator, '\n');
        try output.appendSlice(allocator, "  blocked claims:");
        for (candidate.blocked_claims) |claim| try output.print(allocator, " {s};", .{claim});
        try output.append(allocator, '\n');
    }
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

fn containsString(values: []const []const u8, needle: []const u8) bool {
    for (values) |value| {
        if (std.mem.eql(u8, value, needle)) return true;
    }
    return false;
}

fn agentGuidance(status: RefreshStatus) []const []const u8 {
    return switch (status) {
        .ready => &.{
            "Use this refresh artifact to leave the delivered production-hardening queue and start NenDB durable-history hardening.",
            "Treat agent-query compare_runs arbitrary audit-chain snapshot compare and app-facing production fixtures as dependent follow-ups.",
            "Do not infer production health deployment success customer impact capacity cluster readiness live telemetry durable writes NenDB writes cockroach scope or mutation authority.",
        },
        .blocked => &.{
            "Treat blocked backlog refresh evidence as a stop sign.",
            "Repair source backlog schema recommendation terminal delivered item or terminal verification command evidence before selecting a next branch.",
            "Do not start NenDB durable-history hardening from a blocked refresh artifact.",
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

fn usage() []const u8 {
    return "usage: zig build causal-production-hardening-backlog-refresh -- --from-backlog <production-hardening-backlog.json> refresh --reason <reason> [--verified-command <command>]... [--out-prefix <path-prefix>]\n";
}

fn failUsage(err: anyerror) noreturn {
    std.debug.print("causal-production-hardening-backlog-refresh error: {s}\n{s}", .{ @errorName(err), usage() });
    std.process.exit(2);
}

fn freeSliceOnly(allocator: std.mem.Allocator, values: []const []const u8) void {
    if (values.len > 0) allocator.free(values);
}

fn readySourceBacklogJson() []const u8 {
    return
    \\{
    \\  "schema": "zigeffect.causal.production-hardening-backlog.v1",
    \\  "schema_version": 1,
    \\  "recommendation": "refresh-production-hardening-backlog",
    \\  "recommended_next_branch": "codex/zigeffect-causal-production-hardening-backlog-refresh",
    \\  "backlog_items": [
    \\    {
    \\      "id": "production-telemetry-ci-gate-required-status-check-enforcement-report-policy",
    \\      "status": "delivered",
    \\      "branch": "codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-enforcement-report-policy"
    \\    }
    \\  ],
    \\  "verification_commands": [
    \\    "zig build causal-production-telemetry-ci-gate-required-status-check-enforcement-report-policy"
    \\  ]
    \\}
    ;
}

fn readyPostRefreshBacklogJson() []const u8 {
    return
    \\{
    \\  "schema": "zigeffect.causal.production-hardening-backlog.v1",
    \\  "schema_version": 1,
    \\  "recommendation": "start-nendb-durable-history-hardening",
    \\  "recommended_next_branch": "codex/zigeffect-causal-nendb-durable-history-hardening",
    \\  "backlog_items": [
    \\    {
    \\      "id": "production-telemetry-ci-gate-required-status-check-enforcement-report-policy",
    \\      "status": "delivered",
    \\      "branch": "codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-enforcement-report-policy"
    \\    },
    \\    {
    \\      "id": "production-hardening-backlog-refresh",
    \\      "status": "delivered",
    \\      "branch": "codex/zigeffect-causal-production-hardening-backlog-refresh"
    \\    }
    \\  ],
    \\  "verification_commands": [
    \\    "zig build causal-production-telemetry-ci-gate-required-status-check-enforcement-report-policy",
    \\    "zig build causal-production-hardening-backlog-refresh"
    \\  ]
    \\}
    ;
}

test "refresh constants preserve the NenDB-only handoff" {
    try std.testing.expectEqualStrings(
        "zigeffect.causal.production-hardening-backlog-refresh.v1",
        production_hardening_backlog_refresh_schema,
    );
    try std.testing.expectEqual(@as(u32, 1), production_hardening_backlog_refresh_schema_version);
    try std.testing.expectEqualStrings("start-nendb-durable-history-hardening", recommendation);
    try std.testing.expectEqualStrings(
        "codex/zigeffect-causal-nendb-durable-history-hardening",
        next_branch_if_ready,
    );
}

test "refresh report selects durable history and not Cockroach" {
    const allocator = std.testing.allocator;
    const report = try formatTextReport(allocator, readySourceBacklogJson(), "refresh reviewed", &.{
        "zig build causal-production-hardening-backlog -- --format json",
        "zig build causal-schema-governance -- --format json",
    });
    defer allocator.free(report);

    try std.testing.expect(std.mem.indexOf(u8, report, "backlog refresh status: ready") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "selected next branch: codex/zigeffect-causal-nendb-durable-history-hardening") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "Cockroach") == null);
}

test "refresh accepts post-refresh backlog source" {
    const allocator = std.testing.allocator;
    const report = try formatTextReport(allocator, readyPostRefreshBacklogJson(), "post refresh reviewed", &.{});
    defer allocator.free(report);

    try std.testing.expect(std.mem.indexOf(u8, report, "source recommendation: start-nendb-durable-history-hardening") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "backlog refresh status: ready") != null);
}

test "refresh json is machine readable" {
    const allocator = std.testing.allocator;
    const options = Options{
        .backlog_path = "fixture-production-hardening-backlog.json",
        .reason = "refresh reviewed",
        .verified_commands = &.{
            "zig build causal-production-hardening-backlog -- --format json",
            "zig build causal-schema-governance -- --format json",
            "zig build examples",
            "zig build test",
        },
    };
    const reports = try formatReports(allocator, options, readySourceBacklogJson());
    defer reports.deinit(allocator);

    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"schema\": \"zigeffect.causal.production-hardening-backlog-refresh.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"backlog_refresh_status\": \"ready\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"ready_for_next_branch\": true") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"selected_next_work\": \"nendb-durable-history-hardening\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"selected_next_branch\": \"codex/zigeffect-causal-nendb-durable-history-hardening\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"cockroach_adapter_enabled\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"mutation_authority\": \"none\"") != null);
}

test "refresh blocks wrong source schema" {
    const allocator = std.testing.allocator;
    const report = try formatTextReport(allocator,
        \\{
        \\  "schema": "zigeffect.causal.other.v1",
        \\  "schema_version": 1,
        \\  "recommendation": "refresh-production-hardening-backlog",
        \\  "recommended_next_branch": "codex/zigeffect-causal-production-hardening-backlog-refresh",
        \\  "backlog_items": [
        \\    {"id": "production-telemetry-ci-gate-required-status-check-enforcement-report-policy", "status": "delivered"}
        \\  ],
        \\  "verification_commands": ["zig build causal-production-telemetry-ci-gate-required-status-check-enforcement-report-policy"]
        \\}
    , "negative schema", &.{});
    defer allocator.free(report);

    try std.testing.expect(std.mem.indexOf(u8, report, "backlog refresh status: blocked") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "source-schema: fail") != null);
}

test "refresh blocks unsupported source recommendation" {
    const allocator = std.testing.allocator;
    const report = try formatTextReport(allocator,
        \\{
        \\  "schema": "zigeffect.causal.production-hardening-backlog.v1",
        \\  "schema_version": 1,
        \\  "recommendation": "start-cockroach-durable-history",
        \\  "recommended_next_branch": "codex/zigeffect-causal-cockroach-durable-history",
        \\  "backlog_items": [
        \\    {"id": "production-telemetry-ci-gate-required-status-check-enforcement-report-policy", "status": "delivered"}
        \\  ],
        \\  "verification_commands": ["zig build causal-production-telemetry-ci-gate-required-status-check-enforcement-report-policy"]
        \\}
    , "negative recommendation", &.{});
    defer allocator.free(report);

    try std.testing.expect(std.mem.indexOf(u8, report, "backlog refresh status: blocked") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "source-recommendation-supported: fail") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "source-branch-supported: fail") != null);
}

test "refresh blocks missing terminal delivered item" {
    const allocator = std.testing.allocator;
    const report = try formatTextReport(allocator,
        \\{
        \\  "schema": "zigeffect.causal.production-hardening-backlog.v1",
        \\  "schema_version": 1,
        \\  "recommendation": "refresh-production-hardening-backlog",
        \\  "recommended_next_branch": "codex/zigeffect-causal-production-hardening-backlog-refresh",
        \\  "backlog_items": [
        \\    {"id": "production-telemetry-ci-gate-required-status-check-enforcement-report-policy", "status": "planned"}
        \\  ],
        \\  "verification_commands": ["zig build causal-production-telemetry-ci-gate-required-status-check-enforcement-report-policy"]
        \\}
    , "negative terminal", &.{});
    defer allocator.free(report);

    try std.testing.expect(std.mem.indexOf(u8, report, "backlog refresh status: blocked") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "terminal-item-delivered: fail") != null);
}

test "refresh blocks missing terminal verification command" {
    const allocator = std.testing.allocator;
    const report = try formatTextReport(allocator,
        \\{
        \\  "schema": "zigeffect.causal.production-hardening-backlog.v1",
        \\  "schema_version": 1,
        \\  "recommendation": "refresh-production-hardening-backlog",
        \\  "recommended_next_branch": "codex/zigeffect-causal-production-hardening-backlog-refresh",
        \\  "backlog_items": [
        \\    {"id": "production-telemetry-ci-gate-required-status-check-enforcement-report-policy", "status": "delivered"}
        \\  ],
        \\  "verification_commands": []
        \\}
    , "negative terminal command", &.{});
    defer allocator.free(report);

    try std.testing.expect(std.mem.indexOf(u8, report, "backlog refresh status: blocked") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "terminal-command-recorded: fail") != null);
}
