const std = @import("std");
const fx = @import("zigeffect");

pub const nendb_durable_history_schema = fx.causal_nendb_durable_history_schema;
pub const nendb_durable_history_schema_version = fx.causal_nendb_durable_history_schema_version;
pub const source_branch = "codex/zigeffect-causal-nendb-durable-history-hardening";
pub const recommendation = "start-agent-query-cross-run-comparison";
pub const next_branch_if_ready = "codex/zigeffect-causal-agent-query-compare-runs";

const generated_by = "causal-nendb-durable-history-hardening";
const default_output_prefix = "../../.zig-cache/causal-artifacts/nendb-durable-history-hardening";

const live_telemetry_enabled = false;
const network_send_enabled = false;
const durable_write_authority = false;
const nendb_write_authority = false;
const cockroach_adapter_enabled = false;
const mutation_authority = "none";

const OutputFormat = enum { text, json };
const FixtureStatus = enum { ready, blocked };
const CheckStatus = enum { pass, fail };

const Options = struct {
    format: OutputFormat = .text,
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

const Reports = struct {
    json: []const u8,
    text: []const u8,

    fn deinit(self: Reports, allocator: std.mem.Allocator) void {
        allocator.free(self.json);
        allocator.free(self.text);
    }
};

const FixtureCheck = struct {
    name: []const u8,
    status: CheckStatus,
    detail: []const u8,
};

const FixtureEvidence = struct {
    report: fx.CausalNendbDurableHistoryReport,
    store_retained_events: usize,
    writer_write_count: usize,
    parent_edge_write_count: usize,
    cause_query_restores_path: bool,
    lineage_query_finds_descendants: bool,
    redaction_marker_observed: bool,
    raw_secret_absent: bool,
};

const FixtureResult = struct {
    status: FixtureStatus,
    ready_for_next_branch: bool,
    evidence: FixtureEvidence,
    checks: []const FixtureCheck,

    fn deinit(self: FixtureResult, allocator: std.mem.Allocator) void {
        if (self.checks.len > 0) allocator.free(self.checks);
    }
};

const FakeNendbWriter = struct {
    allocator: std.mem.Allocator,
    writes: std.ArrayList(fx.CausalNendbWrite) = .empty,
    flush_count: u64 = 0,

    pub fn init(allocator: std.mem.Allocator) FakeNendbWriter {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *FakeNendbWriter) void {
        for (self.writes.items) |*write| {
            fx.deinitCausalNendbWrite(self.allocator, write);
        }
        self.writes.deinit(self.allocator);
    }

    pub fn writer(self: *FakeNendbWriter) fx.CausalNendbGraphWriter {
        return .{
            .state = self,
            .write = writeFakeNendb,
            .flush = flushFakeNendb,
        };
    }
};

const denied_claims: []const []const u8 = &.{
    "nendb-durable-history-is-not-production-health-proof",
    "nendb-durable-history-is-not-live-telemetry-ingestion",
    "nendb-durable-history-does-not-enable-network-send",
    "nendb-durable-history-does-not-grant-durable-production-write-authority",
    "nendb-durable-history-does-not-grant-nendb-production-write-authority",
    "nendb-durable-history-does-not-authorize-cockroach-or-non-nendb-adapters",
    "nendb-durable-history-does-not-run-compaction-backup-restore-or-ttl-deletion",
    "nendb-durable-history-grants-no-mutation-authority",
};

const required_check_names: []const []const u8 = &.{
    "writer-attached",
    "node-write-present",
    "parent-edge-present",
    "flush-observed",
    "history-exceeds-store-retention",
    "cause-query-restores-path",
    "lineage-query-supported",
    "redaction-marker-observed",
    "raw-secret-absent",
    "nendb-only-authority",
};

pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len == 2 and (std.mem.eql(u8, args[1], "--help") or std.mem.eql(u8, args[1], "-h"))) {
        std.debug.print("{s}", .{usage()});
        return;
    }

    const options = parseOptions(args) catch |err| failUsage(err);
    const reports = try formatReports(init.gpa, options, true);
    defer reports.deinit(init.gpa);
    const paths = try outputPathsForOptions(init.gpa, options);
    defer paths.deinit(init.gpa);

    try writeArtifact(init.io, paths.json_path, reports.json);
    try writeArtifact(init.io, paths.text_path, reports.text);

    switch (options.format) {
        .text => std.debug.print("{s}", .{reports.text}),
        .json => std.debug.print("{s}", .{reports.json}),
    }
}

fn parseOptions(args: []const []const u8) !Options {
    var options = Options{};
    var index: usize = 1;
    while (index < args.len) {
        const flag = args[index];
        if (!std.mem.startsWith(u8, flag, "--")) return error.UnknownArgument;
        if (index + 1 >= args.len) return error.MissingFlagValue;
        const value = args[index + 1];
        if (std.mem.eql(u8, flag, "--format")) {
            options.format = parseFormat(value) catch return error.UnknownFormat;
        } else if (std.mem.eql(u8, flag, "--out-prefix")) {
            options.out_prefix = value;
        } else {
            return error.UnknownFlag;
        }
        index += 2;
    }
    return options;
}

fn parseFormat(value: []const u8) !OutputFormat {
    if (std.mem.eql(u8, value, "text")) return .text;
    if (std.mem.eql(u8, value, "json")) return .json;
    if (value.len == 0) return error.MissingFormat;
    return error.UnknownFormat;
}

fn formatReports(allocator: std.mem.Allocator, options: Options, include_redaction_marker: bool) !Reports {
    const result = try evaluateFixture(allocator, include_redaction_marker);
    defer result.deinit(allocator);
    const paths = try outputPathsForOptions(allocator, options);
    defer paths.deinit(allocator);

    const json = try formatJsonReport(allocator, result, paths);
    errdefer allocator.free(json);
    const text = try formatTextReportFromResult(allocator, result, paths);
    errdefer allocator.free(text);
    return .{ .json = json, .text = text };
}

fn formatTextReport(allocator: std.mem.Allocator, _: OutputFormat) ![]const u8 {
    const reports = try formatReports(allocator, .{}, true);
    allocator.free(reports.json);
    return reports.text;
}

fn formatTextReportWithoutRedaction(allocator: std.mem.Allocator) ![]const u8 {
    const reports = try formatReports(allocator, .{}, false);
    allocator.free(reports.json);
    return reports.text;
}

fn evaluateFixture(allocator: std.mem.Allocator, include_redaction_marker: bool) !FixtureResult {
    const evidence = try buildFixtureEvidence(allocator, include_redaction_marker);
    var checks = std.ArrayList(FixtureCheck).empty;
    errdefer checks.deinit(allocator);

    try appendCheck(allocator, &checks, "writer-attached", if (evidence.report.writer_attached) .pass else .fail, "CausalNendbGraphWriter boundary is attached");
    try appendCheck(allocator, &checks, "node-write-present", if (evidence.writer_write_count > 0) .pass else .fail, "fixture writes at least one NenDB-shaped node");
    try appendCheck(allocator, &checks, "parent-edge-present", if (evidence.parent_edge_write_count > 0) .pass else .fail, "fixture writes a causal_parent edge");
    try appendCheck(allocator, &checks, "flush-observed", if (evidence.report.flush_observed) .pass else .fail, "flush hook was observed when required");
    try appendCheck(allocator, &checks, "history-exceeds-store-retention", if (evidence.report.retained_events > evidence.store_retained_events) .pass else .fail, "adapter history outlives bounded core store retention");
    try appendCheck(allocator, &checks, "cause-query-restores-path", if (evidence.cause_query_restores_path) .pass else .fail, "cause query restores root and child event ids");
    try appendCheck(allocator, &checks, "lineage-query-supported", if (evidence.lineage_query_finds_descendants and evidence.report.lineage_query_supported) .pass else .fail, "lineage query finds retained descendants");
    try appendCheck(allocator, &checks, "redaction-marker-observed", if (evidence.redaction_marker_observed and evidence.report.redaction_observed) .pass else .fail, "redaction evidence is explicit");
    try appendCheck(allocator, &checks, "raw-secret-absent", if (evidence.raw_secret_absent) .pass else .fail, "fixture does not retain raw test secrets");
    try appendCheck(allocator, &checks, "nendb-only-authority", if (nendbOnlyAuthority(evidence.report)) .pass else .fail, "no Cockroach live telemetry network or mutation authority is enabled");

    const check_slice = try checks.toOwnedSlice(allocator);
    errdefer allocator.free(check_slice);
    const ready = allChecksPassed(check_slice);
    return .{
        .status = if (ready) .ready else .blocked,
        .ready_for_next_branch = ready,
        .evidence = evidence,
        .checks = check_slice,
    };
}

fn buildFixtureEvidence(allocator: std.mem.Allocator, include_redaction_marker: bool) !FixtureEvidence {
    var fake = FakeNendbWriter.init(allocator);
    defer fake.deinit();
    var backend_state = fx.CausalNendbStorageBackendState.init(allocator, fake.writer(), .{ .max_events = 16 });
    defer backend_state.deinit();

    var store = fx.CausalStore.initWithOptions(allocator, .{ .max_events = 1 });
    store.attachBackend(backend_state.backend());
    defer store.deinit();

    const root_detail = if (include_redaction_marker) fx.causal_redaction_marker else "safe but unmarked";
    const root = try store.record(.{
        .kind = .run_started,
        .run_id = 77,
        .label = "nendb-durable-history-root",
        .redacted_detail = root_detail,
    });
    const child = try store.record(.{
        .kind = .log_recorded,
        .run_id = 77,
        .parent_id = root,
        .label = "nendb-durable-history-child",
        .redacted_detail = "safe retained detail",
    });
    _ = try store.record(.{
        .kind = .effect_completed,
        .run_id = 77,
        .parent_id = root,
        .label = "nendb-durable-history-terminal",
        .redacted_detail = "complete",
    });
    try backend_state.flush();

    var store_snapshot = try store.snapshot(allocator);
    defer store_snapshot.deinit();
    var store_cause = try store.cause(allocator, child);
    defer store_cause.deinit();
    var history_cause = try backend_state.cause(allocator, child);
    defer history_cause.deinit();
    var history_lineage = try backend_state.lineage(allocator, root);
    defer history_lineage.deinit();

    const report = backend_state.durableHistoryReport(.{
        .max_events = 16,
        .ttl_days = 14,
        .compaction_trigger_events = 2,
        .compact_to_events = 1,
        .backup_required = true,
        .recovery_required = true,
        .flush_required = true,
        .redaction_required = true,
        .lineage_query_required = true,
    });

    return .{
        .report = report,
        .store_retained_events = store_snapshot.events.len,
        .writer_write_count = fake.writes.items.len,
        .parent_edge_write_count = parentEdgeWriteCount(fake.writes.items),
        .cause_query_restores_path = store_cause.events.len == 0 and
            history_cause.events.len == 2 and
            history_cause.events[0].id == root and
            history_cause.events[1].id == child,
        .lineage_query_finds_descendants = history_lineage.events.len == 3 and
            history_lineage.events[0].id == root and
            history_lineage.events[1].id == child,
        .redaction_marker_observed = writesContainString(fake.writes.items, fx.causal_redaction_marker) or
            eventsContainString(history_cause.events, fx.causal_redaction_marker),
        .raw_secret_absent = !writesContainString(fake.writes.items, "raw-secret") and
            !eventsContainString(history_cause.events, "raw-secret") and
            !eventsContainString(store_snapshot.events, "raw-secret"),
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

fn nendbOnlyAuthority(report: fx.CausalNendbDurableHistoryReport) bool {
    return !report.live_telemetry_enabled and
        !report.network_send_enabled and
        !report.durable_write_authority and
        !report.nendb_write_authority and
        !report.cockroach_adapter_enabled and
        std.mem.eql(u8, report.mutation_authority, mutation_authority) and
        !live_telemetry_enabled and
        !network_send_enabled and
        !durable_write_authority and
        !nendb_write_authority and
        !cockroach_adapter_enabled;
}

fn allChecksPassed(checks: []const FixtureCheck) bool {
    for (checks) |check| {
        if (check.status != .pass) return false;
    }
    return true;
}

fn parentEdgeWriteCount(writes: []const fx.CausalNendbWrite) usize {
    var count: usize = 0;
    for (writes) |write| {
        if (write.parent_edge != null) count += 1;
    }
    return count;
}

fn writesContainString(writes: []const fx.CausalNendbWrite, needle: []const u8) bool {
    for (writes) |write| {
        if (std.mem.indexOf(u8, write.node.label, needle) != null) return true;
        if (std.mem.indexOf(u8, write.node.properties, needle) != null) return true;
        if (write.parent_edge) |edge| {
            if (std.mem.indexOf(u8, edge.label, needle) != null) return true;
            if (std.mem.indexOf(u8, edge.properties, needle) != null) return true;
        }
    }
    return false;
}

fn eventsContainString(events: []const fx.CausalEvent, needle: []const u8) bool {
    for (events) |event| {
        if (std.mem.indexOf(u8, event.label, needle) != null) return true;
        if (std.mem.indexOf(u8, event.type_name, needle) != null) return true;
        if (std.mem.indexOf(u8, event.status, needle) != null) return true;
        if (std.mem.indexOf(u8, event.redacted_detail, needle) != null) return true;
    }
    return false;
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

fn formatTextReportFromResult(allocator: std.mem.Allocator, result: FixtureResult, paths: OutputPaths) ![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);
    const report = result.evidence.report;

    try output.appendSlice(allocator, "zigeffect causal NenDB durable history hardening\n");
    try output.print(allocator, "schema: {s}\n", .{nendb_durable_history_schema});
    try output.print(allocator, "schema_version: {d}\n", .{nendb_durable_history_schema_version});
    try output.print(allocator, "generated by: {s}\n", .{generated_by});
    try output.print(allocator, "source branch: {s}\n", .{source_branch});
    try output.print(allocator, "status: {s}\n", .{statusName(result.status)});
    try output.print(allocator, "ready for next branch: {}\n", .{result.ready_for_next_branch});
    try output.print(allocator, "recommendation: {s}\n", .{recommendation});
    try output.print(allocator, "selected next branch: {s}\n", .{next_branch_if_ready});
    try output.print(allocator, "storage adapter: {s}\n", .{report.storage_adapter});
    try output.print(allocator, "backend kind: {s}\n", .{report.backend_kind});
    try output.print(allocator, "retained events: {d}\n", .{report.retained_events});
    try output.print(allocator, "store retained events: {d}\n", .{result.evidence.store_retained_events});
    try output.print(allocator, "writer write count: {d}\n", .{result.evidence.writer_write_count});
    try output.print(allocator, "parent edge write count: {d}\n", .{result.evidence.parent_edge_write_count});
    try output.print(allocator, "flush observed: {}\n", .{report.flush_observed});
    try output.print(allocator, "redaction observed: {}\n", .{report.redaction_observed});
    try output.print(allocator, "lineage query supported: {}\n", .{report.lineage_query_supported});
    try output.print(allocator, "mutation authority: {s}\n", .{report.mutation_authority});
    try output.print(allocator, "Cockroach adapter enabled: {}\n", .{report.cockroach_adapter_enabled});
    try output.print(allocator, "json output: {s}\n", .{paths.json_path});
    try output.print(allocator, "text output: {s}\n", .{paths.text_path});

    try output.appendSlice(allocator, "\nchecks:\n");
    for (result.checks) |check| {
        try output.print(allocator, "- {s}: {s} - {s}\n", .{ check.name, checkStatusName(check.status), check.detail });
    }

    try output.appendSlice(allocator, "\ndenied claims:\n");
    for (denied_claims) |claim| {
        try output.print(allocator, "- {s}\n", .{claim});
    }

    try output.appendSlice(allocator, "\nrequired check names:\n");
    for (required_check_names) |name| {
        try output.print(allocator, "- {s}\n", .{name});
    }

    return output.toOwnedSlice(allocator);
}

fn formatJsonReport(allocator: std.mem.Allocator, result: FixtureResult, paths: OutputPaths) ![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);
    const report = result.evidence.report;

    try output.appendSlice(allocator, "{\n");
    try appendJsonFieldString(&output, allocator, "schema", nendb_durable_history_schema, true);
    try output.print(allocator, "  \"schema_version\": {d},\n", .{nendb_durable_history_schema_version});
    try appendJsonFieldString(&output, allocator, "generated_by", generated_by, true);
    try appendJsonFieldString(&output, allocator, "source_branch", source_branch, true);
    try appendJsonFieldString(&output, allocator, "status", statusName(result.status), true);
    try output.print(allocator, "  \"ready_for_next_branch\": {},\n", .{result.ready_for_next_branch});
    try appendJsonFieldString(&output, allocator, "recommendation", recommendation, true);
    try appendJsonFieldString(&output, allocator, "selected_next_branch", next_branch_if_ready, true);
    try appendJsonFieldString(&output, allocator, "storage_adapter", report.storage_adapter, true);
    try appendJsonFieldString(&output, allocator, "backend_kind", report.backend_kind, true);
    try appendJsonFieldString(&output, allocator, "node_schema", report.node_schema, true);
    try appendJsonFieldString(&output, allocator, "edge_schema", report.edge_schema, true);
    try output.print(allocator, "  \"retained_events\": {d},\n", .{report.retained_events});
    try output.appendSlice(allocator, "  \"max_events\": ");
    try appendOptionalJsonUsize(&output, allocator, report.max_events);
    try output.appendSlice(allocator, ",\n");
    try output.appendSlice(allocator, "  \"ttl_days\": ");
    try appendOptionalJsonU32(&output, allocator, report.ttl_days);
    try output.appendSlice(allocator, ",\n");
    try output.print(allocator, "  \"written_events\": {d},\n", .{report.written_events});
    try output.print(allocator, "  \"failed_events\": {d},\n", .{report.failed_events});
    try output.print(allocator, "  \"flushed_count\": {d},\n", .{report.flushed_count});
    try output.appendSlice(allocator, "  \"oldest_retained_event_id\": ");
    try appendOptionalJsonU64(&output, allocator, report.oldest_retained_event_id);
    try output.appendSlice(allocator, ",\n");
    try output.appendSlice(allocator, "  \"newest_retained_event_id\": ");
    try appendOptionalJsonU64(&output, allocator, report.newest_retained_event_id);
    try output.appendSlice(allocator, ",\n");
    try output.print(allocator, "  \"store_retained_events\": {d},\n", .{result.evidence.store_retained_events});
    try output.print(allocator, "  \"writer_write_count\": {d},\n", .{result.evidence.writer_write_count});
    try output.print(allocator, "  \"parent_edge_write_count\": {d},\n", .{result.evidence.parent_edge_write_count});
    try output.print(allocator, "  \"writer_attached\": {},\n", .{report.writer_attached});
    try output.print(allocator, "  \"flush_required\": {},\n", .{report.flush_required});
    try output.print(allocator, "  \"flush_observed\": {},\n", .{report.flush_observed});
    try output.print(allocator, "  \"redaction_required\": {},\n", .{report.redaction_required});
    try output.print(allocator, "  \"redaction_observed\": {},\n", .{report.redaction_observed});
    try output.print(allocator, "  \"lineage_query_required\": {},\n", .{report.lineage_query_required});
    try output.print(allocator, "  \"lineage_query_supported\": {},\n", .{report.lineage_query_supported});
    try output.print(allocator, "  \"compaction_required\": {},\n", .{report.compaction_required});
    try output.print(allocator, "  \"backup_required\": {},\n", .{report.backup_required});
    try output.print(allocator, "  \"recovery_required\": {},\n", .{report.recovery_required});
    try output.print(allocator, "  \"live_telemetry_enabled\": {},\n", .{report.live_telemetry_enabled});
    try output.print(allocator, "  \"network_send_enabled\": {},\n", .{report.network_send_enabled});
    try output.print(allocator, "  \"durable_write_authority\": {},\n", .{report.durable_write_authority});
    try output.print(allocator, "  \"nendb_write_authority\": {},\n", .{report.nendb_write_authority});
    try output.print(allocator, "  \"cockroach_adapter_enabled\": {},\n", .{report.cockroach_adapter_enabled});
    try appendJsonFieldString(&output, allocator, "mutation_authority", report.mutation_authority, true);
    try appendJsonFieldString(&output, allocator, "json_output", paths.json_path, true);
    try appendJsonFieldString(&output, allocator, "text_output", paths.text_path, true);

    try output.appendSlice(allocator, "  \"checks\": [\n");
    for (result.checks, 0..) |check, index| {
        try output.appendSlice(allocator, "    { \"name\": ");
        try appendJsonString(&output, allocator, check.name);
        try output.appendSlice(allocator, ", \"status\": ");
        try appendJsonString(&output, allocator, checkStatusName(check.status));
        try output.appendSlice(allocator, ", \"detail\": ");
        try appendJsonString(&output, allocator, check.detail);
        try output.appendSlice(allocator, " }");
        try output.appendSlice(allocator, if (index + 1 == result.checks.len) "\n" else ",\n");
    }
    try output.appendSlice(allocator, "  ],\n");

    try appendStringArrayField(&output, allocator, "denied_claims", denied_claims, true);
    try appendStringArrayField(&output, allocator, "required_check_names", required_check_names, false);
    try output.appendSlice(allocator, "}\n");
    return output.toOwnedSlice(allocator);
}

fn writeFakeNendb(raw: ?*anyopaque, write: fx.CausalNendbWrite) anyerror!void {
    const state: *FakeNendbWriter = @ptrCast(@alignCast(raw.?));
    var cloned = try fx.cloneCausalNendbWrite(state.allocator, write);
    errdefer fx.deinitCausalNendbWrite(state.allocator, &cloned);
    try state.writes.append(state.allocator, cloned);
}

fn flushFakeNendb(raw: ?*anyopaque) anyerror!void {
    const state: *FakeNendbWriter = @ptrCast(@alignCast(raw.?));
    state.flush_count += 1;
}

fn statusName(status: FixtureStatus) []const u8 {
    return switch (status) {
        .ready => "ready",
        .blocked => "blocked",
    };
}

fn checkStatusName(status: CheckStatus) []const u8 {
    return switch (status) {
        .pass => "pass",
        .fail => "fail",
    };
}

fn appendJsonFieldString(
    output: *std.ArrayList(u8),
    allocator: std.mem.Allocator,
    name: []const u8,
    value: []const u8,
    comma: bool,
) !void {
    try output.print(allocator, "  \"{s}\": ", .{name});
    try appendJsonString(output, allocator, value);
    try output.appendSlice(allocator, if (comma) ",\n" else "\n");
}

fn appendStringArrayField(
    output: *std.ArrayList(u8),
    allocator: std.mem.Allocator,
    name: []const u8,
    values: []const []const u8,
    comma: bool,
) !void {
    try output.print(allocator, "  \"{s}\": [", .{name});
    for (values, 0..) |value, index| {
        if (index > 0) try output.appendSlice(allocator, ", ");
        try appendJsonString(output, allocator, value);
    }
    try output.appendSlice(allocator, if (comma) "],\n" else "]\n");
}

fn appendOptionalJsonUsize(output: *std.ArrayList(u8), allocator: std.mem.Allocator, value: ?usize) !void {
    if (value) |number| {
        try output.print(allocator, "{d}", .{number});
    } else {
        try output.appendSlice(allocator, "null");
    }
}

fn appendOptionalJsonU32(output: *std.ArrayList(u8), allocator: std.mem.Allocator, value: ?u32) !void {
    if (value) |number| {
        try output.print(allocator, "{d}", .{number});
    } else {
        try output.appendSlice(allocator, "null");
    }
}

fn appendOptionalJsonU64(output: *std.ArrayList(u8), allocator: std.mem.Allocator, value: ?u64) !void {
    if (value) |number| {
        try output.print(allocator, "{d}", .{number});
    } else {
        try output.appendSlice(allocator, "null");
    }
}

fn appendJsonString(output: *std.ArrayList(u8), allocator: std.mem.Allocator, value: []const u8) !void {
    try output.append(allocator, '"');
    for (value) |byte| {
        switch (byte) {
            '"' => try output.appendSlice(allocator, "\\\""),
            '\\' => try output.appendSlice(allocator, "\\\\"),
            '\n' => try output.appendSlice(allocator, "\\n"),
            '\r' => try output.appendSlice(allocator, "\\r"),
            '\t' => try output.appendSlice(allocator, "\\t"),
            else => try output.append(allocator, byte),
        }
    }
    try output.append(allocator, '"');
}

fn writeArtifact(io: std.Io, path: []const u8, contents: []const u8) !void {
    const slash = std.mem.lastIndexOfScalar(u8, path, '/') orelse return error.InvalidArtifactPath;
    const cwd = std.Io.Dir.cwd();
    try cwd.createDirPath(io, path[0..slash]);
    try cwd.writeFile(io, .{ .sub_path = path, .data = contents });
}

fn usage() []const u8 {
    return "usage: zig build causal-nendb-durable-history-hardening -- [--format text|json] [--out-prefix <path-prefix>]\n";
}

fn failUsage(err: anyerror) noreturn {
    std.debug.print("causal-nendb-durable-history-hardening error: {s}\n{s}", .{ @errorName(err), usage() });
    std.process.exit(2);
}

test "nendb durable history constants preserve next handoff" {
    try std.testing.expectEqualStrings("zigeffect.causal.nendb-durable-history.v1", nendb_durable_history_schema);
    try std.testing.expectEqual(@as(u32, 1), nendb_durable_history_schema_version);
    try std.testing.expectEqualStrings("start-agent-query-cross-run-comparison", recommendation);
    try std.testing.expectEqualStrings("codex/zigeffect-causal-agent-query-compare-runs", next_branch_if_ready);
}

test "nendb durable history default fixture is ready and denies production authority" {
    const report = try formatTextReport(std.testing.allocator, .text);
    defer std.testing.allocator.free(report);

    try std.testing.expect(std.mem.indexOf(u8, report, "status: ready") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "selected next branch: codex/zigeffect-causal-agent-query-compare-runs") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "mutation authority: none") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "Cockroach adapter enabled: false") != null);
}

test "nendb durable history json is machine readable" {
    const reports = try formatReports(std.testing.allocator, .{ .format = .json }, true);
    defer reports.deinit(std.testing.allocator);

    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"schema\": \"zigeffect.causal.nendb-durable-history.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"status\": \"ready\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"ready_for_next_branch\": true") != null);
    try std.testing.expect(std.mem.indexOf(u8, reports.json, "\"selected_next_branch\": \"codex/zigeffect-causal-agent-query-compare-runs\"") != null);
}

test "nendb durable history missing redaction evidence blocks readiness" {
    const report = try formatTextReportWithoutRedaction(std.testing.allocator);
    defer std.testing.allocator.free(report);

    try std.testing.expect(std.mem.indexOf(u8, report, "status: blocked") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "redaction-marker-observed: fail") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "ready for next branch: false") != null);
}

test "nendb durable history denied authority fields stay false" {
    const result = try evaluateFixture(std.testing.allocator, true);
    defer result.deinit(std.testing.allocator);
    const report = result.evidence.report;

    try std.testing.expect(result.ready_for_next_branch);
    try std.testing.expect(!report.live_telemetry_enabled);
    try std.testing.expect(!report.network_send_enabled);
    try std.testing.expect(!report.durable_write_authority);
    try std.testing.expect(!report.nendb_write_authority);
    try std.testing.expect(!report.cockroach_adapter_enabled);
    try std.testing.expectEqualStrings("none", report.mutation_authority);
}

test "nendb durable history usage exposes CLI flags" {
    try std.testing.expect(std.mem.indexOf(u8, usage(), "--format text|json") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage(), "--out-prefix <path-prefix>") != null);
}
