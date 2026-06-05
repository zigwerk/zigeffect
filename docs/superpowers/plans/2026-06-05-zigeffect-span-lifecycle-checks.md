# zigeffect Span Lifecycle Checks Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans
> and test-driven development.

**Goal:** Add deterministic tracing span lookup and lifecycle assertions.

**Architecture:** `Tracing` exposes read-only span query helpers; `TestEnv`
wraps them in test assertions.

**Tech Stack:** Zig, Bun-driven `zig build test`, existing service tests.

---

## Tasks

- [x] Add RED service test for span lifecycle assertions.
- [x] Run `bun run zigeffect:test` and confirm missing helpers fail.
- [x] Implement tracing query helpers.
- [x] Implement `TestEnv` span assertions.
- [x] Re-run focused and full verification.
- [x] Update docs/roadmap status.
