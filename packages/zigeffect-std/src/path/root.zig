const std = @import("std");

pub fn joinAlloc(allocator: std.mem.Allocator, parts: []const []const u8) ![]const u8 {
    var joined = std.ArrayList(u8).empty;
    defer joined.deinit(allocator);

    for (parts) |part| {
        if (part.len == 0) continue;
        if (joined.items.len != 0 and joined.items[joined.items.len - 1] != '/') {
            try joined.append(allocator, '/');
        }
        try joined.appendSlice(allocator, part);
    }

    return normalizeAlloc(allocator, joined.items);
}

pub fn normalizeAlloc(allocator: std.mem.Allocator, path: []const u8) ![]const u8 {
    var segments = std.ArrayList([]const u8).empty;
    defer segments.deinit(allocator);

    const absolute = path.len != 0 and path[0] == '/';
    var iterator = std.mem.splitScalar(u8, path, '/');
    while (iterator.next()) |segment| {
        if (segment.len == 0 or std.mem.eql(u8, segment, ".")) continue;
        if (std.mem.eql(u8, segment, "..")) {
            if (segments.items.len != 0) _ = segments.pop();
            continue;
        }
        try segments.append(allocator, segment);
    }

    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);
    if (absolute) try output.append(allocator, '/');
    for (segments.items, 0..) |segment, index| {
        if (index != 0) try output.append(allocator, '/');
        try output.appendSlice(allocator, segment);
    }
    if (output.items.len == 0) try output.append(allocator, if (absolute) '/' else '.');
    return output.toOwnedSlice(allocator);
}

pub fn basename(path: []const u8) []const u8 {
    const trimmed = std.mem.trimRight(u8, path, "/");
    const index = std.mem.lastIndexOfScalar(u8, trimmed, '/') orelse return trimmed;
    return trimmed[index + 1 ..];
}

pub fn dirname(path: []const u8) []const u8 {
    const trimmed = std.mem.trimRight(u8, path, "/");
    const index = std.mem.lastIndexOfScalar(u8, trimmed, '/') orelse return ".";
    if (index == 0) return "/";
    return trimmed[0..index];
}

pub fn extension(path: []const u8) []const u8 {
    const base = basename(path);
    const index = std.mem.lastIndexOfScalar(u8, base, '.') orelse return "";
    if (index == 0 or index + 1 >= base.len) return "";
    return base[index + 1 ..];
}

test "Path joins normalizes and splits project paths" {
    const joined = try joinAlloc(std.testing.allocator, &.{ "/tmp/", "project", "./src//main.zig" });
    defer std.testing.allocator.free(joined);

    try std.testing.expectEqualStrings("/tmp/project/src/main.zig", joined);
    try std.testing.expectEqualStrings("main.zig", basename(joined));
    try std.testing.expectEqualStrings("/tmp/project/src", dirname(joined));
    try std.testing.expectEqualStrings("zig", extension(joined));
}
