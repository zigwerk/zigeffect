# zigeffect Observability Reporting Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a stable observability report formatter for logger, metrics, and tracing services.

**Architecture:** Create `services/observability.zig`, export it through the facade, and cover report output in `services_test.zig`.

**Tech Stack:** Zig service modules, existing zigeffect tests, Bun verification commands.

---

## Tasks

- [x] Write failing observability report test.
- [x] Verify the test fails before implementation.
- [x] Implement `services/observability.zig`.
- [x] Export observability formatter through `src/zigeffect.zig`.
- [x] Run focused zigeffect tests.
- [x] Update usage/roadmap docs.
- [x] Run full verification.
