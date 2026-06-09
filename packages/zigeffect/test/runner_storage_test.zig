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
