# zigeffect-std Cookbook

This cookbook contains local-first examples that compile through:

```sh
cd packages/zigeffect-std
zig build examples
```

Each example imports only the public facade:

```zig
const zstd = @import("zigeffect_std");
```

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

This is the shape for future `zstd`-based commands such as `doctor`, `check`,
`lint`, and `snapshot`.

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

This is the smallest useful shape for future local API and database smoke
tests.

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

This is the first production-local Postgres shape: deterministic in CI, real
enough for local development, and still replaceable by a future wire-protocol
driver.

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

This is the local development shape for API endpoints before a production
network listener exists.

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

## Next Local Milestones

M13 proves the std library can build real local tools. M14-M17 extend those
examples into a local agent/database development loop:

- **M14 Local Agent Supervisor:** delivered. `zstd.Agent` now supervises local
  process adapters, emits guardrails/checks/artifacts, and returns redacted
  workbench-compatible JSONL plus receipts.
- **M15 Workbench Dev Session UX:** delivered. The Solid workbench renders
  sessions, commands, checks, artifacts, causal facts, durable local ownership,
  and interactive PTY terminals.
- **M16 HTTP Router / Local Server:** delivered. `zstd.Http` now provides
  Schema-coded local JSON routes with receipt and trace JSON.
- **M17 Postgres Maturity:** delivered. `zstd.Sql` now decodes rows through
  Schema, exposes pool leases/stats and transaction receipts, and
  `zigeffect-postgres` provides migration planning/apply SQL plus a copyable
  local migration CLI.
