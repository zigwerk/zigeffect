# zigeffect Layer Graph Startup Design

Date: 2026-06-05

## Goal

Make `zigeffect` layer declarations executable, not only validateable. Production
callers should be able to pass a heterogeneous tuple of declared layers, validate
the graph, start each layer once, and run effects against an automatically
composed environment without hand-written merge environments.

## Architecture

The existing `Layer`, `LayerWithError`, `MergeLayer`, `ServiceSet`, and
`LayerGraph` APIs remain. `Layer.provides` and `Layer.requires` become typed
declaration wrappers so compile-time service lists are available to graph
composition while the existing runtime validation APIs keep returning
`ServiceSet` diagnostics.

The new graph runtime accepts a tuple of heterogeneous layers. It validates
duplicate providers and missing requirements before startup, derives a
topological build order from declared services, builds each layer once, and
stores the resulting environment pointers in a generated composite environment.
The composite `service(Service)` method routes to the one declared provider for
that service, preserving Zig compile-time service lookup.

Startup is memoized at the graph runtime boundary. The first call to `start`,
`context`, or `run` builds the graph and owns the startup `Scope`. Later calls
reuse the same started environment until `deinit`, which closes the startup
scope and releases resources.

## API Shape

```zig
var graph = fx.layerGraph(std.testing.allocator, .{
    loggerLayer.provides(.{fx.Logger}),
    configLayer.provides(.{fx.Config}),
    appLayer.requires(.{ fx.Logger, fx.Config }).provides(.{AppService}),
});
defer graph.deinit();

const value = try graph.run(AppProgram);
```

`fx.layerGraph(allocator, layers)` returns a typed runtime value. Its main
methods are:

- `validate(allocator)`: returns `DependencyReport`.
- `start()`: validates and builds once, returning the started graph.
- `run(effect)`: validates effect requirements against graph providers, starts
  if needed, and runs through a normal `Runtime`.
- `context(scope)`: creates a context for advanced callers with a supplied
  effect scope.

## Validation And Startup Ordering

Graph validation keeps the current semantics:

- duplicate declared providers are reported before startup
- missing layer requirements are reported before startup
- effect requirements are validated before an effect runs

Build order is derived from declarations. A layer can start when all of its
declared requirements have been provided by already-started layers. Independent
layers keep tuple order. If the metadata validates globally but cannot be ordered
incrementally, startup returns `error.MissingServiceRequirement`.

## Error Handling

Graph startup preserves typed layer startup errors by unioning each layer's
`StartupErrorType` with allocator and dependency errors. Validation failures
return the existing `DependencyError` variants:

- `error.MissingServiceRequirement`
- `error.DuplicateServiceProvider`

## Testing

Tests cover:

- automatic heterogeneous graph composition and effect execution
- memoized startup builds each layer once across multiple runs
- graph startup rejects duplicate providers before building
- graph startup rejects unsatisfied requirements before building
- typed startup errors from member layers propagate through graph startup

## Scope

This increment does not add dependency-injected layer builders that receive a
context from previously-started layers. Existing builders still take
`(Allocator, *Scope)`; declared requirements drive validation and startup order.
