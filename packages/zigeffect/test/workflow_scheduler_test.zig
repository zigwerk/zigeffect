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

test "workflow scheduler fires due timers from registered watches" {
    var clock = fx.FakeClock.fake(1_000);
    var journal_memory = fx.workflow.InMemoryJournalStore.init(std.testing.allocator);
    defer journal_memory.deinit();
    const journal = journal_memory.asJournalStore();

    _ = try journal.append(.{ .event = .{
        .sequence = 1,
        .kind = .workflow_started,
        .workflow_id = 7,
        .execution_id = 8,
        .name = "timer-workflow",
        .status = "running",
        .idempotency_key = "scheduler-timer",
    } });

    {
        var context = try fx.workflow.WorkflowContext.init(std.testing.allocator, journal, .{
            .workflow_id = 7,
            .execution_id = 8,
            .clock = &clock,
        });
        defer context.deinit();
        const result = try context.sleep("wake", 250);
        switch (result) {
            .suspended => {},
            else => return error.ExpectedTimerSuspension,
        }
    }

    var scheduler = fx.workflow.WorkflowScheduler.init(std.testing.allocator, journal, &clock);
    defer scheduler.deinit();
    try scheduler.registerTimerWatch(.{ .workflow_id = 7, .execution_id = 8 });

    const early = try scheduler.tick(.{ .max_workflow_polls = 0, .max_timers = 1, .max_queue_retries = 0, .max_queue_claims = 0 });
    try std.testing.expectEqual(@as(usize, 0), early.timers_fired);

    clock.sleep(250);
    const due = try scheduler.tick(.{ .max_workflow_polls = 0, .max_timers = 1, .max_queue_retries = 0, .max_queue_claims = 0 });
    try std.testing.expectEqual(@as(usize, 1), due.timers_fired);

    var events = try journal.readAll(std.testing.allocator);
    defer events.deinit();
    try std.testing.expectEqual(fx.workflow.WorkflowEventKind.timer_fired, events.events[3].kind);
    try std.testing.expectEqual(fx.workflow.WorkflowEventKind.workflow_resumed, events.events[4].kind);
}

test "pumpAsyncUntilIdle drives async timers to completion on a virtual-clock backend" {
    const allocator = std.testing.allocator;
    var clock = fx.FakeClock.fake(1_000);
    var journal_memory = fx.workflow.InMemoryJournalStore.init(allocator);
    defer journal_memory.deinit();
    const journal = journal_memory.asJournalStore();

    _ = try journal.append(.{ .event = .{
        .sequence = 1,
        .kind = .workflow_started,
        .workflow_id = 7,
        .execution_id = 8,
        .name = "pump-timer-workflow",
        .status = "running",
        .idempotency_key = "pump-timer",
    } });
    {
        var context = try fx.workflow.WorkflowContext.init(allocator, journal, .{
            .workflow_id = 7,
            .execution_id = 8,
            .clock = &clock,
        });
        defer context.deinit();
        switch (try context.sleep("wake", 250)) {
            .suspended => {},
            else => return error.ExpectedTimerSuspension,
        }
    }

    var backend_state = fx.LocalAsyncBackendState.init(allocator, .{});
    defer backend_state.deinit();
    var scheduler = fx.workflow.WorkflowScheduler.initWithAsyncBackend(allocator, journal, &clock, backend_state.backend());
    defer scheduler.deinit();
    try scheduler.registerTimerWatch(.{ .workflow_id = 7, .execution_id = 8 });
    // The virtual-clock backend is NOT real_clock — the pump must not busy-spin.
    try std.testing.expect(!backend_state.backend().capabilities.real_clock);

    const budget = fx.workflow.WorkflowSchedulerBudget{
        .max_iterations = 8,
        .max_workflow_polls = 0,
        .max_timers = 4,
        .max_queue_retries = 0,
        .max_queue_claims = 0,
    };

    // Before the deadline: the pump registers the timer, finds it not due, and
    // TERMINATES (it must not loop forever waiting on a clock it cannot advance).
    const early = try scheduler.pumpAsyncUntilIdle(budget, 0);
    try std.testing.expectEqual(@as(usize, 0), early.timers_fired);

    // Advance virtual time past the deadline; one pump fires it and goes idle.
    clock.sleep(250);
    const due = try scheduler.pumpAsyncUntilIdle(budget, 0);
    try std.testing.expectEqual(@as(usize, 1), due.timers_fired);
    try std.testing.expect(!due.budget_exhausted); // reached idle, not the cap

    var events = try journal.readAll(allocator);
    defer events.deinit();
    try std.testing.expectEqual(fx.workflow.WorkflowEventKind.timer_fired, events.events[3].kind);
    try std.testing.expectEqual(fx.workflow.WorkflowEventKind.workflow_resumed, events.events[4].kind);
}

const SchedulerQueuePayload = struct {
    account_id: u64,
};

const SchedulerEmailQueue = fx.workflow
    .Queue("scheduler-email", SchedulerQueuePayload, u64, error{DeliveryFailed})
    .withIdempotencyKey(struct {
    fn key(allocator: std.mem.Allocator, payload: SchedulerQueuePayload) ![]const u8 {
        return std.fmt.allocPrint(allocator, "scheduler-email:{d}", .{payload.account_id});
    }
}.key);

const scheduler_payload_codec = fx.Codec(SchedulerQueuePayload){
    .encode = struct {
        fn encode(allocator: std.mem.Allocator, payload: SchedulerQueuePayload) ![]const u8 {
            return std.fmt.allocPrint(allocator, "{d}", .{payload.account_id});
        }
    }.encode,
    .decode = struct {
        fn decode(_: std.mem.Allocator, bytes: []const u8) !SchedulerQueuePayload {
            return .{ .account_id = try std.fmt.parseInt(u64, bytes, 10) };
        }
    }.decode,
};

const scheduler_result_codec = fx.Codec(u64){
    .encode = struct {
        fn encode(allocator: std.mem.Allocator, value: u64) ![]const u8 {
            return std.fmt.allocPrint(allocator, "{d}", .{value});
        }
    }.encode,
    .decode = struct {
        fn decode(_: std.mem.Allocator, bytes: []const u8) !u64 {
            return std.fmt.parseInt(u64, bytes, 10);
        }
    }.decode,
};

const SchedulerQueueSuccessHandler = struct {
    var calls: usize = 0;
    var last_attempt: u32 = 0;

    fn run(payload: SchedulerQueuePayload, attempt: u32) error{DeliveryFailed}!u64 {
        calls += 1;
        last_attempt = attempt;
        return payload.account_id + 100;
    }
};

test "workflow scheduler processes typed queue worker success" {
    SchedulerQueueSuccessHandler.calls = 0;
    SchedulerQueueSuccessHandler.last_attempt = 0;

    var clock = fx.FakeClock.fake(1_000);
    var journal_memory = fx.workflow.InMemoryJournalStore.init(std.testing.allocator);
    defer journal_memory.deinit();
    const journal = journal_memory.asJournalStore();

    _ = try journal.append(.{ .event = .{
        .sequence = 1,
        .kind = .workflow_started,
        .workflow_id = 7,
        .execution_id = 8,
        .name = "queue-workflow",
        .status = "running",
        .idempotency_key = "scheduler-queue-success",
    } });

    {
        var context = try fx.workflow.WorkflowContext.init(std.testing.allocator, journal, .{
            .workflow_id = 7,
            .execution_id = 8,
        });
        defer context.deinit();
        const result = try context.queue(SchedulerEmailQueue, scheduler_payload_codec, scheduler_result_codec, .{ .account_id = 42 });
        switch (result) {
            .suspended => {},
            else => return error.ExpectedQueueSuspension,
        }
    }

    var worker = fx.workflow.QueueWorker(SchedulerEmailQueue, SchedulerQueueSuccessHandler.run).init(
        std.testing.allocator,
        journal,
        7,
        8,
        scheduler_payload_codec,
        scheduler_result_codec,
        "scheduler-worker-a",
    );
    var scheduler = fx.workflow.WorkflowScheduler.init(std.testing.allocator, journal, &clock);
    defer scheduler.deinit();
    try scheduler.registerQueueWorker(worker.asRegisteredQueueWorker());

    const tick = try scheduler.tick(.{ .max_workflow_polls = 0, .max_timers = 0, .max_queue_retries = 0, .max_queue_claims = 1 });
    try std.testing.expectEqual(@as(usize, 1), tick.queue_claims);
    try std.testing.expectEqual(@as(usize, 1), tick.queue_completions);
    try std.testing.expectEqual(@as(usize, 0), tick.queue_failures);
    try std.testing.expectEqual(@as(usize, 1), SchedulerQueueSuccessHandler.calls);
    try std.testing.expectEqual(@as(u32, 1), SchedulerQueueSuccessHandler.last_attempt);

    var events = try journal.readAll(std.testing.allocator);
    defer events.deinit();
    try std.testing.expectEqual(fx.workflow.WorkflowEventKind.queue_claimed, events.events[3].kind);
    try std.testing.expectEqual(fx.workflow.WorkflowEventKind.queue_completed, events.events[4].kind);
    try std.testing.expectEqual(fx.workflow.WorkflowEventKind.workflow_resumed, events.events[5].kind);
}

const SchedulerQueueFailureHandler = struct {
    var calls: usize = 0;

    fn run(_: SchedulerQueuePayload, _: u32) error{DeliveryFailed}!u64 {
        calls += 1;
        return error.DeliveryFailed;
    }
};

test "workflow scheduler records typed queue worker failure" {
    SchedulerQueueFailureHandler.calls = 0;

    var clock = fx.FakeClock.fake(1_000);
    var journal_memory = fx.workflow.InMemoryJournalStore.init(std.testing.allocator);
    defer journal_memory.deinit();
    const journal = journal_memory.asJournalStore();

    _ = try journal.append(.{ .event = .{
        .sequence = 1,
        .kind = .workflow_started,
        .workflow_id = 7,
        .execution_id = 8,
        .name = "queue-workflow",
        .status = "running",
        .idempotency_key = "scheduler-queue-failure",
    } });

    var durable_queue = fx.workflow.DurableQueue.init(std.testing.allocator, journal, 7, 8);
    _ = try durable_queue.offer(SchedulerEmailQueue, scheduler_payload_codec, .{ .account_id = 42 });

    var worker = fx.workflow.QueueWorker(SchedulerEmailQueue, SchedulerQueueFailureHandler.run).init(
        std.testing.allocator,
        journal,
        7,
        8,
        scheduler_payload_codec,
        scheduler_result_codec,
        "scheduler-worker-failure",
    );
    var scheduler = fx.workflow.WorkflowScheduler.init(std.testing.allocator, journal, &clock);
    defer scheduler.deinit();
    try scheduler.registerQueueWorker(worker.asRegisteredQueueWorker());

    const tick = try scheduler.tick(.{ .max_workflow_polls = 0, .max_timers = 0, .max_queue_retries = 0, .max_queue_claims = 1 });
    try std.testing.expectEqual(@as(usize, 1), tick.queue_claims);
    try std.testing.expectEqual(@as(usize, 0), tick.queue_completions);
    try std.testing.expectEqual(@as(usize, 1), tick.queue_failures);
    try std.testing.expectEqual(@as(usize, 1), SchedulerQueueFailureHandler.calls);

    var events = try journal.readAll(std.testing.allocator);
    defer events.deinit();
    try std.testing.expectEqual(fx.workflow.WorkflowEventKind.queue_failed, events.events[3].kind);
}

const SchedulerTimeoutQueue = fx.workflow
    .Queue("scheduler-timeout-email", SchedulerQueuePayload, u64, error{DeliveryFailed})
    .withIdempotencyKey(struct {
        fn key(allocator: std.mem.Allocator, payload: SchedulerQueuePayload) ![]const u8 {
            return std.fmt.allocPrint(allocator, "scheduler-timeout-email:{d}", .{payload.account_id});
        }
    }.key)
    .withClaimTimeoutMs(250)
    .withMaxConcurrency(1);

test "workflow scheduler retries expired queue claims before processing claims" {
    SchedulerQueueSuccessHandler.calls = 0;
    SchedulerQueueSuccessHandler.last_attempt = 0;

    var clock = fx.FakeClock.fake(1_000);
    var journal_memory = fx.workflow.InMemoryJournalStore.init(std.testing.allocator);
    defer journal_memory.deinit();
    const journal = journal_memory.asJournalStore();

    _ = try journal.append(.{ .event = .{
        .sequence = 1,
        .kind = .workflow_started,
        .workflow_id = 7,
        .execution_id = 8,
        .name = "queue-workflow",
        .status = "running",
        .idempotency_key = "scheduler-queue-retry",
    } });

    var durable_queue = fx.workflow.DurableQueue.initWithClock(std.testing.allocator, journal, 7, 8, &clock);
    _ = try durable_queue.offer(SchedulerTimeoutQueue, scheduler_payload_codec, .{ .account_id = 42 });
    _ = (try durable_queue.claim(SchedulerTimeoutQueue, scheduler_payload_codec, "stale-worker")).?;

    var worker = fx.workflow.QueueWorker(SchedulerTimeoutQueue, SchedulerQueueSuccessHandler.run).initWithClock(
        std.testing.allocator,
        journal,
        7,
        8,
        &clock,
        scheduler_payload_codec,
        scheduler_result_codec,
        "scheduler-retry-worker",
    );
    var scheduler = fx.workflow.WorkflowScheduler.init(std.testing.allocator, journal, &clock);
    defer scheduler.deinit();
    try scheduler.registerQueueWorker(worker.asRegisteredQueueWorker());

    const early = try scheduler.tick(.{ .max_workflow_polls = 0, .max_timers = 0, .max_queue_retries = 1, .max_queue_claims = 1 });
    try std.testing.expectEqual(@as(usize, 0), early.queue_retries);
    try std.testing.expectEqual(@as(usize, 0), early.queue_claims);

    clock.sleep(250);
    const due = try scheduler.tick(.{ .max_workflow_polls = 0, .max_timers = 0, .max_queue_retries = 1, .max_queue_claims = 1 });
    try std.testing.expectEqual(@as(usize, 1), due.queue_retries);
    try std.testing.expectEqual(@as(usize, 1), due.queue_claims);
    try std.testing.expectEqual(@as(usize, 1), due.queue_completions);
    try std.testing.expectEqual(@as(u32, 2), SchedulerQueueSuccessHandler.last_attempt);

    var events = try journal.readAll(std.testing.allocator);
    defer events.deinit();
    try std.testing.expectEqual(fx.workflow.WorkflowEventKind.queue_retry_scheduled, events.events[3].kind);
    try std.testing.expectEqual(fx.workflow.WorkflowEventKind.queue_claimed, events.events[4].kind);
    try std.testing.expectEqual(fx.workflow.WorkflowEventKind.queue_completed, events.events[5].kind);
}

test "workflow scheduler shutdown stops new cooperative work" {
    var journal_memory = fx.workflow.InMemoryJournalStore.init(std.testing.allocator);
    defer journal_memory.deinit();
    var clock = fx.FakeClock.fake(1_000);

    var visits = std.ArrayList(u64).empty;
    defer visits.deinit(std.testing.allocator);
    var worker_state = FakeWorkflowWorker{ .visits = &visits, .id = 1 };

    var scheduler = fx.workflow.WorkflowScheduler.init(std.testing.allocator, journal_memory.asJournalStore(), &clock);
    defer scheduler.deinit();
    try scheduler.registerWorkflowWorker(worker_state.registered());
    scheduler.requestShutdown();

    try std.testing.expect(scheduler.isShutdownRequested());
    const tick = try scheduler.tick(.{ .max_workflow_polls = 1, .max_timers = 1, .max_queue_retries = 1, .max_queue_claims = 1 });
    try std.testing.expect(tick.shutdown_requested);
    try std.testing.expectEqual(@as(usize, 0), tick.workflow_polls);
    try std.testing.expectEqual(@as(usize, 0), visits.items.len);
}

test "workflow scheduler drain stops at idle and reports budget exhaustion" {
    var journal_memory = fx.workflow.InMemoryJournalStore.init(std.testing.allocator);
    defer journal_memory.deinit();
    var clock = fx.FakeClock.fake(1_000);

    var visits = std.ArrayList(u64).empty;
    defer visits.deinit(std.testing.allocator);
    var worker_state = FakeWorkflowWorker{ .visits = &visits, .id = 1 };

    var scheduler = fx.workflow.WorkflowScheduler.init(std.testing.allocator, journal_memory.asJournalStore(), &clock);
    defer scheduler.deinit();
    try scheduler.registerWorkflowWorker(worker_state.registered());

    const exhausted = try scheduler.drain(.{
        .max_iterations = 2,
        .max_workflow_polls = 1,
        .max_timers = 0,
        .max_queue_retries = 0,
        .max_queue_claims = 0,
    });
    try std.testing.expectEqual(@as(usize, 2), exhausted.iterations);
    try std.testing.expectEqual(@as(usize, 2), exhausted.workflow_polls);
    try std.testing.expect(exhausted.budget_exhausted);

    worker_state.step = .idle;
    const idle = try scheduler.drain(.{
        .max_iterations = 4,
        .max_workflow_polls = 1,
        .max_timers = 0,
        .max_queue_retries = 0,
        .max_queue_claims = 0,
    });
    try std.testing.expectEqual(@as(usize, 1), idle.iterations);
    try std.testing.expectEqual(@as(usize, 1), idle.workflow_polls);
    try std.testing.expect(!idle.budget_exhausted);
}
