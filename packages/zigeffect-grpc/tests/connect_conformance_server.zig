const std = @import("std");
const zgrpc = @import("zigeffect_grpc");

const Grpc = zgrpc.Grpc;
const proto = zgrpc.ConnectConformanceProto;
const service_name = "connectrpc.conformance.v1.ConformanceService";

const unary_url = "type.googleapis.com/connectrpc.conformance.v1.UnaryRequest";
const server_stream_url = "type.googleapis.com/connectrpc.conformance.v1.ServerStreamRequest";
const client_stream_url = "type.googleapis.com/connectrpc.conformance.v1.ClientStreamRequest";
const bidi_stream_url = "type.googleapis.com/connectrpc.conformance.v1.BidiStreamRequest";
const request_info_url = "type.googleapis.com/connectrpc.conformance.v1.ConformancePayload.RequestInfo";

fn sleep(io: std.Io, milliseconds: u64) !void {
    if (milliseconds == 0) return;
    try (std.Io.Clock.Duration{
        .raw = .fromMilliseconds(@intCast(milliseconds)),
        .clock = .awake,
    }).sleep(io);
}

fn statusCode(code: proto.Code) Grpc.Code {
    const value = @intFromEnum(code);
    if (value < 1 or value > 16) return .unknown;
    return @enumFromInt(@as(u8, @intCast(value)));
}

fn appendVarint(output: *std.ArrayList(u8), allocator: std.mem.Allocator, value_arg: u64) !void {
    var value = value_arg;
    while (value >= 0x80) {
        try output.append(allocator, @as(u8, @truncate(value)) | 0x80);
        value >>= 7;
    }
    try output.append(allocator, @intCast(value));
}

fn appendField(output: *std.ArrayList(u8), allocator: std.mem.Allocator, field: u8, bytes: []const u8) !void {
    try appendVarint(output, allocator, (@as(u64, field) << 3) | 2);
    try appendVarint(output, allocator, bytes.len);
    try output.appendSlice(allocator, bytes);
}

fn infoInit(allocator: std.mem.Allocator, metadata: []const Grpc.Metadata, timeout_millis: u64) !proto.ConformancePayload.RequestInfo {
    var info = proto.ConformancePayload.RequestInfo{
        // The native transport's no-header default is 30 seconds. All explicit
        // conformance deadlines use another value.
        .timeout_ms = if (timeout_millis == 30_000) null else @intCast(timeout_millis),
    };
    errdefer infoDeinit(allocator, &info);
    for (metadata, 0..) |entry, index| {
        var existing: ?usize = null;
        for (metadata[0..index], 0..) |previous, previous_index| {
            if (std.mem.eql(u8, previous.name, entry.name)) {
                for (info.request_headers.items, 0..) |header, header_index| if (std.mem.eql(u8, header.name, previous.name)) {
                    existing = header_index;
                    break;
                };
                _ = previous_index;
                break;
            }
        }
        if (existing) |header_index| {
            try info.request_headers.items[header_index].value.append(allocator, entry.value);
        } else {
            var header = proto.Header{ .name = entry.name };
            errdefer header.value.deinit(allocator);
            try header.value.append(allocator, entry.value);
            try info.request_headers.append(allocator, header);
        }
    }
    return info;
}

fn infoDeinit(allocator: std.mem.Allocator, info: *proto.ConformancePayload.RequestInfo) void {
    for (info.request_headers.items) |*header| header.value.deinit(allocator);
    info.request_headers.deinit(allocator);
    info.requests.deinit(allocator);
}

fn addRequest(info: *proto.ConformancePayload.RequestInfo, allocator: std.mem.Allocator, type_url: []const u8, bytes: []const u8) !void {
    try info.requests.append(allocator, .{ .type_url = type_url, .value = bytes });
}

fn metadataAlloc(allocator: std.mem.Allocator, headers: []const proto.Header) !std.ArrayList(Grpc.Metadata) {
    var result: std.ArrayList(Grpc.Metadata) = .empty;
    errdefer result.deinit(allocator);
    for (headers) |header| for (header.value.items) |value| try result.append(allocator, .{
        .name = header.name,
        .value = value,
        .kind = if (std.mem.endsWith(u8, header.name, "-bin")) .binary else .ascii,
    });
    return result;
}

fn richStatusAlloc(
    allocator: std.mem.Allocator,
    definition: proto.Error,
    info: ?*const proto.ConformancePayload.RequestInfo,
) !struct { status: Grpc.Status, details: []u8 } {
    var details: std.ArrayList(u8) = .empty;
    errdefer details.deinit(allocator);
    try appendVarint(&details, allocator, (1 << 3) | 0);
    try appendVarint(&details, allocator, @intCast(@intFromEnum(definition.code)));
    const message = definition.message orelse "";
    if (message.len != 0) try appendField(&details, allocator, 2, message);
    for (definition.details.items) |detail| {
        const encoded = try zgrpc.Typed.encodeAlloc(allocator, detail);
        defer allocator.free(encoded);
        try appendField(&details, allocator, 3, encoded);
    }
    if (info) |request_info| {
        const encoded_info = try zgrpc.Typed.encodeAlloc(allocator, request_info.*);
        defer allocator.free(encoded_info);
        const Any = @TypeOf(definition.details.items[0]);
        const info_any = Any{ .type_url = request_info_url, .value = encoded_info };
        const encoded_any = try zgrpc.Typed.encodeAlloc(allocator, info_any);
        defer allocator.free(encoded_any);
        try appendField(&details, allocator, 3, encoded_any);
    }
    const owned = try details.toOwnedSlice(allocator);
    return .{
        .status = .{ .code = statusCode(definition.code), .message = message, .details_bin = owned },
        .details = owned,
    };
}

fn responsePayloadAlloc(
    allocator: std.mem.Allocator,
    comptime Response: type,
    data: []const u8,
    info: ?proto.ConformancePayload.RequestInfo,
) ![]u8 {
    return zgrpc.Typed.encodeAlloc(allocator, Response{ .payload = .{ .data = data, .request_info = info } });
}

const UnaryHandler = struct {
    allocator: std.mem.Allocator,
    io: std.Io,
    receive_limit: u32,

    pub fn invoke(self: *@This(), allocator: std.mem.Allocator, raw: Grpc.UnaryRequest) !Grpc.UnaryResponse {
        if (self.receive_limit != 0 and raw.payload.len > self.receive_limit) return Grpc.UnaryResponse.initAlloc(allocator, "", .{
            .code = .resource_exhausted,
            .message = "request message exceeds receive limit",
        });
        var request = try zgrpc.Typed.decodeAlloc(proto.UnaryRequest, allocator, raw.payload);
        defer request.deinit(allocator);
        var info = try infoInit(allocator, raw.metadata, raw.timeout_millis);
        defer infoDeinit(allocator, &info);
        try addRequest(&info, allocator, unary_url, raw.payload);

        var initial: std.ArrayList(Grpc.Metadata) = .empty;
        defer initial.deinit(allocator);
        var trailing: std.ArrayList(Grpc.Metadata) = .empty;
        defer trailing.deinit(allocator);
        if (request.response_definition) |definition| {
            initial = try metadataAlloc(allocator, definition.response_headers.items);
            trailing = try metadataAlloc(allocator, definition.response_trailers.items);
            try sleep(self.io, definition.response_delay_ms);
            if (definition.response) |response| switch (response) {
                .@"error" => |error_definition| {
                    const rich = try richStatusAlloc(allocator, error_definition, &info);
                    defer allocator.free(rich.details);
                    return Grpc.UnaryResponse.initFullAlloc(allocator, .{
                        .initial_metadata = initial.items,
                        .trailing_metadata = trailing.items,
                        .status = rich.status,
                    });
                },
                .response_data => |data| {
                    const encoded = try responsePayloadAlloc(allocator, proto.UnaryResponse, data, info);
                    defer allocator.free(encoded);
                    return Grpc.UnaryResponse.initFullAlloc(allocator, .{
                        .payload = encoded,
                        .initial_metadata = initial.items,
                        .trailing_metadata = trailing.items,
                        .status = .ok(),
                    });
                },
            };
        }
        const encoded = try responsePayloadAlloc(allocator, proto.UnaryResponse, "", info);
        defer allocator.free(encoded);
        return Grpc.UnaryResponse.initAlloc(allocator, encoded, .ok());
    }
};

const UnimplementedHandler = struct {
    pub fn invoke(_: *@This(), allocator: std.mem.Allocator, _: Grpc.UnaryRequest) !Grpc.UnaryResponse {
        return Grpc.UnaryResponse.initAlloc(allocator, "", .{
            .code = .unimplemented,
            .message = "procedure is not implemented",
        });
    }
};

const StreamKind = enum { server, client, bidi };

const StreamHandler = struct {
    allocator: std.mem.Allocator,
    kind: StreamKind,
    receive_limit: u32,

    pub fn runIncremental(self: *@This(), call: *zgrpc.Incremental.Call) !Grpc.Status {
        return switch (self.kind) {
            .server => self.server(call),
            .client => self.client(call),
            .bidi => self.bidi(call),
        };
    }

    fn setMetadata(call: *zgrpc.Incremental.Call, allocator: std.mem.Allocator, headers: []const proto.Header, trailers: []const proto.Header) !void {
        var initial = try metadataAlloc(allocator, headers);
        defer initial.deinit(allocator);
        var trailing = try metadataAlloc(allocator, trailers);
        defer trailing.deinit(allocator);
        try call.sendHeaders(initial.items);
        try call.setTrailers(trailing.items);
    }

    fn finalError(call: *zgrpc.Incremental.Call, allocator: std.mem.Allocator, definition: proto.Error, info: ?*const proto.ConformancePayload.RequestInfo) !Grpc.Status {
        const rich = try richStatusAlloc(allocator, definition, info);
        defer allocator.free(rich.details);
        try call.setFinalStatus(rich.status);
        return .ok();
    }

    fn server(self: *@This(), call: *zgrpc.Incremental.Call) !Grpc.Status {
        var message = (try call.receive()) orelse return .{ .code = .unimplemented, .message = "exactly one request is required" };
        defer message.deinit();
        if (self.receive_limit != 0 and message.bytes.len > self.receive_limit) return .{ .code = .resource_exhausted, .message = "request message exceeds receive limit" };
        var request = try zgrpc.Typed.decodeAlloc(proto.ServerStreamRequest, self.allocator, message.bytes);
        defer request.deinit(self.allocator);
        if (try call.receive()) |extra_value| {
            var extra = extra_value;
            extra.deinit();
            return .{ .code = .unimplemented, .message = "multiple requests are not valid for a server stream" };
        }
        var info = try infoInit(self.allocator, call.context.metadata, call.context.timeout_millis);
        defer infoDeinit(self.allocator, &info);
        try addRequest(&info, self.allocator, server_stream_url, message.bytes);
        const definition = request.response_definition orelse return .ok();
        try setMetadata(call, self.allocator, definition.response_headers.items, definition.response_trailers.items);
        for (definition.response_data.items, 0..) |data, index| {
            try call.sleep(definition.response_delay_ms);
            const encoded = try responsePayloadAlloc(self.allocator, proto.ServerStreamResponse, data, if (index == 0) info else null);
            defer self.allocator.free(encoded);
            try call.sendAlloc(self.allocator, encoded);
        }
        if (definition.@"error") |error_definition| {
            if (definition.response_data.items.len == 0) return finalError(call, self.allocator, error_definition, &info);
            return finalError(call, self.allocator, error_definition, null);
        }
        return .ok();
    }

    fn client(self: *@This(), call: *zgrpc.Incremental.Call) !Grpc.Status {
        var messages: std.ArrayList([]u8) = .empty;
        defer {
            for (messages.items) |bytes| self.allocator.free(bytes);
            messages.deinit(self.allocator);
        }
        while (try call.receive()) |received| {
            var message = received;
            defer message.deinit();
            if (self.receive_limit != 0 and message.bytes.len > self.receive_limit) return .{ .code = .resource_exhausted, .message = "request message exceeds receive limit" };
            try messages.append(self.allocator, try self.allocator.dupe(u8, message.bytes));
        }
        var info = try infoInit(self.allocator, call.context.metadata, call.context.timeout_millis);
        defer infoDeinit(self.allocator, &info);
        for (messages.items) |bytes| try addRequest(&info, self.allocator, client_stream_url, bytes);
        var first: ?proto.ClientStreamRequest = if (messages.items.len == 0) null else try zgrpc.Typed.decodeAlloc(proto.ClientStreamRequest, self.allocator, messages.items[0]);
        defer if (first) |*request| request.deinit(self.allocator);
        const definition = if (first) |request| request.response_definition else null;
        if (definition) |response_definition| {
            try setMetadata(call, self.allocator, response_definition.response_headers.items, response_definition.response_trailers.items);
            try call.sleep(response_definition.response_delay_ms);
            if (response_definition.response) |response| switch (response) {
                .@"error" => |error_definition| return finalError(call, self.allocator, error_definition, &info),
                .response_data => |data| {
                    const encoded = try responsePayloadAlloc(self.allocator, proto.ClientStreamResponse, data, info);
                    defer self.allocator.free(encoded);
                    try call.sendAlloc(self.allocator, encoded);
                    return .ok();
                },
            };
        }
        const encoded = try responsePayloadAlloc(self.allocator, proto.ClientStreamResponse, "", info);
        defer self.allocator.free(encoded);
        try call.sendAlloc(self.allocator, encoded);
        return .ok();
    }

    fn bidi(self: *@This(), call: *zgrpc.Incremental.Call) !Grpc.Status {
        var messages: std.ArrayList([]u8) = .empty;
        defer {
            for (messages.items) |bytes| self.allocator.free(bytes);
            messages.deinit(self.allocator);
        }
        var definition: ?proto.StreamResponseDefinition = null;
        defer if (definition) |*value| value.deinit(self.allocator);
        var full_duplex = false;
        var sent: usize = 0;
        var first_request = true;
        while (try call.receive()) |received| {
            var message = received;
            defer message.deinit();
            if (self.receive_limit != 0 and message.bytes.len > self.receive_limit) return .{ .code = .resource_exhausted, .message = "request message exceeds receive limit" };
            const owned = try self.allocator.dupe(u8, message.bytes);
            try messages.append(self.allocator, owned);
            if (first_request) {
                var request = try zgrpc.Typed.decodeAlloc(proto.BidiStreamRequest, self.allocator, message.bytes);
                defer request.deinit(self.allocator);
                full_duplex = request.full_duplex;
                if (request.response_definition) |value| definition = try value.dupe(self.allocator);
                if (definition) |value| try setMetadata(call, self.allocator, value.response_headers.items, value.response_trailers.items);
                first_request = false;
            }
            if (full_duplex) {
                const value = definition orelse continue;
                if (sent >= value.response_data.items.len) break;
                var info = try infoInit(self.allocator, if (sent == 0) call.context.metadata else &.{}, if (sent == 0) call.context.timeout_millis else 30_000);
                defer infoDeinit(self.allocator, &info);
                try addRequest(&info, self.allocator, bidi_stream_url, owned);
                try call.sleep(value.response_delay_ms);
                const encoded = try responsePayloadAlloc(self.allocator, proto.BidiStreamResponse, value.response_data.items[sent], info);
                defer self.allocator.free(encoded);
                try call.sendAlloc(self.allocator, encoded);
                sent += 1;
            }
        }
        const value = definition orelse return .ok();
        var all_info = try infoInit(self.allocator, call.context.metadata, call.context.timeout_millis);
        defer infoDeinit(self.allocator, &all_info);
        for (messages.items) |bytes| try addRequest(&all_info, self.allocator, bidi_stream_url, bytes);
        while (sent < value.response_data.items.len) : (sent += 1) {
            try call.sleep(value.response_delay_ms);
            const encoded = try responsePayloadAlloc(self.allocator, proto.BidiStreamResponse, value.response_data.items[sent], if (sent == 0) all_info else null);
            defer self.allocator.free(encoded);
            try call.sendAlloc(self.allocator, encoded);
        }
        if (value.@"error") |error_definition| {
            if (sent == 0) return finalError(call, self.allocator, error_definition, &all_info);
            return finalError(call, self.allocator, error_definition, null);
        }
        return .ok();
    }
};

fn readCompatRequest(allocator: std.mem.Allocator, io: std.Io) !proto.ServerCompatRequest {
    var buffer: [64 * 1024]u8 = undefined;
    var reader = std.Io.File.stdin().reader(io, &buffer);
    var prefix: [4]u8 = undefined;
    try reader.interface.readSliceAll(&prefix);
    const length: usize = std.mem.readInt(u32, &prefix, .big);
    if (length == 0 or length > 1024 * 1024) return error.InvalidCompatRequest;
    const bytes = try allocator.alloc(u8, length);
    defer allocator.free(bytes);
    try reader.interface.readSliceAll(bytes);
    return zgrpc.Typed.decodeAlloc(proto.ServerCompatRequest, allocator, bytes);
}

fn writeCompatResponse(allocator: std.mem.Allocator, io: std.Io, response: proto.ServerCompatResponse) !void {
    const encoded = try zgrpc.Typed.encodeAlloc(allocator, response);
    defer allocator.free(encoded);
    var prefix: [4]u8 = undefined;
    std.mem.writeInt(u32, &prefix, @intCast(encoded.len), .big);
    var buffer: [4096]u8 = undefined;
    var writer = std.Io.File.stdout().writer(io, &buffer);
    try writer.interface.writeAll(&prefix);
    try writer.interface.writeAll(encoded);
    try writer.interface.flush();
}

pub fn main(init: std.process.Init) !void {
    var debug_allocator: std.heap.DebugAllocator(.{}) = .init;
    defer if (debug_allocator.deinit() == .leak) @panic("Connect conformance server leaked memory");
    const allocator = debug_allocator.allocator();
    var request = try readCompatRequest(allocator, init.io);
    defer request.deinit(allocator);
    if (request.protocol != .PROTOCOL_CONNECT or request.http_version != .HTTP_VERSION_2 or request.use_tls or request.client_tls_cert.len != 0) {
        return error.UnsupportedConformanceConfiguration;
    }

    var unary_handler = UnaryHandler{ .allocator = allocator, .io = init.io, .receive_limit = request.message_receive_limit };
    var registry = Grpc.Registry.init(allocator);
    defer registry.deinit();
    try registry.register(.{ .service = service_name, .method = "Unary", .handler = Grpc.UnaryHandler.from(UnaryHandler, &unary_handler) });
    var unimplemented_handler = UnimplementedHandler{};
    try registry.register(.{ .service = service_name, .method = "Unimplemented", .handler = Grpc.UnaryHandler.from(UnimplementedHandler, &unimplemented_handler) });

    var server_stream = StreamHandler{ .allocator = allocator, .kind = .server, .receive_limit = request.message_receive_limit };
    var client_stream = StreamHandler{ .allocator = allocator, .kind = .client, .receive_limit = request.message_receive_limit };
    var bidi_stream = StreamHandler{ .allocator = allocator, .kind = .bidi, .receive_limit = request.message_receive_limit };
    var incremental = zgrpc.Incremental.Registry.init(allocator);
    defer incremental.deinit();
    try incremental.register(service_name, "ServerStream", .server_streaming, zgrpc.Incremental.Handler.from(StreamHandler, &server_stream));
    try incremental.register(service_name, "ClientStream", .client_streaming, zgrpc.Incremental.Handler.from(StreamHandler, &client_stream));
    try incremental.register(service_name, "BidiStream", .bidirectional_streaming, zgrpc.Incremental.Handler.from(StreamHandler, &bidi_stream));

    const process_id: u16 = @intCast(@as(u64, @intCast(std.Io.Clock.real.now(init.io).toMilliseconds())) % 1000);
    var port: u16 = 54_000 + process_id;
    var maybe_server: ?zgrpc.NativeServer = null;
    var attempts: usize = 0;
    while (attempts < 100) : (attempts += 1) {
        maybe_server = zgrpc.NativeServer.init(allocator, init.io, .{
            .host = "127.0.0.1",
            .port = port,
            .max_connections = 32,
            .max_concurrent_streams = 100,
            .connection_idle_timeout_millis = null,
            .connection_max_age_millis = null,
            .protocol_policy = .connect_only,
        }, &registry) catch |err| switch (err) {
            error.AddressInUse => {
                port = if (port == 54_999) 54_000 else port + 1;
                continue;
            },
            else => return err,
        };
        break;
    }
    var server = maybe_server orelse return error.NoConformancePort;
    defer server.deinit();
    try server.installIncremental(&incremental);
    try writeCompatResponse(allocator, init.io, .{ .host = "127.0.0.1", .port = port });
    _ = try server.serve();
}
