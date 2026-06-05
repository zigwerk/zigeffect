# zigeffect Common Runner Path Design

## Goal

Reduce duplicated managed-scope execution logic across `Runtime`, `Layer`, and
`LayerGraphRuntime`.

## Design

Add `src/runtime/runner.zig` with two helpers:

- `runManagedScope(api, Env, ctx, scope, effect)`
- `exitManagedScope(api, Env, ctx, scope, effect)`

Each helper performs the environment assertion, runs the effect, closes the
provided scope with success/failure/finalizer exit semantics, and preserves
cleanup failure reporting for exit paths.

Context construction remains in the calling runtime/layer/graph because that is
where environment pointers, clocks, trace context, and graph startup state are
known.

## Contract

- `Runtime.run` with an owned per-run scope uses the helper.
- `Runtime.run` with `withScope` remains explicit because the caller owns the
  shared scope.
- `Layer.provide`, `MergeLayer.provide`, `LayerGraphRuntime.run`,
  `runNarrowed`, `Runtime.exit`, `LayerGraphRuntime.exit`, and `exitNarrowed`
  use the helper.
- Behavior should remain unchanged.

## Verification

This is a refactor. Existing scope, runtime, layer, graph, finalizer, trace
context, and compile-fail tests are the compatibility suite.
