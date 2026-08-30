const std = @import("std");
const fx = @import("zigeffect");
const fixtures = @import("support/fixtures.zig");

test "scope runs finalizers in reverse order" {
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

    try std.testing.expectEqualStrings("ba", state.order.items);
}
test "context registers typed finalizers through the active scope" {
    var env = try fx.TestEnv.init(std.testing.allocator);
    defer env.deinit();

    var state = fixtures.FinalizerState{
        .allocator = std.testing.allocator,
        .order = .empty,
    };
    defer state.order.deinit(std.testing.allocator);

    var ctx = env.context();
    try ctx.addFinalizerFor(fixtures.FinalizerState, &state, fixtures.releaseTyped);
    env.scope.close();

    try std.testing.expectEqualStrings("t", state.order.items);
}
test "scope records fallible finalizer failures" {
    var scope = fx.Scope.init(std.testing.allocator);
    defer scope.deinit();

    var finalizer_ran = false;
    try scope.addFinalizerFallible(&finalizer_ran, fixtures.failingRawFinalizer);
    scope.close();

    try std.testing.expect(finalizer_ran);
    try std.testing.expectEqual(@as(usize, 1), scope.finalizerFailureCount());
    try std.testing.expect(scope.hasFinalizerFailure("CloseFailed"));
}
test "scope exit finalizers observe close outcome" {
    var scope = fx.Scope.init(std.testing.allocator);
    defer scope.deinit();

    var probe = fixtures.ExitFinalizerProbe{};
    try scope.addFinalizerExit(&probe, fixtures.observeFinalizerExit);
    scope.closeWithExit(.{ .failure = "Boom" });

    try std.testing.expectEqualStrings("Boom", probe.status);
}
test "context reports missing scope when finalizers cannot be registered" {
    var env = try fx.TestEnv.init(std.testing.allocator);
    defer env.deinit();

    var state = fixtures.FinalizerState{
        .allocator = std.testing.allocator,
        .order = .empty,
    };
    defer state.order.deinit(std.testing.allocator);

    var ctx = fx.Context(fx.TestServices).init(std.testing.allocator, &env.services, null);

    try std.testing.expectError(
        error.MissingScope,
        ctx.addFinalizerFor(fixtures.FinalizerState, &state, fixtures.releaseTyped),
    );
}
test "acquireRelease registers typed resources for automatic scope cleanup" {
    var env = try fx.TestEnv.init(std.testing.allocator);
    defer env.deinit();

    var ctx = env.context();
    const program = fx.acquireRelease(
        fixtures.TrackedResource,
        fixtures.TestError,
        fx.TestServices,
        fixtures.acquireTracked,
        fixtures.releaseTracked,
    );

    const resource = try program.run(&ctx);
    try std.testing.expectEqual(@as(u32, 9), resource.id);
    try std.testing.expect(!fixtures.tracked_resource_released);

    env.scope.close();

    try std.testing.expect(fixtures.tracked_resource_released);
}
test "acquireRelease releases immediately when no scope is available" {
    var env = try fx.TestEnv.init(std.testing.allocator);
    defer env.deinit();

    var ctx = fx.Context(fx.TestServices).init(std.testing.allocator, &env.services, null);
    const program = fx.acquireRelease(
        fixtures.TrackedResource,
        fixtures.TestError,
        fx.TestServices,
        fixtures.acquireTracked,
        fixtures.releaseTracked,
    );

    try std.testing.expectError(error.MissingScope, program.run(&ctx));
    try std.testing.expect(fixtures.tracked_resource_released);
}
test "acquireReleaseValue releases immediately when no scope is available" {
    var env = try fx.TestEnv.init(std.testing.allocator);
    defer env.deinit();

    var state = fixtures.FinalizerState{
        .allocator = std.testing.allocator,
        .order = .empty,
    };
    defer state.order.deinit(std.testing.allocator);
    fixtures.value_resource_state = &state;
    defer fixtures.value_resource_state = null;

    var ctx = fx.Context(fx.TestServices).init(std.testing.allocator, &env.services, null);
    const program = fx.acquireReleaseValue(
        fixtures.ValueResource,
        fixtures.TestError,
        fx.TestServices,
        fixtures.acquireValueResourceA,
        fixtures.releaseValueResourceA,
    );

    try std.testing.expectError(error.MissingScope, program.run(&ctx));
    try std.testing.expect(fixtures.value_resource_released);
    try std.testing.expectEqualStrings("a", state.order.items);
}
