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

const FakeWorkflowWorker = struct {
    visits: *std.ArrayList(u64),
    id: u64,
    step: fx.workflow.RunnableWorkflowStep = .progressed,

    fn registered(self: *FakeWorkflowWorker) fx.workflow.RegisteredWorkflowWorker {
        return .{
            .context = self,
            .workflow_id = self.id,
            .execution_id = self.id + 100,
            .name = "fake-workflow",
            .poll_fn = poll,
        };
    }

    fn poll(context: *anyopaque) anyerror!fx.workflow.RunnableWorkflowStep {
        const self: *FakeWorkflowWorker = @ptrCast(@alignCast(context));
        try self.visits.append(std.testing.allocator, self.id);
        return self.step;
    }
};

test "workflow scheduler polls runnable workflow workers fairly" {
    var journal_memory = fx.workflow.InMemoryJournalStore.init(std.testing.allocator);
    defer journal_memory.deinit();
    var clock = fx.FakeClock.fake(1_000);

    var visits = std.ArrayList(u64).empty;
    defer visits.deinit(std.testing.allocator);

    var first = FakeWorkflowWorker{ .visits = &visits, .id = 1 };
    var second = FakeWorkflowWorker{ .visits = &visits, .id = 2 };
    var third = FakeWorkflowWorker{ .visits = &visits, .id = 3 };

    var scheduler = fx.workflow.WorkflowScheduler.init(std.testing.allocator, journal_memory.asJournalStore(), &clock);
    defer scheduler.deinit();
    try scheduler.registerWorkflowWorker(first.registered());
    try scheduler.registerWorkflowWorker(second.registered());
    try scheduler.registerWorkflowWorker(third.registered());

    const budget = fx.workflow.WorkflowSchedulerBudget{
        .max_iterations = 1,
        .max_workflow_polls = 1,
        .max_timers = 0,
        .max_queue_retries = 0,
        .max_queue_claims = 0,
    };
    try std.testing.expectEqual(@as(usize, 1), (try scheduler.tick(budget)).workflow_polls);
    try std.testing.expectEqual(@as(usize, 1), (try scheduler.tick(budget)).workflow_polls);
    try std.testing.expectEqual(@as(usize, 1), (try scheduler.tick(budget)).workflow_polls);
    try std.testing.expectEqual(@as(usize, 1), (try scheduler.tick(budget)).workflow_polls);

    try std.testing.expectEqual(@as(usize, 4), visits.items.len);
    try std.testing.expectEqual(@as(u64, 1), visits.items[0]);
    try std.testing.expectEqual(@as(u64, 2), visits.items[1]);
    try std.testing.expectEqual(@as(u64, 3), visits.items[2]);
    try std.testing.expectEqual(@as(u64, 1), visits.items[3]);
}
