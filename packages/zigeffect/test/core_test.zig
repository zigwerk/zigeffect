const std = @import("std");
const fx = @import("zigeffect");

const TestError = error{ Boom, Empty, MissingScope, OutOfMemory };
const MappedError = error{Mapped};

fn succeeds(ctx: *fx.Context(fx.TestServices)) TestError!u32 {
    const logger = ctx.service(fx.Logger);
    try logger.info("effect ran");
    return 42;
}

fn fails(ctx: *fx.Context(fx.TestServices)) TestError!u32 {
    _ = ctx;
    return error.Boom;
}

fn double(value: u32) u64 {
    return @as(u64, value) * 2;
}

fn recordMapped(value: u64, ctx: *fx.Context(fx.TestServices)) TestError![]const u8 {
    const metrics = ctx.service(fx.Metrics);
    try metrics.increment("mapped.value", @intCast(value));
    return "mapped";
}

fn logTap(value: []const u8, ctx: *fx.Context(fx.TestServices)) TestError!void {
    _ = value;
    const logger = ctx.service(fx.Logger);
    try logger.info("tap observed");
}

fn syncNumber() u32 {
    return 64;
}

fn mapBoomToMapped(err: TestError) MappedError {
    return switch (err) {
        else => error.Mapped,
    };
}

fn recoverFromBoom(err: TestError, ctx: *fx.Context(fx.TestServices)) TestError!u32 {
    if (err != error.Boom) return error.Empty;
    const logger = ctx.service(fx.Logger);
    try logger.info("recovered");
    return 99;
}

fn logFailure(err: TestError, ctx: *fx.Context(fx.TestServices)) TestError!void {
    if (err != error.Boom) return error.Empty;
    const logger = ctx.service(fx.Logger);
    try logger.info("failure observed");
}

fn recordU32Exit(exit: fx.Exit(u32, TestError), ctx: *fx.Context(fx.TestServices)) TestError!void {
    const logger = ctx.service(fx.Logger);
    switch (exit) {
        .success => try logger.info("exit success"),
        .failure => |err| {
            if (err != error.Boom) return error.Empty;
            try logger.info("exit failure");
        },
        else => try logger.info("exit other"),
    }
}

fn ensureFinalizer(ctx: *fx.Context(fx.TestServices)) TestError!void {
    const logger = ctx.service(fx.Logger);
    try logger.info("ensured");
}

var fiber_success_finalizer_probe = ExitFinalizerProbe{};
var fiber_failure_finalizer_probe = ExitFinalizerProbe{};
var fiber_scoped_finalizer_probe = ExitFinalizerProbe{};

fn observeTypedFinalizerExit(probe: *ExitFinalizerProbe, exit: fx.FinalizerExit) void {
    probe.status = switch (exit) {
        .success => "success",
        .failure => |name| name,
        .defect => |message| message,
        .interrupted => "interrupted",
        .cause => |name| name,
    };
}

fn succeedsWithFiberFinalizer(ctx: *fx.Context(fx.TestServices)) TestError!u32 {
    fiber_success_finalizer_probe = .{};
    try ctx.addFinalizerExitFor(ExitFinalizerProbe, &fiber_success_finalizer_probe, observeTypedFinalizerExit);
    return 42;
}

fn failsWithFiberFinalizer(ctx: *fx.Context(fx.TestServices)) TestError!u32 {
    fiber_failure_finalizer_probe = .{};
    try ctx.addFinalizerExitFor(ExitFinalizerProbe, &fiber_failure_finalizer_probe, observeTypedFinalizerExit);
    return error.Boom;
}

fn pendingScopedFiber(ctx: *fx.Context(fx.TestServices)) TestError!u32 {
    fiber_scoped_finalizer_probe = .{};
    try ctx.addFinalizerExitFor(ExitFinalizerProbe, &fiber_scoped_finalizer_probe, observeTypedFinalizerExit);
    return 7;
}

test "effect runs direct style functions against a service context" {
    var env = try fx.TestEnv.init(std.testing.allocator);
    defer env.deinit();

    var ctx = env.context();
    const program = fx.Effect(u32, TestError, fx.TestServices).fromFn(succeeds);

    try std.testing.expectEqual(@as(u32, 42), try program.run(&ctx));
    try std.testing.expectEqual(@as(usize, 1), env.services.logger.entries.items.len);
    try std.testing.expectEqualStrings("effect ran", env.services.logger.entries.items[0]);
}

test "effect exit preserves failure causes" {
    var env = try fx.TestEnv.init(std.testing.allocator);
    defer env.deinit();

    var ctx = env.context();
    const program = fx.Effect(u32, TestError, fx.TestServices).fromFn(fails);

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
    const success = fx.Effect(u32, TestError, fx.TestServices).succeed(12);
    const failed = fx.Effect(u32, TestError, fx.TestServices).fail(error.Boom);
    const synced = fx.Effect(u32, TestError, fx.TestServices).sync(syncNumber);

    try std.testing.expectEqual(@as(u32, 12), try success.run(&ctx));
    try std.testing.expectError(error.Boom, failed.run(&ctx));
    try std.testing.expectEqual(@as(u32, 64), try synced.run(&ctx));
}

test "effect recovery combinators map catch fallback and observe failures" {
    var env = try fx.TestEnv.init(std.testing.allocator);
    defer env.deinit();

    var ctx = env.context();
    const failed = fx.Effect(u32, TestError, fx.TestServices).fromFn(fails);

    try std.testing.expectError(error.Mapped, failed.mapError(MappedError, mapBoomToMapped).run(&ctx));
    try std.testing.expectEqual(@as(u32, 99), try failed.catchAll(TestError, recoverFromBoom).run(&ctx));
    try env.expectLog("recovered");

    const fallback = fx.Effect(u32, TestError, fx.TestServices).succeed(7);
    try std.testing.expectEqual(@as(u32, 7), try failed.orElse(fallback).run(&ctx));

    try std.testing.expectError(error.Boom, failed.tapError(logFailure).run(&ctx));
    try env.expectLog("failure observed");
}

test "effect onExit observes exits and ensuring runs finalizers" {
    var env = try fx.TestEnv.init(std.testing.allocator);
    defer env.deinit();

    var ctx = env.context();
    const successful = fx.Effect(u32, TestError, fx.TestServices)
        .fromFn(succeeds)
        .onExit(recordU32Exit);
    try std.testing.expectEqual(@as(u32, 42), try successful.run(&ctx));
    try env.expectLog("exit success");

    const failed = fx.Effect(u32, TestError, fx.TestServices)
        .fromFn(fails)
        .onExit(recordU32Exit);
    try std.testing.expectError(error.Boom, failed.run(&ctx));
    try env.expectLog("exit failure");

    const ensured = fx.Effect(u32, TestError, fx.TestServices)
        .fromFn(fails)
        .ensuring(ensureFinalizer);
    try std.testing.expectError(error.Boom, ensured.run(&ctx));
    try env.expectLog("ensured");
}

test "exit and cause formatting explain runtime failures" {
    var env = try fx.TestEnv.init(std.testing.allocator);
    defer env.deinit();

    const exit = env.exit(fx.Effect(u32, TestError, fx.TestServices).fromFn(fails));
    const report = try fx.formatExit(std.testing.allocator, "load user profile", exit);
    defer std.testing.allocator.free(report);

    try std.testing.expect(std.mem.indexOf(u8, report, "zigeffect failure report") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "program: load user profile") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "error: Boom") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "hint: Handle this error in the caller") != null);

    const cause_report = try fx.formatCause(
        std.testing.allocator,
        "compile schema",
        fx.Cause(TestError){ .interrupted = 17 },
    );
    defer std.testing.allocator.free(cause_report);

    try std.testing.expect(std.mem.indexOf(u8, cause_report, "cause: interrupted") != null);
    try std.testing.expect(std.mem.indexOf(u8, cause_report, "fiber: 17") != null);

    const failure_cause = fx.Cause(TestError){ .failure = error.Boom };
    const cleanup_cause = fx.Cause(TestError){ .finalizer_failure = "CloseFailed" };
    const sequential_report = try fx.formatCause(
        std.testing.allocator,
        "shutdown",
        fx.Cause(TestError){ .sequential = .{ .left = &failure_cause, .right = &cleanup_cause } },
    );
    defer std.testing.allocator.free(sequential_report);

    try std.testing.expect(std.mem.indexOf(u8, sequential_report, "cause: sequential") != null);
    try std.testing.expect(std.mem.indexOf(u8, sequential_report, "CloseFailed") != null);
}

test "fiber runtime forks and joins successful effects" {
    var env = try fx.TestEnv.init(std.testing.allocator);
    defer env.deinit();

    var runtime = fx.FiberRuntime(fx.TestServices)
        .init(std.testing.allocator, &env.services)
        .withClock(&env.services.clock)
        .provides(.{ fx.Logger, fx.Config, fx.Metrics, fx.Tracing, fx.MemoryFileSystem, fx.Clock });
    defer runtime.deinit();

    const program = fx.Effect(u32, TestError, fx.TestServices).fromFn(succeedsWithFiberFinalizer);
    const fiber = try runtime.fork(program);

    try std.testing.expectEqual(@as(fx.FiberId, 1), fiber.id);
    try std.testing.expectEqual(fx.FiberStatus.pending, fiber.status());

    const exit = runtime.join(fiber);
    switch (exit) {
        .success => |value| try std.testing.expectEqual(@as(u32, 42), value),
        else => return error.Empty,
    }
    try std.testing.expectEqual(fx.FiberStatus.done, fiber.status());
    try std.testing.expectEqualStrings("success", fiber_success_finalizer_probe.status);
}

test "fiber runtime preserves typed failure exits" {
    var env = try fx.TestEnv.init(std.testing.allocator);
    defer env.deinit();

    var runtime = fx.FiberRuntime(fx.TestServices)
        .init(std.testing.allocator, &env.services)
        .withClock(&env.services.clock)
        .provides(.{ fx.Logger, fx.Config, fx.Metrics, fx.Tracing, fx.MemoryFileSystem, fx.Clock });
    defer runtime.deinit();

    const program = fx.Effect(u32, TestError, fx.TestServices).fromFn(failsWithFiberFinalizer);
    const fiber = try runtime.fork(program);
    const exit = runtime.join(fiber);

    switch (exit) {
        .failure => |err| try std.testing.expectEqual(error.Boom, err),
        else => return error.Empty,
    }
    try std.testing.expectEqual(fx.FiberStatus.failed, fiber.status());
    try std.testing.expectEqualStrings("Boom", fiber_failure_finalizer_probe.status);
}

test "fiber runtime interrupts pending fibers" {
    var env = try fx.TestEnv.init(std.testing.allocator);
    defer env.deinit();

    var runtime = fx.FiberRuntime(fx.TestServices)
        .init(std.testing.allocator, &env.services)
        .withClock(&env.services.clock)
        .provides(.{ fx.Logger, fx.Config, fx.Metrics, fx.Tracing, fx.MemoryFileSystem, fx.Clock });
    defer runtime.deinit();

    const program = fx.Effect(u32, TestError, fx.TestServices).fromFn(succeedsWithFiberFinalizer);
    const fiber = try runtime.fork(program);

    runtime.interrupt(fiber);

    const exit = runtime.join(fiber);
    switch (exit) {
        .interrupted => |id| try std.testing.expectEqual(fiber.id, id),
        else => return error.Empty,
    }
    try std.testing.expectEqual(fx.FiberStatus.interrupted, fiber.status());
}

test "forkScoped leases children to the parent scope" {
    var env = try fx.TestEnv.init(std.testing.allocator);
    defer env.deinit();

    var runtime = fx.FiberRuntime(fx.TestServices)
        .init(std.testing.allocator, &env.services)
        .withClock(&env.services.clock)
        .provides(.{ fx.Logger, fx.Config, fx.Metrics, fx.Tracing, fx.MemoryFileSystem, fx.Clock });
    defer runtime.deinit();

    var ctx = env.context();
    const program = fx.Effect(u32, TestError, fx.TestServices).fromFn(pendingScopedFiber);
    const fiber = try runtime.forkScoped(&ctx, program);

    env.scope.closeWithExit(.success);

    const exit = runtime.join(fiber);
    switch (exit) {
        .interrupted => |id| try std.testing.expectEqual(fiber.id, id),
        else => return error.Empty,
    }
    try std.testing.expectEqual(fx.FiberStatus.interrupted, fiber.status());
}

test "fiber runtime validates dependency requirements before forking" {
    var env = try fx.TestEnv.init(std.testing.allocator);
    defer env.deinit();

    var runtime = fx.FiberRuntime(fx.TestServices)
        .init(std.testing.allocator, &env.services)
        .withClock(&env.services.clock)
        .provides(.{fx.Logger});
    defer runtime.deinit();

    const program = fx.Effect(u32, TestError, fx.TestServices)
        .fromFn(succeeds)
        .requires(.{ fx.Logger, fx.Config });

    try std.testing.expectError(error.MissingServiceRequirement, runtime.fork(program));
}

test "interrupted fiber exits format with fiber id" {
    const report = try fx.formatExit(
        std.testing.allocator,
        "load profile fiber",
        fx.Exit(u32, TestError){ .interrupted = 22 },
    );
    defer std.testing.allocator.free(report);

    try std.testing.expect(std.mem.indexOf(u8, report, "status: interrupted") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "fiber: 22") != null);
}

test "deferred completes once with structured exits" {
    var deferred = fx.Deferred(u32, TestError).init();

    try std.testing.expectError(error.DeferredNotCompleted, deferred.awaitExit());
    try deferred.completeSuccess(55);
    try std.testing.expectError(error.DeferredAlreadyCompleted, deferred.completeFailure(error.Boom));

    const exit = try deferred.awaitExit();
    switch (exit) {
        .success => |value| try std.testing.expectEqual(@as(u32, 55), value),
        else => return error.Empty,
    }
}

test "queue preserves fifo order and reports empty or full" {
    var queue = fx.Queue(u32).bounded(std.testing.allocator, 2);
    defer queue.deinit();

    try std.testing.expectError(error.QueueEmpty, queue.take());
    try queue.offer(1);
    try queue.offer(2);
    try std.testing.expectError(error.QueueFull, queue.offer(3));

    try std.testing.expectEqual(@as(u32, 1), try queue.take());
    try std.testing.expectEqual(@as(u32, 2), try queue.take());
    try std.testing.expectError(error.QueueEmpty, queue.take());
}

test "semaphore acquires and releases bounded permits" {
    var semaphore = fx.Semaphore.init(2);

    try std.testing.expectEqual(@as(usize, 2), semaphore.available());
    try semaphore.acquire(2);
    try std.testing.expectEqual(@as(usize, 0), semaphore.available());
    try std.testing.expectError(error.SemaphoreUnavailable, semaphore.acquire(1));
    try semaphore.release(1);
    try std.testing.expectEqual(@as(usize, 1), semaphore.available());
    try std.testing.expectError(error.SemaphoreOverRelease, semaphore.release(2));
}

test "effect composes with map flatMap and tap while staying direct style" {
    var env = try fx.TestEnv.init(std.testing.allocator);
    defer env.deinit();

    var ctx = env.context();
    const program = fx.Effect(u32, TestError, fx.TestServices)
        .fromFn(succeeds)
        .map(u64, double)
        .flatMap([]const u8, recordMapped)
        .tap(logTap);

    try std.testing.expectEqualStrings("mapped", try program.run(&ctx));
    try env.expectLog("effect ran");
    try env.expectLog("tap observed");
    try env.expectMetric("mapped.value", 84);
}

const FinalizerState = struct {
    allocator: std.mem.Allocator,
    order: std.ArrayList(u8),
};

fn appendA(raw: ?*anyopaque) void {
    const state: *FinalizerState = @ptrCast(@alignCast(raw.?));
    state.order.append(state.allocator, 'a') catch unreachable;
}

fn appendB(raw: ?*anyopaque) void {
    const state: *FinalizerState = @ptrCast(@alignCast(raw.?));
    state.order.append(state.allocator, 'b') catch unreachable;
}

fn releaseTyped(state: *FinalizerState) void {
    state.order.append(state.allocator, 't') catch unreachable;
}

const TrackedResource = struct {
    allocator: std.mem.Allocator,
    id: u32,
};

var tracked_resource_released = false;

fn acquireTracked(ctx: *fx.Context(fx.TestServices)) TestError!*TrackedResource {
    tracked_resource_released = false;
    const resource = try ctx.allocator.create(TrackedResource);
    resource.* = .{
        .allocator = ctx.allocator,
        .id = 9,
    };
    return resource;
}

fn releaseTracked(resource: *TrackedResource) void {
    tracked_resource_released = true;
    resource.allocator.destroy(resource);
}

fn releaseTrackedFailing(resource: *TrackedResource) anyerror!void {
    tracked_resource_released = true;
    resource.allocator.destroy(resource);
    return error.CloseFailed;
}

fn trackedId(resource: *TrackedResource) u32 {
    return resource.id;
}

fn failAfterTracked(resource: *TrackedResource, ctx: *fx.Context(fx.TestServices)) TestError!u32 {
    _ = resource;
    const logger = ctx.service(fx.Logger);
    try logger.info("failing after acquire");
    return error.Boom;
}

fn acquireTrackedWithFailingCleanup(ctx: *fx.Context(fx.TestServices)) TestError!*TrackedResource {
    tracked_resource_released = false;
    const resource = try ctx.allocator.create(TrackedResource);
    resource.* = .{
        .allocator = ctx.allocator,
        .id = 10,
    };
    try ctx.addFinalizerFallibleFor(TrackedResource, resource, releaseTrackedFailing);
    return resource;
}

fn failingRawFinalizer(raw: ?*anyopaque) anyerror!void {
    const ran: *bool = @ptrCast(@alignCast(raw.?));
    ran.* = true;
    return error.CloseFailed;
}

const ExitFinalizerProbe = struct {
    status: []const u8 = "none",
};

fn observeFinalizerExit(raw: ?*anyopaque, exit: fx.FinalizerExit) void {
    const probe: *ExitFinalizerProbe = @ptrCast(@alignCast(raw.?));
    probe.status = switch (exit) {
        .success => "success",
        .failure => |name| name,
        .defect => |message| message,
        .interrupted => "interrupted",
        .cause => |name| name,
    };
}

const BuiltLayerEnv = struct {
    logger: fx.Logger,
    released: *bool,

    pub fn service(self: *BuiltLayerEnv, comptime Service: type) *Service {
        if (Service == fx.Logger) return &self.logger;
        return fx.serviceNotFound(BuiltLayerEnv, Service);
    }
};

var layer_env_released = false;

fn releaseBuiltLayerEnv(env: *BuiltLayerEnv) void {
    const allocator = env.logger.allocator;
    env.logger.deinit();
    env.released.* = true;
    allocator.destroy(env);
}

fn buildBuiltLayerEnv(allocator: std.mem.Allocator, scope: *fx.Scope) std.mem.Allocator.Error!*BuiltLayerEnv {
    layer_env_released = false;
    const env = try allocator.create(BuiltLayerEnv);
    env.* = .{
        .logger = fx.Logger.init(allocator),
        .released = &layer_env_released,
    };
    scope.addFinalizerFor(BuiltLayerEnv, env, releaseBuiltLayerEnv) catch |err| {
        releaseBuiltLayerEnv(env);
        return err;
    };
    return env;
}

const ConfigLayerEnv = struct {
    config: fx.Config,

    pub fn service(self: *ConfigLayerEnv, comptime Service: type) *Service {
        if (Service == fx.Config) return &self.config;
        return fx.serviceNotFound(ConfigLayerEnv, Service);
    }
};

const MergedLayerEnv = struct {
    logger_env: *BuiltLayerEnv,
    config_env: *ConfigLayerEnv,
    released: *bool,

    pub fn service(self: *MergedLayerEnv, comptime Service: type) *Service {
        if (Service == fx.Logger) return self.logger_env.service(Service);
        if (Service == fx.Config) return self.config_env.service(Service);
        return fx.serviceNotFound(MergedLayerEnv, Service);
    }
};

var merged_layer_released = false;

fn releaseMergedLayerEnv(env: *MergedLayerEnv) void {
    const allocator = env.logger_env.logger.allocator;
    env.released.* = true;
    allocator.destroy(env);
}

fn combineLayerEnvs(
    allocator: std.mem.Allocator,
    scope: *fx.Scope,
    logger_env: *BuiltLayerEnv,
    config_env: *ConfigLayerEnv,
) std.mem.Allocator.Error!*MergedLayerEnv {
    merged_layer_released = false;
    const env = try allocator.create(MergedLayerEnv);
    env.* = .{
        .logger_env = logger_env,
        .config_env = config_env,
        .released = &merged_layer_released,
    };
    scope.addFinalizerFor(MergedLayerEnv, env, releaseMergedLayerEnv) catch |err| {
        releaseMergedLayerEnv(env);
        return err;
    };
    return env;
}

fn runMergedLayerProgram(ctx: *fx.Context(MergedLayerEnv)) TestError![]const u8 {
    const logger = ctx.service(fx.Logger);
    const config = ctx.service(fx.Config);
    const value = config.require("app.name") catch return error.Empty;
    try logger.info("merged layer ran");
    return value;
}

const GraphLoggerEnv = struct {
    logger: fx.Logger,

    pub fn service(self: *GraphLoggerEnv, comptime Service: type) *Service {
        if (Service == fx.Logger) return &self.logger;
        return fx.serviceNotFound(GraphLoggerEnv, Service);
    }
};

const GraphConfigEnv = struct {
    config: fx.Config,

    pub fn service(self: *GraphConfigEnv, comptime Service: type) *Service {
        if (Service == fx.Config) return &self.config;
        return fx.serviceNotFound(GraphConfigEnv, Service);
    }
};

var graph_logger_builds: usize = 0;
var graph_config_builds: usize = 0;
var graph_logger_released = false;
var graph_config_released = false;

fn releaseGraphLoggerEnv(env: *GraphLoggerEnv) void {
    const allocator = env.logger.allocator;
    env.logger.deinit();
    graph_logger_released = true;
    allocator.destroy(env);
}

fn releaseGraphConfigEnv(env: *GraphConfigEnv) void {
    const allocator = env.config.allocator;
    env.config.deinit();
    graph_config_released = true;
    allocator.destroy(env);
}

fn buildGraphLoggerEnv(allocator: std.mem.Allocator, scope: *fx.Scope) std.mem.Allocator.Error!*GraphLoggerEnv {
    graph_logger_builds += 1;
    graph_logger_released = false;
    const env = try allocator.create(GraphLoggerEnv);
    env.* = .{ .logger = fx.Logger.init(allocator) };
    scope.addFinalizerFor(GraphLoggerEnv, env, releaseGraphLoggerEnv) catch |err| {
        releaseGraphLoggerEnv(env);
        return err;
    };
    return env;
}

fn buildGraphConfigEnv(allocator: std.mem.Allocator, scope: *fx.Scope) std.mem.Allocator.Error!*GraphConfigEnv {
    graph_config_builds += 1;
    graph_config_released = false;
    const env = try allocator.create(GraphConfigEnv);
    env.* = .{ .config = fx.Config.init(allocator) };
    scope.addFinalizerFor(GraphConfigEnv, env, releaseGraphConfigEnv) catch |err| {
        releaseGraphConfigEnv(env);
        return err;
    };
    try env.config.set("app.name", "graph");
    return env;
}

test "scope runs finalizers in reverse order" {
    var scope = fx.Scope.init(std.testing.allocator);
    defer scope.deinit();

    var state = FinalizerState{
        .allocator = std.testing.allocator,
        .order = .empty,
    };
    defer state.order.deinit(std.testing.allocator);

    try scope.addFinalizer(&state, appendA);
    try scope.addFinalizer(&state, appendB);
    scope.close();

    try std.testing.expectEqualStrings("ba", state.order.items);
}

test "context registers typed finalizers through the active scope" {
    var env = try fx.TestEnv.init(std.testing.allocator);
    defer env.deinit();

    var state = FinalizerState{
        .allocator = std.testing.allocator,
        .order = .empty,
    };
    defer state.order.deinit(std.testing.allocator);

    var ctx = env.context();
    try ctx.addFinalizerFor(FinalizerState, &state, releaseTyped);
    env.scope.close();

    try std.testing.expectEqualStrings("t", state.order.items);
}

test "scope records fallible finalizer failures" {
    var scope = fx.Scope.init(std.testing.allocator);
    defer scope.deinit();

    var finalizer_ran = false;
    try scope.addFinalizerFallible(&finalizer_ran, failingRawFinalizer);
    scope.close();

    try std.testing.expect(finalizer_ran);
    try std.testing.expectEqual(@as(usize, 1), scope.finalizerFailureCount());
    try std.testing.expect(scope.hasFinalizerFailure("CloseFailed"));
}

test "scope exit finalizers observe close outcome" {
    var scope = fx.Scope.init(std.testing.allocator);
    defer scope.deinit();

    var probe = ExitFinalizerProbe{};
    try scope.addFinalizerExit(&probe, observeFinalizerExit);
    scope.closeWithExit(.{ .failure = "Boom" });

    try std.testing.expectEqualStrings("Boom", probe.status);
}

test "context reports missing scope when finalizers cannot be registered" {
    var env = try fx.TestEnv.init(std.testing.allocator);
    defer env.deinit();

    var state = FinalizerState{
        .allocator = std.testing.allocator,
        .order = .empty,
    };
    defer state.order.deinit(std.testing.allocator);

    var ctx = fx.Context(fx.TestServices).init(std.testing.allocator, &env.services, null);

    try std.testing.expectError(
        error.MissingScope,
        ctx.addFinalizerFor(FinalizerState, &state, releaseTyped),
    );
}

test "acquireRelease registers typed resources for automatic scope cleanup" {
    var env = try fx.TestEnv.init(std.testing.allocator);
    defer env.deinit();

    var ctx = env.context();
    const program = fx.acquireRelease(
        TrackedResource,
        TestError,
        fx.TestServices,
        acquireTracked,
        releaseTracked,
    );

    const resource = try program.run(&ctx);
    try std.testing.expectEqual(@as(u32, 9), resource.id);
    try std.testing.expect(!tracked_resource_released);

    env.scope.close();

    try std.testing.expect(tracked_resource_released);
}

test "acquireRelease releases immediately when no scope is available" {
    var env = try fx.TestEnv.init(std.testing.allocator);
    defer env.deinit();

    var ctx = fx.Context(fx.TestServices).init(std.testing.allocator, &env.services, null);
    const program = fx.acquireRelease(
        TrackedResource,
        TestError,
        fx.TestServices,
        acquireTracked,
        releaseTracked,
    );

    try std.testing.expectError(error.MissingScope, program.run(&ctx));
    try std.testing.expect(tracked_resource_released);
}

test "runtime automatically closes scoped resources after success" {
    var env = try fx.TestEnv.init(std.testing.allocator);
    defer env.deinit();

    const program = fx.acquireRelease(
        TrackedResource,
        TestError,
        fx.TestServices,
        acquireTracked,
        releaseTracked,
    ).map(u32, trackedId);

    try std.testing.expectEqual(@as(u32, 9), try env.run(program));
    try std.testing.expect(tracked_resource_released);
}

test "runtime automatically closes scoped resources after failure" {
    var env = try fx.TestEnv.init(std.testing.allocator);
    defer env.deinit();

    const program = fx.acquireRelease(
        TrackedResource,
        TestError,
        fx.TestServices,
        acquireTracked,
        releaseTracked,
    ).flatMap(u32, failAfterTracked);

    try std.testing.expectError(error.Boom, env.run(program));
    try std.testing.expect(tracked_resource_released);
    try env.expectLog("failing after acquire");
}

test "runtime exit reports finalizer failures as causes" {
    var env = try fx.TestEnv.init(std.testing.allocator);
    defer env.deinit();

    const program = fx.Effect(*TrackedResource, TestError, fx.TestServices)
        .fromFn(acquireTrackedWithFailingCleanup)
        .map(u32, trackedId);

    const exit = env.exit(program);
    switch (exit) {
        .cause => |cause| switch (cause) {
            .finalizer_failure => |name| try std.testing.expectEqualStrings("CloseFailed", name),
            else => return error.Empty,
        },
        else => return error.Empty,
    }

    try std.testing.expect(tracked_resource_released);
}

test "layer builder constructs dependencies and scope releases them" {
    var scope = fx.Scope.init(std.testing.allocator);
    defer scope.deinit();

    const layer = fx.Layer(BuiltLayerEnv).fromBuilder(buildBuiltLayerEnv);
    var ctx = try layer.buildContext(std.testing.allocator, &scope);

    const logger = ctx.service(fx.Logger);
    try logger.info("layer ready");
    try std.testing.expectEqualStrings("layer ready", logger.entries.items[0]);
    try std.testing.expect(!layer_env_released);

    scope.close();

    try std.testing.expect(layer_env_released);
}

test "layer merge composes dependencies and provide runs effects" {
    var logger_env = BuiltLayerEnv{
        .logger = fx.Logger.init(std.testing.allocator),
        .released = &layer_env_released,
    };
    defer logger_env.logger.deinit();

    var config_env = ConfigLayerEnv{ .config = fx.Config.init(std.testing.allocator) };
    defer config_env.config.deinit();
    try config_env.config.set("app.name", "zigeffect");

    const logger_layer = fx.Layer(BuiltLayerEnv).fromEnv(&logger_env);
    const config_layer = fx.Layer(ConfigLayerEnv).fromEnv(&config_env);
    const merged = logger_layer.merge(ConfigLayerEnv, MergedLayerEnv, config_layer, combineLayerEnvs);
    const program = fx.Effect([]const u8, TestError, MergedLayerEnv).fromFn(runMergedLayerProgram);

    try std.testing.expectEqualStrings("zigeffect", try merged.provide(std.testing.allocator, program));
    try std.testing.expectEqualStrings("merged layer ran", logger_env.logger.entries.items[0]);
    try std.testing.expect(merged_layer_released);
}

test "effect requirements are validated by layers and runtimes" {
    var env = try fx.TestEnv.init(std.testing.allocator);
    defer env.deinit();

    const program = fx.Effect(u32, TestError, fx.TestServices)
        .fromFn(succeeds)
        .requires(.{ fx.Logger, fx.Config });

    const logger_only = env.layer().provides(.{fx.Logger});
    var report = try fx.validateLayerRequirements(std.testing.allocator, logger_only, program);
    defer report.deinit();

    try std.testing.expectEqual(@as(usize, 1), report.issueCount());
    try std.testing.expect(report.hasMissing(@typeName(fx.Config)));

    const formatted = try fx.formatDependencyReport(std.testing.allocator, "test program", report);
    defer std.testing.allocator.free(formatted);
    try std.testing.expect(std.mem.indexOf(u8, formatted, "missing service requirement") != null);
    try std.testing.expect(std.mem.indexOf(u8, formatted, @typeName(fx.Config)) != null);

    try std.testing.expectError(error.MissingServiceRequirement, logger_only.provide(std.testing.allocator, program));

    const full_layer = env.layer().provides(.{ fx.Logger, fx.Config });
    try std.testing.expectEqual(@as(u32, 42), try full_layer.provide(std.testing.allocator, program));

    var missing_runtime = env.runtime().provides(.{fx.Logger});
    try std.testing.expectError(error.MissingServiceRequirement, missing_runtime.run(program));

    var full_runtime = env.runtime().provides(.{ fx.Logger, fx.Config });
    try std.testing.expectEqual(@as(u32, 42), try full_runtime.run(program));
}

test "layer graph reports missing requirements and duplicate providers" {
    var env = try fx.TestEnv.init(std.testing.allocator);
    defer env.deinit();

    var graph = fx.LayerGraph.init(std.testing.allocator);
    defer graph.deinit();

    try graph.addLayer("logger-a", env.layer().provides(.{fx.Logger}));
    try graph.addLayer("logger-b", env.layer().provides(.{fx.Logger}));
    try graph.addLayer("worker", env.layer().requires(.{fx.Config}).provides(.{fx.Metrics}));

    var report = try graph.validate(std.testing.allocator);
    defer report.deinit();

    try std.testing.expectEqual(@as(usize, 2), report.issueCount());
    try std.testing.expect(report.hasMissing(@typeName(fx.Config)));
    try std.testing.expect(report.hasDuplicate(@typeName(fx.Logger)));

    const formatted = try fx.formatDependencyReport(std.testing.allocator, "app graph", report);
    defer std.testing.allocator.free(formatted);
    try std.testing.expect(std.mem.indexOf(u8, formatted, "program: app graph") != null);
    try std.testing.expect(std.mem.indexOf(u8, formatted, "duplicate service provider") != null);
    try std.testing.expect(std.mem.indexOf(u8, formatted, "missing service requirement") != null);
}

test "layer graph automatically composes heterogeneous declared layers" {
    var logger_env = GraphLoggerEnv{ .logger = fx.Logger.init(std.testing.allocator) };
    defer logger_env.logger.deinit();

    var config_env = GraphConfigEnv{ .config = fx.Config.init(std.testing.allocator) };
    defer config_env.config.deinit();
    try config_env.config.set("app.name", "zigeffect");

    const logger_layer = fx.Layer(GraphLoggerEnv)
        .fromEnv(&logger_env)
        .provides(.{fx.Logger});
    const config_layer = fx.Layer(GraphConfigEnv)
        .fromEnv(&config_env)
        .requires(.{fx.Logger})
        .provides(.{fx.Config});

    var graph = fx.layerGraph(std.testing.allocator, .{ config_layer, logger_layer });
    defer graph.deinit();

    const GraphEnv = @TypeOf(graph).EnvType;
    const Program = fx.Effect([]const u8, TestError, GraphEnv)
        .fromFn(struct {
            fn run(ctx: *fx.Context(GraphEnv)) TestError![]const u8 {
                const logger = ctx.service(fx.Logger);
                const config = ctx.service(fx.Config);
                try logger.info("graph ran");
                return config.require("app.name") catch error.Empty;
            }
        }.run)
        .requires(.{ fx.Logger, fx.Config });

    try std.testing.expectEqualStrings("zigeffect", try graph.run(Program));
    try std.testing.expectEqualStrings("graph ran", logger_env.logger.entries.items[0]);
}

test "layer graph memoizes started layers across runs" {
    graph_logger_builds = 0;
    graph_config_builds = 0;
    graph_logger_released = false;
    graph_config_released = false;

    const logger_layer = fx.Layer(GraphLoggerEnv)
        .fromBuilder(buildGraphLoggerEnv)
        .provides(.{fx.Logger});
    const config_layer = fx.Layer(GraphConfigEnv)
        .fromBuilder(buildGraphConfigEnv)
        .requires(.{fx.Logger})
        .provides(.{fx.Config});

    var graph = fx.layerGraph(std.testing.allocator, .{ config_layer, logger_layer });

    const GraphEnv = @TypeOf(graph).EnvType;
    const Program = fx.Effect([]const u8, TestError, GraphEnv)
        .fromFn(struct {
            fn run(ctx: *fx.Context(GraphEnv)) TestError![]const u8 {
                const logger = ctx.service(fx.Logger);
                const config = ctx.service(fx.Config);
                try logger.info("memoized run");
                return config.require("app.name") catch error.Empty;
            }
        }.run)
        .requires(.{ fx.Logger, fx.Config });

    try std.testing.expectEqualStrings("graph", try graph.run(Program));
    try std.testing.expectEqualStrings("graph", try graph.run(Program));
    try std.testing.expectEqual(@as(usize, 1), graph_logger_builds);
    try std.testing.expectEqual(@as(usize, 1), graph_config_builds);
    try std.testing.expect(!graph_logger_released);
    try std.testing.expect(!graph_config_released);

    graph.deinit();
    try std.testing.expect(graph_logger_released);
    try std.testing.expect(graph_config_released);
}

test "layer graph rejects invalid dependencies before startup" {
    graph_logger_builds = 0;
    graph_config_builds = 0;

    const logger_a = fx.Layer(GraphLoggerEnv)
        .fromBuilder(buildGraphLoggerEnv)
        .provides(.{fx.Logger});
    const logger_b = fx.Layer(GraphLoggerEnv)
        .fromBuilder(buildGraphLoggerEnv)
        .provides(.{fx.Logger});

    var duplicate_graph = fx.layerGraph(std.testing.allocator, .{ logger_a, logger_b });
    defer duplicate_graph.deinit();

    try std.testing.expectError(error.DuplicateServiceProvider, duplicate_graph.start());
    try std.testing.expectEqual(@as(usize, 0), graph_logger_builds);

    const needs_config = fx.Layer(GraphLoggerEnv)
        .fromBuilder(buildGraphLoggerEnv)
        .requires(.{fx.Config})
        .provides(.{fx.Logger});

    var missing_graph = fx.layerGraph(std.testing.allocator, .{needs_config});
    defer missing_graph.deinit();

    var report = try missing_graph.validate(std.testing.allocator);
    defer report.deinit();
    try std.testing.expect(report.hasMissing(@typeName(fx.Config)));

    try std.testing.expectError(error.MissingServiceRequirement, missing_graph.start());
    try std.testing.expectEqual(@as(usize, 0), graph_logger_builds);
}

const StartupError = error{ConnectionFailed};

const StartupLayerEnv = struct {
    logger: fx.Logger,

    pub fn service(self: *StartupLayerEnv, comptime Service: type) *Service {
        if (Service == fx.Logger) return &self.logger;
        return fx.serviceNotFound(StartupLayerEnv, Service);
    }
};

fn buildFailingStartupLayer(
    allocator: std.mem.Allocator,
    scope: *fx.Scope,
) (std.mem.Allocator.Error || StartupError)!*StartupLayerEnv {
    _ = allocator;
    _ = scope;
    return error.ConnectionFailed;
}

fn startupLayerProgram(ctx: *fx.Context(StartupLayerEnv)) TestError!u32 {
    _ = ctx;
    return 1;
}

test "typed layer startup errors are preserved through provide" {
    const layer = fx.LayerWithError(StartupLayerEnv, StartupError)
        .fromBuilder(buildFailingStartupLayer)
        .provides(.{fx.Logger});
    const program = fx.Effect(u32, TestError, StartupLayerEnv).fromFn(startupLayerProgram);

    try std.testing.expectError(error.ConnectionFailed, layer.provide(std.testing.allocator, program));
}

test "layer graph preserves typed startup errors" {
    const layer = fx.LayerWithError(StartupLayerEnv, StartupError)
        .fromBuilder(buildFailingStartupLayer)
        .provides(.{fx.Logger});

    var graph = fx.layerGraph(std.testing.allocator, .{layer});
    defer graph.deinit();

    try std.testing.expectError(error.ConnectionFailed, graph.start());
}

test "compile fail fixture captures missing service diagnostics" {
    var io_instance = std.Io.Threaded.init(std.testing.allocator, .{});
    defer io_instance.deinit();
    const io = io_instance.io();

    const output_path = ".zig-cache/missing_service_compile_fail.txt";
    std.Io.Dir.deleteFile(.cwd(), io, output_path) catch {};
    defer std.Io.Dir.deleteFile(.cwd(), io, output_path) catch {};

    const result = try std.process.run(std.testing.allocator, io, .{
        .argv = &.{
            "/bin/sh",
            "-c",
            "/opt/homebrew/bin/zig build-exe --dep zigeffect -Mroot=test/compile_fail/missing_service.zig -Mzigeffect=src/zigeffect.zig -fno-emit-bin --cache-dir .zig-cache/compile-fail-cache --global-cache-dir .zig-cache/compile-fail-global-cache > .zig-cache/missing_service_compile_fail.txt 2>&1",
        },
    });
    defer std.testing.allocator.free(result.stdout);
    defer std.testing.allocator.free(result.stderr);

    switch (result.term) {
        .exited => |code| try std.testing.expect(code != 0),
        else => return error.Empty,
    }

    const diagnostic = try std.Io.Dir.readFileAlloc(.cwd(), io, output_path, std.testing.allocator, .limited(64 * 1024));
    defer std.testing.allocator.free(diagnostic);
    try std.testing.expect(std.mem.indexOf(u8, diagnostic, "zigeffect service not found") != null);
    try std.testing.expect(std.mem.indexOf(u8, diagnostic, @typeName(fx.Config)) != null);
    try std.testing.expect(std.mem.indexOf(u8, diagnostic, "Add a branch to the environment service method") != null);
}

test "context resolves services and test environment captures state" {
    var env = try fx.TestEnv.init(std.testing.allocator);
    defer env.deinit();

    var ctx = env.context();
    const fs = ctx.service(fx.MemoryFileSystem);
    const config = ctx.service(fx.Config);
    const metrics = ctx.service(fx.Metrics);
    const tracing = ctx.service(fx.Tracing);
    const clock = ctx.service(fx.FakeClock);
    const clock_service = ctx.service(fx.Clock);

    try config.set("mode", "test");
    try fs.writeFile("schema.rg", "database yachdee {}");
    try metrics.increment("compile.count", 1);
    try tracing.event("compile.start");
    clock.sleep(25);
    clock_service.sleep(5);

    try std.testing.expectEqualStrings("test", config.get("mode").?);
    try std.testing.expectEqualStrings("database yachdee {}", fs.readFile("schema.rg").?);
    try std.testing.expectEqual(@as(i64, 1), metrics.get("compile.count"));
    try std.testing.expectEqualStrings("compile.start", env.services.tracing.events.items[0]);
    try std.testing.expectEqual(@as(u64, 30), clock.nowMs());
    try std.testing.expectEqual(@as(u64, 30), clock_service.nowMs());
    try env.expectFile("schema.rg", "database yachdee {}");
    try env.expectTrace("compile.start");
    try env.expectMetric("compile.count", 1);
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

var retry_attempts: u8 = 0;

fn succeedsAfterRetry(ctx: *fx.Context(fx.TestServices)) TestError!u32 {
    retry_attempts += 1;
    const metrics = ctx.service(fx.Metrics);
    try metrics.increment("attempts", 1);
    if (retry_attempts < 3) return error.Boom;
    return 7;
}

var repeat_runs: u8 = 0;

fn countsRepeats(ctx: *fx.Context(fx.TestServices)) TestError!u8 {
    repeat_runs += 1;
    const metrics = ctx.service(fx.Metrics);
    try metrics.increment("repeat.runs", 1);
    return repeat_runs;
}

test "effect retry repeats according to schedule" {
    retry_attempts = 0;
    var env = try fx.TestEnv.init(std.testing.allocator);
    defer env.deinit();

    var ctx = env.context();
    var schedule = fx.Schedule.fixed(.{ .max_retries = 3, .delay_ms = 1 });
    const program = fx.Effect(u32, TestError, fx.TestServices).fromFn(succeedsAfterRetry);

    try std.testing.expectEqual(@as(u32, 7), try program.retry(&ctx, &schedule));
    try std.testing.expectEqual(@as(i64, 3), env.services.metrics.get("attempts"));
    try std.testing.expectEqual(@as(u64, 2), env.services.clock.nowMs());
}

test "effect repeat reruns successful programs according to schedule" {
    repeat_runs = 0;
    var env = try fx.TestEnv.init(std.testing.allocator);
    defer env.deinit();

    var ctx = env.context();
    var schedule = fx.Schedule.repeat(.{ .max_repeats = 2, .delay_ms = 5 });
    const program = fx.Effect(u8, TestError, fx.TestServices).fromFn(countsRepeats);

    try std.testing.expectEqual(@as(u8, 3), try program.repeat(&ctx, &schedule));
    try std.testing.expectEqual(@as(i64, 3), env.services.metrics.get("repeat.runs"));
    try std.testing.expectEqual(@as(u64, 10), env.services.clock.nowMs());
}

test "logger config metrics tracing and memory fs support bootstrap helpers" {
    var env = try fx.TestEnv.init(std.testing.allocator);
    defer env.deinit();

    var ctx = env.context();
    const logger = ctx.service(fx.Logger);
    const config = ctx.service(fx.Config);
    const metrics = ctx.service(fx.Metrics);
    const tracing = ctx.service(fx.Tracing);
    const fs = ctx.service(fx.MemoryFileSystem);

    try logger.warn("warned");
    try logger.err("errored");
    try config.set("stage", "dev");
    try config.set("stage", "test");
    try metrics.gauge("queue.depth", 12);
    try tracing.spanStart("compile");
    try tracing.spanEnd("compile");
    try fs.writeFile("schema.rg", "old");
    try fs.writeFile("schema.rg", "new");

    try env.expectLog("warned");
    try env.expectLog("errored");
    try std.testing.expectEqualStrings("test", config.require("stage") catch unreachable);
    try env.expectMetric("queue.depth", 12);
    try env.expectTrace("span:start:compile");
    try env.expectTrace("span:end:compile");
    try env.expectFile("schema.rg", "new");
    try std.testing.expect(fs.exists("schema.rg"));
    fs.deleteFile("schema.rg");
    try std.testing.expect(!fs.exists("schema.rg"));
}
