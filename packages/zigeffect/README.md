# zigeffect

`zigeffect` is a Zig-native Effect-inspired core for composing direct-style Zig
programs.

The center of the API is still normal Zig:

```zig
fn program(ctx: *fx.Context(fx.TestServices)) AppError!Result {
    const logger = ctx.service(fx.Logger);
    try logger.info("running");
    return .{};
}
```

Wrap direct-style functions when you want composition, retry, scoped resources,
or test environments:

```zig
const Program = fx.Effect(Result, AppError, fx.TestServices).fromFn(program);
const result = try Program
    .map(Other, mapResult)
    .tap(recordTelemetry)
    .retry(&ctx, &schedule);
```

Included in this package:

- `Effect`: `fromFn`, `succeed`, `fail`, `sync`, `run`, `exit`, `retry`,
  `repeat`, `map`, `flatMap`, `tap`, `onExit`, `ensuring`, and recovery
  helpers.
- `Runtime`: runs effects with engine-managed scopes and automatic cleanup on
  success or failure, with optional service requirement gates.
- `FiberRuntime` / `Fiber`: deterministic fork, join, interrupt, and scoped
  leases for Effect-style fiber lifecycle semantics.
- `Deferred`, `Queue`, and `Semaphore`: deterministic coordination primitives
  for tests, tooling, and future async backends.
- `Context`: typed service access and scoped finalizer registration.
- `acquireRelease`: typed resource acquisition with automatic scope cleanup.
- `Layer`: dependency environment wrapper, scoped dependency builder, provider,
  and merge helper.
- `LayerWithError`: layer builders with typed startup errors.
- `ServiceSet`, `DependencyReport`, and `LayerGraph`: production DI metadata,
  graph validation, and readable dependency diagnostics.
- `layerGraph`: executable heterogeneous layer graph startup with generated
  composite environments, dependency ordering, and memoized layer builds.
- `Scope`: reverse-order finalizers, including exit-aware cleanup.
- `Exit` / `Cause`: structured result shapes.
- `formatExit` / `formatCause`: readable runtime reports for CLIs, tests, and
  agent workflows.
- `Schedule`: retry/repeat timing with `once`, `recurs`, `spaced`, `duration`,
  fixed, exponential, fibonacci, linear, backoff, and deterministic jitter
  policies.
- `TestEnv`: fake clock, memory filesystem, logger, config, metrics, tracing,
  runtime helpers, and assertion helpers.
- `Clock`: fake/system time service used by schedules and tests.
- `serviceNotFound`: rich compile-time diagnostics for missing environment
  services.

The core fiber runtime is semantic-first and deterministic. It does not claim
real green-thread suspension; a future optional zio adapter will provide the
stackful coroutine and `std.Io` backend.

Docs:

- [Usage](docs/usage.md)
- [Errors](docs/errors.md)
- [EffectTS Parity](docs/effectts-parity.md)
- [Agent Guide](docs/agent-guide.md)
- [Devex Review](docs/devex-review.md)
- [Roadmap](docs/roadmap.md)

Run tests:

```bash
bun run zigeffect:test
```
