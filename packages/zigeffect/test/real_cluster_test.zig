const std = @import("std");
const fx = @import("zigeffect");

test "real cluster public exports are available" {
    try std.testing.expect(@hasDecl(fx.cluster, "real_cluster"));
    try std.testing.expect(@hasDecl(fx.cluster, "RealClusterController"));
    try std.testing.expect(@hasDecl(fx.cluster, "RealClusterControllerOptions"));
    try std.testing.expect(@hasDecl(fx.cluster, "RealClusterError"));
    try std.testing.expect(@hasDecl(fx.cluster, "ClusterMembershipState"));
    try std.testing.expect(@hasDecl(fx.cluster, "ClusterAdmissionDecision"));
    try std.testing.expect(@hasDecl(fx.cluster, "ClusterMember"));
    try std.testing.expect(@hasDecl(fx.cluster, "ClusterMembershipReport"));
    try std.testing.expect(@hasDecl(fx.cluster, "ClusterPlacementStrategy"));
    try std.testing.expect(@hasDecl(fx.cluster, "ClusterShardPlacement"));
    try std.testing.expect(@hasDecl(fx.cluster, "ClusterPlacementPlan"));
    try std.testing.expect(@hasDecl(fx.cluster, "ClusterRebalanceActionKind"));
    try std.testing.expect(@hasDecl(fx.cluster, "ClusterRebalanceAction"));
    try std.testing.expect(@hasDecl(fx.cluster, "ClusterRebalancePlan"));
    try std.testing.expect(@hasDecl(fx.cluster, "ClusterDrainPlan"));
    try std.testing.expect(@hasDecl(fx.cluster, "ClusterNodeDownRecoveryPlan"));
    try std.testing.expect(@hasDecl(fx.cluster, "ClusterSplitBrainFinding"));
    try std.testing.expect(@hasDecl(fx.cluster, "ClusterSplitBrainReport"));
    try std.testing.expect(@hasDecl(fx.cluster, "ClusterInspectionReport"));
    try std.testing.expect(@hasDecl(fx.cluster, "formatClusterInspectionText"));
    try std.testing.expect(@hasDecl(fx.cluster, "formatClusterInspectionJson"));
    try std.testing.expect(@hasDecl(fx, "RealClusterController"));
}

test "real cluster admits runners and discovers active members" {
    var registry = fx.LocalRunnerRegistry.init(std.testing.allocator);
    defer registry.deinit();
    var runner_storage_state = fx.InMemoryRunnerStorage.init(std.testing.allocator);
    defer runner_storage_state.deinit();
    var message_storage_state = fx.InMemoryMessageStorage.init(std.testing.allocator);
    defer message_storage_state.deinit();

    var controller = try fx.RealClusterController.init(std.testing.allocator, .{
        .runner_storage = runner_storage_state.asRunnerStorage(),
        .message_storage = message_storage_state.asMessageStorage(),
        .registry = &registry,
        .options = .{
            .shard_count = 8,
            .lease_ttl_ms = 1_000,
            .health_options = .{ .degraded_after_ms = 100, .unhealthy_after_ms = 300 },
        },
    });

    const runner_a = fx.runnerAddress("machine-real", "runner-a");
    try std.testing.expectEqual(fx.ClusterAdmissionDecision.admitted, try controller.admitRunner(.{
        .address = runner_a,
        .name = "runner-a",
        .started_at_ms = 1_000,
    }));
    try std.testing.expectEqual(fx.ClusterAdmissionDecision.already_member, try controller.admitRunner(.{
        .address = runner_a,
        .name = "runner-a-again",
        .started_at_ms = 1_001,
    }));
    _ = try controller.recordHeartbeat(.{ .address = runner_a, .sequence = 1, .observed_at_ms = 1_010 });

    var report = try controller.discoverRunners(std.testing.allocator, 1_050);
    defer report.deinit();
    try std.testing.expectEqual(@as(usize, 1), report.members.len);
    try std.testing.expectEqual(fx.ClusterMembershipState.active, report.members[0].state);
    try std.testing.expectEqual(@as(usize, 1), report.active);
    try std.testing.expectEqualStrings("runner-a", report.members[0].name);
}

test "real cluster reports joining down and leaving members" {
    var registry = fx.LocalRunnerRegistry.init(std.testing.allocator);
    defer registry.deinit();
    var runner_storage_state = fx.InMemoryRunnerStorage.init(std.testing.allocator);
    defer runner_storage_state.deinit();
    var message_storage_state = fx.InMemoryMessageStorage.init(std.testing.allocator);
    defer message_storage_state.deinit();

    var controller = try fx.RealClusterController.init(std.testing.allocator, .{
        .runner_storage = runner_storage_state.asRunnerStorage(),
        .message_storage = message_storage_state.asMessageStorage(),
        .registry = &registry,
        .options = .{
            .shard_count = 8,
            .lease_ttl_ms = 1_000,
            .health_options = .{ .degraded_after_ms = 100, .unhealthy_after_ms = 300 },
        },
    });

    const down_runner = fx.runnerAddress("machine-real", "runner-down");
    const joining_runner = fx.runnerAddress("machine-real", "runner-joining");
    const leaving_runner = fx.runnerAddress("machine-real", "runner-leaving");
    _ = try controller.admitRunner(.{ .address = down_runner, .name = "runner-down", .started_at_ms = 1_000 });
    _ = try controller.recordHeartbeat(.{ .address = down_runner, .sequence = 1, .observed_at_ms = 1_050 });
    _ = try controller.admitRunner(.{ .address = joining_runner, .name = "runner-joining", .started_at_ms = 1_350 });
    _ = try controller.admitRunner(.{ .address = leaving_runner, .name = "runner-leaving", .started_at_ms = 1_000 });
    try registry.markStopped(leaving_runner, 1_200);

    var report = try controller.discoverRunners(std.testing.allocator, 1_400);
    defer report.deinit();

    try std.testing.expectEqual(@as(usize, 3), report.members.len);
    try std.testing.expectEqual(@as(usize, 1), report.down);
    try expectMemberState(report, joining_runner, .joining);
    try expectMemberState(report, down_runner, .down);
    try expectMemberState(report, leaving_runner, .leaving);
}

test "real cluster controller validates startup options" {
    var registry = fx.LocalRunnerRegistry.init(std.testing.allocator);
    defer registry.deinit();
    var runner_storage_state = fx.InMemoryRunnerStorage.init(std.testing.allocator);
    defer runner_storage_state.deinit();
    var message_storage_state = fx.InMemoryMessageStorage.init(std.testing.allocator);
    defer message_storage_state.deinit();

    try std.testing.expectError(error.InvalidShardCount, fx.RealClusterController.init(std.testing.allocator, .{
        .runner_storage = runner_storage_state.asRunnerStorage(),
        .message_storage = message_storage_state.asMessageStorage(),
        .registry = &registry,
        .options = .{ .shard_count = 0, .lease_ttl_ms = 1_000 },
    }));
    try std.testing.expectError(error.InvalidLeaseTtl, fx.RealClusterController.init(std.testing.allocator, .{
        .runner_storage = runner_storage_state.asRunnerStorage(),
        .message_storage = message_storage_state.asMessageStorage(),
        .registry = &registry,
        .options = .{ .shard_count = 8, .lease_ttl_ms = 0 },
    }));
}

test "real cluster balances placement across active members" {
    var registry = fx.LocalRunnerRegistry.init(std.testing.allocator);
    defer registry.deinit();
    var runner_storage_state = fx.InMemoryRunnerStorage.init(std.testing.allocator);
    defer runner_storage_state.deinit();
    var message_storage_state = fx.InMemoryMessageStorage.init(std.testing.allocator);
    defer message_storage_state.deinit();
    var controller = try testController(&registry, runner_storage_state.asRunnerStorage(), message_storage_state.asMessageStorage());

    const runner_a = fx.runnerAddress("machine-real", "runner-a");
    const runner_b = fx.runnerAddress("machine-real", "runner-b");
    try admitActiveRunner(&controller, runner_a, "runner-a", 1_000);
    try admitActiveRunner(&controller, runner_b, "runner-b", 1_000);

    var plan = try controller.placementPlan(std.testing.allocator, 1_050);
    defer plan.deinit();
    try std.testing.expectEqual(@as(usize, 8), plan.placements.len);
    try expectPlacementOwners(plan, &.{ runner_a, runner_b });
}

test "real cluster placement requires active members" {
    var registry = fx.LocalRunnerRegistry.init(std.testing.allocator);
    defer registry.deinit();
    var runner_storage_state = fx.InMemoryRunnerStorage.init(std.testing.allocator);
    defer runner_storage_state.deinit();
    var message_storage_state = fx.InMemoryMessageStorage.init(std.testing.allocator);
    defer message_storage_state.deinit();
    var controller = try testController(&registry, runner_storage_state.asRunnerStorage(), message_storage_state.asMessageStorage());

    try std.testing.expectError(error.NoActiveClusterMembers, controller.placementPlan(std.testing.allocator, 1_050));
}

test "real cluster applies rebalance plan to durable leases" {
    var registry = fx.LocalRunnerRegistry.init(std.testing.allocator);
    defer registry.deinit();
    var runner_storage_state = fx.InMemoryRunnerStorage.init(std.testing.allocator);
    defer runner_storage_state.deinit();
    const runner_storage = runner_storage_state.asRunnerStorage();
    var message_storage_state = fx.InMemoryMessageStorage.init(std.testing.allocator);
    defer message_storage_state.deinit();
    var controller = try testController(&registry, runner_storage, message_storage_state.asMessageStorage());

    const runner_a = fx.runnerAddress("machine-real", "runner-a");
    const runner_b = fx.runnerAddress("machine-real", "runner-b");
    try admitActiveRunner(&controller, runner_a, "runner-a", 1_000);
    try admitActiveRunner(&controller, runner_b, "runner-b", 1_000);

    var placement = try controller.placementPlan(std.testing.allocator, 1_050);
    defer placement.deinit();
    var rebalance = try controller.rebalancePlan(std.testing.allocator, placement);
    defer rebalance.deinit();
    try std.testing.expectEqual(@as(usize, 8), countRebalanceKind(rebalance, .acquire));

    const applied = try controller.applyRebalancePlan(rebalance, 1_100);
    try std.testing.expectEqual(@as(usize, 8), applied);
    try expectLeasesMatchPlacement(runner_storage, placement);
}

test "real cluster handoff plan moves durable leases after adding runner" {
    var registry = fx.LocalRunnerRegistry.init(std.testing.allocator);
    defer registry.deinit();
    var runner_storage_state = fx.InMemoryRunnerStorage.init(std.testing.allocator);
    defer runner_storage_state.deinit();
    const runner_storage = runner_storage_state.asRunnerStorage();
    var message_storage_state = fx.InMemoryMessageStorage.init(std.testing.allocator);
    defer message_storage_state.deinit();
    var controller = try testController(&registry, runner_storage, message_storage_state.asMessageStorage());

    const runner_a = fx.runnerAddress("machine-real", "runner-a");
    const runner_b = fx.runnerAddress("machine-real", "runner-b");
    try admitActiveRunner(&controller, runner_a, "runner-a", 1_000);
    var first_placement = try controller.placementPlan(std.testing.allocator, 1_050);
    defer first_placement.deinit();
    var first_rebalance = try controller.rebalancePlan(std.testing.allocator, first_placement);
    defer first_rebalance.deinit();
    _ = try controller.applyRebalancePlan(first_rebalance, 1_100);

    try admitActiveRunner(&controller, runner_b, "runner-b", 1_200);
    var next_placement = try controller.placementPlan(std.testing.allocator, 1_250);
    defer next_placement.deinit();
    var next_rebalance = try controller.rebalancePlan(std.testing.allocator, next_placement);
    defer next_rebalance.deinit();
    try std.testing.expect(countRebalanceKind(next_rebalance, .handoff) > 0);

    _ = try controller.applyRebalancePlan(next_rebalance, 1_300);
    try expectLeasesMatchPlacement(runner_storage, next_placement);
}

fn testController(registry: *fx.LocalRunnerRegistry, runner_storage: fx.RunnerStorage, message_storage: fx.MessageStorage) !fx.RealClusterController {
    return fx.RealClusterController.init(std.testing.allocator, .{
        .runner_storage = runner_storage,
        .message_storage = message_storage,
        .registry = registry,
        .options = .{
            .shard_count = 8,
            .lease_ttl_ms = 1_000,
            .health_options = .{ .degraded_after_ms = 100, .unhealthy_after_ms = 300 },
        },
    });
}

fn admitActiveRunner(controller: *fx.RealClusterController, address: fx.RunnerAddress, name: []const u8, now_ms: u64) !void {
    _ = try controller.admitRunner(.{ .address = address, .name = name, .started_at_ms = now_ms });
    _ = try controller.recordHeartbeat(.{ .address = address, .sequence = 1, .observed_at_ms = now_ms + 10 });
}

fn expectPlacementOwners(plan: fx.ClusterPlacementPlan, owners: []const fx.RunnerAddress) !void {
    for (plan.placements, 0..) |placement, index| {
        try std.testing.expect(placement.owner.eql(owners[index % owners.len]));
    }
}

fn countRebalanceKind(plan: fx.ClusterRebalancePlan, kind: fx.ClusterRebalanceActionKind) usize {
    var count: usize = 0;
    for (plan.actions) |action| {
        if (action.kind == kind) count += 1;
    }
    return count;
}

fn expectLeasesMatchPlacement(runner_storage: fx.RunnerStorage, plan: fx.ClusterPlacementPlan) !void {
    for (plan.placements) |placement| {
        const lease = (try runner_storage.lease(placement.shard_id)).?;
        try std.testing.expect(lease.owner.eql(placement.owner));
    }
}

fn expectMemberState(report: fx.ClusterMembershipReport, address: fx.RunnerAddress, state: fx.ClusterMembershipState) !void {
    for (report.members) |member| {
        if (!member.address.eql(address)) continue;
        try std.testing.expectEqual(state, member.state);
        return;
    }
    return error.ExpectedClusterMember;
}
