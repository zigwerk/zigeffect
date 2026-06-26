const std = @import("std");
const zquic = @import("zigeffect_quic");

pub fn runReceiptExampleAlloc(allocator: std.mem.Allocator) ![]const u8 {
    return zquic.webTransportReceiptJsonAlloc(allocator, .{
        .kind = .datagram,
        .session_id = 42,
        .payload = "agent-status=ready",
        .direction = "outbound",
    });
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const receipt = try runReceiptExampleAlloc(allocator);
    defer allocator.free(receipt);
    std.debug.print("{s}\n", .{receipt});
}

test "webtransport receipt example emits deterministic JSON" {
    const receipt = try runReceiptExampleAlloc(std.testing.allocator);
    defer std.testing.allocator.free(receipt);

    try std.testing.expect(std.mem.indexOf(u8, receipt, "\"protocol\":\"webtransport\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, receipt, "\"session_id\":\"42\"") != null);
}
