# zigeffect Vision Completion Roadmap (2026-06-20)

A single executable map of EVERY gap surfaced in the 2026-06-20 vision-vs-reality
audit, plus the foundation it builds on. Each bullet from the audit is a
numbered milestone. Designed to be worked end-to-end without further human
intervention — the five open audit questions are resolved by the **Working
Defaults** below, and any future ambiguity defers to those defaults unless a
milestone explicitly says otherwise.

Companion docs: the audit synthesis is recorded in this turn's chat log;
the active hardening/zio roadmap (`2026-06-20-zigeffect-harness-hardening-and-zio-roadmap.md`)
and zio delivery roadmap (`2026-06-20-zigeffect-zio-async-delivery-roadmap.md`)
remain authoritative for their narrower scopes — this doc super-sets them.

---

## Working Defaults (the five open audit questions, resolved)

| # | Question | Default | Reason |
|---|----------|---------|--------|
| 1 | Does `applied=true` ever happen inside the runtime? | **NO for v1.** Build the executable remediation machinery (policy engine + `FiberExecutor.interrupt` + scenario replay) but keep the apply boundary OFF by default. Operators explicitly enable it per remediation kind. | Safety > novelty. The machinery is the gate to the next evolution; flipping the switch is a separate, reviewable decision. |
| 2 | Effect-parity breadth vs self-improvement depth — which leads? | **Parallel sequencing, parity first.** Ship Effect ergonomics + state primitives before Phase 8 action execution. The self-improving loop dogfoods on real Effect programs; it can't dogfood on a runtime that lacks `Race`/`Queue`/`Hub` causal edges. | Parity is the multiplier. |
| 3 | First live export adapter — OTel/OTLP or NenDB? | **OTel/OTLP.** | Broader operator reach, lower coordination cost (no upstream pin). NenDB follows in Track 9. |
| 4 | Threading model commitment? | **Single-threaded v1, ENFORCED.** `ZioFiberExecutor` asserts the zio runtime is `.exact(1)`; `CausalStore.record` keeps its current model; new primitives (`Hub`, `Queue`, `Ref`) are designed so thread-safety can be added later without breaking the public API. | Lock the safe posture; design the door open. |
| 5 | `causal_app_*` chain convergence? | **Freeze the app_ chain.** No new `causal_app_*` tools until Track 11's convergence audit. | Stop the bleeding. |

---

## Track 0 — Foundation (BUILT)

For honest baseline; each item ships with a dogfood test. Do NOT re-do these.

- **T0.1** Causal taxonomy v1 — 50 event kinds + 10 finding kinds (`packages/zigeffect/src/services/causal.zig`).
- **T0.2** `SuspensionCoordinator.delay` — unified park/resume primitive shared across deterministic and zio backends (`src/runtime/suspension.zig`).
- **T0.3** `AsyncBackend` vtable + `blocking_sleep` — the engine-side seam for pluggable wait (`src/runtime/async_backend.zig`).
- **T0.4** Deterministic `LocalAsyncBackendState` — the reference implementation (virtual clock).
- **T0.5** Real zio adapter (`packages/zigeffect-zio`) — Z1 timer, Z2 socket IO, Z3 cancellation, Z3b channel coordination, D1 unified delay, D2 engine fibers as real coroutines.
- **T0.6** `FiberExecutor` vtable + `FiberRuntime.withExecutor` — productized executor (`fiber.zig:53-85`).
- **T0.7** `ZioFiberExecutor` — `Effect.fork` runs as a real zio coroutine; un-joined fibers drain at deinit.
- **T0.8** Cancellation correctness (H1) — cancelled-mid-`delay` records `fiber_interrupted`, never a fabricated resume.
- **T0.9** Overflow safety (H2) — saturating clock add in `localBlockingSleep`.
- **T0.10** Schedule-id global-uniqueness (L1) + advance/resume aliasing fix (L2).
- **T0.11** `causalStructurallyEquivalent` — first-class engine primitive (`src/services/causal_structural.zig`).
- **T0.12** Tool hygiene gate — `tools/check_tool_hygiene.sh` (CI + pre-commit) after the 120-tool runaway lesson.
- **T0.13** Release-gate umbrella + 6 milestone reports (M46–M51) reported done.
- **T0.14** Workbench (read-only) over saved causal artifacts.
- **T0.15** `causal-*` tool family (47 tools) — query/compare/advice/policy/snapshot/verdict.
- **T0.16** Local async IO + production shard leasing + HTTP/socket transports + local supervision trees (M46–M51 scope).

---

## Track 1 — Surface unification (immediate, hours–days)

The fast wins. They unlock everything else.

- **M1.1** `Runtime(Env).withExecutor` passthrough. Add `pub fn withExecutor(self, executor: FiberExecutor) Runtime(Env)` to `src/runtime/runtime.zig` forwarding to `FiberRuntime(Env).withExecutor`. **Why:** today D2 is invisible at the canonical entry point. **Test:** `test/runtime_executor_test.zig` — run a delay scenario via `Runtime(Env).run(...)` + `ZioFiberExecutor` and assert `causalStructurallyEquivalent` vs deterministic. Effort: hours.

- **M1.2** `SuspensionCoordinator.suspendOnDeferred` / `suspendOnQueue` / `suspendOnSignal`. Mirror `suspendOnTimer`; emit `fiber_suspended{kind=deferred|queue|signal}` and `fiber_resumed{cause_event_id=...}` from inside `Deferred.await` / `Queue.take` / `Semaphore.acquire`. **Why:** highest-frequency causal-graph blind spot — without this, real failure shapes (slow upstream, queue starvation, signal deadlock) are invisible to agents. **Test:** `test/suspension_coordination_test.zig` — assert the full multiset (suspended/resumed) on both deterministic and zio backends, structurally equal. Effort: days.

- **M1.3** First real self-improvement session, captured. Target H7a (`attachCausal` cause-edge propagation, `fiber.zig:195-212`). Baseline → fix → after → `causal-compare` / `causal-advice` / `causal-verdict`; preserve all artifacts under `examples/causal_first_self_improvement_session/`. Add a `release-gate` step that re-runs the comparison and asserts `verdict == improved`. **Why:** converts the headline claim from prose to a reproducible receipt. **Test:** the example dir + a release-gate verify step. Effort: hours–days.

---

## Track 2 — Causal-coverage breadth

Make the causal graph faithfully cover every transition. Highest ROI for the next-evolution loop.

- **M2.1** Deferred-suspension causal edges (covered by M1.2; placeholder for cross-link).
- **M2.2** Queue-suspension causal edges (covered by M1.2).
- **M2.3** Signal-suspension causal edges (covered by M1.2).
- **M2.4** Activity-suspension causal edges (`SuspensionKind.activity` declared but unwired).
- **M2.5** External-signal suspension causal edges (`SuspensionKind.external` declared but unwired).
- **M2.6** **H7a — live `cause_event_id` edges in arbitrary runtime transitions.** Today only the SuspensionCoordinator scenarios carry the edges; arbitrary live transitions propagate `parent_id` only. Refine `fiber_interrupted.cause_event_id` → `scope_closed` via `FinalizerExit`/scope back-reference plumbing. **Test:** new live-fork-then-cancel test asserts cause-edge to the scope's `scope_closed` event.
- **M2.7** Race-loser causal edges (`fiber_interrupted` with cause `race_winner`) — depends on Track 4.
- **M2.8** Hub-broadcast causal edges (per-subscriber resume cause = publish event) — depends on M5.4.
- **M2.9** Findings taxonomy registry — runtime extension mechanism so agents can register new finding kinds (audit lens 2 gap 19).
- **M2.10** Coverage-truth gate — `release-gate` step that asserts each declared `coverage: <domain>` scenario emits its domain's event kinds (H7b from the prior roadmap).

---

## Track 3 — Effect ergonomics M1

Forward-roadmap L112-175 surface, today missing from `src/zigeffect.zig:762-777`.

- **M3.1** `as(value)` — replace success with a constant.
- **M3.2** `replace(value)` — alias of M3.1; symmetric with EffectTS.
- **M3.3** `asVoid()` — discard success.
- **M3.4** `andThen(fn)` — sequential bind alias.
- **M3.5** `zip(other)` — sequential pair.
- **M3.6** `zipWith(other, fn)` — sequential combine.
- **M3.7** `all(effects)` — sequential gather (Effect-TS small-`all`).
- **M3.8** `when(cond, eff)` — conditional execution.
- **M3.9** `unless(cond, eff)` — negated conditional.
- **M3.10** `forEachAlloc(iter, fn)` — sequential traversal.
- **M3.11** `forEachDiscard(iter, fn)` — sequential traversal, ignoring results.
- **M3.12** Facade export of M3.1–M3.11 from `src/zigeffect.zig`. **Test:** `test/effect_ergonomics_test.zig` with one assertion per combinator.
- **M3.13** Document each combinator in `docs/effectts-parity.md` (update the "open" list).

---

## Track 4 — Effect structured-concurrency surface

D2 gave us real interleaving; this gives users an API to compose it.

- **M4.1** `forEachPar(iter, fn, opts)` — parallel traversal (opts: concurrency cap).
- **M4.2** `zipPar(other)` — parallel pair; combined exit only when both succeed.
- **M4.3** `race(other)` — first to succeed wins; loser interrupted.
- **M4.4** `raceFirst(other)` — first to finish (success or failure) wins.
- **M4.5** `raceAll(iter)` — N-way race.
- **M4.6** `both(other)` — parallel pair semantically distinct from zipPar (any failure interrupts).
- **M4.7** Loser-interrupt cause-edge wiring (depends on M2.7).
- **M4.8** `examples/effect_structured_concurrency.zig` covering each operator.
- **M4.9** Causal-equivalence test: each operator's deterministic-vs-zio trace is structurally equal (the D2 invariant generalizes).

---

## Track 5 — Effect state primitives

- **M5.1** `Ref(T)` — atomic cell (get/set/update). Single-threaded v1; document the thread-safety boundary for future v2.
- **M5.2** `SynchronizedRef(T)` — effectful update under a semaphore.
- **M5.3** `FiberRef(T)` — fiber-local with auto-propagation across fork. Propagation happens via the `FiberExecutor.spawn`'s `FiberJob` — extend `FiberJob` with a small ref snapshot vector.
- **M5.4** `Hub(T)` with bounded/sliding/dropping variants — multi-subscriber broadcast. Emits `hub_published` / `hub_received` causal events. **Critical dep:** unblocks workbench live-attach (Track 10) AND agent-attach query interface (Track 8).
- **M5.5** Facade export + tests for each primitive.
- **M5.6** `examples/effect_state.zig` — `Ref` counter, `FiberRef` request-id propagation, `Hub` fanout.

---

## Track 6 — Effect higher-order

- **M6.1** `STM` (transactional memory): `TRef`, `atomically(stm)`, retry semantics via `Deferred`. Emits `stm_attempt` / `stm_committed` / `stm_retried` events.
- **M6.2** `Stream<A,E,R>` first-class effectful stream: `from`/`fromIterator`/`take`/`drop`/`run`/`runCollect`/`mapEffect`. Chunking semantics.
- **M6.3** Full recursive `Schedule` algebra: `union`/`intersect`/`andThen`/`whileInput`/`modifyDelay`. Was explicitly deferred (`effectts-parity.md L204-205`).
- **M6.4** Compile-time effect-composition assertions (`requires` as type-level algebra). Hard — research milestone, may stay deferred; if so, document the boundary explicitly.
- **M6.5** `fx.Test` fixtures/golden output/registry parity (lens-3 gap 16). Cross-link Track 10.
- **M6.6** Effect generator / do-notation — explicitly punted by `effectts-parity.md L57-58`; record the punt formally.

---

## Track 7 — Async substrate (zio vtable fill + adjacent)

Migrate the conformance test from "asserts UnsupportedBackendCapability" to "asserts working."

- **M7.1** `schedule_timer` on zio — per-suspension-id keyed timer.
- **M7.2** `interrupt` on zio — wire per-suspension-id cancel.
- **M7.3** `suspend_runtime` / `wake` keyed by suspension id.
- **M7.4** `register_io_wait` / `complete_io` over `std.Io`.
- **M7.5** Expose `std.Io` as engine effects — `fx.io.read(fd, buf)`, `fx.io.write(fd, buf)`, `fx.io.accept(sock)`. Each emits `io_wait_started` / `io_completed` with the schedule-id correlation.
- **M7.6** `DurableAsyncBackendState` — the missing implementation behind `durableLocalBackend()`'s `can_durable_suspend=true`.
- **M7.7** Clustered `AsyncBackend` — the missing implementation behind `clusteredBackend()`'s `can_distribute=true`.
- **M7.8** `FiberExecutor.interrupt(handle: *anyopaque) void` — vtable extension. **Cross-cuts Track 8 (executable remediation).**
- **M7.9** `ZioFiberExecutor.interrupt` → `JoinHandle.cancel`.
- **M7.10** Single-executor assertion at adapter boundary (M11.7 dup) — assert `RuntimeOptions.executors == .exact(1)` on construction.
- **M7.11** Conformance test rewrite (`packages/zigeffect-zio/src/zio_backend.zig:893-901`): each `Unsupported...` assertion migrates to "asserts working" as the corresponding M7.x lands.
- **M7.12** Per-vtable-method adapter test driven via the engine, NOT via the scenario harness — proves the seam services real workloads.

---

## Track 8 — Self-improving harness depth

The "novel claim made real" track. Built atop Tracks 2/5/7.

- **M8.1** Autonomous closed-loop runner — `causal-dev-loop --autonomous` that chains baseline → change → after → compare → verdict without human prompts. Reuses the per-step CLIs.
- **M8.2** **Level 6** — deterministic replay of arbitrary event logs. `causal-replay <snapshot.json>` reconstructs runtime state and re-runs to a known point.
- **M8.3** **Level 7** — policy-controlled remediation: `policy_engine.decide(action) → Allowed|Denied|Pending`. Binding decision is a fact, not advisory.
- **M8.4** **Phase 8 action — `retry(fiber_id, schedule)`** executable. Today recordable; wire to actual re-execution under the Schedule.
- **M8.5** **Phase 8 action — `graph_restart(scope_id)`** executable. Re-open the scope under the same provider tree.
- **M8.6** **Phase 8 action — `interrupt(fiber_id, cause)`** executable. Depends on M7.8.
- **M8.7** **Phase 8 action — `replay_scenario(snapshot_id)`** executable. Depends on M8.2.
- **M8.8** Live agent-attach query interface (via `Hub` from M5.4). Today `causal-query` reads saved JSON only — make it stream from a running `CausalStore`.
- **M8.9** Durable cross-session learning memory — `src/services/learning_store.zig` indexed by causal-trace fingerprint; advice consulted across sessions.
- **M8.10** Findings-taxonomy extension mechanism (dup M2.9; cross-link). Agents register `CausalFindingKind` at runtime.
- **M8.11** Broader PII/payload redaction policy beyond deterministic secret-shaped strings. Defines a per-field redaction declaration on event payloads.
- **M8.12** `policy_engine` surfaced as `src/services/policy_engine.zig` (graduated from `tools/causal_policy_decision.zig`). Tool becomes a thin CLI shell.
- **M8.13** Apply boundary — `policy_engine.apply(allowed)` actually executes the action and records `applied=true` ONLY when a re-captured causal trace structurally proves the fix. Gated by per-action operator config (default OFF — Working Default #1).
- **M8.14** Verification receipt format — `applied=true` artifact carries the structural-equivalence proof inline + the before/after event ids.

---

## Track 9 — Production readiness

- **M9.1** **OTel/OTLP live export adapter end-to-end.** Add OTLP serialization + gRPC export to `src/services/causal_otel_backend.zig`. Local-collector example. (Working Default #3.)
- **M9.2** External-storage compare-and-swap for shard leases. Today split-brain safety relies on local journal stores (`roadmap.md L62-64`).
- **M9.3** M9 Operating Model enforcement — convert docs/contracts to enforced behavior: telemetry-export adapter dep on `release-gate`, alerting-hook contract test, access-control gate at the storage boundary.
- **M9.4** Cross-host production cluster transport — beyond M49 HTTP/socket.
- **M9.5** `cluster-inspect` reads real file-backed storage.
- **M9.6** NenDB pinned upstream package + live writes (post-OTel per Working Default #3).
- **M9.7** Production telemetry ingestion (consumer side of M9.1/M9.6).
- **M9.8** External CAS for shard leases via a pluggable `LeaseStore` vtable (Postgres / CockroachDB / Hyperdrive — match `CLAUDE.md` runtime targets).

---

## Track 10 — Workbench & DX

- **M10.1** Workbench live-attach via `Hub` + `CausalHubBackend`. Today the bridge fetches a single artifact; make it stream. Visual Graph tab updates as events arrive.
- **M10.2** Example: typed config descriptors (`devex-review.md` Next Priority).
- **M10.3** Example: level-aware logger.
- **M10.4** Example: metrics snapshots.
- **M10.5** Example: tracing spans.
- **M10.6** Example: layer graphs.
- **M10.7** Example: supervision trees (the missing M51 dogfood receipt).
- **M10.8** `fx.runtime.bootstrapZio(allocator, options) !RuntimeBundle` — returns wired `Runtime(Env)` + `ZioFiberExecutor` + `CausalStore` + OTel sink. Rewrite `zigeffect-zio` tests to use it.
- **M10.9** Coordinated dev-session command (`causal-dev-session -- start|assess|status`) — vision status_claim per the critique; verify still works or rebuild.
- **M10.10** `fx.Test` fixtures/golden output/registry (dup M6.5; track here).
- **M10.11** Visual Graph tab — live causal graph rendering driven by `Hub`.
- **M10.12** Replay control surface in workbench — drive M8.2 replay from the UI.

---

## Track 11 — Tooling hygiene & convergence

- **M11.1** Extract `tools/causal_snapshot.zig` (2715 LOC) → `src/services/causal_snapshot.zig` primitive; tool becomes thin shell.
- **M11.2** Extract `tools/causal_query.zig` (1932 LOC) → `src/services/causal_query_engine.zig`.
- **M11.3** Extract `tools/causal_policy_decision.zig` (1475 LOC) → `src/services/policy_engine.zig` (overlaps M8.12).
- **M11.4** `release-gate` deps on each individual backend-conformance step (jsonl/dot/otel/nendb/async-stream/graph-history). Today the umbrella does not depend on them directly — silent regression risk.
- **M11.5** `tool-roadmap.md` gate made programmatic. Today documentary — the hygiene script doesn't enforce roadmap mapping.
- **M11.6** `causal_app_*` chain convergence audit — decide what stays, what merges into the engine chain, what's deprecated. Working Default #5 freezes the chain until this lands.
- **M11.7** Single-executor enforcement at `ZioFiberExecutor` boundary (dup M7.10).
- **M11.8** Tool-count drift — vision says 46 approved, reality has 47. Reconcile, document the actual cap.

---

## Track 12 — Documentation honesty

- **M12.1** `packages/zigeffect-zio/README.md` Status section refresh — today claims Stage 1 unimplemented; reality has D1+D2 productized and Z1/Z2/Z3/Z3b proven.
- **M12.2** `effectts-parity.md L182-183` claim alignment — says "Full supervision trees remain the next Erlang-style runtime milestone" but M51 reports full supervision trees done. Pick one truth.
- **M12.3** Milestone reports M46–M51 honesty pass — partial-DONE items flagged accurately (M48 cross-host transport, external CAS, distributed supervision are deferred per audit).
- **M12.4** Top-level `packages/zigeffect/README.md` — fold productization + hardening into the headline.

---

## Track 13 — Verification & release-gate hardening

- **M13.1** `release-gate` covers all individual backend conformance (dup M11.4).
- **M13.2** Structural-equivalence regression suite per backend — each backend's scenario emits a structurally-equal trace to deterministic.
- **M13.3** Adversarial cancellation test matrix — timer (T0.8 covered), queue (new), IO (new), coordinator-wide (new).
- **M13.4** Cross-package conformance gate — `zig build conformance` step in CI that runs zigeffect + zigeffect-zio together.
- **M13.5** Property fuzz/crash test suite expansion — extend `test/property_history_test.zig`, `test/scheduler_fairness_property_test.zig` to cover Tracks 4/5/6 surface.
- **M13.6** Causal-store thread-safety contract test — proves the single-executor invariant is enforced (not just documented).

---

## Track 14 — The next evolution (the closed agent loop)

The phase change: runtime moves from record-only diagnostic substrate to policy-bounded actor inside a closed agent loop.

- **M14.1** Bounded remediation request protocol — `RemediationRequest{kind, target, params, policy_token}`. Kinds: `retry`, `interrupt`, `replace_provider`, `replay_scenario`.
- **M14.2** Live `CausalStore` attach + agent iteration loop. Built on M5.4 `Hub`. Agent subscribes, observes events, issues `RemediationRequest`s.
- **M14.3** Re-capture and structural-prove-the-fix verification — after `apply`, re-run the failing scenario, capture the new trace, run `causalStructurallyEquivalent` against the known-good shape (or `causal-compare` verdict `improved`).
- **M14.4** `applied=true` gated by policy decision + verification receipt. Default OFF (Working Default #1); per-kind enable.
- **M14.5** End-to-end demo: scripted agent observes a real injected failure → proposes a fix → policy engine approves under explicit operator-enabled posture → runtime applies → runtime verifies → `applied=true` receipt is earned and committed.
- **M14.6** Public API stabilization — once Tracks 1–13 close, mark `Effect` / `Runtime` / `FiberRuntime` / `CausalStore` / `AsyncBackend` / `FiberExecutor` as the stable v1 surface; freeze breaking changes.

---

## Sequencing (DAG sketch)

```
T0 (built) ──┬─► M1.1 (Runtime.withExecutor)
             ├─► M1.2 (suspension coord edges) ──► M2.1-M2.5 ──► M2.10 (coverage-truth gate)
             └─► M1.3 (first self-improvement session) ──► M8.1 (autonomous loop)

M3.* (ergonomics) ──► M4.* (structured-concurrency) ──► M4.7 (loser cause edge) ◄── M2.7

M5.1 (Ref) ──► M5.2 (SyncRef) ──► M5.3 (FiberRef)
                                  M5.4 (Hub) ──┬─► M10.1 (live workbench)
                                               └─► M8.8 (agent attach) ──► M14.2

M6.* (STM/Stream/Schedule) ─── independent

M7.1-M7.7 (zio vtable fill) ──► M7.11 (conformance migration)
M7.8-M7.9 (FiberExecutor.interrupt) ──► M8.6 (interrupt action) ──► M14.1

M8.2 (replay) ──► M8.7 (replay action)
M8.12 (policy_engine src/) ──► M8.13 (apply boundary) ──► M14.4 (applied=true)

M9.1 (OTel live) ──► M10.8 (bootstrapZio) ──► all examples
M11.* (hygiene) ──► M13.1 (release-gate deps)

M14.5 (demo) requires: M1.2, M2.7, M4.3, M5.4, M7.8, M8.6, M8.13, M9.1
```

---

## Verification protocol (per-milestone)

Every milestone, regardless of size, ships with:

1. **A test** — usually `test/<area>_test.zig` or `examples/<scenario>/`. Asserts the observable claim.
2. **A causal-equivalence check** for any milestone touching the runtime — assert the new path produces a structurally-equal trace to the deterministic baseline (where both exist).
3. **A release-gate hook** for any milestone touching tools/backends — add the step to `build.zig` so regression is caught.
4. **An adversarial pass** for any milestone touching cancellation, lifetimes, or concurrency — run the same lens that caught H1 (review agent reads the diff against an adversarial brief).
5. **A doc update** — the relevant `docs/` file gets the status moved from open to done with a one-line evidence phrase.

---

## Autonomous execution rules

Because the user explicitly said "let me cook, get this thing mapped and all points delivered" without human intervention:

1. **Default to action.** If a milestone is well-scoped and unambiguous, build it.
2. **Default to the Working Defaults table** for any of the five open questions.
3. **Stop and ask ONLY** if: (a) a milestone requires a destructive action (force-push, deletion, secret access), (b) a fundamental tradeoff appears that the Defaults table doesn't cover, (c) a milestone reveals that an earlier "DONE" claim was wrong in a way that invalidates downstream milestones.
4. **Each milestone gets its own commit** — small, reviewable, with the Co-Authored-By trailer (Claude Opus 4.7 unless model context changes).
5. **Verification after every milestone** — `zig build test-raw` + `zig build examples` + `zig build release-gate` on the core; `zig build test` on the adapter. Never skip.
6. **Honest reporting** — if a milestone partially lands, the commit message says "partial: …" and the corresponding TODO milestone stays open. Never claim a milestone done by moving paperwork.
7. **Track progress in `TaskCreate`** — one task per milestone; mark `in_progress` on start, `completed` on commit + verification green.
8. **Adversarial review at track boundaries** — at the end of each track, run a focused review agent like the one that caught the H1 cancellation bug, looking for regressions and missed contract gaps.
9. **Update this roadmap** — mark milestones DONE in-place with the commit sha; any new gap discovered gets added to the relevant track as a numbered milestone.
10. **When the cook is done** — when every track closes or a real blocker is hit, surface a single status report.

---

## Honest scope notes

- The audit read ~7% of the ~350 plan/spec/report files. Tracks above cover every bullet the audit surfaced. Any vision item in unread cohort-specific roadmaps (workflow sub-roadmaps, scenario-registry plans, performance-budget specs) is NOT in this document yet. When such an item is discovered mid-execution, it gets added to the relevant track and counted.
- `Track 14` is intentionally the last track. It depends on a wide swath of earlier work; attempting it before its deps land will fail honestly rather than fake the outcome.
- Effort estimates are rough. The roadmap is a graph, not a schedule.
