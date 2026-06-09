# zigeffect In-Memory Journal Store Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the first workflow journal store contract and an in-memory append-only implementation.

**Architecture:** Extend the existing workflow event envelope with idempotency keys, then add `workflow/store.zig` as the owner of journal storage contracts and the in-memory implementation. Keep persistence, parsing, and compaction out of this milestone.

**Tech Stack:** Zig 0.16, `std.ArrayList`, existing `workflow/journal.zig`, existing `workflow/replay.zig`, `bun run zigeffect:test`.

---

## File Structure

- Modify `packages/zigeffect/src/workflow/journal.zig`
  - Adds `idempotency_key` and event clone/free helpers.
- Modify `packages/zigeffect/src/workflow/replay.zig`
  - Makes replay row names allocator-owned so `latestState` can return safely.
- Create `packages/zigeffect/src/workflow/store.zig`
  - Owns `JournalStore`, `JournalAppend`, `JournalEventBatch`,
    `JournalStoreError`, and `InMemoryJournalStore`.
- Modify `packages/zigeffect/src/workflow/root.zig`
  - Exposes store names.
- Modify `packages/zigeffect/test/workflow_test.zig`
  - Adds journal-store tests.
- Modify `packages/zigeffect/test/architecture_test.zig`
  - Verifies store module exposure.
- Modify `packages/zigeffect/docs/architecture.md`
  - Documents `workflow/store.zig`.
- Modify `docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md`
  - Marks Milestone 4 complete after verification.

## Task 1: Idempotency Key Envelope

**Files:**
- Modify `packages/zigeffect/src/workflow/journal.zig`
- Modify `packages/zigeffect/test/workflow_test.zig`

- [x] **Step 1: Write failing idempotency formatting tests**

Extend the existing JSON/text formatter tests to set
`idempotency_key = "event-1"` and assert the key appears in both formats.

- [x] **Step 2: Verify red**

Run:

```bash
bun run zigeffect:test
```

Expected: FAIL until `WorkflowEvent` and formatters expose the field.

- [x] **Step 3: Implement event key and clone helpers**

Add `idempotency_key` to `WorkflowEvent`, include it in JSON/text formatters,
and add allocator-explicit `cloneWorkflowEvent` /
`deinitWorkflowEventStrings` helpers.

- [x] **Step 4: Verify green**

Run:

```bash
bun run zigeffect:test
```

Expected: PASS.

## Task 2: Journal Store Contract And In-Memory Store

**Files:**
- Modify `packages/zigeffect/test/workflow_test.zig`
- Modify `packages/zigeffect/test/architecture_test.zig`
- Create `packages/zigeffect/src/workflow/store.zig`
- Modify `packages/zigeffect/src/workflow/root.zig`

- [x] **Step 1: Write failing store tests**

Add tests for:

- append/read ordering;
- read-from-sequence;
- duplicate non-empty idempotency key rejection;
- sequence conflict from event sequence;
- sequence conflict from `expected_next_sequence`;
- `latestState` replaying stored events;
- `reset` clearing the store and allowing reuse;
- `JournalStore` vtable access through `asJournalStore`.

- [x] **Step 2: Verify red**

Run:

```bash
bun run zigeffect:test
```

Expected: FAIL until the store module exists.

- [x] **Step 3: Implement store contract and memory store**

Add `JournalStore`, `JournalAppend`, `JournalEventBatch`,
`JournalStoreError`, and `InMemoryJournalStore`. Store appends clone events,
read methods return cloned batches, `latestState` folds a temporary batch, and
`reset` frees stored event strings.

- [x] **Step 4: Verify green**

Run:

```bash
bun run zigeffect:test
```

Expected: PASS.

## Task 3: Replay Name Ownership

**Files:**
- Modify `packages/zigeffect/src/workflow/replay.zig`
- Modify `packages/zigeffect/test/workflow_test.zig`

- [x] **Step 1: Add coverage through latest-state replay**

The store `latestState` test must deinitialize its temporary read batch inside
the store and still return row names that remain valid until replay state
deinit.

- [x] **Step 2: Implement owned row names**

Clone row names when rows are created or updated, free them in replay-state
deinit, and keep updates allocation-safe.

- [x] **Step 3: Verify green**

Run:

```bash
bun run zigeffect:test
```

Expected: PASS with leak checks clean.

## Task 4: Docs, Roadmap, And Commit

**Files:**
- Modify `packages/zigeffect/docs/architecture.md`
- Modify `docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md`
- Add `docs/superpowers/specs/2026-06-09-zigeffect-in-memory-journal-store-design.md`
- Add `docs/superpowers/plans/2026-06-09-zigeffect-in-memory-journal-store.md`

- [x] **Step 1: Update architecture docs**

Add `store.zig` to the `src/workflow/` section as the owner of the journal
store contract and in-memory store.

- [x] **Step 2: Mark Milestone 4 complete**

Mark all Milestone 4 deliverables and acceptance boxes in the durable workflows
and clustering roadmap after verification.

- [x] **Step 3: Run full gate**

Run:

```bash
bun run zigeffect:test
cd packages/zigeffect && zig build examples
bun run zig:test
git diff --check
```

Expected: all commands PASS.

- [x] **Step 4: Commit**

```bash
git add packages/zigeffect/src/workflow/journal.zig packages/zigeffect/src/workflow/replay.zig packages/zigeffect/src/workflow/store.zig packages/zigeffect/src/workflow/root.zig packages/zigeffect/test/workflow_test.zig packages/zigeffect/test/architecture_test.zig packages/zigeffect/docs/architecture.md docs/superpowers/specs/2026-06-09-zigeffect-in-memory-journal-store-design.md docs/superpowers/plans/2026-06-09-zigeffect-in-memory-journal-store.md docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md
git commit -m "feat(zigeffect): add in-memory workflow journal store"
```

## Self-Review Checklist

- [x] Append-only ordering is enforced by sequence number.
- [x] Non-empty idempotency keys are unique.
- [x] Read batches own their cloned event strings.
- [x] Replay states returned by `latestState` do not borrow from a freed batch.
- [x] No file store, workflow engine, parser, or compaction logic is added.
- [x] Full verification passes before Milestone 4 is marked complete.
