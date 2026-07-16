const std = @import("std");
const context_mod = @import("context.zig");
const layer_mod = @import("layer.zig");
const result_mod = @import("../core/result.zig");
const clock_mod = @import("../services/clock.zig");
const causal_mod = @import("../services/causal.zig");
const defaults_mod = @import("default_services.zig");
const aspects_mod = @import("aspects.zig");
const topology_mod = @import("topology.zig");
const application_mod = @import("application.zig");

pub const Allocator = std.mem.Allocator;
pub const RuntimeCore = context_mod.RuntimeCore;
pub const RuntimeContext = context_mod.RuntimeContext;
pub const RuntimeAspect = context_mod.RuntimeAspect;
pub const Clock = clock_mod.Clock;
pub const CausalStore = causal_mod.CausalStore;

pub const ManagedRuntimeOptions = struct {
    causal_store: ?*CausalStore = null,
    causal_options: causal_mod.CausalStoreOptions = .{
        .max_events = 4096,
        .max_event_string_bytes = 512,
    },
    aspects: []const RuntimeAspect = &.{},
    observability: aspects_mod.RuntimeObservability = .{},
    defaults: ?defaults_mod.DefaultServices = null,
    causal_context: causal_mod.CausalContextV2 = .{},
};

pub fn ManagedRuntime(comptime RootLayer: type) type {
    return struct {
        const Self = @This();
        pub const OutputServices = RootLayer.OutputServices;
        pub const MakeError = RootLayer.BuildError || Allocator.Error;
        pub const Handle = context_mod.RuntimeHandle(OutputServices);

        root_layer: RootLayer,
        core: ?*RuntimeCore,

        pub fn make(allocator: Allocator, root_layer: RootLayer, options: ManagedRuntimeOptions) MakeError!Self {
            if (comptime !@import("service.zig").subset(RootLayer.InputServices, .{})) {
                @compileError(
                    "zigeffect ManagedRuntime root layer has unsatisfied inputs; " ++
                        "wire them explicitly with Layer.provide",
                );
            }

            const owned_defaults = if (options.defaults == null) try allocator.create(defaults_mod.OwnedDefaults) else null;
            if (owned_defaults) |owned| owned.* = defaults_mod.OwnedDefaults.init(allocator);
            errdefer if (owned_defaults) |owned| {
                owned.deinit();
                allocator.destroy(owned);
            };
            const defaults = options.defaults orelse owned_defaults.?.services();

            const owned_causal_store = if (options.causal_store == null) try allocator.create(CausalStore) else null;
            if (owned_causal_store) |owned| owned.* = CausalStore.initWithOptions(allocator, options.causal_options);
            errdefer if (owned_causal_store) |owned| {
                owned.deinit();
                allocator.destroy(owned);
            };
            const causal_store = options.causal_store orelse owned_causal_store.?;

            const aspects = try aspects_mod.assemble(
                allocator,
                options.aspects,
                options.observability,
                causal_store,
            );
            errdefer allocator.free(aspects);

            const core = try allocator.create(RuntimeCore);
            errdefer allocator.destroy(core);
            core.* = .{
                .allocator = allocator,
                .registry = @import("service.zig").Registry.init(allocator),
                .application_scope = @import("../core/scope.zig").Scope.init(allocator),
                .memo = std.AutoHashMap(u64, void).init(allocator),
                .topology = topology_mod.Topology.init(allocator),
                .root_layer_type = @typeName(RootLayer),
                .defaults = defaults,
                .owned_defaults = owned_defaults,
                .causal_store = causal_store,
                .causal_context = options.causal_context,
                .owned_causal_store = owned_causal_store,
                .aspects = aspects,
            };
            errdefer {
                core.application_scope.deinit();
                core.memo.deinit();
                core.topology.deinit();
                core.registry.deinit();
            }

            const startup_run_id = causal_store.nextRunId();
            core.application_scope.attachRuntimeSignal(core.signalSink(), startup_run_id, null, null, null);
            var context = RuntimeContext{
                .core = core,
                .scope = &core.application_scope,
                .causal_run_id = startup_run_id,
                .causal_context = options.causal_context,
            };
            const runtime_started = context.emit(.{
                .kind = .runtime_started,
                .label = "ManagedRuntime.make",
                .status = "starting",
            });
            context.causal_parent_id = runtime_started;

            var build_context = layer_mod.BuildContext{
                .runtime = &context,
                .memo = &core.memo,
                .topology = &core.topology,
            };
            root_layer.build(&build_context) catch |failure| {
                core.application_scope.closeWithExit(.{ .failure = @errorName(failure) });
                return failure;
            };
            try core.topology.markRootOutputs(RootLayer.OutputServices);
            _ = context.emit(.{
                .kind = .runtime_completed,
                .label = "ManagedRuntime.make",
                .status = "ready",
            });
            return .{ .root_layer = root_layer, .core = core };
        }

        pub fn deinit(self: *Self) void {
            const core = self.core orelse return;
            self.core = null;
            core.disposed = true;

            const shutdown_run_id = core.causal_store.nextRunId();
            var context = RuntimeContext{
                .core = core,
                .scope = &core.application_scope,
                .causal_run_id = shutdown_run_id,
                .causal_context = core.causal_context,
            };
            _ = context.emit(.{
                .kind = .runtime_started,
                .label = "ManagedRuntime.dispose",
                .status = "disposing",
            });
            core.application_scope.closeWithExit(.success);
            _ = context.emit(.{
                .kind = .runtime_completed,
                .label = "ManagedRuntime.dispose",
                .status = "disposed",
            });
            core.application_scope.deinit();
            core.memo.deinit();
            core.topology.deinit();
            core.registry.deinit();
            core.allocator.free(core.aspects);
            if (core.owned_defaults) |owned| {
                owned.deinit();
                core.allocator.destroy(owned);
            }
            if (core.owned_causal_store) |owned| {
                owned.deinit();
                core.allocator.destroy(owned);
            }
            core.allocator.destroy(core);
        }

        pub fn handle(self: *Self) Handle {
            const core = self.core orelse @panic("zigeffect ManagedRuntime has already been disposed");
            return .{ .core = core, .causal_context = core.causal_context };
        }

        pub fn runWithCausalContext(
            self: *Self,
            effect: anytype,
            context: causal_mod.CausalContextV2,
        ) @TypeOf(effect).FailureType!@TypeOf(effect).SuccessType {
            var runtime_handle = self.handle().withCausalContext(context);
            return runtime_handle.run(effect);
        }

        pub fn run(self: *Self, effect: anytype) @TypeOf(effect).FailureType!@TypeOf(effect).SuccessType {
            var runtime_handle = self.handle();
            return runtime_handle.run(effect);
        }

        pub fn inspect(
            self: *Self,
            allocator: Allocator,
            options: application_mod.InspectOptions,
        ) Allocator.Error!application_mod.ApplicationSnapshot {
            var runtime_handle = self.handle();
            return runtime_handle.inspect(allocator, options);
        }

        pub fn inspectJson(
            self: *Self,
            allocator: Allocator,
            options: application_mod.InspectOptions,
        ) Allocator.Error![]u8 {
            var runtime_handle = self.handle();
            return runtime_handle.inspectJson(allocator, options);
        }

        pub fn exit(self: *Self, effect: anytype) result_mod.Exit(@TypeOf(effect).SuccessType, @TypeOf(effect).FailureType) {
            const value = self.run(effect) catch |failure| return .{ .failure = failure };
            return .{ .success = value };
        }
    };
}
