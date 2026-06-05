# zigeffect Runtime Graph Cohesion Design

Date: 2026-06-05

## Goal

Deliver the next roadmap slice for runtime, scope, and fiber cohesion without
turning the deterministic runtime into an async scheduler. A started
`layerGraph` should be usable through the existing `Runtime` and `FiberRuntime`
APIs while preserving declared dependency validation and the existing scope
ownership rules.

## Contracts

- `graph.run(effect)` remains the preferred one-shot production path for effects
  backed by a graph-started environment.
- `graph.runtime()` returns a regular `Runtime(GraphEnv)` backed by the memoized
  graph environment. It should validate effect requirements against the graph's
  declared providers.
- `graph.fiberRuntime()` returns a `FiberRuntime(GraphEnv)` backed by the same
  graph environment. It should validate forked effect requirements against the
  graph's declared providers.
- Graph startup resources live in the graph startup scope and are released on
  `graph.deinit()`.
- Per-run resources live in the runtime/fiber parent scope used for that run.
- A scoped child fiber belongs to its parent scope; closing the parent scope
  interrupts unfinished children without releasing graph startup resources.

## Architecture

- Add a provider-backed service metadata hook in `src/dependency/services.zig`.
  Runtimes can use it to delegate `providedServices` to any object that exposes
  `providedServices(allocator)`.
- Add `withProvider(provider_pointer)` to `Runtime` and `FiberRuntime`.
  It stores an opaque pointer plus the provider metadata adapter, leaving the
  existing `.provides(.{ ... })` path intact for static runtimes.
- Add `runtime()` and `fiberRuntime()` to `LayerGraphRuntime`. Both call
  `start()` and then return a runtime with the graph as its provider metadata
  source.
- Avoid a shared execution abstraction for now. The current `run`/`exit` bodies
  are small and type-heavy; introducing an abstraction before graph/fiber usage
  is pinned would add churn without reducing risk.

## Tests

- A graph-started environment runs through `graph.runtime()` and validates
  effect requirements against graph providers.
- A graph-started environment runs through `graph.fiberRuntime()` and validates
  forked effect requirements against graph providers.
- Closing a parent scope for a graph-backed `FiberRuntime` interrupts an
  unfinished scoped child while leaving graph startup resources alive until
  `graph.deinit()`.
