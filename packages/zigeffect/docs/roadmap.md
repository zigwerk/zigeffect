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
executor. In the current checker, "structurally-equivalent" means the same event
kinds, cause and parent edge kinds, id-insensitive same-scope/resource/fiber
ownership facts, finding-evidence owner states, and per-fiber terminal lifecycle
states, independent of concrete event ids and scheduler ordering. It is still a
semantic fact comparison, not exact event-id graph isomorphism.

## Status at a glance

| # | Pillar | Status | Where |
|---|--------|--------|-------|
| 1 | Effect core + typed errors | **done** | `src/effect/effect.zig`, `src/core/result.zig`, `src/core/context.zig` |
| 2 | DI layers + layer graph | **done** | `src/layer/layer.zig`, `src/layer/graph.zig`, `src/dependency/*` |
| 3 | Scoped resources + finalizers | **done** | `src/core/scope.zig`, `src/effect/resource.zig` |
| 4 | Fiber runtime + concurrency | **real backends** (deterministic, zio coroutines, OS-thread pool) | `src/runtime/fiber.zig`, `src/runtime/thread_pool_executor.zig`, `src/effect/ergonomics.zig`, `packages/zigeffect-zio` |
| 5 | Causal store + event graph + queries | **done** | `src/services/causal.zig` |
| 6 | Causal dev loop (compare/advice/verdict) | **done** | `tools/causal_dev_loop`, `causal_compare`, `causal_advice`, `causal_verdict` |
| 7 | Guarded remediation + agent interventions | **closed loop, gate-off by default** | `src/services/policy_engine.zig`, `src/services/agent_intervention.zig`, `tools/causal_*remediation*` |
| 8 | App-facing causal trace | **done** | `src/services/causal_app_runtime.zig` |
| 9 | Visual workbench (SolidJS / zig-webui) | **live-attach** (static + streaming via collector) | `workbench/`, `workbench/src/collector/` |
| 10 | Export adapters (JSONL/DOT/OTel/OTLP/graph-history/NenDB) | **OTLP + collector live end-to-end** | `src/services/causal_*_backend.zig`, `causal_otlp_json.zig` |
| 11 | Durable workflows + clustering | **scheduler runs on zio; loopback + remote socket wrappers cross the transport boundary** | `src/workflow/*`, `src/cluster/*` |
| 12 | Agent-operable runtime layer | **bounded interventions, counterfactuals, invariants, evals** | `src/services/agent_intervention.zig`, `counterfactual.zig`, `causal_invariant.zig`, `agent_eval.zig` |

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
  program yields a structurally-equivalent causal trace in the stronger semantic
  fact sense defined above.
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
- A bounded **agent intervention protocol**: `AgentInterventionPolicy` is
  default-deny/default-record-only, records every request and decision, and only
  emits `remediation_applied` plus an effect event when apply is enabled and the
  action kind is explicitly approved.
- A deterministic **counterfactual trace fork**: `runCounterfactual` replays a
  baseline causal trace into before/after stores, applies an approved
  intervention to the after store, and reports finding deltas plus structural
  equivalence.
- A reusable **causal invariant builder** over graph facts: resource
  acquisition/finalization, suspended-fiber resolution, pending fibers after
  scope close, and assertion failures.
- A first **agent eval harness**: `runAgentEval` scores an intervention by graph
  improvement plus invariant cleanliness rather than prose plausibility.
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
- **One real loopback socket transport.** `LoopbackSocketClusterTransport` sends
  the existing `ZIGFX/1` cluster frame over localhost TCP, accepts it on a server
  thread, routes through the same message-storage handler, and parses the response
  frame back through the public transport vtable.
- **A hardened remote socket wrapper.** `RemoteSocketClusterTransport` keeps the
  same socket frame path but adds endpoint validation, auth preflight before
  durable submission, nonzero pool validation, reconnect attempts, lifecycle
  metrics, and redacted failure reports.

## Boundary decisions (intentional non-goals, for now)

- **The core stays zio-free and deterministic-by-default.** Real suspension/IO/
  threads live in `packages/zigeffect-zio` and the `ThreadPoolExecutor`; the core
  `packages/zigeffect` still passes all tests without them, so it remains testable
  without threads, IO, or wall-clock time. `LocalAsyncBackendState` is the
  deterministic reference every real executor is checked against.
- **Thread-pool `interrupt` is cooperative.** OS threads can't be async-preempted,
  so a thread-pool race/both returns the correct result but does not short-circuit
  a loser's work (zio's coroutine cancel does). Documented in the executor.
- **Remote socket transport is still not a deployment platform.**
  `LoopbackSocketClusterTransport` crosses localhost TCP and
  `RemoteSocketClusterTransport` adds the operational envelope for auth,
  retries, and metrics, but long-lived multi-node deployment, TLS, load
  balancing, and full connection pooling remain out of scope.
- **The remediation loop's apply gate is OFF by default** and never mutates source
  unless a human-approved policy turns it on; structural verify is mandatory.
- **Agent interventions are record-only by default.** The runtime records what an
  agent asked for and what the policy decided; it does not apply an effect unless
  the master apply gate and kind policy both allow it.
- `requires` stays Zig-native metadata + validation; `Exit` stays a lightweight
  by-value result.

## The frontier now

The original "single biggest gap" — real async/concurrency under the causal graph
— is **substantially closed**: the graph now explains real zio-coroutine and
real-OS-thread execution, not only a deterministic simulation. The next frontier
is the agent-operable runtime becoming production-operable:

1. **Deployed remote cluster networking.** The socket boundary now has loopback
   and remote-wrapper coverage. The next distributed step is real multi-node
   deployment semantics: TLS/auth rotation, timeout/backpressure policy,
   connection-pool behavior, and causal lineage across runner boundaries.
2. **Bidirectional live debugging.** The agent intervention protocol exists in
   the engine; the workbench live path is still observe-only. The next step is an
   explicit, policy-gated browser/collector command path that records every
   intervention as causal facts.
3. **Causal graph diffs and richer evals.** Counterfactuals and `runAgentEval`
   now produce coarse finding deltas. Next, add semantic graph diffs that explain
   exactly which lineage, resource, fiber, or finding facts changed.
4. **Durable retention + operational hardening** (deployment, access control,
   alerting) — deferred until the above, and only ever as `src/` capabilities with
   tests and an approved [tool-roadmap.md](tool-roadmap.md) entry.

## Hardening milestone roadmap

This is the next work sequence. It deliberately hardens the proof surface before
adding broad product surface area.

### M0 — Status truth and roadmap hygiene

**Goal:** keep the repository's claims internally consistent while the project
moves quickly.

**Work:**
- Fix stale comments/docs as they are found, especially statements that say a
  shipped collector, backend method, or scheduler path is "not yet built".
- Keep `roadmap.md`, the future-agent briefing, package READMEs, and workbench
  comments aligned on the current frontier.
- Extend the honesty gate only when it prevents a real failure mode; avoid new
  report-only tools.

**Acceptance:**
- Targeted `rg` sweeps show no current docs contradict the live collector,
  scheduler-on-zio, structural-equivalence definition, or tool hygiene policy.
- `tools/check_tool_hygiene.sh` still passes.

### M1 — Stronger structural equivalence

**Status:** initial hardening delivered on 2026-06-24. The comparator now rejects
parent-lineage, resource-pairing, fiber-scope ownership, and finding-owner false
positives while preserving the existing executor-equivalence suite.

**Goal:** make the three-executor invariant harder to fake by comparing more of
the causal graph shape.

**Work:**
- Add regression traces that the current comparator falsely accepts.
- Expand `causalStructurallyEquivalent` beyond event-kind, cause-kind, and
  terminal-fiber facts to include parent/lineage shape, scope/resource lifecycle
  pairings, fiber ownership, interruption/finalizer facts, and important
  finding-evidence ownership.
- Keep ids and scheduler order abstract; compare semantic structure, not exact
  event numbers.

**Acceptance:**
- Tests reject mismatched parent trees with the same event kinds.
- Tests reject resources finalized under the wrong scope/resource identity.
- Tests reject fiber lifecycle events that have the same terminal state but
  belong to different scope/parent structure.
- Tests reject missing or reassigned finding-evidence ownership where the event
  taxonomy says the event matters diagnostically.
- Existing deterministic/zio/thread-pool structural-equivalence tests stay green.

### M2 — Live debugging browser proof

**Status:** browser proof delivered on 2026-06-24 at
`docs/superpowers/specs/2026-06-24-zigeffect-live-debugging-browser-proof.md`.
Automated collector-to-WebSocket-client coverage exists, and the proof doc now
includes a captured workbench screenshot from the live collector stream.

**Goal:** prove the browser debugging path, not only the collector contract.

**Work:**
- Exercise engine NDJSON -> Bun collector -> WebSocket -> Solid workbench render.
- Prefer an automated Bun/Playwright DOM test; if browser automation is blocked,
  add a repeatable visual proof doc with exact commands and screenshots.
- Fix live-attach docs/comments while touching the path.

**Acceptance:**
- A real live frame appears in the workbench timeline/graph DOM from a collector
  WebSocket, not from a static `?sample=` fixture.
- The verification artifact records exact commands, ports, and expected visible
  UI state.

### M3 — One real loopback cluster transport

**Status:** initial core transport delivered on 2026-06-24 via
`LoopbackSocketClusterTransport`; it crosses localhost TCP and preserves envelope
fields through the existing `ClusterTransport` vtable. A regression test compares
an in-process transport trace to the loopback socket trace with
`causalStructurallyEquivalent`.

**Goal:** cross the distributed boundary once without broadening into a full
deployment platform.

**Work:**
- Put a loopback TCP/socket transport behind the existing `ClusterTransport`
  shape, preferably in the zio adapter where real socket IO already lives.
- Compare the same cluster scenario through in-memory and loopback transports.
- Keep serialization, backpressure, timeout, and shutdown semantics explicit.

**Acceptance:**
- A loopback transport conformance test sends and receives real socket bytes.
- The in-memory and loopback runs produce structurally-equivalent causal traces.
- Transport errors redact endpoint credentials and produce actionable causal
  events.

### M4 — Secret and trace redaction hardening

**Status:** delivered on 2026-06-24. Sentinel coverage now spans stored causal
events, reports, JSON, DOT, JSONL, NDJSON live-feed bytes, OTel/OTLP payloads,
transport auth metadata, and workbench `LiveFrame` labels.

**Goal:** prevent real transport/storage work from leaking credentials into
causal artifacts, workbench payloads, or exported traces.

**Work:**
- Add sentinel-secret tests that inject fake API keys, bearer tokens, cookies,
  database URLs, and passwords into event labels/details and transport/storage
  metadata.
- Assert JSONL, DOT/tooltip text, OTLP/JSON, live frames, CI reports, and
  workbench-facing artifacts do not contain the sentinel strings.
- Redact at the causal boundary rather than only in one exporter.

**Acceptance:**
- A single sentinel corpus proves known secret shapes do not escape any supported
  causal export path.
- Regression tests fail if a new exporter bypasses the redaction boundary.

### M5 — Broader agent honesty gate

**Status:** delivered on 2026-06-24. `check_tool_hygiene.sh` now rejects known
stale current-status claims, caps report-named tool proliferation, and carries
regression fixtures for stale docs and repeated report-tool naming.

**Goal:** catch motion-shaped work before it reaches the repo.

**Work:**
- Extend the existing hygiene checker with narrow checks for stale status claims,
  generated-report proliferation, and forbidden "future/not yet" contradictions
  in current docs.
- Keep the gate small, source-backed, and cheap to run in CI/pre-commit.
- Prefer editing `src/` with tests over adding tools; any new tool must satisfy
  the runtime-import rule.

**Acceptance:**
- CI fails on a current-status doc that claims a shipped capability is missing.
- CI fails on repeated report-tool naming patterns before line-count limits are
  reached.
- The gate has regression tests and does not require network access.

### M6 — Agent intervention protocol

**Status:** delivered on 2026-06-24 via
`src/services/agent_intervention.zig`.

**Goal:** let an agent request bounded runtime actions without letting it claim
or perform mutations that policy did not approve.

**Work:**
- Add a fixed intervention action set: interrupt fiber, fire timer, pause runner,
  replace provider, replay scenario, and inject failure.
- Record `remediation_requested` and `remediation_decided` for every request.
- Keep the default policy record-only; emit `remediation_applied` plus an
  action-specific effect event only when apply is enabled and the kind policy is
  auto-approved.

**Acceptance:**
- Default policy records request/decision but no apply/effect event.
- Approved `interrupt_fiber` records request, decision, apply, and
  `fiber_interrupted`.

### M7 — Counterfactual re-executor

**Status:** delivered on 2026-06-24 via `src/services/counterfactual.zig`.

**Goal:** let an agent test a proposed intervention against a deterministic
causal trace fork before treating it as improvement.

**Work:**
- Replay a baseline trace into before/after `CausalStore`s.
- Apply an approved intervention only to the after store.
- Return finding counts, finding delta, structural equivalence, and an
  `improved` bit.

**Acceptance:**
- A suspended-fiber baseline plus an approved interrupt reduces findings and
  reports `improved = true`.

### M8 — Runtime invariant DSL

**Status:** delivered on 2026-06-24 via `src/services/causal_invariant.zig`.

**Goal:** give agents reusable graph checks without introducing a separate
invariant language.

**Work:**
- Add a Zig builder for resource finalization, suspended-fiber resolution,
  pending fibers after scope close, and assertion failures.
- Return structured `CausalInvariantViolation` records.

**Acceptance:**
- The builder detects unfinalized resources, unresolved suspended fibers, and
  pending fibers at scope close.
- The builder passes when resource and fiber lifecycles close.

### M9 — Remote socket transport hardening

**Status:** delivered on 2026-06-24 via `RemoteSocketClusterTransport`.

**Goal:** close more of the real transport gap without jumping to a distributed
platform.

**Work:**
- Add a remote-socket wrapper behind the existing `ClusterTransport` shape.
- Validate endpoint, auth, limits, pool size, and reconnect attempts before
  durable submission.
- Record metrics and redacted failures through the production-socket transport
  kind.

**Acceptance:**
- Wrong auth is rejected before durable submission.
- Matching auth sends over the socket path and updates metrics.

### M10 — Agent eval harness

**Status:** delivered on 2026-06-24 via `src/services/agent_eval.zig`.

**Goal:** score debugging agents by graph improvement and invariant cleanliness.

**Work:**
- Compose the counterfactual re-executor with the invariant builder.
- Pass only when the intervention is applied, expected improvement holds, and
  no invariant violations remain.

**Acceptance:**
- Approved interrupt over a suspended-fiber trace passes.
- Denied policy does not pass.

## Delivered since 2026-06-20

The forward sequence from the prior roadmap is largely done. Tracked in
`docs/superpowers/plans/`:

- zio backend built; `Queue`/`Semaphore`/`Deferred` suspend/resume on it; engine
  fibers run as zio coroutines (D1/D2).
- OTLP/JSON serialization + the live-attach collector make the causal graph leave
  the in-memory world against a real consumer.
- The workbench has a live-attach path (not just `?sample=` fixtures), with a
  committed browser screenshot proof of a real collector stream.
- Six final-completion tracks (race+both, thread-pool executor, heterogeneous STM,
  FiberRef auto-propagation, the zio vtable fill, workbench live-attach) plus the
  collector and scheduler-on-zio, each adversarially reviewed and hardened.
- One loopback cluster transport crosses localhost TCP, and the remote socket
  wrapper adds auth preflight, reconnect attempts, metrics, and redacted failure
  handling.
- The M6-M10 agentic engine layer now covers bounded interventions,
  counterfactual trace forks, reusable invariants, and graph-delta eval scoring.

## June 2026 cleanup note

An autonomous self-improvement loop over-generated ~120 record-only governance
tools (counter-tier `*_level_*` clones and `*_evaluation_report_evaluation_report_*`
recursion chains), plus ~340 dedicated docs/plans. All were removed; the engine
`src/` was untouched and verified green. Guardrails now prevent recurrence:
`tools/check_tool_hygiene.sh` (CI + pre-commit hook), the Tool Hygiene Policy in
`AGENTS.md`/`CLAUDE.md`, and the approval gate in [tool-roadmap.md](tool-roadmap.md).
The checker now also rejects new `.zig` tools that do not import or explicitly
exercise runtime symbols, unless a human adds a narrow no-runtime-import
justification. It also rejects known stale current-status claims and caps
report-named tool proliferation so report generators do not become their own
growth path.
