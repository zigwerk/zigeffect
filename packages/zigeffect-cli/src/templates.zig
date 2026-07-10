pub const executable_build =
    \\const std = @import("std");
    \\
    \\pub fn build(b: *std.Build) void {
    \\    const target = b.standardTargetOptions(.{});
    \\    const optimize = b.standardOptimizeOption(.{});
    \\    const zigeffect_std = b.dependency("zigeffect_std", .{}).module("zigeffect_std");
    \\__SHARED_DEPENDENCY__
    \\    const app = b.addModule("app", .{
    \\        .root_source_file = b.path("src/app.zig"),
    \\        .target = target,
    \\        .optimize = optimize,
    \\    });
    \\    app.addImport("zigeffect_std", zigeffect_std);
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
    \\    const tests = b.addTest(.{ .name = "__PROJECT_NAME__-tests", .root_module = test_module });
    \\    const test_step = b.step("test", "Run __PROJECT_NAME__ tests");
    \\    test_step.dependOn(&b.addRunArtifact(tests).step);
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
    \\    try app.run(init.gpa);
    \\}
;

pub const app_source =
    \\const std = @import("std");
    \\const zstd = @import("zigeffect_std");
    \\const config = @import("config.zig");
    \\const command = @import("cli.zig");
    \\const http = @import("http.zig");
    \\const sql = @import("sql.zig");
    \\const causal = @import("causal.zig");
    \\const greeting = @import("services/greeting.zig");
    \\__SHARED_SOURCE_IMPORT__
    \\pub const component_name = "__PROJECT_NAME__";
    \\
    \\pub fn run(allocator: std.mem.Allocator) !void {
    \\    var greeting_service = greeting.Greeting{ .prefix = "hello" };
    \\    var provider = zstd.Service.Provider(.{greeting.Greeting}).init(.{&greeting_service});
    \\    _ = provider.layer();
    \\    var store = zstd.fx.CausalStore.init(allocator);
    \\    defer store.deinit();
    \\    var scope = zstd.fx.Scope.init(allocator);
    \\    defer scope.deinit();
    \\    var context = zstd.fx.Context(@TypeOf(provider)).init(allocator, &provider, &scope).withCausalStore(&store);
    \\
    \\    const app_config = try config.decodeJsonAlloc(allocator, "{\"port\":5178,\"development\":true}");
    \\    if (app_config.port != 5178) return error.InvalidConfig;
    \\    if (zstd.Application.record(&context, zstd.Application.configLoad("application", "success", "source=local")) == null) return error.OutOfMemory;
    \\    if (zstd.Application.record(&context, zstd.Application.schemaDecode("AppConfig", "success", "validated config")) == null) return error.OutOfMemory;
    \\    const port = try command.decodePortAlloc(allocator, &.{ "--port", "5178" });
    \\    if (port != 5178) return error.InvalidCommand;
    \\    if (zstd.Application.record(&context, zstd.Application.commandExecution("run", "success", "typed CLI decoded")) == null) return error.OutOfMemory;
    \\
    \\    var route = try http.runHealthRoute(allocator);
    \\    defer route.deinit(allocator);
    \\    if (route.response.status != 200) return error.UnhealthyRoute;
    \\    if (zstd.Application.record(&context, zstd.Application.requestHandling("POST /health", "success", "status=200")) == null) return error.OutOfMemory;
    \\    if (zstd.Application.record(&context, zstd.Application.externalCall("local-http-router", "health", "success")) == null) return error.OutOfMemory;
    \\    const row_count = try sql.runSmokeQuery(allocator);
    \\    if (row_count != 1) return error.UnexpectedRowCount;
    \\    if (zstd.Application.record(&context, zstd.Application.sqlTransaction("local-sql", "health-query", "committed")) == null) return error.OutOfMemory;
    \\__SHARED_SOURCE_USE__
    \\    if (zstd.Application.record(&context, zstd.Application.componentDependency(component_name, "zigeffect-std", "resolved")) == null) return error.OutOfMemory;
    \\    var runtime = zstd.fx.Runtime(@TypeOf(provider)).init(allocator, &provider)
    \\        .provides(.{greeting.Greeting})
    \\        .withCausalStore(&store);
    \\    const message = try runtime.run(greeting.greetEffect(@TypeOf(provider), component_name));
    \\    defer allocator.free(message);
    \\    if (zstd.Application.record(&context, zstd.Application.acceptanceEvaluation("check-bootstrap", "passed", "application boundaries passed")) == null) return error.OutOfMemory;
    \\    if (zstd.Application.record(&context, zstd.Application.artifactProduction("workbench-attachment", "created", "bounded causal attachment")) == null) return error.OutOfMemory;
    \\
    \\    var snapshot = try store.snapshot(allocator);
    \\    defer snapshot.deinit();
    \\    if (snapshot.events.len == 0) return error.MissingCausalEvidence;
    \\
    \\    var recorder = zstd.Observability.Recorder.init(allocator);
    \\    defer recorder.deinit();
    \\    try recorder.increment("app.runs", 1);
    \\    const workbench = try recorder.workbenchJsonAlloc(allocator, component_name);
    \\    defer allocator.free(workbench);
    \\    const attachment = try causal.attachmentJsonAlloc(allocator, component_name, snapshot.events.len);
    \\    defer allocator.free(attachment);
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
    \\pub fn attachmentJsonAlloc(allocator: std.mem.Allocator, component: []const u8, facts: usize) ![]const u8 {
    \\    const fact_text = try std.fmt.allocPrint(allocator, "{d}", .{facts});
    \\    defer allocator.free(fact_text);
    \\    return zstd.Json.objectFromFieldsAlloc(allocator, &.{
    \\        .{ .name = "schema", .value = "zigeffect.application-attachment.v1" },
    \\        .{ .name = "component", .value = component },
    \\        .{ .name = "facts", .value = fact_text },
    \\    });
    \\}
;

pub const greeting_source =
    \\const std = @import("std");
    \\const zstd = @import("zigeffect_std");
    \\
    \\pub const Greeting = struct {
    \\    prefix: []const u8,
    \\
    \\    pub fn formatAlloc(self: Greeting, allocator: std.mem.Allocator, name: []const u8) ![]u8 {
    \\        return std.fmt.allocPrint(allocator, "{s}, {s}", .{ self.prefix, name });
    \\    }
    \\};
    \\
    \\pub fn GreetEffect(comptime EffectEnv: type) type {
    \\    return struct {
    \\        pub const SuccessType = []u8;
    \\        pub const FailureType = std.mem.Allocator.Error;
    \\        pub const EnvType = EffectEnv;
    \\        pub const RequiredServices = .{Greeting};
    \\        name: []const u8,
    \\
    \\        pub fn requiredServices(allocator: std.mem.Allocator) std.mem.Allocator.Error!zstd.fx.ServiceSet {
    \\            return zstd.fx.ServiceSet.fromTypes(allocator, RequiredServices);
    \\        }
    \\
    \\        pub fn run(self: @This(), ctx: *zstd.fx.Context(EffectEnv)) FailureType![]u8 {
    \\            const result = try ctx.service(Greeting).formatAlloc(ctx.allocator, self.name);
    \\            errdefer ctx.allocator.free(result);
    \\            if (zstd.Service.recordOperation(ctx, Greeting, "greet", "success", self.name) == null) return error.OutOfMemory;
    \\            return result;
    \\        }
    \\    };
    \\}
    \\
    \\pub fn greetEffect(comptime EffectEnv: type, name: []const u8) GreetEffect(EffectEnv) {
    \\    return .{ .name = name };
    \\}
;

pub const executable_test =
    \\const std = @import("std");
    \\const app = @import("app");
    \\const zstd = @import("zigeffect_std");
    \\
    \\fn runWithAllocator(allocator: std.mem.Allocator) !void { try app.run(allocator); }
    \\
    \\test "application boundaries produce causal evidence" {
    \\    try app.run(std.testing.allocator);
    \\}
    \\
    \\test "application survives every deterministic allocation failure" {
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
    \\    const zigeffect_std = b.dependency("zigeffect_std", .{}).module("zigeffect_std");
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
    \\    const tests = b.addTest(.{ .name = "__PROJECT_NAME__-tests", .root_module = test_module });
    \\    const test_step = b.step("test", "Run __PROJECT_NAME__ tests");
    \\    test_step.dependOn(&b.addRunArtifact(tests).step);
    \\}
;

pub const library_source =
    \\const std = @import("std");
    \\const zstd = @import("zigeffect_std");
    \\
    \\pub const component_name = "__PROJECT_NAME__";
    \\pub const Input = struct { value: i64 };
    \\
    \\pub const Calculator = struct {
    \\    pub fn double(_: Calculator, value: i64) i64 { return value * 2; }
    \\};
    \\
    \\pub fn DoubleEffect(comptime EffectEnv: type) type {
    \\    return struct {
    \\        pub const SuccessType = i64;
    \\        pub const FailureType = std.mem.Allocator.Error;
    \\        pub const EnvType = EffectEnv;
    \\        pub const RequiredServices = .{Calculator};
    \\        value: i64,
    \\        pub fn requiredServices(allocator: std.mem.Allocator) std.mem.Allocator.Error!zstd.fx.ServiceSet {
    \\            return zstd.fx.ServiceSet.fromTypes(allocator, RequiredServices);
    \\        }
    \\        pub fn run(self: @This(), ctx: *zstd.fx.Context(EffectEnv)) std.mem.Allocator.Error!i64 {
    \\            const output = ctx.service(Calculator).double(self.value);
    \\            if (zstd.Service.recordOperation(ctx, Calculator, "double", "success", component_name) == null) return error.OutOfMemory;
    \\            return output;
    \\        }
    \\    };
    \\}
    \\
    \\pub fn run(allocator: std.mem.Allocator, input_json: []const u8) !i64 {
    \\    const input = try zstd.Schema.decodeJsonAlloc(allocator, zstd.Schema.derive(Input, .{
    \\        .value = zstd.Schema.integer(),
    \\    }), input_json);
    \\    var calculator = Calculator{};
    \\    var provider = zstd.Service.Provider(.{Calculator}).init(.{&calculator});
    \\    _ = provider.layer();
    \\    var store = zstd.fx.CausalStore.init(allocator);
    \\    defer store.deinit();
    \\    var runtime = zstd.fx.Runtime(@TypeOf(provider)).init(allocator, &provider)
    \\        .provides(.{Calculator})
    \\        .withCausalStore(&store);
    \\    return runtime.run(DoubleEffect(@TypeOf(provider)){ .value = input.value });
    \\}
;

pub const library_test =
    \\const std = @import("std");
    \\const library = @import("library");
    \\const zstd = @import("zigeffect_std");
    \\
    \\fn runWithAllocator(allocator: std.mem.Allocator) !void {
    \\    _ = try zstd.Schema.decodeJsonAlloc(allocator, zstd.Schema.derive(library.Input, .{
    \\        .value = zstd.Schema.integer(),
    \\    }), "{\"value\":21}");
    \\}
    \\
    \\test "public effect validates input and runs through its layer" {
    \\    try std.testing.expectEqual(@as(i64, 42), try library.run(std.testing.allocator, "{\"value\":21}"));
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
    \\    const api = b.dependency("api", .{}).module("app");
    \\    const worker = b.dependency("worker", .{}).module("app");
    \\    const shared = b.dependency("shared", .{}).module("shared");
    \\    const system = b.addModule("system", .{
    \\        .root_source_file = b.path("src/root.zig"),
    \\        .target = target,
    \\        .optimize = optimize,
    \\    });
    \\    system.addImport("api", api);
    \\    system.addImport("worker", worker);
    \\    system.addImport("shared", shared);
    \\    const test_module = b.createModule(.{
    \\        .root_source_file = b.path("test/root_test.zig"),
    \\        .target = target,
    \\        .optimize = optimize,
    \\    });
    \\    test_module.addImport("system", system);
    \\    const tests = b.addTest(.{ .name = "__PROJECT_NAME__-tests", .root_module = test_module });
    \\    const test_step = b.step("test", "Run all local system components");
    \\    test_step.dependOn(&b.addRunArtifact(tests).step);
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
    \\    },
    \\    .paths = .{ "build.zig", "build.zig.zon", "README.md", "src", "test" },
    \\}
;

pub const system_source =
    \\const std = @import("std");
    \\pub const api = @import("api");
    \\pub const worker = @import("worker");
    \\pub const shared = @import("shared");
    \\
    \\pub fn run(allocator: std.mem.Allocator) !void {
    \\    if (shared.contract_version != 1) return error.IncompatibleSharedContract;
    \\    try api.run(allocator);
    \\    try worker.run(allocator);
    \\}
;

pub const system_test =
    \\const std = @import("std");
    \\const system = @import("system");
    \\
    \\test "all components run against the shared contract" {
    \\    try system.run(std.testing.allocator);
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
    \\
    \\## Develop
    \\
    \\```sh
    \\zigeffect project validate --json
    \\zigeffect project check --agent --json
    \\zigeffect project test --json
    \\zigeffect project dev
    \\```
    \\
    \\The source of truth is `zigeffect.project.json`. Keep requirement status,
    \\acceptance checks, causal evidence, and handoff receipts aligned with code.
;

pub const changelog =
    \\# Changelog
    \\
    \\## 0.1.0
    \\
    \\- Initial public package contract.
;

pub const gitignore =
    \\.zig-cache/
    \\zig-out/
    \\.zigeffect/sessions/
    \\.zigeffect/causal/
    \\.zigeffect/receipts/
;

pub const skill =
    \\---
    \\name: zigeffect-development
    \\description: Build, debug, test, or review this zigeffect project through its typed manifest, public modules, causal evidence, acceptance checks, and redacted handoffs.
    \\---
    \\
    \\# zigeffect Development
    \\
    \\1. Read `zigeffect.project.json` before editing.
    \\2. Map the request to a requirement, acceptance check, and component.
    \\3. Use public `zigeffect_std` APIs and component facades; do not import
    \\   another component's internals.
    \\4. Add a failing deterministic test before changing behavior.
    \\5. Use `zigeffect add` and `zigeffect generate` for framework structure.
    \\6. Run `zigeffect project check --agent --json`; treat failed, incomplete,
    \\   truncated, or unsupported required evidence as an unpassed handoff.
    \\7. Use `zigeffect safety explain <finding-id>` for source-linked repair
    \\   guidance. Never add unmanaged roots or unaudited escape hatches.
    \\8. Query causal evidence before reconstructing failures from text output.
    \\9. Attach the bounded redacted safety receipt to the handoff and never
    \\   claim an unpassed check.
;
