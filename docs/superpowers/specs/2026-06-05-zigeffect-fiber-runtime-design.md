# Zigeffect Fiber Runtime Design

## Goal

Add Effect-style fiber semantics to `zigeffect` in three staged slices:

1. Build the zigeffect-owned fiber core.
2. Add a backend adapter boundary.
3. Add a zio-backed adapter package.

The fiber model should make zigeffect responsible for Effect semantics while
letting zio provide real stackful coroutine execution and `std.Io` integration
when that backend is selected.

## Current Context

`packages/zigeffect` already has:

- direct-style `Effect(Success, Failure, Env)` values
- `Runtime(Env)` with dependency validation and runtime-managed scopes
- `Scope` with reverse-order, fallible, and exit-aware finalizers
- structured `Exit` and `Cause`
- retry/repeat `Schedule`
- `Layer`, `LayerGraph`, `ServiceSet`, and dependency diagnostics
- `TestEnv` with fake clock, logger, config, metrics, tracing, and memory files

The current `Effect` type is synchronous and run-to-completion. That is a useful
Zig-native foundation, but it cannot suspend direct-style code at `join`,
`take`, or `await` points by itself. Real green-thread suspension should come
from a backend such as zio, which provides stackful coroutines, task groups,
safe cancellation, synchronization primitives, and a Zig 0.16 `std.Io`
implementation.

## Package Boundaries

`zigeffect` remains the semantic owner. It defines:

- fiber ids and status
- structured `Fiber` handles
- fork/join/interrupt/race/timeout contracts
- structured concurrency rules
- child cleanup behavior through `Scope`
- typed `Exit` and `Cause` behavior for fiber completion
- deterministic tests for lifecycle and ownership

`zigeffect` must not depend on zio. The core package should compile and test
without external async dependencies.

`packages/zigeffect-zio` becomes the optional real async backend. It may import
zio and translate zigeffect fiber operations onto zio runtime, task groups,
sleep, cancellation, channels, futures, and `std.Io`.

## Core Fiber Semantics

The core model should add these public concepts:

- `FiberId`: stable runtime-assigned id.
- `FiberStatus`: `pending`, `running`, `done`, `failed`, `interrupted`.
- `Fiber(Success, Failure, Env)`: typed handle for a child effect.
- `FiberRuntime(Env)`: runtime facade that can fork and supervise effects.
- `FiberLease`: a runtime-owned lifetime token that binds a fiber to a parent
  scope.
- `Deferred(Success, Failure)`: one-shot completion cell.
- `Queue(T)`: bounded or unbounded FIFO coordination primitive.
- `Semaphore`: permit counter for structured throttling.

The lease concept is the ownership rule: every forked fiber is leased either to
the current `Scope` or to an explicit runtime root. When the scope closes, any
unfinished leased child is interrupted before finalizers run. This gives
`forkScoped` and runtime-managed cleanup the same shape as existing resource
finalizers.

## Stage 1: Core First

Stage 1 should be additive inside `packages/zigeffect`.

The first implementation should define the typed fiber API, lifecycle state, and
deterministic runtime behavior without adding zio. Because current effects are
synchronous, the deterministic runtime may execute child effects
run-to-completion when scheduled. That is enough to test:

- ids are assigned monotonically
- fork returns a typed handle
- join returns the child `Exit`
- successful children close child scopes with success
- failed children close child scopes with failure
- interrupted pending children close child scopes with interruption
- scoped fibers are interrupted when their parent scope closes
- dependency validation still happens before execution
- `Cause.interrupted` and `Exit.interrupted` are formatted clearly

This stage should not claim real parallelism or non-blocking IO. It establishes
the public contract and safety rules that every backend must satisfy.

## Stage 2: Backend Adapter Boundary

Stage 2 introduces an internal backend interface that separates semantics from
execution.

The adapter boundary should cover:

- spawn an effect into a backend-owned task
- join a backend-owned task
- interrupt or cancel a backend-owned task
- sleep using backend time
- run a function under a child scope
- expose backend capabilities such as `supports_real_suspension`

The adapter must preserve zigeffect semantics:

- parent scopes own child leases
- all child exits become zigeffect `Exit`
- interruption is cooperative where the backend requires cooperation
- finalizer failures remain visible through existing `Cause.finalizer_failure`
- dependencies are checked before backend task creation

The default adapter in core should remain deterministic and test-friendly.

## Stage 3: Zio Backend

Stage 3 adds `packages/zigeffect-zio`.

The zio adapter should:

- depend on `git+https://github.com/lalinsky/zio#v0.13.0` or a pinned newer
  release after verification
- require Zig 0.16-compatible zio
- map zigeffect fork to zio `spawn` or task group operations
- map scoped fibers to zio `Group` lifetime
- map sleep to zio sleep/time primitives
- map interruption to zio cancellation
- use zio synchronization primitives for `Deferred`, `Queue`, and `Semaphore`
  when running under zio
- expose zio `std.Io` as the IO boundary for future zigeffect services

The zio package should be optional. `packages/zigeffect` tests must pass without
network access or external package fetches.

## Public API Direction

The target usage should stay direct-style:

```zig
fn loadProfile(ctx: *fx.Context(AppEnv)) AppError!Profile {
    const logger = ctx.service(fx.Logger);
    try logger.info("loading profile");
    return .{};
}

const LoadProfile = fx.Effect(Profile, AppError, AppEnv).fromFn(loadProfile);

var runtime = fx.FiberRuntime(AppEnv).init(allocator, &env);
const fiber = try runtime.fork(LoadProfile);
const exit = try runtime.join(fiber);
```

Scoped usage should bind child work to the parent runtime scope:

```zig
const fiber = try runtime.forkScoped(ctx, LoadProfile);
```

If the parent scope closes before the fiber completes, the child receives an
interruption exit and its child scope closes with `FinalizerExit.interrupted`.

## Error Handling

Fiber APIs should preserve typed failures:

- child effect failure returns `Exit.failure(Failure)`
- interruption returns `Exit.interrupted(FiberId)`
- unexpected backend/runtime failures return `Exit.defect` or allocator errors
  at API boundaries
- finalizer failures return `Exit.cause(Cause.finalizer_failure(...))` when
  observed through runtime exit APIs

`FiberRuntime.run` should continue to return typed errors for direct execution.
`FiberRuntime.exit`, `Fiber.joinExit`, and test helpers should expose full
structured exits.

## Testing Strategy

Use TDD for each behavior.

Core tests in `packages/zigeffect/test/core_test.zig` should cover:

- fork/join success
- fork/join typed failure
- interrupt pending fiber
- child scope finalizer receives success/failure/interruption
- scoped child is interrupted on parent scope close
- `Deferred` completes once and rejects duplicate completion
- `Queue` preserves FIFO order
- bounded `Queue` reports full/empty deterministically in the core runtime
- `Semaphore` acquires/releases permits and rejects over-release
- dependency requirements are validated before forking
- formatted interruption reports include fiber id and next-action hint

The zio package should have separate tests under `packages/zigeffect-zio/test`.
Those tests may require fetching zio and should not be part of the base
`zigeffect:test` command until the dependency is pinned and stable.

## Documentation

Update zigeffect docs to explain:

- fibers are structured runtime work, not OS threads
- core runtime is deterministic and semantic-first
- zio is the real async backend
- libraries should prefer `std.Io` at IO boundaries
- direct-style code remains the primary user experience

Add zio adapter docs only after the package exists.

## Non-Goals

- No rewrite of the existing `Effect` API.
- No zio dependency in `packages/zigeffect`.
- No claim that the core deterministic runtime provides real green-thread
  suspension.
- No Worker request-path dependency on Zig or zio.
- No automatic migration of RoachGraph or Yachdee application code.
- No broad stream/STM implementation in this slice.

## Verification

Required after Stage 1:

```bash
bun run zigeffect:test
```

Required after Stage 3:

```bash
bun run zigeffect:test
bun run zigeffect-zio:test
```

Repository-level verification remains:

```bash
bun run zig:test
bun run typecheck
```
