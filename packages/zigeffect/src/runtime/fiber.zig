const std = @import("std");
const context_mod = @import("../core/context.zig");
const scope_mod = @import("../core/scope.zig");
const result = @import("../core/result.zig");
const clock_mod = @import("../services/clock.zig");
const causal_mod = @import("../services/causal.zig");
const dep_services = @import("../dependency/services.zig");
const dep_contracts = @import("../dependency/contracts.zig");
const dep_validation = @import("../dependency/validation.zig");
const backend_mod = @import("backend.zig");
const async_backend_mod = @import("async_backend.zig");

pub const Allocator = std.mem.Allocator;
pub const Context = context_mod.Context;
pub const Scope = scope_mod.Scope;
pub const ScopeError = scope_mod.ScopeError;
pub const FinalizerExit = result.FinalizerExit;
pub const Exit = result.Exit;
pub const finalizerExitFromExit = result.finalizerExitFromExit;
pub const exitWithFinalizerFailure = result.exitWithFinalizerFailure;
pub const Clock = clock_mod.Clock;
pub const CausalStore = causal_mod.CausalStore;
pub const CausalEvent = causal_mod.CausalEvent;
pub const BackendCapabilities = backend_mod.BackendCapabilities;
pub const deterministicBackend = backend_mod.deterministicBackend;
pub const AsyncBackend = async_backend_mod.AsyncBackend;
pub const ServiceSet = dep_services.ServiceSet;
pub const ServiceSetBuilder = dep_services.ServiceSetBuilder;
pub const ProviderServiceSetBuilder = dep_services.ProviderServiceSetBuilder;
pub const DependencyError = dep_services.DependencyError;
pub const emptyServiceSet = dep_services.emptyServiceSet;
pub const serviceSetBuilder = dep_services.serviceSetBuilder;
pub const providerServiceSetBuilder = dep_services.providerServiceSetBuilder;
pub const assertEffectEnvironment = dep_contracts.assertEffectEnvironment;
pub const ensureLayerRequirements = dep_validation.ensureLayerRequirements;

pub const FiberId = u64;
pub const FiberStatus = enum {
    pending,
    running,
    done,
    failed,
    interrupted,
};

const FiberRecord = struct {
    state: ?*anyopaque,
    deinit: *const fn (?*anyopaque) void,
};

fn FiberState(comptime Success: type, comptime Failure: type, comptime Env: type) type {
    return struct {
        const Self = @This();
        const RunTask = *const fn (*Self, *Context(Env)) void;
        const DeinitTask = *const fn (?*anyopaque) void;

        allocator: Allocator,
        id: FiberId,
        scope: Scope,
        status_value: FiberStatus = .pending,
        exit_value: ?Exit(Success, Failure) = null,
        task: ?*anyopaque = null,
        run_task: ?RunTask = null,
        deinit_task: ?DeinitTask = null,
        causal_store: ?*CausalStore = null,
        causal_run_id: ?u64 = null,
        causal_forked_event_id: ?u64 = null,
        causal_trace_id: ?u64 = null,
        causal_span_id: ?u64 = null,

        pub fn init(
            allocator: Allocator,
            id: FiberId,
            task: ?*anyopaque,
            run_task: RunTask,
            deinit_task: DeinitTask,
        ) Self {
            return .{
                .allocator = allocator,
                .id = id,
                .scope = Scope.init(allocator),
                .task = task,
                .run_task = run_task,
                .deinit_task = deinit_task,
            };
        }

        pub fn deinit(self: *Self) void {
            if (self.task) |task| {
                self.deinit_task.?(task);
                self.task = null;
            }
            self.scope.deinit();
        }

        pub fn status(self: *const Self) FiberStatus {
            return self.status_value;
        }

        fn exitStatus(exit: Exit(Success, Failure)) []const u8 {
            return switch (exit) {
                .success => "success",
                .failure => "failure",
                .defect => "defect",
                .interrupted => "interrupted",
                .cause => "cause",
            };
        }

        fn exitTypeName(exit: Exit(Success, Failure)) []const u8 {
            return switch (exit) {
                .success => "",
                .failure => |err| @errorName(err),
                .defect => |message| message,
                .interrupted => "",
                .cause => |cause| @tagName(cause),
            };
        }

        fn recordCausal(self: *Self, event: CausalEvent) ?u64 {
            const store = self.causal_store orelse return null;
            var owned = event;
            owned.run_id = owned.run_id orelse self.causal_run_id;
            owned.fiber_id = owned.fiber_id orelse self.id;
            owned.scope_id = owned.scope_id orelse self.scope.causal_scope_id;
            owned.trace_id = owned.trace_id orelse self.causal_trace_id;
            owned.span_id = owned.span_id orelse self.causal_span_id;
            return store.record(owned) catch null;
        }

        pub fn attachCausal(
            self: *Self,
            store: *CausalStore,
            run_id: u64,
            trace_id: ?u64,
            span_id: ?u64,
        ) void {
            self.causal_store = store;
            self.causal_run_id = run_id;
            self.causal_trace_id = trace_id;
            self.causal_span_id = span_id;
            self.scope.causal_scope_id = self.scope.causal_scope_id orelse store.nextScopeId();
            self.causal_forked_event_id = self.recordCausal(.{
                .kind = .fiber_forked,
                .status = "pending",
            });
            self.scope.attachCausal(store, run_id, self.causal_forked_event_id, trace_id, span_id);
        }

        fn recordStarted(self: *Self) void {
            _ = self.recordCausal(.{
                .kind = .fiber_started,
                .parent_id = self.causal_forked_event_id,
                .status = "running",
            });
        }

        fn recordInterrupted(self: *Self) void {
            _ = self.recordCausal(.{
                .kind = .fiber_interrupted,
                .parent_id = self.causal_forked_event_id,
                .status = "interrupted",
            });
        }

        fn recordJoined(self: *Self, exit: Exit(Success, Failure)) void {
            _ = self.recordCausal(.{
                .kind = .fiber_joined,
                .parent_id = self.causal_forked_event_id,
                .status = exitStatus(exit),
                .type_name = exitTypeName(exit),
            });
        }

        fn isComplete(self: *const Self) bool {
            return self.exit_value != null;
        }

        fn completeSuccess(self: *Self, value: Success) void {
            if (self.isComplete()) return;
            self.exit_value = .{ .success = value };
            self.status_value = .done;
        }

        fn completeFailure(self: *Self, err: Failure) void {
            if (self.isComplete()) return;
            self.exit_value = .{ .failure = err };
            self.status_value = .failed;
        }

        fn closeChildScope(self: *Self) void {
            const child_exit = self.exit_value orelse return;
            self.scope.closeWithExit(finalizerExitFromExit(child_exit));
            if (self.scope.firstFinalizerFailure()) |failure| {
                self.exit_value = exitWithFinalizerFailure(Success, Failure, child_exit, failure);
                self.status_value = .failed;
            }
        }

        pub fn run(self: *Self, ctx: *Context(Env)) void {
            if (self.status_value != .pending) return;
            self.status_value = .running;
            self.recordStarted();
            self.run_task.?(self, ctx);
            if (self.exit_value == null) {
                self.exit_value = .{ .defect = "fiber task completed without an exit" };
                self.status_value = .failed;
            }
            self.closeChildScope();
        }

        pub fn interrupt(self: *Self) void {
            if (self.isComplete()) return;
            self.exit_value = .{ .interrupted = self.id };
            self.status_value = .interrupted;
            self.recordInterrupted();
            self.scope.closeWithExit(.{ .interrupted = self.id });
        }

        pub fn join(self: *Self, runtime: *FiberRuntime(Env)) Exit(Success, Failure) {
            if (self.status_value == .pending) {
                var ctx = runtime.context(&self.scope);
                self.run(&ctx);
            }
            return self.exit_value orelse .{ .defect = "fiber has no exit" };
        }
    };
}

pub fn Fiber(comptime Success: type, comptime Failure: type, comptime Env: type) type {
    return struct {
        const Self = @This();
        pub const SuccessType = Success;
        pub const FailureType = Failure;
        pub const EnvType = Env;

        id: FiberId,
        state: *FiberState(Success, Failure, Env),
        runtime: *FiberRuntime(Env),

        pub fn status(self: Self) FiberStatus {
            return self.state.status();
        }

        pub fn joinExit(self: Self) Exit(Success, Failure) {
            return self.runtime.join(self);
        }

        pub fn interrupt(self: Self) void {
            self.runtime.interrupt(self);
        }
    };
}

pub fn FiberRuntime(comptime Env: type) type {
    return struct {
        const Self = @This();

        allocator: Allocator,
        env: *Env,
        clock: ?*Clock = null,
        trace_id: ?u64 = null,
        span_id: ?u64 = null,
        causal_store: ?*CausalStore = null,
        causal_run_id: ?u64 = null,
        backend: BackendCapabilities = deterministicBackend(),
        async_backend: ?AsyncBackend = null,
        provided_builder: ServiceSetBuilder = emptyServiceSet,
        provided_provider: ?*const anyopaque = null,
        provided_provider_builder: ?ProviderServiceSetBuilder = null,
        next_fiber_id: FiberId = 1,
        fibers: std.ArrayList(FiberRecord) = .empty,

        pub fn init(allocator: Allocator, env: *Env) Self {
            return .{
                .allocator = allocator,
                .env = env,
            };
        }

        pub fn deinit(self: *Self) void {
            for (self.fibers.items) |record| {
                record.deinit(record.state);
            }
            self.fibers.deinit(self.allocator);
        }

        pub fn withClock(self: Self, clock: *Clock) Self {
            var runtime = self;
            runtime.clock = clock;
            return runtime;
        }

        pub fn withTraceContext(self: Self, trace_id: u64, span_id: ?u64) Self {
            var runtime = self;
            runtime.trace_id = trace_id;
            runtime.span_id = span_id;
            return runtime;
        }

        pub fn withCausalStore(self: Self, store: *CausalStore) Self {
            var runtime = self;
            runtime.causal_store = store;
            return runtime;
        }

        pub fn withBackend(self: Self, backend: BackendCapabilities) Self {
            var runtime = self;
            runtime.backend = backend;
            return runtime;
        }

        pub fn withAsyncBackend(self: Self, async_backend: AsyncBackend) Self {
            var runtime = self;
            runtime.async_backend = async_backend;
            runtime.backend = async_backend.capabilities;
            return runtime;
        }

        pub fn backendCapabilities(self: *const Self) BackendCapabilities {
            return self.backend;
        }

        pub fn provides(self: Self, comptime services: anytype) Self {
            var runtime = self;
            runtime.provided_builder = serviceSetBuilder(services);
            runtime.provided_provider = null;
            runtime.provided_provider_builder = null;
            return runtime;
        }

        pub fn withProvider(self: Self, provider: anytype) Self {
            var runtime = self;
            runtime.provided_provider = @ptrCast(provider);
            runtime.provided_provider_builder = providerServiceSetBuilder(@TypeOf(provider));
            return runtime;
        }

        pub fn providedServices(self: Self, allocator: Allocator) Allocator.Error!ServiceSet {
            if (self.provided_provider_builder) |builder| {
                return builder(self.provided_provider.?, allocator);
            }
            return self.provided_builder(allocator);
        }

        pub fn ensureCausalRunId(self: *Self) ?u64 {
            const store = self.causal_store orelse return null;
            if (self.causal_run_id == null) {
                self.causal_run_id = store.nextRunId();
            }
            return self.causal_run_id;
        }

        pub fn context(self: *Self, scope: *Scope) Context(Env) {
            var ctx = Context(Env).init(self.allocator, self.env, scope);
            ctx.clock = self.clock;
            ctx.trace_id = self.trace_id;
            ctx.span_id = self.span_id;
            ctx.causal_store = self.causal_store;
            ctx.causal_run_id = self.ensureCausalRunId();
            ctx.async_backend = self.async_backend;
            return ctx;
        }

        pub fn fork(
            self: *Self,
            effect: anytype,
        ) (Allocator.Error || DependencyError)!Fiber(@TypeOf(effect).SuccessType, @TypeOf(effect).FailureType, Env) {
            assertEffectEnvironment("FiberRuntime.fork", Env, effect);
            try ensureLayerRequirements(self.allocator, self.*, effect);

            const EffectType = @TypeOf(effect);
            const State = FiberState(EffectType.SuccessType, EffectType.FailureType, Env);
            const Task = struct {
                allocator: Allocator,
                effect: EffectType,
            };
            const Runner = struct {
                fn run(state: *State, ctx: *Context(Env)) void {
                    const task: *Task = @ptrCast(@alignCast(state.task.?));
                    const value = task.effect.run(ctx) catch |err| {
                        state.completeFailure(err);
                        return;
                    };
                    state.completeSuccess(value);
                }

                fn deinit(raw: ?*anyopaque) void {
                    const task: *Task = @ptrCast(@alignCast(raw.?));
                    task.allocator.destroy(task);
                }
            };
            const StateRecord = struct {
                fn deinit(raw: ?*anyopaque) void {
                    const state: *State = @ptrCast(@alignCast(raw.?));
                    const allocator = state.allocator;
                    state.deinit();
                    allocator.destroy(state);
                }
            };

            const task = try self.allocator.create(Task);
            errdefer self.allocator.destroy(task);
            task.* = .{
                .allocator = self.allocator,
                .effect = effect,
            };

            const state = try self.allocator.create(State);
            errdefer self.allocator.destroy(state);
            state.* = State.init(self.allocator, self.next_fiber_id, task, Runner.run, Runner.deinit);
            errdefer state.deinit();

            try self.fibers.append(self.allocator, .{
                .state = state,
                .deinit = StateRecord.deinit,
            });

            if (self.causal_store) |store| {
                if (self.ensureCausalRunId()) |run_id| {
                    state.attachCausal(store, run_id, self.trace_id, self.span_id);
                }
            }

            const fiber = Fiber(EffectType.SuccessType, EffectType.FailureType, Env){
                .id = self.next_fiber_id,
                .state = state,
                .runtime = self,
            };
            self.next_fiber_id += 1;
            return fiber;
        }

        pub fn forkScoped(
            self: *Self,
            ctx: *Context(Env),
            effect: anytype,
        ) (Allocator.Error || DependencyError || ScopeError)!Fiber(@TypeOf(effect).SuccessType, @TypeOf(effect).FailureType, Env) {
            const parent_scope = ctx.scope orelse return error.MissingScope;
            return self.forkInScope(parent_scope, effect);
        }

        pub fn forkInScope(
            self: *Self,
            parent_scope: *Scope,
            effect: anytype,
        ) (Allocator.Error || DependencyError || ScopeError)!Fiber(@TypeOf(effect).SuccessType, @TypeOf(effect).FailureType, Env) {
            if (parent_scope.closed) return error.MissingScope;
            const fiber = try self.fork(effect);
            const State = FiberState(@TypeOf(effect).SuccessType, @TypeOf(effect).FailureType, Env);
            const LeaseFinalizer = struct {
                fn interrupt(raw: ?*anyopaque, exit: FinalizerExit) void {
                    _ = exit;
                    const state: *State = @ptrCast(@alignCast(raw.?));
                    state.interrupt();
                }
            };

            parent_scope.addFinalizerExit(fiber.state, LeaseFinalizer.interrupt) catch |err| {
                self.interrupt(fiber);
                return err;
            };
            return fiber;
        }

        pub fn join(
            self: *Self,
            fiber: anytype,
        ) Exit(@TypeOf(fiber).SuccessType, @TypeOf(fiber).FailureType) {
            const exit = fiber.state.join(self);
            fiber.state.recordJoined(exit);
            return exit;
        }

        pub fn interrupt(self: *Self, fiber: anytype) void {
            _ = self;
            fiber.state.interrupt();
        }
    };
}
