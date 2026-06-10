# zigeffect Cluster Observability And Causal Queries Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add cluster causal events, query reports, DOT rendering, metrics collection, trace propagation, and failure reports for runner/shard/message/entity failures.

**Architecture:** Extend the existing causal taxonomy and message envelope, then add a focused `cluster/observability.zig` module. Runtime hooks record causal events, while report/DOT/metrics functions read durable stores and causal snapshots without mutating workflow state.

**Tech Stack:** Zig, zigeffect cluster runtime, causal store, metrics service, tracing ids, in-memory and file-backed message storage, Bun-driven verification commands.

---

Date: 2026-06-10

Milestone: 40 - Cluster Observability And Causal Queries

Spec: `docs/superpowers/specs/2026-06-10-zigeffect-cluster-observability-design.md`

## Files

Create:

- `packages/zigeffect/src/cluster/observability.zig`
- `packages/zigeffect/test/cluster_observability_test.zig`

Modify:

- `packages/zigeffect/src/services/causal.zig`
- `packages/zigeffect/src/cluster/envelope.zig`
- `packages/zigeffect/src/cluster/message_storage.zig`
- `packages/zigeffect/src/cluster/runtime.zig`
- `packages/zigeffect/src/cluster/local_cluster.zig`
- `packages/zigeffect/src/cluster/root.zig`
- `packages/zigeffect/src/zigeffect.zig`
- `packages/zigeffect/test/all_test.zig`
- `packages/zigeffect/docs/architecture.md`
- `docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md`

## Task 1: Causal Taxonomy And Observability Surface

- [x] **Step 1: Write failing public taxonomy tests**

Create `packages/zigeffect/test/cluster_observability_test.zig`:

```zig
const std = @import("std");
const fx = @import("zigeffect");

test "cluster observability public exports are available" {
    try std.testing.expect(@hasDecl(fx.cluster, "observability"));
    try std.testing.expect(@hasDecl(fx.cluster, "ClusterTraceContext"));
    try std.testing.expect(@hasDecl(fx.cluster, "ClusterCausalRecorder"));
    try std.testing.expect(@hasDecl(fx.cluster, "ClusterCausalReport"));
    try std.testing.expect(@hasDecl(fx.cluster, "ClusterQueryReport"));
    try std.testing.expect(@hasDecl(fx.cluster, "ClusterMetricsSnapshot"));
    try std.testing.expect(@hasDecl(fx.cluster, "ClusterFailureReport"));
    try std.testing.expect(@hasDecl(fx.cluster, "formatClusterCausalDot"));
    try std.testing.expect(@hasDecl(fx.cluster, "collectClusterMetrics"));
    try std.testing.expect(@hasDecl(fx.cluster, "recordClusterMetrics"));
    try std.testing.expect(@hasDecl(fx.cluster, "formatClusterFailureReport"));
    try std.testing.expect(@hasDecl(fx, "ClusterFailureReport"));
}

test "causal taxonomy includes cluster runner message entity and trace events" {
    try std.testing.expect(fx.isCausalFindingEvidenceEvent(.cluster_runner_registered));
    try std.testing.expect(fx.isCausalFindingEvidenceEvent(.cluster_runner_heartbeat));
    try std.testing.expect(fx.isCausalFindingEvidenceEvent(.cluster_message_submitted));
    try std.testing.expect(fx.isCausalFindingEvidenceEvent(.cluster_message_claimed));
    try std.testing.expect(fx.isCausalFindingEvidenceEvent(.cluster_message_acked));
    try std.testing.expect(fx.isCausalFindingEvidenceEvent(.cluster_message_replied));
    try std.testing.expect(fx.isCausalFindingEvidenceEvent(.cluster_entity_registered));
    try std.testing.expect(fx.isCausalFindingEvidenceEvent(.cluster_entity_processed));
    try std.testing.expect(fx.isCausalFindingEvidenceEvent(.cluster_entity_failed));
    try std.testing.expect(fx.isCausalFindingEvidenceEvent(.cluster_trace_propagated));
}
```

Import the new test in `packages/zigeffect/test/all_test.zig` near the other
cluster tests.

- [x] **Step 2: Verify red**

Run:

```bash
zig build test-raw --summary all
```

Expected: failure because observability exports and causal event kinds are
absent.

- [x] **Step 3: Implement taxonomy and minimal module**

In `services/causal.zig`, add the new event kinds after existing cluster shard
events:

```zig
cluster_runner_registered,
cluster_runner_heartbeat,
cluster_message_submitted,
cluster_message_claimed,
cluster_message_acked,
cluster_message_replied,
cluster_entity_registered,
cluster_entity_processed,
cluster_entity_failed,
cluster_trace_propagated,
```

Add them to the structural finding evidence branch in `causalEventTaxonomy`.

Create `cluster/observability.zig` with the public value types and empty-count
helpers:

```zig
const std = @import("std");
const causal_mod = @import("../services/causal.zig");
const metrics_mod = @import("../services/metrics.zig");
const envelope = @import("envelope.zig");
const identity = @import("identity.zig");
const message_storage = @import("message_storage.zig");
const runner = @import("runner.zig");
const runner_storage = @import("runner_storage.zig");
const routing = @import("routing.zig");

pub const Allocator = std.mem.Allocator;
pub const CausalStore = causal_mod.CausalStore;
pub const CausalEvent = causal_mod.CausalEvent;
pub const CausalEventKind = causal_mod.CausalEventKind;
pub const Metrics = metrics_mod.Metrics;
pub const EntityAddress = identity.EntityAddress;
pub const MessageId = message_storage.MessageId;
pub const MessageAttempt = envelope.MessageAttempt;
pub const RunnerAddress = runner.RunnerAddress;
pub const RunnerStorage = runner_storage.RunnerStorage;
pub const MessageStorage = message_storage.MessageStorage;
pub const ShardCount = routing.ShardCount;
pub const ShardId = routing.ShardId;

pub const ClusterTraceContext = struct {
    trace_id: u64,
    span_id: ?u64 = null,
};

pub const ClusterCausalRecorder = struct {
    store: *CausalStore,
    run_id: ?u64 = null,
};

pub const ClusterCausalReport = struct {
    cluster_events: usize = 0,
    runner_events: usize = 0,
    shard_events: usize = 0,
    message_events: usize = 0,
    entity_events: usize = 0,
    failures: usize = 0,
};

pub const ClusterQueryReport = struct {
    leases: usize = 0,
    messages: usize = 0,
    causal: ClusterCausalReport = .{},
};

pub const ClusterMetricsSnapshot = struct {
    active_leases: usize = 0,
    mailbox_lag: usize = 0,
    message_retries: usize = 0,
    migrations: usize = 0,
    failures: usize = 0,
};

pub const ClusterFailureReport = struct {
    runner: RunnerAddress,
    shard_id: ShardId,
    message_id: MessageId,
    attempt: u32,
    address: EntityAddress,
    cause: []const u8,
    redacted_detail: []const u8 = "",
};
```

Add public function declarations with working empty behavior:

```zig
pub fn formatClusterCausalDot(allocator: Allocator, store: *const CausalStore) Allocator.Error![]const u8 {
    _ = store;
    return allocator.dupe(u8, "digraph zigeffect_cluster {\n}\n");
}

pub fn collectClusterMetrics(
    allocator: Allocator,
    runner_store: RunnerStorage,
    message_store: MessageStorage,
    shard_count: ShardCount,
    causal_store: ?*const CausalStore,
) !ClusterMetricsSnapshot {
    _ = allocator;
    _ = runner_store;
    _ = message_store;
    _ = shard_count;
    _ = causal_store;
    return .{};
}

pub fn recordClusterMetrics(metrics: *Metrics, snapshot: ClusterMetricsSnapshot) Allocator.Error!void {
    try metrics.gauge("cluster.leases.active", @intCast(snapshot.active_leases));
    try metrics.gauge("cluster.mailbox.lag", @intCast(snapshot.mailbox_lag));
    try metrics.gauge("cluster.messages.retries", @intCast(snapshot.message_retries));
    try metrics.gauge("cluster.shards.migrations", @intCast(snapshot.migrations));
    try metrics.gauge("cluster.failures", @intCast(snapshot.failures));
}

pub fn formatClusterFailureReport(allocator: Allocator, report: ClusterFailureReport) Allocator.Error![]const u8 {
    return std.fmt.allocPrint(
        allocator,
        "cluster failure runner={d}/{d} shard={d} message={d} attempt={d} entity={s}/{d} cause={s} detail={s}",
        .{
            report.runner.machine_id,
            report.runner.runner_id,
            report.shard_id,
            report.message_id,
            report.attempt,
            report.address.entity_type.name,
            report.address.id,
            report.cause,
            report.redacted_detail,
        },
    );
}
```

Export the module and public names from `cluster/root.zig` and `zigeffect.zig`.

- [x] **Step 4: Verify green**

Run:

```bash
bun run zigeffect:test
zig fmt --check packages/zigeffect/src/services/causal.zig packages/zigeffect/src/cluster/observability.zig packages/zigeffect/src/cluster/root.zig packages/zigeffect/src/zigeffect.zig packages/zigeffect/test/cluster_observability_test.zig packages/zigeffect/test/all_test.zig
```

- [x] **Step 5: Commit**

```bash
git add packages/zigeffect/src/services/causal.zig packages/zigeffect/src/cluster/observability.zig packages/zigeffect/src/cluster/root.zig packages/zigeffect/src/zigeffect.zig packages/zigeffect/test/cluster_observability_test.zig packages/zigeffect/test/all_test.zig
git commit -m "feat(zigeffect): add cluster observability surface"
```

## Task 2: Durable Message Trace Context

- [x] **Step 1: Write failing trace context tests**

Append to `cluster_observability_test.zig`:

```zig
test "message envelope trace context clones and survives json round trip" {
    const address = fx.entityAddress("counter", "traced");
    const envelope = fx.MessageEnvelope{
        .id = 42,
        .kind = .tell,
        .address = address,
        .idempotency_key = "trace-message",
        .trace_id = 700,
        .span_id = 701,
        .payload_type_name = "text",
        .payload = "hello",
    };

    const cloned = try fx.cloneMessageEnvelope(std.testing.allocator, envelope);
    defer fx.deinitMessageEnvelope(std.testing.allocator, cloned);
    try std.testing.expectEqual(@as(?u64, 700), cloned.trace_id);
    try std.testing.expectEqual(@as(?u64, 701), cloned.span_id);

    const record = fx.StoredMessageRecord{
        .shard_id = 3,
        .envelope = envelope,
        .stored_at_ms = 1_000,
        .updated_at_ms = 1_000,
    };
    const json = try fx.formatStoredMessageRecordJson(std.testing.allocator, record);
    defer std.testing.allocator.free(json);

    var parsed = try fx.parseStoredMessageRecordJson(std.testing.allocator, json);
    defer parsed.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(?u64, 700), parsed.envelope.trace_id);
    try std.testing.expectEqual(@as(?u64, 701), parsed.envelope.span_id);
}
```

- [x] **Step 2: Verify red**

Run:

```bash
zig build test-raw --summary all
```

Expected: failure because `MessageEnvelope.trace_id` and `span_id` are absent.

- [x] **Step 3: Add trace context fields**

In `cluster/envelope.zig`, add fields to `MessageEnvelope`:

```zig
trace_id: ?u64 = null,
span_id: ?u64 = null,
```

In `cloneMessageEnvelope`, scalar assignment already copies these fields because
the function starts from `var owned = envelope`; verify no extra work is needed.

In `cluster/message_storage.zig`, extend the JSON struct:

```zig
trace_id: ?u64 = null,
span_id: ?u64 = null,
```

Emit fields in `formatStoredMessageRecordJson`:

```zig
try output.appendSlice(allocator, ",\"trace_id\":");
try appendOptionalJsonU64(&output, allocator, record.envelope.trace_id);
try output.appendSlice(allocator, ",\"span_id\":");
try appendOptionalJsonU64(&output, allocator, record.envelope.span_id);
```

Parse fields in `parseStoredMessageRecordJson` into the returned envelope.

- [x] **Step 4: Verify green**

Run:

```bash
bun run zigeffect:test
zig fmt --check packages/zigeffect/src/cluster/envelope.zig packages/zigeffect/src/cluster/message_storage.zig packages/zigeffect/test/cluster_observability_test.zig
```

- [x] **Step 5: Commit**

```bash
git add packages/zigeffect/src/cluster/envelope.zig packages/zigeffect/src/cluster/message_storage.zig packages/zigeffect/test/cluster_observability_test.zig
git commit -m "feat(zigeffect): persist cluster message trace context"
```

## Task 3: Causal Recorder And Runtime Hooks

- [x] **Step 1: Write failing runtime causal recording test**

Append to `cluster_observability_test.zig`:

```zig
test "cluster runtime records message entity and failure causal events" {
    var causal = fx.CausalStore.init(std.testing.allocator);
    defer causal.deinit();
    const run_id = causal.nextRunId();

    var runner_storage_state = fx.InMemoryRunnerStorage.init(std.testing.allocator);
    defer runner_storage_state.deinit();
    const runner_storage = runner_storage_state.asRunnerStorage();
    var message_storage_state = fx.InMemoryMessageStorage.init(std.testing.allocator);
    defer message_storage_state.deinit();
    const message_storage = message_storage_state.asMessageStorage();

    var lease_manager = try fx.LocalShardLeaseManager.init(
        std.testing.allocator,
        runner_storage,
        fx.runnerAddress("machine-observe", "runner-a"),
        .{ .ttl_ms = 1_000, .refresh_interval_ms = 250 },
    );
    defer lease_manager.deinit();
    var runtime = try fx.ClusterRuntime.init(
        std.testing.allocator,
        message_storage,
        &lease_manager,
        .{
            .shard_count = 8,
            .entity_runtime_options = .{ .restart_intensity = .{ .max_restarts = 1, .within_ms = 1_000 } },
        },
    );
    defer runtime.deinit();
    runtime.attachCausalStore(&causal, run_id);

    const address = try observedAddressForShard(0, 8);
    _ = try runtime.acquireShard(0, 1_000);
    const ref = try runtime.registerEntity(.{ .address = address, .name = "observed-counter" }, 1_000);
    var submitted = try ref.tellWithTrace("text", "boom", "observed-failure", .{ .trace_id = 11, .span_id = 12 });
    defer submitted.deinit(std.testing.allocator);

    const Handler = struct {
        pub fn handle(_: *fx.EntityScope, _: fx.EntityEnvelope) !fx.EntityHandlerResult {
            return error.Boom;
        }
    };
    _ = try runtime.processShardSupervised(0, Handler, 1_100);

    var snapshot = try causal.snapshot(std.testing.allocator);
    defer snapshot.deinit();
    try expectClusterEvent(snapshot, .cluster_entity_registered);
    try expectClusterEvent(snapshot, .cluster_message_submitted);
    try expectClusterEvent(snapshot, .cluster_trace_propagated);
    try expectClusterEvent(snapshot, .cluster_message_claimed);
    try expectClusterEvent(snapshot, .cluster_entity_failed);
}
```

Add helpers:

```zig
fn expectClusterEvent(snapshot: fx.CausalSnapshot, kind: fx.CausalEventKind) !void {
    for (snapshot.events) |event| {
        if (event.kind == kind) return;
    }
    return error.ExpectedClusterEvent;
}

fn observedAddressForShard(shard_id: fx.ShardId, shard_count: fx.ShardCount) !fx.EntityAddress {
    var id: u64 = 1;
    while (id < 100_000) : (id += 1) {
        var key_buf: [32]u8 = undefined;
        const key = std.fmt.bufPrint(&key_buf, "observed-{d}", .{id}) catch unreachable;
        const address = fx.entityAddress("observed", key);
        if (try fx.shardIdForAddress(address, shard_count) == shard_id) return address;
    }
    return error.EntityShardNotFound;
}
```

- [x] **Step 2: Verify red**

Run:

```bash
zig build test-raw --summary all
```

Expected: failure because runtime causal hooks and traced send APIs are absent.

- [x] **Step 3: Implement recorder and runtime hooks**

In `cluster/observability.zig`, add recorder methods:

```zig
pub fn initRecorder(store: *CausalStore, run_id: ?u64) ClusterCausalRecorder {
    return .{ .store = store, .run_id = run_id };
}

pub fn recordMessage(self: ClusterCausalRecorder, kind: CausalEventKind, shard_id: ShardId, message_id: MessageId, status: []const u8, detail: []const u8, trace: ?ClusterTraceContext) Allocator.Error!void {
    const label = try std.fmt.allocPrint(self.store.allocator, "message-{d}", .{message_id});
    defer self.store.allocator.free(label);
    const redacted_detail = try std.fmt.allocPrint(self.store.allocator, "shard={d} {s}", .{ shard_id, detail });
    defer self.store.allocator.free(redacted_detail);
    _ = try self.store.record(.{
        .kind = kind,
        .run_id = self.run_id,
        .trace_id = if (trace) |value| value.trace_id else null,
        .span_id = if (trace) |value| value.span_id else null,
        .label = label,
        .type_name = "cluster.message",
        .status = status,
        .redacted_detail = redacted_detail,
    });
}
```

Add equivalent `recordEntity` and `recordTracePropagation` helpers.

In `cluster/runtime.zig`:

- add optional recorder field
- add `attachCausalStore`
- record entity registration in `registerEntity`
- record message submission and trace propagation in `submitEntityMessage`
- record claim, reply, ack, and handler failure in `processShardSupervised`

Add `tellWithTrace` and `askWithTrace` to `ClusterEntityRef`. They call a new
private `submitEntityMessageWithTrace` with a `?ClusterTraceContext` parameter.
Existing `tell` and `ask` pass `null`.

In `cluster/local_cluster.zig`, add `attachCausalStore` that calls both
`lease_manager.attachCausalStore` and `runtime.attachCausalStore`.

- [x] **Step 4: Verify green**

Run:

```bash
bun run zigeffect:test
zig fmt --check packages/zigeffect/src/cluster/observability.zig packages/zigeffect/src/cluster/runtime.zig packages/zigeffect/src/cluster/local_cluster.zig packages/zigeffect/test/cluster_observability_test.zig
```

- [x] **Step 5: Commit**

```bash
git add packages/zigeffect/src/cluster/observability.zig packages/zigeffect/src/cluster/runtime.zig packages/zigeffect/src/cluster/local_cluster.zig packages/zigeffect/test/cluster_observability_test.zig
git commit -m "feat(zigeffect): record cluster causal events"
```

## Task 4: Query Reports And Failure Reports

- [x] **Step 1: Write failing report tests**

Append to `cluster_observability_test.zig`:

```zig
test "cluster causal report counts cluster events by domain" {
    var causal = fx.CausalStore.init(std.testing.allocator);
    defer causal.deinit();
    _ = try causal.record(.{ .kind = .cluster_runner_registered, .label = "runner-a" });
    _ = try causal.record(.{ .kind = .cluster_message_submitted, .label = "message-1" });
    _ = try causal.record(.{ .kind = .cluster_entity_failed, .label = "entity-1", .status = "failure" });

    const report = try fx.clusterCausalReport(&causal);
    try std.testing.expectEqual(@as(usize, 3), report.cluster_events);
    try std.testing.expectEqual(@as(usize, 1), report.runner_events);
    try std.testing.expectEqual(@as(usize, 1), report.message_events);
    try std.testing.expectEqual(@as(usize, 1), report.entity_events);
    try std.testing.expectEqual(@as(usize, 1), report.failures);
}

test "cluster failure report identifies runner shard message entity and cause" {
    const report = fx.ClusterFailureReport{
        .runner = fx.runnerAddress("machine-observe", "runner-a"),
        .shard_id = 4,
        .message_id = 99,
        .attempt = 3,
        .address = fx.entityAddress("workflow.execution", "123"),
        .cause = "Boom",
        .redacted_detail = "handler failed",
    };
    const text = try fx.formatClusterFailureReport(std.testing.allocator, report);
    defer std.testing.allocator.free(text);

    try expectContains(text, "runner=");
    try expectContains(text, "shard=4");
    try expectContains(text, "message=99");
    try expectContains(text, "attempt=3");
    try expectContains(text, "workflow.execution");
    try expectContains(text, "cause=Boom");
}
```

Add helper:

```zig
fn expectContains(haystack: []const u8, needle: []const u8) !void {
    try std.testing.expect(std.mem.indexOf(u8, haystack, needle) != null);
}
```

- [x] **Step 2: Verify red**

Run:

```bash
zig build test-raw --summary all
```

Expected: failure because `clusterCausalReport` is absent or returns empty
counts.

- [x] **Step 3: Implement report functions**

In `cluster/observability.zig`, add:

```zig
pub fn clusterCausalReport(store: *const CausalStore) Allocator.Error!ClusterCausalReport {
    _ = store.allocator;
    var report = ClusterCausalReport{};
    for (store.events.items) |event| {
        if (!isClusterEvent(event.kind)) continue;
        report.cluster_events += 1;
        switch (event.kind) {
            .cluster_runner_registered, .cluster_runner_heartbeat => report.runner_events += 1,
            .cluster_shard_lease_acquired,
            .cluster_shard_lease_refreshed,
            .cluster_shard_lease_released,
            .cluster_shard_lease_conflict,
            .cluster_shard_handoff_started,
            .cluster_shard_recovery_started,
            .cluster_shard_recovery_completed,
            => report.shard_events += 1,
            .cluster_message_submitted,
            .cluster_message_claimed,
            .cluster_message_acked,
            .cluster_message_replied,
            => report.message_events += 1,
            .cluster_entity_registered,
            .cluster_entity_processed,
            .cluster_entity_failed,
            => report.entity_events += 1,
            .cluster_trace_propagated => {},
            else => {},
        }
        if (std.mem.eql(u8, event.status, "failure") or event.kind == .cluster_entity_failed) {
            report.failures += 1;
        }
    }
    return report;
}
```

Add `isClusterEvent` covering all cluster kinds. Keep
`formatClusterFailureReport` from Task 1 and adjust wording until the test
passes.

- [x] **Step 4: Verify green**

Run:

```bash
bun run zigeffect:test
zig fmt --check packages/zigeffect/src/cluster/observability.zig packages/zigeffect/test/cluster_observability_test.zig
```

- [x] **Step 5: Commit**

```bash
git add packages/zigeffect/src/cluster/observability.zig packages/zigeffect/test/cluster_observability_test.zig
git commit -m "feat(zigeffect): add cluster causal reports"
```

## Task 5: DOT Rendering And Metrics Collection

- [x] **Step 1: Write failing DOT and metrics tests**

Append to `cluster_observability_test.zig`:

```zig
test "cluster causal dot renders only cluster graph" {
    var causal = fx.CausalStore.init(std.testing.allocator);
    defer causal.deinit();
    const root = try causal.record(.{ .kind = .cluster_runner_registered, .label = "runner-a", .status = "running" });
    _ = try causal.record(.{ .kind = .cluster_message_submitted, .parent_id = root, .label = "message-1", .status = "pending" });
    _ = try causal.record(.{ .kind = .run_started, .label = "non-cluster" });

    const dot = try fx.formatClusterCausalDot(std.testing.allocator, &causal);
    defer std.testing.allocator.free(dot);
    try expectContains(dot, "digraph zigeffect_cluster");
    try expectContains(dot, "cluster_runner_registered");
    try expectContains(dot, "cluster_message_submitted");
    try expectContains(dot, "event_1 -> event_2");
    try std.testing.expect(std.mem.indexOf(u8, dot, "non-cluster") == null);
}

test "cluster metrics collect leases lag retries migrations and failures" {
    var runner_storage_state = fx.InMemoryRunnerStorage.init(std.testing.allocator);
    defer runner_storage_state.deinit();
    const runner_storage = runner_storage_state.asRunnerStorage();
    _ = try runner_storage.acquire(.{
        .shard_id = 0,
        .owner = fx.runnerAddress("machine-observe", "runner-a"),
        .now_ms = 1_000,
        .ttl_ms = 1_000,
    });

    var message_storage_state = fx.InMemoryMessageStorage.init(std.testing.allocator);
    defer message_storage_state.deinit();
    const address = try observedAddressForShard(0, 4);
    var submitted = try message_storage_state.asMessageStorage().submit(.{
        .shard_id = 0,
        .envelope = .{
            .kind = .tell,
            .address = address,
            .idempotency_key = "metric-message",
            .payload_type_name = "text",
            .payload = "work",
        },
    });
    defer submitted.deinit(std.testing.allocator);
    _ = try message_storage_state.asMessageStorage().claim(.{ .shard_id = 0, .message_id = submitted.envelope.id, .now_ms = 1_100 });

    var causal = fx.CausalStore.init(std.testing.allocator);
    defer causal.deinit();
    _ = try causal.record(.{ .kind = .cluster_shard_recovery_completed, .status = "recovered" });
    _ = try causal.record(.{ .kind = .cluster_entity_failed, .status = "failure" });

    const snapshot = try fx.collectClusterMetrics(
        std.testing.allocator,
        runner_storage,
        message_storage_state.asMessageStorage(),
        4,
        &causal,
    );
    try std.testing.expectEqual(@as(usize, 1), snapshot.active_leases);
    try std.testing.expectEqual(@as(usize, 1), snapshot.mailbox_lag);
    try std.testing.expectEqual(@as(usize, 1), snapshot.message_retries);
    try std.testing.expectEqual(@as(usize, 1), snapshot.migrations);
    try std.testing.expectEqual(@as(usize, 1), snapshot.failures);

    var metrics = fx.Metrics.init(std.testing.allocator);
    defer metrics.deinit();
    try fx.recordClusterMetrics(&metrics, snapshot);
    try std.testing.expectEqual(@as(i64, 1), metrics.get("cluster.leases.active"));
    try std.testing.expectEqual(@as(i64, 1), metrics.get("cluster.mailbox.lag"));
    try std.testing.expectEqual(@as(i64, 1), metrics.get("cluster.messages.retries"));
}
```

- [x] **Step 2: Verify red**

Run:

```bash
zig build test-raw --summary all
```

Expected: failure because DOT filtering and metrics collection still return
empty values.

- [x] **Step 3: Implement DOT and metrics**

Implement `formatClusterCausalDot` with deterministic output:

```zig
pub fn formatClusterCausalDot(allocator: Allocator, store: *const CausalStore) Allocator.Error![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);
    try output.appendSlice(allocator, "digraph zigeffect_cluster {\n");
    try output.appendSlice(allocator, "  graph [rankdir=\"LR\", label=\"zigeffect cluster causal graph\"];\n");
    for (store.events.items) |event| {
        if (!isClusterEvent(event.kind)) continue;
        try output.print(
            allocator,
            "  event_{d} [label=\"event {d}\\n{s}\\n{s}\\nstatus={s}\"];\n",
            .{ event.id, event.id, @tagName(event.kind), event.label, event.status },
        );
        if (event.parent_id) |parent_id| {
            try output.print(allocator, "  event_{d} -> event_{d} [label=\"parent\"];\n", .{ parent_id, event.id });
        }
    }
    try output.appendSlice(allocator, "}\n");
    return output.toOwnedSlice(allocator);
}
```

If label/status can contain quotes or newlines, reuse the existing causal DOT
escaping helpers by making them public or add a small local `appendEscapedDot`
helper.

Implement `collectClusterMetrics`:

```zig
var leases = try runner_store.leases(allocator);
defer leases.deinit();
snapshot.active_leases = leases.leases.len;

var shard_id: ShardId = 0;
while (shard_id < @as(ShardId, shard_count)) : (shard_id += 1) {
    var batch = try message_store.unprocessedByShard(shard_id, allocator);
    defer batch.deinit();
    snapshot.mailbox_lag += batch.records.len;
    for (batch.records) |record| {
        if (record.envelope.attempt > 0) snapshot.message_retries += 1;
    }
}
```

Count migrations and failures from `clusterCausalReport` and event kinds.

- [x] **Step 4: Verify green**

Run:

```bash
bun run zigeffect:test
zig fmt --check packages/zigeffect/src/cluster/observability.zig packages/zigeffect/test/cluster_observability_test.zig
```

- [x] **Step 5: Commit**

```bash
git add packages/zigeffect/src/cluster/observability.zig packages/zigeffect/test/cluster_observability_test.zig
git commit -m "feat(zigeffect): add cluster dot and metrics reports"
```

## Task 6: Traced Local Router APIs

- [x] **Step 1: Write failing traced router test**

Append to `cluster_observability_test.zig`:

```zig
test "local cluster router traced asks preserve trace context" {
    var message_storage_state = fx.InMemoryMessageStorage.init(std.testing.allocator);
    defer message_storage_state.deinit();
    var router = fx.LocalClusterRouter.init(std.testing.allocator, message_storage_state.asMessageStorage(), .{ .shard_count = 8 });

    const address = try observedAddressForShard(0, 8);
    var routed = try router.routeAskWithTrace(
        address,
        "text",
        "get",
        "traced ask",
        .{ .trace_id = 77, .span_id = 78 },
    );
    defer routed.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(?u64, 77), routed.envelope.trace_id);
    try std.testing.expectEqual(@as(?u64, 78), routed.envelope.span_id);
}
```

- [x] **Step 2: Verify red**

Run:

```bash
zig build test-raw --summary all
```

Expected: failure because `routeAskWithTrace` is absent.

- [x] **Step 3: Implement traced router APIs**

In `cluster/local_cluster.zig`, add:

```zig
pub fn routeTellWithTrace(self: *LocalClusterRouter, address: EntityAddress, payload_type_name: []const u8, payload: []const u8, redacted_detail: []const u8, trace: ClusterTraceContext) !LocalClusterRouteResult {
    return self.routeMessageWithTrace(.tell, address, payload_type_name, payload, redacted_detail, trace);
}

pub fn routeAskWithTrace(self: *LocalClusterRouter, address: EntityAddress, payload_type_name: []const u8, payload: []const u8, redacted_detail: []const u8, trace: ClusterTraceContext) !LocalClusterRouteResult {
    return self.routeMessageWithTrace(.request, address, payload_type_name, payload, redacted_detail, trace);
}
```

Refactor private `routeMessage` to call `routeMessageWithOptionalTrace`, and
set `trace_id`/`span_id` on the submitted envelope when trace is present.

- [x] **Step 4: Verify green**

Run:

```bash
bun run zigeffect:test
zig fmt --check packages/zigeffect/src/cluster/local_cluster.zig packages/zigeffect/test/cluster_observability_test.zig
```

- [x] **Step 5: Commit**

```bash
git add packages/zigeffect/src/cluster/local_cluster.zig packages/zigeffect/test/cluster_observability_test.zig
git commit -m "feat(zigeffect): add traced cluster router sends"
```

## Task 7: Docs, Roadmap, And Full Gate

- [x] **Step 1: Update architecture docs**

Add `observability.zig` to the `src/cluster/` list in
`packages/zigeffect/docs/architecture.md`:

```md
- `observability.zig`: cluster causal query reports, failure summaries,
  cluster-only DOT rendering, metrics collection, and message trace context
  helpers.
```

- [x] **Step 2: Mark M40 complete**

In `docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md`,
mark every M40 deliverable and acceptance checkbox complete.

In this plan, mark completed task steps with `- [x]` as each task finishes.

- [x] **Step 3: Run full verification gate**

Run:

```bash
bun run zigeffect:test
(cd packages/zigeffect && zig build examples)
(cd packages/zigeffect && zig build cluster-runner -- --help)
bun run zig:test
zig fmt --check packages/zigeffect/src/services/causal.zig packages/zigeffect/src/cluster/observability.zig packages/zigeffect/src/cluster/envelope.zig packages/zigeffect/src/cluster/message_storage.zig packages/zigeffect/src/cluster/runtime.zig packages/zigeffect/src/cluster/local_cluster.zig packages/zigeffect/src/cluster/root.zig packages/zigeffect/src/zigeffect.zig packages/zigeffect/test/cluster_observability_test.zig packages/zigeffect/test/all_test.zig
git diff --check
rg "TO""DO|FIX""ME|st""ub|place""holder|not imple""mented|unimple""mented" packages/zigeffect/src packages/zigeffect/test packages/zigeffect/docs docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md docs/superpowers/specs/2026-06-10-zigeffect-cluster-observability-design.md docs/superpowers/plans/2026-06-10-zigeffect-cluster-observability.md
```

- [x] **Step 4: Commit docs**

```bash
git add packages/zigeffect/docs/architecture.md docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md docs/superpowers/plans/2026-06-10-zigeffect-cluster-observability.md
git commit -m "docs(zigeffect): mark cluster observability complete"
```

## Self-Review

- Spec coverage: causal events, query report, DOT rendering, metrics,
  trace propagation, runtime hooks, failure report, docs, and roadmap all map to
  tasks.
- Marker scan: marker words are split in the full gate command.
- Type consistency: `ClusterTraceContext`, `ClusterCausalRecorder`,
  `ClusterCausalReport`, `ClusterQueryReport`, `ClusterMetricsSnapshot`,
  `ClusterFailureReport`, `formatClusterCausalDot`, `collectClusterMetrics`,
  `recordClusterMetrics`, and `formatClusterFailureReport` are named
  consistently.
