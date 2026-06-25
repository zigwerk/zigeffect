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

pub fn OfferEffect(comptime EffectEnv: type, comptime Item: type) type {
    const QueueService = Service(Item);
    return struct {
        pub const SuccessType = void;
        pub const FailureType = std.mem.Allocator.Error || fx.FiberPrimitiveError;
        pub const EnvType = EffectEnv;
        pub const RequiredServices = .{QueueService};

        item: Item,

        pub fn requiredServices(allocator: std.mem.Allocator) std.mem.Allocator.Error!fx.ServiceSet {
            return fx.ServiceSet.fromTypes(allocator, RequiredServices);
        }

        pub fn run(self: @This(), ctx: *fx.Context(EffectEnv)) FailureType!void {
            const queue = ctx.service(QueueService);
            queue.offer(self.item) catch |err| {
                _ = StdService.recordOperation(ctx, QueueService, "offer", queueOfferFailureStatus(err), @typeName(Item));
                return err;
            };
            _ = StdService.recordOperation(ctx, QueueService, "offer", "success", @typeName(Item));
        }
    };
}

pub fn TakeEffect(comptime EffectEnv: type, comptime Item: type) type {
    const QueueService = Service(Item);
    return struct {
        pub const SuccessType = Item;
        pub const FailureType = fx.FiberPrimitiveError;
        pub const EnvType = EffectEnv;
        pub const RequiredServices = .{QueueService};

        pub fn requiredServices(allocator: std.mem.Allocator) std.mem.Allocator.Error!fx.ServiceSet {
            return fx.ServiceSet.fromTypes(allocator, RequiredServices);
        }

        pub fn run(_: @This(), ctx: *fx.Context(EffectEnv)) FailureType!Item {
            const queue = ctx.service(QueueService);
            const item = queue.take() catch |err| {
                _ = StdService.recordOperation(ctx, QueueService, "take", queueTakeFailureStatus(err), @typeName(Item));
                return err;
            };
            _ = StdService.recordOperation(ctx, QueueService, "take", "success", @typeName(Item));
            return item;
        }
    };
}

pub fn StatsEffect(comptime EffectEnv: type, comptime Item: type) type {
    const QueueService = Service(Item);
    return struct {
        pub const SuccessType = QueueStats;
        pub const FailureType = error{};
        pub const EnvType = EffectEnv;
        pub const RequiredServices = .{QueueService};

        pub fn requiredServices(allocator: std.mem.Allocator) std.mem.Allocator.Error!fx.ServiceSet {
            return fx.ServiceSet.fromTypes(allocator, RequiredServices);
        }

        pub fn run(_: @This(), ctx: *fx.Context(EffectEnv)) FailureType!QueueStats {
            const queue = ctx.service(QueueService);
            const queue_stats = queue.stats();
            _ = StdService.recordOperation(ctx, QueueService, "stats", "success", @typeName(Item));
            return queue_stats;
        }
    };
}

pub fn ShutdownEffect(comptime EffectEnv: type, comptime Item: type) type {
    const QueueService = Service(Item);
    return struct {
        pub const SuccessType = void;
        pub const FailureType = error{};
        pub const EnvType = EffectEnv;
        pub const RequiredServices = .{QueueService};

        pub fn requiredServices(allocator: std.mem.Allocator) std.mem.Allocator.Error!fx.ServiceSet {
            return fx.ServiceSet.fromTypes(allocator, RequiredServices);
        }

        pub fn run(_: @This(), ctx: *fx.Context(EffectEnv)) FailureType!void {
            const queue = ctx.service(QueueService);
            queue.shutdown();
            _ = StdService.recordOperation(ctx, QueueService, "shutdown", "closed", @typeName(Item));
        }
    };
}

pub fn offerEffect(comptime EffectEnv: type, comptime Item: type, item: Item) OfferEffect(EffectEnv, Item) {
    return .{ .item = item };
}

pub fn takeEffect(comptime EffectEnv: type, comptime Item: type) TakeEffect(EffectEnv, Item) {
    return .{};
}

pub fn statsEffect(comptime EffectEnv: type, comptime Item: type) StatsEffect(EffectEnv, Item) {
    return .{};
}

pub fn shutdownEffect(comptime EffectEnv: type, comptime Item: type) ShutdownEffect(EffectEnv, Item) {
    return .{};
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
    const zstd = @import("../root.zig");
    const TextQueue = Service([]const u8);

    var queue = TextQueue.bounded(std.testing.allocator, 4);
    defer queue.deinit();
    var provider = zstd.Service.Provider(.{TextQueue}).init(.{&queue});
    var runtime = zstd.fx.Runtime(@TypeOf(provider)).init(std.testing.allocator, &provider)
        .provides(.{TextQueue});

    try runtime.run(offerEffect(@TypeOf(provider), []const u8, "one"));
    try runtime.run(offerEffect(@TypeOf(provider), []const u8, "two"));

    const stats = try runtime.run(statsEffect(@TypeOf(provider), []const u8));
    try std.testing.expectEqual(@as(usize, 2), stats.len);
    try std.testing.expectEqual(@as(?usize, 2), stats.remaining_capacity);

    try std.testing.expectEqualStrings("one", try runtime.run(takeEffect(@TypeOf(provider), []const u8)));

    try runtime.run(shutdownEffect(@TypeOf(provider), []const u8));
    try std.testing.expectError(
        error.QueueShutdown,
        runtime.run(offerEffect(@TypeOf(provider), []const u8, "after-close")),
    );
}

test "Queue offerEffect records backpressure when bounded queue is full" {
    const zstd = @import("../root.zig");
    const TextQueue = Service([]const u8);

    var queue = TextQueue.bounded(std.testing.allocator, 1);
    defer queue.deinit();
    var provider = zstd.Service.Provider(.{TextQueue}).init(.{&queue});
    var store = zstd.fx.CausalStore.init(std.testing.allocator);
    defer store.deinit();

    var runtime = zstd.fx.Runtime(@TypeOf(provider)).init(std.testing.allocator, &provider)
        .provides(.{TextQueue})
        .withCausalStore(&store);

    try runtime.run(offerEffect(@TypeOf(provider), []const u8, "one"));
    try std.testing.expectError(
        error.QueueFull,
        runtime.run(offerEffect(@TypeOf(provider), []const u8, "two")),
    );

    var snapshot = try store.snapshot(std.testing.allocator);
    defer snapshot.deinit();
    try std.testing.expect(zstd.Service.hasOperation(snapshot, TextQueue, "offer", "backpressure"));
}
