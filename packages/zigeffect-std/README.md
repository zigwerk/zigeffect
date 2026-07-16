# zigeffect-std

`zigeffect-std` is the one-import standard library facade for zigeffect
applications. It depends on `packages/zigeffect` and keeps application-facing
tooling outside the pure engine package.

```zig
const zstd = @import("zigeffect_std");
```

The canonical application model is one root layer and one managed runtime:

```zig
var files = zstd.FileSystem.MemoryFileSystem.init(allocator);
defer files.deinit();
var process = zstd.Process.FakeRunner.init(.{ .exit_code = 0, .stdout = "ok" });

const MainLayer = zstd.fx.kernel.Layer.mergeAll(.{
    zstd.FileSystem.memory(&files),
    zstd.Process.fake(&process),
});
var runtime = try zstd.ManagedRuntime(@TypeOf(MainLayer)).make(
    allocator,
    io,
    root,
    MainLayer,
    .{},
);
defer runtime.deinit();

try runtime.run(zstd.FileSystem.writeFile("ready.txt", "ready"));
try runtime.shutdown();
```

Programs name stable services, layers choose implementations, and the managed
runtime owns the embedded durable NenDB graph. Runtime defaults and
standard-library boundaries emit
structural and semantic evidence through causal storage, logging, metrics, and
tracing automatically.

The standard library migration is incremental. `fx.kernel`, runtime-default
facades, and the canonical FileSystem/Process service pattern are the reference
architecture. Modules that still expose `EffectEnv`, provider tuples, or
`layerGraph` are compatibility surfaces, not examples to copy. See the
[canonical migration roadmap](docs/effect-native-roadmap.md) for exact status.

## Verify

```sh
cd packages/zigeffect-std
zig build test
zig build examples
```

From the repository root:

```sh
bun run zigeffect:std:test
```

## Cookbook

The [local-tools cookbook](docs/cookbook.md) contains examples that compile as
part of `zig build examples` and show how to build real local developer tools
with one import:

- `examples/schema_cli.zig` for Schema-powered typed CLI input.
- `examples/workspace_doctor.zig` for workspace snapshots, fake checks, and
  redacted receipts.
- `examples/agent_dev_session.zig` for workbench-compatible agent JSONL.
- `examples/agent_supervisor.zig` for supervised local agent/tool runs with
  redacted artifacts.
- `examples/http_router.zig` for Schema-coded local HTTP routes with receipts
  and traces.
- `examples/grpc_unary.zig` for exact in-process gRPC method routing through
  the same contract used by qualified native transports.
- `examples/http_sql_smoke.zig` for local HTTP/SQL contract smoke tests.
- `examples/local_toolbelt.zig` for a composed local automation command.
- `examples/causal_graph.zig` for restart-safe local graph persistence and
  bounded read queries.

## Modules

- `fx.kernel` is the canonical service/effect/layer kernel and low-level,
  I/O-free managed interpreter.
  `Service` currently contains migration helpers for legacy modules and is not
  the application composition API.
- `Schema` validates, decodes, encodes, transforms, and derives JSON/config
  boundaries with path-aware redacted issue lists.
- `Json` writes deterministic redacted JSON payloads.
- `Jsonl` appends and parses newline-delimited JSON feeds.
- `Stream` re-exports engine pull streams and adds local line helpers.
- `Sink` provides deterministic memory line sinks with redacted JSONL receipts.
- `Queue` wraps engine queues; its stable-tag canonical layer migration is
  pending S3.
- `PubSub` wraps engine hubs; its stable-tag canonical layer migration is
  pending S3.
- `Cli` parses deterministic command specs, nested subcommands, Schema-powered
  typed options, source-aware defaults, built-ins, completions, effect-native
  handlers, exit-code mapping, and run receipts. Command-to-effect routing is
  behavior-complete; canonical runtime launch is pending S5.
- `Console` exposes requirement-free stdout/stderr effects over the runtime
  default plus captured/live override adapters.
- `Env` provides an owned environment map for deterministic local runs; it is
  not the canonical effect requirement model and migrates under S3.
- `Config` exposes a requirement-free lookup effect over the runtime default
  ConfigProvider plus layered deterministic override data.
- `Secrets` provides shared redaction and secret-display helpers; a portable
  secret-reference resolver service remains pending S3.
- `FileSystem` defines the stable `zigeffect/std/FileSystem` service, canonical
  read/write/remove/exists effects, and memory/local layers.
- `Path` joins, normalizes, and splits project paths.
- `Workspace` models local project roots, snapshots, changed files, ignore
  filtering, and snapshot/diff operations. Its canonical FileSystem-dependent
  service layer remains pending S3.
- `Process` defines the stable `zigeffect/std/Process` service, a canonical run
  effect, and fake/local layers with bounded capture and redacted receipts.
- `Observability` provides semantic annotations and redacted workbench/OTLP
  shapes. Structural visibility comes from runtime aspects; legacy provider
  wrappers remain migration debt.
- `Testing` provides JSON and sentinel-secret assertions.
- `Clock` exposes requirement-free time and sleep effects over the runtime
  default Clock reference.
- `Randomness` exposes requirement-free fill and integer effects over the
  runtime default Random reference plus cryptographic/deterministic overrides.
- `Ids` derives UUIDv7 and monotonic ULID values from Clock and Randomness. Its
  selectable ID-policy service is not yet canonical.
- `Schedule` provides deterministic retry/polling steppers.
- `Sql` defines SQL query contracts, owned results, Schema-backed
  row decoding, fake databases, transaction receipts, migrations, pool
  leases/stats, and lifecycle facts. The local Postgres adapter lives in
  `packages/zigeffect-postgres`; canonical service and scoped pool layers are
  pending S4.
- `Http` defines one portable client contract shared by live, fake, and
  scripted transports. Responses own their headers and bodies, header lookup is
  case-insensitive, and provider clients receive typed timeout, cancellation,
  body-limit, and transport failures plus parsed `Retry-After` metadata. It also
  provides deterministic memory routing, Schema-coded local JSON routes,
  credential-safe request redaction, route receipts/traces, and WebSocket frame
  codecs for local workbench feeds. Canonical client/server tags and scoped
  adapter layers are pending S4.
- `Grpc` is the repository-owned gRPC protocol and Effect boundary derived from
  the public-domain gRPC-zig source material. It provides canonical bounded
  message framing, fragmented stream decoding, metadata and deadlines,
  statuses and trailers, exact method routing, unary and streaming call shapes,
  fake/scripted/in-process providers, health state, qualified transports,
  secret-free receipts, and causal `grpc.call` facts. Live HTTP/2 transports
  must prove TLS, trailers, cancellation, multiplexing, connection reuse, flow
  control, bounds, and redacted diagnostics before qualification. The native
  `packages/zigeffect-grpc` adapter supplies that qualified boundary with all
  four RPC shapes and Python gRPC interoperability evidence. Its application
  composition remains on the documented compatibility bridge until the native
  gRPC roadmap reaches G5.
- `Agent` records workbench-compatible local agent JSONL sessions, Codex and
  Claude Code process adapter commands, guardrails, artifacts, check receipts,
  effect-native process-backed agent runs, and supervised local multi-tool
  sessions with redacted stdout/stderr artifacts. Higher-level canonical
  program migration is pending S6.
- `Application` records stable semantic facts for config loads, Schema decodes,
  CLI commands, requests, SQL transactions, external calls, artifacts,
  component dependencies, and acceptance checks. It reuses the core causal
  taxonomy, emits redacted `span_recorded` facts, writes bounded fact receipts,
  and compares executor traces by semantic shape rather than event ids.
- `ManagedRuntime` is the canonical application process root. It composes the
  kernel interpreter with a bounded recorder, embedded NenDB topology, durable
  property WAL, manifest-enriched agent map, and checked shutdown. Tests may
  supply a `TestContext` store at this root; the runtime restores its previous
  backend and never assumes ownership of the supplied store.
- `CausalGraph` provides the runtime-owned embedded NenDB graph, restart-safe
  durable event ids, complete bounded property records, parent-child traversal,
  partial-tail recovery, committed-corruption detection, ordered delta queries,
  and read-only snapshots. The reviewed Zig 0.16 NenDB port and exact upstream
  revision are reported in runtime health.
- `Development` provides exact receipt reconciliation, content-addressed source
  and manifest identities, the deterministic budgeted context compiler,
  automatic test proof handoffs, journal-backed task statecharts, fenced
  leases, work packets, proof verification, graph federation, and bounded
  structural repair memory as replaceable services and layers. It is the
  programmatic implementation behind `zigeffect agent context` and Ziac's
  read-only `ziac_context` endpoint.
- `Project` defines the validated `zigeffect.project.v1` manifest, component
  dependency graph, requirements, acceptance checks, fixed command IDs,
  deterministic owned file plans, and redacted scaffold receipts used by the
  application-development CLI.
- `Statechart` owns the manifest-selected definition catalog and portable
  projections. `registerDefinitionAtomic` safely registers typed engine
  definitions without replacing other machines, is idempotent for an unchanged
  id/version, serializes concurrent writers, and rejects changed definitions
  that reuse a released version. Live decisions remain runtime causal facts;
  the catalog is their definition and visualization surface.
- `Safety` defines the `agent_safe_v1` project policy, parser-backed governed
  construct analysis, exact fingerprinted allowances, compiler diagnostics,
  bounded evidence completeness, and versioned safety receipts. Unknown,
  stale, unsupported, truncated, and unrun evidence never becomes a pass.
- `fx` re-exports the base zigeffect engine facade.

Clock, Console, Randomness, and Config are runtime defaults: their canonical
operations have no explicit service requirement and can be overridden for a
run. FileSystem and Process are explicit portable services: their canonical
operations require stable tags, while memory/fake/local implementations are
selected by layers.

The runtime records structural layer, effect, resolved-service, scope, fiber,
resource, and finalizer facts automatically. Standard-library operations emit
semantic events through the same RuntimeAspect fanout. Applications do not pass
around a causal store, logger, metrics registry, or tracer merely to be
observable.

The rest of the package is being migrated in the order documented in
`docs/effect-native-roadmap.md`; the pinned Effect comparison and Zig-specific
decisions are recorded in `docs/effect-reference-review.md`.
Environment-parameterized `*Effect` types,
`zstd.Service.Provider`, `ValueProvider`, and `zstd.fx.layerGraph` are legacy
surfaces for unmigrated modules; new application code must not use them.

```zig
const MainLayer = zstd.fx.kernel.Layer.mergeAll(.{
    zstd.FileSystem.local(&local_files),
    Orders.Default(),
});
var runtime = try zstd.ManagedRuntime(@TypeOf(MainLayer)).make(
    allocator,
    io,
    root,
    MainLayer,
    .{ .observability = production_observability },
);
defer runtime.deinit();

const result = try runtime.run(Orders.create(command));
try runtime.shutdown();
```

The public surface is:

```zig
zstd.Service
zstd.Schema
zstd.Json
zstd.Jsonl
zstd.Stream
zstd.Sink
zstd.Queue
zstd.PubSub
zstd.Cli
zstd.Console
zstd.Env
zstd.Config
zstd.Secrets
zstd.FileSystem
zstd.Path
zstd.Workspace
zstd.Process
zstd.Observability
zstd.Testing
zstd.Clock
zstd.Schedule
zstd.Sql
zstd.Http
zstd.Grpc
zstd.Agent
zstd.Application
zstd.CausalGraph
zstd.ManagedRuntime
zstd.CausalRuntime
zstd.Project
zstd.Safety
```

## Project Contract

`zstd.Project.Manifest` fails closed on unknown schema versions, malformed
identifiers, unsafe paths, duplicate components or capabilities, missing or
cyclic dependencies, invalid commands, broken requirement/check references, and
secret-bearing values. `zstd.Project.FilePlan` owns and sorts generated files so
dry-runs and filesystem writes consume the same deterministic plan.

## Application Facts

Record application intent from an effect context with the typed constructors:

```zig
_ = zstd.Application.record(
    ctx,
    zstd.Application.schemaDecode("Invoice.v1", "success", "validated input"),
);
```

`zstd.Application.tracesEquivalent` first applies the engine's structural
comparison and then checks application fact status, references, parent shape,
and cause shape. Runtime snapshots and `receiptJsonAlloc` redact
secret-shaped values before they become agent or workbench artifacts.

## Schema

Use the simple APIs when a fast-fail boundary is enough:

```zig
const port = try zstd.Schema.decodeJsonAlloc(
    allocator,
    zstd.Schema.integer().min(1).max(65535),
    "5178",
);
```

Use detailed decoding for production CLI/config/API boundaries where callers
need every failure at once:

```zig
const AppConfig = struct {
    name: []const u8,
    port: i64,
    enabled: bool,
    mode: ?[]const u8,
};

const schema = zstd.Schema.derive(AppConfig, .{
    .name = zstd.Schema.string().nonEmpty(),
    .port = zstd.Schema.integer().min(1).max(65535),
    .enabled = zstd.Schema.boolean(),
    .mode = zstd.Schema.optional(zstd.Schema.stringEnum(&.{ "local", "ci" })),
});

var result = try zstd.Schema.decodeDetailedJsonAlloc(allocator, schema, json);
defer result.deinit();

if (!result.ok()) {
    const issues_json = try result.issues.jsonAlloc(allocator);
    defer allocator.free(issues_json);
}
```

Schemas support primitive constraints, defaults, arrays, structs, enums, named
transforms with inverse encoders, config decoding, deterministic JSON encoding,
and redacted issue JSON.

## CLI

The legacy parser API remains available. New local tools can use typed commands
backed by `zstd.Schema`:

```zig
const Args = struct {
    workspace: []const u8,
    port: i64,
    watch: bool,
};

const command = zstd.Cli.typedCommand(Args, .{
    .name = "serve",
    .description = "run local server",
    .version = "0.1.0",
}, .{
    zstd.Cli.option("workspace", zstd.Schema.string().nonEmpty(), .{
        .long = "workspace",
        .env = "ZG_WORKSPACE",
        .config_key = "workspace",
        .required = true,
        .help = "workspace root",
    }),
    zstd.Cli.option("port", zstd.Schema.integer().min(1).max(65535), .{
        .long = "port",
        .default_value = "5178",
        .help = "local HTTP port",
    }),
    zstd.Cli.flag("watch", .{
        .long = "watch",
        .short = 'w',
        .help = "rerun on file changes",
    }),
});
```

Typed commands decode `cli > env > config > default`, accumulate redacted
Schema issues, generate deterministic help/completion output, and can run
through `runTypedEffect` with causal service facts.

## Examples

The first example is intentionally small: it proves the one-import facade can
parse a command and write output through a testable service. The cookbook
examples exercise the production local-development path.

```sh
cd packages/zigeffect-std
zig build examples
```

## Documentation

- [Cookbook](docs/cookbook.md): compile-tested examples and their boundaries.
- [Canonical migration roadmap](docs/effect-native-roadmap.md): module-by-module
  status and deletion gates.
- [Effect reference review](docs/effect-reference-review.md): concepts adopted,
  adapted, or rejected for Zig.
- [Core compositional applications](../zigeffect/docs/compositional-applications.md):
  the service/effect/layer/runtime model used by the facade.
