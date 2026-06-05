# zigeffect Graph/Fiber Scope Cohesion Design

Date: 2026-06-05

## Goal

Make the parent/child relationship between graph startup scopes and fibers
explicit and easy to test.

## Design

Add `FiberRuntime.forkInScope(scope, effect)`. It forks an effect and registers
the same interrupting lease that `forkScoped(ctx, effect)` uses, but it accepts
the parent `Scope` directly. `forkScoped` becomes a convenience wrapper that
extracts `ctx.scope` and delegates to `forkInScope`.

This keeps all child-fiber cleanup on the existing `Scope` finalizer machinery:

- graph startup fibers can be attached to the graph startup scope
- per-run fibers can still be attached to a per-run context scope
- parent-scope close interrupts unfinished children before owner finalizers run,
  when the owner registers its finalizer before forking

## Tests

Add a layer graph test where a graph-provided service starts a pending fiber
during startup with `forkInScope(&startup_scope, ChildEffect)`. On
`graph.deinit()`, the startup scope closes and interrupts that unfinished child
before the service runtime is released.

## Non-Goals

- Do not add async scheduling or real suspension.
- Do not change deterministic `join` semantics.
- Do not add supervision trees yet; this is the scope lease primitive they can
  build on.
