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

/// Drain every currently-queued event from a `Hub(CausalEvent)` subscription,
/// appending each as an NDJSON line (via `formatCausalJsonLine`, one object per
/// line, `\n`-terminated) to `out`. Returns the number of events drained.
///
/// This is the engine-side feed for an external live-attach collector: a
/// long-lived consumer `subscribe`s once, then drains periodically and pipes
/// `out` to the collector (stdout / socket / file). The collector maps each
/// NDJSON line to a workbench `LiveFrame` and fans it out to browsers.
pub fn drainHubToNdjson(
    allocator: Allocator,
    hub: *EventHub,
    subscription: SubscriptionId,
    out: *std.ArrayList(u8),
) !usize {
    var count: usize = 0;
    while (try hub.take(subscription)) |event| {
        const line = try causal_jsonl_backend.formatCausalJsonLine(allocator, event);
        defer allocator.free(line);
        try out.appendSlice(allocator, line);
        count += 1;
    }
    return count;
}

test "drainHubToNdjson serializes a subscription's events as NDJSON for the collector feed" {
    const allocator = std.testing.allocator;
    const CausalStore = causal.CausalStore;

    var hub = EventHub.init(allocator, .sliding, 64);
    defer hub.deinit();
    var hub_backend = CausalHubBackendState.init(&hub);

    var store = CausalStore.init(allocator);
    defer store.deinit();
    store.attachBackend(hub_backend.backend());

    // A subscriber must exist BEFORE events are recorded (the hub broadcasts to
    // current subscribers).
    const sub = try hub.subscribe();

    const run = try store.record(.{ .kind = .run_started, .run_id = 1, .status = "started", .label = "collector feed" });
    _ = try store.record(.{ .kind = .scope_opened, .run_id = 1, .scope_id = 2, .parent_id = run, .status = "opened", .label = "scope" });

    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    const drained = try drainHubToNdjson(allocator, &hub, sub, &out);
    try std.testing.expectEqual(@as(usize, 2), drained);

    // Two NDJSON lines, each a complete JSON object with the canonical field names.
    var lines = std.mem.tokenizeScalar(u8, out.items, '\n');
    const first = lines.next() orelse return error.MissingLine;
    try std.testing.expect(std.mem.indexOf(u8, first, "\"kind\":\"run_started\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, first, "\"id\":") != null);
    const second = lines.next() orelse return error.MissingLine;
    try std.testing.expect(std.mem.indexOf(u8, second, "\"kind\":\"scope_opened\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, second, "\"parent_id\":") != null);
    try std.testing.expect(lines.next() == null);

    // Draining again yields nothing (the queue was consumed).
    out.clearRetainingCapacity();
    try std.testing.expectEqual(@as(usize, 0), try drainHubToNdjson(allocator, &hub, sub, &out));
}
