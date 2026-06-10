const std = @import("std");
const fx = @import("zigeffect");

const CountingWorkflowWorker = struct {
    id: usize,
    counts: []usize,
    step: fx.workflow.RunnableWorkflowStep = .progressed,

    fn registered(self: *CountingWorkflowWorker) fx.workflow.RegisteredWorkflowWorker {
        return .{
            .context = self,
            .workflow_id = @intCast(self.id + 1),
            .execution_id = @intCast(self.id + 1001),
            .name = "property-workflow-worker",
            .poll_fn = poll,
        };
    }

    fn poll(context: *anyopaque) anyerror!fx.workflow.RunnableWorkflowStep {
        const self: *CountingWorkflowWorker = @ptrCast(@alignCast(context));
        self.counts[self.id] += 1;
        return self.step;
    }
};

const CountingQueueWorker = struct {
    id: usize,
    retry_counts: []usize,
    claim_counts: []usize,

    fn registered(self: *CountingQueueWorker) fx.workflow.RegisteredQueueWorker {
        return .{
            .context = self,
            .workflow_id = @intCast(self.id + 2001),
            .execution_id = @intCast(self.id + 3001),
            .name = "property-queue-worker",
            .retry_expired_fn = retryExpired,
            .process_one_fn = processOne,
        };
    }

    fn retryExpired(context: *anyopaque) anyerror!usize {
        const self: *CountingQueueWorker = @ptrCast(@alignCast(context));
        self.retry_counts[self.id] += 1;
        return 1;
    }

    fn processOne(context: *anyopaque) anyerror!fx.workflow.QueueWorkerStep {
        const self: *CountingQueueWorker = @ptrCast(@alignCast(context));
        self.claim_counts[self.id] += 1;
        return .{ .completed = @intCast(self.id + 1) };
    }
};

test "workflow scheduler balances workflow worker visits under one-poll budgets" {
    var worker_count: usize = 2;
    while (worker_count <= 7) : (worker_count += 1) {
        var journal_memory = fx.workflow.InMemoryJournalStore.init(std.testing.allocator);
        defer journal_memory.deinit();
        var clock = fx.FakeClock.fake(1_000);

        const counts = try std.testing.allocator.alloc(usize, worker_count);
        defer std.testing.allocator.free(counts);
        @memset(counts, 0);

        const workers = try std.testing.allocator.alloc(CountingWorkflowWorker, worker_count);
        defer std.testing.allocator.free(workers);

        var scheduler = fx.workflow.WorkflowScheduler.init(std.testing.allocator, journal_memory.asJournalStore(), &clock);
        defer scheduler.deinit();

        for (workers, 0..) |*worker, index| {
            worker.* = .{ .id = index, .counts = counts };
            try scheduler.registerWorkflowWorker(worker.registered());
        }

        var tick_index: usize = 0;
        while (tick_index < worker_count * 3 + 1) : (tick_index += 1) {
            const tick = try scheduler.tick(.{
                .max_workflow_polls = 1,
                .max_timers = 0,
                .max_queue_retries = 0,
                .max_queue_claims = 0,
            });
            try std.testing.expectEqual(@as(usize, 1), tick.workflow_polls);
        }

        try expectVisitSpreadAtMostOne(counts);
    }
}

test "workflow scheduler balances queue claim workers under one-claim budgets" {
    var worker_count: usize = 2;
    while (worker_count <= 7) : (worker_count += 1) {
        var journal_memory = fx.workflow.InMemoryJournalStore.init(std.testing.allocator);
        defer journal_memory.deinit();
        var clock = fx.FakeClock.fake(1_000);

        const retry_counts = try std.testing.allocator.alloc(usize, worker_count);
        defer std.testing.allocator.free(retry_counts);
        @memset(retry_counts, 0);
        const claim_counts = try std.testing.allocator.alloc(usize, worker_count);
        defer std.testing.allocator.free(claim_counts);
        @memset(claim_counts, 0);

        const workers = try std.testing.allocator.alloc(CountingQueueWorker, worker_count);
        defer std.testing.allocator.free(workers);

        var scheduler = fx.workflow.WorkflowScheduler.init(std.testing.allocator, journal_memory.asJournalStore(), &clock);
        defer scheduler.deinit();

        for (workers, 0..) |*worker, index| {
            worker.* = .{ .id = index, .retry_counts = retry_counts, .claim_counts = claim_counts };
            try scheduler.registerQueueWorker(worker.registered());
        }

        var tick_index: usize = 0;
        while (tick_index < worker_count * 3 + 1) : (tick_index += 1) {
            const tick = try scheduler.tick(.{
                .max_workflow_polls = 0,
                .max_timers = 0,
                .max_queue_retries = 0,
                .max_queue_claims = 1,
            });
            try std.testing.expectEqual(@as(usize, 1), tick.queue_claims);
        }

        try expectVisitSpreadAtMostOne(claim_counts);
    }
}

test "workflow scheduler balances queue retry workers under one-retry budgets" {
    var worker_count: usize = 2;
    while (worker_count <= 7) : (worker_count += 1) {
        var journal_memory = fx.workflow.InMemoryJournalStore.init(std.testing.allocator);
        defer journal_memory.deinit();
        var clock = fx.FakeClock.fake(1_000);

        const retry_counts = try std.testing.allocator.alloc(usize, worker_count);
        defer std.testing.allocator.free(retry_counts);
        @memset(retry_counts, 0);
        const claim_counts = try std.testing.allocator.alloc(usize, worker_count);
        defer std.testing.allocator.free(claim_counts);
        @memset(claim_counts, 0);

        const workers = try std.testing.allocator.alloc(CountingQueueWorker, worker_count);
        defer std.testing.allocator.free(workers);

        var scheduler = fx.workflow.WorkflowScheduler.init(std.testing.allocator, journal_memory.asJournalStore(), &clock);
        defer scheduler.deinit();

        for (workers, 0..) |*worker, index| {
            worker.* = .{ .id = index, .retry_counts = retry_counts, .claim_counts = claim_counts };
            try scheduler.registerQueueWorker(worker.registered());
        }

        var tick_index: usize = 0;
        while (tick_index < worker_count * 3 + 1) : (tick_index += 1) {
            const tick = try scheduler.tick(.{
                .max_workflow_polls = 0,
                .max_timers = 0,
                .max_queue_retries = 1,
                .max_queue_claims = 0,
            });
            try std.testing.expectEqual(@as(usize, 1), tick.queue_retries);
        }

        try expectVisitSpreadAtMostOne(retry_counts);
    }
}

test "workflow scheduler drain budget exhaustion follows repeated progress" {
    var journal_memory = fx.workflow.InMemoryJournalStore.init(std.testing.allocator);
    defer journal_memory.deinit();
    var clock = fx.FakeClock.fake(1_000);

    const counts = try std.testing.allocator.alloc(usize, 1);
    defer std.testing.allocator.free(counts);
    @memset(counts, 0);

    var worker = CountingWorkflowWorker{ .id = 0, .counts = counts };
    var scheduler = fx.workflow.WorkflowScheduler.init(std.testing.allocator, journal_memory.asJournalStore(), &clock);
    defer scheduler.deinit();
    try scheduler.registerWorkflowWorker(worker.registered());

    const exhausted = try scheduler.drain(.{
        .max_iterations = 3,
        .max_workflow_polls = 1,
        .max_timers = 0,
        .max_queue_retries = 0,
        .max_queue_claims = 0,
    });
    try std.testing.expectEqual(@as(usize, 3), exhausted.iterations);
    try std.testing.expect(exhausted.budget_exhausted);

    worker.step = .idle;
    const idle = try scheduler.drain(.{
        .max_iterations = 3,
        .max_workflow_polls = 1,
        .max_timers = 0,
        .max_queue_retries = 0,
        .max_queue_claims = 0,
    });
    try std.testing.expectEqual(@as(usize, 1), idle.iterations);
    try std.testing.expect(!idle.budget_exhausted);
}

fn expectVisitSpreadAtMostOne(counts: []const usize) !void {
    try std.testing.expect(counts.len > 0);
    var minimum = counts[0];
    var maximum = counts[0];
    for (counts[1..]) |count| {
        minimum = @min(minimum, count);
        maximum = @max(maximum, count);
    }
    try std.testing.expect(maximum - minimum <= 1);
}
