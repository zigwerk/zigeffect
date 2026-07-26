const std = @import("std");
const zstd = @import("zigeffect_std");
const Incremental = @import("incremental.zig");

const fx = zstd.fx;
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

fn failureType(comptime ReturnType: type) type {
    return switch (@typeInfo(ReturnType)) {
        .error_union => |result| result.error_set,
        else => error{},
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
    @setEvalBranchQuota(10_000);
    return std.meta.FieldEnum(Service);
}

pub fn methodShape(comptime Service: type, comptime method: Method(Service)) Grpc.CallShape {
    return shapeForField(serviceFieldType(Service, method));
}

pub fn serviceFullName(comptime Service: type) []const u8 {
    return if (Service.package.len == 0) Service.service_name else Service.package ++ "." ++ Service.service_name;
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
        pub const operations: []const []const u8 = &.{"GeneratedGrpcClient.call"};

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

pub fn GeneratedClientService(comptime Service: type) type {
    return fx.kernel.Service("zigeffect/grpc/client/" ++ serviceFullName(Service), GeneratedClient(Service));
}

pub fn generatedClientLayer(
    comptime Service: type,
    client: GeneratedClient(Service),
) @TypeOf(fx.kernel.Layer.succeed(GeneratedClientService(Service), client)) {
    return fx.kernel.Layer.succeed(GeneratedClientService(Service), client);
}

pub const GeneratedCallError = error{
    OutOfMemory,
    CallFailed,
};

fn generatedCallError(err: anyerror) GeneratedCallError {
    return if (err == error.OutOfMemory) error.OutOfMemory else error.CallFailed;
}

/// A generated unary RPC represented as a canonical typed ZigEffect value.
/// The concrete client is resolved from its stable service tag.
pub fn GeneratedUnaryCallEffect(
    comptime Service: type,
    comptime method: Method(Service),
) type {
    if (comptime methodShape(Service, method) != .unary) {
        @compileError("GeneratedUnaryCallEffect requires a unary generated method");
    }
    const ClientService = GeneratedClientService(Service);
    const State = struct {
        request: RequestType(Service, method),
        options: GeneratedCallOptions,
    };
    return fx.kernel.Effect(
        UnaryResponse(ResponseType(Service, method)),
        GeneratedCallError,
        .{ClientService},
    ).Stateful(State);
}

pub fn generatedUnaryEffect(
    comptime Service: type,
    comptime method: Method(Service),
    request: RequestType(Service, method),
    options: GeneratedCallOptions,
) GeneratedUnaryCallEffect(Service, method) {
    const ClientService = GeneratedClientService(Service);
    const State = GeneratedUnaryCallEffect(Service, method).StateType;
    return GeneratedUnaryCallEffect(Service, method).init(.{ .request = request, .options = options }, struct {
        fn run(state: State, ctx: *fx.kernel.ContextView(.{ClientService})) GeneratedCallError!UnaryResponse(ResponseType(Service, method)) {
            const operation = "grpc.client." ++ @tagName(method);
            const started = ctx.recordCausal(.{
                .kind = .io_wait_started,
                .service_key = ClientService.service_key,
                .label = operation,
                .status = "running",
                .redacted_detail = "generated gRPC client call started; request, response, metadata, and credentials omitted",
            });
            const response = ctx.service(ClientService).unaryAlloc(ctx.allocator(), method, state.request, state.options) catch |err| {
                _ = ctx.recordCausal(.{
                    .kind = .io_completed,
                    .parent_id = started,
                    .cause_event_id = started,
                    .service_key = ClientService.service_key,
                    .label = operation,
                    .type_name = @errorName(err),
                    .status = "failure",
                    .redacted_detail = "generated gRPC client call failed; request, response, metadata, and credentials omitted",
                });
                return generatedCallError(err);
            };
            _ = ctx.recordCausal(.{
                .kind = .io_completed,
                .parent_id = started,
                .service_key = ClientService.service_key,
                .label = operation,
                .status = if (response.wire.status.isOk()) "success" else "failure",
                .redacted_detail = "generated gRPC client call completed; request, response, metadata, and credentials omitted",
            });
            return response;
        }
    }.run);
}

/// A generated streaming RPC represented as a typed ZigEffect value.
pub fn GeneratedStreamingCallEffect(
    comptime Service: type,
    comptime method: Method(Service),
) type {
    if (comptime methodShape(Service, method) == .unary) {
        @compileError("GeneratedStreamingCallEffect requires a streaming generated method");
    }
    const ClientService = GeneratedClientService(Service);
    const State = struct {
        requests: []const RequestType(Service, method),
        options: GeneratedCallOptions,
    };
    return fx.kernel.Effect(
        StreamingResponse(ResponseType(Service, method)),
        GeneratedCallError,
        .{ClientService},
    ).Stateful(State);
}

pub fn generatedStreamingEffect(
    comptime Service: type,
    comptime method: Method(Service),
    requests: []const RequestType(Service, method),
    options: GeneratedCallOptions,
) GeneratedStreamingCallEffect(Service, method) {
    const ClientService = GeneratedClientService(Service);
    const State = GeneratedStreamingCallEffect(Service, method).StateType;
    return GeneratedStreamingCallEffect(Service, method).init(.{ .requests = requests, .options = options }, struct {
        fn run(state: State, ctx: *fx.kernel.ContextView(.{ClientService})) GeneratedCallError!StreamingResponse(ResponseType(Service, method)) {
            const operation = "grpc.client." ++ @tagName(method);
            const started = ctx.recordCausal(.{
                .kind = .io_wait_started,
                .service_key = ClientService.service_key,
                .label = operation,
                .status = "running",
                .redacted_detail = "generated streaming gRPC client call started; messages, metadata, and credentials omitted",
            });
            const response = ctx.service(ClientService).streamingAlloc(ctx.allocator(), method, state.requests, state.options) catch |err| {
                _ = ctx.recordCausal(.{
                    .kind = .io_completed,
                    .parent_id = started,
                    .cause_event_id = started,
                    .service_key = ClientService.service_key,
                    .label = operation,
                    .type_name = @errorName(err),
                    .status = "failure",
                    .redacted_detail = "generated streaming gRPC client call failed; messages, metadata, and credentials omitted",
                });
                return generatedCallError(err);
            };
            _ = ctx.recordCausal(.{
                .kind = .io_completed,
                .parent_id = started,
                .service_key = ClientService.service_key,
                .label = operation,
                .status = if (response.wire.status.isOk()) "success" else "failure",
                .redacted_detail = "generated streaming gRPC client call completed; messages, metadata, and credentials omitted",
            });
            return response;
        }
    }.run);
}

/// Low-level allocation/registry adapter for transport conformance tests.
/// Applications should use `generatedRoutesLayer`, which executes handlers on
/// the consuming application's managed runtime and causal graph.
pub fn GeneratedDriverBinding(comptime Service: type, comptime Implementation: type) type {
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

pub const UnaryRegistry = fx.kernel.Service("zigeffect/grpc/UnaryRegistry", Grpc.Registry);
pub const StreamingRegistry = fx.kernel.Service("zigeffect/grpc/StreamingRegistry", Grpc.StreamingRegistry);
pub const IncrementalRegistry = fx.kernel.Service("zigeffect/grpc/IncrementalRegistry", Incremental.Registry);

const UnaryRegistryLifecycle = struct {
    fn acquire(ctx: *fx.kernel.ContextView(.{})) error{}!Grpc.Registry {
        return Grpc.Registry.init(ctx.allocator());
    }

    fn release(registry: *Grpc.Registry) void {
        registry.deinit();
    }
};

pub fn unaryRegistryLayer() @TypeOf(fx.kernel.Layer.scoped(
    UnaryRegistry,
    error{},
    .{},
    UnaryRegistryLifecycle.acquire,
    UnaryRegistryLifecycle.release,
)) {
    return fx.kernel.Layer.scoped(
        UnaryRegistry,
        error{},
        .{},
        UnaryRegistryLifecycle.acquire,
        UnaryRegistryLifecycle.release,
    );
}

const StreamingRegistryLifecycle = struct {
    fn acquire(ctx: *fx.kernel.ContextView(.{})) error{}!Grpc.StreamingRegistry {
        return Grpc.StreamingRegistry.init(ctx.allocator());
    }

    fn release(registry: *Grpc.StreamingRegistry) void {
        registry.deinit();
    }
};

pub fn streamingRegistryLayer() @TypeOf(fx.kernel.Layer.scoped(
    StreamingRegistry,
    error{},
    .{},
    StreamingRegistryLifecycle.acquire,
    StreamingRegistryLifecycle.release,
)) {
    return fx.kernel.Layer.scoped(
        StreamingRegistry,
        error{},
        .{},
        StreamingRegistryLifecycle.acquire,
        StreamingRegistryLifecycle.release,
    );
}

const IncrementalRegistryLifecycle = struct {
    fn acquire(ctx: *fx.kernel.ContextView(.{})) error{}!Incremental.Registry {
        return Incremental.Registry.init(ctx.allocator());
    }

    fn release(registry: *Incremental.Registry) void {
        registry.deinit();
    }
};

pub fn incrementalRegistryLayer() @TypeOf(fx.kernel.Layer.scoped(
    IncrementalRegistry,
    error{},
    .{},
    IncrementalRegistryLifecycle.acquire,
    IncrementalRegistryLifecycle.release,
)) {
    return fx.kernel.Layer.scoped(
        IncrementalRegistry,
        error{},
        .{},
        IncrementalRegistryLifecycle.acquire,
        IncrementalRegistryLifecycle.release,
    );
}

pub fn InvokeRegisteredEffect() type {
    const State = struct {
        request: Grpc.UnaryRequest,
        options: Grpc.CallOptions,
    };
    return fx.kernel.Effect(Grpc.UnaryResponse, anyerror, .{UnaryRegistry}).Stateful(State);
}

/// Invoke an in-process generated route through the same service boundary used
/// by native transports. The registry belongs to the application layer graph;
/// this effect never constructs a private runtime or causal store.
pub fn invokeRegistered(request: Grpc.UnaryRequest, options: Grpc.CallOptions) InvokeRegisteredEffect() {
    const State = InvokeRegisteredEffect().StateType;
    return InvokeRegisteredEffect().init(.{ .request = request, .options = options }, struct {
        fn run(state: State, ctx: *fx.kernel.ContextView(.{UnaryRegistry})) anyerror!Grpc.UnaryResponse {
            const started = ctx.recordCausal(.{
                .kind = .io_wait_started,
                .service_key = UnaryRegistry.service_key,
                .label = "grpc.server.invoke",
                .status = "running",
                .redacted_detail = "generated gRPC route invocation started; request, response, metadata, and credentials omitted",
            });
            const response = ctx.service(UnaryRegistry).invokeAlloc(ctx.allocator(), state.request, state.options) catch |err| {
                _ = ctx.recordCausal(.{
                    .kind = .io_completed,
                    .parent_id = started,
                    .cause_event_id = started,
                    .service_key = UnaryRegistry.service_key,
                    .label = "grpc.server.invoke",
                    .type_name = @errorName(err),
                    .status = "failure",
                    .redacted_detail = "generated gRPC route invocation failed; request, response, metadata, and credentials omitted",
                });
                return err;
            };
            _ = ctx.recordCausal(.{
                .kind = .io_completed,
                .parent_id = started,
                .service_key = UnaryRegistry.service_key,
                .label = "grpc.server.invoke",
                .status = if (response.status.isOk()) "success" else "failure",
                .redacted_detail = "generated gRPC route invocation completed; request, response, metadata, and credentials omitted",
            });
            return response;
        }
    }.run);
}

fn MethodRequirements(comptime Implementation: type, comptime method_name: []const u8) type {
    const declaration = method_name ++ "Requirements";
    return struct {
        pub const services = if (@hasDecl(Implementation, declaration))
            @field(Implementation, declaration)
        else if (@hasDecl(Implementation, "RequiredServices"))
            Implementation.RequiredServices
        else
            .{};
    };
}

const CausalCorrelation = struct {
    boundary_id: ?u64 = null,
    trace_id: ?u64 = null,
    span_id: ?u64 = null,
    context: fx.CausalContextV2 = .{},
    lineage_baggage_invalid: bool = false,
};

pub const GeneratedHandlerError = error{
    OutOfMemory,
    HandlerFailed,
    ResponseEncodingFailed,
};

fn generatedHandlerError(err: anyerror) GeneratedHandlerError {
    return if (err == error.OutOfMemory) error.OutOfMemory else error.HandlerFailed;
}

fn generatedEncodingError(err: anyerror) GeneratedHandlerError {
    return if (err == error.OutOfMemory) error.OutOfMemory else error.ResponseEncodingFailed;
}

fn validTraceparent(value: []const u8) bool {
    _ = fx.parseTraceParent(value) catch return false;
    return true;
}

fn causalCorrelation(metadata: []const Grpc.Metadata) CausalCorrelation {
    var request_id: []const u8 = "";
    var traceparent: []const u8 = "";
    var lineage = fx.Lineage.Set.empty;
    var lineage_baggage_invalid = false;
    var lineage_member_seen = false;
    for (metadata) |entry| {
        if ((std.mem.eql(u8, entry.name, "x-request-id") or std.mem.eql(u8, entry.name, "request-id")) and entry.value.len <= 128) {
            request_id = entry.value;
        } else if (std.mem.eql(u8, entry.name, "traceparent")) {
            traceparent = entry.value;
        } else if (std.mem.eql(u8, entry.name, "baggage")) {
            const parsed = fx.Lineage.Set.parseBaggage(entry.value) catch {
                lineage_baggage_invalid = true;
                continue;
            };
            if (!parsed.isEmpty()) {
                if (lineage_member_seen) {
                    lineage_baggage_invalid = true;
                } else {
                    lineage = parsed;
                    lineage_member_seen = true;
                }
            }
        }
    }
    const trace_parent = fx.parseTraceParent(traceparent) catch null;
    var context = if (trace_parent) |trace| trace.context() else fx.CausalContextV2{};
    if (!lineage_baggage_invalid) context.lineage = lineage;

    // A call that arrives without a traceparent is the *root* of a trace, not an
    // untraced call. Without originating one here every causal fact this server
    // records would carry a null trace identity and could never be joined to an
    // exported span. The root identity is derived from the request id rather
    // than a clock or RNG so replaying a recorded scenario reproduces it.
    const root_trace: ?fx.TraceParent = if (trace_parent == null and request_id.len != 0) root: {
        const high = std.hash.Wyhash.hash(0x7a49_0000, request_id);
        const low = std.hash.Wyhash.hash(0x7a49_0001, request_id);
        const span = std.hash.Wyhash.hash(0x7a49_0002, request_id);
        break :root .{
            .trace_id_high = if (high == 0) 1 else high,
            .trace_id_low = if (low == 0) 1 else low,
            .parent_id = if (span == 0) 1 else span,
            .flags = 0,
        };
    } else null;
    if (root_trace) |root| {
        context.trace_id_high = root.trace_id_high;
        context.trace_id_low = root.trace_id_low;
        context.span_id = root.parent_id;
    }

    const effective = trace_parent orelse root_trace;
    return .{
        .boundary_id = if (request_id.len == 0) null else std.hash.Wyhash.hash(0, request_id),
        .trace_id = if (effective) |trace| trace.trace_id_low else null,
        .span_id = if (effective) |trace| trace.parent_id else null,
        .context = context,
        .lineage_baggage_invalid = lineage_baggage_invalid,
    };
}

pub fn GeneratedUnaryHandlerEffect(
    comptime Service: type,
    comptime ImplementationService: type,
    comptime method: Method(Service),
) type {
    if (comptime methodShape(Service, method) != .unary) {
        @compileError("GeneratedUnaryHandlerEffect requires a unary method");
    }
    const Implementation = ImplementationService.API;
    const Requirements = MethodRequirements(Implementation, @tagName(method)).services;
    const Request = RequestType(Service, method);
    const State = struct {
        implementation: *Implementation,
        request: Request,
        correlation: CausalCorrelation,
    };
    return fx.kernel.Effect(Grpc.UnaryResponse, GeneratedHandlerError, Requirements).Stateful(State);
}

fn generatedUnaryHandlerEffect(
    comptime Service: type,
    comptime ImplementationService: type,
    comptime method: Method(Service),
    implementation: *ImplementationService.API,
    request: RequestType(Service, method),
    correlation: CausalCorrelation,
) GeneratedUnaryHandlerEffect(Service, ImplementationService, method) {
    const Implementation = ImplementationService.API;
    const Requirements = MethodRequirements(Implementation, @tagName(method)).services;
    const Response = ResponseType(Service, method);
    const State = GeneratedUnaryHandlerEffect(Service, ImplementationService, method).StateType;
    const implementation_method = @field(Implementation, @tagName(method));
    const implementation_info = @typeInfo(@TypeOf(implementation_method)).@"fn";
    return GeneratedUnaryHandlerEffect(Service, ImplementationService, method).init(.{
        .implementation = implementation,
        .request = request,
        .correlation = correlation,
    }, struct {
        fn run(state: State, ctx: *fx.kernel.ContextView(Requirements)) GeneratedHandlerError!Grpc.UnaryResponse {
            const operation = "grpc.server." ++ @tagName(method);
            const started = ctx.recordCausal(.{
                .kind = .io_wait_started,
                .service_key = ImplementationService.service_key,
                .boundary_id = state.correlation.boundary_id,
                .trace_id = state.correlation.trace_id,
                .span_id = state.correlation.span_id,
                .context = state.correlation.context,
                .label = operation,
                .status = "running",
                .redacted_detail = if (state.correlation.lineage_baggage_invalid)
                    "generated gRPC handler started; invalid lineage baggage omitted"
                else
                    "generated gRPC handler started; request, response, metadata, and credentials omitted",
            });
            const response = if (comptime implementation_info.params.len == 3)
                @call(.auto, implementation_method, .{ state.implementation, ctx, state.request })
            else if (comptime implementation_info.params.len == 4)
                @call(.auto, implementation_method, .{ state.implementation, ctx, ctx.allocator(), state.request })
            else
                @compileError("generated unary effect handler must accept (self, context, request) or (self, context, allocator, request)");
            var value = response catch |err| {
                _ = ctx.recordCausal(.{
                    .kind = .io_completed,
                    .parent_id = started,
                    .cause_event_id = started,
                    .service_key = ImplementationService.service_key,
                    .boundary_id = state.correlation.boundary_id,
                    .trace_id = state.correlation.trace_id,
                    .span_id = state.correlation.span_id,
                    .context = state.correlation.context,
                    .label = operation,
                    .type_name = @errorName(err),
                    .status = "failure",
                    .redacted_detail = "generated gRPC handler failed; request, response, metadata, and credentials omitted",
                });
                return generatedHandlerError(err);
            };
            defer if (comptime implementation_info.params.len == 4)
                deinitMessage(Response, ctx.allocator(), &value);
            const bytes = encodeAlloc(ctx.allocator(), value) catch |err| {
                _ = ctx.recordCausal(.{
                    .kind = .io_completed,
                    .parent_id = started,
                    .cause_event_id = started,
                    .service_key = ImplementationService.service_key,
                    .boundary_id = state.correlation.boundary_id,
                    .trace_id = state.correlation.trace_id,
                    .span_id = state.correlation.span_id,
                    .context = state.correlation.context,
                    .label = operation,
                    .type_name = @errorName(err),
                    .status = "failure",
                    .redacted_detail = "generated gRPC response encoding failed; response omitted",
                });
                return generatedEncodingError(err);
            };
            errdefer ctx.allocator().free(bytes);
            const wire = Grpc.UnaryResponse.initOwnedAlloc(ctx.allocator(), bytes, .ok()) catch |err|
                return generatedEncodingError(err);
            _ = ctx.recordCausal(.{
                .kind = .io_completed,
                .parent_id = started,
                .service_key = ImplementationService.service_key,
                .boundary_id = state.correlation.boundary_id,
                .trace_id = state.correlation.trace_id,
                .span_id = state.correlation.span_id,
                .context = state.correlation.context,
                .label = operation,
                .status = "success",
                .redacted_detail = "generated gRPC handler completed; request, response, metadata, and credentials omitted",
            });
            return wire;
        }
    }.run);
}

pub fn GeneratedStreamingHandlerEffect(
    comptime Service: type,
    comptime ImplementationService: type,
    comptime method: Method(Service),
) type {
    if (comptime methodShape(Service, method) == .unary) {
        @compileError("GeneratedStreamingHandlerEffect requires a streaming method");
    }
    const Implementation = ImplementationService.API;
    const Requirements = MethodRequirements(Implementation, @tagName(method)).services;
    const Request = RequestType(Service, method);
    const Response = ResponseType(Service, method);
    const State = struct {
        implementation: *Implementation,
        stream: *Stream(Request, Response),
        correlation: CausalCorrelation,
    };
    return fx.kernel.Effect(Grpc.Status, GeneratedHandlerError, Requirements).Stateful(State);
}

fn generatedStreamingHandlerEffect(
    comptime Service: type,
    comptime ImplementationService: type,
    comptime method: Method(Service),
    implementation: *ImplementationService.API,
    stream: *Stream(RequestType(Service, method), ResponseType(Service, method)),
    correlation: CausalCorrelation,
) GeneratedStreamingHandlerEffect(Service, ImplementationService, method) {
    const Implementation = ImplementationService.API;
    const Requirements = MethodRequirements(Implementation, @tagName(method)).services;
    const State = GeneratedStreamingHandlerEffect(Service, ImplementationService, method).StateType;
    const implementation_method = @field(Implementation, @tagName(method));
    const implementation_info = @typeInfo(@TypeOf(implementation_method)).@"fn";
    return GeneratedStreamingHandlerEffect(Service, ImplementationService, method).init(.{
        .implementation = implementation,
        .stream = stream,
        .correlation = correlation,
    }, struct {
        fn run(state: State, ctx: *fx.kernel.ContextView(Requirements)) GeneratedHandlerError!Grpc.Status {
            if (comptime implementation_info.params.len != 3) {
                @compileError("generated streaming effect handler must accept (self, context, stream)");
            }
            const operation = "grpc.server." ++ @tagName(method);
            const started = ctx.recordCausal(.{
                .kind = .io_wait_started,
                .service_key = ImplementationService.service_key,
                .boundary_id = state.correlation.boundary_id,
                .trace_id = state.correlation.trace_id,
                .span_id = state.correlation.span_id,
                .context = state.correlation.context,
                .label = operation,
                .status = "running",
                .redacted_detail = "generated streaming gRPC handler started; messages, metadata, and credentials omitted",
            });
            const status = @call(.auto, implementation_method, .{ state.implementation, ctx, state.stream }) catch |err| {
                _ = ctx.recordCausal(.{
                    .kind = .io_completed,
                    .parent_id = started,
                    .cause_event_id = started,
                    .service_key = ImplementationService.service_key,
                    .boundary_id = state.correlation.boundary_id,
                    .trace_id = state.correlation.trace_id,
                    .span_id = state.correlation.span_id,
                    .context = state.correlation.context,
                    .label = operation,
                    .type_name = @errorName(err),
                    .status = "failure",
                    .redacted_detail = "generated streaming gRPC handler failed; messages and metadata omitted",
                });
                return generatedHandlerError(err);
            };
            _ = ctx.recordCausal(.{
                .kind = .io_completed,
                .parent_id = started,
                .service_key = ImplementationService.service_key,
                .boundary_id = state.correlation.boundary_id,
                .trace_id = state.correlation.trace_id,
                .span_id = state.correlation.span_id,
                .context = state.correlation.context,
                .label = operation,
                .status = if (status.isOk()) "success" else "failure",
                .redacted_detail = "generated streaming gRPC handler completed; messages and metadata omitted",
            });
            return status;
        }
    }.run);
}

fn generatedRouteRequirementsUpperBound(comptime Service: type, comptime ImplementationService: type) usize {
    @setEvalBranchQuota(100_000);
    const Implementation = ImplementationService.API;
    comptime var total: usize = 3;
    inline for (std.meta.fields(Service)) |field| {
        total += MethodRequirements(Implementation, field.name).services.len;
    }
    return total;
}

fn generatedRouteRequirementCount(comptime Service: type, comptime ImplementationService: type) usize {
    @setEvalBranchQuota(100_000);
    const Implementation = ImplementationService.API;
    comptime var seen: [generatedRouteRequirementsUpperBound(Service, ImplementationService)]type = undefined;
    comptime var count: usize = 0;
    inline for (.{ ImplementationService, UnaryRegistry, IncrementalRegistry }) |Tag| {
        if (!fx.kernel.contains(seen[0..count], Tag)) {
            seen[count] = Tag;
            count += 1;
        }
    }
    inline for (std.meta.fields(Service)) |field| {
        inline for (MethodRequirements(Implementation, field.name).services) |Tag| {
            if (!fx.kernel.contains(seen[0..count], Tag)) {
                seen[count] = Tag;
                count += 1;
            }
        }
    }
    return count;
}

pub fn GeneratedRoutesRequirements(
    comptime Service: type,
    comptime ImplementationService: type,
) [generatedRouteRequirementCount(Service, ImplementationService)]type {
    @setEvalBranchQuota(100_000);
    const Implementation = ImplementationService.API;
    comptime var result: [generatedRouteRequirementCount(Service, ImplementationService)]type = undefined;
    comptime var count: usize = 0;
    inline for (.{ ImplementationService, UnaryRegistry, IncrementalRegistry }) |Tag| {
        if (!fx.kernel.contains(result[0..count], Tag)) {
            result[count] = Tag;
            count += 1;
        }
    }
    inline for (std.meta.fields(Service)) |field| {
        inline for (MethodRequirements(Implementation, field.name).services) |Tag| {
            if (!fx.kernel.contains(result[0..count], Tag)) {
                result[count] = Tag;
                count += 1;
            }
        }
    }
    return result;
}

pub fn GeneratedServerAdapter(comptime Service: type, comptime ImplementationService: type) type {
    const Implementation = ImplementationService.API;
    const Requirements = GeneratedRoutesRequirements(Service, ImplementationService);
    return struct {
        const Self = @This();

        allocator: std.mem.Allocator,
        runtime: fx.kernel.RuntimeHandle(Requirements),
        implementation: *Implementation,

        fn init(
            allocator: std.mem.Allocator,
            runtime: fx.kernel.RuntimeHandle(Requirements),
            implementation: *Implementation,
        ) Self {
            return .{ .allocator = allocator, .runtime = runtime, .implementation = implementation };
        }

        fn registerAll(self: *Self, unary: *Grpc.Registry, incremental: *Incremental.Registry) !void {
            inline for (std.meta.fields(Service)) |field| {
                const shape = comptime shapeForField(field.type);
                if (shape == .unary) {
                    try unary.register(.{
                        .service = serviceFullName(Service),
                        .method = field.name,
                        .handler = Grpc.UnaryHandler.from(Self, self),
                    });
                } else {
                    try incremental.register(
                        serviceFullName(Service),
                        field.name,
                        shape,
                        Incremental.Handler.from(Self, self),
                    );
                }
            }
        }

        pub fn invoke(self: *Self, allocator: std.mem.Allocator, request: Grpc.UnaryRequest) anyerror!Grpc.UnaryResponse {
            inline for (std.meta.fields(Service)) |field| {
                if (comptime shapeForField(field.type) == .unary) {
                    if (std.mem.eql(u8, request.method, field.name)) {
                        const method: Method(Service) = @field(Method(Service), field.name);
                        const Request = RequestType(Service, method);
                        var decoded = try decodeAlloc(Request, allocator, request.payload);
                        defer deinitMessage(Request, allocator, &decoded);
                        const correlation = causalCorrelation(request.metadata);
                        var runtime = self.runtime.withCausalContext(correlation.context);
                        return runtime.run(generatedUnaryHandlerEffect(
                            Service,
                            ImplementationService,
                            method,
                            self.implementation,
                            decoded,
                            correlation,
                        ).named("grpc.server." ++ field.name));
                    }
                }
            }
            return Grpc.UnaryResponse.initAlloc(allocator, "", .{
                .code = .unimplemented,
                .message = "generated method not registered",
            });
        }

        pub fn runIncremental(self: *Self, call: *Incremental.Call) anyerror!Grpc.Status {
            inline for (std.meta.fields(Service)) |field| {
                if (comptime shapeForField(field.type) != .unary) {
                    if (std.mem.eql(u8, call.context.method, field.name)) {
                        const method: Method(Service) = @field(Method(Service), field.name);
                        var stream = Stream(RequestType(Service, method), ResponseType(Service, method)){
                            .allocator = self.allocator,
                            .call = call,
                        };
                        const correlation = causalCorrelation(call.context.metadata);
                        var runtime = self.runtime.withCausalContext(correlation.context);
                        return runtime.run(generatedStreamingHandlerEffect(
                            Service,
                            ImplementationService,
                            method,
                            self.implementation,
                            &stream,
                            correlation,
                        ).named("grpc.server." ++ field.name));
                    }
                }
            }
            return .{ .code = .unimplemented, .message = "generated method not registered" };
        }
    };
}

pub fn GeneratedRoutes(comptime Service: type, comptime ImplementationService: type) type {
    return struct {
        pub const operations: []const []const u8 = &.{ "GeneratedRoutes.invoke", "GeneratedRoutes.stream" };
        adapter: *GeneratedServerAdapter(Service, ImplementationService),
    };
}

pub fn GeneratedRoutesService(comptime Service: type, comptime ImplementationService: type) type {
    return fx.kernel.Service(
        "zigeffect/grpc/routes/" ++ serviceFullName(Service) ++ "/" ++ ImplementationService.service_key,
        GeneratedRoutes(Service, ImplementationService),
    );
}

fn GeneratedRoutesLifecycle(comptime Service: type, comptime ImplementationService: type) type {
    const Requirements = GeneratedRoutesRequirements(Service, ImplementationService);
    const Routes = GeneratedRoutes(Service, ImplementationService);
    const Adapter = GeneratedServerAdapter(Service, ImplementationService);
    return struct {
        fn acquire(ctx: *fx.kernel.ContextView(Requirements)) anyerror!Routes {
            const adapter = try ctx.allocator().create(Adapter);
            errdefer ctx.allocator().destroy(adapter);
            adapter.* = Adapter.init(ctx.allocator(), ctx.runtime(), ctx.service(ImplementationService));
            try adapter.registerAll(ctx.service(UnaryRegistry), ctx.service(IncrementalRegistry));
            return .{ .adapter = adapter };
        }

        fn release(routes: *Routes) void {
            routes.adapter.allocator.destroy(routes.adapter);
        }
    };
}

pub fn generatedRoutesLayer(
    comptime Service: type,
    comptime ImplementationService: type,
) @TypeOf(fx.kernel.Layer.scoped(
    GeneratedRoutesService(Service, ImplementationService),
    anyerror,
    GeneratedRoutesRequirements(Service, ImplementationService),
    GeneratedRoutesLifecycle(Service, ImplementationService).acquire,
    GeneratedRoutesLifecycle(Service, ImplementationService).release,
)) {
    return fx.kernel.Layer.scoped(
        GeneratedRoutesService(Service, ImplementationService),
        anyerror,
        GeneratedRoutesRequirements(Service, ImplementationService),
        GeneratedRoutesLifecycle(Service, ImplementationService).acquire,
        GeneratedRoutesLifecycle(Service, ImplementationService).release,
    );
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

test "boundary correlation originates a root trace when the caller supplies none" {
    // Inbound traceparent wins: the server joins the caller's trace.
    const joined = causalCorrelation(&.{
        .{ .name = "traceparent", .value = "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01" },
        .{ .name = "x-request-id", .value = "request-42" },
    });
    try std.testing.expectEqual(@as(u64, 0xa3ce929d0e0e4736), joined.trace_id.?);
    try std.testing.expectEqual(@as(u64, 0x00f067aa0ba902b7), joined.span_id.?);

    // No traceparent: the call is the root of a trace rather than untraced.
    const root = causalCorrelation(&.{.{ .name = "x-request-id", .value = "request-42" }});
    try std.testing.expect(root.trace_id != null);
    try std.testing.expect(root.span_id != null);
    try std.testing.expect(root.context.trace_id_high != null);
    try std.testing.expectEqual(root.trace_id.?, root.context.trace_id_low.?);
    try std.testing.expectEqual(root.span_id.?, root.context.span_id.?);
    // A root trace must not be mistaken for the caller's trace.
    try std.testing.expect(root.trace_id.? != joined.trace_id.?);

    // Deterministic: replaying the same request reproduces the same identity.
    const replay = causalCorrelation(&.{.{ .name = "x-request-id", .value = "request-42" }});
    try std.testing.expectEqual(root.trace_id.?, replay.trace_id.?);
    try std.testing.expectEqual(root.span_id.?, replay.span_id.?);
    // Distinct requests are distinct traces.
    const other = causalCorrelation(&.{.{ .name = "x-request-id", .value = "request-43" }});
    try std.testing.expect(other.trace_id.? != root.trace_id.?);

    // Lineage baggage survives root origination.
    const ProductId = fx.Lineage.Key([]const u8, .{
        .name = "commerce.product.id",
        .privacy = .internal,
        .propagation = .distributed,
        .export_policy = .otel,
    });
    const product = try ProductId.reference(77, "product-42");
    var baggage_buffer: [fx.Lineage.max_baggage_bytes]u8 = undefined;
    const baggage = try fx.Lineage.Set.empty.with(product).formatBaggage(&baggage_buffer);
    const with_baggage = causalCorrelation(&.{
        .{ .name = "x-request-id", .value = "request-42" },
        .{ .name = "baggage", .value = baggage },
    });
    try std.testing.expect(with_baggage.trace_id != null);
    try std.testing.expect(!with_baggage.context.lineage.isEmpty());
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
    var binding = GeneratedDriverBinding(Service, Implementation).init(std.testing.allocator, &implementation);
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

test "generated server uses canonical requirements layers runtime child scope and durable causal graph" {
    const State = struct {
        var finalized: bool = false;
        var encoded_before_finalize: bool = false;

        fn reset() void {
            finalized = false;
            encoded_before_finalize = false;
        }

        fn release(_: ?*anyopaque) void {
            finalized = true;
        }
    };
    const Message = struct {
        value: u8 = 0,

        pub fn encode(self: @This(), writer: *std.Io.Writer, _: std.mem.Allocator) !void {
            State.encoded_before_finalize = !State.finalized;
            try writer.writeByte(self.value);
        }

        pub fn decode(reader: *std.Io.Reader, _: std.mem.Allocator) !@This() {
            return .{ .value = try reader.takeByte() };
        }

        pub fn deinit(_: *@This(), _: std.mem.Allocator) void {}
    };
    const Service = struct {
        pub const package = "example.v1";
        pub const service_name = "Layered";
        Increment: *const fn (*void, Message) error{}!Message,
    };
    const CounterApi = struct {
        pub const operations: []const []const u8 = &.{"Counter.increment"};
        amount: u8,
    };
    const Counter = fx.kernel.Service("test/grpc/Counter", CounterApi);

    State.reset();
    const Implementation = struct {
        pub const RequiredServices = .{Counter};

        fn Increment(_: *@This(), ctx: *fx.kernel.ContextView(RequiredServices), request: Message) !Message {
            const counter_service = ctx.service(Counter);
            try ctx.scope().addFinalizer(null, State.release);
            return .{ .value = request.value + counter_service.amount };
        }
    };
    const ImplementationService = fx.kernel.Service("test/grpc/LayeredImplementation", Implementation);
    const HandlerEffect = GeneratedUnaryHandlerEffect(Service, ImplementationService, .Increment);
    try std.testing.expect(HandlerEffect.FailureType == GeneratedHandlerError);
    try std.testing.expect(fx.kernel.contains(HandlerEffect.RequiredServices, Counter));
    const dependencies = fx.kernel.Layer.mergeAll(.{
        fx.kernel.Layer.succeed(Counter, .{ .amount = 2 }),
        fx.kernel.Layer.succeed(ImplementationService, .{}),
        unaryRegistryLayer(),
        incrementalRegistryLayer(),
    });
    const routes = generatedRoutesLayer(Service, ImplementationService).provideMerge(dependencies);
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    var runtime = try zstd.ManagedRuntime(@TypeOf(routes)).make(
        std.testing.allocator,
        std.testing.io,
        tmp.dir,
        routes,
        .{},
    );
    defer runtime.deinit();

    const payload = try encodeAlloc(std.testing.allocator, Message{ .value = 40 });
    defer std.testing.allocator.free(payload);
    const ProductId = fx.Lineage.Key([]const u8, .{
        .name = "commerce.product.id",
        .privacy = .internal,
        .propagation = .distributed,
        .export_policy = .otel,
    });
    const product = try ProductId.reference(77, "product-42");
    var baggage_buffer: [fx.Lineage.max_baggage_bytes]u8 = undefined;
    const baggage = try fx.Lineage.Set.empty.with(product).formatBaggage(&baggage_buffer);
    State.reset();
    const invoke_program = invokeRegistered(.{
        .authority = "local",
        .service = "example.v1.Layered",
        .method = "Increment",
        .payload = payload,
        .metadata = &.{
            .{ .name = "x-request-id", .value = "layered-42" },
            .{ .name = "traceparent", .value = "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01" },
            .{ .name = "baggage", .value = baggage },
        },
        .timeout_millis = 1_000,
    }, .{}).named("grpc.test.invoke");
    try std.testing.expect(fx.kernel.contains(@TypeOf(invoke_program).RequiredServices, UnaryRegistry));
    try std.testing.expect(!@hasDecl(@TypeOf(invoke_program), "EnvType"));
    var response = try runtime.run(invoke_program);
    defer response.deinit();
    var decoded = try decodeAlloc(Message, std.testing.allocator, response.payload);
    defer decoded.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(u8, 42), decoded.value);
    try std.testing.expect(State.encoded_before_finalize);
    try std.testing.expect(State.finalized);

    var snapshot = try runtime.inspect(std.testing.allocator, .{ .max_recent_events = 512 });
    defer snapshot.deinit();
    var handler_operation_id: ?u64 = null;
    var saw_boundary_correlation = false;
    var service_parent_id: ?u64 = null;
    var saw_request_scope = false;
    var saw_product_lineage = false;
    for (snapshot.causal.recent_events) |event| {
        if (event.kind == .io_wait_started and std.mem.eql(u8, event.label, "grpc.server.Increment")) {
            handler_operation_id = event.id;
            saw_boundary_correlation = event.boundary_id == std.hash.Wyhash.hash(0, "layered-42") and
                event.trace_id == @as(u64, 0xa3ce929d0e0e4736) and
                event.span_id == @as(u64, 0x00f067aa0ba902b7) and
                event.context.trace_id_high == @as(u64, 0x4bf92f3577b34da6) and
                event.context.trace_id_low == @as(u64, 0xa3ce929d0e0e4736);
        }
        if (event.kind == .service_required and std.mem.eql(u8, event.service_key, Counter.service_key) and std.mem.eql(u8, event.status, "resolved")) {
            service_parent_id = event.parent_id;
            saw_product_lineage = event.context.lineage.contains(product);
        }
        if (event.kind == .scope_closed and std.mem.eql(u8, event.status, "success")) saw_request_scope = true;
    }
    try std.testing.expect(handler_operation_id != null);
    try std.testing.expect(saw_boundary_correlation);
    try std.testing.expect(service_parent_id != null);
    try std.testing.expect(saw_product_lineage);
    try std.testing.expect(saw_request_scope);
    try std.testing.expect(runtime.graphSummary().records > 0);
    try runtime.shutdown();
}

test "generated client call is a layered effect with automatic causal lineage" {
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
        pub const service_name = "ClientEffect";
        Increment: *const fn (*void, Message) error{}!Message,
    };
    const Wire = struct {
        fn unary(_: *anyopaque, allocator: std.mem.Allocator, request: Grpc.UnaryRequest, _: Grpc.CallOptions) anyerror!Grpc.UnaryResponse {
            return Grpc.UnaryResponse.initAlloc(allocator, &.{request.payload[0] + 1}, .ok());
        }

        fn streaming(_: *anyopaque, allocator: std.mem.Allocator, _: Grpc.StreamingRequest, _: Grpc.CallOptions) anyerror!Grpc.StreamingResponse {
            return Grpc.StreamingResponse.initAlloc(allocator, &.{}, .ok());
        }
    };
    const ClientService = GeneratedClientService(Service);

    var marker: u8 = 0;
    const client = GeneratedClient(Service).init(
        "local",
        .{ .ptr = &marker, .invoke_fn = Wire.unary },
        .{ .pointer = &marker, .invoke_fn = Wire.streaming },
    );
    const layer = generatedClientLayer(Service, client);
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    var runtime = try zstd.ManagedRuntime(@TypeOf(layer)).make(std.testing.allocator, std.testing.io, tmp.dir, layer, .{});
    defer runtime.deinit();

    const program = generatedUnaryEffect(Service, .Increment, .{ .value = 41 }, .{}).named("grpc.client.increment");
    try std.testing.expect(fx.kernel.contains(@TypeOf(program).RequiredServices, ClientService));
    try std.testing.expect(!@hasDecl(@TypeOf(program), "EnvType"));
    var response = try runtime.run(program);
    defer response.deinit();
    try std.testing.expectEqual(@as(u8, 42), response.value.?.value);

    var snapshot = try runtime.inspect(std.testing.allocator, .{ .max_recent_events = 256 });
    defer snapshot.deinit();
    var saw_service = false;
    var saw_call = false;
    for (snapshot.causal.recent_events) |event| {
        if (event.kind == .service_required and std.mem.eql(u8, event.service_key, ClientService.service_key)) saw_service = true;
        if (event.kind == .io_completed and std.mem.eql(u8, event.service_key, ClientService.service_key) and std.mem.eql(u8, event.label, "grpc.client.Increment")) saw_call = true;
    }
    try std.testing.expect(saw_service);
    try std.testing.expect(saw_call);
    try runtime.shutdown();
}
