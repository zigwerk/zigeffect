const std = @import("std");
const entity = @import("entity.zig");
const envelope = @import("envelope.zig");
const identity = @import("identity.zig");
const message_storage = @import("message_storage.zig");
const routing = @import("routing.zig");
const shard_lease = @import("shard_lease.zig");

pub const Allocator = std.mem.Allocator;
pub const EntityAddress = identity.EntityAddress;
pub const MessageCorrelationId = envelope.MessageCorrelationId;
pub const MessageEnvelope = envelope.MessageEnvelope;
pub const MessageStorage = message_storage.MessageStorage;
pub const ShardCount = routing.ShardCount;
pub const ShardId = routing.ShardId;
pub const ShardLease = shard_lease.ShardLease;
pub const LocalShardLeaseManager = shard_lease.LocalShardLeaseManager;
pub const LocalEntityRuntimeOptions = entity.LocalEntityRuntimeOptions;

pub const ClusterRuntimeError = error{
    RuntimeShuttingDown,
    ShardNotOwned,
    UnsupportedMessageKind,
    MissingReply,
};

pub const ClusterRuntimeOptions = struct {
    shard_count: ShardCount,
    entity_runtime_options: LocalEntityRuntimeOptions = .{},
};

pub const ClusterProcessReport = struct {
    scanned: usize = 0,
    claimed: usize = 0,
    dispatched: usize = 0,
    replied: usize = 0,
    acked: usize = 0,
    failed: usize = 0,
    skipped: usize = 0,
};

pub const ClusterShutdownReport = struct {
    released_shards: usize = 0,
};

pub const ClusterAsk = struct {
    envelope: MessageEnvelope,
    correlation_id: MessageCorrelationId,
    duplicate: bool = false,

    pub fn deinit(self: *ClusterAsk, allocator: Allocator) void {
        envelope.deinitMessageEnvelope(allocator, self.envelope);
    }
};

pub const ClusterEntityRef = struct {
    address: EntityAddress,
    runtime: *ClusterRuntime,
};

pub const ClusterRuntime = struct {
    allocator: Allocator,
    message_storage: MessageStorage,
    lease_manager: *LocalShardLeaseManager,
    local_runtime: entity.LocalEntityRuntime,
    shard_count: ShardCount,
    owned_shards: std.ArrayList(ShardId) = .empty,
    accepting_messages: bool = true,

    pub fn init(
        allocator: Allocator,
        storage: MessageStorage,
        lease_manager: *LocalShardLeaseManager,
        options: ClusterRuntimeOptions,
    ) routing.ShardRoutingError!ClusterRuntime {
        if (options.shard_count == 0) return error.InvalidShardCount;
        return .{
            .allocator = allocator,
            .message_storage = storage,
            .lease_manager = lease_manager,
            .local_runtime = entity.LocalEntityRuntime.init(allocator, options.entity_runtime_options),
            .shard_count = options.shard_count,
        };
    }

    pub fn deinit(self: *ClusterRuntime) void {
        self.owned_shards.deinit(self.allocator);
        self.local_runtime.deinit();
    }

    pub fn loadOwnedShards(self: *ClusterRuntime) Allocator.Error!usize {
        self.owned_shards.clearRetainingCapacity();
        var leases = try self.lease_manager.ownedLeases(self.allocator);
        defer leases.deinit();
        try self.owned_shards.ensureTotalCapacity(self.allocator, leases.leases.len);
        for (leases.leases) |lease| {
            self.owned_shards.appendAssumeCapacity(lease.shard_id);
        }
        return self.owned_shards.items.len;
    }

    pub fn acquireShard(self: *ClusterRuntime, shard_id: ShardId, now_ms: u64) !ShardLease {
        const lease = try self.lease_manager.acquireShard(shard_id, now_ms);
        errdefer self.lease_manager.releaseShard(shard_id, now_ms) catch {};
        try self.recordOwnedShard(shard_id);
        return lease;
    }

    pub fn releaseShard(self: *ClusterRuntime, shard_id: ShardId, now_ms: u64) !void {
        try self.lease_manager.releaseShard(shard_id, now_ms);
        self.removeOwnedShard(shard_id);
    }

    pub fn ownsShard(self: *const ClusterRuntime, shard_id: ShardId) bool {
        return self.findOwnedShardIndex(shard_id) != null;
    }

    pub fn ownedShardCount(self: *const ClusterRuntime) usize {
        return self.owned_shards.items.len;
    }

    fn recordOwnedShard(self: *ClusterRuntime, shard_id: ShardId) Allocator.Error!void {
        if (self.ownsShard(shard_id)) return;
        try self.owned_shards.append(self.allocator, shard_id);
    }

    fn removeOwnedShard(self: *ClusterRuntime, shard_id: ShardId) void {
        const index = self.findOwnedShardIndex(shard_id) orelse return;
        _ = self.owned_shards.orderedRemove(index);
    }

    fn findOwnedShardIndex(self: *const ClusterRuntime, shard_id: ShardId) ?usize {
        for (self.owned_shards.items, 0..) |owned, index| {
            if (owned == shard_id) return index;
        }
        return null;
    }
};
