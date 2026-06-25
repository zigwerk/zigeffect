const std = @import("std");

pub const EnvError = error{
    MissingVariable,
};

pub const EnvMap = struct {
    allocator: std.mem.Allocator,
    values: std.StringHashMap([]const u8),

    pub fn init(allocator: std.mem.Allocator) EnvMap {
        return .{
            .allocator = allocator,
            .values = std.StringHashMap([]const u8).init(allocator),
        };
    }

    pub fn deinit(self: *EnvMap) void {
        var iterator = self.values.iterator();
        while (iterator.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.*);
        }
        self.values.deinit();
    }

    pub fn put(self: *EnvMap, name: []const u8, value: []const u8) std.mem.Allocator.Error!void {
        if (self.values.fetchRemove(name)) |old| {
            self.allocator.free(old.key);
            self.allocator.free(old.value);
        }
        try self.values.put(
            try self.allocator.dupe(u8, name),
            try self.allocator.dupe(u8, value),
        );
    }

    pub fn get(self: EnvMap, name: []const u8) ?[]const u8 {
        return self.values.get(name);
    }

    pub fn require(self: EnvMap, name: []const u8) EnvError![]const u8 {
        return self.get(name) orelse EnvError.MissingVariable;
    }
};

test "Env require returns value or MissingVariable" {
    var env = EnvMap.init(std.testing.allocator);
    defer env.deinit();

    try env.put("NAME", "Sean");

    try std.testing.expectEqualStrings("Sean", try env.require("NAME"));
    try std.testing.expectError(EnvError.MissingVariable, env.require("MISSING"));
}
