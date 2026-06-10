# zigeffect Production Shard Leasing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add production-grade shard leases with storage-backed write guards, epoch-stamped writes, renewal timing rules, stale-owner release, audit reports, and crash-style tests.

**Architecture:** Keep `RunnerStorage` as the source of truth for lease ownership. Add a small cluster `lease_guard` module that validates a `ShardLeaseFence` immediately before each shard-owned mutation, stamps successful writes with `lease_epoch`, and wraps `JournalStore` so existing workflow lifecycle, timer, and queue code is covered without duplicating its logic.

**Tech Stack:** Zig, zigeffect cluster/workflow modules, `bun:test` wrapper commands, `zig build test-raw`, `std.testing`.

---

## File Structure

- Create `packages/zigeffect/src/cluster/lease_guard.zig`
  Owns `ShardLeaseWriteGuard`, guarded message helpers, guarded mailbox helpers, guarded journal append, guarded journal-store wrapper, and lease epoch detail parsing.
- Create `packages/zigeffect/test/production_shard_leasing_test.zig`
  Focused M48 test coverage for public exports, lease timing, guarded writes, stale fences, audit, force release, and rapid reacquisition.
- Modify `packages/zigeffect/test/all_test.zig`
  Imports the new test file.
- Modify `packages/zigeffect/src/cluster/envelope.zig`
  Adds `lease_epoch` to `MessageEnvelope`.
- Modify `packages/zigeffect/src/cluster/mailbox.zig`
  Adds `lease_epoch` to `EntityEnvelope`.
- Modify `packages/zigeffect/src/cluster/message_storage.zig`
  Persists `lease_epoch` in memory/file message and reply records; accepts epochs on submit, claim, ack, and reply writes.
- Modify `packages/zigeffect/src/cluster/shard_lease.zig`
  Adds renewal jitter/deadline/skew options, timing helpers, owned-lease audit reports, and forced stale release.
- Modify `packages/zigeffect/src/cluster/runtime.zig`
  Replaces direct shard-owned message storage writes with guarded helpers and propagates claimed message epochs into entity envelopes.
- Modify `packages/zigeffect/src/cluster/workflow_engine.zig`
  Wraps workflow journal command application in `ShardLeaseGuardedJournalStore`.
- Modify `packages/zigeffect/src/cluster/root.zig`
  Exports `lease_guard` public API.
- Modify `packages/zigeffect/src/zigeffect.zig`
  Re-exports top-level M48 public API.
- Modify `packages/zigeffect/src/workflow/clock.zig`
  Makes timer fire-at parsing tolerate appended `lease_epoch` detail.
- Modify `packages/zigeffect/src/cluster/timer_wakeup.zig`
  Makes distributed timer wakeup parsing tolerate appended `lease_epoch` detail.
- Modify docs:
  `packages/zigeffect/docs/architecture.md`,
  `packages/zigeffect/docs/effectts-parity.md`,
  `packages/zigeffect/docs/usage.md`,
  `docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md`,
  `docs/superpowers/reports/2026-06-10-zigeffect-milestone-48-completion.md`.

## Task 1: Red Tests For Public API And Timing

**Files:**
- Create: `packages/zigeffect/test/production_shard_leasing_test.zig`
- Modify: `packages/zigeffect/test/all_test.zig`

- [ ] **Step 1: Add the new test import**

Add this line in the `comptime` imports:

```zig
    _ = @import("production_shard_leasing_test.zig");
```

- [ ] **Step 2: Add public export and timing tests**

Create `packages/zigeffect/test/production_shard_leasing_test.zig` with:

```zig
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
    try std.testing.expectEqual(@as(u64, 1_000 + 800), fx.shardLeaseRenewalDeadlineAt(lease, options));
    try std.testing.expectEqual(@as(u64, 1_000 + 200 + jitter), fx.shardLeaseNextRefreshAt(lease, options));
    try std.testing.expect(!fx.shardLeaseExpiredForRecovery(lease, options, 2_024));
    try std.testing.expect(fx.shardLeaseExpiredForRecovery(lease, options, 2_025));
}
```

- [ ] **Step 3: Run the red test command**

Run:

```bash
cd packages/zigeffect && zig build test-raw
```

Expected: FAIL because `production_shard_leasing_test.zig` references new exports and fields that are absent.

- [ ] **Step 4: Commit the red tests**

Run:

```bash
git add packages/zigeffect/test/all_test.zig packages/zigeffect/test/production_shard_leasing_test.zig
git commit -m "test(zigeffect): specify production shard leasing"
```

## Task 2: Message And Mailbox Epoch Storage

**Files:**
- Modify: `packages/zigeffect/src/cluster/envelope.zig`
- Modify: `packages/zigeffect/src/cluster/mailbox.zig`
- Modify: `packages/zigeffect/src/cluster/message_storage.zig`
- Test: `packages/zigeffect/test/production_shard_leasing_test.zig`

- [ ] **Step 1: Add failing epoch persistence tests**

Append tests that submit, claim, ack, reply, and JSON round-trip records with
`lease_epoch = 7`:

```zig
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

    try storage.ack(.{
        .message_id = submitted.envelope.id,
        .shard_id = 2,
        .now_ms = 1_020,
        .lease_epoch = 7,
    });

    var record = try storage_state.messagesRecordForTest(submitted.envelope.id, std.testing.allocator);
    defer record.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(?fx.ShardLeaseEpoch, 7), record.lease_epoch);

    const json = try fx.formatStoredMessageRecordJson(std.testing.allocator, record);
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
```

- [ ] **Step 2: Run red**

Run:

```bash
cd packages/zigeffect && zig build test-raw
```

Expected: FAIL because envelope and request structs do not expose `lease_epoch` and `messagesRecordForTest`.

- [ ] **Step 3: Implement epoch fields**

Implement these exact struct additions:

```zig
pub const MessageEnvelope = struct {
    ...
    lease_epoch: ?runner_storage.ShardLeaseEpoch = null,
};

pub const EntityEnvelope = struct {
    ...
    lease_epoch: ?runner_storage.ShardLeaseEpoch = null,
};

pub const StoredMessageRecord = struct {
    ...
    lease_epoch: ?runner_storage.ShardLeaseEpoch = null,
};

pub const StoredReplyRecord = struct {
    ...
    lease_epoch: ?runner_storage.ShardLeaseEpoch = null,
};
```

Use `@import("runner_storage.zig")` in cluster modules where the epoch type is needed.

- [ ] **Step 4: Wire message storage requests**

Add `lease_epoch` to submit, claim, ack, and reply request structs, plus
`shard_id: ?ShardId = null` on `MessageStorageAck`.

When a request has an epoch:

- Set `owned.lease_epoch`.
- Set `StoredMessageRecord.lease_epoch` or `StoredReplyRecord.lease_epoch`.
- Return envelopes with the epoch populated.
- On `ack`, verify `request.shard_id` when present and return `error.MessageNotFound` if it mismatches the stored record shard.

- [ ] **Step 5: Wire JSON**

Add optional `lease_epoch` to message and reply JSON structs. Formatting writes
`"lease_epoch":<number>` for new records. Parsing uses `null` for old records
without the field.

- [ ] **Step 6: Run green**

Run:

```bash
cd packages/zigeffect && zig build test-raw
```

Expected: PASS for existing tests plus the new message/mailbox epoch tests that do not require guards.

- [ ] **Step 7: Commit**

Run:

```bash
git add packages/zigeffect/src/cluster/envelope.zig packages/zigeffect/src/cluster/mailbox.zig packages/zigeffect/src/cluster/message_storage.zig packages/zigeffect/test/production_shard_leasing_test.zig
git commit -m "feat(zigeffect): persist lease epochs on cluster messages"
```

## Task 3: Lease Guard Module

**Files:**
- Create: `packages/zigeffect/src/cluster/lease_guard.zig`
- Modify: `packages/zigeffect/src/cluster/root.zig`
- Modify: `packages/zigeffect/src/zigeffect.zig`
- Test: `packages/zigeffect/test/production_shard_leasing_test.zig`

- [ ] **Step 1: Add failing guard tests**

Append tests:

```zig
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
            .envelope = .{ .kind = .request, .address = address, .idempotency_key = "guarded", .payload = "ping" },
        },
    });
    defer submitted.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(?fx.ShardLeaseEpoch, 1), submitted.envelope.lease_epoch);

    _ = try runner_storage.acquire(.{ .shard_id = 0, .owner = owner_b, .now_ms = 1_100, .ttl_ms = 100 });
    try std.testing.expectError(error.StaleShardFence, fx.guardMessageClaim(message_storage, .{
        .guard = fx.ShardLeaseWriteGuard.init(runner_storage, fx.fenceFromLease(lease_a), .message_claim),
        .request = .{ .shard_id = 0, .message_id = submitted.envelope.id, .now_ms = 1_110 },
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
```

- [ ] **Step 2: Run red**

Run:

```bash
cd packages/zigeffect && zig build test-raw
```

Expected: FAIL because the guard module and exports do not exist.

- [ ] **Step 3: Implement `lease_guard.zig`**

Implement:

```zig
pub const ShardLeaseWriteKind = enum {
    journal,
    mailbox,
    message_submit,
    message_claim,
    message_ack,
    message_reply,
    queue,
    timer,
};

pub const ShardLeaseWriteGuard = struct {
    storage: RunnerStorage,
    fence: ShardLeaseFence,
    kind: ShardLeaseWriteKind,

    pub fn init(storage: RunnerStorage, fence: ShardLeaseFence, kind: ShardLeaseWriteKind) ShardLeaseWriteGuard;
    pub fn validate(self: ShardLeaseWriteGuard) !void;
    pub fn epoch(self: ShardLeaseWriteGuard) ShardLeaseEpoch;
};
```

Add `appendLeaseEpochDetail`, `leaseEpochFromDetail`, guarded message helpers,
guarded mailbox helpers, `guardJournalAppend`, and `ShardLeaseGuardedJournalStore`.

- [ ] **Step 4: Export module and symbols**

Wire `cluster/root.zig` and `zigeffect.zig` exports for every symbol listed in
the design.

- [ ] **Step 5: Run green**

Run:

```bash
cd packages/zigeffect && zig build test-raw
```

Expected: PASS for public export, message guard, mailbox epoch, and journal guard tests.

- [ ] **Step 6: Commit**

Run:

```bash
git add packages/zigeffect/src/cluster/lease_guard.zig packages/zigeffect/src/cluster/root.zig packages/zigeffect/src/zigeffect.zig packages/zigeffect/test/production_shard_leasing_test.zig
git commit -m "feat(zigeffect): add storage backed lease guards"
```

## Task 4: Lease Timing, Audit, And Forced Release

**Files:**
- Modify: `packages/zigeffect/src/cluster/shard_lease.zig`
- Test: `packages/zigeffect/test/production_shard_leasing_test.zig`

- [ ] **Step 1: Add failing audit and force-release tests**

Append:

```zig
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
```

- [ ] **Step 2: Run red**

Run:

```bash
cd packages/zigeffect && zig build test-raw
```

Expected: FAIL because audit and force-release APIs are absent.

- [ ] **Step 3: Implement timing options**

Extend `ShardLeaseManagerOptions` and update `validateOptions`:

```zig
renewal_jitter_ms: u64 = 0,
renewal_deadline_ms: u64 = 0,
clock_skew_tolerance_ms: u64 = 0,
```

Update `shardLeaseNextRefreshAt` to include deterministic jitter and add
`shardLeaseRenewalDeadlineAt` plus `shardLeaseExpiredForRecovery`.

- [ ] **Step 4: Implement audit and force release**

Add `ShardLeaseAuditStatus`, `ShardLeaseAuditEntry`, `ShardLeaseAuditReport`,
`ShardLeaseForceReleaseReport`, `auditOwnedLeases`, and
`forceReleaseStaleShard`.

Use `RunnerStorage.lease(shard_id)` as durable truth. `forceReleaseStaleShard`
reads the current owner and calls `storage.release(.{ .shard_id = shard_id, .owner = current.owner })` only after `shardLeaseExpiredForRecovery`.

- [ ] **Step 5: Run green**

Run:

```bash
cd packages/zigeffect && zig build test-raw
```

Expected: PASS for lease timing, audit, and force-release tests.

- [ ] **Step 6: Commit**

Run:

```bash
git add packages/zigeffect/src/cluster/shard_lease.zig packages/zigeffect/src/cluster/root.zig packages/zigeffect/src/zigeffect.zig packages/zigeffect/test/production_shard_leasing_test.zig
git commit -m "feat(zigeffect): add lease audit and recovery timing"
```

## Task 5: Runtime Guard Integration

**Files:**
- Modify: `packages/zigeffect/src/cluster/runtime.zig`
- Test: `packages/zigeffect/test/production_shard_leasing_test.zig`

- [ ] **Step 1: Add failing runtime crash tests**

Append:

```zig
test "stale runtime cannot claim ack or reply after rapid reacquisition" {
    var runner_storage_state = fx.InMemoryRunnerStorage.init(std.testing.allocator);
    defer runner_storage_state.deinit();
    const runner_storage = runner_storage_state.asRunnerStorage();
    var message_storage_state = fx.InMemoryMessageStorage.init(std.testing.allocator);
    defer message_storage_state.deinit();
    const message_storage = message_storage_state.asMessageStorage();

    var runtime_a = try runtimeFor(std.testing.allocator, runner_storage, message_storage, "runner-a");
    defer runtime_a.deinit();
    _ = try runtime_a.acquireShard(0, 1_000);

    const address = try addressForShard(0, 8);
    var submitted = try runtime_a.ref(address) catch blk: {
        _ = try runtime_a.registerEntity(.{ .address = address, .name = "lease-runtime" }, 1_000);
        break :blk try runtime_a.ref(address);
    };
    var request = try submitted.ask("text/plain", "ping", "ping");
    defer request.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(?fx.ShardLeaseEpoch, 1), request.envelope.lease_epoch);

    var runtime_b = try runtimeFor(std.testing.allocator, runner_storage, message_storage, "runner-b");
    defer runtime_b.deinit();
    _ = try runtime_b.acquireShard(0, 1_100);

    try std.testing.expectError(error.StaleShardFence, runtime_a.processShard(0, NoopEntityHandler, 1_110));
    try std.testing.expect(!runtime_a.ownsShard(0));

    const report = try runtime_b.processShard(0, NoopEntityHandler, 1_120);
    try std.testing.expectEqual(@as(usize, 1), report.acked);
}
```

- [ ] **Step 2: Run red**

Run:

```bash
cd packages/zigeffect && zig build test-raw
```

Expected: FAIL because runtime direct writes do not use guarded message helpers or epoch propagation.

- [ ] **Step 3: Replace direct writes**

In `ClusterRuntime`:

- Add helper `messageWriteGuard(shard_id, kind)`.
- Add helper `handleStaleShardFence(shard_id, err)`.
- Use `guardMessageSubmit` in `submitEntityMessageWithOptionalTrace`.
- Use `guardMessageClaim` before entity dispatch.
- Use `guardMessageReply` for replies.
- Use `guardMessageAck` after successful dispatch.
- Propagate `claimed.lease_epoch` into `EntityEnvelope` in `messageToEntityEnvelope`.

- [ ] **Step 4: Run green**

Run:

```bash
cd packages/zigeffect && zig build test-raw
```

Expected: PASS with stale runtime writes rejected before mutation and current owner processing safely.

- [ ] **Step 5: Commit**

Run:

```bash
git add packages/zigeffect/src/cluster/runtime.zig packages/zigeffect/test/production_shard_leasing_test.zig
git commit -m "feat(zigeffect): guard runtime shard writes"
```

## Task 6: Workflow Journal Guard Integration

**Files:**
- Modify: `packages/zigeffect/src/cluster/workflow_engine.zig`
- Modify: `packages/zigeffect/src/workflow/clock.zig`
- Modify: `packages/zigeffect/src/cluster/timer_wakeup.zig`
- Test: `packages/zigeffect/test/production_shard_leasing_test.zig`

- [ ] **Step 1: Add failing workflow and timer tests**

Append:

```zig
test "cluster workflow commands append lease epoch and stale timer fire is rejected" {
    var runner_storage_state = fx.InMemoryRunnerStorage.init(std.testing.allocator);
    defer runner_storage_state.deinit();
    const runner_storage = runner_storage_state.asRunnerStorage();
    var message_storage_state = fx.InMemoryMessageStorage.init(std.testing.allocator);
    defer message_storage_state.deinit();
    const message_storage = message_storage_state.asMessageStorage();
    var journal_state = fx.workflow.InMemoryJournalStore.init(std.testing.allocator);
    defer journal_state.deinit();
    const journal_store = journal_state.asJournalStore();

    const execution_id = try executionIdForWorkflowShard(0, 8);
    const workflow_id = fx.workflow.workflowId("lease-workflow");

    var runner_a = try clusterRunner(std.testing.allocator, runner_storage, message_storage, "runner-a");
    defer runner_a.deinit();
    _ = try runner_a.runtime.acquireShard(0, 1_000);
    var registry_a = fx.ClusterWorkflowEntityRegistry.init(std.testing.allocator);
    defer registry_a.deinit();
    _ = try registry_a.registerExecution(&runner_a, journal_store, workflow_id, execution_id, 1_000);

    const scope = try runner_a.entityScope(fx.clusterWorkflowExecutionAddress(execution_id));
    const start_payload = try fx.formatClusterWorkflowCommandJson(std.testing.allocator, .{
        .kind = .append_event,
        .event_kind = .timer_scheduled,
        .workflow_id = workflow_id,
        .execution_id = execution_id,
        .workflow_name = "lease-workflow",
        .name = "wake",
        .status = "scheduled",
        .redacted_detail = "fire_at_ms=1500",
        .timer_id = fx.workflow.timerId("wake"),
        .idempotency_key = "timer-scheduled",
    });
    defer std.testing.allocator.free(start_payload);

    var start_result = try fx.ClusterWorkflowEntityHandler.handle(scope, .{
        .id = 1,
        .sequence = 1,
        .kind = .ask,
        .address = fx.clusterWorkflowExecutionAddress(execution_id),
        .correlation_id = 1,
        .payload_type_name = fx.cluster_workflow_command_payload_type,
        .payload = start_payload,
    });
    defer start_result.deinit(std.testing.allocator);

    var events = try journal_store.readAll(std.testing.allocator);
    defer events.deinit();
    try std.testing.expectEqual(@as(?fx.ShardLeaseEpoch, 1), fx.leaseEpochFromDetail(events.events[0].redacted_detail));

    var wakeups = fx.ClusterTimerWakeupIndex.init(std.testing.allocator);
    defer wakeups.deinit();
    const wakeup_report = try wakeups.rebuildOwned(&runner_a, journal_store);
    try std.testing.expectEqual(@as(usize, 1), wakeup_report.indexed);

    var runner_b = try clusterRunner(std.testing.allocator, runner_storage, message_storage, "runner-b");
    defer runner_b.deinit();
    _ = try runner_b.runtime.acquireShard(0, 1_100);

    const fire_payload = try fx.formatClusterWorkflowCommandJson(std.testing.allocator, .{
        .kind = .fire_due_timers,
        .workflow_id = workflow_id,
        .execution_id = execution_id,
        .now_ms = 1_500,
        .idempotency_key = "fire-stale",
    });
    defer std.testing.allocator.free(fire_payload);

    try std.testing.expectError(error.StaleShardFence, fx.ClusterWorkflowEntityHandler.handle(scope, .{
        .id = 2,
        .sequence = 2,
        .kind = .ask,
        .address = fx.clusterWorkflowExecutionAddress(execution_id),
        .correlation_id = 2,
        .payload_type_name = fx.cluster_workflow_command_payload_type,
        .payload = fire_payload,
    }));
}
```

- [ ] **Step 2: Run red**

Run:

```bash
cd packages/zigeffect && zig build test-raw
```

Expected: FAIL because workflow command journal writes do not use the guarded journal wrapper and timer parsing expects a bare `fire_at_ms` detail.

- [ ] **Step 3: Wrap workflow command application**

In `ClusterWorkflowEntityHandler.handle`:

- Validate the service fence as today.
- Build `ShardLeaseWriteGuard` with `services.runner_storage`, `services.lease_fence`, and `.journal`.
- Create `ShardLeaseGuardedJournalStore`.
- Pass the guarded store to `applyClusterWorkflowCommand`.

Leave command application logic intact so lifecycle, timer, queue, deferred, and signal writes share the same guard.

- [ ] **Step 4: Make timer parsing suffix-tolerant**

Update `parseTimerFireAt` in both workflow clock and cluster timer wakeup to parse
only the token after `fire_at_ms=` up to the next space.

- [ ] **Step 5: Run green**

Run:

```bash
cd packages/zigeffect && zig build test-raw
```

Expected: PASS with workflow journal epoch stamping and stale timer rejection.

- [ ] **Step 6: Commit**

Run:

```bash
git add packages/zigeffect/src/cluster/workflow_engine.zig packages/zigeffect/src/workflow/clock.zig packages/zigeffect/src/cluster/timer_wakeup.zig packages/zigeffect/test/production_shard_leasing_test.zig
git commit -m "feat(zigeffect): guard cluster workflow journal writes"
```

## Task 7: Documentation, Roadmap, And Completion Report

**Files:**
- Modify: `packages/zigeffect/docs/architecture.md`
- Modify: `packages/zigeffect/docs/effectts-parity.md`
- Modify: `packages/zigeffect/docs/usage.md`
- Modify: `docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md`
- Create: `docs/superpowers/reports/2026-06-10-zigeffect-milestone-48-completion.md`

- [ ] **Step 1: Update docs**

Document:

- `cluster/lease_guard.zig`.
- Storage-backed write guards.
- Lease epoch metadata on message records and journal details.
- Lease timing options.
- Audit and forced stale release APIs.
- Crash-recovery guarantees covered by tests.

- [ ] **Step 2: Update roadmap**

Mark every Milestone 48 deliverable and acceptance checkbox complete.

- [ ] **Step 3: Add completion report**

Create a report with:

- Scope completed.
- Tests added.
- Public API added.
- Verification commands and results.
- Residual boundaries: no distributed consensus or external storage CAS beyond current runner storage abstraction.

- [ ] **Step 4: Run docs marker scan**

Run:

```bash
pattern='T''BD|TO''DO|FIX''ME|st''ub|place''holder|not imple''mented|unimple''mented|fi''ll in|add app''ropriate|sim''ilar to'
rg -n "$pattern" docs/superpowers/reports/2026-06-10-zigeffect-milestone-48-completion.md packages/zigeffect/docs/architecture.md packages/zigeffect/docs/effectts-parity.md packages/zigeffect/docs/usage.md docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md
```

Expected: exit 1 with no matches.

- [ ] **Step 5: Commit**

Run:

```bash
git add packages/zigeffect/docs/architecture.md packages/zigeffect/docs/effectts-parity.md packages/zigeffect/docs/usage.md docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md docs/superpowers/reports/2026-06-10-zigeffect-milestone-48-completion.md
git commit -m "docs(zigeffect): complete production shard leasing"
```

## Task 8: Full Verification Gate

**Files:**
- All M48 touched files.

- [ ] **Step 1: Raw Zig tests**

Run:

```bash
cd packages/zigeffect && zig build test-raw
```

Expected: exit 0.

- [ ] **Step 2: Release gate**

Run:

```bash
cd packages/zigeffect && zig build release-gate
```

Expected: exit 0.

- [ ] **Step 3: Examples**

Run:

```bash
cd packages/zigeffect && zig build examples
```

Expected: exit 0.

- [ ] **Step 4: Bun package checks**

Run:

```bash
bun run zigeffect:test
bun run zig:test
```

Expected: both exit 0.

- [ ] **Step 5: Formatting and whitespace checks**

Run:

```bash
zig fmt --check packages/zigeffect/src/cluster/lease_guard.zig packages/zigeffect/src/cluster/envelope.zig packages/zigeffect/src/cluster/mailbox.zig packages/zigeffect/src/cluster/message_storage.zig packages/zigeffect/src/cluster/shard_lease.zig packages/zigeffect/src/cluster/runtime.zig packages/zigeffect/src/cluster/workflow_engine.zig packages/zigeffect/src/cluster/root.zig packages/zigeffect/src/zigeffect.zig packages/zigeffect/src/workflow/clock.zig packages/zigeffect/src/cluster/timer_wakeup.zig packages/zigeffect/test/production_shard_leasing_test.zig packages/zigeffect/test/all_test.zig
git diff --check
```

Expected: both exit 0.

- [ ] **Step 6: Marker scan**

Run:

```bash
pattern='T''BD|TO''DO|FIX''ME|st''ub|place''holder|not imple''mented|unimple''mented|fi''ll in|add app''ropriate|sim''ilar to'
rg -n "$pattern" packages/zigeffect/src/cluster/lease_guard.zig packages/zigeffect/src/cluster/envelope.zig packages/zigeffect/src/cluster/mailbox.zig packages/zigeffect/src/cluster/message_storage.zig packages/zigeffect/src/cluster/shard_lease.zig packages/zigeffect/src/cluster/runtime.zig packages/zigeffect/src/cluster/workflow_engine.zig packages/zigeffect/src/workflow/clock.zig packages/zigeffect/src/cluster/timer_wakeup.zig packages/zigeffect/test/production_shard_leasing_test.zig packages/zigeffect/docs/architecture.md packages/zigeffect/docs/effectts-parity.md packages/zigeffect/docs/usage.md docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md docs/superpowers/reports/2026-06-10-zigeffect-milestone-48-completion.md
```

Expected: exit 1 with no matches.

- [ ] **Step 7: Final commit if any verification-only changes occurred**

If formatting or docs edits changed files after Task 7, commit them:

```bash
git add <changed-files>
git commit -m "chore(zigeffect): polish production shard leasing"
```

## Self-Review

- Spec coverage: Every M48 deliverable maps to a task. Epoch writes are Task 2,
  guarded storage-backed fences are Task 3, runtime and workflow enforcement are
  Tasks 5 and 6, timing/audit/force release is Task 4, crash tests are spread
  across Tasks 3 through 6, and docs/report/roadmap are Task 7.
- Marker scan: the plan avoids unresolved marker words in prose and commands
  except inside the intentional scan regex.
- Type consistency: `ShardLeaseWriteGuard`, `ShardLeaseGuardedJournalStore`,
  `ShardLeaseWriteKind`, `lease_epoch`, `ShardLeaseAuditReport`, and
  `ShardLeaseForceReleaseReport` match the design spec.
