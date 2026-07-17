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

    const business = zstd.fx.kernel.Layer.mergeAll(.{
        zstd.fx.kernel.Layer.succeed(ConformancePolicy, .{}),
        zstd.fx.kernel.Layer.succeed(ImplementationService, .{}),
    });
    const live = zgrpc.Application.layer(Service, ImplementationService, business, .{
        .name = "zigeffect-grpc-cloud-run",
        .server = .{
            .io = init.io,
            .options = .{
                .host = "0.0.0.0",
                .port = port,
                .max_connections = 80,
                .max_calls_per_connection = 100_000,
                .goaway_grace_millis = 250,
                .cors = .{
                    .allowed_origins = allowed_origins.items,
                    .allow_credentials = cors_credentials,
                },
            },
        },
    });
    const Runtime = zstd.ManagedRuntime(@TypeOf(live));
    var runtime = try Runtime.make(
        std.heap.smp_allocator,
        init.io,
        std.Io.Dir.cwd(),
        live,
        .{},
    );
    defer runtime.deinit();
    _ = try zgrpc.Application.run(&runtime, init.io, .{});
}
