# zigeffect-std Expanded Surface Design

Date: 2026-06-25

## Decision

Expand `packages/zigeffect-std` into the local-first standard library facade for
zigeffect applications and agentic development tools.

The public surface target is:

```zig
const zstd = @import("zigeffect_std");

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

`packages/zigeffect` remains the pure engine. `packages/zigeffect-std` owns the
stable application-facing service contracts, deterministic fakes, serialization
helpers, local workspace primitives, and agent run adapters. Real external
protocol adapters can live in separate packages once their contracts stabilize.

## Boundary Rules

`zigeffect-std` may depend on `zigeffect` and Zig `std`. The core `zigeffect`
package must not depend on `zigeffect-std`.

The standard library should prefer:

- deterministic interfaces before real integrations;
- fake implementations before platform implementations;
- redacted values before raw strings;
- typed errors before stringly diagnostics;
- structured receipts before prose logs;
- golden tests before visual assumptions.

Modules with heavy protocol or deployment concerns should be split:

- `zstd.Sql` defines query, row, transaction, pool, fake database, and migration
  contracts.
- a future `zigeffect-postgres` package should provide the real Postgres adapter.
- `zstd.Http` defines request/response/client/server abstractions and fake
  clients.
- future packages can provide platform-specific HTTP or WebSocket adapters.

## Module Responsibilities

### Json

`Json` provides deterministic JSON helpers used by causal artifacts, receipts,
config, workbench payloads, and agent events.

Responsibilities:

- stable stringify for object fields emitted by zigeffect-std;
- JSON string escaping;
- typed parse and encode errors;
- redaction-aware value rendering;
- snapshot helpers for tests.

### Jsonl

`Jsonl` provides newline-delimited JSON helpers for local agent sessions, process
streams, workbench collector feeds, and causal exports.

Responsibilities:

- append one JSON record per line;
- parse complete lines while retaining incomplete trailing input;
- reject malformed lines without breaking the whole stream;
- redact before writing.

### Cli

`Cli` remains the command-facing entry point and grows from the MVP parser into a
small application runner.

Responsibilities:

- command tree and nested subcommands;
- typed string, boolean, integer, and enum options;
- long and short flags;
- required options;
- env/config defaults;
- deterministic help text;
- exit code mapping;
- structured command receipts.

### Console

`Console` provides stdout/stderr/stdin service boundaries.

Responsibilities:

- captured console for tests;
- real console adapter when needed;
- structured console write facts;
- redaction-safe output helpers.

### Env

`Env` provides deterministic environment lookup.

Responsibilities:

- fake map implementation;
- required and optional lookup;
- typed missing-variable errors;
- secret-aware environment values.

### Config

`Config` composes CLI, env, JSON files, and defaults into typed application
configuration.

Responsibilities:

- layered config source order;
- typed missing and invalid config errors;
- redaction metadata for sensitive keys;
- deterministic fixtures for tests.

### Secrets

`Secrets` makes redaction a first-class std-lib concept.

Responsibilities:

- `SecretString` or equivalent wrapper;
- sentinel-secret detection for tests;
- redaction policy for URLs, tokens, keys, passwords, and auth headers;
- helpers used by Json, Jsonl, Config, Process, Sql, Http, and Agent.

### FileSystem

`FileSystem` grows the MVP memory filesystem into a stable file service.

Responsibilities:

- memory filesystem;
- real local filesystem adapter;
- read, write, delete, exists, list;
- atomic write helper;
- redacted path diagnostics.

### Path

`Path` provides path parsing and joining without hiding filesystem access.

Responsibilities:

- join and normalize path segments;
- basename, dirname, extension;
- project-relative display paths;
- workspace-safe path checks.

### Workspace

`Workspace` models a local project checkout.

Responsibilities:

- root discovery;
- relative path resolution;
- ignore-rule aware file listing;
- snapshots for agent runs;
- simple diff capture;
- workspace metadata for the workbench.

### Process

`Process` runs local commands through a testable service boundary.

Responsibilities:

- fake process runner;
- real local process runner;
- command, args, env, cwd model;
- stdout/stderr capture;
- streaming line events;
- exit status and signal status;
- secret redaction for argv, env, cwd, and output;
- structured run receipts.

### Testing

`Testing` provides fixtures and assertions for std-lib users.

Responsibilities:

- fake console/env/fs/process/clock;
- JSON and JSONL golden assertions;
- causal receipt assertions;
- sentinel secret leak assertions;
- local agent session fixtures.

### Clock

`Clock` provides deterministic and real time services.

Responsibilities:

- fake monotonic and wall clock;
- real clock adapter;
- sleep interface;
- timestamps for receipts and agent sessions.

### Schedule

`Schedule` provides reusable retry and polling policies.

Responsibilities:

- fixed, exponential, and bounded schedules;
- deterministic schedule stepping;
- integration with `Clock`;
- retry metadata for causal receipts.

### Sql

`Sql` defines database contracts without committing the std package to a real
database driver.

Responsibilities:

- query text and bind values;
- rows and typed value access;
- transaction interface;
- pool interface;
- fake database for tests;
- migration plan/result types;
- redacted connection metadata.

Real Postgres support should be implemented later in `zigeffect-postgres` against
this interface, then tested against `zstd.Sql` fake and contract tests.

### Http

`Http` defines request/response/client primitives used by local tools and future
adapters.

Responsibilities:

- request and response types;
- fake client;
- status, headers, body helpers;
- redaction for auth headers and URLs;
- optional WebSocket shape after the request model is stable.

### Agent

`Agent` is the local agentic development layer that sits on top of Workspace,
Process, Jsonl, Clock, and Secrets.

Responsibilities:

- local agent session model;
- Codex and Claude Code process adapter contracts;
- tool/run/check/artifact events;
- NDJSON session feed writer;
- workbench-friendly run receipts;
- policy hooks for guardrails.

## Implementation Order

The modules should be implemented in dependency order:

1. `Secrets`
2. `Json`
3. `Jsonl`
4. `Path`
5. `Config`
6. `Clock`
7. `Schedule`
8. `FileSystem` expansion
9. `Workspace`
10. `Process`
11. `Testing`
12. `Cli` expansion
13. `Sql`
14. `Http`
15. `Agent`

This order keeps redaction and serialization underneath every module that emits
artifacts. It also gives `Agent` the primitives it needs instead of building a
parallel local-runtime stack.

## Data Flow

Local agentic development should flow through std-lib services:

```text
Cli command
  -> Config / Env
  -> Workspace
  -> Process
  -> Jsonl session events
  -> causal receipts
  -> workbench collector / sample renderer
```

No command handler should read environment variables, run child processes, or
touch the filesystem directly when a std service exists for that boundary.

## Error Handling

Each module owns typed errors and converts them to CLI exit codes only at the CLI
boundary. Internal modules should not print errors directly.

Common error categories:

- parse error;
- validation error;
- missing config or env value;
- permission or filesystem error;
- process spawn or exit error;
- malformed JSON or JSONL;
- unsupported SQL or HTTP value;
- redaction policy violation.

Errors that may include user data must expose a redacted display path/string.

## Testing Strategy

Every module starts with deterministic tests in the module file or nearby test
files. Each module should include:

- happy-path behavior;
- typed failure behavior;
- redaction behavior where user data can cross a boundary;
- deterministic output ordering for serialized values;
- fake implementation contract tests when the module defines a service.

Package verification remains:

```sh
bun run zigeffect:std:test
```

The local agent gate continues to include the std package:

```sh
bun run zigeffect:local-agent-gate
```

## Acceptance Criteria

The expanded std-lib work is complete when:

- every target module is exported from `zstd`;
- each module has deterministic tests;
- any module that emits strings or artifacts uses `Secrets` redaction helpers;
- `Jsonl`, `Process`, `Workspace`, and `Agent` can produce a local agent session
  feed suitable for the workbench;
- `Sql` and `Http` have fake contracts without forcing real network/database
  dependencies into `zigeffect-std`;
- the std package test and local agent gate pass.

