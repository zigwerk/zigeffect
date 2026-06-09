const std = @import("std");
const fx = @import("zigeffect");

test "shard routing public exports are available" {
    try std.testing.expect(@hasDecl(fx.cluster, "routing"));
    try std.testing.expect(@hasDecl(fx.cluster, "ShardId"));
    try std.testing.expect(@hasDecl(fx.cluster, "ShardCount"));
    try std.testing.expect(@hasDecl(fx.cluster, "ShardRoutingTable"));
    try std.testing.expect(@hasDecl(fx.cluster, "shardIdForEntityId"));
    try std.testing.expect(@hasDecl(fx.cluster, "shardIdForAddress"));
    try std.testing.expect(@hasDecl(fx, "ShardId"));
    try std.testing.expect(@hasDecl(fx, "ShardRoutingTable"));
}

test "shard ids are stable bounded and entity-sensitive" {
    const shard_count: fx.ShardCount = 16;
    const first_id = fx.entityId("counter", "tenant-1");
    const second_id = fx.entityId("counter", "tenant-1");
    const other_type_id = fx.entityId("ledger", "tenant-1");
    const other_key_id = fx.entityId("counter", "tenant-2");

    const first = try fx.shardIdForEntityId(first_id, shard_count);
    const second = try fx.shardIdForEntityId(second_id, shard_count);
    const other_type = try fx.shardIdForEntityId(other_type_id, shard_count);
    const other_key = try fx.shardIdForEntityId(other_key_id, shard_count);
    const by_address = try fx.shardIdForAddress(fx.entityAddress("counter", "tenant-1"), shard_count);

    try std.testing.expectEqual(first, second);
    try std.testing.expectEqual(first, by_address);
    try std.testing.expect(first < @as(fx.ShardId, shard_count));
    try std.testing.expect(other_type < @as(fx.ShardId, shard_count));
    try std.testing.expect(other_key < @as(fx.ShardId, shard_count));

    var occupied = [_]bool{false} ** 16;
    const keys = [_][]const u8{ "tenant-1", "tenant-2", "tenant-3", "tenant-4", "tenant-5", "tenant-6", "tenant-7", "tenant-8" };
    for (keys) |key| {
        const shard = try fx.shardIdForAddress(fx.entityAddress("counter", key), shard_count);
        const index: usize = @intCast(shard);
        occupied[index] = true;
    }
    var occupied_count: usize = 0;
    for (occupied) |is_occupied| {
        if (is_occupied) occupied_count += 1;
    }
    try std.testing.expect(occupied_count > 1);
}

test "zero shard counts fail clearly" {
    const address = fx.entityAddress("counter", "one");
    try std.testing.expectError(error.InvalidShardCount, fx.shardIdForAddress(address, 0));
    try std.testing.expectError(error.InvalidShardCount, fx.shardIdForEntityId(address.id, 0));
    try std.testing.expectError(error.InvalidShardCount, fx.ShardRoutingTable.initLocal(std.testing.allocator, .{ .shard_count = 0 }));
}

test "local routing table owns every configured shard" {
    var table = try fx.ShardRoutingTable.initLocal(std.testing.allocator, .{ .shard_count = 8 });
    defer table.deinit();

    try std.testing.expectEqual(@as(fx.ShardCount, 8), table.shardCount());
    try std.testing.expectEqual(@as(fx.ShardRoutingVersion, 1), table.version());

    for (0..8) |index| {
        const shard_id: fx.ShardId = @intCast(index);
        try std.testing.expectEqual(fx.ShardRouteTarget.local, try table.routeShard(shard_id));
    }
    try std.testing.expectError(error.ShardNotFound, table.routeShard(8));

    const address = fx.entityAddress("counter", "one");
    const route = try table.route(address);
    try std.testing.expectEqual(try fx.shardIdForAddress(address, 8), route.shard_id);
    try std.testing.expectEqual(fx.ShardRouteTarget.local, route.target);
}

test "routing table snapshot reload preserves entity routes" {
    var table = try fx.ShardRoutingTable.initLocal(std.testing.allocator, .{
        .shard_count = 12,
        .version = 7,
    });
    defer table.deinit();

    const address = fx.entityAddress("counter", "reload");
    const before = try table.route(address);
    const snapshot = table.snapshot();

    var reloaded = try fx.ShardRoutingTable.reloadLocal(std.testing.allocator, snapshot);
    defer reloaded.deinit();
    const after = try reloaded.route(address);

    try std.testing.expectEqual(@as(fx.ShardCount, 12), snapshot.shard_count);
    try std.testing.expectEqual(@as(fx.ShardRoutingVersion, 7), snapshot.version);
    try std.testing.expectEqual(before.shard_id, after.shard_id);
    try std.testing.expectEqual(before.target, after.target);
    try std.testing.expectEqual(table.shardCount(), reloaded.shardCount());
    try std.testing.expectEqual(table.version(), reloaded.version());
}
