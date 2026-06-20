const std = @import("std");
const fx = @import("zigeffect");

test "causalStructurallyEquivalent ignores ids and ordering" {
    const allocator = std.testing.allocator;
    const a = [_]fx.CausalEvent{
        .{ .id = 1, .kind = .fiber_suspended, .fiber_id = 1 },
        .{ .id = 2, .kind = .timer_fired, .fiber_id = 1, .cause_event_id = 1 },
        .{ .id = 3, .kind = .fiber_resumed, .fiber_id = 1, .cause_event_id = 2 },
        .{ .id = 4, .kind = .fiber_joined, .fiber_id = 1 },
    };
    // same structure, offset ids, reversed order
    const b = [_]fx.CausalEvent{
        .{ .id = 99, .kind = .fiber_joined, .fiber_id = 1 },
        .{ .id = 60, .kind = .fiber_resumed, .fiber_id = 1, .cause_event_id = 50 },
        .{ .id = 50, .kind = .timer_fired, .fiber_id = 1, .cause_event_id = 40 },
        .{ .id = 40, .kind = .fiber_suspended, .fiber_id = 1 },
    };
    try std.testing.expect(try fx.causalStructurallyEquivalent(allocator, &a, &b));
}

test "causalStructurallyEquivalent detects a different cause edge" {
    const allocator = std.testing.allocator;
    const a = [_]fx.CausalEvent{
        .{ .id = 1, .kind = .timer_fired, .fiber_id = 1 },
        .{ .id = 2, .kind = .io_completed, .fiber_id = 1 },
        .{ .id = 3, .kind = .fiber_resumed, .fiber_id = 1, .cause_event_id = 1 },
    };
    const b = [_]fx.CausalEvent{
        .{ .id = 1, .kind = .timer_fired, .fiber_id = 1 },
        .{ .id = 2, .kind = .io_completed, .fiber_id = 1 },
        .{ .id = 3, .kind = .fiber_resumed, .fiber_id = 1, .cause_event_id = 2 },
    };
    try std.testing.expect(!try fx.causalStructurallyEquivalent(allocator, &a, &b));
}

test "causalStructurallyEquivalent detects a different fiber net state" {
    const allocator = std.testing.allocator;
    const a = [_]fx.CausalEvent{
        .{ .id = 1, .kind = .fiber_forked, .fiber_id = 1 },
        .{ .id = 2, .kind = .fiber_joined, .fiber_id = 1 },
    };
    const b = [_]fx.CausalEvent{
        .{ .id = 1, .kind = .fiber_forked, .fiber_id = 1 },
        .{ .id = 2, .kind = .fiber_interrupted, .fiber_id = 1 },
    };
    try std.testing.expect(!try fx.causalStructurallyEquivalent(allocator, &a, &b));
}

test "causalStructurallyEquivalent: two reordered fibers are equivalent" {
    const allocator = std.testing.allocator;
    const a = [_]fx.CausalEvent{
        .{ .id = 1, .kind = .fiber_forked, .fiber_id = 1 },
        .{ .id = 2, .kind = .fiber_forked, .fiber_id = 2 },
        .{ .id = 3, .kind = .fiber_joined, .fiber_id = 1 },
        .{ .id = 4, .kind = .fiber_joined, .fiber_id = 2 },
    };
    const b = [_]fx.CausalEvent{
        .{ .id = 40, .kind = .fiber_joined, .fiber_id = 2 },
        .{ .id = 10, .kind = .fiber_forked, .fiber_id = 1 },
        .{ .id = 30, .kind = .fiber_joined, .fiber_id = 1 },
        .{ .id = 20, .kind = .fiber_forked, .fiber_id = 2 },
    };
    try std.testing.expect(try fx.causalStructurallyEquivalent(allocator, &a, &b));
}
