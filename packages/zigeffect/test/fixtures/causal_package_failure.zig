const std = @import("std");

test "causal package failure fixture intentionally fails" {
    std.debug.print("causal package failure fixture marker\n", .{});
    try std.testing.expectEqual(@as(u8, 1), @as(u8, 2));
}
