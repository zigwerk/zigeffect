# zigeffect Roadmap

Date: 2026-06-20

`zigeffect` is a Zig-native Effect-inspired engine whose primary debugging
interface is a deterministic, queryable **causal event graph** that LLM agents
query structurally (cause, lineage, resources, fibers, requirements, retries,
findings) instead of parsing logs. The goal is not API cloning; it is a
production-grade Zig shape for direct-style programs, typed errors, service
requirements, scoped resources, dependency layers, an agent-observable causal
runtime, and — eventually — real async and distributed execution.

The deterministic, semantic-first philosophy is deliberate: the core must be
testable without threads, IO, or wall-clock time. Real async and distributed
execution are deferred to backend adapters that must obey the same Scope / Exit /
Cause / event contracts.

## Status at a glance

| # | Pillar | Status | Where |
|---|--------|--------|-------|
| 1 | Effect core + typed errors | **done** | `src/effect/effect.zig`, `src/core/result.zig`, `src/core/context.zig` |
| 2 | DI layers + layer graph | **done** | `src/layer/layer.zig`, `src/layer/graph.zig`, `src/dependency/*` |
| 3 | Scoped resources + finalizers | **done** | `src/core/scope.zig`, `src/effect/resource.zig` |
| 4 | Fiber runtime | **partial — deterministic only** | `src/runtime/fiber.zig`, `src/runtime/coordination.zig`, `src/runtime/async_backend.zig` |
| 5 | Causal store + event graph + queries | **done** | `src/services/causal.zig` |
| 6 | Causal dev loop (compare/advice/verdict) | **done** | `tools/causal_dev_loop`, `causal_compare`, `causal_advice`, `causal_verdict` |
| 7 | Guarded remediation chain | **done (record-only)** | `tools/causal_*remediation*`, `causal_policy_decision`, `causal_audit_chain` |
| 8 | App-facing causal trace | **done** | `src/services/causal_app_runtime.zig` |
| 9 | Visual workbench (SolidJS / zig-webui) | **partial — read-only/local** | `workbench/`, `tools/causal_workbench*` |
| 10 | Export adapters (JSONL/DOT/OTel/graph-history/NenDB) | **partial — mapping only** | `src/services/causal_*_backend.zig` |
| 11 | Durable workflows + clustering | **partial — in-memory** | `src/workflow/*`, `src/cluster/*` |

## What is real today

- Direct-style effects with typed success/failure channels; `Exit`/`Cause`/`CauseTree`.
- Dependency injection gates, layer startup/teardown, heterogeneous graph startup
  with memoization, and readable dependency diagnostics.
- Deterministic scoped cleanup with reverse-order, exit-aware finalizers.
- Deterministic fiber lifecycle (`fork`, `join`, `interrupt`, scoped leases) and
  coordination primitives (`Deferred`, `Queue`, `Semaphore`) with wait-state
  inspection.
- A bounded, opt-in **causal event model** (`CausalStore`) with structural /
  finding-evidence / sampleable taxonomy, secret redaction, retention/sampling/
  truncation disclosure, and the structural queries agents rely on.
- The causal **dev loop** and **guarded remediation chain** — the
  self-improvement harness, all record-only (`mutation_authority=none`).
- App-facing causal traces (`CausalAppTrace`) that emit the same
  `zigeffect.causal.v1` events from Worker-shaped request/job paths.
- Export adapters as sinks (JSONL, DOT, OTel-shaped, graph-history, NenDB
  write-contract, async stream) with per-adapter conformance gates.

## Boundary decisions (intentional non-goals, for now)

- **The fiber runtime is deterministic/semantic-first.** Fibers run to completion
  on join. `async_backend.zig` defines a full `AsyncBackend` vtable
  (suspend/wake/timer/interrupt/IO-wait) but the only implementation is an
  in-memory virtual-clock simulation — no real threading or IO. Real suspension
  belongs to the optional `packages/zigeffect-zio` adapter (see the forward
  sequence); the core stays zio-free so it remains testable without threads, IO,
  or wall-clock time.
- **Clustering transports are in-memory.** `production_http`/`production_socket`
  kinds format bytes and route through an in-process transport over in-memory
  storage; no real sockets yet. Durability is local journal stores.
- **The remediation chain never mutates.** It records review/application state;
  it does not edit source, config, migrations, or external systems.
- `requires` stays Zig-native metadata plus validation, not a type-level
  requirement algebra. `Exit` stays a lightweight by-value result.

## The single biggest gap

**The real async/concurrency execution layer.** Pillars 5–10 (the causal-graph
vision) are the strongest, most complete part of the package; what is missing is
the runtime substrate underneath actually doing concurrent/async/distributed
work. The causal graph today faithfully explains a *deterministic simulation* of
execution. The thesis — agents debugging real programs through runtime-owned
structured facts — is only fully testable once the graph explains real
concurrency.

## Forward sequence

1. **Build the zio backend (`packages/zigeffect-zio`).**
   [zio](https://github.com/lalinsky/zio) v0.14.0 — installed with
   `zig fetch --save "git+https://github.com/lalinsky/zio#v0.14.0"` — targets
   Zig 0.16 on its `main` branch (use the `zig-0.17` branch for Zig master) and
   provides stackful coroutines plus a full `std.Io` implementation over
   io_uring / epoll / kqueue. Add it as a **separate, optional adapter package**
   that implements the `AsyncBackend` seam; the core `packages/zigeffect` stays
   zio-free and must pass its tests without it. Map `fork` → `group.spawn`,
   scoped fibers → `zio.Group` lifetime, `interrupt` → `group.cancel`, and start
   with a single primitive (timer + IO wait). Keep `LocalAsyncBackendState` as
   the deterministic compatibility-suite reference: the same program must produce
   the same causal trace under both backends.
2. **Wire it into the wait-states.** Make `Queue`/`Semaphore`/`Deferred` actually
   suspend/resume on the zio backend (backed by zio channels / sync primitives) —
   the smallest end-to-end proof that deterministic event semantics survive a
   real backend.
3. **Make one export adapter live end-to-end.** Either OTel (add OTLP
   serialization + a local collector sink) or NenDB (pin the upstream package,
   adapt `addNode`/`addEdge`/`flush`) so the causal graph leaves the in-memory /
   fixture world against a real consumer.
4. **Harden the workbench path.** Ensure `causal_workbench` launches against a
   real recorded run (not just `?sample=` fixtures) and connect the Visual Graph
   tab to a live store.
5. **Cross the distributed boundary once.** Replace one in-memory cluster
   transport with a real loopback TCP socket behind the `ClusterTransport` vtable,
   using the in-process transport as the deterministic test double.

Hardening work (durable retention, deployment runbooks, access control,
telemetry export, alerting) is deferred until the runtime substrate above is
real. When any of it returns it must be a `src/` capability with a test and an
approved entry in [tool-roadmap.md](tool-roadmap.md) — never a record-only
contract printer.

## June 2026 cleanup note

An autonomous self-improvement loop over-generated ~120 record-only governance
tools (counter-tier `*_level_*` clones and `*_evaluation_report_evaluation_report_*`
recursion chains), plus ~340 dedicated docs/plans. All were removed; the engine
`src/` was untouched and verified green. Guardrails now prevent recurrence:
`tools/check_tool_hygiene.sh` (CI + pre-commit hook), the Tool Hygiene Policy in
`AGENTS.md`/`CLAUDE.md`, and the approval gate in [tool-roadmap.md](tool-roadmap.md).
