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

test "cluster service supervision public exports are available" {
    try std.testing.expect(@hasDecl(fx.cluster, "ClusterServiceRestartPolicy"));
    try std.testing.expect(@hasDecl(fx.cluster, "ClusterServiceRestartState"));
    try std.testing.expect(@hasDecl(fx.cluster, "ClusterServiceRestartDecision"));
    try std.testing.expect(@hasDecl(fx.cluster, "superviseTransportFailure"));
    try std.testing.expect(@hasDecl(fx.cluster, "superviseShardWorkerFailure"));
    try std.testing.expect(@hasDecl(fx, "ClusterServiceRestartState"));
    try std.testing.expect(@hasDecl(fx, "superviseTransportFailure"));
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

test "transport failure supervision restarts then escalates" {
    var state = fx.ClusterServiceRestartState.init(std.testing.allocator, .{
        .max_restarts = 1,
        .within_ms = 1_000,
    });
    defer state.deinit();

    const failure = fx.ClusterTransportFailureReport{
        .transport = .production_http,
        .retryable = true,
        .attempts = 2,
        .error_name = "TransportUnavailable",
        .redacted_detail = "runner-a to runner-b",
    };

    const first = try fx.superviseTransportFailure(&state, failure, 1_000);
    try std.testing.expectEqual(@as(usize, 1), first.transport_failures);
    try std.testing.expectEqual(@as(usize, 1), first.transport_restarts);
    try std.testing.expectEqual(@as(usize, 0), first.transport_escalations);

    const second = try fx.superviseTransportFailure(&state, failure, 1_100);
    try std.testing.expectEqual(@as(usize, 1), second.transport_failures);
    try std.testing.expectEqual(@as(usize, 0), second.transport_restarts);
    try std.testing.expectEqual(@as(usize, 1), second.transport_escalations);
}

test "shard worker supervision reports restart and escalation" {
    var state = fx.ClusterServiceRestartState.init(std.testing.allocator, .{
        .max_restarts = 1,
        .within_ms = 1_000,
    });
    defer state.deinit();

    const first = try fx.superviseShardWorkerFailure(&state, 3, 1_000);
    try std.testing.expectEqual(@as(usize, 1), first.shard_worker_failures);
    try std.testing.expectEqual(@as(usize, 1), first.shard_worker_restarts);
    try std.testing.expectEqual(@as(usize, 0), first.shard_worker_escalations);

    const second = try fx.superviseShardWorkerFailure(&state, 3, 1_100);
    try std.testing.expectEqual(@as(usize, 1), second.shard_worker_failures);
    try std.testing.expectEqual(@as(usize, 0), second.shard_worker_restarts);
    try std.testing.expectEqual(@as(usize, 1), second.shard_worker_escalations);
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

test "supervised cluster processing records local entity restart and keeps shard" {
    var runner_storage_state = fx.InMemoryRunnerStorage.init(std.testing.allocator);
    defer runner_storage_state.deinit();
    const runner_storage = runner_storage_state.asRunnerStorage();
    const owner = fx.runnerAddress("machine-supervision", "runner-a");
    var lease_manager = try fx.LocalShardLeaseManager.init(
        std.testing.allocator,
        runner_storage,
        owner,
        .{ .ttl_ms = 1_000, .refresh_interval_ms = 250 },
    );
    defer lease_manager.deinit();

    var message_storage_state = fx.InMemoryMessageStorage.init(std.testing.allocator);
    defer message_storage_state.deinit();
    const message_storage = message_storage_state.asMessageStorage();

    var runtime = try fx.ClusterRuntime.init(
        std.testing.allocator,
        message_storage,
        &lease_manager,
        .{
            .shard_count = 8,
            .entity_runtime_options = .{ .restart_intensity = .{ .max_restarts = 2, .within_ms = 1_000 } },
        },
    );
    defer runtime.deinit();

    const address = try addressForShard(0, 8);
    _ = try runtime.acquireShard(0, 1_000);
    const ref = try runtime.registerEntity(.{ .address = address, .name = "supervised-counter" }, 1_000);
    var submitted = try ref.tell("text", "boom", "supervised-failure");
    defer submitted.deinit(std.testing.allocator);

    const Handler = struct {
        pub fn handle(_: *fx.EntityScope, _: fx.EntityEnvelope) !fx.EntityHandlerResult {
            return error.Boom;
        }
    };

    const report = try runtime.processShardSupervised(0, Handler, 1_100);
    try std.testing.expectEqual(@as(usize, 1), report.failed);
    try std.testing.expectEqual(@as(usize, 1), report.entity_failures);
    try std.testing.expectEqual(@as(usize, 1), report.entity_restarts);
    try std.testing.expectEqual(@as(usize, 0), report.entity_escalations);
    try std.testing.expectEqual(@as(usize, 0), report.shard_releases);
    try std.testing.expect(runtime.ownsShard(0));
    try std.testing.expectEqual(fx.EntityStatus.running, try runtime.local_runtime.status(address));

    var retryable = (try message_storage.unprocessedById(submitted.envelope.id, std.testing.allocator)).?;
    defer retryable.deinit(std.testing.allocator);
    try std.testing.expectEqual(fx.MessageDeliveryStatus.claimed, retryable.status);
}

test "supervised entity escalation releases shard for another runner" {
    var runner_storage_state = fx.InMemoryRunnerStorage.init(std.testing.allocator);
    defer runner_storage_state.deinit();
    const runner_storage = runner_storage_state.asRunnerStorage();
    var message_storage_state = fx.InMemoryMessageStorage.init(std.testing.allocator);
    defer message_storage_state.deinit();
    const message_storage = message_storage_state.asMessageStorage();

    var lease_manager_a = try fx.LocalShardLeaseManager.init(
        std.testing.allocator,
        runner_storage,
        fx.runnerAddress("machine-supervision", "runner-a"),
        .{ .ttl_ms = 1_000, .refresh_interval_ms = 250 },
    );
    defer lease_manager_a.deinit();
    var runtime_a = try fx.ClusterRuntime.init(
        std.testing.allocator,
        message_storage,
        &lease_manager_a,
        .{
            .shard_count = 8,
            .entity_runtime_options = .{ .restart_intensity = .{ .max_restarts = 0, .within_ms = 1_000 } },
        },
    );
    defer runtime_a.deinit();

    const address = try addressForShard(0, 8);
    _ = try runtime_a.acquireShard(0, 1_000);
    const ref_a = try runtime_a.registerEntity(.{ .address = address, .name = "migrating-counter" }, 1_000);
    var submitted = try ref_a.tell("text", "finish", "migrate-after-escalation");
    defer submitted.deinit(std.testing.allocator);

    const FailingHandler = struct {
        pub fn handle(_: *fx.EntityScope, _: fx.EntityEnvelope) !fx.EntityHandlerResult {
            return error.Boom;
        }
    };

    const failed = try runtime_a.processShardSupervised(0, FailingHandler, 1_100);
    try std.testing.expectEqual(@as(usize, 1), failed.entity_escalations);
    try std.testing.expectEqual(@as(usize, 1), failed.shard_releases);
    try std.testing.expect(!runtime_a.ownsShard(0));
    try std.testing.expect((try runner_storage.lease(0)) == null);

    var lease_manager_b = try fx.LocalShardLeaseManager.init(
        std.testing.allocator,
        runner_storage,
        fx.runnerAddress("machine-supervision", "runner-b"),
        .{ .ttl_ms = 1_000, .refresh_interval_ms = 250 },
    );
    defer lease_manager_b.deinit();
    var runtime_b = try fx.ClusterRuntime.init(
        std.testing.allocator,
        message_storage,
        &lease_manager_b,
        .{ .shard_count = 8 },
    );
    defer runtime_b.deinit();

    _ = try runtime_b.acquireShard(0, 1_200);
    _ = try runtime_b.registerEntity(.{ .address = address, .name = "migrating-counter" }, 1_200);

    const SuccessHandler = struct {
        pub fn handle(_: *fx.EntityScope, _: fx.EntityEnvelope) !fx.EntityHandlerResult {
            return .noreply;
        }
    };

    const recovered = try runtime_b.processShardSupervised(0, SuccessHandler, 1_300);
    try std.testing.expectEqual(@as(usize, 1), recovered.acked);
    try std.testing.expect((try message_storage.unprocessedById(submitted.envelope.id, std.testing.allocator)) == null);
}

test "supervised workflow entity failure is reported as workflow worker restart" {
    var runner_storage_state = fx.InMemoryRunnerStorage.init(std.testing.allocator);
    defer runner_storage_state.deinit();
    var message_storage_state = fx.InMemoryMessageStorage.init(std.testing.allocator);
    defer message_storage_state.deinit();
    const message_storage = message_storage_state.asMessageStorage();
    var journal_state = fx.workflow.InMemoryJournalStore.init(std.testing.allocator);
    defer journal_state.deinit();
    const journal_store = journal_state.asJournalStore();

    var runner = try fx.LocalClusterRunner.init(std.testing.allocator, .{
        .runner = fx.runnerAddress("machine-supervision", "runner-workflow"),
        .runner_storage = runner_storage_state.asRunnerStorage(),
        .message_storage = message_storage,
        .shard_count = 8,
        .runner_index = 0,
        .runner_count = 1,
        .lease_options = .{ .ttl_ms = 1_000, .refresh_interval_ms = 250 },
        .entity_runtime_options = .{ .restart_intensity = .{ .max_restarts = 2, .within_ms = 1_000 } },
    });
    defer runner.deinit();
    _ = try runner.runtime.acquireShard(0, 1_000);

    const workflow_id = fx.workflow.workflowId("approval");
    const execution_id = try executionIdForWorkflowShard(0, 8);
    var registry = fx.ClusterWorkflowEntityRegistry.init(std.testing.allocator);
    defer registry.deinit();
    _ = try registry.registerExecution(&runner, journal_store, workflow_id, execution_id, 1_000);

    var submitted = try message_storage.submit(.{
        .shard_id = 0,
        .envelope = .{
            .kind = .request,
            .address = fx.clusterWorkflowExecutionAddress(execution_id),
            .idempotency_key = "bad-workflow-command",
            .payload_type_name = fx.cluster_workflow_command_payload_type,
            .payload = "{bad-json",
            .redacted_detail = "bad-workflow-command",
        },
    });
    defer submitted.deinit(std.testing.allocator);

    const report = try runner.runtime.processShardSupervised(0, fx.ClusterWorkflowEntityHandler, 1_100);
    try std.testing.expectEqual(@as(usize, 1), report.workflow_worker_failures);
    try std.testing.expectEqual(@as(usize, 1), report.workflow_worker_restarts);
    try std.testing.expectEqual(@as(usize, 1), report.entity_restarts);
}

test "local cluster runner supervised tick aggregates supervision report" {
    var runner_storage_state = fx.InMemoryRunnerStorage.init(std.testing.allocator);
    defer runner_storage_state.deinit();
    var message_storage_state = fx.InMemoryMessageStorage.init(std.testing.allocator);
    defer message_storage_state.deinit();

    var runner = try fx.LocalClusterRunner.init(std.testing.allocator, .{
        .runner = fx.runnerAddress("machine-supervision", "runner-tick"),
        .runner_storage = runner_storage_state.asRunnerStorage(),
        .message_storage = message_storage_state.asMessageStorage(),
        .shard_count = 8,
        .runner_index = 0,
        .runner_count = 1,
        .lease_options = .{ .ttl_ms = 1_000, .refresh_interval_ms = 250 },
        .entity_runtime_options = .{ .restart_intensity = .{ .max_restarts = 2, .within_ms = 1_000 } },
        .runner_restart_policy = .{ .max_restarts = 2, .within_ms = 1_000 },
    });
    defer runner.deinit();
    _ = try runner.runtime.acquireShard(0, 1_000);

    const address = try addressForShard(0, 8);
    const ref = try runner.registerEntity(.{ .address = address, .name = "tick-counter" }, 1_000);
    var submitted = try ref.tell("text", "boom", "tick-failure");
    defer submitted.deinit(std.testing.allocator);

    const Handler = struct {
        pub fn handle(_: *fx.EntityScope, _: fx.EntityEnvelope) !fx.EntityHandlerResult {
            return error.Boom;
        }
    };

    const report = try runner.tickSupervised(Handler, 1_100);
    try std.testing.expectEqual(@as(usize, 1), report.entity_failures);
    try std.testing.expectEqual(@as(usize, 1), report.entity_restarts);
    try std.testing.expectEqual(@as(usize, 0), report.runner_escalations);
}

fn addressForShard(shard_id: fx.ShardId, shard_count: fx.ShardCount) !fx.EntityAddress {
    var id: u64 = 1;
    while (id < 100_000) : (id += 1) {
        var key_buf: [32]u8 = undefined;
        const key = std.fmt.bufPrint(&key_buf, "supervised-{d}", .{id}) catch unreachable;
        const address = fx.entityAddress("supervised", key);
        if (try fx.shardIdForAddress(address, shard_count) == shard_id) return address;
    }
    return error.EntityShardNotFound;
}

fn executionIdForWorkflowShard(shard_id: fx.ShardId, shard_count: fx.ShardCount) !fx.workflow.ExecutionId {
    var id: fx.workflow.ExecutionId = 1;
    while (id < 100_000) : (id += 1) {
        const address = fx.clusterWorkflowExecutionAddress(id);
        if (try fx.shardIdForAddress(address, shard_count) == shard_id) return id;
    }
    return error.ExecutionShardNotFound;
}
