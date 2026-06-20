//! M5.6 — runnable example dogfooding the Track 5 state primitives:
//! `Ref(T)`, `SynchronizedRef(T)`, and `Hub(T)`.
//!
//! Run: `zig build effect-state-example` (or via `zig build examples`).

const std = @import("std");
const fx = @import("zigeffect");

fn increment(value: u32) u32 {
    return value + 1;
}

const DemoResult = struct {
    handled: u32,
    audit_ids: [3]u32,
    metrics_sum: u64,
};

/// A small worker model: a shared request counter (SynchronizedRef), a
/// per-request id allocator (Ref), and an event Hub two subscribers observe.
fn demo(allocator: std.mem.Allocator) !DemoResult {
    // Ref — a plain atomic cell for the next request id.
    var next_id = fx.Ref(u32).init(1000);

    // SynchronizedRef — a request counter whose updates are serialized.
    var request_count = fx.SynchronizedRef(u32).init(0);

    // Hub — broadcast each handled request id to two subscribers (an audit log
    // and a metrics sink), each with bounded backpressure.
    var hub = fx.Hub(u32).init(allocator, .bounded, 16);
    defer hub.deinit();
    const audit = try hub.subscribe();
    const metrics = try hub.subscribe();

    // Handle three requests.
    var i: usize = 0;
    while (i < 3) : (i += 1) {
        const id = next_id.update(increment); // allocate the next id
        _ = try request_count.update(increment); // bump the serialized counter
        try hub.publish(id); // broadcast to all subscribers
    }

    // Drain the audit subscriber (sees the full ordered stream).
    var audit_ids: [3]u32 = .{ 0, 0, 0 };
    var a: usize = 0;
    while (try hub.take(audit)) |id| : (a += 1) {
        if (a < audit_ids.len) audit_ids[a] = id;
    }

    // The metrics subscriber independently saw the same stream.
    var metrics_sum: u64 = 0;
    while (try hub.take(metrics)) |id| {
        metrics_sum += id;
    }

    return .{
        .handled = request_count.get(),
        .audit_ids = audit_ids,
        .metrics_sum = metrics_sum,
    };
}

pub fn main() !void {
    const result = try demo(std.heap.page_allocator);
    std.debug.print("handled={d} audit={d},{d},{d} metrics_sum={d}\n", .{
        result.handled,
        result.audit_ids[0],
        result.audit_ids[1],
        result.audit_ids[2],
        result.metrics_sum,
    });
}

test "effect_state example: Ref / SynchronizedRef / Hub cooperate over a worker loop" {
    const result = try demo(std.testing.allocator);

    // Three requests handled (SynchronizedRef counter).
    try std.testing.expectEqual(@as(u32, 3), result.handled);
    // Audit subscriber saw the three allocated ids in order (Ref + Hub FIFO).
    try std.testing.expectEqual([3]u32{ 1001, 1002, 1003 }, result.audit_ids);
    // Metrics subscriber independently summed the SAME stream: 1001+1002+1003.
    try std.testing.expectEqual(@as(u64, 3006), result.metrics_sum);
}
