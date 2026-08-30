const services = @import("services.zig");
const report = @import("report.zig");

pub const Allocator = services.Allocator;
pub const ServiceSet = services.ServiceSet;
pub const DependencyError = services.DependencyError;
pub const DependencyReport = report.DependencyReport;

fn effectRequiredServices(allocator: Allocator, effect: anytype) Allocator.Error!ServiceSet {
    const EffectType = @TypeOf(effect);
    if (@hasDecl(EffectType, "requiredServices")) {
        return EffectType.requiredServices(allocator);
    }
    return ServiceSet.init(allocator);
}

fn declarationType(comptime ValueType: type) type {
    return switch (@typeInfo(ValueType)) {
        .pointer => |pointer| pointer.child,
        else => ValueType,
    };
}

fn declaredProvidedServices(allocator: Allocator, provider: anytype) Allocator.Error!ServiceSet {
    const ProviderType = declarationType(@TypeOf(provider));
    if (@hasDecl(ProviderType, "providedServices")) {
        return provider.providedServices(allocator);
    }
    return ServiceSet.init(allocator);
}

fn declaredRequiredServices(allocator: Allocator, consumer: anytype) Allocator.Error!ServiceSet {
    const ConsumerType = declarationType(@TypeOf(consumer));
    if (@hasDecl(ConsumerType, "requiredServices")) {
        return ConsumerType.requiredServices(allocator);
    }
    return ServiceSet.init(allocator);
}

pub fn validateRequirements(allocator: Allocator, provider: anytype, consumer: anytype) Allocator.Error!DependencyReport {
    var provided = try declaredProvidedServices(allocator, provider);
    defer provided.deinit();
    var required = try declaredRequiredServices(allocator, consumer);
    defer required.deinit();

    var dependency_report = DependencyReport.init(allocator);
    errdefer dependency_report.deinit();

    for (required.names.items) |service| {
        if (!provided.contains(service)) {
            try dependency_report.addMissing("effect", service);
        }
    }

    return dependency_report;
}

pub fn requirementsSatisfiedBy(allocator: Allocator, provider: anytype, consumer: anytype) Allocator.Error!bool {
    var dependency_report = try validateRequirements(allocator, provider, consumer);
    defer dependency_report.deinit();
    return dependency_report.isValid();
}

fn staticServiceTupleContains(comptime declared_services: anytype, comptime Service: type) bool {
    inline for (declared_services) |Declared| {
        if (Declared == Service) return true;
    }
    return false;
}

fn staticProvidesService(comptime Provider: type, comptime Service: type) bool {
    if (!@hasDecl(Provider, "ProvidedServices")) return false;
    return staticServiceTupleContains(Provider.ProvidedServices, Service);
}

pub fn staticRequirementsSatisfied(comptime Provider: type, comptime Consumer: type) bool {
    if (!@hasDecl(Consumer, "RequiredServices")) return true;

    inline for (Consumer.RequiredServices) |Service| {
        if (!staticProvidesService(Provider, Service)) return false;
    }

    return true;
}

pub fn assertStaticRequirementsSatisfied(comptime Provider: type, comptime Consumer: type) void {
    if (!@hasDecl(Consumer, "RequiredServices")) return;

    inline for (Consumer.RequiredServices) |Service| {
        if (!staticProvidesService(Provider, Service)) {
            @compileError(
                "zigeffect static requirements not satisfied\n\n" ++
                    "missing service: " ++ @typeName(Service) ++ "\n" ++
                    "provider type: " ++ @typeName(Provider) ++ "\n" ++
                    "consumer type: " ++ @typeName(Consumer) ++ "\n\n" ++
                    "Add the service to .provides(.{ ... }) or use runtime validation for dynamic providers.",
            );
        }
    }
}

pub fn validateLayerRequirements(allocator: Allocator, layer: anytype, effect: anytype) Allocator.Error!DependencyReport {
    return validateRequirements(allocator, layer, effect);
}

pub fn ensureLayerRequirements(allocator: Allocator, layer: anytype, effect: anytype) (Allocator.Error || DependencyError)!void {
    var dependency_report = try validateLayerRequirements(allocator, layer, effect);
    defer dependency_report.deinit();
    if (!dependency_report.isValid()) return error.MissingServiceRequirement;
}
