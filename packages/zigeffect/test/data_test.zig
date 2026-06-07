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

const Tagged = union(enum) {
    one,
    two: u8,
};

const Plain = struct {
    value: u8,
};

fn toU16(value: u8) u16 {
    return value * 10;
}

fn isEven(value: u8) bool {
    return value % 2 == 0;
}

fn sumU8(accumulator: u32, value: u8) u32 {
    return accumulator + value;
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

test "Data identifies tagged unions" {
    try std.testing.expect(fx.Data.isTaggedUnion(Tagged));
    try std.testing.expect(!fx.Data.isTaggedUnion(Plain));
}

test "Chunk copies appends concatenates maps filters and folds" {
    var chunk = try fx.Chunk(u8).fromSlice(std.testing.allocator, &.{ 1, 2, 3 });
    defer chunk.deinit();
    try chunk.append(4);

    var other = try fx.Chunk(u8).fromSlice(std.testing.allocator, &.{ 5, 6 });
    defer other.deinit();

    var combined = try chunk.concat(other);
    defer combined.deinit();
    try std.testing.expectEqualSlices(u8, &.{ 1, 2, 3, 4, 5, 6 }, combined.items);

    var mapped = try combined.map(u16, toU16);
    defer mapped.deinit();
    try std.testing.expectEqualSlices(u16, &.{ 10, 20, 30, 40, 50, 60 }, mapped.items);

    var filtered = try combined.filter(isEven);
    defer filtered.deinit();
    try std.testing.expectEqualSlices(u8, &.{ 2, 4, 6 }, filtered.items);

    try std.testing.expectEqual(@as(u32, 21), combined.fold(u32, 0, sumU8));
}

test "HashSet adds unique values removes and combines sets" {
    var set = fx.HashSet(u8).init(std.testing.allocator);
    defer set.deinit();
    try set.add(1);
    try set.add(1);
    try set.add(2);
    try std.testing.expectEqual(@as(usize, 2), set.count());
    try std.testing.expect(set.contains(1));
    try std.testing.expect(set.remove(1));
    try std.testing.expect(!set.contains(1));

    var other = fx.HashSet(u8).init(std.testing.allocator);
    defer other.deinit();
    try other.add(2);
    try other.add(3);

    var unioned = try set.unionWith(&other);
    defer unioned.deinit();
    try std.testing.expect(unioned.contains(2));
    try std.testing.expect(unioned.contains(3));

    var intersection = try set.intersection(&other);
    defer intersection.deinit();
    try std.testing.expect(intersection.contains(2));
    try std.testing.expect(!intersection.contains(3));

    var difference = try other.difference(&set);
    defer difference.deinit();
    try std.testing.expect(difference.contains(3));
    try std.testing.expect(!difference.contains(2));
}

test "DateTime parses formats UTC ISO strings and computes duration distance" {
    const timestamp = try fx.DateTime.parseIsoUtc("2026-06-07T12:34:56.123456789Z");
    const rendered = try timestamp.formatIsoUtc(std.testing.allocator);
    defer std.testing.allocator.free(rendered);
    try std.testing.expectEqualStrings("2026-06-07T12:34:56.123456789Z", rendered);

    const later = try fx.DateTime.parseIsoUtc("2026-06-07T12:35:01.123456789Z");
    try std.testing.expectEqual(@as(?i128, 5_000_000_000), later.distance(timestamp).toNanos());
}

test "BigDecimal parses and formats values larger than i128 precision" {
    const text = "-1234567890123456789012345678901234567890.000000000000000001";
    var decimal = try fx.BigDecimal.parse(std.testing.allocator, text);
    defer decimal.deinit();

    try std.testing.expect(decimal.isNegative());
    try std.testing.expectEqual(@as(i32, 18), decimal.scaleValue());
    try std.testing.expectEqualStrings(
        "1234567890123456789012345678901234567890000000000000000001",
        decimal.coefficientDigits(),
    );

    const rendered = try decimal.format(std.testing.allocator);
    defer std.testing.allocator.free(rendered);
    try std.testing.expectEqualStrings(text, rendered);
}
