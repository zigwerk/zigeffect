const std = @import("std");
const fx = @import("zigeffect");

fn event(
    sequence: fx.workflow.JournalSequence,
    kind: fx.workflow.WorkflowEventKind,
    key: []const u8,
) fx.workflow.WorkflowEvent {
    return .{
        .sequence = sequence,
        .kind = kind,
        .workflow_id = 41,
        .execution_id = 410,
        .name = "storage-conformance",
        .status = @tagName(kind),
        .idempotency_key = key,
    };
}

pub fn appendStandardJournalEvents(store: fx.workflow.JournalStore) !void {
    _ = try store.append(.{ .expected_next_sequence = 1, .event = event(1, .workflow_started, "journal-1") });
    _ = try store.append(.{ .expected_next_sequence = 2, .event = event(2, .step_started, "journal-2") });
    _ = try store.append(.{ .expected_next_sequence = 3, .event = event(3, .workflow_completed, "journal-3") });
}

pub fn expectStandardJournalEvents(store: fx.workflow.JournalStore) !void {
    var all = try store.readAll(std.testing.allocator);
    defer all.deinit();
    try std.testing.expectEqual(@as(usize, 3), all.events.len);
    try std.testing.expectEqual(@as(fx.workflow.JournalSequence, 1), all.events[0].sequence);
    try std.testing.expectEqual(fx.workflow.WorkflowEventKind.workflow_started, all.events[0].kind);
    try std.testing.expectEqual(fx.workflow.WorkflowEventKind.workflow_completed, all.events[2].kind);

    var from_two = try store.readFromSequence(std.testing.allocator, 2);
    defer from_two.deinit();
    try std.testing.expectEqual(@as(usize, 2), from_two.events.len);
    try std.testing.expectEqual(@as(fx.workflow.JournalSequence, 2), from_two.events[0].sequence);

    var latest = try store.latestState(std.testing.allocator);
    defer latest.deinit();
    try std.testing.expectEqual(@as(fx.workflow.JournalSequence, 3), latest.last_sequence);
}

pub fn expectJournalStoreConformance(store: fx.workflow.JournalStore) !void {
    try appendStandardJournalEvents(store);
    try expectStandardJournalEvents(store);

    try std.testing.expectError(error.SequenceConflict, store.append(.{
        .expected_next_sequence = 99,
        .event = event(4, .step_completed, "journal-conflict"),
    }));
    try std.testing.expectError(error.DuplicateEvent, store.append(.{
        .expected_next_sequence = 4,
        .event = event(4, .step_completed, "journal-3"),
    }));

    store.reset();
    var after_reset = try store.readAll(std.testing.allocator);
    defer after_reset.deinit();
    try std.testing.expectEqual(@as(usize, 0), after_reset.events.len);
}
