# zigeffect Causal Production Capacity Planning Design

Date: 2026-06-10

## Purpose

This branch adds the record-only production capacity planning contract for
zigeffect causal production hardening. The previous branch delivered
wall-clock benchmark baseline contracts. That gives agents and reviewers a
safe timing-evidence shape, but it still does not say how reviewed evidence
should be combined into capacity assumptions.

Capacity planning should be useful before live production automation exists. It
should describe the evidence required to reason about storage growth,
benchmark coverage, dashboard and graph concurrency, agent query load,
alerting and rollout handoffs, and load-test fixture planning without claiming
that zigeffect has measured production capacity.

It should answer:

- which upstream contracts must be reviewed before capacity assumptions are
  usable;
- which capacity domains are in scope;
- how storage growth should be modeled from aggregation and NenDB retention
  policy;
- how wall-clock benchmark baselines should feed load-test fixture planning;
- how dashboard, graph, and agent query surfaces affect concurrency
  assumptions;
- what evidence is missing before a plan can be called reviewed;
- what future branch should audit the completed production-hardening sequence.

Mutation authority remains `none`.

## Existing Evidence

The handoff comes from:

- `packages/zigeffect/tools/causal_production_hardening_backlog.zig`, where
  `production-capacity-planning` is the next planned production-hardening item;
- `packages/zigeffect/docs/production-hardening-backlog.md`, which says
  capacity planning should consume reviewed aggregation, retention, benchmark
  baseline, dashboard, graph, agent query, feedback-loop, alerting, and rollout
  evidence;
- `packages/zigeffect/tools/causal_production_artifact_aggregation.zig`, which
  defines source provenance, bundle fields, and downstream consumers before
  capacity planning;
- `packages/zigeffect/tools/causal_durable_production_retention.zig`, which
  defines NenDB-only retention policy, TTL, compaction thresholds, backup, and
  recovery expectations;
- `packages/zigeffect/tools/causal_wall_clock_benchmark_baselines.zig`, which
  defines the timing scenario families, environment metadata, calibration
  policy, and advisory gates for future benchmark observations;
- `packages/zigeffect/tools/causal_live_dashboard_streaming_workbench.zig` and
  the SolidJS workbench files, which define bounded stream frames, visual graph
  adapter posture, and read-only dashboard boundaries;
- `packages/zigeffect/tools/causal_query.zig` and
  `packages/zigeffect/tools/causal_human_agent_feedback_loop.zig`, which define
  bounded agent queries and the human-agent evidence loop;
- `packages/zigeffect/tools/causal_alerting_integrations.zig` and
  `packages/zigeffect/tools/causal_rollout_automation_guardrails.zig`, which
  define alert/rollout handoff evidence without live delivery or rollout
  mutation.

## Design Brief

- Product: schema-governed production capacity planning contract.
- Command: `zig build causal-production-capacity-planning`.
- Schema: `zigeffect.causal.production-capacity-planning.v1`.
- Work mode: local, deterministic, record-only.
- Produces:
  - source evidence matrix;
  - capacity domain model;
  - storage growth assumptions;
  - load-test fixture plan;
  - workbench dashboard and graph concurrency assumptions;
  - agent query and feedback-loop assumptions;
  - alerting and rollout handoff assumptions;
  - readiness gates;
  - negative capacity fixtures;
  - verification commands;
  - production-hardening completion-audit handoff.
- Mutation authority: `none`.

## In Scope

- Add a Zig report tool:

  ```sh
  zig build causal-production-capacity-planning
  zig build causal-production-capacity-planning -- --format json
  ```

- Emit text and JSON reports.
- Register schema `zigeffect.causal.production-capacity-planning.v1`.
- Define required source contracts:
  - `zigeffect.causal.production-artifact-aggregation.v1`;
  - `zigeffect.causal.durable-production-retention.v1`;
  - `zigeffect.causal.wall-clock-benchmark-baselines.v1`;
  - `zigeffect.causal.live-dashboard-streaming-workbench.v1`;
  - `zigeffect.causal.agent-query.v1`;
  - `zigeffect.causal.human-agent-feedback-loop.v1`;
  - `zigeffect.causal.alerting-integrations.v1`;
  - `zigeffect.causal.rollout-automation-guardrails.v1`.
- Define capacity domains:
  - retained artifact storage;
  - benchmark and load-test fixture coverage;
  - request trace and background job trace volume;
  - causal artifact formatting and query costs;
  - dashboard stream windows;
  - visual graph node and edge rendering;
  - agent query and feedback-loop usage;
  - alerting, rollout, and incident handoff volume.
- Define planning formulas as expressions, not production estimates.
- Define readiness gates that make missing evidence explicit.
- Mark production-capacity-planning delivered in the backlog.
- Hand off to `codex/zigeffect-causal-production-hardening-completion-audit`.

## Out Of Scope

- Live production telemetry ingestion.
- Load-test execution.
- Autoscaling, provisioning, or infrastructure mutation.
- Production capacity claims.
- Cost estimates.
- Production dashboard hosting.
- Timing-based CI failure gates.
- Durable writes.
- Non-NenDB durable adapter work.
- Alternate frontend renderer support.
- Source, config, registry, app, deployment, rollout, alert, ticket, paging, or
  production mutation.

## Architecture

This branch follows the existing deterministic report pattern:

```text
artifact aggregation
  + NenDB retention
  + wall-clock benchmark baselines
  + live dashboard stream/workbench
  + graph visualization
  + bounded agent queries
  + human-agent feedback loop
  + alerting and rollout handoffs
  -> production capacity planning contract
  -> production hardening completion audit
```

The capacity planning report does not read generated artifacts, clocks,
machines, networks, CI systems, databases, workbench bundles, or production
systems. It describes the evidence shape that reviewed plans must provide.

The report can include formulas, but formulas are not measurements. For
example, storage growth can be modeled as:

```text
retained_bundles_per_day
  * average_events_per_bundle
  * bytes_per_event_estimate
  * retention_days
  * backup_multiplier
  * compaction_overhead_factor
```

The formula is useful only when the input evidence has reviewed provenance.
When evidence is missing or environment-drifted, the plan should report
`needs-evidence`, not a guessed capacity.

## Output Schema

Schema:

```text
zigeffect.causal.production-capacity-planning.v1
```

Top-level fields:

```json
{
  "schema": "zigeffect.causal.production-capacity-planning.v1",
  "schema_version": 1,
  "producer": "causal-production-capacity-planning",
  "mode": "local-record",
  "applied": false,
  "mutation_authority": "none",
  "source_branch": "codex/zigeffect-causal-production-capacity-planning",
  "source_contracts": [],
  "capacity_domains": [],
  "storage_growth_assumptions": [],
  "load_test_fixture_plan": [],
  "concurrency_assumptions": [],
  "readiness_gates": [],
  "negative_capacity_fixtures": [],
  "agent_guidance": [],
  "verification_commands": [],
  "next_branch": "codex/zigeffect-causal-production-hardening-completion-audit"
}
```

## Record Families

### Source Contract

Purpose: make capacity assumptions traceable to the upstream evidence family
that justifies them.

Required fields:

- `schema`;
- `producer`;
- `evidence_role`;
- `required_for`;
- `missing_evidence_action`;
- `authority_boundary`.

Source contracts should include aggregation, retention, benchmark baselines,
dashboard stream, agent queries, feedback loop, alerting, and rollout
guardrails.

### Capacity Domain

Purpose: define the surface that capacity planning must reason about without
claiming measured capacity.

Initial domains:

- `retained-artifact-storage`;
- `nendb-retention-compaction`;
- `benchmark-observation-coverage`;
- `request-trace-volume`;
- `background-job-trace-volume`;
- `artifact-formatting-and-query`;
- `dashboard-stream-window`;
- `visual-graph-rendering`;
- `agent-query-and-feedback`;
- `alerting-rollout-handoff-volume`.

Required fields:

- `id`;
- `category`;
- `planning_question`;
- `required_evidence`;
- `model_expression`;
- `review_status`;
- `agent_guidance`.

### Storage Growth Assumption

Purpose: describe storage planning inputs for retained causal evidence.

Inputs:

- aggregation bundle source count;
- average events per retained bundle;
- bytes per event estimate;
- redaction/truncation state;
- retention days;
- compaction trigger;
- compaction target;
- backup multiplier;
- recovery evidence requirement.

The report should cite the NenDB retention policy values already defined:

- retention window: `14` days;
- max events per retained bundle: `4096`;
- compaction trigger: `2048`;
- compaction target: `1024`;
- backup required: `true`;
- recovery required: `true`.

The report should not produce a production storage number unless future
reviewed observation artifacts provide the missing variables.

### Load-Test Fixture Plan

Purpose: convert benchmark baseline scenario families into future load-test
fixture requirements.

Fixture families:

- request trace fixture;
- background job trace fixture;
- artifact formatting fixture;
- agent query fixture;
- before/after compare fixture;
- dev-loop package-test fixture;
- SolidJS workbench build fixture;
- CI baseline capture fixture.

Required fields:

- scenario id;
- target capacity question;
- fixture inputs;
- evidence required before execution;
- blocking missing evidence;
- authority boundary.

The fixture plan should prepare future tests, not run them.

### Concurrency Assumption

Purpose: describe user-facing and agent-facing concurrency assumptions before a
production dashboard exists.

Assumption families:

- local workbench opens one selected artifact;
- live dashboard streams are bounded frame windows;
- Visual Graph lazy-loads the Solid G6 adapter;
- graph perspectives are read-only;
- agent query responses are bounded;
- feedback loop clustering remains local and advisory;
- alerting/rollout handoffs remain previews and evidence records.

Concurrency assumptions are planning boundaries, not production SLOs.

### Readiness Gate

Purpose: classify whether a capacity plan is ready for review.

Initial gates:

- `aggregation-provenance-reviewed`;
- `retention-policy-reviewed`;
- `benchmark-baselines-reviewed`;
- `dashboard-boundary-reviewed`;
- `graph-boundary-reviewed`;
- `agent-query-bounds-reviewed`;
- `alert-rollout-handoff-reviewed`;
- `load-test-plan-ready`;
- `capacity-plan-ready-for-review`.

Every gate is advisory. Failing gates produce missing-evidence guidance.

### Negative Capacity Fixture

Purpose: prevent agents from over-claiming.

Blocked fixtures:

- capacity claimed from unreviewed benchmark records;
- storage estimate without aggregation provenance;
- TTL enforcement claimed without capture timestamps;
- dashboard concurrency claimed from local workbench only;
- graph capacity claimed without node/edge fixture evidence;
- production incident volume inferred from alert previews;
- rollout capacity inferred from canary guardrail records;
- autoscaling recommendation without production telemetry and review.

## Agent Use Cases

Agents should use the report to:

- identify missing evidence before capacity review;
- connect benchmark baseline scenarios to future load-test fixtures;
- explain which storage variables are known policy values and which remain
  unknown observations;
- keep dashboard and graph assumptions separate from production hosting claims;
- ask for the next evidence artifact rather than inventing capacity numbers;
- hand off a complete record to the production hardening completion audit.

Agents should not use the report to:

- estimate production capacity from local or CI records alone;
- claim storage size, throughput, concurrency, latency, or cost as measured;
- recommend autoscaling or provisioning;
- fail CI from timing;
- mutate code, infrastructure, deployments, alerts, tickets, rollouts, or
  durable stores.

## Documentation Updates

Add:

- `packages/zigeffect/docs/production-capacity-planning.md`

Update:

- `packages/zigeffect/README.md`;
- `packages/zigeffect/docs/operations.md`;
- `packages/zigeffect/docs/schema-governance.md`;
- `packages/zigeffect/docs/production-hardening-backlog.md`;
- `packages/zigeffect/docs/roadmap.md`;
- `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`.

## Tests And Verification

Focused tests:

```sh
cd packages/zigeffect
zig test tools/causal_production_capacity_planning.zig
zig build causal-production-capacity-planning
zig build causal-production-capacity-planning -- --format json
zig build causal-schema-governance -- --format json
zig build causal-production-hardening-backlog -- --format json
```

Full verification:

```sh
cd packages/zigeffect
zig build examples
zig build test
cd ../..
bun run zigeffect:workbench:test
bun run zigeffect:workbench:typecheck
bun run zigeffect:workbench:build
bun run check
bun run zig:test
git diff --check
```

## Risks And Mitigations

- Risk: agents treat planning formulas as measured capacity.
  - Mitigation: every domain carries `review_status`, required evidence, and
    missing-evidence guidance.
- Risk: storage planning drifts away from NenDB retention policy.
  - Mitigation: cite retention policy constants in tests and docs.
- Risk: workbench local behavior is mistaken for production dashboard hosting.
  - Mitigation: concurrency assumptions explicitly separate local workbench,
    bounded stream, graph rendering, and future production hosting.
- Risk: capacity planning accidentally grants authority to provision or mutate.
  - Mitigation: report includes `applied=false`, `mutation_authority=none`,
    non-goals, and negative capacity fixtures.

## Acceptance Criteria

- `causal-production-capacity-planning` exists as a Zig build step with text and
  JSON output.
- The report emits `zigeffect.causal.production-capacity-planning.v1`.
- The report includes source contracts, capacity domains, storage assumptions,
  load-test fixture plan, concurrency assumptions, readiness gates, negative
  fixtures, agent guidance, verification commands, and next branch.
- Schema governance includes the new schema.
- Production hardening backlog marks capacity planning delivered and recommends
  the production-hardening completion audit branch.
- Docs explain that capacity planning is a record-only model and not a
  production capacity claim.
- Focused and full verification pass.
