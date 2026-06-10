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

test "local cluster router writes tell and ask messages to shared file storage" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    var message_storage_state = try fx.FileMessageStorage.open(std.testing.allocator, std.testing.io, &tmp.dir, .{});
    defer message_storage_state.deinit();
    const message_storage = message_storage_state.asMessageStorage();

    var router = fx.LocalClusterRouter.init(std.testing.allocator, message_storage, .{ .shard_count = 16 });
    const address = fx.entityAddress("counter", "router-shared");
    const shard_id = try fx.shardIdForAddress(address, 16);

    var tell = try router.routeTell(address, "text", "inc", "first command");
    defer tell.deinit(std.testing.allocator);
    try std.testing.expectEqual(shard_id, tell.shard_id);
    try std.testing.expectEqual(fx.MessageEnvelopeKind.tell, tell.envelope.kind);
    try std.testing.expect(!tell.duplicate);

    var ask = try router.routeAsk(address, "text", "get", "read current value");
    defer ask.deinit(std.testing.allocator);
    try std.testing.expectEqual(shard_id, ask.shard_id);
    try std.testing.expectEqual(fx.MessageEnvelopeKind.request, ask.envelope.kind);
    try std.testing.expect(ask.correlation_id != null);

    var by_shard = try message_storage.unprocessedByShard(shard_id, std.testing.allocator);
    defer by_shard.deinit();
    try std.testing.expectEqual(@as(usize, 2), by_shard.records.len);
    var saw_tell = false;
    var saw_request = false;
    for (by_shard.records) |record| {
        if (record.envelope.kind == .tell) saw_tell = true;
        if (record.envelope.kind == .request) saw_request = true;
    }
    try std.testing.expect(saw_tell);
    try std.testing.expect(saw_request);
}
