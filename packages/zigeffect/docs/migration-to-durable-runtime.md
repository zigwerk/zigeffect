# Migration To Durable Runtime

Date: 2026-06-10

This guide shows how to move from deterministic-only `zigeffect` programs to
the durable workflow and local cluster runtime.

## Keep Plain Zig Handlers

Deterministic programs usually start as plain functions wrapped by `Effect`:

```zig
fn program(ctx: *fx.Context(AppEnv)) AppError!Result {
    const logger = ctx.service(fx.Logger);
    try logger.info("running");
    return .{};
}
```

Keep that shape for durable code. Durable workflow, activity, and actor
handlers are still direct-style Zig functions. The migration is about adding
durable identity, journals, queues, clocks, signals, and runner ownership.

## Add Durable Workflow Identity

Use stable workflow and execution ids:

```zig
const workflow_id = fx.workflow.workflowId("approval");
const execution_id = fx.workflow.executionId("approval", "case-42");
```

For typed definitions, attach idempotency keys so retries and restarts reuse the
same execution identity:

```zig
const Approval = fx.workflow
    .Workflow("approval", ApprovalPayload, ApprovalResult, ApprovalError, AppEnv)
    .withIdempotencyKey(approvalKey);
```

## Replace In-Memory Progress With A Journal

Deterministic code can keep progress in memory. Durable workflows must append
state transitions to a `JournalStore`.

Single-process tests can use:

```zig
var journal_state = fx.workflow.InMemoryJournalStore.init(allocator);
defer journal_state.deinit();
const journal = journal_state.asJournalStore();
```

Crash recovery and local release checks should use:

```zig
var journal_state = try fx.workflow.FileJournalStore.open(allocator, io, dir, .{});
defer journal_state.deinit();
const journal = journal_state.asJournalStore();
```

Reopen the file store after restart and call `latestState` or initialize a new
`WorkflowContext` from the same journal.

## Move Time, Signals, And Queues To Durable Primitives

Use deterministic services for tests, then durable workflow primitives for
runtime boundaries:

| Deterministic-only shape | Durable runtime shape |
| --- | --- |
| `fx.Clock` sleep in tests | `fx.workflow.DurableClock` and `WorkflowContext.sleep` |
| in-memory callback | `fx.workflow.DurableSignal` and `WorkflowContext.waitForSignal` |
| `fx.Queue` for local coordination | `fx.workflow.DurableQueue` and `WorkflowContext.queue` |
| local promise state | `fx.workflow.DurableDeferred` |

Durable operations append journal rows before they suspend or resume, so replay
can recover the exact state after a crash.

## Add Durable Cluster Storage

Local actors can start with `LocalEntityRuntime` and `LocalMailboxStore`.
Multi-runner local clustering needs durable message and runner storage:

```zig
var runner_storage = try fx.FileRunnerStorage.open(allocator, io, dir, .{});
defer runner_storage.deinit();

var message_storage = try fx.FileMessageStorage.open(allocator, io, dir, .{});
defer message_storage.deinit();
```

The runner uses these stores to acquire shard leases and persist messages:

```zig
var runner = try fx.LocalClusterRunner.init(allocator, .{
    .runner = fx.runnerAddress("machine-a", "runner-a"),
    .runner_storage = runner_storage.asRunnerStorage(),
    .message_storage = message_storage.asMessageStorage(),
    .shard_count = 8,
    .runner_index = 0,
    .runner_count = 2,
});
defer runner.deinit();
```

## Recover Cluster Workflow Executions

Cluster workflow execution recovery uses the workflow journal plus the runner's
owned shards:

```zig
var registry = fx.ClusterWorkflowEntityRegistry.init(allocator);
defer registry.deinit();

const recovery = try registry.recoverOwnedExecutions(&runner, journal, now_ms);
```

After recovery, workflow commands can be routed through
`ClusterWorkflowEngine` and handled by `ClusterWorkflowEntityHandler`.

## Validate The Migration

Run the release gate from the repository root:

```bash
bun run zigeffect:release
```

Or from the package directory:

```bash
cd packages/zigeffect
zig build release-gate
```

The release gate covers public API stability, durable storage conformance,
property crash recovery, bounded resources, causal workflow crash recovery
artifacts, the crash recovery example, and the multi-runner cluster migration
example.
