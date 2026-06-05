# Zig Effect And ZGroach Toolchain Design

## Goal

Add two separate Zig packages under `packages/`:

- `packages/zigeffect`: a Zig-native Effect-inspired application/tooling core.
- `packages/zgroach`: the future Zig RoachGraph compiler/toolchain, depending on
  `zigeffect` without merging into it.

This slice should create working, tested package foundations. It should not port
the existing TypeScript RoachGraph compiler yet.

## Package Boundaries

`zigeffect` is generic infrastructure. It must not import or reference
RoachGraph, RGDL, CockroachDB, TypeScript generation, or Yachdee app concerns.

`zgroach` is RoachGraph-specific compiler tooling. It may import `zigeffect`,
but it must keep RGDL, diagnostics, IR, CLI, and future code generation in its
own package.

The TypeScript `packages/roachgraph` package remains the active production
RoachGraph package for now.

## Zigeffect Core

The initial core should be small and Zig-native:

- `Effect`: wraps direct-style `fn(ctx) Error!A`.
- `Runtime`: runs effects with fresh scopes and automatic cleanup on success or
  failure.
- `Context`: service access by typed service key.
- `Layer`: dependency construction and teardown through `Scope`.
- `Scope`: deterministic resource finalization in reverse registration order.
- `Exit` and `Cause`: structured success, failure, defect, and interruption
  shapes.
- `Schedule`: retry and repeat decisions with fixed, exponential, linear,
  backoff, and deterministic jitter policies.
- `TestEnv`: fake clock, in-memory file system, stub logger, metrics, and
  tracing services.
- `Logger`, `Config`, `Metrics`, `Tracing`: small service contracts.

The bootstrap expansion also includes:

- `Effect.map`, `Effect.flatMap`, and `Effect.tap` for edge composition while
  keeping implementation bodies in direct Zig style.
- `Effect.repeat` for successful repetition using `Schedule`.
- Context-level typed finalizer registration.
- `acquireRelease` for pointer resources with automatic cleanup when the active
  `Scope` closes.
- `Layer.fromBuilder` for dependency construction with scope-owned teardown.
- Logger `info`, `warn`, and `err` helpers.
- Config overwrite-safe `set`, `get`, and `require`.
- Metrics counters and gauges.
- Tracing events plus span start/end markers.
- Memory filesystem read, write, exists, and delete helpers.
- Test environment assertion helpers for logs, traces, metrics, and files.
- Usage, agent, and devex-review documentation that keeps public APIs easy for
  humans, LLMs, and agents to apply correctly.
- Runtime-managed cleanup is the recommended path; manual scope closing is a
  low-level escape hatch.
- Diagnostic helpers that make common mistakes explicit:
  - `serviceNotFound(Env, Service)` for rich compile-time service errors.
  - `MissingScope` as a typed error when scoped finalizers are registered
    without an active runtime scope.
  - `formatExit` / `formatCause` for readable runtime failure reports in tests,
    CLIs, and agent-facing tools.

The first implementation should favor direct Zig control flow over combinator
heavy APIs. Combinators may exist at the edge, but regular package code should
read like normal Zig using `try`.

## Diagnostic Experience

`zigeffect` should be unusually helpful when users compose effects incorrectly
or forget required runtime structure. Zig already gives strong type errors, so
the package should add hand-holding at the boundaries where the user is most
likely to be confused.

Missing services should fail at compile time with a message that names the
requested service type, the environment type, and the exact `service` branch the
user should add. Custom environments should delegate their fallback branch to
`fx.serviceNotFound(Env, Service)` instead of writing vague `@compileError`
strings.

Scoped resource registration must not silently succeed without a scope. If a
program calls `Context.addFinalizerFor` outside `Runtime.run`, `TestEnv.run`, or
another context with an active `Scope`, it should return the typed
`error.MissingScope`. `acquireRelease` must immediately release the acquired
resource if finalizer registration fails.

Runtime reports should convert structured `Exit` and `Cause` values into short,
copyable strings. These reports should name the program label, outcome, failure
kind, and next action without replacing Zig's typed error sets.

## Core Hardening V1

Before building the larger `zigeffect` standard library, the core needs a
stronger error and dependency model:

- `Effect.succeed`, `Effect.fail`, and `Effect.sync` constructors for
  boilerplate-free stdlib helpers.
- Recovery combinators: `mapError`, `catchAll`, `orElse`, and `tapError`.
- Richer `Cause` values for sequential, parallel, annotated, and finalizer
  failures.
- Scope support for fallible finalizers. Cleanup failures should be recorded and
  visible through `Runtime.exit`.
- `Layer.merge` and `Layer.provide` for dependency composition and direct
  effect execution from a layer.
- `Clock` as a real service abstraction, with fake and system modes, replacing
  direct coupling to `FakeClock` in runtime/schedules.

This hardening slice should preserve direct-style Zig functions as the primary
way to write programs. It should add recovery and construction tools around that
style, not replace it with a combinator-heavy API.

## Core Style Parity V2

Research against the official Effect docs shows that the next useful parity line
is lifecycle and schedule ergonomics, not a full EffectTS clone. `zigeffect`
should keep Zig-native direct style while matching the mature concepts that make
Effect software predictable:

- `Effect.onExit` for observing structured success/failure exits.
- `Effect.ensuring` for effect-local finalizers that run on success and failure.
- `FinalizerExit` plus exit-aware scope finalizers for cleanup that depends on
  the program outcome.
- Runtime and layer scope closing that passes success or typed-failure outcome
  into finalizers.
- Schedule names that mirror common Effect vocabulary: `once`, `recurs`,
  `spaced`, `duration`, and `fibonacci`.
- A dedicated EffectTS parity document that tracks what has style parity, what
  is intentionally deferred, and where the stdlib should grow next.

This still avoids a full fiber runtime, scheduler algebra, or broad observability
stack. Those should be added when stdlib services prove the need.

## Production Core V1

The DI/runtime core should move from bootstrap-ready to production-gated without
trying to build the whole Effect ecosystem in one step.

The first production slice adds explicit dependency metadata around the existing
direct-style model:

- `ServiceSet`: a runtime set of service type names derived from Zig service
  types.
- Required effects: `Effect.requires(.{ ServiceA, ServiceB })` wraps an effect
  with service requirements while preserving normal `run`, `exit`, recovery,
  lifecycle, retry, and repeat behavior.
- Annotated layers and runtimes: layers/runtimes can declare provided services,
  and execution validates required effects before running.
- Dependency reports: validation should produce structured issues for missing
  requirements and duplicate providers, plus a readable formatter for CLI/test
  output.
- Layer graph validation: a graph can collect layer metadata, detect duplicate
  providers, and report layer requirements that no provider satisfies.
- Typed startup errors: `LayerWithError(Env, StartupError)` preserves
  application startup errors instead of forcing all layer startup failures into
  allocator errors.
- Compile-fail diagnostic fixture: missing-service compile errors should be
  tested by compiling a small bad Zig program and asserting the rich
  `serviceNotFound` message is present.

The runtime boundary should enforce requirements when metadata is present. It
should not make service metadata mandatory for every low-level test or prototype,
because the existing direct-style ergonomics are still valuable. The production
path is: declare requirements on effects, declare provided services on layers or
runtimes, then run through checked `provide` / `Runtime.run`.

Non-goals for this slice:

- No full automatic layer builder across heterogeneous environment types.
- No fiber supervision or cancellation runtime yet.
- No global service registry.
- No replacement for Zig compile-time service access.

## ZGroach Core

The initial `zgroach` package should prove the dependency direction:

- Import and use `zigeffect`.
- Define a minimal compiler environment with logger and config services.
- Provide `validateSource` as a tiny effectful compiler operation.
- Provide `validateCurrentSource` as a `zigeffect.Effect` that reads config and
  files from the test services.
- Expose tests proving `zgroach` can run against a `zigeffect` test
  environment.

This is a package scaffold, not an RGDL parser port.

## Verification

Required verification:

```bash
bun run zigeffect:test
bun run zgroach:test
```

Optional repository checks after package verification:

```bash
bun run typecheck
bun run test
```

## Non-Goals

- No TypeScript RoachGraph migration in this slice.
- No Worker request-path dependency on Zig or Wasm.
- No full fiber runtime.
- No STM, stream/channel system, or Effect Schema port.
- No package publishing metadata beyond local Zig build files.
