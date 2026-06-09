# zigeffect Message Storage Design

Date: 2026-06-10

## Purpose

Milestone 31 persists cluster messages independently of runner memory. It adds a
`MessageStorage` contract, in-memory and file-backed implementations, shard and
id lookup APIs for unprocessed messages, and durable ack/reply state.

## Current Context

Milestone 26 added `MessageEnvelope` and `MessageDeliveryTracker`. The tracker
already handles idempotent request submission, at-least-once claim attempts,
acks, reply storage, and duplicate reply detection, but it is process memory
only and is keyed by entity address rather than shard.

Milestone 27 added `ShardId` and deterministic address-to-shard helpers.
Milestone 30 added bounded shard ownership. Milestone 31 is the storage layer
that future cluster runtimes will read after they acquire a shard.

## Scope

This milestone adds durable local message storage only. It does not dispatch
messages to entity actors, run a cluster runtime, rebalance shards, or add
multi-runner transport. Those are Milestones 32 and later.

## Files

- `packages/zigeffect/src/cluster/message_storage.zig`: `MessageStorage`
  contract, record types, in-memory implementation, file-backed implementation,
  and JSON helpers.
- `packages/zigeffect/test/message_storage_test.zig`: contract, in-memory, and
  file-backed recovery tests.
- `packages/zigeffect/src/cluster/root.zig`: cluster namespace exports.
- `packages/zigeffect/src/zigeffect.zig`: top-level aliases.
- `packages/zigeffect/test/all_test.zig`: aggregate test import.
- `packages/zigeffect/docs/architecture.md`: storage module documentation.
- `docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md`:
  milestone closeout checkboxes.

## Public API

Add `cluster/message_storage.zig`:

```zig
pub const MessageStorageError = error{
    MessageNotFound,
    MissingRequest,
    DuplicateMessage,
    DuplicateReply,
    CorruptMessageFile,
};

pub const StoredMessageRecord = struct {
    shard_id: ShardId,
    envelope: MessageEnvelope,
    status: MessageDeliveryStatus = .pending,
    stored_at_ms: u64,
    updated_at_ms: u64,
};

pub const StoredReplyRecord = struct {
    shard_id: ShardId,
    envelope: MessageEnvelope,
    stored_at_ms: u64,
};

pub const MessageStorageSubmit = struct {
    shard_id: ShardId,
    envelope: MessageEnvelope,
    now_ms: u64 = 0,
};

pub const MessageStorageClaim = struct {
    shard_id: ShardId,
    message_id: MessageId,
    now_ms: u64 = 0,
};

pub const MessageStorageAck = struct {
    message_id: MessageId,
    now_ms: u64 = 0,
};

pub const MessageStorageReply = struct {
    shard_id: ShardId,
    envelope: MessageEnvelope,
    now_ms: u64 = 0,
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
```

The contract exposes:

```zig
pub fn submit(self: MessageStorage, request: MessageStorageSubmit) anyerror!MessageSubmitResult
pub fn claim(self: MessageStorage, request: MessageStorageClaim) anyerror!MessageEnvelope
pub fn ack(self: MessageStorage, request: MessageStorageAck) anyerror!void
pub fn storeReply(self: MessageStorage, request: MessageStorageReply) anyerror!MessageEnvelope
pub fn reply(self: MessageStorage, correlation_id: MessageCorrelationId, allocator: Allocator) anyerror!?MessageEnvelope
pub fn unprocessedByShard(self: MessageStorage, shard_id: ShardId, allocator: Allocator) anyerror!MessageRecordBatch
pub fn unprocessedById(self: MessageStorage, message_id: MessageId, allocator: Allocator) anyerror!?StoredMessageRecord
pub fn reset(self: MessageStorage) void
```

## In-Memory Storage

`InMemoryMessageStorage` owns:

```zig
messages: std.ArrayList(StoredMessageRecord)
replies: std.ArrayList(StoredReplyRecord)
```

Submission clones the envelope, computes `MessageId` and correlation id using
the same rules as `MessageDeliveryTracker`, and returns `duplicate = true` when
an existing message has the same kind, address, and idempotency key. Duplicate
submission returns a cloned existing envelope and does not create another
record.

`claim` finds an unprocessed message by id and shard, sets status to `.claimed`,
increments attempt, updates `updated_at_ms`, and returns a cloned envelope.
Claimed messages remain unprocessed until acked, replied, or interrupted.

`ack` marks the message `.acknowledged`.

`storeReply` requires a correlation id and a matching request. It rejects a
second reply for the same correlation id, stores the reply, and marks the
request `.replied`. Replies are durable independently from request status.

Unprocessed records are statuses `.pending` and `.claimed`. Acknowledged,
replied, and interrupted messages are excluded from unprocessed queries.

## File-Backed Storage

`FileMessageStorage` mirrors in-memory semantics using per-record JSON files:

- `cluster-message-{message_id}.json` for message records.
- `cluster-reply-{correlation_id}.json` for replies.

Each write uses `std.Io.Dir.createFileAtomic(..., .{ .replace = true })`. New
message submission may use exclusive create for first-write idempotency, then
fall back to reading an existing file to detect duplicates. This local model is
safe for multiple store instances in the same filesystem directory.

JSON schemas:

```zig
pub const message_record_schema = "zigeffect.cluster.message-record.v1";
pub const message_record_schema_version: u32 = 1;
pub const message_reply_schema = "zigeffect.cluster.message-reply.v1";
pub const message_reply_schema_version: u32 = 1;
```

The JSON stores all numeric envelope fields plus strings for entity type,
idempotency key, payload type, payload, and redacted detail. Parse helpers own
the string copies in returned envelopes and callers must deinitialize with the
storage batch or `deinitMessageEnvelope`.

## Recovery Semantics

Recovery is simply reopening `FileMessageStorage` over the same directory.
Because message and reply records are authoritative JSON files:

- unprocessed pending/claimed messages are returned by `unprocessedByShard`.
- acknowledged/replied messages are not returned as unprocessed.
- replies remain queryable by correlation id even after reopen.

This directly proves the Milestone 31 acceptance condition: recovery replays
unprocessed messages without losing replies.

## Tests

Add tests for:

- public exports for `MessageStorage`, `InMemoryMessageStorage`, and
  `FileMessageStorage`.
- in-memory submit idempotency and duplicate detection.
- in-memory unprocessed-by-shard and unprocessed-by-id filtering.
- in-memory claim increments attempts and ack removes a message from
  unprocessed queries.
- in-memory reply storage requires a request, rejects duplicate replies, and
  removes the request from unprocessed queries.
- file-backed submit persists across reopen.
- file-backed unprocessed-by-shard returns pending/claimed messages after
  reopen.
- file-backed ack excludes a message after reopen.
- file-backed reply survives reopen and duplicate reply detection still works.

## Acceptance Mapping

- `MessageStorage` contract: vtable plus request and record types.
- In-memory message storage: `InMemoryMessageStorage`.
- File-backed message storage: `FileMessageStorage`.
- Unprocessed messages by shard: `unprocessedByShard`.
- Unprocessed messages by id: `unprocessedById`.
- Ack and reply storage: `ack`, `storeReply`, and `reply`.
- Recovery replay: file-backed reopen tests prove unprocessed messages and
  replies are restored from disk.
