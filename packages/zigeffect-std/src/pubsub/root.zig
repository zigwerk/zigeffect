const std = @import("std");
const StdService = @import("../service/root.zig");
const fx = @import("zigeffect");

pub const Strategy = fx.HubStrategy;
pub const SubscriptionId = fx.SubscriptionId;
pub const PubSubError = fx.HubError;

pub fn Service(comptime Item: type) type {
    return struct {
        const Self = @This();

        hub: fx.Hub(Item),

        pub fn init(allocator: std.mem.Allocator, strategy: Strategy, capacity: usize) Self {
            return .{ .hub = fx.Hub(Item).init(allocator, strategy, capacity) };
        }

        pub fn deinit(self: *Self) void {
            self.hub.deinit();
        }

        pub fn subscribe(self: *Self) PubSubError!SubscriptionId {
            return self.hub.subscribe();
        }

        pub fn unsubscribe(self: *Self, id: SubscriptionId) PubSubError!void {
            return self.hub.unsubscribe(id);
        }

        pub fn publish(self: *Self, item: Item) PubSubError!void {
            return self.hub.publish(item);
        }

        pub fn take(self: *Self, id: SubscriptionId) PubSubError!?Item {
            return self.hub.take(id);
        }

        pub fn subscriberCount(self: *Self) usize {
            return self.hub.subscriberCount();
        }
    };
}

pub fn SubscribeEffect(comptime EffectEnv: type, comptime Item: type) type {
    const PubSubService = Service(Item);
    return struct {
        pub const SuccessType = SubscriptionId;
        pub const FailureType = PubSubError;
        pub const EnvType = EffectEnv;
        pub const RequiredServices = .{PubSubService};

        pub fn requiredServices(allocator: std.mem.Allocator) std.mem.Allocator.Error!fx.ServiceSet {
            return fx.ServiceSet.fromTypes(allocator, RequiredServices);
        }

        pub fn run(_: @This(), ctx: *fx.Context(EffectEnv)) FailureType!SubscriptionId {
            const pubsub = ctx.service(PubSubService);
            const id = pubsub.subscribe() catch |err| {
                _ = StdService.recordOperation(ctx, PubSubService, "subscribe", "failure", @typeName(Item));
                return err;
            };
            _ = StdService.recordOperation(ctx, PubSubService, "subscribe", "success", @typeName(Item));
            return id;
        }
    };
}

pub fn PublishEffect(comptime EffectEnv: type, comptime Item: type) type {
    const PubSubService = Service(Item);
    return struct {
        pub const SuccessType = void;
        pub const FailureType = PubSubError;
        pub const EnvType = EffectEnv;
        pub const RequiredServices = .{PubSubService};

        item: Item,

        pub fn requiredServices(allocator: std.mem.Allocator) std.mem.Allocator.Error!fx.ServiceSet {
            return fx.ServiceSet.fromTypes(allocator, RequiredServices);
        }

        pub fn run(self: @This(), ctx: *fx.Context(EffectEnv)) FailureType!void {
            const pubsub = ctx.service(PubSubService);
            pubsub.publish(self.item) catch |err| {
                _ = StdService.recordOperation(ctx, PubSubService, "publish", publishFailureStatus(err), @typeName(Item));
                return err;
            };
            _ = StdService.recordOperation(ctx, PubSubService, "publish", "success", @typeName(Item));
        }
    };
}

pub fn TakeEffect(comptime EffectEnv: type, comptime Item: type) type {
    const PubSubService = Service(Item);
    return struct {
        pub const SuccessType = ?Item;
        pub const FailureType = PubSubError;
        pub const EnvType = EffectEnv;
        pub const RequiredServices = .{PubSubService};

        id: SubscriptionId,

        pub fn requiredServices(allocator: std.mem.Allocator) std.mem.Allocator.Error!fx.ServiceSet {
            return fx.ServiceSet.fromTypes(allocator, RequiredServices);
        }

        pub fn run(self: @This(), ctx: *fx.Context(EffectEnv)) FailureType!?Item {
            const pubsub = ctx.service(PubSubService);
            const item = pubsub.take(self.id) catch |err| {
                _ = StdService.recordOperation(ctx, PubSubService, "take", takeFailureStatus(err), @typeName(Item));
                return err;
            };
            _ = StdService.recordOperation(ctx, PubSubService, "take", if (item == null) "empty" else "success", @typeName(Item));
            return item;
        }
    };
}

pub fn UnsubscribeEffect(comptime EffectEnv: type, comptime Item: type) type {
    const PubSubService = Service(Item);
    return struct {
        pub const SuccessType = void;
        pub const FailureType = PubSubError;
        pub const EnvType = EffectEnv;
        pub const RequiredServices = .{PubSubService};

        id: SubscriptionId,

        pub fn requiredServices(allocator: std.mem.Allocator) std.mem.Allocator.Error!fx.ServiceSet {
            return fx.ServiceSet.fromTypes(allocator, RequiredServices);
        }

        pub fn run(self: @This(), ctx: *fx.Context(EffectEnv)) FailureType!void {
            const pubsub = ctx.service(PubSubService);
            pubsub.unsubscribe(self.id) catch |err| {
                _ = StdService.recordOperation(ctx, PubSubService, "unsubscribe", takeFailureStatus(err), @typeName(Item));
                return err;
            };
            _ = StdService.recordOperation(ctx, PubSubService, "unsubscribe", "success", @typeName(Item));
        }
    };
}

pub fn subscribeEffect(comptime EffectEnv: type, comptime Item: type) SubscribeEffect(EffectEnv, Item) {
    return .{};
}

pub fn publishEffect(comptime EffectEnv: type, comptime Item: type, item: Item) PublishEffect(EffectEnv, Item) {
    return .{ .item = item };
}

pub fn takeEffect(comptime EffectEnv: type, comptime Item: type, id: SubscriptionId) TakeEffect(EffectEnv, Item) {
    return .{ .id = id };
}

pub fn unsubscribeEffect(comptime EffectEnv: type, comptime Item: type, id: SubscriptionId) UnsubscribeEffect(EffectEnv, Item) {
    return .{ .id = id };
}

fn publishFailureStatus(err: anyerror) []const u8 {
    return switch (err) {
        error.SubscriberFull => "backpressure",
        else => "failure",
    };
}

fn takeFailureStatus(err: anyerror) []const u8 {
    return switch (err) {
        error.UnknownSubscription => "unknown_subscription",
        else => "failure",
    };
}

test "PubSub service broadcasts to multiple subscribers through effects" {
    const zstd = @import("../root.zig");
    const TextPubSub = Service([]const u8);

    var pubsub = TextPubSub.init(std.testing.allocator, .bounded, 2);
    defer pubsub.deinit();
    var provider = zstd.Service.Provider(.{TextPubSub}).init(.{&pubsub});
    var runtime = zstd.fx.Runtime(@TypeOf(provider)).init(std.testing.allocator, &provider)
        .provides(.{TextPubSub});

    const first = try runtime.run(subscribeEffect(@TypeOf(provider), []const u8));
    const second = try runtime.run(subscribeEffect(@TypeOf(provider), []const u8));

    try runtime.run(publishEffect(@TypeOf(provider), []const u8, "event-one"));

    try std.testing.expectEqualStrings("event-one", (try runtime.run(takeEffect(@TypeOf(provider), []const u8, first))).?);
    try std.testing.expectEqualStrings("event-one", (try runtime.run(takeEffect(@TypeOf(provider), []const u8, second))).?);

    try runtime.run(unsubscribeEffect(@TypeOf(provider), []const u8, first));
    try runtime.run(publishEffect(@TypeOf(provider), []const u8, "event-two"));

    try std.testing.expectError(error.UnknownSubscription, runtime.run(takeEffect(@TypeOf(provider), []const u8, first)));
    try std.testing.expectEqualStrings("event-two", (try runtime.run(takeEffect(@TypeOf(provider), []const u8, second))).?);
}

test "PubSub publishEffect records backpressure for bounded subscribers" {
    const zstd = @import("../root.zig");
    const TextPubSub = Service([]const u8);

    var pubsub = TextPubSub.init(std.testing.allocator, .bounded, 1);
    defer pubsub.deinit();
    var provider = zstd.Service.Provider(.{TextPubSub}).init(.{&pubsub});
    var store = zstd.fx.CausalStore.init(std.testing.allocator);
    defer store.deinit();

    var runtime = zstd.fx.Runtime(@TypeOf(provider)).init(std.testing.allocator, &provider)
        .provides(.{TextPubSub})
        .withCausalStore(&store);

    _ = try runtime.run(subscribeEffect(@TypeOf(provider), []const u8));
    try runtime.run(publishEffect(@TypeOf(provider), []const u8, "one"));
    try std.testing.expectError(
        error.SubscriberFull,
        runtime.run(publishEffect(@TypeOf(provider), []const u8, "two")),
    );

    var snapshot = try store.snapshot(std.testing.allocator);
    defer snapshot.deinit();
    try std.testing.expect(zstd.Service.hasOperation(snapshot, TextPubSub, "publish", "backpressure"));
}
