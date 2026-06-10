const std = @import("std");
const fx = @import("zigeffect");

test "performance benchmark reports deterministic journal and mailbox counters" {
    var report = try fx.runPerformanceBenchmarks(std.testing.allocator, .{
        .journal_events = 4,
        .mailbox_messages = 6,
        .entity_count = 2,
    });
    defer report.deinit();

    try std.testing.expectEqual(@as(usize, 4), report.journal.events_appended);
    try std.testing.expectEqual(@as(usize, 4), report.journal.events_replayed);
    try std.testing.expect(report.journal.serialized_bytes > 0);
    try std.testing.expectEqual(@as(usize, 6), report.mailbox.messages_offered);
    try std.testing.expectEqual(@as(usize, 6), report.mailbox.messages_taken);
    try std.testing.expectEqual(@as(usize, 2), report.mailbox.entity_count);
    try std.testing.expectEqual(@as(usize, 0), report.threshold_violations.len);
}

test "performance benchmark reports threshold violations deterministically" {
    var report = try fx.runPerformanceBenchmarks(std.testing.allocator, .{
        .journal_events = 4,
        .mailbox_messages = 3,
        .entity_count = 1,
        .thresholds = .{
            .max_journal_events = 2,
            .max_mailbox_messages = 2,
        },
    });
    defer report.deinit();

    try std.testing.expectEqual(@as(usize, 2), report.threshold_violations.len);
    try std.testing.expectEqual(fx.PerformanceThresholdViolationKind.journal_events, report.threshold_violations[0].kind);
    try std.testing.expectEqual(fx.PerformanceThresholdViolationKind.mailbox_messages, report.threshold_violations[1].kind);
}

test "performance benchmark formats stable text and json reports" {
    var report = try fx.runPerformanceBenchmarks(std.testing.allocator, .{
        .journal_events = 4,
        .mailbox_messages = 6,
        .entity_count = 2,
    });
    defer report.deinit();

    const text = try fx.formatPerformanceBenchmarkText(std.testing.allocator, report);
    defer std.testing.allocator.free(text);
    try std.testing.expect(std.mem.indexOf(u8, text, "schema: zigeffect.performance.benchmark.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "journal.events_appended: 4") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "mailbox.messages_offered: 6") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "verdict: pass") != null);

    const json = try fx.formatPerformanceBenchmarkJson(std.testing.allocator, report);
    defer std.testing.allocator.free(json);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"schema\":\"zigeffect.performance.benchmark.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"events_appended\":4") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"messages_offered\":6") != null);
}
