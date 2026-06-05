# zigeffect Examples Design

## Goal

Add a compile-checked example that demonstrates the preferred module and app
startup pattern for zigeffect.

## Design

Create `packages/zigeffect/examples/readiness.zig`.

The example includes:

- A small `Database` service and `DatabaseEnv`.
- A startup effect over `ServiceEnv(.{ fx.Config, fx.Logger })`.
- `Layer.fromEffect` for database startup.
- `ConfigEnv` plus logger layer bootstrap.
- `layerGraph`, `graph.report`, and `graph.runNarrowed`.
- A test that uses `TestEnv` fake service layers and `runNarrowed`.

Wire the example into `packages/zigeffect/build.zig` with an `examples` step.
This keeps examples as executable documentation and gives agents a stable
command to verify them.

## Contract

- Examples must import the public `zigeffect` facade only.
- Example service lookup uses normal `Context` and `serviceNotFound` paths.
- Startup resources belong to graph startup scope and release at graph deinit.
- Test fake services are provided through normal `TestEnv` layers.

## Verification

Run `cd packages/zigeffect && zig build examples`, plus the normal package and
repo verification commands.
