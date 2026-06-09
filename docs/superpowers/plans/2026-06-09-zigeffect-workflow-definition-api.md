# zigeffect Workflow Definition API Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add typed workflow definitions without execution.

**Architecture:** Add `workflow/definition.zig` for compile-time workflow metadata, idempotency key callbacks, deterministic execution id derivation, and service requirements. Keep execution, registration, payload codecs, and journal writes out of this milestone.

**Tech Stack:** Zig 0.16, existing dependency `ServiceSet`, `std.hash.Fnv1a_64`, existing compile-fail fixture pattern.

---

## File Structure

- Create `packages/zigeffect/src/workflow/definition.zig`
  - Owns `Workflow`, `WorkflowMetadata`, callback validation, requirements,
    and execution id derivation.
- Modify `packages/zigeffect/src/workflow/root.zig`
  - Exposes definition names.
- Modify `packages/zigeffect/test/workflow_test.zig`
  - Adds valid workflow definition tests.
- Add `packages/zigeffect/test/compile_fail/invalid_workflow_idempotency_key.zig`
  - Compile-fail fixture for invalid callback shape.
- Modify `packages/zigeffect/test/layer_test.zig`
  - Adds compile-fail diagnostic assertion.
- Modify `packages/zigeffect/test/architecture_test.zig`
  - Verifies definition module exposure.
- Modify `packages/zigeffect/docs/architecture.md`
  - Documents `workflow/definition.zig`.
- Modify `docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md`
  - Marks Milestone 6 complete after verification.

## Task 1: Valid Definition Surface

**Files:**
- Modify `packages/zigeffect/test/workflow_test.zig`
- Modify `packages/zigeffect/test/architecture_test.zig`

- [ ] **Step 1: Write failing valid-definition tests**

Add tests for `Workflow`, `.withIdempotencyKey`, `.requires`, metadata,
required service set output, idempotency key output, and stable execution id.

- [ ] **Step 2: Verify red**

Run:

```bash
bun run zigeffect:test
```

Expected: FAIL until `workflow/definition.zig` exists.

- [ ] **Step 3: Implement definition module**

Add `WorkflowMetadata`, `Workflow`, callback validation, `idempotencyKey`,
`deriveExecutionId`, `.requires`, `.withIdempotencyKey`, and
`requiredServices`.

- [ ] **Step 4: Verify green**

Run:

```bash
bun run zigeffect:test
```

Expected: PASS.

## Task 2: Compile Diagnostics

**Files:**
- Add `packages/zigeffect/test/compile_fail/invalid_workflow_idempotency_key.zig`
- Modify `packages/zigeffect/test/layer_test.zig`

- [ ] **Step 1: Write failing compile-fail fixture**

Add a fixture using an idempotency callback with the wrong parameter or return
shape, then assert the compile output contains:

```text
zigeffect invalid workflow idempotency key callback
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
- Add `docs/superpowers/specs/2026-06-09-zigeffect-workflow-definition-api-design.md`
- Add `docs/superpowers/plans/2026-06-09-zigeffect-workflow-definition-api.md`

- [ ] **Step 1: Update architecture docs**

Document `definition.zig` under `src/workflow/`.

- [ ] **Step 2: Mark Milestone 6 complete**

Mark all Milestone 6 deliverables and acceptance boxes in the roadmap after
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
git add packages/zigeffect/src/workflow/definition.zig packages/zigeffect/src/workflow/root.zig packages/zigeffect/test/workflow_test.zig packages/zigeffect/test/architecture_test.zig packages/zigeffect/test/layer_test.zig packages/zigeffect/test/compile_fail/invalid_workflow_idempotency_key.zig packages/zigeffect/docs/architecture.md docs/superpowers/specs/2026-06-09-zigeffect-workflow-definition-api-design.md docs/superpowers/plans/2026-06-09-zigeffect-workflow-definition-api.md docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md
git commit -m "feat(zigeffect): add workflow definition API"
```

## Self-Review Checklist

- [ ] Definitions are type-level and do not execute workflow bodies.
- [ ] Idempotency keys are caller-owned and deinitialized by tests.
- [ ] Execution id derivation is deterministic.
- [ ] Requirement declarations use existing service tuple validation.
- [ ] Compile-fail diagnostic covers invalid callback shape.
- [ ] No workflow engine, activity API, journal write, or payload codec is added.
- [ ] Full verification passes before Milestone 6 is marked complete.
