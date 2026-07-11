const std = @import("std");
const http = @import("zigeffect_http");
const zstd = @import("zigeffect_std");

const SSL_METHOD = opaque {};
const SSL_CTX = opaque {};
const SSL = opaque {};

extern fn TLS_server_method() ?*const SSL_METHOD;
extern fn SSL_CTX_new(method: *const SSL_METHOD) ?*SSL_CTX;
extern fn SSL_CTX_free(ctx: *SSL_CTX) void;
extern fn SSL_CTX_ctrl(ctx: *SSL_CTX, command: c_int, larg: c_long, parg: ?*anyopaque) c_long;
extern fn SSL_CTX_use_certificate_chain_file(ctx: *SSL_CTX, path: [*:0]const u8) c_int;
extern fn SSL_CTX_use_PrivateKey_file(ctx: *SSL_CTX, path: [*:0]const u8, file_type: c_int) c_int;
extern fn SSL_CTX_check_private_key(ctx: *const SSL_CTX) c_int;
extern fn SSL_new(ctx: *SSL_CTX) ?*SSL;
extern fn SSL_free(ssl: *SSL) void;
extern fn SSL_set_fd(ssl: *SSL, fd: c_int) c_int;
extern fn SSL_accept(ssl: *SSL) c_int;
extern fn SSL_read(ssl: *SSL, buffer: *anyopaque, length: c_int) c_int;
extern fn SSL_write(ssl: *SSL, buffer: *const anyopaque, length: c_int) c_int;
extern fn SSL_shutdown(ssl: *SSL) c_int;
extern fn SSL_get_error(ssl: *const SSL, result: c_int) c_int;

const ssl_filetype_pem = 1;
const ssl_ctrl_set_min_proto_version = 123;
const ssl_ctrl_set_max_proto_version = 124;
const tls_1_2_version = 0x0303;
const tls_1_3_version = 0x0304;
const ssl_error_want_read = 2;
const ssl_error_want_write = 3;
const ssl_error_zero_return = 6;

pub const capability = zstd.Capability.Descriptor{
    .id = "zigeffect-http.tls.openssl",
    .kind = .http_server,
    .maturity = .production_candidate,
    .package = "zigeffect-http-tls-openssl",
    .version = "0.1.0",
    .features = &.{ "tls1.2", "tls1.3", "certificate-chain", "private-key-check", "live-loopback" },
    .side_effects = .real,
    .conformance = .{
        .schema = "zigeffect.tls-live-conformance",
        .version = 1,
        .receipt = "conformance/tls-loopback-live.v1.json",
        .authority = .live_external,
        .observed_at_ms = 1783777336000,
        .valid_until_ms = 1791553336000,
        .content_sha256 = "sha256:6fb32bcb3bc3944f45e4101a72587839652a52523d205a5d65a8b05684262990",
    },
    .limitations = &.{"requires a compatible system OpenSSL 3 installation"},
};

pub const Config = struct {
    certificate_chain_path: [:0]const u8,
    private_key_path: [:0]const u8,
    minimum_tls_version: enum { tls_1_2, tls_1_3 } = .tls_1_2,
};

pub const Provider = struct {
    context: *SSL_CTX,

    pub fn init(config: Config) !Provider {
        if (config.certificate_chain_path.len == 0) return error.MissingCertificateChain;
        if (config.private_key_path.len == 0) return error.MissingPrivateKey;
        const method = TLS_server_method() orelse return error.TlsLibraryInitializationFailed;
        const context = SSL_CTX_new(method) orelse return error.TlsContextInitializationFailed;
        errdefer SSL_CTX_free(context);
        const minimum: c_long = switch (config.minimum_tls_version) {
            .tls_1_2 => tls_1_2_version,
            .tls_1_3 => tls_1_3_version,
        };
        if (SSL_CTX_ctrl(context, ssl_ctrl_set_min_proto_version, minimum, null) != 1) return error.TlsPolicyConfigurationFailed;
        if (SSL_CTX_ctrl(context, ssl_ctrl_set_max_proto_version, tls_1_3_version, null) != 1) return error.TlsPolicyConfigurationFailed;
        if (SSL_CTX_use_certificate_chain_file(context, config.certificate_chain_path.ptr) != 1) return error.CertificateLoadFailed;
        if (SSL_CTX_use_PrivateKey_file(context, config.private_key_path.ptr, ssl_filetype_pem) != 1) return error.PrivateKeyLoadFailed;
        if (SSL_CTX_check_private_key(context) != 1) return error.PrivateKeyMismatch;
        return .{ .context = context };
    }

    pub fn deinit(self: *Provider) void {
        SSL_CTX_free(self.context);
        self.* = undefined;
    }

    pub fn asProvider(self: *Provider) http.Tls.Provider {
        return http.Tls.Provider.from(Provider, self);
    }

    pub fn handshakeAlloc(self: *Provider, allocator: std.mem.Allocator, handle: std.Io.net.Socket.Handle) !http.Tls.Connection {
        const state = try allocator.create(ConnectionState);
        errdefer allocator.destroy(state);
        const ssl = SSL_new(self.context) orelse return error.TlsConnectionInitializationFailed;
        errdefer SSL_free(ssl);
        if (SSL_set_fd(ssl, handle) != 1) return error.TlsSocketBindingFailed;
        if (SSL_accept(ssl) != 1) return error.TlsHandshakeFailed;
        state.* = .{ .ssl = ssl };
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
    ssl: *SSL,

    fn read(pointer: *anyopaque, buffer: []u8) !usize {
        const self: *ConnectionState = @ptrCast(@alignCast(pointer));
        if (buffer.len == 0) return 0;
        const length: c_int = @intCast(@min(buffer.len, std.math.maxInt(c_int)));
        const result = SSL_read(self.ssl, buffer.ptr, length);
        if (result > 0) return @intCast(result);
        return switch (SSL_get_error(self.ssl, result)) {
            ssl_error_zero_return => 0,
            ssl_error_want_read, ssl_error_want_write => error.WouldBlock,
            else => error.TlsReadFailed,
        };
    }

    fn write(pointer: *anyopaque, bytes: []const u8) !void {
        const self: *ConnectionState = @ptrCast(@alignCast(pointer));
        var offset: usize = 0;
        while (offset < bytes.len) {
            const length: c_int = @intCast(@min(bytes.len - offset, std.math.maxInt(c_int)));
            const result = SSL_write(self.ssl, bytes[offset..].ptr, length);
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

    fn close(pointer: *anyopaque) void {
        const self: *ConnectionState = @ptrCast(@alignCast(pointer));
        _ = SSL_shutdown(self.ssl);
    }

    fn deinit(pointer: *anyopaque, allocator: std.mem.Allocator) void {
        const self: *ConnectionState = @ptrCast(@alignCast(pointer));
        _ = SSL_shutdown(self.ssl);
        SSL_free(self.ssl);
        allocator.destroy(self);
    }
};

test "OpenSSL TLS provider serves an encrypted certificate-verified HTTP exchange" {
    try capability.validate();
    const Handler = struct {
        pub fn handleAlloc(_: *@This(), allocator: std.mem.Allocator, _: http.Http.Request) !http.Http.Response {
            return http.Http.cloneResponseAlloc(allocator, .{ .status = 200, .body = "tls-live-ok" });
        }
    };
    const ServeContext = struct {
        server: *http.Server,
        report: ?http.ServeReport = null,
        failure: ?anyerror = null,
        fn run(self: *@This()) void {
            self.report = self.server.serveOne(std.testing.allocator) catch |err| {
                self.failure = err;
                return;
            };
        }
    };

    var provider = try Provider.init(.{
        .certificate_chain_path = "tests/fixtures/cert.pem",
        .private_key_path = "tests/fixtures/key.pem",
        .minimum_tls_version = .tls_1_3,
    });
    defer provider.deinit();
    var handler = Handler{};
    var server: ?http.Server = null;
    var port: u16 = 25_000;
    while (port < 25_100) : (port += 1) {
        server = http.Server.init(std.testing.allocator, std.testing.io, .{
            .port = port,
            .tls_provider = provider.asProvider(),
        }, http.Handler.from(Handler, &handler)) catch |err| switch (err) {
            error.AddressInUse => continue,
            else => return err,
        };
        break;
    }
    if (server == null) return error.NoTlsLoopbackPort;
    defer server.?.deinit();
    var serve_context = ServeContext{ .server = &server.? };
    const server_thread = try std.Thread.spawn(.{}, ServeContext.run, .{&serve_context});

    var connect_buffer: [32]u8 = undefined;
    const connect = try std.fmt.bufPrint(&connect_buffer, "127.0.0.1:{d}", .{port});
    var child = try std.process.spawn(std.testing.io, .{
        .argv = &.{ "openssl", "s_client", "-connect", connect, "-servername", "localhost", "-CAfile", "tests/fixtures/cert.pem", "-quiet" },
        .stdin = .pipe,
        .stdout = .pipe,
        .stderr = .ignore,
    });
    defer child.kill(std.testing.io);
    try child.stdin.?.writeStreamingAll(std.testing.io, "GET / HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n");
    child.stdin.?.close(std.testing.io);
    child.stdin = null;
    var stdout_reader = child.stdout.?.readerStreaming(std.testing.io, &.{});
    const response = try stdout_reader.interface.allocRemaining(std.testing.allocator, .limited(4096));
    defer std.testing.allocator.free(response);
    const term = try child.wait(std.testing.io);
    server_thread.join();
    if (serve_context.failure) |err| return err;
    try std.testing.expectEqual(@as(u16, 200), serve_context.report.?.status);
    try std.testing.expect(std.mem.indexOf(u8, response, "HTTP/1.1 200 OK") != null);
    try std.testing.expect(std.mem.endsWith(u8, response, "tls-live-ok"));
    switch (term) {
        .exited => |code| try std.testing.expectEqual(@as(u8, 0), code),
        else => return error.TlsClientFailed,
    }
}
