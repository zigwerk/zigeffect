const std = @import("std");
const context_mod = @import("../core/context.zig");
const result = @import("../core/result.zig");
const schedule_mod = @import("schedule.zig");
const dep_services = @import("../dependency/services.zig");
const ergonomics_mod = @import("ergonomics.zig");

pub const AsEffect = ergonomics_mod.AsEffect;
pub const WhenEffect = ergonomics_mod.WhenEffect;

pub const Allocator = std.mem.Allocator;
pub const Context = context_mod.Context;
pub const Exit = result.Exit;
pub const exitToResult = result.exitToResult;
pub const Schedule = schedule_mod.Schedule;
pub const ServiceSet = dep_services.ServiceSet;

fn functionInfo(comptime api: []const u8, comptime Fn: type) std.builtin.Type.Fn {
    return switch (@typeInfo(Fn)) {
        .@"fn" => |fn_info| fn_info,
        .pointer => |pointer| switch (@typeInfo(pointer.child)) {
            .@"fn" => |fn_info| fn_info,
            else => @compileError(
                "zigeffect invalid effect function\n\n" ++
                    "api: " ++ api ++ "\n\n" ++
                    "Expected a function with shape: fn (*fx.Context(Env)) Failure!Success.",
            ),
        },
        else => @compileError(
            "zigeffect invalid effect function\n\n" ++
                "api: " ++ api ++ "\n\n" ++
                "Expected a function with shape: fn (*fx.Context(Env)) Failure!Success.",
        ),
    };
}

fn assertEffectFunction(
    comptime Success: type,
    comptime Failure: type,
    comptime Env: type,
    comptime run_fn: anytype,
) void {
    const fn_info = functionInfo("Effect.fromFn", @TypeOf(run_fn));
    if (fn_info.params.len != 1) {
        @compileError(
            "zigeffect invalid effect function\n\n" ++
                "api: Effect.fromFn\n\n" ++
                "Expected exactly one parameter: *fx.Context(Env).",
        );
    }
    if (fn_info.params[0].type == null or fn_info.params[0].type.? != *Context(Env)) {
        @compileError(
            "zigeffect invalid effect function\n\n" ++
                "api: Effect.fromFn\n\n" ++
                "The first parameter must be *fx.Context(" ++ @typeName(Env) ++ ").",
        );
    }
    if (fn_info.return_type == null or fn_info.return_type.? != Failure!Success) {
        @compileError(
            "zigeffect invalid effect function\n\n" ++
                "api: Effect.fromFn\n\n" ++
                "Expected return type: " ++ @typeName(Failure!Success) ++ ".",
        );
    }
}

pub fn Effect(comptime Success: type, comptime Failure: type, comptime Env: type) type {
    return struct {
        const Self = @This();
        pub const SuccessType = Success;
        pub const FailureType = Failure;
        pub const EnvType = Env;

        const Mode = union(enum) {
            run_fn: *const fn (*Context(Env)) Failure!Success,
            succeed: Success,
            fail: Failure,
            sync_fn: *const fn () Success,
        };

        mode: Mode,

        pub fn fromFn(comptime run_fn: anytype) Self {
            assertEffectFunction(Success, Failure, Env, run_fn);
            const typed: *const fn (*Context(Env)) Failure!Success = run_fn;
            return .{ .mode = .{ .run_fn = typed } };
        }

        pub fn succeed(value: Success) Self {
            return .{ .mode = .{ .succeed = value } };
        }

        pub fn fail(err: Failure) Self {
            return .{ .mode = .{ .fail = err } };
        }

        pub fn sync(sync_fn: *const fn () Success) Self {
            return .{ .mode = .{ .sync_fn = sync_fn } };
        }

        pub fn run(self: Self, ctx: *Context(Env)) Failure!Success {
            return switch (self.mode) {
                .run_fn => |run_fn| run_fn(ctx),
                .succeed => |value| value,
                .fail => |err| err,
                .sync_fn => |sync_fn| sync_fn(),
            };
        }

        pub fn exit(self: Self, ctx: *Context(Env)) Exit(Success, Failure) {
            const value = self.run(ctx) catch |err| return .{ .failure = err };
            return .{ .success = value };
        }

        pub fn retry(self: Self, ctx: *Context(Env), schedule: *Schedule) Failure!Success {
            return retryEffect(self, ctx, schedule);
        }

        pub fn repeat(self: Self, ctx: *Context(Env), schedule: *Schedule) Failure!Success {
            return repeatEffect(self, ctx, schedule);
        }

        pub fn map(
            self: Self,
            comptime Next: type,
            mapper: *const fn (Success) Next,
        ) MapEffect(Self, Next, Failure, Env) {
            return .{
                .parent = self,
                .mapper = mapper,
            };
        }

        pub fn flatMap(
            self: Self,
            comptime Next: type,
            binder: *const fn (Success, *Context(Env)) Failure!Next,
        ) FlatMapEffect(Self, Next, Failure, Env) {
            return .{
                .parent = self,
                .binder = binder,
            };
        }

        pub fn tap(
            self: Self,
            action: *const fn (Success, *Context(Env)) Failure!void,
        ) TapEffect(Self, Failure, Env) {
            return .{
                .parent = self,
                .action = action,
            };
        }

        pub fn mapError(
            self: Self,
            comptime NextFailure: type,
            mapper: *const fn (Failure) NextFailure,
        ) MapErrorEffect(Self, NextFailure, Env) {
            return .{ .parent = self, .mapper = mapper };
        }

        pub fn catchAll(
            self: Self,
            comptime NextFailure: type,
            handler: *const fn (Failure, *Context(Env)) NextFailure!Success,
        ) CatchAllEffect(Self, NextFailure, Env) {
            return .{ .parent = self, .handler = handler };
        }

        pub fn orElse(self: Self, fallback: anytype) OrElseEffect(Self, @TypeOf(fallback), Env) {
            return .{ .parent = self, .fallback = fallback };
        }

        pub fn tapError(
            self: Self,
            action: *const fn (Failure, *Context(Env)) Failure!void,
        ) TapErrorEffect(Self, Failure, Env) {
            return .{ .parent = self, .action = action };
        }

        pub fn onExit(
            self: Self,
            action: *const fn (Exit(Self.SuccessType, Self.FailureType), *Context(Env)) Self.FailureType!void,
        ) OnExitEffect(Self, Env) {
            return .{ .parent = self, .action = action };
        }

        pub fn ensuring(
            self: Self,
            finalizer: *const fn (*Context(Env)) Self.FailureType!void,
        ) EnsuringEffect(Self, Env) {
            return .{ .parent = self, .finalizer = finalizer };
        }

        pub fn requires(self: Self, comptime services: anytype) RequiredEffect(Self, services, Env) {
            return .{ .parent = self };
        }

        // ─── Ergonomics M1 (Track 3) ─────────────────────────────────────────
        // Daily-use combinators that map onto existing primitives. Defined here
        // so they appear on the base Effect type (the most common entry point);
        // wrapper Effects retain the same names already via their own methods.

        /// M3.1 / M3.2 — run self for side-effect, then return `replacement`.
        /// `replace` is the documented alias; both produce an `AsEffect`.
        pub fn as(self: Self, comptime NewSuccess: type, replacement: NewSuccess) AsEffect(Self, NewSuccess, Env) {
            return .{ .parent = self, .replacement = replacement };
        }
        pub fn replace(self: Self, comptime NewSuccess: type, replacement: NewSuccess) AsEffect(Self, NewSuccess, Env) {
            return self.as(NewSuccess, replacement);
        }

        /// M3.3 — run self for side-effect, discard success.
        pub fn asVoid(self: Self) AsEffect(Self, void, Env) {
            return .{ .parent = self, .replacement = {} };
        }

        /// M3.4 — alias for `flatMap`. The EffectTS canonical name; the
        /// signature is identical.
        pub fn andThen(
            self: Self,
            comptime Next: type,
            binder: *const fn (Success, *Context(Env)) Failure!Next,
        ) FlatMapEffect(Self, Next, Failure, Env) {
            return self.flatMap(Next, binder);
        }

        /// M3.8 — run self only if `cond` is true; success becomes `?Success`.
        pub fn when(self: Self, cond: bool) WhenEffect(Self, Env) {
            return .{ .parent = self, .cond = cond };
        }

        /// M3.9 — run self unless `cond` is true; the inverse of `when`.
        pub fn unless(self: Self, cond: bool) WhenEffect(Self, Env) {
            return .{ .parent = self, .cond = !cond };
        }
    };
}

pub fn RequiredEffect(comptime Parent: type, comptime Services: anytype, comptime Env: type) type {
    return struct {
        const Self = @This();
        pub const SuccessType = Parent.SuccessType;
        pub const FailureType = Parent.FailureType;
        pub const EnvType = Env;
        pub const RequiredServices = Services;

        parent: Parent,

        pub fn requiredServices(allocator: Allocator) Allocator.Error!ServiceSet {
            return ServiceSet.fromTypes(allocator, Services);
        }

        pub fn run(self: Self, ctx: *Context(Env)) Parent.FailureType!Parent.SuccessType {
            return self.parent.run(ctx);
        }

        pub fn exit(self: Self, ctx: *Context(Env)) Exit(Parent.SuccessType, Parent.FailureType) {
            return self.parent.exit(ctx);
        }

        pub fn retry(self: Self, ctx: *Context(Env), schedule: *Schedule) Parent.FailureType!Parent.SuccessType {
            return retryEffect(self, ctx, schedule);
        }

        pub fn repeat(self: Self, ctx: *Context(Env), schedule: *Schedule) Parent.FailureType!Parent.SuccessType {
            return repeatEffect(self, ctx, schedule);
        }

        pub fn map(
            self: Self,
            comptime Next: type,
            mapper: *const fn (Parent.SuccessType) Next,
        ) MapEffect(Self, Next, Parent.FailureType, Env) {
            return .{ .parent = self, .mapper = mapper };
        }

        pub fn flatMap(
            self: Self,
            comptime Next: type,
            binder: *const fn (Parent.SuccessType, *Context(Env)) Parent.FailureType!Next,
        ) FlatMapEffect(Self, Next, Parent.FailureType, Env) {
            return .{ .parent = self, .binder = binder };
        }

        pub fn tap(
            self: Self,
            action: *const fn (Parent.SuccessType, *Context(Env)) Parent.FailureType!void,
        ) TapEffect(Self, Parent.FailureType, Env) {
            return .{ .parent = self, .action = action };
        }

        pub fn onExit(
            self: Self,
            action: *const fn (Exit(Self.SuccessType, Self.FailureType), *Context(Env)) Self.FailureType!void,
        ) OnExitEffect(Self, Env) {
            return .{ .parent = self, .action = action };
        }

        pub fn ensuring(
            self: Self,
            finalizer: *const fn (*Context(Env)) Self.FailureType!void,
        ) EnsuringEffect(Self, Env) {
            return .{ .parent = self, .finalizer = finalizer };
        }

        pub fn requires(self: Self, comptime services: anytype) RequiredEffect(Self, services, Env) {
            return .{ .parent = self.parent };
        }
    };
}

pub fn OnExitEffect(comptime Parent: type, comptime Env: type) type {
    return struct {
        const Self = @This();
        pub const SuccessType = Parent.SuccessType;
        pub const FailureType = Parent.FailureType;
        pub const EnvType = Env;

        parent: Parent,
        action: *const fn (Exit(Parent.SuccessType, Parent.FailureType), *Context(Env)) Parent.FailureType!void,

        pub fn run(self: Self, ctx: *Context(Env)) Parent.FailureType!Parent.SuccessType {
            const parent_exit = self.parent.exit(ctx);
            try self.action(parent_exit, ctx);
            return exitToResult(Parent.SuccessType, Parent.FailureType, parent_exit);
        }

        pub fn exit(self: Self, ctx: *Context(Env)) Exit(Parent.SuccessType, Parent.FailureType) {
            const parent_exit = self.parent.exit(ctx);
            self.action(parent_exit, ctx) catch |err| return .{ .failure = err };
            return parent_exit;
        }

        pub fn retry(self: Self, ctx: *Context(Env), schedule: *Schedule) Parent.FailureType!Parent.SuccessType {
            return retryEffect(self, ctx, schedule);
        }

        pub fn repeat(self: Self, ctx: *Context(Env), schedule: *Schedule) Parent.FailureType!Parent.SuccessType {
            return repeatEffect(self, ctx, schedule);
        }

        pub fn map(
            self: Self,
            comptime Next: type,
            mapper: *const fn (Parent.SuccessType) Next,
        ) MapEffect(Self, Next, Parent.FailureType, Env) {
            return .{ .parent = self, .mapper = mapper };
        }

        pub fn flatMap(
            self: Self,
            comptime Next: type,
            binder: *const fn (Parent.SuccessType, *Context(Env)) Parent.FailureType!Next,
        ) FlatMapEffect(Self, Next, Parent.FailureType, Env) {
            return .{ .parent = self, .binder = binder };
        }

        pub fn tap(
            self: Self,
            action: *const fn (Parent.SuccessType, *Context(Env)) Parent.FailureType!void,
        ) TapEffect(Self, Parent.FailureType, Env) {
            return .{ .parent = self, .action = action };
        }

        pub fn onExit(
            self: Self,
            action: *const fn (Exit(Self.SuccessType, Self.FailureType), *Context(Env)) Self.FailureType!void,
        ) OnExitEffect(Self, Env) {
            return .{ .parent = self, .action = action };
        }

        pub fn ensuring(
            self: Self,
            finalizer: *const fn (*Context(Env)) Self.FailureType!void,
        ) EnsuringEffect(Self, Env) {
            return .{ .parent = self, .finalizer = finalizer };
        }
    };
}

pub fn EnsuringEffect(comptime Parent: type, comptime Env: type) type {
    return struct {
        const Self = @This();
        pub const SuccessType = Parent.SuccessType;
        pub const FailureType = Parent.FailureType;
        pub const EnvType = Env;

        parent: Parent,
        finalizer: *const fn (*Context(Env)) Parent.FailureType!void,

        pub fn run(self: Self, ctx: *Context(Env)) Parent.FailureType!Parent.SuccessType {
            const parent_exit = self.parent.exit(ctx);
            try self.finalizer(ctx);
            return exitToResult(Parent.SuccessType, Parent.FailureType, parent_exit);
        }

        pub fn exit(self: Self, ctx: *Context(Env)) Exit(Parent.SuccessType, Parent.FailureType) {
            const parent_exit = self.parent.exit(ctx);
            self.finalizer(ctx) catch |err| return .{ .cause = .{ .finalizer_failure = @errorName(err) } };
            return parent_exit;
        }

        pub fn retry(self: Self, ctx: *Context(Env), schedule: *Schedule) Parent.FailureType!Parent.SuccessType {
            return retryEffect(self, ctx, schedule);
        }

        pub fn repeat(self: Self, ctx: *Context(Env), schedule: *Schedule) Parent.FailureType!Parent.SuccessType {
            return repeatEffect(self, ctx, schedule);
        }

        pub fn map(
            self: Self,
            comptime Next: type,
            mapper: *const fn (Parent.SuccessType) Next,
        ) MapEffect(Self, Next, Parent.FailureType, Env) {
            return .{ .parent = self, .mapper = mapper };
        }

        pub fn flatMap(
            self: Self,
            comptime Next: type,
            binder: *const fn (Parent.SuccessType, *Context(Env)) Parent.FailureType!Next,
        ) FlatMapEffect(Self, Next, Parent.FailureType, Env) {
            return .{ .parent = self, .binder = binder };
        }

        pub fn tap(
            self: Self,
            action: *const fn (Parent.SuccessType, *Context(Env)) Parent.FailureType!void,
        ) TapEffect(Self, Parent.FailureType, Env) {
            return .{ .parent = self, .action = action };
        }

        pub fn onExit(
            self: Self,
            action: *const fn (Exit(Self.SuccessType, Self.FailureType), *Context(Env)) Self.FailureType!void,
        ) OnExitEffect(Self, Env) {
            return .{ .parent = self, .action = action };
        }

        pub fn ensuring(
            self: Self,
            finalizer: *const fn (*Context(Env)) Self.FailureType!void,
        ) EnsuringEffect(Self, Env) {
            return .{ .parent = self, .finalizer = finalizer };
        }
    };
}

pub fn MapEffect(
    comptime Parent: type,
    comptime Success: type,
    comptime Failure: type,
    comptime Env: type,
) type {
    return struct {
        const Self = @This();
        pub const SuccessType = Success;
        pub const FailureType = Failure;
        pub const EnvType = Env;

        parent: Parent,
        mapper: *const fn (Parent.SuccessType) Success,

        pub fn run(self: Self, ctx: *Context(Env)) Failure!Success {
            return self.mapper(try self.parent.run(ctx));
        }

        pub fn exit(self: Self, ctx: *Context(Env)) Exit(Success, Failure) {
            const value = self.run(ctx) catch |err| return .{ .failure = err };
            return .{ .success = value };
        }

        pub fn retry(self: Self, ctx: *Context(Env), schedule: *Schedule) Failure!Success {
            return retryEffect(self, ctx, schedule);
        }

        pub fn repeat(self: Self, ctx: *Context(Env), schedule: *Schedule) Failure!Success {
            return repeatEffect(self, ctx, schedule);
        }

        pub fn map(
            self: Self,
            comptime Next: type,
            mapper: *const fn (Success) Next,
        ) MapEffect(Self, Next, Failure, Env) {
            return .{ .parent = self, .mapper = mapper };
        }

        pub fn flatMap(
            self: Self,
            comptime Next: type,
            binder: *const fn (Success, *Context(Env)) Failure!Next,
        ) FlatMapEffect(Self, Next, Failure, Env) {
            return .{ .parent = self, .binder = binder };
        }

        pub fn tap(
            self: Self,
            action: *const fn (Success, *Context(Env)) Failure!void,
        ) TapEffect(Self, Failure, Env) {
            return .{ .parent = self, .action = action };
        }

        pub fn mapError(
            self: Self,
            comptime NextFailure: type,
            mapper: *const fn (Failure) NextFailure,
        ) MapErrorEffect(Self, NextFailure, Env) {
            return .{ .parent = self, .mapper = mapper };
        }

        pub fn catchAll(
            self: Self,
            comptime NextFailure: type,
            handler: *const fn (Failure, *Context(Env)) NextFailure!Success,
        ) CatchAllEffect(Self, NextFailure, Env) {
            return .{ .parent = self, .handler = handler };
        }

        pub fn orElse(self: Self, fallback: anytype) OrElseEffect(Self, @TypeOf(fallback), Env) {
            return .{ .parent = self, .fallback = fallback };
        }

        pub fn tapError(
            self: Self,
            action: *const fn (Failure, *Context(Env)) Failure!void,
        ) TapErrorEffect(Self, Failure, Env) {
            return .{ .parent = self, .action = action };
        }

        pub fn onExit(
            self: Self,
            action: *const fn (Exit(Self.SuccessType, Self.FailureType), *Context(Env)) Self.FailureType!void,
        ) OnExitEffect(Self, Env) {
            return .{ .parent = self, .action = action };
        }

        pub fn ensuring(
            self: Self,
            finalizer: *const fn (*Context(Env)) Self.FailureType!void,
        ) EnsuringEffect(Self, Env) {
            return .{ .parent = self, .finalizer = finalizer };
        }
    };
}

pub fn FlatMapEffect(
    comptime Parent: type,
    comptime Success: type,
    comptime Failure: type,
    comptime Env: type,
) type {
    return struct {
        const Self = @This();
        pub const SuccessType = Success;
        pub const FailureType = Failure;
        pub const EnvType = Env;

        parent: Parent,
        binder: *const fn (Parent.SuccessType, *Context(Env)) Failure!Success,

        pub fn run(self: Self, ctx: *Context(Env)) Failure!Success {
            return self.binder(try self.parent.run(ctx), ctx);
        }

        pub fn exit(self: Self, ctx: *Context(Env)) Exit(Success, Failure) {
            const value = self.run(ctx) catch |err| return .{ .failure = err };
            return .{ .success = value };
        }

        pub fn retry(self: Self, ctx: *Context(Env), schedule: *Schedule) Failure!Success {
            return retryEffect(self, ctx, schedule);
        }

        pub fn repeat(self: Self, ctx: *Context(Env), schedule: *Schedule) Failure!Success {
            return repeatEffect(self, ctx, schedule);
        }

        pub fn map(
            self: Self,
            comptime Next: type,
            mapper: *const fn (Success) Next,
        ) MapEffect(Self, Next, Failure, Env) {
            return .{ .parent = self, .mapper = mapper };
        }

        pub fn flatMap(
            self: Self,
            comptime Next: type,
            binder: *const fn (Success, *Context(Env)) Failure!Next,
        ) FlatMapEffect(Self, Next, Failure, Env) {
            return .{ .parent = self, .binder = binder };
        }

        pub fn tap(
            self: Self,
            action: *const fn (Success, *Context(Env)) Failure!void,
        ) TapEffect(Self, Failure, Env) {
            return .{ .parent = self, .action = action };
        }

        pub fn mapError(
            self: Self,
            comptime NextFailure: type,
            mapper: *const fn (Failure) NextFailure,
        ) MapErrorEffect(Self, NextFailure, Env) {
            return .{ .parent = self, .mapper = mapper };
        }

        pub fn catchAll(
            self: Self,
            comptime NextFailure: type,
            handler: *const fn (Failure, *Context(Env)) NextFailure!Success,
        ) CatchAllEffect(Self, NextFailure, Env) {
            return .{ .parent = self, .handler = handler };
        }

        pub fn orElse(self: Self, fallback: anytype) OrElseEffect(Self, @TypeOf(fallback), Env) {
            return .{ .parent = self, .fallback = fallback };
        }

        pub fn tapError(
            self: Self,
            action: *const fn (Failure, *Context(Env)) Failure!void,
        ) TapErrorEffect(Self, Failure, Env) {
            return .{ .parent = self, .action = action };
        }

        pub fn onExit(
            self: Self,
            action: *const fn (Exit(Self.SuccessType, Self.FailureType), *Context(Env)) Self.FailureType!void,
        ) OnExitEffect(Self, Env) {
            return .{ .parent = self, .action = action };
        }

        pub fn ensuring(
            self: Self,
            finalizer: *const fn (*Context(Env)) Self.FailureType!void,
        ) EnsuringEffect(Self, Env) {
            return .{ .parent = self, .finalizer = finalizer };
        }
    };
}

pub fn TapEffect(comptime Parent: type, comptime Failure: type, comptime Env: type) type {
    return struct {
        const Self = @This();
        pub const SuccessType = Parent.SuccessType;
        pub const FailureType = Failure;
        pub const EnvType = Env;

        parent: Parent,
        action: *const fn (Parent.SuccessType, *Context(Env)) Failure!void,

        pub fn run(self: Self, ctx: *Context(Env)) Failure!Parent.SuccessType {
            const value = try self.parent.run(ctx);
            try self.action(value, ctx);
            return value;
        }

        pub fn exit(self: Self, ctx: *Context(Env)) Exit(Parent.SuccessType, Failure) {
            const value = self.run(ctx) catch |err| return .{ .failure = err };
            return .{ .success = value };
        }

        pub fn retry(self: Self, ctx: *Context(Env), schedule: *Schedule) Failure!Parent.SuccessType {
            return retryEffect(self, ctx, schedule);
        }

        pub fn repeat(self: Self, ctx: *Context(Env), schedule: *Schedule) Failure!Parent.SuccessType {
            return repeatEffect(self, ctx, schedule);
        }

        pub fn map(
            self: Self,
            comptime Next: type,
            mapper: *const fn (Parent.SuccessType) Next,
        ) MapEffect(Self, Next, Failure, Env) {
            return .{ .parent = self, .mapper = mapper };
        }

        pub fn flatMap(
            self: Self,
            comptime Next: type,
            binder: *const fn (Parent.SuccessType, *Context(Env)) Failure!Next,
        ) FlatMapEffect(Self, Next, Failure, Env) {
            return .{ .parent = self, .binder = binder };
        }

        pub fn tap(
            self: Self,
            action: *const fn (Parent.SuccessType, *Context(Env)) Failure!void,
        ) TapEffect(Self, Failure, Env) {
            return .{ .parent = self, .action = action };
        }

        pub fn mapError(
            self: Self,
            comptime NextFailure: type,
            mapper: *const fn (Failure) NextFailure,
        ) MapErrorEffect(Self, NextFailure, Env) {
            return .{ .parent = self, .mapper = mapper };
        }

        pub fn catchAll(
            self: Self,
            comptime NextFailure: type,
            handler: *const fn (Failure, *Context(Env)) NextFailure!Parent.SuccessType,
        ) CatchAllEffect(Self, NextFailure, Env) {
            return .{ .parent = self, .handler = handler };
        }

        pub fn orElse(self: Self, fallback: anytype) OrElseEffect(Self, @TypeOf(fallback), Env) {
            return .{ .parent = self, .fallback = fallback };
        }

        pub fn tapError(
            self: Self,
            action: *const fn (Failure, *Context(Env)) Failure!void,
        ) TapErrorEffect(Self, Failure, Env) {
            return .{ .parent = self, .action = action };
        }

        pub fn onExit(
            self: Self,
            action: *const fn (Exit(Self.SuccessType, Self.FailureType), *Context(Env)) Self.FailureType!void,
        ) OnExitEffect(Self, Env) {
            return .{ .parent = self, .action = action };
        }

        pub fn ensuring(
            self: Self,
            finalizer: *const fn (*Context(Env)) Self.FailureType!void,
        ) EnsuringEffect(Self, Env) {
            return .{ .parent = self, .finalizer = finalizer };
        }
    };
}

pub fn MapErrorEffect(comptime Parent: type, comptime Failure: type, comptime Env: type) type {
    return struct {
        const Self = @This();
        pub const SuccessType = Parent.SuccessType;
        pub const FailureType = Failure;
        pub const EnvType = Env;

        parent: Parent,
        mapper: *const fn (Parent.FailureType) Failure,

        pub fn run(self: Self, ctx: *Context(Env)) Failure!Parent.SuccessType {
            return self.parent.run(ctx) catch |err| return self.mapper(err);
        }

        pub fn exit(self: Self, ctx: *Context(Env)) Exit(Parent.SuccessType, Failure) {
            const value = self.run(ctx) catch |err| return .{ .failure = err };
            return .{ .success = value };
        }

        pub fn retry(self: Self, ctx: *Context(Env), schedule: *Schedule) Failure!Parent.SuccessType {
            return retryEffect(self, ctx, schedule);
        }

        pub fn repeat(self: Self, ctx: *Context(Env), schedule: *Schedule) Failure!Parent.SuccessType {
            return repeatEffect(self, ctx, schedule);
        }

        pub fn map(
            self: Self,
            comptime Next: type,
            mapper: *const fn (Parent.SuccessType) Next,
        ) MapEffect(Self, Next, Failure, Env) {
            return .{ .parent = self, .mapper = mapper };
        }

        pub fn flatMap(
            self: Self,
            comptime Next: type,
            binder: *const fn (Parent.SuccessType, *Context(Env)) Failure!Next,
        ) FlatMapEffect(Self, Next, Failure, Env) {
            return .{ .parent = self, .binder = binder };
        }

        pub fn tap(
            self: Self,
            action: *const fn (Parent.SuccessType, *Context(Env)) Failure!void,
        ) TapEffect(Self, Failure, Env) {
            return .{ .parent = self, .action = action };
        }

        pub fn onExit(
            self: Self,
            action: *const fn (Exit(Self.SuccessType, Self.FailureType), *Context(Env)) Self.FailureType!void,
        ) OnExitEffect(Self, Env) {
            return .{ .parent = self, .action = action };
        }

        pub fn ensuring(
            self: Self,
            finalizer: *const fn (*Context(Env)) Self.FailureType!void,
        ) EnsuringEffect(Self, Env) {
            return .{ .parent = self, .finalizer = finalizer };
        }
    };
}

pub fn CatchAllEffect(comptime Parent: type, comptime Failure: type, comptime Env: type) type {
    return struct {
        const Self = @This();
        pub const SuccessType = Parent.SuccessType;
        pub const FailureType = Failure;
        pub const EnvType = Env;

        parent: Parent,
        handler: *const fn (Parent.FailureType, *Context(Env)) Failure!Parent.SuccessType,

        pub fn run(self: Self, ctx: *Context(Env)) Failure!Parent.SuccessType {
            return self.parent.run(ctx) catch |err| self.handler(err, ctx);
        }

        pub fn exit(self: Self, ctx: *Context(Env)) Exit(Parent.SuccessType, Failure) {
            const value = self.run(ctx) catch |err| return .{ .failure = err };
            return .{ .success = value };
        }

        pub fn retry(self: Self, ctx: *Context(Env), schedule: *Schedule) Failure!Parent.SuccessType {
            return retryEffect(self, ctx, schedule);
        }

        pub fn repeat(self: Self, ctx: *Context(Env), schedule: *Schedule) Failure!Parent.SuccessType {
            return repeatEffect(self, ctx, schedule);
        }

        pub fn map(
            self: Self,
            comptime Next: type,
            mapper: *const fn (Parent.SuccessType) Next,
        ) MapEffect(Self, Next, Failure, Env) {
            return .{ .parent = self, .mapper = mapper };
        }

        pub fn flatMap(
            self: Self,
            comptime Next: type,
            binder: *const fn (Parent.SuccessType, *Context(Env)) Failure!Next,
        ) FlatMapEffect(Self, Next, Failure, Env) {
            return .{ .parent = self, .binder = binder };
        }

        pub fn tap(
            self: Self,
            action: *const fn (Parent.SuccessType, *Context(Env)) Failure!void,
        ) TapEffect(Self, Failure, Env) {
            return .{ .parent = self, .action = action };
        }

        pub fn onExit(
            self: Self,
            action: *const fn (Exit(Self.SuccessType, Self.FailureType), *Context(Env)) Self.FailureType!void,
        ) OnExitEffect(Self, Env) {
            return .{ .parent = self, .action = action };
        }

        pub fn ensuring(
            self: Self,
            finalizer: *const fn (*Context(Env)) Self.FailureType!void,
        ) EnsuringEffect(Self, Env) {
            return .{ .parent = self, .finalizer = finalizer };
        }
    };
}

pub fn OrElseEffect(comptime Parent: type, comptime Fallback: type, comptime Env: type) type {
    return struct {
        const Self = @This();
        pub const SuccessType = Parent.SuccessType;
        pub const FailureType = Fallback.FailureType;
        pub const EnvType = Env;

        parent: Parent,
        fallback: Fallback,

        pub fn run(self: Self, ctx: *Context(Env)) Fallback.FailureType!Parent.SuccessType {
            return self.parent.run(ctx) catch {
                const value: Parent.SuccessType = try self.fallback.run(ctx);
                return value;
            };
        }

        pub fn exit(self: Self, ctx: *Context(Env)) Exit(Parent.SuccessType, Fallback.FailureType) {
            const value = self.run(ctx) catch |err| return .{ .failure = err };
            return .{ .success = value };
        }

        pub fn retry(self: Self, ctx: *Context(Env), schedule: *Schedule) Fallback.FailureType!Parent.SuccessType {
            return retryEffect(self, ctx, schedule);
        }

        pub fn repeat(self: Self, ctx: *Context(Env), schedule: *Schedule) Fallback.FailureType!Parent.SuccessType {
            return repeatEffect(self, ctx, schedule);
        }

        pub fn map(
            self: Self,
            comptime Next: type,
            mapper: *const fn (Parent.SuccessType) Next,
        ) MapEffect(Self, Next, Fallback.FailureType, Env) {
            return .{ .parent = self, .mapper = mapper };
        }

        pub fn tap(
            self: Self,
            action: *const fn (Parent.SuccessType, *Context(Env)) Fallback.FailureType!void,
        ) TapEffect(Self, Fallback.FailureType, Env) {
            return .{ .parent = self, .action = action };
        }

        pub fn onExit(
            self: Self,
            action: *const fn (Exit(Self.SuccessType, Self.FailureType), *Context(Env)) Self.FailureType!void,
        ) OnExitEffect(Self, Env) {
            return .{ .parent = self, .action = action };
        }

        pub fn ensuring(
            self: Self,
            finalizer: *const fn (*Context(Env)) Self.FailureType!void,
        ) EnsuringEffect(Self, Env) {
            return .{ .parent = self, .finalizer = finalizer };
        }
    };
}

pub fn TapErrorEffect(comptime Parent: type, comptime Failure: type, comptime Env: type) type {
    return struct {
        const Self = @This();
        pub const SuccessType = Parent.SuccessType;
        pub const FailureType = Failure;
        pub const EnvType = Env;

        parent: Parent,
        action: *const fn (Parent.FailureType, *Context(Env)) Failure!void,

        pub fn run(self: Self, ctx: *Context(Env)) Failure!Parent.SuccessType {
            return self.parent.run(ctx) catch |err| {
                try self.action(err, ctx);
                return err;
            };
        }

        pub fn exit(self: Self, ctx: *Context(Env)) Exit(Parent.SuccessType, Failure) {
            const value = self.run(ctx) catch |err| return .{ .failure = err };
            return .{ .success = value };
        }

        pub fn retry(self: Self, ctx: *Context(Env), schedule: *Schedule) Failure!Parent.SuccessType {
            return retryEffect(self, ctx, schedule);
        }

        pub fn repeat(self: Self, ctx: *Context(Env), schedule: *Schedule) Failure!Parent.SuccessType {
            return repeatEffect(self, ctx, schedule);
        }

        pub fn map(
            self: Self,
            comptime Next: type,
            mapper: *const fn (Parent.SuccessType) Next,
        ) MapEffect(Self, Next, Failure, Env) {
            return .{ .parent = self, .mapper = mapper };
        }

        pub fn tap(
            self: Self,
            action: *const fn (Parent.SuccessType, *Context(Env)) Failure!void,
        ) TapEffect(Self, Failure, Env) {
            return .{ .parent = self, .action = action };
        }

        pub fn onExit(
            self: Self,
            action: *const fn (Exit(Self.SuccessType, Self.FailureType), *Context(Env)) Self.FailureType!void,
        ) OnExitEffect(Self, Env) {
            return .{ .parent = self, .action = action };
        }

        pub fn ensuring(
            self: Self,
            finalizer: *const fn (*Context(Env)) Self.FailureType!void,
        ) EnsuringEffect(Self, Env) {
            return .{ .parent = self, .finalizer = finalizer };
        }
    };
}

pub fn retryEffect(effect: anytype, ctx: *Context(@TypeOf(effect).EnvType), schedule: *Schedule) @TypeOf(effect).FailureType!@TypeOf(effect).SuccessType {
    var attempt: usize = 0;

    while (true) {
        return effect.run(ctx) catch |err| {
            const decision = schedule.decision(attempt);
            if (decision.delay_ms) |delay_ms| {
                recordScheduleDecision(ctx, schedule, decision.attempt, delay_ms, "retry");
                if (ctx.clock) |clock| {
                    clock.sleep(delay_ms);
                }
                attempt += 1;
                continue;
            }

            recordScheduleExhausted(ctx, schedule, decision.attempt);
            return err;
        };
    }
}

pub fn repeatEffect(effect: anytype, ctx: *Context(@TypeOf(effect).EnvType), schedule: *Schedule) @TypeOf(effect).FailureType!@TypeOf(effect).SuccessType {
    var repetition: usize = 0;
    var value = try effect.run(ctx);

    while (true) {
        const decision = schedule.decision(repetition);
        const delay_ms = decision.delay_ms orelse {
            recordScheduleStopped(ctx, schedule, decision.attempt);
            break;
        };
        recordScheduleDecision(ctx, schedule, decision.attempt, delay_ms, "repeat");
        if (ctx.clock) |clock| {
            clock.sleep(delay_ms);
        }
        repetition += 1;
        value = try effect.run(ctx);
    }

    return value;
}

fn recordScheduleDecision(
    ctx: anytype,
    schedule: *Schedule,
    attempt: usize,
    delay_ms: u64,
    decision: []const u8,
) void {
    const detail = std.fmt.allocPrint(
        ctx.allocator,
        "attempt={d} delay_ms={d} decision={s}",
        .{ attempt, delay_ms, decision },
    ) catch return;
    defer ctx.allocator.free(detail);

    _ = ctx.recordCausal(.{
        .kind = .schedule_decision,
        .label = schedule.labelOrKind(),
        .status = decision,
        .redacted_detail = detail,
    });
}

fn recordScheduleTerminal(
    ctx: anytype,
    schedule: *Schedule,
    attempt: usize,
    decision: []const u8,
) void {
    const detail = std.fmt.allocPrint(
        ctx.allocator,
        "attempt={d} delay_ms=null decision={s}",
        .{ attempt, decision },
    ) catch return;
    defer ctx.allocator.free(detail);

    _ = ctx.recordCausal(.{
        .kind = .schedule_decision,
        .label = schedule.labelOrKind(),
        .status = decision,
        .redacted_detail = detail,
    });
}

fn recordScheduleExhausted(ctx: anytype, schedule: *Schedule, attempt: usize) void {
    recordScheduleTerminal(ctx, schedule, attempt, "exhausted");
}

fn recordScheduleStopped(ctx: anytype, schedule: *Schedule, attempt: usize) void {
    recordScheduleTerminal(ctx, schedule, attempt, "stopped");
}
