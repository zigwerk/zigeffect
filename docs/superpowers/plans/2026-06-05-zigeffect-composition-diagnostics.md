# zigeffect Composition Diagnostics Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans
> and test-driven development. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Add stable compile-time diagnostics for bad effect functions, bad layer
merge functions, and resource failure sets that cannot return scope/allocation
errors.

**Architecture:** Compile-time checks live in the API-owning modules:
`effect/effect.zig`, `layer/layer.zig`, and `effect/resource.zig`. Compile-fail
fixtures live in `packages/zigeffect/test/compile_fail/`.

**Tech Stack:** Zig 0.16, Bun scripts, `bun run zigeffect:test`.

---

## Tasks

- [x] Add compile-fail fixtures for invalid effect function, invalid layer merge
  function, and invalid resource error set.
- [x] Add tests in `packages/zigeffect/test/layer_test.zig` that compile each
  fixture and assert stable diagnostic text.
- [x] Implement `assertEffectFunction` and route `Effect.fromFn` through it.
- [x] Implement `assertMergeFunction` and route `Layer.merge` wrappers through
  it.
- [x] Implement resource failure-set assertions for `acquireRelease` and
  `acquireReleaseValue`.
- [x] Update docs/roadmap status and run full verification.
