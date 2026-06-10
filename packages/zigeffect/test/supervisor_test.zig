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

test "full supervision public exports are available" {
    try std.testing.expect(@hasDecl(fx.runtime, "SupervisorDecisionRecord"));
    try std.testing.expect(@hasDecl(fx.runtime, "SupervisorInspectionReport"));
    try std.testing.expect(@hasDecl(fx.runtime, "formatSupervisorInspectionText"));
    try std.testing.expect(@hasDecl(fx.runtime, "formatSupervisorInspectionJson"));
    try std.testing.expect(@hasDecl(fx.runtime, "SupervisorTree"));
    try std.testing.expect(@hasDecl(fx.runtime, "SupervisorTreeOptions"));
    try std.testing.expect(@hasDecl(fx.runtime, "SupervisorTreeNodeOptions"));
    try std.testing.expect(@hasDecl(fx.runtime, "SupervisorTreeInspectionReport"));
    try std.testing.expect(@hasDecl(fx, "SupervisorDecisionRecord"));
    try std.testing.expect(@hasDecl(fx, "SupervisorTree"));
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

test "supervisor child specs cover full runtime cluster domains" {
    const specs = [_]fx.SupervisorChildSpec{
        .{ .id = 10, .name = "activity", .kind = .activity },
        .{ .id = 11, .name = "shard-worker", .kind = .shard_worker },
        .{ .id = 12, .name = "runner-service", .kind = .runner_service },
        .{ .id = 13, .name = "transport-server", .kind = .transport_server },
    };
    try std.testing.expectEqual(fx.SupervisorChildKind.activity, specs[0].kind);
    try std.testing.expectEqual(fx.SupervisorChildKind.shard_worker, specs[1].kind);
    try std.testing.expectEqual(fx.SupervisorChildKind.runner_service, specs[2].kind);
    try std.testing.expectEqual(fx.SupervisorChildKind.transport_server, specs[3].kind);
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

test "supervisor one-for-one restarts only failed child" {
    var supervisor = fx.Supervisor.init(std.testing.allocator, .{
        .id = 10,
        .name = "root",
        .strategy = .one_for_one,
    });
    defer supervisor.deinit();

    try supervisor.addChild(.{ .id = 1, .name = "first", .kind = .fiber });
    try supervisor.addChild(.{ .id = 2, .name = "second", .kind = .workflow_worker });
    try supervisor.addChild(.{ .id = 3, .name = "third", .kind = .queue_worker });
    try supervisor.startAll(1_000);

    const decision = try supervisor.reportChildExit(2, .{ .failure = "boom" }, 1_100);
    try std.testing.expectEqual(@as(u64, 10), decision.supervisor_id);
    try std.testing.expectEqual(@as(u64, 2), decision.child_id);
    try std.testing.expectEqual(fx.SupervisorStrategy.one_for_one, decision.strategy);
    try std.testing.expectEqual(@as(usize, 1), decision.restarted_children);
    try std.testing.expectEqual(@as(usize, 0), decision.stopped_children);
    try std.testing.expect(!decision.escalated);

    try std.testing.expectEqual(@as(usize, 0), try supervisor.childRestartCount(1));
    try std.testing.expectEqual(@as(usize, 1), try supervisor.childRestartCount(2));
    try std.testing.expectEqual(@as(usize, 0), try supervisor.childRestartCount(3));
    try std.testing.expectEqual(fx.SupervisorChildStatus.running, try supervisor.childStatus(1));
    try std.testing.expectEqual(fx.SupervisorChildStatus.running, try supervisor.childStatus(2));
    try std.testing.expectEqual(fx.SupervisorChildStatus.running, try supervisor.childStatus(3));
}

test "dynamic supervisor restarts removes and rejects missing dynamic children" {
    var supervisor = fx.Supervisor.init(std.testing.allocator, .{
        .id = 70,
        .name = "dynamic-root",
        .strategy = .dynamic,
    });
    defer supervisor.deinit();

    try supervisor.addChild(.{ .id = 1, .name = "queue", .kind = .queue_worker });
    try supervisor.addChild(.{ .id = 2, .name = "activity", .kind = .activity });
    try supervisor.startAll(1_000);

    const decision = try supervisor.reportChildExit(2, .{ .failure = "activity failed" }, 1_100);
    try std.testing.expectEqual(fx.SupervisorStrategy.dynamic, decision.strategy);
    try std.testing.expectEqual(@as(usize, 1), decision.restarted_children);
    try std.testing.expectEqual(@as(usize, 0), try supervisor.childRestartCount(1));
    try std.testing.expectEqual(@as(usize, 1), try supervisor.childRestartCount(2));

    try supervisor.stopChild(2, .{ .interrupted = 0 });
    try std.testing.expectEqual(fx.SupervisorChildStatus.stopped, try supervisor.childStatus(2));
    try supervisor.removeChild(2);
    try std.testing.expectError(error.ChildNotFound, supervisor.childStatus(2));
}

test "supervisor one-for-all restarts every restartable child" {
    var supervisor = fx.Supervisor.init(std.testing.allocator, .{
        .id = 10,
        .name = "root",
        .strategy = .one_for_all,
    });
    defer supervisor.deinit();

    try supervisor.addChild(.{ .id = 1, .name = "first", .kind = .fiber });
    try supervisor.addChild(.{ .id = 2, .name = "second", .kind = .workflow_worker });
    try supervisor.addChild(.{ .id = 3, .name = "third", .kind = .queue_worker });
    try supervisor.startAll(1_000);

    const decision = try supervisor.reportChildExit(2, .{ .failure = "boom" }, 1_100);
    try std.testing.expectEqual(@as(usize, 3), decision.restarted_children);
    try std.testing.expectEqual(@as(usize, 0), decision.stopped_children);
    try std.testing.expect(!decision.escalated);

    try std.testing.expectEqual(@as(usize, 1), try supervisor.childRestartCount(1));
    try std.testing.expectEqual(@as(usize, 1), try supervisor.childRestartCount(2));
    try std.testing.expectEqual(@as(usize, 1), try supervisor.childRestartCount(3));
    try std.testing.expectEqual(fx.SupervisorChildStatus.running, try supervisor.childStatus(1));
    try std.testing.expectEqual(fx.SupervisorChildStatus.running, try supervisor.childStatus(2));
    try std.testing.expectEqual(fx.SupervisorChildStatus.running, try supervisor.childStatus(3));
}

test "supervisor rest-for-one restarts failed child and later children" {
    var supervisor = fx.Supervisor.init(std.testing.allocator, .{
        .id = 10,
        .name = "root",
        .strategy = .rest_for_one,
    });
    defer supervisor.deinit();

    try supervisor.addChild(.{ .id = 1, .name = "first", .kind = .fiber });
    try supervisor.addChild(.{ .id = 2, .name = "second", .kind = .workflow_worker });
    try supervisor.addChild(.{ .id = 3, .name = "third", .kind = .queue_worker });
    try supervisor.startAll(1_000);

    const decision = try supervisor.reportChildExit(2, .{ .failure = "boom" }, 1_100);
    try std.testing.expectEqual(@as(usize, 2), decision.restarted_children);
    try std.testing.expectEqual(@as(usize, 0), decision.stopped_children);
    try std.testing.expect(!decision.escalated);

    try std.testing.expectEqual(@as(usize, 0), try supervisor.childRestartCount(1));
    try std.testing.expectEqual(@as(usize, 1), try supervisor.childRestartCount(2));
    try std.testing.expectEqual(@as(usize, 1), try supervisor.childRestartCount(3));
    try std.testing.expectEqual(fx.SupervisorChildStatus.running, try supervisor.childStatus(1));
    try std.testing.expectEqual(fx.SupervisorChildStatus.running, try supervisor.childStatus(2));
    try std.testing.expectEqual(fx.SupervisorChildStatus.running, try supervisor.childStatus(3));
}

test "supervisor restart modes handle success and failure differently" {
    var supervisor = fx.Supervisor.init(std.testing.allocator, .{
        .id = 10,
        .name = "root",
        .strategy = .one_for_one,
    });
    defer supervisor.deinit();

    try supervisor.addChild(.{ .id = 1, .name = "permanent", .kind = .fiber, .restart_mode = .permanent });
    try supervisor.addChild(.{ .id = 2, .name = "transient", .kind = .workflow_worker, .restart_mode = .transient });
    try supervisor.addChild(.{ .id = 3, .name = "temporary", .kind = .queue_worker, .restart_mode = .temporary });
    try supervisor.startAll(1_000);

    const permanent_success = try supervisor.reportChildExit(1, .success, 1_100);
    try std.testing.expectEqual(@as(usize, 1), permanent_success.restarted_children);
    try std.testing.expectEqual(@as(usize, 0), permanent_success.stopped_children);
    try std.testing.expectEqual(@as(usize, 1), try supervisor.childRestartCount(1));
    try std.testing.expectEqual(fx.SupervisorChildStatus.running, try supervisor.childStatus(1));

    const transient_success = try supervisor.reportChildExit(2, .success, 1_200);
    try std.testing.expectEqual(@as(usize, 0), transient_success.restarted_children);
    try std.testing.expectEqual(@as(usize, 1), transient_success.stopped_children);
    try std.testing.expectEqual(@as(usize, 0), try supervisor.childRestartCount(2));
    try std.testing.expectEqual(fx.SupervisorChildStatus.stopped, try supervisor.childStatus(2));

    const transient_failure = try supervisor.reportChildExit(2, .{ .failure = "boom" }, 1_300);
    try std.testing.expectEqual(@as(usize, 1), transient_failure.restarted_children);
    try std.testing.expectEqual(@as(usize, 0), transient_failure.stopped_children);
    try std.testing.expectEqual(@as(usize, 1), try supervisor.childRestartCount(2));
    try std.testing.expectEqual(fx.SupervisorChildStatus.running, try supervisor.childStatus(2));

    const temporary_failure = try supervisor.reportChildExit(3, .{ .failure = "boom" }, 1_400);
    try std.testing.expectEqual(@as(usize, 0), temporary_failure.restarted_children);
    try std.testing.expectEqual(@as(usize, 1), temporary_failure.stopped_children);
    try std.testing.expectEqual(@as(usize, 0), try supervisor.childRestartCount(3));
    try std.testing.expectEqual(fx.SupervisorChildStatus.failed, try supervisor.childStatus(3));
}

test "supervisor escalates when restart intensity is exceeded" {
    var supervisor = fx.Supervisor.init(std.testing.allocator, .{
        .id = 10,
        .name = "root",
        .strategy = .one_for_one,
        .intensity = .{ .max_restarts = 2, .within_ms = 1_000 },
    });
    defer supervisor.deinit();

    try supervisor.addChild(.{ .id = 1, .name = "worker", .kind = .fiber });
    try supervisor.startAll(1_000);

    const first = try supervisor.reportChildExit(1, .{ .failure = "boom" }, 1_100);
    try std.testing.expect(!first.escalated);
    try std.testing.expectEqual(@as(usize, 1), first.restarted_children);

    const second = try supervisor.reportChildExit(1, .{ .failure = "boom" }, 1_200);
    try std.testing.expect(!second.escalated);
    try std.testing.expectEqual(@as(usize, 1), second.restarted_children);

    const third = try supervisor.reportChildExit(1, .{ .failure = "boom" }, 1_300);
    try std.testing.expect(third.escalated);
    try std.testing.expectEqual(@as(usize, 0), third.restarted_children);
    try std.testing.expectEqual(@as(usize, 2), try supervisor.childRestartCount(1));
    try std.testing.expectEqual(fx.SupervisorChildStatus.escalated, try supervisor.childStatus(1));

    const cause = third.cause().?;
    try std.testing.expectEqual(error.RestartIntensityExceeded, cause.failure);

    const report = try fx.formatCause(std.testing.allocator, "restart worker", cause);
    defer std.testing.allocator.free(report);
    try std.testing.expect(std.mem.indexOf(u8, report, "RestartIntensityExceeded") != null);
}

test "supervisor inspection reports children decisions escalation and shutdown order" {
    var supervisor = fx.Supervisor.init(std.testing.allocator, .{
        .id = 80,
        .name = "inspect-root",
        .strategy = .one_for_one,
        .intensity = .{ .max_restarts = 1, .within_ms = 1_000 },
    });
    defer supervisor.deinit();

    try supervisor.addChild(.{ .id = 1, .name = "fiber", .kind = .fiber, .shutdown_order = 1 });
    try supervisor.addChild(.{ .id = 2, .name = "transport", .kind = .transport_server, .shutdown_order = 10 });
    try supervisor.startAll(1_000);

    _ = try supervisor.reportChildExit(2, .{ .failure = "port closed" }, 1_100);
    _ = try supervisor.reportChildExit(2, .{ .failure = "port closed again" }, 1_200);

    var inspection = try supervisor.inspect(std.testing.allocator);
    defer inspection.deinit();
    try std.testing.expectEqual(@as(u64, 80), inspection.supervisor_id);
    try std.testing.expectEqual(fx.SupervisorStrategy.one_for_one, inspection.strategy);
    try std.testing.expectEqual(@as(usize, 2), inspection.children.len);
    try std.testing.expectEqual(@as(usize, 1), inspection.escalated_children);
    try std.testing.expectEqual(@as(usize, 2), inspection.decisions.len);
    try std.testing.expect(inspection.decisions[1].decision.escalated);
    try std.testing.expectEqual(@as(usize, 1), inspection.decisions[1].affected_children);
    try std.testing.expectEqual(@as(u64, 2), inspection.shutdown_order[0]);

    const text = try fx.formatSupervisorInspectionText(std.testing.allocator, inspection);
    defer std.testing.allocator.free(text);
    try std.testing.expect(std.mem.indexOf(u8, text, "inspect-root") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "escalated_children: 1") != null);

    const json = try fx.formatSupervisorInspectionJson(std.testing.allocator, inspection);
    defer std.testing.allocator.free(json);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"supervisor_id\":80") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"decision_count\":2") != null);
}

test "supervisor records causal lifecycle decision escalation and shutdown events" {
    var store = fx.CausalStore.init(std.testing.allocator);
    defer store.deinit();

    var supervisor = fx.Supervisor.init(std.testing.allocator, .{
        .id = 10,
        .name = "root",
        .strategy = .one_for_one,
        .intensity = .{ .max_restarts = 1, .within_ms = 1_000 },
    });
    defer supervisor.deinit();

    supervisor.attachCausalStore(&store, 777);
    try supervisor.addChild(.{ .id = 1, .name = "first", .kind = .fiber });
    try supervisor.addChild(.{ .id = 2, .name = "second", .kind = .workflow_worker });
    try supervisor.startAll(1_000);
    _ = try supervisor.reportChildExit(1, .{ .failure = "boom" }, 1_100);
    _ = try supervisor.reportChildExit(1, .{ .failure = "boom" }, 1_200);
    var plan = try supervisor.shutdownPlan(std.testing.allocator);
    defer plan.deinit();

    var snapshot = try store.snapshot(std.testing.allocator);
    defer snapshot.deinit();

    try std.testing.expect(snapshotHasKind(snapshot, .supervisor_child_started));
    try std.testing.expect(snapshotHasKind(snapshot, .supervisor_restart_decided));
    try std.testing.expect(snapshotHasKind(snapshot, .supervisor_escalated));
    try std.testing.expect(snapshotHasKind(snapshot, .supervisor_shutdown_ordered));
    for (snapshot.events) |event| {
        try std.testing.expectEqual(@as(u64, 777), event.run_id.?);
    }
}

fn snapshotHasKind(snapshot: fx.CausalSnapshot, kind: fx.CausalEventKind) bool {
    for (snapshot.events) |event| {
        if (event.kind == kind) return true;
    }
    return false;
}
