# zigeffect Cause And Exit Hardening Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans
> and keep the tests red/green.

**Goal:** Preserve original exit status when cleanup fails and add cause
inspection helpers for tests.

**Architecture:** Cause variants and inspection helpers live in
`packages/zigeffect/src/core/result.zig`. Public aliases flow through
`packages/zigeffect/src/zigeffect.zig`.

**Verification:** `bun run zigeffect:test`, `bun run zig:test`,
`bun run typecheck`.

## Tasks

- [x] Add failing tests in `packages/zigeffect/test/effect_test.zig` for defect
  plus cleanup, interruption plus cleanup, and cause inspection helpers.
- [x] Add direct `defect_then_finalizer_failure` and
  `interrupted_then_finalizer_failure` variants to `Cause`.
- [x] Update `exitWithFinalizerFailure` and `formatCause`.
- [x] Add `causeHasFinalizerFailure`, `causeHasDefect`, and
  `causeHasInterruption` helpers.
- [x] Expose helpers through the facade.
- [x] Update docs and roadmap status.
- [x] Run full verification.
