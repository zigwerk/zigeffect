const std = @import("std");
const fx = @import("zigeffect");

const AppError = error{ MissingScope, OutOfMemory };

const Probe = struct {
    observed: bool = false,
};

var probe = Probe{};

fn observeProbe(value: *Probe, exit: fx.FinalizerExit) void {
    _ = exit;
    value.observed = true;
}

fn childWork(ctx: *fx.Context(fx.TestServices)) AppError!u32 {
    probe = .{};
    try ctx.addFinalizerExitFor(Probe, &probe, observeProbe);
    return 7;
}

const Child = fx.Effect(u32, AppError, fx.TestServices)
    .fromFn(childWork);

fn hasEvent(store: *const fx.CausalStore, kind: fx.CausalEventKind, status: []const u8) bool {
    for (store.events.items) |event| {
        if (event.kind == kind and std.mem.eql(u8, event.status, status)) return true;
    }
    return false;
}

fn runScenario(allocator: std.mem.Allocator, store: *fx.CausalStore) !void {
    var env = try fx.TestEnv.init(allocator);
    defer env.deinit();

    var runtime = fx.FiberRuntime(fx.TestServices)
        .init(allocator, &env.services)
        .withClock(&env.services.clock)
        .withCausalStore(store)
        .provides(.{ fx.Logger, fx.Config, fx.Metrics, fx.Tracing, fx.MemoryFileSystem, fx.Clock });
    defer runtime.deinit();

    var ctx = env.context();
    const fiber = try runtime.forkScoped(&ctx, Child);
    env.scope.closeWithExit(.success);

    const exit = runtime.join(fiber);
    switch (exit) {
        .interrupted => |id| if (id != fiber.id) return error.UnexpectedFiber,
        else => return error.ExpectedInterruptedFiber,
    }
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    var store = fx.CausalStore.init(allocator);
    defer store.deinit();

    try runScenario(allocator, &store);

    const report = try fx.formatCausalReport(allocator, "scoped fiber scenario", &store);
    defer allocator.free(report);
    std.debug.print("{s}", .{report});
}

test "scoped fiber scenario records parent close interruption evidence" {
    var store = fx.CausalStore.init(std.testing.allocator);
    defer store.deinit();

    try runScenario(std.testing.allocator, &store);

    try std.testing.expect(hasEvent(&store, .fiber_forked, "pending"));
    try std.testing.expect(hasEvent(&store, .fiber_interrupted, "interrupted"));
    try std.testing.expect(hasEvent(&store, .scope_closed, "interrupted"));
    try std.testing.expect(hasEvent(&store, .fiber_joined, "interrupted"));
}
