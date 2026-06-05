const std = @import("std");

pub const Allocator = std.mem.Allocator;

pub const DependencyError = error{
    MissingServiceRequirement,
    DuplicateServiceProvider,
};

pub const ServiceSetBuilder = *const fn (Allocator) Allocator.Error!ServiceSet;
pub const ProviderServiceSetBuilder = *const fn (*const anyopaque, Allocator) Allocator.Error!ServiceSet;

pub fn assertServiceTuple(comptime api: []const u8, comptime services: anytype) void {
    switch (@typeInfo(@TypeOf(services))) {
        .@"struct" => |struct_info| {
            if (!struct_info.is_tuple) {
                @compileError(
                    "zigeffect service tuple must be a tuple\n\n" ++
                        "api: " ++ api ++ "\n\n" ++
                        "Use tuple syntax like .{ fx.Logger, fx.Config }.",
                );
            }
        },
        else => @compileError(
            "zigeffect service tuple must be a tuple\n\n" ++
                "api: " ++ api ++ "\n\n" ++
                "Use tuple syntax like .{ fx.Logger, fx.Config }.",
        ),
    }

    inline for (services) |Service| {
        if (@TypeOf(Service) != type) {
            @compileError(
                "zigeffect service tuple entries must be types\n\n" ++
                    "api: " ++ api ++ "\n\n" ++
                    "Use service types like .{ fx.Logger, fx.Config }; values are not valid service declarations.",
            );
        }
    }
}

pub fn emptyServiceSet(allocator: Allocator) Allocator.Error!ServiceSet {
    return ServiceSet.init(allocator);
}

pub fn serviceSetBuilder(comptime services: anytype) ServiceSetBuilder {
    assertServiceTuple("service provider declaration", services);

    const Builder = struct {
        fn build(allocator: Allocator) Allocator.Error!ServiceSet {
            return ServiceSet.fromTypes(allocator, services);
        }
    };

    return Builder.build;
}

pub fn providerServiceSetBuilder(comptime ProviderPointer: type) ProviderServiceSetBuilder {
    const pointer_info = switch (@typeInfo(ProviderPointer)) {
        .pointer => |info| info,
        else => @compileError(
            "zigeffect provider metadata requires a pointer\n\n" ++
                "Use withProvider(&provider) or pass an existing provider pointer.",
        ),
    };
    const Provider = pointer_info.child;

    if (!@hasDecl(Provider, "providedServices")) {
        @compileError(
            "zigeffect provider metadata requires providedServices\n\n" ++
                "provider: " ++ @typeName(Provider) ++ "\n\n" ++
                "Add providedServices(allocator) or use .provides(.{ ... }) for static declarations.",
        );
    }

    const Builder = struct {
        fn build(raw: *const anyopaque, allocator: Allocator) Allocator.Error!ServiceSet {
            const provider: *const Provider = @ptrCast(@alignCast(raw));
            return provider.providedServices(allocator);
        }
    };

    return Builder.build;
}

pub const ServiceSet = struct {
    allocator: Allocator,
    names: std.ArrayList([]const u8) = .empty,

    pub fn init(allocator: Allocator) ServiceSet {
        return .{ .allocator = allocator };
    }

    pub fn fromTypes(allocator: Allocator, comptime services: anytype) Allocator.Error!ServiceSet {
        assertServiceTuple("ServiceSet.fromTypes", services);

        var set = ServiceSet.init(allocator);
        errdefer set.deinit();

        inline for (services) |Service| {
            try set.add(Service);
        }

        return set;
    }

    pub fn deinit(self: *ServiceSet) void {
        self.names.deinit(self.allocator);
    }

    pub fn add(self: *ServiceSet, comptime Service: type) Allocator.Error!void {
        try self.addName(@typeName(Service));
    }

    pub fn addName(self: *ServiceSet, name: []const u8) Allocator.Error!void {
        if (self.contains(name)) return;
        try self.names.append(self.allocator, name);
    }

    pub fn contains(self: *const ServiceSet, name: []const u8) bool {
        for (self.names.items) |existing| {
            if (std.mem.eql(u8, existing, name)) return true;
        }
        return false;
    }

    pub fn mergeFrom(self: *ServiceSet, other: *const ServiceSet) Allocator.Error!void {
        for (other.names.items) |name| {
            try self.addName(name);
        }
    }
};
