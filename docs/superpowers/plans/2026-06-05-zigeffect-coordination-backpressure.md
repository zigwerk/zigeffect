# zigeffect Coordination Backpressure Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans
> and keep tests red/green.

**Goal:** Add queue shutdown and scoped semaphore permit semantics for the
deterministic runtime.

**Architecture:** Changes stay in
`packages/zigeffect/src/runtime/coordination.zig`, with tests in
`packages/zigeffect/test/fiber_test.zig`.

**Verification:** `bun run zigeffect:test`, `bun run zig:test`,
`bun run typecheck`.

## Tasks

- [x] Add failing queue shutdown and scoped semaphore tests.
- [x] Add `QueueShutdown`, `shutdown`, `isShutdown`, and drain-after-shutdown
  behavior.
- [x] Add `Semaphore.acquireScoped(scope, permits)` with finalizer cleanup.
- [x] Update usage, parity, and roadmap docs.
- [x] Run full verification.
