# zigeffect Message Storage Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add durable cluster message storage with a vtable contract, in-memory and file-backed stores, unprocessed lookups, and durable ack/reply recovery.

**Architecture:** Introduce `cluster/message_storage.zig` beside `envelope.zig`. The storage contract owns shard-aware message records and reply records while reusing `MessageEnvelope`, `MessageDeliveryStatus`, `MessageSubmitResult`, and clone/deinit helpers from the envelope module.

**Tech Stack:** Zig, `std.ArrayList`, `std.json.parseFromSlice`, `std.Io.Dir`, `std.testing.tmpDir`, `bun run zigeffect:test`, `zig build examples`, `bun run zig:test`.

---

## File Structure

- Create `packages/zigeffect/src/cluster/message_storage.zig`: message storage contract, request/record/batch types, in-memory store, file-backed store, and JSON helpers.
- Create `packages/zigeffect/test/message_storage_test.zig`: tests for exports, in-memory semantics, file-backed persistence, and recovery.
- Modify `packages/zigeffect/src/cluster/root.zig`: import and re-export message storage APIs.
- Modify `packages/zigeffect/src/zigeffect.zig`: top-level aliases.
- Modify `packages/zigeffect/test/all_test.zig`: import `message_storage_test.zig`.
- Modify `packages/zigeffect/docs/architecture.md`: document `message_storage.zig`.
- Modify `docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md`: mark Milestone 31 complete after verification.
- Modify `docs/superpowers/plans/2026-06-10-zigeffect-message-storage.md`: mark plan checkboxes complete during closeout.

## Task 1: Contract And In-Memory Submit/Lookup

**Files:**
- Create: `packages/zigeffect/test/message_storage_test.zig`
- Create: `packages/zigeffect/src/cluster/message_storage.zig`
- Modify: `packages/zigeffect/src/cluster/root.zig`
- Modify: `packages/zigeffect/src/zigeffect.zig`
- Modify: `packages/zigeffect/test/all_test.zig`

- [ ] **Step 1: Write failing export and in-memory submit tests**

Create `packages/zigeffect/test/message_storage_test.zig`:

```zig
const std = @import("std");
const fx = @import("zigeffect");

test "message storage public exports are available" {
    try std.testing.expect(@hasDecl(fx.cluster, "message_storage"));
    try std.testing.expect(@hasDecl(fx.cluster, "MessageStorage"));
    try std.testing.expect(@hasDecl(fx.cluster, "StoredMessageRecord"));
    try std.testing.expect(@hasDecl(fx.cluster, "MessageStorageSubmit"));
    try std.testing.expect(@hasDecl(fx.cluster, "InMemoryMessageStorage"));
    try std.testing.expect(@hasDecl(fx.cluster, "FileMessageStorage"));
    try std.testing.expect(@hasDecl(fx, "MessageStorage"));
}

test "in-memory message storage submits idempotently and lists unprocessed by shard" {
    var storage_state = fx.InMemoryMessageStorage.init(std.testing.allocator);
    defer storage_state.deinit();
    const storage = storage_state.asMessageStorage();
    const address = fx.entityAddress("counter", "one");

    var first = try storage.submit(.{
        .shard_id = 3,
        .now_ms = 1_000,
        .envelope = .{
            .kind = .request,
            .address = address,
            .idempotency_key = "counter:one:1",
            .payload_type_name = "text",
            .payload = "inc",
        },
    });
    defer first.deinit(std.testing.allocator);
    var duplicate = try storage.submit(.{
        .shard_id = 3,
        .now_ms = 1_001,
        .envelope = .{
            .kind = .request,
            .address = address,
            .idempotency_key = "counter:one:1",
            .payload_type_name = "text",
            .payload = "inc-again",
        },
    });
    defer duplicate.deinit(std.testing.allocator);

    try std.testing.expect(!first.duplicate);
    try std.testing.expect(duplicate.duplicate);
    try std.testing.expectEqual(first.envelope.id, duplicate.envelope.id);

    var by_shard = try storage.unprocessedByShard(3, std.testing.allocator);
    defer by_shard.deinit();
    try std.testing.expectEqual(@as(usize, 1), by_shard.records.len);
    try std.testing.expectEqual(first.envelope.id, by_shard.records[0].envelope.id);

    var by_id = (try storage.unprocessedById(first.envelope.id, std.testing.allocator)).?;
    defer by_id.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(fx.ShardId, 3), by_id.shard_id);
}
```

Add this import to `packages/zigeffect/test/all_test.zig`:

```zig
    _ = @import("message_storage_test.zig");
```

- [ ] **Step 2: Run the red test**

Run:

```bash
bun run zigeffect:test
```

Expected: FAIL with missing `InMemoryMessageStorage`, `MessageStorage`, or
record types. Use `zig build test-raw` from `packages/zigeffect` if needed.

- [ ] **Step 3: Implement contract and in-memory submit/lookup**

Implement:

```zig
pub const StoredMessageRecord = struct {
    shard_id: ShardId,
    envelope: MessageEnvelope,
    status: MessageDeliveryStatus = .pending,
    stored_at_ms: u64,
    updated_at_ms: u64,

    pub fn deinit(self: *StoredMessageRecord, allocator: Allocator) void;
};

pub const MessageRecordBatch = struct {
    allocator: Allocator,
    records: []StoredMessageRecord,
    pub fn deinit(self: *MessageRecordBatch) void;
};

pub const MessageStorage = struct {
    context: *anyopaque,
    vtable: *const VTable,
};

pub const InMemoryMessageStorage = struct {
    allocator: Allocator,
    messages: std.ArrayList(StoredMessageRecord) = .empty,
    replies: std.ArrayList(StoredReplyRecord) = .empty,

    pub fn init(allocator: Allocator) InMemoryMessageStorage;
    pub fn deinit(self: *InMemoryMessageStorage) void;
    pub fn asMessageStorage(self: *InMemoryMessageStorage) MessageStorage;
};
pub const FileMessageStorage = struct {};
```

For Task 1, `claim`, `ack`, `storeReply`, and `reply` may return
`MessageNotFound` or `MissingRequest`; Task 2 drives their complete behavior.

- [ ] **Step 4: Run green checks**

Run:

```bash
bun run zigeffect:test
zig fmt --check packages/zigeffect/src/cluster/message_storage.zig packages/zigeffect/src/cluster/root.zig packages/zigeffect/src/zigeffect.zig packages/zigeffect/test/message_storage_test.zig packages/zigeffect/test/all_test.zig
git diff --check
```

Expected: all commands exit 0.

- [ ] **Step 5: Commit contract and in-memory submit**

```bash
git add packages/zigeffect/src/cluster/message_storage.zig packages/zigeffect/src/cluster/root.zig packages/zigeffect/src/zigeffect.zig packages/zigeffect/test/message_storage_test.zig packages/zigeffect/test/all_test.zig
git commit -m "feat(zigeffect): add message storage contract"
```

## Task 2: In-Memory Claim, Ack, And Reply

**Files:**
- Modify: `packages/zigeffect/test/message_storage_test.zig`
- Modify: `packages/zigeffect/src/cluster/message_storage.zig`

- [ ] **Step 1: Add failing in-memory claim, ack, and reply tests**

Append tests named exactly:

- `in-memory message storage claims and acks unprocessed messages`: submit two
  messages to shard 4 and one message to shard 5, claim by message id on shard
  4, verify attempt increments to 1, verify claimed messages remain
  unprocessed, ack the claimed message, and verify it disappears from
  `unprocessedByShard` and `unprocessedById`.
- `in-memory message storage persists replies and removes replied requests from
  unprocessed queries`: call `storeReply` without a matching request and expect
  `MissingRequest`, store a valid reply, verify `reply(correlation_id)` returns
  it, store a duplicate reply and expect `DuplicateReply`, then verify the
  replied request is excluded from unprocessed queries.

- [ ] **Step 2: Run the red test**

Run:

```bash
bun run zigeffect:test
```

Expected: FAIL on incomplete in-memory claim/ack/reply behavior.

- [ ] **Step 3: Implement complete in-memory delivery semantics**

Implement:

- `claim`: finds by shard and message id, requires unprocessed status, marks
  `.claimed`, increments `attempt`, updates `updated_at_ms`, returns clone.
- `ack`: finds message by id, marks `.acknowledged`, updates `updated_at_ms`.
- `storeReply`: validates correlation id, finds matching request, rejects
  duplicate replies, stores reply, marks request `.replied`.
- `reply`: returns a cloned reply by correlation id.
- `reset`: deinitializes records and clears both arrays.

- [ ] **Step 4: Run green checks**

Run:

```bash
bun run zigeffect:test
zig fmt --check packages/zigeffect/src/cluster/message_storage.zig packages/zigeffect/test/message_storage_test.zig
git diff --check
```

Expected: all commands exit 0.

- [ ] **Step 5: Commit in-memory delivery semantics**

```bash
git add packages/zigeffect/src/cluster/message_storage.zig packages/zigeffect/test/message_storage_test.zig
git commit -m "feat(zigeffect): process in-memory stored messages"
```

## Task 3: File-Backed Submit And Recovery

**Files:**
- Modify: `packages/zigeffect/test/message_storage_test.zig`
- Modify: `packages/zigeffect/src/cluster/message_storage.zig`
- Modify: `packages/zigeffect/src/cluster/root.zig`
- Modify: `packages/zigeffect/src/zigeffect.zig`

- [ ] **Step 1: Add failing file-backed submit and reopen tests**

Append tests named exactly:

- `stored message record json round-trips`: round-trip
  `formatStoredMessageRecordJson` and `parseStoredMessageRecordJson`.
- `file message storage replays unprocessed messages after reopen`: create
  `FileMessageStorage.open(std.testing.allocator, std.testing.io, &tmp.dir,
  .{})`, submit a message to shard 7, reopen another store over the same
  directory, and verify `unprocessedByShard(7)` returns the message.
- `file message storage detects duplicate submissions after reopen`: submit the
  same idempotency key through the reopened store and verify `duplicate = true`.

- [ ] **Step 2: Run the red test**

Run:

```bash
bun run zigeffect:test
```

Expected: FAIL on missing file store and JSON helpers.

- [ ] **Step 3: Implement file-backed message record JSON and submit/reopen**

Implement:

- `FileMessageStorageOptions`.
- `FileMessageStorage.open`, `deinit`, and `asMessageStorage`.
- `messageRecordFileName` and `replyRecordFileName`.
- `formatStoredMessageRecordJson` and `parseStoredMessageRecordJson`.
- file-backed `submit`, `unprocessedByShard`, `unprocessedById`, and `reset`.

- [ ] **Step 4: Run green checks**

Run:

```bash
bun run zigeffect:test
zig fmt --check packages/zigeffect/src/cluster/message_storage.zig packages/zigeffect/src/cluster/root.zig packages/zigeffect/src/zigeffect.zig packages/zigeffect/test/message_storage_test.zig
git diff --check
```

Expected: all commands exit 0.

- [ ] **Step 5: Commit file-backed submit and recovery**

```bash
git add packages/zigeffect/src/cluster/message_storage.zig packages/zigeffect/src/cluster/root.zig packages/zigeffect/src/zigeffect.zig packages/zigeffect/test/message_storage_test.zig
git commit -m "feat(zigeffect): persist stored messages to files"
```

## Task 4: File-Backed Ack, Reply, And Recovery

**Files:**
- Modify: `packages/zigeffect/test/message_storage_test.zig`
- Modify: `packages/zigeffect/src/cluster/message_storage.zig`

- [ ] **Step 1: Add failing file-backed ack and reply tests**

Append tests named exactly:

- `file message storage recovers acked status after reopen`: claim and ack a
  file-backed message, reopen the store, and verify the message is excluded from
  `unprocessedByShard` and `unprocessedById`.
- `file message storage recovers replies after reopen`: store a reply, reopen
  the store, verify `reply(correlation_id)` returns it, and verify duplicate
  reply detection survives reopen.
- `file message storage recovery keeps unprocessed messages and replies`: leave
  one pending message and one claimed message unacked, store a reply for a
  separate request, reopen the store, and verify the pending/claimed messages
  replay while the reply is still available.

- [ ] **Step 2: Run the red test**

Run:

```bash
bun run zigeffect:test
```

Expected: FAIL on incomplete file ack/reply behavior.

- [ ] **Step 3: Implement file-backed ack, claim, reply, and duplicate checks**

Implement:

- file-backed `claim` as atomic update of the message JSON.
- file-backed `ack` as atomic status update.
- `formatStoredReplyRecordJson` and `parseStoredReplyRecordJson`.
- file-backed `storeReply` with request validation, duplicate reply detection,
  reply JSON write, and request status `.replied`.
- file-backed `reply` lookup by correlation id.

- [ ] **Step 4: Run green checks**

Run:

```bash
bun run zigeffect:test
zig fmt --check packages/zigeffect/src/cluster/message_storage.zig packages/zigeffect/test/message_storage_test.zig
git diff --check
```

Expected: all commands exit 0.

- [ ] **Step 5: Commit file-backed ack and reply**

```bash
git add packages/zigeffect/src/cluster/message_storage.zig packages/zigeffect/test/message_storage_test.zig
git commit -m "feat(zigeffect): recover stored message replies"
```

## Task 5: Documentation, Roadmap, And Verification

**Files:**
- Modify: `packages/zigeffect/docs/architecture.md`
- Modify: `docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md`
- Modify: `docs/superpowers/plans/2026-06-10-zigeffect-message-storage.md`

- [ ] **Step 1: Update architecture docs**

Add this bullet in the `src/cluster/` section:

```markdown
- `message_storage.zig`: shard-aware message storage contract, in-memory and
  file-backed message/reply persistence, unprocessed message lookups, and
  durable ack/reply recovery.
```

- [ ] **Step 2: Mark Milestone 31 complete in the roadmap**

Change every Milestone 31 deliverable and acceptance checkbox from `[ ]` to
`[x]`.

- [ ] **Step 3: Mark this implementation plan complete**

Change every checkbox in this file from `[ ]` to `[x]`.

- [ ] **Step 4: Run the full Milestone 31 verification gate**

Run:

```bash
bun run zigeffect:test
zig build examples
bun run zig:test
zig fmt --check packages/zigeffect/src/cluster/message_storage.zig packages/zigeffect/src/cluster/root.zig packages/zigeffect/src/zigeffect.zig packages/zigeffect/test/message_storage_test.zig packages/zigeffect/test/all_test.zig
git diff --check
rg -n 'TO''DO|TB''D|implement'' later|fill'' in' packages/zigeffect/src/cluster packages/zigeffect/test/message_storage_test.zig packages/zigeffect/docs/architecture.md docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md docs/superpowers/specs/2026-06-10-zigeffect-message-storage-design.md docs/superpowers/plans/2026-06-10-zigeffect-message-storage.md
```

Run `zig build examples` from `packages/zigeffect`. Run the other commands from
the repository root. Expected: build/test/format/diff commands exit 0. The
placeholder scan exits 1 with no matches.

- [ ] **Step 5: Commit docs and roadmap**

```bash
git add packages/zigeffect/docs/architecture.md docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md docs/superpowers/plans/2026-06-10-zigeffect-message-storage.md
git commit -m "docs(zigeffect): mark message storage complete"
```
