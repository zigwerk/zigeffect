const std = @import("std");
const fx = @import("zigeffect");

test "runner storage public exports are available" {
    try std.testing.expect(@hasDecl(fx.cluster, "runner_storage"));
    try std.testing.expect(@hasDecl(fx.cluster, "RunnerStorage"));
    try std.testing.expect(@hasDecl(fx.cluster, "ShardLease"));
    try std.testing.expect(@hasDecl(fx.cluster, "RunnerLeaseAcquire"));
    try std.testing.expect(@hasDecl(fx.cluster, "InMemoryRunnerStorage"));
    try std.testing.expect(@hasDecl(fx.cluster, "FileRunnerStorage"));
    try std.testing.expect(@hasDecl(fx, "RunnerStorage"));
}

test "in-memory runner storage acquires and lists leases" {
    var storage = fx.InMemoryRunnerStorage.init(std.testing.allocator);
    defer storage.deinit();
    var contract = storage.asRunnerStorage();

    const owner = fx.runnerAddress("machine-a", "runner-a");
    const lease = try contract.acquire(.{
        .shard_id = 3,
        .owner = owner,
        .now_ms = 1_000,
        .ttl_ms = 500,
    });

    try std.testing.expectEqual(@as(fx.ShardId, 3), lease.shard_id);
    try std.testing.expect(lease.owner.eql(owner));
    try std.testing.expectEqual(@as(u64, 1_000), lease.acquired_at_ms);
    try std.testing.expectEqual(@as(u64, 1_500), lease.expires_at_ms);
    try std.testing.expectEqual(@as(u64, 1), lease.version);

    const found = (try contract.lease(3)).?;
    try std.testing.expect(found.owner.eql(owner));

    var leases = try contract.leases(std.testing.allocator);
    defer leases.deinit();
    try std.testing.expectEqual(@as(usize, 1), leases.leases.len);
}

test "in-memory runner storage rejects active lease conflicts and invalid ttl" {
    var storage = fx.InMemoryRunnerStorage.init(std.testing.allocator);
    defer storage.deinit();
    var contract = storage.asRunnerStorage();

    const owner = fx.runnerAddress("machine-a", "runner-a");
    const contender = fx.runnerAddress("machine-b", "runner-b");
    _ = try contract.acquire(.{ .shard_id = 8, .owner = owner, .now_ms = 10, .ttl_ms = 100 });

    try std.testing.expectError(error.LeaseConflict, contract.acquire(.{
        .shard_id = 8,
        .owner = contender,
        .now_ms = 20,
        .ttl_ms = 100,
    }));
    try std.testing.expectError(error.InvalidLeaseTtl, contract.acquire(.{
        .shard_id = 9,
        .owner = owner,
        .now_ms = 20,
        .ttl_ms = 0,
    }));
}

test "in-memory runner storage replaces expired leases" {
    var storage = fx.InMemoryRunnerStorage.init(std.testing.allocator);
    defer storage.deinit();
    var contract = storage.asRunnerStorage();

    const owner = fx.runnerAddress("machine-a", "runner-a");
    const contender = fx.runnerAddress("machine-b", "runner-b");
    _ = try contract.acquire(.{ .shard_id = 4, .owner = owner, .now_ms = 100, .ttl_ms = 25 });

    const replacement = try contract.acquire(.{ .shard_id = 4, .owner = contender, .now_ms = 125, .ttl_ms = 50 });
    try std.testing.expect(replacement.owner.eql(contender));
    try std.testing.expectEqual(@as(u64, 2), replacement.version);
    try std.testing.expectEqual(@as(u64, 175), replacement.expires_at_ms);
}

test "in-memory runner storage refreshes and releases owned leases" {
    var storage = fx.InMemoryRunnerStorage.init(std.testing.allocator);
    defer storage.deinit();
    var contract = storage.asRunnerStorage();

    const owner = fx.runnerAddress("machine-a", "runner-a");
    const intruder = fx.runnerAddress("machine-b", "runner-b");
    _ = try contract.acquire(.{ .shard_id = 12, .owner = owner, .now_ms = 1_000, .ttl_ms = 200 });

    try std.testing.expectError(error.LeaseNotOwned, contract.refresh(.{
        .shard_id = 12,
        .owner = intruder,
        .now_ms = 1_100,
        .ttl_ms = 200,
    }));

    const refreshed = try contract.refresh(.{ .shard_id = 12, .owner = owner, .now_ms = 1_100, .ttl_ms = 400 });
    try std.testing.expectEqual(@as(u64, 2), refreshed.version);
    try std.testing.expectEqual(@as(u64, 1_500), refreshed.expires_at_ms);

    try std.testing.expectError(error.LeaseNotOwned, contract.release(.{ .shard_id = 12, .owner = intruder }));
    try contract.release(.{ .shard_id = 12, .owner = owner });
    try std.testing.expect((try contract.lease(12)) == null);
}

test "in-memory runner storage rejects expired refreshes and releases all owned leases" {
    var storage = fx.InMemoryRunnerStorage.init(std.testing.allocator);
    defer storage.deinit();
    var contract = storage.asRunnerStorage();

    const owner = fx.runnerAddress("machine-a", "runner-a");
    const other = fx.runnerAddress("machine-b", "runner-b");
    _ = try contract.acquire(.{ .shard_id = 1, .owner = owner, .now_ms = 0, .ttl_ms = 10 });
    _ = try contract.acquire(.{ .shard_id = 2, .owner = owner, .now_ms = 0, .ttl_ms = 100 });
    _ = try contract.acquire(.{ .shard_id = 3, .owner = other, .now_ms = 0, .ttl_ms = 100 });

    try std.testing.expectError(error.LeaseExpired, contract.refresh(.{
        .shard_id = 1,
        .owner = owner,
        .now_ms = 10,
        .ttl_ms = 100,
    }));

    const released = try contract.releaseAll(owner);
    try std.testing.expectEqual(@as(usize, 2), released);
    var leases = try contract.leases(std.testing.allocator);
    defer leases.deinit();
    try std.testing.expectEqual(@as(usize, 1), leases.leases.len);
    try std.testing.expect(leases.leases[0].owner.eql(other));
}
