# zigeffect WorkflowEngine Core Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the first workflow engine core without workflow body execution.

**Architecture:** Add `workflow/engine.zig` as a thin durable start/orchestration layer over workflow definitions and `JournalStore`. Keep execution body semantics, steps, activity calls, completion, recovery, and clustering out of this milestone.

**Tech Stack:** Zig 0.16, existing `Workflow` definitions, `JournalStore`, `ServiceSet`, `std.hash.Fnv1a_64`.

---

## File Structure

- Create `packages/zigeffect/src/workflow/engine.zig`
  - Owns engine types and APIs.
- Modify `packages/zigeffect/src/workflow/root.zig`
  - Exposes engine names.
- Modify `packages/zigeffect/test/workflow_test.zig`
  - Adds engine tests.
- Modify `packages/zigeffect/test/architecture_test.zig`
  - Verifies engine module exposure.
- Modify `packages/zigeffect/docs/architecture.md`
  - Documents `workflow/engine.zig`.
- Modify `docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md`
  - Marks Milestone 8 complete after verification.

## Task 1: Engine Start And Poll

**Files:**
- Modify `packages/zigeffect/test/workflow_test.zig`
- Modify `packages/zigeffect/test/architecture_test.zig`
- Create `packages/zigeffect/src/workflow/engine.zig`
- Modify `packages/zigeffect/src/workflow/root.zig`

- [ ] **Step 1: Write failing engine tests**

Add tests proving:

- `WorkflowEngine.initWithProviders` registers a workflow whose requirements
  are satisfied;
- `execute` starts a no-op workflow and appends `workflow_started`;
- `poll` returns typed `WorkflowResult(...).running`;
- `inspect` returns execution metadata;
- `list` returns the started execution.

- [ ] **Step 2: Verify red**

Run:

```bash
bun run zigeffect:test
```

Expected: FAIL until engine APIs exist.

- [ ] **Step 3: Implement engine core**

Add engine types, registration, provider validation, execution start, journal
sequence calculation, workflow id hashing, poll, inspect, list, and deinit.

- [ ] **Step 4: Verify green**

Run:

```bash
bun run zigeffect:test
```

Expected: PASS.

## Task 2: Duplicate And Dependency Behavior

**Files:**
- Modify `packages/zigeffect/test/workflow_test.zig`
- Modify `packages/zigeffect/src/workflow/engine.zig`

- [ ] **Step 1: Write failing duplicate/dependency tests**

Add tests proving duplicate execution ids return
`DuplicateWorkflowExecution` and missing provider requirements return
`MissingServiceRequirement`.

- [ ] **Step 2: Verify red**

Run:

```bash
bun run zigeffect:test
```

Expected: FAIL until explicit errors exist.

- [ ] **Step 3: Implement explicit errors**

Ensure duplicate checks happen before journal append and registration validates
requirements against provider services.

- [ ] **Step 4: Verify green**

Run:

```bash
bun run zigeffect:test
```

Expected: PASS.

## Task 3: Docs, Roadmap, And Commit

**Files:**
- Modify `packages/zigeffect/docs/architecture.md`
- Modify `docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md`
- Add `docs/superpowers/specs/2026-06-09-zigeffect-workflow-engine-core-design.md`
- Add `docs/superpowers/plans/2026-06-09-zigeffect-workflow-engine-core.md`

- [ ] **Step 1: Update architecture docs**

Document `engine.zig` under `src/workflow/`.

- [ ] **Step 2: Mark Milestone 8 complete**

Mark all Milestone 8 deliverables and acceptance boxes after the full gate
passes.

- [ ] **Step 3: Run full gate**

Run:

```bash
bun run zigeffect:test
cd packages/zigeffect && zig build examples
bun run zig:test
git diff --check
```

Expected: all commands PASS.

- [ ] **Step 4: Commit**

```bash
git add packages/zigeffect/src/workflow/engine.zig packages/zigeffect/src/workflow/root.zig packages/zigeffect/test/workflow_test.zig packages/zigeffect/test/architecture_test.zig packages/zigeffect/docs/architecture.md docs/superpowers/specs/2026-06-09-zigeffect-workflow-engine-core-design.md docs/superpowers/plans/2026-06-09-zigeffect-workflow-engine-core.md docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md
git commit -m "feat(zigeffect): add workflow engine core"
```

## Self-Review Checklist

- [ ] Engine does not execute workflow bodies.
- [ ] `workflow_started` is appended before an execution is recorded.
- [ ] Duplicate execution ids are rejected before append.
- [ ] Registration checks provider requirements.
- [ ] `WorkflowResult` is typed by workflow success/failure.
- [ ] No step runner, activity runner, completion, recovery, or clustering is added.
- [ ] Full verification passes before Milestone 8 is marked complete.
