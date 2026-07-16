# ZigEffect standard-library cookbook

This cookbook contains local-first examples that compile through:

```sh
cd packages/zigeffect-std
zig build examples
```

Each example imports only the public facade:

```zig
const zstd = @import("zigeffect_std");
```

These are compile-tested capability examples. Every effectful example uses
`zstd.fx.kernel` and one `ManagedRuntime`; their layer composition is safe to
copy into an application root.

## `schema_cli.zig`

Use this pattern for production local tools with typed arguments.

Modules exercised:

- `zstd.Cli`
- `zstd.Schema`
- `zstd.Env`
- `zstd.Config`
- `zstd.Testing`

What it proves:

- CLI input wins over env, config, and defaults.
- Typed options decode into a Zig struct.
- Invalid values produce path-aware Schema issue JSON.
- Secret-looking values do not appear in issue payloads.

The example decodes `workspace`, `port`, `watch`, and `mode`. It is the
starting point for EffectTS-style local commands where command input is a real
typed boundary, not ad-hoc string parsing.

## `workspace_doctor.zig`

Use this pattern for local project health checks.

Modules exercised:

- `zstd.Workspace`
- `zstd.FileSystem`
- `zstd.Process`
- `zstd.Observability`
- `zstd.Json`

What it proves:

- A workspace can be snapshotted with ignore rules.
- Fake process checks emit redacted receipts.
- Observability data can be recorded during a local tool run.
- A deterministic JSON artifact can be written for later inspection.

This is the shape for `zstd`-based commands such as `doctor`, `check`, `lint`,
and `snapshot`.

## `agent_dev_session.zig`

Use this pattern for local agent telemetry.

Modules exercised:

- `zstd.Agent`
- `zstd.Process`
- `zstd.Json`
- `zstd.Jsonl`
- `zstd.Secrets`

What it proves:

- A local Codex-style session can emit workbench-compatible JSONL.
- Agent status, checks, guardrails, artifact links, and process receipts can be
  represented in one feed.
- Process commands and outputs are redacted before they reach the feed.

This is the bridge from local CLI execution to the SolidJS workbench.

## `agent_supervisor.zig`

Use this pattern for supervised local agent/tool runs.

Modules exercised:

- `zstd.Agent`
- `zstd.Process`
- `zstd.Json`
- `zstd.Secrets`

What it proves:

- A supervisor can run local process adapters sequentially.
- Guardrails and next actions are emitted into the workbench-compatible feed.
- stdout/stderr are captured as redacted artifacts.
- command receipts and check results stay redacted.

The production path can use `zstd.Process.LocalRunner`; the example uses the
same runner contract with a deterministic fake runner so it stays stable in CI.

## `http_sql_smoke.zig`

Use this pattern for local platform contract tests without external services.

Modules exercised:

- `zstd.Http`
- `zstd.Sql`
- `zstd.Schema`
- `zstd.Json`

What it proves:

- HTTP request bodies can be decoded with Schema.
- Validation failures return redacted issue JSON.
- SQL contracts can be exercised with `zstd.Sql.FakeDatabase`.
- Responses remain deterministic and locally testable.

This is the smallest useful shape for local API and database smoke tests.

## `packages/zigeffect-postgres/examples/migrate.zig`

Use this pattern for local Postgres migration commands.

Modules exercised:

- `pg.Sql` / `zstd.Sql`
- `pg.planMigrationsAlloc`
- `pg.runMigrationCliAlloc`
- `zstd.Secrets`
- `zstd.Json`

What it proves:

- Projects can supply typed migration lists without a hosted service.
- `plan` produces a redacted JSON receipt for local agents and workbench feeds.
- `apply-sql` produces executable transaction-wrapped SQL for `psql`.
- URLs, passwords, and sentinel-shaped values do not appear in receipts.

This is a deterministic local Postgres migration boundary. Native connection
and pool qualification belongs to the adapter package's live gates.

## `http_router.zig`

Use this pattern for local HTTP application boundaries.

Modules exercised:

- `zstd.Http`
- `zstd.Schema`
- `zstd.Json`

What it proves:

- A local route can decode JSON through Schema.
- The typed handler returns a Schema-encoded response.
- validation failures return deterministic redacted 400 payloads.
- every handled request returns route receipt and trace JSON.

This is the deterministic in-memory shape for API endpoint logic. A production
listener is supplied by `zigeffect-http` and remains an adapter migration
surface until it publishes canonical kernel layers.

## `local_toolbelt.zig`

Use this pattern when building a complete local developer command.

Modules exercised:

- `zstd.Cli`
- `zstd.Schema`
- `zstd.Workspace`
- `zstd.FileSystem`
- `zstd.Process`
- `zstd.Agent`
- `zstd.Json`

What it proves:

- A single command can parse typed args, snapshot a workspace, run a process,
  and append agent-session JSONL.
- The output can carry both a deterministic summary receipt and a live-style
  feed for the workbench.
- Redaction holds across the composed path.

This is the copyable starting point for local project automation.

## `grpc_unary.zig`

This example verifies exact in-process gRPC method routing through the same
contract consumed by the native transport. It provides the client with a
canonical layer and executes the call through one managed runtime. Production
services replace the in-process client with generated/native scoped layers
without changing the calling effect.

## `causal_graph.zig`

Use this example to understand restart-safe local causal graph persistence,
bounded queries, and durable event IDs. The graph database is an application
evidence backend; it is not a service dependency every domain effect must
request.

## Register a typed statechart

At application bootstrap, create the manifest-owned statechart artifact
directory and register each public machine:

```zig
try root.createDirPath(io, zstd.Statechart.default_path);
var dir = try root.openDir(io, zstd.Statechart.default_path, .{});
defer dir.close(io);
try zstd.Statechart.registerDefinitionAtomic(
    allocator,
    io,
    dir,
    &OrderWorkflow.definition,
    16 * 1024 * 1024,
);
```

Registration emits the native definition plus XState, Mermaid, and DOT
projections while preserving snapshots and definitions registered by other
components. Keep source references on states and transitions so agents can map
catalog output back to the declaration. Bump the definition version whenever
its fingerprint changes. Use the runtime causal recorder for live decisions
and a `CausalJournalStore` for durable workflow activity events.

## Refreshable resources and bounded pools

Use `Resource.Service` for an application-scoped value that can be replaced
without losing the last successful acquisition. Construction requirements are
layer inputs; consumers require only the resource tag:

```zig
const Credentials = zstd.Resource.Service(
    "app/Credentials",
    CredentialSet,
    LoadError,
    .{ConfigSource},
    loadCredentials,
    releaseCredentials,
);

const MainLayer = Credentials.DefaultWithoutDependencies().provide(ConfigLayer);
var runtime = try zstd.ManagedRuntime(@TypeOf(MainLayer)).make(
    allocator,
    io,
    root,
    MainLayer,
    .{},
);
defer runtime.deinit();

const current = try runtime.run(zstd.Resource.get(Credentials));
try runtime.run(zstd.Resource.refresh(Credentials));
```

Use `Pool.Service` inside adapters or application services that share bounded
native resources:

```zig
const DatabasePool = zstd.Pool.Service(
    "app/DatabasePool",
    Connection,
    ConnectError,
    .{DatabaseConfig},
    connect,
    disconnect,
    .{
        .min_size = 2,
        .max_size = 16,
        .concurrency_per_item = 1,
        .time_to_live_ms = 60_000,
    },
);
```

`Pool.get(DatabasePool)` registers the borrow in the current run scope. Use the
item inside the same composed effect; returning its pointer across the runtime
boundary escapes its borrow scope. Pool exhaustion is an explicit typed
failure in the synchronous interpreter. It never blocks an operating-system
thread.

Both service types advertise their operation catalogs in the application map.
Acquisition scopes and borrow finalizers are recorded structurally by the
runtime, while refresh/get/invalidate operations emit redacted semantic facts.

## Architecture status

The examples prove capability behavior and public imports. Migration status is
tracked separately in [the canonical standard-library roadmap](effect-native-roadmap.md).
A delivered capability is not automatically a canonical service/layer
implementation; only code using stable tags, canonical effects/layers, and one
managed runtime is a composition reference.
