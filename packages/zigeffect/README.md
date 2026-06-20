# zigeffect

`zigeffect` is a Zig-native, Effect-inspired core for composing direct-style Zig
programs — with a deterministic **agent-observable causal runtime** at its
center: the engine records execution as a structured, queryable causal event
graph so LLM agents and humans can debug by asking the runtime precise questions
instead of reconstructing behavior from logs.

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

## The engine

- **`Effect`**: `fromFn`, `succeed`, `fail`, `sync`, `run`, `exit`, `retry`,
  `repeat`, `map`, `flatMap`, `tap`, `onExit`, `ensuring`, and recovery helpers.
- **`Runtime` / `FiberRuntime` / `Fiber`**: engine-managed scopes with automatic
  cleanup, and deterministic fork/join/interrupt with scoped leases. The fiber
  runtime is semantic-first and deterministic — it does not claim real
  green-thread suspension; a future async backend adapter provides that.
- **`Deferred`, `Queue`, `Semaphore`**: deterministic coordination primitives
  with explicit wait-state/backpressure inspection.
- **`Context`**, **`acquireRelease`**, **`Scope`**: typed service access and
  scoped, reverse-order, exit-aware finalization.
- **`Layer` / `layerGraph`**: dependency environments, scoped builders, typed
  startup errors, executable heterogeneous graph startup with dependency
  ordering, memoization, and readable dependency diagnostics.
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

See [docs/usage.md](docs/usage.md), [docs/architecture.md](docs/architecture.md),
[docs/effectts-parity.md](docs/effectts-parity.md), and the
[examples/](examples/) directory.

## The agent-observable causal runtime

Attach a `CausalStore` to a runtime, fiber runtime, layer graph, or context, and
the engine emits compact structural events — run start/end, scope open/close,
fiber fork/join/interrupt, service resolution, resource acquire/finalize, retry
decisions, exits — into one causal event graph keyed by `run_id`, `parent_id`,
`fiber_id`, `scope_id`, `cause_event_id`, and friends. Agents then query
`snapshot`, `lineage`, `cause`, `resources`, `fibers`, `requirements`,
`retries`, and `findings` instead of scanning a text report.

Causal JSON artifacts use the `zigeffect.causal.v1` schema and disclose retention
(`max_events`, `dropped_events`), sampling (`sampled_events`), and truncation
(`truncated_fields`) so agents know when evidence is incomplete. Event strings are
defensively redacted before storage. The event taxonomy classifies each kind as
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

### App-facing causal traces

Record app request / background-job incidents with the same causal vocabulary
from a Cloudflare Worker–shaped path, keeping the request path pure:

```zig
var store = fx.CausalStore.initWithOptions(
    allocator,
    fx.defaultRequestCausalStoreOptions(),
);
defer store.deinit();

var trace = try fx.CausalAppTrace.startRequest(&store, .{
    .method = "GET",
    .route = "/api/projects/:id",
    .runtime = "worker",
});
try trace.recordServiceResolution("ProjectService", "satisfied");
try trace.complete(.success);

const json = try fx.formatCausalJson(allocator, &store);
defer allocator.free(json);
```

These emit normal `zigeffect.causal.v1` events, so app artifacts open in the same
workbench and answer the same `causal-query` commands.

### Visual workbench

`causal-workbench` builds a read-only SolidJS renderer (via `zig-webui`) over a
saved artifact, with timeline, findings, relationship, query, metadata, graph,
and chain views:

```bash
zig build causal-test
zig build causal-workbench -- .zig-cache/causal-artifacts/zigeffect-causal-dogfood.json
zig build causal-workbench -- --server-only <artifact.json>   # for agent/browser inspection
```

### Export adapters

Backend adapters are sinks, not the source of truth (if `failed_writes` is
nonzero, fall back to the in-memory trace): JSON Lines, DOT, OpenTelemetry-shaped
records, scan-based graph history, a NenDB node/edge write-contract, and a bounded
async stream. Each has a focused gate (`zig build causal-*-backend`).

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

## Tools

The `tools/` directory holds the 46 approved CLI tools (causal harness, query
interface, dev loop, remediation chain, app-facing chain, workbench, and
workflow/cluster inspection). The authoritative list and the rules for adding a
tool are in [docs/tool-roadmap.md](docs/tool-roadmap.md).

**Tool hygiene is enforced.** `tools/check_tool_hygiene.sh` (run in CI and as a
pre-commit hook) blocks recursive "report-about-a-report" names, numbered tier
clones, oversized files, and tool-count blowups. A new tool must add runtime
capability, not paperwork — see the Tool Hygiene Policy in `AGENTS.md` /
`CLAUDE.md`. This guardrail exists because an autonomous loop once generated ~120
record-only clone tools; see [docs/roadmap.md](docs/roadmap.md).

## Docs

- [Usage](docs/usage.md) · [Architecture](docs/architecture.md) ·
  [Errors](docs/errors.md) · [Resource Ownership](docs/resource-ownership.md)
- [Data](docs/data.md) · [Pattern Matching](docs/pattern-matching.md) ·
  [Module Pattern](docs/module-pattern.md) · [EffectTS Parity](docs/effectts-parity.md)
- [Agent-Observable Causal Runtime](docs/agent-observable-runtime.md) ·
  [Agent Guide](docs/agent-guide.md) · [Causal Scenarios](docs/causal-scenarios.md) ·
  [Causal Dev Harness](docs/causal-dev-harness.md)
- [Operations](docs/operations.md) · [Schema Governance](docs/schema-governance.md) ·
  [Performance Budget](docs/performance-budget.md) ·
  [Self-Improving AI Engine](docs/self-improving-ai-engine.md)
- [Roadmap](docs/roadmap.md) · [Tool Roadmap](docs/tool-roadmap.md) ·
  [Devex Review](docs/devex-review.md) ·
  [Migration to Durable Runtime](docs/migration-to-durable-runtime.md)
