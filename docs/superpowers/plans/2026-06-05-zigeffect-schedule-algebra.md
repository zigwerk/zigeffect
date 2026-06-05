# zigeffect Schedule Algebra Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans
> and keep tests red/green.

**Goal:** Add schedule decision inspection and small union/intersection delay
composition helpers.

**Architecture:** All behavior stays in
`packages/zigeffect/src/effect/schedule.zig`; no new modules are needed.

**Verification:** `bun run zigeffect:test`, `bun run zig:test`,
`bun run typecheck`.

## Tasks

- [x] Add failing tests in `packages/zigeffect/test/schedule_test.zig`.
- [x] Add `Schedule.Decision`, `decision`, and `isExhausted`.
- [x] Add `unionNextDelay` and `intersectionNextDelay`.
- [x] Update usage, parity, and roadmap docs.
- [x] Run full verification.
