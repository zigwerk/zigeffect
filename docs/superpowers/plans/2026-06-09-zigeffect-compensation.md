# zigeffect Compensation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add durable compensation registration, reverse-order execution, idempotent completion replay, and typed failure journaling.

**Architecture:** Extend the journal and replay model with first-class compensation ids before adding context behavior. `WorkflowContext` owns registration and execution, while `WorkflowReplayState` and checkpoint JSON preserve compensation status for inspection and recovery.

**Tech Stack:** Zig 0.16, existing workflow journal/replay/store/context modules, existing `Exit`/`Cause` detail formatting, Bun project scripts.

---

## File Structure

- Modify `packages/zigeffect/src/workflow/journal.zig`
  - Add `CompensationId`, event field, event kinds, JSON parsing/formatting, and text formatting.
- Modify `packages/zigeffect/src/workflow/replay.zig`
  - Add compensation status/state and fold compensation lifecycle events.
- Modify `packages/zigeffect/src/workflow/store.zig`
  - Include compensation state in checkpoint JSON formatting and parsing.
- Modify `packages/zigeffect/src/workflow/context.zig`
  - Add `registerCompensation`, `runCompensations`, reverse-order selection, handler lookup, and failure journaling.
- Modify `packages/zigeffect/src/workflow/root.zig`
  - Expose `CompensationId`, `CompensationStatus`, `CompensationState`, and `compensationId`.
- Modify `packages/zigeffect/test/workflow_test.zig`
  - Add event, replay, checkpoint, execution order, idempotent replay, and failure tests.
- Modify `packages/zigeffect/docs/architecture.md`
  - Document compensation ownership in `workflow/context.zig`.
- Modify `docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md`
  - Mark Milestone 12 complete after the full gate.

## Task 1: Compensation Journal Events

**Files:**
- Modify `packages/zigeffect/src/workflow/journal.zig`
- Modify `packages/zigeffect/src/workflow/root.zig`
- Modify `packages/zigeffect/test/workflow_test.zig`

- [ ] **Step 1: Write failing event field and name tests**

Extend the event-name test with:

```zig
.{ fx.workflow.WorkflowEventKind.compensation_registered, "compensation_registered" },
.{ fx.workflow.WorkflowEventKind.compensation_started, "compensation_started" },
.{ fx.workflow.WorkflowEventKind.compensation_completed, "compensation_completed" },
.{ fx.workflow.WorkflowEventKind.compensation_failed, "compensation_failed" },
```

Add `compensation_id = 50` to an existing JSON round-trip event and assert:

```zig
try std.testing.expect(std.mem.indexOf(u8, json, "\"compensation_id\":50") != null);
try std.testing.expectEqual(event.compensation_id, parsed.compensation_id);
try std.testing.expect(std.mem.indexOf(u8, text, "compensation_id: 50") != null);
```

Add a stable id assertion:

```zig
try std.testing.expectEqual(fx.workflow.compensationId("refund-charge"), fx.workflow.compensationId("refund-charge"));
try std.testing.expect(fx.workflow.compensationId("refund-charge") != fx.workflow.compensationId("release-seat"));
```

- [ ] **Step 2: Verify red**

Run:

```bash
cd packages/zigeffect && zig build test-raw --summary all
```

Expected: FAIL until compensation ids and event kinds exist.

- [ ] **Step 3: Implement journal compensation fields**

Add `pub const CompensationId = u64`, add
`compensation_id: ?CompensationId = null` to `WorkflowEvent` and JSON rows,
parse/format it in JSON and text, add compensation event kinds and name
mappings, and expose `CompensationId` plus `compensationId(label)` from the
workflow root.

- [ ] **Step 4: Verify green**

Run:

```bash
bun run zigeffect:test
```

Expected: PASS.

## Task 2: Compensation Replay And Checkpoints

**Files:**
- Modify `packages/zigeffect/src/workflow/replay.zig`
- Modify `packages/zigeffect/src/workflow/store.zig`
- Modify `packages/zigeffect/src/workflow/root.zig`
- Modify `packages/zigeffect/test/workflow_test.zig`

- [ ] **Step 1: Write failing replay/checkpoint tests**

Add a replay test:

```zig
const events = [_]fx.workflow.WorkflowEvent{
    .{ .sequence = 1, .kind = .workflow_started, .workflow_id = 7, .execution_id = 8 },
    .{ .sequence = 2, .kind = .compensation_registered, .workflow_id = 7, .execution_id = 8, .compensation_id = 50, .name = "refund-charge" },
    .{ .sequence = 3, .kind = .compensation_started, .workflow_id = 7, .execution_id = 8, .compensation_id = 50 },
    .{ .sequence = 4, .kind = .compensation_completed, .workflow_id = 7, .execution_id = 8, .compensation_id = 50 },
};
var state = try fx.workflow.WorkflowReplayState.fold(std.testing.allocator, &events);
defer state.deinit();
try std.testing.expectEqual(@as(usize, 1), state.compensations.items.len);
try std.testing.expectEqual(fx.workflow.CompensationStatus.completed, state.compensations.items[0].status);
try std.testing.expectEqualStrings("refund-charge", state.compensations.items[0].name);
```

Extend checkpoint tests to assert `"compensations"` and `"compensation_id":50`
round-trip, and extend `expectWorkflowReplayStatesEqual` to compare
compensations.

- [ ] **Step 2: Verify red**

Run:

```bash
cd packages/zigeffect && zig build test-raw --summary all
```

Expected: FAIL until compensation replay state exists.

- [ ] **Step 3: Implement replay and checkpoint state**

Add `CompensationStatus`, `CompensationState`, `compensations` storage, apply
handlers for registered/started/completed/failed, duplicate/unknown replay
errors, checkpoint JSON rows, parser support, deinit cleanup, and root exports.

- [ ] **Step 4: Verify green**

Run:

```bash
bun run zigeffect:test
```

Expected: PASS.

## Task 3: Register And Run Compensations

**Files:**
- Modify `packages/zigeffect/src/workflow/context.zig`
- Modify `packages/zigeffect/test/workflow_test.zig`

- [ ] **Step 1: Write failing reverse-order execution test**

Register `release-seat`, then `refund-charge`, then call
`runCompensations` with handlers for both labels. Assert the execution log is
`refund-charge, release-seat`, and the journal has registered, started, and
completed rows for both labels.

- [ ] **Step 2: Verify red**

Run:

```bash
cd packages/zigeffect && zig build test-raw --summary all
```

Expected: FAIL because context compensation APIs do not exist.

- [ ] **Step 3: Implement registration and reverse-order execution**

Add `WorkflowContext.registerCompensation(label)` and
`WorkflowContext.runCompensations(handlers)`. Registration appends
`compensation_registered`. Execution scans replay plus current journal rows,
runs registered labels in reverse order, matches handlers by `.label`, appends
started/completed rows, and skips labels with completed rows.

- [ ] **Step 4: Verify green**

Run:

```bash
bun run zigeffect:test
```

Expected: PASS.

## Task 4: Idempotent Replay And Failure Cause Detail

**Files:**
- Modify `packages/zigeffect/src/workflow/context.zig`
- Modify `packages/zigeffect/test/workflow_test.zig`

- [ ] **Step 1: Write failing idempotency and failure tests**

Add a replay test where a completed compensation is present before
`runCompensations`; assert its handler is not called again.

Add a failure test where a handler returns `error.RefundFailed`; assert
`runCompensations` returns `error.RefundFailed`, the journal row is
`compensation_failed`, and detail is:

```text
exit.cause.failure:RefundFailed
```

- [ ] **Step 2: Verify red**

Run:

```bash
cd packages/zigeffect && zig build test-raw --summary all
```

Expected: FAIL until completed rows are skipped and failure rows use
`Exit`/`Cause` detail.

- [ ] **Step 3: Implement idempotent completion and failed compensation rows**

Have `runCompensations` skip labels with completed rows, append
`compensation_failed` with `workflowFailureDetail` before returning a handler
error, and leave completed compensation rows unchanged on replay.

- [ ] **Step 4: Verify green**

Run:

```bash
bun run zigeffect:test
```

Expected: PASS.

## Task 5: Docs, Roadmap, Full Gate, And Commit

**Files:**
- Modify `packages/zigeffect/docs/architecture.md`
- Modify `docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md`
- Add `docs/superpowers/specs/2026-06-09-zigeffect-compensation-design.md`
- Add `docs/superpowers/plans/2026-06-09-zigeffect-compensation.md`

- [ ] **Step 1: Update architecture docs**

Update the `src/workflow/` section so `context.zig` mentions compensation
registration, reverse-order execution, idempotent completion replay, and
failure cause details.

- [ ] **Step 2: Run full gate**

Run:

```bash
bun run zigeffect:test
cd packages/zigeffect && zig build examples
bun run zig:test
git diff --check
rg -n 'T''BD|TO''DO|implement la''ter|fill in de''tails|appropriate error hand''ling|handle edge ca''ses|Similar to Ta''sk|deferred bu''cket|par''ked' packages/zigeffect/src/workflow packages/zigeffect/test/workflow_test.zig packages/zigeffect/docs/architecture.md docs/superpowers/specs/2026-06-09-zigeffect-compensation-design.md docs/superpowers/plans/2026-06-09-zigeffect-compensation.md
```

Expected: compile/test commands PASS, `git diff --check` exits 0, and the
placeholder scan exits 1 with no matches.

- [ ] **Step 3: Mark Milestone 12 complete**

After the full gate passes, mark all Milestone 12 deliverables and acceptance
boxes complete in
`docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md`.

- [ ] **Step 4: Commit**

```bash
git add packages/zigeffect/src/workflow/context.zig packages/zigeffect/src/workflow/journal.zig packages/zigeffect/src/workflow/replay.zig packages/zigeffect/src/workflow/root.zig packages/zigeffect/src/workflow/store.zig packages/zigeffect/test/workflow_test.zig packages/zigeffect/docs/architecture.md docs/superpowers/specs/2026-06-09-zigeffect-compensation-design.md docs/superpowers/plans/2026-06-09-zigeffect-compensation.md docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md
git commit -m "feat(zigeffect): add durable compensation"
```

## Self-Review Checklist

- [ ] Compensation ids are first-class journal fields.
- [ ] Replay and checkpoint state preserve compensation rows.
- [ ] Execution order is reverse registration order.
- [ ] Completed compensations are not rerun.
- [ ] Failed compensations use `Exit` and `Cause` detail.
- [ ] No automatic engine hook, retry schedule, worker, or cluster behavior is added in this milestone.
