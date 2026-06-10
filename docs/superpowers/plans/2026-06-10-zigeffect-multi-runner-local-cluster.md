# zigeffect Multi-Runner Local Cluster Implementation Plan

## Spec

`docs/superpowers/specs/2026-06-10-zigeffect-multi-runner-local-cluster-design.md`

## Milestone

Milestone 33: Multi-Runner Local Cluster

## Success Criteria

- A `cluster/local_cluster.zig` module exposes local multi-runner helpers.
- Two runner instances can share file-backed runner and message storage.
- Balanced shard plans split shards deterministically.
- A shared-storage router can submit messages for shards owned by another runner.
- The owner runner processes routed messages and persists replies.
- A survivor runner can recover and reacquire shards from an unhealthy runner.
- Messages submitted before runner death are processed after recovery.
- `zig build cluster-runner -- <args>` builds and runs a local runner process CLI.

## Verification Gate

Run before every implementation commit:

1. `zig build test-raw` from `packages/zigeffect`
2. `zig fmt --check` on touched Zig files
3. `git diff --check`

Run before milestone closeout:

1. `bun run zigeffect:test`
2. `zig build examples` from `packages/zigeffect`
3. `zig build cluster-runner -- --help` from `packages/zigeffect`
4. `bun run zig:test`
5. `zig fmt --check` on touched Zig files
6. `git diff --check`
7. marker scan on touched source/tests/docs

## Task 1: Local Cluster Public Surface And Balanced Shards

Red tests:

- Add `test/multi_runner_cluster_test.zig`.
- Assert `fx.cluster.local_cluster` and the new public types/helpers are exported.
- Assert `balancedShardPlan` splits 8 shards across two runners into even and odd ids.
- Assert invalid shard count, runner count, and runner index are rejected.

Implementation:

- Add `packages/zigeffect/src/cluster/local_cluster.zig`.
- Add `LocalClusterError`, `ShardBalancePlan`, `balancedShardPlan`, and deinit support.
- Export through `cluster/root.zig` and `zigeffect.zig`.
- Add the test file to `test/all_test.zig`.

Commit:

- `feat(zigeffect): add local cluster shard planning`

## Task 2: Shared-Storage Router

Red tests:

- With shared file-backed `FileMessageStorage`, route a tell and ask for an address whose shard is not owned by the submitting runner.
- Assert the records are stored under the computed shard id.
- Assert the route result reports shard id, envelope kind, correlation id for ask, and duplicate status.

Implementation:

- Add `LocalClusterRouter`.
- Add `routeTell`, `routeAsk`, and `routeInterrupt`.
- Generate local-router idempotency keys with a router sequence.
- Do not require shard ownership for router submission.

Commit:

- `feat(zigeffect): route local cluster messages through shared storage`

## Task 3: LocalClusterRunner Tick And File-Backed Two-Runner Processing

Red tests:

- Open shared `FileRunnerStorage` and `FileMessageStorage` in a tmp dir.
- Create two `LocalClusterRunner` instances with different runner addresses.
- Acquire balanced shards for runner A and runner B.
- Submit messages through `LocalClusterRouter` for entities on both shard sets.
- Run `tick` on both runners.
- Assert each runner processes only owned shard messages and replies are durable.

Implementation:

- Add `LocalClusterRunnerOptions`, `LocalClusterRunnerReport`, and `LocalClusterRunner`.
- Compose `LocalShardLeaseManager`, `ClusterRuntime`, and `LocalClusterRouter`.
- Add `acquireBalancedShards`, `loadOwnedShards`, `tick`, and `shutdown`.
- `tick` refreshes leases, reloads owned shards, and processes owned shard messages.

Commit:

- `feat(zigeffect): run two local cluster runners on shared files`

## Task 4: Runner Death Recovery

Red tests:

- Register two runners in `LocalRunnerRegistry`.
- Runner A acquires shards and receives a routed message.
- Stop heartbeats for runner A and inspect it as unhealthy.
- Runner B recovers runner A's shards.
- Runner B processes the message and stores the expected reply.

Implementation:

- Add `ShardRecoveryPlan`.
- Add `planDeadRunnerShardRecovery`.
- Add `LocalClusterRunner.recoverDeadRunner`.
- Snapshot dead runner shard ids before `recoverDeadRunner` releases leases.
- Acquire the released shard ids for the survivor runner.

Commit:

- `feat(zigeffect): recover local cluster runner shards`

## Task 5: Runner Process CLI

Red tests/checks:

- Add CLI option parsing tests for required arguments and invalid numeric values.
- Add a build step that compiles `tools/cluster_runner.zig`.
- Verify `zig build cluster-runner -- --help` exits 0.

Implementation:

- Add `packages/zigeffect/tools/cluster_runner.zig`.
- Parse CLI options into `ClusterRunnerCliOptions`.
- Support `--help`.
- Open/create the configured storage directory through `std.Io.Dir.cwd()`.
- Initialize file-backed runner/message storage.
- Initialize `LocalClusterRunner`.
- Acquire balanced shards and run up to `--max-ticks`.
- Honor `--simulate-death-after-ticks` by exiting before shutdown release.
- Add the build step in `packages/zigeffect/build.zig`.

Commit:

- `feat(zigeffect): add local cluster runner cli`

## Task 6: Milestone Closeout

Steps:

- Mark Milestone 33 roadmap deliverables and acceptance complete.
- Run the full verification gate.
- Commit the roadmap closeout.

Commit:

- `docs(zigeffect): mark multi-runner local cluster complete`
