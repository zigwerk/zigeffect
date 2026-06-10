# zigeffect Performance And Bounded Resource Work Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement M43 performance benchmarks, bounded memory modes, snapshot cadence controls, and backpressure metrics.

**Architecture:** Add opt-in production bounds to workflow journals and local mailboxes, expose pressure stats from queues/mailboxes/cluster metrics, and add a deterministic performance report module plus a CLI build step. Keep benchmark reports stable by using work counters and threshold verdicts rather than wall-clock values.

**Tech Stack:** Zig, zigeffect workflow and cluster modules, existing Zig build steps, and Bun wrapper verification commands.

---

## File Responsibilities

Create:

- `packages/zigeffect/src/performance/root.zig`: performance namespace facade.
- `packages/zigeffect/src/performance/benchmark.zig`: deterministic benchmark report types, runner, text formatter, and JSON formatter.
- `packages/zigeffect/test/performance_benchmark_test.zig`: benchmark report tests.
- `packages/zigeffect/test/resource_bounds_test.zig`: journal, mailbox, and queue bound tests.
- `packages/zigeffect/test/workflow_snapshot_frequency_test.zig`: snapshot cadence tests.
- `packages/zigeffect/tools/performance_bench.zig`: CLI-style benchmark report tool.

Modify:

- `packages/zigeffect/src/workflow/store.zig`: journal bounds and snapshot frequency controls.
- `packages/zigeffect/src/workflow/root.zig`: workflow exports.
- `packages/zigeffect/src/cluster/mailbox.zig`: mailbox bounds and stats.
- `packages/zigeffect/src/cluster/root.zig`: cluster exports.
- `packages/zigeffect/src/runtime/coordination.zig`: queue stats.
- `packages/zigeffect/src/zigeffect.zig`: performance namespace and top-level aliases.
- `packages/zigeffect/src/cluster/observability.zig`: cluster backpressure metric fields.
- `packages/zigeffect/test/architecture_test.zig`: facade coverage.
- `packages/zigeffect/test/cluster_observability_test.zig`: metric coverage.
- `packages/zigeffect/test/all_test.zig`: import new tests.
- `packages/zigeffect/build.zig`: focused `performance-bounds` step and `performance-bench` tool step.
- `packages/zigeffect/docs/architecture.md`: document performance and bounded resource surfaces.
- `docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md`: mark M43 complete after verification.

## Task 1: Journal Event Bounds

**Files:**

- Create: `packages/zigeffect/test/resource_bounds_test.zig`
- Modify: `packages/zigeffect/test/all_test.zig`
- Modify: `packages/zigeffect/src/workflow/store.zig`
- Modify: `packages/zigeffect/src/workflow/root.zig`

- [x] **Step 1: Write failing journal bound tests**

Create `resource_bounds_test.zig` with tests for:

```zig
test "in-memory journal store enforces opt-in event bounds" {
    var store = fx.workflow.InMemoryJournalStore.initBounded(std.testing.allocator, .{ .max_events = 2 });
    defer store.deinit();
    const journal = store.asJournalStore();

    _ = try journal.append(.{ .event = workflowEvent(1, .workflow_started, "bound-1") });
    _ = try journal.append(.{ .event = workflowEvent(2, .step_started, "bound-2") });
    try std.testing.expectError(error.EventLimitExceeded, journal.append(.{
        .event = workflowEvent(3, .step_completed, "bound-3"),
    }));

    const stats = store.capacityStats();
    try std.testing.expectEqual(@as(usize, 2), stats.event_count);
    try std.testing.expectEqual(@as(?usize, 2), stats.max_events);
    try std.testing.expectEqual(@as(?usize, 0), stats.remaining_events);
}
```

Add a second test that opens `FileJournalStore` with
`.max_in_memory_events = 1`, appends one event, and expects
`error.EventLimitExceeded` on the second append. Import
`resource_bounds_test.zig` from `all_test.zig`.

- [x] **Step 2: Run failing test**

Run:

```bash
(cd packages/zigeffect && zig build test-raw)
```

Expected: FAIL with missing `initBounded`, `capacityStats`, and
`max_in_memory_events` declarations.

- [x] **Step 3: Implement journal bounds**

In `store.zig` add:

```zig
pub const JournalCapacityStats = struct {
    event_count: usize = 0,
    max_events: ?usize = null,
    remaining_events: ?usize = null,
};

pub const InMemoryJournalStoreOptions = struct {
    max_events: ?usize = null,
};
```

Add `EventLimitExceeded` to `JournalStoreError`.

Add `options: InMemoryJournalStoreOptions = .{}` to
`InMemoryJournalStore`, implement `initBounded`, make `init` delegate to it,
check `max_events` in `validateAppend`, and implement `capacityStats`.

Add `max_in_memory_events: ?usize = null` to `FileJournalStoreOptions` and
initialize the internal memory store with `InMemoryJournalStore.initBounded`.

Export `JournalCapacityStats` and `InMemoryJournalStoreOptions` through
`workflow/root.zig`.

- [x] **Step 4: Verify and commit**

Run:

```bash
(cd packages/zigeffect && zig build test-raw)
zig fmt --check packages/zigeffect/src/workflow/store.zig packages/zigeffect/src/workflow/root.zig packages/zigeffect/test/resource_bounds_test.zig packages/zigeffect/test/all_test.zig
```

Expected: PASS.

Commit:

```bash
git add packages/zigeffect/src/workflow/store.zig packages/zigeffect/src/workflow/root.zig packages/zigeffect/test/resource_bounds_test.zig packages/zigeffect/test/all_test.zig
git diff --cached --check
git commit -m "feat(zigeffect): add journal event bounds"
```

## Task 2: Mailbox Bounds And Queue Stats

**Files:**

- Modify: `packages/zigeffect/test/resource_bounds_test.zig`
- Modify: `packages/zigeffect/src/cluster/mailbox.zig`
- Modify: `packages/zigeffect/src/cluster/root.zig`
- Modify: `packages/zigeffect/src/runtime/coordination.zig`
- Modify: `packages/zigeffect/src/zigeffect.zig`

- [x] **Step 1: Add failing mailbox and queue tests**

Extend `resource_bounds_test.zig` with tests for:

- `LocalMailboxStore.initBounded(.{ .max_total_pending = 2 })` returning
  `error.MailboxFull` on the third offer;
- `LocalMailboxStore.initBounded(.{ .max_pending_per_mailbox = 1 })` returning
  `error.MailboxFull` on a second offer to the same address;
- `LocalMailboxStore.stats()` reporting mailbox count, total pending,
  max mailbox pending, configured bounds, and backpressured mailbox count;
- `fx.runtime.Queue(u8).bounded(...).stats()` reporting length, capacity,
  remaining capacity, offer state, and take state.

- [x] **Step 2: Run failing test**

Run:

```bash
(cd packages/zigeffect && zig build test-raw)
```

Expected: FAIL with missing mailbox options/stats and queue stats.

- [x] **Step 3: Implement mailbox bounds**

In `cluster/mailbox.zig` add:

```zig
pub const LocalMailboxStoreOptions = struct {
    max_total_pending: ?usize = null,
    max_pending_per_mailbox: ?usize = null,
};

pub const LocalMailboxStats = struct {
    mailbox_count: usize = 0,
    total_pending: usize = 0,
    max_mailbox_pending: usize = 0,
    max_total_pending: ?usize = null,
    max_pending_per_mailbox: ?usize = null,
    backpressured_mailboxes: usize = 0,
};
```

Add `MailboxFull` to `EntityMailboxError`. Add `options` and
`total_pending` fields to `LocalMailboxStore`, implement `initBounded`,
make `init` delegate to it, check total and per-mailbox capacity before
accepting an offer, decrement `total_pending` on take, and implement `stats`.

Export `LocalMailboxStoreOptions` and `LocalMailboxStats` through
`cluster/root.zig` and `src/zigeffect.zig`.

- [x] **Step 4: Implement queue stats**

In `runtime/coordination.zig` add:

```zig
pub const QueueStats = struct {
    len: usize,
    capacity: ?usize,
    remaining_capacity: ?usize,
    offer_state: QueueOfferState,
    take_state: QueueTakeState,
};
```

Add `Queue.stats()` for each queue instance. Export `QueueStats` through the
runtime namespace and top-level facade.

- [x] **Step 5: Verify and commit**

Run:

```bash
(cd packages/zigeffect && zig build test-raw)
zig fmt --check packages/zigeffect/src/cluster/mailbox.zig packages/zigeffect/src/cluster/root.zig packages/zigeffect/src/runtime/coordination.zig packages/zigeffect/src/zigeffect.zig packages/zigeffect/test/resource_bounds_test.zig
```

Expected: PASS.

Commit:

```bash
git add packages/zigeffect/src/cluster/mailbox.zig packages/zigeffect/src/cluster/root.zig packages/zigeffect/src/runtime/coordination.zig packages/zigeffect/src/zigeffect.zig packages/zigeffect/test/resource_bounds_test.zig
git diff --cached --check
git commit -m "feat(zigeffect): add mailbox and queue pressure stats"
```

## Task 3: Cluster Backpressure Metrics

**Files:**

- Modify: `packages/zigeffect/src/cluster/observability.zig`
- Modify: `packages/zigeffect/test/cluster_observability_test.zig`

- [x] **Step 1: Add failing metric assertions**

Extend `cluster_observability_test.zig` so `collectClusterMetrics` asserts:

- `snapshot.max_shard_mailbox_lag` equals the largest unprocessed message count
  for a shard;
- `snapshot.message_backpressure` equals the number of shards with non-zero lag;
- `recordClusterMetrics` records `cluster.messages.backpressure` and
  `cluster.mailbox.lag.max`.

- [x] **Step 2: Run failing test**

Run:

```bash
(cd packages/zigeffect && zig build test-raw)
```

Expected: FAIL with missing metric fields.

- [x] **Step 3: Implement metric fields**

Add fields to `ClusterMetricsSnapshot`, compute them inside
`collectClusterMetrics`, and record gauges in `recordClusterMetrics`.

- [x] **Step 4: Verify and commit**

Run:

```bash
(cd packages/zigeffect && zig build test-raw)
zig fmt --check packages/zigeffect/src/cluster/observability.zig packages/zigeffect/test/cluster_observability_test.zig
```

Expected: PASS.

Commit:

```bash
git add packages/zigeffect/src/cluster/observability.zig packages/zigeffect/test/cluster_observability_test.zig
git diff --cached --check
git commit -m "feat(zigeffect): add cluster backpressure metrics"
```

## Task 4: Replay Snapshot Frequency

**Files:**

- Create: `packages/zigeffect/test/workflow_snapshot_frequency_test.zig`
- Modify: `packages/zigeffect/src/workflow/store.zig`
- Modify: `packages/zigeffect/src/workflow/root.zig`
- Modify: `packages/zigeffect/test/all_test.zig`

- [x] **Step 1: Add failing snapshot cadence tests**

Create tests for:

- `WorkflowSnapshotFrequency.shouldSnapshot(10, 0)` with every 5 events returns
  true;
- `shouldSnapshot(12, 10)` returns false because only 2 tail events exist;
- `FileJournalStore.snapshotDue()` follows configured frequency;
- `writeReplaySnapshotIfDue()` writes a publication only when due.

Import the test from `all_test.zig`.

- [x] **Step 2: Run failing test**

Run:

```bash
(cd packages/zigeffect && zig build test-raw)
```

Expected: FAIL with missing snapshot frequency declarations.

- [x] **Step 3: Implement snapshot frequency**

Add:

```zig
pub const WorkflowSnapshotFrequency = struct {
    every_events: ?JournalSequence = null,
    pub fn shouldSnapshot(self: WorkflowSnapshotFrequency, last_sequence: JournalSequence, base_sequence: JournalSequence) bool { ... }
};
```

Add `snapshot_frequency: WorkflowSnapshotFrequency = .{}` to
`FileJournalStoreOptions`, implement `snapshotDue`, and implement
`writeReplaySnapshotIfDue`. Export through `workflow/root.zig`.

- [x] **Step 4: Verify and commit**

Run:

```bash
(cd packages/zigeffect && zig build test-raw)
zig fmt --check packages/zigeffect/src/workflow/store.zig packages/zigeffect/src/workflow/root.zig packages/zigeffect/test/workflow_snapshot_frequency_test.zig packages/zigeffect/test/all_test.zig
```

Expected: PASS.

Commit:

```bash
git add packages/zigeffect/src/workflow/store.zig packages/zigeffect/src/workflow/root.zig packages/zigeffect/test/workflow_snapshot_frequency_test.zig packages/zigeffect/test/all_test.zig
git diff --cached --check
git commit -m "feat(zigeffect): add replay snapshot frequency"
```

## Task 5: Deterministic Benchmark Reports

**Files:**

- Create: `packages/zigeffect/src/performance/root.zig`
- Create: `packages/zigeffect/src/performance/benchmark.zig`
- Create: `packages/zigeffect/test/performance_benchmark_test.zig`
- Modify: `packages/zigeffect/src/zigeffect.zig`
- Modify: `packages/zigeffect/test/architecture_test.zig`
- Modify: `packages/zigeffect/test/all_test.zig`

- [x] **Step 1: Add failing benchmark report tests**

Create tests asserting:

- `fx.performance.runPerformanceBenchmarks` exists;
- default report appends and replays requested journal events;
- mailbox report offers and takes requested messages;
- threshold violations are deterministic;
- text output includes schema, journal counters, mailbox counters, and verdict;
- JSON output includes `"schema":"zigeffect.performance.benchmark.v1"`.

Add facade assertions to `architecture_test.zig` and import
`performance_benchmark_test.zig` from `all_test.zig`.

- [x] **Step 2: Run failing test**

Run:

```bash
(cd packages/zigeffect && zig build test-raw)
```

Expected: FAIL with missing performance namespace declarations.

- [x] **Step 3: Implement performance module**

Create the performance root and benchmark module with schema constants, report
types, threshold helpers, `runPerformanceBenchmarks`, `formatPerformanceBenchmarkText`,
and `formatPerformanceBenchmarkJson`.

Implementation rules:

- Generate workflow events locally in the benchmark module using static event
  names and unique idempotency keys.
- Use `InMemoryJournalStore` for append/replay counters.
- Use `LocalMailboxStore` for offer/take counters.
- Keep default thresholds permissive enough for default options and strict
  thresholds useful in tests.

- [x] **Step 4: Export the namespace**

Add `pub const performance = @import("performance/root.zig");` to
`src/zigeffect.zig`, plus top-level aliases for report options, report types,
runner, and formatters.

- [x] **Step 5: Verify and commit**

Run:

```bash
(cd packages/zigeffect && zig build test-raw)
zig fmt --check packages/zigeffect/src/performance/root.zig packages/zigeffect/src/performance/benchmark.zig packages/zigeffect/src/zigeffect.zig packages/zigeffect/test/performance_benchmark_test.zig packages/zigeffect/test/architecture_test.zig packages/zigeffect/test/all_test.zig
```

Expected: PASS.

Commit:

```bash
git add packages/zigeffect/src/performance packages/zigeffect/src/zigeffect.zig packages/zigeffect/test/performance_benchmark_test.zig packages/zigeffect/test/architecture_test.zig packages/zigeffect/test/all_test.zig
git diff --cached --check
git commit -m "feat(zigeffect): add deterministic performance reports"
```

## Task 6: Benchmark Tool And Focused Build Steps

**Files:**

- Create: `packages/zigeffect/tools/performance_bench.zig`
- Modify: `packages/zigeffect/build.zig`

- [x] **Step 1: Add failing build-step checks**

Run:

```bash
(cd packages/zigeffect && zig build performance-bounds)
(cd packages/zigeffect && zig build performance-bench)
```

Expected: both commands fail because the steps are absent.

- [x] **Step 2: Implement benchmark tool**

Create `tools/performance_bench.zig` with:

- a `run(allocator, args, writer)` function for tests;
- default text output;
- `--json`;
- `--journal-events N`;
- `--mailbox-messages N`;
- `--entity-count N`;
- tests for text, JSON, and invalid numeric arguments.

- [x] **Step 3: Wire build steps**

In `build.zig`:

- create test modules for `performance_benchmark_test.zig`,
  `resource_bounds_test.zig`, and `workflow_snapshot_frequency_test.zig`;
- create `performance-bounds` step depending on those tests and the updated
  cluster observability tests through the package test path;
- create executable `zigeffect-performance-bench`;
- add run step `performance-bench`;
- add tool tests to `examples_step`;
- add focused test run artifacts to the main `test_step`.

- [x] **Step 4: Verify and commit**

Run:

```bash
(cd packages/zigeffect && zig build performance-bounds)
(cd packages/zigeffect && zig build performance-bench)
(cd packages/zigeffect && zig build performance-bench -- --json)
(cd packages/zigeffect && zig build test-raw)
zig fmt --check packages/zigeffect/tools/performance_bench.zig packages/zigeffect/build.zig
```

Expected: PASS.

Commit:

```bash
git add packages/zigeffect/tools/performance_bench.zig packages/zigeffect/build.zig
git diff --cached --check
git commit -m "build(zigeffect): add performance benchmark steps"
```

## Task 7: Docs, Roadmap, And Full Verification

**Files:**

- Modify: `packages/zigeffect/docs/architecture.md`
- Modify: `packages/zigeffect/README.md`
- Modify: `docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md`

- [x] **Step 1: Document M43 surfaces**

Update architecture docs to mention:

- `src/performance/`;
- journal event bounds and capacity stats;
- snapshot frequency checks;
- local mailbox bounds and stats;
- queue stats;
- cluster backpressure metrics;
- `performance-bench` and `performance-bounds` build steps.

Update README commands so local users can run the focused bounded-resource gate
and print the benchmark report in text or JSON mode. Document the default
thresholds beside those commands.

- [x] **Step 2: Mark M43 complete**

Update the M43 roadmap block:

```markdown
- [x] Benchmark journal append and replay.
- [x] Benchmark mailbox dispatch.
- [x] Add bounded memory modes.
- [x] Add replay snapshot frequency tuning.
- [x] Add backpressure metrics.
```

and:

```markdown
- [x] Benchmarks have stable local output and documented thresholds.
```

- [x] **Step 3: Run full verification**

Run:

```bash
(cd packages/zigeffect && zig build performance-bounds)
(cd packages/zigeffect && zig build performance-bench)
(cd packages/zigeffect && zig build performance-bench -- --json)
bun run zigeffect:test
(cd packages/zigeffect && zig build examples)
bun run zig:test
zig fmt --check \
  packages/zigeffect/src/workflow/store.zig \
  packages/zigeffect/src/workflow/root.zig \
  packages/zigeffect/src/cluster/mailbox.zig \
  packages/zigeffect/src/cluster/root.zig \
  packages/zigeffect/src/runtime/coordination.zig \
  packages/zigeffect/src/cluster/observability.zig \
  packages/zigeffect/src/performance/root.zig \
  packages/zigeffect/src/performance/benchmark.zig \
  packages/zigeffect/src/zigeffect.zig \
  packages/zigeffect/test/resource_bounds_test.zig \
  packages/zigeffect/test/workflow_snapshot_frequency_test.zig \
  packages/zigeffect/test/performance_benchmark_test.zig \
  packages/zigeffect/test/cluster_observability_test.zig \
  packages/zigeffect/test/architecture_test.zig \
  packages/zigeffect/test/all_test.zig \
  packages/zigeffect/tools/performance_bench.zig \
  packages/zigeffect/build.zig
git diff --check
rg -n 'T''BD|TO''DO|FIX''ME|st''ub|place''holder|not imple''mented|unimple''mented|fi''ll in|add app''ropriate|sim''ilar to' \
  packages/zigeffect/src/workflow/store.zig \
  packages/zigeffect/src/workflow/root.zig \
  packages/zigeffect/src/cluster/mailbox.zig \
  packages/zigeffect/src/cluster/root.zig \
  packages/zigeffect/src/runtime/coordination.zig \
  packages/zigeffect/src/cluster/observability.zig \
  packages/zigeffect/src/performance/root.zig \
  packages/zigeffect/src/performance/benchmark.zig \
  packages/zigeffect/src/zigeffect.zig \
  packages/zigeffect/test/resource_bounds_test.zig \
  packages/zigeffect/test/workflow_snapshot_frequency_test.zig \
  packages/zigeffect/test/performance_benchmark_test.zig \
  packages/zigeffect/test/cluster_observability_test.zig \
  packages/zigeffect/test/architecture_test.zig \
  packages/zigeffect/test/all_test.zig \
  packages/zigeffect/tools/performance_bench.zig \
  packages/zigeffect/build.zig \
  packages/zigeffect/docs/architecture.md \
  docs/superpowers/specs/2026-06-10-zigeffect-performance-bounded-resource-design.md \
  docs/superpowers/plans/2026-06-10-zigeffect-performance-bounded-resource.md \
  docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md
git status --short
```

Expected: build and test commands pass, format and diff checks pass, marker
scan exits with no matches, and git status is clean after commits.

- [x] **Step 4: Commit docs**

Commit:

```bash
git add packages/zigeffect/docs/architecture.md packages/zigeffect/README.md docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md docs/superpowers/plans/2026-06-10-zigeffect-performance-bounded-resource.md
git diff --cached --check
git commit -m "docs(zigeffect): mark performance bounds complete"
```

## Self-Review

- Journal benchmark work is covered by Task 5 and Task 6.
- Mailbox benchmark work is covered by Task 5 and Task 6.
- Bounded memory modes are covered by Task 1 and Task 2.
- Replay snapshot frequency tuning is covered by Task 4.
- Backpressure metrics are covered by Task 2 and Task 3.
- Stable local benchmark output and documented thresholds are covered by Task 5,
  Task 6, and Task 7.
