const std = @import("std");

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const port = try std.fmt.parseUnsigned(u16, args.next() orelse return error.MissingPort, 10);
    const address = try std.Io.net.IpAddress.parseIp4("127.0.0.1", port);
    var listener = try address.listen(init.io, .{ .reuse_address = true });
    defer listener.deinit(init.io);
    var seen = [_]bool{ false, false, false };
    for (0..3) |_| {
        var stream = try listener.accept(init.io);
        defer stream.close(init.io);
        var buffer: [16 * 1024]u8 = undefined;
        var length: usize = 0;
        while (length < buffer.len) {
            var parts = [_][]u8{buffer[length..]};
            const count = try init.io.vtable.netRead(init.io.userdata, stream.socket.handle, &parts);
            if (count == 0) break;
            length += count;
            if (std.mem.indexOf(u8, buffer[0..length], "reference-process-collector") != null) break;
        }
        const request = buffer[0..length];
        if (std.mem.startsWith(u8, request, "POST /v1/logs ")) seen[0] = true else if (std.mem.startsWith(u8, request, "POST /v1/metrics ")) seen[1] = true else if (std.mem.startsWith(u8, request, "POST /v1/traces ")) seen[2] = true else return error.UnexpectedSignal;
        try writeAll(stream, init.io, "HTTP/1.1 200 OK\r\nContent-Length: 2\r\nConnection: close\r\n\r\n{}");
    }
    for (seen) |value| if (!value) return error.MissingSignal;
}

fn writeAll(stream: std.Io.net.Stream, io: std.Io, bytes: []const u8) !void {
    var offset: usize = 0;
    while (offset < bytes.len) {
        const parts = [_][]const u8{bytes[offset..]};
        const count = try io.vtable.netWrite(io.userdata, stream.socket.handle, "", &parts, 1);
        if (count == 0) return error.WriteZero;
        offset += count;
    }
}
