# zigeffect-std

`zigeffect-std` is the one-import standard library facade for zigeffect
applications. It depends on `packages/zigeffect` and keeps application-facing
tooling outside the pure engine package.

```zig
const zstd = @import("zigeffect_std");
```

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

M13 adds a local-tools cookbook in `docs/cookbook.md`. These examples compile
as part of `zig build examples` and show how to build real local developer tools
with one import:

- `examples/schema_cli.zig` for Schema-powered typed CLI input.
- `examples/workspace_doctor.zig` for workspace snapshots, fake checks, and
  redacted receipts.
- `examples/agent_dev_session.zig` for workbench-compatible agent JSONL.
- `examples/agent_supervisor.zig` for supervised local agent/tool runs with
  redacted artifacts.
- `examples/http_router.zig` for Schema-coded local HTTP routes with receipts
  and traces.
- `examples/http_sql_smoke.zig` for local HTTP/SQL contract smoke tests.
- `examples/local_toolbelt.zig` for a composed local automation command.

## Modules

- `Service` provides the effect-native service kernel for providers, access
  effects, layers, and causal service facts.
- `Schema` validates, decodes, encodes, transforms, and derives JSON/config
  boundaries with path-aware redacted issue lists.
- `Json` writes deterministic redacted JSON payloads.
- `Jsonl` appends and parses newline-delimited JSON feeds.
- `Stream` re-exports engine pull streams and adds local line helpers.
- `Sink` provides deterministic memory line sinks with redacted JSONL receipts.
- `Queue` wraps engine queues as effect-native std services.
- `PubSub` wraps engine hubs as effect-native multi-subscriber services.
- `Cli` parses deterministic command specs, nested subcommands, Schema-powered
  typed options, source-aware defaults, built-ins, completions, effect-native
  handlers, exit-code mapping, and run receipts.
- `Console` provides a captured console service for testable command output.
- `Env` provides an owned environment map for deterministic local runs.
- `Config` resolves layered key/value config with redacted display values.
- `Secrets` provides shared redaction and secret-display helpers.
- `FileSystem` provides memory and real local file-system adapters plus
  effect-native read/write/delete/exists operations.
- `Path` joins, normalizes, and splits project paths.
- `Workspace` models local project roots, snapshots, changed files, ignore
  filtering, and effect-native snapshot/diff operations.
- `Process` provides fake and real local command runners with bounded capture,
  effect-native execution, and redacted run receipts.
- `Observability` wraps engine logger, metrics, and tracing services behind one
  effect-native recorder with redacted workbench JSON and OTLP-shaped JSON
  exports.
- `Testing` provides JSON and sentinel-secret assertions.
- `Clock` provides deterministic fake time.
- `Schedule` provides deterministic retry/polling steppers.
- `Sql` defines effect-native SQL query contracts, owned results, Schema-backed
  row decoding, fake databases, transaction receipts, migrations, pool
  leases/stats, and lifecycle facts. The local Postgres adapter lives in
  `packages/zigeffect-postgres`.
- `Http` defines effect-native HTTP client/server contracts with fake and live
  local clients, deterministic memory routing, Schema-coded local JSON routes,
  redacted route receipts/traces, and WebSocket frame codecs for local
  workbench feeds.
- `Agent` records workbench-compatible local agent JSONL sessions, Codex and
  Claude Code process adapter commands, guardrails, artifacts, check receipts,
  effect-native process-backed agent runs, and supervised local multi-tool
  sessions with redacted stdout/stderr artifacts.
- `Application` records stable semantic facts for config loads, Schema decodes,
  CLI commands, requests, SQL transactions, external calls, artifacts,
  component dependencies, and acceptance checks. It reuses the core causal
  taxonomy, emits redacted `span_recorded` facts, writes bounded fact receipts,
  and compares executor traces by semantic shape rather than event ids.
- `Project` defines the validated `zigeffect.project.v1` manifest, component
  dependency graph, requirements, acceptance checks, fixed command IDs,
  deterministic owned file plans, and redacted scaffold receipts used by the
  application-development CLI.
- `Safety` defines the `agent_safe_v1` project policy, parser-backed governed
  construct analysis, exact fingerprinted allowances, compiler diagnostics,
  bounded evidence completeness, and versioned safety receipts. Unknown,
  stale, unsupported, truncated, and unrun evidence never becomes a pass.
- `fx` re-exports the base zigeffect engine facade.

`Env`, `Config`, `Secrets`, `Json`, `Jsonl`, `Cli`, `Queue`, `PubSub`, `Sink`,
`FileSystem`, `Workspace`, `Process`, and `Observability` expose effect-native
service APIs. Their `*Effect` values declare required services, resolve those
services through `zstd.Service.Provider`, and record causal service-operation
facts so local agent workflows can inspect boundary behavior through the engine
graph instead of ad-hoc logs.

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
zstd.Agent
zstd.Application
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
