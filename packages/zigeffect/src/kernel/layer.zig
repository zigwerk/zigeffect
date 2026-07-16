const std = @import("std");
const service_mod = @import("service.zig");
const context_mod = @import("context.zig");
const scope_mod = @import("../core/scope.zig");
const topology_mod = @import("topology.zig");
const identity_mod = @import("../core/runtime_identity.zig");

pub const Allocator = std.mem.Allocator;
pub const RuntimeContext = context_mod.RuntimeContext;
pub const ContextView = context_mod.ContextView;
pub const RegistryError = service_mod.RegistryError;
pub const InfrastructureError = Allocator.Error || RegistryError || scope_mod.FinalizerRegistrationError;

var next_layer_id = std.atomic.Value(u64).init(1);

fn freshLayerId() u64 {
    var id = next_layer_id.fetchAdd(1, .monotonic);
    if (id == 0) id = next_layer_id.fetchAdd(1, .monotonic);
    return id;
}

fn LayerMethods(comptime Parent: type) type {
    return struct {
        pub fn provide(self: Parent, dependency: anytype) ProvidedLayer(Parent, @TypeOf(dependency), false) {
            return .{ .dependent = self, .dependency = dependency };
        }

        pub fn provideMerge(self: Parent, dependency: anytype) ProvidedLayer(Parent, @TypeOf(dependency), true) {
            return .{ .dependent = self, .dependency = dependency };
        }

        pub fn merge(self: Parent, other: anytype) MergedLayer(@TypeOf(.{ self, other })) {
            return .{ .layers = .{ self, other } };
        }
    };
}

fn declareLayerMethods(comptime Self: type) type {
    const Methods = LayerMethods(Self);
    return struct {
        pub const provide = Methods.provide;
        pub const provideMerge = Methods.provideMerge;
        pub const merge = Methods.merge;
    };
}

pub const BuildContext = struct {
    runtime: *RuntimeContext,
    memo: *std.AutoHashMap(u64, void),
    topology: *topology_mod.Topology,

    pub fn declare(
        self: *BuildContext,
        id: u64,
        kind: topology_mod.LayerKind,
        comptime Tag: type,
        comptime Requirements: anytype,
    ) Allocator.Error!void {
        try self.topology.declare(id, kind, Tag, Requirements);
    }

    pub fn begin(self: *BuildContext, id: u64, name: []const u8) bool {
        if (self.memo.contains(id)) {
            self.topology.markMemoized(id);
            _ = self.runtime.emit(.{
                .kind = .layer_completed,
                .label = name,
                .layer_id = id,
                .status = "memoized",
            });
            return true;
        }
        self.topology.markBuilding(id);
        _ = self.runtime.emit(.{
            .kind = .layer_started,
            .label = name,
            .layer_id = id,
            .status = "starting",
        });
        return false;
    }

    pub fn complete(self: *BuildContext, id: u64, name: []const u8) Allocator.Error!void {
        try self.memo.put(id, {});
        self.topology.markReady(id);
        _ = self.runtime.emit(.{
            .kind = .layer_completed,
            .label = name,
            .layer_id = id,
            .status = "success",
        });
    }

    pub fn failed(self: *BuildContext, id: u64, name: []const u8, failure: anyerror) void {
        self.topology.markFailed(id);
        _ = self.runtime.emit(.{
            .kind = .layer_completed,
            .label = name,
            .layer_id = id,
            .type_name = @errorName(failure),
            .status = "failure",
        });
    }

    pub fn provided(self: *BuildContext, id: u64, comptime Tag: type) void {
        _ = self.runtime.emit(.{
            .kind = .service_provided,
            .label = Tag.service_key,
            .service_key = Tag.service_key,
            .type_name = identity_mod.boundedTypeName(Tag.API),
            .layer_id = id,
            .status = "provided",
        });
    }
};

pub const EmptyLayer = struct {
    const Methods = declareLayerMethods(@This());
    pub const OutputServices = [_]type{};
    pub const ErrorType = error{};
    pub const InputServices = [_]type{};
    pub const BuildError = InfrastructureError;
    pub const provide = Methods.provide;
    pub const provideMerge = Methods.provideMerge;
    pub const merge = Methods.merge;

    pub fn build(self: EmptyLayer, context: *BuildContext) BuildError!void {
        _ = self;
        _ = context;
    }
};

pub fn SucceedLayer(comptime Tag: type) type {
    service_mod.assertServiceTag(Tag);
    return struct {
        const Self = @This();
        const Methods = declareLayerMethods(Self);
        pub const OutputServices = [_]type{Tag};
        pub const ErrorType = error{};
        pub const InputServices = [_]type{};
        pub const BuildError = InfrastructureError;
        pub const provide = Methods.provide;
        pub const provideMerge = Methods.provideMerge;
        pub const merge = Methods.merge;

        id: u64,
        value: Tag.API,

        pub fn build(self: Self, context: *BuildContext) BuildError!void {
            try context.declare(self.id, .succeed, Tag, .{});
            if (context.begin(self.id, Tag.service_key)) return;
            _ = context.runtime.core.registry.putOwned(Tag, self.value) catch |failure| {
                context.failed(self.id, Tag.service_key, failure);
                return failure;
            };
            context.provided(self.id, Tag);
            context.complete(self.id, Tag.service_key) catch |failure| {
                context.failed(self.id, Tag.service_key, failure);
                return failure;
            };
        }
    };
}

pub fn SyncLayer(comptime Tag: type, comptime Requirements: anytype, comptime make: anytype) type {
    service_mod.assertServiceTag(Tag);
    return struct {
        const Self = @This();
        const Methods = declareLayerMethods(Self);
        pub const OutputServices = [_]type{Tag};
        pub const ErrorType = error{};
        pub const InputServices = Requirements;
        pub const BuildError = InfrastructureError;
        pub const provide = Methods.provide;
        pub const provideMerge = Methods.provideMerge;
        pub const merge = Methods.merge;

        id: u64,

        pub fn build(self: Self, context: *BuildContext) BuildError!void {
            try context.declare(self.id, .sync, Tag, Requirements);
            if (context.begin(self.id, Tag.service_key)) return;
            var services = ContextView(Requirements){ .runtime_context = context.runtime };
            const value: Tag.API = make(&services);
            _ = context.runtime.core.registry.putOwned(Tag, value) catch |failure| {
                context.failed(self.id, Tag.service_key, failure);
                return failure;
            };
            context.provided(self.id, Tag);
            context.complete(self.id, Tag.service_key) catch |failure| {
                context.failed(self.id, Tag.service_key, failure);
                return failure;
            };
        }
    };
}

pub fn EffectLayer(
    comptime Tag: type,
    comptime Failure: type,
    comptime Requirements: anytype,
    comptime acquire: anytype,
) type {
    service_mod.assertServiceTag(Tag);
    return struct {
        const Self = @This();
        const Methods = declareLayerMethods(Self);
        pub const OutputServices = [_]type{Tag};
        pub const ErrorType = Failure;
        pub const InputServices = Requirements;
        pub const BuildError = Failure || InfrastructureError;
        pub const provide = Methods.provide;
        pub const provideMerge = Methods.provideMerge;
        pub const merge = Methods.merge;

        id: u64,

        pub fn build(self: Self, context: *BuildContext) BuildError!void {
            try context.declare(self.id, .effect, Tag, Requirements);
            if (context.begin(self.id, Tag.service_key)) return;
            var services = ContextView(Requirements){ .runtime_context = context.runtime };
            const value = acquire(&services) catch |failure| {
                context.failed(self.id, Tag.service_key, failure);
                return failure;
            };
            _ = context.runtime.core.registry.putOwned(Tag, value) catch |failure| {
                context.failed(self.id, Tag.service_key, failure);
                return failure;
            };
            context.provided(self.id, Tag);
            context.complete(self.id, Tag.service_key) catch |failure| {
                context.failed(self.id, Tag.service_key, failure);
                return failure;
            };
        }
    };
}

pub fn ScopedLayer(
    comptime Tag: type,
    comptime Failure: type,
    comptime Requirements: anytype,
    comptime acquire: anytype,
    comptime release: anytype,
) type {
    service_mod.assertServiceTag(Tag);
    return struct {
        const Self = @This();
        const Methods = declareLayerMethods(Self);
        pub const OutputServices = [_]type{Tag};
        pub const ErrorType = Failure;
        pub const InputServices = Requirements;
        pub const BuildError = Failure || InfrastructureError;
        pub const provide = Methods.provide;
        pub const provideMerge = Methods.provideMerge;
        pub const merge = Methods.merge;

        id: u64,

        pub fn build(self: Self, context: *BuildContext) BuildError!void {
            try context.declare(self.id, .scoped, Tag, Requirements);
            if (context.begin(self.id, Tag.service_key)) return;
            var services = ContextView(Requirements){ .runtime_context = context.runtime };
            var value = acquire(&services) catch |failure| {
                context.failed(self.id, Tag.service_key, failure);
                return failure;
            };
            const pointer = context.runtime.core.registry.putOwned(Tag, value) catch |failure| {
                release(&value);
                context.failed(self.id, Tag.service_key, failure);
                return failure;
            };
            context.runtime.scope.addFinalizerFor(Tag.API, pointer, release) catch |failure| {
                release(pointer);
                context.failed(self.id, Tag.service_key, failure);
                return failure;
            };
            context.provided(self.id, Tag);
            context.complete(self.id, Tag.service_key) catch |failure| {
                context.failed(self.id, Tag.service_key, failure);
                return failure;
            };
        }
    };
}

fn mergedOutputTotal(comptime Layers: type) usize {
    comptime var total: usize = 0;
    inline for (std.meta.fields(Layers)) |field| total += field.type.OutputServices.len;
    return total;
}

fn mergedInputTotal(comptime Layers: type) usize {
    comptime var total: usize = 0;
    inline for (std.meta.fields(Layers)) |field| total += field.type.InputServices.len;
    return total;
}

fn mergedOutputCount(comptime Layers: type) usize {
    comptime var seen: [mergedOutputTotal(Layers)]type = undefined;
    comptime var count: usize = 0;
    inline for (std.meta.fields(Layers)) |field| {
        inline for (field.type.OutputServices) |Tag| {
            if (!service_mod.contains(seen[0..count], Tag)) {
                seen[count] = Tag;
                count += 1;
            }
        }
    }
    return count;
}

fn mergedInputCount(comptime Layers: type) usize {
    comptime var seen: [mergedInputTotal(Layers)]type = undefined;
    comptime var count: usize = 0;
    inline for (std.meta.fields(Layers)) |field| {
        inline for (field.type.InputServices) |Tag| {
            if (!service_mod.contains(seen[0..count], Tag)) {
                seen[count] = Tag;
                count += 1;
            }
        }
    }
    return count;
}

fn mergedOutputs(comptime Layers: type) [mergedOutputCount(Layers)]type {
    comptime var result: [mergedOutputCount(Layers)]type = undefined;
    comptime var index: usize = 0;
    inline for (std.meta.fields(Layers)) |field| {
        inline for (field.type.OutputServices) |Tag| {
            if (!service_mod.contains(result[0..index], Tag)) {
                result[index] = Tag;
                index += 1;
            }
        }
    }
    return result;
}

fn mergedInputs(comptime Layers: type) [mergedInputCount(Layers)]type {
    comptime var result: [mergedInputCount(Layers)]type = undefined;
    comptime var index: usize = 0;
    inline for (std.meta.fields(Layers)) |field| {
        inline for (field.type.InputServices) |Tag| {
            if (!service_mod.contains(result[0..index], Tag)) {
                result[index] = Tag;
                index += 1;
            }
        }
    }
    return result;
}

fn mergedErrorType(comptime Layers: type) type {
    comptime var Errors = error{};
    inline for (std.meta.fields(Layers)) |field| Errors = Errors || field.type.ErrorType;
    return Errors;
}

fn mergedBuildError(comptime Layers: type) type {
    comptime var Errors = error{};
    inline for (std.meta.fields(Layers)) |field| Errors = Errors || field.type.BuildError;
    return Errors;
}

pub fn MergedLayer(comptime Layers: type) type {
    return struct {
        const Self = @This();
        const Methods = declareLayerMethods(Self);
        pub const OutputServices = mergedOutputs(Layers);
        pub const ErrorType = mergedErrorType(Layers);
        pub const InputServices = mergedInputs(Layers);
        pub const BuildError = mergedBuildError(Layers);
        pub const provide = Methods.provide;
        pub const provideMerge = Methods.provideMerge;
        pub const merge = Methods.merge;

        layers: Layers,

        pub fn build(self: Self, context: *BuildContext) BuildError!void {
            inline for (std.meta.fields(Layers)) |field| {
                try @field(self.layers, field.name).build(context);
            }
        }
    };
}

pub fn ProvidedLayer(comptime Dependent: type, comptime Dependency: type, comptime expose_dependency: bool) type {
    const Unsatisfied = service_mod.difference(Dependent.InputServices, Dependency.OutputServices);
    const Inputs = service_mod.unionServices(Unsatisfied, Dependency.InputServices);
    const Outputs = if (expose_dependency)
        service_mod.unionServices(Dependent.OutputServices, Dependency.OutputServices)
    else
        Dependent.OutputServices;

    return struct {
        const Self = @This();
        const Methods = declareLayerMethods(Self);
        pub const OutputServices = Outputs;
        pub const ErrorType = Dependent.ErrorType || Dependency.ErrorType;
        pub const InputServices = Inputs;
        pub const BuildError = Dependent.BuildError || Dependency.BuildError;
        pub const provide = Methods.provide;
        pub const provideMerge = Methods.provideMerge;
        pub const merge = Methods.merge;

        dependent: Dependent,
        dependency: Dependency,

        pub fn build(self: Self, context: *BuildContext) BuildError!void {
            try self.dependency.build(context);
            try self.dependent.build(context);
        }
    };
}

pub const Layer = struct {
    pub fn empty() EmptyLayer {
        return .{};
    }

    pub fn succeed(comptime Tag: type, value: Tag.API) SucceedLayer(Tag) {
        return .{ .id = freshLayerId(), .value = value };
    }

    pub fn sync(comptime Tag: type, comptime Requirements: anytype, comptime make: anytype) SyncLayer(Tag, Requirements, make) {
        return .{ .id = freshLayerId() };
    }

    pub fn effect(
        comptime Tag: type,
        comptime Failure: type,
        comptime Requirements: anytype,
        comptime acquire: anytype,
    ) EffectLayer(Tag, Failure, Requirements, acquire) {
        return .{ .id = freshLayerId() };
    }

    pub fn scoped(
        comptime Tag: type,
        comptime Failure: type,
        comptime Requirements: anytype,
        comptime acquire: anytype,
        comptime release: anytype,
    ) ScopedLayer(Tag, Failure, Requirements, acquire, release) {
        return .{ .id = freshLayerId() };
    }

    pub fn mergeAll(layers: anytype) MergedLayer(@TypeOf(layers)) {
        return .{ .layers = layers };
    }

    pub fn provide(dependent: anytype, dependency: anytype) ProvidedLayer(@TypeOf(dependent), @TypeOf(dependency), false) {
        return .{ .dependent = dependent, .dependency = dependency };
    }

    pub fn provideMerge(dependent: anytype, dependency: anytype) ProvidedLayer(@TypeOf(dependent), @TypeOf(dependency), true) {
        return .{ .dependent = dependent, .dependency = dependency };
    }
};
