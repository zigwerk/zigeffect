const std = @import("std");
const zgrpc = @import("zigeffect_grpc");

const Grpc = zgrpc.Grpc;
const proto = zgrpc.OfficialInteropProto;
const service_name = "grpc.testing.TestService";
const echo_initial = "x-grpc-test-echo-initial";
const echo_trailing = "x-grpc-test-echo-trailing-bin";

const EchoMetadata = struct {
    initial: [1]Grpc.Metadata = undefined,
    trailing: [1]Grpc.Metadata = undefined,
    initial_len: usize = 0,
    trailing_len: usize = 0,

    fn from(entries: []const Grpc.Metadata) EchoMetadata {
        var result = EchoMetadata{};
        for (entries) |entry| {
            if (std.mem.eql(u8, entry.name, echo_initial)) {
                result.initial[0] = entry;
                result.initial_len = 1;
            } else if (std.mem.eql(u8, entry.name, echo_trailing)) {
                result.trailing[0] = entry;
                result.trailing_len = 1;
            }
        }
        return result;
    }

    fn initialSlice(self: *const EchoMetadata) []const Grpc.Metadata {
        return self.initial[0..self.initial_len];
    }

    fn trailingSlice(self: *const EchoMetadata) []const Grpc.Metadata {
        return self.trailing[0..self.trailing_len];
    }
};

fn statusFromEcho(value: ?proto.EchoStatus) Grpc.Status {
    const echo = value orelse return .ok();
    if (echo.code == 0) return .ok();
    if (echo.code < 0 or echo.code > 16) return .{ .code = .unknown, .message = echo.message };
    return .{ .code = @enumFromInt(@as(u8, @intCast(echo.code))), .message = echo.message };
}

fn zeroPayload(allocator: std.mem.Allocator, size: i32) ![]u8 {
    if (size < 0 or size > 4 * 1024 * 1024) return error.InvalidResponseSize;
    const body = try allocator.alloc(u8, @intCast(size));
    @memset(body, 0);
    return body;
}

const UnaryKind = enum { empty, unary };

const UnaryHandler = struct {
    kind: UnaryKind,

    pub fn invoke(self: *@This(), allocator: std.mem.Allocator, request: Grpc.UnaryRequest) !Grpc.UnaryResponse {
        const metadata = EchoMetadata.from(request.metadata);
        switch (self.kind) {
            .empty => {
                var decoded = try zgrpc.Typed.decodeAlloc(proto.Empty, allocator, request.payload);
                defer decoded.deinit(allocator);
                const payload = try zgrpc.Typed.encodeAlloc(allocator, proto.Empty{});
                defer allocator.free(payload);
                return Grpc.UnaryResponse.initFullAlloc(allocator, .{
                    .payload = payload,
                    .initial_metadata = metadata.initialSlice(),
                    .trailing_metadata = metadata.trailingSlice(),
                    .status = .ok(),
                });
            },
            .unary => {
                var decoded = try zgrpc.Typed.decodeAlloc(proto.SimpleRequest, allocator, request.payload);
                defer decoded.deinit(allocator);
                const status = statusFromEcho(decoded.response_status);
                if (!status.isOk()) {
                    return Grpc.UnaryResponse.initFullAlloc(allocator, .{
                        .initial_metadata = metadata.initialSlice(),
                        .trailing_metadata = metadata.trailingSlice(),
                        .status = status,
                    });
                }
                const body = try zeroPayload(allocator, decoded.response_size);
                defer allocator.free(body);
                const payload = try zgrpc.Typed.encodeAlloc(allocator, proto.SimpleResponse{
                    .payload = .{ .type = decoded.response_type, .body = body },
                    .server_id = "zigeffect-grpc-official-interop",
                });
                defer allocator.free(payload);
                return Grpc.UnaryResponse.initFullAlloc(allocator, .{
                    .payload = payload,
                    .initial_metadata = metadata.initialSlice(),
                    .trailing_metadata = metadata.trailingSlice(),
                    .status = .ok(),
                });
            },
        }
    }
};

const StreamKind = enum { output, input, full_duplex, half_duplex };

const StreamHandler = struct {
    allocator: std.mem.Allocator,
    kind: StreamKind,

    pub fn runIncremental(self: *@This(), call: *zgrpc.Incremental.Call) !Grpc.Status {
        const metadata = EchoMetadata.from(call.context.metadata);
        try call.sendHeaders(metadata.initialSlice());
        defer call.setTrailers(metadata.trailingSlice()) catch {};
        return switch (self.kind) {
            .output => self.output(call),
            .input => self.input(call),
            .full_duplex => self.fullDuplex(call),
            .half_duplex => self.halfDuplex(call),
        };
    }

    fn output(self: *@This(), call: *zgrpc.Incremental.Call) !Grpc.Status {
        var message = (try call.receive()) orelse return .{ .code = .invalid_argument, .message = "request required" };
        defer message.deinit();
        var request = try zgrpc.Typed.decodeAlloc(proto.StreamingOutputCallRequest, self.allocator, message.bytes);
        defer request.deinit(self.allocator);
        const status = statusFromEcho(request.response_status);
        if (!status.isOk()) {
            try call.setFinalStatus(status);
            return .ok();
        }
        try self.sendResponses(call, request.response_type, request.response_parameters.items);
        return .ok();
    }

    fn input(self: *@This(), call: *zgrpc.Incremental.Call) !Grpc.Status {
        var total: usize = 0;
        while (try call.receive()) |received| {
            var message = received;
            defer message.deinit();
            var request = try zgrpc.Typed.decodeAlloc(proto.StreamingInputCallRequest, self.allocator, message.bytes);
            defer request.deinit(self.allocator);
            if (request.payload) |payload| total = std.math.add(usize, total, payload.body.len) catch return error.ResponseTooLarge;
            if (total > std.math.maxInt(i32)) return error.ResponseTooLarge;
        }
        const encoded = try zgrpc.Typed.encodeAlloc(self.allocator, proto.StreamingInputCallResponse{
            .aggregated_payload_size = @intCast(total),
        });
        defer self.allocator.free(encoded);
        try call.sendAlloc(self.allocator, encoded);
        return .ok();
    }

    fn fullDuplex(self: *@This(), call: *zgrpc.Incremental.Call) !Grpc.Status {
        while (try call.receive()) |received| {
            var message = received;
            defer message.deinit();
            var request = try zgrpc.Typed.decodeAlloc(proto.StreamingOutputCallRequest, self.allocator, message.bytes);
            defer request.deinit(self.allocator);
            const status = statusFromEcho(request.response_status);
            if (!status.isOk()) {
                try call.setFinalStatus(status);
                return .ok();
            }
            try self.sendResponses(call, request.response_type, request.response_parameters.items);
        }
        return .ok();
    }

    fn halfDuplex(self: *@This(), call: *zgrpc.Incremental.Call) !Grpc.Status {
        var responses: std.ArrayList(struct { payload_type: proto.PayloadType, size: i32, interval_us: i32 }) = .empty;
        defer responses.deinit(self.allocator);
        while (try call.receive()) |received| {
            var message = received;
            defer message.deinit();
            var request = try zgrpc.Typed.decodeAlloc(proto.StreamingOutputCallRequest, self.allocator, message.bytes);
            defer request.deinit(self.allocator);
            const status = statusFromEcho(request.response_status);
            if (!status.isOk()) {
                try call.setFinalStatus(status);
                return .ok();
            }
            for (request.response_parameters.items) |parameter| try responses.append(self.allocator, .{
                .payload_type = request.response_type,
                .size = parameter.size,
                .interval_us = parameter.interval_us,
            });
        }
        for (responses.items) |response| try self.sendResponse(call, response.payload_type, response.size, response.interval_us);
        return .ok();
    }

    fn sendResponses(self: *@This(), call: *zgrpc.Incremental.Call, payload_type: proto.PayloadType, parameters: []const proto.ResponseParameters) !void {
        for (parameters) |parameter| try self.sendResponse(call, payload_type, parameter.size, parameter.interval_us);
    }

    fn sendResponse(self: *@This(), call: *zgrpc.Incremental.Call, payload_type: proto.PayloadType, size: i32, interval_us: i32) !void {
        if (interval_us > 0) try call.sleep(@intCast(@divTrunc(interval_us + 999, 1000)));
        const body = try zeroPayload(self.allocator, size);
        defer self.allocator.free(body);
        const encoded = try zgrpc.Typed.encodeAlloc(self.allocator, proto.StreamingOutputCallResponse{
            .payload = .{ .type = payload_type, .body = body },
        });
        defer self.allocator.free(encoded);
        try call.sendAlloc(self.allocator, encoded);
    }
};

pub fn main(init: std.process.Init) !void {
    var debug_allocator: std.heap.DebugAllocator(.{}) = .init;
    defer if (debug_allocator.deinit() == .leak) @panic("official interop server leaked memory");
    const allocator = debug_allocator.allocator();

    var args = std.process.Args.Iterator.init(init.minimal.args);
    _ = args.next();
    const port = try std.fmt.parseInt(u16, args.next() orelse return error.MissingPort, 10);
    const mode = args.next() orelse return error.MissingMode;
    const certificate = args.next();
    const private_key = args.next();

    var empty_handler = UnaryHandler{ .kind = .empty };
    var unary_handler = UnaryHandler{ .kind = .unary };
    var registry = Grpc.Registry.init(allocator);
    defer registry.deinit();
    try registry.register(.{ .service = service_name, .method = "EmptyCall", .handler = Grpc.UnaryHandler.from(UnaryHandler, &empty_handler) });
    try registry.register(.{ .service = service_name, .method = "UnaryCall", .handler = Grpc.UnaryHandler.from(UnaryHandler, &unary_handler) });

    var streaming = Grpc.StreamingRegistry.init(allocator);
    defer streaming.deinit();
    var output = StreamHandler{ .allocator = allocator, .kind = .output };
    var input = StreamHandler{ .allocator = allocator, .kind = .input };
    var full_duplex = StreamHandler{ .allocator = allocator, .kind = .full_duplex };
    var half_duplex = StreamHandler{ .allocator = allocator, .kind = .half_duplex };
    var incremental = zgrpc.Incremental.Registry.init(allocator);
    defer incremental.deinit();
    try incremental.register(service_name, "StreamingOutputCall", .server_streaming, zgrpc.Incremental.Handler.from(StreamHandler, &output));
    try incremental.register(service_name, "StreamingInputCall", .client_streaming, zgrpc.Incremental.Handler.from(StreamHandler, &input));
    try incremental.register(service_name, "FullDuplexCall", .bidirectional_streaming, zgrpc.Incremental.Handler.from(StreamHandler, &full_duplex));
    try incremental.register(service_name, "HalfDuplexCall", .bidirectional_streaming, zgrpc.Incremental.Handler.from(StreamHandler, &half_duplex));

    const tls: ?zgrpc.ServerTlsConfig = if (std.mem.eql(u8, mode, "tls")) .{
        .certificate_chain_path = certificate orelse return error.MissingCertificate,
        .private_key_path = private_key orelse return error.MissingPrivateKey,
    } else if (std.mem.eql(u8, mode, "plaintext")) null else return error.InvalidMode;

    var server = try zgrpc.NativeServer.initStreaming(allocator, init.io, .{
        .host = "127.0.0.1",
        .port = port,
        .tls = tls,
        .max_connections = 8,
        .max_calls_per_connection = 10_000,
        .max_concurrent_streams = 128,
        .stream_queue_capacity = 2,
    }, &registry, &streaming);
    defer server.deinit();
    try server.installIncremental(&incremental);
    _ = try server.serve();
}
