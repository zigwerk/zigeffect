const std = @import("std");

pub const EntityId = u64;

pub const EntityType = struct {
    name: []const u8,

    pub fn init(name: []const u8) EntityType {
        return .{ .name = name };
    }
};

pub const EntityAddress = struct {
    entity_type: EntityType,
    id: EntityId,

    pub fn eql(self: EntityAddress, other: EntityAddress) bool {
        return self.id == other.id and std.mem.eql(u8, self.entity_type.name, other.entity_type.name);
    }
};

pub fn entityId(entity_type: []const u8, key: []const u8) EntityId {
    var hasher = std.hash.Fnv1a_64.init();
    hasher.update(entity_type);
    hasher.update(":");
    hasher.update(key);
    return hasher.final();
}

pub fn entityAddress(entity_type: []const u8, key: []const u8) EntityAddress {
    return .{
        .entity_type = EntityType.init(entity_type),
        .id = entityId(entity_type, key),
    };
}
