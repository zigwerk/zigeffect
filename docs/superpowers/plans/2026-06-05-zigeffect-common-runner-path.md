# zigeffect Common Runner Path Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans.

**Goal:** Add a shared managed-scope runner helper and route duplicated runner
paths through it.

**Architecture:** `runtime/runner.zig` owns shared execution/exit close logic.
Callers still build contexts and perform dependency validation.

**Tech Stack:** Zig, Bun-driven `zig build test`, existing runtime/layer/scope
tests.

---

## Tasks

- [x] Add `src/runtime/runner.zig`.
- [x] Route regular runtime owned-scope run/exit through the helper.
- [x] Route layer provide wrappers through the helper.
- [x] Route graph run/exit and narrowed run/exit through the helper.
- [x] Re-run focused and full verification.
- [x] Update docs/roadmap status.
