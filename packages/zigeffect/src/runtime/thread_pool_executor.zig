//! Track B — `ThreadPoolExecutor`, a `FiberExecutor` backed by real OS threads.
//!
//! A second concrete executor (besides the zio coroutine one), proving the
//! FiberExecutor abstraction works over genuine OS-thread parallelism — now that
//! `CausalStore`/`Ref`/`Hub` are thread-safe. Each `spawn` runs the `FiberJob`
//! on its own `std.Thread`; `join` waits for it; `waitAny` polls completion.
//!
//! HONEST LIMITATION — `interrupt` is best-effort. OS threads cannot be safely
//! async-preempted, so `interrupt` only sets a cooperative cancel flag the job's
//! body may poll (via `isCancelled`); a non-cooperating body runs to completion.
//! Therefore thread-pool `race`/`both` produce the correct RESULT (the winner's)
//! but do NOT short-circuit a loser's WORK — `join` waits for it. (zio's
//! coroutine cancel genuinely stops a parked loser; threads can't.)
//!
//! CONTRACT: `join` before `destroy` (the worker writes its handle until it
//! exits). The job's `FiberJob.context` and result slot must outlive the worker
//! — the structured-concurrency primitives guarantee this by joining all workers
//! before their owning stack frame returns.

const std = @import("std");
const executor_mod = @import("executor.zig");

pub const FiberExecutor = executor_mod.FiberExecutor;
pub const FiberJob = executor_mod.FiberJob;

const PoolHandle = struct {
    thread: std.Thread,
    done: std.atomic.Value(bool),
    cancel: std.atomic.Value(bool),
    job: FiberJob,
};

pub const ThreadPoolExecutor = struct {
    allocator: std.mem.Allocator,

    fn worker(handle: *PoolHandle) void {
        handle.job.run(handle.job.context);
        handle.done.store(true, .release);
    }

    fn spawn(context: ?*anyopaque, job: FiberJob) ?*anyopaque {
        const self: *ThreadPoolExecutor = @ptrCast(@alignCast(context.?));
        const handle = self.allocator.create(PoolHandle) catch return null;
        handle.done = std.atomic.Value(bool).init(false);
        handle.cancel = std.atomic.Value(bool).init(false);
        handle.job = job;
        handle.thread = std.Thread.spawn(.{}, worker, .{handle}) catch {
            self.allocator.destroy(handle);
            return null; // engine falls back to synchronous execution
        };
        return handle;
    }

    fn join(context: ?*anyopaque, raw: *anyopaque) void {
        _ = context;
        const handle: *PoolHandle = @ptrCast(@alignCast(raw));
        handle.thread.join();
    }

    fn destroy(context: ?*anyopaque, raw: *anyopaque) void {
        const self: *ThreadPoolExecutor = @ptrCast(@alignCast(context.?));
        const handle: *PoolHandle = @ptrCast(@alignCast(raw));
        self.allocator.destroy(handle);
    }

    /// Best-effort cooperative cancel — sets the flag; the job's body must poll
    /// `isCancelled` to observe it (OS threads can't be async-preempted).
    fn interruptJob(context: ?*anyopaque, raw: *anyopaque) void {
        _ = context;
        const handle: *PoolHandle = @ptrCast(@alignCast(raw));
        handle.cancel.store(true, .release);
    }

    fn waitAny(context: ?*anyopaque, handles: []const *anyopaque) usize {
        _ = context;
        while (true) {
            for (handles, 0..) |raw, i| {
                const handle: *PoolHandle = @ptrCast(@alignCast(raw));
                if (handle.done.load(.acquire)) return i;
            }
            std.atomic.spinLoopHint();
        }
    }

    const vtable = FiberExecutor.VTable{
        .spawn = spawn,
        .join = join,
        .destroy = destroy,
        .interrupt = interruptJob,
        .waitAny = waitAny,
    };

    pub fn executor(self: *ThreadPoolExecutor) FiberExecutor {
        return .{ .context = self, .vtable = &vtable };
    }
};
