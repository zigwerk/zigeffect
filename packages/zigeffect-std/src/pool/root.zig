//! Bounded scoped resource pools inspired by Effect's `Pool`.
//!
//! Pool entries are heap-stable and each owns an acquisition scope. Borrows
//! are registered in the current effect scope, so success, failure, and
//! interruption all return capacity through the same finalizer path.

const std = @import("std");
const StdService = @import("../service/root.zig");
const fx = @import("zigeffect");

pub const TimeToLiveStrategy = enum {
    idle,
    creation,
};

pub const Options = struct {
    min_size: usize = 0,
    max_size: usize,
    concurrency_per_item: usize = 1,
    time_to_live_ms: ?u64 = null,
    time_to_live_strategy: TimeToLiveStrategy = .idle,

    pub fn validate(self: Options) PoolError!void {
        if (self.max_size == 0 or self.min_size > self.max_size or self.concurrency_per_item == 0) {
            return error.InvalidPoolOptions;
        }
        if (self.time_to_live_ms == 0) return error.InvalidPoolOptions;
    }
};

pub const PoolError = error{
    InvalidPoolOptions,
    PoolClosed,
    PoolExhausted,
    PoolItemNotFound,
    OutOfMemory,
    MissingScope,
};

pub const default_service_key = "zigeffect/std/Pool";

pub const Stats = struct {
    size: usize,
    borrowed: usize,
    available: usize,
    pending_creations: usize,
    max_size: usize,
    concurrency_per_item: usize,
    closed: bool,
};

fn assertErrorSet(comptime Failure: type) void {
    switch (@typeInfo(Failure)) {
        .error_set => {},
        else => @compileError("zstd.Pool requires an error-set acquisition failure type"),
    }
}

pub fn Pool(
    comptime Item: type,
    comptime Failure: type,
    comptime Requirements: anytype,
    comptime acquire: *const fn (*fx.kernel.ContextView(Requirements)) Failure!Item,
    comptime release: *const fn (*Item) void,
) type {
    assertErrorSet(Failure);
    return struct {
        const Self = @This();

        pub const is_zigeffect_pool = true;
        pub const operations: []const []const u8 = &.{
            "Pool.get",
            "Pool.invalidate",
            "Pool.prune",
            "Pool.stats",
        };
        pub const ItemType = Item;
        pub const AcquisitionFailure = Failure;
        pub const RequiredServices = Requirements;
        pub const ErrorType = Failure || PoolError;

        const OwnedItem = struct {
            allocator: std.mem.Allocator,
            item: Item,
        };

        const Entry = struct {
            scope: fx.Scope,
            owned: *OwnedItem,
            borrowers: usize = 0,
            invalidated: bool = false,
            created_at_ms: u64,
            last_used_ms: u64,
        };

        const Borrow = struct {
            allocator: std.mem.Allocator,
            pool: *Self,
            entry: *Entry,
            clock: *fx.kernel.Clock,
        };

        allocator: std.mem.Allocator,
        service_key: []const u8,
        options: Options,
        entries: std.ArrayList(*Entry) = .empty,
        pending_creations: usize = 0,
        closed: bool = false,
        mutex: std.atomic.Mutex = .unlocked,

        fn lock(self: *Self) void {
            while (!self.mutex.tryLock()) std.Thread.yield() catch {};
        }

        fn releaseOwned(owned: *OwnedItem) void {
            const allocator = owned.allocator;
            release(&owned.item);
            allocator.destroy(owned);
        }

        fn closeFailedScope(scope: *fx.Scope, failure: anyerror) void {
            scope.closeWithExit(.{ .failure = @errorName(failure) });
            scope.deinit();
        }

        fn acquireEntry(self: *Self, ctx: anytype) ErrorType!*Entry {
            const runtime_context = ctx.runtime_context;
            var child_scope = fx.Scope.init(self.allocator);
            const run_id = runtime_context.causal_run_id orelse runtime_context.core.causal_store.nextRunId();
            child_scope.attachRuntimeSignal(
                runtime_context.core.signalSink(),
                run_id,
                runtime_context.causal_parent_id,
                runtime_context.scope.causal_trace_id,
                runtime_context.scope.causal_span_id,
            );
            child_scope.setCausalContext(runtime_context.causal_context);

            var child_runtime = runtime_context.*;
            child_runtime.scope = &child_scope;
            child_runtime.causal_parent_id = child_scope.causal_opened_event_id orelse runtime_context.causal_parent_id;
            var acquire_context = fx.kernel.ContextView(Requirements){ .runtime_context = &child_runtime };
            var item = acquire(&acquire_context) catch |failure| {
                closeFailedScope(&child_scope, failure);
                return failure;
            };

            const owned = self.allocator.create(OwnedItem) catch |failure| {
                release(&item);
                closeFailedScope(&child_scope, failure);
                return failure;
            };
            owned.* = .{ .allocator = self.allocator, .item = item };
            child_scope.addFinalizerFor(OwnedItem, owned, releaseOwned) catch |failure| {
                releaseOwned(owned);
                closeFailedScope(&child_scope, failure);
                return failure;
            };

            const entry = self.allocator.create(Entry) catch |failure| {
                child_scope.closeWithExit(.{ .failure = @errorName(failure) });
                child_scope.deinit();
                return failure;
            };
            const now = ctx.clock().nowMs();
            entry.* = .{
                .scope = child_scope,
                .owned = owned,
                .created_at_ms = now,
                .last_used_ms = now,
            };
            return entry;
        }

        fn destroyEntry(self: *Self, entry: *Entry, exit: fx.FinalizerExit) void {
            entry.scope.closeWithExit(exit);
            entry.scope.deinit();
            self.allocator.destroy(entry);
        }

        pub fn init(
            ctx: *fx.kernel.ContextView(Requirements),
            stable_service_key: []const u8,
            options: Options,
        ) ErrorType!Self {
            try options.validate();
            var self = Self{
                .allocator = ctx.allocator(),
                .service_key = if (stable_service_key.len == 0) default_service_key else stable_service_key,
                .options = options,
            };
            errdefer self.deinit();
            while (self.entries.items.len < options.min_size) {
                const entry = try self.acquireEntry(ctx);
                self.entries.append(self.allocator, entry) catch |failure| {
                    self.destroyEntry(entry, .{ .failure = @errorName(failure) });
                    return failure;
                };
            }
            return self;
        }

        pub fn deinit(self: *Self) void {
            self.lock();
            if (self.closed) {
                self.mutex.unlock();
                return;
            }
            self.closed = true;
            self.mutex.unlock();

            while (true) {
                self.lock();
                const entry = if (self.entries.items.len == 0) null else self.entries.pop();
                self.mutex.unlock();
                if (entry) |owned| self.destroyEntry(owned, .success) else break;
            }
            self.entries.deinit(self.allocator);
        }

        fn destroyPool(pool: *Self) void {
            const allocator = pool.allocator;
            pool.deinit();
            allocator.destroy(pool);
        }

        const MakeState = struct {
            service_key: []const u8,
            options: Options,
        };

        /// Constructs a pool inside the current effect scope. Long-lived pools
        /// should normally use `Pool.Service` so a managed runtime owns them.
        pub fn make(stable_service_key: []const u8, options: Options) fx.kernel.Effect(
            *Self,
            ErrorType,
            Requirements,
        ).Stateful(MakeState) {
            const Make = fx.kernel.Effect(*Self, ErrorType, Requirements);
            return Make.fromState(MakeState, .{
                .service_key = stable_service_key,
                .options = options,
            }, struct {
                fn run(state: MakeState, ctx: *fx.kernel.ContextView(Requirements)) ErrorType!*Self {
                    const allocator = ctx.allocator();
                    const pool = allocator.create(Self) catch return error.OutOfMemory;
                    pool.* = Self.init(ctx, state.service_key, state.options) catch |failure| {
                        allocator.destroy(pool);
                        return failure;
                    };
                    ctx.addFinalizerFor(Self, pool, Self.destroyPool) catch |failure| {
                        Self.destroyPool(pool);
                        return failure;
                    };
                    return pool;
                }
            }.run);
        }

        fn isExpired(self: *const Self, entry: *const Entry, now_ms: u64) bool {
            const ttl = self.options.time_to_live_ms orelse return false;
            const since = switch (self.options.time_to_live_strategy) {
                .idle => entry.last_used_ms,
                .creation => entry.created_at_ms,
            };
            return now_ms >= since and now_ms - since >= ttl;
        }

        fn removeEntryLocked(self: *Self, target: *Entry) bool {
            for (self.entries.items, 0..) |entry, index| {
                if (entry == target) {
                    _ = self.entries.orderedRemove(index);
                    return true;
                }
            }
            return false;
        }

        fn pruneExpiredIn(self: *Self, ctx: anytype) ErrorType!usize {
            var removed: usize = 0;
            const now = ctx.clock().nowMs();
            while (true) {
                self.lock();
                if (self.closed) {
                    self.mutex.unlock();
                    return error.PoolClosed;
                }
                var expired: ?*Entry = null;
                if (self.entries.items.len > self.options.min_size) {
                    for (self.entries.items) |entry| {
                        if (entry.borrowers == 0 and self.isExpired(entry, now)) {
                            _ = self.removeEntryLocked(entry);
                            expired = entry;
                            break;
                        }
                    }
                }
                self.mutex.unlock();
                const entry = expired orelse break;
                self.destroyEntry(entry, .success);
                removed += 1;
            }
            return removed;
        }

        fn returnBorrow(borrow: *Borrow) void {
            const pool = borrow.pool;
            const entry = borrow.entry;
            var destroy = false;
            pool.lock();
            if (entry.borrowers > 0) entry.borrowers -= 1;
            entry.last_used_ms = borrow.clock.nowMs();
            if (entry.invalidated and entry.borrowers == 0) {
                destroy = pool.removeEntryLocked(entry);
            }
            pool.mutex.unlock();
            if (destroy) pool.destroyEntry(entry, .success);
            borrow.allocator.destroy(borrow);
        }

        fn reserveExisting(self: *Self) ErrorType!?*Entry {
            self.lock();
            defer self.mutex.unlock();
            if (self.closed) return error.PoolClosed;
            for (self.entries.items) |entry| {
                if (entry.invalidated) continue;
                if (entry.borrowers >= self.options.concurrency_per_item) continue;
                entry.borrowers += 1;
                return entry;
            }
            return null;
        }

        fn reserveCreation(self: *Self) ErrorType!void {
            self.lock();
            defer self.mutex.unlock();
            if (self.closed) return error.PoolClosed;
            if (self.entries.items.len >= self.options.max_size or
                self.pending_creations >= self.options.max_size - self.entries.items.len)
            {
                return error.PoolExhausted;
            }
            self.pending_creations += 1;
        }

        fn finishCreation(self: *Self, entry: ?*Entry) ErrorType!?*Entry {
            self.lock();
            defer self.mutex.unlock();
            if (self.pending_creations > 0) self.pending_creations -= 1;
            const created = entry orelse return null;
            if (self.closed) return error.PoolClosed;
            self.entries.append(self.allocator, created) catch return error.OutOfMemory;
            created.borrowers = 1;
            return created;
        }

        fn undoBorrow(self: *Self, entry: *Entry, clock: *fx.kernel.Clock) void {
            var destroy = false;
            self.lock();
            if (entry.borrowers > 0) entry.borrowers -= 1;
            entry.last_used_ms = clock.nowMs();
            if (entry.invalidated and entry.borrowers == 0) {
                destroy = self.removeEntryLocked(entry);
            }
            self.mutex.unlock();
            if (destroy) self.destroyEntry(entry, .success);
        }

        pub fn borrowIn(self: *Self, ctx: anytype) ErrorType!*Item {
            const operation = StdService.beginOperation(ctx, self.service_key, "Pool.get", "borrow bounded scoped item");
            _ = self.pruneExpiredIn(ctx) catch |failure| {
                _ = StdService.completeOperation(ctx, operation, "failure", @errorName(failure));
                return failure;
            };

            var entry = self.reserveExisting() catch |failure| {
                _ = StdService.completeOperation(ctx, operation, "failure", @errorName(failure));
                return failure;
            };
            if (entry == null) {
                self.reserveCreation() catch |failure| {
                    _ = StdService.completeOperation(ctx, operation, "failure", @errorName(failure));
                    return failure;
                };
                const created = self.acquireEntry(ctx) catch |failure| {
                    _ = self.finishCreation(null) catch {};
                    _ = StdService.completeOperation(ctx, operation, "failure", @errorName(failure));
                    return failure;
                };
                entry = self.finishCreation(created) catch |failure| {
                    self.destroyEntry(created, .{ .failure = @errorName(failure) });
                    _ = StdService.completeOperation(ctx, operation, "failure", @errorName(failure));
                    return failure;
                };
            }

            const selected = entry.?;
            const borrow = self.allocator.create(Borrow) catch {
                self.undoBorrow(selected, ctx.clock());
                _ = StdService.completeOperation(ctx, operation, "failure", @errorName(error.OutOfMemory));
                return error.OutOfMemory;
            };
            borrow.* = .{
                .allocator = self.allocator,
                .pool = self,
                .entry = selected,
                .clock = ctx.clock(),
            };
            ctx.addFinalizerFor(Borrow, borrow, returnBorrow) catch |failure| {
                self.undoBorrow(selected, ctx.clock());
                self.allocator.destroy(borrow);
                _ = StdService.completeOperation(ctx, operation, "failure", @errorName(failure));
                return failure;
            };
            _ = StdService.completeOperation(ctx, operation, "success", "borrow registered in run scope");
            return &selected.owned.item;
        }

        pub fn invalidateIn(self: *Self, ctx: anytype, item: *Item) ErrorType!void {
            const operation = StdService.beginOperation(ctx, self.service_key, "Pool.invalidate", "invalidate pooled item");
            var matched: ?*Entry = null;
            var destroy_idle = false;
            self.lock();
            if (self.closed) {
                self.mutex.unlock();
                _ = StdService.completeOperation(ctx, operation, "failure", @errorName(error.PoolClosed));
                return error.PoolClosed;
            }
            for (self.entries.items) |entry| {
                if (&entry.owned.item != item) continue;
                matched = entry;
                entry.invalidated = true;
                if (entry.borrowers == 0 and self.removeEntryLocked(entry)) destroy_idle = true;
                break;
            }
            self.mutex.unlock();
            const entry = matched orelse {
                _ = StdService.completeOperation(ctx, operation, "failure", @errorName(error.PoolItemNotFound));
                return error.PoolItemNotFound;
            };
            if (!destroy_idle) {
                _ = StdService.completeOperation(ctx, operation, "success", "borrowed item marked invalid");
                return;
            }
            self.destroyEntry(entry, .success);
            _ = StdService.completeOperation(ctx, operation, "success", "idle item finalized");
        }

        pub fn statsValue(self: *Self) Stats {
            self.lock();
            defer self.mutex.unlock();
            var borrowed: usize = 0;
            var available: usize = 0;
            for (self.entries.items) |entry| {
                borrowed += entry.borrowers;
                if (!entry.invalidated and entry.borrowers < self.options.concurrency_per_item) {
                    available = std.math.add(
                        usize,
                        available,
                        self.options.concurrency_per_item - entry.borrowers,
                    ) catch std.math.maxInt(usize);
                }
            }
            return .{
                .size = self.entries.items.len,
                .borrowed = borrowed,
                .available = available,
                .pending_creations = self.pending_creations,
                .max_size = self.options.max_size,
                .concurrency_per_item = self.options.concurrency_per_item,
                .closed = self.closed,
            };
        }
    };
}

fn ServiceLifecycle(comptime PoolType: type, comptime stable_service_key: []const u8, comptime options: Options) type {
    return struct {
        fn acquire(ctx: *fx.kernel.ContextView(PoolType.RequiredServices)) PoolType.ErrorType!PoolType {
            return PoolType.init(ctx, stable_service_key, options);
        }

        fn release(pool: *PoolType) void {
            pool.deinit();
        }
    };
}

/// Defines a stable pool service and its canonical scoped default layer.
pub fn Service(
    comptime stable_service_key: []const u8,
    comptime Item: type,
    comptime Failure: type,
    comptime Requirements: anytype,
    comptime acquire: *const fn (*fx.kernel.ContextView(Requirements)) Failure!Item,
    comptime release: *const fn (*Item) void,
    comptime options: Options,
) type {
    if (stable_service_key.len == 0) @compileError("zstd.Pool service keys must not be empty");
    const PoolType = Pool(Item, Failure, Requirements, acquire, release);
    const Lifecycle = ServiceLifecycle(PoolType, stable_service_key, options);
    return fx.kernel.defineService(.{
        .key = stable_service_key,
        .API = PoolType,
        .Failure = PoolType.ErrorType,
        .Requirements = Requirements,
        .acquire = Lifecycle.acquire,
        .release = Lifecycle.release,
    });
}

fn assertPoolService(comptime Tag: type) void {
    if (!@hasDecl(Tag.API, "is_zigeffect_pool")) {
        @compileError("zstd.Pool operation requires a tag created by Pool.Service");
    }
}

pub fn get(comptime Tag: type) fx.kernel.Effect(*Tag.API.ItemType, Tag.API.ErrorType, .{Tag}) {
    assertPoolService(Tag);
    return fx.kernel.Effect(*Tag.API.ItemType, Tag.API.ErrorType, .{Tag}).fromFn(struct {
        fn run(ctx: *fx.kernel.ContextView(.{Tag})) Tag.API.ErrorType!*Tag.API.ItemType {
            return ctx.service(Tag).borrowIn(ctx);
        }
    }.run);
}

pub fn invalidate(comptime Tag: type, item: *Tag.API.ItemType) fx.kernel.Effect(
    void,
    Tag.API.ErrorType,
    .{Tag},
).Stateful(*Tag.API.ItemType) {
    assertPoolService(Tag);
    const Invalidate = fx.kernel.Effect(void, Tag.API.ErrorType, .{Tag});
    return Invalidate.fromState(*Tag.API.ItemType, item, struct {
        fn run(value: *Tag.API.ItemType, ctx: *fx.kernel.ContextView(.{Tag})) Tag.API.ErrorType!void {
            try ctx.service(Tag).invalidateIn(ctx, value);
        }
    }.run);
}

pub fn prune(comptime Tag: type) fx.kernel.Effect(void, Tag.API.ErrorType, .{Tag}) {
    assertPoolService(Tag);
    return fx.kernel.Effect(void, Tag.API.ErrorType, .{Tag}).fromFn(struct {
        fn run(ctx: *fx.kernel.ContextView(.{Tag})) Tag.API.ErrorType!void {
            _ = try ctx.service(Tag).pruneExpiredIn(ctx);
        }
    }.run);
}

pub fn stats(comptime Tag: type) fx.kernel.Effect(Stats, error{}, .{Tag}) {
    assertPoolService(Tag);
    return fx.kernel.Effect(Stats, error{}, .{Tag}).fromFn(struct {
        fn run(ctx: *fx.kernel.ContextView(.{Tag})) error{}!Stats {
            return ctx.service(Tag).statsValue();
        }
    }.run);
}
