const std = @import("std");
const fx = @import("zigeffect");

test "real cluster public exports are available" {
    try std.testing.expect(@hasDecl(fx.cluster, "real_cluster"));
    try std.testing.expect(@hasDecl(fx.cluster, "RealClusterController"));
    try std.testing.expect(@hasDecl(fx.cluster, "RealClusterControllerOptions"));
    try std.testing.expect(@hasDecl(fx.cluster, "RealClusterError"));
    try std.testing.expect(@hasDecl(fx.cluster, "ClusterMembershipState"));
    try std.testing.expect(@hasDecl(fx.cluster, "ClusterAdmissionDecision"));
    try std.testing.expect(@hasDecl(fx.cluster, "ClusterMember"));
    try std.testing.expect(@hasDecl(fx.cluster, "ClusterMembershipReport"));
    try std.testing.expect(@hasDecl(fx.cluster, "ClusterPlacementStrategy"));
    try std.testing.expect(@hasDecl(fx.cluster, "ClusterShardPlacement"));
    try std.testing.expect(@hasDecl(fx.cluster, "ClusterPlacementPlan"));
    try std.testing.expect(@hasDecl(fx.cluster, "ClusterRebalanceActionKind"));
    try std.testing.expect(@hasDecl(fx.cluster, "ClusterRebalanceAction"));
    try std.testing.expect(@hasDecl(fx.cluster, "ClusterRebalancePlan"));
    try std.testing.expect(@hasDecl(fx.cluster, "ClusterDrainPlan"));
    try std.testing.expect(@hasDecl(fx.cluster, "ClusterNodeDownRecoveryPlan"));
    try std.testing.expect(@hasDecl(fx.cluster, "ClusterSplitBrainFinding"));
    try std.testing.expect(@hasDecl(fx.cluster, "ClusterSplitBrainReport"));
    try std.testing.expect(@hasDecl(fx.cluster, "ClusterInspectionReport"));
    try std.testing.expect(@hasDecl(fx.cluster, "formatClusterInspectionText"));
    try std.testing.expect(@hasDecl(fx.cluster, "formatClusterInspectionJson"));
    try std.testing.expect(@hasDecl(fx, "RealClusterController"));
}
