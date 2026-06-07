const std = @import("std");

pub fn HashSet(comptime T: type) type {
    return struct {
        const Self = @This();

        allocator: std.mem.Allocator,
        map: std.AutoHashMap(T, void),

        pub fn init(allocator: std.mem.Allocator) Self {
            return .{ .allocator = allocator, .map = std.AutoHashMap(T, void).init(allocator) };
        }

        pub fn deinit(self: *Self) void {
            self.map.deinit();
        }

        pub fn add(self: *Self, value: T) std.mem.Allocator.Error!void {
            try self.map.put(value, {});
        }

        pub fn contains(self: *const Self, value: T) bool {
            return self.map.contains(value);
        }

        pub fn remove(self: *Self, value: T) bool {
            return self.map.remove(value);
        }

        pub fn count(self: *const Self) usize {
            return self.map.count();
        }

        pub fn unionWith(self: *const Self, other: *const Self) std.mem.Allocator.Error!Self {
            var result = init(self.allocator);
            errdefer result.deinit();

            var self_keys = self.map.keyIterator();
            while (self_keys.next()) |key| {
                try result.add(key.*);
            }

            var other_keys = other.map.keyIterator();
            while (other_keys.next()) |key| {
                try result.add(key.*);
            }

            return result;
        }

        pub fn intersection(self: *const Self, other: *const Self) std.mem.Allocator.Error!Self {
            var result = init(self.allocator);
            errdefer result.deinit();

            var self_keys = self.map.keyIterator();
            while (self_keys.next()) |key| {
                if (other.contains(key.*)) try result.add(key.*);
            }

            return result;
        }

        pub fn difference(self: *const Self, other: *const Self) std.mem.Allocator.Error!Self {
            var result = init(self.allocator);
            errdefer result.deinit();

            var self_keys = self.map.keyIterator();
            while (self_keys.next()) |key| {
                if (!other.contains(key.*)) try result.add(key.*);
            }

            return result;
        }
    };
}
