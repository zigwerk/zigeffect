const std = @import("std");
const fx = @import("zigeffect");

const AppEnv = struct {};
const OtherEnv = struct {};

fn runOther(_: *fx.Context(OtherEnv)) error{}!u32 {
    return 1;
}

pub fn main() void {
    var env = AppEnv{};
    var runtime = fx.FiberRuntime(AppEnv).init(std.heap.page_allocator, &env);
    defer runtime.deinit();
    const program = fx.Effect(u32, error{}, OtherEnv).fromFn(runOther);

    _ = runtime.fork(program) catch {};
}
