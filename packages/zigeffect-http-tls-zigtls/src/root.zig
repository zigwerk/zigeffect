//! ZigTLS adapter for the public ZigEffect HTTP TLS provider contract.

const std = @import("std");
const http = @import("zigeffect_http");
const zstd = @import("zigeffect_std");
const zigtls = @import("zigtls");

pub const capability = zstd.Capability.Descriptor{
    .id = "zigeffect-http.tls.zigtls",
    .kind = .http_server,
    .maturity = .local_development,
    .package = "zigeffect-http-tls-zigtls",
    .version = "0.1.0",
    .features = &.{ "tls1.3", "aes-128-gcm", "x25519", "ed25519", "http1.1" },
    .side_effects = .real,
    .limitations = &.{
        "Ed25519 PKCS#8 private keys only",
        "synchronous HTTP/1.1 server provider",
        "live cross-implementation conformance is required before production_candidate",
    },
};

pub const Config = struct {
    certificate_chain_path: []const u8,
    private_key_path: []const u8,
    require_alpn: bool = false,
    allowed_alpn_protocols: []const []const u8 = &.{"http/1.1"},
    max_handshake_iterations: usize = 64,
    max_read_iterations: usize = 64,
    max_write_iterations: usize = 64,

    pub fn validate(self: Config) !void {
        if (self.certificate_chain_path.len == 0) return error.MissingCertificateChain;
        if (self.private_key_path.len == 0) return error.MissingPrivateKey;
        if (self.allowed_alpn_protocols.len == 0) return error.MissingAlpn;
        for (self.allowed_alpn_protocols) |protocol| {
            if (protocol.len == 0 or protocol.len > 255) return error.InvalidAlpn;
        }
        if (self.max_handshake_iterations == 0) return error.InvalidHandshakeLimit;
        if (self.max_read_iterations == 0) return error.InvalidReadLimit;
        if (self.max_write_iterations == 0) return error.InvalidWriteLimit;
    }
};

pub const ProviderConfig = struct {
    io: std.Io,
    tls: Config,
};
pub const ConfigService = zstd.fx.kernel.Service("zigeffect/http/tls/zigtls/Config", ProviderConfig);

pub const ProviderApi = struct {
    pub const operations: []const []const u8 = &.{"TlsProvider.handshake"};
    provider: Provider,
};
pub const ProviderService = zstd.fx.kernel.Service("zigeffect/http/tls/zigtls/Provider", ProviderApi);
pub const HttpProviderService = zstd.fx.kernel.Service("zigeffect/http/TlsProvider", http.Tls.Provider);

pub fn configLayer(config: ProviderConfig) @TypeOf(zstd.fx.kernel.Layer.succeed(ConfigService, config)) {
    return zstd.fx.kernel.Layer.succeed(ConfigService, config);
}

const ProviderLifecycle = struct {
    fn acquire(ctx: *zstd.fx.kernel.ContextView(.{ConfigService})) anyerror!ProviderApi {
        const config = ctx.service(ConfigService).*;
        return .{ .provider = try Provider.init(ctx.allocator(), config.io, config.tls) };
    }

    fn release(api: *ProviderApi) void {
        api.provider.deinit();
    }
};

pub fn providerLayer() @TypeOf(zstd.fx.kernel.Layer.scoped(
    ProviderService,
    anyerror,
    .{ConfigService},
    ProviderLifecycle.acquire,
    ProviderLifecycle.release,
)) {
    return zstd.fx.kernel.Layer.scoped(
        ProviderService,
        anyerror,
        .{ConfigService},
        ProviderLifecycle.acquire,
        ProviderLifecycle.release,
    );
}

const HttpProviderFactory = struct {
    fn make(ctx: *zstd.fx.kernel.ContextView(.{ProviderService})) http.Tls.Provider {
        return ctx.service(ProviderService).provider.asProvider();
    }
};

pub fn httpProviderLayer() @TypeOf(zstd.fx.kernel.Layer.sync(
    HttpProviderService,
    .{ProviderService},
    HttpProviderFactory.make,
)) {
    return zstd.fx.kernel.Layer.sync(HttpProviderService, .{ProviderService}, HttpProviderFactory.make);
}

pub fn configuredProviderLayer(config: ProviderConfig) @TypeOf(
    httpProviderLayer().provideMerge(providerLayer().provideMerge(configLayer(config))),
) {
    return httpProviderLayer().provideMerge(providerLayer().provideMerge(configLayer(config)));
}

pub const Provider = struct {
    allocator: std.mem.Allocator,
    io: std.Io,
    credentials: zigtls.cert_reload.Ed25519ServerCredentialsBundle,
    config: Config,

    pub fn init(allocator: std.mem.Allocator, io: std.Io, config: Config) !Provider {
        try config.validate();
        var store = zigtls.cert_reload.Store.init(allocator);
        defer store.deinit();
        _ = try store.reloadFromFilesIo(
            io,
            std.Io.Dir.cwd(),
            config.certificate_chain_path,
            config.private_key_path,
        );
        return .{
            .allocator = allocator,
            .io = io,
            .credentials = try store.loadActiveEd25519Bundle(allocator),
            .config = config,
        };
    }

    pub fn deinit(self: *Provider) void {
        self.credentials.deinit(self.allocator);
        self.* = undefined;
    }

    pub fn asProvider(self: *Provider) http.Tls.Provider {
        return http.Tls.Provider.from(Provider, self);
    }

    pub fn handshakeAlloc(self: *Provider, allocator: std.mem.Allocator, handle: std.Io.net.Socket.Handle) !http.Tls.Connection {
        const state = try allocator.create(ConnectionState);
        errdefer allocator.destroy(state);
        state.io = self.io;
        state.handle = handle;
        state.max_read_iterations = self.config.max_read_iterations;
        state.max_write_iterations = self.config.max_write_iterations;
        state.closed = false;
        state.connection = try zigtls.termination.Connection.initChecked(allocator, .{
            .session = .{
                .role = .server,
                .suite = .tls_aes_128_gcm_sha256,
                .server_credentials = self.credentials.serverCredentials(),
            },
            .client_hello_policy = .{
                .require_alpn = self.config.require_alpn,
                .allowed_alpn_protocols = self.config.allowed_alpn_protocols,
            },
        });
        errdefer state.connection.deinit();
        state.adapter = zigtls.adapter.EventLoopAdapter.init(allocator, &state.connection, state.transport());
        errdefer state.adapter.deinit();
        state.connection.accept(.{});
        try state.completeHandshake(self.config.max_handshake_iterations);
        return .{
            .pointer = state,
            .read_fn = ConnectionState.read,
            .write_fn = ConnectionState.write,
            .close_fn = ConnectionState.close,
            .deinit_fn = ConnectionState.deinit,
        };
    }
};

const ConnectionState = struct {
    io: std.Io,
    handle: std.Io.net.Socket.Handle,
    connection: zigtls.termination.Connection,
    adapter: zigtls.adapter.EventLoopAdapter,
    max_read_iterations: usize,
    max_write_iterations: usize,
    closed: bool,

    fn transport(self: *ConnectionState) zigtls.adapter.Transport {
        return .{
            .userdata = @intFromPtr(self),
            .read_fn = transportRead,
            .write_fn = transportWrite,
        };
    }

    fn transportRead(userdata: usize, out: []u8) anyerror!usize {
        const self: *ConnectionState = @ptrFromInt(userdata);
        var parts = [_][]u8{out};
        return self.io.vtable.netRead(self.io.userdata, self.handle, &parts);
    }

    fn transportWrite(userdata: usize, bytes: []const u8) anyerror!usize {
        const self: *ConnectionState = @ptrFromInt(userdata);
        const parts = [_][]const u8{bytes};
        return self.io.vtable.netWrite(self.io.userdata, self.handle, "", &parts, 1);
    }

    fn completeHandshake(self: *ConnectionState, limit: usize) !void {
        var iteration: usize = 0;
        while (iteration < limit) : (iteration += 1) {
            if (self.connection.engine.machine.state == .connected) return;
            const ingress = try self.adapter.pumpRead(1);
            try self.flushPending();
            if (self.connection.engine.machine.state == .connected) return;
            if (ingress.would_block) std.Thread.yield() catch {};
        }
        return error.TlsHandshakeIterationLimitExceeded;
    }

    fn flushPending(self: *ConnectionState) !void {
        var iteration: usize = 0;
        while (iteration < self.max_write_iterations) : (iteration += 1) {
            const result = try self.adapter.flushWrite(1);
            if (result.would_block) {
                std.Thread.yield() catch {};
                continue;
            }
            if (result.bytes_written == 0) return;
        }
        return error.TlsWriteIterationLimitExceeded;
    }

    fn read(pointer: *anyopaque, buffer: []u8) !usize {
        const self: *ConnectionState = @ptrCast(@alignCast(pointer));
        if (buffer.len == 0) return 0;
        const buffered = self.connection.read_plaintext(buffer);
        if (buffered != 0) return buffered;
        var iteration: usize = 0;
        while (iteration < self.max_read_iterations) : (iteration += 1) {
            const ingress = try self.adapter.pumpRead(1);
            try self.flushPending();
            const count = self.connection.read_plaintext(buffer);
            if (count != 0) return count;
            if (ingress.would_block) std.Thread.yield() catch {};
        }
        return error.TlsReadIterationLimitExceeded;
    }

    fn write(pointer: *anyopaque, bytes: []const u8) !void {
        const self: *ConnectionState = @ptrCast(@alignCast(pointer));
        _ = try self.connection.write_plaintext(bytes);
        try self.flushPending();
    }

    fn close(pointer: *anyopaque) void {
        const self: *ConnectionState = @ptrCast(@alignCast(pointer));
        if (self.closed) return;
        self.connection.shutdown() catch {};
        self.flushPending() catch {};
        self.closed = true;
    }

    fn deinit(pointer: *anyopaque, allocator: std.mem.Allocator) void {
        const self: *ConnectionState = @ptrCast(@alignCast(pointer));
        close(self);
        self.adapter.deinit();
        self.connection.deinit();
        allocator.destroy(self);
    }
};
