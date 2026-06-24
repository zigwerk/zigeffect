const std = @import("std");
const fx = @import("zigeffect");

test "causal concurrency recorder emits race winner and loser facts" {
    var store = fx.CausalStore.init(std.testing.allocator);
    defer store.deinit();

    var recorder = fx.CausalConcurrencyRecorder.init(&store, .{ .run_id = 7, .scope_id = 8 });
    const race = try recorder.recordRaceStarted(.{ .schedule_id = 9, .label = "fetch race" });
    _ = try recorder.recordRaceWinner(.{ .schedule_id = 9, .fiber_id = 10, .parent_id = race });
    _ = try recorder.recordRaceLoserInterrupted(.{ .schedule_id = 9, .fiber_id = 11, .parent_id = race, .cause_event_id = race });

    var snapshot = try store.snapshot(std.testing.allocator);
    defer snapshot.deinit();
    try std.testing.expectEqual(fx.CausalEventKind.race_started, snapshot.events[0].kind);
    try std.testing.expectEqual(fx.CausalEventKind.race_winner_selected, snapshot.events[1].kind);
    try std.testing.expectEqual(fx.CausalEventKind.race_loser_interrupted, snapshot.events[2].kind);
    try std.testing.expectEqual(@as(?u64, 11), snapshot.events[2].fiber_id);
}

test "causal concurrency recorder emits both and STM retry facts" {
    var store = fx.CausalStore.init(std.testing.allocator);
    defer store.deinit();

    var recorder = fx.CausalConcurrencyRecorder.init(&store, .{ .run_id = 21, .scope_id = 22 });
    const both = try recorder.recordBothStarted(.{ .schedule_id = 23, .label = "pair" });
    _ = try recorder.recordBothCompleted(.{ .schedule_id = 23, .parent_id = both });
    const started = try recorder.recordStmTransactionStarted(.{ .schedule_id = 24, .label = "transfer" });
    const conflict = try recorder.recordStmConflictDetected(.{ .schedule_id = 24, .parent_id = started, .cause_event_id = started });
    _ = try recorder.recordStmRetryScheduled(.{ .schedule_id = 24, .parent_id = conflict, .cause_event_id = conflict });
    _ = try recorder.recordStmTransactionCommitted(.{ .schedule_id = 24, .parent_id = conflict });

    var snapshot = try store.snapshot(std.testing.allocator);
    defer snapshot.deinit();
    try std.testing.expectEqual(fx.CausalEventKind.both_started, snapshot.events[0].kind);
    try std.testing.expectEqual(fx.CausalEventKind.both_completed, snapshot.events[1].kind);
    try std.testing.expectEqual(fx.CausalEventKind.stm_transaction_started, snapshot.events[2].kind);
    try std.testing.expectEqual(fx.CausalEventKind.stm_conflict_detected, snapshot.events[3].kind);
    try std.testing.expectEqual(fx.CausalEventKind.stm_retry_scheduled, snapshot.events[4].kind);
    try std.testing.expectEqual(fx.CausalEventKind.stm_transaction_committed, snapshot.events[5].kind);
}
