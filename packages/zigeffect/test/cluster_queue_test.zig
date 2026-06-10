const std = @import("std");
const fx = @import("zigeffect");

test "cluster queue public exports are available" {
    try std.testing.expect(@hasDecl(fx.cluster, "queue"));
    try std.testing.expect(@hasDecl(fx.cluster, "ClusterQueueStatus"));
    try std.testing.expect(@hasDecl(fx.cluster, "ClusterQueueItem"));
    try std.testing.expect(@hasDecl(fx.cluster, "ClusterQueueBatch"));
    try std.testing.expect(@hasDecl(fx.cluster, "ClusterQueueRebuildReport"));
    try std.testing.expect(@hasDecl(fx.cluster, "ClusterQueueClaimLimits"));
    try std.testing.expect(@hasDecl(fx.cluster, "ClusterQueueIndex"));
    try std.testing.expect(@hasDecl(fx, "ClusterQueueIndex"));
}
