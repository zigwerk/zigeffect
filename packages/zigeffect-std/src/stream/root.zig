const std = @import("std");
const Jsonl = @import("../jsonl/root.zig");
const fx = @import("zigeffect");

pub const EngineStream = fx.Stream;
pub const fromSlice = fx.streamFromSlice;

pub fn empty(comptime Item: type) @TypeOf(fx.streamFromSlice(Item, &[_]Item{})) {
    return fx.streamFromSlice(Item, &[_]Item{});
}

pub fn collectAlloc(
    stream: anytype,
    allocator: std.mem.Allocator,
) std.mem.Allocator.Error![]@TypeOf(stream).ItemType {
    return stream.runCollect(allocator);
}

pub fn splitLinesAlloc(allocator: std.mem.Allocator, input: []const u8) std.mem.Allocator.Error!Jsonl.ParsedLines {
    return Jsonl.parseLinesAlloc(allocator, input);
}

test "Stream re-exports engine stream composition and collects values" {
    const input = [_]u8{ 1, 2, 3, 4 };
    const Doubler = struct {
        fn apply(value: u8) u8 {
            return value * 2;
        }
    };
    const Even = struct {
        fn keep(value: u8) bool {
            return value % 4 == 0;
        }
    };

    const values = try collectAlloc(
        fromSlice(u8, input[0..]).map(u8, Doubler.apply).filter(Even.keep),
        std.testing.allocator,
    );
    defer std.testing.allocator.free(values);

    try std.testing.expectEqualSlices(u8, &.{ 4, 8 }, values);
}

test "Stream splits complete lines and retains trailing partial line" {
    var lines = try splitLinesAlloc(std.testing.allocator, "one\ntwo\nthr");
    defer lines.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), lines.lines.len);
    try std.testing.expectEqualStrings("one", lines.lines[0]);
    try std.testing.expectEqualStrings("two", lines.lines[1]);
    try std.testing.expectEqualStrings("thr", lines.trailing);
}
