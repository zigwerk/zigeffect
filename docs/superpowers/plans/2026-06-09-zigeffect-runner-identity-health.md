# zigeffect Runner Identity Health Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add runner identity, startup registration, heartbeat records, persisted in-memory health transitions, and local runner health inspection for Milestone 28.

**Architecture:** Add `packages/zigeffect/src/cluster/runner.zig` as the local runner participant module. It owns stable runner ids, an allocator-backed in-memory registry, health event history, and a deterministic health inspector that mutates the registry only by persisted health events and state changes.

**Tech Stack:** Zig, `std.hash.Fnv1a_64`, `std.ArrayList`, `bun run zigeffect:test`, `zig build examples`, `bun run zig:test`.

---

## File Structure

- Create `packages/zigeffect/src/cluster/runner.zig`: runner ids, registration records, heartbeat history, health events, registry, inspector, reports.
- Create `packages/zigeffect/test/runner_test.zig`: public exports, identity stability, registration, heartbeat, inspector, report behavior.
- Modify `packages/zigeffect/src/cluster/root.zig`: import and re-export runner APIs.
- Modify `packages/zigeffect/src/zigeffect.zig`: add top-level runner aliases.
- Modify `packages/zigeffect/test/all_test.zig`: import `runner_test.zig`.
- Modify `packages/zigeffect/docs/architecture.md`: document `runner.zig`.
- Modify `docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md`: mark Milestone 28 complete after verification.

## Task 1: Runner Identity Public Surface

**Files:**
- Create: `packages/zigeffect/test/runner_test.zig`
- Create: `packages/zigeffect/src/cluster/runner.zig`
- Modify: `packages/zigeffect/src/cluster/root.zig`
- Modify: `packages/zigeffect/src/zigeffect.zig`
- Modify: `packages/zigeffect/test/all_test.zig`

- [x] **Step 1: Write failing public export and identity tests**

Create `packages/zigeffect/test/runner_test.zig`:

```zig
const std = @import("std");
const fx = @import("zigeffect");

test "runner public exports are available" {
    try std.testing.expect(@hasDecl(fx.cluster, "runner"));
    try std.testing.expect(@hasDecl(fx.cluster, "RunnerId"));
    try std.testing.expect(@hasDecl(fx.cluster, "MachineId"));
    try std.testing.expect(@hasDecl(fx.cluster, "RunnerAddress"));
    try std.testing.expect(@hasDecl(fx.cluster, "RunnerHealthState"));
    try std.testing.expect(@hasDecl(fx.cluster, "RunnerRegistration"));
    try std.testing.expect(@hasDecl(fx.cluster, "RunnerHeartbeat"));
    try std.testing.expect(@hasDecl(fx.cluster, "LocalRunnerRegistry"));
    try std.testing.expect(@hasDecl(fx.cluster, "LocalRunnerHealthInspector"));
    try std.testing.expect(@hasDecl(fx, "RunnerAddress"));
}

test "runner ids are stable machine-sensitive and process-sensitive" {
    const machine = fx.machineId("dev-machine");
    const same_machine = fx.machineId("dev-machine");
    const other_machine = fx.machineId("ci-machine");
    const runner = fx.runnerId(machine, "process-a");
    const same_runner = fx.runnerId(machine, "process-a");
    const other_process = fx.runnerId(machine, "process-b");
    const other_machine_runner = fx.runnerId(other_machine, "process-a");

    try std.testing.expectEqual(machine, same_machine);
    try std.testing.expect(machine != other_machine);
    try std.testing.expectEqual(runner, same_runner);
    try std.testing.expect(runner != other_process);
    try std.testing.expect(runner != other_machine_runner);

    const address = fx.runnerAddress("dev-machine", "process-a");
    try std.testing.expect(address.eql(.{ .machine_id = machine, .runner_id = runner }));
}
```

Add this import to `packages/zigeffect/test/all_test.zig`:

```zig
    _ = @import("runner_test.zig");
```

- [x] **Step 2: Run the red test**

Run:

```bash
bun run zigeffect:test
```

Expected: FAIL with missing declarations for runner types or helper functions.

- [x] **Step 3: Implement runner identity types and exports**

Create the first version of `packages/zigeffect/src/cluster/runner.zig`:

```zig
const std = @import("std");

pub const Allocator = std.mem.Allocator;
pub const RunnerId = u64;
pub const MachineId = u64;
pub const RunnerHeartbeatSequence = u64;

pub const RunnerAddress = struct {
    machine_id: MachineId,
    runner_id: RunnerId,

    pub fn eql(self: RunnerAddress, other: RunnerAddress) bool {
        return self.machine_id == other.machine_id and self.runner_id == other.runner_id;
    }
};

pub const RunnerHealthState = enum { starting, healthy, degraded, unhealthy, stopped };
pub const RunnerHealthReason = enum { startup_registered, heartbeat_recorded, heartbeat_late, heartbeat_expired, runner_stopped };

pub const RunnerRegistration = struct {
    address: RunnerAddress,
    name: []const u8,
    started_at_ms: u64,
};

pub const RunnerHeartbeat = struct {
    address: RunnerAddress,
    sequence: RunnerHeartbeatSequence,
    observed_at_ms: u64,
};

pub const RunnerHealthEvent = struct {
    address: RunnerAddress,
    previous_state: ?RunnerHealthState,
    next_state: RunnerHealthState,
    reason: RunnerHealthReason,
    at_ms: u64,
};

pub const RunnerHealthSnapshot = struct {
    address: RunnerAddress,
    name: []const u8,
    state: RunnerHealthState,
    started_at_ms: u64,
    last_heartbeat_at_ms: ?u64 = null,
    last_heartbeat_sequence: ?RunnerHeartbeatSequence = null,
    heartbeat_age_ms: ?u64 = null,
    health_event_count: usize = 0,
};

pub const RunnerHealthReport = struct {
    allocator: Allocator,
    generated_at_ms: u64,
    snapshots: []RunnerHealthSnapshot,

    pub fn deinit(self: *RunnerHealthReport) void {
        self.allocator.free(self.snapshots);
    }
};

pub const RunnerHealthInspectorOptions = struct {
    degraded_after_ms: u64 = 5_000,
    unhealthy_after_ms: u64 = 15_000,
};

pub const RunnerRegistryError = error{
    DuplicateRunner,
    RunnerNotFound,
    InvalidHeartbeatSequence,
    InvalidHealthThresholds,
};

pub const LocalRunnerRegistry = struct {
    allocator: Allocator,

    pub fn init(allocator: Allocator) LocalRunnerRegistry {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *LocalRunnerRegistry) void {
        _ = self;
    }
};

pub const LocalRunnerHealthInspector = struct {
    options: RunnerHealthInspectorOptions,

    pub fn init(options: RunnerHealthInspectorOptions) RunnerRegistryError!LocalRunnerHealthInspector {
        if (options.degraded_after_ms > options.unhealthy_after_ms) return error.InvalidHealthThresholds;
        return .{ .options = options };
    }
};

pub fn machineId(machine_key: []const u8) MachineId {
    var hasher = std.hash.Fnv1a_64.init();
    hasher.update("zigeffect.cluster.machine.v1:");
    hasher.update(machine_key);
    return hasher.final();
}

pub fn runnerId(machine_id: MachineId, runner_key: []const u8) RunnerId {
    var hasher = std.hash.Fnv1a_64.init();
    var machine_buf: [8]u8 = undefined;
    std.mem.writeInt(u64, &machine_buf, machine_id, .little);
    hasher.update("zigeffect.cluster.runner.v1:");
    hasher.update(&machine_buf);
    hasher.update(":");
    hasher.update(runner_key);
    return hasher.final();
}

pub fn runnerAddress(machine_key: []const u8, runner_key: []const u8) RunnerAddress {
    const machine_id = machineId(machine_key);
    return .{
        .machine_id = machine_id,
        .runner_id = runnerId(machine_id, runner_key),
    };
}
```

In `cluster/root.zig`, import `runner.zig` and re-export the public types and
helper functions. In `zigeffect.zig`, add top-level aliases near the cluster
aliases.

- [x] **Step 4: Run the green identity test**

Run:

```bash
bun run zigeffect:test
zig fmt --check packages/zigeffect/src/cluster/runner.zig packages/zigeffect/src/cluster/root.zig packages/zigeffect/src/zigeffect.zig packages/zigeffect/test/runner_test.zig packages/zigeffect/test/all_test.zig
git diff --check
```

Expected: all commands exit 0.

- [x] **Step 5: Commit runner identity**

```bash
git add packages/zigeffect/src/cluster/runner.zig packages/zigeffect/src/cluster/root.zig packages/zigeffect/src/zigeffect.zig packages/zigeffect/test/runner_test.zig packages/zigeffect/test/all_test.zig
git commit -m "feat(zigeffect): add runner identity surface"
```

## Task 2: Startup Registration And Health Events

**Files:**
- Modify: `packages/zigeffect/test/runner_test.zig`
- Modify: `packages/zigeffect/src/cluster/runner.zig`

- [x] **Step 1: Add failing registration tests**

Append these tests:

```zig
test "local runner registry persists startup registration and event" {
    var registry = fx.LocalRunnerRegistry.init(std.testing.allocator);
    defer registry.deinit();

    const address = fx.runnerAddress("machine-a", "runner-a");
    const snapshot = try registry.registerRunner(.{
        .address = address,
        .name = "runner-a",
        .started_at_ms = 1_000,
    });

    try std.testing.expectEqual(@as(usize, 1), registry.runnerCount());
    try std.testing.expectEqual(fx.RunnerHealthState.starting, snapshot.state);
    try std.testing.expectEqualStrings("runner-a", snapshot.name);
    try std.testing.expectEqual(@as(usize, 1), try registry.healthEventCount(address));

    const event = (try registry.lastHealthEvent(address)).?;
    try std.testing.expectEqual(@as(?fx.RunnerHealthState, null), event.previous_state);
    try std.testing.expectEqual(fx.RunnerHealthState.starting, event.next_state);
    try std.testing.expectEqual(fx.RunnerHealthReason.startup_registered, event.reason);
    try std.testing.expectEqual(@as(u64, 1_000), event.at_ms);

    try std.testing.expectError(error.DuplicateRunner, registry.registerRunner(.{
        .address = address,
        .name = "duplicate",
        .started_at_ms = 1_100,
    }));
}
```

- [x] **Step 2: Run the red registration test**

Run:

```bash
bun run zigeffect:test
```

Expected: FAIL with missing methods such as `registerRunner`, `runnerCount`,
`healthEventCount`, or `lastHealthEvent`.

- [x] **Step 3: Implement registration storage and health event access**

Extend `LocalRunnerRegistry` with `records` and `events` arrays, an internal
`RunnerRecord`, `registerRunner`, `runnerCount`, `state`, `snapshot`,
`healthEventCount`, `lastHealthEvent`, and helper methods for finding records.
Registration must clone runner names and free them in `deinit`.

- [x] **Step 4: Run the green registration test**

Run:

```bash
bun run zigeffect:test
zig fmt --check packages/zigeffect/src/cluster/runner.zig packages/zigeffect/test/runner_test.zig
git diff --check
```

Expected: all commands exit 0.

- [x] **Step 5: Commit registration storage**

```bash
git add packages/zigeffect/src/cluster/runner.zig packages/zigeffect/test/runner_test.zig
git commit -m "feat(zigeffect): persist runner startup registration"
```

## Task 3: Heartbeat Records And Healthy Transitions

**Files:**
- Modify: `packages/zigeffect/test/runner_test.zig`
- Modify: `packages/zigeffect/src/cluster/runner.zig`

- [x] **Step 1: Add failing heartbeat tests**

Append this test:

```zig
test "runner heartbeat records are monotonic and transition to healthy" {
    var registry = fx.LocalRunnerRegistry.init(std.testing.allocator);
    defer registry.deinit();

    const address = fx.runnerAddress("machine-a", "runner-a");
    _ = try registry.registerRunner(.{ .address = address, .name = "runner-a", .started_at_ms = 1_000 });

    const snapshot = try registry.recordHeartbeat(.{
        .address = address,
        .sequence = 1,
        .observed_at_ms = 1_250,
    });

    try std.testing.expectEqual(fx.RunnerHealthState.healthy, snapshot.state);
    try std.testing.expectEqual(@as(usize, 1), try registry.heartbeatCount(address));
    try std.testing.expectEqual(@as(u64, 1_250), snapshot.last_heartbeat_at_ms.?);
    try std.testing.expectEqual(@as(fx.RunnerHeartbeatSequence, 1), snapshot.last_heartbeat_sequence.?);
    try std.testing.expectEqual(@as(usize, 2), try registry.healthEventCount(address));

    const event = (try registry.lastHealthEvent(address)).?;
    try std.testing.expectEqual(fx.RunnerHealthState.starting, event.previous_state.?);
    try std.testing.expectEqual(fx.RunnerHealthState.healthy, event.next_state);
    try std.testing.expectEqual(fx.RunnerHealthReason.heartbeat_recorded, event.reason);

    try std.testing.expectError(error.InvalidHeartbeatSequence, registry.recordHeartbeat(.{
        .address = address,
        .sequence = 1,
        .observed_at_ms = 1_300,
    }));
    try std.testing.expectError(error.RunnerNotFound, registry.recordHeartbeat(.{
        .address = fx.runnerAddress("missing", "runner"),
        .sequence = 1,
        .observed_at_ms = 1_300,
    }));
}
```

- [x] **Step 2: Run the red heartbeat test**

Run:

```bash
bun run zigeffect:test
```

Expected: FAIL with missing methods such as `recordHeartbeat` or
`heartbeatCount`.

- [x] **Step 3: Implement heartbeat storage and monotonic sequence validation**

Add a `heartbeats` array, `heartbeatCount`, `lastHeartbeat`, and
`recordHeartbeat`. `recordHeartbeat` must reject missing runners and
non-increasing sequences, append the heartbeat, update the runner state to
`healthy`, and record a health event only when the state changes.

- [x] **Step 4: Run the green heartbeat test**

Run:

```bash
bun run zigeffect:test
zig fmt --check packages/zigeffect/src/cluster/runner.zig packages/zigeffect/test/runner_test.zig
git diff --check
```

Expected: all commands exit 0.

- [x] **Step 5: Commit heartbeat records**

```bash
git add packages/zigeffect/src/cluster/runner.zig packages/zigeffect/test/runner_test.zig
git commit -m "feat(zigeffect): record runner heartbeats"
```

## Task 4: Local Health Inspector And Reports

**Files:**
- Modify: `packages/zigeffect/test/runner_test.zig`
- Modify: `packages/zigeffect/src/cluster/runner.zig`

- [x] **Step 1: Add failing inspector and report tests**

Append these tests:

```zig
test "runner health inspector persists degraded and unhealthy transitions" {
    var registry = fx.LocalRunnerRegistry.init(std.testing.allocator);
    defer registry.deinit();

    const address = fx.runnerAddress("machine-a", "runner-a");
    _ = try registry.registerRunner(.{ .address = address, .name = "runner-a", .started_at_ms = 1_000 });
    _ = try registry.recordHeartbeat(.{ .address = address, .sequence = 1, .observed_at_ms = 1_050 });

    const inspector = try fx.LocalRunnerHealthInspector.init(.{
        .degraded_after_ms = 100,
        .unhealthy_after_ms = 300,
    });

    const healthy = try inspector.inspectRunner(&registry, address, 1_120);
    try std.testing.expectEqual(fx.RunnerHealthState.healthy, healthy.state);
    try std.testing.expectEqual(@as(usize, 2), try registry.healthEventCount(address));

    const degraded = try inspector.inspectRunner(&registry, address, 1_150);
    try std.testing.expectEqual(fx.RunnerHealthState.degraded, degraded.state);
    var event = (try registry.lastHealthEvent(address)).?;
    try std.testing.expectEqual(fx.RunnerHealthReason.heartbeat_late, event.reason);

    const unhealthy = try inspector.inspectRunner(&registry, address, 1_350);
    try std.testing.expectEqual(fx.RunnerHealthState.unhealthy, unhealthy.state);
    event = (try registry.lastHealthEvent(address)).?;
    try std.testing.expectEqual(fx.RunnerHealthReason.heartbeat_expired, event.reason);
    try std.testing.expectEqual(@as(usize, 4), try registry.healthEventCount(address));

    _ = try inspector.inspectRunner(&registry, address, 1_360);
    try std.testing.expectEqual(@as(usize, 4), try registry.healthEventCount(address));
}

test "stopped runner remains stopped during health inspection" {
    var registry = fx.LocalRunnerRegistry.init(std.testing.allocator);
    defer registry.deinit();

    const address = fx.runnerAddress("machine-a", "runner-a");
    _ = try registry.registerRunner(.{ .address = address, .name = "runner-a", .started_at_ms = 1_000 });
    try registry.markStopped(address, 1_100);

    const inspector = try fx.LocalRunnerHealthInspector.init(.{
        .degraded_after_ms = 100,
        .unhealthy_after_ms = 300,
    });
    const snapshot = try inspector.inspectRunner(&registry, address, 2_000);
    try std.testing.expectEqual(fx.RunnerHealthState.stopped, snapshot.state);
    try std.testing.expectEqual(fx.RunnerHealthReason.runner_stopped, (try registry.lastHealthEvent(address)).?.reason);
}

test "runner health inspector reports all current runners" {
    var registry = fx.LocalRunnerRegistry.init(std.testing.allocator);
    defer registry.deinit();

    const first = fx.runnerAddress("machine-a", "runner-a");
    const second = fx.runnerAddress("machine-a", "runner-b");
    _ = try registry.registerRunner(.{ .address = first, .name = "runner-a", .started_at_ms = 1_000 });
    _ = try registry.registerRunner(.{ .address = second, .name = "runner-b", .started_at_ms = 1_000 });
    _ = try registry.recordHeartbeat(.{ .address = first, .sequence = 1, .observed_at_ms = 1_050 });

    const inspector = try fx.LocalRunnerHealthInspector.init(.{
        .degraded_after_ms = 100,
        .unhealthy_after_ms = 300,
    });
    var report = try inspector.inspectAll(std.testing.allocator, &registry, 1_400);
    defer report.deinit();

    try std.testing.expectEqual(@as(u64, 1_400), report.generated_at_ms);
    try std.testing.expectEqual(@as(usize, 2), report.snapshots.len);
    try std.testing.expectEqual(fx.RunnerHealthState.unhealthy, report.snapshots[0].state);
    try std.testing.expectEqual(fx.RunnerHealthState.unhealthy, report.snapshots[1].state);
}
```

- [x] **Step 2: Run the red inspector test**

Run:

```bash
bun run zigeffect:test
```

Expected: FAIL with missing methods such as `inspectRunner`, `markStopped`, or
`inspectAll`.

- [x] **Step 3: Implement health inspection and reports**

Add `markStopped`, `LocalRunnerHealthInspector.inspectRunner`,
`LocalRunnerHealthInspector.inspectAll`, `RunnerHealthReport.deinit`, and a
private state-transition helper. Inspection must persist only actual state
changes and must leave stopped runners stopped.

- [x] **Step 4: Run the green inspector test**

Run:

```bash
bun run zigeffect:test
zig fmt --check packages/zigeffect/src/cluster/runner.zig packages/zigeffect/test/runner_test.zig
git diff --check
```

Expected: all commands exit 0.

- [x] **Step 5: Commit health inspector**

```bash
git add packages/zigeffect/src/cluster/runner.zig packages/zigeffect/test/runner_test.zig
git commit -m "feat(zigeffect): inspect runner health"
```

## Task 5: Documentation, Roadmap, And Verification

**Files:**
- Modify: `packages/zigeffect/docs/architecture.md`
- Modify: `docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md`
- Modify: `docs/superpowers/plans/2026-06-09-zigeffect-runner-identity-health.md`

- [x] **Step 1: Update architecture docs**

Add this bullet in the `src/cluster/` section:

```markdown
- `runner.zig`: stable runner and machine identity, startup registration,
  heartbeat history, in-memory health events, and local runner health
  inspection reports.
```

- [x] **Step 2: Mark Milestone 28 complete in the roadmap**

Change every Milestone 28 deliverable and acceptance checkbox from `[ ]` to
`[x]`.

- [x] **Step 3: Run the full Milestone 28 verification gate**

Run:

```bash
bun run zigeffect:test
cd packages/zigeffect && zig build examples
bun run zig:test
zig fmt --check packages/zigeffect/src/cluster/runner.zig packages/zigeffect/src/cluster/root.zig packages/zigeffect/src/zigeffect.zig packages/zigeffect/test/runner_test.zig packages/zigeffect/test/all_test.zig
git diff --check
rg -n 'TO''DO|TB''D|implement'' later|fill'' in' packages/zigeffect/src/cluster packages/zigeffect/test/runner_test.zig packages/zigeffect/docs/architecture.md docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md docs/superpowers/specs/2026-06-09-zigeffect-runner-identity-health-design.md docs/superpowers/plans/2026-06-09-zigeffect-runner-identity-health.md
```

Expected: the build/test/format/diff commands exit 0. The `rg` placeholder scan
exits 1 with no matches.

- [x] **Step 4: Commit docs and roadmap**

```bash
git add packages/zigeffect/docs/architecture.md docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md docs/superpowers/plans/2026-06-09-zigeffect-runner-identity-health.md
git commit -m "docs(zigeffect): mark runner health complete"
```
