//! Track 4 (M4.1 / M4.2) — Effect structured concurrency.

const std = @import("std");
const fx = @import("zigeffect");
const fixtures = @import("support/fixtures.zig");

const E = fx.Effect(u32, fixtures.TestError, fx.TestServices);

/// Counts spawn/join/destroy calls so we can assert vtable pairing — a buggy
/// primitive that forgot to join or destroy would now fail loudly.
const ProbeExec = struct {
    spawned: usize = 0,
    joined: usize = 0,
    destroyed: usize = 0,
    fn spawn(ctx: ?*anyopaque, job: fx.FiberJob) ?*anyopaque {
        const self: *ProbeExec = @ptrCast(@alignCast(ctx.?));
        self.spawned += 1;
        job.run(job.context);
        return ctx;
    }
    fn join(ctx: ?*anyopaque, handle: *anyopaque) void {
        const self: *ProbeExec = @ptrCast(@alignCast(ctx.?));
        self.joined += 1;
        _ = handle;
    }
    fn destroy(ctx: ?*anyopaque, handle: *anyopaque) void {
        const self: *ProbeExec = @ptrCast(@alignCast(ctx.?));
        self.destroyed += 1;
        _ = handle;
    }
    const vtable = fx.FiberExecutor.VTable{ .spawn = spawn, .join = join, .destroy = destroy };
    fn executor(self: *ProbeExec) fx.FiberExecutor {
        return .{ .context = self, .vtable = &vtable };
    }
};

/// Always refuses to spawn — exercises the spawn-decline drain-then-inline
/// fallback path that ProbeExec doesn't cover.
const DecliningExec = struct {
    spawn_attempts: usize = 0,
    fn spawn(ctx: ?*anyopaque, job: fx.FiberJob) ?*anyopaque {
        const self: *DecliningExec = @ptrCast(@alignCast(ctx.?));
        self.spawn_attempts += 1;
        _ = job;
        return null; // primitive falls back to inline-sequential.
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
    fn executor(self: *DecliningExec) fx.FiberExecutor {
        return .{ .context = self, .vtable = &vtable };
    }
};

fn runtimeWith(env: *fx.TestEnv, exec: ?fx.FiberExecutor) fx.Runtime(fx.TestServices) {
    var rt = fx.Runtime(fx.TestServices)
        .init(std.testing.allocator, &env.services)
        .withClock(&env.services.clock)
        .provides(.{ fx.Logger, fx.Config, fx.Metrics, fx.Tracing, fx.MemoryFileSystem, fx.Clock });
    if (exec) |e| rt = rt.withExecutor(e);
    return rt;
}

const DoubleBody = struct {
    fn run(item: u32, ctx: *fx.Context(fx.TestServices)) fixtures.TestError!u32 {
        _ = ctx;
        return item * 2;
    }
    fn failsOnTwo(item: u32, ctx: *fx.Context(fx.TestServices)) fixtures.TestError!u32 {
        _ = ctx;
        if (item == 2) return error.Boom;
        return item * 2;
    }
};

test "M4.1 forEachPar: no executor falls back to sequential — same result as forEachAlloc" {
    var env = try fx.TestEnv.init(std.testing.allocator);
    defer env.deinit();
    var rt = runtimeWith(&env, null);

    const items = [_]u32{ 1, 2, 3 };
    const program = fx.forEachPar(u32, u32, fixtures.TestError, fx.TestServices, &items, DoubleBody.run);
    const results = try rt.run(program);
    defer std.testing.allocator.free(results);
    try std.testing.expectEqualSlices(u32, &.{ 2, 4, 6 }, results);
}

test "M4.1 forEachPar with executor: spawn / join / destroy are paired one-per-item" {
    var env = try fx.TestEnv.init(std.testing.allocator);
    defer env.deinit();
    var exec = ProbeExec{};
    var rt = runtimeWith(&env, exec.executor());

    const items = [_]u32{ 10, 20, 30, 40 };
    const program = fx.forEachPar(u32, u32, fixtures.TestError, fx.TestServices, &items, DoubleBody.run);
    const results = try rt.run(program);
    defer std.testing.allocator.free(results);
    try std.testing.expectEqualSlices(u32, &.{ 20, 40, 60, 80 }, results);
    // Vtable pairing: each item gets spawn + join + destroy. A primitive that
    // forgot to join or leaked a handle would fail here.
    try std.testing.expectEqual(@as(usize, 4), exec.spawned);
    try std.testing.expectEqual(@as(usize, 4), exec.joined);
    try std.testing.expectEqual(@as(usize, 4), exec.destroyed);
}

test "M4.1 forEachPar: empty input returns an empty slice (no allocator churn)" {
    var env = try fx.TestEnv.init(std.testing.allocator);
    defer env.deinit();
    var exec = ProbeExec{};
    var rt = runtimeWith(&env, exec.executor());

    const items = [_]u32{};
    const program = fx.forEachPar(u32, u32, fixtures.TestError, fx.TestServices, &items, DoubleBody.run);
    const results = try rt.run(program);
    defer std.testing.allocator.free(results);
    try std.testing.expectEqual(@as(usize, 0), results.len);
    try std.testing.expectEqual(@as(usize, 0), exec.spawned);
}

test "M4.1 forEachPar: spawn-decline fallback runs every body inline (drain-then-inline)" {
    var env = try fx.TestEnv.init(std.testing.allocator);
    defer env.deinit();
    var exec = DecliningExec{};
    var rt = runtimeWith(&env, exec.executor());

    const items = [_]u32{ 1, 2, 3 };
    const program = fx.forEachPar(u32, u32, fixtures.TestError, fx.TestServices, &items, DoubleBody.run);
    const results = try rt.run(program);
    defer std.testing.allocator.free(results);
    // The primitive must still produce correct results when every spawn declines.
    try std.testing.expectEqualSlices(u32, &.{ 2, 4, 6 }, results);
    // Spawn was attempted at least once (decline drains then runs inline).
    try std.testing.expect(exec.spawn_attempts >= 1);
}

test "M4.1 forEachPar with executor: failure returns the first error; no leak" {
    var env = try fx.TestEnv.init(std.testing.allocator);
    defer env.deinit();
    var exec = ProbeExec{};
    var rt = runtimeWith(&env, exec.executor());

    const items = [_]u32{ 1, 2, 3 };
    const program = fx.forEachPar(u32, u32, fixtures.TestError, fx.TestServices, &items, DoubleBody.failsOnTwo);
    const result = rt.run(program);
    try std.testing.expectError(error.Boom, result);
    // All fibers were spawned (no early interrupt yet — that's M7.8).
    try std.testing.expectEqual(@as(usize, 3), exec.spawned);
}

test "M4.2 zipPar: no executor falls back to sequential zip" {
    var env = try fx.TestEnv.init(std.testing.allocator);
    defer env.deinit();
    var rt = runtimeWith(&env, null);

    const program = E.succeed(7).zipPar(E.succeed(11));
    const pair = try rt.run(program);
    try std.testing.expectEqual(@as(u32, 7), pair.left);
    try std.testing.expectEqual(@as(u32, 11), pair.right);
}

test "M4.2 zipPar with executor: both effects spawned, pair returned" {
    var env = try fx.TestEnv.init(std.testing.allocator);
    defer env.deinit();
    var exec = ProbeExec{};
    var rt = runtimeWith(&env, exec.executor());

    const program = E.succeed(7).zipPar(E.succeed(11));
    const pair = try rt.run(program);
    try std.testing.expectEqual(@as(u32, 7), pair.left);
    try std.testing.expectEqual(@as(u32, 11), pair.right);
    try std.testing.expectEqual(@as(usize, 2), exec.spawned);
}

test "M4.2 zipPar with executor: left failure short-circuits with that error" {
    var env = try fx.TestEnv.init(std.testing.allocator);
    defer env.deinit();
    var exec = ProbeExec{};
    var rt = runtimeWith(&env, exec.executor());

    const program = E.fail(error.Boom).zipPar(E.succeed(11));
    const result = rt.run(program);
    try std.testing.expectError(error.Boom, result);
    try std.testing.expectEqual(@as(usize, 2), exec.spawned);
}

/// Causal-recording body — proves the structural-equivalence test is not
/// vacuous. The body records a `metric_recorded` event (a non-lifecycle kind)
/// so the snapshot is more than just the `run_started`/`exit_recorded`/
/// `run_completed` envelope `Runtime.run` injects.
const RecordingBody = struct {
    fn run(ctx: *fx.Context(fx.TestServices)) fixtures.TestError!u32 {
        _ = ctx.recordCausal(.{
            .kind = .metric_recorded,
            .label = "recording body ran",
            .status = "ready",
        });
        return 7;
    }
};

test "structural equivalence: zipPar with executor vs zip without (causal-recording body, non-vacuous)" {
    var env_a = try fx.TestEnv.init(std.testing.allocator);
    defer env_a.deinit();
    var store_a = fx.CausalStore.init(std.testing.allocator);
    defer store_a.deinit();
    var rt_a = fx.Runtime(fx.TestServices)
        .init(std.testing.allocator, &env_a.services)
        .withClock(&env_a.services.clock)
        .withCausalStore(&store_a)
        .provides(.{ fx.Logger, fx.Config, fx.Metrics, fx.Tracing, fx.MemoryFileSystem, fx.Clock });
    const seq = E.fromFn(RecordingBody.run).zip(E.fromFn(RecordingBody.run));
    _ = try rt_a.run(seq);

    var env_b = try fx.TestEnv.init(std.testing.allocator);
    defer env_b.deinit();
    var exec = ProbeExec{};
    var store_b = fx.CausalStore.init(std.testing.allocator);
    defer store_b.deinit();
    var rt_b = fx.Runtime(fx.TestServices)
        .init(std.testing.allocator, &env_b.services)
        .withClock(&env_b.services.clock)
        .withCausalStore(&store_b)
        .withExecutor(exec.executor())
        .provides(.{ fx.Logger, fx.Config, fx.Metrics, fx.Tracing, fx.MemoryFileSystem, fx.Clock });
    const par = E.fromFn(RecordingBody.run).zipPar(E.fromFn(RecordingBody.run));
    _ = try rt_b.run(par);

    var snap_a = try store_a.snapshot(std.testing.allocator);
    defer snap_a.deinit();
    var snap_b = try store_b.snapshot(std.testing.allocator);
    defer snap_b.deinit();

    // Non-vacuity: the body recorded events, so snapshots are richer than the
    // 3-event runtime envelope (`run_started`, `exit_recorded`, `run_completed`).
    try std.testing.expect(snap_a.events.len > 3);
    try std.testing.expect(snap_b.events.len > 3);
    // Each side recorded exactly two `metric_recorded` events (one per body).
    var metrics_a: usize = 0;
    var metrics_b: usize = 0;
    for (snap_a.events) |e| if (e.kind == .metric_recorded) {
        metrics_a += 1;
    };
    for (snap_b.events) |e| if (e.kind == .metric_recorded) {
        metrics_b += 1;
    };
    try std.testing.expectEqual(@as(usize, 2), metrics_a);
    try std.testing.expectEqual(@as(usize, 2), metrics_b);

    // Load-bearing assertion: sequential `zip` and parallel `zipPar` produce
    // structurally equivalent causal traces (same event kinds + cause-edge
    // pairs + fiber-net states), independent of execution order.
    try std.testing.expect(try fx.causalStructurallyEquivalent(std.testing.allocator, snap_a.events, snap_b.events));
}
