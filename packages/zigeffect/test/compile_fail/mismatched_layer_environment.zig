const std = @import("std");
const fx = @import("zigeffect");

const AppEnv = struct {};
const OtherEnv = struct {};

fn runOther(_: *fx.Context(OtherEnv)) error{}!u32 {
    return 1;
}

pub fn main() void {
    var env = AppEnv{};
    const layer = fx.Layer(AppEnv).fromEnv(&env);
    const program = fx.Effect(u32, error{}, OtherEnv).fromFn(runOther);

    _ = layer.provide(std.heap.page_allocator, program) catch {};
}
