const std = @import("std");
const scope_mod = @import("scope.zig");
const result = @import("result.zig");
const clock_mod = @import("../services/clock.zig");
const causal_mod = @import("../services/causal.zig");
const async_backend_mod = @import("../runtime/async_backend.zig");

pub const Allocator = std.mem.Allocator;
pub const Scope = scope_mod.Scope;
pub const ScopeError = scope_mod.ScopeError;
pub const FinalizerRegistrationError = scope_mod.FinalizerRegistrationError;
pub const FinalizerExit = result.FinalizerExit;
pub const Clock = clock_mod.Clock;
pub const CausalStore = causal_mod.CausalStore;
pub const CausalEvent = causal_mod.CausalEvent;
pub const AsyncBackend = async_backend_mod.AsyncBackend;
pub const AsyncBackendError = async_backend_mod.AsyncBackendError;
pub const Suspension = async_backend_mod.Suspension;
pub const AsyncIoWaitKind = async_backend_mod.AsyncIoWaitKind;
pub const AsyncIoInterest = async_backend_mod.AsyncIoInterest;

pub fn serviceNotFound(comptime Env: type, comptime Service: type) noreturn {
    @compileError(
        "zigeffect service not found\n\n" ++
            "requested service: " ++ @typeName(Service) ++ "\n" ++
            "environment: " ++ @typeName(Env) ++ "\n\n" ++
            "Add a branch to the environment service method:\n\n" ++
            "    pub fn service(self: *" ++ @typeName(Env) ++ ", comptime Requested: type) *Requested {\n" ++
            "        if (Requested == " ++ @typeName(Service) ++ ") return &self.<field>;\n" ++
            "        return fx.serviceNotFound(" ++ @typeName(Env) ++ ", Requested);\n" ++
            "    }\n\n" ++
            "This usually means the effect asks for a service that the layer/environment does not provide.",
    );
}

pub fn Context(comptime Env: type) type {
    return struct {
        const Self = @This();

        allocator: Allocator,
        env: *Env,
        scope: ?*Scope = null,
        clock: ?*Clock = null,
        trace_id: ?u64 = null,
        span_id: ?u64 = null,
        causal_store: ?*CausalStore = null,
        causal_run_id: ?u64 = null,
        async_backend: ?AsyncBackend = null,

        pub fn init(allocator: Allocator, env: *Env, scope: ?*Scope) Self {
            return .{
                .allocator = allocator,
                .env = env,
                .scope = scope,
            };
        }

        pub fn service(self: *Self, comptime Service: type) *Service {
            return self.env.service(Service);
        }

        pub fn withCausalStore(self: Self, store: *CausalStore) Self {
            var ctx = self;
            ctx.causal_store = store;
            return ctx;
        }

        pub fn ensureCausalRunId(self: *Self) ?u64 {
            if (self.causal_store == null) return null;
            if (self.causal_run_id == null) {
                self.causal_run_id = self.causal_store.?.nextRunId();
            }
            return self.causal_run_id;
        }

        pub fn recordCausal(self: *Self, event: CausalEvent) ?u64 {
            const store = self.causal_store orelse return null;
            var owned = event;
            owned.run_id = owned.run_id orelse self.ensureCausalRunId();
            if (owned.scope_id == null) {
                if (self.scope) |scope| owned.scope_id = scope.causal_scope_id;
            }
            owned.trace_id = owned.trace_id orelse self.trace_id;
            owned.span_id = owned.span_id orelse self.span_id;
            return store.record(owned) catch null;
        }

        pub fn requireAsyncBackend(self: *const Self) AsyncBackendError!AsyncBackend {
            return self.async_backend orelse error.UnsupportedBackendCapability;
        }

        pub fn suspendRuntime(
            self: *const Self,
            suspension: Suspension,
            reason: []const u8,
        ) AsyncBackendError!void {
            const backend = try self.requireAsyncBackend();
            try backend.suspendRuntime(.{
                .suspension = suspension,
                .reason = reason,
            });
        }

        pub fn registerIoWait(
            self: *const Self,
            suspension: Suspension,
            io_kind: AsyncIoWaitKind,
            interest: AsyncIoInterest,
            descriptor: ?i64,
            reason: []const u8,
        ) AsyncBackendError!void {
            const backend = try self.requireAsyncBackend();
            try backend.registerIoWait(.{
                .suspension = suspension,
                .io_kind = io_kind,
                .interest = interest,
                .descriptor = descriptor,
                .reason = reason,
            });
        }

        pub fn addFinalizerFor(
            self: *Self,
            comptime Resource: type,
            resource: *Resource,
            comptime release: *const fn (*Resource) void,
        ) FinalizerRegistrationError!void {
            if (self.scope) |scope| {
                if (scope.closed) return error.MissingScope;
                return scope.addFinalizerFor(Resource, resource, release);
            }
            return error.MissingScope;
        }

        pub fn addFinalizerFallibleFor(
            self: *Self,
            comptime Resource: type,
            resource: *Resource,
            comptime release: anytype,
        ) FinalizerRegistrationError!void {
            if (self.scope) |scope| {
                if (scope.closed) return error.MissingScope;
                return scope.addFinalizerFallibleFor(Resource, resource, release);
            }
            return error.MissingScope;
        }

        pub fn addFinalizerExitFor(
            self: *Self,
            comptime Resource: type,
            resource: *Resource,
            comptime release: *const fn (*Resource, FinalizerExit) void,
        ) FinalizerRegistrationError!void {
            if (self.scope) |scope| {
                if (scope.closed) return error.MissingScope;
                return scope.addFinalizerExitFor(Resource, resource, release);
            }
            return error.MissingScope;
        }

        pub fn addFinalizerExitFallibleFor(
            self: *Self,
            comptime Resource: type,
            resource: *Resource,
            comptime release: anytype,
        ) FinalizerRegistrationError!void {
            if (self.scope) |scope| {
                if (scope.closed) return error.MissingScope;
                return scope.addFinalizerExitFallibleFor(Resource, resource, release);
            }
            return error.MissingScope;
        }
    };
}
