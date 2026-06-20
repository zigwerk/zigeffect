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
const executor_mod = @import("executor.zig");
const runner_mod = @import("runner.zig");

pub const Allocator = dep_services.Allocator;
pub const Context = context_mod.Context;
pub const Scope = scope_mod.Scope;
pub const Exit = result.Exit;
pub const finalizerExitFromExit = result.finalizerExitFromExit;
pub const exitWithFinalizerFailure = result.exitWithFinalizerFailure;
pub const Clock = clock_mod.Clock;
pub const CausalStore = causal_mod.CausalStore;
pub const BackendCapabilities = backend_mod.BackendCapabilities;
pub const deterministicBackend = backend_mod.deterministicBackend;
pub const AsyncBackend = async_backend_mod.AsyncBackend;
pub const FiberExecutor = executor_mod.FiberExecutor;
pub const FiberJob = executor_mod.FiberJob;
pub const runManagedScope = runner_mod.runManagedScope;
pub const exitManagedScope = runner_mod.exitManagedScope;
pub const runCallerOwnedScope = runner_mod.runCallerOwnedScope;
pub const exitCallerOwnedScope = runner_mod.exitCallerOwnedScope;
pub const ServiceSet = dep_services.ServiceSet;
pub const ServiceSetBuilder = dep_services.ServiceSetBuilder;
pub const ProviderServiceSetBuilder = dep_services.ProviderServiceSetBuilder;
pub const DependencyError = dep_services.DependencyError;
pub const emptyServiceSet = dep_services.emptyServiceSet;
pub const serviceSetBuilder = dep_services.serviceSetBuilder;
pub const providerServiceSetBuilder = dep_services.providerServiceSetBuilder;
pub const assertEffectEnvironment = dep_contracts.assertEffectEnvironment;
pub const validateLayerRequirements = dep_validation.validateLayerRequirements;
pub const ensureLayerRequirements = dep_validation.ensureLayerRequirements;

pub fn Runtime(comptime Env: type) type {
    return struct {
        const Self = @This();

        allocator: Allocator,
        env: *Env,
        clock: ?*Clock = null,
        shared_scope: ?*Scope = null,
        trace_id: ?u64 = null,
        span_id: ?u64 = null,
        causal_store: ?*CausalStore = null,
        backend: BackendCapabilities = deterministicBackend(),
        async_backend: ?AsyncBackend = null,
        /// Pluggable execution strategy for forked work. Propagated onto every
        /// `Context` produced by `context()`. Default (null) keeps the
        /// deterministic posture: forks run synchronously on join.
        executor: ?FiberExecutor = null,
        provided_builder: ServiceSetBuilder = emptyServiceSet,
        provided_provider: ?*const anyopaque = null,
        provided_provider_builder: ?ProviderServiceSetBuilder = null,

        pub fn init(allocator: Allocator, env: *Env) Self {
            return .{
                .allocator = allocator,
                .env = env,
            };
        }

        pub fn withClock(self: Self, clock: *Clock) Self {
            var runtime = self;
            runtime.clock = clock;
            return runtime;
        }

        pub fn withScope(self: Self, scope: *Scope) Self {
            var runtime = self;
            runtime.shared_scope = scope;
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

        /// Run forked work via the given executor (e.g. a real coroutine
        /// backend) instead of synchronously. Propagated to every `Context`
        /// the runtime produces. The deterministic default (no executor)
        /// is unchanged. Mirrors `FiberRuntime.withExecutor`.
        pub fn withExecutor(self: Self, exec: FiberExecutor) Self {
            var runtime = self;
            runtime.executor = exec;
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

        pub fn context(self: *Self, scope: *Scope) Context(Env) {
            var ctx = Context(Env).init(self.allocator, self.env, scope);
            ctx.clock = self.clock;
            ctx.trace_id = self.trace_id;
            ctx.span_id = self.span_id;
            ctx.causal_store = self.causal_store;
            ctx.async_backend = self.async_backend;
            ctx.executor = self.executor;
            return ctx;
        }

        pub fn run(self: *Self, effect: anytype) (Allocator.Error || DependencyError || @TypeOf(effect).FailureType)!@TypeOf(effect).SuccessType {
            assertEffectEnvironment("Runtime.run", Env, effect);
            try ensureLayerRequirements(self.allocator, self.*, effect);

            if (self.shared_scope) |scope| {
                var ctx = self.context(scope);
                return runCallerOwnedScope("Runtime.run", Env, &ctx, effect);
            }

            var scope = Scope.init(self.allocator);
            defer scope.deinit();

            var ctx = self.context(&scope);
            return runManagedScope("Runtime.run", Env, &ctx, &scope, effect);
        }

        pub fn exit(self: *Self, effect: anytype) Exit(@TypeOf(effect).SuccessType, @TypeOf(effect).FailureType) {
            assertEffectEnvironment("Runtime.exit", Env, effect);
            var report = validateLayerRequirements(self.allocator, self.*, effect) catch
                return .{ .defect = "dependency validation allocation failed" };
            defer report.deinit();
            if (!report.isValid()) return .{ .defect = "missing service requirements" };

            if (self.shared_scope) |scope| {
                var ctx = self.context(scope);
                return exitCallerOwnedScope("Runtime.exit", Env, &ctx, effect);
            }

            var scope = Scope.init(self.allocator);
            defer scope.deinit();

            var ctx = self.context(&scope);
            return exitManagedScope("Runtime.exit", Env, &ctx, &scope, effect);
        }
    };
}
