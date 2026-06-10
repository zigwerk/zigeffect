const std = @import("std");
const fx = @import("zigeffect");

test "cluster fencing public exports are available" {
    try std.testing.expect(@hasDecl(fx.cluster, "fencing"));
    try std.testing.expect(@hasDecl(fx.cluster, "ShardLeaseEpoch"));
    try std.testing.expect(@hasDecl(fx.cluster, "ShardLeaseFence"));
    try std.testing.expect(@hasDecl(fx.cluster, "FenceValidationError"));
    try std.testing.expect(@hasDecl(fx.cluster, "fenceFromLease"));
    try std.testing.expect(@hasDecl(fx.cluster, "validateShardFence"));
    try std.testing.expect(@hasDecl(fx.cluster, "formatShardFenceDiagnostic"));
    try std.testing.expect(@hasDecl(fx, "ShardLeaseFence"));
}

test "shard lease epoch is stable across refresh and increments on reacquire" {
    var storage = fx.InMemoryRunnerStorage.init(std.testing.allocator);
    defer storage.deinit();
    const runner_storage = storage.asRunnerStorage();
    const runner_a = fx.runnerAddress("machine", "runner-a");
    const runner_b = fx.runnerAddress("machine", "runner-b");

    const acquired = try runner_storage.acquire(.{
        .shard_id = 0,
        .owner = runner_a,
        .now_ms = 1_000,
        .ttl_ms = 100,
    });
    try std.testing.expectEqual(@as(fx.ShardLeaseEpoch, 1), acquired.epoch);
    try std.testing.expectEqual(@as(u64, 1), acquired.version);

    const refreshed = try runner_storage.refresh(.{
        .shard_id = 0,
        .owner = runner_a,
        .now_ms = 1_050,
        .ttl_ms = 100,
    });
    try std.testing.expectEqual(@as(fx.ShardLeaseEpoch, 1), refreshed.epoch);
    try std.testing.expectEqual(@as(u64, 2), refreshed.version);

    const reacquired = try runner_storage.acquire(.{
        .shard_id = 0,
        .owner = runner_b,
        .now_ms = 1_150,
        .ttl_ms = 100,
    });
    try std.testing.expectEqual(@as(fx.ShardLeaseEpoch, 2), reacquired.epoch);
    try std.testing.expectEqual(@as(u64, 3), reacquired.version);
}

test "shard fence validation accepts current lease and rejects stale epoch" {
    var storage = fx.InMemoryRunnerStorage.init(std.testing.allocator);
    defer storage.deinit();
    const runner_storage = storage.asRunnerStorage();
    const runner_a = fx.runnerAddress("machine", "runner-a");
    const runner_b = fx.runnerAddress("machine", "runner-b");

    const first = try runner_storage.acquire(.{
        .shard_id = 0,
        .owner = runner_a,
        .now_ms = 1_000,
        .ttl_ms = 100,
    });
    const stale_fence = fx.fenceFromLease(first);
    try fx.validateShardFence(runner_storage, stale_fence);

    _ = try runner_storage.acquire(.{
        .shard_id = 0,
        .owner = runner_b,
        .now_ms = 1_100,
        .ttl_ms = 100,
    });
    try std.testing.expectError(error.StaleShardFence, fx.validateShardFence(runner_storage, stale_fence));
}

test "stale cluster runtime rejects shard processing before message claim" {
    var runner_storage_state = fx.InMemoryRunnerStorage.init(std.testing.allocator);
    defer runner_storage_state.deinit();
    const runner_storage = runner_storage_state.asRunnerStorage();
    var message_storage_state = fx.InMemoryMessageStorage.init(std.testing.allocator);
    defer message_storage_state.deinit();
    const message_storage = message_storage_state.asMessageStorage();

    const owner_a = fx.runnerAddress("machine", "runner-a");
    var lease_manager_a = try fx.LocalShardLeaseManager.init(
        std.testing.allocator,
        runner_storage,
        owner_a,
        .{ .ttl_ms = 100, .refresh_interval_ms = 50 },
    );
    defer lease_manager_a.deinit();
    var runtime_a = try fx.ClusterRuntime.init(
        std.testing.allocator,
        message_storage,
        &lease_manager_a,
        .{ .shard_count = 8 },
    );
    defer runtime_a.deinit();
    _ = try runtime_a.acquireShard(0, 1_000);

    const address = try addressForShard(0, 8);
    var submitted = try message_storage.submit(.{
        .shard_id = 0,
        .envelope = .{
            .kind = .tell,
            .address = address,
            .payload_type_name = "text/plain",
            .payload = "write",
            .redacted_detail = "stale-write",
            .idempotency_key = "stale-write",
        },
    });
    defer submitted.deinit(std.testing.allocator);

    const owner_b = fx.runnerAddress("machine", "runner-b");
    var lease_manager_b = try fx.LocalShardLeaseManager.init(
        std.testing.allocator,
        runner_storage,
        owner_b,
        .{ .ttl_ms = 100, .refresh_interval_ms = 50 },
    );
    defer lease_manager_b.deinit();
    _ = try lease_manager_b.acquireShard(0, 1_100);

    try std.testing.expectError(error.StaleShardFence, runtime_a.processShard(0, NoopEntityHandler, 1_110));
    try std.testing.expect(!runtime_a.ownsShard(0));

    var unprocessed = try message_storage.unprocessedByShard(0, std.testing.allocator);
    defer unprocessed.deinit();
    try std.testing.expectEqual(@as(usize, 1), unprocessed.records.len);
}

test "stale workflow entity rejects journal write after lease epoch moves" {
    var runner_storage_state = fx.InMemoryRunnerStorage.init(std.testing.allocator);
    defer runner_storage_state.deinit();
    const runner_storage = runner_storage_state.asRunnerStorage();
    var message_storage_state = fx.InMemoryMessageStorage.init(std.testing.allocator);
    defer message_storage_state.deinit();
    const message_storage = message_storage_state.asMessageStorage();
    var journal_state = fx.workflow.InMemoryJournalStore.init(std.testing.allocator);
    defer journal_state.deinit();
    const journal_store = journal_state.asJournalStore();

    const workflow_id = fx.workflow.workflowId("approval");
    const execution_id = try executionIdForWorkflowShard(0, 8);
    const address = fx.clusterWorkflowExecutionAddress(execution_id);

    var runner_a = try fx.LocalClusterRunner.init(std.testing.allocator, .{
        .runner = fx.runnerAddress("machine", "runner-a"),
        .runner_storage = runner_storage,
        .message_storage = message_storage,
        .shard_count = 8,
        .runner_index = 0,
        .runner_count = 1,
        .lease_options = .{ .ttl_ms = 100, .refresh_interval_ms = 50 },
    });
    defer runner_a.deinit();
    _ = try runner_a.runtime.acquireShard(0, 1_000);

    var registry_a = fx.ClusterWorkflowEntityRegistry.init(std.testing.allocator);
    defer registry_a.deinit();
    _ = try registry_a.registerExecution(&runner_a, journal_store, workflow_id, execution_id, 1_000);

    var runner_b = try fx.LocalClusterRunner.init(std.testing.allocator, .{
        .runner = fx.runnerAddress("machine", "runner-b"),
        .runner_storage = runner_storage,
        .message_storage = message_storage,
        .shard_count = 8,
        .runner_index = 0,
        .runner_count = 1,
        .lease_options = .{ .ttl_ms = 100, .refresh_interval_ms = 50 },
    });
    defer runner_b.deinit();
    _ = try runner_b.runtime.acquireShard(0, 1_100);

    const payload = try fx.formatClusterWorkflowCommandJson(std.testing.allocator, .{
        .kind = .append_event,
        .event_kind = .workflow_started,
        .workflow_id = workflow_id,
        .execution_id = execution_id,
        .workflow_name = "approval",
        .name = "approval",
        .status = "running",
        .idempotency_key = "stale-journal-start",
    });
    defer std.testing.allocator.free(payload);

    const scope = try runner_a.entityScope(address);
    try std.testing.expectError(error.StaleShardFence, fx.ClusterWorkflowEntityHandler.handle(scope, .{
        .id = 1,
        .sequence = 1,
        .kind = .ask,
        .address = address,
        .correlation_id = 1,
        .payload_type_name = fx.cluster_workflow_command_payload_type,
        .payload = payload,
        .redacted_detail = "stale-journal-start",
    }));

    var events = try journal_store.readAll(std.testing.allocator);
    defer events.deinit();
    try std.testing.expectEqual(@as(usize, 0), events.events.len);
}

const NoopEntityHandler = struct {
    pub fn handle(_: *fx.EntityScope, _: fx.EntityEnvelope) !fx.EntityHandlerResult {
        return .noreply;
    }
};

fn addressForShard(shard_id: fx.ShardId, shard_count: fx.ShardCount) !fx.EntityAddress {
    var id: u64 = 1;
    while (id < 100_000) : (id += 1) {
        var key_buf: [32]u8 = undefined;
        const key = std.fmt.bufPrint(&key_buf, "entity-{d}", .{id}) catch unreachable;
        const address = fx.entityAddress("fenced", key);
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
