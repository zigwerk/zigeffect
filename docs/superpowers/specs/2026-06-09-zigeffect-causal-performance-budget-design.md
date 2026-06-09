# zigeffect Causal Performance Budget Design

Date: 2026-06-09

## Purpose

This branch finishes the next M9 operating-model gap by making causal
instrumentation overhead explicit, checkable, and release-reviewable. The goal
is not to add a flaky timing benchmark. The goal is a deterministic budget
contract that tells humans and agents which bounded-memory, artifact-size,
sampling, backend, workbench, and release-review limits must hold before a
causal runtime change is considered ready.

This is part of the long-running zigeffect causal self-improvement system. The
performance budget should be useful to a development agent while it changes
zigeffect itself and to app-facing agents that inspect causal artifacts from
applications built with zigeffect.

## Current Context

The causal runtime already exposes the main overhead controls:

- `CausalStoreOptions.max_events` caps retained event memory.
- `CausalStoreOptions.max_event_string_bytes` caps retained event string size.
- `CausalSamplingPolicy` samples only `log_recorded`, `metric_recorded`, and
  `span_recorded` observability events.
- causal JSON artifacts disclose retention, sampling, truncation, and backend
  failure counters.
- app-facing defaults bound request traces at 256 events and background-job
  traces at 1024 events, with 256-byte event string fields.
- the workbench rejects artifacts above 4 MiB before reading them.
- CI uploads only causal `.txt`, `.json`, and `.dot` artifacts with 14-day
  retention.
- schema governance and operations docs already exist.

What is missing is one authoritative report that names these budgets, verifies
the constants that can be checked locally, and gives a release-note checklist
for changes that affect causal overhead.

## User-Facing Direction

The workbench UI direction is SolidJS inside `webui-dev/zig-webui`:

```text
SolidJS renderer
  -> Bun/Vite static build
  -> Zig launcher and bounded read-only bridge
  -> webui-dev/zig-webui native window or local server
```

`zig-webui` is the host and bridge boundary. SolidJS is the renderer running in
that webview. React is not part of this branch and should be introduced only if
a future integration has a concrete need that cannot fit the SolidJS path.

## Chosen Approach

Add a deterministic `zig build causal-performance-budget` report.

The report will be a small Zig tool, following the same shape as
`causal-schema-governance`:

- default text output for humans;
- `--format json` output for agents and CI;
- unit tests for option parsing, budget inventory, text output, JSON output,
  and checked constant alignment;
- build wiring that runs tool tests under `zig build test`;
- documentation in README, operations, schema governance, and a dedicated
  performance budget page.

This branch should add a new artifact schema family:

```text
zigeffect.causal.performance-budget.v1
```

The schema is a record-only operating-model artifact. It does not capture a
runtime trace, mutate source, launch the workbench, write a durable store, or
enforce wall-clock timing. It records the current budget contract and whether
each checkable budget matches the runtime constant or documented command.

## Alternatives Considered

### A wall-clock benchmark command

This would measure event record latency, backend write latency, and workbench
build time. It is useful later, but not as the first M9 budget because local and
CI machines vary enough to make wall-clock gates noisy. It also risks teaching
agents to over-trust one machine's timing.

### Docs only

This would be quick, but agents need a machine-readable contract they can print
before changing causal overhead surfaces. Docs alone would let budget claims
drift from runtime constants.

### Deterministic budget report

This is the chosen path. It makes current limits visible, testable, and stable
in CI while leaving true benchmark baselines as later production hardening.

## Budget Model

The initial budget report should include these categories.

### Store Retention

- `default`: unbounded unless a caller opts into `CausalStoreOptions`.
- `app-request`: `max_events = 256`.
- `app-background-job`: `max_events = 1024`.

The report should mark request and job defaults as checked against
`fx.default_request_max_events` and `fx.default_job_max_events`.

### Event String Bounds

- `app-event-string`: `max_event_string_bytes = 256`.
- redaction runs before truncation and before backend emission.
- truncation is disclosed through `truncated_fields`.

The report should mark the app default as checked against
`fx.default_app_max_event_string_bytes`.

### Sampling

- sampling remains opt-in.
- sampling is allowed only for observability event kinds:
  `log_recorded`, `metric_recorded`, and `span_recorded`.
- structural runtime events must remain unsampled.
- sampled-out events consume ids but do not enter retained storage or attached
  backends.

This category is descriptive in the budget report, backed by existing causal
store tests.

### Artifact And Workbench Bounds

- workbench artifact read limit: 4 MiB.
- workbench session schema: `zigeffect.causal.workbench-session.v1`.
- workbench mode: read-only SolidJS renderer hosted by `webui-dev/zig-webui`.
- retained CI artifact globs: causal `.txt`, `.json`, and `.dot` only.
- CI retention: 14 days.

The workbench artifact limit should be checked against
`causal_workbench_session.max_artifact_bytes`.

### Backend Sink Posture

- backends are sinks, not the authoritative store.
- backend failures must not fail deterministic store recording.
- backend failures must be disclosed through `failed_writes`.
- backend conformance remains required for adapter compatibility.
- current durable direction is the NenDB writer contract and adapter boundary.
- no Cockroach adapter is introduced by this branch.

### Release Review

The release guidance should require a causal change author to answer:

- Does the change alter retained event count, event string bounds, sampling, or
  backend emission?
- Does the change add or change an artifact schema?
- Does the change alter workbench artifact size, bridge behavior, or UI
  hosting?
- Does the change alter CI artifact upload globs or retention?
- Does the change need a release-note entry for overhead, compatibility, or
  migration posture?

The release checklist should include these commands:

```sh
cd packages/zigeffect
zig build causal-performance-budget
zig build causal-performance-budget -- --format json
zig build causal-schema-governance
zig build examples
zig build test
cd ../..
bun run check
bun run zig:test
git diff --check
```

## Report Shape

Text output should be stable and scan-friendly:

```text
zigeffect causal performance budget
schema: zigeffect.causal.performance-budget.v1
schema_version: 1
status: current

budgets:
- app-request-retention
  value: max_events=256
  check: passed
  source: fx.default_request_max_events
...

release checklist:
- run zig build causal-performance-budget
- update release notes when overhead surfaces change
```

JSON output should contain:

- `schema`
- `schema_version`
- `status`
- `generated_by`
- `budgets`
- `release_review`
- `verification_commands`
- `non_goals`

Each budget entry should contain:

- `id`
- `category`
- `description`
- `budget`
- `source`
- `check`
- `agent_guidance`

Checks should use string values such as `passed`, `documented`, and
`review-required` instead of booleans so agents do not confuse documented
posture with executable verification.

## Documentation Changes

Add `packages/zigeffect/docs/performance-budget.md` with:

- command usage;
- budget categories;
- release-note checklist;
- agent interpretation rules;
- SolidJS inside `webui-dev/zig-webui` workbench note;
- explicit non-goals.

Update:

- `packages/zigeffect/README.md`
- `packages/zigeffect/docs/operations.md`
- `packages/zigeffect/docs/schema-governance.md`
- `packages/zigeffect/docs/roadmap.md`
- `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`

## Schema Governance

Because the performance-budget report has JSON output for agents, it should be
registered in `causal-schema-governance` as an official schema:

```text
schema: zigeffect.causal.performance-budget.v1
category: operating-model
status: current
emitted_by: causal-performance-budget
consumed_by: agents, reviewers, CI docs
compatibility: record-only
requirements: budget report tests, operations docs, release guidance
```

Existing schema count tests must be updated after adding the new entry.

## Non-Goals

This branch does not add:

- wall-clock latency gates;
- throughput benchmarks;
- production capacity planning;
- production dashboards;
- alerting or paging;
- RBAC, encryption-at-rest policy, or SIEM integration;
- source/config mutation authority;
- React workbench support;
- Cockroach adapter work.

## Success Criteria

The branch is successful when:

- `zig build causal-performance-budget` prints the text report.
- `zig build causal-performance-budget -- --format json` prints
  machine-readable JSON.
- `zig build test` runs the performance-budget tool tests.
- schema governance lists `zigeffect.causal.performance-budget.v1`.
- operations and README docs point agents to the budget command.
- release guidance is explicit enough for a causal-runtime author to decide
  when release notes are required.
- the master roadmap marks the performance budget and release guidance as
  delivered, while leaving any true production operating gaps explicit.
