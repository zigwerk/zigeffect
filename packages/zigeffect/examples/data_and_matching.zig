const std = @import("std");
const fx = @import("zigeffect");

const User = struct {
    id: u8,
    name: []const u8,
    age: u8,
};

const Event = union(enum) {
    heartbeat,
    signed_in: User,
    failed: []const u8,
};

fn isAdultUser(user: User) bool {
    return user.age >= 18;
}

fn onHeartbeat() []const u8 {
    return "heartbeat";
}

fn onSignedIn(user: User) []const u8 {
    return user.name;
}

fn onFailed(message: []const u8) []const u8 {
    return message;
}

fn classify(event: Event) []const u8 {
    return fx.pattern.exhaustive([]const u8, event, .{
        .heartbeat = fx.pattern.arm(fx.pattern.any, onHeartbeat),
        .signed_in = fx.pattern.arm(.{
            .id = fx.pattern.any,
            .name = fx.pattern.any,
            .age = fx.pattern.range(.inclusive, 18, 120),
        }, onSignedIn),
        .failed = fx.pattern.arm(fx.pattern.any, onFailed),
    });
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    var users = try fx.Chunk(User).fromSlice(allocator, &.{
        .{ .id = 1, .name = "Ada", .age = 34 },
        .{ .id = 2, .name = "Lin", .age = 16 },
    });
    defer users.deinit();

    var adults = try users.filter(isAdultUser);
    defer adults.deinit();

    var total = try fx.BigDecimal.parse(allocator, "123456789012345678901234567890.0001");
    defer total.deinit();
    const rendered_total = try total.format(allocator);
    defer allocator.free(rendered_total);

    std.debug.print("matched={s} total={s}\n", .{
        classify(.{ .signed_in = adults.items[0] }),
        rendered_total,
    });
}

test "data and matching example classifies adult sign in" {
    var users = try fx.Chunk(User).fromSlice(std.testing.allocator, &.{
        .{ .id = 1, .name = "Ada", .age = 34 },
        .{ .id = 2, .name = "Lin", .age = 16 },
    });
    defer users.deinit();

    var adults = try users.filter(isAdultUser);
    defer adults.deinit();

    try std.testing.expectEqual(@as(usize, 1), adults.len());
    try std.testing.expectEqualStrings("Ada", classify(.{ .signed_in = adults.items[0] }));

    var parsed = try fx.BigDecimal.parse(std.testing.allocator, "123456789012345678901234567890.0001");
    defer parsed.deinit();
    const rendered = try parsed.format(std.testing.allocator);
    defer std.testing.allocator.free(rendered);
    try std.testing.expectEqualStrings("123456789012345678901234567890.0001", rendered);
}
