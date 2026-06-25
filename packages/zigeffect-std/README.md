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

## Modules

- `Service` provides the effect-native service kernel for providers, access
  effects, layers, and causal service facts.
- `Schema` validates and decodes JSON/config boundaries with typed errors.
- `Json` writes deterministic redacted JSON payloads.
- `Jsonl` appends and parses newline-delimited JSON feeds.
- `Stream` re-exports engine pull streams and adds local line helpers.
- `Sink` provides deterministic memory line sinks with redacted JSONL receipts.
- `Queue` wraps engine queues as effect-native std services.
- `PubSub` wraps engine hubs as effect-native multi-subscriber services.
- `Cli` parses deterministic command specs, nested subcommands, typed defaults,
  completions, effect-native handlers, exit-code mapping, and run receipts.
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
- `Sql` defines effect-native SQL query contracts, owned results, fake
  databases, transactions, migrations, and pool lifecycle facts. The local
  Postgres adapter lives in `packages/zigeffect-postgres`.
- `Http` defines effect-native HTTP client/server contracts with fake and live
  local clients, deterministic memory routing, redacted diagnostics, and
  WebSocket frame codecs for local workbench feeds.
- `Agent` formats local agent session events and run receipts.
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
```

## Example

The first example is intentionally small: it proves the one-import facade can
parse a command and write output through a testable service.

```sh
cd packages/zigeffect-std
zig build examples
```
