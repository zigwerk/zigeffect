const std = @import("std");
const fx = @import("zigeffect");

test "workflow scheduler public exports are available" {
    try std.testing.expect(@hasDecl(fx.workflow, "scheduler"));
    try std.testing.expect(@hasDecl(fx.workflow, "WorkflowScheduler"));
    try std.testing.expect(@hasDecl(fx.workflow, "WorkflowSchedulerBudget"));
    try std.testing.expect(@hasDecl(fx.workflow, "WorkflowSchedulerTickResult"));
    try std.testing.expect(@hasDecl(fx.workflow, "SchedulerWorkKind"));
    try std.testing.expect(@hasDecl(fx.workflow, "RunnableWorkflowStep"));
    try std.testing.expect(@hasDecl(fx.workflow, "RegisteredWorkflowWorker"));
    try std.testing.expect(@hasDecl(fx.workflow, "TimerWatch"));
    try std.testing.expect(@hasDecl(fx.workflow, "QueueWorker"));
    try std.testing.expect(@hasDecl(fx.workflow, "QueueWorkerStep"));
    try std.testing.expect(@hasDecl(fx.workflow, "RegisteredQueueWorker"));
}

test "workflow scheduler tick result reports and merges progress" {
    var result = fx.workflow.WorkflowSchedulerTickResult{};
    try std.testing.expect(!result.progressed());

    result.workflow_progress = 1;
    try std.testing.expect(result.progressed());

    var merged = fx.workflow.WorkflowSchedulerTickResult{ .iterations = 1, .timers_fired = 1 };
    merged.merge(.{
        .iterations = 2,
        .queue_claims = 1,
        .queue_failures = 1,
        .budget_exhausted = true,
        .shutdown_requested = true,
    });

    try std.testing.expectEqual(@as(usize, 3), merged.iterations);
    try std.testing.expectEqual(@as(usize, 1), merged.timers_fired);
    try std.testing.expectEqual(@as(usize, 1), merged.queue_claims);
    try std.testing.expectEqual(@as(usize, 1), merged.queue_failures);
    try std.testing.expect(merged.budget_exhausted);
    try std.testing.expect(merged.shutdown_requested);
}
