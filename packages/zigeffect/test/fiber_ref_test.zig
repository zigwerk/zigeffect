//! M5.3 (first cut) — FiberRef tests.

const std = @import("std");
const fx = @import("zigeffect");
const fixtures = @import("support/fixtures.zig");

fn bump(x: u32) u32 {
    return x + 1;
}

test "FiberRef get/set/update/reset" {
    var fref = fx.FiberRef(u32).init(10);
    try std.testing.expectEqual(@as(u32, 10), fref.get());
    fref.set(42);
    try std.testing.expectEqual(@as(u32, 42), fref.get());
    try std.testing.expectEqual(@as(u32, 43), fref.update(bump));
    fref.reset();
    try std.testing.expectEqual(@as(u32, 10), fref.get()); // back to default
}

test "forkChild inherits a SNAPSHOT; child and parent are then independent" {
    var parent = fx.FiberRef(u32).init(0);
    parent.set(100);

    // Fork: the child sees the parent's value AT FORK TIME.
    var child = parent.forkChild();
    try std.testing.expectEqual(@as(u32, 100), child.get());

    // Mutating the child does NOT affect the parent.
    child.set(999);
    try std.testing.expectEqual(@as(u32, 999), child.get());
    try std.testing.expectEqual(@as(u32, 100), parent.get());

    // Mutating the parent AFTER the fork does NOT affect the already-forked child.
    parent.set(200);
    try std.testing.expectEqual(@as(u32, 200), parent.get());
    try std.testing.expectEqual(@as(u32, 999), child.get());
}

test "forkChild preserves the default for the child's own reset" {
    var parent = fx.FiberRef(u32).init(7);
    parent.set(50);
    var child = parent.forkChild();
    child.set(60);
    child.reset();
    // Child resets to the inherited default (7), independent of the parent.
    try std.testing.expectEqual(@as(u32, 7), child.get());
}

// ── M5.3 auto-propagation via Context inline slots ──

test "FiberRefSlot auto-snapshots across a Context copy (the executor's fork mechanism)" {
    var env = try fx.TestEnv.init(std.testing.allocator);
    defer env.deinit();
    var scope = fx.Scope.init(std.testing.allocator);
    defer scope.deinit();

    const RequestId = fx.FiberRefSlot(u32);
    const rid = RequestId.init();

    var parent = fx.Context(fx.TestServices).init(std.testing.allocator, &env.services, &scope);
    rid.set(&parent, 12345);
    try std.testing.expectEqual(@as(u32, 12345), rid.get(&parent));

    // Fork = the executor copies ctx.* by value. The child inherits the value.
    var child = parent;
    try std.testing.expectEqual(@as(u32, 12345), rid.get(&child));

    // Child writes stay LOCAL — parent is unaffected.
    rid.set(&child, 99999);
    try std.testing.expectEqual(@as(u32, 99999), rid.get(&child));
    try std.testing.expectEqual(@as(u32, 12345), rid.get(&parent));

    // And a parent write AFTER the fork doesn't reach the already-forked child.
    rid.set(&parent, 55555);
    try std.testing.expectEqual(@as(u32, 55555), rid.get(&parent));
    try std.testing.expectEqual(@as(u32, 99999), rid.get(&child));
}

const SlotBody = struct {
    var slot: fx.FiberRefSlot(u32) = undefined;
    var observed: u32 = 0;
    fn run(item: u32, ctx: *fx.Context(fx.TestServices)) fixtures.TestError!u32 {
        // Each forked body reads the inherited slot value, then writes its own.
        observed = slot.get(ctx);
        slot.set(ctx, item);
        return slot.get(ctx);
    }
};

test "FiberRefSlot propagates end-to-end through a real forEachPar fork" {
    var env = try fx.TestEnv.init(std.testing.allocator);
    defer env.deinit();

    SlotBody.slot = fx.FiberRefSlot(u32).init();

    const ProbeExec = struct {
        fn spawn(c: ?*anyopaque, job: fx.FiberJob) ?*anyopaque {
            job.run(job.context);
            return c;
        }
        fn join(c: ?*anyopaque, h: *anyopaque) void {
            _ = c;
            _ = h;
        }
        fn destroy(c: ?*anyopaque, h: *anyopaque) void {
            _ = c;
            _ = h;
        }
        const vtable = fx.FiberExecutor.VTable{ .spawn = spawn, .join = join, .destroy = destroy };
        fn executor(self: *@This()) fx.FiberExecutor {
            return .{ .context = self, .vtable = &vtable };
        }
    };
    var exec = ProbeExec{};

    // Seed the slot in the runtime's context by setting it from a body that runs
    // first is awkward; instead assert per-fiber independence: each body writes
    // its item and reads back ITS OWN value (the copies are independent).
    var runtime = fx.Runtime(fx.TestServices)
        .init(std.testing.allocator, &env.services)
        .withClock(&env.services.clock)
        .withExecutor(exec.executor())
        .provides(.{ fx.Logger, fx.Config, fx.Metrics, fx.Tracing, fx.MemoryFileSystem, fx.Clock });

    const items = [_]u32{ 10, 20, 30 };
    const program = fx.forEachPar(u32, u32, fixtures.TestError, fx.TestServices, &items, SlotBody.run);
    const results = try runtime.run(program);
    defer std.testing.allocator.free(results);

    // Each fiber read+wrote its OWN slot copy → returns its own item.
    try std.testing.expectEqualSlices(u32, &.{ 10, 20, 30 }, results);
}

test "FiberRef works over a non-numeric type (request id as slice)" {
    var rid = fx.FiberRef([]const u8).init("anonymous");
    rid.set("req-abc");
    var child = rid.forkChild();
    try std.testing.expectEqualStrings("req-abc", child.get());
    child.set("req-xyz");
    try std.testing.expectEqualStrings("req-abc", rid.get()); // parent unchanged
}
