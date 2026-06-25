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
- `Json` writes deterministic redacted JSON payloads.
- `Jsonl` appends and parses newline-delimited JSON feeds.
- `Cli` parses deterministic command specs and emits command run receipts.
- `Console` provides a captured console service for testable command output.
- `Env` provides an owned environment map for deterministic local runs.
- `Config` resolves layered key/value config with redacted display values.
- `Secrets` provides shared redaction and secret-display helpers.
- `FileSystem` provides an in-memory file system for tests and local tools.
- `Path` joins, normalizes, and splits project paths.
- `Workspace` models local project roots, snapshots, and changed files.
- `Process` provides a fakeable command runner and redacted run receipts.
- `Testing` provides JSON and sentinel-secret assertions.
- `Clock` provides deterministic fake time.
- `Schedule` provides deterministic retry/polling steppers.
- `Sql` defines fakeable SQL query contracts without a real driver.
- `Http` defines fakeable request/response contracts without network access.
- `Agent` formats local agent session events and run receipts.
- `fx` re-exports the base zigeffect engine facade.

The public surface is:

```zig
zstd.Service
zstd.Json
zstd.Jsonl
zstd.Cli
zstd.Console
zstd.Env
zstd.Config
zstd.Secrets
zstd.FileSystem
zstd.Path
zstd.Workspace
zstd.Process
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
