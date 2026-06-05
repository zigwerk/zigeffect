# zigeffect Fiber Workflow Assertions Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> superpowers:executing-plans and test-driven development.

**Goal:** Add deterministic queue producer/consumer workflow coverage under
fibers and small reusable assertions.

**Architecture:** Tests live in `test/fiber_test.zig`; helpers live in
`src/testing/test_env.zig` and are exported through `fx.testing`.

**Verification:** `bun run zigeffect:test`, `bun run zig:test`,
`bun run typecheck`.

---

## Tasks

- [x] Add RED fiber workflow test using missing queue/fiber assertions.
- [x] Implement `expectFiberStatus`, `expectQueueLen`, and
  `expectQueueShutdown`.
- [x] Update usage/roadmap docs.
- [x] Run full verification.
