//! Multi-threading lift — stress tests with REAL OS threads proving the
//! thread-safety of CausalStore.record, Ref.update, and Hub.publish/take.
//!
//! Each test spawns N std.Thread workers hammering a shared primitive, joins
//! them (the quiescent barrier), then asserts the final state is exactly
//! consistent — no lost updates, no torn writes, no corrupted containers. Run
//! under `std.testing.allocator` so leaks/UAF surface too.

const std = @import("std");
const fx = @import("zigeffect");

const THREADS = 8;
const OPS_PER_THREAD = 2000;

// ── CausalStore.record under concurrent writers ──

const StoreWorker = struct {
    store: *fx.CausalStore,
    fn run(self: *StoreWorker) void {
        var i: usize = 0;
        while (i < OPS_PER_THREAD) : (i += 1) {
            _ = self.store.record(.{ .kind = .metric_recorded, .status = "ready", .label = "x" }) catch {};
        }
    }
};

test "CausalStore.record is safe under concurrent OS threads (every event recorded, ids unique)" {
    const allocator = std.testing.allocator;
    var store = fx.CausalStore.init(allocator);
    defer store.deinit();

    var workers: [THREADS]StoreWorker = undefined;
    var threads: [THREADS]std.Thread = undefined;
    for (&workers, 0..) |*w, i| {
        w.* = .{ .store = &store };
        threads[i] = try std.Thread.spawn(.{}, StoreWorker.run, .{w});
    }
    for (&threads) |t| t.join(); // quiescent barrier

    // Every record from every thread landed — no lost appends.
    var snap = try store.snapshot(allocator);
    defer snap.deinit();
    try std.testing.expectEqual(@as(usize, THREADS * OPS_PER_THREAD), snap.events.len);

    // Event ids are unique (no two threads got the same id) and form the
    // contiguous range 1..=N (the counter was incremented exactly once each).
    var seen = std.AutoHashMap(u64, void).init(allocator);
    defer seen.deinit();
    var max_id: u64 = 0;
    for (snap.events) |e| {
        try std.testing.expect(!seen.contains(e.id)); // unique
        try seen.put(e.id, {});
        if (e.id > max_id) max_id = e.id;
    }
    try std.testing.expectEqual(@as(u64, THREADS * OPS_PER_THREAD), max_id);
}

// ── Ref.update under concurrent read-modify-write ──

fn incr(x: u64) u64 {
    return x + 1;
}

const RefWorker = struct {
    ref: *fx.Ref(u64),
    fn run(self: *RefWorker) void {
        var i: usize = 0;
        while (i < OPS_PER_THREAD) : (i += 1) {
            _ = self.ref.update(incr);
        }
    }
};

test "Ref.update is safe under concurrent OS threads (no lost increments)" {
    const allocator = std.testing.allocator;
    _ = allocator;
    var ref = fx.Ref(u64).init(0);

    var workers: [THREADS]RefWorker = undefined;
    var threads: [THREADS]std.Thread = undefined;
    for (&workers, 0..) |*w, i| {
        w.* = .{ .ref = &ref };
        threads[i] = try std.Thread.spawn(.{}, RefWorker.run, .{w});
    }
    for (&threads) |t| t.join();

    // Every increment is accounted for — a torn read-modify-write would lose some.
    try std.testing.expectEqual(@as(u64, THREADS * OPS_PER_THREAD), ref.get());
}

// ── Hub.publish under concurrent publishers ──

const HubWorker = struct {
    hub: *fx.Hub(u32),
    fn run(self: *HubWorker) void {
        var i: usize = 0;
        while (i < OPS_PER_THREAD) : (i += 1) {
            self.hub.publish(1) catch {};
        }
    }
};

test "Hub.publish/take is safe under concurrent OS threads (subscriber sees every item)" {
    const allocator = std.testing.allocator;
    // A sliding hub with ample capacity so no publish is dropped for capacity.
    var hub = fx.Hub(u32).init(allocator, .sliding, THREADS * OPS_PER_THREAD + 16);
    defer hub.deinit();
    const sub = try hub.subscribe();

    var workers: [THREADS]HubWorker = undefined;
    var threads: [THREADS]std.Thread = undefined;
    for (&workers, 0..) |*w, i| {
        w.* = .{ .hub = &hub };
        threads[i] = try std.Thread.spawn(.{}, HubWorker.run, .{w});
    }
    for (&threads) |t| t.join();

    // Drain the subscriber — it must have received exactly every published item,
    // with no corruption of the underlying queue.
    var count: usize = 0;
    while (try hub.take(sub)) |_| count += 1;
    try std.testing.expectEqual(@as(usize, THREADS * OPS_PER_THREAD), count);
}
