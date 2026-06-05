# zigeffect Resource Model Expansion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans
> and test-driven development. Keep each task red/green.

**Goal:** Add value-resource acquisition and better cleanup failure reporting
while preserving existing pointer-resource behavior.

**Architecture:** Value resources live in `src/effect/resource.zig`. Combined
failure reporting lives in `src/core/result.zig` and is used by runtime, fiber,
and graph exit paths.

**Verification:** `bun run zigeffect:test`, `bun run zig:test`,
`bun run typecheck`.

## Tasks

- [x] Add resource fixtures for value resources, nested release ordering, and
  program failure plus failing cleanup.
- [x] Add failing tests for `acquireReleaseValue`, no-scope immediate release,
  nested reverse cleanup, and combined runtime cleanup cause reporting.
- [x] Implement `acquireReleaseValue` in `packages/zigeffect/src/effect/resource.zig`
  and expose it through the facade.
- [x] Add a direct `failure_then_finalizer_failure` `Cause` variant and a helper
  for applying finalizer failures to an existing `Exit`.
- [x] Use the helper in `Runtime.exit`, `FiberState.closeChildScope`, and
  `LayerGraphRuntime.exit`.
- [x] Update usage/errors/roadmap docs.
- [x] Run full verification.
