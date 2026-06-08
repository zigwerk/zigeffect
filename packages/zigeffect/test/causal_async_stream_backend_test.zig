const std = @import("std");
const fx = @import("zigeffect");
const conformance = @import("support/causal_backend_conformance.zig");

const FakeAsyncSink = struct {
    allocator: std.mem.Allocator,
    events: std.ArrayList(fx.CausalEvent) = .empty,
    fail_next: bool = false,
    flush_count: u64 = 0,

    pub fn init(allocator: std.mem.Allocator) FakeAsyncSink {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *FakeAsyncSink) void {
        for (self.events.items) |event| {
            fx.deinitCausalAsyncStreamEvent(self.allocator, event);
        }
        self.events.deinit(self.allocator);
    }

    pub fn sink(self: *FakeAsyncSink) fx.CausalAsyncStreamSink {
        return .{
            .state = self,
            .on_event = onFakeAsyncEvent,
            .flush = flushFakeAsyncSink,
        };
    }
};

fn onFakeAsyncEvent(raw: ?*anyopaque, event: fx.CausalEvent) anyerror!void {
    const state: *FakeAsyncSink = @ptrCast(@alignCast(raw.?));
    if (state.fail_next) {
        state.fail_next = false;
        return error.FakeAsyncSinkRejected;
    }

    const cloned = try fx.cloneCausalAsyncStreamEvent(state.allocator, event);
    errdefer fx.deinitCausalAsyncStreamEvent(state.allocator, cloned);
    try state.events.append(state.allocator, cloned);
}

fn flushFakeAsyncSink(raw: ?*anyopaque) anyerror!void {
    const state: *FakeAsyncSink = @ptrCast(@alignCast(raw.?));
    state.flush_count += 1;
}

fn eventsContainString(events: []const fx.CausalEvent, needle: []const u8) bool {
    for (events) |event| {
        if (std.mem.indexOf(u8, event.label, needle) != null) return true;
        if (std.mem.indexOf(u8, event.type_name, needle) != null) return true;
        if (std.mem.indexOf(u8, event.status, needle) != null) return true;
        if (std.mem.indexOf(u8, event.redacted_detail, needle) != null) return true;
    }
    return false;
}

test "async stream backend queues conformance events and exposes async_stream kind" {
    var backend_state = fx.CausalAsyncStreamBackendState.init(std.testing.allocator, .{});
    defer backend_state.deinit();

    var store = fx.CausalStore.initWithOptions(std.testing.allocator, conformance.standardStoreOptions());
    store.attachBackend(backend_state.backend());
    defer store.deinit();

    const ids = try conformance.recordStandardTrace(&store);
    try conformance.expectStandardStorePosture(&store, ids);

    try std.testing.expectEqual(fx.CausalBackendKind.async_stream, store.attachedBackendKind().?);
    try std.testing.expectEqual(@as(usize, 3), backend_state.eventCount());
    try std.testing.expectEqual(@as(u64, 3), backend_state.acceptedEventCount());
    try std.testing.expectEqual(@as(u64, 0), backend_state.drainedEventCount());
    try std.testing.expectEqual(@as(u64, 0), backend_state.failedEventCount());
    try std.testing.expectEqual(@as(u64, 0), backend_state.droppedEventCount());

    var snapshot = try backend_state.peekSnapshot(std.testing.allocator);
    defer snapshot.deinit();
    try std.testing.expectEqual(@as(usize, 3), snapshot.events.len);
    try std.testing.expectEqual(ids.started, snapshot.events[0].id);
    try std.testing.expectEqual(ids.retained_log, snapshot.events[1].id);
    try std.testing.expectEqual(ids.completed, snapshot.events[2].id);
    try std.testing.expect(eventsContainString(snapshot.events, "raw-secret") == false);
    try std.testing.expect(eventsContainString(snapshot.events, fx.causal_redaction_marker));
    try std.testing.expect(eventsContainString(snapshot.events, fx.causal_truncation_marker));
}

test "async stream peek leaves events queued and drain clears in order" {
    var backend_state = fx.CausalAsyncStreamBackendState.init(std.testing.allocator, .{});
    defer backend_state.deinit();

    var store = fx.CausalStore.init(std.testing.allocator);
    store.attachBackend(backend_state.backend());
    defer store.deinit();

    const root = try store.record(.{ .kind = .run_started, .label = "stream-run" });
    const child = try store.record(.{ .kind = .effect_completed, .parent_id = root, .status = "done" });

    var snapshot = try backend_state.peekSnapshot(std.testing.allocator);
    defer snapshot.deinit();
    try std.testing.expectEqual(@as(usize, 2), snapshot.events.len);
    try std.testing.expectEqual(@as(usize, 2), backend_state.eventCount());

    var drained = try backend_state.drain(std.testing.allocator);
    defer drained.deinit();
    try std.testing.expectEqual(@as(usize, 2), drained.events.len);
    try std.testing.expectEqual(root, drained.events[0].id);
    try std.testing.expectEqual(child, drained.events[1].id);
    try std.testing.expectEqual(@as(usize, 0), backend_state.eventCount());
    try std.testing.expectEqual(@as(u64, 2), backend_state.drainedEventCount());
}

test "async stream sink receives accepted events and flushes" {
    var fake = FakeAsyncSink.init(std.testing.allocator);
    defer fake.deinit();
    var backend_state = fx.CausalAsyncStreamBackendState.init(std.testing.allocator, .{
        .sink = fake.sink(),
    });
    defer backend_state.deinit();

    var store = fx.CausalStore.init(std.testing.allocator);
    store.attachBackend(backend_state.backend());
    defer store.deinit();

    const id = try store.record(.{ .kind = .run_started, .label = "sink-run" });
    try std.testing.expectEqual(@as(usize, 1), fake.events.items.len);
    try std.testing.expectEqual(id, fake.events.items[0].id);
    try std.testing.expectEqualStrings("sink-run", fake.events.items[0].label);

    try backend_state.flush();
    try std.testing.expectEqual(@as(u64, 1), fake.flush_count);
    try std.testing.expectEqual(@as(u64, 1), backend_state.flushedCount());
}

test "async stream sink failure fails closed without queueing" {
    var fake = FakeAsyncSink.init(std.testing.allocator);
    defer fake.deinit();
    fake.fail_next = true;
    var backend_state = fx.CausalAsyncStreamBackendState.init(std.testing.allocator, .{
        .sink = fake.sink(),
    });
    defer backend_state.deinit();

    var store = fx.CausalStore.init(std.testing.allocator);
    store.attachBackend(backend_state.backend());
    defer store.deinit();

    const id = try store.record(.{ .kind = .run_started, .label = "rejected" });
    try std.testing.expectEqual(@as(u64, 1), id);
    try std.testing.expectEqual(@as(usize, 0), backend_state.eventCount());
    try std.testing.expectEqual(@as(usize, 0), fake.events.items.len);
    try std.testing.expectEqual(@as(u64, 0), backend_state.acceptedEventCount());
    try std.testing.expectEqual(@as(u64, 1), backend_state.failedEventCount());
    try std.testing.expectEqual(@as(u64, 1), backend_state.droppedEventCount());
    try std.testing.expectEqual(@as(u64, 1), store.backendFailureCount());
}

test "async stream max_events fails before sink call" {
    var fake = FakeAsyncSink.init(std.testing.allocator);
    defer fake.deinit();
    var backend_state = fx.CausalAsyncStreamBackendState.init(std.testing.allocator, .{
        .max_events = 0,
        .sink = fake.sink(),
    });
    defer backend_state.deinit();

    var store = fx.CausalStore.init(std.testing.allocator);
    store.attachBackend(backend_state.backend());
    defer store.deinit();

    _ = try store.record(.{ .kind = .run_started, .label = "overflow" });
    try std.testing.expectEqual(@as(usize, 0), backend_state.eventCount());
    try std.testing.expectEqual(@as(usize, 0), fake.events.items.len);
    try std.testing.expectEqual(@as(u64, 1), backend_state.failedEventCount());
    try std.testing.expectEqual(@as(u64, 1), backend_state.droppedEventCount());
    try std.testing.expectEqual(@as(u64, 1), store.backendFailureCount());
}

test "async stream clear releases queued events without changing accepted count" {
    var backend_state = fx.CausalAsyncStreamBackendState.init(std.testing.allocator, .{});
    defer backend_state.deinit();

    var store = fx.CausalStore.init(std.testing.allocator);
    store.attachBackend(backend_state.backend());
    defer store.deinit();

    _ = try store.record(.{ .kind = .run_started, .label = "clear-me" });
    _ = try store.record(.{ .kind = .run_completed, .status = "ok" });

    try std.testing.expectEqual(@as(usize, 2), backend_state.eventCount());
    try std.testing.expectEqual(@as(u64, 2), backend_state.acceptedEventCount());
    backend_state.clear();
    try std.testing.expectEqual(@as(usize, 0), backend_state.eventCount());
    try std.testing.expectEqual(@as(u64, 2), backend_state.acceptedEventCount());
    try std.testing.expectEqual(@as(u64, 0), backend_state.drainedEventCount());
}
