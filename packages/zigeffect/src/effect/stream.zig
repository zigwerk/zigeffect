//! M6.2 (first cut) — `Stream(Item)`, a pull-based composable stream.
//!
//! This is the synchronous pull model: a stream is anything with
//! `next() ?Item` (null = end), and combinators wrap a parent stream lazily —
//! no work happens until a terminal operation pulls. Combinators and terminals
//! are defined ONCE on the generic `Stream(Item, Impl)` wrapper, so every stage
//! composes fluently: `fromSlice(...).map(...).filter(...).take(n).runCollect(a)`.
//!
//! SCOPE (honest): this first cut is synchronous and value-pull. A fully
//! effectful `Stream<A,E,R>` whose `next` runs an `Effect` (and can suspend on
//! the async backend, with chunking and backpressure) is a follow-up — it
//! layers the same combinator surface over an effectful source. The pull model
//! here is the foundation that surface will reuse.

const std = @import("std");

pub const Allocator = std.mem.Allocator;

/// The generic stream wrapper. `Impl` is any type with `next(*Impl) ?Item`.
/// All combinators and terminals live here, so each composes uniformly.
pub fn Stream(comptime Item: type, comptime Impl: type) type {
    return struct {
        const Self = @This();
        pub const ItemType = Item;

        impl: Impl,

        pub fn next(self: *Self) ?Item {
            return self.impl.next();
        }

        // ── Lazy combinators (no work until a terminal pulls) ──

        pub fn map(self: Self, comptime Out: type, f: *const fn (Item) Out) Stream(Out, MapImpl(Self, Item, Out)) {
            return .{ .impl = .{ .parent = self, .f = f } };
        }

        pub fn filter(self: Self, pred: *const fn (Item) bool) Stream(Item, FilterImpl(Self, Item)) {
            return .{ .impl = .{ .parent = self, .pred = pred } };
        }

        pub fn take(self: Self, n: usize) Stream(Item, TakeImpl(Self, Item)) {
            return .{ .impl = .{ .parent = self, .remaining = n } };
        }

        pub fn drop(self: Self, n: usize) Stream(Item, DropImpl(Self, Item)) {
            return .{ .impl = .{ .parent = self, .to_drop = n } };
        }

        // ── Terminal operations (consume the stream) ──

        /// Collect into an allocated slice; caller owns and frees it.
        pub fn runCollect(self: Self, allocator: Allocator) Allocator.Error![]Item {
            var s = self;
            var list: std.ArrayList(Item) = .empty;
            errdefer list.deinit(allocator);
            while (s.next()) |item| try list.append(allocator, item);
            return list.toOwnedSlice(allocator);
        }

        /// Pull every item for side effect; discard values.
        pub fn forEach(self: Self, f: *const fn (Item) void) void {
            var s = self;
            while (s.next()) |item| f(item);
        }

        /// Left fold over the stream.
        pub fn fold(self: Self, comptime Acc: type, init: Acc, f: *const fn (Acc, Item) Acc) Acc {
            var s = self;
            var acc = init;
            while (s.next()) |item| acc = f(acc, item);
            return acc;
        }

        /// Count the items (consumes the stream).
        pub fn count(self: Self) usize {
            var s = self;
            var n: usize = 0;
            while (s.next()) |_| n += 1;
            return n;
        }

        /// Pull every item, discarding them (run for effect on an effectful source).
        pub fn runDrain(self: Self) void {
            var s = self;
            while (s.next()) |_| {}
        }
    };
}

// ── Source / combinator impls (each just provides next()) ──

fn SliceImpl(comptime Item: type) type {
    return struct {
        items: []const Item,
        pos: usize = 0,
        pub fn next(self: *@This()) ?Item {
            if (self.pos >= self.items.len) return null;
            defer self.pos += 1;
            return self.items[self.pos];
        }
    };
}

fn MapImpl(comptime Parent: type, comptime In: type, comptime Out: type) type {
    return struct {
        parent: Parent,
        f: *const fn (In) Out,
        pub fn next(self: *@This()) ?Out {
            const x = self.parent.next() orelse return null;
            return self.f(x);
        }
    };
}

fn FilterImpl(comptime Parent: type, comptime Item: type) type {
    return struct {
        parent: Parent,
        pred: *const fn (Item) bool,
        pub fn next(self: *@This()) ?Item {
            while (self.parent.next()) |x| {
                if (self.pred(x)) return x;
            }
            return null;
        }
    };
}

fn TakeImpl(comptime Parent: type, comptime Item: type) type {
    return struct {
        parent: Parent,
        remaining: usize,
        pub fn next(self: *@This()) ?Item {
            if (self.remaining == 0) return null;
            const x = self.parent.next() orelse return null;
            self.remaining -= 1;
            return x;
        }
    };
}

fn DropImpl(comptime Parent: type, comptime Item: type) type {
    return struct {
        parent: Parent,
        to_drop: usize,
        pub fn next(self: *@This()) ?Item {
            while (self.to_drop > 0) {
                _ = self.parent.next() orelse return null;
                self.to_drop -= 1;
            }
            return self.parent.next();
        }
    };
}

// ── Constructors ──

/// A stream over a borrowed slice. The slice must outlive the stream.
pub fn fromSlice(comptime Item: type, items: []const Item) Stream(Item, SliceImpl(Item)) {
    return .{ .impl = .{ .items = items } };
}

/// An empty stream (yields nothing).
pub fn empty(comptime Item: type) Stream(Item, SliceImpl(Item)) {
    return .{ .impl = .{ .items = &[_]Item{} } };
}
