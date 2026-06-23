//! M10.1 — `CausalHubBackend`, the engine-side live-attach bridge.
//!
//! A `CausalBackend` that republishes every recorded `CausalEvent` to a
//! `Hub(CausalEvent)`, so a workbench (or an agent) can SUBSCRIBE to a running
//! store and observe events as they happen — the engine half of live-attach.
//! (The SolidJS rendering that consumes the stream is separate frontend work;
//! this is the data path it plugs into.)
//!
//! LIFETIME: published events carry the store's string slices by reference (the
//! store retains the originals). Subscribers must consume promptly — i.e. while
//! the store is alive — which is the live-attach pattern. Do NOT hold a taken
//! event past the store's deinit.
//!
//! DEADLOCK SAFETY: the store calls this backend's `record` while holding the
//! store mutex, and `record` publishes under the Hub mutex (ordering:
//! store → hub). Therefore the live-attach Hub MUST NOT have a causal store
//! attached (`hub.withCausalStore`), or `publish → store.record → publish`
//! would both recurse and invert the lock order. The Hub here is a plain
//! event stream.

const std = @import("std");
const causal = @import("causal.zig");
const causal_backend = @import("causal_backend.zig");
const causal_jsonl_backend = @import("causal_jsonl_backend.zig");
const hub_mod = @import("../runtime/hub.zig");
const sync = @import("../runtime/sync.zig");

pub const Allocator = std.mem.Allocator;
pub const CausalEvent = causal.CausalEvent;
pub const EventHub = hub_mod.Hub(CausalEvent);
pub const SubscriptionId = hub_mod.SubscriptionId;

pub const CausalHubBackendState = struct {
    hub: *EventHub,
    published_count: u64 = 0,
    dropped_count: u64 = 0,

    pub fn init(hub: *EventHub) CausalHubBackendState {
        return .{ .hub = hub };
    }

    pub fn backend(self: *CausalHubBackendState) causal_backend.CausalBackend {
        return .{
            // The Hub is a non-blocking live event stream for async consumers.
            .kind = .async_stream,
            .state = self,
            .record = recordHubBackend,
        };
    }

    pub fn publishedCount(self: *const CausalHubBackendState) u64 {
        return self.published_count;
    }

    pub fn droppedCount(self: *const CausalHubBackendState) u64 {
        return self.dropped_count;
    }
};

fn recordHubBackend(raw: ?*anyopaque, event: CausalEvent) anyerror!void {
    const state: *CausalHubBackendState = @ptrCast(@alignCast(raw.?));
    // Best-effort live stream: a full / sliding subscriber may drop, which is
    // fine for live observation. We never fail the originating record.
    state.hub.publish(event) catch {
        state.dropped_count += 1;
        return;
    };
    state.published_count += 1;
}

/// `CausalNdjsonTap` — the engine-side NDJSON feed for an external live-attach
/// collector. A `CausalBackend` that, on each recorded event, serializes it to an
/// NDJSON line (via `formatCausalJsonLine`) IMMEDIATELY — while the event's
/// string slices are still valid (the call is synchronous inside the store's
/// `record`) — and appends the OWNED bytes to an internal lock-guarded buffer.
/// `drain` moves the buffered NDJSON out.
///
/// Why not reuse the `Hub(CausalEvent)` path: the hub queues event STRUCTS, whose
/// `[]const u8` slices borrow store-owned heap. A bounded store's retention trim
/// (or `deinit`) frees those slices while an undrained queue copy still
/// references them — a use-after-free for a periodically-draining collector. By
/// serializing eagerly under the record call, this tap never retains a borrowed
/// slice past its lifetime, so it is safe with bounded stores and arbitrary drain
/// latency. It is single-consumer (one collector) and thread-safe.
pub const CausalNdjsonTapState = struct {
    allocator: Allocator,
    mutex: sync.SpinLock = .{},
    buffer: std.ArrayList(u8) = .empty,
    buffered_lines: u64 = 0,
    recorded_count: u64 = 0,
    failed_count: u64 = 0,

    pub fn init(allocator: Allocator) CausalNdjsonTapState {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *CausalNdjsonTapState) void {
        self.buffer.deinit(self.allocator);
    }

    pub fn backend(self: *CausalNdjsonTapState) causal_backend.CausalBackend {
        return .{
            .kind = .async_stream,
            .state = self,
            .record = recordNdjsonTap,
        };
    }

    /// Move the buffered NDJSON into `out` and clear the buffer. Returns the
    /// number of NDJSON lines moved. If appending to `out` fails (OOM) the
    /// internal buffer is left intact so the drain can be retried without losing
    /// events.
    pub fn drain(self: *CausalNdjsonTapState, out: *std.ArrayList(u8)) !usize {
        self.mutex.lock();
        defer self.mutex.unlock();
        if (self.buffer.items.len == 0) return 0;
        try out.appendSlice(self.allocator, self.buffer.items); // buffer intact on error
        const lines = self.buffered_lines;
        self.buffer.clearRetainingCapacity();
        self.buffered_lines = 0;
        return lines;
    }

    pub fn pendingBytes(self: *CausalNdjsonTapState) usize {
        self.mutex.lock();
        defer self.mutex.unlock();
        return self.buffer.items.len;
    }

    pub fn failedCount(self: *const CausalNdjsonTapState) u64 {
        return self.failed_count;
    }
};

fn recordNdjsonTap(raw: ?*anyopaque, event: CausalEvent) anyerror!void {
    const state: *CausalNdjsonTapState = @ptrCast(@alignCast(raw.?));
    // Serialize NOW, while the event's slices are valid. Best-effort: a
    // serialization/append failure is counted, never propagated — we must not
    // fail the originating store.record.
    const line = causal_jsonl_backend.formatCausalJsonLine(state.allocator, event) catch {
        state.failed_count += 1;
        return;
    };
    defer state.allocator.free(line);
    state.mutex.lock();
    defer state.mutex.unlock();
    state.buffer.appendSlice(state.allocator, line) catch {
        state.failed_count += 1;
        return;
    };
    state.buffered_lines += 1;
    state.recorded_count += 1;
}

test "CausalNdjsonTap serializes recorded events to NDJSON for the collector feed" {
    const allocator = std.testing.allocator;
    const CausalStore = causal.CausalStore;

    var tap = CausalNdjsonTapState.init(allocator);
    defer tap.deinit();

    var store = CausalStore.init(allocator);
    defer store.deinit();
    store.attachBackend(tap.backend());

    const run = try store.record(.{ .kind = .run_started, .run_id = 1, .status = "started", .label = "collector feed" });
    _ = try store.record(.{ .kind = .scope_opened, .run_id = 1, .scope_id = 2, .parent_id = run, .status = "opened", .label = "scope" });

    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try std.testing.expectEqual(@as(usize, 2), try tap.drain(&out));

    var lines = std.mem.tokenizeScalar(u8, out.items, '\n');
    const first = lines.next() orelse return error.MissingLine;
    try std.testing.expect(std.mem.indexOf(u8, first, "\"kind\":\"run_started\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, first, "\"id\":") != null);
    const second = lines.next() orelse return error.MissingLine;
    try std.testing.expect(std.mem.indexOf(u8, second, "\"kind\":\"scope_opened\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, second, "\"parent_id\":") != null);
    try std.testing.expect(lines.next() == null);

    // Draining again yields nothing (the buffer was moved out).
    out.clearRetainingCapacity();
    try std.testing.expectEqual(@as(usize, 0), try tap.drain(&out));
}

test "CausalNdjsonTap is UAF-safe with a BOUNDED store whose retention trims older events" {
    const allocator = std.testing.allocator;
    const CausalStore = causal.CausalStore;

    // A store that retains only ONE event — every new record trims (and frees the
    // strings of) the previous one. The hub path would dangle here; the tap
    // serialized each event under its own record call, so it is safe.
    var store = CausalStore.initBounded(allocator, 1);
    defer store.deinit();
    var tap = CausalNdjsonTapState.init(allocator);
    defer tap.deinit();
    store.attachBackend(tap.backend());

    _ = try store.record(.{ .kind = .run_started, .run_id = 1, .status = "started", .label = "first-event-label" });
    _ = try store.record(.{ .kind = .metric_recorded, .run_id = 1, .status = "ready", .label = "second-event-label" });
    _ = try store.record(.{ .kind = .run_completed, .run_id = 1, .status = "success", .label = "third-event-label" });

    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try std.testing.expectEqual(@as(usize, 3), try tap.drain(&out));
    // All three labels survived in the NDJSON despite the store trimming to 1.
    try std.testing.expect(std.mem.indexOf(u8, out.items, "first-event-label") != null);
    try std.testing.expect(std.mem.indexOf(u8, out.items, "second-event-label") != null);
    try std.testing.expect(std.mem.indexOf(u8, out.items, "third-event-label") != null);
}
