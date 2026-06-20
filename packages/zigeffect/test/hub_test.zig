//! M5.4 — Hub(T) tests.

const std = @import("std");
const fx = @import("zigeffect");

test "Hub: publish reaches every subscriber, take drains in FIFO order" {
    var hub = fx.Hub(u32).init(std.testing.allocator, .bounded, 8);
    defer hub.deinit();

    const a = try hub.subscribe();
    const b = try hub.subscribe();
    try std.testing.expectEqual(@as(usize, 2), hub.subscriberCount());

    try hub.publish(1);
    try hub.publish(2);
    try hub.publish(3);

    try std.testing.expectEqual(@as(?u32, 1), try hub.take(a));
    try std.testing.expectEqual(@as(?u32, 2), try hub.take(a));
    try std.testing.expectEqual(@as(?u32, 3), try hub.take(a));
    try std.testing.expectEqual(@as(?u32, null), try hub.take(a));

    try std.testing.expectEqual(@as(?u32, 1), try hub.take(b));
    try std.testing.expectEqual(@as(?u32, 2), try hub.take(b));
    try std.testing.expectEqual(@as(?u32, 3), try hub.take(b));
}

test "Hub strategy=bounded: full subscriber queue returns SubscriberFull on publish" {
    var hub = fx.Hub(u32).init(std.testing.allocator, .bounded, 2);
    defer hub.deinit();
    _ = try hub.subscribe();

    try hub.publish(1);
    try hub.publish(2);
    const result = hub.publish(3);
    try std.testing.expectError(error.SubscriberFull, result);
}

test "Hub strategy=sliding: full queue drops oldest to admit new item" {
    var hub = fx.Hub(u32).init(std.testing.allocator, .sliding, 2);
    defer hub.deinit();
    const sub = try hub.subscribe();

    try hub.publish(1);
    try hub.publish(2);
    // Queue is now [1, 2]; publishing 3 should drop 1 (oldest).
    try hub.publish(3);

    try std.testing.expectEqual(@as(?u32, 2), try hub.take(sub));
    try std.testing.expectEqual(@as(?u32, 3), try hub.take(sub));
    try std.testing.expectEqual(@as(?u32, null), try hub.take(sub));
}

test "Hub strategy=dropping: full queue silently drops the new item" {
    var hub = fx.Hub(u32).init(std.testing.allocator, .dropping, 2);
    defer hub.deinit();
    const sub = try hub.subscribe();

    try hub.publish(1);
    try hub.publish(2);
    try hub.publish(3); // dropped — queue stays at [1, 2]

    try std.testing.expectEqual(@as(?u32, 1), try hub.take(sub));
    try std.testing.expectEqual(@as(?u32, 2), try hub.take(sub));
    try std.testing.expectEqual(@as(?u32, null), try hub.take(sub));
}

test "Hub.unsubscribe removes the subscriber; subsequent take returns UnknownSubscription" {
    var hub = fx.Hub(u32).init(std.testing.allocator, .bounded, 4);
    defer hub.deinit();
    const sub = try hub.subscribe();
    try hub.unsubscribe(sub);
    try std.testing.expectError(error.UnknownSubscription, hub.take(sub));
}

test "Hub with CausalStore emits hub_published / hub_received on the load-bearing edge" {
    var store = fx.CausalStore.init(std.testing.allocator);
    defer store.deinit();

    var hub = fx.Hub(u32).init(std.testing.allocator, .bounded, 4);
    defer hub.deinit();
    hub.withCausalStore(&store);

    const a = try hub.subscribe();
    const b = try hub.subscribe();
    try hub.publish(42);

    // Each subscriber takes once.
    _ = try hub.take(a);
    _ = try hub.take(b);

    var snap = try store.snapshot(std.testing.allocator);
    defer snap.deinit();

    var published: usize = 0;
    var received: usize = 0;
    for (snap.events) |event| {
        if (event.kind == .hub_published) published += 1;
        if (event.kind == .hub_received) received += 1;
    }
    try std.testing.expectEqual(@as(usize, 1), published);
    try std.testing.expectEqual(@as(usize, 2), received);
}

test "Hub: a subscriber that joins LATE does not receive prior items" {
    var hub = fx.Hub(u32).init(std.testing.allocator, .bounded, 4);
    defer hub.deinit();

    const early = try hub.subscribe();
    try hub.publish(1);
    try hub.publish(2);

    const late = try hub.subscribe();
    try hub.publish(3);

    // Early sub sees 1, 2, 3.
    try std.testing.expectEqual(@as(?u32, 1), try hub.take(early));
    try std.testing.expectEqual(@as(?u32, 2), try hub.take(early));
    try std.testing.expectEqual(@as(?u32, 3), try hub.take(early));

    // Late sub sees only 3.
    try std.testing.expectEqual(@as(?u32, 3), try hub.take(late));
    try std.testing.expectEqual(@as(?u32, null), try hub.take(late));
}
