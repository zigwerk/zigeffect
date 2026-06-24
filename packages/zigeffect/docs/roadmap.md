# zigeffect Roadmap

Date: 2026-06-24

`zigeffect` is a Zig-native Effect-inspired engine whose primary debugging
interface is a deterministic, queryable **causal event graph** that LLM agents
query structurally (cause, lineage, resources, fibers, requirements, retries,
findings) instead of parsing logs. The goal is not API cloning; it is a
production-grade Zig shape for direct-style programs, typed errors, service
requirements, scoped resources, dependency layers, an agent-observable causal
runtime, and real async execution.

The deterministic, semantic-first philosophy is deliberate: the **core** must be
testable without threads, IO, or wall-clock time. Real async/concurrent execution
lives in backend adapters (and now real OS-thread / zio-coroutine executors) that
obey the same Scope / Exit / Cause / event contracts — proven by the invariant
that the same program produces a structurally-equivalent causal trace under every
executor.

## Status at a glance

| # | Pillar | Status | Where |
|---|--------|--------|-------|
| 1 | Effect core + typed errors | **done** | `src/effect/effect.zig`, `src/core/result.zig`, `src/core/context.zig` |
| 2 | DI layers + layer graph | **done** | `src/layer/layer.zig`, `src/layer/graph.zig`, `src/dependency/*` |
| 3 | Scoped resources + finalizers | **done** | `src/core/scope.zig`, `src/effect/resource.zig` |
| 4 | Fiber runtime + concurrency | **real backends** (deterministic, zio coroutines, OS-thread pool) | `src/runtime/fiber.zig`, `src/runtime/thread_pool_executor.zig`, `src/effect/ergonomics.zig`, `packages/zigeffect-zio` |
| 5 | Causal store + event graph + queries | **done** | `src/services/causal.zig` |
| 6 | Causal dev loop (compare/advice/verdict) | **done** | `tools/causal_dev_loop`, `causal_compare`, `causal_advice`, `causal_verdict` |
| 7 | Guarded remediation chain | **closed loop, gate-off by default** | `src/services/policy_engine.zig`, `tools/causal_*remediation*` |
| 8 | App-facing causal trace | **done** | `src/services/causal_app_runtime.zig` |
| 9 | Visual workbench (SolidJS / zig-webui) | **live-attach** (static + streaming via collector) | `workbench/`, `workbench/src/collector/` |
| 10 | Export adapters (JSONL/DOT/OTel/OTLP/graph-history/NenDB) | **OTLP + collector live end-to-end** | `src/services/causal_*_backend.zig`, `causal_otlp_json.zig` |
| 11 | Durable workflows + clustering | **scheduler runs on zio; transports in-memory** | `src/workflow/*`, `src/cluster/*` |

## What is real today

- Direct-style effects with typed success/failure channels; `Exit`/`Cause`/`CauseTree`.
- Dependency injection gates, layer startup/teardown, heterogeneous graph startup
  with memoization, and readable dependency diagnostics.
- Deterministic scoped cleanup with reverse-order, exit-aware finalizers.
- **Structured concurrency on three executors, one abstraction.** `fork`/`join`/
  `interrupt`, `forEachPar`/`zipPar`, and the race family — `raceFirst`/`raceAll`/
  `race` (prefer-success) / `both` (fail-fast) — run on the deterministic backend,
  on **real zio coroutines**, OR on a **real OS-thread pool** (`ThreadPoolExecutor`)
  via the `FiberExecutor` vtable. The D2 invariant holds across all three: the same
  program yields a structurally-equivalent causal trace.
- **Thread-safe state primitives.** `CausalStore`/`Ref`/`Hub` are lifted to
  thread-safe with a `SpinLock`, proven by an 8-thread × 2000-op stress test +
  mutation testing. STM (`TRef`, `Stm.atomically`) with optimistic conflict-retry,
  including **heterogeneous transactions** (`atomicallyMixed` over `TRef`s of
  different value types). Fiber-local `FiberRef` with **auto-propagation** across
  `fork` (inline `Context` slots for `@sizeOf(T) <= 8`).
- A bounded, opt-in **causal event model** (`CausalStore`) with structural /
  finding-evidence / sampleable taxonomy, secret redaction, retention/sampling/
  truncation disclosure, and the structural queries agents rely on.
- The causal **dev loop** and the **closed remediation loop**: `findings()` →
  remediation → `PolicyEngine.decide()` (gate OFF by default) → `ApplyBoundary`
  (action + structural verify) → `applied` earned only when approve AND verify,
  with per-kind executors (retry/interrupt/replace-provider/replay).
- App-facing causal traces (`CausalAppTrace`) emitting `zigeffect.causal.v1` from
  Worker-shaped request/job paths.
- Export adapters as sinks (JSONL, DOT, OTel-shaped, **OTLP/JSON**, graph-history,
  NenDB write-contract, async stream) with per-adapter conformance gates.
- **The real zio backend** (`packages/zigeffect-zio`): `blockingSleep` parks a
  coroutine on the event loop; the full `AsyncBackend` vtable is implemented
  (suspend/wake/schedule-timer/interrupt/register-io/complete-io/poll-wake) as a
  registration + wake-queue with real zio timer coroutines; real socket IO via
  `zio.net`. Engine fibers run as interleaving zio coroutines.
- **The workflow scheduler runs on the zio backend.** A `real_clock` capability +
  `WorkflowScheduler.pumpAsyncUntilIdle` reconcile the virtual-clock PULL model
  with zio's real-clock PUSH model (yield the event loop for real timers to fire).
- **Live-attach end-to-end.** `CausalNdjsonTap` streams recorded events as NDJSON;
  a Bun WebSocket collector (`workbench/src/collector/`) maps them to `LiveFrame`s
  and fans out one-per-message; the SolidJS workbench consumes them via
  `?live=ws://…/live`. Proven with real engine bytes through to the client.

## Boundary decisions (intentional non-goals, for now)

- **The core stays zio-free and deterministic-by-default.** Real suspension/IO/
  threads live in `packages/zigeffect-zio` and the `ThreadPoolExecutor`; the core
  `packages/zigeffect` still passes all tests without them, so it remains testable
  without threads, IO, or wall-clock time. `LocalAsyncBackendState` is the
  deterministic reference every real executor is checked against.
- **Thread-pool `interrupt` is cooperative.** OS threads can't be async-preempted,
  so a thread-pool race/both returns the correct result but does not short-circuit
  a loser's work (zio's coroutine cancel does). Documented in the executor.
- **Clustering transports are in-memory.** `production_http`/`production_socket`
  format bytes and route through an in-process transport; the *workflow scheduler*
  now runs on zio, but the cluster *transport* is not yet on real sockets.
- **The remediation loop's apply gate is OFF by default** and never mutates source
  unless a human-approved policy turns it on; structural verify is mandatory.
- `requires` stays Zig-native metadata + validation; `Exit` stays a lightweight
  by-value result.

## The frontier now

The original "single biggest gap" — real async/concurrency under the causal graph
— is **substantially closed**: the graph now explains real zio-coroutine and
real-OS-thread execution, not only a deterministic simulation. The honest
remaining frontier is:

1. **Visual confirmation of the live stream.** The data path
   (engine → NDJSON → collector → frontend contract) is automated end-to-end; a
   human still needs to watch the workbench render a live run in a browser.
2. **The full cluster transport on real sockets.** The scheduler runs on zio;
   the `ClusterTransport` vtable still routes in-process. Crossing it once on a
   loopback TCP socket (zio.net is proven) is the next distributed step.
3. **Durable retention + operational hardening** (deployment, access control,
   alerting) — deferred until the above, and only ever as `src/` capabilities with
   tests and an approved [tool-roadmap.md](tool-roadmap.md) entry.

## Delivered since 2026-06-20

The forward sequence from the prior roadmap is largely done. Tracked in
`docs/superpowers/plans/`:

- zio backend built; `Queue`/`Semaphore`/`Deferred` suspend/resume on it; engine
  fibers run as zio coroutines (D1/D2).
- OTLP/JSON serialization + the live-attach collector make the causal graph leave
  the in-memory world against a real consumer.
- The workbench has a live-attach path (not just `?sample=` fixtures).
- Six final-completion tracks (race+both, thread-pool executor, heterogeneous STM,
  FiberRef auto-propagation, the zio vtable fill, workbench live-attach) plus the
  collector and scheduler-on-zio, each adversarially reviewed and hardened.

Still open from that sequence: crossing the distributed boundary on a real socket
(item 5).

## June 2026 cleanup note

An autonomous self-improvement loop over-generated ~120 record-only governance
tools (counter-tier `*_level_*` clones and `*_evaluation_report_evaluation_report_*`
recursion chains), plus ~340 dedicated docs/plans. All were removed; the engine
`src/` was untouched and verified green. Guardrails now prevent recurrence:
`tools/check_tool_hygiene.sh` (CI + pre-commit hook), the Tool Hygiene Policy in
`AGENTS.md`/`CLAUDE.md`, and the approval gate in [tool-roadmap.md](tool-roadmap.md).
