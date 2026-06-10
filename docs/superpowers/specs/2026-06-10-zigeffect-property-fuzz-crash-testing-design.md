# zigeffect Property, Fuzz, And Crash Testing Design

Date: 2026-06-10

Milestone: 42 - Property, Fuzz, And Crash Testing

## Goal

Add deterministic generated-history tests that exercise workflow replay,
message storage, file-store recovery, and scheduler fairness across many small
cases. The milestone should increase confidence in durable behavior without
changing production workflow or cluster semantics.

## Current Context

Workflow replay is centralized in `src/workflow/replay.zig`.
`WorkflowReplayState.fold` and `WorkflowReplayState.apply` are the canonical
event reducers. `JournalStore` has in-memory and append-only file-backed
implementations in `src/workflow/store.zig`; the file store already recovers
complete JSONL rows, truncates partial trailing bytes, and exposes
`recoveredPartialBytes`.

Cluster message durability is centralized in `src/cluster/message_storage.zig`.
Both memory and file stores share the same vtable and now pass M41 conformance
tests. Scheduler fairness is localized in `src/workflow/scheduler.zig`, where
workflow workers, timer watches, and queue workers each advance through
round-robin cursors with explicit budgets.

Existing tests are example-based. M42 adds deterministic generated cases that
cover more combinations while staying reproducible and fast under
`bun run zigeffect:test`.

## Design Principles

- Generators are test support only. No public runtime API changes are required.
- Every generated case is deterministic from an explicit seed and case index.
- Generated histories are valid histories. Invalid-history diagnostics remain
  covered by existing replay tests.
- Property-style tests use fixed seed lists and bounded case counts so failures
  are reproducible and local.
- Crash testing simulates observable file-store crash windows: persisted
  prefixes and partial trailing JSONL rows.
- Scheduler fairness checks assert bounded visit spread, not exact internal
  cursor values.

## Components

### Workflow History Generator

Create `packages/zigeffect/test/support/workflow_history_generator.zig`.

The helper owns deterministic generation of valid `fx.workflow.WorkflowEvent`
arrays. It returns an owned `GeneratedWorkflowHistory` with:

- allocator;
- seed;
- case index;
- events;
- flags describing whether the history has activity, timer, deferred, queue,
  compensation, and terminal events.

The generator starts each history with `workflow_started`, then emits bounded
combinations of:

- activity scheduled, started, completed, failed, retry scheduled, or timed out;
- timer scheduled, fired, or cancelled;
- deferred created, awaited, completed, failed, or cancelled;
- queue offered, claimed, completed, failed, retry scheduled, or acked;
- compensation registered, started, completed, or failed;
- optional workflow terminal event.

Ordering constraints are encoded in the generator so replay receives valid
state transitions. Event ids and idempotency keys derive from the seed, case
index, sequence, and domain id. The generated strings are static enough to avoid
per-event allocator ownership in the source events; stores clone strings when
they need ownership.

### Replay Equivalence

Create `packages/zigeffect/test/property_history_test.zig`.

The tests compare four replay paths for each generated workflow history:

- direct `WorkflowReplayState.fold`;
- incremental `WorkflowReplayState.apply`;
- `InMemoryJournalStore.latestState` after appending all events;
- `FileJournalStore.latestState` after appending all events and reopening.

Add `test/support/replay_assertions.zig` with
`expectReplayStatesEqual(expected, actual)`. It compares workflow status,
workflow id, execution id, last sequence, and each replay row list by id,
status, last sequence, attempt, and name.

### Crash Injection

Create `packages/zigeffect/test/support/journal_crash_injection.zig`.

The helper provides deterministic file-store crash scenarios:

- append the first `N` generated events through `FileJournalStore`, reopen, and
  compare replay with the same prefix folded in memory;
- append a partial JSONL row for event `N + 1` directly to the active segment,
  reopen, assert `recoveredPartialBytes() > 0`, and compare replay with the
  complete prefix;
- run these windows across a bounded set of seeds and prefix lengths.

This targets the file store behavior the runtime can actually observe after a
process exits mid-write. It does not add production crash hooks or thread-level
fault injection.

Create `packages/zigeffect/test/crash_recovery_property_test.zig` for the
tests.

### Message History Generator

Create `packages/zigeffect/test/support/message_history_generator.zig`.

The helper owns deterministic generation and application of message operations:

- submit request messages to one or more shards;
- submit duplicate messages using identical kind, address, and idempotency key;
- claim a bounded subset of requests;
- store replies for a bounded subset of requests;
- ack a bounded subset of remaining requests.

The generator returns an owned `GeneratedMessageHistory` with operation records
and expected reply correlation ids. Tests apply the same operations to
`InMemoryMessageStorage` and `FileMessageStorage`, reopen the file store, and
compare:

- duplicate submit identity;
- unprocessed records per shard;
- unprocessed lookup by message id;
- stored replies by correlation id.

Create `packages/zigeffect/test/message_history_property_test.zig`.

### Scheduler Fairness Properties

Create `packages/zigeffect/test/scheduler_fairness_property_test.zig`.

The test file uses lightweight fake workflow and queue workers. For seeded
cases, it registers varied worker counts and runs the scheduler with small
budgets over multiple ticks. It asserts:

- every workflow worker is visited within a full round when budget permits;
- no workflow worker visit count differs from another by more than one after
  repeated one-at-a-time ticks;
- queue claim workers follow the same bounded spread property;
- `drain` reports budget exhaustion only when progress was made for the full
  iteration budget.

Timer fairness remains covered through the existing scheduler timer tests and
the cursor behavior exercised by registered watches; M42 focuses new property
coverage on worker queues where visit counts are directly observable.

### Focused Build Step

Add a `property-crash` Zig build step in `packages/zigeffect/build.zig`.

The step runs the new generated-history, message-history, crash-recovery, and
scheduler-fairness property tests. It is also included in the regular
`zig build test` path so `bun run zigeffect:test` keeps the generated suites
green.

## Files

Create:

- `packages/zigeffect/test/support/workflow_history_generator.zig`
- `packages/zigeffect/test/support/message_history_generator.zig`
- `packages/zigeffect/test/support/journal_crash_injection.zig`
- `packages/zigeffect/test/support/replay_assertions.zig`
- `packages/zigeffect/test/property_history_test.zig`
- `packages/zigeffect/test/message_history_property_test.zig`
- `packages/zigeffect/test/crash_recovery_property_test.zig`
- `packages/zigeffect/test/scheduler_fairness_property_test.zig`

Modify:

- `packages/zigeffect/test/all_test.zig`
- `packages/zigeffect/build.zig`
- `packages/zigeffect/docs/architecture.md`
- `docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md`

## Acceptance

- Generated workflow histories replay equivalently through fold, apply, memory
  journal store, and reopened file journal store.
- Generated message histories produce equivalent observable storage state across
  memory and reopened file stores.
- File journal recovery ignores partial trailing rows and reports recovered
  bytes.
- Scheduler property tests prove bounded visit spread for workflow and queue
  workers under small budgets.
- `zig build property-crash`, `bun run zigeffect:test`, `zig build examples`,
  and `bun run zig:test` pass.

## Out Of Scope

- Runtime-level process management or OS crash orchestration.
- Non-deterministic fuzzing that produces irreproducible failures.
- External fuzzing engines.
- Production database crash testing.
- Changing workflow or cluster runtime behavior except where a generated test
  exposes a concrete bug.

## Risks

- Generated histories can become too broad and slow. Mitigation: fixed seed
  lists, small operation counts, and a focused build step.
- Comparing replay states by list order could hide semantic equivalence if
  later replay chooses sorted storage. Mitigation: current replay preserves
  append order; if that changes, update `replay_assertions.zig` to sort by id.
- Partial-row crash tests must avoid relying on private file-store internals
  beyond the documented segment naming helper. Mitigation: use
  `workflow.segmentFileName` and public recovery accessors.

## Self-Review

- Scope matches M42 deliverables: generated workflow histories, generated
  message histories, crash point injection, replay equivalence, and scheduler
  fairness.
- No production runtime behavior is added for testing-only concerns.
- The design has one focused implementation plan and bounded verification
  commands.
