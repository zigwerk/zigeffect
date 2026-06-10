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
