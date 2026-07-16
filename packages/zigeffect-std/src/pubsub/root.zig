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

pub fn API(comptime Item: type) type {
    return struct {
        pub const operations: []const []const u8 = &.{ "PubSub.subscribe", "PubSub.publish", "PubSub.take", "PubSub.unsubscribe" };
        service: *Service(Item),
        pub fn subscribe(self: @This()) PubSubError!SubscriptionId {
            return self.service.subscribe();
        }
        pub fn publish(self: @This(), item: Item) PubSubError!void {
            return self.service.publish(item);
        }
        pub fn take(self: @This(), id: SubscriptionId) PubSubError!?Item {
            return self.service.take(id);
        }
        pub fn unsubscribe(self: @This(), id: SubscriptionId) PubSubError!void {
            return self.service.unsubscribe(id);
        }
    };
}

pub fn PubSub(comptime Item: type) type {
    return fx.kernel.Service("zigeffect/std/PubSub/" ++ @typeName(Item), API(Item));
}

pub fn layer(comptime Item: type, service: *Service(Item)) @TypeOf(
    fx.kernel.Layer.succeed(PubSub(Item), API(Item){ .service = service }),
) {
    return fx.kernel.Layer.succeed(PubSub(Item), .{ .service = service });
}

fn record(ctx: anytype, comptime Item: type, operation: []const u8, status: []const u8) void {
    _ = StdService.recordSemantic(ctx, .span_recorded, PubSub(Item).service_key, operation, status, @typeName(Item));
}

pub fn subscribe(comptime Item: type) fx.kernel.Effect(SubscriptionId, PubSubError, .{PubSub(Item)}) {
    const Subscribe = fx.kernel.Effect(SubscriptionId, PubSubError, .{PubSub(Item)});
    return Subscribe.fromFn(struct {
        fn run(ctx: *Subscribe.Context) PubSubError!SubscriptionId {
            const id = ctx.service(PubSub(Item)).subscribe() catch |failure| {
                record(ctx, Item, "PubSub.subscribe", "failure");
                return failure;
            };
            record(ctx, Item, "PubSub.subscribe", "success");
            return id;
        }
    }.run);
}

pub fn publish(comptime Item: type, item: Item) fx.kernel.Effect(void, PubSubError, .{PubSub(Item)}).Stateful(Item) {
    const Publish = fx.kernel.Effect(void, PubSubError, .{PubSub(Item)});
    return Publish.fromState(Item, item, struct {
        fn run(value: Item, ctx: *Publish.Context) PubSubError!void {
            ctx.service(PubSub(Item)).publish(value) catch |failure| {
                record(ctx, Item, "PubSub.publish", publishFailureStatus(failure));
                return failure;
            };
            record(ctx, Item, "PubSub.publish", "success");
        }
    }.run);
}

pub fn take(comptime Item: type, id: SubscriptionId) fx.kernel.Effect(?Item, PubSubError, .{PubSub(Item)}).Stateful(SubscriptionId) {
    const Take = fx.kernel.Effect(?Item, PubSubError, .{PubSub(Item)});
    return Take.fromState(SubscriptionId, id, struct {
        fn run(value: SubscriptionId, ctx: *Take.Context) PubSubError!?Item {
            const item = ctx.service(PubSub(Item)).take(value) catch |failure| {
                record(ctx, Item, "PubSub.take", takeFailureStatus(failure));
                return failure;
            };
            record(ctx, Item, "PubSub.take", if (item == null) "empty" else "success");
            return item;
        }
    }.run);
}

pub fn unsubscribe(comptime Item: type, id: SubscriptionId) fx.kernel.Effect(void, PubSubError, .{PubSub(Item)}).Stateful(SubscriptionId) {
    const Unsubscribe = fx.kernel.Effect(void, PubSubError, .{PubSub(Item)});
    return Unsubscribe.fromState(SubscriptionId, id, struct {
        fn run(value: SubscriptionId, ctx: *Unsubscribe.Context) PubSubError!void {
            ctx.service(PubSub(Item)).unsubscribe(value) catch |failure| {
                record(ctx, Item, "PubSub.unsubscribe", takeFailureStatus(failure));
                return failure;
            };
            record(ctx, Item, "PubSub.unsubscribe", "success");
        }
    }.run);
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
    const TextPubSub = Service([]const u8);

    var pubsub = TextPubSub.init(std.testing.allocator, .bounded, 2);
    defer pubsub.deinit();
    const root = layer([]const u8, &pubsub);
    var runtime = try fx.kernel.ManagedRuntime(@TypeOf(root)).make(std.testing.allocator, root, .{});
    defer runtime.deinit();

    const first = try runtime.run(subscribe([]const u8));
    const second = try runtime.run(subscribe([]const u8));

    try runtime.run(publish([]const u8, "event-one"));

    try std.testing.expectEqualStrings("event-one", (try runtime.run(take([]const u8, first))).?);
    try std.testing.expectEqualStrings("event-one", (try runtime.run(take([]const u8, second))).?);

    try runtime.run(unsubscribe([]const u8, first));
    try runtime.run(publish([]const u8, "event-two"));

    try std.testing.expectError(error.UnknownSubscription, runtime.run(take([]const u8, first)));
    try std.testing.expectEqualStrings("event-two", (try runtime.run(take([]const u8, second))).?);
}

test "PubSub publishEffect records backpressure for bounded subscribers" {
    const TextPubSub = Service([]const u8);

    var pubsub = TextPubSub.init(std.testing.allocator, .bounded, 1);
    defer pubsub.deinit();
    const root = layer([]const u8, &pubsub);
    var store = fx.CausalStore.init(std.testing.allocator);
    defer store.deinit();
    var runtime = try fx.kernel.ManagedRuntime(@TypeOf(root)).make(std.testing.allocator, root, .{ .causal_store = &store });
    defer runtime.deinit();

    _ = try runtime.run(subscribe([]const u8));
    try runtime.run(publish([]const u8, "one"));
    try std.testing.expectError(
        error.SubscriberFull,
        runtime.run(publish([]const u8, "two")),
    );

    var snapshot = try store.snapshot(std.testing.allocator);
    defer snapshot.deinit();
    try std.testing.expect(StdService.hasOperation(snapshot, PubSub([]const u8), "PubSub.publish", "backpressure"));
}
