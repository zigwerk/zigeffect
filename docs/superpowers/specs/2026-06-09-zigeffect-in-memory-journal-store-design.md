# zigeffect In-Memory Journal Store Design

Date: 2026-06-09

## Purpose

Milestone 4 adds the first workflow journal storage contract and an in-memory
implementation for tests, model checks, and later workflow-engine milestones.
The store remains local and volatile, but it must preserve the append-only
semantics future durable stores will share.

## Design

Add `packages/zigeffect/src/workflow/store.zig` and expose it through
`fx.workflow`.

The module owns:

- `JournalStore`: a small vtable contract over append, read, replay, and reset
  operations;
- `JournalAppend`: append request with an event and optional optimistic
  `expected_next_sequence`;
- `JournalEventBatch`: caller-owned read results with explicit `deinit`;
- `JournalStoreError`: sequence conflict, duplicate event, and sequence
  overflow errors;
- `InMemoryJournalStore`: allocator-owned append-only event storage.

Extend `WorkflowEvent` with `idempotency_key: []const u8 = ""`. Empty keys are
allowed for low-level tests, but non-empty keys are unique within a store.
Duplicate non-empty keys are rejected instead of silently returning an existing
event. This keeps the first store simple while preserving the future ability to
make idempotent append semantics richer.

## Ownership

The in-memory store clones workflow events into its allocator on append. Read
methods clone matching events into the caller allocator and return a
`JournalEventBatch` that must be deinitialized by the caller. This mirrors the
existing `CausalStore` ownership pattern.

Replay state owns copied row names so `latestState` can read a temporary batch,
fold it, release the batch, and return a state that remains valid.

## Append Rules

- The first event must have sequence `1`.
- Each later event must use `last_sequence + 1`.
- If `expected_next_sequence` is provided, it must match the computed next
  sequence.
- Duplicate non-empty `idempotency_key` values return `DuplicateEvent`.
- Overflow when computing the next sequence returns `SequenceOverflow`.

## Read Rules

- `readAll(allocator)` returns all events in append order.
- `readFromSequence(allocator, sequence)` returns events with
  `event.sequence >= sequence`.
- `latestState(allocator)` folds all current events with `WorkflowReplayState`.
- `reset()` frees stored event strings and leaves the store reusable.

## Non-Goals

- No file persistence.
- No JSON parsing.
- No compaction or snapshots.
- No partial history repair.
- No concurrent locking.
- No workflow execution.

## Acceptance

- Tests prove ordered append and read batches.
- Tests prove duplicate idempotency keys are rejected.
- Tests prove optimistic sequence conflicts are rejected.
- Tests prove `latestState` replays from memory.
- Tests prove `reset` frees the logical journal and the store remains reusable.
- `bun run zigeffect:test` passes.
- `cd packages/zigeffect && zig build examples` passes.
- `bun run zig:test` passes.
