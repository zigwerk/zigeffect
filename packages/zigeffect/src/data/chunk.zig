const std = @import("std");

pub fn Chunk(comptime T: type) type {
    return struct {
        const Self = @This();

        allocator: std.mem.Allocator,
        items: []T,

        pub fn init(allocator: std.mem.Allocator) Self {
            return .{ .allocator = allocator, .items = &.{} };
        }

        pub fn fromSlice(allocator: std.mem.Allocator, values: []const T) std.mem.Allocator.Error!Self {
            const items = try allocator.dupe(T, values);
            return .{ .allocator = allocator, .items = items };
        }

        pub fn deinit(self: *Self) void {
            if (self.items.len > 0) self.allocator.free(self.items);
            self.items = &.{};
        }

        pub fn len(self: Self) usize {
            return self.items.len;
        }

        pub fn append(self: *Self, value: T) std.mem.Allocator.Error!void {
            if (self.items.len == 0) {
                self.items = try self.allocator.alloc(T, 1);
            } else {
                self.items = try self.allocator.realloc(self.items, self.items.len + 1);
            }
            self.items[self.items.len - 1] = value;
        }

        pub fn concat(self: Self, other: Self) std.mem.Allocator.Error!Self {
            var items = try self.allocator.alloc(T, self.items.len + other.items.len);
            errdefer self.allocator.free(items);
            @memcpy(items[0..self.items.len], self.items);
            @memcpy(items[self.items.len..], other.items);
            return .{ .allocator = self.allocator, .items = items };
        }

        pub fn map(self: Self, comptime U: type, f: anytype) std.mem.Allocator.Error!Chunk(U) {
            var items = try self.allocator.alloc(U, self.items.len);
            errdefer self.allocator.free(items);
            for (self.items, 0..) |item, index| {
                items[index] = f(item);
            }
            return .{ .allocator = self.allocator, .items = items };
        }

        pub fn filter(self: Self, predicate: anytype) std.mem.Allocator.Error!Self {
            var items = try self.allocator.alloc(T, self.items.len);
            errdefer self.allocator.free(items);
            var count: usize = 0;
            for (self.items) |item| {
                if (predicate(item)) {
                    items[count] = item;
                    count += 1;
                }
            }
            if (count == 0) {
                self.allocator.free(items);
                return init(self.allocator);
            }
            items = try self.allocator.realloc(items, count);
            return .{ .allocator = self.allocator, .items = items };
        }

        pub fn fold(self: Self, comptime Accumulator: type, initial: Accumulator, f: anytype) Accumulator {
            var result = initial;
            for (self.items) |item| {
                result = f(result, item);
            }
            return result;
        }
    };
}
