# zigeffect Activity Definition API Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add typed activity definitions without execution.

**Architecture:** Add `workflow/activity.zig` for activity metadata, idempotency key callbacks, retry schedule attachment, timeout metadata, compensation metadata, formatting, and service requirements. Keep execution, journal writes, and payload codecs out of this milestone.

**Tech Stack:** Zig 0.16, existing dependency `ServiceSet`, existing `Schedule`, existing compile-fail fixture pattern.

---

## File Structure

- Create `packages/zigeffect/src/workflow/activity.zig`
  - Owns `Activity`, `ActivityMetadata`, callback validation, requirements,
    retry/timeout/compensation metadata, and formatting.
- Modify `packages/zigeffect/src/workflow/root.zig`
  - Exposes activity names.
- Modify `packages/zigeffect/test/workflow_test.zig`
  - Adds valid activity definition tests.
- Add `packages/zigeffect/test/compile_fail/invalid_activity_idempotency_key.zig`
  - Compile-fail fixture for invalid callback shape.
- Modify `packages/zigeffect/test/layer_test.zig`
  - Adds compile-fail diagnostic assertion.
- Modify `packages/zigeffect/test/architecture_test.zig`
  - Verifies activity module exposure.
- Modify `packages/zigeffect/docs/architecture.md`
  - Documents `workflow/activity.zig`.
- Modify `docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md`
  - Marks Milestone 7 complete after verification.

## Task 1: Valid Activity Definition Surface

**Files:**
- Modify `packages/zigeffect/test/workflow_test.zig`
- Modify `packages/zigeffect/test/architecture_test.zig`

- [ ] **Step 1: Write failing valid activity tests**

Add tests for `Activity`, `.withIdempotencyKey`, `.withRetrySchedule`,
`.withTimeoutMs`, `.withCompensation`, `.requires`, `metadata`,
`requiredServices`, `idempotencyKey`, `retrySchedule`, and `format`.

- [ ] **Step 2: Verify red**

Run:

```bash
bun run zigeffect:test
```

Expected: FAIL until `workflow/activity.zig` exists.

- [ ] **Step 3: Implement activity module**

Add `ActivityMetadata`, `Activity`, callback validation,
`idempotencyKey`, `retrySchedule`, `.requires`, `.withRetrySchedule`,
`.withTimeoutMs`, `.withCompensation`, `requiredServices`, and `format`.

- [ ] **Step 4: Verify green**

Run:

```bash
bun run zigeffect:test
```

Expected: PASS.

## Task 2: Compile Diagnostics

**Files:**
- Add `packages/zigeffect/test/compile_fail/invalid_activity_idempotency_key.zig`
- Modify `packages/zigeffect/test/layer_test.zig`

- [ ] **Step 1: Write failing compile-fail fixture**

Add a fixture using an idempotency callback with the wrong shape, then assert
the compile output contains:

```text
zigeffect invalid activity idempotency key callback
```

- [ ] **Step 2: Verify red**

Run:

```bash
bun run zigeffect:test
```

Expected: FAIL until callback validation emits the diagnostic.

- [ ] **Step 3: Implement diagnostics**

Use `@typeInfo` validation and `@compileError` messages for invalid callback
shape.

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
- Add `docs/superpowers/specs/2026-06-09-zigeffect-activity-definition-api-design.md`
- Add `docs/superpowers/plans/2026-06-09-zigeffect-activity-definition-api.md`

- [ ] **Step 1: Update architecture docs**

Document `activity.zig` under `src/workflow/`.

- [ ] **Step 2: Mark Milestone 7 complete**

Mark all Milestone 7 deliverables and acceptance boxes in the roadmap after
the full gate passes.

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
git add packages/zigeffect/src/workflow/activity.zig packages/zigeffect/src/workflow/root.zig packages/zigeffect/test/workflow_test.zig packages/zigeffect/test/architecture_test.zig packages/zigeffect/test/layer_test.zig packages/zigeffect/test/compile_fail/invalid_activity_idempotency_key.zig packages/zigeffect/docs/architecture.md docs/superpowers/specs/2026-06-09-zigeffect-activity-definition-api-design.md docs/superpowers/plans/2026-06-09-zigeffect-activity-definition-api.md docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md
git commit -m "feat(zigeffect): add activity definition API"
```

## Self-Review Checklist

- [ ] Definitions are type-level and do not execute activity functions.
- [ ] Idempotency keys are caller-owned and deinitialized by tests.
- [ ] Retry schedule, timeout, and compensation are metadata only.
- [ ] Requirement declarations use existing service tuple validation.
- [ ] `format` emits an inspectable summary without allocating hidden state.
- [ ] Compile-fail diagnostic covers invalid callback shape.
- [ ] No activity runner, workflow engine, journal write, or payload codec is added.
- [ ] Full verification passes before Milestone 7 is marked complete.
