const std = @import("std");
const context_mod = @import("../core/context.zig");
const services_mod = @import("services.zig");

pub const assertServiceTuple = services_mod.assertServiceTuple;
pub const serviceNotFound = context_mod.serviceNotFound;

fn servicePointerTuple(comptime service_tuple: anytype) type {
    const tuple_info = @typeInfo(@TypeOf(service_tuple)).@"struct";
    comptime var pointer_types: [tuple_info.fields.len]type = undefined;

    inline for (service_tuple, 0..) |Service, index| {
        pointer_types[index] = *Service;
    }

    return std.meta.Tuple(&pointer_types);
}

pub fn ServiceEnv(comptime service_tuple: anytype) type {
    assertServiceTuple("ServiceEnv", service_tuple);

    return struct {
        const Self = @This();
        pub const Services = service_tuple;
        pub const ServicePointers = servicePointerTuple(service_tuple);

        services: ServicePointers,

        pub fn fromContext(ctx: anytype) Self {
            var pointers: ServicePointers = undefined;
            inline for (service_tuple, 0..) |Service, index| {
                pointers[index] = ctx.service(Service);
            }
            return .{ .services = pointers };
        }

        pub fn service(self: *Self, comptime Requested: type) *Requested {
            inline for (service_tuple, 0..) |Service, index| {
                if (Requested == Service) return self.services[index];
            }
            return serviceNotFound(Self, Requested);
        }
    };
}
