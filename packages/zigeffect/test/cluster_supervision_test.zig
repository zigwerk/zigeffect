const std = @import("std");
const fx = @import("zigeffect");

test "cluster supervision public exports are available" {
    try std.testing.expect(@hasDecl(fx.cluster, "supervision"));
    try std.testing.expect(@hasDecl(fx.cluster, "ClusterSupervisionPolicy"));
    try std.testing.expect(@hasDecl(fx.cluster, "ClusterRunnerRestartPolicy"));
    try std.testing.expect(@hasDecl(fx.cluster, "ClusterRunnerRestartState"));
    try std.testing.expect(@hasDecl(fx.cluster, "ClusterRunnerRestartDecision"));
    try std.testing.expect(@hasDecl(fx.cluster, "ClusterSupervisionReport"));
    try std.testing.expect(@hasDecl(fx, "ClusterSupervisionReport"));
}

test "supervisor child kinds cover runner shard entity and workflow worker" {
    try std.testing.expectEqual(fx.SupervisorChildKind.runner, fx.SupervisorChildKind.runner);
    try std.testing.expectEqual(fx.SupervisorChildKind.shard, fx.SupervisorChildKind.shard);
    try std.testing.expectEqual(fx.SupervisorChildKind.entity, fx.SupervisorChildKind.entity);
    try std.testing.expectEqual(fx.SupervisorChildKind.workflow_worker, fx.SupervisorChildKind.workflow_worker);
}

test "cluster runner restart state escalates after intensity budget" {
    var state = fx.ClusterRunnerRestartState.init(std.testing.allocator, .{
        .max_restarts = 2,
        .within_ms = 1_000,
    });
    defer state.deinit();

    const first = try state.recordFailure(1_000);
    try std.testing.expect(first.restart_allowed);
    try std.testing.expect(!first.escalated);

    const second = try state.recordFailure(1_100);
    try std.testing.expect(second.restart_allowed);
    try std.testing.expect(!second.escalated);

    const third = try state.recordFailure(1_200);
    try std.testing.expect(!third.restart_allowed);
    try std.testing.expect(third.escalated);

    const fourth = try state.recordFailure(2_300);
    try std.testing.expect(fourth.restart_allowed);
    try std.testing.expect(!fourth.escalated);
}

test "entity runtime exposes last supervisor decision after handler failure" {
    var runtime = fx.LocalEntityRuntime.init(std.testing.allocator, .{
        .restart_intensity = .{ .max_restarts = 2, .within_ms = 1_000 },
    });
    defer runtime.deinit();

    const address = fx.entityAddress("counter", "decision");
    _ = try runtime.registerEntity(.{ .address = address, .name = "counter-decision" }, 1_000);

    const envelope = try fx.cloneEntityEnvelope(std.testing.allocator, .{
        .id = 1,
        .sequence = 1,
        .kind = .tell,
        .address = address,
        .payload_type_name = "text",
        .payload = "boom",
    });

    const Handler = struct {
        pub fn handle(_: *fx.EntityScope, _: fx.EntityEnvelope) !fx.EntityHandlerResult {
            return error.Boom;
        }
    };

    try std.testing.expectError(error.Boom, runtime.processEnvelope(envelope, Handler, 1_100));
    const decision = (try runtime.lastSupervisorDecision(address)).?;
    try std.testing.expectEqual(@as(usize, 1), decision.restarted_children);
    try std.testing.expect(!decision.escalated);
}
