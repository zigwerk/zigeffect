const std = @import("std");
const zgrpc = @import("zigeffect_grpc");

const Grpc = zgrpc.Grpc;
const proto = zgrpc.OfficialInteropProto;
const service_name = "grpc.testing.TestService";
const authority = "foo.test.google.fr";
const echo_initial = "x-grpc-test-echo-initial";
const echo_trailing = "x-grpc-test-echo-trailing-bin";

fn expect(condition: bool, err: anyerror) !void {
    if (!condition) return err;
}

fn metadataValue(entries: []const Grpc.Metadata, name: []const u8) ?[]const u8 {
    for (entries) |entry| if (std.mem.eql(u8, entry.name, name)) return entry.value;
    return null;
}

fn unary(
    client: *zgrpc.NativeClient,
    allocator: std.mem.Allocator,
    method: []const u8,
    payload: []const u8,
    metadata: []const Grpc.Metadata,
    timeout_millis: u64,
) !Grpc.UnaryResponse {
    return client.invokeAlloc(allocator, .{
        .authority = authority,
        .service = service_name,
        .method = method,
        .payload = payload,
        .metadata = metadata,
        .timeout_millis = timeout_millis,
    }, .{ .timeout_millis = timeout_millis });
}

fn streaming(
    client: *zgrpc.NativeClient,
    allocator: std.mem.Allocator,
    method: []const u8,
    messages: []const []const u8,
    metadata: []const Grpc.Metadata,
    shape: Grpc.CallShape,
) !Grpc.StreamingResponse {
    return client.invokeStreamingAlloc(allocator, .{
        .authority = authority,
        .service = service_name,
        .method = method,
        .messages = messages,
        .metadata = metadata,
        .timeout_millis = 10_000,
        .shape = shape,
    }, .{ .timeout_millis = 10_000 });
}

fn emptyUnary(client: *zgrpc.NativeClient, allocator: std.mem.Allocator) !void {
    const encoded = try zgrpc.Typed.encodeAlloc(allocator, proto.Empty{});
    defer allocator.free(encoded);
    var response = try unary(client, allocator, "EmptyCall", encoded, &.{}, 10_000);
    defer response.deinit();
    try expect(response.status.isOk(), error.EmptyUnaryStatus);
    var decoded = try zgrpc.Typed.decodeAlloc(proto.Empty, allocator, response.payload);
    defer decoded.deinit(allocator);
}

fn largeUnary(client: *zgrpc.NativeClient, allocator: std.mem.Allocator) !void {
    const request_body = try allocator.alloc(u8, 271_828);
    defer allocator.free(request_body);
    @memset(request_body, 0);
    const encoded = try zgrpc.Typed.encodeAlloc(allocator, proto.SimpleRequest{
        .response_type = .COMPRESSABLE,
        .response_size = 314_159,
        .payload = .{ .type = .COMPRESSABLE, .body = request_body },
    });
    defer allocator.free(encoded);
    var response = try unary(client, allocator, "UnaryCall", encoded, &.{}, 10_000);
    defer response.deinit();
    try expect(response.status.isOk(), error.LargeUnaryStatus);
    var decoded = try zgrpc.Typed.decodeAlloc(proto.SimpleResponse, allocator, response.payload);
    defer decoded.deinit(allocator);
    const payload = decoded.payload orelse return error.MissingPayload;
    try expect(payload.type == .COMPRESSABLE and payload.body.len == 314_159, error.LargeUnaryPayload);
}

fn serverStreaming(client: *zgrpc.NativeClient, allocator: std.mem.Allocator) !void {
    const sizes = [_]i32{ 31_415, 9, 2_653, 58_979 };
    var request = proto.StreamingOutputCallRequest{ .response_type = .COMPRESSABLE };
    defer request.response_parameters.deinit(allocator);
    for (sizes) |size| try request.response_parameters.append(allocator, .{ .size = size });
    const encoded = try zgrpc.Typed.encodeAlloc(allocator, request);
    defer allocator.free(encoded);
    var response = try streaming(client, allocator, "StreamingOutputCall", &.{encoded}, &.{}, .server_streaming);
    defer response.deinit();
    try expect(response.status.isOk() and response.messages.len == sizes.len, error.ServerStreamingStatus);
    for (response.messages, sizes) |message, size| {
        var decoded = try zgrpc.Typed.decodeAlloc(proto.StreamingOutputCallResponse, allocator, message);
        defer decoded.deinit(allocator);
        const payload = decoded.payload orelse return error.MissingPayload;
        try expect(payload.type == .COMPRESSABLE and payload.body.len == @as(usize, @intCast(size)), error.ServerStreamingPayload);
    }
}

fn clientStreaming(client: *zgrpc.NativeClient, allocator: std.mem.Allocator) !void {
    const sizes = [_]usize{ 27_182, 8, 1_828, 45_904 };
    var encoded: [sizes.len][]u8 = undefined;
    var initialized: usize = 0;
    defer for (encoded[0..initialized]) |message| allocator.free(message);
    for (sizes, 0..) |size, index| {
        const body = try allocator.alloc(u8, size);
        defer allocator.free(body);
        @memset(body, 0);
        encoded[index] = try zgrpc.Typed.encodeAlloc(allocator, proto.StreamingInputCallRequest{
            .payload = .{ .type = .COMPRESSABLE, .body = body },
        });
        initialized += 1;
    }
    var response = try streaming(client, allocator, "StreamingInputCall", &encoded, &.{}, .client_streaming);
    defer response.deinit();
    try expect(response.status.isOk() and response.messages.len == 1, error.ClientStreamingStatus);
    var decoded = try zgrpc.Typed.decodeAlloc(proto.StreamingInputCallResponse, allocator, response.messages[0]);
    defer decoded.deinit(allocator);
    try expect(decoded.aggregated_payload_size == 74_922, error.ClientStreamingPayload);
}

fn openBidi(channel: *zgrpc.PersistentChannel, metadata: []const Grpc.Metadata, timeout_millis: u64) !zgrpc.IncrementalClientStream {
    return channel.openIncrementalStream(.{
        .authority = authority,
        .service = service_name,
        .method = "FullDuplexCall",
        .metadata = metadata,
        .timeout_millis = timeout_millis,
        .shape = .bidirectional_streaming,
    }, 8);
}

fn makeDuplexRequest(allocator: std.mem.Allocator, response_size: i32, payload_size: usize, status: ?proto.EchoStatus) ![]u8 {
    const body = try allocator.alloc(u8, payload_size);
    defer allocator.free(body);
    @memset(body, 0);
    var request = proto.StreamingOutputCallRequest{
        .response_type = .COMPRESSABLE,
        .payload = .{ .type = .COMPRESSABLE, .body = body },
        .response_status = status,
    };
    defer request.response_parameters.deinit(allocator);
    if (response_size >= 0) try request.response_parameters.append(allocator, .{ .size = response_size });
    return zgrpc.Typed.encodeAlloc(allocator, request);
}

fn pingPong(channel: *zgrpc.PersistentChannel, allocator: std.mem.Allocator) !void {
    const response_sizes = [_]i32{ 31_415, 9, 2_653, 58_979 };
    const payload_sizes = [_]usize{ 27_182, 8, 1_828, 45_904 };
    var stream = try openBidi(channel, &.{}, 10_000);
    defer stream.deinit();
    for (response_sizes, payload_sizes) |response_size, payload_size| {
        const encoded = try makeDuplexRequest(allocator, response_size, payload_size, null);
        defer allocator.free(encoded);
        try stream.sendAlloc(encoded);
        var message = (try stream.receive()) orelse return error.MissingPingPongResponse;
        defer message.deinit();
        var decoded = try zgrpc.Typed.decodeAlloc(proto.StreamingOutputCallResponse, allocator, message.bytes);
        defer decoded.deinit(allocator);
        const payload = decoded.payload orelse return error.MissingPayload;
        try expect(payload.type == .COMPRESSABLE and payload.body.len == @as(usize, @intCast(response_size)), error.PingPongPayload);
    }
    stream.closeSend();
    try expect((try stream.receive()) == null, error.ExtraPingPongResponse);
    var result = try stream.finishAlloc(allocator);
    defer result.deinit();
    try expect(result.status.isOk(), error.PingPongStatus);
}

fn cancellationCases(channel: *zgrpc.PersistentChannel, allocator: std.mem.Allocator) !void {
    {
        var stream = try channel.openIncrementalStream(.{
            .authority = authority,
            .service = service_name,
            .method = "StreamingInputCall",
            .timeout_millis = 10_000,
            .shape = .client_streaming,
        }, 2);
        defer stream.deinit();
        stream.cancel();
        _ = stream.receive() catch |err| {
            try expect(err == error.CallCancelled, error.CancelAfterBeginStatus);
            return;
        };
        return error.CancelAfterBeginDidNotCancel;
    }
    _ = allocator;
}

fn cancelAfterFirstResponse(channel: *zgrpc.PersistentChannel, allocator: std.mem.Allocator) !void {
    var stream = try openBidi(channel, &.{}, 10_000);
    defer stream.deinit();
    const encoded = try makeDuplexRequest(allocator, 31_415, 27_182, null);
    defer allocator.free(encoded);
    try stream.sendAlloc(encoded);
    var first = (try stream.receive()) orelse return error.MissingCancelResponse;
    first.deinit();
    stream.cancel();
    _ = stream.receive() catch |err| {
        try expect(err == error.CallCancelled, error.CancelAfterResponseStatus);
        return;
    };
    return error.CancelAfterResponseDidNotCancel;
}

fn timeoutCase(channel: *zgrpc.PersistentChannel, allocator: std.mem.Allocator) !void {
    var stream = try openBidi(channel, &.{}, 1);
    defer stream.deinit();
    const encoded = try makeDuplexRequest(allocator, -1, 27_182, null);
    defer allocator.free(encoded);
    try stream.sendAlloc(encoded);
    const received = stream.receive() catch |err| {
        try expect(err == error.DeadlineExceeded, error.TimeoutStatus);
        return;
    };
    try expect(received == null, error.UnexpectedTimeoutResponse);
    var response = try stream.finishAlloc(allocator);
    defer response.deinit();
    try expect(response.status.code == .deadline_exceeded, error.TimeoutStatus);
}

fn emptyStream(channel: *zgrpc.PersistentChannel, allocator: std.mem.Allocator) !void {
    var stream = try openBidi(channel, &.{}, 10_000);
    defer stream.deinit();
    stream.closeSend();
    try expect((try stream.receive()) == null, error.UnexpectedEmptyStreamResponse);
    var response = try stream.finishAlloc(allocator);
    defer response.deinit();
    try expect(response.status.isOk(), error.EmptyStreamStatus);
}

fn statusCases(client: *zgrpc.NativeClient, allocator: std.mem.Allocator) !void {
    const messages = [_][]const u8{
        "test status message",
        "\t\ntest with whitespace\r\nand Unicode BMP \xe2\x98\xba and non-BMP \xf0\x9f\x98\x88\t\n",
    };
    for (messages) |message| {
        const encoded = try zgrpc.Typed.encodeAlloc(allocator, proto.SimpleRequest{
            .response_type = .COMPRESSABLE,
            .response_size = 1,
            .payload = .{ .type = .COMPRESSABLE, .body = "\x00" },
            .response_status = .{ .code = 2, .message = message },
        });
        defer allocator.free(encoded);
        var response = try unary(client, allocator, "UnaryCall", encoded, &.{}, 10_000);
        defer response.deinit();
        try expect(response.status.code == .unknown and std.mem.eql(u8, response.status.message, message), error.UnaryStatusMismatch);
    }

    const encoded = try makeDuplexRequest(allocator, 1, 1, .{ .code = 2, .message = messages[0] });
    defer allocator.free(encoded);
    var response = try streaming(client, allocator, "FullDuplexCall", &.{encoded}, &.{}, .bidirectional_streaming);
    defer response.deinit();
    try expect(response.status.code == .unknown and std.mem.eql(u8, response.status.message, messages[0]), error.StreamStatusMismatch);
}

fn metadataCase(client: *zgrpc.NativeClient, allocator: std.mem.Allocator) !void {
    const trailing = "\x0a\x0b\x0a\x0b\x0a\x0b";
    const metadata = [_]Grpc.Metadata{
        .{ .name = echo_initial, .value = "test_initial_metadata_value" },
        .{ .name = echo_trailing, .value = trailing, .kind = .binary },
    };
    const encoded = try zgrpc.Typed.encodeAlloc(allocator, proto.SimpleRequest{
        .response_type = .COMPRESSABLE,
        .response_size = 1,
        .payload = .{ .type = .COMPRESSABLE, .body = "\x00" },
    });
    defer allocator.free(encoded);
    var unary_response = try unary(client, allocator, "UnaryCall", encoded, &metadata, 10_000);
    defer unary_response.deinit();
    try expect(std.mem.eql(u8, metadataValue(unary_response.initial_metadata, echo_initial) orelse return error.MissingInitialMetadata, metadata[0].value), error.InitialMetadataMismatch);
    try expect(std.mem.eql(u8, metadataValue(unary_response.trailing_metadata, echo_trailing) orelse return error.MissingTrailingMetadata, trailing), error.TrailingMetadataMismatch);

    const duplex = try makeDuplexRequest(allocator, 1, 0, null);
    defer allocator.free(duplex);
    var stream_response = try streaming(client, allocator, "FullDuplexCall", &.{duplex}, &metadata, .bidirectional_streaming);
    defer stream_response.deinit();
    try expect(std.mem.eql(u8, metadataValue(stream_response.initial_metadata, echo_initial) orelse return error.MissingInitialMetadata, metadata[0].value), error.InitialMetadataMismatch);
    try expect(std.mem.eql(u8, metadataValue(stream_response.trailing_metadata, echo_trailing) orelse return error.MissingTrailingMetadata, trailing), error.TrailingMetadataMismatch);
}

fn unimplementedCases(client: *zgrpc.NativeClient, allocator: std.mem.Allocator) !void {
    const encoded = try zgrpc.Typed.encodeAlloc(allocator, proto.Empty{});
    defer allocator.free(encoded);
    var method = try unary(client, allocator, "UnimplementedCall", encoded, &.{}, 10_000);
    defer method.deinit();
    try expect(method.status.code == .unimplemented, error.UnimplementedMethodStatus);
    var service = try client.invokeAlloc(allocator, .{
        .authority = authority,
        .service = "grpc.testing.UnimplementedService",
        .method = "UnimplementedCall",
        .payload = encoded,
        .timeout_millis = 10_000,
    }, .{ .timeout_millis = 10_000 });
    defer service.deinit();
    try expect(service.status.code == .unimplemented, error.UnimplementedServiceStatus);
}

pub fn main(init: std.process.Init) !void {
    var debug_allocator: std.heap.DebugAllocator(.{}) = .init;
    defer if (debug_allocator.deinit() == .leak) @panic("official interop client leaked memory");
    const allocator = debug_allocator.allocator();
    var args = std.process.Args.Iterator.init(init.minimal.args);
    _ = args.next();
    const port = try std.fmt.parseInt(u16, args.next() orelse return error.MissingPort, 10);
    const mode = args.next() orelse return error.MissingMode;
    const certificate = args.next();
    var options = zgrpc.ClientOptions{ .port = port, .keepalive_interval_millis = null };
    if (std.mem.eql(u8, mode, "tls")) options.tls = .{
        .ca_path = certificate orelse return error.MissingCertificate,
        .server_name = authority,
    };
    var native = try zgrpc.NativeClient.init(allocator, init.io, options);
    var channel = try zgrpc.PersistentChannel.init(allocator, init.io, options);
    defer channel.deinit();

    try emptyUnary(&native, allocator);
    try largeUnary(&native, allocator);
    try serverStreaming(&native, allocator);
    try clientStreaming(&native, allocator);
    try pingPong(&channel, allocator);
    try timeoutCase(&channel, allocator);
    try cancellationCases(&channel, allocator);
    try cancelAfterFirstResponse(&channel, allocator);
    try emptyStream(&channel, allocator);
    try statusCases(&native, allocator);
    try metadataCase(&native, allocator);
    try unimplementedCases(&native, allocator);
}
