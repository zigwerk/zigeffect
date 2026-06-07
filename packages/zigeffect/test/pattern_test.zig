const std = @import("std");
const fx = @import("zigeffect");

const Profile = struct {
    age: u8,
    name: []const u8,
    pos: struct { x: i32, y: i32 },
};

const Command = union(enum) {
    quit,
    profile: Profile,
    score: u8,
};

fn isAdult(value: u8) bool {
    return value >= 18;
}

fn onQuit() []const u8 {
    return "quit";
}

fn onProfile(profile: Profile) []const u8 {
    return profile.name;
}

fn onScore(score: u8) []const u8 {
    if (score == 10) return "ten";
    return "score";
}

test "pattern namespace exposes structural matching entry points" {
    try std.testing.expect(@hasDecl(fx.pattern, "matches"));
    try std.testing.expect(@hasDecl(fx.pattern, "capture"));
    try std.testing.expect(@hasDecl(fx.pattern, "any"));
    try std.testing.expect(@hasDecl(fx.pattern, "bind"));
    try std.testing.expect(@hasDecl(fx.pattern, "range"));
}

test "structural matcher supports wildcard ranges nested structs and captures" {
    const profile = Profile{ .age = 34, .name = "Ada", .pos = .{ .x = 10, .y = 20 } };
    try std.testing.expect(fx.pattern.matches(profile, .{
        .age = fx.pattern.range(.inclusive, 18, 65),
        .name = fx.pattern.any,
        .pos = .{ .x = 10, .y = fx.pattern.any },
    }));
    try std.testing.expect(!fx.pattern.matches(profile, .{
        .age = fx.pattern.range(.inclusive, 35, 65),
        .name = fx.pattern.any,
        .pos = .{ .x = 10, .y = fx.pattern.any },
    }));

    const captures = fx.pattern.capture(profile, .{
        .age = fx.pattern.any,
        .name = fx.pattern.bind("name"),
        .pos = .{ .x = fx.pattern.bind("x"), .y = 20 },
    }).?;
    try std.testing.expectEqualStrings("Ada", captures.name);
    try std.testing.expectEqual(@as(i32, 10), captures.x);
}

test "structural matcher supports predicates and exact arrays" {
    try std.testing.expect(fx.pattern.matches(@as(u8, 34), fx.pattern.predicate(isAdult)));
    try std.testing.expect(!fx.pattern.matches(@as(u8, 12), fx.pattern.predicate(isAdult)));
    try std.testing.expect(fx.pattern.matches(@as(?u8, 34), fx.pattern.some(fx.pattern.predicate(isAdult))));
    try std.testing.expect(fx.pattern.matches(@as(?u8, null), fx.pattern.none));
    try std.testing.expect(!fx.pattern.matches(@as(?u8, 12), fx.pattern.some(fx.pattern.predicate(isAdult))));
    try std.testing.expect(fx.pattern.matches([_]u8{ 1, 2, 3 }, [_]u8{ 1, 2, 3 }));
    try std.testing.expect(!fx.pattern.matches([_]u8{ 1, 2, 3 }, [_]u8{ 1, 2, 4 }));
}

test "structural arms exhaustively and partially match tagged union payloads" {
    const profile = Profile{ .age = 34, .name = "Ada", .pos = .{ .x = 10, .y = 20 } };
    try std.testing.expectEqualStrings("Ada", fx.pattern.exhaustive([]const u8, Command{ .profile = profile }, .{
        .quit = fx.pattern.arm(fx.pattern.any, onQuit),
        .profile = fx.pattern.arm(.{
            .age = fx.pattern.range(.inclusive, 18, 65),
            .name = fx.pattern.any,
            .pos = .{ .x = 10, .y = fx.pattern.any },
        }, onProfile),
        .score = fx.pattern.arm(fx.pattern.range(.inclusive, 1, 10), onScore),
    }));

    try std.testing.expectEqualStrings("ten", fx.pattern.partial([]const u8, Command{ .score = 10 }, .{
        .score = fx.pattern.arm(fx.pattern.range(.inclusive, 10, 20), onScore),
    }).?);
    try std.testing.expect(fx.pattern.partial([]const u8, Command{ .score = 2 }, .{
        .score = fx.pattern.arm(fx.pattern.range(.inclusive, 10, 20), onScore),
    }) == null);
}
