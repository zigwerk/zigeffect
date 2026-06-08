const std = @import("std");
const fx = @import("zigeffect");
const causal = @import("support/causal_assertions.zig");
const fixtures = @import("support/fixtures.zig");

fn expectCompileFailDiagnostic(fixture: []const u8, output_path: []const u8, expected: []const u8) !void {
    _ = output_path;
    var io_instance = std.Io.Threaded.init(std.testing.allocator, .{});
    defer io_instance.deinit();
    const io = io_instance.io();

    const root_arg = try std.fmt.allocPrint(
        std.testing.allocator,
        "-Mroot=test/compile_fail/{s}",
        .{fixture},
    );
    defer std.testing.allocator.free(root_arg);

    const result = try std.process.run(std.testing.allocator, io, .{
        .argv = &.{
            "/opt/homebrew/bin/zig",
            "build-exe",
            "--dep",
            "zigeffect",
            root_arg,
            "-Mzigeffect=src/zigeffect.zig",
            "-fno-emit-bin",
            "--cache-dir",
            ".zig-cache/compile-fail-cache",
            "--global-cache-dir",
            ".zig-cache/compile-fail-global-cache",
        },
    });
    defer std.testing.allocator.free(result.stdout);
    defer std.testing.allocator.free(result.stderr);

    switch (result.term) {
        .exited => |code| try std.testing.expect(code != 0),
        else => return error.Empty,
    }

    try std.testing.expect(
        std.mem.indexOf(u8, result.stdout, expected) != null or
            std.mem.indexOf(u8, result.stderr, expected) != null,
    );
}

test "layer builder constructs dependencies and scope releases them" {
    var scope = fx.Scope.init(std.testing.allocator);
    defer scope.deinit();

    const layer = fx.Layer(fixtures.BuiltLayerEnv).fromBuilder(fixtures.buildBuiltLayerEnv);
    var ctx = try layer.buildContext(std.testing.allocator, &scope);

    const logger = ctx.service(fx.Logger);
    try logger.info("layer ready");
    try std.testing.expectEqualStrings("layer ready", logger.entries.items[0]);
    try std.testing.expect(!fixtures.layer_env_released);

    scope.close();

    try std.testing.expect(fixtures.layer_env_released);
}
test "layer merge composes dependencies and provide runs effects" {
    var logger_env = fixtures.BuiltLayerEnv{
        .logger = fx.Logger.init(std.testing.allocator),
        .released = &fixtures.layer_env_released,
    };
    defer logger_env.logger.deinit();

    var config_env = fixtures.ConfigLayerEnv{ .config = fx.Config.init(std.testing.allocator) };
    defer config_env.config.deinit();
    try config_env.config.set("app.name", "zigeffect");

    const logger_layer = fx.Layer(fixtures.BuiltLayerEnv).fromEnv(&logger_env);
    const config_layer = fx.Layer(fixtures.ConfigLayerEnv).fromEnv(&config_env);
    const merged = logger_layer.merge(fixtures.ConfigLayerEnv, fixtures.MergedLayerEnv, config_layer, fixtures.combineLayerEnvs);
    const program = fx.Effect([]const u8, fixtures.TestError, fixtures.MergedLayerEnv).fromFn(fixtures.runMergedLayerProgram);

    try std.testing.expectEqualStrings("zigeffect", try merged.provide(std.testing.allocator, program));
    try std.testing.expectEqualStrings("merged layer ran", logger_env.logger.entries.items[0]);
    try std.testing.expect(fixtures.merged_layer_released);
}
test "effect requirements are validated by layers and runtimes" {
    var env = try fx.TestEnv.init(std.testing.allocator);
    defer env.deinit();

    const program = fx.Effect(u32, fixtures.TestError, fx.TestServices)
        .fromFn(fixtures.succeeds)
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
test "layer graph allows explicit replacement providers" {
    var base_config_env = fixtures.GraphConfigEnv{ .config = fx.Config.init(std.testing.allocator) };
    defer base_config_env.config.deinit();
    try base_config_env.config.set("app.name", "base");

    var replacement_config_env = fixtures.GraphConfigEnv{ .config = fx.Config.init(std.testing.allocator) };
    defer replacement_config_env.config.deinit();
    try replacement_config_env.config.set("app.name", "replacement");

    const base_layer = fx.Layer(fixtures.GraphConfigEnv)
        .fromEnv(&base_config_env)
        .provides(.{fx.Config});
    const replacement_layer = fx.Layer(fixtures.GraphConfigEnv)
        .fromEnv(&replacement_config_env)
        .provides(.{fx.Config})
        .replaces(.{fx.Config});

    var manual_graph = fx.LayerGraph.init(std.testing.allocator);
    defer manual_graph.deinit();
    try manual_graph.addLayer("base-config", base_layer);
    try manual_graph.addLayer("replacement-config", replacement_layer);

    var report = try manual_graph.validate(std.testing.allocator);
    defer report.deinit();
    try std.testing.expect(report.isValid());

    var graph = fx.layerGraph(std.testing.allocator, .{ base_layer, replacement_layer });
    defer graph.deinit();

    const GraphEnv = @TypeOf(graph).EnvType;
    const Program = fx.Effect([]const u8, fixtures.TestError, GraphEnv)
        .fromFn(struct {
            fn run(ctx: *fx.Context(GraphEnv)) fixtures.TestError![]const u8 {
                const config = ctx.service(fx.Config);
                return config.require("app.name") catch error.Empty;
            }
        }.run)
        .requires(.{fx.Config});

    try std.testing.expectEqualStrings("replacement", try graph.run(Program));
}
test "layer graph startup builders observe replacement providers" {
    fixtures.database_layer_builds = 0;
    fixtures.database_layer_released = false;

    var logger_env = fixtures.GraphLoggerEnv{ .logger = fx.Logger.init(std.testing.allocator) };
    defer logger_env.logger.deinit();

    var base_config_env = fixtures.GraphConfigEnv{ .config = fx.Config.init(std.testing.allocator) };
    defer base_config_env.config.deinit();
    try base_config_env.config.set("database.dsn", "base-dsn");

    var replacement_config_env = fixtures.GraphConfigEnv{ .config = fx.Config.init(std.testing.allocator) };
    defer replacement_config_env.config.deinit();
    try replacement_config_env.config.set("database.dsn", "replacement-dsn");

    const database_layer = fx.LayerWithError(fixtures.DatabaseLayerEnv, fixtures.StartupError)
        .fromContextBuilder(fixtures.buildDatabaseLayerEnv)
        .requires(.{ fx.Config, fx.Logger })
        .provides(.{fixtures.Database});
    const base_config_layer = fx.Layer(fixtures.GraphConfigEnv)
        .fromEnv(&base_config_env)
        .provides(.{fx.Config});
    const replacement_config_layer = fx.Layer(fixtures.GraphConfigEnv)
        .fromEnv(&replacement_config_env)
        .provides(.{fx.Config})
        .replaces(.{fx.Config});
    const logger_layer = fx.Layer(fixtures.GraphLoggerEnv)
        .fromEnv(&logger_env)
        .provides(.{fx.Logger});

    var graph = fx.layerGraph(std.testing.allocator, .{
        database_layer,
        base_config_layer,
        replacement_config_layer,
        logger_layer,
    });

    const GraphEnv = @TypeOf(graph).EnvType;
    const Program = fx.Effect([]const u8, fixtures.TestError, GraphEnv)
        .fromFn(struct {
            fn run(ctx: *fx.Context(GraphEnv)) fixtures.TestError![]const u8 {
                return fixtures.runDatabaseProgram(ctx);
            }
        }.run)
        .requires(.{fixtures.Database});

    try std.testing.expectEqualStrings("replacement-dsn", try graph.run(Program));
    try std.testing.expectEqual(@as(usize, 1), fixtures.database_layer_builds);

    graph.deinit();
    try std.testing.expect(fixtures.database_layer_released);
}
test "layer graph emits service and layer causal events during startup" {
    fixtures.graph_logger_builds = 0;
    fixtures.graph_config_builds = 0;

    var store = fx.CausalStore.init(std.testing.allocator);
    defer store.deinit();

    const logger_layer = fx.Layer(fixtures.GraphLoggerEnv)
        .fromBuilder(fixtures.buildGraphLoggerEnv)
        .provides(.{fx.Logger});
    const config_layer = fx.Layer(fixtures.GraphConfigEnv)
        .fromBuilder(fixtures.buildGraphConfigEnv)
        .requires(.{fx.Logger})
        .provides(.{fx.Config});

    var graph = fx.layerGraph(std.testing.allocator, .{ config_layer, logger_layer })
        .withTraceContext(707, 808)
        .withCausalStore(&store);
    defer graph.deinit();

    _ = try graph.start();

    var snapshot = try store.snapshot(std.testing.allocator);
    defer snapshot.deinit();

    _ = try causal.expectEvent(snapshot, .{
        .kind = .service_provided,
        .label = @typeName(fixtures.GraphLoggerEnv),
        .type_name = @typeName(fx.Logger),
        .status = "provided",
    });
    _ = try causal.expectEvent(snapshot, .{
        .kind = .service_required,
        .label = @typeName(fixtures.GraphConfigEnv),
        .type_name = @typeName(fx.Logger),
        .status = "satisfied",
    });
    const started = try causal.expectEvent(snapshot, .{
        .kind = .layer_started,
        .label = @typeName(fixtures.GraphConfigEnv),
        .status = "starting",
    });
    const completed = try causal.expectEvent(snapshot, .{
        .kind = .layer_completed,
        .label = @typeName(fixtures.GraphConfigEnv),
        .status = "success",
    });
    try std.testing.expectEqual(started.run_id.?, completed.run_id.?);
    try std.testing.expectEqual(@as(?u64, 707), started.trace_id);
    try std.testing.expectEqual(@as(?u64, 808), completed.span_id);
}
test "layer graph emits service replacement causal events" {
    var base_config_env = fixtures.GraphConfigEnv{ .config = fx.Config.init(std.testing.allocator) };
    defer base_config_env.config.deinit();
    try base_config_env.config.set("app.name", "base");

    var replacement_config_env = fixtures.GraphConfigEnv{ .config = fx.Config.init(std.testing.allocator) };
    defer replacement_config_env.config.deinit();
    try replacement_config_env.config.set("app.name", "replacement");

    var store = fx.CausalStore.init(std.testing.allocator);
    defer store.deinit();

    const base_layer = fx.Layer(fixtures.GraphConfigEnv)
        .fromEnv(&base_config_env)
        .provides(.{fx.Config});
    const replacement_layer = fx.Layer(fixtures.GraphConfigEnv)
        .fromEnv(&replacement_config_env)
        .provides(.{fx.Config})
        .replaces(.{fx.Config});

    var graph = fx.layerGraph(std.testing.allocator, .{ base_layer, replacement_layer })
        .withCausalStore(&store);
    defer graph.deinit();

    _ = try graph.start();

    var snapshot = try store.snapshot(std.testing.allocator);
    defer snapshot.deinit();

    const replaced = try causal.expectEvent(snapshot, .{
        .kind = .service_replaced,
        .label = @typeName(fixtures.GraphConfigEnv),
        .type_name = @typeName(fx.Config),
        .status = "replaced",
    });
    try std.testing.expect(replaced.redacted_detail.len > 0);
}
test "graph runtime formats dependency reports directly" {
    var env = try fx.TestEnv.init(std.testing.allocator);
    defer env.deinit();

    const logger_layer = env.layer().provides(.{fx.Logger});
    const metrics_layer = env.layer().requires(.{fx.Config}).provides(.{fx.Metrics});

    var graph = fx.layerGraph(std.testing.allocator, .{ logger_layer, metrics_layer });
    defer graph.deinit();

    const formatted = try graph.report("app startup");
    defer std.testing.allocator.free(formatted);

    try std.testing.expect(std.mem.indexOf(u8, formatted, "program: app startup") != null);
    try std.testing.expect(std.mem.indexOf(u8, formatted, "missing service requirement") != null);
    try std.testing.expect(std.mem.indexOf(u8, formatted, @typeName(fx.Config)) != null);
}
test "layer graph automatically composes heterogeneous declared layers" {
    var logger_env = fixtures.GraphLoggerEnv{ .logger = fx.Logger.init(std.testing.allocator) };
    defer logger_env.logger.deinit();

    var config_env = fixtures.GraphConfigEnv{ .config = fx.Config.init(std.testing.allocator) };
    defer config_env.config.deinit();
    try config_env.config.set("app.name", "zigeffect");

    const logger_layer = fx.Layer(fixtures.GraphLoggerEnv)
        .fromEnv(&logger_env)
        .provides(.{fx.Logger});
    const config_layer = fx.Layer(fixtures.GraphConfigEnv)
        .fromEnv(&config_env)
        .requires(.{fx.Logger})
        .provides(.{fx.Config});

    var graph = fx.layerGraph(std.testing.allocator, .{ config_layer, logger_layer });
    defer graph.deinit();

    const GraphEnv = @TypeOf(graph).EnvType;
    const Program = fx.Effect([]const u8, fixtures.TestError, GraphEnv)
        .fromFn(struct {
            fn run(ctx: *fx.Context(GraphEnv)) fixtures.TestError![]const u8 {
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
    fixtures.graph_logger_builds = 0;
    fixtures.graph_config_builds = 0;
    fixtures.graph_logger_released = false;
    fixtures.graph_config_released = false;

    const logger_layer = fx.Layer(fixtures.GraphLoggerEnv)
        .fromBuilder(fixtures.buildGraphLoggerEnv)
        .provides(.{fx.Logger});
    const config_layer = fx.Layer(fixtures.GraphConfigEnv)
        .fromBuilder(fixtures.buildGraphConfigEnv)
        .requires(.{fx.Logger})
        .provides(.{fx.Config});

    var graph = fx.layerGraph(std.testing.allocator, .{ config_layer, logger_layer });

    const GraphEnv = @TypeOf(graph).EnvType;
    const Program = fx.Effect([]const u8, fixtures.TestError, GraphEnv)
        .fromFn(struct {
            fn run(ctx: *fx.Context(GraphEnv)) fixtures.TestError![]const u8 {
                const logger = ctx.service(fx.Logger);
                const config = ctx.service(fx.Config);
                try logger.info("memoized run");
                return config.require("app.name") catch error.Empty;
            }
        }.run)
        .requires(.{ fx.Logger, fx.Config });

    try std.testing.expectEqualStrings("graph", try graph.run(Program));
    try std.testing.expectEqualStrings("graph", try graph.run(Program));
    try std.testing.expectEqual(@as(usize, 1), fixtures.graph_logger_builds);
    try std.testing.expectEqual(@as(usize, 1), fixtures.graph_config_builds);
    try std.testing.expect(!fixtures.graph_logger_released);
    try std.testing.expect(!fixtures.graph_config_released);

    graph.deinit();
    try std.testing.expect(fixtures.graph_logger_released);
    try std.testing.expect(fixtures.graph_config_released);
}
test "layer graph rejects invalid dependencies before startup" {
    fixtures.graph_logger_builds = 0;
    fixtures.graph_config_builds = 0;

    const logger_a = fx.Layer(fixtures.GraphLoggerEnv)
        .fromBuilder(fixtures.buildGraphLoggerEnv)
        .provides(.{fx.Logger});
    const logger_b = fx.Layer(fixtures.GraphLoggerEnv)
        .fromBuilder(fixtures.buildGraphLoggerEnv)
        .provides(.{fx.Logger});

    var duplicate_graph = fx.layerGraph(std.testing.allocator, .{ logger_a, logger_b });
    defer duplicate_graph.deinit();

    try std.testing.expectError(error.DuplicateServiceProvider, duplicate_graph.start());
    try std.testing.expectEqual(@as(usize, 0), fixtures.graph_logger_builds);

    const needs_config = fx.Layer(fixtures.GraphLoggerEnv)
        .fromBuilder(fixtures.buildGraphLoggerEnv)
        .requires(.{fx.Config})
        .provides(.{fx.Logger});

    var missing_graph = fx.layerGraph(std.testing.allocator, .{needs_config});
    defer missing_graph.deinit();

    var report = try missing_graph.validate(std.testing.allocator);
    defer report.deinit();
    try std.testing.expect(report.hasMissing(@typeName(fx.Config)));

    try std.testing.expectError(error.MissingServiceRequirement, missing_graph.start());
    try std.testing.expectEqual(@as(usize, 0), fixtures.graph_logger_builds);
}
test "typed layer startup errors are preserved through provide" {
    const layer = fx.LayerWithError(fixtures.StartupLayerEnv, fixtures.StartupError)
        .fromBuilder(fixtures.buildFailingStartupLayer)
        .provides(.{fx.Logger});
    const program = fx.Effect(u32, fixtures.TestError, fixtures.StartupLayerEnv).fromFn(fixtures.startupLayerProgram);

    try std.testing.expectError(error.ConnectionFailed, layer.provide(std.testing.allocator, program));
}
test "layer graph preserves typed startup errors" {
    const layer = fx.LayerWithError(fixtures.StartupLayerEnv, fixtures.StartupError)
        .fromBuilder(fixtures.buildFailingStartupLayer)
        .provides(.{fx.Logger});

    var graph = fx.layerGraph(std.testing.allocator, .{layer});
    defer graph.deinit();

    try std.testing.expectError(error.ConnectionFailed, graph.start());
}
test "context builder consumes previously started graph services" {
    var logger_env = fixtures.GraphLoggerEnv{ .logger = fx.Logger.init(std.testing.allocator) };
    defer logger_env.logger.deinit();

    var config_env = fixtures.GraphConfigEnv{ .config = fx.Config.init(std.testing.allocator) };
    defer config_env.config.deinit();
    try config_env.config.set("database.dsn", "postgres://graph");

    fixtures.database_layer_builds = 0;
    fixtures.database_layer_released = false;

    const database_layer = fx.LayerWithError(fixtures.DatabaseLayerEnv, fixtures.StartupError)
        .fromContextBuilder(fixtures.buildDatabaseLayerEnv)
        .requires(.{ fx.Config, fx.Logger })
        .provides(.{fixtures.Database});
    const config_layer = fx.Layer(fixtures.GraphConfigEnv)
        .fromEnv(&config_env)
        .provides(.{fx.Config});
    const logger_layer = fx.Layer(fixtures.GraphLoggerEnv)
        .fromEnv(&logger_env)
        .provides(.{fx.Logger});

    var graph = fx.layerGraph(std.testing.allocator, .{ database_layer, config_layer, logger_layer });
    const GraphEnv = @TypeOf(graph).EnvType;
    const Program = fx.Effect([]const u8, fixtures.TestError, GraphEnv)
        .fromFn(struct {
            fn run(ctx: *fx.Context(GraphEnv)) fixtures.TestError![]const u8 {
                const database = ctx.service(fixtures.Database);
                return database.dsn;
            }
        }.run)
        .requires(.{fixtures.Database});

    try std.testing.expectEqualStrings("postgres://graph", try graph.run(Program));
    try std.testing.expectEqual(@as(usize, 1), fixtures.database_layer_builds);
    try std.testing.expectEqualStrings("database layer starting", logger_env.logger.entries.items[0]);
    try std.testing.expect(!fixtures.database_layer_released);

    graph.deinit();
    try std.testing.expect(fixtures.database_layer_released);
}
test "effect backed layer consumes narrowed startup services" {
    var logger_env = fixtures.GraphLoggerEnv{ .logger = fx.Logger.init(std.testing.allocator) };
    defer logger_env.logger.deinit();

    var config_env = fixtures.GraphConfigEnv{ .config = fx.Config.init(std.testing.allocator) };
    defer config_env.config.deinit();
    try config_env.config.set("database.dsn", "postgres://effect-layer");

    fixtures.database_layer_released = false;

    const StartupEnv = fx.ServiceEnv(.{ fx.Config, fx.Logger });
    const database_effect = fx.Effect(
        *fixtures.DatabaseLayerEnv,
        std.mem.Allocator.Error || fixtures.StartupError,
        StartupEnv,
    )
        .fromFn(struct {
            fn run(ctx: *fx.Context(StartupEnv)) (std.mem.Allocator.Error || fixtures.StartupError)!*fixtures.DatabaseLayerEnv {
                const config = ctx.service(fx.Config);
                const logger = ctx.service(fx.Logger);
                try logger.info("database effect layer starting");

                const dsn = config.require("database.dsn") catch return error.ConnectionFailed;
                const env = try ctx.allocator.create(fixtures.DatabaseLayerEnv);
                env.* = .{
                    .allocator = ctx.allocator,
                    .database = .{ .dsn = dsn },
                    .released = &fixtures.database_layer_released,
                };
                ctx.scope.?.addFinalizerFor(fixtures.DatabaseLayerEnv, env, fixtures.releaseDatabaseLayerEnv) catch |err| {
                    fixtures.releaseDatabaseLayerEnv(env);
                    return err;
                };
                return env;
            }
        }.run)
        .requires(.{ fx.Config, fx.Logger });
    const database_layer = fx.LayerWithError(fixtures.DatabaseLayerEnv, fixtures.StartupError)
        .fromEffect(database_effect)
        .provides(.{fixtures.Database});
    const config_layer = fx.Layer(fixtures.GraphConfigEnv)
        .fromEnv(&config_env)
        .provides(.{fx.Config});
    const logger_layer = fx.Layer(fixtures.GraphLoggerEnv)
        .fromEnv(&logger_env)
        .provides(.{fx.Logger});

    var graph = fx.layerGraph(std.testing.allocator, .{ database_layer, config_layer, logger_layer });
    const GraphEnv = @TypeOf(graph).EnvType;
    const Program = fx.Effect([]const u8, fixtures.TestError, GraphEnv)
        .fromFn(struct {
            fn run(ctx: *fx.Context(GraphEnv)) fixtures.TestError![]const u8 {
                const database = ctx.service(fixtures.Database);
                return database.dsn;
            }
        }.run)
        .requires(.{fixtures.Database});

    try std.testing.expectEqualStrings("postgres://effect-layer", try graph.run(Program));
    try std.testing.expectEqualStrings("database effect layer starting", logger_env.logger.entries.items[0]);
    try std.testing.expect(!fixtures.database_layer_released);

    graph.deinit();
    try std.testing.expect(fixtures.database_layer_released);
}
test "effect backed layer receives graph causal context" {
    var store = fx.CausalStore.init(std.testing.allocator);
    defer store.deinit();

    const StartupEnv = fx.ServiceEnv(.{});
    const startup_effect = fx.Effect(
        *fixtures.GraphLoggerEnv,
        std.mem.Allocator.Error || fx.ScopeError,
        StartupEnv,
    )
        .fromFn(struct {
        fn run(ctx: *fx.Context(StartupEnv)) (std.mem.Allocator.Error || fx.ScopeError)!*fixtures.GraphLoggerEnv {
            _ = ctx.recordCausal(.{
                .kind = .assertion_recorded,
                .label = "effect-layer-startup",
                .status = "observed",
            });

            const env = try ctx.allocator.create(fixtures.GraphLoggerEnv);
            env.* = .{ .logger = fx.Logger.init(ctx.allocator) };
            ctx.scope.?.addFinalizerFor(fixtures.GraphLoggerEnv, env, fixtures.releaseGraphLoggerEnv) catch |err| {
                fixtures.releaseGraphLoggerEnv(env);
                return err;
            };
            return env;
        }
    }.run);
    const logger_layer = fx.LayerWithError(fixtures.GraphLoggerEnv, fx.ScopeError)
        .fromEffect(startup_effect)
        .provides(.{fx.Logger});

    var graph = fx.layerGraph(std.testing.allocator, .{logger_layer})
        .withCausalStore(&store);
    defer graph.deinit();

    _ = try graph.start();

    var snapshot = try store.snapshot(std.testing.allocator);
    defer snapshot.deinit();

    _ = try causal.expectEvent(snapshot, .{
        .kind = .assertion_recorded,
        .label = "effect-layer-startup",
        .status = "observed",
    });
}
test "config provider env feeds dependency-injected graph startup" {
    fixtures.database_layer_builds = 0;
    fixtures.database_layer_released = false;

    var logger_env = fixtures.GraphLoggerEnv{ .logger = fx.Logger.init(std.testing.allocator) };
    defer logger_env.logger.deinit();

    var config_env = fx.ConfigEnv.init(std.testing.allocator);
    defer config_env.deinit();
    const entries = [_]fx.ConfigEntry{
        .{ .key = "database.dsn", .value = "postgres://provider" },
    };
    try config_env.config.loadEntries(&entries);

    const database_layer = fx.LayerWithError(fixtures.DatabaseLayerEnv, fixtures.StartupError)
        .fromContextBuilder(fixtures.buildDatabaseLayerEnv)
        .requires(.{ fx.Config, fx.Logger })
        .provides(.{fixtures.Database});
    const config_layer = fx.Layer(fx.ConfigEnv)
        .fromEnv(&config_env)
        .provides(.{fx.Config});
    const logger_layer = fx.Layer(fixtures.GraphLoggerEnv)
        .fromEnv(&logger_env)
        .provides(.{fx.Logger});

    var graph = fx.layerGraph(std.testing.allocator, .{ database_layer, config_layer, logger_layer });
    const GraphEnv = @TypeOf(graph).EnvType;
    const Program = fx.Effect([]const u8, fixtures.TestError, GraphEnv)
        .fromFn(struct {
            fn run(ctx: *fx.Context(GraphEnv)) fixtures.TestError![]const u8 {
                return fixtures.runDatabaseProgram(ctx);
            }
        }.run)
        .requires(.{fixtures.Database});

    try std.testing.expectEqualStrings("postgres://provider", try graph.run(Program));
    graph.deinit();
    try std.testing.expect(fixtures.database_layer_released);
}
test "context builder finalizers belong to graph startup scope" {
    var logger_env = fixtures.GraphLoggerEnv{ .logger = fx.Logger.init(std.testing.allocator) };
    defer logger_env.logger.deinit();

    var config_env = fixtures.GraphConfigEnv{ .config = fx.Config.init(std.testing.allocator) };
    defer config_env.config.deinit();
    try config_env.config.set("database.dsn", "postgres://long-lived");

    fixtures.database_layer_released = false;

    const database_layer = fx.LayerWithError(fixtures.DatabaseLayerEnv, fixtures.StartupError)
        .fromContextBuilder(fixtures.buildDatabaseLayerEnv)
        .requires(.{ fx.Config, fx.Logger })
        .provides(.{fixtures.Database});
    const config_layer = fx.Layer(fixtures.GraphConfigEnv)
        .fromEnv(&config_env)
        .provides(.{fx.Config});
    const logger_layer = fx.Layer(fixtures.GraphLoggerEnv)
        .fromEnv(&logger_env)
        .provides(.{fx.Logger});

    var graph = fx.layerGraph(std.testing.allocator, .{ config_layer, logger_layer, database_layer });
    const GraphEnv = @TypeOf(graph).EnvType;
    const Program = fx.Effect([]const u8, fixtures.TestError, GraphEnv)
        .fromFn(struct {
            fn run(ctx: *fx.Context(GraphEnv)) fixtures.TestError![]const u8 {
                const database = ctx.service(fixtures.Database);
                return database.dsn;
            }
        }.run)
        .requires(.{fixtures.Database});

    try std.testing.expectEqualStrings("postgres://long-lived", try graph.run(Program));
    try std.testing.expect(!fixtures.database_layer_released);

    graph.deinit();
    try std.testing.expect(fixtures.database_layer_released);
}
test "context builder startup failure closes already started dependencies" {
    fixtures.graph_logger_builds = 0;
    fixtures.graph_logger_released = false;

    const logger_layer = fx.Layer(fixtures.GraphLoggerEnv)
        .fromBuilder(fixtures.buildGraphLoggerEnv)
        .provides(.{fx.Logger});
    const database_layer = fx.LayerWithError(fixtures.DatabaseLayerEnv, fixtures.StartupError)
        .fromContextBuilder(fixtures.buildFailingDatabaseLayerEnv)
        .requires(.{fx.Logger})
        .provides(.{fixtures.Database});

    var graph = fx.layerGraph(std.testing.allocator, .{ database_layer, logger_layer });
    defer graph.deinit();

    try std.testing.expectError(error.ConnectionFailed, graph.start());
    try std.testing.expectEqual(@as(usize, 1), fixtures.graph_logger_builds);
    try std.testing.expect(fixtures.graph_logger_released);
}
test "layer graph records startup failure and cleanup causal evidence" {
    fixtures.graph_logger_builds = 0;
    fixtures.graph_logger_released = false;

    var store = fx.CausalStore.init(std.testing.allocator);
    defer store.deinit();

    const logger_layer = fx.Layer(fixtures.GraphLoggerEnv)
        .fromBuilder(fixtures.buildGraphLoggerEnv)
        .provides(.{fx.Logger});
    const database_layer = fx.LayerWithError(fixtures.DatabaseLayerEnv, fixtures.StartupError)
        .fromContextBuilder(fixtures.buildFailingDatabaseLayerEnv)
        .requires(.{fx.Logger})
        .provides(.{fixtures.Database});

    var graph = fx.layerGraph(std.testing.allocator, .{ database_layer, logger_layer })
        .withCausalStore(&store);
    defer graph.deinit();

    try std.testing.expectError(error.ConnectionFailed, graph.start());

    var snapshot = try store.snapshot(std.testing.allocator);
    defer snapshot.deinit();

    _ = try causal.expectEvent(snapshot, .{
        .kind = .layer_completed,
        .label = @typeName(fixtures.GraphLoggerEnv),
        .status = "success",
    });
    _ = try causal.expectEvent(snapshot, .{
        .kind = .layer_started,
        .label = @typeName(fixtures.DatabaseLayerEnv),
        .status = "starting",
    });
    _ = try causal.expectEvent(snapshot, .{
        .kind = .exit_recorded,
        .label = @typeName(fixtures.DatabaseLayerEnv),
        .type_name = "ConnectionFailed",
        .status = "failure",
    });
    _ = try causal.expectEvent(snapshot, .{
        .kind = .resource_finalized,
        .type_name = @typeName(fixtures.GraphLoggerEnv),
        .status = "success",
    });
    _ = try causal.expectEvent(snapshot, .{
        .kind = .scope_closed,
        .status = "failure",
    });
    try std.testing.expect(fixtures.graph_logger_released);
}
test "graph started environments run through regular runtime" {
    var logger_env = fixtures.GraphLoggerEnv{ .logger = fx.Logger.init(std.testing.allocator) };
    defer logger_env.logger.deinit();

    var config_env = fixtures.GraphConfigEnv{ .config = fx.Config.init(std.testing.allocator) };
    defer config_env.config.deinit();
    try config_env.config.set("database.dsn", "postgres://runtime");

    fixtures.database_layer_released = false;

    const database_layer = fx.LayerWithError(fixtures.DatabaseLayerEnv, fixtures.StartupError)
        .fromContextBuilder(fixtures.buildDatabaseLayerEnv)
        .requires(.{ fx.Config, fx.Logger })
        .provides(.{fixtures.Database});
    const config_layer = fx.Layer(fixtures.GraphConfigEnv)
        .fromEnv(&config_env)
        .provides(.{fx.Config});
    const logger_layer = fx.Layer(fixtures.GraphLoggerEnv)
        .fromEnv(&logger_env)
        .provides(.{fx.Logger});

    {
        var graph = fx.layerGraph(std.testing.allocator, .{ database_layer, config_layer, logger_layer });
        defer graph.deinit();

        const GraphEnv = @TypeOf(graph).EnvType;
        const Program = fx.Effect([]const u8, fixtures.TestError, GraphEnv)
            .fromFn(struct {
                fn run(ctx: *fx.Context(GraphEnv)) fixtures.TestError![]const u8 {
                    const database = ctx.service(fixtures.Database);
                    return database.dsn;
                }
            }.run)
            .requires(.{fixtures.Database});

        var runtime = try graph.runtime();
        try std.testing.expectEqualStrings("postgres://runtime", try runtime.run(Program));
        try std.testing.expect(!fixtures.database_layer_released);
    }

    try std.testing.expect(fixtures.database_layer_released);
}
test "graph runtime adapters propagate causal store" {
    var env = try fx.TestEnv.init(std.testing.allocator);
    defer env.deinit();

    var store = fx.CausalStore.init(std.testing.allocator);
    defer store.deinit();

    var graph = fx.layerGraph(std.testing.allocator, .{
        env.layer().provides(.{ fx.Logger, fx.Config, fx.Metrics, fx.Tracing, fx.MemoryFileSystem, fx.Clock }),
    }).withCausalStore(&store);
    defer graph.deinit();

    const GraphEnv = @TypeOf(graph).EnvType;
    const RuntimeProgram = fx.Effect([]const u8, fixtures.TestError, GraphEnv).succeed("runtime");
    var runtime = try graph.runtime();
    try std.testing.expectEqualStrings("runtime", try runtime.run(RuntimeProgram));

    const FiberProgram = fx.Effect([]const u8, fixtures.TestError, GraphEnv).succeed("fiber");
    var fiber_runtime = try graph.fiberRuntime();
    defer fiber_runtime.deinit();
    const fiber = try fiber_runtime.fork(FiberProgram);
    const exit = fiber_runtime.join(fiber);
    switch (exit) {
        .success => |value| try std.testing.expectEqualStrings("fiber", value),
        else => return error.Empty,
    }

    var snapshot = try store.snapshot(std.testing.allocator);
    defer snapshot.deinit();

    _ = try causal.expectEvent(snapshot, .{
        .kind = .run_started,
        .label = "Runtime.run",
    });
    _ = try causal.expectEvent(snapshot, .{
        .kind = .fiber_forked,
        .status = "pending",
    });
}
test "graph runtime runs effects against a narrowed service environment" {
    var logger_env = fixtures.GraphLoggerEnv{ .logger = fx.Logger.init(std.testing.allocator) };
    defer logger_env.logger.deinit();

    var config_env = fixtures.GraphConfigEnv{ .config = fx.Config.init(std.testing.allocator) };
    defer config_env.config.deinit();
    try config_env.config.set("database.dsn", "postgres://narrowed");

    fixtures.database_layer_released = false;

    const database_layer = fx.LayerWithError(fixtures.DatabaseLayerEnv, fixtures.StartupError)
        .fromContextBuilder(fixtures.buildDatabaseLayerEnv)
        .requires(.{ fx.Config, fx.Logger })
        .provides(.{fixtures.Database});
    const config_layer = fx.Layer(fixtures.GraphConfigEnv)
        .fromEnv(&config_env)
        .provides(.{fx.Config});
    const logger_layer = fx.Layer(fixtures.GraphLoggerEnv)
        .fromEnv(&logger_env)
        .provides(.{fx.Logger});

    var graph = fx.layerGraph(std.testing.allocator, .{ database_layer, config_layer, logger_layer });
    const DatabaseOnlyEnv = fx.ServiceEnv(.{fixtures.Database});
    const Program = fx.Effect([]const u8, fixtures.TestError, DatabaseOnlyEnv)
        .fromFn(struct {
            fn run(ctx: *fx.Context(DatabaseOnlyEnv)) fixtures.TestError![]const u8 {
                const database = ctx.service(fixtures.Database);
                return database.dsn;
            }
        }.run)
        .requires(.{fixtures.Database});

    try std.testing.expectEqualStrings(
        "postgres://narrowed",
        try graph.runNarrowed(.{fixtures.Database}, Program),
    );
    const narrowed_exit = graph.exitNarrowed(.{fixtures.Database}, Program);
    switch (narrowed_exit) {
        .success => |dsn| try std.testing.expectEqualStrings("postgres://narrowed", dsn),
        else => return error.Empty,
    }
    try std.testing.expect(!fixtures.database_layer_released);

    graph.deinit();
    try std.testing.expect(fixtures.database_layer_released);
}
test "graph narrowed runtime paths propagate causal store" {
    var env = try fx.TestEnv.init(std.testing.allocator);
    defer env.deinit();

    var store = fx.CausalStore.init(std.testing.allocator);
    defer store.deinit();

    var graph = fx.layerGraph(std.testing.allocator, .{
        env.layer().provides(.{ fx.Logger, fx.Config, fx.Metrics, fx.Tracing, fx.MemoryFileSystem, fx.Clock }),
    }).withCausalStore(&store);
    defer graph.deinit();

    const LoggerOnly = fx.ServiceEnv(.{fx.Logger});
    const Program = fx.Effect([]const u8, fixtures.TestError, LoggerOnly)
        .succeed("narrowed")
        .requires(.{fx.Logger});

    try std.testing.expectEqualStrings("narrowed", try graph.runNarrowed(.{fx.Logger}, Program));
    const exit = graph.exitNarrowed(.{fx.Logger}, Program);
    switch (exit) {
        .success => |value| try std.testing.expectEqualStrings("narrowed", value),
        else => return error.Empty,
    }

    var snapshot = try store.snapshot(std.testing.allocator);
    defer snapshot.deinit();

    _ = try causal.expectEvent(snapshot, .{
        .kind = .run_started,
        .label = "LayerGraphRuntime.runNarrowed",
    });
    _ = try causal.expectEvent(snapshot, .{
        .kind = .run_started,
        .label = "LayerGraphRuntime.exitNarrowed",
    });
}
test "graph runtime propagates trace context into effect context" {
    var env = try fx.TestEnv.init(std.testing.allocator);
    defer env.deinit();

    var graph = fx.layerGraph(std.testing.allocator, .{
        env.layer().provides(.{ fx.Logger, fx.Config, fx.Metrics, fx.Tracing, fx.MemoryFileSystem, fx.Clock }),
    }).withTraceContext(505, 606);
    defer graph.deinit();

    const GraphEnv = @TypeOf(graph).EnvType;
    const Program = fx.Effect(void, fixtures.TestError, GraphEnv)
        .fromFn(struct {
            fn run(ctx: *fx.Context(GraphEnv)) fixtures.TestError!void {
                const logger = ctx.service(fx.Logger);
                try logger.logWithContext(.info, "graph trace context", &.{}, .{
                    .trace_id = ctx.trace_id,
                    .span_id = ctx.span_id,
                });
            }
        }.run)
        .requires(.{fx.Logger});

    try graph.run(Program);

    const entry = env.services.logger.structured_entries.items[0];
    try std.testing.expectEqual(@as(?u64, 505), entry.trace_id);
    try std.testing.expectEqual(@as(?u64, 606), entry.span_id);
}
test "graph started environments run through fiber runtime" {
    var logger_env = fixtures.GraphLoggerEnv{ .logger = fx.Logger.init(std.testing.allocator) };
    defer logger_env.logger.deinit();

    var config_env = fixtures.GraphConfigEnv{ .config = fx.Config.init(std.testing.allocator) };
    defer config_env.config.deinit();
    try config_env.config.set("database.dsn", "postgres://fiber");

    fixtures.database_layer_released = false;

    const database_layer = fx.LayerWithError(fixtures.DatabaseLayerEnv, fixtures.StartupError)
        .fromContextBuilder(fixtures.buildDatabaseLayerEnv)
        .requires(.{ fx.Config, fx.Logger })
        .provides(.{fixtures.Database});
    const config_layer = fx.Layer(fixtures.GraphConfigEnv)
        .fromEnv(&config_env)
        .provides(.{fx.Config});
    const logger_layer = fx.Layer(fixtures.GraphLoggerEnv)
        .fromEnv(&logger_env)
        .provides(.{fx.Logger});

    {
        var graph = fx.layerGraph(std.testing.allocator, .{ database_layer, config_layer, logger_layer });
        defer graph.deinit();

        const GraphEnv = @TypeOf(graph).EnvType;
        const Program = fx.Effect([]const u8, fixtures.TestError, GraphEnv)
            .fromFn(struct {
                fn run(ctx: *fx.Context(GraphEnv)) fixtures.TestError![]const u8 {
                    const database = ctx.service(fixtures.Database);
                    return database.dsn;
                }
            }.run)
            .requires(.{fixtures.Database});

        var fiber_runtime = try graph.fiberRuntime();
        defer fiber_runtime.deinit();

        const fiber = try fiber_runtime.fork(Program);
        const exit = fiber_runtime.join(fiber);
        switch (exit) {
            .success => |dsn| try std.testing.expectEqualStrings("postgres://fiber", dsn),
            else => return error.Empty,
        }
        try std.testing.expect(!fixtures.database_layer_released);
    }

    try std.testing.expect(fixtures.database_layer_released);
}
test "graph backed scoped fibers do not release startup resources on parent close" {
    var logger_env = fixtures.GraphLoggerEnv{ .logger = fx.Logger.init(std.testing.allocator) };
    defer logger_env.logger.deinit();

    var config_env = fixtures.GraphConfigEnv{ .config = fx.Config.init(std.testing.allocator) };
    defer config_env.config.deinit();
    try config_env.config.set("database.dsn", "postgres://scoped-fiber");

    fixtures.database_layer_released = false;

    const database_layer = fx.LayerWithError(fixtures.DatabaseLayerEnv, fixtures.StartupError)
        .fromContextBuilder(fixtures.buildDatabaseLayerEnv)
        .requires(.{ fx.Config, fx.Logger })
        .provides(.{fixtures.Database});
    const config_layer = fx.Layer(fixtures.GraphConfigEnv)
        .fromEnv(&config_env)
        .provides(.{fx.Config});
    const logger_layer = fx.Layer(fixtures.GraphLoggerEnv)
        .fromEnv(&logger_env)
        .provides(.{fx.Logger});

    {
        var graph = fx.layerGraph(std.testing.allocator, .{ database_layer, config_layer, logger_layer });
        defer graph.deinit();

        const GraphEnv = @TypeOf(graph).EnvType;
        const Program = fx.Effect([]const u8, fixtures.TestError, GraphEnv)
            .fromFn(struct {
                fn run(ctx: *fx.Context(GraphEnv)) fixtures.TestError![]const u8 {
                    const database = ctx.service(fixtures.Database);
                    return database.dsn;
                }
            }.run)
            .requires(.{fixtures.Database});

        var fiber_runtime = try graph.fiberRuntime();
        defer fiber_runtime.deinit();

        var parent_scope = fx.Scope.init(std.testing.allocator);
        defer parent_scope.deinit();
        var ctx = fiber_runtime.context(&parent_scope);
        const fiber = try fiber_runtime.forkScoped(&ctx, Program);

        parent_scope.closeWithExit(.success);

        const exit = fiber_runtime.join(fiber);
        switch (exit) {
            .interrupted => |id| try std.testing.expectEqual(fiber.id, id),
            else => return error.Empty,
        }
        try std.testing.expect(!fixtures.database_layer_released);
    }

    try std.testing.expect(fixtures.database_layer_released);
}
test "graph startup scope interrupts fibers started by graph services" {
    var logger_env = fixtures.GraphLoggerEnv{ .logger = fx.Logger.init(std.testing.allocator) };
    defer logger_env.logger.deinit();

    const fiber_layer = fx.LayerWithError(fixtures.GraphFiberEnv, fixtures.GraphFiberStartupError)
        .fromContextBuilder(fixtures.buildGraphFiberEnv)
        .requires(.{fx.Logger})
        .provides(.{fixtures.GraphFiberService});
    const logger_layer = fx.Layer(fixtures.GraphLoggerEnv)
        .fromEnv(&logger_env)
        .provides(.{fx.Logger});

    var graph = fx.layerGraph(std.testing.allocator, .{ fiber_layer, logger_layer });
    errdefer graph.deinit();

    _ = try graph.start();
    try std.testing.expect(!fixtures.graph_fiber_released);
    try std.testing.expectEqual(fx.FiberStatus.pending, fixtures.graph_fiber_status_on_release);

    graph.deinit();

    try std.testing.expect(fixtures.graph_fiber_released);
    try std.testing.expectEqual(fx.FiberStatus.interrupted, fixtures.graph_fiber_status_on_release);
}
test "compile fail fixture captures missing service diagnostics" {
    try expectCompileFailDiagnostic("missing_service.zig", ".zig-cache/missing_service_compile_fail.txt", "zigeffect service not found");
    try expectCompileFailDiagnostic("missing_service.zig", ".zig-cache/missing_service_compile_fail.txt", @typeName(fx.Config));
    try expectCompileFailDiagnostic("missing_service.zig", ".zig-cache/missing_service_compile_fail.txt", "Add a branch to the environment service method");
}
test "compile fail fixture captures malformed service tuple diagnostics" {
    try expectCompileFailDiagnostic(
        "invalid_service_tuple.zig",
        ".zig-cache/invalid_service_tuple_compile_fail.txt",
        "zigeffect service tuple entries must be types",
    );
}
test "compile fail fixture captures invalid effect function diagnostics" {
    try expectCompileFailDiagnostic(
        "invalid_effect_function.zig",
        ".zig-cache/invalid_effect_function_compile_fail.txt",
        "zigeffect invalid effect function",
    );
}
test "compile fail fixture captures invalid layer merge diagnostics" {
    try expectCompileFailDiagnostic(
        "invalid_layer_merge.zig",
        ".zig-cache/invalid_layer_merge_compile_fail.txt",
        "zigeffect invalid layer merge function",
    );
}
test "compile fail fixture captures invalid resource error set diagnostics" {
    try expectCompileFailDiagnostic(
        "invalid_resource_error_set.zig",
        ".zig-cache/invalid_resource_error_set_compile_fail.txt",
        "zigeffect resource failure set",
    );
}
test "compile fail fixture captures static requirement diagnostics" {
    try expectCompileFailDiagnostic(
        "invalid_static_requirements.zig",
        ".zig-cache/invalid_static_requirements_compile_fail.txt",
        "zigeffect static requirements not satisfied",
    );
}
test "compile fail fixture captures layer environment mismatch diagnostics" {
    try expectCompileFailDiagnostic(
        "mismatched_layer_environment.zig",
        ".zig-cache/mismatched_layer_environment_compile_fail.txt",
        "zigeffect environment mismatch",
    );
    try expectCompileFailDiagnostic(
        "mismatched_layer_environment.zig",
        ".zig-cache/mismatched_layer_environment_compile_fail.txt",
        "api: Layer.provide",
    );
}
test "compile fail fixture captures runtime environment mismatch diagnostics" {
    try expectCompileFailDiagnostic(
        "mismatched_runtime_environment.zig",
        ".zig-cache/mismatched_runtime_environment_compile_fail.txt",
        "zigeffect environment mismatch",
    );
    try expectCompileFailDiagnostic(
        "mismatched_runtime_environment.zig",
        ".zig-cache/mismatched_runtime_environment_compile_fail.txt",
        "api: Runtime.run",
    );
}
test "compile fail fixture captures fiber environment mismatch diagnostics" {
    try expectCompileFailDiagnostic(
        "mismatched_fiber_environment.zig",
        ".zig-cache/mismatched_fiber_environment_compile_fail.txt",
        "zigeffect environment mismatch",
    );
    try expectCompileFailDiagnostic(
        "mismatched_fiber_environment.zig",
        ".zig-cache/mismatched_fiber_environment_compile_fail.txt",
        "api: FiberRuntime.fork",
    );
}
test "compile fail fixture captures match missing handler diagnostics" {
    try expectCompileFailDiagnostic(
        "match_missing_handler.zig",
        ".zig-cache/match_missing_handler_compile_fail.txt",
        "zigeffect match exhaustive missing handler for tag 'failed'",
    );
}
test "compile fail fixture captures match unknown handler diagnostics" {
    try expectCompileFailDiagnostic(
        "match_unknown_handler.zig",
        ".zig-cache/match_unknown_handler_compile_fail.txt",
        "zigeffect match handler 'done' is not a tag",
    );
}
test "compile fail fixture captures match return diagnostics" {
    try expectCompileFailDiagnostic(
        "match_wrong_return.zig",
        ".zig-cache/match_wrong_return_compile_fail.txt",
        "zigeffect match handler return mismatch",
    );
}
test "compile fail fixture captures match payload diagnostics" {
    try expectCompileFailDiagnostic(
        "match_wrong_payload.zig",
        ".zig-cache/match_wrong_payload_compile_fail.txt",
        "zigeffect match handler payload mismatch",
    );
}
test "compile fail fixture captures duplicate pattern capture diagnostics" {
    try expectCompileFailDiagnostic(
        "pattern_duplicate_capture.zig",
        ".zig-cache/pattern_duplicate_capture_compile_fail.txt",
        "zigeffect pattern duplicate capture 'same'",
    );
}
test "compile fail fixture captures missing pattern arm diagnostics" {
    try expectCompileFailDiagnostic(
        "pattern_missing_union_tag.zig",
        ".zig-cache/pattern_missing_union_tag_compile_fail.txt",
        "zigeffect pattern exhaustive missing arm for tag 'score'",
    );
}
test "compile fail fixture captures unknown pattern arm diagnostics" {
    try expectCompileFailDiagnostic(
        "pattern_unknown_union_tag.zig",
        ".zig-cache/pattern_unknown_union_tag_compile_fail.txt",
        "zigeffect pattern arm 'score' is not a tag",
    );
}
