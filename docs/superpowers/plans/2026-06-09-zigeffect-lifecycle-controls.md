# zigeffect Workflow Lifecycle Controls Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add durable workflow lifecycle controls for suspend, resume, interrupt, and cancel, including explicit pending-work behavior for timers, deferreds, queues, and activities.

**Architecture:** Add `workflow/lifecycle.zig` as an external control API over `JournalStore`. Use existing lifecycle event kinds and replay statuses. Lifecycle terminal controls scan the journal and append terminal rows for pending durable work before appending `workflow_interrupted` or `workflow_cancelled`.

**Tech Stack:** Zig 0.16, existing workflow journal/replay/store modules, durable timer/deferred/queue/activity event rows, Bun project scripts.

---

## File Structure

- Create `packages/zigeffect/src/workflow/lifecycle.zig`
  - Owns lifecycle control API, current-state scan, pending-work termination,
    lifecycle idempotency keys, and detail formatting.
- Modify `packages/zigeffect/src/workflow/root.zig`
  - Exposes lifecycle module names.
- Modify `packages/zigeffect/test/workflow_test.zig`
  - Adds suspend/resume, interrupt, cancel, pending work, and file-store
    restart tests.
- Modify `packages/zigeffect/docs/architecture.md`
  - Documents lifecycle ownership.
- Modify `docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md`
  - Marks Milestone 17 complete after the full gate.

## Task 1: Lifecycle Module, Suspend, And Resume

**Files:**
- Create `packages/zigeffect/src/workflow/lifecycle.zig`
- Modify `packages/zigeffect/src/workflow/root.zig`
- Modify `packages/zigeffect/test/workflow_test.zig`

- [ ] **Step 1: Write failing suspend/resume tests**

Use a running workflow, call `WorkflowLifecycle.suspend("operator")`, assert a
`workflow_suspended` row and replay suspended status. Reopen/fresh lifecycle,
call suspend again and assert false/no duplicate. Resume after restart and
assert `workflow_resumed` plus running status.

- [ ] **Step 2: Verify red**

Run:

```bash
cd packages/zigeffect && zig build test-raw --summary all
```

Expected: FAIL until lifecycle exports exist.

- [ ] **Step 3: Implement lifecycle shell/suspend/resume**

Add `WorkflowLifecycle.init`, current status scanning, append helpers, suspend,
resume, terminal/idempotency checks, and root exports.

- [ ] **Step 4: Verify green**

Run:

```bash
bun run zigeffect:test
```

Expected: PASS.

## Task 2: Interrupt And Cancel Terminal Controls

**Files:**
- Modify `packages/zigeffect/src/workflow/lifecycle.zig`
- Modify `packages/zigeffect/test/workflow_test.zig`

- [ ] **Step 1: Write failing terminal action tests**

Call `interrupt("operator")` and `cancel("operator")` on separate running
workflows. Assert terminal workflow rows, redacted cause/reason detail, replay
status, and no duplicate terminal row after restart.

- [ ] **Step 2: Verify red**

Run:

```bash
cd packages/zigeffect && zig build test-raw --summary all
```

Expected: FAIL until terminal lifecycle APIs exist.

- [ ] **Step 3: Implement interrupt/cancel**

Append terminal lifecycle rows with deterministic idempotency keys and return
false for already-terminal executions.

- [ ] **Step 4: Verify green**

Run:

```bash
bun run zigeffect:test
```

Expected: PASS.

## Task 3: Pending Work Policy

**Files:**
- Modify `packages/zigeffect/src/workflow/lifecycle.zig`
- Modify `packages/zigeffect/test/workflow_test.zig`

- [ ] **Step 1: Write failing pending-work tests**

Build a journal with one pending timer, deferred, queue, and activity. Call
`cancel("operator")` and assert `timer_cancelled`, `deferred_cancelled`,
`queue_failed`, and `activity_failed` rows before `workflow_cancelled`. Repeat
for interrupt detail shape where useful.

- [ ] **Step 2: Verify red**

Run:

```bash
cd packages/zigeffect && zig build test-raw --summary all
```

Expected: FAIL until pending-work termination exists.

- [ ] **Step 3: Implement pending-work termination**

Scan current event history, identify latest nonterminal timer/deferred/queue and
activity rows, append explicit terminal rows with lifecycle detail, and avoid
duplicates on repeated terminal actions.

- [ ] **Step 4: Verify green**

Run:

```bash
bun run zigeffect:test
```

Expected: PASS.

## Task 4: File Store Restart Lifecycle Controls

**Files:**
- Modify `packages/zigeffect/test/workflow_test.zig`

- [ ] **Step 1: Write failing file-store lifecycle test**

Open a `FileJournalStore`, start and suspend a workflow, close/reopen, resume,
close/reopen, cancel, and assert final replay status is cancelled with no
duplicate lifecycle rows.

- [ ] **Step 2: Verify red**

Run:

```bash
cd packages/zigeffect && zig build test-raw --summary all
```

Expected: FAIL until lifecycle controls are fully store-compatible; PASS is
acceptable if earlier tasks already used only `JournalStore`.

- [ ] **Step 3: Fix any store-compatibility gaps**

Ensure lifecycle controls use only `JournalStore` append/read operations with
strict sequence handling.

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
- Add `docs/superpowers/specs/2026-06-09-zigeffect-lifecycle-controls-design.md`
- Add `docs/superpowers/plans/2026-06-09-zigeffect-lifecycle-controls.md`

- [ ] **Step 1: Update architecture docs**

Document `workflow/lifecycle.zig` ownership.

- [ ] **Step 2: Run full gate**

Run:

```bash
bun run zigeffect:test
cd packages/zigeffect && zig build examples
bun run zig:test
zig fmt --check packages/zigeffect/src/workflow/lifecycle.zig packages/zigeffect/src/workflow/root.zig packages/zigeffect/test/workflow_test.zig
git diff --check
rg -n 'T''BD|TO''DO|implement la''ter|fill in de''tails|appropriate error hand''ling|handle edge ca''ses|Similar to Ta''sk|deferred bu''cket|par''ked' packages/zigeffect/src/workflow packages/zigeffect/test/workflow_test.zig packages/zigeffect/docs/architecture.md docs/superpowers/specs/2026-06-09-zigeffect-lifecycle-controls-design.md docs/superpowers/plans/2026-06-09-zigeffect-lifecycle-controls.md
```

Expected: compile/test commands PASS, format and diff checks exit 0, and the
placeholder scan exits 1 with no matches.

- [ ] **Step 3: Mark Milestone 17 complete**

After the full gate passes, mark all Milestone 17 deliverables and acceptance
boxes complete in
`docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md`.
