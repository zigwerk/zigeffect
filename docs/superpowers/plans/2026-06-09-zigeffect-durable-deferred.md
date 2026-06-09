# zigeffect Durable Deferred Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add durable deferred await, external completion/failure/cancellation APIs, typed success/failure serialization, and replay of completed values.

**Architecture:** Use the existing deferred journal event vocabulary and replay state. Add a focused `workflow/deferred.zig` module for durable deferred result types and external append helpers, then wire `WorkflowContext.awaitDeferred` through the same identity and terminal-row parsing.

**Tech Stack:** Zig 0.16, existing `Codec`, existing `Suspension`, existing workflow journal store/replay/context modules, Bun project scripts.

---

## File Structure

- Create `packages/zigeffect/src/workflow/deferred.zig`
  - Owns `DeferredAwaitResult`, `DurableDeferred`, `deferredId`, and external completion APIs.
- Modify `packages/zigeffect/src/workflow/context.zig`
  - Adds `awaitDeferred` and deferred terminal replay.
- Modify `packages/zigeffect/src/workflow/root.zig`
  - Exposes deferred module types and helpers.
- Modify `packages/zigeffect/test/workflow_test.zig`
  - Adds await suspension, completion replay, failure replay, cancellation replay, and idempotent external completion tests.
- Modify `packages/zigeffect/docs/architecture.md`
  - Documents deferred ownership.
- Modify `docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md`
  - Marks Milestone 13 complete after the full gate.

## Task 1: Deferred Module And Identity

**Files:**
- Create `packages/zigeffect/src/workflow/deferred.zig`
- Modify `packages/zigeffect/src/workflow/root.zig`
- Modify `packages/zigeffect/test/workflow_test.zig`

- [ ] **Step 1: Write failing identity and export tests**

Add:

```zig
test "workflow deferred ids are stable by label" {
    try std.testing.expectEqual(fx.workflow.deferredId("approval"), fx.workflow.deferredId("approval"));
    try std.testing.expect(fx.workflow.deferredId("approval") != fx.workflow.deferredId("payment"));
    try std.testing.expect(@hasDecl(fx.workflow, "DurableDeferred"));
}
```

- [ ] **Step 2: Verify red**

Run:

```bash
cd packages/zigeffect && zig build test-raw --summary all
```

Expected: FAIL until the deferred module and exports exist.

- [ ] **Step 3: Implement deferred module shell**

Add `deferred.zig` with `deferredId(label)`, `DeferredAwaitResult`, and a
`DurableDeferred` struct shell with allocator, journal store, workflow id, and
execution id fields. Export these names from `workflow/root.zig`.

- [ ] **Step 4: Verify green**

Run:

```bash
bun run zigeffect:test
```

Expected: PASS.

## Task 2: Await Missing Deferred Suspends

**Files:**
- Modify `packages/zigeffect/src/workflow/context.zig`
- Modify `packages/zigeffect/test/workflow_test.zig`

- [ ] **Step 1: Write failing await suspension test**

Call `context.awaitDeferred("approval", codec, error{Rejected})` with only
`workflow_started` present. Assert the result is `.suspended` with
`SuspensionKind.deferred`, and journal rows are `deferred_created`,
`deferred_awaited`, and `workflow_suspended`.

- [ ] **Step 2: Verify red**

Run:

```bash
cd packages/zigeffect && zig build test-raw --summary all
```

Expected: FAIL because `awaitDeferred` does not exist.

- [ ] **Step 3: Implement missing-deferred await**

Add `WorkflowContext.awaitDeferred`. For a missing deferred, append
`deferred_created`, append `deferred_awaited`, append `workflow_suspended`, and
return `.suspended = .{ .kind = .deferred, .id = id, .label = label }`.

- [ ] **Step 4: Verify green**

Run:

```bash
bun run zigeffect:test
```

Expected: PASS.

## Task 3: External Completion And Completed Replay

**Files:**
- Modify `packages/zigeffect/src/workflow/deferred.zig`
- Modify `packages/zigeffect/src/workflow/context.zig`
- Modify `packages/zigeffect/test/workflow_test.zig`

- [ ] **Step 1: Write failing completion replay test**

After an initial suspended await, call
`DurableDeferred.init(...).complete("approval", codec, 42)`. Create a fresh
context and await again. Assert the result is `.completed = 42`, no duplicate
await rows are appended, and repeated `complete` does not append a second
terminal row.

- [ ] **Step 2: Verify red**

Run:

```bash
cd packages/zigeffect && zig build test-raw --summary all
```

Expected: FAIL until external completion and completed replay exist.

- [ ] **Step 3: Implement external completion**

Add `DurableDeferred.init`, `complete`, terminal-row lookup, next-sequence
calculation, encoded-value append, and completed replay decoding in
`WorkflowContext.awaitDeferred`.

- [ ] **Step 4: Verify green**

Run:

```bash
bun run zigeffect:test
```

Expected: PASS.

## Task 4: External Failure And Cancellation Replay

**Files:**
- Modify `packages/zigeffect/src/workflow/deferred.zig`
- Modify `packages/zigeffect/src/workflow/context.zig`
- Modify `packages/zigeffect/test/workflow_test.zig`

- [ ] **Step 1: Write failing failure and cancellation tests**

Use `DurableDeferred.fail("approval", error.Rejected)` and assert await
returns `.failed = error.Rejected`. Use `DurableDeferred.cancel("approval",
"operator")` and assert await returns `.cancelled = "operator"`.

- [ ] **Step 2: Verify red**

Run:

```bash
cd packages/zigeffect && zig build test-raw --summary all
```

Expected: FAIL until failed and cancelled terminal rows replay.

- [ ] **Step 3: Implement failure and cancellation**

Append failed rows with `Exit.cause.failure:<error-name>`, append cancelled rows
with the cancellation reason, parse failures into the requested error set, and
return cancelled details directly from replay.

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
- Add `docs/superpowers/specs/2026-06-09-zigeffect-durable-deferred-design.md`
- Add `docs/superpowers/plans/2026-06-09-zigeffect-durable-deferred.md`

- [ ] **Step 1: Update architecture docs**

Document `workflow/deferred.zig` and `WorkflowContext.awaitDeferred`.

- [ ] **Step 2: Run full gate**

Run:

```bash
bun run zigeffect:test
cd packages/zigeffect && zig build examples
bun run zig:test
git diff --check
rg -n 'T''BD|TO''DO|implement la''ter|fill in de''tails|appropriate error hand''ling|handle edge ca''ses|Similar to Ta''sk|deferred bu''cket|par''ked' packages/zigeffect/src/workflow packages/zigeffect/test/workflow_test.zig packages/zigeffect/docs/architecture.md docs/superpowers/specs/2026-06-09-zigeffect-durable-deferred-design.md docs/superpowers/plans/2026-06-09-zigeffect-durable-deferred.md
```

Expected: compile/test commands PASS, `git diff --check` exits 0, and the
placeholder scan exits 1 with no matches.

- [ ] **Step 3: Mark Milestone 13 complete**

After the full gate passes, mark all Milestone 13 deliverables and acceptance
boxes complete in
`docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md`.

- [ ] **Step 4: Commit**

```bash
git add packages/zigeffect/src/workflow/deferred.zig packages/zigeffect/src/workflow/context.zig packages/zigeffect/src/workflow/root.zig packages/zigeffect/test/workflow_test.zig packages/zigeffect/docs/architecture.md docs/superpowers/specs/2026-06-09-zigeffect-durable-deferred-design.md docs/superpowers/plans/2026-06-09-zigeffect-durable-deferred.md docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md
git commit -m "feat(zigeffect): add durable deferreds"
```

## Self-Review Checklist

- [ ] Awaiting missing deferreds returns a suspension value.
- [ ] Completed deferred replay decodes through `Codec`.
- [ ] Failed deferred replay returns the requested error-set value.
- [ ] Cancelled deferred replay returns the recorded reason.
- [ ] External terminal appends are idempotent.
- [ ] No distributed notification, scheduler loop, worker polling, or timer integration is added in this milestone.
