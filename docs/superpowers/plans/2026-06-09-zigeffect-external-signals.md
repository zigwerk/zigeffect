# zigeffect External Signals Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add durable external signals with typed definitions, replay-aware waits, external append/resume, deterministic consumption, timeout support, and file-store restart coverage.

**Architecture:** Keep the workflow journal schema stable by using `signal_received` and `signal_consumed` names/details rather than adding a new journal id field. Use `workflow/signal.zig` for definitions, ids, wait result types, and external append APIs. Wire `WorkflowContext.waitForSignal` through the journal, and reuse durable timer rows for signal timeouts.

**Tech Stack:** Zig 0.16, existing `Codec`, `Suspension`, `JournalStore`, `WorkflowContext`, `DurableClock`, `FileJournalStore`, Bun project scripts.

---

## File Structure

- Create `packages/zigeffect/src/workflow/signal.zig`
  - Owns `Signal`, `SignalMetadata`, `SignalWaitResult`, `DurableSignal`, `signalId`, and signal detail/idempotency helpers.
- Modify `packages/zigeffect/src/workflow/context.zig`
  - Adds `waitForSignal` and signal replay/consumption helpers.
- Modify `packages/zigeffect/src/workflow/root.zig`
  - Exposes signal module names.
- Modify `packages/zigeffect/test/workflow_test.zig`
  - Adds signal definition, wait, append, consume, timeout, idempotency, replay, and file-store tests.
- Modify `packages/zigeffect/docs/architecture.md`
  - Documents durable signal ownership.
- Modify `docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md`
  - Marks Milestone 15 complete after the full gate.

## Task 1: Signal Module And Definitions

**Files:**
- Create `packages/zigeffect/src/workflow/signal.zig`
- Modify `packages/zigeffect/src/workflow/root.zig`
- Modify `packages/zigeffect/test/workflow_test.zig`

- [ ] **Step 1: Write failing definition/export tests**

Add tests for stable `signalId`, `Signal("approval", u64).metadata()`, payload
type exposure, and `withTimeoutMs`.

- [ ] **Step 2: Verify red**

Run:

```bash
cd packages/zigeffect && zig build test-raw --summary all
```

Expected: FAIL until signal module exports exist.

- [ ] **Step 3: Implement signal module shell**

Add signal definition metadata, timeout attachment, stable signal id, wait
result type, and `DurableSignal.init`.

- [ ] **Step 4: Verify green**

Run:

```bash
bun run zigeffect:test
```

Expected: PASS.

## Task 2: Wait And Replay Before Receipt

**Files:**
- Modify `packages/zigeffect/src/workflow/context.zig`
- Modify `packages/zigeffect/test/workflow_test.zig`

- [ ] **Step 1: Write failing wait suspension test**

Call `context.waitForSignal(Approval, codec)` with no received signal. Assert
`.suspended`, `SuspensionKind.signal`, stable id, one `workflow_suspended`
event, and no duplicate suspension on a fresh replay before receipt.

- [ ] **Step 2: Verify red**

Run:

```bash
cd packages/zigeffect && zig build test-raw --summary all
```

Expected: FAIL until `WorkflowContext.waitForSignal` exists.

- [ ] **Step 3: Implement wait pending behavior**

Read the current journal, detect prior consumed rows, detect unconsumed received
rows, append signal suspension only when absent, and return `.suspended`.

- [ ] **Step 4: Verify green**

Run:

```bash
bun run zigeffect:test
```

Expected: PASS.

## Task 3: External Append, Resume, Consume, And Idempotency

**Files:**
- Modify `packages/zigeffect/src/workflow/signal.zig`
- Modify `packages/zigeffect/src/workflow/context.zig`
- Modify `packages/zigeffect/test/workflow_test.zig`

- [ ] **Step 1: Write failing append/consume tests**

Use `DurableSignal.send(Approval, codec, payload, "operator-1")`. Assert
`signal_received`, duplicate key returns false, `workflow_resumed` is appended
when suspended, `waitForSignal` returns decoded payload and appends
`signal_consumed`, and replay returns the same consumed payload without
duplicates.

- [ ] **Step 2: Verify red**

Run:

```bash
cd packages/zigeffect && zig build test-raw --summary all
```

Expected: FAIL until append and consume APIs exist.

- [ ] **Step 3: Implement append/resume and deterministic consume**

Encode payloads through `Codec`, derive signal idempotency keys, convert
duplicate append keys to `false`, append `workflow_resumed` for suspended
executions, append `signal_consumed` with `received_sequence=<n>`, and replay
consumed rows.

- [ ] **Step 4: Verify green**

Run:

```bash
bun run zigeffect:test
```

Expected: PASS.

## Task 4: Signal Timeout Support

**Files:**
- Modify `packages/zigeffect/src/workflow/context.zig`
- Modify `packages/zigeffect/src/workflow/signal.zig`
- Modify `packages/zigeffect/test/workflow_test.zig`

- [ ] **Step 1: Write failing timeout tests**

Use `Signal("approval", u64).withTimeoutMs(250)`. Assert missing signal wait
schedules a durable timeout timer, firing it makes wait return `.timed_out`,
and receiving the signal first cancels the timeout timer.

- [ ] **Step 2: Verify red**

Run:

```bash
cd packages/zigeffect && zig build test-raw --summary all
```

Expected: FAIL until signal timeout handling exists.

- [ ] **Step 3: Implement timeout scheduling and terminal replay**

Schedule `signal:<name>:timeout` timer rows, detect `timer_fired` as timeout,
append timed-out `signal_consumed`, cancel pending timeout on received signal,
and avoid stale timeout firing.

- [ ] **Step 4: Verify green**

Run:

```bash
bun run zigeffect:test
```

Expected: PASS.

## Task 5: File Store Restart Signal Flow

**Files:**
- Modify `packages/zigeffect/test/workflow_test.zig`

- [ ] **Step 1: Write failing file-store restart test**

Schedule a wait in `FileJournalStore`, close/reopen, append the signal, close
reopen again, and assert wait returns the decoded payload with running replay
state.

- [ ] **Step 2: Verify red**

Run:

```bash
cd packages/zigeffect && zig build test-raw --summary all
```

Expected: FAIL until file-store-compatible append/wait paths are complete.

- [ ] **Step 3: Fix any file-store compatibility gaps**

Ensure all signal operations use only the `JournalStore` interface and strict
append sequencing.

- [ ] **Step 4: Verify green**

Run:

```bash
bun run zigeffect:test
```

Expected: PASS.

## Task 6: Docs, Roadmap, Full Gate, And Commit

**Files:**
- Modify `packages/zigeffect/docs/architecture.md`
- Modify `docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md`
- Add `docs/superpowers/specs/2026-06-09-zigeffect-external-signals-design.md`
- Add `docs/superpowers/plans/2026-06-09-zigeffect-external-signals.md`

- [ ] **Step 1: Update architecture docs**

Document `workflow/signal.zig` and `WorkflowContext.waitForSignal` ownership.

- [ ] **Step 2: Run full gate**

Run:

```bash
bun run zigeffect:test
cd packages/zigeffect && zig build examples
bun run zig:test
zig fmt --check packages/zigeffect/src/workflow/signal.zig packages/zigeffect/src/workflow/context.zig packages/zigeffect/src/workflow/root.zig packages/zigeffect/test/workflow_test.zig
git diff --check
rg -n 'T''BD|TO''DO|implement la''ter|fill in de''tails|appropriate error hand''ling|handle edge ca''ses|Similar to Ta''sk|deferred bu''cket|par''ked' packages/zigeffect/src/workflow packages/zigeffect/test/workflow_test.zig packages/zigeffect/docs/architecture.md docs/superpowers/specs/2026-06-09-zigeffect-external-signals-design.md docs/superpowers/plans/2026-06-09-zigeffect-external-signals.md
```

Expected: compile/test commands PASS, format and diff checks exit 0, and the
placeholder scan exits 1 with no matches.

- [ ] **Step 3: Mark Milestone 15 complete**

After the full gate passes, mark all Milestone 15 deliverables and acceptance
boxes complete in
`docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md`.
