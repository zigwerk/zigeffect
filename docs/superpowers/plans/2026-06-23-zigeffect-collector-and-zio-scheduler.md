# Live-attach collector + scheduler-on-zio (2026-06-23)

The two residual items after the six final-completion tracks. Both bridge a real
boundary the earlier work intentionally stopped at. Verifiable end-to-end.

## Piece 2 — Run the workflow scheduler on the zio backend (push/pull reconciliation)

**The gap (from the mapping):** `WorkflowScheduler.tickAsync` does
`registerPendingTimerWaits → advanceTime(nowMs) → consumeBackendWakes(busy-poll
pollWake until null) → …`. On the deterministic backend `advanceTime` fires due
timers synchronously and `pollWake` drains them in the same tick. On zio,
`advanceTime` is a no-op, `scheduleTimer` spawns a REAL timer coroutine, and
`pollWake` only returns the wake AFTER the real timer fires. A single `tickAsync`
polls before the timer fires and gets nothing; a naive caller would busy-spin,
never yielding to zio's event loop so the timer coroutine can't even run.
`BackendCapabilities` has no flag to tell the two clock models apart.

**Build:**
1. `BackendCapabilities.real_clock: bool` (default `false`). Add
   `asyncRealBackend()` = `asyncLocalBackend()` + `real_clock = true`. zio's
   `backend()` uses it; the deterministic backend stays `real_clock = false`.
2. zio `scheduleTimer`: sleep the RELATIVE delay `due_time_ms -| now_ms` (today it
   sleeps the absolute timestamp — fine for the Track E test where `now_ms = 0`,
   wrong for the scheduler which passes `now_ms = clock.nowMs()` and an absolute
   `fire_at_ms`).
3. Scheduler timer-registration dedup (`registered_timer_ids`): register a journal
   timer with the backend ONCE; clear the id when its wake is consumed. Prevents
   re-spawning a real coroutine every tick (the mapping flagged duplicate
   registration as a pre-existing gap). Deterministic single-tick behavior is
   unchanged (register→fire→consume→clear within one `tickAsync`).
4. `WorkflowScheduler.pumpAsyncUntilIdle(budget, quantum_ms)`: loop `tickAsync`;
   after each tick read `backend.snapshot()`; if pending timers remain AND the
   backend is `real_clock`, `backend.blockingSleep(quantum_ms)` to yield the event
   loop so the timer coroutine runs, then re-tick; stop when idle (no pending
   timers and no progress), on shutdown, or at `max_iterations`. On a non-real
   backend it degrades to a `drain`-style loop (the caller advances virtual time).

**Tests:**
- Core (deterministic): `pumpAsyncUntilIdle` fires a virtual timer in one pump and
  terminates (does not spin); `real_clock` defaults false.
- zio (`zigeffect-zio`): a `WorkflowScheduler` on the zio backend with a journal
  `context.sleep(~15ms)` timer; `pumpAsyncUntilIdle` inside a live zio runtime
  drains it — the journal records `timer_fired` + `workflow_resumed` (the real
  coroutine fired on the real clock, the pump yielded, the wake was consumed).

## Piece 1 — Live-attach collector (CausalHubBackend → WebSocket)

**The contract (from the mapping):** the frontend `webSocketLiveSource` expects
ONE JSON `LiveFrame` per WebSocket message (`{sequence,event_id,event_kind,status,
label?,lane?,parent_id?,finding_kind?,dashboard_priority?}`). The engine already
serializes a `CausalEvent` to NDJSON via `formatCausalJsonLine` and republishes
events to a `Hub(CausalEvent)` (`CausalHubBackend`). Bun.serve (with WebSocket) is
the project's local-server pattern; the runtime boundary permits Bun-native in
local tooling (not Worker handlers).

**Architecture (simplest honest transport):**
`engine (NDJSON via Hub tap) → Bun collector (map → fan-out) → browser`.

1. **Engine tap (Zig):** `causalHubDrainToNdjson(allocator, hub, sub_id, writer)`
   — drain a `Hub(CausalEvent)` subscription, serialize each event to an NDJSON
   line via `formatCausalJsonLine`, write to a writer. Tested: record events
   through a store with `CausalHubBackend`, subscribe, drain, assert NDJSON.
2. **Collector (Bun/TS)** at `packages/zigeffect/workbench/collector/`:
   - `frame.ts`: `causalLineToFrame(line, sequence) → LiveFrame | null` — map an
     engine NDJSON `CausalEvent` line to a `LiveFrame` (event_id←id, event_kind←
     kind, status, label, parent_id; lane derived from run/scope/fiber;
     dashboard_priority derived from status). Pure, tested.
   - `collector.ts`: `createCollector()` → `{ fetch, websocket, ingestLine,
     clientCount }`. `/live` upgrades to WS (subscribers); `POST /ingest` reads an
     NDJSON body, maps each line, broadcasts ONE frame per WS message; a stdin
     reader for `engine | collector`. `import.meta.main` binds a port.
   - Tests (bun:test): frame mapping; ingest→broadcast to a real connected WS
     client; multiple clients; malformed-line tolerance.
3. Wire `zigeffect:collector:test` into the root test script.

**Honest boundary that closes here:** the frontend's `webSocketLiveSource` now has
a real server to talk to (`?live=ws://127.0.0.1:<port>/live`), fed by real engine
NDJSON. Browser rendering of the live stream remains a manual check.

## Order & gates
Piece 2 first (contained, core+zio), then Piece 1 (Zig tap + Bun collector).
Gates: core `test-raw`+`examples`+`release-gate`+`tool-hygiene`; `zig build test`
(zio); `bun test` (collector) + workbench typecheck/test. Adversarial review last.

---

## Delivery log (2026-06-23)

Both pieces delivered, then hardened against an adversarial review.

- **Piece 2 — scheduler on zio** (`83146b35`): `real_clock` capability +
  `asyncRealBackend()`; zio `scheduleTimer` relative-delay; scheduler timer
  dedup; `pumpAsyncUntilIdle` (yields the event loop on real-clock backends).
  Deterministic + zio end-to-end timer tests.
- **Piece 1 — live-attach collector** (`db9bd483`): Zig tap + Bun WebSocket
  collector (`createCollector`) mapping engine NDJSON → `LiveFrame`, one per
  message; real WebSocket fan-out tested.
- **Hardening** (`ed452a13`): a 4-dimension adversarial review (each finding
  independently verified) found two real use-after-frees and several
  liveness/validation defects. Fixed: (UAF) zio backend now OWNS suspension
  labels in an arena (the scheduler frees the borrowed `timer.name` before the
  timer fires); (UAF) replaced the borrowed-slice `drainHubToNdjson` with
  `CausalNdjsonTap`, which serializes each event under its `record` call into an
  owned buffer — proven UAF-safe with a bounded(1) store that trims every record;
  (liveness) a failed timer-coroutine spawn now resolves immediately instead of
  orphaning the suspension (pump always reaches idle); (thrash) the timer
  registration is released only when the journal timer actually fires, not on any
  wake; (validation) collector broadcast skips non-OPEN sockets, and frame
  mapping requires safe non-negative integer ids.

**Residual after this:** none that is fake-able today. The remaining honest
follow-ups are operational, not code gaps — wiring the collector binary into a
real engine run + manual browser verification of the live stream, and (if ever
needed) running the *full* cluster transport on zio (the workflow scheduler path
is done; cluster transport uses the same vtable but was out of scope here).
