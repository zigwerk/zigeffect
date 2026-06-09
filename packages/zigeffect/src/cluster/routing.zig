const std = @import("std");
const identity = @import("identity.zig");

pub const Allocator = std.mem.Allocator;
pub const EntityId = identity.EntityId;
pub const EntityAddress = identity.EntityAddress;
pub const ShardId = u64;
pub const ShardCount = u32;
pub const ShardRoutingVersion = u64;

pub const ShardRoutingError = error{
    InvalidShardCount,
    ShardNotFound,
};

pub const ShardRouteTarget = enum { local };

pub const ShardRouteEntry = struct {
    shard_id: ShardId,
    target: ShardRouteTarget = .local,
};

pub const ShardRoute = struct {
    shard_id: ShardId,
    target: ShardRouteTarget,
};

pub const ShardRoutingOptions = struct {
    shard_count: ShardCount,
    version: ShardRoutingVersion = 1,
};

pub const ShardRoutingSnapshot = struct {
    shard_count: ShardCount,
    version: ShardRoutingVersion,
};

pub const ShardRoutingTable = struct {
    allocator: Allocator,
    entries: std.ArrayList(ShardRouteEntry) = .empty,
    version_value: ShardRoutingVersion = 1,

    pub fn initLocal(allocator: Allocator, options: ShardRoutingOptions) (Allocator.Error || ShardRoutingError)!ShardRoutingTable {
        if (options.shard_count == 0) return error.InvalidShardCount;
        var table = ShardRoutingTable{
            .allocator = allocator,
            .version_value = options.version,
        };
        errdefer table.deinit();

        try table.entries.ensureTotalCapacity(allocator, @intCast(options.shard_count));
        var shard_id: ShardId = 0;
        while (shard_id < @as(ShardId, options.shard_count)) : (shard_id += 1) {
            table.entries.appendAssumeCapacity(.{ .shard_id = shard_id });
        }
        return table;
    }

    pub fn deinit(self: *ShardRoutingTable) void {
        self.entries.deinit(self.allocator);
    }
};

pub fn entityShardHash(entity_id: EntityId) u64 {
    var hasher = std.hash.Fnv1a_64.init();
    var id_buf: [8]u8 = undefined;
    std.mem.writeInt(u64, &id_buf, entity_id, .little);
    hasher.update("zigeffect.cluster.shard.v1:");
    hasher.update(&id_buf);
    return hasher.final();
}

pub fn shardIdForEntityId(entity_id: EntityId, shard_count: ShardCount) ShardRoutingError!ShardId {
    if (shard_count == 0) return error.InvalidShardCount;
    return entityShardHash(entity_id) % @as(ShardId, shard_count);
}

pub fn shardIdForAddress(address: EntityAddress, shard_count: ShardCount) ShardRoutingError!ShardId {
    return shardIdForEntityId(address.id, shard_count);
}
