# zigeffect Graph/Fiber Scope Cohesion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an explicit scope-attached fiber fork API and prove graph startup scope cleanup interrupts graph-started child fibers.

**Architecture:** Implement `FiberRuntime.forkInScope(scope, effect)` in `runtime/fiber.zig`, delegate `forkScoped` to it, and add a graph startup test in `layer_test.zig`.

**Tech Stack:** Zig, deterministic zigeffect fiber runtime, existing Bun verification commands.

---

## Tasks

- [x] Write failing graph startup fiber cleanup test.
- [x] Verify the test fails before implementation.
- [x] Implement `FiberRuntime.forkInScope`.
- [x] Delegate `forkScoped` to `forkInScope`.
- [x] Run focused zigeffect tests.
- [x] Update roadmap/resource docs.
- [x] Run full verification.
