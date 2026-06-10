# zigeffect Cooperative Local Scheduler Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a deterministic local workflow scheduler that fairly polls registered workflow work, fires durable timers, processes durable queues, supports graceful shutdown, and enforces explicit work budgets.

**Architecture:** Add `src/workflow/scheduler.zig` as a separate orchestration layer over existing `WorkflowEngine`, `DurableClock`, `DurableQueue`, replay state, and journal stores. The scheduler stores type-erased workflow and queue worker registrations by value, keeps fair cursors per work class, and records all durable progress through existing journal APIs.

**Tech Stack:** Zig, `std.ArrayList`, existing zigeffect workflow journal/timer/queue modules, `bun:test` wrapper commands through Bun, and Zig test files imported by `packages/zigeffect/test/all_test.zig`.

---

## File Structure

- Create `packages/zigeffect/src/workflow/scheduler.zig`
  - Owns `WorkflowScheduler`, budgets, tick results, type-erased registered workflow workers, timer watches, type-erased queue workers, and typed `QueueWorker` helper.
- Create `packages/zigeffect/test/workflow_scheduler_test.zig`
  - Owns scheduler-focused tests so the already large `workflow_test.zig` does not grow further.
- Modify `packages/zigeffect/src/workflow/root.zig`
  - Adds `scheduler` namespace import and `fx.workflow.*` aliases.
- Modify `packages/zigeffect/test/all_test.zig`
  - Imports `workflow_scheduler_test.zig`.
- Modify `packages/zigeffect/docs/architecture.md`
  - Adds scheduler ownership and runtime boundary notes.
- Modify `docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md`
  - Marks Milestone 23 deliverables and acceptance complete after verification.

## Task 1: Scheduler Module, Public Exports, And Result Types

**Files:**
- Create: `packages/zigeffect/src/workflow/scheduler.zig`
- Create: `packages/zigeffect/test/workflow_scheduler_test.zig`
- Modify: `packages/zigeffect/src/workflow/root.zig`
- Modify: `packages/zigeffect/test/all_test.zig`

- [ ] **Step 1: Write the failing public export test**

Add `packages/zigeffect/test/workflow_scheduler_test.zig`:

```zig
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
```

Modify `packages/zigeffect/test/all_test.zig` by adding the import near
`workflow_test.zig`:

```zig
    _ = @import("workflow_scheduler_test.zig");
```

- [ ] **Step 2: Run the red test**

Run:

```bash
cd packages/zigeffect && zig build test-raw --summary all
```

Expected: failure because `fx.workflow.scheduler` or `WorkflowScheduler` does
not exist.

- [ ] **Step 3: Add the minimal scheduler module and exports**

Create `packages/zigeffect/src/workflow/scheduler.zig`:

```zig
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

    pub fn init(allocator: Allocator, journal_store: JournalStore, clock: *Clock) WorkflowScheduler {
        return .{
            .allocator = allocator,
            .journal_store = journal_store,
            .clock = clock,
        };
    }

    pub fn deinit(self: *WorkflowScheduler) void {
        _ = self;
    }
};
```

Modify `packages/zigeffect/src/workflow/root.zig`:

```zig
pub const scheduler = @import("scheduler.zig");
```

Add aliases near the existing workflow engine, clock, and queue aliases:

```zig
pub const SchedulerWorkKind = scheduler.SchedulerWorkKind;
pub const RunnableWorkflowStep = scheduler.RunnableWorkflowStep;
pub const QueueWorkerStep = scheduler.QueueWorkerStep;
pub const WorkflowSchedulerBudget = scheduler.WorkflowSchedulerBudget;
pub const WorkflowSchedulerTickResult = scheduler.WorkflowSchedulerTickResult;
pub const RegisteredWorkflowWorker = scheduler.RegisteredWorkflowWorker;
pub const TimerWatch = scheduler.TimerWatch;
pub const RegisteredQueueWorker = scheduler.RegisteredQueueWorker;
pub const QueueWorker = scheduler.QueueWorker;
pub const WorkflowScheduler = scheduler.WorkflowScheduler;
```

- [ ] **Step 4: Run the green test**

Run:

```bash
cd packages/zigeffect && zig build test-raw --summary all
```

Expected: all tests pass, including the new export and result aggregation tests.

- [ ] **Step 5: Format and commit**

Run:

```bash
zig fmt --check packages/zigeffect/src/workflow/scheduler.zig packages/zigeffect/src/workflow/root.zig packages/zigeffect/test/workflow_scheduler_test.zig packages/zigeffect/test/all_test.zig
```

Then commit:

```bash
git add packages/zigeffect/src/workflow/scheduler.zig packages/zigeffect/src/workflow/root.zig packages/zigeffect/test/workflow_scheduler_test.zig packages/zigeffect/test/all_test.zig
git commit -m "feat(zigeffect): add workflow scheduler surface"
```

## Task 2: Runnable Workflow Registry And Fair Polling

**Files:**
- Modify: `packages/zigeffect/src/workflow/scheduler.zig`
- Modify: `packages/zigeffect/test/workflow_scheduler_test.zig`

- [ ] **Step 1: Write the failing fairness test**

Append this helper and test to `packages/zigeffect/test/workflow_scheduler_test.zig`:

```zig
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
```

- [ ] **Step 2: Run the red test**

Run:

```bash
cd packages/zigeffect && zig build test-raw --summary all
```

Expected: failure because `WorkflowScheduler.registerWorkflowWorker` and
`tick` do not exist.

- [ ] **Step 3: Implement workflow worker registration and polling**

Update `WorkflowScheduler` in `packages/zigeffect/src/workflow/scheduler.zig`:

```zig
pub const WorkflowScheduler = struct {
    allocator: Allocator,
    journal_store: JournalStore,
    clock: *Clock,
    workflow_workers: std.ArrayList(RegisteredWorkflowWorker) = .empty,
    workflow_cursor: usize = 0,

    pub fn init(allocator: Allocator, journal_store: JournalStore, clock: *Clock) WorkflowScheduler {
        return .{
            .allocator = allocator,
            .journal_store = journal_store,
            .clock = clock,
        };
    }

    pub fn deinit(self: *WorkflowScheduler) void {
        self.workflow_workers.deinit(self.allocator);
    }

    pub fn registerWorkflowWorker(self: *WorkflowScheduler, worker: RegisteredWorkflowWorker) Allocator.Error!void {
        try self.workflow_workers.append(self.allocator, worker);
    }

    pub fn tick(self: *WorkflowScheduler, budget: WorkflowSchedulerBudget) anyerror!WorkflowSchedulerTickResult {
        var result = WorkflowSchedulerTickResult{ .iterations = 1 };
        try self.pollWorkflowWorkers(budget.max_workflow_polls, &result);
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
};
```

- [ ] **Step 4: Run the green test**

Run:

```bash
cd packages/zigeffect && zig build test-raw --summary all
```

Expected: all tests pass.

- [ ] **Step 5: Commit**

Run:

```bash
zig fmt --check packages/zigeffect/src/workflow/scheduler.zig packages/zigeffect/test/workflow_scheduler_test.zig
git add packages/zigeffect/src/workflow/scheduler.zig packages/zigeffect/test/workflow_scheduler_test.zig
git commit -m "feat(zigeffect): poll workflow scheduler workers fairly"
```

## Task 3: Timer Watches And Durable Wake-Up Polling

**Files:**
- Modify: `packages/zigeffect/src/workflow/scheduler.zig`
- Modify: `packages/zigeffect/test/workflow_scheduler_test.zig`

- [ ] **Step 1: Write the failing timer test**

Append to `packages/zigeffect/test/workflow_scheduler_test.zig`:

```zig
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
```

- [ ] **Step 2: Run the red test**

Run:

```bash
cd packages/zigeffect && zig build test-raw --summary all
```

Expected: failure because `WorkflowScheduler.registerTimerWatch` does not exist
or timer polling is not implemented.

- [ ] **Step 3: Implement timer watches and fair timer cursor**

Add fields to `WorkflowScheduler`:

```zig
    timer_watches: std.ArrayList(TimerWatch) = .empty,
    timer_cursor: usize = 0,
```

Update `deinit`:

```zig
        self.timer_watches.deinit(self.allocator);
        self.workflow_workers.deinit(self.allocator);
```

Add registration:

```zig
    pub fn registerTimerWatch(self: *WorkflowScheduler, watch: TimerWatch) Allocator.Error!void {
        try self.timer_watches.append(self.allocator, watch);
    }
```

Update `tick`:

```zig
        try self.pollWorkflowWorkers(budget.max_workflow_polls, &result);
        try self.fireDueTimers(budget.max_timers, &result);
```

Add helper:

```zig
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
```

- [ ] **Step 4: Run the green test**

Run:

```bash
cd packages/zigeffect && zig build test-raw --summary all
```

Expected: all tests pass.

- [ ] **Step 5: Commit**

Run:

```bash
zig fmt --check packages/zigeffect/src/workflow/scheduler.zig packages/zigeffect/test/workflow_scheduler_test.zig
git add packages/zigeffect/src/workflow/scheduler.zig packages/zigeffect/test/workflow_scheduler_test.zig
git commit -m "feat(zigeffect): fire scheduler timer watches"
```

## Task 4: Typed Queue Worker Processing

**Files:**
- Modify: `packages/zigeffect/src/workflow/scheduler.zig`
- Modify: `packages/zigeffect/test/workflow_scheduler_test.zig`

- [ ] **Step 1: Write the failing queue success test**

Append helpers and the success test to
`packages/zigeffect/test/workflow_scheduler_test.zig`:

```zig
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
```

- [ ] **Step 2: Run the red test**

Run:

```bash
cd packages/zigeffect && zig build test-raw --summary all
```

Expected: failure because `WorkflowScheduler.registerQueueWorker` and queue
processing do not exist.

- [ ] **Step 3: Implement queue worker registration and claim processing**

Add fields to `WorkflowScheduler`:

```zig
    queue_workers: std.ArrayList(RegisteredQueueWorker) = .empty,
    queue_cursor: usize = 0,
```

Update `deinit`:

```zig
        self.queue_workers.deinit(self.allocator);
        self.timer_watches.deinit(self.allocator);
        self.workflow_workers.deinit(self.allocator);
```

Add registration:

```zig
    pub fn registerQueueWorker(self: *WorkflowScheduler, worker: RegisteredQueueWorker) Allocator.Error!void {
        try self.queue_workers.append(self.allocator, worker);
    }
```

Update `tick`:

```zig
        try self.pollWorkflowWorkers(budget.max_workflow_polls, &result);
        try self.fireDueTimers(budget.max_timers, &result);
        try self.retryExpiredQueueClaims(budget.max_queue_retries, &result);
        try self.processQueueClaims(budget.max_queue_claims, &result);
```

Add helpers:

```zig
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
```

- [ ] **Step 4: Run the green test**

Run:

```bash
cd packages/zigeffect && zig build test-raw --summary all
```

Expected: all tests pass.

- [ ] **Step 5: Commit**

Run:

```bash
zig fmt --check packages/zigeffect/src/workflow/scheduler.zig packages/zigeffect/test/workflow_scheduler_test.zig
git add packages/zigeffect/src/workflow/scheduler.zig packages/zigeffect/test/workflow_scheduler_test.zig
git commit -m "feat(zigeffect): process scheduler queue workers"
```

## Task 5: Queue Failure And Expired Claim Retry

**Files:**
- Modify: `packages/zigeffect/test/workflow_scheduler_test.zig`

- [ ] **Step 1: Write the queue failure test**

Append to `packages/zigeffect/test/workflow_scheduler_test.zig`:

```zig
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
```

- [ ] **Step 2: Run and verify it passes with Task 4 implementation**

Run:

```bash
cd packages/zigeffect && zig build test-raw --summary all
```

Expected: all tests pass. If this fails, fix the existing `QueueWorker` failure
branch so typed handler errors call `DurableQueue.fail` and return
`QueueWorkerStep.failed`.

- [ ] **Step 3: Write the expired retry test**

Append to `packages/zigeffect/test/workflow_scheduler_test.zig`:

```zig
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
```

- [ ] **Step 4: Run the green tests**

Run:

```bash
cd packages/zigeffect && zig build test-raw --summary all
bun run zigeffect:test
```

Expected: both commands pass.

- [ ] **Step 5: Commit**

Run:

```bash
zig fmt --check packages/zigeffect/test/workflow_scheduler_test.zig
git add packages/zigeffect/test/workflow_scheduler_test.zig
git commit -m "test(zigeffect): cover scheduler queue failures and retries"
```

## Task 6: Graceful Shutdown, Drain Loop, And Budget Exhaustion

**Files:**
- Modify: `packages/zigeffect/src/workflow/scheduler.zig`
- Modify: `packages/zigeffect/test/workflow_scheduler_test.zig`

- [ ] **Step 1: Write the shutdown and drain tests**

Append to `packages/zigeffect/test/workflow_scheduler_test.zig`:

```zig
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
```

- [ ] **Step 2: Run the red test**

Run:

```bash
cd packages/zigeffect && zig build test-raw --summary all
```

Expected: failure because shutdown and `drain` APIs do not exist.

- [ ] **Step 3: Implement shutdown and drain**

Add a field to `WorkflowScheduler`:

```zig
    shutdown_requested: bool = false,
```

Add methods:

```zig
    pub fn requestShutdown(self: *WorkflowScheduler) void {
        self.shutdown_requested = true;
    }

    pub fn isShutdownRequested(self: *const WorkflowScheduler) bool {
        return self.shutdown_requested;
    }
```

Update the top of `tick`:

```zig
        var result = WorkflowSchedulerTickResult{
            .iterations = 1,
            .shutdown_requested = self.shutdown_requested,
        };
        if (self.shutdown_requested) return result;
```

Add `drain`:

```zig
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
```

- [ ] **Step 4: Run the green tests**

Run:

```bash
cd packages/zigeffect && zig build test-raw --summary all
bun run zigeffect:test
```

Expected: both commands pass.

- [ ] **Step 5: Commit**

Run:

```bash
zig fmt --check packages/zigeffect/src/workflow/scheduler.zig packages/zigeffect/test/workflow_scheduler_test.zig
git add packages/zigeffect/src/workflow/scheduler.zig packages/zigeffect/test/workflow_scheduler_test.zig
git commit -m "feat(zigeffect): add scheduler shutdown and drain budgets"
```

## Task 7: Architecture Docs, Roadmap Checklist, And Full Verification

**Files:**
- Modify: `packages/zigeffect/docs/architecture.md`
- Modify: `docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md`

- [ ] **Step 1: Update architecture documentation**

In `packages/zigeffect/docs/architecture.md`, add `scheduler.zig` to the
`src/workflow/` bullet list:

```markdown
- `scheduler.zig`: local cooperative workflow scheduler, runnable workflow
  worker registry, durable timer watches, typed durable queue workers, graceful
  shutdown, fair cursors, and bounded tick/drain budgets.
```

Add this paragraph after the workflow compaction section or before
`src/cluster/`:

```markdown
### Cooperative Local Scheduling

The workflow scheduler is a local orchestration boundary over the journal,
durable clock, and durable queues. It does not provide real async I/O or
distributed execution; it fairly visits registered workflow workers, timer
watches, and queue workers within explicit budgets and records durable progress
through existing workflow events. Later cluster and supervision modules should
reuse this boundary instead of bypassing the workflow journal.
```

- [ ] **Step 2: Mark Milestone 23 complete in the roadmap**

In `docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md`,
change Milestone 23 deliverables and acceptance to:

```markdown
Deliverables:

- [x] Add runnable work registry.
- [x] Add timer wake-up polling.
- [x] Add fair queue processing loop.
- [x] Add graceful shutdown.
- [x] Add bounded work budgets.

Acceptance:

- [x] Scheduler can drive multiple workflows and queues deterministically.
```

- [ ] **Step 3: Run the full Milestone 23 verification gate**

Run:

```bash
bun run zigeffect:test
cd packages/zigeffect && zig build examples
bun run zig:test
zig fmt --check packages/zigeffect/src/workflow/scheduler.zig packages/zigeffect/src/workflow/root.zig packages/zigeffect/src/zigeffect.zig packages/zigeffect/test/workflow_scheduler_test.zig packages/zigeffect/test/all_test.zig
git diff --check
rg -n 'TO''DO|TB''D|implement'' later|fill'' in' packages/zigeffect/src/workflow packages/zigeffect/test/workflow_scheduler_test.zig packages/zigeffect/docs/architecture.md docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md
```

Expected:

- `bun run zigeffect:test` exits 0.
- `zig build examples` exits 0.
- `bun run zig:test` exits 0.
- `zig fmt --check ...` exits 0.
- `git diff --check` exits 0.
- The `rg` placeholder scan exits 1 with no matches.

- [ ] **Step 4: Commit docs and roadmap completion**

Run:

```bash
git add packages/zigeffect/docs/architecture.md docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md
git commit -m "docs(zigeffect): mark cooperative scheduler complete"
```

## Milestone 23 Completion Checklist

- [ ] Scheduler surface committed.
- [ ] Runnable workflow fairness committed.
- [ ] Timer watch polling committed.
- [ ] Queue worker processing committed.
- [ ] Queue failure and retry tests committed.
- [ ] Shutdown and budget drain committed.
- [ ] Architecture and roadmap complete.
- [ ] Full verification gate passed.
