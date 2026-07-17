const std = @import("std");
const zstd = @import("zigeffect_std");
const build_options = @import("build_options");
const c = @cImport({
    @cInclude("nghttp2/nghttp2.h");
});

const SSL_METHOD = opaque {};
const SSL_CTX = opaque {};
const SSL = opaque {};
extern fn TLS_server_method() ?*const SSL_METHOD;
extern fn TLS_client_method() ?*const SSL_METHOD;
extern fn SSL_CTX_new(method: *const SSL_METHOD) ?*SSL_CTX;
extern fn SSL_CTX_up_ref(context: *SSL_CTX) c_int;
extern fn SSL_CTX_free(context: *SSL_CTX) void;
extern fn SSL_CTX_ctrl(context: *SSL_CTX, command: c_int, larg: c_long, parg: ?*anyopaque) c_long;
extern fn SSL_CTX_use_certificate_chain_file(context: *SSL_CTX, path: [*:0]const u8) c_int;
extern fn SSL_CTX_use_PrivateKey_file(context: *SSL_CTX, path: [*:0]const u8, file_type: c_int) c_int;
extern fn SSL_CTX_check_private_key(context: *const SSL_CTX) c_int;
extern fn SSL_CTX_load_verify_locations(context: *SSL_CTX, ca_file: ?[*:0]const u8, ca_path: ?[*:0]const u8) c_int;
extern fn SSL_CTX_set_default_verify_paths(context: *SSL_CTX) c_int;
const VerifyCallback = ?*const fn (c_int, ?*anyopaque) callconv(.c) c_int;
extern fn SSL_CTX_set_verify(context: *SSL_CTX, mode: c_int, callback: VerifyCallback) void;
extern fn SSL_CTX_set_alpn_protos(context: *SSL_CTX, protocols: [*]const u8, protocols_len: c_uint) c_int;
const AlpnSelectCallback = ?*const fn (*SSL, *[*]const u8, *u8, [*]const u8, c_uint, ?*anyopaque) callconv(.c) c_int;
extern fn SSL_CTX_set_alpn_select_cb(context: *SSL_CTX, callback: AlpnSelectCallback, arg: ?*anyopaque) void;
extern fn SSL_select_next_proto(out: *[*]const u8, out_len: *u8, server: [*]const u8, server_len: c_uint, client: [*]const u8, client_len: c_uint) c_int;
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
extern fn SSL_get0_alpn_selected(ssl: *const SSL, data: *[*]const u8, length: *c_uint) void;

const ssl_filetype_pem = 1;
const ssl_verify_peer: c_int = 1;
const ssl_verify_fail_if_no_peer_cert: c_int = 2;
const ssl_ctrl_set_min_proto_version = 123;
const ssl_ctrl_set_max_proto_version = 124;
const ssl_ctrl_set_tlsext_hostname = 55;
const tls_1_2_version = 0x0303;
const tls_1_3_version = 0x0304;
const ssl_error_want_read = 2;
const ssl_error_want_write = 3;
const ssl_error_zero_return = 6;
const x509_v_ok = 0;
const openssl_npn_negotiated = 1;
const ssl_tlsext_err_ok = 0;
const h2_alpn = "\x02h2";

pub const Grpc = zstd.Grpc;
pub const Typed = @import("typed.zig");
pub const Compression = @import("compression.zig");
pub const Connect = @import("connect.zig");
pub const Middleware = @import("middleware.zig");
pub const Iap = @import("iap.zig");
pub const Oidc = @import("oidc.zig");
pub const Otlp = @import("otlp.zig");
pub const Incremental = @import("incremental.zig");
pub const Channel = @import("channel.zig");
pub const Channelz = @import("channelz.zig");
pub const Credentials = @import("credentials.zig");
pub const HealthProto = @import("generated/grpc/health/v1.pb.zig");
pub const ChannelzProto = @import("generated/grpc/channelz/v1.pb.zig");
pub const ReflectionProto = @import("generated/grpc/reflection/v1.pb.zig");
pub const ReflectionV1AlphaProto = @import("generated/grpc/reflection/v1alpha.pb.zig");
pub const StandardServices = @import("standard_services.zig");
pub const ConformanceProto = @import("generated/zigeffect/grpc/v1.pb.zig");
pub const OfficialInteropProto = @import("generated/grpc/testing.pb.zig");
pub const ConnectConformanceProto = @import("generated/connectrpc/conformance/v1.pb.zig");

const inspected_conformance = zstd.Capability.Conformance{
    .schema = "zigeffect.grpc-live-conformance",
    .version = 2,
    .receipt = "conformance/grpc-live.v2.candidate.json",
    .authority = .live_external,
    .observed_at_ms = 1783960118311,
    .valid_until_ms = 1791736118311,
    .content_sha256 = "sha256:c798975730df885adbae37ccb0910fcfe339cb5a8e25ee732e3cacbe0cfc83fd",
};

pub const ephemeral_client_capability = zstd.Capability.Descriptor{
    .id = "zigeffect-grpc.ephemeral-client",
    .kind = .grpc_client,
    .maturity = .production_candidate,
    .package = "zigeffect-grpc",
    .version = "0.1.0",
    .features = &.{ "grpc", "unary", "client-streaming", "server-streaming", "bidirectional-streaming", "http2", "hpack", "trailers", "deadlines", "cancellation", "tls1.2", "tls1.3", "alpn-h2", "gzip", "deflate", "bounded-messages", "external-interoperability" },
    .targets = &.{ "aarch64-macos", "aarch64-linux" },
    .side_effects = .real,
    .conformance = inspected_conformance,
    .limitations = &.{
        "each ordinary NativeClient call opens a connection; use PersistentChannel or ChannelPool for reuse",
        "native Linux amd64 and the 24-hour campaign remain release-promotion gates",
    },
};

/// Backward-compatible default descriptor. New requirement manifests should
/// select the specific capability slice they use.
pub const capability = ephemeral_client_capability;

pub const server_capability = zstd.Capability.Descriptor{
    .id = "zigeffect-grpc.native-server",
    .kind = .grpc_server,
    .maturity = .production_candidate,
    .package = "zigeffect-grpc",
    .version = "0.1.0",
    .features = &.{ "grpc", "unary", "client-streaming", "server-streaming", "bidirectional-streaming", "http2", "hpack", "trailers", "deadlines", "tls1.2", "tls1.3", "alpn-h2", "multiplexing", "bounded-messages", "health-watch-live", "reflection-v1", "reflection-v1alpha", "channelz", "external-interoperability" },
    .targets = &.{ "aarch64-macos", "aarch64-linux" },
    .side_effects = .real,
    .conformance = inspected_conformance,
    .limitations = &.{"native Linux amd64 and the 24-hour campaign remain release-promotion gates"},
};

pub const persistent_channel_capability = zstd.Capability.Descriptor{
    .id = "zigeffect-grpc.persistent-channel",
    .kind = .grpc_client,
    .maturity = .production_candidate,
    .package = "zigeffect-grpc",
    .version = "0.1.0",
    .features = &.{ "persistent-channels", "connection-reuse", "multiplexing", "concurrent-calls", "reconnection", "dns", "round-robin", "service-config", "retry-throttling", "retry-pushback", "safe-method-hedging", "client-health-watch", "wait-for-ready", "acknowledged-keepalive-ping", "channel-snapshots", "subchannel-snapshots", "channelz", "cloud-run-id-token" },
    .targets = &.{ "aarch64-macos", "aarch64-linux" },
    .side_effects = .real,
    .conformance = inspected_conformance,
    .limitations = &.{"the 24-hour campaign remains a release-promotion gate"},
};

pub const incremental_streaming_capability = zstd.Capability.Descriptor{
    .id = "zigeffect-grpc.incremental-streaming",
    .kind = .stream,
    .maturity = .production_candidate,
    .package = "zigeffect-grpc",
    .version = "0.1.0",
    .features = &.{ "client-streaming", "server-streaming", "bidirectional-streaming", "incremental-backpressure", "canonical-stream-trailers", "half-close", "stream-cancellation", "client-interceptors", "bounded-queues" },
    .targets = &.{ "aarch64-macos", "aarch64-linux" },
    .side_effects = .real,
    .conformance = inspected_conformance,
    .limitations = &.{"the 24-hour campaign remains a release-promotion gate"},
};

pub const connect_server_capability = zstd.Capability.Descriptor{
    .id = "zigeffect-grpc.connect-server",
    .kind = .web_transport,
    .maturity = .production_candidate,
    .package = "zigeffect-grpc",
    .version = "0.1.0",
    .features = &.{ "connect-v1", "protobuf", "unary", "server-streaming", "incremental-streaming", "incremental-backpressure", "stream-cancellation", "metadata", "end-stream-metadata", "connect-timeout", "compression", "cors", "canonical-errors", "solid-query" },
    .targets = &.{ "aarch64-macos", "aarch64-linux" },
    .side_effects = .real,
    .conformance = inspected_conformance,
    .limitations = &.{"the 24-hour campaign remains a release-promotion gate"},
};

pub const connect_client_capability = zstd.Capability.Descriptor{
    .id = "zigeffect-grpc.connect-client",
    .kind = .web_transport,
    .maturity = .production_candidate,
    .package = "zigeffect-grpc",
    .version = "0.1.0",
    .features = &.{ "connect-v1", "protobuf", "unary", "http1.1", "plaintext", "metadata", "binary-metadata", "connect-timeout", "cancellation", "canonical-errors", "bounded-messages" },
    .targets = &.{ "aarch64-macos", "aarch64-linux" },
    .side_effects = .real,
    .conformance = inspected_conformance,
    .limitations = &.{ "native Connect client HTTP/2, TLS, GET, compression, and streaming are explicitly unsupported", "the 24-hour campaign remains a release-promotion gate" },
};

pub const generated_bindings_capability = zstd.Capability.Descriptor{
    .id = "zigeffect-grpc.generated-bindings",
    .kind = .grpc_client,
    .maturity = .production_candidate,
    .package = "zigeffect-grpc",
    .version = "0.1.0",
    .features = &.{ "protobuf-codegen", "typed-bindings", "typed-client", "typed-server", "all-call-shapes", "owned-status", "maps", "oneofs", "proto3-optional", "well-known-types", "unknown-fields", "buf-lint", "buf-breaking", "solid-query" },
    .targets = &.{ "aarch64-macos", "aarch64-linux" },
    .side_effects = .real,
    .conformance = inspected_conformance,
    .limitations = &.{"the 24-hour campaign remains a release-promotion gate"},
};

pub const cloud_run_capability = zstd.Capability.Descriptor{
    .id = "zigeffect-grpc.cloud-run",
    .kind = .grpc_server,
    .maturity = .production_candidate,
    .package = "zigeffect-grpc",
    .version = "0.1.0",
    .features = &.{ "cloud-run-h2c", "cloud-run-graceful-shutdown", "cloud-run-id-token", "health-watch-live", "reflection-v1", "reflection-v1alpha", "channelz", "tls", "mtls", "iap-es256", "oidc-es256", "oidc-rs256", "otlp-http-json", "otlp-direct-tls", "otlp-auth-headers", "mixed-shape-load" },
    .targets = &.{"aarch64-linux-container"},
    .side_effects = .real,
    .conformance = inspected_conformance,
    .limitations = &.{ "a deployed GCP Cloud Run receipt and the 24-hour campaign remain release-promotion gates", "verified OTLP TLS is covered locally rather than against a public collector" },
};

pub const Limits = struct {
    grpc: Grpc.Limits = .{},
    max_wire_read_bytes: usize = 64 * 1024,
    max_header_count: usize = 128,
    max_header_bytes: usize = 16 * 1024,

    pub fn validate(self: Limits) !void {
        try self.grpc.validate();
        if (self.max_wire_read_bytes < 9 or self.max_header_count == 0 or self.max_header_bytes < 1024) return error.InvalidLimits;
    }
};

const Wire = struct {
    pointer: *anyopaque,
    read_fn: *const fn (*anyopaque, []u8) anyerror!usize,
    write_fn: *const fn (*anyopaque, []const u8) anyerror!void,
    cancel_fn: *const fn (*anyopaque) void,
    close_fn: *const fn (*anyopaque) void,
    socket_handle_fn: *const fn (*anyopaque) std.posix.fd_t,

    fn read(self: Wire, buffer: []u8) !usize {
        return self.read_fn(self.pointer, buffer);
    }

    fn writeAll(self: Wire, bytes: []const u8) !void {
        return self.write_fn(self.pointer, bytes);
    }

    fn close(self: Wire) void {
        self.close_fn(self.pointer);
    }

    fn cancelRead(self: Wire) void {
        self.cancel_fn(self.pointer);
    }

    fn socketHandle(self: Wire) std.posix.fd_t {
        return self.socket_handle_fn(self.pointer);
    }
};

const PlainWire = struct {
    io: std.Io,
    stream: std.Io.net.Stream,

    fn wire(self: *PlainWire) Wire {
        return .{ .pointer = self, .read_fn = read, .write_fn = write, .cancel_fn = cancel, .close_fn = close, .socket_handle_fn = socketHandle };
    }

    fn read(pointer: *anyopaque, buffer: []u8) !usize {
        const self: *PlainWire = @ptrCast(@alignCast(pointer));
        var parts = [_][]u8{buffer};
        return self.io.vtable.netRead(self.io.userdata, self.stream.socket.handle, &parts);
    }

    fn write(pointer: *anyopaque, bytes: []const u8) !void {
        const self: *PlainWire = @ptrCast(@alignCast(pointer));
        var offset: usize = 0;
        while (offset < bytes.len) {
            const parts = [_][]const u8{bytes[offset..]};
            const count = try self.io.vtable.netWrite(self.io.userdata, self.stream.socket.handle, "", &parts, 1);
            if (count == 0) return error.ConnectionClosed;
            offset += count;
        }
    }

    fn close(pointer: *anyopaque) void {
        const self: *PlainWire = @ptrCast(@alignCast(pointer));
        self.stream.close(self.io);
    }

    fn cancel(pointer: *anyopaque) void {
        const self: *PlainWire = @ptrCast(@alignCast(pointer));
        self.stream.shutdown(self.io, .recv) catch {};
    }

    fn socketHandle(pointer: *anyopaque) std.posix.fd_t {
        return (@as(*PlainWire, @ptrCast(@alignCast(pointer)))).stream.socket.handle;
    }
};

const TlsWire = struct {
    io: std.Io,
    stream: std.Io.net.Stream,
    ssl: *SSL,

    fn wire(self: *TlsWire) Wire {
        return .{ .pointer = self, .read_fn = read, .write_fn = write, .cancel_fn = cancel, .close_fn = close, .socket_handle_fn = socketHandle };
    }

    fn read(pointer: *anyopaque, buffer: []u8) !usize {
        const self: *TlsWire = @ptrCast(@alignCast(pointer));
        if (buffer.len == 0) return 0;
        while (true) {
            const result = SSL_read(self.ssl, buffer.ptr, @intCast(@min(buffer.len, std.math.maxInt(c_int))));
            if (result > 0) return @intCast(result);
            switch (SSL_get_error(self.ssl, result)) {
                ssl_error_zero_return => return 0,
                ssl_error_want_read, ssl_error_want_write => continue,
                else => return error.TlsReadFailed,
            }
        }
    }

    fn write(pointer: *anyopaque, bytes: []const u8) !void {
        const self: *TlsWire = @ptrCast(@alignCast(pointer));
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

    fn close(pointer: *anyopaque) void {
        const self: *TlsWire = @ptrCast(@alignCast(pointer));
        _ = SSL_shutdown(self.ssl);
        SSL_free(self.ssl);
        self.stream.close(self.io);
    }

    fn cancel(pointer: *anyopaque) void {
        const self: *TlsWire = @ptrCast(@alignCast(pointer));
        self.stream.shutdown(self.io, .recv) catch {};
    }

    fn socketHandle(pointer: *anyopaque) std.posix.fd_t {
        return (@as(*TlsWire, @ptrCast(@alignCast(pointer)))).stream.socket.handle;
    }
};

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
    certificate_chain_path: ?[:0]const u8 = null,
    private_key_path: ?[:0]const u8 = null,

    pub fn validate(self: ClientTlsConfig) !void {
        if (self.server_name.len == 0) return error.MissingServerName;
        if ((self.certificate_chain_path == null) != (self.private_key_path == null)) return error.IncompleteClientIdentity;
    }
};

fn configureTlsVersion(context: *SSL_CTX) !void {
    if (SSL_CTX_ctrl(context, ssl_ctrl_set_min_proto_version, tls_1_2_version, null) != 1) return error.TlsVersionConfigurationFailed;
    if (SSL_CTX_ctrl(context, ssl_ctrl_set_max_proto_version, tls_1_3_version, null) != 1) return error.TlsVersionConfigurationFailed;
}

fn alpnSelect(_: *SSL, out: *[*]const u8, out_len: *u8, input: [*]const u8, input_len: c_uint, _: ?*anyopaque) callconv(.c) c_int {
    return if (SSL_select_next_proto(out, out_len, h2_alpn.ptr, h2_alpn.len, input, input_len) == openssl_npn_negotiated)
        ssl_tlsext_err_ok
    else
        3;
}

fn createServerTlsContext(config: ServerTlsConfig) !*SSL_CTX {
    try config.validate();
    const method = TLS_server_method() orelse return error.TlsMethodUnavailable;
    const context = SSL_CTX_new(method) orelse return error.TlsContextInitializationFailed;
    errdefer SSL_CTX_free(context);
    try configureTlsVersion(context);
    if (SSL_CTX_use_certificate_chain_file(context, config.certificate_chain_path.ptr) != 1) return error.TlsCertificateLoadFailed;
    if (SSL_CTX_use_PrivateKey_file(context, config.private_key_path.ptr, ssl_filetype_pem) != 1) return error.TlsPrivateKeyLoadFailed;
    if (SSL_CTX_check_private_key(context) != 1) return error.TlsPrivateKeyMismatch;
    if (config.client_ca_path) |ca| {
        if (SSL_CTX_load_verify_locations(context, ca.ptr, null) != 1) return error.TlsClientCaLoadFailed;
        SSL_CTX_set_verify(context, ssl_verify_peer | if (config.require_client_certificate) ssl_verify_fail_if_no_peer_cert else 0, null);
    }
    SSL_CTX_set_alpn_select_cb(context, alpnSelect, null);
    return context;
}

fn createClientTlsContext(config: ClientTlsConfig) !*SSL_CTX {
    try config.validate();
    const method = TLS_client_method() orelse return error.TlsMethodUnavailable;
    const context = SSL_CTX_new(method) orelse return error.TlsContextInitializationFailed;
    errdefer SSL_CTX_free(context);
    try configureTlsVersion(context);
    if (config.ca_path) |ca| {
        if (SSL_CTX_load_verify_locations(context, ca.ptr, null) != 1) return error.TlsCaLoadFailed;
    } else if (SSL_CTX_set_default_verify_paths(context) != 1) return error.TlsDefaultCaLoadFailed;
    if (config.certificate_chain_path) |certificate| {
        if (SSL_CTX_use_certificate_chain_file(context, certificate.ptr) != 1) return error.TlsClientCertificateLoadFailed;
        if (SSL_CTX_use_PrivateKey_file(context, config.private_key_path.?.ptr, ssl_filetype_pem) != 1) return error.TlsClientPrivateKeyLoadFailed;
        if (SSL_CTX_check_private_key(context) != 1) return error.TlsClientPrivateKeyMismatch;
    }
    SSL_CTX_set_verify(context, ssl_verify_peer, null);
    if (SSL_CTX_set_alpn_protos(context, h2_alpn.ptr, h2_alpn.len) != 0) return error.TlsAlpnConfigurationFailed;
    return context;
}

fn requireH2(ssl: *SSL) !void {
    var selected: [*]const u8 = undefined;
    var length: c_uint = 0;
    SSL_get0_alpn_selected(ssl, &selected, &length);
    if (length != 2 or !std.mem.eql(u8, selected[0..length], "h2")) return error.TlsAlpnNegotiationFailed;
}

fn configureTcpNoDelay(handle: std.posix.socket_t, enabled: bool) !void {
    const value: c_int = @intFromBool(enabled);
    try std.posix.setsockopt(
        handle,
        std.posix.IPPROTO.TCP,
        std.posix.TCP.NODELAY,
        std.mem.asBytes(&value),
    );
}

fn checkNghttp(result: anytype) !void {
    if (result < 0) return error.Http2Failure;
}

fn flushSession(session: *c.nghttp2_session, wire: Wire) !void {
    // nghttp2 exposes one serialized frame at a time. Writing each fragment
    // separately turns a unary response (headers, DATA, trailers) into several
    // tiny TCP/TLS writes. Coalesce one flush cycle without heap allocation.
    var pending: [64 * 1024]u8 = undefined;
    var pending_len: usize = 0;
    while (true) {
        var data: [*c]const u8 = null;
        const length = c.nghttp2_session_mem_send(session, &data);
        if (length < 0) return error.Http2SendFailure;
        if (length == 0) {
            if (pending_len != 0) try wire.writeAll(pending[0..pending_len]);
            return;
        }
        const bytes = data[0..@intCast(length)];
        if (bytes.len > pending.len) {
            if (pending_len != 0) {
                try wire.writeAll(pending[0..pending_len]);
                pending_len = 0;
            }
            try wire.writeAll(bytes);
            continue;
        }
        if (pending_len + bytes.len > pending.len) {
            try wire.writeAll(pending[0..pending_len]);
            pending_len = 0;
        }
        @memcpy(pending[pending_len .. pending_len + bytes.len], bytes);
        pending_len += bytes.len;
    }
}

fn receiveSession(session: *c.nghttp2_session, wire: Wire, buffer: []u8) !usize {
    const count = try wire.read(buffer);
    if (count == 0) return error.ConnectionClosed;
    const consumed = c.nghttp2_session_mem_recv(session, buffer.ptr, count);
    if (consumed < 0 or consumed != count) return error.Http2ReceiveFailure;
    try flushSession(session, wire);
    return count;
}

/// A non-blocking self-pipe makes handler-to-transport notifications visible
/// to the same `poll(2)` call as socket readiness. Writes deliberately
/// coalesce when the pipe is full; one readable byte is enough to make the
/// connection worker drain every ready stream.
const NotificationWakeup = struct {
    read_fd: std.posix.fd_t,
    write_fd: std.posix.fd_t,

    fn init() !NotificationWakeup {
        const fds = try std.Io.Threaded.pipe2(.{ .NONBLOCK = true, .CLOEXEC = true });
        return .{ .read_fd = fds[0], .write_fd = fds[1] };
    }

    fn deinit(self: *NotificationWakeup) void {
        std.Io.Threaded.closeFd(self.read_fd);
        std.Io.Threaded.closeFd(self.write_fd);
        self.* = undefined;
    }

    fn signal(self: *NotificationWakeup) void {
        const byte = [_]u8{1};
        while (true) switch (std.posix.errno(std.posix.system.write(self.write_fd, &byte, byte.len))) {
            .SUCCESS, .AGAIN => return,
            .INTR => continue,
            else => return,
        };
    }

    fn drain(self: *NotificationWakeup) void {
        var buffer: [256]u8 = undefined;
        while (true) {
            const count = std.posix.read(self.read_fd, &buffer) catch |err| switch (err) {
                error.WouldBlock => return,
                else => return,
            };
            if (count < buffer.len) return;
        }
    }
};

test "incremental transport wakeup coalesces notifications without timer polling" {
    var wakeup = try NotificationWakeup.init();
    defer wakeup.deinit();
    for (0..10_000) |_| wakeup.signal();
    var descriptors = [_]std.posix.pollfd{.{
        .fd = wakeup.read_fd,
        .events = std.posix.POLL.IN,
        .revents = 0,
    }};
    try std.testing.expectEqual(@as(usize, 1), try std.posix.poll(&descriptors, 0));
    wakeup.drain();
    descriptors[0].revents = 0;
    try std.testing.expectEqual(@as(usize, 0), try std.posix.poll(&descriptors, 0));
}

test "grpc sockets default to tcp nodelay" {
    try std.testing.expect((ClientOptions{}).tcp_nodelay);
    try std.testing.expect((ServerOptions{}).tcp_nodelay);
    const address = try std.Io.net.IpAddress.resolve(std.testing.io, "127.0.0.1", 0);
    var listener = try address.listen(std.testing.io, .{ .reuse_address = true });
    defer listener.deinit(std.testing.io);
    try configureTcpNoDelay(listener.socket.handle, true);
}

test "one HTTP2 flush coalesces pending control frames into one write" {
    const CountingWire = struct {
        writes: usize = 0,
        bytes: usize = 0,

        fn wire(self: *@This()) Wire {
            return .{
                .pointer = self,
                .read_fn = read,
                .write_fn = write,
                .cancel_fn = cancel,
                .close_fn = close,
                .socket_handle_fn = socketHandle,
            };
        }

        fn read(_: *anyopaque, _: []u8) anyerror!usize {
            return error.UnexpectedRead;
        }

        fn write(pointer: *anyopaque, bytes: []const u8) anyerror!void {
            const self: *@This() = @ptrCast(@alignCast(pointer));
            self.writes += 1;
            self.bytes += bytes.len;
        }

        fn cancel(_: *anyopaque) void {}
        fn close(_: *anyopaque) void {}
        fn socketHandle(_: *anyopaque) std.posix.fd_t {
            return -1;
        }
    };

    var callbacks: ?*c.nghttp2_session_callbacks = null;
    try checkNghttp(c.nghttp2_session_callbacks_new(&callbacks));
    defer c.nghttp2_session_callbacks_del(callbacks);
    var maybe_session: ?*c.nghttp2_session = null;
    try checkNghttp(c.nghttp2_session_server_new(&maybe_session, callbacks, null));
    const session = maybe_session orelse return error.Http2InitializationFailed;
    defer c.nghttp2_session_del(session);
    try checkNghttp(c.nghttp2_submit_settings(session, c.NGHTTP2_FLAG_NONE, null, 0));
    try checkNghttp(c.nghttp2_submit_ping(session, c.NGHTTP2_FLAG_NONE, null));
    try checkNghttp(c.nghttp2_submit_goaway(session, c.NGHTTP2_FLAG_NONE, 0, c.NGHTTP2_NO_ERROR, null, 0));

    var counting = CountingWire{};
    try flushSession(session, counting.wire());
    try std.testing.expect(counting.bytes > 0);
    try std.testing.expectEqual(@as(usize, 1), counting.writes);
}

test "identity unary frame decoding borrows the validated payload" {
    const framed = try Grpc.frameMessageAlloc(std.testing.allocator, "payload", .{});
    defer std.testing.allocator.free(framed);
    var decoded = try decodeUnaryBody(std.testing.allocator, framed, .identity, .{});
    defer decoded.deinit();
    try std.testing.expectEqual(@intFromPtr(framed.ptr + 5), @intFromPtr(decoded.bytes.ptr));
    try std.testing.expectEqualStrings("payload", decoded.bytes);
}

test "server flow control advertises production windows above the 64 KiB cliff" {
    const options = ServerOptions{};
    const settings = serverSettings(options);
    try std.testing.expectEqual(c.NGHTTP2_SETTINGS_MAX_CONCURRENT_STREAMS, settings[0].settings_id);
    try std.testing.expectEqual(c.NGHTTP2_SETTINGS_INITIAL_WINDOW_SIZE, settings[1].settings_id);
    try std.testing.expectEqual(@as(u32, 4 * 1024 * 1024), settings[1].value);
    try std.testing.expect(options.initial_connection_window_bytes >= options.initial_stream_window_bytes);
}

test "handler executor reuses a bounded worker set" {
    const Probe = struct {
        io: std.Io,
        expected: usize,
        completed: std.atomic.Value(usize) = .init(0),
        done: std.Io.Event = .unset,

        fn run(pointer: *anyopaque) void {
            const self: *@This() = @ptrCast(@alignCast(pointer));
            if (self.completed.fetchAdd(1, .acq_rel) + 1 == self.expected) self.done.set(self.io);
        }
    };
    var executor = try HandlerExecutor.create(std.testing.allocator, std.testing.io, 2, 64, 512 * 1024);
    defer executor.destroy();
    var probe = Probe{ .io = std.testing.io, .expected = 100 };
    for (0..probe.expected) |_| try executor.schedule(.{ .pointer = &probe, .run_fn = Probe.run });
    probe.done.waitUncancelable(std.testing.io);
    try std.testing.expectEqual(@as(usize, 100), probe.completed.load(.acquire));
    try std.testing.expectEqual(@as(usize, 2), executor.workerCount());
}

/// Resolves DNS names through Zig's cancellable host lookup and tries every
/// returned address. Numeric IPv4/IPv6 literals stay on the allocation-free
/// fast path. This is deliberately shared by ephemeral and persistent clients.
fn connectHost(io: std.Io, host: []const u8, port: u16, tcp_nodelay: bool) !std.Io.net.Stream {
    if (std.Io.net.IpAddress.resolve(io, host, port)) |address| {
        const stream = try address.connect(io, .{ .mode = .stream });
        errdefer stream.close(io);
        try configureTcpNoDelay(stream.socket.handle, tcp_nodelay);
        return stream;
    } else |_| {}

    const host_name = try std.Io.net.HostName.init(host);
    var lookup_storage: [32]std.Io.net.HostName.LookupResult = undefined;
    var results = std.Io.Queue(std.Io.net.HostName.LookupResult).init(&lookup_storage);
    try host_name.lookup(io, &results, .{ .port = port });
    var saw_address = false;
    while (results.getOne(io)) |result| switch (result) {
        .canonical_name => {},
        .address => |address| {
            saw_address = true;
            if (address.connect(io, .{ .mode = .stream })) |stream| {
                configureTcpNoDelay(stream.socket.handle, tcp_nodelay) catch {
                    stream.close(io);
                    continue;
                };
                return stream;
            } else |_| {}
        },
    } else |err| switch (err) {
        error.Closed => {},
        else => return err,
    }
    return if (saw_address) error.AllResolvedAddressesFailed else error.NoAddressReturned;
}

fn receiveServerEvent(session: *c.nghttp2_session, connection: *ServerConnection, wire: Wire, buffer: []u8) !void {
    // Ordinary idle connections stay on the direct read path. Once a unary
    // job or incremental call is live, poll the socket and the shared handler
    // wakeup together so nghttp2 remains single-owner without timer polling.
    if (!connection.hasAsyncWork()) {
        _ = try receiveSession(session, wire, buffer);
        return;
    }
    expireIncrementalStreams(connection);
    if (!try feedBlockedIncrementalInputs(connection)) {
        _ = try connection.notifications.getOne(connection.io);
        try resumeAllIncrementalOutputs(session, connection);
        try completeUnaryResponses(session, connection);
        _ = try feedBlockedIncrementalInputs(connection);
        try flushServerSession(session, connection, wire);
        return;
    }
    if (connection.parser_paused) {
        connection.parser_paused = false;
        const resumed = c.nghttp2_session_mem_recv(session, buffer.ptr, 0);
        if (resumed < 0) return connection.callback_error orelse error.Http2ReceiveFailure;
        try flushServerSession(session, connection, wire);
        return;
    }
    if (connection.pending_wire.items.len != 0) {
        const consumed = c.nghttp2_session_mem_recv(session, connection.pending_wire.items.ptr, connection.pending_wire.items.len);
        if (consumed < 0) return connection.callback_error orelse error.Http2ReceiveFailure;
        const used: usize = @intCast(consumed);
        if (used == 0) return error.Http2ReceiveFailure;
        const remaining = connection.pending_wire.items.len - used;
        std.mem.copyForwards(u8, connection.pending_wire.items[0..remaining], connection.pending_wire.items[used..]);
        connection.pending_wire.shrinkRetainingCapacity(remaining);
        try flushServerSession(session, connection, wire);
        return;
    }
    // Wait on transport readiness and handler notifications in one syscall.
    // This preserves the no-lost-read guarantee while avoiding a fixed timer
    // delay between every pair of streaming request/response messages.
    var descriptors = [_]std.posix.pollfd{
        .{
            .fd = wire.socketHandle(),
            .events = std.posix.POLL.IN | std.posix.POLL.ERR,
            .revents = 0,
        },
        .{
            .fd = connection.wakeup.read_fd,
            .events = std.posix.POLL.IN | std.posix.POLL.ERR,
            .revents = 0,
        },
    };
    _ = try std.posix.poll(&descriptors, 10);
    if ((descriptors[0].revents & (std.posix.POLL.IN | std.posix.POLL.ERR)) != 0) {
        const count = try wire.read(buffer);
        if (count == 0) return error.ConnectionClosed;
        const consumed = c.nghttp2_session_mem_recv(session, buffer.ptr, count);
        if (consumed < 0) return connection.callback_error orelse error.Http2ReceiveFailure;
        const used: usize = @intCast(consumed);
        if (used < count) try connection.pending_wire.appendSlice(connection.allocator, buffer[used..count]);
    }
    if ((descriptors[1].revents & (std.posix.POLL.IN | std.posix.POLL.ERR)) != 0) {
        connection.wakeup.drain();
        var notifications: [32]i32 = undefined;
        while (true) {
            const count = connection.notifications.get(connection.io, &notifications, 0) catch |err| switch (err) {
                error.Closed => 0,
                else => return err,
            };
            if (count < notifications.len) break;
        }
        try resumeAllIncrementalOutputs(session, connection);
    }
    try completeUnaryResponses(session, connection);
    try flushServerSession(session, connection, wire);
}

fn expireIncrementalStreams(connection: *ServerConnection) void {
    for (connection.streams.items) |stream| {
        const runtime = stream.incremental_runtime orelse continue;
        if (runtime.forcedStatus() != null) continue;
        if (deadlineReached(connection.io, runtime.deadline)) runtime.forceStatus(.deadline_exceeded);
    }
}

fn feedBlockedIncrementalInputs(connection: *ServerConnection) !bool {
    var ready = true;
    for (connection.streams.items) |stream| {
        if (stream.incremental_runtime == null) continue;
        if (!try feedIncrementalInput(connection, stream)) ready = false;
    }
    return ready;
}

fn resumeIncrementalOutput(session: *c.nghttp2_session, stream: *ServerStream) !void {
    const runtime = stream.incremental_runtime orelse return;
    if (!stream.incremental_headers_submitted) {
        if (runtime.lookahead == null) runtime.lookahead = try runtime.outbound.tryReceive();
        if (runtime.lookahead == null and !runtime.done.load(.acquire) and !runtime.headers_ready.load(.acquire)) return;
        try submitIncrementalResponseHeaders(session, runtime.connection, stream, runtime);
        return;
    }
    if (stream.incremental_provider_active) {
        const resumed = c.nghttp2_session_resume_data(session, stream.stream_id);
        if (resumed < 0 and resumed != c.NGHTTP2_ERR_INVALID_ARGUMENT) return error.Http2Failure;
        return;
    }
    if (runtime.done.load(.acquire) and runtime.lookahead == null) {
        runtime.lookahead = try runtime.outbound.tryReceive();
        if (runtime.lookahead == null) {
            if (runtime.middleware.context.protocol == .grpc) {
                try submitIncrementalTrailersDirect(session, stream.stream_id, runtime);
                return;
            }
        }
    }
    var provider = c.nghttp2_data_provider{ .source = .{ .ptr = stream }, .read_callback = serverIncrementalDataRead };
    try checkNghttp(c.nghttp2_submit_data(session, c.NGHTTP2_FLAG_NONE, stream.stream_id, &provider));
    stream.incremental_provider_active = true;
}

fn resumeAllIncrementalOutputs(session: *c.nghttp2_session, connection: *ServerConnection) !void {
    for (connection.streams.items) |stream| {
        if (stream.incremental_runtime == null) continue;
        try resumeIncrementalOutput(session, stream);
    }
}

fn flushServerSession(session: *c.nghttp2_session, connection: *ServerConnection, wire: Wire) !void {
    _ = connection;
    try flushSession(session, wire);
}

fn receiveSessionTimed(
    session: *c.nghttp2_session,
    io: std.Io,
    wire: Wire,
    buffer: []u8,
    deadline: std.Io.Clock.Timestamp,
    cancellation: ?Grpc.Cancellation,
) !usize {
    const Race = union(enum) {
        read: anyerror!usize,
        timeout: std.Io.Cancelable!void,
        cancellation: std.Io.Cancelable!void,
    };
    var results: [3]Race = undefined;
    var select = std.Io.Select(Race).init(io, &results);
    select.async(.read, wireReadTask, .{ wire, buffer });
    select.async(.timeout, deadlineTask, .{ io, deadline });
    if (cancellation) |token| select.async(.cancellation, cancellationTask, .{ io, token });
    const first = select.await() catch |err| {
        select.cancelDiscard();
        return err;
    };
    const count = switch (first) {
        .read => |result| try result,
        .timeout => |result| {
            try result;
            wire.cancelRead();
            select.cancelDiscard();
            return error.DeadlineExceeded;
        },
        .cancellation => |result| {
            try result;
            wire.cancelRead();
            select.cancelDiscard();
            return error.CallCancelled;
        },
    };
    select.cancelDiscard();
    if (count == 0) return error.ConnectionClosed;
    const consumed = c.nghttp2_session_mem_recv(session, buffer.ptr, count);
    if (consumed < 0 or consumed != count) return error.Http2ReceiveFailure;
    try flushSession(session, wire);
    return count;
}

fn wireReadTask(wire: Wire, buffer: []u8) anyerror!usize {
    return wire.read(buffer);
}

fn deadlineTask(io: std.Io, deadline: std.Io.Clock.Timestamp) std.Io.Cancelable!void {
    return deadline.wait(io);
}

fn cancellationTask(io: std.Io, cancellation: Grpc.Cancellation) std.Io.Cancelable!void {
    while (!cancellation.isCancelled()) {
        try (std.Io.Clock.Duration{ .raw = .fromMilliseconds(1), .clock = .awake }).sleep(io);
    }
}

fn callHasCompleteResponse(call: *const ClientCall) bool {
    return call.closed.load(.acquire) or call.response_complete.load(.acquire);
}

fn receiveCallUntilComplete(
    call: *ClientCall,
    session: *c.nghttp2_session,
    io: std.Io,
    wire: Wire,
    buffer: []u8,
    deadline: std.Io.Clock.Timestamp,
    cancellation: ?Grpc.Cancellation,
) !void {
    while (!callHasCompleteResponse(call)) {
        _ = receiveSessionTimed(session, io, wire, buffer, deadline, cancellation) catch |err| switch (err) {
            // A peer may close the connection immediately after the complete
            // grpc-status trailers. The semantic response is complete even if
            // nghttp2 has not delivered its local stream-close callback yet.
            error.ConnectionClosed => if (callHasCompleteResponse(call)) break else return err,
            else => return err,
        };
    }
}

fn nv(name: []const u8, value: []const u8) c.nghttp2_nv {
    return .{
        .name = @ptrCast(@constCast(name.ptr)),
        .value = @ptrCast(@constCast(value.ptr)),
        .namelen = name.len,
        .valuelen = value.len,
        .flags = c.NGHTTP2_NV_FLAG_NONE,
    };
}

const ClientCall = struct {
    allocator: std.mem.Allocator,
    request_body: []u8,
    request_headers: []c.nghttp2_nv = &.{},
    request_offset: usize = 0,
    response_body: std.ArrayList(u8) = .empty,
    headers: std.ArrayList(OwnedHeader) = .empty,
    header_bytes: usize = 0,
    stream_id: i32 = 0,
    closed: std.atomic.Value(bool) = .init(false),
    response_complete: std.atomic.Value(bool) = .init(false),
    commitment: Channel.CommitmentTracker = .{},
    stream_error: u32 = 0,
    incremental: ?*ClientIncrementalRuntime = null,
    limits: Limits,

    fn deinit(self: *ClientCall) void {
        self.allocator.free(self.request_body);
        self.response_body.deinit(self.allocator);
        for (self.headers.items) |*header| header.deinit(self.allocator);
        self.headers.deinit(self.allocator);
    }

    fn addHeader(self: *ClientCall, name: []const u8, value: []const u8, trailer: bool) !void {
        if (self.headers.items.len >= self.limits.max_header_count) return error.MetadataTooLarge;
        const added = std.math.add(usize, name.len, value.len) catch return error.MetadataTooLarge;
        const total = std.math.add(usize, self.header_bytes, added) catch return error.MetadataTooLarge;
        if (total > self.limits.max_header_bytes) return error.MetadataTooLarge;
        const owned_name = try self.allocator.dupe(u8, name);
        errdefer self.allocator.free(owned_name);
        const owned_value = try self.allocator.dupe(u8, value);
        errdefer self.allocator.free(owned_value);
        try self.headers.append(self.allocator, .{ .name = owned_name, .value = owned_value, .trailer = trailer });
        self.header_bytes = total;
    }
};

const OwnedHeader = struct {
    name: []u8,
    value: []u8,
    trailer: bool = false,

    fn deinit(self: *OwnedHeader, allocator: std.mem.Allocator) void {
        allocator.free(self.name);
        allocator.free(self.value);
    }

    fn borrowed(self: OwnedHeader) Grpc.Header {
        return .{ .name = self.name, .value = self.value };
    }
};

fn clientDataRead(
    _: ?*c.nghttp2_session,
    _: i32,
    buffer: [*c]u8,
    length: usize,
    data_flags: [*c]u32,
    source: [*c]c.nghttp2_data_source,
    _: ?*anyopaque,
) callconv(.c) isize {
    const call: *ClientCall = @ptrCast(@alignCast(source.*.ptr.?));
    if (call.incremental) |runtime| return runtime.readRequest(buffer, length, data_flags);
    const remaining = call.request_body.len - call.request_offset;
    const count = @min(length, remaining);
    if (count != 0) @memcpy(buffer[0..count], call.request_body[call.request_offset .. call.request_offset + count]);
    call.request_offset += count;
    if (call.request_offset == call.request_body.len) data_flags.* |= c.NGHTTP2_DATA_FLAG_EOF;
    return @intCast(count);
}

fn clientOnHeader(
    session: ?*c.nghttp2_session,
    frame: [*c]const c.nghttp2_frame,
    name: [*c]const u8,
    name_len: usize,
    value: [*c]const u8,
    value_len: usize,
    _: u8,
    _: ?*anyopaque,
) callconv(.c) c_int {
    const raw = c.nghttp2_session_get_stream_user_data(session.?, frame.*.hd.stream_id) orelse return c.NGHTTP2_ERR_CALLBACK_FAILURE;
    const call: *ClientCall = @ptrCast(@alignCast(raw));
    const trailer = frame.*.headers.cat == c.NGHTTP2_HCAT_HEADERS;
    if (!trailer) call.commitment.mark(.response_headers);
    call.addHeader(name[0..name_len], value[0..value_len], trailer) catch return c.NGHTTP2_ERR_CALLBACK_FAILURE;
    if (std.ascii.eqlIgnoreCase(name[0..name_len], "grpc-status")) call.response_complete.store(true, .release);
    return 0;
}

fn clientOnData(
    session: ?*c.nghttp2_session,
    _: u8,
    stream_id: i32,
    data: [*c]const u8,
    length: usize,
    _: ?*anyopaque,
) callconv(.c) c_int {
    const raw = c.nghttp2_session_get_stream_user_data(session.?, stream_id) orelse return c.NGHTTP2_ERR_CALLBACK_FAILURE;
    const call: *ClientCall = @ptrCast(@alignCast(raw));
    if (length != 0) call.commitment.mark(.response_message);
    if (call.incremental) |runtime| return runtime.onResponseData(data[0..length]);
    if (call.response_body.items.len + length > call.limits.grpc.max_buffered_message_bytes) return c.NGHTTP2_ERR_CALLBACK_FAILURE;
    call.response_body.appendSlice(call.allocator, data[0..length]) catch return c.NGHTTP2_ERR_CALLBACK_FAILURE;
    return 0;
}

fn clientOnClose(
    session: ?*c.nghttp2_session,
    stream_id: i32,
    error_code: u32,
    _: ?*anyopaque,
) callconv(.c) c_int {
    const raw = c.nghttp2_session_get_stream_user_data(session.?, stream_id) orelse return 0;
    const call: *ClientCall = @ptrCast(@alignCast(raw));
    if (stream_id == call.stream_id) {
        call.stream_error = error_code;
        call.closed.store(true, .release);
    }
    return 0;
}

fn clientOnFrame(
    _: ?*c.nghttp2_session,
    frame: [*c]const c.nghttp2_frame,
    user_data: ?*anyopaque,
) callconv(.c) c_int {
    if (frame.*.hd.type != c.NGHTTP2_PING or (frame.*.hd.flags & c.NGHTTP2_FLAG_ACK) == 0) return 0;
    const pointer = user_data orelse return 0;
    const channel: *PersistentChannel = @ptrCast(@alignCast(pointer));
    channel.lock();
    defer channel.mutex.unlock();
    const operation = channel.pending_ping orelse return 0;
    if (!std.mem.eql(u8, operation.data[0..], frame.*.ping.opaque_data[0..8])) return 0;
    channel.pending_ping = null;
    operation.completed.store(true, .release);
    return 0;
}

fn clientCallbacks() !*c.nghttp2_session_callbacks {
    var callbacks: ?*c.nghttp2_session_callbacks = null;
    try checkNghttp(c.nghttp2_session_callbacks_new(&callbacks));
    const value = callbacks orelse return error.Http2InitializationFailed;
    c.nghttp2_session_callbacks_set_on_header_callback(value, clientOnHeader);
    c.nghttp2_session_callbacks_set_on_data_chunk_recv_callback(value, clientOnData);
    c.nghttp2_session_callbacks_set_on_stream_close_callback(value, clientOnClose);
    c.nghttp2_session_callbacks_set_on_frame_recv_callback(value, clientOnFrame);
    return value;
}

fn frameUnaryRequestAlloc(allocator: std.mem.Allocator, request: Grpc.UnaryRequest, limits: Grpc.Limits) ![]u8 {
    if (request.compression == .identity) return Grpc.frameMessageAlloc(allocator, request.payload, .{ .limits = limits });
    const compressed = try Compression.compressAlloc(allocator, request.compression, request.payload, limits.max_message_bytes);
    defer allocator.free(compressed);
    return Grpc.frameMessageAlloc(allocator, compressed, .{ .limits = limits, .compressed = true });
}

fn frameStreamingRequestAlloc(allocator: std.mem.Allocator, request: Grpc.StreamingRequest, limits: Grpc.Limits) ![]u8 {
    var frames: std.ArrayList(u8) = .empty;
    errdefer frames.deinit(allocator);
    for (request.messages) |message| {
        const frame = try Grpc.frameMessageAlloc(allocator, message, .{ .limits = limits });
        defer allocator.free(frame);
        try frames.appendSlice(allocator, frame);
    }
    return frames.toOwnedSlice(allocator);
}

fn headerCompression(headers: []const OwnedHeader) !Grpc.Compression {
    for (headers) |header| if (std.ascii.eqlIgnoreCase(header.name, "grpc-encoding")) {
        return Grpc.Compression.parse(header.value) orelse error.UnsupportedCompression;
    };
    return .identity;
}

fn retryPushbackMillis(headers: []const OwnedHeader) !?i64 {
    var result: ?i64 = null;
    for (headers) |header| {
        if (!std.ascii.eqlIgnoreCase(header.name, "grpc-retry-pushback-ms")) continue;
        if (result != null) return error.DuplicateRetryPushback;
        result = std.fmt.parseInt(i64, header.value, 10) catch return error.InvalidRetryPushback;
    }
    return result;
}

const DecodedUnaryBody = struct {
    allocator: std.mem.Allocator,
    bytes: []const u8,
    owned: ?[]u8 = null,

    fn deinit(self: *DecodedUnaryBody) void {
        if (self.owned) |bytes| self.allocator.free(bytes);
        self.* = undefined;
    }
};

fn decodeUnaryBody(allocator: std.mem.Allocator, body: []const u8, encoding: Grpc.Compression, limits: Grpc.Limits) !DecodedUnaryBody {
    if (body.len == 0) return .{ .allocator = allocator, .bytes = "" };
    const compressed = body[0] == 1;
    const payload = try Grpc.unframeMessage(body, .{ .limits = limits, .compressed = compressed });
    if (!compressed) return .{ .allocator = allocator, .bytes = payload };
    if (encoding == .identity) return error.UnsupportedCompression;
    const restored = try Compression.decompressAlloc(allocator, encoding, payload, limits.max_message_bytes);
    return .{ .allocator = allocator, .bytes = restored, .owned = restored };
}

fn requestForTransport(options: ClientOptions, request: Grpc.UnaryRequest) Grpc.UnaryRequest {
    var transported = request;
    transported.scheme = if (options.tls == null) "http" else "https";
    return transported;
}

fn streamingRequestForTransport(options: ClientOptions, request: Grpc.StreamingRequest) Grpc.StreamingRequest {
    var transported = request;
    transported.scheme = if (options.tls == null) "http" else "https";
    return transported;
}

const PreparedCredentialMetadata = struct {
    allocator: std.mem.Allocator,
    block: ?Grpc.MetadataBlock = null,
    combined: ?[]Grpc.Metadata = null,
    entries: []const Grpc.Metadata,

    fn deinit(self: *PreparedCredentialMetadata) void {
        if (self.combined) |entries| self.allocator.free(entries);
        if (self.block) |*block| block.deinit();
        self.* = undefined;
    }
};

fn prepareCredentialMetadataAlloc(
    allocator: std.mem.Allocator,
    provider: ?Credentials.Provider,
    context: Credentials.Context,
    existing: []const Grpc.Metadata,
) !PreparedCredentialMetadata {
    const selected = provider orelse return .{ .allocator = allocator, .entries = existing };
    var block = try selected.metadataAlloc(allocator, context);
    errdefer block.deinit();
    const combined = try allocator.alloc(Grpc.Metadata, existing.len + block.entries.len);
    @memcpy(combined[0..existing.len], existing);
    @memcpy(combined[existing.len..], block.entries);
    return .{ .allocator = allocator, .block = block, .combined = combined, .entries = combined };
}

fn responseHeadersForPhaseAlloc(allocator: std.mem.Allocator, call: *const ClientCall, trailer: bool) ![]Grpc.Header {
    var count: usize = 0;
    for (call.headers.items) |header| if (header.trailer == trailer) {
        count += 1;
    };
    const headers = try allocator.alloc(Grpc.Header, count);
    var index: usize = 0;
    for (call.headers.items) |header| {
        if (header.trailer != trailer) continue;
        headers[index] = header.borrowed();
        index += 1;
    }
    return headers;
}

fn hasTrailersOnlyStatus(call: *const ClientCall) bool {
    for (call.headers.items) |header| {
        if (!header.trailer and std.ascii.eqlIgnoreCase(header.name, "grpc-status")) return true;
    }
    return false;
}

fn responseHttpStatus(headers: []const Grpc.Header) !u16 {
    var result: ?u16 = null;
    for (headers) |header| {
        if (!std.mem.eql(u8, header.name, ":status")) continue;
        if (result != null) return error.DuplicateHttpStatus;
        result = std.fmt.parseInt(u16, header.value, 10) catch return error.InvalidHttpStatus;
    }
    return result orelse error.MissingHttpStatus;
}

const ParsedResponseContext = struct {
    status: Grpc.OwnedStatus,
    initial_metadata: Grpc.MetadataBlock,
    trailing_metadata: Grpc.MetadataBlock,
    compression: Grpc.Compression,

    fn deinit(self: *ParsedResponseContext) void {
        self.status.deinit();
        self.initial_metadata.deinit();
        self.trailing_metadata.deinit();
        self.* = undefined;
    }
};

fn parseResponseContextAlloc(allocator: std.mem.Allocator, call: *const ClientCall) !ParsedResponseContext {
    const initial_headers = try responseHeadersForPhaseAlloc(allocator, call, false);
    defer allocator.free(initial_headers);
    const http_status = try responseHttpStatus(initial_headers);
    const trailers_only = hasTrailersOnlyStatus(call);
    const trailing_headers = if (trailers_only)
        initial_headers
    else
        try responseHeadersForPhaseAlloc(allocator, call, true);
    defer if (!trailers_only) allocator.free(trailing_headers);

    var status = if (http_status == 200) blk: {
        try Grpc.validateResponseHeaders(http_status, initial_headers);
        break :blk try Grpc.parseTrailersAlloc(allocator, trailing_headers, call.limits.grpc);
    } else blk: {
        const message = try std.fmt.allocPrint(allocator, "HTTP status {d} without grpc-status", .{http_status});
        errdefer allocator.free(message);
        const details = try allocator.dupe(u8, "");
        break :blk Grpc.OwnedStatus{
            .allocator = allocator,
            .status = .{ .code = Grpc.codeFromHttpStatus(http_status), .message = message },
            .message_storage = message,
            .details_storage = details,
        };
    };
    errdefer status.deinit();
    var initial_metadata = if (trailers_only)
        try Grpc.metadataFromHeadersAlloc(allocator, &.{}, call.limits.grpc)
    else
        try Grpc.metadataFromHeadersAlloc(allocator, initial_headers, call.limits.grpc);
    errdefer initial_metadata.deinit();
    var trailing_metadata = try Grpc.metadataFromHeadersAlloc(allocator, trailing_headers, call.limits.grpc);
    errdefer trailing_metadata.deinit();
    return .{
        .status = status,
        .initial_metadata = initial_metadata,
        .trailing_metadata = trailing_metadata,
        .compression = try headerCompression(call.headers.items),
    };
}

fn unaryResponseFromCallAlloc(allocator: std.mem.Allocator, call: *const ClientCall) !Grpc.UnaryResponse {
    var context = try parseResponseContextAlloc(allocator, call);
    defer context.deinit();
    var message = try decodeUnaryBody(allocator, call.response_body.items, context.compression, call.limits.grpc);
    defer message.deinit();
    return Grpc.UnaryResponse.initFullAlloc(allocator, .{
        .payload = message.bytes,
        .initial_metadata = context.initial_metadata.entries,
        .trailing_metadata = context.trailing_metadata.entries,
        .status = context.status.status,
        .retry_pushback_millis = try retryPushbackMillis(call.headers.items),
    });
}

fn streamingResponseFromCallAlloc(allocator: std.mem.Allocator, call: *const ClientCall) !Grpc.StreamingResponse {
    var context = try parseResponseContextAlloc(allocator, call);
    defer context.deinit();
    var decoder = try Grpc.MessageDecoder.init(allocator, call.limits.grpc);
    defer decoder.deinit();
    try decoder.push(call.response_body.items);
    try decoder.finish();
    var owned: std.ArrayList(Grpc.OwnedMessage) = .empty;
    defer {
        for (owned.items) |*message| message.deinit(allocator);
        owned.deinit(allocator);
    }
    while (decoder.pop()) |message| try owned.append(allocator, message);
    var decompressed: std.ArrayList([]u8) = .empty;
    defer {
        for (decompressed.items) |bytes| allocator.free(bytes);
        decompressed.deinit(allocator);
    }
    const messages = try allocator.alloc([]const u8, owned.items.len);
    defer allocator.free(messages);
    for (owned.items, 0..) |message, index| {
        if (!message.compressed) {
            messages[index] = message.bytes;
            continue;
        }
        if (context.compression == .identity) return error.UnsupportedCompression;
        const restored = try Compression.decompressAlloc(allocator, context.compression, message.bytes, call.limits.grpc.max_message_bytes);
        try decompressed.append(allocator, restored);
        messages[index] = restored;
    }
    return Grpc.StreamingResponse.initFullAlloc(allocator, messages, .{
        .initial_metadata = context.initial_metadata.entries,
        .trailing_metadata = context.trailing_metadata.entries,
        .status = context.status.status,
    });
}

pub const ClientOptions = struct {
    host: []const u8 = "127.0.0.1",
    port: u16 = 50051,
    limits: Limits = .{},
    tls: ?ClientTlsConfig = null,
    /// Disable Nagle's algorithm for latency-sensitive HTTP/2 control and
    /// trailer writes. gRPC defaults this on for both plaintext and TLS.
    tcp_nodelay: bool = true,
    max_concurrent_streams: usize = 100,
    keepalive_interval_millis: ?u64 = 60_000,
    keepalive_timeout_millis: u64 = 20_000,
    /// Optional gRPC service config. Persistent channels parse and own a
    /// bounded copy during initialization.
    service_config_json: ?[]const u8 = null,
    credentials: ?Credentials.Provider = null,
    /// Canonical target URI, for example dns:///orders.internal:443.
    target_uri: ?[]const u8 = null,
    resolver: ?Channel.Resolver = null,
    /// Optional ZigEffect causal boundary recorder. It never receives payloads,
    /// metadata, authorities, or credential material.
    causal: ?*Middleware.CausalFacts = null,
    telemetry: ?*Middleware.OtlpTelemetry = null,
};

pub const NativeClient = struct {
    allocator: std.mem.Allocator,
    io: std.Io,
    options: ClientOptions,

    pub fn init(allocator: std.mem.Allocator, io: std.Io, options: ClientOptions) !NativeClient {
        try options.limits.validate();
        if (options.max_concurrent_streams == 0) return error.InvalidLimits;
        if (options.keepalive_interval_millis) |interval| if (interval < 10_000) return error.InvalidLimits;
        if (options.keepalive_timeout_millis == 0) return error.InvalidLimits;
        if (options.keepalive_interval_millis) |interval| if (options.keepalive_timeout_millis > interval) return error.InvalidLimits;
        if (options.tls) |tls| try tls.validate();
        return .{ .allocator = allocator, .io = io, .options = options };
    }

    pub fn invokeAlloc(self: *NativeClient, allocator: std.mem.Allocator, request: Grpc.UnaryRequest, call_options: Grpc.CallOptions) anyerror!Grpc.UnaryResponse {
        try call_options.checkActive();
        try request.validate(self.options.limits.grpc);
        var metadata = try prepareCredentialMetadataAlloc(allocator, self.options.credentials, .{
            .authority = request.authority,
            .service = request.service,
            .method = request.method,
            .shape = .unary,
        }, request.metadata);
        defer metadata.deinit();
        var forwarded = request;
        forwarded.metadata = metadata.entries;
        try forwarded.validate(self.options.limits.grpc);

        const stream = try connectHost(self.io, self.options.host, self.options.port, self.options.tcp_nodelay);
        var owns_stream = true;
        defer if (owns_stream) stream.close(self.io);
        if (self.options.tls) |tls| {
            const context = try createClientTlsContext(tls);
            defer SSL_CTX_free(context);
            const ssl = SSL_new(context) orelse return error.TlsConnectionInitializationFailed;
            var owns_ssl = true;
            defer if (owns_ssl) SSL_free(ssl);
            if (SSL_set_fd(ssl, stream.socket.handle) != 1) return error.TlsSocketBindingFailed;
            if (SSL_ctrl(ssl, ssl_ctrl_set_tlsext_hostname, 0, @ptrCast(@constCast(tls.server_name.ptr))) != 1) return error.TlsServerNameFailed;
            if (SSL_set1_host(ssl, tls.server_name.ptr) != 1) return error.TlsHostVerificationConfigurationFailed;
            if (SSL_connect(ssl) != 1) return error.TlsHandshakeFailed;
            if (SSL_get_verify_result(ssl) != x509_v_ok) return error.TlsPeerVerificationFailed;
            try requireH2(ssl);
            var tls_wire = TlsWire{ .io = self.io, .stream = stream, .ssl = ssl };
            owns_ssl = false;
            owns_stream = false;
            const wire = tls_wire.wire();
            defer wire.close();
            return self.invokeWireAlloc(allocator, wire, forwarded, call_options);
        } else {
            var plain = PlainWire{ .io = self.io, .stream = stream };
            owns_stream = false;
            const wire = plain.wire();
            defer wire.close();
            return self.invokeWireAlloc(allocator, wire, forwarded, call_options);
        }
    }

    pub fn client(self: *NativeClient) Grpc.Client {
        return .{ .ptr = self, .invoke_fn = invokeErased };
    }

    pub fn transport(self: *NativeClient) Grpc.Transport {
        return .{
            .ptr = self,
            .capabilities = .{
                .http2 = true,
                .tls = self.options.tls != null,
                .trailers = true,
                .deadlines = true,
                .cancellation = true,
                .multiplexing = true,
                .connection_reuse = true,
                .flow_control = true,
                .bounded_messages = true,
                .redacted_diagnostics = true,
            },
            .invoke_fn = invokeErased,
        };
    }

    pub fn invokeBatchAlloc(
        self: *NativeClient,
        allocator: std.mem.Allocator,
        requests: []const Grpc.UnaryRequest,
        call_options: Grpc.CallOptions,
    ) anyerror!BatchResponse {
        if (requests.len == 0) return error.EmptyBatch;
        try call_options.checkActive();
        for (requests) |request| try request.validate(self.options.limits.grpc);
        const metadata = try allocator.alloc(PreparedCredentialMetadata, requests.len);
        defer allocator.free(metadata);
        const forwarded = try allocator.alloc(Grpc.UnaryRequest, requests.len);
        defer allocator.free(forwarded);
        var prepared: usize = 0;
        defer for (metadata[0..prepared]) |*entry| entry.deinit();
        for (requests, 0..) |request, index| {
            metadata[index] = try prepareCredentialMetadataAlloc(allocator, self.options.credentials, .{
                .authority = request.authority,
                .service = request.service,
                .method = request.method,
                .shape = .unary,
            }, request.metadata);
            prepared += 1;
            forwarded[index] = request;
            forwarded[index].metadata = metadata[index].entries;
            try forwarded[index].validate(self.options.limits.grpc);
        }
        const stream = try connectHost(self.io, self.options.host, self.options.port, self.options.tcp_nodelay);
        var owns_stream = true;
        defer if (owns_stream) stream.close(self.io);
        if (self.options.tls) |tls| {
            const context = try createClientTlsContext(tls);
            defer SSL_CTX_free(context);
            const ssl = SSL_new(context) orelse return error.TlsConnectionInitializationFailed;
            var owns_ssl = true;
            defer if (owns_ssl) SSL_free(ssl);
            if (SSL_set_fd(ssl, stream.socket.handle) != 1) return error.TlsSocketBindingFailed;
            if (SSL_ctrl(ssl, ssl_ctrl_set_tlsext_hostname, 0, @ptrCast(@constCast(tls.server_name.ptr))) != 1) return error.TlsServerNameFailed;
            if (SSL_set1_host(ssl, tls.server_name.ptr) != 1) return error.TlsHostVerificationConfigurationFailed;
            if (SSL_connect(ssl) != 1) return error.TlsHandshakeFailed;
            if (SSL_get_verify_result(ssl) != x509_v_ok) return error.TlsPeerVerificationFailed;
            try requireH2(ssl);
            var tls_wire = TlsWire{ .io = self.io, .stream = stream, .ssl = ssl };
            owns_ssl = false;
            owns_stream = false;
            const wire = tls_wire.wire();
            defer wire.close();
            return self.invokeBatchWireAlloc(allocator, wire, forwarded, call_options);
        }
        var plain = PlainWire{ .io = self.io, .stream = stream };
        owns_stream = false;
        const wire = plain.wire();
        defer wire.close();
        return self.invokeBatchWireAlloc(allocator, wire, forwarded, call_options);
    }

    pub fn invokeStreamingAlloc(self: *NativeClient, allocator: std.mem.Allocator, request: Grpc.StreamingRequest, call_options: Grpc.CallOptions) anyerror!Grpc.StreamingResponse {
        try call_options.checkActive();
        try request.validate(self.options.limits.grpc);
        var metadata = try prepareCredentialMetadataAlloc(allocator, self.options.credentials, .{
            .authority = request.authority,
            .service = request.service,
            .method = request.method,
            .shape = request.shape,
        }, request.metadata);
        defer metadata.deinit();
        var forwarded = request;
        forwarded.metadata = metadata.entries;
        try forwarded.validate(self.options.limits.grpc);
        const stream = try connectHost(self.io, self.options.host, self.options.port, self.options.tcp_nodelay);
        var owns_stream = true;
        defer if (owns_stream) stream.close(self.io);
        if (self.options.tls) |tls| {
            const context = try createClientTlsContext(tls);
            defer SSL_CTX_free(context);
            const ssl = SSL_new(context) orelse return error.TlsConnectionInitializationFailed;
            var owns_ssl = true;
            defer if (owns_ssl) SSL_free(ssl);
            if (SSL_set_fd(ssl, stream.socket.handle) != 1) return error.TlsSocketBindingFailed;
            if (SSL_ctrl(ssl, ssl_ctrl_set_tlsext_hostname, 0, @ptrCast(@constCast(tls.server_name.ptr))) != 1) return error.TlsServerNameFailed;
            if (SSL_set1_host(ssl, tls.server_name.ptr) != 1) return error.TlsHostVerificationConfigurationFailed;
            if (SSL_connect(ssl) != 1 or SSL_get_verify_result(ssl) != x509_v_ok) return error.TlsHandshakeFailed;
            try requireH2(ssl);
            var tls_wire = TlsWire{ .io = self.io, .stream = stream, .ssl = ssl };
            owns_ssl = false;
            owns_stream = false;
            const wire = tls_wire.wire();
            defer wire.close();
            return self.invokeStreamingWireAlloc(allocator, wire, forwarded, call_options);
        }
        var plain = PlainWire{ .io = self.io, .stream = stream };
        owns_stream = false;
        const wire = plain.wire();
        defer wire.close();
        return self.invokeStreamingWireAlloc(allocator, wire, forwarded, call_options);
    }

    fn invokeErased(pointer: *anyopaque, allocator: std.mem.Allocator, request: Grpc.UnaryRequest, options: Grpc.CallOptions) anyerror!Grpc.UnaryResponse {
        return (@as(*NativeClient, @ptrCast(@alignCast(pointer)))).invokeAlloc(allocator, request, options);
    }

    fn invokeWireAlloc(self: *NativeClient, allocator: std.mem.Allocator, wire: Wire, request: Grpc.UnaryRequest, call_options: Grpc.CallOptions) !Grpc.UnaryResponse {
        const request_body = try frameUnaryRequestAlloc(allocator, request, self.options.limits.grpc);
        var call = ClientCall{ .allocator = allocator, .request_body = request_body, .limits = self.options.limits };
        defer call.deinit();

        const callbacks = try clientCallbacks();
        defer c.nghttp2_session_callbacks_del(callbacks);
        var maybe_session: ?*c.nghttp2_session = null;
        try checkNghttp(c.nghttp2_session_client_new(&maybe_session, callbacks, null));
        const session = maybe_session orelse return error.Http2InitializationFailed;
        defer c.nghttp2_session_del(session);

        try checkNghttp(c.nghttp2_submit_settings(session, c.NGHTTP2_FLAG_NONE, null, 0));
        var owned_headers = try Grpc.requestHeadersAlloc(allocator, requestForTransport(self.options, request), self.options.limits.grpc);
        defer owned_headers.deinit();
        const headers = try allocator.alloc(c.nghttp2_nv, owned_headers.headers.len);
        defer allocator.free(headers);
        for (owned_headers.headers, 0..) |header, index| headers[index] = nv(header.name, header.value);
        var provider = c.nghttp2_data_provider{
            .source = .{ .ptr = &call },
            .read_callback = clientDataRead,
        };
        const stream_id = c.nghttp2_submit_request(session, null, headers.ptr, headers.len, &provider, &call);
        if (stream_id < 0) return error.Http2SubmitFailed;
        call.stream_id = stream_id;
        try flushSession(session, wire);

        const buffer = try allocator.alloc(u8, self.options.limits.max_wire_read_bytes);
        defer allocator.free(buffer);
        const deadline = std.Io.Clock.Timestamp.fromNow(self.io, .{
            .raw = .fromMilliseconds(@intCast(request.timeout_millis)),
            .clock = .awake,
        });
        try receiveCallUntilComplete(&call, session, self.io, wire, buffer, deadline, call_options.cancellation);
        if (call.stream_error != c.NGHTTP2_NO_ERROR) return error.Http2StreamFailed;

        return unaryResponseFromCallAlloc(allocator, &call);
    }

    fn invokeBatchWireAlloc(
        self: *NativeClient,
        allocator: std.mem.Allocator,
        wire: Wire,
        requests: []const Grpc.UnaryRequest,
        call_options: Grpc.CallOptions,
    ) !BatchResponse {
        const calls = try allocator.alloc(ClientCall, requests.len);
        defer allocator.free(calls);
        var initialized: usize = 0;
        defer for (calls[0..initialized]) |*call| call.deinit();
        for (requests, 0..) |request, index| {
            const body = try frameUnaryRequestAlloc(allocator, request, self.options.limits.grpc);
            calls[index] = .{ .allocator = allocator, .request_body = body, .limits = self.options.limits };
            initialized += 1;
        }

        const callbacks = try clientCallbacks();
        defer c.nghttp2_session_callbacks_del(callbacks);
        var maybe_session: ?*c.nghttp2_session = null;
        try checkNghttp(c.nghttp2_session_client_new(&maybe_session, callbacks, null));
        const session = maybe_session orelse return error.Http2InitializationFailed;
        defer c.nghttp2_session_del(session);
        try checkNghttp(c.nghttp2_submit_settings(session, c.NGHTTP2_FLAG_NONE, null, 0));

        for (requests, 0..) |request, index| {
            var owned_headers = try Grpc.requestHeadersAlloc(allocator, requestForTransport(self.options, request), self.options.limits.grpc);
            defer owned_headers.deinit();
            const headers = try allocator.alloc(c.nghttp2_nv, owned_headers.headers.len);
            defer allocator.free(headers);
            for (owned_headers.headers, 0..) |header, header_index| headers[header_index] = nv(header.name, header.value);
            var provider = c.nghttp2_data_provider{ .source = .{ .ptr = &calls[index] }, .read_callback = clientDataRead };
            const stream_id = c.nghttp2_submit_request(session, null, headers.ptr, headers.len, &provider, &calls[index]);
            if (stream_id < 0) return error.Http2SubmitFailed;
            calls[index].stream_id = stream_id;
        }
        try flushSession(session, wire);

        var minimum_timeout = requests[0].timeout_millis;
        for (requests[1..]) |request| minimum_timeout = @min(minimum_timeout, request.timeout_millis);
        const deadline = std.Io.Clock.Timestamp.fromNow(self.io, .{
            .raw = .fromMilliseconds(@intCast(minimum_timeout)),
            .clock = .awake,
        });
        const buffer = try allocator.alloc(u8, self.options.limits.max_wire_read_bytes);
        defer allocator.free(buffer);
        while (true) {
            var closed: usize = 0;
            for (calls) |call| if (call.closed.load(.acquire)) {
                closed += 1;
            };
            if (closed == calls.len) break;
            _ = receiveSessionTimed(session, self.io, wire, buffer, deadline, call_options.cancellation) catch |err| switch (err) {
                error.ConnectionClosed => {
                    var complete = true;
                    for (calls) |*call| complete = complete and callHasCompleteResponse(call);
                    if (complete) break;
                    return err;
                },
                else => return err,
            };
        }

        const responses = try allocator.alloc(Grpc.UnaryResponse, calls.len);
        var response_count: usize = 0;
        errdefer {
            for (responses[0..response_count]) |*response| response.deinit();
            allocator.free(responses);
        }
        for (calls, 0..) |call, index| {
            if (call.stream_error != c.NGHTTP2_NO_ERROR) return error.Http2StreamFailed;
            responses[index] = try unaryResponseFromCallAlloc(allocator, &call);
            response_count += 1;
        }
        return .{ .allocator = allocator, .responses = responses };
    }

    fn invokeStreamingWireAlloc(self: *NativeClient, allocator: std.mem.Allocator, wire: Wire, request: Grpc.StreamingRequest, call_options: Grpc.CallOptions) !Grpc.StreamingResponse {
        const body = try frameStreamingRequestAlloc(allocator, request, self.options.limits.grpc);
        var call = ClientCall{ .allocator = allocator, .request_body = body, .limits = self.options.limits };
        defer call.deinit();
        const callbacks = try clientCallbacks();
        defer c.nghttp2_session_callbacks_del(callbacks);
        var maybe_session: ?*c.nghttp2_session = null;
        try checkNghttp(c.nghttp2_session_client_new(&maybe_session, callbacks, null));
        const session = maybe_session orelse return error.Http2InitializationFailed;
        defer c.nghttp2_session_del(session);
        try checkNghttp(c.nghttp2_submit_settings(session, c.NGHTTP2_FLAG_NONE, null, 0));
        const unary_headers = Grpc.UnaryRequest{
            .authority = request.authority,
            .service = request.service,
            .method = request.method,
            .payload = "",
            .scheme = streamingRequestForTransport(self.options, request).scheme,
            .metadata = request.metadata,
            .timeout_millis = request.timeout_millis,
        };
        var owned_headers = try Grpc.requestHeadersAlloc(allocator, unary_headers, self.options.limits.grpc);
        defer owned_headers.deinit();
        const headers = try allocator.alloc(c.nghttp2_nv, owned_headers.headers.len);
        defer allocator.free(headers);
        for (owned_headers.headers, 0..) |header, index| headers[index] = nv(header.name, header.value);
        var provider = c.nghttp2_data_provider{ .source = .{ .ptr = &call }, .read_callback = clientDataRead };
        const stream_id = c.nghttp2_submit_request(session, null, headers.ptr, headers.len, &provider, &call);
        if (stream_id < 0) return error.Http2SubmitFailed;
        call.stream_id = stream_id;
        try flushSession(session, wire);
        const buffer = try allocator.alloc(u8, self.options.limits.max_wire_read_bytes);
        defer allocator.free(buffer);
        const deadline = std.Io.Clock.Timestamp.fromNow(self.io, .{ .raw = .fromMilliseconds(@intCast(request.timeout_millis)), .clock = .awake });
        try receiveCallUntilComplete(&call, session, self.io, wire, buffer, deadline, call_options.cancellation);
        if (call.stream_error != c.NGHTTP2_NO_ERROR) return error.Http2StreamFailed;
        return streamingResponseFromCallAlloc(allocator, &call);
    }
};

pub const BatchResponse = struct {
    allocator: std.mem.Allocator,
    responses: []Grpc.UnaryResponse,

    pub fn deinit(self: *BatchResponse) void {
        for (self.responses) |*response| response.deinit();
        self.allocator.free(self.responses);
        self.* = undefined;
    }
};

const ClientWireStorage = union(enum) {
    plain: PlainWire,
    tls: struct {
        context: *SSL_CTX,
        wire: TlsWire,
    },

    fn wire(self: *ClientWireStorage) Wire {
        return switch (self.*) {
            .plain => |*plain| plain.wire(),
            .tls => |*tls| tls.wire.wire(),
        };
    }

    fn deinit(self: *ClientWireStorage) void {
        switch (self.*) {
            .plain => |*plain| plain.wire().close(),
            .tls => |*tls| {
                tls.wire.wire().close();
                SSL_CTX_free(tls.context);
            },
        }
        self.* = undefined;
    }

    fn socketHandle(self: *ClientWireStorage) std.posix.fd_t {
        return switch (self.*) {
            .plain => |*plain| plain.stream.socket.handle,
            .tls => |*tls| tls.wire.stream.socket.handle,
        };
    }
};

const ClientConnection = struct {
    callbacks: *c.nghttp2_session_callbacks,
    session: *c.nghttp2_session,
    storage: ClientWireStorage,

    fn init(client: *NativeClient) !ClientConnection {
        const stream = try connectHost(client.io, client.options.host, client.options.port, client.options.tcp_nodelay);
        var owns_stream = true;
        errdefer if (owns_stream) stream.close(client.io);
        var storage: ClientWireStorage = if (client.options.tls) |tls| blk: {
            const context = try createClientTlsContext(tls);
            errdefer SSL_CTX_free(context);
            const ssl = SSL_new(context) orelse return error.TlsConnectionInitializationFailed;
            errdefer SSL_free(ssl);
            if (SSL_set_fd(ssl, stream.socket.handle) != 1) return error.TlsSocketBindingFailed;
            if (SSL_ctrl(ssl, ssl_ctrl_set_tlsext_hostname, 0, @ptrCast(@constCast(tls.server_name.ptr))) != 1) return error.TlsServerNameFailed;
            if (SSL_set1_host(ssl, tls.server_name.ptr) != 1) return error.TlsHostVerificationConfigurationFailed;
            if (SSL_connect(ssl) != 1) return error.TlsHandshakeFailed;
            if (SSL_get_verify_result(ssl) != x509_v_ok) return error.TlsPeerVerificationFailed;
            try requireH2(ssl);
            break :blk .{ .tls = .{ .context = context, .wire = .{ .io = client.io, .stream = stream, .ssl = ssl } } };
        } else .{ .plain = .{ .io = client.io, .stream = stream } };
        owns_stream = false;
        errdefer storage.deinit();
        const callbacks = try clientCallbacks();
        errdefer c.nghttp2_session_callbacks_del(callbacks);
        var maybe_session: ?*c.nghttp2_session = null;
        try checkNghttp(c.nghttp2_session_client_new(&maybe_session, callbacks, null));
        const session = maybe_session orelse return error.Http2InitializationFailed;
        errdefer c.nghttp2_session_del(session);
        try checkNghttp(c.nghttp2_submit_settings(session, c.NGHTTP2_FLAG_NONE, null, 0));
        try flushSession(session, storage.wire());
        return .{ .callbacks = callbacks, .session = session, .storage = storage };
    }

    fn deinit(self: *ClientConnection) void {
        c.nghttp2_session_del(self.session);
        c.nghttp2_session_callbacks_del(self.callbacks);
        self.storage.deinit();
        self.* = undefined;
    }
};

pub const ChannelSnapshot = struct {
    connected: bool,
    connectivity: Channel.ConnectivitySnapshot,
    calls: usize,
    calls_started: usize,
    calls_succeeded: usize,
    calls_failed: usize,
    connections_opened: usize,
    reconnects: usize,
    active_calls: usize,
    peak_active_calls: usize,
    keepalive_pings: usize,
    resolved_addresses: usize,
    selected_address: ?Channel.Address,
    retry_tokens_milli: ?u32,
    health_state: ClientHealthState,
    health_generation: u64,
};

pub const ClientHealthState = enum(u8) {
    disabled,
    connecting,
    serving,
    not_serving,
    service_unknown,
    failed,
    shutdown,
};

const PingOperation = struct {
    data: [8]u8,
    completed: std.atomic.Value(bool) = .init(false),
};

const ClientOperation = union(enum) {
    call: *ClientCall,
    ping: *PingOperation,
};

const ClientOperationQueue = struct {
    items: std.ArrayList(ClientOperation) = .empty,
    head: usize = 0,

    fn deinit(self: *ClientOperationQueue, allocator: std.mem.Allocator) void {
        self.items.deinit(allocator);
        self.* = undefined;
    }

    fn count(self: *const ClientOperationQueue) usize {
        return self.items.items.len - self.head;
    }

    fn append(self: *ClientOperationQueue, allocator: std.mem.Allocator, operation: ClientOperation) !void {
        if (self.head != 0 and self.items.items.len == self.items.capacity) self.compact();
        try self.items.append(allocator, operation);
    }

    fn pop(self: *ClientOperationQueue) ?ClientOperation {
        if (self.head == self.items.items.len) return null;
        const operation = self.items.items[self.head];
        self.head += 1;
        if (self.head == self.items.items.len) {
            self.items.clearRetainingCapacity();
            self.head = 0;
        } else if (self.head >= 64 and self.head >= self.count()) self.compact();
        return operation;
    }

    fn removeCall(self: *ClientOperationQueue, target: *ClientCall) bool {
        for (self.items.items[self.head..], self.head..) |operation, index| switch (operation) {
            .call => |call| if (call == target) {
                if (index == self.head) {
                    _ = self.pop();
                } else {
                    _ = self.items.orderedRemove(index);
                }
                return true;
            },
            else => {},
        };
        return false;
    }

    fn clearRetainingCapacity(self: *ClientOperationQueue) void {
        self.items.clearRetainingCapacity();
        self.head = 0;
    }

    fn compact(self: *ClientOperationQueue) void {
        if (self.head == 0) return;
        const remaining = self.count();
        std.mem.copyForwards(ClientOperation, self.items.items[0..remaining], self.items.items[self.head..]);
        self.items.shrinkRetainingCapacity(remaining);
        self.head = 0;
    }
};

test "persistent operation queue dequeues without retaining a copied prefix" {
    var queue: ClientOperationQueue = .{};
    defer queue.deinit(std.testing.allocator);
    var ping = PingOperation{ .data = .{ 0, 0, 0, 0, 0, 0, 0, 1 } };
    for (0..10_000) |_| try queue.append(std.testing.allocator, .{ .ping = &ping });
    for (0..10_000) |_| try std.testing.expect(queue.pop() != null);
    try std.testing.expectEqual(@as(usize, 0), queue.count());
    try std.testing.expectEqual(@as(usize, 0), queue.head);
    try std.testing.expectEqual(@as(usize, 0), queue.items.items.len);
}

pub const IncrementalOpenRequest = struct {
    authority: []const u8,
    service: []const u8,
    method: []const u8,
    scheme: []const u8 = "https",
    metadata: []const Grpc.Metadata = &.{},
    timeout_millis: u64,
    shape: Grpc.CallShape,

    fn streaming(self: IncrementalOpenRequest) Grpc.StreamingRequest {
        return .{
            .authority = self.authority,
            .service = self.service,
            .method = self.method,
            .messages = &.{},
            .scheme = self.scheme,
            .metadata = self.metadata,
            .timeout_millis = self.timeout_millis,
            .shape = self.shape,
        };
    }
};

pub const IncrementalClientStream = struct {
    runtime: *ClientIncrementalRuntime,

    pub fn sendAlloc(self: *IncrementalClientStream, bytes: []const u8) !void {
        if (self.runtime.joined or self.runtime.requests.isClosed()) return error.StreamClosed;
        try self.runtime.requests.sendAlloc(self.runtime.allocator, bytes);
        self.runtime.channel.operation_wakeup.signal();
    }

    pub fn closeSend(self: *IncrementalClientStream) void {
        self.runtime.requests.close();
        self.runtime.channel.operation_wakeup.signal();
    }

    pub fn receive(self: *IncrementalClientStream) !?Incremental.OwnedMessage {
        const message = try self.runtime.responses.receive();
        if (message) |value| {
            self.runtime.channel.operation_wakeup.signal();
            return value;
        }
        // The final DATA callback can pause on a full application queue and
        // receive the stream-close event in the same HTTP/2 input batch. Join
        // the sole parser thread before taking its lookahead so a decoded
        // response cannot be lost behind the queue-close notification.
        self.runtime.join();
        if (try self.runtime.popBufferedResponse()) |value| return value;
        if (self.runtime.failure) |err| return err;
        if (self.runtime.call.closed.load(.acquire) and
            !self.runtime.request_eof_sent.load(.acquire) and
            !self.runtime.call.response_complete.load(.acquire)) return error.RemoteClosedBeforeHalfClose;
        return null;
    }

    pub fn finishAlloc(self: *IncrementalClientStream, allocator: std.mem.Allocator) !Grpc.StreamingResponse {
        self.closeSend();
        self.runtime.join();
        if (self.runtime.failure) |err| return err;
        var context = try parseResponseContextAlloc(allocator, &self.runtime.call);
        defer context.deinit();
        return Grpc.StreamingResponse.initFullAlloc(allocator, &.{}, .{
            .initial_metadata = context.initial_metadata.entries,
            .trailing_metadata = context.trailing_metadata.entries,
            .status = context.status.status,
        });
    }

    pub fn cancel(self: *IncrementalClientStream) void {
        self.runtime.cancelled.store(true, .release);
        self.runtime.requests.close();
        self.runtime.channel.operation_wakeup.signal();
    }

    pub fn deinit(self: *IncrementalClientStream) void {
        if (!self.runtime.joined) {
            self.cancel();
            self.runtime.join();
        }
        self.runtime.deinit();
        self.* = undefined;
    }
};

fn TypedRawClientStream(comptime Request: type, comptime Response: type, comptime RawStream: type) type {
    return struct {
        allocator: std.mem.Allocator,
        raw: RawStream,

        pub fn send(self: *@This(), request: Request) !void {
            const bytes = try Typed.encodeAlloc(self.allocator, request);
            defer self.allocator.free(bytes);
            try self.raw.sendAlloc(bytes);
        }

        pub fn receive(self: *@This()) !?Typed.Owned(Response) {
            const next = (try self.raw.receive()) orelse return null;
            var message = next;
            defer message.deinit();
            return .{ .allocator = self.allocator, .value = try Typed.decodeAlloc(Response, self.allocator, message.bytes) };
        }

        pub fn closeSend(self: *@This()) void {
            self.raw.closeSend();
        }

        pub fn finishAlloc(self: *@This(), allocator: std.mem.Allocator) !Grpc.StreamingResponse {
            return self.raw.finishAlloc(allocator);
        }

        pub fn cancel(self: *@This()) void {
            self.raw.cancel();
        }

        pub fn deinit(self: *@This()) void {
            self.raw.deinit();
            self.* = undefined;
        }
    };
}

pub fn TypedIncrementalClientStream(comptime Request: type, comptime Response: type) type {
    return TypedRawClientStream(Request, Response, IncrementalClientStream);
}

pub fn GeneratedIncrementalClient(comptime Service: type) type {
    return struct {
        channel: *PersistentChannel,
        authority: []const u8,
        capacity: usize,

        pub fn init(channel: *PersistentChannel, authority: []const u8, capacity: usize) @This() {
            return .{ .channel = channel, .authority = authority, .capacity = capacity };
        }

        pub fn open(
            self: *@This(),
            comptime method: Typed.Method(Service),
            options: Typed.GeneratedCallOptions,
        ) !TypedIncrementalClientStream(Typed.RequestType(Service, method), Typed.ResponseType(Service, method)) {
            const shape = comptime Typed.methodShape(Service, method);
            if (shape == .unary) @compileError("generated incremental open requires a streaming method");
            if (options.compression != .identity) return error.IncrementalCompressionNotSupported;
            const raw = try self.channel.openIncrementalStream(.{
                .authority = self.authority,
                .service = if (Service.package.len == 0) Service.service_name else Service.package ++ "." ++ Service.service_name,
                .method = @tagName(method),
                .metadata = options.metadata,
                .timeout_millis = options.call.timeout_millis,
                .shape = shape,
            }, self.capacity);
            return .{ .allocator = self.channel.client_impl.allocator, .raw = raw };
        }
    };
}

pub const IncrementalClientTransport = struct {
    pointer: *anyopaque,
    open_fn: *const fn (*anyopaque, IncrementalOpenRequest, usize) anyerror!IncrementalClientStream,

    pub fn from(comptime Target: type, target: *Target) IncrementalClientTransport {
        return .{
            .pointer = target,
            .open_fn = struct {
                fn open(pointer: *anyopaque, request: IncrementalOpenRequest, capacity: usize) anyerror!IncrementalClientStream {
                    return (@as(*Target, @ptrCast(@alignCast(pointer)))).openIncrementalStream(request, capacity);
                }
            }.open,
        };
    }
};

const OwnedClientCallContext = struct {
    allocator: std.mem.Allocator,
    authority: []u8,
    service: []u8,
    method: []u8,
    metadata: Grpc.MetadataBlock,
    value: Middleware.ClientCallContext,

    fn initAlloc(allocator: std.mem.Allocator, request: IncrementalOpenRequest) !OwnedClientCallContext {
        const authority = try allocator.dupe(u8, request.authority);
        errdefer allocator.free(authority);
        const service = try allocator.dupe(u8, request.service);
        errdefer allocator.free(service);
        const method = try allocator.dupe(u8, request.method);
        errdefer allocator.free(method);
        var metadata = try cloneClientMetadataAlloc(allocator, request.metadata);
        errdefer metadata.deinit();
        return .{
            .allocator = allocator,
            .authority = authority,
            .service = service,
            .method = method,
            .metadata = metadata,
            .value = .{
                .authority = authority,
                .service = service,
                .method = method,
                .shape = request.shape,
                .metadata = metadata.entries,
            },
        };
    }

    fn deinit(self: *OwnedClientCallContext) void {
        self.metadata.deinit();
        self.allocator.free(self.authority);
        self.allocator.free(self.service);
        self.allocator.free(self.method);
        self.* = undefined;
    }
};

fn cloneClientMetadataAlloc(allocator: std.mem.Allocator, entries: []const Grpc.Metadata) !Grpc.MetadataBlock {
    const output = try allocator.alloc(Grpc.Metadata, entries.len);
    errdefer allocator.free(output);
    var initialized: usize = 0;
    errdefer {
        for (output[0..initialized]) |entry| {
            allocator.free(entry.name);
            allocator.free(entry.value);
        }
    }
    for (entries, 0..) |entry, index| {
        const name = try allocator.dupe(u8, entry.name);
        errdefer allocator.free(name);
        const value = try allocator.dupe(u8, entry.value);
        output[index] = .{ .name = name, .value = value, .kind = entry.kind, .sensitive = entry.sensitive };
        initialized += 1;
    }
    return .{ .allocator = allocator, .entries = output };
}

fn finishIncrementalClientInterceptors(interceptors: []const Middleware.ClientInterceptor, entered: usize, context: *const Middleware.ClientCallContext, outcome: Middleware.ClientOutcome) void {
    var index = entered;
    while (index != 0) {
        index -= 1;
        const interceptor = interceptors[index];
        interceptor.after_fn(interceptor.pointer, context, outcome);
    }
}

fn incrementalClientFailure(err: anyerror) Middleware.ClientOutcome {
    return .{
        .code = switch (err) {
            error.CallCancelled => .cancelled,
            error.DeadlineExceeded => .deadline_exceeded,
            else => .unavailable,
        },
        .transport_failed = err != error.CallCancelled and err != error.DeadlineExceeded,
    };
}

pub const InterceptedIncrementalClient = struct {
    allocator: std.mem.Allocator,
    downstream: IncrementalClientTransport,
    interceptors: []const Middleware.ClientInterceptor,

    pub fn open(self: *InterceptedIncrementalClient, request: IncrementalOpenRequest, capacity: usize) !InterceptedIncrementalClientStream {
        var context = try OwnedClientCallContext.initAlloc(self.allocator, request);
        errdefer context.deinit();
        var entered: usize = 0;
        for (self.interceptors, 0..) |interceptor, index| {
            if (interceptor.before_fn(interceptor.pointer, &context.value)) |denied| {
                finishIncrementalClientInterceptors(self.interceptors, index, &context.value, .{ .code = denied.code });
                return error.ClientInterceptorRejected;
            }
            entered += 1;
        }
        const combined = try self.allocator.alloc(Grpc.Metadata, context.value.metadata.len + context.value.appended_metadata.len);
        defer self.allocator.free(combined);
        @memcpy(combined[0..context.value.metadata.len], context.value.metadata);
        @memcpy(combined[context.value.metadata.len..], context.value.appended_metadata);
        var forwarded = request;
        forwarded.metadata = combined;
        const raw = self.downstream.open_fn(self.downstream.pointer, forwarded, capacity) catch |err| {
            finishIncrementalClientInterceptors(self.interceptors, entered, &context.value, incrementalClientFailure(err));
            return err;
        };
        return .{
            .raw = raw,
            .context = context,
            .interceptors = self.interceptors,
            .entered = entered,
        };
    }
};

pub const InterceptedIncrementalClientStream = struct {
    raw: IncrementalClientStream,
    context: OwnedClientCallContext,
    interceptors: []const Middleware.ClientInterceptor,
    entered: usize,
    finished: bool = false,

    pub fn sendAlloc(self: *InterceptedIncrementalClientStream, bytes: []const u8) !void {
        self.raw.sendAlloc(bytes) catch |err| {
            self.finishOnce(incrementalClientFailure(err));
            return err;
        };
    }

    pub fn closeSend(self: *InterceptedIncrementalClientStream) void {
        self.raw.closeSend();
    }

    pub fn receive(self: *InterceptedIncrementalClientStream) !?Incremental.OwnedMessage {
        return self.raw.receive() catch |err| {
            self.finishOnce(incrementalClientFailure(err));
            return err;
        };
    }

    pub fn finishAlloc(self: *InterceptedIncrementalClientStream, allocator: std.mem.Allocator) !Grpc.StreamingResponse {
        const response = self.raw.finishAlloc(allocator) catch |err| {
            self.finishOnce(incrementalClientFailure(err));
            return err;
        };
        self.finishOnce(.{ .code = response.status.code });
        return response;
    }

    pub fn cancel(self: *InterceptedIncrementalClientStream) void {
        self.raw.cancel();
    }

    pub fn deinit(self: *InterceptedIncrementalClientStream) void {
        if (!self.finished) self.finishOnce(.{ .code = .cancelled });
        self.raw.deinit();
        self.context.deinit();
        self.* = undefined;
    }

    fn finishOnce(self: *InterceptedIncrementalClientStream, outcome: Middleware.ClientOutcome) void {
        if (self.finished) return;
        self.finished = true;
        finishIncrementalClientInterceptors(self.interceptors, self.entered, &self.context.value, outcome);
    }
};

pub fn GeneratedInterceptedIncrementalClient(comptime Service: type) type {
    return struct {
        client: *InterceptedIncrementalClient,
        authority: []const u8,
        capacity: usize,

        pub fn init(client: *InterceptedIncrementalClient, authority: []const u8, capacity: usize) @This() {
            return .{ .client = client, .authority = authority, .capacity = capacity };
        }

        pub fn open(
            self: *@This(),
            comptime method: Typed.Method(Service),
            options: Typed.GeneratedCallOptions,
        ) !TypedRawClientStream(Typed.RequestType(Service, method), Typed.ResponseType(Service, method), InterceptedIncrementalClientStream) {
            const shape = comptime Typed.methodShape(Service, method);
            if (shape == .unary) @compileError("generated incremental open requires a streaming method");
            if (options.compression != .identity) return error.IncrementalCompressionNotSupported;
            const raw = try self.client.open(.{
                .authority = self.authority,
                .service = if (Service.package.len == 0) Service.service_name else Service.package ++ "." ++ Service.service_name,
                .method = @tagName(method),
                .metadata = options.metadata,
                .timeout_millis = options.call.timeout_millis,
                .shape = shape,
            }, self.capacity);
            return .{ .allocator = self.client.allocator, .raw = raw };
        }
    };
}

const ClientIncrementalRuntime = struct {
    allocator: std.mem.Allocator,
    channel: *PersistentChannel,
    connection: *ClientConnection,
    call: ClientCall,
    request_header_block: Grpc.HeaderBlock,
    requests: Incremental.Pipe,
    responses: Incremental.Pipe,
    decoder: Grpc.MessageDecoder,
    pending_response: ?Incremental.OwnedMessage = null,
    request_frame: ?[]u8 = null,
    request_offset: usize = 0,
    blocked_response: bool = false,
    cancelled: std.atomic.Value(bool) = .init(false),
    request_eof_sent: std.atomic.Value(bool) = .init(false),
    failure: ?anyerror = null,
    deadline: std.Io.Clock.Timestamp,
    thread: ?std.Thread = null,
    joined: bool = false,

    fn create(channel: *PersistentChannel, connection: *ClientConnection, request: IncrementalOpenRequest, capacity: usize) !*ClientIncrementalRuntime {
        const allocator = channel.client_impl.allocator;
        const self = try allocator.create(ClientIncrementalRuntime);
        errdefer allocator.destroy(self);
        var requests = try Incremental.Pipe.init(allocator, channel.client_impl.io, capacity);
        errdefer requests.deinit();
        var responses = try Incremental.Pipe.init(allocator, channel.client_impl.io, capacity);
        errdefer responses.deinit();
        var decoder = try Grpc.MessageDecoder.init(allocator, channel.client_impl.options.limits.grpc);
        errdefer decoder.deinit();
        const body = try allocator.dupe(u8, "");
        errdefer allocator.free(body);
        var transported = request.streaming();
        transported.scheme = if (channel.client_impl.options.tls == null) "http" else "https";
        const header_request = Grpc.UnaryRequest{
            .authority = transported.authority,
            .service = transported.service,
            .method = transported.method,
            .payload = "",
            .scheme = transported.scheme,
            .metadata = transported.metadata,
            .timeout_millis = transported.timeout_millis,
        };
        var header_block = try Grpc.requestHeadersAlloc(allocator, header_request, channel.client_impl.options.limits.grpc);
        errdefer header_block.deinit();
        const request_headers = try allocator.alloc(c.nghttp2_nv, header_block.headers.len);
        errdefer allocator.free(request_headers);
        for (header_block.headers, 0..) |header, index| request_headers[index] = nv(header.name, header.value);
        self.* = .{
            .allocator = allocator,
            .channel = channel,
            .connection = connection,
            .call = .{
                .allocator = allocator,
                .request_body = body,
                .request_headers = request_headers,
                .limits = channel.client_impl.options.limits,
                .incremental = self,
            },
            .request_header_block = header_block,
            .requests = requests,
            .responses = responses,
            .decoder = decoder,
            .deadline = deadlineFromNow(channel.client_impl.io, request.timeout_millis),
        };
        return self;
    }

    fn start(self: *ClientIncrementalRuntime) !void {
        try self.channel.enqueueOperation(.{ .call = &self.call });
        self.thread = std.Thread.spawn(.{}, run, .{self}) catch |err| {
            self.channel.lock();
            _ = self.channel.pending_operations.removeCall(&self.call);
            self.channel.mutex.unlock();
            return err;
        };
    }

    fn run(self: *ClientIncrementalRuntime) void {
        const buffer = self.allocator.alloc(u8, self.channel.client_impl.options.limits.max_wire_read_bytes) catch |err| {
            self.failure = err;
            self.responses.close();
            self.channel.releaseConnection(true);
            return;
        };
        defer self.allocator.free(buffer);
        var connection_failed = false;
        while (!self.call.closed.load(.acquire)) {
            if (self.channel.failed()) {
                self.failure = error.ChannelConnectionFailed;
                connection_failed = true;
                break;
            }
            if (self.channel.pump_owner.cmpxchgStrong(false, true, .acquire, .monotonic) != null) {
                self.channel.waitForPump();
                continue;
            }
            if (self.cancelled.load(.acquire)) {
                if (self.call.stream_id == 0) {
                    _ = self.channel.removePendingCall(&self.call);
                    self.call.closed.store(true, .release);
                } else cancelPersistentStream(self.connection, &self.call) catch |err| {
                    self.failure = err;
                    connection_failed = true;
                };
                if (self.failure == null) self.failure = error.CallCancelled;
                self.channel.releasePump();
                break;
            }
            const progressed = self.progress() catch |err| {
                self.failure = err;
                connection_failed = true;
                self.channel.releasePump();
                break;
            };
            if (!progressed) {
                self.channel.releasePump();
                sleepMilliseconds(self.channel.client_impl.io, 1) catch {};
                continue;
            }
            const result = self.channel.pumpOne(self.connection, buffer, self.deadline, null);
            self.channel.releasePump();
            result catch |err| {
                if (err == error.DeadlineExceeded) {
                    while (self.channel.pump_owner.cmpxchgStrong(false, true, .acquire, .monotonic) != null) self.channel.waitForPump();
                    cancelPersistentStream(self.connection, &self.call) catch {};
                    self.channel.releasePump();
                    self.failure = err;
                } else {
                    self.failure = self.failure orelse err;
                    connection_failed = true;
                }
                break;
            };
        }
        if (self.failure == null and self.call.stream_error != c.NGHTTP2_NO_ERROR) {
            const deadline_expired = deadlineReached(self.channel.client_impl.io, self.deadline);
            self.failure = clientStreamTerminationError(
                self.call.stream_error,
                self.cancelled.load(.acquire),
                deadline_expired,
            );
        }
        if (self.failure == null) self.decoder.finish() catch |err| {
            self.failure = err;
        };
        self.responses.close();
        self.channel.releaseConnection(connection_failed);
        self.channel.lock();
        self.channel.calls += 1;
        self.channel.mutex.unlock();
        const succeeded = if (self.failure == null) blk: {
            var context = parseResponseContextAlloc(self.allocator, &self.call) catch break :blk false;
            defer context.deinit();
            break :blk context.status.status.isOk();
        } else false;
        self.channel.recordChannelzCallFinished(succeeded);
    }

    fn progress(self: *ClientIncrementalRuntime) !bool {
        if (self.call.stream_id == 0) return true;
        const resumed = c.nghttp2_session_resume_data(self.connection.session, self.call.stream_id);
        if (resumed < 0 and resumed != c.NGHTTP2_ERR_INVALID_ARGUMENT) return error.Http2Failure;
        if (self.blocked_response) {
            if (!try self.drainResponses()) return false;
            const parsed = c.nghttp2_session_mem_recv(self.connection.session, null, 0);
            if (parsed < 0) return error.Http2ReceiveFailure;
            self.blocked_response = false;
        }
        try flushSession(self.connection.session, self.connection.storage.wire());
        return true;
    }

    fn readRequest(self: *ClientIncrementalRuntime, buffer: [*c]u8, length: usize, data_flags: [*c]u32) isize {
        while (true) {
            if (self.request_frame) |frame| {
                const remaining = frame.len - self.request_offset;
                const count = @min(length, remaining);
                if (count != 0) @memcpy(buffer[0..count], frame[self.request_offset .. self.request_offset + count]);
                self.request_offset += count;
                if (self.request_offset == frame.len) {
                    self.allocator.free(frame);
                    self.request_frame = null;
                    self.request_offset = 0;
                }
                return @intCast(count);
            }
            const next = self.requests.tryReceive() catch return c.NGHTTP2_ERR_CALLBACK_FAILURE;
            if (next) |value| {
                var message = value;
                self.request_frame = Grpc.frameMessageAlloc(self.allocator, message.bytes, .{ .limits = self.call.limits.grpc }) catch {
                    message.deinit();
                    return c.NGHTTP2_ERR_CALLBACK_FAILURE;
                };
                message.deinit();
                continue;
            }
            if (self.requests.isClosed()) {
                self.request_eof_sent.store(true, .release);
                data_flags.* |= c.NGHTTP2_DATA_FLAG_EOF;
                return 0;
            }
            return c.NGHTTP2_ERR_DEFERRED;
        }
    }

    fn onResponseData(self: *ClientIncrementalRuntime, data: []const u8) c_int {
        self.decoder.push(data) catch |err| {
            self.failure = err;
            return c.NGHTTP2_ERR_CALLBACK_FAILURE;
        };
        if (!(self.drainResponses() catch |err| {
            self.failure = err;
            return c.NGHTTP2_ERR_CALLBACK_FAILURE;
        })) {
            self.blocked_response = true;
            return c.NGHTTP2_ERR_PAUSE;
        }
        return 0;
    }

    fn drainResponses(self: *ClientIncrementalRuntime) !bool {
        if (self.pending_response) |message| {
            if (!try self.responses.trySend(message)) return false;
            self.pending_response = null;
        }
        while (self.decoder.pop()) |decoded_value| {
            const message = try self.ownedResponse(decoded_value);
            if (!try self.responses.trySend(message)) {
                self.pending_response = message;
                return false;
            }
        }
        return true;
    }

    fn popBufferedResponse(self: *ClientIncrementalRuntime) !?Incremental.OwnedMessage {
        std.debug.assert(self.joined);
        if (self.pending_response) |message| {
            self.pending_response = null;
            return message;
        }
        const decoded = self.decoder.pop() orelse return null;
        return try self.ownedResponse(decoded);
    }

    fn ownedResponse(self: *ClientIncrementalRuntime, decoded_value: Grpc.OwnedMessage) !Incremental.OwnedMessage {
        var decoded = decoded_value;
        const bytes = if (decoded.compressed) blk: {
            const encoding = try headerCompression(self.call.headers.items);
            if (encoding == .identity) {
                decoded.deinit(self.allocator);
                return error.UnsupportedCompression;
            }
            const restored = try Compression.decompressAlloc(self.allocator, encoding, decoded.bytes, self.call.limits.grpc.max_message_bytes);
            decoded.deinit(self.allocator);
            break :blk restored;
        } else blk: {
            const owned = decoded.bytes;
            decoded = undefined;
            break :blk owned;
        };
        return .{ .allocator = self.allocator, .bytes = bytes };
    }

    fn join(self: *ClientIncrementalRuntime) void {
        if (self.joined) return;
        if (self.thread) |thread| thread.join();
        self.joined = true;
    }

    fn deinit(self: *ClientIncrementalRuntime) void {
        std.debug.assert(self.joined);
        self.requests.deinit();
        self.responses.deinit();
        self.decoder.deinit();
        if (self.pending_response) |*message| message.deinit();
        if (self.request_frame) |frame| self.allocator.free(frame);
        self.allocator.free(self.call.request_headers);
        self.request_header_block.deinit();
        self.call.deinit();
        const allocator = self.allocator;
        allocator.destroy(self);
    }
};

fn clientStreamTerminationError(stream_error: u32, locally_cancelled: bool, deadline_expired: bool) ?anyerror {
    if (stream_error == c.NGHTTP2_NO_ERROR) return null;
    if (locally_cancelled) return error.CallCancelled;
    // grpc-go may close a timed-out stream with RST_STREAM(CANCEL) before its
    // final status reaches the wire. Preserve the local deadline cause instead
    // of degrading the public error to a generic HTTP/2 stream failure.
    if (deadline_expired and stream_error == c.NGHTTP2_CANCEL) return error.DeadlineExceeded;
    return error.Http2StreamFailed;
}

test "incremental client preserves local cancellation and deadline causes across RST_STREAM" {
    try std.testing.expect(clientStreamTerminationError(c.NGHTTP2_NO_ERROR, false, false) == null);
    try std.testing.expect(clientStreamTerminationError(c.NGHTTP2_CANCEL, true, false).? == error.CallCancelled);
    try std.testing.expect(clientStreamTerminationError(c.NGHTTP2_CANCEL, false, true).? == error.DeadlineExceeded);
    try std.testing.expect(clientStreamTerminationError(c.NGHTTP2_INTERNAL_ERROR, false, true).? == error.Http2StreamFailed);
}

pub const PersistentChannel = struct {
    client_impl: NativeClient,
    service_config: ?Channel.ServiceConfig = null,
    connectivity: Channel.ConnectivityStateMachine = .{},
    target_uri: ?[]u8 = null,
    resolver: ?Channel.Resolver = null,
    resolved: ?Channel.AddressList = null,
    resolved_health: ?[]bool = null,
    picker: Channel.Picker = .init(.pick_first),
    selected_index: ?usize = null,
    retry_throttle: ?Channel.RetryThrottle = null,
    mutex: std.atomic.Mutex = .unlocked,
    connection: ?ClientConnection = null,
    closed: bool = false,
    connection_failed: bool = false,
    active_calls: usize = 0,
    peak_active_calls: usize = 0,
    calls: usize = 0,
    calls_started: usize = 0,
    calls_succeeded: usize = 0,
    calls_failed: usize = 0,
    connections_opened: usize = 0,
    reconnects: usize = 0,
    keepalive_pings: usize = 0,
    pending_operations: ClientOperationQueue = .{},
    pump_owner: std.atomic.Value(bool) = .init(false),
    pump_wait_mutex: std.Io.Mutex = .init,
    pump_condition: std.Io.Condition = .init,
    operation_wakeup: NotificationWakeup,
    keepalive_thread: ?std.Thread = null,
    health_watch_thread: ?std.Thread = null,
    health_watch_started: bool = false,
    health_state: std.atomic.Value(u8) = .init(@intFromEnum(ClientHealthState.disabled)),
    health_generation: std.atomic.Value(u64) = .init(0),
    ping_mutex: std.Io.Mutex = .init,
    pending_ping: ?*PingOperation = null,

    pub fn init(allocator: std.mem.Allocator, io: std.Io, options: ClientOptions) !PersistentChannel {
        const client_impl = try NativeClient.init(allocator, io, options);
        var service_config: ?Channel.ServiceConfig = null;
        errdefer if (service_config) |*config| config.deinit();
        if (options.service_config_json) |json| service_config = try Channel.ServiceConfig.parseAlloc(allocator, json, .{});
        const target_uri = if (options.target_uri) |uri| try allocator.dupe(u8, uri) else null;
        errdefer if (target_uri) |uri| allocator.free(uri);
        var resolved: ?Channel.AddressList = null;
        errdefer if (resolved) |*addresses| addresses.deinit();
        var resolved_health: ?[]bool = null;
        errdefer if (resolved_health) |health| allocator.free(health);
        if (target_uri) |uri| {
            const target = try Channel.Target.parse(uri);
            if (options.resolver) |resolver| {
                resolved = try resolver.resolveAlloc(allocator, target);
            } else {
                const addresses = try allocator.alloc(Channel.Address, 1);
                errdefer allocator.free(addresses);
                addresses[0] = .{ .host = try allocator.dupe(u8, target.host), .port = target.port };
                resolved = .{ .allocator = allocator, .addresses = addresses };
            }
            if (resolved.?.addresses.len == 0) return error.NoResolvedAddress;
            resolved_health = try allocator.alloc(bool, resolved.?.addresses.len);
            @memset(resolved_health.?, true);
        }
        var operation_wakeup = try NotificationWakeup.init();
        errdefer operation_wakeup.deinit();
        return .{
            .client_impl = client_impl,
            .service_config = service_config,
            .target_uri = target_uri,
            .resolver = options.resolver,
            .resolved = resolved,
            .resolved_health = resolved_health,
            .picker = .init(if (service_config) |config| config.load_balancing else .pick_first),
            .retry_throttle = if (service_config) |config| if (config.retry_throttling) |policy| Channel.RetryThrottle.init(policy) else null else null,
            .health_state = .init(@intFromEnum(if (service_config) |config| if (config.health_service != null) ClientHealthState.connecting else .disabled else .disabled)),
            .operation_wakeup = operation_wakeup,
        };
    }

    pub fn deinit(self: *PersistentChannel) void {
        self.lock();
        self.closed = true;
        self.connection_failed = true;
        self.connectivity.transition(.shutdown) catch {};
        self.health_state.store(@intFromEnum(ClientHealthState.shutdown), .release);
        _ = self.health_generation.fetchAdd(1, .acq_rel);
        if (self.connection) |*connection| connection.storage.wire().cancelRead();
        self.mutex.unlock();
        if (self.health_watch_thread) |thread| thread.join();
        if (self.keepalive_thread) |thread| thread.join();
        while (true) {
            self.lock();
            const complete = self.active_calls == 0;
            self.mutex.unlock();
            if (complete) break;
            sleepMilliseconds(self.client_impl.io, 1) catch break;
        }
        self.lock();
        self.disconnect();
        self.mutex.unlock();
        self.operation_wakeup.deinit();
        self.pending_operations.deinit(self.client_impl.allocator);
        if (self.service_config) |*config| config.deinit();
        if (self.resolved_health) |health| self.client_impl.allocator.free(health);
        if (self.resolved) |*addresses| addresses.deinit();
        if (self.target_uri) |uri| self.client_impl.allocator.free(uri);
        self.* = undefined;
    }

    pub fn snapshot(self: *PersistentChannel) ChannelSnapshot {
        self.lock();
        defer self.mutex.unlock();
        return .{
            .connected = self.connection != null,
            .connectivity = self.connectivity.snapshot(),
            .calls = self.calls,
            .calls_started = self.calls_started,
            .calls_succeeded = self.calls_succeeded,
            .calls_failed = self.calls_failed,
            .connections_opened = self.connections_opened,
            .reconnects = self.reconnects,
            .active_calls = self.active_calls,
            .peak_active_calls = self.peak_active_calls,
            .keepalive_pings = self.keepalive_pings,
            .resolved_addresses = if (self.resolved) |addresses| addresses.addresses.len else 0,
            .selected_address = if (self.selected_index) |index| self.resolved.?.addresses[index] else null,
            .retry_tokens_milli = if (self.retry_throttle) |throttle| throttle.tokens_milli else null,
            .health_state = @enumFromInt(self.health_state.load(.acquire)),
            .health_generation = self.health_generation.load(.acquire),
        };
    }

    pub fn client(self: *PersistentChannel) Grpc.Client {
        return .{ .ptr = self, .invoke_fn = invokeErased };
    }

    pub fn invokeAlloc(self: *PersistentChannel, allocator: std.mem.Allocator, request: Grpc.UnaryRequest, options: Grpc.CallOptions) anyerror!Grpc.UnaryResponse {
        try options.checkActive();
        try request.validate(self.client_impl.options.limits.grpc);
        try self.ensureKeepaliveStarted();
        var metadata = try prepareCredentialMetadataAlloc(allocator, self.client_impl.options.credentials, .{
            .authority = request.authority,
            .service = request.service,
            .method = request.method,
            .shape = .unary,
        }, request.metadata);
        defer metadata.deinit();
        var effective_request = request;
        effective_request.metadata = metadata.entries;
        try effective_request.validate(self.client_impl.options.limits.grpc);
        const method_config = if (self.service_config) |*config| config.method(effective_request.service, effective_request.method) else null;
        effective_request.timeout_millis = @min(effective_request.timeout_millis, options.timeout_millis);
        if (method_config) |config| if (config.timeout_millis) |timeout| {
            effective_request.timeout_millis = @min(effective_request.timeout_millis, timeout);
        };
        const overall_deadline = deadlineFromNow(self.client_impl.io, effective_request.timeout_millis);
        try self.waitForHealthy(effective_request.service, effective_request.method, overall_deadline, options);
        const hedging_policy = if (request.idempotency == .no_side_effects) if (method_config) |config| config.hedging else null else null;
        if (hedging_policy) |policy| {
            if (method_config) |config| if (config.wait_for_ready) try self.waitUntilReady(overall_deadline, options);
            const response = try self.invokeHedgedAlloc(allocator, effective_request, options, policy, overall_deadline);
            if (response.status.code == .ok) {
                self.recordRetrySuccess();
            } else if (policy.non_fatal[@intFromEnum(response.status.code)]) {
                _ = self.recordRetryFailureAllowed();
            }
            return response;
        }
        const retry_policy = if (request.idempotency == .unknown) null else if (method_config) |config| config.retry else null;
        const max_attempts: u8 = if (request.idempotency == .unknown) 1 else if (retry_policy) |policy| policy.max_attempts else 2;
        if (method_config) |config| if (config.wait_for_ready) try self.waitUntilReady(overall_deadline, options);
        var attempt: u8 = 1;
        while (true) : (attempt += 1) {
            try options.checkActive();
            effective_request.timeout_millis = try remainingDeadlineMillis(self.client_impl.io, overall_deadline);
            var commitment: Channel.Commitment = .uncommitted;
            if (self.client_impl.options.causal) |facts| facts.emit(.attempt, "started", effective_request.service, effective_request.method);
            var response = self.invokeAttempt(allocator, effective_request, options, &commitment) catch |err| {
                if (self.client_impl.options.causal) |facts| {
                    facts.emit(.attempt, "failed", effective_request.service, effective_request.method);
                    facts.emit(.status, @errorName(err), effective_request.service, effective_request.method);
                }
                if (err == error.CallCancelled or err == error.DeadlineExceeded or attempt >= max_attempts) return err;
                if (commitment != .uncommitted) return err;
                if (retry_policy) |policy| {
                    if (!policy.allows(.unavailable)) return err;
                    if (!self.recordRetryFailureAllowed()) return err;
                    if (self.client_impl.options.causal) |facts| facts.emit(.retry, "scheduled", effective_request.service, effective_request.method);
                    try self.waitForRetry(policy.delayMillis(attempt, attempt), overall_deadline, options);
                }
                self.lock();
                self.reconnects += 1;
                self.mutex.unlock();
                continue;
            };
            if (self.client_impl.options.causal) |facts| {
                facts.emit(.attempt, if (response.status.code == .ok) "succeeded" else "failed", effective_request.service, effective_request.method);
                facts.emit(.status, @tagName(response.status.code), effective_request.service, effective_request.method);
            }
            if (attempt >= max_attempts) return response;
            const retryable = if (retry_policy) |policy| policy.allows(response.status.code) else false;
            if (!retryable) {
                if (response.status.code == .ok) self.recordRetrySuccess();
                return response;
            }
            if (!self.recordRetryFailureAllowed()) return response;
            const pushback = response.retry_pushback_millis;
            if (pushback) |delay| if (delay < 0) return response;
            response.deinit();
            const delay = if (pushback) |value| @as(u64, @intCast(value)) else retry_policy.?.delayMillis(attempt, attempt);
            if (self.client_impl.options.causal) |facts| facts.emit(.retry, "scheduled", effective_request.service, effective_request.method);
            try self.waitForRetry(delay, overall_deadline, options);
        }
    }

    fn invokeHedgedAlloc(
        self: *PersistentChannel,
        allocator: std.mem.Allocator,
        request: Grpc.UnaryRequest,
        options: Grpc.CallOptions,
        policy: Channel.HedgingPolicy,
        overall_deadline: std.Io.Clock.Timestamp,
    ) !Grpc.UnaryResponse {
        var done = std.atomic.Value(bool).init(false);
        const Attempt = struct {
            channel: *PersistentChannel,
            request: Grpc.UnaryRequest,
            options: Grpc.CallOptions,
            done: *const std.atomic.Value(bool),
            response: ?Grpc.UnaryResponse = null,
            failure: ?anyerror = null,
            commitment: Channel.Commitment = .uncommitted,
            complete: std.atomic.Value(bool) = .init(false),
            consumed: bool = false,

            fn run(attempt: *@This()) void {
                defer attempt.complete.store(true, .release);
                var call_options = attempt.options;
                call_options.cancellation = .{
                    .ptr = attempt,
                    .is_cancelled_fn = cancelled,
                };
                attempt.response = attempt.channel.invokeAttempt(std.heap.smp_allocator, attempt.request, call_options, &attempt.commitment) catch |err| {
                    attempt.failure = err;
                    return;
                };
            }

            fn cancelled(pointer: *const anyopaque) bool {
                const attempt: *const @This() = @ptrCast(@alignCast(pointer));
                if (attempt.done.load(.acquire)) return true;
                if (attempt.options.cancellation) |upstream| return upstream.isCancelled();
                return false;
            }
        };

        const maximum_attempts: usize = policy.max_attempts;
        const attempts = try self.client_impl.allocator.alloc(Attempt, maximum_attempts);
        defer self.client_impl.allocator.free(attempts);
        const threads = try self.client_impl.allocator.alloc(?std.Thread, maximum_attempts);
        defer self.client_impl.allocator.free(threads);
        @memset(threads, null);
        var launched: usize = 0;
        defer {
            done.store(true, .release);
            for (threads[0..launched]) |maybe_thread| if (maybe_thread) |thread| thread.join();
            for (attempts[0..launched]) |*attempt| if (attempt.response) |*response| response.deinit();
        }

        var completed: usize = 0;
        var winner: ?usize = null;
        var last_response: ?usize = null;
        var last_failure: ?anyerror = null;
        var terminal_error: ?anyerror = null;
        var stop_launching = false;
        var next_launch_millis = awakeMillis(self.client_impl.io);

        while (true) {
            options.checkActive() catch |err| {
                terminal_error = err;
                break;
            };
            _ = remainingDeadlineMillis(self.client_impl.io, overall_deadline) catch |err| {
                terminal_error = err;
                break;
            };

            for (attempts[0..launched], 0..) |*attempt, index| {
                if (attempt.consumed or !attempt.complete.load(.acquire)) continue;
                attempt.consumed = true;
                completed += 1;
                if (attempt.response) |*response| {
                    last_response = index;
                    if (!policy.non_fatal[@intFromEnum(response.status.code)]) {
                        winner = index;
                        break;
                    }
                    if (response.retry_pushback_millis) |pushback| {
                        if (pushback < 0) {
                            stop_launching = true;
                        } else {
                            next_launch_millis = awakeMillis(self.client_impl.io) +| @as(u64, @intCast(pushback));
                        }
                    }
                } else if (attempt.failure) |err| {
                    last_failure = err;
                    if (attempt.commitment != .uncommitted) {
                        terminal_error = err;
                        stop_launching = true;
                        break;
                    }
                }
            }
            if (winner != null or terminal_error != null) break;

            const now = awakeMillis(self.client_impl.io);
            if (!stop_launching and launched < maximum_attempts and now >= next_launch_millis) {
                const remaining = remainingDeadlineMillis(self.client_impl.io, overall_deadline) catch |err| {
                    terminal_error = err;
                    break;
                };
                var attempt_request = request;
                attempt_request.timeout_millis = remaining;
                var attempt_options = options;
                attempt_options.timeout_millis = remaining;
                attempts[launched] = .{
                    .channel = self,
                    .request = attempt_request,
                    .options = attempt_options,
                    .done = &done,
                };
                threads[launched] = try std.Thread.spawn(.{}, Attempt.run, .{&attempts[launched]});
                launched += 1;
                next_launch_millis = now +| policy.hedging_delay_millis;
                continue;
            }

            if (completed == launched and (stop_launching or launched == maximum_attempts)) break;
            try sleepMilliseconds(self.client_impl.io, 1);
        }

        done.store(true, .release);
        if (winner orelse last_response) |index| {
            const response = &attempts[index].response.?;
            return Grpc.UnaryResponse.initFullAlloc(allocator, .{
                .payload = response.payload,
                .initial_metadata = response.initial_metadata,
                .trailing_metadata = response.trailing_metadata,
                .status = response.status,
                .retry_pushback_millis = response.retry_pushback_millis,
            });
        }
        if (terminal_error) |err| return err;
        if (last_failure) |err| return err;
        return error.HedgingAttemptsExhausted;
    }

    fn recordRetryFailureAllowed(self: *PersistentChannel) bool {
        self.lock();
        defer self.mutex.unlock();
        if (self.retry_throttle) |*throttle| return throttle.recordFailureAndAllow();
        return true;
    }

    fn waitForHealthy(
        self: *PersistentChannel,
        service: []const u8,
        method: []const u8,
        deadline: std.Io.Clock.Timestamp,
        options: Grpc.CallOptions,
    ) !void {
        const health_service = if (self.service_config) |*config| config.health_service else null;
        if (health_service == null or (std.mem.eql(u8, service, "grpc.health.v1.Health") and
            (std.mem.eql(u8, method, "Check") or std.mem.eql(u8, method, "Watch")))) return;
        try self.ensureHealthWatchStarted();
        while (true) {
            try options.checkActive();
            if (deadlineReached(self.client_impl.io, deadline)) return error.DeadlineExceeded;
            const state: ClientHealthState = @enumFromInt(self.health_state.load(.acquire));
            switch (state) {
                .serving => return,
                .shutdown => return error.ChannelClosed,
                .disabled => return,
                .connecting, .not_serving, .service_unknown, .failed => try sleepMilliseconds(self.client_impl.io, 1),
            }
        }
    }

    fn ensureHealthWatchStarted(self: *PersistentChannel) !void {
        self.lock();
        defer self.mutex.unlock();
        if (self.closed) return error.ChannelClosed;
        if (self.health_watch_started) return;
        if (self.service_config == null or self.service_config.?.health_service == null) return;
        self.health_watch_started = true;
        self.health_watch_thread = std.Thread.spawn(.{}, healthWatchLoop, .{self}) catch |err| {
            self.health_watch_started = false;
            return err;
        };
    }

    fn healthWatchLoop(self: *PersistentChannel) void {
        var backoff_millis: u64 = 10;
        while (!self.isClosed()) {
            self.publishHealth(.connecting);
            self.runHealthWatch() catch {
                if (self.isClosed()) return;
                self.publishHealth(.failed);
                sleepMilliseconds(self.client_impl.io, backoff_millis) catch return;
                backoff_millis = @min(backoff_millis *| 2, 1_000);
                continue;
            };
            backoff_millis = 10;
        }
    }

    fn runHealthWatch(self: *PersistentChannel) !void {
        const watched_service = self.service_config.?.health_service.?;
        const encoded = try Typed.encodeAlloc(self.client_impl.allocator, HealthProto.HealthCheckRequest{ .service = watched_service });
        defer self.client_impl.allocator.free(encoded);
        var stream = try self.openIncrementalStreamRaw(.{
            .authority = self.client_impl.options.host,
            .service = "grpc.health.v1.Health",
            .method = "Watch",
            .timeout_millis = 24 * 60 * 60 * 1_000,
            .shape = .server_streaming,
        }, 1);
        defer stream.deinit();
        try stream.sendAlloc(encoded);
        stream.closeSend();
        while (try stream.receive()) |message_value| {
            var message = message_value;
            defer message.deinit();
            var response = try Typed.decodeAlloc(HealthProto.HealthCheckResponse, self.client_impl.allocator, message.bytes);
            defer response.deinit(self.client_impl.allocator);
            self.publishHealth(switch (response.status) {
                .SERVING => .serving,
                .SERVICE_UNKNOWN => .service_unknown,
                .UNKNOWN, .NOT_SERVING => .not_serving,
                else => .not_serving,
            });
        }
        return error.HealthWatchClosed;
    }

    fn publishHealth(self: *PersistentChannel, state: ClientHealthState) void {
        const previous = self.health_state.swap(@intFromEnum(state), .acq_rel);
        if (previous == @intFromEnum(state)) return;
        _ = self.health_generation.fetchAdd(1, .acq_rel);
    }

    fn isClosed(self: *PersistentChannel) bool {
        self.lock();
        defer self.mutex.unlock();
        return self.closed;
    }

    fn recordRetrySuccess(self: *PersistentChannel) void {
        self.lock();
        defer self.mutex.unlock();
        if (self.retry_throttle) |*throttle| throttle.recordSuccess();
    }

    fn waitUntilReady(self: *PersistentChannel, deadline: std.Io.Clock.Timestamp, options: Grpc.CallOptions) !void {
        var attempt: u8 = 1;
        const backoff = Channel.RetryPolicy{
            .max_attempts = std.math.maxInt(u8),
            .initial_backoff_millis = 10,
            .max_backoff_millis = 1_000,
            .backoff_multiplier_milli = 1_600,
        };
        while (true) : (attempt +|= 1) {
            try options.checkActive();
            self.lock();
            if (self.closed) {
                self.mutex.unlock();
                return error.ChannelClosed;
            }
            if (self.connection_failed and self.active_calls == 0) {
                self.disconnect();
                self.connection_failed = false;
            }
            const connected = self.connection != null or blk: {
                self.ensureConnected() catch {
                    self.disconnect();
                    self.mutex.unlock();
                    try self.waitForRetry(backoff.delayMillis(attempt, attempt), deadline, options);
                    continue;
                };
                break :blk true;
            };
            self.mutex.unlock();
            if (connected) return;
        }
    }

    fn waitForRetry(self: *PersistentChannel, delay_millis: u64, deadline: std.Io.Clock.Timestamp, options: Grpc.CallOptions) !void {
        try options.checkActive();
        const remaining = try remainingDeadlineMillis(self.client_impl.io, deadline);
        if (delay_millis >= remaining) return error.DeadlineExceeded;
        try sleepMilliseconds(self.client_impl.io, delay_millis);
        try options.checkActive();
    }

    pub fn invokeStreamingAlloc(self: *PersistentChannel, allocator: std.mem.Allocator, request: Grpc.StreamingRequest, options: Grpc.CallOptions) anyerror!Grpc.StreamingResponse {
        try options.checkActive();
        try request.validate(self.client_impl.options.limits.grpc);
        try self.ensureKeepaliveStarted();
        var metadata = try prepareCredentialMetadataAlloc(allocator, self.client_impl.options.credentials, .{
            .authority = request.authority,
            .service = request.service,
            .method = request.method,
            .shape = request.shape,
        }, request.metadata);
        defer metadata.deinit();
        var forwarded = request;
        forwarded.metadata = metadata.entries;
        try forwarded.validate(self.client_impl.options.limits.grpc);
        try self.waitForHealthy(
            forwarded.service,
            forwarded.method,
            deadlineFromNow(self.client_impl.io, @min(forwarded.timeout_millis, options.timeout_millis)),
            options,
        );
        self.recordChannelzCallStarted();
        var channelz_finished = false;
        errdefer if (!channelz_finished) self.recordChannelzCallFinished(false);
        const connection = try self.acquireConnection();
        var released = false;
        errdefer if (!released) self.releaseConnection(true);
        const response = invokePersistentStreamingAlloc(self, connection, allocator, forwarded, options) catch |err| {
            self.releaseConnection(err != error.CallCancelled and err != error.DeadlineExceeded);
            released = true;
            return err;
        };
        self.releaseConnection(false);
        released = true;
        self.lock();
        self.calls += 1;
        self.mutex.unlock();
        self.recordChannelzCallFinished(response.status.isOk());
        channelz_finished = true;
        return response;
    }

    pub fn openIncrementalStream(self: *PersistentChannel, request: IncrementalOpenRequest, capacity: usize) !IncrementalClientStream {
        if (self.client_impl.options.causal) |facts| facts.emit(.stream, "started", request.service, request.method);
        try self.waitForHealthy(
            request.service,
            request.method,
            deadlineFromNow(self.client_impl.io, request.timeout_millis),
            .{ .limits = self.client_impl.options.limits.grpc, .timeout_millis = request.timeout_millis },
        );
        const stream = self.openIncrementalStreamRaw(request, capacity) catch |err| {
            if (self.client_impl.options.causal) |facts| facts.emit(.stream, @errorName(err), request.service, request.method);
            return err;
        };
        if (self.client_impl.options.causal) |facts| facts.emit(.stream, "opened", request.service, request.method);
        return stream;
    }

    fn openIncrementalStreamRaw(self: *PersistentChannel, request: IncrementalOpenRequest, capacity: usize) !IncrementalClientStream {
        if (capacity == 0) return error.InvalidLimits;
        try request.streaming().validate(self.client_impl.options.limits.grpc);
        try self.ensureKeepaliveStarted();
        var metadata = try prepareCredentialMetadataAlloc(self.client_impl.allocator, self.client_impl.options.credentials, .{
            .authority = request.authority,
            .service = request.service,
            .method = request.method,
            .shape = request.shape,
        }, request.metadata);
        defer metadata.deinit();
        var forwarded = request;
        forwarded.metadata = metadata.entries;
        try forwarded.streaming().validate(self.client_impl.options.limits.grpc);
        self.recordChannelzCallStarted();
        var channelz_transferred = false;
        errdefer if (!channelz_transferred) self.recordChannelzCallFinished(false);
        const connection = try self.acquireConnection();
        const runtime = ClientIncrementalRuntime.create(self, connection, forwarded, capacity) catch |err| {
            self.releaseConnection(false);
            return err;
        };
        runtime.start() catch |err| {
            runtime.joined = true;
            runtime.deinit();
            self.releaseConnection(false);
            return err;
        };
        channelz_transferred = true;
        return .{ .runtime = runtime };
    }

    pub fn ping(self: *PersistentChannel, ping_data: [8]u8) !void {
        self.ping_mutex.lockUncancelable(self.client_impl.io);
        defer self.ping_mutex.unlock(self.client_impl.io);
        const connection = try self.acquireConnection();
        var failed_call = false;
        defer self.releaseConnection(failed_call);
        var operation = PingOperation{ .data = ping_data };
        try self.enqueueOperation(.{ .ping = &operation });
        const buffer = try self.client_impl.allocator.alloc(u8, self.client_impl.options.limits.max_wire_read_bytes);
        defer self.client_impl.allocator.free(buffer);
        const deadline = deadlineFromNow(self.client_impl.io, self.client_impl.options.keepalive_timeout_millis);
        while (!operation.completed.load(.acquire)) {
            if (self.failed()) {
                failed_call = true;
                self.clearPendingPing(&operation);
                return error.ChannelConnectionFailed;
            }
            if (self.pump_owner.cmpxchgStrong(false, true, .acquire, .monotonic) == null) {
                if (operation.completed.load(.acquire)) {
                    self.releasePump();
                    break;
                }
                const result = self.pumpOne(connection, buffer, deadline, null);
                self.releasePump();
                result catch |err| {
                    failed_call = true;
                    self.clearPendingPing(&operation);
                    return err;
                };
            } else self.waitForPump();
        }
        self.lock();
        self.keepalive_pings += 1;
        self.mutex.unlock();
    }

    fn invokeAttempt(
        self: *PersistentChannel,
        allocator: std.mem.Allocator,
        request: Grpc.UnaryRequest,
        options: Grpc.CallOptions,
        commitment: *Channel.Commitment,
    ) !Grpc.UnaryResponse {
        const started_at = std.Io.Clock.Timestamp.now(self.client_impl.io, .awake);
        self.recordChannelzCallStarted();
        var channelz_finished = false;
        errdefer if (!channelz_finished) self.recordChannelzCallFinished(false);
        const connection = try self.acquireConnection();
        var released = false;
        errdefer if (!released) self.releaseConnection(true);
        const response = invokePersistentAlloc(self, connection, allocator, request, options, commitment) catch |err| {
            self.releaseConnection(err != error.CallCancelled and err != error.DeadlineExceeded);
            released = true;
            self.recordClientAttemptTelemetry(request, .unavailable, started_at);
            return err;
        };
        self.releaseConnection(false);
        released = true;
        self.lock();
        self.calls += 1;
        self.mutex.unlock();
        self.recordChannelzCallFinished(response.status.isOk());
        self.recordClientAttemptTelemetry(request, response.status.code, started_at);
        channelz_finished = true;
        return response;
    }

    fn recordClientAttemptTelemetry(
        self: *PersistentChannel,
        request: Grpc.UnaryRequest,
        code: Grpc.Code,
        started_at: std.Io.Clock.Timestamp,
    ) void {
        const telemetry = self.client_impl.options.telemetry orelse return;
        const finished_at = std.Io.Clock.Timestamp.now(self.client_impl.io, .awake);
        telemetry.recordClientAttempt(
            request.service,
            request.method,
            code,
            elapsedTimestampMillis(started_at, finished_at),
            @intCast(@max(std.Io.Clock.Timestamp.now(self.client_impl.io, .real).raw.nanoseconds, 0)),
        );
    }

    fn recordChannelzCallStarted(self: *PersistentChannel) void {
        self.lock();
        self.calls_started +|= 1;
        self.mutex.unlock();
    }

    fn recordChannelzCallFinished(self: *PersistentChannel, succeeded: bool) void {
        self.lock();
        if (succeeded) self.calls_succeeded +|= 1 else self.calls_failed +|= 1;
        self.mutex.unlock();
    }

    fn acquireConnection(self: *PersistentChannel) !*ClientConnection {
        while (true) {
            self.lock();
            if (self.closed) {
                self.mutex.unlock();
                return error.ChannelClosed;
            }
            if (self.connection_failed) {
                if (self.active_calls == 0) {
                    self.disconnect();
                    self.connection_failed = false;
                } else {
                    self.mutex.unlock();
                    try sleepMilliseconds(self.client_impl.io, 1);
                    continue;
                }
            }
            if (self.active_calls >= self.client_impl.options.max_concurrent_streams) {
                self.mutex.unlock();
                try sleepMilliseconds(self.client_impl.io, 1);
                continue;
            }
            self.ensureConnected() catch |err| {
                self.mutex.unlock();
                return err;
            };
            self.active_calls += 1;
            self.peak_active_calls = @max(self.peak_active_calls, self.active_calls);
            const connection = &self.connection.?;
            self.mutex.unlock();
            return connection;
        }
    }

    fn releaseConnection(self: *PersistentChannel, failed_call: bool) void {
        self.lock();
        if (failed_call) {
            self.connection_failed = true;
            self.connectivity.transition(.transient_failure) catch {};
            if (self.connection) |*connection| connection.storage.wire().cancelRead();
        }
        std.debug.assert(self.active_calls != 0);
        self.active_calls -= 1;
        if (self.active_calls == 0 and self.connection_failed) {
            self.drainOperations();
            self.disconnect();
            self.connection_failed = false;
        }
        self.mutex.unlock();
    }

    fn enqueueOperation(self: *PersistentChannel, operation: ClientOperation) !void {
        self.lock();
        if (self.closed) {
            self.mutex.unlock();
            return error.ChannelClosed;
        }
        if (self.connection_failed) {
            self.mutex.unlock();
            return error.ChannelConnectionFailed;
        }
        if (self.pending_operations.count() >= self.client_impl.options.max_concurrent_streams + 1) {
            self.mutex.unlock();
            return error.ChannelSaturated;
        }
        self.pending_operations.append(self.client_impl.allocator, operation) catch |err| {
            self.mutex.unlock();
            return err;
        };
        self.mutex.unlock();
        self.operation_wakeup.signal();
    }

    fn pumpOne(self: *PersistentChannel, connection: *ClientConnection, buffer: []u8, deadline: ?std.Io.Clock.Timestamp, cancellation: ?Grpc.Cancellation) !void {
        if (self.popPendingOperation()) |operation| return self.processOperation(connection, operation);
        if (cancellation) |token| if (token.isCancelled()) return error.CallCancelled;
        if (deadline) |value| if (deadlineReached(self.client_impl.io, value)) return error.DeadlineExceeded;
        var descriptors = [_]std.posix.pollfd{
            .{
                .fd = connection.storage.socketHandle(),
                .events = std.posix.POLL.IN | std.posix.POLL.ERR,
                .revents = 0,
            },
            .{
                .fd = self.operation_wakeup.read_fd,
                .events = std.posix.POLL.IN | std.posix.POLL.ERR,
                .revents = 0,
            },
        };
        _ = try std.posix.poll(&descriptors, 10);
        if ((descriptors[0].revents & (std.posix.POLL.IN | std.posix.POLL.ERR)) != 0) {
            const count = try connection.storage.wire().read(buffer);
            if (count == 0) return error.ConnectionClosed;
            const consumed = c.nghttp2_session_mem_recv(connection.session, buffer.ptr, count);
            if (consumed < 0 or consumed != count) return error.Http2ReceiveFailure;
            try flushSession(connection.session, connection.storage.wire());
        }
        if ((descriptors[1].revents & (std.posix.POLL.IN | std.posix.POLL.ERR)) != 0) {
            self.operation_wakeup.drain();
            if (self.popPendingOperation()) |operation| try self.processOperation(connection, operation);
        }
    }

    fn processOperation(self: *PersistentChannel, connection: *ClientConnection, operation: ClientOperation) !void {
        switch (operation) {
            .call => |call| {
                var provider = c.nghttp2_data_provider{ .source = .{ .ptr = call }, .read_callback = clientDataRead };
                const stream_id = c.nghttp2_submit_request(connection.session, null, call.request_headers.ptr, call.request_headers.len, &provider, call);
                if (stream_id < 0) return error.Http2SubmitFailed;
                call.stream_id = stream_id;
                try flushSession(connection.session, connection.storage.wire());
            },
            .ping => |ping_operation| {
                self.lock();
                if (self.pending_ping != null) {
                    self.mutex.unlock();
                    return error.PingAlreadyInFlight;
                }
                self.pending_ping = ping_operation;
                self.mutex.unlock();
                checkNghttp(c.nghttp2_submit_ping(connection.session, c.NGHTTP2_FLAG_NONE, &ping_operation.data)) catch |err| {
                    self.clearPendingPing(ping_operation);
                    return err;
                };
                flushSession(connection.session, connection.storage.wire()) catch |err| {
                    self.clearPendingPing(ping_operation);
                    return err;
                };
            },
        }
    }

    fn clearPendingPing(self: *PersistentChannel, operation: *PingOperation) void {
        self.lock();
        defer self.mutex.unlock();
        if (self.pending_ping == operation) self.pending_ping = null;
    }

    fn popPendingOperation(self: *PersistentChannel) ?ClientOperation {
        self.lock();
        defer self.mutex.unlock();
        return self.pending_operations.pop();
    }

    fn releasePump(self: *PersistentChannel) void {
        self.pump_owner.store(false, .release);
        self.pump_wait_mutex.lockUncancelable(self.client_impl.io);
        self.pump_condition.broadcast(self.client_impl.io);
        self.pump_wait_mutex.unlock(self.client_impl.io);
    }

    fn waitForPump(self: *PersistentChannel) void {
        self.pump_wait_mutex.lockUncancelable(self.client_impl.io);
        defer self.pump_wait_mutex.unlock(self.client_impl.io);
        while (self.pump_owner.load(.acquire)) self.pump_condition.waitUncancelable(self.client_impl.io, &self.pump_wait_mutex);
    }

    fn removePendingCall(self: *PersistentChannel, target: *ClientCall) bool {
        self.lock();
        defer self.mutex.unlock();
        return self.pending_operations.removeCall(target);
    }

    fn failed(self: *PersistentChannel) bool {
        self.lock();
        defer self.mutex.unlock();
        return self.closed or self.connection_failed;
    }

    fn markConnectionFailed(self: *PersistentChannel) void {
        self.lock();
        self.connection_failed = true;
        self.connectivity.transition(.transient_failure) catch {};
        if (self.connection) |*connection| connection.storage.wire().cancelRead();
        self.mutex.unlock();
    }

    fn drainOperations(self: *PersistentChannel) void {
        self.pending_operations.clearRetainingCapacity();
    }

    fn ensureKeepaliveStarted(self: *PersistentChannel) !void {
        if (self.client_impl.options.keepalive_interval_millis == null) return;
        self.lock();
        defer self.mutex.unlock();
        if (self.keepalive_thread == null and !self.closed) self.keepalive_thread = try std.Thread.spawn(.{}, keepaliveLoop, .{self});
    }

    fn keepaliveLoop(self: *PersistentChannel) void {
        const interval = self.client_impl.options.keepalive_interval_millis orelse return;
        var sequence: u64 = 1;
        while (true) {
            var waited: u64 = 0;
            while (waited < interval) {
                self.lock();
                const stop = self.closed;
                const connected = self.connection != null;
                self.mutex.unlock();
                if (stop) return;
                const step = @min(interval - waited, 50);
                sleepMilliseconds(self.client_impl.io, step) catch return;
                waited += step;
                if (!connected and waited == interval) break;
            }
            self.lock();
            const stop = self.closed;
            const connected = self.connection != null and !self.connection_failed and self.active_calls == 0;
            self.mutex.unlock();
            if (stop) return;
            if (connected) {
                var data: [8]u8 = undefined;
                std.mem.writeInt(u64, &data, sequence, .big);
                self.ping(data) catch {};
                sequence +%= 1;
            }
        }
    }

    fn ensureConnected(self: *PersistentChannel) !void {
        if (self.connection != null) return;
        if (self.client_impl.options.causal) |facts| facts.emit(.connect, "started", "channel", "connect");
        try self.resolveAndPick();
        if (self.connectivity.state == .ready) self.connectivity.transition(.idle) catch {};
        try self.connectivity.transition(.connecting);
        self.connection = ClientConnection.init(&self.client_impl) catch |err| {
            self.connectivity.transition(.transient_failure) catch {};
            if (self.client_impl.options.causal) |facts| facts.emit(.connect, @errorName(err), "channel", "connect");
            return err;
        };
        c.nghttp2_session_set_user_data(self.connection.?.session, self);
        self.connections_opened += 1;
        try self.connectivity.transition(.ready);
        if (self.client_impl.options.telemetry) |telemetry| telemetry.recordConnection(
            "ready",
            1,
            @intCast(@max(std.Io.Clock.Timestamp.now(self.client_impl.io, .real).raw.nanoseconds, 0)),
        );
        if (self.client_impl.options.causal) |facts| facts.emit(.connect, "succeeded", "channel", "connect");
    }

    fn disconnect(self: *PersistentChannel) void {
        if (self.connection) |*connection| {
            connection.deinit();
            if (self.client_impl.options.telemetry) |telemetry| telemetry.recordConnection(
                "closed",
                -1,
                @intCast(@max(std.Io.Clock.Timestamp.now(self.client_impl.io, .real).raw.nanoseconds, 0)),
            );
        }
        self.connection = null;
        if (self.connectivity.state == .ready) self.connectivity.transition(.idle) catch {};
    }

    fn resolveAndPick(self: *PersistentChannel) !void {
        if (self.client_impl.options.causal) |facts| facts.emit(.resolve, "started", "channel", "resolve");
        if (self.target_uri == null) {
            if (self.client_impl.options.causal) |facts| {
                facts.emit(.resolve, "succeeded", "channel", "resolve");
                facts.emit(.pick, "succeeded", "channel", "pick");
            }
            return;
        }
        if (self.resolver) |resolver| {
            var replacement = try resolver.resolveAlloc(self.client_impl.allocator, try Channel.Target.parse(self.target_uri.?));
            errdefer replacement.deinit();
            if (replacement.addresses.len == 0) return error.NoResolvedAddress;
            const replacement_health = try self.client_impl.allocator.alloc(bool, replacement.addresses.len);
            @memset(replacement_health, true);
            if (self.resolved_health) |health| self.client_impl.allocator.free(health);
            if (self.resolved) |*addresses| addresses.deinit();
            self.resolved = replacement;
            self.resolved_health = replacement_health;
        }
        const index = try self.picker.pickIndex(self.resolved.?.addresses, self.resolved_health.?);
        const address = self.resolved.?.addresses[index];
        self.selected_index = index;
        self.client_impl.options.host = address.host;
        self.client_impl.options.port = address.port;
        if (self.client_impl.options.causal) |facts| {
            facts.emit(.resolve, "succeeded", "channel", "resolve");
            facts.emit(.pick, "succeeded", "channel", "pick");
        }
    }

    fn lock(self: *PersistentChannel) void {
        while (!self.mutex.tryLock()) std.Thread.yield() catch {};
    }

    fn invokeErased(pointer: *anyopaque, allocator: std.mem.Allocator, request: Grpc.UnaryRequest, options: Grpc.CallOptions) anyerror!Grpc.UnaryResponse {
        return (@as(*PersistentChannel, @ptrCast(@alignCast(pointer)))).invokeAlloc(allocator, request, options);
    }
};

fn invokePersistentAlloc(
    channel: *PersistentChannel,
    connection: *ClientConnection,
    allocator: std.mem.Allocator,
    request: Grpc.UnaryRequest,
    options: Grpc.CallOptions,
    commitment: *Channel.Commitment,
) !Grpc.UnaryResponse {
    const client = &channel.client_impl;
    const request_body = try frameUnaryRequestAlloc(allocator, request, client.options.limits.grpc);
    var call = ClientCall{ .allocator = allocator, .request_body = request_body, .limits = client.options.limits };
    defer call.deinit();
    defer commitment.* = call.commitment.snapshot();
    var owned_headers = try Grpc.requestHeadersAlloc(allocator, requestForTransport(client.options, request), client.options.limits.grpc);
    defer owned_headers.deinit();
    call.request_headers = try allocator.alloc(c.nghttp2_nv, owned_headers.headers.len);
    defer allocator.free(call.request_headers);
    for (owned_headers.headers, 0..) |header, index| call.request_headers[index] = nv(header.name, header.value);
    try channel.enqueueOperation(.{ .call = &call });
    const buffer = try allocator.alloc(u8, client.options.limits.max_wire_read_bytes);
    defer allocator.free(buffer);
    const deadline = std.Io.Clock.Timestamp.fromNow(client.io, .{
        .raw = .fromMilliseconds(@intCast(request.timeout_millis)),
        .clock = .awake,
    });
    while (!call.closed.load(.acquire)) {
        if (channel.failed()) {
            if (call.response_complete.load(.acquire)) break;
            return error.ChannelConnectionFailed;
        }
        if (channel.pump_owner.cmpxchgStrong(false, true, .acquire, .monotonic) == null) {
            if (call.closed.load(.acquire)) {
                channel.releasePump();
                break;
            }
            const result = channel.pumpOne(connection, buffer, deadline, options.cancellation);
            result catch |err| {
                if (err == error.CallCancelled or err == error.DeadlineExceeded) {
                    const cancel_result = cancelPersistentStream(connection, &call);
                    channel.releasePump();
                    try cancel_result;
                    return err;
                }
                channel.releasePump();
                if (call.response_complete.load(.acquire)) {
                    channel.markConnectionFailed();
                    break;
                }
                return err;
            };
            channel.releasePump();
        } else channel.waitForPump();
    }
    if (call.stream_error != c.NGHTTP2_NO_ERROR) return error.Http2StreamFailed;
    return unaryResponseFromCallAlloc(allocator, &call);
}

fn invokePersistentStreamingAlloc(channel: *PersistentChannel, connection: *ClientConnection, allocator: std.mem.Allocator, request: Grpc.StreamingRequest, options: Grpc.CallOptions) !Grpc.StreamingResponse {
    const client = &channel.client_impl;
    const request_body = try frameStreamingRequestAlloc(allocator, request, client.options.limits.grpc);
    var call = ClientCall{ .allocator = allocator, .request_body = request_body, .limits = client.options.limits };
    defer call.deinit();
    const header_request = Grpc.UnaryRequest{
        .authority = request.authority,
        .service = request.service,
        .method = request.method,
        .payload = "",
        .scheme = streamingRequestForTransport(client.options, request).scheme,
        .metadata = request.metadata,
        .timeout_millis = request.timeout_millis,
    };
    var owned_headers = try Grpc.requestHeadersAlloc(allocator, header_request, client.options.limits.grpc);
    defer owned_headers.deinit();
    call.request_headers = try allocator.alloc(c.nghttp2_nv, owned_headers.headers.len);
    defer allocator.free(call.request_headers);
    for (owned_headers.headers, 0..) |header, index| call.request_headers[index] = nv(header.name, header.value);
    try channel.enqueueOperation(.{ .call = &call });
    const buffer = try allocator.alloc(u8, client.options.limits.max_wire_read_bytes);
    defer allocator.free(buffer);
    const deadline = deadlineFromNow(client.io, request.timeout_millis);
    while (!call.closed.load(.acquire)) {
        if (channel.failed()) {
            if (call.response_complete.load(.acquire)) break;
            return error.ChannelConnectionFailed;
        }
        if (channel.pump_owner.cmpxchgStrong(false, true, .acquire, .monotonic) == null) {
            if (call.closed.load(.acquire)) {
                channel.releasePump();
                break;
            }
            const result = channel.pumpOne(connection, buffer, deadline, options.cancellation);
            result catch |err| {
                if (err == error.CallCancelled or err == error.DeadlineExceeded) {
                    const cancel_result = cancelPersistentStream(connection, &call);
                    channel.releasePump();
                    try cancel_result;
                    return err;
                }
                channel.releasePump();
                if (call.response_complete.load(.acquire)) {
                    channel.markConnectionFailed();
                    break;
                }
                return err;
            };
            channel.releasePump();
        } else channel.waitForPump();
    }
    if (call.stream_error != c.NGHTTP2_NO_ERROR) return error.Http2StreamFailed;
    return streamingResponseFromCallAlloc(allocator, &call);
}

fn cancelPersistentStream(connection: *ClientConnection, call: *ClientCall) !void {
    if (call.stream_id == 0 or call.closed.load(.acquire)) return;
    try checkNghttp(c.nghttp2_submit_rst_stream(connection.session, c.NGHTTP2_FLAG_NONE, call.stream_id, c.NGHTTP2_CANCEL));
    try flushSession(connection.session, connection.storage.wire());
    call.closed.store(true, .release);
}

pub const ChannelPoolOptions = struct {
    size: usize = 4,
    client: ClientOptions = .{},
};

pub const ChannelPool = struct {
    allocator: std.mem.Allocator,
    channels: []PersistentChannel,
    next: std.atomic.Value(usize),

    pub fn init(allocator: std.mem.Allocator, io: std.Io, options: ChannelPoolOptions) !ChannelPool {
        if (options.size == 0) return error.InvalidPoolSize;
        const channels = try allocator.alloc(PersistentChannel, options.size);
        var initialized: usize = 0;
        errdefer {
            for (channels[0..initialized]) |*channel| channel.deinit();
            allocator.free(channels);
        }
        for (channels) |*channel| {
            channel.* = try PersistentChannel.init(allocator, io, options.client);
            initialized += 1;
        }
        return .{ .allocator = allocator, .channels = channels, .next = std.atomic.Value(usize).init(0) };
    }

    pub fn deinit(self: *ChannelPool) void {
        for (self.channels) |*channel| channel.deinit();
        self.allocator.free(self.channels);
        self.* = undefined;
    }

    pub fn client(self: *ChannelPool) Grpc.Client {
        return .{ .ptr = self, .invoke_fn = invokeErased };
    }

    pub fn invokeAlloc(self: *ChannelPool, allocator: std.mem.Allocator, request: Grpc.UnaryRequest, options: Grpc.CallOptions) anyerror!Grpc.UnaryResponse {
        return self.pick().invokeAlloc(allocator, request, options);
    }

    pub fn streamingClient(self: *ChannelPool) Middleware.StreamingClient {
        return Middleware.StreamingClient.from(ChannelPool, self);
    }

    pub fn invokeStreamingAlloc(self: *ChannelPool, allocator: std.mem.Allocator, request: Grpc.StreamingRequest, options: Grpc.CallOptions) anyerror!Grpc.StreamingResponse {
        return self.pick().invokeStreamingAlloc(allocator, request, options);
    }

    pub fn openIncrementalStream(self: *ChannelPool, request: IncrementalOpenRequest, capacity: usize) !IncrementalClientStream {
        return self.pick().openIncrementalStream(request, capacity);
    }

    pub fn snapshot(self: *ChannelPool, allocator: std.mem.Allocator) ![]ChannelSnapshot {
        const snapshots = try allocator.alloc(ChannelSnapshot, self.channels.len);
        for (self.channels, snapshots) |*channel, *value| value.* = channel.snapshot();
        return snapshots;
    }

    fn pick(self: *ChannelPool) *PersistentChannel {
        const index = self.next.fetchAdd(1, .monotonic) % self.channels.len;
        return &self.channels[index];
    }

    fn invokeErased(pointer: *anyopaque, allocator: std.mem.Allocator, request: Grpc.UnaryRequest, options: Grpc.CallOptions) anyerror!Grpc.UnaryResponse {
        return (@as(*ChannelPool, @ptrCast(@alignCast(pointer)))).invokeAlloc(allocator, request, options);
    }
};

fn SmallByteBuffer(comptime inline_capacity: usize) type {
    return struct {
        items: []u8 = &.{},
        inline_storage: [inline_capacity]u8 = undefined,
        overflow: std.ArrayList(u8) = .empty,

        fn appendSlice(self: *@This(), allocator: std.mem.Allocator, bytes: []const u8) !void {
            if (bytes.len == 0) return;
            const new_len = std.math.add(usize, self.items.len, bytes.len) catch return error.OutOfMemory;
            if (self.overflow.capacity == 0 and new_len <= inline_capacity) {
                @memcpy(self.inline_storage[self.items.len..new_len], bytes);
                self.items = self.inline_storage[0..new_len];
                return;
            }
            if (self.overflow.capacity == 0) {
                try self.overflow.ensureTotalCapacityPrecise(allocator, new_len);
                self.overflow.appendSliceAssumeCapacity(self.items);
            }
            try self.overflow.appendSlice(allocator, bytes);
            self.items = self.overflow.items;
        }

        fn deinit(self: *@This(), allocator: std.mem.Allocator) void {
            self.overflow.deinit(allocator);
            self.* = undefined;
        }
    };
}

test "small request header values stay allocation free" {
    var failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    var value: SmallByteBuffer(64) = .{};
    defer value.deinit(failing.allocator());
    try value.appendSlice(failing.allocator(), "application/grpc");
    try std.testing.expectEqualStrings("application/grpc", value.items);
}

test "request header values preserve bytes after bounded overflow" {
    var value: SmallByteBuffer(8) = .{};
    defer value.deinit(std.testing.allocator);
    try value.appendSlice(std.testing.allocator, "application/");
    try value.appendSlice(std.testing.allocator, "grpc");
    try std.testing.expectEqualStrings("application/grpc", value.items);
}

const ServerStream = struct {
    allocator: std.mem.Allocator,
    stream_id: i32,
    grpc_limits: Grpc.Limits = .{},
    path: SmallByteBuffer(128) = .{},
    authority: SmallByteBuffer(64) = .{},
    method: SmallByteBuffer(8) = .{},
    scheme: SmallByteBuffer(8) = .{},
    te: SmallByteBuffer(16) = .{},
    content_type: SmallByteBuffer(64) = .{},
    accept_encoding: SmallByteBuffer(64) = .{},
    origin: SmallByteBuffer(64) = .{},
    protocol_version: SmallByteBuffer(8) = .{},
    authorization: SmallByteBuffer(64) = .{},
    iap_jwt: SmallByteBuffer(64) = .{},
    traceparent: SmallByteBuffer(64) = .{},
    tracestate: SmallByteBuffer(64) = .{},
    baggage: SmallByteBuffer(64) = .{},
    request_id: SmallByteBuffer(64) = .{},
    body: std.ArrayList(u8) = .empty,
    body_capacity_reserved: bool = false,
    request_headers: std.ArrayList(OwnedHeader) = .empty,
    header_count: usize = 0,
    header_bytes: usize = 0,
    response_frame: ?[]u8 = null,
    response_offset: usize = 0,
    response_status: Grpc.Code = .ok,
    response_trailers: ?Grpc.HeaderBlock = null,
    request_compression: Grpc.Compression = .identity,
    unsupported_request_compression: bool = false,
    response_compression: Grpc.Compression = .identity,
    timeout_millis: u64 = 30_000,
    response_started: bool = false,
    incremental_decoder: ?Grpc.MessageDecoder = null,
    incremental_runtime: ?*IncrementalRuntime = null,
    incremental_pending_message: ?Incremental.OwnedMessage = null,
    incremental_frame_ready: bool = false,
    incremental_frame_final: bool = false,
    incremental_provider_active: bool = false,
    incremental_headers_submitted: bool = false,
    unary_connection: ?*ServerConnection = null,
    unary_job_scheduled: bool = false,
    unary_job_complete: std.atomic.Value(bool) = .init(false),
    unary_job_finished: std.Io.Event = .unset,
    unary_response: ?Grpc.UnaryResponse = null,
    unary_error: ?anyerror = null,
    peer_closed: bool = false,

    fn deinit(self: *ServerStream) void {
        // The handler thread borrows route/authority slices and middleware
        // context from this stream. Stop and join it before releasing any of
        // that storage; cancellation can otherwise race the next HTTP/2 stream
        // and corrupt the shared allocator.
        if (self.incremental_runtime) |runtime| {
            runtime.destroy();
            self.incremental_runtime = null;
        }
        if (self.unary_job_scheduled) self.unary_job_finished.waitUncancelable(self.unary_connection.?.io);
        if (self.unary_response) |*response| response.deinit();
        self.path.deinit(self.allocator);
        self.authority.deinit(self.allocator);
        self.method.deinit(self.allocator);
        self.scheme.deinit(self.allocator);
        self.te.deinit(self.allocator);
        self.content_type.deinit(self.allocator);
        self.accept_encoding.deinit(self.allocator);
        self.origin.deinit(self.allocator);
        self.protocol_version.deinit(self.allocator);
        self.authorization.deinit(self.allocator);
        self.iap_jwt.deinit(self.allocator);
        self.traceparent.deinit(self.allocator);
        self.tracestate.deinit(self.allocator);
        self.baggage.deinit(self.allocator);
        self.request_id.deinit(self.allocator);
        self.body.deinit(self.allocator);
        for (self.request_headers.items) |*header| header.deinit(self.allocator);
        self.request_headers.deinit(self.allocator);
        if (self.incremental_decoder) |*decoder| decoder.deinit();
        if (self.incremental_pending_message) |*message| message.deinit();
        if (self.response_frame) |frame| self.allocator.free(frame);
        if (self.response_trailers) |*trailers| trailers.deinit();
        self.allocator.destroy(self);
    }

    fn observeRequestHeader(self: *ServerStream, limits: Limits, name: []const u8, value: []const u8) !void {
        if (self.header_count >= limits.max_header_count) return error.MetadataTooLarge;
        const added = std.math.add(usize, name.len, value.len) catch return error.MetadataTooLarge;
        const total = std.math.add(usize, self.header_bytes, added) catch return error.MetadataTooLarge;
        if (total > limits.max_header_bytes) return error.MetadataTooLarge;
        self.header_count += 1;
        self.header_bytes = total;
    }

    fn addApplicationRequestHeader(self: *ServerStream, name: []const u8, value: []const u8) !void {
        if (!Grpc.isApplicationMetadataName(name)) return;
        const owned_name = try self.allocator.dupe(u8, name);
        errdefer self.allocator.free(owned_name);
        const owned_value = try self.allocator.dupe(u8, value);
        errdefer self.allocator.free(owned_value);
        try self.request_headers.append(self.allocator, .{ .name = owned_name, .value = owned_value });
    }

    fn reserveDeclaredMessageBody(self: *ServerStream, limits: Grpc.Limits) !void {
        if (self.body_capacity_reserved or self.body.items.len < 5) return;
        if (self.body.items[0] > 1) return error.InvalidCompressedFlag;
        const message_len: usize = std.mem.readInt(u32, self.body.items[1..5], .big);
        if (message_len > limits.max_message_bytes) return error.MessageTooLarge;
        const framed_len = std.math.add(usize, message_len, 5) catch return error.MessageTooLarge;
        if (framed_len > limits.max_buffered_message_bytes) return error.MessageTooLarge;
        try self.body.ensureTotalCapacityPrecise(self.allocator, framed_len);
        self.body_capacity_reserved = true;
    }

    fn runUnary(pointer: *anyopaque) void {
        const self: *ServerStream = @ptrCast(@alignCast(pointer));
        const connection = self.unary_connection.?;
        if (invokeUnaryResponseAlloc(connection, self)) |response| {
            self.unary_response = response;
        } else |err| {
            self.unary_error = err;
        }
        self.unary_job_complete.store(true, .release);
        self.unary_job_finished.set(connection.io);
        _ = connection.notifications.put(connection.io, &.{self.stream_id}, 0) catch {};
        connection.wakeup.signal();
    }
};

fn requestMetadataAlloc(stream: *const ServerStream, limits: Grpc.Limits) !Grpc.MetadataBlock {
    var dedicated_count: usize = 0;
    if (stream.authorization.items.len != 0) dedicated_count += 1;
    if (stream.iap_jwt.items.len != 0) dedicated_count += 1;
    if (stream.traceparent.items.len != 0) dedicated_count += 1;
    if (stream.tracestate.items.len != 0) dedicated_count += 1;
    if (stream.baggage.items.len != 0) dedicated_count += 1;
    if (stream.request_id.items.len != 0) dedicated_count += 1;
    const headers = try stream.allocator.alloc(Grpc.Header, stream.request_headers.items.len + dedicated_count);
    defer stream.allocator.free(headers);
    for (stream.request_headers.items, 0..) |header, index| headers[index] = header.borrowed();
    var index = stream.request_headers.items.len;
    if (stream.authorization.items.len != 0) {
        headers[index] = .{ .name = "authorization", .value = stream.authorization.items };
        index += 1;
    }
    if (stream.iap_jwt.items.len != 0) {
        headers[index] = .{ .name = "x-goog-iap-jwt-assertion", .value = stream.iap_jwt.items };
        index += 1;
    }
    if (stream.traceparent.items.len != 0) {
        headers[index] = .{ .name = "traceparent", .value = stream.traceparent.items };
        index += 1;
    }
    if (stream.tracestate.items.len != 0) {
        headers[index] = .{ .name = "tracestate", .value = stream.tracestate.items };
        index += 1;
    }
    if (stream.baggage.items.len != 0) {
        headers[index] = .{ .name = "baggage", .value = stream.baggage.items };
        index += 1;
    }
    if (stream.request_id.items.len != 0) headers[index] = .{ .name = "x-request-id", .value = stream.request_id.items };
    return Grpc.metadataFromHeadersAlloc(stream.allocator, headers, limits);
}

fn setResponseTrailers(stream: *ServerStream, status: Grpc.Status, metadata: []const Grpc.Metadata, limits: Grpc.Limits) !void {
    return setResponseTrailersFull(stream, status, metadata, null, limits);
}

fn setResponseTrailersFull(stream: *ServerStream, status: Grpc.Status, metadata: []const Grpc.Metadata, retry_pushback_millis: ?i64, limits: Grpc.Limits) !void {
    if (stream.response_trailers) |*existing| existing.deinit();
    stream.response_trailers = null;
    stream.response_status = status.code;
    if (status.code == .ok and status.message.len == 0 and status.details_bin.len == 0 and metadata.len == 0 and retry_pushback_millis == null) return;
    stream.response_trailers = try Grpc.statusTrailersWithPushbackAlloc(stream.allocator, status, metadata, retry_pushback_millis, limits);
}

fn submitTrailerBlock(session: *c.nghttp2_session, stream_id: i32, allocator: std.mem.Allocator, block: Grpc.HeaderBlock) c_int {
    const trailers = allocator.alloc(c.nghttp2_nv, block.headers.len) catch return c.NGHTTP2_ERR_CALLBACK_FAILURE;
    defer allocator.free(trailers);
    for (block.headers, 0..) |header, index| trailers[index] = nv(header.name, header.value);
    return c.nghttp2_submit_trailer(session, stream_id, trailers.ptr, trailers.len);
}

const HandlerJob = struct {
    pointer: *anyopaque,
    run_fn: *const fn (*anyopaque) void,
};

/// A fixed-size executor for blocking incremental handlers. The synchronous
/// handler API needs a schedulable context while it waits on bounded pipes,
/// but creating and destroying an OS thread for every RPC is both expensive
/// and unbounded. This executor caps resident stacks and queues excess work so
/// admission pressure propagates back to the HTTP/2 connection.
const HandlerExecutor = struct {
    allocator: std.mem.Allocator,
    io: std.Io,
    storage: []HandlerJob,
    queue: std.Io.Queue(HandlerJob),
    threads: []std.Thread,

    fn create(allocator: std.mem.Allocator, io: std.Io, worker_count: usize, queue_capacity: usize, stack_bytes: usize) !*HandlerExecutor {
        if (worker_count == 0 or queue_capacity == 0 or stack_bytes < 128 * 1024) return error.InvalidLimits;
        const self = try allocator.create(HandlerExecutor);
        errdefer allocator.destroy(self);
        const storage = try allocator.alloc(HandlerJob, queue_capacity);
        errdefer allocator.free(storage);
        const threads = try allocator.alloc(std.Thread, worker_count);
        errdefer allocator.free(threads);
        self.* = .{
            .allocator = allocator,
            .io = io,
            .storage = storage,
            .queue = std.Io.Queue(HandlerJob).init(storage),
            .threads = threads,
        };
        var spawned: usize = 0;
        errdefer {
            self.queue.close(io);
            for (threads[0..spawned]) |thread| thread.join();
        }
        for (threads) |*thread| {
            thread.* = try std.Thread.spawn(.{ .stack_size = stack_bytes }, worker, .{self});
            spawned += 1;
        }
        return self;
    }

    fn destroy(self: *HandlerExecutor) void {
        self.queue.close(self.io);
        for (self.threads) |thread| thread.join();
        self.allocator.free(self.threads);
        self.allocator.free(self.storage);
        const allocator = self.allocator;
        allocator.destroy(self);
    }

    fn schedule(self: *HandlerExecutor, job: HandlerJob) !void {
        try self.queue.putOne(self.io, job);
    }

    fn worker(self: *HandlerExecutor) void {
        while (true) {
            const job = self.queue.getOne(self.io) catch |err| switch (err) {
                error.Closed => return,
                else => return,
            };
            job.run_fn(job.pointer);
        }
    }

    fn workerCount(self: *const HandlerExecutor) usize {
        return self.threads.len;
    }
};

const IncrementalRuntime = struct {
    allocator: std.mem.Allocator,
    io: std.Io,
    handler: Incremental.Handler,
    inbound: Incremental.Pipe,
    outbound: Incremental.Pipe,
    notifications: *std.Io.Queue(i32),
    wakeup: *NotificationWakeup,
    stream_id: i32,
    call: Incremental.Call,
    handler_finished: std.Io.Event = .unset,
    done: std.atomic.Value(bool) = .init(false),
    status_code: std.atomic.Value(u8) = .init(@intFromEnum(Grpc.Code.unknown)),
    status_message: []u8 = &.{},
    status_details: []u8 = &.{},
    owns_status: bool = false,
    provided_status_code: ?Grpc.Code = null,
    request_messages: std.atomic.Value(usize) = .init(0),
    response_messages: std.atomic.Value(usize) = .init(0),
    middleware: MiddlewareRun,
    connection: *ServerConnection,
    trailers_submitted: bool = false,
    lookahead: ?Incremental.OwnedMessage = null,
    request_metadata: Grpc.MetadataBlock,
    metadata_mutex: std.atomic.Mutex = .unlocked,
    initial_metadata: ?Grpc.MetadataBlock = null,
    trailing_metadata: ?Grpc.MetadataBlock = null,
    headers_ready: std.atomic.Value(bool) = .init(false),
    headers_submitted: std.atomic.Value(bool) = .init(false),
    forced_code: std.atomic.Value(u8) = .init(255),
    deadline: std.Io.Clock.Timestamp,

    fn create(
        connection: *ServerConnection,
        stream: *ServerStream,
        route: anytype,
        shape: Grpc.CallShape,
        handler: Incremental.Handler,
        middleware: MiddlewareRun,
    ) !*IncrementalRuntime {
        const self = try connection.allocator.create(IncrementalRuntime);
        errdefer connection.allocator.destroy(self);
        var inbound = try Incremental.Pipe.init(connection.allocator, connection.io, connection.stream_queue_capacity);
        errdefer inbound.deinit();
        var outbound = try Incremental.Pipe.init(connection.allocator, connection.io, connection.stream_queue_capacity);
        errdefer outbound.deinit();
        var request_metadata = try requestMetadataAlloc(stream, connection.limits.grpc);
        errdefer request_metadata.deinit();
        self.* = .{
            .allocator = connection.allocator,
            .io = connection.io,
            .handler = handler,
            .inbound = inbound,
            .outbound = outbound,
            .notifications = &connection.notifications,
            .wakeup = &connection.wakeup,
            .stream_id = stream.stream_id,
            .call = undefined,
            .middleware = middleware,
            .connection = connection,
            .request_metadata = request_metadata,
            .deadline = deadlineFromNow(connection.io, stream.timeout_millis),
        };
        self.call = .{
            .context = .{
                .authority = stream.authority.items,
                .scheme = stream.scheme.items,
                .service = route.service,
                .method = route.method,
                .shape = shape,
                .timeout_millis = stream.timeout_millis,
                .metadata = self.request_metadata.entries,
            },
            .inbound = &self.inbound,
            .outbound = &self.outbound,
            .notify_pointer = self,
            .notify_fn = notifyErased,
            .metadata_pointer = self,
            .set_initial_metadata_fn = setInitialMetadataErased,
            .set_trailing_metadata_fn = setTrailingMetadataErased,
            .set_final_status_fn = setFinalStatusErased,
        };
        const executor = connection.handler_executor orelse return error.HandlerExecutorMissing;
        try executor.schedule(.{ .pointer = self, .run_fn = runScheduled });
        return self;
    }

    fn destroy(self: *IncrementalRuntime) void {
        self.inbound.close();
        self.outbound.close();
        self.handler_finished.waitUncancelable(self.io);
        self.inbound.deinit();
        self.outbound.deinit();
        if (self.lookahead) |*message| message.deinit();
        self.request_metadata.deinit();
        if (self.initial_metadata) |*metadata| metadata.deinit();
        if (self.trailing_metadata) |*metadata| metadata.deinit();
        if (self.owns_status) {
            self.allocator.free(self.status_message);
            self.allocator.free(self.status_details);
        }
        const allocator = self.allocator;
        allocator.destroy(self);
    }

    fn run(self: *IncrementalRuntime) void {
        const handler_status = self.handler.run_fn(self.handler.pointer, &self.call) catch Grpc.Status{
            .code = .internal,
            .message = "incremental handler failed",
        };
        const forced_status = self.forcedStatus();
        const provided_status: ?Grpc.Status = if (self.provided_status_code) |code| .{
            .code = code,
            .message = self.status_message,
            .details_bin = self.status_details,
        } else null;
        const final_status = forced_status orelse provided_status orelse handler_status;
        if (forced_status == null and provided_status == null) {
            const message = self.allocator.dupe(u8, final_status.message) catch null;
            const details = self.allocator.dupe(u8, final_status.details_bin) catch null;
            if (message != null and details != null) {
                self.status_message = message.?;
                self.status_details = details.?;
                self.owns_status = true;
            } else {
                if (message) |owned| self.allocator.free(owned);
                if (details) |owned| self.allocator.free(owned);
            }
        }
        self.status_code.store(@intFromEnum(final_status.code), .release);
        self.outbound.close();
        self.done.store(true, .release);
        finishMiddleware(
            self.connection,
            &self.middleware,
            final_status.code,
            self.request_messages.load(.acquire),
            self.response_messages.load(.acquire),
        );
        self.notify();
    }

    fn runScheduled(pointer: *anyopaque) void {
        const self: *IncrementalRuntime = @ptrCast(@alignCast(pointer));
        self.run();
        self.handler_finished.set(self.io);
    }

    fn notifyErased(pointer: *anyopaque) void {
        (@as(*IncrementalRuntime, @ptrCast(@alignCast(pointer)))).notify();
    }

    fn setInitialMetadataErased(pointer: *anyopaque, metadata: []const Grpc.Metadata) !void {
        const self: *IncrementalRuntime = @ptrCast(@alignCast(pointer));
        if (self.headers_submitted.load(.acquire)) return error.ResponseHeadersAlreadyCommitted;
        self.lockMetadata();
        defer self.metadata_mutex.unlock();
        if (self.headers_submitted.load(.acquire)) return error.ResponseHeadersAlreadyCommitted;
        if (self.initial_metadata != null) return error.ResponseHeadersAlreadySet;
        self.initial_metadata = try cloneMetadataBlockAlloc(self.allocator, metadata, self.connection.limits.grpc);
        self.headers_ready.store(true, .release);
    }

    fn setTrailingMetadataErased(pointer: *anyopaque, metadata: []const Grpc.Metadata) !void {
        const self: *IncrementalRuntime = @ptrCast(@alignCast(pointer));
        if (self.done.load(.acquire)) return error.ResponseAlreadyCompleted;
        self.lockMetadata();
        defer self.metadata_mutex.unlock();
        if (self.done.load(.acquire)) return error.ResponseAlreadyCompleted;
        if (self.trailing_metadata != null) return error.ResponseTrailersAlreadySet;
        self.trailing_metadata = try cloneMetadataBlockAlloc(self.allocator, metadata, self.connection.limits.grpc);
    }

    fn setFinalStatusErased(pointer: *anyopaque, final_status: Grpc.Status) !void {
        const self: *IncrementalRuntime = @ptrCast(@alignCast(pointer));
        if (self.done.load(.acquire)) return error.ResponseAlreadyCompleted;
        self.lockMetadata();
        defer self.metadata_mutex.unlock();
        if (self.done.load(.acquire)) return error.ResponseAlreadyCompleted;
        if (self.provided_status_code != null) return error.ResponseStatusAlreadySet;
        const message = try self.allocator.dupe(u8, final_status.message);
        errdefer self.allocator.free(message);
        const details = try self.allocator.dupe(u8, final_status.details_bin);
        self.status_message = message;
        self.status_details = details;
        self.owns_status = true;
        self.provided_status_code = final_status.code;
    }

    fn lockMetadata(self: *IncrementalRuntime) void {
        while (!self.metadata_mutex.tryLock()) std.Thread.yield() catch {};
    }

    fn notify(self: *IncrementalRuntime) void {
        _ = self.notifications.put(self.io, &.{self.stream_id}, 0) catch {};
        self.wakeup.signal();
    }

    fn status(self: *IncrementalRuntime) Grpc.Status {
        if (self.forcedStatus()) |forced_status| return forced_status;
        return .{
            .code = @enumFromInt(self.status_code.load(.acquire)),
            .message = self.status_message,
            .details_bin = self.status_details,
        };
    }

    fn forceStatus(self: *IncrementalRuntime, code: Grpc.Code) void {
        if (self.forced_code.cmpxchgStrong(255, @intFromEnum(code), .acq_rel, .acquire) != null) return;
        self.status_code.store(@intFromEnum(code), .release);
        self.inbound.close();
        self.outbound.close();
        self.done.store(true, .release);
        self.notify();
    }

    fn forcedStatus(self: *const IncrementalRuntime) ?Grpc.Status {
        const raw = self.forced_code.load(.acquire);
        if (raw == 255) return null;
        const code: Grpc.Code = @enumFromInt(raw);
        return .{ .code = code, .message = switch (code) {
            .deadline_exceeded => "deadline exceeded",
            .cancelled => "call cancelled",
            else => "call terminated",
        } };
    }
};

fn cloneMetadataBlockAlloc(allocator: std.mem.Allocator, metadata: []const Grpc.Metadata, limits: Grpc.Limits) !Grpc.MetadataBlock {
    var headers = try Grpc.metadataHeadersAlloc(allocator, metadata, limits);
    defer headers.deinit();
    return Grpc.metadataFromHeadersAlloc(allocator, headers.headers, limits);
}

pub const PeerKeepalivePolicy = struct {
    minimum_interval_millis: u64 = 5 * 60 * 1000,
    permit_without_calls: bool = false,
    maximum_strikes: u8 = 2,

    pub fn validate(self: PeerKeepalivePolicy) !void {
        if (self.minimum_interval_millis == 0 or self.maximum_strikes == 0) return error.InvalidKeepalivePolicy;
    }
};

/// Selects which RPC protocol families a native HTTP/2 listener accepts.
/// `.all` preserves the default mixed gRPC/Connect endpoint. Dedicated
/// Connect and gRPC listeners can use the narrower modes to return canonical
/// HTTP errors for requests that do not belong to the configured protocol.
pub const ServerProtocolPolicy = enum {
    all,
    grpc_only,
    connect_only,
};

pub const PeerPingDecision = enum { accept, strike, close };

pub const PeerKeepaliveGuard = struct {
    policy: PeerKeepalivePolicy,
    last_ping_millis: ?u64 = null,
    strikes: u8 = 0,

    pub fn init(policy: PeerKeepalivePolicy) PeerKeepaliveGuard {
        return .{ .policy = policy };
    }

    pub fn observe(self: *PeerKeepaliveGuard, now_millis: u64, has_calls: bool) PeerPingDecision {
        const too_soon = if (self.last_ping_millis) |previous|
            now_millis < previous or now_millis - previous < self.policy.minimum_interval_millis
        else
            false;
        self.last_ping_millis = now_millis;
        if ((!has_calls and !self.policy.permit_without_calls) or too_soon) {
            self.strikes +|= 1;
            return if (self.strikes > self.policy.maximum_strikes) .close else .strike;
        }
        self.strikes = 0;
        return .accept;
    }

    /// gRPC keepalive enforcement counts pings since the last DATA frame.
    /// Application traffic therefore resets the abuse window, including the
    /// BDP probes used by grpc-go and grpcio during active streams.
    pub fn observeData(self: *PeerKeepaliveGuard) void {
        self.last_ping_millis = null;
        self.strikes = 0;
    }
};

pub const ServerCallCounters = struct {
    started: std.atomic.Value(u64) = .init(0),
    succeeded: std.atomic.Value(u64) = .init(0),
    failed: std.atomic.Value(u64) = .init(0),

    fn begin(self: *ServerCallCounters) void {
        _ = self.started.fetchAdd(1, .monotonic);
    }

    fn finish(self: *ServerCallCounters, code: Grpc.Code) void {
        if (code == .ok) {
            _ = self.succeeded.fetchAdd(1, .monotonic);
        } else {
            _ = self.failed.fetchAdd(1, .monotonic);
        }
    }
};

const ServerConnection = struct {
    allocator: std.mem.Allocator,
    io: std.Io,
    registry: *Grpc.Registry,
    streaming_registry: ?*Grpc.StreamingRegistry,
    incremental_registry: ?*Incremental.Registry,
    limits: Limits,
    response_compression: Grpc.Compression,
    cors: Connect.CorsPolicy,
    interceptors: []const Middleware.Interceptor,
    streams: std.ArrayList(*ServerStream) = .empty,
    notification_storage: []i32,
    notifications: std.Io.Queue(i32),
    wakeup: NotificationWakeup,
    pending_wire: std.ArrayList(u8) = .empty,
    parser_paused: bool = false,
    stream_queue_capacity: usize,
    max_concurrent_streams: usize,
    callback_error: ?anyerror = null,
    completed_calls: usize = 0,
    peer_keepalive: PeerKeepaliveGuard,
    protocol_policy: ServerProtocolPolicy,
    handler_executor: ?*HandlerExecutor = null,
    close_after_flush: bool = false,
    call_counters: ?*ServerCallCounters = null,
    causal: ?*Middleware.CausalFacts = null,

    fn init(allocator: std.mem.Allocator, io: std.Io, registry: *Grpc.Registry, streaming_registry: ?*Grpc.StreamingRegistry, incremental_registry: ?*Incremental.Registry, limits: Limits, response_compression: Grpc.Compression, cors: Connect.CorsPolicy, interceptors: []const Middleware.Interceptor, stream_queue_capacity: usize, max_concurrent_streams: usize, peer_keepalive: PeerKeepalivePolicy, protocol_policy: ServerProtocolPolicy) !ServerConnection {
        const notification_storage = try allocator.alloc(i32, stream_queue_capacity * 2);
        errdefer allocator.free(notification_storage);
        var streams = try std.ArrayList(*ServerStream).initCapacity(allocator, max_concurrent_streams);
        errdefer streams.deinit(allocator);
        var wakeup = try NotificationWakeup.init();
        errdefer wakeup.deinit();
        return .{
            .allocator = allocator,
            .io = io,
            .registry = registry,
            .streaming_registry = streaming_registry,
            .incremental_registry = incremental_registry,
            .limits = limits,
            .response_compression = response_compression,
            .cors = cors,
            .interceptors = interceptors,
            .streams = streams,
            .notification_storage = notification_storage,
            .notifications = std.Io.Queue(i32).init(notification_storage),
            .wakeup = wakeup,
            .stream_queue_capacity = stream_queue_capacity,
            .max_concurrent_streams = max_concurrent_streams,
            .peer_keepalive = PeerKeepaliveGuard.init(peer_keepalive),
            .protocol_policy = protocol_policy,
        };
    }

    fn deinit(self: *ServerConnection) void {
        self.notifications.close(self.io);
        for (self.streams.items) |active_stream| active_stream.deinit();
        self.streams.deinit(self.allocator);
        self.pending_wire.deinit(self.allocator);
        self.wakeup.deinit();
        self.allocator.free(self.notification_storage);
    }

    fn stream(self: *ServerConnection, stream_id: i32) !*ServerStream {
        if (self.findStream(stream_id)) |existing| return existing;
        if (self.streams.items.len >= self.max_concurrent_streams) return error.ConnectionCapacityExceeded;
        const created = try self.allocator.create(ServerStream);
        errdefer self.allocator.destroy(created);
        created.* = .{ .allocator = self.allocator, .stream_id = stream_id, .grpc_limits = self.limits.grpc };
        self.streams.appendAssumeCapacity(created);
        return created;
    }

    fn callbackStream(self: *ServerConnection, session: *c.nghttp2_session, stream_id: i32, create: bool) !*ServerStream {
        if (c.nghttp2_session_get_stream_user_data(session, stream_id)) |raw| {
            return @ptrCast(@alignCast(raw));
        }
        if (!create) return error.ServerStreamMissing;
        const existing = self.findStream(stream_id);
        const stream_value = if (existing) |active| active else try self.stream(stream_id);
        if (c.nghttp2_session_set_stream_user_data(session, stream_id, stream_value) < 0) {
            if (existing == null) _ = self.removeStream(stream_id);
            return error.Http2StreamUserDataFailed;
        }
        return stream_value;
    }

    fn findStream(self: *ServerConnection, stream_id: i32) ?*ServerStream {
        for (self.streams.items) |active_stream| if (active_stream.stream_id == stream_id) return active_stream;
        return null;
    }

    fn removeStream(self: *ServerConnection, stream_id: i32) bool {
        for (self.streams.items, 0..) |active_stream, index| {
            if (active_stream.stream_id != stream_id) continue;
            self.streams.swapRemove(index).deinit();
            self.completed_calls += 1;
            return true;
        }
        return false;
    }

    fn hasIncrementalStreams(self: *const ServerConnection) bool {
        for (self.streams.items) |active_stream| if (active_stream.incremental_runtime != null) return true;
        return false;
    }

    fn hasUnaryJobs(self: *const ServerConnection) bool {
        for (self.streams.items) |active_stream| if (active_stream.unary_job_scheduled) return true;
        return false;
    }

    fn hasAsyncWork(self: *const ServerConnection) bool {
        return self.hasIncrementalStreams() or self.hasUnaryJobs();
    }
};

test "closed server streams do not grow connection storage" {
    var registry = Grpc.Registry.init(std.testing.allocator);
    defer registry.deinit();
    var connection = try ServerConnection.init(
        std.testing.allocator,
        std.testing.io,
        &registry,
        null,
        null,
        .{},
        .identity,
        .{},
        &.{},
        1,
        2,
        .{},
        .all,
    );
    defer connection.deinit();

    for (0..20_000) |index| {
        const stream_id: i32 = @intCast(index * 2 + 1);
        _ = try connection.stream(stream_id);
        if (!connection.removeStream(stream_id)) return error.StreamRemovalFailed;
    }

    if (connection.streams.items.len != 0) return error.ClosedStreamRetained;
    if (connection.streams.capacity > 16) return error.StreamStorageNotBounded;
    _ = try connection.stream(40_001);
    _ = try connection.stream(40_003);
    _ = connection.stream(40_005) catch |err| switch (err) {
        error.ConnectionCapacityExceeded => return,
        else => return err,
    };
    return error.ConcurrentStreamLimitNotEnforced;
}

test "server callbacks use nghttp2 stream user data for constant time lookup" {
    try std.testing.expect(@hasDecl(ServerConnection, "callbackStream"));
}

test "server retains application metadata without duplicating reserved headers" {
    const stream = try std.testing.allocator.create(ServerStream);
    stream.* = .{ .allocator = std.testing.allocator, .stream_id = 1 };
    defer stream.deinit();
    try stream.observeRequestHeader(.{}, ":path", "/example.v1.Echo/Say");
    try stream.observeRequestHeader(.{}, "x-tenant", "blue");
    try stream.addApplicationRequestHeader("x-tenant", "blue");
    try std.testing.expectEqual(@as(usize, 2), stream.header_count);
    try std.testing.expectEqual(@as(usize, 1), stream.request_headers.items.len);
    try std.testing.expectEqualStrings("x-tenant", stream.request_headers.items[0].name);
}

test "common OK response trailers stay on the allocation free path" {
    const stream = try std.testing.allocator.create(ServerStream);
    stream.* = .{ .allocator = std.testing.allocator, .stream_id = 1 };
    defer stream.deinit();
    try setResponseTrailers(stream, .ok(), &.{}, .{});
    try std.testing.expect(stream.response_trailers == null);
    try std.testing.expectEqual(Grpc.Code.ok, stream.response_status);
}

test "server request body reserves the bounded declared gRPC frame size" {
    const stream = try std.testing.allocator.create(ServerStream);
    stream.* = .{ .allocator = std.testing.allocator, .stream_id = 1 };
    defer stream.deinit();
    try stream.body.appendSlice(std.testing.allocator, &.{ 0, 0, 1, 0, 0 });
    try stream.reserveDeclaredMessageBody(.{});
    try std.testing.expect(stream.body.capacity >= 65_541);
    try std.testing.expect(stream.body_capacity_reserved);
}

test "server advertises and enforces a bounded concurrent stream limit" {
    try std.testing.expect(@hasField(ServerOptions, "max_concurrent_streams"));
}

test "server peer keepalive guard rejects excessive idle pings deterministically" {
    var guard = PeerKeepaliveGuard.init(.{
        .minimum_interval_millis = 1_000,
        .permit_without_calls = false,
        .maximum_strikes = 2,
    });
    try std.testing.expectEqual(PeerPingDecision.accept, guard.observe(0, true));
    try std.testing.expectEqual(PeerPingDecision.strike, guard.observe(100, false));
    try std.testing.expectEqual(PeerPingDecision.strike, guard.observe(200, false));
    try std.testing.expectEqual(PeerPingDecision.close, guard.observe(300, false));
    guard.observeData();
    try std.testing.expectEqual(PeerPingDecision.accept, guard.observe(301, true));
}

test "native server validates mandatory gRPC HTTP2 request fields" {
    try validateGrpcRequestFields("POST", "http", "example.test", "/example.v1.Echo/Say", Grpc.content_type, "trailers");
    try validateGrpcRequestFields("POST", "https", "example.test", "/example.v1.Echo/Say", "application/grpc", "Trailers");
    try validateGrpcRequestFields("POST", "https", "example.test", "/example.v1.Echo/Say", "application/grpc+json; charset=utf-8", "trailers");
    try std.testing.expectError(error.InvalidHttpMethod, validateGrpcRequestFields("GET", "http", "example.test", "/example.v1.Echo/Say", Grpc.content_type, "trailers"));
    try std.testing.expectError(error.InvalidScheme, validateGrpcRequestFields("POST", "ftp", "example.test", "/example.v1.Echo/Say", Grpc.content_type, "trailers"));
    try std.testing.expectError(error.MissingAuthority, validateGrpcRequestFields("POST", "http", "", "/example.v1.Echo/Say", Grpc.content_type, "trailers"));
    try std.testing.expectError(error.InvalidContentType, validateGrpcRequestFields("POST", "http", "example.test", "/example.v1.Echo/Say", "application/json", "trailers"));
    try std.testing.expectError(error.InvalidContentType, validateGrpcRequestFields("POST", "http", "example.test", "/example.v1.Echo/Say", "application/grpc-web", "trailers"));
    try std.testing.expectError(error.MissingTrailersTe, validateGrpcRequestFields("POST", "http", "example.test", "/example.v1.Echo/Say", Grpc.content_type, ""));
}

fn serverOnHeader(
    maybe_session: ?*c.nghttp2_session,
    frame: [*c]const c.nghttp2_frame,
    name: [*c]const u8,
    name_len: usize,
    value: [*c]const u8,
    value_len: usize,
    _: u8,
    user_data: ?*anyopaque,
) callconv(.c) c_int {
    if (frame.*.hd.type != c.NGHTTP2_DATA and frame.*.hd.type != c.NGHTTP2_HEADERS) return 0;
    const connection: *ServerConnection = @ptrCast(@alignCast(user_data.?));
    const session = maybe_session orelse return c.NGHTTP2_ERR_CALLBACK_FAILURE;
    const stream = connection.callbackStream(session, frame.*.hd.stream_id, true) catch |err| {
        connection.callback_error = err;
        return c.NGHTTP2_ERR_CALLBACK_FAILURE;
    };
    const header_name = name[0..name_len];
    stream.observeRequestHeader(connection.limits, header_name, value[0..value_len]) catch |err| {
        connection.callback_error = err;
        return c.NGHTTP2_ERR_CALLBACK_FAILURE;
    };
    if (std.mem.eql(u8, header_name, ":path")) {
        stream.path.appendSlice(connection.allocator, value[0..value_len]) catch |err| {
            connection.callback_error = err;
            return c.NGHTTP2_ERR_CALLBACK_FAILURE;
        };
    } else if (std.mem.eql(u8, header_name, ":authority")) {
        stream.authority.appendSlice(connection.allocator, value[0..value_len]) catch |err| {
            connection.callback_error = err;
            return c.NGHTTP2_ERR_CALLBACK_FAILURE;
        };
    } else if (std.mem.eql(u8, header_name, ":method")) {
        stream.method.appendSlice(connection.allocator, value[0..value_len]) catch |err| {
            connection.callback_error = err;
            return c.NGHTTP2_ERR_CALLBACK_FAILURE;
        };
    } else if (std.mem.eql(u8, header_name, ":scheme")) {
        stream.scheme.appendSlice(connection.allocator, value[0..value_len]) catch |err| {
            connection.callback_error = err;
            return c.NGHTTP2_ERR_CALLBACK_FAILURE;
        };
    } else if (std.mem.eql(u8, header_name, "te")) {
        stream.te.appendSlice(connection.allocator, value[0..value_len]) catch |err| {
            connection.callback_error = err;
            return c.NGHTTP2_ERR_CALLBACK_FAILURE;
        };
    } else if (std.mem.eql(u8, header_name, "content-type")) {
        stream.content_type.appendSlice(connection.allocator, value[0..value_len]) catch |err| {
            connection.callback_error = err;
            return c.NGHTTP2_ERR_CALLBACK_FAILURE;
        };
    } else if (std.mem.eql(u8, header_name, "origin")) {
        stream.origin.appendSlice(connection.allocator, value[0..value_len]) catch |err| {
            connection.callback_error = err;
            return c.NGHTTP2_ERR_CALLBACK_FAILURE;
        };
    } else if (std.mem.eql(u8, header_name, "connect-protocol-version")) {
        stream.protocol_version.appendSlice(connection.allocator, value[0..value_len]) catch |err| {
            connection.callback_error = err;
            return c.NGHTTP2_ERR_CALLBACK_FAILURE;
        };
    } else if (std.mem.eql(u8, header_name, "connect-timeout-ms")) {
        stream.timeout_millis = std.fmt.parseInt(u64, value[0..value_len], 10) catch {
            connection.callback_error = error.InvalidDeadline;
            return c.NGHTTP2_ERR_CALLBACK_FAILURE;
        };
    } else if (std.mem.eql(u8, header_name, "grpc-timeout")) {
        const timeout = Grpc.Timeout.parse(value[0..value_len]) catch {
            connection.callback_error = error.InvalidDeadline;
            return c.NGHTTP2_ERR_CALLBACK_FAILURE;
        };
        stream.timeout_millis = timeout.toMillisecondsCeil() catch {
            connection.callback_error = error.InvalidDeadline;
            return c.NGHTTP2_ERR_CALLBACK_FAILURE;
        };
    } else if (std.mem.eql(u8, header_name, "authorization")) {
        stream.authorization.appendSlice(connection.allocator, value[0..value_len]) catch |err| {
            connection.callback_error = err;
            return c.NGHTTP2_ERR_CALLBACK_FAILURE;
        };
    } else if (std.mem.eql(u8, header_name, "x-goog-iap-jwt-assertion")) {
        if (value_len == 0 or value_len > 64 * 1024) {
            connection.callback_error = error.InvalidIapJwt;
            return c.NGHTTP2_ERR_CALLBACK_FAILURE;
        }
        stream.iap_jwt.appendSlice(connection.allocator, value[0..value_len]) catch |err| {
            connection.callback_error = err;
            return c.NGHTTP2_ERR_CALLBACK_FAILURE;
        };
    } else if (std.mem.eql(u8, header_name, "traceparent")) {
        if (!Middleware.validTraceparent(value[0..value_len])) {
            connection.callback_error = error.InvalidTraceContext;
            return c.NGHTTP2_ERR_CALLBACK_FAILURE;
        }
        stream.traceparent.appendSlice(connection.allocator, value[0..value_len]) catch |err| {
            connection.callback_error = err;
            return c.NGHTTP2_ERR_CALLBACK_FAILURE;
        };
    } else if (std.mem.eql(u8, header_name, "tracestate")) {
        if (!Middleware.validTracestate(value[0..value_len])) {
            connection.callback_error = error.InvalidTraceContext;
            return c.NGHTTP2_ERR_CALLBACK_FAILURE;
        }
        stream.tracestate.appendSlice(connection.allocator, value[0..value_len]) catch |err| {
            connection.callback_error = err;
            return c.NGHTTP2_ERR_CALLBACK_FAILURE;
        };
    } else if (std.mem.eql(u8, header_name, "baggage")) {
        if (!Middleware.validBaggage(value[0..value_len])) {
            connection.callback_error = error.InvalidTraceContext;
            return c.NGHTTP2_ERR_CALLBACK_FAILURE;
        }
        stream.baggage.appendSlice(connection.allocator, value[0..value_len]) catch |err| {
            connection.callback_error = err;
            return c.NGHTTP2_ERR_CALLBACK_FAILURE;
        };
    } else if (std.mem.eql(u8, header_name, "x-request-id")) {
        if (value_len > 128) {
            connection.callback_error = error.MetadataTooLarge;
            return c.NGHTTP2_ERR_CALLBACK_FAILURE;
        }
        stream.request_id.appendSlice(connection.allocator, value[0..value_len]) catch |err| {
            connection.callback_error = err;
            return c.NGHTTP2_ERR_CALLBACK_FAILURE;
        };
    } else if (std.mem.eql(u8, header_name, "grpc-encoding") or std.mem.eql(u8, header_name, "content-encoding") or std.mem.eql(u8, header_name, "connect-content-encoding")) {
        if (Grpc.Compression.parse(value[0..value_len])) |compression| {
            stream.request_compression = compression;
        } else {
            stream.unsupported_request_compression = true;
        }
    } else if (std.mem.eql(u8, header_name, "grpc-accept-encoding") or std.mem.eql(u8, header_name, "connect-accept-encoding")) {
        stream.accept_encoding.appendSlice(connection.allocator, value[0..value_len]) catch |err| {
            connection.callback_error = err;
            return c.NGHTTP2_ERR_CALLBACK_FAILURE;
        };
    } else {
        stream.addApplicationRequestHeader(header_name, value[0..value_len]) catch |err| {
            connection.callback_error = err;
            return c.NGHTTP2_ERR_CALLBACK_FAILURE;
        };
    }
    return 0;
}

fn serverOnData(
    maybe_session: ?*c.nghttp2_session,
    _: u8,
    stream_id: i32,
    data: [*c]const u8,
    length: usize,
    user_data: ?*anyopaque,
) callconv(.c) c_int {
    const connection: *ServerConnection = @ptrCast(@alignCast(user_data.?));
    connection.peer_keepalive.observeData();
    const session = maybe_session orelse return c.NGHTTP2_ERR_CALLBACK_FAILURE;
    const stream = connection.callbackStream(session, stream_id, false) catch |err| {
        connection.callback_error = err;
        return c.NGHTTP2_ERR_CALLBACK_FAILURE;
    };
    if (stream.incremental_runtime != null) {
        const decoder = if (stream.incremental_decoder) |*value| value else {
            connection.callback_error = error.IncrementalDecoderMissing;
            return c.NGHTTP2_ERR_CALLBACK_FAILURE;
        };
        decoder.push(data[0..length]) catch |err| {
            if (isConnectStreamingContentType(stream.content_type.items)) {
                stream.incremental_runtime.?.forceStatus(if (err == error.MessageTooLarge) .resource_exhausted else .internal);
                return 0;
            }
            connection.callback_error = err;
            return c.NGHTTP2_ERR_CALLBACK_FAILURE;
        };
        const ready = feedIncrementalInput(connection, stream) catch |err| {
            if (isConnectStreamingContentType(stream.content_type.items)) {
                stream.incremental_runtime.?.forceStatus(if (err == error.MessageTooLarge) .resource_exhausted else .internal);
                return 0;
            }
            connection.callback_error = err;
            return c.NGHTTP2_ERR_CALLBACK_FAILURE;
        };
        if (!ready) {
            connection.parser_paused = true;
            return c.NGHTTP2_ERR_PAUSE;
        }
        return 0;
    }
    const buffered = std.math.add(usize, stream.body.items.len, length) catch {
        connection.callback_error = error.MessageTooLarge;
        return c.NGHTTP2_ERR_CALLBACK_FAILURE;
    };
    if (buffered > connection.limits.grpc.max_buffered_message_bytes) {
        connection.callback_error = error.MessageTooLarge;
        return c.NGHTTP2_ERR_CALLBACK_FAILURE;
    }
    stream.body.appendSlice(connection.allocator, data[0..length]) catch |err| {
        connection.callback_error = err;
        return c.NGHTTP2_ERR_CALLBACK_FAILURE;
    };
    if (usesFramedRequestBody(stream.content_type.items)) {
        stream.reserveDeclaredMessageBody(connection.limits.grpc) catch |err| {
            connection.callback_error = err;
            return c.NGHTTP2_ERR_CALLBACK_FAILURE;
        };
    }
    return 0;
}

fn feedIncrementalInput(connection: *ServerConnection, stream: *ServerStream) !bool {
    const runtime = stream.incremental_runtime orelse return true;
    if (stream.incremental_pending_message) |message| {
        if (!try runtime.inbound.trySend(message)) return false;
        stream.incremental_pending_message = null;
        _ = runtime.request_messages.fetchAdd(1, .release);
    }
    const decoder = if (stream.incremental_decoder) |*value| value else return error.IncrementalDecoderMissing;
    while (decoder.pop()) |decoded_value| {
        var decoded = decoded_value;
        var message: Incremental.OwnedMessage = undefined;
        if (decoded.compressed) {
            if (stream.request_compression == .identity) {
                decoded.deinit(connection.allocator);
                return error.UnsupportedCompression;
            }
            const restored = Compression.decompressAlloc(connection.allocator, stream.request_compression, decoded.bytes, connection.limits.grpc.max_message_bytes) catch |err| {
                decoded.deinit(connection.allocator);
                return err;
            };
            decoded.deinit(connection.allocator);
            message = .{ .allocator = connection.allocator, .bytes = restored };
        } else message = .{ .allocator = connection.allocator, .bytes = decoded.bytes };
        if (!try runtime.inbound.trySend(message)) {
            stream.incremental_pending_message = message;
            return false;
        }
        _ = runtime.request_messages.fetchAdd(1, .release);
    }
    return true;
}

fn splitPath(path: []const u8) !struct { service: []const u8, method: []const u8 } {
    if (path.len < 4 or path[0] != '/') return error.InvalidGrpcPath;
    const separator = std.mem.indexOfScalar(u8, path[1..], '/') orelse return error.InvalidGrpcPath;
    const at = separator + 1;
    if (at == 1 or at + 1 >= path.len) return error.InvalidGrpcPath;
    return .{ .service = path[1..at], .method = path[at + 1 ..] };
}

fn validateGrpcRequestFields(method: []const u8, scheme: []const u8, authority: []const u8, path: []const u8, content_type_value: []const u8, te: []const u8) !void {
    if (!std.mem.eql(u8, method, "POST")) return error.InvalidHttpMethod;
    if (!std.mem.eql(u8, scheme, "http") and !std.mem.eql(u8, scheme, "https")) return error.InvalidScheme;
    if (authority.len == 0) return error.MissingAuthority;
    _ = try splitPath(path);
    if (!isGrpcContentType(content_type_value)) return error.InvalidContentType;
    if (!std.ascii.eqlIgnoreCase(te, "trailers")) return error.MissingTrailersTe;
}

fn isGrpcContentType(value: []const u8) bool {
    const media_type = std.mem.trim(u8, if (std.mem.indexOfScalar(u8, value, ';')) |separator| value[0..separator] else value, " \t");
    if (std.mem.eql(u8, media_type, "application/grpc")) return true;
    if (!std.mem.startsWith(u8, media_type, "application/grpc+")) return false;
    const suffix = media_type["application/grpc+".len..];
    return std.mem.eql(u8, suffix, "proto") or std.mem.eql(u8, suffix, "json");
}

fn validateGrpcRequest(stream: *const ServerStream) !void {
    return validateGrpcRequestFields(
        stream.method.items,
        stream.scheme.items,
        stream.authority.items,
        stream.path.items,
        stream.content_type.items,
        stream.te.items,
    );
}

fn isConnectStreamingContentType(value: []const u8) bool {
    const media_type = std.mem.trim(u8, if (std.mem.indexOfScalar(u8, value, ';')) |separator| value[0..separator] else value, " \t");
    return std.mem.eql(u8, media_type, Connect.streaming_proto_content_type);
}

fn usesFramedRequestBody(value: []const u8) bool {
    return isGrpcContentType(value) or isConnectStreamingContentType(value);
}

test "request body framing distinguishes raw Connect unary payloads" {
    try std.testing.expect(usesFramedRequestBody(Grpc.content_type));
    try std.testing.expect(usesFramedRequestBody(Connect.streaming_proto_content_type));
    try std.testing.expect(!usesFramedRequestBody(Connect.unary_proto_content_type));
}

fn validateConnectStreamingRequest(stream: *const ServerStream) !void {
    if (!std.mem.eql(u8, stream.method.items, "POST")) return error.InvalidHttpMethod;
    if (!std.mem.eql(u8, stream.scheme.items, "http") and !std.mem.eql(u8, stream.scheme.items, "https")) return error.InvalidScheme;
    if (stream.authority.items.len == 0) return error.MissingAuthority;
    _ = try splitPath(stream.path.items);
    if (!isConnectStreamingContentType(stream.content_type.items)) return error.InvalidContentType;
    if (!std.mem.eql(u8, stream.protocol_version.items, Connect.protocol_version)) return error.InvalidConnectProtocolVersion;
}

fn acceptsCompression(value: []const u8, encoding: Grpc.Compression) bool {
    if (encoding == .identity) return true;
    var tokens = std.mem.splitScalar(u8, value, ',');
    while (tokens.next()) |token| {
        if (std.ascii.eqlIgnoreCase(std.mem.trim(u8, token, " \t"), encoding.headerValue())) return true;
    }
    return false;
}

fn prepareResponseCompression(connection: *const ServerConnection, stream: *ServerStream) void {
    stream.response_compression = if (acceptsCompression(stream.accept_encoding.items, connection.response_compression))
        connection.response_compression
    else
        .identity;
}

fn frameResponseMessageAlloc(connection: *const ServerConnection, stream: *ServerStream, message: []const u8) ![]u8 {
    prepareResponseCompression(connection, stream);
    if (stream.response_compression == .identity) return Grpc.frameMessageAlloc(connection.allocator, message, .{ .limits = connection.limits.grpc });
    const compressed = try Compression.compressAlloc(connection.allocator, stream.response_compression, message, connection.limits.grpc.max_message_bytes);
    defer connection.allocator.free(compressed);
    return Grpc.frameMessageAlloc(connection.allocator, compressed, .{ .limits = connection.limits.grpc, .compressed = true });
}

fn frameOwnedUnaryResponseAlloc(connection: *const ServerConnection, stream: *ServerStream, response: *Grpc.UnaryResponse) ![]u8 {
    prepareResponseCompression(connection, stream);
    if (stream.response_compression != .identity) return frameResponseMessageAlloc(connection, stream, response.payload);
    if (response.payload.len > connection.limits.grpc.max_message_bytes or response.payload.len > std.math.maxInt(u32)) return error.MessageTooLarge;
    const message_len = response.payload.len;
    const payload = response.takePayload();
    errdefer connection.allocator.free(payload);
    const frame = try connection.allocator.realloc(payload, message_len + 5);
    std.mem.copyBackwards(u8, frame[5..], frame[0..message_len]);
    frame[0] = 0;
    std.mem.writeInt(u32, frame[1..5], @intCast(message_len), .big);
    return frame;
}

const MiddlewareRun = struct {
    context: Middleware.CallContext,
    entered: usize,
    started_at: std.Io.Clock.Timestamp,
};

fn beginMiddleware(connection: *ServerConnection, stream: *ServerStream, route: anytype, protocol: Middleware.Protocol, shape: Grpc.CallShape) struct { run: MiddlewareRun, denied: ?Grpc.Status } {
    var context = Middleware.CallContext{
        .protocol = protocol,
        .authority = stream.authority.items,
        .service = route.service,
        .method = route.method,
        .shape = shape,
        .authorization = stream.authorization.items,
        .iap_jwt = stream.iap_jwt.items,
        .traceparent = stream.traceparent.items,
        .tracestate = stream.tracestate.items,
        .baggage = stream.baggage.items,
        .request_id = stream.request_id.items,
    };
    if (connection.call_counters) |counters| counters.begin();
    const result = Middleware.runBefore(connection.interceptors, &context);
    if (connection.causal) |facts| {
        if (result.status) |status| {
            facts.emitCall(.status, @tagName(status.code), &context);
        } else {
            facts.emitCall(.handler, "started", &context);
            if (shape != .unary) facts.emitCall(.stream, "started", &context);
        }
    }
    if (result.status) |status| if (connection.call_counters) |counters| counters.finish(status.code);
    return .{ .run = .{
        .context = context,
        .entered = result.entered,
        .started_at = std.Io.Clock.Timestamp.now(connection.io, .awake),
    }, .denied = result.status };
}

fn finishMiddleware(connection: *ServerConnection, run: *const MiddlewareRun, code: Grpc.Code, request_messages: usize, response_messages: usize) void {
    const finished_at = std.Io.Clock.Timestamp.now(connection.io, .awake);
    const elapsed = run.started_at.durationTo(finished_at).raw.toMilliseconds();
    Middleware.afterEntered(connection.interceptors, run.entered, &run.context, .{
        .code = code,
        .duration_millis = @intCast(@max(elapsed, 0)),
        .request_messages = request_messages,
        .response_messages = response_messages,
        .end_time_unix_nanos = @intCast(@max(std.Io.Clock.Timestamp.now(connection.io, .real).raw.nanoseconds, 0)),
    });
    if (connection.call_counters) |counters| counters.finish(code);
    if (connection.causal) |facts| {
        facts.emitCall(.handler, if (code == .ok) "succeeded" else "failed", &run.context);
        facts.emitCall(.status, @tagName(code), &run.context);
        if (run.context.shape != .unary) facts.emitCall(.stream, if (code == .ok) "completed" else "failed", &run.context);
    }
}

fn startIncrementalResponse(session: *c.nghttp2_session, connection: *ServerConnection, stream: *ServerStream) !bool {
    if (stream.response_started) return true;
    const protocol: Middleware.Protocol = if (isGrpcContentType(stream.content_type.items)) .grpc else if (isConnectStreamingContentType(stream.content_type.items)) .connect else return false;
    if ((protocol == .grpc and connection.protocol_policy == .connect_only) or
        (protocol == .connect and connection.protocol_policy == .grpc_only)) return false;
    switch (protocol) {
        .grpc => validateGrpcRequest(stream) catch return false,
        .connect => {
            if (!corsAllowed(connection, stream)) {
                try submitConnectIncrementalStatus(session, connection, stream, .{ .code = .permission_denied, .message = "origin is not allowed" });
                return true;
            }
            validateConnectStreamingRequest(stream) catch {
                try submitConnectIncrementalStatus(session, connection, stream, .{ .code = .invalid_argument, .message = "invalid Connect streaming request" });
                return true;
            };
            if (stream.unsupported_request_compression) {
                try submitConnectIncrementalStatus(session, connection, stream, .{ .code = .unimplemented, .message = "request compression is not supported" });
                return true;
            }
        },
    }
    const registry = connection.incremental_registry orelse return false;
    const route = splitPath(stream.path.items) catch return false;
    const entry = registry.find(route.service, route.method) orelse return false;
    const middleware = beginMiddleware(connection, stream, route, protocol, entry.shape);
    if (middleware.denied) |status| {
        if (protocol == .connect) {
            try submitConnectIncrementalStatus(session, connection, stream, status);
            return true;
        }
        try setResponseTrailers(stream, status, &.{}, connection.limits.grpc);
        stream.response_frame = try connection.allocator.dupe(u8, "");
        stream.response_started = true;
        try submitResponse(session, stream);
        return true;
    }
    stream.incremental_decoder = try Grpc.MessageDecoder.init(connection.allocator, connection.limits.grpc);
    errdefer {
        stream.incremental_decoder.?.deinit();
        stream.incremental_decoder = null;
    }
    stream.incremental_runtime = try IncrementalRuntime.create(connection, stream, route, entry.shape, entry.handler, middleware.run);
    stream.response_started = true;
    return true;
}

fn submitIncrementalResponseHeaders(session: *c.nghttp2_session, connection: *ServerConnection, stream: *ServerStream, runtime: *IncrementalRuntime) !void {
    prepareResponseCompression(connection, stream);
    const initial_metadata = if (runtime.initial_metadata) |metadata| metadata.entries else &.{};
    var metadata_headers = try Grpc.metadataHeadersAlloc(connection.allocator, initial_metadata, connection.limits.grpc);
    defer metadata_headers.deinit();
    var provider = c.nghttp2_data_provider{ .source = .{ .ptr = stream }, .read_callback = serverIncrementalDataRead };
    if (runtime.middleware.context.protocol == .grpc) {
        const headers = try connection.allocator.alloc(c.nghttp2_nv, metadata_headers.headers.len + 3);
        defer connection.allocator.free(headers);
        headers[0] = nv(":status", "200");
        headers[1] = nv("content-type", Grpc.content_type);
        headers[2] = nv("grpc-encoding", stream.response_compression.headerValue());
        for (metadata_headers.headers, 0..) |header, index| headers[index + 3] = nv(header.name, header.value);
        try checkNghttp(c.nghttp2_submit_response(session, stream.stream_id, headers.ptr, headers.len, &provider));
    } else {
        var cors_headers: [12]c.nghttp2_nv = undefined;
        var cors_count: usize = 0;
        appendCorsHeaders(&cors_headers, &cors_count, connection, stream);
        const include_encoding = stream.response_compression != .identity;
        const headers = try connection.allocator.alloc(c.nghttp2_nv, 2 + @as(usize, @intFromBool(include_encoding)) + metadata_headers.headers.len + cors_count);
        defer connection.allocator.free(headers);
        var count: usize = 0;
        headers[count] = nv(":status", "200");
        count += 1;
        headers[count] = nv("content-type", Connect.streaming_proto_content_type);
        count += 1;
        if (include_encoding) {
            headers[count] = nv("connect-content-encoding", stream.response_compression.headerValue());
            count += 1;
        }
        for (metadata_headers.headers) |header| {
            headers[count] = nv(header.name, header.value);
            count += 1;
        }
        @memcpy(headers[count .. count + cors_count], cors_headers[0..cors_count]);
        count += cors_count;
        try checkNghttp(c.nghttp2_submit_response(session, stream.stream_id, headers.ptr, count, &provider));
    }
    stream.incremental_headers_submitted = true;
    stream.incremental_provider_active = true;
    runtime.headers_submitted.store(true, .release);
}

fn submitConnectIncrementalStatus(session: *c.nghttp2_session, connection: *ServerConnection, stream: *ServerStream, status: Grpc.Status) !void {
    const json = try Connect.endStreamJsonAlloc(connection.allocator, status, &.{}, connection.limits.grpc);
    defer connection.allocator.free(json);
    stream.response_frame = try Connect.frameEnvelopeAlloc(connection.allocator, .end_stream, json, connection.limits.grpc.max_message_bytes);
    stream.response_started = true;
    try submitRawConnectResponse(session, connection, stream, "200", Connect.streaming_proto_content_type);
}

const IncrementalOutputPoll = struct {
    message: ?Incremental.OwnedMessage = null,
    complete: bool = false,
};

fn finishIncrementalOutputPoll(outbound: *Incremental.Pipe, done: *const std.atomic.Value(bool), first: ?Incremental.OwnedMessage) !IncrementalOutputPoll {
    if (first) |message| return .{ .message = message };
    // The handler may enqueue its final message and publish `done` between the
    // empty queue poll above and this acquire. Once completion is observed, a
    // second poll is mandatory before trailers can commit the stream.
    if (!done.load(.acquire)) return .{};
    return .{ .message = try outbound.tryReceive(), .complete = true };
}

fn pollIncrementalOutput(outbound: *Incremental.Pipe, done: *const std.atomic.Value(bool)) !IncrementalOutputPoll {
    return finishIncrementalOutputPoll(outbound, done, try outbound.tryReceive());
}

fn serverIncrementalDataRead(
    session: ?*c.nghttp2_session,
    stream_id: i32,
    buffer: [*c]u8,
    length: usize,
    data_flags: [*c]u32,
    source: [*c]c.nghttp2_data_source,
    _: ?*anyopaque,
) callconv(.c) isize {
    const stream: *ServerStream = @ptrCast(@alignCast(source.*.ptr.?));
    const runtime = stream.incremental_runtime orelse return c.NGHTTP2_ERR_CALLBACK_FAILURE;
    const connect = runtime.middleware.context.protocol == .connect;
    while (true) {
        if (stream.response_frame) |frame| {
            const remaining = frame.len - stream.response_offset;
            const count = @min(length, remaining);
            if (count != 0) @memcpy(buffer[0..count], frame[stream.response_offset .. stream.response_offset + count]);
            stream.response_offset += count;
            if (stream.response_offset == frame.len) {
                const final_connect_frame = connect and stream.incremental_frame_final;
                stream.allocator.free(frame);
                stream.response_frame = null;
                stream.response_offset = 0;
                stream.incremental_frame_ready = false;
                if (connect) {
                    if (final_connect_frame) {
                        runtime.trailers_submitted = true;
                        stream.incremental_provider_active = false;
                        data_flags.* |= c.NGHTTP2_DATA_FLAG_EOF;
                    }
                    return @intCast(count);
                }
                if (runtime.forcedStatus() != null) {
                    if (!runtime.trailers_submitted and submitIncrementalTrailers(session.?, stream_id, runtime, data_flags) < 0) return c.NGHTTP2_ERR_CALLBACK_FAILURE;
                    stream.incremental_provider_active = false;
                    return @intCast(count);
                }
                const next = pollIncrementalOutput(&runtime.outbound, &runtime.done) catch return c.NGHTTP2_ERR_CALLBACK_FAILURE;
                if (next.message) |message| {
                    runtime.lookahead = message;
                } else if (next.complete) {
                    if (!runtime.trailers_submitted and submitIncrementalTrailers(session.?, stream_id, runtime, data_flags) < 0) return c.NGHTTP2_ERR_CALLBACK_FAILURE;
                    stream.incremental_provider_active = false;
                } else {
                    data_flags.* |= c.NGHTTP2_DATA_FLAG_EOF | c.NGHTTP2_DATA_FLAG_NO_END_STREAM;
                    stream.incremental_provider_active = false;
                }
            }
            return @intCast(count);
        }
        if (runtime.forcedStatus() != null) {
            if (runtime.lookahead) |*message| message.deinit();
            runtime.lookahead = null;
        }
        var output_poll: IncrementalOutputPoll = if (runtime.forcedStatus() != null)
            .{ .complete = true }
        else if (runtime.lookahead) |message| blk: {
            runtime.lookahead = null;
            break :blk .{ .message = message };
        } else pollIncrementalOutput(&runtime.outbound, &runtime.done) catch return c.NGHTTP2_ERR_CALLBACK_FAILURE;
        if (output_poll.message) |*message| {
            stream.response_frame = frameIncrementalResponseMessageAlloc(runtime, stream, message.bytes) catch {
                message.deinit();
                return c.NGHTTP2_ERR_CALLBACK_FAILURE;
            };
            stream.incremental_frame_ready = true;
            stream.incremental_frame_final = false;
            message.deinit();
            _ = runtime.response_messages.fetchAdd(1, .release);
            continue;
        }
        if (!output_poll.complete) return c.NGHTTP2_ERR_DEFERRED;
        if (connect) {
            if (runtime.trailers_submitted) {
                data_flags.* |= c.NGHTTP2_DATA_FLAG_EOF;
                stream.incremental_provider_active = false;
                return 0;
            }
            const trailing_metadata = if (runtime.trailing_metadata) |metadata| metadata.entries else &.{};
            const json = Connect.endStreamJsonAlloc(runtime.allocator, runtime.status(), trailing_metadata, runtime.connection.limits.grpc) catch return c.NGHTTP2_ERR_CALLBACK_FAILURE;
            defer runtime.allocator.free(json);
            stream.response_frame = Connect.frameEnvelopeAlloc(runtime.allocator, .end_stream, json, runtime.connection.limits.grpc.max_message_bytes) catch return c.NGHTTP2_ERR_CALLBACK_FAILURE;
            stream.incremental_frame_ready = true;
            stream.incremental_frame_final = true;
            continue;
        }
        if (!runtime.trailers_submitted) {
            if (submitIncrementalTrailers(session.?, stream_id, runtime, data_flags) < 0) return c.NGHTTP2_ERR_CALLBACK_FAILURE;
        } else data_flags.* |= c.NGHTTP2_DATA_FLAG_EOF;
        return 0;
    }
}

fn frameIncrementalResponseMessageAlloc(runtime: *IncrementalRuntime, stream: *ServerStream, message: []const u8) ![]u8 {
    if (runtime.middleware.context.protocol == .grpc) return frameResponseMessageAlloc(runtime.connection, stream, message);
    prepareResponseCompression(runtime.connection, stream);
    const payload = if (stream.response_compression == .identity)
        try runtime.allocator.dupe(u8, message)
    else
        try Compression.compressAlloc(runtime.allocator, stream.response_compression, message, runtime.connection.limits.grpc.max_message_bytes);
    defer runtime.allocator.free(payload);
    return Connect.frameEnvelopeWithCompressionAlloc(
        runtime.allocator,
        .message,
        stream.response_compression != .identity,
        payload,
        runtime.connection.limits.grpc.max_message_bytes,
    );
}

fn submitIncrementalTrailers(session: *c.nghttp2_session, stream_id: i32, runtime: *IncrementalRuntime, data_flags: *u32) c_int {
    data_flags.* |= c.NGHTTP2_DATA_FLAG_EOF | c.NGHTTP2_DATA_FLAG_NO_END_STREAM;
    const trailing_metadata = if (runtime.trailing_metadata) |metadata| metadata.entries else &.{};
    var block = Grpc.statusTrailersAlloc(runtime.allocator, runtime.status(), trailing_metadata, runtime.connection.limits.grpc) catch return c.NGHTTP2_ERR_CALLBACK_FAILURE;
    defer block.deinit();
    const submitted = submitTrailerBlock(session, stream_id, runtime.allocator, block);
    if (submitted < 0) return submitted;
    runtime.trailers_submitted = true;
    return 0;
}

fn submitIncrementalTrailersDirect(session: *c.nghttp2_session, stream_id: i32, runtime: *IncrementalRuntime) !void {
    if (runtime.trailers_submitted) return;
    const trailing_metadata = if (runtime.trailing_metadata) |metadata| metadata.entries else &.{};
    var block = try Grpc.statusTrailersAlloc(runtime.allocator, runtime.status(), trailing_metadata, runtime.connection.limits.grpc);
    defer block.deinit();
    try checkNghttp(submitTrailerBlock(session, stream_id, runtime.allocator, block));
    runtime.trailers_submitted = true;
}

fn serverDataRead(
    session: ?*c.nghttp2_session,
    stream_id: i32,
    buffer: [*c]u8,
    length: usize,
    data_flags: [*c]u32,
    source: [*c]c.nghttp2_data_source,
    _: ?*anyopaque,
) callconv(.c) isize {
    const stream: *ServerStream = @ptrCast(@alignCast(source.*.ptr.?));
    const frame = stream.response_frame orelse return c.NGHTTP2_ERR_CALLBACK_FAILURE;
    const remaining = frame.len - stream.response_offset;
    const count = @min(length, remaining);
    if (count != 0) @memcpy(buffer[0..count], frame[stream.response_offset .. stream.response_offset + count]);
    stream.response_offset += count;
    if (stream.response_offset == frame.len) {
        data_flags.* |= c.NGHTTP2_DATA_FLAG_EOF | c.NGHTTP2_DATA_FLAG_NO_END_STREAM;
        if (stream.response_trailers) |trailers| {
            if (submitTrailerBlock(session.?, stream_id, stream.allocator, trailers) < 0) return c.NGHTTP2_ERR_CALLBACK_FAILURE;
        } else {
            var trailers = [_]c.nghttp2_nv{nv("grpc-status", "0")};
            if (c.nghttp2_submit_trailer(session.?, stream_id, &trailers, trailers.len) < 0) return c.NGHTTP2_ERR_CALLBACK_FAILURE;
        }
    }
    return @intCast(count);
}

fn serverRawDataRead(
    _: ?*c.nghttp2_session,
    _: i32,
    buffer: [*c]u8,
    length: usize,
    data_flags: [*c]u32,
    source: [*c]c.nghttp2_data_source,
    _: ?*anyopaque,
) callconv(.c) isize {
    const stream: *ServerStream = @ptrCast(@alignCast(source.*.ptr.?));
    const body = stream.response_frame orelse "";
    const remaining = body.len - stream.response_offset;
    const count = @min(length, remaining);
    if (count != 0) @memcpy(buffer[0..count], body[stream.response_offset .. stream.response_offset + count]);
    stream.response_offset += count;
    if (stream.response_offset == body.len) data_flags.* |= c.NGHTTP2_DATA_FLAG_EOF;
    return @intCast(count);
}

fn submitServerResponse(session: *c.nghttp2_session, connection: *ServerConnection, stream: *ServerStream) !void {
    if (std.mem.eql(u8, stream.method.items, "OPTIONS")) return submitCorsPreflight(session, connection, stream);
    const connect_unary = std.mem.startsWith(u8, stream.content_type.items, Connect.unary_proto_content_type) or
        std.mem.startsWith(u8, stream.content_type.items, Connect.unary_json_content_type);
    const connect_streaming = std.mem.startsWith(u8, stream.content_type.items, Connect.streaming_proto_content_type);
    if (connection.protocol_policy == .connect_only and !connect_unary and !connect_streaming) {
        return submitConnectHttpError(session, connection, stream, "415", .unknown, "unsupported media type");
    }
    if (connect_unary) {
        return submitConnectUnaryResponse(session, connection, stream);
    }
    if (connect_streaming) {
        return submitConnectStreamingResponse(session, connection, stream);
    }
    validateGrpcRequest(stream) catch |err| {
        var diagnostic: [128]u8 = undefined;
        const message = std.fmt.bufPrint(&diagnostic, "invalid gRPC request headers: {s}", .{@errorName(err)}) catch "invalid gRPC request headers";
        try setResponseTrailers(stream, .{ .code = .invalid_argument, .message = message }, &.{}, connection.limits.grpc);
        stream.response_frame = try connection.allocator.dupe(u8, "");
        return submitResponse(session, stream);
    };
    const route = splitPath(stream.path.items) catch {
        try setResponseTrailers(stream, .{ .code = .unimplemented, .message = "invalid gRPC method path" }, &.{}, connection.limits.grpc);
        stream.response_frame = try connection.allocator.dupe(u8, "");
        return submitResponse(session, stream);
    };
    if (connection.streaming_registry) |registry| if (registry.shapeFor(route.service, route.method)) |shape| {
        var middleware = beginMiddleware(connection, stream, route, .grpc, shape);
        if (middleware.denied) |status| {
            try setResponseTrailers(stream, status, &.{}, connection.limits.grpc);
            stream.response_frame = try connection.allocator.dupe(u8, "");
            return submitResponse(session, stream);
        }
        var outcome_code: Grpc.Code = .unknown;
        var response_count: usize = 0;
        defer finishMiddleware(connection, &middleware.run, outcome_code, 0, response_count);
        var decoder = try Grpc.MessageDecoder.init(connection.allocator, connection.limits.grpc);
        defer decoder.deinit();
        try decoder.push(stream.body.items);
        try decoder.finish();
        var owned_messages: std.ArrayList(Grpc.OwnedMessage) = .empty;
        defer {
            for (owned_messages.items) |*message| message.deinit(connection.allocator);
            owned_messages.deinit(connection.allocator);
        }
        while (decoder.pop()) |message| try owned_messages.append(connection.allocator, message);
        const messages = try connection.allocator.alloc([]const u8, owned_messages.items.len);
        defer connection.allocator.free(messages);
        var decompressed: std.ArrayList([]u8) = .empty;
        defer {
            for (decompressed.items) |message| connection.allocator.free(message);
            decompressed.deinit(connection.allocator);
        }
        for (owned_messages.items, 0..) |message, index| {
            if (message.compressed) {
                if (stream.request_compression == .identity) return error.UnsupportedCompression;
                const restored = try Compression.decompressAlloc(connection.allocator, stream.request_compression, message.bytes, connection.limits.grpc.max_message_bytes);
                try decompressed.append(connection.allocator, restored);
                messages[index] = restored;
            } else messages[index] = message.bytes;
        }
        var request_metadata = try requestMetadataAlloc(stream, connection.limits.grpc);
        defer request_metadata.deinit();
        var response = try registry.invokeAlloc(connection.allocator, .{
            .authority = stream.authority.items,
            .service = route.service,
            .method = route.method,
            .messages = messages,
            .scheme = stream.scheme.items,
            .metadata = request_metadata.entries,
            .timeout_millis = stream.timeout_millis,
            .shape = shape,
        }, connection.limits.grpc);
        defer response.deinit();
        var frames: std.ArrayList(u8) = .empty;
        errdefer frames.deinit(connection.allocator);
        for (response.messages) |message| {
            const frame = try frameResponseMessageAlloc(connection, stream, message);
            defer connection.allocator.free(frame);
            try frames.appendSlice(connection.allocator, frame);
        }
        try setResponseTrailers(stream, response.status, response.trailing_metadata, connection.limits.grpc);
        outcome_code = response.status.code;
        response_count = response.messages.len;
        stream.response_frame = try frames.toOwnedSlice(connection.allocator);
        return submitResponseWithMetadata(session, stream, response.initial_metadata);
    };
    var response = try invokeUnaryResponseAlloc(connection, stream);
    defer response.deinit();
    try submitUnaryResponse(session, connection, stream, &response);
}

fn invokeUnaryResponseAlloc(connection: *ServerConnection, stream: *ServerStream) !Grpc.UnaryResponse {
    validateGrpcRequest(stream) catch |err| {
        var diagnostic: [128]u8 = undefined;
        const message = std.fmt.bufPrint(&diagnostic, "invalid gRPC request headers: {s}", .{@errorName(err)}) catch "invalid gRPC request headers";
        return Grpc.UnaryResponse.initAlloc(connection.allocator, "", .{ .code = .invalid_argument, .message = message });
    };
    const route = splitPath(stream.path.items) catch {
        return Grpc.UnaryResponse.initAlloc(connection.allocator, "", .{ .code = .unimplemented, .message = "invalid gRPC method path" });
    };
    var middleware = beginMiddleware(connection, stream, route, .grpc, .unary);
    if (middleware.denied) |status| return Grpc.UnaryResponse.initAlloc(connection.allocator, "", status);
    var outcome_code: Grpc.Code = .unknown;
    defer finishMiddleware(connection, &middleware.run, outcome_code, 1, 1);
    var payload = try decodeUnaryBody(connection.allocator, stream.body.items, stream.request_compression, connection.limits.grpc);
    defer payload.deinit();
    var request_metadata = try requestMetadataAlloc(stream, connection.limits.grpc);
    defer request_metadata.deinit();
    const response = connection.registry.invokeAlloc(connection.allocator, .{
        .authority = stream.authority.items,
        .service = route.service,
        .method = route.method,
        .payload = payload.bytes,
        .scheme = stream.scheme.items,
        .metadata = request_metadata.entries,
        .timeout_millis = stream.timeout_millis,
    }, .{ .limits = connection.limits.grpc }) catch |err| switch (err) {
        error.MethodNotFound => {
            outcome_code = .unimplemented;
            return Grpc.UnaryResponse.initAlloc(connection.allocator, "", .{ .code = .unimplemented, .message = "method not found" });
        },
        else => return err,
    };
    outcome_code = response.status.code;
    return response;
}

fn submitUnaryResponse(session: *c.nghttp2_session, connection: *ServerConnection, stream: *ServerStream, response: *Grpc.UnaryResponse) !void {
    try setResponseTrailersFull(stream, response.status, response.trailing_metadata, response.retry_pushback_millis, connection.limits.grpc);
    stream.response_frame = if (response.status.code != .ok and response.payload.len == 0)
        try connection.allocator.dupe(u8, "")
    else
        try frameOwnedUnaryResponseAlloc(connection, stream, response);
    try submitResponseWithMetadata(session, stream, response.initial_metadata);
}

fn shouldScheduleUnary(connection: *const ServerConnection, stream: *const ServerStream) bool {
    if (std.mem.eql(u8, stream.method.items, "OPTIONS")) return false;
    if (connection.protocol_policy == .connect_only or !isGrpcContentType(stream.content_type.items)) return false;
    const route = splitPath(stream.path.items) catch return false;
    if (connection.streaming_registry) |registry| if (registry.shapeFor(route.service, route.method) != null) return false;
    return true;
}

fn scheduleUnary(connection: *ServerConnection, stream: *ServerStream) !void {
    if (stream.unary_job_scheduled) return error.UnaryJobAlreadyScheduled;
    const executor = connection.handler_executor orelse return error.HandlerExecutorMissing;
    stream.unary_connection = connection;
    stream.unary_job_scheduled = true;
    executor.schedule(.{ .pointer = stream, .run_fn = ServerStream.runUnary }) catch |err| {
        stream.unary_job_scheduled = false;
        stream.unary_connection = null;
        return err;
    };
}

fn completeUnaryResponses(session: *c.nghttp2_session, connection: *ServerConnection) !void {
    var index: usize = 0;
    while (index < connection.streams.items.len) {
        const stream = connection.streams.items[index];
        if (!stream.unary_job_scheduled or !stream.unary_job_complete.load(.acquire)) {
            index += 1;
            continue;
        }
        if (stream.peer_closed) {
            _ = connection.removeStream(stream.stream_id);
            continue;
        }
        stream.unary_job_scheduled = false;
        stream.unary_connection = null;
        if (stream.unary_error) |err| return err;
        var response = stream.unary_response orelse return error.UnaryResponseMissing;
        stream.unary_response = null;
        defer response.deinit();
        try submitUnaryResponse(session, connection, stream, &response);
        index += 1;
    }
}

fn corsAllowed(connection: *ServerConnection, stream: *ServerStream) bool {
    return stream.origin.items.len == 0 or connection.cors.allows(stream.origin.items);
}

fn appendCorsHeaders(headers: anytype, count: *usize, connection: *ServerConnection, stream: *ServerStream) void {
    if (stream.origin.items.len == 0 or !corsAllowed(connection, stream)) return;
    headers[count.*] = nv("access-control-allow-origin", stream.origin.items);
    count.* += 1;
    headers[count.*] = nv("vary", "Origin");
    count.* += 1;
    headers[count.*] = nv("access-control-expose-headers", "grpc-status,grpc-message,connect-content-encoding,connect-accept-encoding");
    count.* += 1;
    if (connection.cors.allow_credentials) {
        headers[count.*] = nv("access-control-allow-credentials", "true");
        count.* += 1;
    }
}

fn submitCorsPreflight(session: *c.nghttp2_session, connection: *ServerConnection, stream: *ServerStream) !void {
    const allowed = corsAllowed(connection, stream);
    stream.response_frame = try connection.allocator.dupe(u8, "");
    var headers: [12]c.nghttp2_nv = undefined;
    var count: usize = 0;
    headers[count] = nv(":status", if (allowed) "204" else "403");
    count += 1;
    headers[count] = nv("access-control-allow-methods", "POST,GET,OPTIONS");
    count += 1;
    headers[count] = nv("access-control-allow-headers", "content-type,connect-protocol-version,connect-timeout-ms,authorization,x-user-agent,x-grpc-web,grpc-timeout");
    count += 1;
    var max_age: [10]u8 = undefined;
    const max_age_value = try std.fmt.bufPrint(&max_age, "{d}", .{connection.cors.max_age_seconds});
    headers[count] = nv("access-control-max-age", max_age_value);
    count += 1;
    appendCorsHeaders(&headers, &count, connection, stream);
    var provider = c.nghttp2_data_provider{ .source = .{ .ptr = stream }, .read_callback = serverRawDataRead };
    try checkNghttp(c.nghttp2_submit_response(session, stream.stream_id, &headers, count, &provider));
}

fn submitConnectUnaryResponse(session: *c.nghttp2_session, connection: *ServerConnection, stream: *ServerStream) !void {
    if (!corsAllowed(connection, stream)) return submitConnectError(session, connection, stream, .permission_denied, "origin is not allowed");
    if (!std.mem.eql(u8, stream.method.items, "POST")) return submitConnectHttpError(session, connection, stream, "405", .unknown, "method not allowed");
    if (stream.protocol_version.items.len != 0 and !std.mem.eql(u8, stream.protocol_version.items, Connect.protocol_version)) {
        return submitConnectError(session, connection, stream, .invalid_argument, "unsupported Connect protocol version");
    }
    if (!std.mem.startsWith(u8, stream.content_type.items, Connect.unary_proto_content_type)) {
        return submitConnectHttpError(session, connection, stream, "415", .unknown, "unsupported media type");
    }
    if (stream.unsupported_request_compression) return submitConnectError(session, connection, stream, .unimplemented, "request compression is not supported");
    const route = splitPath(stream.path.items) catch return submitConnectHttpError(session, connection, stream, "404", .unimplemented, "procedure is not implemented");
    var middleware = beginMiddleware(connection, stream, route, .connect, .unary);
    if (middleware.denied) |status| return submitConnectError(session, connection, stream, status.code, status.message);
    var outcome_code: Grpc.Code = .unknown;
    defer finishMiddleware(connection, &middleware.run, outcome_code, 1, 1);
    var request_metadata = try requestMetadataAlloc(stream, connection.limits.grpc);
    defer request_metadata.deinit();
    var response = connection.registry.invokeAlloc(connection.allocator, .{
        .authority = stream.authority.items,
        .service = route.service,
        .method = route.method,
        .payload = stream.body.items,
        .scheme = stream.scheme.items,
        .metadata = request_metadata.entries,
        .timeout_millis = stream.timeout_millis,
    }, .{ .limits = connection.limits.grpc }) catch |err| switch (err) {
        error.MethodNotFound => return submitConnectHttpError(session, connection, stream, "404", .unimplemented, "procedure is not implemented"),
        else => return submitConnectError(session, connection, stream, .internal, "handler failed"),
    };
    defer response.deinit();
    outcome_code = response.status.code;
    if (response.status.code != .ok) {
        var response_metadata = try ConnectUnaryMetadata.initAlloc(connection.allocator, response.initial_metadata, response.trailing_metadata);
        defer response_metadata.deinit();
        return submitConnectStatusError(session, connection, stream, response.status, response_metadata.entries);
    }
    stream.response_frame = try connection.allocator.dupe(u8, response.payload);
    var response_metadata = try ConnectUnaryMetadata.initAlloc(connection.allocator, response.initial_metadata, response.trailing_metadata);
    defer response_metadata.deinit();
    return submitRawConnectResponseWithMetadata(session, connection, stream, "200", Connect.unary_proto_content_type, response_metadata.entries);
}

const ConnectUnaryMetadata = struct {
    allocator: std.mem.Allocator,
    entries: []Grpc.Metadata,
    trailer_names: [][]u8,

    fn initAlloc(allocator: std.mem.Allocator, initial: []const Grpc.Metadata, trailing: []const Grpc.Metadata) !ConnectUnaryMetadata {
        const entries = try allocator.alloc(Grpc.Metadata, initial.len + trailing.len);
        errdefer allocator.free(entries);
        const names = try allocator.alloc([]u8, trailing.len);
        errdefer allocator.free(names);
        var initialized: usize = 0;
        errdefer for (names[0..initialized]) |name| allocator.free(name);
        @memcpy(entries[0..initial.len], initial);
        for (trailing, 0..) |entry, index| {
            names[index] = try std.mem.concat(allocator, u8, &.{ "trailer-", entry.name });
            initialized += 1;
            entries[initial.len + index] = entry;
            entries[initial.len + index].name = names[index];
        }
        return .{ .allocator = allocator, .entries = entries, .trailer_names = names };
    }

    fn deinit(self: *ConnectUnaryMetadata) void {
        for (self.trailer_names) |name| self.allocator.free(name);
        self.allocator.free(self.trailer_names);
        self.allocator.free(self.entries);
        self.* = undefined;
    }
};

test "Connect unary trailers use the canonical trailer header prefix" {
    const initial = [_]Grpc.Metadata{.{ .name = "x-header", .value = "one" }};
    const trailing = [_]Grpc.Metadata{.{ .name = "x-trailer", .value = "two" }};
    var metadata = try ConnectUnaryMetadata.initAlloc(std.testing.allocator, &initial, &trailing);
    defer metadata.deinit();
    try std.testing.expectEqualStrings("x-header", metadata.entries[0].name);
    try std.testing.expectEqualStrings("trailer-x-trailer", metadata.entries[1].name);
    var headers = try Grpc.metadataHeadersAlloc(std.testing.allocator, metadata.entries, .{});
    defer headers.deinit();
    try std.testing.expectEqualStrings("trailer-x-trailer", headers.headers[1].name);
}

fn submitConnectError(session: *c.nghttp2_session, connection: *ServerConnection, stream: *ServerStream, code: Grpc.Code, message: []const u8) !void {
    return submitConnectStatusError(session, connection, stream, .{ .code = code, .message = message }, &.{});
}

fn submitConnectStatusError(session: *c.nghttp2_session, connection: *ServerConnection, stream: *ServerStream, status_value: Grpc.Status, metadata: []const Grpc.Metadata) !void {
    stream.response_frame = try Connect.errorJsonStatusAlloc(connection.allocator, status_value);
    var status_buffer: [3]u8 = undefined;
    const status = try std.fmt.bufPrint(&status_buffer, "{d}", .{Connect.httpStatus(status_value.code)});
    return submitRawConnectResponseWithMetadata(session, connection, stream, status, Connect.unary_json_content_type, metadata);
}

fn submitConnectHttpError(session: *c.nghttp2_session, connection: *ServerConnection, stream: *ServerStream, http_status: []const u8, code: Grpc.Code, message: []const u8) !void {
    stream.response_frame = try Connect.errorJsonAlloc(connection.allocator, code, message);
    return submitRawConnectResponse(session, connection, stream, http_status, Connect.unary_json_content_type);
}

fn submitRawConnectResponse(session: *c.nghttp2_session, connection: *ServerConnection, stream: *ServerStream, status: []const u8, content_type_value: []const u8) !void {
    return submitRawConnectResponseWithMetadata(session, connection, stream, status, content_type_value, &.{});
}

fn submitRawConnectResponseWithMetadata(session: *c.nghttp2_session, connection: *ServerConnection, stream: *ServerStream, status: []const u8, content_type_value: []const u8, metadata: []const Grpc.Metadata) !void {
    var metadata_headers = try Grpc.metadataHeadersAlloc(connection.allocator, metadata, connection.limits.grpc);
    defer metadata_headers.deinit();
    var cors_headers: [12]c.nghttp2_nv = undefined;
    var cors_count: usize = 0;
    appendCorsHeaders(&cors_headers, &cors_count, connection, stream);
    const include_encoding = std.mem.startsWith(u8, content_type_value, Connect.streaming_proto_content_type) and stream.response_compression != .identity;
    const headers = try connection.allocator.alloc(c.nghttp2_nv, 2 + @as(usize, @intFromBool(include_encoding)) + metadata_headers.headers.len + cors_count);
    defer connection.allocator.free(headers);
    var count: usize = 0;
    headers[count] = nv(":status", status);
    count += 1;
    headers[count] = nv("content-type", content_type_value);
    count += 1;
    if (include_encoding) {
        headers[count] = nv("connect-content-encoding", stream.response_compression.headerValue());
        count += 1;
    }
    for (metadata_headers.headers) |header| {
        headers[count] = nv(header.name, header.value);
        count += 1;
    }
    @memcpy(headers[count .. count + cors_count], cors_headers[0..cors_count]);
    count += cors_count;
    var provider = c.nghttp2_data_provider{ .source = .{ .ptr = stream }, .read_callback = serverRawDataRead };
    try checkNghttp(c.nghttp2_submit_response(session, stream.stream_id, headers.ptr, count, &provider));
}

fn submitConnectStreamingResponse(session: *c.nghttp2_session, connection: *ServerConnection, stream: *ServerStream) !void {
    if (!corsAllowed(connection, stream)) return submitConnectError(session, connection, stream, .permission_denied, "origin is not allowed");
    const route = splitPath(stream.path.items) catch return submitConnectError(session, connection, stream, .unimplemented, "procedure is not implemented");
    const registry = connection.streaming_registry orelse return submitConnectError(session, connection, stream, .unimplemented, "streaming registry is not installed");
    const shape = registry.shapeFor(route.service, route.method) orelse return submitConnectError(session, connection, stream, .unimplemented, "procedure is not implemented");
    var middleware = beginMiddleware(connection, stream, route, .connect, shape);
    if (middleware.denied) |status| return submitConnectError(session, connection, stream, status.code, status.message);
    var outcome_code: Grpc.Code = .unknown;
    var request_count: usize = 0;
    var response_count: usize = 0;
    defer finishMiddleware(connection, &middleware.run, outcome_code, request_count, response_count);
    var decoded = Connect.decodeEnvelopesAlloc(connection.allocator, stream.body.items, .{
        .max_message_bytes = connection.limits.grpc.max_message_bytes,
        .max_messages = connection.limits.grpc.max_stream_messages,
    }) catch return submitConnectError(session, connection, stream, .invalid_argument, "invalid Connect envelope");
    defer decoded.deinit();
    request_count = decoded.items.len;
    var messages = try connection.allocator.alloc([]const u8, decoded.items.len);
    defer connection.allocator.free(messages);
    var decompressed: std.ArrayList([]u8) = .empty;
    defer {
        for (decompressed.items) |message| connection.allocator.free(message);
        decompressed.deinit(connection.allocator);
    }
    for (decoded.items, 0..) |item, index| {
        if (item.kind != .message) return submitConnectError(session, connection, stream, .invalid_argument, "unexpected Connect end-stream request");
        if (item.compressed) {
            if (stream.request_compression == .identity) return submitConnectError(session, connection, stream, .invalid_argument, "compressed envelope lacks an encoding");
            const restored = Compression.decompressAlloc(connection.allocator, stream.request_compression, item.payload, connection.limits.grpc.max_message_bytes) catch return submitConnectError(session, connection, stream, .invalid_argument, "invalid compressed Connect envelope");
            try decompressed.append(connection.allocator, restored);
            messages[index] = restored;
        } else messages[index] = item.payload;
    }
    var request_metadata = try requestMetadataAlloc(stream, connection.limits.grpc);
    defer request_metadata.deinit();
    var response = registry.invokeAlloc(connection.allocator, .{
        .authority = stream.authority.items,
        .service = route.service,
        .method = route.method,
        .messages = messages,
        .scheme = stream.scheme.items,
        .metadata = request_metadata.entries,
        .timeout_millis = stream.timeout_millis,
        .shape = shape,
    }, connection.limits.grpc) catch return submitConnectError(session, connection, stream, .internal, "handler failed");
    defer response.deinit();
    outcome_code = response.status.code;
    response_count = response.messages.len;
    var body: std.ArrayList(u8) = .empty;
    errdefer body.deinit(connection.allocator);
    prepareResponseCompression(connection, stream);
    for (response.messages) |message| {
        const payload = if (stream.response_compression == .identity)
            try connection.allocator.dupe(u8, message)
        else
            try Compression.compressAlloc(connection.allocator, stream.response_compression, message, connection.limits.grpc.max_message_bytes);
        defer connection.allocator.free(payload);
        const frame = try Connect.frameEnvelopeWithCompressionAlloc(connection.allocator, .message, stream.response_compression != .identity, payload, connection.limits.grpc.max_message_bytes);
        defer connection.allocator.free(frame);
        try body.appendSlice(connection.allocator, frame);
    }
    const end_json = try Connect.endStreamJsonAlloc(connection.allocator, response.status, response.trailing_metadata, connection.limits.grpc);
    defer connection.allocator.free(end_json);
    const end_frame = try Connect.frameEnvelopeAlloc(connection.allocator, .end_stream, end_json, connection.limits.grpc.max_message_bytes);
    defer connection.allocator.free(end_frame);
    try body.appendSlice(connection.allocator, end_frame);
    stream.response_frame = try body.toOwnedSlice(connection.allocator);
    return submitRawConnectResponseWithMetadata(session, connection, stream, "200", Connect.streaming_proto_content_type, response.initial_metadata);
}

fn submitResponse(session: *c.nghttp2_session, stream: *ServerStream) !void {
    return submitResponseWithMetadata(session, stream, &.{});
}

fn submitResponseWithMetadata(session: *c.nghttp2_session, stream: *ServerStream, metadata: []const Grpc.Metadata) !void {
    var provider = c.nghttp2_data_provider{ .source = .{ .ptr = stream }, .read_callback = serverDataRead };
    if (metadata.len == 0) {
        var headers = [_]c.nghttp2_nv{
            nv(":status", "200"),
            nv("content-type", Grpc.content_type),
            nv("grpc-encoding", stream.response_compression.headerValue()),
        };
        try checkNghttp(c.nghttp2_submit_response(session, stream.stream_id, &headers, headers.len, &provider));
        return;
    }
    var metadata_headers = try Grpc.metadataHeadersAlloc(stream.allocator, metadata, stream.grpc_limits);
    defer metadata_headers.deinit();
    const headers = try stream.allocator.alloc(c.nghttp2_nv, metadata_headers.headers.len + 3);
    defer stream.allocator.free(headers);
    headers[0] = nv(":status", "200");
    headers[1] = nv("content-type", Grpc.content_type);
    headers[2] = nv("grpc-encoding", stream.response_compression.headerValue());
    for (metadata_headers.headers, 0..) |header, index| headers[index + 3] = nv(header.name, header.value);
    try checkNghttp(c.nghttp2_submit_response(session, stream.stream_id, headers.ptr, headers.len, &provider));
}

fn serverOnFrame(
    maybe_session: ?*c.nghttp2_session,
    frame: [*c]const c.nghttp2_frame,
    user_data: ?*anyopaque,
) callconv(.c) c_int {
    const connection: *ServerConnection = @ptrCast(@alignCast(user_data.?));
    if (frame.*.hd.type == c.NGHTTP2_PING and (frame.*.hd.flags & c.NGHTTP2_FLAG_ACK) == 0) {
        const now = std.Io.Clock.Timestamp.now(connection.io, .awake).raw.nanoseconds;
        const now_millis: u64 = @intCast(@max(@divTrunc(now, std.time.ns_per_ms), 0));
        if (connection.peer_keepalive.observe(now_millis, connection.streams.items.len != 0) == .close) {
            const session = maybe_session orelse return c.NGHTTP2_ERR_CALLBACK_FAILURE;
            const reason = "too_many_pings";
            if (c.nghttp2_submit_goaway(session, c.NGHTTP2_FLAG_NONE, c.nghttp2_session_get_last_proc_stream_id(session), c.NGHTTP2_ENHANCE_YOUR_CALM, reason.ptr, reason.len) < 0) return c.NGHTTP2_ERR_CALLBACK_FAILURE;
            connection.close_after_flush = true;
        }
        return 0;
    }
    if (frame.*.hd.type != c.NGHTTP2_DATA and frame.*.hd.type != c.NGHTTP2_HEADERS) return 0;
    const session = maybe_session orelse return c.NGHTTP2_ERR_CALLBACK_FAILURE;
    const stream = connection.callbackStream(session, frame.*.hd.stream_id, false) catch |err| {
        connection.callback_error = err;
        return c.NGHTTP2_ERR_CALLBACK_FAILURE;
    };
    if (frame.*.hd.type == c.NGHTTP2_HEADERS and !stream.response_started) {
        const started = startIncrementalResponse(maybe_session.?, connection, stream) catch |err| {
            connection.callback_error = err;
            return c.NGHTTP2_ERR_CALLBACK_FAILURE;
        };
        if (started and (frame.*.hd.flags & c.NGHTTP2_FLAG_END_STREAM) == 0) return 0;
    }
    if ((frame.*.hd.flags & c.NGHTTP2_FLAG_END_STREAM) == 0) return 0;
    if (stream.incremental_runtime) |runtime| {
        if (stream.incremental_decoder) |*decoder| decoder.finish() catch |err| {
            connection.callback_error = err;
            return c.NGHTTP2_ERR_CALLBACK_FAILURE;
        };
        runtime.inbound.close();
        return 0;
    }
    if (stream.response_started) return 0;
    if (shouldScheduleUnary(connection, stream)) {
        scheduleUnary(connection, stream) catch |err| {
            connection.callback_error = err;
            return c.NGHTTP2_ERR_CALLBACK_FAILURE;
        };
        return 0;
    }
    submitServerResponse(maybe_session.?, connection, stream) catch |err| {
        connection.callback_error = err;
        return c.NGHTTP2_ERR_CALLBACK_FAILURE;
    };
    return 0;
}

fn serverOnClose(
    maybe_session: ?*c.nghttp2_session,
    stream_id: i32,
    _: u32,
    user_data: ?*anyopaque,
) callconv(.c) c_int {
    const connection: *ServerConnection = @ptrCast(@alignCast(user_data.?));
    if (maybe_session) |session| _ = c.nghttp2_session_set_stream_user_data(session, stream_id, null);
    if (connection.findStream(stream_id)) |stream| if (stream.unary_job_scheduled) {
        stream.peer_closed = true;
        return 0;
    };
    _ = connection.removeStream(stream_id);
    return 0;
}

fn serverCallbacks() !*c.nghttp2_session_callbacks {
    var callbacks: ?*c.nghttp2_session_callbacks = null;
    try checkNghttp(c.nghttp2_session_callbacks_new(&callbacks));
    const value = callbacks orelse return error.Http2InitializationFailed;
    c.nghttp2_session_callbacks_set_on_header_callback(value, serverOnHeader);
    c.nghttp2_session_callbacks_set_on_data_chunk_recv_callback(value, serverOnData);
    c.nghttp2_session_callbacks_set_on_frame_recv_callback(value, serverOnFrame);
    c.nghttp2_session_callbacks_set_on_stream_close_callback(value, serverOnClose);
    return value;
}

pub const ServerOptions = struct {
    host: []const u8 = "127.0.0.1",
    port: u16 = 50051,
    limits: Limits = .{},
    tls: ?ServerTlsConfig = null,
    /// Disable Nagle's algorithm on every accepted gRPC connection.
    tcp_nodelay: bool = true,
    response_compression: Grpc.Compression = .identity,
    max_calls_per_connection: usize = 100_000,
    max_connections: usize = 80,
    max_concurrent_streams: usize = 100,
    initial_stream_window_bytes: u32 = 4 * 1024 * 1024,
    initial_connection_window_bytes: u32 = 16 * 1024 * 1024,
    goaway_grace_millis: u64 = 250,
    connection_idle_timeout_millis: ?u64 = 5 * 60 * 1000,
    connection_max_age_millis: ?u64 = 60 * 60 * 1000,
    connection_max_age_grace_millis: u64 = 30_000,
    stream_queue_capacity: usize = 16,
    /// Eight workers is the measured Linux default for the synchronous
    /// handler contract. Services with deliberately blocking handlers may
    /// raise this bound without changing HTTP/2 connection ownership.
    handler_worker_count: usize = 8,
    handler_queue_capacity: usize = 1024,
    handler_worker_stack_bytes: usize = 512 * 1024,
    peer_keepalive: PeerKeepalivePolicy = .{},
    protocol_policy: ServerProtocolPolicy = .all,
    cors: Connect.CorsPolicy = .{},
    interceptors: []const Middleware.Interceptor = &.{},
    causal: ?*Middleware.CausalFacts = null,
};

fn serverSettings(options: ServerOptions) [2]c.nghttp2_settings_entry {
    return .{
        .{
            .settings_id = c.NGHTTP2_SETTINGS_MAX_CONCURRENT_STREAMS,
            .value = @intCast(options.max_concurrent_streams),
        },
        .{
            .settings_id = c.NGHTTP2_SETTINGS_INITIAL_WINDOW_SIZE,
            .value = options.initial_stream_window_bytes,
        },
    };
}

pub const SupervisorReport = struct {
    accepted: usize = 0,
    completed: usize = 0,
    failed: usize = 0,
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
        for (self.sockets) |*slot| if (slot.*) |socket| {
            if (socket.handle == handle) {
                slot.* = null;
                return;
            }
        };
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
            (std.Io.net.Stream{ .socket = socket }).shutdown(io, .both) catch {};
        }
    }

    fn lock(self: *ActiveRegistry) void {
        while (!self.mutex.tryLock()) std.Thread.yield() catch {};
    }
};

pub const NativeServer = struct {
    allocator: std.mem.Allocator,
    io: std.Io,
    options: ServerOptions,
    registry: *Grpc.Registry,
    streaming_registry: ?*Grpc.StreamingRegistry = null,
    incremental_registry: ?*Incremental.Registry = null,
    handler_executor: ?*HandlerExecutor = null,
    listener: std.Io.net.Server,
    tls_context: ?*SSL_CTX = null,
    tls_mutex: std.atomic.Mutex = .unlocked,
    certificate_generation: std.atomic.Value(u64),
    open: bool = true,
    accepting: std.atomic.Value(bool),
    accept_mutex: std.Io.Mutex = .init,
    active_registry: *ActiveRegistry,
    call_counters: ServerCallCounters = .{},

    pub fn init(allocator: std.mem.Allocator, io: std.Io, options: ServerOptions, registry: *Grpc.Registry) !NativeServer {
        try options.limits.validate();
        try options.peer_keepalive.validate();
        if (options.max_calls_per_connection == 0 or options.max_connections == 0 or options.max_concurrent_streams == 0 or options.max_concurrent_streams > std.math.maxInt(u32) or options.initial_stream_window_bytes < c.NGHTTP2_INITIAL_WINDOW_SIZE or options.initial_stream_window_bytes > std.math.maxInt(i32) or options.initial_connection_window_bytes < options.initial_stream_window_bytes or options.initial_connection_window_bytes > std.math.maxInt(i32) or options.goaway_grace_millis == 0 or options.connection_max_age_grace_millis == 0 or options.stream_queue_capacity == 0 or options.handler_worker_count == 0 or options.handler_queue_capacity < options.handler_worker_count or options.handler_worker_stack_bytes < 128 * 1024) return error.InvalidLimits;
        if (options.connection_idle_timeout_millis) |timeout| if (timeout == 0) return error.InvalidLimits;
        if (options.connection_max_age_millis) |age| if (age == 0) return error.InvalidLimits;
        if (options.tls) |tls| try tls.validate();
        const address = try std.Io.net.IpAddress.resolve(io, options.host, options.port);
        var listener = try address.listen(io, .{ .reuse_address = true });
        errdefer listener.deinit(io);
        const active_registry = try ActiveRegistry.create(allocator, options.max_connections);
        errdefer active_registry.destroy();
        const tls_context = if (options.tls) |tls| try createServerTlsContext(tls) else null;
        errdefer if (tls_context) |context| SSL_CTX_free(context);
        const handler_executor = try HandlerExecutor.create(
            allocator,
            io,
            options.handler_worker_count,
            options.handler_queue_capacity,
            options.handler_worker_stack_bytes,
        );
        errdefer handler_executor.destroy();
        return .{
            .allocator = allocator,
            .io = io,
            .options = options,
            .registry = registry,
            .listener = listener,
            .tls_context = tls_context,
            .handler_executor = handler_executor,
            .certificate_generation = std.atomic.Value(u64).init(if (tls_context == null) 0 else 1),
            .accepting = std.atomic.Value(bool).init(true),
            .active_registry = active_registry,
        };
    }

    pub fn initStreaming(allocator: std.mem.Allocator, io: std.Io, options: ServerOptions, registry: *Grpc.Registry, streaming_registry: *Grpc.StreamingRegistry) !NativeServer {
        var server = try init(allocator, io, options, registry);
        server.streaming_registry = streaming_registry;
        return server;
    }

    /// Installs queue-backed streaming handlers. Call before `serve`.
    pub fn installIncremental(self: *NativeServer, registry: *Incremental.Registry) !void {
        if (!self.ready() or self.activeConnections() != 0) return error.ServerAlreadyServing;
        if (self.incremental_registry != null) return error.IncrementalRegistryAlreadyInstalled;
        self.incremental_registry = registry;
    }

    pub fn deinit(self: *NativeServer) void {
        self.drain();
        self.lockTls();
        const context = self.tls_context;
        self.tls_context = null;
        self.tls_mutex.unlock();
        if (context) |value| SSL_CTX_free(value);
        if (self.handler_executor) |executor| executor.destroy();
        self.active_registry.destroy();
        self.* = undefined;
    }

    pub fn drain(self: *NativeServer) void {
        if (self.options.causal) |facts| facts.emit(.drain, "started", "server", "drain");
        self.accepting.store(false, .release);
        if (self.open) {
            self.listener.socket.close(self.io);
            self.open = false;
        }
        if (self.options.causal) |facts| facts.emit(.drain, "completed", "server", "drain");
    }

    pub fn ready(self: *const NativeServer) bool {
        return self.open and self.accepting.load(.acquire);
    }

    pub fn activeConnections(self: *NativeServer) usize {
        return self.active_registry.count();
    }

    /// Atomically changes the certificate used by future TLS handshakes.
    /// Existing connections retain their OpenSSL context until they close.
    pub fn reloadTls(self: *NativeServer, config: ServerTlsConfig) !u64 {
        const replacement = try createServerTlsContext(config);
        self.lockTls();
        const previous = self.tls_context;
        self.tls_context = replacement;
        self.options.tls = config;
        const generation = self.certificate_generation.fetchAdd(1, .acq_rel) + 1;
        self.tls_mutex.unlock();
        if (previous) |context| SSL_CTX_free(context);
        return generation;
    }

    pub fn certificateGeneration(self: *const NativeServer) u64 {
        return self.certificate_generation.load(.acquire);
    }

    pub fn shutdown(self: *NativeServer, options: ShutdownOptions) !ShutdownReport {
        try options.validate();
        if (self.options.causal) |facts| facts.emit(.shutdown, "started", "server", "shutdown");
        self.drain();
        const active_at_start = self.activeConnections();
        const graceful_deadline = deadlineFromNow(self.io, options.deadline_ms);
        while (self.activeConnections() != 0 and !deadlineReached(self.io, graceful_deadline)) {
            try sleepMilliseconds(self.io, options.poll_interval_ms);
        }
        if (self.activeConnections() == 0) {
            if (self.options.causal) |facts| facts.emit(.shutdown, "completed", "server", "shutdown");
            return .{
                .active_at_start = active_at_start,
                .active_remaining = 0,
                .drained = true,
                .forced = false,
            };
        }
        self.active_registry.shutdownAll(self.io);
        const force_deadline = deadlineFromNow(self.io, options.force_close_wait_ms);
        while (self.activeConnections() != 0 and !deadlineReached(self.io, force_deadline)) {
            try sleepMilliseconds(self.io, options.poll_interval_ms);
        }
        if (self.options.causal) |facts| facts.emit(.shutdown, "forced", "server", "shutdown");
        return .{
            .active_at_start = active_at_start,
            .active_remaining = self.activeConnections(),
            .drained = false,
            .forced = true,
        };
    }

    pub fn serve(self: *NativeServer) !SupervisorReport {
        if (!self.ready()) return error.ServerNotReady;
        const contexts = try self.allocator.alloc(WorkerContext, self.options.max_connections);
        defer self.allocator.free(contexts);
        const threads = try self.allocator.alloc(std.Thread, self.options.max_connections);
        defer self.allocator.free(threads);
        var spawned: usize = 0;
        errdefer {
            self.drain();
            for (threads[0..spawned]) |thread| thread.join();
        }
        for (contexts, 0..) |*context, index| {
            context.* = .{ .server = self };
            threads[index] = try std.Thread.spawn(.{}, WorkerContext.run, .{context});
            spawned += 1;
        }
        var report = SupervisorReport{ .peak_in_flight = spawned };
        for (threads) |thread| thread.join();
        for (contexts) |context| {
            report.accepted += context.completed + context.failed;
            report.completed += context.completed;
            report.failed += context.failed;
        }
        return report;
    }

    pub fn serveOne(self: *NativeServer) !void {
        if (!self.ready()) return error.ServerNotReady;
        const allocator = self.allocator;
        const stream = try self.acceptOne();
        configureTcpNoDelay(stream.socket.handle, self.options.tcp_nodelay) catch |err| {
            stream.close(self.io);
            return err;
        };
        try self.active_registry.register(stream.socket);
        defer self.active_registry.unregister(stream.socket.handle);
        self.lockTls();
        const retained_context = self.tls_context;
        const context_retained = if (retained_context) |context| SSL_CTX_up_ref(context) == 1 else false;
        const ssl = if (context_retained) SSL_new(retained_context.?) else null;
        const tls_enabled = retained_context != null;
        self.tls_mutex.unlock();
        if (tls_enabled) {
            const context = retained_context.?;
            if (!context_retained) return error.TlsContextReferenceFailed;
            defer SSL_CTX_free(context);
            const secured = ssl orelse return error.TlsConnectionInitializationFailed;
            var owns_secured = true;
            defer if (owns_secured) SSL_free(secured);
            if (SSL_set_fd(secured, stream.socket.handle) != 1) return error.TlsSocketBindingFailed;
            if (SSL_accept(secured) != 1) return error.TlsHandshakeFailed;
            try requireH2(secured);
            var tls_wire = TlsWire{ .io = self.io, .stream = stream, .ssl = secured };
            owns_secured = false;
            return self.serveWire(allocator, tls_wire.wire());
        }
        var plain = PlainWire{ .io = self.io, .stream = stream };
        return self.serveWire(allocator, plain.wire());
    }

    /// Serializes only the accept syscall, never connection processing. The
    /// bounded poll makes listener shutdown observable on platforms where
    /// closing a descriptor does not wake a blocking accept in another thread.
    fn acceptOne(self: *NativeServer) !std.Io.net.Stream {
        self.accept_mutex.lockUncancelable(self.io);
        defer self.accept_mutex.unlock(self.io);
        while (self.ready()) {
            var descriptors = [_]std.posix.pollfd{.{
                .fd = self.listener.socket.handle,
                .events = std.posix.POLL.IN | std.posix.POLL.ERR,
                .revents = 0,
            }};
            if (try std.posix.poll(&descriptors, 50) == 0) continue;
            if (!self.ready()) return error.ServerNotReady;
            if ((descriptors[0].revents & std.posix.POLL.IN) == 0) return error.ListenerPollFailed;
            return self.listener.accept(self.io);
        }
        return error.ServerNotReady;
    }

    fn serveWire(self: *NativeServer, allocator: std.mem.Allocator, wire: Wire) !void {
        defer wire.close();

        var connection = try ServerConnection.init(allocator, self.io, self.registry, self.streaming_registry, self.incremental_registry, self.options.limits, self.options.response_compression, self.options.cors, self.options.interceptors, self.options.stream_queue_capacity, self.options.max_concurrent_streams, self.options.peer_keepalive, self.options.protocol_policy);
        defer connection.deinit();
        connection.handler_executor = self.handler_executor;
        connection.call_counters = &self.call_counters;
        connection.causal = self.options.causal;
        const callbacks = try serverCallbacks();
        defer c.nghttp2_session_callbacks_del(callbacks);
        var maybe_session: ?*c.nghttp2_session = null;
        try checkNghttp(c.nghttp2_session_server_new(&maybe_session, callbacks, &connection));
        const session = maybe_session orelse return error.Http2InitializationFailed;
        defer c.nghttp2_session_del(session);
        const settings = serverSettings(self.options);
        try checkNghttp(c.nghttp2_submit_settings(session, c.NGHTTP2_FLAG_NONE, &settings, settings.len));
        try checkNghttp(c.nghttp2_session_set_local_window_size(session, c.NGHTTP2_FLAG_NONE, 0, @intCast(self.options.initial_connection_window_bytes)));
        try flushSession(session, wire);

        const buffer = try allocator.alloc(u8, self.options.limits.max_wire_read_bytes);
        defer allocator.free(buffer);
        // A reusable HTTP/2 server connection remains available between RPCs.
        // Connection rotation uses the two-phase graceful shutdown described
        // by RFC 9113: first advertise GOAWAY with the maximum stream ID so the
        // peer opens a replacement channel, accept frames already in flight
        // for one grace interval, then commit the actual last processed ID.
        const started_at = std.Io.Clock.Timestamp.now(self.io, .awake);
        var last_activity = started_at;
        var observed_completed_calls: usize = 0;
        var age_draining = false;
        var age_deadline: ?std.Io.Clock.Timestamp = null;
        while (true) {
            const now = std.Io.Clock.Timestamp.now(self.io, .awake);
            if (!age_draining) if (self.options.connection_max_age_millis) |maximum_age| {
                if (elapsedTimestampMillis(started_at, now) >= maximum_age) {
                    try checkNghttp(c.nghttp2_submit_goaway(session, c.NGHTTP2_FLAG_NONE, std.math.maxInt(i32), c.NGHTTP2_NO_ERROR, null, 0));
                    try flushSession(session, wire);
                    age_draining = true;
                    age_deadline = deadlineFromNow(self.io, self.options.connection_max_age_grace_millis);
                }
            };
            if (age_draining and (connection.streams.items.len == 0 or deadlineReached(self.io, age_deadline.?))) {
                const last_stream_id = c.nghttp2_session_get_last_proc_stream_id(session);
                try checkNghttp(c.nghttp2_submit_goaway(session, c.NGHTTP2_FLAG_NONE, last_stream_id, c.NGHTTP2_NO_ERROR, null, 0));
                flushSession(session, wire) catch {};
                break;
            }
            if (connection.streams.items.len == 0) if (self.options.connection_idle_timeout_millis) |idle_timeout| {
                if (elapsedTimestampMillis(last_activity, now) >= idle_timeout) {
                    const last_stream_id = c.nghttp2_session_get_last_proc_stream_id(session);
                    try checkNghttp(c.nghttp2_submit_goaway(session, c.NGHTTP2_FLAG_NONE, last_stream_id, c.NGHTTP2_NO_ERROR, null, 0));
                    flushSession(session, wire) catch {};
                    break;
                }
            };
            const dispatch_without_readiness = connection.hasAsyncWork() or connection.pending_wire.items.len != 0 or connection.parser_paused;
            if (!dispatch_without_readiness) {
                var descriptors = [_]std.posix.pollfd{.{
                    .fd = wire.socketHandle(),
                    .events = std.posix.POLL.IN | std.posix.POLL.ERR,
                    .revents = 0,
                }};
                if (try std.posix.poll(&descriptors, 10) == 0) continue;
                if ((descriptors[0].revents & (std.posix.POLL.IN | std.posix.POLL.ERR)) == 0) continue;
                last_activity = std.Io.Clock.Timestamp.now(self.io, .awake);
            }
            receiveServerEvent(session, &connection, wire, buffer) catch |err| switch (err) {
                error.ConnectionClosed => break,
                else => return connection.callback_error orelse err,
            };
            if (connection.close_after_flush) break;
            if (connection.completed_calls != observed_completed_calls) {
                observed_completed_calls = connection.completed_calls;
                last_activity = std.Io.Clock.Timestamp.now(self.io, .awake);
            }
            if (connection.completed_calls >= self.options.max_calls_per_connection and connection.streams.items.len == 0) {
                try checkNghttp(c.nghttp2_submit_goaway(session, c.NGHTTP2_FLAG_NONE, std.math.maxInt(i32), c.NGHTTP2_NO_ERROR, null, 0));
                try flushSession(session, wire);
                try sleepMilliseconds(self.io, self.options.goaway_grace_millis);
                const last_stream_id = c.nghttp2_session_get_last_proc_stream_id(session);
                try checkNghttp(c.nghttp2_submit_goaway(session, c.NGHTTP2_FLAG_NONE, last_stream_id, c.NGHTTP2_NO_ERROR, null, 0));
                flushSession(session, wire) catch {};
                break;
            }
        }
        if (connection.callback_error) |err| return err;
    }

    fn lockTls(self: *NativeServer) void {
        while (!self.tls_mutex.tryLock()) std.Thread.yield() catch {};
    }
};

/// Stable Channelz view over a live persistent client channel. The caller owns
/// the adapter and reference slices for at least as long as it is registered.
pub const PersistentChannelChannelz = struct {
    channel: *PersistentChannel,
    ref: Channelz.Ref,
    channel_refs: []const Channelz.Ref = &.{},
    subchannel_refs: []const Channelz.Ref = &.{},
    socket_refs: []const Channelz.Ref = &.{},

    pub fn channelzSnapshot(self: *PersistentChannelChannelz) Channelz.ChannelSnapshot {
        const snapshot_value = self.channel.snapshot();
        return .{
            .ref = self.ref,
            .state = channelzState(snapshot_value.connectivity.state),
            .target = self.channel.target_uri orelse "",
            .calls_started = channelzCounter(snapshot_value.calls_started),
            .calls_succeeded = channelzCounter(snapshot_value.calls_succeeded),
            .calls_failed = channelzCounter(snapshot_value.calls_failed),
            .channel_refs = self.channel_refs,
            .subchannel_refs = self.subchannel_refs,
            .socket_refs = self.socket_refs,
        };
    }
};

/// Optional standard subchannel projection for a resolved backend address.
pub const PersistentSubchannelChannelz = struct {
    channel: *PersistentChannel,
    ref: Channelz.Ref,
    target: []const u8,
    socket_refs: []const Channelz.Ref = &.{},

    pub fn channelzSnapshot(self: *PersistentSubchannelChannelz) Channelz.SubchannelSnapshot {
        const snapshot_value = self.channel.snapshot();
        return .{
            .ref = self.ref,
            .state = channelzState(snapshot_value.connectivity.state),
            .target = self.target,
            .calls_started = channelzCounter(snapshot_value.calls_started),
            .calls_succeeded = channelzCounter(snapshot_value.calls_succeeded),
            .calls_failed = channelzCounter(snapshot_value.calls_failed),
            .socket_refs = self.socket_refs,
        };
    }
};

/// Channelz socket projection for the current persistent HTTP/2 connection.
pub const PersistentSocketChannelz = struct {
    channel: *PersistentChannel,
    ref: Channelz.Ref,
    remote_name: []const u8 = "",

    pub fn channelzSnapshot(self: *PersistentSocketChannelz) Channelz.SocketSnapshot {
        const snapshot_value = self.channel.snapshot();
        return .{
            .ref = self.ref,
            .streams_started = channelzCounter(snapshot_value.calls_started),
            .streams_succeeded = channelzCounter(snapshot_value.calls_succeeded),
            .streams_failed = channelzCounter(snapshot_value.calls_failed),
            .keepalives_sent = channelzCounter(snapshot_value.keepalive_pings),
            .peer_max_concurrent_streams = @intCast(@min(self.channel.client_impl.options.max_concurrent_streams, std.math.maxInt(u32))),
            .remote_name = self.remote_name,
        };
    }
};

/// Stable Channelz view over a supervised native server.
pub const NativeServerChannelz = struct {
    server: *NativeServer,
    ref: Channelz.Ref,
    listen_socket_refs: []const Channelz.Ref = &.{},

    pub fn channelzSnapshot(self: *NativeServerChannelz) Channelz.ServerSnapshot {
        return .{
            .ref = self.ref,
            .calls_started = channelzCounter(self.server.call_counters.started.load(.acquire)),
            .calls_succeeded = channelzCounter(self.server.call_counters.succeeded.load(.acquire)),
            .calls_failed = channelzCounter(self.server.call_counters.failed.load(.acquire)),
            .listen_socket_refs = self.listen_socket_refs,
        };
    }
};

/// Channelz projection for a native server listening socket.
pub const NativeServerSocketChannelz = struct {
    server: *NativeServer,
    server_id: i64,
    ref: Channelz.Ref,
    name: []const u8 = "",

    pub fn channelzSnapshot(self: *NativeServerSocketChannelz) Channelz.SocketSnapshot {
        return .{
            .ref = self.ref,
            .server_id = self.server_id,
            .streams_started = channelzCounter(self.server.call_counters.started.load(.acquire)),
            .streams_succeeded = channelzCounter(self.server.call_counters.succeeded.load(.acquire)),
            .streams_failed = channelzCounter(self.server.call_counters.failed.load(.acquire)),
            .peer_max_concurrent_streams = @intCast(self.server.options.max_concurrent_streams),
            .remote_name = self.name,
        };
    }
};

fn channelzState(state: Channel.ConnectivityState) Channelz.State {
    return switch (state) {
        .idle => .idle,
        .connecting => .connecting,
        .ready => .ready,
        .transient_failure => .transient_failure,
        .shutdown => .shutdown,
    };
}

fn channelzCounter(value: anytype) i64 {
    return std.math.cast(i64, value) orelse std.math.maxInt(i64);
}

const WorkerContext = struct {
    server: *NativeServer,
    completed: usize = 0,
    failed: usize = 0,

    fn run(self: *WorkerContext) void {
        while (self.server.ready()) {
            self.server.serveOne() catch {
                if (!self.server.ready()) break;
                self.failed += 1;
                continue;
            };
            self.completed += 1;
        }
    }
};

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

fn awakeMillis(io: std.Io) u64 {
    const nanoseconds = std.Io.Clock.Timestamp.now(io, .awake).raw.nanoseconds;
    return @intCast(@max(@divTrunc(nanoseconds, std.time.ns_per_ms), 0));
}

fn elapsedTimestampMillis(start: std.Io.Clock.Timestamp, end: std.Io.Clock.Timestamp) u64 {
    const elapsed = start.durationTo(end).raw.toMilliseconds();
    return @intCast(@max(elapsed, 0));
}

fn remainingDeadlineMillis(io: std.Io, deadline: std.Io.Clock.Timestamp) !u64 {
    const now = std.Io.Clock.Timestamp.now(io, deadline.clock);
    const remaining_ns = deadline.raw.nanoseconds - now.raw.nanoseconds;
    if (remaining_ns <= 0) return error.DeadlineExceeded;
    const rounded = @divTrunc(remaining_ns + std.time.ns_per_ms - 1, std.time.ns_per_ms);
    return @intCast(@max(@as(i96, 1), rounded));
}

test "native gRPC adapter exposes an HTTP/2 client and server" {
    try capability.validate();
    try server_capability.validate();
    try persistent_channel_capability.validate();
    try incremental_streaming_capability.validate();
    try connect_server_capability.validate();
    try connect_client_capability.validate();
    try generated_bindings_capability.validate();
    try cloud_run_capability.validate();
    try std.testing.expect(@hasDecl(@This(), "NativeClient"));
    try std.testing.expect(@hasDecl(@This(), "NativeServer"));
    std.testing.refAllDecls(StandardServices);
    std.testing.refAllDecls(Iap);
    std.testing.refAllDecls(Oidc);
    std.testing.refAllDecls(Otlp);
    std.testing.refAllDecls(Channel);
    std.testing.refAllDecls(Channelz);
    std.testing.refAllDecls(Credentials);
}

test "native server exposes supervised readiness and graceful shutdown" {
    try std.testing.expect(@hasDecl(NativeServer, "serve"));
    try std.testing.expect(@hasDecl(NativeServer, "ready"));
    try std.testing.expect(@hasDecl(NativeServer, "shutdown"));
}

test "live Channelz adapters expose persistent channel and native server counters" {
    var channel = try PersistentChannel.init(std.testing.allocator, std.testing.io, .{
        .host = "127.0.0.1",
        .port = 1,
        .target_uri = "direct:///127.0.0.1:1",
    });
    defer channel.deinit();
    channel.calls_started = 5;
    channel.calls_succeeded = 4;
    channel.calls_failed = 1;
    var channel_source = PersistentChannelChannelz{
        .channel = &channel,
        .ref = .{ .id = 11, .name = "orders" },
    };
    const channel_snapshot = channel_source.channelzSnapshot();
    try std.testing.expectEqual(@as(i64, 5), channel_snapshot.calls_started);
    try std.testing.expectEqual(@as(i64, 4), channel_snapshot.calls_succeeded);
    try std.testing.expectEqual(Channelz.State.idle, channel_snapshot.state);

    var registry = Grpc.Registry.init(std.testing.allocator);
    defer registry.deinit();
    var maybe_server: ?NativeServer = null;
    var port: u16 = 29_300;
    while (port < 29_350) : (port += 1) {
        maybe_server = NativeServer.init(std.testing.allocator, std.testing.io, .{ .port = port }, &registry) catch |err| switch (err) {
            error.AddressInUse => continue,
            else => return err,
        };
        break;
    }
    if (maybe_server == null) return error.NoChannelzTestPort;
    var server = maybe_server.?;
    defer server.deinit();
    server.call_counters.started.store(8, .release);
    server.call_counters.succeeded.store(7, .release);
    server.call_counters.failed.store(1, .release);
    const sockets = [_]Channelz.Ref{.{ .id = 13, .name = "listener" }};
    var server_source = NativeServerChannelz{
        .server = &server,
        .ref = .{ .id = 12, .name = "api" },
        .listen_socket_refs = &sockets,
    };
    const server_snapshot = server_source.channelzSnapshot();
    try std.testing.expectEqual(@as(i64, 8), server_snapshot.calls_started);
    try std.testing.expectEqual(@as(i64, 7), server_snapshot.calls_succeeded);
    try std.testing.expectEqual(@as(usize, 1), server_snapshot.listen_socket_refs.len);
}

test "native server retires idle and maximum-age connections with GOAWAY" {
    var registry = Grpc.Registry.init(std.testing.allocator);
    defer registry.deinit();
    const Policy = struct {
        idle: ?u64,
        age: ?u64,
    };
    for ([_]Policy{
        .{ .idle = 20, .age = null },
        .{ .idle = null, .age = 20 },
    }, 0..) |policy, case_index| {
        var maybe_server: ?NativeServer = null;
        var port: u16 = @intCast(29_700 + case_index * 20);
        const maximum_port = port + 20;
        while (port < maximum_port) : (port += 1) {
            maybe_server = NativeServer.init(std.testing.allocator, std.testing.io, .{
                .port = port,
                .connection_idle_timeout_millis = policy.idle,
                .connection_max_age_millis = policy.age,
                .connection_max_age_grace_millis = 5,
            }, &registry) catch |err| switch (err) {
                error.AddressInUse => continue,
                else => return err,
            };
            break;
        }
        if (maybe_server == null) return error.NoLifecyclePolicyPort;
        var server = maybe_server.?;
        defer server.deinit();
        const Context = struct {
            server: *NativeServer,
            failure: ?anyerror = null,
            fn run(self: *@This()) void {
                self.server.serveOne() catch |err| {
                    self.failure = err;
                };
            }
        };
        var context = Context{ .server = &server };
        const thread = try std.Thread.spawn(.{}, Context.run, .{&context});
        const address = try std.Io.net.IpAddress.resolve(std.testing.io, "127.0.0.1", port);
        var stream = try address.connect(std.testing.io, .{ .mode = .stream });
        thread.join();
        stream.close(std.testing.io);
        if (context.failure) |err| return err;
        try std.testing.expectEqual(@as(usize, 0), server.activeConnections());
    }
}

test "typed protobuf adapter owns encoded and decoded messages" {
    const Sample = struct {
        value: u32 = 0,

        pub fn encode(self: @This(), writer: *std.Io.Writer, _: std.mem.Allocator) !void {
            try writer.writeByte(@intCast(self.value));
        }

        pub fn decode(reader: *std.Io.Reader, _: std.mem.Allocator) !@This() {
            return .{ .value = try reader.takeByte() };
        }

        pub fn deinit(_: *@This(), _: std.mem.Allocator) void {}
    };

    const encoded = try Typed.encodeAlloc(std.testing.allocator, Sample{ .value = 42 });
    defer std.testing.allocator.free(encoded);
    var decoded = try Typed.decodeAlloc(Sample, std.testing.allocator, encoded);
    defer Typed.deinitMessage(Sample, std.testing.allocator, &decoded);
    try std.testing.expectEqual(@as(u32, 42), decoded.value);
}

test "generated proto3 contract round trips rich messages and exposes every RPC shape" {
    var tags: std.ArrayList([]const u8) = .empty;
    defer tags.deinit(std.testing.allocator);
    try tags.append(std.testing.allocator, "production");
    var counters: std.ArrayList(ConformanceProto.UnaryRequest.CountersEntry) = .empty;
    defer counters.deinit(std.testing.allocator);
    try counters.append(std.testing.allocator, .{ .key = "calls", .value = 7 });
    const request = ConformanceProto.UnaryRequest{
        .id = "request-42",
        .sequence = 42,
        .payload = "payload",
        .tags = tags,
        .counters = counters,
        .note = "generated",
        .nested = .{ .label = "nested" },
        .state = .EXAMPLE_STATE_READY,
        .selector = .{ .number = 99 },
    };
    const encoded = try Typed.encodeAlloc(std.testing.allocator, request);
    defer std.testing.allocator.free(encoded);
    var decoded = try Typed.decodeAlloc(ConformanceProto.UnaryRequest, std.testing.allocator, encoded);
    defer decoded.deinit(std.testing.allocator);
    try std.testing.expectEqualStrings("request-42", decoded.id);
    try std.testing.expectEqual(@as(i64, 42), decoded.sequence);
    try std.testing.expectEqualStrings("production", decoded.tags.items[0]);
    try std.testing.expectEqualStrings("calls", decoded.counters.items[0].key);
    try std.testing.expectEqual(@as(u64, 99), decoded.selector.?.number);

    const Service = ConformanceProto.ConformanceService(struct {}, error{Failed});
    try std.testing.expect(@hasField(Service, "Unary"));
    try std.testing.expect(@hasField(Service, "ClientStream"));
    try std.testing.expect(@hasField(Service, "ServerStream"));
    try std.testing.expect(@hasField(Service, "BidiStream"));
}

test "native plaintext HTTP/2 client and server interoperate over loopback" {
    const Echo = struct {
        pub fn invoke(_: *@This(), allocator: std.mem.Allocator, request: Grpc.UnaryRequest) anyerror!Grpc.UnaryResponse {
            return Grpc.UnaryResponse.initAlloc(allocator, request.payload, .ok());
        }
    };
    var echo = Echo{};
    var registry = Grpc.Registry.init(std.testing.allocator);
    defer registry.deinit();
    try registry.register(.{ .service = "example.v1.Echo", .method = "Say", .handler = Grpc.UnaryHandler.from(Echo, &echo) });

    var server: ?NativeServer = null;
    var port: u16 = 28_000;
    while (port < 28_100) : (port += 1) {
        server = NativeServer.init(std.testing.allocator, std.testing.io, .{ .port = port }, &registry) catch |err| switch (err) {
            error.AddressInUse => continue,
            else => return err,
        };
        break;
    }
    if (server == null) return error.NoLoopbackPort;
    defer server.?.deinit();

    const Context = struct {
        server: *NativeServer,
        failure: ?anyerror = null,
        fn run(self: *@This()) void {
            self.server.serveOne() catch |err| {
                self.failure = err;
            };
        }
    };
    var context = Context{ .server = &server.? };
    const thread = try std.Thread.spawn(.{}, Context.run, .{&context});
    var client = try NativeClient.init(std.testing.allocator, std.testing.io, .{ .port = port });
    try std.testing.expectError(error.TransportNotQualified, Grpc.requireQualified(client.transport().capabilities));
    const response_result = client.invokeAlloc(std.testing.allocator, .{
        .authority = "localhost",
        .service = "example.v1.Echo",
        .method = "Say",
        .payload = "native",
        .timeout_millis = 1000,
    }, .{});
    thread.join();
    if (context.failure) |err| return err;
    var response = try response_result;
    defer response.deinit();
    try std.testing.expectEqualStrings("native", response.payload);
    try std.testing.expect(response.status.isOk());
}

test "native transport preserves metadata rich status and server deadline" {
    const Handler = struct {
        saw_ascii: bool = false,
        saw_binary: bool = false,
        timeout_millis: u64 = 0,

        pub fn invoke(self: *@This(), allocator: std.mem.Allocator, request: Grpc.UnaryRequest) anyerror!Grpc.UnaryResponse {
            self.timeout_millis = request.timeout_millis;
            for (request.metadata) |entry| {
                if (std.mem.eql(u8, entry.name, "request-id") and std.mem.eql(u8, entry.value, "req-42")) self.saw_ascii = true;
                if (std.mem.eql(u8, entry.name, "trace-bin") and std.mem.eql(u8, entry.value, &.{ 0x00, 0xff })) self.saw_binary = true;
            }
            return Grpc.UnaryResponse.initFullAlloc(allocator, .{
                .payload = "",
                .initial_metadata = &.{.{ .name = "server-version", .value = "v2" }},
                .trailing_metadata = &.{
                    .{ .name = "quota", .value = "low" },
                    .{ .name = "debug-bin", .value = &.{ 0x01, 0xfe }, .kind = .binary },
                },
                .status = .{
                    .code = .resource_exhausted,
                    .message = "quota 100% exhausted",
                    .details_bin = &.{ 0x08, 0x08 },
                },
            });
        }
    };
    var handler = Handler{};
    var registry = Grpc.Registry.init(std.testing.allocator);
    defer registry.deinit();
    try registry.register(.{
        .service = "example.v1.Metadata",
        .method = "Inspect",
        .handler = Grpc.UnaryHandler.from(Handler, &handler),
    });

    var maybe_server: ?NativeServer = null;
    var port: u16 = 27_900;
    while (port < 28_000) : (port += 1) {
        maybe_server = NativeServer.init(std.testing.allocator, std.testing.io, .{ .port = port }, &registry) catch |err| switch (err) {
            error.AddressInUse => continue,
            else => return err,
        };
        break;
    }
    if (maybe_server == null) return error.NoMetadataLoopbackPort;
    var server = maybe_server.?;
    defer server.deinit();
    const Context = struct {
        server: *NativeServer,
        failure: ?anyerror = null,
        fn run(self: *@This()) void {
            self.server.serveOne() catch |err| {
                self.failure = err;
            };
        }
    };
    var context = Context{ .server = &server };
    const thread = try std.Thread.spawn(.{}, Context.run, .{&context});
    var client = try NativeClient.init(std.testing.allocator, std.testing.io, .{ .port = port });
    const response_result = client.invokeAlloc(std.testing.allocator, .{
        .authority = "localhost",
        .service = "example.v1.Metadata",
        .method = "Inspect",
        .payload = "",
        .metadata = &.{
            .{ .name = "request-id", .value = "req-42" },
            .{ .name = "trace-bin", .value = &.{ 0x00, 0xff }, .kind = .binary },
        },
        .timeout_millis = 275,
    }, .{});
    thread.join();
    if (context.failure) |err| return err;
    var response = try response_result;
    defer response.deinit();

    try std.testing.expect(handler.saw_ascii);
    try std.testing.expect(handler.saw_binary);
    try std.testing.expect(handler.timeout_millis <= 275 and handler.timeout_millis > 0);
    try std.testing.expectEqual(Grpc.Code.resource_exhausted, response.status.code);
    try std.testing.expectEqualStrings("quota 100% exhausted", response.status.message);
    try std.testing.expectEqualSlices(u8, &.{ 0x08, 0x08 }, response.status.details_bin);
    try std.testing.expectEqualStrings("v2", response.initial_metadata[0].value);
    try std.testing.expectEqualStrings("low", response.trailing_metadata[0].value);
    try std.testing.expectEqualSlices(u8, &.{ 0x01, 0xfe }, response.trailing_metadata[1].value);
}

test "supervisor accepts concurrent connections and drains without leaked sockets" {
    const Echo = struct {
        pub fn invoke(_: *@This(), allocator: std.mem.Allocator, request: Grpc.UnaryRequest) anyerror!Grpc.UnaryResponse {
            return Grpc.UnaryResponse.initAlloc(allocator, request.payload, .ok());
        }
    };
    var echo = Echo{};
    var registry = Grpc.Registry.init(std.testing.allocator);
    defer registry.deinit();
    try registry.register(.{ .service = "example.v1.Echo", .method = "Say", .handler = Grpc.UnaryHandler.from(Echo, &echo) });
    var maybe_server: ?NativeServer = null;
    var port: u16 = 28_500;
    while (port < 28_600) : (port += 1) {
        maybe_server = NativeServer.init(std.testing.allocator, std.testing.io, .{
            .port = port,
            .max_connections = 2,
        }, &registry) catch |err| switch (err) {
            error.AddressInUse => continue,
            else => return err,
        };
        break;
    }
    if (maybe_server == null) return error.NoSupervisorLoopbackPort;
    var server = maybe_server.?;
    defer server.deinit();

    const ServeContext = struct {
        server: *NativeServer,
        report: ?SupervisorReport = null,
        failure: ?anyerror = null,
        fn run(self: *@This()) void {
            self.report = self.server.serve() catch |err| {
                self.failure = err;
                return;
            };
        }
    };
    var serve_context = ServeContext{ .server = &server };
    const server_thread = try std.Thread.spawn(.{}, ServeContext.run, .{&serve_context});

    const ClientContext = struct {
        port: u16,
        payload: []const u8,
        failure: ?anyerror = null,
        fn run(self: *@This()) void {
            var client = NativeClient.init(std.heap.page_allocator, std.testing.io, .{ .port = self.port }) catch |err| {
                self.failure = err;
                return;
            };
            var response = client.invokeAlloc(std.heap.page_allocator, .{
                .authority = "localhost",
                .service = "example.v1.Echo",
                .method = "Say",
                .payload = self.payload,
                .timeout_millis = 1_000,
            }, .{}) catch |err| {
                self.failure = err;
                return;
            };
            defer response.deinit();
            if (!std.mem.eql(u8, response.payload, self.payload)) self.failure = error.UnexpectedPayload;
        }
    };
    var clients = [_]ClientContext{
        .{ .port = port, .payload = "first" },
        .{ .port = port, .payload = "second" },
    };
    const first = try std.Thread.spawn(.{}, ClientContext.run, .{&clients[0]});
    const second = try std.Thread.spawn(.{}, ClientContext.run, .{&clients[1]});
    first.join();
    second.join();
    for (clients) |client_context| if (client_context.failure) |err| return err;
    const shutdown = try server.shutdown(.{});
    server_thread.join();
    if (serve_context.failure) |err| return err;
    try std.testing.expect(shutdown.drained);
    try std.testing.expectEqual(@as(usize, 0), shutdown.active_remaining);
    try std.testing.expectEqual(@as(usize, 2), serve_context.report.?.completed);
    try std.testing.expectEqual(@as(usize, 0), serve_context.report.?.failed);
}

test "supervisor wakes idle accept workers during shutdown" {
    var registry = Grpc.Registry.init(std.testing.allocator);
    defer registry.deinit();
    var maybe_server: ?NativeServer = null;
    var port: u16 = 28_600;
    while (port < 28_700) : (port += 1) {
        maybe_server = NativeServer.init(std.testing.allocator, std.testing.io, .{
            .port = port,
            .max_connections = 4,
        }, &registry) catch |err| switch (err) {
            error.AddressInUse => continue,
            else => return err,
        };
        break;
    }
    if (maybe_server == null) return error.NoIdleShutdownLoopbackPort;
    var server = maybe_server.?;
    defer server.deinit();

    const ServeContext = struct {
        server: *NativeServer,
        result: ?SupervisorReport = null,
        failure: ?anyerror = null,

        fn run(self: *@This()) void {
            self.result = self.server.serve() catch |err| {
                self.failure = err;
                return;
            };
        }
    };
    var context = ServeContext{ .server = &server };
    const thread = try std.Thread.spawn(.{}, ServeContext.run, .{&context});
    try sleepMilliseconds(std.testing.io, 25);
    const shutdown = try server.shutdown(.{ .deadline_ms = 250, .force_close_wait_ms = 250 });
    thread.join();

    if (context.failure) |err| return err;
    try std.testing.expect(context.result != null);
    try std.testing.expectEqual(@as(usize, 0), context.result.?.accepted);
    try std.testing.expect(shutdown.drained);
    try std.testing.expectEqual(@as(usize, 0), shutdown.active_remaining);
}

test "persistent channel reuses HTTP/2 and reconnects after graceful GOAWAY" {
    try std.testing.expect(@hasDecl(@This(), "PersistentChannel"));
    try std.testing.expect(@hasDecl(@This(), "ChannelPool"));
    try std.testing.expect(@hasDecl(ChannelPool, "invokeStreamingAlloc"));
    try std.testing.expect(@hasDecl(ChannelPool, "openIncrementalStream"));
    try std.testing.expect(@hasDecl(ChannelPool, "snapshot"));
    const Echo = struct {
        pub fn invoke(_: *@This(), allocator: std.mem.Allocator, request: Grpc.UnaryRequest) anyerror!Grpc.UnaryResponse {
            return Grpc.UnaryResponse.initAlloc(allocator, request.payload, .ok());
        }
    };
    var echo = Echo{};
    var registry = Grpc.Registry.init(std.testing.allocator);
    defer registry.deinit();
    try registry.register(.{ .service = "example.v1.Echo", .method = "Say", .handler = Grpc.UnaryHandler.from(Echo, &echo) });
    var maybe_server: ?NativeServer = null;
    var port: u16 = 28_600;
    while (port < 28_700) : (port += 1) {
        maybe_server = NativeServer.init(std.testing.allocator, std.testing.io, .{
            .port = port,
            .max_calls_per_connection = 2,
        }, &registry) catch |err| switch (err) {
            error.AddressInUse => continue,
            else => return err,
        };
        break;
    }
    if (maybe_server == null) return error.NoPersistentChannelPort;
    var server = maybe_server.?;
    defer server.deinit();
    const ServeContext = struct {
        server: *NativeServer,
        failure: ?anyerror = null,
        fn run(self: *@This()) void {
            for (0..2) |_| self.server.serveOne() catch |err| {
                self.failure = err;
                return;
            };
        }
    };
    var serve_context = ServeContext{ .server = &server };
    const server_thread = try std.Thread.spawn(.{}, ServeContext.run, .{&serve_context});
    var channel = try PersistentChannel.init(std.testing.allocator, std.testing.io, .{ .port = port });
    defer channel.deinit();
    for ([_][]const u8{ "first", "second", "after-goaway", "reused-after-goaway" }) |payload| {
        var response = try channel.invokeAlloc(std.testing.allocator, .{
            .authority = "localhost",
            .service = "example.v1.Echo",
            .method = "Say",
            .payload = payload,
            .timeout_millis = 1_000,
            .idempotency = .idempotent,
        }, .{});
        defer response.deinit();
        try std.testing.expectEqualStrings(payload, response.payload);
    }
    server_thread.join();
    if (serve_context.failure) |err| return err;
    const snapshot = channel.snapshot();
    try std.testing.expectEqual(@as(usize, 4), snapshot.calls);
    try std.testing.expectEqual(@as(usize, 2), snapshot.connections_opened);
    try std.testing.expectEqual(@as(usize, 1), snapshot.reconnects);
}

test "persistent channel carries unary and streaming RPCs over one HTTP2 connection" {
    const Handler = struct {
        pub fn invoke(_: *@This(), allocator: std.mem.Allocator, request: Grpc.UnaryRequest) anyerror!Grpc.UnaryResponse {
            return Grpc.UnaryResponse.initAlloc(allocator, request.payload, .ok());
        }

        pub fn invokeStreaming(_: *@This(), allocator: std.mem.Allocator, request: Grpc.StreamingRequest) anyerror!Grpc.StreamingResponse {
            return Grpc.StreamingResponse.initAlloc(allocator, request.messages, .ok());
        }
    };
    var handler = Handler{};
    var unary = Grpc.Registry.init(std.testing.allocator);
    defer unary.deinit();
    try unary.register(.{ .service = "example.v1.Mixed", .method = "Unary", .handler = Grpc.UnaryHandler.from(Handler, &handler) });
    var streaming = Grpc.StreamingRegistry.init(std.testing.allocator);
    defer streaming.deinit();
    try streaming.register("example.v1.Mixed", "Bidi", .bidirectional_streaming, Grpc.StreamingHandler.from(Handler, &handler));

    var maybe_server: ?NativeServer = null;
    var port: u16 = 29_300;
    while (port < 29_400) : (port += 1) {
        maybe_server = NativeServer.initStreaming(std.testing.allocator, std.testing.io, .{
            .port = port,
            .max_calls_per_connection = 2,
        }, &unary, &streaming) catch |err| switch (err) {
            error.AddressInUse => continue,
            else => return err,
        };
        break;
    }
    if (maybe_server == null) return error.NoPersistentStreamingPort;
    var server = maybe_server.?;
    defer server.deinit();
    const ServeContext = struct {
        server: *NativeServer,
        failure: ?anyerror = null,
        fn run(self: *@This()) void {
            self.server.serveOne() catch |err| {
                self.failure = err;
            };
        }
    };
    var serve_context = ServeContext{ .server = &server };
    const thread = try std.Thread.spawn(.{}, ServeContext.run, .{&serve_context});
    var channel = try PersistentChannel.init(std.testing.allocator, std.testing.io, .{
        .port = port,
        .keepalive_interval_millis = null,
    });
    defer channel.deinit();
    var unary_response = try channel.invokeAlloc(std.testing.allocator, .{
        .authority = "localhost",
        .service = "example.v1.Mixed",
        .method = "Unary",
        .payload = "one",
        .timeout_millis = 1_000,
    }, .{});
    defer unary_response.deinit();
    var streaming_response = try channel.invokeStreamingAlloc(std.testing.allocator, .{
        .authority = "localhost",
        .service = "example.v1.Mixed",
        .method = "Bidi",
        .messages = &.{ "two", "three" },
        .timeout_millis = 1_000,
        .shape = .bidirectional_streaming,
    }, .{});
    defer streaming_response.deinit();
    thread.join();
    if (serve_context.failure) |err| return err;
    try std.testing.expectEqualStrings("one", unary_response.payload);
    try std.testing.expectEqual(@as(usize, 2), streaming_response.messages.len);
    try std.testing.expectEqualStrings("two", streaming_response.messages[0]);
    try std.testing.expectEqual(@as(usize, 1), channel.snapshot().connections_opened);
}

test "persistent channel applies service-config retries and publishes connectivity" {
    const Handler = struct {
        calls: usize = 0,
        saw_credentials: bool = false,

        pub fn invoke(self: *@This(), allocator: std.mem.Allocator, request: Grpc.UnaryRequest) anyerror!Grpc.UnaryResponse {
            self.calls += 1;
            for (request.metadata) |entry| if (std.mem.eql(u8, entry.name, "authorization") and std.mem.eql(u8, entry.value, "Bearer service-token")) {
                self.saw_credentials = entry.sensitive;
            };
            if (self.calls == 1) return Grpc.UnaryResponse.initFullAlloc(allocator, .{
                .status = .{ .code = .unavailable, .message = "retry me" },
                .retry_pushback_millis = 1,
            });
            return Grpc.UnaryResponse.initAlloc(allocator, request.payload, .ok());
        }
    };
    var handler = Handler{};
    var registry = Grpc.Registry.init(std.testing.allocator);
    defer registry.deinit();
    try registry.register(.{
        .service = "orders.v1.Orders",
        .method = "Get",
        .handler = Grpc.UnaryHandler.from(Handler, &handler),
    });
    var maybe_server: ?NativeServer = null;
    var port: u16 = 29_600;
    while (port < 29_700) : (port += 1) {
        maybe_server = NativeServer.init(std.testing.allocator, std.testing.io, .{ .port = port }, &registry) catch |err| switch (err) {
            error.AddressInUse => continue,
            else => return err,
        };
        break;
    }
    if (maybe_server == null) return error.NoServiceConfigPort;
    var server = maybe_server.?;
    defer server.deinit();
    const ServeContext = struct {
        server: *NativeServer,
        failure: ?anyerror = null,
        fn run(self: *@This()) void {
            self.server.serveOne() catch |err| {
                self.failure = err;
            };
        }
    };
    var serve_context = ServeContext{ .server = &server };
    const server_thread = try std.Thread.spawn(.{}, ServeContext.run, .{&serve_context});
    const config =
        \\{"retryThrottling":{"maxTokens":4,"tokenRatio":0.5},"methodConfig":[{"name":[{"service":"orders.v1.Orders","method":"Get"}],"retryPolicy":{"maxAttempts":3,"initialBackoff":"0.001s","maxBackoff":"0.002s","backoffMultiplier":2,"retryableStatusCodes":["UNAVAILABLE"]}}]}
    ;
    const StaticCredentials = struct {
        pub fn metadataAlloc(_: *@This(), allocator: std.mem.Allocator, _: Credentials.Context) !Grpc.MetadataBlock {
            const entries = try allocator.alloc(Grpc.Metadata, 1);
            errdefer allocator.free(entries);
            const name = try allocator.dupe(u8, "authorization");
            errdefer allocator.free(name);
            const value = try allocator.dupe(u8, "Bearer service-token");
            entries[0] = .{ .name = name, .value = value, .sensitive = true };
            return .{ .allocator = allocator, .entries = entries };
        }
    };
    var static_credentials = StaticCredentials{};
    const target_uri = try std.fmt.allocPrint(std.testing.allocator, "dns:///localhost:{d}", .{port});
    defer std.testing.allocator.free(target_uri);
    var channel = try PersistentChannel.init(std.testing.allocator, std.testing.io, .{
        .target_uri = target_uri,
        .service_config_json = config,
        .credentials = Credentials.Provider.from(StaticCredentials, &static_credentials),
    });
    var response = try channel.invokeAlloc(std.testing.allocator, .{
        .authority = "localhost",
        .service = "orders.v1.Orders",
        .method = "Get",
        .payload = "order-42",
        .timeout_millis = 1_000,
        .idempotency = .idempotent,
    }, .{});
    defer response.deinit();
    try std.testing.expectEqualStrings("order-42", response.payload);
    try std.testing.expectEqual(@as(usize, 2), handler.calls);
    try std.testing.expect(handler.saw_credentials);
    const snapshot = channel.snapshot();
    try std.testing.expectEqual(Channel.ConnectivityState.ready, snapshot.connectivity.state);
    try std.testing.expect(snapshot.connectivity.generation >= 2);
    try std.testing.expectEqual(@as(usize, 1), snapshot.resolved_addresses);
    try std.testing.expectEqual(@as(?u32, 3_500), snapshot.retry_tokens_milli);
    channel.deinit();
    server_thread.join();
    if (serve_context.failure) |err| return err;
}

test "persistent channel hedges only explicitly non-mutating methods" {
    const Handler = struct {
        calls: std.atomic.Value(usize) = .init(0),

        pub fn invoke(self: *@This(), allocator: std.mem.Allocator, request: Grpc.UnaryRequest) anyerror!Grpc.UnaryResponse {
            const call = self.calls.fetchAdd(1, .acq_rel) + 1;
            if (call == 1) return Grpc.UnaryResponse.initAlloc(allocator, "", .{ .code = .unavailable, .message = "hedge me" });
            return Grpc.UnaryResponse.initAlloc(allocator, request.payload, .ok());
        }
    };
    var handler = Handler{};
    var registry = Grpc.Registry.init(std.testing.allocator);
    defer registry.deinit();
    try registry.register(.{
        .service = "orders.v1.Orders",
        .method = "Get",
        .handler = Grpc.UnaryHandler.from(Handler, &handler),
    });
    var maybe_server: ?NativeServer = null;
    var port: u16 = 29_700;
    while (port < 29_800) : (port += 1) {
        maybe_server = NativeServer.init(std.testing.allocator, std.testing.io, .{ .port = port }, &registry) catch |err| switch (err) {
            error.AddressInUse => continue,
            else => return err,
        };
        break;
    }
    if (maybe_server == null) return error.NoHedgingPort;
    var server = maybe_server.?;
    defer server.deinit();
    const ServeContext = struct {
        server: *NativeServer,
        failure: ?anyerror = null,
        fn run(self: *@This()) void {
            self.server.serveOne() catch |err| {
                self.failure = err;
            };
        }
    };
    var serve_context = ServeContext{ .server = &server };
    const server_thread = try std.Thread.spawn(.{}, ServeContext.run, .{&serve_context});
    const config =
        \\{"methodConfig":[{"name":[{"service":"orders.v1.Orders","method":"Get"}],"hedgingPolicy":{"maxAttempts":2,"hedgingDelay":"0s","nonFatalStatusCodes":["UNAVAILABLE"]}}]}
    ;
    var channel = try PersistentChannel.init(std.testing.allocator, std.testing.io, .{
        .port = port,
        .service_config_json = config,
        .keepalive_interval_millis = null,
    });
    var response = try channel.invokeAlloc(std.testing.allocator, .{
        .authority = "localhost",
        .service = "orders.v1.Orders",
        .method = "Get",
        .payload = "order-hedged",
        .timeout_millis = 1_000,
        .idempotency = .no_side_effects,
    }, .{});
    const response_ok = response.status.code == .ok and std.mem.eql(u8, response.payload, "order-hedged");
    response.deinit();
    const calls = handler.calls.load(.acquire);
    channel.deinit();
    server_thread.join();
    if (serve_context.failure) |err| return err;
    try std.testing.expect(response_ok);
    try std.testing.expectEqual(@as(usize, 2), calls);
}

test "service-config client Health Watch gates application calls until serving" {
    const Handler = struct {
        calls: std.atomic.Value(usize) = .init(0),

        pub fn invoke(self: *@This(), allocator: std.mem.Allocator, request: Grpc.UnaryRequest) anyerror!Grpc.UnaryResponse {
            _ = self.calls.fetchAdd(1, .acq_rel);
            return Grpc.UnaryResponse.initAlloc(allocator, request.payload, .ok());
        }
    };
    var handler = Handler{};
    var unary = Grpc.Registry.init(std.testing.allocator);
    defer unary.deinit();
    try unary.register(.{
        .service = "orders.v1.Orders",
        .method = "Get",
        .handler = Grpc.UnaryHandler.from(Handler, &handler),
    });
    var streaming = Grpc.StreamingRegistry.init(std.testing.allocator);
    defer streaming.deinit();
    var incremental = Incremental.Registry.init(std.testing.allocator);
    defer incremental.deinit();
    var health = Grpc.HealthRegistry.init(std.testing.allocator);
    defer health.deinit();
    try health.set("orders.v1.Orders", .not_serving);
    const names = [_][]const u8{ "orders.v1.Orders", "grpc.health.v1.Health" };
    var services = StandardServices.Services{ .health = &health, .service_names = &names };
    try services.install(&unary, &streaming);
    try services.installIncremental(&incremental);
    var maybe_server: ?NativeServer = null;
    var port: u16 = 29_800;
    while (port < 29_900) : (port += 1) {
        maybe_server = NativeServer.initStreaming(std.testing.allocator, std.testing.io, .{ .port = port }, &unary, &streaming) catch |err| switch (err) {
            error.AddressInUse => continue,
            else => return err,
        };
        break;
    }
    if (maybe_server == null) return error.NoClientHealthWatchPort;
    var server = maybe_server.?;
    defer server.deinit();
    try server.installIncremental(&incremental);
    const ServeContext = struct {
        server: *NativeServer,
        failure: ?anyerror = null,
        fn run(self: *@This()) void {
            self.server.serveOne() catch |err| {
                self.failure = err;
            };
        }
    };
    var serve_context = ServeContext{ .server = &server };
    const server_thread = try std.Thread.spawn(.{}, ServeContext.run, .{&serve_context});
    const config =
        \\{"healthCheckConfig":{"serviceName":"orders.v1.Orders"}}
    ;
    var channel = try PersistentChannel.init(std.testing.allocator, std.testing.io, .{
        .port = port,
        .service_config_json = config,
        .keepalive_interval_millis = null,
    });
    const CallContext = struct {
        channel: *PersistentChannel,
        response_ok: bool = false,
        failure: ?anyerror = null,
        fn run(self: *@This()) void {
            var response = self.channel.invokeAlloc(std.heap.smp_allocator, .{
                .authority = "localhost",
                .service = "orders.v1.Orders",
                .method = "Get",
                .payload = "healthy-order",
                .timeout_millis = 2_000,
            }, .{}) catch |err| {
                self.failure = err;
                return;
            };
            defer response.deinit();
            self.response_ok = response.status.code == .ok and std.mem.eql(u8, response.payload, "healthy-order");
        }
    };
    var call_context = CallContext{ .channel = &channel };
    const call_thread = try std.Thread.spawn(.{}, CallContext.run, .{&call_context});
    try sleepMilliseconds(std.testing.io, 25);
    const gated_before_serving = handler.calls.load(.acquire) == 0;
    try health.set("orders.v1.Orders", .serving);
    call_thread.join();
    const application_calls = handler.calls.load(.acquire);
    channel.deinit();
    server_thread.join();
    if (serve_context.failure) |err| return err;
    if (call_context.failure) |err| return err;
    try std.testing.expect(gated_before_serving);
    try std.testing.expect(call_context.response_ok);
    try std.testing.expectEqual(@as(usize, 1), application_calls);
}

test "cancelling one persistent stream sends RST_STREAM without poisoning sibling calls" {
    const Handler = struct {
        pub fn invoke(_: *@This(), allocator: std.mem.Allocator, request: Grpc.UnaryRequest) anyerror!Grpc.UnaryResponse {
            return Grpc.UnaryResponse.initAlloc(allocator, request.payload, .ok());
        }

        pub fn runIncremental(_: *@This(), call: *Incremental.Call) anyerror!Grpc.Status {
            while (try call.receive()) |value| {
                var message = value;
                message.deinit();
            }
            while (!call.isCancelled()) try call.sleep(1);
            return .{ .code = .cancelled, .message = "client cancelled" };
        }
    };
    var handler = Handler{};
    var unary = Grpc.Registry.init(std.testing.allocator);
    defer unary.deinit();
    try unary.register(.{ .service = "example.v1.Cancel", .method = "Unary", .handler = Grpc.UnaryHandler.from(Handler, &handler) });
    var incremental = Incremental.Registry.init(std.testing.allocator);
    defer incremental.deinit();
    try incremental.register("example.v1.Cancel", "Watch", .server_streaming, Incremental.Handler.from(Handler, &handler));
    var maybe_server: ?NativeServer = null;
    var port: u16 = 29_500;
    while (port < 29_600) : (port += 1) {
        maybe_server = NativeServer.init(std.testing.allocator, std.testing.io, .{
            .port = port,
            .max_calls_per_connection = 2,
            .stream_queue_capacity = 1,
        }, &unary) catch |err| switch (err) {
            error.AddressInUse => continue,
            else => return err,
        };
        break;
    }
    if (maybe_server == null) return error.NoPersistentCancellationPort;
    var server = maybe_server.?;
    defer server.deinit();
    try server.installIncremental(&incremental);
    const ServeContext = struct {
        server: *NativeServer,
        failure: ?anyerror = null,
        fn run(self: *@This()) void {
            self.server.serveOne() catch |err| {
                self.failure = err;
            };
        }
    };
    var serve_context = ServeContext{ .server = &server };
    const server_thread = try std.Thread.spawn(.{}, ServeContext.run, .{&serve_context});
    var channel = try PersistentChannel.init(std.heap.page_allocator, std.testing.io, .{
        .port = port,
        .keepalive_interval_millis = null,
    });
    defer channel.deinit();
    const CancelFlag = struct {
        value: std.atomic.Value(bool) = .init(false),
        fn token(self: *const @This()) Grpc.Cancellation {
            return .{ .ptr = self, .is_cancelled_fn = check };
        }
        fn check(pointer: *const anyopaque) bool {
            const self: *const @This() = @ptrCast(@alignCast(pointer));
            return self.value.load(.acquire);
        }
    };
    var flag = CancelFlag{};
    const CallContext = struct {
        channel: *PersistentChannel,
        cancellation: Grpc.Cancellation,
        failure: ?anyerror = null,
        fn run(self: *@This()) void {
            var response = self.channel.invokeStreamingAlloc(std.heap.page_allocator, .{
                .authority = "localhost",
                .service = "example.v1.Cancel",
                .method = "Watch",
                .messages = &.{&.{}},
                .timeout_millis = 5_000,
                .shape = .server_streaming,
            }, .{ .cancellation = self.cancellation }) catch |err| {
                self.failure = err;
                return;
            };
            response.deinit();
        }
    };
    var call_context = CallContext{ .channel = &channel, .cancellation = flag.token() };
    const call_thread = try std.Thread.spawn(.{}, CallContext.run, .{&call_context});
    while (channel.snapshot().active_calls == 0) try sleepMilliseconds(std.testing.io, 1);
    flag.value.store(true, .release);
    call_thread.join();
    const cancellation_error = call_context.failure orelse return error.CancellationDidNotFire;
    if (cancellation_error != error.CallCancelled) return cancellation_error;
    var response = try channel.invokeAlloc(std.testing.allocator, .{
        .authority = "localhost",
        .service = "example.v1.Cancel",
        .method = "Unary",
        .payload = "still-alive",
        .timeout_millis = 1_000,
    }, .{});
    defer response.deinit();
    server_thread.join();
    if (serve_context.failure) |err| return err;
    try std.testing.expectEqualStrings("still-alive", response.payload);
    try std.testing.expectEqual(@as(usize, 1), channel.snapshot().connections_opened);
}

test "automatic keepalive records only acknowledged HTTP2 PINGs" {
    const Echo = struct {
        pub fn invoke(_: *@This(), allocator: std.mem.Allocator, request: Grpc.UnaryRequest) anyerror!Grpc.UnaryResponse {
            return Grpc.UnaryResponse.initAlloc(allocator, request.payload, .ok());
        }
    };
    var echo = Echo{};
    var registry = Grpc.Registry.init(std.testing.allocator);
    defer registry.deinit();
    try registry.register(.{ .service = "example.v1.Echo", .method = "Say", .handler = Grpc.UnaryHandler.from(Echo, &echo) });
    var maybe_server: ?NativeServer = null;
    var port: u16 = 28_700;
    while (port < 28_800) : (port += 1) {
        maybe_server = NativeServer.init(std.testing.allocator, std.testing.io, .{
            .port = port,
            .max_calls_per_connection = 100,
        }, &registry) catch |err| switch (err) {
            error.AddressInUse => continue,
            else => return err,
        };
        break;
    }
    if (maybe_server == null) return error.NoKeepaliveLoopbackPort;
    var server = maybe_server.?;
    defer server.deinit();
    const ServeContext = struct {
        server: *NativeServer,
        failure: ?anyerror = null,
        fn run(self: *@This()) void {
            self.server.serveOne() catch |err| {
                self.failure = err;
            };
        }
    };
    var serve_context = ServeContext{ .server = &server };
    const server_thread = try std.Thread.spawn(.{}, ServeContext.run, .{&serve_context});
    var channel = try PersistentChannel.init(std.testing.allocator, std.testing.io, .{
        .port = port,
        .keepalive_interval_millis = 10_000,
        .keepalive_timeout_millis = 10_000,
    });
    // Preserve production validation while shortening this deterministic test.
    channel.client_impl.options.keepalive_interval_millis = 10;
    channel.client_impl.options.keepalive_timeout_millis = 500;
    var response = try channel.invokeAlloc(std.testing.allocator, .{
        .authority = "localhost",
        .service = "example.v1.Echo",
        .method = "Say",
        .payload = "alive",
        .timeout_millis = 1_000,
    }, .{});
    response.deinit();
    const deadline = deadlineFromNow(std.testing.io, 2_000);
    while (channel.snapshot().keepalive_pings == 0 and !deadlineReached(std.testing.io, deadline)) {
        try sleepMilliseconds(std.testing.io, 1);
    }
    const snapshot = channel.snapshot();
    channel.deinit();
    server_thread.join();
    if (serve_context.failure) |err| return err;
    try std.testing.expectEqual(@as(usize, 1), snapshot.connections_opened);
    try std.testing.expect(snapshot.keepalive_pings >= 1);
}

test "ordinary concurrent calls multiplex over one persistent HTTP/2 channel" {
    const Echo = struct {
        entered: std.atomic.Value(usize) = .init(0),
        pub fn invoke(self: *@This(), allocator: std.mem.Allocator, request: Grpc.UnaryRequest) anyerror!Grpc.UnaryResponse {
            const entered = self.entered.fetchAdd(1, .acq_rel) + 1;
            if (entered == 1) {
                const deadline = deadlineFromNow(std.testing.io, 500);
                while (self.entered.load(.acquire) < 2 and !deadlineReached(std.testing.io, deadline)) {
                    try sleepMilliseconds(std.testing.io, 1);
                }
                if (self.entered.load(.acquire) < 2) return error.UnaryHandlersSerialized;
            }
            try sleepMilliseconds(std.testing.io, 20);
            return Grpc.UnaryResponse.initAlloc(allocator, request.payload, .ok());
        }
    };
    var echo = Echo{};
    var registry = Grpc.Registry.init(std.testing.allocator);
    defer registry.deinit();
    try registry.register(.{ .service = "example.v1.Echo", .method = "Say", .handler = Grpc.UnaryHandler.from(Echo, &echo) });
    var maybe_server: ?NativeServer = null;
    var port: u16 = 29_000;
    while (port < 29_100) : (port += 1) {
        maybe_server = NativeServer.init(std.testing.allocator, std.testing.io, .{
            .port = port,
            .max_calls_per_connection = 100,
        }, &registry) catch |err| switch (err) {
            error.AddressInUse => continue,
            else => return err,
        };
        break;
    }
    if (maybe_server == null) return error.NoConcurrentPersistentChannelPort;
    var server = maybe_server.?;
    defer server.deinit();
    const ServeContext = struct {
        server: *NativeServer,
        failure: ?anyerror = null,
        fn run(self: *@This()) void {
            self.server.serveOne() catch |err| {
                self.failure = err;
            };
        }
    };
    var serve_context = ServeContext{ .server = &server };
    const server_thread = try std.Thread.spawn(.{}, ServeContext.run, .{&serve_context});
    var channel = try PersistentChannel.init(std.heap.page_allocator, std.testing.io, .{
        .port = port,
        .max_concurrent_streams = 2,
        .keepalive_interval_millis = null,
    });
    const CallContext = struct {
        channel: *PersistentChannel,
        payload: []const u8,
        failure: ?anyerror = null,
        fn run(self: *@This()) void {
            var response = self.channel.invokeAlloc(std.heap.page_allocator, .{
                .authority = "localhost",
                .service = "example.v1.Echo",
                .method = "Say",
                .payload = self.payload,
                .timeout_millis = 2_000,
            }, .{}) catch |err| {
                self.failure = err;
                return;
            };
            defer response.deinit();
            if (!std.mem.eql(u8, response.payload, self.payload)) self.failure = error.UnexpectedPayload;
        }
    };
    var contexts = [_]CallContext{
        .{ .channel = &channel, .payload = "first" },
        .{ .channel = &channel, .payload = "second" },
    };
    const first = try std.Thread.spawn(.{}, CallContext.run, .{&contexts[0]});
    while (channel.snapshot().active_calls == 0) try sleepMilliseconds(std.testing.io, 1);
    const second = try std.Thread.spawn(.{}, CallContext.run, .{&contexts[1]});
    first.join();
    second.join();
    const snapshot = channel.snapshot();
    channel.deinit();
    server_thread.join();
    if (serve_context.failure) |err| return err;
    if (echo.entered.load(.acquire) != 2) return error.ConcurrentHandlersMissing;
    for (contexts) |context| if (context.failure) |err| return err;
    try std.testing.expectEqual(@as(usize, 2), snapshot.calls);
    try std.testing.expectEqual(@as(usize, 1), snapshot.connections_opened);
    try std.testing.expectEqual(@as(usize, 2), snapshot.peak_active_calls);
}

test "gzip and deflate compression are bounded per message" {
    for ([_]Grpc.Compression{ .gzip, .deflate }) |encoding| {
        const compressed = try Compression.compressAlloc(std.testing.allocator, encoding, "repeat-repeat-repeat", 1024);
        defer std.testing.allocator.free(compressed);
        const restored = try Compression.decompressAlloc(std.testing.allocator, encoding, compressed, 1024);
        defer std.testing.allocator.free(restored);
        try std.testing.expectEqualStrings("repeat-repeat-repeat", restored);
    }
}

test "server negotiates and emits compressed response messages" {
    const Echo = struct {
        pub fn invoke(_: *@This(), allocator: std.mem.Allocator, request: Grpc.UnaryRequest) anyerror!Grpc.UnaryResponse {
            return Grpc.UnaryResponse.initAlloc(allocator, request.payload, .ok());
        }
    };
    var echo = Echo{};
    var registry = Grpc.Registry.init(std.testing.allocator);
    defer registry.deinit();
    try registry.register(.{ .service = "example.v1.Compression", .method = "Echo", .handler = Grpc.UnaryHandler.from(Echo, &echo) });
    var maybe_server: ?NativeServer = null;
    var port: u16 = 29_400;
    while (port < 29_500) : (port += 1) {
        maybe_server = NativeServer.init(std.testing.allocator, std.testing.io, .{
            .port = port,
            .response_compression = .gzip,
        }, &registry) catch |err| switch (err) {
            error.AddressInUse => continue,
            else => return err,
        };
        break;
    }
    if (maybe_server == null) return error.NoCompressionPort;
    var server = maybe_server.?;
    defer server.deinit();
    const ServeContext = struct {
        server: *NativeServer,
        failure: ?anyerror = null,
        fn run(self: *@This()) void {
            self.server.serveOne() catch |err| {
                self.failure = err;
            };
        }
    };
    var context = ServeContext{ .server = &server };
    const thread = try std.Thread.spawn(.{}, ServeContext.run, .{&context});
    var client = try NativeClient.init(std.testing.allocator, std.testing.io, .{ .port = port });
    var response = try client.invokeAlloc(std.testing.allocator, .{
        .authority = "localhost",
        .service = "example.v1.Compression",
        .method = "Echo",
        .payload = "compress-compress-compress",
        .timeout_millis = 1_000,
    }, .{});
    defer response.deinit();
    thread.join();
    if (context.failure) |err| return err;
    try std.testing.expectEqualStrings("compress-compress-compress", response.payload);
}

test "Connect streaming envelopes preserve message boundaries and end-stream state" {
    const message = try Connect.frameEnvelopeAlloc(std.testing.allocator, .message, "hello", 1024);
    defer std.testing.allocator.free(message);
    const end_stream = try Connect.frameEnvelopeAlloc(std.testing.allocator, .end_stream, "{}", 1024);
    defer std.testing.allocator.free(end_stream);
    const joined = try std.mem.concat(std.testing.allocator, u8, &.{ message, end_stream });
    defer std.testing.allocator.free(joined);
    var decoded = try Connect.decodeEnvelopesAlloc(std.testing.allocator, joined, .{ .max_message_bytes = 1024, .max_messages = 4 });
    defer decoded.deinit();
    try std.testing.expectEqual(@as(usize, 2), decoded.items.len);
    try std.testing.expectEqual(Connect.EnvelopeKind.message, decoded.items[0].kind);
    try std.testing.expectEqualStrings("hello", decoded.items[0].payload);
    try std.testing.expectEqual(Connect.EnvelopeKind.end_stream, decoded.items[1].kind);
}

test "middleware authentication and telemetry remain composable and redacted" {
    const Verify = struct {
        pub fn verify(_: *@This(), token: []const u8) bool {
            return std.mem.eql(u8, token, "valid-token");
        }
    };
    var verify = Verify{};
    var auth = Middleware.BearerAuth.init(Middleware.TokenVerifier.from(Verify, &verify));
    var telemetry = Middleware.Telemetry{};
    const interceptors = [_]Middleware.Interceptor{ auth.interceptor(), telemetry.interceptor() };
    var context = Middleware.CallContext{
        .protocol = .grpc,
        .authority = "api.internal",
        .service = "orders.v1.Orders",
        .method = "List",
        .shape = .unary,
        .authorization = "Bearer valid-token",
    };
    try std.testing.expect((Middleware.before(&interceptors, &context)) == null);
    Middleware.after(&interceptors, &context, .{ .code = .ok, .duration_millis = 2 });
    const snapshot = telemetry.snapshot();
    try std.testing.expectEqual(@as(usize, 1), snapshot.started);
    try std.testing.expectEqual(@as(usize, 1), snapshot.completed);
    try std.testing.expectEqual(@as(usize, 0), snapshot.failed);
}

test "native TLS handshakes verify the peer across atomic certificate rotation" {
    try runTlsCertificateRotationScenario();
}

fn runTlsCertificateRotationScenario() !void {
    const certificate: [:0]const u8 = "tests/fixtures/cert.pem";
    const key: [:0]const u8 = "tests/fixtures/key.pem";
    const rotated_certificate: [:0]const u8 = "tests/fixtures/rotated-cert.pem";
    const rotated_key: [:0]const u8 = "tests/fixtures/rotated-key.pem";
    const Echo = struct {
        pub fn invoke(_: *@This(), allocator: std.mem.Allocator, request: Grpc.UnaryRequest) anyerror!Grpc.UnaryResponse {
            return Grpc.UnaryResponse.initAlloc(allocator, request.payload, .ok());
        }
    };
    var echo = Echo{};
    var registry = Grpc.Registry.init(std.testing.allocator);
    defer registry.deinit();
    try registry.register(.{ .service = "example.v1.Echo", .method = "Say", .handler = Grpc.UnaryHandler.from(Echo, &echo) });

    var server: ?NativeServer = null;
    var port: u16 = 28_100;
    while (port < 28_200) : (port += 1) {
        server = NativeServer.init(std.testing.allocator, std.testing.io, .{
            .port = port,
            .tls = .{
                .certificate_chain_path = certificate,
                .private_key_path = key,
                .client_ca_path = certificate,
                .require_client_certificate = true,
            },
        }, &registry) catch |err| switch (err) {
            error.AddressInUse => continue,
            else => return err,
        };
        break;
    }
    if (server == null) return error.NoTlsLoopbackPort;
    defer server.?.deinit();
    try std.testing.expectEqual(@as(u64, 1), server.?.certificateGeneration());

    const Context = struct {
        server: *NativeServer,
        failure: ?anyerror = null,
        fn run(self: *@This()) void {
            var accepted: usize = 0;
            while (accepted < 2) : (accepted += 1) self.server.serveOne() catch |err| {
                self.failure = err;
                return;
            };
        }
    };
    var context = Context{ .server = &server.? };
    const thread = try std.Thread.spawn(.{}, Context.run, .{&context});
    var original_client = try NativeClient.init(std.testing.allocator, std.testing.io, .{
        .port = port,
        .tls = .{
            .ca_path = certificate,
            .server_name = "localhost",
            .certificate_chain_path = certificate,
            .private_key_path = key,
        },
    });
    try Grpc.requireQualified(original_client.transport().capabilities);
    var original_response = try original_client.invokeAlloc(std.testing.allocator, .{
        .authority = "localhost",
        .service = "example.v1.Echo",
        .method = "Say",
        .payload = "original-certificate",
        .timeout_millis = 1000,
    }, .{});
    defer original_response.deinit();
    try std.testing.expectEqualStrings("original-certificate", original_response.payload);

    try std.testing.expectEqual(@as(u64, 2), try server.?.reloadTls(.{
        .certificate_chain_path = rotated_certificate,
        .private_key_path = rotated_key,
        .client_ca_path = rotated_certificate,
        .require_client_certificate = true,
    }));
    var rotated_client = try NativeClient.init(std.testing.allocator, std.testing.io, .{
        .port = port,
        .tls = .{
            .ca_path = rotated_certificate,
            .server_name = "localhost",
            .certificate_chain_path = rotated_certificate,
            .private_key_path = rotated_key,
        },
    });
    var rotated_response = try rotated_client.invokeAlloc(std.testing.allocator, .{
        .authority = "localhost",
        .service = "example.v1.Echo",
        .method = "Say",
        .payload = "rotated-certificate",
        .timeout_millis = 1000,
    }, .{});
    defer rotated_response.deinit();
    thread.join();
    if (context.failure) |err| return err;
    try std.testing.expectEqualStrings("rotated-certificate", rotated_response.payload);
    try std.testing.expect(rotated_response.status.isOk());
}

test "native client interrupts blocked reads at deadline" {
    var listener: ?std.Io.net.Server = null;
    var port: u16 = 28_200;
    while (port < 28_300) : (port += 1) {
        const address = try std.Io.net.IpAddress.resolve(std.testing.io, "127.0.0.1", port);
        listener = address.listen(std.testing.io, .{ .reuse_address = true }) catch |err| switch (err) {
            error.AddressInUse => continue,
            else => return err,
        };
        break;
    }
    if (listener == null) return error.NoDeadlinePort;
    defer listener.?.deinit(std.testing.io);
    const Context = struct {
        listener: *std.Io.net.Server,
        fn run(self: *@This()) void {
            var stream = self.listener.accept(std.testing.io) catch return;
            defer stream.close(std.testing.io);
            (std.Io.Clock.Duration{ .raw = .fromMilliseconds(100), .clock = .awake }).sleep(std.testing.io) catch {};
        }
    };
    var context = Context{ .listener = &listener.? };
    const thread = try std.Thread.spawn(.{}, Context.run, .{&context});
    var client = try NativeClient.init(std.testing.allocator, std.testing.io, .{ .port = port });
    try std.testing.expectError(error.DeadlineExceeded, client.invokeAlloc(std.testing.allocator, .{
        .authority = "localhost",
        .service = "example.v1.Stall",
        .method = "Wait",
        .payload = "",
        .timeout_millis = 10,
    }, .{}));
    thread.join();
}

test "native gRPC capability is bound to the inspected live receipt" {
    const bytes = try std.Io.Dir.cwd().readFileAlloc(
        std.testing.io,
        capability.conformance.?.receipt,
        std.testing.allocator,
        .limited(128 * 1024),
    );
    defer std.testing.allocator.free(bytes);
    var digest: [std.crypto.hash.sha2.Sha256.digest_length]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(bytes, &digest, .{});
    const hex = std.fmt.bytesToHex(digest, .lower);
    try std.testing.expectEqualStrings(capability.conformance.?.content_sha256[7..], &hex);

    const Receipt = struct {
        schema: []const u8,
        version: u32,
        status: []const u8,
        complete: bool,
    };
    var parsed = try std.json.parseFromSlice(Receipt, std.testing.allocator, bytes, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();
    try std.testing.expectEqualStrings(capability.conformance.?.schema, parsed.value.schema);
    try std.testing.expectEqual(capability.conformance.?.version, parsed.value.version);
    try std.testing.expectEqualStrings("passed", parsed.value.status);
    try std.testing.expect(parsed.value.complete);
}

test "native client multiplexes two unary RPCs over one HTTP/2 connection" {
    const Echo = struct {
        pub fn invoke(_: *@This(), allocator: std.mem.Allocator, request: Grpc.UnaryRequest) anyerror!Grpc.UnaryResponse {
            return Grpc.UnaryResponse.initAlloc(allocator, request.payload, .ok());
        }
    };
    var echo = Echo{};
    var registry = Grpc.Registry.init(std.testing.allocator);
    defer registry.deinit();
    try registry.register(.{ .service = "example.v1.Echo", .method = "Say", .handler = Grpc.UnaryHandler.from(Echo, &echo) });
    var server: ?NativeServer = null;
    var port: u16 = 28_300;
    while (port < 28_400) : (port += 1) {
        server = NativeServer.init(std.testing.allocator, std.testing.io, .{
            .port = port,
            .max_calls_per_connection = 2,
        }, &registry) catch |err| switch (err) {
            error.AddressInUse => continue,
            else => return err,
        };
        break;
    }
    if (server == null) return error.NoMultiplexPort;
    defer server.?.deinit();
    const Context = struct {
        server: *NativeServer,
        failure: ?anyerror = null,
        fn run(self: *@This()) void {
            self.server.serveOne() catch |err| {
                self.failure = err;
            };
        }
    };
    var context = Context{ .server = &server.? };
    const thread = try std.Thread.spawn(.{}, Context.run, .{&context});
    var client = try NativeClient.init(std.testing.allocator, std.testing.io, .{ .port = port });
    const requests = [_]Grpc.UnaryRequest{
        .{ .authority = "localhost", .service = "example.v1.Echo", .method = "Say", .payload = "first", .timeout_millis = 1000 },
        .{ .authority = "localhost", .service = "example.v1.Echo", .method = "Say", .payload = "second", .timeout_millis = 1000 },
    };
    var batch = try client.invokeBatchAlloc(std.testing.allocator, &requests, .{});
    defer batch.deinit();
    thread.join();
    if (context.failure) |err| return err;
    try std.testing.expectEqual(@as(usize, 2), batch.responses.len);
    try std.testing.expectEqualStrings("first", batch.responses[0].payload);
    try std.testing.expectEqualStrings("second", batch.responses[1].payload);
}

test "native transport supports client server and bidirectional streaming shapes" {
    const Handler = struct {
        pub fn invokeStreaming(_: *@This(), allocator: std.mem.Allocator, request: Grpc.StreamingRequest) anyerror!Grpc.StreamingResponse {
            return switch (request.shape) {
                .client_streaming => Grpc.StreamingResponse.initAlloc(allocator, &.{"received-two"}, .ok()),
                .server_streaming => Grpc.StreamingResponse.initAlloc(allocator, &.{ "part-one", "part-two" }, .ok()),
                .bidirectional_streaming => Grpc.StreamingResponse.initAlloc(allocator, request.messages, .ok()),
                .unary => error.InvalidCallShape,
            };
        }
    };
    var handler = Handler{};
    var unary = Grpc.Registry.init(std.testing.allocator);
    defer unary.deinit();
    var streaming = Grpc.StreamingRegistry.init(std.testing.allocator);
    defer streaming.deinit();
    try streaming.register("example.v1.Stream", "Upload", .client_streaming, Grpc.StreamingHandler.from(Handler, &handler));
    try streaming.register("example.v1.Stream", "Download", .server_streaming, Grpc.StreamingHandler.from(Handler, &handler));
    try streaming.register("example.v1.Stream", "Chat", .bidirectional_streaming, Grpc.StreamingHandler.from(Handler, &handler));
    var server: ?NativeServer = null;
    var port: u16 = 28_400;
    while (port < 28_500) : (port += 1) {
        server = NativeServer.initStreaming(std.testing.allocator, std.testing.io, .{ .port = port }, &unary, &streaming) catch |err| switch (err) {
            error.AddressInUse => continue,
            else => return err,
        };
        break;
    }
    if (server == null) return error.NoStreamingPort;
    defer server.?.deinit();
    const Context = struct {
        server: *NativeServer,
        failure: ?anyerror = null,
        fn run(self: *@This()) void {
            var count: usize = 0;
            while (count < 3) : (count += 1) self.server.serveOne() catch |err| {
                self.failure = err;
                return;
            };
        }
    };
    var context = Context{ .server = &server.? };
    const thread = try std.Thread.spawn(.{}, Context.run, .{&context});
    var client = try NativeClient.init(std.testing.allocator, std.testing.io, .{ .port = port });
    var upload = try client.invokeStreamingAlloc(std.testing.allocator, .{
        .authority = "localhost",
        .service = "example.v1.Stream",
        .method = "Upload",
        .messages = &.{ "one", "two" },
        .timeout_millis = 1000,
        .shape = .client_streaming,
    }, .{});
    defer upload.deinit();
    var download = try client.invokeStreamingAlloc(std.testing.allocator, .{
        .authority = "localhost",
        .service = "example.v1.Stream",
        .method = "Download",
        .messages = &.{"request"},
        .timeout_millis = 1000,
        .shape = .server_streaming,
    }, .{});
    defer download.deinit();
    var chat = try client.invokeStreamingAlloc(std.testing.allocator, .{
        .authority = "localhost",
        .service = "example.v1.Stream",
        .method = "Chat",
        .messages = &.{ "hello", "world" },
        .timeout_millis = 1000,
        .shape = .bidirectional_streaming,
    }, .{});
    defer chat.deinit();
    thread.join();
    if (context.failure) |err| return err;
    try std.testing.expectEqualStrings("received-two", upload.messages[0]);
    try std.testing.expectEqual(@as(usize, 2), download.messages.len);
    try std.testing.expectEqualStrings("hello", chat.messages[0]);
    try std.testing.expectEqualStrings("world", chat.messages[1]);
}

test "incremental server streams through a capacity-one backpressure pipe" {
    const Echo = struct {
        pub fn runIncremental(_: *@This(), call: *Incremental.Call) anyerror!Grpc.Status {
            while (try call.receive()) |value| {
                var message = value;
                defer message.deinit();
                try call.sendAlloc(std.heap.page_allocator, message.bytes);
            }
            return .ok();
        }
    };
    var echo = Echo{};
    var unary = Grpc.Registry.init(std.testing.allocator);
    defer unary.deinit();
    var incremental = Incremental.Registry.init(std.testing.allocator);
    defer incremental.deinit();
    try incremental.register(
        "example.v1.Stream",
        "Chat",
        .bidirectional_streaming,
        Incremental.Handler.from(Echo, &echo),
    );
    var maybe_server: ?NativeServer = null;
    var port: u16 = 28_700;
    while (port < 28_800) : (port += 1) {
        maybe_server = NativeServer.init(std.testing.allocator, std.testing.io, .{
            .port = port,
            .stream_queue_capacity = 1,
        }, &unary) catch |err| switch (err) {
            error.AddressInUse => continue,
            else => return err,
        };
        break;
    }
    if (maybe_server == null) return error.NoIncrementalPort;
    var server = maybe_server.?;
    defer server.deinit();
    try server.installIncremental(&incremental);
    const ServeContext = struct {
        server: *NativeServer,
        failure: ?anyerror = null,
        fn run(self: *@This()) void {
            self.server.serveOne() catch |err| {
                self.failure = err;
            };
        }
    };
    var context = ServeContext{ .server = &server };
    const thread = try std.Thread.spawn(.{}, ServeContext.run, .{&context});
    var client = try NativeClient.init(std.testing.allocator, std.testing.io, .{ .port = port });
    var response = try client.invokeStreamingAlloc(std.testing.allocator, .{
        .authority = "localhost",
        .service = "example.v1.Stream",
        .method = "Chat",
        .messages = &.{ "one", "two", "three" },
        .timeout_millis = 10_000,
        .shape = .bidirectional_streaming,
    }, .{});
    defer response.deinit();
    thread.join();
    if (context.failure) |err| return err;
    try std.testing.expectEqual(@as(usize, 3), response.messages.len);
    try std.testing.expectEqualStrings("one", response.messages[0]);
    try std.testing.expectEqualStrings("two", response.messages[1]);
    try std.testing.expectEqualStrings("three", response.messages[2]);
    try std.testing.expect(response.status.isOk());
}

test "incremental completion rechecks output after an empty pre-completion poll" {
    var outbound = try Incremental.Pipe.init(std.testing.allocator, std.testing.io, 1);
    defer outbound.deinit();
    var done = std.atomic.Value(bool).init(false);

    // Reproduce the transport's first empty poll, then the handler's final
    // enqueue and completion publication before the transport checks `done`.
    const first = try outbound.tryReceive();
    try std.testing.expect(first == null);
    try outbound.sendAlloc(std.testing.allocator, "final-response");
    outbound.close();
    done.store(true, .release);

    const poll = try finishIncrementalOutputPoll(&outbound, &done, first);
    try std.testing.expect(poll.complete);
    var message = poll.message orelse return error.FinalIncrementalResponseLost;
    defer message.deinit();
    try std.testing.expectEqualStrings("final-response", message.bytes);
}

test "persistent incremental client streams bidirectionally with capacity-one backpressure" {
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
        pub const service_name = "Stream";
        Incremental: *const fn (*void, *std.Io.Queue(Message), *std.Io.Queue(Message)) error{}!void,
    };
    const Echo = struct {
        received: std.atomic.Value(usize) = .init(0),
        saw_request_eof: std.atomic.Value(bool) = .init(false),
        saw_interceptor_metadata: std.atomic.Value(bool) = .init(false),

        pub fn Incremental(self: *@This(), stream: *Typed.Stream(Message, Message)) anyerror!Grpc.Status {
            for (stream.context().metadata) |entry| if (std.mem.eql(u8, entry.name, "client-interceptor") and std.mem.eql(u8, entry.value, "enabled")) {
                self.saw_interceptor_metadata.store(true, .release);
            };
            while (try stream.receive()) |value| {
                var message = value;
                defer message.deinit();
                _ = self.received.fetchAdd(1, .release);
                try stream.send(message.value);
            }
            self.saw_request_eof.store(true, .release);
            return .ok();
        }
    };
    var echo = Echo{};
    var client_causal_store = zstd.fx.CausalStore.init(std.testing.allocator);
    defer client_causal_store.deinit();
    var server_causal_store = zstd.fx.CausalStore.init(std.testing.allocator);
    defer server_causal_store.deinit();
    var client_causal = Middleware.CausalFacts{ .recorder = .fromStore(&client_causal_store), .service_key = "incremental-client" };
    var server_causal = Middleware.CausalFacts{ .recorder = .fromStore(&server_causal_store), .service_key = "incremental-server" };
    var unary = Grpc.Registry.init(std.testing.allocator);
    defer unary.deinit();
    var incremental = Incremental.Registry.init(std.testing.allocator);
    defer incremental.deinit();
    var binding = Typed.GeneratedDriverBinding(Service, Echo).init(std.heap.page_allocator, &echo);
    try binding.registerAll(&unary, &incremental);
    var maybe_server: ?NativeServer = null;
    var port: u16 = 29_600;
    while (port < 29_700) : (port += 1) {
        maybe_server = NativeServer.init(std.testing.allocator, std.testing.io, .{
            .port = port,
            .stream_queue_capacity = 1,
            .max_calls_per_connection = 1,
            .causal = &server_causal,
        }, &unary) catch |err| switch (err) {
            error.AddressInUse => continue,
            else => return err,
        };
        break;
    }
    if (maybe_server == null) return error.NoPersistentIncrementalPort;
    var server = maybe_server.?;
    defer server.deinit();
    try server.installIncremental(&incremental);
    const ServeContext = struct {
        server: *NativeServer,
        failure: ?anyerror = null,
        fn run(self: *@This()) void {
            self.server.serveOne() catch |err| {
                self.failure = err;
            };
        }
    };
    var serve_context = ServeContext{ .server = &server };
    const server_thread = try std.Thread.spawn(.{}, ServeContext.run, .{&serve_context});
    var channel = try PersistentChannel.init(std.heap.page_allocator, std.testing.io, .{
        .port = port,
        .keepalive_interval_millis = null,
        .causal = &client_causal,
    });
    var server_joined = false;
    defer {
        channel.deinit();
        if (!server_joined) server_thread.join();
    }
    const metadata = [_]Grpc.Metadata{.{ .name = "client-interceptor", .value = "enabled" }};
    var append = Middleware.AppendClientMetadata{ .metadata = &metadata };
    const Observer = struct {
        completed: usize = 0,
        code: Grpc.Code = .unknown,
        pub fn beforeClient(_: *@This(), _: *Middleware.ClientCallContext) ?Grpc.Status {
            return null;
        }
        pub fn afterClient(self: *@This(), _: *const Middleware.ClientCallContext, outcome: Middleware.ClientOutcome) void {
            self.completed += 1;
            self.code = outcome.code;
        }
    };
    var observer = Observer{};
    const client_interceptors = [_]Middleware.ClientInterceptor{ append.interceptor(), Middleware.ClientInterceptor.from(Observer, &observer) };
    var intercepted = InterceptedIncrementalClient{
        .allocator = std.heap.page_allocator,
        .downstream = IncrementalClientTransport.from(PersistentChannel, &channel),
        .interceptors = &client_interceptors,
    };
    var generated = GeneratedInterceptedIncrementalClient(Service).init(&intercepted, "localhost", 1);
    var stream = try generated.open(.Incremental, .{ .call = .{ .timeout_millis = 5_000 } });
    defer stream.deinit();
    try stream.send(.{ .value = 1 });
    var first = (try stream.receive()) orelse {
        return error.MissingIncrementalResponse;
    };
    defer first.deinit();
    try std.testing.expectEqual(@as(u8, 1), first.value.value);
    try stream.send(.{ .value = 2 });
    var second = (try stream.receive()) orelse {
        if (echo.saw_request_eof.load(.acquire)) return error.ServerObservedPrematureRequestEof;
        if (echo.received.load(.acquire) != 2) return error.ServerDidNotReceiveSecondRequest;
        return error.MissingIncrementalResponse;
    };
    defer second.deinit();
    try std.testing.expectEqual(@as(u8, 2), second.value.value);
    stream.closeSend();
    var final = stream.finishAlloc(std.testing.allocator) catch |client_error| {
        return client_error;
    };
    defer final.deinit();
    server_thread.join();
    server_joined = true;
    if (serve_context.failure) |err| return err;
    try std.testing.expect(final.status.isOk());
    try std.testing.expect(echo.saw_interceptor_metadata.load(.acquire));
    try std.testing.expectEqual(@as(usize, 1), observer.completed);
    try std.testing.expectEqual(Grpc.Code.ok, observer.code);
    try std.testing.expectEqual(@as(usize, 1), channel.snapshot().connections_opened);

    var client_facts = try client_causal_store.snapshot(std.testing.allocator);
    defer client_facts.deinit();
    var server_facts = try server_causal_store.snapshot(std.testing.allocator);
    defer server_facts.deinit();
    var saw_client_stream_started = false;
    var saw_client_stream_opened = false;
    for (client_facts.events) |event| {
        if (!std.mem.eql(u8, event.label, "stream")) continue;
        saw_client_stream_started = saw_client_stream_started or std.mem.eql(u8, event.status, "started");
        saw_client_stream_opened = saw_client_stream_opened or std.mem.eql(u8, event.status, "opened");
        try std.testing.expect(std.mem.indexOf(u8, event.redacted_detail, "payload") == null);
    }
    var saw_server_stream_started = false;
    var saw_server_stream_completed = false;
    for (server_facts.events) |event| {
        if (!std.mem.eql(u8, event.label, "stream")) continue;
        saw_server_stream_started = saw_server_stream_started or std.mem.eql(u8, event.status, "started");
        saw_server_stream_completed = saw_server_stream_completed or std.mem.eql(u8, event.status, "completed");
        try std.testing.expect(std.mem.indexOf(u8, event.redacted_detail, "payload") == null);
    }
    try std.testing.expect(saw_client_stream_started and saw_client_stream_opened);
    try std.testing.expect(saw_server_stream_started and saw_server_stream_completed);
}

test "incremental server emits a non-OK final status in canonical trailers" {
    const Reject = struct {
        pub fn runIncremental(_: *@This(), call: *Incremental.Call) anyerror!Grpc.Status {
            if (try call.receive()) |value| {
                var message = value;
                defer message.deinit();
                try call.sendAlloc(std.heap.page_allocator, message.bytes);
            }
            while (try call.receive()) |value| {
                var message = value;
                message.deinit();
            }
            return .{ .code = .invalid_argument, .message = "stream rejected" };
        }
    };
    var reject = Reject{};
    var unary = Grpc.Registry.init(std.testing.allocator);
    defer unary.deinit();
    var incremental = Incremental.Registry.init(std.testing.allocator);
    defer incremental.deinit();
    try incremental.register(
        "example.v1.Stream",
        "Reject",
        .bidirectional_streaming,
        Incremental.Handler.from(Reject, &reject),
    );
    var maybe_server: ?NativeServer = null;
    var port: u16 = 28_900;
    while (port < 29_000) : (port += 1) {
        maybe_server = NativeServer.init(std.testing.allocator, std.testing.io, .{
            .port = port,
            .stream_queue_capacity = 1,
        }, &unary) catch |err| switch (err) {
            error.AddressInUse => continue,
            else => return err,
        };
        break;
    }
    if (maybe_server == null) return error.NoIncrementalTrailerPort;
    var server = maybe_server.?;
    defer server.deinit();
    try server.installIncremental(&incremental);
    const ServeContext = struct {
        server: *NativeServer,
        failure: ?anyerror = null,
        fn run(self: *@This()) void {
            self.server.serveOne() catch |err| {
                self.failure = err;
            };
        }
    };
    var context = ServeContext{ .server = &server };
    const thread = try std.Thread.spawn(.{}, ServeContext.run, .{&context});
    var client = try NativeClient.init(std.testing.allocator, std.testing.io, .{ .port = port });
    var response = try client.invokeStreamingAlloc(std.testing.allocator, .{
        .authority = "localhost",
        .service = "example.v1.Stream",
        .method = "Reject",
        .messages = &.{"invalid"},
        .timeout_millis = 10_000,
        .shape = .bidirectional_streaming,
    }, .{});
    defer response.deinit();
    thread.join();
    if (context.failure) |err| return err;
    try std.testing.expectEqual(@as(usize, 1), response.messages.len);
    try std.testing.expectEqualStrings("invalid", response.messages[0]);
    try std.testing.expectEqual(Grpc.Code.invalid_argument, response.status.code);
}

test "malformed HTTP2 frame corpus fails closed without leaking connections" {
    try runMalformedHttp2FrameScenario();
}

fn runMalformedHttp2FrameScenario() !void {
    var registry = Grpc.Registry.init(std.testing.allocator);
    defer registry.deinit();
    var maybe_server: ?NativeServer = null;
    var port: u16 = 28_800;
    while (port < 28_900) : (port += 1) {
        maybe_server = NativeServer.init(std.testing.allocator, std.testing.io, .{ .port = port }, &registry) catch |err| switch (err) {
            error.AddressInUse => continue,
            else => return err,
        };
        break;
    }
    if (maybe_server == null) return error.NoMalformedPeerPort;
    var server = maybe_server.?;
    defer server.deinit();
    const ServeContext = struct {
        server: *NativeServer,
        failure: ?anyerror = null,
        completed: bool = false,
        fn run(self: *@This()) void {
            self.server.serveOne() catch |err| {
                self.failure = err;
                return;
            };
            self.completed = true;
        }
    };
    const preface = "PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n";
    const cases = [_][]const u8{
        "not-an-http2-preface",
        preface ++ "\x00\x00\x01\x04\x00\x00\x00\x00\x00\x00",
        preface ++ "\x00\x00\x06\x04\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00",
        preface ++ "\x00\x00\x00\x00\x00\x00\x00\x00\x00",
        preface ++ "\x00\x00\x00\x04\x00\x00\x00\x00\x01",
    };
    for (cases) |bytes| {
        var context = ServeContext{ .server = &server };
        const thread = try std.Thread.spawn(.{}, ServeContext.run, .{&context});
        const address = try std.Io.net.IpAddress.resolve(std.testing.io, "127.0.0.1", port);
        var stream = try address.connect(std.testing.io, .{ .mode = .stream });
        var plain = PlainWire{ .io = std.testing.io, .stream = stream };
        try plain.wire().writeAll(bytes);
        stream.close(std.testing.io);
        thread.join();
        try std.testing.expect(context.completed or context.failure != null);
        try std.testing.expectEqual(@as(usize, 0), server.activeConnections());
    }
}

test "defensive adversarial campaign runs malformed frames and certificate rotation in-process" {
    for (0..build_options.grpc_adversarial_iterations) |_| {
        try runMalformedHttp2FrameScenario();
        try runTlsCertificateRotationScenario();
    }
}

test "fuzz native compression and generated protobuf boundaries remain bounded" {
    return std.testing.fuzz({}, fuzzNativeBoundaries, .{ .corpus = &.{
        &.{},
        &.{ 0x0a, 0x00 },
        &.{ 0x22, 0xfd, 0xd0, 0x9b, 0x97, 0x3d },
        &.{ 0x58, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80 },
        &.{ 0x5a, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80 },
        &.{ 0x1f, 0x8b, 0x08, 0x00 },
        &.{ 0x78, 0x9c, 0x03, 0x00 },
    } });
}

test "protobuf rejects a negative repeated-field length without trapping" {
    const regression = [_]u8{ 0x22, 0xfd, 0xd0, 0x9b, 0x97, 0x3d };
    try std.testing.expectError(error.InvalidInput, Typed.decodeAlloc(ConformanceProto.UnaryRequest, std.testing.allocator, &regression));
}

test "protobuf rejects an overlong unknown-field length varint without trapping" {
    const regression = [_]u8{ 0x5a, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80 };
    try std.testing.expectError(error.InvalidInput, Typed.decodeAlloc(ConformanceProto.UnaryRequest, std.testing.allocator, &regression));
}

test "protobuf rejects an overlong unknown scalar varint without trapping" {
    const regression = [_]u8{ 0x58, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80 };
    try std.testing.expectError(error.InvalidInput, Typed.decodeAlloc(ConformanceProto.UnaryRequest, std.testing.allocator, &regression));
}

test "protobuf duplicate optional string releases replaced allocation" {
    const regression = [_]u8{ 0x32, 0x01, 'a', 0x32, 0x01, 'b' };
    var message = try Typed.decodeAlloc(
        ConformanceProto.UnaryRequest,
        std.testing.allocator,
        &regression,
    );
    defer message.deinit(std.testing.allocator);
    try std.testing.expectEqualStrings("b", message.note.?);
}

test "protobuf oneof scalar replacement releases previous string" {
    const regression = [_]u8{ 0x4a, 0x01, 'a', 0x50, 0x01 };
    var message = try Typed.decodeAlloc(
        ConformanceProto.UnaryRequest,
        std.testing.allocator,
        &regression,
    );
    defer message.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(u64, 1), message.selector.?.number);
}

test "generated protobuf covers maps oneofs optional WKT and unknown fields" {
    const encoded = [_]u8{
        0x0a, 0x02, 'i',  'd',
        0x22, 0x01, 't',  0x2a,
        0x05, 0x0a, 0x01, 'k',
        0x10, 0x07, 0x32, 0x01,
        'n',  0x3a, 0x03, 0x0a,
        0x01, 'x',  0x40, 0x01,
        0x4a, 0x01, 's',  0x5a,
        0x05, 0x08, 0x7b, 0x10,
        0xc8, 0x03, 0x60, 0x09,
    };
    var message = try Typed.decodeAlloc(
        ConformanceProto.UnaryRequest,
        std.testing.allocator,
        &encoded,
    );
    defer message.deinit(std.testing.allocator);

    try std.testing.expectEqualStrings("id", message.id);
    try std.testing.expectEqualStrings("t", message.tags.items[0]);
    try std.testing.expectEqualStrings("k", message.counters.items[0].key);
    try std.testing.expectEqual(@as(i64, 7), message.counters.items[0].value);
    try std.testing.expectEqualStrings("n", message.note.?);
    try std.testing.expectEqualStrings("x", message.nested.?.label);
    try std.testing.expectEqual(ConformanceProto.ExampleState.EXAMPLE_STATE_READY, message.state);
    try std.testing.expectEqualStrings("s", message.selector.?.name);
    try std.testing.expectEqual(@as(i64, 123), message.observed_at.?.seconds);
    try std.testing.expectEqual(@as(i32, 456), message.observed_at.?.nanos);
    try std.testing.expect(message._unknown_fields.len != 0);

    const round_trip = try Typed.encodeAlloc(std.testing.allocator, message);
    defer std.testing.allocator.free(round_trip);
    try std.testing.expect(std.mem.endsWith(u8, round_trip, &.{ 0x60, 0x09 }));
}

test "VirtualWorld FaultMatrix and Schedules explore gRPC recovery boundaries" {
    const World = zstd.Testing.VirtualWorld;
    const actions = [_]World.Action{
        .{ .kind = .send, .actor = "resolver", .target = "channel", .value = "resolve" },
        .{ .kind = .send, .actor = "channel", .target = "backend", .value = "connect" },
        .{ .kind = .send, .actor = "client-stream", .target = "server-stream", .value = "message" },
        .{ .kind = .checkpoint, .actor = "tls", .target = "certificate", .value = "rotate" },
        .{ .kind = .send, .actor = "server", .target = "channel", .value = "goaway" },
        .{ .kind = .send, .actor = "server-stream", .target = "client-stream", .value = "rst-stream" },
        .{ .kind = .checkpoint, .actor = "server", .target = "supervisor", .value = "shutdown" },
    };
    const faults = [_]World.Fault{
        .{ .step = 0, .kind = .delay, .target = "channel", .amount = 25 },
        .{ .step = 1, .kind = .drop, .target = "backend" },
        .{ .step = 2, .kind = .duplicate, .target = "server-stream" },
        .{ .step = 3, .kind = .clock_skew, .target = "certificate", .amount = 50 },
        .{ .step = 4, .kind = .partition, .target = "channel" },
        .{ .step = 5, .kind = .reorder, .target = "client-stream" },
        .{ .step = 6, .kind = .crash, .target = "server" },
    };
    var world = try World.runAlloc(std.testing.allocator, &actions, &faults, .{ .seed = 0x47525043 });
    defer world.deinit();
    try std.testing.expectEqual(zstd.Testing.TestStatus.passed, world.status());
    try std.testing.expectEqual(actions.len, world.executed);
    try std.testing.expectEqual(faults.len, world.applied_faults);

    var matrix = try zstd.Testing.FaultMatrix.standard(std.testing.allocator, 0x47525043);
    defer matrix.deinit();
    const MatrixState = struct {
        executed: usize = 0,
        fn run(state: *@This(), case: zstd.Testing.FaultCase) !void {
            if (case.replay_token.len == 0) return error.MissingReplayToken;
            state.executed += 1;
        }
    };
    var matrix_state = MatrixState{};
    var matrix_receipt = try zstd.Testing.runFaultMatrix(
        std.testing.allocator,
        matrix,
        &matrix_state,
        MatrixState.run,
        .{ .stop_on_failure = false },
    );
    defer matrix_receipt.deinit();
    try std.testing.expectEqual(@as(usize, 0), matrix_receipt.failed);
    try std.testing.expectEqual(matrix_receipt.planned, matrix_receipt.executed);

    const ScheduleModel = struct {
        connected: bool = false,
        stream_open: bool = false,
        retry_scheduled: bool = false,
        certificate_generation: u8 = 1,
        draining: bool = false,
        shutdown: bool = false,
        done: [6]bool = .{false} ** 6,

        pub fn actionCount(_: @This()) usize {
            return 6;
        }
        pub fn runnable(self: @This(), action: usize) bool {
            if (action >= self.done.len or self.done[action]) return false;
            return switch (action) {
                0 => !self.shutdown,
                1 => self.connected and !self.shutdown,
                2 => self.stream_open and !self.shutdown,
                3 => !self.shutdown,
                4 => self.connected and !self.shutdown,
                5 => true,
                else => false,
            };
        }
        pub fn step(self: *@This(), action: usize) !void {
            if (!self.runnable(action)) return error.NotRunnable;
            self.done[action] = true;
            switch (action) {
                0 => self.connected = true,
                1 => self.stream_open = true,
                2 => {
                    self.stream_open = false;
                    self.retry_scheduled = true;
                },
                3 => self.certificate_generation +|= 1,
                4 => self.draining = true,
                5 => {
                    self.shutdown = true;
                    self.connected = false;
                    self.stream_open = false;
                    @memset(&self.done, true);
                },
                else => unreachable,
            }
        }
        pub fn isComplete(self: @This()) bool {
            if (self.shutdown) return true;
            for (self.done) |done| if (!done) return false;
            return true;
        }
        pub fn invariant(self: @This()) bool {
            return !(self.shutdown and (self.connected or self.stream_open));
        }
        pub fn stateHash(self: @This()) u64 {
            var hash: u64 = self.certificate_generation;
            hash |= @as(u64, @intFromBool(self.connected)) << 8;
            hash |= @as(u64, @intFromBool(self.stream_open)) << 9;
            hash |= @as(u64, @intFromBool(self.retry_scheduled)) << 10;
            hash |= @as(u64, @intFromBool(self.draining)) << 11;
            hash |= @as(u64, @intFromBool(self.shutdown)) << 12;
            for (self.done, 0..) |done, index| hash |= @as(u64, @intFromBool(done)) << @intCast(16 + index);
            return hash;
        }
        pub fn sourceRef(_: @This(), action: usize) ?u64 {
            return 0x475250430000 + action;
        }
    };
    var schedule = try zstd.Testing.Schedules.explore(std.testing.allocator, ScheduleModel{}, .{});
    defer schedule.deinit();
    try std.testing.expectEqual(zstd.Testing.TestStatus.passed, schedule.status);
    try std.testing.expect(!schedule.truncated);
    try std.testing.expect(schedule.explored_schedules > 0);
}

fn fuzzNativeBoundaries(_: void, smith: *std.testing.Smith) !void {
    var input: [4096]u8 = undefined;
    const bytes = input[0..smith.slice(&input)];
    for ([_]Grpc.Compression{ .gzip, .deflate }) |encoding| {
        if (Compression.decompressAlloc(std.testing.allocator, encoding, bytes, 4096)) |decoded| {
            std.testing.allocator.free(decoded);
        } else |_| {}
    }
    if (Typed.decodeAlloc(ConformanceProto.UnaryRequest, std.testing.allocator, bytes)) |message_value| {
        var message = message_value;
        message.deinit(std.testing.allocator);
    } else |_| {}
}

/// Application configuration for a scope-owned persistent client channel.
/// Borrowed option strings and credential providers must be supplied by layers
/// whose lifetime encloses this layer.
pub const PersistentChannelConfig = struct {
    io: std.Io,
    options: ClientOptions = .{},
};
pub const PersistentChannelConfigService = zstd.fx.kernel.Service(
    "zigeffect/grpc/PersistentChannelConfig",
    PersistentChannelConfig,
);

pub const PersistentChannelApi = struct {
    pub const operations: []const []const u8 = &.{ "PersistentChannel.client", "PersistentChannel.snapshot" };
    allocator: std.mem.Allocator,
    causal: *RuntimeCausalBoundary,
    channel: PersistentChannel,
};

const RuntimeCausalBoundary = struct {
    facts: Middleware.CausalFacts,
};

pub const PersistentChannelService = zstd.fx.kernel.Service(
    "zigeffect/grpc/PersistentChannel",
    PersistentChannelApi,
);

pub fn persistentChannelConfigLayer(config: PersistentChannelConfig) @TypeOf(
    zstd.fx.kernel.Layer.succeed(PersistentChannelConfigService, config),
) {
    return zstd.fx.kernel.Layer.succeed(PersistentChannelConfigService, config);
}

const PersistentChannelLifecycle = struct {
    fn acquire(
        ctx: *zstd.fx.kernel.ContextView(.{PersistentChannelConfigService}),
    ) anyerror!PersistentChannelApi {
        const config = ctx.service(PersistentChannelConfigService);
        const causal = try ctx.allocator().create(RuntimeCausalBoundary);
        errdefer ctx.allocator().destroy(causal);
        causal.* = .{ .facts = .{
            .recorder = ctx.causalRecorder(),
            .service_key = PersistentChannelService.service_key,
        } };
        var options = config.options;
        options.causal = &causal.facts;
        return .{
            .allocator = ctx.allocator(),
            .causal = causal,
            .channel = try PersistentChannel.init(ctx.allocator(), config.io, options),
        };
    }

    fn release(api: *PersistentChannelApi) void {
        api.channel.deinit();
        api.allocator.destroy(api.causal);
    }
};

pub fn persistentChannelLayer() @TypeOf(zstd.fx.kernel.Layer.scoped(
    PersistentChannelService,
    anyerror,
    .{PersistentChannelConfigService},
    PersistentChannelLifecycle.acquire,
    PersistentChannelLifecycle.release,
)) {
    return zstd.fx.kernel.Layer.scoped(
        PersistentChannelService,
        anyerror,
        .{PersistentChannelConfigService},
        PersistentChannelLifecycle.acquire,
        PersistentChannelLifecycle.release,
    );
}

const PersistentGrpcClientFactory = struct {
    fn make(ctx: *zstd.fx.kernel.ContextView(.{PersistentChannelService})) Grpc.ClientApi {
        return .{ .client = ctx.service(PersistentChannelService).channel.client() };
    }
};

pub fn persistentGrpcClientLayer() @TypeOf(zstd.fx.kernel.Layer.sync(
    Grpc.GrpcClient,
    .{PersistentChannelService},
    PersistentGrpcClientFactory.make,
)) {
    return zstd.fx.kernel.Layer.sync(
        Grpc.GrpcClient,
        .{PersistentChannelService},
        PersistentGrpcClientFactory.make,
    );
}

pub const ChannelPoolConfig = struct {
    io: std.Io,
    options: ChannelPoolOptions = .{},
};
pub const ChannelPoolConfigService = zstd.fx.kernel.Service(
    "zigeffect/grpc/ChannelPoolConfig",
    ChannelPoolConfig,
);

pub const ChannelPoolApi = struct {
    pub const operations: []const []const u8 = &.{ "ChannelPool.client", "ChannelPool.snapshot" };
    allocator: std.mem.Allocator,
    causal: *RuntimeCausalBoundary,
    pool: ChannelPool,
};

pub const ChannelPoolService = zstd.fx.kernel.Service(
    "zigeffect/grpc/ChannelPool",
    ChannelPoolApi,
);

pub fn channelPoolConfigLayer(config: ChannelPoolConfig) @TypeOf(
    zstd.fx.kernel.Layer.succeed(ChannelPoolConfigService, config),
) {
    return zstd.fx.kernel.Layer.succeed(ChannelPoolConfigService, config);
}

const ChannelPoolLifecycle = struct {
    fn acquire(ctx: *zstd.fx.kernel.ContextView(.{ChannelPoolConfigService})) anyerror!ChannelPoolApi {
        const config = ctx.service(ChannelPoolConfigService);
        const causal = try ctx.allocator().create(RuntimeCausalBoundary);
        errdefer ctx.allocator().destroy(causal);
        causal.* = .{ .facts = .{
            .recorder = ctx.causalRecorder(),
            .service_key = ChannelPoolService.service_key,
        } };
        var options = config.options;
        options.client.causal = &causal.facts;
        return .{
            .allocator = ctx.allocator(),
            .causal = causal,
            .pool = try ChannelPool.init(ctx.allocator(), config.io, options),
        };
    }

    fn release(api: *ChannelPoolApi) void {
        api.pool.deinit();
        api.allocator.destroy(api.causal);
    }
};

pub fn channelPoolLayer() @TypeOf(zstd.fx.kernel.Layer.scoped(
    ChannelPoolService,
    anyerror,
    .{ChannelPoolConfigService},
    ChannelPoolLifecycle.acquire,
    ChannelPoolLifecycle.release,
)) {
    return zstd.fx.kernel.Layer.scoped(
        ChannelPoolService,
        anyerror,
        .{ChannelPoolConfigService},
        ChannelPoolLifecycle.acquire,
        ChannelPoolLifecycle.release,
    );
}

const PooledGrpcClientFactory = struct {
    fn make(ctx: *zstd.fx.kernel.ContextView(.{ChannelPoolService})) Grpc.ClientApi {
        return .{ .client = ctx.service(ChannelPoolService).pool.client() };
    }
};

pub fn pooledGrpcClientLayer() @TypeOf(zstd.fx.kernel.Layer.sync(
    Grpc.GrpcClient,
    .{ChannelPoolService},
    PooledGrpcClientFactory.make,
)) {
    return zstd.fx.kernel.Layer.sync(
        Grpc.GrpcClient,
        .{ChannelPoolService},
        PooledGrpcClientFactory.make,
    );
}

/// Application configuration for a scope-owned native server. Registries are
/// separate services so generated handlers can be assembled before the
/// listener is reported ready.
pub const NativeServerConfig = struct {
    io: std.Io,
    options: ServerOptions = .{},
};
pub const NativeServerConfigService = zstd.fx.kernel.Service(
    "zigeffect/grpc/NativeServerConfig",
    NativeServerConfig,
);

pub const NativeServerApi = struct {
    pub const operations: []const []const u8 = &.{
        "NativeServer.ready",
        "NativeServer.serve",
        "NativeServer.drain",
        "NativeServer.shutdown",
    };
    allocator: std.mem.Allocator,
    causal: *RuntimeCausalBoundary,
    server: NativeServer,
};

pub const NativeServerService = zstd.fx.kernel.Service(
    "zigeffect/grpc/NativeServer",
    NativeServerApi,
);

pub fn nativeServerConfigLayer(config: NativeServerConfig) @TypeOf(
    zstd.fx.kernel.Layer.succeed(NativeServerConfigService, config),
) {
    return zstd.fx.kernel.Layer.succeed(NativeServerConfigService, config);
}

const NativeServerLifecycle = struct {
    const Requirements = .{
        NativeServerConfigService,
        Typed.UnaryRegistry,
        Typed.StreamingRegistry,
        Typed.IncrementalRegistry,
    };

    fn acquire(ctx: *zstd.fx.kernel.ContextView(Requirements)) anyerror!NativeServerApi {
        const config = ctx.service(NativeServerConfigService);
        const causal = try ctx.allocator().create(RuntimeCausalBoundary);
        errdefer ctx.allocator().destroy(causal);
        causal.* = .{ .facts = .{
            .recorder = ctx.causalRecorder(),
            .service_key = NativeServerService.service_key,
        } };
        var options = config.options;
        options.causal = &causal.facts;
        var server = try NativeServer.initStreaming(
            ctx.allocator(),
            config.io,
            options,
            ctx.service(Typed.UnaryRegistry),
            ctx.service(Typed.StreamingRegistry),
        );
        errdefer server.deinit();
        try server.installIncremental(ctx.service(Typed.IncrementalRegistry));
        return .{ .allocator = ctx.allocator(), .causal = causal, .server = server };
    }

    fn release(api: *NativeServerApi) void {
        api.server.deinit();
        api.allocator.destroy(api.causal);
    }
};

pub fn nativeServerLayer() @TypeOf(zstd.fx.kernel.Layer.scoped(
    NativeServerService,
    anyerror,
    NativeServerLifecycle.Requirements,
    NativeServerLifecycle.acquire,
    NativeServerLifecycle.release,
)) {
    return zstd.fx.kernel.Layer.scoped(
        NativeServerService,
        anyerror,
        NativeServerLifecycle.Requirements,
        NativeServerLifecycle.acquire,
        NativeServerLifecycle.release,
    );
}

pub const NativeChannelzConfig = struct {
    server_ref: Channelz.Ref = .{ .id = 1, .name = "zigeffect-grpc-server" },
    listener_ref: Channelz.Ref = .{ .id = 2, .name = "zigeffect-grpc-listener" },
    listener_name: []const u8 = "listener",
};

pub const NativeChannelzConfigService = zstd.fx.kernel.Service(
    "zigeffect/grpc/NativeChannelzConfig",
    NativeChannelzConfig,
);

const NativeChannelzState = struct {
    registry: Channelz.Registry,
    listen_socket_refs: [1]Channelz.Ref,
    server_source: NativeServerChannelz,
    listener_source: NativeServerSocketChannelz,
    service: Channelz.Service,
};

pub const NativeChannelzApi = struct {
    pub const operations: []const []const u8 = &.{
        "Channelz.GetServers",
        "Channelz.GetServer",
        "Channelz.GetServerSockets",
        "Channelz.GetSocket",
    };
    allocator: std.mem.Allocator,
    state: *NativeChannelzState,
};

pub const NativeChannelzService = zstd.fx.kernel.Service(
    "zigeffect/grpc/NativeChannelz",
    NativeChannelzApi,
);

pub fn nativeChannelzConfigLayer(config: NativeChannelzConfig) @TypeOf(
    zstd.fx.kernel.Layer.succeed(NativeChannelzConfigService, config),
) {
    return zstd.fx.kernel.Layer.succeed(NativeChannelzConfigService, config);
}

const NativeChannelzLifecycle = struct {
    const Requirements = .{
        NativeChannelzConfigService,
        NativeServerService,
        Typed.UnaryRegistry,
    };

    fn acquire(ctx: *zstd.fx.kernel.ContextView(Requirements)) anyerror!NativeChannelzApi {
        const allocator = ctx.allocator();
        const config = ctx.service(NativeChannelzConfigService);
        const server = &ctx.service(NativeServerService).server;
        const state = try allocator.create(NativeChannelzState);
        errdefer allocator.destroy(state);
        state.registry = Channelz.Registry.init(allocator);
        errdefer state.registry.deinit();
        state.listen_socket_refs = .{config.listener_ref};
        state.server_source = .{
            .server = server,
            .ref = config.server_ref,
            .listen_socket_refs = &state.listen_socket_refs,
        };
        state.listener_source = .{
            .server = server,
            .server_id = config.server_ref.id,
            .ref = config.listener_ref,
            .name = config.listener_name,
        };
        try state.registry.registerServer(Channelz.ServerSource.from(NativeServerChannelz, &state.server_source));
        try state.registry.registerSocket(Channelz.SocketSource.from(NativeServerSocketChannelz, &state.listener_source));
        state.service = .{ .registry = &state.registry };
        try state.service.install(ctx.service(Typed.UnaryRegistry));
        return .{ .allocator = allocator, .state = state };
    }

    fn release(api: *NativeChannelzApi) void {
        api.state.registry.deinit();
        api.allocator.destroy(api.state);
    }
};

pub fn nativeChannelzLayer() @TypeOf(zstd.fx.kernel.Layer.scoped(
    NativeChannelzService,
    anyerror,
    NativeChannelzLifecycle.Requirements,
    NativeChannelzLifecycle.acquire,
    NativeChannelzLifecycle.release,
)) {
    return zstd.fx.kernel.Layer.scoped(
        NativeChannelzService,
        anyerror,
        NativeChannelzLifecycle.Requirements,
        NativeChannelzLifecycle.acquire,
        NativeChannelzLifecycle.release,
    );
}

pub const ChannelSnapshotEffect = zstd.fx.kernel.Effect(
    ChannelSnapshot,
    error{},
    .{PersistentChannelService},
);

pub fn channelSnapshotEffect() ChannelSnapshotEffect {
    return ChannelSnapshotEffect.fromFn(struct {
        fn run(ctx: *zstd.fx.kernel.ContextView(.{PersistentChannelService})) error{}!ChannelSnapshot {
            const result = ctx.service(PersistentChannelService).channel.snapshot();
            _ = ctx.recordCausal(.{
                .kind = .io_completed,
                .service_key = PersistentChannelService.service_key,
                .label = "grpc.channel.snapshot",
                .status = "success",
                .redacted_detail = "read bounded persistent channel state; credentials and payloads omitted",
            });
            return result;
        }
    }.run);
}

pub const ServerReadyEffect = zstd.fx.kernel.Effect(bool, error{}, .{NativeServerService});

pub fn serverReadyEffect() ServerReadyEffect {
    return ServerReadyEffect.fromFn(struct {
        fn run(ctx: *zstd.fx.kernel.ContextView(.{NativeServerService})) error{}!bool {
            const ready = ctx.service(NativeServerService).server.ready();
            _ = ctx.recordCausal(.{
                .kind = .io_completed,
                .service_key = NativeServerService.service_key,
                .label = "grpc.server.ready",
                .status = if (ready) "ready" else "not-ready",
                .redacted_detail = "read native server readiness",
            });
            return ready;
        }
    }.run);
}

pub const DrainServerEffect = zstd.fx.kernel.Effect(void, error{}, .{NativeServerService});

pub fn drainServerEffect() DrainServerEffect {
    return DrainServerEffect.fromFn(struct {
        fn run(ctx: *zstd.fx.kernel.ContextView(.{NativeServerService})) error{}!void {
            ctx.service(NativeServerService).server.drain();
            _ = ctx.recordCausal(.{
                .kind = .io_completed,
                .service_key = NativeServerService.service_key,
                .label = "grpc.server.drain",
                .status = "success",
                .redacted_detail = "stopped accepting new connections",
            });
        }
    }.run);
}

pub const ServeEffect = zstd.fx.kernel.Effect(SupervisorReport, anyerror, .{NativeServerService});

pub fn serveEffect() ServeEffect {
    return ServeEffect.fromFn(struct {
        fn run(ctx: *zstd.fx.kernel.ContextView(.{NativeServerService})) anyerror!SupervisorReport {
            const started = ctx.recordCausal(.{
                .kind = .io_wait_started,
                .service_key = NativeServerService.service_key,
                .label = "grpc.server.serve",
                .status = "running",
                .redacted_detail = "native gRPC supervisor started",
            });
            const result = ctx.service(NativeServerService).server.serve() catch |err| {
                _ = ctx.recordCausal(.{
                    .kind = .io_completed,
                    .parent_id = started,
                    .cause_event_id = started,
                    .service_key = NativeServerService.service_key,
                    .label = "grpc.server.serve",
                    .type_name = @errorName(err),
                    .status = "failure",
                    .redacted_detail = "native gRPC supervisor failed",
                });
                return err;
            };
            _ = ctx.recordCausal(.{
                .kind = .io_completed,
                .parent_id = started,
                .service_key = NativeServerService.service_key,
                .label = "grpc.server.serve",
                .status = "success",
                .redacted_detail = "native gRPC supervisor stopped",
            });
            return result;
        }
    }.run);
}

pub fn ShutdownServerEffect() type {
    return zstd.fx.kernel.Effect(
        ShutdownReport,
        anyerror,
        .{NativeServerService},
    ).Stateful(ShutdownOptions);
}

pub fn shutdownServerEffect(options: ShutdownOptions) ShutdownServerEffect() {
    const State = ShutdownServerEffect().StateType;
    return ShutdownServerEffect().init(options, struct {
        fn run(state: State, ctx: *zstd.fx.kernel.ContextView(.{NativeServerService})) anyerror!ShutdownReport {
            const started = ctx.recordCausal(.{
                .kind = .io_wait_started,
                .service_key = NativeServerService.service_key,
                .label = "grpc.server.shutdown",
                .status = "running",
                .redacted_detail = "bounded native gRPC shutdown started",
            });
            const result = ctx.service(NativeServerService).server.shutdown(state) catch |err| {
                _ = ctx.recordCausal(.{
                    .kind = .io_completed,
                    .parent_id = started,
                    .cause_event_id = started,
                    .service_key = NativeServerService.service_key,
                    .label = "grpc.server.shutdown",
                    .type_name = @errorName(err),
                    .status = "failure",
                    .redacted_detail = "bounded native gRPC shutdown failed",
                });
                return err;
            };
            _ = ctx.recordCausal(.{
                .kind = .io_completed,
                .parent_id = started,
                .service_key = NativeServerService.service_key,
                .label = "grpc.server.shutdown",
                .status = if (result.forced) "forced" else "success",
                .redacted_detail = "bounded native gRPC shutdown completed",
            });
            return result;
        }
    }.run);
}

/// Canonical composition and process lifecycle for a generated native gRPC
/// application. Product code supplies its implementation/dependency layer and
/// transport policy; ZigEffect owns the registries, standard services,
/// runtime causal boundary, lifecycle, readiness, drain, and checked shutdown.
pub const Application = struct {
    fn Descriptor(comptime Service: type) type {
        return struct {
            const service_name = Typed.serviceFullName(Service);
            const service_names = [_][]const u8{
                service_name,
                "grpc.health.v1.Health",
                "grpc.channelz.v1.Channelz",
                "grpc.reflection.v1.ServerReflection",
                "grpc.reflection.v1alpha.ServerReflection",
            };
            const initial_health = [_]StandardServices.InitialHealth{
                .{ .service = "", .status = .serving },
                .{ .service = service_name, .status = .serving },
            };
        };
    }

    pub const Config = struct {
        /// Stable application identity used by Channelz and agent discovery.
        name: []const u8,
        server: NativeServerConfig,
        /// Supply the application's descriptor set when full reflection of
        /// product messages is required. Health/reflection remain available
        /// with the package-owned standard descriptor by default.
        descriptor_set: []const u8 = StandardServices.embedded_descriptor_set,
        channelz: ?NativeChannelzConfig = null,
    };

    fn standardConfig(comptime Service: type, config: Config) StandardServices.Config {
        const descriptor = Descriptor(Service);
        return .{
            .descriptor_set = config.descriptor_set,
            .service_names = &descriptor.service_names,
            .initial_health = &descriptor.initial_health,
        };
    }

    fn channelzConfig(config: Config) NativeChannelzConfig {
        return config.channelz orelse .{
            .server_ref = .{ .id = 1, .name = config.name },
            .listener_ref = .{ .id = 2, .name = config.name },
            .listener_name = config.server.options.host,
        };
    }

    /// Generated routes plus all three bounded registries. This smaller facade
    /// is useful for in-process contract tests that do not open a listener.
    pub fn routesLayer(
        comptime Service: type,
        comptime ImplementationService: type,
        dependencies: anytype,
    ) @TypeOf(Typed.generatedRoutesLayer(Service, ImplementationService).provideMerge(
        zstd.fx.kernel.Layer.mergeAll(.{
            dependencies,
            Typed.unaryRegistryLayer(),
            Typed.streamingRegistryLayer(),
            Typed.incrementalRegistryLayer(),
        }),
    )) {
        const foundations = zstd.fx.kernel.Layer.mergeAll(.{
            dependencies,
            Typed.unaryRegistryLayer(),
            Typed.streamingRegistryLayer(),
            Typed.incrementalRegistryLayer(),
        });
        return Typed.generatedRoutesLayer(Service, ImplementationService).provideMerge(foundations);
    }

    /// Complete live layer for one generated service. Additional application
    /// services belong in `dependencies`; transport internals do not.
    pub fn layer(
        comptime Service: type,
        comptime ImplementationService: type,
        dependencies: anytype,
        config: Config,
    ) @TypeOf(zstd.fx.kernel.Layer.mergeAll(.{
        nativeChannelzLayer().provideMerge(
            nativeServerLayer().provideMerge(
                StandardServices.layer().provideMerge(
                    zstd.fx.kernel.Layer.mergeAll(.{
                        routesLayer(Service, ImplementationService, dependencies),
                        StandardServices.configLayer(standardConfig(Service, config)),
                        nativeServerConfigLayer(config.server),
                        nativeChannelzConfigLayer(channelzConfig(config)),
                    }),
                ),
            ),
        ),
        zstd.Application.Lifecycle.managerLayer(),
        zstd.Application.Lifecycle.signalLayer(),
    })) {
        const configured_routes = zstd.fx.kernel.Layer.mergeAll(.{
            routesLayer(Service, ImplementationService, dependencies),
            StandardServices.configLayer(standardConfig(Service, config)),
            nativeServerConfigLayer(config.server),
            nativeChannelzConfigLayer(channelzConfig(config)),
        });
        const standards = StandardServices.layer().provideMerge(configured_routes);
        const server = nativeServerLayer().provideMerge(standards);
        const transport = nativeChannelzLayer().provideMerge(server);
        return zstd.fx.kernel.Layer.mergeAll(.{
            transport,
            zstd.Application.Lifecycle.managerLayer(),
            zstd.Application.Lifecycle.signalLayer(),
        });
    }

    pub const StopSource = struct {
        state: ?*anyopaque = null,
        requested_fn: *const fn (?*anyopaque) bool,

        pub fn processSignals() StopSource {
            return .{ .requested_fn = struct {
                fn requested(_: ?*anyopaque) bool {
                    return zstd.Application.Lifecycle.requestedSignal() != .none;
                }
            }.requested };
        }

        pub fn from(
            comptime State: type,
            state: *State,
            comptime requested: *const fn (*State) bool,
        ) StopSource {
            return .{
                .state = state,
                .requested_fn = struct {
                    fn call(raw: ?*anyopaque) bool {
                        const typed: *State = @ptrCast(@alignCast(raw.?));
                        return requested(typed);
                    }
                }.call,
            };
        }

        pub fn isRequested(self: StopSource) bool {
            return self.requested_fn(self.state);
        }
    };

    pub const RunOptions = struct {
        readiness_attempts: usize = 200,
        poll_interval_ms: i64 = 25,
        shutdown: ShutdownOptions = .{ .deadline_ms = 25_000 },
        stop: StopSource = StopSource.processSignals(),

        fn validate(self: RunOptions) !void {
            if (self.readiness_attempts == 0 or self.poll_interval_ms <= 0) return error.InvalidApplicationRunOptions;
            try self.shutdown.validate();
        }
    };

    fn ServeContext(comptime Runtime: type) type {
        return struct {
            runtime: *Runtime,
            done: std.atomic.Value(bool) = .init(false),
            result: ?anyerror = null,
            report: SupervisorReport = .{},

            fn run(self: *@This()) void {
                self.report = self.runtime.run(serveEffect().named("grpc.application.serve")) catch |failure| {
                    self.result = failure;
                    self.done.store(true, .release);
                    return;
                };
                self.done.store(true, .release);
            }
        };
    }

    fn recover(runtime: anytype, shutdown: ShutdownOptions) void {
        _ = runtime.run(drainServerEffect().named("grpc.application.drain.recovery")) catch {};
        _ = runtime.run(shutdownServerEffect(shutdown).named("grpc.application.shutdown.recovery")) catch {};
    }

    /// Run the standard native server program and dispose the process runtime
    /// only after the embedded causal graph has passed its health/flush checks.
    pub fn run(runtime: anytype, io: std.Io, options: RunOptions) !SupervisorReport {
        try options.validate();
        try runtime.run(zstd.Application.Lifecycle.start().named("grpc.application.lifecycle.start"));

        const Runtime = @typeInfo(@TypeOf(runtime)).pointer.child;
        const Serving = ServeContext(Runtime);
        var serving = Serving{ .runtime = runtime };
        const thread = try std.Thread.spawn(.{}, Serving.run, .{&serving});
        var joined = false;
        errdefer if (!joined) {
            recover(runtime, options.shutdown);
            thread.join();
        };

        var ready = false;
        var attempt: usize = 0;
        while (attempt < options.readiness_attempts and !serving.done.load(.acquire)) : (attempt += 1) {
            if (runtime.run(serverReadyEffect().named("grpc.application.readiness")) catch false) {
                ready = true;
                break;
            }
            io.sleep(.fromMilliseconds(options.poll_interval_ms), .awake) catch break;
        }
        if (!ready) {
            recover(runtime, options.shutdown);
            thread.join();
            joined = true;
            if (serving.result) |failure| return failure;
            return error.ServerNotReady;
        }

        try runtime.run(zstd.Application.Lifecycle.ready().named("grpc.application.lifecycle.ready"));
        while (!options.stop.isRequested() and !serving.done.load(.acquire)) {
            io.sleep(.fromMilliseconds(options.poll_interval_ms), .awake) catch break;
        }

        try runtime.run(zstd.Application.Lifecycle.drain().named("grpc.application.lifecycle.drain"));
        try runtime.run(drainServerEffect().named("grpc.application.drain"));
        const shutdown = try runtime.run(shutdownServerEffect(options.shutdown).named("grpc.application.shutdown"));
        thread.join();
        joined = true;
        if (serving.result) |failure| return failure;
        if (shutdown.active_remaining != 0) return error.ShutdownIncomplete;

        try runtime.run(zstd.Application.Lifecycle.stop().named("grpc.application.lifecycle.stop"));
        if (runtime.graphSummary().records == 0 or runtime.causalHealth().status != .healthy) {
            return error.UnhealthyCausalRuntime;
        }
        const report = serving.report;
        try runtime.shutdown();
        return report;
    }
};

test "persistent channel layer owns the channel and exposes the std gRPC client service" {
    const config = persistentChannelConfigLayer(.{
        .io = std.testing.io,
        .options = .{ .keepalive_interval_millis = null },
    });
    const resources = persistentGrpcClientLayer()
        .provideMerge(persistentChannelLayer())
        .provideMerge(config);
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    var runtime = try zstd.ManagedRuntime(@TypeOf(resources)).make(
        std.testing.allocator,
        std.testing.io,
        tmp.dir,
        resources,
        .{},
    );
    defer runtime.deinit();

    const snapshot_value = try runtime.run(channelSnapshotEffect().named("grpc.channel.snapshot.test"));
    try std.testing.expect(!snapshot_value.connected);
    var application = try runtime.inspect(std.testing.allocator, .{});
    defer application.deinit();
    var saw_client = false;
    for (application.services) |service| {
        if (std.mem.eql(u8, service.key, Grpc.GrpcClient.service_key)) saw_client = true;
    }
    try std.testing.expect(saw_client);
    try std.testing.expect(runtime.graphSummary().records > 0);
    try runtime.shutdown();
}

test "channel pool layer owns all channels and exposes one load-balanced client service" {
    const config = channelPoolConfigLayer(.{
        .io = std.testing.io,
        .options = .{ .size = 2, .client = .{ .keepalive_interval_millis = null } },
    });
    const resources = pooledGrpcClientLayer()
        .provideMerge(channelPoolLayer())
        .provideMerge(config);
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    var runtime = try zstd.ManagedRuntime(@TypeOf(resources)).make(
        std.testing.allocator,
        std.testing.io,
        tmp.dir,
        resources,
        .{},
    );
    defer runtime.deinit();

    var application = try runtime.inspect(std.testing.allocator, .{});
    defer application.deinit();
    var saw_pool = false;
    var saw_client = false;
    for (application.services) |service| {
        if (std.mem.eql(u8, service.key, ChannelPoolService.service_key)) saw_pool = true;
        if (std.mem.eql(u8, service.key, Grpc.GrpcClient.service_key)) saw_client = true;
    }
    try std.testing.expect(saw_pool);
    try std.testing.expect(saw_client);
    try runtime.shutdown();
}

test "native server layer owns listener lifecycle and serves lifecycle effects" {
    const dependencies = zstd.fx.kernel.Layer.mergeAll(.{
        nativeServerConfigLayer(.{
            .io = std.testing.io,
            .options = .{ .host = "127.0.0.1", .port = 0 },
        }),
        Typed.unaryRegistryLayer(),
        Typed.streamingRegistryLayer(),
        Typed.incrementalRegistryLayer(),
        nativeChannelzConfigLayer(.{}),
    });
    const server = nativeServerLayer().provideMerge(dependencies);
    const resources = nativeChannelzLayer().provideMerge(server);
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    var runtime = try zstd.ManagedRuntime(@TypeOf(resources)).make(
        std.testing.allocator,
        std.testing.io,
        tmp.dir,
        resources,
        .{},
    );
    defer runtime.deinit();

    try std.testing.expect(try runtime.run(serverReadyEffect()));
    try runtime.run(drainServerEffect());
    try std.testing.expect(!(try runtime.run(serverReadyEffect())));
    var application = try runtime.inspect(std.testing.allocator, .{ .max_recent_events = 256 });
    defer application.deinit();
    var saw_automatic_boundary_fact = false;
    var saw_channelz_layer = false;
    for (application.services) |service| {
        if (std.mem.eql(u8, service.key, NativeChannelzService.service_key)) saw_channelz_layer = true;
    }
    for (application.causal.recent_events) |event| {
        if (std.mem.eql(u8, event.type_name, "GrpcBoundaryFact") and
            std.mem.eql(u8, event.service_key, NativeServerService.service_key))
        {
            saw_automatic_boundary_fact = true;
        }
    }
    try std.testing.expect(saw_channelz_layer);
    try std.testing.expect(saw_automatic_boundary_fact);
    try std.testing.expect(runtime.graphSummary().records > 0);
    try runtime.shutdown();
}

test "application facade owns generated routes standard services transport and lifecycle" {
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
        pub const service_name = "ApplicationFacade";
        Ping: *const fn (*void, Message) anyerror!Message,
    };
    const Implementation = struct {
        pub fn Ping(_: *@This(), _: *zstd.fx.kernel.ContextView(.{}), request: Message) !Message {
            return request;
        }
    };
    const ImplementationService = zstd.fx.kernel.Service(
        "test/grpc/ApplicationFacadeImplementation",
        Implementation,
    );
    const dependencies = zstd.fx.kernel.Layer.succeed(ImplementationService, .{});
    const root = Application.layer(Service, ImplementationService, dependencies, .{
        .name = "application-facade-test",
        .server = .{
            .io = std.testing.io,
            .options = .{
                .host = "127.0.0.1",
                .port = 0,
                .max_connections = 1,
                .handler_worker_count = 1,
                .handler_queue_capacity = 4,
            },
        },
    });
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    var runtime = try zstd.ManagedRuntime(@TypeOf(root)).make(
        std.testing.allocator,
        std.testing.io,
        tmp.dir,
        root,
        .{},
    );
    defer runtime.deinit();

    var application = try runtime.inspect(std.testing.allocator, .{});
    defer application.deinit();
    inline for (.{
        Typed.UnaryRegistry,
        Typed.StreamingRegistry,
        Typed.IncrementalRegistry,
        StandardServices.Service,
        NativeServerService,
        NativeChannelzService,
        zstd.Application.Lifecycle.Lifecycle,
        zstd.Application.Lifecycle.ProcessSignals,
    }) |ExpectedService| {
        var found = false;
        for (application.services) |service| {
            if (std.mem.eql(u8, service.key, ExpectedService.service_key)) found = true;
        }
        try std.testing.expect(found);
    }
    try std.testing.expect(try runtime.run(serverReadyEffect()));
    try std.testing.expect(runtime.graphSummary().records > 0);
    const Stop = struct {
        fn requested(_: *@This()) bool {
            return true;
        }
    };
    var stop = Stop{};
    const report = try Application.run(&runtime, std.testing.io, .{
        .stop = Application.StopSource.from(Stop, &stop, Stop.requested),
    });
    try std.testing.expectEqual(@as(usize, 0), report.failed);
}

test "application runner rejects non-positive polling intervals" {
    try std.testing.expectError(
        error.InvalidApplicationRunOptions,
        (Application.RunOptions{ .poll_interval_ms = -1 }).validate(),
    );
}
