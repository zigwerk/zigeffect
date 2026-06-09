# zigeffect Message Envelope And Delivery Semantics Design

Date: 2026-06-09

## Context

Milestone 25 added local entity identity, runtime-bound refs, in-memory
mailboxes, local ask/tell/reply/interrupt operations, and supervisor-backed
handler recovery. Milestone 26 defines the durable message protocol that later
message storage, shard routing, and multi-runner transport will persist and
move across runners.

The existing `EntityEnvelope` remains a local actor convenience type. Milestone
26 adds `cluster/envelope.zig` as the shared protocol surface for durable
cluster delivery.

## Goals

- Add stable message ids and idempotency keys.
- Add request, reply, ack, interrupt, and chunk-reply envelope kinds.
- Add typed correlation ids for request/reply relationships.
- Add an in-memory delivery tracker that models at-least-once delivery.
- Detect duplicate request submissions by idempotency key.
- Detect duplicate replies for the same request correlation.
- Report missing replies for unknown request correlations.
- Provide redacted diagnostics that include ids, kind, attempts, and redacted
  detail without printing raw payload bytes.
- Export protocol types through `fx.cluster` and top-level aliases.

## Boundary

This milestone does not persist envelopes to disk, lease shards, route by shard,
or send messages over a transport. It provides deterministic protocol structs
and an in-memory delivery tracker used by tests and later storage milestones.

## Public API

Create `packages/zigeffect/src/cluster/envelope.zig`.

```zig
pub const MessageId = u64;
pub const MessageCorrelationId = u64;
pub const MessageAttempt = u32;

pub const MessageEnvelopeKind = enum {
    request,
    reply,
    ack,
    interrupt,
    chunk_reply,
};

pub const MessageDeliveryStatus = enum {
    pending,
    claimed,
    acknowledged,
    replied,
    interrupted,
};

pub const MessageEnvelope = struct {
    id: MessageId = 0,
    kind: MessageEnvelopeKind,
    address: EntityAddress,
    correlation_id: ?MessageCorrelationId = null,
    idempotency_key: []const u8 = "",
    attempt: MessageAttempt = 0,
    chunk_index: ?u32 = null,
    chunk_count: ?u32 = null,
    payload_type_name: []const u8 = "",
    payload: []const u8 = "",
    redacted_detail: []const u8 = "",
};

pub const MessageDeliveryError = error{
    MessageNotFound,
    MissingRequest,
    DuplicateReply,
};
```

Functions:

```zig
pub fn messageId(address: EntityAddress, kind: MessageEnvelopeKind, idempotency_key: []const u8) MessageId;
pub fn messageCorrelationId(message_id: MessageId) MessageCorrelationId;
pub fn cloneMessageEnvelope(allocator: Allocator, envelope: MessageEnvelope) Allocator.Error!MessageEnvelope;
pub fn deinitMessageEnvelope(allocator: Allocator, envelope: MessageEnvelope) void;
pub fn formatMessageDiagnostic(allocator: Allocator, envelope: MessageEnvelope) Allocator.Error![]const u8;
```

Delivery tracker:

```zig
pub const MessageSubmitResult = struct {
    envelope: MessageEnvelope,
    duplicate: bool = false,

    pub fn deinit(self: *MessageSubmitResult, allocator: Allocator) void;
};

pub const MessageDeliveryTracker = struct {
    pub fn init(allocator: Allocator) MessageDeliveryTracker;
    pub fn deinit(self: *MessageDeliveryTracker) void;

    pub fn submit(self: *MessageDeliveryTracker, envelope: MessageEnvelope) Allocator.Error!MessageSubmitResult;
    pub fn claimNext(self: *MessageDeliveryTracker, address: EntityAddress) (Allocator.Error || MessageDeliveryError)!MessageEnvelope;
    pub fn ack(self: *MessageDeliveryTracker, message_id: MessageId) MessageDeliveryError!void;
    pub fn storeReply(self: *MessageDeliveryTracker, reply: MessageEnvelope) (Allocator.Error || MessageDeliveryError)!MessageEnvelope;
    pub fn pendingCount(self: *const MessageDeliveryTracker, address: EntityAddress) usize;
};
```

## Behavior

`messageId` hashes the entity type, entity id, message kind, and idempotency key
with `std.hash.Fnv1a_64`. Empty idempotency keys are allowed for tests, but
cluster callers should provide stable keys once message storage lands.

`submit` fills a missing message id from `messageId`, fills a missing
correlation id for request envelopes, and stores the first envelope for an
idempotency key. A repeated request with the same address, kind, and
idempotency key returns the original envelope with `duplicate = true` and does
not append another pending message.

`claimNext` returns the oldest non-acknowledged message for the address and
increments its attempt. Calling `claimNext` again before `ack` returns the same
message with a higher attempt, modeling at-least-once retry.

`ack` marks a message acknowledged. Acknowledged messages are no longer returned
by `claimNext`.

`storeReply` requires a known request correlation. The first reply for a request
is stored. A second reply for the same correlation returns
`error.DuplicateReply`. A reply for an unknown correlation returns
`error.MissingRequest`.

`formatMessageDiagnostic` never includes `payload`. It includes
`redacted_detail`, ids, kind, type name, attempt, chunk metadata, and
correlation id.

## Tests

Add `packages/zigeffect/test/message_envelope_test.zig` and import it from
`all_test.zig`.

Required coverage:

- public exports and stable message id derivation;
- duplicate request submission by idempotency key;
- at-least-once retry through repeated claim before ack;
- ack removes messages from claimable pending set;
- missing reply correlation returns `MissingRequest`;
- duplicate reply returns `DuplicateReply`;
- diagnostics include redacted detail and exclude raw payload.

## Documentation

Update `packages/zigeffect/docs/architecture.md` to list `envelope.zig` under
`src/cluster/`.

Update the roadmap after the full gate by marking Milestone 26 complete.
