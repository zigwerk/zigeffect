const std = @import("std");
const library = @import("library");

test "shared contract exposes a stable initial version" {
    try std.testing.expectEqual(@as(u32, 1), library.contract_version);
    try library.validateCreate(.{ .id = "order-1", .idempotency_key = "0123456789abcdef", .attachment_key = "orders/order-1.txt", .attachment = "receipt" });
    const report = library.statechart.validate();
    try std.testing.expect(report.isValid());
    try std.testing.expectEqual(library.OrderStatus.processing, try library.advance(.pending, .claim));
    try std.testing.expectEqual(library.OrderStatus.completed, try library.advance(.processing, .complete));
    try std.testing.expectError(error.InvalidOrderTransition, library.advance(.completed, .claim));
}
