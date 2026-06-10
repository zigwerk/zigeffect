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

fn entityEnvelope(address: fx.EntityAddress, payload: []const u8) fx.EntityEnvelope {
    return .{
        .kind = .tell,
        .address = address,
        .payload_type_name = "text",
        .payload = payload,
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

test "local mailbox store enforces opt-in total pending bounds" {
    var store = fx.LocalMailboxStore.initBounded(std.testing.allocator, .{ .max_total_pending = 2 });
    defer store.deinit();

    const first_address = fx.entityAddress("mailbox-bound", "one");
    const second_address = fx.entityAddress("mailbox-bound", "two");
    const third_address = fx.entityAddress("mailbox-bound", "three");

    const first = try store.offer(entityEnvelope(first_address, "one"));
    defer fx.deinitEntityEnvelope(std.testing.allocator, first);
    const second = try store.offer(entityEnvelope(second_address, "two"));
    defer fx.deinitEntityEnvelope(std.testing.allocator, second);

    try std.testing.expectError(error.MailboxFull, store.offer(entityEnvelope(third_address, "three")));

    const stats = store.stats();
    try std.testing.expectEqual(@as(usize, 2), stats.mailbox_count);
    try std.testing.expectEqual(@as(usize, 2), stats.total_pending);
    try std.testing.expectEqual(@as(usize, 1), stats.max_mailbox_pending);
    try std.testing.expectEqual(@as(?usize, 2), stats.max_total_pending);
    try std.testing.expectEqual(@as(?usize, null), stats.max_pending_per_mailbox);
    try std.testing.expectEqual(@as(usize, 2), stats.backpressured_mailboxes);
}

test "local mailbox store enforces opt-in per-mailbox pending bounds" {
    var store = fx.LocalMailboxStore.initBounded(std.testing.allocator, .{ .max_pending_per_mailbox = 1 });
    defer store.deinit();

    const address = fx.entityAddress("mailbox-bound", "one");
    const first = try store.offer(entityEnvelope(address, "one"));
    defer fx.deinitEntityEnvelope(std.testing.allocator, first);

    try std.testing.expectError(error.MailboxFull, store.offer(entityEnvelope(address, "two")));

    const stats = store.stats();
    try std.testing.expectEqual(@as(usize, 1), stats.mailbox_count);
    try std.testing.expectEqual(@as(usize, 1), stats.total_pending);
    try std.testing.expectEqual(@as(usize, 1), stats.max_mailbox_pending);
    try std.testing.expectEqual(@as(?usize, null), stats.max_total_pending);
    try std.testing.expectEqual(@as(?usize, 1), stats.max_pending_per_mailbox);
    try std.testing.expectEqual(@as(usize, 1), stats.backpressured_mailboxes);
}

test "runtime queue stats expose backpressure state" {
    var queue = fx.runtime.Queue(u8).bounded(std.testing.allocator, 2);
    defer queue.deinit();

    var stats = queue.stats();
    try std.testing.expectEqual(@as(usize, 0), stats.len);
    try std.testing.expectEqual(@as(?usize, 2), stats.capacity);
    try std.testing.expectEqual(@as(?usize, 2), stats.remaining_capacity);
    try std.testing.expectEqual(fx.QueueOfferState.ready, stats.offer_state);
    try std.testing.expectEqual(fx.QueueTakeState.empty, stats.take_state);

    try queue.offer(1);
    try queue.offer(2);

    stats = queue.stats();
    try std.testing.expectEqual(@as(usize, 2), stats.len);
    try std.testing.expectEqual(@as(?usize, 0), stats.remaining_capacity);
    try std.testing.expectEqual(fx.QueueOfferState.backpressured, stats.offer_state);
    try std.testing.expectEqual(fx.QueueTakeState.ready, stats.take_state);
}
