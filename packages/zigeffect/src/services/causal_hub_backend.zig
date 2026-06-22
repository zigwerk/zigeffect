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
const hub_mod = @import("../runtime/hub.zig");

pub const Allocator = std.mem.Allocator;
pub const CausalEvent = causal.CausalEvent;
pub const EventHub = hub_mod.Hub(CausalEvent);

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
