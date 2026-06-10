const std = @import("std");
const workflow = @import("../workflow/root.zig");
const cluster = @import("../cluster/root.zig");

pub const performance_benchmark_schema = "zigeffect.performance.benchmark.v1";
pub const performance_benchmark_schema_version: u32 = 1;

pub const PerformanceThresholdViolationKind = enum {
    journal_events,
    journal_bytes,
    mailbox_messages,
    mailbox_peak_pending,
};

pub const PerformanceThresholdViolation = struct {
    kind: PerformanceThresholdViolationKind,
    actual: usize,
    threshold: usize,
};

pub const PerformanceThresholds = struct {
    max_journal_events: ?usize = 1_024,
    max_journal_bytes: ?usize = 1_000_000,
    max_mailbox_messages: ?usize = 4_096,
    max_mailbox_peak_pending: ?usize = 4_096,
};

pub const PerformanceBenchmarkOptions = struct {
    journal_events: usize = 128,
    mailbox_messages: usize = 256,
    entity_count: usize = 8,
    thresholds: PerformanceThresholds = .{},
};

pub const JournalBenchmarkReport = struct {
    events_appended: usize = 0,
    events_replayed: usize = 0,
    serialized_bytes: usize = 0,
    state_rows: usize = 0,
};

pub const MailboxBenchmarkReport = struct {
    messages_offered: usize = 0,
    messages_taken: usize = 0,
    entity_count: usize = 0,
    peak_pending: usize = 0,
};

pub const PerformanceBenchmarkReport = struct {
    allocator: std.mem.Allocator,
    schema: []const u8 = performance_benchmark_schema,
    schema_version: u32 = performance_benchmark_schema_version,
    journal: JournalBenchmarkReport,
    mailbox: MailboxBenchmarkReport,
    thresholds: PerformanceThresholds,
    threshold_violations: []PerformanceThresholdViolation,

    pub fn deinit(self: *PerformanceBenchmarkReport) void {
        self.allocator.free(self.threshold_violations);
    }

    pub fn passed(self: *const PerformanceBenchmarkReport) bool {
        return self.threshold_violations.len == 0;
    }
};

pub fn runPerformanceBenchmarks(
    allocator: std.mem.Allocator,
    options: PerformanceBenchmarkOptions,
) !PerformanceBenchmarkReport {
    const journal_report = try runJournalBenchmark(allocator, options.journal_events);
    const mailbox_report = try runMailboxBenchmark(allocator, options.mailbox_messages, options.entity_count);
    const violations = try collectThresholdViolations(allocator, journal_report, mailbox_report, options.thresholds);
    errdefer allocator.free(violations);

    return .{
        .allocator = allocator,
        .journal = journal_report,
        .mailbox = mailbox_report,
        .thresholds = options.thresholds,
        .threshold_violations = violations,
    };
}

pub fn formatPerformanceBenchmarkText(
    allocator: std.mem.Allocator,
    report: PerformanceBenchmarkReport,
) std.mem.Allocator.Error![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.print(allocator, "schema: {s}\n", .{report.schema});
    try output.print(allocator, "schema_version: {d}\n", .{report.schema_version});
    try output.print(allocator, "journal.events_appended: {d}\n", .{report.journal.events_appended});
    try output.print(allocator, "journal.events_replayed: {d}\n", .{report.journal.events_replayed});
    try output.print(allocator, "journal.serialized_bytes: {d}\n", .{report.journal.serialized_bytes});
    try output.print(allocator, "journal.state_rows: {d}\n", .{report.journal.state_rows});
    try output.print(allocator, "mailbox.messages_offered: {d}\n", .{report.mailbox.messages_offered});
    try output.print(allocator, "mailbox.messages_taken: {d}\n", .{report.mailbox.messages_taken});
    try output.print(allocator, "mailbox.entity_count: {d}\n", .{report.mailbox.entity_count});
    try output.print(allocator, "mailbox.peak_pending: {d}\n", .{report.mailbox.peak_pending});
    try output.print(allocator, "threshold_violations: {d}\n", .{report.threshold_violations.len});
    try output.print(allocator, "verdict: {s}\n", .{if (report.passed()) "pass" else "fail"});
    for (report.threshold_violations) |violation| {
        try output.print(
            allocator,
            "violation.{s}: actual={d} threshold={d}\n",
            .{ @tagName(violation.kind), violation.actual, violation.threshold },
        );
    }

    return output.toOwnedSlice(allocator);
}

pub fn formatPerformanceBenchmarkJson(
    allocator: std.mem.Allocator,
    report: PerformanceBenchmarkReport,
) std.mem.Allocator.Error![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.print(
        allocator,
        "{{\"schema\":\"{s}\",\"schema_version\":{d},\"journal\":{{\"events_appended\":{d},\"events_replayed\":{d},\"serialized_bytes\":{d},\"state_rows\":{d}}},\"mailbox\":{{\"messages_offered\":{d},\"messages_taken\":{d},\"entity_count\":{d},\"peak_pending\":{d}}},\"threshold_violations\":[",
        .{
            report.schema,
            report.schema_version,
            report.journal.events_appended,
            report.journal.events_replayed,
            report.journal.serialized_bytes,
            report.journal.state_rows,
            report.mailbox.messages_offered,
            report.mailbox.messages_taken,
            report.mailbox.entity_count,
            report.mailbox.peak_pending,
        },
    );
    for (report.threshold_violations, 0..) |violation, index| {
        if (index != 0) try output.append(allocator, ',');
        try output.print(
            allocator,
            "{{\"kind\":\"{s}\",\"actual\":{d},\"threshold\":{d}}}",
            .{ @tagName(violation.kind), violation.actual, violation.threshold },
        );
    }
    try output.print(allocator, "],\"verdict\":\"{s}\"}}", .{if (report.passed()) "pass" else "fail"});

    return output.toOwnedSlice(allocator);
}

fn runJournalBenchmark(allocator: std.mem.Allocator, event_count: usize) !JournalBenchmarkReport {
    var store = workflow.InMemoryJournalStore.init(allocator);
    defer store.deinit();
    const journal = store.asJournalStore();

    var serialized_bytes: usize = 0;
    var index: usize = 0;
    while (index < event_count) : (index += 1) {
        const sequence: workflow.JournalSequence = @intCast(index + 1);
        const key = try std.fmt.allocPrint(allocator, "performance-journal-{d}", .{sequence});
        defer allocator.free(key);
        const event = workflow.WorkflowEvent{
            .sequence = sequence,
            .kind = if (index == 0) .workflow_started else .step_started,
            .workflow_id = 9_001,
            .execution_id = 9_002,
            .name = "performance-journal",
            .status = "recorded",
            .idempotency_key = key,
        };

        const row = try workflow.formatWorkflowEventJson(allocator, event);
        defer allocator.free(row);
        serialized_bytes += row.len;
        _ = try journal.append(.{ .event = event });
    }

    var state = try journal.latestState(allocator);
    defer state.deinit();

    return .{
        .events_appended = event_count,
        .events_replayed = @intCast(state.last_sequence),
        .serialized_bytes = serialized_bytes,
        .state_rows = state.activities.items.len +
            state.timers.items.len +
            state.deferreds.items.len +
            state.queues.items.len +
            state.compensations.items.len,
    };
}

fn runMailboxBenchmark(
    allocator: std.mem.Allocator,
    message_count: usize,
    requested_entity_count: usize,
) !MailboxBenchmarkReport {
    var store = cluster.LocalMailboxStore.init(allocator);
    defer store.deinit();

    const entity_count = @max(requested_entity_count, 1);
    var peak_pending: usize = 0;
    var offered: usize = 0;
    var index: usize = 0;
    while (index < message_count) : (index += 1) {
        const address = try benchmarkAddress(index % entity_count);
        const payload = try std.fmt.allocPrint(allocator, "message-{d}", .{index});
        defer allocator.free(payload);
        const returned = try store.offer(.{
            .kind = .tell,
            .address = address,
            .payload_type_name = "text",
            .payload = payload,
        });
        defer cluster.deinitEntityEnvelope(allocator, returned);
        offered += 1;
        peak_pending = @max(peak_pending, store.stats().total_pending);
    }

    var taken: usize = 0;
    index = 0;
    while (index < message_count) : (index += 1) {
        const address = try benchmarkAddress(index % entity_count);
        const item = try store.take(address);
        defer cluster.deinitEntityEnvelope(allocator, item);
        taken += 1;
    }

    return .{
        .messages_offered = offered,
        .messages_taken = taken,
        .entity_count = entity_count,
        .peak_pending = peak_pending,
    };
}

fn collectThresholdViolations(
    allocator: std.mem.Allocator,
    journal: JournalBenchmarkReport,
    mailbox: MailboxBenchmarkReport,
    thresholds: PerformanceThresholds,
) std.mem.Allocator.Error![]PerformanceThresholdViolation {
    var violations = std.ArrayList(PerformanceThresholdViolation).empty;
    errdefer violations.deinit(allocator);

    try appendViolation(&violations, allocator, .journal_events, journal.events_appended, thresholds.max_journal_events);
    try appendViolation(&violations, allocator, .journal_bytes, journal.serialized_bytes, thresholds.max_journal_bytes);
    try appendViolation(&violations, allocator, .mailbox_messages, mailbox.messages_offered, thresholds.max_mailbox_messages);
    try appendViolation(&violations, allocator, .mailbox_peak_pending, mailbox.peak_pending, thresholds.max_mailbox_peak_pending);

    return violations.toOwnedSlice(allocator);
}

fn appendViolation(
    violations: *std.ArrayList(PerformanceThresholdViolation),
    allocator: std.mem.Allocator,
    kind: PerformanceThresholdViolationKind,
    actual: usize,
    maybe_threshold: ?usize,
) std.mem.Allocator.Error!void {
    const threshold = maybe_threshold orelse return;
    if (actual <= threshold) return;
    try violations.append(allocator, .{
        .kind = kind,
        .actual = actual,
        .threshold = threshold,
    });
}

fn benchmarkAddress(index: usize) !cluster.EntityAddress {
    var key_buffer: [32]u8 = undefined;
    const key = try std.fmt.bufPrint(&key_buffer, "entity-{d}", .{index});
    return cluster.entityAddress("performance-entity", key);
}
