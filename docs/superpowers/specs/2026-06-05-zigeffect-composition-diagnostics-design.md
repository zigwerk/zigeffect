# zigeffect Composition Diagnostics Design

Date: 2026-06-05

## Goal

Close the next concrete gap in roadmap section 1 by adding package-owned
compile-time diagnostics for common composition mistakes:

- invalid `Effect.fromFn` function shapes
- invalid `Layer.merge` combine function shapes
- resource error sets that cannot represent scope/allocation failures

## Contracts

- Diagnostics should contain stable `zigeffect ...` messages that compile-fail
  fixtures can assert.
- Existing valid call sites must keep their current ergonomics.
- Assertions stay close to the owning API:
  - effect function checks in `src/effect/effect.zig`
  - merge function checks in `src/layer/layer.zig`
  - resource failure-set checks in `src/effect/resource.zig`

## Non-Goals

- No full type-level requirement algebra in this slice.
- No broad rewrite of combinator wrappers.
- No attempt to replace every Zig native type error.

## Tests

- `test/compile_fail/invalid_effect_function.zig` checks
  `zigeffect invalid effect function`.
- `test/compile_fail/invalid_layer_merge.zig` checks
  `zigeffect invalid layer merge function`.
- `test/compile_fail/invalid_resource_error_set.zig` checks
  `zigeffect resource failure set`.
