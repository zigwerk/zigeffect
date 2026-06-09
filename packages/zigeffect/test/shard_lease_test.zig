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

test "shard lease manager acquires shards and records causal events" {
    var storage_state = fx.InMemoryRunnerStorage.init(std.testing.allocator);
    defer storage_state.deinit();
    const storage = storage_state.asRunnerStorage();
    const owner = fx.runnerAddress("machine-a", "runner-a");
    var causal = fx.CausalStore.init(std.testing.allocator);
    defer causal.deinit();

    var manager = try fx.LocalShardLeaseManager.init(
        std.testing.allocator,
        storage,
        owner,
        .{ .ttl_ms = 1_000, .refresh_interval_ms = 250 },
    );
    defer manager.deinit();
    manager.attachCausalStore(&causal, 900);

    const lease = try manager.acquireShard(5, 1_000);
    try std.testing.expectEqual(@as(fx.ShardId, 5), lease.shard_id);
    try std.testing.expect(manager.ownsShard(5));
    try std.testing.expectError(error.ShardAlreadyOwned, manager.acquireShard(5, 1_100));

    var owned = try manager.ownedLeases(std.testing.allocator);
    defer owned.deinit();
    try std.testing.expectEqual(@as(usize, 1), owned.leases.len);

    var snapshot = try causal.snapshot(std.testing.allocator);
    defer snapshot.deinit();
    try std.testing.expect(snapshotHasKind(snapshot, .cluster_shard_lease_acquired));
}

test "shard lease manager refreshes only due owned leases" {
    var storage_state = fx.InMemoryRunnerStorage.init(std.testing.allocator);
    defer storage_state.deinit();
    const storage = storage_state.asRunnerStorage();
    const owner = fx.runnerAddress("machine-a", "runner-a");
    var causal = fx.CausalStore.init(std.testing.allocator);
    defer causal.deinit();

    var manager = try fx.LocalShardLeaseManager.init(
        std.testing.allocator,
        storage,
        owner,
        .{ .ttl_ms = 1_000, .refresh_interval_ms = 250 },
    );
    defer manager.deinit();
    manager.attachCausalStore(&causal, 901);

    _ = try manager.acquireShard(6, 1_000);
    const early = try manager.refreshOwnedLeases(1_249);
    try std.testing.expectEqual(@as(usize, 0), early.refreshed);

    const due = try manager.refreshOwnedLeases(1_250);
    try std.testing.expectEqual(@as(usize, 1), due.refreshed);
    const stored = (try storage.lease(6)).?;
    try std.testing.expectEqual(@as(u64, 2_250), stored.expires_at_ms);
    try std.testing.expectEqual(@as(u64, 2), stored.version);

    var snapshot = try causal.snapshot(std.testing.allocator);
    defer snapshot.deinit();
    try std.testing.expect(snapshotHasKind(snapshot, .cluster_shard_lease_refreshed));
}

fn snapshotHasKind(snapshot: fx.CausalSnapshot, kind: fx.CausalEventKind) bool {
    for (snapshot.events) |event| {
        if (event.kind == kind) return true;
    }
    return false;
}
