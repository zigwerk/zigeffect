# zigeffect Cluster Durable Queues Design

Date: 2026-06-10

Milestone: 37 - Cluster Durable Queues

## Goal

Make durable workflow queues safe across runner boundaries. Queue offers,
claims, retries, completions, and failures must remain workflow-journal events,
but cluster runners need a shard-owned queue work index and workflow-entity
commands so a claimed item can return to the cluster when the runner that
claimed it crashes.

This milestone builds the queue cluster layer on top of the existing durable
queue journal vocabulary and the Milestone 35 cluster workflow entity command
path. It does not introduce real async IO, remote network transports beyond the
existing loopback abstraction, SQL storage, or split-brain fencing. Lease epoch
fencing is Milestone 38.

## Existing Foundation

Workflow already provides:

- `Queue` typed definitions with idempotency keys, claim timeouts, and
  max-concurrency metadata.
- `DurableQueue.offer`, `claim`, `retryExpiredClaims`, `complete`, and `fail`.
- Queue journal event kinds: `queue_offered`, `queue_claimed`,
  `queue_retry_scheduled`, `queue_completed`, `queue_failed`, and
  `queue_acked`.
- Queue claim details in the form:

```text
worker=<worker-id> claim_deadline_ms=<u64|null> attempt=<n>
```

Cluster already provides:

- Deterministic workflow execution entity sharding.
- Durable message transport to the shard-owned workflow entity.
- `ClusterWorkflowEngine.completeQueue` and `failQueue`.
- Workflow entity recovery after shard migration.

The missing layer is a type-agnostic cluster queue work index and queue claim
commands that mutate the journal from the owning workflow entity.

## Public Surface

Add `packages/zigeffect/src/cluster/queue.zig` and export it from:

- `fx.cluster.queue`
- `fx.cluster.ClusterQueueStatus`
- `fx.cluster.ClusterQueueItem`
- `fx.cluster.ClusterQueueBatch`
- `fx.cluster.ClusterQueueRebuildReport`
- `fx.cluster.ClusterQueueClaimLimits`
- `fx.cluster.ClusterQueueIndex`
- selected top-level `fx` aliases used by tests and examples.

Extend `packages/zigeffect/src/cluster/workflow_engine.zig` with:

- `ClusterWorkflowCommandKind.claim_queue`
- `ClusterWorkflowCommandKind.retry_expired_queues`
- `ClusterWorkflowEngine.claimQueue`
- `ClusterWorkflowEngine.retryExpiredQueues`
- result fields for `queue_id`, `queue_attempt`, `queue_claimed`, and
  `queue_retried`.

Existing result JSON remains backward compatible because added fields have
defaults and existing parsers ignore unknown fields.

## Queue Ownership And Sharding

Queue work is owned by the workflow execution shard, not by a separate global
queue shard ring.

For every queue item:

1. Read `workflow_id`, `execution_id`, `queue_id`, and queue `name` from the
   journal event.
2. Map `execution_id` to `clusterWorkflowExecutionAddress(execution_id)`.
3. Compute `shard_id` with `shardIdForAddress`.
4. A runner may process the item only when it owns that shard.

This keeps queue claims, retry rows, completions, failures, and workflow resume
events serialized through the same workflow execution entity that owns the rest
of the durable workflow state.

## Rebuild Semantics

`ClusterQueueIndex.rebuildOwned(runner, journal_store)` scans the workflow
journal and rebuilds an in-memory view of queue work owned by the runner.

The scan rules are:

- `queue_offered` creates or refreshes an item.
- `queue_claimed` marks the item claimed and records worker, deadline, attempt,
  and claim sequence.
- `queue_retry_scheduled` marks the item retry-ready.
- `queue_completed`, `queue_failed`, and `queue_acked` mark terminal or
  consumed state.
- Events whose workflow execution shard is not owned by the runner are skipped.
- Duplicate offer rows for the same `(workflow_id, execution_id, queue_id)` are
  collapsed.
- Unknown queue status order is interpreted by journal sequence order.

Each `ClusterQueueItem` records:

- `workflow_id`
- `execution_id`
- `queue_id`
- `shard_id`
- `name`
- `payload`
- `status`
- `attempt`
- `claim_worker`
- `claim_deadline_ms`
- `claim_sequence`

Payload is the `redacted_detail` from `queue_offered`. It stays encoded until a
typed worker decodes it.

## Claimable Work And Limits

`ClusterQueueIndex.claimable(allocator, limits)` returns owned items whose
status is `offered` or `retry_ready`.

`ClusterQueueClaimLimits` includes:

- `max_per_runner`
- `max_per_queue`

The index applies limits before a runner attempts claims:

- `max_per_runner` caps the total returned item count.
- `max_per_queue` caps items returned for each queue name.
- Zero means no items for that limit.

The workflow entity command still validates per-queue concurrency when appending
the actual claim. The index limits are selection limits; the command is the
durable journal guard.

## Claim Leases And Expiration

Claim leases are represented by the existing `queue_claimed.redacted_detail`
deadline. A null deadline means the claim does not expire.

`ClusterQueueIndex.expiredClaims(allocator, now_ms)` returns owned claimed
items whose deadline is present and `<= now_ms`.

`ClusterWorkflowEngine.retryExpiredQueues(workflow_id, execution_id, queue_name,
now_ms)` routes to the workflow entity. The entity scans the journal and appends
`queue_retry_scheduled` for every expired claim in that workflow execution and
queue name.

The retry row keeps the previous claim sequence and attempt in
`redacted_detail`:

```text
claim_sequence=<sequence> attempt=<attempt>
```

This matches the local durable queue retry shape.

## Queue Claim Command

`ClusterWorkflowEngine.claimQueue` sends a shard-routed command with:

- `workflow_id`
- `execution_id`
- `queue_id`
- `queue_name`
- `worker_id`
- `now_ms`
- `claim_timeout_ms`
- `max_concurrency`

The workflow entity appends a `queue_claimed` row only when:

- the queue item exists,
- the latest queue status is `offered` or `retry_ready`,
- active claims for the queue name are below `max_concurrency`.

The appended detail is:

```text
worker=<worker-id> claim_deadline_ms=<deadline|null> attempt=<next-attempt>
```

The command result records whether a claim was appended and the attempt number.

## Completion And Failure Routing

Worker completions and failures continue to use:

- `ClusterWorkflowEngine.completeQueue`
- `ClusterWorkflowEngine.failQueue`

Those commands route through the owning workflow entity and append
`queue_completed` or `queue_failed`, then resume a suspended workflow if needed.

This milestone proves the complete path, but leaves richer typed worker APIs for
later ergonomics if the core remains simpler without them.

## Crash Return Flow

The acceptance flow is:

1. Runner A owns a workflow execution shard.
2. Runner A starts a workflow, appends `queue_offered`, and appends
   `workflow_suspended` for the queue wait.
3. Runner A claims the queue item through `ClusterWorkflowEngine.claimQueue`
   with a finite lease deadline.
4. Runner A shuts down before completing.
5. Runner B acquires the shard and recovers the workflow execution entity.
6. Runner B rebuilds `ClusterQueueIndex` and sees the item as expired.
7. Runner B routes `retryExpiredQueues` through the workflow entity.
8. Runner B rebuilds or updates the index and claims the item as attempt 2.
9. Runner B completes the item through `completeQueue`.
10. The journal contains `queue_retry_scheduled`, a second `queue_claimed`,
    `queue_completed`, and `workflow_resumed`.

## Tests

Add `packages/zigeffect/test/cluster_queue_test.zig`.

Coverage:

1. Public exports exist.
2. Queue index stores queue item ownership by workflow execution shard.
3. Rebuild filters unowned queue work.
4. Rebuild tracks offered, claimed, retry-ready, completed, failed, and acked
   status by sequence order.
5. Claimable selection respects max-per-runner and max-per-queue limits.
6. Expired claim selection returns only claimed items whose deadline has passed.
7. `ClusterWorkflowEngine.claimQueue` appends durable queue claims through the
   owning workflow entity and enforces max concurrency.
8. `ClusterWorkflowEngine.retryExpiredQueues` appends retry rows through the
   owning workflow entity.
9. Migration acceptance: a queue item claimed on runner A returns to the
   cluster after runner A shuts down, then runner B retries, reclaims, and
   completes it.

## Documentation

Update `packages/zigeffect/docs/architecture.md` to include
`cluster/queue.zig`.

Mark Milestone 37 complete in the roadmap only after the full verification gate
passes.

## Completion Definition

Milestone 37 is complete when queue work is rebuilt by shard ownership, claim
leases can expire and return work to the cluster, claim commands and worker
completions mutate the workflow journal through the owning entity, and tests
prove a runner crash returns claimed work for another runner to complete.
