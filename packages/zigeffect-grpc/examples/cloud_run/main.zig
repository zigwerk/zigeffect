const std = @import("std");
const zgrpc = @import("zigeffect_grpc");
const zstd = @import("zigeffect_std");

const proto = zgrpc.ConformanceProto;
const Service = proto.ConformanceService(void, anyerror);

const ConformancePolicyApi = struct {
    pub const operations: []const []const u8 = &.{"ConformancePolicy.unary"};

    pub fn unary(_: *@This(), request: proto.UnaryRequest) proto.UnaryResponse {
        return .{ .id = request.id, .accepted_sequence = request.sequence };
    }
};
const ConformancePolicy = zstd.fx.kernel.Service(
    "example/cloud-run/ConformancePolicy",
    ConformancePolicyApi,
);

const Implementation = struct {
    pub const RequiredServices = .{ConformancePolicy};

    pub fn Unary(_: *@This(), ctx: *zstd.fx.kernel.ContextView(RequiredServices), request: proto.UnaryRequest) !proto.UnaryResponse {
        return ctx.service(ConformancePolicy).unary(request);
    }

    pub fn ClientStream(_: *@This(), ctx: *zstd.fx.kernel.ContextView(RequiredServices), stream: *zgrpc.Typed.Stream(proto.ClientStreamRequest, proto.ClientStreamResponse)) !zgrpc.Grpc.Status {
        _ = ctx.service(ConformancePolicy);
        var count: i64 = 0;
        while (try stream.receive()) |owned_value| {
            var owned = owned_value;
            defer owned.deinit();
            count += 1;
        }
        try stream.send(.{ .accepted_count = count });
        return .ok();
    }

    pub fn ServerStream(_: *@This(), ctx: *zstd.fx.kernel.ContextView(RequiredServices), stream: *zgrpc.Typed.Stream(proto.ServerStreamRequest, proto.ServerStreamResponse)) !zgrpc.Grpc.Status {
        _ = ctx.service(ConformancePolicy);
        var request = (try stream.receive()) orelse return .{ .code = .invalid_argument, .message = "request required" };
        defer request.deinit();
        var sequence: i64 = 0;
        while (sequence < request.value.count) : (sequence += 1) try stream.send(.{ .sequence = sequence });
        return .ok();
    }

    pub fn BidiStream(_: *@This(), ctx: *zstd.fx.kernel.ContextView(RequiredServices), stream: *zgrpc.Typed.Stream(proto.BidiStreamRequest, proto.BidiStreamResponse)) !zgrpc.Grpc.Status {
        _ = ctx.service(ConformancePolicy);
        while (try stream.receive()) |owned_value| {
            var owned = owned_value;
            defer owned.deinit();
            try stream.send(.{ .sequence = owned.value.sequence });
        }
        return .ok();
    }
};
const ImplementationService = zstd.fx.kernel.Service(
    "example/cloud-run/ConformanceImplementation",
    Implementation,
);

fn ServeContext(comptime Runtime: type) type {
    return struct {
        runtime: *Runtime,
        done: std.atomic.Value(bool) = .init(false),
        result: ?anyerror = null,
        report: zgrpc.SupervisorReport = .{},

        fn run(self: *@This()) void {
            self.report = self.runtime.run(zgrpc.serveEffect().named("cloud-run.grpc.serve")) catch |err| {
                self.result = err;
                self.done.store(true, .release);
                return;
            };
            self.done.store(true, .release);
        }
    };
}

pub fn main(init: std.process.Init) !void {
    const port = try std.fmt.parseInt(u16, init.environ_map.get("PORT") orelse "8080", 10);
    var allowed_origins: std.ArrayList([]const u8) = .empty;
    defer allowed_origins.deinit(std.heap.smp_allocator);
    if (init.environ_map.get("CORS_ALLOWED_ORIGINS")) |csv| {
        var values = std.mem.splitScalar(u8, csv, ',');
        while (values.next()) |raw| {
            const origin = std.mem.trim(u8, raw, " \t\r\n");
            if (origin.len != 0) try allowed_origins.append(std.heap.smp_allocator, origin);
        }
    }
    const cors_credentials = std.mem.eql(u8, init.environ_map.get("CORS_ALLOW_CREDENTIALS") orelse "false", "true");

    const service_names = [_][]const u8{
        "zigeffect.grpc.v1.ConformanceService",
        "grpc.health.v1.Health",
        "grpc.channelz.v1.Channelz",
        "grpc.reflection.v1.ServerReflection",
        "grpc.reflection.v1alpha.ServerReflection",
    };
    var telemetry = zgrpc.Middleware.Telemetry{};
    const interceptors = [_]zgrpc.Middleware.Interceptor{telemetry.interceptor()};

    const foundations = zstd.fx.kernel.Layer.mergeAll(.{
        zstd.fx.kernel.Layer.succeed(ConformancePolicy, .{}),
        zstd.fx.kernel.Layer.succeed(ImplementationService, .{}),
        zgrpc.Typed.unaryRegistryLayer(),
        zgrpc.Typed.streamingRegistryLayer(),
        zgrpc.Typed.incrementalRegistryLayer(),
        zgrpc.StandardServices.configLayer(.{
            .service_names = &service_names,
            .initial_health = &.{
                .{ .service = "", .status = .serving },
                .{ .service = "zigeffect.grpc.v1.ConformanceService", .status = .serving },
            },
        }),
        zgrpc.nativeServerConfigLayer(.{
            .io = init.io,
            .options = .{
                .host = "0.0.0.0",
                .port = port,
                .max_connections = 80,
                .max_calls_per_connection = 100_000,
                .goaway_grace_millis = 250,
                .interceptors = &interceptors,
                .cors = .{
                    .allowed_origins = allowed_origins.items,
                    .allow_credentials = cors_credentials,
                },
            },
        }),
        zgrpc.nativeChannelzConfigLayer(.{
            .server_ref = .{ .id = 1, .name = "zigeffect-grpc-cloud-run" },
            .listener_ref = .{ .id = 2, .name = "cloud-run-h2c-listener" },
            .listener_name = "0.0.0.0",
        }),
    });
    const routes = zgrpc.Typed.generatedRoutesLayer(Service, ImplementationService)
        .provideMerge(foundations);
    const standards = zgrpc.StandardServices.layer().provideMerge(routes);
    const server = zgrpc.nativeServerLayer().provideMerge(standards);
    const grpc_layer = zgrpc.nativeChannelzLayer().provideMerge(server);
    const main_layer = zstd.fx.kernel.Layer.mergeAll(.{
        grpc_layer,
        zstd.Application.Lifecycle.managerLayer(),
        zstd.Application.Lifecycle.signalLayer(),
    });
    const Runtime = zstd.ManagedRuntime(@TypeOf(main_layer));
    var runtime = try Runtime.make(
        std.heap.smp_allocator,
        init.io,
        std.Io.Dir.cwd(),
        main_layer,
        .{},
    );
    defer runtime.deinit();

    try runtime.run(zstd.Application.Lifecycle.start().named("cloud-run.lifecycle.start"));
    try runtime.run(zstd.Application.Lifecycle.ready().named("cloud-run.lifecycle.ready"));
    const Serving = ServeContext(Runtime);
    var serving = Serving{ .runtime = &runtime };
    const thread = try std.Thread.spawn(.{}, Serving.run, .{&serving});

    while (zstd.Application.Lifecycle.requestedSignal() == .none and !serving.done.load(.acquire)) {
        init.io.sleep(.fromMilliseconds(25), .awake) catch break;
    }
    try runtime.run(zstd.Application.Lifecycle.drain().named("cloud-run.lifecycle.drain"));
    const shutdown = try runtime.run(zgrpc.shutdownServerEffect(.{
        .deadline_ms = 25_000,
    }).named("cloud-run.grpc.shutdown"));
    thread.join();
    if (serving.result) |err| return err;
    if (shutdown.active_remaining != 0) return error.ShutdownIncomplete;
    try runtime.run(zstd.Application.Lifecycle.stop().named("cloud-run.lifecycle.stop"));
    var application = try runtime.inspect(std.heap.smp_allocator, .{ .max_recent_events = 128 });
    defer application.deinit();
    if (application.services.len < 12 or application.causal.findings.len != 0) return error.InvalidApplicationSnapshot;
    try runtime.shutdown();
}
