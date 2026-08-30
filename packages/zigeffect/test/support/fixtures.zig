const std = @import("std");
const fx = @import("zigeffect");

pub const TestError = error{ Boom, Empty, MissingScope, OutOfMemory };
pub const MappedError = error{Mapped};

pub fn succeeds(ctx: *fx.Context(fx.TestServices)) TestError!u32 {
    const logger = ctx.service(fx.Logger);
    try logger.info("effect ran");
    return 42;
}

pub fn fails(ctx: *fx.Context(fx.TestServices)) TestError!u32 {
    _ = ctx;
    return error.Boom;
}

pub fn double(value: u32) u64 {
    return @as(u64, value) * 2;
}

pub fn recordMapped(value: u64, ctx: *fx.Context(fx.TestServices)) TestError![]const u8 {
    const metrics = ctx.service(fx.Metrics);
    try metrics.increment("mapped.value", @intCast(value));
    return "mapped";
}

pub fn logTap(value: []const u8, ctx: *fx.Context(fx.TestServices)) TestError!void {
    _ = value;
    const logger = ctx.service(fx.Logger);
    try logger.info("tap observed");
}

pub fn syncNumber() u32 {
    return 64;
}

pub fn mapBoomToMapped(err: TestError) MappedError {
    return switch (err) {
        else => error.Mapped,
    };
}

pub fn recoverFromBoom(err: TestError, ctx: *fx.Context(fx.TestServices)) TestError!u32 {
    if (err != error.Boom) return error.Empty;
    const logger = ctx.service(fx.Logger);
    try logger.info("recovered");
    return 99;
}

pub fn logFailure(err: TestError, ctx: *fx.Context(fx.TestServices)) TestError!void {
    if (err != error.Boom) return error.Empty;
    const logger = ctx.service(fx.Logger);
    try logger.info("failure observed");
}

pub fn logTraceContext(ctx: *fx.Context(fx.TestServices)) TestError!void {
    const logger = ctx.service(fx.Logger);
    try logger.logWithContext(.info, "trace context", &.{}, .{
        .trace_id = ctx.trace_id,
        .span_id = ctx.span_id,
    });
}

pub fn recordU32Exit(exit: fx.Exit(u32, TestError), ctx: *fx.Context(fx.TestServices)) TestError!void {
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

pub fn ensureFinalizer(ctx: *fx.Context(fx.TestServices)) TestError!void {
    const logger = ctx.service(fx.Logger);
    try logger.info("ensured");
}

pub var fiber_success_finalizer_probe = ExitFinalizerProbe{};
pub var fiber_failure_finalizer_probe = ExitFinalizerProbe{};
pub var fiber_scoped_finalizer_probe = ExitFinalizerProbe{};

pub fn observeTypedFinalizerExit(probe: *ExitFinalizerProbe, exit: fx.FinalizerExit) void {
    probe.status = switch (exit) {
        .success => "success",
        .failure => |name| name,
        .defect => |message| message,
        .interrupted => "interrupted",
        .cause => |name| name,
    };
}

pub fn succeedsWithFiberFinalizer(ctx: *fx.Context(fx.TestServices)) TestError!u32 {
    fiber_success_finalizer_probe = .{};
    try ctx.addFinalizerExitFor(ExitFinalizerProbe, &fiber_success_finalizer_probe, observeTypedFinalizerExit);
    return 42;
}

pub fn failsWithFiberFinalizer(ctx: *fx.Context(fx.TestServices)) TestError!u32 {
    fiber_failure_finalizer_probe = .{};
    try ctx.addFinalizerExitFor(ExitFinalizerProbe, &fiber_failure_finalizer_probe, observeTypedFinalizerExit);
    return error.Boom;
}

pub fn pendingScopedFiber(ctx: *fx.Context(fx.TestServices)) TestError!u32 {
    fiber_scoped_finalizer_probe = .{};
    try ctx.addFinalizerExitFor(ExitFinalizerProbe, &fiber_scoped_finalizer_probe, observeTypedFinalizerExit);
    return 7;
}

pub const FinalizerState = struct {
    allocator: std.mem.Allocator,
    order: std.ArrayList(u8),
};

pub fn appendA(raw: ?*anyopaque) void {
    const state: *FinalizerState = @ptrCast(@alignCast(raw.?));
    state.order.append(state.allocator, 'a') catch unreachable;
}

pub fn appendB(raw: ?*anyopaque) void {
    const state: *FinalizerState = @ptrCast(@alignCast(raw.?));
    state.order.append(state.allocator, 'b') catch unreachable;
}

pub fn releaseTyped(state: *FinalizerState) void {
    state.order.append(state.allocator, 't') catch unreachable;
}

pub const TrackedResource = struct {
    allocator: std.mem.Allocator,
    id: u32,
};

pub var tracked_resource_released = false;

pub fn acquireTracked(ctx: *fx.Context(fx.TestServices)) TestError!*TrackedResource {
    tracked_resource_released = false;
    const resource = try ctx.allocator.create(TrackedResource);
    resource.* = .{
        .allocator = ctx.allocator,
        .id = 9,
    };
    return resource;
}

pub fn releaseTracked(resource: *TrackedResource) void {
    tracked_resource_released = true;
    resource.allocator.destroy(resource);
}

pub fn releaseTrackedFailing(resource: *TrackedResource) anyerror!void {
    tracked_resource_released = true;
    resource.allocator.destroy(resource);
    return error.CloseFailed;
}

pub fn trackedId(resource: *TrackedResource) u32 {
    return resource.id;
}

pub fn failAfterTracked(resource: *TrackedResource, ctx: *fx.Context(fx.TestServices)) TestError!u32 {
    _ = resource;
    const logger = ctx.service(fx.Logger);
    try logger.info("failing after acquire");
    return error.Boom;
}

pub fn acquireTrackedWithFailingCleanup(ctx: *fx.Context(fx.TestServices)) TestError!*TrackedResource {
    tracked_resource_released = false;
    const resource = try ctx.allocator.create(TrackedResource);
    resource.* = .{
        .allocator = ctx.allocator,
        .id = 10,
    };
    try ctx.addFinalizerFallibleFor(TrackedResource, resource, releaseTrackedFailing);
    return resource;
}

pub fn acquireTrackedThenFailWithFailingCleanup(ctx: *fx.Context(fx.TestServices)) TestError!u32 {
    const resource = try acquireTrackedWithFailingCleanup(ctx);
    return failAfterTracked(resource, ctx);
}

pub const ValueResource = struct {
    id: u32,
    state: *FinalizerState,
};

pub var value_resource_state: ?*FinalizerState = null;
pub var value_resource_released = false;

pub fn acquireValueResourceA(ctx: *fx.Context(fx.TestServices)) TestError!ValueResource {
    _ = ctx;
    value_resource_released = false;
    return .{
        .id = 1,
        .state = value_resource_state.?,
    };
}

pub fn acquireValueResourceB(ctx: *fx.Context(fx.TestServices)) TestError!ValueResource {
    _ = ctx;
    return .{
        .id = 2,
        .state = value_resource_state.?,
    };
}

pub fn releaseValueResourceA(resource: ValueResource) void {
    value_resource_released = true;
    resource.state.order.append(resource.state.allocator, 'a') catch unreachable;
}

pub fn releaseValueResourceB(resource: ValueResource) void {
    resource.state.order.append(resource.state.allocator, 'b') catch unreachable;
}

pub fn valueResourceId(resource: ValueResource) u32 {
    return resource.id;
}

pub fn acquireNestedValueResources(ctx: *fx.Context(fx.TestServices)) TestError!u32 {
    const first = try fx.acquireReleaseValue(
        ValueResource,
        TestError,
        fx.TestServices,
        acquireValueResourceA,
        releaseValueResourceA,
    ).run(ctx);
    const second = try fx.acquireReleaseValue(
        ValueResource,
        TestError,
        fx.TestServices,
        acquireValueResourceB,
        releaseValueResourceB,
    ).run(ctx);
    return first.id + second.id;
}

pub fn failingRawFinalizer(raw: ?*anyopaque) anyerror!void {
    const ran: *bool = @ptrCast(@alignCast(raw.?));
    ran.* = true;
    return error.CloseFailed;
}

pub const ExitFinalizerProbe = struct {
    status: []const u8 = "none",
};

pub fn observeFinalizerExit(raw: ?*anyopaque, exit: fx.FinalizerExit) void {
    const probe: *ExitFinalizerProbe = @ptrCast(@alignCast(raw.?));
    probe.status = switch (exit) {
        .success => "success",
        .failure => |name| name,
        .defect => |message| message,
        .interrupted => "interrupted",
        .cause => |name| name,
    };
}

pub const BuiltLayerEnv = struct {
    logger: fx.Logger,
    released: *bool,

    pub fn service(self: *BuiltLayerEnv, comptime Service: type) *Service {
        if (Service == fx.Logger) return &self.logger;
        return fx.serviceNotFound(BuiltLayerEnv, Service);
    }
};

pub var layer_env_released = false;

pub fn releaseBuiltLayerEnv(env: *BuiltLayerEnv) void {
    const allocator = env.logger.allocator;
    env.logger.deinit();
    env.released.* = true;
    allocator.destroy(env);
}

pub fn buildBuiltLayerEnv(allocator: std.mem.Allocator, scope: *fx.Scope) std.mem.Allocator.Error!*BuiltLayerEnv {
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

pub const ConfigLayerEnv = struct {
    config: fx.Config,

    pub fn service(self: *ConfigLayerEnv, comptime Service: type) *Service {
        if (Service == fx.Config) return &self.config;
        return fx.serviceNotFound(ConfigLayerEnv, Service);
    }
};

pub const MergedLayerEnv = struct {
    logger_env: *BuiltLayerEnv,
    config_env: *ConfigLayerEnv,
    released: *bool,

    pub fn service(self: *MergedLayerEnv, comptime Service: type) *Service {
        if (Service == fx.Logger) return self.logger_env.service(Service);
        if (Service == fx.Config) return self.config_env.service(Service);
        return fx.serviceNotFound(MergedLayerEnv, Service);
    }
};

pub var merged_layer_released = false;

pub fn releaseMergedLayerEnv(env: *MergedLayerEnv) void {
    const allocator = env.logger_env.logger.allocator;
    env.released.* = true;
    allocator.destroy(env);
}

pub fn combineLayerEnvs(
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

pub fn runMergedLayerProgram(ctx: *fx.Context(MergedLayerEnv)) TestError![]const u8 {
    const logger = ctx.service(fx.Logger);
    const config = ctx.service(fx.Config);
    const value = config.require("app.name") catch return error.Empty;
    try logger.info("merged layer ran");
    return value;
}

pub const GraphLoggerEnv = struct {
    logger: fx.Logger,

    pub fn service(self: *GraphLoggerEnv, comptime Service: type) *Service {
        if (Service == fx.Logger) return &self.logger;
        return fx.serviceNotFound(GraphLoggerEnv, Service);
    }
};

pub const GraphConfigEnv = struct {
    config: fx.Config,

    pub fn service(self: *GraphConfigEnv, comptime Service: type) *Service {
        if (Service == fx.Config) return &self.config;
        return fx.serviceNotFound(GraphConfigEnv, Service);
    }
};

pub var graph_logger_builds: usize = 0;
pub var graph_config_builds: usize = 0;
pub var graph_logger_released = false;
pub var graph_config_released = false;

pub fn releaseGraphLoggerEnv(env: *GraphLoggerEnv) void {
    const allocator = env.logger.allocator;
    env.logger.deinit();
    graph_logger_released = true;
    allocator.destroy(env);
}

pub fn releaseGraphConfigEnv(env: *GraphConfigEnv) void {
    const allocator = env.config.allocator;
    env.config.deinit();
    graph_config_released = true;
    allocator.destroy(env);
}

pub fn buildGraphLoggerEnv(allocator: std.mem.Allocator, scope: *fx.Scope) std.mem.Allocator.Error!*GraphLoggerEnv {
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

pub fn buildGraphConfigEnv(allocator: std.mem.Allocator, scope: *fx.Scope) std.mem.Allocator.Error!*GraphConfigEnv {
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

pub const Database = struct {
    dsn: []const u8,
};

pub const DatabaseLayerEnv = struct {
    allocator: std.mem.Allocator,
    database: Database,
    released: *bool,

    pub fn service(self: *DatabaseLayerEnv, comptime Service: type) *Service {
        if (Service == Database) return &self.database;
        return fx.serviceNotFound(DatabaseLayerEnv, Service);
    }
};

pub var database_layer_builds: usize = 0;
pub var database_layer_released = false;

pub fn releaseDatabaseLayerEnv(env: *DatabaseLayerEnv) void {
    env.released.* = true;
    env.database.dsn = "";
    env.allocator.destroy(env);
}

pub fn buildDatabaseLayerEnv(
    allocator: std.mem.Allocator,
    scope: *fx.Scope,
    ctx: anytype,
) (std.mem.Allocator.Error || StartupError)!*DatabaseLayerEnv {
    database_layer_builds += 1;
    database_layer_released = false;

    const config = ctx.service(fx.Config);
    const logger = ctx.service(fx.Logger);
    try logger.info("database layer starting");

    const dsn = config.require("database.dsn") catch return error.ConnectionFailed;
    const env = try allocator.create(DatabaseLayerEnv);
    env.* = .{
        .allocator = allocator,
        .database = .{ .dsn = dsn },
        .released = &database_layer_released,
    };
    scope.addFinalizerFor(DatabaseLayerEnv, env, releaseDatabaseLayerEnv) catch |err| {
        releaseDatabaseLayerEnv(env);
        return err;
    };
    return env;
}

pub fn buildFailingDatabaseLayerEnv(
    allocator: std.mem.Allocator,
    scope: *fx.Scope,
    ctx: anytype,
) (std.mem.Allocator.Error || StartupError)!*DatabaseLayerEnv {
    _ = allocator;
    _ = scope;
    const logger = ctx.service(fx.Logger);
    try logger.info("database layer failed");
    return error.ConnectionFailed;
}

pub fn runDatabaseProgram(ctx: anytype) TestError![]const u8 {
    const database = ctx.service(Database);
    return database.dsn;
}

pub const GraphFiberStartupError = fx.DependencyError || fx.ScopeError;
pub const GraphFiberServices = fx.ServiceEnv(.{fx.Logger});

pub const GraphFiberService = struct {
    name: []const u8 = "graph-fiber",
};

pub const GraphFiberEnv = struct {
    allocator: std.mem.Allocator,
    service_value: GraphFiberService,
    startup_env: GraphFiberServices,
    runtime: fx.FiberRuntime(GraphFiberServices),
    fiber: ?fx.Fiber(u32, TestError, GraphFiberServices),

    pub fn service(self: *GraphFiberEnv, comptime Service: type) *Service {
        if (Service == GraphFiberService) return &self.service_value;
        return fx.serviceNotFound(GraphFiberEnv, Service);
    }
};

pub var graph_fiber_released = false;
pub var graph_fiber_status_on_release: fx.FiberStatus = .pending;

pub fn graphChildFiber(ctx: *fx.Context(GraphFiberServices)) TestError!u32 {
    const logger = ctx.service(fx.Logger);
    try logger.info("graph child fiber started");
    return 1;
}

pub const GraphChildFiber = fx.Effect(u32, TestError, GraphFiberServices)
    .fromFn(graphChildFiber)
    .requires(.{fx.Logger});

pub fn releaseGraphFiberEnv(env: *GraphFiberEnv) void {
    graph_fiber_released = true;
    graph_fiber_status_on_release = if (env.fiber) |fiber| fiber.status() else .pending;
    env.runtime.deinit();
    env.allocator.destroy(env);
}

pub fn buildGraphFiberEnv(
    allocator: std.mem.Allocator,
    scope: *fx.Scope,
    ctx: anytype,
) (std.mem.Allocator.Error || GraphFiberStartupError)!*GraphFiberEnv {
    graph_fiber_released = false;
    graph_fiber_status_on_release = .pending;

    const env = try allocator.create(GraphFiberEnv);
    env.* = .{
        .allocator = allocator,
        .service_value = .{},
        .startup_env = GraphFiberServices.fromContext(ctx),
        .runtime = undefined,
        .fiber = null,
    };
    env.runtime = fx.FiberRuntime(GraphFiberServices)
        .init(allocator, &env.startup_env)
        .provides(.{fx.Logger});

    scope.addFinalizerFor(GraphFiberEnv, env, releaseGraphFiberEnv) catch |err| {
        releaseGraphFiberEnv(env);
        return err;
    };
    env.fiber = try env.runtime.forkInScope(scope, GraphChildFiber);
    return env;
}

pub const StartupError = error{ConnectionFailed};

pub const StartupLayerEnv = struct {
    logger: fx.Logger,

    pub fn service(self: *StartupLayerEnv, comptime Service: type) *Service {
        if (Service == fx.Logger) return &self.logger;
        return fx.serviceNotFound(StartupLayerEnv, Service);
    }
};

pub fn buildFailingStartupLayer(
    allocator: std.mem.Allocator,
    scope: *fx.Scope,
) (std.mem.Allocator.Error || StartupError)!*StartupLayerEnv {
    _ = allocator;
    _ = scope;
    return error.ConnectionFailed;
}

pub fn startupLayerProgram(ctx: *fx.Context(StartupLayerEnv)) TestError!u32 {
    _ = ctx;
    return 1;
}

pub var retry_attempts: u8 = 0;

pub fn succeedsAfterRetry(ctx: *fx.Context(fx.TestServices)) TestError!u32 {
    retry_attempts += 1;
    const metrics = ctx.service(fx.Metrics);
    try metrics.increment("attempts", 1);
    if (retry_attempts < 3) return error.Boom;
    return 7;
}

pub var repeat_runs: u8 = 0;

pub fn countsRepeats(ctx: *fx.Context(fx.TestServices)) TestError!u8 {
    repeat_runs += 1;
    const metrics = ctx.service(fx.Metrics);
    try metrics.increment("repeat.runs", 1);
    return repeat_runs;
}
