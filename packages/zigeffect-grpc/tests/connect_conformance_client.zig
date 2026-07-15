const std = @import("std");
const zgrpc = @import("zigeffect_grpc");
const zstd = @import("zigeffect_std");

const Grpc = zgrpc.Grpc;
const proto = zgrpc.ConnectConformanceProto;
const default_service = "connectrpc.conformance.v1.ConformanceService";

fn readRequest(reader: *std.Io.Reader, allocator: std.mem.Allocator) !?proto.ClientCompatRequest {
    var prefix: [4]u8 = undefined;
    const prefix_bytes = try reader.readSliceShort(&prefix);
    if (prefix_bytes == 0) return null;
    if (prefix_bytes != prefix.len) return error.TruncatedCompatRequest;
    const length: usize = std.mem.readInt(u32, &prefix, .big);
    if (length == 0 or length > 16 * 1024 * 1024) return error.InvalidCompatRequest;
    const bytes = try allocator.alloc(u8, length);
    defer allocator.free(bytes);
    try reader.readSliceAll(bytes);
    return try zgrpc.Typed.decodeAlloc(proto.ClientCompatRequest, allocator, bytes);
}

fn writeResponse(writer: *std.Io.Writer, allocator: std.mem.Allocator, response: proto.ClientCompatResponse) !void {
    const encoded = try zgrpc.Typed.encodeAlloc(allocator, response);
    defer allocator.free(encoded);
    var prefix: [4]u8 = undefined;
    std.mem.writeInt(u32, &prefix, @intCast(encoded.len), .big);
    try writer.writeAll(&prefix);
    try writer.writeAll(encoded);
    try writer.flush();
}

fn decodeBase64Alloc(allocator: std.mem.Allocator, encoded: []const u8) ![]u8 {
    if (std.base64.standard_no_pad.Decoder.calcSizeForSlice(encoded)) |length| {
        const value = try allocator.alloc(u8, length);
        errdefer allocator.free(value);
        std.base64.standard_no_pad.Decoder.decode(value, encoded) catch return error.InvalidBinaryMetadata;
        return value;
    } else |_| {}
    const length = std.base64.standard.Decoder.calcSizeForSlice(encoded) catch return error.InvalidBinaryMetadata;
    const value = try allocator.alloc(u8, length);
    errdefer allocator.free(value);
    std.base64.standard.Decoder.decode(value, encoded) catch return error.InvalidBinaryMetadata;
    return value;
}

fn requestMetadataAlloc(allocator: std.mem.Allocator, headers: []const proto.Header) ![]Grpc.Metadata {
    var metadata: std.ArrayList(Grpc.Metadata) = .empty;
    errdefer {
        for (metadata.items) |entry| {
            allocator.free(entry.name);
            if (entry.kind == .binary) allocator.free(entry.value);
        }
        metadata.deinit(allocator);
    }
    for (headers) |header| for (header.value.items) |value| {
        const name = try std.ascii.allocLowerString(allocator, header.name);
        errdefer allocator.free(name);
        if (std.mem.endsWith(u8, name, "-bin")) {
            const decoded = try decodeBase64Alloc(allocator, value);
            errdefer allocator.free(decoded);
            try metadata.append(allocator, .{ .name = name, .value = decoded, .kind = .binary });
        } else {
            try metadata.append(allocator, .{ .name = name, .value = value });
        }
    };
    return metadata.toOwnedSlice(allocator);
}

fn freeRequestMetadata(allocator: std.mem.Allocator, metadata: []Grpc.Metadata) void {
    for (metadata) |entry| {
        allocator.free(entry.name);
        if (entry.kind == .binary) allocator.free(entry.value);
    }
    allocator.free(metadata);
}

fn appendResponseHeaders(allocator: std.mem.Allocator, result: *proto.ClientResponseResult, headers: []const zstd.Http.Header) !void {
    for (headers, 0..) |header, index| {
        if (std.ascii.eqlIgnoreCase(header.name, "content-length") or
            std.ascii.eqlIgnoreCase(header.name, "date") or
            std.ascii.eqlIgnoreCase(header.name, "transfer-encoding") or
            std.ascii.startsWithIgnoreCase(header.name, "trailer-")) continue;
        var existing: ?usize = null;
        for (headers[0..index]) |previous| {
            if (std.ascii.eqlIgnoreCase(previous.name, header.name)) {
                for (result.response_headers.items, 0..) |candidate, candidate_index| {
                    if (std.ascii.eqlIgnoreCase(candidate.name, header.name)) {
                        existing = candidate_index;
                        break;
                    }
                }
                break;
            }
        }
        if (existing) |header_index| {
            try result.response_headers.items[header_index].value.append(allocator, try allocator.dupe(u8, header.value));
        } else {
            var compat_header = proto.Header{ .name = try allocator.dupe(u8, header.name) };
            try compat_header.value.append(allocator, try allocator.dupe(u8, header.value));
            try result.response_headers.append(allocator, compat_header);
        }
    }
}

fn appendResponseTrailers(allocator: std.mem.Allocator, result: *proto.ClientResponseResult, headers: []const zstd.Http.Header) !void {
    for (headers, 0..) |header, index| {
        if (!std.ascii.startsWithIgnoreCase(header.name, "trailer-") or header.name.len == "trailer-".len) continue;
        const name = header.name["trailer-".len..];
        var existing: ?usize = null;
        for (headers[0..index]) |previous| {
            if (std.ascii.startsWithIgnoreCase(previous.name, "trailer-") and
                std.ascii.eqlIgnoreCase(previous.name["trailer-".len..], name))
            {
                for (result.response_trailers.items, 0..) |candidate, candidate_index| {
                    if (std.ascii.eqlIgnoreCase(candidate.name, name)) {
                        existing = candidate_index;
                        break;
                    }
                }
                break;
            }
        }
        if (existing) |header_index| {
            try result.response_trailers.items[header_index].value.append(allocator, try allocator.dupe(u8, header.value));
        } else {
            var compat_header = proto.Header{ .name = try allocator.dupe(u8, name) };
            try compat_header.value.append(allocator, try allocator.dupe(u8, header.value));
            try result.response_trailers.append(allocator, compat_header);
        }
    }
}

fn appendPayload(allocator: std.mem.Allocator, result: *proto.ClientResponseResult, method: []const u8, bytes: []const u8) !void {
    if (std.mem.eql(u8, method, "Unary")) {
        const decoded = try zgrpc.Typed.decodeAlloc(proto.UnaryResponse, allocator, bytes);
        try result.payloads.append(allocator, decoded.payload orelse .{});
    } else if (std.mem.eql(u8, method, "IdempotentUnary")) {
        const decoded = try zgrpc.Typed.decodeAlloc(proto.IdempotentUnaryResponse, allocator, bytes);
        try result.payloads.append(allocator, decoded.payload orelse .{});
    } else if (std.mem.eql(u8, method, "Unimplemented")) {
        _ = try zgrpc.Typed.decodeAlloc(proto.UnimplementedResponse, allocator, bytes);
    } else return error.UnsupportedConformanceMethod;
}

fn appendErrorDetails(allocator: std.mem.Allocator, destination: *proto.Error, details: []const zgrpc.Connect.ErrorDetail) !void {
    for (details) |detail| {
        const type_url = if (std.mem.indexOfScalar(u8, detail.type_name, '/') == null)
            try std.fmt.allocPrint(allocator, "type.googleapis.com/{s}", .{detail.type_name})
        else
            try allocator.dupe(u8, detail.type_name);
        try destination.details.append(allocator, .{ .type_url = type_url, .value = try allocator.dupe(u8, detail.value) });
    }
}

fn validateRequest(request: proto.ClientCompatRequest) !void {
    if (request.protocol != .PROTOCOL_CONNECT) return error.UnsupportedProtocol;
    if (request.http_version != .HTTP_VERSION_1) return error.UnsupportedHttpVersion;
    if (request.codec != .CODEC_PROTO) return error.UnsupportedCodec;
    if (request.compression != .COMPRESSION_IDENTITY) return error.UnsupportedCompression;
    if (request.server_tls_cert.len != 0 or request.client_tls_creds != null) return error.UnsupportedTls;
    if (request.stream_type != .STREAM_TYPE_UNARY) return error.UnsupportedStreamType;
    if (request.use_get_http_method) return error.UnsupportedConnectGet;
    if (request.raw_request != null) return error.UnsupportedRawRequest;
    if (request.request_messages.items.len != 1) return error.InvalidRequestMessageCount;
}

fn invoke(
    allocator: std.mem.Allocator,
    client: *zgrpc.Connect.NativeUnaryClient,
    request: proto.ClientCompatRequest,
) !proto.ClientCompatResponse {
    validateRequest(request) catch |err| return .{
        .test_name = request.test_name,
        .result = .{ .@"error" = .{ .message = @errorName(err) } },
    };

    const service = request.service orelse default_service;
    const method = request.method orelse "Unary";
    const metadata = try requestMetadataAlloc(allocator, request.request_headers.items);
    defer freeRequestMetadata(allocator, metadata);
    const base_url = try std.fmt.allocPrint(allocator, "http://{s}:{d}", .{ request.host, request.port });
    defer allocator.free(base_url);

    var result = proto.ClientResponseResult{};
    const cancel_after_millis: ?u64 = if (request.cancel) |cancel|
        if (cancel.cancel_timing) |timing| switch (timing) {
            .after_close_send_ms => |value| value,
            else => null,
        } else null
    else
        null;
    var response = client.invokeAlloc(allocator, .{
        .base_url = base_url,
        .service = service,
        .method = method,
        .payload = request.request_messages.items[0].value,
        .metadata = metadata,
        .timeout_millis = if (request.timeout_ms) |value| @as(u64, value) else null,
        .cancel_after_millis = cancel_after_millis,
        .response_body_limit = if (request.message_receive_limit == 0) 4 * 1024 * 1024 else request.message_receive_limit,
    }) catch |err| {
        result.@"error" = .{
            .code = switch (err) {
                error.RequestCancelled => .CODE_CANCELED,
                error.RequestTimeout => .CODE_DEADLINE_EXCEEDED,
                error.InvalidConnectError, error.TransportFailure => .CODE_INTERNAL,
                else => .CODE_UNAVAILABLE,
            },
            .message = @errorName(err),
        };
        return .{ .test_name = request.test_name, .result = .{ .response = result } };
    };
    defer response.deinit();

    try appendResponseHeaders(allocator, &result, response.http_response.headers);
    try appendResponseTrailers(allocator, &result, response.http_response.headers);
    if (response.status.isOk()) {
        try appendPayload(allocator, &result, method, response.payload);
    } else {
        result.@"error" = .{
            .code = @enumFromInt(@as(i32, @intFromEnum(response.status.code))),
            .message = if (response.status.message.len == 0) null else try allocator.dupe(u8, response.status.message),
        };
        try appendErrorDetails(allocator, &result.@"error".?, response.details);
    }
    return .{ .test_name = request.test_name, .result = .{ .response = result } };
}

pub fn main(init: std.process.Init) !void {
    var debug_allocator: std.heap.DebugAllocator(.{}) = .init;
    defer if (debug_allocator.deinit() == .leak) @panic("Connect conformance client leaked memory");
    const backing_allocator = debug_allocator.allocator();
    var client = zgrpc.Connect.NativeUnaryClient.init(backing_allocator, init.io);
    defer client.deinit();

    var read_buffer: [64 * 1024]u8 = undefined;
    var reader = std.Io.File.stdin().reader(init.io, &read_buffer);
    var write_buffer: [64 * 1024]u8 = undefined;
    var writer = std.Io.File.stdout().writer(init.io, &write_buffer);
    var arena = std.heap.ArenaAllocator.init(backing_allocator);
    defer arena.deinit();

    while (true) {
        _ = arena.reset(.retain_capacity);
        const allocator = arena.allocator();
        const request = try readRequest(&reader.interface, allocator) orelse break;
        const response = try invoke(allocator, &client, request);
        try writeResponse(&writer.interface, allocator, response);
    }
}
