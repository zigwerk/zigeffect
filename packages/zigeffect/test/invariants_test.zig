const std = @import("std");
const fx = @import("zigeffect");
const fixtures = @import("support/fixtures.zig");

var runtime_order_state: ?*fixtures.FinalizerState = null;

fn appendRuntimeA(state: *fixtures.FinalizerState) void {
    state.order.append(state.allocator, 'a') catch unreachable;
}

fn appendRuntimeB(state: *fixtures.FinalizerState) void {
    state.order.append(state.allocator, 'b') catch unreachable;
}

fn registerRuntimeFinalizers(ctx: *fx.Context(fx.TestServices)) fixtures.TestError!u32 {
    const state = runtime_order_state.?;
    try ctx.addFinalizerFor(fixtures.FinalizerState, state, appendRuntimeA);
    try ctx.addFinalizerFor(fixtures.FinalizerState, state, appendRuntimeB);
    return 1;
}

test "invariant scope close is idempotent and reverse ordered" {
    var scope = fx.Scope.init(std.testing.allocator);
    defer scope.deinit();

    var state = fixtures.FinalizerState{
        .allocator = std.testing.allocator,
        .order = .empty,
    };
    defer state.order.deinit(std.testing.allocator);

    try scope.addFinalizer(&state, fixtures.appendA);
    try scope.addFinalizer(&state, fixtures.appendB);

    scope.close();
    scope.close();

    try std.testing.expectEqualStrings("ba", state.order.items);
}

test "invariant graph validation runs before startup builders" {
    fixtures.graph_logger_builds = 0;

    const logger_a = fx.Layer(fixtures.GraphLoggerEnv)
        .fromBuilder(fixtures.buildGraphLoggerEnv)
        .provides(.{fx.Logger});
    const logger_b = fx.Layer(fixtures.GraphLoggerEnv)
        .fromBuilder(fixtures.buildGraphLoggerEnv)
        .provides(.{fx.Logger});

    var graph = fx.layerGraph(std.testing.allocator, .{ logger_a, logger_b });
    defer graph.deinit();

    try std.testing.expectError(error.DuplicateServiceProvider, graph.start());
    try std.testing.expectEqual(@as(usize, 0), fixtures.graph_logger_builds);
}

test "invariant scoped parent close interrupts pending child before acquisition" {
    var env = try fx.TestEnv.init(std.testing.allocator);
    defer env.deinit();

    var runtime = fx.FiberRuntime(fx.TestServices)
        .init(std.testing.allocator, &env.services)
        .withClock(&env.services.clock)
        .provides(.{ fx.Logger, fx.Config, fx.Metrics, fx.Tracing, fx.MemoryFileSystem, fx.Clock });
    defer runtime.deinit();

    var ctx = env.context();
    const program = fx.Effect(u32, fixtures.TestError, fx.TestServices).fromFn(fixtures.pendingScopedFiber);
    const fiber = try runtime.forkScoped(&ctx, program);

    fixtures.fiber_scoped_finalizer_probe = .{};

    env.scope.close();
    const exit = runtime.join(fiber);

    switch (exit) {
        .interrupted => |id| try std.testing.expectEqual(fiber.id, id),
        else => return error.Empty,
    }
    try std.testing.expectEqual(fx.FiberStatus.interrupted, fiber.status());
    try std.testing.expectEqualStrings("none", fixtures.fiber_scoped_finalizer_probe.status);
}

test "invariant runtime finalizers observe success in reverse order" {
    var env = try fx.TestEnv.init(std.testing.allocator);
    defer env.deinit();

    var state = fixtures.FinalizerState{
        .allocator = std.testing.allocator,
        .order = .empty,
    };
    defer state.order.deinit(std.testing.allocator);

    runtime_order_state = &state;
    defer runtime_order_state = null;

    const program = fx.Effect(u32, fixtures.TestError, fx.TestServices).fromFn(registerRuntimeFinalizers);
    try std.testing.expectEqual(@as(u32, 1), try env.run(program));
    try std.testing.expectEqualStrings("ba", state.order.items);
}
