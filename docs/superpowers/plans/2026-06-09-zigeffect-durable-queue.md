# zigeffect Durable Queue Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add durable queues with typed definitions, idempotent offers, worker claiming, concurrency limits, completion/failure/ack events, claim timeout retry, workflow awaiting, and file-store restart coverage.

**Architecture:** Add `workflow/queue.zig` for queue definitions and external worker APIs. Extend the journal event model with `queue_retry_scheduled` so retry is a first-class durable state transition. Wire `WorkflowContext.queue` for workflow-side offer-and-await. Keep storage append-only and use only `JournalStore` so in-memory and file stores behave the same.

**Tech Stack:** Zig 0.16, existing `Codec`, `Schedule`-style clock semantics where needed, `JournalStore`, `WorkflowContext`, `FileJournalStore`, Bun project scripts.

---

## File Structure

- Create `packages/zigeffect/src/workflow/queue.zig`
  - Owns `Queue`, `QueueMetadata`, `QueueClaim`, `QueueAwaitResult`,
    `DurableQueue`, `queueItemId`, claim detail parsing, and queue
    idempotency helpers.
- Modify `packages/zigeffect/src/workflow/journal.zig`
  - Adds `queue_retry_scheduled` event kind and formatter/parser names.
- Modify `packages/zigeffect/src/workflow/replay.zig`
  - Adds `QueueStatus.retry_ready` and folds retry rows.
- Modify `packages/zigeffect/src/workflow/context.zig`
  - Adds `queue` workflow await helper.
- Modify `packages/zigeffect/src/workflow/root.zig`
  - Exposes queue module names.
- Modify `packages/zigeffect/test/workflow_test.zig`
  - Adds queue definition, offer, claim, complete/fail/ack, retry timeout,
    workflow await, and file-store tests.
- Modify `packages/zigeffect/docs/architecture.md`
  - Documents durable queue ownership.
- Modify `docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md`
  - Marks Milestone 16 complete after the full gate.

## Task 1: Queue Event Model And Definitions

**Files:**
- Modify `packages/zigeffect/src/workflow/journal.zig`
- Modify `packages/zigeffect/src/workflow/replay.zig`
- Create `packages/zigeffect/src/workflow/queue.zig`
- Modify `packages/zigeffect/src/workflow/root.zig`
- Modify `packages/zigeffect/test/workflow_test.zig`

- [ ] **Step 1: Write failing event/definition tests**

Add tests for `queue_retry_scheduled` event kind formatting, retry folding to
`QueueStatus.retry_ready`, stable `queueItemId`, `Queue(...).metadata()`,
`withClaimTimeoutMs`, `withMaxConcurrency`, and `withIdempotencyKey`.

- [ ] **Step 2: Verify red**

Run:

```bash
cd packages/zigeffect && zig build test-raw --summary all
```

Expected: FAIL until queue retry and queue definition exports exist.

- [ ] **Step 3: Implement event/model shell**

Add `queue_retry_scheduled`, `QueueStatus.retry_ready`, queue definition
metadata, item id derivation, wait/claim result types, and `DurableQueue.init`.

- [ ] **Step 4: Verify green**

Run:

```bash
bun run zigeffect:test
```

Expected: PASS.

## Task 2: Idempotent Offer And File Persistence

**Files:**
- Modify `packages/zigeffect/src/workflow/queue.zig`
- Modify `packages/zigeffect/test/workflow_test.zig`

- [ ] **Step 1: Write failing offer tests**

Offer a queue item with a typed idempotency key and payload codec. Assert
`queue_offered`, payload detail, stable queue id, duplicate offer returns false,
and the offered row survives `FileJournalStore` reopen.

- [ ] **Step 2: Verify red**

Run:

```bash
cd packages/zigeffect && zig build test-raw --summary all
```

Expected: FAIL until `DurableQueue.offer` exists.

- [ ] **Step 3: Implement offer**

Encode payloads, require typed idempotency keys, derive item ids, append
`queue_offered` with deterministic idempotency, convert duplicate append keys
to false, and return the queue item id.

- [ ] **Step 4: Verify green**

Run:

```bash
bun run zigeffect:test
```

Expected: PASS.

## Task 3: Claim And Concurrency Limits

**Files:**
- Modify `packages/zigeffect/src/workflow/queue.zig`
- Modify `packages/zigeffect/test/workflow_test.zig`

- [ ] **Step 1: Write failing claim/concurrency tests**

Offer two items to a queue with max concurrency 1. Assert the first claim
returns the oldest payload and appends `queue_claimed`; a second concurrent
claim returns null until the first item completes or retries.

- [ ] **Step 2: Verify red**

Run:

```bash
cd packages/zigeffect && zig build test-raw --summary all
```

Expected: FAIL until claim and active-claim counting exist.

- [ ] **Step 3: Implement claim**

Scan current journal state, count active claimed items, decode the oldest
offered/retry-ready item, append `queue_claimed` with worker and deadline
metadata, and return `QueueClaim(Payload)`.

- [ ] **Step 4: Verify green**

Run:

```bash
bun run zigeffect:test
```

Expected: PASS.

## Task 4: Complete, Fail, Ack, And Workflow Await

**Files:**
- Modify `packages/zigeffect/src/workflow/queue.zig`
- Modify `packages/zigeffect/src/workflow/context.zig`
- Modify `packages/zigeffect/test/workflow_test.zig`

- [ ] **Step 1: Write failing completion/await tests**

Use `WorkflowContext.queue(QueueType, payload_codec, result_codec, payload)`.
Assert missing completion offers/suspends, `DurableQueue.complete` appends
`queue_completed` plus `workflow_resumed`, replay returns decoded success,
appends `queue_acked`, and a later replay returns the same success without
duplicate ack. Add a failure path that returns typed failure and acks.

- [ ] **Step 2: Verify red**

Run:

```bash
cd packages/zigeffect && zig build test-raw --summary all
```

Expected: FAIL until complete/fail/ack and workflow await exist.

- [ ] **Step 3: Implement complete/fail/ack and workflow await**

Append terminal rows, wake suspended workflows, replay completion/failure
details, append ack once, and keep queue suspension idempotent before terminal
completion.

- [ ] **Step 4: Verify green**

Run:

```bash
bun run zigeffect:test
```

Expected: PASS.

## Task 5: Claim Timeout And Retry

**Files:**
- Modify `packages/zigeffect/src/workflow/queue.zig`
- Modify `packages/zigeffect/test/workflow_test.zig`

- [ ] **Step 1: Write failing retry tests**

Use a fake clock and a queue with `withClaimTimeoutMs(250)`. Claim an item at
`1_000`, assert no retry at `1_249`, append `queue_retry_scheduled` at `1_250`,
and assert the item can be claimed again with an incremented attempt.

- [ ] **Step 2: Verify red**

Run:

```bash
cd packages/zigeffect && zig build test-raw --summary all
```

Expected: FAIL until retry scanning exists.

- [ ] **Step 3: Implement expired-claim retry**

Parse claim deadlines, skip terminal items, append retry rows once per expired
claim, and treat retry-ready items as claimable.

- [ ] **Step 4: Verify green**

Run:

```bash
bun run zigeffect:test
```

Expected: PASS.

## Task 6: Docs, Roadmap, Full Gate, And Commit

**Files:**
- Modify `packages/zigeffect/docs/architecture.md`
- Modify `docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md`
- Add `docs/superpowers/specs/2026-06-09-zigeffect-durable-queue-design.md`
- Add `docs/superpowers/plans/2026-06-09-zigeffect-durable-queue.md`

- [ ] **Step 1: Update architecture docs**

Document `workflow/queue.zig` and `WorkflowContext.queue` ownership.

- [ ] **Step 2: Run full gate**

Run:

```bash
bun run zigeffect:test
cd packages/zigeffect && zig build examples
bun run zig:test
zig fmt --check packages/zigeffect/src/workflow/queue.zig packages/zigeffect/src/workflow/context.zig packages/zigeffect/src/workflow/root.zig packages/zigeffect/src/workflow/journal.zig packages/zigeffect/src/workflow/replay.zig packages/zigeffect/test/workflow_test.zig
git diff --check
rg -n 'T''BD|TO''DO|implement la''ter|fill in de''tails|appropriate error hand''ling|handle edge ca''ses|Similar to Ta''sk|deferred bu''cket|par''ked' packages/zigeffect/src/workflow packages/zigeffect/test/workflow_test.zig packages/zigeffect/docs/architecture.md docs/superpowers/specs/2026-06-09-zigeffect-durable-queue-design.md docs/superpowers/plans/2026-06-09-zigeffect-durable-queue.md
```

Expected: compile/test commands PASS, format and diff checks exit 0, and the
placeholder scan exits 1 with no matches.

- [ ] **Step 3: Mark Milestone 16 complete**

After the full gate passes, mark all Milestone 16 deliverables and acceptance
boxes complete in
`docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md`.
