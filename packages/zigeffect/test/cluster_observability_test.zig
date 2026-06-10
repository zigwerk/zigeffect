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
