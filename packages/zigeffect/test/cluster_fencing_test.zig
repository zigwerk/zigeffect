const std = @import("std");
const fx = @import("zigeffect");

test "cluster fencing public exports are available" {
    try std.testing.expect(@hasDecl(fx.cluster, "fencing"));
    try std.testing.expect(@hasDecl(fx.cluster, "ShardLeaseEpoch"));
    try std.testing.expect(@hasDecl(fx.cluster, "ShardLeaseFence"));
    try std.testing.expect(@hasDecl(fx.cluster, "FenceValidationError"));
    try std.testing.expect(@hasDecl(fx.cluster, "fenceFromLease"));
    try std.testing.expect(@hasDecl(fx.cluster, "validateShardFence"));
    try std.testing.expect(@hasDecl(fx.cluster, "formatShardFenceDiagnostic"));
    try std.testing.expect(@hasDecl(fx, "ShardLeaseFence"));
}

test "shard lease epoch is stable across refresh and increments on reacquire" {
    var storage = fx.InMemoryRunnerStorage.init(std.testing.allocator);
    defer storage.deinit();
    const runner_storage = storage.asRunnerStorage();
    const runner_a = fx.runnerAddress("machine", "runner-a");
    const runner_b = fx.runnerAddress("machine", "runner-b");

    const acquired = try runner_storage.acquire(.{
        .shard_id = 0,
        .owner = runner_a,
        .now_ms = 1_000,
        .ttl_ms = 100,
    });
    try std.testing.expectEqual(@as(fx.ShardLeaseEpoch, 1), acquired.epoch);
    try std.testing.expectEqual(@as(u64, 1), acquired.version);

    const refreshed = try runner_storage.refresh(.{
        .shard_id = 0,
        .owner = runner_a,
        .now_ms = 1_050,
        .ttl_ms = 100,
    });
    try std.testing.expectEqual(@as(fx.ShardLeaseEpoch, 1), refreshed.epoch);
    try std.testing.expectEqual(@as(u64, 2), refreshed.version);

    const reacquired = try runner_storage.acquire(.{
        .shard_id = 0,
        .owner = runner_b,
        .now_ms = 1_150,
        .ttl_ms = 100,
    });
    try std.testing.expectEqual(@as(fx.ShardLeaseEpoch, 2), reacquired.epoch);
    try std.testing.expectEqual(@as(u64, 3), reacquired.version);
}

test "shard fence validation accepts current lease and rejects stale epoch" {
    var storage = fx.InMemoryRunnerStorage.init(std.testing.allocator);
    defer storage.deinit();
    const runner_storage = storage.asRunnerStorage();
    const runner_a = fx.runnerAddress("machine", "runner-a");
    const runner_b = fx.runnerAddress("machine", "runner-b");

    const first = try runner_storage.acquire(.{
        .shard_id = 0,
        .owner = runner_a,
        .now_ms = 1_000,
        .ttl_ms = 100,
    });
    const stale_fence = fx.fenceFromLease(first);
    try fx.validateShardFence(runner_storage, stale_fence);

    _ = try runner_storage.acquire(.{
        .shard_id = 0,
        .owner = runner_b,
        .now_ms = 1_100,
        .ttl_ms = 100,
    });
    try std.testing.expectError(error.StaleShardFence, fx.validateShardFence(runner_storage, stale_fence));
}
