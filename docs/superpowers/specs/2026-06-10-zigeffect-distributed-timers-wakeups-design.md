# zigeffect Distributed Timers And Wakeups Design

Date: 2026-06-10

Milestone: 36 - Distributed Timers And Wakeups

## Goal

Make durable workflow timers safe across cluster shard movement. A timer
scheduled while runner A owns a workflow execution shard must be discoverable by
runner B after ownership moves, and firing the timer after migration must append
exactly one `timer_fired` event even when the wakeup is rebuilt or attempted
more than once.

This milestone builds the durable wakeup index and migration behavior on top of
the workflow journal and the cluster workflow entity command path from Milestone
35. It does not introduce real async IO, process supervision, remote networking,
or background scheduler threads; those remain explicit later milestones in the
roadmap.

## Existing Foundation

Workflow already provides:

- `DurableClock.dueTimers(now_ms)` for a single workflow execution.
- `DurableClock.fireDueTimers(now_ms)` for idempotent terminal timer mutation.
- `timer_scheduled`, `timer_fired`, `timer_cancelled`, and
  `workflow_resumed` journal events.
- `WorkflowScheduler` with local in-memory timer watches for non-clustered
  execution.

Cluster already provides:

- `EntityAddress` and deterministic shard routing.
- `LocalClusterRunner` and shard leases.
- `ClusterWorkflowEngine.fireDueTimers`, which routes timer firing through the
  shard-owned workflow execution entity.
- `ClusterWorkflowEntityRegistry.recoverOwnedExecutions`, which recreates
  workflow execution entities after shard acquisition.

The missing layer is a cluster-aware timer wakeup index that can be rebuilt from
durable journal events and filtered by current shard ownership.

## Public Surface

Add `packages/zigeffect/src/cluster/timer_wakeup.zig` and export it from:

- `fx.cluster.timer_wakeup`
- `fx.cluster.ClusterTimerWakeup`
- `fx.cluster.ClusterTimerWakeupBatch`
- `fx.cluster.ClusterTimerWakeupReport`
- `fx.cluster.ClusterTimerWakeupIndex`
- selected top-level `fx` aliases used by tests and examples.

The module is intentionally small and synchronous. It returns deterministic work
items and leaves actual command delivery to `ClusterWorkflowEngine`.

## Timer Ownership

Timer ownership is derived from workflow execution identity:

1. Each scheduled timer belongs to a workflow execution.
2. The workflow execution maps to `clusterWorkflowExecutionAddress(execution_id)`.
3. The address maps to a shard through `shardIdForAddress`.
4. A runner owns the timer only when it currently owns that shard.

This means timers migrate with the workflow execution shard. No separate timer
shard ring is introduced in this milestone.

Each indexed wakeup records:

- `workflow_id`
- `execution_id`
- `timer_id`
- `shard_id`
- `name`
- `fire_at_ms`
- `late_by_ms`

`late_by_ms` is zero for an indexed timer and is computed when a due batch is
requested.

## Rebuild Semantics

`ClusterTimerWakeupIndex.rebuildOwned(runner, journal_store)` scans the journal
and rebuilds its entire in-memory wakeup set.

The scan rules are:

- Only `timer_scheduled` events with a `timer_id` are candidates.
- `redacted_detail` must be parseable as `fire_at_ms=<u64>`.
- A candidate is skipped if a terminal event for the same
  `(workflow_id, execution_id, timer_id)` already exists.
- A candidate is skipped if its workflow execution shard is not currently owned
  by the runner.
- Duplicate schedule events for the same
  `(workflow_id, execution_id, timer_id)` are collapsed to one wakeup.

The method returns `ClusterTimerWakeupReport` with:

- `scanned`
- `indexed`
- `skipped_unowned`
- `skipped_terminal`
- `skipped_duplicate`

This report gives callers a way to assert that wakeup reconstruction happened
after shard acquisition and that unowned shards were not scheduled locally.

## Due And Late Timers

`ClusterTimerWakeupIndex.due(allocator, now_ms)` returns an owned
`ClusterTimerWakeupBatch`.

The batch includes only timers whose `fire_at_ms <= now_ms`. For every returned
wakeup:

```text
late_by_ms = now_ms - fire_at_ms
```

Late timers are not a separate error path. They remain due timers with a
diagnostic age. This keeps recovery simple: if a runner is down or a shard moves
after the fire time, the new owner fires the timer immediately and exposes how
late the wakeup was.

## Idempotent Firing

The wakeup index is not the source of truth for firing. It is a rebuilt guide.
The source of truth remains the workflow journal.

Actual timer mutation happens through:

```zig
ClusterWorkflowEngine.fireDueTimers(workflow_id, execution_id, now_ms)
```

The owning workflow execution entity calls:

```zig
DurableClock.fireDueTimers(now_ms)
```

`DurableClock.fireDueTimers` already skips timers with `timer_fired` or
`timer_cancelled` terminal events. This milestone adds cluster migration tests
that fire the same due timer twice through the entity command path and verify
that the journal contains one `timer_fired` event.

## Migration Flow

Timer migration after shard movement is:

1. Runner A owns the execution shard.
2. Runner A starts a workflow execution through `ClusterWorkflowEngine`.
3. Runner A appends `timer_scheduled` and `workflow_suspended` through the same
   workflow entity command path.
4. Runner A shuts down and releases the shard.
5. Runner B acquires the shard.
6. Runner B calls `ClusterWorkflowEntityRegistry.recoverOwnedExecutions`.
7. Runner B calls `ClusterTimerWakeupIndex.rebuildOwned`.
8. Runner B asks the wakeup index for due timers.
9. Runner B submits `fire_due_timers` for the due execution through
   `ClusterWorkflowEngine`.
10. Runner B processes the command with `ClusterWorkflowEntityHandler`.
11. The journal contains exactly one `timer_fired` event and one
    `workflow_resumed` event.

## Tests

Add `packages/zigeffect/test/cluster_timer_wakeup_test.zig`.

Coverage:

1. Public exports exist.
2. `ClusterTimerWakeupIndex.rebuildOwned` indexes a scheduled timer with the
   workflow execution shard id.
3. Rebuild filters timers whose execution shard is not currently owned.
4. Rebuild skips timers that already have `timer_fired` or `timer_cancelled`.
5. Rebuild collapses duplicate schedule records for the same timer id.
6. `due(now_ms)` reports late timers with `late_by_ms`.
7. Firing the same due timer twice through the cluster workflow entity appends
   exactly one `timer_fired`.
8. Migration acceptance: a timer scheduled on runner A fires exactly once after
   runner B acquires the shard and rebuilds wakeups from the journal.

## Documentation

Update `packages/zigeffect/docs/architecture.md` to include
`cluster/timer_wakeup.zig` and describe the journal-backed wakeup rebuild flow.

Mark Milestone 36 complete in the roadmap only after the full verification gate
passes.

## Completion Definition

Milestone 36 is complete when a cluster runner can rebuild owned timer wakeups
from the workflow journal after shard acquisition, report late due timers, and
fire migrated timers through the shard-owned workflow entity exactly once.
