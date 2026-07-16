const std = @import("std");
const zstd = @import("zigeffect_std");
pub const fx = zstd.fx;

pub const capability = zstd.Capability.Descriptor{
    .id = "zigeffect-transport.tcp-tls",
    .kind = .cluster_transport,
    .maturity = .production_candidate,
    .package = "zigeffect-transport",
    .version = "0.1.0",
    .features = &.{ "real-tcp", "tls1.2", "tls1.3", "peer-verification", "mutual-tls", "bounded-framing", "request-deadlines", "credential-rotation", "endpoint-discovery", "connection-pooling", "graceful-drain" },
    .side_effects = .real,
    .conformance = .{ .schema = "zigeffect.transport-live-conformance", .version = 1, .receipt = "conformance/tls-process-live.v1.json", .authority = .live_external, .observed_at_ms = 1783777336000, .valid_until_ms = 1791553336000, .content_sha256 = "sha256:6a324a28a11126e4481e7733a69a4ef613ca9e9982668f4b5f13662765c85bf0" },
    .limitations = &.{
        "requires a compatible system OpenSSL 3 installation",
        "service discovery is supplied by the caller",
    },
};

pub const Handler = struct {
    pointer: *anyopaque,
    handle_fn: *const fn (*anyopaque, std.mem.Allocator, fx.ClusterTransportRequest) anyerror!fx.ClusterTransportResponse,

    pub fn from(comptime HandlerType: type, handler: *HandlerType) Handler {
        return .{
            .pointer = handler,
            .handle_fn = struct {
                fn handle(pointer: *anyopaque, allocator: std.mem.Allocator, request: fx.ClusterTransportRequest) anyerror!fx.ClusterTransportResponse {
                    return (@as(*HandlerType, @ptrCast(@alignCast(pointer)))).handleAlloc(allocator, request);
                }
            }.handle,
        };
    }

    pub fn handleAlloc(self: Handler, allocator: std.mem.Allocator, request: fx.ClusterTransportRequest) !fx.ClusterTransportResponse {
        return self.handle_fn(self.pointer, allocator, request);
    }
};

pub const StorageHandler = struct {
    inner: fx.InProcessClusterTransport,

    pub fn init(allocator: std.mem.Allocator, storage: fx.MessageStorage, shard_count: fx.ShardCount) !StorageHandler {
        return .{ .inner = try fx.InProcessClusterTransport.init(allocator, storage, .{ .shard_count = shard_count }) };
    }

    pub fn deinit(self: *StorageHandler) void {
        self.inner.deinit();
    }

    pub fn handleAlloc(self: *StorageHandler, allocator: std.mem.Allocator, request: fx.ClusterTransportRequest) !fx.ClusterTransportResponse {
        var response = try self.inner.send(allocator, request);
        response.transport = .production_socket;
        return response;
    }
};

pub const Auth = struct {
    mode: fx.ClusterTransportAuthMode = .none,
    credential: []const u8 = "",
};

pub const Limits = struct {
    max_frame_bytes: usize = 1024 * 1024,
    max_in_flight: usize = 1024,
    max_requests_per_connection: usize = 100,

    pub fn validate(self: Limits) !void {
        if (self.max_frame_bytes == 0 or self.max_in_flight == 0 or self.max_requests_per_connection == 0) return error.InvalidTransportLimits;
    }
};

const SSL_METHOD = opaque {};
const SSL_CTX = opaque {};
const SSL = opaque {};
extern fn TLS_server_method() ?*const SSL_METHOD;
extern fn TLS_client_method() ?*const SSL_METHOD;
extern fn SSL_CTX_new(method: *const SSL_METHOD) ?*SSL_CTX;
extern fn SSL_CTX_free(context: *SSL_CTX) void;
extern fn SSL_CTX_ctrl(context: *SSL_CTX, command: c_int, larg: c_long, parg: ?*anyopaque) c_long;
extern fn SSL_CTX_use_certificate_chain_file(context: *SSL_CTX, path: [*:0]const u8) c_int;
extern fn SSL_CTX_use_PrivateKey_file(context: *SSL_CTX, path: [*:0]const u8, file_type: c_int) c_int;
extern fn SSL_CTX_check_private_key(context: *const SSL_CTX) c_int;
extern fn SSL_CTX_load_verify_locations(context: *SSL_CTX, ca_file: ?[*:0]const u8, ca_path: ?[*:0]const u8) c_int;
extern fn SSL_CTX_set_default_verify_paths(context: *SSL_CTX) c_int;
const VerifyCallback = ?*const fn (c_int, ?*anyopaque) callconv(.c) c_int;
extern fn SSL_CTX_set_verify(context: *SSL_CTX, mode: c_int, callback: VerifyCallback) void;
extern fn SSL_new(context: *SSL_CTX) ?*SSL;
extern fn SSL_free(ssl: *SSL) void;
extern fn SSL_set_fd(ssl: *SSL, fd: c_int) c_int;
extern fn SSL_ctrl(ssl: *SSL, command: c_int, larg: c_long, parg: ?*anyopaque) c_long;
extern fn SSL_set1_host(ssl: *SSL, hostname: [*:0]const u8) c_int;
extern fn SSL_accept(ssl: *SSL) c_int;
extern fn SSL_connect(ssl: *SSL) c_int;
extern fn SSL_read(ssl: *SSL, buffer: *anyopaque, length: c_int) c_int;
extern fn SSL_write(ssl: *SSL, buffer: *const anyopaque, length: c_int) c_int;
extern fn SSL_shutdown(ssl: *SSL) c_int;
extern fn SSL_get_error(ssl: *const SSL, result: c_int) c_int;
extern fn SSL_get_verify_result(ssl: *const SSL) c_long;

const ssl_filetype_pem = 1;
const ssl_verify_peer = 1;
const ssl_verify_fail_if_no_peer_cert = 2;
const ssl_ctrl_set_min_proto_version = 123;
const ssl_ctrl_set_max_proto_version = 124;
const ssl_ctrl_set_tlsext_hostname = 55;
const tls_1_2_version = 0x0303;
const tls_1_3_version = 0x0304;
const ssl_error_want_read = 2;
const ssl_error_want_write = 3;
const ssl_error_zero_return = 6;
const x509_v_ok = 0;

pub const ServerTlsConfig = struct {
    certificate_chain_path: [:0]const u8,
    private_key_path: [:0]const u8,
    client_ca_path: ?[:0]const u8 = null,
    require_client_certificate: bool = false,

    pub fn validate(self: ServerTlsConfig) !void {
        if (self.certificate_chain_path.len == 0 or self.private_key_path.len == 0) return error.InvalidTlsConfig;
        if (self.require_client_certificate and self.client_ca_path == null) return error.MissingClientCa;
    }
};

pub const ClientTlsConfig = struct {
    ca_path: ?[:0]const u8 = null,
    server_name: [:0]const u8,
    client_certificate_chain_path: ?[:0]const u8 = null,
    client_private_key_path: ?[:0]const u8 = null,

    pub fn validate(self: ClientTlsConfig) !void {
        if (self.server_name.len == 0) return error.MissingServerName;
        if ((self.client_certificate_chain_path == null) != (self.client_private_key_path == null)) return error.IncompleteClientIdentity;
    }
};

pub const ServerOptions = struct {
    host: []const u8 = "127.0.0.1",
    port: u16 = 19392,
    limits: Limits = .{},
    auth: Auth = .{},
    request_deadline_ms: ?u64 = 30_000,
    tls_handshake_deadline_ms: u64 = 10_000,
    tls: ?ServerTlsConfig = null,
};

pub const ServerSnapshot = struct {
    readiness: bool,
    accepted_connections: usize,
    active_connections: usize,
    handled_requests: usize,
    rejected_auth: usize,
    malformed_frames: usize,
};

pub const Server = struct {
    allocator: std.mem.Allocator,
    io: std.Io,
    options: ServerOptions,
    listener: std.Io.net.Server,
    handler: Handler,
    ready: std.atomic.Value(bool) = .init(true),
    listener_open: std.atomic.Value(bool) = .init(true),
    accepted_connections: std.atomic.Value(usize) = .init(0),
    active_connections: std.atomic.Value(usize) = .init(0),
    handled_requests: std.atomic.Value(usize) = .init(0),
    rejected_auth: std.atomic.Value(usize) = .init(0),
    malformed_frames: std.atomic.Value(usize) = .init(0),
    tls_context: ?*SSL_CTX = null,
    tls_mutex: std.atomic.Mutex = .unlocked,
    certificate_epoch: std.atomic.Value(u64) = .init(0),
    auth_mutex: std.atomic.Mutex = .unlocked,
    owned_auth_credential: ?[]u8 = null,
    auth_epoch: std.atomic.Value(u64) = .init(0),

    pub fn init(allocator: std.mem.Allocator, io: std.Io, options: ServerOptions, handler: Handler) !Server {
        try options.limits.validate();
        if (options.request_deadline_ms == 0) return error.InvalidRequestDeadline;
        if (options.tls_handshake_deadline_ms == 0) return error.InvalidTlsHandshakeDeadline;
        if (options.tls) |tls| try tls.validate();
        var owned_options = options;
        const owned_credential = if (options.auth.mode == .none) null else try allocator.dupe(u8, options.auth.credential);
        errdefer if (owned_credential) |credential| allocator.free(credential);
        if (owned_credential) |credential| owned_options.auth.credential = credential;
        const address = try std.Io.net.IpAddress.resolve(io, options.host, options.port);
        var listener = try address.listen(io, .{ .reuse_address = true });
        errdefer listener.deinit(io);
        const tls_context = if (options.tls) |tls| try createServerTlsContext(tls) else null;
        errdefer if (tls_context) |context| SSL_CTX_free(context);
        return .{ .allocator = allocator, .io = io, .options = owned_options, .listener = listener, .handler = handler, .tls_context = tls_context, .owned_auth_credential = owned_credential };
    }

    pub fn deinit(self: *Server) void {
        self.drain();
        if (self.tls_context) |context| SSL_CTX_free(context);
        self.freeOwnedAuth();
        self.* = undefined;
    }

    pub fn drain(self: *Server) void {
        self.ready.store(false, .release);
        if (self.listener_open.swap(false, .acq_rel)) self.listener.deinit(self.io);
    }

    pub fn snapshot(self: *const Server) ServerSnapshot {
        return .{
            .readiness = self.ready.load(.acquire),
            .accepted_connections = self.accepted_connections.load(.acquire),
            .active_connections = self.active_connections.load(.acquire),
            .handled_requests = self.handled_requests.load(.acquire),
            .rejected_auth = self.rejected_auth.load(.acquire),
            .malformed_frames = self.malformed_frames.load(.acquire),
        };
    }

    pub fn serveOne(self: *Server, allocator: std.mem.Allocator) !usize {
        if (!self.ready.load(.acquire)) return error.TransportUnavailable;
        var stream = try self.listener.accept(self.io);
        _ = self.accepted_connections.fetchAdd(1, .monotonic);
        _ = self.active_connections.fetchAdd(1, .monotonic);
        defer _ = self.active_connections.fetchSub(1, .monotonic);
        defer stream.close(self.io);
        if (self.tls_context != null) {
            const ssl = try self.newServerSsl(stream.socket.handle);
            var state = TlsWireState{ .stream = stream, .io = self.io, .ssl = ssl };
            defer state.deinit();
            try timedTlsHandshake(self.io, &state, true, self.options.tls_handshake_deadline_ms);
            return self.handleWire(allocator, state.wire());
        }
        var state = PlainWireState{ .stream = stream, .io = self.io };
        return self.handleWire(allocator, state.wire());
    }

    pub fn reloadTls(self: *Server, config: ServerTlsConfig) !u64 {
        try config.validate();
        const replacement = try createServerTlsContext(config);
        while (!self.tls_mutex.tryLock()) std.Thread.yield() catch {};
        const previous = self.tls_context;
        self.tls_context = replacement;
        self.options.tls = config;
        const epoch = self.certificate_epoch.fetchAdd(1, .acq_rel) + 1;
        self.tls_mutex.unlock();
        if (previous) |context| SSL_CTX_free(context);
        return epoch;
    }

    fn newServerSsl(self: *Server, handle: std.Io.net.Socket.Handle) !*SSL {
        while (!self.tls_mutex.tryLock()) std.Thread.yield() catch {};
        defer self.tls_mutex.unlock();
        const context = self.tls_context orelse return error.TlsDisabled;
        const ssl = SSL_new(context) orelse return error.TlsConnectionInitializationFailed;
        errdefer SSL_free(ssl);
        if (SSL_set_fd(ssl, handle) != 1) return error.TlsSocketBindingFailed;
        return ssl;
    }

    fn handleWire(self: *Server, allocator: std.mem.Allocator, wire: Wire) !usize {
        var handled: usize = 0;
        while (handled < self.options.limits.max_requests_per_connection) {
            const deadline = if (self.options.request_deadline_ms) |value| deadlineFromNow(self.io, value) else null;
            const body = readFrameAlloc(allocator, self.io, wire, self.options.limits.max_frame_bytes, deadline) catch |err| switch (err) {
                error.EndOfStream => break,
                else => {
                    _ = self.malformed_frames.fetchAdd(1, .monotonic);
                    return err;
                },
            };
            defer allocator.free(body);
            if (std.mem.eql(u8, body, "ZIGFXPING/1")) {
                try writeFramedAlloc(allocator, wire, "ZIGFXPONG/1");
                continue;
            }
            const authenticated = parseAuthenticatedBody(body) catch |err| {
                try writeErrorAlloc(allocator, wire, error.CorruptTransportMessage);
                _ = self.malformed_frames.fetchAdd(1, .monotonic);
                return err;
            };
            var request = fx.parseClusterTransportRequestJson(allocator, authenticated.request_json) catch |err| {
                try writeErrorAlloc(allocator, wire, error.CorruptTransportMessage);
                _ = self.malformed_frames.fetchAdd(1, .monotonic);
                return err;
            };
            defer request.deinit(allocator);
            if (request.auth.mode != authenticated.mode) {
                _ = self.rejected_auth.fetchAdd(1, .monotonic);
                try writeErrorAlloc(allocator, wire, error.TransportUnauthorized);
                return error.TransportUnauthorized;
            }
            self.validateServerAuth(authenticated.mode, authenticated.credential) catch |err| {
                _ = self.rejected_auth.fetchAdd(1, .monotonic);
                try writeErrorAlloc(allocator, wire, error.TransportUnauthorized);
                return err;
            };
            var response = self.handler.handleAlloc(allocator, request) catch |err| {
                try writeErrorAlloc(allocator, wire, err);
                return err;
            };
            defer response.deinit(allocator);
            const response_json = try fx.formatClusterTransportResponseJson(allocator, response);
            defer allocator.free(response_json);
            try writeFramedAlloc(allocator, wire, response_json);
            handled += 1;
            _ = self.handled_requests.fetchAdd(1, .monotonic);
        }
        return handled;
    }

    pub fn rotateAuth(self: *Server, auth: Auth) !u64 {
        const replacement = if (auth.mode == .none) null else try self.allocator.dupe(u8, auth.credential);
        errdefer if (replacement) |credential| self.allocator.free(credential);
        while (!self.auth_mutex.tryLock()) std.Thread.yield() catch {};
        const previous = self.owned_auth_credential;
        self.owned_auth_credential = replacement;
        self.options.auth = .{ .mode = auth.mode, .credential = if (replacement) |credential| credential else "" };
        const epoch = self.auth_epoch.fetchAdd(1, .acq_rel) + 1;
        self.auth_mutex.unlock();
        if (previous) |credential| {
            @memset(credential, 0);
            self.allocator.free(credential);
        }
        return epoch;
    }

    fn validateServerAuth(self: *Server, mode: fx.ClusterTransportAuthMode, credential: []const u8) !void {
        while (!self.auth_mutex.tryLock()) std.Thread.yield() catch {};
        defer self.auth_mutex.unlock();
        return validateAuth(self.options.auth, mode, credential);
    }

    fn freeOwnedAuth(self: *Server) void {
        if (self.owned_auth_credential) |credential| {
            @memset(credential, 0);
            self.allocator.free(credential);
            self.owned_auth_credential = null;
        }
    }
};

pub const ClientOptions = struct {
    host: []const u8 = "127.0.0.1",
    port: u16 = 19392,
    auth: Auth = .{},
    limits: Limits = .{},
    reconnect_attempts: usize = 1,
    tls: ?ClientTlsConfig = null,
    tls_handshake_deadline_ms: u64 = 10_000,
    pool: fx.ClusterTransportConnectionPoolPolicy = .{ .max_connections = 2 },
    backpressure: fx.ClusterTransportBackpressurePolicy = .{ .strategy = .block, .max_queued = 1024 },
    acquisition_timeout_ms: u64 = 5_000,
    acquisition_poll_ms: u64 = 1,
    max_connection_lifetime_ms: u64 = 3_600_000,
};

pub const ClientConfig = struct { io: std.Io, options: ClientOptions = .{} };
pub const ClientConfigService = zstd.fx.kernel.Service("zigeffect/transport/ClientConfig", ClientConfig);
pub const ClientApi = struct {
    pub const operations: []const []const u8 = &.{ "ClusterTransport.send", "ClusterTransport.refreshDiscovery", "ClusterTransport.rotateAuth", "ClusterTransport.snapshot" };
    client: Client,
};
pub const ClientService = zstd.fx.kernel.Service("zigeffect/transport/Client", ClientApi);

pub fn clientConfigLayer(config: ClientConfig) @TypeOf(zstd.fx.kernel.Layer.succeed(ClientConfigService, config)) {
    return zstd.fx.kernel.Layer.succeed(ClientConfigService, config);
}

const ClientLifecycle = struct {
    fn acquire(ctx: *zstd.fx.kernel.ContextView(.{ClientConfigService})) anyerror!ClientApi {
        const config = ctx.service(ClientConfigService);
        return .{ .client = try Client.initAlloc(ctx.allocator(), config.io, config.options) };
    }

    fn release(api: *ClientApi) void {
        api.client.close() catch {};
        api.client.deinit();
    }
};

pub fn clientLayer() @TypeOf(zstd.fx.kernel.Layer.scoped(
    ClientService,
    anyerror,
    .{ClientConfigService},
    ClientLifecycle.acquire,
    ClientLifecycle.release,
)) {
    return zstd.fx.kernel.Layer.scoped(
        ClientService,
        anyerror,
        .{ClientConfigService},
        ClientLifecycle.acquire,
        ClientLifecycle.release,
    );
}

pub const ClusterTransportService = zstd.fx.kernel.Service("zigeffect/cluster/Transport", fx.ClusterTransport);
const ClusterTransportFactory = struct {
    fn make(ctx: *zstd.fx.kernel.ContextView(.{ClientService})) fx.ClusterTransport {
        return ctx.service(ClientService).client.asClusterTransport();
    }
};

pub fn clusterTransportLayer() @TypeOf(zstd.fx.kernel.Layer.sync(
    ClusterTransportService,
    .{ClientService},
    ClusterTransportFactory.make,
)) {
    return zstd.fx.kernel.Layer.sync(ClusterTransportService, .{ClientService}, ClusterTransportFactory.make);
}

pub fn configuredClientLayer(config: ClientConfig) @TypeOf(
    clusterTransportLayer().provideMerge(clientLayer().provideMerge(clientConfigLayer(config))),
) {
    return clusterTransportLayer().provideMerge(clientLayer().provideMerge(clientConfigLayer(config)));
}

pub const ServerConfig = struct { io: std.Io, options: ServerOptions = .{}, handler: Handler };
pub const ServerConfigService = zstd.fx.kernel.Service("zigeffect/transport/ServerConfig", ServerConfig);
pub const ServerApi = struct {
    pub const operations: []const []const u8 = &.{ "ClusterTransportServer.serveOne", "ClusterTransportServer.drain", "ClusterTransportServer.snapshot" };
    server: Server,
};
pub const ServerService = zstd.fx.kernel.Service("zigeffect/transport/Server", ServerApi);

pub fn serverConfigLayer(config: ServerConfig) @TypeOf(zstd.fx.kernel.Layer.succeed(ServerConfigService, config)) {
    return zstd.fx.kernel.Layer.succeed(ServerConfigService, config);
}

const ServerLifecycle = struct {
    fn acquire(ctx: *zstd.fx.kernel.ContextView(.{ServerConfigService})) anyerror!ServerApi {
        const config = ctx.service(ServerConfigService);
        return .{ .server = try Server.init(ctx.allocator(), config.io, config.options, config.handler) };
    }

    fn release(api: *ServerApi) void {
        api.server.drain();
        api.server.deinit();
    }
};

pub fn serverLayer() @TypeOf(zstd.fx.kernel.Layer.scoped(
    ServerService,
    anyerror,
    .{ServerConfigService},
    ServerLifecycle.acquire,
    ServerLifecycle.release,
)) {
    return zstd.fx.kernel.Layer.scoped(
        ServerService,
        anyerror,
        .{ServerConfigService},
        ServerLifecycle.acquire,
        ServerLifecycle.release,
    );
}

pub fn configuredServerLayer(config: ServerConfig) @TypeOf(serverLayer().provideMerge(serverConfigLayer(config))) {
    return serverLayer().provideMerge(serverConfigLayer(config));
}

pub const ServeOneEffect = zstd.fx.kernel.Effect(usize, anyerror, .{ServerService});
pub fn serveOneEffect() ServeOneEffect {
    return ServeOneEffect.fromFn(struct {
        fn run(ctx: *ServeOneEffect.Context) anyerror!usize {
            const operation = zstd.Service.beginOperation(ctx, ServerService.service_key, "cluster.transport.server.serve-one", "serving one bounded transport connection");
            const handled = ctx.service(ServerService).server.serveOne(ctx.allocator()) catch |failure| {
                _ = zstd.Service.completeOperation(ctx, operation, "failure", @errorName(failure));
                return failure;
            };
            _ = zstd.Service.completeOperation(ctx, operation, "success", "bounded transport connection completed");
            return handled;
        }
    }.run);
}

pub const DrainServerEffect = zstd.fx.kernel.Effect(void, error{}, .{ServerService});
pub fn drainServerEffect() DrainServerEffect {
    return DrainServerEffect.fromFn(struct {
        fn run(ctx: *DrainServerEffect.Context) error{}!void {
            ctx.service(ServerService).server.drain();
            _ = zstd.Service.recordSemantic(ctx, .resource_finalized, ServerService.service_key, "cluster.transport.server.drain", "success", "transport listener drained");
        }
    }.run);
}

const SendRequest = struct { request: fx.ClusterTransportRequest };
pub const SendEffect = zstd.fx.kernel.Effect(fx.ClusterTransportResponse, anyerror, .{ClusterTransportService}).Stateful(SendRequest);
pub fn sendEffect(request: fx.ClusterTransportRequest) SendEffect {
    return SendEffect.init(.{ .request = request }, struct {
        fn run(state: SendRequest, ctx: *SendEffect.Context) anyerror!fx.ClusterTransportResponse {
            const operation = zstd.Service.beginOperation(ctx, ClusterTransportService.service_key, "cluster.transport.send", "sending bounded redacted cluster envelope");
            const response = ctx.service(ClusterTransportService).send(ctx.allocator(), state.request) catch |err| {
                _ = zstd.Service.completeOperation(ctx, operation, "failure", @errorName(err));
                return err;
            };
            _ = zstd.Service.completeOperation(ctx, operation, "success", "cluster envelope completed");
            return response;
        }
    }.run);
}

pub const ClientSnapshot = struct {
    sends: usize,
    successes: usize,
    failures: usize,
    reconnects: usize,
    bytes_sent: usize,
    bytes_received: usize,
    checked_out: usize,
    available: usize,
    backpressured: usize,
};

const ClientSlot = struct {
    connection: ?PooledConnection = null,
    leased: bool = false,
    created_ms: i64 = 0,
    last_used_ms: i64 = 0,
    last_health_ms: i64 = 0,
};

pub const Client = struct {
    allocator: std.mem.Allocator,
    io: std.Io,
    options: ClientOptions,
    slots: []ClientSlot,
    mutex: std.atomic.Mutex = .unlocked,
    closing: std.atomic.Value(bool) = .init(false),
    queued: std.atomic.Value(usize) = .init(0),
    sends: std.atomic.Value(usize) = .init(0),
    successes: std.atomic.Value(usize) = .init(0),
    failures: std.atomic.Value(usize) = .init(0),
    reconnects: std.atomic.Value(usize) = .init(0),
    bytes_sent: std.atomic.Value(usize) = .init(0),
    bytes_received: std.atomic.Value(usize) = .init(0),
    backpressured: std.atomic.Value(usize) = .init(0),
    owned_host: []u8,
    owned_auth_credential: ?[]u8 = null,
    auth_mutex: std.atomic.Mutex = .unlocked,
    auth_epoch: std.atomic.Value(u64) = .init(0),
    discovery_epoch: std.atomic.Value(u64) = .init(0),

    pub fn init(io: std.Io, options: ClientOptions) !Client {
        return initAlloc(std.heap.smp_allocator, io, options);
    }

    pub fn initAlloc(allocator: std.mem.Allocator, io: std.Io, options: ClientOptions) !Client {
        try options.limits.validate();
        if (options.tls_handshake_deadline_ms == 0) return error.InvalidTlsHandshakeDeadline;
        if (options.tls) |tls| try tls.validate();
        if (options.pool.max_connections == 0 or options.pool.idle_timeout_ms == 0 or options.pool.health_check_interval_ms == 0 or
            options.acquisition_timeout_ms == 0 or options.acquisition_poll_ms == 0 or options.max_connection_lifetime_ms == 0 or
            options.backpressure.max_queued == 0) return error.InvalidTransportLimits;
        const owned_host = try allocator.dupe(u8, options.host);
        errdefer allocator.free(owned_host);
        const owned_credential = if (options.auth.mode == .none) null else try allocator.dupe(u8, options.auth.credential);
        errdefer if (owned_credential) |credential| allocator.free(credential);
        var owned_options = options;
        owned_options.host = owned_host;
        if (owned_credential) |credential| owned_options.auth.credential = credential;
        const slots = try allocator.alloc(ClientSlot, options.pool.max_connections);
        @memset(slots, .{});
        return .{ .allocator = allocator, .io = io, .options = owned_options, .slots = slots, .owned_host = owned_host, .owned_auth_credential = owned_credential };
    }

    pub fn close(self: *Client) !void {
        self.closing.store(true, .release);
        self.lock();
        defer self.mutex.unlock();
        for (self.slots) |slot| if (slot.leased) return error.TransportPoolBusy;
        for (self.slots) |*slot| if (slot.connection) |*connection| {
            connection.close();
            slot.connection = null;
        };
    }

    pub fn deinit(self: *Client) void {
        self.close() catch {
            self.lock();
            for (self.slots) |slot| std.debug.assert(!slot.leased);
            self.mutex.unlock();
        };
        self.allocator.free(self.owned_host);
        if (self.owned_auth_credential) |credential| {
            @memset(credential, 0);
            self.allocator.free(credential);
        }
        self.allocator.free(self.slots);
        self.* = undefined;
    }

    pub fn asClusterTransport(self: *Client) fx.ClusterTransport {
        return .{ .ptr = self, .vtable = &client_vtable };
    }

    pub fn snapshot(self: *const Client) ClientSnapshot {
        const mutable: *Client = @constCast(self);
        mutable.lock();
        var checked_out: usize = 0;
        for (self.slots) |slot| if (slot.leased) {
            checked_out += 1;
        };
        mutable.mutex.unlock();
        return .{
            .sends = self.sends.load(.acquire),
            .successes = self.successes.load(.acquire),
            .failures = self.failures.load(.acquire),
            .reconnects = self.reconnects.load(.acquire),
            .bytes_sent = self.bytes_sent.load(.acquire),
            .bytes_received = self.bytes_received.load(.acquire),
            .checked_out = checked_out,
            .available = self.slots.len - checked_out,
            .backpressured = self.backpressured.load(.acquire),
        };
    }

    pub fn sendAlloc(self: *Client, allocator: std.mem.Allocator, request_value: fx.ClusterTransportRequest) !fx.ClusterTransportResponse {
        _ = self.sends.fetchAdd(1, .monotonic);
        if (request_value.policy.timeout_ms == 0) return error.TransportTimeout;
        var request = request_value;
        while (!self.auth_mutex.tryLock()) std.Thread.yield() catch {};
        defer self.auth_mutex.unlock();
        request.auth = .{ .mode = self.options.auth.mode, .credential = null };
        const json = try fx.formatClusterTransportRequestJson(allocator, request);
        defer allocator.free(json);
        const authenticated_body = try formatAuthenticatedBodyAlloc(allocator, self.options.auth, json);
        defer allocator.free(authenticated_body);
        if (authenticated_body.len > self.options.limits.max_frame_bytes) return error.TransportPayloadTooLarge;
        const max_attempts = @min(request.policy.max_retries, self.options.reconnect_attempts) + 1;
        var attempt: usize = 0;
        while (attempt < max_attempts) : (attempt += 1) {
            const response = self.sendOnce(allocator, authenticated_body, request.policy.timeout_ms) catch |err| {
                _ = self.failures.fetchAdd(1, .monotonic);
                if (attempt + 1 < max_attempts and request.idempotency_key != null and retryable(err)) {
                    _ = self.reconnects.fetchAdd(1, .monotonic);
                    (std.Io.Clock.Duration{ .raw = .fromMilliseconds(2), .clock = .awake }).sleep(self.io) catch {};
                    continue;
                }
                return err;
            };
            _ = self.successes.fetchAdd(1, .monotonic);
            return response;
        }
        return error.RetryLimitExceeded;
    }

    fn sendOnce(self: *Client, allocator: std.mem.Allocator, json: []const u8, timeout_ms: u64) !fx.ClusterTransportResponse {
        var lease = try self.checkout(allocator, timeout_ms);
        defer lease.release();
        return self.exchange(allocator, lease.wire(), json, timeout_ms) catch |err| {
            lease.invalidate();
            return err;
        };
    }

    fn openConnection(self: *Client) !PooledConnection {
        const address = std.Io.net.IpAddress.resolve(self.io, self.options.host, self.options.port) catch return error.TransportUnavailable;
        var stream = address.connect(self.io, .{ .mode = .stream }) catch return error.TransportUnavailable;
        errdefer stream.close(self.io);
        if (self.options.tls) |tls| {
            const context = try createClientTlsContext(tls);
            errdefer SSL_CTX_free(context);
            const ssl = SSL_new(context) orelse return error.TlsConnectionInitializationFailed;
            var state = TlsWireState{ .stream = stream, .io = self.io, .ssl = ssl };
            errdefer state.deinit();
            if (SSL_set_fd(ssl, stream.socket.handle) != 1) return error.TlsSocketBindingFailed;
            if (SSL_ctrl(ssl, ssl_ctrl_set_tlsext_hostname, 0, @ptrCast(@constCast(tls.server_name.ptr))) != 1) return error.TlsServerNameFailed;
            if (SSL_set1_host(ssl, tls.server_name.ptr) != 1) return error.TlsHostVerificationConfigurationFailed;
            try timedTlsHandshake(self.io, &state, false, self.options.tls_handshake_deadline_ms);
            if (SSL_get_verify_result(ssl) != x509_v_ok) return error.TlsPeerVerificationFailed;
            return .{ .tls = .{ .state = state, .context = context } };
        }
        return .{ .plain = .{ .stream = stream, .io = self.io } };
    }

    pub fn rotateAuth(self: *Client, auth: Auth) !u64 {
        const replacement = if (auth.mode == .none) null else try self.allocator.dupe(u8, auth.credential);
        errdefer if (replacement) |credential| self.allocator.free(credential);
        while (!self.auth_mutex.tryLock()) std.Thread.yield() catch {};
        const previous = self.owned_auth_credential;
        self.owned_auth_credential = replacement;
        self.options.auth = .{ .mode = auth.mode, .credential = if (replacement) |credential| credential else "" };
        const epoch = self.auth_epoch.fetchAdd(1, .acq_rel) + 1;
        self.auth_mutex.unlock();
        if (previous) |credential| {
            @memset(credential, 0);
            self.allocator.free(credential);
        }
        self.closeConnections();
        return epoch;
    }

    pub fn refreshDiscovery(self: *Client, discovery_snapshot: fx.ClusterTransportServiceDiscoverySnapshot, requirements: fx.ClusterTransportServiceDiscoveryRequirements) !u64 {
        const selection = fx.selectFreshestClusterTransportServiceDiscoveryEndpoint(discovery_snapshot.endpoints, requirements);
        const selected = selection.selected orelse return error.TransportUnavailable;
        if ((self.options.tls != null) != selected.tls_enabled) return error.TransportTlsPolicyMismatch;
        const replacement = try self.allocator.dupe(u8, selected.host);
        self.lock();
        for (self.slots) |slot| if (slot.leased) {
            self.mutex.unlock();
            self.allocator.free(replacement);
            return error.TransportPoolBusy;
        };
        const previous = self.owned_host;
        self.owned_host = replacement;
        self.options.host = replacement;
        self.options.port = selected.port;
        for (self.slots) |*slot| if (slot.connection) |*connection| {
            connection.close();
            slot.connection = null;
        };
        const epoch = self.discovery_epoch.fetchAdd(1, .acq_rel) + 1;
        self.mutex.unlock();
        self.allocator.free(previous);
        return epoch;
    }

    fn closeConnections(self: *Client) void {
        self.lock();
        defer self.mutex.unlock();
        for (self.slots) |*slot| if (!slot.leased) if (slot.connection) |*connection| {
            connection.close();
            slot.connection = null;
        };
    }

    fn exchange(self: *Client, allocator: std.mem.Allocator, wire: Wire, json: []const u8, timeout_ms: u64) !fx.ClusterTransportResponse {
        try writeFramedAlloc(allocator, wire, json);
        _ = self.bytes_sent.fetchAdd(json.len, .monotonic);
        const response_body = try readFrameAlloc(allocator, self.io, wire, self.options.limits.max_frame_bytes, deadlineFromNow(self.io, timeout_ms));
        defer allocator.free(response_body);
        _ = self.bytes_received.fetchAdd(response_body.len, .monotonic);
        if (std.mem.startsWith(u8, response_body, error_prefix)) return errorFromWire(response_body[error_prefix.len..]);
        return fx.parseClusterTransportResponseJson(allocator, response_body);
    }

    fn sendOpaque(pointer: *anyopaque, allocator: std.mem.Allocator, request: fx.ClusterTransportRequest) anyerror!fx.ClusterTransportResponse {
        return (@as(*Client, @ptrCast(@alignCast(pointer)))).sendAlloc(allocator, request);
    }

    fn checkout(self: *Client, allocator: std.mem.Allocator, timeout_ms: u64) !ClientLease {
        if (self.closing.load(.acquire)) return error.TransportUnavailable;
        const wait_ms = @min(timeout_ms, self.options.acquisition_timeout_ms);
        const deadline = deadlineFromNow(self.io, wait_ms);
        var counted_queue = false;
        defer {
            if (counted_queue) _ = self.queued.fetchSub(1, .monotonic);
        }
        while (true) {
            self.lock();
            if (self.closing.load(.acquire)) {
                self.mutex.unlock();
                return error.TransportUnavailable;
            }
            var selected: ?usize = null;
            for (self.slots, 0..) |*slot, index| {
                if (slot.leased) continue;
                slot.leased = true;
                selected = index;
                break;
            }
            self.mutex.unlock();
            if (selected) |index| {
                const slot = &self.slots[index];
                const now = nowMilliseconds(self.io);
                const expired = slot.connection != null and
                    (elapsedAtLeast(now, slot.created_ms, self.options.max_connection_lifetime_ms) or
                        elapsedAtLeast(now, slot.last_used_ms, self.options.pool.idle_timeout_ms));
                if (expired) {
                    slot.connection.?.close();
                    slot.connection = null;
                }
                if (slot.connection == null) {
                    slot.connection = self.openConnection() catch |err| {
                        self.releaseSlot(index);
                        return err;
                    };
                    slot.created_ms = now;
                    slot.last_health_ms = now;
                } else if (elapsedAtLeast(now, slot.last_health_ms, self.options.pool.health_check_interval_ms)) {
                    self.healthCheck(allocator, &slot.connection.?, @min(timeout_ms, self.options.pool.health_check_interval_ms)) catch {
                        slot.connection.?.close();
                        slot.connection = self.openConnection() catch |err| {
                            self.releaseSlot(index);
                            return err;
                        };
                        _ = self.reconnects.fetchAdd(1, .monotonic);
                    };
                    slot.last_health_ms = now;
                }
                return .{ .client = self, .index = index };
            }
            switch (self.options.backpressure.strategy) {
                .reject, .drop => {
                    _ = self.backpressured.fetchAdd(1, .monotonic);
                    return error.TransportBackpressured;
                },
                .block => {},
            }
            if (!counted_queue) {
                const queued = self.queued.fetchAdd(1, .monotonic) + 1;
                counted_queue = true;
                if (queued > self.options.backpressure.max_queued) {
                    _ = self.backpressured.fetchAdd(1, .monotonic);
                    return error.TransportBackpressured;
                }
            }
            if (std.Io.Clock.Timestamp.compare(std.Io.Clock.Timestamp.now(self.io, .awake), .gte, deadline)) return error.TransportTimeout;
            try (std.Io.Clock.Duration{ .raw = .fromMilliseconds(@intCast(self.options.acquisition_poll_ms)), .clock = .awake }).sleep(self.io);
        }
    }

    fn healthCheck(self: *Client, allocator: std.mem.Allocator, connection: *PooledConnection, timeout_ms: u64) !void {
        const wire = connection.wire();
        try writeFramedAlloc(allocator, wire, "ZIGFXPING/1");
        const body = try readFrameAlloc(allocator, self.io, wire, 64, deadlineFromNow(self.io, timeout_ms));
        defer allocator.free(body);
        if (!std.mem.eql(u8, body, "ZIGFXPONG/1")) return error.TransportUnavailable;
    }

    fn releaseSlot(self: *Client, index: usize) void {
        self.lock();
        self.slots[index].last_used_ms = nowMilliseconds(self.io);
        self.slots[index].leased = false;
        self.mutex.unlock();
    }

    fn invalidateSlot(self: *Client, index: usize) void {
        if (self.slots[index].connection) |*connection| connection.close();
        self.slots[index].connection = null;
    }

    fn lock(self: *Client) void {
        while (!self.mutex.tryLock()) std.Thread.yield() catch {};
    }
};

const ClientLease = struct {
    client: *Client,
    index: usize,
    released: bool = false,

    fn wire(self: *ClientLease) Wire {
        return self.client.slots[self.index].connection.?.wire();
    }
    fn invalidate(self: *ClientLease) void {
        self.client.invalidateSlot(self.index);
    }
    fn release(self: *ClientLease) void {
        if (self.released) return;
        self.client.releaseSlot(self.index);
        self.released = true;
    }
};

const client_vtable: fx.ClusterTransport.VTable = .{ .send = Client.sendOpaque };

const Wire = struct {
    pointer: *anyopaque,
    read_fn: *const fn (*anyopaque, []u8) anyerror!usize,
    write_fn: *const fn (*anyopaque, []const u8) anyerror!void,
    cancel_fn: *const fn (*anyopaque) void,

    fn read(self: Wire, buffer: []u8) !usize {
        return self.read_fn(self.pointer, buffer);
    }
    fn write(self: Wire, bytes: []const u8) !void {
        return self.write_fn(self.pointer, bytes);
    }
    fn cancelRead(self: Wire) void {
        self.cancel_fn(self.pointer);
    }
};

const PlainWireState = struct {
    stream: std.Io.net.Stream,
    io: std.Io,

    fn wire(self: *PlainWireState) Wire {
        return .{ .pointer = self, .read_fn = read, .write_fn = write, .cancel_fn = cancel };
    }
    fn read(pointer: *anyopaque, buffer: []u8) !usize {
        const self: *PlainWireState = @ptrCast(@alignCast(pointer));
        var parts = [_][]u8{buffer};
        return self.io.vtable.netRead(self.io.userdata, self.stream.socket.handle, &parts);
    }
    fn write(pointer: *anyopaque, bytes: []const u8) !void {
        const self: *PlainWireState = @ptrCast(@alignCast(pointer));
        var offset: usize = 0;
        while (offset < bytes.len) {
            const parts = [_][]const u8{bytes[offset..]};
            const count = try self.io.vtable.netWrite(self.io.userdata, self.stream.socket.handle, "", &parts, 1);
            if (count == 0) return error.TransportUnavailable;
            offset += count;
        }
    }
    fn cancel(pointer: *anyopaque) void {
        const self: *PlainWireState = @ptrCast(@alignCast(pointer));
        self.stream.shutdown(self.io, .recv) catch {};
    }
};

const TlsWireState = struct {
    stream: std.Io.net.Stream,
    io: std.Io,
    ssl: *SSL,

    fn wire(self: *TlsWireState) Wire {
        return .{ .pointer = self, .read_fn = read, .write_fn = write, .cancel_fn = cancel };
    }
    fn deinit(self: *TlsWireState) void {
        _ = SSL_shutdown(self.ssl);
        SSL_free(self.ssl);
    }
    fn read(pointer: *anyopaque, buffer: []u8) !usize {
        const self: *TlsWireState = @ptrCast(@alignCast(pointer));
        if (buffer.len == 0) return 0;
        const result = SSL_read(self.ssl, buffer.ptr, @intCast(@min(buffer.len, std.math.maxInt(c_int))));
        if (result > 0) return @intCast(result);
        return switch (SSL_get_error(self.ssl, result)) {
            ssl_error_zero_return => 0,
            ssl_error_want_read, ssl_error_want_write => error.WouldBlock,
            else => error.TlsReadFailed,
        };
    }
    fn write(pointer: *anyopaque, bytes: []const u8) !void {
        const self: *TlsWireState = @ptrCast(@alignCast(pointer));
        var offset: usize = 0;
        while (offset < bytes.len) {
            const result = SSL_write(self.ssl, bytes[offset..].ptr, @intCast(@min(bytes.len - offset, std.math.maxInt(c_int))));
            if (result > 0) {
                offset += @intCast(result);
                continue;
            }
            switch (SSL_get_error(self.ssl, result)) {
                ssl_error_want_read, ssl_error_want_write => continue,
                else => return error.TlsWriteFailed,
            }
        }
    }
    fn cancel(pointer: *anyopaque) void {
        const self: *TlsWireState = @ptrCast(@alignCast(pointer));
        self.stream.shutdown(self.io, .both) catch {};
    }
};

const PooledConnection = union(enum) {
    plain: PlainWireState,
    tls: struct { state: TlsWireState, context: *SSL_CTX },

    fn wire(self: *PooledConnection) Wire {
        return switch (self.*) {
            .plain => |*state| state.wire(),
            .tls => |*owned| owned.state.wire(),
        };
    }

    fn close(self: *PooledConnection) void {
        switch (self.*) {
            .plain => |*state| state.stream.close(state.io),
            .tls => |*owned| {
                owned.state.deinit();
                owned.state.stream.close(owned.state.io);
                SSL_CTX_free(owned.context);
            },
        }
    }
};

fn configureTlsVersions(context: *SSL_CTX) !void {
    if (SSL_CTX_ctrl(context, ssl_ctrl_set_min_proto_version, tls_1_2_version, null) != 1) return error.TlsPolicyConfigurationFailed;
    if (SSL_CTX_ctrl(context, ssl_ctrl_set_max_proto_version, tls_1_3_version, null) != 1) return error.TlsPolicyConfigurationFailed;
}

fn createServerTlsContext(config: ServerTlsConfig) !*SSL_CTX {
    const method = TLS_server_method() orelse return error.TlsLibraryInitializationFailed;
    const context = SSL_CTX_new(method) orelse return error.TlsContextInitializationFailed;
    errdefer SSL_CTX_free(context);
    try configureTlsVersions(context);
    if (SSL_CTX_use_certificate_chain_file(context, config.certificate_chain_path.ptr) != 1) return error.CertificateLoadFailed;
    if (SSL_CTX_use_PrivateKey_file(context, config.private_key_path.ptr, ssl_filetype_pem) != 1) return error.PrivateKeyLoadFailed;
    if (SSL_CTX_check_private_key(context) != 1) return error.PrivateKeyMismatch;
    if (config.client_ca_path) |path| {
        if (SSL_CTX_load_verify_locations(context, path.ptr, null) != 1) return error.ClientCaLoadFailed;
        const verify_mode: c_int = @as(c_int, ssl_verify_peer) | if (config.require_client_certificate) @as(c_int, ssl_verify_fail_if_no_peer_cert) else 0;
        SSL_CTX_set_verify(context, verify_mode, null);
    }
    return context;
}

fn createClientTlsContext(config: ClientTlsConfig) !*SSL_CTX {
    const method = TLS_client_method() orelse return error.TlsLibraryInitializationFailed;
    const context = SSL_CTX_new(method) orelse return error.TlsContextInitializationFailed;
    errdefer SSL_CTX_free(context);
    try configureTlsVersions(context);
    if (config.ca_path) |path| {
        if (SSL_CTX_load_verify_locations(context, path.ptr, null) != 1) return error.CaLoadFailed;
    } else if (SSL_CTX_set_default_verify_paths(context) != 1) return error.SystemCaLoadFailed;
    SSL_CTX_set_verify(context, ssl_verify_peer, null);
    if (config.client_certificate_chain_path) |certificate| {
        if (SSL_CTX_use_certificate_chain_file(context, certificate.ptr) != 1) return error.ClientCertificateLoadFailed;
        const key = config.client_private_key_path.?;
        if (SSL_CTX_use_PrivateKey_file(context, key.ptr, ssl_filetype_pem) != 1) return error.ClientPrivateKeyLoadFailed;
        if (SSL_CTX_check_private_key(context) != 1) return error.ClientPrivateKeyMismatch;
    }
    return context;
}

const HandshakeRace = union(enum) { handshake: anyerror!void, timeout: std.Io.Cancelable!void };

fn timedTlsHandshake(io: std.Io, state: *TlsWireState, server_side: bool, timeout_ms: u64) !void {
    var results: [2]HandshakeRace = undefined;
    var select = std.Io.Select(HandshakeRace).init(io, &results);
    select.async(.handshake, tlsHandshakeTask, .{ state, server_side });
    select.async(.timeout, deadlineTask, .{ io, deadlineFromNow(io, timeout_ms) });
    const first = select.await() catch |err| {
        select.cancelDiscard();
        return err;
    };
    switch (first) {
        .handshake => |result| {
            select.cancelDiscard();
            try result;
        },
        .timeout => |result| {
            try result;
            state.stream.shutdown(io, .both) catch {};
            select.cancelDiscard();
            return error.TlsHandshakeTimeout;
        },
    }
}

fn tlsHandshakeTask(state: *TlsWireState, server_side: bool) !void {
    const result = if (server_side) SSL_accept(state.ssl) else SSL_connect(state.ssl);
    if (result != 1) return error.TlsHandshakeFailed;
}

const error_prefix = "ZIGFXERR/1 ";

fn writeFramedAlloc(allocator: std.mem.Allocator, wire: Wire, body: []const u8) !void {
    const frame = try fx.formatClusterTransportSocketFrame(allocator, body);
    defer allocator.free(frame);
    try wire.write(frame);
}

fn writeErrorAlloc(allocator: std.mem.Allocator, wire: Wire, err: anyerror) !void {
    const body = try std.fmt.allocPrint(allocator, "{s}{s}", .{ error_prefix, @errorName(err) });
    defer allocator.free(body);
    try writeFramedAlloc(allocator, wire, body);
}

fn readFrameAlloc(allocator: std.mem.Allocator, io: std.Io, wire: Wire, max_bytes: usize, deadline: ?std.Io.Clock.Timestamp) ![]u8 {
    var header: [64]u8 = undefined;
    var header_len: usize = 0;
    while (true) {
        var byte: [1]u8 = undefined;
        const count = try timedRead(io, wire, &byte, deadline);
        if (count == 0) return if (header_len == 0) error.EndOfStream else error.CorruptTransportMessage;
        if (byte[0] == '\n') break;
        if (header_len == header.len) return error.CorruptTransportMessage;
        header[header_len] = byte[0];
        header_len += 1;
    }
    const prefix = "ZIGFX/1 ";
    if (!std.mem.startsWith(u8, header[0..header_len], prefix)) return error.CorruptTransportMessage;
    const length = std.fmt.parseUnsigned(usize, header[prefix.len..header_len], 10) catch return error.CorruptTransportMessage;
    if (length > max_bytes) return error.TransportPayloadTooLarge;
    const body = try allocator.alloc(u8, length);
    errdefer allocator.free(body);
    var offset: usize = 0;
    while (offset < length) {
        const count = try timedRead(io, wire, body[offset..], deadline);
        if (count == 0) return error.CorruptTransportMessage;
        offset += count;
    }
    return body;
}

fn timedRead(io: std.Io, wire: Wire, buffer: []u8, deadline: ?std.Io.Clock.Timestamp) !usize {
    const timestamp = deadline orelse return wire.read(buffer);
    const Race = union(enum) { read: anyerror!usize, timeout: std.Io.Cancelable!void };
    var results: [2]Race = undefined;
    var select = std.Io.Select(Race).init(io, &results);
    select.async(.read, wireReadTask, .{ wire, buffer });
    select.async(.timeout, deadlineTask, .{ io, timestamp });
    const first = select.await() catch |err| {
        select.cancelDiscard();
        return err;
    };
    return switch (first) {
        .read => |result| blk: {
            select.cancelDiscard();
            break :blk result;
        },
        .timeout => |result| {
            try result;
            wire.cancelRead();
            select.cancelDiscard();
            return error.TransportTimeout;
        },
    };
}

fn wireReadTask(wire: Wire, buffer: []u8) anyerror!usize {
    return wire.read(buffer);
}
fn deadlineTask(io: std.Io, deadline: std.Io.Clock.Timestamp) std.Io.Cancelable!void {
    return deadline.wait(io);
}
fn deadlineFromNow(io: std.Io, milliseconds: u64) std.Io.Clock.Timestamp {
    return std.Io.Clock.Timestamp.fromNow(io, .{ .raw = .fromMilliseconds(@intCast(milliseconds)), .clock = .awake });
}

fn nowMilliseconds(io: std.Io) i64 {
    return @intCast(@divTrunc(std.Io.Clock.awake.now(io).nanoseconds, std.time.ns_per_ms));
}

fn elapsedAtLeast(now: i64, then: i64, duration_ms: u64) bool {
    if (now < then) return false;
    return @as(u64, @intCast(now - then)) >= duration_ms;
}

pub fn constantTimeEql(left: []const u8, right: []const u8) bool {
    var difference: usize = left.len ^ right.len;
    const maximum = @max(left.len, right.len);
    var index: usize = 0;
    while (index < maximum) : (index += 1) {
        const left_byte: u8 = if (index < left.len) left[index] else 0;
        const right_byte: u8 = if (index < right.len) right[index] else 0;
        difference |= left_byte ^ right_byte;
    }
    std.mem.doNotOptimizeAway(difference);
    return difference == 0;
}

const AuthenticatedBody = struct {
    mode: fx.ClusterTransportAuthMode,
    credential: []const u8,
    request_json: []const u8,
};

fn formatAuthenticatedBodyAlloc(allocator: std.mem.Allocator, auth: Auth, request_json: []const u8) ![]u8 {
    const credential = if (auth.mode == .none) "" else auth.credential;
    return std.fmt.allocPrint(allocator, "ZIGFXAUTH/1 {s} {d}\n{s}{s}", .{ @tagName(auth.mode), credential.len, credential, request_json });
}

fn parseAuthenticatedBody(body: []const u8) !AuthenticatedBody {
    const line_end = std.mem.indexOfScalar(u8, body, '\n') orelse return error.CorruptTransportMessage;
    var parts = std.mem.splitScalar(u8, body[0..line_end], ' ');
    if (!std.mem.eql(u8, parts.next() orelse return error.CorruptTransportMessage, "ZIGFXAUTH/1")) return error.CorruptTransportMessage;
    const mode = std.meta.stringToEnum(fx.ClusterTransportAuthMode, parts.next() orelse return error.CorruptTransportMessage) orelse return error.CorruptTransportMessage;
    const credential_len = std.fmt.parseUnsigned(usize, parts.next() orelse return error.CorruptTransportMessage, 10) catch return error.CorruptTransportMessage;
    if (parts.next() != null or credential_len > body.len - line_end - 1) return error.CorruptTransportMessage;
    const credential_start = line_end + 1;
    const json_start = credential_start + credential_len;
    if (json_start == body.len) return error.CorruptTransportMessage;
    return .{ .mode = mode, .credential = body[credential_start..json_start], .request_json = body[json_start..] };
}

fn validateAuth(expected: Auth, supplied_mode: fx.ClusterTransportAuthMode, supplied_credential: []const u8) !void {
    if (expected.mode == .none) return;
    if (supplied_mode != expected.mode) return error.TransportUnauthorized;
    if (!constantTimeEql(expected.credential, supplied_credential)) return error.TransportUnauthorized;
}

fn retryable(err: anyerror) bool {
    return err == error.TransportUnavailable or err == error.TransportTimeout or err == error.EndOfStream or err == error.ConnectionResetByPeer;
}

fn errorFromWire(name: []const u8) anyerror {
    if (std.mem.eql(u8, name, "TransportUnauthorized")) return error.TransportUnauthorized;
    if (std.mem.eql(u8, name, "TransportPayloadTooLarge")) return error.TransportPayloadTooLarge;
    if (std.mem.eql(u8, name, "TransportBackpressured")) return error.TransportBackpressured;
    if (std.mem.eql(u8, name, "CorruptTransportMessage")) return error.CorruptTransportMessage;
    return error.TransportUnavailable;
}

test "framing rejects hostile lengths and shared secrets compare without early content exits" {
    try capability.validate();
    try std.testing.expect(constantTimeEql("shared-secret", "shared-secret"));
    try std.testing.expect(!constantTimeEql("shared-secret", "shared-secreu"));
    try std.testing.expect(!constantTimeEql("short", "longer"));
    try (Limits{ .max_frame_bytes = 1 }).validate();
    try std.testing.expectError(error.InvalidTransportLimits, (Limits{ .max_frame_bytes = 0 }).validate());
}

test "plain TCP client and server exchange through independent socket ownership" {
    var memory = fx.InMemoryMessageStorage.init(std.testing.allocator);
    defer memory.deinit();
    var storage_handler = try StorageHandler.init(std.testing.allocator, memory.asMessageStorage(), 16);
    defer storage_handler.deinit();
    var server: ?Server = null;
    var port: u16 = 26_200;
    while (port < 26_300) : (port += 1) {
        server = Server.init(std.testing.allocator, std.testing.io, .{
            .port = port,
            .auth = .{ .mode = .shared_secret, .credential = "test-secret" },
        }, Handler.from(StorageHandler, &storage_handler)) catch |err| switch (err) {
            error.AddressInUse => continue,
            else => return err,
        };
        break;
    }
    if (server == null) return error.NoLoopbackPort;
    defer server.?.deinit();
    const Context = struct {
        server: *Server,
        result: ?usize = null,
        failure: ?anyerror = null,
        fn run(self: *@This()) void {
            self.result = self.server.serveOne(std.testing.allocator) catch |err| {
                self.failure = err;
                return;
            };
        }
    };
    var context: Context = .{ .server = &server.? };
    const thread = try std.Thread.spawn(.{}, Context.run, .{&context});
    var client = try Client.init(std.testing.io, .{ .port = port, .auth = .{ .mode = .shared_secret, .credential = "test-secret" } });
    var response = try client.sendAlloc(std.testing.allocator, .{
        .kind = .tell,
        .address = fx.entityAddress("transport-test", "one"),
        .payload = "hello",
        .idempotency_key = "send-1",
    });
    defer response.deinit(std.testing.allocator);
    var second_response = try client.sendAlloc(std.testing.allocator, .{
        .kind = .tell,
        .address = fx.entityAddress("transport-test", "two"),
        .payload = "again",
        .idempotency_key = "send-2",
    });
    defer second_response.deinit(std.testing.allocator);
    try std.testing.expectEqualStrings("again", second_response.envelope.payload);
    try std.testing.expectEqual(@as(usize, 0), client.snapshot().checked_out);
    client.deinit();
    thread.join();
    if (context.failure) |err| return err;
    try std.testing.expectEqual(@as(usize, 2), context.result.?);
    try std.testing.expectEqual(fx.ClusterTransportKind.production_socket, response.transport);
    try std.testing.expectEqualStrings("hello", response.envelope.payload);
    try std.testing.expectEqual(@as(usize, 2), server.?.snapshot().handled_requests);
    try std.testing.expectEqual(@as(usize, 1), server.?.snapshot().accepted_connections);
}

test "TLS client and server verify host and mutual certificate identity and reload context" {
    const certificate: [:0]const u8 = "../zigeffect-http-tls-openssl/tests/fixtures/cert.pem";
    const key: [:0]const u8 = "../zigeffect-http-tls-openssl/tests/fixtures/key.pem";
    var memory = fx.InMemoryMessageStorage.init(std.testing.allocator);
    defer memory.deinit();
    var storage_handler = try StorageHandler.init(std.testing.allocator, memory.asMessageStorage(), 16);
    defer storage_handler.deinit();
    const tls = ServerTlsConfig{
        .certificate_chain_path = certificate,
        .private_key_path = key,
        .client_ca_path = certificate,
        .require_client_certificate = true,
    };
    var server: ?Server = null;
    var port: u16 = 26_300;
    while (port < 26_400) : (port += 1) {
        server = Server.init(std.testing.allocator, std.testing.io, .{
            .port = port,
            .tls = tls,
            .auth = .{ .mode = .shared_secret, .credential = "tls-secret" },
        }, Handler.from(StorageHandler, &storage_handler)) catch |err| switch (err) {
            error.AddressInUse => continue,
            else => return err,
        };
        break;
    }
    if (server == null) return error.NoTlsLoopbackPort;
    defer server.?.deinit();
    try std.testing.expectEqual(@as(u64, 1), try server.?.reloadTls(tls));
    const Context = struct {
        server: *Server,
        result: ?usize = null,
        failure: ?anyerror = null,
        fn run(self: *@This()) void {
            self.result = self.server.serveOne(std.testing.allocator) catch |err| {
                self.failure = err;
                return;
            };
        }
    };
    var context: Context = .{ .server = &server.? };
    const thread = try std.Thread.spawn(.{}, Context.run, .{&context});
    var client = try Client.init(std.testing.io, .{
        .port = port,
        .auth = .{ .mode = .shared_secret, .credential = "tls-secret" },
        .tls = .{
            .ca_path = certificate,
            .server_name = "localhost",
            .client_certificate_chain_path = certificate,
            .client_private_key_path = key,
        },
    });
    var response = try client.sendAlloc(std.testing.allocator, .{
        .kind = .tell,
        .address = fx.entityAddress("tls-transport", "one"),
        .payload = "encrypted",
        .idempotency_key = "tls-send-1",
    });
    defer response.deinit(std.testing.allocator);
    client.deinit();
    thread.join();
    if (context.failure) |err| return err;
    try std.testing.expectEqualStrings("encrypted", response.envelope.payload);
    try std.testing.expectEqual(@as(usize, 1), context.result.?);
}

test "discovery and credential rotation move live traffic between servers" {
    var first_memory = fx.InMemoryMessageStorage.init(std.testing.allocator);
    defer first_memory.deinit();
    var second_memory = fx.InMemoryMessageStorage.init(std.testing.allocator);
    defer second_memory.deinit();
    var first_handler = try StorageHandler.init(std.testing.allocator, first_memory.asMessageStorage(), 16);
    defer first_handler.deinit();
    var second_handler = try StorageHandler.init(std.testing.allocator, second_memory.asMessageStorage(), 16);
    defer second_handler.deinit();
    var first_server: ?Server = null;
    var first_port: u16 = 26_400;
    while (first_port < 26_450) : (first_port += 1) {
        first_server = Server.init(std.testing.allocator, std.testing.io, .{ .port = first_port, .auth = .{ .mode = .shared_secret, .credential = "old-secret" } }, Handler.from(StorageHandler, &first_handler)) catch |err| switch (err) {
            error.AddressInUse => continue,
            else => return err,
        };
        break;
    }
    if (first_server == null) return error.NoDiscoveryPort;
    defer first_server.?.deinit();
    var second_server: ?Server = null;
    var second_port: u16 = 26_450;
    while (second_port < 26_500) : (second_port += 1) {
        second_server = Server.init(std.testing.allocator, std.testing.io, .{ .port = second_port, .auth = .{ .mode = .shared_secret, .credential = "old-secret" } }, Handler.from(StorageHandler, &second_handler)) catch |err| switch (err) {
            error.AddressInUse => continue,
            else => return err,
        };
        break;
    }
    if (second_server == null) return error.NoDiscoveryPort;
    defer second_server.?.deinit();
    try std.testing.expectEqual(@as(u64, 1), try second_server.?.rotateAuth(.{ .mode = .shared_secret, .credential = "new-secret" }));
    const ServeContext = struct {
        server: *Server,
        handled: ?usize = null,
        failure: ?anyerror = null,
        fn run(self: *@This()) void {
            self.handled = self.server.serveOne(std.testing.allocator) catch |err| {
                self.failure = err;
                return;
            };
        }
    };
    var first_context: ServeContext = .{ .server = &first_server.? };
    var second_context: ServeContext = .{ .server = &second_server.? };
    const first_thread = try std.Thread.spawn(.{}, ServeContext.run, .{&first_context});
    const second_thread = try std.Thread.spawn(.{}, ServeContext.run, .{&second_context});
    var client = try Client.initAlloc(std.testing.allocator, std.testing.io, .{ .port = first_port, .auth = .{ .mode = .shared_secret, .credential = "old-secret" } });
    var first_response = try client.sendAlloc(std.testing.allocator, .{ .kind = .tell, .address = fx.entityAddress("discovery", "first"), .idempotency_key = "discovery-1" });
    defer first_response.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(u64, 1), try client.rotateAuth(.{ .mode = .shared_secret, .credential = "new-secret" }));
    const endpoints = [_]fx.ClusterTransportDiscoveredEndpoint{
        .{ .host = "127.0.0.1", .port = first_port, .healthy = true, .auth_epoch = 1 },
        .{ .host = "127.0.0.1", .port = second_port, .healthy = true, .auth_epoch = 2 },
    };
    try std.testing.expectEqual(@as(u64, 1), try client.refreshDiscovery(.{ .source = "unit", .endpoints = &endpoints }, .{ .require_tls = false, .min_auth_epoch = 2 }));
    var second_response = try client.sendAlloc(std.testing.allocator, .{ .kind = .tell, .address = fx.entityAddress("discovery", "second"), .idempotency_key = "discovery-2" });
    defer second_response.deinit(std.testing.allocator);
    client.deinit();
    first_thread.join();
    second_thread.join();
    if (first_context.failure) |err| return err;
    if (second_context.failure) |err| return err;
    try std.testing.expectEqual(@as(usize, 1), first_context.handled.?);
    try std.testing.expectEqual(@as(usize, 1), second_context.handled.?);
    try std.testing.expectEqual(@as(usize, 1), first_memory.messages.items.len);
    try std.testing.expectEqual(@as(usize, 1), second_memory.messages.items.len);
}
