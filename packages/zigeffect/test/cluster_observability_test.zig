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

fn expectClusterEvent(snapshot: fx.CausalSnapshot, kind: fx.CausalEventKind) !void {
    for (snapshot.events) |event| {
        if (event.kind == kind) return;
    }
    return error.ExpectedClusterEvent;
}

fn expectContains(haystack: []const u8, needle: []const u8) !void {
    try std.testing.expect(std.mem.indexOf(u8, haystack, needle) != null);
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
