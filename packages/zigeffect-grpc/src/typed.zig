const std = @import("std");
const zstd = @import("zigeffect_std");
const Incremental = @import("incremental.zig");

pub const Grpc = zstd.Grpc;

pub fn encodeAlloc(allocator: std.mem.Allocator, message: anytype) ![]u8 {
    var output: std.Io.Writer.Allocating = .init(allocator);
    errdefer output.deinit();
    try message.encode(&output.writer, allocator);
    return output.toOwnedSlice();
}

pub fn decodeAlloc(comptime Message: type, allocator: std.mem.Allocator, bytes: []const u8) !Message {
    var reader: std.Io.Reader = .fixed(bytes);
    const value = try Message.decode(&reader, allocator);
    if (reader.seek != bytes.len) {
        var owned = value;
        deinitMessage(Message, allocator, &owned);
        return error.TrailingProtobufBytes;
    }
    return value;
}

pub fn deinitMessage(comptime Message: type, allocator: std.mem.Allocator, message: *Message) void {
    if (@hasDecl(Message, "deinit")) message.deinit(allocator);
}

pub fn Owned(comptime Message: type) type {
    return struct {
        allocator: std.mem.Allocator,
        value: Message,

        pub fn deinit(self: *@This()) void {
            deinitMessage(Message, self.allocator, &self.value);
            self.* = undefined;
        }
    };
}

pub fn invokeUnaryAlloc(
    comptime Request: type,
    comptime Response: type,
    allocator: std.mem.Allocator,
    client: Grpc.Client,
    authority: []const u8,
    service: []const u8,
    method: []const u8,
    request: Request,
    options: Grpc.CallOptions,
) !Owned(Response) {
    const payload = try encodeAlloc(allocator, request);
    defer allocator.free(payload);
    var response = try client.invokeAlloc(allocator, .{
        .authority = authority,
        .service = service,
        .method = method,
        .payload = payload,
        .timeout_millis = options.timeout_millis,
    }, options);
    defer response.deinit();
    if (response.status.code != .ok) return error.GrpcCallFailed;
    return .{ .allocator = allocator, .value = try decodeAlloc(Response, allocator, response.payload) };
}

pub const StreamingClient = struct {
    pointer: *anyopaque,
    invoke_fn: *const fn (*anyopaque, std.mem.Allocator, Grpc.StreamingRequest, Grpc.CallOptions) anyerror!Grpc.StreamingResponse,

    pub fn from(comptime Target: type, target: *Target) StreamingClient {
        return .{
            .pointer = target,
            .invoke_fn = struct {
                fn invoke(pointer: *anyopaque, allocator: std.mem.Allocator, request: Grpc.StreamingRequest, options: Grpc.CallOptions) anyerror!Grpc.StreamingResponse {
                    return (@as(*Target, @ptrCast(@alignCast(pointer)))).invokeStreamingAlloc(allocator, request, options);
                }
            }.invoke,
        };
    }

    pub fn invokeStreamingAlloc(self: StreamingClient, allocator: std.mem.Allocator, request: Grpc.StreamingRequest, options: Grpc.CallOptions) anyerror!Grpc.StreamingResponse {
        try options.checkActive();
        try request.validate(options.limits);
        return self.invoke_fn(self.pointer, allocator, request, options);
    }
};

pub fn StreamingResponse(comptime Message: type) type {
    return struct {
        allocator: std.mem.Allocator,
        messages: []Message,
        wire: Grpc.StreamingResponse,

        pub fn deinit(self: *@This()) void {
            for (self.messages) |*message| deinitMessage(Message, self.allocator, message);
            self.allocator.free(self.messages);
            self.wire.deinit();
            self.* = undefined;
        }
    };
}

pub fn invokeStreamingAlloc(
    comptime Request: type,
    comptime Response: type,
    allocator: std.mem.Allocator,
    client: StreamingClient,
    authority: []const u8,
    service: []const u8,
    method: []const u8,
    requests: []const Request,
    shape: Grpc.CallShape,
    options: Grpc.CallOptions,
) !StreamingResponse(Response) {
    if (shape == .unary) return error.InvalidCallShape;
    const encoded = try allocator.alloc([]u8, requests.len);
    defer allocator.free(encoded);
    var encoded_count: usize = 0;
    defer for (encoded[0..encoded_count]) |bytes| allocator.free(bytes);
    for (requests, 0..) |request, index| {
        encoded[index] = try encodeAlloc(allocator, request);
        encoded_count += 1;
    }
    const borrowed = try allocator.alloc([]const u8, encoded.len);
    defer allocator.free(borrowed);
    for (encoded, 0..) |bytes, index| borrowed[index] = bytes;
    var wire = try client.invokeStreamingAlloc(allocator, .{
        .authority = authority,
        .service = service,
        .method = method,
        .messages = borrowed,
        .timeout_millis = options.timeout_millis,
        .shape = shape,
    }, options);
    errdefer wire.deinit();
    const messages = try allocator.alloc(Response, wire.messages.len);
    errdefer allocator.free(messages);
    var decoded_count: usize = 0;
    errdefer for (messages[0..decoded_count]) |*message| deinitMessage(Response, allocator, message);
    for (wire.messages, 0..) |bytes, index| {
        messages[index] = try decodeAlloc(Response, allocator, bytes);
        decoded_count += 1;
    }
    return .{ .allocator = allocator, .messages = messages, .wire = wire };
}

pub fn UnaryBinding(
    comptime Request: type,
    comptime Response: type,
    comptime Context: type,
    comptime invoke_fn: fn (*Context, Request) anyerror!Response,
) type {
    return struct {
        context: *Context,

        pub fn handler(self: *@This()) Grpc.UnaryHandler {
            return Grpc.UnaryHandler.from(@This(), self);
        }

        pub fn invoke(self: *@This(), allocator: std.mem.Allocator, request: Grpc.UnaryRequest) anyerror!Grpc.UnaryResponse {
            var decoded = try decodeAlloc(Request, allocator, request.payload);
            defer deinitMessage(Request, allocator, &decoded);
            // The two-argument handler contract returns a borrowed response.
            // This permits zero-copy echo/projection fields from `decoded`;
            // deinitializing both messages would double-free aliased protobuf
            // slices. Handlers that allocate response backing storage retain
            // ownership of it and should use request-scoped/context storage.
            const result = try invoke_fn(self.context, decoded);
            const encoded = try encodeAlloc(allocator, result);
            errdefer allocator.free(encoded);
            return Grpc.UnaryResponse.initOwnedAlloc(allocator, encoded, .ok());
        }
    };
}

pub fn Stream(comptime Request: type, comptime Response: type) type {
    return struct {
        allocator: std.mem.Allocator,
        call: *Incremental.Call,

        pub fn receive(self: *@This()) !?Owned(Request) {
            const next = (try self.call.receive()) orelse return null;
            var message = next;
            defer message.deinit();
            return .{ .allocator = self.allocator, .value = try decodeAlloc(Request, self.allocator, message.bytes) };
        }

        pub fn send(self: *@This(), response: Response) !void {
            const bytes = try encodeAlloc(self.allocator, response);
            defer self.allocator.free(bytes);
            try self.call.sendAlloc(self.allocator, bytes);
        }

        pub fn context(self: *const @This()) *const Incremental.Context {
            return &self.call.context;
        }

        pub fn isCancelled(self: *const @This()) bool {
            return self.call.isCancelled();
        }
    };
}

pub fn IncrementalBinding(
    comptime Request: type,
    comptime Response: type,
    comptime Context: type,
    comptime invoke_fn: fn (*Context, *Stream(Request, Response)) anyerror!Grpc.Status,
) type {
    return struct {
        context: *Context,
        allocator: std.mem.Allocator,

        pub fn handler(self: *@This()) Incremental.Handler {
            return Incremental.Handler.from(@This(), self);
        }

        pub fn runIncremental(self: *@This(), call: *Incremental.Call) anyerror!Grpc.Status {
            var stream = Stream(Request, Response){ .allocator = self.allocator, .call = call };
            return invoke_fn(self.context, &stream);
        }
    };
}

pub const GeneratedCallOptions = struct {
    call: Grpc.CallOptions = .{},
    metadata: []const Grpc.Metadata = &.{},
    idempotency: Grpc.Idempotency = .unknown,
    compression: Grpc.Compression = .identity,
};

fn serviceFieldType(comptime Service: type, comptime method: std.meta.FieldEnum(Service)) type {
    inline for (std.meta.fields(Service)) |field| {
        if (std.mem.eql(u8, field.name, @tagName(method))) return field.type;
    }
    @compileError("generated service method is not a service field");
}

fn methodFunction(comptime FieldType: type) std.builtin.Type.Fn {
    const pointer = switch (@typeInfo(FieldType)) {
        .pointer => |pointer| pointer,
        else => @compileError("generated service field must be a function pointer"),
    };
    return switch (@typeInfo(pointer.child)) {
        .@"fn" => |function| function,
        else => @compileError("generated service field must point to a function"),
    };
}

fn queueElement(comptime QueuePointer: type) type {
    const QueueType = switch (@typeInfo(QueuePointer)) {
        .pointer => |pointer| pointer.child,
        else => @compileError("streaming service parameter must be a queue pointer"),
    };
    const put = @typeInfo(@TypeOf(QueueType.put)).@"fn";
    const elements = put.params[2].type.?;
    return @typeInfo(elements).pointer.child;
}

fn successType(comptime ReturnType: type) type {
    return switch (@typeInfo(ReturnType)) {
        .error_union => |result| result.payload,
        else => ReturnType,
    };
}

fn shapeForField(comptime FieldType: type) Grpc.CallShape {
    const function = methodFunction(FieldType);
    return switch (function.params.len) {
        2 => switch (@typeInfo(function.params[1].type.?)) {
            .pointer => .client_streaming,
            else => .unary,
        },
        3 => switch (@typeInfo(function.params[1].type.?)) {
            .pointer => .bidirectional_streaming,
            else => .server_streaming,
        },
        else => @compileError("unsupported generated gRPC method signature"),
    };
}

pub fn Method(comptime Service: type) type {
    return std.meta.FieldEnum(Service);
}

pub fn methodShape(comptime Service: type, comptime method: Method(Service)) Grpc.CallShape {
    return shapeForField(serviceFieldType(Service, method));
}

pub fn RequestType(comptime Service: type, comptime method: Method(Service)) type {
    const function = methodFunction(serviceFieldType(Service, method));
    return switch (methodShape(Service, method)) {
        .unary, .server_streaming => function.params[1].type.?,
        .client_streaming, .bidirectional_streaming => queueElement(function.params[1].type.?),
    };
}

pub fn ResponseType(comptime Service: type, comptime method: Method(Service)) type {
    const function = methodFunction(serviceFieldType(Service, method));
    return switch (methodShape(Service, method)) {
        .unary, .client_streaming => successType(function.return_type.?),
        .server_streaming, .bidirectional_streaming => queueElement(function.params[2].type.?),
    };
}

pub fn UnaryResponse(comptime Message: type) type {
    return struct {
        allocator: std.mem.Allocator,
        value: ?Message,
        wire: Grpc.UnaryResponse,

        pub fn deinit(self: *@This()) void {
            if (self.value) |*value| deinitMessage(Message, self.allocator, value);
            self.wire.deinit();
            self.* = undefined;
        }
    };
}

pub fn GeneratedClient(comptime Service: type) type {
    return struct {
        authority: []const u8,
        unary_client: Grpc.Client,
        streaming_client: StreamingClient,

        pub fn init(authority: []const u8, unary_client: Grpc.Client, streaming_client: StreamingClient) @This() {
            return .{ .authority = authority, .unary_client = unary_client, .streaming_client = streaming_client };
        }

        pub fn unaryAlloc(
            self: *@This(),
            allocator: std.mem.Allocator,
            comptime method: Method(Service),
            request: RequestType(Service, method),
            options: GeneratedCallOptions,
        ) !UnaryResponse(ResponseType(Service, method)) {
            if (comptime methodShape(Service, method) != .unary) @compileError("unaryAlloc requires a unary generated method");
            const payload = try encodeAlloc(allocator, request);
            defer allocator.free(payload);
            var wire = try self.unary_client.invokeAlloc(allocator, .{
                .authority = self.authority,
                .service = if (Service.package.len == 0) Service.service_name else Service.package ++ "." ++ Service.service_name,
                .method = @tagName(method),
                .payload = payload,
                .metadata = options.metadata,
                .timeout_millis = options.call.timeout_millis,
                .compression = options.compression,
                .idempotency = options.idempotency,
            }, options.call);
            errdefer wire.deinit();
            const value = if (wire.status.code == .ok)
                try decodeAlloc(ResponseType(Service, method), allocator, wire.payload)
            else
                null;
            return .{ .allocator = allocator, .value = value, .wire = wire };
        }

        pub fn streamingAlloc(
            self: *@This(),
            allocator: std.mem.Allocator,
            comptime method: Method(Service),
            requests: []const RequestType(Service, method),
            options: GeneratedCallOptions,
        ) !StreamingResponse(ResponseType(Service, method)) {
            const shape = comptime methodShape(Service, method);
            if (shape == .unary) @compileError("streamingAlloc requires a streaming generated method");
            const encoded = try allocator.alloc([]u8, requests.len);
            defer allocator.free(encoded);
            var encoded_count: usize = 0;
            defer for (encoded[0..encoded_count]) |bytes| allocator.free(bytes);
            for (requests, 0..) |request, index| {
                encoded[index] = try encodeAlloc(allocator, request);
                encoded_count += 1;
            }
            const borrowed = try allocator.alloc([]const u8, encoded.len);
            defer allocator.free(borrowed);
            for (encoded, 0..) |bytes, index| borrowed[index] = bytes;
            var wire = try self.streaming_client.invokeStreamingAlloc(allocator, .{
                .authority = self.authority,
                .service = if (Service.package.len == 0) Service.service_name else Service.package ++ "." ++ Service.service_name,
                .method = @tagName(method),
                .messages = borrowed,
                .metadata = options.metadata,
                .timeout_millis = options.call.timeout_millis,
                .shape = shape,
            }, options.call);
            errdefer wire.deinit();
            const messages = try allocator.alloc(ResponseType(Service, method), wire.messages.len);
            errdefer allocator.free(messages);
            var decoded_count: usize = 0;
            errdefer for (messages[0..decoded_count]) |*message| deinitMessage(ResponseType(Service, method), allocator, message);
            for (wire.messages, 0..) |bytes, index| {
                messages[index] = try decodeAlloc(ResponseType(Service, method), allocator, bytes);
                decoded_count += 1;
            }
            return .{ .allocator = allocator, .messages = messages, .wire = wire };
        }
    };
}

pub fn GeneratedServer(comptime Service: type, comptime Implementation: type) type {
    return struct {
        allocator: std.mem.Allocator,
        implementation: *Implementation,

        pub fn init(allocator: std.mem.Allocator, implementation: *Implementation) @This() {
            return .{ .allocator = allocator, .implementation = implementation };
        }

        pub fn registerAll(self: *@This(), unary: *Grpc.Registry, incremental: *Incremental.Registry) !void {
            const service = if (Service.package.len == 0) Service.service_name else Service.package ++ "." ++ Service.service_name;
            inline for (std.meta.fields(Service)) |field| {
                const shape = comptime shapeForField(field.type);
                if (shape == .unary) {
                    try unary.register(.{ .service = service, .method = field.name, .handler = Grpc.UnaryHandler.from(@This(), self) });
                } else {
                    try incremental.register(service, field.name, shape, Incremental.Handler.from(@This(), self));
                }
            }
        }

        pub fn invoke(self: *@This(), allocator: std.mem.Allocator, request: Grpc.UnaryRequest) anyerror!Grpc.UnaryResponse {
            inline for (std.meta.fields(Service)) |field| {
                if (comptime shapeForField(field.type) == .unary) {
                    if (std.mem.eql(u8, request.method, field.name)) {
                        const method: Method(Service) = @field(Method(Service), field.name);
                        const Request = RequestType(Service, method);
                        const Response = ResponseType(Service, method);
                        var decoded = try decodeAlloc(Request, allocator, request.payload);
                        defer deinitMessage(Request, allocator, &decoded);
                        const implementation_method = @field(Implementation, field.name);
                        const implementation_info = @typeInfo(@TypeOf(implementation_method)).@"fn";
                        if (comptime implementation_info.params.len == 3) {
                            // An allocator-aware handler explicitly transfers
                            // an owned response to the binding.
                            var response = try @call(.auto, implementation_method, .{ self.implementation, allocator, decoded });
                            defer deinitMessage(Response, allocator, &response);
                            const bytes = try encodeAlloc(allocator, response);
                            errdefer allocator.free(bytes);
                            return Grpc.UnaryResponse.initOwnedAlloc(allocator, bytes, .ok());
                        } else if (comptime implementation_info.params.len == 2) {
                            // The conventional handler returns a borrowed
                            // response and may safely project decoded fields.
                            const response = try @call(.auto, implementation_method, .{ self.implementation, decoded });
                            const bytes = try encodeAlloc(allocator, response);
                            errdefer allocator.free(bytes);
                            return Grpc.UnaryResponse.initOwnedAlloc(allocator, bytes, .ok());
                        } else @compileError("generated unary handler must accept (self, request) or (self, allocator, request)");
                    }
                }
            }
            return Grpc.UnaryResponse.initAlloc(allocator, "", .{ .code = .unimplemented, .message = "generated method not registered" });
        }

        pub fn runIncremental(self: *@This(), call: *Incremental.Call) anyerror!Grpc.Status {
            inline for (std.meta.fields(Service)) |field| {
                if (comptime shapeForField(field.type) != .unary) {
                    if (std.mem.eql(u8, call.context.method, field.name)) {
                        const method: Method(Service) = @field(Method(Service), field.name);
                        var stream = Stream(RequestType(Service, method), ResponseType(Service, method)){
                            .allocator = self.allocator,
                            .call = call,
                        };
                        return @call(.auto, @field(Implementation, field.name), .{ self.implementation, &stream });
                    }
                }
            }
            return .{ .code = .unimplemented, .message = "generated method not registered" };
        }
    };
}

test "typed unary binding decodes the request and owns its response" {
    const Message = struct {
        value: u8 = 0,

        pub fn encode(self: @This(), writer: *std.Io.Writer, _: std.mem.Allocator) !void {
            try writer.writeByte(self.value);
        }

        pub fn decode(reader: *std.Io.Reader, _: std.mem.Allocator) !@This() {
            return .{ .value = try reader.takeByte() };
        }

        pub fn deinit(_: *@This(), _: std.mem.Allocator) void {}
    };
    const Context = struct {
        fn call(_: *@This(), request: Message) !Message {
            return .{ .value = request.value + 1 };
        }
    };
    var context = Context{};
    var binding = UnaryBinding(Message, Message, Context, Context.call){ .context = &context };
    var response = try binding.invoke(std.testing.allocator, .{
        .authority = "local",
        .service = "example.v1.Service",
        .method = "Increment",
        .payload = &.{41},
        .timeout_millis = 1_000,
    });
    defer response.deinit();
    try std.testing.expectEqualSlices(u8, &.{42}, response.payload);
}

test "owned unary response transfers the encoded payload without cloning" {
    const encoded = try std.testing.allocator.dupe(u8, "encoded");
    errdefer std.testing.allocator.free(encoded);
    const original_pointer = encoded.ptr;
    var response = try Grpc.UnaryResponse.initOwnedAlloc(std.testing.allocator, encoded, .ok());
    defer response.deinit();
    try std.testing.expectEqual(original_pointer, response.payload.ptr);
}

test "owned unary response payload can move into the transport frame" {
    const encoded = try std.testing.allocator.dupe(u8, "frame-me");
    errdefer std.testing.allocator.free(encoded);
    var response = try Grpc.UnaryResponse.initOwnedAlloc(std.testing.allocator, encoded, .ok());
    const transferred = response.takePayload();
    response.deinit();
    defer std.testing.allocator.free(transferred);
    try std.testing.expectEqualStrings("frame-me", transferred);
}

test "typed unary binding permits a response to borrow decoded protobuf storage" {
    const Message = struct {
        value: []u8 = &.{},

        pub fn encode(self: @This(), writer: *std.Io.Writer, _: std.mem.Allocator) !void {
            try writer.writeByte(@intCast(self.value.len));
            try writer.writeAll(self.value);
        }

        pub fn decode(reader: *std.Io.Reader, allocator: std.mem.Allocator) !@This() {
            const length = try reader.takeByte();
            const value = try allocator.alloc(u8, length);
            errdefer allocator.free(value);
            try reader.readSliceAll(value);
            return .{ .value = value };
        }

        pub fn deinit(self: *@This(), allocator: std.mem.Allocator) void {
            allocator.free(self.value);
        }
    };
    const Context = struct {
        fn echo(_: *@This(), request: Message) !Message {
            return .{ .value = request.value };
        }
    };
    var context = Context{};
    var binding = UnaryBinding(Message, Message, Context, Context.echo){ .context = &context };
    var response = try binding.invoke(std.testing.allocator, .{
        .authority = "local",
        .service = "example.v1.Service",
        .method = "Echo",
        .payload = &.{ 3, 'z', 'i', 'g' },
        .timeout_millis = 1_000,
    });
    defer response.deinit();
    try std.testing.expectEqualSlices(u8, &.{ 3, 'z', 'i', 'g' }, response.payload);
}

test "typed streaming client preserves decoded messages metadata and final status" {
    const Message = struct {
        value: u8 = 0,

        pub fn encode(self: @This(), writer: *std.Io.Writer, _: std.mem.Allocator) !void {
            try writer.writeByte(self.value);
        }

        pub fn decode(reader: *std.Io.Reader, _: std.mem.Allocator) !@This() {
            return .{ .value = try reader.takeByte() };
        }

        pub fn deinit(_: *@This(), _: std.mem.Allocator) void {}
    };
    const Fake = struct {
        pub fn invokeStreamingAlloc(_: *@This(), allocator: std.mem.Allocator, request: Grpc.StreamingRequest, _: Grpc.CallOptions) !Grpc.StreamingResponse {
            try std.testing.expectEqual(Grpc.CallShape.bidirectional_streaming, request.shape);
            try std.testing.expectEqual(@as(usize, 2), request.messages.len);
            const initial = [_]Grpc.Metadata{.{ .name = "request-id", .value = "abc" }};
            const trailing = [_]Grpc.Metadata{.{ .name = "quota-left", .value = "9" }};
            return Grpc.StreamingResponse.initFullAlloc(allocator, &.{ &.{3}, &.{4} }, .{
                .initial_metadata = &initial,
                .trailing_metadata = &trailing,
                .status = .{ .code = .resource_exhausted, .message = "retry later" },
            });
        }
    };
    var fake = Fake{};
    const requests = [_]Message{ .{ .value = 1 }, .{ .value = 2 } };
    var response = try invokeStreamingAlloc(Message, Message, std.testing.allocator, StreamingClient.from(Fake, &fake), "local", "example.v1.Chat", "Talk", &requests, .bidirectional_streaming, .{});
    defer response.deinit();
    try std.testing.expectEqual(@as(usize, 2), response.messages.len);
    try std.testing.expectEqual(@as(u8, 3), response.messages[0].value);
    try std.testing.expectEqual(Grpc.Code.resource_exhausted, response.wire.status.code);
    try std.testing.expectEqualStrings("retry later", response.wire.status.message);
    try std.testing.expectEqualStrings("abc", response.wire.initial_metadata[0].value);
    try std.testing.expectEqualStrings("9", response.wire.trailing_metadata[0].value);
}

test "typed incremental binding decodes and encodes messages with stream context" {
    const Message = struct {
        value: u8 = 0,
        pub fn encode(self: @This(), writer: *std.Io.Writer, _: std.mem.Allocator) !void {
            try writer.writeByte(self.value);
        }
        pub fn decode(reader: *std.Io.Reader, _: std.mem.Allocator) !@This() {
            return .{ .value = try reader.takeByte() };
        }
        pub fn deinit(_: *@This(), _: std.mem.Allocator) void {}
    };
    const Context = struct {
        fn run(_: *@This(), stream: *Stream(Message, Message)) !Grpc.Status {
            try std.testing.expectEqualStrings("trace-1", stream.context().metadata[0].value);
            while (try stream.receive()) |owned_value| {
                var owned = owned_value;
                defer owned.deinit();
                try stream.send(.{ .value = owned.value.value + 1 });
            }
            return .ok();
        }
    };
    var inbound = try Incremental.Pipe.init(std.testing.allocator, std.testing.io, 1);
    defer inbound.deinit();
    var outbound = try Incremental.Pipe.init(std.testing.allocator, std.testing.io, 1);
    defer outbound.deinit();
    try inbound.sendAlloc(std.testing.allocator, &.{41});
    inbound.close();
    const Notify = struct {
        fn call(_: *anyopaque) void {}
    };
    var marker: u8 = 0;
    const metadata = [_]Grpc.Metadata{.{ .name = "trace-id", .value = "trace-1" }};
    var call = Incremental.Call{
        .context = .{
            .authority = "local",
            .service = "example.v1.Typed",
            .method = "Bidi",
            .shape = .bidirectional_streaming,
            .timeout_millis = 1_000,
            .metadata = &metadata,
        },
        .inbound = &inbound,
        .outbound = &outbound,
        .notify_pointer = &marker,
        .notify_fn = Notify.call,
    };
    var context = Context{};
    var binding = IncrementalBinding(Message, Message, Context, Context.run){ .context = &context, .allocator = std.testing.allocator };
    try std.testing.expect((try binding.runIncremental(&call)).isOk());
    var encoded = (try outbound.receive()).?;
    defer encoded.deinit();
    var decoded = try decodeAlloc(Message, std.testing.allocator, encoded.bytes);
    defer decoded.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(u8, 42), decoded.value);
}

test "generated service facade derives typed clients and registers every RPC shape" {
    const Message = struct {
        value: u8 = 0,
        pub fn encode(self: @This(), writer: *std.Io.Writer, _: std.mem.Allocator) !void {
            try writer.writeByte(self.value);
        }
        pub fn decode(reader: *std.Io.Reader, _: std.mem.Allocator) !@This() {
            return .{ .value = try reader.takeByte() };
        }
        pub fn deinit(_: *@This(), _: std.mem.Allocator) void {}
    };
    const Service = struct {
        pub const package = "example.v1";
        pub const service_name = "Everything";
        Unary: *const fn (*void, Message) error{}!Message,
        ClientStream: *const fn (*void, *std.Io.Queue(Message)) error{}!Message,
        ServerStream: *const fn (*void, Message, *std.Io.Queue(Message)) error{}!void,
        BidiStream: *const fn (*void, *std.Io.Queue(Message), *std.Io.Queue(Message)) error{}!void,
    };
    const Wire = struct {
        fn unary(_: *anyopaque, allocator: std.mem.Allocator, request: Grpc.UnaryRequest, _: Grpc.CallOptions) anyerror!Grpc.UnaryResponse {
            try std.testing.expectEqualStrings("example.v1.Everything", request.service);
            try std.testing.expectEqualStrings("Unary", request.method);
            return Grpc.UnaryResponse.initAlloc(allocator, &.{request.payload[0] + 1}, .ok());
        }
        fn streaming(_: *anyopaque, allocator: std.mem.Allocator, request: Grpc.StreamingRequest, _: Grpc.CallOptions) anyerror!Grpc.StreamingResponse {
            try std.testing.expectEqual(Grpc.CallShape.bidirectional_streaming, request.shape);
            return Grpc.StreamingResponse.initAlloc(allocator, &.{&.{request.messages[0][0] + 1}}, .ok());
        }
    };
    var marker: u8 = 0;
    var client = GeneratedClient(Service).init(
        "api.example.test",
        .{ .ptr = &marker, .invoke_fn = Wire.unary },
        .{ .pointer = &marker, .invoke_fn = Wire.streaming },
    );
    var unary = try client.unaryAlloc(std.testing.allocator, .Unary, .{ .value = 41 }, .{});
    defer unary.deinit();
    try std.testing.expectEqual(@as(u8, 42), unary.value.?.value);
    var bidi = try client.streamingAlloc(std.testing.allocator, .BidiStream, &.{.{ .value = 8 }}, .{});
    defer bidi.deinit();
    try std.testing.expectEqual(@as(u8, 9), bidi.messages[0].value);

    const Implementation = struct {
        fn Unary(_: *@This(), request: Message) !Message {
            return .{ .value = request.value + 1 };
        }
        fn ClientStream(_: *@This(), _: *Stream(Message, Message)) !Grpc.Status {
            return .ok();
        }
        fn ServerStream(_: *@This(), _: *Stream(Message, Message)) !Grpc.Status {
            return .ok();
        }
        fn BidiStream(_: *@This(), _: *Stream(Message, Message)) !Grpc.Status {
            return .ok();
        }
    };
    var implementation = Implementation{};
    var binding = GeneratedServer(Service, Implementation).init(std.testing.allocator, &implementation);
    var unary_registry = Grpc.Registry.init(std.testing.allocator);
    defer unary_registry.deinit();
    var incremental_registry = Incremental.Registry.init(std.testing.allocator);
    defer incremental_registry.deinit();
    try binding.registerAll(&unary_registry, &incremental_registry);
    const registered_request = try encodeAlloc(std.testing.allocator, Message{ .value = 4 });
    defer std.testing.allocator.free(registered_request);
    var registered_response = try unary_registry.invokeAlloc(std.testing.allocator, .{
        .authority = "local",
        .service = "example.v1.Everything",
        .method = "Unary",
        .payload = registered_request,
        .timeout_millis = 1_000,
    }, .{});
    defer registered_response.deinit();
    var registered_message = try decodeAlloc(Message, std.testing.allocator, registered_response.payload);
    defer registered_message.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(u8, 5), registered_message.value);
    try std.testing.expectEqual(Grpc.CallShape.client_streaming, incremental_registry.find("example.v1.Everything", "ClientStream").?.shape);
    try std.testing.expectEqual(Grpc.CallShape.server_streaming, incremental_registry.find("example.v1.Everything", "ServerStream").?.shape);
    try std.testing.expectEqual(Grpc.CallShape.bidirectional_streaming, incremental_registry.find("example.v1.Everything", "BidiStream").?.shape);
}
