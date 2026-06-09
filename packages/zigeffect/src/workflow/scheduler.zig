const std = @import("std");
const clock_service = @import("../services/clock.zig");
const traits = @import("../traits/root.zig");
const clock_mod = @import("clock.zig");
const journal_mod = @import("journal.zig");
const queue_mod = @import("queue.zig");
const store_mod = @import("store.zig");

pub const Allocator = std.mem.Allocator;
pub const Clock = clock_service.Clock;
pub const JournalStore = store_mod.JournalStore;
pub const WorkflowId = journal_mod.WorkflowId;
pub const ExecutionId = journal_mod.ExecutionId;
pub const QueueId = journal_mod.QueueId;
pub const DurableClock = clock_mod.DurableClock;
pub const DurableQueue = queue_mod.DurableQueue;

pub const SchedulerWorkKind = enum {
    workflow,
    timer,
    queue_retry,
    queue_claim,
};

pub const RunnableWorkflowStep = enum {
    idle,
    progressed,
    completed,
    failed,
};

pub const QueueWorkerStep = union(enum) {
    idle,
    completed: QueueId,
    failed: QueueId,
};

pub const WorkflowSchedulerBudget = struct {
    max_iterations: usize = 1,
    max_workflow_polls: usize = 64,
    max_timers: usize = 64,
    max_queue_retries: usize = 64,
    max_queue_claims: usize = 64,
};

pub const WorkflowSchedulerTickResult = struct {
    iterations: usize = 0,
    workflow_polls: usize = 0,
    workflow_progress: usize = 0,
    workflow_completions: usize = 0,
    workflow_failures: usize = 0,
    timers_fired: usize = 0,
    queue_retries: usize = 0,
    queue_claims: usize = 0,
    queue_completions: usize = 0,
    queue_failures: usize = 0,
    budget_exhausted: bool = false,
    shutdown_requested: bool = false,

    pub fn progressed(self: WorkflowSchedulerTickResult) bool {
        return self.workflow_progress != 0 or
            self.workflow_completions != 0 or
            self.workflow_failures != 0 or
            self.timers_fired != 0 or
            self.queue_retries != 0 or
            self.queue_claims != 0 or
            self.queue_completions != 0 or
            self.queue_failures != 0;
    }

    pub fn merge(self: *WorkflowSchedulerTickResult, other: WorkflowSchedulerTickResult) void {
        self.iterations += other.iterations;
        self.workflow_polls += other.workflow_polls;
        self.workflow_progress += other.workflow_progress;
        self.workflow_completions += other.workflow_completions;
        self.workflow_failures += other.workflow_failures;
        self.timers_fired += other.timers_fired;
        self.queue_retries += other.queue_retries;
        self.queue_claims += other.queue_claims;
        self.queue_completions += other.queue_completions;
        self.queue_failures += other.queue_failures;
        self.budget_exhausted = self.budget_exhausted or other.budget_exhausted;
        self.shutdown_requested = self.shutdown_requested or other.shutdown_requested;
    }
};

pub const RegisteredWorkflowWorker = struct {
    context: *anyopaque,
    workflow_id: WorkflowId,
    execution_id: ExecutionId,
    name: []const u8,
    poll_fn: *const fn (*anyopaque) anyerror!RunnableWorkflowStep,

    pub fn poll(self: RegisteredWorkflowWorker) anyerror!RunnableWorkflowStep {
        return self.poll_fn(self.context);
    }
};

pub const TimerWatch = struct {
    workflow_id: WorkflowId,
    execution_id: ExecutionId,
};

pub const RegisteredQueueWorker = struct {
    context: *anyopaque,
    workflow_id: WorkflowId,
    execution_id: ExecutionId,
    name: []const u8,
    retry_expired_fn: *const fn (*anyopaque) anyerror!usize,
    process_one_fn: *const fn (*anyopaque) anyerror!QueueWorkerStep,

    pub fn retryExpired(self: RegisteredQueueWorker) anyerror!usize {
        return self.retry_expired_fn(self.context);
    }

    pub fn processOne(self: RegisteredQueueWorker) anyerror!QueueWorkerStep {
        return self.process_one_fn(self.context);
    }
};

pub fn QueueWorker(
    comptime QueueType: type,
    comptime Handler: *const fn (
        QueueType.PayloadType,
        u32,
    ) QueueType.FailureType!QueueType.SuccessType,
) type {
    return struct {
        const Self = @This();

        allocator: Allocator,
        durable_queue: DurableQueue,
        payload_codec: traits.Codec(QueueType.PayloadType),
        result_codec: traits.Codec(QueueType.SuccessType),
        worker_id: []const u8,

        pub fn init(
            allocator: Allocator,
            journal_store: JournalStore,
            workflow_id: WorkflowId,
            execution_id: ExecutionId,
            payload_codec: traits.Codec(QueueType.PayloadType),
            result_codec: traits.Codec(QueueType.SuccessType),
            worker_id: []const u8,
        ) Self {
            return .{
                .allocator = allocator,
                .durable_queue = DurableQueue.init(allocator, journal_store, workflow_id, execution_id),
                .payload_codec = payload_codec,
                .result_codec = result_codec,
                .worker_id = worker_id,
            };
        }

        pub fn initWithClock(
            allocator: Allocator,
            journal_store: JournalStore,
            workflow_id: WorkflowId,
            execution_id: ExecutionId,
            clock: *Clock,
            payload_codec: traits.Codec(QueueType.PayloadType),
            result_codec: traits.Codec(QueueType.SuccessType),
            worker_id: []const u8,
        ) Self {
            return .{
                .allocator = allocator,
                .durable_queue = DurableQueue.initWithClock(allocator, journal_store, workflow_id, execution_id, clock),
                .payload_codec = payload_codec,
                .result_codec = result_codec,
                .worker_id = worker_id,
            };
        }

        pub fn asRegisteredQueueWorker(self: *Self) RegisteredQueueWorker {
            return .{
                .context = self,
                .workflow_id = self.durable_queue.workflow_id,
                .execution_id = self.durable_queue.execution_id,
                .name = QueueType.name,
                .retry_expired_fn = retryExpired,
                .process_one_fn = processOne,
            };
        }

        fn retryExpired(context: *anyopaque) anyerror!usize {
            const self: *Self = @ptrCast(@alignCast(context));
            return self.durable_queue.retryExpiredClaims(QueueType);
        }

        fn processOne(context: *anyopaque) anyerror!QueueWorkerStep {
            const self: *Self = @ptrCast(@alignCast(context));
            const maybe_claim = try self.durable_queue.claim(QueueType, self.payload_codec, self.worker_id);
            const claim = maybe_claim orelse return .idle;

            const value = Handler(claim.payload, claim.attempt) catch |err| {
                try self.durable_queue.fail(QueueType, claim.item_id, err);
                return .{ .failed = claim.item_id };
            };

            try self.durable_queue.complete(QueueType, claim.item_id, self.result_codec, value);
            return .{ .completed = claim.item_id };
        }
    };
}

pub const WorkflowScheduler = struct {
    allocator: Allocator,
    journal_store: JournalStore,
    clock: *Clock,
    workflow_workers: std.ArrayList(RegisteredWorkflowWorker) = .empty,
    workflow_cursor: usize = 0,
    timer_watches: std.ArrayList(TimerWatch) = .empty,
    timer_cursor: usize = 0,
    queue_workers: std.ArrayList(RegisteredQueueWorker) = .empty,
    queue_cursor: usize = 0,

    pub fn init(allocator: Allocator, journal_store: JournalStore, clock: *Clock) WorkflowScheduler {
        return .{
            .allocator = allocator,
            .journal_store = journal_store,
            .clock = clock,
        };
    }

    pub fn deinit(self: *WorkflowScheduler) void {
        self.queue_workers.deinit(self.allocator);
        self.timer_watches.deinit(self.allocator);
        self.workflow_workers.deinit(self.allocator);
    }

    pub fn registerWorkflowWorker(self: *WorkflowScheduler, worker: RegisteredWorkflowWorker) Allocator.Error!void {
        try self.workflow_workers.append(self.allocator, worker);
    }

    pub fn registerTimerWatch(self: *WorkflowScheduler, watch: TimerWatch) Allocator.Error!void {
        try self.timer_watches.append(self.allocator, watch);
    }

    pub fn registerQueueWorker(self: *WorkflowScheduler, worker: RegisteredQueueWorker) Allocator.Error!void {
        try self.queue_workers.append(self.allocator, worker);
    }

    pub fn tick(self: *WorkflowScheduler, budget: WorkflowSchedulerBudget) anyerror!WorkflowSchedulerTickResult {
        var result = WorkflowSchedulerTickResult{ .iterations = 1 };
        try self.pollWorkflowWorkers(budget.max_workflow_polls, &result);
        try self.fireDueTimers(budget.max_timers, &result);
        try self.retryExpiredQueueClaims(budget.max_queue_retries, &result);
        try self.processQueueClaims(budget.max_queue_claims, &result);
        return result;
    }

    fn pollWorkflowWorkers(self: *WorkflowScheduler, max_polls: usize, result: *WorkflowSchedulerTickResult) anyerror!void {
        const len = self.workflow_workers.items.len;
        if (len == 0 or max_polls == 0) return;

        const visits = @min(max_polls, len);
        var count: usize = 0;
        while (count < visits) : (count += 1) {
            const index = self.workflow_cursor % len;
            self.workflow_cursor = (index + 1) % len;
            const step = try self.workflow_workers.items[index].poll();
            result.workflow_polls += 1;
            switch (step) {
                .idle => {},
                .progressed => result.workflow_progress += 1,
                .completed => result.workflow_completions += 1,
                .failed => result.workflow_failures += 1,
            }
        }
    }

    fn fireDueTimers(self: *WorkflowScheduler, max_watches: usize, result: *WorkflowSchedulerTickResult) anyerror!void {
        const len = self.timer_watches.items.len;
        if (len == 0 or max_watches == 0) return;

        const visits = @min(max_watches, len);
        var count: usize = 0;
        const now_ms = self.clock.nowMs();
        while (count < visits) : (count += 1) {
            const index = self.timer_cursor % len;
            self.timer_cursor = (index + 1) % len;
            const watch = self.timer_watches.items[index];
            var durable_clock = DurableClock.init(self.allocator, self.journal_store, watch.workflow_id, watch.execution_id);
            result.timers_fired += try durable_clock.fireDueTimers(now_ms);
        }
    }

    fn retryExpiredQueueClaims(self: *WorkflowScheduler, max_workers: usize, result: *WorkflowSchedulerTickResult) anyerror!void {
        if (max_workers == 0) return;
        const visits = @min(max_workers, self.queue_workers.items.len);
        var count: usize = 0;
        while (count < visits) : (count += 1) {
            result.queue_retries += try self.queue_workers.items[count].retryExpired();
        }
    }

    fn processQueueClaims(self: *WorkflowScheduler, max_workers: usize, result: *WorkflowSchedulerTickResult) anyerror!void {
        const len = self.queue_workers.items.len;
        if (len == 0 or max_workers == 0) return;

        const visits = @min(max_workers, len);
        var count: usize = 0;
        while (count < visits) : (count += 1) {
            const index = self.queue_cursor % len;
            self.queue_cursor = (index + 1) % len;
            const step = try self.queue_workers.items[index].processOne();
            switch (step) {
                .idle => {},
                .completed => {
                    result.queue_claims += 1;
                    result.queue_completions += 1;
                },
                .failed => {
                    result.queue_claims += 1;
                    result.queue_failures += 1;
                },
            }
        }
    }
};
