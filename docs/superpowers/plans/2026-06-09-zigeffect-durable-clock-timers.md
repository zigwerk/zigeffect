# zigeffect Durable Clock And Timers Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add durable sleep, timer firing, timer cancellation, due timer querying, and a local file-store-compatible wake-up loop.

**Architecture:** Use existing timer journal events and replay state. Add a focused `workflow/clock.zig` module for durable timer identity, sleep result types, due timer queries, and firing helpers, then wire `WorkflowContext.sleep` and `sleepUntil` through that module.

**Tech Stack:** Zig 0.16, existing `Clock`, existing `Suspension`, existing workflow journal store/replay/context modules, Bun project scripts.

---

## File Structure

- Create `packages/zigeffect/src/workflow/clock.zig`
  - Owns `timerId`, `TimerSleepResult`, `DurableClock`, due timer list, fire, and cancel helpers.
- Modify `packages/zigeffect/src/workflow/context.zig`
  - Adds `sleep` and `sleepUntil`.
- Modify `packages/zigeffect/src/workflow/root.zig`
  - Exposes clock module names.
- Modify `packages/zigeffect/test/workflow_test.zig`
  - Adds sleep suspension, replay-before-fire idempotency, fire/resume, cancellation, due query, and file-store wake-up tests.
- Modify `packages/zigeffect/docs/architecture.md`
  - Documents durable clock ownership.
- Modify `docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md`
  - Marks Milestone 14 complete after the full gate.

## Task 1: Durable Clock Module And Timer Identity

**Files:**
- Create `packages/zigeffect/src/workflow/clock.zig`
- Modify `packages/zigeffect/src/workflow/root.zig`
- Modify `packages/zigeffect/test/workflow_test.zig`

- [x] **Step 1: Write failing identity/export tests**

Add:

```zig
test "workflow timer ids are stable by label" {
    try std.testing.expectEqual(fx.workflow.timerId("wake"), fx.workflow.timerId("wake"));
    try std.testing.expect(fx.workflow.timerId("wake") != fx.workflow.timerId("timeout"));
    try std.testing.expect(@hasDecl(fx.workflow, "DurableClock"));
}
```

- [x] **Step 2: Verify red**

Run:

```bash
cd packages/zigeffect && zig build test-raw --summary all
```

Expected: FAIL until durable clock exports exist.

- [x] **Step 3: Implement clock module shell**

Add `clock.zig` with `timerId(label)`, `TimerSleepResult`, `DueTimer`,
`DueTimerList`, and `DurableClock.init`. Export names from `workflow/root.zig`.

- [x] **Step 4: Verify green**

Run:

```bash
bun run zigeffect:test
```

Expected: PASS.

## Task 2: Sleep And Replay Before Fire

**Files:**
- Modify `packages/zigeffect/src/workflow/context.zig`
- Modify `packages/zigeffect/test/workflow_test.zig`

- [x] **Step 1: Write failing sleep suspension test**

With fake clock at `1_000`, call `context.sleep("wake", 250)`. Assert
`.suspended`, `timer_scheduled` detail `fire_at_ms=1250`, and
`workflow_suspended`. Create a fresh context and call sleep again; assert no
duplicate timer row is appended.

- [x] **Step 2: Verify red**

Run:

```bash
cd packages/zigeffect && zig build test-raw --summary all
```

Expected: FAIL until `WorkflowContext.sleep` exists.

- [x] **Step 3: Implement sleep/sleepUntil pending behavior**

Add `sleep(label, delay_ms)` and `sleepUntil(label, fire_at_ms)`. If no fired or
cancelled terminal row exists, append `timer_scheduled` only when absent, append
`workflow_suspended`, and return `.suspended`.

- [x] **Step 4: Verify green**

Run:

```bash
bun run zigeffect:test
```

Expected: PASS.

## Task 3: Due Query And Firing

**Files:**
- Modify `packages/zigeffect/src/workflow/clock.zig`
- Modify `packages/zigeffect/src/workflow/context.zig`
- Modify `packages/zigeffect/test/workflow_test.zig`

- [x] **Step 1: Write failing fire/resume tests**

Use `DurableClock.init(...).dueTimers(1_250)` and assert it returns the pending
timer. Call `fireDueTimers(1_250)`, create a fresh context, call sleep again,
and assert `.fired` with no duplicate schedule rows.

- [x] **Step 2: Verify red**

Run:

```bash
cd packages/zigeffect && zig build test-raw --summary all
```

Expected: FAIL until due query and fire APIs exist.

- [x] **Step 3: Implement due query and fire**

Parse `fire_at_ms=<timestamp>` details, collect scheduled timers due at or
before `now_ms`, skip fired/cancelled timers, append `timer_fired`, and return
the fired count.

- [x] **Step 4: Verify green**

Run:

```bash
bun run zigeffect:test
```

Expected: PASS.

## Task 4: Timer Cancellation And File Store Wake-Up

**Files:**
- Modify `packages/zigeffect/src/workflow/clock.zig`
- Modify `packages/zigeffect/src/workflow/context.zig`
- Modify `packages/zigeffect/test/workflow_test.zig`

- [x] **Step 1: Write failing cancel and file-store tests**

Call `DurableClock.cancel("wake")` and assert sleep replay returns
`.cancelled`. Add a file-store test that schedules a timer, reopens the file
store, calls `fireDueTimers`, and verifies replay returns `.fired`.

- [x] **Step 2: Verify red**

Run:

```bash
cd packages/zigeffect && zig build test-raw --summary all
```

Expected: FAIL until cancellation and file-store firing work.

- [x] **Step 3: Implement cancellation and file-store-compatible firing**

Append `timer_cancelled` through `DurableClock.cancel`. Ensure `fireDueTimers`
only uses the `JournalStore` interface so both in-memory and file stores work.

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
- Add `docs/superpowers/specs/2026-06-09-zigeffect-durable-clock-timers-design.md`
- Add `docs/superpowers/plans/2026-06-09-zigeffect-durable-clock-timers.md`

- [x] **Step 1: Update architecture docs**

Document `workflow/clock.zig` and `WorkflowContext.sleep` ownership.

- [x] **Step 2: Run full gate**

Run:

```bash
bun run zigeffect:test
cd packages/zigeffect && zig build examples
bun run zig:test
git diff --check
rg -n 'T''BD|TO''DO|implement la''ter|fill in de''tails|appropriate error hand''ling|handle edge ca''ses|Similar to Ta''sk|deferred bu''cket|par''ked' packages/zigeffect/src/workflow packages/zigeffect/test/workflow_test.zig packages/zigeffect/docs/architecture.md docs/superpowers/specs/2026-06-09-zigeffect-durable-clock-timers-design.md docs/superpowers/plans/2026-06-09-zigeffect-durable-clock-timers.md
```

Expected: compile/test commands PASS, `git diff --check` exits 0, and the
placeholder scan exits 1 with no matches.

- [x] **Step 3: Mark Milestone 14 complete**

After the full gate passes, mark all Milestone 14 deliverables and acceptance
boxes complete in
`docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md`.

- [ ] **Step 4: Commit**

```bash
git add packages/zigeffect/src/workflow/clock.zig packages/zigeffect/src/workflow/context.zig packages/zigeffect/src/workflow/root.zig packages/zigeffect/test/workflow_test.zig packages/zigeffect/docs/architecture.md docs/superpowers/specs/2026-06-09-zigeffect-durable-clock-timers-design.md docs/superpowers/plans/2026-06-09-zigeffect-durable-clock-timers.md docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md
git commit -m "feat(zigeffect): add durable clock timers"
```

## Self-Review Checklist

- [ ] Pending sleep appends a timer and suspension.
- [ ] Replay before fire does not duplicate the scheduled timer.
- [ ] Due timer query parses scheduled fire times.
- [ ] Firing due timers appends durable fired rows.
- [ ] Cancellation replays as cancelled.
- [ ] File-store firing uses only the `JournalStore` API.
