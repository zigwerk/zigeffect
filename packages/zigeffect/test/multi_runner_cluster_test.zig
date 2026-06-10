const std = @import("std");
const fx = @import("zigeffect");

test "local cluster public exports are available" {
    try std.testing.expect(@hasDecl(fx.cluster, "local_cluster"));
    try std.testing.expect(@hasDecl(fx.cluster, "LocalClusterError"));
    try std.testing.expect(@hasDecl(fx.cluster, "ShardBalancePlan"));
    try std.testing.expect(@hasDecl(fx.cluster, "LocalClusterRouter"));
    try std.testing.expect(@hasDecl(fx.cluster, "LocalClusterRouteResult"));
    try std.testing.expect(@hasDecl(fx.cluster, "LocalClusterRunnerOptions"));
    try std.testing.expect(@hasDecl(fx.cluster, "LocalClusterRunner"));
    try std.testing.expect(@hasDecl(fx.cluster, "LocalClusterRunnerReport"));
    try std.testing.expect(@hasDecl(fx.cluster, "ShardRecoveryPlan"));
    try std.testing.expect(@hasDecl(fx.cluster, "balancedShardPlan"));
    try std.testing.expect(@hasDecl(fx, "LocalClusterRunner"));
}

test "balanced shard plan splits shards by runner index" {
    var even = try fx.balancedShardPlan(std.testing.allocator, 8, 0, 2);
    defer even.deinit();
    var odd = try fx.balancedShardPlan(std.testing.allocator, 8, 1, 2);
    defer odd.deinit();

    try std.testing.expectEqualSlices(fx.ShardId, &.{ 0, 2, 4, 6 }, even.shards);
    try std.testing.expectEqualSlices(fx.ShardId, &.{ 1, 3, 5, 7 }, odd.shards);
}

test "balanced shard plan validates shard and runner counts" {
    try std.testing.expectError(error.InvalidShardCount, fx.balancedShardPlan(std.testing.allocator, 0, 0, 2));
    try std.testing.expectError(error.InvalidRunnerCount, fx.balancedShardPlan(std.testing.allocator, 8, 0, 0));
    try std.testing.expectError(error.InvalidRunnerIndex, fx.balancedShardPlan(std.testing.allocator, 8, 2, 2));
}
