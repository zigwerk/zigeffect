//! M5.1 — Ref(T) tests.

const std = @import("std");
const fx = @import("zigeffect");

test "Ref.get / set returns previous + stores new" {
    var counter = fx.Ref(u32).init(7);
    try std.testing.expectEqual(@as(u32, 7), counter.get());
    const prev = counter.set(11);
    try std.testing.expectEqual(@as(u32, 7), prev);
    try std.testing.expectEqual(@as(u32, 11), counter.get());
}

const Incr = struct {
    fn add_one(value: u32) u32 {
        return value + 1;
    }
};

test "Ref.update applies the transform and returns the new value" {
    var counter = fx.Ref(u32).init(0);
    const next = counter.update(Incr.add_one);
    try std.testing.expectEqual(@as(u32, 1), next);
    try std.testing.expectEqual(@as(u32, 1), counter.get());
}

test "Ref.updateAndReturnBoth returns previous and current" {
    var counter = fx.Ref(u32).init(5);
    const pair = counter.updateAndReturnBoth(Incr.add_one);
    try std.testing.expectEqual(@as(u32, 5), pair.previous);
    try std.testing.expectEqual(@as(u32, 6), pair.current);
    try std.testing.expectEqual(@as(u32, 6), counter.get());
}

const BumpFail = struct {
    const E = error{Boom};
    fn ok(v: u32) E!u32 {
        return v + 1;
    }
    fn fails(v: u32) E!u32 {
        _ = v;
        return error.Boom;
    }
};

test "Ref.updateE updates on success" {
    var counter = fx.Ref(u32).init(3);
    const next = try counter.updateE(BumpFail.E, BumpFail.ok);
    try std.testing.expectEqual(@as(u32, 4), next);
    try std.testing.expectEqual(@as(u32, 4), counter.get());
}

test "Ref.updateE leaves the cell untouched on transform failure" {
    var counter = fx.Ref(u32).init(3);
    const result = counter.updateE(BumpFail.E, BumpFail.fails);
    try std.testing.expectError(error.Boom, result);
    try std.testing.expectEqual(@as(u32, 3), counter.get());
}

test "M5.2 — SynchronizedRef.get reads through to the underlying cell" {
    var sref = fx.SynchronizedRef(u32).init(11);
    try std.testing.expectEqual(@as(u32, 11), sref.get());
}

test "M5.2 — SynchronizedRef.update applies the transform under the permit" {
    var sref = fx.SynchronizedRef(u32).init(11);
    const next = try sref.update(Incr.add_one);
    try std.testing.expectEqual(@as(u32, 12), next);
    try std.testing.expectEqual(@as(u32, 12), sref.get());
}

test "M5.2 — SynchronizedRef.updateE rolls back on failure, keeps permit free" {
    var sref = fx.SynchronizedRef(u32).init(3);
    const result = sref.updateE(BumpFail.E, BumpFail.fails);
    try std.testing.expectError(error.Boom, result);
    try std.testing.expectEqual(@as(u32, 3), sref.get());
    // Subsequent update must succeed (permit was released even on error).
    const next = try sref.update(Incr.add_one);
    try std.testing.expectEqual(@as(u32, 4), next);
}

test "Ref works over a non-numeric type (slice)" {
    var slot = fx.Ref([]const u8).init("alpha");
    try std.testing.expectEqualStrings("alpha", slot.get());
    _ = slot.set("beta");
    try std.testing.expectEqualStrings("beta", slot.get());
}
