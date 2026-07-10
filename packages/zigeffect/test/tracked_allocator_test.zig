const std = @import("std");
const fx = @import("zigeffect");

test "TrackedAllocator accounts allocation resize free and source identity" {
    var tracker = fx.TrackedAllocator.init(std.testing.allocator);
    defer tracker.deinit();
    const allocator = tracker.allocator();

    var bytes = try tracker.allocAt(u8, 16, 99);
    try std.testing.expectEqual(@as(?u64, 99), tracker.sourceRefFor(bytes.ptr));
    bytes = try allocator.realloc(bytes, 32);
    allocator.free(bytes);

    const snapshot = tracker.snapshot();
    try std.testing.expect(snapshot.allocations >= 1);
    try std.testing.expectEqual(snapshot.allocations, snapshot.frees);
    try std.testing.expectEqual(@as(usize, 0), snapshot.live_allocations);
    try std.testing.expectEqual(@as(usize, 0), snapshot.live_bytes);
    try std.testing.expect(snapshot.peak_bytes >= 16);
    try std.testing.expect(snapshot.resizes + snapshot.remaps >= 1);
    try std.testing.expectEqual(@as(usize, 0), snapshot.invalid_frees);
}

test "TrackedAllocator suppresses invalid and double frees and records violations" {
    var tracker = fx.TrackedAllocator.init(std.testing.allocator);
    defer tracker.deinit();
    const allocator = tracker.allocator();

    const bytes = try allocator.alloc(u8, 8);
    try std.testing.expect(tracker.freeChecked(bytes));
    try std.testing.expect(!tracker.freeChecked(bytes));
    var foreign: [4]u8 = undefined;
    const foreign_slice: []u8 = &foreign;
    try std.testing.expect(!tracker.freeChecked(foreign_slice));

    const snapshot = tracker.snapshot();
    try std.testing.expectEqual(@as(usize, 2), snapshot.invalid_frees);

    var store = fx.CausalStore.init(std.testing.allocator);
    defer store.deinit();
    try tracker.recordCausalSummary(&store, 1, 2, 77);
    var events = try store.snapshot(std.testing.allocator);
    defer events.deinit();
    try std.testing.expectEqual(@as(usize, 2), events.events.len);
    try std.testing.expectEqual(fx.CausalEventKind.metric_recorded, events.events[0].kind);
    try std.testing.expectEqual(fx.CausalEventKind.assertion_recorded, events.events[1].kind);
    try std.testing.expectEqualStrings("failure", events.events[1].status);
    try std.testing.expectEqual(@as(?u64, 77), events.events[1].source_ref_id);
}

test "TrackedAllocator reports OOM and releases live allocations on deinit" {
    var failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    var failed_tracker = fx.TrackedAllocator.init(failing.allocator());
    defer failed_tracker.deinit();
    try std.testing.expectError(error.OutOfMemory, failed_tracker.allocator().alloc(u8, 4));
    try std.testing.expectEqual(@as(usize, 1), failed_tracker.snapshot().out_of_memory);

    var tracker = fx.TrackedAllocator.init(std.testing.allocator);
    _ = try tracker.allocator().alloc(u8, 64);
    try std.testing.expectEqual(@as(usize, 1), tracker.snapshot().live_allocations);
    tracker.deinit();
}

const Worker = struct {
    tracker: *fx.TrackedAllocator,

    fn run(self: *Worker) void {
        const allocator = self.tracker.allocator();
        var index: usize = 0;
        while (index < 200) : (index += 1) {
            const bytes = allocator.alloc(u8, 24) catch return;
            allocator.free(bytes);
        }
    }
};

test "TrackedAllocator is safe under concurrent allocator use" {
    var tracker = fx.TrackedAllocator.init(std.testing.allocator);
    defer tracker.deinit();
    var workers: [4]Worker = undefined;
    var threads: [4]std.Thread = undefined;
    for (&workers, 0..) |*worker, index| {
        worker.* = .{ .tracker = &tracker };
        threads[index] = try std.Thread.spawn(.{}, Worker.run, .{worker});
    }
    for (&threads) |thread| thread.join();

    const snapshot = tracker.snapshot();
    try std.testing.expectEqual(@as(usize, 800), snapshot.allocations);
    try std.testing.expectEqual(@as(usize, 800), snapshot.frees);
    try std.testing.expectEqual(@as(usize, 0), snapshot.live_allocations);
    try std.testing.expectEqual(@as(usize, 0), snapshot.invalid_frees);
}
