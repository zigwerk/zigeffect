const std = @import("std");

pub const GetOrderRequest = struct { id: []const u8 };
pub const Order = struct { id: []const u8, status: []const u8 };

pub const OrdersService = struct {
    pub fn getOrder(_: *OrdersService, request: GetOrderRequest) !Order {
        return loadOrder(request.id);
    }
};

fn loadOrder(id: []const u8) !Order {
    if (id.len == 0) return error.InvalidOrderId;
    return .{ .id = id, .status = "ready" };
}

test "GetOrder returns an order" {
    var service = OrdersService{};
    const order = try service.getOrder(.{ .id = "order-1" });
    try std.testing.expectEqualStrings("ready", order.status);
}
