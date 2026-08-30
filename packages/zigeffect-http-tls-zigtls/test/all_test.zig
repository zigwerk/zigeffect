const std = @import("std");
const adapter = @import("adapter");
const http = @import("zigeffect_http");
const zstd = @import("zigeffect_std");

test "ZigTLS adapter exposes a scoped HTTP TLS provider" {
    try adapter.capability.validate();
    try std.testing.expectEqual(zstd.Capability.Maturity.local_development, adapter.capability.maturity);

    var provider = try adapter.Provider.init(std.testing.allocator, std.testing.io, .{
        .certificate_chain_path = "tests/fixtures/cert.pem",
        .private_key_path = "tests/fixtures/key.pem",
    });
    defer provider.deinit();

    const erased: http.Tls.Provider = provider.asProvider();
    try std.testing.expectEqual(@intFromPtr(&provider), @intFromPtr(erased.pointer));
}

test "ZigTLS provider serves a certificate-verified HTTP exchange to OpenSSL" {
    const Handler = struct {
        pub fn handleAlloc(_: *@This(), allocator: std.mem.Allocator, _: http.Http.Request) !http.Http.Response {
            return http.Http.cloneResponseAlloc(allocator, .{ .status = 200, .body = "zigtls-live-ok" });
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

    var provider = try adapter.Provider.init(std.testing.allocator, std.testing.io, .{
        .certificate_chain_path = "tests/fixtures/cert.pem",
        .private_key_path = "tests/fixtures/key.pem",
    });
    defer provider.deinit();

    var handler = Handler{};
    var server: ?http.Server = null;
    var port: u16 = 25_100;
    while (port < 25_200) : (port += 1) {
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
    try std.testing.expect(std.mem.endsWith(u8, response, "zigtls-live-ok"));
    switch (term) {
        .exited => |code| try std.testing.expectEqual(@as(u8, 0), code),
        else => return error.TlsClientFailed,
    }
}
