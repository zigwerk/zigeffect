const context_mod = @import("../core/context.zig");
const scope_mod = @import("../core/scope.zig");
const result = @import("../core/result.zig");
const dep_contracts = @import("../dependency/contracts.zig");
const identity_mod = @import("../core/runtime_identity.zig");

pub const Context = context_mod.Context;
pub const Scope = scope_mod.Scope;
pub const Exit = result.Exit;
pub const finalizerExitFromExit = result.finalizerExitFromExit;
pub const exitWithFinalizerFailure = result.exitWithFinalizerFailure;
pub const assertEffectEnvironment = dep_contracts.assertEffectEnvironment;

fn recordExit(
    ctx: anytype,
    parent_id: ?u64,
    exit: anytype,
) void {
    switch (exit) {
        .success => {
            _ = ctx.recordCausal(.{
                .kind = .exit_recorded,
                .parent_id = parent_id,
                .status = "success",
            });
        },
        .failure => |err| {
            _ = ctx.recordCausal(.{
                .kind = .exit_recorded,
                .parent_id = parent_id,
                .status = "failure",
                .type_name = @errorName(err),
            });
        },
        .defect => |message| {
            _ = ctx.recordCausal(.{
                .kind = .exit_recorded,
                .parent_id = parent_id,
                .status = "defect",
                .type_name = message,
            });
        },
        .interrupted => |fiber_id| {
            _ = ctx.recordCausal(.{
                .kind = .exit_recorded,
                .parent_id = parent_id,
                .status = "interrupted",
                .fiber_id = fiber_id,
            });
        },
        .cause => |cause| {
            _ = ctx.recordCausal(.{
                .kind = .exit_recorded,
                .parent_id = parent_id,
                .status = "cause",
                .type_name = @tagName(cause),
            });
        },
    }
}

fn recordRunStarted(
    comptime api: []const u8,
    ctx: anytype,
    effect: anytype,
) ?u64 {
    return ctx.recordCausal(.{
        .kind = .run_started,
        .label = api,
        .type_name = identity_mod.boundedTypeName(@TypeOf(effect)),
    });
}

fn recordRunCompleted(
    comptime api: []const u8,
    ctx: anytype,
    parent_id: ?u64,
    status: []const u8,
    type_name: []const u8,
) void {
    _ = ctx.recordCausal(.{
        .kind = .run_completed,
        .parent_id = parent_id,
        .label = api,
        .status = status,
        .type_name = type_name,
    });
}

fn recordRunCompletedFromExit(
    comptime api: []const u8,
    ctx: anytype,
    parent_id: ?u64,
    exit: anytype,
) void {
    recordRunCompleted(
        api,
        ctx,
        parent_id,
        switch (exit) {
            .success => "success",
            .failure => "failure",
            .defect => "defect",
            .interrupted => "interrupted",
            .cause => "cause",
        },
        "",
    );
}

fn attachManagedCausalScope(
    ctx: anytype,
    scope: *Scope,
    parent_id: ?u64,
) void {
    const store = ctx.causal_store orelse return;
    const run_id = ctx.ensureCausalRunId() orelse return;
    scope.attachCausal(store, run_id, parent_id, ctx.trace_id, ctx.span_id);
}

pub fn runManagedScope(
    comptime api: []const u8,
    comptime Env: type,
    ctx: *Context(Env),
    scope: *Scope,
    effect: anytype,
) @TypeOf(effect).FailureType!@TypeOf(effect).SuccessType {
    assertEffectEnvironment(api, Env, effect);

    const started = recordRunStarted(api, ctx, effect);
    attachManagedCausalScope(ctx, scope, started);
    const previous_parent = ctx.causal_parent_id;
    ctx.causal_parent_id = started orelse previous_parent;
    defer ctx.causal_parent_id = previous_parent;

    const value = ctx.runEffect(effect) catch |err| {
        scope.closeWithExit(.{ .failure = @errorName(err) });
        recordExit(ctx, started, Exit(@TypeOf(effect).SuccessType, @TypeOf(effect).FailureType){ .failure = err });
        recordRunCompleted(api, ctx, started, "failure", @errorName(err));
        return err;
    };
    scope.closeWithExit(.success);
    recordExit(ctx, started, Exit(@TypeOf(effect).SuccessType, @TypeOf(effect).FailureType){ .success = value });
    recordRunCompleted(api, ctx, started, "success", "");
    return value;
}

pub fn runCallerOwnedScope(
    comptime api: []const u8,
    comptime Env: type,
    ctx: *Context(Env),
    effect: anytype,
) @TypeOf(effect).FailureType!@TypeOf(effect).SuccessType {
    assertEffectEnvironment(api, Env, effect);

    const started = recordRunStarted(api, ctx, effect);
    if (ctx.scope) |scope| attachManagedCausalScope(ctx, scope, started);
    const previous_parent = ctx.causal_parent_id;
    ctx.causal_parent_id = started orelse previous_parent;
    defer ctx.causal_parent_id = previous_parent;

    const value = ctx.runEffect(effect) catch |err| {
        recordExit(ctx, started, Exit(@TypeOf(effect).SuccessType, @TypeOf(effect).FailureType){ .failure = err });
        recordRunCompleted(api, ctx, started, "failure", @errorName(err));
        return err;
    };
    recordExit(ctx, started, Exit(@TypeOf(effect).SuccessType, @TypeOf(effect).FailureType){ .success = value });
    recordRunCompleted(api, ctx, started, "success", "");
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

    const started = recordRunStarted(api, ctx, effect);
    attachManagedCausalScope(ctx, scope, started);
    const previous_parent = ctx.causal_parent_id;
    ctx.causal_parent_id = started orelse previous_parent;
    defer ctx.causal_parent_id = previous_parent;
    const base_exit = ctx.exitEffect(effect);
    scope.closeWithExit(finalizerExitFromExit(base_exit));

    if (scope.firstFinalizerFailure()) |failure| {
        const final_exit = exitWithFinalizerFailure(@TypeOf(effect).SuccessType, @TypeOf(effect).FailureType, base_exit, failure);
        recordExit(ctx, started, final_exit);
        recordRunCompleted(api, ctx, started, "cause", "");
        return final_exit;
    }

    recordExit(ctx, started, base_exit);
    recordRunCompletedFromExit(api, ctx, started, base_exit);
    return base_exit;
}

pub fn exitCallerOwnedScope(
    comptime api: []const u8,
    comptime Env: type,
    ctx: *Context(Env),
    effect: anytype,
) Exit(@TypeOf(effect).SuccessType, @TypeOf(effect).FailureType) {
    assertEffectEnvironment(api, Env, effect);

    const started = recordRunStarted(api, ctx, effect);
    if (ctx.scope) |scope| attachManagedCausalScope(ctx, scope, started);
    const previous_parent = ctx.causal_parent_id;
    ctx.causal_parent_id = started orelse previous_parent;
    defer ctx.causal_parent_id = previous_parent;
    const base_exit = ctx.exitEffect(effect);
    recordExit(ctx, started, base_exit);
    recordRunCompletedFromExit(api, ctx, started, base_exit);
    return base_exit;
}
