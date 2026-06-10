# zigeffect Real Clustering Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a real cluster control plane for membership, discovery, placement, rebalance, drain, node-down recovery, split-brain evidence, and admin inspection.

**Architecture:** Introduce `cluster/real_cluster.zig` as the control-plane layer over the existing registry, health inspector, runner storage, message storage, lease manager, and local runners. The controller mutates durable lease storage for rebalance, drain, and recovery, while runners synchronize their local lease caches before processing reassigned shards. Inspection and CLI output are deterministic text/JSON views over durable stores.

**Tech Stack:** Zig standard library, zigeffect cluster modules, file/in-memory runner and message storage, `bun:test` repo commands, `zig build` verification gates.

---

Spec: `docs/superpowers/specs/2026-06-10-zigeffect-real-clustering-design.md`

Roadmap: `docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md`

## File Map

- Create `packages/zigeffect/src/cluster/real_cluster.zig`
  - Owns controller, membership, placement, rebalance, drain, recovery, split-brain, inspection, and formatters.
- Create `packages/zigeffect/test/real_cluster_test.zig`
  - Adds red/green coverage for each M50 behavior.
- Create `packages/zigeffect/tools/cluster_inspect.zig`
  - Minimal deterministic CLI for cluster inspection output.
- Modify `packages/zigeffect/test/all_test.zig`
  - Imports `real_cluster_test.zig`.
- Modify `packages/zigeffect/src/cluster/root.zig`
  - Re-exports real cluster public surface.
- Modify `packages/zigeffect/src/zigeffect.zig`
  - Adds top-level aliases.
- Modify `packages/zigeffect/src/cluster/shard_lease.zig`
  - Adds `syncOwnedLeasesFromStorage`.
- Modify `packages/zigeffect/src/cluster/local_cluster.zig`
  - Adds `syncOwnedShards`.
- Modify `packages/zigeffect/build.zig`
  - Adds `zig build cluster-inspect` and tool tests.
- Modify `packages/zigeffect/test/public_api_stability_test.zig`
  - Pins new public API aliases and errors.
- Modify docs and roadmap:
  - `packages/zigeffect/docs/architecture.md`
  - `packages/zigeffect/docs/effectts-parity.md`
  - `packages/zigeffect/docs/usage.md`
  - `docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md`
- Create `docs/superpowers/reports/2026-06-10-zigeffect-milestone-50-completion.md`

## Task 1: Public Real Cluster Contract

**Files:**
- Create: `packages/zigeffect/test/real_cluster_test.zig`
- Modify: `packages/zigeffect/test/all_test.zig`
- Modify: `packages/zigeffect/test/public_api_stability_test.zig`
- Create: `packages/zigeffect/src/cluster/real_cluster.zig`
- Modify: `packages/zigeffect/src/cluster/root.zig`
- Modify: `packages/zigeffect/src/zigeffect.zig`

- [ ] **Step 1: Add failing public API tests**

Create `real_cluster_test.zig` with:

```zig
const std = @import("std");
const fx = @import("zigeffect");

test "real cluster public exports are available" {
    try std.testing.expect(@hasDecl(fx.cluster, "real_cluster"));
    try std.testing.expect(@hasDecl(fx.cluster, "RealClusterController"));
    try std.testing.expect(@hasDecl(fx.cluster, "RealClusterControllerOptions"));
    try std.testing.expect(@hasDecl(fx.cluster, "ClusterMembershipState"));
    try std.testing.expect(@hasDecl(fx.cluster, "ClusterAdmissionDecision"));
    try std.testing.expect(@hasDecl(fx.cluster, "ClusterMembershipReport"));
    try std.testing.expect(@hasDecl(fx.cluster, "ClusterPlacementPlan"));
    try std.testing.expect(@hasDecl(fx.cluster, "ClusterRebalancePlan"));
    try std.testing.expect(@hasDecl(fx.cluster, "ClusterDrainPlan"));
    try std.testing.expect(@hasDecl(fx.cluster, "ClusterNodeDownRecoveryPlan"));
    try std.testing.expect(@hasDecl(fx.cluster, "ClusterSplitBrainReport"));
    try std.testing.expect(@hasDecl(fx.cluster, "ClusterInspectionReport"));
    try std.testing.expect(@hasDecl(fx.cluster, "formatClusterInspectionText"));
    try std.testing.expect(@hasDecl(fx.cluster, "formatClusterInspectionJson"));
    try std.testing.expect(@hasDecl(fx, "RealClusterController"));
}
```

Add `_ = @import("real_cluster_test.zig");` to `all_test.zig`.

Extend public API stability tests with the new cluster names and top-level
aliases.

- [ ] **Step 2: Run the red test**

Run:

```bash
cd packages/zigeffect && zig build test-raw
```

Expected: compile failure for missing `real_cluster` declarations.

- [ ] **Step 3: Add the minimal module and exports**

Create `real_cluster.zig` with public enums, structs, `deinit` methods, and
`RealClusterController.init`. Include `RealClusterError`:

```zig
pub const RealClusterError = error{
    InvalidShardCount,
    InvalidLeaseTtl,
    NoActiveClusterMembers,
    RunnerStillAlive,
};
```

Export the module and aliases through `cluster/root.zig` and `zigeffect.zig`.

- [ ] **Step 4: Run green test and commit**

Run:

```bash
cd packages/zigeffect && zig build test-raw
zig fmt --check packages/zigeffect/src/cluster/real_cluster.zig packages/zigeffect/src/cluster/root.zig packages/zigeffect/src/zigeffect.zig packages/zigeffect/test/real_cluster_test.zig packages/zigeffect/test/all_test.zig packages/zigeffect/test/public_api_stability_test.zig
```

Commit:

```bash
git add packages/zigeffect/src/cluster/real_cluster.zig packages/zigeffect/src/cluster/root.zig packages/zigeffect/src/zigeffect.zig packages/zigeffect/test/real_cluster_test.zig packages/zigeffect/test/all_test.zig packages/zigeffect/test/public_api_stability_test.zig
git commit -m "feat(zigeffect): add real cluster public contract"
```

## Task 2: Membership Admission And Discovery

**Files:**
- Modify: `packages/zigeffect/test/real_cluster_test.zig`
- Modify: `packages/zigeffect/src/cluster/real_cluster.zig`

- [ ] **Step 1: Add failing membership tests**

Add tests for:

- `real cluster admits runners and discovers active members`
- `real cluster reports joining down and leaving members`
- controller init rejects zero shard count and zero lease ttl

The first test should:

```zig
var registry = fx.LocalRunnerRegistry.init(std.testing.allocator);
defer registry.deinit();
var runner_storage_state = fx.InMemoryRunnerStorage.init(std.testing.allocator);
defer runner_storage_state.deinit();
var message_storage_state = fx.InMemoryMessageStorage.init(std.testing.allocator);
defer message_storage_state.deinit();

var controller = try fx.RealClusterController.init(std.testing.allocator, .{
    .runner_storage = runner_storage_state.asRunnerStorage(),
    .message_storage = message_storage_state.asMessageStorage(),
    .registry = &registry,
    .options = .{
        .shard_count = 8,
        .lease_ttl_ms = 1_000,
        .health_options = .{ .degraded_after_ms = 100, .unhealthy_after_ms = 300 },
    },
});

const runner_a = fx.runnerAddress("machine-real", "runner-a");
try std.testing.expectEqual(fx.ClusterAdmissionDecision.admitted, try controller.admitRunner(.{
    .address = runner_a,
    .name = "runner-a",
    .started_at_ms = 1_000,
}));
try std.testing.expectEqual(fx.ClusterAdmissionDecision.already_member, try controller.admitRunner(.{
    .address = runner_a,
    .name = "runner-a-again",
    .started_at_ms = 1_001,
}));
_ = try controller.recordHeartbeat(.{ .address = runner_a, .sequence = 1, .observed_at_ms = 1_010 });

var report = try controller.discoverRunners(std.testing.allocator, 1_050);
defer report.deinit();
try std.testing.expectEqual(@as(usize, 1), report.members.len);
try std.testing.expectEqual(fx.ClusterMembershipState.active, report.members[0].state);
try std.testing.expectEqual(@as(usize, 1), report.active);
```

- [ ] **Step 2: Run red test**

Run:

```bash
cd packages/zigeffect && zig build test-raw
```

Expected: missing controller methods and membership report behavior.

- [ ] **Step 3: Implement membership**

Implement:

- `RealClusterController.init`
- `admitRunner`
- `recordHeartbeat`
- `discoverRunners`
- `ClusterMembershipReport.deinit`

Sort members by machine id then runner id.

- [ ] **Step 4: Run green test and commit**

Run raw tests and fmt, then commit:

```bash
git add packages/zigeffect/src/cluster/real_cluster.zig packages/zigeffect/test/real_cluster_test.zig
git commit -m "feat(zigeffect): add cluster membership discovery"
```

## Task 3: Placement And Rebalance

**Files:**
- Modify: `packages/zigeffect/test/real_cluster_test.zig`
- Modify: `packages/zigeffect/src/cluster/real_cluster.zig`

- [ ] **Step 1: Add failing placement/rebalance tests**

Add tests for:

- balanced placement over active members;
- no active members returns `NoActiveClusterMembers`;
- rebalance plan emits acquire actions for empty lease storage;
- applying the plan writes durable leases;
- adding a runner emits handoff actions and changes durable owners.

Use a helper:

```zig
fn expectPlacementOwners(plan: fx.ClusterPlacementPlan, owners: []const fx.RunnerAddress) !void {
    for (plan.placements, 0..) |placement, index| {
        try std.testing.expect(placement.owner.eql(owners[index % owners.len]));
    }
}
```

- [ ] **Step 2: Run red test**

Run:

```bash
cd packages/zigeffect && zig build test-raw
```

Expected: missing `placementPlan`, `rebalancePlan`, and
`applyRebalancePlan`.

- [ ] **Step 3: Implement placement/rebalance**

Implement:

- `ClusterPlacementPlan.deinit`
- `ClusterRebalancePlan.deinit`
- `placementPlan`
- `rebalancePlan`
- `applyRebalancePlan`

The apply path releases stale owners before acquiring desired owners. Count
applied actions in `recent_rebalance_actions`.

- [ ] **Step 4: Run green test and commit**

Run raw tests and fmt, then commit:

```bash
git add packages/zigeffect/src/cluster/real_cluster.zig packages/zigeffect/test/real_cluster_test.zig
git commit -m "feat(zigeffect): add cluster placement and rebalancing"
```

## Task 4: Runner Lease Sync And Graceful Drain

**Files:**
- Modify: `packages/zigeffect/test/real_cluster_test.zig`
- Modify: `packages/zigeffect/src/cluster/shard_lease.zig`
- Modify: `packages/zigeffect/src/cluster/local_cluster.zig`
- Modify: `packages/zigeffect/src/cluster/real_cluster.zig`
- Modify: `packages/zigeffect/src/cluster/root.zig`
- Modify: `packages/zigeffect/src/zigeffect.zig`

- [ ] **Step 1: Add failing sync and drain tests**

Add tests that:

- acquire leases through the controller;
- call `runner.syncOwnedShards()`;
- route a message to a reassigned shard;
- tick the replacement runner and read the durable reply;
- drain a runner and verify its leases move to active members.

The message correctness assertion should mirror existing multi-runner tests:
the reply payload must be `value=drained`.

- [ ] **Step 2: Run red test**

Run:

```bash
cd packages/zigeffect && zig build test-raw
```

Expected: missing `syncOwnedLeasesFromStorage`, `syncOwnedShards`, and
`drainRunner`.

- [ ] **Step 3: Implement sync and drain**

Add to `LocalShardLeaseManager`:

```zig
pub fn syncOwnedLeasesFromStorage(self: *LocalShardLeaseManager) !usize
```

It reads `storage.leases`, keeps only leases owned by `self.owner`, replaces
`owned_leases`, and returns the new count.

Add to `LocalClusterRunner`:

```zig
pub fn syncOwnedShards(self: *LocalClusterRunner) !usize
```

It syncs the lease manager and reloads runtime owned shards.

Implement `RealClusterController.drainRunner`. It marks the runner stopped,
recomputes placement from remaining active members, releases drained leases,
acquires replacement leases, and returns `ClusterDrainPlan`.

- [ ] **Step 4: Run green test and commit**

Run raw tests and fmt, then commit:

```bash
git add packages/zigeffect/src/cluster/shard_lease.zig packages/zigeffect/src/cluster/local_cluster.zig packages/zigeffect/src/cluster/real_cluster.zig packages/zigeffect/src/cluster/root.zig packages/zigeffect/src/zigeffect.zig packages/zigeffect/test/real_cluster_test.zig
git commit -m "feat(zigeffect): add cluster drain and runner lease sync"
```

## Task 5: Node-Down Recovery And Split-Brain Evidence

**Files:**
- Modify: `packages/zigeffect/test/real_cluster_test.zig`
- Modify: `packages/zigeffect/src/cluster/real_cluster.zig`

- [ ] **Step 1: Add failing recovery and split-brain tests**

Add tests for:

- `recoverNodeDown` refuses a healthy runner;
- unhealthy runner leases are released and reassigned;
- recovered runner syncs and processes a queued message;
- `detectSplitBrain` reports missing storage lease, wrong owner, and stale
  epoch.

Build local split-brain input from two `RunnerLeaseBatch` snapshots.

- [ ] **Step 2: Run red test**

Run:

```bash
cd packages/zigeffect && zig build test-raw
```

Expected: missing recovery and split-brain APIs.

- [ ] **Step 3: Implement recovery and split-brain**

Implement:

- `ClusterNodeDownRecoveryPlan`
- `recoverNodeDown`
- `ClusterSplitBrainReport.deinit`
- `detectSplitBrain`

Recovery uses the health inspector, releases dead-runner leases, and acquires
replacement leases from the active placement plan.

- [ ] **Step 4: Run green test and commit**

Run raw tests and fmt, then commit:

```bash
git add packages/zigeffect/src/cluster/real_cluster.zig packages/zigeffect/test/real_cluster_test.zig
git commit -m "feat(zigeffect): add node down recovery and split brain reports"
```

## Task 6: Inspection Formatters And CLI

**Files:**
- Modify: `packages/zigeffect/test/real_cluster_test.zig`
- Modify: `packages/zigeffect/src/cluster/real_cluster.zig`
- Create: `packages/zigeffect/tools/cluster_inspect.zig`
- Modify: `packages/zigeffect/build.zig`

- [ ] **Step 1: Add failing inspection and CLI tests**

Add tests for:

- `inspectCluster` returns membership, leases, metrics, rebalance actions, and
  failure counts;
- `formatClusterInspectionText` contains `members=`, `leases=`, and `lag=`;
- `formatClusterInspectionJson` contains the report schema and counts;
- `zig build cluster-inspect -- --help` exits successfully.

- [ ] **Step 2: Run red tests**

Run:

```bash
cd packages/zigeffect && zig build test-raw
cd packages/zigeffect && zig build cluster-inspect -- --help
```

Expected: missing inspection methods, formatter functions, tool, and build
step.

- [ ] **Step 3: Implement inspection and CLI**

Implement:

- `ClusterInspectionReport.deinit`
- `inspectCluster`
- `formatClusterInspectionText`
- `formatClusterInspectionJson`

Create `tools/cluster_inspect.zig` with:

```zig
pub fn main() !void {
    try std.fs.File.stdout().writeAll("zigeffect cluster inspect\n");
}
```

Add a `--help` path that prints available flags and exits. Wire the build step
as `cluster-inspect`.

- [ ] **Step 4: Run green tests and commit**

Run raw tests, CLI help, and fmt. Commit:

```bash
git add packages/zigeffect/src/cluster/real_cluster.zig packages/zigeffect/tools/cluster_inspect.zig packages/zigeffect/build.zig packages/zigeffect/test/real_cluster_test.zig
git commit -m "feat(zigeffect): add cluster inspection command"
```

## Task 7: Docs, Roadmap, Report, And Full Gate

**Files:**
- Modify: `packages/zigeffect/docs/architecture.md`
- Modify: `packages/zigeffect/docs/effectts-parity.md`
- Modify: `packages/zigeffect/docs/usage.md`
- Modify: `docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md`
- Create: `docs/superpowers/reports/2026-06-10-zigeffect-milestone-50-completion.md`

- [ ] **Step 1: Update docs**

Document `real_cluster.zig`, runner lease sync, controller placement/rebalance,
node-down recovery, split-brain reports, and `cluster-inspect`.

- [ ] **Step 2: Mark roadmap M50 complete**

Mark every M50 deliverable and acceptance checkbox complete.

- [ ] **Step 3: Add completion report**

Create a report listing shipped APIs, tests, and verification commands.

- [ ] **Step 4: Run full verification**

Run:

```bash
cd packages/zigeffect && zig build test-raw
cd packages/zigeffect && zig build release-gate
cd packages/zigeffect && zig build examples
cd packages/zigeffect && zig build cluster-inspect -- --help
bun run zigeffect:test
bun run zig:test
zig fmt --check packages/zigeffect/src/cluster/real_cluster.zig packages/zigeffect/src/cluster/shard_lease.zig packages/zigeffect/src/cluster/local_cluster.zig packages/zigeffect/src/cluster/root.zig packages/zigeffect/src/zigeffect.zig packages/zigeffect/test/real_cluster_test.zig packages/zigeffect/test/all_test.zig packages/zigeffect/test/public_api_stability_test.zig packages/zigeffect/tools/cluster_inspect.zig packages/zigeffect/build.zig
git diff --check
run the project marker scan on modified source, tests, tools, docs, spec, plan, roadmap, and report
```

Expected: all commands pass.

- [ ] **Step 5: Commit closeout**

Run:

```bash
git add packages/zigeffect/docs/architecture.md packages/zigeffect/docs/effectts-parity.md packages/zigeffect/docs/usage.md docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md docs/superpowers/reports/2026-06-10-zigeffect-milestone-50-completion.md
git commit -m "docs(zigeffect): complete real clustering"
```

## Self-Review Checklist

- The controller uses existing durable stores and does not add a second message
  delivery path.
- Rebalance, drain, and recovery mutate durable lease storage and require
  runner sync before processing.
- Placement is deterministic and sorted by runner identity.
- Split-brain reports compare local snapshots with durable storage evidence.
- Inspection reports cover membership, leases, lag, actions, and failures.
- `cluster-inspect` exists and is wired into `zig build`.
- Full gate passes before M50 is marked complete.
