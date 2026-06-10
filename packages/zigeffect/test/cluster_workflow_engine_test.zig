const std = @import("std");
const fx = @import("zigeffect");

test "cluster workflow public exports are available" {
    try std.testing.expect(@hasDecl(fx.cluster, "workflow_engine"));
    try std.testing.expect(@hasDecl(fx.cluster, "cluster_workflow_entity_type"));
    try std.testing.expect(@hasDecl(fx.cluster, "cluster_workflow_command_payload_type"));
    try std.testing.expect(@hasDecl(fx.cluster, "cluster_workflow_entity_service_key"));
    try std.testing.expect(@hasDecl(fx.cluster, "ClusterWorkflowCommandKind"));
    try std.testing.expect(@hasDecl(fx.cluster, "ClusterWorkflowCommand"));
    try std.testing.expect(@hasDecl(fx.cluster, "ClusterWorkflowCommandResult"));
    try std.testing.expect(@hasDecl(fx.cluster, "ClusterWorkflowCommandError"));
    try std.testing.expect(@hasDecl(fx.cluster, "ClusterWorkflowEngine"));
    try std.testing.expect(@hasDecl(fx.cluster, "ClusterWorkflowEntityServices"));
    try std.testing.expect(@hasDecl(fx.cluster, "ClusterWorkflowEntityRegistry"));
    try std.testing.expect(@hasDecl(fx.cluster, "ClusterWorkflowEntityHandler"));
    try std.testing.expect(@hasDecl(fx.cluster, "clusterWorkflowExecutionAddress"));
    try std.testing.expect(@hasDecl(fx, "ClusterWorkflowEngine"));
}

test "cluster workflow execution address routes by execution id" {
    const execution_id: fx.workflow.ExecutionId = 42;
    const address = fx.clusterWorkflowExecutionAddress(execution_id);
    try std.testing.expectEqual(execution_id, address.id);
    try std.testing.expectEqualStrings(fx.cluster_workflow_entity_type, address.entity_type.name);

    const first_shard = try fx.shardIdForAddress(address, 16);
    const same = fx.clusterWorkflowExecutionAddress(execution_id);
    const second_shard = try fx.shardIdForAddress(same, 16);
    try std.testing.expectEqual(first_shard, second_shard);
}

test "cluster workflow command json round-trips" {
    const command = fx.ClusterWorkflowCommand{
        .kind = .append_event,
        .event_kind = .timer_scheduled,
        .workflow_id = 7,
        .execution_id = 8,
        .workflow_name = "approval",
        .name = "review-timeout",
        .status = "scheduled",
        .redacted_detail = "fire_at_ms=1200",
        .idempotency_key = "timer:review-timeout",
        .now_ms = 1_000,
        .timer_id = 55,
        .expected_next_sequence = 2,
    };

    const json = try fx.formatClusterWorkflowCommandJson(std.testing.allocator, command);
    defer std.testing.allocator.free(json);
    try std.testing.expect(std.mem.indexOf(u8, json, fx.cluster_workflow_command_schema) != null);

    var parsed = try fx.parseClusterWorkflowCommandJson(std.testing.allocator, json);
    defer parsed.deinit(std.testing.allocator);

    try std.testing.expectEqual(fx.ClusterWorkflowCommandKind.append_event, parsed.kind);
    try std.testing.expectEqual(fx.workflow.WorkflowEventKind.timer_scheduled, parsed.event_kind.?);
    try std.testing.expectEqual(@as(fx.workflow.WorkflowId, 7), parsed.workflow_id);
    try std.testing.expectEqual(@as(fx.workflow.ExecutionId, 8), parsed.execution_id);
    try std.testing.expectEqualStrings("approval", parsed.workflow_name);
    try std.testing.expectEqualStrings("review-timeout", parsed.name);
    try std.testing.expectEqualStrings("scheduled", parsed.status);
    try std.testing.expectEqualStrings("fire_at_ms=1200", parsed.redacted_detail);
    try std.testing.expectEqualStrings("timer:review-timeout", parsed.idempotency_key);
    try std.testing.expectEqual(@as(u64, 1_000), parsed.now_ms);
    try std.testing.expectEqual(@as(?fx.workflow.TimerId, 55), parsed.timer_id);
    try std.testing.expectEqual(@as(?fx.workflow.JournalSequence, 2), parsed.expected_next_sequence);
}

test "cluster workflow result json round-trips" {
    const result = fx.ClusterWorkflowCommandResult{
        .kind = .fire_due_timers,
        .workflow_id = 7,
        .execution_id = 8,
        .appended = true,
        .sequence = 4,
        .last_sequence = 5,
        .status = "running",
        .timers_fired = 1,
    };

    const json = try fx.formatClusterWorkflowCommandResultJson(std.testing.allocator, result);
    defer std.testing.allocator.free(json);
    try std.testing.expect(std.mem.indexOf(u8, json, fx.cluster_workflow_command_result_schema) != null);

    var parsed = try fx.parseClusterWorkflowCommandResultJson(std.testing.allocator, json);
    defer parsed.deinit(std.testing.allocator);

    try std.testing.expectEqual(fx.ClusterWorkflowCommandKind.fire_due_timers, parsed.kind);
    try std.testing.expectEqual(@as(fx.workflow.WorkflowId, 7), parsed.workflow_id);
    try std.testing.expectEqual(@as(fx.workflow.ExecutionId, 8), parsed.execution_id);
    try std.testing.expect(parsed.appended);
    try std.testing.expectEqual(@as(?fx.workflow.JournalSequence, 4), parsed.sequence);
    try std.testing.expectEqual(@as(fx.workflow.JournalSequence, 5), parsed.last_sequence);
    try std.testing.expectEqualStrings("running", parsed.status);
    try std.testing.expectEqual(@as(usize, 1), parsed.timers_fired);
}

test "cluster workflow command parser rejects incompatible schema" {
    const bad_command =
        \\{"schema":"other.schema","schema_version":1,"kind":"start","event_kind":null,"workflow_id":7,"execution_id":8,"workflow_name":"approval","name":"approval","status":"running","redacted_detail":"","idempotency_key":"start","now_ms":0,"activity_id":null,"timer_id":null,"deferred_id":null,"queue_id":null,"compensation_id":null,"expected_next_sequence":null}
    ;
    try std.testing.expectError(error.IncompatibleClusterWorkflowCommandSchema, fx.parseClusterWorkflowCommandJson(std.testing.allocator, bad_command));

    const bad_result =
        \\{"schema":"other.schema","schema_version":1,"kind":"start","workflow_id":7,"execution_id":8,"appended":true,"sequence":1,"last_sequence":1,"status":"running","timers_fired":0}
    ;
    try std.testing.expectError(error.IncompatibleClusterWorkflowCommandSchema, fx.parseClusterWorkflowCommandResultJson(std.testing.allocator, bad_result));
}

test "cluster workflow registry registers execution entity with journal service" {
    var runner_storage_state = fx.InMemoryRunnerStorage.init(std.testing.allocator);
    defer runner_storage_state.deinit();
    var message_storage_state = fx.InMemoryMessageStorage.init(std.testing.allocator);
    defer message_storage_state.deinit();
    var journal_state = fx.workflow.InMemoryJournalStore.init(std.testing.allocator);
    defer journal_state.deinit();
    const journal_store = journal_state.asJournalStore();

    var runner = try fx.LocalClusterRunner.init(std.testing.allocator, .{
        .runner = fx.runnerAddress("machine-workflow", "runner-a"),
        .runner_storage = runner_storage_state.asRunnerStorage(),
        .message_storage = message_storage_state.asMessageStorage(),
        .shard_count = 8,
        .runner_index = 0,
        .runner_count = 1,
        .lease_options = .{ .ttl_ms = 1_000, .refresh_interval_ms = 250 },
    });
    defer runner.deinit();
    var plan = try runner.acquireBalancedShards(1_000);
    defer plan.deinit();

    var registry = fx.ClusterWorkflowEntityRegistry.init(std.testing.allocator);
    defer registry.deinit();

    const result = try registry.registerExecution(&runner, journal_store, 7, 8, 1_000);
    const address = fx.clusterWorkflowExecutionAddress(8);
    try std.testing.expect(result.address.eql(address));
    try std.testing.expect(result.registered);

    const scope = try runner.entityScope(address);
    const raw = (try scope.service(fx.cluster_workflow_entity_service_key)).?;
    const services: *fx.ClusterWorkflowEntityServices = @ptrCast(@alignCast(raw));
    try std.testing.expectEqual(@as(fx.workflow.WorkflowId, 7), services.workflow_id);
    try std.testing.expectEqual(@as(fx.workflow.ExecutionId, 8), services.execution_id);
    try std.testing.expect(services.journal_store.context == journal_store.context);
}

test "cluster workflow registry recovers owned executions from journal" {
    var runner_storage_state = fx.InMemoryRunnerStorage.init(std.testing.allocator);
    defer runner_storage_state.deinit();
    var message_storage_state = fx.InMemoryMessageStorage.init(std.testing.allocator);
    defer message_storage_state.deinit();
    var journal_state = fx.workflow.InMemoryJournalStore.init(std.testing.allocator);
    defer journal_state.deinit();
    const journal_store = journal_state.asJournalStore();

    const owned_execution = try executionIdForShard(0, 8);
    const foreign_execution = try executionIdForShard(1, 8);
    _ = try journal_store.append(.{ .event = .{
        .sequence = 1,
        .kind = .workflow_started,
        .workflow_id = 7,
        .execution_id = owned_execution,
        .name = "owned",
        .status = "running",
        .idempotency_key = "owned-start",
    } });
    _ = try journal_store.append(.{ .event = .{
        .sequence = 2,
        .kind = .workflow_started,
        .workflow_id = 9,
        .execution_id = foreign_execution,
        .name = "foreign",
        .status = "running",
        .idempotency_key = "foreign-start",
    } });

    var runner = try fx.LocalClusterRunner.init(std.testing.allocator, .{
        .runner = fx.runnerAddress("machine-workflow", "runner-recovery"),
        .runner_storage = runner_storage_state.asRunnerStorage(),
        .message_storage = message_storage_state.asMessageStorage(),
        .shard_count = 8,
        .runner_index = 0,
        .runner_count = 1,
        .lease_options = .{ .ttl_ms = 1_000, .refresh_interval_ms = 250 },
    });
    defer runner.deinit();
    _ = try runner.runtime.acquireShard(0, 1_000);

    var registry = fx.ClusterWorkflowEntityRegistry.init(std.testing.allocator);
    defer registry.deinit();
    const report = try registry.recoverOwnedExecutions(&runner, journal_store, 1_000);

    try std.testing.expectEqual(@as(usize, 2), report.scanned);
    try std.testing.expectEqual(@as(usize, 1), report.registered);
    _ = try runner.entityScope(fx.clusterWorkflowExecutionAddress(owned_execution));
    try std.testing.expectError(error.EntityNotFound, runner.entityScope(fx.clusterWorkflowExecutionAddress(foreign_execution)));
}

fn executionIdForShard(shard_id: fx.ShardId, shard_count: fx.ShardCount) !fx.workflow.ExecutionId {
    var id: fx.workflow.ExecutionId = 1;
    while (id < 100_000) : (id += 1) {
        const address = fx.clusterWorkflowExecutionAddress(id);
        if (try fx.shardIdForAddress(address, shard_count) == shard_id) return id;
    }
    return error.ExecutionShardNotFound;
}
