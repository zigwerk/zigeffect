# zigeffect Architecture

Date: 2026-06-05

`zigeffect` is organized as a public facade plus domain modules. Users import
`zigeffect` through `src/zigeffect.zig`; maintainers and agents work in the
domain folder that owns the behavior they are changing.

## Public Import

The public module root is:

```text
packages/zigeffect/src/zigeffect.zig
```

That file is a facade. It exports domain namespaces such as `fx.core`,
`fx.effect`, `fx.runtime`, `fx.layer`, `fx.services`, `fx.data`, `fx.match`,
`fx.pattern`, `fx.traits`, `fx.workflow`, and `fx.cluster`, while preserving
the existing top-level aliases such as `fx.Effect`, `fx.Context`, `fx.Scope`,
`fx.Runtime`, `fx.Layer`, `fx.Schedule`, and `fx.TestEnv`. Domain namespaces
also expose ergonomic aliases, for example `fx.effect.Effect`,
`fx.runtime.Runtime`, `fx.layer.Layer`, `fx.services.Logger`, and
`fx.data.Option`.

Package users should keep importing the facade:

```zig
const fx = @import("zigeffect");
```

Implementation modules should not import `src/zigeffect.zig`. Import the
specific sibling domain file instead. This keeps dependencies explicit and
prevents facade cycles.

## Source Domains

```text
src/core/
```

Owns the engine result language and low-level execution context:

- `result.zig`: `Cause`, `Exit`, `FinalizerExit`, formatting, conversion.
- `scope.zig`: `Scope`, finalizer registration, cleanup ordering.
- `context.zig`: `Context` and `serviceNotFound`.

Roadmap work touching failure representation, cleanup ownership, or service
lookup starts here.

```text
src/dependency/
```

Owns service metadata and diagnostics:

- `services.zig`: `ServiceSet`, service-set builders, `DependencyError`.
- `report.zig`: dependency issues, reports, formatted diagnostics.
- `validation.zig`: requirement/provider validation helpers.

Requirement algebra, provider ownership, malformed tuple diagnostics, and graph
reports belong here.

```text
src/effect/
```

Owns direct-style effect values and synchronous effect combinators:

- `effect.zig`: `Effect`, combinators, error recovery, retry/repeat execution.
- `resource.zig`: `acquireRelease`.
- `schedule.zig`: `Schedule` policies.

Effect combinators, scoped acquisition helpers, and schedule algebra should land
here unless they need runtime/fiber execution semantics.

```text
src/runtime/
```

Owns execution runtimes and deterministic concurrency primitives:

- `runtime.zig`: `Runtime`.
- `runner.zig`: managed-scope run/exit helper shared by runtime, layer, and
  graph paths.
- `fiber.zig`: `Fiber`, `FiberRuntime`, deterministic lifecycle semantics.
- `coordination.zig`: `Deferred`, `Queue`, `Semaphore`.
- `backend.zig`: backend capability contract and deterministic backend marker.
- `control.zig`: shared suspension and cooperative cancellation vocabulary.

Runtime/scope/fiber cohesion, coordination backpressure, scoped permits,
controlled suspension vocabulary, cooperative cancellation, and future backend
boundaries belong here.

```text
src/layer/
```

Owns dependency layers and graph startup:

- `layer.zig`: `Layer`, `LayerWithError`, `ProvidedLayer`, `RequiredLayer`,
  `MergeLayer`.
- `graph.zig`: `LayerGraph`, generated graph environments,
  `LayerGraphRuntime`, `layerGraph`.

Dependency-injected layer builders, graph startup ordering, graph memoization,
and provider replacement APIs belong here, with metadata helpers in
`src/dependency/` where appropriate.

```text
src/services/
```

Owns built-in services:

- `clock.zig`
- `logger.zig`
- `config.zig`
- `metrics.zig`
- `tracing.zig`
- `memory_file_system.zig`
- `id_generator.zig`

Production config, logger, metrics, tracing, filesystem, and id generation
service contracts belong here. Keep these services layered on the core instead
of adding observability or durable runtime complexity to `Effect` or `Runtime`.

```text
src/traits/
```

Owns small typeclass-ish contracts used by data and pattern helpers:

- `equal.zig`
- `hash.zig`
- `order.zig`
- `show.zig`
- `redaction.zig`
- `codec.zig`

Equality, hashing, ordering, formatting, redaction marker behavior, and
allocator-explicit encoding/decoding contracts belong here when they need to
compose across data structures, durable payloads, snapshots, or messages.

```text
src/data/
```

Owns Effect-style data helpers:

- `option.zig`
- `either.zig`
- `duration.zig`
- `datetime.zig`
- `big_decimal.zig`
- `chunk.zig`
- `hash_set.zig`
- `redacted.zig`
- `data.zig`

Owned data structures keep allocators explicit. Foundational ADT ergonomics
belong here; generic tagged-union dispatch belongs in `src/match/`.

```text
src/match/
```

Owns generic tagged-union matching:

- `tagged.zig`
- `handlers.zig`
- `diagnostics.zig`

Exhaustive and partial `union(enum)` matching, handler validation, and
compile-fail diagnostics belong here.

```text
src/pattern/
```

Owns structural matching:

- `matcher.zig`
- `structural.zig`
- `captures.zig`
- `predicates.zig`
- `diagnostics.zig`

Wildcards, ranges, predicates, optionals, nested struct patterns, typed
captures, and structural union arms belong here.

```text
src/workflow/
```

Owns local durable workflow runtime surfaces:

- `root.zig`: workflow namespace facade and ergonomic public aliases.
- `definition.zig`: typed workflow definitions, metadata, idempotency key
  callback validation, deterministic execution id derivation, and service
  requirements.
- `activity.zig`: typed activity definitions, metadata, idempotency key
  callback validation, retry schedule attachment, timeout metadata,
  compensation metadata, formatting, and service requirements.
- `journal.zig`: workflow journal id aliases, event kinds, event envelope,
  schema constants, event clone/free helpers, JSON parser, and JSON/text
  formatters.
- `replay.zig`: workflow replay status, state rows, malformed history errors,
  and deterministic event-folding logic.
- `store.zig`: journal store contract, append/read batches, optimistic
  sequence checks, idempotency-key duplicate detection, in-memory store,
  append-only file store, segment naming, lock guard, partial-write recovery,
  corruption reports, fsync policy, and checkpoint JSON.

Workflow definitions, activity definitions, journal events, replay state,
journal stores, durable timers, durable deferreds, durable queues, signals,
lifecycle controls, inspectors, and replay helpers belong here. Workflow code
should consume `core`, `runtime`, `effect`, `layer`, `services`, and `traits`
contracts instead of expanding those domains with workflow-specific behavior.

```text
src/cluster/
```

Owns Erlang-style distributed runtime surfaces:

- `root.zig`: cluster namespace marker until actor/shard modules land.

Entity identity, actor references, message envelopes, durable message storage,
shard ids, runner ids, runner storage, leases, rebalancing, transports,
cluster workflow integration, and supervision across entities, shards, runners,
and transports belong here. Cluster code should build on workflow and runtime
contracts instead of making durable state depend on runner memory.

```text
src/testing/
```

Owns reusable test environment helpers:

- `test_env.zig`: `TestServices`, `TestEnv`, assertions, test runtime helpers.

Effect-style test toolkit additions and fake service builders belong here.

## Import Direction

Implementation modules follow this direction:

- `core/*` imports only `std` and lower-level core files.
- `dependency/*` imports `std` and `core` only when needed.
- `effect/*` imports `core`, `dependency`, and service files only where needed.
- `runtime/*` imports `core`, `dependency`, `effect`, and `services/clock`.
- `layer/*` imports `core` and `dependency`; graph code may import runtime
  helpers only when sharing an execution path.
- `services/*` imports `std` and service-local dependencies.
- `testing/*` may import any public domain needed to assemble test services.
- `workflow/*` may import core, dependency, effect, runtime, layer, services,
  traits, and data modules, but not `cluster/*`.
- `cluster/*` may import workflow and lower-level domains.
- No implementation module imports `src/zigeffect.zig`.

When adding a feature, start in the owning domain and pull in smaller contracts
from lower domains. Avoid adding parallel service lookup, cleanup, or result
reporting mechanisms.

## Tests

The test entry point is:

```text
test/all_test.zig
```

It imports domain test files:

- `architecture_test.zig`: facade and namespace contracts.
- `dependency_test.zig`
- `effect_test.zig`
- `scope_test.zig`
- `runtime_test.zig`
- `fiber_test.zig`
- `invariants_test.zig`
- `layer_test.zig`
- `schedule_test.zig`
- `services_test.zig`
- `traits_test.zig`
- `data_test.zig`
- `match_test.zig`
- `pattern_test.zig`

Shared test-only helpers live in:

```text
test/support/fixtures.zig
```

Add new tests to the domain file that owns the behavior. Add shared fixtures
only when at least two test files need the same helper.

Compile-fail fixtures remain under:

```text
test/compile_fail/
```

## Roadmap Landing Zones

- Public API hardening: `src/dependency/`, `src/core/context.zig`,
  `test/architecture_test.zig`, and compile-fail fixtures.
- Requirement algebra and provider contracts: `src/dependency/` plus
  `src/layer/`.
- Dependency-injected layer builders: `src/layer/graph.zig` and
  `src/layer/layer.zig`.
- Runtime, scope, and fiber cohesion: `src/runtime/` and `src/core/scope.zig`.
- Resource model expansion: `src/effect/resource.zig` and `src/core/scope.zig`.
- Cause and exit hardening: `src/core/result.zig`.
- Schedule algebra: `src/effect/schedule.zig`.
- Coordination primitives: `src/runtime/coordination.zig` and
  `src/runtime/fiber.zig`.
- Config and observability services: `src/services/`.
- Test toolkit: `src/testing/` and `test/support/fixtures.zig`.
- Async backend boundary: `src/runtime/`.
- Module/application patterns: docs and examples first, then focused helpers.

## Verification

Run:

```bash
bun run zigeffect:test
bun run zig:test
bun run typecheck
```

`bun run zigeffect:test` must keep the architecture test green so the facade and
domain namespace contract does not regress.
