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
- `async_backend.zig`: async backend vtable shape for suspend, wake, timers,
  and interrupts.
- `backend_diagnostics.zig`: backend capability requirements and formatted
  diagnostics for unsupported runtime features.
- `control.zig`: shared suspension and cooperative cancellation vocabulary.
- `supervisor.zig`: local supervision definitions, child specs, restart modes,
  one-for-one/one-for-all/rest-for-one strategies, restart intensity, shutdown
  ordering, `Cause` evidence, and causal supervisor events.

Runtime/scope/fiber cohesion, coordination backpressure, scoped permits,
controlled suspension vocabulary, cooperative cancellation, and future backend
boundaries belong here.

Runtime backend capabilities include operation-specific async workflow flags for
wake, timer scheduling, interruption, and durable suspension. The async backend
vtable names the future suspend, wake, timer, and interrupt operations without
implementing real async I/O yet. Backend diagnostics format missing capability
errors so workflow code can fail clearly before a deterministic backend attempts
async-only behavior.

Local supervision is a deterministic policy layer. It records child specs and
restart decisions, preserves failure evidence through `Cause`, and emits causal
events, but real async execution and distributed supervision remain separate
backend and cluster milestones.

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
- `context.zig`: replay-aware workflow context, deterministic step and
  activity sequence assignment, recorded outcome lookup, activity result codec
  boundaries, attempt counters, retry schedule decisions, clock-backed retry
  delays, timeout terminal events, durable compensation registration and
  reverse-order execution, durable deferred awaits, durable `sleep` and
  `sleepUntil` suspension, durable `waitForSignal` suspension and consumption,
  durable queue offer/await/ack through `queue`, causal schedule mapping, and
  `Exit`/`Cause` failure journaling.
- `deferred.zig`: durable deferred await result type, stable deferred identity,
  and external complete, fail, and cancel APIs.
- `clock.zig`: stable timer identity, durable sleep result type, due timer
  query, timer firing, timer cancellation, and journal-store-compatible wake-up
  helpers for in-memory and append-only file stores.
- `signal.zig`: named signal definitions, stable signal identity, durable wait
  result type, external signal append API, idempotency keys, and suspended
  workflow wake-up for signal receipt.
- `queue.zig`: typed durable queue definitions, stable queue item identity,
  idempotent offers, worker claims, concurrency limits, completion/failure,
  expired-claim retry, ack state, and workflow wake-up for queue terminals.
- `scheduler.zig`: local cooperative workflow scheduler, runnable workflow
  worker registry, durable timer watches, typed durable queue workers, graceful
  shutdown, fair cursors, and bounded tick/drain budgets.
- `lifecycle.zig`: external suspend, resume, interrupt, and cancel controls
  over `JournalStore`, including durable lifecycle rows, idempotent terminal
  transitions, and explicit terminal rows for pending timers, deferreds,
  queues, and activities during interrupt or cancellation.
- `inspect.zig`: workflow journal execution grouping, replay report building,
  pending-work summaries, last-failure extraction, and stable text/JSON report
  formatting for humans and agents.
- `causal.zig`: workflow journal to causal event mapping, workflow causal
  store construction, workflow failure/retry/suspend/resume findings, and
  reuse of shared causal report, JSON, and DOT rendering for durable histories.
- `engine.zig`: workflow engine registration, provider requirement validation,
  backend requirement checks, durable `workflow_started` appends, typed poll
  results, execution inspection, duplicate execution checks, and in-memory
  execution indexing.
- `journal.zig`: workflow journal id aliases, event kinds, event envelope,
  schema constants, version-aware compatibility classification, current-row
  migration registry, unknown-event policy, event clone/free helpers, JSON
  parser, and JSON/text formatters.
- `replay.zig`: workflow replay status, state rows, malformed history errors,
  and deterministic event-folding logic.
- `store.zig`: journal store contract, append/read batches, optimistic
  sequence checks, idempotency-key duplicate detection, in-memory store,
  append-only file store, segment naming, lock guard, partial-write recovery,
  future-schema downgrade failure before mutation, corruption reports, fsync
  policy, checkpoint JSON, snapshot commit metadata, archive export, retention
  policies, and completed-workflow compaction.

Workflow definitions, activity definitions, journal events, replay state,
journal stores, durable timers, durable deferreds, durable queues, durable
compensations, signals, lifecycle controls, inspectors, and replay helpers
belong here. Workflow code should consume `core`, `runtime`, `effect`, `layer`,
`services`, and `traits` contracts instead of expanding those domains with
workflow-specific behavior.

Workflow causal integration belongs in `src/workflow/causal.zig`, with the
shared causal runtime remaining in `src/services/causal.zig`. Query tools and
dogfood harnesses should consume workflow causal JSON/DOT/report helpers rather
than re-parsing workflow journal rows ad hoc.

### Workflow Snapshots, Archives, And Compaction

The local workflow file store writes normal events to the active JSONL segment.
Replay snapshots use `workflow-checkpoint-{sequence}.json`, and
`workflow-snapshot-commit-{sequence}.json` is the commit point that makes a
checkpoint eligible for recovery. Recovery loads the highest committed
checkpoint and then replays only segment rows with a greater sequence.

Completed workflow compaction exports acknowledged rows to
`workflow-archive-{first}-{last}.jsonl`, commits a checkpoint, and truncates the
active segment only after the commit marker exists. A crash before the commit
falls back to full segment replay; a crash after the commit recovers from
checkpoint plus tail. Retention policies can keep all rows, archive then
compact completed workflows, or checkpoint-only compact completed workflows.

### Cooperative Local Scheduling

The workflow scheduler is a local orchestration boundary over the journal,
durable clock, and durable queues. It does not provide real async I/O or
distributed execution; it fairly visits registered workflow workers, timer
watches, and queue workers within explicit budgets and records durable progress
through existing workflow events. Later cluster and supervision modules should
reuse this boundary instead of bypassing the workflow journal.

```text
src/cluster/
```

Owns Erlang-style distributed runtime surfaces:

- `root.zig`: cluster namespace facade and ergonomic public aliases.
- `identity.zig`: local entity type, id, address, and stable id derivation.
- `mailbox.zig`: local in-memory entity envelopes, per-entity FIFO mailbox
  storage, ask correlations, reply storage, and envelope ownership helpers.
- `entity.zig`: local entity runtime, runtime-bound refs, entity scopes,
  services, finalizers, idle shutdown, and supervisor-backed handler failure
  recovery.
- `envelope.zig`: durable cluster message protocol with message ids,
  idempotency keys, request/reply/ack/interrupt/chunk-reply envelopes,
  at-least-once delivery tracking, duplicate reply detection, and redacted
  diagnostics.
- `message_storage.zig`: shard-aware durable message and reply storage
  contract, in-memory storage, file-backed append/recovery semantics, and
  stable JSON compatibility helpers.
- `routing.zig`: deterministic shard ids, entity-id shard hashing,
  configurable local shard routing tables, local route targets, and
  snapshot/reload helpers for restart-stable routing.
- `runner.zig`: stable runner and machine identity, startup registration,
  heartbeat history, in-memory health events, and local runner health
  inspection reports.
- `runner_storage.zig`: runner storage contract, shard lease metadata,
  in-memory lease table, file-backed per-shard lease files, and local atomic
  acquire/refresh/release operations.
- `shard_lease.zig`: local shard lease manager with bounded TTLs, refresh
  cadence, owned-lease tracking, graceful handoff, dead-runner recovery, and
  causal shard ownership events.
- `runtime.zig`: shard-owned cluster runtime that registers local entities,
  accepts messages for owned shards, dispatches durable envelopes, stores
  replies, acknowledges processed messages, and releases owned shards on
  shutdown.
- `local_cluster.zig`: local multi-runner composition for shared storage,
  balanced shard acquisition, durable message routing, runner ticks, and
  dead-runner shard recovery.
- `transport.zig`: deterministic cluster transport boundary with a synchronous
  vtable, versioned request/response JSON, HTTP-shaped loopback bytes,
  in-process transport, loopback HTTP transport, and timeout/retry policy
  metadata.
- `workflow_engine.zig`: shard-owned durable workflow command layer that maps
  execution ids to workflow execution entities, routes commands through cluster
  transport, mutates `JournalStore` from the owning entity, rebuilds execution
  entity registrations after shard migration, and exposes timer, deferred,
  signal, and queue command paths through shard ownership.

Entity identity, actor references, message envelopes, durable message storage,
shard ids, runner ids, runner storage, leases, rebalancing, transports,
cluster workflow integration, and supervision across entities, shards, runners,
and transports belong here. Cluster code should build on workflow and runtime
contracts instead of making durable state depend on runner memory.

The local entity runtime is single-process and in-memory. It gives cluster
concepts a deterministic local execution model, but durable message storage,
runner ownership, and transport are separate milestones.

```text
tools/
```

Owns local developer and agent CLI entrypoints:

- `workflow_tool_support.zig`: shared workflow CLI argument parsing and
  fixture/file-journal event loading.
- `workflow_list.zig`: `zig build workflow-list` execution summary command.
- `workflow_replay.zig`: `zig build workflow-replay` selected execution replay
  command.
- `workflow_journal_inspect.zig`: `zig build workflow-journal-inspect` selected
  execution event inspection command.

Workflow tools should stay thin and delegate durable state interpretation to
`src/workflow/inspect.zig`.

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
