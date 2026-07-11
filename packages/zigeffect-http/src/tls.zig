const std = @import("std");
const zstd = @import("zigeffect_std");

pub const capability = zstd.Capability.Descriptor{
    .id = "zigeffect-http.tls13",
    .kind = .http_server,
    .maturity = .local_development,
    .package = "zigeffect-http",
    .version = "0.1.0",
    .features = &.{ "tls1.3", "aes-128-gcm", "x25519", "ecdsa-p256" },
    .side_effects = .real,
    .limitations = &.{
        "TLS_AES_128_GCM_SHA256 only",
        "ECDSA P-256 certificates only",
        "live HTTP conformance is required before production_candidate",
    },
};

pub const Config = struct {
    cert_chain_der: []const []const u8,
    private_key_bytes: []const u8,
    alpn: []const []const u8 = &.{"http/1.1"},

    pub fn validate(self: Config) !void {
        if (self.cert_chain_der.len == 0) return error.MissingCertificateChain;
        for (self.cert_chain_der) |certificate| if (certificate.len == 0) return error.EmptyCertificate;
        if (self.private_key_bytes.len != 32) return error.InvalidPrivateKey;
        if (self.alpn.len == 0) return error.MissingAlpn;
        for (self.alpn) |protocol| {
            if (protocol.len == 0 or protocol.len > 255) return error.InvalidAlpn;
        }
    }
};

pub const Connection = struct {
    pointer: *anyopaque,
    read_fn: *const fn (*anyopaque, []u8) anyerror!usize,
    write_fn: *const fn (*anyopaque, []const u8) anyerror!void,
    close_fn: *const fn (*anyopaque) void,
    deinit_fn: *const fn (*anyopaque, std.mem.Allocator) void,

    pub fn read(self: Connection, buffer: []u8) !usize {
        return self.read_fn(self.pointer, buffer);
    }

    pub fn write(self: Connection, bytes: []const u8) !void {
        return self.write_fn(self.pointer, bytes);
    }

    pub fn close(self: Connection) void {
        self.close_fn(self.pointer);
    }

    pub fn deinit(self: *Connection, allocator: std.mem.Allocator) void {
        self.deinit_fn(self.pointer, allocator);
        self.* = undefined;
    }
};

pub const Provider = struct {
    pointer: *anyopaque,
    handshake_fn: *const fn (*anyopaque, std.mem.Allocator, std.Io.net.Socket.Handle) anyerror!Connection,

    pub fn from(comptime ProviderType: type, provider: *ProviderType) Provider {
        return .{
            .pointer = provider,
            .handshake_fn = struct {
                fn handshake(pointer: *anyopaque, allocator: std.mem.Allocator, handle: std.Io.net.Socket.Handle) anyerror!Connection {
                    const typed: *ProviderType = @ptrCast(@alignCast(pointer));
                    return typed.handshakeAlloc(allocator, handle);
                }
            }.handshake,
        };
    }

    pub fn handshakeAlloc(self: Provider, allocator: std.mem.Allocator, handle: std.Io.net.Socket.Handle) !Connection {
        return self.handshake_fn(self.pointer, allocator, handle);
    }
};

test "TLS provider validates bounded configuration and stays local until live conformance" {
    try capability.validate();
    try std.testing.expectEqual(zstd.Capability.Maturity.local_development, capability.maturity);
    const key = [_]u8{0x01} ** 32;
    try std.testing.expectError(error.MissingCertificateChain, (Config{ .cert_chain_der = &.{}, .private_key_bytes = &key }).validate());
    try std.testing.expectError(error.InvalidPrivateKey, (Config{ .cert_chain_der = &.{"certificate"}, .private_key_bytes = "short" }).validate());
    try (Config{ .cert_chain_der = &.{"certificate"}, .private_key_bytes = &key }).validate();
}
