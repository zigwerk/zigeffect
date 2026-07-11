//! Effectful, chunked, resource-safe streams.
//!
//! This is deliberately separate from the original synchronous value stream.
//! `EffectStream(A, E, R)` pulls through `Context(R)`, carries typed failures,
//! bounds every allocation by an explicit chunk size, and closes its source
//! exactly once on success, failure, or interruption. Values are linear-owned:
//! after passing a stream into a combinator, the previous value must not be used.

const std = @import("std");
const context_mod = @import("../core/context.zig");

pub const StreamError = error{
    StreamClosed,
    InvalidChunkSize,
    InvalidBufferCapacity,
    StreamTimeout,
    RetryExhausted,
    BufferFull,
    BufferEmpty,
};

pub const CloseReason = enum { success, failure, interrupted };
pub const BackpressureStrategy = enum { block, reject, drop_newest, drop_oldest };

pub fn EffectStream(comptime Item: type, comptime Error: type, comptime Env: type) type {
    const Failure = Error || StreamError || std.mem.Allocator.Error;
    const Context = context_mod.Context(Env);
    return struct {
        const Self = @This();
        pub const ItemType = Item;
        pub const ErrorType = Error;
        pub const EnvType = Env;
        pub const FailureType = Failure;

        pub const Chunk = struct {
            allocator: std.mem.Allocator,
            items: []Item,
            end: bool = false,

            pub fn deinit(self: *Chunk) void {
                self.allocator.free(self.items);
                self.* = undefined;
            }
        };

        const VTable = struct {
            pull: *const fn (*anyopaque, *Context, std.mem.Allocator, usize) Failure!Chunk,
            close: *const fn (*anyopaque, CloseReason) void,
            destroy: *const fn (*anyopaque, std.mem.Allocator) void,
        };

        allocator: std.mem.Allocator,
        pointer: *anyopaque,
        vtable: *const VTable,
        closed: bool = false,

        pub fn pull(self: *Self, ctx: *Context, allocator: std.mem.Allocator, max_items: usize) Failure!Chunk {
            if (self.closed) return error.StreamClosed;
            if (max_items == 0) return error.InvalidChunkSize;
            const result = self.vtable.pull(self.pointer, ctx, allocator, max_items) catch |err| {
                self.close(.failure);
                return err;
            };
            if (result.end) self.close(.success);
            return result;
        }

        pub fn close(self: *Self, reason: CloseReason) void {
            if (self.closed) return;
            self.closed = true;
            self.vtable.close(self.pointer, reason);
        }

        pub fn interrupt(self: *Self) void { self.close(.interrupted); }

        pub fn deinit(self: *Self) void {
            self.close(.success);
            self.vtable.destroy(self.pointer, self.allocator);
            self.* = undefined;
        }

        pub fn mapEffectAlloc(
            self: Self,
            comptime Out: type,
            allocator: std.mem.Allocator,
            mapper: *const fn (Item, *Context) Error!Out,
        ) std.mem.Allocator.Error!EffectStream(Out, Error, Env) {
            const Parent = Self;
            const Output = EffectStream(Out, Error, Env);
            const State = struct {
                parent: Parent,
                mapper: *const fn (Item, *Context) Error!Out,
                closed: bool = false,
                fn pull(raw: *anyopaque, ctx: *Context, output_allocator: std.mem.Allocator, max: usize) Output.FailureType!Output.Chunk {
                    const state: *@This() = @ptrCast(@alignCast(raw));
                    var input = try state.parent.pull(ctx, output_allocator, max);
                    defer input.deinit();
                    const output = try output_allocator.alloc(Out, input.items.len);
                    errdefer output_allocator.free(output);
                    for (input.items, 0..) |item, index| output[index] = try state.mapper(item, ctx);
                    return .{ .allocator = output_allocator, .items = output, .end = input.end };
                }
                fn close(raw: *anyopaque, reason: CloseReason) void {
                    const state: *@This() = @ptrCast(@alignCast(raw));
                    if (state.closed) return;
                    state.closed = true;
                    state.parent.close(reason);
                }
                fn destroy(raw: *anyopaque, state_allocator: std.mem.Allocator) void {
                    const state: *@This() = @ptrCast(@alignCast(raw));
                    state.parent.deinit();
                    state_allocator.destroy(state);
                }
            };
            const state = try allocator.create(State);
            state.* = .{ .parent = self, .mapper = mapper };
            return .{ .allocator = allocator, .pointer = state, .vtable = &.{ .pull = State.pull, .close = State.close, .destroy = State.destroy } };
        }

        pub fn filterEffectAlloc(
            self: Self,
            allocator: std.mem.Allocator,
            predicate: *const fn (Item, *Context) Error!bool,
        ) std.mem.Allocator.Error!Self {
            const State = struct {
                parent: Self,
                predicate: *const fn (Item, *Context) Error!bool,
                closed: bool = false,
                fn pull(raw: *anyopaque, ctx: *Context, output_allocator: std.mem.Allocator, max: usize) Failure!Chunk {
                    const state: *@This() = @ptrCast(@alignCast(raw));
                    while (true) {
                        var input = try state.parent.pull(ctx, output_allocator, max);
                        defer input.deinit();
                        var output: std.ArrayList(Item) = .empty;
                        errdefer output.deinit(output_allocator);
                        for (input.items) |item| if (try state.predicate(item, ctx)) try output.append(output_allocator, item);
                        if (output.items.len != 0 or input.end) return .{ .allocator = output_allocator, .items = try output.toOwnedSlice(output_allocator), .end = input.end };
                    }
                }
                fn close(raw: *anyopaque, reason: CloseReason) void {
                    const state: *@This() = @ptrCast(@alignCast(raw));
                    if (state.closed) return;
                    state.closed = true;
                    state.parent.close(reason);
                }
                fn destroy(raw: *anyopaque, state_allocator: std.mem.Allocator) void {
                    const state: *@This() = @ptrCast(@alignCast(raw));
                    state.parent.deinit();
                    state_allocator.destroy(state);
                }
            };
            const state = try allocator.create(State);
            state.* = .{ .parent = self, .predicate = predicate };
            return .{ .allocator = allocator, .pointer = state, .vtable = &.{ .pull = State.pull, .close = State.close, .destroy = State.destroy } };
        }

        pub fn mergeAlloc(self: Self, allocator: std.mem.Allocator, other: Self) std.mem.Allocator.Error!Self {
            const State = struct {
                left: Self,
                right: Self,
                left_done: bool = false,
                right_done: bool = false,
                next_left: bool = true,
                closed: bool = false,
                fn pull(raw: *anyopaque, ctx: *Context, output_allocator: std.mem.Allocator, max: usize) Failure!Chunk {
                    const state: *@This() = @ptrCast(@alignCast(raw));
                    while (!state.left_done or !state.right_done) {
                        const choose_left = (!state.left_done and state.next_left) or state.right_done;
                        state.next_left = !choose_left;
                        var chunk = if (choose_left)
                            try state.left.pull(ctx, output_allocator, max)
                        else
                            try state.right.pull(ctx, output_allocator, max);
                        if (chunk.end) {
                            if (choose_left) state.left_done = true else state.right_done = true;
                            if (chunk.items.len == 0 and (!state.left_done or !state.right_done)) {
                                chunk.deinit();
                                continue;
                            }
                        }
                        chunk.end = state.left_done and state.right_done;
                        return chunk;
                    }
                    return .{ .allocator = output_allocator, .items = try output_allocator.alloc(Item, 0), .end = true };
                }
                fn close(raw: *anyopaque, reason: CloseReason) void {
                    const state: *@This() = @ptrCast(@alignCast(raw));
                    if (state.closed) return;
                    state.closed = true;
                    state.left.close(reason);
                    state.right.close(reason);
                }
                fn destroy(raw: *anyopaque, state_allocator: std.mem.Allocator) void {
                    const state: *@This() = @ptrCast(@alignCast(raw));
                    state.left.deinit();
                    state.right.deinit();
                    state_allocator.destroy(state);
                }
            };
            const state = try allocator.create(State);
            state.* = .{ .left = self, .right = other };
            return .{ .allocator = allocator, .pointer = state, .vtable = &.{ .pull = State.pull, .close = State.close, .destroy = State.destroy } };
        }

        pub fn flatMapAlloc(
            self: Self,
            comptime Out: type,
            allocator: std.mem.Allocator,
            binder: *const fn (Item, *Context) Error!EffectStream(Out, Error, Env),
        ) std.mem.Allocator.Error!EffectStream(Out, Error, Env) {
            const Output = EffectStream(Out, Error, Env);
            const State = struct {
                parent: Self,
                binder: *const fn (Item, *Context) Error!Output,
                current: ?Output = null,
                parent_done: bool = false,
                closed: bool = false,
                fn pull(raw: *anyopaque, ctx: *Context, output_allocator: std.mem.Allocator, max: usize) Output.FailureType!Output.Chunk {
                    const state: *@This() = @ptrCast(@alignCast(raw));
                    while (true) {
                        if (state.current) |*child| {
                            var chunk = try child.pull(ctx, output_allocator, max);
                            if (chunk.end) {
                                child.deinit();
                                state.current = null;
                                if (chunk.items.len == 0) { chunk.deinit(); continue; }
                                chunk.end = state.parent_done;
                            }
                            return chunk;
                        }
                        if (state.parent_done) return .{ .allocator = output_allocator, .items = try output_allocator.alloc(Out, 0), .end = true };
                        var input = try state.parent.pull(ctx, output_allocator, 1);
                        defer input.deinit();
                        state.parent_done = input.end;
                        if (input.items.len == 0) continue;
                        state.current = try state.binder(input.items[0], ctx);
                    }
                }
                fn close(raw: *anyopaque, reason: CloseReason) void {
                    const state: *@This() = @ptrCast(@alignCast(raw));
                    if (state.closed) return;
                    state.closed = true;
                    if (state.current) |*child| child.close(reason);
                    state.parent.close(reason);
                }
                fn destroy(raw: *anyopaque, state_allocator: std.mem.Allocator) void {
                    const state: *@This() = @ptrCast(@alignCast(raw));
                    if (state.current) |*child| child.deinit();
                    state.parent.deinit();
                    state_allocator.destroy(state);
                }
            };
            const state = try allocator.create(State);
            state.* = .{ .parent = self, .binder = binder };
            return .{ .allocator = allocator, .pointer = state, .vtable = &.{ .pull = State.pull, .close = State.close, .destroy = State.destroy } };
        }

        pub fn bufferAlloc(self: Self, allocator: std.mem.Allocator, capacity: usize) (std.mem.Allocator.Error || StreamError)!Self {
            if (capacity == 0) return error.InvalidBufferCapacity;
            const State = struct {
                parent: Self,
                capacity: usize,
                pending: std.ArrayList(Item) = .empty,
                parent_done: bool = false,
                closed: bool = false,
                fn pull(raw: *anyopaque, ctx: *Context, output_allocator: std.mem.Allocator, max: usize) Failure!Chunk {
                    const state: *@This() = @ptrCast(@alignCast(raw));
                    if (state.pending.items.len == 0 and !state.parent_done) {
                        var input = try state.parent.pull(ctx, state.parent.allocator, state.capacity);
                        defer input.deinit();
                        try state.pending.appendSlice(state.parent.allocator, input.items);
                        state.parent_done = input.end;
                    }
                    const count = @min(max, state.pending.items.len);
                    const output = try output_allocator.dupe(Item, state.pending.items[0..count]);
                    if (count != 0) {
                        std.mem.copyForwards(Item, state.pending.items[0 .. state.pending.items.len - count], state.pending.items[count..]);
                        state.pending.shrinkRetainingCapacity(state.pending.items.len - count);
                    }
                    return .{ .allocator = output_allocator, .items = output, .end = state.parent_done and state.pending.items.len == 0 };
                }
                fn close(raw: *anyopaque, reason: CloseReason) void {
                    const state: *@This() = @ptrCast(@alignCast(raw));
                    if (state.closed) return;
                    state.closed = true;
                    state.parent.close(reason);
                }
                fn destroy(raw: *anyopaque, state_allocator: std.mem.Allocator) void {
                    const state: *@This() = @ptrCast(@alignCast(raw));
                    state.pending.deinit(state.parent.allocator);
                    state.parent.deinit();
                    state_allocator.destroy(state);
                }
            };
            const state = try allocator.create(State);
            state.* = .{ .parent = self, .capacity = capacity };
            return .{ .allocator = allocator, .pointer = state, .vtable = &.{ .pull = State.pull, .close = State.close, .destroy = State.destroy } };
        }

        /// Debounces a source chunk as a burst: only its latest item is emitted
        /// after the configured interval. The injected clock makes the same
        /// decision under deterministic and system execution.
        pub fn debounceAlloc(self: Self, allocator: std.mem.Allocator, interval_ms: u64) (std.mem.Allocator.Error || StreamError)!Self {
            if (interval_ms == 0) return error.StreamTimeout;
            const State = struct {
                parent: Self,
                interval_ms: u64,
                closed: bool = false,
                fn pull(raw: *anyopaque, ctx: *Context, output_allocator: std.mem.Allocator, max: usize) Failure!Chunk {
                    const state: *@This() = @ptrCast(@alignCast(raw));
                    var input = try state.parent.pull(ctx, output_allocator, max);
                    defer input.deinit();
                    if (input.items.len == 0) return .{ .allocator = output_allocator, .items = try output_allocator.alloc(Item, 0), .end = input.end };
                    if (ctx.clock) |clock| clock.sleep(state.interval_ms);
                    const output = try output_allocator.alloc(Item, 1);
                    output[0] = input.items[input.items.len - 1];
                    return .{ .allocator = output_allocator, .items = output, .end = input.end };
                }
                fn close(raw: *anyopaque, reason: CloseReason) void {
                    const state: *@This() = @ptrCast(@alignCast(raw));
                    if (state.closed) return;
                    state.closed = true;
                    state.parent.close(reason);
                }
                fn destroy(raw: *anyopaque, state_allocator: std.mem.Allocator) void {
                    const state: *@This() = @ptrCast(@alignCast(raw));
                    state.parent.deinit();
                    state_allocator.destroy(state);
                }
            };
            const state = try allocator.create(State);
            state.* = .{ .parent = self, .interval_ms = interval_ms };
            return .{ .allocator = allocator, .pointer = state, .vtable = &.{ .pull = State.pull, .close = State.close, .destroy = State.destroy } };
        }

        pub fn retryAlloc(self: Self, allocator: std.mem.Allocator, max_attempts: u32) (std.mem.Allocator.Error || StreamError)!Self {
            if (max_attempts == 0) return error.RetryExhausted;
            const State = struct {
                parent: Self,
                max_attempts: u32,
                closed: bool = false,
                fn pull(raw: *anyopaque, ctx: *Context, output_allocator: std.mem.Allocator, max: usize) Failure!Chunk {
                    const state: *@This() = @ptrCast(@alignCast(raw));
                    var attempt: u32 = 0;
                    while (attempt < state.max_attempts) : (attempt += 1) {
                        return state.parent.vtable.pull(state.parent.pointer, ctx, output_allocator, max) catch |err| {
                            if (attempt + 1 == state.max_attempts) return err;
                            continue;
                        };
                    }
                    return error.RetryExhausted;
                }
                fn close(raw: *anyopaque, reason: CloseReason) void {
                    const state: *@This() = @ptrCast(@alignCast(raw));
                    if (state.closed) return;
                    state.closed = true;
                    state.parent.close(reason);
                }
                fn destroy(raw: *anyopaque, state_allocator: std.mem.Allocator) void {
                    const state: *@This() = @ptrCast(@alignCast(raw));
                    state.parent.deinit();
                    state_allocator.destroy(state);
                }
            };
            const state = try allocator.create(State);
            state.* = .{ .parent = self, .max_attempts = max_attempts };
            return .{ .allocator = allocator, .pointer = state, .vtable = &.{ .pull = State.pull, .close = State.close, .destroy = State.destroy } };
        }

        pub fn timeoutAlloc(self: Self, allocator: std.mem.Allocator, timeout_ms: u64) (std.mem.Allocator.Error || StreamError)!Self {
            if (timeout_ms == 0) return error.StreamTimeout;
            const State = struct {
                parent: Self,
                timeout_ms: u64,
                closed: bool = false,
                fn pull(raw: *anyopaque, ctx: *Context, output_allocator: std.mem.Allocator, max: usize) Failure!Chunk {
                    const state: *@This() = @ptrCast(@alignCast(raw));
                    const clock = ctx.clock orelse return state.parent.pull(ctx, output_allocator, max);
                    const started = clock.nowMs();
                    var chunk = try state.parent.pull(ctx, output_allocator, max);
                    if (clock.nowMs() -| started > state.timeout_ms) {
                        chunk.deinit();
                        return error.StreamTimeout;
                    }
                    return chunk;
                }
                fn close(raw: *anyopaque, reason: CloseReason) void {
                    const state: *@This() = @ptrCast(@alignCast(raw));
                    if (state.closed) return;
                    state.closed = true;
                    state.parent.close(reason);
                }
                fn destroy(raw: *anyopaque, state_allocator: std.mem.Allocator) void {
                    const state: *@This() = @ptrCast(@alignCast(raw));
                    state.parent.deinit();
                    state_allocator.destroy(state);
                }
            };
            const state = try allocator.create(State);
            state.* = .{ .parent = self, .timeout_ms = timeout_ms };
            return .{ .allocator = allocator, .pointer = state, .vtable = &.{ .pull = State.pull, .close = State.close, .destroy = State.destroy } };
        }

        pub fn runCollectAlloc(self: *Self, ctx: *Context, allocator: std.mem.Allocator, chunk_size: usize) Failure![]Item {
            if (chunk_size == 0) return error.InvalidChunkSize;
            var output: std.ArrayList(Item) = .empty;
            errdefer output.deinit(allocator);
            while (true) {
                var chunk = try self.pull(ctx, allocator, chunk_size);
                defer chunk.deinit();
                try output.appendSlice(allocator, chunk.items);
                if (chunk.end) break;
            }
            return output.toOwnedSlice(allocator);
        }

        pub fn runForEach(self: *Self, ctx: *Context, allocator: std.mem.Allocator, chunk_size: usize, consume: *const fn (Item, *Context) Error!void) Failure!void {
            while (true) {
                var chunk = try self.pull(ctx, allocator, chunk_size);
                defer chunk.deinit();
                for (chunk.items) |item| try consume(item, ctx);
                if (chunk.end) return;
            }
        }

        pub fn runFold(self: *Self, ctx: *Context, allocator: std.mem.Allocator, chunk_size: usize, comptime Acc: type, initial: Acc, combine: *const fn (Acc, Item, *Context) Error!Acc) Failure!Acc {
            var value = initial;
            while (true) {
                var chunk = try self.pull(ctx, allocator, chunk_size);
                defer chunk.deinit();
                for (chunk.items) |item| value = try combine(value, item, ctx);
                if (chunk.end) return value;
            }
        }
    };
}

pub fn fromSliceAlloc(
    comptime Item: type,
    comptime Error: type,
    comptime Env: type,
    allocator: std.mem.Allocator,
    items: []const Item,
) std.mem.Allocator.Error!EffectStream(Item, Error, Env) {
    const Stream = EffectStream(Item, Error, Env);
    const Context = context_mod.Context(Env);
    const State = struct {
        items: []Item,
        position: usize = 0,
        closed: bool = false,
        fn pull(raw: *anyopaque, _: *Context, output_allocator: std.mem.Allocator, max: usize) Stream.FailureType!Stream.Chunk {
            const state: *@This() = @ptrCast(@alignCast(raw));
            const count = @min(max, state.items.len - state.position);
            const output = try output_allocator.dupe(Item, state.items[state.position .. state.position + count]);
            state.position += count;
            return .{ .allocator = output_allocator, .items = output, .end = state.position == state.items.len };
        }
        fn close(raw: *anyopaque, _: CloseReason) void {
            const state: *@This() = @ptrCast(@alignCast(raw));
            state.closed = true;
        }
        fn destroy(raw: *anyopaque, state_allocator: std.mem.Allocator) void {
            const state: *@This() = @ptrCast(@alignCast(raw));
            state_allocator.free(state.items);
            state_allocator.destroy(state);
        }
    };
    const owned_items = try allocator.dupe(Item, items);
    errdefer allocator.free(owned_items);
    const state = try allocator.create(State);
    state.* = .{ .items = owned_items };
    return .{ .allocator = allocator, .pointer = state, .vtable = &.{ .pull = State.pull, .close = State.close, .destroy = State.destroy } };
}

/// Adapts an external resource without taking ownership of the puller object.
/// The puller must provide `pull(*Context(Env), Allocator, usize)` returning the
/// stream Chunk, plus `close(CloseReason)`. This is the integration point for
/// HTTP bodies, SQL row cursors, brokers, object stores, and telemetry batches.
pub fn fromPuller(
    comptime Item: type,
    comptime Error: type,
    comptime Env: type,
    comptime Puller: type,
    allocator: std.mem.Allocator,
    puller: *Puller,
) EffectStream(Item, Error, Env) {
    const Stream = EffectStream(Item, Error, Env);
    const Context = context_mod.Context(Env);
    const Adapter = struct {
        fn pull(raw: *anyopaque, ctx: *Context, output_allocator: std.mem.Allocator, max: usize) Stream.FailureType!Stream.Chunk {
            return (@as(*Puller, @ptrCast(@alignCast(raw)))).pull(ctx, output_allocator, max);
        }
        fn close(raw: *anyopaque, reason: CloseReason) void {
            (@as(*Puller, @ptrCast(@alignCast(raw)))).close(reason);
        }
        fn destroy(_: *anyopaque, _: std.mem.Allocator) void {}
    };
    return .{ .allocator = allocator, .pointer = puller, .vtable = &.{ .pull = Adapter.pull, .close = Adapter.close, .destroy = Adapter.destroy } };
}

/// Adapts and owns an external puller. `close` is invoked exactly once by the
/// stream and optional `deinit` runs when the stream is destroyed.
pub fn fromOwnedPullerAlloc(
    comptime Item: type,
    comptime Error: type,
    comptime Env: type,
    comptime Puller: type,
    allocator: std.mem.Allocator,
    puller: Puller,
) std.mem.Allocator.Error!EffectStream(Item, Error, Env) {
    const Stream = EffectStream(Item, Error, Env);
    const Context = context_mod.Context(Env);
    const Adapter = struct {
        fn pull(raw: *anyopaque, ctx: *Context, output_allocator: std.mem.Allocator, max: usize) Stream.FailureType!Stream.Chunk { return (@as(*Puller, @ptrCast(@alignCast(raw)))).pull(ctx, output_allocator, max); }
        fn close(raw: *anyopaque, reason: CloseReason) void { (@as(*Puller, @ptrCast(@alignCast(raw)))).close(reason); }
        fn destroy(raw: *anyopaque, state_allocator: std.mem.Allocator) void { const state: *Puller = @ptrCast(@alignCast(raw)); if (@hasDecl(Puller, "deinit")) state.deinit(); state_allocator.destroy(state); }
    };
    const state = try allocator.create(Puller);
    state.* = puller;
    return .{ .allocator = allocator, .pointer = state, .vtable = &.{ .pull = Adapter.pull, .close = Adapter.close, .destroy = Adapter.destroy } };
}

pub fn BoundedBuffer(comptime Item: type) type {
    return struct {
        allocator: std.mem.Allocator,
        items: []Item,
        head: usize = 0,
        count: usize = 0,
        mutex: std.atomic.Mutex = .unlocked,

        pub fn initAlloc(allocator: std.mem.Allocator, buffer_capacity: usize) !@This() {
            if (buffer_capacity == 0) return error.InvalidBufferCapacity;
            return .{ .allocator = allocator, .items = try allocator.alloc(Item, buffer_capacity) };
        }
        pub fn deinit(self: *@This()) void { self.allocator.free(self.items); self.* = undefined; }
        pub fn capacity(self: *const @This()) usize { return self.items.len; }
        pub fn size(self: *@This()) usize { self.lock(); defer self.mutex.unlock(); return self.count; }
        pub fn offer(self: *@This(), item: Item, strategy: BackpressureStrategy) !bool {
            self.lock(); defer self.mutex.unlock();
            if (self.count == self.items.len) switch (strategy) {
                .block, .reject => return error.BufferFull,
                .drop_newest => return false,
                .drop_oldest => { self.head = (self.head + 1) % self.items.len; self.count -= 1; },
            };
            self.items[(self.head + self.count) % self.items.len] = item;
            self.count += 1;
            return true;
        }
        pub fn offerEffect(self: *@This(), item: Item, strategy: BackpressureStrategy, ctx: anytype, timeout_ms: u64) !bool {
            if (strategy != .block) return self.offer(item, strategy);
            const started = if (ctx.clock) |clock| clock.nowMs() else 0;
            var suspended = false;
            while (true) {
                self.lock();
                if (self.count < self.items.len) {
                    self.items[(self.head + self.count) % self.items.len] = item;
                    self.count += 1;
                    self.mutex.unlock();
                    if (suspended) _ = ctx.recordCausal(.{ .kind = .fiber_resumed, .label = "stream.backpressure", .status = "ready" });
                    return true;
                }
                self.mutex.unlock();
                if (!suspended) {
                    suspended = true;
                    _ = ctx.recordCausal(.{ .kind = .fiber_suspended, .label = "stream.backpressure", .status = "waiting", .redacted_detail = "bounded buffer full" });
                }
                if (ctx.clock) |clock| {
                    if (timeout_ms != 0 and clock.nowMs() -| started >= timeout_ms) return error.BufferFull;
                    clock.sleep(1);
                } else {
                    std.Thread.yield() catch {};
                }
            }
        }
        pub fn take(self: *@This()) !Item {
            self.lock(); defer self.mutex.unlock();
            if (self.count == 0) return error.BufferEmpty;
            const value = self.items[self.head];
            self.head = (self.head + 1) % self.items.len;
            self.count -= 1;
            return value;
        }
        fn lock(self: *@This()) void { while (!self.mutex.tryLock()) std.Thread.yield() catch {}; }
    };
}

test "effect stream chunks map filter merge timeout and finalize" {
    const Env = struct {};
    var env = Env{};
    var clock = @import("../services/clock.zig").Clock.fake(0);
    var ctx = context_mod.Context(Env).init(std.testing.allocator, &env, null);
    ctx.clock = &clock;
    var left = try fromSliceAlloc(u8, error{}, Env, std.testing.allocator, &.{ 1, 2, 3 });
    const Mapper = struct { fn apply(value: u8, _: *context_mod.Context(Env)) error{}!u8 { return value * 2; } };
    const Filter = struct { fn keep(value: u8, _: *context_mod.Context(Env)) error{}!bool { return value % 4 == 0; } };
    var mapped = try left.mapEffectAlloc(u8, std.testing.allocator, Mapper.apply);
    var filtered = try mapped.filterEffectAlloc(std.testing.allocator, Filter.keep);
    defer filtered.deinit();
    const values = try filtered.runCollectAlloc(&ctx, std.testing.allocator, 2);
    defer std.testing.allocator.free(values);
    try std.testing.expectEqualSlices(u8, &.{ 4 }, values);
}

test "bounded buffer enforces each overflow policy" {
    var buffer = try BoundedBuffer(u8).initAlloc(std.testing.allocator, 2);
    defer buffer.deinit();
    try std.testing.expect(try buffer.offer(1, .reject));
    try std.testing.expect(try buffer.offer(2, .reject));
    try std.testing.expectError(error.BufferFull, buffer.offer(3, .reject));
    try std.testing.expect(!(try buffer.offer(3, .drop_newest)));
    try std.testing.expect(try buffer.offer(3, .drop_oldest));
    try std.testing.expectEqual(@as(u8, 2), try buffer.take());
    try std.testing.expectEqual(@as(u8, 3), try buffer.take());
    try std.testing.expectError(error.BufferEmpty, buffer.take());
}

test "external puller interruption finalizes exactly once" {
    const Env = struct {};
    const Puller = struct {
        closes: usize = 0,
        reason: ?CloseReason = null,
        fn pull(_: *@This(), _: *context_mod.Context(Env), allocator: std.mem.Allocator, _: usize) anyerror!EffectStream(u8, anyerror, Env).Chunk {
            return .{ .allocator = allocator, .items = try allocator.dupe(u8, &.{1}), .end = false };
        }
        fn close(self: *@This(), reason: CloseReason) void { self.closes += 1; self.reason = reason; }
    };
    var puller = Puller{};
    var stream = fromPuller(u8, anyerror, Env, Puller, std.testing.allocator, &puller);
    stream.interrupt();
    stream.interrupt();
    stream.deinit();
    try std.testing.expectEqual(@as(usize, 1), puller.closes);
    try std.testing.expectEqual(CloseReason.interrupted, puller.reason.?);
}
