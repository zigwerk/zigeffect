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
