const std = @import("std");
const fx = @import("zigeffect");

const AppError = error{ MissingConfig, OutOfMemory };
const StartupError = error{ConnectionFailed};

const Database = struct {
    dsn: []const u8,
};

const DatabaseEnv = struct {
    allocator: std.mem.Allocator,
    database: Database,
    released: *bool,

    pub fn service(self: *DatabaseEnv, comptime Service: type) *Service {
        if (Service == Database) return &self.database;
        return fx.serviceNotFound(DatabaseEnv, Service);
    }
};

const LoggerEnv = struct {
    logger: fx.Logger,

    pub fn service(self: *LoggerEnv, comptime Service: type) *Service {
        if (Service == fx.Logger) return &self.logger;
        return fx.serviceNotFound(LoggerEnv, Service);
    }
};

var database_released = false;

fn releaseDatabase(env: *DatabaseEnv) void {
    env.released.* = true;
    env.allocator.destroy(env);
}

const StartupEnv = fx.ServiceEnv(.{ fx.Config, fx.Logger });

fn buildDatabase(ctx: *fx.Context(StartupEnv)) (std.mem.Allocator.Error || StartupError)!*DatabaseEnv {
    const logger = ctx.service(fx.Logger);
    const config = ctx.service(fx.Config);
    try logger.info("database startup");

    const dsn = config.require("database.dsn") catch return error.ConnectionFailed;
    const env = try ctx.allocator.create(DatabaseEnv);
    env.* = .{
        .allocator = ctx.allocator,
        .database = .{ .dsn = dsn },
        .released = &database_released,
    };
    ctx.scope.?.addFinalizerFor(DatabaseEnv, env, releaseDatabase) catch |err| {
        releaseDatabase(env);
        return err;
    };
    return env;
}

const ReadinessEnv = fx.ServiceEnv(.{ Database, fx.Logger });

fn checkReadiness(ctx: *fx.Context(ReadinessEnv)) AppError![]const u8 {
    const database = ctx.service(Database);
    const logger = ctx.service(fx.Logger);
    try logger.info("readiness check");
    return database.dsn;
}

fn databaseLayer() fx.ProvidedLayer(
    fx.EffectLayer(DatabaseEnv, StartupError, @TypeOf(BuildDatabase)),
    .{Database},
) {
    return fx.LayerWithError(DatabaseEnv, StartupError)
        .fromEffect(BuildDatabase)
        .provides(.{Database});
}

const BuildDatabase = fx.Effect(
    *DatabaseEnv,
    std.mem.Allocator.Error || StartupError,
    StartupEnv,
)
    .fromFn(buildDatabase)
    .requires(.{ fx.Config, fx.Logger });

const Readiness = fx.Effect([]const u8, AppError, ReadinessEnv)
    .fromFn(checkReadiness)
    .requires(.{ Database, fx.Logger });

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    var logger_env = LoggerEnv{ .logger = fx.Logger.init(allocator) };
    defer logger_env.logger.deinit();

    var config_env = fx.ConfigEnv.init(allocator);
    defer config_env.deinit();
    try config_env.config.loadDotEnv(
        \\database.dsn=postgres://example
    );

    const logger_layer = fx.Layer(LoggerEnv)
        .fromEnv(&logger_env)
        .provides(.{fx.Logger});
    const config_layer = fx.Layer(fx.ConfigEnv)
        .fromEnv(&config_env)
        .provides(.{fx.Config});

    var graph = fx.layerGraph(allocator, .{
        databaseLayer(),
        config_layer,
        logger_layer,
    });
    defer graph.deinit();

    const report = try graph.report("readiness app startup");
    defer allocator.free(report);

    const dsn = try graph.runNarrowed(.{ Database, fx.Logger }, Readiness);
    std.debug.print("ready: {s}\n", .{dsn});
}

test "readiness example runs through fake service layers" {
    var env = try fx.TestEnv.init(std.testing.allocator);
    defer env.deinit();
    try env.services.config.set("database.dsn", "postgres://test");

    var graph = fx.layerGraph(std.testing.allocator, .{
        databaseLayer(),
        env.configLayer(),
        env.loggerLayer(),
    });
    defer graph.deinit();

    try std.testing.expectEqualStrings(
        "postgres://test",
        try graph.runNarrowed(.{ Database, fx.Logger }, Readiness),
    );
    try env.expectLog("database startup");
    try env.expectLog("readiness check");
    try std.testing.expect(!database_released);
}
