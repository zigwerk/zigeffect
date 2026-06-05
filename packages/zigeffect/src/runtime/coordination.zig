const std = @import("std");
const result = @import("../core/result.zig");
const scope_mod = @import("../core/scope.zig");

pub const Allocator = std.mem.Allocator;
pub const Exit = result.Exit;
pub const Scope = scope_mod.Scope;

pub const FiberPrimitiveError = error{
    DeferredAlreadyCompleted,
    DeferredNotCompleted,
    QueueEmpty,
    QueueFull,
    QueueShutdown,
    SemaphoreUnavailable,
    SemaphoreOverRelease,
};

pub const DeferredAwaitState = enum {
    ready,
    pending,
};

pub const QueueOfferState = enum {
    ready,
    backpressured,
    shutdown,
};

pub const QueueTakeState = enum {
    ready,
    empty,
    shutdown,
};

pub const SemaphoreAcquireState = enum {
    ready,
    unavailable,
};

pub fn Deferred(comptime Success: type, comptime Failure: type) type {
    return struct {
        const Self = @This();

        exit_value: ?Exit(Success, Failure) = null,

        pub fn init() Self {
            return .{};
        }

        pub fn isCompleted(self: *const Self) bool {
            return self.exit_value != null;
        }

        pub fn awaitState(self: *const Self) DeferredAwaitState {
            return if (self.isCompleted()) .ready else .pending;
        }

        pub fn completeExit(self: *Self, exit: Exit(Success, Failure)) FiberPrimitiveError!void {
            if (self.isCompleted()) return error.DeferredAlreadyCompleted;
            self.exit_value = exit;
        }

        pub fn completeSuccess(self: *Self, value: Success) FiberPrimitiveError!void {
            try self.completeExit(.{ .success = value });
        }

        pub fn completeFailure(self: *Self, err: Failure) FiberPrimitiveError!void {
            try self.completeExit(.{ .failure = err });
        }

        pub fn awaitExit(self: *const Self) FiberPrimitiveError!Exit(Success, Failure) {
            if (self.awaitState() == .pending) return error.DeferredNotCompleted;
            return self.exit_value.?;
        }
    };
}

pub fn Queue(comptime Item: type) type {
    return struct {
        const Self = @This();

        allocator: Allocator,
        items: std.ArrayList(Item) = .empty,
        capacity: ?usize = null,
        shutdown_value: bool = false,

        pub fn init(allocator: Allocator) Self {
            return .{ .allocator = allocator };
        }

        pub fn bounded(allocator: Allocator, capacity: usize) Self {
            return .{
                .allocator = allocator,
                .capacity = capacity,
            };
        }

        pub fn deinit(self: *Self) void {
            self.items.deinit(self.allocator);
        }

        pub fn len(self: *const Self) usize {
            return self.items.items.len;
        }

        pub fn shutdown(self: *Self) void {
            self.shutdown_value = true;
        }

        pub fn isShutdown(self: *const Self) bool {
            return self.shutdown_value;
        }

        pub fn offerState(self: *const Self) QueueOfferState {
            if (self.shutdown_value) return .shutdown;
            if (self.capacity) |capacity| {
                if (self.items.items.len >= capacity) return .backpressured;
            }
            return .ready;
        }

        pub fn takeState(self: *const Self) QueueTakeState {
            if (self.items.items.len > 0) return .ready;
            if (self.shutdown_value) return .shutdown;
            return .empty;
        }

        pub fn offer(self: *Self, item: Item) (Allocator.Error || FiberPrimitiveError)!void {
            switch (self.offerState()) {
                .ready => {},
                .backpressured => return error.QueueFull,
                .shutdown => return error.QueueShutdown,
            }
            try self.items.append(self.allocator, item);
        }

        pub fn take(self: *Self) FiberPrimitiveError!Item {
            switch (self.takeState()) {
                .ready => {},
                .empty => return error.QueueEmpty,
                .shutdown => return error.QueueShutdown,
            }
            return self.items.orderedRemove(0);
        }
    };
}

pub const Semaphore = struct {
    permits: usize,
    max_permits: usize,

    pub fn init(permits: usize) Semaphore {
        return .{
            .permits = permits,
            .max_permits = permits,
        };
    }

    pub fn available(self: *const Semaphore) usize {
        return self.permits;
    }

    pub fn acquireState(self: *const Semaphore, permits: usize) SemaphoreAcquireState {
        return if (permits <= self.permits) .ready else .unavailable;
    }

    pub fn acquire(self: *Semaphore, permits: usize) FiberPrimitiveError!void {
        if (self.acquireState(permits) == .unavailable) return error.SemaphoreUnavailable;
        self.permits -= permits;
    }

    pub fn release(self: *Semaphore, permits: usize) FiberPrimitiveError!void {
        if (permits > self.max_permits - self.permits) return error.SemaphoreOverRelease;
        self.permits += permits;
    }

    const ScopedPermit = struct {
        allocator: Allocator,
        semaphore: *Semaphore,
        permits: usize,
    };

    fn releaseScopedPermit(permit: *ScopedPermit) void {
        const allocator = permit.allocator;
        permit.semaphore.release(permit.permits) catch unreachable;
        allocator.destroy(permit);
    }

    pub fn acquireScoped(self: *Semaphore, scope: *Scope, permits: usize) (Allocator.Error || FiberPrimitiveError)!void {
        try self.acquire(permits);

        const scoped = scope.allocator.create(ScopedPermit) catch |err| {
            self.release(permits) catch unreachable;
            return err;
        };
        scoped.* = .{
            .allocator = scope.allocator,
            .semaphore = self,
            .permits = permits,
        };

        scope.addFinalizerFor(ScopedPermit, scoped, releaseScopedPermit) catch |err| {
            releaseScopedPermit(scoped);
            return err;
        };
    }
};
