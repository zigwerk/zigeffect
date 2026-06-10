# zigeffect Cluster Runtime Design

## Milestone

Milestone 32: Cluster Entity Runtime

## Goal

Run local entities through shard-owned durable message storage. The single-process cluster runtime should preserve the visible behavior of `LocalEntityRuntime` while moving submission, replay, ack, and reply state into `MessageStorage` and moving shard ownership into `LocalShardLeaseManager`.

## Existing Foundations

- `LocalEntityRuntime` owns entity registration, scopes, finalizers, supervision, restart intensity, idle shutdown, and handler invocation.
- `MessageStorage` owns durable submit, claim, ack, unprocessed queries, and reply lookup.
- `LocalShardLeaseManager` owns the runner's in-memory view of acquired shard leases and can release them on shutdown.
- `routing.shardIdForAddress` maps entity addresses to shard ids.
- `MessageEnvelope` is durable cluster protocol state. `EntityEnvelope` is local actor mailbox state.

## Public Surface

Add `cluster/runtime.zig` and export it through `cluster/root.zig` and the top-level `zigeffect.zig` facade.

New public types:

- `ClusterRuntime`
- `ClusterRuntimeOptions`
- `ClusterRuntimeError`
- `ClusterEntityRef`
- `ClusterAsk`
- `ClusterProcessReport`
- `ClusterShutdownReport`

Extend `MessageEnvelopeKind` with `tell`, leaving existing `request`, `reply`, `ack`, `interrupt`, and `chunk_reply` variants intact.

## Runtime Shape

`ClusterRuntime` contains:

- allocator
- `MessageStorage`
- pointer to `LocalShardLeaseManager`
- embedded `LocalEntityRuntime`
- configured `ShardCount`
- owned shard ids loaded from the lease manager
- accepting flag for shutdown

The runtime does not introduce transport, remote routing, background loops, async IO, or cross-runner handoff in this milestone. Those belong to later milestones. This milestone is the local durable bridge.

## Entity Registration

`ClusterRuntime.registerEntity` delegates to `LocalEntityRuntime.registerEntity` and returns a `ClusterEntityRef` for durable submission.

`ClusterRuntime.ref` delegates to `LocalEntityRuntime.ref` and returns a `ClusterEntityRef`.

`ClusterEntityRef.tell` submits a durable `MessageEnvelope` with kind `tell`.

`ClusterEntityRef.ask` submits a durable `MessageEnvelope` with kind `request` and returns `ClusterAsk` with the durable correlation id.

`ClusterEntityRef.interrupt` submits a durable `MessageEnvelope` with kind `interrupt`.

All ref submission paths compute the shard with `shardIdForAddress` and reject submission if the runtime does not currently own the shard.

## Owned Shards

`ClusterRuntime.loadOwnedShards` asks `LocalShardLeaseManager.ownedLeases`, clears the runtime cache, and records each shard id.

`ClusterRuntime.acquireShard` delegates to the lease manager and records the shard locally.

`ClusterRuntime.releaseShard` delegates to the lease manager and removes the shard locally.

`ClusterRuntime.ownsShard` checks the loaded/acquired cache.

`ClusterRuntime.shutdown` disables new submissions, releases every cached shard through the lease manager, and reports how many shards were released.

## Message Processing

Processing is explicit and synchronous:

1. `processOwnedShards(handler, now_ms)` iterates cached owned shards.
2. `processShard(shard_id, handler, now_ms)` rejects unowned shards.
3. The runtime queries `message_storage.unprocessedByShard`.
4. Each message is claimed by id before dispatch.
5. Claimed durable envelopes convert to entity envelopes.
6. The entity envelope is processed through `LocalEntityRuntime.processEnvelope`.
7. Handler replies are read from the local runtime reply mailbox and stored with `MessageStorage.storeReply`.
8. The durable message is acked only after successful handler processing and reply storage.

If handler processing fails, the message is not acked. It remains in `claimed` status, which is still considered unprocessed by `MessageStorage`, so replay can retry it.

## Local Runtime Refactor

Add `LocalEntityRuntime.processEnvelope(envelope, handler, now_ms)`.

`processNext` becomes a small mailbox adapter:

1. take from `LocalMailboxStore`
2. pass ownership to `processEnvelope`

This keeps supervision, interrupt handling, stop handling, reply creation, and scope restart behavior in exactly one place. The cluster runtime calls `processEnvelope` with envelopes sourced from durable storage.

## Envelope Conversion

Durable to local:

- `MessageEnvelopeKind.tell` maps to `EntityEnvelopeKind.tell`.
- `MessageEnvelopeKind.request` maps to `EntityEnvelopeKind.ask`.
- `MessageEnvelopeKind.interrupt` maps to `EntityEnvelopeKind.interrupt`.
- Other durable message kinds are rejected for actor dispatch.

Local reply to durable:

- `EntityEnvelopeKind.reply` maps to `MessageEnvelopeKind.reply`.

String fields and entity addresses are cloned at the boundary. The caller always owns returned envelopes and must deinitialize them.

## Ack And Reply Semantics

- Tell: handler success stores no reply and then acks the durable message.
- Ask: handler success stores a durable reply, then acks the durable request.
- Interrupt: local runtime transitions the entity to interrupted, then the durable interrupt message is acked.
- Handler failure: no ack and no durable reply.
- Duplicate reply: propagates `DuplicateReply` and prevents ack, leaving the request replayable.

## Shutdown Semantics

Shutdown for this milestone is bounded and synchronous:

- new submissions through `ClusterEntityRef` fail once shutdown begins
- cached owned shards are released through `LocalShardLeaseManager.releaseShard`
- local runtime resources are still released by `ClusterRuntime.deinit`

Draining, interrupts for long-running handlers, and distributed handoff coordination are later milestones.

## Tests

Add `test/cluster_runtime_test.zig` and include it from `test/all_test.zig`.

Required tests:

- public exports are available
- `LocalEntityRuntime.processEnvelope` preserves existing handler/reply behavior
- cluster runtime loads owned shards from the lease manager
- cluster refs submit durable tell and ask messages only for owned shards
- processing a tell dispatches to the entity and acks the durable message
- processing an ask stores a durable reply and acks the durable request
- handler failure leaves the durable message unacked and retryable
- shutdown releases owned shards and rejects new submissions
- single-process cluster behavior matches local runtime for tell plus ask ordering and reply payloads

## Acceptance

Milestone 32 is complete when the single-process `ClusterRuntime` can register an entity, submit tell and ask messages through durable storage, process owned shard messages with the same handler contract as `LocalEntityRuntime`, persist replies, ack processed messages, leave failed messages replayable, and release owned shards during shutdown.
