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

pub fn runBridgeExampleAlloc(allocator: std.mem.Allocator) !zquic.LocalDevSessionBridgeSummary {
    var client = zquic.FakeWebTransportClient.init(allocator);
    defer client.deinit();

    return zquic.bridgeLocalDevSessionJsonlAlloc(allocator, .{
        .session_id = 42,
        .url = "https://localhost:4433/.well-known/webtransport",
        .status = "connected",
    },
        \\{"sequence":1,"kind":"agent_status","agent_id":"codex","agent_kind":"codex","agent_label":"Codex","status":"running","task":"bridged local dev session"}
        \\{"sequence":2,"kind":"check_result","label":"local bridge smoke","status":"pass","detail":"frame emitted"}
        \\
    , &client);
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const receipt = try runReceiptExampleAlloc(allocator);
    defer allocator.free(receipt);
    std.debug.print("{s}\n", .{receipt});

    var bridge = try runBridgeExampleAlloc(allocator);
    defer bridge.deinit();
    std.debug.print("{s}", .{bridge.frame_jsonl});
}

test "webtransport receipt example emits deterministic JSON" {
    const receipt = try runReceiptExampleAlloc(std.testing.allocator);
    defer std.testing.allocator.free(receipt);

    try std.testing.expect(std.mem.indexOf(u8, receipt, "\"protocol\":\"webtransport\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, receipt, "\"session_id\":\"42\"") != null);
}

test "webtransport bridge example emits workbench frames" {
    var bridge = try runBridgeExampleAlloc(std.testing.allocator);
    defer bridge.deinit();

    try std.testing.expectEqual(@as(usize, 2), bridge.event_count);
    try std.testing.expectEqual(@as(usize, 3), bridge.frame_count);
    try std.testing.expect(std.mem.indexOf(u8, bridge.frame_jsonl, "zigeffect.webtransport.local-dev-frame.v1") != null);
    try std.testing.expect(std.mem.indexOf(u8, bridge.frame_jsonl, "transport_status") != null);
}
