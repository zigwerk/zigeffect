# zigeffect Cluster Runtime Implementation Plan

## Spec

`docs/superpowers/specs/2026-06-10-zigeffect-cluster-runtime-design.md`

## Milestone

Milestone 32: Cluster Entity Runtime

## Success Criteria

- `ClusterRuntime` is public from `fx.cluster` and the top-level `fx` facade.
- The runtime can load/acquire/release owned shards through `LocalShardLeaseManager`.
- Cluster refs submit durable tell, ask, and interrupt messages only for owned shards.
- `processShard` and `processOwnedShards` claim durable messages, dispatch them to local entity handlers, store durable replies, and ack after success.
- Handler failure leaves durable messages replayable.
- Shutdown releases owned shards and rejects further submissions.
- Single-process cluster behavior matches local entity runtime for tell plus ask handling.

## Verification Gate

Run before every implementation commit:

1. `zig build test-raw` from `packages/zigeffect`
2. `zig fmt --check` on touched Zig files
3. `git diff --check`

Run before milestone closeout:

1. `bun run zigeffect:test`
2. `zig build examples` from `packages/zigeffect`
3. `bun run zig:test`
4. `zig fmt --check` on touched Zig files
5. `git diff --check`
6. marker scan on touched source/tests/docs

## Task 1: Local Entity External Envelope Hook

Red tests:

- Add a test proving `LocalEntityRuntime.processEnvelope` can process an externally supplied tell and ask envelope without using `LocalMailboxStore.take`.
- Assert replies are still available through `takeReply`.
- Assert handler failure still restarts or escalates according to the existing supervisor rules.

Implementation:

- Add `LocalEntityRuntime.processEnvelope(envelope, handler, now_ms)`.
- Refactor `processNext` to take from the mailbox and delegate to `processEnvelope`.
- Preserve existing ownership: returned `EntityProcessResult` owns the envelope; errors deinitialize the envelope.

Commit:

- `feat(zigeffect): process external entity envelopes`

## Task 2: Cluster Runtime Surface And Owned Shards

Red tests:

- Add `test/cluster_runtime_test.zig`.
- Assert public exports for `runtime`, `ClusterRuntime`, `ClusterRuntimeOptions`, `ClusterRuntimeError`, `ClusterEntityRef`, `ClusterAsk`, `ClusterProcessReport`, and `ClusterShutdownReport`.
- Assert `ClusterRuntime.loadOwnedShards` mirrors leases acquired through `LocalShardLeaseManager`.
- Assert `ClusterRuntime.acquireShard`, `ownsShard`, and `releaseShard` update both the lease manager and runtime cache.

Implementation:

- Add `packages/zigeffect/src/cluster/runtime.zig`.
- Add options, errors, reports, and runtime struct.
- Wire runtime module exports through `cluster/root.zig` and `zigeffect.zig`.
- Add `cluster_runtime_test.zig` to `test/all_test.zig`.

Commit:

- `feat(zigeffect): add cluster runtime shard ownership`

## Task 3: Durable Cluster Ref Submission

Red tests:

- Assert `ClusterEntityRef.tell` stores a durable `tell` message for an owned shard.
- Assert `ClusterEntityRef.ask` stores a durable `request` message and returns a correlation id.
- Assert submission to an unowned shard fails with `ShardNotOwned`.
- Assert submissions after shutdown begins fail with `RuntimeShuttingDown`.

Implementation:

- Extend `MessageEnvelopeKind` with `tell`.
- Add `ClusterEntityRef` and `ClusterAsk`.
- Add cluster ref registration and lookup methods.
- Add route validation through `shardIdForAddress`.
- Add durable submit helpers for tell, ask, and interrupt.

Commit:

- `feat(zigeffect): submit cluster entity messages`

## Task 4: Message Dispatch, Ack, Reply, And Retry

Red tests:

- Tell processing dispatches to the handler and acks the durable message.
- Ask processing dispatches to the handler, stores a durable reply, and acks the durable request.
- Handler failure leaves the durable message visible through `unprocessedById`.
- Processing an unowned shard fails with `ShardNotOwned`.
- A single-process cluster runtime produces the same handler ordering and reply payload as `LocalEntityRuntime` for tell plus ask.

Implementation:

- Add durable-to-local and local-reply-to-durable conversion helpers.
- Add `processShard(shard_id, handler, now_ms)`.
- Add `processOwnedShards(handler, now_ms)`.
- Add report counters for scanned, claimed, dispatched, replied, acked, failed, and skipped messages.
- Ack only after handler success and reply storage success.

Commit:

- `feat(zigeffect): dispatch cluster runtime messages`

## Task 5: Shutdown And Milestone Closeout

Red tests:

- Shutdown releases every cached owned shard through the lease manager.
- Shutdown returns a report with released shard count.
- Shutdown is idempotent.
- Submitting through an old `ClusterEntityRef` after shutdown fails.

Implementation:

- Add `ClusterRuntime.shutdown(now_ms)`.
- Ensure release order is deterministic and cached shard state is cleared.
- Keep `deinit` responsible for local runtime and cache memory only.
- Mark Milestone 32 roadmap deliverables and acceptance complete after full verification.

Commit:

- `feat(zigeffect): release cluster shards on shutdown`
- `docs(zigeffect): mark cluster runtime complete`
