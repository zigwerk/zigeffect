const std = @import("std");
const fx = @import("zigeffect");

test "cluster runtime public exports are available" {
    try std.testing.expect(@hasDecl(fx.cluster, "runtime"));
    try std.testing.expect(@hasDecl(fx.cluster, "ClusterRuntime"));
    try std.testing.expect(@hasDecl(fx.cluster, "ClusterRuntimeOptions"));
    try std.testing.expect(@hasDecl(fx.cluster, "ClusterRuntimeError"));
    try std.testing.expect(@hasDecl(fx.cluster, "ClusterEntityRef"));
    try std.testing.expect(@hasDecl(fx.cluster, "ClusterAsk"));
    try std.testing.expect(@hasDecl(fx.cluster, "ClusterProcessReport"));
    try std.testing.expect(@hasDecl(fx.cluster, "ClusterShutdownReport"));
    try std.testing.expect(@hasDecl(fx, "ClusterRuntime"));
}

test "cluster runtime loads owned shards from lease manager" {
    var runner_storage_state = fx.InMemoryRunnerStorage.init(std.testing.allocator);
    defer runner_storage_state.deinit();
    const runner_storage = runner_storage_state.asRunnerStorage();
    const owner = fx.runnerAddress("machine-a", "runner-a");
    var lease_manager = try fx.LocalShardLeaseManager.init(
        std.testing.allocator,
        runner_storage,
        owner,
        .{ .ttl_ms = 1_000, .refresh_interval_ms = 250 },
    );
    defer lease_manager.deinit();
    var message_storage_state = fx.InMemoryMessageStorage.init(std.testing.allocator);
    defer message_storage_state.deinit();

    var runtime = try fx.ClusterRuntime.init(
        std.testing.allocator,
        message_storage_state.asMessageStorage(),
        &lease_manager,
        .{ .shard_count = 16 },
    );
    defer runtime.deinit();

    _ = try lease_manager.acquireShard(3, 1_000);
    _ = try lease_manager.acquireShard(5, 1_000);

    try std.testing.expectEqual(@as(usize, 2), try runtime.loadOwnedShards());
    try std.testing.expectEqual(@as(usize, 2), runtime.ownedShardCount());
    try std.testing.expect(runtime.ownsShard(3));
    try std.testing.expect(runtime.ownsShard(5));
    try std.testing.expect(!runtime.ownsShard(7));
}

test "cluster runtime acquire and release shard update runtime and leases" {
    var runner_storage_state = fx.InMemoryRunnerStorage.init(std.testing.allocator);
    defer runner_storage_state.deinit();
    const runner_storage = runner_storage_state.asRunnerStorage();
    const owner = fx.runnerAddress("machine-a", "runner-a");
    var lease_manager = try fx.LocalShardLeaseManager.init(
        std.testing.allocator,
        runner_storage,
        owner,
        .{ .ttl_ms = 1_000, .refresh_interval_ms = 250 },
    );
    defer lease_manager.deinit();
    var message_storage_state = fx.InMemoryMessageStorage.init(std.testing.allocator);
    defer message_storage_state.deinit();

    var runtime = try fx.ClusterRuntime.init(
        std.testing.allocator,
        message_storage_state.asMessageStorage(),
        &lease_manager,
        .{ .shard_count = 16 },
    );
    defer runtime.deinit();

    const lease = try runtime.acquireShard(4, 1_000);
    try std.testing.expectEqual(@as(fx.ShardId, 4), lease.shard_id);
    try std.testing.expect(runtime.ownsShard(4));
    try std.testing.expect(lease_manager.ownsShard(4));
    try std.testing.expect((try runner_storage.lease(4)) != null);

    try runtime.releaseShard(4, 1_100);
    try std.testing.expect(!runtime.ownsShard(4));
    try std.testing.expect(!lease_manager.ownsShard(4));
    try std.testing.expect((try runner_storage.lease(4)) == null);
}
