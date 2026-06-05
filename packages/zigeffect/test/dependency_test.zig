const std = @import("std");
const fx = @import("zigeffect");
const fixtures = @import("support/fixtures.zig");

test "requirements helpers compare declared requirements against providers" {
    var env = try fx.TestEnv.init(std.testing.allocator);
    defer env.deinit();

    const program = fx.Effect(u32, fixtures.TestError, fx.TestServices)
        .fromFn(fixtures.succeeds)
        .requires(.{ fx.Logger, fx.Config });

    const logger_only = env.layer().provides(.{fx.Logger});
    var missing = try fx.validateRequirements(std.testing.allocator, logger_only, program);
    defer missing.deinit();
    try std.testing.expect(!missing.isValid());
    try std.testing.expect(missing.hasMissing(@typeName(fx.Config)));
    try std.testing.expect(!try fx.requirementsSatisfiedBy(std.testing.allocator, logger_only, program));

    const full = env.layer().provides(.{ fx.Logger, fx.Config });
    var satisfied = try fx.validateRequirements(std.testing.allocator, full, program);
    defer satisfied.deinit();
    try std.testing.expect(satisfied.isValid());
    try std.testing.expect(try fx.requirementsSatisfiedBy(std.testing.allocator, full, program));

    try std.testing.expect(fx.staticRequirementsSatisfied(@TypeOf(full), @TypeOf(program)));
    try std.testing.expect(!fx.staticRequirementsSatisfied(@TypeOf(logger_only), @TypeOf(program)));
}
test "test env service layer helpers declare fake service providers" {
    var env = try fx.TestEnv.init(std.testing.allocator);
    defer env.deinit();

    const program = fx.Effect(u32, fixtures.TestError, fx.TestServices)
        .fromFn(fixtures.succeeds)
        .requires(.{ fx.Logger, fx.Config });

    var logger_missing = try fx.validateRequirements(std.testing.allocator, env.loggerLayer(), program);
    defer logger_missing.deinit();
    try std.testing.expect(logger_missing.hasMissing(@typeName(fx.Config)));

    var full = try fx.validateRequirements(std.testing.allocator, env.serviceLayer(.{ fx.Logger, fx.Config }), program);
    defer full.deinit();
    try std.testing.expect(full.isValid());
}
test "test env named service layers compose in layer graphs" {
    var env = try fx.TestEnv.init(std.testing.allocator);
    defer env.deinit();
    try env.services.config.set("app.name", "test-layer");

    var graph = fx.layerGraph(std.testing.allocator, .{
        env.loggerLayer(),
        env.configLayer(),
    });
    defer graph.deinit();

    const GraphEnv = @TypeOf(graph).EnvType;
    const Program = fx.Effect([]const u8, fixtures.TestError, GraphEnv)
        .fromFn(struct {
            fn run(ctx: *fx.Context(GraphEnv)) fixtures.TestError![]const u8 {
                const logger = ctx.service(fx.Logger);
                const config = ctx.service(fx.Config);
                try logger.info("named test layers ran");
                return config.require("app.name") catch error.Empty;
            }
        }.run)
        .requires(.{ fx.Logger, fx.Config });

    try std.testing.expectEqualStrings("test-layer", try graph.run(Program));
    try env.expectLog("named test layers ran");
}
test "testing helpers assert reports causes and schedules" {
    var env = try fx.TestEnv.init(std.testing.allocator);
    defer env.deinit();

    const program = fx.Effect(u32, fixtures.TestError, fx.TestServices)
        .fromFn(fixtures.succeeds)
        .requires(.{ fx.Logger, fx.Config });

    const logger_only = env.layer().provides(.{fx.Logger});
    var missing = try fx.validateRequirements(std.testing.allocator, logger_only, program);
    defer missing.deinit();
    try fx.testing.expectDependencyReportMissing(&missing, @typeName(fx.Config));

    const cleanup = fx.Cause(fixtures.TestError){ .finalizer_failure = "CloseFailed" };
    const defect = fx.Cause(fixtures.TestError){ .defect = "bad invariant" };
    const interrupted = fx.Cause(fixtures.TestError){ .interrupted = 99 };
    try fx.testing.expectCauseFinalizerFailure(cleanup, "CloseFailed");
    try fx.testing.expectCauseDefect(defect, "bad invariant");
    try fx.testing.expectCauseInterruption(interrupted, 99);

    var schedule = fx.Schedule.fixed(.{ .max_retries = 1, .delay_ms = 25 });
    try fx.testing.expectScheduleDelay(&schedule, 0, 25);
    try fx.testing.expectScheduleDelay(&schedule, 1, null);
}
test "testing helpers format assertion reports with expected actual and context" {
    var env = try fx.TestEnv.init(std.testing.allocator);
    defer env.deinit();
    try env.services.logger.info("first log");

    const log_report = try env.formatLogAssertionReport("missing log");
    defer std.testing.allocator.free(log_report);
    try std.testing.expect(std.mem.indexOf(u8, log_report, "zigeffect test assertion failed") != null);
    try std.testing.expect(std.mem.indexOf(u8, log_report, "assertion: log contains") != null);
    try std.testing.expect(std.mem.indexOf(u8, log_report, "expected: missing log") != null);
    try std.testing.expect(std.mem.indexOf(u8, log_report, "actual logs: 1") != null);
    try std.testing.expect(std.mem.indexOf(u8, log_report, "first log") != null);

    const schedule_report = try fx.testing.formatScheduleDelayAssertionReport(
        std.testing.allocator,
        2,
        25,
        null,
    );
    defer std.testing.allocator.free(schedule_report);
    try std.testing.expect(std.mem.indexOf(u8, schedule_report, "assertion: schedule delay") != null);
    try std.testing.expect(std.mem.indexOf(u8, schedule_report, "attempt: 2") != null);
    try std.testing.expect(std.mem.indexOf(u8, schedule_report, "expected: 25") != null);
    try std.testing.expect(std.mem.indexOf(u8, schedule_report, "actual: null") != null);

    const fiber_report = try fx.testing.formatFiberStatusAssertionReport(
        std.testing.allocator,
        .done,
        .pending,
    );
    defer std.testing.allocator.free(fiber_report);
    try std.testing.expect(std.mem.indexOf(u8, fiber_report, "assertion: fiber status") != null);
    try std.testing.expect(std.mem.indexOf(u8, fiber_report, "expected: done") != null);
    try std.testing.expect(std.mem.indexOf(u8, fiber_report, "actual: pending") != null);

    const queue_report = try fx.testing.formatQueueStateAssertionReport(
        std.testing.allocator,
        0,
        2,
        true,
        false,
    );
    defer std.testing.allocator.free(queue_report);
    try std.testing.expect(std.mem.indexOf(u8, queue_report, "assertion: queue state") != null);
    try std.testing.expect(std.mem.indexOf(u8, queue_report, "expected len: 0") != null);
    try std.testing.expect(std.mem.indexOf(u8, queue_report, "actual shutdown: false") != null);
}
