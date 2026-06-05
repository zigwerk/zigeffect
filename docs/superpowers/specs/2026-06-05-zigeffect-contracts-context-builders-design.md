# zigeffect Contracts And Context Builders Design

Date: 2026-06-05

## Goal

Deliver roadmap sections 1-3 on top of the new `zigeffect` architecture:

- harden common public API misuse paths
- make service requirements and provider declarations easier to compare
- add graph-level dependency reports
- add dependency-injected layer builders that can consume services already
  started by `layerGraph`

The milestone preserves the existing direct-style user boundary and does not
change current `Layer.fromBuilder` behavior.

## Scope

This milestone owns:

- service tuple validation for `.provides`, `.requires`, `ServiceSet.fromTypes`,
  runtime providers, and graph layer declarations
- helper APIs for checking declared requirements against declared providers
- `LayerGraphRuntime.report(label)`
- `Layer.fromContextBuilder` and `LayerWithError.fromContextBuilder`
- graph startup contexts for dependency-injected builders
- typed startup error preservation and partial-startup cleanup
- focused invariant tests and compile-fail diagnostics

This milestone does not add provider override/replacement APIs. Duplicate
providers remain invalid by default. It also does not start runtime/fiber
cohesion work from roadmap section 4.

## Public API

Service declarations keep the existing ergonomic tuple shape:

```zig
const logger_layer = fx.Layer(LoggerEnv)
    .fromEnv(&logger_env)
    .provides(.{fx.Logger});

const database_layer = fx.LayerWithError(DatabaseEnv, StartupError)
    .fromContextBuilder(buildDatabaseEnv)
    .requires(.{ fx.Config, fx.Logger })
    .provides(.{Database});
```

Malformed declarations fail with package-owned compile errors. Stable message
fragments should include:

- `zigeffect service tuple must be a tuple`
- `zigeffect service tuple entries must be types`

Requirement helpers live under both the root facade and the dependency
namespace:

```zig
var report = try fx.validateRequirements(allocator, provider, consumer);
defer report.deinit();

const ok = try fx.requirementsSatisfiedBy(allocator, provider, consumer);
```

`provider` can be a layer, runtime, or graph runtime. `consumer` can be an
effect or layer. The helper uses existing `providedServices` and
`requiredServices` declarations where available, and returns normal
`DependencyReport` diagnostics for dynamic callers.

Graph runtimes can format their own validation report:

```zig
const report = try graph.report("app startup");
defer allocator.free(report);
```

## Context Builder API

`fromContextBuilder` takes a comptime function value. The builder receives the
allocator, the graph startup scope, and a generated graph-startup context:

```zig
fn buildDatabaseEnv(
    allocator: std.mem.Allocator,
    scope: *fx.Scope,
    ctx: anytype,
) (std.mem.Allocator.Error || StartupError)!*DatabaseEnv {
    const config = ctx.service(fx.Config);
    const logger = ctx.service(fx.Logger);
    try logger.info("starting database");

    const env = try allocator.create(DatabaseEnv);
    errdefer allocator.destroy(env);
    env.* = try DatabaseEnv.connect(config);
    try scope.addFinalizerFor(DatabaseEnv, env, releaseDatabaseEnv);
    return env;
}
```

The builder can use `anytype` for the context parameter while still accessing
services through `Context.service`. This keeps builder declarations independent
from generated graph environment types.

Graph startup calls every layer through `buildWithContext`. Normal
`fromBuilder` and `fromEnv` layers ignore the startup context. Context-builder
layers use it.

## Graph Startup Context

During startup, `LayerGraphRuntime` maintains:

- the tuple of started environment pointers
- a parallel `built` flag array
- the existing graph startup `Scope`

It exposes a startup-only environment whose `service(Service)` method returns a
service only when the provider layer has already started. If a builder requests
a service that is provided by a later layer, startup panics with a clear message
because metadata allowed a builder to ask for something not declared as ready.
If a service is not provided by the graph at all, the existing `serviceNotFound`
compile-time diagnostic is used.

Metadata validation remains the preflight gate. A context builder should only be
called after its declared requirements are satisfied by already-started layers.

## Error Handling And Cleanup

Typed startup errors remain typed through `Layer.provide`,
`LayerGraphRuntime.start`, and `LayerGraphRuntime.run`.

If a context builder fails:

- already-started graph dependencies close through the graph startup scope
- finalizers observe a failure exit with the startup error name
- the graph resets its startup scope
- the typed startup error is returned to the caller

Per-run scopes remain independent. Context-builder finalizers are graph startup
finalizers, not per-run finalizers.

## Tests

Use TDD for each behavior.

Required tests:

- `dependency_test.zig`: `validateRequirements` and
  `requirementsSatisfiedBy` report satisfied/missing requirements.
- `layer_test.zig`: `graph.report("app startup")` formats valid and invalid
  graph diagnostics.
- `layer_test.zig`: a database layer consumes `Config` and `Logger` during
  graph startup through `fromContextBuilder`.
- `layer_test.zig`: context-builder resources release on `graph.deinit`, not
  after a single `graph.run`.
- `layer_test.zig`: context-builder startup failures preserve typed startup
  errors and close already-started dependencies.
- `invariants_test.zig`: scope close idempotence/order, graph validation before
  startup, fiber scoped interruption cleanup, and runtime finalizer ordering.
- `compile_fail/invalid_service_tuple.zig`: malformed declarations show stable
  package-owned compile diagnostics.

Existing architecture, effect, scope, runtime, fiber, layer, schedule, services,
and compile-fail tests must continue passing.

## File Ownership

- `src/dependency/services.zig`: service tuple assertions.
- `src/dependency/validation.zig`: requirement comparison helpers.
- `src/dependency/report.zig`: existing report formatting remains the shared
  diagnostic language.
- `src/layer/layer.zig`: context-builder layer type and wrapper delegation.
- `src/layer/graph.zig`: startup context, `buildWithContext`, graph report.
- `src/zigeffect.zig`: facade aliases only.
- `test/dependency_test.zig`, `test/invariants_test.zig`, `test/layer_test.zig`,
  and compile-fail fixtures: coverage.

## Documentation

Update:

- `packages/zigeffect/README.md`
- `packages/zigeffect/docs/usage.md`
- `packages/zigeffect/docs/errors.md`
- `packages/zigeffect/docs/effectts-parity.md`
- `packages/zigeffect/docs/roadmap.md`

The docs should show the preferred graph startup path and clarify that
context-builder resources belong to graph startup scope.

## Verification

Required:

```bash
bun run zigeffect:test
bun run zig:test
bun run typecheck
```

The broader roadmap goal remains active after this milestone.
