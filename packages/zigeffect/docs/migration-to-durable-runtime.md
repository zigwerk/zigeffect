# Migration to the durable runtime

**Original guide:** 2026-06-10; **canonical-kernel review:** 2026-07-15

This guide shows how to move from deterministic-only `zigeffect` programs to
the durable workflow and local cluster runtime.

Durable workflow and cluster domains still contain environment-parameterized
compatibility APIs. Do not move an otherwise canonical application back to the
legacy composition model. Isolate those adapters behind a module facade and
keep the process root on one `zstd.ManagedRuntime` while the durable surface is
migrated. It embeds the durable NenDB causal graph around the I/O-free kernel
interpreter.

## Keep canonical domain operations

Deterministic domain operations remain direct Zig functions wrapped by a
canonical effect:

```zig
const Repository = fx.kernel.Service("orders/Repository", RepositoryApi);
const Program = fx.kernel.Effect(Result, AppError, .{Repository});

const program = Program.fromFn(struct {
    fn run(ctx: *Program.Context) AppError!Result {
        return ctx.service(Repository).load();
    }
}.run).named("orders.workflow-input");
```

Durable workflow, activity, and actor handlers are also direct-style Zig
functions. The migration adds durable identity, journals, queues, clocks,
signals, and runner ownership; it does not create a second application runtime.

## Add Durable Workflow Identity

Use stable workflow and execution ids:

```zig
const workflow_id = fx.workflow.workflowId("approval");
const execution_id = fx.workflow.executionId("approval", "case-42");
```

For typed definitions, attach idempotency keys so retries and restarts reuse the
same execution identity. The current `AppEnv` parameter below is a durable
compatibility boundary and must not escape into ordinary application modules:

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
