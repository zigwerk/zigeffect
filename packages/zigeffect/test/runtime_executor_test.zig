//! M1.1 — `Runtime(Env).withExecutor` passthrough.
//!
//! Proves: the canonical top-level entry point (`Runtime(Env)`) can be built
//! with a `FiberExecutor`, and that executor is propagated onto every
//! `Context` produced for an `Effect` to run inside. Without this, the D2
//! productization (`Effect.fork` as a real zio coroutine) was invisible from
//! `Runtime(Env)` — users had to drop to `FiberRuntime` to attach an executor.

const std = @import("std");
const fx = @import("zigeffect");
const fixtures = @import("support/fixtures.zig");

/// Minimal in-core executor; only the vtable identity matters for this test —
/// we just need a value that survives the builder + context propagation and is
/// observable by an effect body.
const ProbeExecutor = struct {
    seen: usize = 0,

    fn spawn(ctx: ?*anyopaque, job: fx.FiberJob) ?*anyopaque {
        const self: *ProbeExecutor = @ptrCast(@alignCast(ctx.?));
        self.seen += 1;
        job.run(job.context);
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
    fn executor(self: *ProbeExecutor) fx.FiberExecutor {
        return .{ .context = self, .vtable = &vtable };
    }
};

/// Effect body that inspects `ctx.executor` — proves the executor reached the
/// running effect through `Runtime(Env)`.
const ExecutorWitness = struct {
    var executor_was_visible: bool = false;

    fn run(ctx: *fx.Context(fx.TestServices)) fixtures.TestError!u32 {
        executor_was_visible = ctx.executor != null;
        return 7;
    }
};

test "Runtime(Env).withExecutor propagates the executor to the running effect's Context" {
    var env = try fx.TestEnv.init(std.testing.allocator);
    defer env.deinit();
    var probe = ProbeExecutor{};

    var runtime = fx.Runtime(fx.TestServices)
        .init(std.testing.allocator, &env.services)
        .withClock(&env.services.clock)
        .withExecutor(probe.executor())
        .provides(.{ fx.Logger, fx.Config, fx.Metrics, fx.Tracing, fx.MemoryFileSystem, fx.Clock });

    ExecutorWitness.executor_was_visible = false;
    const program = fx.Effect(u32, fixtures.TestError, fx.TestServices).fromFn(ExecutorWitness.run);
    const value = try runtime.run(program);

    try std.testing.expectEqual(@as(u32, 7), value);
    // The headline assertion: the executor set on the Runtime builder reached
    // the Context the effect ran inside.
    try std.testing.expect(ExecutorWitness.executor_was_visible);
}

test "Runtime(Env) default (no executor) keeps the deterministic posture" {
    var env = try fx.TestEnv.init(std.testing.allocator);
    defer env.deinit();

    var runtime = fx.Runtime(fx.TestServices)
        .init(std.testing.allocator, &env.services)
        .withClock(&env.services.clock)
        .provides(.{ fx.Logger, fx.Config, fx.Metrics, fx.Tracing, fx.MemoryFileSystem, fx.Clock });

    ExecutorWitness.executor_was_visible = false;
    const program = fx.Effect(u32, fixtures.TestError, fx.TestServices).fromFn(ExecutorWitness.run);
    const value = try runtime.run(program);

    try std.testing.expectEqual(@as(u32, 7), value);
    try std.testing.expect(!ExecutorWitness.executor_was_visible);
}
