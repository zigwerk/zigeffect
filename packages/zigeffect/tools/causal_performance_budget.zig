const std = @import("std");
const fx = @import("zigeffect");
const workbench_session = @import("causal_workbench_session");

pub const performance_budget_schema = "zigeffect.causal.performance-budget.v1";
pub const performance_budget_schema_version: u32 = 1;

const OutputFormat = enum { text, json };

const BudgetEntry = struct {
    id: []const u8,
    category: []const u8,
    description: []const u8,
    budget: []const u8,
    source: []const u8,
    check: []const u8,
    agent_guidance: []const u8,
};

const budget_entries: []const BudgetEntry = &.{
    .{
        .id = "default-store-retention",
        .category = "store-retention",
        .description = "Plain CausalStore remains unbounded unless callers opt into retention.",
        .budget = "max_events=unbounded",
        .source = "CausalStore.init",
        .check = "documented",
        .agent_guidance = "Use bounded options for request paths, long-running jobs, and CI probes.",
    },
    .{
        .id = "app-request-retention",
        .category = "store-retention",
        .description = "Default app request traces keep a bounded retained event set.",
        .budget = "max_events=256",
        .source = "fx.default_request_max_events",
        .check = "passed",
        .agent_guidance = "Treat dropped_events as incomplete retained evidence and cite oldest_retained_event_id.",
    },
    .{
        .id = "app-background-job-retention",
        .category = "store-retention",
        .description = "Default app background-job traces keep a larger bounded retained event set.",
        .budget = "max_events=1024",
        .source = "fx.default_job_max_events",
        .check = "passed",
        .agent_guidance = "Use job defaults for background work; tighten only with explicit evidence.",
    },
    .{
        .id = "app-event-string-bound",
        .category = "event-string-bounds",
        .description = "Default app traces bound event label, type, status, and detail strings.",
        .budget = "max_event_string_bytes=256",
        .source = "fx.default_app_max_event_string_bytes",
        .check = "passed",
        .agent_guidance = "Cite truncated_fields when reasoning depends on event payload text.",
    },
    .{
        .id = "observability-sampling",
        .category = "sampling",
        .description = "Sampling is opt-in and limited to log, metric, and span observability events.",
        .budget = "structural_events=unsampled",
        .source = "CausalStore.shouldRetainEvent",
        .check = "documented",
        .agent_guidance = "Do not assume sampled log, metric, or span evidence is complete.",
    },
    .{
        .id = "workbench-artifact-size",
        .category = "artifact-bounds",
        .description = "Workbench rejects selected artifacts above the bounded read limit before full read.",
        .budget = "max_artifact_bytes=4194304",
        .source = "causal_workbench_session.max_artifact_bytes",
        .check = "passed",
        .agent_guidance = "Split or query large artifacts before opening them in the local workbench.",
    },
    .{
        .id = "workbench-ui-host",
        .category = "workbench",
        .description = "Workbench UI is a SolidJS renderer hosted by webui-dev/zig-webui.",
        .budget = "renderer=SolidJS host=zig-webui mode=read-only",
        .source = "causal-workbench and package scripts",
        .check = "documented",
        .agent_guidance = "Keep workbench changes on the SolidJS plus zig-webui path unless a future adapter is justified.",
    },
    .{
        .id = "ci-artifact-retention",
        .category = "artifact-retention",
        .description = "CI uploads only causal text, JSON, and DOT artifacts for failed causal jobs.",
        .budget = "globs=*.txt,*.json,*.dot retention_days=14",
        .source = ".github/workflows/zigeffect-causal.yml",
        .check = "documented",
        .agent_guidance = "Do not upload the rest of .zig-cache; review artifacts for redaction before sharing.",
    },
    .{
        .id = "backend-sink-failure-posture",
        .category = "backend-sinks",
        .description = "Backend adapters are sinks; deterministic store writes remain authoritative.",
        .budget = "backend_failures=nonfatal failed_writes=reported",
        .source = "CausalStore.record and backend conformance tests",
        .check = "documented",
        .agent_guidance = "If failed_writes is nonzero, backend durability/export evidence is incomplete.",
    },
};

const release_review: []const []const u8 = &.{
    "Document retained event count changes.",
    "Document event string bound or truncation changes.",
    "Document sampling behavior changes.",
    "Document backend emission or failure-posture changes.",
    "Document artifact schema, compatibility, or migration changes.",
    "Document workbench artifact-size, bridge, host, or renderer changes.",
    "Document CI upload glob or retention changes.",
};

const verification_commands: []const []const u8 = &.{
    "cd packages/zigeffect",
    "zig build causal-performance-budget",
    "zig build causal-performance-budget -- --format json",
    "zig build causal-schema-governance",
    "zig build examples",
    "zig build test",
    "cd ../..",
    "bun run check",
    "bun run zig:test",
    "git diff --check",
};

const non_goals: []const []const u8 = &.{
    "wall-clock latency gates",
    "throughput benchmarks",
    "production capacity planning",
    "production dashboards",
    "alerting or paging",
    "RBAC or encryption-at-rest policy",
    "source or config mutation authority",
    "React workbench support",
    "Cockroach adapter work",
};

fn usage() []const u8 {
    return
        \\usage:
        \\  zig build causal-performance-budget
        \\  zig build causal-performance-budget -- --format text
        \\  zig build causal-performance-budget -- --format json
        \\
        \\formats:
        \\  --format text|json
        \\
    ;
}

fn parseOptions(args: []const []const u8) !OutputFormat {
    if (args.len == 1) return .text;
    if (args.len == 3 and std.mem.eql(u8, args[1], "--format")) {
        if (std.mem.eql(u8, args[2], "text")) return .text;
        if (std.mem.eql(u8, args[2], "json")) return .json;
        return error.UnknownFormat;
    }
    if (args.len == 2 and std.mem.eql(u8, args[1], "--format")) return error.MissingFormat;
    return error.UnknownFlag;
}

pub fn budgetEntries() []const BudgetEntry {
    return budget_entries;
}

fn formatPerformanceBudgetText(allocator: std.mem.Allocator) ![]const u8 {
    try validateBudgetConstants();

    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "zigeffect causal performance budget\n");
    try output.print(allocator, "schema: {s}\n", .{performance_budget_schema});
    try output.print(allocator, "schema_version: {d}\n", .{performance_budget_schema_version});
    try output.appendSlice(allocator, "status: current\n");
    try output.appendSlice(allocator, "generated_by: causal-performance-budget\n\n");

    try output.appendSlice(allocator, "budgets:\n");
    for (budgetEntries()) |entry| {
        try output.print(allocator, "- {s}\n", .{entry.id});
        try output.print(allocator, "  category: {s}\n", .{entry.category});
        try output.print(allocator, "  description: {s}\n", .{entry.description});
        try output.print(allocator, "  budget: {s}\n", .{entry.budget});
        try output.print(allocator, "  source: {s}\n", .{entry.source});
        try output.print(allocator, "  check: {s}\n", .{entry.check});
        try output.print(allocator, "  agent guidance: {s}\n", .{entry.agent_guidance});
    }

    try output.appendSlice(allocator, "\nrelease checklist:\n");
    for (release_review) |item| {
        try output.print(allocator, "- {s}\n", .{item});
    }

    try output.appendSlice(allocator, "\nverification commands:\n");
    for (verification_commands) |command| {
        try output.print(allocator, "- {s}\n", .{command});
    }

    try output.appendSlice(allocator, "\nnon-goals:\n");
    for (non_goals) |item| {
        try output.print(allocator, "- {s}\n", .{item});
    }

    return output.toOwnedSlice(allocator);
}

fn formatPerformanceBudgetJson(allocator: std.mem.Allocator) ![]const u8 {
    try validateBudgetConstants();

    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "{\n");
    try output.appendSlice(allocator, "  \"schema\": ");
    try appendJsonString(allocator, &output, performance_budget_schema);
    try output.appendSlice(allocator, ",\n");
    try output.print(allocator, "  \"schema_version\": {d},\n", .{performance_budget_schema_version});
    try output.appendSlice(allocator, "  \"status\": \"current\",\n");
    try output.appendSlice(allocator, "  \"generated_by\": \"causal-performance-budget\",\n");
    try output.appendSlice(allocator, "  \"budgets\": [\n");

    for (budgetEntries(), 0..) |entry, index| {
        try output.appendSlice(allocator, "    {\n");
        try appendJsonProperty(allocator, &output, "id", entry.id, true);
        try appendJsonProperty(allocator, &output, "category", entry.category, true);
        try appendJsonProperty(allocator, &output, "description", entry.description, true);
        try appendJsonProperty(allocator, &output, "budget", entry.budget, true);
        try appendJsonProperty(allocator, &output, "source", entry.source, true);
        try appendJsonProperty(allocator, &output, "check", entry.check, true);
        try appendJsonProperty(allocator, &output, "agent_guidance", entry.agent_guidance, false);
        try output.appendSlice(allocator, "    }");
        if (index + 1 < budgetEntries().len) try output.append(allocator, ',');
        try output.append(allocator, '\n');
    }

    try output.appendSlice(allocator, "  ],\n");
    try output.appendSlice(allocator, "  \"release_review\": ");
    try appendStringArray(allocator, &output, release_review);
    try output.appendSlice(allocator, ",\n");
    try output.appendSlice(allocator, "  \"verification_commands\": ");
    try appendStringArray(allocator, &output, verification_commands);
    try output.appendSlice(allocator, ",\n");
    try output.appendSlice(allocator, "  \"non_goals\": ");
    try appendStringArray(allocator, &output, non_goals);
    try output.appendSlice(allocator, "\n}\n");

    return output.toOwnedSlice(allocator);
}

pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    const format = parseOptions(args) catch |err| failUsage(err);
    const report = switch (format) {
        .text => try formatPerformanceBudgetText(init.gpa),
        .json => try formatPerformanceBudgetJson(init.gpa),
    };
    defer init.gpa.free(report);

    std.debug.print("{s}", .{report});
}

fn failUsage(err: anyerror) noreturn {
    std.debug.print("causal-performance-budget error: {s}\n{s}", .{ @errorName(err), usage() });
    std.process.exit(2);
}

fn validateBudgetConstants() !void {
    if (fx.default_request_max_events != 256) return error.CausalPerformanceBudgetDrift;
    if (fx.default_job_max_events != 1024) return error.CausalPerformanceBudgetDrift;
    if (fx.default_app_max_event_string_bytes != 256) return error.CausalPerformanceBudgetDrift;
    if (workbench_session.max_artifact_bytes != 4 * 1024 * 1024) return error.CausalPerformanceBudgetDrift;
}

fn appendJsonProperty(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    name: []const u8,
    value: []const u8,
    comma: bool,
) !void {
    try output.appendSlice(allocator, "      ");
    try appendJsonString(allocator, output, name);
    try output.appendSlice(allocator, ": ");
    try appendJsonString(allocator, output, value);
    if (comma) try output.append(allocator, ',');
    try output.append(allocator, '\n');
}

fn appendStringArray(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    values: []const []const u8,
) !void {
    try output.append(allocator, '[');
    for (values, 0..) |value, index| {
        if (index != 0) try output.appendSlice(allocator, ", ");
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
        else => try output.append(allocator, byte),
    };
    try output.append(allocator, '"');
}

fn expectBudget(id: []const u8) !void {
    for (budgetEntries()) |entry| {
        if (std.mem.eql(u8, entry.id, id)) return;
    }
    return error.MissingBudgetEntry;
}

test "performance budget usage names command and formats" {
    try std.testing.expect(std.mem.indexOf(u8, usage(), "causal-performance-budget") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage(), "--format text|json") != null);
    try std.testing.expectEqualStrings("zigeffect.causal.performance-budget.v1", performance_budget_schema);
}

test "performance budget inventory includes checked runtime constants" {
    try std.testing.expectEqual(@as(usize, 9), budgetEntries().len);
    try expectBudget("app-request-retention");
    try expectBudget("app-background-job-retention");
    try expectBudget("app-event-string-bound");
    try expectBudget("workbench-artifact-size");
}

test "performance budget constants align with runtime defaults" {
    try std.testing.expectEqual(@as(usize, 256), fx.default_request_max_events);
    try std.testing.expectEqual(@as(usize, 1024), fx.default_job_max_events);
    try std.testing.expectEqual(@as(usize, 256), fx.default_app_max_event_string_bytes);
    try std.testing.expectEqual(@as(usize, 4 * 1024 * 1024), workbench_session.max_artifact_bytes);
}

test "performance budget text report includes release checklist" {
    const report = try formatPerformanceBudgetText(std.testing.allocator);
    defer std.testing.allocator.free(report);

    try std.testing.expect(std.mem.indexOf(u8, report, "zigeffect causal performance budget") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "schema: zigeffect.causal.performance-budget.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "app-request-retention") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "SolidJS renderer hosted by webui-dev/zig-webui") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "release checklist:") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "zig build causal-performance-budget -- --format json") != null);
}

test "performance budget json report is machine readable" {
    const report = try formatPerformanceBudgetJson(std.testing.allocator);
    defer std.testing.allocator.free(report);

    try std.testing.expect(std.mem.indexOf(u8, report, "\"schema\": \"zigeffect.causal.performance-budget.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"schema_version\": 1") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"id\": \"app-request-retention\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"verification_commands\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "\"non_goals\"") != null);
}

test "performance budget parses format options" {
    try std.testing.expectEqual(OutputFormat.text, try parseOptions(&.{"zigeffect-causal-performance-budget"}));
    try std.testing.expectEqual(OutputFormat.text, try parseOptions(&.{ "zigeffect-causal-performance-budget", "--format", "text" }));
    try std.testing.expectEqual(OutputFormat.json, try parseOptions(&.{ "zigeffect-causal-performance-budget", "--format", "json" }));
    try std.testing.expectError(error.UnknownFormat, parseOptions(&.{ "zigeffect-causal-performance-budget", "--format", "yaml" }));
    try std.testing.expectError(error.UnknownFlag, parseOptions(&.{ "zigeffect-causal-performance-budget", "--json" }));
}
