# zigeffect Workflow Storage Compaction Design

Date: 2026-06-09

## Purpose

Milestone 21 keeps durable workflow recovery correct while preventing completed
workflow journals from growing forever. It builds on the existing append-only
file journal and checkpoint JSON support by adding committed replay snapshots,
archive export, retention policy enforcement, and a crash-safe compaction
protocol.

## Scope

This milestone changes the local workflow file store only. It does not add
networked storage, multi-runner coordination, shard leasing, async I/O backends,
or cluster transport. Those are later roadmap milestones. The local store must,
however, expose storage semantics that those later backends can copy: committed
snapshot metadata, archive boundaries, deterministic recovery from snapshot plus
tail, and explicit retention policy decisions.

## Existing Foundation

`packages/zigeffect/src/workflow/store.zig` already provides:

- `FileJournalStore` and `InMemoryJournalStore`;
- append-only JSONL segment writes;
- recovery from complete rows plus truncation of partial trailing writes;
- corruption reporting for complete malformed rows;
- `workflow-checkpoint-{sequence}.json` checkpoint naming;
- checkpoint JSON formatting and parsing for `WorkflowReplayState`.

Milestone 21 keeps the existing journal event schema unchanged. Checkpoints
remain replay-state snapshots using the existing
`zigeffect.workflow.checkpoint.v1` format.

## File Formats

The store directory contains these durable files:

- `workflow-0000000000000001.jsonl`: active JSONL segment.
- `workflow-checkpoint-{last_sequence}.json`: replay snapshot for a sequence.
- `workflow-snapshot-commit-{last_sequence}.json`: commit marker that makes the
  checkpoint eligible for recovery and compaction.
- `workflow-archive-{first_sequence}-{last_sequence}.jsonl`: exported raw JSONL
  journal rows covered by a compaction.
- `workflow.lock`: existing local ownership guard.

The snapshot commit JSON schema is:

```json
{
  "schema": "zigeffect.workflow.snapshot-commit.v1",
  "schema_version": 1,
  "last_sequence": 42,
  "checkpoint_name": "workflow-checkpoint-0000000000000042.json",
  "segment_name": "workflow-0000000000000001.jsonl",
  "archive_name": "workflow-archive-0000000000000001-0000000000000042.jsonl"
}
```

`archive_name` is nullable. Manual snapshot publication may commit a checkpoint
without exporting or compacting an archive. Completed workflow compaction uses a
non-null archive name unless retention explicitly selects checkpoint-only
compaction.

## Recovery

Recovery uses this order:

1. Acquire the existing `workflow.lock`.
2. Find the highest valid `workflow-snapshot-commit-{sequence}.json` file.
3. Load and parse the referenced checkpoint.
4. Reject the commit if the checkpoint is missing, malformed, has the wrong
   schema, or has a different `last_sequence`.
5. Recover the active segment as before, but skip rows whose sequence is less
   than or equal to the committed checkpoint sequence.
6. Apply recovered tail rows to the checkpoint state when `latestState` is
   requested.

Incomplete temporary files are ignored. A checkpoint file without a matching
commit marker is ignored, so a crash after checkpoint write but before commit
falls back to full journal replay. A committed snapshot with the full segment
still present is also safe, because recovery skips acknowledged rows and replays
only the tail.

## Replay Snapshots

`FileJournalStore.writeReplaySnapshot` folds the latest state, writes the
checkpoint atomically, then writes the snapshot commit atomically. Once the
commit marker exists, snapshot plus tail replay must produce the same
`WorkflowReplayState` as full segment replay.

Snapshots are allowed for running workflows. Publishing a snapshot does not
truncate the active segment. This provides faster recovery for long-running
workflows while preserving all event rows until a later retention policy
decides they can be removed.

## Compaction

`FileJournalStore.compactCompleted` compacts only terminal workflow states:

- `completed`;
- `failed`;
- `interrupted`;
- `cancelled`;
- `defect`.

If the latest workflow state is not terminal, compaction returns a result with
`compacted = false` and leaves all files untouched.

For terminal workflows, compaction:

1. Computes the latest state.
2. Exports the active segment rows covered by the compaction to an archive file
   unless checkpoint-only retention is requested.
3. Publishes a replay snapshot and commit marker at `last_sequence`.
4. Truncates the active segment only after the commit marker exists.
5. Updates the in-process file store base state so `latestState` remains
   correct without requiring reopen.

The live segment after successful compaction contains only tail rows after the
checkpoint sequence. For a completed single-execution store, that normally
means the segment is empty.

## Retention Policy

`FileJournalStoreOptions` gains a retention policy:

- `keep_all`: never compact automatically.
- `archive_then_compact_completed`: export the completed journal rows, commit a
  checkpoint, then truncate acknowledged rows.
- `checkpoint_only_completed`: commit a checkpoint and truncate acknowledged
  rows without keeping a raw archive.

The default remains `keep_all` so existing tests and callers keep their current
append-only behavior. `FileJournalStore.applyRetentionPolicy` runs the selected
policy and returns a structured compaction result.

## Archive Export

Archive export writes deterministic JSONL rows using the existing workflow event
formatter. The exported rows preserve event schema versions, sequence numbers,
workflow ids, execution ids, names, statuses, idempotency keys, and redacted
details. Archive export is available independently through
`FileJournalStore.exportArchive` so operators and future cluster storage
backends can retain raw history without also truncating the active segment.

## Crash Invariants

The compaction protocol is safe at each crash point:

- Before checkpoint write: full segment is still present; recovery full-replays.
- After checkpoint write and before commit: checkpoint is ignored; recovery
  full-replays.
- After commit and before truncation: recovery loads checkpoint and skips
  duplicate segment rows through the checkpoint sequence.
- After truncation: recovery loads checkpoint and replays any tail rows left in
  the active segment.

No acknowledged event may be lost unless its replay-equivalent checkpoint is
committed first. No uncommitted checkpoint may affect recovery.

## Public API Additions

`packages/zigeffect/src/workflow/store.zig` adds:

- `workflow_snapshot_commit_schema`;
- `workflow_snapshot_commit_schema_version`;
- `WorkflowCompletedRetentionPolicy`;
- `WorkflowRetentionPolicy`;
- `WorkflowSnapshotCommit`;
- `WorkflowSnapshotPublication`;
- `WorkflowCompactionResult`;
- `archiveFileName`;
- `snapshotCommitFileName`;
- `formatWorkflowSnapshotCommitJson`;
- `parseWorkflowSnapshotCommitJson`;
- `FileJournalStore.writeReplaySnapshot`;
- `FileJournalStore.exportArchive`;
- `FileJournalStore.compactCompleted`;
- `FileJournalStore.applyRetentionPolicy`.

`packages/zigeffect/src/workflow/replay.zig` adds:

- `WorkflowReplayState.clone`;
- `workflowStatusIsTerminal`.

`packages/zigeffect/src/workflow/root.zig` re-exports the new public workflow
storage APIs.

## Tests

`packages/zigeffect/test/workflow_test.zig` gains tests for:

- replay snapshot JSON plus tail replay equals full replay;
- reopening from a committed snapshot skips acknowledged rows and keeps tail
  replay correct;
- checkpoint files without commit markers are ignored;
- completed compaction exports an archive, commits a checkpoint, truncates the
  active segment, and preserves `latestState`;
- crash after commit but before truncation does not duplicate or lose events;
- retention `keep_all` leaves completed journals untouched;
- retention `archive_then_compact_completed` compacts completed journals;
- retention `checkpoint_only_completed` compacts without archive export;
- archive export writes deterministic JSONL rows that replay to the exported
  boundary.

## Documentation

Update:

- `packages/zigeffect/docs/architecture.md` with snapshot, archive, retention,
  and compaction recovery semantics.
- `docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md`
  to mark Milestone 21 complete after verification.

## Acceptance

- Snapshot plus tail replay equals full replay.
- Crash during compaction does not lose acknowledged events.
- Completed workflow retention can preserve all rows, archive then compact, or
  checkpoint-only compact.
- Archive export is deterministic and replayable.
- Corruption-safe commit semantics are documented and covered by tests.
- `bun run zigeffect:test` passes.
- `cd packages/zigeffect && zig build examples` passes.
- `bun run zig:test` passes.
