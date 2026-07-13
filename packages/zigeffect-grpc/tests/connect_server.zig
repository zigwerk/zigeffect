const std = @import("std");
const zgrpc = @import("zigeffect_grpc");

const proto = zgrpc.ConformanceProto;

const Service = struct {
    fn unary(_: *@This(), request: proto.UnaryRequest) !proto.UnaryResponse {
        return .{ .id = request.id, .accepted_sequence = request.sequence };
    }

    pub fn invokeStreaming(_: *@This(), allocator: std.mem.Allocator, request: zgrpc.Grpc.StreamingRequest) !zgrpc.Grpc.StreamingResponse {
        if (request.shape != .server_streaming or request.messages.len != 1) return error.InvalidStreamingRequest;
        var decoded = try zgrpc.Typed.decodeAlloc(proto.ServerStreamRequest, allocator, request.messages[0]);
        defer decoded.deinit(allocator);
        if (decoded.count < 0 or decoded.count > 32) return error.InvalidStreamingRequest;
        const encoded = try allocator.alloc([]u8, @intCast(decoded.count));
        defer allocator.free(encoded);
        var initialized: usize = 0;
        defer for (encoded[0..initialized]) |bytes| allocator.free(bytes);
        for (encoded, 0..) |*bytes, index| {
            bytes.* = try zgrpc.Typed.encodeAlloc(allocator, proto.ServerStreamResponse{ .sequence = @intCast(index) });
            initialized += 1;
        }
        const borrowed = try allocator.alloc([]const u8, encoded.len);
        defer allocator.free(borrowed);
        for (encoded, 0..) |bytes, index| borrowed[index] = bytes;
        const request_id = for (request.metadata) |entry| {
            if (std.mem.eql(u8, entry.name, "request-id")) break entry.value;
        } else "missing";
        const initial = [_]zgrpc.Grpc.Metadata{.{ .name = "request-id", .value = request_id }};
        const trailing = [_]zgrpc.Grpc.Metadata{.{ .name = "stream-complete", .value = "true" }};
        return zgrpc.Grpc.StreamingResponse.initFullAlloc(allocator, borrowed, .{
            .initial_metadata = &initial,
            .trailing_metadata = &trailing,
            .status = .ok(),
        });
    }
};

const IncrementalServerStream = struct {
    allocator: std.mem.Allocator,

    pub fn runIncremental(self: *@This(), call: *zgrpc.Incremental.Call) !zgrpc.Grpc.Status {
        const request_id = for (call.context.metadata) |entry| {
            if (std.mem.eql(u8, entry.name, "request-id")) break entry.value;
        } else "missing";
        const initial = [_]zgrpc.Grpc.Metadata{.{ .name = "request-id", .value = request_id }};
        try call.sendHeaders(&initial);
        var request_message = (try call.receive()) orelse return .{ .code = .invalid_argument, .message = "request required" };
        defer request_message.deinit();
        var request = try zgrpc.Typed.decodeAlloc(proto.ServerStreamRequest, self.allocator, request_message.bytes);
        defer request.deinit(self.allocator);
        if (request.count < 0) return .{ .code = .invalid_argument, .message = "count must be non-negative" };
        if (request.count > 32) return .{ .code = .resource_exhausted, .message = "count exceeds test bound" };
        var sequence: i64 = 0;
        while (sequence < request.count) : (sequence += 1) {
            const encoded = try zgrpc.Typed.encodeAlloc(self.allocator, proto.ServerStreamResponse{ .sequence = sequence });
            defer self.allocator.free(encoded);
            try call.sendAlloc(self.allocator, encoded);
            if (sequence + 1 < request.count) try call.sleep(25);
        }
        const trailing = [_]zgrpc.Grpc.Metadata{.{ .name = "stream-complete", .value = "true" }};
        try call.setTrailers(&trailing);
        return .ok();
    }
};

pub fn main(init: std.process.Init) !void {
    var debug_allocator: std.heap.DebugAllocator(.{}) = .init;
    defer if (debug_allocator.deinit() == .leak) @panic("connect server leaked memory");
    const allocator = debug_allocator.allocator();
    var args = std.process.Args.Iterator.init(init.minimal.args);
    _ = args.next();
    const port = try std.fmt.parseInt(u16, args.next() orelse return error.MissingPort, 10);
    var service = Service{};
    var unary = zgrpc.Typed.UnaryBinding(proto.UnaryRequest, proto.UnaryResponse, Service, Service.unary){ .context = &service };
    var registry = zgrpc.Grpc.Registry.init(allocator);
    defer registry.deinit();
    try registry.register(.{
        .service = "zigeffect.grpc.v1.ConformanceService",
        .method = "Unary",
        .handler = unary.handler(),
    });
    var streaming = zgrpc.Grpc.StreamingRegistry.init(allocator);
    defer streaming.deinit();
    try streaming.register(
        "zigeffect.grpc.v1.ConformanceService",
        "ServerStream",
        .server_streaming,
        zgrpc.Grpc.StreamingHandler.from(Service, &service),
    );
    var incremental_handler = IncrementalServerStream{ .allocator = allocator };
    var incremental = zgrpc.Incremental.Registry.init(allocator);
    defer incremental.deinit();
    try incremental.register(
        "zigeffect.grpc.v1.ConformanceService",
        "ServerStream",
        .server_streaming,
        zgrpc.Incremental.Handler.from(IncrementalServerStream, &incremental_handler),
    );
    const origins = [_][]const u8{"http://localhost:39052"};
    var server = try zgrpc.NativeServer.initStreaming(allocator, init.io, .{
        .host = "0.0.0.0",
        .port = port,
        .max_connections = 4,
        .max_calls_per_connection = 100,
        .response_compression = .gzip,
        .cors = .{ .allowed_origins = &origins },
    }, &registry, &streaming);
    defer server.deinit();
    try server.installIncremental(&incremental);
    _ = try server.serve();
}
