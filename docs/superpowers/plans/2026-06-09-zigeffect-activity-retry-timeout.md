# zigeffect Activity Retry And Timeout Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add durable retry decisions, clock-backed retry delays, timeout terminal events, exhausted retry behavior, and causal schedule-decision mapping to workflow activities.

**Architecture:** Extend the workflow journal with retry and timeout events before changing execution. Then teach `WorkflowContext.activity` to loop through retry schedules, use optional clock and causal store integrations, and replay completed, failed, exhausted, and timed-out terminal outcomes without invoking the runner.

**Tech Stack:** Zig 0.16, existing `Schedule`, existing `Clock`, existing `CausalStore`, existing `WorkflowContext.activity`, existing journal store/replay/checkpoint modules, Bun project scripts.

---

## File Structure

- Modify `packages/zigeffect/src/workflow/journal.zig`
  - Add retry and timeout event kinds and stable names.
- Modify `packages/zigeffect/src/workflow/replay.zig`
  - Fold retry scheduled and timeout events into activity state.
- Modify `packages/zigeffect/src/workflow/context.zig`
  - Add clock/causal options, retry loop, schedule decision detail formatting,
    causal recording, exhausted handling, and timeout handling.
- Modify `packages/zigeffect/src/workflow/root.zig`
  - Expose any new context option aliases already available through
    `WorkflowContextOptions`.
- Modify `packages/zigeffect/test/workflow_test.zig`
  - Add event vocabulary, replay, retry success, retry exhaustion, timeout, and
    replay tests.
- Modify `packages/zigeffect/docs/architecture.md`
  - Document retry/timeout ownership in `workflow/context.zig`.
- Modify `docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md`
  - Mark Milestone 11 complete after the full gate.

## Task 1: Retry And Timeout Journal Vocabulary

**Files:**
- Modify `packages/zigeffect/src/workflow/journal.zig`
- Modify `packages/zigeffect/src/workflow/replay.zig`
- Modify `packages/zigeffect/test/workflow_test.zig`

- [x] **Step 1: Write failing event and replay tests**

Extend the event-name test:

```zig
.{ fx.workflow.WorkflowEventKind.activity_retry_scheduled, "activity_retry_scheduled" },
.{ fx.workflow.WorkflowEventKind.activity_timed_out, "activity_timed_out" },
```

Add replay assertions:

```zig
const retry_ready = [_]fx.workflow.WorkflowEvent{
    .{ .sequence = 1, .kind = .workflow_started, .workflow_id = 7, .execution_id = 8 },
    .{ .sequence = 2, .kind = .activity_scheduled, .workflow_id = 7, .execution_id = 8, .activity_id = 10, .attempt = 1 },
    .{ .sequence = 3, .kind = .activity_retry_scheduled, .workflow_id = 7, .execution_id = 8, .activity_id = 10, .attempt = 1, .status = "retry" },
};
var retry_state = try fx.workflow.WorkflowReplayState.fold(std.testing.allocator, &retry_ready);
defer retry_state.deinit();
try std.testing.expectEqual(fx.workflow.ActivityStatus.retry_ready, retry_state.activities.items[0].status);

const timeout = [_]fx.workflow.WorkflowEvent{
    .{ .sequence = 1, .kind = .workflow_started, .workflow_id = 7, .execution_id = 8 },
    .{ .sequence = 2, .kind = .activity_scheduled, .workflow_id = 7, .execution_id = 8, .activity_id = 10, .attempt = 1 },
    .{ .sequence = 3, .kind = .activity_timed_out, .workflow_id = 7, .execution_id = 8, .activity_id = 10, .attempt = 1, .status = "timeout" },
};
var timeout_state = try fx.workflow.WorkflowReplayState.fold(std.testing.allocator, &timeout);
defer timeout_state.deinit();
try std.testing.expectEqual(fx.workflow.ActivityStatus.failed, timeout_state.activities.items[0].status);
```

- [x] **Step 2: Verify red**

Run:

```bash
cd packages/zigeffect && zig build test-raw --summary all
```

Expected: FAIL until the new event kinds exist.

- [x] **Step 3: Implement event kinds and replay folding**

Add `activity_retry_scheduled` and `activity_timed_out` to
`WorkflowEventKind`, map them in `workflowEventKindName`, fold retry scheduled
events with `updateActivity(event, .retry_ready)`, and fold timed-out events
with `updateActivity(event, .failed)`.

- [x] **Step 4: Verify green**

Run:

```bash
bun run zigeffect:test
```

Expected: PASS.

## Task 2: Retry Success With Clock And Causal Mapping

**Files:**
- Modify `packages/zigeffect/src/workflow/context.zig`
- Modify `packages/zigeffect/test/workflow_test.zig`

- [x] **Step 1: Write failing retry success test**

Add a test with an activity definition that has
`withRetrySchedule(fx.Schedule.fixed(.{ .max_retries = 2, .delay_ms = 25 }).withLabel("charge-retry"))`.
Use `var clock = fx.FakeClock.fake(1_000)` and
`var causal = fx.CausalStore.init(std.testing.allocator)`, pass both through
`WorkflowContextOptions`, make the runner fail once and then return `104`, and
assert:

```zig
try std.testing.expectEqual(@as(u64, 104), value);
try std.testing.expectEqual(@as(u64, 2), Runner.calls);
try std.testing.expectEqual(@as(u64, 1_025), clock.nowMs());
try std.testing.expectEqual(fx.workflow.WorkflowEventKind.activity_retry_scheduled, events.events[3].kind);
try std.testing.expectEqual(@as(u32, 1), events.events[3].attempt);
try std.testing.expectEqualStrings("attempt=0 delay_ms=25 decision=retry", events.events[3].redacted_detail);
try std.testing.expectEqual(fx.workflow.WorkflowEventKind.activity_completed, events.events[6].kind);
try std.testing.expectEqual(@as(u32, 2), events.events[6].attempt);
```

Assert causal retry snapshot:

```zig
var retries = try causal.retries(std.testing.allocator, 1);
defer retries.deinit();
try std.testing.expectEqual(@as(usize, 1), retries.events.len);
try std.testing.expectEqual(fx.CausalEventKind.schedule_decision, retries.events[0].kind);
try std.testing.expectEqualStrings("charge-retry", retries.events[0].label);
try std.testing.expectEqualStrings("retry", retries.events[0].status);
```

- [x] **Step 2: Verify red**

Run:

```bash
cd packages/zigeffect && zig build test-raw --summary all
```

Expected: FAIL because activity retry loops, clock sleeping, and causal mapping
are absent.

- [x] **Step 3: Implement retry success path**

Add optional fields to `WorkflowContextOptions` and `WorkflowContext`:

```zig
clock: ?*Clock = null,
causal_store: ?*CausalStore = null,
causal_run_id: ?u64 = null,
```

Import `services/clock.zig`, `services/causal.zig`, and `effect/schedule.zig`.
Inside `WorkflowContext.activity`, run attempts in a loop. On failure, when
`ActivityType.retrySchedule()` returns a schedule and `schedule.decision(attempt - 1)`
continues, append `activity_retry_scheduled`, record a causal
`schedule_decision`, sleep the optional clock, increment the activity attempt,
and continue.

- [x] **Step 4: Verify green**

Run:

```bash
bun run zigeffect:test
```

Expected: PASS.

## Task 3: Retry Exhaustion Replay

**Files:**
- Modify `packages/zigeffect/src/workflow/context.zig`
- Modify `packages/zigeffect/test/workflow_test.zig`

- [x] **Step 1: Write failing exhaustion test**

Use a retry schedule with one retry and a runner that always returns
`error.Declined`. Assert first run and replay both return `error.Declined`,
runner calls remain `2`, the terminal event is `activity_failed` with status
`exhausted`, and the terminal detail is:

```text
attempt=1 delay_ms=null decision=exhausted;exit.cause.failure:Declined
```

Assert causal retries contain both a `retry` and an `exhausted` decision.

- [x] **Step 2: Verify red**

Run:

```bash
cd packages/zigeffect && zig build test-raw --summary all
```

Expected: FAIL until exhausted retry decisions are terminal and replayable.

- [x] **Step 3: Implement exhausted retry terminal behavior**

When a retry schedule returns `delay_ms = null`, format the exhausted detail,
append `activity_failed` with status `exhausted`, record causal
`schedule_decision` with status `exhausted`, and return the original typed
failure. Update recorded failure parsing to read the failure detail after the
semicolon.

- [x] **Step 4: Verify green**

Run:

```bash
bun run zigeffect:test
```

Expected: PASS.

## Task 4: Timeout Terminal Event And Replay

**Files:**
- Modify `packages/zigeffect/src/workflow/context.zig`
- Modify `packages/zigeffect/test/workflow_test.zig`

- [x] **Step 1: Write failing timeout test**

Define an activity with `.withTimeoutMs(0)` and failure type
`error{ActivityTimeout}`. Assert first run and replay both return
`error.ActivityTimeout`, runner calls remain `0`, and the terminal row is:

```zig
try std.testing.expectEqual(fx.workflow.WorkflowEventKind.activity_timed_out, events.events[2].kind);
try std.testing.expectEqualStrings("timeout", events.events[2].status);
try std.testing.expectEqualStrings("exit.cause.failure:ActivityTimeout", events.events[2].redacted_detail);
```

- [x] **Step 2: Verify red**

Run:

```bash
cd packages/zigeffect && zig build test-raw --summary all
```

Expected: FAIL until timeout metadata is enforced.

- [x] **Step 3: Implement timeout terminal behavior**

Before each attempt, if `ActivityType.metadata().timeout_ms` is `0`, append
`activity_scheduled`, append `activity_timed_out`, and return
`error.ActivityTimeout`. Update recorded activity replay to parse
`activity_timed_out` as a failed terminal outcome.

- [x] **Step 4: Verify green**

Run:

```bash
bun run zigeffect:test
```

Expected: PASS.

## Task 5: Docs, Roadmap, Full Gate, And Commit

**Files:**
- Modify `packages/zigeffect/docs/architecture.md`
- Modify `docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md`
- Add `docs/superpowers/specs/2026-06-09-zigeffect-activity-retry-timeout-design.md`
- Add `docs/superpowers/plans/2026-06-09-zigeffect-activity-retry-timeout.md`

- [x] **Step 1: Update architecture docs**

Update the `src/workflow/` section so `context.zig` mentions retry schedules,
clock-backed delays, timeout terminal events, and causal schedule decisions.

- [x] **Step 2: Run full gate**

Run:

```bash
bun run zigeffect:test
cd packages/zigeffect && zig build examples
bun run zig:test
git diff --check
rg -n 'T''BD|TO''DO|implement la''ter|fill in de''tails|appropriate error hand''ling|handle edge ca''ses|Similar to Ta''sk|deferred bu''cket|par''ked' packages/zigeffect/src/workflow packages/zigeffect/test/workflow_test.zig packages/zigeffect/docs/architecture.md docs/superpowers/specs/2026-06-09-zigeffect-activity-retry-timeout-design.md docs/superpowers/plans/2026-06-09-zigeffect-activity-retry-timeout.md
```

Expected: compile/test commands PASS, `git diff --check` exits 0, and the
placeholder scan exits 1 with no matches.

- [x] **Step 3: Mark Milestone 11 complete**

After the full gate passes, mark all Milestone 11 deliverables and acceptance
boxes complete in
`docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md`.

- [x] **Step 4: Commit**

```bash
git add packages/zigeffect/src/workflow/context.zig packages/zigeffect/src/workflow/journal.zig packages/zigeffect/src/workflow/replay.zig packages/zigeffect/test/workflow_test.zig packages/zigeffect/docs/architecture.md docs/superpowers/specs/2026-06-09-zigeffect-activity-retry-timeout-design.md docs/superpowers/plans/2026-06-09-zigeffect-activity-retry-timeout.md docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md
git commit -m "feat(zigeffect): add activity retry and timeout semantics"
```

## Self-Review Checklist

- [x] Retry decisions are durable journal rows.
- [x] Retry delays use optional `Clock`.
- [x] Retry decisions record existing causal `schedule_decision` events.
- [x] Exhausted retries replay typed failures without rerunning activities.
- [x] Timeout rows replay `error.ActivityTimeout` without rerunning activities.
- [x] No worker polling, durable timer wakeups, compensation, or clustering is added in this milestone.
