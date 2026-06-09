const std = @import("std");
const routing = @import("routing.zig");
const runner = @import("runner.zig");

pub const Allocator = std.mem.Allocator;
pub const ShardId = routing.ShardId;
pub const RunnerAddress = runner.RunnerAddress;
pub const RunnerStorageLeaseId = u64;
pub const RunnerLeaseTtlMs = u64;

pub const ShardLease = struct {
    shard_id: ShardId,
    owner: RunnerAddress,
    acquired_at_ms: u64,
    refreshed_at_ms: u64,
    expires_at_ms: u64,
    version: u64,
};

pub const RunnerLeaseAcquire = struct {
    shard_id: ShardId,
    owner: RunnerAddress,
    now_ms: u64,
    ttl_ms: RunnerLeaseTtlMs,
};

pub const RunnerLeaseRefresh = struct {
    shard_id: ShardId,
    owner: RunnerAddress,
    now_ms: u64,
    ttl_ms: RunnerLeaseTtlMs,
};

pub const RunnerLeaseRelease = struct {
    shard_id: ShardId,
    owner: RunnerAddress,
};

pub const RunnerLeaseBatch = struct {
    allocator: Allocator,
    leases: []ShardLease,

    pub fn deinit(self: *RunnerLeaseBatch) void {
        self.allocator.free(self.leases);
    }
};

pub const RunnerStorageError = error{
    InvalidLeaseTtl,
    LeaseConflict,
    LeaseNotFound,
    LeaseNotOwned,
    LeaseExpired,
    CorruptLeaseFile,
};

pub const RunnerStorage = struct {
    context: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        acquire: *const fn (*anyopaque, RunnerLeaseAcquire) anyerror!ShardLease,
        refresh: *const fn (*anyopaque, RunnerLeaseRefresh) anyerror!ShardLease,
        release: *const fn (*anyopaque, RunnerLeaseRelease) anyerror!void,
        release_all: *const fn (*anyopaque, RunnerAddress) anyerror!usize,
        lease: *const fn (*anyopaque, ShardId) anyerror!?ShardLease,
        leases: *const fn (*anyopaque, Allocator) anyerror!RunnerLeaseBatch,
        reset: *const fn (*anyopaque) void,
    };

    pub fn acquire(self: RunnerStorage, request: RunnerLeaseAcquire) anyerror!ShardLease {
        return self.vtable.acquire(self.context, request);
    }

    pub fn refresh(self: RunnerStorage, request: RunnerLeaseRefresh) anyerror!ShardLease {
        return self.vtable.refresh(self.context, request);
    }

    pub fn release(self: RunnerStorage, request: RunnerLeaseRelease) anyerror!void {
        return self.vtable.release(self.context, request);
    }

    pub fn releaseAll(self: RunnerStorage, owner: RunnerAddress) anyerror!usize {
        return self.vtable.release_all(self.context, owner);
    }

    pub fn lease(self: RunnerStorage, shard_id: ShardId) anyerror!?ShardLease {
        return self.vtable.lease(self.context, shard_id);
    }

    pub fn leases(self: RunnerStorage, allocator: Allocator) anyerror!RunnerLeaseBatch {
        return self.vtable.leases(self.context, allocator);
    }

    pub fn reset(self: RunnerStorage) void {
        self.vtable.reset(self.context);
    }
};

pub const InMemoryRunnerStorage = struct {
    allocator: Allocator,
    leases_list: std.ArrayList(ShardLease) = .empty,

    pub fn init(allocator: Allocator) InMemoryRunnerStorage {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *InMemoryRunnerStorage) void {
        self.leases_list.deinit(self.allocator);
    }

    pub fn asRunnerStorage(self: *InMemoryRunnerStorage) RunnerStorage {
        return .{
            .context = self,
            .vtable = &in_memory_vtable,
        };
    }

    pub fn acquire(self: *InMemoryRunnerStorage, request: RunnerLeaseAcquire) (Allocator.Error || RunnerStorageError)!ShardLease {
        const expires_at_ms = try leaseExpiresAt(request.now_ms, request.ttl_ms);
        if (self.findLeaseIndex(request.shard_id) != null) return error.LeaseConflict;

        try self.leases_list.ensureUnusedCapacity(self.allocator, 1);
        const lease_record: ShardLease = .{
            .shard_id = request.shard_id,
            .owner = request.owner,
            .acquired_at_ms = request.now_ms,
            .refreshed_at_ms = request.now_ms,
            .expires_at_ms = expires_at_ms,
            .version = 1,
        };
        self.leases_list.appendAssumeCapacity(lease_record);
        return lease_record;
    }

    pub fn refresh(self: *InMemoryRunnerStorage, request: RunnerLeaseRefresh) (Allocator.Error || RunnerStorageError)!ShardLease {
        _ = self;
        _ = request;
        return error.LeaseNotFound;
    }

    pub fn release(self: *InMemoryRunnerStorage, request: RunnerLeaseRelease) RunnerStorageError!void {
        _ = self;
        _ = request;
        return error.LeaseNotFound;
    }

    pub fn releaseAll(self: *InMemoryRunnerStorage, owner: RunnerAddress) usize {
        _ = self;
        _ = owner;
        return 0;
    }

    pub fn lease(self: *const InMemoryRunnerStorage, shard_id: ShardId) ?ShardLease {
        const index = self.findLeaseIndex(shard_id) orelse return null;
        return self.leases_list.items[index];
    }

    pub fn leases(self: *const InMemoryRunnerStorage, allocator: Allocator) Allocator.Error!RunnerLeaseBatch {
        const copied = try allocator.dupe(ShardLease, self.leases_list.items);
        return .{
            .allocator = allocator,
            .leases = copied,
        };
    }

    pub fn reset(self: *InMemoryRunnerStorage) void {
        self.leases_list.clearRetainingCapacity();
    }

    fn findLeaseIndex(self: *const InMemoryRunnerStorage, shard_id: ShardId) ?usize {
        for (self.leases_list.items, 0..) |lease_record, index| {
            if (lease_record.shard_id == shard_id) return index;
        }
        return null;
    }
};

pub const FileRunnerStorage = struct {};

fn leaseExpiresAt(now_ms: u64, ttl_ms: RunnerLeaseTtlMs) RunnerStorageError!u64 {
    if (ttl_ms == 0) return error.InvalidLeaseTtl;
    return std.math.add(u64, now_ms, ttl_ms) catch error.InvalidLeaseTtl;
}

fn inMemoryAcquire(context: *anyopaque, request: RunnerLeaseAcquire) anyerror!ShardLease {
    const storage: *InMemoryRunnerStorage = @ptrCast(@alignCast(context));
    return storage.acquire(request);
}

fn inMemoryRefresh(context: *anyopaque, request: RunnerLeaseRefresh) anyerror!ShardLease {
    const storage: *InMemoryRunnerStorage = @ptrCast(@alignCast(context));
    return storage.refresh(request);
}

fn inMemoryRelease(context: *anyopaque, request: RunnerLeaseRelease) anyerror!void {
    const storage: *InMemoryRunnerStorage = @ptrCast(@alignCast(context));
    return storage.release(request);
}

fn inMemoryReleaseAll(context: *anyopaque, owner: RunnerAddress) anyerror!usize {
    const storage: *InMemoryRunnerStorage = @ptrCast(@alignCast(context));
    return storage.releaseAll(owner);
}

fn inMemoryLease(context: *anyopaque, shard_id: ShardId) anyerror!?ShardLease {
    const storage: *InMemoryRunnerStorage = @ptrCast(@alignCast(context));
    return storage.lease(shard_id);
}

fn inMemoryLeases(context: *anyopaque, allocator: Allocator) anyerror!RunnerLeaseBatch {
    const storage: *InMemoryRunnerStorage = @ptrCast(@alignCast(context));
    return storage.leases(allocator);
}

fn inMemoryReset(context: *anyopaque) void {
    const storage: *InMemoryRunnerStorage = @ptrCast(@alignCast(context));
    storage.reset();
}

const in_memory_vtable: RunnerStorage.VTable = .{
    .acquire = inMemoryAcquire,
    .refresh = inMemoryRefresh,
    .release = inMemoryRelease,
    .release_all = inMemoryReleaseAll,
    .lease = inMemoryLease,
    .leases = inMemoryLeases,
    .reset = inMemoryReset,
};
