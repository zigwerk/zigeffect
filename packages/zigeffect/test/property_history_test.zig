const std = @import("std");
const fx = @import("zigeffect");
const replay_assertions = @import("support/replay_assertions.zig");
const workflow_history_generator = @import("support/workflow_history_generator.zig");

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
