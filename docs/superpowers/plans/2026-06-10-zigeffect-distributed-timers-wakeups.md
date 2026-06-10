# zigeffect Distributed Timers And Wakeups Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox syntax for tracking.

**Goal:** Add a journal-backed cluster timer wakeup index so due timers migrate with workflow execution shards and fire exactly once after runner ownership moves.

**Architecture:** Create `cluster/timer_wakeup.zig` as a synchronous rebuildable index over the workflow journal. The index derives timer ownership from `clusterWorkflowExecutionAddress(execution_id)` and `shardIdForAddress`, returns due/late wakeups, and leaves actual journal mutation to `ClusterWorkflowEngine.fireDueTimers`.

**Tech Stack:** Zig, `bun:test` wrapper commands, zigeffect workflow journal, local cluster runner, file-backed runner/message/journal storage.

---

Date: 2026-06-10

Milestone: 36 - Distributed Timers And Wakeups

Spec: `docs/superpowers/specs/2026-06-10-zigeffect-distributed-timers-wakeups-design.md`

## Files

Create:

- `packages/zigeffect/src/cluster/timer_wakeup.zig`
- `packages/zigeffect/test/cluster_timer_wakeup_test.zig`

Modify:

- `packages/zigeffect/src/cluster/root.zig`
- `packages/zigeffect/src/zigeffect.zig`
- `packages/zigeffect/test/all_test.zig`
- `packages/zigeffect/docs/architecture.md`
- `docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md`

## Task 1: Public Surface And Empty Index

**Files:**

- Create: `packages/zigeffect/test/cluster_timer_wakeup_test.zig`
- Create: `packages/zigeffect/src/cluster/timer_wakeup.zig`
- Modify: `packages/zigeffect/src/cluster/root.zig`
- Modify: `packages/zigeffect/src/zigeffect.zig`
- Modify: `packages/zigeffect/test/all_test.zig`

- [x] **Step 1: Write failing public surface tests**

Add:

```zig
test "cluster timer wakeup public exports are available" {
    try std.testing.expect(@hasDecl(fx.cluster, "timer_wakeup"));
    try std.testing.expect(@hasDecl(fx.cluster, "ClusterTimerWakeup"));
    try std.testing.expect(@hasDecl(fx.cluster, "ClusterTimerWakeupBatch"));
    try std.testing.expect(@hasDecl(fx.cluster, "ClusterTimerWakeupReport"));
    try std.testing.expect(@hasDecl(fx.cluster, "ClusterTimerWakeupIndex"));
    try std.testing.expect(@hasDecl(fx, "ClusterTimerWakeupIndex"));
}
```

Import the new test file from `packages/zigeffect/test/all_test.zig`.

- [x] **Step 2: Verify red**

Run:

```bash
bun run zigeffect:test
```

Expected: compile failure for missing cluster timer wakeup declarations.

- [x] **Step 3: Add minimal module and exports**

Implement:

```zig
pub const ClusterTimerWakeup = struct {
    workflow_id: WorkflowId,
    execution_id: ExecutionId,
    timer_id: TimerId,
    shard_id: ShardId,
    name: []const u8 = "",
    fire_at_ms: u64,
    late_by_ms: u64 = 0,
};
```

Also add `ClusterTimerWakeupBatch`, `ClusterTimerWakeupReport`, and
`ClusterTimerWakeupIndex` with `init`, `deinit`, and empty storage.

- [x] **Step 4: Verify green**

Run:

```bash
bun run zigeffect:test
zig fmt --check packages/zigeffect/src/cluster/timer_wakeup.zig packages/zigeffect/src/cluster/root.zig packages/zigeffect/src/zigeffect.zig packages/zigeffect/test/cluster_timer_wakeup_test.zig packages/zigeffect/test/all_test.zig
```

Expected: tests pass and formatting passes.

- [x] **Step 5: Commit**

```bash
git add packages/zigeffect/src/cluster/timer_wakeup.zig packages/zigeffect/src/cluster/root.zig packages/zigeffect/src/zigeffect.zig packages/zigeffect/test/cluster_timer_wakeup_test.zig packages/zigeffect/test/all_test.zig
git commit -m "feat(zigeffect): add cluster timer wakeup index surface"
```

## Task 2: Rebuild Owned Wakeups From Journal

**Files:**

- Modify: `packages/zigeffect/src/cluster/timer_wakeup.zig`
- Modify: `packages/zigeffect/test/cluster_timer_wakeup_test.zig`

- [x] **Step 1: Write failing rebuild tests**

Add tests:

- `cluster timer wakeup rebuild indexes owned scheduled timers`
- `cluster timer wakeup rebuild skips unowned timers`
- `cluster timer wakeup rebuild skips terminal timers`
- `cluster timer wakeup rebuild collapses duplicate schedules`

Use in-memory runner storage, message storage, journal storage, and helper
`executionIdForShard(shard_id, shard_count)` to create owned and unowned
executions.

- [x] **Step 2: Verify red**

Run:

```bash
bun run zigeffect:test
```

Expected: compile or assertion failure for missing `rebuildOwned` behavior.

- [x] **Step 3: Implement rebuild rules**

Add:

```zig
pub fn rebuildOwned(
    self: *ClusterTimerWakeupIndex,
    runner: *LocalClusterRunner,
    journal_store: JournalStore,
) !ClusterTimerWakeupReport
```

The method clears old wakeups, scans `journal_store.readAll`, evaluates only
`timer_scheduled` events with timer ids, parses `fire_at_ms=<u64>`, computes
the execution shard, filters unowned shards, filters terminal timers, and
deduplicates `(workflow_id, execution_id, timer_id)`.

- [x] **Step 4: Verify green**

Run:

```bash
bun run zigeffect:test
zig fmt --check packages/zigeffect/src/cluster/timer_wakeup.zig packages/zigeffect/test/cluster_timer_wakeup_test.zig
```

Expected: tests pass and formatting passes.

- [x] **Step 5: Commit**

```bash
git add packages/zigeffect/src/cluster/timer_wakeup.zig packages/zigeffect/test/cluster_timer_wakeup_test.zig
git commit -m "feat(zigeffect): rebuild owned timer wakeups"
```

## Task 3: Due Batches And Late Timer Reporting

**Files:**

- Modify: `packages/zigeffect/src/cluster/timer_wakeup.zig`
- Modify: `packages/zigeffect/test/cluster_timer_wakeup_test.zig`

- [x] **Step 1: Write failing due batch tests**

Add tests:

- `cluster timer wakeup due filters future timers`
- `cluster timer wakeup due reports late timers`

Assert that `due(allocator, 1_500)` excludes timers with `fire_at_ms = 2_000`
and returns timers with `fire_at_ms = 1_000` and `late_by_ms = 500`.

- [x] **Step 2: Verify red**

Run:

```bash
bun run zigeffect:test
```

Expected: compile or assertion failure for missing `due` behavior.

- [x] **Step 3: Implement due batches**

Add:

```zig
pub fn due(
    self: *const ClusterTimerWakeupIndex,
    allocator: Allocator,
    now_ms: u64,
) Allocator.Error!ClusterTimerWakeupBatch
```

Clone timer names into the returned batch, compute `late_by_ms`, and provide a
batch `deinit` that frees names and the owned slice.

- [x] **Step 4: Verify green**

Run:

```bash
bun run zigeffect:test
zig fmt --check packages/zigeffect/src/cluster/timer_wakeup.zig packages/zigeffect/test/cluster_timer_wakeup_test.zig
```

Expected: tests pass and formatting passes.

- [x] **Step 5: Commit**

```bash
git add packages/zigeffect/src/cluster/timer_wakeup.zig packages/zigeffect/test/cluster_timer_wakeup_test.zig
git commit -m "feat(zigeffect): report due cluster timer wakeups"
```

## Task 4: Idempotent Cluster Firing

**Files:**

- Modify: `packages/zigeffect/test/cluster_timer_wakeup_test.zig`

- [x] **Step 1: Write failing idempotency acceptance test**

Add:

```zig
test "cluster timer wakeup firing is idempotent through workflow entity" {
    // Seed started, timer_scheduled, workflow_suspended.
    // Register execution on the owning runner.
    // Rebuild the timer wakeup index.
    // Submit fireDueTimers twice through ClusterWorkflowEngine.
    // Process both commands with ClusterWorkflowEntityHandler.
    // Assert one timer_fired event exists in the journal.
}
```

Use the same message submission and reply parsing pattern as
`cluster_workflow_engine_test.zig`.

- [x] **Step 2: Verify red**

Run:

```bash
bun run zigeffect:test
```

Expected: failure if the existing command path appends duplicate timer terminal
events or if the test helpers are incomplete.

- [x] **Step 3: Implement any needed test helper support**

Keep production changes out of this task unless the test proves a real defect.
If a defect exists, fix it in `DurableClock.fireDueTimers` or
`ClusterWorkflowEntityHandler` with the smallest journal-based change.

- [x] **Step 4: Verify green**

Run:

```bash
bun run zigeffect:test
zig fmt --check packages/zigeffect/test/cluster_timer_wakeup_test.zig packages/zigeffect/src/workflow/clock.zig packages/zigeffect/src/cluster/workflow_engine.zig
```

Expected: tests pass and formatting passes.

- [x] **Step 5: Commit**

```bash
git add packages/zigeffect/test/cluster_timer_wakeup_test.zig packages/zigeffect/src/workflow/clock.zig packages/zigeffect/src/cluster/workflow_engine.zig
git commit -m "test(zigeffect): prove cluster timer fire idempotency"
```

If no production file changed, stage only the test file.

## Task 5: Runner Migration Acceptance

**Files:**

- Modify: `packages/zigeffect/test/cluster_timer_wakeup_test.zig`

- [x] **Step 1: Write failing migration test**

Add:

```zig
test "timer scheduled on runner a fires once after ownership moves" {
    // Use FileRunnerStorage, FileMessageStorage, and FileJournalStore in a tmp dir.
    // Runner A acquires shards.
    // Runner A starts workflow, appends timer_scheduled, appends workflow_suspended.
    // Runner A shuts down.
    // Runner B acquires shards and recovers workflow execution entities.
    // Runner B rebuilds ClusterTimerWakeupIndex.
    // Runner B submits fireDueTimers for each due wakeup.
    // Assert exactly one timer_fired and one workflow_resumed journal event.
}
```

- [x] **Step 2: Verify red**

Run:

```bash
bun run zigeffect:test
```

Expected: failure until the helper flow is complete.

- [x] **Step 3: Implement helper flow**

Reuse local helpers for:

- Creating runners.
- Processing a cluster workflow submission.
- Counting journal events by workflow event kind.
- Appending timer schedule and suspension events through `ClusterWorkflowEngine.appendEvent`.

Production changes should be limited to defects exposed by the migration test.

- [x] **Step 4: Verify green**

Run:

```bash
bun run zigeffect:test
zig fmt --check packages/zigeffect/test/cluster_timer_wakeup_test.zig
```

Expected: tests pass and formatting passes.

- [x] **Step 5: Commit**

```bash
git add packages/zigeffect/test/cluster_timer_wakeup_test.zig
git commit -m "test(zigeffect): prove timer wakeups migrate with shards"
```

## Task 6: Docs, Roadmap, And Full Gate

**Files:**

- Modify: `packages/zigeffect/docs/architecture.md`
- Modify: `docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md`

- [x] **Step 1: Update architecture docs**

Document `cluster/timer_wakeup.zig` as the rebuilt journal-backed index for
cluster timer ownership and late wakeup reporting.

- [x] **Step 2: Mark roadmap milestone complete**

Mark Milestone 36 checklist items complete after the verification gate passes.

- [x] **Step 3: Run full verification gate**

Run:

```bash
bun run zigeffect:test
(cd packages/zigeffect && zig build examples)
(cd packages/zigeffect && zig build cluster-runner -- --help)
bun run zig:test
zig fmt --check packages/zigeffect/src/cluster/timer_wakeup.zig packages/zigeffect/src/cluster/root.zig packages/zigeffect/src/zigeffect.zig packages/zigeffect/test/cluster_timer_wakeup_test.zig packages/zigeffect/test/all_test.zig
git diff --check
rg "TO""DO|FIX""ME|st""ub|place""holder|not imple""mented|unimple""mented" packages/zigeffect/src packages/zigeffect/test packages/zigeffect/docs docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md docs/superpowers/specs/2026-06-10-zigeffect-distributed-timers-wakeups-design.md docs/superpowers/plans/2026-06-10-zigeffect-distributed-timers-wakeups.md
```

Expected: all commands pass. The marker scan should return no matches.

- [x] **Step 4: Commit docs**

```bash
git add packages/zigeffect/docs/architecture.md docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md docs/superpowers/plans/2026-06-10-zigeffect-distributed-timers-wakeups.md
git commit -m "docs(zigeffect): mark distributed timer wakeups complete"
```

## Self-Review

- Spec coverage: timer ownership, rebuild after shard acquisition, duplicate
  firing prevention, late timer handling, and migration acceptance each map to a
  task.
- Marker scan: the command splits marker words so the plan does not match its
  own verification line.
- Type consistency: `ClusterTimerWakeupIndex`, `ClusterTimerWakeupBatch`,
  `ClusterTimerWakeupReport`, `rebuildOwned`, and `due` are named consistently
  across tasks.
