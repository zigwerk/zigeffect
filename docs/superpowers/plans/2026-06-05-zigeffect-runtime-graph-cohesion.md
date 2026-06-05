# zigeffect Runtime Graph Cohesion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans
> and keep tests red/green around each task.

**Goal:** Make graph-started environments runnable through regular and fiber
runtimes while preserving provider contracts and scope ownership.

**Architecture:** Provider metadata adapters live in `src/dependency/services.zig`.
`Runtime` and `FiberRuntime` can opt into provider-backed validation through
`withProvider`. `LayerGraphRuntime` exposes `runtime()` and `fiberRuntime()`.

**Verification:** `bun run zigeffect:test`, `bun run zig:test`,
`bun run typecheck`.

## Tasks

- [x] Add failing tests in `packages/zigeffect/test/layer_test.zig` for
  `graph.runtime()`, `graph.fiberRuntime()`, and scoped child interruption over
  graph-started resources.
- [x] Add provider metadata adapter helpers to
  `packages/zigeffect/src/dependency/services.zig`.
- [x] Add `withProvider` and provider-backed `providedServices` to
  `packages/zigeffect/src/runtime/runtime.zig`.
- [x] Add `withProvider` and provider-backed `providedServices` to
  `packages/zigeffect/src/runtime/fiber.zig`.
- [x] Add `runtime()` and `fiberRuntime()` helpers to
  `packages/zigeffect/src/layer/graph.zig`.
- [x] Update docs for graph/runtime/fiber lifecycle boundaries.
- [x] Run full verification.
