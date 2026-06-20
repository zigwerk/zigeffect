# zigeffect Async/Concurrency Delivery Roadmap (zio backend)

Date: 2026-06-20
Status: active
Design: [2026-06-20-zigeffect-zio-backend-design.md](../specs/2026-06-20-zigeffect-zio-backend-design.md)
Engine roadmap: [packages/zigeffect/docs/roadmap.md](../../../packages/zigeffect/docs/roadmap.md)

This is the comprehensive, staged delivery plan for the single biggest gap in the
engine: **real structured concurrency**. The engine today has the
structured-concurrency *discipline* (scope-bound forks, cancellation propagation,
typed exits) but runs as a deterministic, run-to-completion simulation. This
roadmap delivers real suspension/resumption on [zio](https://github.com/lalinsky/zio)
v0.14.0 while keeping the core deterministic and zio-free, and it makes the
engine's own causal reporter — queried by AI agents — the standing test
methodology for every increment.

## Principles (non-negotiable)

1. **Core stays zio-free.** `packages/zigeffect` compiles and passes
   `zig build test-raw` without zio. zio lives only in `packages/zigeffect-zio`.
2. **The deterministic backend is the reference.** `LocalAsyncBackendState`
   (virtual clock) is the oracle; the same program must produce the same
   *structural* causal trace under deterministic and zio backends.
3. **Causal-verified, not log-scraped.** Each increment's acceptance criteria are
   expressed as assertions over the causal graph and checked by AI agents running
   `causal-query` — "the test passes" means "the graph shows the required
   cause/lineage edges," not just a green assertion.
4. **TDD.** Failing test first, then implement, per repo rules.
5. **Tool hygiene.** No new record-only tools; new capability goes in `src/` with
   tests; any new tool needs an approved `tool-roadmap.md` entry.

## The standing test methodology — the agent causal-verification loop

Every increment runs this loop (already demonstrated against the current engine,
which is how the Stage 0 criteria below were derived):

1. **Instrument** — a scenario attaches a `CausalStore` to the runtime and drives
   the `AsyncBackend` via `LocalAsyncBackendState` with `advanceTo` (virtual
   clock, no real sleeps).
2. **Run** — execute the scenario → `zigeffect.causal.v1` JSON/DOT/text artifact
   under `.zig-cache/causal-artifacts/`.
3. **Agent causal verification** — AI agents run `causal-query`
   (`fibers`/`cause`/`lineage`/`snapshot`) against the artifact to adversarially
   verify each acceptance criterion, reporting holds/violates with event ids and
   treating vacuous passes (empty fiber set) as failures.
4. **Compare** — `causal-compare` baseline vs after proves the new events appeared
   and unrelated scenarios did not regress.
5. **Advice** — `causal-advice` must be clean (no new findings).

An increment is DONE only when all agents confirm every criterion holds
non-vacuously, `causal-compare` shows the expected additive delta with no
regression, and `causal-advice` is clean.

## Architecture

```
packages/zigeffect            core engine — deterministic, zio-free
  src/services/causal.zig      causal event taxonomy (+ suspension kinds, Stage 0)
  src/runtime/async_backend.zig  AsyncBackend vtable + LocalAsyncBackendState (deterministic)
  src/runtime/fiber.zig          fiber lifecycle; suspension call sites (Stage 0)
  src/runtime/coordination.zig   Deferred/Queue/Semaphore; park/resume (Stage 0/3)
packages/zigeffect-zio         optional adapter — depends on zio only
  src/zio_backend.zig          ZioAsyncBackendState : AsyncBackend.VTable (Stages 1-3)
  src/runtime_entry.zig        zio.run host (Stage 1)
```

The `AsyncBackend` vtable (`suspend_runtime`, `wake`, `schedule_timer`,
`interrupt`, `register_io_wait`, `complete_io`, `poll_wake`, `advance_time`,
`snapshot`) is the seam. Core owns the causal-event emission around suspension;
each backend owns the actual park/unpark. The deterministic backend models
suspension with a virtual clock; zio performs it with real coroutines.

## Stages

### Stage 0 — Suspension in the causal model (in-core, zio-free) — ACTIVE

**Why first:** the causal taxonomy has no way to express a fiber pausing and
resuming (confirmed by agents querying the graph). Until it does, real suspension
would be causally invisible — we could not verify it. This stage lands the
vocabulary and the deterministic suspension model, fully tested, with **zero zio
dependency and zero regression risk**.

Deliverables:
- New `CausalEventKind`s: `fiber_suspended`, `fiber_resumed`, `timer_scheduled`,
  `timer_fired` (+ `io_wait_started`, `io_completed` reserved), classified
  structural / finding-evidence / non-sampleable.
- Core suspension emission: around `AsyncBackend.scheduleTimer` / `advanceTime` /
  `pollWake`, emit the events with correct edges — `fiber_resumed.cause_event_id`
  → `timer_fired`; `timer_fired` ↔ `timer_scheduled` by shared `schedule_id`;
  `timer_scheduled.cause_event_id` → `fiber_suspended`.
- A deterministic `delay`/suspension scenario that forks → suspends → fires timer
  (`advanceTo`) → resumes → joins, with a `CausalStore`, producing an artifact.
- Registered scenario so the agent loop can query it.

Acceptance criteria (agent-derived, AC-1…AC-7):
- **AC-1** `fiber_suspended` precedes `fiber_resumed` for the same `fiber_id`.
- **AC-2** `cause <resumed_id>` reaches a `timer_fired` via `cause_event_id`.
- **AC-3** `timer_fired` correlates to `timer_scheduled` by `schedule_id`, whose
  cause is the `fiber_suspended`.
- **AC-4** `fibers pending` is empty at run completion after the clock advances.
- **AC-5** suspend/resume events fall within the fiber's `scope_opened`/`closed`.
- **AC-6** virtual time only: `timer_fired.due_time_ms ≤ advanceTo(now)`, backend
  `duplicate_suspend_count == 0`, no real sleeping.
- **AC-7** no regression: dogfood scenario's event kinds/counts unchanged
  (`causal-compare`).

Gate: `zig build test-raw` + `examples` + `release-gate` green; all 7 ACs pass
via agents; `causal-compare` additive-only; `causal-advice` clean.

### Stage 1 — zio timer (real suspension)

`packages/zigeffect-zio` with `ZioAsyncBackendState` implementing
`suspend_runtime` / `wake` / `schedule_timer`. Program enters via `zio.run`; a
delayed fiber yields the OS thread and resumes on a real zio timer. Reuses the
Stage 0 causal-event emission unchanged. Proof: deterministic-scenario
causal-trace equivalence (exact, single active fiber) between
`LocalAsyncBackendState` and `ZioAsyncBackendState`.

Gate: core still green without zio; `zigeffect-zio:test` green; agent equivalence
check passes; real suspension demonstrated (no busy-wait, thread actually yields).

### Stage 2 — zio IO wait

`register_io_wait` / `complete_io` over a real socket read via `std.Io.Reader`.
A fiber blocked on a socket wakes on data; emits `io_wait_started` /
`io_completed` / `fiber_resumed` with the same cause-edge shape as the timer.

Gate: socket round-trip test under zio; agent verifies the IO cause edges;
equivalence on the deterministic IO model.

### Stage 3 — coordination + cancellation

Back `Deferred` / `Queue` / `Semaphore` with zio primitives (channels/semaphore
or event-loop park) so a fiber parks on `await`/`take`/`acquire` and resumes on
signal. Map scoped-fiber cancellation → `zio.Group.cancel`: a parent scope close
cancels a parked child. First genuinely interleaved scenario; verified by
**structural-invariant** comparison (partial order), not exact trace.

Gate: interleaved scenario passes structural-invariant equivalence; scope-close
cancels a parked child (causal graph shows `fiber_interrupted.cause_event_id` →
`scope_closed`); no leaks under `causal-advice`.

### Stage 4 — hardening + integration

Error/defect propagation across the yield boundary; allocator/lifetime ownership
of parked fibers; leak checks; the `zigeffect-zio` conformance gate; docs. App
integration stays artifact-based (the Cloudflare Worker request path cannot run
Zig — apps emit `zigeffect.causal.v1` artifacts via `CausalAppTrace` and open
them in the same workbench). Optional: a real loopback TCP cluster transport
(roadmap pillar 11) as a separate follow-on.

Gate: full release-gate green; conformance suite green; workbench renders a real
zio-backed run; honest "production-ready for single-threaded async" statement.

## Beyond (separate roadmap items, not in this delivery)

Multi-thread parallelism (one runtime currently owns one `CausalStore`),
durable workflows/clustering over real transports, live export adapters (OTLP /
NenDB), and production-hardening contracts — each returns only as a `src/`
capability with tests and an approved `tool-roadmap.md` entry.

## Honest status

- **Stage 0**: delivered + verified this iteration (in-core, zio-free).
- **Stages 1-4**: scoped and executable; require building against real zio in the
  dev environment (network fetch + OS event loop), which is iterative systems
  work, not a single-pass delivery. The package skeleton + vtable mapping are
  scaffolded so the work starts from a compiling boundary.
- The agent causal-verification loop is operational and is the gate for every
  stage.
