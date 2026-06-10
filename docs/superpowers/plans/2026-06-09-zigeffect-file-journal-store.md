# zigeffect File Journal Store Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a local append-only file-backed workflow journal store with recovery, locking, corruption reports, fsync policy options, and checkpoint JSON round-tripping.

**Architecture:** Extend `workflow/journal.zig` with structured event parsing and extend `workflow/store.zig` with file-store ownership. Keep the file store API aligned with the `JournalStore` contract from Milestone 4.

**Tech Stack:** Zig 0.16, `std.fs`, `std.json`, `std.ArrayList`, existing workflow journal/replay/store modules, `bun run zigeffect:test`.

---

## File Structure

- Modify `packages/zigeffect/src/workflow/journal.zig`
  - Adds structured JSON row parsing and event-kind schema validation.
- Modify `packages/zigeffect/src/workflow/store.zig`
  - Adds file store, fsync policy, corruption report, segment naming,
    checkpoint formatter/parser.
- Modify `packages/zigeffect/src/workflow/root.zig`
  - Exposes file-store names.
- Modify `packages/zigeffect/test/workflow_test.zig`
  - Adds file-store persistence, recovery, corruption, locking, fsync, and
    checkpoint tests.
- Modify `packages/zigeffect/test/architecture_test.zig`
  - Verifies file-store exposure.
- Modify `packages/zigeffect/docs/architecture.md`
  - Documents file-store responsibilities.
- Modify `docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md`
  - Marks Milestone 5 complete after verification.

## Task 1: Structured Event Parser

**Files:**
- Modify `packages/zigeffect/src/workflow/journal.zig`
- Modify `packages/zigeffect/test/workflow_test.zig`

- [x] **Step 1: Write failing parser tests**

Add tests proving `formatWorkflowEventJson` output can parse back into an
equivalent `WorkflowEvent`, including optional ids, escaped text, and
`idempotency_key`.

- [x] **Step 2: Verify red**

Run:

```bash
bun run zigeffect:test
```

Expected: FAIL until parser APIs exist.

- [x] **Step 3: Implement parser**

Add `WorkflowEventParseError`, `parseWorkflowEventJson`, and
`workflowEventKindFromName`. Use `std.json.parseFromSlice` and clone parsed
strings into the caller allocator.

- [x] **Step 4: Verify green**

Run:

```bash
bun run zigeffect:test
```

Expected: PASS.

## Task 2: File Store Append And Restart Replay

**Files:**
- Modify `packages/zigeffect/src/workflow/store.zig`
- Modify `packages/zigeffect/src/workflow/root.zig`
- Modify `packages/zigeffect/test/workflow_test.zig`
- Modify `packages/zigeffect/test/architecture_test.zig`

- [x] **Step 1: Write failing file-store tests**

Add tests proving:

- `FileJournalStore.open` creates a named segment;
- appended JSON lines survive deinit/reopen;
- `latestState` after reopen matches an `InMemoryJournalStore` fed the same
  events;
- `FileJournalStore.asJournalStore` satisfies the same vtable contract.

- [x] **Step 2: Verify red**

Run:

```bash
bun run zigeffect:test
```

Expected: FAIL until file-store APIs exist.

- [x] **Step 3: Implement file append/recovery**

Add `FileJournalStore`, `FileJournalStoreOptions`, segment naming helpers,
append-to-segment-before-memory ordering, and restart recovery into the memory
store.

- [x] **Step 4: Verify green**

Run:

```bash
bun run zigeffect:test
```

Expected: PASS.

## Task 3: Crash Recovery, Locking, Corruption, And Fsync

**Files:**
- Modify `packages/zigeffect/src/workflow/store.zig`
- Modify `packages/zigeffect/test/workflow_test.zig`

- [x] **Step 1: Write failing edge-case tests**

Add tests proving:

- partial trailing JSON bytes are truncated on reopen and valid earlier rows
  replay;
- a malformed complete row returns `CorruptJournal` and records segment/offset;
- a second opener fails with `JournalStoreLocked`;
- `JournalFsyncPolicy.after_append` increments `syncCount` on append;
- `JournalFsyncPolicy.after_recovery` increments `syncCount` after partial
  truncation.

- [x] **Step 2: Verify red**

Run:

```bash
bun run zigeffect:test
```

Expected: FAIL until the edge behavior exists.

- [x] **Step 3: Implement edge behavior**

Implement lock-file acquisition/removal, partial-tail truncation, corruption
reports, and fsync policy checks.

- [x] **Step 4: Verify green**

Run:

```bash
bun run zigeffect:test
```

Expected: PASS.

## Task 4: Checkpoint Format

**Files:**
- Modify `packages/zigeffect/src/workflow/store.zig`
- Modify `packages/zigeffect/src/workflow/root.zig`
- Modify `packages/zigeffect/test/workflow_test.zig`

- [x] **Step 1: Write failing checkpoint tests**

Add tests that fold a journal to `WorkflowReplayState`, format a checkpoint,
parse the checkpoint back, and compare workflow status, ids, sequence, and all
row states.

- [x] **Step 2: Verify red**

Run:

```bash
bun run zigeffect:test
```

Expected: FAIL until checkpoint formatter/parser exist.

- [x] **Step 3: Implement checkpoint formatter/parser**

Add checkpoint schema constants, status formatting/parsing helpers, JSON array
formatters, `formatWorkflowCheckpointJson`, and
`parseWorkflowCheckpointJson`.

- [x] **Step 4: Verify green**

Run:

```bash
bun run zigeffect:test
```

Expected: PASS.

## Task 5: Docs, Roadmap, And Commit

**Files:**
- Modify `packages/zigeffect/docs/architecture.md`
- Modify `docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md`
- Add `docs/superpowers/specs/2026-06-09-zigeffect-file-journal-store-design.md`
- Add `docs/superpowers/plans/2026-06-09-zigeffect-file-journal-store.md`

- [x] **Step 1: Update architecture docs**

Document `FileJournalStore`, segment naming, recovery posture, corruption
reports, fsync policy, and checkpoints under `src/workflow/store.zig`.

- [x] **Step 2: Mark Milestone 5 complete**

Mark all Milestone 5 deliverables and acceptance boxes in the roadmap after
the full gate passes.

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
git add packages/zigeffect/src/workflow/journal.zig packages/zigeffect/src/workflow/store.zig packages/zigeffect/src/workflow/root.zig packages/zigeffect/test/workflow_test.zig packages/zigeffect/test/architecture_test.zig packages/zigeffect/docs/architecture.md docs/superpowers/specs/2026-06-09-zigeffect-file-journal-store-design.md docs/superpowers/plans/2026-06-09-zigeffect-file-journal-store.md docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md
git commit -m "feat(zigeffect): add file workflow journal store"
```

## Self-Review Checklist

- [x] Complete rows parse through `std.json`, not string slicing.
- [x] Partial trailing rows are truncated; malformed complete rows are not.
- [x] Corruption reports include segment name and byte offset.
- [x] Lock file prevents two local openers.
- [x] Fsync policies are observable in tests.
- [x] Checkpoint JSON round-trips to an equivalent replay state.
- [x] File store and memory store fold to the same state.
- [x] No workflow engine, activity runner, timers, or cluster leasing is added.
- [x] Full verification passes before Milestone 5 is marked complete.
