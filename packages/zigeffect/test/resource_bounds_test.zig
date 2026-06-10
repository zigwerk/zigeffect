const std = @import("std");
const fx = @import("zigeffect");

fn workflowEvent(
    sequence: fx.workflow.JournalSequence,
    kind: fx.workflow.WorkflowEventKind,
    key: []const u8,
) fx.workflow.WorkflowEvent {
    return .{
        .sequence = sequence,
        .kind = kind,
        .workflow_id = 43,
        .execution_id = 430,
        .name = "resource-bound",
        .status = @tagName(kind),
        .idempotency_key = key,
    };
}

test "in-memory journal store enforces opt-in event bounds" {
    var store = fx.workflow.InMemoryJournalStore.initBounded(std.testing.allocator, .{ .max_events = 2 });
    defer store.deinit();
    const journal = store.asJournalStore();

    _ = try journal.append(.{ .event = workflowEvent(1, .workflow_started, "bound-1") });
    _ = try journal.append(.{ .event = workflowEvent(2, .step_started, "bound-2") });
    try std.testing.expectError(error.EventLimitExceeded, journal.append(.{
        .event = workflowEvent(3, .step_completed, "bound-3"),
    }));

    const stats = store.capacityStats();
    try std.testing.expectEqual(@as(usize, 2), stats.event_count);
    try std.testing.expectEqual(@as(?usize, 2), stats.max_events);
    try std.testing.expectEqual(@as(?usize, 0), stats.remaining_events);
}

test "file journal store enforces opt-in replay tail bounds" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    var store = try fx.workflow.FileJournalStore.open(std.testing.allocator, std.testing.io, &tmp.dir, .{
        .max_in_memory_events = 1,
    });
    defer store.deinit();
    const journal = store.asJournalStore();

    _ = try journal.append(.{ .event = workflowEvent(1, .workflow_started, "file-bound-1") });
    try std.testing.expectError(error.EventLimitExceeded, journal.append(.{
        .event = workflowEvent(2, .step_started, "file-bound-2"),
    }));
}
