const std = @import("std");
const routing = @import("routing.zig");
const runner = @import("runner.zig");

pub const Allocator = std.mem.Allocator;
pub const ShardId = routing.ShardId;
pub const RunnerAddress = runner.RunnerAddress;
pub const RunnerStorageLeaseId = u64;
pub const RunnerLeaseTtlMs = u64;
pub const ShardLeaseEpoch = u64;
pub const runner_lease_schema = "zigeffect.cluster.runner-lease.v1";
pub const runner_lease_schema_version: u32 = 1;

pub const ShardLease = struct {
    shard_id: ShardId,
    owner: RunnerAddress,
    acquired_at_ms: u64,
    refreshed_at_ms: u64,
    expires_at_ms: u64,
    epoch: ShardLeaseEpoch = 1,
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
        if (self.findLeaseIndex(request.shard_id)) |index| {
            const current = self.leases_list.items[index];
            if (!leaseExpired(current, request.now_ms)) return error.LeaseConflict;
            const replacement: ShardLease = .{
                .shard_id = request.shard_id,
                .owner = request.owner,
                .acquired_at_ms = request.now_ms,
                .refreshed_at_ms = request.now_ms,
                .expires_at_ms = expires_at_ms,
                .epoch = current.epoch + 1,
                .version = current.version + 1,
            };
            self.leases_list.items[index] = replacement;
            return replacement;
        }

        try self.leases_list.ensureUnusedCapacity(self.allocator, 1);
        const lease_record: ShardLease = .{
            .shard_id = request.shard_id,
            .owner = request.owner,
            .acquired_at_ms = request.now_ms,
            .refreshed_at_ms = request.now_ms,
            .expires_at_ms = expires_at_ms,
            .epoch = 1,
            .version = 1,
        };
        self.leases_list.appendAssumeCapacity(lease_record);
        return lease_record;
    }

    pub fn refresh(self: *InMemoryRunnerStorage, request: RunnerLeaseRefresh) (Allocator.Error || RunnerStorageError)!ShardLease {
        const expires_at_ms = try leaseExpiresAt(request.now_ms, request.ttl_ms);
        const index = self.findLeaseIndex(request.shard_id) orelse return error.LeaseNotFound;
        const current = self.leases_list.items[index];
        if (!current.owner.eql(request.owner)) return error.LeaseNotOwned;
        if (leaseExpired(current, request.now_ms)) return error.LeaseExpired;

        const refreshed: ShardLease = .{
            .shard_id = current.shard_id,
            .owner = current.owner,
            .acquired_at_ms = current.acquired_at_ms,
            .refreshed_at_ms = request.now_ms,
            .expires_at_ms = expires_at_ms,
            .epoch = current.epoch,
            .version = current.version + 1,
        };
        self.leases_list.items[index] = refreshed;
        return refreshed;
    }

    pub fn release(self: *InMemoryRunnerStorage, request: RunnerLeaseRelease) RunnerStorageError!void {
        const index = self.findLeaseIndex(request.shard_id) orelse return error.LeaseNotFound;
        const current = self.leases_list.items[index];
        if (!current.owner.eql(request.owner)) return error.LeaseNotOwned;
        _ = self.leases_list.orderedRemove(index);
    }

    pub fn releaseAll(self: *InMemoryRunnerStorage, owner: RunnerAddress) usize {
        var released: usize = 0;
        var index: usize = 0;
        while (index < self.leases_list.items.len) {
            if (self.leases_list.items[index].owner.eql(owner)) {
                _ = self.leases_list.orderedRemove(index);
                released += 1;
            } else {
                index += 1;
            }
        }
        return released;
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

pub const FileRunnerStorageOptions = struct {
    lease_prefix: []const u8 = "runner-shard-",
    lease_suffix: []const u8 = ".json",
    max_lease_file_bytes: usize = 64 * 1024,
};

pub const FileRunnerStorage = struct {
    allocator: Allocator,
    io: std.Io,
    dir: *std.Io.Dir,
    options: FileRunnerStorageOptions,

    pub fn open(allocator: Allocator, io: std.Io, dir: *std.Io.Dir, options: FileRunnerStorageOptions) !FileRunnerStorage {
        return .{
            .allocator = allocator,
            .io = io,
            .dir = dir,
            .options = options,
        };
    }

    pub fn deinit(self: *FileRunnerStorage) void {
        _ = self;
    }

    pub fn asRunnerStorage(self: *FileRunnerStorage) RunnerStorage {
        return .{
            .context = self,
            .vtable = &file_vtable,
        };
    }

    pub fn acquire(self: *FileRunnerStorage, request: RunnerLeaseAcquire) !ShardLease {
        const expires_at_ms = try leaseExpiresAt(request.now_ms, request.ttl_ms);
        const name = try runnerLeaseFileName(self.allocator, self.options, request.shard_id);
        defer self.allocator.free(name);

        const candidate: ShardLease = .{
            .shard_id = request.shard_id,
            .owner = request.owner,
            .acquired_at_ms = request.now_ms,
            .refreshed_at_ms = request.now_ms,
            .expires_at_ms = expires_at_ms,
            .epoch = 1,
            .version = 1,
        };

        self.writeLeaseFileExclusive(name, candidate) catch |err| switch (err) {
            error.PathAlreadyExists => return try self.acquireExistingLeaseFile(name, request, expires_at_ms),
            else => return err,
        };
        return candidate;
    }

    fn acquireExistingLeaseFile(self: *FileRunnerStorage, name: []const u8, request: RunnerLeaseAcquire, expires_at_ms: u64) !ShardLease {
        if (try self.lease(request.shard_id)) |current| {
            if (!leaseExpired(current, request.now_ms)) return error.LeaseConflict;
            self.dir.deleteFile(self.io, name) catch |err| switch (err) {
                error.FileNotFound => {},
                else => return err,
            };
            const replacement: ShardLease = .{
                .shard_id = request.shard_id,
                .owner = request.owner,
                .acquired_at_ms = request.now_ms,
                .refreshed_at_ms = request.now_ms,
                .expires_at_ms = expires_at_ms,
                .epoch = current.epoch + 1,
                .version = current.version + 1,
            };
            self.writeLeaseFileExclusive(name, replacement) catch |err| switch (err) {
                error.PathAlreadyExists => return error.LeaseConflict,
                else => return err,
            };
            return replacement;
        }

        const candidate: ShardLease = .{
            .shard_id = request.shard_id,
            .owner = request.owner,
            .acquired_at_ms = request.now_ms,
            .refreshed_at_ms = request.now_ms,
            .expires_at_ms = expires_at_ms,
            .epoch = 1,
            .version = 1,
        };
        self.writeLeaseFileExclusive(name, candidate) catch |err| switch (err) {
            error.PathAlreadyExists => return error.LeaseConflict,
            else => return err,
        };
        return candidate;
    }

    pub fn refresh(self: *FileRunnerStorage, request: RunnerLeaseRefresh) !ShardLease {
        const expires_at_ms = try leaseExpiresAt(request.now_ms, request.ttl_ms);
        const name = try runnerLeaseFileName(self.allocator, self.options, request.shard_id);
        defer self.allocator.free(name);

        const current = (try self.readLeaseFile(name)) orelse return error.LeaseNotFound;
        if (!current.owner.eql(request.owner)) return error.LeaseNotOwned;
        if (leaseExpired(current, request.now_ms)) return error.LeaseExpired;

        const refreshed: ShardLease = .{
            .shard_id = current.shard_id,
            .owner = current.owner,
            .acquired_at_ms = current.acquired_at_ms,
            .refreshed_at_ms = request.now_ms,
            .expires_at_ms = expires_at_ms,
            .epoch = current.epoch,
            .version = current.version + 1,
        };
        try self.writeLeaseFileAtomic(name, refreshed);
        return refreshed;
    }

    pub fn release(self: *FileRunnerStorage, request: RunnerLeaseRelease) !void {
        const name = try runnerLeaseFileName(self.allocator, self.options, request.shard_id);
        defer self.allocator.free(name);

        const current = (try self.readLeaseFile(name)) orelse return error.LeaseNotFound;
        if (!current.owner.eql(request.owner)) return error.LeaseNotOwned;
        self.dir.deleteFile(self.io, name) catch |err| switch (err) {
            error.FileNotFound => return error.LeaseNotFound,
            else => return err,
        };
    }

    pub fn releaseAll(self: *FileRunnerStorage, owner: RunnerAddress) !usize {
        var released: usize = 0;
        var iterator = self.dir.iterate();
        while (try iterator.next(self.io)) |entry| {
            if (shardIdFromLeaseFileName(self.options, entry.name) == null) continue;
            const current = (try self.readLeaseFile(entry.name)) orelse continue;
            if (!current.owner.eql(owner)) continue;
            self.dir.deleteFile(self.io, entry.name) catch |err| switch (err) {
                error.FileNotFound => continue,
                else => return err,
            };
            released += 1;
        }
        return released;
    }

    pub fn lease(self: *FileRunnerStorage, shard_id: ShardId) !?ShardLease {
        const name = try runnerLeaseFileName(self.allocator, self.options, shard_id);
        defer self.allocator.free(name);
        return self.readLeaseFile(name);
    }

    pub fn leases(self: *FileRunnerStorage, allocator: Allocator) !RunnerLeaseBatch {
        var lease_items: std.ArrayList(ShardLease) = .empty;
        errdefer lease_items.deinit(allocator);

        var iterator = self.dir.iterate();
        while (try iterator.next(self.io)) |entry| {
            if (shardIdFromLeaseFileName(self.options, entry.name) == null) continue;
            if (try self.readLeaseFile(entry.name)) |lease_record| {
                try lease_items.append(allocator, lease_record);
            }
        }

        return .{
            .allocator = allocator,
            .leases = try lease_items.toOwnedSlice(allocator),
        };
    }

    pub fn reset(self: *FileRunnerStorage) void {
        var iterator = self.dir.iterate();
        while (iterator.next(self.io) catch null) |entry| {
            if (shardIdFromLeaseFileName(self.options, entry.name) == null) continue;
            self.dir.deleteFile(self.io, entry.name) catch {};
        }
    }

    fn readLeaseFile(self: *FileRunnerStorage, name: []const u8) !?ShardLease {
        const content = self.dir.readFileAlloc(
            self.io,
            name,
            self.allocator,
            std.Io.Limit.limited(self.options.max_lease_file_bytes),
        ) catch |err| switch (err) {
            error.FileNotFound => return null,
            else => return err,
        };
        defer self.allocator.free(content);

        return try parseShardLeaseJson(self.allocator, content);
    }

    fn writeLeaseFileExclusive(self: *FileRunnerStorage, name: []const u8, lease_record: ShardLease) !void {
        const content = try formatShardLeaseJson(self.allocator, lease_record);
        defer self.allocator.free(content);

        const file = try self.dir.createFile(self.io, name, .{ .exclusive = true });
        defer file.close(self.io);
        try file.writeStreamingAll(self.io, content);
    }

    fn writeLeaseFileAtomic(self: *FileRunnerStorage, name: []const u8, lease_record: ShardLease) !void {
        const content = try formatShardLeaseJson(self.allocator, lease_record);
        defer self.allocator.free(content);

        var file = try self.dir.createFileAtomic(self.io, name, .{ .replace = true });
        defer file.deinit(self.io);
        try file.file.writeStreamingAll(self.io, content);
        try file.replace(self.io);
    }
};

const ShardLeaseJson = struct {
    schema: []const u8,
    schema_version: u32,
    shard_id: ShardId,
    machine_id: runner.MachineId,
    runner_id: runner.RunnerId,
    acquired_at_ms: u64,
    refreshed_at_ms: u64,
    expires_at_ms: u64,
    epoch: ?ShardLeaseEpoch = null,
    version: u64,
};

pub fn runnerLeaseFileName(allocator: Allocator, options: FileRunnerStorageOptions, shard_id: ShardId) Allocator.Error![]const u8 {
    return std.fmt.allocPrint(allocator, "{s}{d}{s}", .{ options.lease_prefix, shard_id, options.lease_suffix });
}

fn shardIdFromLeaseFileName(options: FileRunnerStorageOptions, name: []const u8) ?ShardId {
    if (!std.mem.startsWith(u8, name, options.lease_prefix)) return null;
    if (!std.mem.endsWith(u8, name, options.lease_suffix)) return null;
    const start = options.lease_prefix.len;
    const end = name.len - options.lease_suffix.len;
    if (end <= start) return null;
    return std.fmt.parseUnsigned(ShardId, name[start..end], 10) catch null;
}

pub fn formatShardLeaseJson(allocator: Allocator, lease_record: ShardLease) Allocator.Error![]const u8 {
    return std.fmt.allocPrint(
        allocator,
        "{{\"schema\":\"{s}\",\"schema_version\":{d},\"shard_id\":{d},\"machine_id\":{d},\"runner_id\":{d},\"acquired_at_ms\":{d},\"refreshed_at_ms\":{d},\"expires_at_ms\":{d},\"epoch\":{d},\"version\":{d}}}",
        .{
            runner_lease_schema,
            runner_lease_schema_version,
            lease_record.shard_id,
            lease_record.owner.machine_id,
            lease_record.owner.runner_id,
            lease_record.acquired_at_ms,
            lease_record.refreshed_at_ms,
            lease_record.expires_at_ms,
            lease_record.epoch,
            lease_record.version,
        },
    );
}

pub fn parseShardLeaseJson(allocator: Allocator, content: []const u8) (Allocator.Error || RunnerStorageError)!ShardLease {
    var parsed = std.json.parseFromSlice(ShardLeaseJson, allocator, content, .{ .ignore_unknown_fields = true }) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        else => return error.CorruptLeaseFile,
    };
    defer parsed.deinit();

    if (!std.mem.eql(u8, parsed.value.schema, runner_lease_schema)) return error.CorruptLeaseFile;
    if (parsed.value.schema_version != runner_lease_schema_version) return error.CorruptLeaseFile;
    return .{
        .shard_id = parsed.value.shard_id,
        .owner = .{
            .machine_id = parsed.value.machine_id,
            .runner_id = parsed.value.runner_id,
        },
        .acquired_at_ms = parsed.value.acquired_at_ms,
        .refreshed_at_ms = parsed.value.refreshed_at_ms,
        .expires_at_ms = parsed.value.expires_at_ms,
        .epoch = parsed.value.epoch orelse parsed.value.version,
        .version = parsed.value.version,
    };
}

fn leaseExpiresAt(now_ms: u64, ttl_ms: RunnerLeaseTtlMs) RunnerStorageError!u64 {
    if (ttl_ms == 0) return error.InvalidLeaseTtl;
    return std.math.add(u64, now_ms, ttl_ms) catch error.InvalidLeaseTtl;
}

fn leaseExpired(lease_record: ShardLease, now_ms: u64) bool {
    return lease_record.expires_at_ms <= now_ms;
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

fn fileAcquire(context: *anyopaque, request: RunnerLeaseAcquire) anyerror!ShardLease {
    const storage: *FileRunnerStorage = @ptrCast(@alignCast(context));
    return storage.acquire(request);
}

fn fileRefresh(context: *anyopaque, request: RunnerLeaseRefresh) anyerror!ShardLease {
    const storage: *FileRunnerStorage = @ptrCast(@alignCast(context));
    return storage.refresh(request);
}

fn fileRelease(context: *anyopaque, request: RunnerLeaseRelease) anyerror!void {
    const storage: *FileRunnerStorage = @ptrCast(@alignCast(context));
    return storage.release(request);
}

fn fileReleaseAll(context: *anyopaque, owner: RunnerAddress) anyerror!usize {
    const storage: *FileRunnerStorage = @ptrCast(@alignCast(context));
    return storage.releaseAll(owner);
}

fn fileLease(context: *anyopaque, shard_id: ShardId) anyerror!?ShardLease {
    const storage: *FileRunnerStorage = @ptrCast(@alignCast(context));
    return storage.lease(shard_id);
}

fn fileLeases(context: *anyopaque, allocator: Allocator) anyerror!RunnerLeaseBatch {
    const storage: *FileRunnerStorage = @ptrCast(@alignCast(context));
    return storage.leases(allocator);
}

fn fileReset(context: *anyopaque) void {
    const storage: *FileRunnerStorage = @ptrCast(@alignCast(context));
    storage.reset();
}

const file_vtable: RunnerStorage.VTable = .{
    .acquire = fileAcquire,
    .refresh = fileRefresh,
    .release = fileRelease,
    .release_all = fileReleaseAll,
    .lease = fileLease,
    .leases = fileLeases,
    .reset = fileReset,
};
