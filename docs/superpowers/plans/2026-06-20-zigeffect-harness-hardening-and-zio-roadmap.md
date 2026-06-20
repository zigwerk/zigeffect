# zigeffect Harness Hardening → zio Async — Master Roadmap

Date: 2026-06-20
Status: active
Predecessors:
- [zio async delivery roadmap](./2026-06-20-zigeffect-zio-async-delivery-roadmap.md)
- [zio backend design](../specs/2026-06-20-zigeffect-zio-backend-design.md)

Battle-testing the agent dogfood + causal reporting framework on Stage 0
surfaced concrete gaps. This roadmap hardens that framework **first** (so the
loop we rely on for the zio work is trustworthy and ergonomic), then returns to
the zio async backend. Every item is verified by the same loop it improves:
TDD test → causal artifact → AI-agent causal verification → `causal-compare` →
`causal-advice` clean.

Principles carried forward: core stays zio-free; `LocalAsyncBackendState` is the
deterministic reference; causal-verified not log-scraped; no new record-only
tools (extend existing ones; new `causal_*` tool needs a `tool-roadmap.md` entry).

---

## Milestone H — Harness Hardening

### H1 — Query results to stdout *(reframed → folded into H6)*
Investigated and **dropped as specified.** Finding from battle-testing the
harness: under `zig build <tool>`, the Run step **captures/suppresses child
stdout** (stderr is the forwarded channel — which is why the whole codebase uses
`std.debug.print`), and Run steps **cache**, so re-running the same query yields
*no* output at all. Moving query data to stdout makes it vanish for the exact
invocation agents use. The real ergonomic fix is therefore not the stream but a
clean machine-readable surface: **the structured `--agent` JSON mode (H6)**, plus
documenting the run-cache gotcha (agents should vary args or read the artifact
JSON directly, and capture `2>&1`).
- **Outcome:** reverted; intent merged into H6.

### H2 — Net-state `fibers` query
Add an engine `fiberStates()` (latest lifecycle status per `fiber_id`, with a
`resolved` flag) and a `fibers_state` query verb. Lets an agent answer "anything
still parked?" in one call instead of reasoning over immutable events.
- **Gate:** on the delay artifact, `fibers_state` reports fiber 1 as resolved
  (terminal `fiber_joined`); a hang fixture reports it unresolved. Agent-verified.

### H3 — Single source of truth for event kinds
Derive the tools' recognized-kind set from the engine `CausalEventKind` enum via
`@typeInfo`/`@tagName` (delete the hand-maintained `known_causal_event_kinds`
list in `causal_artifact.zig`). Kinds can no longer drift from the engine.
- **Gate:** adding an enum member needs no tool edit; taxonomy warning never
  fires for an engine-known kind; tests green.

### H4 — Hang detector: `fiber_suspended_without_resume`
Add the finding kind + a `findings()` rule (a `fiber_suspended` with no later
`fiber_resumed`/`fiber_interrupted` for the same `fiber_id`) and an
`inspect-suspended-fiber` advice action. This is the new failure mode the
suspension capability introduces.
- **Gate:** delay artifact stays finding-clean; a suspend-without-resume fixture
  produces exactly one finding + advice action. Agent-verified.

### H5 — Structural-invariant comparator  *(blocks Stage 1)*
Add a `--structural` mode to `causal-compare`: compare two artifacts on
structural invariants (set of fibers + terminal status; cause-edge relationships
by kind; scope nesting; finding kinds) ignoring event ids/ordering. Required to
verify the zio backend, whose real scheduling makes exact event order vary.
- **Gate:** deterministic delay artifact vs an id-shifted/reordered copy compares
  EQUAL structurally; a genuinely different trace compares NOT-EQUAL. Agent-verified.

### H6 — Steer the agent loop to `--agent` + add suspension facts
The structured `--agent` JSON mode already exists; make the verification loop
prefer it, and add per-fiber net state + suspend↔resume pairs to its bundle so
agents get the facts in one structured call (fewer slow `zig build` invocations).
- **Gate:** `--agent summarize_run` includes fiber net-state + suspension pairs;
  agent loop uses it.

### H7 — Coverage-truth + real cause edges in the runtime
(a) A gate asserting a scenario tagged `coverage: <domain>` actually emits that
domain's event kinds (e.g. `coverage: fiber` ⇒ `fiber_*` events present).
(b) Populate real `cause_event_id` edges in `fiber.zig`/`scope.zig`
instrumentation (today only `parent_id` is set), and make `causal-scoped-fiber`
emit a true fiber lifecycle.
- **Gate:** coverage-truth gate fails on a stub scenario; `causal-scoped-fiber`
  emits `fiber_forked/started/.../interrupted` with a scope-close cause edge.

**Milestone H done when:** H1–H6 land green and agent-verified (H7 may trail as
its own follow-up; it is larger and touches live runtime instrumentation).

---

## Milestone Z — zio Async Backend (resumes after H)

zio v0.14.0 resolves and is Zig-0.16 compatible (dep hash-pinned in
`packages/zigeffect-zio`). The Stage 0 suspension events + scenario + agent
harness + the H5 structural comparator gate this work.

### Z1 — zio timer primitive (real suspension) — DONE
Implemented and verified against real zio v0.14.0. `recordZioDelayScenario`
([packages/zigeffect-zio/src/zio_backend.zig](../../../packages/zigeffect-zio/src/zio_backend.zig))
runs a coroutine that calls `zio.sleep(.fromMilliseconds(n))` — which genuinely
parks the fiber on the zio event loop (io_uring/epoll/kqueue) and resumes it when
the timer fires — and emits the suspend/timer/resume causal trace. The adapter
test asserts that trace is **structurally equal** to the deterministic
`fx.recordDelaySuspensionScenario` (identical event-kind multiset incl. exactly
one fiber_suspended/timer_fired/fiber_resumed/fiber_joined).
- **Outcome:** `zigeffect-zio` build+test green against real zio; the zio
  dependency fetches and links (lazy, hash-pinned). Real suspension proven to
  produce an equivalent causal graph — the Stage-1 milestone.
- **Note:** Z1 uses the run-under-zio emission model (sleep wraps the causal
  events). Wiring the full `AsyncBackend` *vtable* methods to zio is a refinement
  for Z2/Z3 where the poll-based vtable meets coordination park/unpark.

### Verification lesson (recorded)
`zig build test-raw` does NOT run the tools' inline tests; `zig build examples`
and `release-gate` do. Always run both. The agent verification loop caught an H5
unit-test crash (missing `Event` field defaults) that `test-raw` missed — exactly
the kind of gap the dogfood loop exists to catch.

### Z2 — zio IO wait
`register_io_wait` / `complete_io` over a real socket read via `std.Io`. Emits
`io_wait_started`/`io_completed`/`fiber_resumed`.
- **Gate:** socket round-trip wakes the fiber; agent verifies the IO cause edges;
  structural equivalence on the IO model.

### Z3 — structured cancellation — DONE (cancellation half)
`recordZioCancellationScenario` ([zio_backend.zig](../../../packages/zigeffect-zio/src/zio_backend.zig)):
a child spawned in a `zio.Group` suspends on a real `zio.sleep`; the parent closes
the scope and `group.cancel()`s, genuinely interrupting the child. The trace
records `fiber_interrupted` caused by `scope_closed` — the structured-concurrency
invariant, against real zio cancellation; the hang detector treats interrupt as
resolution. `zigeffect-zio` build+test green.
- **Remaining (Z3b):** back `Deferred`/`Queue`/`Semaphore` park/unpark with zio
  `Channel`/`Future`/`Semaphore`, and a genuinely *interleaved* two-coroutine
  scenario verified by H5 structural invariants.

## Remaining work (precise, ordered)

1. **Z2 — real socket IO wait.** A coroutine blocks on a real loopback
   `zio.net.Stream.read`; emit `io_wait_started`/`io_completed`/`fiber_resumed`;
   structural-equivalence vs a deterministic IO model. (zio.net API: `IpAddress.
   listen/connect`, `Server.accept`, `Stream.read/write`.)
2. **Z3b — coordination park/unpark + interleaving** (above).
3. **H7a — real `cause_event_id` edges in the live runtime.** Today `fiber.zig`/
   `scope.zig` set `parent_id` but not cause edges, so *real* programs (not just
   the demo scenarios) lack causal cause-links. Wire `fiber_interrupted.cause` →
   `scope_closed` in `forkInScope`'s lease finalizer, and resume/timer causes
   where applicable. Additive; guard the existing fiber/scope causal tests.
4. **H7b — coverage-truth gate.** Assert a scenario tagged `coverage: <domain>`
   actually emits that domain's event kinds (catches stub scenarios like the old
   `causal-scoped-fiber`). Re-wire `causal-scoped-fiber` to emit a real fiber
   lifecycle.
5. **Deep integration (the big one) — engine fibers run AS zio coroutines.**
   Wire the `AsyncBackend` vtable + `FiberRuntime` so `Effect`/`Fiber` execution
   actually suspends via zio (not the hand-emitted demo scenarios). This is where
   the poll-based vtable meets zio's blocking-coroutine model; likely a
   `blocking_sleep`/host-mode coordinator method. Multi-session.
6. **H6b — `--agent` bundle enrichment** (per-fiber net state + suspend/resume
   pairs in the structured JSON mode).
7. **Z4 — hardening + workbench.** Defect propagation across the yield boundary,
   allocator/lifetime of parked fibers, conformance gate, workbench renders a
   real zio-backed run.

### Z4 — hardening + integration
Error/defect propagation across the yield boundary; allocator/lifetime of parked
fibers; leak checks; the `zigeffect-zio` conformance gate; workbench renders a
real zio-backed run. App integration stays artifact-based (Workers can't run Zig).
- **Gate:** full release-gate + conformance green; honest "single-threaded async
  works" statement. Multi-thread parallelism and durable/cluster transports are
  separate, later roadmap items.

---

## Execution order

H1 → H3 → H4 → H2 → H5 → H6 → (H7) → Z1 → Z2 → Z3 → Z4.

H1/H3 are quick footgun/drift fixes; H4/H2 harden the suspension feature and the
agent ergonomics; H5 is the Stage-1 gate. Then the zio stages build on a
trustworthy, suspension-aware, structurally-comparable harness.
