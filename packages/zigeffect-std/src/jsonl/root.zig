const std = @import("std");

pub const ParsedLines = struct {
    lines: []const []const u8,
    trailing: []const u8,

    pub fn deinit(self: *ParsedLines, allocator: std.mem.Allocator) void {
        for (self.lines) |line| allocator.free(line);
        allocator.free(self.lines);
        allocator.free(self.trailing);
    }
};

pub fn appendRecordAlloc(
    allocator: std.mem.Allocator,
    existing: []const u8,
    record_json: []const u8,
) ![]const u8 {
    var output = std.ArrayList(u8).empty;
    errdefer output.deinit(allocator);

    try output.appendSlice(allocator, existing);
    try output.appendSlice(allocator, record_json);
    try output.append(allocator, '\n');

    return output.toOwnedSlice(allocator);
}

pub fn parseLinesAlloc(allocator: std.mem.Allocator, input: []const u8) !ParsedLines {
    var lines = std.ArrayList([]const u8).empty;
    errdefer {
        for (lines.items) |line| allocator.free(line);
        lines.deinit(allocator);
    }

    var start: usize = 0;
    while (std.mem.indexOfScalarPos(u8, input, start, '\n')) |newline| {
        try lines.append(allocator, try allocator.dupe(u8, input[start..newline]));
        start = newline + 1;
    }

    return .{
        .lines = try lines.toOwnedSlice(allocator),
        .trailing = try allocator.dupe(u8, input[start..]),
    };
}

test "Jsonl appends records and parses complete lines" {
    const feed = try appendRecordAlloc(std.testing.allocator, "", "{\"a\":\"1\"}");
    defer std.testing.allocator.free(feed);

    var parsed = try parseLinesAlloc(std.testing.allocator, feed);
    defer parsed.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), parsed.lines.len);
    try std.testing.expectEqualStrings("{\"a\":\"1\"}", parsed.lines[0]);
    try std.testing.expectEqualStrings("", parsed.trailing);
}

test "Jsonl retains trailing partial line" {
    var parsed = try parseLinesAlloc(std.testing.allocator, "{\"a\":\"1\"}\n{\"b\"");
    defer parsed.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), parsed.lines.len);
    try std.testing.expectEqualStrings("{\"a\":\"1\"}", parsed.lines[0]);
    try std.testing.expectEqualStrings("{\"b\"", parsed.trailing);
}
