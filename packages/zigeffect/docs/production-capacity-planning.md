# zigeffect Causal Production Capacity Planning

`causal-production-capacity-planning` is the deterministic, record-only
capacity planning contract for zigeffect causal production hardening. It gathers
the evidence shape produced by prior hardening milestones and turns it into
explicit assumptions, missing-evidence gates, negative fixtures, and the next
completion-audit handoff.

## Command

```sh
cd packages/zigeffect
zig build causal-production-capacity-planning
zig build causal-production-capacity-planning -- --format json
```

The text report is for maintainers. The JSON report uses schema
`zigeffect.causal.production-capacity-planning.v1` for agents and automated
roadmap checks.

## Authority Boundary

This report is `record-only`, `planning-only`, and has
`mutation_authority=none`. It does not ingest production telemetry, execute
load tests, size production capacity, estimate production cost, provision
infrastructure, host dashboards, write durable storage, send alerts, create
tickets, shift traffic, edit source/config/app/registry/deployment state, or
grant mutation authority.

Durable planning remains NenDB adapter work only. Workbench planning remains
SolidJS inside `webui-dev/zig-webui`; alternate frontend renderers are outside
this milestone.

## Source Contracts

The report consumes these schema-governed evidence contracts:

- `production-artifact-aggregation`: bundle provenance, source classes, privacy
  review, and source aggregation boundaries.
- `durable-production-retention`: NenDB retention, TTL, compaction, backup, and
  recovery policy.
- `wall-clock-benchmark-baselines`: local and CI scenario families, baseline
  record fields, environment metadata, calibration policy, and advisory gates.
- `live-dashboard-stream`: bounded stream windows, read-only workbench
  transport, truncation, and redaction state.
- `agent-query`: bounded query slices with evidence ids, redaction state,
  truncation state, and next-query hints.
- `human-agent-feedback-loop`: workbench selections, before/after comparisons,
  local regression clusters, and guarded proposal handoffs.
- `alerting-integrations`: alert preview records, severity routing, escalation
  gates, and external integration handoff fixtures.
- `rollout-automation-guardrails`: canary evidence, rollout progression gates,
  circuit breakers, rollback readiness, and negative automation fixtures.

Missing upstream evidence blocks the capacity domain that depends on it. Agents
should cite the source schema and producer whenever they summarize a capacity
assumption.

## Capacity Domains

The contract defines ten planning domains:

1. `retained-artifact-storage`
2. `nendb-retention-compaction`
3. `benchmark-observation-coverage`
4. `request-trace-volume`
5. `background-job-trace-volume`
6. `artifact-formatting-and-query`
7. `dashboard-stream-window`
8. `visual-graph-rendering`
9. `agent-query-and-feedback`
10. `alerting-rollout-handoff-volume`

Each domain records the planning question, required evidence, formula or model
expression, review status, and agent guidance. Formulae are placeholders for
reviewed observations, not production capacity claims.

## Storage Assumptions

Known NenDB retention policy constants:

- `retention-days = 14`
- `max-events-per-bundle = 4096`
- `compaction-trigger-events = 2048`
- `compact-to-events = 1024`
- `backup-required = true`
- `recovery-required = true`

Unknown until reviewed observation or policy:

- retained bundles per day
- average events per bundle
- bytes per event estimate
- backup multiplier
- compaction overhead factor

Agents should report these as missing evidence, not fill them from local
fixtures or optimistic averages.

## Load-Test Fixture Plan

The report plans fixtures for the eight wall-clock scenario families without
executing them:

- `app-request-trace`
- `background-job-trace`
- `causal-artifact-formatting`
- `causal-query-agent-slices`
- `causal-compare-before-after`
- `causal-dev-loop-package-tests`
- `workbench-solid-build`
- `ci-baseline-capture`

Every fixture has required evidence and a blocking missing-evidence reason. A
future load-test harness should consume these records only after review confirms
compatible baselines, aggregation provenance, retention policy, redaction
state, and authority boundaries.

## Workbench And Agent Concurrency

The first planning contract assumes bounded local viewer behavior:

- one retained artifact or sampled bundle at a time in the SolidJS workbench;
- bounded dashboard frame windows with truncation metadata;
- lazy visual graph perspectives with explicit node and edge fixture sizes;
- read-only graph perspectives over the unified causal spine;
- bounded agent query slices instead of unbounded artifact dumps;
- local regression clusters until durable history learning is reviewed;
- alert and rollout previews only, with no external sends or execution.

These assumptions are not multi-user production dashboard, graph database,
agent memory, incident-management, or rollout automation capacity claims.

## Readiness Gates

Capacity planning becomes reviewable only when these gates have evidence:

- `aggregation-provenance-reviewed`
- `retention-policy-reviewed`
- `benchmark-baselines-reviewed`
- `dashboard-boundary-reviewed`
- `graph-boundary-reviewed`
- `agent-query-bounds-reviewed`
- `alert-rollout-handoff-reviewed`
- `load-test-plan-ready`
- `capacity-plan-ready-for-review`

When a gate is missing evidence, agents should block the dependent claim and
request the missing source contract or fixture.

## Negative Capacity Fixtures

The report rejects over-claims such as:

- production capacity inferred from one unreviewed timing baseline;
- storage estimates without aggregation provenance;
- TTL enforcement claims without capture timestamps and retention reports;
- dashboard concurrency inferred from the local workbench;
- graph capacity without node and edge fixture evidence;
- incident volume inferred from alert previews;
- rollout volume inferred from canary guardrail records;
- autoscaling recommendations without telemetry and review.

## Handoff

The next branch is
`codex/zigeffect-causal-production-hardening-completion-audit`.

That audit should verify every delivered production-hardening report, confirm
that capacity planning stayed record-only, and decide which future branch should
turn planning evidence into an observed load-test harness, production telemetry
capture design, or production readiness review.
