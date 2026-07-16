# ZigEffect developer-experience review

**Reviewed:** 2026-07-15

**Status:** canonical application kernel and local scaffolds landed; adapter and
standard-library migration remains in progress.

This document records the current developer-experience boundary. Older reviews
that treated `ServiceEnv`, `LayerGraph`, or environment-parameterized effects as
the target architecture are superseded.

## Product standard

ZigEffect should feel like sturdy Zig with Effect-style composition:

- service requirements and typed failures are visible at compile time;
- business operations return lazy descriptions;
- layers select implementations and own resources;
- one managed runtime builds and memoizes the application graph;
- logging, metrics, tracing, supervision, and causal evidence are runtime
  aspects rather than parameters threaded through every function;
- deterministic tests replace layers without rewriting programs; and
- one bounded inspection surface can map the running application for people and
  agents.

Explicit allocators, native error sets, ownership, bounded storage, and direct
Zig control flow remain non-negotiable.

## Landed

- `kernel.Service` provides stable typed capability tags.
- `kernel.Effect` records success, typed failure, and required services.
- `map`, `flatMap`, `tap`, `andThen`, `zip`, `catchAll`, `mapError`, and
  `named` compose lazily and infer service/error unions.
- `kernel.Layer` exposes construction inputs, outputs, startup errors, scoped
  acquisition, fluent provision, merge, and identity memoization.
- `zstd.ManagedRuntime` is the single application root builder, interpreter,
  inspector, embedded NenDB owner, checked persistence boundary, and disposer.
  `kernel.ManagedRuntime` remains its I/O-free lower-level interpreter.
- Runtime defaults cover config, console, random, and tracing with per-run
  overrides.
- Runtime aspects fan out causal, logging, metrics, tracing, and supervisor
  observations.
- Application snapshots describe layers, services, operations, dependency
  edges, memoized reuse, findings, fibers, and recent causal evidence.
- Retained causal event text is redacted, bounded, and packed into one owned
  allocation per event.
- Local application and service scaffolds teach the canonical process runtime;
  libraries export effects and default layers without a hidden runtime.

## Remaining migration debt

- Older engine regression domains still use `Effect(..., Env)`, `LayerGraph`,
  and related compatibility internals; canonical packages and applications do
  not depend on them.
- Production promotion still requires the declared Linux, live-service, soak,
  and authenticated qualification matrices. Local passing receipts do not
  promote unsupported targets.
- Ziac still tracks targeted domain/provider migration work in its composition
  roadmap, but its process roots and executor now use canonical services,
  layers, runtime handles, statecharts, and workflows.

Migration status is authoritative in:

- [Standard-library migration](../../zigeffect-std/docs/effect-native-roadmap.md)
- [Native gRPC migration](../../zigeffect-grpc/docs/effect-native-roadmap.md)
- [Ziac composition migration](../../ziac/docs/zigeffect-composition-roadmap.md)

## Developer-experience rules

1. New APIs must make the canonical path shorter than the compatibility path.
2. Application code must never construct a runtime inside a domain operation.
3. A transport may interpret child programs through a bounded runtime handle;
   ordinary services may not.
4. Default services and observability must not pollute ordinary requirement
   sets.
5. Every external resource has one acquisition owner and one finalizer.
6. Graphs show semantic operations and real runtime boundaries, not pure
   combinator noise.
7. Compile-time diagnostics should name the missing service, invalid effect
   return, or incompatible layer boundary and suggest the repair.
8. Generated projects are compile-tested in Debug and ReleaseSafe.
9. Testing v2 receipts are the source of truth for discovered/executed counts,
   leaks, logged errors, and replay.
10. Capability maturity follows checked-in evidence; a workflow definition or
    local experiment is never promoted into a production claim.

## Acceptance bar for public API changes

- a failing focused test precedes behavior changes;
- the public facade and generated templates stay synchronized;
- examples use only public imports;
- application docs use the canonical kernel unless explicitly describing
  migration debt;
- package-native tests emit complete Testing v2 receipts;
- public API, performance/resource, sanitizer, and downstream gates run in
  proportion to the change; and
- unsupported, skipped, or unrun evidence is stated plainly.

The validated architecture and implementation plan live in the repository
design records under `docs/superpowers/specs/` and `docs/superpowers/plans/`.
