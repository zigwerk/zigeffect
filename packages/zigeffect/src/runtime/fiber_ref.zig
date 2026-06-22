//! M5.3 (first cut) — `FiberRef(T)`, fiber-local state with snapshot-on-fork.
//!
//! A FiberRef is a value cell that a fiber owns. When a fiber forks a child, the
//! child gets its OWN cell seeded with a SNAPSHOT of the parent's current value
//! (`forkChild`): the child can mutate freely without affecting the parent or
//! siblings, and starts from where the parent was at fork time. This is the
//! defining FiberRef semantic (cf. EffectTS `FiberRef`).
//!
//! SCOPE (honest first cut): the snapshot-on-fork is EXPLICIT here — the caller
//! (or a future executor integration) calls `forkChild` when spawning a fiber.
//! Fully automatic propagation through `FiberRuntime.fork` requires Context-
//! attached, type-erased fiber-local storage that the executor clones in its
//! `FiberJob` — a focused follow-up that reuses this cell's snapshot semantics.
//! (Trace/request-id propagation already works today via `Runtime.withTraceContext`,
//! which the Context shallow-copy carries across fork.)
//!
//! Thread-safe (consistent with `Ref`): get/set are guarded so a FiberRef shared
//! across threads never tears, though the common pattern is one cell per fiber.

const std = @import("std");
const sync = @import("sync.zig");

pub fn FiberRef(comptime T: type) type {
    return struct {
        const Self = @This();

        default: T,
        value: T,
        lock: sync.SpinLock = .{},

        pub fn init(default: T) Self {
            return .{ .default = default, .value = default };
        }

        pub fn get(self: *Self) T {
            self.lock.lock();
            defer self.lock.unlock();
            return self.value;
        }

        pub fn set(self: *Self, value: T) void {
            self.lock.lock();
            defer self.lock.unlock();
            self.value = value;
        }

        pub fn update(self: *Self, transform: *const fn (T) T) T {
            self.lock.lock();
            defer self.lock.unlock();
            self.value = transform(self.value);
            return self.value;
        }

        /// Restore the cell to its default value.
        pub fn reset(self: *Self) void {
            self.lock.lock();
            defer self.lock.unlock();
            self.value = self.default;
        }

        /// Produce a child FiberRef that inherits a SNAPSHOT of this cell's
        /// current value. The child is independent — mutating it does not affect
        /// the parent (and vice versa). This is the fork-propagation primitive.
        pub fn forkChild(self: *Self) Self {
            self.lock.lock();
            defer self.lock.unlock();
            return .{ .default = self.default, .value = self.value };
        }
    };
}
