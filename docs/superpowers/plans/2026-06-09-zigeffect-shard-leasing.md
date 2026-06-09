# zigeffect Shard Leasing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a local shard lease manager with bounded lease duration, refresh cadence, graceful handoff, runner-death recovery, and causal shard ownership events.

**Architecture:** Build `cluster/shard_lease.zig` over the existing `RunnerStorage` contract. Keep storage authoritative for lease conflicts and expiration, while the manager owns local cadence decisions, owned-lease tracking, handoff, health-inspected recovery, and optional `CausalStore` event recording.

**Tech Stack:** Zig, `std.ArrayList`, zigeffect `RunnerStorage`, `LocalRunnerRegistry`, `LocalRunnerHealthInspector`, `CausalStore`, `bun run zigeffect:test`, `zig build examples`, `bun run zig:test`.

---

## File Structure

- Create `packages/zigeffect/src/cluster/shard_lease.zig`: lease manager options, cadence helpers, local owned-lease manager, handoff and recovery reports, and causal event recording.
- Create `packages/zigeffect/test/shard_lease_test.zig`: tests for exports, options, cadence, acquisition, refresh, expired reacquisition, handoff, recovery, and causal events.
- Modify `packages/zigeffect/src/services/causal.zig`: add cluster shard lease event kinds and taxonomy entries.
- Modify `packages/zigeffect/src/cluster/root.zig`: import and re-export shard lease APIs.
- Modify `packages/zigeffect/src/zigeffect.zig`: top-level shard lease aliases.
- Modify `packages/zigeffect/test/all_test.zig`: import `shard_lease_test.zig`.
- Modify `packages/zigeffect/docs/architecture.md`: document `shard_lease.zig`.
- Modify `docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md`: mark Milestone 30 complete after verification.
- Modify `docs/superpowers/plans/2026-06-09-zigeffect-shard-leasing.md`: mark plan checkboxes complete during closeout.

## Task 1: Public Surface, Options, And Refresh Cadence

**Files:**
- Create: `packages/zigeffect/test/shard_lease_test.zig`
- Create: `packages/zigeffect/src/cluster/shard_lease.zig`
- Modify: `packages/zigeffect/src/cluster/root.zig`
- Modify: `packages/zigeffect/src/zigeffect.zig`
- Modify: `packages/zigeffect/test/all_test.zig`

- [ ] **Step 1: Write failing public export and cadence tests**

Create `packages/zigeffect/test/shard_lease_test.zig`:

```zig
const std = @import("std");
const fx = @import("zigeffect");

test "shard lease public exports are available" {
    try std.testing.expect(@hasDecl(fx.cluster, "shard_lease"));
    try std.testing.expect(@hasDecl(fx.cluster, "LocalShardLeaseManager"));
    try std.testing.expect(@hasDecl(fx.cluster, "ShardLeaseManagerOptions"));
    try std.testing.expect(@hasDecl(fx.cluster, "ShardLeaseRefreshReport"));
    try std.testing.expect(@hasDecl(fx.cluster, "ShardLeaseRecoveryReport"));
    try std.testing.expect(@hasDecl(fx.cluster, "ShardHandoffReport"));
    try std.testing.expect(@hasDecl(fx, "LocalShardLeaseManager"));
}

test "shard lease manager validates ttl and refresh cadence" {
    var storage_state = fx.InMemoryRunnerStorage.init(std.testing.allocator);
    defer storage_state.deinit();
    const storage = storage_state.asRunnerStorage();
    const owner = fx.runnerAddress("machine-a", "runner-a");

    try std.testing.expectError(error.InvalidLeaseOptions, fx.LocalShardLeaseManager.init(
        std.testing.allocator,
        storage,
        owner,
        .{ .ttl_ms = 0, .refresh_interval_ms = 10 },
    ));
    try std.testing.expectError(error.InvalidLeaseOptions, fx.LocalShardLeaseManager.init(
        std.testing.allocator,
        storage,
        owner,
        .{ .ttl_ms = 100, .refresh_interval_ms = 0 },
    ));
    try std.testing.expectError(error.InvalidLeaseOptions, fx.LocalShardLeaseManager.init(
        std.testing.allocator,
        storage,
        owner,
        .{ .ttl_ms = 100, .refresh_interval_ms = 100 },
    ));
}

test "shard lease cadence reports next refresh and due state" {
    const owner = fx.runnerAddress("machine-a", "runner-a");
    const lease: fx.ShardLease = .{
        .shard_id = 7,
        .owner = owner,
        .acquired_at_ms = 1_000,
        .refreshed_at_ms = 1_000,
        .expires_at_ms = 2_000,
        .version = 1,
    };
    const options: fx.ShardLeaseManagerOptions = .{ .ttl_ms = 1_000, .refresh_interval_ms = 250 };

    try std.testing.expectEqual(@as(u64, 1_250), fx.shardLeaseNextRefreshAt(lease, options));
    try std.testing.expect(!fx.shardLeaseRefreshDue(lease, options, 1_249));
    try std.testing.expect(fx.shardLeaseRefreshDue(lease, options, 1_250));
}
```

Add this import to `packages/zigeffect/test/all_test.zig`:

```zig
    _ = @import("shard_lease_test.zig");
```

- [ ] **Step 2: Run the red test**

Run:

```bash
bun run zigeffect:test
```

Expected: FAIL with missing `LocalShardLeaseManager` or `shardLeaseRefreshDue`.
Use `zig build test-raw` from `packages/zigeffect` if the causal wrapper hides
the compile error.

- [ ] **Step 3: Implement minimal public surface and cadence helpers**

Create `packages/zigeffect/src/cluster/shard_lease.zig` with:

```zig
const std = @import("std");
const runner = @import("runner.zig");
const runner_storage = @import("runner_storage.zig");

pub const Allocator = std.mem.Allocator;
pub const RunnerAddress = runner.RunnerAddress;
pub const ShardId = runner_storage.ShardId;
pub const RunnerStorage = runner_storage.RunnerStorage;
pub const RunnerLeaseTtlMs = runner_storage.RunnerLeaseTtlMs;
pub const ShardLease = runner_storage.ShardLease;
pub const RunnerLeaseBatch = runner_storage.RunnerLeaseBatch;

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
    owned_leases: std.ArrayList(ShardLease) = .empty,

    pub fn init(allocator: Allocator, storage: RunnerStorage, owner: RunnerAddress, options: ShardLeaseManagerOptions) ShardLeaseManagerError!LocalShardLeaseManager
    pub fn deinit(self: *LocalShardLeaseManager) void
};

pub fn shardLeaseNextRefreshAt(lease: ShardLease, options: ShardLeaseManagerOptions) u64
pub fn shardLeaseRefreshDue(lease: ShardLease, options: ShardLeaseManagerOptions, now_ms: u64) bool
```

Export the module and aliases from `cluster/root.zig` and `zigeffect.zig`.

- [ ] **Step 4: Run green checks**

Run:

```bash
bun run zigeffect:test
zig fmt --check packages/zigeffect/src/cluster/shard_lease.zig packages/zigeffect/src/cluster/root.zig packages/zigeffect/src/zigeffect.zig packages/zigeffect/test/shard_lease_test.zig packages/zigeffect/test/all_test.zig
git diff --check
```

Expected: all commands exit 0.

- [ ] **Step 5: Commit public surface**

```bash
git add packages/zigeffect/src/cluster/shard_lease.zig packages/zigeffect/src/cluster/root.zig packages/zigeffect/src/zigeffect.zig packages/zigeffect/test/shard_lease_test.zig packages/zigeffect/test/all_test.zig
git commit -m "feat(zigeffect): add shard lease manager surface"
```

## Task 2: Acquire, Refresh, And Causal Events

**Files:**
- Modify: `packages/zigeffect/test/shard_lease_test.zig`
- Modify: `packages/zigeffect/src/cluster/shard_lease.zig`
- Modify: `packages/zigeffect/src/services/causal.zig`
- Modify: `packages/zigeffect/src/cluster/root.zig`
- Modify: `packages/zigeffect/src/zigeffect.zig`

- [ ] **Step 1: Add failing acquire, refresh, and causal tests**

Append:

```zig
test "shard lease manager acquires shards and records causal events" {
    var storage_state = fx.InMemoryRunnerStorage.init(std.testing.allocator);
    defer storage_state.deinit();
    const storage = storage_state.asRunnerStorage();
    const owner = fx.runnerAddress("machine-a", "runner-a");
    var causal = fx.CausalStore.init(std.testing.allocator);
    defer causal.deinit();

    var manager = try fx.LocalShardLeaseManager.init(
        std.testing.allocator,
        storage,
        owner,
        .{ .ttl_ms = 1_000, .refresh_interval_ms = 250 },
    );
    defer manager.deinit();
    manager.attachCausalStore(&causal, 900);

    const lease = try manager.acquireShard(5, 1_000);
    try std.testing.expectEqual(@as(fx.ShardId, 5), lease.shard_id);
    try std.testing.expect(manager.ownsShard(5));
    try std.testing.expectError(error.ShardAlreadyOwned, manager.acquireShard(5, 1_100));

    var owned = try manager.ownedLeases(std.testing.allocator);
    defer owned.deinit();
    try std.testing.expectEqual(@as(usize, 1), owned.leases.len);

    var snapshot = try causal.snapshot(std.testing.allocator);
    defer snapshot.deinit();
    try std.testing.expect(snapshotHasKind(snapshot, .cluster_shard_lease_acquired));
}

test "shard lease manager refreshes only due owned leases" {
    var storage_state = fx.InMemoryRunnerStorage.init(std.testing.allocator);
    defer storage_state.deinit();
    const storage = storage_state.asRunnerStorage();
    const owner = fx.runnerAddress("machine-a", "runner-a");
    var causal = fx.CausalStore.init(std.testing.allocator);
    defer causal.deinit();

    var manager = try fx.LocalShardLeaseManager.init(
        std.testing.allocator,
        storage,
        owner,
        .{ .ttl_ms = 1_000, .refresh_interval_ms = 250 },
    );
    defer manager.deinit();
    manager.attachCausalStore(&causal, 901);

    _ = try manager.acquireShard(6, 1_000);
    const early = try manager.refreshOwnedLeases(1_249);
    try std.testing.expectEqual(@as(usize, 0), early.refreshed);

    const due = try manager.refreshOwnedLeases(1_250);
    try std.testing.expectEqual(@as(usize, 1), due.refreshed);
    const stored = (try storage.lease(6)).?;
    try std.testing.expectEqual(@as(u64, 2_250), stored.expires_at_ms);
    try std.testing.expectEqual(@as(u64, 2), stored.version);

    var snapshot = try causal.snapshot(std.testing.allocator);
    defer snapshot.deinit();
    try std.testing.expect(snapshotHasKind(snapshot, .cluster_shard_lease_refreshed));
}

fn snapshotHasKind(snapshot: fx.CausalSnapshot, kind: fx.CausalEventKind) bool {
    for (snapshot.events) |event| {
        if (event.kind == kind) return true;
    }
    return false;
}
```

- [ ] **Step 2: Run the red test**

Run:

```bash
bun run zigeffect:test
```

Expected: FAIL on missing manager methods and missing causal event kinds.

- [ ] **Step 3: Implement acquire, refresh, owned lease tracking, and causal event kinds**

Add causal enum variants to `CausalEventKind` and the structural taxonomy:

```zig
cluster_shard_lease_acquired,
cluster_shard_lease_refreshed,
cluster_shard_lease_released,
cluster_shard_lease_conflict,
cluster_shard_handoff_started,
cluster_shard_recovery_started,
cluster_shard_recovery_completed,
```

Implement manager fields and methods:

```zig
causal_store: ?*causal_mod.CausalStore = null,
causal_run_id: ?u64 = null,
pub fn attachCausalStore(self: *LocalShardLeaseManager, store: *causal_mod.CausalStore, run_id: u64) void
pub fn acquireShard(self: *LocalShardLeaseManager, shard_id: ShardId, now_ms: u64) !ShardLease
pub fn refreshOwnedLeases(self: *LocalShardLeaseManager, now_ms: u64) !ShardLeaseRefreshReport
pub fn ownsShard(self: *const LocalShardLeaseManager, shard_id: ShardId) bool
pub fn ownedLeases(self: *const LocalShardLeaseManager, allocator: Allocator) Allocator.Error!RunnerLeaseBatch
```

`recordCausal` should allocate a label like `shard-{d}` and a redacted detail
with shard id, owner ids, version, and expiration, then call `CausalStore.record`.

- [ ] **Step 4: Run green checks**

Run:

```bash
bun run zigeffect:test
zig fmt --check packages/zigeffect/src/cluster/shard_lease.zig packages/zigeffect/src/services/causal.zig packages/zigeffect/test/shard_lease_test.zig packages/zigeffect/src/cluster/root.zig packages/zigeffect/src/zigeffect.zig
git diff --check
```

Expected: all commands exit 0.

- [ ] **Step 5: Commit acquire and refresh**

```bash
git add packages/zigeffect/src/cluster/shard_lease.zig packages/zigeffect/src/services/causal.zig packages/zigeffect/src/cluster/root.zig packages/zigeffect/src/zigeffect.zig packages/zigeffect/test/shard_lease_test.zig
git commit -m "feat(zigeffect): acquire and refresh shard leases"
```

## Task 3: Expired Reacquire And Graceful Handoff

**Files:**
- Modify: `packages/zigeffect/test/shard_lease_test.zig`
- Modify: `packages/zigeffect/src/cluster/shard_lease.zig`

- [ ] **Step 1: Add failing expired reacquire and handoff tests**

Append:

```zig
test "shard lease manager reacquires expired owned leases" {
    var storage_state = fx.InMemoryRunnerStorage.init(std.testing.allocator);
    defer storage_state.deinit();
    const storage = storage_state.asRunnerStorage();
    const owner = fx.runnerAddress("machine-a", "runner-a");

    var manager = try fx.LocalShardLeaseManager.init(
        std.testing.allocator,
        storage,
        owner,
        .{ .ttl_ms = 100, .refresh_interval_ms = 25 },
    );
    defer manager.deinit();

    _ = try manager.acquireShard(8, 1_000);
    const report = try manager.refreshOwnedLeases(1_100);
    try std.testing.expectEqual(@as(usize, 1), report.expired);
    try std.testing.expectEqual(@as(usize, 1), report.reacquired);
    const stored = (try storage.lease(8)).?;
    try std.testing.expect(stored.owner.eql(owner));
    try std.testing.expectEqual(@as(u64, 1_200), stored.expires_at_ms);
    try std.testing.expectEqual(@as(u64, 2), stored.version);
}

test "shard lease manager gracefully hands off owned shards" {
    var storage_state = fx.InMemoryRunnerStorage.init(std.testing.allocator);
    defer storage_state.deinit();
    const storage = storage_state.asRunnerStorage();
    const source_owner = fx.runnerAddress("machine-a", "runner-a");
    const target_owner = fx.runnerAddress("machine-b", "runner-b");

    var source = try fx.LocalShardLeaseManager.init(
        std.testing.allocator,
        storage,
        source_owner,
        .{ .ttl_ms = 1_000, .refresh_interval_ms = 250 },
    );
    defer source.deinit();
    var target = try fx.LocalShardLeaseManager.init(
        std.testing.allocator,
        storage,
        target_owner,
        .{ .ttl_ms = 1_000, .refresh_interval_ms = 250 },
    );
    defer target.deinit();

    _ = try source.acquireShard(9, 1_000);
    const handoff = try source.handoffShard(9, target_owner, 1_100);
    try std.testing.expectEqual(@as(fx.ShardId, 9), handoff.shard_id);
    try std.testing.expect(!source.ownsShard(9));
    try std.testing.expect((try storage.lease(9)) == null);

    const target_lease = try target.acquireShard(9, 1_101);
    try std.testing.expect(target_lease.owner.eql(target_owner));
    try std.testing.expect(target.ownsShard(9));
    try std.testing.expectError(error.ShardNotOwned, source.handoffShard(9, target_owner, 1_200));
}
```

- [ ] **Step 2: Run the red test**

Run:

```bash
bun run zigeffect:test
```

Expected: FAIL on missing expired reacquire behavior, `releaseShard`, or
`handoffShard`.

- [ ] **Step 3: Implement expired reacquire, release, and handoff**

Implement:

```zig
pub fn releaseShard(self: *LocalShardLeaseManager, shard_id: ShardId, now_ms: u64) !void
pub fn handoffShard(self: *LocalShardLeaseManager, shard_id: ShardId, target: RunnerAddress, now_ms: u64) !ShardHandoffReport
```

In `refreshOwnedLeases`, handle `error.LeaseExpired` by incrementing `expired`
and calling `storage.acquire` with the same owner, shard, current time, and TTL.
On successful reacquire, replace the owned lease and increment `reacquired`.
On `LeaseConflict`, remove the local owned lease, increment `conflicts`, record a
conflict event, and continue.

- [ ] **Step 4: Run green checks**

Run:

```bash
bun run zigeffect:test
zig fmt --check packages/zigeffect/src/cluster/shard_lease.zig packages/zigeffect/test/shard_lease_test.zig
git diff --check
```

Expected: all commands exit 0.

- [ ] **Step 5: Commit handoff and expired reacquire**

```bash
git add packages/zigeffect/src/cluster/shard_lease.zig packages/zigeffect/test/shard_lease_test.zig
git commit -m "feat(zigeffect): hand off and reacquire shard leases"
```

## Task 4: Runner Death Recovery

**Files:**
- Modify: `packages/zigeffect/test/shard_lease_test.zig`
- Modify: `packages/zigeffect/src/cluster/shard_lease.zig`

- [ ] **Step 1: Add failing runner death recovery tests**

Append:

```zig
test "shard lease recovery refuses live runners" {
    var storage_state = fx.InMemoryRunnerStorage.init(std.testing.allocator);
    defer storage_state.deinit();
    const storage = storage_state.asRunnerStorage();
    const live = fx.runnerAddress("machine-a", "runner-a");
    const survivor = fx.runnerAddress("machine-b", "runner-b");

    var registry = fx.LocalRunnerRegistry.init(std.testing.allocator);
    defer registry.deinit();
    _ = try registry.registerRunner(.{ .address = live, .name = "live", .started_at_ms = 1_000 });
    _ = try registry.recordHeartbeat(.{ .address = live, .sequence = 1, .observed_at_ms = 1_100 });
    const inspector = try fx.LocalRunnerHealthInspector.init(.{ .degraded_after_ms = 100, .unhealthy_after_ms = 500 });

    var manager = try fx.LocalShardLeaseManager.init(
        std.testing.allocator,
        storage,
        survivor,
        .{ .ttl_ms = 1_000, .refresh_interval_ms = 250 },
    );
    defer manager.deinit();

    try std.testing.expectError(error.RunnerStillAlive, manager.recoverDeadRunner(&registry, &inspector, live, 1_150));
}

test "shard lease recovery releases dead runner leases for survivor reacquisition" {
    var storage_state = fx.InMemoryRunnerStorage.init(std.testing.allocator);
    defer storage_state.deinit();
    const storage = storage_state.asRunnerStorage();
    const dead = fx.runnerAddress("machine-a", "runner-a");
    const survivor = fx.runnerAddress("machine-b", "runner-b");
    var causal = fx.CausalStore.init(std.testing.allocator);
    defer causal.deinit();

    var registry = fx.LocalRunnerRegistry.init(std.testing.allocator);
    defer registry.deinit();
    _ = try registry.registerRunner(.{ .address = dead, .name = "dead", .started_at_ms = 1_000 });
    _ = try registry.recordHeartbeat(.{ .address = dead, .sequence = 1, .observed_at_ms = 1_050 });
    const inspector = try fx.LocalRunnerHealthInspector.init(.{ .degraded_after_ms = 100, .unhealthy_after_ms = 300 });

    _ = try storage.acquire(.{ .shard_id = 12, .owner = dead, .now_ms = 1_050, .ttl_ms = 10_000 });

    var survivor_manager = try fx.LocalShardLeaseManager.init(
        std.testing.allocator,
        storage,
        survivor,
        .{ .ttl_ms = 1_000, .refresh_interval_ms = 250 },
    );
    defer survivor_manager.deinit();
    survivor_manager.attachCausalStore(&causal, 902);

    const recovery = try survivor_manager.recoverDeadRunner(&registry, &inspector, dead, 1_400);
    try std.testing.expectEqual(@as(usize, 1), recovery.released);
    try std.testing.expect((try storage.lease(12)) == null);

    const reacquired = try survivor_manager.acquireShard(12, 1_401);
    try std.testing.expect(reacquired.owner.eql(survivor));

    var snapshot = try causal.snapshot(std.testing.allocator);
    defer snapshot.deinit();
    try std.testing.expect(snapshotHasKind(snapshot, .cluster_shard_recovery_started));
    try std.testing.expect(snapshotHasKind(snapshot, .cluster_shard_recovery_completed));
}
```

- [ ] **Step 2: Run the red test**

Run:

```bash
bun run zigeffect:test
```

Expected: FAIL on missing `recoverDeadRunner`.

- [ ] **Step 3: Implement runner death recovery**

Implement:

```zig
pub fn recoverDeadRunner(
    self: *LocalShardLeaseManager,
    registry: *runner_mod.LocalRunnerRegistry,
    inspector: *const runner_mod.LocalRunnerHealthInspector,
    dead_runner: RunnerAddress,
    now_ms: u64,
) !ShardLeaseRecoveryReport
```

Call `inspector.inspectRunner(registry, dead_runner, now_ms)`. Proceed only when
the resulting state is `.unhealthy` or `.stopped`. Record recovery started,
call `storage.releaseAll(dead_runner)`, record recovery completed, and return
the release count.

- [ ] **Step 4: Run green checks**

Run:

```bash
bun run zigeffect:test
zig fmt --check packages/zigeffect/src/cluster/shard_lease.zig packages/zigeffect/test/shard_lease_test.zig
git diff --check
```

Expected: all commands exit 0.

- [ ] **Step 5: Commit runner death recovery**

```bash
git add packages/zigeffect/src/cluster/shard_lease.zig packages/zigeffect/test/shard_lease_test.zig
git commit -m "feat(zigeffect): recover shard leases after runner death"
```

## Task 5: Documentation, Roadmap, And Verification

**Files:**
- Modify: `packages/zigeffect/docs/architecture.md`
- Modify: `docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md`
- Modify: `docs/superpowers/plans/2026-06-09-zigeffect-shard-leasing.md`

- [ ] **Step 1: Update architecture docs**

Add this bullet in the `src/cluster/` section:

```markdown
- `shard_lease.zig`: local shard lease manager with bounded TTLs, refresh
  cadence, owned-lease tracking, graceful handoff, dead-runner recovery, and
  causal shard ownership events.
```

- [ ] **Step 2: Mark Milestone 30 complete in the roadmap**

Change every Milestone 30 deliverable and acceptance checkbox from `[ ]` to
`[x]`.

- [ ] **Step 3: Mark this implementation plan complete**

Change each task checkbox in
`docs/superpowers/plans/2026-06-09-zigeffect-shard-leasing.md` from `[ ]` to
`[x]`.

- [ ] **Step 4: Run the full Milestone 30 verification gate**

Run:

```bash
bun run zigeffect:test
zig build examples
bun run zig:test
zig fmt --check packages/zigeffect/src/cluster/shard_lease.zig packages/zigeffect/src/cluster/root.zig packages/zigeffect/src/zigeffect.zig packages/zigeffect/src/services/causal.zig packages/zigeffect/test/shard_lease_test.zig packages/zigeffect/test/all_test.zig
git diff --check
rg -n 'TO''DO|TB''D|implement'' later|fill'' in' packages/zigeffect/src/cluster packages/zigeffect/src/services/causal.zig packages/zigeffect/test/shard_lease_test.zig packages/zigeffect/docs/architecture.md docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md docs/superpowers/specs/2026-06-09-zigeffect-shard-leasing-design.md docs/superpowers/plans/2026-06-09-zigeffect-shard-leasing.md
```

Run `zig build examples` from `packages/zigeffect`. Run the other commands from
the repository root. Expected: build/test/format/diff commands exit 0. The
placeholder scan exits 1 with no matches.

- [ ] **Step 5: Commit docs and roadmap**

```bash
git add packages/zigeffect/docs/architecture.md docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md docs/superpowers/plans/2026-06-09-zigeffect-shard-leasing.md
git commit -m "docs(zigeffect): mark shard leasing complete"
```
