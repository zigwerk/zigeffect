# zigeffect Workflow Storage Compaction Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add committed replay snapshots, archive export, completed-workflow compaction, retention policies, and crash-safe recovery to the local workflow file journal.

**Architecture:** Keep normal writes append-only, publish checkpoints through a separate snapshot commit marker, and recover by folding committed checkpoint state plus active segment tail rows. Completed compaction exports acknowledged rows, commits a snapshot, then truncates the active segment only after the commit exists.

**Tech Stack:** Zig 0.16, `std.Io`, `bun:test` project gate, existing `packages/zigeffect` workflow modules and `bun run zigeffect:test`.

---

## File Structure

- Modify: `packages/zigeffect/src/workflow/replay.zig`
  - Add `WorkflowReplayState.clone`.
  - Add `workflowStatusIsTerminal`.
- Modify: `packages/zigeffect/src/workflow/store.zig`
  - Add snapshot commit schema constants, commit structs, archive naming, retention policy structs, and compaction result structs.
  - Extend `InMemoryJournalStore` with a base sequence for compacted tails.
  - Extend `FileJournalStore` with committed checkpoint recovery, replay snapshot publication, archive export, completed compaction, retention enforcement, and snapshot-aware `latestState`.
- Modify: `packages/zigeffect/src/workflow/root.zig`
  - Re-export new storage APIs.
- Modify: `packages/zigeffect/test/workflow_test.zig`
  - Add red tests for clone helpers, snapshot commit JSON, snapshot plus tail replay, archive export, compaction, crash recovery, and retention policy.
- Modify: `packages/zigeffect/docs/architecture.md`
  - Document snapshot commit files, archive export, retention policies, and crash recovery.
- Modify: `docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md`
  - Mark Milestone 21 deliverables and acceptance complete after verification.

## Task 1: Replay State Clone And Terminal Status

**Files:**
- Modify: `packages/zigeffect/test/workflow_test.zig`
- Modify: `packages/zigeffect/src/workflow/replay.zig`
- Modify: `packages/zigeffect/src/workflow/root.zig`

- [ ] **Step 1: Write failing clone and terminal-status tests**

Add after the existing workflow replay fold tests in `packages/zigeffect/test/workflow_test.zig`:

```zig
test "workflow replay state clone owns copied names" {
    const events = [_]fx.workflow.WorkflowEvent{
        .{ .sequence = 1, .kind = .workflow_started, .workflow_id = 7, .execution_id = 8, .name = "clone-workflow" },
        .{ .sequence = 2, .kind = .activity_scheduled, .workflow_id = 7, .execution_id = 8, .activity_id = 10, .attempt = 1, .name = "charge" },
        .{ .sequence = 3, .kind = .timer_scheduled, .workflow_id = 7, .execution_id = 8, .timer_id = 20, .name = "wake" },
    };

    var state = try fx.workflow.WorkflowReplayState.fold(std.testing.allocator, &events);
    defer state.deinit();

    var cloned = try state.clone(std.testing.allocator);
    defer cloned.deinit();

    try expectWorkflowReplayStatesEqual(&state, &cloned);
    try std.testing.expect(cloned.activities.items[0].name.ptr != state.activities.items[0].name.ptr);
    try std.testing.expect(cloned.timers.items[0].name.ptr != state.timers.items[0].name.ptr);
}

test "workflow terminal status helper identifies retention-safe states" {
    try std.testing.expect(!fx.workflow.workflowStatusIsTerminal(.pending));
    try std.testing.expect(!fx.workflow.workflowStatusIsTerminal(.running));
    try std.testing.expect(!fx.workflow.workflowStatusIsTerminal(.suspended));
    try std.testing.expect(fx.workflow.workflowStatusIsTerminal(.completed));
    try std.testing.expect(fx.workflow.workflowStatusIsTerminal(.failed));
    try std.testing.expect(fx.workflow.workflowStatusIsTerminal(.interrupted));
    try std.testing.expect(fx.workflow.workflowStatusIsTerminal(.cancelled));
    try std.testing.expect(fx.workflow.workflowStatusIsTerminal(.defect));
}
```

- [ ] **Step 2: Run the red test**

Run:

```bash
cd packages/zigeffect && zig build test-raw --summary all -- workflow replay state clone owns copied names
```

Expected: compile failure because `WorkflowReplayState.clone` and `workflowStatusIsTerminal` do not exist.

- [ ] **Step 3: Implement replay clone and terminal helper**

Add to `WorkflowReplayState` in `packages/zigeffect/src/workflow/replay.zig`:

```zig
pub fn clone(self: *const WorkflowReplayState, allocator: std.mem.Allocator) std.mem.Allocator.Error!WorkflowReplayState {
    var copied = WorkflowReplayState.init(allocator);
    errdefer copied.deinit();

    copied.workflow_status = self.workflow_status;
    copied.workflow_id = self.workflow_id;
    copied.execution_id = self.execution_id;
    copied.last_sequence = self.last_sequence;

    for (self.activities.items) |row| {
        const name = try copied.cloneName(row.name);
        errdefer copied.freeName(name);
        try copied.activities.append(allocator, .{ .id = row.id, .status = row.status, .last_sequence = row.last_sequence, .attempt = row.attempt, .name = name });
    }
    for (self.timers.items) |row| {
        const name = try copied.cloneName(row.name);
        errdefer copied.freeName(name);
        try copied.timers.append(allocator, .{ .id = row.id, .status = row.status, .last_sequence = row.last_sequence, .name = name });
    }
    for (self.deferreds.items) |row| {
        const name = try copied.cloneName(row.name);
        errdefer copied.freeName(name);
        try copied.deferreds.append(allocator, .{ .id = row.id, .status = row.status, .last_sequence = row.last_sequence, .name = name });
    }
    for (self.queues.items) |row| {
        const name = try copied.cloneName(row.name);
        errdefer copied.freeName(name);
        try copied.queues.append(allocator, .{ .id = row.id, .status = row.status, .last_sequence = row.last_sequence, .name = name });
    }
    for (self.compensations.items) |row| {
        const name = try copied.cloneName(row.name);
        errdefer copied.freeName(name);
        try copied.compensations.append(allocator, .{ .id = row.id, .status = row.status, .last_sequence = row.last_sequence, .name = name });
    }

    return copied;
}
```

Add near the existing private `isTerminal` helper:

```zig
pub fn workflowStatusIsTerminal(status: WorkflowStatus) bool {
    return isTerminal(status);
}
```

Re-export in `packages/zigeffect/src/workflow/root.zig`:

```zig
pub const workflowStatusIsTerminal = replay.workflowStatusIsTerminal;
```

- [ ] **Step 4: Run the green test**

Run:

```bash
bun run zigeffect:test
```

Expected: workflow tests pass.

- [ ] **Step 5: Commit**

```bash
git add packages/zigeffect/src/workflow/replay.zig packages/zigeffect/src/workflow/root.zig packages/zigeffect/test/workflow_test.zig
git commit -m "feat(zigeffect): clone workflow replay state"
```

## Task 2: Snapshot Commit Metadata And Store Base Sequence

**Files:**
- Modify: `packages/zigeffect/test/workflow_test.zig`
- Modify: `packages/zigeffect/src/workflow/store.zig`
- Modify: `packages/zigeffect/src/workflow/root.zig`

- [ ] **Step 1: Write failing metadata tests**

Add after the checkpoint JSON round-trip test:

```zig
test "workflow snapshot commit json round-trips file references" {
    const checkpoint_name = try fx.workflow.checkpointFileName(std.testing.allocator, 42);
    defer std.testing.allocator.free(checkpoint_name);
    const commit_name = try fx.workflow.snapshotCommitFileName(std.testing.allocator, 42);
    defer std.testing.allocator.free(commit_name);
    const archive_name = try fx.workflow.archiveFileName(std.testing.allocator, 1, 42);
    defer std.testing.allocator.free(archive_name);

    try std.testing.expectEqualStrings("workflow-snapshot-commit-0000000000000042.json", commit_name);
    try std.testing.expectEqualStrings("workflow-archive-0000000000000001-0000000000000042.jsonl", archive_name);

    const json = try fx.workflow.formatWorkflowSnapshotCommitJson(std.testing.allocator, .{
        .last_sequence = 42,
        .checkpoint_name = checkpoint_name,
        .segment_name = "workflow-0000000000000001.jsonl",
        .archive_name = archive_name,
    });
    defer std.testing.allocator.free(json);

    try std.testing.expect(std.mem.indexOf(u8, json, "\"schema\":\"zigeffect.workflow.snapshot-commit.v1\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"archive_name\":\"workflow-archive-0000000000000001-0000000000000042.jsonl\"") != null);

    var parsed = try fx.workflow.parseWorkflowSnapshotCommitJson(std.testing.allocator, json);
    defer parsed.deinit();

    try std.testing.expectEqual(@as(u64, 42), parsed.last_sequence);
    try std.testing.expectEqualStrings(checkpoint_name, parsed.checkpoint_name);
    try std.testing.expectEqualStrings("workflow-0000000000000001.jsonl", parsed.segment_name);
    try std.testing.expectEqualStrings(archive_name, parsed.archive_name.?);
}

test "in-memory journal store can validate compacted tail sequence" {
    var store = fx.workflow.InMemoryJournalStore.init(std.testing.allocator);
    defer store.deinit();
    store.resetFromSequence(3);

    _ = try store.append(.{
        .event = .{ .sequence = 4, .kind = .workflow_completed, .workflow_id = 7, .execution_id = 8, .idempotency_key = "completed" },
    });

    try std.testing.expectError(error.SequenceConflict, store.append(.{
        .event = .{ .sequence = 4, .kind = .workflow_completed, .workflow_id = 7, .execution_id = 8, .idempotency_key = "duplicate-sequence" },
    }));
}
```

- [ ] **Step 2: Run the red test**

Run:

```bash
bun run zigeffect:test
```

Expected: compile failure for missing snapshot commit APIs and `resetFromSequence`.

- [ ] **Step 3: Add metadata types and base sequence support**

In `packages/zigeffect/src/workflow/store.zig`, add:

```zig
pub const workflow_snapshot_commit_schema = "zigeffect.workflow.snapshot-commit.v1";
pub const workflow_snapshot_commit_schema_version: u32 = 1;

pub const WorkflowSnapshotCommit = struct {
    allocator: Allocator,
    last_sequence: JournalSequence,
    checkpoint_name: []const u8,
    segment_name: []const u8,
    archive_name: ?[]const u8 = null,

    pub fn deinit(self: *WorkflowSnapshotCommit) void {
        self.allocator.free(self.checkpoint_name);
        self.allocator.free(self.segment_name);
        if (self.archive_name) |name| self.allocator.free(name);
    }
};

const WorkflowSnapshotCommitJson = struct {
    schema: []const u8,
    schema_version: u32,
    last_sequence: JournalSequence,
    checkpoint_name: []const u8,
    segment_name: []const u8,
    archive_name: ?[]const u8 = null,
};
```

Add `snapshotCommitFileName`, `archiveFileName`,
`formatWorkflowSnapshotCommitJson`, and `parseWorkflowSnapshotCommitJson` using
the existing checkpoint JSON string helpers.

Extend `InMemoryJournalStore`:

```zig
base_sequence: JournalSequence = 0,

pub fn resetFromSequence(self: *InMemoryJournalStore, sequence: JournalSequence) void {
    self.reset();
    self.base_sequence = sequence;
}
```

Change `nextSequence` to return `base_sequence + 1` when no tail events exist.

- [ ] **Step 4: Re-export metadata APIs**

In `packages/zigeffect/src/workflow/root.zig`, re-export:

```zig
pub const workflow_snapshot_commit_schema = store.workflow_snapshot_commit_schema;
pub const workflow_snapshot_commit_schema_version = store.workflow_snapshot_commit_schema_version;
pub const WorkflowSnapshotCommit = store.WorkflowSnapshotCommit;
pub const snapshotCommitFileName = store.snapshotCommitFileName;
pub const archiveFileName = store.archiveFileName;
pub const formatWorkflowSnapshotCommitJson = store.formatWorkflowSnapshotCommitJson;
pub const parseWorkflowSnapshotCommitJson = store.parseWorkflowSnapshotCommitJson;
```

- [ ] **Step 5: Run the green test**

Run:

```bash
bun run zigeffect:test
```

Expected: tests pass.

- [ ] **Step 6: Commit**

```bash
git add packages/zigeffect/src/workflow/store.zig packages/zigeffect/src/workflow/root.zig packages/zigeffect/test/workflow_test.zig
git commit -m "feat(zigeffect): add workflow snapshot commit metadata"
```

## Task 3: Snapshot Publication And Snapshot-Aware Recovery

**Files:**
- Modify: `packages/zigeffect/test/workflow_test.zig`
- Modify: `packages/zigeffect/src/workflow/store.zig`
- Modify: `packages/zigeffect/src/workflow/root.zig`

- [ ] **Step 1: Write failing snapshot recovery tests**

Add file store tests after the partial trailing row recovery test:

```zig
test "file workflow journal snapshot plus tail replay equals full replay after reopen" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const events = [_]fx.workflow.WorkflowEvent{
        .{ .sequence = 1, .kind = .workflow_started, .workflow_id = 7, .execution_id = 8, .name = "snap", .idempotency_key = "start" },
        .{ .sequence = 2, .kind = .activity_scheduled, .workflow_id = 7, .execution_id = 8, .activity_id = 10, .attempt = 1, .name = "charge", .idempotency_key = "activity" },
        .{ .sequence = 3, .kind = .activity_completed, .workflow_id = 7, .execution_id = 8, .activity_id = 10, .attempt = 1, .idempotency_key = "activity-done" },
        .{ .sequence = 4, .kind = .timer_scheduled, .workflow_id = 7, .execution_id = 8, .timer_id = 20, .name = "wake", .idempotency_key = "timer" },
        .{ .sequence = 5, .kind = .timer_fired, .workflow_id = 7, .execution_id = 8, .timer_id = 20, .idempotency_key = "timer-fired" },
    };

    var expected = try fx.workflow.WorkflowReplayState.fold(std.testing.allocator, &events);
    defer expected.deinit();

    {
        var store = try fx.workflow.FileJournalStore.open(std.testing.allocator, std.testing.io, &tmp.dir, .{});
        defer store.deinit();
        for (events[0..3]) |event| _ = try store.append(.{ .event = event });

        const publication = try store.writeReplaySnapshot(null);
        defer publication.deinit(std.testing.allocator);
        try std.testing.expectEqual(@as(u64, 3), publication.last_sequence);

        for (events[3..]) |event| _ = try store.append(.{ .event = event });
    }

    {
        var reopened = try fx.workflow.FileJournalStore.open(std.testing.allocator, std.testing.io, &tmp.dir, .{});
        defer reopened.deinit();

        var actual = try reopened.latestState(std.testing.allocator);
        defer actual.deinit();
        try expectWorkflowReplayStatesEqual(&expected, &actual);
    }
}

test "file workflow journal ignores uncommitted checkpoint files" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const events = [_]fx.workflow.WorkflowEvent{
        .{ .sequence = 1, .kind = .workflow_started, .workflow_id = 7, .execution_id = 8, .idempotency_key = "start" },
        .{ .sequence = 2, .kind = .workflow_completed, .workflow_id = 7, .execution_id = 8, .idempotency_key = "complete" },
    };

    {
        var store = try fx.workflow.FileJournalStore.open(std.testing.allocator, std.testing.io, &tmp.dir, .{});
        defer store.deinit();
        for (events[0..1]) |event| _ = try store.append(.{ .event = event });

        var state = try store.latestState(std.testing.allocator);
        defer state.deinit();
        const checkpoint_json = try fx.workflow.formatWorkflowCheckpointJson(std.testing.allocator, &state);
        defer std.testing.allocator.free(checkpoint_json);
        const checkpoint_name = try fx.workflow.checkpointFileName(std.testing.allocator, state.last_sequence);
        defer std.testing.allocator.free(checkpoint_name);
        const file = try tmp.dir.createFile(std.testing.io, checkpoint_name, .{ .read = true });
        defer file.close(std.testing.io);
        try file.writeStreamingAll(std.testing.io, checkpoint_json);

        _ = try store.append(.{ .event = events[1] });
    }

    var expected = try fx.workflow.WorkflowReplayState.fold(std.testing.allocator, &events);
    defer expected.deinit();

    var reopened = try fx.workflow.FileJournalStore.open(std.testing.allocator, std.testing.io, &tmp.dir, .{});
    defer reopened.deinit();
    var actual = try reopened.latestState(std.testing.allocator);
    defer actual.deinit();
    try expectWorkflowReplayStatesEqual(&expected, &actual);
}
```

- [ ] **Step 2: Run the red test**

Run:

```bash
bun run zigeffect:test
```

Expected: compile failure because `writeReplaySnapshot` and publication types do not exist.

- [ ] **Step 3: Implement snapshot publication and recovery**

Add `WorkflowSnapshotPublication` with owned names and `deinit`. Add
`FileJournalStore.base_state: ?WorkflowReplayState`.

Implement:

```zig
pub fn writeReplaySnapshot(self: *FileJournalStore, archive_name: ?[]const u8) !WorkflowSnapshotPublication
```

The method:

1. Calls `latestState`.
2. Writes checkpoint JSON through `dir.createFileAtomic(self.io, checkpoint_name, .{ .replace = true })`.
3. Writes snapshot commit JSON through `dir.createFileAtomic(self.io, commit_name, .{ .replace = true })`.
4. Returns owned checkpoint and commit file names.

Change `recover` to call `recoverLatestCommittedSnapshot` before segment scan.
During segment scan, skip rows with `event.sequence <= base_sequence`. Change
`latestState` to clone `base_state` and apply tail events before returning.

- [ ] **Step 4: Run the green test**

Run:

```bash
bun run zigeffect:test
```

Expected: tests pass.

- [ ] **Step 5: Commit**

```bash
git add packages/zigeffect/src/workflow/store.zig packages/zigeffect/src/workflow/root.zig packages/zigeffect/test/workflow_test.zig
git commit -m "feat(zigeffect): recover workflow journals from snapshots"
```

## Task 4: Archive Export

**Files:**
- Modify: `packages/zigeffect/test/workflow_test.zig`
- Modify: `packages/zigeffect/src/workflow/store.zig`
- Modify: `packages/zigeffect/src/workflow/root.zig`

- [ ] **Step 1: Write failing archive export test**

Add:

```zig
test "file workflow journal archive export writes replayable json lines" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const events = [_]fx.workflow.WorkflowEvent{
        .{ .sequence = 1, .kind = .workflow_started, .workflow_id = 7, .execution_id = 8, .idempotency_key = "start" },
        .{ .sequence = 2, .kind = .activity_scheduled, .workflow_id = 7, .execution_id = 8, .activity_id = 10, .name = "charge", .idempotency_key = "activity" },
        .{ .sequence = 3, .kind = .activity_completed, .workflow_id = 7, .execution_id = 8, .activity_id = 10, .idempotency_key = "activity-done" },
    };

    var expected = try fx.workflow.WorkflowReplayState.fold(std.testing.allocator, &events);
    defer expected.deinit();

    var store = try fx.workflow.FileJournalStore.open(std.testing.allocator, std.testing.io, &tmp.dir, .{});
    defer store.deinit();
    for (events) |event| _ = try store.append(.{ .event = event });

    const exported = try store.exportArchive(1, 3);
    defer exported.deinit(std.testing.allocator);
    try std.testing.expectEqualStrings("workflow-archive-0000000000000001-0000000000000003.jsonl", exported.archive_name);
    try std.testing.expectEqual(@as(usize, 3), exported.event_count);

    const archive = try tmp.dir.readFileAlloc(std.testing.io, exported.archive_name, std.testing.allocator, std.Io.Limit.limited(16 * 1024));
    defer std.testing.allocator.free(archive);
    try std.testing.expectEqual(@as(usize, 3), std.mem.count(u8, archive, "\n"));

    var archived_events = try parseWorkflowJsonLines(std.testing.allocator, archive);
    defer archived_events.deinit();
    var actual = try fx.workflow.WorkflowReplayState.fold(std.testing.allocator, archived_events.events);
    defer actual.deinit();
    try expectWorkflowReplayStatesEqual(&expected, &actual);
}
```

- [ ] **Step 2: Run the red test**

Run:

```bash
bun run zigeffect:test
```

Expected: compile failure for missing `exportArchive` and archive result type.

- [ ] **Step 3: Implement archive export**

Add `WorkflowArchiveExport` with `archive_name`, `first_sequence`,
`last_sequence`, `event_count`, `byte_count`, and `deinit`.

Implement:

```zig
pub fn exportArchive(self: *FileJournalStore, first_sequence: JournalSequence, last_sequence: JournalSequence) !WorkflowArchiveExport
```

It writes only in-memory tail events in the requested inclusive range using
`journal.formatWorkflowEventJson`, one newline per event, through
`self.dir.createFileAtomic(self.io, archive_name, .{ .replace = true })`.

- [ ] **Step 4: Run the green test**

Run:

```bash
bun run zigeffect:test
```

Expected: tests pass.

- [ ] **Step 5: Commit**

```bash
git add packages/zigeffect/src/workflow/store.zig packages/zigeffect/src/workflow/root.zig packages/zigeffect/test/workflow_test.zig
git commit -m "feat(zigeffect): export workflow journal archives"
```

## Task 5: Completed Workflow Compaction And Crash Safety

**Files:**
- Modify: `packages/zigeffect/test/workflow_test.zig`
- Modify: `packages/zigeffect/src/workflow/store.zig`
- Modify: `packages/zigeffect/src/workflow/root.zig`

- [ ] **Step 1: Write failing completed compaction tests**

Add:

```zig
test "file workflow journal compacts completed workflow after archive and snapshot commit" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const events = [_]fx.workflow.WorkflowEvent{
        .{ .sequence = 1, .kind = .workflow_started, .workflow_id = 7, .execution_id = 8, .idempotency_key = "start" },
        .{ .sequence = 2, .kind = .activity_scheduled, .workflow_id = 7, .execution_id = 8, .activity_id = 10, .name = "charge", .idempotency_key = "activity" },
        .{ .sequence = 3, .kind = .activity_completed, .workflow_id = 7, .execution_id = 8, .activity_id = 10, .idempotency_key = "activity-done" },
        .{ .sequence = 4, .kind = .workflow_completed, .workflow_id = 7, .execution_id = 8, .idempotency_key = "complete" },
    };
    var expected = try fx.workflow.WorkflowReplayState.fold(std.testing.allocator, &events);
    defer expected.deinit();

    {
        var store = try fx.workflow.FileJournalStore.open(std.testing.allocator, std.testing.io, &tmp.dir, .{});
        defer store.deinit();
        for (events) |event| _ = try store.append(.{ .event = event });

        const result = try store.compactCompleted(.{ .export_archive = true });
        defer result.deinit(std.testing.allocator);
        try std.testing.expect(result.compacted);
        try std.testing.expectEqual(@as(u64, 4), result.last_sequence.?);
        try std.testing.expectEqual(@as(usize, 4), result.archived_event_count);

        var state = try store.latestState(std.testing.allocator);
        defer state.deinit();
        try expectWorkflowReplayStatesEqual(&expected, &state);
    }

    const segment_name = try fx.workflow.segmentFileName(std.testing.allocator, 1);
    defer std.testing.allocator.free(segment_name);
    const compacted_segment = try tmp.dir.readFileAlloc(std.testing.io, segment_name, std.testing.allocator, std.Io.Limit.limited(16 * 1024));
    defer std.testing.allocator.free(compacted_segment);
    try std.testing.expectEqual(@as(usize, 0), compacted_segment.len);

    var reopened = try fx.workflow.FileJournalStore.open(std.testing.allocator, std.testing.io, &tmp.dir, .{});
    defer reopened.deinit();
    var actual = try reopened.latestState(std.testing.allocator);
    defer actual.deinit();
    try expectWorkflowReplayStatesEqual(&expected, &actual);
}

test "file workflow journal compaction leaves running workflow untouched" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    var store = try fx.workflow.FileJournalStore.open(std.testing.allocator, std.testing.io, &tmp.dir, .{});
    defer store.deinit();
    _ = try store.append(.{ .event = .{ .sequence = 1, .kind = .workflow_started, .workflow_id = 7, .execution_id = 8, .idempotency_key = "start" } });

    const result = try store.compactCompleted(.{ .export_archive = true });
    defer result.deinit(std.testing.allocator);
    try std.testing.expect(!result.compacted);
}

test "file workflow journal crash after snapshot commit replays without losing acknowledged rows" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const events = [_]fx.workflow.WorkflowEvent{
        .{ .sequence = 1, .kind = .workflow_started, .workflow_id = 7, .execution_id = 8, .idempotency_key = "start" },
        .{ .sequence = 2, .kind = .workflow_completed, .workflow_id = 7, .execution_id = 8, .idempotency_key = "complete" },
    };
    var expected = try fx.workflow.WorkflowReplayState.fold(std.testing.allocator, &events);
    defer expected.deinit();

    {
        var store = try fx.workflow.FileJournalStore.open(std.testing.allocator, std.testing.io, &tmp.dir, .{});
        defer store.deinit();
        for (events) |event| _ = try store.append(.{ .event = event });
        const publication = try store.writeReplaySnapshot(null);
        defer publication.deinit(std.testing.allocator);
    }

    var reopened = try fx.workflow.FileJournalStore.open(std.testing.allocator, std.testing.io, &tmp.dir, .{});
    defer reopened.deinit();
    var actual = try reopened.latestState(std.testing.allocator);
    defer actual.deinit();
    try expectWorkflowReplayStatesEqual(&expected, &actual);
}
```

- [ ] **Step 2: Run the red test**

Run:

```bash
bun run zigeffect:test
```

Expected: compile failure for missing compaction APIs.

- [ ] **Step 3: Implement compaction**

Add:

```zig
pub const WorkflowCompactionOptions = struct {
    export_archive: bool = true,
};

pub const WorkflowCompactionResult = struct {
    compacted: bool,
    last_sequence: ?JournalSequence = null,
    checkpoint_name: ?[]const u8 = null,
    commit_name: ?[]const u8 = null,
    archive_name: ?[]const u8 = null,
    archived_event_count: usize = 0,

    pub fn deinit(self: *const WorkflowCompactionResult, allocator: Allocator) void {
        if (self.checkpoint_name) |name| allocator.free(name);
        if (self.commit_name) |name| allocator.free(name);
        if (self.archive_name) |name| allocator.free(name);
    }
};
```

Implement `compactCompleted` to:

1. Fold latest state.
2. Return `compacted = false` when status is not terminal.
3. Export archive when requested.
4. Publish replay snapshot with the archive name.
5. Truncate the active segment with `self.dir.createFile(self.io, self.segment_name, .{ .truncate = true })`.
6. Set `base_state` to the compacted state clone.
7. Call `memory.resetFromSequence(last_sequence)`.

- [ ] **Step 4: Run the green test**

Run:

```bash
bun run zigeffect:test
```

Expected: tests pass.

- [ ] **Step 5: Commit**

```bash
git add packages/zigeffect/src/workflow/store.zig packages/zigeffect/src/workflow/root.zig packages/zigeffect/test/workflow_test.zig
git commit -m "feat(zigeffect): compact completed workflow journals"
```

## Task 6: Completed Retention Policies

**Files:**
- Modify: `packages/zigeffect/test/workflow_test.zig`
- Modify: `packages/zigeffect/src/workflow/store.zig`
- Modify: `packages/zigeffect/src/workflow/root.zig`

- [ ] **Step 1: Write failing retention tests**

Add:

```zig
test "workflow retention keep all leaves completed segment intact" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    var store = try fx.workflow.FileJournalStore.open(std.testing.allocator, std.testing.io, &tmp.dir, .{
        .retention_policy = .{ .completed = .keep_all },
    });
    defer store.deinit();
    _ = try store.append(.{ .event = .{ .sequence = 1, .kind = .workflow_started, .workflow_id = 7, .execution_id = 8, .idempotency_key = "start" } });
    _ = try store.append(.{ .event = .{ .sequence = 2, .kind = .workflow_completed, .workflow_id = 7, .execution_id = 8, .idempotency_key = "complete" } });

    const result = try store.applyRetentionPolicy();
    defer result.deinit(std.testing.allocator);
    try std.testing.expect(!result.compacted);

    const segment_name = try fx.workflow.segmentFileName(std.testing.allocator, 1);
    defer std.testing.allocator.free(segment_name);
    const segment = try tmp.dir.readFileAlloc(std.testing.io, segment_name, std.testing.allocator, std.Io.Limit.limited(16 * 1024));
    defer std.testing.allocator.free(segment);
    try std.testing.expectEqual(@as(usize, 2), std.mem.count(u8, segment, "\n"));
}

test "workflow retention archive then compact completed exports archive" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    var store = try fx.workflow.FileJournalStore.open(std.testing.allocator, std.testing.io, &tmp.dir, .{
        .retention_policy = .{ .completed = .archive_then_compact_completed },
    });
    defer store.deinit();
    _ = try store.append(.{ .event = .{ .sequence = 1, .kind = .workflow_started, .workflow_id = 7, .execution_id = 8, .idempotency_key = "start" } });
    _ = try store.append(.{ .event = .{ .sequence = 2, .kind = .workflow_completed, .workflow_id = 7, .execution_id = 8, .idempotency_key = "complete" } });

    const result = try store.applyRetentionPolicy();
    defer result.deinit(std.testing.allocator);
    try std.testing.expect(result.compacted);
    try std.testing.expect(result.archive_name != null);
}

test "workflow retention checkpoint only completed skips archive export" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    var store = try fx.workflow.FileJournalStore.open(std.testing.allocator, std.testing.io, &tmp.dir, .{
        .retention_policy = .{ .completed = .checkpoint_only_completed },
    });
    defer store.deinit();
    _ = try store.append(.{ .event = .{ .sequence = 1, .kind = .workflow_started, .workflow_id = 7, .execution_id = 8, .idempotency_key = "start" } });
    _ = try store.append(.{ .event = .{ .sequence = 2, .kind = .workflow_completed, .workflow_id = 7, .execution_id = 8, .idempotency_key = "complete" } });

    const result = try store.applyRetentionPolicy();
    defer result.deinit(std.testing.allocator);
    try std.testing.expect(result.compacted);
    try std.testing.expect(result.archive_name == null);
}
```

- [ ] **Step 2: Run the red test**

Run:

```bash
bun run zigeffect:test
```

Expected: compile failure for missing retention policy types and method.

- [ ] **Step 3: Implement retention policy**

Add:

```zig
pub const WorkflowCompletedRetentionPolicy = enum {
    keep_all,
    archive_then_compact_completed,
    checkpoint_only_completed,
};

pub const WorkflowRetentionPolicy = struct {
    completed: WorkflowCompletedRetentionPolicy = .keep_all,
};
```

Add `retention_policy: WorkflowRetentionPolicy = .{}` to
`FileJournalStoreOptions`. Implement:

```zig
pub fn applyRetentionPolicy(self: *FileJournalStore) !WorkflowCompactionResult
```

Switch on `self.options.retention_policy.completed` and call
`compactCompleted(.{ .export_archive = true })`,
`compactCompleted(.{ .export_archive = false })`, or return
`compacted = false`.

- [ ] **Step 4: Run the green test**

Run:

```bash
bun run zigeffect:test
```

Expected: tests pass.

- [ ] **Step 5: Commit**

```bash
git add packages/zigeffect/src/workflow/store.zig packages/zigeffect/src/workflow/root.zig packages/zigeffect/test/workflow_test.zig
git commit -m "feat(zigeffect): add workflow journal retention policies"
```

## Task 7: Documentation, Roadmap, And Verification

**Files:**
- Modify: `packages/zigeffect/docs/architecture.md`
- Modify: `docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md`

- [ ] **Step 1: Update architecture docs**

Add a section near workflow file journal storage:

```markdown
### Workflow Snapshots, Archives, And Compaction

The local workflow file store writes normal events to the active JSONL segment.
Replay snapshots use `workflow-checkpoint-{sequence}.json`, and
`workflow-snapshot-commit-{sequence}.json` is the commit point that makes a
checkpoint eligible for recovery. Recovery loads the highest committed
checkpoint and then replays only segment rows with a greater sequence.

Completed workflow compaction exports acknowledged rows to
`workflow-archive-{first}-{last}.jsonl`, commits a checkpoint, and truncates the
active segment only after the commit marker exists. A crash before the commit
falls back to full segment replay; a crash after the commit recovers from
checkpoint plus tail. Retention policies can keep all rows, archive then
compact completed workflows, or checkpoint-only compact completed workflows.
```

- [ ] **Step 2: Mark Milestone 21 complete in roadmap**

In `docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md`,
mark all Milestone 21 deliverables and acceptance checks as `[x]`.

- [ ] **Step 3: Run full verification gate**

Run:

```bash
bun run zigeffect:test
cd packages/zigeffect && zig build examples
bun run zig:test
zig fmt --check packages/zigeffect/src/workflow/replay.zig packages/zigeffect/src/workflow/store.zig packages/zigeffect/src/workflow/root.zig packages/zigeffect/test/workflow_test.zig
git diff --check
rg -n 'TO''DO|TB''D|implement'' later|fill'' in' packages/zigeffect/src/workflow packages/zigeffect/test/workflow_test.zig packages/zigeffect/docs/architecture.md docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md
```

Expected:

- all build and test commands pass;
- `zig fmt --check` passes;
- `git diff --check` produces no output;
- placeholder scan exits with no matches.

- [ ] **Step 4: Commit docs and roadmap**

```bash
git add packages/zigeffect/docs/architecture.md docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md
git commit -m "docs(zigeffect): mark workflow storage compaction complete"
```

## Self-Review

- Spec coverage: replay snapshots, safe compaction after completed sequences,
  retention policies, archive export, corruption-safe commit protocol, snapshot
  plus tail replay, and crash-during-compaction acceptance all map to tasks.
- Placeholder scan: the plan avoids open implementation placeholders and names
  concrete files, commands, types, and tests.
- Type consistency: public names match the design spec and are re-exported from
  `fx.workflow` through `root.zig`.
