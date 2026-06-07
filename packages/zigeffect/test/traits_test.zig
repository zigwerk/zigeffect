const std = @import("std");
const fx = @import("zigeffect");

const Point = struct { x: u8, y: u8 };
const Shape = union(enum) { point: Point, label: []const u8 };
const Parity = struct {
    value: u8,

    pub fn equals(lhs: @This(), rhs: @This()) bool {
        return lhs.value % 2 == rhs.value % 2;
    }

    pub fn hash(self: @This()) u64 {
        return self.value % 2;
    }

    pub fn compare(lhs: @This(), rhs: @This()) fx.traits.Ordering {
        return fx.traits.compare(u8, lhs.value % 2, rhs.value % 2);
    }
};

test "Equal compares scalars slices structs and tagged unions" {
    try std.testing.expect(fx.traits.equals(u8, 1, 1));
    try std.testing.expect(!fx.traits.equals(u8, 1, 2));
    try std.testing.expect(fx.traits.equals([]const u8, "same", "same"));
    try std.testing.expect(!fx.traits.equals([]const u8, "same", "diff"));
    try std.testing.expect(fx.traits.equals(Point, .{ .x = 1, .y = 2 }, .{ .x = 1, .y = 2 }));
    try std.testing.expect(!fx.traits.equals(Point, .{ .x = 1, .y = 2 }, .{ .x = 2, .y = 1 }));
    try std.testing.expect(fx.traits.equals(Shape, .{ .point = .{ .x = 1, .y = 2 } }, .{ .point = .{ .x = 1, .y = 2 } }));
    try std.testing.expect(!fx.traits.equals(Shape, .{ .point = .{ .x = 1, .y = 2 } }, .{ .label = "point" }));
}

test "Hash and Order produce stable basic behavior" {
    try std.testing.expectEqual(fx.traits.hash(u8, 42), fx.traits.hash(u8, 42));
    try std.testing.expectEqual(fx.traits.hash(Point, .{ .x = 4, .y = 5 }), fx.traits.hash(Point, .{ .x = 4, .y = 5 }));
    try std.testing.expectEqual(fx.traits.Ordering.less, fx.traits.compare(u8, 1, 2));
    try std.testing.expectEqual(fx.traits.Ordering.equal, fx.traits.compare(u8, 2, 2));
    try std.testing.expectEqual(fx.traits.Ordering.greater, fx.traits.compare(u8, 3, 2));
}

test "traits honor custom implementations and expose formatting redaction helpers" {
    try std.testing.expect(fx.traits.equals(Parity, .{ .value = 2 }, .{ .value = 4 }));
    try std.testing.expect(!fx.traits.equals(Parity, .{ .value = 2 }, .{ .value = 3 }));
    try std.testing.expectEqual(@as(u64, 1), fx.traits.hash(Parity, .{ .value = 5 }));
    try std.testing.expectEqual(fx.traits.Ordering.less, fx.traits.compare(Parity, .{ .value = 2 }, .{ .value = 3 }));

    const rendered = try fx.traits.format(std.testing.allocator, @as(u8, 7));
    defer std.testing.allocator.free(rendered);
    try std.testing.expectEqualStrings("7", rendered);
    try std.testing.expectEqualStrings("[REDACTED]", fx.traits.redaction_marker);
}
