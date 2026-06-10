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
