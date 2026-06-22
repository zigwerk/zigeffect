//! M10.1 — CausalHubBackend (live-attach bridge) tests.

const std = @import("std");
const fx = @import("zigeffect");

test "CausalHubBackend streams recorded events to a subscriber as they happen" {
    const allocator = std.testing.allocator;

    var hub = fx.Hub(fx.CausalEvent).init(allocator, .sliding, 64);
    defer hub.deinit();
    const sub = try hub.subscribe();

    var bridge = fx.causal_hub_backend.CausalHubBackendState.init(&hub);
    var store = fx.CausalStore.init(allocator);
    defer store.deinit();
    store.attachBackend(bridge.backend());

    // Record three events into the store.
    _ = try store.record(.{ .kind = .run_started, .status = "started", .label = "a" });
    _ = try store.record(.{ .kind = .fiber_forked, .fiber_id = 1, .status = "pending", .label = "b" });
    _ = try store.record(.{ .kind = .run_completed, .status = "success", .label = "c" });

    // The subscriber observed all three, in order, via the live stream.
    try std.testing.expectEqual(@as(u64, 3), bridge.publishedCount());
    const e0 = (try hub.take(sub)).?;
    const e1 = (try hub.take(sub)).?;
    const e2 = (try hub.take(sub)).?;
    try std.testing.expectEqual(fx.CausalEventKind.run_started, e0.kind);
    try std.testing.expectEqual(fx.CausalEventKind.fiber_forked, e1.kind);
    try std.testing.expectEqual(fx.CausalEventKind.run_completed, e2.kind);
    // Event ids carried through (store-assigned, monotonic).
    try std.testing.expect(e0.id < e1.id and e1.id < e2.id);
    // No more pending.
    try std.testing.expectEqual(@as(?fx.CausalEvent, null), try hub.take(sub));
}

test "CausalHubBackend fans out to multiple live subscribers" {
    const allocator = std.testing.allocator;

    var hub = fx.Hub(fx.CausalEvent).init(allocator, .sliding, 64);
    defer hub.deinit();
    const a = try hub.subscribe();
    const b = try hub.subscribe();

    var bridge = fx.causal_hub_backend.CausalHubBackendState.init(&hub);
    var store = fx.CausalStore.init(allocator);
    defer store.deinit();
    store.attachBackend(bridge.backend());

    _ = try store.record(.{ .kind = .metric_recorded, .status = "ready", .label = "m" });

    // Both subscribers independently saw the event.
    try std.testing.expectEqual(fx.CausalEventKind.metric_recorded, (try hub.take(a)).?.kind);
    try std.testing.expectEqual(fx.CausalEventKind.metric_recorded, (try hub.take(b)).?.kind);
}

test "CausalHubBackend: a late subscriber only sees events recorded after it attaches" {
    const allocator = std.testing.allocator;

    var hub = fx.Hub(fx.CausalEvent).init(allocator, .sliding, 64);
    defer hub.deinit();
    const early = try hub.subscribe();

    var bridge = fx.causal_hub_backend.CausalHubBackendState.init(&hub);
    var store = fx.CausalStore.init(allocator);
    defer store.deinit();
    store.attachBackend(bridge.backend());

    _ = try store.record(.{ .kind = .run_started, .status = "started" });
    const late = try hub.subscribe();
    _ = try store.record(.{ .kind = .run_completed, .status = "success" });

    // Early sub sees both; late sub sees only the second.
    try std.testing.expectEqual(fx.CausalEventKind.run_started, (try hub.take(early)).?.kind);
    try std.testing.expectEqual(fx.CausalEventKind.run_completed, (try hub.take(early)).?.kind);
    try std.testing.expectEqual(fx.CausalEventKind.run_completed, (try hub.take(late)).?.kind);
    try std.testing.expectEqual(@as(?fx.CausalEvent, null), try hub.take(late));
}
