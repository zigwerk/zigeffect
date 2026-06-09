const std = @import("std");
const fx = @import("zigeffect");

test "shard lease public exports are available" {
    try std.testing.expect(@hasDecl(fx.cluster, "shard_lease"));
    try std.testing.expect(@hasDecl(fx.cluster, "LocalShardLeaseManager"));
    try std.testing.expect(@hasDecl(fx.cluster, "ShardLeaseManagerOptions"));
    try std.testing.expect(@hasDecl(fx.cluster, "ShardLeaseRefreshReport"));
    try std.testing.expect(@hasDecl(fx.cluster, "ShardLeaseRecoveryReport"));
    try std.testing.expect(@hasDecl(fx.cluster, "ShardHandoffReport"));
    try std.testing.expect(@hasDecl(fx, "LocalShardLeaseManager"));
}

test "shard lease manager validates ttl and refresh cadence" {
    var storage_state = fx.InMemoryRunnerStorage.init(std.testing.allocator);
    defer storage_state.deinit();
    const storage = storage_state.asRunnerStorage();
    const owner = fx.runnerAddress("machine-a", "runner-a");

    try std.testing.expectError(error.InvalidLeaseOptions, fx.LocalShardLeaseManager.init(
        std.testing.allocator,
        storage,
        owner,
        .{ .ttl_ms = 0, .refresh_interval_ms = 10 },
    ));
    try std.testing.expectError(error.InvalidLeaseOptions, fx.LocalShardLeaseManager.init(
        std.testing.allocator,
        storage,
        owner,
        .{ .ttl_ms = 100, .refresh_interval_ms = 0 },
    ));
    try std.testing.expectError(error.InvalidLeaseOptions, fx.LocalShardLeaseManager.init(
        std.testing.allocator,
        storage,
        owner,
        .{ .ttl_ms = 100, .refresh_interval_ms = 100 },
    ));
}

test "shard lease cadence reports next refresh and due state" {
    const owner = fx.runnerAddress("machine-a", "runner-a");
    const lease: fx.ShardLease = .{
        .shard_id = 7,
        .owner = owner,
        .acquired_at_ms = 1_000,
        .refreshed_at_ms = 1_000,
        .expires_at_ms = 2_000,
        .version = 1,
    };
    const options: fx.ShardLeaseManagerOptions = .{ .ttl_ms = 1_000, .refresh_interval_ms = 250 };

    try std.testing.expectEqual(@as(u64, 1_250), fx.shardLeaseNextRefreshAt(lease, options));
    try std.testing.expect(!fx.shardLeaseRefreshDue(lease, options, 1_249));
    try std.testing.expect(fx.shardLeaseRefreshDue(lease, options, 1_250));
}
