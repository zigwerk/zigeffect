const std = @import("std");
const envelope = @import("envelope.zig");
const routing = @import("routing.zig");

pub const Allocator = std.mem.Allocator;
pub const MessageCorrelationId = envelope.MessageCorrelationId;
pub const MessageEnvelope = envelope.MessageEnvelope;
pub const ShardCount = routing.ShardCount;
pub const ShardId = routing.ShardId;

pub const LocalClusterError = error{
    InvalidShardCount,
    InvalidRunnerCount,
    InvalidRunnerIndex,
};

pub const ShardBalancePlan = struct {
    allocator: Allocator,
    shards: []ShardId,

    pub fn deinit(self: *ShardBalancePlan) void {
        self.allocator.free(self.shards);
    }
};

pub const LocalClusterRouteResult = struct {
    shard_id: ShardId,
    envelope: MessageEnvelope,
    correlation_id: ?MessageCorrelationId = null,
    duplicate: bool = false,

    pub fn deinit(self: *LocalClusterRouteResult, allocator: Allocator) void {
        envelope.deinitMessageEnvelope(allocator, self.envelope);
    }
};

pub const LocalClusterRouter = struct {};

pub const LocalClusterRunnerOptions = struct {};

pub const LocalClusterRunnerReport = struct {
    refreshed: usize = 0,
    reacquired: usize = 0,
    expired: usize = 0,
    conflicts: usize = 0,
    scanned: usize = 0,
    claimed: usize = 0,
    dispatched: usize = 0,
    replied: usize = 0,
    acked: usize = 0,
    failed: usize = 0,
    skipped: usize = 0,
};

pub const LocalClusterRunner = struct {};

pub const ShardRecoveryPlan = struct {
    allocator: Allocator,
    shards: []ShardId,
    released: usize = 0,
    acquired: usize = 0,

    pub fn deinit(self: *ShardRecoveryPlan) void {
        self.allocator.free(self.shards);
    }
};

pub fn balancedShardPlan(
    allocator: Allocator,
    shard_count: ShardCount,
    runner_index: usize,
    runner_count: usize,
) (Allocator.Error || LocalClusterError)!ShardBalancePlan {
    if (shard_count == 0) return error.InvalidShardCount;
    if (runner_count == 0) return error.InvalidRunnerCount;
    if (runner_index >= runner_count) return error.InvalidRunnerIndex;

    var shards = std.ArrayList(ShardId).empty;
    errdefer shards.deinit(allocator);

    var shard_id: ShardId = 0;
    while (shard_id < @as(ShardId, shard_count)) : (shard_id += 1) {
        if (shard_id % @as(ShardId, @intCast(runner_count)) != @as(ShardId, @intCast(runner_index))) continue;
        try shards.append(allocator, shard_id);
    }

    return .{
        .allocator = allocator,
        .shards = try shards.toOwnedSlice(allocator),
    };
}
