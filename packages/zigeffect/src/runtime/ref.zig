//! M5.1 — `Ref(T)`, the atomic cell primitive.
//!
//! Single-threaded v1: `get`/`set`/`update` are plain reads and writes. The
//! engine's v1 production posture is single-executor (see Working Default #4 in
//! the vision-completion roadmap), so a non-atomic cell is sound today. The
//! public API is designed so that lifting to thread-safe in v2 — by swapping
//! the field to `std.atomic.Value(T)` and the methods to load/store/cmpxchg —
//! is source-compatible: no caller can observe the difference.
//!
//! `Ref` is the foundation for `SynchronizedRef` (M5.2 — effectful update under
//! a semaphore), `FiberRef` (M5.3 — fiber-local with auto-propagation), and
//! `Hub` subscriber state (M5.4).

const std = @import("std");

pub fn Ref(comptime T: type) type {
    return struct {
        const Self = @This();

        value: T,

        pub fn init(value: T) Self {
            return .{ .value = value };
        }

        /// Load the current value.
        pub fn get(self: *const Self) T {
            return self.value;
        }

        /// Store a new value, returning the previous one.
        pub fn set(self: *Self, value: T) T {
            const prev = self.value;
            self.value = value;
            return prev;
        }

        /// Apply `transform` to the current value, store the result, and
        /// return the NEW value (matches EffectTS `Ref.update`).
        pub fn update(self: *Self, transform: *const fn (T) T) T {
            self.value = transform(self.value);
            return self.value;
        }

        /// Apply `transform`, return BOTH the previous and the new value as a
        /// 2-field struct. Useful for caller-observable change detection.
        pub const UpdatePair = struct { previous: T, current: T };
        pub fn updateAndReturnBoth(self: *Self, transform: *const fn (T) T) UpdatePair {
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
            const next = try transform(self.value);
            self.value = next;
            return next;
        }
    };
}
