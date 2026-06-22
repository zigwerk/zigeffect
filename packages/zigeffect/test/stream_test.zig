//! M6.2 (first cut) — Stream tests.

const std = @import("std");
const fx = @import("zigeffect");

fn double(x: u32) u32 {
    return x * 2;
}
fn isEven(x: u32) bool {
    return x % 2 == 0;
}
fn sum(acc: u32, x: u32) u32 {
    return acc + x;
}

test "fromSlice + runCollect round-trips" {
    const items = [_]u32{ 1, 2, 3 };
    const out = try fx.streamFromSlice(u32, &items).runCollect(std.testing.allocator);
    defer std.testing.allocator.free(out);
    try std.testing.expectEqualSlices(u32, &.{ 1, 2, 3 }, out);
}

test "map transforms lazily" {
    const items = [_]u32{ 1, 2, 3 };
    const out = try fx.streamFromSlice(u32, &items).map(u32, double).runCollect(std.testing.allocator);
    defer std.testing.allocator.free(out);
    try std.testing.expectEqualSlices(u32, &.{ 2, 4, 6 }, out);
}

test "filter keeps matching items" {
    const items = [_]u32{ 1, 2, 3, 4, 5, 6 };
    const out = try fx.streamFromSlice(u32, &items).filter(isEven).runCollect(std.testing.allocator);
    defer std.testing.allocator.free(out);
    try std.testing.expectEqualSlices(u32, &.{ 2, 4, 6 }, out);
}

test "take bounds the stream" {
    const items = [_]u32{ 10, 20, 30, 40 };
    const out = try fx.streamFromSlice(u32, &items).take(2).runCollect(std.testing.allocator);
    defer std.testing.allocator.free(out);
    try std.testing.expectEqualSlices(u32, &.{ 10, 20 }, out);
}

test "drop skips the prefix" {
    const items = [_]u32{ 10, 20, 30, 40 };
    const out = try fx.streamFromSlice(u32, &items).drop(2).runCollect(std.testing.allocator);
    defer std.testing.allocator.free(out);
    try std.testing.expectEqualSlices(u32, &.{ 30, 40 }, out);
}

test "composed pipeline: map -> filter -> take is fully lazy" {
    const items = [_]u32{ 1, 2, 3, 4, 5, 6, 7, 8 };
    // double everything → keep evens (all, since doubled) → first 3.
    const out = try fx.streamFromSlice(u32, &items)
        .map(u32, double)
        .filter(isEven)
        .take(3)
        .runCollect(std.testing.allocator);
    defer std.testing.allocator.free(out);
    try std.testing.expectEqualSlices(u32, &.{ 2, 4, 6 }, out);
}

test "fold accumulates" {
    const items = [_]u32{ 1, 2, 3, 4 };
    const total = fx.streamFromSlice(u32, &items).fold(u32, 0, sum);
    try std.testing.expectEqual(@as(u32, 10), total);
}

test "count consumes and counts" {
    const items = [_]u32{ 5, 6, 7, 8, 9 };
    const n = fx.streamFromSlice(u32, &items).filter(isEven).count();
    try std.testing.expectEqual(@as(usize, 2), n); // 6, 8
}

var for_each_total: u32 = 0;
fn accumulate(x: u32) void {
    for_each_total += x;
}

test "forEach runs the side effect over each item" {
    for_each_total = 0;
    const items = [_]u32{ 1, 2, 3 };
    fx.streamFromSlice(u32, &items).forEach(accumulate);
    try std.testing.expectEqual(@as(u32, 6), for_each_total);
}

test "empty stream yields nothing" {
    const out = try fx.effect.stream.empty(u32).runCollect(std.testing.allocator);
    defer std.testing.allocator.free(out);
    try std.testing.expectEqual(@as(usize, 0), out.len);
}
