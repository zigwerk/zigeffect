# zigeffect

`zigeffect` is a Zig-native, Effect-inspired core for composing direct-style Zig
programs — with a deterministic **agent-observable causal runtime** at its
center: the engine records execution as a structured, queryable causal event
graph so LLM agents and humans can debug by asking the runtime precise questions
instead of reconstructing behavior from logs.

The canonical application API is normal Zig with service requirements visible
in the effect type:

```zig
const zstd = @import("zigeffect_std");
const fx = zstd.fx;
const kernel = fx.kernel;
const Orders = kernel.Service("application/Orders", OrdersApi);
const Find = kernel.Effect(Order, error{NotFound}, .{Orders});

const program = find(order_id)
    .flatMap(loadCustomer)
    .tap(auditCustomer)
    .named("orders.customer-view");

const MainLayer = OrdersLive.merge(AuditLive);
var runtime = try zstd.ManagedRuntime(@TypeOf(MainLayer)).make(
    allocator,
    io,
    root,
    MainLayer,
    .{ .observability = production_observability },
);
defer runtime.deinit();

const result = try runtime.run(program);
try runtime.shutdown();
```

`map`, `flatMap`, `tap`, `andThen`, `zip`, `catchAll`, and `mapError`
statically infer combined services and typed failures. Layers expose fluent
`provide`, `provideMerge`, and `merge`; one managed runtime builds the graph,
runs every endpoint/job, and disposes resources once. Application code does not
call the interpreter protocol directly. See
[compositional applications](docs/compositional-applications.md).

## The engine

- **Canonical `kernel.Service` / `kernel.Effect` / `kernel.Layer` plus
  application `zstd.ManagedRuntime`**: stable capability tags, inferred service and error
  composition, typed construction inputs and outputs, scoped builders, explicit
  provision, identity memoization, reusable runs, application inspection, and
  one disposal.
- **Legacy low-level `Effect`**: `fromFn`, `succeed`, `fail`, `sync`, `run`, `exit`, `retry`,
  `repeat`, `map`, `flatMap`, `tap`, `onExit`, `ensuring`, and recovery helpers.
  This environment-parameterized surface remains for unmigrated engine domains;
  new applications use `kernel.Effect`.
- **`Runtime` / `FiberRuntime` / `Fiber`**: engine-managed scopes with automatic
  cleanup, and fork/join/interrupt with scoped leases. The core stays
  deterministic and dependency-free, but the same `FiberExecutor` vtable runs on
  **three executors**: the deterministic backend, real **[zio](https://github.com/lalinsky/zio)
  coroutines** (`packages/zigeffect-zio`, built), and a real **OS-thread pool**
  (`ThreadPoolExecutor`). The same program yields a structurally-equivalent causal
  trace on all three: same event kinds, cause and parent edge kinds,
  id-insensitive scope/resource/fiber ownership facts, finding-evidence owner
  states, and per-fiber terminal lifecycle states, while ignoring concrete ids
  and scheduling order. See [docs/roadmap.md](docs/roadmap.md).
- **Concurrency**: `forEachPar`, `zipPar`, and the race family — `raceFirst`,
  `raceAll`, `race` (prefer-success), `both` (fail-fast).
- **`Deferred`, `Queue`, `Semaphore`**: coordination primitives with explicit
  wait-state/backpressure inspection; they suspend/resume for real on the zio
  backend.
- **`STM` / `TRef`**: optimistic-concurrency transactions (`atomically`), including
  **heterogeneous** transactions (`atomicallyMixed`) over `TRef`s of different
  value types. `Ref`/`Hub`/`CausalStore` are thread-safe; `FiberRef` is fiber-local
  with auto-propagation across `fork`.
- **`Context`**, **`acquireRelease`**, **`Scope`**: typed service access and
  scoped, reverse-order, exit-aware finalization.
- **`Exit` / `Cause` / `CauseTree`**: structured result shapes with
  allocator-owned recursive cause reports.
- **`Schedule`**: `once`, `recurs`, `spaced`, `duration`, fixed, exponential,
  fibonacci, linear, backoff, deterministic jitter.
- **Data + matching**: `Option`, `Either`, `Duration`, `DateTime`, `BigDecimal`,
  `Chunk`, `HashSet`, `Redacted`, `Data`, and exhaustive `match` / `pattern`.
- **`TestEnv` / `Clock`**: fake clock, memory filesystem, logger, config,
  metrics, tracing, and assertion helpers for deterministic tests.
- **`serviceNotFound`**: compile-time diagnostics for missing environment
  services.
- **Production statecharts**: typed flat/hierarchical/parallel/history machines,
  actors and supervision, durable workflow journals, cluster fencing, causal
  evidence, governed agent-authored workflow plans, immutable proof/review/
  approval chains, policy-gated fleet control, XState v5 projection/conformance,
  and the synchronized SolidJS Studio. See
  [docs/statecharts-production.md](docs/statecharts-production.md) and
  [docs/agent-workflow-studio.md](docs/agent-workflow-studio.md).

See [docs/usage.md](docs/usage.md), [docs/architecture.md](docs/architecture.md),
[docs/effectts-parity.md](docs/effectts-parity.md), and the
[examples/](examples/) directory.

## The agent-observable causal runtime

Every low-level `kernel.ManagedRuntime` owns a bounded `CausalStore` by default.
Every canonical application `zstd.ManagedRuntime` additionally owns an
embedded durable NenDB graph and checked persistence shutdown. Applications do
not construct, attach, or flush causal stores or graph backends. The engine
emits compact structural events — run start/end, scope open/close,
fiber fork/join/interrupt, service resolution, resource acquire/finalize, retry
decisions, exits — into one causal event graph keyed by `run_id`, `parent_id`,
`fiber_id`, `scope_id`, `cause_event_id`, and friends. Agents then query
`snapshot`, `lineage`, `cause`, `resources`, `fibers`, `requirements`,
`retries`, and `findings` instead of scanning a text report.

Causal JSON artifacts use the `zigeffect.causal.v1` schema and disclose retention
(`max_events`, `dropped_events`), sampling (`sampled_events`), and truncation
(`truncated_fields`) so agents know when evidence is incomplete. Event strings
are defensively redacted before storage and packed into one owned text
allocation per retained event. The event taxonomy classifies each kind as
structural, finding-evidence, or sampleable — and **finding evidence is never
sampleable**.

```bash
cd packages/zigeffect
zig build causal-test                       # write dogfood artifacts under .zig-cache/causal-artifacts/
zig build causal-query -- cause 3           # query the default artifact
zig build causal-query -- fibers pending
zig build causal-query -- --file <path> lineage 2
```

For the full picture see
[docs/agent-observable-runtime.md](docs/agent-observable-runtime.md) and
[docs/agent-guide.md](docs/agent-guide.md).

### The causal dev loop

The dev loop is the engine's self-improvement harness: capture a baseline, make a
change, capture the after state, and let the runtime tell you whether the change
*improved* the causal structure rather than just changing it.

```bash
zig build causal-dev-loop -- baseline       # writes ...-before.json, runs the package-test gate
# make the patch
zig build causal-dev-loop -- after          # writes ...-after.json + compare + advice + verdict
```

`causal-advice` produces rule-based, non-mutating next-action advice (pointing at
event ids and exact `causal-query` commands); `causal-compare` diffs two
artifacts; `causal-verdict` emits structured verdict JSON.

### Guarded remediation chain

A record-only, human-in-the-loop pipeline turns causal findings into reviewed
fixes without ever mutating source: `causal-diagnosis` → `causal-remediation-plan`
→ `causal-remediation-audit` → `causal-remediation-decision` →
`causal-patch-proposal` → `causal-audit-chain` → `causal-policy-decision`. Every
artifact preserves `applied=false` and `mutation_authority=none`. A parallel
`causal-app-*` chain does the same for app-facing incidents. See
[docs/operations.md](docs/operations.md).

### Runtime-owned application boundaries

Canonical applications create one `zstd.ManagedRuntime` and run their HTTP,
gRPC, queue or workflow adapter through it. The runtime owns the store and
embedded NenDB graph; the adapter derives the narrow recording capability it
needs and automatically emits request/job, retry and response boundaries.

```zig
var runtime = try zstd.ManagedRuntime(@TypeOf(MainLayer)).make(
    allocator,
    io,
    project_root,
    MainLayer,
    .{},
);
defer runtime.deinit();

try runtime.run(serve().named("projects.serve"));
try runtime.shutdown();
```

Application handlers do not create `CausalStore`, call `recordCausal`, attach a
backend or reproduce service/lifecycle events. Low-level `CausalAppTrace`
remains an adapter implementation and framework-conformance primitive. See
[Runtime-owned causal applications](docs/runtime-owned-causal-applications.md).

### Visual workbench

`causal-workbench` builds a read-only SolidJS renderer (via `zig-webui`) over a
saved artifact, with timeline, findings, relationship, query, metadata, graph,
and chain views:

```bash
zig build causal-test
zig build causal-workbench -- .zig-cache/causal-artifacts/zigeffect-causal-dogfood.json
zig build causal-workbench -- --server-only <artifact.json>   # for agent/browser inspection
```

**Live-attach.** Beyond static artifacts, the workbench can stream a *running*
engine. `CausalNdjsonTap` emits recorded events as NDJSON; a Bun WebSocket
collector (`workbench/src/collector/`) maps them to `LiveFrame`s and fans them out
one-per-message; the workbench consumes them via `?live=ws://…/live` — the same
timeline/graph/findings views, updating live.

```bash
zig build live-stream-example
./zig-out/bin/zigeffect-live-stream-example | bun workbench/src/collector/collector.ts
# then open the workbench at ?live=ws://127.0.0.1:4500/live
```

### Export adapters

Backend adapters are sinks, not the source of truth (if `failed_writes` is
nonzero, fall back to the in-memory trace): JSON Lines, DOT, OpenTelemetry-shaped
records, scan-based graph history, a NenDB node/edge write-contract, and a bounded
async stream. Each has a focused gate (`zig build causal-*-backend`).

For applications, `zigeffect-std` implements that writer contract as
`zstd.CausalGraph.LocalDatabase`: an embedded Zig 0.16 port of NenDB's
data-oriented topology backed by a bounded restart-safe property WAL at
`.zigeffect/graph/causal-graph.jsonl`. The `zigeffect` CLI exposes
manifest-scoped status, ordered-since, event, and child queries. The exact
upstream NenDB commit is pinned under `packages/references/nen-db` and reported
by runtime health; no server or Docker image is required.

## Schema governance and budgets

```bash
zig build causal-schema-governance              # registry of the official causal schemas
zig build causal-performance-budget             # deterministic retention/sampling/truncation budgets
```

See [docs/schema-governance.md](docs/schema-governance.md) and
[docs/performance-budget.md](docs/performance-budget.md).

## Build and test

```bash
cd packages/zigeffect
zig build test            # package tests through the causal harness (test-raw for the raw binary)
zig build examples        # compile and test the package examples
zig build release-gate    # the full release pipeline
```

Or from the repo root: `bun run zigeffect:test`.

For the complete local application-development distribution, install the
`packages/zigeffect-cli` executable and run
`bun run zigeffect:local-release`. The CLI generates five compile-tested project
kinds, embeds compatibility and scaffold-ownership metadata, emits Bash/Zsh/Fish
completions, and performs dry-run-first conflict-safe upgrades. See
[docs/compatibility.md](docs/compatibility.md).

The distribution also includes Testing v2: the CLI selects a scenario through
a fixed control protocol, requires a matching native `TestContext` receipt, and
exposes semantic `coverage`, `gaps`, bounded `stress`, deterministic `replay`,
and validated `history`. Public `zstd.Testing` modules cover statechart models,
schedules, structural shrinking, differential executors, distributed virtual
faults, mutation analysis, performance budgets, and side-effect authority. See
[docs/agent-first-testing.md](docs/agent-first-testing.md).

Every first-party and template-v11 `b.addTest` artifact also uses the
`zigeffect_test_runner` server runner. It preserves idiomatic `std.testing`
tests while atomically emitting complete suite receipts under
`.zigeffect/tests/suites/`; missing executions, failures, leaks, and logged
errors fail closed.

## Tools

The `tools/` directory holds the 46 approved CLI tools (causal harness, query
interface, dev loop, remediation chain, app-facing chain, workbench, and
workflow/cluster inspection). The authoritative list and the rules for adding a
tool are in [docs/tool-roadmap.md](docs/tool-roadmap.md).

**Tool hygiene is enforced.** `tools/check_tool_hygiene.sh` (run in CI and as a
pre-commit hook) blocks recursive "report-about-a-report" names, numbered tier
clones, oversized files, tool-count blowups, and new `.zig` tools that do not
import or explicitly exercise runtime symbols. A new tool must add runtime
capability, not paperwork — see the Tool Hygiene Policy in `AGENTS.md` /
`CLAUDE.md`. This guardrail exists because an autonomous loop once generated ~120
record-only clone tools; see [docs/roadmap.md](docs/roadmap.md).

## Docs

The [documentation index](docs/README.md) separates tutorials, operational
guides, references, and migration records.

Start here:

1. [Usage](docs/usage.md)
2. [Compositional applications](docs/compositional-applications.md)
3. [Module pattern](docs/module-pattern.md)
4. [Architecture](docs/architecture.md)

Build and test applications:

- [How Codex builds applications](docs/agent-first-application-development.md)
- [Agent guide](docs/agent-guide.md)
- [Agent-first testing](docs/agent-first-testing.md)
- [Errors](docs/errors.md) and [resource ownership](docs/resource-ownership.md)
- [gRPC, Connect, and Cloud Run](docs/grpc-cloud-run.md)

Operate and debug the runtime:

- [Agent-observable causal runtime](docs/agent-observable-runtime.md)
- [Causal scenarios](docs/causal-scenarios.md)
- [Causal development harness](docs/causal-dev-harness.md)
- [Local agentic development](docs/local-agentic-development.md)
- [Agent safety plane](docs/agent-safety-plane.md)
- [Operations](docs/operations.md)

Reference and status:

- [Data](docs/data.md) and [pattern matching](docs/pattern-matching.md)
- [Schema governance](docs/schema-governance.md)
- [Performance budget](docs/performance-budget.md)
- [Effect concepts](docs/effectts-parity.md)
- [Developer-experience review](docs/devex-review.md)
- [Roadmap](docs/roadmap.md) and [tool roadmap](docs/tool-roadmap.md)
- [Migration to durable runtime](docs/migration-to-durable-runtime.md)
