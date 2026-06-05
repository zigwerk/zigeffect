# zigeffect Runtime Shared Scope Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> superpowers:executing-plans and test-driven development.

**Goal:** Deliver explicit long-lived runtime scopes through `Runtime.withScope`
without changing default per-run cleanup.

**Architecture:** Runtime owns the opt-in pointer to an external `Scope`;
`Context` remains the only finalizer registration path and rejects closed
scopes.

**Verification:** `bun run zigeffect:test`, `bun run zig:test`,
`bun run typecheck`.

---

## Tasks

- [x] Add RED tests for shared runtime-scope retention and closed-scope
  registration failure.
- [x] Add `Runtime.withScope` and shared-scope execution behavior.
- [x] Add closed-scope guards to context finalizer registration methods.
- [x] Update docs/roadmap and run full verification.
