const std = @import("std");
const fx = @import("zigeffect");
const replay_assertions = @import("support/replay_assertions.zig");
const workflow_history_generator = @import("support/workflow_history_generator.zig");

fn appendHistory(store: fx.workflow.JournalStore, events: []const fx.workflow.WorkflowEvent) !void {
    for (events) |event| {
        _ = try store.append(.{ .expected_next_sequence = event.sequence, .event = event });
    }
}

fn incrementalReplay(events: []const fx.workflow.WorkflowEvent) !fx.workflow.WorkflowReplayState {
    var state = fx.workflow.WorkflowReplayState.init(std.testing.allocator);
    errdefer state.deinit();

    for (events) |event| {
        try state.apply(event);
    }

    return state;
}

test "replay assertion helper compares complete workflow replay state" {
    const events = [_]fx.workflow.WorkflowEvent{
        .{
            .sequence = 1,
            .kind = .workflow_started,
            .workflow_id = 101,
            .execution_id = 202,
            .name = "property-workflow",
            .status = "running",
            .idempotency_key = "property-start",
        },
        .{
            .sequence = 2,
            .kind = .activity_scheduled,
            .workflow_id = 101,
            .execution_id = 202,
            .activity_id = 301,
            .attempt = 1,
            .name = "activity",
            .status = "scheduled",
            .idempotency_key = "property-activity",
        },
    };

    var expected = try fx.workflow.WorkflowReplayState.fold(std.testing.allocator, &events);
    defer expected.deinit();
    var actual = try fx.workflow.WorkflowReplayState.fold(std.testing.allocator, &events);
    defer actual.deinit();

    try replay_assertions.expectReplayStatesEqual(&expected, &actual);
}

test "generated workflow histories are valid replay inputs" {
    const seeds = [_]u64{ 0x42, 0x1234, 0x9e3779b97f4a7c15 };
    for (seeds) |seed| {
        var case_index: usize = 0;
        while (case_index < 12) : (case_index += 1) {
            var history = try workflow_history_generator.generateWorkflowHistory(
                std.testing.allocator,
                seed,
                case_index,
            );
            defer history.deinit();

            try std.testing.expect(history.events.len >= 1);
            try std.testing.expectEqual(fx.workflow.WorkflowEventKind.workflow_started, history.events[0].kind);
            var state = try fx.workflow.WorkflowReplayState.fold(std.testing.allocator, history.events);
            defer state.deinit();
            try std.testing.expectEqual(history.events[history.events.len - 1].sequence, state.last_sequence);
        }
    }
}

test "generated workflow histories replay equivalently through stores" {
    const seeds = [_]u64{ 0x42, 0x5150, 0xabcdef, 0x9e3779b97f4a7c15 };
    for (seeds) |seed| {
        var case_index: usize = 0;
        while (case_index < 12) : (case_index += 1) {
            var history = try workflow_history_generator.generateWorkflowHistory(
                std.testing.allocator,
                seed,
                case_index,
            );
            defer history.deinit();

            var folded = try fx.workflow.WorkflowReplayState.fold(std.testing.allocator, history.events);
            defer folded.deinit();
            var applied = try incrementalReplay(history.events);
            defer applied.deinit();
            try replay_assertions.expectReplayStatesEqual(&folded, &applied);

            var memory_state = fx.workflow.InMemoryJournalStore.init(std.testing.allocator);
            defer memory_state.deinit();
            const memory_store = memory_state.asJournalStore();
            try appendHistory(memory_store, history.events);
            var memory_replay = try memory_store.latestState(std.testing.allocator);
            defer memory_replay.deinit();
            try replay_assertions.expectReplayStatesEqual(&folded, &memory_replay);

            var tmp = std.testing.tmpDir(.{});
            defer tmp.cleanup();
            {
                var file_state = try fx.workflow.FileJournalStore.open(std.testing.allocator, std.testing.io, &tmp.dir, .{});
                defer file_state.deinit();
                try appendHistory(file_state.asJournalStore(), history.events);
            }
            var reopened_state = try fx.workflow.FileJournalStore.open(std.testing.allocator, std.testing.io, &tmp.dir, .{});
            defer reopened_state.deinit();
            var file_replay = try reopened_state.asJournalStore().latestState(std.testing.allocator);
            defer file_replay.deinit();
            try replay_assertions.expectReplayStatesEqual(&folded, &file_replay);
        }
    }
}
