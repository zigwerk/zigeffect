const std = @import("std");
const Secrets = @import("../secrets/root.zig");

pub const Header = struct {
    name: []const u8,
    value: []const u8,
};

pub const Request = struct {
    method: []const u8,
    url: []const u8,
    headers: []const Header = &.{},
    body: []const u8 = "",
};

pub const Response = struct {
    status: u16,
    headers: []const Header = &.{},
    body: []const u8 = "",
};

pub const FakeClient = struct {
    response: Response,

    pub fn init(response: Response) FakeClient {
        return .{ .response = response };
    }

    pub fn send(self: FakeClient, request: Request) Response {
        _ = request;
        return self.response;
    }
};

pub fn redactRequestAlloc(allocator: std.mem.Allocator, request: Request) ![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    const url = try Secrets.redactAlloc(allocator, request.url);
    defer allocator.free(url);

    try output.print(allocator, "{s} {s}", .{ request.method, url });
    for (request.headers) |header| {
        const value = if (isSensitiveHeader(header.name) or Secrets.containsSecret(header.value))
            Secrets.redacted
        else
            header.value;
        try output.print(allocator, "\n{s}: {s}", .{ header.name, value });
    }

    return output.toOwnedSlice(allocator);
}

fn isSensitiveHeader(name: []const u8) bool {
    return eqlInsensitive(name, "authorization") or
        eqlInsensitive(name, "cookie") or
        eqlInsensitive(name, "x-api-key");
}

fn eqlInsensitive(left: []const u8, right: []const u8) bool {
    if (left.len != right.len) return false;
    for (left, right) |left_byte, right_byte| {
        if (std.ascii.toLower(left_byte) != std.ascii.toLower(right_byte)) return false;
    }
    return true;
}

test "Http fake client returns configured responses" {
    const client = FakeClient.init(.{ .status = 201, .body = "created" });
    const response = client.send(.{ .method = "POST", .url = "http://localhost/projects" });

    try std.testing.expectEqual(@as(u16, 201), response.status);
    try std.testing.expectEqualStrings("created", response.body);
}

test "Http redacts authorization headers and secret URLs" {
    const headers = [_]Header{
        .{ .name = "authorization", .value = "Bearer token" },
    };
    const display = try redactRequestAlloc(std.testing.allocator, .{
        .method = "GET",
        .url = "https://token=abc123@example.com",
        .headers = headers[0..],
    });
    defer std.testing.allocator.free(display);

    try std.testing.expect(std.mem.indexOf(u8, display, "token=abc123") == null);
    try std.testing.expect(std.mem.indexOf(u8, display, "Bearer token") == null);
    try std.testing.expect(std.mem.indexOf(u8, display, "[REDACTED]") != null);
}
