# zigeffect Layer Graph Startup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add automatic heterogeneous layer graph construction and memoized startup for `zigeffect`.

**Architecture:** Layer declarations become typed wrappers that preserve compile-time service lists. A new graph runtime builds a tuple of heterogeneous layers once, validates metadata, creates a generated composite environment, and runs effects through the existing runtime.

**Tech Stack:** Zig 0.16, `zigeffect`, `bun run zigeffect:test`.

---

## File Structure

- Modify `packages/zigeffect/src/zigeffect.zig`: typed declaration wrappers, composite graph environment, graph runtime, and validation/startup helpers.
- Modify `packages/zigeffect/test/core_test.zig`: TDD coverage for composition, memoization, validation failures, and startup errors.
- Modify `packages/zigeffect/README.md`: public surface summary.
- Modify `packages/zigeffect/docs/usage.md`: graph runtime usage example.
- Modify `packages/zigeffect/docs/effectts-parity.md`: mark automatic graph construction as implemented for the current scope.
- Modify `packages/zigeffect/docs/errors.md`: graph startup diagnostics.

## Tasks

### Task 1: Typed graph composition tests

- [ ] Add test helper layer environments for logger, config, metrics, and app service in `packages/zigeffect/test/core_test.zig`.
- [ ] Add a failing test named `layer graph automatically composes heterogeneous declared layers`.
- [ ] Run `bun run zigeffect:test` and confirm the failure is caused by missing `fx.layerGraph`.
- [ ] Implement typed declaration wrappers and graph environment routing in `packages/zigeffect/src/zigeffect.zig`.
- [ ] Run `bun run zigeffect:test` and confirm the new test passes.

### Task 2: Memoized startup tests

- [ ] Add counters to graph test builders.
- [ ] Add a failing test named `layer graph memoizes started layers across runs`.
- [ ] Run `bun run zigeffect:test` and confirm the graph rebuilds or the method is missing.
- [ ] Implement graph `start`, `run`, and `deinit` memoization.
- [ ] Run `bun run zigeffect:test` and confirm the memoization test passes.

### Task 3: Validation failure tests

- [ ] Add a failing test named `layer graph rejects invalid dependencies before startup`.
- [ ] Cover duplicate providers and missing layer requirements.
- [ ] Run `bun run zigeffect:test` and confirm invalid graphs are not rejected yet.
- [ ] Wire graph validation into `start` and return existing `DependencyError` values.
- [ ] Run `bun run zigeffect:test` and confirm validation tests pass.

### Task 4: Startup error propagation tests

- [ ] Add a failing test named `layer graph preserves typed startup errors`.
- [ ] Run `bun run zigeffect:test` and confirm typed layer errors are not yet part of graph startup.
- [ ] Union member layer `StartupErrorType` values into graph startup errors.
- [ ] Run `bun run zigeffect:test` and confirm startup error propagation passes.

### Task 5: Documentation and full verification

- [ ] Update README and docs with the new graph runtime API.
- [ ] Run `bun run zigeffect:test`.
- [ ] Run `bun run zig:test`.
- [ ] Report exact verification results.
