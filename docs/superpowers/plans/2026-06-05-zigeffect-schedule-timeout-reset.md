# zigeffect Schedule Timeout And Reset Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> superpowers:executing-plans and test-driven development.

**Goal:** Add timeout and reset policy vocabulary to schedules without changing
existing retry/repeat behavior.

**Architecture:** Extend `effect/schedule.zig` with two new schedule kinds and a
small reset inspection helper.

**Verification:** `bun run zigeffect:test`, `bun run zig:test`,
`bun run typecheck`.

---

## Tasks

- [x] Add RED tests for timeout and reset schedules.
- [x] Add `Schedule.timeout` and elapsed-budget delay behavior.
- [x] Add `Schedule.reset` and `resetAttempt`.
- [x] Update docs/roadmap and run full verification.
