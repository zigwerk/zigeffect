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
- `FiberRuntime` / `Fiber`: deterministic fork, join, interrupt, scoped
  leases, and direct scope-attached forks for Effect-style fiber lifecycle
  semantics.
- `Deferred`, `Queue`, and `Semaphore`: deterministic coordination primitives
  with explicit wait-state/backpressure inspection for tests, tooling, and
  future async backends.
- `Context`: typed service access and scoped finalizer registration.
- `acquireRelease` / `acquireReleaseValue`: typed resource acquisition with
  automatic scope cleanup.
- `Layer`: dependency environment wrapper, scoped dependency builder, provider,
  context-aware dependency builder, provider, and merge helper.
- `LayerWithError`: layer builders with typed startup errors.
- `ServiceSet`, `DependencyReport`, and `LayerGraph`: production DI metadata,
  graph validation, and readable dependency diagnostics.
- `validateRequirements` / `requirementsSatisfiedBy`: compare declared
  requirements against declared providers.
- `layerGraph`: executable heterogeneous layer graph startup with generated
  composite environments, dependency ordering, dependency reports, and memoized
  layer builds, plus regular and fiber runtime adapters for graph-started
  environments.
- `Scope`: reverse-order finalizers, including exit-aware cleanup.
- `Exit` / `Cause`: structured result shapes, plus `CauseTree` for
  allocator-owned recursive cause reports.
- `formatExit` / `formatCause` / `formatObservabilityReport`: readable runtime
  and observability reports for CLIs, tests, and agent workflows.
- `Schedule` / `ScheduleProgram`: retry/repeat timing with `once`, `recurs`,
  `spaced`, `duration`, fixed, exponential, fibonacci, linear, backoff,
  deterministic jitter, and owned recursive schedule composition.
- `CausalStore` / `CausalBackend`: deterministic causal event storage, query
  helpers, report/JSON/DOT/CI formatters, and optional adapter sinks for JSON
  Lines, DOT, OpenTelemetry, embedded graph, durable history, and future async
  streams.
- `TestEnv`: fake clock, memory filesystem, logger, config, metrics, tracing,
  runtime helpers, assertion helpers, and readable assertion report formatters.
- `Clock`: fake/system time service used by schedules and tests.
- `serviceNotFound`: rich compile-time diagnostics for missing environment
  services.

The core fiber runtime is semantic-first and deterministic. It does not claim
real green-thread suspension; a future optional zio adapter will provide the
stackful coroutine and `std.Io` backend.

`zigeffect` now includes the first deterministic agent-observable causal
runtime surface: attach a `CausalStore` to a runtime, fiber runtime, layer
graph, or context, then inspect snapshots, lineage, causes, resources, fibers,
requirements, retries, findings, and reports instead of reconstructing runtime
behavior from logs.

Docs:

- [Usage](docs/usage.md)
- [Architecture](docs/architecture.md)
- [Errors](docs/errors.md)
- [Resource Ownership](docs/resource-ownership.md)
- [EffectTS Parity](docs/effectts-parity.md)
- [Module Pattern](docs/module-pattern.md)
- [Agent-Observable Causal Runtime](docs/agent-observable-runtime.md)
- [Causal Scenario Registry](docs/causal-scenarios.md)
- [Readiness Example](examples/readiness.zig)
- [Causal Readiness Example](examples/causal_readiness.zig)
- [Causal Missing Config Scenario](examples/causal_missing_config.zig)
- [Causal Cleanup Failure Scenario](examples/causal_cleanup_failure.zig)
- [Causal Scoped Fiber Scenario](examples/causal_scoped_fiber.zig)
- [Causal Retry Exhaustion Scenario](examples/causal_retry_exhaustion.zig)
- [Agent Guide](docs/agent-guide.md)
- [Devex Review](docs/devex-review.md)
- [Roadmap](docs/roadmap.md)

Run tests:

```bash
bun run zigeffect:test
```

Compile and test the package examples:

```bash
cd packages/zigeffect
zig build examples
```

Print a sample causal CI report:

```bash
cd packages/zigeffect
zig build causal-report
```

Run the local causal dogfood harness and write agent-readable artifacts:

```bash
cd packages/zigeffect
zig build causal-test
```

The harness writes a text report, JSON event snapshot, and DOT graph under
`.zig-cache/causal-artifacts/`.

Run the failure-gated causal dogfood check:

```bash
cd packages/zigeffect
zig build causal-check
```

`causal-check` writes the same artifacts as `causal-test`, then exits nonzero
when the dogfood fixture contains findings. Use it when a development or CI
agent should treat causal findings as actionable failures.

Print the registered causal scenarios and invariants:

```bash
cd packages/zigeffect
zig build causal-catalog
```

Capture artifacts for a real expected compile-fail scenario:

```bash
cd packages/zigeffect
zig build causal-capture-missing-service
```

Run package tests through the causal development harness:

```bash
cd packages/zigeffect
zig build causal-dev-test
```

`causal-dev-test` exits zero while package tests pass. If package tests fail
during development, it writes scenario-specific artifacts under
`.zig-cache/causal-artifacts/` before exiting nonzero.

Run the two-phase causal development loop around a runtime patch:

```bash
cd packages/zigeffect
zig build causal-dev-loop -- baseline
# make the patch
zig build causal-dev-loop -- after
```

Target a registered scenario when the patch touches a specific subsystem:

```bash
zig build causal-dev-loop -- baseline causal-scoped-fiber
# make the patch
zig build causal-dev-loop -- after causal-scoped-fiber
```

The baseline phase writes
`.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-before.json` and runs the
package-test gate. The after phase writes
`.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-after.json`, writes
`.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-compare.txt`, writes
`.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-queries.txt`, reruns the
package-test gate, and prints the report paths. Scenario targets use
slug-specific before, after, compare, and query-report paths under
`.zig-cache/causal-artifacts/`.

Run a named scenario from the catalog:

```bash
cd packages/zigeffect
zig build causal-run -- causal-scoped-fiber
```

Query the default dogfood JSON artifact:

```bash
cd packages/zigeffect
zig build causal-query -- cause 3
zig build causal-query -- lineage 2
zig build causal-query -- resources 1
zig build causal-query -- fibers pending
zig build causal-query -- requirements 1
zig build causal-query -- retries 1
```

Use `zig build causal-query -- --file <path> <query> [argument]` to inspect a
non-default artifact.

For example:

```bash
zig build causal-query -- --file .zig-cache/causal-artifacts/zigeffect-causal-missing-service-compile-fail.json cause 3
```

Compare two saved causal JSON artifacts:

```bash
cd packages/zigeffect
zig build causal-compare -- .zig-cache/causal-artifacts/before.json .zig-cache/causal-artifacts/after.json
```

The compare report summarizes event count deltas, finding count deltas, added
events, removed events, and changed events. Use it when a fix needs evidence
that the causal trace improved instead of just changed.

Print an agent-friendly module scaffold:

```bash
cd packages/zigeffect
zig build-exe tools/scaffold_module.zig
./scaffold_module billing Ledger
```
