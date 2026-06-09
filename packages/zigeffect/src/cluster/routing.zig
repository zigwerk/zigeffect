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

    pub fn reloadLocal(allocator: Allocator, routing_snapshot: ShardRoutingSnapshot) (Allocator.Error || ShardRoutingError)!ShardRoutingTable {
        return initLocal(allocator, .{
            .shard_count = routing_snapshot.shard_count,
            .version = routing_snapshot.version,
        });
    }

    pub fn deinit(self: *ShardRoutingTable) void {
        self.entries.deinit(self.allocator);
    }

    pub fn shardCount(self: *const ShardRoutingTable) ShardCount {
        return @intCast(self.entries.items.len);
    }

    pub fn version(self: *const ShardRoutingTable) ShardRoutingVersion {
        return self.version_value;
    }

    pub fn route(self: *const ShardRoutingTable, address: EntityAddress) ShardRoutingError!ShardRoute {
        const shard_id = try shardIdForAddress(address, self.shardCount());
        return .{
            .shard_id = shard_id,
            .target = try self.routeShard(shard_id),
        };
    }

    pub fn routeShard(self: *const ShardRoutingTable, shard_id: ShardId) ShardRoutingError!ShardRouteTarget {
        for (self.entries.items) |entry| {
            if (entry.shard_id == shard_id) return entry.target;
        }
        return error.ShardNotFound;
    }

    pub fn snapshot(self: *const ShardRoutingTable) ShardRoutingSnapshot {
        return .{
            .shard_count = self.shardCount(),
            .version = self.version_value,
        };
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
