//! M5.1 — `Ref(T)`, the atomic cell primitive.
//!
//! Thread-safe write path: `get`/`set`/`update` are serialized by a `SpinLock`, so
//! OS-thread executors do not lose read-modify-write updates. Keep read-side
//! inspection at a quiescent barrier when combining this with broader runtime
//! snapshots or host services.
//!
//! `Ref` is the foundation for `SynchronizedRef` (M5.2 — effectful update under
//! a semaphore), `FiberRef` (M5.3 — fiber-local with auto-propagation), and
//! `Hub` subscriber state (M5.4).

const std = @import("std");
const coordination = @import("coordination.zig");
const sync = @import("sync.zig");

pub const Semaphore = coordination.Semaphore;
pub const FiberPrimitiveError = coordination.FiberPrimitiveError;

pub fn Ref(comptime T: type) type {
    return struct {
        const Self = @This();

        value: T,
        // Thread-safe (M-thread lift): the spinlock guards the read-modify-write
        // window so concurrent updates from multiple executor threads don't tear
        // or lose writes. Uncontended (one CAS) single-threaded — zero cost there.
        mutex: sync.SpinLock = .{},

        pub fn init(value: T) Self {
            return .{ .value = value };
        }

        /// Load the current value (under the lock, so it never reads a torn write).
        pub fn get(self: *Self) T {
            self.mutex.lock();
            defer self.mutex.unlock();
            return self.value;
        }

        /// Store a new value, returning the previous one.
        pub fn set(self: *Self, value: T) T {
            self.mutex.lock();
            defer self.mutex.unlock();
            const prev = self.value;
            self.value = value;
            return prev;
        }

        /// Apply `transform` to the current value, store the result, and
        /// return the NEW value (matches EffectTS `Ref.update`).
        pub fn update(self: *Self, transform: *const fn (T) T) T {
            self.mutex.lock();
            defer self.mutex.unlock();
            self.value = transform(self.value);
            return self.value;
        }

        /// Apply `transform`, return BOTH the previous and the new value as a
        /// 2-field struct. Useful for caller-observable change detection.
        pub const UpdatePair = struct { previous: T, current: T };
        pub fn updateAndReturnBoth(self: *Self, transform: *const fn (T) T) UpdatePair {
            self.mutex.lock();
            defer self.mutex.unlock();
            const previous = self.value;
            self.value = transform(previous);
            return .{ .previous = previous, .current = self.value };
        }

        /// Apply a transform that may itself fail, leaving the cell unchanged
        /// on error. Returns the new value on success.
        pub fn updateE(
            self: *Self,
            comptime E: type,
            transform: *const fn (T) E!T,
        ) E!T {
            self.mutex.lock();
            defer self.mutex.unlock();
            const next = try transform(self.value);
            self.value = next;
            return next;
        }
    };
}

/// M5.2 — `SynchronizedRef(T)`, a `Ref` whose `update` is serialized through a
/// 1-permit semaphore. `Ref` itself already protects the cell with a `SpinLock`;
/// the semaphore remains the effect-level serialization boundary for callers
/// that need update ordering to compose with other fiber primitives.
///
/// Reads (`get`) are NOT guarded — the semaphore protects the
/// read-transform-write window, not snapshot reads. The convention matches
/// EffectTS `SynchronizedRef.modify`.
pub fn SynchronizedRef(comptime T: type) type {
    return struct {
        const Self = @This();

        cell: Ref(T),
        permit: Semaphore,

        pub fn init(value: T) Self {
            return .{ .cell = Ref(T).init(value), .permit = Semaphore.init(1) };
        }

        pub fn get(self: *Self) T {
            return self.cell.get();
        }

        /// Serialized read-transform-write. Acquires the permit, applies
        /// `transform`, releases. Returns the new value.
        pub fn update(self: *Self, transform: *const fn (T) T) FiberPrimitiveError!T {
            try self.permit.acquire(1);
            defer self.permit.release(1) catch {};
            return self.cell.update(transform);
        }

        /// Serialized read-transform-write where the transform may itself
        /// fail. Leaves the cell unchanged on error. Returns the new value on
        /// success.
        pub fn updateE(
            self: *Self,
            comptime E: type,
            transform: *const fn (T) E!T,
        ) (E || FiberPrimitiveError)!T {
            try self.permit.acquire(1);
            defer self.permit.release(1) catch {};
            return self.cell.updateE(E, transform);
        }
    };
}
