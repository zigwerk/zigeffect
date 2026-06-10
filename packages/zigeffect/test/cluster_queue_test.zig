const std = @import("std");
const fx = @import("zigeffect");

test "cluster queue public exports are available" {
    try std.testing.expect(@hasDecl(fx.cluster, "queue"));
    try std.testing.expect(@hasDecl(fx.cluster, "ClusterQueueStatus"));
    try std.testing.expect(@hasDecl(fx.cluster, "ClusterQueueItem"));
    try std.testing.expect(@hasDecl(fx.cluster, "ClusterQueueBatch"));
    try std.testing.expect(@hasDecl(fx.cluster, "ClusterQueueRebuildReport"));
    try std.testing.expect(@hasDecl(fx.cluster, "ClusterQueueClaimLimits"));
    try std.testing.expect(@hasDecl(fx.cluster, "ClusterQueueIndex"));
    try std.testing.expect(@hasDecl(fx, "ClusterQueueIndex"));
}

test "cluster queue rebuild indexes owned offered work" {
    var runner_storage_state = fx.InMemoryRunnerStorage.init(std.testing.allocator);
    defer runner_storage_state.deinit();
    var message_storage_state = fx.InMemoryMessageStorage.init(std.testing.allocator);
    defer message_storage_state.deinit();
    var journal_state = fx.workflow.InMemoryJournalStore.init(std.testing.allocator);
    defer journal_state.deinit();
    const journal_store = journal_state.asJournalStore();

    const workflow_id = fx.workflow.workflowId("approval");
    const execution_id = try executionIdForShard(0, 8);
    const queue_id = fx.workflow.queueItemId("email", "item-1");
    try seedQueueEvent(journal_store, .queue_offered, workflow_id, execution_id, queue_id, 1, "email", "42", "queue-offer-1", 0);

    var runner = try runnerOwningShard(runner_storage_state.asRunnerStorage(), message_storage_state.asMessageStorage(), 0);
    defer runner.deinit();
    var index = fx.ClusterQueueIndex.init(std.testing.allocator);
    defer index.deinit();

    const report = try index.rebuildOwned(&runner, journal_store);
    try std.testing.expectEqual(@as(usize, 1), report.scanned);
    try std.testing.expectEqual(@as(usize, 1), report.indexed);
    try std.testing.expectEqual(@as(usize, 1), index.items.items.len);
    try std.testing.expectEqual(workflow_id, index.items.items[0].workflow_id);
    try std.testing.expectEqual(execution_id, index.items.items[0].execution_id);
    try std.testing.expectEqual(queue_id, index.items.items[0].queue_id);
    try std.testing.expectEqual(@as(fx.ShardId, 0), index.items.items[0].shard_id);
    try std.testing.expectEqual(fx.ClusterQueueStatus.offered, index.items.items[0].status);
    try std.testing.expectEqualStrings("email", index.items.items[0].name);
    try std.testing.expectEqualStrings("42", index.items.items[0].payload);
}

test "cluster queue rebuild skips unowned work" {
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
    const owned_id = fx.workflow.queueItemId("email", "owned");
    const foreign_id = fx.workflow.queueItemId("email", "foreign");
    try seedQueueEvent(journal_store, .queue_offered, workflow_id, owned_execution, owned_id, 1, "email", "42", "owned", 0);
    try seedQueueEvent(journal_store, .queue_offered, workflow_id, foreign_execution, foreign_id, 2, "email", "43", "foreign", 0);

    var runner = try runnerOwningShard(runner_storage_state.asRunnerStorage(), message_storage_state.asMessageStorage(), 0);
    defer runner.deinit();
    var index = fx.ClusterQueueIndex.init(std.testing.allocator);
    defer index.deinit();

    const report = try index.rebuildOwned(&runner, journal_store);
    try std.testing.expectEqual(@as(usize, 2), report.scanned);
    try std.testing.expectEqual(@as(usize, 1), report.indexed);
    try std.testing.expectEqual(@as(usize, 1), report.skipped_unowned);
    try std.testing.expectEqual(@as(usize, 1), index.items.items.len);
    try std.testing.expectEqual(owned_id, index.items.items[0].queue_id);
}

test "cluster queue rebuild tracks latest status by sequence" {
    var runner_storage_state = fx.InMemoryRunnerStorage.init(std.testing.allocator);
    defer runner_storage_state.deinit();
    var message_storage_state = fx.InMemoryMessageStorage.init(std.testing.allocator);
    defer message_storage_state.deinit();
    var journal_state = fx.workflow.InMemoryJournalStore.init(std.testing.allocator);
    defer journal_state.deinit();
    const journal_store = journal_state.asJournalStore();

    const workflow_id = fx.workflow.workflowId("approval");
    const execution_id = try executionIdForShard(0, 8);
    const offered_id = fx.workflow.queueItemId("email", "offered");
    const claimed_id = fx.workflow.queueItemId("email", "claimed");
    const retry_id = fx.workflow.queueItemId("email", "retry");
    const completed_id = fx.workflow.queueItemId("email", "completed");
    const failed_id = fx.workflow.queueItemId("email", "failed");
    const acked_id = fx.workflow.queueItemId("email", "acked");

    try seedQueueEvent(journal_store, .queue_offered, workflow_id, execution_id, offered_id, 1, "email", "1", "offered", 0);
    try seedQueueEvent(journal_store, .queue_offered, workflow_id, execution_id, claimed_id, 2, "email", "2", "claimed-offer", 0);
    try seedQueueEvent(journal_store, .queue_claimed, workflow_id, execution_id, claimed_id, 3, "email", "worker=worker-a claim_deadline_ms=1250 attempt=1", "claimed", 1);
    try seedQueueEvent(journal_store, .queue_offered, workflow_id, execution_id, retry_id, 4, "email", "3", "retry-offer", 0);
    try seedQueueEvent(journal_store, .queue_claimed, workflow_id, execution_id, retry_id, 5, "email", "worker=worker-a claim_deadline_ms=1250 attempt=1", "retry-claim", 1);
    try seedQueueEvent(journal_store, .queue_retry_scheduled, workflow_id, execution_id, retry_id, 6, "email", "claim_sequence=5 attempt=1", "retry-ready", 1);
    try seedQueueEvent(journal_store, .queue_offered, workflow_id, execution_id, completed_id, 7, "email", "4", "completed-offer", 0);
    try seedQueueEvent(journal_store, .queue_completed, workflow_id, execution_id, completed_id, 8, "email", "done", "completed", 0);
    try seedQueueEvent(journal_store, .queue_offered, workflow_id, execution_id, failed_id, 9, "email", "5", "failed-offer", 0);
    try seedQueueEvent(journal_store, .queue_failed, workflow_id, execution_id, failed_id, 10, "email", "failed", "failed", 0);
    try seedQueueEvent(journal_store, .queue_offered, workflow_id, execution_id, acked_id, 11, "email", "6", "acked-offer", 0);
    try seedQueueEvent(journal_store, .queue_acked, workflow_id, execution_id, acked_id, 12, "email", "", "acked", 0);

    var runner = try runnerOwningShard(runner_storage_state.asRunnerStorage(), message_storage_state.asMessageStorage(), 0);
    defer runner.deinit();
    var index = fx.ClusterQueueIndex.init(std.testing.allocator);
    defer index.deinit();

    _ = try index.rebuildOwned(&runner, journal_store);
    try expectQueueStatus(&index, offered_id, .offered);
    try expectQueueStatus(&index, claimed_id, .claimed);
    try expectQueueStatus(&index, retry_id, .retry_ready);
    try expectQueueStatus(&index, completed_id, .completed);
    try expectQueueStatus(&index, failed_id, .failed);
    try expectQueueStatus(&index, acked_id, .acked);
}

test "cluster queue rebuild parses claim metadata" {
    var runner_storage_state = fx.InMemoryRunnerStorage.init(std.testing.allocator);
    defer runner_storage_state.deinit();
    var message_storage_state = fx.InMemoryMessageStorage.init(std.testing.allocator);
    defer message_storage_state.deinit();
    var journal_state = fx.workflow.InMemoryJournalStore.init(std.testing.allocator);
    defer journal_state.deinit();
    const journal_store = journal_state.asJournalStore();

    const workflow_id = fx.workflow.workflowId("approval");
    const execution_id = try executionIdForShard(0, 8);
    const queue_id = fx.workflow.queueItemId("email", "claimed");
    try seedQueueEvent(journal_store, .queue_offered, workflow_id, execution_id, queue_id, 1, "email", "42", "offer", 0);
    try seedQueueEvent(journal_store, .queue_claimed, workflow_id, execution_id, queue_id, 2, "email", "worker=worker-a claim_deadline_ms=1250 attempt=3", "claim", 3);

    var runner = try runnerOwningShard(runner_storage_state.asRunnerStorage(), message_storage_state.asMessageStorage(), 0);
    defer runner.deinit();
    var index = fx.ClusterQueueIndex.init(std.testing.allocator);
    defer index.deinit();

    _ = try index.rebuildOwned(&runner, journal_store);
    const item = (try queueItem(&index, queue_id)).?;
    try std.testing.expectEqual(fx.ClusterQueueStatus.claimed, item.status);
    try std.testing.expectEqual(@as(u32, 3), item.attempt);
    try std.testing.expectEqual(@as(?u64, 1_250), item.claim_deadline_ms);
    try std.testing.expectEqual(@as(?fx.workflow.JournalSequence, 2), item.claim_sequence);
    try std.testing.expectEqualStrings("worker-a", item.claim_worker);
}

test "cluster queue claimable respects runner and queue limits" {
    var runner_storage_state = fx.InMemoryRunnerStorage.init(std.testing.allocator);
    defer runner_storage_state.deinit();
    var message_storage_state = fx.InMemoryMessageStorage.init(std.testing.allocator);
    defer message_storage_state.deinit();
    var journal_state = fx.workflow.InMemoryJournalStore.init(std.testing.allocator);
    defer journal_state.deinit();
    const journal_store = journal_state.asJournalStore();

    const workflow_id = fx.workflow.workflowId("approval");
    const execution_id = try executionIdForShard(0, 8);
    const email_1 = fx.workflow.queueItemId("email", "1");
    const email_2 = fx.workflow.queueItemId("email", "2");
    const sms_1 = fx.workflow.queueItemId("sms", "1");
    try seedQueueEvent(journal_store, .queue_offered, workflow_id, execution_id, email_1, 1, "email", "1", "email-1", 0);
    try seedQueueEvent(journal_store, .queue_offered, workflow_id, execution_id, email_2, 2, "email", "2", "email-2", 0);
    try seedQueueEvent(journal_store, .queue_offered, workflow_id, execution_id, sms_1, 3, "sms", "3", "sms-1", 0);

    var runner = try runnerOwningShard(runner_storage_state.asRunnerStorage(), message_storage_state.asMessageStorage(), 0);
    defer runner.deinit();
    var index = fx.ClusterQueueIndex.init(std.testing.allocator);
    defer index.deinit();
    _ = try index.rebuildOwned(&runner, journal_store);

    var claimable = try index.claimable(std.testing.allocator, .{ .max_per_runner = 2, .max_per_queue = 1 });
    defer claimable.deinit();
    try std.testing.expectEqual(@as(usize, 2), claimable.items.len);
    try std.testing.expectEqual(email_1, claimable.items[0].queue_id);
    try std.testing.expectEqual(sms_1, claimable.items[1].queue_id);
}

test "cluster queue expired claims require passed deadlines" {
    var runner_storage_state = fx.InMemoryRunnerStorage.init(std.testing.allocator);
    defer runner_storage_state.deinit();
    var message_storage_state = fx.InMemoryMessageStorage.init(std.testing.allocator);
    defer message_storage_state.deinit();
    var journal_state = fx.workflow.InMemoryJournalStore.init(std.testing.allocator);
    defer journal_state.deinit();
    const journal_store = journal_state.asJournalStore();

    const workflow_id = fx.workflow.workflowId("approval");
    const execution_id = try executionIdForShard(0, 8);
    const expired_id = fx.workflow.queueItemId("email", "expired");
    const future_id = fx.workflow.queueItemId("email", "future");
    const no_deadline_id = fx.workflow.queueItemId("email", "no-deadline");
    try seedClaimedQueue(journal_store, workflow_id, execution_id, expired_id, 1, "expired", "worker-a", "1250");
    try seedClaimedQueue(journal_store, workflow_id, execution_id, future_id, 3, "future", "worker-b", "2000");
    try seedClaimedQueue(journal_store, workflow_id, execution_id, no_deadline_id, 5, "no-deadline", "worker-c", "null");

    var runner = try runnerOwningShard(runner_storage_state.asRunnerStorage(), message_storage_state.asMessageStorage(), 0);
    defer runner.deinit();
    var index = fx.ClusterQueueIndex.init(std.testing.allocator);
    defer index.deinit();
    _ = try index.rebuildOwned(&runner, journal_store);

    var expired = try index.expiredClaims(std.testing.allocator, 1_500);
    defer expired.deinit();
    try std.testing.expectEqual(@as(usize, 1), expired.items.len);
    try std.testing.expectEqual(expired_id, expired.items[0].queue_id);
    try std.testing.expectEqual(@as(?u64, 1_250), expired.items[0].claim_deadline_ms);
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
        .runner = fx.runnerAddress("machine-queue", "runner-queue"),
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

fn seedQueueEvent(
    journal_store: fx.workflow.JournalStore,
    kind: fx.workflow.WorkflowEventKind,
    workflow_id: fx.workflow.WorkflowId,
    execution_id: fx.workflow.ExecutionId,
    queue_id: fx.workflow.QueueId,
    sequence: fx.workflow.JournalSequence,
    name: []const u8,
    detail: []const u8,
    idempotency_key: []const u8,
    attempt: u32,
) !void {
    _ = try journal_store.append(.{ .event = .{
        .sequence = sequence,
        .kind = kind,
        .workflow_id = workflow_id,
        .execution_id = execution_id,
        .queue_id = queue_id,
        .attempt = attempt,
        .name = name,
        .status = @tagName(kind),
        .redacted_detail = detail,
        .idempotency_key = idempotency_key,
    } });
}

fn seedClaimedQueue(
    journal_store: fx.workflow.JournalStore,
    workflow_id: fx.workflow.WorkflowId,
    execution_id: fx.workflow.ExecutionId,
    queue_id: fx.workflow.QueueId,
    first_sequence: fx.workflow.JournalSequence,
    key: []const u8,
    worker: []const u8,
    deadline: []const u8,
) !void {
    const offer_key = try std.fmt.allocPrint(std.testing.allocator, "{s}-offer", .{key});
    defer std.testing.allocator.free(offer_key);
    try seedQueueEvent(journal_store, .queue_offered, workflow_id, execution_id, queue_id, first_sequence, "email", key, offer_key, 0);

    const claim_key = try std.fmt.allocPrint(std.testing.allocator, "{s}-claim", .{key});
    defer std.testing.allocator.free(claim_key);
    const detail = try std.fmt.allocPrint(std.testing.allocator, "worker={s} claim_deadline_ms={s} attempt=1", .{ worker, deadline });
    defer std.testing.allocator.free(detail);
    try seedQueueEvent(journal_store, .queue_claimed, workflow_id, execution_id, queue_id, first_sequence + 1, "email", detail, claim_key, 1);
}

fn queueItem(index: *const fx.ClusterQueueIndex, queue_id: fx.workflow.QueueId) !?fx.ClusterQueueItem {
    for (index.items.items) |item| {
        if (item.queue_id == queue_id) return item;
    }
    return null;
}

fn expectQueueStatus(
    index: *const fx.ClusterQueueIndex,
    queue_id: fx.workflow.QueueId,
    status: fx.ClusterQueueStatus,
) !void {
    const item = (try queueItem(index, queue_id)).?;
    try std.testing.expectEqual(status, item.status);
}
