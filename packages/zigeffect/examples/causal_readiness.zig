const std = @import("std");
const fx = @import("zigeffect");

const AppError = error{ MissingConfig, InvalidConfig, OutOfMemory };
const StartupError = error{MissingConfig};

const Database = struct {
    dsn: []const u8,
};

const ReadinessResult = struct {
    dsn: []const u8,
    region: []const u8,
};

const LoggerEnv = struct {
    logger: fx.Logger,

    pub fn service(self: *LoggerEnv, comptime Service: type) *Service {
        if (Service == fx.Logger) return &self.logger;
        return fx.serviceNotFound(LoggerEnv, Service);
    }
};

const MetricsEnv = struct {
    metrics: fx.Metrics,

    pub fn service(self: *MetricsEnv, comptime Service: type) *Service {
        if (Service == fx.Metrics) return &self.metrics;
        return fx.serviceNotFound(MetricsEnv, Service);
    }
};

const TracingEnv = struct {
    tracing: fx.Tracing,

    pub fn service(self: *TracingEnv, comptime Service: type) *Service {
        if (Service == fx.Tracing) return &self.tracing;
        return fx.serviceNotFound(TracingEnv, Service);
    }
};

const DatabaseEnv = struct {
    allocator: std.mem.Allocator,
    database: Database,

    pub fn service(self: *DatabaseEnv, comptime Service: type) *Service {
        if (Service == Database) return &self.database;
        return fx.serviceNotFound(DatabaseEnv, Service);
    }
};

const StartupEnv = fx.ServiceEnv(.{
    fx.Config,
    fx.Logger,
    fx.Metrics,
    fx.Tracing,
});

const ReadinessEnv = fx.ServiceEnv(.{
    Database,
    fx.Config,
    fx.Logger,
    fx.Metrics,
    fx.Tracing,
});

fn releaseDatabase(env: *DatabaseEnv) void {
    env.allocator.destroy(env);
}

fn configToStartup(err: fx.ConfigError) StartupError {
    return switch (err) {
        error.MissingConfig => error.MissingConfig,
        error.InvalidConfigValue => error.MissingConfig,
    };
}

fn configToApp(err: fx.ConfigError) AppError {
    return switch (err) {
        error.MissingConfig => error.MissingConfig,
        error.InvalidConfigValue => error.InvalidConfig,
    };
}

fn recordAppEvent(
    ctx: *fx.Context(ReadinessEnv),
    kind: fx.CausalEventKind,
    label: []const u8,
    status: []const u8,
    detail: []const u8,
) void {
    _ = ctx.recordCausal(.{
        .kind = kind,
        .label = label,
        .status = status,
        .redacted_detail = detail,
    });
}

fn buildDatabase(ctx: *fx.Context(StartupEnv)) (std.mem.Allocator.Error || StartupError)!*DatabaseEnv {
    const logger = ctx.service(fx.Logger);
    const metrics = ctx.service(fx.Metrics);
    const tracing = ctx.service(fx.Tracing);
    const config = ctx.service(fx.Config);

    const span_id = try tracing.startSpan("database startup", ctx.span_id);
    _ = ctx.recordCausal(.{
        .kind = .span_recorded,
        .span_id = span_id,
        .label = "database startup",
        .status = "started",
    });
    errdefer tracing.endSpan(span_id) catch {};

    const dsn = config.require("database.dsn") catch |err| {
        _ = ctx.recordCausal(.{
            .kind = .assertion_recorded,
            .label = "database.dsn",
            .type_name = @errorName(err),
            .status = "failure",
            .redacted_detail = "missing startup config",
        });
        return configToStartup(err);
    };

    try logger.info("database startup");
    _ = ctx.recordCausal(.{
        .kind = .log_recorded,
        .label = "database startup",
        .status = "info",
    });

    try metrics.increment("database.startups", 1);
    _ = ctx.recordCausal(.{
        .kind = .metric_recorded,
        .label = "database.startups",
        .status = "increment",
        .redacted_detail = "1",
    });

    const env = try ctx.allocator.create(DatabaseEnv);
    env.* = .{
        .allocator = ctx.allocator,
        .database = .{ .dsn = dsn },
    };
    ctx.scope.?.addFinalizerFor(DatabaseEnv, env, releaseDatabase) catch |err| {
        releaseDatabase(env);
        return err;
    };

    try tracing.endSpan(span_id);
    _ = ctx.recordCausal(.{
        .kind = .span_recorded,
        .span_id = span_id,
        .label = "database startup",
        .status = "completed",
    });
    return env;
}

const BuildDatabase = fx.Effect(
    *DatabaseEnv,
    std.mem.Allocator.Error || StartupError,
    StartupEnv,
)
    .fromFn(buildDatabase)
    .requires(.{ fx.Config, fx.Logger, fx.Metrics, fx.Tracing });

fn databaseLayer() fx.ProvidedLayer(
    fx.EffectLayer(DatabaseEnv, StartupError, @TypeOf(BuildDatabase)),
    .{Database},
) {
    return fx.LayerWithError(DatabaseEnv, StartupError)
        .fromEffect(BuildDatabase)
        .provides(.{Database});
}

fn checkReadiness(ctx: *fx.Context(ReadinessEnv)) AppError!ReadinessResult {
    const database = ctx.service(Database);
    const config = ctx.service(fx.Config);
    const logger = ctx.service(fx.Logger);
    const metrics = ctx.service(fx.Metrics);
    const tracing = ctx.service(fx.Tracing);

    const span_id = try tracing.startSpan("readiness check", ctx.span_id);
    recordAppEvent(ctx, .span_recorded, "readiness check", "started", "");
    errdefer {
        tracing.endSpan(span_id) catch {};
        recordAppEvent(ctx, .span_recorded, "readiness check", "failure", "");
    }

    try logger.info("readiness check");
    recordAppEvent(ctx, .log_recorded, "readiness check", "info", "");

    try metrics.increment("readiness.checks", 1);
    recordAppEvent(ctx, .metric_recorded, "readiness.checks", "increment", "1");

    const region = config.require("readiness.region") catch |err| {
        _ = ctx.recordCausal(.{
            .kind = .assertion_recorded,
            .label = "readiness.region",
            .type_name = @errorName(err),
            .status = "failure",
            .redacted_detail = "missing app config",
        });
        return configToApp(err);
    };

    try tracing.endSpan(span_id);
    recordAppEvent(ctx, .span_recorded, "readiness check", "completed", "");
    return .{
        .dsn = database.dsn,
        .region = region,
    };
}

const Readiness = fx.Effect(ReadinessResult, AppError, ReadinessEnv)
    .fromFn(checkReadiness)
    .requires(.{ Database, fx.Config, fx.Logger, fx.Metrics, fx.Tracing });

fn hasEvent(store: *const fx.CausalStore, kind: fx.CausalEventKind, label: []const u8, status: []const u8) bool {
    for (store.events.items) |event| {
        if (event.kind == kind and
            std.mem.eql(u8, event.label, label) and
            std.mem.eql(u8, event.status, status))
        {
            return true;
        }
    }
    return false;
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    var logger_env = LoggerEnv{ .logger = fx.Logger.init(allocator) };
    defer logger_env.logger.deinit();

    var config_env = fx.ConfigEnv.init(allocator);
    defer config_env.deinit();
    try config_env.config.loadDotEnv(
        \\database.dsn=postgres://example
    );

    var metrics_env = MetricsEnv{ .metrics = fx.Metrics.init(allocator) };
    defer metrics_env.metrics.deinit();

    var tracing_env = TracingEnv{ .tracing = fx.Tracing.init(allocator) };
    defer tracing_env.tracing.deinit();

    const logger_layer = fx.Layer(LoggerEnv)
        .fromEnv(&logger_env)
        .provides(.{fx.Logger});
    const config_layer = fx.Layer(fx.ConfigEnv)
        .fromEnv(&config_env)
        .provides(.{fx.Config});
    const metrics_layer = fx.Layer(MetricsEnv)
        .fromEnv(&metrics_env)
        .provides(.{fx.Metrics});
    const tracing_layer = fx.Layer(TracingEnv)
        .fromEnv(&tracing_env)
        .provides(.{fx.Tracing});

    var store = fx.CausalStore.init(allocator);
    defer store.deinit();

    var graph = fx.layerGraph(allocator, .{
        databaseLayer(),
        config_layer,
        logger_layer,
        metrics_layer,
        tracing_layer,
    })
        .withTraceContext(1001, null)
        .withCausalStore(&store);
    defer graph.deinit();

    const result = graph.runNarrowed(.{
        Database,
        fx.Config,
        fx.Logger,
        fx.Metrics,
        fx.Tracing,
    }, Readiness) catch |err| {
        std.debug.print("readiness failed with typed error: {s}\n\n", .{@errorName(err)});
        const report = try fx.formatCausalReport(allocator, "causal readiness", &store);
        defer allocator.free(report);
        const json = try fx.formatCausalJson(allocator, &store);
        defer allocator.free(json);
        std.debug.print("{s}\n{s}", .{ report, json });
        return;
    };

    std.debug.print("ready: database={s} region={s}\n\n", .{ result.dsn, result.region });
    const report = try fx.formatCausalReport(allocator, "causal readiness", &store);
    defer allocator.free(report);
    const json = try fx.formatCausalJson(allocator, &store);
    defer allocator.free(json);
    std.debug.print("{s}\n{s}", .{ report, json });
}

test "causal readiness example records graph app and observability events" {
    var env = try fx.TestEnv.init(std.testing.allocator);
    defer env.deinit();
    try env.services.config.set("database.dsn", "postgres://test");
    try env.services.config.set("readiness.region", "eu-west-2");

    var store = fx.CausalStore.init(std.testing.allocator);
    defer store.deinit();

    var graph = fx.layerGraph(std.testing.allocator, .{
        databaseLayer(),
        env.configLayer(),
        env.loggerLayer(),
        env.metricsLayer(),
        env.tracingLayer(),
    })
        .withTraceContext(42, null)
        .withCausalStore(&store);
    defer graph.deinit();

    const result = try graph.runNarrowed(.{
        Database,
        fx.Config,
        fx.Logger,
        fx.Metrics,
        fx.Tracing,
    }, Readiness);

    try std.testing.expectEqualStrings("postgres://test", result.dsn);
    try std.testing.expectEqualStrings("eu-west-2", result.region);
    try env.expectLog("database startup");
    try env.expectLog("readiness check");
    try std.testing.expectEqual(@as(i64, 1), env.services.metrics.get("database.startups"));
    try std.testing.expectEqual(@as(i64, 1), env.services.metrics.get("readiness.checks"));
    try std.testing.expect(hasEvent(&store, .service_required, @typeName(DatabaseEnv), "satisfied"));
    try std.testing.expect(hasEvent(&store, .resource_acquired, "", "success"));
    try std.testing.expect(hasEvent(&store, .log_recorded, "readiness check", "info"));
    try std.testing.expect(hasEvent(&store, .metric_recorded, "readiness.checks", "increment"));
    try std.testing.expect(hasEvent(&store, .span_recorded, "readiness check", "completed"));
    try std.testing.expect(hasEvent(&store, .exit_recorded, "", "success"));
}

test "causal readiness example keeps missing config as a typed app failure" {
    var env = try fx.TestEnv.init(std.testing.allocator);
    defer env.deinit();
    try env.services.config.set("database.dsn", "postgres://test");

    var store = fx.CausalStore.init(std.testing.allocator);
    defer store.deinit();

    var graph = fx.layerGraph(std.testing.allocator, .{
        databaseLayer(),
        env.configLayer(),
        env.loggerLayer(),
        env.metricsLayer(),
        env.tracingLayer(),
    }).withCausalStore(&store);
    defer graph.deinit();

    const err = graph.runNarrowed(.{
        Database,
        fx.Config,
        fx.Logger,
        fx.Metrics,
        fx.Tracing,
    }, Readiness);

    try std.testing.expectError(error.MissingConfig, err);
    try std.testing.expect(hasEvent(&store, .assertion_recorded, "readiness.region", "failure"));
    try std.testing.expect(hasEvent(&store, .exit_recorded, "", "failure"));

    const report = try fx.formatCausalReport(std.testing.allocator, "missing config", &store);
    defer std.testing.allocator.free(report);
    try std.testing.expect(std.mem.indexOf(u8, report, "MissingConfig") != null);

    const json = try fx.formatCausalJson(std.testing.allocator, &store);
    defer std.testing.allocator.free(json);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"kind\": \"assertion_recorded\"") != null);
}
