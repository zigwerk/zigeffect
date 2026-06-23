//! M6.1 (first cut) — STM tests, including a multi-threaded conflict-retry proof.

const std = @import("std");
const fx = @import("zigeffect");

const U64Ref = fx.TRef(u64);
const Txn = fx.Transaction(u64);

test "atomically commits a single read-modify-write" {
    const allocator = std.testing.allocator;
    var stm = fx.Stm{};
    var counter = U64Ref.init(10);

    const Body = struct {
        fn run(txn: *Txn, ref: *U64Ref) u64 {
            const v = txn.get(ref);
            txn.set(ref, v + 5);
            return v + 5;
        }
    };
    const result = stm.atomically(u64, u64, *U64Ref, allocator, &counter, Body.run);
    try std.testing.expectEqual(@as(u64, 15), result);
    try std.testing.expectEqual(@as(u64, 15), counter.peek());
}

test "a transaction sees its own staged writes (read-after-write within the txn)" {
    const allocator = std.testing.allocator;
    var stm = fx.Stm{};
    var ref = U64Ref.init(0);

    const Body = struct {
        fn run(txn: *Txn, r: *U64Ref) u64 {
            txn.set(r, 100);
            // The transactional read must observe the staged write, not the
            // committed value (still 0).
            return txn.get(r);
        }
    };
    const seen = stm.atomically(u64, u64, *U64Ref, allocator, &ref, Body.run);
    try std.testing.expectEqual(@as(u64, 100), seen);
    try std.testing.expectEqual(@as(u64, 100), ref.peek());
}

test "atomically moves a value between two refs atomically (multi-ref transaction)" {
    const allocator = std.testing.allocator;
    var stm = fx.Stm{};
    var a = U64Ref.init(100);
    var b = U64Ref.init(0);

    const Pair = struct { a: *U64Ref, b: *U64Ref };
    const Body = struct {
        fn run(txn: *Txn, p: Pair) void {
            const av = txn.get(p.a);
            txn.set(p.a, av - 30);
            txn.set(p.b, txn.get(p.b) + 30);
        }
    };
    stm.atomically(u64, void, Pair, allocator, .{ .a = &a, .b = &b }, Body.run);
    try std.testing.expectEqual(@as(u64, 70), a.peek());
    try std.testing.expectEqual(@as(u64, 30), b.peek());
    // Total conserved.
    try std.testing.expectEqual(@as(u64, 100), a.peek() + b.peek());
}

// ── Heterogeneous transactions (Track C) ──

const HTxn = fx.HeteroTransaction;

test "heterogeneous transaction touches a TRef(u64) AND a TRef([]const u8) atomically" {
    const allocator = std.testing.allocator;
    var stm = fx.Stm{};
    var balance = fx.TRef(u64).init(100);
    var label = fx.TRef([]const u8).init("idle");

    const Refs = struct { balance: *fx.TRef(u64), label: *fx.TRef([]const u8) };
    const Body = struct {
        fn run(txn: *HTxn, refs: Refs) void {
            const b = txn.get(u64, refs.balance);
            txn.set(u64, refs.balance, b - 30);
            txn.set([]const u8, refs.label, "charged");
        }
    };
    stm.atomicallyMixed(void, Refs, allocator, .{ .balance = &balance, .label = &label }, Body.run);

    try std.testing.expectEqual(@as(u64, 70), balance.peek());
    try std.testing.expectEqualStrings("charged", label.peek());
}

test "heterogeneous read-after-write within a transaction sees the staged write" {
    const allocator = std.testing.allocator;
    var stm = fx.Stm{};
    var ref = fx.TRef(u32).init(0);

    const Body = struct {
        fn run(txn: *HTxn, r: *fx.TRef(u32)) u32 {
            txn.set(u32, r, 77);
            return txn.get(u32, r); // must see the staged 77, not committed 0
        }
    };
    const seen = stm.atomicallyMixed(u32, *fx.TRef(u32), allocator, &ref, Body.run);
    try std.testing.expectEqual(@as(u32, 77), seen);
    try std.testing.expectEqual(@as(u32, 77), ref.peek());
}

const HeteroWorker = struct {
    stm: *fx.Stm,
    a: *fx.TRef(u64),
    b: *fx.TRef(u64),
    allocator: std.mem.Allocator,

    const Refs = struct { a: *fx.TRef(u64), b: *fx.TRef(u64) };
    fn body(txn: *HTxn, refs: Refs) void {
        // Atomically increment BOTH refs — conserving (a - b) under conflict.
        txn.set(u64, refs.a, txn.get(u64, refs.a) + 1);
        txn.set(u64, refs.b, txn.get(u64, refs.b) + 1);
    }
    fn run(self: *HeteroWorker) void {
        var i: usize = 0;
        while (i < 1000) : (i += 1) {
            self.stm.atomicallyMixed(void, Refs, self.allocator, .{ .a = self.a, .b = self.b }, body);
        }
    }
};

test "heterogeneous STM: concurrent two-ref transactions stay consistent (no lost updates)" {
    const allocator = std.testing.allocator;
    var stm = fx.Stm{};
    var a = fx.TRef(u64).init(0);
    var b = fx.TRef(u64).init(0);

    var workers: [8]HeteroWorker = undefined;
    var threads: [8]std.Thread = undefined;
    for (&workers, 0..) |*w, i| {
        w.* = .{ .stm = &stm, .a = &a, .b = &b, .allocator = allocator };
        threads[i] = try std.Thread.spawn(.{}, HeteroWorker.run, .{w});
    }
    for (&threads) |t| t.join();

    // Both refs incremented exactly 8*1000 times — and stayed EQUAL (the
    // two-ref write committed atomically every time).
    try std.testing.expectEqual(@as(u64, 8000), a.peek());
    try std.testing.expectEqual(@as(u64, 8000), b.peek());
    try std.testing.expectEqual(a.peek(), b.peek());
}

// ── Multi-threaded conflict-retry proof ──

const STM_THREADS = 8;
const STM_OPS = 1000;

const StmWorker = struct {
    stm: *fx.Stm,
    ref: *U64Ref,
    allocator: std.mem.Allocator,

    fn body(txn: *Txn, ref: *U64Ref) void {
        txn.set(ref, txn.get(ref) + 1);
    }
    fn run(self: *StmWorker) void {
        var i: usize = 0;
        while (i < STM_OPS) : (i += 1) {
            self.stm.atomically(u64, void, *U64Ref, self.allocator, self.ref, body);
        }
    }
};

test "STM resolves concurrent conflicts by retry — no lost updates across 8 threads" {
    const allocator = std.testing.allocator;
    var stm = fx.Stm{};
    var counter = U64Ref.init(0);

    var workers: [STM_THREADS]StmWorker = undefined;
    var threads: [STM_THREADS]std.Thread = undefined;
    for (&workers, 0..) |*w, i| {
        w.* = .{ .stm = &stm, .ref = &counter, .allocator = allocator };
        threads[i] = try std.Thread.spawn(.{}, StmWorker.run, .{w});
    }
    for (&threads) |t| t.join();

    // Every increment landed. Without conflict-retry, concurrent
    // read-modify-write transactions would lose updates (count < N).
    try std.testing.expectEqual(@as(u64, STM_THREADS * STM_OPS), counter.peek());
}
