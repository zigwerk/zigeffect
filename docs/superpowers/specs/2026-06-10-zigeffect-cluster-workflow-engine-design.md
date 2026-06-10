# zigeffect Cluster Workflow Engine Design

Date: 2026-06-10

Milestone: 35 - Cluster Workflow Engine

## Goal

Run durable workflow execution commands as shard-owned cluster entities. A
workflow execution id should map to one stable entity address, cluster transport
should route workflow commands to that address, and only the runner that owns
the shard should mutate the workflow journal.

This milestone integrates the existing local durable workflow journal, lifecycle
helpers, durable clock, deferred, queue, and signal vocabulary with the cluster
runtime from Milestones 31-34. It does not add production networking, real async
IO, global timer ownership indexes, queue claim leasing, or full distributed
workflow scheduling. Those are later roadmap milestones.

## Existing Foundation

Workflow already provides:

- `WorkflowEngine` for registration, deterministic workflow ids, execution ids,
  and workflow-start journal events.
- `JournalStore`, `InMemoryJournalStore`, and `FileJournalStore`.
- `WorkflowContext` for durable steps, activities, timers, deferreds, signals,
  queues, and compensation events.
- `DurableClock`, `DurableDeferred`, `DurableSignal`, `DurableQueue`, and
  `WorkflowLifecycle` helper modules that append to a `JournalStore`.

Cluster already provides:

- `EntityAddress` and deterministic shard routing.
- `MessageStorage` and cluster runtime processing by owned shard.
- `LocalClusterRunner` for shard acquisition, ticks, and recovery.
- `ClusterTransport`, in-process transport, and loopback HTTP transport.

M35 should compose these rather than creating another journal or another local
workflow runtime.

## Public Surface

Add `packages/zigeffect/src/cluster/workflow_engine.zig` and export it from:

- `fx.cluster.workflow_engine`
- `fx.cluster.cluster_workflow_entity_type`
- `fx.cluster.ClusterWorkflowCommandKind`
- `fx.cluster.ClusterWorkflowCommand`
- `fx.cluster.ClusterWorkflowCommandResult`
- `fx.cluster.ClusterWorkflowEngine`
- `fx.cluster.ClusterWorkflowEntityServices`
- `fx.cluster.ClusterWorkflowEntityRegistry`
- `fx.cluster.ClusterWorkflowEntityHandler`
- selected top-level `fx` aliases used by tests and examples.

## Entity Identity

Workflow executions use entity type:

```text
workflow.execution
```

`clusterWorkflowExecutionAddress(execution_id)` returns an `EntityAddress` whose
id is the execution id and whose entity type is `workflow.execution`.

This intentionally routes by execution id, not workflow id. Every command for a
single execution goes to one shard, and ownership transfer for that shard moves
journal mutation authority.

## Command Protocol

`ClusterWorkflowCommand` is a stable, JSON-serializable command envelope:

- `kind: ClusterWorkflowCommandKind`
- `workflow_id: WorkflowId`
- `execution_id: ExecutionId`
- `workflow_name: []const u8`
- `name: []const u8`
- `status: []const u8`
- `redacted_detail: []const u8`
- `idempotency_key: []const u8`
- `now_ms: u64`
- optional ids: `activity_id`, `timer_id`, `deferred_id`, `queue_id`,
  `compensation_id`
- `expected_next_sequence: ?JournalSequence`

Command kinds:

- `start`: append `workflow_started`.
- `append_event`: append a caller-specified workflow event kind and ids.
- `complete`: append `workflow_completed`.
- `suspend`: append `workflow_suspended` if currently running.
- `resume`: append `workflow_resumed` if currently suspended.
- `interrupt`: append `workflow_interrupted` through `WorkflowLifecycle`.
- `cancel`: append `workflow_cancelled` through `WorkflowLifecycle`.
- `fire_due_timers`: run `DurableClock.fireDueTimers(now_ms)`.
- `complete_deferred`: append `deferred_completed`, then resume if suspended.
- `fail_deferred`: append `deferred_failed`, then resume if suspended.
- `cancel_deferred`: append `deferred_cancelled`, then resume if suspended.
- `send_signal`: append `signal_received`, then resume if suspended.
- `complete_queue`: append `queue_completed`, then resume if suspended.
- `fail_queue`: append `queue_failed`, then resume if suspended.

Typed workflow functions and typed queue workers can still use the local
`WorkflowContext` and durable helpers directly when running inside the owning
entity. The command protocol exists so external runner/workflow control can be
durably routed through shard ownership.

## Command Result

`ClusterWorkflowCommandResult` is also JSON-serializable:

- `kind`
- `workflow_id`
- `execution_id`
- `appended: bool`
- `sequence: ?JournalSequence`
- `last_sequence: JournalSequence`
- `status: []const u8`
- `timers_fired: usize`

The cluster entity replies with this result for ask commands. The command is
idempotent where the underlying journal/lifecycle helper is idempotent; duplicate
journal events return `appended = false`.

## Cluster Workflow Engine

`ClusterWorkflowEngine` is a client facade over `ClusterTransport`.

It owns:

- allocator
- transport
- workflow command sequence

It exposes:

- `start(workflow_name, idempotency_key)`
- `appendEvent(command)`
- `complete(workflow_id, execution_id, detail)`
- `suspend(workflow_id, execution_id, reason)`
- `resume(workflow_id, execution_id, reason)`
- `interrupt(workflow_id, execution_id, reason)`
- `cancel(workflow_id, execution_id, reason)`
- `fireDueTimers(workflow_id, execution_id, now_ms)`
- `completeDeferred(workflow_id, execution_id, label, detail)`
- `sendSignal(workflow_id, execution_id, signal_name, encoded_payload,
  external_idempotency_key)`
- `completeQueue(workflow_id, execution_id, queue_name, queue_id, detail)`

Each method serializes a `ClusterWorkflowCommand` and sends it through
`ClusterTransport` to `clusterWorkflowExecutionAddress(execution_id)` with
payload type `application/vnd.zigeffect.cluster.workflow-command+json`.

The send result is a durable message submission. The command result is read from
`MessageStorage.reply(correlation_id)` after the owning runner processes its
shard.

## Entity Registration And Recovery

`ClusterWorkflowEntityRegistry` registers workflow execution entities on a
`LocalClusterRunner`.

It supports:

- `registerExecution(runner, journal_store, workflow_id, execution_id, now_ms)`
- `recoverOwnedExecutions(runner, journal_store, now_ms)`

`recoverOwnedExecutions` scans the journal for execution ids, computes each
execution entity shard, and registers only entities whose shard is owned by the
runner. This is the key migration behavior for this milestone: after shard
ownership moves, the new runner can rebuild the entity registry from durable
journal state and continue processing commands.

Each registered entity scope receives `ClusterWorkflowEntityServices` under a
stable service key. The services include the `JournalStore`.

## Entity Handler

`ClusterWorkflowEntityHandler.handle(scope, envelope)`:

1. Loads `ClusterWorkflowEntityServices` from the entity scope.
2. Parses the workflow command JSON from `envelope.payload`.
3. Verifies that the command execution id matches `envelope.address.id`.
4. Applies the command to the `JournalStore`.
5. Formats `ClusterWorkflowCommandResult` JSON as the reply.

Unsupported command kinds or invalid payloads fail the entity message. Failed
cluster messages remain replayable through existing message storage semantics.

## Durable Helper Semantics

This milestone proves the helper categories route through shard ownership:

- Timers: `fire_due_timers` calls `DurableClock.fireDueTimers`.
- Deferreds: complete/fail/cancel commands append terminal deferred events and
  resume the workflow when needed.
- Queues: complete/fail commands append queue terminal events and resume the
  workflow when needed.
- Signals: send command appends `signal_received` and resumes the workflow when
  needed.

Later milestones make these distributed-safe with ownership indexes, timer
migration indexes, queue claim leases, and stronger concurrency policy.

## Tests

Add `packages/zigeffect/test/cluster_workflow_engine_test.zig`.

Coverage:

1. Public exports exist.
2. `clusterWorkflowExecutionAddress` routes by execution id.
3. Command/result JSON round-trip.
4. Registering a workflow execution entity stores the journal service in the
   entity scope.
5. `ClusterWorkflowEngine.start` routes a command by execution id; the owning
   runner processes it; the journal contains `workflow_started`; the reply
   parses as a command result.
6. `complete`, `suspend`, `resume`, `interrupt`, and `cancel` commands mutate
   the journal through the owning entity.
7. Timer/deferred/queue/signal commands mutate the journal through the owning
   entity and resume suspended workflows when appropriate.
8. Migration acceptance: runner A owns the workflow shard and processes
   `start`; runner A releases the shard; runner B acquires it, recovers the
   workflow execution entity from the journal, processes `complete`, and the
   journal replays to completed.

## Documentation

Update `packages/zigeffect/docs/architecture.md` to include
`cluster/workflow_engine.zig`.

Mark Milestone 35 complete in the roadmap only after the full verification gate
passes.

## Completion Definition

Milestone 35 is complete when workflow execution commands are routed by
execution id to shard-owned entities, journal mutation happens only in the
owning entity handler, timer/deferred/queue/signal command surfaces append
through that same path, and a workflow started on runner A can resume and
complete on runner B after shard ownership migration.
