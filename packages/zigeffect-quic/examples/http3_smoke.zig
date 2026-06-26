const std = @import("std");
const zquic = @import("zigeffect_quic");

pub fn runFakeSmokeAlloc(allocator: std.mem.Allocator) !zquic.Http.Response {
    var response = try zquic.Http.cloneResponseAlloc(allocator, .{
        .status = 204,
        .body = "",
    });
    defer response.deinit(allocator);

    var client = try zquic.FakeQuicHttpClient.initOwned(allocator, response);
    defer client.deinit();

    return client.sendAlloc(allocator, .{
        .method = "GET",
        .url = "https://localhost/health",
    });
}

pub fn runLiveSmokeAlloc(
    allocator: std.mem.Allocator,
    address: []const u8,
    port: u16,
    path: []const u8,
    insecure: bool,
) !zquic.Http.Response {
    var client = zquic.QuicHttpClient.init(.{
        .address = address,
        .port = port,
        .server_name = "localhost",
        .skip_cert_verify = insecure,
    });
    return client.sendAlloc(allocator, .{
        .method = "GET",
        .url = path,
    });
}

pub fn main(init: std.process.Init.Minimal) !void {
    const allocator = std.heap.page_allocator;
    var live = false;
    var address: []const u8 = "127.0.0.1";
    var port: u16 = 4433;
    var path: []const u8 = "/";
    var insecure = false;

    var args = std.process.Args.Iterator.init(init.args);
    _ = args.next();
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--live")) {
            live = true;
        } else if (std.mem.eql(u8, arg, "--address")) {
            if (args.next()) |value| address = value;
        } else if (std.mem.eql(u8, arg, "--port")) {
            if (args.next()) |value| port = std.fmt.parseInt(u16, value, 10) catch port;
        } else if (std.mem.eql(u8, arg, "--path")) {
            if (args.next()) |value| path = value;
        } else if (std.mem.eql(u8, arg, "--insecure")) {
            insecure = true;
        }
    }

    var response = if (live)
        try runLiveSmokeAlloc(allocator, address, port, path, insecure)
    else
        try runFakeSmokeAlloc(allocator);
    defer response.deinit(allocator);

    std.debug.print("status={d} body={s}\n", .{ response.status, response.body });
}

test "http3 smoke example runs deterministic fake path" {
    var response = try runFakeSmokeAlloc(std.testing.allocator);
    defer response.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(u16, 204), response.status);
}
