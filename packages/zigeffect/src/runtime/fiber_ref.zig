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
const context_mod = @import("../core/context.zig");

pub const Context = context_mod.Context;

/// Module-level slot cursor. Each `FiberRefSlot` instance claims the next slot.
/// Capped at the Context's slot count; over-allocation is a programmer error.
var slot_cursor: sync.SpinLock = .{};
var next_slot: usize = 0;

fn claimSlot() usize {
    slot_cursor.lock();
    defer slot_cursor.unlock();
    const idx = next_slot;
    next_slot += 1;
    return idx;
}

/// M5.3 (auto-propagation) — a fiber-local cell stored INLINE in the `Context`,
/// so it auto-snapshots across fork via the executor's `ctx.*` copy (no
/// explicit `forkChild` needed). Constraint: `@sizeOf(T) <= 8` (it lives in one
/// of the Context's u64 slots). Larger T uses the explicit `FiberRef(T)` cell.
///
/// Usage: create ONE `FiberRefSlot(T)` (claims a slot at init), then
/// `ref.set(ctx, v)` / `ref.get(ctx)` against the running fiber's Context. A
/// fiber forked from that Context inherits the value; its own writes stay local.
pub fn FiberRefSlot(comptime T: type) type {
    comptime std.debug.assert(@sizeOf(T) <= 8);
    return struct {
        const Self = @This();
        slot: usize,

        pub fn init() Self {
            const idx = claimSlot();
            std.debug.assert(idx < context_mod.fiber_local_slot_count);
            return .{ .slot = idx };
        }

        pub fn get(self: Self, ctx: anytype) T {
            const slot_bytes: [8]u8 = @bitCast(ctx.fiber_local_slots[self.slot]);
            var value: T = undefined;
            @memcpy(std.mem.asBytes(&value), slot_bytes[0..@sizeOf(T)]);
            return value;
        }

        pub fn set(self: Self, ctx: anytype, value: T) void {
            var slot_bytes: [8]u8 = @bitCast(ctx.fiber_local_slots[self.slot]);
            const value_bytes = std.mem.asBytes(&value);
            @memcpy(slot_bytes[0..@sizeOf(T)], value_bytes);
            ctx.fiber_local_slots[self.slot] = @bitCast(slot_bytes);
        }
    };
}

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
