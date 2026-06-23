# zigeffect Final Completion Roadmap (2026-06-23)

The remaining six items after the productization push. Ordered by tractability:
engine-side + fully verifiable first, the frontend (least verifiable here) last.
Every milestone ships with a test; concurrency/safety milestones add a
mutation-test or real-OS-thread proof.

Gates per milestone: `zig build test-raw` + `examples` + `release-gate` +
`tool-hygiene` (core) and `zig build test` (zigeffect-zio).

---

## Track A — Race completion: `race` + `both`

Atop the shipped `raceFirst`/`raceAll` (poll-park `waitAny` + `interrupt`).

- **A.1** `race(other)` — first to SUCCEED wins. If the first completer FAILED,
  wait for the other and return its result; if both fail, return the
  last-completing failure. Implement by looping `waitAny` over the not-yet-done
  handles: on a success, interrupt the rest and return; on a failure, drop that
  handle and continue.
- **A.2** `both(other)` — parallel pair, FAIL-FAST: if either branch fails,
  interrupt the other and return the failure; if both succeed, return the
  `ZipPair`. (Distinct from `zipPar`, which waits for both regardless.)
- **A.3** Tests: core (synchronous racing executor) for the result logic +
  zigeffect-zio (real timing) proving short-circuit (fast success cancels slow
  loser; first failure cancels the slow other).

## Track B — Thread-pool `FiberExecutor` (core, std.Thread)

A second real executor (besides zio coroutines), proving the abstraction over
genuine OS-thread parallelism — now that `CausalStore`/`Ref`/`Hub` are
thread-safe.

- **B.1** `ThreadPoolExecutor` in `src/runtime/` implementing the FiberExecutor
  vtable: `spawn` runs the `FiberJob` on a worker thread, `join` blocks on a
  per-job completion signal, `destroy` frees, `waitAny` polls completion flags.
- **B.2** `interrupt` is best-effort: sets a cooperative cancel flag; the job
  only stops if its body polls it (OS threads can't be safely async-preempted).
  Document that thread-pool `race` doesn't short-circuit the loser's WORK (only
  its result is discarded) — honest limitation vs zio's coroutine cancel.
- **B.3** Tests: `forEachPar`/`zipPar` on the thread-pool executor produce
  correct results AND a structurally-equivalent causal trace to the
  deterministic run (the D2 invariant over real OS threads). Run under the leak
  detector.

## Track C — Heterogeneous STM

Lift the homogeneous STM (M6.1) to transactions that touch `TRef(A)`,
`TRef(B)`, … in one atomic body.

- **C.1** Type-erased read/write log: `get(comptime T, ref)` logs
  `{ ref:*anyopaque, read_version:fn(*anyopaque)u64, observed }` (the version
  reader generated per-T at the call site); `set(comptime T, ref, value)`
  stages `{ ref, value_bytes (heap), apply:fn(ref,value)void }`.
- **C.2** Commit validates versions (type-agnostic u64 compare) then applies
  writes (type-specific via the generated apply fn), all under the Stm lock.
- **C.3** Tests: an atomic transaction over a `TRef(u64)` AND a `TRef([]const u8)`
  (transfer + flag) commits atomically; conflict-retry across two heterogeneous
  threads; mutation-proven discrimination.

## Track D — Full FiberRef auto-propagation

Make `FiberRef` propagate across fork WITHOUT an explicit `forkChild`, for
values that fit inline — reusing the existing Context shallow-copy.

- **D.1** Add a fixed inline `fiber_local_slots: [N]u64` array to `Context` plus
  a slot cursor. Because the executor's `FiberJob` already copies `ctx.*` by
  value, the slots auto-SNAPSHOT on fork — child inherits, mutations stay local.
- **D.2** `FiberRefSlot(T)` (for `@sizeOf(T) <= 8`): claims a slot, get/set
  read/write `ctx.fiber_local_slots[idx]` (bitcast T↔u64). Document the size
  limit; larger T keeps the explicit `forkChild` cell (M5.3) or a future heap
  frame.
- **D.3** Tests: a FiberRefSlot set in a parent ctx is visible in a forked child
  ctx (via the executor copy) and mutations in the child don't affect the
  parent — proven through a real `forEachPar`/fork on an executor.

## Track E — zio `AsyncBackend` vtable fill

Migrate the 6 stub methods from `error.UnsupportedBackendCapability` to working,
driven THROUGH the engine's AsyncBackend interface (not the scenario harness).

- **E.1** `schedule_timer` — per-suspension-id zio timer (`zio.sleep` keyed by id).
- **E.2** `interrupt` — per-suspension cancel (wire to the coroutine/group cancel).
- **E.3** `suspend_runtime` / `wake` — park/unpark keyed by suspension id.
- **E.4** `register_io_wait` / `complete_io` — over `zio.net` / `std.Io`.
- **E.5** Per-method adapter test driving each via `Context.suspendRuntime` etc.;
  migrate the conformance test from "asserts Unsupported" to "asserts working"
  as each lands.

## Track F — SolidJS workbench live-attach frontend

The only non-engine track. Verifiable by build/typecheck + data-binding unit
tests (no browser in this loop).

- **F.1** A bridge module that consumes the `CausalHubBackend` event stream
  (over the workbench's existing WebUI transport) and maintains a live causal
  graph model.
- **F.2** A "Live" view component that renders the streaming graph (nodes =
  events, edges = cause/parent), updating as events arrive.
- **F.3** Verify: `bun run zigeffect:workbench:typecheck` (tsc) green + a unit
  test of the bridge's event→graph reduction. Browser rendering is manual
  (out of scope for autonomous verification) — flag honestly.

---

## Execution order & verification protocol

A → D → C → B → E → F. After each milestone: full gate sweep; for
concurrency/safety milestones, a real-OS-thread test + a mutation check that the
test is discriminating. Commit per milestone with the Co-Authored-By trailer.
Update the master roadmap's progress log + delivery boundary as tracks close.

Honest stop conditions: if a zio vtable method (Track E) needs a zio API that
isn't exported (as `selectAwaitables` was), record the precise gap + a
poll/fallback rather than fake it. If the frontend (Track F) can't be verified
beyond typecheck without a browser, say so.

---

## Delivery log — ALL SIX TRACKS COMPLETE (2026-06-23)

Executed A → D → C → B → E → F. Every track shipped with tests; concurrency/safety
tracks added real-OS-thread proofs and mutation checks. All gates green per
commit (`test-raw` + `examples` + `release-gate` + `tool-hygiene` for core,
`zig build test` for zio, `typecheck` + `test` for the workbench).

- **Track A — race + both** (`6e9af4c0`): `RaceEffect` (prefer-success: first
  `.value` wins, interrupting the other; on `.err` await the other) and
  `BothEffect` (fail-fast: first failure interrupts the other, else assemble the
  pair). Short-circuit via poll-park `waitAny`; zio timing tests + core tests.
- **Track D — FiberRef auto-propagation** (`c01c83dc`): `FiberRefSlot(T)` for
  `@sizeOf(T)<=8`, stored in `Context.fiber_local_slots`, auto-snapshotted on
  fork by the executor's context copy. Auto-propagation test.
- **Track C — heterogeneous STM** (`7aee8dca`): `HeteroTransaction` with a
  type-erased read/write log; `Stm.atomicallyMixed` touches `TRef`s of different
  value types in one atomic body. Proof: 8 threads × 1000 two-ref txns leave both
  refs equal at 8000 (atomic multi-ref commit under real concurrency).
- **Track B — ThreadPoolExecutor** (`1c893d48`): a `FiberExecutor` over real OS
  threads. `forEachPar`/`zipPar` now run on the deterministic backend, on zio
  coroutines, OR on an OS-thread pool — one abstraction, three executors. The D2
  structural-equivalence invariant holds over real OS-thread parallelism.
  Documented honest limit: thread `interrupt` is cooperative-only.
- **Track E — zio AsyncBackend vtable fill** (`99f3358b`): migrated the six
  stubbed pull-model methods from `UnsupportedBackendCapability` to a real
  registration + wake-queue (`suspend_runtime`/`register_io_wait`/`wake`/
  `complete_io`/`interrupt`/`poll_wake`); `schedule_timer` spawns a REAL zio
  timer coroutine. `advance_time` is the one deterministic-only concept (no-op on
  zio). Conformance test flipped from asserts-Unsupported to asserts-working.
- **Track F — workbench live-attach** (`6e346f9b`): `liveAttach.ts` —
  `LiveCausalBuffer` (sequence order, event_id dedup, ring window), `LiveSource`
  transport abstraction (mock + WebSocket), and `createLiveArtifact` Solid
  reactive integration. `?live=<ws-url>` streams frames into the SAME views.
  +12 tests (43→55). HONEST BOUNDARY: the WebSocket transport needs the
  engine-side collector endpoint (not yet built); browser rendering is manual.

Residual (genuinely needs new external surface, not fake-able here): the
live-attach HTTP/WS COLLECTOR endpoint that bridges `CausalHubBackend` to the
workbench socket, and running the cluster/workflow scheduler ON the zio backend
(needs the scheduler loop to cooperate with zio's event loop — the engine-loop
push/pull reconciliation, beyond the vtable itself).
