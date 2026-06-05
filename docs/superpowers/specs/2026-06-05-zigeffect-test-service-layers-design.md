# zigeffect Test Service Layers Design

## Goal

Make fake-service injection ergonomic by exposing reusable `TestEnv` layer
builders for common test services.

## Design

Add `TestEnv.serviceLayer(.{ ... })`, which returns the normal
`Layer(TestServices).fromEnv(&env.services).provides(services)` shape.

Add named helpers:

- `loggerLayer()`
- `configLayer()`
- `metricsLayer()`
- `tracingLayer()`
- `fileSystemLayer()`
- `clockLayer()`

These helpers are convenience wrappers only. They do not create alternate
service lookup semantics and do not own separate service instances.

## Contract

- All helpers return normal layer values, so they compose with `LayerGraph`,
  `validateRequirements`, `.requires`, `.replaces`, and `graph.run`.
- Service values remain owned by `TestEnv`.
- Tests can still use `env.layer()` when they want the full fake environment.

## Tests

Add tests that use named helpers to satisfy dependency validation and to run a
small graph with logger/config layers.
