const std = @import("std");
const zstd = @import("zigeffect_std");
const quic = @import("quic");

pub const Quic = quic;
pub const Http = zstd.Http;
pub const Service = zstd.Service;
pub const fx = zstd.fx;
const event_loop = quic.event_loop;
const qpack = quic.qpack;

pub const ClientConfig = struct {
    address: []const u8 = "127.0.0.1",
    port: u16 = 4433,
    server_name: []const u8 = "localhost",
    ca_cert_path: ?[]const u8 = null,
    skip_cert_verify: bool = false,
    response_body_limit: usize = 1024 * 1024,
};
pub const ClientConfigService = zstd.fx.kernel.Service("zigeffect/quic/ClientConfig", ClientConfig);
pub const ClientApi = struct {
    pub const operations: []const []const u8 = &.{"QuicHttpClient.send"};
    client: QuicHttpClient,
};
pub const ClientService = zstd.fx.kernel.Service("zigeffect/quic/Client", ClientApi);

pub fn clientConfigLayer(config: ClientConfig) @TypeOf(zstd.fx.kernel.Layer.succeed(ClientConfigService, config)) {
    return zstd.fx.kernel.Layer.succeed(ClientConfigService, config);
}

const ClientFactory = struct {
    fn make(ctx: *zstd.fx.kernel.ContextView(.{ClientConfigService})) ClientApi {
        return .{ .client = QuicHttpClient.init(ctx.service(ClientConfigService).*) };
    }
};

pub fn clientLayer() @TypeOf(zstd.fx.kernel.Layer.sync(
    ClientService,
    .{ClientConfigService},
    ClientFactory.make,
)) {
    return zstd.fx.kernel.Layer.sync(ClientService, .{ClientConfigService}, ClientFactory.make);
}

const HttpClientFactory = struct {
    fn make(ctx: *zstd.fx.kernel.ContextView(.{ClientService})) zstd.Http.Client {
        return ctx.service(ClientService).client.asHttpClient();
    }
};

pub fn httpClientLayer() @TypeOf(zstd.fx.kernel.Layer.sync(
    zstd.Http.HttpClient,
    .{ClientService},
    HttpClientFactory.make,
)) {
    return zstd.fx.kernel.Layer.sync(zstd.Http.HttpClient, .{ClientService}, HttpClientFactory.make);
}

pub fn configuredClientLayer(config: ClientConfig) @TypeOf(
    httpClientLayer().provideMerge(clientLayer().provideMerge(clientConfigLayer(config))),
) {
    return httpClientLayer().provideMerge(clientLayer().provideMerge(clientConfigLayer(config)));
}

pub const FakeQuicHttpClient = struct {
    pub const capability = zstd.Capability.Descriptor{
        .id = "zigeffect-quic.fake-http-client",
        .kind = .http_client,
        .maturity = .fake,
        .package = "zigeffect-quic",
        .version = "0.1.0",
        .features = &.{ "http3", "quic" },
        .limitations = &.{"returns a configured response without QUIC network IO"},
    };

    response: zstd.Http.Response,
    allocator: ?std.mem.Allocator = null,

    pub fn init(response: zstd.Http.Response) FakeQuicHttpClient {
        return .{ .response = response };
    }

    pub fn initOwned(allocator: std.mem.Allocator, response: zstd.Http.Response) std.mem.Allocator.Error!FakeQuicHttpClient {
        return .{
            .response = try zstd.Http.cloneResponseAlloc(allocator, response),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *FakeQuicHttpClient) void {
        const allocator = self.allocator orelse return;
        self.response.deinit(allocator);
        self.* = undefined;
    }

    pub fn sendAlloc(self: *FakeQuicHttpClient, allocator: std.mem.Allocator, request: zstd.Http.Request) std.mem.Allocator.Error!zstd.Http.Response {
        _ = request;
        return zstd.Http.cloneResponseAlloc(allocator, self.response);
    }

    pub fn sendAllocWithOptions(self: *FakeQuicHttpClient, allocator: std.mem.Allocator, request: zstd.Http.Request, options: zstd.Http.SendOptions) zstd.Http.ClientError!zstd.Http.Response {
        try options.checkActive();
        if (self.response.body.len > options.response_body_limit) return error.ResponseBodyTooLarge;
        return self.sendAlloc(allocator, request);
    }

    pub fn asHttpClient(self: *FakeQuicHttpClient) zstd.Http.Client {
        return zstd.Http.Client.from(FakeQuicHttpClient, self);
    }
};

pub const QuicHttpClient = struct {
    pub const capability = zstd.Capability.Descriptor{
        .id = "zigeffect-quic.http3-client",
        .kind = .http_client,
        .maturity = .local_development,
        .package = "zigeffect-quic",
        .version = "0.1.0",
        .features = &.{ "http3", "quic", "tls" },
        .side_effects = .real,
        .limitations = &.{"has no live release conformance recovery or bounded-load receipt"},
    };

    config: ClientConfig = .{},

    pub fn init(config: ClientConfig) QuicHttpClient {
        return .{ .config = config };
    }

    pub fn sendAlloc(self: *QuicHttpClient, allocator: std.mem.Allocator, request: zstd.Http.Request) anyerror!zstd.Http.Response {
        var handler = H3RequestHandler.init(allocator, request, self.config);
        defer handler.deinit();

        var client = try event_loop.Client(H3RequestHandler).init(allocator, &handler, .{
            .address = self.config.address,
            .port = self.config.port,
            .server_name = self.config.server_name,
            .ca_cert_path = self.config.ca_cert_path,
            .skip_cert_verify = self.config.skip_cert_verify,
        });
        defer client.deinit();
        try client.run();

        return handler.responseAlloc();
    }

    pub fn sendAllocWithOptions(self: *QuicHttpClient, allocator: std.mem.Allocator, request: zstd.Http.Request, options: zstd.Http.SendOptions) zstd.Http.ClientError!zstd.Http.Response {
        options.checkActive() catch |err| return err;
        if (self.config.response_body_limit > options.response_body_limit) self.config.response_body_limit = options.response_body_limit;
        return self.sendAlloc(allocator, request) catch |err| switch (err) {
            error.OutOfMemory => error.OutOfMemory,
            error.ResponseBodyTooLarge => error.ResponseBodyTooLarge,
            else => error.TransportFailure,
        };
    }

    pub fn asHttpClient(self: *QuicHttpClient) zstd.Http.Client {
        return zstd.Http.Client.from(QuicHttpClient, self);
    }
};

const H3RequestHandler = struct {
    pub const protocol: event_loop.Protocol = .h3;

    allocator: std.mem.Allocator,
    request: zstd.Http.Request,
    config: ClientConfig,
    status: u16 = 0,
    headers: std.ArrayList(zstd.Http.Header) = .empty,
    body: std.ArrayList(u8) = .empty,

    pub fn init(allocator: std.mem.Allocator, request: zstd.Http.Request, config: ClientConfig) H3RequestHandler {
        return .{
            .allocator = allocator,
            .request = request,
            .config = config,
        };
    }

    pub fn deinit(self: *H3RequestHandler) void {
        for (self.headers.items) |header| {
            self.allocator.free(header.name);
            self.allocator.free(header.value);
        }
        self.headers.deinit(self.allocator);
        self.body.deinit(self.allocator);
    }

    pub fn onConnected(self: *H3RequestHandler, session: *event_loop.ClientSession) void {
        const headers = self.buildHeadersAlloc() catch {
            session.closeConnection();
            return;
        };
        defer self.allocator.free(headers);

        _ = session.sendRequest(headers, if (self.request.body.len == 0) null else self.request.body) catch {
            session.closeConnection();
            return;
        };
    }

    pub fn onHeaders(self: *H3RequestHandler, _: *event_loop.ClientSession, _: u64, headers: []const qpack.Header) void {
        for (headers) |header| {
            if (std.mem.eql(u8, header.name, ":status")) {
                self.status = std.fmt.parseInt(u16, header.value, 10) catch 0;
                continue;
            }
            const name = self.allocator.dupe(u8, header.name) catch return;
            errdefer self.allocator.free(name);
            const value = self.allocator.dupe(u8, header.value) catch return;
            self.headers.append(self.allocator, .{ .name = name, .value = value }) catch {
                self.allocator.free(name);
                self.allocator.free(value);
            };
        }
    }

    pub fn onData(self: *H3RequestHandler, session: *event_loop.ClientSession, _: u64, _: usize) void {
        var buffer: [8192]u8 = undefined;
        while (true) {
            const count = session.recvBody(&buffer);
            if (count == 0) break;
            if (self.body.items.len + count > self.config.response_body_limit) {
                session.closeConnection();
                break;
            }
            self.body.appendSlice(self.allocator, buffer[0..count]) catch {
                session.closeConnection();
                break;
            };
        }
    }

    pub fn onFinished(self: *H3RequestHandler, session: *event_loop.ClientSession, _: u64) void {
        _ = self;
        session.closeConnection();
    }

    fn buildHeadersAlloc(self: *H3RequestHandler) std.mem.Allocator.Error![]qpack.Header {
        const extra_count = self.request.headers.len;
        const headers = try self.allocator.alloc(qpack.Header, 4 + extra_count);
        errdefer self.allocator.free(headers);

        headers[0] = .{ .name = ":method", .value = self.request.method };
        headers[1] = .{ .name = ":scheme", .value = requestScheme(self.request.url) };
        headers[2] = .{ .name = ":authority", .value = requestAuthority(self.request.url) orelse self.config.server_name };
        headers[3] = .{ .name = ":path", .value = requestPath(self.request.url) };
        for (self.request.headers, 0..) |header, index| {
            headers[4 + index] = .{ .name = header.name, .value = header.value };
        }
        return headers;
    }

    fn responseAlloc(self: *H3RequestHandler) std.mem.Allocator.Error!zstd.Http.Response {
        const headers = try self.allocator.alloc(zstd.Http.Header, self.headers.items.len);
        errdefer self.allocator.free(headers);

        var initialized: usize = 0;
        errdefer {
            for (headers[0..initialized]) |header| {
                self.allocator.free(header.name);
                self.allocator.free(header.value);
            }
        }

        for (self.headers.items, 0..) |header, index| {
            const name = try self.allocator.dupe(u8, header.name);
            errdefer self.allocator.free(name);
            const value = try self.allocator.dupe(u8, header.value);
            headers[index] = .{ .name = name, .value = value };
            initialized += 1;
        }

        const body = try self.allocator.dupe(u8, self.body.items);
        errdefer self.allocator.free(body);

        return .{
            .status = if (self.status == 0) 502 else self.status,
            .headers = headers,
            .body = body,
        };
    }
};

pub const WebTransportMessageKind = enum { stream, datagram, session_ready, session_closed };

pub const WebTransportMessage = struct {
    kind: WebTransportMessageKind,
    session_id: u64,
    stream_id: ?u64 = null,
    payload: []const u8 = "",
    direction: []const u8 = "outbound",
};

pub const FakeWebTransportClient = struct {
    pub const capability = zstd.Capability.Descriptor{
        .id = "zigeffect-quic.fake-web-transport-client",
        .kind = .web_transport,
        .maturity = .fake,
        .package = "zigeffect-quic",
        .version = "0.1.0",
        .limitations = &.{"records messages in memory without a WebTransport session"},
    };

    allocator: std.mem.Allocator,
    messages: std.ArrayList(WebTransportMessage) = .empty,

    pub fn init(allocator: std.mem.Allocator) FakeWebTransportClient {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *FakeWebTransportClient) void {
        for (self.messages.items) |message| {
            self.allocator.free(message.payload);
            self.allocator.free(message.direction);
        }
        self.messages.deinit(self.allocator);
    }

    pub fn recordAlloc(self: *FakeWebTransportClient, message: WebTransportMessage) std.mem.Allocator.Error!void {
        const payload = try self.allocator.dupe(u8, message.payload);
        errdefer self.allocator.free(payload);
        const direction = try self.allocator.dupe(u8, message.direction);
        errdefer self.allocator.free(direction);
        try self.messages.append(self.allocator, .{
            .kind = message.kind,
            .session_id = message.session_id,
            .stream_id = message.stream_id,
            .payload = payload,
            .direction = direction,
        });
    }
};

pub const LocalDevSessionBridgeOptions = struct {
    session_id: u64,
    url: []const u8,
    status: []const u8 = "connected",
    fallback: []const u8 = "websocket",
};

pub const LocalDevSessionBridgeSummary = struct {
    allocator: std.mem.Allocator,
    event_count: usize,
    frame_count: usize,
    frame_jsonl: []const u8,
    receipt_json: []const u8,

    pub fn deinit(self: *LocalDevSessionBridgeSummary) void {
        self.allocator.free(self.frame_jsonl);
        self.allocator.free(self.receipt_json);
        self.* = undefined;
    }
};

pub fn bridgeLocalDevSessionJsonlAlloc(
    allocator: std.mem.Allocator,
    options: LocalDevSessionBridgeOptions,
    feed_jsonl: []const u8,
    client: *FakeWebTransportClient,
) std.mem.Allocator.Error!LocalDevSessionBridgeSummary {
    var frames: std.ArrayList(u8) = .empty;
    errdefer frames.deinit(allocator);

    var frame_count: usize = 0;
    var event_count: usize = 0;

    const status_payload = try transportStatusPayloadJsonAlloc(allocator, options);
    defer allocator.free(status_payload);
    try appendDevFrameAlloc(allocator, &frames, client, options, frame_count, status_payload);
    frame_count += 1;

    var iterator = std.mem.splitScalar(u8, feed_jsonl, '\n');
    while (iterator.next()) |raw_line| {
        const line = std.mem.trim(u8, raw_line, " \t\r\n");
        if (line.len == 0) continue;
        try appendDevFrameAlloc(allocator, &frames, client, options, frame_count, line);
        frame_count += 1;
        event_count += 1;
    }

    const frame_jsonl = try frames.toOwnedSlice(allocator);
    errdefer allocator.free(frame_jsonl);
    const receipt_json = try bridgeReceiptJsonAlloc(allocator, options, event_count, frame_count);
    errdefer allocator.free(receipt_json);

    return .{
        .allocator = allocator,
        .event_count = event_count,
        .frame_count = frame_count,
        .frame_jsonl = frame_jsonl,
        .receipt_json = receipt_json,
    };
}

fn appendDevFrameAlloc(
    allocator: std.mem.Allocator,
    frames: *std.ArrayList(u8),
    client: *FakeWebTransportClient,
    options: LocalDevSessionBridgeOptions,
    frame_sequence: usize,
    payload: []const u8,
) std.mem.Allocator.Error!void {
    const frame_json = try webTransportDevFrameJsonAlloc(allocator, options, frame_sequence, payload);
    defer allocator.free(frame_json);

    try client.recordAlloc(.{
        .kind = .datagram,
        .session_id = options.session_id,
        .payload = frame_json,
        .direction = "outbound",
    });
    try frames.appendSlice(allocator, frame_json);
    try frames.append(allocator, '\n');
}

fn webTransportDevFrameJsonAlloc(
    allocator: std.mem.Allocator,
    options: LocalDevSessionBridgeOptions,
    frame_sequence: usize,
    payload: []const u8,
) std.mem.Allocator.Error![]const u8 {
    const frame_sequence_text = try std.fmt.allocPrint(allocator, "{d}", .{frame_sequence});
    defer allocator.free(frame_sequence_text);
    const session_id = try std.fmt.allocPrint(allocator, "{d}", .{options.session_id});
    defer allocator.free(session_id);
    const url = try zstd.Secrets.redactAlloc(allocator, options.url);
    defer allocator.free(url);
    const safe_payload = try zstd.Secrets.redactAlloc(allocator, payload);
    defer allocator.free(safe_payload);

    return zstd.Json.objectFromFieldsAlloc(allocator, &.{
        .{ .name = "schema", .value = "zigeffect.webtransport.local-dev-frame.v1" },
        .{ .name = "transport", .value = "webtransport" },
        .{ .name = "frame_sequence", .value = frame_sequence_text },
        .{ .name = "session_id", .value = session_id },
        .{ .name = "url", .value = url },
        .{ .name = "payload", .value = safe_payload },
    });
}

fn transportStatusPayloadJsonAlloc(
    allocator: std.mem.Allocator,
    options: LocalDevSessionBridgeOptions,
) std.mem.Allocator.Error![]const u8 {
    const session_id = try std.fmt.allocPrint(allocator, "{d}", .{options.session_id});
    defer allocator.free(session_id);
    const url = try zstd.Secrets.redactAlloc(allocator, options.url);
    defer allocator.free(url);

    return zstd.Json.objectFromFieldsAlloc(allocator, &.{
        .{ .name = "sequence", .value = "0" },
        .{ .name = "kind", .value = "transport_status" },
        .{ .name = "protocol", .value = "webtransport" },
        .{ .name = "status", .value = options.status },
        .{ .name = "url", .value = url },
        .{ .name = "session_id", .value = session_id },
        .{ .name = "fallback", .value = options.fallback },
        .{ .name = "detail", .value = "local WebTransport bridge ready" },
    });
}

fn bridgeReceiptJsonAlloc(
    allocator: std.mem.Allocator,
    options: LocalDevSessionBridgeOptions,
    event_count: usize,
    frame_count: usize,
) std.mem.Allocator.Error![]const u8 {
    const event_count_text = try std.fmt.allocPrint(allocator, "{d}", .{event_count});
    defer allocator.free(event_count_text);
    const frame_count_text = try std.fmt.allocPrint(allocator, "{d}", .{frame_count});
    defer allocator.free(frame_count_text);
    const session_id = try std.fmt.allocPrint(allocator, "{d}", .{options.session_id});
    defer allocator.free(session_id);
    const url = try zstd.Secrets.redactAlloc(allocator, options.url);
    defer allocator.free(url);

    return zstd.Json.objectFromFieldsAlloc(allocator, &.{
        .{ .name = "kind", .value = "zigeffect.quic.webtransport.local-dev-bridge" },
        .{ .name = "protocol", .value = "webtransport" },
        .{ .name = "status", .value = options.status },
        .{ .name = "url", .value = url },
        .{ .name = "session_id", .value = session_id },
        .{ .name = "event_count", .value = event_count_text },
        .{ .name = "frame_count", .value = frame_count_text },
    });
}

pub fn http3ReceiptJsonAlloc(
    allocator: std.mem.Allocator,
    request: zstd.Http.Request,
    config: ClientConfig,
    outcome: []const u8,
    status: u16,
) std.mem.Allocator.Error![]const u8 {
    const redacted_request = try zstd.Http.redactRequestAlloc(allocator, request);
    defer allocator.free(redacted_request);
    const port = try std.fmt.allocPrint(allocator, "{d}", .{config.port});
    defer allocator.free(port);
    const status_text = try std.fmt.allocPrint(allocator, "{d}", .{status});
    defer allocator.free(status_text);
    const address = try zstd.Secrets.redactAlloc(allocator, config.address);
    defer allocator.free(address);
    const server_name = try zstd.Secrets.redactAlloc(allocator, config.server_name);
    defer allocator.free(server_name);

    return zstd.Json.objectFromFieldsAlloc(allocator, &.{
        .{ .name = "kind", .value = "zigeffect.quic.http3" },
        .{ .name = "protocol", .value = "h3" },
        .{ .name = "address", .value = address },
        .{ .name = "port", .value = port },
        .{ .name = "server_name", .value = server_name },
        .{ .name = "request", .value = redacted_request },
        .{ .name = "outcome", .value = outcome },
        .{ .name = "status", .value = status_text },
    });
}

pub fn webTransportReceiptJsonAlloc(
    allocator: std.mem.Allocator,
    message: WebTransportMessage,
) std.mem.Allocator.Error![]const u8 {
    const session_id = try std.fmt.allocPrint(allocator, "{d}", .{message.session_id});
    defer allocator.free(session_id);
    const stream_id = if (message.stream_id) |id| try std.fmt.allocPrint(allocator, "{d}", .{id}) else try allocator.dupe(u8, "");
    defer allocator.free(stream_id);
    const payload = try zstd.Secrets.redactAlloc(allocator, message.payload);
    defer allocator.free(payload);
    const direction = try zstd.Secrets.redactAlloc(allocator, message.direction);
    defer allocator.free(direction);

    return zstd.Json.objectFromFieldsAlloc(allocator, &.{
        .{ .name = "kind", .value = @tagName(message.kind) },
        .{ .name = "protocol", .value = "webtransport" },
        .{ .name = "session_id", .value = session_id },
        .{ .name = "stream_id", .value = stream_id },
        .{ .name = "direction", .value = direction },
        .{ .name = "payload", .value = payload },
    });
}

fn requestScheme(url: []const u8) []const u8 {
    if (std.mem.startsWith(u8, url, "http://")) return "http";
    return "https";
}

fn requestAuthority(url: []const u8) ?[]const u8 {
    const scheme = std.mem.indexOf(u8, url, "://") orelse return null;
    const authority_start = scheme + 3;
    const authority_end = std.mem.indexOfScalarPos(u8, url, authority_start, '/') orelse url.len;
    if (authority_end <= authority_start) return null;
    return url[authority_start..authority_end];
}

fn requestPath(url: []const u8) []const u8 {
    const scheme = std.mem.indexOf(u8, url, "://") orelse {
        if (url.len == 0) return "/";
        return url;
    };
    const authority_start = scheme + 3;
    const slash = std.mem.indexOfScalarPos(u8, url, authority_start, '/') orelse return "/";
    return url[slash..];
}

test "zigeffect-quic imports quic-zig" {
    try std.testing.expect(@hasDecl(quic, "event_loop"));
}

test "QUIC adapters publish truthful pre-production capabilities" {
    try FakeQuicHttpClient.capability.validate();
    try QuicHttpClient.capability.validate();
    try FakeWebTransportClient.capability.validate();
    try std.testing.expectEqual(zstd.Capability.Maturity.fake, FakeQuicHttpClient.capability.maturity);
    try std.testing.expectEqual(zstd.Capability.Maturity.local_development, QuicHttpClient.capability.maturity);
    try std.testing.expectEqual(zstd.Capability.Maturity.fake, FakeWebTransportClient.capability.maturity);
    try std.testing.expectEqual(
        zstd.Capability.Match.insufficient_maturity,
        zstd.Capability.match(QuicHttpClient.capability, .{
            .kind = .http_client,
            .minimum_maturity = .production_candidate,
            .requires_live_conformance = true,
        }),
    );
}

test "QUIC fake HTTP client works through zstd Http sendEffect with redacted causal facts" {
    var response = try zstd.Http.cloneResponseAlloc(std.testing.allocator, .{
        .status = 200,
        .body = "{\"ok\":true}",
    });
    defer response.deinit(std.testing.allocator);

    var client = try FakeQuicHttpClient.initOwned(std.testing.allocator, response);
    defer client.deinit();

    const main_layer = zstd.Http.clientLayer(client.asHttpClient());
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    var runtime = try zstd.ManagedRuntime(@TypeOf(main_layer)).make(std.testing.allocator, std.testing.io, tmp.dir, main_layer, .{});
    defer runtime.deinit();

    var output = try runtime.run(zstd.Http.sendEffect(.{
        .method = "GET",
        .url = "https://localhost/projects?token=abc123",
        .headers = &.{.{ .name = "authorization", .value = "Bearer abc123" }},
    }));
    defer output.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(u16, 200), output.status);
    try std.testing.expectEqualStrings("{\"ok\":true}", output.body);

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

test "QUIC HTTP receipts redact request metadata" {
    const receipt = try http3ReceiptJsonAlloc(std.testing.allocator, .{
        .method = "POST",
        .url = "https://localhost/agent?password=hunter2",
        .headers = &.{.{ .name = "authorization", .value = "Bearer abc123" }},
        .body = "token=abc123",
    }, .{
        .address = "127.0.0.1",
        .port = 4433,
        .server_name = "localhost",
        .skip_cert_verify = true,
    }, "success", 202);
    defer std.testing.allocator.free(receipt);

    try std.testing.expect(std.mem.indexOf(u8, receipt, "hunter2") == null);
    try std.testing.expect(std.mem.indexOf(u8, receipt, "abc123") == null);
    try std.testing.expect(std.mem.indexOf(u8, receipt, "\"protocol\":\"h3\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, receipt, "\"status\":\"202\"") != null);
}

test "WebTransport receipt redacts stream and datagram payloads" {
    const stream_receipt = try webTransportReceiptJsonAlloc(std.testing.allocator, .{
        .kind = .stream,
        .session_id = 7,
        .stream_id = 11,
        .payload = "sentinel-secret-for-tests",
        .direction = "outbound",
    });
    defer std.testing.allocator.free(stream_receipt);

    try std.testing.expect(std.mem.indexOf(u8, stream_receipt, "sentinel-secret") == null);
    try std.testing.expect(std.mem.indexOf(u8, stream_receipt, "\"kind\":\"stream\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, stream_receipt, "\"stream_id\":\"11\"") != null);

    const datagram_receipt = try webTransportReceiptJsonAlloc(std.testing.allocator, .{
        .kind = .datagram,
        .session_id = 7,
        .payload = "token=abc123",
        .direction = "inbound",
    });
    defer std.testing.allocator.free(datagram_receipt);

    try std.testing.expect(std.mem.indexOf(u8, datagram_receipt, "abc123") == null);
    try std.testing.expect(std.mem.indexOf(u8, datagram_receipt, "\"kind\":\"datagram\"") != null);
}

test "WebTransport bridge frames zstd Agent session JSONL for the workbench" {
    var session = zstd.Agent.Session.init(std.testing.allocator, "m19-session", "/tmp/yachdee");
    defer session.deinit();
    try session.recordAgentStatus(.{
        .agent_id = "codex",
        .agent_kind = .codex,
        .agent_label = "Codex",
        .status = .running,
        .task = "streaming token=abc123 through WebTransport",
    });
    try session.recordCheck(.{
        .label = "bun run zigeffect:quic:test",
        .command = "bun run zigeffect:quic:test",
        .status = .pass,
        .detail = "bridge test passed",
    });

    var client = FakeWebTransportClient.init(std.testing.allocator);
    defer client.deinit();

    var summary = try bridgeLocalDevSessionJsonlAlloc(std.testing.allocator, .{
        .session_id = 42,
        .url = "https://localhost:4433/.well-known/webtransport?token=abc123",
        .status = "connected",
    }, session.feedText(), &client);
    defer summary.deinit();

    try std.testing.expectEqual(@as(usize, 2), summary.event_count);
    try std.testing.expectEqual(@as(usize, 3), summary.frame_count);
    try std.testing.expectEqual(@as(usize, 3), client.messages.items.len);
    try std.testing.expect(std.mem.indexOf(u8, summary.frame_jsonl, "zigeffect.webtransport.local-dev-frame.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, summary.frame_jsonl, "transport_status") != null);
    try std.testing.expect(std.mem.indexOf(u8, summary.frame_jsonl, "abc123") == null);
    try std.testing.expect(std.mem.indexOf(u8, summary.receipt_json, "abc123") == null);
}
