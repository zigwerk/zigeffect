const std = @import("std");
const context_mod = @import("../core/context.zig");
const scope_mod = @import("../core/scope.zig");
const dep_services = @import("../dependency/services.zig");
const dep_contracts = @import("../dependency/contracts.zig");
const dep_validation = @import("../dependency/validation.zig");
const runner_mod = @import("../runtime/runner.zig");

pub const Allocator = dep_services.Allocator;
pub const Context = context_mod.Context;
pub const Scope = scope_mod.Scope;
pub const ServiceSet = dep_services.ServiceSet;
pub const ServiceSetBuilder = dep_services.ServiceSetBuilder;
pub const DependencyError = dep_services.DependencyError;
pub const emptyServiceSet = dep_services.emptyServiceSet;
pub const serviceSetBuilder = dep_services.serviceSetBuilder;
pub const assertServiceTuple = dep_services.assertServiceTuple;
pub const assertEffectEnvironment = dep_contracts.assertEffectEnvironment;
pub const ensureLayerRequirements = dep_validation.ensureLayerRequirements;
pub const runManagedScope = runner_mod.runManagedScope;

fn mergeFunctionInfo(comptime Fn: type) std.builtin.Type.Fn {
    return switch (@typeInfo(Fn)) {
        .@"fn" => |fn_info| fn_info,
        .pointer => |pointer| switch (@typeInfo(pointer.child)) {
            .@"fn" => |fn_info| fn_info,
            else => @compileError(
                "zigeffect invalid layer merge function\n\n" ++
                    "Expected shape: fn (Allocator, *Scope, *LeftEnv, *RightEnv) Allocator.Error!*CombinedEnv.",
            ),
        },
        else => @compileError(
            "zigeffect invalid layer merge function\n\n" ++
                "Expected shape: fn (Allocator, *Scope, *LeftEnv, *RightEnv) Allocator.Error!*CombinedEnv.",
        ),
    };
}

fn assertMergeFunction(
    comptime LeftEnv: type,
    comptime RightEnv: type,
    comptime CombinedEnv: type,
    comptime combine: anytype,
) void {
    const fn_info = mergeFunctionInfo(@TypeOf(combine));
    if (fn_info.params.len != 4) {
        @compileError(
            "zigeffect invalid layer merge function\n\n" ++
                "Layer.merge combine functions must accept: Allocator, *Scope, *LeftEnv, *RightEnv.",
        );
    }
    if (fn_info.params[0].type == null or fn_info.params[0].type.? != Allocator) {
        @compileError("zigeffect invalid layer merge function\n\nFirst parameter must be std.mem.Allocator.");
    }
    if (fn_info.params[1].type == null or fn_info.params[1].type.? != *Scope) {
        @compileError("zigeffect invalid layer merge function\n\nSecond parameter must be *fx.Scope.");
    }
    if (fn_info.params[2].type == null or fn_info.params[2].type.? != *LeftEnv) {
        @compileError("zigeffect invalid layer merge function\n\nThird parameter must be *" ++ @typeName(LeftEnv) ++ ".");
    }
    if (fn_info.params[3].type == null or fn_info.params[3].type.? != *RightEnv) {
        @compileError("zigeffect invalid layer merge function\n\nFourth parameter must be *" ++ @typeName(RightEnv) ++ ".");
    }
    if (fn_info.return_type == null or fn_info.return_type.? != Allocator.Error!*CombinedEnv) {
        @compileError(
            "zigeffect invalid layer merge function\n\n" ++
                "Expected return type: " ++ @typeName(Allocator.Error!*CombinedEnv) ++ ".",
        );
    }
}

fn assertLayerEffect(
    comptime Env: type,
    comptime BuildError: type,
    comptime EffectType: type,
) void {
    if (!@hasDecl(EffectType, "SuccessType") or !@hasDecl(EffectType, "FailureType") or !@hasDecl(EffectType, "EnvType")) {
        @compileError(
            "zigeffect invalid layer effect\n\n" ++
                "Layer.fromEffect expects an effect-like value with SuccessType, FailureType, and EnvType declarations.",
        );
    }
    if (EffectType.SuccessType != *Env) {
        @compileError(
            "zigeffect invalid layer effect\n\n" ++
                "Layer.fromEffect startup effects must return " ++ @typeName(*Env) ++ ".",
        );
    }
    if (EffectType.FailureType != BuildError) {
        @compileError(
            "zigeffect invalid layer effect\n\n" ++
                "Layer.fromEffect startup effect failure type must be " ++ @typeName(BuildError) ++ ".",
        );
    }
    if (!@hasDecl(EffectType.EnvType, "fromContext")) {
        @compileError(
            "zigeffect invalid layer effect\n\n" ++
                "Layer.fromEffect startup effect environments must provide fromContext(ctx); use fx.ServiceEnv(.{ ... }) for graph startup dependencies.",
        );
    }
}

pub fn Layer(comptime Env: type) type {
    return LayerWithError(Env, error{});
}

pub fn LayerWithError(comptime Env: type, comptime StartupError: type) type {
    return struct {
        const Self = @This();
        pub const EnvType = Env;
        pub const StartupErrorType = StartupError;
        const BuildError = Allocator.Error || StartupError;
        const BuildFn = *const fn (Allocator, *Scope) BuildError!*Env;

        env: ?*Env = null,
        builder: ?BuildFn = null,
        provided_builder: ServiceSetBuilder = emptyServiceSet,
        required_builder: ServiceSetBuilder = emptyServiceSet,

        pub fn fromEnv(env: *Env) Self {
            return .{ .env = env };
        }

        pub fn fromBuilder(builder: BuildFn) Self {
            return .{ .builder = builder };
        }

        pub fn fromContextBuilder(comptime builder: anytype) ContextBuilderLayer(Env, StartupError, builder) {
            return .{};
        }

        pub fn fromEffect(effect: anytype) EffectLayer(Env, StartupError, @TypeOf(effect)) {
            assertLayerEffect(Env, BuildError, @TypeOf(effect));
            return .{ .effect = effect };
        }

        pub fn provides(self: Self, comptime services: anytype) ProvidedLayer(Self, services) {
            assertServiceTuple("Layer.provides", services);
            return .{ .inner = self };
        }

        pub fn requires(self: Self, comptime services: anytype) RequiredLayer(Self, services) {
            assertServiceTuple("Layer.requires", services);
            return .{ .inner = self };
        }

        pub fn replaces(self: Self, comptime services: anytype) ReplacementLayer(Self, services) {
            assertServiceTuple("Layer.replaces", services);
            return .{ .inner = self };
        }

        pub fn providedServices(self: Self, allocator: Allocator) Allocator.Error!ServiceSet {
            return self.provided_builder(allocator);
        }

        pub fn requiredServices(self: Self, allocator: Allocator) Allocator.Error!ServiceSet {
            return self.required_builder(allocator);
        }

        pub fn replacedServices(self: Self, allocator: Allocator) Allocator.Error!ServiceSet {
            _ = self;
            return emptyServiceSet(allocator);
        }

        pub fn build(self: Self, allocator: Allocator, scope: *Scope) BuildError!*Env {
            if (self.env) |env| return env;
            if (self.builder) |builder| return builder(allocator, scope);
            unreachable;
        }

        pub fn buildWithContext(self: Self, allocator: Allocator, scope: *Scope, ctx: anytype) BuildError!*Env {
            _ = ctx;
            return self.build(allocator, scope);
        }

        pub fn context(self: Self, allocator: Allocator, scope: ?*Scope) Context(Env) {
            return Context(Env).init(allocator, self.env orelse @panic("zigeffect Layer.context requires Layer.fromEnv; use buildContext for builder layers"), scope);
        }

        pub fn buildContext(self: Self, allocator: Allocator, scope: *Scope) BuildError!Context(Env) {
            return Context(Env).init(allocator, try self.build(allocator, scope), scope);
        }

        pub fn provide(
            self: Self,
            allocator: Allocator,
            effect: anytype,
        ) (BuildError || DependencyError || @TypeOf(effect).FailureType)!@TypeOf(effect).SuccessType {
            assertEffectEnvironment("Layer.provide", Env, effect);
            try ensureLayerRequirements(allocator, self, effect);

            var scope = Scope.init(allocator);
            defer scope.deinit();

            var ctx = try self.buildContext(allocator, &scope);
            return runManagedScope("Layer.provide", Env, &ctx, &scope, effect);
        }

        pub fn merge(
            self: Self,
            comptime OtherEnv: type,
            comptime CombinedEnv: type,
            other: Layer(OtherEnv),
            comptime combine: anytype,
        ) MergeLayer(Self, Layer(OtherEnv), CombinedEnv) {
            assertMergeFunction(Env, OtherEnv, CombinedEnv, combine);
            const typed: *const fn (Allocator, *Scope, *Env, *OtherEnv) Allocator.Error!*CombinedEnv = combine;
            return .{
                .left = self,
                .right = other,
                .combine = typed,
            };
        }
    };
}

pub fn EffectLayer(comptime Env: type, comptime StartupError: type, comptime EffectType: type) type {
    return struct {
        const Self = @This();
        pub const EnvType = Env;
        pub const StartupErrorType = StartupError;
        const BuildError = Allocator.Error || StartupError;

        effect: EffectType,

        pub fn provides(self: Self, comptime services: anytype) ProvidedLayer(Self, services) {
            assertServiceTuple("Layer.provides", services);
            return .{ .inner = self };
        }

        pub fn requires(self: Self, comptime services: anytype) RequiredLayer(Self, services) {
            assertServiceTuple("Layer.requires", services);
            return .{ .inner = self };
        }

        pub fn replaces(self: Self, comptime services: anytype) ReplacementLayer(Self, services) {
            assertServiceTuple("Layer.replaces", services);
            return .{ .inner = self };
        }

        pub fn providedServices(self: Self, allocator: Allocator) Allocator.Error!ServiceSet {
            _ = self;
            return emptyServiceSet(allocator);
        }

        pub fn requiredServices(self: Self, allocator: Allocator) Allocator.Error!ServiceSet {
            _ = self;
            if (@hasDecl(EffectType, "requiredServices")) {
                return EffectType.requiredServices(allocator);
            }
            return emptyServiceSet(allocator);
        }

        pub fn replacedServices(self: Self, allocator: Allocator) Allocator.Error!ServiceSet {
            _ = self;
            return emptyServiceSet(allocator);
        }

        pub fn build(self: Self, allocator: Allocator, scope: *Scope) BuildError!*Env {
            _ = self;
            _ = allocator;
            _ = scope;
            @compileError("Layer.fromEffect requires a graph startup context; use layerGraph or Layer.fromBuilder for context-free startup.");
        }

        pub fn buildWithContext(self: Self, allocator: Allocator, scope: *Scope, ctx: anytype) BuildError!*Env {
            const EffectEnv = EffectType.EnvType;
            var effect_env = EffectEnv.fromContext(ctx);
            var effect_ctx = Context(EffectEnv).init(allocator, &effect_env, scope);
            effect_ctx.clock = ctx.clock;
            effect_ctx.trace_id = ctx.trace_id;
            effect_ctx.span_id = ctx.span_id;
            effect_ctx.causal_store = ctx.causal_store;
            effect_ctx.causal_run_id = ctx.causal_run_id;
            effect_ctx.causal_parent_id = ctx.causal_parent_id;
            return effect_ctx.runEffect(self.effect);
        }
    };
}

pub fn ContextBuilderLayer(comptime Env: type, comptime StartupError: type, comptime builder: anytype) type {
    return struct {
        const Self = @This();
        pub const EnvType = Env;
        pub const StartupErrorType = StartupError;
        const BuildError = Allocator.Error || StartupError;

        pub fn provides(self: Self, comptime services: anytype) ProvidedLayer(Self, services) {
            assertServiceTuple("Layer.provides", services);
            return .{ .inner = self };
        }

        pub fn requires(self: Self, comptime services: anytype) RequiredLayer(Self, services) {
            assertServiceTuple("Layer.requires", services);
            return .{ .inner = self };
        }

        pub fn replaces(self: Self, comptime services: anytype) ReplacementLayer(Self, services) {
            assertServiceTuple("Layer.replaces", services);
            return .{ .inner = self };
        }

        pub fn providedServices(self: Self, allocator: Allocator) Allocator.Error!ServiceSet {
            _ = self;
            return emptyServiceSet(allocator);
        }

        pub fn requiredServices(self: Self, allocator: Allocator) Allocator.Error!ServiceSet {
            _ = self;
            return emptyServiceSet(allocator);
        }

        pub fn replacedServices(self: Self, allocator: Allocator) Allocator.Error!ServiceSet {
            _ = self;
            return emptyServiceSet(allocator);
        }

        pub fn buildWithContext(self: Self, allocator: Allocator, scope: *Scope, ctx: anytype) BuildError!*Env {
            _ = self;
            return builder(allocator, scope, ctx);
        }
    };
}

pub fn ProvidedLayer(comptime Inner: type, comptime Provided: anytype) type {
    return struct {
        const Self = @This();
        pub const EnvType = Inner.EnvType;
        pub const StartupErrorType = Inner.StartupErrorType;
        pub const ProvidedServices = Provided;
        const BuildError = Allocator.Error || StartupErrorType;

        inner: Inner,

        pub fn provides(self: Self, comptime services: anytype) ProvidedLayer(Inner, services) {
            assertServiceTuple("Layer.provides", services);
            return .{ .inner = self.inner };
        }

        pub fn requires(self: Self, comptime services: anytype) ProvidedLayer(RequiredLayer(Inner, services), Provided) {
            assertServiceTuple("Layer.requires", services);
            return .{ .inner = self.inner.requires(services) };
        }

        pub fn replaces(self: Self, comptime services: anytype) ReplacementLayer(Self, services) {
            assertServiceTuple("Layer.replaces", services);
            return .{ .inner = self };
        }

        pub fn providedServices(self: Self, allocator: Allocator) Allocator.Error!ServiceSet {
            _ = self;
            return ServiceSet.fromTypes(allocator, Provided);
        }

        pub fn requiredServices(self: Self, allocator: Allocator) Allocator.Error!ServiceSet {
            return self.inner.requiredServices(allocator);
        }

        pub fn replacedServices(self: Self, allocator: Allocator) Allocator.Error!ServiceSet {
            return self.inner.replacedServices(allocator);
        }

        pub fn build(self: Self, allocator: Allocator, scope: *Scope) BuildError!*EnvType {
            return self.inner.build(allocator, scope);
        }

        pub fn buildWithContext(self: Self, allocator: Allocator, scope: *Scope, ctx: anytype) BuildError!*EnvType {
            if (@hasDecl(Inner, "buildWithContext")) {
                return self.inner.buildWithContext(allocator, scope, ctx);
            }
            return self.inner.build(allocator, scope);
        }

        pub fn context(self: Self, allocator: Allocator, scope: ?*Scope) Context(EnvType) {
            return self.inner.context(allocator, scope);
        }

        pub fn buildContext(self: Self, allocator: Allocator, scope: *Scope) BuildError!Context(EnvType) {
            return Context(EnvType).init(allocator, try self.build(allocator, scope), scope);
        }

        pub fn provide(
            self: Self,
            allocator: Allocator,
            effect: anytype,
        ) (BuildError || DependencyError || @TypeOf(effect).FailureType)!@TypeOf(effect).SuccessType {
            assertEffectEnvironment("Layer.provide", EnvType, effect);
            try ensureLayerRequirements(allocator, self, effect);

            var scope = Scope.init(allocator);
            defer scope.deinit();

            var ctx = try self.buildContext(allocator, &scope);
            return runManagedScope("Layer.provide", EnvType, &ctx, &scope, effect);
        }

        pub fn merge(
            self: Self,
            comptime OtherEnv: type,
            comptime CombinedEnv: type,
            other: anytype,
            comptime combine: anytype,
        ) MergeLayer(Self, @TypeOf(other), CombinedEnv) {
            assertMergeFunction(EnvType, OtherEnv, CombinedEnv, combine);
            const typed: *const fn (Allocator, *Scope, *EnvType, *OtherEnv) Allocator.Error!*CombinedEnv = combine;
            return .{
                .left = self,
                .right = other,
                .combine = typed,
            };
        }
    };
}

pub fn RequiredLayer(comptime Inner: type, comptime Required: anytype) type {
    return struct {
        const Self = @This();
        pub const EnvType = Inner.EnvType;
        pub const StartupErrorType = Inner.StartupErrorType;
        pub const RequiredServices = Required;
        const BuildError = Allocator.Error || StartupErrorType;

        inner: Inner,

        pub fn provides(self: Self, comptime services: anytype) ProvidedLayer(Self, services) {
            assertServiceTuple("Layer.provides", services);
            return .{ .inner = self };
        }

        pub fn requires(self: Self, comptime services: anytype) RequiredLayer(Inner, services) {
            assertServiceTuple("Layer.requires", services);
            return .{ .inner = self.inner };
        }

        pub fn replaces(self: Self, comptime services: anytype) ReplacementLayer(Self, services) {
            assertServiceTuple("Layer.replaces", services);
            return .{ .inner = self };
        }

        pub fn providedServices(self: Self, allocator: Allocator) Allocator.Error!ServiceSet {
            return self.inner.providedServices(allocator);
        }

        pub fn requiredServices(self: Self, allocator: Allocator) Allocator.Error!ServiceSet {
            _ = self;
            return ServiceSet.fromTypes(allocator, Required);
        }

        pub fn replacedServices(self: Self, allocator: Allocator) Allocator.Error!ServiceSet {
            return self.inner.replacedServices(allocator);
        }

        pub fn build(self: Self, allocator: Allocator, scope: *Scope) BuildError!*EnvType {
            return self.inner.build(allocator, scope);
        }

        pub fn buildWithContext(self: Self, allocator: Allocator, scope: *Scope, ctx: anytype) BuildError!*EnvType {
            if (@hasDecl(Inner, "buildWithContext")) {
                return self.inner.buildWithContext(allocator, scope, ctx);
            }
            return self.inner.build(allocator, scope);
        }

        pub fn context(self: Self, allocator: Allocator, scope: ?*Scope) Context(EnvType) {
            return self.inner.context(allocator, scope);
        }

        pub fn buildContext(self: Self, allocator: Allocator, scope: *Scope) BuildError!Context(EnvType) {
            return Context(EnvType).init(allocator, try self.build(allocator, scope), scope);
        }

        pub fn provide(
            self: Self,
            allocator: Allocator,
            effect: anytype,
        ) (BuildError || DependencyError || @TypeOf(effect).FailureType)!@TypeOf(effect).SuccessType {
            assertEffectEnvironment("Layer.provide", EnvType, effect);
            try ensureLayerRequirements(allocator, self, effect);

            var scope = Scope.init(allocator);
            defer scope.deinit();

            var ctx = try self.buildContext(allocator, &scope);
            return runManagedScope("Layer.provide", EnvType, &ctx, &scope, effect);
        }

        pub fn merge(
            self: Self,
            comptime OtherEnv: type,
            comptime CombinedEnv: type,
            other: anytype,
            comptime combine: anytype,
        ) MergeLayer(Self, @TypeOf(other), CombinedEnv) {
            assertMergeFunction(EnvType, OtherEnv, CombinedEnv, combine);
            const typed: *const fn (Allocator, *Scope, *EnvType, *OtherEnv) Allocator.Error!*CombinedEnv = combine;
            return .{
                .left = self,
                .right = other,
                .combine = typed,
            };
        }
    };
}

pub fn ReplacementLayer(comptime Inner: type, comptime Replaced: anytype) type {
    return struct {
        const Self = @This();
        pub const EnvType = Inner.EnvType;
        pub const StartupErrorType = Inner.StartupErrorType;
        pub const ReplacedServices = Replaced;
        pub const ProvidedServices = if (@hasDecl(Inner, "ProvidedServices")) Inner.ProvidedServices else .{};
        const BuildError = Allocator.Error || StartupErrorType;

        inner: Inner,

        pub fn provides(self: Self, comptime services: anytype) ProvidedLayer(Self, services) {
            assertServiceTuple("Layer.provides", services);
            return .{ .inner = self };
        }

        pub fn requires(self: Self, comptime services: anytype) RequiredLayer(Self, services) {
            assertServiceTuple("Layer.requires", services);
            return .{ .inner = self };
        }

        pub fn replaces(self: Self, comptime services: anytype) ReplacementLayer(Self, services) {
            assertServiceTuple("Layer.replaces", services);
            return .{ .inner = self };
        }

        pub fn providedServices(self: Self, allocator: Allocator) Allocator.Error!ServiceSet {
            return self.inner.providedServices(allocator);
        }

        pub fn requiredServices(self: Self, allocator: Allocator) Allocator.Error!ServiceSet {
            return self.inner.requiredServices(allocator);
        }

        pub fn replacedServices(self: Self, allocator: Allocator) Allocator.Error!ServiceSet {
            var replaced = try self.inner.replacedServices(allocator);
            errdefer replaced.deinit();
            var current = try ServiceSet.fromTypes(allocator, Replaced);
            defer current.deinit();
            try replaced.mergeFrom(&current);
            return replaced;
        }

        pub fn build(self: Self, allocator: Allocator, scope: *Scope) BuildError!*EnvType {
            return self.inner.build(allocator, scope);
        }

        pub fn buildWithContext(self: Self, allocator: Allocator, scope: *Scope, ctx: anytype) BuildError!*EnvType {
            if (@hasDecl(Inner, "buildWithContext")) {
                return self.inner.buildWithContext(allocator, scope, ctx);
            }
            return self.inner.build(allocator, scope);
        }

        pub fn context(self: Self, allocator: Allocator, scope: ?*Scope) Context(EnvType) {
            return self.inner.context(allocator, scope);
        }

        pub fn buildContext(self: Self, allocator: Allocator, scope: *Scope) BuildError!Context(EnvType) {
            return Context(EnvType).init(allocator, try self.build(allocator, scope), scope);
        }

        pub fn provide(
            self: Self,
            allocator: Allocator,
            effect: anytype,
        ) (BuildError || DependencyError || @TypeOf(effect).FailureType)!@TypeOf(effect).SuccessType {
            assertEffectEnvironment("Layer.provide", EnvType, effect);
            try ensureLayerRequirements(allocator, self, effect);

            var scope = Scope.init(allocator);
            defer scope.deinit();

            var ctx = try self.buildContext(allocator, &scope);
            return runManagedScope("Layer.provide", EnvType, &ctx, &scope, effect);
        }

        pub fn merge(
            self: Self,
            comptime OtherEnv: type,
            comptime CombinedEnv: type,
            other: anytype,
            comptime combine: anytype,
        ) MergeLayer(Self, @TypeOf(other), CombinedEnv) {
            assertMergeFunction(EnvType, OtherEnv, CombinedEnv, combine);
            const typed: *const fn (Allocator, *Scope, *EnvType, *OtherEnv) Allocator.Error!*CombinedEnv = combine;
            return .{
                .left = self,
                .right = other,
                .combine = typed,
            };
        }
    };
}

pub fn MergeLayer(comptime LeftLayer: type, comptime RightLayer: type, comptime Env: type) type {
    return struct {
        const Self = @This();
        pub const EnvType = Env;
        pub const StartupErrorType = LeftLayer.StartupErrorType || RightLayer.StartupErrorType;
        const BuildError = Allocator.Error || StartupErrorType;

        left: LeftLayer,
        right: RightLayer,
        combine: *const fn (Allocator, *Scope, *LeftLayer.EnvType, *RightLayer.EnvType) Allocator.Error!*Env,

        pub fn providedServices(self: Self, allocator: Allocator) Allocator.Error!ServiceSet {
            var provided = ServiceSet.init(allocator);
            errdefer provided.deinit();

            var left = try self.left.providedServices(allocator);
            defer left.deinit();
            var right = try self.right.providedServices(allocator);
            defer right.deinit();
            try provided.mergeFrom(&left);
            try provided.mergeFrom(&right);
            return provided;
        }

        pub fn requiredServices(self: Self, allocator: Allocator) Allocator.Error!ServiceSet {
            var required = ServiceSet.init(allocator);
            errdefer required.deinit();

            var left = try self.left.requiredServices(allocator);
            defer left.deinit();
            var right = try self.right.requiredServices(allocator);
            defer right.deinit();
            try required.mergeFrom(&left);
            try required.mergeFrom(&right);
            return required;
        }

        pub fn replacedServices(self: Self, allocator: Allocator) Allocator.Error!ServiceSet {
            var replaced = ServiceSet.init(allocator);
            errdefer replaced.deinit();

            var left = try self.left.replacedServices(allocator);
            defer left.deinit();
            var right = try self.right.replacedServices(allocator);
            defer right.deinit();
            try replaced.mergeFrom(&left);
            try replaced.mergeFrom(&right);
            return replaced;
        }

        pub fn replaces(self: Self, comptime services: anytype) ReplacementLayer(Self, services) {
            assertServiceTuple("Layer.replaces", services);
            return .{ .inner = self };
        }

        pub fn build(self: Self, allocator: Allocator, scope: *Scope) BuildError!*Env {
            const left_env = try self.left.build(allocator, scope);
            const right_env = try self.right.build(allocator, scope);
            return self.combine(allocator, scope, left_env, right_env);
        }

        pub fn buildWithContext(self: Self, allocator: Allocator, scope: *Scope, ctx: anytype) BuildError!*Env {
            const left_env = if (@hasDecl(LeftLayer, "buildWithContext"))
                try self.left.buildWithContext(allocator, scope, ctx)
            else
                try self.left.build(allocator, scope);
            const right_env = if (@hasDecl(RightLayer, "buildWithContext"))
                try self.right.buildWithContext(allocator, scope, ctx)
            else
                try self.right.build(allocator, scope);
            return self.combine(allocator, scope, left_env, right_env);
        }

        pub fn buildContext(self: Self, allocator: Allocator, scope: *Scope) BuildError!Context(Env) {
            return Context(Env).init(allocator, try self.build(allocator, scope), scope);
        }

        pub fn provide(
            self: Self,
            allocator: Allocator,
            effect: anytype,
        ) (BuildError || DependencyError || @TypeOf(effect).FailureType)!@TypeOf(effect).SuccessType {
            assertEffectEnvironment("Layer.provide", Env, effect);
            try ensureLayerRequirements(allocator, self, effect);

            var scope = Scope.init(allocator);
            defer scope.deinit();

            var ctx = try self.buildContext(allocator, &scope);
            return runManagedScope("Layer.provide", Env, &ctx, &scope, effect);
        }
    };
}
