const std = @import("std");
const fx = @import("zigeffect");
const fixtures = @import("support/fixtures.zig");

test "effect runs direct style functions against a service context" {
    var env = try fx.TestEnv.init(std.testing.allocator);
    defer env.deinit();

    var ctx = env.context();
    const program = fx.Effect(u32, fixtures.TestError, fx.TestServices).fromFn(fixtures.succeeds);

    try std.testing.expectEqual(@as(u32, 42), try program.run(&ctx));
    try std.testing.expectEqual(@as(usize, 1), env.services.logger.entries.items.len);
    try std.testing.expectEqualStrings("effect ran", env.services.logger.entries.items[0]);
}
test "effect exit preserves failure causes" {
    var env = try fx.TestEnv.init(std.testing.allocator);
    defer env.deinit();

    var ctx = env.context();
    const program = fx.Effect(u32, fixtures.TestError, fx.TestServices).fromFn(fixtures.fails);

    const exit = program.exit(&ctx);
    switch (exit) {
        .failure => |err| try std.testing.expectEqual(error.Boom, err),
        else => return error.Empty,
    }
}
test "effect constructors create success failure and sync programs" {
    var env = try fx.TestEnv.init(std.testing.allocator);
    defer env.deinit();

    var ctx = env.context();
    const success = fx.Effect(u32, fixtures.TestError, fx.TestServices).succeed(12);
    const failed = fx.Effect(u32, fixtures.TestError, fx.TestServices).fail(error.Boom);
    const synced = fx.Effect(u32, fixtures.TestError, fx.TestServices).sync(fixtures.syncNumber);

    try std.testing.expectEqual(@as(u32, 12), try success.run(&ctx));
    try std.testing.expectError(error.Boom, failed.run(&ctx));
    try std.testing.expectEqual(@as(u32, 64), try synced.run(&ctx));
}
test "effect recovery combinators map catch fallback and observe failures" {
    var env = try fx.TestEnv.init(std.testing.allocator);
    defer env.deinit();

    var ctx = env.context();
    const failed = fx.Effect(u32, fixtures.TestError, fx.TestServices).fromFn(fixtures.fails);

    try std.testing.expectError(error.Mapped, failed.mapError(fixtures.MappedError, fixtures.mapBoomToMapped).run(&ctx));
    try std.testing.expectEqual(@as(u32, 99), try failed.catchAll(fixtures.TestError, fixtures.recoverFromBoom).run(&ctx));
    try env.expectLog("recovered");

    const fallback = fx.Effect(u32, fixtures.TestError, fx.TestServices).succeed(7);
    try std.testing.expectEqual(@as(u32, 7), try failed.orElse(fallback).run(&ctx));

    try std.testing.expectError(error.Boom, failed.tapError(fixtures.logFailure).run(&ctx));
    try env.expectLog("failure observed");
}
test "effect onExit observes exits and ensuring runs finalizers" {
    var env = try fx.TestEnv.init(std.testing.allocator);
    defer env.deinit();

    var ctx = env.context();
    const successful = fx.Effect(u32, fixtures.TestError, fx.TestServices)
        .fromFn(fixtures.succeeds)
        .onExit(fixtures.recordU32Exit);
    try std.testing.expectEqual(@as(u32, 42), try successful.run(&ctx));
    try env.expectLog("exit success");

    const failed = fx.Effect(u32, fixtures.TestError, fx.TestServices)
        .fromFn(fixtures.fails)
        .onExit(fixtures.recordU32Exit);
    try std.testing.expectError(error.Boom, failed.run(&ctx));
    try env.expectLog("exit failure");

    const ensured = fx.Effect(u32, fixtures.TestError, fx.TestServices)
        .fromFn(fixtures.fails)
        .ensuring(fixtures.ensureFinalizer);
    try std.testing.expectError(error.Boom, ensured.run(&ctx));
    try env.expectLog("ensured");
}
test "exit and cause formatting explain runtime failures" {
    var env = try fx.TestEnv.init(std.testing.allocator);
    defer env.deinit();

    const exit = env.exit(fx.Effect(u32, fixtures.TestError, fx.TestServices).fromFn(fixtures.fails));
    const report = try fx.formatExit(std.testing.allocator, "load user profile", exit);
    defer std.testing.allocator.free(report);

    try std.testing.expect(std.mem.indexOf(u8, report, "zigeffect failure report") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "program: load user profile") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "error: Boom") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "hint: Handle this error in the caller") != null);

    const cause_report = try fx.formatCause(
        std.testing.allocator,
        "compile schema",
        fx.Cause(fixtures.TestError){ .interrupted = 17 },
    );
    defer std.testing.allocator.free(cause_report);

    try std.testing.expect(std.mem.indexOf(u8, cause_report, "cause: interrupted") != null);
    try std.testing.expect(std.mem.indexOf(u8, cause_report, "fiber: 17") != null);

    const failure_cause = fx.Cause(fixtures.TestError){ .failure = error.Boom };
    const cleanup_cause = fx.Cause(fixtures.TestError){ .finalizer_failure = "CloseFailed" };
    const sequential_report = try fx.formatCause(
        std.testing.allocator,
        "shutdown",
        fx.Cause(fixtures.TestError){ .sequential = .{ .left = &failure_cause, .right = &cleanup_cause } },
    );
    defer std.testing.allocator.free(sequential_report);

    try std.testing.expect(std.mem.indexOf(u8, sequential_report, "cause: sequential") != null);
    try std.testing.expect(std.mem.indexOf(u8, sequential_report, "CloseFailed") != null);
}
test "exit finalizer helper preserves defects and interruptions" {
    const defect_exit = fx.exitWithFinalizerFailure(
        u32,
        fixtures.TestError,
        fx.Exit(u32, fixtures.TestError){ .defect = "bad invariant" },
        "CloseFailed",
    );

    switch (defect_exit) {
        .cause => |cause| {
            try std.testing.expect(fx.causeHasDefect(cause, "bad invariant"));
            try std.testing.expect(fx.causeHasFinalizerFailure(cause, "CloseFailed"));
        },
        else => return error.Empty,
    }

    const interrupted_exit = fx.exitWithFinalizerFailure(
        u32,
        fixtures.TestError,
        fx.Exit(u32, fixtures.TestError){ .interrupted = 88 },
        "CloseFailed",
    );

    switch (interrupted_exit) {
        .cause => |cause| {
            try std.testing.expect(fx.causeHasInterruption(cause, 88));
            try std.testing.expect(fx.causeHasFinalizerFailure(cause, "CloseFailed"));
        },
        else => return error.Empty,
    }
}
test "cause helpers inspect nested cause reports" {
    const defect = fx.Cause(fixtures.TestError){ .defect = "bad invariant" };
    const cleanup = fx.Cause(fixtures.TestError){ .finalizer_failure = "CloseFailed" };
    const interrupted = fx.Cause(fixtures.TestError){ .interrupted = 44 };
    const nested = fx.Cause(fixtures.TestError){ .sequential = .{
        .left = &defect,
        .right = &cleanup,
    } };
    const annotated = fx.Cause(fixtures.TestError){ .annotated = .{
        .cause = &interrupted,
        .annotation = "test",
    } };

    try std.testing.expect(fx.causeHasDefect(nested, "bad invariant"));
    try std.testing.expect(fx.causeHasFinalizerFailure(nested, "CloseFailed"));
    try std.testing.expect(fx.causeHasInterruption(annotated, 44));
}
test "owned cause tree owns recursive cause reports" {
    var tree = fx.CauseTree(fixtures.TestError).init(std.testing.allocator);
    defer tree.deinit();

    const failure = try tree.failure(error.Boom);
    const cleanup = try tree.finalizerFailure("CloseFailed");
    _ = try tree.sequential(failure, cleanup);

    try std.testing.expect(tree.hasFinalizerFailure("CloseFailed"));
    try std.testing.expect(!tree.hasDefect("bad invariant"));

    const report = try tree.format("shutdown");
    defer std.testing.allocator.free(report);

    try std.testing.expect(std.mem.indexOf(u8, report, "cause: sequential") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "error: Boom") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "CloseFailed") != null);
}
test "owned cause tree copies pointer backed causes" {
    var tree = fx.CauseTree(fixtures.TestError).init(std.testing.allocator);
    defer tree.deinit();

    const defect = fx.Cause(fixtures.TestError){ .defect = "bad invariant" };
    const cleanup = fx.Cause(fixtures.TestError){ .finalizer_failure = "CloseFailed" };
    const source = fx.Cause(fixtures.TestError){ .sequential = .{
        .left = &defect,
        .right = &cleanup,
    } };

    _ = try tree.copyFromCause(source);

    try std.testing.expect(tree.hasDefect("bad invariant"));
    try std.testing.expect(tree.hasFinalizerFailure("CloseFailed"));
}
test "owned cause tree appends finalizer failure to existing causes" {
    const defect = fx.Cause(fixtures.TestError){ .defect = "bad invariant" };
    const interrupted = fx.Cause(fixtures.TestError){ .interrupted = 55 };
    const source = fx.Cause(fixtures.TestError){ .parallel = .{
        .left = &defect,
        .right = &interrupted,
    } };
    const exit = fx.Exit(u32, fixtures.TestError){ .cause = source };

    var tree = try fx.causeTreeWithFinalizerFailure(
        std.testing.allocator,
        u32,
        fixtures.TestError,
        exit,
        "CloseFailed",
    );
    defer tree.deinit();

    try std.testing.expect(tree.hasDefect("bad invariant"));
    try std.testing.expect(tree.hasInterruption(55));
    try std.testing.expect(tree.hasFinalizerFailure("CloseFailed"));
}
test "effect composes with map flatMap and tap while staying direct style" {
    var env = try fx.TestEnv.init(std.testing.allocator);
    defer env.deinit();

    var ctx = env.context();
    const program = fx.Effect(u32, fixtures.TestError, fx.TestServices)
        .fromFn(fixtures.succeeds)
        .map(u64, fixtures.double)
        .flatMap([]const u8, fixtures.recordMapped)
        .tap(fixtures.logTap);

    try std.testing.expectEqualStrings("mapped", try program.run(&ctx));
    try env.expectLog("effect ran");
    try env.expectLog("tap observed");
    try env.expectMetric("mapped.value", 84);
}
test "effect retry repeats according to schedule" {
    fixtures.retry_attempts = 0;
    var env = try fx.TestEnv.init(std.testing.allocator);
    defer env.deinit();

    var ctx = env.context();
    var schedule = fx.Schedule.fixed(.{ .max_retries = 3, .delay_ms = 1 });
    const program = fx.Effect(u32, fixtures.TestError, fx.TestServices).fromFn(fixtures.succeedsAfterRetry);

    try std.testing.expectEqual(@as(u32, 7), try program.retry(&ctx, &schedule));
    try std.testing.expectEqual(@as(i64, 3), env.services.metrics.get("attempts"));
    try std.testing.expectEqual(@as(u64, 2), env.services.clock.nowMs());
}
test "effect repeat reruns successful programs according to schedule" {
    fixtures.repeat_runs = 0;
    var env = try fx.TestEnv.init(std.testing.allocator);
    defer env.deinit();

    var ctx = env.context();
    var schedule = fx.Schedule.repeat(.{ .max_repeats = 2, .delay_ms = 5 });
    const program = fx.Effect(u8, fixtures.TestError, fx.TestServices).fromFn(fixtures.countsRepeats);

    try std.testing.expectEqual(@as(u8, 3), try program.repeat(&ctx, &schedule));
    try std.testing.expectEqual(@as(i64, 3), env.services.metrics.get("repeat.runs"));
    try std.testing.expectEqual(@as(u64, 10), env.services.clock.nowMs());
}
