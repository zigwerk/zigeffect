const std = @import("std");
const Json = @import("../json/root.zig");
const Schema = @import("../schema/root.zig");
const Secrets = @import("../secrets/root.zig");
const Capability = @import("../capability/root.zig");
const External = @import("../external/root.zig");
const StdService = @import("../service/root.zig");
const fx = @import("zigeffect");
const Stream = @import("../stream/root.zig");

pub const Header = struct {
    name: []const u8,
    value: []const u8,
};

pub const Request = struct {
    method: []const u8,
    url: []const u8,
    headers: []const Header = &.{},
    body: []const u8 = "",
};

pub const TransportError = error{
    ResponseBodyTooLarge,
    ConnectTimeout,
    RequestTimeout,
    RequestCancelled,
    UnsupportedHttpMethod,
    ScriptExhausted,
    TransportFailure,
};

pub const ClientError = TransportError || std.mem.Allocator.Error;

pub const Cancellation = struct {
    ptr: *const anyopaque,
    isCancelledFn: *const fn (*const anyopaque) bool,

    pub fn isCancelled(self: Cancellation) bool {
        return self.isCancelledFn(self.ptr);
    }

    pub fn fromBool(value: *const bool) Cancellation {
        return .{ .ptr = value, .isCancelledFn = boolCancelled };
    }

    fn boolCancelled(raw: *const anyopaque) bool {
        const value: *const bool = @ptrCast(@alignCast(raw));
        return value.*;
    }
};

pub const SendOptions = struct {
    response_body_limit: usize = 1024 * 1024,
    connect_timeout_millis: u64 = 10_000,
    request_timeout_millis: u64 = 60_000,
    cancellation: ?Cancellation = null,

    pub fn checkActive(self: SendOptions) TransportError!void {
        if (self.cancellation) |cancellation| {
            if (cancellation.isCancelled()) return error.RequestCancelled;
        }
    }
};

pub fn requestBodyStreamAlloc(allocator: std.mem.Allocator, request: Request) !fx.EffectStream(u8, anyerror, Stream.EmptyEnv) {
    return Stream.ownedBytesAlloc(allocator, request.body);
}
pub fn responseBodyStreamAlloc(allocator: std.mem.Allocator, response: Response) !fx.EffectStream(u8, anyerror, Stream.EmptyEnv) {
    return Stream.ownedBytesAlloc(allocator, response.body);
}

pub const Response = struct {
    status: u16,
    headers: []const Header = &.{},
    body: []const u8 = "",

    pub fn deinit(self: *Response, allocator: std.mem.Allocator) void {
        freeHeaders(allocator, self.headers);
        allocator.free(self.body);
        self.* = undefined;
    }

    pub fn header(self: Response, name: []const u8) ?[]const u8 {
        for (self.headers) |candidate| {
            if (eqlInsensitive(candidate.name, name)) return candidate.value;
        }
        return null;
    }

    pub fn retryAfterMillis(self: Response, now_epoch_seconds: u64) ?u64 {
        const raw = self.header("retry-after") orelse return null;
        if (std.fmt.parseInt(u64, raw, 10)) |seconds| {
            return std.math.mul(u64, seconds, std.time.ms_per_s) catch null;
        } else |_| {}
        const retry_epoch = parseHttpDate(raw) orelse return null;
        const delay_seconds = retry_epoch -| now_epoch_seconds;
        return std.math.mul(u64, delay_seconds, std.time.ms_per_s) catch null;
    }
};

pub const Client = struct {
    pub const operations: []const []const u8 = &.{"HttpClient.send"};
    ptr: *anyopaque,
    sendFn: *const fn (*anyopaque, std.mem.Allocator, Request, SendOptions) ClientError!Response,

    pub fn sendAlloc(
        self: Client,
        allocator: std.mem.Allocator,
        request: Request,
        options: SendOptions,
    ) ClientError!Response {
        return self.sendFn(self.ptr, allocator, request, options);
    }

    pub fn from(comptime T: type, pointer: *T) Client {
        return .{
            .ptr = pointer,
            .sendFn = struct {
                fn call(raw: *anyopaque, allocator: std.mem.Allocator, request: Request, options: SendOptions) ClientError!Response {
                    return (@as(*T, @ptrCast(@alignCast(raw)))).sendAllocWithOptions(allocator, request, options);
                }
            }.call,
        };
    }
};

pub const HttpClient = fx.kernel.Service("zigeffect/std/HttpClient", Client);

pub fn clientLayer(client: Client) @TypeOf(fx.kernel.Layer.succeed(HttpClient, client)) {
    return fx.kernel.Layer.succeed(HttpClient, client);
}

pub const RouteResult = struct {
    response: Response,
    receipt_json: []const u8,
    trace_json: []const u8,

    pub fn deinit(self: *RouteResult, allocator: std.mem.Allocator) void {
        self.response.deinit(allocator);
        allocator.free(self.receipt_json);
        allocator.free(self.trace_json);
        self.* = undefined;
    }
};

pub const FakeClient = struct {
    pub const capability = Capability.Builtin.fake_http_client;

    response: Response,

    pub fn init(response: Response) FakeClient {
        return .{ .response = response };
    }

    pub fn send(self: FakeClient, request: Request) Response {
        _ = request;
        return self.response;
    }

    pub fn sendAlloc(self: *FakeClient, allocator: std.mem.Allocator, request: Request) std.mem.Allocator.Error!Response {
        _ = request;
        return cloneResponseAlloc(allocator, self.response);
    }

    pub fn sendAllocWithOptions(
        self: *FakeClient,
        allocator: std.mem.Allocator,
        request: Request,
        options: SendOptions,
    ) ClientError!Response {
        _ = request;
        try options.checkActive();
        if (self.response.body.len > options.response_body_limit) return error.ResponseBodyTooLarge;
        return cloneResponseAlloc(allocator, self.response);
    }

    pub fn client(self: *FakeClient) Client {
        return .{ .ptr = self, .sendFn = sendErased };
    }

    fn sendErased(
        raw: *anyopaque,
        allocator: std.mem.Allocator,
        request: Request,
        options: SendOptions,
    ) ClientError!Response {
        const self: *FakeClient = @ptrCast(@alignCast(raw));
        return self.sendAllocWithOptions(allocator, request, options);
    }

    pub fn sendClassifiedAlloc(self: *FakeClient, allocator: std.mem.Allocator, request: Request) External.Result(Response) {
        const response = self.sendAlloc(allocator, request) catch |err| {
            return .{ .failure = External.Failure.fromError("fake-http", "send", err) };
        };
        return .{ .success = response };
    }
};

pub const ScriptedClient = struct {
    const Step = union(enum) {
        response: Response,
        failure: TransportError,
    };

    allocator: std.mem.Allocator,
    steps: std.ArrayList(Step) = .empty,
    cursor: usize = 0,

    pub fn init(allocator: std.mem.Allocator) ScriptedClient {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *ScriptedClient) void {
        for (self.steps.items) |*step| switch (step.*) {
            .response => |*response| response.deinit(self.allocator),
            .failure => {},
        };
        self.steps.deinit(self.allocator);
        self.* = undefined;
    }

    pub fn addResponse(self: *ScriptedClient, response: Response) std.mem.Allocator.Error!void {
        var owned = try cloneResponseAlloc(self.allocator, response);
        errdefer owned.deinit(self.allocator);
        try self.steps.append(self.allocator, .{ .response = owned });
    }

    pub fn addError(self: *ScriptedClient, failure: TransportError) std.mem.Allocator.Error!void {
        try self.steps.append(self.allocator, .{ .failure = failure });
    }

    pub fn sendAllocWithOptions(
        self: *ScriptedClient,
        allocator: std.mem.Allocator,
        request: Request,
        options: SendOptions,
    ) ClientError!Response {
        _ = request;
        try options.checkActive();
        if (self.cursor >= self.steps.items.len) return error.ScriptExhausted;
        const step = self.steps.items[self.cursor];
        self.cursor += 1;
        return switch (step) {
            .failure => |failure| failure,
            .response => |response| {
                if (response.body.len > options.response_body_limit) return error.ResponseBodyTooLarge;
                return cloneResponseAlloc(allocator, response);
            },
        };
    }

    pub fn client(self: *ScriptedClient) Client {
        return .{ .ptr = self, .sendFn = sendErased };
    }

    fn sendErased(
        raw: *anyopaque,
        allocator: std.mem.Allocator,
        request: Request,
        options: SendOptions,
    ) ClientError!Response {
        const self: *ScriptedClient = @ptrCast(@alignCast(raw));
        return self.sendAllocWithOptions(allocator, request, options);
    }
};

pub fn JsonEndpoint(comptime RequestSchema: type, comptime ResponseSchema: type, comptime Handler: type) type {
    return struct {
        const Self = @This();

        method: []const u8,
        path: []const u8,
        request_schema: RequestSchema,
        response_schema: ResponseSchema,
        handler: Handler,

        pub fn matches(self: Self, request: Request) bool {
            return eqlInsensitive(self.method, request.method) and std.mem.eql(u8, self.path, requestPath(request.url));
        }

        pub fn routeName(self: Self) []const u8 {
            _ = self;
            return RequestSchemaRouteName(Self);
        }

        pub fn handleAlloc(self: Self, allocator: std.mem.Allocator, request: Request) !RouteResult {
            var decoded = try Schema.decodeDetailedJsonAlloc(allocator, self.request_schema, request.body);
            defer decoded.deinit();

            if (!decoded.ok()) {
                const issues_json = try decoded.issues.jsonAlloc(allocator);
                defer allocator.free(issues_json);
                const route_name = try routeNameAlloc(allocator, self.method, self.path);
                defer allocator.free(route_name);
                return routeErrorResultAlloc(allocator, 400, route_name, "validation_failed", issues_json, request);
            }

            const output = self.handler(allocator, decoded.value.?) catch |err| {
                const route_name = try routeNameAlloc(allocator, self.method, self.path);
                defer allocator.free(route_name);
                return routeErrorResultAlloc(allocator, 500, route_name, "handler_failed", @errorName(err), request);
            };

            const body = Schema.encodeJsonAlloc(allocator, self.response_schema, output) catch |err| {
                const route_name = try routeNameAlloc(allocator, self.method, self.path);
                defer allocator.free(route_name);
                return routeErrorResultAlloc(allocator, 500, route_name, "encode_failed", @errorName(err), request);
            };
            defer allocator.free(body);

            const response = try jsonResponseAlloc(allocator, 200, body);
            errdefer {
                var mutable_response = response;
                mutable_response.deinit(allocator);
            }

            const route_name = try routeNameAlloc(allocator, self.method, self.path);
            defer allocator.free(route_name);
            const receipt_json = try routeReceiptJsonAlloc(allocator, route_name, "success", 200);
            errdefer allocator.free(receipt_json);
            const trace_json = try routeTraceJsonAlloc(allocator, route_name, "success", 200, request);
            errdefer allocator.free(trace_json);

            return .{
                .response = response,
                .receipt_json = receipt_json,
                .trace_json = trace_json,
            };
        }
    };
}

pub fn jsonEndpoint(
    method: []const u8,
    path: []const u8,
    request_schema: anytype,
    response_schema: anytype,
    handler: anytype,
) JsonEndpoint(@TypeOf(request_schema), @TypeOf(response_schema), *const @TypeOf(handler)) {
    return .{
        .method = method,
        .path = path,
        .request_schema = request_schema,
        .response_schema = response_schema,
        .handler = handler,
    };
}

pub fn Router(comptime Routes: type) type {
    return struct {
        const Self = @This();

        routes: Routes,

        pub fn handleAlloc(self: *Self, allocator: std.mem.Allocator, request: Request) !RouteResult {
            inline for (@typeInfo(Routes).@"struct".fields) |field_info| {
                const endpoint = @field(self.routes, field_info.name);
                if (endpoint.matches(request)) {
                    return endpoint.handleAlloc(allocator, request);
                }
            }
            return routeErrorResultAlloc(allocator, 404, "unmatched", "route_not_found", requestPath(request.url), request);
        }
    };
}

pub fn router(routes: anytype) Router(@TypeOf(routes)) {
    return .{ .routes = routes };
}

pub const LocalClient = struct {
    pub const capability = Capability.Builtin.local_http_client;

    transport: std.http.Client,
    response_body_limit: usize = 1024 * 1024,

    pub fn init(allocator: std.mem.Allocator, io: std.Io) LocalClient {
        return .{
            .transport = .{
                .allocator = allocator,
                .io = io,
            },
        };
    }

    pub fn deinit(self: *LocalClient) void {
        self.transport.deinit();
    }

    pub fn sendAlloc(self: *LocalClient, allocator: std.mem.Allocator, request: Request) anyerror!Response {
        return self.sendAllocWithOptions(allocator, request, .{
            .response_body_limit = self.response_body_limit,
        });
    }

    pub fn sendAllocWithOptions(
        self: *LocalClient,
        allocator: std.mem.Allocator,
        request: Request,
        options: SendOptions,
    ) ClientError!Response {
        try options.checkActive();
        if (options.connect_timeout_millis == 0) return error.ConnectTimeout;
        if (options.request_timeout_millis == 0) return error.RequestTimeout;
        const method = parseHttpMethod(request.method) orelse return error.UnsupportedHttpMethod;
        const extra_headers = try allocator.alloc(std.http.Header, request.headers.len);
        defer allocator.free(extra_headers);
        for (request.headers, 0..) |header, index| {
            extra_headers[index] = .{ .name = header.name, .value = header.value };
        }

        const uri = std.Uri.parse(request.url) catch return error.TransportFailure;
        var live_request = self.transport.request(method, uri, .{
            .redirect_behavior = .unhandled,
            .headers = .{ .accept_encoding = .omit },
            .extra_headers = extra_headers,
            .privileged_headers = &.{},
            .keep_alive = false,
        }) catch |err| return mapConnectError(err);
        defer live_request.deinit();

        if (request.body.len == 0 and !method.requestHasBody()) {
            live_request.sendBodiless() catch |err| return mapRequestError(err);
        } else {
            live_request.transfer_encoding = .{ .content_length = request.body.len };
            var body_writer = live_request.sendBodyUnflushed(&.{}) catch |err| return mapRequestError(err);
            body_writer.writer.writeAll(request.body) catch |err| return mapRequestError(err);
            body_writer.end() catch |err| return mapRequestError(err);
            live_request.connection.?.flush() catch |err| return mapRequestError(err);
        }

        var live_response = live_request.receiveHead(&.{}) catch |err| return mapRequestError(err);
        const headers = try cloneLiveHeadersAlloc(allocator, live_response.head);
        errdefer freeHeaders(allocator, headers);
        if (live_response.head.content_length) |content_length| {
            if (content_length > options.response_body_limit) return error.ResponseBodyTooLarge;
        }
        try options.checkActive();

        const response_buffer = try allocator.alloc(u8, options.response_body_limit);
        defer allocator.free(response_buffer);
        var response_writer = std.Io.Writer.fixed(response_buffer);
        const response_reader = live_response.reader(&.{});
        _ = response_reader.streamRemaining(&response_writer) catch |err| {
            if (response_writer.buffered().len >= options.response_body_limit) {
                return error.ResponseBodyTooLarge;
            }
            return mapRequestError(err);
        };
        try options.checkActive();
        const body = try allocator.dupe(u8, response_writer.buffered());
        errdefer allocator.free(body);

        return .{
            .status = @intCast(@intFromEnum(live_response.head.status)),
            .headers = headers,
            .body = body,
        };
    }

    pub fn client(self: *LocalClient) Client {
        return .{ .ptr = self, .sendFn = sendErased };
    }

    fn sendErased(
        raw: *anyopaque,
        allocator: std.mem.Allocator,
        request: Request,
        options: SendOptions,
    ) ClientError!Response {
        const self: *LocalClient = @ptrCast(@alignCast(raw));
        return self.sendAllocWithOptions(allocator, request, options);
    }

    pub fn sendClassifiedAlloc(self: *LocalClient, allocator: std.mem.Allocator, request: Request) External.Result(Response) {
        const response = self.sendAlloc(allocator, request) catch |err| {
            return .{ .failure = External.Failure.fromError("http", "send", err) };
        };
        return .{ .success = response };
    }
};

fn cloneLiveHeadersAlloc(
    allocator: std.mem.Allocator,
    head: std.http.Client.Response.Head,
) std.mem.Allocator.Error![]Header {
    var headers = std.ArrayList(Header).empty;
    errdefer {
        for (headers.items) |header| {
            allocator.free(header.name);
            allocator.free(header.value);
        }
        headers.deinit(allocator);
    }
    var iterator = head.iterateHeaders();
    while (iterator.next()) |header| {
        const name = try allocator.dupe(u8, header.name);
        errdefer allocator.free(name);
        const value = try allocator.dupe(u8, header.value);
        errdefer allocator.free(value);
        try headers.append(allocator, .{ .name = name, .value = value });
    }
    return headers.toOwnedSlice(allocator);
}

fn mapConnectError(err: anyerror) ClientError {
    if (std.mem.indexOf(u8, @errorName(err), "Timeout") != null) return error.ConnectTimeout;
    if (std.mem.indexOf(u8, @errorName(err), "Cancel") != null) return error.RequestCancelled;
    if (err == error.OutOfMemory) return error.OutOfMemory;
    return error.TransportFailure;
}

fn mapRequestError(err: anyerror) ClientError {
    if (std.mem.indexOf(u8, @errorName(err), "Timeout") != null) return error.RequestTimeout;
    if (std.mem.indexOf(u8, @errorName(err), "Cancel") != null) return error.RequestCancelled;
    if (err == error.OutOfMemory) return error.OutOfMemory;
    return error.TransportFailure;
}

pub const MemoryServer = struct {
    pub const capability = Capability.Builtin.memory_http_server;

    const Route = struct {
        method: []const u8,
        path: []const u8,
        response: Response,
    };

    allocator: std.mem.Allocator,
    routes: std.ArrayList(Route) = .empty,

    pub fn init(allocator: std.mem.Allocator) MemoryServer {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *MemoryServer) void {
        for (self.routes.items) |*route| {
            self.allocator.free(route.method);
            self.allocator.free(route.path);
            route.response.deinit(self.allocator);
        }
        self.routes.deinit(self.allocator);
    }

    pub fn addRoute(self: *MemoryServer, method: []const u8, path: []const u8, response: Response) std.mem.Allocator.Error!void {
        const owned_method = try self.allocator.dupe(u8, method);
        errdefer self.allocator.free(owned_method);
        const owned_path = try self.allocator.dupe(u8, path);
        errdefer self.allocator.free(owned_path);
        var owned_response = try cloneResponseAlloc(self.allocator, response);
        errdefer owned_response.deinit(self.allocator);

        try self.routes.append(self.allocator, .{
            .method = owned_method,
            .path = owned_path,
            .response = owned_response,
        });
    }

    pub fn handleAlloc(self: *MemoryServer, allocator: std.mem.Allocator, request: Request) std.mem.Allocator.Error!Response {
        const path = requestPath(request.url);
        for (self.routes.items) |route| {
            if (eqlInsensitive(route.method, request.method) and std.mem.eql(u8, route.path, path)) {
                return cloneResponseAlloc(allocator, route.response);
            }
        }

        return cloneResponseAlloc(allocator, .{ .status = 404, .body = "not found" });
    }
};

pub const WebSocketFrame = struct {
    pub const Kind = enum { text, binary, ping, pong, close };

    kind: Kind,
    payload: []const u8,

    pub fn deinit(self: *WebSocketFrame, allocator: std.mem.Allocator) void {
        allocator.free(self.payload);
        self.* = undefined;
    }

    pub fn encodeAlloc(self: WebSocketFrame, allocator: std.mem.Allocator) std.mem.Allocator.Error![]const u8 {
        const redacted_payload = try Secrets.redactAlloc(allocator, self.payload);
        defer allocator.free(redacted_payload);
        const escaped_payload = try Json.escapeStringAlloc(allocator, redacted_payload);
        defer allocator.free(escaped_payload);

        return std.fmt.allocPrint(
            allocator,
            "{{\"kind\":\"{s}\",\"payload\":\"{s}\"}}",
            .{ @tagName(self.kind), escaped_payload },
        );
    }

    pub fn decodeAlloc(allocator: std.mem.Allocator, input: []const u8) (std.mem.Allocator.Error || error{InvalidWebSocketFrame})!WebSocketFrame {
        const Parsed = struct {
            kind: []const u8,
            payload: []const u8,
        };

        var parsed = std.json.parseFromSlice(Parsed, allocator, input, .{ .ignore_unknown_fields = true }) catch return error.InvalidWebSocketFrame;
        defer parsed.deinit();

        const kind = std.meta.stringToEnum(Kind, parsed.value.kind) orelse return error.InvalidWebSocketFrame;
        const payload = try Secrets.redactAlloc(allocator, parsed.value.payload);
        return .{ .kind = kind, .payload = payload };
    }
};

pub fn redactRequestAlloc(allocator: std.mem.Allocator, request: Request) ![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    const url = try Secrets.redactAlloc(allocator, request.url);
    defer allocator.free(url);

    try output.print(allocator, "{s} {s}", .{ request.method, url });
    for (request.headers) |header| {
        const value = if (isSensitiveHeader(header.name) or Secrets.containsSecret(header.value))
            Secrets.redacted
        else
            header.value;
        try output.print(allocator, "\n{s}: {s}", .{ header.name, value });
    }
    if (request.body.len != 0) {
        const body = if (Secrets.containsSecret(request.body) or containsCredentialBody(request.body))
            Secrets.redacted
        else
            request.body;
        try output.print(allocator, "\nbody: {s}", .{body});
    }

    return output.toOwnedSlice(allocator);
}

const SendRequest = struct { request: Request, options: SendOptions = .{} };
pub const SendEffect = fx.kernel.Effect(Response, ClientError, .{HttpClient}).Stateful(SendRequest);
pub fn send(request: Request, options: SendOptions) SendEffect {
    return SendEffect.init(.{ .request = request, .options = options }, struct {
        fn run(state: SendRequest, ctx: *SendEffect.Context) ClientError!Response {
            const operation = StdService.beginOperation(ctx, HttpClient.service_key, "http.send", "bounded HTTP request metadata omitted");
            const response = ctx.service(HttpClient).sendAlloc(ctx.allocator(), state.request, state.options) catch |err| {
                _ = StdService.completeOperation(ctx, operation, "failure", "bounded HTTP request failed; metadata omitted");
                return err;
            };
            _ = StdService.completeOperation(ctx, operation, "success", "bounded HTTP request completed; metadata omitted");
            return response;
        }
    }.run);
}

pub fn sendEffect(request: Request) SendEffect {
    return send(request, .{});
}

pub const SendClassifiedEffect = fx.kernel.Effect(External.Result(Response), error{}, .{HttpClient}).Stateful(SendRequest);
pub fn sendClassified(request: Request, options: SendOptions) SendClassifiedEffect {
    return SendClassifiedEffect.init(.{ .request = request, .options = options }, struct {
        fn run(state: SendRequest, ctx: *SendClassifiedEffect.Context) error{}!External.Result(Response) {
            const operation = StdService.beginOperation(ctx, HttpClient.service_key, "http.send", "classified bounded HTTP request");
            const response = ctx.service(HttpClient).sendAlloc(ctx.allocator(), state.request, state.options) catch |err| {
                const failure = External.Failure.fromError("http-client", "send", err);
                _ = StdService.completeOperation(ctx, operation, @tagName(failure.class), failure.detail);
                return .{ .failure = failure };
            };
            _ = StdService.completeOperation(ctx, operation, "success", "classified bounded HTTP request completed");
            return .{ .success = response };
        }
    }.run);
}

pub fn sendClassifiedEffect(request: Request) SendClassifiedEffect {
    return sendClassified(request, .{});
}

pub const MemoryServerApi = struct {
    pub const operations: []const []const u8 = &.{"MemoryHttpServer.handle"};
    server: *MemoryServer,
};
pub const MemoryServerService = fx.kernel.Service("zigeffect/std/MemoryHttpServer", MemoryServerApi);
pub fn memoryServerLayer(server: *MemoryServer) @TypeOf(fx.kernel.Layer.succeed(MemoryServerService, MemoryServerApi{ .server = server })) {
    return fx.kernel.Layer.succeed(MemoryServerService, .{ .server = server });
}
pub const HandleEffect = fx.kernel.Effect(Response, std.mem.Allocator.Error, .{MemoryServerService}).Stateful(Request);
pub fn handleEffect(request: Request) HandleEffect {
    return HandleEffect.init(request, struct {
        fn run(value: Request, ctx: *HandleEffect.Context) std.mem.Allocator.Error!Response {
            return ctx.service(MemoryServerService).server.handleAlloc(ctx.allocator(), value);
        }
    }.run);
}

pub const RouteHandler = struct {
    pub const operations: []const []const u8 = &.{"HttpRouter.handle"};
    pointer: *anyopaque,
    handle_fn: *const fn (*anyopaque, std.mem.Allocator, Request) anyerror!RouteResult,

    pub fn from(comptime T: type, value: *T) RouteHandler {
        return .{ .pointer = value, .handle_fn = struct {
            fn call(raw: *anyopaque, allocator: std.mem.Allocator, request: Request) anyerror!RouteResult {
                return (@as(*T, @ptrCast(@alignCast(raw)))).handleAlloc(allocator, request);
            }
        }.call };
    }
};
pub const RouterService = fx.kernel.Service("zigeffect/std/HttpRouter", RouteHandler);
pub fn routerLayer(handler: RouteHandler) @TypeOf(fx.kernel.Layer.succeed(RouterService, handler)) {
    return fx.kernel.Layer.succeed(RouterService, handler);
}
pub const HandleRouteEffect = fx.kernel.Effect(RouteResult, anyerror, .{RouterService}).Stateful(Request);
pub fn handleRouteEffect(request: Request) HandleRouteEffect {
    return HandleRouteEffect.init(request, struct {
        fn run(value: Request, ctx: *HandleRouteEffect.Context) anyerror!RouteResult {
            const service = ctx.service(RouterService);
            return service.handle_fn(service.pointer, ctx.allocator(), value);
        }
    }.run);
}

pub fn cloneResponseAlloc(allocator: std.mem.Allocator, response: Response) std.mem.Allocator.Error!Response {
    const headers = try cloneHeadersAlloc(allocator, response.headers);
    errdefer freeHeaders(allocator, headers);
    const body = try allocator.dupe(u8, response.body);
    errdefer allocator.free(body);
    return .{
        .status = response.status,
        .headers = headers,
        .body = body,
    };
}

fn jsonResponseAlloc(allocator: std.mem.Allocator, status: u16, body: []const u8) !Response {
    const headers = [_]Header{
        .{ .name = "content-type", .value = "application/json" },
    };
    return cloneResponseAlloc(allocator, .{
        .status = status,
        .headers = headers[0..],
        .body = body,
    });
}

fn routeErrorResultAlloc(
    allocator: std.mem.Allocator,
    status: u16,
    route_name: []const u8,
    error_code: []const u8,
    detail: []const u8,
    request: Request,
) !RouteResult {
    const redacted_detail = try Secrets.redactAlloc(allocator, detail);
    defer allocator.free(redacted_detail);

    const body = try Json.objectFromFieldsAlloc(allocator, &.{
        .{ .name = "schema", .value = "zigeffect.std.http-route-error.v1" },
        .{ .name = "status", .value = error_code },
        .{ .name = "detail", .value = redacted_detail },
    });
    defer allocator.free(body);

    const response = try jsonResponseAlloc(allocator, status, body);
    errdefer {
        var mutable_response = response;
        mutable_response.deinit(allocator);
    }
    const receipt_json = try routeReceiptJsonAlloc(allocator, route_name, error_code, status);
    errdefer allocator.free(receipt_json);
    const trace_json = try routeTraceJsonAlloc(allocator, route_name, error_code, status, request);
    errdefer allocator.free(trace_json);

    return .{
        .response = response,
        .receipt_json = receipt_json,
        .trace_json = trace_json,
    };
}

fn routeReceiptJsonAlloc(allocator: std.mem.Allocator, route_name: []const u8, status: []const u8, http_status: u16) ![]const u8 {
    const status_text = try std.fmt.allocPrint(allocator, "{d}", .{http_status});
    defer allocator.free(status_text);
    return Json.objectFromFieldsAlloc(allocator, &.{
        .{ .name = "schema", .value = "zigeffect.std.http-route-receipt.v1" },
        .{ .name = "route", .value = route_name },
        .{ .name = "status", .value = status },
        .{ .name = "http_status", .value = status_text },
    });
}

fn routeTraceJsonAlloc(allocator: std.mem.Allocator, route_name: []const u8, status: []const u8, http_status: u16, request: Request) ![]const u8 {
    const status_text = try std.fmt.allocPrint(allocator, "{d}", .{http_status});
    defer allocator.free(status_text);
    const request_text = try redactRequestAlloc(allocator, request);
    defer allocator.free(request_text);
    return Json.objectFromFieldsAlloc(allocator, &.{
        .{ .name = "schema", .value = "zigeffect.std.http-route-trace.v1" },
        .{ .name = "route", .value = route_name },
        .{ .name = "status", .value = status },
        .{ .name = "http_status", .value = status_text },
        .{ .name = "request", .value = request_text },
    });
}

fn routeNameAlloc(allocator: std.mem.Allocator, method: []const u8, path: []const u8) ![]const u8 {
    return std.fmt.allocPrint(allocator, "{s} {s}", .{ method, path });
}

fn RequestSchemaRouteName(comptime Endpoint: type) []const u8 {
    _ = Endpoint;
    return "typed-json-endpoint";
}

fn cloneHeadersAlloc(allocator: std.mem.Allocator, headers: []const Header) std.mem.Allocator.Error![]Header {
    const cloned = try allocator.alloc(Header, headers.len);
    errdefer allocator.free(cloned);

    var initialized: usize = 0;
    errdefer {
        for (cloned[0..initialized]) |header| {
            allocator.free(header.name);
            allocator.free(header.value);
        }
    }

    for (headers, 0..) |header, index| {
        const name = try allocator.dupe(u8, header.name);
        const value = allocator.dupe(u8, header.value) catch |err| {
            allocator.free(name);
            return err;
        };
        cloned[index] = .{
            .name = name,
            .value = value,
        };
        initialized += 1;
    }

    return cloned;
}

fn freeHeaders(allocator: std.mem.Allocator, headers: []const Header) void {
    for (headers) |header| {
        allocator.free(header.name);
        allocator.free(header.value);
    }
    allocator.free(headers);
}

fn parseHttpMethod(method: []const u8) ?std.http.Method {
    if (eqlInsensitive(method, "GET")) return .GET;
    if (eqlInsensitive(method, "HEAD")) return .HEAD;
    if (eqlInsensitive(method, "POST")) return .POST;
    if (eqlInsensitive(method, "PUT")) return .PUT;
    if (eqlInsensitive(method, "DELETE")) return .DELETE;
    if (eqlInsensitive(method, "CONNECT")) return .CONNECT;
    if (eqlInsensitive(method, "OPTIONS")) return .OPTIONS;
    if (eqlInsensitive(method, "TRACE")) return .TRACE;
    if (eqlInsensitive(method, "PATCH")) return .PATCH;
    return null;
}

fn requestPath(url: []const u8) []const u8 {
    var target = url;
    if (std.mem.indexOf(u8, url, "://")) |scheme_index| {
        const authority_start = scheme_index + 3;
        if (std.mem.indexOfScalarPos(u8, url, authority_start, '/')) |path_start| {
            target = url[path_start..];
        } else {
            target = "/";
        }
    }
    if (std.mem.indexOfScalar(u8, target, '?')) |query_index| {
        return target[0..query_index];
    }
    return target;
}

fn isSensitiveHeader(name: []const u8) bool {
    return eqlInsensitive(name, "authorization") or
        eqlInsensitive(name, "cookie") or
        eqlInsensitive(name, "x-api-key");
}

fn containsCredentialBody(body: []const u8) bool {
    return containsInsensitive(body, "\"client_secret\"") or
        containsInsensitive(body, "\"private_key\"") or
        containsInsensitive(body, "\"refresh_token\"") or
        containsInsensitive(body, "\"access_token\"") or
        containsInsensitive(body, "\"password\"") or
        containsInsensitive(body, "\"api_key\"");
}

fn containsInsensitive(haystack: []const u8, needle: []const u8) bool {
    if (needle.len == 0) return true;
    if (needle.len > haystack.len) return false;
    var index: usize = 0;
    while (index + needle.len <= haystack.len) : (index += 1) {
        if (eqlInsensitive(haystack[index .. index + needle.len], needle)) return true;
    }
    return false;
}

fn parseHttpDate(value: []const u8) ?u64 {
    if (value.len != 29) return null;
    if (value[3] != ',' or value[4] != ' ' or value[7] != ' ' or value[11] != ' ' or
        value[16] != ' ' or value[19] != ':' or value[22] != ':' or value[25] != ' ' or
        !std.mem.eql(u8, value[26..29], "GMT")) return null;

    const day = std.fmt.parseInt(u8, value[5..7], 10) catch return null;
    const month = parseHttpMonth(value[8..11]) orelse return null;
    const year = std.fmt.parseInt(u16, value[12..16], 10) catch return null;
    const hour = std.fmt.parseInt(u8, value[17..19], 10) catch return null;
    const minute = std.fmt.parseInt(u8, value[20..22], 10) catch return null;
    const second = std.fmt.parseInt(u8, value[23..25], 10) catch return null;
    if (year < 1970 or day == 0 or hour > 23 or minute > 59 or second > 59) return null;
    const days_in_month = monthDays(year, month);
    if (day > days_in_month) return null;

    var days: u64 = 0;
    var cursor_year: u16 = 1970;
    while (cursor_year < year) : (cursor_year += 1) {
        days += if (isLeapYear(cursor_year)) 366 else 365;
    }
    var cursor_month: u8 = 1;
    while (cursor_month < month) : (cursor_month += 1) {
        days += monthDays(year, cursor_month);
    }
    days += day - 1;
    return days * std.time.s_per_day +
        @as(u64, hour) * std.time.s_per_hour +
        @as(u64, minute) * std.time.s_per_min +
        second;
}

fn parseHttpMonth(value: []const u8) ?u8 {
    const names = [_][]const u8{ "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" };
    for (names, 1..) |name, month| {
        if (std.mem.eql(u8, value, name)) return @intCast(month);
    }
    return null;
}

fn monthDays(year: u16, month: u8) u8 {
    return switch (month) {
        1, 3, 5, 7, 8, 10, 12 => 31,
        4, 6, 9, 11 => 30,
        2 => if (isLeapYear(year)) 29 else 28,
        else => 0,
    };
}

fn isLeapYear(year: u16) bool {
    return (year % 4 == 0 and year % 100 != 0) or year % 400 == 0;
}

fn eqlInsensitive(left: []const u8, right: []const u8) bool {
    if (left.len != right.len) return false;
    for (left, right) |left_byte, right_byte| {
        if (std.ascii.toLower(left_byte) != std.ascii.toLower(right_byte)) return false;
    }
    return true;
}

test "Http fake client returns configured responses" {
    const client = FakeClient.init(.{ .status = 201, .body = "created" });
    const response = client.send(.{ .method = "POST", .url = "http://localhost/projects" });

    try std.testing.expectEqual(@as(u16, 201), response.status);
    try std.testing.expectEqualStrings("created", response.body);
}

test "Http responses own headers and lookup names case-insensitively" {
    var client = FakeClient.init(.{
        .status = 429,
        .headers = &.{
            .{ .name = "Retry-After", .value = "12" },
            .{ .name = "X-Request-Id", .value = "request-1" },
        },
        .body = "limited",
    });
    var response = try client.sendAlloc(std.testing.allocator, .{ .method = "GET", .url = "https://example.test" });
    defer response.deinit(std.testing.allocator);

    try std.testing.expectEqualStrings("12", response.header("retry-after").?);
    try std.testing.expectEqualStrings("request-1", response.header("x-REQUEST-id").?);
    try std.testing.expect(response.header("missing") == null);
}

test "Http live response heads are cloned into owned headers" {
    var raw_head = [_]u8{0} ** 256;
    const wire = "HTTP/1.1 429 Too Many Requests\r\nRetry-After: 3\r\nX-Request-Id: live-1\r\nContent-Length: 0\r\n\r\n";
    @memcpy(raw_head[0..wire.len], wire);
    const head = try std.http.Client.Response.Head.parse(raw_head[0..wire.len]);
    const headers = try cloneLiveHeadersAlloc(std.testing.allocator, head);
    defer freeHeaders(std.testing.allocator, headers);

    @memset(raw_head[0..wire.len], 0);
    const response = Response{ .status = 429, .headers = headers };
    try std.testing.expectEqualStrings("3", response.header("retry-after").?);
    try std.testing.expectEqualStrings("live-1", response.header("X-REQUEST-ID").?);
}

test "Http scripted client applies typed body limit cancellation and timeout failures" {
    var scripted = ScriptedClient.init(std.testing.allocator);
    defer scripted.deinit();
    try scripted.addResponse(.{ .status = 200, .body = "too-large" });
    try std.testing.expectError(
        error.ResponseBodyTooLarge,
        scripted.sendAllocWithOptions(
            std.testing.allocator,
            .{ .method = "GET", .url = "https://example.test" },
            .{ .response_body_limit = 3 },
        ),
    );

    var cancelled = true;
    try std.testing.expectError(
        error.RequestCancelled,
        scripted.sendAllocWithOptions(
            std.testing.allocator,
            .{ .method = "GET", .url = "https://example.test" },
            .{ .cancellation = Cancellation.fromBool(&cancelled) },
        ),
    );

    try scripted.addError(error.ConnectTimeout);
    cancelled = false;
    try std.testing.expectError(
        error.ConnectTimeout,
        scripted.sendAllocWithOptions(
            std.testing.allocator,
            .{ .method = "GET", .url = "https://example.test" },
            .{ .connect_timeout_millis = 5 },
        ),
    );
    try scripted.addError(error.RequestTimeout);
    try std.testing.expectError(
        error.RequestTimeout,
        scripted.sendAllocWithOptions(
            std.testing.allocator,
            .{ .method = "GET", .url = "https://example.test" },
            .{ .request_timeout_millis = 5 },
        ),
    );
}

test "Http retry-after parses integer seconds and IMF-fixdate" {
    const seconds = Response{
        .status = 429,
        .headers = &.{.{ .name = "retry-after", .value = "7" }},
    };
    try std.testing.expectEqual(@as(?u64, 7_000), seconds.retryAfterMillis(0));

    const date = Response{
        .status = 503,
        .headers = &.{.{ .name = "Retry-After", .value = "Wed, 21 Oct 2015 07:28:00 GMT" }},
    };
    try std.testing.expectEqual(
        @as(?u64, 60_000),
        date.retryAfterMillis(1_445_412_420),
    );
}

test "Http client interface is shared by fake and scripted transports" {
    var fake = FakeClient.init(.{ .status = 204 });
    var scripted = ScriptedClient.init(std.testing.allocator);
    defer scripted.deinit();
    try scripted.addResponse(.{ .status = 202 });

    const clients = [_]Client{ fake.client(), scripted.client() };
    for (clients, 0..) |client, index| {
        var response = try client.sendAlloc(
            std.testing.allocator,
            .{ .method = "GET", .url = "https://example.test" },
            .{},
        );
        defer response.deinit(std.testing.allocator);
        try std.testing.expectEqual(if (index == 0) @as(u16, 204) else @as(u16, 202), response.status);
    }
}

test "Http redacts authorization headers and secret URLs" {
    const headers = [_]Header{
        .{ .name = "authorization", .value = "Bearer token" },
    };
    const display = try redactRequestAlloc(std.testing.allocator, .{
        .method = "GET",
        .url = "https://token=abc123@example.com",
        .headers = headers[0..],
    });
    defer std.testing.allocator.free(display);

    try std.testing.expect(std.mem.indexOf(u8, display, "token=abc123") == null);
    try std.testing.expect(std.mem.indexOf(u8, display, "Bearer token") == null);
    try std.testing.expect(std.mem.indexOf(u8, display, "[REDACTED]") != null);
}

test "Http redacts OAuth credential request bodies" {
    const display = try redactRequestAlloc(std.testing.allocator, .{
        .method = "POST",
        .url = "https://oauth2.googleapis.com/token",
        .body = "{\"client_email\":\"service@example.test\",\"private_key\":\"raw-key\"}",
    });
    defer std.testing.allocator.free(display);

    try std.testing.expect(std.mem.indexOf(u8, display, "raw-key") == null);
    try std.testing.expect(std.mem.indexOf(u8, display, "[REDACTED]") != null);
}

test "Http redacts database password and API key request bodies" {
    const password_display = try redactRequestAlloc(std.testing.allocator, .{
        .method = "POST",
        .url = "https://cockroachlabs.cloud/api/v1/sql-users",
        .body = "{\"name\":\"app\",\"password\":\"dummy-database-password\"}",
    });
    defer std.testing.allocator.free(password_display);
    const key_display = try redactRequestAlloc(std.testing.allocator, .{
        .method = "POST",
        .url = "https://example.test/credentials",
        .body = "{\"api_key\":\"dummy-api-key\"}",
    });
    defer std.testing.allocator.free(key_display);

    try std.testing.expect(std.mem.indexOf(u8, password_display, "dummy-database-password") == null);
    try std.testing.expect(std.mem.indexOf(u8, key_display, "dummy-api-key") == null);
}

test "Http sendEffect uses client services and records redacted causal facts" {
    var client = FakeClient.init(.{ .status = 202, .body = "accepted" });
    const main_layer = clientLayer(client.client());
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const zstd = @import("../root.zig");
    var runtime = try zstd.ManagedRuntime(@TypeOf(main_layer)).make(std.testing.allocator, std.testing.io, tmp.dir, main_layer, .{});
    defer runtime.deinit();

    var response = try runtime.run(sendEffect(.{
        .method = "POST",
        .url = "https://example.test/api?token=abc123",
        .headers = &.{.{ .name = "authorization", .value = "Bearer token" }},
        .body = "{\"name\":\"local\"}",
    }));
    defer response.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(u16, 202), response.status);
    try std.testing.expectEqualStrings("accepted", response.body);

    var snapshot = try runtime.inspect(std.testing.allocator, .{ .max_recent_events = 64 });
    defer snapshot.deinit();
    var found = false;
    for (snapshot.causal.recent_events) |event| {
        if (std.mem.eql(u8, event.label, "http.send") and std.mem.eql(u8, event.status, "success")) found = true;
        try std.testing.expect(std.mem.indexOf(u8, event.redacted_detail, "abc123") == null);
    }
    try std.testing.expect(found);
    try runtime.shutdown();
}

test "Http LocalClient exposes live adapter contract without network access" {
    var local = LocalClient.init(std.testing.allocator, std.testing.io);
    defer local.deinit();

    try std.testing.expect(local.response_body_limit == 1024 * 1024);
    try std.testing.expect(@hasDecl(LocalClient, "sendAlloc"));
    try std.testing.expect(@hasDecl(LocalClient, "client"));
}

test "Http adapters publish truthful capability maturity" {
    try FakeClient.capability.validate();
    try LocalClient.capability.validate();
    try MemoryServer.capability.validate();
    try std.testing.expectEqual(Capability.Maturity.fake, MemoryServer.capability.maturity);
    try std.testing.expectEqual(
        Capability.Match.insufficient_maturity,
        Capability.match(MemoryServer.capability, .{
            .kind = .http_server,
            .minimum_maturity = .production_candidate,
            .requires_live_conformance = true,
        }),
    );
}

test "Http classified clients return backend neutral recovery failures" {
    var local = LocalClient.init(std.testing.allocator, std.testing.io);
    defer local.deinit();
    const result = local.sendClassifiedAlloc(std.testing.allocator, .{
        .method = "NOT-A-METHOD",
        .url = "http://localhost/",
    });
    switch (result) {
        .success => return error.TestExpectedFailure,
        .failure => |failure| {
            try std.testing.expectEqual(@import("../external/root.zig").Class.unsupported, failure.class);
            try std.testing.expect(!failure.retryable());
        },
    }
}

test "Http classified effect keeps failures in the success channel" {
    var client = FakeClient.init(.{ .status = 204 });
    const zstd = @import("../root.zig");
    const main_layer = clientLayer(client.client());
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    var runtime = try zstd.ManagedRuntime(@TypeOf(main_layer)).make(std.testing.allocator, std.testing.io, tmp.dir, main_layer, .{});
    defer runtime.deinit();
    var result = try runtime.run(sendClassifiedEffect(.{
        .method = "GET",
        .url = "https://example.invalid/health",
    }));
    switch (result) {
        .success => |*response| response.deinit(std.testing.allocator),
        .failure => return error.TestUnexpectedFailure,
    }
    try runtime.shutdown();
}

test "Http memory server routes requests through effect-native handler" {
    const zstd = @import("../root.zig");

    var server = MemoryServer.init(std.testing.allocator);
    defer server.deinit();
    try server.addRoute("GET", "/health", .{ .status = 200, .body = "ok" });

    const main_layer = memoryServerLayer(&server);
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    var runtime = try zstd.ManagedRuntime(@TypeOf(main_layer)).make(std.testing.allocator, std.testing.io, tmp.dir, main_layer, .{});
    defer runtime.deinit();

    var response = try runtime.run(handleEffect(.{ .method = "GET", .url = "/health" }));
    defer response.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(u16, 200), response.status);
    try std.testing.expectEqualStrings("ok", response.body);

    try std.testing.expect(runtime.graphSummary().records != 0);
    try runtime.shutdown();
}

test "Http WebSocketFrame encodes decodes and redacts payloads" {
    const frame = WebSocketFrame{
        .kind = .text,
        .payload = "{\"authorization\":\"Bearer token=abc123\"}",
    };

    const encoded = try frame.encodeAlloc(std.testing.allocator);
    defer std.testing.allocator.free(encoded);
    try std.testing.expect(std.mem.indexOf(u8, encoded, "abc123") == null);
    try std.testing.expect(std.mem.indexOf(u8, encoded, "\"kind\":\"text\"") != null);

    var decoded = try WebSocketFrame.decodeAlloc(std.testing.allocator, encoded);
    defer decoded.deinit(std.testing.allocator);
    try std.testing.expectEqual(WebSocketFrame.Kind.text, decoded.kind);
    try std.testing.expectEqualStrings("[REDACTED]", decoded.payload);
}

const ProjectCreate = struct {
    name: []const u8,
    limit: i64,
};

const ProjectCreated = struct {
    id: []const u8,
    name: []const u8,
};

fn createProjectHandler(allocator: std.mem.Allocator, input: ProjectCreate) !ProjectCreated {
    _ = allocator;
    return .{
        .id = "project-local",
        .name = input.name,
    };
}

test "Http typed router validates JSON and returns response receipt and trace" {
    const endpoint = jsonEndpoint(
        "POST",
        "/projects",
        Schema.derive(ProjectCreate, .{
            .name = Schema.string().nonEmpty(),
            .limit = Schema.integer().min(1).max(10),
        }),
        Schema.derive(ProjectCreated, .{
            .id = Schema.string().nonEmpty(),
            .name = Schema.string().nonEmpty(),
        }),
        createProjectHandler,
    );
    var local_router = router(.{endpoint});

    var result = try local_router.handleAlloc(std.testing.allocator, .{
        .method = "POST",
        .url = "http://localhost/projects",
        .body = "{\"name\":\"local\",\"limit\":2}",
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(u16, 200), result.response.status);
    try std.testing.expect(std.mem.indexOf(u8, result.response.body, "\"id\":\"project-local\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, result.receipt_json, "\"status\":\"success\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, result.trace_json, "\"route\":\"POST /projects\"") != null);
}

test "Http response cloning releases partial headers on every allocation failure" {
    const Harness = struct {
        fn run(allocator: std.mem.Allocator) !void {
            var response = try cloneResponseAlloc(allocator, .{
                .status = 200,
                .headers = &.{
                    .{ .name = "content-type", .value = "application/json" },
                    .{ .name = "x-request-id", .value = "local" },
                },
                .body = "{}",
            });
            defer response.deinit(allocator);
        }
    };
    try std.testing.checkAllAllocationFailures(std.testing.allocator, Harness.run, .{});
}

test "Http typed router returns redacted validation failure" {
    const endpoint = jsonEndpoint(
        "POST",
        "/projects",
        Schema.derive(ProjectCreate, .{
            .name = Schema.string().nonEmpty(),
            .limit = Schema.integer().min(1).max(10),
        }),
        Schema.derive(ProjectCreated, .{
            .id = Schema.string().nonEmpty(),
            .name = Schema.string().nonEmpty(),
        }),
        createProjectHandler,
    );
    var local_router = router(.{endpoint});

    var result = try local_router.handleAlloc(std.testing.allocator, .{
        .method = "POST",
        .url = "/projects",
        .body = "{\"name\":\"token=abc123\",\"limit\":99}",
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(u16, 400), result.response.status);
    try std.testing.expect(std.mem.indexOf(u8, result.response.body, "$.limit") != null);
    try std.testing.expect(std.mem.indexOf(u8, result.response.body, "abc123") == null);
}

test "Http typed router returns deterministic not found responses" {
    var local_router = router(.{});
    var result = try local_router.handleAlloc(std.testing.allocator, .{
        .method = "GET",
        .url = "/missing",
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(u16, 404), result.response.status);
    try std.testing.expect(std.mem.indexOf(u8, result.response.body, "route_not_found") != null);
}

test "Http typed router effect records causal facts" {
    const zstd = @import("../root.zig");
    const endpoint = jsonEndpoint(
        "POST",
        "/projects",
        Schema.derive(ProjectCreate, .{
            .name = Schema.string().nonEmpty(),
            .limit = Schema.integer().min(1).max(10),
        }),
        Schema.derive(ProjectCreated, .{
            .id = Schema.string().nonEmpty(),
            .name = Schema.string().nonEmpty(),
        }),
        createProjectHandler,
    );
    var local_router = router(.{endpoint});
    const main_layer = routerLayer(RouteHandler.from(@TypeOf(local_router), &local_router));
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    var runtime = try zstd.ManagedRuntime(@TypeOf(main_layer)).make(std.testing.allocator, std.testing.io, tmp.dir, main_layer, .{});
    defer runtime.deinit();

    var result = try runtime.run(handleRouteEffect(.{
        .method = "POST",
        .url = "/projects",
        .body = "{\"name\":\"local\",\"limit\":1}",
    }));
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(u16, 200), result.response.status);
    try std.testing.expect(runtime.graphSummary().records != 0);
    try runtime.shutdown();
}

test "Http request and response body streams own bounded chunked data" {
    var request_bytes = [_]u8{ 'r', 'e', 'q', 'u', 'e', 's', 't' };
    var response_bytes = [_]u8{ 'r', 'e', 's', 'p', 'o', 'n', 's', 'e' };
    var request_stream = try requestBodyStreamAlloc(std.testing.allocator, .{ .method = "POST", .url = "/", .body = &request_bytes });
    defer request_stream.deinit();
    var response_stream = try responseBodyStreamAlloc(std.testing.allocator, .{ .status = 200, .body = &response_bytes });
    defer response_stream.deinit();
    @memset(&request_bytes, 0);
    @memset(&response_bytes, 0);

    var env = Stream.EmptyEnv{};
    var context = fx.Context(Stream.EmptyEnv).init(std.testing.allocator, &env, null);
    const request = try request_stream.runCollectAlloc(&context, std.testing.allocator, 2);
    defer std.testing.allocator.free(request);
    const response = try response_stream.runCollectAlloc(&context, std.testing.allocator, 3);
    defer std.testing.allocator.free(response);
    try std.testing.expectEqualStrings("request", request);
    try std.testing.expectEqualStrings("response", response);
}
