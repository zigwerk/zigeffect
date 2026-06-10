const std = @import("std");
const fx = @import("zigeffect");

test "cluster timer wakeup public exports are available" {
    try std.testing.expect(@hasDecl(fx.cluster, "timer_wakeup"));
    try std.testing.expect(@hasDecl(fx.cluster, "ClusterTimerWakeup"));
    try std.testing.expect(@hasDecl(fx.cluster, "ClusterTimerWakeupBatch"));
    try std.testing.expect(@hasDecl(fx.cluster, "ClusterTimerWakeupReport"));
    try std.testing.expect(@hasDecl(fx.cluster, "ClusterTimerWakeupIndex"));
    try std.testing.expect(@hasDecl(fx, "ClusterTimerWakeupIndex"));
}

test "cluster timer wakeup rebuild indexes owned scheduled timers" {
    var runner_storage_state = fx.InMemoryRunnerStorage.init(std.testing.allocator);
    defer runner_storage_state.deinit();
    var message_storage_state = fx.InMemoryMessageStorage.init(std.testing.allocator);
    defer message_storage_state.deinit();
    var journal_state = fx.workflow.InMemoryJournalStore.init(std.testing.allocator);
    defer journal_state.deinit();
    const journal_store = journal_state.asJournalStore();

    const workflow_id = fx.workflow.workflowId("approval");
    const execution_id = try executionIdForShard(0, 8);
    const timer_id = fx.workflow.timerId("approval-timeout");
    try seedScheduledTimer(journal_store, workflow_id, execution_id, timer_id, 1, "approval-timeout", 1_000, "owned-timer");

    var runner = try runnerOwningShard(runner_storage_state.asRunnerStorage(), message_storage_state.asMessageStorage(), 0);
    defer runner.deinit();
    var index = fx.ClusterTimerWakeupIndex.init(std.testing.allocator);
    defer index.deinit();

    const report = try index.rebuildOwned(&runner, journal_store);
    try std.testing.expectEqual(@as(usize, 1), report.scanned);
    try std.testing.expectEqual(@as(usize, 1), report.indexed);
    try std.testing.expectEqual(@as(usize, 1), index.wakeups.items.len);
    try std.testing.expectEqual(workflow_id, index.wakeups.items[0].workflow_id);
    try std.testing.expectEqual(execution_id, index.wakeups.items[0].execution_id);
    try std.testing.expectEqual(timer_id, index.wakeups.items[0].timer_id);
    try std.testing.expectEqual(@as(fx.ShardId, 0), index.wakeups.items[0].shard_id);
    try std.testing.expectEqual(@as(u64, 1_000), index.wakeups.items[0].fire_at_ms);
    try std.testing.expectEqualStrings("approval-timeout", index.wakeups.items[0].name);
}

test "cluster timer wakeup rebuild skips unowned timers" {
    var runner_storage_state = fx.InMemoryRunnerStorage.init(std.testing.allocator);
    defer runner_storage_state.deinit();
    var message_storage_state = fx.InMemoryMessageStorage.init(std.testing.allocator);
    defer message_storage_state.deinit();
    var journal_state = fx.workflow.InMemoryJournalStore.init(std.testing.allocator);
    defer journal_state.deinit();
    const journal_store = journal_state.asJournalStore();

    const workflow_id = fx.workflow.workflowId("approval");
    const owned_execution = try executionIdForShard(0, 8);
    const foreign_execution = try executionIdForShard(1, 8);
    try seedScheduledTimer(journal_store, workflow_id, owned_execution, fx.workflow.timerId("owned-timeout"), 1, "owned-timeout", 1_000, "owned-timer");
    try seedScheduledTimer(journal_store, workflow_id, foreign_execution, fx.workflow.timerId("foreign-timeout"), 2, "foreign-timeout", 1_000, "foreign-timer");

    var runner = try runnerOwningShard(runner_storage_state.asRunnerStorage(), message_storage_state.asMessageStorage(), 0);
    defer runner.deinit();
    var index = fx.ClusterTimerWakeupIndex.init(std.testing.allocator);
    defer index.deinit();

    const report = try index.rebuildOwned(&runner, journal_store);
    try std.testing.expectEqual(@as(usize, 2), report.scanned);
    try std.testing.expectEqual(@as(usize, 1), report.indexed);
    try std.testing.expectEqual(@as(usize, 1), report.skipped_unowned);
    try std.testing.expectEqual(@as(usize, 1), index.wakeups.items.len);
    try std.testing.expectEqual(owned_execution, index.wakeups.items[0].execution_id);
}

test "cluster timer wakeup rebuild skips terminal timers" {
    var runner_storage_state = fx.InMemoryRunnerStorage.init(std.testing.allocator);
    defer runner_storage_state.deinit();
    var message_storage_state = fx.InMemoryMessageStorage.init(std.testing.allocator);
    defer message_storage_state.deinit();
    var journal_state = fx.workflow.InMemoryJournalStore.init(std.testing.allocator);
    defer journal_state.deinit();
    const journal_store = journal_state.asJournalStore();

    const workflow_id = fx.workflow.workflowId("approval");
    const execution_id = try executionIdForShard(0, 8);
    const timer_id = fx.workflow.timerId("approval-timeout");
    try seedScheduledTimer(journal_store, workflow_id, execution_id, timer_id, 1, "approval-timeout", 1_000, "timer-scheduled");
    try seedTimerTerminal(journal_store, .timer_fired, workflow_id, execution_id, timer_id, 2, "approval-timeout", "timer-fired");

    var runner = try runnerOwningShard(runner_storage_state.asRunnerStorage(), message_storage_state.asMessageStorage(), 0);
    defer runner.deinit();
    var index = fx.ClusterTimerWakeupIndex.init(std.testing.allocator);
    defer index.deinit();

    const report = try index.rebuildOwned(&runner, journal_store);
    try std.testing.expectEqual(@as(usize, 1), report.scanned);
    try std.testing.expectEqual(@as(usize, 0), report.indexed);
    try std.testing.expectEqual(@as(usize, 1), report.skipped_terminal);
    try std.testing.expectEqual(@as(usize, 0), index.wakeups.items.len);
}

test "cluster timer wakeup rebuild collapses duplicate schedules" {
    var runner_storage_state = fx.InMemoryRunnerStorage.init(std.testing.allocator);
    defer runner_storage_state.deinit();
    var message_storage_state = fx.InMemoryMessageStorage.init(std.testing.allocator);
    defer message_storage_state.deinit();
    var journal_state = fx.workflow.InMemoryJournalStore.init(std.testing.allocator);
    defer journal_state.deinit();
    const journal_store = journal_state.asJournalStore();

    const workflow_id = fx.workflow.workflowId("approval");
    const execution_id = try executionIdForShard(0, 8);
    const timer_id = fx.workflow.timerId("approval-timeout");
    try seedScheduledTimer(journal_store, workflow_id, execution_id, timer_id, 1, "approval-timeout", 1_000, "timer-scheduled-1");
    try seedScheduledTimer(journal_store, workflow_id, execution_id, timer_id, 2, "approval-timeout", 1_000, "timer-scheduled-2");

    var runner = try runnerOwningShard(runner_storage_state.asRunnerStorage(), message_storage_state.asMessageStorage(), 0);
    defer runner.deinit();
    var index = fx.ClusterTimerWakeupIndex.init(std.testing.allocator);
    defer index.deinit();

    const report = try index.rebuildOwned(&runner, journal_store);
    try std.testing.expectEqual(@as(usize, 2), report.scanned);
    try std.testing.expectEqual(@as(usize, 1), report.indexed);
    try std.testing.expectEqual(@as(usize, 1), report.skipped_duplicate);
    try std.testing.expectEqual(@as(usize, 1), index.wakeups.items.len);
}

test "cluster timer wakeup due filters future timers" {
    var runner_storage_state = fx.InMemoryRunnerStorage.init(std.testing.allocator);
    defer runner_storage_state.deinit();
    var message_storage_state = fx.InMemoryMessageStorage.init(std.testing.allocator);
    defer message_storage_state.deinit();
    var journal_state = fx.workflow.InMemoryJournalStore.init(std.testing.allocator);
    defer journal_state.deinit();
    const journal_store = journal_state.asJournalStore();

    const workflow_id = fx.workflow.workflowId("approval");
    const execution_id = try executionIdForShard(0, 8);
    try seedScheduledTimer(journal_store, workflow_id, execution_id, fx.workflow.timerId("due-timeout"), 1, "due-timeout", 1_000, "due-timer");
    try seedScheduledTimer(journal_store, workflow_id, execution_id, fx.workflow.timerId("future-timeout"), 2, "future-timeout", 2_000, "future-timer");

    var runner = try runnerOwningShard(runner_storage_state.asRunnerStorage(), message_storage_state.asMessageStorage(), 0);
    defer runner.deinit();
    var index = fx.ClusterTimerWakeupIndex.init(std.testing.allocator);
    defer index.deinit();
    _ = try index.rebuildOwned(&runner, journal_store);

    var due = try index.due(std.testing.allocator, 1_500);
    defer due.deinit();
    try std.testing.expectEqual(@as(usize, 1), due.wakeups.len);
    try std.testing.expectEqualStrings("due-timeout", due.wakeups[0].name);
    try std.testing.expectEqual(@as(u64, 1_000), due.wakeups[0].fire_at_ms);
}

test "cluster timer wakeup due reports late timers" {
    var runner_storage_state = fx.InMemoryRunnerStorage.init(std.testing.allocator);
    defer runner_storage_state.deinit();
    var message_storage_state = fx.InMemoryMessageStorage.init(std.testing.allocator);
    defer message_storage_state.deinit();
    var journal_state = fx.workflow.InMemoryJournalStore.init(std.testing.allocator);
    defer journal_state.deinit();
    const journal_store = journal_state.asJournalStore();

    const workflow_id = fx.workflow.workflowId("approval");
    const execution_id = try executionIdForShard(0, 8);
    try seedScheduledTimer(journal_store, workflow_id, execution_id, fx.workflow.timerId("approval-timeout"), 1, "approval-timeout", 1_000, "timer");

    var runner = try runnerOwningShard(runner_storage_state.asRunnerStorage(), message_storage_state.asMessageStorage(), 0);
    defer runner.deinit();
    var index = fx.ClusterTimerWakeupIndex.init(std.testing.allocator);
    defer index.deinit();
    _ = try index.rebuildOwned(&runner, journal_store);

    var due = try index.due(std.testing.allocator, 1_500);
    defer due.deinit();
    try std.testing.expectEqual(@as(usize, 1), due.wakeups.len);
    try std.testing.expectEqual(@as(u64, 500), due.wakeups[0].late_by_ms);
}

test "cluster timer wakeup firing is idempotent through workflow entity" {
    var runner_storage_state = fx.InMemoryRunnerStorage.init(std.testing.allocator);
    defer runner_storage_state.deinit();
    var message_storage_state = fx.InMemoryMessageStorage.init(std.testing.allocator);
    defer message_storage_state.deinit();
    const message_storage = message_storage_state.asMessageStorage();
    var journal_state = fx.workflow.InMemoryJournalStore.init(std.testing.allocator);
    defer journal_state.deinit();
    const journal_store = journal_state.asJournalStore();

    const workflow_id = fx.workflow.workflowId("approval");
    const execution_id = try executionIdForShard(0, 8);
    const timer_id = fx.workflow.timerId("approval-timeout");
    try seedStarted(journal_store, workflow_id, execution_id, "approval", "start");
    try seedScheduledTimer(journal_store, workflow_id, execution_id, timer_id, 2, "approval-timeout", 1_000, "timer-scheduled");
    try seedTimerSuspension(journal_store, workflow_id, execution_id, timer_id, 3, "approval-timeout", "timer-suspended");

    var runner = try runnerOwningShard(runner_storage_state.asRunnerStorage(), message_storage, 0);
    defer runner.deinit();
    var registry = fx.ClusterWorkflowEntityRegistry.init(std.testing.allocator);
    defer registry.deinit();
    _ = try registry.registerExecution(&runner, journal_store, workflow_id, execution_id, 1_000);

    var index = fx.ClusterTimerWakeupIndex.init(std.testing.allocator);
    defer index.deinit();
    _ = try index.rebuildOwned(&runner, journal_store);
    var due = try index.due(std.testing.allocator, 1_500);
    defer due.deinit();
    try std.testing.expectEqual(@as(usize, 1), due.wakeups.len);

    var transport_state = try fx.InProcessClusterTransport.init(std.testing.allocator, message_storage, .{ .shard_count = 8 });
    defer transport_state.deinit();
    var engine = fx.ClusterWorkflowEngine.init(std.testing.allocator, transport_state.asClusterTransport());
    defer engine.deinit();

    var first = try engine.fireDueTimers(workflow_id, execution_id, 1_500);
    defer first.deinit(std.testing.allocator);
    var first_result = try processWorkflowSubmission(&runner, message_storage, first, 1_500);
    defer first_result.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 1), first_result.timers_fired);

    var second = try engine.fireDueTimers(workflow_id, execution_id, 1_500);
    defer second.deinit(std.testing.allocator);
    var second_result = try processWorkflowSubmission(&runner, message_storage, second, 1_600);
    defer second_result.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 0), second_result.timers_fired);

    try std.testing.expectEqual(@as(usize, 1), try countEvents(journal_store, .timer_fired));
    try std.testing.expectEqual(@as(usize, 1), try countEvents(journal_store, .workflow_resumed));
}

fn executionIdForShard(shard_id: fx.ShardId, shard_count: fx.ShardCount) !fx.workflow.ExecutionId {
    var id: fx.workflow.ExecutionId = 1;
    while (id < 100_000) : (id += 1) {
        const address = fx.clusterWorkflowExecutionAddress(id);
        if (try fx.shardIdForAddress(address, shard_count) == shard_id) return id;
    }
    return error.ExecutionShardNotFound;
}

fn runnerOwningShard(
    runner_storage: fx.RunnerStorage,
    message_storage: fx.MessageStorage,
    shard_id: fx.ShardId,
) !fx.LocalClusterRunner {
    var runner = try fx.LocalClusterRunner.init(std.testing.allocator, .{
        .runner = fx.runnerAddress("machine-timer", "runner-timer"),
        .runner_storage = runner_storage,
        .message_storage = message_storage,
        .shard_count = 8,
        .runner_index = 0,
        .runner_count = 1,
        .lease_options = .{ .ttl_ms = 1_000, .refresh_interval_ms = 250 },
    });
    errdefer runner.deinit();
    _ = try runner.runtime.acquireShard(shard_id, 1_000);
    return runner;
}

fn seedScheduledTimer(
    journal_store: fx.workflow.JournalStore,
    workflow_id: fx.workflow.WorkflowId,
    execution_id: fx.workflow.ExecutionId,
    timer_id: fx.workflow.TimerId,
    sequence: fx.workflow.JournalSequence,
    name: []const u8,
    fire_at_ms: u64,
    idempotency_key: []const u8,
) !void {
    const detail = try std.fmt.allocPrint(std.testing.allocator, "fire_at_ms={d}", .{fire_at_ms});
    defer std.testing.allocator.free(detail);
    _ = try journal_store.append(.{ .event = .{
        .sequence = sequence,
        .kind = .timer_scheduled,
        .workflow_id = workflow_id,
        .execution_id = execution_id,
        .timer_id = timer_id,
        .name = name,
        .status = "scheduled",
        .redacted_detail = detail,
        .idempotency_key = idempotency_key,
    } });
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

fn seedTimerSuspension(
    journal_store: fx.workflow.JournalStore,
    workflow_id: fx.workflow.WorkflowId,
    execution_id: fx.workflow.ExecutionId,
    timer_id: fx.workflow.TimerId,
    sequence: fx.workflow.JournalSequence,
    name: []const u8,
    idempotency_key: []const u8,
) !void {
    _ = try journal_store.append(.{ .event = .{
        .sequence = sequence,
        .kind = .workflow_suspended,
        .workflow_id = workflow_id,
        .execution_id = execution_id,
        .timer_id = timer_id,
        .name = name,
        .status = "waiting",
        .redacted_detail = "timer",
        .idempotency_key = idempotency_key,
    } });
}

fn seedTimerTerminal(
    journal_store: fx.workflow.JournalStore,
    kind: fx.workflow.WorkflowEventKind,
    workflow_id: fx.workflow.WorkflowId,
    execution_id: fx.workflow.ExecutionId,
    timer_id: fx.workflow.TimerId,
    sequence: fx.workflow.JournalSequence,
    name: []const u8,
    idempotency_key: []const u8,
) !void {
    _ = try journal_store.append(.{ .event = .{
        .sequence = sequence,
        .kind = kind,
        .workflow_id = workflow_id,
        .execution_id = execution_id,
        .timer_id = timer_id,
        .name = name,
        .status = "terminal",
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

fn countEvents(
    journal_store: fx.workflow.JournalStore,
    kind: fx.workflow.WorkflowEventKind,
) !usize {
    var events = try journal_store.readAll(std.testing.allocator);
    defer events.deinit();

    var count: usize = 0;
    for (events.events) |event| {
        if (event.kind == kind) count += 1;
    }
    return count;
}
