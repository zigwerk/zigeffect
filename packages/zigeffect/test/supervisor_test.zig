const std = @import("std");
const fx = @import("zigeffect");

test "supervisor public exports are available" {
    try std.testing.expect(@hasDecl(fx.runtime, "supervisor"));
    try std.testing.expect(@hasDecl(fx.runtime, "Supervisor"));
    try std.testing.expect(@hasDecl(fx.runtime, "SupervisorStrategy"));
    try std.testing.expect(@hasDecl(fx.runtime, "SupervisorRestartMode"));
    try std.testing.expect(@hasDecl(fx.runtime, "SupervisorChildKind"));
    try std.testing.expect(@hasDecl(fx.runtime, "SupervisorChildStatus"));
    try std.testing.expect(@hasDecl(fx.runtime, "SupervisorChildSpec"));
    try std.testing.expect(@hasDecl(fx.runtime, "SupervisorChildExit"));
    try std.testing.expect(@hasDecl(fx.runtime, "RestartIntensity"));
    try std.testing.expect(@hasDecl(fx.runtime, "SupervisorOptions"));
    try std.testing.expect(@hasDecl(fx.runtime, "SupervisorDecision"));
    try std.testing.expect(@hasDecl(fx.runtime, "SupervisorShutdownPlan"));
    try std.testing.expect(@hasDecl(fx, "Supervisor"));
    try std.testing.expect(@hasDecl(fx, "SupervisorError"));
}

test "supervisor child specs cover local runtime domains" {
    const specs = [_]fx.SupervisorChildSpec{
        .{ .id = 1, .name = "fiber-child", .kind = .fiber },
        .{ .id = 2, .name = "workflow-worker", .kind = .workflow_worker },
        .{ .id = 3, .name = "queue-worker", .kind = .queue_worker },
        .{ .id = 4, .name = "entity", .kind = .entity },
    };
    try std.testing.expectEqual(fx.SupervisorChildKind.fiber, specs[0].kind);
    try std.testing.expectEqual(fx.SupervisorRestartMode.permanent, specs[0].restart_mode);
    try std.testing.expectEqual(@as(u32, 0), specs[0].shutdown_order);
}

test "supervisor registers children and rejects duplicate ids" {
    var supervisor = fx.Supervisor.init(std.testing.allocator, .{ .id = 10, .name = "root" });
    defer supervisor.deinit();

    try supervisor.addChild(.{ .id = 1, .name = "first", .kind = .fiber });
    try supervisor.addChild(.{ .id = 2, .name = "second", .kind = .queue_worker });
    try std.testing.expectError(error.DuplicateChild, supervisor.addChild(.{ .id = 1, .name = "dupe", .kind = .fiber }));

    try supervisor.startAll(1_000);
    try std.testing.expectEqual(fx.SupervisorChildStatus.running, try supervisor.childStatus(1));
    try std.testing.expectEqual(fx.SupervisorChildStatus.running, try supervisor.childStatus(2));
}

test "supervisor shutdown plan uses order and reverse registration tie break" {
    var supervisor = fx.Supervisor.init(std.testing.allocator, .{ .id = 10, .name = "root" });
    defer supervisor.deinit();

    try supervisor.addChild(.{ .id = 1, .name = "first", .kind = .fiber, .shutdown_order = 10 });
    try supervisor.addChild(.{ .id = 2, .name = "second", .kind = .workflow_worker, .shutdown_order = 20 });
    try supervisor.addChild(.{ .id = 3, .name = "third", .kind = .queue_worker, .shutdown_order = 20 });
    try supervisor.addChild(.{ .id = 4, .name = "fourth", .kind = .entity, .shutdown_order = 5 });

    var plan = try supervisor.shutdownPlan(std.testing.allocator);
    defer plan.deinit();
    try std.testing.expectEqual(@as(usize, 4), plan.children.len);
    try std.testing.expectEqual(@as(u64, 3), plan.children[0].spec.id);
    try std.testing.expectEqual(@as(u64, 2), plan.children[1].spec.id);
    try std.testing.expectEqual(@as(u64, 1), plan.children[2].spec.id);
    try std.testing.expectEqual(@as(u64, 4), plan.children[3].spec.id);
}
