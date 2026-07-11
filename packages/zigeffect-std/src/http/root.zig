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

pub fn requestBodyStreamAlloc(allocator: std.mem.Allocator, request: Request) !fx.EffectStream(u8, anyerror, Stream.EmptyEnv) { return Stream.ownedBytesAlloc(allocator, request.body); }
pub fn responseBodyStreamAlloc(allocator: std.mem.Allocator, response: Response) !fx.EffectStream(u8, anyerror, Stream.EmptyEnv) { return Stream.ownedBytesAlloc(allocator, response.body); }

pub const Response = struct {
    status: u16,
    headers: []const Header = &.{},
    body: []const u8 = "",

    pub fn deinit(self: *Response, allocator: std.mem.Allocator) void {
        freeHeaders(allocator, self.headers);
        allocator.free(self.body);
        self.* = undefined;
    }
};

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

    pub fn sendClassifiedAlloc(self: *FakeClient, allocator: std.mem.Allocator, request: Request) External.Result(Response) {
        const response = self.sendAlloc(allocator, request) catch |err| {
            return .{ .failure = External.Failure.fromError("fake-http", "send", err) };
        };
        return .{ .success = response };
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

    client: std.http.Client,
    response_body_limit: usize = 1024 * 1024,

    pub fn init(allocator: std.mem.Allocator, io: std.Io) LocalClient {
        return .{
            .client = .{
                .allocator = allocator,
                .io = io,
            },
        };
    }

    pub fn deinit(self: *LocalClient) void {
        self.client.deinit();
    }

    pub fn sendAlloc(self: *LocalClient, allocator: std.mem.Allocator, request: Request) anyerror!Response {
        const method = parseHttpMethod(request.method) orelse return error.UnsupportedHttpMethod;
        const extra_headers = try allocator.alloc(std.http.Header, request.headers.len);
        defer allocator.free(extra_headers);
        for (request.headers, 0..) |header, index| {
            extra_headers[index] = .{ .name = header.name, .value = header.value };
        }

        const response_buffer = try allocator.alloc(u8, self.response_body_limit);
        defer allocator.free(response_buffer);
        var response_writer = std.Io.Writer.fixed(response_buffer);

        const result = try self.client.fetch(.{
            .location = .{ .url = request.url },
            .method = method,
            .payload = if (request.body.len == 0) null else request.body,
            .extra_headers = extra_headers,
            .response_writer = &response_writer,
            .keep_alive = false,
        });

        const headers = try allocator.alloc(Header, 0);
        errdefer allocator.free(headers);
        const body = try allocator.dupe(u8, response_writer.buffered());
        errdefer allocator.free(body);

        return .{
            .status = @intCast(@intFromEnum(result.status)),
            .headers = headers,
            .body = body,
        };
    }

    pub fn sendClassifiedAlloc(self: *LocalClient, allocator: std.mem.Allocator, request: Request) External.Result(Response) {
        const response = self.sendAlloc(allocator, request) catch |err| {
            return .{ .failure = External.Failure.fromError("http", "send", err) };
        };
        return .{ .success = response };
    }
};

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
        const body = if (Secrets.containsSecret(request.body)) Secrets.redacted else request.body;
        try output.print(allocator, "\nbody: {s}", .{body});
    }

    return output.toOwnedSlice(allocator);
}

pub fn SendEffect(comptime EffectEnv: type, comptime Client: type) type {
    return struct {
        pub const SuccessType = Response;
        pub const FailureType = anyerror;
        pub const EnvType = EffectEnv;
        pub const RequiredServices = .{Client};

        request: Request,

        pub fn requiredServices(allocator: std.mem.Allocator) std.mem.Allocator.Error!fx.ServiceSet {
            return fx.ServiceSet.fromTypes(allocator, RequiredServices);
        }

        pub fn run(self: @This(), ctx: *fx.Context(EffectEnv)) FailureType!Response {
            const client = ctx.service(Client);
            const detail = redactRequestAlloc(ctx.allocator, self.request) catch |err| {
                _ = StdService.recordOperation(ctx, Client, "http.send", "failure", @errorName(err));
                return err;
            };
            defer ctx.allocator.free(detail);

            const response = client.sendAlloc(ctx.allocator, self.request) catch |err| {
                _ = StdService.recordOperation(ctx, Client, "http.send", "failure", detail);
                return err;
            };
            _ = StdService.recordOperation(ctx, Client, "http.send", "success", detail);
            return response;
        }
    };
}

pub fn SendClassifiedEffect(comptime EffectEnv: type, comptime Client: type) type {
    return struct {
        pub const SuccessType = External.Result(Response);
        pub const FailureType = error{};
        pub const EnvType = EffectEnv;
        pub const RequiredServices = .{Client};

        request: Request,

        pub fn requiredServices(allocator: std.mem.Allocator) std.mem.Allocator.Error!fx.ServiceSet {
            return fx.ServiceSet.fromTypes(allocator, RequiredServices);
        }

        pub fn run(self: @This(), ctx: *fx.Context(EffectEnv)) FailureType!SuccessType {
            const client = ctx.service(Client);
            const result = client.sendClassifiedAlloc(ctx.allocator, self.request);
            switch (result) {
                .success => {
                    _ = StdService.recordOperation(ctx, Client, "http.send", "success", "classified");
                },
                .failure => |failure| {
                    _ = StdService.recordOperation(ctx, Client, "http.send", @tagName(failure.class), failure.detail);
                },
            }
            return result;
        }
    };
}

pub fn HandleEffect(comptime EffectEnv: type) type {
    return struct {
        pub const SuccessType = Response;
        pub const FailureType = std.mem.Allocator.Error;
        pub const EnvType = EffectEnv;
        pub const RequiredServices = .{MemoryServer};

        request: Request,

        pub fn requiredServices(allocator: std.mem.Allocator) std.mem.Allocator.Error!fx.ServiceSet {
            return fx.ServiceSet.fromTypes(allocator, RequiredServices);
        }

        pub fn run(self: @This(), ctx: *fx.Context(EffectEnv)) FailureType!Response {
            const server = ctx.service(MemoryServer);
            const detail = redactRequestAlloc(ctx.allocator, self.request) catch |err| {
                _ = StdService.recordOperation(ctx, MemoryServer, "http.handle", "failure", @errorName(err));
                return err;
            };
            defer ctx.allocator.free(detail);

            const response = server.handleAlloc(ctx.allocator, self.request) catch |err| {
                _ = StdService.recordOperation(ctx, MemoryServer, "http.handle", "failure", detail);
                return err;
            };
            _ = StdService.recordOperation(ctx, MemoryServer, "http.handle", if (response.status < 400) "success" else "not_found", detail);
            return response;
        }
    };
}

pub fn sendEffect(comptime EffectEnv: type, comptime Client: type, request: Request) SendEffect(EffectEnv, Client) {
    return .{ .request = request };
}

pub fn sendClassifiedEffect(comptime EffectEnv: type, comptime Client: type, request: Request) SendClassifiedEffect(EffectEnv, Client) {
    return .{ .request = request };
}

pub fn handleEffect(comptime EffectEnv: type, request: Request) HandleEffect(EffectEnv) {
    return .{ .request = request };
}

pub fn HandleRouteEffect(comptime EffectEnv: type, comptime RouterType: type) type {
    return struct {
        pub const SuccessType = RouteResult;
        pub const FailureType = anyerror;
        pub const EnvType = EffectEnv;
        pub const RequiredServices = .{RouterType};

        request: Request,

        pub fn requiredServices(allocator: std.mem.Allocator) std.mem.Allocator.Error!fx.ServiceSet {
            return fx.ServiceSet.fromTypes(allocator, RequiredServices);
        }

        pub fn run(self: @This(), ctx: *fx.Context(EffectEnv)) FailureType!RouteResult {
            const local_router = ctx.service(RouterType);
            const detail = redactRequestAlloc(ctx.allocator, self.request) catch |err| {
                _ = StdService.recordOperation(ctx, RouterType, "http.route", "failure", @errorName(err));
                return err;
            };
            defer ctx.allocator.free(detail);

            const result = local_router.handleAlloc(ctx.allocator, self.request) catch |err| {
                _ = StdService.recordOperation(ctx, RouterType, "http.route", "failure", detail);
                return err;
            };
            _ = StdService.recordOperation(ctx, RouterType, "http.route", if (result.response.status < 400) "success" else "failure", detail);
            return result;
        }
    };
}

pub fn handleRouteEffect(comptime EffectEnv: type, comptime RouterType: type, request: Request) HandleRouteEffect(EffectEnv, RouterType) {
    return .{ .request = request };
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

test "Http sendEffect uses client services and records redacted causal facts" {
    const zstd = @import("../root.zig");

    var client = FakeClient.init(.{ .status = 202, .body = "accepted" });
    var provider = zstd.Service.Provider(.{FakeClient}).init(.{&client});
    var store = zstd.fx.CausalStore.init(std.testing.allocator);
    defer store.deinit();

    var runtime = zstd.fx.Runtime(@TypeOf(provider)).init(std.testing.allocator, &provider)
        .provides(.{FakeClient})
        .withCausalStore(&store);

    var response = try runtime.run(sendEffect(@TypeOf(provider), FakeClient, .{
        .method = "POST",
        .url = "https://example.test/api?token=abc123",
        .headers = &.{.{ .name = "authorization", .value = "Bearer token" }},
        .body = "{\"name\":\"local\"}",
    }));
    defer response.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(u16, 202), response.status);
    try std.testing.expectEqualStrings("accepted", response.body);

    var snapshot = try store.snapshot(std.testing.allocator);
    defer snapshot.deinit();
    const event_index = zstd.Service.findOperation(snapshot, FakeClient, "http.send", "success");
    try std.testing.expect(event_index != null);
    try std.testing.expect(std.mem.indexOf(u8, snapshot.events[event_index.?].redacted_detail, "abc123") == null);
}

test "Http LocalClient exposes live adapter contract without network access" {
    var local = LocalClient.init(std.testing.allocator, std.testing.io);
    defer local.deinit();

    try std.testing.expect(local.response_body_limit == 1024 * 1024);
    try std.testing.expect(@hasDecl(LocalClient, "sendAlloc"));
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
    var services = zstd.Service.Provider(.{FakeClient}).init(.{&client});
    var runtime = zstd.fx.Runtime(@TypeOf(services)).init(std.testing.allocator, &services).provides(.{FakeClient});
    var result = try runtime.run(sendClassifiedEffect(@TypeOf(services), FakeClient, .{
        .method = "GET",
        .url = "https://example.invalid/health",
    }));
    switch (result) {
        .success => |*response| response.deinit(std.testing.allocator),
        .failure => return error.TestUnexpectedFailure,
    }
}

test "Http memory server routes requests through effect-native handler" {
    const zstd = @import("../root.zig");

    var server = MemoryServer.init(std.testing.allocator);
    defer server.deinit();
    try server.addRoute("GET", "/health", .{ .status = 200, .body = "ok" });

    var provider = zstd.Service.Provider(.{MemoryServer}).init(.{&server});
    var store = zstd.fx.CausalStore.init(std.testing.allocator);
    defer store.deinit();

    var runtime = zstd.fx.Runtime(@TypeOf(provider)).init(std.testing.allocator, &provider)
        .provides(.{MemoryServer})
        .withCausalStore(&store);

    var response = try runtime.run(handleEffect(@TypeOf(provider), .{ .method = "GET", .url = "/health" }));
    defer response.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(u16, 200), response.status);
    try std.testing.expectEqualStrings("ok", response.body);

    var snapshot = try store.snapshot(std.testing.allocator);
    defer snapshot.deinit();
    try std.testing.expect(zstd.Service.hasOperation(snapshot, MemoryServer, "http.handle", "success"));
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
    const RouterType = @TypeOf(local_router);

    var provider = zstd.Service.Provider(.{RouterType}).init(.{&local_router});
    var store = zstd.fx.CausalStore.init(std.testing.allocator);
    defer store.deinit();
    var runtime = zstd.fx.Runtime(@TypeOf(provider)).init(std.testing.allocator, &provider)
        .provides(.{RouterType})
        .withCausalStore(&store);

    var result = try runtime.run(handleRouteEffect(@TypeOf(provider), RouterType, .{
        .method = "POST",
        .url = "/projects",
        .body = "{\"name\":\"local\",\"limit\":1}",
    }));
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(u16, 200), result.response.status);
    var snapshot = try store.snapshot(std.testing.allocator);
    defer snapshot.deinit();
    try std.testing.expect(zstd.Service.hasOperation(snapshot, RouterType, "http.route", "success"));
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
