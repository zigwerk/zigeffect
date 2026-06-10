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
    try std.testing.expect(@hasDecl(fx.cluster, "ClusterSplitBrainFindingKind"));
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

test "real cluster drain reassigns leases and synced runner processes queued messages" {
    var registry = fx.LocalRunnerRegistry.init(std.testing.allocator);
    defer registry.deinit();
    var runner_storage_state = fx.InMemoryRunnerStorage.init(std.testing.allocator);
    defer runner_storage_state.deinit();
    const runner_storage = runner_storage_state.asRunnerStorage();
    var message_storage_state = fx.InMemoryMessageStorage.init(std.testing.allocator);
    defer message_storage_state.deinit();
    const message_storage = message_storage_state.asMessageStorage();
    var controller = try testController(&registry, runner_storage, message_storage);

    const runner_a_address = fx.runnerAddress("machine-real", "runner-a");
    const runner_b_address = fx.runnerAddress("machine-real", "runner-b");
    try admitActiveRunner(&controller, runner_a_address, "runner-a", 1_000);
    try admitActiveRunner(&controller, runner_b_address, "runner-b", 1_000);

    var runner_a = try fx.LocalClusterRunner.init(std.testing.allocator, .{
        .runner = runner_a_address,
        .runner_storage = runner_storage,
        .message_storage = message_storage,
        .shard_count = 8,
        .runner_index = 0,
        .runner_count = 2,
        .lease_options = .{ .ttl_ms = 1_000, .refresh_interval_ms = 250 },
    });
    defer runner_a.deinit();
    var runner_b = try fx.LocalClusterRunner.init(std.testing.allocator, .{
        .runner = runner_b_address,
        .runner_storage = runner_storage,
        .message_storage = message_storage,
        .shard_count = 8,
        .runner_index = 1,
        .runner_count = 2,
        .lease_options = .{ .ttl_ms = 1_000, .refresh_interval_ms = 250 },
    });
    defer runner_b.deinit();

    var placement = try controller.placementPlan(std.testing.allocator, 1_050);
    defer placement.deinit();
    var rebalance = try controller.rebalancePlan(std.testing.allocator, placement);
    defer rebalance.deinit();
    _ = try controller.applyRebalancePlan(rebalance, 1_100);
    try std.testing.expectEqual(@as(usize, 4), try runner_a.syncOwnedShards());
    try std.testing.expectEqual(@as(usize, 4), try runner_b.syncOwnedShards());

    const drained_address = try addressForRealShard(0, 8);
    var routed = try runner_b.router.routeAsk(drained_address, "text", "drain-get", "read after drain");
    defer routed.deinit(std.testing.allocator);

    const drain = try controller.drainRunner(runner_a_address, 1_200);
    try std.testing.expectEqual(@as(usize, 4), drain.released);
    try std.testing.expectEqual(@as(usize, 4), drain.reassigned);
    try std.testing.expectEqual(@as(usize, 0), try runner_a.syncOwnedShards());
    try std.testing.expectEqual(@as(usize, 8), try runner_b.syncOwnedShards());

    _ = try runner_b.registerEntity(.{ .address = drained_address, .name = "drained" }, 1_200);
    const Handler = struct {
        pub fn handle(_: *fx.EntityScope, envelope: fx.EntityEnvelope) !fx.EntityHandlerResult {
            try std.testing.expectEqual(fx.EntityEnvelopeKind.ask, envelope.kind);
            try std.testing.expectEqualStrings("drain-get", envelope.payload);
            return .{ .reply = "value=drained" };
        }
    };

    const report = try runner_b.tick(Handler, 1_250);
    try std.testing.expectEqual(@as(usize, 1), report.dispatched);
    const reply = (try message_storage.reply(routed.correlation_id.?, std.testing.allocator)).?;
    defer fx.deinitMessageEnvelope(std.testing.allocator, reply);
    try std.testing.expectEqualStrings("value=drained", reply.payload);
}

test "real cluster node down recovery refuses live runners" {
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
    _ = try runner_storage.acquire(.{
        .shard_id = 0,
        .owner = runner_a,
        .now_ms = 1_050,
        .ttl_ms = 1_000,
    });

    try std.testing.expectError(error.RunnerStillAlive, controller.recoverNodeDown(runner_a, runner_b, 1_100));
    const lease = (try runner_storage.lease(0)).?;
    try std.testing.expect(lease.owner.eql(runner_a));
}

test "real cluster node down recovery reassigns leases and surviving runner processes queued messages" {
    var registry = fx.LocalRunnerRegistry.init(std.testing.allocator);
    defer registry.deinit();
    var runner_storage_state = fx.InMemoryRunnerStorage.init(std.testing.allocator);
    defer runner_storage_state.deinit();
    const runner_storage = runner_storage_state.asRunnerStorage();
    var message_storage_state = fx.InMemoryMessageStorage.init(std.testing.allocator);
    defer message_storage_state.deinit();
    const message_storage = message_storage_state.asMessageStorage();
    var controller = try testController(&registry, runner_storage, message_storage);

    const runner_a_address = fx.runnerAddress("machine-real", "runner-a");
    const runner_b_address = fx.runnerAddress("machine-real", "runner-b");
    try admitActiveRunner(&controller, runner_a_address, "runner-a", 1_000);
    try admitActiveRunner(&controller, runner_b_address, "runner-b", 1_000);

    var runner_a = try fx.LocalClusterRunner.init(std.testing.allocator, .{
        .runner = runner_a_address,
        .runner_storage = runner_storage,
        .message_storage = message_storage,
        .shard_count = 8,
        .runner_index = 0,
        .runner_count = 2,
        .lease_options = .{ .ttl_ms = 1_000, .refresh_interval_ms = 250 },
    });
    defer runner_a.deinit();
    var runner_b = try fx.LocalClusterRunner.init(std.testing.allocator, .{
        .runner = runner_b_address,
        .runner_storage = runner_storage,
        .message_storage = message_storage,
        .shard_count = 8,
        .runner_index = 1,
        .runner_count = 2,
        .lease_options = .{ .ttl_ms = 1_000, .refresh_interval_ms = 250 },
    });
    defer runner_b.deinit();

    var placement = try controller.placementPlan(std.testing.allocator, 1_050);
    defer placement.deinit();
    var rebalance = try controller.rebalancePlan(std.testing.allocator, placement);
    defer rebalance.deinit();
    _ = try controller.applyRebalancePlan(rebalance, 1_100);
    try std.testing.expectEqual(@as(usize, 4), try runner_a.syncOwnedShards());
    try std.testing.expectEqual(@as(usize, 4), try runner_b.syncOwnedShards());

    const recovered_address = try addressForRealShard(0, 8);
    var routed = try runner_b.router.routeAsk(recovered_address, "text", "recover-get", "read after recovery");
    defer routed.deinit(std.testing.allocator);

    _ = try controller.recordHeartbeat(.{ .address = runner_b_address, .sequence = 2, .observed_at_ms = 1_850 });
    const recovery = try controller.recoverNodeDown(runner_a_address, runner_b_address, 2_000);
    try std.testing.expect(recovery.dead_runner.eql(runner_a_address));
    try std.testing.expect(recovery.recovered_by.eql(runner_b_address));
    try std.testing.expectEqual(@as(usize, 4), recovery.released);
    try std.testing.expectEqual(@as(usize, 4), recovery.reassigned);
    try std.testing.expectEqual(@as(usize, 0), try runner_a.syncOwnedShards());
    try std.testing.expectEqual(@as(usize, 8), try runner_b.syncOwnedShards());

    _ = try runner_b.registerEntity(.{ .address = recovered_address, .name = "recovered" }, 2_000);
    const Handler = struct {
        pub fn handle(_: *fx.EntityScope, envelope: fx.EntityEnvelope) !fx.EntityHandlerResult {
            try std.testing.expectEqual(fx.EntityEnvelopeKind.ask, envelope.kind);
            try std.testing.expectEqualStrings("recover-get", envelope.payload);
            return .{ .reply = "value=recovered" };
        }
    };

    const report = try runner_b.tick(Handler, 2_050);
    try std.testing.expectEqual(@as(usize, 1), report.dispatched);
    const reply = (try message_storage.reply(routed.correlation_id.?, std.testing.allocator)).?;
    defer fx.deinitMessageEnvelope(std.testing.allocator, reply);
    try std.testing.expectEqualStrings("value=recovered", reply.payload);
}

test "real cluster split brain report classifies missing owner and epoch drift" {
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
    const healthy = try runner_storage.acquire(.{
        .shard_id = 0,
        .owner = runner_a,
        .now_ms = 1_000,
        .ttl_ms = 100,
    });
    const owner_mismatch = try runner_storage.acquire(.{
        .shard_id = 1,
        .owner = runner_b,
        .now_ms = 1_000,
        .ttl_ms = 100,
    });
    _ = try runner_storage.acquire(.{
        .shard_id = 2,
        .owner = runner_a,
        .now_ms = 1_000,
        .ttl_ms = 10,
    });
    const epoch_drift = try runner_storage.acquire(.{
        .shard_id = 2,
        .owner = runner_a,
        .now_ms = 1_020,
        .ttl_ms = 100,
    });

    const local_leases = try std.testing.allocator.dupe(fx.ShardLease, &.{
        healthy,
        .{
            .shard_id = owner_mismatch.shard_id,
            .owner = runner_a,
            .acquired_at_ms = owner_mismatch.acquired_at_ms,
            .refreshed_at_ms = owner_mismatch.refreshed_at_ms,
            .expires_at_ms = owner_mismatch.expires_at_ms,
            .epoch = owner_mismatch.epoch,
            .version = owner_mismatch.version,
        },
        .{
            .shard_id = epoch_drift.shard_id,
            .owner = epoch_drift.owner,
            .acquired_at_ms = epoch_drift.acquired_at_ms,
            .refreshed_at_ms = epoch_drift.refreshed_at_ms,
            .expires_at_ms = epoch_drift.expires_at_ms,
            .epoch = epoch_drift.epoch - 1,
            .version = epoch_drift.version,
        },
        .{
            .shard_id = 3,
            .owner = runner_a,
            .acquired_at_ms = 1_000,
            .refreshed_at_ms = 1_000,
            .expires_at_ms = 1_100,
            .epoch = 1,
            .version = 1,
        },
    });
    defer std.testing.allocator.free(local_leases);
    const local_snapshot = fx.RunnerLeaseBatch{ .allocator = std.testing.allocator, .leases = local_leases };

    var report = try controller.detectSplitBrain(std.testing.allocator, &.{local_snapshot});
    defer report.deinit();
    try std.testing.expectEqual(@as(usize, 3), report.findings.len);
    try expectSplitBrainFinding(report, .owner_mismatch, 1, runner_a, runner_b, 1, 1);
    try expectSplitBrainFinding(report, .epoch_mismatch, 2, runner_a, runner_a, 1, 2);
    try expectSplitBrainFinding(report, .missing_storage_lease, 3, runner_a, null, 1, null);
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

fn addressForRealShard(shard_id: fx.ShardId, shard_count: fx.ShardCount) !fx.EntityAddress {
    var index: usize = 0;
    while (index < 10_000) : (index += 1) {
        var key_buf: [32]u8 = undefined;
        const key = try std.fmt.bufPrint(&key_buf, "real-{d}-{d}", .{ shard_id, index });
        const address = fx.entityAddress("counter", key);
        if (try fx.shardIdForAddress(address, shard_count) == shard_id) return address;
    }
    return error.ShardAddressNotFound;
}

fn expectSplitBrainFinding(
    report: fx.ClusterSplitBrainReport,
    kind: fx.ClusterSplitBrainFindingKind,
    shard_id: fx.ShardId,
    local_owner: fx.RunnerAddress,
    storage_owner: ?fx.RunnerAddress,
    local_epoch: fx.ShardLeaseEpoch,
    storage_epoch: ?fx.ShardLeaseEpoch,
) !void {
    for (report.findings) |finding| {
        if (finding.kind != kind or finding.shard_id != shard_id) continue;
        try std.testing.expect(finding.local_owner.eql(local_owner));
        if (storage_owner) |expected_owner| {
            try std.testing.expect(finding.storage_owner.?.eql(expected_owner));
        } else {
            try std.testing.expectEqual(@as(?fx.RunnerAddress, null), finding.storage_owner);
        }
        try std.testing.expectEqual(local_epoch, finding.local_epoch);
        try std.testing.expectEqual(storage_epoch, finding.storage_epoch);
        return;
    }
    return error.ExpectedSplitBrainFinding;
}

fn expectMemberState(report: fx.ClusterMembershipReport, address: fx.RunnerAddress, state: fx.ClusterMembershipState) !void {
    for (report.members) |member| {
        if (!member.address.eql(address)) continue;
        try std.testing.expectEqual(state, member.state);
        return;
    }
    return error.ExpectedClusterMember;
}
