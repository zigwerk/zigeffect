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

test "runner lease json round-trips" {
    const owner = fx.runnerAddress("machine-a", "runner-a");
    const lease: fx.ShardLease = .{
        .shard_id = 42,
        .owner = owner,
        .acquired_at_ms = 1_000,
        .refreshed_at_ms = 1_000,
        .expires_at_ms = 2_000,
        .version = 7,
    };

    const json = try fx.formatShardLeaseJson(std.testing.allocator, lease);
    defer std.testing.allocator.free(json);

    const parsed = try fx.parseShardLeaseJson(std.testing.allocator, json);
    try std.testing.expectEqual(lease.shard_id, parsed.shard_id);
    try std.testing.expect(parsed.owner.eql(owner));
    try std.testing.expectEqual(lease.version, parsed.version);
}

test "file runner storage acquires leases atomically across store instances" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    var first = try fx.FileRunnerStorage.open(std.testing.allocator, std.testing.io, &tmp.dir, .{});
    defer first.deinit();
    var second = try fx.FileRunnerStorage.open(std.testing.allocator, std.testing.io, &tmp.dir, .{});
    defer second.deinit();

    var first_contract = first.asRunnerStorage();
    var second_contract = second.asRunnerStorage();
    const owner = fx.runnerAddress("machine-a", "runner-a");
    const contender = fx.runnerAddress("machine-b", "runner-b");

    _ = try first_contract.acquire(.{ .shard_id = 17, .owner = owner, .now_ms = 500, .ttl_ms = 250 });
    try std.testing.expectError(error.LeaseConflict, second_contract.acquire(.{
        .shard_id = 17,
        .owner = contender,
        .now_ms = 600,
        .ttl_ms = 250,
    }));

    const found = (try second_contract.lease(17)).?;
    try std.testing.expect(found.owner.eql(owner));

    const file = try tmp.dir.openFile(std.testing.io, "runner-shard-17.json", .{});
    file.close(std.testing.io);
}

test "file runner storage replaces expired persisted leases" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    var first = try fx.FileRunnerStorage.open(std.testing.allocator, std.testing.io, &tmp.dir, .{});
    defer first.deinit();
    var second = try fx.FileRunnerStorage.open(std.testing.allocator, std.testing.io, &tmp.dir, .{});
    defer second.deinit();

    var first_contract = first.asRunnerStorage();
    var second_contract = second.asRunnerStorage();
    const owner = fx.runnerAddress("machine-a", "runner-a");
    const contender = fx.runnerAddress("machine-b", "runner-b");
    _ = try first_contract.acquire(.{ .shard_id = 18, .owner = owner, .now_ms = 100, .ttl_ms = 25 });

    const replacement = try second_contract.acquire(.{ .shard_id = 18, .owner = contender, .now_ms = 125, .ttl_ms = 100 });
    try std.testing.expect(replacement.owner.eql(contender));
    try std.testing.expectEqual(@as(u64, 2), replacement.version);
}
