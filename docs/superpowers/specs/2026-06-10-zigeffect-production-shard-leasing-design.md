# zigeffect Production Shard Leasing Design

Date: 2026-06-10

Milestone: 48 - Production Shard Leasing

## Goal

Harden shard ownership from local proof into production-grade lease enforcement.
Every cluster-owned write must be fenced by the durable runner storage epoch,
record the epoch it was written under, and become harmless after a runner loses
ownership.

This builds on Milestone 38. The earlier split-brain work made stale runtime and
workflow-entity paths validate before mutation. This milestone makes that rule a
reusable contract for journal, message, mailbox, queue, and timer writes, then
adds lease timing rules, stale-owner recovery, and audit reports.

## Existing Foundation

The current code already provides:

- `ShardLease.epoch`, stable across refresh and incremented on reacquire.
- `ShardLeaseFence`, derived from a lease and validated against `RunnerStorage`.
- `LocalShardLeaseManager.fenceForShard`.
- `ClusterRuntime.processShard` and `submitEntityMessage` fence checks.
- `ClusterWorkflowEntityServices.validateLeaseFence`.
- In-memory and file runner storage with persisted lease epoch.

The remaining gaps are production hardening gaps:

- Low-level writes can still bypass the runtime fence unless callers remember to
  validate separately.
- Message records and workflow journal events do not expose which lease epoch
  wrote them.
- Lease refresh timing has no jitter, deadline, or clock-skew vocabulary.
- Stale local ownership can be detected only incidentally during write paths.
- Recovery reports show release count, but not which local leases are valid,
  expired, missing, stale, or forcibly released.

## Public Surface

Add `packages/zigeffect/src/cluster/lease_guard.zig` and export:

- `fx.cluster.lease_guard`
- `fx.cluster.ShardLeaseWriteGuard`
- `fx.cluster.ShardLeaseGuardedJournalStore`
- `fx.cluster.ShardLeaseWriteKind`
- `fx.cluster.LeaseGuardedJournalAppend`
- `fx.cluster.GuardedMessageSubmit`
- `fx.cluster.GuardedMessageClaim`
- `fx.cluster.GuardedMessageAck`
- `fx.cluster.GuardedMessageReply`
- `fx.cluster.guardMessageSubmit`
- `fx.cluster.guardMessageClaim`
- `fx.cluster.guardMessageAck`
- `fx.cluster.guardMessageReply`
- `fx.cluster.guardJournalAppend`
- `fx.cluster.guardMailboxOffer`
- `fx.cluster.guardMailboxReply`
- `fx.cluster.appendLeaseEpochDetail`
- `fx.cluster.leaseEpochFromDetail`

Extend existing public types:

- `MessageEnvelope.lease_epoch: ?ShardLeaseEpoch`
- `StoredMessageRecord.lease_epoch: ?ShardLeaseEpoch`
- `StoredReplyRecord.lease_epoch: ?ShardLeaseEpoch`
- `MessageStorageSubmit.lease_epoch: ?ShardLeaseEpoch`
- `MessageStorageClaim.lease_epoch: ?ShardLeaseEpoch`
- `MessageStorageAck.shard_id: ?ShardId`
- `MessageStorageAck.lease_epoch: ?ShardLeaseEpoch`
- `MessageStorageReply.lease_epoch: ?ShardLeaseEpoch`
- `EntityEnvelope.lease_epoch: ?ShardLeaseEpoch`
- `ShardLeaseManagerOptions.renewal_jitter_ms: u64 = 0`
- `ShardLeaseManagerOptions.renewal_deadline_ms: u64 = 0`
- `ShardLeaseManagerOptions.clock_skew_tolerance_ms: u64 = 0`

Add lease-audit exports:

- `fx.cluster.ShardLeaseAuditEntry`
- `fx.cluster.ShardLeaseAuditReport`
- `fx.cluster.ShardLeaseAuditStatus`
- `fx.cluster.ShardLeaseForceReleaseReport`
- `fx.cluster.shardLeaseRenewalJitterMs`
- `fx.cluster.shardLeaseRenewalDeadlineAt`
- `fx.cluster.shardLeaseExpiredForRecovery`
- `LocalShardLeaseManager.auditOwnedLeases`
- `LocalShardLeaseManager.forceReleaseStaleShard`

## Write Guard Model

`ShardLeaseWriteGuard` contains:

- `storage: RunnerStorage`
- `fence: ShardLeaseFence`
- `kind: ShardLeaseWriteKind`

Before any guarded write, the guard calls `validateShardFence(storage, fence)`.
On success, the write uses `fence.epoch` as the durable write epoch. On failure,
the write returns `error.StaleShardFence` and does not mutate storage.

The guard is deliberately storage-backed and synchronous. It does not trust local
memory once a write is about to happen.

`ShardLeaseWriteKind` labels the write for diagnostics:

- `journal`
- `mailbox`
- `message_submit`
- `message_claim`
- `message_ack`
- `message_reply`
- `queue`
- `timer`

## Epoch Stamping

Epoch metadata is stored in the native shape of each durable surface:

- Message records and replies use `lease_epoch` fields in memory and file JSON.
- Message envelopes carry `lease_epoch` so claimed/replied messages expose the
  epoch used by the storage mutation.
- Entity mailbox envelopes carry `lease_epoch`.
- Workflow journal events keep the journal schema stable by appending
  `lease_epoch=<epoch>` to `redacted_detail` through `appendLeaseEpochDetail`.
- Queue and timer writes are journal writes and therefore use the same detail
  stamping.

The parser helper `leaseEpochFromDetail(detail)` extracts the last
`lease_epoch=<number>` token from a detail string. Timer and queue parsers must
continue to parse their existing tokens when the lease epoch suffix is present.

Compatibility rules:

- Existing records with no epoch parse as `null`.
- New guarded writes always set an epoch.
- Unguarded low-level stores remain usable for local tests and non-cluster
  callers, but cluster runtime and cluster workflow paths use guarded helpers.

## Cluster Runtime Integration

`ClusterRuntime` replaces direct calls to `message_storage.submit`, `claim`,
`ack`, and `storeReply` with guarded message helpers.

For each shard mutation:

1. Build a guard from `lease_manager.fenceForShard(shard_id)`.
2. Validate against `lease_manager.storage`.
3. Apply the storage mutation with `lease_epoch = fence.epoch`.
4. If validation fails, remove the shard from local ownership, stop accepting
   messages, and return `error.StaleShardFence`.

This covers mailbox-level entity dispatch too because cluster message claims are
converted into entity envelopes with the claimed message epoch.

## Cluster Workflow Integration

`ClusterWorkflowEntityHandler` validates the service fence before command
application and passes the fence to the command applier.

All command applier journal writes run through
`ShardLeaseGuardedJournalStore`, a wrapper around `JournalStore` whose append
vtable calls `guardJournalAppend` and whose read/replay/reset vtable delegates
to the inner store.

That wrapper covers:

- workflow start and append-event commands,
- lifecycle commands,
- timer fire commands,
- deferred completion/failure/cancel commands,
- signal receipt,
- queue claim/retry/complete/failure commands,
- implicit workflow resume writes caused by timer, queue, deferred, or signal
  completion.

This ensures stale workflow entities fail before appending and successful
cluster-owned journal entries include `lease_epoch=<epoch>`.

## Lease Timing Rules

`ShardLeaseManagerOptions` keeps the existing `ttl_ms` and
`refresh_interval_ms`, then adds:

- `renewal_jitter_ms`: deterministic per-shard jitter added to the next refresh
  time.
- `renewal_deadline_ms`: latest safe age since the last refresh before the
  manager treats renewal as deadline-critical. `0` means use `ttl_ms`.
- `clock_skew_tolerance_ms`: grace window used for stale-owner recovery and
  audits.

Rules:

- `refresh_interval_ms` must be greater than zero and lower than `ttl_ms`.
- `renewal_deadline_ms`, when nonzero, must be greater than
  `refresh_interval_ms` and no greater than `ttl_ms`.
- `refresh_interval_ms + renewal_jitter_ms` must be lower than the effective
  renewal deadline.
- Refresh due time is `refreshed_at_ms + refresh_interval_ms + jitter`.
- Renewal deadline time is `refreshed_at_ms + effective_deadline_ms`.
- Recovery expiry is `expires_at_ms + clock_skew_tolerance_ms <= now_ms`.

The jitter is deterministic so tests and replay remain stable:
`(shard_id ^ epoch) % (renewal_jitter_ms + 1)`.

## Stale Detection And Forced Release

`LocalShardLeaseManager.auditOwnedLeases(allocator, now_ms)` compares local
owned leases against runner storage and returns an owned report.

Each entry reports:

- `shard_id`
- local `owner` and `epoch`
- current storage owner and epoch when present
- `expires_at_ms`
- `status`

Statuses:

- `valid`
- `refresh_due`
- `renewal_deadline_missed`
- `expired`
- `missing`
- `stale_owner`
- `stale_epoch`

`LocalShardLeaseManager.forceReleaseStaleShard(shard_id, now_ms)` reads current
runner storage and releases the current owner only when the stored lease is
expired for recovery after clock-skew tolerance. It returns
`ShardLeaseForceReleaseReport` with the released owner, epoch, and timestamp.

This method is intentionally stricter than `releaseAll(dead_runner)`. A health
inspector can release a dead runner by owner; forced stale release only handles
lease records whose durable TTL has passed.

## Crash And Recovery Guarantees

The tests model crash-style scenarios using in-memory stores:

1. Renewal loss: runner A misses renewal, runner B reacquires after expiry, and
   runner A cannot claim, ack, reply, or append journal entries.
2. Partial release: runner A still has local owned shard state after storage has
   moved; audit reports stale owner/epoch and the next guarded write fails.
3. Stale writes: direct guarded message and journal helpers reject old fences.
4. Rapid reacquisition: epoch increments on each expired reacquire and old
   fences remain rejected while the latest fence succeeds.
5. Timer duplicate safety: stale timer fire command fails before append; current
   owner fires once and a second fire remains idempotent.
6. Mailbox safety: guarded local mailbox offer/reply stamp lease epoch and stale
   guards reject before enqueue.

## Documentation

Update:

- `packages/zigeffect/docs/architecture.md`
- `packages/zigeffect/docs/effectts-parity.md`
- `packages/zigeffect/docs/usage.md`
- `docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md`

## Completion Definition

Milestone 48 is complete when cluster-owned writes validate storage-backed
fences immediately before mutation, successful writes carry lease epochs, stale
owners can be audited and forcibly released after durable expiry, renewal timing
has jitter/deadline/skew rules, and the full release gate plus focused crash
tests pass.
