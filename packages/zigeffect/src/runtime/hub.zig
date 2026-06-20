//! M5.4 — `Hub(T)`, the multi-subscriber broadcast primitive.
//!
//! Multiple subscribers each get their own copy of every published item.
//! Each subscriber owns a `Queue(T)` (the existing coordination primitive),
//! so per-subscriber backpressure semantics are uniform with `Queue`.
//!
//! Strategy on full subscriber queue:
//!   - bounded: publish returns `error.SubscriberFull` (caller decides what
//!     to do — retry, drop, etc.).
//!   - sliding: the OLDEST item in the subscriber's queue is dropped to make
//!     room for the new one. The slow subscriber "slides forward."
//!   - dropping: the NEW item is dropped for that subscriber only; other
//!     subscribers still receive it.
//!
//! Optional `CausalStore` integration emits `hub_published` once per publish
//! and `hub_received` once per subscriber that successfully accepted the item
//! (the load-bearing cause edge for downstream subscriber-resume queries).
//!
//! Single-threaded v1 — no atomics. Lifting to thread-safe in v2 (mutex around
//! `subscribers` + per-subscriber atomic queue) is source-compatible: callers
//! observe no difference.
//!
//! Hub is the substrate for:
//!   - Workbench live-attach (M10.1): a `CausalHubBackend` publishes events as
//!     they are recorded; the SolidJS bridge subscribes.
//!   - Agent-attach query interface (M8.8): an agent subscribes to a running
//!     `CausalStore` and iterates against streamed events.

const std = @import("std");
const coordination = @import("coordination.zig");
const causal_mod = @import("../services/causal.zig");

pub const Allocator = std.mem.Allocator;
pub const Queue = coordination.Queue;
pub const QueueOfferState = coordination.QueueOfferState;
pub const FiberPrimitiveError = coordination.FiberPrimitiveError;
pub const CausalStore = causal_mod.CausalStore;
pub const CausalEvent = causal_mod.CausalEvent;

pub const HubStrategy = enum {
    /// Block / fail at the publish boundary when any subscriber's queue is full.
    bounded,
    /// Drop the oldest item in the subscriber's queue to make room (slow subs
    /// fall behind, never block the publisher).
    sliding,
    /// Drop the new item for that subscriber only (slow subs lose new data).
    dropping,
};

pub const HubError = error{
    SubscriberFull,
    UnknownSubscription,
    OutOfMemory,
};

pub const SubscriptionId = u64;

pub fn Hub(comptime T: type) type {
    return struct {
        const Self = @This();

        const Subscriber = struct {
            id: SubscriptionId,
            queue: Queue(T),
            active: bool = true,
        };

        allocator: Allocator,
        strategy: HubStrategy,
        capacity: usize,
        next_subscription_id: SubscriptionId = 1,
        subscribers: std.ArrayList(Subscriber) = .empty,
        causal_store: ?*CausalStore = null,

        pub fn init(allocator: Allocator, strategy: HubStrategy, capacity: usize) Self {
            return .{ .allocator = allocator, .strategy = strategy, .capacity = capacity };
        }

        pub fn deinit(self: *Self) void {
            for (self.subscribers.items) |*sub| sub.queue.deinit();
            self.subscribers.deinit(self.allocator);
        }

        /// Attach a causal store. Subsequent publish/receive operations emit
        /// `hub_published` / `hub_received` events. Pass null to detach.
        pub fn withCausalStore(self: *Self, store: ?*CausalStore) void {
            self.causal_store = store;
        }

        pub fn subscriberCount(self: *const Self) usize {
            var n: usize = 0;
            for (self.subscribers.items) |sub| if (sub.active) {
                n += 1;
            };
            return n;
        }

        /// Register a new subscriber. Returns its `SubscriptionId`. The
        /// subscriber's queue receives every subsequently published item per
        /// the hub's strategy.
        pub fn subscribe(self: *Self) HubError!SubscriptionId {
            const id = self.next_subscription_id;
            self.next_subscription_id += 1;
            self.subscribers.append(self.allocator, .{
                .id = id,
                .queue = Queue(T).bounded(self.allocator, self.capacity),
            }) catch return error.OutOfMemory;
            return id;
        }

        /// Detach a subscriber. Its remaining items are discarded.
        pub fn unsubscribe(self: *Self, id: SubscriptionId) HubError!void {
            const idx = self.findSubscriberIndex(id) orelse return error.UnknownSubscription;
            self.subscribers.items[idx].queue.deinit();
            _ = self.subscribers.orderedRemove(idx);
        }

        /// Take the next item from the subscriber's queue, or null if empty.
        /// When `causal_store` is set, takes that succeed emit `hub_received`.
        pub fn take(self: *Self, id: SubscriptionId) HubError!?T {
            const idx = self.findSubscriberIndex(id) orelse return error.UnknownSubscription;
            const sub = &self.subscribers.items[idx];
            const item = sub.queue.take() catch |err| switch (err) {
                error.QueueEmpty => return null,
                else => return error.UnknownSubscription,
            };
            if (self.causal_store) |store| {
                _ = store.record(.{
                    .kind = .hub_received,
                    .status = "ready",
                    .label = "hub item received by subscriber",
                    .type_name = "Hub",
                    .schedule_id = id,
                }) catch {};
            }
            return item;
        }

        /// Broadcast `item` to every active subscriber per the hub's strategy.
        /// Returns:
        ///   - `error.SubscriberFull` if `strategy == .bounded` and any
        ///     subscriber's queue rejected the item;
        ///   - `error.OutOfMemory` if a strategy needed to grow a queue.
        /// Other strategies never error per subscriber; they silently degrade.
        pub fn publish(self: *Self, item: T) HubError!void {
            if (self.causal_store) |store| {
                _ = store.record(.{
                    .kind = .hub_published,
                    .status = "ready",
                    .label = "hub item published",
                    .type_name = "Hub",
                }) catch {};
            }
            for (self.subscribers.items) |*sub| {
                if (!sub.active) continue;
                self.offerToSubscriber(sub, item) catch |err| return err;
            }
        }

        fn offerToSubscriber(self: *Self, sub: *Subscriber, item: T) HubError!void {
            switch (self.strategy) {
                .bounded => sub.queue.offer(item) catch return error.SubscriberFull,
                .sliding => {
                    if (sub.queue.offerState() == .backpressured) {
                        // Drop oldest to make room.
                        _ = sub.queue.take() catch {};
                    }
                    sub.queue.offer(item) catch return error.OutOfMemory;
                },
                .dropping => {
                    if (sub.queue.offerState() == .backpressured) return; // drop new item
                    sub.queue.offer(item) catch return error.OutOfMemory;
                },
            }
        }

        fn findSubscriberIndex(self: *Self, id: SubscriptionId) ?usize {
            for (self.subscribers.items, 0..) |sub, i| {
                if (sub.id == id) return i;
            }
            return null;
        }
    };
}
