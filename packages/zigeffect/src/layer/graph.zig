const std = @import("std");
const context_mod = @import("../core/context.zig");
const scope_mod = @import("../core/scope.zig");
const result = @import("../core/result.zig");
const dep_services = @import("../dependency/services.zig");
const dep_report = @import("../dependency/report.zig");
const dep_contracts = @import("../dependency/contracts.zig");
const dep_narrowing = @import("../dependency/narrowing.zig");
const dep_validation = @import("../dependency/validation.zig");
const runtime_mod = @import("../runtime/runtime.zig");
const fiber_mod = @import("../runtime/fiber.zig");
const runner_mod = @import("../runtime/runner.zig");

pub const Allocator = dep_services.Allocator;
pub const Context = context_mod.Context;
pub const serviceNotFound = context_mod.serviceNotFound;
pub const Scope = scope_mod.Scope;
pub const Exit = result.Exit;
pub const finalizerExitFromExit = result.finalizerExitFromExit;
pub const exitWithFinalizerFailure = result.exitWithFinalizerFailure;
pub const ServiceSet = dep_services.ServiceSet;
pub const DependencyError = dep_services.DependencyError;
pub const DependencyReport = dep_report.DependencyReport;
pub const formatDependencyReport = dep_report.formatDependencyReport;
pub const assertEffectEnvironment = dep_contracts.assertEffectEnvironment;
pub const ServiceEnv = dep_narrowing.ServiceEnv;
pub const validateLayerRequirements = dep_validation.validateLayerRequirements;
pub const ensureLayerRequirements = dep_validation.ensureLayerRequirements;
pub const Runtime = runtime_mod.Runtime;
pub const FiberRuntime = fiber_mod.FiberRuntime;
pub const runManagedScope = runner_mod.runManagedScope;
pub const exitManagedScope = runner_mod.exitManagedScope;

pub const LayerGraph = struct {
    const Node = struct {
        name: []const u8,
        provides: ServiceSet,
        requires: ServiceSet,
        replaces: ServiceSet,
    };

    allocator: Allocator,
    nodes: std.ArrayList(Node) = .empty,

    pub fn init(allocator: Allocator) LayerGraph {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *LayerGraph) void {
        for (self.nodes.items) |*node| {
            node.provides.deinit();
            node.requires.deinit();
            node.replaces.deinit();
        }
        self.nodes.deinit(self.allocator);
    }

    pub fn addLayer(self: *LayerGraph, name: []const u8, layer: anytype) Allocator.Error!void {
        var provides = try layer.providedServices(self.allocator);
        errdefer provides.deinit();
        var requires = try layer.requiredServices(self.allocator);
        errdefer requires.deinit();
        var replaces = try layer.replacedServices(self.allocator);
        errdefer replaces.deinit();

        try self.nodes.append(self.allocator, .{
            .name = name,
            .provides = provides,
            .requires = requires,
            .replaces = replaces,
        });
    }

    pub fn validate(self: *const LayerGraph, allocator: Allocator) Allocator.Error!DependencyReport {
        var report = DependencyReport.init(allocator);
        errdefer report.deinit();

        var provided = ServiceSet.init(allocator);
        defer provided.deinit();
        var owners = std.StringHashMap([]const u8).init(allocator);
        defer owners.deinit();

        for (self.nodes.items) |node| {
            for (node.provides.names.items) |service| {
                if (provided.contains(service)) {
                    if (node.replaces.contains(service)) {
                        try owners.put(service, node.name);
                    } else {
                        try report.addDuplicate(node.name, service, owners.get(service) orelse "unknown");
                    }
                } else {
                    try provided.addName(service);
                    try owners.put(service, node.name);
                }
            }
        }

        for (self.nodes.items) |node| {
            for (node.requires.names.items) |service| {
                if (!provided.contains(service)) {
                    try report.addMissing(node.name, service);
                }
            }
        }

        return report;
    }
};

fn tupleFieldCount(comptime Tuple: type) usize {
    return std.meta.fields(Tuple).len;
}

fn layerEnvPointerTupleType(comptime Layers: type) type {
    const fields = std.meta.fields(Layers);
    comptime var types: [fields.len]type = undefined;
    inline for (fields, 0..) |field, index| {
        types[index] = *field.type.EnvType;
    }
    return std.meta.Tuple(&types);
}

fn layerGraphStartupErrorType(comptime Layers: type) type {
    const fields = std.meta.fields(Layers);
    comptime var StartupError = error{};
    inline for (fields) |field| {
        StartupError = StartupError || field.type.StartupErrorType;
    }
    return StartupError;
}

fn LayerGraphStartupEnv(comptime Layers: type) type {
    return struct {
        const Self = @This();
        pub const EnvPointersType = layerEnvPointerTupleType(Layers);
        pub const BuiltFlagsType = [tupleFieldCount(Layers)]bool;

        envs: *EnvPointersType,
        built: *const BuiltFlagsType,

        pub fn service(self: *Self, comptime Service: type) *Service {
            comptime var declared = false;
            const fields = std.meta.fields(Layers);

            comptime var reverse_index = fields.len;
            inline while (reverse_index > 0) {
                reverse_index -= 1;
                const field = fields[reverse_index];
                if (comptime layerProvidesService(field.type, Service)) {
                    declared = true;
                    if (self.built[reverse_index]) {
                        return @field(self.envs.*, field.name).service(Service);
                    }
                }
            }

            if (comptime declared) {
                @panic("zigeffect graph startup service requested before its provider layer started");
            }

            return serviceNotFound(Self, Service);
        }
    };
}

fn serviceTupleContains(comptime services: anytype, comptime Service: type) bool {
    inline for (services) |Declared| {
        if (Declared == Service) return true;
    }
    return false;
}

fn layerProvidesService(comptime LayerType: type, comptime Service: type) bool {
    if (!@hasDecl(LayerType, "ProvidedServices")) return false;
    return serviceTupleContains(LayerType.ProvidedServices, Service);
}

fn layerGraphNodeName(comptime LayerType: type) []const u8 {
    if (@hasDecl(LayerType, "Name")) return LayerType.Name;
    return @typeName(LayerType.EnvType);
}

fn graphDependencyError(report: *const DependencyReport) ?DependencyError {
    for (report.issues.items) |issue| {
        if (issue.kind == .duplicate_provider) return error.DuplicateServiceProvider;
    }
    for (report.issues.items) |issue| {
        if (issue.kind == .missing_requirement) return error.MissingServiceRequirement;
    }
    return null;
}

fn layerRequirementsSatisfied(allocator: Allocator, layer: anytype, provided: *const ServiceSet) Allocator.Error!bool {
    var required = try layer.requiredServices(allocator);
    defer required.deinit();

    for (required.names.items) |service| {
        if (!provided.contains(service)) return false;
    }
    return true;
}

pub fn LayerGraphEnv(comptime Layers: type) type {
    return struct {
        const Self = @This();
        pub const LayerTupleType = Layers;
        pub const EnvPointersType = layerEnvPointerTupleType(Layers);

        envs: EnvPointersType,

        pub fn service(self: *Self, comptime Service: type) *Service {
            const fields = std.meta.fields(Layers);

            comptime var reverse_index = fields.len;
            inline while (reverse_index > 0) {
                reverse_index -= 1;
                const field = fields[reverse_index];
                if (comptime layerProvidesService(field.type, Service)) {
                    return @field(self.envs, field.name).service(Service);
                }
            }
            return serviceNotFound(Self, Service);
        }
    };
}

pub fn LayerGraphRuntime(comptime Layers: type) type {
    return struct {
        const Self = @This();
        const LayerFields = std.meta.fields(Layers);
        pub const EnvType = LayerGraphEnv(Layers);
        pub const StartupErrorType = layerGraphStartupErrorType(Layers);
        pub const StartError = Allocator.Error || DependencyError || StartupErrorType;

        allocator: Allocator,
        layers: Layers,
        startup_scope: Scope,
        env: EnvType = undefined,
        started: bool = false,
        trace_id: ?u64 = null,
        span_id: ?u64 = null,

        pub fn init(allocator: Allocator, layers: Layers) Self {
            return .{
                .allocator = allocator,
                .layers = layers,
                .startup_scope = Scope.init(allocator),
            };
        }

        pub fn withTraceContext(self: Self, trace_id: u64, span_id: ?u64) Self {
            var graph_runtime = self;
            graph_runtime.trace_id = trace_id;
            graph_runtime.span_id = span_id;
            return graph_runtime;
        }

        pub fn deinit(self: *Self) void {
            self.startup_scope.deinit();
            self.started = false;
        }

        pub fn providedServices(self: *const Self, allocator: Allocator) Allocator.Error!ServiceSet {
            var provided = ServiceSet.init(allocator);
            errdefer provided.deinit();

            inline for (LayerFields) |field| {
                var layer_provided = try @field(self.layers, field.name).providedServices(allocator);
                defer layer_provided.deinit();
                try provided.mergeFrom(&layer_provided);
            }

            return provided;
        }

        pub fn requiredServices(self: *const Self, allocator: Allocator) Allocator.Error!ServiceSet {
            var required = ServiceSet.init(allocator);
            errdefer required.deinit();

            inline for (LayerFields) |field| {
                var layer_required = try @field(self.layers, field.name).requiredServices(allocator);
                defer layer_required.deinit();
                try required.mergeFrom(&layer_required);
            }

            return required;
        }

        pub fn validate(self: *const Self, allocator: Allocator) Allocator.Error!DependencyReport {
            var graph = LayerGraph.init(allocator);
            defer graph.deinit();

            inline for (LayerFields) |field| {
                try graph.addLayer(layerGraphNodeName(field.type), @field(self.layers, field.name));
            }

            return graph.validate(allocator);
        }

        pub fn report(self: *const Self, label: []const u8) Allocator.Error![]const u8 {
            var dependency_report = try self.validate(self.allocator);
            defer dependency_report.deinit();
            return formatDependencyReport(self.allocator, label, dependency_report);
        }

        fn ensureValid(self: *const Self) (Allocator.Error || DependencyError)!void {
            var dependency_report = try self.validate(self.allocator);
            defer dependency_report.deinit();

            if (graphDependencyError(&dependency_report)) |err| return err;
        }

        fn buildEnvs(self: *Self) StartError!EnvType.EnvPointersType {
            var envs: EnvType.EnvPointersType = undefined;
            var built = [_]bool{false} ** tupleFieldCount(Layers);
            var startup_env = LayerGraphStartupEnv(Layers){
                .envs = &envs,
                .built = &built,
            };
            var startup_ctx = Context(LayerGraphStartupEnv(Layers)).init(self.allocator, &startup_env, &self.startup_scope);
            startup_ctx.trace_id = self.trace_id;
            startup_ctx.span_id = self.span_id;
            var provided = ServiceSet.init(self.allocator);
            defer provided.deinit();

            var remaining = tupleFieldCount(Layers);
            while (remaining > 0) {
                var progressed = false;

                inline for (LayerFields, 0..) |field, index| {
                    if (!built[index]) {
                        const layer = @field(self.layers, field.name);
                        const ready = try layerRequirementsSatisfied(self.allocator, layer, &provided);
                        if (ready) {
                            @field(envs, field.name) = try layer.buildWithContext(self.allocator, &self.startup_scope, &startup_ctx);

                            var layer_provided = try layer.providedServices(self.allocator);
                            defer layer_provided.deinit();
                            try provided.mergeFrom(&layer_provided);

                            built[index] = true;
                            remaining -= 1;
                            progressed = true;
                        }
                    }
                }

                if (!progressed) return error.MissingServiceRequirement;
            }

            return envs;
        }

        pub fn start(self: *Self) StartError!*EnvType {
            if (self.started) return &self.env;

            try self.ensureValid();
            const envs = self.buildEnvs() catch |err| {
                self.startup_scope.closeWithExit(.{ .failure = @errorName(err) });
                self.startup_scope.deinit();
                self.startup_scope = Scope.init(self.allocator);
                return err;
            };

            self.env = .{ .envs = envs };
            self.started = true;
            return &self.env;
        }

        pub fn context(self: *Self, scope: *Scope) StartError!Context(EnvType) {
            const env = try self.start();
            var ctx = Context(EnvType).init(self.allocator, env, scope);
            ctx.trace_id = self.trace_id;
            ctx.span_id = self.span_id;
            return ctx;
        }

        pub fn runtime(self: *Self) StartError!Runtime(EnvType) {
            const env = try self.start();
            var regular_runtime = Runtime(EnvType).init(self.allocator, env).withProvider(self);
            if (self.trace_id) |trace_id| regular_runtime = regular_runtime.withTraceContext(trace_id, self.span_id);
            return regular_runtime;
        }

        pub fn fiberRuntime(self: *Self) StartError!FiberRuntime(EnvType) {
            const env = try self.start();
            var fiber_runtime = FiberRuntime(EnvType).init(self.allocator, env).withProvider(self);
            if (self.trace_id) |trace_id| fiber_runtime = fiber_runtime.withTraceContext(trace_id, self.span_id);
            return fiber_runtime;
        }

        pub fn run(
            self: *Self,
            effect: anytype,
        ) (StartError || @TypeOf(effect).FailureType)!@TypeOf(effect).SuccessType {
            assertEffectEnvironment("LayerGraphRuntime.run", EnvType, effect);
            try ensureLayerRequirements(self.allocator, self, effect);

            var scope = Scope.init(self.allocator);
            defer scope.deinit();

            var ctx = try self.context(&scope);
            return runManagedScope("LayerGraphRuntime.run", EnvType, &ctx, &scope, effect);
        }

        pub fn runNarrowed(
            self: *Self,
            comptime services: anytype,
            effect: anytype,
        ) (StartError || @TypeOf(effect).FailureType)!@TypeOf(effect).SuccessType {
            const NarrowEnv = ServiceEnv(services);
            assertEffectEnvironment("LayerGraphRuntime.runNarrowed", NarrowEnv, effect);
            try ensureLayerRequirements(self.allocator, self, effect);

            var scope = Scope.init(self.allocator);
            defer scope.deinit();

            var graph_ctx = try self.context(&scope);
            var narrow_env = NarrowEnv.fromContext(&graph_ctx);
            var ctx = Context(NarrowEnv).init(self.allocator, &narrow_env, &scope);
            return runManagedScope("LayerGraphRuntime.runNarrowed", NarrowEnv, &ctx, &scope, effect);
        }

        pub fn exit(self: *Self, effect: anytype) Exit(@TypeOf(effect).SuccessType, @TypeOf(effect).FailureType) {
            assertEffectEnvironment("LayerGraphRuntime.exit", EnvType, effect);
            var dependency_report = validateLayerRequirements(self.allocator, self, effect) catch
                return .{ .defect = "dependency validation allocation failed" };
            defer dependency_report.deinit();
            if (!dependency_report.isValid()) return .{ .defect = "missing service requirements" };

            var scope = Scope.init(self.allocator);
            defer scope.deinit();

            var ctx = self.context(&scope) catch |err|
                return .{ .defect = @errorName(err) };
            return exitManagedScope("LayerGraphRuntime.exit", EnvType, &ctx, &scope, effect);
        }

        pub fn exitNarrowed(
            self: *Self,
            comptime services: anytype,
            effect: anytype,
        ) Exit(@TypeOf(effect).SuccessType, @TypeOf(effect).FailureType) {
            const NarrowEnv = ServiceEnv(services);
            assertEffectEnvironment("LayerGraphRuntime.exitNarrowed", NarrowEnv, effect);
            var dependency_report = validateLayerRequirements(self.allocator, self, effect) catch
                return .{ .defect = "dependency validation allocation failed" };
            defer dependency_report.deinit();
            if (!dependency_report.isValid()) return .{ .defect = "missing service requirements" };

            var scope = Scope.init(self.allocator);
            defer scope.deinit();

            var graph_ctx = self.context(&scope) catch |err|
                return .{ .defect = @errorName(err) };
            var narrow_env = NarrowEnv.fromContext(&graph_ctx);
            var ctx = Context(NarrowEnv).init(self.allocator, &narrow_env, &scope);
            return exitManagedScope("LayerGraphRuntime.exitNarrowed", NarrowEnv, &ctx, &scope, effect);
        }
    };
}

pub fn layerGraph(allocator: Allocator, layers: anytype) LayerGraphRuntime(@TypeOf(layers)) {
    return LayerGraphRuntime(@TypeOf(layers)).init(allocator, layers);
}
