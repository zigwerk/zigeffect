# zigeffect Shard Leasing Design

Date: 2026-06-09

## Purpose

Milestone 30 turns raw runner storage leases into a local shard leasing runtime.
The runtime lets one runner own a shard for a bounded lease duration, refresh
that ownership on a cadence, hand shards off gracefully, and force recovery when
a runner is declared dead by the local health inspector.

## Current Context

Milestone 27 added deterministic shard ids and local routing tables.
Milestone 28 added runner identity, startup registration, heartbeats, and local
health inspection. Milestone 29 added `RunnerStorage`, `ShardLease`, in-memory
lease storage, and file-backed per-shard lease files with atomic acquisition.

The missing piece is the active owner process that uses those contracts. Storage
knows how to acquire, refresh, release, and list leases, but it does not decide
when to refresh, when an owned lease is stale, whether a peer is dead, or how to
emit shard-ownership evidence.

## Scope

This milestone adds a local shard lease manager. It does not add distributed
transport, remote health gossip, cross-runner RPC, dynamic routing rebalancing,
or message storage. Those remain later roadmap milestones.

## Files

- `packages/zigeffect/src/cluster/shard_lease.zig`: new local shard lease
  manager, lease options, refresh cadence helpers, handoff and recovery reports,
  owned-lease tracking, and causal recording hooks.
- `packages/zigeffect/test/shard_lease_test.zig`: unit tests for public exports,
  option validation, acquire, refresh cadence, graceful handoff, dead-runner
  recovery, and causal events.
- `packages/zigeffect/src/cluster/root.zig`: cluster namespace exports.
- `packages/zigeffect/src/zigeffect.zig`: top-level ergonomic aliases.
- `packages/zigeffect/src/services/causal.zig`: shard ownership event kinds and
  taxonomy entries.
- `packages/zigeffect/test/all_test.zig`: aggregate test import.
- `packages/zigeffect/docs/architecture.md`: module ownership documentation.
- `docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md`:
  milestone closeout checkboxes.

## Public API

Add `cluster/shard_lease.zig` with these public types:

```zig
pub const ShardLeaseManagerError = error{
    InvalidLeaseOptions,
    ShardAlreadyOwned,
    ShardNotOwned,
    RunnerStillAlive,
};

pub const ShardLeaseManagerOptions = struct {
    ttl_ms: RunnerLeaseTtlMs,
    refresh_interval_ms: u64,
};

pub const ShardLeaseRefreshReport = struct {
    refreshed: usize = 0,
    reacquired: usize = 0,
    expired: usize = 0,
    conflicts: usize = 0,
};

pub const ShardLeaseRecoveryReport = struct {
    dead_runner: RunnerAddress,
    recovered_by: RunnerAddress,
    released: usize,
    at_ms: u64,
};

pub const ShardHandoffReport = struct {
    shard_id: ShardId,
    from: RunnerAddress,
    to: RunnerAddress,
    released_at_ms: u64,
};

pub const LocalShardLeaseManager = struct {
    allocator: Allocator,
    storage: RunnerStorage,
    owner: RunnerAddress,
    options: ShardLeaseManagerOptions,
    owned_leases: std.ArrayList(ShardLease),
    causal_store: ?*CausalStore = null,
    causal_run_id: ?u64 = null,
};
```

`LocalShardLeaseManager` exposes:

```zig
pub fn init(
    allocator: Allocator,
    storage: RunnerStorage,
    owner: RunnerAddress,
    options: ShardLeaseManagerOptions,
) ShardLeaseManagerError!LocalShardLeaseManager

pub fn deinit(self: *LocalShardLeaseManager) void
pub fn attachCausalStore(self: *LocalShardLeaseManager, store: *CausalStore, run_id: u64) void
pub fn acquireShard(self: *LocalShardLeaseManager, shard_id: ShardId, now_ms: u64) !ShardLease
pub fn refreshOwnedLeases(self: *LocalShardLeaseManager, now_ms: u64) !ShardLeaseRefreshReport
pub fn releaseShard(self: *LocalShardLeaseManager, shard_id: ShardId, now_ms: u64) !void
pub fn handoffShard(self: *LocalShardLeaseManager, shard_id: ShardId, target: RunnerAddress, now_ms: u64) !ShardHandoffReport
pub fn recoverDeadRunner(self: *LocalShardLeaseManager, registry: *LocalRunnerRegistry, inspector: *const LocalRunnerHealthInspector, dead_runner: RunnerAddress, now_ms: u64) !ShardLeaseRecoveryReport
pub fn ownsShard(self: *const LocalShardLeaseManager, shard_id: ShardId) bool
pub fn ownedLeases(self: *const LocalShardLeaseManager, allocator: Allocator) Allocator.Error!RunnerLeaseBatch
```

Also expose:

```zig
pub fn shardLeaseRefreshDue(lease: ShardLease, options: ShardLeaseManagerOptions, now_ms: u64) bool
pub fn shardLeaseNextRefreshAt(lease: ShardLease, options: ShardLeaseManagerOptions) u64
```

## Lease Options And Refresh Cadence

`ttl_ms` is the bounded ownership duration. `refresh_interval_ms` is the local
cadence for renewing active ownership. Options are valid only when both values
are nonzero and `refresh_interval_ms < ttl_ms`; otherwise `init` returns
`InvalidLeaseOptions`.

Refresh is due when:

```zig
now_ms >= lease.refreshed_at_ms + refresh_interval_ms
```

Use saturating addition when computing the next refresh timestamp so tests and
runtime code do not overflow near `maxInt(u64)`.

## Acquisition And Owned Lease Tracking

`acquireShard` delegates to `RunnerStorage.acquire` with the manager owner and
configured TTL. If the shard is already in `owned_leases`, it returns
`ShardAlreadyOwned`. If storage returns an active conflict, the manager records a
conflict causal event and surfaces the storage error. If storage allows expired
lease replacement, the returned `ShardLease` is appended to `owned_leases` and
an acquired causal event is recorded.

The manager tracks only leases it owns locally. `ownedLeases` returns an
allocator-owned copy through the existing `RunnerLeaseBatch` type.

## Refresh Behavior

`refreshOwnedLeases` loops over locally owned leases. For each lease that is not
due, it leaves the lease unchanged. For due leases it calls
`RunnerStorage.refresh`.

If refresh succeeds, the owned lease entry is replaced with the refreshed lease
and a refreshed causal event is recorded.

If refresh returns `LeaseExpired`, the manager attempts `RunnerStorage.acquire`
for the same shard and owner. A successful reacquisition replaces the owned
entry and increments `reacquired`. A conflict removes the owned entry, increments
`conflicts`, records a conflict event, and continues. Other errors bubble out.

This keeps missed local refreshes recoverable while preserving storage as the
single authority for active ownership.

## Graceful Handoff

`handoffShard` is a local source-runner operation. It requires the source manager
to own the shard. It records a handoff-started causal event, calls
`RunnerStorage.release` for the source owner, removes the local owned lease, and
records a released causal event. The target runner then acquires the shard using
its own `acquireShard` call. This keeps handoff deterministic without adding
transport or remote callbacks.

## Forced Recovery After Runner Death

`recoverDeadRunner` uses `LocalRunnerHealthInspector.inspectRunner` to verify
the target runner is `.unhealthy` or `.stopped`. If the runner is still
`.starting`, `.healthy`, or `.degraded`, it returns `RunnerStillAlive` and does
not mutate storage.

When the target is dead, the manager records a recovery-started causal event,
calls `RunnerStorage.releaseAll(dead_runner)`, records a recovery-completed
causal event with the release count, and returns a `ShardLeaseRecoveryReport`.
Another manager can then acquire those shards immediately. This satisfies the
Milestone 30 acceptance test by simulating a runner death through heartbeat age,
force-releasing its leases, and reacquiring the shard from the survivor.

## Causal Events

Extend `CausalEventKind` with:

```zig
cluster_shard_lease_acquired,
cluster_shard_lease_refreshed,
cluster_shard_lease_released,
cluster_shard_lease_conflict,
cluster_shard_handoff_started,
cluster_shard_recovery_started,
cluster_shard_recovery_completed,
```

These are structural, finding-evidence events and are not sampleable. The
manager records them only when `attachCausalStore` has been called. Event fields:

- `run_id`: manager `causal_run_id`.
- `label`: `"shard-{id}"` for shard events or `"runner-recovery"` for recovery.
- `type_name`: `"cluster.shard_lease"`.
- `status`: `"acquired"`, `"refreshed"`, `"released"`, `"conflict"`,
  `"handoff_started"`, `"recovery_started"`, or `"recovery_completed"`.
- `redacted_detail`: numeric shard, owner, target, version, expiration, and
  release-count details. It must not contain user payloads.

## Tests

Add tests covering:

- public exports for `shard_lease`.
- invalid options reject zero TTL, zero refresh interval, and interval greater
  than or equal to TTL.
- `shardLeaseRefreshDue` returns false before cadence and true at cadence.
- `acquireShard` stores an owned lease and records an acquired causal event.
- `refreshOwnedLeases` skips non-due leases and refreshes due leases.
- an expired owned lease is reacquired by the same manager.
- graceful handoff releases source ownership and lets the target acquire.
- runner death recovery releases dead-runner leases and lets a survivor acquire.
- recovery refuses healthy runners.
- causal snapshots contain acquired, refreshed, released, handoff, conflict, and
  recovery events when a store is attached.

## Acceptance Mapping

- Lease duration and refresh cadence: `ShardLeaseManagerOptions`,
  `shardLeaseRefreshDue`, and `refreshOwnedLeases`.
- Expired lease acquisition: `acquireShard` and expired-refresh reacquisition
  both delegate to storage acquisition after expiration.
- Graceful shard handoff: `handoffShard`.
- Forced recovery after runner death: `recoverDeadRunner`.
- Causal events: new cluster shard lease event kinds recorded through
  `CausalStore`.
- Runner death and shard reacquisition test: dead runner is marked unhealthy by
  `LocalRunnerHealthInspector`, survivor releases dead leases, then acquires the
  shard.
