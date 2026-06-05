# zigeffect Layer.fromEffect Design

## Goal

Add `Layer.fromEffect` as a graph-startup constructor for layers whose startup
logic is already expressed as an effect over a narrowed service environment.

## Design

`LayerWithError(Env, StartupError).fromEffect(effect)` returns an effect-backed
layer. The effect must return `*Env`; its failure set must be compatible with
the layer build error (`Allocator.Error || StartupError`).

The effect environment is expected to be a context-projectable environment such
as `fx.ServiceEnv(.{ fx.Config, fx.Logger })`. During graph startup,
`buildWithContext` projects that environment from the graph startup context,
creates a normal `Context(effect.EnvType)` with the graph startup scope, and
runs the effect.

`fromEffect` preserves effect requirement metadata. A layer created from
`effect.requires(.{ ... })` reports those requirements to graph validation even
before `.requires` is called on the layer.

## Contract

- Effect-backed layers are startup layers. Their finalizers belong to the graph
  startup scope.
- The effect returns the environment pointer owned by the startup scope.
- `Layer.fromBuilder` remains the lower-level constructor for direct allocator
  and scope functions.
- `Layer.fromContextBuilder` remains available for generic `anytype` startup
  builders.

## Tests

Add a graph test where a database layer is built from an effect over
`ServiceEnv(.{ fx.Config, fx.Logger })`, consumes config/logger, registers a
startup finalizer, and is released only on `graph.deinit()`.
