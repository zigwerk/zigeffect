const std = @import("std");
const runner = @import("runner.zig");
const runner_storage = @import("runner_storage.zig");

pub const Allocator = std.mem.Allocator;
pub const RunnerAddress = runner.RunnerAddress;
pub const RunnerStorage = runner_storage.RunnerStorage;
pub const ShardId = runner_storage.ShardId;
pub const ShardLease = runner_storage.ShardLease;
pub const ShardLeaseEpoch = runner_storage.ShardLeaseEpoch;

pub const FenceValidationError = error{
    StaleShardFence,
};

pub const ShardLeaseFence = struct {
    shard_id: ShardId,
    owner: RunnerAddress,
    epoch: ShardLeaseEpoch,
};

pub fn fenceFromLease(lease: ShardLease) ShardLeaseFence {
    return .{
        .shard_id = lease.shard_id,
        .owner = lease.owner,
        .epoch = lease.epoch,
    };
}

pub fn validateShardFence(storage: RunnerStorage, fence: ShardLeaseFence) anyerror!void {
    const current = (try storage.lease(fence.shard_id)) orelse return error.StaleShardFence;
    if (!current.owner.eql(fence.owner)) return error.StaleShardFence;
    if (current.epoch != fence.epoch) return error.StaleShardFence;
}

pub fn formatShardFenceDiagnostic(
    allocator: Allocator,
    fence: ShardLeaseFence,
    current: ?ShardLease,
) Allocator.Error![]const u8 {
    if (current) |lease| {
        return std.fmt.allocPrint(
            allocator,
            "shard={d} fence_owner={d}/{d} fence_epoch={d} current_owner={d}/{d} current_epoch={d}",
            .{
                fence.shard_id,
                fence.owner.machine_id,
                fence.owner.runner_id,
                fence.epoch,
                lease.owner.machine_id,
                lease.owner.runner_id,
                lease.epoch,
            },
        );
    }
    return std.fmt.allocPrint(
        allocator,
        "shard={d} fence_owner={d}/{d} fence_epoch={d} current_owner=none current_epoch=none",
        .{
            fence.shard_id,
            fence.owner.machine_id,
            fence.owner.runner_id,
            fence.epoch,
        },
    );
}
