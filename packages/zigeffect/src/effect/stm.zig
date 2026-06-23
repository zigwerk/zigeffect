//! M6.1 (first cut) — Software Transactional Memory.
//!
//! Now meaningful because the multi-threading lift made the primitives
//! thread-safe: concurrent transactions on different OS threads can genuinely
//! conflict, and STM resolves them by optimistic validation + retry.
//!
//! Model: each `TRef(T)` holds a value + a version. A transaction body reads
//! refs (recording the version it observed) and stages writes. `atomically`
//! runs the body, then commits under the `Stm` commit lock: if every read ref's
//! version is unchanged, the staged writes are applied (and their versions
//! bumped); otherwise a conflicting commit interleaved, so the whole
//! transaction is retried. Commits serialize through the `Stm` lock, so the
//! validate-then-apply step is atomic across all refs in the transaction.
//!
//! CONTRACT: the transaction body MUST be a pure function of the refs it reads
//! — it may run multiple times on retry, so external side effects must not
//! happen inside it.
//!
//! SCOPE (honest, like the Stream first cut): a transaction is homogeneous in
//! the ref value type `T`. Heterogeneous transactions (mixing TRef(A) and
//! TRef(B)) need a type-erased read/write log and are a follow-up; the
//! version-validation protocol here is what that will reuse.

const std = @import("std");
const sync = @import("../runtime/sync.zig");

pub const Allocator = std.mem.Allocator;

pub fn TRef(comptime T: type) type {
    return struct {
        const Self = @This();
        value: T,
        version: u64 = 0,
        lock: sync.SpinLock = .{},

        pub fn init(value: T) Self {
            return .{ .value = value };
        }

        /// Direct (non-transactional) read of the current value. For reads
        /// inside a transaction use `Transaction.get`.
        pub fn peek(self: *Self) T {
            self.lock.lock();
            defer self.lock.unlock();
            return self.value;
        }
    };
}

pub fn Transaction(comptime T: type) type {
    return struct {
        const Self = @This();
        const ReadEntry = struct { ref: *TRef(T), observed: u64 };
        const WriteEntry = struct { ref: *TRef(T), value: T };

        allocator: Allocator,
        reads: std.ArrayList(ReadEntry) = .empty,
        writes: std.ArrayList(WriteEntry) = .empty,
        failed: bool = false, // set if an allocation failed mid-body

        fn init(allocator: Allocator) Self {
            return .{ .allocator = allocator };
        }

        fn deinit(self: *Self) void {
            self.reads.deinit(self.allocator);
            self.writes.deinit(self.allocator);
        }

        fn reset(self: *Self) void {
            self.reads.clearRetainingCapacity();
            self.writes.clearRetainingCapacity();
            self.failed = false;
        }

        /// Transactional read. Returns the staged write if this transaction has
        /// already written the ref; otherwise reads the committed value and logs
        /// the observed version for commit-time validation.
        pub fn get(self: *Self, ref: *TRef(T)) T {
            for (self.writes.items) |w| {
                if (w.ref == ref) return w.value;
            }
            ref.lock.lock();
            const v = ref.value;
            const ver = ref.version;
            ref.lock.unlock();
            self.reads.append(self.allocator, .{ .ref = ref, .observed = ver }) catch {
                self.failed = true;
            };
            return v;
        }

        /// Transactional write — staged, applied only at commit.
        pub fn set(self: *Self, ref: *TRef(T), value: T) void {
            for (self.writes.items) |*w| {
                if (w.ref == ref) {
                    w.value = value;
                    return;
                }
            }
            self.writes.append(self.allocator, .{ .ref = ref, .value = value }) catch {
                self.failed = true;
            };
        }
    };
}

pub const Stm = struct {
    commit_lock: sync.SpinLock = .{},

    /// Run `body(txn, ctx)` atomically, retrying on conflict. Returns the body's
    /// result from the committed attempt. The body must be pure (it may run
    /// multiple times).
    pub fn atomically(
        self: *Stm,
        comptime T: type,
        comptime R: type,
        comptime Ctx: type,
        allocator: Allocator,
        ctx: Ctx,
        body: *const fn (*Transaction(T), Ctx) R,
    ) R {
        var txn = Transaction(T).init(allocator);
        defer txn.deinit();
        while (true) {
            txn.reset();
            const result = body(&txn, ctx);
            if (txn.failed) continue; // allocation failure mid-body — retry clean
            if (self.tryCommit(T, &txn)) return result;
            // conflict — another commit changed a ref we read; retry.
        }
    }

    /// Heterogeneous transaction: the body may touch `TRef`s of DIFFERENT value
    /// types. Method form of `atomicallyHetero`.
    pub fn atomicallyMixed(
        self: *Stm,
        comptime R: type,
        comptime Ctx: type,
        allocator: Allocator,
        ctx: Ctx,
        body: *const fn (*HeteroTransaction, Ctx) R,
    ) R {
        return atomicallyHetero(self, R, Ctx, allocator, ctx, body);
    }

    fn tryCommit(self: *Stm, comptime T: type, txn: *Transaction(T)) bool {
        self.commit_lock.lock();
        defer self.commit_lock.unlock();

        // Validate: every read ref's version must be unchanged.
        for (txn.reads.items) |r| {
            r.ref.lock.lock();
            const current = r.ref.version;
            r.ref.lock.unlock();
            if (current != r.observed) return false; // conflict
        }

        // Apply: write staged values + bump versions.
        for (txn.writes.items) |w| {
            w.ref.lock.lock();
            w.ref.value = w.value;
            w.ref.version += 1;
            w.ref.lock.unlock();
        }
        return true;
    }
};

// ─── Track C — heterogeneous STM ─────────────────────────────────────────────
//
// A transaction that touches TRef(A), TRef(B), … of DIFFERENT value types in
// one atomic body. The read/write log is type-erased: `get`/`set` are generic
// over the per-ref type T and generate (at the comptime call site) the
// type-specific version-reader, write-applier, and free fns that the type-erased
// commit drives. Validation is type-agnostic (u64 version compare); apply is
// type-specific via the generated fn.

const HeteroRead = struct {
    ref: *anyopaque,
    read_version: *const fn (*anyopaque) u64,
    observed: u64,
};

const HeteroWrite = struct {
    ref: *anyopaque,
    value: *anyopaque, // an allocated *T (aligned); applied/freed via the fns below
    apply: *const fn (ref: *anyopaque, value: *anyopaque) void,
    free: *const fn (Allocator, value: *anyopaque) void,
};

pub const HeteroTransaction = struct {
    allocator: Allocator,
    reads: std.ArrayList(HeteroRead) = .empty,
    writes: std.ArrayList(HeteroWrite) = .empty,
    failed: bool = false,

    fn init(allocator: Allocator) HeteroTransaction {
        return .{ .allocator = allocator };
    }

    fn deinit(self: *HeteroTransaction) void {
        self.clearWrites();
        self.reads.deinit(self.allocator);
        self.writes.deinit(self.allocator);
    }

    fn clearWrites(self: *HeteroTransaction) void {
        for (self.writes.items) |w| w.free(self.allocator, w.value);
        self.writes.clearRetainingCapacity();
    }

    fn reset(self: *HeteroTransaction) void {
        self.reads.clearRetainingCapacity();
        self.clearWrites();
        self.failed = false;
    }

    fn Ops(comptime T: type) type {
        return struct {
            fn readVersion(raw: *anyopaque) u64 {
                const ref: *TRef(T) = @ptrCast(@alignCast(raw));
                ref.lock.lock();
                defer ref.lock.unlock();
                return ref.version;
            }
            fn apply(raw_ref: *anyopaque, raw_val: *anyopaque) void {
                const ref: *TRef(T) = @ptrCast(@alignCast(raw_ref));
                const val: *T = @ptrCast(@alignCast(raw_val));
                ref.lock.lock();
                defer ref.lock.unlock();
                ref.value = val.*;
                ref.version += 1;
            }
            fn free(allocator: Allocator, raw_val: *anyopaque) void {
                const val: *T = @ptrCast(@alignCast(raw_val));
                allocator.destroy(val);
            }
        };
    }

    /// Transactional read of `ref`. Returns a staged write if present, else the
    /// committed value (logging the observed version for commit validation).
    pub fn get(self: *HeteroTransaction, comptime T: type, ref: *TRef(T)) T {
        const ref_erased: *anyopaque = @ptrCast(ref);
        for (self.writes.items) |w| {
            if (w.ref == ref_erased) {
                const val: *T = @ptrCast(@alignCast(w.value));
                return val.*;
            }
        }
        ref.lock.lock();
        const v = ref.value;
        const ver = ref.version;
        ref.lock.unlock();
        self.reads.append(self.allocator, .{
            .ref = ref_erased,
            .read_version = Ops(T).readVersion,
            .observed = ver,
        }) catch {
            self.failed = true;
        };
        return v;
    }

    /// Stage a transactional write of `ref` (applied only at commit). Replaces an
    /// earlier staged write of the same ref.
    pub fn set(self: *HeteroTransaction, comptime T: type, ref: *TRef(T), value: T) void {
        const ref_erased: *anyopaque = @ptrCast(ref);
        // Replace an existing staged write for this ref.
        for (self.writes.items) |*w| {
            if (w.ref == ref_erased) {
                const val: *T = @ptrCast(@alignCast(w.value));
                val.* = value;
                return;
            }
        }
        const slot = self.allocator.create(T) catch {
            self.failed = true;
            return;
        };
        slot.* = value;
        self.writes.append(self.allocator, .{
            .ref = ref_erased,
            .value = @ptrCast(slot),
            .apply = Ops(T).apply,
            .free = Ops(T).free,
        }) catch {
            self.failed = true;
            self.allocator.destroy(slot);
        };
    }
};

pub fn atomicallyHetero(
    self: *Stm,
    comptime R: type,
    comptime Ctx: type,
    allocator: Allocator,
    ctx: Ctx,
    body: *const fn (*HeteroTransaction, Ctx) R,
) R {
    var txn = HeteroTransaction.init(allocator);
    defer txn.deinit();
    while (true) {
        txn.reset();
        const result = body(&txn, ctx);
        if (txn.failed) continue;
        if (tryCommitHetero(self, &txn)) return result;
    }
}

fn tryCommitHetero(self: *Stm, txn: *HeteroTransaction) bool {
    self.commit_lock.lock();
    defer self.commit_lock.unlock();
    for (txn.reads.items) |r| {
        if (r.read_version(r.ref) != r.observed) return false; // conflict
    }
    for (txn.writes.items) |w| {
        w.apply(w.ref, w.value);
    }
    return true;
}
