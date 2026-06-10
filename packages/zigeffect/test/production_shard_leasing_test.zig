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
