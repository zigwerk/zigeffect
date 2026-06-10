const std = @import("std");
const fx = @import("zigeffect");

test "production shard leasing public exports are available" {
    try std.testing.expect(@hasDecl(fx.cluster, "lease_guard"));
    try std.testing.expect(@hasDecl(fx.cluster, "ShardLeaseWriteGuard"));
    try std.testing.expect(@hasDecl(fx.cluster, "ShardLeaseGuardedJournalStore"));
    try std.testing.expect(@hasDecl(fx.cluster, "ShardLeaseWriteKind"));
    try std.testing.expect(@hasDecl(fx.cluster, "guardMessageSubmit"));
    try std.testing.expect(@hasDecl(fx.cluster, "guardMessageClaim"));
    try std.testing.expect(@hasDecl(fx.cluster, "guardMessageAck"));
    try std.testing.expect(@hasDecl(fx.cluster, "guardMessageReply"));
    try std.testing.expect(@hasDecl(fx.cluster, "guardJournalAppend"));
    try std.testing.expect(@hasDecl(fx.cluster, "guardMailboxOffer"));
    try std.testing.expect(@hasDecl(fx.cluster, "guardMailboxReply"));
    try std.testing.expect(@hasDecl(fx.cluster, "appendLeaseEpochDetail"));
    try std.testing.expect(@hasDecl(fx.cluster, "leaseEpochFromDetail"));
    try std.testing.expect(@hasDecl(fx.cluster, "ShardLeaseAuditReport"));
    try std.testing.expect(@hasDecl(fx.cluster, "ShardLeaseForceReleaseReport"));
    try std.testing.expect(@hasDecl(fx, "ShardLeaseWriteGuard"));
}

test "lease renewal jitter deadline and recovery expiry are deterministic" {
    const owner = fx.runnerAddress("machine-a", "runner-a");
    const lease = fx.ShardLease{
        .shard_id = 5,
        .owner = owner,
        .acquired_at_ms = 1_000,
        .refreshed_at_ms = 1_000,
        .expires_at_ms = 2_000,
        .epoch = 3,
        .version = 4,
    };
    const options = fx.ShardLeaseManagerOptions{
        .ttl_ms = 1_000,
        .refresh_interval_ms = 200,
        .renewal_jitter_ms = 50,
        .renewal_deadline_ms = 800,
        .clock_skew_tolerance_ms = 25,
    };

    const jitter = fx.shardLeaseRenewalJitterMs(lease, options);
    try std.testing.expect(jitter <= 50);
    try std.testing.expectEqual(@as(u64, 1_800), fx.shardLeaseRenewalDeadlineAt(lease, options));
    try std.testing.expectEqual(@as(u64, 1_200 + jitter), fx.shardLeaseNextRefreshAt(lease, options));
    try std.testing.expect(!fx.shardLeaseExpiredForRecovery(lease, options, 2_024));
    try std.testing.expect(fx.shardLeaseExpiredForRecovery(lease, options, 2_025));
}

test "message storage persists lease epoch across submit claim ack reply and json" {
    var storage_state = fx.InMemoryMessageStorage.init(std.testing.allocator);
    defer storage_state.deinit();
    const storage = storage_state.asMessageStorage();
    const address = fx.entityAddress("lease-message", "one");

    var submitted = try storage.submit(.{
        .shard_id = 2,
        .now_ms = 1_000,
        .lease_epoch = 7,
        .envelope = .{
            .kind = .request,
            .address = address,
            .idempotency_key = "lease-message",
            .payload = "ping",
        },
    });
    defer submitted.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(?fx.ShardLeaseEpoch, 7), submitted.envelope.lease_epoch);

    const claimed = try storage.claim(.{
        .shard_id = 2,
        .message_id = submitted.envelope.id,
        .now_ms = 1_010,
        .lease_epoch = 7,
    });
    defer fx.deinitMessageEnvelope(std.testing.allocator, claimed);
    try std.testing.expectEqual(@as(?fx.ShardLeaseEpoch, 7), claimed.lease_epoch);

    const stored_reply = try storage.storeReply(.{
        .shard_id = 2,
        .now_ms = 1_015,
        .lease_epoch = 7,
        .envelope = .{
            .kind = .reply,
            .address = address,
            .correlation_id = submitted.envelope.correlation_id.?,
            .payload = "pong",
        },
    });
    defer fx.deinitMessageEnvelope(std.testing.allocator, stored_reply);
    try std.testing.expectEqual(@as(?fx.ShardLeaseEpoch, 7), stored_reply.lease_epoch);

    try storage.ack(.{
        .message_id = submitted.envelope.id,
        .shard_id = 2,
        .now_ms = 1_020,
        .lease_epoch = 7,
    });
    try std.testing.expectEqual(@as(?fx.ShardLeaseEpoch, 7), storage_state.messages.items[0].lease_epoch);
    try std.testing.expectEqual(@as(?fx.ShardLeaseEpoch, 7), storage_state.replies.items[0].lease_epoch);

    const json = try fx.formatStoredMessageRecordJson(std.testing.allocator, storage_state.messages.items[0]);
    defer std.testing.allocator.free(json);
    var parsed = try fx.parseStoredMessageRecordJson(std.testing.allocator, json);
    defer parsed.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(?fx.ShardLeaseEpoch, 7), parsed.lease_epoch);
}

test "mailbox envelopes carry lease epoch" {
    var store = fx.LocalMailboxStore.init(std.testing.allocator);
    defer store.deinit();
    const address = fx.entityAddress("lease-mailbox", "one");

    const offered = try store.offer(.{
        .kind = .tell,
        .address = address,
        .lease_epoch = 9,
        .payload = "hello",
    });
    defer fx.deinitEntityEnvelope(std.testing.allocator, offered);

    const taken = try store.take(address);
    defer fx.deinitEntityEnvelope(std.testing.allocator, taken);
    try std.testing.expectEqual(@as(?fx.ShardLeaseEpoch, 9), taken.lease_epoch);
}

test "guarded message writes validate fence and stamp epoch" {
    var runner_storage_state = fx.InMemoryRunnerStorage.init(std.testing.allocator);
    defer runner_storage_state.deinit();
    const runner_storage = runner_storage_state.asRunnerStorage();
    var message_storage_state = fx.InMemoryMessageStorage.init(std.testing.allocator);
    defer message_storage_state.deinit();
    const message_storage = message_storage_state.asMessageStorage();

    const owner_a = fx.runnerAddress("machine", "runner-a");
    const owner_b = fx.runnerAddress("machine", "runner-b");
    const lease_a = try runner_storage.acquire(.{ .shard_id = 0, .owner = owner_a, .now_ms = 1_000, .ttl_ms = 100 });
    const guard_a = fx.ShardLeaseWriteGuard.init(runner_storage, fx.fenceFromLease(lease_a), .message_submit);
    const address = try addressForShard(0, 8);

    var submitted = try fx.guardMessageSubmit(message_storage, .{
        .guard = guard_a,
        .request = .{
            .shard_id = 0,
            .now_ms = 1_010,
            .envelope = .{
                .kind = .request,
                .address = address,
                .idempotency_key = "guarded",
                .payload = "ping",
            },
        },
    });
    defer submitted.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(?fx.ShardLeaseEpoch, 1), submitted.envelope.lease_epoch);
    try std.testing.expectEqual(@as(?fx.ShardLeaseEpoch, 1), message_storage_state.messages.items[0].lease_epoch);

    _ = try runner_storage.acquire(.{ .shard_id = 0, .owner = owner_b, .now_ms = 1_100, .ttl_ms = 100 });
    try std.testing.expectError(error.StaleShardFence, fx.guardMessageClaim(message_storage, .{
        .guard = fx.ShardLeaseWriteGuard.init(runner_storage, fx.fenceFromLease(lease_a), .message_claim),
        .request = .{ .shard_id = 0, .message_id = submitted.envelope.id, .now_ms = 1_110 },
    }));
}

test "guarded mailbox writes stamp epoch and reject stale fence" {
    var runner_storage_state = fx.InMemoryRunnerStorage.init(std.testing.allocator);
    defer runner_storage_state.deinit();
    const runner_storage = runner_storage_state.asRunnerStorage();
    var store = fx.LocalMailboxStore.init(std.testing.allocator);
    defer store.deinit();

    const owner_a = fx.runnerAddress("machine", "runner-a");
    const owner_b = fx.runnerAddress("machine", "runner-b");
    const lease_a = try runner_storage.acquire(.{ .shard_id = 3, .owner = owner_a, .now_ms = 1_000, .ttl_ms = 100 });
    const address = fx.entityAddress("guarded-mailbox", "one");
    const guard_a = fx.ShardLeaseWriteGuard.init(runner_storage, fx.fenceFromLease(lease_a), .mailbox);

    const offered = try fx.guardMailboxOffer(&store, guard_a, .{
        .kind = .tell,
        .address = address,
        .payload = "hello",
    });
    defer fx.deinitEntityEnvelope(std.testing.allocator, offered);
    try std.testing.expectEqual(@as(?fx.ShardLeaseEpoch, 1), offered.lease_epoch);

    _ = try runner_storage.acquire(.{ .shard_id = 3, .owner = owner_b, .now_ms = 1_100, .ttl_ms = 100 });
    try std.testing.expectError(error.StaleShardFence, fx.guardMailboxOffer(&store, guard_a, .{
        .kind = .tell,
        .address = address,
        .payload = "stale",
    }));
}

test "guarded journal store stamps lease epoch and rejects stale fence" {
    var runner_storage_state = fx.InMemoryRunnerStorage.init(std.testing.allocator);
    defer runner_storage_state.deinit();
    const runner_storage = runner_storage_state.asRunnerStorage();
    var journal_state = fx.workflow.InMemoryJournalStore.init(std.testing.allocator);
    defer journal_state.deinit();

    const owner_a = fx.runnerAddress("machine", "runner-a");
    const owner_b = fx.runnerAddress("machine", "runner-b");
    const lease_a = try runner_storage.acquire(.{ .shard_id = 1, .owner = owner_a, .now_ms = 1_000, .ttl_ms = 100 });
    var guarded_store = fx.ShardLeaseGuardedJournalStore.init(
        std.testing.allocator,
        journal_state.asJournalStore(),
        fx.ShardLeaseWriteGuard.init(runner_storage, fx.fenceFromLease(lease_a), .journal),
    );
    const journal_store = guarded_store.asJournalStore();

    _ = try journal_store.append(.{ .expected_next_sequence = 1, .event = .{
        .sequence = 1,
        .kind = .workflow_started,
        .workflow_id = 7,
        .execution_id = 8,
        .name = "guarded",
        .status = "running",
        .redacted_detail = "start",
        .idempotency_key = "guarded-start",
    } });

    var events = try journal_state.asJournalStore().readAll(std.testing.allocator);
    defer events.deinit();
    try std.testing.expectEqual(@as(?fx.ShardLeaseEpoch, 1), fx.leaseEpochFromDetail(events.events[0].redacted_detail));

    _ = try runner_storage.acquire(.{ .shard_id = 1, .owner = owner_b, .now_ms = 1_100, .ttl_ms = 100 });
    try std.testing.expectError(error.StaleShardFence, journal_store.append(.{ .expected_next_sequence = 2, .event = .{
        .sequence = 2,
        .kind = .workflow_completed,
        .workflow_id = 7,
        .execution_id = 8,
        .status = "completed",
        .idempotency_key = "guarded-complete",
    } }));
}

test "lease audit reports valid stale epoch missing and expired owned leases" {
    var storage_state = fx.InMemoryRunnerStorage.init(std.testing.allocator);
    defer storage_state.deinit();
    const storage = storage_state.asRunnerStorage();
    const owner_a = fx.runnerAddress("machine", "runner-a");
    const owner_b = fx.runnerAddress("machine", "runner-b");

    var manager = try fx.LocalShardLeaseManager.init(std.testing.allocator, storage, owner_a, .{
        .ttl_ms = 100,
        .refresh_interval_ms = 20,
        .renewal_deadline_ms = 80,
        .clock_skew_tolerance_ms = 10,
    });
    defer manager.deinit();

    _ = try manager.acquireShard(0, 1_000);
    _ = try manager.acquireShard(1, 1_000);
    _ = try manager.acquireShard(2, 1_000);
    try storage.release(.{ .shard_id = 1, .owner = owner_a });
    _ = try storage.acquire(.{ .shard_id = 2, .owner = owner_b, .now_ms = 1_100, .ttl_ms = 100 });

    var report = try manager.auditOwnedLeases(std.testing.allocator, 1_111);
    defer report.deinit();
    try std.testing.expectEqual(@as(usize, 3), report.scanned);
    try std.testing.expectEqual(@as(usize, 1), report.expired);
    try std.testing.expectEqual(@as(usize, 1), report.missing);
    try std.testing.expectEqual(@as(usize, 1), report.stale_owner);
}

test "force release stale shard releases only after skew tolerant expiry" {
    var storage_state = fx.InMemoryRunnerStorage.init(std.testing.allocator);
    defer storage_state.deinit();
    const storage = storage_state.asRunnerStorage();
    const owner_a = fx.runnerAddress("machine", "runner-a");
    const owner_b = fx.runnerAddress("machine", "runner-b");

    _ = try storage.acquire(.{ .shard_id = 4, .owner = owner_a, .now_ms = 1_000, .ttl_ms = 100 });
    var manager = try fx.LocalShardLeaseManager.init(std.testing.allocator, storage, owner_b, .{
        .ttl_ms = 100,
        .refresh_interval_ms = 20,
        .clock_skew_tolerance_ms = 10,
    });
    defer manager.deinit();

    try std.testing.expectError(error.RunnerStillAlive, manager.forceReleaseStaleShard(4, 1_109));
    const released = try manager.forceReleaseStaleShard(4, 1_110);
    try std.testing.expectEqual(@as(fx.ShardId, 4), released.shard_id);
    try std.testing.expect(released.released_owner.eql(owner_a));
    try std.testing.expect((try storage.lease(4)) == null);
}

test "cluster runtime stamps epochs and rejects stale owner after reacquisition" {
    var runner_storage_state = fx.InMemoryRunnerStorage.init(std.testing.allocator);
    defer runner_storage_state.deinit();
    const runner_storage = runner_storage_state.asRunnerStorage();
    var message_storage_state = fx.InMemoryMessageStorage.init(std.testing.allocator);
    defer message_storage_state.deinit();
    const message_storage = message_storage_state.asMessageStorage();
    const address = try addressForShard(0, 8);

    var fixture_a = try runtimeFor(runner_storage, message_storage, "runner-a");
    defer fixture_a.deinit();
    const runtime_a = &fixture_a.runtime;
    _ = try runtime_a.acquireShard(0, 1_000);
    _ = try runtime_a.registerEntity(.{ .address = address, .name = "runtime-lease" }, 1_000);
    const ref_a = try runtime_a.ref(address);

    var request = try ref_a.ask("text/plain", "ping", "ping");
    defer request.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(?fx.ShardLeaseEpoch, 1), request.envelope.lease_epoch);

    var fixture_b = try runtimeFor(runner_storage, message_storage, "runner-b");
    defer fixture_b.deinit();
    const runtime_b = &fixture_b.runtime;
    _ = try runtime_b.acquireShard(0, 1_100);
    _ = try runtime_b.registerEntity(.{ .address = address, .name = "runtime-lease" }, 1_100);

    try std.testing.expectError(error.StaleShardFence, runtime_a.processShard(0, NoopEntityHandler, 1_110));
    try std.testing.expect(!runtime_a.ownsShard(0));

    const report = try runtime_b.processShard(0, NoopEntityHandler, 1_120);
    try std.testing.expectEqual(@as(usize, 1), report.acked);
    try std.testing.expectEqual(@as(?fx.ShardLeaseEpoch, 2), message_storage_state.messages.items[0].lease_epoch);
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
        const address = fx.entityAddress("production-lease", key);
        if (try fx.shardIdForAddress(address, shard_count) == shard_id) return address;
    }
    return error.EntityShardNotFound;
}

const RuntimeFixture = struct {
    manager: *fx.LocalShardLeaseManager,
    runtime: fx.ClusterRuntime,

    pub fn deinit(self: *RuntimeFixture) void {
        self.runtime.deinit();
        self.manager.deinit();
        std.testing.allocator.destroy(self.manager);
    }
};

fn runtimeFor(runner_storage: fx.RunnerStorage, message_storage: fx.MessageStorage, runner_name: []const u8) !RuntimeFixture {
    const owner = fx.runnerAddress("machine", runner_name);
    const manager = try std.testing.allocator.create(fx.LocalShardLeaseManager);
    errdefer std.testing.allocator.destroy(manager);
    manager.* = try fx.LocalShardLeaseManager.init(
        std.testing.allocator,
        runner_storage,
        owner,
        .{ .ttl_ms = 100, .refresh_interval_ms = 20 },
    );
    errdefer manager.deinit();

    const runtime = try fx.ClusterRuntime.init(
        std.testing.allocator,
        message_storage,
        manager,
        .{ .shard_count = 8 },
    );
    return .{
        .manager = manager,
        .runtime = runtime,
    };
}
