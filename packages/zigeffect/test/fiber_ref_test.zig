//! M5.3 (first cut) — FiberRef tests.

const std = @import("std");
const fx = @import("zigeffect");

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

test "FiberRef works over a non-numeric type (request id as slice)" {
    var rid = fx.FiberRef([]const u8).init("anonymous");
    rid.set("req-abc");
    var child = rid.forkChild();
    try std.testing.expectEqualStrings("req-abc", child.get());
    child.set("req-xyz");
    try std.testing.expectEqualStrings("req-abc", rid.get()); // parent unchanged
}
