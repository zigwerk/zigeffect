const std = @import("std");
const fx = @import("zigeffect");

test "causal invariant builder reports resource and fiber violations" {
    const events = [_]fx.CausalEvent{
        .{ .id = 1, .kind = .scope_opened, .run_id = 1, .scope_id = 2, .status = "opened" },
        .{ .id = 2, .kind = .resource_acquired, .run_id = 1, .scope_id = 2, .resource_id = 3, .status = "acquired", .type_name = "db" },
        .{ .id = 3, .kind = .fiber_suspended, .run_id = 1, .scope_id = 2, .fiber_id = 4, .status = "suspended" },
        .{ .id = 4, .kind = .scope_closed, .run_id = 1, .scope_id = 2, .status = "closed" },
    };

    const builder = fx.CausalInvariantBuilder.init()
        .requireEveryResourceFinalized()
        .requireSuspendedFibersResolve()
        .requireNoPendingFibersAfterScopeClose();

    var result = try builder.check(std.testing.allocator, &events);
    defer result.deinit();

    try std.testing.expectEqual(@as(usize, 3), result.violations.len);
    try std.testing.expectEqual(fx.CausalInvariantViolationKind.resource_not_finalized, result.violations[0].kind);
    try std.testing.expectEqual(fx.CausalInvariantViolationKind.suspended_fiber_unresolved, result.violations[1].kind);
    try std.testing.expectEqual(fx.CausalInvariantViolationKind.pending_fiber_after_scope_close, result.violations[2].kind);
}

test "causal invariants pass when resource and fiber lifecycles close" {
    const events = [_]fx.CausalEvent{
        .{ .id = 1, .kind = .scope_opened, .run_id = 1, .scope_id = 2, .status = "opened" },
        .{ .id = 2, .kind = .resource_acquired, .run_id = 1, .scope_id = 2, .resource_id = 3, .status = "acquired", .type_name = "db" },
        .{ .id = 3, .kind = .fiber_suspended, .run_id = 1, .scope_id = 2, .fiber_id = 4, .status = "suspended" },
        .{ .id = 4, .kind = .fiber_interrupted, .run_id = 1, .scope_id = 2, .fiber_id = 4, .status = "interrupted" },
        .{ .id = 5, .kind = .resource_finalized, .run_id = 1, .scope_id = 2, .resource_id = 3, .status = "success", .type_name = "db" },
        .{ .id = 6, .kind = .scope_closed, .run_id = 1, .scope_id = 2, .status = "closed" },
    };

    const builder = fx.CausalInvariantBuilder.init()
        .requireEveryResourceFinalized()
        .requireSuspendedFibersResolve()
        .requireNoPendingFibersAfterScopeClose();

    var result = try builder.check(std.testing.allocator, &events);
    defer result.deinit();
    try std.testing.expectEqual(@as(usize, 0), result.violations.len);
}
