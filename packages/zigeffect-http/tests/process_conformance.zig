const std = @import("std");

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const server_path = args.next() orelse return error.MissingServerPath;

    const port = try findAvailablePort(init.io);
    var port_buffer: [5]u8 = undefined;
    const port_text = try std.fmt.bufPrint(&port_buffer, "{d}", .{port});
    var child = try std.process.spawn(init.io, .{
        .argv = &.{ server_path, port_text },
        .stdin = .ignore,
        .stdout = .ignore,
        .stderr = .inherit,
    });
    defer child.kill(init.io);

    const address = try std.Io.net.IpAddress.parseIp4("127.0.0.1", port);
    var stream: std.Io.net.Stream = undefined;
    var connected = false;
    for (0..200) |_| {
        stream = address.connect(init.io, .{ .mode = .stream }) catch {
            try (std.Io.Clock.Duration{ .raw = .fromMilliseconds(2), .clock = .awake }).sleep(init.io);
            continue;
        };
        connected = true;
        break;
    }
    if (!connected) return error.ServerDidNotBecomeReady;
    defer stream.close(init.io);

    try writeAll(stream, init.io, "GET /process-conformance HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n");
    var response: [4096]u8 = undefined;
    var response_len: usize = 0;
    while (response_len < response.len) {
        var parts = [_][]u8{response[response_len..]};
        const count = try init.io.vtable.netRead(init.io.userdata, stream.socket.handle, &parts);
        if (count == 0) break;
        response_len += count;
    }
    if (response_len == response.len) return error.ResponseTooLarge;
    if (std.mem.indexOf(u8, response[0..response_len], "HTTP/1.1 200 OK") == null or
        !std.mem.endsWith(u8, response[0..response_len], "separate-process-ok"))
    {
        return error.InvalidResponse;
    }
    const term = try child.wait(init.io);
    switch (term) {
        .exited => |code| if (code != 0) return error.ServerFailed,
        else => return error.ServerFailed,
    }
}

fn findAvailablePort(io: std.Io) !u16 {
    var port: u16 = 24_000;
    while (port < 24_200) : (port += 1) {
        const address = try std.Io.net.IpAddress.parseIp4("127.0.0.1", port);
        var listener = address.listen(io, .{ .reuse_address = true }) catch |err| switch (err) {
            error.AddressInUse => continue,
            else => return err,
        };
        listener.deinit(io);
        return port;
    }
    return error.NoConformancePort;
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
