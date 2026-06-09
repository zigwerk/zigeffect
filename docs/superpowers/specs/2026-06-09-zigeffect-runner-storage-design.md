# zigeffect Runner Storage Design

Date: 2026-06-09

## Purpose

Milestone 29 persists runner and shard ownership metadata. It introduces a
`RunnerStorage` contract, in-memory and file-backed implementations, and lease
operations for acquiring, refreshing, releasing, and releasing all shard
ownership held by a runner.

## Current Context

Milestone 27 added deterministic `ShardId` routing. Milestone 28 added stable
`RunnerAddress`, runner registration, heartbeat history, health states, and
local health inspection. The workflow file journal already establishes local
durability patterns: vtable-backed storage contracts, allocator-owned in-memory
stores, exclusive file creation for local locks, atomic file replacement, and
`std.json.parseFromSlice` for durable JSON.

Milestone 29 owns runner storage but not lease scheduling, expired-runner
recovery, shard handoff policy, or real multi-process transport. Those behaviors
start in the following shard leasing and multi-runner milestones.

## Requirements

- Add a `RunnerStorage` contract with vtable operations.
- Implement in-memory runner storage.
- Implement file-backed runner storage.
- Add acquire, refresh, release, and release-all operations.
- Add lease conflict errors.
- Persist enough metadata to inspect current shard ownership.
- Prove file-backed local acquisition is atomic through exclusive per-shard
  lease files.

## Data Model

Create `packages/zigeffect/src/cluster/runner_storage.zig`.

Public types:

- `RunnerStorageLeaseId = u64`
- `RunnerLeaseTtlMs = u64`
- `ShardLease = struct { shard_id: ShardId, owner: RunnerAddress, acquired_at_ms: u64, refreshed_at_ms: u64, expires_at_ms: u64, version: u64 }`
- `RunnerLeaseAcquire = struct { shard_id: ShardId, owner: RunnerAddress, now_ms: u64, ttl_ms: RunnerLeaseTtlMs }`
- `RunnerLeaseRefresh = struct { shard_id: ShardId, owner: RunnerAddress, now_ms: u64, ttl_ms: RunnerLeaseTtlMs }`
- `RunnerLeaseRelease = struct { shard_id: ShardId, owner: RunnerAddress }`
- `RunnerLeaseBatch = struct { allocator: Allocator, leases: []ShardLease }`
- `RunnerStorageError = error{ InvalidLeaseTtl, LeaseConflict, LeaseNotFound, LeaseNotOwned, LeaseExpired, CorruptLeaseFile }`

`ttl_ms == 0` is invalid for acquire and refresh. `expires_at_ms` is computed as
`now_ms + ttl_ms`. If addition overflows, the operation returns
`InvalidLeaseTtl`.

## Contract

`RunnerStorage` follows the workflow `JournalStore` pattern:

- `context: *anyopaque`
- `vtable: *const VTable`
- wrapper methods for `acquire`, `refresh`, `release`, `releaseAll`,
  `lease`, `leases`, and `reset`

The vtable returns `anyerror`-compatible operation errors because file-backed
storage can return filesystem and JSON errors in addition to runner storage
errors. Public tests assert the typed runner errors for expected lease conflicts.

## In-Memory Storage

`InMemoryRunnerStorage` owns `std.ArrayList(ShardLease)`.

Behavior:

- `acquire` returns an existing non-expired owner as `LeaseConflict`.
- `acquire` replaces an expired lease, increments the version, and returns the
  new lease.
- `refresh` requires the same owner and a non-expired lease.
- `release` requires the same owner and removes the lease.
- `releaseAll(owner)` removes every lease owned by `owner` and returns the
  removed count.
- `lease(shard_id)` returns a copy of the lease or `null`.
- `leases(allocator)` returns an owned snapshot batch.
- `reset()` removes all leases.

This store is deterministic and does not consult a clock; callers pass `now_ms`
explicitly.

## File-Backed Storage

`FileRunnerStorage` owns:

- `allocator`
- `io: std.Io`
- `dir: *std.Io.Dir`
- `options: FileRunnerStorageOptions`

Options:

- `lease_prefix = "runner-shard-"`
- `lease_suffix = ".json"`
- `max_lease_file_bytes = 64 * 1024`

Each shard lease is stored in `runner-shard-{shard_id}.json`. The JSON schema is
`zigeffect.cluster.runner-lease.v1`.

Acquire algorithm:

1. Validate TTL.
2. Try `dir.createFile(io, lease_name, .{ .exclusive = true, .read = true })`.
3. If creation succeeds, write the lease JSON and return it.
4. If the file exists, read and parse the current lease.
5. If the current lease is not expired at `now_ms`, return `LeaseConflict`.
6. If the current lease is expired, delete it and try exclusive create again.
7. If the second exclusive create conflicts, return `LeaseConflict`.

Refresh algorithm:

1. Read and parse the current lease.
2. Return `LeaseNotFound` if the file is absent.
3. Return `LeaseNotOwned` if the owner differs.
4. Return `LeaseExpired` if `expires_at_ms <= now_ms`.
5. Write the updated lease JSON using `dir.createFileAtomic(io, name, .{ .replace = true })`.

Release algorithm:

1. Read and parse the current lease.
2. Return `LeaseNotFound` if the file is absent.
3. Return `LeaseNotOwned` if the owner differs.
4. Delete the lease file.

Release-all iterates known lease files in the directory, releases those owned by
the provided owner, and skips leases owned by other runners.

The file-backed store does not maintain a hidden cache. Each operation reads the
authoritative file state so two local store instances can model contention.

## JSON

`formatShardLeaseJson(allocator, lease)` writes:

- `schema`
- `schema_version`
- `shard_id`
- `machine_id`
- `runner_id`
- `acquired_at_ms`
- `refreshed_at_ms`
- `expires_at_ms`
- `version`

`parseShardLeaseJson(allocator, json)` validates the schema and version, then
returns a `ShardLease`.

## Testing

Add `packages/zigeffect/test/runner_storage_test.zig`.

Tests cover:

- Public exports for the storage module, contract, lease types, in-memory store,
  and file-backed store.
- In-memory acquire, conflict, refresh, release, release-all, lease lookup, and
  reset.
- Expired leases can be reacquired by another runner.
- Refresh rejects wrong owners and expired leases.
- File-backed acquire writes a lease file and a second local store sees
  `LeaseConflict`.
- File-backed refresh survives reopen.
- File-backed release removes the lease file.
- File-backed release-all removes only the caller's leases.

## Documentation

Update `packages/zigeffect/docs/architecture.md` with `runner_storage.zig`.
Mark Milestone 29 complete in the roadmap only after the full gate proves the
contract, in-memory store, file-backed store, and atomic local acquisition.
