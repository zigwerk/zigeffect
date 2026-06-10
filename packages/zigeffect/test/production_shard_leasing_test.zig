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
