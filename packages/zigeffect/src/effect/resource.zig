const std = @import("std");
const context_mod = @import("../core/context.zig");
const effect_mod = @import("effect.zig");

pub const Allocator = std.mem.Allocator;
pub const Context = context_mod.Context;
pub const Effect = effect_mod.Effect;

fn assertErrorSet(comptime Failure: type) void {
    switch (@typeInfo(Failure)) {
        .error_set => {},
        else => @compileError(
            "zigeffect resource failure set\n\n" ++
                "Resource helpers require a Zig error set type.",
        ),
    }
}

fn assertResourceFailureSet(comptime Failure: type) void {
    assertErrorSet(Failure);
    if ((Failure || error{MissingScope}) != Failure) {
        @compileError(
            "zigeffect resource failure set\n\n" ++
                "acquireRelease/acquireReleaseValue failure sets must include MissingScope, " ++
                "because registering scoped finalizers can fail when no scope is available.",
        );
    }
    if ((Failure || error{OutOfMemory}) != Failure) {
        @compileError(
            "zigeffect resource failure set\n\n" ++
                "acquireRelease/acquireReleaseValue failure sets must include OutOfMemory, " ++
                "because registering scoped finalizers can fail with either error.",
        );
    }
}

pub fn acquireRelease(
    comptime Resource: type,
    comptime Failure: type,
    comptime Env: type,
    comptime acquire: *const fn (*Context(Env)) Failure!*Resource,
    comptime release: *const fn (*Resource) void,
) Effect(*Resource, Failure, Env) {
    assertResourceFailureSet(Failure);

    const Runner = struct {
        fn run(ctx: *Context(Env)) Failure!*Resource {
            const resource = try acquire(ctx);
            ctx.addFinalizerFor(Resource, resource, release) catch |err| {
                release(resource);
                return err;
            };
            return resource;
        }
    };

    return Effect(*Resource, Failure, Env).fromFn(Runner.run);
}

pub fn acquireReleaseValue(
    comptime Resource: type,
    comptime Failure: type,
    comptime Env: type,
    comptime acquire: *const fn (*Context(Env)) Failure!Resource,
    comptime release: *const fn (Resource) void,
) Effect(Resource, Failure, Env) {
    assertResourceFailureSet(Failure);

    const Runner = struct {
        const Box = struct {
            allocator: Allocator,
            value: Resource,
        };

        fn releaseBox(box: *Box) void {
            const allocator = box.allocator;
            release(box.value);
            allocator.destroy(box);
        }

        fn run(ctx: *Context(Env)) Failure!Resource {
            const value = try acquire(ctx);
            const box = ctx.allocator.create(Box) catch |err| {
                release(value);
                return err;
            };
            box.* = .{
                .allocator = ctx.allocator,
                .value = value,
            };

            ctx.addFinalizerFor(Box, box, releaseBox) catch |err| {
                release(box.value);
                ctx.allocator.destroy(box);
                return err;
            };
            return value;
        }
    };

    return Effect(Resource, Failure, Env).fromFn(Runner.run);
}
