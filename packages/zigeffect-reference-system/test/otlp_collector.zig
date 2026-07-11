const std = @import("std");

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa); defer args.deinit();
    _ = args.next();
    const port = try std.fmt.parseUnsigned(u16, args.next() orelse return error.MissingPort, 10);
    const expected = try std.fmt.parseUnsigned(usize, args.next() orelse return error.MissingExpectedRequests, 10);
    const address = try std.Io.net.IpAddress.parseIp4("127.0.0.1", port);
    var listener = try address.listen(init.io, .{ .reuse_address = true }); defer listener.deinit(init.io);
    var api = false;
    var worker = false;
    for (0..expected) |_| {
        var stream = try listener.accept(init.io); defer stream.close(init.io);
        const request = try readRequestAlloc(init.gpa, init.io, stream); defer init.gpa.free(request);
        if (!std.mem.startsWith(u8, request, "POST /v1/logs ")) return error.UnexpectedSignal;
        api = api or std.mem.indexOf(u8, request, "reference-api") != null;
        worker = worker or std.mem.indexOf(u8, request, "reference-worker") != null;
        try writeAll(init.io, stream, "HTTP/1.1 200 OK\r\nContent-Length: 2\r\nConnection: close\r\n\r\n{}");
    }
    if (!api or !worker) return error.MissingServiceTelemetry;
}

fn readRequestAlloc(allocator: std.mem.Allocator, io: std.Io, stream: std.Io.net.Stream) ![]u8 {
    var output = std.ArrayList(u8).empty; errdefer output.deinit(allocator);
    var expected_total: ?usize = null;
    while (output.items.len < 1024 * 1024) {
        var buffer = [_]u8{0} ** 4096; var parts = [_][]u8{&buffer};
        const count = try io.vtable.netRead(io.userdata, stream.socket.handle, &parts);
        if (count == 0) break;
        try output.appendSlice(allocator, buffer[0..count]);
        if (expected_total == null) if (std.mem.indexOf(u8, output.items, "\r\n\r\n")) |header_end| {
            const length = contentLength(output.items[0..header_end]) orelse return error.MissingContentLength;
            expected_total = header_end + 4 + length;
        };
        if (expected_total) |total| if (output.items.len >= total) break;
    }
    return output.toOwnedSlice(allocator);
}

fn contentLength(headers: []const u8) ?usize {
    var lines = std.mem.splitSequence(u8, headers, "\r\n");
    while (lines.next()) |line| if (std.ascii.startsWithIgnoreCase(line, "content-length:")) return std.fmt.parseUnsigned(usize, std.mem.trim(u8, line[15..], " \t"), 10) catch null;
    return null;
}
fn writeAll(io: std.Io, stream: std.Io.net.Stream, bytes: []const u8) !void { var offset: usize = 0; while (offset < bytes.len) { const parts = [_][]const u8{bytes[offset..]}; const count = try io.vtable.netWrite(io.userdata, stream.socket.handle, "", &parts, 1); if (count == 0) return error.WriteZero; offset += count; } }
