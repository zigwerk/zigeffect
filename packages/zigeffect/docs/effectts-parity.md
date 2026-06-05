# zigeffect EffectTS Parity

Date: 2026-06-05

This document tracks what “style parity” means for `zigeffect`. EffectTS is a
large production ecosystem. `zigeffect` is not trying to clone it API-for-API;
the goal is to preserve the core software shape in Zig:

- direct-style programs with typed errors
- explicit service requirements
- deterministic resource cleanup
- structured exits and causes
- schedules for retry and repeat
- test services that make time, files, logs, metrics, and traces deterministic

## Research Baseline

Official Effect docs show a mature system with:

- `Effect` values, success/failure/requirements, and generator-based direct
  style: https://effect.website/docs/getting-started/using-generators/
- typed services through `Context.Tag`, generic tags, and service provisioning:
  https://effect.website/docs/requirements-management/services/
- `Layer` dependency construction and provisioning:
  https://effect.website/docs/requirements-management/layers/
- structured `Exit` and `Cause`, including failure, defect, and interruption:
  https://effect.website/docs/data-types/cause/
- schedules for retry/repeat with recurs, spaced, duration, exponential,
  fibonacci, jitter, and composition:
  https://effect.website/docs/scheduling/schedule-types/
- logging levels and structured logging helpers:
  https://effect.website/docs/observability/logging/
- tracing spans and annotations:
  https://effect.website/docs/observability/tracing/
- counters, gauges, histograms, summaries, timers, and frequencies:
  https://effect.website/docs/observability/metrics/
- typed config descriptors and providers:
  https://effect.website/docs/configuration/
- deterministic test clocks for time-based effects:
  https://effect.website/docs/testing/testclock/

## Current Parity Choices

### Effect

EffectTS has a broad set of constructors, combinators, and generator syntax.
`zigeffect` keeps the core as `fn(ctx) Error!A`, then wraps it with
`Effect.fromFn`. The current parity target is direct-style execution plus enough
edge combinators to compose stdlib services:

- constructors: `succeed`, `fail`, `sync`
- transformation: `map`, `flatMap`, `tap`
- recovery: `mapError`, `catchAll`, `orElse`, `tapError`
- lifecycle observation: `onExit`, `ensuring`
- scheduling: `retry`, `repeat`

Zig does not need an EffectTS generator equivalent for the first version
because `try` already gives readable direct-style error flow.

### Context

EffectTS uses service tags. `zigeffect` uses a Zig environment struct with a
typed `service` method. Missing services route through
`fx.serviceNotFound(Env, Service)` so compile errors name the requested service,
environment, and fix pattern.

Production paths can now add metadata through `Effect.requires`, layer/runtime
`provides`, `ServiceSet`, `DependencyReport`, and `LayerGraph`. This gives
preflight dependency validation without replacing Zig's compile-time service
lookup.

### Layer

EffectTS layers can model complex dependency graphs. `zigeffect` currently
supports:

- `Layer.fromEnv`
- `Layer.fromBuilder`
- `Layer.buildContext`
- `Layer.provide`
- `Layer.merge`
- `LayerWithError`
- `LayerGraph`
- `layerGraph`

This supports checked production startup in small and medium graphs. Explicit
`Layer.merge` remains available, while `layerGraph` accepts heterogeneous layer
tuples, validates declared providers and requirements, derives startup order,
and memoizes the built environments until graph deinit.

### Scope

EffectTS scopes and finalizers are central to resource safety. `zigeffect` now
has:

- reverse-order finalizers
- typed resource finalizers
- fallible finalizers with recorded cleanup failures
- exit-aware finalizers through `FinalizerExit`
- runtime-managed scope close on success and failure
- `ensuring` for effect-local finalizers

Manual scope closing remains a low-level test/custom-runtime tool.

### Exit And Cause

EffectTS separates expected failures, defects, and interruptions through
`Cause`. `zigeffect` mirrors that shape with Zig error sets for expected
failures and tagged unions for defects, interruptions, finalizer failures,
sequential/parallel causes, and annotations.

The main difference is runtime-generated nested causes: recursive causes use
pointer links, so runtime code avoids returning pointer-backed sequential trees
from stack-local values. Today, a cleanup failure surfaced by `Runtime.exit`
returns `Cause.finalizer_failure` directly.

### Fibers

EffectTS fibers model lightweight, interruptible work with structured joins and
scope ownership. `zigeffect` now has Stage 1 semantic parity for the lifecycle
surface:

- `FiberId`
- `FiberStatus`
- `FiberRuntime`
- typed `Fiber` handles
- deterministic `fork`, `join`, and `interrupt`
- `forkScoped` leases that interrupt unfinished children when a parent scope
  closes
- child scope cleanup with success, failure, or interruption exits
- `Deferred`, `Queue`, and `Semaphore` as deterministic coordination
  primitives

The current core runtime is deterministic and run-to-completion on `join`; it is
not a real green-thread scheduler. True suspension, task groups, cancellation
against blocking IO, and `std.Io` integration are deferred to the optional zio
backend adapter.

### Schedule

EffectTS has a deep scheduling algebra. `zigeffect` now covers the names needed
for retry/repeat stdlib work:

- `once`
- `recurs`
- `spaced`
- `duration`
- `fixed`
- `repeat`
- `exponential`
- `fibonacci`
- `linear`
- `backoff`
- `jitteredBackoff`

Composition operators are intentionally deferred until real stdlib code needs
them.

### TestEnv

EffectTS has robust test services, including fake time. `zigeffect` currently
bundles:

- fake `Clock`
- in-memory filesystem
- stub logger
- config map
- counters/gauges
- tracing events/spans
- assertion helpers

This is enough to build `fx.Test` later. The next useful step is fixtures,
golden output, and clearer assertion reports.

### Logger, Config, Metrics, Tracing

EffectTS observability/config is substantially more mature than the current
stubs. The first `zigeffect` parity line is service shape, deterministic tests,
and useful names:

- Logger should evolve from plain messages to level-aware entries and fields.
- Config should evolve into typed descriptors with env/file providers and
  missing-key diagnostics.
- Metrics should add histograms and snapshots.
- Tracing should add trace ids, span ids, attributes, and nested span trees.

These should be built as stdlib services on top of the core rather than by
expanding the core runtime too early.

## Next Parity Priorities

1. Typed config descriptors and providers.
2. Level-aware structured logger entries.
3. Metrics snapshots with counters, gauges, and histograms.
4. Tracing spans with ids and parent/child relationships.
5. `fx.Test` helpers for fixtures, golden output, and fake service injection.
6. Dependency-injected layer builders for graph services.
7. Zio backend adapter for real fibers, cancellation, and `std.Io`.
8. Compile-time assertions for common effect composition mistakes.
