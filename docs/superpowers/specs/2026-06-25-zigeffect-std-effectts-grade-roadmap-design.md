# zigeffect-std EffectTS-Grade Roadmap Design

Date: 2026-06-25

## Decision

Move `packages/zigeffect-std` from an expanded helper facade to an
EffectTS-grade application standard library for the Zig effect engine.

The standard library must not become a parallel runtime. It must be the
application layer of `packages/zigeffect`:

```text
packages/zigeffect
  Effect, Context, Layer, Runtime, Scope, Fiber, Schedule, Stream, CausalStore

packages/zigeffect-std
  effect-native services, schemas, CLI, config, process/workspace, HTTP/SQL
  contracts, observability helpers, and local agent runtime tooling

adapter packages
  real drivers and platform adapters such as zigeffect-postgres or zigeffect-zio
```

Every std module that crosses a boundary must become:

- a service contract;
- a fake/test implementation;
- a live implementation when local-only APIs make sense;
- an effect-native access API;
- typed errors;
- scoped resource behavior where resources are acquired;
- causal facts through `Context.recordCausal`;
- deterministic tests proving dependency validation and trace evidence.

## Non-Negotiable Quality Bar

No milestone is complete because a namespace exists. A milestone is complete only
when its public APIs are effect-native, tested, documented, and included in
`bun run zigeffect:std:test`.

No stubs:

- no placeholder services that only store data without effect access;
- no fake-only protocol surface where a live local adapter is explicitly in
  scope for that milestone;
- no untyped string errors at effect boundaries;
- no boundary output that bypasses `Secrets`;
- no causal-observable operation that forgets to emit a causal fact.

## Milestones

### M1 - Std Service Kernel

Build the reusable service shape that all later std modules use.

Deliverables:

- `zstd.Service` module.
- `Service.Provider(.{ ... })` for typed provider envs.
- `Service.access(Service, Env)` effect constructor with `.requires(.{Service})`.
- `Service.recordRequired`, `recordProvided`, and `recordOperation` helpers.
- `Service.layerFromEnv` helper for layer construction.
- tests proving service access, dependency metadata, provider resolution,
  scoped layer use, and causal evidence.

### M2 - Schema

Build `zstd.Schema` for data boundaries.

Deliverables:

- primitive schemas for string, int, bool, enum, optional, array, struct.
- decode/encode with typed error trees.
- transform schemas.
- JSON and Config codecs.
- redacted error rendering.
- tests for valid decode, invalid tree, transform, JSON codec, config codec.

### M3 - Effect-Native Config, Env, Secrets, Json, Jsonl

Convert the current helper modules to service-backed modules.

Deliverables:

- service contracts and providers for Env, Config, Secrets, Json, Jsonl.
- fake layers for tests.
- live local env provider.
- typed errors and redacted diagnostics.
- causal facts for config load/lookup, env lookup, JSON encode/decode, JSONL
  append/parse.

### M4 - CLI Application Framework

Turn `zstd.Cli` into an effect-native CLI runner.

Deliverables:

- command handlers as effects.
- layer-driven dependencies.
- typed option schemas.
- nested subcommands.
- env/config defaults.
- deterministic help and completions.
- exit-code mapping from typed errors.
- command run receipts and causal facts.

### M5 - Streams, Queues, PubSub, Sinks

Expose std-level streaming primitives for local IO and agent feeds.

Deliverables:

- `zstd.Stream`, `Sink`, `Queue`, `PubSub` facade helpers over engine primitives.
- deterministic fake sources/sinks.
- line stream helpers for JSONL/process output.
- causal facts for stream start, item, backpressure/drop, close, failure.

### M6 - Process, Workspace, FileSystem Live Local Adapters

Make local development operations real and traceable.

Deliverables:

- effect-native Process service with fake and real local runner.
- effect-native FileSystem service with memory and real local adapter.
- Workspace service for root discovery, snapshots, diffs, ignore filtering.
- stdout/stderr streaming into JSONL/causal facts.
- secret-safe argv/env/path/output handling.

### M7 - Observability

Status: delivered on 2026-06-25.

Build std-level logging, metrics, tracing, and artifact export on top of the
causal graph.

Deliverables:

- `zstd.Observability` service backed by the engine logger, metrics, and
  tracing primitives.
- log/metric/span APIs as effects with service requirements.
- redacted workbench artifact helpers.
- causal receipt builders through `zstd.Service.recordOperation`.
- OTLP-shaped JSON export for local collectors and future bridge adapters.

### M8 - HTTP and WebSocket

Status: delivered on 2026-06-25.

Make HTTP local tools effect-native.

Deliverables:

- HTTP client/server contracts as effect-native services.
- fake client and deterministic memory server.
- real local client adapter through Zig `std.http.Client.fetch`.
- request/response ownership and deinit contracts.
- WebSocket frame contracts for workbench/collector flows.
- redacted header/url/body diagnostics and causal service facts.

### M9 - SQL and Postgres Adapter Package

Keep `zstd.Sql` as the contract and add real Postgres outside std.

Deliverables:

- effect-native SQL contract, fake database, transaction scope, migrations.
- `packages/zigeffect-postgres` adapter package.
- connection pool interface.
- redacted connection metadata.
- contract tests shared by fake and Postgres adapter.

### M10 - Agent Toolkit

Make local agentic development a first-class std-lib runtime.

Deliverables:

- `zstd.Agent` service.
- Codex and Claude Code process adapter contracts.
- local session model and JSONL feed writer.
- tool/check/artifact events.
- policy/guardrail hooks.
- live workbench visualization path.
- end-to-end local agent run proof.

## Dependency Order

```text
M1 Service Kernel
  -> M2 Schema
  -> M3 Config/Env/Secrets/Json
  -> M4 CLI
  -> M5 Streams
  -> M6 Process/Workspace/FileSystem
  -> M7 Observability
  -> M8 HTTP/WebSocket
  -> M9 SQL/Postgres
  -> M10 Agent Toolkit
```

M1 must happen first because it defines the service/layer/effect/causal contract
that all later milestones must follow.

## M1 Design

`zstd.Service` wraps the existing engine concepts instead of replacing them.

Public API target:

```zig
const zstd = @import("zigeffect_std");

const Env = zstd.Service.Env(.{ zstd.Console.CapturedConsole });

const Program = zstd.Service.access(zstd.Console.CapturedConsole, Env);
```

Core pieces:

- `Env(.{ ServiceA, ServiceB })`: alias to the engine's service-env narrowing
  pattern.
- `Provider(.{ ServiceA, ServiceB })`: a typed provider/env that stores service
  pointers, implements `service(Requested)`, exposes `providedServices`, and can
  produce a `Layer`.
- `access(Service, Env)`: returns an `fx.Effect(*Service, error{}, Env)` and
  declares `.requires(.{Service})`.
- `recordRequired(ctx, Service, detail)`: records `service_required`.
- `recordProvided(ctx, Service, detail)`: records `service_provided`.
- `recordOperation(ctx, Service, operation, status, detail)`: records a
  `span_recorded` causal fact with `service_key`.
- `layerFromEnv(Env, env, services)`: creates a provided layer from an existing
  env.

This makes the existing std modules progressively migratable. A module can keep
plain helper functions while adding its effect-native service facade; later
milestones move behavior behind these service contracts.

## M1 Acceptance Criteria

M1 is complete when:

- `zstd.Service` is exported.
- provider envs resolve multiple services through `ctx.service`.
- access effects participate in `.requires(.{Service})` metadata.
- provider layers run through `fx.Runtime`/`fx.Layer` without special cases.
- service required/provided/operation facts appear in a `CausalStore`.
- tests prove all of the above inside `packages/zigeffect-std`.
- `bun run zigeffect:std:test` and `bun run zigeffect:local-agent-gate` pass.
