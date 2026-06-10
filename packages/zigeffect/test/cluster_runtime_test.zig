const std = @import("std");
const fx = @import("zigeffect");

test "cluster runtime public exports are available" {
    try std.testing.expect(@hasDecl(fx.cluster, "runtime"));
    try std.testing.expect(@hasDecl(fx.cluster, "ClusterRuntime"));
    try std.testing.expect(@hasDecl(fx.cluster, "ClusterRuntimeOptions"));
    try std.testing.expect(@hasDecl(fx.cluster, "ClusterRuntimeError"));
    try std.testing.expect(@hasDecl(fx.cluster, "ClusterEntityRef"));
    try std.testing.expect(@hasDecl(fx.cluster, "ClusterAsk"));
    try std.testing.expect(@hasDecl(fx.cluster, "ClusterProcessReport"));
    try std.testing.expect(@hasDecl(fx.cluster, "ClusterShutdownReport"));
    try std.testing.expect(@hasDecl(fx, "ClusterRuntime"));
}

test "cluster runtime loads owned shards from lease manager" {
    var runner_storage_state = fx.InMemoryRunnerStorage.init(std.testing.allocator);
    defer runner_storage_state.deinit();
    const runner_storage = runner_storage_state.asRunnerStorage();
    const owner = fx.runnerAddress("machine-a", "runner-a");
    var lease_manager = try fx.LocalShardLeaseManager.init(
        std.testing.allocator,
        runner_storage,
        owner,
        .{ .ttl_ms = 1_000, .refresh_interval_ms = 250 },
    );
    defer lease_manager.deinit();
    var message_storage_state = fx.InMemoryMessageStorage.init(std.testing.allocator);
    defer message_storage_state.deinit();

    var runtime = try fx.ClusterRuntime.init(
        std.testing.allocator,
        message_storage_state.asMessageStorage(),
        &lease_manager,
        .{ .shard_count = 16 },
    );
    defer runtime.deinit();

    _ = try lease_manager.acquireShard(3, 1_000);
    _ = try lease_manager.acquireShard(5, 1_000);

    try std.testing.expectEqual(@as(usize, 2), try runtime.loadOwnedShards());
    try std.testing.expectEqual(@as(usize, 2), runtime.ownedShardCount());
    try std.testing.expect(runtime.ownsShard(3));
    try std.testing.expect(runtime.ownsShard(5));
    try std.testing.expect(!runtime.ownsShard(7));
}

test "cluster runtime acquire and release shard update runtime and leases" {
    var runner_storage_state = fx.InMemoryRunnerStorage.init(std.testing.allocator);
    defer runner_storage_state.deinit();
    const runner_storage = runner_storage_state.asRunnerStorage();
    const owner = fx.runnerAddress("machine-a", "runner-a");
    var lease_manager = try fx.LocalShardLeaseManager.init(
        std.testing.allocator,
        runner_storage,
        owner,
        .{ .ttl_ms = 1_000, .refresh_interval_ms = 250 },
    );
    defer lease_manager.deinit();
    var message_storage_state = fx.InMemoryMessageStorage.init(std.testing.allocator);
    defer message_storage_state.deinit();

    var runtime = try fx.ClusterRuntime.init(
        std.testing.allocator,
        message_storage_state.asMessageStorage(),
        &lease_manager,
        .{ .shard_count = 16 },
    );
    defer runtime.deinit();

    const lease = try runtime.acquireShard(4, 1_000);
    try std.testing.expectEqual(@as(fx.ShardId, 4), lease.shard_id);
    try std.testing.expect(runtime.ownsShard(4));
    try std.testing.expect(lease_manager.ownsShard(4));
    try std.testing.expect((try runner_storage.lease(4)) != null);

    try runtime.releaseShard(4, 1_100);
    try std.testing.expect(!runtime.ownsShard(4));
    try std.testing.expect(!lease_manager.ownsShard(4));
    try std.testing.expect((try runner_storage.lease(4)) == null);
}

test "cluster entity ref submits durable tell and ask messages for owned shard" {
    var runner_storage_state = fx.InMemoryRunnerStorage.init(std.testing.allocator);
    defer runner_storage_state.deinit();
    const runner_storage = runner_storage_state.asRunnerStorage();
    const owner = fx.runnerAddress("machine-a", "runner-a");
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
        .{ .shard_count = 16 },
    );
    defer runtime.deinit();

    const address = fx.entityAddress("counter", "durable-ref");
    const shard_id = try fx.shardIdForAddress(address, 16);
    _ = try runtime.acquireShard(shard_id, 1_000);
    const ref = try runtime.registerEntity(.{ .address = address, .name = "counter-durable-ref" }, 1_000);

    var tell = try ref.tell("text", "inc", "first command");
    defer tell.deinit(std.testing.allocator);
    try std.testing.expectEqual(fx.MessageEnvelopeKind.tell, tell.envelope.kind);

    var ask = try ref.ask("text", "get", "read current value");
    defer ask.deinit(std.testing.allocator);
    try std.testing.expectEqual(fx.MessageEnvelopeKind.request, ask.envelope.kind);
    try std.testing.expect(ask.correlation_id != 0);

    var by_shard = try message_storage.unprocessedByShard(shard_id, std.testing.allocator);
    defer by_shard.deinit();
    try std.testing.expectEqual(@as(usize, 2), by_shard.records.len);
    try std.testing.expectEqual(fx.MessageEnvelopeKind.tell, by_shard.records[0].envelope.kind);
    try std.testing.expectEqual(fx.MessageEnvelopeKind.request, by_shard.records[1].envelope.kind);
}

test "cluster entity ref rejects durable submission for unowned shard" {
    var runner_storage_state = fx.InMemoryRunnerStorage.init(std.testing.allocator);
    defer runner_storage_state.deinit();
    const runner_storage = runner_storage_state.asRunnerStorage();
    const owner = fx.runnerAddress("machine-a", "runner-a");
    var lease_manager = try fx.LocalShardLeaseManager.init(
        std.testing.allocator,
        runner_storage,
        owner,
        .{ .ttl_ms = 1_000, .refresh_interval_ms = 250 },
    );
    defer lease_manager.deinit();
    var message_storage_state = fx.InMemoryMessageStorage.init(std.testing.allocator);
    defer message_storage_state.deinit();

    var runtime = try fx.ClusterRuntime.init(
        std.testing.allocator,
        message_storage_state.asMessageStorage(),
        &lease_manager,
        .{ .shard_count = 16 },
    );
    defer runtime.deinit();

    const address = fx.entityAddress("counter", "unowned");
    const ref = try runtime.registerEntity(.{ .address = address, .name = "counter-unowned" }, 1_000);

    try std.testing.expectError(error.ShardNotOwned, ref.tell("text", "inc", "first command"));
    try std.testing.expectError(error.ShardNotOwned, ref.ask("text", "get", "read current value"));
}

test "cluster runtime processes tell messages and acks durable storage" {
    var runner_storage_state = fx.InMemoryRunnerStorage.init(std.testing.allocator);
    defer runner_storage_state.deinit();
    const runner_storage = runner_storage_state.asRunnerStorage();
    const owner = fx.runnerAddress("machine-a", "runner-a");
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
        .{ .shard_count = 16 },
    );
    defer runtime.deinit();

    const address = fx.entityAddress("counter", "dispatch-tell");
    const shard_id = try fx.shardIdForAddress(address, 16);
    _ = try runtime.acquireShard(shard_id, 1_000);
    const ref = try runtime.registerEntity(.{ .address = address, .name = "counter-dispatch-tell" }, 1_000);
    var seen = std.ArrayList([]u8).empty;
    defer {
        for (seen.items) |item| {
            std.testing.allocator.free(item);
        }
        seen.deinit(std.testing.allocator);
    }
    const scope = try runtime.entityScope(address);
    try scope.provideService("seen", &seen);

    var tell = try ref.tell("text", "inc", "first command");
    defer tell.deinit(std.testing.allocator);

    const Handler = struct {
        pub fn handle(entity_scope: *fx.EntityScope, envelope: fx.EntityEnvelope) !fx.EntityHandlerResult {
            const raw = (try entity_scope.service("seen")).?;
            const seen_messages: *std.ArrayList([]u8) = @ptrCast(@alignCast(raw));
            const owned_payload = try std.testing.allocator.dupe(u8, envelope.payload);
            errdefer std.testing.allocator.free(owned_payload);
            try seen_messages.append(std.testing.allocator, owned_payload);
            return .noreply;
        }
    };

    const report = try runtime.processShard(shard_id, Handler, 1_100);
    try std.testing.expectEqual(@as(usize, 1), report.scanned);
    try std.testing.expectEqual(@as(usize, 1), report.claimed);
    try std.testing.expectEqual(@as(usize, 1), report.dispatched);
    try std.testing.expectEqual(@as(usize, 1), report.acked);
    try std.testing.expectEqualStrings("inc", seen.items[0]);
    try std.testing.expect((try message_storage.unprocessedById(tell.envelope.id, std.testing.allocator)) == null);
}

test "cluster runtime processes ask messages stores replies and acks requests" {
    var runner_storage_state = fx.InMemoryRunnerStorage.init(std.testing.allocator);
    defer runner_storage_state.deinit();
    const runner_storage = runner_storage_state.asRunnerStorage();
    const owner = fx.runnerAddress("machine-a", "runner-a");
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
        .{ .shard_count = 16 },
    );
    defer runtime.deinit();

    const address = fx.entityAddress("counter", "dispatch-ask");
    const shard_id = try fx.shardIdForAddress(address, 16);
    _ = try runtime.acquireShard(shard_id, 1_000);
    const ref = try runtime.registerEntity(.{ .address = address, .name = "counter-dispatch-ask" }, 1_000);
    var ask = try ref.ask("text", "get", "read current value");
    defer ask.deinit(std.testing.allocator);

    const Handler = struct {
        pub fn handle(_: *fx.EntityScope, envelope: fx.EntityEnvelope) !fx.EntityHandlerResult {
            if (envelope.kind == .ask) return .{ .reply = "value=1" };
            return .noreply;
        }
    };

    const report = try runtime.processShard(shard_id, Handler, 1_100);
    try std.testing.expectEqual(@as(usize, 1), report.scanned);
    try std.testing.expectEqual(@as(usize, 1), report.replied);
    try std.testing.expectEqual(@as(usize, 1), report.acked);

    const found_reply = (try message_storage.reply(ask.correlation_id, std.testing.allocator)).?;
    defer fx.deinitMessageEnvelope(std.testing.allocator, found_reply);
    try std.testing.expectEqual(fx.MessageEnvelopeKind.reply, found_reply.kind);
    try std.testing.expectEqualStrings("value=1", found_reply.payload);
    try std.testing.expect((try message_storage.unprocessedById(ask.envelope.id, std.testing.allocator)) == null);
}

test "cluster runtime leaves failed durable messages retryable" {
    var runner_storage_state = fx.InMemoryRunnerStorage.init(std.testing.allocator);
    defer runner_storage_state.deinit();
    const runner_storage = runner_storage_state.asRunnerStorage();
    const owner = fx.runnerAddress("machine-a", "runner-a");
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
        .{ .shard_count = 16 },
    );
    defer runtime.deinit();

    const address = fx.entityAddress("counter", "dispatch-fail");
    const shard_id = try fx.shardIdForAddress(address, 16);
    _ = try runtime.acquireShard(shard_id, 1_000);
    const ref = try runtime.registerEntity(.{ .address = address, .name = "counter-dispatch-fail" }, 1_000);
    var tell = try ref.tell("text", "boom", "failing command");
    defer tell.deinit(std.testing.allocator);

    const Handler = struct {
        pub fn handle(_: *fx.EntityScope, _: fx.EntityEnvelope) !fx.EntityHandlerResult {
            return error.Boom;
        }
    };

    try std.testing.expectError(error.Boom, runtime.processShard(shard_id, Handler, 1_100));
    var retryable = (try message_storage.unprocessedById(tell.envelope.id, std.testing.allocator)).?;
    defer retryable.deinit(std.testing.allocator);
    try std.testing.expectEqual(fx.MessageDeliveryStatus.claimed, retryable.status);
    try std.testing.expectEqual(@as(fx.MessageAttempt, 1), retryable.envelope.attempt);
}

test "cluster runtime rejects processing unowned shard" {
    var runner_storage_state = fx.InMemoryRunnerStorage.init(std.testing.allocator);
    defer runner_storage_state.deinit();
    const runner_storage = runner_storage_state.asRunnerStorage();
    const owner = fx.runnerAddress("machine-a", "runner-a");
    var lease_manager = try fx.LocalShardLeaseManager.init(
        std.testing.allocator,
        runner_storage,
        owner,
        .{ .ttl_ms = 1_000, .refresh_interval_ms = 250 },
    );
    defer lease_manager.deinit();
    var message_storage_state = fx.InMemoryMessageStorage.init(std.testing.allocator);
    defer message_storage_state.deinit();

    var runtime = try fx.ClusterRuntime.init(
        std.testing.allocator,
        message_storage_state.asMessageStorage(),
        &lease_manager,
        .{ .shard_count = 16 },
    );
    defer runtime.deinit();

    const Handler = struct {
        pub fn handle(_: *fx.EntityScope, _: fx.EntityEnvelope) !fx.EntityHandlerResult {
            return .noreply;
        }
    };

    try std.testing.expectError(error.ShardNotOwned, runtime.processShard(6, Handler, 1_100));
}
