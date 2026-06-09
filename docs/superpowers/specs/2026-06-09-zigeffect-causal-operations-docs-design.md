# zigeffect Causal Operations Docs Design

Date: 2026-06-09

## Purpose

This branch documents the day-to-day operating model for the zigeffect causal
self-improvement runtime. The causal system now has many commands and artifact
families, but the operational contract is spread across the README, agent guide,
scenario docs, schema governance docs, roadmap, CI workflow, and tool output.

The goal is to give human maintainers and development agents one practical
runbook for local development, CI failures, artifact retention, handoff,
review gates, guarded application records, workbench inspection, backend
adapter operation, redaction review, and scenario governance.

## Current Context

The branch starts after the schema governance milestone. Current verified
surfaces include:

- `.github/workflows/zigeffect-causal.yml` runs on zigeffect PRs, `master`
  pushes, and manual dispatch with `contents: read`.
- CI captures PR base causal baselines, runs `causal-artifacts`,
  `causal-test`, `examples`, and the causal package test gate, then writes
  `causal-ci-handoff` and uploads only causal artifact globs on failure.
- CI artifact upload is limited to
  `packages/zigeffect/.zig-cache/causal-artifacts/*.txt`, `*.json`, and
  `*.dot` with `retention-days: 14`.
- `zig build causal-artifacts` prints the local/CI retention manifest.
- `zig build causal-ci-handoff` writes the first-read CI failure report and
  generated advice pointers.
- `zig build causal-schema-governance` prints the authoritative schema/version
  matrix for current causal artifacts.
- `zig build causal-workbench -- <artifact.json>` opens the SolidJS workbench
  through `webui-dev/zig-webui`, and `--server-only` exposes a local
  inspection URL.
- Registry and app application tools are record-only boundaries. They only set
  `applied=true` after reviewed readiness evidence and post-change verification
  evidence exist.
- Backend adapters exist for memory, JSON Lines, DOT, OpenTelemetry, graph
  history, NenDB storage writer contract, and async streams.

## Chosen Approach

Add one operations manual:

```text
packages/zigeffect/docs/operations.md
```

This document becomes the operational front door. It should not duplicate every
line of the agent guide or scenario docs. Instead, it defines the sequence,
ownership, decision points, and evidence requirements for operating the causal
runtime.

Update the existing entry points to link to it:

- `packages/zigeffect/README.md`
- `packages/zigeffect/docs/agent-guide.md`
- `packages/zigeffect/docs/agent-observable-runtime.md`
- `packages/zigeffect/docs/causal-scenarios.md`
- `packages/zigeffect/docs/schema-governance.md`
- `packages/zigeffect/docs/roadmap.md`
- `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`

## Operations Manual Structure

The new manual should contain these sections.

### Scope And Authority

State that the current operating model is local/CI and record-only. It may
produce, inspect, compare, review, and record application evidence. It does not
mutate source, deploy production systems, page humans, write durable production
stores, or bypass human review.

### Command Map

List the primary commands by job:

- local artifact capture: `causal-test`, `causal-check`, `causal-run`,
  `causal-dev-loop`, `causal-dev-session`;
- CI and handoff: `causal-artifacts`, `causal-ci-handoff`;
- query and advice: `causal-query`, `causal-compare`, `causal-advice`,
  `causal-diagnosis`;
- governance and review: `causal-remediation-audit`,
  `causal-remediation-decision`, `causal-patch-proposal`,
  `causal-audit-chain`, `causal-policy-decision`;
- registry application: `causal-scenario-proposal`,
  `causal-scenario-registry-patch`, `causal-registry-application-readiness`,
  `causal-registry-apply`;
- app remediation: `causal-app-remediation-audit`,
  `causal-app-policy-decision`, `causal-app-human-review`,
  `causal-app-patch-proposal`, `causal-app-application-readiness`,
  `causal-app-apply`;
- snapshots and replay: `causal-snapshot` subcommands;
- schema and workbench: `causal-schema-governance`, `causal-workbench`,
  `causal-workbench-ui`;
- backend checks: `causal-backend-conformance`, `causal-jsonl-backend`,
  `causal-dot-backend`, `causal-otel-backend`,
  `causal-graph-history-backend`, `causal-nendb-storage-backend`,
  `causal-async-stream-backend`.

### Local Development Runbook

Define the expected local loop:

1. Print schema governance and artifact manifest when changing causal artifact
   families, CI upload behavior, or agent-visible outputs.
2. Start with `zig build causal-dev-session -- start [scenario]` or
   `zig build causal-dev-loop -- baseline [scenario]`.
3. Make the code/docs change.
4. Run `zig build causal-dev-session -- assess [scenario]` or
   `zig build causal-dev-loop -- after [scenario]`.
5. Inspect the verdict, advice, diagnosis, and query commands.
6. Use the SolidJS `zig-webui` workbench when graph or remediation-chain
   inspection is faster than reading text artifacts.
7. Run the relevant verification commands before claiming completion.

### CI Failure Handoff

Define the first-read order for uploaded artifacts:

1. `zigeffect-causal-ci-verdict.json`
2. `zigeffect-causal-ci-handoff.txt`
3. generated `*-advice.txt`
4. generated `*-ci-compare.txt` when PR baseline artifacts exist
5. source JSON artifacts using printed `causal-query` commands

Also state that CI has read-only permissions, uploads artifacts only on
failure, retains them for 14 days, and does not mutate registry/source state.

### Artifact Retention And Sharing

Document:

- local artifacts live under `.zig-cache/causal-artifacts/`;
- CI upload globs are exactly `*.txt`, `*.json`, and `*.dot`;
- the rest of `.zig-cache` should not be uploaded;
- text artifacts are for human triage;
- JSON artifacts are the agent-readable source of truth for queries;
- DOT artifacts are graph visualization helpers;
- bounded, sampled, or truncated artifacts must be cited as incomplete;
- retention in CI is 14 days.

### Redaction Review

Document the review checklist before sharing artifacts:

- redaction runs before store retention and backend emission;
- scan uploaded `.txt`, `.json`, and `.dot` artifacts for visible secrets;
- confirm secret-shaped values are replaced with `<redacted>`;
- cite truncation metadata when `truncated_fields` is nonzero;
- treat the policy as deterministic backstop, not complete PII classification;
- never intentionally record request bodies, cookies, credentials, or raw
  headers in causal event strings.

### Human Review And Guarded Application

Define the operating rule:

- review, policy, readiness, and application artifacts are evidence records;
- `applied=false` is the default state;
- only `record-applied` modes can record `applied=true`;
- `record-applied` requires reviewed readiness plus current source/config state
  and post-change verification evidence;
- registry application is limited to the scenario-registry/docs boundary;
- app application records are record-only and do not mutate source, config,
  migrations, runbooks, operations, or rollback systems.

### Workbench Operation

Document how to open artifacts:

```sh
cd packages/zigeffect
zig build causal-workbench -- .zig-cache/causal-artifacts/zigeffect-causal-dogfood.json
zig build causal-workbench -- --server-only .zig-cache/causal-artifacts/zigeffect-causal-dogfood.json
```

State that the workbench is a SolidJS app launched through
`webui-dev/zig-webui`, reads one artifact through a bounded read-only Zig
bridge, and is not an approval or mutation surface.

### Backend Adapter Operations

Summarize the backend contract:

- deterministic store remains authoritative;
- adapters are sinks;
- failures must increment backend failure counters rather than failing store
  writes;
- redaction and sampling happen before backend emission;
- backend conformance is required before claiming compatibility;
- NenDB support is currently a storage writer contract and adapter tests, not a
  direct production database integration.

### Scenario And Invariant Governance

Link the operating model to `causal-scenarios.md`:

- run `causal-catalog` and `causal-test-matrix` before adding scenarios;
- prefer tightening an existing scenario/invariant when the domain is partial;
- add scenarios only for cross-subsystem causal failures that should produce CI
  artifacts;
- add invariants only for named rules that should be reused across scenarios;
- use registry proposal, patch, readiness, and apply artifacts for reviewed
  scenario-registry changes.

### Production Gaps

Explicitly defer out-of-scope production items:

- distributed artifact aggregation;
- durable production retention beyond local files and CI uploads;
- production deployment runbooks;
- alerting, paging, Slack, Linear, Jira, or SIEM integrations;
- RBAC/access control over artifact bundles;
- encryption-at-rest policy;
- live dashboards and streaming workbench;
- automated source/config mutation authority;
- performance budgets, benchmarks, and capacity planning.

Those belong to later M9 branches, especially performance budget and durable
operations branches. Durable database work remains NenDB-first; no Cockroach
adapter should be introduced by this branch.

## Alternatives Considered

### A: Keep Expanding The Agent Guide

The agent guide already contains the operational facts, but it is too broad for
operators. Adding more procedure text there would make first-read operations
harder.

### B: Split One Doc Per Operations Area

Separate docs for CI, workbench, redaction, human review, and backends would be
clean in the long term, but this branch needs one front door. Splitting can
happen once the operating model grows beyond current local/CI procedures.

### C: Add A Single Operations Manual

This is selected. It gives agents and humans one stable entry point, links to
deeper existing docs, and makes the current authority boundaries clear.

## Non-Goals

- No code changes to causal runtime or tooling.
- No CI workflow changes.
- No new durable backend implementation.
- No Cockroach adapter work.
- No production deployment automation.
- No alerting, ticketing, or paging integrations.
- No workbench UI changes.
- No new schema family.

## Acceptance Criteria

- `packages/zigeffect/docs/operations.md` exists and covers local development,
  CI handoff, artifact retention/sharing, redaction review, human review,
  guarded registry/app application, workbench operation, backend adapter
  operation, schema governance, and scenario governance.
- Existing docs link to the operations manual from the places agents and humans
  already look.
- The master roadmap marks M9 as active with operations docs delivered and
  performance budget still next.
- Immediate branch queue advances to
  `codex/zigeffect-causal-performance-budget`.
- No docs claim production mutation authority, durable production persistence,
  or production alerting exists.
- The docs preserve SolidJS plus `webui-dev/zig-webui` as the workbench UI
  path.
- The docs preserve NenDB-only durable direction for now and do not add
  Cockroach adapter scope.
- Verification passes:
  - `bun run check`
  - `bun run zig:test`
  - `git diff --check`
