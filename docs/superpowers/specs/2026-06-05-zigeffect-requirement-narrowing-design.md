# zigeffect Requirement Narrowing Design

## Goal

Allow app effects to run from a graph-started environment while depending only
on a narrow service set instead of the generated full `LayerGraphEnv`.

## Design

Add `fx.ServiceEnv(.{ ... })`, a small generated environment that stores
pointers to a declared tuple of services and exposes the normal
`service(Service)` method. It is a view, not an owner: services still live in
the graph startup environment and scopes still belong to the runner.

Add explicit graph runner APIs:

- `graph.runNarrowed(.{ ServiceA, ServiceB }, effect)`
- `graph.exitNarrowed(.{ ServiceA, ServiceB }, effect)`

These APIs assert that `effect.EnvType == fx.ServiceEnv(services)`, validate
declared effect requirements against graph providers, build the graph context,
project the requested services into `ServiceEnv`, and execute the effect with
the normal per-run scope.

Keep `graph.run(effect)` strict: it still requires `effect.EnvType` to equal
the generated graph environment. This preserves useful environment mismatch
diagnostics and makes narrowing an intentional boundary.

## Contract

- `ServiceEnv` service tuples use the same service tuple diagnostics as
  `.provides` and `.requires`.
- `runNarrowed` and `exitNarrowed` do not allocate or own service values.
- Per-run finalizers registered by narrowed effects close with the per-run
  scope.
- Graph startup resources remain owned by `graph.deinit()`.

## Tests

Add layer graph tests where a graph provides config, logger, and database, but
the app effect uses `fx.ServiceEnv(.{fixtures.Database})` and runs through
`graph.runNarrowed`. The test proves the effect does not need the full graph
environment type and that startup resources remain graph-owned.
