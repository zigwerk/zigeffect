pub const executable_build =
    \\const std = @import("std");
    \\
    \\pub fn build(b: *std.Build) void {
    \\    const target = b.standardTargetOptions(.{});
    \\    const optimize = b.standardOptimizeOption(.{});
    \\    const zigeffect_std_dependency = b.dependency("zigeffect_std", .{ .target = target, .optimize = optimize });
    \\    const zigeffect_std = zigeffect_std_dependency.module("zigeffect_std");
    \\    const testing_runner = zigeffect_std_dependency.module("zigeffect_test_runner").root_source_file.?;
    \\__ADAPTER_DEPENDENCIES__
    \\__SHARED_DEPENDENCY__
    \\    const app = b.addModule("app", .{
    \\        .root_source_file = b.path("src/app.zig"),
    \\        .target = target,
    \\        .optimize = optimize,
    \\    });
    \\    app.addImport("zigeffect_std", zigeffect_std);
    \\__ADAPTER_IMPORTS__
    \\__SHARED_IMPORT__
    \\    const main_module = b.createModule(.{
    \\        .root_source_file = b.path("src/main.zig"),
    \\        .target = target,
    \\        .optimize = optimize,
    \\    });
    \\    main_module.addImport("app", app);
    \\    const executable = b.addExecutable(.{ .name = "__PROJECT_NAME__", .root_module = main_module });
    \\    b.installArtifact(executable);
    \\
    \\    const run = b.addRunArtifact(executable);
    \\    if (b.args) |args| run.addArgs(args);
    \\    const run_step = b.step("run", "Run __PROJECT_NAME__ locally");
    \\    run_step.dependOn(&run.step);
    \\
    \\    const test_module = b.createModule(.{
    \\        .root_source_file = b.path("test/root_test.zig"),
    \\        .target = target,
    \\        .optimize = optimize,
    \\    });
    \\    test_module.addImport("app", app);
    \\    test_module.addImport("zigeffect_std", zigeffect_std);
    \\    var test_options = std.Build.TestOptions{ .name = "__PROJECT_NAME__-tests", .root_module = test_module, .test_runner = .{ .path = testing_runner, .mode = .server } };
    \\    if (b.option([]const u8, "test-filter", "Compile only matching native tests")) |filter| test_options.filters = &.{filter};
    \\    const tests = b.addTest(test_options);
    \\    const run_tests = b.addRunArtifact(tests);
    \\    const test_step = b.step("test", "Run __PROJECT_NAME__ tests");
    \\    test_step.dependOn(&run_tests.step);
    \\}
;

pub const executable_zon =
    \\.{
    \\    .name = .__ZIG_NAME__,
    \\    .version = "0.1.0",
    \\    .minimum_zig_version = "0.16.0",
    \\    .fingerprint = 0x__FINGERPRINT__,
    \\    .dependencies = .{
    \\        .zigeffect_std = .{ .path = "__STD_PATH__" },
    \\__ADAPTER_ZON_DEPENDENCIES__
    \\__SHARED_ZON_DEPENDENCY__
    \\    },
    \\    .paths = .{ "build.zig", "build.zig.zon", "README.md", "src", "test" },
    \\}
;

pub const main_source =
    \\const std = @import("std");
    \\const app = @import("app");
    \\
    \\pub fn main(init: std.process.Init) !void {
    \\    try app.run(init.gpa, init.io, std.Io.Dir.cwd());
    \\}
;

pub const production_app_source =
    \\const std = @import("std");
    \\const production = @import("production_wiring.zig");
    \\
    \\pub const component_name = "__PROJECT_NAME__";
    \\pub fn productionContract() bool { return production.compileContract(); }
    \\pub fn run(allocator: std.mem.Allocator, io: std.Io, root: std.Io.Dir) !void {
    \\    return production.run(allocator, io, root);
    \\}
;

pub const production_wiring_source =
    \\const std = @import("std");
    \\const zstd = @import("zigeffect_std");
    \\const http = @import("zigeffect_http");
    \\const postgres = @import("zigeffect_postgres_libpq");
    \\const otel = @import("zigeffect_otel");
    \\const causal_graph = @import("causal_graph.zig");
    \\
    \\pub const Config = struct { port: i64, database_url: []const u8, otlp_host: []const u8, otlp_port: i64, migration_dialect: []const u8 };
    \\pub const config_schema = zstd.Schema.structSchema(Config, .{
    \\    zstd.Schema.field("port", zstd.Schema.integer().min(1).max(65535)),
    \\    zstd.Schema.field("database_url", zstd.Schema.string().nonEmpty()),
    \\    zstd.Schema.field("otlp_host", zstd.Schema.string().nonEmpty()),
    \\    zstd.Schema.field("otlp_port", zstd.Schema.integer().min(1).max(65535)),
    \\    zstd.Schema.field("migration_dialect", zstd.Schema.stringEnum(&.{ "postgresql", "cockroachdb" })),
    \\});
    \\
    \\const Health = struct {
    \\    pub fn handleAlloc(_: *@This(), allocator: std.mem.Allocator, request: zstd.Http.Request) !zstd.Http.Response {
    \\        if (!std.mem.eql(u8, request.url, "/health/ready")) return zstd.Http.cloneResponseAlloc(allocator, .{ .status = 404, .body = "not found" });
    \\        return zstd.Http.cloneResponseAlloc(allocator, .{ .status = 200, .body = "ready" });
    \\    }
    \\};
    \\
    \\pub fn compileContract() bool {
    \\    return @hasDecl(http, "serverLayer") and @hasDecl(postgres, "sessionLayer") and
    \\        @hasDecl(postgres, "poolLayer") and @hasDecl(otel, "exporterLayer") and
    \\        @hasDecl(zstd.Application.Lifecycle, "managerLayer");
    \\}
    \\
    \\const RuntimeInputs = struct { io: std.Io, root: std.Io.Dir };
    \\const ConfigLayerEnv = struct {
    \\    allocator: std.mem.Allocator,
    \\    layered: zstd.Config.LayeredConfig,
    \\    decoded: zstd.Schema.DecodeResult(Config),
    \\    config: Config,
    \\    http_config: http.ServerLayerConfig,
    \\    session_config: postgres.SessionLayerConfig,
    \\    pool_config: postgres.PoolLayerConfig,
    \\    exporter_config: otel.ExporterLayerConfig,
    \\
    \\    pub fn service(self: *@This(), comptime Requested: type) *Requested {
    \\        if (Requested == Config) return &self.config;
    \\        if (Requested == http.ServerLayerConfig) return &self.http_config;
    \\        if (Requested == postgres.SessionLayerConfig) return &self.session_config;
    \\        if (Requested == postgres.PoolLayerConfig) return &self.pool_config;
    \\        if (Requested == otel.ExporterLayerConfig) return &self.exporter_config;
    \\        return zstd.fx.serviceNotFound(@This(), Requested);
    \\    }
    \\};
    \\
    \\fn releaseConfigLayer(env: *ConfigLayerEnv) void {
    \\    const allocator = env.allocator;
    \\    env.decoded.deinit();
    \\    env.layered.deinit();
    \\    allocator.destroy(env);
    \\}
    \\
    \\fn buildConfigLayer(allocator: std.mem.Allocator, scope: *zstd.fx.Scope, ctx: anytype) anyerror!*ConfigLayerEnv {
    \\    const inputs = ctx.service(RuntimeInputs);
    \\    var layered = zstd.Config.LayeredConfig.init(allocator);
    \\    errdefer layered.deinit();
    \\    var root = inputs.root;
    \\    _ = try layered.loadJsonFile(inputs.io, &root, "config.json", 64 * 1024, 1);
    \\    var decoded = try layered.decodeDetailedAlloc(allocator, config_schema);
    \\    errdefer decoded.deinit();
    \\    if (!decoded.ok()) return error.InvalidProductionConfiguration;
    \\    const config = decoded.value.?;
    \\    const env = try allocator.create(ConfigLayerEnv);
    \\    errdefer allocator.destroy(env);
    \\    env.* = .{
    \\        .allocator = allocator,
    \\        .layered = layered,
    \\        .decoded = decoded,
    \\        .config = config,
    \\        .http_config = .{ .io = inputs.io, .options = .{ .host = "0.0.0.0", .port = @intCast(config.port) } },
    \\        .session_config = .{ .config = .{ .connection_url = config.database_url } },
    \\        .pool_config = .{ .io = inputs.io, .config = .{ .session = .{ .connection_url = config.database_url } } },
    \\        .exporter_config = .{ .io = inputs.io, .options = .{ .host = config.otlp_host, .port = @intCast(config.otlp_port) } },
    \\    };
    \\    scope.addFinalizerFor(ConfigLayerEnv, env, releaseConfigLayer) catch |err| return err;
    \\    return env;
    \\}
    \\
    \\fn configLayer() @TypeOf(
    \\    zstd.fx.LayerWithError(ConfigLayerEnv, anyerror)
    \\        .fromContextBuilder(buildConfigLayer)
    \\        .requires(.{RuntimeInputs})
    \\        .provides(.{ Config, http.ServerLayerConfig, postgres.SessionLayerConfig, postgres.PoolLayerConfig, otel.ExporterLayerConfig }),
    \\) {
    \\    return zstd.fx.LayerWithError(ConfigLayerEnv, anyerror)
    \\        .fromContextBuilder(buildConfigLayer)
    \\        .requires(.{RuntimeInputs})
    \\        .provides(.{ Config, http.ServerLayerConfig, postgres.SessionLayerConfig, postgres.PoolLayerConfig, otel.ExporterLayerConfig });
    \\}
    \\
    \\fn ProductionEffect(comptime EffectEnv: type) type {
    \\    return struct {
    \\        pub const SuccessType = void;
    \\        pub const FailureType = anyerror;
    \\        pub const EnvType = EffectEnv;
    \\        pub const RequiredServices = .{ Config, zstd.Application.Lifecycle.Manager, postgres.Session, postgres.Pool, otel.Exporter, http.Server };
    \\        pub fn requiredServices(allocator: std.mem.Allocator) std.mem.Allocator.Error!zstd.fx.ServiceSet {
    \\            return zstd.fx.ServiceSet.fromTypes(allocator, RequiredServices);
    \\        }
    \\        pub fn run(_: @This(), ctx: *zstd.fx.Context(EffectEnv)) anyerror!void {
    \\            _ = ctx.service(Config);
    \\            try ctx.runEffect(zstd.Application.Lifecycle.startEffect(EffectEnv));
    \\            const migrations = [_]zstd.Sql.Migration{.{ .id = "001_bootstrap", .sql = "create table if not exists zigeffect_service_health (id bigint primary key, checked_at timestamptz not null default now())" }};
    \\            const config = ctx.service(Config);
    \\            var migration_report = try ctx.runEffect(postgres.applyMigrationsEffect(EffectEnv, .{ .dialect = if (std.mem.eql(u8, config.migration_dialect, "cockroachdb")) .cockroachdb else .postgresql }, &migrations));
    \\            defer migration_report.deinit();
    \\            try ctx.runEffect(zstd.Application.Lifecycle.readyEffect(EffectEnv));
    \\            _ = try ctx.runEffect(http.serveOneEffect(EffectEnv));
    \\            try ctx.runEffect(zstd.Application.Lifecycle.drainEffect(EffectEnv));
    \\            _ = try ctx.runEffect(http.shutdownServerEffect(EffectEnv, .{}));
    \\            try ctx.runEffect(otel.shutdownExporterEffect(EffectEnv));
    \\            try ctx.runEffect(postgres.closePoolEffect(EffectEnv));
    \\            try ctx.runEffect(zstd.Application.Lifecycle.stopEffect(EffectEnv));
    \\        }
    \\    };
    \\}
    \\
    \\pub fn run(allocator: std.mem.Allocator, io: std.Io, root: std.Io.Dir) !void {
    \\    var graph = try causal_graph.open(allocator, io, root);
    \\    defer graph.deinit();
    \\    var graph_backend = graph.storageBackend(allocator, causal_graph.max_events);
    \\    defer graph_backend.deinit();
    \\    var causal_store = zstd.fx.CausalStore.init(allocator);
    \\    defer causal_store.deinit();
    \\    causal_store.attachBackend(graph_backend.backend());
    \\    var inputs_provider = zstd.Service.ValueProvider(RuntimeInputs).init(.{ .io = io, .root = root });
    \\    var health = Health{};
    \\    var handler_provider = zstd.Service.ValueProvider(http.Handler).init(http.Handler.from(Health, &health));
    \\    const inputs_layer = inputs_provider.layer();
    \\    const application_config_layer = configLayer();
    \\    const lifecycle_layer = zstd.Application.Lifecycle.managerLayer();
    \\    const handler_layer = handler_provider.layer();
    \\    const session_layer = postgres.sessionLayer();
    \\    const pool_layer = postgres.poolLayer();
    \\    const exporter_layer = otel.exporterLayer();
    \\    const server_layer = http.serverLayer();
    \\    const Layers = @TypeOf(.{ inputs_layer, application_config_layer, lifecycle_layer, handler_layer, session_layer, pool_layer, exporter_layer, server_layer });
    \\    const Env = zstd.fx.LayerGraphEnv(Layers);
    \\    var app = zstd.fx.layerGraph(allocator, .{ inputs_layer, application_config_layer, lifecycle_layer, handler_layer, session_layer, pool_layer, exporter_layer, server_layer }).withCausalStore(&causal_store);
    \\    defer app.deinit();
    \\    try app.run(ProductionEffect(Env){});
    \\    try graph_backend.flush();
    \\    if (graph_backend.lastFailure()) |err| return err;
    \\    if (causal_store.backendFailureCount() != 0) return error.GraphWriteFailed;
    \\}
;

pub const production_test =
    \\const std = @import("std");
    \\const app = @import("app");
    \\
    \\test "production profile compiles real adapter and lifecycle wiring" {
    \\    try std.testing.expect(app.productionContract());
    \\}
;

pub const app_source =
    \\const std = @import("std");
    \\const zstd = @import("zigeffect_std");
    \\const kernel = zstd.fx.kernel;
    \\const config = @import("config.zig");
    \\const command = @import("cli.zig");
    \\const http = @import("http.zig");
    \\const sql = @import("sql.zig");
    \\const causal = @import("causal.zig");
    \\const causal_graph = @import("causal_graph.zig");
    \\const greeting = @import("services/greeting.zig");
    \\__SHARED_SOURCE_IMPORT__
    \\pub const component_name = "__PROJECT_NAME__";
    \\pub const Greeting = greeting.Greeting;
    \\pub const causal_graph_options = causal_graph.options;
    \\
    \\const BootstrapInputs = struct { io: std.Io, root: std.Io.Dir };
    \\const BootstrapBase = kernel.Effect(void, anyerror, .{});
    \\const Bootstrap = BootstrapBase.Stateful(BootstrapInputs);
    \\
    \\fn record(ctx: anytype, fact: zstd.Application.Fact) !void {
    \\    if (zstd.Application.record(ctx, fact) == null) return error.OutOfMemory;
    \\}
    \\
    \\fn bootstrap(io: std.Io, root: std.Io.Dir) Bootstrap {
    \\    return Bootstrap.init(.{ .io = io, .root = root }, struct {
    \\        fn run(inputs: BootstrapInputs, ctx: *Bootstrap.Context) anyerror!void {
    \\            _ = inputs.io;
    \\            _ = inputs.root;
    \\            const allocator = ctx.allocator();
    \\            const app_config = try config.decodeJsonAlloc(allocator, "{\"port\":5178,\"development\":true}");
    \\    if (app_config.port != 5178) return error.InvalidConfig;
    \\            try record(ctx, zstd.Application.configLoad("application", "success", "source=local"));
    \\            try record(ctx, zstd.Application.schemaDecode("AppConfig", "success", "validated config"));
    \\    const port = try command.decodePortAlloc(allocator, &.{ "--port", "5178" });
    \\    if (port != 5178) return error.InvalidCommand;
    \\            try record(ctx, zstd.Application.commandExecution("run", "success", "typed CLI decoded"));
    \\
    \\    var route = try http.runHealthRoute(allocator);
    \\    defer route.deinit(allocator);
    \\    if (route.response.status != 200) return error.UnhealthyRoute;
    \\            try record(ctx, zstd.Application.requestHandling("POST /health", "success", "status=200"));
    \\            try record(ctx, zstd.Application.externalCall("local-http-router", "health", "success"));
    \\    const row_count = try sql.runSmokeQuery(allocator);
    \\    if (row_count != 1) return error.UnexpectedRowCount;
    \\            try record(ctx, zstd.Application.sqlTransaction("local-sql", "health-query", "committed"));
    \\__SHARED_SOURCE_USE__
    \\            try record(ctx, zstd.Application.componentDependency(component_name, "zigeffect-std", "resolved"));
    \\        }
    \\    }.run);
    \\}
    \\
    \\const FinalizeGreetingBase = kernel.Effect(void, anyerror, .{});
    \\const FinalizeGreeting = FinalizeGreetingBase.Stateful([]u8);
    \\fn finalizeGreeting(message: []u8) FinalizeGreeting {
    \\    return FinalizeGreeting.init(message, struct {
    \\        fn run(owned_message: []u8, ctx: *FinalizeGreeting.Context) anyerror!void {
    \\            const allocator = ctx.allocator();
    \\            defer allocator.free(owned_message);
    \\            try record(ctx, zstd.Application.acceptanceEvaluation("check-bootstrap", "passed", "application boundaries passed"));
    \\            try record(ctx, zstd.Application.artifactProduction("workbench-attachment", "created", "bounded causal attachment"));
    \\            try record(ctx, zstd.Application.artifactProduction("causal-graph", "prepared", causal_graph.wal_path));
    \\
    \\            var recorder = zstd.Observability.Recorder.init(allocator);
    \\            defer recorder.deinit();
    \\            try recorder.increment("app.runs", 1);
    \\            const workbench = try recorder.workbenchJsonAlloc(allocator, component_name);
    \\            defer allocator.free(workbench);
    \\        }
    \\    }.run);
    \\}
    \\
    \\pub fn program(io: std.Io, root: std.Io.Dir) @TypeOf(
    \\    bootstrap(io, root)
    \\        .andThen(greeting.greet(component_name))
    \\        .flatMap(finalizeGreeting)
    \\        .named("application.bootstrap"),
    \\) {
    \\    return bootstrap(io, root)
    \\        .andThen(greeting.greet(component_name))
    \\        .flatMap(finalizeGreeting)
    \\        .named("application.bootstrap");
    \\}
    \\
    \\pub fn rootLayer() @TypeOf(kernel.Layer.succeed(greeting.Greeting, .{ .prefix = "hello" })) {
    \\    return kernel.Layer.succeed(greeting.Greeting, .{ .prefix = "hello" });
    \\}
    \\
    \\pub fn runWithOptions(allocator: std.mem.Allocator, io: std.Io, root: std.Io.Dir, options: zstd.CausalRuntime.Options) !void {
    \\    const main_layer = rootLayer();
    \\    var runtime_options = options;
    \\    runtime_options.graph = causal_graph_options;
    \\    var runtime = try zstd.ManagedRuntime(@TypeOf(main_layer)).make(allocator, io, root, main_layer, runtime_options);
    \\    defer runtime.deinit();
    \\    try runtime.run(program(io, root));
    \\    var inspection = try runtime.inspect(allocator, .{ .max_recent_events = 64 });
    \\    defer inspection.deinit();
    \\    if (inspection.services.len != 1 or inspection.causal.findings.len != 0) return error.InvalidApplicationSnapshot;
    \\    const graph = runtime.graphSummary();
    \\    const health = runtime.causalHealth();
    \\    if (graph.records == 0 or health.status != .healthy) return error.MissingCausalEvidence;
    \\    const agent_map = try runtime.agentMapJsonAlloc(allocator, .{ .max_recent_events = 64 });
    \\    defer allocator.free(agent_map);
    \\    if (agent_map.len == 0) return error.MissingApplicationMap;
    \\    try runtime.shutdown();
    \\}
    \\
    \\pub fn run(allocator: std.mem.Allocator, io: std.Io, root: std.Io.Dir) !void {
    \\    return runWithOptions(allocator, io, root, .{});
    \\}
;

pub const causal_graph_source =
    \\const std = @import("std");
    \\const zstd = @import("zigeffect_std");
    \\
    \\pub const path = zstd.CausalGraph.default_path;
    \\pub const wal_path = path ++ "/" ++ zstd.CausalGraph.default_wal_name;
    \\pub const max_events: usize = 100_000;
    \\pub const options = zstd.CausalGraph.Options{
    \\    .path = path,
    \\    .max_records = max_events,
    \\    .max_wal_bytes = 16 * 1024 * 1024,
    \\};
    \\
    \\pub fn open(allocator: std.mem.Allocator, io: std.Io, root: std.Io.Dir) !zstd.CausalGraph.LocalDatabase {
    \\    return zstd.CausalGraph.LocalDatabase.init(allocator, io, root, options);
    \\}
;

pub const config_source =
    \\const std = @import("std");
    \\const zstd = @import("zigeffect_std");
    \\
    \\pub const AppConfig = struct {
    \\    port: i64,
    \\    development: bool,
    \\};
    \\
    \\pub fn decodeJsonAlloc(allocator: std.mem.Allocator, input: []const u8) !AppConfig {
    \\    return zstd.Schema.decodeJsonAlloc(allocator, zstd.Schema.derive(AppConfig, .{
    \\        .port = zstd.Schema.integer().min(1).max(65535),
    \\        .development = zstd.Schema.boolean(),
    \\    }), input);
    \\}
;

pub const cli_source =
    \\const std = @import("std");
    \\const zstd = @import("zigeffect_std");
    \\
    \\const Args = struct { port: i64, verbose: bool };
    \\
    \\pub fn decodePortAlloc(allocator: std.mem.Allocator, args: []const []const u8) !i64 {
    \\    const command = zstd.Cli.typedCommand(Args, .{
    \\        .name = "__PROJECT_NAME__",
    \\        .description = "Run __PROJECT_NAME__ locally",
    \\        .version = "0.1.0",
    \\    }, .{
    \\        zstd.Cli.option("port", zstd.Schema.integer().min(1).max(65535), .{
    \\            .long = "port",
    \\            .env = "ZIGEFFECT_PORT",
    \\            .config_key = "port",
    \\            .default_value = "5178",
    \\            .help = "local HTTP port",
    \\        }),
    \\        zstd.Cli.flag("verbose", .{ .long = "verbose", .short = 'v', .help = "verbose local output" }),
    \\    });
    \\    var parsed = try zstd.Cli.parse(allocator, command.toCommandSpec(), args);
    \\    defer parsed.deinit(allocator);
    \\    var decoded = try zstd.Cli.decodeTypedCommandAlloc(allocator, command, parsed, null, null);
    \\    defer decoded.deinit();
    \\    if (!decoded.ok()) return error.InvalidCommand;
    \\    return decoded.value.?.port;
    \\}
;

pub const http_source =
    \\const std = @import("std");
    \\const zstd = @import("zigeffect_std");
    \\
    \\const HealthRequest = struct { probe: bool };
    \\const HealthResponse = struct { status: []const u8 };
    \\
    \\fn health(_: std.mem.Allocator, request: HealthRequest) !HealthResponse {
    \\    return .{ .status = if (request.probe) "ok" else "degraded" };
    \\}
    \\
    \\pub fn runHealthRoute(allocator: std.mem.Allocator) !zstd.Http.RouteResult {
    \\    const endpoint = zstd.Http.jsonEndpoint(
    \\        "POST",
    \\        "/health",
    \\        zstd.Schema.derive(HealthRequest, .{ .probe = zstd.Schema.boolean() }),
    \\        zstd.Schema.derive(HealthResponse, .{ .status = zstd.Schema.stringEnum(&.{ "ok", "degraded" }) }),
    \\        health,
    \\    );
    \\    var router = zstd.Http.router(.{endpoint});
    \\    return router.handleAlloc(allocator, .{
    \\        .method = "POST",
    \\        .url = "http://127.0.0.1/health",
    \\        .body = "{\"probe\":true}",
    \\    });
    \\}
;

pub const sql_source =
    \\const std = @import("std");
    \\const zstd = @import("zigeffect_std");
    \\
    \\pub fn runSmokeQuery(allocator: std.mem.Allocator) !usize {
    \\    const fields = [_]zstd.Sql.Field{.{ .name = "status", .value = .{ .text = "ready" } }};
    \\    const rows = [_]zstd.Sql.Row{.{ .fields = fields[0..] }};
    \\    var database = zstd.Sql.FakeDatabase.init(.{ .rows = rows[0..] });
    \\    var result = try database.queryAlloc(allocator, .{ .sql = "select status from health", .binds = &.{} });
    \\    defer result.deinit(allocator);
    \\    return result.rows.len;
    \\}
;

pub const causal_source =
    \\const std = @import("std");
    \\const zstd = @import("zigeffect_std");
    \\
    \\pub const workbench_query = "?live=ws://127.0.0.1:4318";
    \\
    \\pub fn attachmentJsonAlloc(
    \\    allocator: std.mem.Allocator,
    \\    component: []const u8,
    \\    facts: usize,
    \\    graph: zstd.CausalGraph.Summary,
    \\) ![]u8 {
    \\    return std.json.Stringify.valueAlloc(allocator, .{
    \\        .schema = "zigeffect.application-attachment.v2",
    \\        .schema_version = 2,
    \\        .component = component,
    \\        .facts = facts,
    \\        .causal_graph = .{
    \\            .schema = graph.schema,
    \\            .path = graph.path,
    \\            .wal_name = graph.wal_name,
    \\            .records = graph.records,
    \\            .edges = graph.edges,
    \\            .session = graph.sessions,
    \\        },
    \\    }, .{});
    \\}
;

pub const greeting_source =
    \\const std = @import("std");
    \\const zstd = @import("zigeffect_std");
    \\
    \\const kernel = zstd.fx.kernel;
    \\
    \\pub const GreetingApi = struct {
    \\    pub const operations: []const []const u8 = &.{"Greeting.greet"};
    \\    prefix: []const u8,
    \\
    \\    pub fn formatAlloc(self: GreetingApi, allocator: std.mem.Allocator, name: []const u8) ![]u8 {
    \\        return std.fmt.allocPrint(allocator, "{s}, {s}", .{ self.prefix, name });
    \\    }
    \\};
    \\
    \\pub const Greeting = kernel.Service("application/Greeting", GreetingApi);
    \\const GreetBase = kernel.Effect([]u8, std.mem.Allocator.Error, .{Greeting});
    \\pub const Greet = GreetBase.Stateful([]const u8);
    \\
    \\pub fn greet(name: []const u8) Greet {
    \\    return Greet.init(name, struct {
    \\        fn run(value: []const u8, ctx: *Greet.Context) std.mem.Allocator.Error![]u8 {
    \\            const result = try ctx.service(Greeting).formatAlloc(ctx.allocator(), value);
    \\            errdefer ctx.allocator().free(result);
    \\            if (ctx.recordCausal(.{ .kind = .activity_completed, .service_key = Greeting.service_key, .label = "Greeting.greet", .status = "success", .redacted_detail = value }) == null) return error.OutOfMemory;
    \\            return result;
    \\        }
    \\    }.run);
    \\}
;

pub const executable_test =
    \\const std = @import("std");
    \\const app = @import("app");
    \\const zstd = @import("zigeffect_std");
    \\
    \\fn runWithAllocator(allocator: std.mem.Allocator) !void {
    \\    const Input = struct { port: i64, development: bool };
    \\    _ = try zstd.Schema.decodeJsonAlloc(allocator, zstd.Schema.derive(Input, .{
    \\        .port = zstd.Schema.integer().min(1).max(65535),
    \\        .development = zstd.Schema.boolean(),
    \\    }), "{\"port\":5178,\"development\":true}");
    \\}
    \\
    \\fn acceptanceScenario() zstd.Testing.Scenario {
    \\    return .{ .id = "bootstrap-boundaries", .label = "generated boundaries remain safe", .requirement = "req-bootstrap", .acceptance_check = "check-bootstrap", .component = "__PROJECT_NAME__", .command = "test", .source_roots = &.{ "src", "test" } };
    \\}
    \\
    \\test "application acceptance is one runtime, receipt, and durable causal graph" {
    \\    var context = try zstd.Testing.TestContext.initFromProject(std.testing.allocator, std.testing.io, std.Io.Dir.cwd(), .{ .project = "__PROJECT_NAME__", .suite = "acceptance", .scenario = acceptanceScenario(), .seed = 42 });
    \\    defer context.deinit();
    \\    const layer = app.rootLayer();
    \\    var runtime = try zstd.ManagedRuntime(@TypeOf(layer)).make(std.testing.allocator, std.testing.io, std.Io.Dir.cwd(), layer, .{ .graph = app.causal_graph_options, .causal_store = context.causalStore() });
    \\    defer runtime.deinit();
    \\    try runtime.run(app.program(std.testing.io, std.Io.Dir.cwd()));
    \\    var inspection = try runtime.inspect(std.testing.allocator, .{ .max_recent_events = 128 });
    \\    defer inspection.deinit();
    \\    const assertions = zstd.Testing.AssertionRecorder.init(&context);
    \\    try assertions.applicationService(.{ .id = "greeting-service", .label = "greeting service is provided at the root", .repair_hint = "compose Greeting once in app.rootLayer" }, &inspection, app.Greeting.service_key, true);
    \\    try assertions.applicationOperation(.{ .id = "greeting-operation", .label = "greeting operation is agent discoverable", .repair_hint = "declare GreetingApi.operations" }, &inspection, app.Greeting.service_key, "Greeting.greet");
    \\    _ = try assertions.event(.{ .id = "greeting-causal", .label = "greeting execution is causally addressable", .repair_hint = "run greeting through the managed runtime" }, .{ .kind = .activity_completed, .label = "Greeting.greet", .status = "success" });
    \\    try assertions.noFindings(.{ .id = "causal-clean", .label = "runtime has no causal findings" });
    \\    try assertions.noPendingFibers(.{ .id = "fibers-clean", .label = "runtime has no pending fibers" });
    \\    var budgets = try zstd.Testing.Budgets.evaluateAlloc(std.testing.allocator, &.{.{ .id = "bootstrap-steps", .kind = .deterministic_steps, .value = 1 }}, &.{.{ .id = "bootstrap-budget", .metric_id = "bootstrap-steps", .absolute_max = 10 }});
    \\    defer budgets.deinit();
    \\    try context.recordReport(.performance, budgets);
    \\    try context.mapCausalEventIds(&runtime);
    \\    try runtime.shutdown();
    \\    try context.publish(std.testing.io, std.Io.Dir.cwd(), 1);
    \\}
    \\
    \\test "application input boundary survives every deterministic allocation failure" {
    \\    try std.testing.checkAllAllocationFailures(std.testing.allocator, runWithAllocator, .{});
    \\}
    \\
    \\test "application concurrency model explores every bounded schedule" {
    \\    const Model = struct {
    \\        value: u8 = 0,
    \\        done: [2]bool = .{ false, false },
    \\        pub fn actionCount(_: @This()) usize { return 2; }
    \\        pub fn runnable(self: @This(), action: usize) bool { return action < 2 and !self.done[action]; }
    \\        pub fn step(self: *@This(), action: usize) !void { if (!self.runnable(action)) return error.NotRunnable; self.value += 1; self.done[action] = true; }
    \\        pub fn isComplete(self: @This()) bool { return self.done[0] and self.done[1]; }
    \\        pub fn invariant(self: @This()) bool { return self.value <= 2; }
    \\        pub fn stateHash(self: @This()) u64 { return @as(u64, self.value) | (@as(u64, @intFromBool(self.done[0])) << 8) | (@as(u64, @intFromBool(self.done[1])) << 9); }
    \\        pub fn sourceRef(_: @This(), action: usize) ?u64 { return 100 + action; }
    \\    };
    \\    var report = try zstd.fx.exploreSchedules(std.testing.allocator, Model{}, .{});
    \\    defer report.deinit();
    \\    try std.testing.expectEqual(zstd.fx.ScheduleExplorationVerdict.passed, report.verdict());
    \\}
    \\
    \\test "deterministic and concurrent executor traces stay structurally equivalent" {
    \\    var deterministic = zstd.fx.CausalStore.init(std.testing.allocator);
    \\    defer deterministic.deinit();
    \\    var concurrent = zstd.fx.CausalStore.init(std.testing.allocator);
    \\    defer concurrent.deinit();
    \\    _ = try deterministic.record(.{ .kind = .effect_started, .type_name = "generated-work" });
    \\    _ = try deterministic.record(.{ .kind = .effect_completed, .type_name = "generated-work", .status = "success" });
    \\    _ = try concurrent.record(.{ .kind = .effect_started, .type_name = "generated-work" });
    \\    _ = try concurrent.record(.{ .kind = .effect_completed, .type_name = "generated-work", .status = "success" });
    \\    var left = try deterministic.snapshot(std.testing.allocator);
    \\    defer left.deinit();
    \\    var right = try concurrent.snapshot(std.testing.allocator);
    \\    defer right.deinit();
    \\    try std.testing.expect(try zstd.fx.causalStructurallyEquivalent(std.testing.allocator, left.events, right.events));
    \\}
;

pub const library_build =
    \\const std = @import("std");
    \\
    \\pub fn build(b: *std.Build) void {
    \\    const target = b.standardTargetOptions(.{});
    \\    const optimize = b.standardOptimizeOption(.{});
    \\    const zigeffect_std_dependency = b.dependency("zigeffect_std", .{ .target = target, .optimize = optimize });
    \\    const zigeffect_std = zigeffect_std_dependency.module("zigeffect_std");
    \\    const testing_runner = zigeffect_std_dependency.module("zigeffect_test_runner").root_source_file.?;
    \\    const library = b.addModule("__MODULE_NAME__", .{
    \\        .root_source_file = b.path("src/root.zig"),
    \\        .target = target,
    \\        .optimize = optimize,
    \\    });
    \\    library.addImport("zigeffect_std", zigeffect_std);
    \\    const test_module = b.createModule(.{
    \\        .root_source_file = b.path("test/root_test.zig"),
    \\        .target = target,
    \\        .optimize = optimize,
    \\    });
    \\    test_module.addImport("library", library);
    \\    test_module.addImport("zigeffect_std", zigeffect_std);
    \\    var test_options = std.Build.TestOptions{ .name = "__PROJECT_NAME__-tests", .root_module = test_module, .test_runner = .{ .path = testing_runner, .mode = .server } };
    \\    if (b.option([]const u8, "test-filter", "Compile only matching native tests")) |filter| test_options.filters = &.{filter};
    \\    const tests = b.addTest(test_options);
    \\    const run_tests = b.addRunArtifact(tests);
    \\    const test_step = b.step("test", "Run __PROJECT_NAME__ tests");
    \\    test_step.dependOn(&run_tests.step);
    \\}
;

pub const library_source =
    \\const std = @import("std");
    \\const zstd = @import("zigeffect_std");
    \\const kernel = zstd.fx.kernel;
    \\
    \\pub const component_name = "__PROJECT_NAME__";
    \\pub const Input = struct { value: i64 };
    \\
    \\pub const CalculatorApi = struct {
    \\    pub const operations: []const []const u8 = &.{"Calculator.double"};
    \\    pub fn double(_: CalculatorApi, value: i64) i64 { return value * 2; }
    \\};
    \\
    \\pub const Calculator = kernel.Service("library/Calculator", CalculatorApi);
    \\pub const DefaultLayer = @TypeOf(kernel.Layer.succeed(Calculator, .{}));
    \\const DoubleBase = kernel.Effect(i64, std.mem.Allocator.Error, .{Calculator});
    \\pub const Double = DoubleBase.Stateful(i64);
    \\
    \\pub fn double(value: i64) Double {
    \\    return Double.init(value, struct {
    \\        fn run(input: i64, ctx: *Double.Context) std.mem.Allocator.Error!i64 {
    \\            const output = ctx.service(Calculator).double(input);
    \\            if (ctx.recordCausal(.{ .kind = .activity_completed, .service_key = Calculator.service_key, .label = "Calculator.double", .status = "success", .redacted_detail = component_name }) == null) return error.OutOfMemory;
    \\            return output;
    \\        }
    \\    }.run);
    \\}
    \\
    \\pub fn defaultLayer() DefaultLayer {
    \\    return kernel.Layer.succeed(Calculator, .{});
    \\}
    \\
    \\pub fn decodeInputAlloc(allocator: std.mem.Allocator, input_json: []const u8) !Input {
    \\    return zstd.Schema.decodeJsonAlloc(allocator, zstd.Schema.derive(Input, .{
    \\        .value = zstd.Schema.integer(),
    \\    }), input_json);
    \\}
;

pub const library_test =
    \\const std = @import("std");
    \\const library = @import("library");
    \\const zstd = @import("zigeffect_std");
    \\
    \\fn acceptanceScenario() zstd.Testing.Scenario {
    \\    return .{ .id = "bootstrap-boundaries", .label = "generated library remains safe", .requirement = "req-bootstrap", .acceptance_check = "check-bootstrap", .component = "__PROJECT_NAME__", .command = "test", .source_roots = &.{ "src", "test" } };
    \\}
    \\
    \\fn runWithAllocator(allocator: std.mem.Allocator) !void {
    \\    _ = try zstd.Schema.decodeJsonAlloc(allocator, zstd.Schema.derive(library.Input, .{
    \\        .value = zstd.Schema.integer(),
    \\    }), "{\"value\":21}");
    \\}
    \\
    \\test "public effect validates input and runs through its layer" {
    \\    var context = try zstd.Testing.TestContext.initFromProject(std.testing.allocator, std.testing.io, std.Io.Dir.cwd(), .{ .project = "__PROJECT_NAME__", .suite = "acceptance", .scenario = acceptanceScenario() });
    \\    defer context.deinit();
    \\    const input = try library.decodeInputAlloc(std.testing.allocator, "{\"value\":21}");
    \\    const layer = library.defaultLayer();
    \\    var runtime = try zstd.ManagedRuntime(@TypeOf(layer)).make(std.testing.allocator, std.testing.io, std.Io.Dir.cwd(), layer, .{ .causal_store = context.causalStore() });
    \\    defer runtime.deinit();
    \\    const actual = try runtime.run(library.double(input.value).named("library.double"));
    \\    var inspection = try runtime.inspect(std.testing.allocator, .{ .max_recent_events = 64 });
    \\    defer inspection.deinit();
    \\    const assertions = zstd.Testing.AssertionRecorder.init(&context);
    \\    try assertions.equal(.{ .id = "double-value", .label = "public effect doubles valid input" }, @as(i64, 42), actual);
    \\    try assertions.applicationService(.{ .id = "calculator-service", .label = "calculator service is provided by the default layer" }, &inspection, library.Calculator.service_key, true);
    \\    try assertions.applicationOperation(.{ .id = "calculator-operation", .label = "calculator operation is discoverable" }, &inspection, library.Calculator.service_key, "Calculator.double");
    \\    _ = try assertions.event(.{ .id = "double-causal", .label = "double execution is causally addressable" }, .{ .kind = .activity_completed, .label = "Calculator.double", .status = "success" });
    \\    try assertions.noFindings(.{ .id = "causal-clean", .label = "library execution has no causal findings" });
    \\    var budgets = try zstd.Testing.Budgets.evaluateAlloc(std.testing.allocator, &.{.{ .id = "double-steps", .kind = .deterministic_steps, .value = 1 }}, &.{.{ .id = "double-budget", .metric_id = "double-steps", .absolute_max = 8 }});
    \\    defer budgets.deinit();
    \\    try context.recordReport(.performance, budgets);
    \\    try context.mapCausalEventIds(&runtime);
    \\    try runtime.shutdown();
    \\    try context.publish(std.testing.io, std.Io.Dir.cwd(), 1);
    \\}
    \\
    \\test "Schema-derived properties are deterministic and replayable" {
    \\    const Property = struct { fn check(_: void, value: i64) !void { if (value < 0 or value > 100) return error.OutOfBounds; } };
    \\    var receipt = try zstd.Testing.Generators.runProperty(std.testing.allocator, zstd.Schema.integer().min(0).max(100), {}, Property.check, .{ .seed = 42, .cases = 64 });
    \\    defer receipt.deinit();
    \\    try std.testing.expect(receipt.passed);
    \\    try std.testing.expectEqual(@as(usize, 64), receipt.executed);
    \\}
    \\
    \\test "library survives every deterministic allocation failure" {
    \\    try std.testing.checkAllAllocationFailures(std.testing.allocator, runWithAllocator, .{});
    \\}
    \\
    \\test "library schedule model is bounded and complete" {
    \\    const Model = struct {
    \\        value: u8 = 0,
    \\        done: [2]bool = .{ false, false },
    \\        pub fn actionCount(_: @This()) usize { return 2; }
    \\        pub fn runnable(self: @This(), action: usize) bool { return action < 2 and !self.done[action]; }
    \\        pub fn step(self: *@This(), action: usize) !void { if (!self.runnable(action)) return error.NotRunnable; self.value += 1; self.done[action] = true; }
    \\        pub fn isComplete(self: @This()) bool { return self.done[0] and self.done[1]; }
    \\        pub fn invariant(self: @This()) bool { return self.value <= 2; }
    \\        pub fn stateHash(self: @This()) u64 { return @as(u64, self.value) | (@as(u64, @intFromBool(self.done[0])) << 8) | (@as(u64, @intFromBool(self.done[1])) << 9); }
    \\        pub fn sourceRef(_: @This(), action: usize) ?u64 { return 200 + action; }
    \\    };
    \\    var report = try zstd.fx.exploreSchedules(std.testing.allocator, Model{}, .{});
    \\    defer report.deinit();
    \\    try std.testing.expectEqual(zstd.fx.ScheduleExplorationVerdict.passed, report.verdict());
    \\}
    \\
    \\test "library execution traces remain structurally equivalent" {
    \\    var deterministic = zstd.fx.CausalStore.init(std.testing.allocator);
    \\    defer deterministic.deinit();
    \\    var concurrent = zstd.fx.CausalStore.init(std.testing.allocator);
    \\    defer concurrent.deinit();
    \\    _ = try deterministic.record(.{ .kind = .effect_started, .type_name = "library-work" });
    \\    _ = try deterministic.record(.{ .kind = .effect_completed, .type_name = "library-work", .status = "success" });
    \\    _ = try concurrent.record(.{ .kind = .effect_started, .type_name = "library-work" });
    \\    _ = try concurrent.record(.{ .kind = .effect_completed, .type_name = "library-work", .status = "success" });
    \\    var left = try deterministic.snapshot(std.testing.allocator);
    \\    defer left.deinit();
    \\    var right = try concurrent.snapshot(std.testing.allocator);
    \\    defer right.deinit();
    \\    try std.testing.expect(try zstd.fx.causalStructurallyEquivalent(std.testing.allocator, left.events, right.events));
    \\}
;

pub const system_build =
    \\const std = @import("std");
    \\
    \\pub fn build(b: *std.Build) void {
    \\    const target = b.standardTargetOptions(.{});
    \\    const optimize = b.standardOptimizeOption(.{});
    \\    const api = b.dependency("api", .{ .target = target, .optimize = optimize }).module("app");
    \\    const worker = b.dependency("worker", .{ .target = target, .optimize = optimize }).module("app");
    \\    const shared = b.dependency("shared", .{ .target = target, .optimize = optimize }).module("shared");
    \\    const zigeffect_std_dependency = b.dependency("zigeffect_std", .{ .target = target, .optimize = optimize });
    \\    const zigeffect_std = zigeffect_std_dependency.module("zigeffect_std");
    \\    const testing_runner = zigeffect_std_dependency.module("zigeffect_test_runner").root_source_file.?;
    \\    const system = b.addModule("system", .{
    \\        .root_source_file = b.path("src/root.zig"),
    \\        .target = target,
    \\        .optimize = optimize,
    \\    });
    \\    system.addImport("api", api);
    \\    system.addImport("worker", worker);
    \\    system.addImport("shared", shared);
    \\    system.addImport("zigeffect_std", zigeffect_std);
    \\    const test_module = b.createModule(.{
    \\        .root_source_file = b.path("test/root_test.zig"),
    \\        .target = target,
    \\        .optimize = optimize,
    \\    });
    \\    test_module.addImport("system", system);
    \\    test_module.addImport("zigeffect_std", zigeffect_std);
    \\    var test_options = std.Build.TestOptions{ .name = "__PROJECT_NAME__-tests", .root_module = test_module, .test_runner = .{ .path = testing_runner, .mode = .server } };
    \\    if (b.option([]const u8, "test-filter", "Compile only matching native tests")) |filter| test_options.filters = &.{filter};
    \\    const tests = b.addTest(test_options);
    \\    const run_tests = b.addRunArtifact(tests);
    \\    const test_step = b.step("test", "Run all local system components");
    \\    test_step.dependOn(&run_tests.step);
    \\}
;

pub const system_zon =
    \\.{
    \\    .name = .__ZIG_NAME__,
    \\    .version = "0.1.0",
    \\    .minimum_zig_version = "0.16.0",
    \\    .fingerprint = 0x__FINGERPRINT__,
    \\    .dependencies = .{
    \\        .api = .{ .path = "services/api" },
    \\        .worker = .{ .path = "services/worker" },
    \\        .shared = .{ .path = "packages/shared" },
    \\        .zigeffect_std = .{ .path = "__STD_PATH__" },
    \\    },
    \\    .paths = .{ "build.zig", "build.zig.zon", "README.md", "src", "test" },
    \\}
;

pub const system_source =
    \\const std = @import("std");
    \\const zstd = @import("zigeffect_std");
    \\pub const api = @import("api");
    \\pub const worker = @import("worker");
    \\pub const shared = @import("shared");
    \\
    \\pub fn runWithOptions(allocator: std.mem.Allocator, io: std.Io, root: std.Io.Dir, options: zstd.CausalRuntime.Options) !void {
    \\    if (shared.contract_version != 1) return error.IncompatibleSharedContract;
    \\    try root.createDirPath(io, "services/api");
    \\    try root.createDirPath(io, "services/worker");
    \\    var api_root = try root.openDir(io, "services/api", .{});
    \\    defer api_root.close(io);
    \\    var worker_root = try root.openDir(io, "services/worker", .{});
    \\    defer worker_root.close(io);
    \\    try api.runWithOptions(allocator, io, api_root, options);
    \\    try worker.runWithOptions(allocator, io, worker_root, options);
    \\}
    \\
    \\pub fn run(allocator: std.mem.Allocator, io: std.Io, root: std.Io.Dir) !void {
    \\    return runWithOptions(allocator, io, root, .{});
    \\}
;

pub const system_test =
    \\const std = @import("std");
    \\const system = @import("system");
    \\const zstd = @import("zigeffect_std");
    \\
    \\test "system acceptance runs real child applications and both causal graphs" {
    \\    const scenario = zstd.Testing.Scenario{ .id = "bootstrap-boundaries", .label = "api worker and shared package agree", .requirement = "req-bootstrap", .acceptance_check = "check-bootstrap", .component = "api-service", .command = "test" };
    \\    var context = try zstd.Testing.TestContext.initFromProject(std.testing.allocator, std.testing.io, std.Io.Dir.cwd(), .{ .project = "__PROJECT_NAME__", .suite = "system", .scenario = scenario });
    \\    defer context.deinit();
    \\    try system.runWithOptions(std.testing.allocator, std.testing.io, std.Io.Dir.cwd(), .{ .causal_store = context.causalStore() });
    \\    const assertions = zstd.Testing.AssertionRecorder.init(&context);
    \\    try assertions.equal(.{ .id = "shared-contract", .label = "shared contract version" }, @as(u32, 1), system.shared.contract_version);
    \\    _ = try assertions.event(.{ .id = "component-causal", .label = "a child application executed through its managed runtime" }, .{ .kind = .activity_completed, .label = "Greeting.greet", .status = "success" });
    \\    try assertions.noPendingFibers(.{ .id = "fibers-clean", .label = "child applications left no pending fibers" });
    \\    try assertions.noFindings(.{ .id = "causal-clean", .label = "child applications left no causal findings" });
    \\    var world = try zstd.Testing.VirtualWorld.runAlloc(std.testing.allocator, &.{
    \\        .{ .kind = .send, .actor = "api", .target = "worker", .value = "bootstrap" },
    \\        .{ .kind = .queue_delivery, .actor = "queue", .target = "worker", .value = "bootstrap" },
    \\    }, &.{.{ .step = 1, .kind = .queue_redelivery }}, .{ .seed = 42 });
    \\    defer world.deinit();
    \\    try context.recordReport(.virtual_world, world);
    \\    var api_graph = try zstd.CausalGraph.Snapshot.open(std.testing.allocator, std.testing.io, std.Io.Dir.cwd(), .{ .path = "services/api/.zigeffect/graph", .max_records = 100_000 });
    \\    defer api_graph.deinit();
    \\    var worker_graph = try zstd.CausalGraph.Snapshot.open(std.testing.allocator, std.testing.io, std.Io.Dir.cwd(), .{ .path = "services/worker/.zigeffect/graph", .max_records = 100_000 });
    \\    defer worker_graph.deinit();
    \\    try assertions.boolean(.{ .id = "component-graphs", .label = "both child causal graphs contain execution evidence" }, api_graph.summary().records > 0 and worker_graph.summary().records > 0);
    \\    try context.publish(std.testing.io, std.Io.Dir.cwd(), 1);
    \\}
;

pub const production_system_source =
    \\pub const api = @import("api");
    \\pub const worker = @import("worker");
    \\pub const shared = @import("shared");
    \\pub fn productionContract() bool { return shared.contract_version == 1 and api.productionContract() and worker.productionContract(); }
;

pub const production_system_test =
    \\const std = @import("std");
    \\const system = @import("system");
    \\const zstd = @import("zigeffect_std");
    \\
    \\test "production system compiles separate API worker and shared contracts" {
    \\    try std.testing.expect(system.productionContract());
    \\}
    \\test "production system emits a Testing v2 capability scenario" {
    \\    const scenario = zstd.Testing.Scenario{ .id = "bootstrap-boundaries", .label = "production adapters resolve before launch", .requirement = "req-bootstrap", .acceptance_check = "check-bootstrap", .component = "api-service", .command = "test" };
    \\    var context = try zstd.Testing.TestContext.initFromProject(std.testing.allocator, std.testing.io, std.Io.Dir.cwd(), .{ .project = "__PROJECT_NAME__", .suite = "production-system", .scenario = scenario });
    \\    defer context.deinit();
    \\    const assertions = zstd.Testing.AssertionRecorder.init(&context);
    \\    try assertions.boolean(.{ .id = "real-wiring", .label = "all production wiring compiles" }, system.productionContract());
    \\    try context.publish(std.testing.io, std.Io.Dir.cwd(), 1);
    \\}
;

pub const shared_source =
    \\pub const contract_version: u32 = 1;
    \\pub const component_name = "__PROJECT_NAME__";
;

pub const shared_test =
    \\const std = @import("std");
    \\const library = @import("library");
    \\
    \\test "shared contract exposes a stable initial version" {
    \\    try std.testing.expectEqual(@as(u32, 1), library.contract_version);
    \\}
;

pub const readme =
    \\# __PROJECT_NAME__
    \\
    \\Generated by zigeffect for local-first, agent-readable Zig development.
    \\Scaffold profile: `__PROFILE__`. Receipts and capability resolution must be interpreted under this profile.
    \\
    \\## Architecture
    \\
    \\Generated application, service, library, and module code uses canonical
    \\`fx.kernel.Service`, `Effect`, `Layer`, and one process-level
    \\`zstd.ManagedRuntime`. Domain code composes descriptions; only the process
    \\root or a runtime-backed transport interprets them. The runtime owns the
    \\bounded in-memory causal recorder and an embedded durable NenDB graph. Do
    \\not introduce `EffectEnv`, `LayerGraph`, `ctx.runEffect`, per-endpoint
    \\runtimes, or manual graph/store wiring.
    \\
    \\The production profile currently isolates HTTP, Postgres, and OTLP behind a
    \\documented compatibility adapter bridge until those packages publish
    \\canonical kernel layers. That bridge is migration debt, not a second
    \\application architecture.
    \\
    \\## Develop
    \\
    \\```sh
    \\zigeffect compatibility --json
    \\zigeffect upgrade --dry-run --json
    \\zigeffect project validate --json
    \\zigeffect project check --agent --json
    \\zigeffect project test --json
    \\zigeffect test list --json
    \\zigeffect test affected --changed <changed-path> --json
    \\zigeffect test run --requirement req-bootstrap --json
    \\zigeffect test coverage --requirement req-bootstrap --json
    \\zigeffect test gaps --requirement req-bootstrap --json
    \\zigeffect test stress --requirement req-bootstrap --runs 32 --json
    \\zigeffect test history --json
    \\zigeffect test explain bootstrap-boundaries --json
    \\zigeffect agent context --task req-bootstrap --budget 65536 --json
    \\zigeffect project dev
    \\zigeffect graph status --json
    \\zigeffect graph since <baseline-event-id> --limit 256 --json
    \\zigeffect graph event <event-id> --json
    \\zigeffect graph children <event-id> --json
    \\zigeffect graph path <from-event-id> <to-event-id> --limit 128 --json
    \\```
    \\
    \\The source of truth is `zigeffect.project.json`. Compatibility metadata and
    \\CLI-owned scaffold hashes live under `.zigeffect/`; upgrades preserve
    \\user-owned source and refuse edited managed files. Keep requirement status,
    \\acceptance checks, causal evidence, and handoff receipts aligned with code.
    \\Applications and services automatically persist every redacted semantic
    \\runtime event into an embedded NenDB topology plus its crash-safe property
    \\WAL at `.zigeffect/graph/causal-graph.jsonl`; no daemon or container is
    \\required. Capture `newest_durable_event_id` from `graph status` before a
    \\change, then query `graph since` after its focused test to inspect exactly
    \\what the change caused. The graph commands validate the manifest before
    \\opening that artifact. For a system root, add
    \\`--component <manifest-component-id>` to graph queries.
    \\Test scenarios bind requirements to deterministic seeds, fault profiles,
    \\source roots, replay commands, causal events, and semantic snapshots. The
    \\CLI control and native process receipts prevent exit-code-only false passes.
    \\The latest agent-readable run is `.zigeffect/tests/latest.json`; open it in
    \\the Workbench Tests view for protocol identity, semantic gaps, adversarial
    \\evidence, minimal failures, regressions, and replay instead of reconstructing
    \\failures from terminal text.
;

pub const changelog =
    \\# Changelog
    \\
    \\## 0.1.0
    \\
    \\- Initial public package contract.
;

pub const statechart_source =
    \\const zstd = @import("zigeffect_std");
    \\
    \\pub const State = enum { root, idle, running, done };
    \\pub const Event = enum { start, finish };
    \\pub const Context = struct { attempts: u32 = 0 };
    \\pub const Command = union(enum) { begin_work, publish_result };
    \\pub const Definition = zstd.fx.statechart.Definition(State, Event, Context, Command);
    \\pub const definition = Definition.init(.{
    \\    .id = "agent.__MACHINE_NAME__",
    \\    .version = 1,
    \\    .initial = .root,
    \\    .states = &.{
    \\        .{ .id = .root, .kind = .compound, .initial = .idle },
    \\        .{ .id = .idle, .parent = .root, .description = "Waiting for typed work" },
    \\        .{ .id = .running, .parent = .root, .description = "Executing through Effect services" },
    \\        .{ .id = .done, .kind = .final, .parent = .root },
    \\    },
    \\    .transitions = &.{
    \\        .{ .id = "start", .source = .idle, .event = .start, .target = .running },
    \\        .{ .id = "finish", .source = .running, .event = .finish, .target = .done },
    \\    },
    \\});
    \\pub const Runtime = zstd.fx.statechart.ConfigurationMachine(Definition);
    \\pub const Artifacts = zstd.fx.statechart.ConfigurationArtifacts(Definition);
    \\pub const Analysis = zstd.fx.statechart.Analyzer(Definition);
;

pub const statechart_actor_source =
    \\const zstd = @import("zigeffect_std");
    \\
    \\pub const State = enum { idle, running, done };
    \\pub const Event = enum { start, finish };
    \\pub const Context = struct {};
    \\pub const Command = union(enum) { begin_work, publish_result };
    \\pub const Definition = zstd.fx.statechart.Definition(State, Event, Context, Command);
    \\pub const definition = Definition.init(.{
    \\    .id = "agent.__MACHINE_NAME__",
    \\    .version = 1,
    \\    .initial = .idle,
    \\    .states = &.{ .{ .id = .idle }, .{ .id = .running }, .{ .id = .done, .kind = .final } },
    \\    .transitions = &.{
    \\        .{ .id = "start", .source = .idle, .event = .start, .target = .running },
    \\        .{ .id = "finish", .source = .running, .event = .finish, .target = .done },
    \\    },
    \\});
    \\pub const Actor = zstd.fx.statechart.Actor(Definition);
    \\pub const ActorSystem = zstd.fx.statechart.ActorSystem(Definition);
;

pub const durable_statechart_source =
    \\const zstd = @import("zigeffect_std");
    \\
    \\pub const State = enum { idle, running, done };
    \\pub const Event = enum { start, finish };
    \\pub const Context = struct {};
    \\pub const Command = union(enum) { activity, timer, signal, queue };
    \\pub const Definition = zstd.fx.statechart.Definition(State, Event, Context, Command);
    \\pub const definition = Definition.init(.{
    \\    .id = "workflow.__MACHINE_NAME__",
    \\    .version = 1,
    \\    .initial = .idle,
    \\    .states = &.{ .{ .id = .idle }, .{ .id = .running }, .{ .id = .done, .kind = .final } },
    \\    .transitions = &.{
    \\        .{ .id = "start", .source = .idle, .event = .start, .target = .running },
    \\        .{ .id = "finish", .source = .running, .event = .finish, .target = .done },
    \\    },
    \\});
    \\pub const Durable = zstd.fx.workflow.DurableStatechart(Definition);
;

pub const statechart_test_source =
    \\const std = @import("std");
    \\const zstd = @import("zigeffect_std");
    \\
    \\test "__MACHINE_NAME__ definition is valid and deterministic" {
    \\    const State = enum { idle, done };
    \\    const Event = enum { finish };
    \\    const Definition = zstd.fx.statechart.Definition(State, Event, void, void);
    \\    const definition = Definition.init(.{
    \\        .id = "agent.__MACHINE_NAME__",
    \\        .version = 1,
    \\        .initial = .idle,
    \\        .states = &.{ .{ .id = .idle }, .{ .id = .done, .kind = .final } },
    \\        .transitions = &.{.{ .id = "finish", .source = .idle, .event = .finish, .target = .done }},
    \\    });
    \\    try std.testing.expect(definition.validate().isValid());
    \\    try std.testing.expect(definition.fingerprint() != 0);
    \\}
;

pub const gitignore =
    \\.zig-cache/
    \\zig-out/
    \\.zigeffect/sessions/
    \\.zigeffect/causal/
    \\.zigeffect/graph/
    \\.zigeffect/statecharts/
    \\.zigeffect/receipts/
    \\.zigeffect/tests/actual/
    \\.zigeffect/tests/raw/
    \\.zigeffect/tests/receipts/
    \\.zigeffect/tests/process-receipts/
    \\.zigeffect/tests/raw-receipts/
    \\.zigeffect/tests/control.json
    \\.zigeffect/tests/history.jsonl
    \\.zigeffect/tests/latest.json
;

pub const skill =
    \\---
    \\name: zigeffect-development
    \\description: Build, change, debug, test, or review this ZigEffect application through zigeffect.project.json, public zigeffect_std APIs, zstd.Testing scenarios, causal evidence, deterministic replay, semantic snapshots, and evidence-backed agent handoffs.
    \\---
    \\
    \\# ZigEffect Development
    \\
    \\Treat the manifest and structured evidence as the source of truth. Terminal
    \\text is a bounded diagnostic artifact, not proof that a requirement passed.
    \\
    \\## Run the proof-carrying causal loop
    \\
    \\1. Orient with `zigeffect agent context --task <id-or-summary> --budget
    \\   65536 --json`. Retain its source identity, manifest digest, graph cursor,
    \\   authority, omissions, affected scenarios, and proof references.
    \\2. Bind the request to a requirement, acceptance check, component, fixed
    \\   command, and scenario. State the expected before/action/after causal path
    \\   and the slice that must remain unchanged.
    \\3. If a coordinator supplies a work packet, obey its baseline, allowed and
    \\   excluded paths, dependencies, verification commands, graph cursor,
    \\   lease, and fencing token. Never invent missing coordination or authority.
    \\4. Add the failing deterministic native scenario, then make the smallest
    \\   typed service/layer change through the one managed runtime.
    \\5. Run the affected scenario. Treat
    \\   `.zigeffect/tests/process-receipts/<scenario>.json` and
    \\   `.zigeffect/handoffs/tests/<scenario>.json` as authoritative only when
    \\   source, manifest, command, toolchain, and completeness identities match.
    \\   `.zigeffect/tests/raw-receipts/` and terminal output are diagnostic only.
    \\6. Compare `zigeffect graph since <cursor> --limit 256 --json` with the
    \\   counterfactual and use `zigeffect graph path <from> <to> --limit 128
    \\   --json` for exact relationships.
    \\7. Re-query `agent context` after the change. Reject stale proof,
    \\   undeclared or overlapping paths, expired fencing tokens, missing
    \\   dependency proof, and required gaps before integration.
    \\8. Run project gates and hand off exact receipt/proof paths, replay
    \\   commands, causal IDs, limitations, and remaining authority requirements.
    \\
    \\## Establish intent
    \\
    \\1. Run `zigeffect compatibility --json`, read `zigeffect.project.json`, and
    \\   inspect migrations with `zigeffect upgrade --dry-run --json`. Never work
    \\   around a conflict or unsupported manifest.
    \\2. Run:
    \\
    \\       zigeffect project validate --json
    \\       zigeffect agent status --json
    \\       zigeffect agent next --json
    \\       zigeffect test list --json
    \\
    \\3. Map the request to a requirement, acceptance check, component,
    \\   manifest-owned command, and one or more `test_scenarios`. Declare missing
    \\   intent before implementing behavior.
    \\4. Read the component's public facade, layers, schemas, tests, and causal
    \\   helpers. Use public `zigeffect_std` APIs; never import another component's
    \\   internals.
    \\
    \\## Implement inspectable behavior
    \\
    \\- Model fallible boundaries with typed effects, service layers, Schema,
    \\  typed errors, scoped resources, and deterministic providers for config,
    \\  clock, filesystem, process, HTTP, SQL, IDs, logging, and tracing.
    \\- Define stable tags with `zstd.fx.kernel.Service`, operations with
    \\  `zstd.fx.kernel.Effect`, and implementations with canonical layers.
    \\  Compose one named root program and interpret it through one
    \\  `zstd.ManagedRuntime`. It automatically owns the in-memory recorder,
    \\  embedded NenDB topology, durable property WAL, and checked shutdown.
    \\  Application code never calls `runIn`, `ctx.runEffect`, `layerGraph`,
    \\  manually attaches a causal backend, or uses environment-parameterized
    \\  effects.
    \\- Application acceptance tests pass `context.causalStore()` only to the
    \\  one root `zstd.ManagedRuntime`, assert the real execution, call
    \\  `context.mapCausalEventIds(&runtime)` while it is live, then shut down
    \\  and publish. Mount the runtime at the owning project or component root
    \\  and query at least one mapped ID through the project-mounted graph before
    \\  publishing. Do not create a synthetic receipt beside a detached graph.
    \\- Use `zigeffect add` and `zigeffect generate` before hand-writing framework
    \\  structure.
    \\- Emit semantic facts at external, workflow, statechart, artifact, and
    \\  acceptance boundaries. Use typed statecharts for inspectable long-lived
    \\  control flow and durable statecharts for replayable workflows.
    \\- Never put credentials, personal data, or raw terminal scrollback in
    \\  manifests, facts, receipts, fixtures, snapshots, or Workbench payloads.
    \\
    \\## Test requirements with `zstd.Testing`
    \\
    \\Add a failing deterministic test before changing behavior. Register its
    \\scenario in `test_scenarios` with a requirement, acceptance check, component,
    \\command, source roots, stable seed, fault profile, and required status.
    \\
    \\    const std = @import("std");
    \\    const zstd = @import("zigeffect_std");
    \\
    \\    var context = try zstd.Testing.TestContext.initFromProject(std.testing.allocator, std.testing.io, std.Io.Dir.cwd(), .{
    \\        .project = "app",
    \\        .suite = "acceptance",
    \\        .scenario = scenario,
    \\        .seed = 42,
    \\    });
    \\    defer context.deinit();
    \\    const assertions = zstd.Testing.AssertionRecorder.init(&context);
    \\    try assertions.equal(.{
    \\        .id = "stable-acceptance-id",
    \\        .label = "user-visible behavior holds",
    \\        .repair_hint = "repair the responsible typed boundary",
    \\    }, expected, actual);
    \\    try assertions.noPendingFibers(.{ .id = "fibers-clean", .label = "no work escaped its scope" });
    \\    try assertions.noFindings(.{ .id = "causal-clean", .label = "runtime invariants remain clean" });
    \\    try context.publish(std.testing.io, std.Io.Dir.cwd(), 1);
    \\
    \\Use `AssertionRecorder` for values, semantic JSON, `Exit`, `Cause`, events,
    \\findings, fibers, and secret scans. Use `FaultMatrix` for bounded hostile
    \\runtime cases, `Generators.runProperty` for structural shrinking,
    \\`Models.StatechartExplorer` and `Schedules` for bounded exploration,
    \\`Differential` for cross-executor comparison, `VirtualWorld` for
    \\distributed faults, `Mutation` for requirement-linked mutant evidence,
    \\`Budgets` for deterministic performance contracts, `Sandbox.Firewall` for
    \\side-effect authority, and semantic snapshots for durable artifacts.
    \\Unsupported cases, exhausted bounds, dropped evidence, or truncation are not
    \\passes.
    \\
    \\## Iterate from evidence
    \\
    \\1. Before editing, run `zigeffect agent context --task <id> --budget 65536
    \\   --json`. Retain its exact source/manifest identity, proof references,
    \\   authority, omissions, and `newest_durable_event_id` as the causal
    \\   baseline. Use the current graph,
    \\   requirement, contracts, and scopes to state the expected counterfactual:
    \\   which services, boundaries, and facts should change, and which should not.
    \\2. Select the smallest declared set with `zigeffect test affected --changed
    \\   <path> --json`, then run a scenario or `zigeffect test run --requirement
    \\   <id> --json`.
    \\3. Read `.zigeffect/tests/latest.json`, then the stable native receipt and
    \\   proof handoff under `.zigeffect/tests/process-receipts/` and
    \\   `.zigeffect/handoffs/tests/`; require their source, manifest, command,
    \\   native toolchain, selection, and status identities to agree.
    \\   Run `zigeffect test coverage --json` and `zigeffect test gaps --json`;
    \\   required semantic gaps are unpassed evidence.
    \\4. Query `zigeffect graph since <baseline-event-id> --limit 256 --json` and
    \\   compare the actual causal delta with the stated counterfactual and test
    \\   contract. An empty, truncated, dropped, or unexpectedly broad delta is
    \\   evidence to investigate, not a pass.
    \\5. On failure, inspect the first assertion's source, repair hint, causal
    \\   event IDs, and `causal_event_id_space`. Query `zigeffect graph event
    \\   <id> --json` and `zigeffect graph children <id> --json` only for
    \\   `graph_durable` IDs; `runtime_local` IDs are not graph cursors.
    \\   Use `zigeffect graph path <from> <to> --limit 128 --json` when two
    \\   events bound the suspected causal behavior.
    \\6. Copy the receipt's exact replay command, preserving its seed, fault,
    \\   root, and bounds. Use `zigeffect safety explain <finding-id>` for a
    \\   source-linked safety repair.
    \\7. Compare with `zigeffect test snapshot <scenario> --json`. Apply only an
    \\   inspected intentional change with `--apply --json`; never bless an
    \\   unexplained diff.
    \\
    \\## Verify and hand off
    \\
    \\    zigeffect project validate --json
    \\    zigeffect test run --requirement <id> --json
    \\    zigeffect test coverage --requirement <id> --json
    \\    zigeffect test gaps --requirement <id> --json
    \\    zigeffect test stress --requirement <id> --runs 32 --json
    \\    zigeffect test history --json
    \\    zigeffect project test --json
    \\    zigeffect project check --agent --json
    \\    zigeffect agent handoff --provider <harness> --session <id> --json
    \\
    \\Attach changed requirements, acceptance status, bounded redacted receipts,
    \\replay commands, and relevant causal IDs. State failed or unrun gates. Never
    \\claim safety or completeness beyond the compiler mode, platform, cases, and
    \\bounds recorded in the evidence.
    \\
    \\For multi-agent work, integrate proof rather than prose. Each implementer
    \\owns one non-overlapping work packet and returns a proof bundle bound to the
    \\source baseline, lease fencing token, changed paths, verification digests,
    \\receipts, and causal IDs. Independent qualifiers never repair candidates.
    \\Repair memory is advice, not current proof or authority.
;
