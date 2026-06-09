const std = @import("std");
const fx = @import("zigeffect");

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
