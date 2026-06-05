# zigeffect Test Toolkit Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans
> and keep tests red/green.

**Goal:** Add small deterministic assertion helpers for logs, metrics, reports,
causes, and schedules.

**Architecture:** Helpers live in `packages/zigeffect/src/testing/test_env.zig`
and are exposed through `fx.testing`.

**Verification:** `bun run zigeffect:test`, `bun run zig:test`,
`bun run typecheck`.

## Tasks

- [x] Add failing tests for new helpers.
- [x] Add `TestEnv.expectStructuredLog` and `TestEnv.expectHistogram`.
- [x] Add `expectDependencyReportMissing`, `expectCause*`, and
  `expectScheduleDelay` helpers.
- [x] Expose helpers through `fx.testing`.
- [x] Update usage, parity, and roadmap docs.
- [x] Run full verification.
