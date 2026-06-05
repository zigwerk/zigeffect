const context_mod = @import("../core/context.zig");
const scope_mod = @import("../core/scope.zig");
const result = @import("../core/result.zig");
const dep_contracts = @import("../dependency/contracts.zig");

pub const Context = context_mod.Context;
pub const Scope = scope_mod.Scope;
pub const Exit = result.Exit;
pub const finalizerExitFromExit = result.finalizerExitFromExit;
pub const exitWithFinalizerFailure = result.exitWithFinalizerFailure;
pub const assertEffectEnvironment = dep_contracts.assertEffectEnvironment;

pub fn runManagedScope(
    comptime api: []const u8,
    comptime Env: type,
    ctx: *Context(Env),
    scope: *Scope,
    effect: anytype,
) @TypeOf(effect).FailureType!@TypeOf(effect).SuccessType {
    assertEffectEnvironment(api, Env, effect);

    const value = effect.run(ctx) catch |err| {
        scope.closeWithExit(.{ .failure = @errorName(err) });
        return err;
    };
    scope.closeWithExit(.success);
    return value;
}

pub fn exitManagedScope(
    comptime api: []const u8,
    comptime Env: type,
    ctx: *Context(Env),
    scope: *Scope,
    effect: anytype,
) Exit(@TypeOf(effect).SuccessType, @TypeOf(effect).FailureType) {
    assertEffectEnvironment(api, Env, effect);

    const base_exit = effect.exit(ctx);
    scope.closeWithExit(finalizerExitFromExit(base_exit));

    if (scope.firstFinalizerFailure()) |failure| {
        return exitWithFinalizerFailure(@TypeOf(effect).SuccessType, @TypeOf(effect).FailureType, base_exit, failure);
    }

    return base_exit;
}
