const std = @import("std");
const fx = @import("zigeffect");

fn expectWorkflowReplayStatesEqual(expected: *const fx.workflow.WorkflowReplayState, actual: *const fx.workflow.WorkflowReplayState) !void {
    try std.testing.expectEqual(expected.workflow_status, actual.workflow_status);
    try std.testing.expectEqual(expected.workflow_id, actual.workflow_id);
    try std.testing.expectEqual(expected.execution_id, actual.execution_id);
    try std.testing.expectEqual(expected.last_sequence, actual.last_sequence);

    try std.testing.expectEqual(expected.activities.items.len, actual.activities.items.len);
    for (expected.activities.items, actual.activities.items) |expected_row, actual_row| {
        try std.testing.expectEqual(expected_row.id, actual_row.id);
        try std.testing.expectEqual(expected_row.status, actual_row.status);
        try std.testing.expectEqual(expected_row.last_sequence, actual_row.last_sequence);
        try std.testing.expectEqualStrings(expected_row.name, actual_row.name);
    }

    try std.testing.expectEqual(expected.timers.items.len, actual.timers.items.len);
    for (expected.timers.items, actual.timers.items) |expected_row, actual_row| {
        try std.testing.expectEqual(expected_row.id, actual_row.id);
        try std.testing.expectEqual(expected_row.status, actual_row.status);
        try std.testing.expectEqual(expected_row.last_sequence, actual_row.last_sequence);
        try std.testing.expectEqualStrings(expected_row.name, actual_row.name);
    }

    try std.testing.expectEqual(expected.deferreds.items.len, actual.deferreds.items.len);
    for (expected.deferreds.items, actual.deferreds.items) |expected_row, actual_row| {
        try std.testing.expectEqual(expected_row.id, actual_row.id);
        try std.testing.expectEqual(expected_row.status, actual_row.status);
        try std.testing.expectEqual(expected_row.last_sequence, actual_row.last_sequence);
        try std.testing.expectEqualStrings(expected_row.name, actual_row.name);
    }

    try std.testing.expectEqual(expected.queues.items.len, actual.queues.items.len);
    for (expected.queues.items, actual.queues.items) |expected_row, actual_row| {
        try std.testing.expectEqual(expected_row.id, actual_row.id);
        try std.testing.expectEqual(expected_row.status, actual_row.status);
        try std.testing.expectEqual(expected_row.last_sequence, actual_row.last_sequence);
        try std.testing.expectEqualStrings(expected_row.name, actual_row.name);
    }
}

test "workflow journal schema constants are stable" {
    try std.testing.expectEqualStrings("zigeffect.workflow.journal-event.v1", fx.workflow.workflow_journal_event_schema);
    try std.testing.expectEqual(@as(u32, 1), fx.workflow.workflow_journal_event_schema_version);
}

test "workflow journal ids are u64 aliases" {
    try std.testing.expect(fx.workflow.WorkflowId == u64);
    try std.testing.expect(fx.workflow.ExecutionId == u64);
    try std.testing.expect(fx.workflow.ActivityId == u64);
    try std.testing.expect(fx.workflow.TimerId == u64);
    try std.testing.expect(fx.workflow.DeferredId == u64);
    try std.testing.expect(fx.workflow.QueueId == u64);
    try std.testing.expect(fx.workflow.JournalSequence == u64);
}

test "workflow event kind names are stable" {
    const cases = .{
        .{ fx.workflow.WorkflowEventKind.workflow_started, "workflow_started" },
        .{ fx.workflow.WorkflowEventKind.workflow_suspended, "workflow_suspended" },
        .{ fx.workflow.WorkflowEventKind.workflow_resumed, "workflow_resumed" },
        .{ fx.workflow.WorkflowEventKind.workflow_completed, "workflow_completed" },
        .{ fx.workflow.WorkflowEventKind.workflow_failed, "workflow_failed" },
        .{ fx.workflow.WorkflowEventKind.workflow_interrupted, "workflow_interrupted" },
        .{ fx.workflow.WorkflowEventKind.workflow_cancelled, "workflow_cancelled" },
        .{ fx.workflow.WorkflowEventKind.activity_scheduled, "activity_scheduled" },
        .{ fx.workflow.WorkflowEventKind.activity_started, "activity_started" },
        .{ fx.workflow.WorkflowEventKind.activity_completed, "activity_completed" },
        .{ fx.workflow.WorkflowEventKind.activity_failed, "activity_failed" },
        .{ fx.workflow.WorkflowEventKind.timer_scheduled, "timer_scheduled" },
        .{ fx.workflow.WorkflowEventKind.timer_fired, "timer_fired" },
        .{ fx.workflow.WorkflowEventKind.timer_cancelled, "timer_cancelled" },
        .{ fx.workflow.WorkflowEventKind.deferred_created, "deferred_created" },
        .{ fx.workflow.WorkflowEventKind.deferred_awaited, "deferred_awaited" },
        .{ fx.workflow.WorkflowEventKind.deferred_completed, "deferred_completed" },
        .{ fx.workflow.WorkflowEventKind.deferred_failed, "deferred_failed" },
        .{ fx.workflow.WorkflowEventKind.deferred_cancelled, "deferred_cancelled" },
        .{ fx.workflow.WorkflowEventKind.queue_offered, "queue_offered" },
        .{ fx.workflow.WorkflowEventKind.queue_claimed, "queue_claimed" },
        .{ fx.workflow.WorkflowEventKind.queue_completed, "queue_completed" },
        .{ fx.workflow.WorkflowEventKind.queue_failed, "queue_failed" },
        .{ fx.workflow.WorkflowEventKind.queue_acked, "queue_acked" },
        .{ fx.workflow.WorkflowEventKind.signal_received, "signal_received" },
        .{ fx.workflow.WorkflowEventKind.signal_consumed, "signal_consumed" },
    };

    inline for (cases) |case| {
        try std.testing.expectEqualStrings(case[1], fx.workflow.workflowEventKindName(case[0]));
    }
}

test "workflow event json includes schema metadata and optional ids" {
    const event = fx.workflow.WorkflowEvent{
        .sequence = 1,
        .kind = .activity_completed,
        .workflow_id = 7,
        .execution_id = 8,
        .activity_id = 9,
        .name = "charge-card",
        .status = "success",
        .redacted_detail = "ok",
        .idempotency_key = "event-1",
    };

    const json = try fx.workflow.formatWorkflowEventJson(std.testing.allocator, event);
    defer std.testing.allocator.free(json);

    try std.testing.expect(std.mem.indexOf(u8, json, "\"schema\":\"zigeffect.workflow.journal-event.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"schema_version\":1") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"sequence\":1") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"kind\":\"activity_completed\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"workflow_id\":7") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"execution_id\":8") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"activity_id\":9") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"timer_id\":null") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"name\":\"charge-card\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"status\":\"success\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"redacted_detail\":\"ok\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"idempotency_key\":\"event-1\"") != null);
}

test "workflow event text is readable for agents and CLIs" {
    const event = fx.workflow.WorkflowEvent{
        .sequence = 2,
        .kind = .timer_scheduled,
        .workflow_id = 7,
        .execution_id = 8,
        .timer_id = 10,
        .name = "wake-up",
        .status = "scheduled",
        .idempotency_key = "timer-2",
    };

    const text = try fx.workflow.formatWorkflowEventText(std.testing.allocator, event);
    defer std.testing.allocator.free(text);

    try std.testing.expect(std.mem.indexOf(u8, text, "zigeffect workflow journal event") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "kind: timer_scheduled") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "timer_id: 10") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "name: wake-up") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "idempotency_key: timer-2") != null);
}

test "workflow event json parses back into an owned event" {
    const event = fx.workflow.WorkflowEvent{
        .sequence = 3,
        .kind = .queue_claimed,
        .workflow_id = 7,
        .execution_id = 8,
        .parent_sequence = 2,
        .queue_id = 40,
        .name = "mailbox \"primary\"",
        .status = "claimed\nready",
        .redacted_detail = "safe\tpayload",
        .idempotency_key = "queue-claim",
    };

    const json = try fx.workflow.formatWorkflowEventJson(std.testing.allocator, event);
    defer std.testing.allocator.free(json);

    const parsed = try fx.workflow.parseWorkflowEventJson(std.testing.allocator, json);
    defer fx.workflow.deinitWorkflowEventStrings(std.testing.allocator, parsed);

    try std.testing.expectEqual(event.sequence, parsed.sequence);
    try std.testing.expectEqual(event.kind, parsed.kind);
    try std.testing.expectEqual(event.workflow_id, parsed.workflow_id);
    try std.testing.expectEqual(event.execution_id, parsed.execution_id);
    try std.testing.expectEqual(event.parent_sequence, parsed.parent_sequence);
    try std.testing.expectEqual(event.queue_id, parsed.queue_id);
    try std.testing.expectEqual(@as(?u64, null), parsed.activity_id);
    try std.testing.expectEqualStrings(event.name, parsed.name);
    try std.testing.expectEqualStrings(event.status, parsed.status);
    try std.testing.expectEqualStrings(event.redacted_detail, parsed.redacted_detail);
    try std.testing.expectEqualStrings(event.idempotency_key, parsed.idempotency_key);
}

test "workflow replay folds lifecycle events" {
    const events = [_]fx.workflow.WorkflowEvent{
        .{ .sequence = 1, .kind = .workflow_started, .workflow_id = 7, .execution_id = 8, .name = "approval" },
        .{ .sequence = 2, .kind = .workflow_suspended, .workflow_id = 7, .execution_id = 8, .status = "waiting" },
        .{ .sequence = 3, .kind = .workflow_resumed, .workflow_id = 7, .execution_id = 8 },
        .{ .sequence = 4, .kind = .workflow_completed, .workflow_id = 7, .execution_id = 8, .status = "success" },
    };

    var state = try fx.workflow.WorkflowReplayState.fold(std.testing.allocator, &events);
    defer state.deinit();

    try std.testing.expectEqual(fx.workflow.WorkflowStatus.completed, state.workflow_status);
    try std.testing.expectEqual(@as(?u64, 7), state.workflow_id);
    try std.testing.expectEqual(@as(?u64, 8), state.execution_id);
    try std.testing.expectEqual(@as(u64, 4), state.last_sequence);
}

test "workflow replay rejects events before start and duplicate starts" {
    const before_start = [_]fx.workflow.WorkflowEvent{
        .{ .sequence = 1, .kind = .workflow_completed, .workflow_id = 7, .execution_id = 8 },
    };
    try std.testing.expectError(error.WorkflowNotStarted, fx.workflow.WorkflowReplayState.fold(std.testing.allocator, &before_start));

    const duplicate_start = [_]fx.workflow.WorkflowEvent{
        .{ .sequence = 1, .kind = .workflow_started, .workflow_id = 7, .execution_id = 8 },
        .{ .sequence = 2, .kind = .workflow_started, .workflow_id = 7, .execution_id = 8 },
    };
    try std.testing.expectError(error.WorkflowAlreadyStarted, fx.workflow.WorkflowReplayState.fold(std.testing.allocator, &duplicate_start));
}

test "workflow replay folds defect terminal status" {
    const events = [_]fx.workflow.WorkflowEvent{
        .{ .sequence = 1, .kind = .workflow_started, .workflow_id = 7, .execution_id = 8 },
        .{ .sequence = 2, .kind = .workflow_failed, .workflow_id = 7, .execution_id = 8, .status = "defect" },
    };

    var state = try fx.workflow.WorkflowReplayState.fold(std.testing.allocator, &events);
    defer state.deinit();

    try std.testing.expectEqual(fx.workflow.WorkflowStatus.defect, state.workflow_status);
    try std.testing.expectEqual(@as(u64, 2), state.last_sequence);
}

test "workflow replay rejects terminal and lifecycle transition violations" {
    const after_terminal = [_]fx.workflow.WorkflowEvent{
        .{ .sequence = 1, .kind = .workflow_started, .workflow_id = 7, .execution_id = 8 },
        .{ .sequence = 2, .kind = .workflow_completed, .workflow_id = 7, .execution_id = 8 },
        .{ .sequence = 3, .kind = .timer_scheduled, .workflow_id = 7, .execution_id = 8, .timer_id = 20 },
    };
    try std.testing.expectError(error.WorkflowAlreadyTerminal, fx.workflow.WorkflowReplayState.fold(std.testing.allocator, &after_terminal));

    const resume_without_suspend = [_]fx.workflow.WorkflowEvent{
        .{ .sequence = 1, .kind = .workflow_started, .workflow_id = 7, .execution_id = 8 },
        .{ .sequence = 2, .kind = .workflow_resumed, .workflow_id = 7, .execution_id = 8 },
    };
    try std.testing.expectError(error.InvalidWorkflowTransition, fx.workflow.WorkflowReplayState.fold(std.testing.allocator, &resume_without_suspend));
}

test "workflow replay folds activity timer deferred and queue rows" {
    const events = [_]fx.workflow.WorkflowEvent{
        .{ .sequence = 1, .kind = .workflow_started, .workflow_id = 7, .execution_id = 8 },
        .{ .sequence = 2, .kind = .activity_scheduled, .workflow_id = 7, .execution_id = 8, .activity_id = 10, .name = "charge" },
        .{ .sequence = 3, .kind = .activity_started, .workflow_id = 7, .execution_id = 8, .activity_id = 10 },
        .{ .sequence = 4, .kind = .activity_completed, .workflow_id = 7, .execution_id = 8, .activity_id = 10 },
        .{ .sequence = 5, .kind = .timer_scheduled, .workflow_id = 7, .execution_id = 8, .timer_id = 20, .name = "wake-up" },
        .{ .sequence = 6, .kind = .timer_fired, .workflow_id = 7, .execution_id = 8, .timer_id = 20 },
        .{ .sequence = 7, .kind = .deferred_created, .workflow_id = 7, .execution_id = 8, .deferred_id = 30, .name = "approval" },
        .{ .sequence = 8, .kind = .deferred_awaited, .workflow_id = 7, .execution_id = 8, .deferred_id = 30 },
        .{ .sequence = 9, .kind = .deferred_completed, .workflow_id = 7, .execution_id = 8, .deferred_id = 30 },
        .{ .sequence = 10, .kind = .queue_offered, .workflow_id = 7, .execution_id = 8, .queue_id = 40, .name = "mailbox" },
        .{ .sequence = 11, .kind = .queue_claimed, .workflow_id = 7, .execution_id = 8, .queue_id = 40 },
        .{ .sequence = 12, .kind = .queue_acked, .workflow_id = 7, .execution_id = 8, .queue_id = 40 },
    };

    var state = try fx.workflow.WorkflowReplayState.fold(std.testing.allocator, &events);
    defer state.deinit();

    try std.testing.expectEqual(@as(usize, 1), state.activities.items.len);
    try std.testing.expectEqual(@as(u64, 10), state.activities.items[0].id);
    try std.testing.expectEqual(fx.workflow.ActivityStatus.completed, state.activities.items[0].status);
    try std.testing.expectEqual(@as(u64, 4), state.activities.items[0].last_sequence);
    try std.testing.expectEqualStrings("charge", state.activities.items[0].name);

    try std.testing.expectEqual(@as(usize, 1), state.timers.items.len);
    try std.testing.expectEqual(@as(u64, 20), state.timers.items[0].id);
    try std.testing.expectEqual(fx.workflow.TimerStatus.fired, state.timers.items[0].status);
    try std.testing.expectEqual(@as(u64, 6), state.timers.items[0].last_sequence);
    try std.testing.expectEqualStrings("wake-up", state.timers.items[0].name);

    try std.testing.expectEqual(@as(usize, 1), state.deferreds.items.len);
    try std.testing.expectEqual(@as(u64, 30), state.deferreds.items[0].id);
    try std.testing.expectEqual(fx.workflow.DeferredStatus.completed, state.deferreds.items[0].status);
    try std.testing.expectEqual(@as(u64, 9), state.deferreds.items[0].last_sequence);
    try std.testing.expectEqualStrings("approval", state.deferreds.items[0].name);

    try std.testing.expectEqual(@as(usize, 1), state.queues.items.len);
    try std.testing.expectEqual(@as(u64, 40), state.queues.items[0].id);
    try std.testing.expectEqual(fx.workflow.QueueStatus.acked, state.queues.items[0].status);
    try std.testing.expectEqual(@as(u64, 12), state.queues.items[0].last_sequence);
    try std.testing.expectEqualStrings("mailbox", state.queues.items[0].name);
}

test "workflow replay folds retry-ready activity failures" {
    const events = [_]fx.workflow.WorkflowEvent{
        .{ .sequence = 1, .kind = .workflow_started, .workflow_id = 7, .execution_id = 8 },
        .{ .sequence = 2, .kind = .activity_scheduled, .workflow_id = 7, .execution_id = 8, .activity_id = 10 },
        .{ .sequence = 3, .kind = .activity_failed, .workflow_id = 7, .execution_id = 8, .activity_id = 10, .status = "retry_ready" },
    };

    var state = try fx.workflow.WorkflowReplayState.fold(std.testing.allocator, &events);
    defer state.deinit();

    try std.testing.expectEqual(fx.workflow.ActivityStatus.retry_ready, state.activities.items[0].status);
    try std.testing.expectEqual(@as(u64, 3), state.activities.items[0].last_sequence);
}

test "workflow replay rejects malformed resource histories" {
    const unknown_activity = [_]fx.workflow.WorkflowEvent{
        .{ .sequence = 1, .kind = .workflow_started, .workflow_id = 7, .execution_id = 8 },
        .{ .sequence = 2, .kind = .activity_completed, .workflow_id = 7, .execution_id = 8, .activity_id = 10 },
    };
    try std.testing.expectError(error.UnknownActivity, fx.workflow.WorkflowReplayState.fold(std.testing.allocator, &unknown_activity));

    const duplicate_timer = [_]fx.workflow.WorkflowEvent{
        .{ .sequence = 1, .kind = .workflow_started, .workflow_id = 7, .execution_id = 8 },
        .{ .sequence = 2, .kind = .timer_scheduled, .workflow_id = 7, .execution_id = 8, .timer_id = 20 },
        .{ .sequence = 3, .kind = .timer_scheduled, .workflow_id = 7, .execution_id = 8, .timer_id = 20 },
    };
    try std.testing.expectError(error.DuplicateTimer, fx.workflow.WorkflowReplayState.fold(std.testing.allocator, &duplicate_timer));

    const missing_deferred = [_]fx.workflow.WorkflowEvent{
        .{ .sequence = 1, .kind = .workflow_started, .workflow_id = 7, .execution_id = 8 },
        .{ .sequence = 2, .kind = .deferred_completed, .workflow_id = 7, .execution_id = 8 },
    };
    try std.testing.expectError(error.MissingTargetId, fx.workflow.WorkflowReplayState.fold(std.testing.allocator, &missing_deferred));

    const unknown_queue = [_]fx.workflow.WorkflowEvent{
        .{ .sequence = 1, .kind = .workflow_started, .workflow_id = 7, .execution_id = 8 },
        .{ .sequence = 2, .kind = .queue_acked, .workflow_id = 7, .execution_id = 8, .queue_id = 40 },
    };
    try std.testing.expectError(error.UnknownQueue, fx.workflow.WorkflowReplayState.fold(std.testing.allocator, &unknown_queue));
}

test "in-memory workflow journal store appends and reads ordered events" {
    var memory_store = fx.workflow.InMemoryJournalStore.init(std.testing.allocator);
    defer memory_store.deinit();

    var journal_store = memory_store.asJournalStore();
    try std.testing.expect(@TypeOf(journal_store) == fx.workflow.JournalStore);

    const first_sequence = try journal_store.append(.{
        .event = .{
            .sequence = 1,
            .kind = .workflow_started,
            .workflow_id = 7,
            .execution_id = 8,
            .idempotency_key = "start",
        },
    });
    try std.testing.expectEqual(@as(u64, 1), first_sequence);

    const second_sequence = try journal_store.append(.{
        .expected_next_sequence = 2,
        .event = .{
            .sequence = 2,
            .kind = .timer_scheduled,
            .workflow_id = 7,
            .execution_id = 8,
            .timer_id = 20,
            .name = "wake-up",
            .idempotency_key = "timer",
        },
    });
    try std.testing.expectEqual(@as(u64, 2), second_sequence);

    var all = try journal_store.readAll(std.testing.allocator);
    defer all.deinit();
    try std.testing.expectEqual(@as(usize, 2), all.events.len);
    try std.testing.expectEqual(@as(u64, 1), all.events[0].sequence);
    try std.testing.expectEqual(@as(u64, 2), all.events[1].sequence);
    try std.testing.expectEqualStrings("timer", all.events[1].idempotency_key);

    var from_second = try journal_store.readFromSequence(std.testing.allocator, 2);
    defer from_second.deinit();
    try std.testing.expectEqual(@as(usize, 1), from_second.events.len);
    try std.testing.expectEqual(@as(u64, 2), from_second.events[0].sequence);
    try std.testing.expectEqualStrings("wake-up", from_second.events[0].name);
}

test "in-memory workflow journal store rejects duplicate keys and sequence conflicts" {
    var store = fx.workflow.InMemoryJournalStore.init(std.testing.allocator);
    defer store.deinit();

    _ = try store.append(.{
        .event = .{
            .sequence = 1,
            .kind = .workflow_started,
            .workflow_id = 7,
            .execution_id = 8,
            .idempotency_key = "start",
        },
    });

    try std.testing.expectError(error.DuplicateEvent, store.append(.{
        .event = .{
            .sequence = 2,
            .kind = .workflow_suspended,
            .workflow_id = 7,
            .execution_id = 8,
            .idempotency_key = "start",
        },
    }));

    try std.testing.expectError(error.SequenceConflict, store.append(.{
        .event = .{
            .sequence = 3,
            .kind = .workflow_suspended,
            .workflow_id = 7,
            .execution_id = 8,
            .idempotency_key = "suspend",
        },
    }));

    try std.testing.expectError(error.SequenceConflict, store.append(.{
        .expected_next_sequence = 3,
        .event = .{
            .sequence = 2,
            .kind = .workflow_suspended,
            .workflow_id = 7,
            .execution_id = 8,
            .idempotency_key = "suspend",
        },
    }));
}

test "in-memory workflow journal store replays latest state and resets" {
    var store = fx.workflow.InMemoryJournalStore.init(std.testing.allocator);
    defer store.deinit();

    _ = try store.append(.{
        .event = .{
            .sequence = 1,
            .kind = .workflow_started,
            .workflow_id = 7,
            .execution_id = 8,
            .idempotency_key = "start",
        },
    });
    _ = try store.append(.{
        .event = .{
            .sequence = 2,
            .kind = .activity_scheduled,
            .workflow_id = 7,
            .execution_id = 8,
            .activity_id = 10,
            .name = "charge",
            .idempotency_key = "activity-scheduled",
        },
    });
    _ = try store.append(.{
        .event = .{
            .sequence = 3,
            .kind = .activity_completed,
            .workflow_id = 7,
            .execution_id = 8,
            .activity_id = 10,
            .idempotency_key = "activity-completed",
        },
    });

    var state = try store.latestState(std.testing.allocator);
    defer state.deinit();
    try std.testing.expectEqual(fx.workflow.WorkflowStatus.running, state.workflow_status);
    try std.testing.expectEqual(@as(usize, 1), state.activities.items.len);
    try std.testing.expectEqual(fx.workflow.ActivityStatus.completed, state.activities.items[0].status);
    try std.testing.expectEqualStrings("charge", state.activities.items[0].name);

    store.reset();

    var empty_events = try store.readAll(std.testing.allocator);
    defer empty_events.deinit();
    try std.testing.expectEqual(@as(usize, 0), empty_events.events.len);

    var empty_state = try store.latestState(std.testing.allocator);
    defer empty_state.deinit();
    try std.testing.expectEqual(fx.workflow.WorkflowStatus.pending, empty_state.workflow_status);

    const restarted_sequence = try store.append(.{
        .event = .{
            .sequence = 1,
            .kind = .workflow_started,
            .workflow_id = 9,
            .execution_id = 10,
            .idempotency_key = "restart",
        },
    });
    try std.testing.expectEqual(@as(u64, 1), restarted_sequence);
}

test "file workflow journal store appends json lines and replays after reopen" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const events = [_]fx.workflow.WorkflowEvent{
        .{
            .sequence = 1,
            .kind = .workflow_started,
            .workflow_id = 7,
            .execution_id = 8,
            .idempotency_key = "start",
        },
        .{
            .sequence = 2,
            .kind = .activity_scheduled,
            .workflow_id = 7,
            .execution_id = 8,
            .activity_id = 10,
            .name = "charge",
            .idempotency_key = "activity-scheduled",
        },
        .{
            .sequence = 3,
            .kind = .activity_completed,
            .workflow_id = 7,
            .execution_id = 8,
            .activity_id = 10,
            .idempotency_key = "activity-completed",
        },
    };

    const segment_name = try fx.workflow.segmentFileName(std.testing.allocator, 1);
    defer std.testing.allocator.free(segment_name);

    {
        var file_store = try fx.workflow.FileJournalStore.open(std.testing.allocator, std.testing.io, &tmp.dir, .{});
        defer file_store.deinit();

        var journal_store = file_store.asJournalStore();
        try std.testing.expect(@TypeOf(journal_store) == fx.workflow.JournalStore);
        for (events) |event| {
            _ = try journal_store.append(.{ .event = event });
        }

        var file_state = try journal_store.latestState(std.testing.allocator);
        defer file_state.deinit();
        try std.testing.expectEqual(fx.workflow.ActivityStatus.completed, file_state.activities.items[0].status);
    }

    const raw_segment = try tmp.dir.readFileAlloc(
        std.testing.io,
        segment_name,
        std.testing.allocator,
        std.Io.Limit.limited(16 * 1024),
    );
    defer std.testing.allocator.free(raw_segment);
    try std.testing.expectEqual(@as(usize, 3), std.mem.count(u8, raw_segment, "\n"));
    try std.testing.expect(std.mem.indexOf(u8, raw_segment, "\"idempotency_key\":\"activity-completed\"") != null);

    var memory_store = fx.workflow.InMemoryJournalStore.init(std.testing.allocator);
    defer memory_store.deinit();
    for (events) |event| {
        _ = try memory_store.append(.{ .event = event });
    }
    var memory_state = try memory_store.latestState(std.testing.allocator);
    defer memory_state.deinit();

    {
        var reopened = try fx.workflow.FileJournalStore.open(std.testing.allocator, std.testing.io, &tmp.dir, .{});
        defer reopened.deinit();

        var file_state = try reopened.latestState(std.testing.allocator);
        defer file_state.deinit();
        try expectWorkflowReplayStatesEqual(&memory_state, &file_state);
    }
}

test "file workflow journal store recovers partial trailing row" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const segment_name = try fx.workflow.segmentFileName(std.testing.allocator, 1);
    defer std.testing.allocator.free(segment_name);

    const started = fx.workflow.WorkflowEvent{
        .sequence = 1,
        .kind = .workflow_started,
        .workflow_id = 7,
        .execution_id = 8,
        .idempotency_key = "start",
    };
    const started_json = try fx.workflow.formatWorkflowEventJson(std.testing.allocator, started);
    defer std.testing.allocator.free(started_json);

    const partial = "{\"schema\":\"zigeffect.workflow.journal-event.v1\",\"sequence\":";
    {
        const file = try tmp.dir.createFile(std.testing.io, segment_name, .{ .read = true });
        defer file.close(std.testing.io);
        try file.writeStreamingAll(std.testing.io, started_json);
        try file.writeStreamingAll(std.testing.io, "\n");
        try file.writeStreamingAll(std.testing.io, partial);
    }

    var store = try fx.workflow.FileJournalStore.open(std.testing.allocator, std.testing.io, &tmp.dir, .{ .fsync_policy = .after_recovery });
    defer store.deinit();

    try std.testing.expectEqual(partial.len, store.recoveredPartialBytes());
    try std.testing.expectEqual(@as(u64, 1), store.syncCount());

    var state = try store.latestState(std.testing.allocator);
    defer state.deinit();
    try std.testing.expectEqual(fx.workflow.WorkflowStatus.running, state.workflow_status);
    try std.testing.expectEqual(@as(u64, 1), state.last_sequence);

    const recovered_segment = try tmp.dir.readFileAlloc(
        std.testing.io,
        segment_name,
        std.testing.allocator,
        std.Io.Limit.limited(16 * 1024),
    );
    defer std.testing.allocator.free(recovered_segment);
    try std.testing.expectEqual(@as(usize, 1), std.mem.count(u8, recovered_segment, "\n"));
    try std.testing.expect(std.mem.indexOf(u8, recovered_segment, partial) == null);
}

test "file workflow journal store reports complete-row corruption" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const segment_name = try fx.workflow.segmentFileName(std.testing.allocator, 1);
    defer std.testing.allocator.free(segment_name);

    {
        const file = try tmp.dir.createFile(std.testing.io, segment_name, .{ .read = true });
        defer file.close(std.testing.io);
        try file.writeStreamingAll(std.testing.io, "{\"schema\":\"not-json\"\n");
    }

    var store = try fx.workflow.FileJournalStore.init(std.testing.allocator, std.testing.io, &tmp.dir, .{});
    defer store.deinit();
    try store.acquireLock();
    try std.testing.expectError(error.CorruptJournal, store.recover());

    const report = store.lastCorruption().?;
    try std.testing.expectEqualStrings(segment_name, report.segment_name);
    try std.testing.expectEqual(@as(u64, 0), report.offset);
    try std.testing.expectEqual(fx.workflow.JournalCorruptionReason.invalid_json, report.reason);
}

test "file workflow journal store lock rejects a second local opener" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    var first = try fx.workflow.FileJournalStore.open(std.testing.allocator, std.testing.io, &tmp.dir, .{});
    defer first.deinit();

    try std.testing.expectError(
        error.JournalStoreLocked,
        fx.workflow.FileJournalStore.open(std.testing.allocator, std.testing.io, &tmp.dir, .{}),
    );
}

test "file workflow journal store fsync policy is observable after appends" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    var store = try fx.workflow.FileJournalStore.open(std.testing.allocator, std.testing.io, &tmp.dir, .{ .fsync_policy = .after_append });
    defer store.deinit();

    _ = try store.append(.{
        .event = .{
            .sequence = 1,
            .kind = .workflow_started,
            .workflow_id = 7,
            .execution_id = 8,
            .idempotency_key = "start",
        },
    });
    _ = try store.append(.{
        .event = .{
            .sequence = 2,
            .kind = .workflow_completed,
            .workflow_id = 7,
            .execution_id = 8,
            .idempotency_key = "complete",
        },
    });

    try std.testing.expectEqual(@as(u64, 2), store.syncCount());
}

test "workflow checkpoint json round-trips replay-equivalent state" {
    const events = [_]fx.workflow.WorkflowEvent{
        .{ .sequence = 1, .kind = .workflow_started, .workflow_id = 7, .execution_id = 8 },
        .{ .sequence = 2, .kind = .activity_scheduled, .workflow_id = 7, .execution_id = 8, .activity_id = 10, .name = "charge" },
        .{ .sequence = 3, .kind = .activity_completed, .workflow_id = 7, .execution_id = 8, .activity_id = 10 },
        .{ .sequence = 4, .kind = .timer_scheduled, .workflow_id = 7, .execution_id = 8, .timer_id = 20, .name = "wake-up" },
        .{ .sequence = 5, .kind = .timer_fired, .workflow_id = 7, .execution_id = 8, .timer_id = 20 },
        .{ .sequence = 6, .kind = .deferred_created, .workflow_id = 7, .execution_id = 8, .deferred_id = 30, .name = "approval" },
        .{ .sequence = 7, .kind = .deferred_completed, .workflow_id = 7, .execution_id = 8, .deferred_id = 30 },
        .{ .sequence = 8, .kind = .queue_offered, .workflow_id = 7, .execution_id = 8, .queue_id = 40, .name = "mailbox" },
        .{ .sequence = 9, .kind = .queue_acked, .workflow_id = 7, .execution_id = 8, .queue_id = 40 },
    };

    var state = try fx.workflow.WorkflowReplayState.fold(std.testing.allocator, &events);
    defer state.deinit();

    const checkpoint_json = try fx.workflow.formatWorkflowCheckpointJson(std.testing.allocator, &state);
    defer std.testing.allocator.free(checkpoint_json);

    try std.testing.expect(std.mem.indexOf(u8, checkpoint_json, "\"schema\":\"zigeffect.workflow.checkpoint.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, checkpoint_json, "\"activity_id\":10") != null);
    try std.testing.expect(std.mem.indexOf(u8, checkpoint_json, "\"queue_id\":40") != null);

    var parsed = try fx.workflow.parseWorkflowCheckpointJson(std.testing.allocator, checkpoint_json);
    defer parsed.deinit();

    try expectWorkflowReplayStatesEqual(&state, &parsed);
}

test "workflow definition exposes metadata requirements and execution ids" {
    const Payload = struct {
        account_id: u64,
        region: []const u8,
    };
    const Success = struct {
        approved: bool,
    };
    const Failure = error{Rejected};
    const Helpers = struct {
        fn key(allocator: std.mem.Allocator, payload: Payload) ![]const u8 {
            return std.fmt.allocPrint(allocator, "{d}:{s}", .{ payload.account_id, payload.region });
        }
    };

    const Approval = fx.workflow
        .Workflow("approval", Payload, Success, Failure, fx.TestServices)
        .withIdempotencyKey(Helpers.key)
        .requires(.{ fx.Logger, fx.Config });

    try std.testing.expect(Approval.PayloadType == Payload);
    try std.testing.expect(Approval.SuccessType == Success);
    try std.testing.expect(Approval.FailureType == Failure);
    try std.testing.expect(Approval.EnvType == fx.TestServices);
    try std.testing.expectEqual(@as(usize, 2), Approval.RequiredServices.len);

    const metadata = Approval.metadata();
    try std.testing.expectEqualStrings("approval", metadata.name);
    try std.testing.expectEqualStrings(@typeName(Payload), metadata.payload_type_name);
    try std.testing.expectEqualStrings(@typeName(Success), metadata.success_type_name);
    try std.testing.expectEqualStrings(@typeName(Failure), metadata.failure_type_name);
    try std.testing.expectEqualStrings(@typeName(fx.TestServices), metadata.env_type_name);
    try std.testing.expectEqual(@as(usize, 2), metadata.requirement_count);
    try std.testing.expect(metadata.has_idempotency_key);

    var required = try Approval.requiredServices(std.testing.allocator);
    defer required.deinit();
    try std.testing.expect(required.contains(@typeName(fx.Logger)));
    try std.testing.expect(required.contains(@typeName(fx.Config)));

    const payload = Payload{ .account_id = 42, .region = "eu" };
    const key = try Approval.idempotencyKey(std.testing.allocator, payload);
    defer std.testing.allocator.free(key);
    try std.testing.expectEqualStrings("42:eu", key);

    const execution_id = try Approval.deriveExecutionId(std.testing.allocator, payload);
    const same_execution_id = try Approval.deriveExecutionId(std.testing.allocator, payload);
    const different_execution_id = try Approval.deriveExecutionId(std.testing.allocator, .{ .account_id = 43, .region = "eu" });
    try std.testing.expectEqual(execution_id, same_execution_id);
    try std.testing.expect(execution_id != different_execution_id);
}

test "activity definition exposes metadata formatting requirements and retry policy" {
    const Payload = struct {
        invoice_id: u64,
        cents: u64,
    };
    const Success = struct {
        charge_id: []const u8,
    };
    const Failure = error{Declined};
    const Helpers = struct {
        fn key(allocator: std.mem.Allocator, payload: Payload) ![]const u8 {
            return std.fmt.allocPrint(allocator, "invoice:{d}:{d}", .{ payload.invoice_id, payload.cents });
        }
    };

    const ChargeCard = fx.workflow
        .Activity("charge-card", Payload, Success, Failure, fx.TestServices)
        .withIdempotencyKey(Helpers.key)
        .withRetrySchedule(fx.Schedule.fixed(.{ .max_retries = 3, .delay_ms = 25 }).withLabel("charge-retry"))
        .withTimeoutMs(30_000)
        .withCompensation("refund-charge")
        .requires(.{fx.Logger});

    try std.testing.expect(ChargeCard.PayloadType == Payload);
    try std.testing.expect(ChargeCard.SuccessType == Success);
    try std.testing.expect(ChargeCard.FailureType == Failure);
    try std.testing.expect(ChargeCard.EnvType == fx.TestServices);
    try std.testing.expectEqual(@as(usize, 1), ChargeCard.RequiredServices.len);

    const metadata = ChargeCard.metadata();
    try std.testing.expectEqualStrings("charge-card", metadata.name);
    try std.testing.expect(metadata.has_idempotency_key);
    try std.testing.expect(metadata.has_retry_schedule);
    try std.testing.expectEqualStrings("charge-retry", metadata.retry_schedule_label);
    try std.testing.expectEqual(@as(?u64, 30_000), metadata.timeout_ms);
    try std.testing.expectEqualStrings("refund-charge", metadata.compensation_name);
    try std.testing.expectEqual(@as(usize, 1), metadata.requirement_count);

    var retry = ChargeCard.retrySchedule().?;
    try std.testing.expectEqualStrings("charge-retry", retry.labelOrKind());

    var required = try ChargeCard.requiredServices(std.testing.allocator);
    defer required.deinit();
    try std.testing.expect(required.contains(@typeName(fx.Logger)));

    const payload = Payload{ .invoice_id = 77, .cents = 1299 };
    const key = try ChargeCard.idempotencyKey(std.testing.allocator, payload);
    defer std.testing.allocator.free(key);
    try std.testing.expectEqualStrings("invoice:77:1299", key);

    const formatted = try ChargeCard.format(std.testing.allocator);
    defer std.testing.allocator.free(formatted);
    try std.testing.expect(std.mem.indexOf(u8, formatted, "activity: charge-card") != null);
    try std.testing.expect(std.mem.indexOf(u8, formatted, "retry: charge-retry") != null);
    try std.testing.expect(std.mem.indexOf(u8, formatted, "timeout_ms: 30000") != null);
    try std.testing.expect(std.mem.indexOf(u8, formatted, "compensation: refund-charge") != null);
}
