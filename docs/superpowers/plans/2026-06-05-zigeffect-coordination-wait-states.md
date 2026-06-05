# zigeffect Coordination Wait States Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add deterministic wait-state inspection APIs for coordination primitives.

**Architecture:** Extend `runtime/coordination.zig` with public state enums and inspection methods, update operation implementations to use those states, and export the enums through the facade.

**Tech Stack:** Zig deterministic coordination primitives, existing zigeffect tests, Bun verification commands.

---

## Tasks

- [x] Write failing tests for deferred, queue, and semaphore wait states.
- [x] Verify tests fail before implementation.
- [x] Add public wait-state enums.
- [x] Add `awaitState`, `offerState`, `takeState`, and `acquireState`.
- [x] Route existing operations through the state helpers.
- [x] Export wait-state enums.
- [x] Run focused zigeffect tests.
- [x] Update usage/roadmap docs.
- [x] Run full verification.
