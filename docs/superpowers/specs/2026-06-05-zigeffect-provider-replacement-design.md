# zigeffect Provider Replacement Design

## Goal

Add an explicit graph-boundary replacement contract for layer providers. Duplicate
providers remain invalid by default, but a layer can opt in to replacing an
already-provided service with `.replaces(.{ Service })`.

## Chosen Approach

Use the existing metadata wrapper pattern. Layers already expose
`providedServices` and `requiredServices`; replacement adds a third metadata
set, `replacedServices`, and a fluent `.replaces(.{ ... })` wrapper.

This keeps provider ownership in the dependency/layer domain instead of making
`LayerGraphRuntime` special-case concrete layer types.

## Contract

- `.replaces(.{Service})` uses the same service tuple validation as `.provides`
  and `.requires`.
- Duplicate providers are still reported unless the later provider declares the
  duplicated service in `replaces`.
- Replacement is graph-local metadata. It affects layer graph validation and
  generated graph service lookup; it does not mutate individual layer behavior.
- Executable graph environments resolve a duplicated service to the latest
  built replacement provider.
- Startup builder contexts use the latest built provider too, so a builder that
  depends on a replaced service observes the replacement after it has started.

## Implementation Shape

- Add `replacedServices(allocator)` to the layer metadata protocol.
- Add `ReplacementLayer(Inner, Replaced)` in `src/layer/layer.zig`.
- Add `.replaces` methods to base, context-builder, provided, required, and
  merge layer wrappers.
- Extend `LayerGraph.Node` with `replaces`.
- Update `LayerGraph.validate` so a later duplicate provider is accepted when
  the later node declares it replaces that service.
- Update generated graph service lookup to scan providers from last to first.
- Update startup context service lookup to scan the last built provider first.

## Tests

- Existing duplicate-provider tests continue to fail without replacement.
- A manual `LayerGraph` with base and replacement providers validates cleanly.
- `layerGraph.run` reads the replacement config provider, not the base provider.
- A dependency-injected database layer built after a replacement config reads
  the replacement config during startup.
