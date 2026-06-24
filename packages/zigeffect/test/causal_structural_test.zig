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

test "causalStructurallyEquivalent detects different parent lineage shape" {
    const allocator = std.testing.allocator;
    const a = [_]fx.CausalEvent{
        .{ .id = 1, .kind = .run_started },
        .{ .id = 2, .kind = .effect_started, .parent_id = 1 },
        .{ .id = 3, .kind = .effect_completed, .parent_id = 2 },
    };
    const b = [_]fx.CausalEvent{
        .{ .id = 10, .kind = .run_started },
        .{ .id = 20, .kind = .effect_started },
        .{ .id = 30, .kind = .effect_completed, .parent_id = 10 },
    };
    try std.testing.expect(!try fx.causalStructurallyEquivalent(allocator, &a, &b));
}

test "causalStructurallyEquivalent detects mismatched resource finalization pairing" {
    const allocator = std.testing.allocator;
    const a = [_]fx.CausalEvent{
        .{ .id = 1, .kind = .scope_opened, .scope_id = 1 },
        .{ .id = 2, .kind = .resource_acquired, .scope_id = 1, .resource_id = 9 },
        .{ .id = 3, .kind = .resource_finalized, .scope_id = 1, .resource_id = 9 },
        .{ .id = 4, .kind = .scope_closed, .scope_id = 1 },
    };
    const b = [_]fx.CausalEvent{
        .{ .id = 10, .kind = .scope_opened, .scope_id = 1 },
        .{ .id = 20, .kind = .resource_acquired, .scope_id = 1, .resource_id = 9 },
        .{ .id = 30, .kind = .resource_finalized, .scope_id = 1, .resource_id = 10 },
        .{ .id = 40, .kind = .scope_closed, .scope_id = 1 },
    };
    try std.testing.expect(!try fx.causalStructurallyEquivalent(allocator, &a, &b));
}

test "causalStructurallyEquivalent detects fiber lifecycle scope ownership changes" {
    const allocator = std.testing.allocator;
    const a = [_]fx.CausalEvent{
        .{ .id = 1, .kind = .scope_opened, .scope_id = 1 },
        .{ .id = 2, .kind = .fiber_forked, .scope_id = 1, .fiber_id = 7 },
        .{ .id = 3, .kind = .fiber_joined, .scope_id = 1, .fiber_id = 7 },
        .{ .id = 4, .kind = .scope_closed, .scope_id = 1 },
    };
    const b = [_]fx.CausalEvent{
        .{ .id = 10, .kind = .scope_opened, .scope_id = 1 },
        .{ .id = 20, .kind = .fiber_forked, .scope_id = 1, .fiber_id = 7 },
        .{ .id = 30, .kind = .fiber_joined, .scope_id = 2, .fiber_id = 7 },
        .{ .id = 40, .kind = .scope_closed, .scope_id = 1 },
    };
    try std.testing.expect(!try fx.causalStructurallyEquivalent(allocator, &a, &b));
}

test "causalStructurallyEquivalent detects finding evidence attached to an unknown owner" {
    const allocator = std.testing.allocator;
    const a = [_]fx.CausalEvent{
        .{ .id = 1, .kind = .scope_opened, .scope_id = 1 },
        .{ .id = 2, .kind = .cluster_entity_failed, .scope_id = 1, .fiber_id = 8 },
        .{ .id = 3, .kind = .fiber_interrupted, .scope_id = 1, .fiber_id = 8 },
    };
    const b = [_]fx.CausalEvent{
        .{ .id = 10, .kind = .scope_opened, .scope_id = 1 },
        .{ .id = 20, .kind = .cluster_entity_failed, .scope_id = 2, .fiber_id = 8 },
        .{ .id = 30, .kind = .fiber_interrupted, .scope_id = 1, .fiber_id = 8 },
    };
    try std.testing.expect(!try fx.causalStructurallyEquivalent(allocator, &a, &b));
}
