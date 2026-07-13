const std = @import("std");
const zgrpc = @import("zigeffect_grpc");
const zstd = @import("zigeffect_std");

const proto = zgrpc.ConformanceProto;
const Service = proto.ConformanceService(void, anyerror);

const ConformanceService = struct {
    pub fn Unary(_: *@This(), request: proto.UnaryRequest) !proto.UnaryResponse {
        return .{ .id = request.id, .accepted_sequence = request.sequence };
    }

    pub fn ClientStream(_: *@This(), stream: *zgrpc.Typed.Stream(proto.ClientStreamRequest, proto.ClientStreamResponse)) !zgrpc.Grpc.Status {
        var count: i64 = 0;
        while (try stream.receive()) |owned_value| {
            var owned = owned_value;
            defer owned.deinit();
            count += 1;
        }
        try stream.send(.{ .accepted_count = count });
        return .ok();
    }

    pub fn ServerStream(_: *@This(), stream: *zgrpc.Typed.Stream(proto.ServerStreamRequest, proto.ServerStreamResponse)) !zgrpc.Grpc.Status {
        var request = (try stream.receive()) orelse return .{ .code = .invalid_argument, .message = "request required" };
        defer request.deinit();
        var sequence: i64 = 0;
        while (sequence < request.value.count) : (sequence += 1) try stream.send(.{ .sequence = sequence });
        return .ok();
    }

    pub fn BidiStream(_: *@This(), stream: *zgrpc.Typed.Stream(proto.BidiStreamRequest, proto.BidiStreamResponse)) !zgrpc.Grpc.Status {
        while (try stream.receive()) |owned_value| {
            var owned = owned_value;
            defer owned.deinit();
            try stream.send(.{ .sequence = owned.value.sequence });
        }
        return .ok();
    }
};

const ServeContext = struct {
    server: *zgrpc.NativeServer,
    result: ?anyerror = null,
    report: zgrpc.SupervisorReport = .{},

    fn run(self: *@This()) void {
        self.report = self.server.serve() catch |err| {
            if (self.server.ready()) self.result = err;
            return;
        };
    }
};

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

    var service = ConformanceService{};
    var unary = zgrpc.Grpc.Registry.init(std.heap.smp_allocator);
    defer unary.deinit();
    var streaming = zgrpc.Grpc.StreamingRegistry.init(std.heap.smp_allocator);
    defer streaming.deinit();
    var incremental = zgrpc.Incremental.Registry.init(std.heap.smp_allocator);
    defer incremental.deinit();
    var generated = zgrpc.Typed.GeneratedServer(Service, ConformanceService).init(std.heap.smp_allocator, &service);
    try generated.registerAll(&unary, &incremental);
    var health = zgrpc.Grpc.HealthRegistry.init(std.heap.smp_allocator);
    defer health.deinit();
    try health.set("", .serving);
    try health.set("zigeffect.grpc.v1.ConformanceService", .serving);
    const service_names = [_][]const u8{
        "zigeffect.grpc.v1.ConformanceService",
        "grpc.health.v1.Health",
        "grpc.channelz.v1.Channelz",
        "grpc.reflection.v1.ServerReflection",
        "grpc.reflection.v1alpha.ServerReflection",
    };
    var standard = zgrpc.StandardServices.Services{
        .health = &health,
        .service_names = &service_names,
    };
    try standard.install(&unary, &streaming);
    try standard.installIncremental(&incremental);

    var telemetry = zgrpc.Middleware.Telemetry{};
    const interceptors = [_]zgrpc.Middleware.Interceptor{telemetry.interceptor()};
    var server = try zgrpc.NativeServer.initStreaming(std.heap.smp_allocator, init.io, .{
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
    }, &unary, &streaming);
    defer server.deinit();
    try server.installIncremental(&incremental);

    const listen_socket_refs = [_]zgrpc.Channelz.Ref{.{ .id = 2, .name = "cloud-run-h2c-listener" }};
    var channelz_registry = zgrpc.Channelz.Registry.init(std.heap.smp_allocator);
    defer channelz_registry.deinit();
    var server_channelz = zgrpc.NativeServerChannelz{
        .server = &server,
        .ref = .{ .id = 1, .name = "zigeffect-grpc-cloud-run" },
        .listen_socket_refs = &listen_socket_refs,
    };
    var listener_channelz = zgrpc.NativeServerSocketChannelz{
        .server = &server,
        .server_id = 1,
        .ref = listen_socket_refs[0],
        .name = "0.0.0.0",
    };
    try channelz_registry.registerServer(zgrpc.Channelz.ServerSource.from(zgrpc.NativeServerChannelz, &server_channelz));
    try channelz_registry.registerSocket(zgrpc.Channelz.SocketSource.from(zgrpc.NativeServerSocketChannelz, &listener_channelz));
    var channelz_service = zgrpc.Channelz.Service{ .registry = &channelz_registry };
    try channelz_service.install(&unary);

    var signals = try zstd.Application.Lifecycle.SignalRegistration.install();
    defer signals.deinit();
    var serving = ServeContext{ .server = &server };
    const thread = try std.Thread.spawn(.{}, ServeContext.run, .{&serving});

    while (zstd.Application.Lifecycle.requestedSignal() == .none and serving.result == null) {
        init.io.sleep(.fromMilliseconds(25), .awake) catch break;
    }
    const shutdown = try server.shutdown(.{ .deadline_ms = 25_000 });
    thread.join();
    if (serving.result) |err| return err;
    if (shutdown.active_remaining != 0) return error.ShutdownIncomplete;
}
