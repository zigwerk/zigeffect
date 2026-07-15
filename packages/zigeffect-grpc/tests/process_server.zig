const std = @import("std");
const zgrpc = @import("zigeffect_grpc");

const Echo = struct {
    pub fn invoke(_: *@This(), allocator: std.mem.Allocator, request: zgrpc.Grpc.UnaryRequest) anyerror!zgrpc.Grpc.UnaryResponse {
        return zgrpc.Grpc.UnaryResponse.initAlloc(allocator, request.payload, .ok());
    }
};

const Streams = struct {
    pub fn invokeStreaming(_: *@This(), allocator: std.mem.Allocator, request: zgrpc.Grpc.StreamingRequest) anyerror!zgrpc.Grpc.StreamingResponse {
        return switch (request.shape) {
            .client_streaming => zgrpc.Grpc.StreamingResponse.initAlloc(allocator, &.{"received-two"}, .ok()),
            .server_streaming => zgrpc.Grpc.StreamingResponse.initAlloc(allocator, &.{ "part-one", "part-two" }, .ok()),
            .bidirectional_streaming => zgrpc.Grpc.StreamingResponse.initAlloc(allocator, request.messages, .ok()),
            .unary => error.InvalidCallShape,
        };
    }
};

const IncrementalChat = struct {
    pub fn runIncremental(_: *@This(), call: *zgrpc.Incremental.Call) anyerror!zgrpc.Grpc.Status {
        while (try call.receive()) |value| {
            var message = value;
            defer message.deinit();
            try call.sendAlloc(std.heap.page_allocator, message.bytes);
        }
        return .ok();
    }
};

pub fn main(init: std.process.Init) !void {
    var args = std.process.Args.Iterator.init(init.minimal.args);
    _ = args.next();
    const port_text = args.next() orelse return error.MissingPort;
    const port = try std.fmt.parseInt(u16, port_text, 10);
    const mode = args.next() orelse "plaintext";

    var echo = Echo{};
    var registry = zgrpc.Grpc.Registry.init(std.heap.page_allocator);
    defer registry.deinit();
    try registry.register(.{
        .service = "example.v1.Echo",
        .method = "Say",
        .handler = zgrpc.Grpc.UnaryHandler.from(Echo, &echo),
    });
    var streams = Streams{};
    var streaming_registry = zgrpc.Grpc.StreamingRegistry.init(std.heap.page_allocator);
    defer streaming_registry.deinit();
    try streaming_registry.register("example.v1.Stream", "Upload", .client_streaming, zgrpc.Grpc.StreamingHandler.from(Streams, &streams));
    try streaming_registry.register("example.v1.Stream", "Download", .server_streaming, zgrpc.Grpc.StreamingHandler.from(Streams, &streams));
    try streaming_registry.register("example.v1.Stream", "Chat", .bidirectional_streaming, zgrpc.Grpc.StreamingHandler.from(Streams, &streams));
    var incremental_chat = IncrementalChat{};
    var incremental_registry = zgrpc.Incremental.Registry.init(std.heap.page_allocator);
    defer incremental_registry.deinit();
    try incremental_registry.register("example.v1.Stream", "Chat", .bidirectional_streaming, zgrpc.Incremental.Handler.from(IncrementalChat, &incremental_chat));

    var options = zgrpc.ServerOptions{ .port = port, .max_calls_per_connection = 4 };
    if (std.mem.eql(u8, mode, "tls")) {
        const certificate = args.next() orelse return error.MissingCertificate;
        const key = args.next() orelse return error.MissingPrivateKey;
        options.tls = .{ .certificate_chain_path = certificate, .private_key_path = key };
    }
    var server = try zgrpc.NativeServer.initStreaming(std.heap.page_allocator, init.io, options, &registry, &streaming_registry);
    defer server.deinit();
    try server.installIncremental(&incremental_registry);
    try server.serveOne();
}
