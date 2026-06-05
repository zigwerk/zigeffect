# zigeffect Test Fixtures Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> superpowers:executing-plans and test-driven development.

**Goal:** Add deterministic fixture/golden-output helpers to `TestEnv`.

**Architecture:** Extend `testing/test_env.zig` with `TestFixtureRegistry` and a
registry field on `TestEnv`; export the registry through the facade.

**Verification:** `bun run zigeffect:test`, `bun run zig:test`,
`bun run typecheck`.

---

## Tasks

- [x] Add RED tests for golden output, fixture replacement, and missing fixture
  errors.
- [x] Implement `TestFixtureRegistry`.
- [x] Add fixture registry methods to `TestEnv` and facade exports.
- [x] Update docs/roadmap and run full verification.
