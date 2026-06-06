const std = @import("std");
const fx = @import("zigeffect");

const AppError = error{ InvalidInput, MissingScope, OutOfMemory };

const Resource = struct {
    allocator: std.mem.Allocator,
};

fn releaseFailing(resource: *Resource) anyerror!void {
    const allocator = resource.allocator;
    allocator.destroy(resource);
    return error.CloseFailed;
}

fn failWithCleanup(ctx: *fx.Context(fx.TestServices)) AppError!u32 {
    const resource = try ctx.allocator.create(Resource);
    resource.* = .{ .allocator = ctx.allocator };
    ctx.addFinalizerFallibleFor(Resource, resource, releaseFailing) catch |err| {
        ctx.allocator.destroy(resource);
        return err;
    };
    return error.InvalidInput;
}

const Program = fx.Effect(u32, AppError, fx.TestServices)
    .fromFn(failWithCleanup);

fn hasEvent(store: *const fx.CausalStore, kind: fx.CausalEventKind, status: []const u8) bool {
    for (store.events.items) |event| {
        if (event.kind == kind and std.mem.eql(u8, event.status, status)) return true;
    }
    return false;
}

fn runScenario(allocator: std.mem.Allocator, store: *fx.CausalStore) !void {
    var env = try fx.TestEnv.init(allocator);
    defer env.deinit();

    var runtime = env.runtime().withCausalStore(store);
    const exit = runtime.exit(Program);
    switch (exit) {
        .cause => |cause| switch (cause) {
            .failure_then_finalizer_failure => |both| {
                if (both.failure != error.InvalidInput) return error.UnexpectedFailure;
                if (!std.mem.eql(u8, both.finalizer_failure, "CloseFailed")) return error.UnexpectedFailure;
            },
            else => return error.ExpectedCleanupCause,
        },
        else => return error.ExpectedCleanupCause,
    }
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    var store = fx.CausalStore.init(allocator);
    defer store.deinit();

    try runScenario(allocator, &store);

    const report = try fx.formatCausalReport(allocator, "cleanup failure scenario", &store);
    defer allocator.free(report);
    std.debug.print("{s}", .{report});
}

test "cleanup failure scenario records combined failure and resource lineage" {
    var store = fx.CausalStore.init(std.testing.allocator);
    defer store.deinit();

    try runScenario(std.testing.allocator, &store);

    try std.testing.expect(hasEvent(&store, .resource_acquired, "success"));
    try std.testing.expect(hasEvent(&store, .resource_finalized, "failure"));
    try std.testing.expect(hasEvent(&store, .scope_closed, "failure"));
    try std.testing.expect(hasEvent(&store, .exit_recorded, "cause"));
}
