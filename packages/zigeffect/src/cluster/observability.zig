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

    pub fn init(store: *CausalStore, run_id: ?u64) ClusterCausalRecorder {
        return .{ .store = store, .run_id = run_id };
    }

    pub fn recordMessage(
        self: ClusterCausalRecorder,
        kind: CausalEventKind,
        shard_id: ShardId,
        message: message_storage.MessageEnvelope,
        status: []const u8,
        detail: []const u8,
    ) Allocator.Error!void {
        const label = try std.fmt.allocPrint(self.store.allocator, "message-{d}", .{message.id});
        defer self.store.allocator.free(label);
        const redacted_detail = try std.fmt.allocPrint(
            self.store.allocator,
            "shard={d} attempt={d} {s}",
            .{ shard_id, message.attempt, detail },
        );
        defer self.store.allocator.free(redacted_detail);
        _ = try self.store.record(.{
            .kind = kind,
            .run_id = self.run_id,
            .trace_id = message.trace_id,
            .span_id = message.span_id,
            .label = label,
            .type_name = "cluster.message",
            .status = status,
            .redacted_detail = redacted_detail,
        });
    }

    pub fn recordEntity(
        self: ClusterCausalRecorder,
        kind: CausalEventKind,
        address: EntityAddress,
        status: []const u8,
        detail: []const u8,
        trace: ?ClusterTraceContext,
    ) Allocator.Error!void {
        const label = try std.fmt.allocPrint(self.store.allocator, "{s}/{d}", .{ address.entity_type.name, address.id });
        defer self.store.allocator.free(label);
        _ = try self.store.record(.{
            .kind = kind,
            .run_id = self.run_id,
            .trace_id = if (trace) |value| value.trace_id else null,
            .span_id = if (trace) |value| value.span_id else null,
            .label = label,
            .type_name = address.entity_type.name,
            .status = status,
            .redacted_detail = detail,
        });
    }

    pub fn recordTracePropagation(
        self: ClusterCausalRecorder,
        shard_id: ShardId,
        message: message_storage.MessageEnvelope,
    ) Allocator.Error!void {
        try self.recordMessage(.cluster_trace_propagated, shard_id, message, "propagated", "trace context propagated");
    }
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
    max_shard_mailbox_lag: usize = 0,
    message_backpressure: usize = 0,
    message_retries: usize = 0,
    migrations: usize = 0,
    failures: usize = 0,
};

pub const ClusterFailureReport = struct {
    runner: RunnerAddress,
    shard_id: ShardId,
    message_id: MessageId,
    attempt: MessageAttempt,
    address: EntityAddress,
    cause: []const u8,
    redacted_detail: []const u8 = "",
};

pub fn clusterCausalReport(store: *const CausalStore) Allocator.Error!ClusterCausalReport {
    var report = ClusterCausalReport{};
    for (store.events.items) |event| {
        if (!isClusterEvent(event.kind)) continue;
        report.cluster_events += 1;
        switch (event.kind) {
            .cluster_runner_registered,
            .cluster_runner_heartbeat,
            => report.runner_events += 1,
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

pub fn isClusterEvent(kind: CausalEventKind) bool {
    return switch (kind) {
        .cluster_shard_lease_acquired,
        .cluster_shard_lease_refreshed,
        .cluster_shard_lease_released,
        .cluster_shard_lease_conflict,
        .cluster_shard_handoff_started,
        .cluster_shard_recovery_started,
        .cluster_shard_recovery_completed,
        .cluster_runner_registered,
        .cluster_runner_heartbeat,
        .cluster_message_submitted,
        .cluster_message_claimed,
        .cluster_message_acked,
        .cluster_message_replied,
        .cluster_entity_registered,
        .cluster_entity_processed,
        .cluster_entity_failed,
        .cluster_trace_propagated,
        => true,
        else => false,
    };
}

pub fn formatClusterCausalDot(allocator: Allocator, store: *const CausalStore) Allocator.Error![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, "digraph zigeffect_cluster {\n");
    try output.appendSlice(allocator, "  graph [rankdir=\"LR\", labelloc=\"t\", label=\"zigeffect cluster causal graph\"];\n");
    try output.appendSlice(allocator, "  node [shape=\"box\", style=\"rounded,filled\", fontname=\"Menlo\", fontsize=\"10\"];\n");
    try output.appendSlice(allocator, "  edge [fontname=\"Menlo\", fontsize=\"9\", color=\"#64748b\"];\n");
    for (store.events.items) |event| {
        if (!isClusterEvent(event.kind)) continue;
        try causal_mod.appendCausalDotEvent(&output, allocator, event);
    }
    try output.appendSlice(allocator, "}\n");
    return output.toOwnedSlice(allocator);
}

pub fn collectClusterMetrics(
    allocator: Allocator,
    runner_store: RunnerStorage,
    message_store: MessageStorage,
    shard_count: ShardCount,
    causal_store: ?*const CausalStore,
) !ClusterMetricsSnapshot {
    var snapshot = ClusterMetricsSnapshot{};

    var leases = try runner_store.leases(allocator);
    defer leases.deinit();
    snapshot.active_leases = leases.leases.len;

    var shard_id: ShardId = 0;
    while (shard_id < @as(ShardId, shard_count)) : (shard_id += 1) {
        var batch = try message_store.unprocessedByShard(shard_id, allocator);
        defer batch.deinit();
        const shard_lag = batch.records.len;
        snapshot.mailbox_lag += shard_lag;
        snapshot.max_shard_mailbox_lag = @max(snapshot.max_shard_mailbox_lag, shard_lag);
        if (shard_lag > 0) snapshot.message_backpressure += 1;
        for (batch.records) |record| {
            if (record.envelope.attempt > 0) {
                snapshot.message_retries += 1;
            }
        }
    }

    if (causal_store) |store| {
        const report = try clusterCausalReport(store);
        snapshot.failures = report.failures;
        for (store.events.items) |event| {
            switch (event.kind) {
                .cluster_shard_handoff_started,
                .cluster_shard_recovery_completed,
                => snapshot.migrations += 1,
                else => {},
            }
        }
    }

    return snapshot;
}

pub fn recordClusterMetrics(metrics: *Metrics, snapshot: ClusterMetricsSnapshot) Allocator.Error!void {
    try metrics.gauge("cluster.leases.active", @intCast(snapshot.active_leases));
    try metrics.gauge("cluster.mailbox.lag", @intCast(snapshot.mailbox_lag));
    try metrics.gauge("cluster.mailbox.lag.max", @intCast(snapshot.max_shard_mailbox_lag));
    try metrics.gauge("cluster.messages.backpressure", @intCast(snapshot.message_backpressure));
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
