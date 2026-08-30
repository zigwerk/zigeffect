const zgrpc = @import("zigeffect-grpc");
const generated = @import("../gen/orders.pb.zig");

pub const UnregisteredOrdersService = struct {
    pub fn GetOrder(_: *UnregisteredOrdersService, request: generated.GetOrderRequest) !generated.Order {
        return .{ .id = request.id, .status = "unregistered" };
    }
};

pub fn constructOnly(allocator: @import("std").mem.Allocator, service: *UnregisteredOrdersService) void {
    var binding = zgrpc.Typed.GeneratedDriverBinding(
        generated.OrdersService(UnregisteredOrdersService, anyerror),
        UnregisteredOrdersService,
    ).init(allocator, service);
    _ = &binding;
}
