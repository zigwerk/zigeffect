const std = @import("std");
const zgrpc = @import("zigeffect-grpc");
const generated = @import("../gen/orders.pb.zig");

pub const OrdersService = struct {
    pub fn GetOrder(_: *OrdersService, request: generated.GetOrderRequest) !generated.Order {
        return loadOrder(request.id);
    }
};

pub fn registerOrders(
    allocator: std.mem.Allocator,
    unary: *zgrpc.Grpc.Registry,
    incremental: *zgrpc.Incremental.Registry,
    service: *OrdersService,
) !void {
    var binding = zgrpc.Typed.GeneratedDriverBinding(
        generated.OrdersService(OrdersService, anyerror),
        OrdersService,
    ).init(allocator, service);
    try binding.registerAll(unary, incremental);
}

fn loadOrder(id: []const u8) !generated.Order {
    if (id.len == 0) return error.InvalidOrderId;
    return .{ .id = id, .status = "ready" };
}

test "GetOrder returns an order" {
    var service = OrdersService{};
    const order = try service.GetOrder(.{ .id = "order-1" });
    try std.testing.expectEqualStrings("ready", order.status);
}
