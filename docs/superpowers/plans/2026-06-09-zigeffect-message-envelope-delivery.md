# zigeffect Message Envelope And Delivery Semantics Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the cluster message protocol surface and deterministic in-memory delivery tracker for duplicate detection, at-least-once retry, reply correlation, and redacted diagnostics.

**Architecture:** Add `src/cluster/envelope.zig` beside the local entity actor modules. Keep `EntityEnvelope` unchanged for local actor ergonomics; `MessageEnvelope` becomes the durable protocol type later storage and transport milestones will use. Tests live in a new `message_envelope_test.zig`.

**Tech Stack:** Zig, `std.hash.Fnv1a_64`, unmanaged `std.ArrayList`, existing cluster identity helpers, Bun/Zig test commands.

---

## Task 1: Envelope Surface, Stable Ids, And Exports

**Files:**
- Create: `packages/zigeffect/src/cluster/envelope.zig`
- Create: `packages/zigeffect/test/message_envelope_test.zig`
- Modify: `packages/zigeffect/src/cluster/root.zig`
- Modify: `packages/zigeffect/src/zigeffect.zig`
- Modify: `packages/zigeffect/test/all_test.zig`

- [ ] **Step 1: Write failing public export and id tests**

Create `packages/zigeffect/test/message_envelope_test.zig`:

```zig
const std = @import("std");
const fx = @import("zigeffect");

test "message envelope public exports and ids are stable" {
    try std.testing.expect(@hasDecl(fx.cluster, "envelope"));
    try std.testing.expect(@hasDecl(fx.cluster, "MessageEnvelope"));
    try std.testing.expect(@hasDecl(fx.cluster, "MessageDeliveryTracker"));
    try std.testing.expect(@hasDecl(fx, "MessageEnvelope"));

    const address = fx.entityAddress("counter", "one");
    const first = fx.messageId(address, .request, "counter:one:1");
    const second = fx.messageId(address, .request, "counter:one:1");
    const other_key = fx.messageId(address, .request, "counter:one:2");
    const other_kind = fx.messageId(address, .interrupt, "counter:one:1");

    try std.testing.expectEqual(first, second);
    try std.testing.expect(first != other_key);
    try std.testing.expect(first != other_kind);
    try std.testing.expectEqual(first, fx.messageCorrelationId(first));
}
```

Add to `packages/zigeffect/test/all_test.zig`:

```zig
    _ = @import("message_envelope_test.zig");
```

- [ ] **Step 2: Run red**

Run:

```bash
cd packages/zigeffect && zig build test-raw --summary all
```

Expected: failure because message envelope exports do not exist.

- [ ] **Step 3: Implement envelope structs, ids, clone/free, and exports**

Create `packages/zigeffect/src/cluster/envelope.zig` with the types from the design spec, plus `cloneMessageEnvelope`, `deinitMessageEnvelope`, `messageId`, and `messageCorrelationId`.

`messageId` must hash `address.entity_type.name`, `address.id`, `@tagName(kind)`, and `idempotency_key` using `std.hash.Fnv1a_64`.

Update `cluster/root.zig` and `zigeffect.zig` to export all message protocol types and helper functions.

- [ ] **Step 4: Run green**

Run:

```bash
cd packages/zigeffect && zig build test-raw --summary all
```

Expected: all tests pass.

- [ ] **Step 5: Commit**

Run:

```bash
zig fmt --check packages/zigeffect/src/cluster/envelope.zig packages/zigeffect/src/cluster/root.zig packages/zigeffect/src/zigeffect.zig packages/zigeffect/test/message_envelope_test.zig packages/zigeffect/test/all_test.zig
git add packages/zigeffect/src/cluster/envelope.zig packages/zigeffect/src/cluster/root.zig packages/zigeffect/src/zigeffect.zig packages/zigeffect/test/message_envelope_test.zig packages/zigeffect/test/all_test.zig
git commit -m "feat(zigeffect): add cluster message envelopes"
```

## Task 2: Delivery Tracker Semantics

**Files:**
- Modify: `packages/zigeffect/src/cluster/envelope.zig`
- Modify: `packages/zigeffect/test/message_envelope_test.zig`

- [ ] **Step 1: Write failing delivery tests**

Append tests covering duplicate request submission, retry before ack, ack removal, missing reply, duplicate reply, and redacted diagnostics.

Use these exact test names:

- `message delivery tracker detects duplicate request idempotency`
- `message delivery tracker retries unacked claims at least once`
- `message delivery tracker validates missing and duplicate replies`
- `message diagnostics redact raw payload`

- [ ] **Step 2: Run red**

Run:

```bash
cd packages/zigeffect && zig build test-raw --summary all
```

Expected: failure because `MessageDeliveryTracker` behavior is incomplete.

- [ ] **Step 3: Implement tracker**

In `envelope.zig`, implement `MessageSubmitResult` and `MessageDeliveryTracker`.

Internal state:

```zig
const StoredMessage = struct {
    envelope: MessageEnvelope,
    status: MessageDeliveryStatus = .pending,
};
```

Tracker fields:

```zig
allocator: Allocator,
messages: std.ArrayList(StoredMessage) = .empty,
replies: std.ArrayList(MessageEnvelope) = .empty,
```

Semantics:

- `submit` clones the first message for each address/kind/idempotency key and returns `duplicate = true` for later matching submissions.
- `claimNext` returns the oldest pending or claimed message for an address, increments attempt, and leaves it claimable until ack.
- `ack` marks a message acknowledged or returns `error.MessageNotFound`.
- `storeReply` requires a known request correlation, returns `error.MissingRequest` when absent, and returns `error.DuplicateReply` for a second reply with the same correlation.
- `pendingCount` counts non-acknowledged messages for the address.
- `formatMessageDiagnostic` omits payload bytes and includes redacted detail.

- [ ] **Step 4: Run green**

Run:

```bash
cd packages/zigeffect && zig build test-raw --summary all
```

Expected: all tests pass.

- [ ] **Step 5: Commit**

Run:

```bash
zig fmt --check packages/zigeffect/src/cluster/envelope.zig packages/zigeffect/test/message_envelope_test.zig
git add packages/zigeffect/src/cluster/envelope.zig packages/zigeffect/test/message_envelope_test.zig
git commit -m "feat(zigeffect): add message delivery tracker"
```

## Task 3: Docs, Roadmap, And Full Verification

**Files:**
- Modify: `packages/zigeffect/docs/architecture.md`
- Modify: `docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md`

- [ ] **Step 1: Update docs and roadmap**

Add `envelope.zig` to the `src/cluster/` architecture list as the durable cluster message protocol with ids, idempotency, request/reply/ack/interrupt/chunk-reply envelopes, at-least-once tracking, and redacted diagnostics.

Mark all Milestone 26 deliverables and acceptance as `[x]`.

- [ ] **Step 2: Run full gate**

Run:

```bash
bun run zigeffect:test
cd packages/zigeffect && zig build examples
bun run zig:test
zig fmt --check packages/zigeffect/src/cluster/envelope.zig packages/zigeffect/src/cluster/root.zig packages/zigeffect/src/zigeffect.zig packages/zigeffect/test/message_envelope_test.zig packages/zigeffect/test/all_test.zig
git diff --check
rg -n 'TO''DO|TB''D|implement'' later|fill'' in' packages/zigeffect/src/cluster packages/zigeffect/test/message_envelope_test.zig packages/zigeffect/docs/architecture.md docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md
```

Expected: test/build/format/diff commands exit 0; the placeholder scan exits 1 with no matches.

- [ ] **Step 3: Commit docs**

Run:

```bash
git add packages/zigeffect/docs/architecture.md docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md
git commit -m "docs(zigeffect): mark message envelopes complete"
```
