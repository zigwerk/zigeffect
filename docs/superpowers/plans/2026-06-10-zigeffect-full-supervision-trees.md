# zigeffect Full Supervision Trees Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship Milestone 51 by making supervision trees a complete runtime and cluster feature with typed children, dynamic supervision, inspection, distributed shard cleanup, runner drain reporting, and full verification.

**Architecture:** Extend the existing deterministic `Supervisor` instead of creating a second restart engine. Add inspection and tree aggregation in `runtime/supervisor.zig`, then feed cluster shard, transport, runner service, and drain failures into explicit `ClusterSupervisionReport` counters.

**Tech Stack:** Zig standard library, zigeffect runtime modules, zigeffect cluster modules, `bun:test` repository scripts, `zig build` package gates.

---

## File Structure

- Modify `packages/zigeffect/src/runtime/supervisor.zig`
  - Add child kinds, dynamic strategy, bounded decision records, inspection reports, formatters, dynamic child lifecycle APIs, and `SupervisorTree`.
- Modify `packages/zigeffect/src/zigeffect.zig`
  - Mirror runtime and cluster public exports.
- Modify `packages/zigeffect/src/cluster/supervision.zig`
  - Add cluster service restart aliases, shard worker and transport supervision helpers, runner service counters, and report aggregation.
- Modify `packages/zigeffect/src/cluster/root.zig`
  - Export the new cluster supervision helpers and aliases.
- Modify `packages/zigeffect/src/cluster/runtime.zig`
  - Add shard worker restart state and `superviseShardWorkerExit`.
- Modify `packages/zigeffect/src/cluster/local_cluster.zig`
  - Add runner service supervision helper and supervised tick failure accounting.
- Modify `packages/zigeffect/src/cluster/real_cluster.zig`
  - Add supervised runner drain report generation.
- Modify `packages/zigeffect/test/supervisor_test.zig`
  - Add runtime contract, dynamic strategy, inspection, and tree tests.
- Modify `packages/zigeffect/test/cluster_supervision_test.zig`
  - Add service restart, transport, shard worker, runner service, and runner drain tests.
- Modify `docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md`
  - Mark Milestone 51 completed after verification.
- Create `docs/superpowers/reports/2026-06-10-zigeffect-milestone-51-completion.md`
  - Record shipped behavior and verification evidence.

---

### Task 1: Runtime Supervision Public Surface And Dynamic Strategy

**Files:**
- Modify: `packages/zigeffect/test/supervisor_test.zig`
- Modify: `packages/zigeffect/src/runtime/supervisor.zig`
- Modify: `packages/zigeffect/src/zigeffect.zig`

- [x] **Step 1: Write failing public surface and dynamic strategy tests**

Append these tests to `packages/zigeffect/test/supervisor_test.zig`:

```zig
test "full supervision public exports are available" {
    try std.testing.expect(@hasDecl(fx.runtime, "SupervisorDecisionRecord"));
    try std.testing.expect(@hasDecl(fx.runtime, "SupervisorInspectionReport"));
    try std.testing.expect(@hasDecl(fx.runtime, "formatSupervisorInspectionText"));
    try std.testing.expect(@hasDecl(fx.runtime, "formatSupervisorInspectionJson"));
    try std.testing.expect(@hasDecl(fx.runtime, "SupervisorTree"));
    try std.testing.expect(@hasDecl(fx.runtime, "SupervisorTreeOptions"));
    try std.testing.expect(@hasDecl(fx.runtime, "SupervisorTreeNodeOptions"));
    try std.testing.expect(@hasDecl(fx.runtime, "SupervisorTreeInspectionReport"));
    try std.testing.expect(@hasDecl(fx, "SupervisorDecisionRecord"));
    try std.testing.expect(@hasDecl(fx, "SupervisorTree"));
}

test "supervisor child specs cover full runtime cluster domains" {
    const specs = [_]fx.SupervisorChildSpec{
        .{ .id = 10, .name = "activity", .kind = .activity },
        .{ .id = 11, .name = "shard-worker", .kind = .shard_worker },
        .{ .id = 12, .name = "runner-service", .kind = .runner_service },
        .{ .id = 13, .name = "transport-server", .kind = .transport_server },
    };
    try std.testing.expectEqual(fx.SupervisorChildKind.activity, specs[0].kind);
    try std.testing.expectEqual(fx.SupervisorChildKind.shard_worker, specs[1].kind);
    try std.testing.expectEqual(fx.SupervisorChildKind.runner_service, specs[2].kind);
    try std.testing.expectEqual(fx.SupervisorChildKind.transport_server, specs[3].kind);
}

test "dynamic supervisor restarts removes and rejects missing dynamic children" {
    var supervisor = fx.Supervisor.init(std.testing.allocator, .{
        .id = 70,
        .name = "dynamic-root",
        .strategy = .dynamic,
    });
    defer supervisor.deinit();

    try supervisor.addChild(.{ .id = 1, .name = "queue", .kind = .queue_worker });
    try supervisor.addChild(.{ .id = 2, .name = "activity", .kind = .activity });
    try supervisor.startAll(1_000);

    const decision = try supervisor.reportChildExit(2, .{ .failure = "activity failed" }, 1_100);
    try std.testing.expectEqual(fx.SupervisorStrategy.dynamic, decision.strategy);
    try std.testing.expectEqual(@as(usize, 1), decision.restarted_children);
    try std.testing.expectEqual(@as(usize, 0), try supervisor.childRestartCount(1));
    try std.testing.expectEqual(@as(usize, 1), try supervisor.childRestartCount(2));

    try supervisor.stopChild(2, .interrupted);
    try std.testing.expectEqual(fx.SupervisorChildStatus.stopped, try supervisor.childStatus(2));
    try supervisor.removeChild(2);
    try std.testing.expectError(error.ChildNotFound, supervisor.childStatus(2));
}
```

- [x] **Step 2: Run test to verify it fails**

Run from `packages/zigeffect`:

```bash
zig build test-raw --summary all
```

Expected: FAIL with missing declarations, missing enum tags, or missing `stopChild` and `removeChild` methods.

- [x] **Step 3: Implement the minimal public surface and dynamic strategy**

In `packages/zigeffect/src/runtime/supervisor.zig`:

```zig
pub const SupervisorStrategy = enum { one_for_one, one_for_all, rest_for_one, dynamic };
pub const SupervisorChildKind = enum {
    fiber,
    activity,
    workflow_worker,
    queue_worker,
    entity,
    runner,
    shard,
    shard_worker,
    runner_service,
    transport_server,
};

pub fn stopChild(self: *Supervisor, child_id: SupervisorChildId, exit: SupervisorChildExit) SupervisorError!void {
    const index = self.findChildIndex(child_id) orelse return error.ChildNotFound;
    markStoppedOrFailed(&self.children.items[index], exit);
}

pub fn removeChild(self: *Supervisor, child_id: SupervisorChildId) SupervisorError!void {
    const index = self.findChildIndex(child_id) orelse return error.ChildNotFound;
    _ = self.children.orderedRemove(index);
}
```

Update `strategyAffects` so `.dynamic` affects only the failed child:

```zig
fn strategyAffects(strategy: SupervisorStrategy, failed_index: usize, candidate_index: usize) bool {
    return switch (strategy) {
        .one_for_one, .dynamic => candidate_index == failed_index,
        .one_for_all => true,
        .rest_for_one => candidate_index >= failed_index,
    };
}
```

- [x] **Step 4: Export new runtime declarations**

In `packages/zigeffect/src/zigeffect.zig`, add runtime namespace and top-level exports for declarations introduced in this task and later tasks:

```zig
pub const SupervisorDecisionRecord = supervisor.SupervisorDecisionRecord;
pub const SupervisorInspectionReport = supervisor.SupervisorInspectionReport;
pub const formatSupervisorInspectionText = supervisor.formatSupervisorInspectionText;
pub const formatSupervisorInspectionJson = supervisor.formatSupervisorInspectionJson;
pub const SupervisorTree = supervisor.SupervisorTree;
pub const SupervisorTreeOptions = supervisor.SupervisorTreeOptions;
pub const SupervisorTreeNodeOptions = supervisor.SupervisorTreeNodeOptions;
pub const SupervisorTreeInspectionReport = supervisor.SupervisorTreeInspectionReport;
pub const formatSupervisorTreeInspectionText = supervisor.formatSupervisorTreeInspectionText;
pub const formatSupervisorTreeInspectionJson = supervisor.formatSupervisorTreeInspectionJson;
```

- [x] **Step 5: Run test to verify it passes**

Run from `packages/zigeffect`:

```bash
zig build test-raw --summary all
```

Expected: PASS for existing tests and the new dynamic strategy tests after Task 2 declarations are present.

- [x] **Step 6: Commit**

```bash
git add packages/zigeffect/test/supervisor_test.zig packages/zigeffect/src/runtime/supervisor.zig packages/zigeffect/src/zigeffect.zig
git commit -m "feat(zigeffect): add dynamic supervision surface"
```

---

### Task 2: Supervisor Inspection And Decision History

**Files:**
- Modify: `packages/zigeffect/test/supervisor_test.zig`
- Modify: `packages/zigeffect/src/runtime/supervisor.zig`
- Modify: `packages/zigeffect/src/zigeffect.zig`

- [x] **Step 1: Write failing inspection tests**

Append this test to `packages/zigeffect/test/supervisor_test.zig`:

```zig
test "supervisor inspection reports children decisions escalation and shutdown order" {
    var supervisor = fx.Supervisor.init(std.testing.allocator, .{
        .id = 80,
        .name = "inspect-root",
        .strategy = .one_for_one,
        .intensity = .{ .max_restarts = 1, .within_ms = 1_000 },
    });
    defer supervisor.deinit();

    try supervisor.addChild(.{ .id = 1, .name = "fiber", .kind = .fiber, .shutdown_order = 1 });
    try supervisor.addChild(.{ .id = 2, .name = "transport", .kind = .transport_server, .shutdown_order = 10 });
    try supervisor.startAll(1_000);

    _ = try supervisor.reportChildExit(2, .{ .failure = "port closed" }, 1_100);
    _ = try supervisor.reportChildExit(2, .{ .failure = "port closed again" }, 1_200);

    var report = try supervisor.inspect(std.testing.allocator);
    defer report.deinit();
    try std.testing.expectEqual(@as(u64, 80), report.supervisor_id);
    try std.testing.expectEqual(fx.SupervisorStrategy.one_for_one, report.strategy);
    try std.testing.expectEqual(@as(usize, 2), report.children.len);
    try std.testing.expectEqual(@as(usize, 1), report.escalated_children);
    try std.testing.expectEqual(@as(usize, 2), report.decisions.len);
    try std.testing.expect(report.decisions[1].decision.escalated);
    try std.testing.expectEqual(@as(usize, 1), report.decisions[1].affected_children);
    try std.testing.expectEqual(@as(u64, 2), report.shutdown_order[0]);

    const text = try fx.formatSupervisorInspectionText(std.testing.allocator, report);
    defer std.testing.allocator.free(text);
    try std.testing.expect(std.mem.indexOf(u8, text, "inspect-root") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "escalated_children: 1") != null);

    const json = try fx.formatSupervisorInspectionJson(std.testing.allocator, report);
    defer std.testing.allocator.free(json);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"supervisor_id\":80") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"decision_count\":2") != null);
}
```

- [x] **Step 2: Run test to verify it fails**

Run from `packages/zigeffect`:

```bash
zig build test-raw --summary all
```

Expected: FAIL with missing `inspect` method or missing inspection fields.

- [x] **Step 3: Implement decision record storage**

In `packages/zigeffect/src/runtime/supervisor.zig`, add:

```zig
pub const SupervisorDecisionRecord = struct {
    at_ms: u64,
    child: SupervisorChildSnapshot,
    decision: SupervisorDecision,
    affected_children: usize = 0,
};
```

Add to `SupervisorOptions`:

```zig
max_recent_decisions: usize = 32,
```

Add to `Supervisor`:

```zig
recent_decisions: std.ArrayList(SupervisorDecisionRecord) = .empty,
```

Deinitialize it in `Supervisor.deinit`.

When `reportChildExit` finishes each decision branch, append a
`SupervisorDecisionRecord`. Use `restarted_children + stopped_children` for
normal decisions and the escalated affected count for escalation.

- [x] **Step 4: Implement inspection report and formatters**

Add:

```zig
pub const SupervisorInspectionReport = struct {
    allocator: Allocator,
    supervisor_id: SupervisorId,
    name: []const u8,
    strategy: SupervisorStrategy,
    intensity: RestartIntensity,
    children: []SupervisorChildSnapshot,
    decisions: []SupervisorDecisionRecord,
    shutdown_order: []SupervisorChildId,
    running_children: usize = 0,
    stopped_children: usize = 0,
    failed_children: usize = 0,
    escalated_children: usize = 0,
    dynamic_children: usize = 0,

    pub fn deinit(self: *SupervisorInspectionReport) void {
        self.allocator.free(self.children);
        self.allocator.free(self.decisions);
        self.allocator.free(self.shutdown_order);
    }
};
```

Add `Supervisor.inspect`, `formatSupervisorInspectionText`, and
`formatSupervisorInspectionJson`. The text output must include the supervisor
name, strategy, child counts, decision count, and escalation count. The JSON
output must include schema-free stable fields for ids, counts, strategy, and
decision count.

- [x] **Step 5: Run test to verify it passes**

Run from `packages/zigeffect`:

```bash
zig build test-raw --summary all
```

Expected: PASS.

- [x] **Step 6: Commit**

```bash
git add packages/zigeffect/test/supervisor_test.zig packages/zigeffect/src/runtime/supervisor.zig packages/zigeffect/src/zigeffect.zig
git commit -m "feat(zigeffect): add supervisor inspection reports"
```

---

### Task 3: Supervisor Tree Aggregate

**Files:**
- Modify: `packages/zigeffect/test/supervisor_test.zig`
- Modify: `packages/zigeffect/src/runtime/supervisor.zig`
- Modify: `packages/zigeffect/src/zigeffect.zig`

- [x] **Step 1: Write failing supervisor tree test**

Append this test to `packages/zigeffect/test/supervisor_test.zig`:

```zig
test "supervisor tree inspects parent child supervisor nodes and escalations" {
    var tree = fx.SupervisorTree.init(std.testing.allocator, .{
        .id = 900,
        .name = "runtime-tree",
    });
    defer tree.deinit();

    try tree.addSupervisor(.{
        .id = 1,
        .name = "root",
        .strategy = .one_for_all,
    });
    try tree.addSupervisor(.{
        .id = 2,
        .parent_id = 1,
        .name = "cluster-services",
        .strategy = .dynamic,
        .intensity = .{ .max_restarts = 0, .within_ms = 1_000 },
    });
    try tree.addChild(1, .{ .id = 10, .name = "fiber", .kind = .fiber });
    try tree.addChild(2, .{ .id = 20, .name = "transport", .kind = .transport_server });
    try tree.startAll(1_000);

    const decision = try tree.reportChildExit(2, 20, .{ .failure = "transport failed" }, 1_100);
    try std.testing.expect(decision.escalated);

    var report = try tree.inspect(std.testing.allocator);
    defer report.deinit();
    try std.testing.expectEqual(@as(u64, 900), report.tree_id);
    try std.testing.expectEqual(@as(usize, 2), report.nodes.len);
    try std.testing.expectEqual(@as(usize, 2), report.total_children);
    try std.testing.expectEqual(@as(usize, 1), report.total_decisions);
    try std.testing.expectEqual(@as(usize, 1), report.total_escalated_children);
    try std.testing.expectEqual(@as(?u64, 1), report.nodes[1].parent_id);

    const text = try fx.formatSupervisorTreeInspectionText(std.testing.allocator, report);
    defer std.testing.allocator.free(text);
    try std.testing.expect(std.mem.indexOf(u8, text, "runtime-tree") != null);

    const json = try fx.formatSupervisorTreeInspectionJson(std.testing.allocator, report);
    defer std.testing.allocator.free(json);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"tree_id\":900") != null);
}
```

- [x] **Step 2: Run test to verify it fails**

Run from `packages/zigeffect`:

```bash
zig build test-raw --summary all
```

Expected: FAIL with missing `SupervisorTree` implementation or missing report fields.

- [x] **Step 3: Implement tree types**

In `packages/zigeffect/src/runtime/supervisor.zig`, add:

```zig
pub const SupervisorTreeError = error{
    DuplicateSupervisor,
    SupervisorNotFound,
    ParentSupervisorNotFound,
};

pub const SupervisorTreeOptions = struct {
    id: u64,
    name: []const u8,
};

pub const SupervisorTreeNodeOptions = struct {
    id: SupervisorId,
    parent_id: ?SupervisorId = null,
    name: []const u8,
    strategy: SupervisorStrategy = .one_for_one,
    intensity: RestartIntensity = .{},
};

pub const SupervisorTreeNodeSnapshot = struct {
    supervisor_id: SupervisorId,
    parent_id: ?SupervisorId = null,
    name: []const u8,
    strategy: SupervisorStrategy,
    child_count: usize = 0,
    decision_count: usize = 0,
    escalated_children: usize = 0,
};

pub const SupervisorTreeInspectionReport = struct {
    allocator: Allocator,
    tree_id: u64,
    name: []const u8,
    nodes: []SupervisorTreeNodeSnapshot,
    total_children: usize = 0,
    total_decisions: usize = 0,
    total_escalated_children: usize = 0,

    pub fn deinit(self: *SupervisorTreeInspectionReport) void {
        self.allocator.free(self.nodes);
    }
};
```

- [x] **Step 4: Implement `SupervisorTree`**

Add a tree struct that owns node states:

```zig
const SupervisorTreeNodeState = struct {
    parent_id: ?SupervisorId = null,
    supervisor: Supervisor,
};

pub const SupervisorTree = struct {
    allocator: Allocator,
    options: SupervisorTreeOptions,
    nodes: std.ArrayList(SupervisorTreeNodeState) = .empty,

    pub fn init(allocator: Allocator, options: SupervisorTreeOptions) SupervisorTree;
    pub fn deinit(self: *SupervisorTree) void;
    pub fn addSupervisor(self: *SupervisorTree, options: SupervisorTreeNodeOptions) (Allocator.Error || SupervisorTreeError)!void;
    pub fn addChild(self: *SupervisorTree, supervisor_id: SupervisorId, spec: SupervisorChildSpec) (Allocator.Error || SupervisorTreeError || SupervisorError)!void;
    pub fn startAll(self: *SupervisorTree, now_ms: u64) Allocator.Error!void;
    pub fn reportChildExit(self: *SupervisorTree, supervisor_id: SupervisorId, child_id: SupervisorChildId, exit: SupervisorChildExit, now_ms: u64) (Allocator.Error || SupervisorTreeError || SupervisorError)!SupervisorDecision;
    pub fn inspect(self: *SupervisorTree, allocator: Allocator) Allocator.Error!SupervisorTreeInspectionReport;
};
```

Use each node's `Supervisor.inspect` internally when building the tree report.

- [x] **Step 5: Implement tree formatters**

Add `formatSupervisorTreeInspectionText` and `formatSupervisorTreeInspectionJson`
with stable summary fields: tree id, name, node count, total children, total
decisions, and total escalated children.

- [x] **Step 6: Run test to verify it passes**

Run from `packages/zigeffect`:

```bash
zig build test-raw --summary all
```

Expected: PASS.

- [x] **Step 7: Commit**

```bash
git add packages/zigeffect/test/supervisor_test.zig packages/zigeffect/src/runtime/supervisor.zig packages/zigeffect/src/zigeffect.zig
git commit -m "feat(zigeffect): add supervisor tree inspection"
```

---

### Task 4: Cluster Service Restart Reports

**Files:**
- Modify: `packages/zigeffect/test/cluster_supervision_test.zig`
- Modify: `packages/zigeffect/src/cluster/supervision.zig`
- Modify: `packages/zigeffect/src/cluster/root.zig`
- Modify: `packages/zigeffect/src/zigeffect.zig`

- [x] **Step 1: Write failing cluster service restart tests**

Append these tests to `packages/zigeffect/test/cluster_supervision_test.zig`:

```zig
test "cluster service supervision public exports are available" {
    try std.testing.expect(@hasDecl(fx.cluster, "ClusterServiceRestartPolicy"));
    try std.testing.expect(@hasDecl(fx.cluster, "ClusterServiceRestartState"));
    try std.testing.expect(@hasDecl(fx.cluster, "ClusterServiceRestartDecision"));
    try std.testing.expect(@hasDecl(fx.cluster, "superviseTransportFailure"));
    try std.testing.expect(@hasDecl(fx.cluster, "superviseShardWorkerFailure"));
    try std.testing.expect(@hasDecl(fx, "ClusterServiceRestartState"));
    try std.testing.expect(@hasDecl(fx, "superviseTransportFailure"));
}

test "transport failure supervision restarts then escalates" {
    var state = fx.ClusterServiceRestartState.init(std.testing.allocator, .{
        .max_restarts = 1,
        .within_ms = 1_000,
    });
    defer state.deinit();

    const failure = fx.ClusterTransportFailureReport{
        .transport = .production_http,
        .retryable = true,
        .attempts = 2,
        .error_name = "TransportUnavailable",
        .redacted_detail = "runner-a to runner-b",
    };

    const first = try fx.superviseTransportFailure(&state, failure, 1_000);
    try std.testing.expectEqual(@as(usize, 1), first.transport_failures);
    try std.testing.expectEqual(@as(usize, 1), first.transport_restarts);
    try std.testing.expectEqual(@as(usize, 0), first.transport_escalations);

    const second = try fx.superviseTransportFailure(&state, failure, 1_100);
    try std.testing.expectEqual(@as(usize, 1), second.transport_failures);
    try std.testing.expectEqual(@as(usize, 0), second.transport_restarts);
    try std.testing.expectEqual(@as(usize, 1), second.transport_escalations);
}

test "shard worker supervision reports restart and escalation" {
    var state = fx.ClusterServiceRestartState.init(std.testing.allocator, .{
        .max_restarts = 1,
        .within_ms = 1_000,
    });
    defer state.deinit();

    const first = try fx.superviseShardWorkerFailure(&state, 3, 1_000);
    try std.testing.expectEqual(@as(usize, 1), first.shard_worker_failures);
    try std.testing.expectEqual(@as(usize, 1), first.shard_worker_restarts);
    try std.testing.expectEqual(@as(usize, 0), first.shard_worker_escalations);

    const second = try fx.superviseShardWorkerFailure(&state, 3, 1_100);
    try std.testing.expectEqual(@as(usize, 1), second.shard_worker_failures);
    try std.testing.expectEqual(@as(usize, 0), second.shard_worker_restarts);
    try std.testing.expectEqual(@as(usize, 1), second.shard_worker_escalations);
}
```

- [x] **Step 2: Run test to verify it fails**

Run from `packages/zigeffect`:

```bash
zig build test-raw --summary all
```

Expected: FAIL with missing cluster exports or missing counters.

- [x] **Step 3: Extend cluster supervision report**

In `packages/zigeffect/src/cluster/supervision.zig`, add service aliases:

```zig
pub const ClusterServiceRestartPolicy = ClusterRunnerRestartPolicy;
pub const ClusterServiceRestartDecision = ClusterRunnerRestartDecision;
pub const ClusterServiceRestartState = ClusterRunnerRestartState;
```

Add counters to `ClusterSupervisionReport` and include them in `add`:

```zig
shard_worker_failures: usize = 0,
shard_worker_restarts: usize = 0,
shard_worker_escalations: usize = 0,
transport_failures: usize = 0,
transport_restarts: usize = 0,
transport_escalations: usize = 0,
runner_service_failures: usize = 0,
runner_service_restarts: usize = 0,
runner_service_escalations: usize = 0,
runner_drains: usize = 0,
runner_drain_releases: usize = 0,
runner_drain_reassignments: usize = 0,
```

- [x] **Step 4: Implement helper functions**

Add:

```zig
pub fn superviseTransportFailure(
    state: *ClusterServiceRestartState,
    failure: transport.ClusterTransportFailureReport,
    now_ms: u64,
) Allocator.Error!ClusterSupervisionReport {
    _ = failure;
    const decision = try state.recordFailure(now_ms);
    return .{
        .transport_failures = 1,
        .transport_restarts = if (decision.restart_allowed) 1 else 0,
        .transport_escalations = if (decision.escalated) 1 else 0,
    };
}

pub fn superviseShardWorkerFailure(
    state: *ClusterServiceRestartState,
    shard_id: ShardId,
    now_ms: u64,
) Allocator.Error!ClusterSupervisionReport {
    _ = shard_id;
    const decision = try state.recordFailure(now_ms);
    return .{
        .shard_worker_failures = 1,
        .shard_worker_restarts = if (decision.restart_allowed) 1 else 0,
        .shard_worker_escalations = if (decision.escalated) 1 else 0,
    };
}

pub fn superviseRunnerServiceFailure(
    state: *ClusterServiceRestartState,
    now_ms: u64,
) Allocator.Error!ClusterSupervisionReport {
    const decision = try state.recordFailure(now_ms);
    return .{
        .runner_service_failures = 1,
        .runner_service_restarts = if (decision.restart_allowed) 1 else 0,
        .runner_service_escalations = if (decision.escalated) 1 else 0,
        .runner_restarts = if (decision.restart_allowed) 1 else 0,
        .runner_escalations = if (decision.escalated) 1 else 0,
    };
}
```

- [x] **Step 5: Export cluster helpers**

Add exports in `packages/zigeffect/src/cluster/root.zig` and top-level exports in
`packages/zigeffect/src/zigeffect.zig`.

- [x] **Step 6: Run test to verify it passes**

Run from `packages/zigeffect`:

```bash
zig build test-raw --summary all
```

Expected: PASS.

- [x] **Step 7: Commit**

```bash
git add packages/zigeffect/test/cluster_supervision_test.zig packages/zigeffect/src/cluster/supervision.zig packages/zigeffect/src/cluster/root.zig packages/zigeffect/src/zigeffect.zig
git commit -m "feat(zigeffect): add cluster service supervision reports"
```

---

### Task 5: Shard Worker And Runner Service Runtime Integration

**Files:**
- Modify: `packages/zigeffect/test/cluster_supervision_test.zig`
- Modify: `packages/zigeffect/src/cluster/runtime.zig`
- Modify: `packages/zigeffect/src/cluster/local_cluster.zig`

- [x] **Step 1: Write failing integration tests**

Append these tests to `packages/zigeffect/test/cluster_supervision_test.zig`:

```zig
test "cluster runtime shard worker escalation releases owned shard" {
    var runner_storage_state = fx.InMemoryRunnerStorage.init(std.testing.allocator);
    defer runner_storage_state.deinit();
    var message_storage_state = fx.InMemoryMessageStorage.init(std.testing.allocator);
    defer message_storage_state.deinit();
    var lease_manager = try fx.LocalShardLeaseManager.init(
        std.testing.allocator,
        runner_storage_state.asRunnerStorage(),
        fx.runnerAddress("machine-supervision", "runner-shard-worker"),
        .{ .ttl_ms = 1_000, .refresh_interval_ms = 250 },
    );
    defer lease_manager.deinit();

    var runtime = try fx.ClusterRuntime.init(
        std.testing.allocator,
        message_storage_state.asMessageStorage(),
        &lease_manager,
        .{
            .shard_count = 8,
            .shard_worker_restart_policy = .{ .max_restarts = 1, .within_ms = 1_000 },
        },
    );
    defer runtime.deinit();
    _ = try runtime.acquireShard(0, 1_000);

    const first = try runtime.superviseShardWorkerExit(0, .{ .failure = "poll failed" }, 1_100);
    try std.testing.expectEqual(@as(usize, 1), first.shard_worker_restarts);
    try std.testing.expect(runtime.ownsShard(0));

    const second = try runtime.superviseShardWorkerExit(0, .{ .failure = "poll failed again" }, 1_200);
    try std.testing.expectEqual(@as(usize, 1), second.shard_worker_escalations);
    try std.testing.expectEqual(@as(usize, 1), second.shard_releases);
    try std.testing.expect(!runtime.ownsShard(0));
    try std.testing.expect((try runner_storage_state.asRunnerStorage().lease(0)) == null);
}

test "local cluster runner records runner service restart and escalation" {
    var runner_storage_state = fx.InMemoryRunnerStorage.init(std.testing.allocator);
    defer runner_storage_state.deinit();
    var message_storage_state = fx.InMemoryMessageStorage.init(std.testing.allocator);
    defer message_storage_state.deinit();

    var runner = try fx.LocalClusterRunner.init(std.testing.allocator, .{
        .runner = fx.runnerAddress("machine-supervision", "runner-service"),
        .runner_storage = runner_storage_state.asRunnerStorage(),
        .message_storage = message_storage_state.asMessageStorage(),
        .shard_count = 8,
        .runner_index = 0,
        .runner_count = 1,
        .lease_options = .{ .ttl_ms = 1_000, .refresh_interval_ms = 250 },
        .runner_restart_policy = .{ .max_restarts = 1, .within_ms = 1_000 },
    });
    defer runner.deinit();

    const first = try runner.superviseRunnerServiceFailure(1_000);
    try std.testing.expectEqual(@as(usize, 1), first.runner_service_failures);
    try std.testing.expectEqual(@as(usize, 1), first.runner_service_restarts);
    try std.testing.expectEqual(@as(usize, 0), first.runner_service_escalations);

    const second = try runner.superviseRunnerServiceFailure(1_100);
    try std.testing.expectEqual(@as(usize, 1), second.runner_service_failures);
    try std.testing.expectEqual(@as(usize, 0), second.runner_service_restarts);
    try std.testing.expectEqual(@as(usize, 1), second.runner_service_escalations);
}
```

- [x] **Step 2: Run test to verify it fails**

Run from `packages/zigeffect`:

```bash
zig build test-raw --summary all
```

Expected: FAIL with missing `shard_worker_restart_policy`,
`superviseShardWorkerExit`, or `superviseRunnerServiceFailure`.

- [x] **Step 3: Add shard worker restart state to `ClusterRuntime`**

In `packages/zigeffect/src/cluster/runtime.zig`:

```zig
const runtime_supervisor = @import("../runtime/supervisor.zig");

pub const ClusterRuntimeOptions = struct {
    shard_count: ShardCount,
    entity_runtime_options: LocalEntityRuntimeOptions = .{},
    supervision_policy: ClusterSupervisionPolicy = .{},
    shard_worker_restart_policy: supervision.ClusterServiceRestartPolicy = .{},
};
```

Add field:

```zig
shard_worker_restart_state: supervision.ClusterServiceRestartState,
```

Initialize it from options and deinitialize it in `ClusterRuntime.deinit`.

- [x] **Step 4: Implement `ClusterRuntime.superviseShardWorkerExit`**

Add:

```zig
pub fn superviseShardWorkerExit(
    self: *ClusterRuntime,
    shard_id: ShardId,
    exit: runtime_supervisor.SupervisorChildExit,
    now_ms: u64,
) !ClusterSupervisionReport {
    if (!self.ownsShard(shard_id)) return error.ShardNotOwned;
    switch (exit) {
        .success => return .{},
        .failure, .defect, .interrupted => {},
    }

    var report = try supervision.superviseShardWorkerFailure(&self.shard_worker_restart_state, shard_id, now_ms);
    if (report.shard_worker_escalations > 0 and self.supervision_policy.release_shard_on_escalation) {
        try self.releaseShard(shard_id, now_ms);
        report.shard_releases += 1;
    }
    return report;
}
```

- [x] **Step 5: Add runner service helper to `LocalClusterRunner`**

In `packages/zigeffect/src/cluster/local_cluster.zig`, add:

```zig
pub fn superviseRunnerServiceFailure(self: *LocalClusterRunner, now_ms: u64) !ClusterSupervisionReport {
    return supervision.superviseRunnerServiceFailure(&self.runner_restart_state, now_ms);
}
```

Wrap `tickSupervised` error branches by returning `superviseRunnerServiceFailure`
when lease refresh, shard loading, or processing fails before a normal report is
available.

- [x] **Step 6: Run test to verify it passes**

Run from `packages/zigeffect`:

```bash
zig build test-raw --summary all
```

Expected: PASS.

- [x] **Step 7: Commit**

```bash
git add packages/zigeffect/test/cluster_supervision_test.zig packages/zigeffect/src/cluster/runtime.zig packages/zigeffect/src/cluster/local_cluster.zig
git commit -m "feat(zigeffect): supervise shard and runner services"
```

---

### Task 6: Distributed Runner Drain Supervision

**Files:**
- Modify: `packages/zigeffect/test/cluster_supervision_test.zig`
- Modify: `packages/zigeffect/src/cluster/real_cluster.zig`

- [x] **Step 1: Write failing runner drain supervision test**

Append this test to `packages/zigeffect/test/cluster_supervision_test.zig`:

```zig
test "real cluster supervised runner drain reports distributed cleanup" {
    var registry = fx.LocalRunnerRegistry.init(std.testing.allocator);
    defer registry.deinit();
    var runner_storage_state = fx.InMemoryRunnerStorage.init(std.testing.allocator);
    defer runner_storage_state.deinit();
    const runner_storage = runner_storage_state.asRunnerStorage();
    var message_storage_state = fx.InMemoryMessageStorage.init(std.testing.allocator);
    defer message_storage_state.deinit();

    var controller = try fx.RealClusterController.init(std.testing.allocator, .{
        .runner_storage = runner_storage,
        .message_storage = message_storage_state.asMessageStorage(),
        .registry = &registry,
        .options = .{
            .shard_count = 8,
            .lease_ttl_ms = 1_000,
            .health_options = .{ .degraded_after_ms = 100, .unhealthy_after_ms = 300 },
        },
    });

    const runner_a = fx.runnerAddress("machine-supervision", "runner-a");
    const runner_b = fx.runnerAddress("machine-supervision", "runner-b");
    _ = try controller.admitRunner(.{ .address = runner_a, .name = "runner-a", .started_at_ms = 1_000 });
    _ = try controller.recordHeartbeat(.{ .address = runner_a, .sequence = 1, .observed_at_ms = 1_010 });
    _ = try controller.admitRunner(.{ .address = runner_b, .name = "runner-b", .started_at_ms = 1_000 });
    _ = try controller.recordHeartbeat(.{ .address = runner_b, .sequence = 1, .observed_at_ms = 1_010 });

    var placement = try controller.placementPlan(std.testing.allocator, 1_050);
    defer placement.deinit();
    var rebalance = try controller.rebalancePlan(std.testing.allocator, placement);
    defer rebalance.deinit();
    _ = try controller.applyRebalancePlan(rebalance, 1_100);

    const report = try controller.superviseRunnerDrain(runner_a, 1_200);
    try std.testing.expectEqual(@as(usize, 1), report.runner_drains);
    try std.testing.expectEqual(@as(usize, 4), report.runner_drain_releases);
    try std.testing.expectEqual(@as(usize, 4), report.runner_drain_reassignments);
    try std.testing.expectEqual(@as(usize, 8), (try runner_storage.leases(std.testing.allocator)).leases.len);
}
```

When implementing this test, store the leases batch in a variable and deinitialize
it before the test exits.

- [x] **Step 2: Run test to verify it fails**

Run from `packages/zigeffect`:

```bash
zig build test-raw --summary all
```

Expected: FAIL with missing `superviseRunnerDrain`.

- [x] **Step 3: Implement supervised runner drain**

In `packages/zigeffect/src/cluster/real_cluster.zig`, import supervision:

```zig
const supervision = @import("supervision.zig");
```

Add method:

```zig
pub fn superviseRunnerDrain(self: *RealClusterController, address: RunnerAddress, now_ms: u64) !supervision.ClusterSupervisionReport {
    const drain = try self.drainRunner(address, now_ms);
    return .{
        .runner_drains = 1,
        .runner_drain_releases = drain.released,
        .runner_drain_reassignments = drain.reassigned,
        .shard_releases = drain.released,
    };
}
```

- [x] **Step 4: Run test to verify it passes**

Run from `packages/zigeffect`:

```bash
zig build test-raw --summary all
```

Expected: PASS.

- [x] **Step 5: Commit**

```bash
git add packages/zigeffect/test/cluster_supervision_test.zig packages/zigeffect/src/cluster/real_cluster.zig
git commit -m "feat(zigeffect): add supervised runner drain reports"
```

---

### Task 7: Documentation, Roadmap, And Full Verification

**Files:**
- Modify: `docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md`
- Create: `docs/superpowers/reports/2026-06-10-zigeffect-milestone-51-completion.md`

- [x] **Step 1: Update roadmap completion**

In `docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md`, mark every Milestone 51 deliverable and acceptance checkbox complete.

- [x] **Step 2: Write completion report**

Create `docs/superpowers/reports/2026-06-10-zigeffect-milestone-51-completion.md` with:

```markdown
# zigeffect Milestone 51 Completion Report

Date: 2026-06-10

Milestone: 51 - Full Supervision Trees

## Shipped

- Full runtime child kind vocabulary for fibers, activities, workflow workers,
  queue workers, entities, shards, shard workers, runners, runner services, and
  transport servers.
- Dynamic supervision strategy with runtime child stop and removal.
- Supervisor decision history, inspection reports, and text/JSON formatters.
- Supervisor tree aggregation with parent-child links and escalation totals.
- Cluster service restart reports for shard workers, transport servers, runner
  services, and runner drains.
- Shard worker escalation releases shard ownership.
- Supervised runner drain reports distributed release and reassignment counts.

## Verification

- `zig build test-raw`
- `zig build release-gate`
- `zig build examples`
- `zig build cluster-inspect -- --help`
- `bun run zigeffect:test`
- `bun run zig:test`
- `zig fmt --check ...`
- `git diff --check`
- Marker scan for unfinished work patterns
```

- [x] **Step 3: Run formatting**

Run from `packages/zigeffect`:

```bash
zig fmt src/runtime/supervisor.zig src/cluster/supervision.zig src/cluster/root.zig src/cluster/runtime.zig src/cluster/local_cluster.zig src/cluster/real_cluster.zig src/zigeffect.zig test/supervisor_test.zig test/cluster_supervision_test.zig
```

- [x] **Step 4: Run full verification gate**

Run:

```bash
zig build test-raw
zig build release-gate
zig build examples
zig build cluster-inspect -- --help
```

from `packages/zigeffect`, then run from repo root:

```bash
bun run zigeffect:test
bun run zig:test
git diff --check
rg -n "T""BD|TO""DO|FIX""ME|st""ub|place""holder|not imple""mented|unimple""mented|fill ""in|add appro""priate|similar ""to" packages/zigeffect/src packages/zigeffect/test packages/zigeffect/docs docs/superpowers/specs/2026-06-10-zigeffect-full-supervision-trees-design.md docs/superpowers/plans/2026-06-10-zigeffect-full-supervision-trees.md docs/superpowers/reports/2026-06-10-zigeffect-milestone-51-completion.md docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md
```

Expected: all build and Bun commands pass; `rg` exits with code 1 because it finds no matches.

- [x] **Step 5: Commit completion docs**

```bash
git add docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md docs/superpowers/reports/2026-06-10-zigeffect-milestone-51-completion.md
git commit -m "docs(zigeffect): complete full supervision trees"
```

- [x] **Step 6: Final status**

Run:

```bash
git status --short --branch
git log --oneline -8
```

Expected: branch is clean and recent commits show the M51 spec, plan, implementation commits, and completion report.
