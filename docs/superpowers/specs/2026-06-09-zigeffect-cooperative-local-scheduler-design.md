# zigeffect Cooperative Local Scheduler Design

Date: 2026-06-09

## Context

Milestone 23 adds the first local scheduler on top of the durable workflow
journal, timer, queue, lifecycle, and backend contracts already built. The
current workflow modules can start executions, fold journal replay state, fire
durable timers, claim and finish durable queue items, and record lifecycle
controls. There is no scheduler module yet, and the workflow engine does not
execute arbitrary suspended workflow bodies through a real async backend.

This milestone creates the deterministic local loop that later async,
supervision, and clustering milestones can reuse. It is cooperative: callers
register work sources, the scheduler visits them in fair order, and every pass
has explicit budgets. It does not spawn operating-system threads, block on I/O,
or pretend that the deterministic backend is a green-thread runtime.

## Design Choice

Three approaches were considered:

1. Add a thin journal-backed scheduler module under `src/workflow/`.
2. Fold scheduler state into `WorkflowEngine`.
3. Build the async backend adapter first and hang scheduling off that adapter.

The selected approach is option 1. A scheduler module can depend on
`WorkflowEngine`, `DurableClock`, `DurableQueue`, replay state, and lifecycle
controls without making the engine own queue workers, timers, or shutdown
policy. Keeping the scheduler separate also gives cluster and supervision code a
stable orchestration boundary to build on.

## Goals

- Add `workflow/scheduler.zig` as the local cooperative scheduler domain.
- Add a runnable workflow worker registry with fair cursor rotation.
- Add timer watches that fire due durable timers through `DurableClock`.
- Add typed durable queue worker registration, expired-claim retries, queue
  claim processing, completion, and failure.
- Add graceful shutdown controls that stop new cooperative work from being
  claimed or polled.
- Add bounded tick and drain APIs with explicit counters and budget exhaustion
  reporting.
- Export scheduler types through `workflow/root.zig`; the existing
  `fx.workflow` namespace makes them available from `zigeffect.zig`.
- Cover fairness, budgets, shutdown, timers, queue processing, and public exports
  with tests.

## Milestone Boundary

This milestone implements the local deterministic scheduler contract and the
durable queue/timer progress loop. Real async I/O, multi-runner transport, shard
leasing, distributed cluster membership, and complete supervision trees are
separate roadmap milestones with their own storage and runtime requirements.
Milestone 23 still leaves extension points for them by using type-erased worker
registrations and by keeping all progress evidence in the workflow journal.

## Public API

Create `packages/zigeffect/src/workflow/scheduler.zig`.

Core scheduler types:

```zig
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

    pub fn progressed(self: WorkflowSchedulerTickResult) bool;
    pub fn merge(self: *WorkflowSchedulerTickResult, other: WorkflowSchedulerTickResult) void;
};
```

Registered workflow worker:

```zig
pub const RegisteredWorkflowWorker = struct {
    context: *anyopaque,
    workflow_id: WorkflowId,
    execution_id: ExecutionId,
    name: []const u8,
    poll_fn: *const fn (*anyopaque) anyerror!RunnableWorkflowStep,

    pub fn poll(self: RegisteredWorkflowWorker) anyerror!RunnableWorkflowStep;
};
```

Timer watch:

```zig
pub const TimerWatch = struct {
    workflow_id: WorkflowId,
    execution_id: ExecutionId,
};
```

Registered queue worker:

```zig
pub const RegisteredQueueWorker = struct {
    context: *anyopaque,
    workflow_id: WorkflowId,
    execution_id: ExecutionId,
    name: []const u8,
    retry_expired_fn: *const fn (*anyopaque) anyerror!usize,
    process_one_fn: *const fn (*anyopaque) anyerror!QueueWorkerStep,

    pub fn retryExpired(self: RegisteredQueueWorker) anyerror!usize;
    pub fn processOne(self: RegisteredQueueWorker) anyerror!QueueWorkerStep;
};
```

Typed queue worker helper:

```zig
pub fn QueueWorker(
    comptime QueueType: type,
    comptime Handler: *const fn (
        QueueType.PayloadType,
        u32,
    ) QueueType.FailureType!QueueType.SuccessType,
) type;
```

The generated queue worker state stores a `DurableQueue`, payload codec, result
codec, worker id, and handler. `processOne` claims one item, calls the handler,
records `queue_completed` on success, records `queue_failed` on typed failure,
and returns the affected queue id. `retryExpired` delegates to
`DurableQueue.retryExpiredClaims`.

Scheduler:

```zig
pub const WorkflowScheduler = struct {
    pub fn init(allocator: Allocator, journal_store: JournalStore, clock: *Clock) WorkflowScheduler;
    pub fn deinit(self: *WorkflowScheduler) void;

    pub fn registerWorkflowWorker(self: *WorkflowScheduler, worker: RegisteredWorkflowWorker) Allocator.Error!void;
    pub fn registerTimerWatch(self: *WorkflowScheduler, watch: TimerWatch) Allocator.Error!void;
    pub fn registerQueueWorker(self: *WorkflowScheduler, worker: RegisteredQueueWorker) Allocator.Error!void;

    pub fn requestShutdown(self: *WorkflowScheduler) void;
    pub fn isShutdownRequested(self: *const WorkflowScheduler) bool;

    pub fn tick(self: *WorkflowScheduler, budget: WorkflowSchedulerBudget) anyerror!WorkflowSchedulerTickResult;
    pub fn drain(self: *WorkflowScheduler, budget: WorkflowSchedulerBudget) anyerror!WorkflowSchedulerTickResult;
};
```

## Runtime Behavior

`tick` performs at most one cooperative pass. If shutdown has been requested, it
returns with `shutdown_requested = true` and does not poll workflows, fire
timers, retry queues, or claim queue items.

When active, `tick` visits registered workflow workers from the current workflow
cursor, up to `max_workflow_polls`. Each visit increments `workflow_polls`.
`progressed`, `completed`, and `failed` outcomes increment the corresponding
counters. The cursor advances after each visit so repeated ticks do not starve
later workers.

Timer watches are visited from a timer cursor, up to `max_timers` watches per
tick. For each watch, the scheduler constructs a `DurableClock` and calls
`fireDueTimers(clock.nowMs())`. The returned count is added to `timers_fired`.
The cursor advances after each watch.

Queue workers are visited in two phases. First, the scheduler retries expired
claims up to `max_queue_retries` worker visits and accumulates
`queue_retries`. Second, it processes at most `max_queue_claims` worker visits
from the queue cursor. Each non-idle claim increments `queue_claims`; completed
and failed results increment `queue_completions` and `queue_failures`.

`drain` repeatedly calls `tick` until one pass makes no progress, shutdown is
requested, or `max_iterations` passes have been consumed. If the last pass still
made progress and the iteration budget is exhausted, `budget_exhausted` is set
on the merged result.

## Error Handling

Scheduler methods return allocator and journal errors directly. Queue handler
typed failures are not scheduler failures; they are durable queue outcomes and
are recorded with `DurableQueue.fail`. Unexpected codec, journal, or allocation
failures return from `tick` or `drain`.

Registration APIs copy registration structs by value but do not own worker
contexts. The caller owns any concrete queue or workflow worker state and must
keep it alive until the scheduler is deinitialized or the worker is no longer
registered.

## Testing Strategy

Add `packages/zigeffect/test/workflow_scheduler_test.zig` and import it from
`packages/zigeffect/test/all_test.zig`.

Tests cover:

- Public exports for scheduler types at `fx.workflow`.
- Runnable workflow fairness by registering three fake workflow workers, giving
  `max_workflow_polls = 1`, and asserting successive ticks visit workers in
  rotating order.
- Timer wake-up polling by scheduling two timers on one journal and asserting
  scheduler `tick` fires due timers and resumes the workflow through existing
  durable clock events.
- Queue worker success by offering two queue items, registering a typed queue
  worker, draining with bounded queue claims, and asserting handler calls,
  `queue_completed`, and `workflow_resumed` events.
- Queue worker failure by returning a typed queue error and asserting
  `queue_failed` and `queue_failures`.
- Expired claim retry by using `FakeClock`, claim timeout metadata, and
  `queue_retries`.
- Shutdown by requesting shutdown before a tick and asserting no workflow,
  timer, or queue counters change.
- Budget exhaustion by limiting `max_iterations` or `max_queue_claims` and
  asserting progress stops at the requested budget.

Verification commands:

```bash
bun run zigeffect:test
cd packages/zigeffect && zig build examples
bun run zig:test
zig fmt --check packages/zigeffect/src/workflow/scheduler.zig packages/zigeffect/src/workflow/root.zig packages/zigeffect/src/zigeffect.zig packages/zigeffect/test/workflow_scheduler_test.zig packages/zigeffect/test/all_test.zig
git diff --check
rg -n 'TO''DO|TB''D|implement'' later|fill'' in' packages/zigeffect/src/workflow packages/zigeffect/test/workflow_scheduler_test.zig packages/zigeffect/docs/architecture.md docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md
```
