# zigeffect Deterministic Workflow Step Runner Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add replay-aware pure workflow steps without activity execution.

**Architecture:** Extend workflow journal event kinds with step events, then add `workflow/context.zig` as the owner of `WorkflowContext` and `stepU64`. Keep generic codecs, engine integration, activities, timers, and completion out of this milestone.

**Tech Stack:** Zig 0.16, existing `JournalStore`, existing workflow journal parser/formatter, `std.fmt`.

---

## File Structure

- Modify `packages/zigeffect/src/workflow/journal.zig`
  - Adds step event kinds.
- Create `packages/zigeffect/src/workflow/context.zig`
  - Owns `WorkflowContext`, options, and `stepU64`.
- Modify `packages/zigeffect/src/workflow/root.zig`
  - Exposes context names.
- Modify `packages/zigeffect/test/workflow_test.zig`
  - Adds step replay tests.
- Modify `packages/zigeffect/test/architecture_test.zig`
  - Verifies context module exposure.
- Modify `packages/zigeffect/docs/architecture.md`
  - Documents `workflow/context.zig`.
- Modify `docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md`
  - Marks Milestone 9 complete after verification.

## Task 1: Step Event Vocabulary

**Files:**
- Modify `packages/zigeffect/src/workflow/journal.zig`
- Modify `packages/zigeffect/test/workflow_test.zig`

- [x] **Step 1: Write failing step event name tests**

Assert `step_started`, `step_completed`, and `step_failed` have stable names.

- [x] **Step 2: Verify red**

Run:

```bash
bun run zigeffect:test
```

Expected: FAIL until event kinds exist.

- [x] **Step 3: Implement event kinds**

Add the three event kinds and name mappings.

- [x] **Step 4: Verify green**

Run:

```bash
bun run zigeffect:test
```

Expected: PASS.

## Task 2: Replay-Aware Step Runner

**Files:**
- Create `packages/zigeffect/src/workflow/context.zig`
- Modify `packages/zigeffect/src/workflow/root.zig`
- Modify `packages/zigeffect/test/workflow_test.zig`
- Modify `packages/zigeffect/test/architecture_test.zig`

- [x] **Step 1: Write failing step replay tests**

Add tests proving first run records `step_started` and `step_completed`, replay
returns the recorded value without calling the function again, and failed steps
append `step_failed`.

- [x] **Step 2: Verify red**

Run:

```bash
bun run zigeffect:test
```

Expected: FAIL until `WorkflowContext` exists.

- [x] **Step 3: Implement context and stepU64**

Initialize replay history from the journal, compute next sequence, find
recorded step completions by label, append step events, parse u64 results, and
record typed error names through `Exit.cause.failure` details on failure.

- [x] **Step 4: Verify green**

Run:

```bash
bun run zigeffect:test
```

Expected: PASS.

## Task 3: Docs, Roadmap, And Commit

**Files:**
- Modify `packages/zigeffect/docs/architecture.md`
- Modify `docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md`
- Add `docs/superpowers/specs/2026-06-09-zigeffect-deterministic-workflow-step-runner-design.md`
- Add `docs/superpowers/plans/2026-06-09-zigeffect-deterministic-workflow-step-runner.md`

- [x] **Step 1: Update architecture docs**

Document `context.zig` under `src/workflow/`.

- [x] **Step 2: Mark Milestone 9 complete**

Mark all Milestone 9 deliverables and acceptance boxes after the full gate.

- [x] **Step 3: Run full gate**

Run:

```bash
bun run zigeffect:test
cd packages/zigeffect && zig build examples
bun run zig:test
git diff --check
```

Expected: all commands PASS.

- [x] **Step 4: Commit**

```bash
git add packages/zigeffect/src/workflow/context.zig packages/zigeffect/src/workflow/journal.zig packages/zigeffect/src/workflow/root.zig packages/zigeffect/test/workflow_test.zig packages/zigeffect/test/architecture_test.zig packages/zigeffect/docs/architecture.md docs/superpowers/specs/2026-06-09-zigeffect-deterministic-workflow-step-runner-design.md docs/superpowers/plans/2026-06-09-zigeffect-deterministic-workflow-step-runner.md docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md
git commit -m "feat(zigeffect): add deterministic workflow step runner"
```

## Self-Review Checklist

- [x] Replay returns recorded values without re-running step functions.
- [x] Step events use deterministic sequence assignment.
- [x] Failed steps record typed error names through `Exit` and `Cause`.
- [x] No activity execution, generic codecs, engine integration, timers, or queues are added.
- [x] Full verification passes before Milestone 9 is marked complete.
