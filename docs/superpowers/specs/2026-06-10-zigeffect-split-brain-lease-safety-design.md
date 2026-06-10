# zigeffect Split-Brain And Lease Safety Design

Date: 2026-06-10

Milestone: 38 - Split-Brain And Lease Safety

## Goal

Make stale shard owners harmless. If runner A still has local memory that says it
owns a shard after runner B has acquired a newer lease epoch, runner A must not
be able to mutate the durable mailbox or workflow journal for that shard.

This milestone adds lease epochs and fencing validation to the cluster runtime
and workflow entity command path. It does not add distributed consensus, clock
synchronization, or storage-specific compare-and-swap primitives beyond the
current local/file stores.

## Existing Foundation

Cluster already provides:

- `ShardLease.version`, which increments on acquire-after-expiry and refresh.
- `RunnerStorage.lease(shard_id)`, which can read the current durable lease.
- `LocalShardLeaseManager.owned_leases`, which records local runner ownership.
- `ClusterRuntime.processShard`, which gates message processing by local shard
  ownership.
- `ClusterWorkflowEntityHandler`, which performs workflow journal mutation from
  the owning entity.

The gap is that local ownership alone is not enough after split-brain. A stale
runner can still have a shard id in memory. We need a durable acquisition epoch
that changes only when ownership changes and a fence check against current
runner storage before shard-owned writes.

## Public Surface

Add `packages/zigeffect/src/cluster/fencing.zig` and export:

- `fx.cluster.fencing`
- `fx.cluster.ShardLeaseEpoch`
- `fx.cluster.ShardLeaseFence`
- `fx.cluster.FenceValidationError`
- `fx.cluster.fenceFromLease`
- `fx.cluster.validateShardFence`
- `fx.cluster.formatShardFenceDiagnostic`

Add `epoch: ShardLeaseEpoch` to `ShardLease`.

Extend cluster runtime errors with `StaleShardFence`.

## Lease Epoch Semantics

`ShardLease` keeps both:

- `epoch`: acquisition epoch, stable across refreshes.
- `version`: storage row version, increments on refresh and replacement.

Rules:

- New shard lease starts with `epoch = 1` and `version = 1`.
- Refresh keeps the same `epoch` and increments `version`.
- Acquire after an expired lease increments `epoch` and `version`.
- Release removes the lease.

This makes refreshes cheap and safe: refreshing a lease does not make the
runner's own entity registrations stale. Only a new owner/acquisition makes old
fences stale.

## Fencing Token

`ShardLeaseFence` contains:

- `shard_id`
- `owner`
- `epoch`

`fenceFromLease(lease)` derives a token from the lease.

`validateShardFence(runner_storage, fence)` reads the current durable lease for
the shard and rejects when:

- no lease exists,
- the owner differs,
- the epoch differs.

The validation is intentionally storage-independent. It uses the existing
`RunnerStorage.lease` contract and works for in-memory and file storage.

## Runtime Write Guard

`ClusterRuntime` validates the current fence before processing a shard:

1. Look up the local fence for the shard from `LocalShardLeaseManager`.
2. Validate that fence against `RunnerStorage`.
3. If validation fails, remove the shard from local ownership, stop accepting
   new messages, and return `error.StaleShardFence`.

This prevents stale runners from claiming, replying, or acknowledging durable
messages after another runner has acquired the shard.

## Journal Write Guard

`ClusterWorkflowEntityRegistry.registerExecution` captures the current shard
fence and runner storage in `ClusterWorkflowEntityServices`.

`ClusterWorkflowEntityHandler.handle` validates that fence before applying a
workflow command. If the durable lease epoch has moved, the handler returns
`error.StaleShardFence` before appending any workflow event.

This protects the journal even if a command reaches a stale entity scope through
a test harness or future transport path that bypasses `ClusterRuntime`.

## Diagnostics

`formatShardFenceDiagnostic(allocator, fence, current)` formats a concise report:

```text
shard=<id> fence_owner=<machine>/<runner> fence_epoch=<epoch> current_owner=<machine>/<runner>|none current_epoch=<epoch>|none
```

Tests assert the diagnostic includes shard id, fenced owner, fenced epoch, and
current owner/epoch when present.

## Tests

Add `packages/zigeffect/test/cluster_fencing_test.zig`.

Coverage:

1. Public exports exist.
2. Lease acquire records epoch, refresh preserves epoch, acquire after expiry
   increments epoch.
3. `validateShardFence` accepts the current owner/epoch and rejects stale
   owner/epoch.
4. Stale `ClusterRuntime.processShard` rejects before message claim/ack after a
   newer owner acquires the shard.
5. Stale `ClusterWorkflowEntityHandler` rejects before workflow journal append.
6. Diagnostics include fenced and current lease identity.

## Documentation

Update `packages/zigeffect/docs/architecture.md` to include
`cluster/fencing.zig`.

Mark Milestone 38 complete in the roadmap only after the full verification gate
passes.

## Completion Definition

Milestone 38 is complete when shard lease epochs distinguish acquisition from
refresh, stale fences are rejected before mailbox or journal mutation, stale
runners shut down local ownership on fence failure, diagnostics explain the
lease conflict, and tests prove stale runner writes cannot corrupt journal or
mailbox state.
