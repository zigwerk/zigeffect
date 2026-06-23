const std = @import("std");
const clock_service = @import("../services/clock.zig");
const traits = @import("../traits/root.zig");
const async_backend_mod = @import("../runtime/async_backend.zig");
const clock_mod = @import("clock.zig");
const journal_mod = @import("journal.zig");
const queue_mod = @import("queue.zig");
const store_mod = @import("store.zig");

pub const Allocator = std.mem.Allocator;
pub const Clock = clock_service.Clock;
pub const AsyncBackend = async_backend_mod.AsyncBackend;
pub const AsyncBackendError = async_backend_mod.AsyncBackendError;
pub const BackendWakeEvent = async_backend_mod.BackendWakeEvent;
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
    queue_retry_cursor: usize = 0,
    queue_cursor: usize = 0,
    shutdown_requested: bool = false,
    async_backend: ?AsyncBackend = null,
    // Timer ids already registered with the async backend and not yet resolved.
    // Prevents re-registering (and, on a real-clock backend, re-spawning a timer
    // coroutine for) the same journal timer on every async tick.
    registered_timer_ids: std.ArrayList(u64) = .empty,

    pub fn init(allocator: Allocator, journal_store: JournalStore, clock: *Clock) WorkflowScheduler {
        return .{
            .allocator = allocator,
            .journal_store = journal_store,
            .clock = clock,
        };
    }

    pub fn initWithAsyncBackend(
        allocator: Allocator,
        journal_store: JournalStore,
        clock: *Clock,
        async_backend: AsyncBackend,
    ) WorkflowScheduler {
        var scheduler = WorkflowScheduler.init(allocator, journal_store, clock);
        scheduler.async_backend = async_backend;
        return scheduler;
    }

    pub fn withAsyncBackend(self: WorkflowScheduler, async_backend: AsyncBackend) WorkflowScheduler {
        var scheduler = self;
        scheduler.async_backend = async_backend;
        return scheduler;
    }

    pub fn deinit(self: *WorkflowScheduler) void {
        self.queue_workers.deinit(self.allocator);
        self.timer_watches.deinit(self.allocator);
        self.workflow_workers.deinit(self.allocator);
        self.registered_timer_ids.deinit(self.allocator);
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

    pub fn requestShutdown(self: *WorkflowScheduler) void {
        self.shutdown_requested = true;
    }

    pub fn isShutdownRequested(self: *const WorkflowScheduler) bool {
        return self.shutdown_requested;
    }

    pub fn tick(self: *WorkflowScheduler, budget: WorkflowSchedulerBudget) anyerror!WorkflowSchedulerTickResult {
        var result = WorkflowSchedulerTickResult{
            .iterations = 1,
            .shutdown_requested = self.shutdown_requested,
        };
        if (self.shutdown_requested) return result;

        try self.pollWorkflowWorkers(budget.max_workflow_polls, &result);
        try self.fireDueTimers(budget.max_timers, &result);
        try self.retryExpiredQueueClaims(budget.max_queue_retries, &result);
        try self.processQueueClaims(budget.max_queue_claims, &result);
        return result;
    }

    pub fn tickAsync(self: *WorkflowScheduler, budget: WorkflowSchedulerBudget) anyerror!WorkflowSchedulerTickResult {
        const backend = self.async_backend orelse return self.tick(budget);
        var result = WorkflowSchedulerTickResult{
            .iterations = 1,
            .shutdown_requested = self.shutdown_requested,
        };
        if (self.shutdown_requested) return result;

        try self.registerPendingTimerWaits(backend, budget.max_timers);
        _ = try backend.advanceTime(self.clock.nowMs());
        try self.consumeBackendWakes(backend, budget, &result);
        try self.retryExpiredQueueClaims(budget.max_queue_retries, &result);
        try self.processQueueClaimsWithBackend(budget.max_queue_claims, &result, backend);
        try self.pollWorkflowWorkers(budget.max_workflow_polls, &result);
        return result;
    }

    /// Drive `tickAsync` until idle, reconciling the backend's clock model.
    ///
    /// On a virtual-clock backend (`real_clock == false`) due timers fire inside
    /// `tickAsync` (via `advanceTime`), so this behaves like `drain`: loop while a
    /// tick makes progress; the caller advances virtual time between pumps.
    ///
    /// On a real-clock backend (zio) timers fire on the OS clock via the event
    /// loop, so a tick that registered a timer sees no wake yet. When timers are
    /// still pending in the backend this YIELDS the event loop via
    /// `blockingSleep(quantum_ms)` — letting the real timer coroutine run — then
    /// re-ticks to consume the wake. Bounded by `budget.max_iterations`.
    pub fn pumpAsyncUntilIdle(
        self: *WorkflowScheduler,
        budget: WorkflowSchedulerBudget,
        quantum_ms: u64,
    ) anyerror!WorkflowSchedulerTickResult {
        const backend = self.async_backend orelse return self.drain(budget);

        var merged = WorkflowSchedulerTickResult{};
        if (budget.max_iterations == 0) {
            merged.budget_exhausted = true;
            merged.shutdown_requested = self.shutdown_requested;
            return merged;
        }

        var iteration: usize = 0;
        while (iteration < budget.max_iterations) : (iteration += 1) {
            const tick_result = try self.tickAsync(budget);
            const made_progress = tick_result.progressed();
            merged.merge(tick_result);
            if (tick_result.shutdown_requested) return merged;

            const pending = backend.snapshot().pending_count;
            if (pending == 0 and !made_progress) return merged; // fully idle

            if (pending > 0 and backend.capabilities.real_clock) {
                // Real timers will fire on their own — yield the event loop so the
                // pending timer coroutine(s) can run, then re-tick to consume.
                backend.blockingSleep(quantum_ms) catch {};
                continue;
            }
            if (!made_progress) {
                // Virtual clock with pending timers not yet due: nothing changes
                // until the caller advances the clock. Stop pumping.
                return merged;
            }
        }

        if (merged.progressed()) merged.budget_exhausted = true;
        return merged;
    }

    fn isTimerRegistered(self: *const WorkflowScheduler, timer_id: u64) bool {
        for (self.registered_timer_ids.items) |id| {
            if (id == timer_id) return true;
        }
        return false;
    }

    fn unregisterTimer(self: *WorkflowScheduler, timer_id: u64) void {
        for (self.registered_timer_ids.items, 0..) |id, index| {
            if (id == timer_id) {
                _ = self.registered_timer_ids.swapRemove(index);
                return;
            }
        }
    }

    pub fn drain(self: *WorkflowScheduler, budget: WorkflowSchedulerBudget) anyerror!WorkflowSchedulerTickResult {
        var merged = WorkflowSchedulerTickResult{};
        if (budget.max_iterations == 0) {
            merged.budget_exhausted = true;
            merged.shutdown_requested = self.shutdown_requested;
            return merged;
        }

        var iteration: usize = 0;
        while (iteration < budget.max_iterations) : (iteration += 1) {
            const tick_result = try self.tick(budget);
            const made_progress = tick_result.progressed();
            merged.merge(tick_result);
            if (tick_result.shutdown_requested or !made_progress) return merged;
        }

        if (merged.progressed()) merged.budget_exhausted = true;
        return merged;
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

    fn registerPendingTimerWaits(self: *WorkflowScheduler, backend: AsyncBackend, max_watches: usize) anyerror!void {
        const len = self.timer_watches.items.len;
        if (len == 0 or max_watches == 0) return;

        const visits = @min(max_watches, len);
        var count: usize = 0;
        while (count < visits) : (count += 1) {
            const index = self.timer_cursor % len;
            self.timer_cursor = (index + 1) % len;
            const watch = self.timer_watches.items[index];
            var durable_clock = DurableClock.init(self.allocator, self.journal_store, watch.workflow_id, watch.execution_id);
            var pending = try durable_clock.pendingTimers();
            defer pending.deinit();

            for (pending.timers) |timer| {
                // Register each journal timer with the backend at most once. On a
                // real-clock backend `scheduleTimer` spawns a live timer; without
                // this guard every tick would spawn a duplicate for the same
                // still-pending timer. Cleared when the wake is consumed.
                if (self.isTimerRegistered(timer.timer_id)) continue;
                try backend.scheduleTimer(.{
                    .suspension = .{ .kind = .timer, .id = timer.timer_id, .label = timer.name },
                    .due_time_ms = timer.fire_at_ms,
                    .now_ms = self.clock.nowMs(),
                    .workflow_id = timer.workflow_id,
                    .execution_id = timer.execution_id,
                });
                try self.registered_timer_ids.append(self.allocator, timer.timer_id);
            }
        }
    }

    fn consumeBackendWakes(
        self: *WorkflowScheduler,
        backend: AsyncBackend,
        budget: WorkflowSchedulerBudget,
        result: *WorkflowSchedulerTickResult,
    ) anyerror!void {
        const max_wakes = budget.max_timers + budget.max_queue_claims + budget.max_workflow_polls;
        var consumed: usize = 0;
        while (consumed < max_wakes) : (consumed += 1) {
            const maybe_wake = try backend.pollWake();
            const wake = maybe_wake orelse return;
            try self.handleBackendWake(wake, result);
        }
    }

    fn handleBackendWake(
        self: *WorkflowScheduler,
        wake: BackendWakeEvent,
        result: *WorkflowSchedulerTickResult,
    ) anyerror!void {
        switch (wake.suspension.kind) {
            .timer => {
                const workflow_id = wake.workflow_id orelse return;
                const execution_id = wake.execution_id orelse return;
                var durable_clock = DurableClock.init(self.allocator, self.journal_store, workflow_id, execution_id);
                switch (wake.status) {
                    .pending => {},
                    .ready => {
                        const fired = try durable_clock.fireDueTimers(self.clock.nowMs());
                        result.timers_fired += fired;
                        // Release the registration ONLY if the journal timer
                        // actually became terminal. If the durable clock says it is
                        // not due yet (clock skew vs the real backend that fired the
                        // coroutine), keep it registered so the next tick does NOT
                        // re-spawn a duplicate timer (the dedup's whole purpose).
                        if (fired > 0) self.unregisterTimer(wake.suspension.id);
                    },
                    .interrupted => {
                        _ = try durable_clock.cancel(wake.suspension.label);
                        self.unregisterTimer(wake.suspension.id);
                    },
                }
            },
            else => {},
        }
    }

    fn retryExpiredQueueClaims(self: *WorkflowScheduler, max_workers: usize, result: *WorkflowSchedulerTickResult) anyerror!void {
        const len = self.queue_workers.items.len;
        if (len == 0 or max_workers == 0) return;

        const visits = @min(max_workers, len);
        var count: usize = 0;
        while (count < visits) : (count += 1) {
            const index = self.queue_retry_cursor % len;
            self.queue_retry_cursor = (index + 1) % len;
            result.queue_retries += try self.queue_workers.items[index].retryExpired();
        }
    }

    fn processQueueClaims(self: *WorkflowScheduler, max_workers: usize, result: *WorkflowSchedulerTickResult) anyerror!void {
        return self.processQueueClaimsWithBackend(max_workers, result, null);
    }

    fn processQueueClaimsWithBackend(
        self: *WorkflowScheduler,
        max_workers: usize,
        result: *WorkflowSchedulerTickResult,
        async_backend: ?AsyncBackend,
    ) anyerror!void {
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
                .completed => |queue_id| {
                    result.queue_claims += 1;
                    result.queue_completions += 1;
                    if (async_backend) |backend| try wakeQueueSuspension(backend, queue_id, "queue completed");
                },
                .failed => |queue_id| {
                    result.queue_claims += 1;
                    result.queue_failures += 1;
                    if (async_backend) |backend| try wakeQueueSuspension(backend, queue_id, "queue failed");
                },
            }
        }
    }
};

fn wakeQueueSuspension(backend: AsyncBackend, queue_id: QueueId, reason: []const u8) AsyncBackendError!void {
    backend.wake(.{ .suspension_id = queue_id, .reason = reason }) catch |err| switch (err) {
        error.UnknownSuspension => return,
        else => return err,
    };
}
