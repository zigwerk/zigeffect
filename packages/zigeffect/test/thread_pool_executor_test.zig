//! Track B — ThreadPoolExecutor: forEachPar/zipPar over REAL OS threads.

const std = @import("std");
const fx = @import("zigeffect");
const fixtures = @import("support/fixtures.zig");

const E = fx.Effect(u32, fixtures.TestError, fx.TestServices);

fn rt(env: *fx.TestEnv, exec: ?fx.FiberExecutor, store: ?*fx.CausalStore) fx.Runtime(fx.TestServices) {
    var runtime = fx.Runtime(fx.TestServices)
        .init(std.testing.allocator, &env.services)
        .withClock(&env.services.clock)
        .provides(.{ fx.Logger, fx.Config, fx.Metrics, fx.Tracing, fx.MemoryFileSystem, fx.Clock });
    if (store) |s| runtime = runtime.withCausalStore(s);
    if (exec) |e| runtime = runtime.withExecutor(e);
    return runtime;
}

// A body that records a causal event from whatever (possibly worker) thread it
// runs on — exercising the thread-safe CausalStore through the executor.
const RecordingBody = struct {
    fn run(item: u32, ctx: *fx.Context(fx.TestServices)) fixtures.TestError!u32 {
        _ = ctx.recordCausal(.{ .kind = .metric_recorded, .label = "tp body", .status = "ready" });
        // A little spin so the threads genuinely overlap.
        var sink: u64 = 0;
        var i: u32 = 0;
        while (i < 1000) : (i += 1) sink +%= i;
        std.mem.doNotOptimizeAway(sink);
        return item * 2;
    }
};

fn runForEachPar(allocator: std.mem.Allocator, exec: ?fx.FiberExecutor, store: *fx.CausalStore) ![]u32 {
    var env = try fx.TestEnv.init(allocator);
    defer env.deinit();
    var runtime = rt(&env, exec, store);
    const items = [_]u32{ 1, 2, 3, 4, 5, 6 };
    const program = fx.forEachPar(u32, u32, fixtures.TestError, fx.TestServices, &items, RecordingBody.run);
    return runtime.run(program);
}

test "ThreadPoolExecutor: forEachPar runs bodies on real OS threads with correct results" {
    const allocator = std.testing.allocator;
    var pool = fx.ThreadPoolExecutor{ .allocator = allocator };
    var store = fx.CausalStore.init(allocator);
    defer store.deinit();

    const results = try runForEachPar(allocator, pool.executor(), &store);
    defer allocator.free(results);

    try std.testing.expectEqualSlices(u32, &.{ 2, 4, 6, 8, 10, 12 }, results);
    // Every body recorded its event into the shared (thread-safe) store.
    var snap = try store.snapshot(allocator);
    defer snap.deinit();
    var metrics: usize = 0;
    for (snap.events) |e| if (e.kind == .metric_recorded) {
        metrics += 1;
    };
    try std.testing.expectEqual(@as(usize, 6), metrics);
}

test "ThreadPoolExecutor: forEachPar trace is structurally equivalent to the deterministic run" {
    const allocator = std.testing.allocator;

    // Deterministic (no executor): bodies run sequentially inline.
    var det_store = fx.CausalStore.init(allocator);
    defer det_store.deinit();
    const det = try runForEachPar(allocator, null, &det_store);
    defer allocator.free(det);

    // Real OS-thread pool.
    var pool = fx.ThreadPoolExecutor{ .allocator = allocator };
    var tp_store = fx.CausalStore.init(allocator);
    defer tp_store.deinit();
    const tp = try runForEachPar(allocator, pool.executor(), &tp_store);
    defer allocator.free(tp);

    try std.testing.expectEqualSlices(u32, det, tp);

    var det_snap = try det_store.snapshot(allocator);
    defer det_snap.deinit();
    var tp_snap = try tp_store.snapshot(allocator);
    defer tp_snap.deinit();

    // The D2 invariant, now over REAL OS-thread parallelism: same causal
    // structure as the deterministic run despite the threads reordering events.
    try std.testing.expect(try fx.causalStructurallyEquivalent(allocator, det_snap.events, tp_snap.events));
}

test "ThreadPoolExecutor: zipPar over OS threads returns the pair" {
    const allocator = std.testing.allocator;
    var env = try fx.TestEnv.init(allocator);
    defer env.deinit();
    var pool = fx.ThreadPoolExecutor{ .allocator = allocator };
    var runtime = rt(&env, pool.executor(), null);

    const pair = try runtime.run(E.succeed(7).zipPar(E.succeed(11)));
    try std.testing.expectEqual(@as(u32, 7), pair.left);
    try std.testing.expectEqual(@as(u32, 11), pair.right);
}
