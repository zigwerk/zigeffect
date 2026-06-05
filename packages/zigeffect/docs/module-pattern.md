# zigeffect Module Pattern

Date: 2026-06-05

Use this shape when a feature grows beyond one effect. The goal is predictable
ownership: service contracts, layer startup, effects, tests, and docs live
together, while shared engine behavior stays in `zigeffect` domains.

## Feature Folder Shape

```text
feature/
  service.zig      # service types and environment-facing contracts
  layer.zig        # Layer/LayerWithError builders and provider metadata
  effects.zig      # direct-style effect functions and Effect wrappers
  fixtures.zig     # test-only builders and fake services
  feature_test.zig # focused behavior tests
  README.md        # ownership notes and startup requirements
```

Small features can start with one file. Split only when the boundary becomes
real: a service contract, a startup layer, or shared fixtures.

## Service Contract

Keep service contracts small and explicit:

```zig
pub const Database = struct {
    dsn: []const u8,
};

pub const Env = struct {
    database: Database,

    pub fn service(self: *Env, comptime Service: type) *Service {
        if (Service == Database) return &self.database;
        return fx.serviceNotFound(Env, Service);
    }
};
```

Effects should declare what they need:

```zig
const LoadUser = fx.Effect(User, AppError, AppEnv)
    .fromFn(loadUser)
    .requires(.{ Database, fx.Logger });
```

## Layer Startup

Use `fromContextBuilder` when startup depends on earlier graph services:

```zig
const databaseLayer = fx.LayerWithError(DatabaseEnv, StartupError)
    .fromContextBuilder(buildDatabase)
    .requires(.{ fx.Config, fx.Logger })
    .provides(.{Database});
```

Builder finalizers belong to the graph startup scope. Per-run resources belong
to runtime scopes inside effects.

## App Startup

Validate and start apps through `layerGraph`:

```zig
var graph = fx.layerGraph(allocator, .{
    databaseLayer,
    loggerLayer,
    configLayer,
});
defer graph.deinit();

const report = try graph.report("app startup");
defer allocator.free(report);

try _ = graph.start();
```

Use `graph.run(Program)` for normal app execution. Use `graph.runtime()` or
`graph.fiberRuntime()` when a boundary needs regular runtime or deterministic
fiber APIs over the graph-started environment.

When a program only needs a subset of graph services, type it against
`fx.ServiceEnv(.{ ... })` and run it explicitly through the graph's narrowed
runner:

```zig
const ReadinessEnv = fx.ServiceEnv(.{ Database, fx.Logger });
const Readiness = fx.Effect(bool, AppError, ReadinessEnv)
    .fromFn(checkReadiness)
    .requires(.{ Database, fx.Logger });

const ready = try graph.runNarrowed(.{ Database, fx.Logger }, Readiness);
```

See [`../examples/readiness.zig`](../examples/readiness.zig) for a
compile-checked end-to-end module example with a database contract, startup
effect, graph bootstrap, readiness effect, and fake-service test layers.

Use the scaffold generator when starting a new module:

```bash
cd packages/zigeffect
zig build-exe tools/scaffold_module.zig
./scaffold_module billing Ledger
```

## Tests

Tests should use public contracts:

```zig
var env = try fx.TestEnv.init(std.testing.allocator);
defer env.deinit();

try env.services.config.set("database.dsn", "postgres://test");
try env.expectStructuredLog(.info, "database layer starting");
```

Use `fx.testing` helpers for dependency reports, causes, schedules, structured
logs, histograms, and cleanup assertions. Avoid test-only service lookup paths;
tests should exercise the same `Context` and `Layer` contracts as production.

Use [Resource Ownership](resource-ownership.md) when deciding whether a module
resource belongs to graph startup, one run, a shared runtime scope, or a fiber
child scope.

## Agent Rules

- Start in the folder that owns the behavior.
- Add provider and requirement metadata before relying on graph startup order.
- Keep graph startup resources and per-run resources separate.
- Prefer direct-style functions for business logic; wrap with `Effect` at
  module boundaries.
- Update this module's README when adding services, layers, or startup
  requirements.
