# zigeffect Test Assertion Reports Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add readable assertion report formatters to the zigeffect test toolkit.

**Architecture:** Keep report generation in `testing/test_env.zig`, expose it under `fx.testing`, and leave existing assertion helper signatures stable.

**Tech Stack:** Zig, existing `bun run zigeffect:test` and repo verification commands.

---

## Tasks

- [x] Write failing tests for log, schedule, fiber, and queue assertion reports.
- [x] Verify the tests fail before implementation.
- [x] Implement assertion report formatters in `src/testing/test_env.zig`.
- [x] Export the formatters through `src/zigeffect.zig`.
- [x] Run focused zigeffect tests.
- [x] Update usage/roadmap docs.
- [x] Run full verification.
