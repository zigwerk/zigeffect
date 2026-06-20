# zigeffect-zio Backend — Design

Date: 2026-06-20
Status: design (no code yet)
Supersedes the "Stage 3: Zio Backend" section of
[2026-06-05-zigeffect-fiber-runtime-design.md](./2026-06-05-zigeffect-fiber-runtime-design.md)
with the concrete v0.14.0 plan.

## Summary

Add `packages/zigeffect-zio`, an **optional** adapter package that gives
`zigeffect` real stackful-coroutine concurrency by implementing the existing
`AsyncBackend` vtable on top of [zio](https://github.com/lalinsky/zio) v0.14.0.
The core `packages/zigeffect` stays zio-free and must keep passing its tests
without it. The deterministic `LocalAsyncBackendState` remains the
compatibility-suite reference: a program must produce the same *structural*
causal trace under both backends.

## Why zio

- zio is an async I/O framework with **stackful coroutines** over a
  cross-platform **event loop** (io_uring / epoll / kqueue) and a **full
  `std.Io` implementation**.
- Its `main` branch targets **Zig 0.16** (the `zig-0.17` branch is for Zig
  master), matching this repo's `minimum_zig_version`. The earlier
  compatibility risk is resolved.
- The alternative, `std.Io.Evented`, is unfinished upstream ("missing essential
  functionality, if it even builds"), so it is not a viable target yet.
- zio's layered architecture exposes the fiber runtime, `std.Io`, **and** the
  raw event loop, which is what lets us implement every `AsyncBackend` primitive
  — including the non-IO park/unpark our coordination primitives need.

Install (in the adapter package only):

```bash
zig fetch --save "git+https://github.com/lalinsky/zio#v0.14.0"
```

## Current state (what exists, what does not)

- **The seam exists and is plumbed.** `src/runtime/async_backend.zig` defines
  `AsyncBackend` with a 9-method `VTable`:
  `suspend_runtime`, `wake`, `schedule_timer`, `interrupt`, `register_io_wait`,
  `complete_io`, `poll_wake`, `advance_time`, `snapshot`. It is an optional field
  on `Runtime`/`FiberRuntime`/`Context` (`withAsyncBackend`), so the context can
  carry a backend.
- **The execution path does not invoke it yet.** `FiberState.run` /
  `join` ([src/runtime/fiber.zig:204,224](../../../packages/zigeffect/src/runtime/fiber.zig))
  run the effect **synchronously to completion**; nothing calls
  `suspendRuntime`/`registerIoWait` at a blocking point. So forks don't actually
  suspend — they run start-to-finish at `join`.
- **Coordination primitives are immediate-return state machines.**
  `Deferred`/`Queue`/`Semaphore` ([src/runtime/coordination.zig](../../../packages/zigeffect/src/runtime/coordination.zig))
  expose `awaitState`/`offerState`/`acquireState` plus operations that return at
  once with `FiberPrimitiveError`; they inspect wait-state, they do not park a
  fiber.
- **Only the deterministic backend is implemented.**
  `LocalAsyncBackendState` registers virtual waits, fires timers on
  `advanceTime`, and drains ready events via `poll_wake`.
  `UnsupportedAsyncBackendState` rejects everything.

**Consequence:** the zio work is *two-sided*. We must (A) wire the execution and
coordination paths to actually call the backend at blocking points, and (B)
implement the zio backend behind the vtable. (A) is shared infrastructure that
also makes `LocalAsyncBackendState` exercise real suspend/resume in tests; (B) is
the zio-specific package. Doing (A) first, proven against the deterministic
backend, de-risks (B).

## Goals

1. Real suspension: a fiber blocked on a timer or IO yields the OS thread and
   resumes on completion, under zio.
2. Real structured concurrency: scoped forks map to a `zio.Group` whose lifetime
   bounds the children; scope close cancels them.
3. The core stays zio-free and green without zio; zio is a dependency of the
   adapter package only.
4. The causal trace stays meaningful: the same program yields the same
   structural causal graph under deterministic and zio backends.

## Non-goals

- No zio dependency in `packages/zigeffect`, no Worker request-path dependency on
  Zig or zio.
- Not rewriting the effect/layer/scope API; the user-facing surface is unchanged.
- Not chasing full parity in v1 — one timer primitive end-to-end first.
- No durable/distributed work here (separate roadmap items).

## Package boundary

```
packages/zigeffect          # core — unchanged, zio-free, green without zio
packages/zigeffect-zio       # new — depends on zio, implements AsyncBackend
  build.zig.zon              # the ONLY place zio is declared
  src/zio_backend.zig        # ZioAsyncBackendState : AsyncBackend.VTable
  src/runtime_entry.zig      # zio.run(...) entry that hosts a FiberRuntime
  test/                      # zio-backed tests (may fetch zio; separate gate)
```

- CI keeps `zig build test-raw` (core) passing **without** zio. A separate
  `zigeffect-zio:test` gate builds the adapter and runs its tests.
- The adapter imports `zigeffect` as a module and `zio` as a dependency; the
  arrow is one-way.

## AsyncBackend vtable ↔ zio mapping

zio's three layers cover the full vtable. The non-IO park/unpark (the last two
rows) is exactly why a `std.Io`-only backend would be insufficient.

| `AsyncBackend` method | zio layer | zio mechanism |
|---|---|---|
| `suspend_runtime(req)` | fiber runtime | yield the current zio coroutine, parking it keyed by `req.suspension_id` |
| `wake(req)` | fiber runtime | reschedule the parked coroutine for `req.suspension_id` |
| `schedule_timer(req)` | event loop | register a timer; on fire, `wake` the suspension |
| `register_io_wait(req)` | event loop / `std.Io` | register fd readiness (or issue the `std.Io` op); on completion, `complete_io` + `wake` |
| `complete_io(req)` | event loop | mark the IO wait satisfied and resume |
| `interrupt(req)` | fiber runtime | `group.cancel` / targeted cancellation of the parked coroutine; resume with `interrupted` |
| `poll_wake()` | — | under zio the loop drives wakes directly; `poll_wake` returns already-resolved events for inspection/parity |
| `advance_time(now)` | — | **deterministic backend only**; under zio time is real, so this is a no-op/UnsupportedForRealTime |
| `snapshot()` | fiber runtime | report parked/ready/interrupted counts for tests and the causal workbench |

Structured-concurrency mapping (unchanged from the 2026-06-05 intent, confirmed
against v0.14.0):

| zigeffect | zio |
|---|---|
| `FiberRuntime.fork` | `group.spawn(...)` |
| `forkScoped` / `forkInScope` (scope-lease) | child registered in the owning scope's `zio.Group`; scope close → `group.cancel()` |
| `Fiber.interrupt` | targeted cancellation |
| `Deferred.await` | zio future/await (or a 1-slot channel) |
| `Queue.offer` / take | zio channel |
| `Semaphore.acquire` | zio semaphore (or counting park on the event loop) |
| effect IO | `std.Io.Reader` / `std.Io.Writer` |

## Execution model decision

**Run-under-zio.** The program entry becomes `zio.run(rootFiber)`; the
`FiberRuntime` runs *inside* a zio runtime, forks are zio coroutines, and a
blocking effect calls `backend.suspendRuntime(...)` which yields the current
coroutine. `wake`/timer/IO completions resume it. This is the only model that
delivers real suspension; the alternative (zigeffect pumping zio's loop via
`poll_wake`) would re-impose cooperative, non-suspending semantics and defeat the
point.

The deterministic `LocalAsyncBackendState` keeps the **poll + `advance_time`**
model unchanged — tests drive virtual time explicitly. The runtime therefore
abstracts over a "drive mode": *pumped* (deterministic, advance_time) vs *hosted*
(zio owns the loop). Wiring task (A) introduces the suspension call sites; each
backend interprets them in its own drive mode.

## Causal-trace equivalence strategy

Under real scheduling, absolute event **ordering and ids can legitimately vary**,
so "diff the two JSON artifacts" is the wrong oracle. Equivalence is defined on
**structural invariants** of the causal graph, which both backends must satisfy
for the same program:

- the same set of fibers fork, and each reaches the same terminal status
  (done / failed / interrupted);
- the same parent/cause edges (which scope owns which fiber; which interrupt was
  caused by which scope close);
- the same resource acquire/finalize pairing and finalizer ordering per scope;
- the same typed `Exit`/`Cause` at each join.

Delivery order:

1. **Deterministic-ordering scenarios first** — a single active fiber suspends on
   a timer, parent scope closes → child cancels. Here even exact-trace
   equivalence holds, so the first proof is tight.
2. **Interleaved scenarios next** — compare structural invariants only, asserting
   the partial order the program guarantees (e.g. "child finalizes before parent
   scope close completes"), not a total order.

The existing `causal-compare` / dev-loop tooling is the harness; add a
structural-invariant comparator alongside the exact-diff one.

## Staged delivery

- **Stage 0 — wiring (core, no zio).** Introduce the suspension call sites: make
  a `sleep` effect and `Deferred.await`/`Queue.take`/`Semaphore.acquire` call
  `backend.suspendRuntime`/`wake`. Prove against `LocalAsyncBackendState` with
  `advance_time`. Core stays green; this is the (A) half and ships first.
- **Stage 1 — zio timer.** `packages/zigeffect-zio` with `ZioAsyncBackendState`;
  implement `suspend_runtime`/`wake`/`schedule_timer`. Prove: a fiber sleeps,
  yields the thread, resumes; deterministic-scenario causal-trace equivalence.
- **Stage 2 — zio IO wait.** `register_io_wait`/`complete_io` over a real socket
  read via `std.Io`. Prove: a fiber blocked on a socket wakes on data.
- **Stage 3 — coordination + cancellation.** Back `Deferred`/`Queue`/`Semaphore`
  with zio primitives; map scoped-fiber cancellation to `zio.Group.cancel`.
  Prove: scope close cancels a parked child; structural-invariant equivalence on
  an interleaved scenario.
- **Stage 4 — hardening.** Error/defect propagation, allocator ownership across
  the yield boundary, leak checks, and the `zigeffect-zio` conformance gate.

Each stage is a small PR with a failing test first (TDD), per the repo rules.

## Risks and mitigations

- **Allocator/lifetime across the yield boundary.** A parked coroutine's stack
  and captured `Task`/`State` must outlive the suspension. Mitigation: the
  fiber `State` already owns its allocation and child `Scope`; pin it for the
  parked duration and free on resume/cancel, as the deterministic path does.
- **Ordering nondeterminism breaking tests.** Mitigation: structural-invariant
  oracle (above); exact-diff only for single-active-fiber scenarios.
- **zio API churn / 0.16-vs-0.17 split.** Pin `#v0.14.0`; if the repo moves to
  Zig master, switch to zio's `zig-0.17` branch in lockstep — isolated to the
  adapter's `build.zig.zon`.
- **Causal events under real concurrency.** `CausalStore.record` must stay safe
  if events can be appended from resumed coroutines; confirm single-runtime
  ownership (one runtime per zio.run) so there is no cross-thread contention in
  v1. Real multi-thread parallelism is out of scope until proven single-threaded.
- **Core accidentally taking the dep.** A CI check asserts `rg zio packages/zigeffect/src` is empty.

## Test plan

- Core (no zio): `cd packages/zigeffect && zig build test-raw` stays green after
  Stage 0 wiring.
- Adapter: `bun run zigeffect-zio:test` (new) builds against zio and runs the
  stage tests; may fetch zio, kept out of the base gate.
- Equivalence: a shared scenario set run under both backends, compared by the
  structural-invariant comparator (and exact-diff for deterministic scenarios).
- `causal-dev-loop` baseline/after around each stage to show the causal trace
  improves rather than merely changes.

## Open questions

1. **Single-threaded first?** v1 should host one `FiberRuntime` per `zio.run` on
   one OS thread (real suspension, no real parallelism) to keep `CausalStore`
   single-owner. Multi-thread parallelism is a later, separate proof. Confirm.
2. **`Deferred`/`Queue`/`Semaphore`: zio-native vs park-on-event-loop?** Native
   zio channels/semaphore are simpler; the event-loop park is more uniform with
   the vtable. Decide in Stage 3 against a real interleaved scenario.
3. **Where does `sleep` live?** Add a first-class `sleep`/`delay` effect in core
   (Stage 0) that routes through `schedule_timer`, or keep it in `Schedule`?
   Leaning: a small core `delay` effect, since it is the canonical suspension
   point.
