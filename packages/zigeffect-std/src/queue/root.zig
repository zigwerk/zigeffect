const std = @import("std");
const StdService = @import("../service/root.zig");
const fx = @import("zigeffect");

pub const QueueStats = fx.QueueStats;
pub const QueueOfferState = fx.QueueOfferState;
pub const QueueTakeState = fx.QueueTakeState;

pub fn Service(comptime Item: type) type {
    return struct {
        const Self = @This();

        queue: fx.Queue(Item),

        pub fn init(allocator: std.mem.Allocator) Self {
            return .{ .queue = fx.Queue(Item).init(allocator) };
        }

        pub fn bounded(allocator: std.mem.Allocator, capacity: usize) Self {
            return .{ .queue = fx.Queue(Item).bounded(allocator, capacity) };
        }

        pub fn deinit(self: *Self) void {
            self.queue.deinit();
        }

        pub fn offer(self: *Self, item: Item) (std.mem.Allocator.Error || fx.FiberPrimitiveError)!void {
            return self.queue.offer(item);
        }

        pub fn take(self: *Self) fx.FiberPrimitiveError!Item {
            return self.queue.take();
        }

        pub fn shutdown(self: *Self) void {
            self.queue.shutdown();
        }

        pub fn stats(self: *const Self) QueueStats {
            return self.queue.stats();
        }
    };
}

pub fn API(comptime Item: type) type {
    return struct {
        pub const operations: []const []const u8 = &.{ "Queue.offer", "Queue.take", "Queue.stats", "Queue.shutdown" };
        queue: *Service(Item),

        pub fn offer(self: @This(), item: Item) (std.mem.Allocator.Error || fx.FiberPrimitiveError)!void {
            return self.queue.offer(item);
        }
        pub fn take(self: @This()) fx.FiberPrimitiveError!Item {
            return self.queue.take();
        }
        pub fn stats(self: @This()) QueueStats {
            return self.queue.stats();
        }
        pub fn shutdown(self: @This()) void {
            self.queue.shutdown();
        }
    };
}

pub fn Queue(comptime Item: type) type {
    return fx.kernel.Service("zigeffect/std/Queue/" ++ @typeName(Item), API(Item));
}

pub fn layer(comptime Item: type, queue: *Service(Item)) @TypeOf(
    fx.kernel.Layer.succeed(Queue(Item), API(Item){ .queue = queue }),
) {
    return fx.kernel.Layer.succeed(Queue(Item), .{ .queue = queue });
}

pub fn offer(comptime Item: type, item: Item) fx.kernel.Effect(
    void,
    std.mem.Allocator.Error || fx.FiberPrimitiveError,
    .{Queue(Item)},
).Stateful(Item) {
    const Offer = fx.kernel.Effect(void, std.mem.Allocator.Error || fx.FiberPrimitiveError, .{Queue(Item)});
    return Offer.fromState(Item, item, struct {
        fn run(value: Item, ctx: *Offer.Context) Offer.FailureType!void {
            ctx.service(Queue(Item)).offer(value) catch |failure| {
                _ = StdService.recordSemantic(ctx, .span_recorded, Queue(Item).service_key, "Queue.offer", queueOfferFailureStatus(failure), @typeName(Item));
                return failure;
            };
            _ = StdService.recordSemantic(ctx, .span_recorded, Queue(Item).service_key, "Queue.offer", "success", @typeName(Item));
        }
    }.run);
}

pub fn take(comptime Item: type) fx.kernel.Effect(Item, fx.FiberPrimitiveError, .{Queue(Item)}) {
    const Take = fx.kernel.Effect(Item, fx.FiberPrimitiveError, .{Queue(Item)});
    return Take.fromFn(struct {
        fn run(ctx: *Take.Context) fx.FiberPrimitiveError!Item {
            const value = ctx.service(Queue(Item)).take() catch |failure| {
                _ = StdService.recordSemantic(ctx, .span_recorded, Queue(Item).service_key, "Queue.take", queueTakeFailureStatus(failure), @typeName(Item));
                return failure;
            };
            _ = StdService.recordSemantic(ctx, .span_recorded, Queue(Item).service_key, "Queue.take", "success", @typeName(Item));
            return value;
        }
    }.run);
}

pub fn stats(comptime Item: type) fx.kernel.Effect(QueueStats, error{}, .{Queue(Item)}) {
    const Stats = fx.kernel.Effect(QueueStats, error{}, .{Queue(Item)});
    return Stats.fromFn(struct {
        fn run(ctx: *Stats.Context) error{}!QueueStats {
            const value = ctx.service(Queue(Item)).stats();
            _ = StdService.recordSemantic(ctx, .span_recorded, Queue(Item).service_key, "Queue.stats", "success", @typeName(Item));
            return value;
        }
    }.run);
}

pub fn shutdown(comptime Item: type) fx.kernel.Effect(void, error{}, .{Queue(Item)}) {
    const Shutdown = fx.kernel.Effect(void, error{}, .{Queue(Item)});
    return Shutdown.fromFn(struct {
        fn run(ctx: *Shutdown.Context) error{}!void {
            ctx.service(Queue(Item)).shutdown();
            _ = StdService.recordSemantic(ctx, .span_recorded, Queue(Item).service_key, "Queue.shutdown", "closed", @typeName(Item));
        }
    }.run);
}

fn queueOfferFailureStatus(err: anyerror) []const u8 {
    return switch (err) {
        error.QueueFull => "backpressure",
        error.QueueShutdown => "shutdown",
        else => "failure",
    };
}

fn queueTakeFailureStatus(err: anyerror) []const u8 {
    return switch (err) {
        error.QueueEmpty => "empty",
        error.QueueShutdown => "shutdown",
        else => "failure",
    };
}

test "Queue service offer take stats and shutdown are effect-native" {
    const TextQueue = Service([]const u8);

    var queue = TextQueue.bounded(std.testing.allocator, 4);
    defer queue.deinit();
    const root = layer([]const u8, &queue);
    var runtime = try fx.kernel.ManagedRuntime(@TypeOf(root)).make(std.testing.allocator, root, .{});
    defer runtime.deinit();

    try runtime.run(offer([]const u8, "one"));
    try runtime.run(offer([]const u8, "two"));

    const current = try runtime.run(stats([]const u8));
    try std.testing.expectEqual(@as(usize, 2), current.len);
    try std.testing.expectEqual(@as(?usize, 2), current.remaining_capacity);

    try std.testing.expectEqualStrings("one", try runtime.run(take([]const u8)));

    try runtime.run(shutdown([]const u8));
    try std.testing.expectError(
        error.QueueShutdown,
        runtime.run(offer([]const u8, "after-close")),
    );
}

test "Queue offerEffect records backpressure when bounded queue is full" {
    const TextQueue = Service([]const u8);

    var queue = TextQueue.bounded(std.testing.allocator, 1);
    defer queue.deinit();
    const root = layer([]const u8, &queue);
    var store = fx.CausalStore.init(std.testing.allocator);
    defer store.deinit();
    var runtime = try fx.kernel.ManagedRuntime(@TypeOf(root)).make(std.testing.allocator, root, .{ .causal_store = &store });
    defer runtime.deinit();

    try runtime.run(offer([]const u8, "one"));
    try std.testing.expectError(
        error.QueueFull,
        runtime.run(offer([]const u8, "two")),
    );

    var snapshot = try store.snapshot(std.testing.allocator);
    defer snapshot.deinit();
    try std.testing.expect(StdService.hasOperation(snapshot, Queue([]const u8), "Queue.offer", "backpressure"));
}
