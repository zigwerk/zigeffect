# zigeffect-std Local Tools Cookbook Design

Date: 2026-06-26

Status: delivered on 2026-06-26.

## Decision

Add M13 as a real local-tool cookbook for `zigeffect-std`.

M1-M12 built the standard-library surface. M13 must prove that surface by
shipping copyable Zig examples that compile under `zig build examples`, exercise
multiple std modules together, and emit deterministic redacted artifacts that a
local agent/workbench flow can consume.

## Goals

- Keep `const zstd = @import("zigeffect_std");` as the only user-facing import.
- Add production-shaped examples, not throwaway snippets.
- Cover typed CLI, Schema issues, env/config/default precedence, workspace
  snapshots, process receipts, observability payloads, and agent JSONL feeds.
- Gate examples in `packages/zigeffect-std/build.zig`.
- Document each example in a cookbook with usage, modules exercised, and the
  local-development scenario it represents.

## Non-Goals

- No hosted services.
- No new distributed runtime.
- No process supervisor daemon yet; that is M14.
- No workbench UI change yet; M15 will consume the M13 JSONL/artifact shapes.
- No new std module unless an example exposes a missing primitive that cannot be
  expressed with existing modules.

## Examples

### `schema_cli.zig`

Demonstrates a typed CLI boundary:

- `zstd.Cli`
- `zstd.Schema`
- `zstd.Env`
- `zstd.Config`
- `zstd.Console`

The example decodes `workspace`, `port`, `watch`, and `mode` from
`cli > env > config > default`, prints a deterministic summary, and can expose
redacted issue JSON for invalid input.

### `workspace_doctor.zig`

Demonstrates a local project health check:

- `zstd.Workspace`
- `zstd.FileSystem`
- `zstd.Process`
- `zstd.Observability`
- `zstd.Json`

The example snapshots an in-memory workspace with ignore rules, runs fake
checks, and emits one redacted JSON receipt that can be stored as an artifact.

### `agent_dev_session.zig`

Demonstrates workbench-compatible local agent telemetry:

- `zstd.Agent`
- `zstd.Process`
- `zstd.Jsonl`
- `zstd.Secrets`

The example records a Codex-style session, check results, guardrails, artifact
links, and a redacted process receipt in JSONL.

### `http_sql_smoke.zig`

Demonstrates platform contracts without requiring external services:

- `zstd.Http`
- `zstd.Sql`
- `zstd.Schema`
- `zstd.Json`

The example validates a request payload, routes it through memory HTTP/SQL
contracts, and returns deterministic JSON.

### `local_toolbelt.zig`

Demonstrates composing the previous shapes into one local command surface:

- `zstd.Cli`
- `zstd.Schema`
- `zstd.Workspace`
- `zstd.Process`
- `zstd.Agent`

The example gives future users a small "toolbelt" pattern for building
EffectTS-style local CLIs with receipts and agent facts.

## Success Criteria

- `bun run zigeffect:std:test` builds and tests all cookbook examples.
- Each example has at least one behavior test that fails before implementation
  and passes after implementation.
- Cookbook examples do not leak sentinel secrets in receipts, issues, or JSONL.
- `packages/zigeffect-std/README.md` links to the cookbook and lists the new
  example commands.
- `packages/zigeffect/docs/roadmap.md` records M13 as delivered once verified.
