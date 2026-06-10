# zigeffect Property, Fuzz, And Crash Testing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add deterministic generated-history, crash-recovery, replay-equivalence, and scheduler-fairness tests for M42.

**Architecture:** Keep generation and comparison code in test support modules, then exercise the public workflow and cluster storage APIs from focused test files. The only production change expected by the plan is a scheduler fairness fix if the retry-scanning property demonstrates skew under one-worker budgets.

**Tech Stack:** Zig, `bun:test` wrapper commands, zigeffect workflow journal stores, zigeffect cluster message storage, and the existing Zig build system.

---

## Context Map

- `packages/zigeffect/src/workflow/journal.zig` owns `WorkflowEvent`, event kind names, JSON formatters, parser, clone, and free helpers.
- `packages/zigeffect/src/workflow/replay.zig` owns `WorkflowReplayState.fold` and `WorkflowReplayState.apply`.
- `packages/zigeffect/src/workflow/store.zig` owns `JournalStore`, `InMemoryJournalStore`, `FileJournalStore`, `segmentFileName`, and `recoveredPartialBytes`.
- `packages/zigeffect/src/cluster/envelope.zig` owns `MessageEnvelope`, computed message ids, correlations, clone, and free helpers.
- `packages/zigeffect/src/cluster/message_storage.zig` owns `MessageStorage`, in-memory storage, file storage, and observable unprocessed/reply queries.
- `packages/zigeffect/src/workflow/scheduler.zig` owns registered workflow workers, registered queue workers, tick/drain budgets, and fairness cursors.
- `packages/zigeffect/test/all_test.zig` imports package-wide tests.
- `packages/zigeffect/build.zig` defines focused test steps such as `storage-conformance`.
- `docs/superpowers/specs/2026-06-10-zigeffect-property-fuzz-crash-testing-design.md` is the M42 design checkpoint.

## File Responsibilities

Create:

- `packages/zigeffect/test/support/replay_assertions.zig`: deep equality assertions for replay states.
- `packages/zigeffect/test/support/workflow_history_generator.zig`: deterministic valid workflow history generator.
- `packages/zigeffect/test/support/journal_crash_injection.zig`: file journal prefix and partial-tail recovery helpers.
- `packages/zigeffect/test/support/message_history_generator.zig`: deterministic message operation generator and observable-storage comparison helpers.
- `packages/zigeffect/test/property_history_test.zig`: generated workflow replay equivalence tests.
- `packages/zigeffect/test/crash_recovery_property_test.zig`: generated file journal crash recovery tests.
- `packages/zigeffect/test/message_history_property_test.zig`: generated message storage equivalence tests.
- `packages/zigeffect/test/scheduler_fairness_property_test.zig`: generated scheduler fairness tests.

Modify:

- `packages/zigeffect/src/workflow/scheduler.zig`: add a queue retry cursor only if the retry fairness test fails.
- `packages/zigeffect/test/all_test.zig`: import the new test files.
- `packages/zigeffect/build.zig`: add `property-crash` focused test step and wire it into `zig build test`.
- `packages/zigeffect/docs/architecture.md`: document generated property/crash suites and the retry fairness cursor.
- `docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md`: mark M42 deliverables and acceptance complete after verification.

## Determinism Rules

- Use fixed seed arrays in test files.
- Keep per-seed case counts bounded: 12 workflow cases, 10 message cases, and 8 scheduler cases are enough for M42.
- Include seed and case index in every generated idempotency key and assertion failure message where practical.
- Use only public workflow and cluster APIs. Direct file writes are allowed only for the partial-tail crash helper because it simulates a process exit during an append.

## Task 1: Add Replay Assertion Support

**Files:**

- Create: `packages/zigeffect/test/support/replay_assertions.zig`
- Create: `packages/zigeffect/test/property_history_test.zig`
- Modify: `packages/zigeffect/test/all_test.zig`

- [ ] **Step 1: Write the failing replay assertion test import**

Add `packages/zigeffect/test/property_history_test.zig` with a small hand-built replay comparison:

```zig
const std = @import("std");
const fx = @import("zigeffect");
const replay_assertions = @import("support/replay_assertions.zig");

test "replay assertion helper compares complete workflow replay state" {
    const events = [_]fx.workflow.WorkflowEvent{
        .{
            .sequence = 1,
            .kind = .workflow_started,
            .workflow_id = 101,
            .execution_id = 202,
            .name = "property-workflow",
            .status = "running",
            .idempotency_key = "property-start",
        },
        .{
            .sequence = 2,
            .kind = .activity_scheduled,
            .workflow_id = 101,
            .execution_id = 202,
            .activity_id = 301,
            .attempt = 1,
            .name = "activity",
            .status = "scheduled",
            .idempotency_key = "property-activity",
        },
    };

    var expected = try fx.workflow.WorkflowReplayState.fold(std.testing.allocator, &events);
    defer expected.deinit();
    var actual = try fx.workflow.WorkflowReplayState.fold(std.testing.allocator, &events);
    defer actual.deinit();

    try replay_assertions.expectReplayStatesEqual(&expected, &actual);
}
```

Add this import to `packages/zigeffect/test/all_test.zig`:

```zig
    _ = @import("property_history_test.zig");
```

- [ ] **Step 2: Run the focused failing command**

Run:

```bash
(cd packages/zigeffect && zig build test-raw)
```

Expected: FAIL because `support/replay_assertions.zig` does not exist yet.

- [ ] **Step 3: Implement replay assertions**

Create `packages/zigeffect/test/support/replay_assertions.zig` with one exported function:

```zig
const std = @import("std");
const fx = @import("zigeffect");

pub fn expectReplayStatesEqual(
    expected: *const fx.workflow.WorkflowReplayState,
    actual: *const fx.workflow.WorkflowReplayState,
) !void {
    try std.testing.expectEqual(expected.workflow_status, actual.workflow_status);
    try std.testing.expectEqual(expected.workflow_id, actual.workflow_id);
    try std.testing.expectEqual(expected.execution_id, actual.execution_id);
    try std.testing.expectEqual(expected.last_sequence, actual.last_sequence);

    try expectActivitiesEqual(expected.activities.items, actual.activities.items);
    try expectTimersEqual(expected.timers.items, actual.timers.items);
    try expectDeferredsEqual(expected.deferreds.items, actual.deferreds.items);
    try expectQueuesEqual(expected.queues.items, actual.queues.items);
    try expectCompensationsEqual(expected.compensations.items, actual.compensations.items);
}
```

Add private helpers named `expectActivitiesEqual`, `expectTimersEqual`, `expectDeferredsEqual`, `expectQueuesEqual`, and `expectCompensationsEqual`. Each helper compares list length, id, status, last sequence, name, and activity attempt where relevant.

- [ ] **Step 4: Verify and commit**

Run:

```bash
(cd packages/zigeffect && zig build test-raw)
zig fmt --check packages/zigeffect/test/property_history_test.zig packages/zigeffect/test/support/replay_assertions.zig packages/zigeffect/test/all_test.zig
```

Expected: PASS.

Commit:

```bash
git add packages/zigeffect/test/property_history_test.zig packages/zigeffect/test/support/replay_assertions.zig packages/zigeffect/test/all_test.zig
git diff --cached --check
git commit -m "test(zigeffect): add replay assertion support"
```

## Task 2: Generate Valid Workflow Histories

**Files:**

- Create: `packages/zigeffect/test/support/workflow_history_generator.zig`
- Modify: `packages/zigeffect/test/property_history_test.zig`

- [ ] **Step 1: Add failing generator coverage**

Extend `packages/zigeffect/test/property_history_test.zig`:

```zig
const workflow_history_generator = @import("support/workflow_history_generator.zig");

test "generated workflow histories are valid replay inputs" {
    const seeds = [_]u64{ 0x42, 0x1234, 0x9e3779b97f4a7c15 };
    for (seeds) |seed| {
        var case_index: usize = 0;
        while (case_index < 12) : (case_index += 1) {
            var history = try workflow_history_generator.generateWorkflowHistory(
                std.testing.allocator,
                seed,
                case_index,
            );
            defer history.deinit();

            try std.testing.expect(history.events.len >= 1);
            try std.testing.expectEqual(fx.workflow.WorkflowEventKind.workflow_started, history.events[0].kind);
            var state = try fx.workflow.WorkflowReplayState.fold(std.testing.allocator, history.events);
            defer state.deinit();
            try std.testing.expectEqual(history.events[history.events.len - 1].sequence, state.last_sequence);
        }
    }
}
```

- [ ] **Step 2: Run the failing command**

Run:

```bash
(cd packages/zigeffect && zig build test-raw)
```

Expected: FAIL because `support/workflow_history_generator.zig` does not exist yet.

- [ ] **Step 3: Implement the generator**

Create a generator module with:

```zig
pub const GeneratedWorkflowHistory = struct {
    allocator: std.mem.Allocator,
    seed: u64,
    case_index: usize,
    events: []fx.workflow.WorkflowEvent,
    has_activity: bool = false,
    has_timer: bool = false,
    has_deferred: bool = false,
    has_queue: bool = false,
    has_compensation: bool = false,
    has_terminal: bool = false,

    pub fn deinit(self: *GeneratedWorkflowHistory) void {
        for (self.events) |event| fx.workflow.deinitWorkflowEventStrings(self.allocator, event);
        self.allocator.free(self.events);
    }
};

pub fn generateWorkflowHistory(
    allocator: std.mem.Allocator,
    seed: u64,
    case_index: usize,
) !GeneratedWorkflowHistory
```

Implementation details:

- Use `std.Random.DefaultPrng.init(seed ^ (@as(u64, case_index) << 32) ^ 0xa11ce5eed)` for deterministic choices.
- Use workflow id `10_000 + (seed % 10_000) + case_index` and execution id `workflow_id + 1_000_000`.
- Start with `workflow_started` at sequence 1.
- Append at most one valid chain for activity, timer, deferred, queue, compensation, and suspend/resume.
- Append terminal workflow state only after all non-terminal domain events.
- Allocate `name`, `status`, `redacted_detail`, and `idempotency_key` with `std.fmt.allocPrint` so every generated event owns strings.
- On error, free every owned event already appended.

- [ ] **Step 4: Verify and commit**

Run:

```bash
(cd packages/zigeffect && zig build test-raw)
zig fmt --check packages/zigeffect/test/property_history_test.zig packages/zigeffect/test/support/workflow_history_generator.zig
```

Expected: PASS.

Commit:

```bash
git add packages/zigeffect/test/property_history_test.zig packages/zigeffect/test/support/workflow_history_generator.zig
git diff --cached --check
git commit -m "test(zigeffect): generate workflow histories"
```

## Task 3: Add Replay Equivalence Across Fold, Apply, Memory, And File Stores

**Files:**

- Modify: `packages/zigeffect/test/property_history_test.zig`

- [ ] **Step 1: Add failing equivalence coverage**

Add helper functions to `property_history_test.zig`:

```zig
fn appendHistory(store: fx.workflow.JournalStore, events: []const fx.workflow.WorkflowEvent) !void {
    for (events) |event| {
        _ = try store.append(.{ .expected_next_sequence = event.sequence, .event = event });
    }
}

fn incrementalReplay(events: []const fx.workflow.WorkflowEvent) !fx.workflow.WorkflowReplayState {
    var state = fx.workflow.WorkflowReplayState.init(std.testing.allocator);
    errdefer state.deinit();
    for (events) |event| try state.apply(event);
    return state;
}
```

Add the generated equivalence test:

```zig
test "generated workflow histories replay equivalently through stores" {
    const seeds = [_]u64{ 0x42, 0x5150, 0xabcdef, 0x9e3779b97f4a7c15 };
    for (seeds) |seed| {
        var case_index: usize = 0;
        while (case_index < 12) : (case_index += 1) {
            var history = try workflow_history_generator.generateWorkflowHistory(
                std.testing.allocator,
                seed,
                case_index,
            );
            defer history.deinit();

            var folded = try fx.workflow.WorkflowReplayState.fold(std.testing.allocator, history.events);
            defer folded.deinit();
            var applied = try incrementalReplay(history.events);
            defer applied.deinit();
            try replay_assertions.expectReplayStatesEqual(&folded, &applied);

            var memory_state = fx.workflow.InMemoryJournalStore.init(std.testing.allocator);
            defer memory_state.deinit();
            try appendHistory(memory_state.asJournalStore(), history.events);
            var memory_replay = try memory_state.asJournalStore().latestState(std.testing.allocator);
            defer memory_replay.deinit();
            try replay_assertions.expectReplayStatesEqual(&folded, &memory_replay);

            var tmp = std.testing.tmpDir(.{});
            defer tmp.cleanup();
            {
                var file_state = try fx.workflow.FileJournalStore.open(std.testing.allocator, std.testing.io, &tmp.dir, .{});
                defer file_state.deinit();
                try appendHistory(file_state.asJournalStore(), history.events);
            }
            var reopened_state = try fx.workflow.FileJournalStore.open(std.testing.allocator, std.testing.io, &tmp.dir, .{});
            defer reopened_state.deinit();
            var file_replay = try reopened_state.asJournalStore().latestState(std.testing.allocator);
            defer file_replay.deinit();
            try replay_assertions.expectReplayStatesEqual(&folded, &file_replay);
        }
    }
}
```

- [ ] **Step 2: Run the test**

Run:

```bash
(cd packages/zigeffect && zig build test-raw)
```

Expected: PASS. If it fails, inspect the generated seed/case by reducing the seed list to one case, fix the generator validity issue, then restore the full seed list.

- [ ] **Step 3: Verify and commit**

Run:

```bash
(cd packages/zigeffect && zig build test-raw)
zig fmt --check packages/zigeffect/test/property_history_test.zig
```

Expected: PASS.

Commit:

```bash
git add packages/zigeffect/test/property_history_test.zig
git diff --cached --check
git commit -m "test(zigeffect): check workflow replay equivalence"
```

## Task 4: Add File Journal Crash Injection Properties

**Files:**

- Create: `packages/zigeffect/test/support/journal_crash_injection.zig`
- Create: `packages/zigeffect/test/crash_recovery_property_test.zig`
- Modify: `packages/zigeffect/test/all_test.zig`

- [ ] **Step 1: Add failing crash recovery tests**

Create `packages/zigeffect/test/crash_recovery_property_test.zig`:

```zig
const std = @import("std");
const workflow_history_generator = @import("support/workflow_history_generator.zig");
const journal_crash_injection = @import("support/journal_crash_injection.zig");

test "file journal recovers generated prefixes" {
    const seeds = [_]u64{ 0x91, 0x5151, 0x7777 };
    for (seeds) |seed| {
        var history = try workflow_history_generator.generateWorkflowHistory(std.testing.allocator, seed, 0);
        defer history.deinit();
        var prefix_len: usize = 0;
        while (prefix_len <= history.events.len) : (prefix_len += 1) {
            try journal_crash_injection.expectFileJournalPrefixRecovers(history.events, prefix_len);
        }
    }
}

test "file journal trims generated partial trailing rows" {
    const seeds = [_]u64{ 0x92, 0x6161, 0x8888 };
    for (seeds) |seed| {
        var history = try workflow_history_generator.generateWorkflowHistory(std.testing.allocator, seed, 1);
        defer history.deinit();
        var prefix_len: usize = 0;
        while (prefix_len + 1 < history.events.len) : (prefix_len += 2) {
            try journal_crash_injection.expectFileJournalPartialTailRecovers(history.events, prefix_len);
        }
    }
}
```

Add this import to `all_test.zig`:

```zig
    _ = @import("crash_recovery_property_test.zig");
```

- [ ] **Step 2: Run the failing command**

Run:

```bash
(cd packages/zigeffect && zig build test-raw)
```

Expected: FAIL because `support/journal_crash_injection.zig` does not exist yet.

- [ ] **Step 3: Implement crash injection helpers**

Create `journal_crash_injection.zig` with:

```zig
pub fn expectFileJournalPrefixRecovers(
    events: []const fx.workflow.WorkflowEvent,
    prefix_len: usize,
) !void

pub fn expectFileJournalPartialTailRecovers(
    events: []const fx.workflow.WorkflowEvent,
    prefix_len: usize,
) !void
```

Implementation details:

- Use `std.testing.tmpDir(.{})` inside each helper.
- Append `events[0..prefix_len]` through `FileJournalStore.open(...).asJournalStore().append`.
- Reopen the store and compare `latestState` against `WorkflowReplayState.fold(events[0..prefix_len])`.
- For partial-tail recovery, close the store, format `events[prefix_len]` with `fx.workflow.formatWorkflowEventJson`, write the first half of that JSON to the active segment returned by `fx.workflow.segmentFileName`, omit the newline, reopen the store, assert `recoveredPartialBytes() > 0`, and compare replay with the prefix only.

- [ ] **Step 4: Verify and commit**

Run:

```bash
(cd packages/zigeffect && zig build test-raw)
zig fmt --check packages/zigeffect/test/crash_recovery_property_test.zig packages/zigeffect/test/support/journal_crash_injection.zig packages/zigeffect/test/all_test.zig
```

Expected: PASS.

Commit:

```bash
git add packages/zigeffect/test/crash_recovery_property_test.zig packages/zigeffect/test/support/journal_crash_injection.zig packages/zigeffect/test/all_test.zig
git diff --cached --check
git commit -m "test(zigeffect): add journal crash properties"
```

## Task 5: Add Message History Generation And Storage Equivalence

**Files:**

- Create: `packages/zigeffect/test/support/message_history_generator.zig`
- Create: `packages/zigeffect/test/message_history_property_test.zig`
- Modify: `packages/zigeffect/test/all_test.zig`

- [ ] **Step 1: Add failing message property tests**

Create `message_history_property_test.zig`:

```zig
const std = @import("std");
const fx = @import("zigeffect");
const message_history_generator = @import("support/message_history_generator.zig");

test "generated message histories match across memory and reopened file storage" {
    const seeds = [_]u64{ 0x22, 0x3333, 0x4444, 0x9e3779b97f4a7c15 };
    for (seeds) |seed| {
        var case_index: usize = 0;
        while (case_index < 10) : (case_index += 1) {
            var history = try message_history_generator.generateMessageHistory(
                std.testing.allocator,
                seed,
                case_index,
            );
            defer history.deinit();

            var memory_state = fx.InMemoryMessageStorage.init(std.testing.allocator);
            defer memory_state.deinit();
            var memory_observed = try message_history_generator.applyMessageHistory(
                std.testing.allocator,
                memory_state.asMessageStorage(),
                history,
            );
            defer memory_observed.deinit();

            var tmp = std.testing.tmpDir(.{});
            defer tmp.cleanup();
            {
                var file_state = try fx.FileMessageStorage.open(std.testing.allocator, std.testing.io, &tmp.dir, .{});
                defer file_state.deinit();
                var file_observed = try message_history_generator.applyMessageHistory(
                    std.testing.allocator,
                    file_state.asMessageStorage(),
                    history,
                );
                file_observed.deinit();
            }

            var reopened_state = try fx.FileMessageStorage.open(std.testing.allocator, std.testing.io, &tmp.dir, .{});
            defer reopened_state.deinit();
            var reopened_observed = try message_history_generator.observeMessageStorage(
                std.testing.allocator,
                reopened_state.asMessageStorage(),
                memory_observed.message_ids,
                memory_observed.reply_correlation_ids,
            );
            defer reopened_observed.deinit();

            try message_history_generator.expectMessageObservationsEqual(&memory_observed, &reopened_observed);
        }
    }
}
```

Add this import to `all_test.zig`:

```zig
    _ = @import("message_history_property_test.zig");
```

- [ ] **Step 2: Run the failing command**

Run:

```bash
(cd packages/zigeffect && zig build test-raw)
```

Expected: FAIL because `support/message_history_generator.zig` does not exist yet.

- [ ] **Step 3: Implement message generator and observation helpers**

Create `message_history_generator.zig` with:

```zig
pub const MessageRequestPlan = struct {
    shard_id: fx.ShardId,
    address_key: []const u8,
    idempotency_key: []const u8,
    payload: []const u8,
    submit_duplicate: bool,
    claim: bool,
    store_reply: bool,
    ack: bool,
};

pub const GeneratedMessageHistory = struct {
    allocator: std.mem.Allocator,
    seed: u64,
    case_index: usize,
    requests: []MessageRequestPlan,
    pub fn deinit(self: *GeneratedMessageHistory) void { ... }
};

pub const MessageObservation = struct {
    allocator: std.mem.Allocator,
    message_ids: []fx.MessageId,
    reply_correlation_ids: []fx.MessageCorrelationId,
    unprocessed: []ObservedMessageRecord,
    replies: []ObservedReply,
    pub fn deinit(self: *MessageObservation) void { ... }
};
```

Implementation details:

- Allocate request strings with `std.fmt.allocPrint`.
- `generateMessageHistory` creates 3 to 6 request plans across shard ids 1 to 4.
- `applyMessageHistory` submits each request, optionally submits the duplicate and asserts `.duplicate`, optionally claims, optionally stores a reply, optionally acks if the request was not replied.
- `observeMessageStorage` reads `unprocessedByShard` for shards 1 through 4, reads `unprocessedById` for each message id, and reads replies for each correlation id.
- `expectMessageObservationsEqual` compares ids, statuses, attempts, payloads, and reply payloads.
- Sort observed records by message id before comparison so memory and file directory iteration order cannot affect assertions.

- [ ] **Step 4: Verify and commit**

Run:

```bash
(cd packages/zigeffect && zig build test-raw)
zig fmt --check packages/zigeffect/test/message_history_property_test.zig packages/zigeffect/test/support/message_history_generator.zig packages/zigeffect/test/all_test.zig
```

Expected: PASS.

Commit:

```bash
git add packages/zigeffect/test/message_history_property_test.zig packages/zigeffect/test/support/message_history_generator.zig packages/zigeffect/test/all_test.zig
git diff --cached --check
git commit -m "test(zigeffect): generate message histories"
```

## Task 6: Add Scheduler Fairness Properties And Fix Retry Scanning

**Files:**

- Create: `packages/zigeffect/test/scheduler_fairness_property_test.zig`
- Modify: `packages/zigeffect/src/workflow/scheduler.zig`
- Modify: `packages/zigeffect/test/all_test.zig`

- [ ] **Step 1: Add failing scheduler fairness properties**

Create `scheduler_fairness_property_test.zig` with:

```zig
const std = @import("std");
const fx = @import("zigeffect");

const CountingWorkflowWorker = struct {
    id: usize,
    counts: []usize,
    step: fx.workflow.RunnableWorkflowStep = .progressed,

    fn registered(self: *CountingWorkflowWorker) fx.workflow.RegisteredWorkflowWorker {
        return .{
            .context = self,
            .workflow_id = @intCast(self.id + 1),
            .execution_id = @intCast(self.id + 1001),
            .name = "property-workflow-worker",
            .poll_fn = poll,
        };
    }

    fn poll(context: *anyopaque) anyerror!fx.workflow.RunnableWorkflowStep {
        const self: *CountingWorkflowWorker = @ptrCast(@alignCast(context));
        self.counts[self.id] += 1;
        return self.step;
    }
};

const CountingQueueWorker = struct {
    id: usize,
    retry_counts: []usize,
    claim_counts: []usize,

    fn registered(self: *CountingQueueWorker) fx.workflow.RegisteredQueueWorker {
        return .{
            .context = self,
            .workflow_id = @intCast(self.id + 2001),
            .execution_id = @intCast(self.id + 3001),
            .name = "property-queue-worker",
            .retry_expired_fn = retryExpired,
            .process_one_fn = processOne,
        };
    }

    fn retryExpired(context: *anyopaque) anyerror!usize {
        const self: *CountingQueueWorker = @ptrCast(@alignCast(context));
        self.retry_counts[self.id] += 1;
        return 1;
    }

    fn processOne(context: *anyopaque) anyerror!fx.workflow.QueueWorkerStep {
        const self: *CountingQueueWorker = @ptrCast(@alignCast(context));
        self.claim_counts[self.id] += 1;
        return .{ .completed = @intCast(self.id + 1) };
    }
};
```

Add tests that create `2..7` workers and run repeated one-at-a-time ticks:

- workflow worker counts differ by at most one;
- queue claim counts differ by at most one;
- queue retry counts differ by at most one;
- `drain` sets `budget_exhausted` only when each budgeted iteration made progress.

Add this import to `all_test.zig`:

```zig
    _ = @import("scheduler_fairness_property_test.zig");
```

- [ ] **Step 2: Run the failing command**

Run:

```bash
(cd packages/zigeffect && zig build test-raw)
```

Expected: FAIL on the queue retry fairness property because `retryExpiredQueueClaims` always begins at index 0.

- [ ] **Step 3: Fix queue retry fairness**

Modify `packages/zigeffect/src/workflow/scheduler.zig`:

```zig
    queue_workers: std.ArrayList(RegisteredQueueWorker) = .empty,
    queue_retry_cursor: usize = 0,
    queue_cursor: usize = 0,
```

Change `retryExpiredQueueClaims` to use the retry cursor:

```zig
    fn retryExpiredQueueClaims(self: *WorkflowScheduler, max_workers: usize, result: *WorkflowSchedulerTickResult) anyerror!void {
        const len = self.queue_workers.items.len;
        if (len == 0 or max_workers == 0) return;

        const visits = @min(max_workers, len);
        var count: usize = 0;
        while (count < visits) : (count += 1) {
            const index = self.queue_retry_cursor % len;
            self.queue_retry_cursor = (index + 1) % len;
            result.queue_retries += try self.queue_workers.items[index].retryExpired();
        }
    }
```

- [ ] **Step 4: Verify and commit**

Run:

```bash
(cd packages/zigeffect && zig build test-raw)
zig fmt --check packages/zigeffect/src/workflow/scheduler.zig packages/zigeffect/test/scheduler_fairness_property_test.zig packages/zigeffect/test/all_test.zig
```

Expected: PASS.

Commit:

```bash
git add packages/zigeffect/src/workflow/scheduler.zig packages/zigeffect/test/scheduler_fairness_property_test.zig packages/zigeffect/test/all_test.zig
git diff --cached --check
git commit -m "test(zigeffect): add scheduler fairness properties"
```

## Task 7: Add Focused Build Step

**Files:**

- Modify: `packages/zigeffect/build.zig`

- [ ] **Step 1: Add failing build-step expectation**

Run:

```bash
(cd packages/zigeffect && zig build property-crash)
```

Expected: FAIL because the build step is not registered yet.

- [ ] **Step 2: Register property test modules**

In `packages/zigeffect/build.zig`, after the storage conformance step, add modules and run artifacts for:

- `test/property_history_test.zig`
- `test/crash_recovery_property_test.zig`
- `test/message_history_property_test.zig`
- `test/scheduler_fairness_property_test.zig`

For each module:

```zig
    const property_history_test_module = b.createModule(.{
        .root_source_file = b.path("test/property_history_test.zig"),
        .target = target,
        .optimize = optimize,
    });
    property_history_test_module.addImport("zigeffect", zigeffect);

    const property_history_tests = b.addTest(.{
        .name = "zigeffect-property-history-tests",
        .root_module = property_history_test_module,
    });
    const run_property_history_tests = b.addRunArtifact(property_history_tests);
```

Add:

```zig
    const property_crash_step = b.step("property-crash", "Run generated workflow, message, crash, and scheduler property tests");
    property_crash_step.dependOn(&run_property_history_tests.step);
    property_crash_step.dependOn(&run_crash_recovery_property_tests.step);
    property_crash_step.dependOn(&run_message_history_property_tests.step);
    property_crash_step.dependOn(&run_scheduler_fairness_property_tests.step);
```

Add the same four run artifacts to the main `test_step` near the existing `run_storage_conformance_tests` dependency.

- [ ] **Step 3: Verify and commit**

Run:

```bash
(cd packages/zigeffect && zig build property-crash)
(cd packages/zigeffect && zig build test-raw)
zig fmt --check packages/zigeffect/build.zig
```

Expected: PASS.

Commit:

```bash
git add packages/zigeffect/build.zig
git diff --cached --check
git commit -m "build(zigeffect): add property crash test step"
```

## Task 8: Update Documentation And Roadmap

**Files:**

- Modify: `packages/zigeffect/docs/architecture.md`
- Modify: `docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md`

- [ ] **Step 1: Document generated property suites**

In `packages/zigeffect/docs/architecture.md`, update the workflow storage conformance paragraph to mention generated workflow histories, replay equivalence, and crash recovery. Update the cooperative scheduler section to mention independent workflow, timer, queue retry, and queue claim cursors. Update the cluster storage conformance paragraph to mention generated message histories across memory and file stores.

- [ ] **Step 2: Mark M42 complete in the roadmap**

In the M42 block, change each deliverable and acceptance checkbox to complete:

```markdown
- [x] Add generated workflow histories.
- [x] Add generated message histories.
- [x] Add crash point injection.
- [x] Add replay equivalence checks.
- [x] Add scheduler fairness checks.
```

```markdown
- [x] Generated tests find no replay divergence across memory and file stores.
```

- [ ] **Step 3: Verify and commit**

Run:

```bash
rg -n "Milestone 42|property-crash|generated workflow|generated message|queue retry" packages/zigeffect/docs/architecture.md docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md
git diff --check
```

Expected: PASS.

Commit:

```bash
git add packages/zigeffect/docs/architecture.md docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md
git diff --cached --check
git commit -m "docs(zigeffect): mark property crash testing complete"
```

## Task 9: Full M42 Verification Gate

**Files:** all files changed by M42.

- [ ] **Step 1: Run the focused test step**

Run:

```bash
(cd packages/zigeffect && zig build property-crash)
```

Expected: PASS.

- [ ] **Step 2: Run package verification**

Run:

```bash
bun run zigeffect:test
(cd packages/zigeffect && zig build examples)
bun run zig:test
```

Expected: PASS.

- [ ] **Step 3: Run formatting and marker gates**

Run:

```bash
zig fmt --check \
  packages/zigeffect/src/workflow/scheduler.zig \
  packages/zigeffect/test/support/replay_assertions.zig \
  packages/zigeffect/test/support/workflow_history_generator.zig \
  packages/zigeffect/test/support/journal_crash_injection.zig \
  packages/zigeffect/test/support/message_history_generator.zig \
  packages/zigeffect/test/property_history_test.zig \
  packages/zigeffect/test/crash_recovery_property_test.zig \
  packages/zigeffect/test/message_history_property_test.zig \
  packages/zigeffect/test/scheduler_fairness_property_test.zig \
  packages/zigeffect/test/all_test.zig \
  packages/zigeffect/build.zig
git diff --check
rg -n 'T''BD|TO''DO|FIX''ME|st''ub|place''holder|not imple''mented|unimple''mented|fi''ll in|add app''ropriate|sim''ilar to' \
  packages/zigeffect/src \
  packages/zigeffect/test \
  packages/zigeffect/docs \
  docs/superpowers/specs \
  docs/superpowers/plans
```

Expected: format checks pass, diff check passes, and marker scan exits with no matches.

- [ ] **Step 4: Final status**

Run:

```bash
git status --short
git log --oneline -8
```

Expected: clean worktree and M42 commits visible at the top of the branch.

## Self-Review

- Generated workflow histories are covered by Task 2.
- Replay equivalence across fold, apply, memory store, and file store is covered by Task 3.
- Crash point injection is covered by Task 4.
- Generated message histories are covered by Task 5.
- Scheduler fairness is covered by Task 6, including the known retry scanner skew.
- Focused build integration is covered by Task 7.
- Docs, roadmap, and verification are covered by Tasks 8 and 9.
