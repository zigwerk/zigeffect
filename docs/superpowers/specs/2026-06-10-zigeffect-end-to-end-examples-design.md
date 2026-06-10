# zigeffect End-To-End Examples Design

Date: 2026-06-10

Milestone: 44 - End-To-End Examples

## Goal

Add runnable examples that explain the durable workflow and local cluster
runtime through complete, tested stories:

- local approval workflow;
- durable queue worker;
- timer and signal workflow;
- local actor;
- multi-runner local cluster;
- cluster workflow migration.

The examples must compile as executables and run their own tests through
`zig build examples`.

## Current Context

Existing examples live under `packages/zigeffect/examples/`. Each example is a
single Zig module with:

- `const fx = @import("zigeffect");`
- a `main` function for humans running the executable;
- one or more `test` blocks in the same file;
- build wiring in `packages/zigeffect/build.zig` as an executable, a test
  artifact, and dependencies of the aggregate `examples` step.

The workflow and cluster runtime already expose the APIs needed for this
milestone:

- workflow journals: `InMemoryJournalStore`, `FileJournalStore`, `JournalStore`;
- workflow context operations: `WorkflowContext.sleep`,
  `WorkflowContext.waitForSignal`, and `WorkflowContext.queue`;
- external durable helpers: `DurableClock`, `DurableSignal`, `DurableQueue`;
- cluster actors: `LocalEntityRuntime`, `EntityScope`, `EntityHandlerResult`;
- durable cluster runtime: `ClusterRuntime`, `LocalClusterRunner`,
  `LocalClusterRouter`, shared message storage, and runner storage;
- cluster workflow routing: `ClusterWorkflowEngine`,
  `ClusterWorkflowEntityRegistry`, `ClusterWorkflowEntityHandler`, and
  `InProcessClusterTransport`.

## Selected Architecture

Create six example modules, one per roadmap deliverable:

- `packages/zigeffect/examples/workflow_approval.zig`
- `packages/zigeffect/examples/workflow_queue_worker.zig`
- `packages/zigeffect/examples/workflow_timer_signal.zig`
- `packages/zigeffect/examples/local_actor.zig`
- `packages/zigeffect/examples/multi_runner_cluster.zig`
- `packages/zigeffect/examples/cluster_workflow_migration.zig`

Each module owns a small scenario runner that returns a typed report struct.
`main` prints that report in stable text. Tests call the scenario runner and
assert the durable facts that make the example useful.

The examples should stay self-contained. Small helpers such as payload codecs,
entity handlers, address search, and workflow submission processing can live in
the example file that uses them. This keeps each file readable without adding a
second public support API for examples.

## Example Stories

### Local Approval Workflow

The approval example starts a workflow in an append-only file journal, waits for
an `approval` signal, closes the store, reopens it, sends the signal through
`DurableSignal`, and replays the workflow context to receive the approved value.

The report includes:

- workflow id;
- execution id;
- whether the first pass suspended;
- approved value;
- final workflow status;
- total journal events.

The test asserts that the workflow suspends before the signal, receives the
signal after reopen, and keeps durable state in the same workflow execution.

### Durable Queue Worker

The queue worker example offers a durable `email` queue item from a workflow,
observes the workflow suspension, claims the item as a worker, completes it,
and replays the workflow context to read the result and ack the item once.

The report includes:

- queue item id;
- account id;
- worker id;
- completed result value;
- whether replay acked the item;
- total journal events.

The test asserts that the queue item is offered idempotently, claimed by the
worker, completed, resumed, and acked exactly once.

### Timer And Signal Workflow

The timer/signal example combines two durable waits in one local journal. It
schedules a `review-timeout` timer with `WorkflowContext.sleep`, fires it with
`DurableClock`, then waits for an `approval` signal and receives it through
`DurableSignal`.

The report includes:

- timer id;
- fired timer count;
- signal value;
- number of timer events;
- number of signal events.

The test asserts that the timer wait suspends before firing, resumes after
`fireDueTimers`, and the signal wait receives the external signal.

### Local Actor

The local actor example registers a counter entity in `LocalEntityRuntime`,
sends a `tell` message to increment state, sends an `ask` message to read
state, processes messages with a handler, and reads the reply.

The report includes:

- entity address;
- processed message count;
- final counter value;
- reply payload.

The test asserts FIFO processing, state mutation through `EntityScope`
services, reply storage, and an empty mailbox after processing.

### Multi-Runner Local Cluster

The multi-runner example opens shared file-backed runner and message storage,
starts two `LocalClusterRunner` instances, acquires balanced shards, routes one
ask message to each runner-owned entity through the shared router, ticks both
runners, and reads both replies from shared message storage.

The report includes:

- runner A shard count;
- runner B shard count;
- runner A dispatch count;
- runner B dispatch count;
- both reply payloads.

The test asserts the balanced shard split, durable routing through shared
storage, per-runner dispatch, and stored replies.

### Cluster Workflow Migration

The migration example starts a workflow command on runner A through
`ClusterWorkflowEngine`, processes it through the workflow entity handler,
shuts down runner A, starts runner B over the same file-backed journal and
storage, recovers owned workflow executions, completes the workflow from runner
B, and reads the final journal state.

The report includes:

- workflow id;
- execution id;
- runner A start status;
- recovered execution count;
- runner B completion status;
- final workflow status.

The test asserts that runner A appends `workflow_started`, runner B recovers the
execution entity, completion appends through the new owner, and the final
workflow state is completed.

## Build Wiring

`packages/zigeffect/build.zig` will add one module, executable, test artifact,
and `examples_step` dependency pair for each new file.

Names:

- `zigeffect-workflow-approval-example`
- `zigeffect-workflow-queue-worker-example`
- `zigeffect-workflow-timer-signal-example`
- `zigeffect-local-actor-example`
- `zigeffect-multi-runner-cluster-example`
- `zigeffect-cluster-workflow-migration-example`

Each module imports only `zigeffect` and `std`.

## Testing Strategy

TDD will be applied per example:

1. Add the example module and a test that names the desired report facts.
2. Wire the module into `build.zig`.
3. Run `zig build examples` and confirm the new test fails for missing scenario
   behavior.
4. Implement the minimal scenario runner and `main`.
5. Re-run `zig build examples`.
6. Commit the example slice.

The full milestone gate is:

```bash
(cd packages/zigeffect && zig build examples)
bun run zigeffect:test
bun run zig:test
zig fmt --check \
  packages/zigeffect/examples/workflow_approval.zig \
  packages/zigeffect/examples/workflow_queue_worker.zig \
  packages/zigeffect/examples/workflow_timer_signal.zig \
  packages/zigeffect/examples/local_actor.zig \
  packages/zigeffect/examples/multi_runner_cluster.zig \
  packages/zigeffect/examples/cluster_workflow_migration.zig \
  packages/zigeffect/build.zig
git diff --check
```

The scoped marker scan for this milestone includes the six example files,
`build.zig`, this spec, the M44 implementation plan, README updates, and the
durable workflows/clustering roadmap.

## Documentation

Update `packages/zigeffect/README.md` so users can discover the new examples
and run `zig build examples`. Update the durable workflows/clustering roadmap
so all M44 deliverables and the acceptance checkbox are marked complete after
the full gate passes.

## Alternatives Considered

1. One large `durable_workflows_and_cluster.zig` example. This would show a
   complete journey, but it would make each concept harder to locate and harder
   to test independently.
2. Docs-only examples. This would be faster, but it would not satisfy the
   roadmap acceptance because examples must compile and run through
   `zig build examples`.
3. Six focused executable examples. This is selected because it matches the
   existing build pattern, gives each concept a searchable file, and makes the
   examples act as regression tests.

## Risks And Controls

- Risk: examples accidentally become copy-pasted test fixtures that are hard to
  read. Control: each example returns a named report and prints stable text.
- Risk: cluster examples duplicate helper logic. Control: keep helpers small
  and local to the file that needs them.
- Risk: file-backed examples leave artifacts outside Zig cache or temp dirs.
  Control: tests use `std.testing.tmpDir`; `main` uses in-memory stores unless
  file-backed behavior is the point of the example.
- Risk: examples overclaim distributed behavior. Control: wording and printed
  reports describe the current local deterministic runtime and file-backed
  storage shape.

## Acceptance Checklist

- Local approval workflow example exists, compiles, and tests durable signal
  resume after reopen.
- Durable queue worker example exists, compiles, and tests offer, claim,
  complete, replay, and ack.
- Timer and signal workflow example exists, compiles, and tests both wait
  kinds.
- Local actor example exists, compiles, and tests tell, ask, state, and reply.
- Multi-runner local cluster example exists, compiles, and tests shared storage
  routing across two runners.
- Cluster workflow migration example exists, compiles, and tests runner A to
  runner B workflow ownership recovery.
- `zig build examples` compiles and runs all examples.
