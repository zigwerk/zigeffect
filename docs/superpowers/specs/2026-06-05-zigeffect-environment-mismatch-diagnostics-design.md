# zigeffect Environment Mismatch Diagnostics Design

## Goal

Add stable compile-time diagnostics when public runner APIs receive an effect
whose `EnvType` does not match the layer, runtime, graph runtime, or fiber
runtime environment.

## Design

Environment compatibility is a dependency contract, so the shared assertion
lives in `packages/zigeffect/src/dependency/contracts.zig`. The helper receives
the API name, expected environment type, and effect value. It verifies that the
effect type exposes `EnvType` and that it equals the expected environment.

Runner entry points call the helper before runtime dependency validation:

- `Layer.provide` wrappers
- `MergeLayer.provide`
- `Runtime.run` and `Runtime.exit`
- `FiberRuntime.fork`
- `LayerGraphRuntime.run` and `LayerGraphRuntime.exit`

`FiberRuntime.forkScoped` uses `fork`, so the same check covers scoped forks.
The helper does not change service requirement validation; it only catches the
wrong environment type earlier with a consistent message.

## Contract

The diagnostic starts with `zigeffect environment mismatch`, includes the API
name, expected environment type, and actual effect environment type, and tells
callers to run the effect with the matching layer/runtime or adapt the effect to
the target environment.

## Tests

Add compile-fail fixtures for:

- `Layer.provide` with a mismatched effect environment.
- `Runtime.run` with a mismatched effect environment.
- `FiberRuntime.fork` with a mismatched effect environment.

The existing compile-fail harness asserts the stable diagnostic header and API
names.
