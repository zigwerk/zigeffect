const std = @import("std");
const zstd = @import("zigeffect_std");

const Echo = struct {
    pub fn invoke(_: *@This(), allocator: std.mem.Allocator, request: zstd.Grpc.UnaryRequest) anyerror!zstd.Grpc.UnaryResponse {
        return zstd.Grpc.UnaryResponse.initAlloc(allocator, request.payload, .ok());
    }
};

pub fn runGrpcUnaryExample(
    allocator: std.mem.Allocator,
    io: std.Io,
    root: std.Io.Dir,
) !zstd.Grpc.UnaryResponse {
    var echo = Echo{};
    var registry = zstd.Grpc.Registry.init(allocator);
    defer registry.deinit();
    try registry.register(.{
        .service = "example.v1.Echo",
        .method = "Say",
        .handler = zstd.Grpc.UnaryHandler.from(Echo, &echo),
    });

    var client = zstd.Grpc.InProcessClient.init(&registry);
    const layer = zstd.Grpc.clientLayer(client.client());
    var runtime = try zstd.ManagedRuntime(@TypeOf(layer)).make(allocator, io, root, layer, .{});
    defer runtime.deinit();
    const response = try runtime.run(zstd.Grpc.call(.{
        .authority = "local",
        .service = "example.v1.Echo",
        .method = "Say",
        .payload = "hello from ZigEffect gRPC",
        .timeout_millis = 1000,
    }, .{}).named("example.grpc.echo"));
    try runtime.shutdown();
    return response;
}

pub fn main(init: std.process.Init) !void {
    var response = try runGrpcUnaryExample(std.heap.page_allocator, init.io, std.Io.Dir.cwd());
    defer response.deinit();
    std.debug.print("{s}\n", .{response.payload});
}

test "gRPC unary example routes through a layered effect from the one-import facade" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    var response = try runGrpcUnaryExample(std.testing.allocator, std.testing.io, tmp.dir);
    defer response.deinit();
    try std.testing.expectEqualStrings("hello from ZigEffect gRPC", response.payload);
    try std.testing.expect(response.status.isOk());
}
