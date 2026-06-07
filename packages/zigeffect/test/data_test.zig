const std = @import("std");
const fx = @import("zigeffect");

fn addOne(value: u8) u8 {
    return value + 1;
}

fn doubleSome(value: u8) fx.Option(u8) {
    return fx.Option(u8).some(value * 2);
}

fn appendBang(value: []const u8) []const u8 {
    if (std.mem.eql(u8, value, "bad")) return "bad!";
    return "!";
}

test "data namespace exposes core data type constructors" {
    try std.testing.expect(@hasDecl(fx.data, "Option"));
    try std.testing.expect(@hasDecl(fx.data, "Either"));
    try std.testing.expect(@hasDecl(fx.data, "Duration"));
    try std.testing.expect(@hasDecl(fx.data, "Redacted"));
    try std.testing.expect(@hasDecl(fx.data, "Chunk"));
    try std.testing.expect(@hasDecl(fx.data, "HashSet"));
    try std.testing.expect(@hasDecl(fx.data, "DateTime"));
    try std.testing.expect(@hasDecl(fx.data, "BigDecimal"));
}

test "root facade exposes foundational data constructors" {
    try std.testing.expect(fx.Option(u8) == fx.data.Option(u8));
    try std.testing.expect(fx.Either(u8, []const u8) == fx.data.Either(u8, []const u8));
    try std.testing.expect(fx.Duration == fx.data.Duration);
    try std.testing.expect(fx.Redacted([]const u8) == fx.data.Redacted([]const u8));
}

test "Option maps flatMaps defaults and exposes values deliberately" {
    const option = fx.Option(u8).some(2);
    const none = fx.Option(u8).none();

    try std.testing.expect(option.isSome());
    try std.testing.expect(!option.isNone());
    try std.testing.expect(none.isNone());
    try std.testing.expectEqual(@as(u8, 3), option.map(u8, addOne).getOrElse(0));
    try std.testing.expectEqual(@as(u8, 4), option.flatMap(u8, doubleSome).getOrElse(0));
    try std.testing.expectEqual(@as(u8, 9), none.getOrElse(9));
    try std.testing.expectEqual(@as(?u8, 2), option.valueOrNull());
    try std.testing.expectEqual(@as(?u8, null), none.valueOrNull());
}

test "Either is right biased and supports map mapLeft and defaults" {
    const right = fx.Either(u8, []const u8).right(2);
    const left = fx.Either(u8, []const u8).left("bad");

    try std.testing.expect(right.isRight());
    try std.testing.expect(!right.isLeft());
    try std.testing.expect(left.isLeft());
    try std.testing.expectEqual(@as(u8, 3), right.map(u8, addOne).getOrElse(0));
    try std.testing.expectEqualStrings("bad!", left.mapLeft([]const u8, appendBang).leftOrNull().?);
    try std.testing.expectEqual(@as(u8, 9), left.getOrElse(9));
    try std.testing.expectEqual(@as(?u8, 2), right.rightOrNull());
    try std.testing.expectEqual(@as(?[]const u8, null), right.leftOrNull());
}

test "Duration and Redacted expose safe value behavior" {
    const d = fx.Duration.seconds(2).plus(fx.Duration.millis(500));
    try std.testing.expectEqual(@as(?i128, 2_500_000_000), d.toNanos());
    try std.testing.expectEqual(@as(?i128, null), fx.Duration.infinity().toNanos());

    const secret = fx.Redacted([]const u8).make("token");
    try std.testing.expectEqualStrings("token", secret.unsafeValue());
    try std.testing.expectEqualStrings("[REDACTED]", secret.redactedText());
}
