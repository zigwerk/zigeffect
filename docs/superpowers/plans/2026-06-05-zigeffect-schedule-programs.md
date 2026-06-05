# zigeffect Schedule Programs Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an owned recursive schedule-program tree for deterministic schedule composition.

**Architecture:** Implement `ScheduleProgram` in `effect/schedule.zig`, export it through `zigeffect.zig`, and cover recursive union/intersection/sequence decisions with tests.

**Tech Stack:** Zig schedules, existing zigeffect test runner, Bun verification commands.

---

## Tasks

- [x] Write failing tests for recursive schedule programs.
- [x] Verify the tests fail before implementation.
- [x] Implement `Schedule.maxContinuations`.
- [x] Implement `ScheduleProgram` nodes and decision logic.
- [x] Export `ScheduleProgram`.
- [x] Run focused zigeffect tests.
- [x] Update usage/roadmap docs.
- [x] Run full verification.
