const std = @import("std");
const fx = @import("zigeffect");

pub fn expectRunnerStorageConformance(store: fx.RunnerStorage) !void {
    const owner = fx.runnerAddress("machine-storage", "runner-a");
    const contender = fx.runnerAddress("machine-storage", "runner-b");
    const other = fx.runnerAddress("machine-other", "runner-c");

    const lease = try store.acquire(.{ .shard_id = 3, .owner = owner, .now_ms = 1_000, .ttl_ms = 500 });
    try std.testing.expect(lease.owner.eql(owner));
    try std.testing.expectEqual(@as(u64, 1_500), lease.expires_at_ms);
    try std.testing.expectEqual(@as(u64, 1), lease.version);

    try std.testing.expectError(error.LeaseConflict, store.acquire(.{
        .shard_id = 3,
        .owner = contender,
        .now_ms = 1_100,
        .ttl_ms = 500,
    }));

    const replacement = try store.acquire(.{ .shard_id = 3, .owner = contender, .now_ms = 1_500, .ttl_ms = 100 });
    try std.testing.expect(replacement.owner.eql(contender));
    try std.testing.expectEqual(@as(u64, 2), replacement.version);

    try std.testing.expectError(error.LeaseNotOwned, store.refresh(.{
        .shard_id = 3,
        .owner = owner,
        .now_ms = 1_525,
        .ttl_ms = 100,
    }));
    const refreshed = try store.refresh(.{ .shard_id = 3, .owner = contender, .now_ms = 1_525, .ttl_ms = 200 });
    try std.testing.expectEqual(@as(u64, 1_725), refreshed.expires_at_ms);

    _ = try store.acquire(.{ .shard_id = 4, .owner = contender, .now_ms = 1_525, .ttl_ms = 200 });
    _ = try store.acquire(.{ .shard_id = 5, .owner = other, .now_ms = 1_525, .ttl_ms = 200 });

    try std.testing.expectError(error.LeaseNotOwned, store.release(.{ .shard_id = 4, .owner = owner }));
    const released = try store.releaseAll(contender);
    try std.testing.expectEqual(@as(usize, 2), released);

    var leases = try store.leases(std.testing.allocator);
    defer leases.deinit();
    try std.testing.expectEqual(@as(usize, 1), leases.leases.len);
    try std.testing.expect(leases.leases[0].owner.eql(other));

    store.reset();
    var after_reset = try store.leases(std.testing.allocator);
    defer after_reset.deinit();
    try std.testing.expectEqual(@as(usize, 0), after_reset.leases.len);
}
