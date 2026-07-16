const std = @import("std");
const zstd = @import("zigeffect_std");

pub const Http = zstd.Http;
pub const WebSocket = @import("websocket.zig");
pub const Tls = @import("tls.zig");

test "HTTP server is exposed as a scoped ZigEffect layer" {
    const Health = struct {
        fn handleAlloc(_: *@This(), allocator: std.mem.Allocator, _: Http.Request) !Http.Response {
            return Http.cloneResponseAlloc(allocator, .{ .status = 200, .body = "ok" });
        }
    };
    var health = Health{};
    const main_layer = configuredServerLayer(.{ .io = std.testing.io, .options = .{ .port = 0 } }, Handler.from(Health, &health));
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    var runtime = try zstd.ManagedRuntime(@TypeOf(main_layer)).make(
        std.testing.allocator,
        std.testing.io,
        tmp.dir,
        main_layer,
        .{},
    );
    defer runtime.deinit();

    try runtime.run(drainServerEffect().named("http.test.drain"));
    var snapshot = try runtime.inspect(std.testing.allocator, .{ .max_recent_events = 32 });
    defer snapshot.deinit();
    try std.testing.expectEqual(@as(usize, 3), snapshot.services.len);
    try std.testing.expect(snapshot.causal.recent_events.len != 0);
    try runtime.shutdown();
}

test {
    _ = WebSocket;
    _ = Tls;
}

pub const capability = zstd.Capability.Descriptor{
    .id = "zigeffect-http.server",
    .kind = .http_server,
    .maturity = .production_candidate,
    .package = "zigeffect-http",
    .version = "0.1.0",
    .features = &.{ "http1", "chunked", "middleware", "graceful-drain" },
    .side_effects = .real,
    .conformance = .{ .schema = "zigeffect.http-live-conformance", .version = 1, .receipt = "conformance/http-live.v1.json", .authority = .live_external, .observed_at_ms = 1783777336000, .valid_until_ms = 1791553336000, .content_sha256 = "sha256:818cd10afbf38ff139a45541d33b54abdf58e60e20a5fdffe3d627ce2a9ae2df" },
    .limitations = &.{"HTTP/2 is not implemented"},
};

pub const Limits = struct {
    max_request_line_bytes: usize = 8 * 1024,
    max_header_bytes: usize = 32 * 1024,
    max_headers: usize = 128,
    max_body_bytes: usize = 1024 * 1024,

    pub fn validate(self: Limits) !void {
        if (self.max_request_line_bytes == 0 or self.max_header_bytes == 0 or
            self.max_headers == 0 or self.max_body_bytes == 0)
        {
            return error.InvalidLimits;
        }
    }
};

pub const ParsedRequest = struct {
    request: Http.Request,
    version: []const u8,
    keep_alive: bool,
    consumed: usize,
    owned_body: ?[]u8 = null,

    pub fn deinit(self: *ParsedRequest, allocator: std.mem.Allocator) void {
        allocator.free(self.request.headers);
        if (self.owned_body) |body| allocator.free(body);
        self.* = undefined;
    }
};

pub const Handler = struct {
    pointer: *anyopaque,
    handle_fn: *const fn (*anyopaque, std.mem.Allocator, Http.Request) anyerror!Http.Response,

    pub fn from(comptime HandlerType: type, value: *HandlerType) Handler {
        return .{
            .pointer = value,
            .handle_fn = struct {
                fn handle(pointer: *anyopaque, allocator: std.mem.Allocator, request: Http.Request) anyerror!Http.Response {
                    const handler: *HandlerType = @ptrCast(@alignCast(pointer));
                    return handler.handleAlloc(allocator, request);
                }
            }.handle,
        };
    }

    pub fn fromRouter(comptime RouterType: type, value: *RouterType) Handler {
        return .{
            .pointer = value,
            .handle_fn = struct {
                fn handle(pointer: *anyopaque, allocator: std.mem.Allocator, request: Http.Request) anyerror!Http.Response {
                    const router: *RouterType = @ptrCast(@alignCast(pointer));
                    const result = try router.handleAlloc(allocator, request);
                    allocator.free(result.receipt_json);
                    allocator.free(result.trace_json);
                    return result.response;
                }
            }.handle,
        };
    }

    pub fn handleAlloc(self: Handler, allocator: std.mem.Allocator, request: Http.Request) anyerror!Http.Response {
        return self.handle_fn(self.pointer, allocator, request);
    }
};

pub const Guard = struct {
    pointer: *anyopaque,
    check_fn: *const fn (*anyopaque, Http.Request) ?zstd.External.Failure,

    pub fn from(comptime GuardType: type, value: *GuardType) Guard {
        return .{
            .pointer = value,
            .check_fn = struct {
                fn check(pointer: *anyopaque, request: Http.Request) ?zstd.External.Failure {
                    const guard: *GuardType = @ptrCast(@alignCast(pointer));
                    return guard.check(request);
                }
            }.check,
        };
    }

    pub fn check(self: Guard, request: Http.Request) ?zstd.External.Failure {
        return self.check_fn(self.pointer, request);
    }
};

pub const ApplicationMapOptions = struct {
    max_recent_events: usize = 128,
    max_response_bytes: usize = 1024 * 1024,
};

/// Type-erased access to the inspection surface of one application runtime.
/// The provider borrows the runtime and must be cleared before that runtime is
/// deinitialized.
pub const ApplicationMapProvider = struct {
    pointer: *anyopaque,
    json_fn: *const fn (*anyopaque, std.mem.Allocator, usize) anyerror![]u8,

    pub fn from(comptime RuntimeType: type, runtime: *RuntimeType) ApplicationMapProvider {
        comptime {
            if (!@hasDecl(RuntimeType, "inspectJson"))
                @compileError("application-map providers require a runtime with inspectJson");
        }
        return .{
            .pointer = runtime,
            .json_fn = struct {
                fn jsonAlloc(pointer: *anyopaque, allocator: std.mem.Allocator, max_recent_events: usize) anyerror![]u8 {
                    const owned_runtime: *RuntimeType = @ptrCast(@alignCast(pointer));
                    if (comptime @hasDecl(RuntimeType, "agentMapJsonAlloc")) {
                        return owned_runtime.agentMapJsonAlloc(allocator, .{ .max_recent_events = max_recent_events });
                    }
                    return owned_runtime.inspectJson(allocator, .{ .max_recent_events = max_recent_events });
                }
            }.jsonAlloc,
        };
    }

    pub fn jsonAlloc(self: ApplicationMapProvider, allocator: std.mem.Allocator, max_recent_events: usize) ![]u8 {
        return self.json_fn(self.pointer, allocator, max_recent_events);
    }
};

/// Breaks the construction cycle between a layered HTTP handler and the
/// managed runtime that owns that handler. Install exactly once after runtime
/// construction and before serving; clear after drain and before runtime
/// deinitialization. Those lifecycle boundaries also make concurrent reads
/// race-free without a lock on every inspection request.
pub const ApplicationMapSlot = struct {
    provider: ?ApplicationMapProvider = null,

    pub fn install(self: *ApplicationMapSlot, comptime RuntimeType: type, runtime: *RuntimeType) !void {
        if (self.provider != null) return error.ApplicationMapSlotAlreadyInstalled;
        self.provider = ApplicationMapProvider.from(RuntimeType, runtime);
    }

    pub fn clear(self: *ApplicationMapSlot) void {
        self.provider = null;
    }

    pub fn jsonAlloc(self: *ApplicationMapSlot, allocator: std.mem.Allocator, max_recent_events: usize) ![]u8 {
        const provider = self.provider orelse return error.ApplicationMapUnavailable;
        return provider.jsonAlloc(allocator, max_recent_events);
    }
};

/// Guarded layered handler whose provider is installed by the owning durable
/// runtime immediately after construction. This is the canonical adapter for
/// application servers because it never requires a second diagnostic runtime.
pub const RuntimeApplicationMapHandler = struct {
    slot: *ApplicationMapSlot,
    path: []const u8,
    guard: Guard,
    options: ApplicationMapOptions,

    pub fn init(
        slot: *ApplicationMapSlot,
        path: []const u8,
        guard: Guard,
        options: ApplicationMapOptions,
    ) !RuntimeApplicationMapHandler {
        if (path.len == 0 or path[0] != '/' or containsLineBreak(path)) return error.InvalidApplicationMapPath;
        if (options.max_recent_events == 0 or options.max_response_bytes == 0) return error.InvalidApplicationMapBounds;
        return .{ .slot = slot, .path = path, .guard = guard, .options = options };
    }

    pub fn asHandler(self: *RuntimeApplicationMapHandler) Handler {
        return Handler.from(RuntimeApplicationMapHandler, self);
    }

    pub fn handleAlloc(self: *RuntimeApplicationMapHandler, allocator: std.mem.Allocator, request: Http.Request) !Http.Response {
        if (!std.mem.eql(u8, request.url, self.path))
            return Http.cloneResponseAlloc(allocator, .{ .status = 404, .body = "not found" });
        if (!std.mem.eql(u8, request.method, "GET"))
            return Http.cloneResponseAlloc(allocator, .{ .status = 405, .body = "method not allowed" });
        if (self.guard.check(request)) |failure| {
            return Http.cloneResponseAlloc(allocator, .{
                .status = statusForFailure(failure.class),
                .body = @tagName(failure.class),
            });
        }

        const json = self.slot.jsonAlloc(allocator, self.options.max_recent_events) catch |err| switch (err) {
            error.ApplicationMapUnavailable => return Http.cloneResponseAlloc(allocator, .{
                .status = 503,
                .headers = &.{.{ .name = "retry-after", .value = "1" }},
                .body = "application map unavailable",
            }),
            else => return err,
        };
        defer allocator.free(json);
        if (json.len > self.options.max_response_bytes) return error.ApplicationMapResponseTooLarge;
        return Http.cloneResponseAlloc(allocator, .{
            .status = 200,
            .headers = &.{.{ .name = "content-type", .value = "application/json" }},
            .body = json,
        });
    }
};

/// A guarded HTTP adapter for the canonical runtime's single-query agent map.
/// Durable application runtimes include their NenDB graph and causal health;
/// the lower-level kernel runtime retains its in-memory snapshot fallback.
/// The guard is mandatory: callers cannot accidentally construct a public,
/// unauthenticated topology endpoint.
pub fn ApplicationMapHandler(comptime RuntimeType: type) type {
    return struct {
        const Self = @This();

        runtime: *RuntimeType,
        path: []const u8,
        guard: Guard,
        options: ApplicationMapOptions,

        pub fn init(
            runtime: *RuntimeType,
            path: []const u8,
            guard: Guard,
            options: ApplicationMapOptions,
        ) !Self {
            if (path.len == 0 or path[0] != '/' or containsLineBreak(path)) return error.InvalidApplicationMapPath;
            if (options.max_recent_events == 0 or options.max_response_bytes == 0) return error.InvalidApplicationMapBounds;
            return .{
                .runtime = runtime,
                .path = path,
                .guard = guard,
                .options = options,
            };
        }

        pub fn asHandler(self: *Self) Handler {
            return Handler.from(Self, self);
        }

        pub fn handleAlloc(self: *Self, allocator: std.mem.Allocator, request: Http.Request) !Http.Response {
            if (!std.mem.eql(u8, request.url, self.path)) {
                return Http.cloneResponseAlloc(allocator, .{ .status = 404, .body = "not found" });
            }
            if (!std.mem.eql(u8, request.method, "GET")) {
                return Http.cloneResponseAlloc(allocator, .{ .status = 405, .body = "method not allowed" });
            }
            if (self.guard.check(request)) |failure| {
                return Http.cloneResponseAlloc(allocator, .{
                    .status = statusForFailure(failure.class),
                    .body = @tagName(failure.class),
                });
            }

            const json = if (comptime @hasDecl(RuntimeType, "agentMapJsonAlloc"))
                try self.runtime.agentMapJsonAlloc(allocator, .{
                    .max_recent_events = self.options.max_recent_events,
                })
            else
                try self.runtime.inspectJson(allocator, .{
                    .max_recent_events = self.options.max_recent_events,
                });
            defer allocator.free(json);
            if (json.len > self.options.max_response_bytes) return error.ApplicationMapResponseTooLarge;
            return Http.cloneResponseAlloc(allocator, .{
                .status = 200,
                .headers = &.{.{ .name = "content-type", .value = "application/json" }},
                .body = json,
            });
        }
    };
}

pub const MiddlewareOptions = struct {
    request_id_prefix: []const u8 = "req",
    secure_headers: bool = true,
    cors_allow_origin: ?[]const u8 = null,
    compression_negotiation: bool = true,
    guards: []const Guard = &.{},
};

pub const PolicyHandler = struct {
    inner: Handler,
    options: MiddlewareOptions,
    next_request_id: std.atomic.Value(u64) = std.atomic.Value(u64).init(1),

    pub fn init(inner: Handler, options: MiddlewareOptions) !PolicyHandler {
        if (options.request_id_prefix.len == 0 or containsLineBreak(options.request_id_prefix)) return error.InvalidRequestIdPrefix;
        return .{ .inner = inner, .options = options };
    }

    pub fn asHandler(self: *PolicyHandler) Handler {
        return Handler.from(PolicyHandler, self);
    }

    pub fn handleAlloc(self: *PolicyHandler, allocator: std.mem.Allocator, request: Http.Request) !Http.Response {
        for (self.options.guards) |guard| {
            if (guard.check(request)) |failure| {
                return Http.cloneResponseAlloc(allocator, .{
                    .status = statusForFailure(failure.class),
                    .body = @tagName(failure.class),
                });
            }
        }
        var response = try self.inner.handleAlloc(allocator, request);
        errdefer response.deinit(allocator);
        const request_id = try std.fmt.allocPrint(allocator, "{s}-{d}", .{
            self.options.request_id_prefix,
            self.next_request_id.fetchAdd(1, .monotonic),
        });
        defer allocator.free(request_id);
        var additions: std.ArrayList(Http.Header) = .empty;
        defer additions.deinit(allocator);
        try additions.append(allocator, .{ .name = "X-Request-Id", .value = request_id });
        if (requestHeader(request, "traceparent")) |traceparent| {
            if (validTraceparent(traceparent)) try additions.append(allocator, .{ .name = "traceparent", .value = traceparent });
        }
        if (self.options.secure_headers) {
            try additions.append(allocator, .{ .name = "X-Content-Type-Options", .value = "nosniff" });
            try additions.append(allocator, .{ .name = "X-Frame-Options", .value = "DENY" });
            try additions.append(allocator, .{ .name = "Referrer-Policy", .value = "no-referrer" });
        }
        if (self.options.cors_allow_origin) |origin| {
            if (containsLineBreak(origin)) return error.InvalidCorsOrigin;
            try additions.append(allocator, .{ .name = "Access-Control-Allow-Origin", .value = origin });
        }
        if (self.options.compression_negotiation and requestHeader(request, "accept-encoding") != null) {
            try additions.append(allocator, .{ .name = "Vary", .value = "Accept-Encoding" });
            try additions.append(allocator, .{ .name = "X-ZigEffect-Compression", .value = "identity" });
        }
        try appendOwnedHeadersAlloc(allocator, &response, additions.items);
        return response;
    }
};

pub const ServerOptions = struct {
    host: []const u8 = "127.0.0.1",
    port: u16,
    limits: Limits = .{},
    max_connections: usize = 64,
    max_requests_per_connection: usize = 100,
    request_deadline_ms: ?u64 = 30_000,
    tls_provider: ?Tls.Provider = null,
    tls_handshake_deadline_ms: ?u64 = 10_000,
    websocket_handler: ?WebSocket.Handler = null,
    websocket_frame_limits: WebSocket.FrameLimits = .{},
    max_websocket_frames: usize = 1_000,
};

pub const ServeReport = struct {
    request_bytes: usize,
    response_bytes: usize,
    status: u16,
    requests: usize = 1,
};

pub const SupervisorReport = struct {
    accepted: usize = 0,
    completed: usize = 0,
    failed: usize = 0,
    requests: usize = 0,
    peak_in_flight: usize = 0,
};

pub const ShutdownOptions = struct {
    deadline_ms: u64 = 30_000,
    poll_interval_ms: u64 = 5,
    force_close_wait_ms: u64 = 1_000,

    pub fn validate(self: ShutdownOptions) !void {
        if (self.deadline_ms == 0 or self.poll_interval_ms == 0 or self.force_close_wait_ms == 0) return error.InvalidShutdownOptions;
    }
};

pub const ShutdownReport = struct {
    active_at_start: usize,
    active_remaining: usize,
    drained: bool,
    forced: bool,
};

const ActiveRegistry = struct {
    allocator: std.mem.Allocator,
    mutex: std.atomic.Mutex = .unlocked,
    sockets: []?std.Io.net.Socket,

    fn create(allocator: std.mem.Allocator, capacity: usize) !*ActiveRegistry {
        const self = try allocator.create(ActiveRegistry);
        errdefer allocator.destroy(self);
        const sockets = try allocator.alloc(?std.Io.net.Socket, capacity);
        @memset(sockets, null);
        self.* = .{ .allocator = allocator, .sockets = sockets };
        return self;
    }

    fn destroy(self: *ActiveRegistry) void {
        self.allocator.free(self.sockets);
        const allocator = self.allocator;
        allocator.destroy(self);
    }

    fn register(self: *ActiveRegistry, socket: std.Io.net.Socket) !void {
        self.lock();
        defer self.mutex.unlock();
        for (self.sockets) |*slot| {
            if (slot.* != null) continue;
            slot.* = socket;
            return;
        }
        return error.ConnectionCapacityExceeded;
    }

    fn unregister(self: *ActiveRegistry, handle: std.Io.net.Socket.Handle) void {
        self.lock();
        defer self.mutex.unlock();
        for (self.sockets) |*slot| {
            if (slot.*) |socket| {
                if (socket.handle == handle) {
                    slot.* = null;
                    return;
                }
            }
        }
    }

    fn count(self: *ActiveRegistry) usize {
        self.lock();
        defer self.mutex.unlock();
        var active: usize = 0;
        for (self.sockets) |slot| if (slot != null) {
            active += 1;
        };
        return active;
    }

    fn shutdownAll(self: *ActiveRegistry, io: std.Io) void {
        self.lock();
        defer self.mutex.unlock();
        for (self.sockets) |slot| {
            const socket = slot orelse continue;
            const stream = std.Io.net.Stream{ .socket = socket };
            stream.shutdown(io, .both) catch {};
        }
    }

    fn lock(self: *ActiveRegistry) void {
        while (!self.mutex.tryLock()) std.Thread.yield() catch {};
    }
};

const Wire = struct {
    pointer: *anyopaque,
    read_fn: *const fn (*anyopaque, []u8) anyerror!usize,
    write_fn: *const fn (*anyopaque, []const u8) anyerror!void,
    cancel_read_fn: *const fn (*anyopaque) void,

    fn read(self: Wire, buffer: []u8) !usize {
        return self.read_fn(self.pointer, buffer);
    }

    fn writeAll(self: Wire, bytes: []const u8) !void {
        return self.write_fn(self.pointer, bytes);
    }

    fn cancelRead(self: Wire) void {
        self.cancel_read_fn(self.pointer);
    }
};

const PlainWire = struct {
    io: std.Io,
    stream: std.Io.net.Stream,

    fn asWire(self: *PlainWire) Wire {
        return .{ .pointer = self, .read_fn = read, .write_fn = write, .cancel_read_fn = cancelRead };
    }

    fn read(pointer: *anyopaque, buffer: []u8) !usize {
        const self: *PlainWire = @ptrCast(@alignCast(pointer));
        var parts = [_][]u8{buffer};
        return self.io.vtable.netRead(self.io.userdata, self.stream.socket.handle, &parts);
    }

    fn write(pointer: *anyopaque, bytes: []const u8) !void {
        const self: *PlainWire = @ptrCast(@alignCast(pointer));
        return writeAll(self.stream, self.io, bytes);
    }

    fn cancelRead(pointer: *anyopaque) void {
        const self: *PlainWire = @ptrCast(@alignCast(pointer));
        self.stream.shutdown(self.io, .recv) catch {};
    }
};

const TlsWire = struct {
    io: std.Io,
    stream: std.Io.net.Stream,
    connection: *Tls.Connection,

    fn asWire(self: *TlsWire) Wire {
        return .{ .pointer = self, .read_fn = read, .write_fn = write, .cancel_read_fn = cancelRead };
    }

    fn read(pointer: *anyopaque, buffer: []u8) !usize {
        const self: *TlsWire = @ptrCast(@alignCast(pointer));
        return self.connection.read(buffer);
    }

    fn write(pointer: *anyopaque, bytes: []const u8) !void {
        const self: *TlsWire = @ptrCast(@alignCast(pointer));
        return self.connection.write(bytes);
    }

    fn cancelRead(pointer: *anyopaque) void {
        const self: *TlsWire = @ptrCast(@alignCast(pointer));
        self.stream.shutdown(self.io, .recv) catch {};
    }
};

pub const Server = struct {
    allocator: std.mem.Allocator,
    io: std.Io,
    options: ServerOptions,
    listener: std.Io.net.Server,
    handler: Handler,
    lifecycle: zstd.Application.Lifecycle.Manager,
    accepting: std.atomic.Value(bool),
    listener_open: std.atomic.Value(bool),
    active_registry: *ActiveRegistry,

    pub fn init(allocator: std.mem.Allocator, io: std.Io, options: ServerOptions, handler: Handler) !Server {
        try options.limits.validate();
        if (options.max_connections == 0 or options.max_requests_per_connection == 0) return error.InvalidLimits;
        if (options.request_deadline_ms == 0) return error.InvalidRequestDeadline;
        if (options.tls_handshake_deadline_ms == 0) return error.InvalidTlsHandshakeDeadline;
        if (options.websocket_frame_limits.max_payload_bytes == 0 or options.max_websocket_frames == 0) return error.InvalidWebSocketLimits;
        const address = try std.Io.net.IpAddress.parseIp4(options.host, options.port);
        var listener = try address.listen(io, .{ .reuse_address = true });
        errdefer listener.deinit(io);
        const active_registry = try ActiveRegistry.create(allocator, options.max_connections);
        errdefer active_registry.destroy();
        var lifecycle = zstd.Application.Lifecycle.Manager.init(allocator);
        errdefer lifecycle.deinit();
        try lifecycle.start();
        try lifecycle.ready();
        return .{
            .allocator = allocator,
            .io = io,
            .options = options,
            .listener = listener,
            .handler = handler,
            .lifecycle = lifecycle,
            .accepting = std.atomic.Value(bool).init(true),
            .listener_open = std.atomic.Value(bool).init(true),
            .active_registry = active_registry,
        };
    }

    pub fn deinit(self: *Server) void {
        self.lifecycle.stop() catch {};
        if (self.listener_open.swap(false, .acq_rel)) self.listener.deinit(self.io);
        self.lifecycle.deinit();
        self.active_registry.destroy();
        self.* = undefined;
    }

    pub fn drain(self: *Server) !void {
        self.accepting.store(false, .release);
        try self.lifecycle.drain();
        if (self.listener_open.swap(false, .acq_rel)) self.listener.socket.close(self.io);
    }

    pub fn snapshot(self: *const Server) zstd.Application.Lifecycle.Snapshot {
        return self.lifecycle.snapshot();
    }

    pub fn activeConnections(self: *Server) usize {
        return self.active_registry.count();
    }

    pub fn shutdown(self: *Server, options: ShutdownOptions) !ShutdownReport {
        try options.validate();
        try self.drain();
        const active_at_start = self.activeConnections();
        const graceful_deadline = deadlineFromNow(self.io, options.deadline_ms);
        while (self.activeConnections() != 0 and !deadlineReached(self.io, graceful_deadline)) {
            try sleepMilliseconds(self.io, options.poll_interval_ms);
        }
        if (self.activeConnections() == 0) {
            try self.lifecycle.stop();
            return .{ .active_at_start = active_at_start, .active_remaining = 0, .drained = true, .forced = false };
        }

        self.active_registry.shutdownAll(self.io);
        try self.lifecycle.forceStop();
        const force_deadline = deadlineFromNow(self.io, options.force_close_wait_ms);
        while (self.activeConnections() != 0 and !deadlineReached(self.io, force_deadline)) {
            try sleepMilliseconds(self.io, options.poll_interval_ms);
        }
        return .{
            .active_at_start = active_at_start,
            .active_remaining = self.activeConnections(),
            .drained = false,
            .forced = true,
        };
    }

    pub fn serveOne(self: *Server, allocator: std.mem.Allocator) !ServeReport {
        if (!self.accepting.load(.acquire) or !self.snapshot().readiness) return error.ServerNotReady;
        var stream = try self.listener.accept(self.io);
        defer stream.close(self.io);
        try self.active_registry.register(stream.socket);
        defer self.active_registry.unregister(stream.socket.handle);
        return self.handleStream(allocator, stream);
    }

    pub fn serveConnections(self: *Server, allocator: std.mem.Allocator, connection_count: usize) !SupervisorReport {
        if (connection_count == 0) return error.InvalidConnectionCount;
        if (!self.accepting.load(.acquire) or !self.snapshot().readiness) return error.ServerNotReady;
        const contexts = try allocator.alloc(ConnectionContext, connection_count);
        defer allocator.free(contexts);
        const threads = try allocator.alloc(std.Thread, @min(connection_count, self.options.max_connections));
        defer allocator.free(threads);

        var report = SupervisorReport{};
        var next: usize = 0;
        while (next < connection_count and self.accepting.load(.acquire)) {
            const batch_count = @min(self.options.max_connections, connection_count - next);
            var spawned: usize = 0;
            while (spawned < batch_count) : (spawned += 1) {
                const stream = self.listener.accept(self.io) catch |err| {
                    if (!self.accepting.load(.acquire)) break;
                    return err;
                };
                self.active_registry.register(stream.socket) catch |err| {
                    stream.close(self.io);
                    return err;
                };
                contexts[next + spawned] = .{ .server = self, .allocator = allocator, .stream = stream };
                threads[spawned] = std.Thread.spawn(.{}, serveConnectionThread, .{&contexts[next + spawned]}) catch |err| {
                    self.active_registry.unregister(stream.socket.handle);
                    stream.close(self.io);
                    return err;
                };
                report.accepted += 1;
            }
            report.peak_in_flight = @max(report.peak_in_flight, spawned);
            for (threads[0..spawned]) |thread| thread.join();
            for (contexts[next .. next + spawned]) |context| {
                if (context.failure == null) {
                    report.completed += 1;
                    report.requests += context.report.?.requests;
                } else {
                    report.failed += 1;
                }
            }
            next += spawned;
            if (spawned == 0) break;
        }
        return report;
    }

    fn handleStream(self: *Server, allocator: std.mem.Allocator, stream: std.Io.net.Stream) !ServeReport {
        if (self.options.tls_provider) |provider| {
            var connection = try timedTlsHandshake(
                allocator,
                self.io,
                stream,
                provider,
                self.options.tls_handshake_deadline_ms,
            );
            defer connection.deinit(allocator);
            var tls_wire = TlsWire{ .io = self.io, .stream = stream, .connection = &connection };
            return self.handleWire(allocator, tls_wire.asWire());
        }
        var plain_wire = PlainWire{ .io = self.io, .stream = stream };
        return self.handleWire(allocator, plain_wire.asWire());
    }

    fn handleWire(self: *Server, allocator: std.mem.Allocator, wire: Wire) !ServeReport {
        const capacity = std.math.add(usize, self.options.limits.max_header_bytes, self.options.limits.max_body_bytes) catch return error.InvalidLimits;
        const buffer = try allocator.alloc(u8, capacity);
        defer allocator.free(buffer);
        var buffered: usize = 0;
        var total_read: usize = 0;
        var total_written: usize = 0;
        var requests: usize = 0;
        var last_status: u16 = 0;
        while (requests < self.options.max_requests_per_connection) {
            const request_deadline = if (self.options.request_deadline_ms) |milliseconds| deadlineFromNow(self.io, milliseconds) else null;
            var parsed: ParsedRequest = while (true) {
                const candidate = parseRequestAlloc(allocator, buffer[0..buffered], self.options.limits) catch |err| switch (err) {
                    error.IncompleteRequest => {
                        if (buffered == buffer.len) return error.RequestTooLarge;
                        const parts = [_][]u8{buffer[buffered..]};
                        const count = timedWireRead(self.io, wire, parts[0], request_deadline) catch |read_err| switch (read_err) {
                            error.RequestTimeout => {
                                const encoded = try errorResponseAlloc(allocator, 408, "RequestTimeout");
                                defer allocator.free(encoded);
                                try wire.writeAll(encoded);
                                return .{
                                    .request_bytes = total_read,
                                    .response_bytes = total_written + encoded.len,
                                    .status = 408,
                                    .requests = requests,
                                };
                            },
                            else => return read_err,
                        };
                        if (count == 0) return if (requests == 0) error.ConnectionClosed else .{
                            .request_bytes = total_read,
                            .response_bytes = total_written,
                            .status = last_status,
                            .requests = requests,
                        };
                        buffered += count;
                        total_read += count;
                        continue;
                    },
                    else => {
                        const status = statusForParseError(err);
                        const encoded = try errorResponseAlloc(allocator, status, @errorName(err));
                        defer allocator.free(encoded);
                        try wire.writeAll(encoded);
                        return .{
                            .request_bytes = total_read,
                            .response_bytes = encoded.len,
                            .status = status,
                            .requests = requests,
                        };
                    },
                };
                break candidate;
            };
            if (self.options.websocket_handler) |websocket_handler| {
                if (WebSocket.isUpgradeRequest(parsed.request) and websocket_handler.accepts(parsed.request)) {
                    const initial = buffer[parsed.consumed..buffered];
                    const report = self.serveWebSocket(allocator, wire, parsed.request, parsed.version, websocket_handler, initial, total_read) catch |err| {
                        parsed.deinit(allocator);
                        return err;
                    };
                    parsed.deinit(allocator);
                    return report;
                }
            }
            const consumed = parsed.consumed;
            const request_keep_alive = parsed.keep_alive;
            var response = response: {
                defer parsed.deinit(allocator);
                break :response self.handler.handleAlloc(allocator, parsed.request) catch |err| {
                    const failure = zstd.External.Failure.fromError("http-server", "handle", err);
                    const body = try allocator.dupe(u8, @tagName(failure.class));
                    errdefer allocator.free(body);
                    break :response Http.Response{
                        .status = statusForFailure(failure.class),
                        .headers = try allocator.alloc(Http.Header, 0),
                        .body = body,
                    };
                };
            };
            defer response.deinit(allocator);
            requests += 1;
            last_status = response.status;
            const keep_alive = request_keep_alive and
                requests < self.options.max_requests_per_connection and
                self.accepting.load(.acquire);
            const encoded = try encodeResponseAlloc(allocator, response, keep_alive);
            defer allocator.free(encoded);
            try wire.writeAll(encoded);
            total_written += encoded.len;

            const remaining = buffered - consumed;
            if (remaining != 0) std.mem.copyForwards(u8, buffer[0..remaining], buffer[consumed..buffered]);
            buffered = remaining;
            if (!keep_alive) break;
        }
        return .{ .request_bytes = total_read, .response_bytes = total_written, .status = last_status, .requests = requests };
    }

    fn serveWebSocket(
        self: *Server,
        allocator: std.mem.Allocator,
        wire: Wire,
        request: Http.Request,
        version: []const u8,
        handler: WebSocket.Handler,
        initial: []const u8,
        request_bytes: usize,
    ) !ServeReport {
        const handshake = try WebSocket.handshakeResponseAlloc(allocator, request, version);
        defer allocator.free(handshake);
        try wire.writeAll(handshake);
        var response_bytes = handshake.len;

        const capacity = std.math.add(usize, self.options.websocket_frame_limits.max_payload_bytes, 14) catch return error.InvalidWebSocketLimits;
        const buffer = try allocator.alloc(u8, capacity);
        defer allocator.free(buffer);
        if (initial.len > buffer.len) return error.FrameTooLarge;
        @memcpy(buffer[0..initial.len], initial);
        var buffered = initial.len;
        var frames: usize = 0;
        while (frames < self.options.max_websocket_frames) : (frames += 1) {
            var frame: WebSocket.Frame = while (true) {
                const parsed = WebSocket.parseClientFrameAlloc(allocator, buffer[0..buffered], self.options.websocket_frame_limits) catch |err| switch (err) {
                    error.IncompleteFrame => {
                        if (buffered == buffer.len) return error.FrameTooLarge;
                        const deadline = if (self.options.request_deadline_ms) |milliseconds| deadlineFromNow(self.io, milliseconds) else null;
                        const count = try timedWireRead(self.io, wire, buffer[buffered..], deadline);
                        if (count == 0) return error.ConnectionClosed;
                        buffered += count;
                        continue;
                    },
                    else => return err,
                };
                break parsed;
            };
            defer frame.deinit(allocator);
            const consumed = frame.consumed;
            switch (frame.opcode) {
                .ping => {
                    const encoded = try WebSocket.encodeServerFrameAlloc(allocator, .pong, frame.payload, true);
                    defer allocator.free(encoded);
                    try wire.writeAll(encoded);
                    response_bytes += encoded.len;
                },
                .pong => {},
                .close => {
                    const encoded = try WebSocket.encodeServerFrameAlloc(allocator, .close, frame.payload, true);
                    defer allocator.free(encoded);
                    try wire.writeAll(encoded);
                    response_bytes += encoded.len;
                    return .{ .request_bytes = request_bytes, .response_bytes = response_bytes, .status = 101, .requests = 1 };
                },
                .continuation => return error.FragmentedMessageUnsupported,
                .text, .binary => {
                    if (!frame.fin) return error.FragmentedMessageUnsupported;
                    if (try handler.handleAlloc(allocator, request, frame)) |message_value| {
                        var message = message_value;
                        defer message.deinit(allocator);
                        const encoded = try WebSocket.encodeServerFrameAlloc(allocator, message.opcode, message.payload, true);
                        defer allocator.free(encoded);
                        try wire.writeAll(encoded);
                        response_bytes += encoded.len;
                    }
                },
            }
            const remaining = buffered - consumed;
            if (remaining != 0) std.mem.copyForwards(u8, buffer[0..remaining], buffer[consumed..buffered]);
            buffered = remaining;
        }
        return error.WebSocketFrameLimitExceeded;
    }
};

const TlsHandshakeRace = union(enum) {
    handshake: anyerror!Tls.Connection,
    timeout: std.Io.Cancelable!void,
};

fn timedTlsHandshake(
    allocator: std.mem.Allocator,
    io: std.Io,
    stream: std.Io.net.Stream,
    provider: Tls.Provider,
    deadline_ms: ?u64,
) !Tls.Connection {
    const milliseconds = deadline_ms orelse return provider.handshakeAlloc(allocator, stream.socket.handle);
    var results: [2]TlsHandshakeRace = undefined;
    var race = std.Io.Select(TlsHandshakeRace).init(io, &results);
    race.async(.handshake, tlsHandshakeTask, .{ provider, allocator, stream.socket.handle });
    race.async(.timeout, deadlineTask, .{ io, deadlineFromNow(io, milliseconds) });
    const first = race.await() catch |err| {
        cancelTlsHandshakeRace(&race, allocator);
        return err;
    };
    return switch (first) {
        .handshake => |result| result: {
            cancelTlsHandshakeRace(&race, allocator);
            break :result result;
        },
        .timeout => |result| {
            try result;
            stream.shutdown(io, .both) catch {};
            cancelTlsHandshakeRace(&race, allocator);
            return error.TlsHandshakeTimeout;
        },
    };
}

fn tlsHandshakeTask(provider: Tls.Provider, allocator: std.mem.Allocator, handle: std.Io.net.Socket.Handle) anyerror!Tls.Connection {
    return provider.handshakeAlloc(allocator, handle);
}

fn cancelTlsHandshakeRace(race: *std.Io.Select(TlsHandshakeRace), allocator: std.mem.Allocator) void {
    while (race.cancel()) |pending| switch (pending) {
        .timeout => {},
        .handshake => |result| {
            if (result) |connection_value| {
                var connection = connection_value;
                connection.deinit(allocator);
            } else |_| {}
        },
    };
}

const ConnectionContext = struct {
    server: *Server,
    allocator: std.mem.Allocator,
    stream: std.Io.net.Stream,
    report: ?ServeReport = null,
    failure: ?anyerror = null,
};

fn serveConnectionThread(context: *ConnectionContext) void {
    defer context.server.active_registry.unregister(context.stream.socket.handle);
    defer context.stream.close(context.server.io);
    context.report = context.server.handleStream(context.allocator, context.stream) catch |err| {
        context.failure = err;
        return;
    };
}

fn timedWireRead(
    io: std.Io,
    wire: Wire,
    buffer: []u8,
    deadline: ?std.Io.Clock.Timestamp,
) !usize {
    const timestamp = deadline orelse return wire.read(buffer);
    const Race = union(enum) {
        read: anyerror!usize,
        timeout: std.Io.Cancelable!void,
    };
    var results: [2]Race = undefined;
    var race = std.Io.Select(Race).init(io, &results);
    race.async(.read, wireReadTask, .{ wire, buffer });
    race.async(.timeout, deadlineTask, .{ io, timestamp });
    const first = race.await() catch |err| {
        race.cancelDiscard();
        return err;
    };
    return switch (first) {
        .read => |result| result: {
            race.cancelDiscard();
            break :result result;
        },
        .timeout => |result| {
            try result;
            wire.cancelRead();
            race.cancelDiscard();
            return error.RequestTimeout;
        },
    };
}

fn wireReadTask(wire: Wire, buffer: []u8) anyerror!usize {
    return wire.read(buffer);
}

fn deadlineTask(io: std.Io, deadline: std.Io.Clock.Timestamp) std.Io.Cancelable!void {
    return deadline.wait(io);
}

fn sleepMilliseconds(io: std.Io, milliseconds: u64) !void {
    try (std.Io.Clock.Duration{
        .raw = .fromMilliseconds(@intCast(milliseconds)),
        .clock = .awake,
    }).sleep(io);
}

fn deadlineFromNow(io: std.Io, milliseconds: u64) std.Io.Clock.Timestamp {
    return std.Io.Clock.Timestamp.fromNow(io, .{
        .raw = .fromMilliseconds(@intCast(milliseconds)),
        .clock = .awake,
    });
}

fn deadlineReached(io: std.Io, deadline: std.Io.Clock.Timestamp) bool {
    return std.Io.Clock.Timestamp.compare(std.Io.Clock.Timestamp.now(io, .awake), .gte, deadline);
}

fn writeAll(stream: std.Io.net.Stream, io: std.Io, bytes: []const u8) !void {
    var offset: usize = 0;
    while (offset < bytes.len) {
        const parts = [_][]const u8{bytes[offset..]};
        const written = try io.vtable.netWrite(io.userdata, stream.socket.handle, "", &parts, 1);
        if (written == 0) return error.WriteZero;
        offset += written;
    }
}

fn errorResponseAlloc(allocator: std.mem.Allocator, status: u16, detail: []const u8) ![]u8 {
    return encodeResponseAlloc(allocator, .{
        .status = status,
        .headers = &.{.{ .name = "Content-Type", .value = "text/plain; charset=utf-8" }},
        .body = detail,
    }, false);
}

fn statusForParseError(err: anyerror) u16 {
    return switch (err) {
        error.BodyTooLarge, error.HeadersTooLarge, error.TooManyHeaders, error.RequestTooLarge => 413,
        error.UnsupportedHttpVersion, error.UnsupportedTransferEncoding => 400,
        else => 400,
    };
}

fn statusForFailure(class: zstd.External.Class) u16 {
    return switch (class) {
        .unauthorized => 401,
        .capacity => 429,
        .timeout, .unavailable => 503,
        .conflict => 409,
        .unsupported => 501,
        .canceled => 499,
        .corrupt_data => 400,
        .internal => 500,
    };
}

fn requestHeader(request: Http.Request, name: []const u8) ?[]const u8 {
    for (request.headers) |header| if (std.ascii.eqlIgnoreCase(header.name, name)) return header.value;
    return null;
}

fn validTraceparent(value: []const u8) bool {
    _ = zstd.fx.parseTraceParent(value) catch return false;
    return true;
}

fn appendOwnedHeadersAlloc(allocator: std.mem.Allocator, response: *Http.Response, additions: []const Http.Header) !void {
    const headers = try allocator.alloc(Http.Header, response.headers.len + additions.len);
    errdefer allocator.free(headers);
    var initialized: usize = 0;
    errdefer for (headers[0..initialized]) |header| {
        allocator.free(header.name);
        allocator.free(header.value);
    };
    for (response.headers) |header| {
        headers[initialized] = try cloneHeaderAlloc(allocator, header);
        initialized += 1;
    }
    for (additions) |header| {
        headers[initialized] = try cloneHeaderAlloc(allocator, header);
        initialized += 1;
    }
    const old_headers = response.headers;
    for (old_headers) |header| {
        allocator.free(header.name);
        allocator.free(header.value);
    }
    allocator.free(old_headers);
    response.headers = headers;
}

fn cloneHeaderAlloc(allocator: std.mem.Allocator, header: Http.Header) !Http.Header {
    const name = try allocator.dupe(u8, header.name);
    errdefer allocator.free(name);
    return .{
        .name = name,
        .value = try allocator.dupe(u8, header.value),
    };
}

pub fn parseRequestAlloc(allocator: std.mem.Allocator, input: []const u8, limits: Limits) !ParsedRequest {
    try limits.validate();
    const marker = "\r\n\r\n";
    const header_start = std.mem.indexOf(u8, input, marker) orelse {
        if (input.len > limits.max_header_bytes) return error.HeadersTooLarge;
        return error.IncompleteRequest;
    };
    const header_end = header_start + marker.len;
    if (header_end > limits.max_header_bytes) return error.HeadersTooLarge;

    const request_line_marker = std.mem.indexOf(u8, input[0..header_start], "\r\n");
    const request_line_end = request_line_marker orelse header_start;
    const headers_begin = if (request_line_marker != null) request_line_end + 2 else header_start;
    if (request_line_end == 0 or request_line_end > limits.max_request_line_bytes) return error.MalformedRequestLine;
    var request_parts = std.mem.splitScalar(u8, input[0..request_line_end], ' ');
    const method = request_parts.next() orelse return error.MalformedRequestLine;
    const target = request_parts.next() orelse return error.MalformedRequestLine;
    const version = request_parts.next() orelse return error.MalformedRequestLine;
    if (request_parts.next() != null or !validToken(method) or !validRequestTarget(target)) return error.MalformedRequestLine;
    if (!std.mem.eql(u8, version, "HTTP/1.1") and !std.mem.eql(u8, version, "HTTP/1.0")) return error.UnsupportedHttpVersion;

    var headers: std.ArrayList(Http.Header) = .empty;
    errdefer headers.deinit(allocator);
    var content_length: usize = 0;
    var has_content_length = false;
    var connection: []const u8 = "";
    var chunked = false;
    var transfer_encoding_seen = false;
    var host_count: usize = 0;
    var lines = std.mem.splitSequence(u8, input[headers_begin..header_start], "\r\n");
    while (lines.next()) |line| {
        if (line.len == 0) continue;
        if (headers.items.len >= limits.max_headers) return error.TooManyHeaders;
        const colon = std.mem.indexOfScalar(u8, line, ':') orelse return error.MalformedHeader;
        const name = line[0..colon];
        const value = std.mem.trim(u8, line[colon + 1 ..], " \t");
        if (!validHeaderName(name) or !validHeaderValue(value)) return error.MalformedHeader;
        try headers.append(allocator, .{ .name = name, .value = value });
        if (std.ascii.eqlIgnoreCase(name, "host")) {
            host_count += 1;
            if (host_count > 1) return error.DuplicateHost;
            if (value.len == 0) return error.MalformedHost;
        } else if (std.ascii.eqlIgnoreCase(name, "content-length")) {
            if (has_content_length) return error.DuplicateContentLength;
            content_length = std.fmt.parseInt(usize, value, 10) catch return error.MalformedContentLength;
            has_content_length = true;
        } else if (std.ascii.eqlIgnoreCase(name, "transfer-encoding")) {
            if (transfer_encoding_seen) return error.DuplicateTransferEncoding;
            transfer_encoding_seen = true;
            if (!std.ascii.eqlIgnoreCase(value, "chunked")) return error.UnsupportedTransferEncoding;
            chunked = true;
        } else if (std.ascii.eqlIgnoreCase(name, "connection")) {
            connection = value;
        }
    }
    if (std.mem.eql(u8, version, "HTTP/1.1") and host_count == 0) return error.MissingHost;
    if (chunked and has_content_length) return error.ConflictingBodyFraming;
    if (content_length > limits.max_body_bytes) return error.BodyTooLarge;
    var owned_body: ?[]u8 = null;
    errdefer if (owned_body) |body| allocator.free(body);
    const body: []const u8, const consumed: usize = if (chunked) decoded: {
        const decoded_body = try decodeChunkedBodyAlloc(allocator, input[header_end..], limits);
        owned_body = decoded_body.body;
        break :decoded .{ decoded_body.body, header_end + decoded_body.consumed };
    } else decoded: {
        if (input.len - header_end < content_length) return error.IncompleteRequest;
        break :decoded .{ input[header_end .. header_end + content_length], header_end + content_length };
    };
    const owned_headers = try headers.toOwnedSlice(allocator);
    errdefer allocator.free(owned_headers);
    const default_keep_alive = std.mem.eql(u8, version, "HTTP/1.1");
    const keep_alive = if (containsHeaderToken(connection, "close"))
        false
    else if (containsHeaderToken(connection, "keep-alive"))
        true
    else
        default_keep_alive;
    return .{
        .request = .{ .method = method, .url = target, .headers = owned_headers, .body = body },
        .version = version,
        .keep_alive = keep_alive,
        .consumed = consumed,
        .owned_body = owned_body,
    };
}

const DecodedChunkedBody = struct {
    body: []u8,
    consumed: usize,
};

fn decodeChunkedBodyAlloc(allocator: std.mem.Allocator, input: []const u8, limits: Limits) !DecodedChunkedBody {
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);
    var cursor: usize = 0;
    var trailer_count: usize = 0;
    while (true) {
        const relative_line_end = std.mem.indexOf(u8, input[cursor..], "\r\n") orelse return error.IncompleteRequest;
        const line_end = cursor + relative_line_end;
        const raw_size = std.mem.trim(u8, input[cursor..line_end], " \t");
        const extension = std.mem.indexOfScalar(u8, raw_size, ';') orelse raw_size.len;
        const size_text = raw_size[0..extension];
        if (size_text.len == 0 or size_text.len > 16) return error.MalformedChunk;
        const chunk_size = std.fmt.parseInt(usize, size_text, 16) catch return error.MalformedChunk;
        cursor = line_end + 2;
        if (chunk_size == 0) {
            const trailer_start = cursor;
            while (true) {
                const relative_trailer_end = std.mem.indexOf(u8, input[cursor..], "\r\n") orelse return error.IncompleteRequest;
                const trailer_end = cursor + relative_trailer_end;
                if (trailer_end - trailer_start > limits.max_header_bytes) return error.HeadersTooLarge;
                if (trailer_end == cursor) {
                    cursor += 2;
                    return .{ .body = try output.toOwnedSlice(allocator), .consumed = cursor };
                }
                const trailer = input[cursor..trailer_end];
                const colon = std.mem.indexOfScalar(u8, trailer, ':') orelse return error.MalformedHeader;
                const name = trailer[0..colon];
                const value = std.mem.trim(u8, trailer[colon + 1 ..], " \t");
                if (!validHeaderName(name) or !validHeaderValue(value)) return error.MalformedHeader;
                if (std.ascii.eqlIgnoreCase(name, "content-length") or
                    std.ascii.eqlIgnoreCase(name, "transfer-encoding") or
                    std.ascii.eqlIgnoreCase(name, "host")) return error.ForbiddenTrailer;
                trailer_count += 1;
                if (trailer_count > limits.max_headers) return error.TooManyHeaders;
                cursor = trailer_end + 2;
            }
        }
        if (chunk_size > limits.max_body_bytes -| output.items.len) return error.BodyTooLarge;
        if (input.len - cursor < chunk_size + 2) return error.IncompleteRequest;
        if (!std.mem.eql(u8, input[cursor + chunk_size .. cursor + chunk_size + 2], "\r\n")) return error.MalformedChunk;
        try output.appendSlice(allocator, input[cursor .. cursor + chunk_size]);
        cursor += chunk_size + 2;
    }
}

pub fn encodeResponseAlloc(allocator: std.mem.Allocator, response: Http.Response, keep_alive: bool) ![]u8 {
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);
    try output.print(allocator, "HTTP/1.1 {d} {s}\r\n", .{ response.status, reasonPhrase(response.status) });
    for (response.headers) |header| {
        if (!validHeaderName(header.name) or containsLineBreak(header.value)) return error.MalformedHeader;
        if (std.ascii.eqlIgnoreCase(header.name, "content-length") or std.ascii.eqlIgnoreCase(header.name, "connection")) continue;
        try output.print(allocator, "{s}: {s}\r\n", .{ header.name, header.value });
    }
    try output.print(allocator, "Content-Length: {d}\r\nConnection: {s}\r\n\r\n", .{ response.body.len, if (keep_alive) "keep-alive" else "close" });
    try output.appendSlice(allocator, response.body);
    return output.toOwnedSlice(allocator);
}

pub fn encodeChunkedResponseAlloc(
    allocator: std.mem.Allocator,
    status: u16,
    headers: []const Http.Header,
    chunks: []const []const u8,
    keep_alive: bool,
) ![]u8 {
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);
    try output.print(allocator, "HTTP/1.1 {d} {s}\r\n", .{ status, reasonPhrase(status) });
    for (headers) |header| {
        if (!validHeaderName(header.name) or containsLineBreak(header.value)) return error.MalformedHeader;
        if (std.ascii.eqlIgnoreCase(header.name, "content-length") or
            std.ascii.eqlIgnoreCase(header.name, "transfer-encoding") or
            std.ascii.eqlIgnoreCase(header.name, "connection")) continue;
        try output.print(allocator, "{s}: {s}\r\n", .{ header.name, header.value });
    }
    try output.print(allocator, "Transfer-Encoding: chunked\r\nConnection: {s}\r\n\r\n", .{if (keep_alive) "keep-alive" else "close"});
    for (chunks) |chunk| {
        if (chunk.len == 0) continue;
        try output.print(allocator, "{x}\r\n", .{chunk.len});
        try output.appendSlice(allocator, chunk);
        try output.appendSlice(allocator, "\r\n");
    }
    try output.appendSlice(allocator, "0\r\n\r\n");
    return output.toOwnedSlice(allocator);
}

fn validHeaderName(value: []const u8) bool {
    return validToken(value);
}

fn validToken(value: []const u8) bool {
    if (value.len == 0) return false;
    for (value) |byte| {
        if (std.ascii.isAlphanumeric(byte) or std.mem.indexOfScalar(u8, "!#$%&'*+-.^_`|~", byte) != null) continue;
        return false;
    }
    return true;
}

fn validRequestTarget(value: []const u8) bool {
    if (value.len == 0) return false;
    for (value) |byte| if (byte < 0x21 or byte > 0x7e) return false;
    return true;
}

fn validHeaderValue(value: []const u8) bool {
    for (value) |byte| if ((byte < 0x20 and byte != '\t') or byte == 0x7f) return false;
    return true;
}

fn containsHeaderToken(value: []const u8, wanted: []const u8) bool {
    var tokens = std.mem.splitScalar(u8, value, ',');
    while (tokens.next()) |token| {
        if (std.ascii.eqlIgnoreCase(std.mem.trim(u8, token, " \t"), wanted)) return true;
    }
    return false;
}

fn containsLineBreak(value: []const u8) bool {
    return std.mem.indexOfScalar(u8, value, '\r') != null or std.mem.indexOfScalar(u8, value, '\n') != null;
}

fn reasonPhrase(status: u16) []const u8 {
    return switch (status) {
        200 => "OK",
        201 => "Created",
        204 => "No Content",
        400 => "Bad Request",
        401 => "Unauthorized",
        403 => "Forbidden",
        404 => "Not Found",
        408 => "Request Timeout",
        409 => "Conflict",
        413 => "Content Too Large",
        429 => "Too Many Requests",
        499 => "Client Closed Request",
        500 => "Internal Server Error",
        501 => "Not Implemented",
        503 => "Service Unavailable",
        else => "Unknown",
    };
}

test "HTTP request parser handles bounded headers body and keep alive" {
    const input = "POST /orders HTTP/1.1\r\nHost: localhost\r\nContent-Length: 5\r\n\r\nhelloextra";
    var parsed = try parseRequestAlloc(std.testing.allocator, input, .{});
    defer parsed.deinit(std.testing.allocator);
    try std.testing.expectEqualStrings("POST", parsed.request.method);
    try std.testing.expectEqualStrings("/orders", parsed.request.url);
    try std.testing.expectEqualStrings("hello", parsed.request.body);
    try std.testing.expect(parsed.keep_alive);
    try std.testing.expectEqual(input.len - "extra".len, parsed.consumed);
}

test "HTTP request parser rejects malformed incomplete and oversized input" {
    try std.testing.expectError(error.IncompleteRequest, parseRequestAlloc(std.testing.allocator, "GET / HTTP/1.1\r\n", .{}));
    try std.testing.expectError(error.MalformedRequestLine, parseRequestAlloc(std.testing.allocator, "GET / too many parts HTTP/1.1\r\n\r\n", .{}));
    try std.testing.expectError(error.BodyTooLarge, parseRequestAlloc(std.testing.allocator, "POST / HTTP/1.1\r\nHost: localhost\r\nContent-Length: 5\r\n\r\nhello", .{ .max_body_bytes = 4 }));
    try std.testing.expectError(error.UnsupportedTransferEncoding, parseRequestAlloc(std.testing.allocator, "POST / HTTP/1.1\r\nHost: localhost\r\nTransfer-Encoding: gzip\r\n\r\n", .{}));
}

test "HTTP request parser rejects request smuggling ambiguities and control bytes" {
    try std.testing.expectError(error.MissingHost, parseRequestAlloc(std.testing.allocator, "GET / HTTP/1.1\r\n\r\n", .{}));
    try std.testing.expectError(error.DuplicateHost, parseRequestAlloc(std.testing.allocator, "GET / HTTP/1.1\r\nHost: one\r\nHost: two\r\n\r\n", .{}));
    try std.testing.expectError(error.MalformedHeader, parseRequestAlloc(std.testing.allocator, "GET / HTTP/1.1\r\nHost : localhost\r\n\r\n", .{}));
    try std.testing.expectError(error.MalformedHeader, parseRequestAlloc(std.testing.allocator, "GET / HTTP/1.1\r\nHost: local\x00host\r\n\r\n", .{}));
    try std.testing.expectError(error.DuplicateTransferEncoding, parseRequestAlloc(std.testing.allocator, "POST / HTTP/1.1\r\nHost: localhost\r\nTransfer-Encoding: chunked\r\nTransfer-Encoding: identity\r\n\r\n0\r\n\r\n", .{}));
    try std.testing.expectError(error.ForbiddenTrailer, parseRequestAlloc(std.testing.allocator, "POST / HTTP/1.1\r\nHost: localhost\r\nTransfer-Encoding: chunked\r\n\r\n0\r\nContent-Length: 5\r\n\r\n", .{}));
}

test "HTTP request parser decodes chunked bodies and bounded trailers" {
    const input = "POST / HTTP/1.1\r\nHost: localhost\r\nTransfer-Encoding: chunked\r\n\r\n4\r\nWiki\r\n5\r\npedia\r\n0\r\nX-Trace: done\r\n\r\nextra";
    var parsed = try parseRequestAlloc(std.testing.allocator, input, .{});
    defer parsed.deinit(std.testing.allocator);
    try std.testing.expectEqualStrings("Wikipedia", parsed.request.body);
    try std.testing.expectEqual(input.len - "extra".len, parsed.consumed);
    try std.testing.expectError(error.ConflictingBodyFraming, parseRequestAlloc(std.testing.allocator, "POST / HTTP/1.1\r\nHost: localhost\r\nContent-Length: 1\r\nTransfer-Encoding: chunked\r\n\r\n0\r\n\r\n", .{}));
}

fn fuzzBoundedRequestParser(_: void, smith: *std.testing.Smith) !void {
    var input_buffer: [4096]u8 = undefined;
    const input = input_buffer[0..smith.slice(&input_buffer)];
    var parsed = parseRequestAlloc(std.testing.allocator, input, .{
        .max_request_line_bytes = 256,
        .max_header_bytes = 1024,
        .max_headers = 16,
        .max_body_bytes = 2048,
    }) catch return;
    defer parsed.deinit(std.testing.allocator);
    try std.testing.expect(parsed.consumed <= input.len);
    try std.testing.expect(parsed.request.headers.len <= 16);
    try std.testing.expect(parsed.request.body.len <= 2048);
    try std.testing.expect(!containsLineBreak(parsed.request.method));
}

test "HTTP parser fuzz target preserves framing and ownership bounds" {
    try std.testing.fuzz({}, fuzzBoundedRequestParser, .{});
}

test "HTTP response encoder owns framing and rejects header injection" {
    const encoded = try encodeResponseAlloc(std.testing.allocator, .{ .status = 200, .body = "ready" }, false);
    defer std.testing.allocator.free(encoded);
    try std.testing.expect(std.mem.indexOf(u8, encoded, "Content-Length: 5\r\n") != null);
    try std.testing.expect(std.mem.endsWith(u8, encoded, "\r\n\r\nready"));
    try std.testing.expectError(error.MalformedHeader, encodeResponseAlloc(std.testing.allocator, .{
        .status = 200,
        .headers = &.{.{ .name = "X-Test", .value = "ok\r\nInjected: yes" }},
    }, false));
}

test "HTTP chunked response encoder streams bounded chunks without content length" {
    const encoded = try encodeChunkedResponseAlloc(std.testing.allocator, 200, &.{}, &.{ "hello", " world" }, false);
    defer std.testing.allocator.free(encoded);
    try std.testing.expect(std.mem.indexOf(u8, encoded, "Transfer-Encoding: chunked\r\n") != null);
    try std.testing.expect(std.mem.endsWith(u8, encoded, "5\r\nhello\r\n6\r\n world\r\n0\r\n\r\n"));
    try std.testing.expect(std.mem.indexOf(u8, encoded, "Content-Length") == null);
}

test "HTTP server adapter carries content-addressed live conformance" {
    try capability.validate();
    try std.testing.expectEqual(zstd.Capability.Maturity.production_candidate, capability.maturity);
    try std.testing.expect(capability.conformance != null);
}

test "HTTP server accepts a real loopback connection" {
    const TestHandler = struct {
        fn handleAlloc(_: *@This(), allocator: std.mem.Allocator, request: Http.Request) !Http.Response {
            if (!std.mem.eql(u8, request.url, "/health")) return error.UnexpectedPath;
            return Http.cloneResponseAlloc(allocator, .{ .status = 200, .body = "ready" });
        }
    };
    const ServeContext = struct {
        server: *Server,
        report: ?ServeReport = null,
        failure: ?anyerror = null,

        fn run(self: *@This()) void {
            self.report = self.server.serveOne(std.testing.allocator) catch |err| {
                self.failure = err;
                return;
            };
        }
    };

    var handler_value = TestHandler{};
    var server: ?Server = null;
    var port: u16 = 19820;
    while (port < 19840) : (port += 1) {
        server = Server.init(std.testing.allocator, std.testing.io, .{ .port = port }, Handler.from(TestHandler, &handler_value)) catch |err| switch (err) {
            error.AddressInUse => continue,
            else => return err,
        };
        break;
    }
    if (server == null) return error.NoLoopbackPort;
    defer server.?.deinit();
    var context = ServeContext{ .server = &server.? };
    const thread = try std.Thread.spawn(.{}, ServeContext.run, .{&context});

    const address = try std.Io.net.IpAddress.parseIp4("127.0.0.1", port);
    var stream = try address.connect(std.testing.io, .{ .mode = .stream });
    defer stream.close(std.testing.io);
    try writeAll(stream, std.testing.io, "GET /health HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n");
    var response_buffer: [4096]u8 = undefined;
    var response_len: usize = 0;
    while (response_len < response_buffer.len) {
        var parts = [_][]u8{response_buffer[response_len..]};
        const count = try std.testing.io.vtable.netRead(std.testing.io.userdata, stream.socket.handle, &parts);
        if (count == 0) break;
        response_len += count;
    }
    thread.join();
    if (context.failure) |err| return err;
    try std.testing.expectEqual(@as(u16, 200), context.report.?.status);
    try std.testing.expect(std.mem.indexOf(u8, response_buffer[0..response_len], "HTTP/1.1 200 OK") != null);
    try std.testing.expect(std.mem.endsWith(u8, response_buffer[0..response_len], "ready"));
}

test "HTTP server delegates accepted sockets through the TLS provider contract" {
    const PassthroughProvider = struct {
        io: std.Io,
        handshakes: usize = 0,

        const Stream = struct {
            io: std.Io,
            handle: std.Io.net.Socket.Handle,
        };

        pub fn handshakeAlloc(self: *@This(), allocator: std.mem.Allocator, handle: std.Io.net.Socket.Handle) !Tls.Connection {
            self.handshakes += 1;
            const stream = try allocator.create(Stream);
            stream.* = .{ .io = self.io, .handle = handle };
            return .{
                .pointer = stream,
                .read_fn = read,
                .write_fn = write,
                .close_fn = close,
                .deinit_fn = deinit,
            };
        }

        fn read(pointer: *anyopaque, buffer: []u8) !usize {
            const stream: *Stream = @ptrCast(@alignCast(pointer));
            var parts = [_][]u8{buffer};
            return stream.io.vtable.netRead(stream.io.userdata, stream.handle, &parts);
        }

        fn write(pointer: *anyopaque, bytes: []const u8) !void {
            const stream: *Stream = @ptrCast(@alignCast(pointer));
            var offset: usize = 0;
            while (offset < bytes.len) {
                const parts = [_][]const u8{bytes[offset..]};
                const count = try stream.io.vtable.netWrite(stream.io.userdata, stream.handle, "", &parts, 1);
                if (count == 0) return error.WriteZero;
                offset += count;
            }
        }

        fn close(_: *anyopaque) void {}

        fn deinit(pointer: *anyopaque, allocator: std.mem.Allocator) void {
            const stream: *Stream = @ptrCast(@alignCast(pointer));
            allocator.destroy(stream);
        }
    };
    const HandlerValue = struct {
        fn handleAlloc(_: *@This(), allocator: std.mem.Allocator, _: Http.Request) !Http.Response {
            return Http.cloneResponseAlloc(allocator, .{ .status = 200, .body = "provider-ok" });
        }
    };
    const Context = struct {
        server: *Server,
        failure: ?anyerror = null,
        fn run(self: *@This()) void {
            _ = self.server.serveOne(std.testing.allocator) catch |err| {
                self.failure = err;
                return;
            };
        }
    };

    var provider = PassthroughProvider{ .io = std.testing.io };
    var handler_value = HandlerValue{};
    var server = try testServerWithOptions(std.testing.allocator, std.testing.io, 19820, 19840, .{
        .port = 0,
        .tls_provider = Tls.Provider.from(PassthroughProvider, &provider),
    }, Handler.from(HandlerValue, &handler_value));
    defer server.deinit();
    var context = Context{ .server = &server };
    const thread = try std.Thread.spawn(.{}, Context.run, .{&context});
    var stream = try serverAddress(server).connect(std.testing.io, .{ .mode = .stream });
    defer stream.close(std.testing.io);
    try writeAll(stream, std.testing.io, "GET / HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n");
    const response = try readToCloseAlloc(std.testing.allocator, stream, std.testing.io, 4096);
    defer std.testing.allocator.free(response);
    thread.join();
    if (context.failure) |err| return err;
    try std.testing.expectEqual(@as(usize, 1), provider.handshakes);
    try std.testing.expect(std.mem.endsWith(u8, response, "provider-ok"));
}

test "HTTP TLS handshake deadline closes a stalled peer boundedly" {
    const SlowProvider = struct {
        io: std.Io,

        pub fn handshakeAlloc(self: *@This(), _: std.mem.Allocator, handle: std.Io.net.Socket.Handle) !Tls.Connection {
            var byte: [1]u8 = undefined;
            var parts = [_][]u8{&byte};
            _ = try self.io.vtable.netRead(self.io.userdata, handle, &parts);
            return error.UnexpectedHandshakeData;
        }
    };
    const HandlerValue = struct {
        fn handleAlloc(_: *@This(), allocator: std.mem.Allocator, _: Http.Request) !Http.Response {
            return Http.cloneResponseAlloc(allocator, .{ .status = 204 });
        }
    };
    const Context = struct {
        server: *Server,
        failure: ?anyerror = null,
        fn run(self: *@This()) void {
            _ = self.server.serveOne(std.testing.allocator) catch |err| {
                self.failure = err;
                return;
            };
        }
    };

    var provider = SlowProvider{ .io = std.testing.io };
    var handler_value = HandlerValue{};
    var server = try testServerWithOptions(std.testing.allocator, std.testing.io, 19840, 19860, .{
        .port = 0,
        .tls_provider = Tls.Provider.from(SlowProvider, &provider),
        .tls_handshake_deadline_ms = 5,
    }, Handler.from(HandlerValue, &handler_value));
    defer server.deinit();
    var context = Context{ .server = &server };
    const thread = try std.Thread.spawn(.{}, Context.run, .{&context});
    var stream = try serverAddress(server).connect(std.testing.io, .{ .mode = .stream });
    defer stream.close(std.testing.io);
    thread.join();
    try std.testing.expectEqual(error.TlsHandshakeTimeout, context.failure.?);
    try std.testing.expectEqual(@as(usize, 0), server.activeConnections());
}

test "HTTP performs a live WebSocket upgrade echo and close session" {
    const Echo = struct {
        pub fn accepts(_: *@This(), request: Http.Request) bool {
            return std.mem.eql(u8, request.url, "/ws");
        }

        pub fn handleAlloc(_: *@This(), allocator: std.mem.Allocator, _: Http.Request, frame: WebSocket.Frame) !?WebSocket.Message {
            return .{ .opcode = frame.opcode, .payload = try allocator.dupe(u8, frame.payload) };
        }
    };
    const Fallback = struct {
        fn handleAlloc(_: *@This(), allocator: std.mem.Allocator, _: Http.Request) !Http.Response {
            return Http.cloneResponseAlloc(allocator, .{ .status = 404 });
        }
    };
    const Context = struct {
        server: *Server,
        report: ?ServeReport = null,
        failure: ?anyerror = null,
        fn run(self: *@This()) void {
            self.report = self.server.serveOne(std.testing.allocator) catch |err| {
                self.failure = err;
                return;
            };
        }
    };

    var echo = Echo{};
    var fallback = Fallback{};
    var server = try testServerWithOptions(std.testing.allocator, std.testing.io, 19860, 19880, .{
        .port = 0,
        .websocket_handler = WebSocket.Handler.from(Echo, &echo),
    }, Handler.from(Fallback, &fallback));
    defer server.deinit();
    var context = Context{ .server = &server };
    const thread = try std.Thread.spawn(.{}, Context.run, .{&context});
    var stream = try serverAddress(server).connect(std.testing.io, .{ .mode = .stream });
    defer stream.close(std.testing.io);
    const request = "GET /ws HTTP/1.1\r\n" ++
        "Host: localhost\r\n" ++
        "Upgrade: websocket\r\n" ++
        "Connection: Upgrade\r\n" ++
        "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\n" ++
        "Sec-WebSocket-Version: 13\r\n\r\n";
    const text_frame = [_]u8{ 0x81, 0x85, 0x37, 0xfa, 0x21, 0x3d, 0x7f, 0x9f, 0x4d, 0x51, 0x58 };
    const close_frame = [_]u8{ 0x88, 0x80, 0x01, 0x02, 0x03, 0x04 };
    try writeAll(stream, std.testing.io, request);
    try writeAll(stream, std.testing.io, &text_frame);
    try writeAll(stream, std.testing.io, &close_frame);
    const response = try readToCloseAlloc(std.testing.allocator, stream, std.testing.io, 4096);
    defer std.testing.allocator.free(response);
    thread.join();
    if (context.failure) |err| return err;
    try std.testing.expectEqual(@as(u16, 101), context.report.?.status);
    try std.testing.expect(std.mem.indexOf(u8, response, "HTTP/1.1 101 Switching Protocols") != null);
    try std.testing.expect(std.mem.indexOf(u8, response, &.{ 0x81, 0x05, 'H', 'e', 'l', 'l', 'o' }) != null);
    try std.testing.expect(std.mem.endsWith(u8, response, &.{ 0x88, 0x00 }));
}

test "HTTP handler adapts typed router results without leaking sidecar receipts" {
    const Router = struct {
        fn handleAlloc(_: *@This(), allocator: std.mem.Allocator, _: Http.Request) !Http.RouteResult {
            return .{
                .response = try Http.cloneResponseAlloc(allocator, .{ .status = 201, .body = "created" }),
                .receipt_json = try allocator.dupe(u8, "{}"),
                .trace_json = try allocator.dupe(u8, "{}"),
            };
        }
    };
    var router = Router{};
    var response = try Handler.fromRouter(Router, &router).handleAlloc(std.testing.allocator, .{ .method = "POST", .url = "/orders" });
    defer response.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(u16, 201), response.status);
    try std.testing.expectEqualStrings("created", response.body);
}

test "HTTP keep alive preserves pipelined bytes across requests" {
    const CountingHandler = struct {
        count: usize = 0,

        fn handleAlloc(self: *@This(), allocator: std.mem.Allocator, _: Http.Request) !Http.Response {
            self.count += 1;
            return Http.cloneResponseAlloc(allocator, .{ .status = 200, .body = "ok" });
        }
    };
    const Context = struct {
        server: *Server,
        report: ?ServeReport = null,
        failure: ?anyerror = null,
        fn run(self: *@This()) void {
            self.report = self.server.serveOne(std.testing.allocator) catch |err| {
                self.failure = err;
                return;
            };
        }
    };

    var handler_value = CountingHandler{};
    var server = try testServer(std.testing.allocator, std.testing.io, 19840, 19860, .{
        .max_requests_per_connection = 2,
    }, Handler.from(CountingHandler, &handler_value));
    defer server.deinit();
    var context = Context{ .server = &server };
    const thread = try std.Thread.spawn(.{}, Context.run, .{&context});
    var stream = try serverAddress(server).connect(std.testing.io, .{ .mode = .stream });
    defer stream.close(std.testing.io);
    try writeAll(stream, std.testing.io, "GET /one HTTP/1.1\r\nHost: localhost\r\n\r\n" ++
        "GET /two HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n");
    const response = try readToCloseAlloc(std.testing.allocator, stream, std.testing.io, 8192);
    defer std.testing.allocator.free(response);
    thread.join();
    if (context.failure) |err| return err;
    try std.testing.expectEqual(@as(usize, 2), context.report.?.requests);
    try std.testing.expectEqual(@as(usize, 2), handler_value.count);
    try std.testing.expectEqual(@as(usize, 2), std.mem.count(u8, response, "HTTP/1.1 200 OK"));
}

test "HTTP supervisor bounds concurrent accepted connections and drain closes readiness" {
    const HandlerValue = struct {
        fn handleAlloc(_: *@This(), allocator: std.mem.Allocator, _: Http.Request) !Http.Response {
            return Http.cloneResponseAlloc(allocator, .{ .status = 204 });
        }
    };
    const Context = struct {
        server: *Server,
        report: ?SupervisorReport = null,
        failure: ?anyerror = null,
        fn run(self: *@This()) void {
            self.report = self.server.serveConnections(std.testing.allocator, 2) catch |err| {
                self.failure = err;
                return;
            };
        }
    };

    var handler_value = HandlerValue{};
    var server = try testServer(std.testing.allocator, std.testing.io, 19860, 19880, .{ .max_connections = 2 }, Handler.from(HandlerValue, &handler_value));
    defer server.deinit();
    var context = Context{ .server = &server };
    const thread = try std.Thread.spawn(.{}, Context.run, .{&context});
    var first = try serverAddress(server).connect(std.testing.io, .{ .mode = .stream });
    defer first.close(std.testing.io);
    var second = try serverAddress(server).connect(std.testing.io, .{ .mode = .stream });
    defer second.close(std.testing.io);
    try writeAll(first, std.testing.io, "GET / HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n");
    try writeAll(second, std.testing.io, "GET / HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n");
    const first_response = try readToCloseAlloc(std.testing.allocator, first, std.testing.io, 4096);
    defer std.testing.allocator.free(first_response);
    const second_response = try readToCloseAlloc(std.testing.allocator, second, std.testing.io, 4096);
    defer std.testing.allocator.free(second_response);
    thread.join();
    if (context.failure) |err| return err;
    try std.testing.expectEqual(@as(usize, 2), context.report.?.accepted);
    try std.testing.expectEqual(@as(usize, 2), context.report.?.completed);
    try std.testing.expectEqual(@as(usize, 2), context.report.?.peak_in_flight);
    try server.drain();
    try std.testing.expect(!server.snapshot().readiness);
    try std.testing.expectError(error.ServerNotReady, server.serveOne(std.testing.allocator));
}

test "HTTP shutdown drains accepted work before the deadline" {
    const BlockingHandler = struct {
        entered: *std.atomic.Value(bool),
        release: *std.atomic.Value(bool),

        fn handleAlloc(self: *@This(), allocator: std.mem.Allocator, _: Http.Request) !Http.Response {
            self.entered.store(true, .release);
            while (!self.release.load(.acquire)) std.Thread.yield() catch {};
            return Http.cloneResponseAlloc(allocator, .{ .status = 204 });
        }
    };
    const Context = struct {
        server: *Server,
        report: ?ServeReport = null,
        failure: ?anyerror = null,
        fn run(self: *@This()) void {
            self.report = self.server.serveOne(std.testing.allocator) catch |err| {
                self.failure = err;
                return;
            };
        }
    };
    const Releaser = struct {
        release: *std.atomic.Value(bool),
        fn run(self: *@This()) void {
            sleepMilliseconds(std.testing.io, 2) catch {};
            self.release.store(true, .release);
        }
    };

    var entered = std.atomic.Value(bool).init(false);
    var release = std.atomic.Value(bool).init(false);
    var handler_value = BlockingHandler{ .entered = &entered, .release = &release };
    var server = try testServer(std.testing.allocator, std.testing.io, 19900, 19920, .{}, Handler.from(BlockingHandler, &handler_value));
    defer server.deinit();
    var context = Context{ .server = &server };
    const server_thread = try std.Thread.spawn(.{}, Context.run, .{&context});
    var stream = try serverAddress(server).connect(std.testing.io, .{ .mode = .stream });
    defer stream.close(std.testing.io);
    try writeAll(stream, std.testing.io, "GET / HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n");
    while (!entered.load(.acquire)) std.Thread.yield() catch {};
    var releaser = Releaser{ .release = &release };
    const release_thread = try std.Thread.spawn(.{}, Releaser.run, .{&releaser});
    const shutdown_report = try server.shutdown(.{ .deadline_ms = 100, .poll_interval_ms = 1 });
    release_thread.join();
    server_thread.join();
    if (context.failure) |err| return err;
    try std.testing.expect(shutdown_report.drained);
    try std.testing.expect(!shutdown_report.forced);
    try std.testing.expectEqual(@as(usize, 0), shutdown_report.active_remaining);
    try std.testing.expectEqual(zstd.Application.Lifecycle.State.stopped, server.snapshot().state);
}

test "HTTP shutdown force-stops blocked connections at the deadline" {
    const HandlerValue = struct {
        fn handleAlloc(_: *@This(), allocator: std.mem.Allocator, _: Http.Request) !Http.Response {
            return Http.cloneResponseAlloc(allocator, .{ .status = 204 });
        }
    };
    const Context = struct {
        server: *Server,
        failure: ?anyerror = null,
        fn run(self: *@This()) void {
            _ = self.server.serveOne(std.testing.allocator) catch |err| {
                self.failure = err;
                return;
            };
        }
    };

    var handler_value = HandlerValue{};
    var server = try testServer(std.testing.allocator, std.testing.io, 19920, 19940, .{}, Handler.from(HandlerValue, &handler_value));
    defer server.deinit();
    var context = Context{ .server = &server };
    const server_thread = try std.Thread.spawn(.{}, Context.run, .{&context});
    var stream = try serverAddress(server).connect(std.testing.io, .{ .mode = .stream });
    defer stream.close(std.testing.io);
    try writeAll(stream, std.testing.io, "POST / HTTP/1.1\r\nHost: localhost\r\nContent-Length: 10\r\n\r\npart");
    while (server.activeConnections() == 0) std.Thread.yield() catch {};
    const shutdown_report = try server.shutdown(.{ .deadline_ms = 2, .poll_interval_ms = 1 });
    server_thread.join();
    try std.testing.expect(shutdown_report.forced);
    try std.testing.expectEqual(@as(usize, 0), shutdown_report.active_remaining);
    try std.testing.expectEqual(zstd.Application.Lifecycle.State.forced_stopped, server.snapshot().state);
    try std.testing.expect(context.failure != null);
}

test "HTTP request deadline returns a bounded structured timeout response" {
    const HandlerValue = struct {
        fn handleAlloc(_: *@This(), allocator: std.mem.Allocator, _: Http.Request) !Http.Response {
            return Http.cloneResponseAlloc(allocator, .{ .status = 204 });
        }
    };
    const Context = struct {
        server: *Server,
        report: ?ServeReport = null,
        failure: ?anyerror = null,
        fn run(self: *@This()) void {
            self.report = self.server.serveOne(std.testing.allocator) catch |err| {
                self.failure = err;
                return;
            };
        }
    };

    var handler_value = HandlerValue{};
    var server = try testServer(std.testing.allocator, std.testing.io, 19940, 19960, .{ .request_deadline_ms = 5 }, Handler.from(HandlerValue, &handler_value));
    defer server.deinit();
    var context = Context{ .server = &server };
    const server_thread = try std.Thread.spawn(.{}, Context.run, .{&context});
    var stream = try serverAddress(server).connect(std.testing.io, .{ .mode = .stream });
    defer stream.close(std.testing.io);
    try writeAll(stream, std.testing.io, "POST / HTTP/1.1\r\nHost: localhost\r\nContent-Length: 10\r\n\r\npart");
    const response = try readToCloseAlloc(std.testing.allocator, stream, std.testing.io, 4096);
    defer std.testing.allocator.free(response);
    server_thread.join();
    if (context.failure) |err| return err;
    try std.testing.expectEqual(@as(u16, 408), context.report.?.status);
    try std.testing.expect(std.mem.indexOf(u8, response, "HTTP/1.1 408 Request Timeout") != null);
    try std.testing.expect(std.mem.endsWith(u8, response, "RequestTimeout"));
}

fn testServer(
    allocator: std.mem.Allocator,
    io: std.Io,
    first_port: u16,
    end_port: u16,
    partial: struct { max_connections: usize = 64, max_requests_per_connection: usize = 100, request_deadline_ms: ?u64 = 30_000 },
    handler: Handler,
) !Server {
    var port = first_port;
    while (port < end_port) : (port += 1) {
        return Server.init(allocator, io, .{
            .port = port,
            .max_connections = partial.max_connections,
            .max_requests_per_connection = partial.max_requests_per_connection,
            .request_deadline_ms = partial.request_deadline_ms,
        }, handler) catch |err| switch (err) {
            error.AddressInUse => continue,
            else => return err,
        };
    }
    return error.NoLoopbackPort;
}

fn testServerWithOptions(
    allocator: std.mem.Allocator,
    io: std.Io,
    first_port: u16,
    end_port: u16,
    options: ServerOptions,
    handler: Handler,
) !Server {
    var candidate = options;
    var port = first_port;
    while (port < end_port) : (port += 1) {
        candidate.port = port;
        return Server.init(allocator, io, candidate, handler) catch |err| switch (err) {
            error.AddressInUse => continue,
            else => return err,
        };
    }
    return error.NoLoopbackPort;
}

fn serverAddress(server: Server) std.Io.net.IpAddress {
    return std.Io.net.IpAddress.parseIp4(server.options.host, server.options.port) catch unreachable;
}

fn readToCloseAlloc(allocator: std.mem.Allocator, stream: std.Io.net.Stream, io: std.Io, limit: usize) ![]u8 {
    const buffer = try allocator.alloc(u8, limit);
    errdefer allocator.free(buffer);
    var length: usize = 0;
    while (length < buffer.len) {
        var parts = [_][]u8{buffer[length..]};
        const count = try io.vtable.netRead(io.userdata, stream.socket.handle, &parts);
        if (count == 0) return allocator.realloc(buffer, length);
        length += count;
    }
    allocator.free(buffer);
    return error.ResponseTooLarge;
}

test "HTTP codec survives every allocation failure" {
    const Harness = struct {
        fn parse(allocator: std.mem.Allocator) !void {
            var parsed = try parseRequestAlloc(allocator, "POST / HTTP/1.1\r\nHost: localhost\r\nContent-Length: 2\r\n\r\nok", .{});
            defer parsed.deinit(allocator);
        }
        fn encode(allocator: std.mem.Allocator) !void {
            const encoded = try encodeResponseAlloc(allocator, .{ .status = 200, .body = "ok" }, false);
            defer allocator.free(encoded);
        }
    };
    try std.testing.checkAllAllocationFailures(std.testing.allocator, Harness.parse, .{});
    try std.testing.checkAllAllocationFailures(std.testing.allocator, Harness.encode, .{});
}

test "HTTP policy middleware adds request trace security CORS and negotiation headers" {
    const Inner = struct {
        fn handleAlloc(_: *@This(), allocator: std.mem.Allocator, _: Http.Request) !Http.Response {
            return Http.cloneResponseAlloc(allocator, .{ .status = 200, .body = "ok" });
        }
    };
    var inner = Inner{};
    var policy = try PolicyHandler.init(Handler.from(Inner, &inner), .{ .cors_allow_origin = "https://app.example" });
    var response = try policy.handleAlloc(std.testing.allocator, .{
        .method = "GET",
        .url = "/",
        .headers = &.{
            .{ .name = "traceparent", .value = "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01" },
            .{ .name = "Accept-Encoding", .value = "gzip, br" },
        },
    });
    defer response.deinit(std.testing.allocator);
    try std.testing.expect(requestHeader(.{ .method = "GET", .url = "/", .headers = response.headers }, "X-Request-Id") != null);
    try std.testing.expectEqualStrings("DENY", requestHeader(.{ .method = "GET", .url = "/", .headers = response.headers }, "X-Frame-Options").?);
    try std.testing.expectEqualStrings("https://app.example", requestHeader(.{ .method = "GET", .url = "/", .headers = response.headers }, "Access-Control-Allow-Origin").?);
    try std.testing.expectEqualStrings("identity", requestHeader(.{ .method = "GET", .url = "/", .headers = response.headers }, "X-ZigEffect-Compression").?);
    try std.testing.expect(requestHeader(.{ .method = "GET", .url = "/", .headers = response.headers }, "traceparent") != null);
}

test "HTTP policy guards map classified authorization and capacity failures" {
    const Inner = struct {
        fn handleAlloc(_: *@This(), allocator: std.mem.Allocator, _: Http.Request) !Http.Response {
            return Http.cloneResponseAlloc(allocator, .{ .status = 200 });
        }
    };
    const Deny = struct {
        class: zstd.External.Class,
        fn check(self: *@This(), _: Http.Request) ?zstd.External.Failure {
            return .init("guard", "request", self.class, "denied", "policy");
        }
    };
    var inner = Inner{};
    var unauthorized = Deny{ .class = .unauthorized };
    var policy = try PolicyHandler.init(Handler.from(Inner, &inner), .{ .guards = &.{Guard.from(Deny, &unauthorized)} });
    var response = try policy.handleAlloc(std.testing.allocator, .{ .method = "GET", .url = "/" });
    defer response.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(u16, 401), response.status);

    var capacity = Deny{ .class = .capacity };
    policy = try PolicyHandler.init(Handler.from(Inner, &inner), .{ .guards = &.{Guard.from(Deny, &capacity)} });
    var limited = try policy.handleAlloc(std.testing.allocator, .{ .method = "GET", .url = "/" });
    defer limited.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(u16, 429), limited.status);
}

test "guarded application map handler exposes one bounded managed runtime snapshot" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const MapService = zstd.fx.kernel.Service("http-test/MapService", struct { value: u32 });
    const Access = struct {
        allowed: bool,

        fn check(self: *@This(), _: Http.Request) ?zstd.External.Failure {
            if (self.allowed) return null;
            return .init("application-map", "inspect", .unauthorized, "denied", "policy");
        }
    };

    const layer = zstd.fx.kernel.Layer.succeed(MapService, .{ .value = 1 });
    var runtime = try zstd.ManagedRuntime(@TypeOf(layer)).make(
        std.testing.allocator,
        std.testing.io,
        tmp.dir,
        layer,
        .{},
    );
    defer runtime.deinit();

    var access = Access{ .allowed = true };
    var map = try ApplicationMapHandler(@TypeOf(runtime)).init(
        &runtime,
        "/_zigeffect/application",
        Guard.from(Access, &access),
        .{ .max_recent_events = 16, .max_response_bytes = 128 * 1024 },
    );
    var response = try map.handleAlloc(std.testing.allocator, .{
        .method = "GET",
        .url = "/_zigeffect/application",
    });
    defer response.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(u16, 200), response.status);
    try std.testing.expectEqualStrings("application/json", response.header("content-type").?);
    try std.testing.expect(std.mem.indexOf(u8, response.body, MapService.service_key) != null);
    try std.testing.expect(std.mem.indexOf(u8, response.body, "nendb_embedded") != null);
    try std.testing.expect(std.mem.indexOf(u8, response.body, zstd.CausalRuntime.agent_map_schema) != null);
    var parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, response.body, .{});
    defer parsed.deinit();

    access.allowed = false;
    var denied = try map.handleAlloc(std.testing.allocator, .{
        .method = "GET",
        .url = "/_zigeffect/application",
    });
    defer denied.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(u16, 401), denied.status);
}

test "runtime application map slot binds the layered handler to the owning managed runtime" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const MapService = zstd.fx.kernel.Service("http-test/SlotMapService", struct { value: u32 });
    const Access = struct {
        fn check(_: *@This(), _: Http.Request) ?zstd.External.Failure {
            return null;
        }
    };

    var slot = ApplicationMapSlot{};
    var access = Access{};
    var map = try RuntimeApplicationMapHandler.init(
        &slot,
        "/.well-known/zigeffect/application-map",
        Guard.from(Access, &access),
        .{ .max_recent_events = 16, .max_response_bytes = 128 * 1024 },
    );

    var unavailable = try map.handleAlloc(std.testing.allocator, .{
        .method = "GET",
        .url = "/.well-known/zigeffect/application-map",
    });
    defer unavailable.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(u16, 503), unavailable.status);

    const layer = zstd.fx.kernel.Layer.succeed(MapService, .{ .value = 1 });
    var runtime = try zstd.ManagedRuntime(@TypeOf(layer)).make(
        std.testing.allocator,
        std.testing.io,
        tmp.dir,
        layer,
        .{},
    );
    defer runtime.deinit();
    try slot.install(@TypeOf(runtime), &runtime);
    defer slot.clear();

    var response = try map.handleAlloc(std.testing.allocator, .{
        .method = "GET",
        .url = "/.well-known/zigeffect/application-map",
    });
    defer response.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(u16, 200), response.status);
    try std.testing.expect(std.mem.indexOf(u8, response.body, MapService.service_key) != null);
    try std.testing.expect(std.mem.indexOf(u8, response.body, "nendb_embedded") != null);

    slot.clear();
    var cleared = try map.handleAlloc(std.testing.allocator, .{
        .method = "GET",
        .url = "/.well-known/zigeffect/application-map",
    });
    defer cleared.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(u16, 503), cleared.status);
}

test "HTTP policy middleware survives every allocation failure" {
    const Inner = struct {
        fn handleAlloc(_: *@This(), allocator: std.mem.Allocator, _: Http.Request) !Http.Response {
            return Http.cloneResponseAlloc(allocator, .{
                .status = 200,
                .headers = &.{.{ .name = "Content-Type", .value = "application/json" }},
                .body = "{}",
            });
        }
    };
    const Harness = struct {
        fn run(allocator: std.mem.Allocator) !void {
            var inner = Inner{};
            var policy = try PolicyHandler.init(Handler.from(Inner, &inner), .{ .cors_allow_origin = "https://app.example" });
            var response = try policy.handleAlloc(allocator, .{
                .method = "GET",
                .url = "/",
                .headers = &.{.{ .name = "Accept-Encoding", .value = "gzip" }},
            });
            defer response.deinit(allocator);
        }
    };
    try std.testing.checkAllAllocationFailures(std.testing.allocator, Harness.run, .{});
}

/// Application configuration for a scope-owned HTTP server. The handler is a
/// separate service so application and test layers can replace it independently.
pub const ServerLayerConfig = struct {
    io: std.Io,
    options: ServerOptions,
};
pub const ServerConfigService = zstd.fx.kernel.Service("zigeffect/http/ServerConfig", ServerLayerConfig);
pub const HandlerService = zstd.fx.kernel.Service("zigeffect/http/Handler", Handler);

pub const ServerApi = struct {
    pub const operations: []const []const u8 = &.{ "HttpServer.serveOne", "HttpServer.drain", "HttpServer.shutdown", "HttpServer.snapshot" };
    server: Server,
};
pub const ServerService = zstd.fx.kernel.Service("zigeffect/http/Server", ServerApi);

pub fn serverConfigLayer(config: ServerLayerConfig) @TypeOf(zstd.fx.kernel.Layer.succeed(ServerConfigService, config)) {
    return zstd.fx.kernel.Layer.succeed(ServerConfigService, config);
}

pub fn handlerLayer(handler: Handler) @TypeOf(zstd.fx.kernel.Layer.succeed(HandlerService, handler)) {
    return zstd.fx.kernel.Layer.succeed(HandlerService, handler);
}

const ServerLifecycle = struct {
    fn acquire(ctx: *zstd.fx.kernel.ContextView(.{ ServerConfigService, HandlerService })) anyerror!ServerApi {
        const config = ctx.service(ServerConfigService);
        return .{ .server = try Server.init(ctx.allocator(), config.io, config.options, ctx.service(HandlerService).*) };
    }

    fn release(api: *ServerApi) void {
        api.server.drain() catch {};
        api.server.deinit();
    }
};

pub fn serverLayer() @TypeOf(zstd.fx.kernel.Layer.scoped(
    ServerService,
    anyerror,
    .{ ServerConfigService, HandlerService },
    ServerLifecycle.acquire,
    ServerLifecycle.release,
)) {
    return zstd.fx.kernel.Layer.scoped(
        ServerService,
        anyerror,
        .{ ServerConfigService, HandlerService },
        ServerLifecycle.acquire,
        ServerLifecycle.release,
    );
}

pub fn configuredServerLayer(config: ServerLayerConfig, handler: Handler) @TypeOf(
    serverLayer().provideMerge(handlerLayer(handler).provideMerge(serverConfigLayer(config))),
) {
    return serverLayer().provideMerge(handlerLayer(handler).provideMerge(serverConfigLayer(config)));
}

pub const ServeOneEffect = zstd.fx.kernel.Effect(ServeReport, anyerror, .{ServerService});
pub fn serveOneEffect() ServeOneEffect {
    return ServeOneEffect.fromFn(struct {
        fn run(ctx: *ServeOneEffect.Context) anyerror!ServeReport {
            const operation = zstd.Service.beginOperation(ctx, ServerService.service_key, "http.server.serve-one", "serving one bounded connection");
            const report = ctx.service(ServerService).server.serveOne(ctx.allocator()) catch |err| {
                _ = zstd.Service.completeOperation(ctx, operation, "failure", @errorName(err));
                return err;
            };
            _ = zstd.Service.completeOperation(ctx, operation, "success", "served one bounded connection");
            return report;
        }
    }.run);
}

pub const DrainServerEffect = zstd.fx.kernel.Effect(void, anyerror, .{ServerService});
pub fn drainServerEffect() DrainServerEffect {
    return DrainServerEffect.fromFn(struct {
        fn run(ctx: *DrainServerEffect.Context) anyerror!void {
            const operation = zstd.Service.beginOperation(ctx, ServerService.service_key, "http.server.drain", "draining HTTP listener");
            ctx.service(ServerService).server.drain() catch |err| {
                _ = zstd.Service.completeOperation(ctx, operation, "failure", @errorName(err));
                return err;
            };
            _ = zstd.Service.completeOperation(ctx, operation, "success", "listener stopped accepting connections");
        }
    }.run);
}

pub const ShutdownServerEffect = zstd.fx.kernel.Effect(ShutdownReport, anyerror, .{ServerService}).Stateful(ShutdownOptions);
pub fn shutdownServerEffect(options: ShutdownOptions) ShutdownServerEffect {
    return ShutdownServerEffect.init(options, struct {
        fn run(value: ShutdownOptions, ctx: *ShutdownServerEffect.Context) anyerror!ShutdownReport {
            const operation = zstd.Service.beginOperation(ctx, ServerService.service_key, "http.server.shutdown", "shutting down HTTP server scope");
            const report = ctx.service(ServerService).server.shutdown(value) catch |err| {
                _ = zstd.Service.completeOperation(ctx, operation, "failure", @errorName(err));
                return err;
            };
            _ = zstd.Service.completeOperation(ctx, operation, "success", "server scope drained");
            return report;
        }
    }.run);
}
