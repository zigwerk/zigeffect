const std = @import("std");
const zstd = @import("zigeffect_std");

const Echo = struct {
    pub fn invoke(_: *@This(), allocator: std.mem.Allocator, request: zstd.Grpc.UnaryRequest) anyerror!zstd.Grpc.UnaryResponse {
        return zstd.Grpc.UnaryResponse.initAlloc(allocator, request.payload, .ok());
    }
};

pub fn runGrpcUnaryExample(allocator: std.mem.Allocator) !zstd.Grpc.UnaryResponse {
    var echo = Echo{};
    var registry = zstd.Grpc.Registry.init(allocator);
    defer registry.deinit();
    try registry.register(.{
        .service = "example.v1.Echo",
        .method = "Say",
        .handler = zstd.Grpc.UnaryHandler.from(Echo, &echo),
    });

    var client = zstd.Grpc.InProcessClient.init(&registry);
    return client.invokeAlloc(allocator, .{
        .authority = "local",
        .service = "example.v1.Echo",
        .method = "Say",
        .payload = "hello from ZigEffect gRPC",
        .timeout_millis = 1000,
    }, .{});
}

pub fn main() !void {
    var response = try runGrpcUnaryExample(std.heap.page_allocator);
    defer response.deinit();
    std.debug.print("{s}\n", .{response.payload});
}

test "gRPC unary example routes through the one-import facade" {
    var response = try runGrpcUnaryExample(std.testing.allocator);
    defer response.deinit();
    try std.testing.expectEqualStrings("hello from ZigEffect gRPC", response.payload);
    try std.testing.expect(response.status.isOk());
}
