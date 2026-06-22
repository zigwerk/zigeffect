//! Minimal synchronization primitives for the thread-safe engine primitives
//! (CausalStore / Hub / Ref). Zig 0.16's std moved the blocking `Thread.Mutex`
//! into the Io-based concurrency model; for the short critical sections here we
//! use an atomic spinlock built on `std.atomic.Mutex` (which provides tryLock/
//! unlock but no blocking lock). Uncontended in the single-threaded case (one
//! CAS), it spins only under real cross-thread contention over a tiny section.

const std = @import("std");

pub const SpinLock = struct {
    state: std.atomic.Mutex = .unlocked,

    pub fn lock(self: *SpinLock) void {
        while (!self.state.tryLock()) {
            std.atomic.spinLoopHint();
        }
    }

    pub fn unlock(self: *SpinLock) void {
        self.state.unlock();
    }
};
