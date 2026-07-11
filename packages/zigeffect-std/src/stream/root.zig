const std = @import("std");
const Jsonl = @import("../jsonl/root.zig");
const Schedules = @import("../testing/schedules.zig");
const fx = @import("zigeffect");

pub const EngineStream = fx.Stream;
pub const ValueStream = fx.ValueStream;
pub const Effectful = fx.EffectStream;
pub const effectfulFromSliceAlloc = fx.effectStreamFromSliceAlloc;
pub const effectfulFromPuller = fx.effectStreamFromPuller;
pub const effectfulFromOwnedPullerAlloc = fx.effectStreamFromOwnedPullerAlloc;
pub const BoundedBuffer = fx.BoundedStreamBuffer;
pub const BackpressureStrategy = fx.StreamBackpressureStrategy;
pub const fromSlice = fx.streamFromSlice;
pub const EmptyEnv = struct {};

pub fn ownedBytesAlloc(allocator: std.mem.Allocator, bytes: []const u8) !fx.EffectStream(u8, anyerror, EmptyEnv) {
    const Puller = struct {
        allocator: std.mem.Allocator,
        bytes: []u8,
        offset: usize = 0,
        closed: bool = false,
        pub fn pull(self: *@This(), _: *fx.Context(EmptyEnv), output_allocator: std.mem.Allocator, max: usize) anyerror!fx.EffectStream(u8, anyerror, EmptyEnv).Chunk { const count = @min(max, self.bytes.len - self.offset); const output = try output_allocator.dupe(u8, self.bytes[self.offset .. self.offset + count]); self.offset += count; return .{ .allocator = output_allocator, .items = output, .end = self.offset == self.bytes.len }; }
        pub fn close(self: *@This(), _: fx.StreamCloseReason) void { self.closed = true; }
        pub fn deinit(self: *@This()) void { self.allocator.free(self.bytes); }
    };
    return fx.effectStreamFromOwnedPullerAlloc(u8, anyerror, EmptyEnv, Puller, allocator, .{ .allocator = allocator, .bytes = try allocator.dupe(u8, bytes) });
}

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

test "effect stream backpressure model explores every bounded producer consumer schedule" {
    const Model = struct {
        produced: u8 = 0,
        consumed: u8 = 0,
        queue: [2]u8 = .{ 0, 0 },
        count: u8 = 0,
        valid_order: bool = true,

        pub fn actionCount(_: @This()) usize { return 2; }
        pub fn runnable(self: @This(), action: usize) bool {
            return switch (action) {
                0 => self.produced < 3 and self.count < self.queue.len,
                1 => self.consumed < 3 and self.count != 0,
                else => false,
            };
        }
        pub fn step(self: *@This(), action: usize) !void {
            if (!self.runnable(action)) return error.NotRunnable;
            switch (action) {
                0 => {
                    self.produced += 1;
                    self.queue[self.count] = self.produced;
                    self.count += 1;
                },
                1 => {
                    self.consumed += 1;
                    self.valid_order = self.valid_order and self.queue[0] == self.consumed;
                    if (self.count > 1) self.queue[0] = self.queue[1];
                    self.count -= 1;
                },
                else => unreachable,
            }
        }
        pub fn isComplete(self: @This()) bool { return self.produced == 3 and self.consumed == 3; }
        pub fn invariant(self: @This()) bool { return self.valid_order and self.count <= self.queue.len; }
        pub fn stateHash(self: @This()) u64 {
            return @as(u64, self.produced) |
                (@as(u64, self.consumed) << 8) |
                (@as(u64, self.count) << 16) |
                (@as(u64, self.queue[0]) << 24) |
                (@as(u64, self.queue[1]) << 32);
        }
        pub fn sourceRef(_: @This(), action: usize) ?u64 { return 138_000 + action; }
    };

    var evidence = try Schedules.explore(std.testing.allocator, Model{}, .{
        .max_states = 128,
        .max_schedules = 128,
        .max_steps_per_schedule = 8,
    });
    defer evidence.deinit();
    try std.testing.expectEqual(.passed, evidence.status);
    try std.testing.expect(!evidence.truncated);
    try std.testing.expect(evidence.explored_schedules > 1);
}
