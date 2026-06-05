# zigeffect Roadmap

Date: 2026-06-05

This roadmap tracks `zigeffect` as a Zig-native Effect-inspired engine. The goal
is not API cloning. The goal is a production-grade Zig shape for direct-style
programs, typed errors, service requirements, scoped resources, dependency
layers, testing, and eventually async runtime semantics.

## Current Assessment

`zigeffect` now works as a small synchronous Zig effect engine. It captures the
Effect architecture shape, but it is not yet a full Effect-grade runtime.

What is real today:

- Dependency injection gates work.
- Layer startup and teardown work.
- Heterogeneous graph startup works and memoizes within the graph runtime.
- Typed Zig errors are preserved.
- Scoped cleanup is deterministic.
- Deterministic fiber lifecycle semantics exist for `fork`, `join`,
  `interrupt`, scoped leases, and coordination primitives.
- Tests cover these paths.

What is not Effect-grade yet:

- The fiber runtime is deterministic and semantic-first, not a real async
  scheduler with green-thread suspension or blocking-IO interruption.
- `requires` is metadata plus validation, not a fully type-level requirement
  algebra.
- Layer builders cannot consume previously built services through a graph
  context yet.
- `Cause` is a useful reporting shape, not the full Effect failure algebra.
- `Schedule` is a practical delay policy set, not a compositional schedule
  algebra.
- Logger, config, metrics, and tracing are still test-oriented service stubs,
  not production observability.

## Engine Integration Invariants

Every deeper engine change should preserve these rules:

- `Effect` stays direct-style Zig at the user boundary. Runtime complexity
  should not leak into normal program bodies.
- `Context` is the only service access path. Layers, runtimes, fibers, and test
  helpers should all construct or pass contexts rather than inventing parallel
  service lookup mechanisms.
- `Scope` owns cleanup. Runtime scopes, graph startup scopes, fiber scopes, and
  test scopes must all close through the same finalizer machinery.
- `Exit` and `Cause` are the shared result language. Runtime, fiber, layer,
  schedule, and cleanup failures should all converge there instead of each
  subsystem formatting one-off errors.
- Dependency validation happens before startup or execution when requirements
  are declared. A layer graph should not partially start when metadata already
  proves it is invalid.
- Long-lived dependencies belong to graph/runtime startup scopes. Per-run
  resources belong to per-run scopes. Fiber children belong to child scopes
  linked to their parent lifetime.
- The deterministic core remains testable without threads, IO, or wall-clock
  time. Optional async backends can add suspension and IO integration later, but
  must obey the same `Scope`, `Exit`, `Cause`, and service contracts.
- Test services should exercise the same public contracts as production
  services. Avoid special test-only semantics that make production behavior
  weaker.

## Finished

### Core Effect Shape

- Direct-style programs: `fn(ctx) Error!A`.
- `Effect(Success, Failure, Env).fromFn`.
- Constructors: `succeed`, `fail`, `sync`.
- Combinators: `map`, `flatMap`, `tap`.
- Recovery helpers: `mapError`, `catchAll`, `orElse`, `tapError`.
- Lifecycle hooks: `onExit`, `ensuring`.
- Runtime execution through `run` and `exit`.

### Context And Services

- Typed `Context(Env)` service lookup.
- Custom environment `service(Service)` methods.
- Package-owned `serviceNotFound` compile-time diagnostics.
- `Effect.requires` metadata for production dependency gates.
- `Runtime.provides` and layer provider declarations.

### Scope And Resources

- `Scope` with reverse-order finalization.
- Typed finalizers.
- Fallible finalizers with recorded cleanup failures.
- Exit-aware finalizers through `FinalizerExit`.
- `acquireRelease` for scoped pointer resources.
- Runtime-managed scope close on success and failure.

### Runtime Result Model

- `Exit` for success, typed failure, defect, interruption, and cause.
- `Cause` shape for failures, defects, interruption, cleanup failure, and nested
  cause variants.
- `formatExit` and `formatCause` for readable CLI/test/agent reports.

### Fiber Lifecycle And Coordination

- `FiberId` and `FiberStatus`.
- `FiberRuntime` and typed `Fiber` handles.
- Deterministic `fork`, `join`, and `interrupt`.
- `forkScoped` leases that interrupt unfinished child fibers when a parent scope
  closes.
- Child scope cleanup with success, failure, or interruption exits.
- `Deferred`, `Queue`, and `Semaphore` coordination primitives.

### Layers And DI

- `Layer.fromEnv`.
- `Layer.fromBuilder`.
- `Layer.provide`.
- `Layer.merge`.
- `LayerWithError` for typed startup failures.
- `ServiceSet`, `DependencyReport`, and `LayerGraph` metadata validation.
- Duplicate provider and missing requirement diagnostics.
- Executable `layerGraph` for heterogeneous layer tuples.
- Automatic graph validation before startup.
- Dependency-ordered graph startup from declarations.
- Memoized graph startup until graph deinit.
- Generated composite graph environment with typed service dispatch.

### Schedule And Test Support

- Retry/repeat policies: `once`, `recurs`, `spaced`, `duration`, `fixed`,
  `repeat`, `exponential`, `fibonacci`, `linear`, `backoff`,
  `jitteredBackoff`.
- Fake/system `Clock`.
- `TestEnv` with logger, config, metrics, tracing, memory filesystem, fake
  clock, runtime helpers, and assertions.

### Documentation And Verification

- Usage guide.
- Error guide.
- EffectTS parity notes.
- Agent guide.
- Devex review.
- Focused Zig tests for core effect behavior, scopes, layers, graph startup,
  schedules, diagnostics, and test services.

## Delivery Roadmap

### 1. Engine Invariants And Public API Hardening

Goal: make the current engine harder to misuse before adding deeper semantics.

- Add compile-time assertions for common composition mistakes:
  mismatched environments, invalid effect function shapes, invalid layer merge
  combine functions, and missing resource error-set members.
- Improve compile errors for `Layer.provides`, `Layer.requires`, and
  `layerGraph` when callers pass malformed service tuples.
- Add dependency report helpers for graph runtimes, including a direct formatted
  `graph.report("app startup")` style API.
- Add a small internal invariants test suite for scope close behavior, graph
  validation before startup, fiber interruption cleanup, and runtime finalizer
  ordering.
- Add tests for compile-time diagnostics where Zig can expose stable messages.

### 2. Requirement Algebra And Provider Contracts

Goal: make requirements more than loose metadata while staying Zig-native.

- Preserve current `requires(.{ ... })` ergonomics.
- Add typed helpers that can compare effect requirements against layer/runtime
  providers at compile time when both sides are known.
- Add provider ownership diagnostics: one provider per service inside a graph,
  with explicit override/replacement APIs only when a graph boundary asks for
  them.
- Add requirement narrowing for generated graph environments so app effects do
  not have to depend on every service in the graph.
- Keep dynamic `DependencyReport` output for CLIs and agents.

### 3. Dependency-Injected Layer Builders

Goal: make `layerGraph` behave more like real Effect layers, where layer
constructors can consume services built by earlier layers.

- Add `Layer.fromEffect` or `Layer.fromContextBuilder`.
- Let a layer builder receive `Context(GraphEnvSoFar)` or a narrower generated
  dependency context.
- Preserve typed startup errors and scoped cleanup.
- Keep metadata validation as the preflight gate.
- Add tests where `DatabaseLayer` consumes `Config` and `Logger` during startup.
- Ensure layer-builder contexts can register finalizers into the graph startup
  scope, not the caller's per-run scope.
- Define how builder failures close already-started dependencies.

### 4. Runtime, Scope, And Fiber Cohesion

Goal: make `Runtime`, `FiberRuntime`, and `LayerGraphRuntime` feel like one
engine rather than three runners.

- Share context construction rules across runtime types.
- Add a common internal runner path for scope creation, effect execution,
  finalizer close, and `Exit` conversion where Zig's types allow it.
- Make graph-started environments runnable through both regular runtime and
  fiber runtime paths.
- Define parent/child relationships between graph startup scopes, per-run
  scopes, and fiber scopes.
- Add tests where a graph-provided service starts a fiber and cleanup interrupts
  unfinished child work deterministically.

### 5. Resource Model Expansion

Goal: make resource handling useful beyond heap-allocated pointer resources.

- Add value-resource acquisition helpers where safe.
- Add explicit long-lived runtime scopes for applications that need shared
  lifecycle boundaries.
- Add better cleanup failure reporting when both the program and finalizer fail.
- Add tests for nested resources, repeated acquisition, and cleanup ordering
  across graph startup plus per-run scopes.
- Add resource ownership docs for graph startup resources, per-run resources,
  and fiber-owned resources.

### 6. Cause And Exit Hardening

Goal: make runtime result reporting closer to Effect’s failure model.

- Replace pointer-backed recursive cause links with an owned representation for
  runtime-generated nested causes.
- Represent combined program failure plus cleanup failure safely.
- Represent interruption cause consistently across runtime and fiber paths.
- Add richer interruption and defect helpers.
- Add cause assertions for tests.
- Keep Zig error sets as expected failures.

### 7. Schedule Algebra And Clock Integration

Goal: move schedules from useful policies to composable schedule programs.

- Add schedule composition operators.
- Add jitter, timeout, reset, union/intersection-style policy composition where
  useful.
- Add schedule state inspection for tests.
- Make schedules run through `Clock` and fiber/runtime sleep hooks rather than
  hand-advancing time in isolated helpers.
- Keep deterministic fake-clock behavior.

### 8. Coordination Primitives And Backpressure

Goal: make `Deferred`, `Queue`, and `Semaphore` useful with the deterministic
fiber core and future async backend.

- Define blocking semantics for deterministic mode: immediate status/errors
  today, suspend/resume through a backend later.
- Add queue shutdown/interruption behavior.
- Add semaphore scoped permits that release on scope close.
- Add tests for producer/consumer workflows under deterministic fibers.

### 9. Config Service

Goal: move from a test map to production-grade typed config.

- Add typed config descriptors.
- Add env/file providers.
- Add missing-key and type-conversion diagnostics.
- Add secret-safe formatting.
- Support graph startup use cases where config drives layer construction.
- Provide config layers that can be consumed by dependency-injected layer
  builders.

### 10. Observability Services

Goal: make logger, metrics, and tracing credible stdlib services.

- Logger: preserve level, message, fields, timestamps, and trace/span metadata.
- Metrics: counters, gauges, histograms, snapshots, and assertions.
- Tracing: trace ids, span ids, attributes, parent/child relationships, and
  span lifecycle checks.
- Keep these as services layered on the core, not as core runtime complexity.
- Ensure traces can connect effect runs, layer startup, fibers, schedules, and
  finalizers without each subsystem inventing separate metadata.

### 11. Test Toolkit

Goal: make Effect-style deterministic testing ergonomic in Zig.

- Add `fx.Test` helpers for fixtures, golden output, fake service injection, and
  readable assertion reports.
- Add scoped test layers for custom services.
- Add fake config, logger, metrics, tracing, and clock builders as reusable
  layers.
- Add test helpers for dependency reports, exits, causes, schedules, and
  cleanup failures.
- Add deterministic fiber workflow assertions for fork/join/interrupt, queue
  flows, and scoped child cleanup.

### 12. Backend Boundary For Async Runtime

Goal: cross the line from deterministic fiber lifecycle semantics to a fuller
effect runtime with real suspension, scheduling, and structured concurrency.

- Define the Zig concurrency model: async functions, event loops, worker pools,
  or a deliberately synchronous engine with explicit async adapters.
- Add a backend that can suspend and resume work instead of running fibers to
  completion on join.
- Add interruption that can cancel or detach blocking IO through the chosen
  backend.
- Add supervision, task groups, and structured concurrency.
- Add parallel composition after interruption and cleanup semantics are
  well-defined for the backend.
- Keep deterministic backend tests as the compatibility suite for all future
  async backends.

### 13. Module And Application Pattern

Goal: make large systems predictable to build with `zigeffect`.

- Define a module shape that bundles services, layers, effects, tests, and docs.
- Add app startup templates around `layerGraph`.
- Add CLI-friendly startup validation and dependency reports.
- Add examples for database-backed services, test layers, and production
  bootstrap.

## Cross-Subsystem Compatibility Checklist

Before any engine milestone is considered complete, verify:

- Effects run through `Runtime`, `Layer.provide`, and `layerGraph.run` with the
  same service and finalizer semantics.
- Effects can run inside deterministic fibers without bypassing runtime
  dependency validation.
- Layer startup resources outlive per-run resources and are released on graph
  deinit.
- Fiber scopes close child resources on success, failure, and interruption.
- Schedules use the active `Clock` and are deterministic under `TestEnv`.
- `Exit` and `Cause` reports include enough context to diagnose effect failure,
  cleanup failure, interruption, and startup failure.
- Test services can be provided through normal layers and graph startup, not
  only through `TestEnv` shortcuts.
- Documentation shows one preferred path for production startup and one
  preferred path for tests.

## Definition Of Effect-Grade

`zigeffect` can be treated as Effect-grade for Zig when it has:

- typed direct-style effects
- typed service requirements and provider declarations
- dependency-injected layer builders
- automatic graph startup and memoization
- deterministic scoped resource safety
- deterministic fiber lifecycle semantics
- useful typed exits and causes
- deterministic test services
- production config and observability services
- a clear async/concurrency story, even if it is intentionally smaller than
  EffectTS

The current implementation satisfies the first six items for synchronous code.
The next delivery priority is dependency-injected layer builders.
