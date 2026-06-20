const std = @import("std");
const fx = @import("zigeffect");
const fixtures = @import("support/fixtures.zig");

// A minimal in-core executor with no external dependency: it runs each job
// eagerly on spawn and treats join/destroy as no-ops. Its only purpose is to
// exercise the FiberExecutor plumbing in the core and prove that routing a
// forked fiber THROUGH an executor yields the same exit and the same causal
// structure as the default synchronous-on-join path. (The zigeffect-zio package
// supplies the real coroutine-backed executor.)
const SyncExecutor = struct {
    spawned: usize = 0,

    fn spawn(ctx: ?*anyopaque, job: fx.FiberJob) ?*anyopaque {
        const self: *SyncExecutor = @ptrCast(@alignCast(ctx.?));
        self.spawned += 1;
        job.run(job.context);
        // Non-null sentinel handle: signals "spawned" so join awaits via the
        // executor path rather than re-running synchronously.
        return ctx;
    }
    fn join(ctx: ?*anyopaque, handle: *anyopaque) void {
        _ = ctx;
        _ = handle;
    }
    fn destroy(ctx: ?*anyopaque, handle: *anyopaque) void {
        _ = ctx;
        _ = handle;
    }

    const vtable = fx.FiberExecutor.VTable{ .spawn = spawn, .join = join, .destroy = destroy };

    fn executor(self: *SyncExecutor) fx.FiberExecutor {
        return .{ .context = self, .vtable = &vtable };
    }
};

fn runForkProgram(executor: ?fx.FiberExecutor, store: *fx.CausalStore) !u32 {
    var env = try fx.TestEnv.init(std.testing.allocator);
    defer env.deinit();

    var runtime = fx.FiberRuntime(fx.TestServices)
        .init(std.testing.allocator, &env.services)
        .withClock(&env.services.clock)
        .withCausalStore(store)
        .provides(.{ fx.Logger, fx.Config, fx.Metrics, fx.Tracing, fx.MemoryFileSystem, fx.Clock });
    if (executor) |e| runtime = runtime.withExecutor(e);
    defer runtime.deinit();

    const program = fx.Effect(u32, fixtures.TestError, fx.TestServices).succeed(7);
    const fiber = try runtime.fork(program);
    const exit = runtime.join(fiber);
    return switch (exit) {
        .success => |value| value,
        else => error.UnexpectedExit,
    };
}

test "FiberExecutor: a forked fiber routed through an executor matches the synchronous path" {
    // Default path: no executor (fiber runs synchronously on join).
    var det_store = fx.CausalStore.init(std.testing.allocator);
    defer det_store.deinit();
    const det_value = try runForkProgram(null, &det_store);
    try std.testing.expectEqual(@as(u32, 7), det_value);

    // Executor path: fiber spawned onto the executor at fork; join awaits it.
    var exec = SyncExecutor{};
    var exec_store = fx.CausalStore.init(std.testing.allocator);
    defer exec_store.deinit();
    const exec_value = try runForkProgram(exec.executor(), &exec_store);
    try std.testing.expectEqual(@as(u32, 7), exec_value);
    try std.testing.expectEqual(@as(usize, 1), exec.spawned);

    // Identical exit value AND identical causal structure across both paths.
    var det_snap = try det_store.snapshot(std.testing.allocator);
    defer det_snap.deinit();
    var exec_snap = try exec_store.snapshot(std.testing.allocator);
    defer exec_snap.deinit();
    try std.testing.expect(try fx.causalStructurallyEquivalent(std.testing.allocator, det_snap.events, exec_snap.events));
}

// An executor whose handle is heap-allocated, like the real zio one. Used to
// prove that an un-joined fiber's handle is drained (freed) at deinit — if the
// drain were missing, std.testing.allocator would report a leak.
const BoxExecutor = struct {
    allocator: std.mem.Allocator,

    const Box = struct { ran: bool };

    fn spawn(ctx: ?*anyopaque, job: fx.FiberJob) ?*anyopaque {
        const self: *BoxExecutor = @ptrCast(@alignCast(ctx.?));
        const box = self.allocator.create(Box) catch return null;
        box.* = .{ .ran = false };
        job.run(job.context);
        box.ran = true;
        return box;
    }
    fn join(ctx: ?*anyopaque, handle: *anyopaque) void {
        _ = ctx;
        _ = handle;
    }
    fn destroy(ctx: ?*anyopaque, handle: *anyopaque) void {
        const self: *BoxExecutor = @ptrCast(@alignCast(ctx.?));
        const box: *Box = @ptrCast(@alignCast(handle));
        self.allocator.destroy(box);
    }
    const vtable = fx.FiberExecutor.VTable{ .spawn = spawn, .join = join, .destroy = destroy };
    fn executor(self: *BoxExecutor) fx.FiberExecutor {
        return .{ .context = self, .vtable = &vtable };
    }
};

test "FiberExecutor: an un-joined executor fiber is drained at deinit (no leak)" {
    var env = try fx.TestEnv.init(std.testing.allocator);
    defer env.deinit();
    var exec = BoxExecutor{ .allocator = std.testing.allocator };

    var runtime = fx.FiberRuntime(fx.TestServices)
        .init(std.testing.allocator, &env.services)
        .withClock(&env.services.clock)
        .withExecutor(exec.executor())
        .provides(.{ fx.Logger, fx.Config, fx.Metrics, fx.Tracing, fx.MemoryFileSystem, fx.Clock });
    defer runtime.deinit(); // must drain the un-joined fiber's heap handle

    const program = fx.Effect(u32, fixtures.TestError, fx.TestServices).succeed(7);
    _ = try runtime.fork(program); // forked, intentionally never joined
    // If deinit failed to drain the handle, testing.allocator would flag the leak.
}

test "FiberExecutor: spawn declined (null handle) falls back to synchronous execution" {
    const Declining = struct {
        fn spawn(ctx: ?*anyopaque, job: fx.FiberJob) ?*anyopaque {
            _ = ctx;
            _ = job; // never runs the job
            return null; // decline → runtime must run it synchronously on join
        }
        fn join(ctx: ?*anyopaque, handle: *anyopaque) void {
            _ = ctx;
            _ = handle;
        }
        fn destroy(ctx: ?*anyopaque, handle: *anyopaque) void {
            _ = ctx;
            _ = handle;
        }
        const vtable = fx.FiberExecutor.VTable{ .spawn = spawn, .join = join, .destroy = destroy };
    };
    var store = fx.CausalStore.init(std.testing.allocator);
    defer store.deinit();
    const value = try runForkProgram(.{ .context = null, .vtable = &Declining.vtable }, &store);
    try std.testing.expectEqual(@as(u32, 7), value);
}
