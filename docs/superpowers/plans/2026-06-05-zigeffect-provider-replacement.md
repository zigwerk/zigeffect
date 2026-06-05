# zigeffect Provider Replacement Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> superpowers:executing-plans and test-driven development.

**Goal:** Deliver explicit provider replacement metadata for layer graphs while
preserving duplicate-provider errors by default.

**Architecture:** Extend the existing layer metadata protocol with
`replacedServices`, keep validation in `layer/graph.zig`, and preserve service
tuple validation through the existing dependency helpers.

**Verification:** `bun run zigeffect:test`, `bun run zig:test`,
`bun run typecheck`.

---

## Tasks

- [x] Add RED tests for manual graph validation, final graph service lookup, and
  dependency-injected startup lookup under replacement.
- [x] Add `replacedServices` metadata defaults and `ReplacementLayer`.
- [x] Add `.replaces(.{ ... })` fluent methods to layer wrappers.
- [x] Make graph duplicate-provider validation replacement-aware.
- [x] Make generated graph and startup contexts resolve the latest provider.
- [x] Update docs/roadmap and run full verification.
