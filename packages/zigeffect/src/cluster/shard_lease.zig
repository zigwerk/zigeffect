const std = @import("std");
const runner = @import("runner.zig");
const runner_storage = @import("runner_storage.zig");

pub const Allocator = std.mem.Allocator;
pub const RunnerAddress = runner.RunnerAddress;
pub const ShardId = runner_storage.ShardId;
pub const RunnerStorage = runner_storage.RunnerStorage;
pub const RunnerLeaseTtlMs = runner_storage.RunnerLeaseTtlMs;
pub const ShardLease = runner_storage.ShardLease;
pub const RunnerLeaseBatch = runner_storage.RunnerLeaseBatch;

pub const ShardLeaseManagerError = error{
    InvalidLeaseOptions,
    ShardAlreadyOwned,
    ShardNotOwned,
    RunnerStillAlive,
};

pub const ShardLeaseManagerOptions = struct {
    ttl_ms: RunnerLeaseTtlMs,
    refresh_interval_ms: u64,
};

pub const ShardLeaseRefreshReport = struct {
    refreshed: usize = 0,
    reacquired: usize = 0,
    expired: usize = 0,
    conflicts: usize = 0,
};

pub const ShardLeaseRecoveryReport = struct {
    dead_runner: RunnerAddress,
    recovered_by: RunnerAddress,
    released: usize,
    at_ms: u64,
};

pub const ShardHandoffReport = struct {
    shard_id: ShardId,
    from: RunnerAddress,
    to: RunnerAddress,
    released_at_ms: u64,
};

pub const LocalShardLeaseManager = struct {
    allocator: Allocator,
    storage: RunnerStorage,
    owner: RunnerAddress,
    options: ShardLeaseManagerOptions,
    owned_leases: std.ArrayList(ShardLease) = .empty,

    pub fn init(allocator: Allocator, storage: RunnerStorage, owner: RunnerAddress, options: ShardLeaseManagerOptions) ShardLeaseManagerError!LocalShardLeaseManager {
        try validateOptions(options);
        return .{
            .allocator = allocator,
            .storage = storage,
            .owner = owner,
            .options = options,
        };
    }

    pub fn deinit(self: *LocalShardLeaseManager) void {
        self.owned_leases.deinit(self.allocator);
    }
};

pub fn shardLeaseNextRefreshAt(lease: ShardLease, options: ShardLeaseManagerOptions) u64 {
    return lease.refreshed_at_ms +| options.refresh_interval_ms;
}

pub fn shardLeaseRefreshDue(lease: ShardLease, options: ShardLeaseManagerOptions, now_ms: u64) bool {
    return now_ms >= shardLeaseNextRefreshAt(lease, options);
}

fn validateOptions(options: ShardLeaseManagerOptions) ShardLeaseManagerError!void {
    if (options.ttl_ms == 0) return error.InvalidLeaseOptions;
    if (options.refresh_interval_ms == 0) return error.InvalidLeaseOptions;
    if (options.refresh_interval_ms >= options.ttl_ms) return error.InvalidLeaseOptions;
}
