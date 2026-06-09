# zigeffect Workflow Replay State Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add deterministic folding from workflow journal events into in-memory replay state.

**Architecture:** Implement `workflow/replay.zig` as an allocator-owned state machine over `WorkflowEvent` slices. Keep lookup linear and explicit for the first version; storage, parsing, snapshots, and workflow execution come later.

**Tech Stack:** Zig 0.16, `std.ArrayList`, existing `workflow/journal.zig`, `bun run zigeffect:test`.

---

## File Structure

- Create `packages/zigeffect/src/workflow/replay.zig`
  - Owns statuses, state rows, replay errors, `WorkflowReplayState`, and fold
    logic.
- Modify `packages/zigeffect/src/workflow/root.zig`
  - Exposes replay names.
- Modify `packages/zigeffect/test/workflow_test.zig`
  - Adds replay-state tests.
- Modify `packages/zigeffect/test/architecture_test.zig`
  - Verifies replay module exposure.
- Modify `packages/zigeffect/docs/architecture.md`
  - Documents `workflow/replay.zig`.
- Modify `docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md`
  - Marks Milestone 3 complete after verification.

## Task 1: Workflow Lifecycle Fold

**Files:**
- Modify: `packages/zigeffect/test/workflow_test.zig`
- Modify: `packages/zigeffect/test/architecture_test.zig`
- Create: `packages/zigeffect/src/workflow/replay.zig`
- Modify: `packages/zigeffect/src/workflow/root.zig`

- [ ] **Step 1: Write failing lifecycle tests**

Add tests:

```zig
test "workflow replay folds lifecycle events" {
    const events = [_]fx.workflow.WorkflowEvent{
        .{ .sequence = 1, .kind = .workflow_started, .workflow_id = 7, .execution_id = 8, .name = "approval" },
        .{ .sequence = 2, .kind = .workflow_suspended, .workflow_id = 7, .execution_id = 8, .status = "waiting" },
        .{ .sequence = 3, .kind = .workflow_resumed, .workflow_id = 7, .execution_id = 8 },
        .{ .sequence = 4, .kind = .workflow_completed, .workflow_id = 7, .execution_id = 8, .status = "success" },
    };

    var state = try fx.workflow.WorkflowReplayState.fold(std.testing.allocator, &events);
    defer state.deinit();

    try std.testing.expectEqual(fx.workflow.WorkflowStatus.completed, state.workflow_status);
    try std.testing.expectEqual(@as(?u64, 7), state.workflow_id);
    try std.testing.expectEqual(@as(?u64, 8), state.execution_id);
    try std.testing.expectEqual(@as(u64, 4), state.last_sequence);
}

test "workflow replay rejects events before start and duplicate starts" {
    const before_start = [_]fx.workflow.WorkflowEvent{
        .{ .sequence = 1, .kind = .workflow_completed, .workflow_id = 7, .execution_id = 8 },
    };
    try std.testing.expectError(error.WorkflowNotStarted, fx.workflow.WorkflowReplayState.fold(std.testing.allocator, &before_start));

    const duplicate_start = [_]fx.workflow.WorkflowEvent{
        .{ .sequence = 1, .kind = .workflow_started, .workflow_id = 7, .execution_id = 8 },
        .{ .sequence = 2, .kind = .workflow_started, .workflow_id = 7, .execution_id = 8 },
    };
    try std.testing.expectError(error.WorkflowAlreadyStarted, fx.workflow.WorkflowReplayState.fold(std.testing.allocator, &duplicate_start));
}
```

Add architecture assertion:

```zig
try std.testing.expect(@hasDecl(fx.workflow, "replay"));
try std.testing.expect(fx.workflow.WorkflowReplayState == fx.workflow.replay.WorkflowReplayState);
```

- [ ] **Step 2: Verify red**

Run:

```bash
bun run zigeffect:test
```

Expected: FAIL because replay state is missing.

- [ ] **Step 3: Implement lifecycle replay**

Create status enums, `ReplayError`, `WorkflowReplayState.init`, `deinit`,
`apply`, `fold`, and lifecycle handling. Expose through `workflow/root.zig`.

- [ ] **Step 4: Verify green**

Run:

```bash
bun run zigeffect:test
```

Expected: PASS.

## Task 2: Activity, Timer, Deferred, And Queue Rows

**Files:**
- Modify: `packages/zigeffect/test/workflow_test.zig`
- Modify: `packages/zigeffect/src/workflow/replay.zig`

- [ ] **Step 1: Write failing resource fold tests**

Add tests that fold one activity, timer, deferred, and queue:

```zig
test "workflow replay folds activity timer deferred and queue rows" {
    const events = [_]fx.workflow.WorkflowEvent{
        .{ .sequence = 1, .kind = .workflow_started, .workflow_id = 7, .execution_id = 8 },
        .{ .sequence = 2, .kind = .activity_scheduled, .workflow_id = 7, .execution_id = 8, .activity_id = 10, .name = "charge" },
        .{ .sequence = 3, .kind = .activity_started, .workflow_id = 7, .execution_id = 8, .activity_id = 10 },
        .{ .sequence = 4, .kind = .activity_completed, .workflow_id = 7, .execution_id = 8, .activity_id = 10 },
        .{ .sequence = 5, .kind = .timer_scheduled, .workflow_id = 7, .execution_id = 8, .timer_id = 20 },
        .{ .sequence = 6, .kind = .timer_fired, .workflow_id = 7, .execution_id = 8, .timer_id = 20 },
        .{ .sequence = 7, .kind = .deferred_created, .workflow_id = 7, .execution_id = 8, .deferred_id = 30 },
        .{ .sequence = 8, .kind = .deferred_completed, .workflow_id = 7, .execution_id = 8, .deferred_id = 30 },
        .{ .sequence = 9, .kind = .queue_offered, .workflow_id = 7, .execution_id = 8, .queue_id = 40 },
        .{ .sequence = 10, .kind = .queue_claimed, .workflow_id = 7, .execution_id = 8, .queue_id = 40 },
        .{ .sequence = 11, .kind = .queue_acked, .workflow_id = 7, .execution_id = 8, .queue_id = 40 },
    };

    var state = try fx.workflow.WorkflowReplayState.fold(std.testing.allocator, &events);
    defer state.deinit();

    try std.testing.expectEqual(fx.workflow.ActivityStatus.completed, state.activities.items[0].status);
    try std.testing.expectEqual(fx.workflow.TimerStatus.fired, state.timers.items[0].status);
    try std.testing.expectEqual(fx.workflow.DeferredStatus.completed, state.deferreds.items[0].status);
    try std.testing.expectEqual(fx.workflow.QueueStatus.acked, state.queues.items[0].status);
}

test "workflow replay rejects unknown activity update" {
    const events = [_]fx.workflow.WorkflowEvent{
        .{ .sequence = 1, .kind = .workflow_started, .workflow_id = 7, .execution_id = 8 },
        .{ .sequence = 2, .kind = .activity_completed, .workflow_id = 7, .execution_id = 8, .activity_id = 10 },
    };

    try std.testing.expectError(error.UnknownActivity, fx.workflow.WorkflowReplayState.fold(std.testing.allocator, &events));
}
```

- [ ] **Step 2: Verify red**

Run:

```bash
bun run zigeffect:test
```

Expected: FAIL until row folding exists.

- [ ] **Step 3: Implement row folding**

Add state row structs and event handlers for activity, timer, deferred, and
queue events. Missing ids return `MissingTargetId`; duplicate create/schedule
events return duplicate errors; unknown updates return unknown errors.

- [ ] **Step 4: Verify full gate**

Run:

```bash
bun run zigeffect:test
cd packages/zigeffect && zig build examples
bun run zig:test
```

Expected: all commands PASS.

## Task 3: Docs, Roadmap, And Commit

**Files:**
- Modify: `packages/zigeffect/docs/architecture.md`
- Modify: `docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md`
- Add: `docs/superpowers/specs/2026-06-09-zigeffect-workflow-replay-state-design.md`
- Add: `docs/superpowers/plans/2026-06-09-zigeffect-workflow-replay-state.md`

- [ ] **Step 1: Update architecture docs**

Add `replay.zig` to the `src/workflow/` section as the owner of replay status,
state rows, malformed history errors, and fold logic.

- [ ] **Step 2: Mark Milestone 3 complete**

Mark all Milestone 3 deliverables and acceptance boxes in the durable workflows
and clustering roadmap after verification.

- [ ] **Step 3: Run diff checks**

Run:

```bash
git diff --check
```

Expected: PASS with no output.

- [ ] **Step 4: Commit**

```bash
git add packages/zigeffect/src/workflow/replay.zig packages/zigeffect/src/workflow/root.zig packages/zigeffect/test/workflow_test.zig packages/zigeffect/test/architecture_test.zig packages/zigeffect/docs/architecture.md docs/superpowers/specs/2026-06-09-zigeffect-workflow-replay-state-design.md docs/superpowers/plans/2026-06-09-zigeffect-workflow-replay-state.md docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md
git commit -m "feat(zigeffect): add workflow replay state fold"
```

## Self-Review Checklist

- [ ] Fold rejects malformed histories named in the spec.
- [ ] No journal store, parser, workflow engine, activity runner, or schedule math is added.
- [ ] Full verification passes before Milestone 3 is marked complete.
