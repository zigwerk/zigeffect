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
        .workflow_id = 430,
        .execution_id = 431,
        .name = "snapshot-frequency",
        .status = @tagName(kind),
        .idempotency_key = key,
    };
}

test "workflow snapshot frequency decides from active tail length" {
    const disabled = fx.workflow.WorkflowSnapshotFrequency{};
    try std.testing.expect(!disabled.shouldSnapshot(10, 0));

    const every_five = fx.workflow.WorkflowSnapshotFrequency{ .every_events = 5 };
    try std.testing.expect(every_five.shouldSnapshot(5, 0));
    try std.testing.expect(every_five.shouldSnapshot(10, 0));
    try std.testing.expect(!every_five.shouldSnapshot(4, 0));
    try std.testing.expect(!every_five.shouldSnapshot(12, 10));
    try std.testing.expect(every_five.shouldSnapshot(15, 10));
}

test "file journal writes replay snapshot only when frequency is due" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    var store = try fx.workflow.FileJournalStore.open(std.testing.allocator, std.testing.io, &tmp.dir, .{
        .snapshot_frequency = .{ .every_events = 2 },
    });
    defer store.deinit();
    const journal = store.asJournalStore();

    _ = try journal.append(.{ .event = event(1, .workflow_started, "snapshot-1") });
    try std.testing.expect(!store.snapshotDue());
    try std.testing.expect((try store.writeReplaySnapshotIfDue()) == null);

    _ = try journal.append(.{ .event = event(2, .step_started, "snapshot-2") });
    try std.testing.expect(store.snapshotDue());
    const publication = (try store.writeReplaySnapshotIfDue()) orelse return error.ExpectedSnapshotPublication;
    defer publication.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(fx.workflow.JournalSequence, 2), publication.last_sequence);
    try std.testing.expect(!store.snapshotDue());

    _ = try journal.append(.{ .event = event(3, .step_completed, "snapshot-3") });
    try std.testing.expect(!store.snapshotDue());
}
