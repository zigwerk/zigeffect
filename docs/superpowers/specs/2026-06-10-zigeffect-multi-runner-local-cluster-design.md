# zigeffect Multi-Runner Local Cluster Design

## Milestone

Milestone 33: Multi-Runner Local Cluster

## Goal

Prove clustering on one machine with multiple runner processes using shared file-backed runner storage, shared file-backed message storage, deterministic shard balancing, runner death simulation, and local between-runner message routing.

## Scope Boundary

This milestone is real local clustering, not network clustering.

In scope:

- runner process CLI
- shared filesystem storage
- multiple runner identities
- shard split across runners
- owner polling through durable message storage
- dead runner release and survivor reacquisition
- deterministic in-process tests for two runners

Out of scope:

- network transport
- HTTP loopback transport
- multi-machine coordination
- async IO
- active load-based rebalancing

Those belong to Milestone 34 and later.

## Existing Foundations

- `FileRunnerStorage` stores shard leases atomically in shared files.
- `FileMessageStorage` stores durable messages and replies atomically in shared files.
- `LocalShardLeaseManager` owns, refreshes, releases, hands off, and recovers shard leases.
- `LocalRunnerRegistry` plus `LocalRunnerHealthInspector` can model runner health in tests.
- `ClusterRuntime` can process owned shards from `MessageStorage`.
- `ClusterRuntime` intentionally rejects direct ref submission for unowned shards.

## New Public Surface

Add `cluster/local_cluster.zig` and export it through `cluster/root.zig` and `zigeffect.zig`.

New public types:

- `LocalClusterRunnerOptions`
- `LocalClusterRunner`
- `LocalClusterRunnerReport`
- `LocalClusterRouter`
- `LocalClusterRouteResult`
- `ShardBalancePlan`
- `ShardRecoveryPlan`

Add a tool:

- `packages/zigeffect/tools/cluster_runner.zig`

Add build step:

- `zig build cluster-runner -- <args>`

## Runner CLI

The runner CLI follows existing zigeffect tool patterns:

- `pub fn main(init: std.process.Init) !void`
- parse `init.minimal.args`
- use `std.Io.Dir.cwd()`
- create/open the configured storage directory
- initialize file-backed runner and message storage
- initialize a shard lease manager
- initialize a cluster runtime
- acquire initial balanced shards
- run a bounded or continuous processing loop

CLI arguments:

- `--runner-id <text-or-number>`
- `--machine-id <text-or-number>`
- `--storage-dir <path>`
- `--shard-count <n>`
- `--runner-index <n>`
- `--runner-count <n>`
- `--lease-ttl-ms <n>`
- `--refresh-interval-ms <n>`
- `--tick-ms <n>`
- `--max-ticks <n>`
- `--simulate-death-after-ticks <n>`

The CLI may use hashed text ids via existing `runnerAddress`.

## Shared Storage

All local runners point at the same directory.

Files already produced by existing storage implementations:

- `runner-lease-<shard>.json`
- `cluster-message-<id>.json`
- `cluster-reply-<correlation>.json`

The CLI does not invent separate storage protocols for messages or leases. It composes `FileRunnerStorage` and `FileMessageStorage`.

## Shard Balancing

Milestone 33 uses deterministic static balancing:

- runner `i` out of `n` owns shards where `shard_id % n == i`
- each runner attempts to acquire its planned shard ids
- conflicts are reported, not silently ignored

Expose:

- `balancedShardPlan(allocator, shard_count, runner_index, runner_count)`
- `LocalClusterRunner.acquireBalancedShards(now_ms)`

This gives two local runners a predictable split and keeps tests stable.

## Local Message Routing

Between-runner routing in this milestone means:

1. compute `shardIdForAddress`
2. submit the message to shared `MessageStorage` with that shard id
3. the runner that owns the shard picks it up through `processOwnedShards`

There is no direct socket, channel, or RPC between runners yet.

Add `LocalClusterRouter` as an explicit shared-storage ingress path. It can submit tell, ask, and interrupt messages for any shard in the configured shard count. Unlike `ClusterEntityRef`, it does not require the current process to own the destination shard.

This keeps `ClusterRuntime` strict for local actor refs and gives the multi-runner CLI/tests a routing surface that matches the local shared-storage model.

## Runner Death Simulation

Tests use `LocalRunnerRegistry` and `LocalRunnerHealthInspector`:

- register two runner addresses
- record heartbeats for both
- stop heartbeats for one runner
- inspect it after `unhealthy_after_ms`
- survivor calls recovery

Because `LocalShardLeaseManager.recoverDeadRunner` releases leases and returns only a count, add a helper that snapshots the dead runner's shard ids before release:

- `planDeadRunnerShardRecovery(storage, dead_runner, allocator)`
- `recoverAndAcquireDeadRunnerShards(manager, registry, inspector, dead_runner, now_ms)`

The helper:

1. lists current leases
2. records shard ids owned by the dead runner
3. calls `recoverDeadRunner`
4. attempts to acquire each recorded shard for the survivor
5. returns `ShardRecoveryPlan`

## LocalClusterRunner

`LocalClusterRunner` composes:

- runner address
- optional runner registry pointer for tests
- `LocalShardLeaseManager`
- `ClusterRuntime`
- `LocalClusterRouter`
- tick/lease options

Primary methods:

- `init`
- `deinit`
- `acquireBalancedShards`
- `loadOwnedShards`
- `tick(handler, now_ms)`
- `recoverDeadRunner`
- `shutdown`

`tick` should:

1. refresh owned leases
2. load owned shards
3. process owned shard messages
4. return a report

## Tests

Add `test/multi_runner_cluster_test.zig`.

Required tests:

- public exports for local cluster helpers are available
- balanced shard plans split shards deterministically across two runners
- shared file-backed runner and message storage can be opened by two local runner instances
- a router on runner A can submit a message for a shard owned by runner B
- runner B processes the message and stores the reply
- two runners split shards and process only their owned shard messages
- dead runner recovery releases dead runner shards and survivor reacquires them
- messages submitted before death are processed after survivor recovery

## Acceptance

Milestone 33 is complete when two local runners using shared file-backed storage split shards, route messages through shared durable storage, recover after one runner stops heartbeating, and preserve entity message correctness without network transport.
