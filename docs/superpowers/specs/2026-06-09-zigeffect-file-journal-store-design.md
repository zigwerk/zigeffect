# zigeffect File Journal Store Design

Date: 2026-06-09

## Purpose

Milestone 5 adds a local append-only file journal store. It makes workflow
history survive process restart before workflow execution, timers, activity
runners, or clustered ownership enter the system.

## Design

Extend the workflow store module with:

- `FileJournalStore`;
- `FileJournalStoreOptions`;
- `JournalFsyncPolicy`;
- `JournalCorruptionReport`;
- segment naming helpers;
- checkpoint schema constants and checkpoint JSON formatter/parser.

The file store implements the existing `JournalStore` contract. It keeps an
internal `InMemoryJournalStore` as the recovered read model and appends every
new event to a newline-delimited JSON segment before appending it to memory.

## Files

Within the configured directory:

- `workflow-0000000000000001.jsonl`: first journal segment;
- `workflow.lock`: exclusive process ownership guard;
- `workflow-checkpoint-0000000000000000.json`: checkpoint file name shape,
  where the numeric suffix is the checkpoint `last_sequence`.

Segment rotation is not part of this milestone. The naming helper still uses
zero-padded sequence numbers so later rotation can add new segment starts
without changing the file naming convention.

## Recovery

Recovery reads the segment from disk, line by line.

- Complete newline-terminated rows are parsed with `std.json.parseFromSlice`.
- A trailing non-empty row without a newline is treated as a partial crash
  write and truncated away.
- A malformed complete row is corruption, not recovery. The store records the
  segment name, byte offset, and reason in `JournalCorruptionReport`, then
  returns `CorruptJournal`.
- Valid recovered rows are loaded into the memory store with the same sequence
  and idempotency checks used by appends.

## Locking

Opening the store creates `workflow.lock` with exclusive create semantics. A
second open while the lock exists returns `JournalStoreLocked`. `deinit` removes
the lock for stores that acquired it. Stale lock breaking is intentionally left
for the later multi-process/cluster lease milestones.

## Fsync

`JournalFsyncPolicy` has:

- `never`;
- `after_append`;
- `after_recovery`;
- `always`.

The store calls `sync()` on the segment file according to policy and tracks
`sync_count` for deterministic tests.

## Checkpoints

Checkpoint JSON is a replay-state snapshot:

- schema: `zigeffect.workflow.checkpoint.v1`;
- schema version: `1`;
- `last_sequence`;
- workflow status, workflow id, and execution id;
- activity, timer, deferred, and queue rows with id, status, last sequence, and
  name.

`formatWorkflowCheckpointJson` and `parseWorkflowCheckpointJson` round-trip
through `WorkflowReplayState`. Tests compare a state folded from the journal to
the parsed checkpoint state to prove replay equivalence.

## Non-Goals

- No segment rotation.
- No compaction commit protocol.
- No stale lock breaking.
- No concurrent writer coordination beyond the lock file.
- No workflow execution.
- No cluster leasing.

## Acceptance

- Crash fixture tests simulate partial writes and restart replay.
- Full-line corruption reports the exact segment and byte offset.
- Lock tests reject a second local opener.
- Fsync policy tests prove sync decisions are observable.
- File store and memory store produce the same folded state.
- Checkpoint JSON round-trips to an equivalent replay state.
- `bun run zigeffect:test` passes.
- `cd packages/zigeffect && zig build examples` passes.
- `bun run zig:test` passes.
