# zigeffect Performance And Bounded Resource Work Design

Date: 2026-06-10

Milestone: 43 - Performance And Bounded Resource Work

## Goal

Make local durable workflows and actor mailboxes viable for longer histories and
larger message sets by adding stable benchmark reporting, bounded-memory modes,
replay snapshot cadence controls, and backpressure metrics.

## Current Context

Workflow journal storage is centralized in `packages/zigeffect/src/workflow/store.zig`.
`JournalStore` already exposes append, read, replay, and reset operations.
`FileJournalStoreOptions` already includes `max_segment_bytes`, retention
policy, and fsync policy. The file store can write replay snapshots, export
archives, compact completed workflows, and recover from committed snapshots.

Local entity mailbox behavior is centralized in
`packages/zigeffect/src/cluster/mailbox.zig`. `LocalMailboxStore` supports
offer, take, pending count, reply storage, and deterministic message sequence
assignment, but it is currently unbounded.

Runtime queues in `packages/zigeffect/src/runtime/coordination.zig` already
support bounded capacity and expose `offerState`, `takeState`, and length.
Cluster observability in `packages/zigeffect/src/cluster/observability.zig`
already reports active leases, mailbox lag, retries, migrations, and failures.

M42 added deterministic generated workflow and message histories. M43 should
reuse that style: stable local reports, bounded case sizes, and tests that
assert report shape and guardrail behavior instead of relying on wall-clock
timings.

## Design Principles

- Benchmark output is stable by default. Reports include deterministic work
  counters, byte counts, threshold verdicts, and optional elapsed fields only
  when a caller explicitly asks for timing.
- Bounds are opt-in so existing tests and examples keep their current behavior.
- Limit errors are explicit and local. Reaching a journal or mailbox bound
  returns a typed error before accepting additional owned state.
- Snapshot cadence is a policy decision that can be inspected and invoked by
  schedulers or tools, rather than hidden inside append error paths.
- Metrics expose current pressure and capacity without requiring cluster
  transport or external telemetry.

## Components

### Journal Bounded Memory

Extend `InMemoryJournalStore` with optional bounds:

- `InMemoryJournalStoreOptions { max_events: ?usize = null }`;
- `InMemoryJournalStore.initBounded(allocator, options)`;
- `InMemoryJournalStore.capacityStats()`;
- `JournalCapacityStats { event_count, max_events, remaining_events }`;
- `JournalStoreError.EventLimitExceeded`.

`InMemoryJournalStore.init` remains unbounded and delegates to
`initBounded(.{})`. `append` checks the event bound before cloning the incoming
event. `FileJournalStoreOptions` gains `max_in_memory_events: ?usize = null`,
and `FileJournalStore.init` uses it for its internal replay tail store. This
gives callers a hard cap on active in-memory event rows after recovery or while
appending.

### Replay Snapshot Frequency

Add a small replay snapshot policy:

- `WorkflowSnapshotFrequency { every_events: ?JournalSequence = null }`;
- `WorkflowSnapshotFrequency.shouldSnapshot(last_sequence, base_sequence)`;
- `FileJournalStoreOptions.snapshot_frequency`.

Add `FileJournalStore.snapshotDue()` and
`FileJournalStore.writeReplaySnapshotIfDue()`. The due check uses the latest
state sequence, the committed base sequence, and the configured frequency. The
writer returns `?WorkflowSnapshotPublication`: `null` when no snapshot is due,
and a normal publication when a snapshot was written.

This keeps append durable and predictable: append persists the event, while
callers opt into snapshot publication at explicit scheduling points.

### Mailbox Bounded Memory And Backpressure

Extend `LocalMailboxStore` with optional bounds:

- `LocalMailboxStoreOptions { max_total_pending: ?usize = null, max_pending_per_mailbox: ?usize = null }`;
- `LocalMailboxStore.initBounded(allocator, options)`;
- `EntityMailboxError.MailboxFull`;
- `LocalMailboxStats { mailbox_count, total_pending, max_mailbox_pending, max_total_pending, max_pending_per_mailbox, backpressured_mailboxes }`;
- `LocalMailboxStore.stats()`.

`offer` checks total and per-mailbox capacity before cloning and appending the
envelope. `take` decrements the tracked total count. The stats function computes
backpressured mailbox count by comparing current mailbox lengths with the
configured per-mailbox capacity and also treats the entire store as
backpressured when total capacity is exhausted.

### Runtime Queue Metrics

Add a generic `QueueStats` result to `runtime/coordination.zig`:

- `QueueStats { len, capacity, remaining_capacity, offer_state, take_state }`;
- `Queue.stats()`.

This exposes existing bounded queue pressure without changing queue semantics.

### Cluster Backpressure Metrics

Extend `ClusterMetricsSnapshot` with:

- `message_backpressure`;
- `max_shard_mailbox_lag`.

`collectClusterMetrics` already scans unprocessed messages by shard. It can set
`max_shard_mailbox_lag` to the largest shard batch and set
`message_backpressure` to the number of shards whose lag is non-zero. This keeps
cluster metrics storage-agnostic while giving operators pressure signals.
`recordClusterMetrics` records gauges for both fields.

### Stable Benchmark Reports

Create `packages/zigeffect/src/performance/benchmark.zig` and export it through
`src/performance/root.zig` and `src/zigeffect.zig`.

The module owns:

- `PerformanceBenchmarkOptions { journal_events, mailbox_messages, entity_count, thresholds }`;
- `PerformanceThresholds { max_journal_events, max_journal_bytes, max_mailbox_messages, max_mailbox_peak_pending }`;
- `JournalBenchmarkReport { events_appended, events_replayed, serialized_bytes, state_rows }`;
- `MailboxBenchmarkReport { messages_offered, messages_taken, entity_count, peak_pending }`;
- `PerformanceBenchmarkReport { schema, schema_version, journal, mailbox, thresholds, threshold_violations }`;
- `runPerformanceBenchmarks(allocator, options)`;
- text and JSON formatters.

The benchmark runner uses the same public APIs users use:

- journal append and replay through `InMemoryJournalStore`;
- event serialization through `formatWorkflowEventJson`;
- mailbox offer, pending count, and take through `LocalMailboxStore`.

The default report is deterministic. It reports work performed and threshold
violations, not elapsed time. That makes CI and local output stable. Future live
profiling can layer on top without changing this report schema.

### Benchmark Tool And Build Step

Create `packages/zigeffect/tools/performance_bench.zig`.

Commands:

- default text report;
- `--json` JSON report;
- `--journal-events N`;
- `--mailbox-messages N`;
- `--entity-count N`.

Add a build step:

- `zig build performance-bench`;

and include tool tests in `zig build examples`, matching existing tool patterns.

## Tests

Add focused tests:

- `performance_benchmark_test.zig`: stable text and JSON report shape, threshold
  pass/fail behavior, journal and mailbox counters.
- `resource_bounds_test.zig`: in-memory journal event bound, file journal tail
  bound, mailbox total and per-mailbox bounds, mailbox stats, runtime queue
  stats.
- `workflow_snapshot_frequency_test.zig`: snapshot due checks and conditional
  snapshot publication.
- Extend `cluster_observability_test.zig` for `message_backpressure` and
  `max_shard_mailbox_lag`.

Add a focused build step:

- `zig build performance-bounds`;

This step runs benchmark, bounds, snapshot frequency, and observability tests.
The normal `zig build test` path also depends on these tests.

## Acceptance

- Journal append and replay benchmark reports have stable local text and JSON
  output with documented thresholds.
- Mailbox dispatch benchmark reports have stable local text and JSON output
  with documented thresholds.
- In-memory journal and local mailbox stores enforce opt-in bounds.
- File journal replay tail storage can be bounded through options.
- Replay snapshot frequency can be inspected and invoked explicitly.
- Queue, mailbox, and cluster metrics expose backpressure signals.
- `zig build performance-bounds`, `zig build performance-bench`,
  `bun run zigeffect:test`, `zig build examples`, and `bun run zig:test` pass.

## Out Of Scope

- Non-deterministic benchmarking as a correctness gate.
- Live distributed load testing.
- External telemetry exporters.
- Automatic snapshot publication inside `JournalStore.append`.
- Database-backed benchmark suites.

## Risks

- Too many new public knobs can make the API noisy. Mitigation: keep options
  grouped under existing store/mailbox option structs and retain unbounded
  defaults.
- Benchmark reports can be mistaken for real latency measurements. Mitigation:
  name fields as work counters and keep elapsed timing out of the default
  report.
- File journal bounds can reject recovery of an oversized active tail.
  Mitigation: document the behavior and pair it with snapshot frequency and
  compaction controls.

## Self-Review

- The design covers every M43 deliverable: journal benchmark, mailbox benchmark,
  bounded memory modes, snapshot frequency, and backpressure metrics.
- The benchmark acceptance is stable because default reports use deterministic
  counters and thresholds.
- Production behavior changes are opt-in except additional metrics fields.
- The work is focused enough for one implementation plan.
