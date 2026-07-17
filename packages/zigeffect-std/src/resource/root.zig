//! Refreshable scoped values inspired by Effect's `Resource`.
//!
//! A Resource owns one child scope per acquisition. Refreshing acquires into a
//! new child scope before replacing the current value, so a failed refresh
//! leaves the last successful value and its resources intact.

const std = @import("std");
const StdService = @import("../service/root.zig");
const fx = @import("zigeffect");

pub const ResourceError = error{
    ResourceClosed,
    OutOfMemory,
    MissingScope,
};

pub const default_service_key = "zigeffect/std/Resource";

fn assertErrorSet(comptime Failure: type) void {
    switch (@typeInfo(Failure)) {
        .error_set => {},
        else => @compileError("zstd.Resource requires an error-set acquisition failure type"),
    }
}

/// A manually refreshed value. Applications normally obtain this through
/// `Resource.Service`, whose default layer owns the value for the managed
/// runtime's application scope.
pub fn Manual(
    comptime Value: type,
    comptime Failure: type,
    comptime Requirements: anytype,
    comptime acquire: *const fn (*fx.kernel.ContextView(Requirements)) Failure!Value,
    comptime release: *const fn (*Value) void,
) type {
    assertErrorSet(Failure);
    return struct {
        const Self = @This();

        pub const is_zigeffect_resource = true;
        pub const operations: []const []const u8 = &.{
            "Resource.get",
            "Resource.refresh",
        };
        pub const ValueType = Value;
        pub const AcquisitionFailure = Failure;
        pub const RequiredServices = Requirements;
        pub const ErrorType = Failure || ResourceError;

        const OwnedValue = struct {
            allocator: std.mem.Allocator,
            value: Value,
        };

        const Acquisition = struct {
            scope: fx.Scope,
            owned: *OwnedValue,

            fn close(self: *Acquisition, exit: fx.FinalizerExit) void {
                self.scope.closeWithExit(exit);
                self.scope.deinit();
                self.* = undefined;
            }
        };

        allocator: std.mem.Allocator,
        service_key: []const u8,
        current: ?Acquisition,
        mutex: std.atomic.Mutex = .unlocked,

        fn lock(self: *Self) void {
            while (!self.mutex.tryLock()) std.Thread.yield() catch {};
        }

        fn releaseOwned(owned: *OwnedValue) void {
            const allocator = owned.allocator;
            release(&owned.value);
            allocator.destroy(owned);
        }

        fn closeFailedScope(scope: *fx.Scope, failure: anyerror) void {
            scope.closeWithExit(.{ .failure = @errorName(failure) });
            scope.deinit();
        }

        fn acquireScoped(ctx: anytype) ErrorType!Acquisition {
            const runtime_context = ctx.runtime_context;
            var child_scope = fx.Scope.init(runtime_context.core.allocator);
            const run_id = runtime_context.causal_run_id orelse runtime_context.core.causal_store.nextRunId();
            child_scope.attachRuntimeSignal(
                runtime_context.core.signalSink(),
                run_id,
                runtime_context.causal_parent_id,
                runtime_context.scope.causal_trace_id,
                runtime_context.scope.causal_span_id,
            );
            child_scope.setCausalContext(runtime_context.causal_context);

            var child_runtime = runtime_context.*;
            child_runtime.scope = &child_scope;
            child_runtime.causal_parent_id = child_scope.causal_opened_event_id orelse runtime_context.causal_parent_id;
            var acquire_context = fx.kernel.ContextView(Requirements){ .runtime_context = &child_runtime };

            var value = acquire(&acquire_context) catch |failure| {
                closeFailedScope(&child_scope, failure);
                return failure;
            };
            const owned = runtime_context.core.allocator.create(OwnedValue) catch |failure| {
                release(&value);
                closeFailedScope(&child_scope, failure);
                return failure;
            };
            owned.* = .{
                .allocator = runtime_context.core.allocator,
                .value = value,
            };
            child_scope.addFinalizerFor(OwnedValue, owned, releaseOwned) catch |failure| {
                releaseOwned(owned);
                closeFailedScope(&child_scope, failure);
                return failure;
            };
            return .{ .scope = child_scope, .owned = owned };
        }

        pub fn init(ctx: *fx.kernel.ContextView(Requirements), stable_service_key: []const u8) ErrorType!Self {
            const current = try acquireScoped(ctx);
            return .{
                .allocator = ctx.allocator(),
                .service_key = if (stable_service_key.len == 0) default_service_key else stable_service_key,
                .current = current,
            };
        }

        pub fn deinit(self: *Self) void {
            self.lock();
            const current = self.current;
            self.current = null;
            self.mutex.unlock();
            if (current) |value| {
                var owned = value;
                owned.close(.success);
            }
        }

        pub fn getValue(self: *Self) ErrorType!Value {
            self.lock();
            defer self.mutex.unlock();
            const current = self.current orelse return error.ResourceClosed;
            return current.owned.value;
        }

        pub fn refreshIn(self: *Self, ctx: anytype) ErrorType!void {
            const operation = StdService.beginOperation(ctx, self.service_key, "Resource.refresh", "refresh scoped value");
            var replacement = acquireScoped(ctx) catch |failure| {
                _ = StdService.completeOperation(ctx, operation, "failure", @errorName(failure));
                return failure;
            };

            self.lock();
            const previous = self.current orelse {
                self.mutex.unlock();
                replacement.close(.{ .failure = @errorName(error.ResourceClosed) });
                _ = StdService.completeOperation(ctx, operation, "failure", @errorName(error.ResourceClosed));
                return error.ResourceClosed;
            };
            self.current = replacement;
            self.mutex.unlock();

            var old = previous;
            old.close(.success);
            _ = StdService.completeOperation(ctx, operation, "success", "replaced previous scoped value");
        }

        fn destroy(resource: *Self) void {
            const allocator = resource.allocator;
            resource.deinit();
            allocator.destroy(resource);
        }

        pub fn make(stable_service_key: []const u8) fx.kernel.Effect(*Self, ErrorType, Requirements).Stateful([]const u8) {
            const Make = fx.kernel.Effect(*Self, ErrorType, Requirements);
            return Make.fromState([]const u8, stable_service_key, struct {
                fn run(key: []const u8, ctx: *fx.kernel.ContextView(Requirements)) ErrorType!*Self {
                    const allocator = ctx.allocator();
                    const resource = allocator.create(Self) catch return error.OutOfMemory;
                    resource.* = Self.init(ctx, key) catch |failure| {
                        allocator.destroy(resource);
                        return failure;
                    };
                    ctx.addFinalizerFor(Self, resource, Self.destroy) catch |failure| {
                        Self.destroy(resource);
                        return failure;
                    };
                    return resource;
                }
            }.run);
        }
    };
}

fn ServiceLifecycle(comptime ResourceType: type, comptime stable_service_key: []const u8) type {
    return struct {
        fn acquire(ctx: *fx.kernel.ContextView(ResourceType.RequiredServices)) ResourceType.ErrorType!ResourceType {
            return ResourceType.init(ctx, stable_service_key);
        }

        fn release(resource: *ResourceType) void {
            resource.deinit();
        }
    };
}

/// Defines a stable service tag and its canonical scoped default layer.
pub fn Service(
    comptime stable_service_key: []const u8,
    comptime Value: type,
    comptime Failure: type,
    comptime Requirements: anytype,
    comptime acquire: *const fn (*fx.kernel.ContextView(Requirements)) Failure!Value,
    comptime release: *const fn (*Value) void,
) type {
    if (stable_service_key.len == 0) @compileError("zstd.Resource service keys must not be empty");
    const ResourceType = Manual(Value, Failure, Requirements, acquire, release);
    const Lifecycle = ServiceLifecycle(ResourceType, stable_service_key);
    return fx.kernel.defineService(.{
        .key = stable_service_key,
        .API = ResourceType,
        .Failure = ResourceType.ErrorType,
        .Requirements = Requirements,
        .acquire = Lifecycle.acquire,
        .release = Lifecycle.release,
    });
}

fn assertResourceService(comptime Tag: type) void {
    if (!@hasDecl(Tag.API, "is_zigeffect_resource")) {
        @compileError("zstd.Resource operation requires a tag created by Resource.Service");
    }
}

pub fn get(comptime Tag: type) fx.kernel.Effect(Tag.API.ValueType, Tag.API.ErrorType, .{Tag}) {
    assertResourceService(Tag);
    return fx.kernel.Effect(Tag.API.ValueType, Tag.API.ErrorType, .{Tag}).fromFn(struct {
        fn run(ctx: *fx.kernel.ContextView(.{Tag})) Tag.API.ErrorType!Tag.API.ValueType {
            const operation = StdService.beginOperation(ctx, Tag.service_key, "Resource.get", "read current scoped value");
            const value = ctx.service(Tag).getValue() catch |failure| {
                _ = StdService.completeOperation(ctx, operation, "failure", @errorName(failure));
                return failure;
            };
            _ = StdService.completeOperation(ctx, operation, "success", "read current scoped value");
            return value;
        }
    }.run);
}

pub fn refresh(comptime Tag: type) fx.kernel.Effect(void, Tag.API.ErrorType, .{Tag}) {
    assertResourceService(Tag);
    return fx.kernel.Effect(void, Tag.API.ErrorType, .{Tag}).fromFn(struct {
        fn run(ctx: *fx.kernel.ContextView(.{Tag})) Tag.API.ErrorType!void {
            try ctx.service(Tag).refreshIn(ctx);
        }
    }.run);
}
