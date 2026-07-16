const std = @import("std");
const service_mod = @import("service.zig");
const scope_mod = @import("../core/scope.zig");
const clock_mod = @import("../services/clock.zig");
const causal_mod = @import("../services/causal.zig");
const defaults_mod = @import("default_services.zig");
const runtime_signal_mod = @import("../core/runtime_signal.zig");
const topology_mod = @import("topology.zig");
const application_mod = @import("application.zig");
const identity_mod = @import("../core/runtime_identity.zig");
const result_mod = @import("../core/result.zig");
const executor_mod = @import("../runtime/executor.zig");
const backend_mod = @import("../runtime/backend.zig");
const async_backend_mod = @import("../runtime/async_backend.zig");

pub const Allocator = std.mem.Allocator;
pub const Registry = service_mod.Registry;
pub const Scope = scope_mod.Scope;
pub const Clock = clock_mod.Clock;
pub const CausalStore = causal_mod.CausalStore;
pub const DefaultServices = defaults_mod.DefaultServices;
pub const DefaultOverrides = defaults_mod.DefaultOverrides;

pub const RuntimeEventKind = runtime_signal_mod.RuntimeEventKind;
pub const RuntimeEvent = runtime_signal_mod.RuntimeEvent;
pub const RuntimeAspect = runtime_signal_mod.RuntimeAspect;
pub const RuntimeSignalSink = runtime_signal_mod.RuntimeSignalSink;
pub const FiberExecutor = executor_mod.FiberExecutor;
pub const FiberJob = executor_mod.FiberJob;
pub const BackendCapabilities = backend_mod.BackendCapabilities;
pub const AsyncBackend = async_backend_mod.AsyncBackend;

/// Heap-stable state shared by every run and runtime handle derived from one
/// ManagedRuntime. The core is immutable after layer startup except for the
/// memo table during construction and explicit runtime disposal.
pub const RuntimeCore = struct {
    allocator: Allocator,
    registry: Registry,
    application_scope: Scope,
    memo: std.AutoHashMap(u64, void),
    topology: topology_mod.Topology,
    root_layer_type: []const u8,
    defaults: DefaultServices,
    owned_defaults: ?*defaults_mod.OwnedDefaults = null,
    causal_store: *CausalStore,
    causal_context: causal_mod.CausalContextV2 = .{},
    owned_causal_store: ?*CausalStore = null,
    aspects: []const RuntimeAspect = &.{},
    backend: BackendCapabilities = backend_mod.deterministicBackend(),
    async_backend: ?AsyncBackend = null,
    executor: ?FiberExecutor = null,
    next_fiber_id: std.atomic.Value(u64) = std.atomic.Value(u64).init(1),
    disposed: bool = false,

    pub fn emit(self: *RuntimeCore, event: RuntimeEvent) ?u64 {
        var lineage_id: ?u64 = null;
        for (self.aspects) |aspect| {
            lineage_id = aspect.on_event(aspect.state, event) orelse lineage_id;
        }
        return lineage_id;
    }

    pub fn emitCausal(self: *RuntimeCore, event: causal_mod.CausalEvent) ?u64 {
        var lineage_id: ?u64 = null;
        for (self.aspects) |aspect| {
            const emit_causal = aspect.on_causal_event orelse continue;
            lineage_id = emit_causal(aspect.state, event) orelse lineage_id;
        }
        return lineage_id;
    }

    pub fn signalSink(self: *RuntimeCore) RuntimeSignalSink {
        return .{
            .state = self,
            .emit_event = struct {
                fn call(raw: *anyopaque, event: RuntimeEvent) ?u64 {
                    const core: *RuntimeCore = @ptrCast(@alignCast(raw));
                    return core.emit(event);
                }
            }.call,
            .next_scope_id = struct {
                fn call(raw: *anyopaque) u64 {
                    const core: *RuntimeCore = @ptrCast(@alignCast(raw));
                    return core.causal_store.nextScopeId();
                }
            }.call,
            .next_resource_id = struct {
                fn call(raw: *anyopaque) u64 {
                    const core: *RuntimeCore = @ptrCast(@alignCast(raw));
                    return core.causal_store.nextResourceId();
                }
            }.call,
        };
    }
};

pub const RuntimeContext = struct {
    core: *RuntimeCore,
    scope: *Scope,
    default_overrides: DefaultOverrides = .{},
    causal_run_id: ?u64 = null,
    causal_parent_id: ?u64 = null,
    fiber_id: ?u64 = null,
    causal_context: causal_mod.CausalContextV2 = .{},

    pub fn emit(self: *RuntimeContext, event: RuntimeEvent) ?u64 {
        var enriched = event;
        enriched.run_id = enriched.run_id orelse self.causal_run_id;
        enriched.parent_id = enriched.parent_id orelse self.causal_parent_id;
        enriched.fiber_id = enriched.fiber_id orelse self.fiber_id;
        enriched.scope_id = enriched.scope_id orelse self.scope.causal_scope_id;
        enriched.trace_id = enriched.trace_id orelse self.scope.causal_trace_id;
        enriched.span_id = enriched.span_id orelse self.scope.causal_span_id;

        return self.core.emit(enriched);
    }

    pub fn recordCausal(self: *RuntimeContext, event: causal_mod.CausalEvent) ?u64 {
        var enriched = event;
        enriched.run_id = enriched.run_id orelse self.causal_run_id;
        enriched.parent_id = enriched.parent_id orelse self.causal_parent_id;
        enriched.fiber_id = enriched.fiber_id orelse self.fiber_id;
        enriched.scope_id = enriched.scope_id orelse self.scope.causal_scope_id;
        enriched.trace_id = enriched.trace_id orelse self.scope.causal_trace_id;
        enriched.span_id = enriched.span_id orelse self.scope.causal_span_id;
        enriched.context = causal_mod.CausalContextV2.merge(self.causal_context, enriched.context);
        enriched.context.trace_id_low = enriched.context.trace_id_low orelse enriched.trace_id;
        enriched.context.span_id = enriched.context.span_id orelse enriched.span_id;
        enriched.trace_id = enriched.trace_id orelse enriched.context.trace_id_low;
        enriched.span_id = enriched.span_id orelse enriched.context.span_id;
        return self.core.emitCausal(enriched);
    }
};

pub fn ContextView(comptime Requirements: anytype) type {
    return struct {
        const Self = @This();
        pub const RequiredServices = Requirements;

        runtime_context: *RuntimeContext,

        pub fn allocator(self: *const Self) Allocator {
            return self.runtime_context.core.allocator;
        }

        pub fn scope(self: *const Self) *Scope {
            return self.runtime_context.scope;
        }

        pub fn clock(self: *const Self) *Clock {
            return self.runtime_context.default_overrides.clock orelse self.runtime_context.core.defaults.clock;
        }

        pub fn configProvider(self: *const Self) defaults_mod.ConfigProvider {
            return self.runtime_context.default_overrides.config_provider orelse self.runtime_context.core.defaults.config_provider;
        }

        pub fn console(self: *const Self) defaults_mod.Console {
            return self.runtime_context.default_overrides.console orelse self.runtime_context.core.defaults.console;
        }

        pub fn random(self: *const Self) defaults_mod.Random {
            return self.runtime_context.default_overrides.random orelse self.runtime_context.core.defaults.random;
        }

        pub fn tracer(self: *const Self) defaults_mod.Tracer {
            return self.runtime_context.default_overrides.tracer orelse self.runtime_context.core.defaults.tracer;
        }

        /// The runtime's selected execution strategy. `null` is the canonical
        /// deterministic, synchronous interpreter; adapters such as
        /// zigeffect-zio install a real executor once at runtime construction.
        pub fn executor(self: *const Self) ?FiberExecutor {
            return self.runtime_context.core.executor;
        }

        /// The runtime-owned async suspension backend, when the selected
        /// execution strategy supports timers, IO waits, and interruption.
        pub fn asyncBackend(self: *const Self) ?AsyncBackend {
            return self.runtime_context.core.async_backend;
        }

        pub fn backendCapabilities(self: *const Self) BackendCapabilities {
            return self.runtime_context.core.backend;
        }

        /// Record a semantic fact through every runtime aspect. The runtime
        /// supplies run/fiber/scope lineage while preserving explicit parent,
        /// cause, boundary, trace, and domain references from the caller.
        pub fn recordCausal(self: *const Self, event: causal_mod.CausalEvent) ?u64 {
            return self.runtime_context.recordCausal(event);
        }

        /// Derive a recording-only capability for long-lived transport and
        /// platform adapters acquired by a layer. The managed runtime retains
        /// ownership of the store and its durable backend.
        pub fn causalRecorder(self: *const Self) causal_mod.CausalRecorder {
            return causal_mod.CausalRecorder.fromStore(self.runtime_context.core.causal_store);
        }

        /// Derive a reusable interpreter handle limited to this effect's
        /// declared requirements. Long-lived servers and workers use it to run
        /// each request/job in a fresh child scope without rebuilding layers.
        pub fn runtime(self: *const Self) RuntimeHandle(Requirements) {
            return .{
                .core = self.runtime_context.core,
                .default_overrides = self.runtime_context.default_overrides,
                .causal_parent_id = self.runtime_context.causal_parent_id,
                .causal_context = self.runtime_context.causal_context,
            };
        }

        pub fn inspectApplication(
            self: *const Self,
            target_allocator: Allocator,
            options: application_mod.InspectOptions,
        ) Allocator.Error!application_mod.ApplicationSnapshot {
            return application_mod.ApplicationSnapshot.capture(
                target_allocator,
                &self.runtime_context.core.topology,
                self.runtime_context.core.root_layer_type,
                self.runtime_context.core.causal_store,
                options,
            );
        }

        pub fn service(self: *Self, comptime Tag: type) *Tag.API {
            if (comptime !service_mod.contains(Requirements, Tag)) {
                @compileError(
                    "zigeffect undeclared service requirement\n\nservice: " ++
                        Tag.service_key ++
                        "\n\nAdd the service tag to Effect(..., Requirements).",
                );
            }

            const resolved = self.runtime_context.core.registry.get(Tag) catch {
                @panic("zigeffect runtime invariant violated: required service is missing");
            };
            _ = self.runtime_context.emit(.{
                .kind = .service_required,
                .label = "Context.service",
                .service_key = Tag.service_key,
                .type_name = identity_mod.boundedTypeName(Tag.API),
                .status = "resolved",
            });
            return resolved;
        }
    };
}

pub fn RuntimeHandle(comptime AvailableServices: anytype) type {
    return struct {
        const Self = @This();
        pub const Services = AvailableServices;

        core: *RuntimeCore,
        default_overrides: DefaultOverrides = .{},
        causal_parent_id: ?u64 = null,
        causal_context: causal_mod.CausalContextV2 = .{},

        /// Derive a handle whose runs inherit proof-carrying development
        /// correlation without rebuilding or mutating the managed runtime.
        pub fn withCausalContext(self: Self, child: causal_mod.CausalContextV2) Self {
            var derived = self;
            derived.causal_context = causal_mod.CausalContextV2.merge(self.causal_context, child);
            return derived;
        }

        pub fn inspect(
            self: *const Self,
            allocator: Allocator,
            options: application_mod.InspectOptions,
        ) Allocator.Error!application_mod.ApplicationSnapshot {
            if (self.core.disposed) @panic("zigeffect ManagedRuntime has already been disposed");
            return application_mod.ApplicationSnapshot.capture(
                allocator,
                &self.core.topology,
                self.core.root_layer_type,
                self.core.causal_store,
                options,
            );
        }

        pub fn inspectJson(
            self: *const Self,
            allocator: Allocator,
            options: application_mod.InspectOptions,
        ) Allocator.Error![]u8 {
            var snapshot = try self.inspect(allocator, options);
            defer snapshot.deinit();
            return snapshot.jsonAlloc(allocator);
        }

        pub fn run(self: *Self, effect: anytype) @TypeOf(effect).FailureType!@TypeOf(effect).SuccessType {
            if (comptime !service_mod.subset(@TypeOf(effect).RequiredServices, AvailableServices)) {
                @compileError(
                    "zigeffect RuntimeHandle cannot run effect: the handle does not contain every required service",
                );
            }
            if (self.core.disposed) @panic("zigeffect ManagedRuntime has already been disposed");

            var scope = Scope.init(self.core.allocator);
            defer scope.deinit();
            const run_id = self.core.causal_store.nextRunId();
            scope.attachRuntimeSignal(self.core.signalSink(), run_id, self.causal_parent_id, null, null);

            const fiber_id = self.core.next_fiber_id.fetchAdd(1, .monotonic);

            var context = RuntimeContext{
                .core = self.core,
                .scope = &scope,
                .default_overrides = self.default_overrides,
                .causal_run_id = run_id,
                .causal_parent_id = self.causal_parent_id,
                .fiber_id = fiber_id,
                .causal_context = self.causal_context,
            };
            const effect_label = identity_mod.effectLabel(effect);
            const effect_type = identity_mod.boundedTypeName(@TypeOf(effect));
            const forked = context.emit(.{
                .kind = .fiber_forked,
                .label = "RuntimeHandle.run",
                .type_name = effect_type,
                .status = "forked",
            });
            context.causal_parent_id = forked orelse self.causal_parent_id;
            const fiber_started = context.emit(.{
                .kind = .fiber_started,
                .label = effect_label,
                .status = "running",
            });
            context.causal_parent_id = fiber_started orelse context.causal_parent_id;
            const started = context.emit(.{
                .kind = .run_started,
                .label = "RuntimeHandle.run",
                .type_name = effect_type,
                .status = "running",
            });
            context.causal_parent_id = started orelse context.causal_parent_id;

            const EffectType = @TypeOf(effect);
            const Outcome = result_mod.Exit(EffectType.SuccessType, EffectType.FailureType);
            const Task = struct {
                effect: EffectType,
                runtime: *RuntimeContext,
                outcome: ?Outcome = null,

                fn execute(raw: ?*anyopaque) void {
                    const task: *@This() = @ptrCast(@alignCast(raw.?));
                    task.outcome = if (task.effect.runIn(task.runtime)) |value|
                        .{ .success = value }
                    else |failure|
                        .{ .failure = failure };
                }
            };

            var task = Task{ .effect = effect, .runtime = &context };
            if (self.core.executor) |executor| {
                if (executor.vtable.spawn(executor.context, .{
                    .context = &task,
                    .run = Task.execute,
                })) |handle| {
                    executor.vtable.join(executor.context, handle);
                    executor.vtable.destroy(executor.context, handle);
                } else {
                    Task.execute(&task);
                }
            } else {
                Task.execute(&task);
            }

            const outcome = task.outcome orelse @panic("zigeffect executor returned before the effect completed");
            const value = switch (outcome) {
                .success => |success| success,
                .failure => |failure| {
                    scope.closeWithExit(.{ .failure = @errorName(failure) });
                    _ = context.emit(.{
                        .kind = .run_completed,
                        .label = "RuntimeHandle.run",
                        .type_name = @errorName(failure),
                        .status = "failure",
                    });
                    _ = context.emit(.{
                        .kind = .fiber_joined,
                        .label = effect_label,
                        .type_name = @errorName(failure),
                        .status = "failure",
                    });
                    return failure;
                },
                .defect => @panic("canonical effects cannot return a defect outcome"),
                .interrupted => @panic("canonical top-level execution was interrupted without a typed failure"),
                .cause => @panic("canonical effects cannot return a legacy cause outcome"),
            };
            scope.closeWithExit(.success);
            _ = context.emit(.{
                .kind = .run_completed,
                .label = "RuntimeHandle.run",
                .status = "success",
            });
            _ = context.emit(.{
                .kind = .fiber_joined,
                .label = effect_label,
                .status = "success",
            });
            return value;
        }
    };
}
