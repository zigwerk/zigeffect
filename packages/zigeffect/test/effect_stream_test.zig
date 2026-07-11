const std = @import("std");
const fx = @import("zigeffect");

const Env = struct {};
const Ctx = fx.Context(Env);
const StreamFailure = error{OutOfMemory};

test "effect stream composes chunked map filter flat-map merge buffer and debounce" {
    var env = Env{};
    var clock = fx.Clock.fake(0);
    var ctx = Ctx.init(std.testing.allocator, &env, null);
    ctx.clock = &clock;
    const Map = struct { fn run(value: u8, _: *Ctx) StreamFailure!u8 { return value * 2; } };
    const Filter = struct { fn run(value: u8, _: *Ctx) StreamFailure!bool { return value % 4 == 0; } };
    const Binder = struct {
        fn run(value: u8, context: *Ctx) StreamFailure!fx.EffectStream(u8, StreamFailure, Env) {
            return fx.effectStreamFromSliceAlloc(u8, StreamFailure, Env, context.allocator, &.{ value, value + 1 });
        }
    };
    const left = try fx.effectStreamFromSliceAlloc(u8, StreamFailure, Env, std.testing.allocator, &.{ 1, 2, 3, 4 });
    const mapped = try left.mapEffectAlloc(u8, std.testing.allocator, Map.run);
    const filtered = try mapped.filterEffectAlloc(std.testing.allocator, Filter.run);
    const flat = try filtered.flatMapAlloc(u8, std.testing.allocator, Binder.run);
    const right = try fx.effectStreamFromSliceAlloc(u8, StreamFailure, Env, std.testing.allocator, &.{ 20, 21 });
    const merged = try flat.mergeAlloc(std.testing.allocator, right);
    const buffered = try merged.bufferAlloc(std.testing.allocator, 2);
    var debounced = try buffered.debounceAlloc(std.testing.allocator, 5);
    defer debounced.deinit();
    const values = try debounced.runCollectAlloc(&ctx, std.testing.allocator, 2);
    defer std.testing.allocator.free(values);
    try std.testing.expectEqualSlices(u8, &.{ 5, 21, 9 }, values);
    try std.testing.expectEqual(@as(u64, 15), clock.nowMs());
}

test "effect stream owns source items after the caller mutates its slice" {
    var env = Env{};
    var ctx = Ctx.init(std.testing.allocator, &env, null);
    var source_items = [_]u8{ 3, 5, 8 };
    var stream = try fx.effectStreamFromSliceAlloc(
        u8,
        StreamFailure,
        Env,
        std.testing.allocator,
        &source_items,
    );
    defer stream.deinit();

    @memset(&source_items, 0);
    const values = try stream.runCollectAlloc(&ctx, std.testing.allocator, 2);
    defer std.testing.allocator.free(values);

    try std.testing.expectEqualSlices(u8, &.{ 3, 5, 8 }, values);
}

test "effect stream retries a transient pull and times out cooperatively" {
    const Puller = struct {
        attempts: usize = 0,
        closed: usize = 0,
        pub fn pull(self: *@This(), _: *Ctx, allocator: std.mem.Allocator, _: usize) (error{Transient} || std.mem.Allocator.Error)!fx.EffectStream(u8, error{Transient}, Env).Chunk {
            self.attempts += 1;
            if (self.attempts == 1) return error.Transient;
            return .{ .allocator = allocator, .items = try allocator.dupe(u8, &.{7}), .end = true };
        }
        pub fn close(self: *@This(), _: fx.StreamCloseReason) void { self.closed += 1; }
    };
    var env = Env{};
    var clock = fx.Clock.fake(0);
    var ctx = Ctx.init(std.testing.allocator, &env, null);
    ctx.clock = &clock;
    var puller = Puller{};
    const source = fx.effectStreamFromPuller(u8, error{Transient}, Env, Puller, std.testing.allocator, &puller);
    var retried = try source.retryAlloc(std.testing.allocator, 2);
    defer retried.deinit();
    const values = try retried.runCollectAlloc(&ctx, std.testing.allocator, 1);
    defer std.testing.allocator.free(values);
    try std.testing.expectEqualSlices(u8, &.{7}, values);
    try std.testing.expectEqual(@as(usize, 2), puller.attempts);
    try std.testing.expectEqual(@as(usize, 1), puller.closed);
}

test "effect stream interruption finalizes an external source exactly once" {
    const Puller = struct {
        closes: usize = 0,
        reason: ?fx.StreamCloseReason = null,
        pub fn pull(_: *@This(), _: *Ctx, allocator: std.mem.Allocator, _: usize) anyerror!fx.EffectStream(u8, anyerror, Env).Chunk {
            return .{ .allocator = allocator, .items = try allocator.dupe(u8, &.{1}), .end = false };
        }
        pub fn close(self: *@This(), reason: fx.StreamCloseReason) void { self.closes += 1; self.reason = reason; }
    };
    var puller = Puller{};
    var stream = fx.effectStreamFromPuller(u8, anyerror, Env, Puller, std.testing.allocator, &puller);
    stream.interrupt();
    stream.interrupt();
    stream.deinit();
    try std.testing.expectEqual(@as(usize, 1), puller.closes);
    try std.testing.expectEqual(fx.StreamCloseReason.interrupted, puller.reason.?);
}

test "bounded stream buffer never exceeds capacity" {
    var buffer = try fx.BoundedStreamBuffer(u8).initAlloc(std.testing.allocator, 2);
    defer buffer.deinit();
    try std.testing.expect(try buffer.offer(1, .reject));
    try std.testing.expect(try buffer.offer(2, .reject));
    try std.testing.expectError(error.BufferFull, buffer.offer(3, .reject));
    try std.testing.expect(!(try buffer.offer(3, .drop_newest)));
    try std.testing.expect(try buffer.offer(3, .drop_oldest));
    try std.testing.expectEqual(@as(usize, 2), buffer.size());
    try std.testing.expectEqual(@as(u8, 2), try buffer.take());
    try std.testing.expectEqual(@as(u8, 3), try buffer.take());
}
