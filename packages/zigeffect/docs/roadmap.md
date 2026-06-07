# zigeffect Roadmap

Date: 2026-06-05

This roadmap tracks `zigeffect` as a Zig-native Effect-inspired engine. The goal
is not API cloning. The goal is a production-grade Zig shape for direct-style
programs, typed errors, service requirements, scoped resources, dependency
layers, testing, and eventually async runtime semantics.

## Current Assessment

`zigeffect` now works as a deterministic Zig effect engine. It satisfies the
current deterministic roadmap and keeps the async runtime story as an explicit
backend-adapter boundary.

What is real today:

- Public package layout is split behind a facade into core, dependency, effect,
  runtime, layer, services, and testing domains.
- Runner APIs emit stable compile-time diagnostics for mismatched effect
  environments before runtime execution or service validation.
- Dependency injection gates work.
- Layer startup and teardown work.
- Heterogeneous graph startup works and memoizes within the graph runtime.
- Graph-started environments can be handed to regular and fiber runtimes while
  keeping dependency validation.
- Typed Zig errors are preserved.
- Scoped cleanup is deterministic.
- Pointer and value resource acquisition helpers share the same scope cleanup
  contract.
- Deterministic fiber lifecycle semantics exist for `fork`, `join`,
  `interrupt`, scoped leases, and coordination primitives.
- Tests cover these paths.

Current boundary decisions:

- The fiber runtime is deterministic and semantic-first. Real suspension,
  blocking-IO interruption, and async supervision belong to a future backend
  adapter, not to the deterministic core.
- `requires` stays Zig-native metadata plus validation. It is not trying to
  become a full type-level requirement algebra.
- `Exit` stays a lightweight by-value result. Recursive ownership is handled by
  `CauseTree` for reports and tooling instead of forcing every `exit()` caller
  to manage heap state.
- Logger, config, metrics, tracing, and observability reporting are deterministic
  stdlib-style services. External exporters can layer on top of those service
  contracts.
- The agent-observable causal runtime is a roadmap direction, not a shipped
  runtime graph API yet. The package already has the ingredients: typed
  effects, services, scopes, fibers, layers, schedules, exits, causes, logs,
  metrics, and traces. Future work should connect them through an opt-in,
  bounded causal event model that agents can query structurally.

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
- `validateRequirements` and `requirementsSatisfiedBy` for provider/consumer
  contract checks.
- `staticRequirementsSatisfied` and `assertStaticRequirementsSatisfied` for
  compile-time known provider/consumer metadata.
- `ServiceEnv(.{ ... })` and graph `runNarrowed`/`exitNarrowed` for app effects
  that depend on a service slice rather than the full graph environment.
- Stable compile diagnostics for malformed provider/requirement service
  tuples.
- Stable compile diagnostics for invalid `Effect.fromFn`, invalid
  `Layer.merge`, and resource failure sets missing scope/allocation errors.
- Stable compile diagnostics for mismatched effect environments at layer,
  runtime, graph runtime, and fiber runtime boundaries.

### Scope And Resources

- `Scope` with reverse-order finalization.
- Typed finalizers.
- Fallible finalizers with recorded cleanup failures.
- Exit-aware finalizers through `FinalizerExit`.
- `acquireRelease` for scoped pointer resources.
- `acquireReleaseValue` for scoped value resources where copy-based cleanup is
  safe.
- Runtime-managed scope close on success and failure.
- Explicit shared runtime scopes through `Runtime.withScope`.
- Runtime, fiber, and graph exits preserve typed program failure followed by
  cleanup failure through `Cause.failure_then_finalizer_failure`.
- Runtime-generated cleanup failures also preserve defects and interruptions
  through direct combined cause variants.

### Runtime Result Model

- `Exit` for success, typed failure, defect, interruption, and cause.
- `Cause` shape for failures, defects, interruption, cleanup failure, and nested
  cause variants.
- `CauseTree` for allocator-owned recursive cause reports in tests and tooling.
- `formatExit` and `formatCause` for readable CLI/test/agent reports.

### Fiber Lifecycle And Coordination

- `FiberId` and `FiberStatus`.
- `FiberRuntime` and typed `Fiber` handles.
- Deterministic `fork`, `join`, and `interrupt`.
- `forkScoped` leases that interrupt unfinished child fibers when a parent scope
  closes.
- Child scope cleanup with success, failure, or interruption exits.
- `Deferred`, `Queue`, and `Semaphore` coordination primitives.
- Queue shutdown and scoped semaphore permit cleanup.
- Deterministic queue producer/consumer workflow coverage under fibers.
- Explicit deterministic backend capability boundary for future async runtimes.

### Layers And DI

- `Layer.fromEnv`.
- `Layer.fromBuilder`.
- `Layer.fromContextBuilder` for dependency-injected graph startup builders.
- `Layer.provide`.
- `Layer.merge`.
- `LayerWithError` for typed startup failures.
- `ServiceSet`, `DependencyReport`, and `LayerGraph` metadata validation.
- Duplicate provider and missing requirement diagnostics.
- Executable `layerGraph` for heterogeneous layer tuples.
- Direct `LayerGraphRuntime.report("label")` formatted dependency reports.
- Automatic graph validation before startup.
- Explicit provider replacement metadata through `.replaces(.{Service})`.
- Dependency-ordered graph startup from declarations.
- Graph builder contexts that expose already-started dependency services.
- Graph startup-scope finalizers for dependency-injected builders.
- Startup failure cleanup for already-started graph dependencies.
- Regular and fiber runtime adapters for graph-started environments.
- Memoized graph startup until graph deinit.
- Generated composite graph environment with typed service dispatch.

### Schedule And Test Support

- Retry/repeat policies: `once`, `recurs`, `spaced`, `duration`, `fixed`,
  `repeat`, `exponential`, `fibonacci`, `linear`, `backoff`,
  `jitteredBackoff`.
- Schedule decision inspection and union/intersection-style delay composition.
- Schedule timeout policies and reset-attempt inspection.
- Fake/system `Clock`.
- `TestEnv` with logger, config, metrics, tracing, memory filesystem, fake
  clock, runtime helpers, fixture registry, golden output assertions, and
  deterministic assertions.
- Typed config descriptors with defaults, parse errors, and secret-safe
  diagnostic formatting.
- Config entry/dotenv provider loading and `ConfigEnv` layer support.
- Schema-wide config loading through `Config.schema` and `Config.readSchema`.
- Structured logger entries with optional trace metadata, metrics
  histograms/snapshots, and tracing span/trace ids plus attributes.
- Test helpers for structured logs, histograms, dependency reports, causes, and
  schedule delays.

### Documentation And Verification

- Usage guide.
- Architecture guide and domain file tree for future roadmap work.
- Error guide.
- EffectTS parity notes.
- Module/application pattern guide.
- Agent guide.
- Devex review.
- Focused Zig tests for core effect behavior, scopes, layers, graph startup,
  schedules, diagnostics, invariants, and test services.

## Delivery Roadmap

### 1. Engine Invariants And Public API Hardening

Goal: make the current engine harder to misuse before adding deeper semantics.

Status: delivered for the current synchronous API surface. Malformed service
tuple diagnostics, environment mismatch diagnostics, composition-shape
diagnostics for `Effect.fromFn`, `Layer.merge`, and resource failure sets,
graph-runtime reports, compile-fail coverage, and cross-subsystem invariants
are in place.

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

Status: delivered for the current graph runtime shape. Generic
provider/consumer comparison helpers, static requirement helpers,
graph duplicate-provider diagnostics, explicit graph-local provider replacement
metadata, and graph service-environment narrowing are in place.

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

Status: delivered for the current graph startup shape. `Layer.fromContextBuilder`
receives a graph startup context, `Layer.fromEffect` runs startup effects over
projected service environments, typed startup errors are preserved, graph
startup scope finalizers are used, and already-started dependencies close on
builder failure.

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

Status: delivered for the current deterministic runtime. Graph-started
environments expose regular and fiber runtime adapters that validate
requirements against graph providers. Managed-scope run/exit logic is shared
through an internal runner helper. `forkScoped` and `forkInScope` define
parent/child scope leases for per-run, caller-owned, and graph-startup scopes,
including graph-provided services that start unfinished child fibers during
startup. Future async supervision remains part of the backend roadmap.

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

Status: delivered for the current synchronous resource model. Value-resource
acquisition, nested reverse cleanup ordering, combined program-failure plus
cleanup-failure reporting, explicit long-lived runtime scopes, and ownership
guides for graph startup, per-run, shared runtime, and fiber-owned resources
are in place.

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

Status: delivered for the current by-value `Exit` model. Runtime-generated
cleanup failures preserve typed failures, defects, and interruptions with
direct non-pointer cause variants. Cause inspection helpers are available for
tests. `CauseTree` adds an allocator-owned recursive report shape and can append
finalizer failures to existing nested causes without dangling pointers. The
engine intentionally keeps `Exit` lightweight; managed recursive ownership lives
in `CauseTree`.

- Add an owned recursive representation for runtime-generated nested causes
  while preserving the current by-value `Exit` API.
- Represent combined program failure plus cleanup failure safely.
- Represent interruption cause consistently across runtime and fiber paths.
- Add richer interruption and defect helpers.
- Add cause assertions for tests.
- Keep Zig error sets as expected failures.

### 7. Schedule Algebra And Clock Integration

Goal: move schedules from useful policies to composable schedule programs.

Status: delivered for the current deterministic runtime. Schedule decision
inspection, union/intersection-style delay composition, timeout policies,
reset-attempt inspection, owned recursive `ScheduleProgram` trees, and
fake-clock retry/repeat sleeps are in place and tested. Deeper async runtime
sleep hooks remain part of the backend roadmap.

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

Status: delivered for deterministic coordination. Queue shutdown semantics,
scoped semaphore permits, deterministic queue producer/consumer workflows under
fibers, and explicit wait-state/backpressure inspection are in place and
tested. Real blocking or suspend/resume remains part of the future async
backend.

- Define blocking semantics for deterministic mode: immediate status/errors
  today, suspend/resume through a backend later.
- Add queue shutdown/interruption behavior.
- Add semaphore scoped permits that release on scope close.
- Add tests for producer/consumer workflows under deterministic fibers.

### 9. Config Service

Goal: move from a test map to production-grade typed config.

Status: delivered for the current stdlib service shape. Typed descriptors for
string, integer, and boolean values, defaults, invalid-value errors,
secret-safe diagnostics, entry/dotenv provider loading, schema-wide struct
loading, and `ConfigEnv` layer support are in place.

- Add typed config descriptors.
- Add env/file providers.
- Add missing-key and type-conversion diagnostics.
- Add secret-safe formatting.
- Support graph startup use cases where config drives layer construction.
- Provide config layers that can be consumed by dependency-injected layer
  builders.

### 10. Observability Services

Goal: make logger, metrics, and tracing credible stdlib services.

Status: delivered for the current deterministic service shape. Logger levels,
fields, timestamps, trace metadata, metrics histograms and snapshots, tracing
span ids, trace ids, parent ids, attributes, and runtime/fiber/graph
trace-context propagation are in place. Span lifecycle lookup, deterministic
assertions, and `formatObservabilityReport` for CLI/test/agent reporting are in
place.

- Logger: preserve level, message, fields, timestamps, and trace/span metadata.
- Metrics: counters, gauges, histograms, snapshots, and assertions.
- Tracing: trace ids, span ids, attributes, parent/child relationships, and
  span lifecycle checks.
- Keep these as services layered on the core, not as core runtime complexity.
- Ensure traces can connect effect runs, layer startup, fibers, schedules, and
  finalizers without each subsystem inventing separate metadata.

### 11. Test Toolkit

Goal: make Effect-style deterministic testing ergonomic in Zig.

Status: delivered for the current deterministic toolkit. Test assertions cover
structured logs, histograms, dependency reports, causes, schedule delays, fiber
status, queue state, fixture registry, golden output, and reusable fake-service
layer builders. Readable assertion report formatters cover log, schedule,
fiber-status, and queue-state mismatches for agent-facing harnesses.

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

Status: delivered as an explicit backend boundary. The deterministic backend
capability contract is exposed through regular and fiber runtimes, and
coordination wait states define which operations would suspend in a future
backend. Real suspension, blocking IO interruption, supervision, and parallel
composition are reserved for an async backend adapter rather than hidden inside
the deterministic core.

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

Status: delivered for the current package shape. The module/application guide
defines service, layer, effects, fixtures, tests, app startup, and agent
ownership patterns. `examples/readiness.zig` is compile-checked through
`zig build examples` and demonstrates a database-backed service, startup
effect, graph bootstrap, narrowed readiness effect, dependency report, and
fake-service test layers. `tools/scaffold_module.zig` is also compile-checked
through `zig build examples` and prints a module scaffold for service, layer,
effects, fixtures, tests, and README files. A larger domain-specific example
catalog can grow from this template.

- Define a module shape that bundles services, layers, effects, tests, and docs.
- Add app startup templates around `layerGraph`.
- Add CLI-friendly startup validation and dependency reports.
- Add examples for database-backed services, test layers, and production
  bootstrap.

### 14. Agent-Observable Causal Runtime

Goal: make `zigeffect` useful to agents as a structured execution model, not
just a library that emits text logs.

Status: initial deterministic implementation delivered. The canonical design is
in
`docs/agent-observable-runtime.md`; the Superpowers design and implementation
plan live in
`docs/superpowers/specs/2026-06-05-zigeffect-agent-observable-causal-runtime-design.md`
and
`docs/superpowers/plans/2026-06-05-zigeffect-agent-observable-causal-runtime.md`.

The novelty target is precise: a Zig-native agent-observable Effect runtime
with a first-class causal execution graph spanning typed errors, service
requirements, layer providers, scopes, resources, fibers, schedules, logs,
metrics, and traces.

- Delivered: opt-in `CausalStore` records deterministic runtime events.
- Delivered: runtime, scope, resource, fiber, layer, schedule, exit, service,
  and app-recorded observability facts can enter the causal graph.
- Delivered: structured queries for snapshot, lineage, cause, resources,
  fibers, requirements, retries, and findings.
- Delivered: text, JSON, DOT, and CI reports for human and agent tooling.
- Delivered: a local causal report tool and scenario examples for missing
  config, cleanup failure, scoped fiber interruption, and retry exhaustion.
- Delivered: opt-in bounded `CausalStore` retention through `initBounded`, with
  retention metadata in reports and JSON artifacts.
- Delivered: an optional `CausalBackend` event sink contract with adapter kinds
  for memory, JSON Lines, DOT, OpenTelemetry, NenDB graph, Cockroach/RoachGraph
  history, and async streams.
- Still future: production-grade adapter implementations, durable histories,
  a workbench UI, deterministic replay/forking, and policy-controlled
  remediation.
- Still future: using the causal graph pervasively inside `zigeffect` tests so
  agents can diagnose engine regressions from runtime facts.
- Leave room for a future causal workbench that visualizes effect runs, scope
  trees, fiber trees, layer graphs, retry timelines, resource ownership, and
  cause trees.
- Keep remediation controlled: agents may propose retries, graph restarts,
  provider replacement, config-layer replacement, fiber interruption, or
  deterministic replay, but arbitrary runtime memory mutation is out of scope.

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
- Causal runtime milestones preserve deterministic event ordering, bounded
  storage, secret redaction, and equivalent semantics for future async
  backends.

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
- agent-observable causal execution graphs
- a clear async/concurrency story, even if it is intentionally smaller than
  EffectTS

The current implementation satisfies the deterministic core, dependency, layer,
resource, fiber, config, observability, test, causal-runtime,
backend-boundary, and module-pattern requirements listed above. Future work can
add production adapters, async runtime backends, deterministic replay,
controlled remediation, and a larger application-template catalog without
changing the current deterministic contracts.
