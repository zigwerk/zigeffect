const std = @import("std");
const Json = @import("../json/root.zig");
const Secrets = @import("../secrets/root.zig");
const StdService = @import("../service/root.zig");
const fx = @import("zigeffect");

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

pub const FakeClient = struct {
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
};

pub const LocalClient = struct {
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
};

pub const MemoryServer = struct {
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

pub fn handleEffect(comptime EffectEnv: type, request: Request) HandleEffect(EffectEnv) {
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
        cloned[index] = .{
            .name = try allocator.dupe(u8, header.name),
            .value = try allocator.dupe(u8, header.value),
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
