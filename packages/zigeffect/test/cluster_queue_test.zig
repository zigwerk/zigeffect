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

test "cluster workflow claim queue appends durable claim through owning entity" {
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
    const queue_id = fx.workflow.queueItemId("email", "claim-1");
    try seedStarted(journal_store, workflow_id, execution_id, "approval", "claim-start");
    try seedQueueEvent(journal_store, .queue_offered, workflow_id, execution_id, queue_id, 2, "email", "42", "claim-offer", 0);

    var runner = try runnerOwningShard(runner_storage_state.asRunnerStorage(), message_storage, 0);
    defer runner.deinit();
    var registry = fx.ClusterWorkflowEntityRegistry.init(std.testing.allocator);
    defer registry.deinit();
    _ = try registry.registerExecution(&runner, journal_store, workflow_id, execution_id, 1_000);

    var transport_state = try fx.InProcessClusterTransport.init(std.testing.allocator, message_storage, .{ .shard_count = 8 });
    defer transport_state.deinit();
    var engine = fx.ClusterWorkflowEngine.init(std.testing.allocator, transport_state.asClusterTransport());
    defer engine.deinit();

    var submission = try engine.claimQueue(workflow_id, execution_id, "email", queue_id, "worker-a", 1_000, 250, 1);
    defer submission.deinit(std.testing.allocator);
    var result = try processWorkflowSubmission(&runner, message_storage, submission, 1_010);
    defer result.deinit(std.testing.allocator);
    try std.testing.expect(result.queue_claimed);
    try std.testing.expectEqual(queue_id, result.queue_id.?);
    try std.testing.expectEqual(@as(u32, 1), result.queue_attempt);

    var events = try journal_store.readAll(std.testing.allocator);
    defer events.deinit();
    try std.testing.expectEqual(fx.workflow.WorkflowEventKind.queue_claimed, events.events[2].kind);
    try std.testing.expectEqualStrings("worker=worker-a claim_deadline_ms=1250 attempt=1 lease_epoch=1", events.events[2].redacted_detail);
}

test "cluster workflow claim queue respects max concurrency" {
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
    const first_id = fx.workflow.queueItemId("email", "first");
    const second_id = fx.workflow.queueItemId("email", "second");
    try seedStarted(journal_store, workflow_id, execution_id, "approval", "concurrency-start");
    try seedQueueEvent(journal_store, .queue_offered, workflow_id, execution_id, first_id, 2, "email", "1", "first-offer", 0);
    try seedQueueEvent(journal_store, .queue_offered, workflow_id, execution_id, second_id, 3, "email", "2", "second-offer", 0);

    var runner = try runnerOwningShard(runner_storage_state.asRunnerStorage(), message_storage, 0);
    defer runner.deinit();
    var registry = fx.ClusterWorkflowEntityRegistry.init(std.testing.allocator);
    defer registry.deinit();
    _ = try registry.registerExecution(&runner, journal_store, workflow_id, execution_id, 1_000);

    var transport_state = try fx.InProcessClusterTransport.init(std.testing.allocator, message_storage, .{ .shard_count = 8 });
    defer transport_state.deinit();
    var engine = fx.ClusterWorkflowEngine.init(std.testing.allocator, transport_state.asClusterTransport());
    defer engine.deinit();

    var first = try engine.claimQueue(workflow_id, execution_id, "email", first_id, "worker-a", 1_000, null, 1);
    defer first.deinit(std.testing.allocator);
    var first_result = try processWorkflowSubmission(&runner, message_storage, first, 1_010);
    defer first_result.deinit(std.testing.allocator);
    try std.testing.expect(first_result.queue_claimed);

    var second = try engine.claimQueue(workflow_id, execution_id, "email", second_id, "worker-b", 1_020, null, 1);
    defer second.deinit(std.testing.allocator);
    var second_result = try processWorkflowSubmission(&runner, message_storage, second, 1_030);
    defer second_result.deinit(std.testing.allocator);
    try std.testing.expect(!second_result.queue_claimed);

    try std.testing.expectEqual(@as(usize, 1), try countEvents(journal_store, .queue_claimed));
}

test "cluster workflow retry expired queues appends retry rows through owning entity" {
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
    const queue_id = fx.workflow.queueItemId("email", "expired");
    try seedStarted(journal_store, workflow_id, execution_id, "approval", "retry-start");
    try seedQueueEvent(journal_store, .queue_offered, workflow_id, execution_id, queue_id, 2, "email", "42", "retry-offer", 0);
    try seedQueueEvent(journal_store, .queue_claimed, workflow_id, execution_id, queue_id, 3, "email", "worker=worker-a claim_deadline_ms=1250 attempt=1", "retry-claim", 1);

    var runner = try runnerOwningShard(runner_storage_state.asRunnerStorage(), message_storage, 0);
    defer runner.deinit();
    var registry = fx.ClusterWorkflowEntityRegistry.init(std.testing.allocator);
    defer registry.deinit();
    _ = try registry.registerExecution(&runner, journal_store, workflow_id, execution_id, 1_000);

    var transport_state = try fx.InProcessClusterTransport.init(std.testing.allocator, message_storage, .{ .shard_count = 8 });
    defer transport_state.deinit();
    var engine = fx.ClusterWorkflowEngine.init(std.testing.allocator, transport_state.asClusterTransport());
    defer engine.deinit();

    var submission = try engine.retryExpiredQueues(workflow_id, execution_id, "email", 1_500);
    defer submission.deinit(std.testing.allocator);
    var result = try processWorkflowSubmission(&runner, message_storage, submission, 1_500);
    defer result.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 1), result.queue_retried);

    var events = try journal_store.readAll(std.testing.allocator);
    defer events.deinit();
    try std.testing.expectEqual(fx.workflow.WorkflowEventKind.queue_retry_scheduled, events.events[3].kind);
    try std.testing.expectEqualStrings("claim_sequence=3 attempt=1 lease_epoch=1", events.events[3].redacted_detail);
}

test "queue worker crash returns claimed work to the cluster" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    var runner_storage_a = try fx.FileRunnerStorage.open(std.testing.allocator, std.testing.io, &tmp.dir, .{});
    defer runner_storage_a.deinit();
    var runner_storage_b = try fx.FileRunnerStorage.open(std.testing.allocator, std.testing.io, &tmp.dir, .{});
    defer runner_storage_b.deinit();
    var message_storage_a = try fx.FileMessageStorage.open(std.testing.allocator, std.testing.io, &tmp.dir, .{});
    defer message_storage_a.deinit();
    var message_storage_b = try fx.FileMessageStorage.open(std.testing.allocator, std.testing.io, &tmp.dir, .{});
    defer message_storage_b.deinit();
    var journal_state = try fx.workflow.FileJournalStore.open(std.testing.allocator, std.testing.io, &tmp.dir, .{});
    defer journal_state.deinit();
    const journal_store = journal_state.asJournalStore();

    var runner_a = try fx.LocalClusterRunner.init(std.testing.allocator, .{
        .runner = fx.runnerAddress("machine-queue", "runner-a"),
        .runner_storage = runner_storage_a.asRunnerStorage(),
        .message_storage = message_storage_a.asMessageStorage(),
        .shard_count = 8,
        .runner_index = 0,
        .runner_count = 1,
        .lease_options = .{ .ttl_ms = 1_000, .refresh_interval_ms = 250 },
    });
    defer runner_a.deinit();
    var plan_a = try runner_a.acquireBalancedShards(1_000);
    defer plan_a.deinit();

    var transport_state = try fx.InProcessClusterTransport.init(std.testing.allocator, message_storage_a.asMessageStorage(), .{ .shard_count = 8 });
    defer transport_state.deinit();
    var engine = fx.ClusterWorkflowEngine.init(std.testing.allocator, transport_state.asClusterTransport());
    defer engine.deinit();

    const workflow_id = fx.workflow.workflowId("approval");
    const execution_id = fx.workflow.executionId("approval", "queue-crash");
    const queue_id = fx.workflow.queueItemId("email", "crash-item");
    var registry_a = fx.ClusterWorkflowEntityRegistry.init(std.testing.allocator);
    defer registry_a.deinit();
    _ = try registry_a.registerExecution(&runner_a, journal_store, workflow_id, execution_id, 1_000);

    var started = try engine.start("approval", "queue-crash");
    defer started.deinit(std.testing.allocator);
    var start_result = try processWorkflowSubmission(&runner_a, message_storage_a.asMessageStorage(), started, 1_025);
    defer start_result.deinit(std.testing.allocator);
    try std.testing.expect(start_result.appended);

    var offered = try engine.appendEvent(.{
        .kind = .append_event,
        .event_kind = .queue_offered,
        .workflow_id = workflow_id,
        .execution_id = execution_id,
        .name = "email",
        .status = "offered",
        .redacted_detail = "42",
        .idempotency_key = "queue-crash-offered",
        .queue_id = queue_id,
    });
    defer offered.deinit(std.testing.allocator);
    var offer_result = try processWorkflowSubmission(&runner_a, message_storage_a.asMessageStorage(), offered, 1_050);
    defer offer_result.deinit(std.testing.allocator);
    try std.testing.expect(offer_result.appended);

    var suspended = try engine.appendEvent(.{
        .kind = .append_event,
        .event_kind = .workflow_suspended,
        .workflow_id = workflow_id,
        .execution_id = execution_id,
        .name = "email",
        .status = "waiting",
        .redacted_detail = "queue",
        .idempotency_key = "queue-crash-suspended",
        .queue_id = queue_id,
    });
    defer suspended.deinit(std.testing.allocator);
    var suspend_result = try processWorkflowSubmission(&runner_a, message_storage_a.asMessageStorage(), suspended, 1_075);
    defer suspend_result.deinit(std.testing.allocator);
    try std.testing.expect(suspend_result.appended);

    var claimed_a = try engine.claimQueue(workflow_id, execution_id, "email", queue_id, "worker-a", 1_100, 200, 1);
    defer claimed_a.deinit(std.testing.allocator);
    var claim_a_result = try processWorkflowSubmission(&runner_a, message_storage_a.asMessageStorage(), claimed_a, 1_100);
    defer claim_a_result.deinit(std.testing.allocator);
    try std.testing.expect(claim_a_result.queue_claimed);
    try std.testing.expectEqual(@as(u32, 1), claim_a_result.queue_attempt);

    _ = try runner_a.shutdown(1_150);

    var runner_b = try fx.LocalClusterRunner.init(std.testing.allocator, .{
        .runner = fx.runnerAddress("machine-queue", "runner-b"),
        .runner_storage = runner_storage_b.asRunnerStorage(),
        .message_storage = message_storage_b.asMessageStorage(),
        .shard_count = 8,
        .runner_index = 0,
        .runner_count = 1,
        .lease_options = .{ .ttl_ms = 1_000, .refresh_interval_ms = 250 },
    });
    defer runner_b.deinit();
    var plan_b = try runner_b.acquireBalancedShards(1_500);
    defer plan_b.deinit();

    var registry_b = fx.ClusterWorkflowEntityRegistry.init(std.testing.allocator);
    defer registry_b.deinit();
    const recovery = try registry_b.recoverOwnedExecutions(&runner_b, journal_store, 1_500);
    try std.testing.expectEqual(@as(usize, 1), recovery.scanned);
    try std.testing.expectEqual(@as(usize, 1), recovery.registered);

    var index = fx.ClusterQueueIndex.init(std.testing.allocator);
    defer index.deinit();
    _ = try index.rebuildOwned(&runner_b, journal_store);
    var expired = try index.expiredClaims(std.testing.allocator, 1_500);
    defer expired.deinit();
    try std.testing.expectEqual(@as(usize, 1), expired.items.len);
    try std.testing.expectEqual(queue_id, expired.items[0].queue_id);

    var retried = try engine.retryExpiredQueues(workflow_id, execution_id, "email", 1_500);
    defer retried.deinit(std.testing.allocator);
    var retry_result = try processWorkflowSubmission(&runner_b, message_storage_b.asMessageStorage(), retried, 1_500);
    defer retry_result.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 1), retry_result.queue_retried);

    _ = try index.rebuildOwned(&runner_b, journal_store);
    var claimable = try index.claimable(std.testing.allocator, .{ .max_per_runner = 1, .max_per_queue = 1 });
    defer claimable.deinit();
    try std.testing.expectEqual(@as(usize, 1), claimable.items.len);
    try std.testing.expectEqual(fx.ClusterQueueStatus.retry_ready, claimable.items[0].status);

    var claimed_b = try engine.claimQueue(workflow_id, execution_id, "email", queue_id, "worker-b", 1_525, 200, 1);
    defer claimed_b.deinit(std.testing.allocator);
    var claim_b_result = try processWorkflowSubmission(&runner_b, message_storage_b.asMessageStorage(), claimed_b, 1_525);
    defer claim_b_result.deinit(std.testing.allocator);
    try std.testing.expect(claim_b_result.queue_claimed);
    try std.testing.expectEqual(@as(u32, 2), claim_b_result.queue_attempt);

    var completed = try engine.completeQueue(workflow_id, execution_id, "email", queue_id, "done");
    defer completed.deinit(std.testing.allocator);
    var complete_result = try processWorkflowSubmission(&runner_b, message_storage_b.asMessageStorage(), completed, 1_550);
    defer complete_result.deinit(std.testing.allocator);
    try std.testing.expect(complete_result.appended);

    try std.testing.expectEqual(@as(usize, 1), try countEvents(journal_store, .queue_retry_scheduled));
    try std.testing.expectEqual(@as(usize, 2), try countEvents(journal_store, .queue_claimed));
    try std.testing.expectEqual(@as(usize, 1), try countEvents(journal_store, .queue_completed));
    try std.testing.expectEqual(@as(usize, 1), try countEvents(journal_store, .workflow_resumed));
    var state = try journal_store.latestState(std.testing.allocator);
    defer state.deinit();
    try std.testing.expectEqual(fx.workflow.WorkflowStatus.running, state.workflow_status);
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
