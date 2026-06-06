# zigeffect Agent-Observable Causal Runtime Design

Date: 2026-06-05

## Goal

Define the definitive `zigeffect` roadmap for an agent-observable causal
runtime: a structured, queryable execution graph that helps agents reason about
the `zigeffect` engine itself and about applications built with `zigeffect`.

## Problem

Agents currently infer runtime behavior from text logs, command output, stack
traces, and source-code structure. That works for small failures, but it scales
poorly when a failure crosses effect boundaries, layer startup, scoped
resources, fibers, schedules, finalizers, and tracing spans.

`zigeffect` already owns those runtime facts. The engine can expose them as
typed events and graph queries instead of forcing agents to reconstruct them
from strings.

## Novelty Claim

The design does not claim to invent tracing, workflow replay, dynamic
instrumentation, supervision, or agent traces.

The defensible novelty claim is:

> `zigeffect` aims to be the first Zig-native agent-observable Effect runtime
> with a first-class causal execution graph spanning typed errors, services,
> layers, scopes, resources, fibers, schedules, logs, metrics, and traces.

This claim is specific enough to be credible and useful enough to guide product
and implementation work.

## Audiences

### Engine Agents

Agents maintaining `zigeffect` need structured evidence for engine regressions:

- scope ownership and finalizer ordering
- fiber fork, join, interrupt, and child-scope behavior
- layer graph startup, provider replacement, and partial-startup cleanup
- schedule decisions and retry state
- exit and cause propagation
- deterministic test failures

### App Agents

Agents maintaining apps built with `zigeffect` need app-level runtime evidence:

- failing domain effects and typed app errors
- service requirements and provider ownership
- resource acquisition and cleanup
- dependency layer startup
- retry loops and timeout behavior
- user-visible traces connected to services, scopes, and fibers
- config reads and secret-safe diagnostics

## Primary Use Cases

### Engine Regression Diagnosis

When a `zigeffect` regression appears, agents should load causal evidence from
the failing test and identify the owning subsystem. The system should support
questions such as:

- did graph validation run before startup?
- did a child fiber close because it completed or because a parent scope
  interrupted it?
- did a finalizer convert a typed program failure into a combined cause?
- did a schedule use fake time or wall-clock time?

### App Incident Explanation

When an app built with `zigeffect` fails, agents should connect the user-visible
symptom to runtime structure:

- request trace
- domain effect
- typed error
- service provider
- layer startup path
- resource scope
- retry decisions
- logs and metrics emitted under the same trace

### CI Artifact Triage

CI should eventually emit bounded causal artifacts for failed tests. Agents
should summarize the artifact into:

- failure kind
- event lineage
- likely owning module
- missing test or missing runtime invariant
- proposed fix with evidence ids

### Production Breaker Analysis

Production capture should stay bounded and policy-controlled. Breaker points
include typed failures, defects, timeout events, retry exhaustion, finalizer
failure, and explicit diagnostic probes. The first production workflow is
explain-and-propose, not autonomous mutation.

### Agent-Orchestrated Workflows

Agent managers can run sub-tasks as typed effects with scoped resources,
services, retry policies, fork/join relationships, and structured exits. The
manager can inspect critical paths and failed sub-tasks through the same causal
query surface.

### Security And Audit

The runtime should support audit questions:

- did a secret-looking value enter an exported event?
- which config descriptor supplied a value?
- who proposed a remediation action?
- which event ids justified the proposal?
- was the action approved by policy or a human?

## Contracts

- Application code remains direct-style Zig: `fn run(ctx) Error!A`.
- Causal observation is opt-in and bounded.
- Runtime events preserve typed facts: service names, layer names, error names,
  fiber ids, scope ids, trace ids, span ids, and schedule labels.
- `Context` remains the only service lookup path.
- `Scope` remains the only cleanup ownership path.
- `Exit` and `Cause` remain the shared result language.
- Event capture must not require a graph database in the deterministic core.
- Event export must be redaction-aware.
- The deterministic backend defines the compatibility suite for future async
  backends.
- Agent remediation is controlled and explicit; the runtime must not support
  arbitrary memory mutation.
- Findings and remediation proposals must cite event ids or query results.
- Edges must distinguish known causality from correlation or trace linkage.

## Non-Goals

- No arbitrary live hot-patching.
- No autonomous production self-healing without policy and approval.
- No telemetry for every `.map` or local computation by default.
- No mandatory external database.
- No change to the public direct-style effect boundary.
- No claim that every span relationship is a causal parent/child relationship.

## Architecture

Add a causal-event service and query layer over the existing runtime domains.

### Core Model

The first event model is append-only and deterministic:

- event id
- event kind
- run id
- parent event id
- fiber id
- scope id
- trace id
- span id
- label
- type name
- status
- redacted detail

This is intentionally small. It supports snapshots, lineage, and report
formatting before richer payloads are introduced.

### Runtime Hooks

Runtime hooks emit events only when a causal store is configured:

- run start/completion
- scope open/close
- finalizer start/completion/failure
- exit/cause recording
- fiber fork/start/join/interrupt
- layer startup/completion/failure
- service requirement/provider/replacement facts
- resource acquire/finalize
- schedule decisions
- structured log, metric, and span links

### Query Surface

The query layer exposes:

- `snapshot`
- `cause(id)`
- `lineage(id)`
- `resources(scope_id)`
- `fibers(status?)`
- `requirements(id)`
- `retries(run_id)`
- `findings`

Queries should have JSON output for agents and human-readable reports for
debugging.

### Findings

Findings are derived, structured diagnostics:

- missing service requirement
- duplicate provider without replacement
- layer startup failed after partial startup
- resource acquired without finalization
- finalizer failed after typed failure
- fiber pending at graph deinit
- retry budget exhausted
- span started but not ended
- config read failed
- secret-looking value entered an unredacted field

### Tooling Layers

The implementation should leave room for several product surfaces:

- runtime library APIs for stores, events, queries, and reports
- CLI output for local debugging and CI artifacts
- agent tool or MCP-style query surface
- DOT or browser visualization for demos and human debugging
- OpenTelemetry bridge for production observability ecosystems
- embedded graph backend adapter after the event taxonomy is stable
- policy-controlled remediation API after diagnosis is reliable

## Storage

Phase one uses an in-memory deterministic store. The runtime must not depend on
a database to execute or to run its deterministic tests. Later adapters reuse
the same event sink:

- JSON Lines export
- DOT export
- OpenTelemetry bridge
- NenDB or another embedded graph backend
- Cockroach/RoachGraph durable history storage for app, CI, or fleet-level
  audit
- future async backend event stream

NenDB is attractive for high-volume local graph queries, but it is explicitly a
backend adapter, not a dependency of the deterministic core. CockroachDB is
appropriate for durable cross-run history in Yachdee-style applications, but it
should not replace the local allocator-aware store used by the runtime.

## Documentation Deliverables

- Canonical package doc:
  `packages/zigeffect/docs/agent-observable-runtime.md`
- Roadmap section:
  `packages/zigeffect/docs/roadmap.md`
- Agent guide additions:
  `packages/zigeffect/docs/agent-guide.md`
- README doc link:
  `packages/zigeffect/README.md`
- Implementation plan:
  `docs/superpowers/plans/2026-06-05-zigeffect-agent-observable-causal-runtime.md`

## Testing Strategy

Implementation should follow TDD in small slices:

- unit tests for event store append/snapshot/query behavior
- runtime tests for run/scope/exit hooks
- fiber tests for fork/join/interrupt hooks
- layer tests for requirement/provider/startup events
- resource tests for acquisition/finalization lineage
- schedule tests for retry decision events
- services tests for formatter, JSON, redaction, and observability links
- app example tests for an agent diagnosis workflow

## Phasing

0. Dogfood development feedback loop for `zigeffect` itself.
1. Causal event core.
2. Runtime, scope, and fiber hooks.
3. Layer, service, resource, and schedule hooks.
4. Agent query surface.
5. App-level diagnostics and examples.
6. Engine improvement harness.
7. Backend and database adapters.
8. Controlled remediation.

## Maturity Levels

- Level 0: structured text reports from existing `Exit`, `Cause`, dependency,
  and observability formatters.
- Level 1: manual causal event store and deterministic snapshots.
- Level 2: runtime hooks across runs, scopes, fibers, resources, layers,
  schedules, exits, and causes.
- Level 3: query helpers and derived findings.
- Level 4: CI artifacts and local agent tools.
- Level 5: app-level labels and incident diagnostics.
- Level 6: deterministic replay and forking for selected effect boundaries.
- Level 7: policy-controlled remediation.

## Adapter Decision

The adapter strategy is:

- in-memory store is the reference implementation and deterministic test
  backend;
- JSON Lines and DOT are artifact/export adapters;
- OpenTelemetry is the production observability bridge;
- NenDB is the embedded graph-query adapter candidate for local agent sessions;
- Cockroach/RoachGraph is the durable history/audit adapter for app and CI
  workflows after event semantics are stable.

This keeps runtime observation local and allocator-aware while leaving a clear
path to graph queries and durable history.

## Success Criteria

- A failing effect can be diagnosed from structured graph queries without
  reading stdout.
- A failing engine test can identify the exact fiber, scope, resource, and cause
  lineage.
- An app agent can connect a failure to service providers, layers, resources,
  retry policies, and trace spans.
- Event storage is bounded and deterministic in tests.
- Exported reports redact secrets.
- Future async backends can emit equivalent event semantics.
- CI can attach a causal artifact that an agent can summarize without rerunning
  the whole job.
- App docs show how to label effects, layers, resources, and schedules so
  causal output is useful.
- Agent findings distinguish "caused by" from "correlated with" when the
  runtime only knows trace linkage.

## Spec Self-Review

- Empty-marker scan: no unresolved requirement markers remain.
- Consistency: the doc keeps the current deterministic runtime as the reference
  and treats graph databases as adapters.
- Scope: this is a large roadmap, but it is decomposed into independently
  testable phases.
- Ambiguity: remediation is explicitly controlled; arbitrary hot-patching is a
  non-goal.
