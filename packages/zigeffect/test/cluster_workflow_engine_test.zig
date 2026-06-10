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

test "cluster workflow engine start stores workflow started through owning entity" {
    var runner_storage_state = fx.InMemoryRunnerStorage.init(std.testing.allocator);
    defer runner_storage_state.deinit();
    var message_storage_state = fx.InMemoryMessageStorage.init(std.testing.allocator);
    defer message_storage_state.deinit();
    const message_storage = message_storage_state.asMessageStorage();
    var journal_state = fx.workflow.InMemoryJournalStore.init(std.testing.allocator);
    defer journal_state.deinit();
    const journal_store = journal_state.asJournalStore();

    var runner = try workflowRunner(runner_storage_state.asRunnerStorage(), message_storage);
    defer runner.deinit();
    var plan = try runner.acquireBalancedShards(1_000);
    defer plan.deinit();

    var transport_state = try fx.InProcessClusterTransport.init(std.testing.allocator, message_storage, .{ .shard_count = 8 });
    defer transport_state.deinit();
    var engine = fx.ClusterWorkflowEngine.init(std.testing.allocator, transport_state.asClusterTransport());
    defer engine.deinit();

    const workflow_id = fx.workflow.workflowId("approval");
    const execution_id = fx.workflow.executionId("approval", "case-start");
    var registry = fx.ClusterWorkflowEntityRegistry.init(std.testing.allocator);
    defer registry.deinit();
    _ = try registry.registerExecution(&runner, journal_store, workflow_id, execution_id, 1_000);

    var submission = try engine.start("approval", "case-start");
    defer submission.deinit(std.testing.allocator);
    try std.testing.expectEqual(workflow_id, submission.workflow_id);
    try std.testing.expectEqual(execution_id, submission.execution_id);

    var result = try processWorkflowSubmission(&runner, message_storage, submission, 1_100);
    defer result.deinit(std.testing.allocator);
    try std.testing.expect(result.appended);
    try std.testing.expectEqual(@as(?fx.workflow.JournalSequence, 1), result.sequence);
    try std.testing.expectEqualStrings("running", result.status);

    var events = try journal_store.readAll(std.testing.allocator);
    defer events.deinit();
    try std.testing.expectEqual(@as(usize, 1), events.events.len);
    try std.testing.expectEqual(fx.workflow.WorkflowEventKind.workflow_started, events.events[0].kind);
    try std.testing.expectEqual(workflow_id, events.events[0].workflow_id);
    try std.testing.expectEqual(execution_id, events.events[0].execution_id);
}

test "cluster workflow complete appends completed through owning entity" {
    var runner_storage_state = fx.InMemoryRunnerStorage.init(std.testing.allocator);
    defer runner_storage_state.deinit();
    var message_storage_state = fx.InMemoryMessageStorage.init(std.testing.allocator);
    defer message_storage_state.deinit();
    const message_storage = message_storage_state.asMessageStorage();
    var journal_state = fx.workflow.InMemoryJournalStore.init(std.testing.allocator);
    defer journal_state.deinit();
    const journal_store = journal_state.asJournalStore();

    const workflow_id = fx.workflow.workflowId("approval");
    const execution_id = fx.workflow.executionId("approval", "case-complete");
    try seedStarted(journal_store, workflow_id, execution_id, "approval", "case-complete");

    var runner = try workflowRunner(runner_storage_state.asRunnerStorage(), message_storage);
    defer runner.deinit();
    var plan = try runner.acquireBalancedShards(1_000);
    defer plan.deinit();
    var registry = fx.ClusterWorkflowEntityRegistry.init(std.testing.allocator);
    defer registry.deinit();
    _ = try registry.registerExecution(&runner, journal_store, workflow_id, execution_id, 1_000);

    var transport_state = try fx.InProcessClusterTransport.init(std.testing.allocator, message_storage, .{ .shard_count = 8 });
    defer transport_state.deinit();
    var engine = fx.ClusterWorkflowEngine.init(std.testing.allocator, transport_state.asClusterTransport());
    defer engine.deinit();

    var submission = try engine.complete(workflow_id, execution_id, "value=approved");
    defer submission.deinit(std.testing.allocator);
    var result = try processWorkflowSubmission(&runner, message_storage, submission, 1_100);
    defer result.deinit(std.testing.allocator);
    try std.testing.expect(result.appended);
    try std.testing.expectEqualStrings("completed", result.status);

    var state = try journal_store.latestState(std.testing.allocator);
    defer state.deinit();
    try std.testing.expectEqual(fx.workflow.WorkflowStatus.completed, state.workflow_status);
}

test "cluster workflow lifecycle commands suspend resume interrupt and cancel" {
    try expectSuspendResumeLifecycle();
    try expectTerminalLifecycle(.interrupt);
    try expectTerminalLifecycle(.cancel);
}

fn executionIdForShard(shard_id: fx.ShardId, shard_count: fx.ShardCount) !fx.workflow.ExecutionId {
    var id: fx.workflow.ExecutionId = 1;
    while (id < 100_000) : (id += 1) {
        const address = fx.clusterWorkflowExecutionAddress(id);
        if (try fx.shardIdForAddress(address, shard_count) == shard_id) return id;
    }
    return error.ExecutionShardNotFound;
}

fn workflowRunner(runner_storage: fx.RunnerStorage, message_storage: fx.MessageStorage) !fx.LocalClusterRunner {
    return fx.LocalClusterRunner.init(std.testing.allocator, .{
        .runner = fx.runnerAddress("machine-workflow", "runner-command"),
        .runner_storage = runner_storage,
        .message_storage = message_storage,
        .shard_count = 8,
        .runner_index = 0,
        .runner_count = 1,
        .lease_options = .{ .ttl_ms = 1_000, .refresh_interval_ms = 250 },
    });
}

fn seedStarted(
    journal_store: fx.workflow.JournalStore,
    workflow_id: fx.workflow.WorkflowId,
    execution_id: fx.workflow.ExecutionId,
    workflow_name: []const u8,
    idempotency_key: []const u8,
) !void {
    _ = try journal_store.append(.{ .event = .{
        .sequence = 1,
        .kind = .workflow_started,
        .workflow_id = workflow_id,
        .execution_id = execution_id,
        .name = workflow_name,
        .status = "running",
        .idempotency_key = idempotency_key,
    } });
}

fn processWorkflowSubmission(
    runner: *fx.LocalClusterRunner,
    message_storage: fx.MessageStorage,
    submission: fx.ClusterWorkflowCommandSubmission,
    now_ms: u64,
) !fx.ClusterWorkflowCommandResult {
    const report = try runner.tick(fx.ClusterWorkflowEntityHandler, now_ms);
    try std.testing.expectEqual(@as(usize, 1), report.dispatched);
    try std.testing.expectEqual(@as(usize, 1), report.replied);
    try std.testing.expectEqual(@as(usize, 1), report.acked);

    const reply = (try message_storage.reply(submission.correlation_id, std.testing.allocator)).?;
    defer fx.deinitMessageEnvelope(std.testing.allocator, reply);
    return fx.parseClusterWorkflowCommandResultFromReply(std.testing.allocator, reply);
}

fn expectSuspendResumeLifecycle() !void {
    var runner_storage_state = fx.InMemoryRunnerStorage.init(std.testing.allocator);
    defer runner_storage_state.deinit();
    var message_storage_state = fx.InMemoryMessageStorage.init(std.testing.allocator);
    defer message_storage_state.deinit();
    const message_storage = message_storage_state.asMessageStorage();
    var journal_state = fx.workflow.InMemoryJournalStore.init(std.testing.allocator);
    defer journal_state.deinit();
    const journal_store = journal_state.asJournalStore();

    const workflow_id = fx.workflow.workflowId("approval");
    const execution_id = fx.workflow.executionId("approval", "case-suspend-resume");
    try seedStarted(journal_store, workflow_id, execution_id, "approval", "case-suspend-resume");

    var runner = try workflowRunner(runner_storage_state.asRunnerStorage(), message_storage);
    defer runner.deinit();
    var plan = try runner.acquireBalancedShards(1_000);
    defer plan.deinit();
    var registry = fx.ClusterWorkflowEntityRegistry.init(std.testing.allocator);
    defer registry.deinit();
    _ = try registry.registerExecution(&runner, journal_store, workflow_id, execution_id, 1_000);

    var transport_state = try fx.InProcessClusterTransport.init(std.testing.allocator, message_storage, .{ .shard_count = 8 });
    defer transport_state.deinit();
    var engine = fx.ClusterWorkflowEngine.init(std.testing.allocator, transport_state.asClusterTransport());
    defer engine.deinit();

    var suspend_submission = try engine.suspendWorkflow(workflow_id, execution_id, "waiting-for-review");
    defer suspend_submission.deinit(std.testing.allocator);
    var suspended = try processWorkflowSubmission(&runner, message_storage, suspend_submission, 1_100);
    defer suspended.deinit(std.testing.allocator);
    try std.testing.expectEqualStrings("suspended", suspended.status);

    var resume_submission = try engine.resumeWorkflow(workflow_id, execution_id, "review-ready");
    defer resume_submission.deinit(std.testing.allocator);
    var resumed = try processWorkflowSubmission(&runner, message_storage, resume_submission, 1_200);
    defer resumed.deinit(std.testing.allocator);
    try std.testing.expectEqualStrings("running", resumed.status);

    var events = try journal_store.readAll(std.testing.allocator);
    defer events.deinit();
    try std.testing.expectEqual(fx.workflow.WorkflowEventKind.workflow_suspended, events.events[1].kind);
    try std.testing.expectEqual(fx.workflow.WorkflowEventKind.workflow_resumed, events.events[2].kind);
}

fn expectTerminalLifecycle(kind: fx.ClusterWorkflowCommandKind) !void {
    var runner_storage_state = fx.InMemoryRunnerStorage.init(std.testing.allocator);
    defer runner_storage_state.deinit();
    var message_storage_state = fx.InMemoryMessageStorage.init(std.testing.allocator);
    defer message_storage_state.deinit();
    const message_storage = message_storage_state.asMessageStorage();
    var journal_state = fx.workflow.InMemoryJournalStore.init(std.testing.allocator);
    defer journal_state.deinit();
    const journal_store = journal_state.asJournalStore();

    const suffix = if (kind == .interrupt) "interrupt" else "cancel";
    const workflow_id = fx.workflow.workflowId("approval");
    const execution_id = fx.workflow.executionId("approval", suffix);
    try seedStarted(journal_store, workflow_id, execution_id, "approval", suffix);

    var runner = try workflowRunner(runner_storage_state.asRunnerStorage(), message_storage);
    defer runner.deinit();
    var plan = try runner.acquireBalancedShards(1_000);
    defer plan.deinit();
    var registry = fx.ClusterWorkflowEntityRegistry.init(std.testing.allocator);
    defer registry.deinit();
    _ = try registry.registerExecution(&runner, journal_store, workflow_id, execution_id, 1_000);

    var transport_state = try fx.InProcessClusterTransport.init(std.testing.allocator, message_storage, .{ .shard_count = 8 });
    defer transport_state.deinit();
    var engine = fx.ClusterWorkflowEngine.init(std.testing.allocator, transport_state.asClusterTransport());
    defer engine.deinit();

    var submission = switch (kind) {
        .interrupt => try engine.interrupt(workflow_id, execution_id, "operator"),
        .cancel => try engine.cancel(workflow_id, execution_id, "operator"),
        else => unreachable,
    };
    defer submission.deinit(std.testing.allocator);
    var result = try processWorkflowSubmission(&runner, message_storage, submission, 1_100);
    defer result.deinit(std.testing.allocator);

    var state = try journal_store.latestState(std.testing.allocator);
    defer state.deinit();
    switch (kind) {
        .interrupt => {
            try std.testing.expectEqualStrings("interrupted", result.status);
            try std.testing.expectEqual(fx.workflow.WorkflowStatus.interrupted, state.workflow_status);
        },
        .cancel => {
            try std.testing.expectEqualStrings("cancelled", result.status);
            try std.testing.expectEqual(fx.workflow.WorkflowStatus.cancelled, state.workflow_status);
        },
        else => unreachable,
    }
}
