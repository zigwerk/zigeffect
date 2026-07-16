# ZigEffect Standard Library Canonical Migration Roadmap

The architectural comparison behind this roadmap is recorded in
`effect-reference-review.md`.

**Audited:** 2026-07-15
**Status:** canonical kernel admitted; S1-S2 and the portable/native gRPC slice
of S4 are landed. Remaining capabilities are migration work, and legacy
prototypes are not accepted as evidence.

The canonical application algebra and local scaffold are now landed. Effects
compose fluently with inferred service/error unions, layers compose with
`provide`/`provideMerge`/`merge`, semantic program names become causal parents,
and generated local applications use one `zstd.ManagedRuntime`. Generated
libraries export effects and default layers without owning a runtime.
Production adapter scaffolds remain legacy until HTTP, Postgres, and OTEL
publish canonical layers; they are not migration evidence.

| Surface | Status | Use in new code? |
| --- | --- | --- |
| `fx.kernel.Service`, `Effect`, `Layer` | Canonical | Yes |
| `zstd.ManagedRuntime` | Canonical application process root | Yes |
| `fx.kernel.ManagedRuntime` | I/O-free low-level interpreter | Framework tests/custom platforms only |
| Canonical `FileSystem` and `Process` effects/layers | Landed migration oracles | Yes |
| Runtime-default Clock, Config, Console, Random | Canonical facade partly landed | Yes, through their canonical operations |
| `Service.Provider`, `ValueProvider`, `EffectEnv`, `layerGraph` | Legacy migration surface | No |
| HTTP, SQL, OTEL, and remaining std provider layers | Migration pending | Do not copy their wiring pattern |

## Finding

The standard library contains useful contracts, deterministic implementations,
typed failures, and resource wrappers, but much of it is still built on the
legacy dependency kernel. The architecture ratchet currently finds 321
selected legacy references under `zigeffect-std/src`. It fails if that number
rises, while canonical gRPC surfaces must remain at zero.

`Service.Provider`, `ValueProvider`, `layerFromEnv`, `EffectEnv`, and
`Application.run(layers, effect)` make features look composable while retaining
one concrete environment tuple. Earlier roadmap entries marked several
capabilities “landed” when those facades existed. They must be migrated again;
none counts as complete against `fx.kernel`.

## Standard Library Boundary

| Kind | Canonical home | Examples |
| --- | --- | --- |
| Pure data and algorithms | ordinary Zig APIs | Schema, Path, codecs, redaction, schedule data |
| Runtime defaults | ZigEffect kernel, re-exported by std | Clock, ConfigProvider, Console, Random, Tracer |
| Runtime aspects | ZigEffect kernel/adapters | logging, metrics, tracing, supervisor, causal evidence |
| Application capabilities | stable service tags + effects | FileSystem, Process, HttpClient, Sql, Queue, ObjectStorage |
| Resource implementations | scoped layers | pools, listeners, local stores, brokers, subprocesses |
| Platform drivers | adapter packages | libpq, native gRPC, Redis, S3, OTLP |

The standard library is not a second runtime. It supplies portable contracts,
effect constructors, live/test layer constructors, and facades for kernel
defaults. Drivers stay imperative below those boundaries.

## Defaults Are Not Ordinary Requirements

Clock, ConfigProvider, Console, Random, and Tracer are installed by the runtime.
Their ordinary operations do not add application service requirements.
`zstd.Clock`, `zstd.Console`, and related namespaces wrap the kernel defaults
and expose lexical/scoped override operations for tests.

IDs are not a runtime default. An ID policy can be an explicit service/layer
when applications need a selectable UUID/ULID strategy; its live layer may use
default Clock and Random during operation.

Logging, metrics, tracing, supervision, and structural causal recording are
runtime aspects. `zstd.Observability` retains semantic annotations, span names,
metric instruments, and logger configuration, but application effects do not
request an observability provider merely to be visible.

## Inventory

### Retain as pure APIs

- Schema, Path, Capability, Boundary, Safety, and pure External policies;
- JSON/JSONL encoding and decoding where no I/O occurs;
- protocol codecs and message/status data under Http/Grpc/Sql;
- statechart definitions and deterministic transitions;
- causal query/diff/redaction data structures; and
- Testing v2 assertions, receipts, and deterministic scenario data.

### Rewrite as explicit services and layers

| Capability | Service output | Typical construction input | Lifetime |
| --- | --- | --- | --- |
| FileSystem | `zstd/FileSystem` | platform I/O/default config | application or test |
| Workspace | `zstd/Workspace` | FileSystem | application |
| Process | `zstd/Process` | platform I/O | per operation; runner app-scoped |
| HttpClient | `zstd/HttpClient` | credentials/config defaults | pool app-scoped |
| Sql | `zstd/Sql` | config/credentials | pool app-scoped; transaction run-scoped |
| Queue/PubSub/Sink | stable capability tags | bounds/config | application; subscriptions run-scoped |
| Cache/Broker/ObjectStorage | portable tags | adapter/config | client/pool application-scoped |
| Secrets | secret-reference resolver tag | config/credential source | application |

Construction inputs belong to layer `InputServices`; they do not appear on the
operations of the service output.

## Target Developer Experience

```zig
const kernel = zstd.fx.kernel;

var files = zstd.FileSystem.MemoryFileSystem.init(allocator);
defer files.deinit();
var process = zstd.Process.FakeRunner.init(.{
    .exit_code = 0,
    .stdout = "ok",
});

const MainLayer = kernel.Layer.mergeAll(.{
    zstd.FileSystem.memory(&files),
    zstd.Process.fake(&process),
});

var runtime = try zstd.ManagedRuntime(@TypeOf(MainLayer)).make(
    allocator,
    io,
    root,
    MainLayer,
    .{ .observability = production_observability },
);
defer runtime.deinit();

try runtime.run(App.main(args).named("application.main"));
try runtime.shutdown();
```

No std-facing domain API names a concrete environment, provider tuple,
`LayerGraphEnv`, narrowed runner, or manually assembled causal store.

## Ordered Gates

### S0 — Kernel admission gate

Do not migrate std until the canonical kernel proves:

- requirement-typed effects and compile-time service access;
- `Layer<Output, Error, Input>` with explicit `provide` semantics;
- identity memoization and reverse finalization;
- heap-stable ManagedRuntime and requirements-limited RuntimeHandle;
- all runtime defaults with inherited scoped overrides; and
- causal/logger/metrics/tracer/supervisor aspect hooks.

The canonical kernel now proves the admission set, including all five default
references, inherited overrides, aspect fanout, managed-runtime application
snapshots, and a reference server using one RuntimeHandle. S0 is complete.

### S1 — Runtime defaults

Replace the std Clock, Config, Console, Randomness, and tracing provider tuples
with facades over kernel defaults. Migrate live and deterministic override tests.
Delete their `EffectEnv` constructors.

**Current:** canonical Clock, Console, Random, and ConfigProvider operations
have landed with inherited overrides and semantic aspect fanout. Tracer-facing
application span combinators and deletion of the legacy `EffectEnv`
constructors remain.

### S2 — Service definition pattern

Choose FileSystem and Process as migration oracles. Each must have:

- one stable tag and abstract API;
- effects carrying only that tag;
- live and deterministic layers;
- typed/redacted failures;
- scoped ownership where needed; and
- identical programs running against live and fake layers.

Only after both pass should the pattern be copied to other namespaces.

**Current:** FileSystem and Process now expose stable tags, implementation-
independent effects, typed failures, deterministic/live layer constructors,
application-topology evidence, and causally linked operation pairs. Legacy
implementation-typed constructors remain only to support unmigrated consumers
and must be deleted as those consumers move.

### S3 — Local data and messaging

Migrate Env/Secrets, Workspace, Queue, PubSub, Sink, Cache, Broker,
ObjectStorage, and Outbox. Prove bounds, cancellation, acknowledgement,
transactional ownership, replay, and finalization.

### S4 — Adapter facades

Migrate Http and Sql contracts, then consume scoped layers from the owning
adapter packages. Connection pools belong to the managed runtime; requests and
transactions belong to child scopes.

**Current:** the portable gRPC client tag/call effect, generated clients and
handlers, registry ownership, native channel/pool/server resources, standard
health/reflection services and Cloud Run composition are canonical. Libraries
own no runtime or graph; the consuming application owns one durable runtime.

### S5 — Application and CLI

Introduce `Application.launch` only on the canonical kernel; the discarded
compatibility-first prototype must not return. The launcher constructs one
ManagedRuntime for the process, runs the root effect, drains, flushes evidence,
and disposes once. CLI command routing selects effects; it does not construct
environments or runtimes per handler.

### S6 — Higher-level programs

Migrate Agent, Resilience, lifecycle, durable Statechart, and CausalGraph
storage. Long-lived loops derive RuntimeHandles and run each event in a child
scope. Semantic causal facts remain explicit; structural facts come from
aspects.

### S7 — Scaffold and deletion

Generate tag contracts, live/test layers, one root layer, and one managed
runtime. Then delete `Service.Provider`, `ValueProvider`, `layerFromEnv`,
environment-typed constructors, and legacy std examples.

**Current:** template schema v11 local application/service and library projects,
plus generated service/layer modules, use canonical tags, effects, fluent
layers, named programs, application inspection, and ManagedRuntime. The real
production profile remains on legacy adapter layers and blocks S7 completion.

## Definition of Done

- no `Context(Env)`, `Effect(..., Env)`, `Layer(Env)`, or `Runtime(Env)` in std;
- defaults are ambient and overrideable without ordinary requirements;
- every external capability has live and deterministic layers;
- application resources finalize once, run resources once per run;
- examples use one ManagedRuntime and no per-program provision;
- structural evidence appears without feature instrumentation; and
- Testing v2 receipts are complete with zero pending tests, leaks, and logged
  errors.
