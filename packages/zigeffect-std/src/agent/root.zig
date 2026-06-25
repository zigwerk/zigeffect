const std = @import("std");
const Json = @import("../json/root.zig");
const Jsonl = @import("../jsonl/root.zig");

pub const Event = struct {
    sequence: u64,
    agent: []const u8,
    kind: []const u8,
    detail: []const u8,
};

pub const RunReceipt = struct {
    agent: []const u8,
    workspace: []const u8,
    status: []const u8,
};

pub fn eventJsonAlloc(allocator: std.mem.Allocator, event: Event) ![]const u8 {
    const sequence = try std.fmt.allocPrint(allocator, "{d}", .{event.sequence});
    defer allocator.free(sequence);

    const fields = [_]Json.Field{
        .{ .name = "sequence", .value = sequence },
        .{ .name = "agent", .value = event.agent },
        .{ .name = "kind", .value = event.kind },
        .{ .name = "detail", .value = event.detail },
    };
    return Json.objectFromFieldsAlloc(allocator, fields[0..]);
}

pub fn appendEventJsonlAlloc(
    allocator: std.mem.Allocator,
    feed: []const u8,
    event: Event,
) ![]const u8 {
    const event_json = try eventJsonAlloc(allocator, event);
    defer allocator.free(event_json);
    return Jsonl.appendRecordAlloc(allocator, feed, event_json);
}

pub fn receiptJsonAlloc(allocator: std.mem.Allocator, receipt: RunReceipt) ![]const u8 {
    const fields = [_]Json.Field{
        .{ .name = "agent", .value = receipt.agent },
        .{ .name = "workspace", .value = receipt.workspace },
        .{ .name = "status", .value = receipt.status },
    };
    return Json.objectFromFieldsAlloc(allocator, fields[0..]);
}

test "Agent formats local session events as redacted JSONL" {
    const event = Event{
        .sequence = 7,
        .agent = "codex",
        .kind = "process_output",
        .detail = "token=abc123",
    };

    const feed = try appendEventJsonlAlloc(std.testing.allocator, "", event);
    defer std.testing.allocator.free(feed);

    try std.testing.expect(std.mem.indexOf(u8, feed, "token=abc123") == null);
    try std.testing.expect(std.mem.indexOf(u8, feed, "[REDACTED]") != null);
    try std.testing.expect(std.mem.endsWith(u8, feed, "\n"));
}

test "Agent run receipt includes agent workspace and status" {
    const receipt = try receiptJsonAlloc(std.testing.allocator, .{
        .agent = "claude-code",
        .workspace = "/repo",
        .status = "success",
    });
    defer std.testing.allocator.free(receipt);

    try std.testing.expect(std.mem.indexOf(u8, receipt, "\"agent\":\"claude-code\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, receipt, "\"workspace\":\"/repo\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, receipt, "\"status\":\"success\"") != null);
}
