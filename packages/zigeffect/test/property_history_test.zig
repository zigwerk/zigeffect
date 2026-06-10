const std = @import("std");
const fx = @import("zigeffect");
const replay_assertions = @import("support/replay_assertions.zig");

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
