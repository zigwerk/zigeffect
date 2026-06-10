# zigeffect Shard Identity And Routing Design

Date: 2026-06-09

## Purpose

Milestone 27 adds deterministic shard identity and local routing for cluster
entities. The goal is to map every `EntityAddress` to a stable `ShardId`, make
the shard count configurable, and provide a reloadable routing table that can
route messages in a single local runner before runner registration, leases, and
multi-runner transport exist.

## Current Context

The cluster domain currently contains:

- `identity.zig` for stable `EntityId` and `EntityAddress` values.
- `mailbox.zig` for local per-entity FIFO mailboxes.
- `entity.zig` for local entity runtime behavior.
- `envelope.zig` for durable message ids, idempotency keys, at-least-once
  delivery tracking, duplicate reply detection, and redacted diagnostics.

Routing should compose with these modules. It should compute from
`EntityAddress`, expose stable public aliases through `cluster/root.zig` and
`zigeffect.zig`, and avoid adding durable storage or runner membership before
the roadmap milestones that own those responsibilities.

## Requirements

- Add `ShardId` as a first-class cluster type.
- Add a configurable `ShardCount` with validation that zero shards is invalid.
- Add a stable hash function for entity ids.
- Add deterministic shard assignment from `EntityAddress` to `ShardId`.
- Add a routing table that contains one entry per shard.
- Add local single-runner routing where every shard routes to the local process.
- Add a snapshot/reload path for the routing table so restart stability can be
  tested without durable runner storage.
- Keep routing independent of `MessageEnvelope` storage and mailbox internals.

## Design

Create `packages/zigeffect/src/cluster/routing.zig`.

The module defines:

- `ShardId = u64`
- `ShardCount = u32`
- `ShardRoutingVersion = u64`
- `ShardRoutingError = error{ InvalidShardCount, ShardNotFound }`
- `ShardRouteTarget = enum { local }`
- `ShardRouteEntry = struct { shard_id: ShardId, target: ShardRouteTarget }`
- `ShardRoute = struct { shard_id: ShardId, target: ShardRouteTarget }`
- `ShardRoutingSnapshot = struct { shard_count: ShardCount, version: ShardRoutingVersion }`
- `ShardRoutingTable`

`entityShardHash(entity_id)` hashes the `EntityId` bytes with an explicit
cluster-sharding namespace. This avoids tying shard distribution to the current
entity id implementation while remaining deterministic across process restarts.

`shardIdForEntityId(entity_id, shard_count)` validates `shard_count > 0`,
computes `entityShardHash(entity_id) % shard_count`, and returns a `ShardId`.

`shardIdForAddress(address, shard_count)` delegates to
`shardIdForEntityId(address.id, shard_count)`.

`ShardRoutingTable.initLocal(allocator, .{ .shard_count = N })` creates a table
with shard ids `0..N-1`, all targeting `.local`, and version `1`.

`route(address)` returns the computed shard and target. `routeShard(shard_id)`
returns the target for an already computed shard. `snapshot()` returns the shard
count and version. `reloadLocal(allocator, snapshot)` reconstructs the same
local table from a previous snapshot.

## Error Handling

Zero shard counts return `InvalidShardCount` from public constructors and shard
assignment helpers. Unknown shard ids return `ShardNotFound` from `routeShard`.
The local route target carries no runner id because runner identity begins in
Milestone 28.

## Testing

Add `packages/zigeffect/test/routing_test.zig` and import it from
`packages/zigeffect/test/all_test.zig`.

Tests cover:

- Public exports for `routing`, `ShardId`, `ShardCount`, `ShardRoutingTable`,
  `shardIdForEntityId`, and `shardIdForAddress`.
- Stable shard assignment for repeated entity ids.
- Shard ids stay inside the configured shard count.
- Different entity ids distribute over more than one shard for a representative
  local table.
- Zero shard counts fail clearly.
- Local routing maps every configured shard to `.local`.
- Snapshot and reload preserve entity-to-shard and entity-to-route results.

## Documentation

Update `packages/zigeffect/docs/architecture.md` to list `routing.zig` in the
cluster module inventory. Update the master roadmap to mark Milestone 27
deliverables and acceptance complete only after the full verification gate
passes.
