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

test "shard lease manager reacquires expired owned leases" {
    var storage_state = fx.InMemoryRunnerStorage.init(std.testing.allocator);
    defer storage_state.deinit();
    const storage = storage_state.asRunnerStorage();
    const owner = fx.runnerAddress("machine-a", "runner-a");

    var manager = try fx.LocalShardLeaseManager.init(
        std.testing.allocator,
        storage,
        owner,
        .{ .ttl_ms = 100, .refresh_interval_ms = 25 },
    );
    defer manager.deinit();

    _ = try manager.acquireShard(8, 1_000);
    const report = try manager.refreshOwnedLeases(1_100);
    try std.testing.expectEqual(@as(usize, 1), report.expired);
    try std.testing.expectEqual(@as(usize, 1), report.reacquired);
    const stored = (try storage.lease(8)).?;
    try std.testing.expect(stored.owner.eql(owner));
    try std.testing.expectEqual(@as(u64, 1_200), stored.expires_at_ms);
    try std.testing.expectEqual(@as(u64, 2), stored.version);
}

test "shard lease manager gracefully hands off owned shards" {
    var storage_state = fx.InMemoryRunnerStorage.init(std.testing.allocator);
    defer storage_state.deinit();
    const storage = storage_state.asRunnerStorage();
    const source_owner = fx.runnerAddress("machine-a", "runner-a");
    const target_owner = fx.runnerAddress("machine-b", "runner-b");

    var source = try fx.LocalShardLeaseManager.init(
        std.testing.allocator,
        storage,
        source_owner,
        .{ .ttl_ms = 1_000, .refresh_interval_ms = 250 },
    );
    defer source.deinit();
    var target = try fx.LocalShardLeaseManager.init(
        std.testing.allocator,
        storage,
        target_owner,
        .{ .ttl_ms = 1_000, .refresh_interval_ms = 250 },
    );
    defer target.deinit();

    _ = try source.acquireShard(9, 1_000);
    const handoff = try source.handoffShard(9, target_owner, 1_100);
    try std.testing.expectEqual(@as(fx.ShardId, 9), handoff.shard_id);
    try std.testing.expect(!source.ownsShard(9));
    try std.testing.expect((try storage.lease(9)) == null);

    const target_lease = try target.acquireShard(9, 1_101);
    try std.testing.expect(target_lease.owner.eql(target_owner));
    try std.testing.expect(target.ownsShard(9));
    try std.testing.expectError(error.ShardNotOwned, source.handoffShard(9, target_owner, 1_200));
}

test "shard lease recovery refuses live runners" {
    var storage_state = fx.InMemoryRunnerStorage.init(std.testing.allocator);
    defer storage_state.deinit();
    const storage = storage_state.asRunnerStorage();
    const live = fx.runnerAddress("machine-a", "runner-a");
    const survivor = fx.runnerAddress("machine-b", "runner-b");

    var registry = fx.LocalRunnerRegistry.init(std.testing.allocator);
    defer registry.deinit();
    _ = try registry.registerRunner(.{ .address = live, .name = "live", .started_at_ms = 1_000 });
    _ = try registry.recordHeartbeat(.{ .address = live, .sequence = 1, .observed_at_ms = 1_100 });
    const inspector = try fx.LocalRunnerHealthInspector.init(.{ .degraded_after_ms = 100, .unhealthy_after_ms = 500 });

    var manager = try fx.LocalShardLeaseManager.init(
        std.testing.allocator,
        storage,
        survivor,
        .{ .ttl_ms = 1_000, .refresh_interval_ms = 250 },
    );
    defer manager.deinit();

    try std.testing.expectError(error.RunnerStillAlive, manager.recoverDeadRunner(&registry, &inspector, live, 1_150));
}

test "shard lease recovery releases dead runner leases for survivor reacquisition" {
    var storage_state = fx.InMemoryRunnerStorage.init(std.testing.allocator);
    defer storage_state.deinit();
    const storage = storage_state.asRunnerStorage();
    const dead = fx.runnerAddress("machine-a", "runner-a");
    const survivor = fx.runnerAddress("machine-b", "runner-b");
    var causal = fx.CausalStore.init(std.testing.allocator);
    defer causal.deinit();

    var registry = fx.LocalRunnerRegistry.init(std.testing.allocator);
    defer registry.deinit();
    _ = try registry.registerRunner(.{ .address = dead, .name = "dead", .started_at_ms = 1_000 });
    _ = try registry.recordHeartbeat(.{ .address = dead, .sequence = 1, .observed_at_ms = 1_050 });
    const inspector = try fx.LocalRunnerHealthInspector.init(.{ .degraded_after_ms = 100, .unhealthy_after_ms = 300 });

    _ = try storage.acquire(.{ .shard_id = 12, .owner = dead, .now_ms = 1_050, .ttl_ms = 10_000 });

    var survivor_manager = try fx.LocalShardLeaseManager.init(
        std.testing.allocator,
        storage,
        survivor,
        .{ .ttl_ms = 1_000, .refresh_interval_ms = 250 },
    );
    defer survivor_manager.deinit();
    survivor_manager.attachCausalStore(&causal, 902);

    const recovery = try survivor_manager.recoverDeadRunner(&registry, &inspector, dead, 1_400);
    try std.testing.expectEqual(@as(usize, 1), recovery.released);
    try std.testing.expect((try storage.lease(12)) == null);

    const reacquired = try survivor_manager.acquireShard(12, 1_401);
    try std.testing.expect(reacquired.owner.eql(survivor));

    var snapshot = try causal.snapshot(std.testing.allocator);
    defer snapshot.deinit();
    try std.testing.expect(snapshotHasKind(snapshot, .cluster_shard_recovery_started));
    try std.testing.expect(snapshotHasKind(snapshot, .cluster_shard_recovery_completed));
}

fn snapshotHasKind(snapshot: fx.CausalSnapshot, kind: fx.CausalEventKind) bool {
    for (snapshot.events) |event| {
        if (event.kind == kind) return true;
    }
    return false;
}
