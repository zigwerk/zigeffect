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

The application-facing standard library now uses the canonical kernel
throughout. Environment-shaped effects and layer graphs are quarantined inside
the framework's retired engine tests; they are not exported by `zigeffect_std`
modules or accepted by the architecture gate. See the
[canonical migration roadmap](docs/effect-native-roadmap.md) for the completed
surface and remaining low-level engine retirement work.

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
  `Service` provides semantic operation helpers for canonical service APIs.
- `Schema` validates, decodes, encodes, transforms, and derives JSON/config
  boundaries with path-aware redacted issue lists.
- `Parser` defines bounded, owned source-document facts and a replaceable parser
  service/layer. The optional `zigeffect-parser` package supplies the pinned
  native TypeScript/TSX/JavaScript/JSX provider, an offline Zig-native
  Proto2/Proto3/Editions provider, and a compiler-AST Zig provider with richer
  lexical binding evidence. Structural-facts v4 includes exact ordered call
  arguments and direct-call result bindings for framework-neutral recipe
  analysis; the richer direct Zig result remains outside that common contract
  until a lossless schema revision.
- `Json` writes deterministic redacted JSON payloads.
- `Jsonl` appends and parses newline-delimited JSON feeds.
- `Stream` re-exports engine pull streams and adds local line helpers.
- `Sink` provides deterministic memory line sinks with redacted JSONL receipts.
- `Queue` and `PubSub` expose stable tags, operation effects, and replaceable
  memory/live layers.
- `Cli` parses deterministic command specs, nested subcommands, Schema-powered
  typed options, source-aware defaults, built-ins, completions, effect-native
  handlers, exit-code mapping, run receipts, and a replaceable Runner service.
- `Console` exposes requirement-free stdout/stderr effects over the runtime
  default plus captured/live override adapters.
- `Env` provides owned environment data and canonical lookup effects; service
  requirements remain tags rather than environment structs.
- `Config` exposes a requirement-free lookup effect over the runtime default
  ConfigProvider plus layered deterministic override data.
- `Secrets` provides redaction, secret references, audits, and replaceable
  resolver services/layers.
- `FileSystem` defines the stable `zigeffect/std/FileSystem` service, canonical
  read/write/remove/exists effects, and memory/local layers.
- `Path` joins, normalizes, and splits project paths.
- `Workspace` provides a stable service, layers, and effects for project roots,
  snapshots, changes, and ignore-aware diffs.
- `Process` defines the stable `zigeffect/std/Process` service, a canonical run
  effect, and fake/local layers with bounded capture and redacted receipts.
- `Observability` provides a stable recorder service plus logging, metric,
  span, artifact, and redacted workbench/OTLP effects. Structural visibility
  comes from runtime aspects.
- `Testing` provides JSON and sentinel-secret assertions.
- `Clock` exposes requirement-free time and sleep effects over the runtime
  default Clock reference.
- `Randomness` exposes requirement-free fill and integer effects over the
  runtime default Random reference plus cryptographic/deterministic overrides.
- `Ids` derives UUIDv7 and monotonic ULID values from Clock and Randomness
  through a selectable canonical ID-policy service.
- `Schedule` provides deterministic retry/polling steppers.
- `Resource` defines refreshable scoped service values. A successful refresh
  swaps acquisition scopes and finalizes the replaced value; a failed refresh
  preserves the last successful value.
- `Pool` defines bounded scoped resource services with preallocation, reuse,
  invalidation, TTL pruning, per-item concurrency, explicit exhaustion, and
  complete partial-startup unwind. Construction dependencies remain layer
  inputs; consumers require only the pool tag.
- `Sql` defines SQL query contracts, owned results, Schema-backed
  row decoding, fake databases, transaction receipts, migrations, pool
  leases/stats, migrations, stable database/pool tags, and scoped layers. Live
  Postgres implementations live in the adapter packages.
- `Http` defines one portable client contract shared by live, fake, and
  scripted transports. Responses own their headers and bodies, header lookup is
  case-insensitive, and provider clients receive typed timeout, cancellation,
  body-limit, and transport failures plus parsed `Retry-After` metadata. It also
  provides deterministic memory routing, Schema-coded local JSON routes,
  credential-safe request redaction, route receipts/traces, WebSocket codecs,
  and canonical client/server/router tags with scoped adapter layers.
- `Grpc` is the repository-owned gRPC protocol and Effect boundary derived from
  the public-domain gRPC-zig source material. It provides canonical bounded
  message framing, fragmented stream decoding, metadata and deadlines,
  statuses and trailers, exact method routing, unary and streaming call shapes,
  fake/scripted/in-process providers, health state, qualified transports,
  secret-free receipts, and causal `grpc.call` facts. Live HTTP/2 transports
  must prove TLS, trailers, cancellation, multiplexing, connection reuse, flow
  control, bounds, and redacted diagnostics before qualification. The native
  `packages/zigeffect-grpc` adapter supplies that boundary with generated
  client/route layers, native server/channel layers, all four RPC shapes, and
  Python gRPC interoperability evidence.
- `Agent` records workbench-compatible local agent JSONL sessions, Codex and
  Claude Code process adapter commands, guardrails, artifacts, check receipts,
  effect-native process-backed agent runs, and supervised local multi-tool
  sessions with redacted stdout/stderr artifacts through a canonical session
  service and Process dependency.
- `Statechart.Effect` turns a pure typed machine definition into a service
  layer and requirement-typed step effect whose decisions are recorded into
  the owning causal graph.
- `Workflow` provides a journal service/layer plus append and replay effects so
  durable work composes with ordinary application services.
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
