//! Low-level engine failure fixture; not application scaffolding.
//! Direct stores are used here only to prove framework causal behavior.

const std = @import("std");
const fx = @import("zigeffect");

const StartupError = error{MissingConfig};

const Database = struct {
    dsn: []const u8,
};

const DatabaseEnv = struct {
    allocator: std.mem.Allocator,
    database: Database,

    pub fn service(self: *DatabaseEnv, comptime Service: type) *Service {
        if (Service == Database) return &self.database;
        return fx.serviceNotFound(DatabaseEnv, Service);
    }
};

const StartupEnv = fx.ServiceEnv(.{ fx.Config, fx.Logger });

fn releaseDatabase(env: *DatabaseEnv) void {
    env.allocator.destroy(env);
}

fn buildDatabase(ctx: *fx.Context(StartupEnv)) (std.mem.Allocator.Error || StartupError)!*DatabaseEnv {
    const logger = ctx.service(fx.Logger);
    const config = ctx.service(fx.Config);
    try logger.info("database startup");

    const dsn = config.require("database.dsn") catch return error.MissingConfig;
    const env = try ctx.allocator.create(DatabaseEnv);
    env.* = .{
        .allocator = ctx.allocator,
        .database = .{ .dsn = dsn },
    };
    ctx.scope.?.addFinalizerFor(DatabaseEnv, env, releaseDatabase) catch |err| {
        releaseDatabase(env);
        return err;
    };
    return env;
}

const BuildDatabase = fx.Effect(
    *DatabaseEnv,
    std.mem.Allocator.Error || StartupError,
    StartupEnv,
)
    .fromFn(buildDatabase)
    .requires(.{ fx.Config, fx.Logger });

fn databaseLayer() fx.ProvidedLayer(
    fx.EffectLayer(DatabaseEnv, StartupError, @TypeOf(BuildDatabase)),
    .{Database},
) {
    return fx.LayerWithError(DatabaseEnv, StartupError)
        .fromEffect(BuildDatabase)
        .provides(.{Database});
}

fn hasEvent(store: *const fx.CausalStore, kind: fx.CausalEventKind, status: []const u8) bool {
    for (store.events.items) |event| {
        if (event.kind == kind and std.mem.eql(u8, event.status, status)) return true;
    }
    return false;
}

fn runScenario(allocator: std.mem.Allocator, store: *fx.CausalStore) !void {
    var env = try fx.TestEnv.init(allocator);
    defer env.deinit();

    var graph = fx.layerGraph(allocator, .{
        databaseLayer(),
        env.configLayer(),
        env.loggerLayer(),
    }).withCausalStore(store);
    defer graph.deinit();

    _ = graph.start() catch |err| switch (err) {
        error.MissingConfig => return,
        else => return err,
    };
    return error.ExpectedMissingConfig;
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    var store = fx.CausalStore.init(allocator);
    defer store.deinit();

    try runScenario(allocator, &store);

    const report = try fx.formatCausalReport(allocator, "missing config scenario", &store);
    defer allocator.free(report);
    std.debug.print("{s}", .{report});
}

test "missing config scenario records layer and dependency evidence" {
    var store = fx.CausalStore.init(std.testing.allocator);
    defer store.deinit();

    try runScenario(std.testing.allocator, &store);

    try std.testing.expect(hasEvent(&store, .service_required, "satisfied"));
    try std.testing.expect(hasEvent(&store, .service_provided, "provided"));
    try std.testing.expect(hasEvent(&store, .layer_started, "starting"));
    try std.testing.expect(hasEvent(&store, .exit_recorded, "failure"));
}
