const std = @import("std");
const scope_mod = @import("scope.zig");
const result = @import("result.zig");
const clock_mod = @import("../services/clock.zig");

pub const Allocator = std.mem.Allocator;
pub const Scope = scope_mod.Scope;
pub const ScopeError = scope_mod.ScopeError;
pub const FinalizerRegistrationError = scope_mod.FinalizerRegistrationError;
pub const FinalizerExit = result.FinalizerExit;
pub const Clock = clock_mod.Clock;

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
