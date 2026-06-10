# zigeffect Cluster Supervision Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add deterministic cluster supervision so recoverable entity and workflow handler failures restart locally, while escalated failures release shard ownership for migration.

**Architecture:** Reuse the existing runtime `Supervisor` and local entity restart policy. Add a cluster supervision module for reports and runner restart state, expose entity supervisor decisions, and add supervised cluster processing methods alongside the current error-returning methods.

**Tech Stack:** Zig, zigeffect cluster runtime, local entity runtime, runtime supervisor, in-memory runner/message/journal stores, Bun-driven verification commands.

---

Date: 2026-06-10

Milestone: 39 - Cluster Supervision

Spec: `docs/superpowers/specs/2026-06-10-zigeffect-cluster-supervision-design.md`

## Files

Create:

- `packages/zigeffect/src/cluster/supervision.zig`
- `packages/zigeffect/test/cluster_supervision_test.zig`

Modify:

- `packages/zigeffect/src/runtime/supervisor.zig`
- `packages/zigeffect/src/cluster/entity.zig`
- `packages/zigeffect/src/cluster/runtime.zig`
- `packages/zigeffect/src/cluster/local_cluster.zig`
- `packages/zigeffect/src/cluster/root.zig`
- `packages/zigeffect/src/zigeffect.zig`
- `packages/zigeffect/test/all_test.zig`
- `packages/zigeffect/docs/architecture.md`
- `docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md`

## Task 1: Public Supervision Surface

- [ ] **Step 1: Write failing export and runner policy tests**

Create `packages/zigeffect/test/cluster_supervision_test.zig` with:

```zig
const std = @import("std");
const fx = @import("zigeffect");

test "cluster supervision public exports are available" {
    try std.testing.expect(@hasDecl(fx.cluster, "supervision"));
    try std.testing.expect(@hasDecl(fx.cluster, "ClusterSupervisionPolicy"));
    try std.testing.expect(@hasDecl(fx.cluster, "ClusterRunnerRestartPolicy"));
    try std.testing.expect(@hasDecl(fx.cluster, "ClusterRunnerRestartState"));
    try std.testing.expect(@hasDecl(fx.cluster, "ClusterRunnerRestartDecision"));
    try std.testing.expect(@hasDecl(fx.cluster, "ClusterSupervisionReport"));
    try std.testing.expect(@hasDecl(fx, "ClusterSupervisionReport"));
}

test "supervisor child kinds cover runner shard entity and workflow worker" {
    try std.testing.expectEqual(fx.SupervisorChildKind.runner, fx.SupervisorChildKind.runner);
    try std.testing.expectEqual(fx.SupervisorChildKind.shard, fx.SupervisorChildKind.shard);
    try std.testing.expectEqual(fx.SupervisorChildKind.entity, fx.SupervisorChildKind.entity);
    try std.testing.expectEqual(fx.SupervisorChildKind.workflow_worker, fx.SupervisorChildKind.workflow_worker);
}

test "cluster runner restart state escalates after intensity budget" {
    var state = fx.ClusterRunnerRestartState.init(std.testing.allocator, .{
        .max_restarts = 2,
        .within_ms = 1_000,
    });
    defer state.deinit();

    const first = try state.recordFailure(1_000);
    try std.testing.expect(first.restart_allowed);
    try std.testing.expect(!first.escalated);

    const second = try state.recordFailure(1_100);
    try std.testing.expect(second.restart_allowed);
    try std.testing.expect(!second.escalated);

    const third = try state.recordFailure(1_200);
    try std.testing.expect(!third.restart_allowed);
    try std.testing.expect(third.escalated);

    const fourth = try state.recordFailure(2_300);
    try std.testing.expect(fourth.restart_allowed);
    try std.testing.expect(!fourth.escalated);
}
```

Import the new test in `packages/zigeffect/test/all_test.zig`:

```zig
comptime {
    _ = @import("cluster_supervision_test.zig");
}
```

- [ ] **Step 2: Verify red**

Run:

```bash
zig build test-raw --summary all
```

Expected: failure because `cluster.supervision`, runner/shard child kinds, and
cluster supervision types are absent.

- [ ] **Step 3: Implement public surface**

Add `packages/zigeffect/src/cluster/supervision.zig`:

```zig
const std = @import("std");
const routing = @import("routing.zig");

pub const Allocator = std.mem.Allocator;
pub const ShardId = routing.ShardId;

pub const ClusterSupervisionPolicy = struct {
    release_shard_on_escalation: bool = true,
    workflow_entity_type_name: []const u8 = "workflow.execution",
};

pub const ClusterRunnerRestartPolicy = struct {
    max_restarts: usize = 3,
    within_ms: u64 = 60_000,
};

pub const ClusterRunnerRestartDecision = struct {
    restart_allowed: bool = false,
    escalated: bool = false,
    restart_count: usize = 0,
};

pub const ClusterRunnerRestartState = struct {
    allocator: Allocator,
    policy: ClusterRunnerRestartPolicy,
    failures: std.ArrayList(u64) = .empty,

    pub fn init(allocator: Allocator, policy: ClusterRunnerRestartPolicy) ClusterRunnerRestartState {
        return .{ .allocator = allocator, .policy = policy };
    }

    pub fn deinit(self: *ClusterRunnerRestartState) void {
        self.failures.deinit(self.allocator);
    }

    pub fn recordFailure(self: *ClusterRunnerRestartState, now_ms: u64) Allocator.Error!ClusterRunnerRestartDecision {
        self.prune(now_ms);
        if (self.failures.items.len >= self.policy.max_restarts) {
            return .{
                .restart_allowed = false,
                .escalated = true,
                .restart_count = self.failures.items.len,
            };
        }
        try self.failures.append(self.allocator, now_ms);
        return .{
            .restart_allowed = true,
            .restart_count = self.failures.items.len,
        };
    }

    fn prune(self: *ClusterRunnerRestartState, now_ms: u64) void {
        const window_start = now_ms -| self.policy.within_ms;
        while (self.failures.items.len > 0 and self.failures.items[0] < window_start) {
            _ = self.failures.orderedRemove(0);
        }
    }
};

pub const ClusterSupervisionReport = struct {
    scanned: usize = 0,
    claimed: usize = 0,
    dispatched: usize = 0,
    replied: usize = 0,
    acked: usize = 0,
    failed: usize = 0,
    skipped: usize = 0,
    entity_failures: usize = 0,
    entity_restarts: usize = 0,
    entity_escalations: usize = 0,
    workflow_worker_failures: usize = 0,
    workflow_worker_restarts: usize = 0,
    shard_releases: usize = 0,
    runner_restarts: usize = 0,
    runner_escalations: usize = 0,

    pub fn add(self: *ClusterSupervisionReport, other: ClusterSupervisionReport) void {
        self.scanned += other.scanned;
        self.claimed += other.claimed;
        self.dispatched += other.dispatched;
        self.replied += other.replied;
        self.acked += other.acked;
        self.failed += other.failed;
        self.skipped += other.skipped;
        self.entity_failures += other.entity_failures;
        self.entity_restarts += other.entity_restarts;
        self.entity_escalations += other.entity_escalations;
        self.workflow_worker_failures += other.workflow_worker_failures;
        self.workflow_worker_restarts += other.workflow_worker_restarts;
        self.shard_releases += other.shard_releases;
        self.runner_restarts += other.runner_restarts;
        self.runner_escalations += other.runner_escalations;
    }
};
```

Extend `SupervisorChildKind` in `packages/zigeffect/src/runtime/supervisor.zig`:

```zig
pub const SupervisorChildKind = enum { fiber, workflow_worker, queue_worker, entity, runner, shard };
```

Export the module and types in `cluster/root.zig` and `zigeffect.zig`.

- [ ] **Step 4: Verify green**

Run:

```bash
bun run zigeffect:test
zig fmt --check packages/zigeffect/src/cluster/supervision.zig packages/zigeffect/src/runtime/supervisor.zig packages/zigeffect/src/cluster/root.zig packages/zigeffect/src/zigeffect.zig packages/zigeffect/test/cluster_supervision_test.zig packages/zigeffect/test/all_test.zig
```

- [ ] **Step 5: Commit**

```bash
git add packages/zigeffect/src/cluster/supervision.zig packages/zigeffect/src/runtime/supervisor.zig packages/zigeffect/src/cluster/root.zig packages/zigeffect/src/zigeffect.zig packages/zigeffect/test/cluster_supervision_test.zig packages/zigeffect/test/all_test.zig
git commit -m "feat(zigeffect): add cluster supervision surface"
```

## Task 2: Entity Supervisor Decision Surface

- [ ] **Step 1: Write failing entity decision test**

Append to `cluster_supervision_test.zig`:

```zig
test "entity runtime exposes last supervisor decision after handler failure" {
    var runtime = fx.LocalEntityRuntime.init(std.testing.allocator, .{
        .restart_intensity = .{ .max_restarts = 2, .within_ms = 1_000 },
    });
    defer runtime.deinit();

    const address = fx.entityAddress("counter", "decision");
    _ = try runtime.registerEntity(.{ .address = address, .name = "counter-decision" }, 1_000);

    const envelope = try fx.cloneEntityEnvelope(std.testing.allocator, .{
        .id = 1,
        .sequence = 1,
        .kind = .tell,
        .address = address,
        .payload_type_name = "text",
        .payload = "boom",
    });

    const Handler = struct {
        pub fn handle(_: *fx.EntityScope, _: fx.EntityEnvelope) !fx.EntityHandlerResult {
            return error.Boom;
        }
    };

    try std.testing.expectError(error.Boom, runtime.processEnvelope(envelope, Handler, 1_100));
    const decision = (try runtime.lastSupervisorDecision(address)).?;
    try std.testing.expectEqual(@as(usize, 1), decision.restarted_children);
    try std.testing.expect(!decision.escalated);
}
```

- [ ] **Step 2: Verify red**

Run:

```bash
zig build test-raw --summary all
```

Expected: failure because `lastSupervisorDecision` is absent.

- [ ] **Step 3: Store and expose supervisor decisions**

In `cluster/entity.zig`, add a field to `EntityInstance`:

```zig
last_supervisor_decision: ?SupervisorDecision = null,
```

Add a public method to `LocalEntityRuntime`:

```zig
pub fn lastSupervisorDecision(self: *const LocalEntityRuntime, address: EntityAddress) EntityRuntimeError!?SupervisorDecision {
    const index = self.findEntityIndex(address) orelse return error.EntityNotFound;
    return self.entities.items[index].last_supervisor_decision;
}
```

In `handleEntityFailure`, set the field immediately after `reportChildExit`:

```zig
instance.last_supervisor_decision = decision;
```

Also clear it on successful handler processing before returning a success
result:

```zig
instance.last_supervisor_decision = null;
```

- [ ] **Step 4: Verify green**

Run:

```bash
bun run zigeffect:test
zig fmt --check packages/zigeffect/src/cluster/entity.zig packages/zigeffect/test/cluster_supervision_test.zig
```

- [ ] **Step 5: Commit**

```bash
git add packages/zigeffect/src/cluster/entity.zig packages/zigeffect/test/cluster_supervision_test.zig
git commit -m "feat(zigeffect): expose entity supervisor decisions"
```

## Task 3: Supervised Runtime Local Restarts

- [ ] **Step 1: Write failing supervised restart test**

Append to `cluster_supervision_test.zig`:

```zig
test "supervised cluster processing records local entity restart and keeps shard" {
    var runner_storage_state = fx.InMemoryRunnerStorage.init(std.testing.allocator);
    defer runner_storage_state.deinit();
    const runner_storage = runner_storage_state.asRunnerStorage();
    const owner = fx.runnerAddress("machine-supervision", "runner-a");
    var lease_manager = try fx.LocalShardLeaseManager.init(
        std.testing.allocator,
        runner_storage,
        owner,
        .{ .ttl_ms = 1_000, .refresh_interval_ms = 250 },
    );
    defer lease_manager.deinit();

    var message_storage_state = fx.InMemoryMessageStorage.init(std.testing.allocator);
    defer message_storage_state.deinit();
    const message_storage = message_storage_state.asMessageStorage();

    var runtime = try fx.ClusterRuntime.init(
        std.testing.allocator,
        message_storage,
        &lease_manager,
        .{
            .shard_count = 8,
            .entity_runtime_options = .{ .restart_intensity = .{ .max_restarts = 2, .within_ms = 1_000 } },
        },
    );
    defer runtime.deinit();

    const address = try addressForShard(0, 8);
    _ = try runtime.acquireShard(0, 1_000);
    const ref = try runtime.registerEntity(.{ .address = address, .name = "supervised-counter" }, 1_000);
    var submitted = try ref.tell("text", "boom", "supervised-failure");
    defer submitted.deinit(std.testing.allocator);

    const Handler = struct {
        pub fn handle(_: *fx.EntityScope, _: fx.EntityEnvelope) !fx.EntityHandlerResult {
            return error.Boom;
        }
    };

    const report = try runtime.processShardSupervised(0, Handler, 1_100);
    try std.testing.expectEqual(@as(usize, 1), report.failed);
    try std.testing.expectEqual(@as(usize, 1), report.entity_failures);
    try std.testing.expectEqual(@as(usize, 1), report.entity_restarts);
    try std.testing.expectEqual(@as(usize, 0), report.entity_escalations);
    try std.testing.expectEqual(@as(usize, 0), report.shard_releases);
    try std.testing.expect(runtime.ownsShard(0));
    try std.testing.expectEqual(fx.EntityStatus.running, try runtime.local_runtime.status(address));

    var retryable = (try message_storage.unprocessedById(submitted.envelope.id, std.testing.allocator)).?;
    defer retryable.deinit(std.testing.allocator);
    try std.testing.expectEqual(fx.MessageDeliveryStatus.claimed, retryable.status);
}
```

Add helper:

```zig
fn addressForShard(shard_id: fx.ShardId, shard_count: fx.ShardCount) !fx.EntityAddress {
    var id: u64 = 1;
    while (id < 100_000) : (id += 1) {
        var key_buf: [32]u8 = undefined;
        const key = std.fmt.bufPrint(&key_buf, "supervised-{d}", .{id}) catch unreachable;
        const address = fx.entityAddress("supervised", key);
        if (try fx.shardIdForAddress(address, shard_count) == shard_id) return address;
    }
    return error.EntityShardNotFound;
}
```

- [ ] **Step 2: Verify red**

Run:

```bash
zig build test-raw --summary all
```

Expected: failure because `processShardSupervised` is absent.

- [ ] **Step 3: Implement supervised processing for local restarts**

In `cluster/runtime.zig`, import supervision:

```zig
const supervision = @import("supervision.zig");
```

Add aliases and options:

```zig
pub const ClusterSupervisionPolicy = supervision.ClusterSupervisionPolicy;
pub const ClusterSupervisionReport = supervision.ClusterSupervisionReport;

pub const ClusterRuntimeOptions = struct {
    shard_count: ShardCount,
    entity_runtime_options: LocalEntityRuntimeOptions = .{},
    supervision_policy: ClusterSupervisionPolicy = .{},
};
```

Store the policy on `ClusterRuntime`:

```zig
supervision_policy: ClusterSupervisionPolicy = .{},
```

Initialize it from options.

Add `processShardSupervised` and `processOwnedShardsSupervised`. The supervised
method should copy the success path from `processShard`, but replace the handler
failure branch with:

```zig
const entity_envelope = try messageToEntityEnvelope(self.allocator, claimed);
var result = self.local_runtime.processEnvelope(entity_envelope, handler, now_ms) catch |err| {
    _ = err;
    report.failed += 1;
    report.entity_failures += 1;
    const decision = (try self.local_runtime.lastSupervisorDecision(record.envelope.address)) orelse return err;
    if (decision.restarted_children > 0) {
        report.entity_restarts += 1;
    }
    if (decision.escalated) {
        report.entity_escalations += 1;
    }
    continue;
};
```

Keep reply storage and ack logic identical to `processShard` after successful
handler processing.

- [ ] **Step 4: Verify green**

Run:

```bash
bun run zigeffect:test
zig fmt --check packages/zigeffect/src/cluster/runtime.zig packages/zigeffect/test/cluster_supervision_test.zig
```

- [ ] **Step 5: Commit**

```bash
git add packages/zigeffect/src/cluster/runtime.zig packages/zigeffect/test/cluster_supervision_test.zig
git commit -m "feat(zigeffect): supervise cluster entity restarts"
```

## Task 4: Escalation Releases Shards And Allows Migration

- [ ] **Step 1: Write failing escalation and migration test**

Append to `cluster_supervision_test.zig`:

```zig
test "supervised entity escalation releases shard for another runner" {
    var runner_storage_state = fx.InMemoryRunnerStorage.init(std.testing.allocator);
    defer runner_storage_state.deinit();
    const runner_storage = runner_storage_state.asRunnerStorage();
    var message_storage_state = fx.InMemoryMessageStorage.init(std.testing.allocator);
    defer message_storage_state.deinit();
    const message_storage = message_storage_state.asMessageStorage();

    var lease_manager_a = try fx.LocalShardLeaseManager.init(
        std.testing.allocator,
        runner_storage,
        fx.runnerAddress("machine-supervision", "runner-a"),
        .{ .ttl_ms = 1_000, .refresh_interval_ms = 250 },
    );
    defer lease_manager_a.deinit();
    var runtime_a = try fx.ClusterRuntime.init(
        std.testing.allocator,
        message_storage,
        &lease_manager_a,
        .{
            .shard_count = 8,
            .entity_runtime_options = .{ .restart_intensity = .{ .max_restarts = 0, .within_ms = 1_000 } },
        },
    );
    defer runtime_a.deinit();

    const address = try addressForShard(0, 8);
    _ = try runtime_a.acquireShard(0, 1_000);
    const ref_a = try runtime_a.registerEntity(.{ .address = address, .name = "migrating-counter" }, 1_000);
    var submitted = try ref_a.tell("text", "finish", "migrate-after-escalation");
    defer submitted.deinit(std.testing.allocator);

    const FailingHandler = struct {
        pub fn handle(_: *fx.EntityScope, _: fx.EntityEnvelope) !fx.EntityHandlerResult {
            return error.Boom;
        }
    };

    const failed = try runtime_a.processShardSupervised(0, FailingHandler, 1_100);
    try std.testing.expectEqual(@as(usize, 1), failed.entity_escalations);
    try std.testing.expectEqual(@as(usize, 1), failed.shard_releases);
    try std.testing.expect(!runtime_a.ownsShard(0));
    try std.testing.expect((try runner_storage.lease(0)) == null);

    var lease_manager_b = try fx.LocalShardLeaseManager.init(
        std.testing.allocator,
        runner_storage,
        fx.runnerAddress("machine-supervision", "runner-b"),
        .{ .ttl_ms = 1_000, .refresh_interval_ms = 250 },
    );
    defer lease_manager_b.deinit();
    var runtime_b = try fx.ClusterRuntime.init(
        std.testing.allocator,
        message_storage,
        &lease_manager_b,
        .{ .shard_count = 8 },
    );
    defer runtime_b.deinit();

    _ = try runtime_b.acquireShard(0, 1_200);
    _ = try runtime_b.registerEntity(.{ .address = address, .name = "migrating-counter" }, 1_200);

    const SuccessHandler = struct {
        pub fn handle(_: *fx.EntityScope, _: fx.EntityEnvelope) !fx.EntityHandlerResult {
            return .noreply;
        }
    };

    const recovered = try runtime_b.processShardSupervised(0, SuccessHandler, 1_300);
    try std.testing.expectEqual(@as(usize, 1), recovered.acked);
    try std.testing.expect((try message_storage.unprocessedById(submitted.envelope.id, std.testing.allocator)) == null);
}
```

- [ ] **Step 2: Verify red**

Run:

```bash
zig build test-raw --summary all
```

Expected: failure because escalation is reported but the shard is still owned,
or because the released-shard count is absent.

- [ ] **Step 3: Release shard on escalation**

In `processShardSupervised`, extend the failure branch:

```zig
if (decision.escalated) {
    report.entity_escalations += 1;
    if (self.supervision_policy.release_shard_on_escalation) {
        try self.releaseShard(shard_id, now_ms);
        report.shard_releases += 1;
        return report;
    }
}
```

Make sure this branch does not acknowledge the claimed message.

- [ ] **Step 4: Verify green**

Run:

```bash
bun run zigeffect:test
zig fmt --check packages/zigeffect/src/cluster/runtime.zig packages/zigeffect/test/cluster_supervision_test.zig
```

- [ ] **Step 5: Commit**

```bash
git add packages/zigeffect/src/cluster/runtime.zig packages/zigeffect/test/cluster_supervision_test.zig
git commit -m "feat(zigeffect): release shards on supervised escalation"
```

## Task 5: Workflow Worker And Runner Supervision Aggregation

- [ ] **Step 1: Write failing workflow worker and runner tick tests**

Append to `cluster_supervision_test.zig`:

```zig
test "supervised workflow entity failure is reported as workflow worker restart" {
    var runner_storage_state = fx.InMemoryRunnerStorage.init(std.testing.allocator);
    defer runner_storage_state.deinit();
    var message_storage_state = fx.InMemoryMessageStorage.init(std.testing.allocator);
    defer message_storage_state.deinit();
    const message_storage = message_storage_state.asMessageStorage();
    var journal_state = fx.workflow.InMemoryJournalStore.init(std.testing.allocator);
    defer journal_state.deinit();
    const journal_store = journal_state.asJournalStore();

    var runner = try fx.LocalClusterRunner.init(std.testing.allocator, .{
        .runner = fx.runnerAddress("machine-supervision", "runner-workflow"),
        .runner_storage = runner_storage_state.asRunnerStorage(),
        .message_storage = message_storage,
        .shard_count = 8,
        .runner_index = 0,
        .runner_count = 1,
        .lease_options = .{ .ttl_ms = 1_000, .refresh_interval_ms = 250 },
        .entity_runtime_options = .{ .restart_intensity = .{ .max_restarts = 2, .within_ms = 1_000 } },
    });
    defer runner.deinit();
    _ = try runner.runtime.acquireShard(0, 1_000);

    const workflow_id = fx.workflow.workflowId("approval");
    const execution_id = try executionIdForWorkflowShard(0, 8);
    var registry = fx.ClusterWorkflowEntityRegistry.init(std.testing.allocator);
    defer registry.deinit();
    _ = try registry.registerExecution(&runner, journal_store, workflow_id, execution_id, 1_000);

    var submitted = try message_storage.submit(.{
        .shard_id = 0,
        .envelope = .{
            .kind = .request,
            .address = fx.clusterWorkflowExecutionAddress(execution_id),
            .idempotency_key = "bad-workflow-command",
            .payload_type_name = fx.cluster_workflow_command_payload_type,
            .payload = "{bad-json",
            .redacted_detail = "bad-workflow-command",
        },
    });
    defer submitted.deinit(std.testing.allocator);

    const report = try runner.runtime.processShardSupervised(0, fx.ClusterWorkflowEntityHandler, 1_100);
    try std.testing.expectEqual(@as(usize, 1), report.workflow_worker_failures);
    try std.testing.expectEqual(@as(usize, 1), report.workflow_worker_restarts);
    try std.testing.expectEqual(@as(usize, 1), report.entity_restarts);
}

test "local cluster runner supervised tick aggregates supervision report" {
    var runner_storage_state = fx.InMemoryRunnerStorage.init(std.testing.allocator);
    defer runner_storage_state.deinit();
    var message_storage_state = fx.InMemoryMessageStorage.init(std.testing.allocator);
    defer message_storage_state.deinit();

    var runner = try fx.LocalClusterRunner.init(std.testing.allocator, .{
        .runner = fx.runnerAddress("machine-supervision", "runner-tick"),
        .runner_storage = runner_storage_state.asRunnerStorage(),
        .message_storage = message_storage_state.asMessageStorage(),
        .shard_count = 8,
        .runner_index = 0,
        .runner_count = 1,
        .lease_options = .{ .ttl_ms = 1_000, .refresh_interval_ms = 250 },
        .entity_runtime_options = .{ .restart_intensity = .{ .max_restarts = 2, .within_ms = 1_000 } },
        .runner_restart_policy = .{ .max_restarts = 2, .within_ms = 1_000 },
    });
    defer runner.deinit();
    _ = try runner.runtime.acquireShard(0, 1_000);

    const address = try addressForShard(0, 8);
    const ref = try runner.registerEntity(.{ .address = address, .name = "tick-counter" }, 1_000);
    var submitted = try ref.tell("text", "boom", "tick-failure");
    defer submitted.deinit(std.testing.allocator);

    const Handler = struct {
        pub fn handle(_: *fx.EntityScope, _: fx.EntityEnvelope) !fx.EntityHandlerResult {
            return error.Boom;
        }
    };

    const report = try runner.tickSupervised(Handler, 1_100);
    try std.testing.expectEqual(@as(usize, 1), report.entity_failures);
    try std.testing.expectEqual(@as(usize, 1), report.entity_restarts);
    try std.testing.expectEqual(@as(usize, 0), report.runner_escalations);
}
```

Add helper:

```zig
fn executionIdForWorkflowShard(shard_id: fx.ShardId, shard_count: fx.ShardCount) !fx.workflow.ExecutionId {
    var id: fx.workflow.ExecutionId = 1;
    while (id < 100_000) : (id += 1) {
        const address = fx.clusterWorkflowExecutionAddress(id);
        if (try fx.shardIdForAddress(address, shard_count) == shard_id) return id;
    }
    return error.ExecutionShardNotFound;
}
```

- [ ] **Step 2: Verify red**

Run:

```bash
zig build test-raw --summary all
```

Expected: failure because workflow worker counters and `tickSupervised` are
absent.

- [ ] **Step 3: Classify workflow workers and aggregate runner tick reports**

In `processShardSupervised`, when a handler failure has a decision:

```zig
const is_workflow_worker = std.mem.eql(
    u8,
    record.envelope.address.entity_type.name,
    self.supervision_policy.workflow_entity_type_name,
);
if (is_workflow_worker) {
    report.workflow_worker_failures += 1;
}
if (decision.restarted_children > 0) {
    report.entity_restarts += 1;
    if (is_workflow_worker) report.workflow_worker_restarts += 1;
}
```

In `cluster/local_cluster.zig`, import supervision and extend runner options:

```zig
const supervision = @import("supervision.zig");

pub const ClusterRunnerRestartPolicy = supervision.ClusterRunnerRestartPolicy;
pub const ClusterRunnerRestartState = supervision.ClusterRunnerRestartState;
pub const ClusterSupervisionReport = supervision.ClusterSupervisionReport;

pub const LocalClusterRunnerOptions = struct {
    ...
    runner_restart_policy: ClusterRunnerRestartPolicy = .{},
};
```

Add state to `LocalClusterRunner`:

```zig
runner_restart_state: ClusterRunnerRestartState,
```

Initialize it:

```zig
.runner_restart_state = ClusterRunnerRestartState.init(allocator, options.runner_restart_policy),
```

Deinitialize it:

```zig
self.runner_restart_state.deinit();
```

Add `tickSupervised`:

```zig
pub fn tickSupervised(self: *LocalClusterRunner, handler: anytype, now_ms: u64) !ClusterSupervisionReport {
    _ = try self.lease_manager.refreshOwnedLeases(now_ms);
    _ = try self.runtime.loadOwnedShards();
    return self.runtime.processOwnedShardsSupervised(handler, now_ms);
}
```

Keep the existing `tick` method unchanged.

- [ ] **Step 4: Verify green**

Run:

```bash
bun run zigeffect:test
zig fmt --check packages/zigeffect/src/cluster/runtime.zig packages/zigeffect/src/cluster/local_cluster.zig packages/zigeffect/test/cluster_supervision_test.zig
```

- [ ] **Step 5: Commit**

```bash
git add packages/zigeffect/src/cluster/runtime.zig packages/zigeffect/src/cluster/local_cluster.zig packages/zigeffect/test/cluster_supervision_test.zig
git commit -m "feat(zigeffect): aggregate workflow and runner supervision"
```

## Task 6: Docs, Roadmap, And Full Gate

- [ ] **Step 1: Update architecture docs**

Add `supervision.zig` to the `src/cluster/` module list in
`packages/zigeffect/docs/architecture.md` with:

```md
- `supervision.zig`: cluster supervision policies, reports, runner restart
  intensity state, workflow-worker classification, and shard-release
  escalation vocabulary.
```

- [ ] **Step 2: Mark M39 complete in roadmap and plan**

In `docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md`,
mark every M39 deliverable and acceptance checkbox complete.

In this plan, mark completed task steps with `- [x]` as each task finishes.

- [ ] **Step 3: Run full verification gate**

Run:

```bash
bun run zigeffect:test
(cd packages/zigeffect && zig build examples)
(cd packages/zigeffect && zig build cluster-runner -- --help)
bun run zig:test
zig fmt --check packages/zigeffect/src/cluster/supervision.zig packages/zigeffect/src/runtime/supervisor.zig packages/zigeffect/src/cluster/entity.zig packages/zigeffect/src/cluster/runtime.zig packages/zigeffect/src/cluster/local_cluster.zig packages/zigeffect/src/cluster/root.zig packages/zigeffect/src/zigeffect.zig packages/zigeffect/test/cluster_supervision_test.zig packages/zigeffect/test/all_test.zig
git diff --check
rg "TO""DO|FIX""ME|st""ub|place""holder|not imple""mented|unimple""mented" packages/zigeffect/src packages/zigeffect/test packages/zigeffect/docs docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md docs/superpowers/specs/2026-06-10-zigeffect-cluster-supervision-design.md docs/superpowers/plans/2026-06-10-zigeffect-cluster-supervision.md
```

Expected: all tests pass, examples build, CLI help prints, formatting passes,
whitespace check passes, and marker scan finds no matches.

- [ ] **Step 4: Commit docs**

```bash
git add packages/zigeffect/docs/architecture.md docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md docs/superpowers/plans/2026-06-10-zigeffect-cluster-supervision.md
git commit -m "docs(zigeffect): mark cluster supervision complete"
```

## Self-Review

- Spec coverage: public supervision exports, local entity restarts, workflow
  worker classification, shard release on escalation, migration through durable
  messages, runner restart state, docs, and roadmap all map to tasks.
- Marker scan: marker words are split in the full gate command.
- Type consistency: `ClusterSupervisionPolicy`, `ClusterSupervisionReport`,
  `ClusterRunnerRestartPolicy`, `ClusterRunnerRestartState`,
  `lastSupervisorDecision`, `processShardSupervised`, and `tickSupervised` are
  named consistently across tasks.
