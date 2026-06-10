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
- Durable workflow and cluster prerequisites now have explicit contracts for
  codecs, deterministic id generation, suspension/cancellation vocabulary,
  expanded backend capability labels, and causal extension domains.
- Durable clustering now includes production shard leasing, production-shaped
  HTTP/socket transports, and a real shared-storage control plane for
  membership, placement, rebalancing, drain, node-down recovery,
  split-brain evidence, and inspection.
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
- The current causal dogfood lane now has local before/after comparison,
  generated local and CI advice, local and CI structured verdict JSON, and pull
  request CI baseline capture, so failing head artifacts can be compared with
  base-commit causal evidence.
- Forward direction for the next major work is captured in
  [`../../../docs/superpowers/specs/2026-06-07-zigeffect-forward-roadmap-ergonomics-to-async-design.md`](../../../docs/superpowers/specs/2026-06-07-zigeffect-forward-roadmap-ergonomics-to-async-design.md):
  make Effect composition more ergonomic without cloning EffectTS, harden the
  deterministic core as the compatibility suite, then design and prototype the
  async backend boundary.
- The durable workflows and clustering execution roadmap is captured in
  [`../../../docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md`](../../../docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md):
  add the small core prerequisites for durability, then build local durable
  workflow journals, workflow execution, durable timers/deferreds/queues,
  entity actors, sharding, multi-runner clustering, real async IO, production
  leases, transports, real clustering, and full supervision.

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
- Durable-local, async-local, and clustered backend capability labels are named
  without changing the deterministic runtime implementation.

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
- Delivered: opt-in deterministic causal sampling for high-volume logs,
  metrics, and spans, with sampled-event metadata in reports and JSON artifacts.
- Delivered: explicit causal event taxonomy helpers and taxonomy-versioned JSON
  metadata for structural, finding-evidence, and sampleable roles.
- Delivered: taxonomy-version warnings in causal query, compare, and
  development-loop query reports for newer saved artifacts.
- Delivered: default `zig build test` now runs through the causal package-test
  harness, with `test-raw` kept as the unwrapped unit-test step.
- Delivered: a controlled `zig build causal-package-failure-fixture` scenario
  proves package-shaped test failures write queryable causal artifacts without
  forcing the real package suite to fail.
- Delivered: `zig build causal-advice -- --file <artifact>` and
  after-phase loop advice reports turn causal evidence into deterministic,
  non-mutating next actions for development agents.
- Delivered: before-aware causal advice labels actions as `observed`,
  `persisting`, or `new`, allowing the development loop to distinguish stable
  fixture evidence from after-only regressions.
- Delivered: local causal dev-loop verdict JSON gives agents a first-read
  aggregate status, action counts, and next inspection step after after-phase
  runs.
- Delivered: `zig build causal-dev-agent -- local [scenario]` turns local
  dev-loop verdicts into deterministic agent inspection plans.
- Delivered: `zig build causal-diagnosis -- local [scenario]` writes
  patch-ready, non-mutating diagnosis reports from local dev-loop artifacts.
- Delivered: `zig build causal-remediation-plan -- local [scenario]` writes
  evidence-bound, non-mutating remediation plans from local dev-loop artifacts.
- Delivered: `zig build causal-remediation-audit -- local [scenario]` writes
  pending, schema-versioned proposal/audit records before any approval, patch
  proposal, or source mutation command exists.
- Delivered: `zig build causal-remediation-decision -- local approve|reject
  [scenario]` writes approved or rejected decision records for pending audits
  while keeping `applied=false`.
- Delivered: `zig build causal-dev-session -- start|assess|status
  [scenario]` coordinates baseline capture, after assessment, local agent
  handoff, diagnosis, remediation planning, and remediation audit into one
  repeatable local development harness without approval or source mutation.
- Delivered: `zig build causal-patch-proposal -- local draft|approved
  [scenario] --summary <summary> --file <path> --change <description>` writes
  non-mutating patch-intent artifacts that link proposed file changes to
  audit or approved decision evidence while preserving `applied=false`.
- Delivered: `zig build causal-audit-chain -- local [scenario]` writes
  read-only chain comparison JSON/text reports that compare session, audit,
  optional decision, proposal, before/after artifacts, and compare posture,
  then classify proposal event ids as disappeared, persisting, appeared, or
  missing.
- Delivered: `zig build causal-scenario-proposal -- local [scenario]` writes
  read-only scenario learning JSON/text reports that recommend `add-scenario`,
  `refine-scenario`, or `none` from verdict, diagnosis, remediation-plan, and
  audit-chain evidence.
- Delivered: `zig build causal-scenario-registry-patch -- --from-proposal
  <scenario-proposal.json>` writes review-only JSON/text/Zig registry patch
  drafts from scenario proposal artifacts while never editing
  `tools/causal_run.zig`.
- Delivered: `zig build causal-registry-application-readiness` writes
  policy-controlled JSON/text readiness reports for registry patch drafts while
  never editing `tools/causal_run.zig`.
- Delivered: `zig build causal-registry-apply` writes guarded registry
  application JSON/text artifacts from readiness reports. `plan` preserves
  `applied=false`; `record-applied` records `applied=true` only after current
  source state and verification command evidence pass.
- Delivered: `zig build causal-policy-decision -- local [scenario]` writes
  deterministic advisory policy JSON/text artifacts. The default local policy
  evaluates remediation/audit/registry evidence and emits `approve`, `reject`,
  or `needs-human-review` while preserving `applied=false` and
  `mutation_authority=none`.
- Delivered: `zig build causal-test-matrix` prints a deterministic coverage
  matrix for service, layer, scope, fiber, schedule, config, resource, retry,
  cause, and observability domains.
- Delivered: the scenario registry records coverage domains and includes
  `causal-readiness` as an app-shaped observability scenario.
- Delivered: core runtime tests share structural causal assertion helpers for
  event patterns, event sequences, findings, and quiet stores.
- Delivered: `zig build causal-artifacts` prints a deterministic retention
  manifest with upload globs and dogfood, scenario, and dev-loop artifact paths
  for agents and CI.
- Delivered: `.github/workflows/zigeffect-causal.yml` runs the causal manifest,
  dogfood harness, examples, and causal package-test gate, then uploads causal
  artifacts on failure.
- Delivered: `zig build causal-ci-handoff` writes a failure handoff report with
  exact advice and query commands, and CI runs it before artifact upload.
- Delivered: CI handoff now generates `*-advice.txt` reports from existing JSON
  artifacts using the same `causal_advice` engine as local development.
- Delivered: defensive causal event redaction for common secret-shaped
  key/value details, bearer values, and URL credentials.
- Delivered: an optional `CausalBackend` event sink contract with adapter kinds
  for memory, JSON Lines, DOT, OpenTelemetry, NenDB graph/history, and async
  streams.
- Delivered: `CausalAppTrace` and `examples/causal_app_request.zig` show how a
  Worker-shaped app request can emit bounded, redacted, workbench-compatible
  causal JSON without request-path filesystem, process, or Bun APIs.
- Delivered: app incident mapping classifies app config, requirement, response,
  retry, resource, finalizer, and fiber incidents, and app-specific
  advice/diagnosis mappings name the affected app subsystem.
- Delivered: `zig build causal-app-remediation-audit -- local --artifact
  <causal-json> --target <app-target>` writes pending, non-mutating app
  remediation audit artifacts with advisory app policy gates and query commands.
- Delivered: `zig build causal-app-policy-decision -- local --audit
  <app-remediation-audit-json>` evaluates source, config, migration,
  operational-human, and rollback app gates while preserving
  `mutation_authority=none` and `applied=false`.
- Delivered: `zig build causal-app-human-review -- local --policy
  <app-policy-decision-json>` records high-risk human-review evidence for
  migration, operational, and rollback-required app work while preserving
  `mutation_authority=none` and `applied=false`.
- Delivered: `zig build causal-app-patch-proposal -- local --policy
  <app-policy-decision-json> --summary <summary> --change <description>`
  writes draft, non-mutating app proposal artifacts that cite source files,
  config keys, migrations, runbooks, and rollback plans while preserving
  `mutation_authority=none` and `applied=false`.
- Delivered: `zig build causal-app-application-readiness -- local --proposal
  <app-patch-proposal-json> approve --reason <reason>` writes non-mutating app
  readiness artifacts that re-check proposal evidence before an application
  attempt while preserving `mutation_authority=none` and `applied=false`.
- Delivered: `zig build causal-app-apply -- --from-readiness
  <app-application-readiness-json> plan|record-applied --reason <reason>`
  writes guarded app application artifacts. `applied=true` is possible only
  after ready readiness, category-specific change evidence, before/after
  evidence, and post-application verification evidence are recorded.
- Delivered: `zig build causal-schema-governance` prints the authoritative
  causal artifact schema/version matrix with compatibility posture, producer,
  consumer, migration policy, and new-schema checklist.
- Delivered: `docs/operations.md` is the local/CI causal runtime operations
  manual for artifact retention, CI handoff, redaction review, review gates,
  guarded application records, workbench operation, backend adapter
  expectations, schema governance, and scenario governance.
- Delivered: `causal-performance-budget` publishes
  `zigeffect.causal.performance-budget.v1` with deterministic overhead budgets,
  SolidJS plus `webui-dev/zig-webui` workbench posture, and release-review
  guidance for causal runtime changes.
- Delivered: `causal-m9-completion-audit` publishes
  `zigeffect.causal.m9-completion-audit.v1` with deliverable checks,
  production-gap acknowledgement, verification commands, and the recommendation
  to deliver M9 with deferred production hardening.
- Delivered: `causal-production-hardening-backlog` publishes
  `zigeffect.causal.production-hardening-backlog.v1` with the ordered
  production-hardening branch queue, NenDB-only durable direction, SolidJS plus
  `webui-dev/zig-webui` workbench direction, the delivered graph visual
  debugging, human-agent feedback-loop, rollout automation guardrails, and
  wall-clock benchmark baseline, production capacity planning, and
  production-hardening completion audit plus load-test observation harness,
  production telemetry capture design, fixture, readiness-review, and
  implementation-proposal, exporter-boundary, local-pipeline-fixtures, and
  NenDB-retention-fixtures
  contracts, milestones, non-goals, verification commands, and the current
  next branch
  `codex/zigeffect-causal-production-telemetry-workbench-readonly-preview`.
- Delivered: `causal-production-artifact-aggregation` publishes
  `zigeffect.causal.production-artifact-aggregation.v1` with the aggregation
  bundle contract, source provenance fields, privacy review gates, deterministic
  multi-source fixture, and durable-retention handoff.
- Delivered: `causal-durable-production-retention` publishes
  `zigeffect.causal.durable-production-retention.v1` with the NenDB-only
  retention policy, TTL and compaction thresholds, backup and recovery
  expectations, retained-bundle fixture, and deployment-runbooks handoff.
- Delivered: `causal-production-deployment-runbooks` publishes
  `zigeffect.causal.production-deployment-runbooks.v1` with manual deployment,
  rollback, causal verification, and incident-response gates. It consumes the
  aggregation and durable-retention contracts, keeps deploy/rollback execution
  outside zigeffect authority, and hands off to artifact access control.
- Delivered: `causal-artifact-access-control` publishes
  `zigeffect.causal.artifact-access-control.v1` with visibility classes, role
  labels, permissions, access decisions, denied-view fixtures, and access audit
  fields. It consumes the aggregation, durable-retention, and deployment-runbook
  contracts while keeping live RBAC enforcement and mutation authority out of
  scope.
- Delivered: `causal-encryption-at-rest-policy` publishes
  `zigeffect.causal.encryption-at-rest-policy.v1` with encryption domains, key
  owner labels, rotation evidence, encrypted artifact fixture metadata,
  redaction ordering, denied fixtures, and authority boundaries. It keeps
  encryption implementation, KMS integration, live RBAC, non-NenDB durable
  adapter work, alternate frontend renderer support, and mutation authority out
  of scope.
- Delivered: `causal-alerting-integrations` publishes
  `zigeffect.causal.alerting-integrations.v1` with record-only channel
  contracts, severity and routing policy, escalation gates, payload fields,
  preview fixtures, denied fixtures, and authority boundaries for Slack,
  Linear, Jira, SIEM, and paging handoffs. It keeps live alert delivery, ticket
  creation, SIEM forwarding, paging execution, network calls, secrets,
  non-NenDB durable adapter work, alternate frontend renderer support, and
  mutation authority out of scope.
- Delivered: `causal-live-dashboard-streaming-workbench` publishes
  `zigeffect.causal.live-dashboard-streaming-workbench.v1`, registers
  `zigeffect.causal.live-dashboard-stream.v1`, adds the local live stream
  sample, and extends the SolidJS/zig-webui workbench with Live and Visual Graph
  tabs backed by a lazy `@dschz/solid-g6` adapter over `@antv/g6`.
- Delivered: graph visual debugging adds cause, topology, ownership, and
  lineage perspectives to Visual Graph, the `?sample=visual-graph` fixture,
  selection detail, legend/warning panels, richer Solid G6 adapter metadata, and
  desktop/mobile nonblank G6 canvas verification while mutation authority
  remains `none`.
- Delivered: `causal-human-agent-feedback-loop` publishes
  `zigeffect.causal.human-agent-feedback-loop.v1` with the record-only loop
  that connects human workbench selections, bounded agent queries, before/after
  comparison, local regression clustering records, guarded remediation handoff,
  and future NenDB durable-history handoff. It keeps `applied=false`,
  `mutation_authority=none`, `workbench_mutation=false`, and
  `agent_mutation=false`.
- Delivered: `causal-rollout-automation-guardrails` publishes
  `zigeffect.causal.rollout-automation-guardrails.v1` with canary evidence
  records, progression gates, circuit-breaker decisions, rollback readiness
  gates, and negative automation fixtures. It keeps rollout progression,
  traffic shifts, feature flags, alert delivery, ticket creation, paging,
  deploys, and rollbacks outside zigeffect authority.
- Delivered: `causal-wall-clock-benchmark-baselines` publishes
  `zigeffect.causal.wall-clock-benchmark-baselines.v1` with local and CI
  benchmark scenario families, baseline record fields, environment metadata,
  calibration policy, advisory review gates, and capacity-planning handoff. It
  keeps timing observations record-only and does not collect timings, fail CI,
  run load tests, size production capacity, or grant mutation authority.
- Delivered: `causal-production-capacity-planning` publishes
  `zigeffect.causal.production-capacity-planning.v1` with source evidence,
  capacity domains, storage assumptions, load-test fixture plans, workbench and
  graph concurrency assumptions, agent guidance, readiness gates, negative
  capacity fixtures, and completion-audit handoff. It keeps capacity planning
  record-only, planning-only, NenDB-only, and does not ingest telemetry, run
  load tests, size production capacity, provision infrastructure, or grant
  mutation authority.
- Delivered: `causal-production-hardening-completion-audit` publishes
  `zigeffect.causal.production-hardening-completion-audit.v1` with delivered
  milestone checks, record-only/NenDB/SolidJS boundary checks, remaining
  evidence gaps, negative over-claim fixtures, and the handoff to
  `codex/zigeffect-causal-load-test-observation-harness`. It keeps
  `mutation_authority=none` and does not ingest telemetry, execute load tests,
  size production capacity, add non-NenDB adapter work, add alternate frontend
  renderer support, or mutate production state.
- Delivered: `causal-load-test-observation-harness` publishes
  `zigeffect.causal.load-test-observation-harness.v1` with approved scenario
  families, curated local argv arrays, bounded opt-in observation mode,
  median/p95 records, capped output snippets, negative over-claim fixtures, and
  the handoff to
  `codex/zigeffect-causal-production-telemetry-capture-design`. It keeps
  observations local, advisory, record-only, `mutation_authority=none`, and
  does not run production load, ingest production telemetry, fail CI, size
  production capacity, add non-NenDB adapter work, add alternate frontend
  renderer support, or mutate production state.
- Delivered: `causal-production-telemetry-capture-design` publishes
  `zigeffect.causal.production-telemetry-capture-design.v1` with runtime,
  app-semantic, backend OTel, redaction/access, and local-observation
  correlation capture surfaces, future telemetry field contracts, readiness
  gates, negative fixtures, and the handoff to
  `codex/zigeffect-causal-production-telemetry-capture-fixtures`. It keeps
  `production_telemetry_ingestion=false`, `live_exporter_enabled=false`,
  `mutation_authority=none`, and does not write durable production storage,
  size capacity, fail CI, add non-NenDB adapter work, add alternate frontend
  renderer support, or mutate production state.
- Delivered: `causal-production-telemetry-capture-fixtures` publishes
  `zigeffect.causal.production-telemetry-capture-fixtures.v1` with safe
  example records, selected fixture output, negative fixtures, validation
  checks, and the handoff to
  `causal-production-telemetry-readiness-review`. It keeps
  `production_telemetry_ingestion=false`, `live_exporter_enabled=false`,
  `durable_write_enabled=false`, `ci_gate_enabled=false`,
  `mutation_authority=none`, and does not write durable production storage,
  size capacity, fail CI, add non-NenDB adapter work, add alternate frontend
  renderer support, or mutate production state.
- Delivered: `causal-production-telemetry-readiness-review` publishes
  `zigeffect.causal.production-telemetry-readiness-review.v1` with fixture JSON
  review, reviewer decision and reason, required verification command evidence,
  ready and blocked readiness artifacts, and the handoff to
  `codex/zigeffect-causal-production-telemetry-implementation-proposal`. It
  keeps `applied=false`, `production_telemetry_ingestion=false`,
  `live_exporter_enabled=false`, `durable_write_enabled=false`,
  `ci_gate_enabled=false`, `mutation_authority=none`, and does not implement
  telemetry, write durable production storage, size capacity, fail CI, add
  non-NenDB adapter work, add alternate frontend renderer support, or mutate
  production state.
- Delivered: `causal-production-telemetry-implementation-proposal` publishes
  `zigeffect.causal.production-telemetry-implementation-proposal.v1` with ready
  readiness-review JSON consumption, proposer decision and reason, readiness
  and proposal verification checks, approved and blocked proposal artifacts,
  proposal phases, and the handoff to
  `codex/zigeffect-causal-production-telemetry-exporter-boundary`. It keeps
  `applied=false`, `production_telemetry_ingestion=false`,
  `live_exporter_enabled=false`, `durable_write_enabled=false`,
  `ci_gate_enabled=false`, `mutation_authority=none`, and does not implement
  telemetry, write durable production storage, size capacity, fail CI, add
  non-NenDB adapter work, add alternate frontend renderer support, or mutate
  production state.
- Delivered: `causal-production-telemetry-exporter-boundary` publishes
  `zigeffect.causal.production-telemetry-exporter-boundary.v1` with approved
  proposal consumption, proposal evidence checks, no-network exporter boundary
  fields, local envelope fixture names, approved and blocked boundary
  artifacts, and the handoff to
  `codex/zigeffect-causal-production-telemetry-local-pipeline-fixtures`. It
  keeps `applied=false`, `production_telemetry_ingestion=false`,
  `live_exporter_enabled=false`, `network_send_enabled=false`,
  `collector_endpoint_configured=false`, `otlp_serialization_enabled=false`,
  `durable_write_enabled=false`, `ci_gate_enabled=false`,
  `mutation_authority=none`, and does not implement telemetry, send to a
  network, configure collectors, serialize OTLP, write durable production
  storage, size capacity, fail CI, add non-NenDB adapter work, add alternate
  frontend renderer support, or mutate production state.
- Delivered: `causal-production-telemetry-local-pipeline-fixtures` publishes
  `zigeffect.causal.production-telemetry-local-pipeline-fixtures.v1` with
  approved exporter-boundary consumption, normalized local envelope fixtures,
  redaction and access checks, sampling fixtures, correlation-link fixtures,
  ready and blocked fixture artifacts, and the handoff to
  `codex/zigeffect-causal-production-telemetry-nendb-retention-fixtures`. It
  keeps `applied=false`, `production_telemetry_ingestion=false`,
  `live_exporter_enabled=false`, `network_send_enabled=false`,
  `collector_endpoint_configured=false`, `otlp_serialization_enabled=false`,
  `runtime_pipeline_enabled=false`, `durable_write_enabled=false`,
  `ci_gate_enabled=false`, `mutation_authority=none`, and does not run a
  telemetry pipeline, write NenDB, write durable production storage, size
  capacity, fail CI, add non-NenDB adapter work, add alternate frontend
  renderer support, or mutate production state.
- Delivered: `causal-production-telemetry-nendb-retention-fixtures` publishes
  `zigeffect.causal.production-telemetry-nendb-retention-fixtures.v1` with
  ready local-pipeline-fixtures consumption, NenDB node and edge mapping
  fixtures, retention policy constants, compaction markers, backup and recovery
  markers, ready and blocked retention artifacts, and the handoff to
  `codex/zigeffect-causal-production-telemetry-workbench-readonly-preview`. It
  keeps `applied=false`, `production_telemetry_ingestion=false`,
  `live_exporter_enabled=false`, `network_send_enabled=false`,
  `collector_endpoint_configured=false`, `otlp_serialization_enabled=false`,
  `runtime_pipeline_enabled=false`, `durable_write_enabled=false`,
  `nendb_write_enabled=false`, `ci_gate_enabled=false`,
  `mutation_authority=none`, NenDB-only, and SolidJS `zig-webui` aligned
  without touching production systems, running a telemetry pipeline, writing
  NenDB, compacting records, running backup or recovery, or claiming production
  capacity.
- Delivered: `causal-production-telemetry-workbench-readonly-preview` publishes
  `zigeffect.causal.production-telemetry-workbench-readonly-preview.v1`, adds a
  read-only SolidJS `webui-dev/zig-webui` Telemetry tab, supports
  `?sample=production-telemetry`, carries NenDB mapping fixtures and authority
  checks into the workbench, emits ready and blocked preview artifacts, and
  hands off to
  `codex/zigeffect-causal-production-telemetry-ci-artifact-preview`. It keeps
  `applied=false`, `production_telemetry_ingestion=false`,
  `live_exporter_enabled=false`, `network_send_enabled=false`,
  `collector_endpoint_configured=false`, `otlp_serialization_enabled=false`,
  `runtime_pipeline_enabled=false`, `durable_write_enabled=false`,
  `nendb_write_enabled=false`, `ci_gate_enabled=false`,
  `mutation_authority=none`, and avoids live telemetry, durable writes, CI
  gates, hosted dashboard claims, alternate renderers, or production mutation.
- Delivered: `causal-production-telemetry-ci-artifact-preview` publishes
  `zigeffect.causal.production-telemetry-ci-artifact-preview.v1`, consumes a
  ready workbench-preview artifact, records a preview-only CI archive candidate
  catalog and upload policy, emits ready and blocked CI artifact preview
  artifacts, and hands off to
  `codex/zigeffect-causal-production-telemetry-ci-harness-boundary`. It keeps
  `applied=false`, `production_telemetry_ingestion=false`,
  `live_exporter_enabled=false`, `network_send_enabled=false`,
  `collector_endpoint_configured=false`, `otlp_serialization_enabled=false`,
  `runtime_pipeline_enabled=false`, `durable_write_enabled=false`,
  `nendb_write_enabled=false`, `ci_upload_enabled=false`,
  `ci_workflow_mutation_enabled=false`, `ci_gate_enabled=false`,
  `mutation_authority=none`, and avoids artifact upload execution, workflow
  mutation, live telemetry, durable writes, CI gates, hosted dashboard claims,
  alternate renderers, or production mutation.
- Delivered: `causal-unified-spine-contract` publishes
  `zigeffect.causal.unified-spine-contract.v1` with canonical runtime ids, app
  semantic ids, relationship taxonomy, policy stages, derived index families,
  consumer contracts, and fixture mappings. It was the handoff into
  `codex/zigeffect-causal-deep-runtime-internals`.
- Delivered: deep runtime internals now emit stable runtime ids for layers,
  services, scopes, fibers, resources, finalizers, retries, defects,
  interruptions, and cause chains through the unified causal spine.
- Delivered: app semantic tracing records `artifact_id`, `domain_entity_ref`,
  `data_subject_ref`, and `schema_ref` through helper methods for data reads,
  transforms, writes, service calls, domain actions, policy decisions,
  artifacts, and responses.
- Delivered: the compact agent query interface returns bounded JSON for run
  summaries, failures, event explanations, cause traces, data lineage,
  findings, and recommended next queries. Cross-run comparison remains future.
- Still future: production-grade app-facing integrations, durable history
  hardening, and comparing arbitrary named audit-chain snapshots.
- Still future: deeper runtime regression scenarios for partial config and
  cause coverage.
- Extend the SolidJS `zig-webui` causal workbench when future UI branches need
  richer effect-run, scope-tree, fiber-tree, layer-graph, retry-timeline,
  resource-ownership, and cause-tree views.
- The live dashboard streaming branch started the graph layer with
  `@dschz/solid-g6` as the SolidJS adapter over the current causal graph model.
  The graph visual debugging branch deepened read-only graph layouts, runtime
  topology, cause chains, ownership, and app data lineage. Use direct
  `@antv/g6` APIs only when the adapter needs engine access. Keep `solid-flow`
  as optional later research for editable remediation planning surfaces.
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
