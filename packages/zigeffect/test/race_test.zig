//! M4.4 / M4.5 — race family (core: fallback + synchronous racing executor).
//! Real timing-based short-circuit is proven in the zigeffect-zio package.

const std = @import("std");
const fx = @import("zigeffect");
const fixtures = @import("support/fixtures.zig");

const E = fx.Effect(u32, fixtures.TestError, fx.TestServices);

fn rt(env: *fx.TestEnv, exec: ?fx.FiberExecutor) fx.Runtime(fx.TestServices) {
    var runtime = fx.Runtime(fx.TestServices)
        .init(std.testing.allocator, &env.services)
        .withClock(&env.services.clock)
        .provides(.{ fx.Logger, fx.Config, fx.Metrics, fx.Tracing, fx.MemoryFileSystem, fx.Clock });
    if (exec) |e| runtime = runtime.withExecutor(e);
    return runtime;
}

/// A non-racing executor (spawn/join/destroy only — no waitAny/interrupt), so
/// `canRace()` is false and the race family must fall back to sequential.
const PlainExec = struct {
    fn spawn(ctx: ?*anyopaque, job: fx.FiberJob) ?*anyopaque {
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
    fn executor(self: *PlainExec) fx.FiberExecutor {
        return .{ .context = self, .vtable = &vtable };
    }
};

/// A racing executor that runs each job synchronously on spawn (so every job is
/// already complete) and whose `waitAny` returns the first index. Exercises the
/// executor race code path deterministically.
const SyncRacingExec = struct {
    fn spawn(ctx: ?*anyopaque, job: fx.FiberJob) ?*anyopaque {
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
    fn interrupt(ctx: ?*anyopaque, handle: *anyopaque) void {
        _ = ctx;
        _ = handle;
    }
    fn waitAny(ctx: ?*anyopaque, handles: []const *anyopaque) usize {
        _ = ctx;
        _ = handles;
        return 0; // all jobs already ran synchronously; first wins
    }
    const vtable = fx.FiberExecutor.VTable{ .spawn = spawn, .join = join, .destroy = destroy, .interrupt = interrupt, .waitAny = waitAny };
    fn executor(self: *SyncRacingExec) fx.FiberExecutor {
        return .{ .context = self, .vtable = &vtable };
    }
};

test "raceFirst with no executor falls back to the left branch" {
    var env = try fx.TestEnv.init(std.testing.allocator);
    defer env.deinit();
    var runtime = rt(&env, null);
    const program = E.succeed(1).raceFirst(E.succeed(2));
    try std.testing.expectEqual(@as(u32, 1), try runtime.run(program));
}

test "raceFirst with a non-racing executor (no waitAny) falls back to the left branch" {
    var env = try fx.TestEnv.init(std.testing.allocator);
    defer env.deinit();
    var exec = PlainExec{};
    var runtime = rt(&env, exec.executor());
    const program = E.succeed(7).raceFirst(E.succeed(9));
    try std.testing.expectEqual(@as(u32, 7), try runtime.run(program));
}

test "raceFirst with a synchronous racing executor takes the executor path (winner 0 = left)" {
    var env = try fx.TestEnv.init(std.testing.allocator);
    defer env.deinit();
    var exec = SyncRacingExec{};
    var runtime = rt(&env, exec.executor());
    const program = E.succeed(11).raceFirst(E.succeed(22));
    try std.testing.expectEqual(@as(u32, 11), try runtime.run(program));
}

test "raceFirst propagates the winner's failure" {
    var env = try fx.TestEnv.init(std.testing.allocator);
    defer env.deinit();
    var exec = SyncRacingExec{};
    var runtime = rt(&env, exec.executor());
    // Winner is index 0 (left); if it fails, raceFirst returns that failure.
    const program = E.fail(error.Boom).raceFirst(E.succeed(2));
    try std.testing.expectError(error.Boom, runtime.run(program));
}

test "raceAll with a synchronous racing executor returns the first item's result" {
    var env = try fx.TestEnv.init(std.testing.allocator);
    defer env.deinit();
    var exec = SyncRacingExec{};
    var runtime = rt(&env, exec.executor());
    const items = [_]E{ E.succeed(100), E.succeed(200), E.succeed(300) };
    const program = fx.raceAll(E, fixtures.TestError, fx.TestServices, &items);
    try std.testing.expectEqual(@as(u32, 100), try runtime.run(program));
}

test "raceAll with no executor falls back to the first item" {
    var env = try fx.TestEnv.init(std.testing.allocator);
    defer env.deinit();
    var runtime = rt(&env, null);
    const items = [_]E{ E.succeed(5), E.succeed(6) };
    const program = fx.raceAll(E, fixtures.TestError, fx.TestServices, &items);
    try std.testing.expectEqual(@as(u32, 5), try runtime.run(program));
}
