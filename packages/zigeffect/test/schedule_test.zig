const std = @import("std");
const fx = @import("zigeffect");
const fixtures = @import("support/fixtures.zig");

fn expectScheduleDecision(
    snapshot: fx.CausalSnapshot,
    label: []const u8,
    expected_detail: []const u8,
) !void {
    for (snapshot.events) |event| {
        if (event.kind != .schedule_decision) continue;
        if (!std.mem.eql(u8, event.label, label)) continue;
        if (std.mem.indexOf(u8, event.redacted_detail, expected_detail) == null) continue;
        return;
    }
    return error.ExpectedScheduleDecisionMissing;
}

test "schedules produce fixed and exponential retry decisions" {
    var fixed = fx.Schedule.fixed(.{ .max_retries = 2, .delay_ms = 10 });
    try std.testing.expectEqual(@as(?u64, 10), fixed.nextDelay(0));
    try std.testing.expectEqual(@as(?u64, 10), fixed.nextDelay(1));
    try std.testing.expectEqual(@as(?u64, null), fixed.nextDelay(2));

    var exponential = fx.Schedule.exponential(.{
        .max_retries = 3,
        .base_delay_ms = 5,
        .max_delay_ms = 12,
    });
    try std.testing.expectEqual(@as(?u64, 5), exponential.nextDelay(0));
    try std.testing.expectEqual(@as(?u64, 10), exponential.nextDelay(1));
    try std.testing.expectEqual(@as(?u64, 12), exponential.nextDelay(2));
    try std.testing.expectEqual(@as(?u64, null), exponential.nextDelay(3));

    var linear = fx.Schedule.linear(.{
        .max_retries = 3,
        .base_delay_ms = 4,
        .step_delay_ms = 6,
        .max_delay_ms = 20,
    });
    try std.testing.expectEqual(@as(?u64, 4), linear.nextDelay(0));
    try std.testing.expectEqual(@as(?u64, 10), linear.nextDelay(1));
    try std.testing.expectEqual(@as(?u64, 16), linear.nextDelay(2));
    try std.testing.expectEqual(@as(?u64, null), linear.nextDelay(3));

    var capped = fx.Schedule.exponential(.{
        .max_retries = 4,
        .base_delay_ms = 10,
        .max_delay_ms = 25,
    });
    try std.testing.expectEqual(@as(?u64, 25), capped.nextDelay(3));
}
test "schedules produce repeat backoff and jitter decisions" {
    var repeat = fx.Schedule.repeat(.{ .max_repeats = 2, .delay_ms = 7 });
    try std.testing.expectEqual(@as(?u64, 7), repeat.nextDelay(0));
    try std.testing.expectEqual(@as(?u64, 7), repeat.nextDelay(1));
    try std.testing.expectEqual(@as(?u64, null), repeat.nextDelay(2));

    var backoff = fx.Schedule.backoff(.{
        .max_retries = 3,
        .base_delay_ms = 3,
        .factor = 3,
        .max_delay_ms = 40,
    });
    try std.testing.expectEqual(@as(?u64, 3), backoff.nextDelay(0));
    try std.testing.expectEqual(@as(?u64, 9), backoff.nextDelay(1));
    try std.testing.expectEqual(@as(?u64, 27), backoff.nextDelay(2));
    try std.testing.expectEqual(@as(?u64, null), backoff.nextDelay(3));

    var jitter = fx.Schedule.jitteredBackoff(.{
        .max_retries = 3,
        .base_delay_ms = 10,
        .factor = 2,
        .max_delay_ms = 100,
        .jitter_ms = 3,
        .seed = 1,
    });
    try std.testing.expectEqual(@as(?u64, 12), jitter.nextDelay(0));
    try std.testing.expectEqual(@as(?u64, 23), jitter.nextDelay(1));
    try std.testing.expectEqual(@as(?u64, 40), jitter.nextDelay(2));
    try std.testing.expectEqual(@as(?u64, null), jitter.nextDelay(3));
}
test "schedule constructors mirror effect vocabulary" {
    var once = fx.Schedule.once();
    try std.testing.expectEqual(@as(?u64, 0), once.nextDelay(0));
    try std.testing.expectEqual(@as(?u64, null), once.nextDelay(1));

    var recurs = fx.Schedule.recurs(2);
    try std.testing.expectEqual(@as(?u64, 0), recurs.nextDelay(0));
    try std.testing.expectEqual(@as(?u64, 0), recurs.nextDelay(1));
    try std.testing.expectEqual(@as(?u64, null), recurs.nextDelay(2));

    var spaced = fx.Schedule.spaced(.{ .max_retries = 2, .delay_ms = 11 });
    try std.testing.expectEqual(@as(?u64, 11), spaced.nextDelay(0));
    try std.testing.expectEqual(@as(?u64, 11), spaced.nextDelay(1));
    try std.testing.expectEqual(@as(?u64, null), spaced.nextDelay(2));

    var duration = fx.Schedule.duration(.{ .max_retries = 2, .duration_ms = 9 });
    try std.testing.expectEqual(@as(?u64, 9), duration.nextDelay(0));
    try std.testing.expectEqual(@as(?u64, 9), duration.nextDelay(1));
    try std.testing.expectEqual(@as(?u64, null), duration.nextDelay(2));

    var fibonacci = fx.Schedule.fibonacci(.{
        .max_retries = 5,
        .base_delay_ms = 3,
        .max_delay_ms = 20,
    });
    try std.testing.expectEqual(@as(?u64, 3), fibonacci.nextDelay(0));
    try std.testing.expectEqual(@as(?u64, 3), fibonacci.nextDelay(1));
    try std.testing.expectEqual(@as(?u64, 6), fibonacci.nextDelay(2));
    try std.testing.expectEqual(@as(?u64, 9), fibonacci.nextDelay(3));
    try std.testing.expectEqual(@as(?u64, 15), fibonacci.nextDelay(4));
    try std.testing.expectEqual(@as(?u64, null), fibonacci.nextDelay(5));
}
test "schedule decisions expose state for tests" {
    var schedule = fx.Schedule.fixed(.{ .max_retries = 2, .delay_ms = 10 });

    const first = schedule.decision(0);
    try std.testing.expectEqual(@as(usize, 0), first.attempt);
    try std.testing.expectEqual(@as(?u64, 10), first.delay_ms);
    try std.testing.expect(first.continues);
    try std.testing.expect(!schedule.isExhausted(0));

    const exhausted = schedule.decision(2);
    try std.testing.expectEqual(@as(usize, 2), exhausted.attempt);
    try std.testing.expectEqual(@as(?u64, null), exhausted.delay_ms);
    try std.testing.expect(!exhausted.continues);
    try std.testing.expect(schedule.isExhausted(2));
}
test "schedule union and intersection compose delay decisions" {
    var short = fx.Schedule.fixed(.{ .max_retries = 3, .delay_ms = 10 });
    var long = fx.Schedule.fixed(.{ .max_retries = 2, .delay_ms = 25 });

    try std.testing.expectEqual(@as(?u64, 10), short.unionNextDelay(&long, 0));
    try std.testing.expectEqual(@as(?u64, 10), short.unionNextDelay(&long, 2));
    try std.testing.expectEqual(@as(?u64, null), short.unionNextDelay(&long, 3));

    try std.testing.expectEqual(@as(?u64, 25), short.intersectionNextDelay(&long, 0));
    try std.testing.expectEqual(@as(?u64, 25), short.intersectionNextDelay(&long, 1));
    try std.testing.expectEqual(@as(?u64, null), short.intersectionNextDelay(&long, 2));
}
test "schedule programs compose recursive union intersection and sequence decisions" {
    var program = fx.ScheduleProgram.init(std.testing.allocator);
    defer program.deinit();

    const short = try program.schedule(fx.Schedule.fixed(.{ .max_retries = 3, .delay_ms = 10 }));
    const long = try program.schedule(fx.Schedule.fixed(.{ .max_retries = 2, .delay_ms = 25 }));

    const union_node = try program.unionWith(short, long);
    try std.testing.expectEqual(@as(?u64, 10), program.nextDelayFor(union_node, 0));
    try std.testing.expectEqual(@as(?u64, 10), program.nextDelayFor(union_node, 2));
    try std.testing.expectEqual(@as(?u64, null), program.nextDelayFor(union_node, 3));

    const intersection_node = try program.intersectionWith(short, long);
    try std.testing.expectEqual(@as(?u64, 25), program.nextDelayFor(intersection_node, 0));
    try std.testing.expectEqual(@as(?u64, 25), program.nextDelayFor(intersection_node, 1));
    try std.testing.expectEqual(@as(?u64, null), program.nextDelayFor(intersection_node, 2));

    _ = try program.sequence(union_node, intersection_node);
    try std.testing.expectEqual(@as(?u64, 10), program.nextDelay(0));
    try std.testing.expectEqual(@as(?u64, 10), program.nextDelay(2));
    try std.testing.expectEqual(@as(?u64, 25), program.nextDelay(3));
    try std.testing.expectEqual(@as(?u64, 25), program.nextDelay(4));
    try std.testing.expectEqual(@as(?u64, null), program.nextDelay(5));

    const decision = program.decision(3);
    try std.testing.expectEqual(@as(usize, 3), decision.attempt);
    try std.testing.expectEqual(@as(?u64, 25), decision.delay_ms);
    try std.testing.expect(decision.continues);
}
test "schedule timeout and reset policies expose deterministic state" {
    var timeout = fx.Schedule.timeout(.{
        .max_retries = 5,
        .delay_ms = 10,
        .timeout_ms = 25,
    });
    try std.testing.expectEqual(@as(?u64, 10), timeout.nextDelay(0));
    try std.testing.expectEqual(@as(?u64, 10), timeout.nextDelay(1));
    try std.testing.expectEqual(@as(?u64, null), timeout.nextDelay(2));
    try std.testing.expect(timeout.isExhausted(2));

    var reset = fx.Schedule.reset(.{
        .max_retries = 3,
        .delay_ms = 5,
        .reset_after_ms = 100,
    });
    try std.testing.expectEqual(@as(?u64, 5), reset.nextDelay(2));
    try std.testing.expectEqual(@as(?u64, null), reset.nextDelay(3));
    try std.testing.expectEqual(@as(usize, 2), reset.resetAttempt(2, 99));
    try std.testing.expectEqual(@as(usize, 0), reset.resetAttempt(2, 100));

    var fixed = fx.Schedule.fixed(.{ .max_retries = 3, .delay_ms = 1 });
    try std.testing.expectEqual(@as(usize, 2), fixed.resetAttempt(2, 100));
}
test "retry records causal schedule decisions" {
    fixtures.retry_attempts = 0;

    var env = try fx.TestEnv.init(std.testing.allocator);
    defer env.deinit();

    var store = fx.CausalStore.init(std.testing.allocator);
    defer store.deinit();

    var ctx = env.context().withCausalStore(&store);
    var schedule = fx.Schedule.spaced(.{ .max_retries = 2, .delay_ms = 5 })
        .withLabel("retry-metrics");
    const program = fx.Effect(u32, fixtures.TestError, fx.TestServices)
        .fromFn(fixtures.succeedsAfterRetry)
        .requires(.{fx.Metrics});

    try std.testing.expectEqual(@as(u32, 7), try program.retry(&ctx, &schedule));

    var snapshot = try store.snapshot(std.testing.allocator);
    defer snapshot.deinit();

    try expectScheduleDecision(snapshot, "retry-metrics", "attempt=0 delay_ms=5 decision=retry");
    try expectScheduleDecision(snapshot, "retry-metrics", "attempt=1 delay_ms=5 decision=retry");
}
test "repeat records causal schedule decisions" {
    fixtures.repeat_runs = 0;

    var env = try fx.TestEnv.init(std.testing.allocator);
    defer env.deinit();

    var store = fx.CausalStore.init(std.testing.allocator);
    defer store.deinit();

    var ctx = env.context().withCausalStore(&store);
    var schedule = fx.Schedule.repeat(.{ .max_repeats = 2, .delay_ms = 7 })
        .withLabel("repeat-metrics");
    const program = fx.Effect(u8, fixtures.TestError, fx.TestServices)
        .fromFn(fixtures.countsRepeats)
        .requires(.{fx.Metrics});

    try std.testing.expectEqual(@as(u8, 3), try program.repeat(&ctx, &schedule));

    var snapshot = try store.snapshot(std.testing.allocator);
    defer snapshot.deinit();

    try expectScheduleDecision(snapshot, "repeat-metrics", "attempt=0 delay_ms=7 decision=repeat");
    try expectScheduleDecision(snapshot, "repeat-metrics", "attempt=1 delay_ms=7 decision=repeat");
}
