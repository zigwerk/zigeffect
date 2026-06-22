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
