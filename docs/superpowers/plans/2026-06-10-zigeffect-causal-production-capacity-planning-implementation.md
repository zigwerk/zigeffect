# zigeffect Causal Production Capacity Planning Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a schema-governed, record-only production capacity planning contract that combines reviewed aggregation, NenDB retention, wall-clock benchmark baseline, dashboard/workbench, graph, agent query, feedback-loop, alerting, and rollout evidence into explicit planning assumptions without claiming measured production capacity.

**Architecture:** Implement a small Zig report tool with text and JSON output. The report defines source evidence, capacity domains, storage growth assumptions, load-test fixture plans, concurrency assumptions, readiness gates, negative capacity fixtures, agent guidance, and the next production-hardening completion-audit branch. It does not run load tests, collect live telemetry, provision infrastructure, mutate systems, or estimate capacity from missing evidence.

**Tech Stack:** Zig 0.16 build steps and tests, existing zigeffect causal tool patterns, Markdown docs, Bun verification commands, SolidJS workbench docs hosted by `webui-dev/zig-webui`, NenDB-only durable retention direction.

---

## Files And Responsibilities

- Create `packages/zigeffect/tools/causal_production_capacity_planning.zig`
  - Owns `zigeffect.causal.production-capacity-planning.v1`.
  - Provides text and JSON report formatting.
  - Exposes static records for source contracts, capacity domains, storage
    assumptions, load-test fixture plan, concurrency assumptions, readiness
    gates, negative capacity fixtures, agent guidance, non-goals, and
    verification commands.
  - Tests option parsing, schema metadata, source contract coverage, capacity
    domain coverage, retention constants, readiness gates, negative fixtures,
    text output, JSON output, and mutation-authority boundaries.

- Modify `packages/zigeffect/build.zig`
  - Adds `causal-production-capacity-planning` executable step.
  - Adds tool tests to `zig build test`.

- Modify `packages/zigeffect/tools/causal_schema_governance.zig`
  - Registers `zigeffect.causal.production-capacity-planning.v1`.
  - Updates schema-count expectations from `47` to `48`.
  - Adds representative test expectations.

- Modify `packages/zigeffect/tools/causal_production_hardening_backlog.zig`
  - Marks `production-capacity-planning` delivered.
  - Updates recommendation to `start-production-hardening-completion-audit`.
  - Updates recommended next branch to
    `codex/zigeffect-causal-production-hardening-completion-audit`.
  - Adds the new tool and docs to evidence sources.
  - Adds the new command to verification commands.

- Create `packages/zigeffect/docs/production-capacity-planning.md`
  - Documents command usage, schema, source contracts, capacity domains, storage
    assumptions, load-test fixture plan, concurrency assumptions, readiness
    gates, negative fixtures, agent guidance, and completion-audit handoff.

- Modify `packages/zigeffect/README.md`
  - Adds the new command near production-hardening and wall-clock baseline
    reports.

- Modify `packages/zigeffect/docs/operations.md`
  - Adds the command to the local/CI operating model.
  - Adds a capacity-planning section.

- Modify `packages/zigeffect/docs/schema-governance.md`
  - Adds the official schema entry.

- Modify `packages/zigeffect/docs/production-hardening-backlog.md`
  - Marks capacity planning delivered.
  - Updates next branch and verification suite.

- Modify `packages/zigeffect/docs/roadmap.md`
  - Records delivery and next branch.

- Modify `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`
  - Marks the capacity-planning branch delivered.
  - Names production-hardening completion audit as the current next branch.

## TDD Strategy

The useful red/green loop is:

1. create the tool file with tests describing the target schema, inventories,
   authority boundaries, retention constants, and formatters;
2. run `zig test tools/causal_production_capacity_planning.zig` and observe
   expected failures from empty inventories and stub formatters;
3. implement records and text/JSON formatters;
4. add build integration and run the command;
5. register schema governance and backlog tests;
6. update docs;
7. run focused and full verification.

## Task 1: Add Failing Tool Tests

**Files:**

- Create `packages/zigeffect/tools/causal_production_capacity_planning.zig`

- [ ] Add schema constants:
  - `production_capacity_planning_schema`;
  - `production_capacity_planning_schema_version`;
  - `source_branch`;
  - `next_branch`.

- [ ] Add type declarations for:
  - `SourceContract`;
  - `CapacityDomain`;
  - `StorageGrowthAssumption`;
  - `LoadTestFixture`;
  - `ConcurrencyAssumption`;
  - `ReadinessGate`;
  - `NegativeCapacityFixture`;
  - `AgentGuidance`.

- [ ] Add stub inventory functions returning empty slices.

- [ ] Add stub formatting functions returning `error.ExpectedRedFailure`.

- [ ] Add tests that should fail until implementation exists:
  - usage names `causal-production-capacity-planning` and `--format text|json`;
  - schema metadata matches
    `zigeffect.causal.production-capacity-planning.v1`;
  - source contracts include aggregation, durable retention, wall-clock
    baselines, dashboard stream, agent query, human-agent feedback, alerting,
    and rollout guardrails;
  - capacity domains include retained storage, retention compaction, benchmark
    coverage, request/job traces, artifact/query cost, dashboard stream, graph
    rendering, agent feedback, and alert/rollout handoff;
  - storage assumptions cite `retention_days=14`,
    `max_events_per_bundle=4096`, `compaction_trigger_events=2048`,
    `compact_to_events=1024`, backup required, and recovery required;
  - readiness gates include all evidence-review gates and
    `capacity-plan-ready-for-review`;
  - negative fixtures block capacity claims from weak evidence;
  - text output includes record-only capacity planning language;
  - JSON output includes `applied=false`, `mutation_authority="none"`, source
    contracts, readiness gates, and next branch;
  - option parsing rejects unknown formats and flags.

- [ ] Run expected red:

  ```sh
  cd packages/zigeffect
  zig test tools/causal_production_capacity_planning.zig
  ```

## Task 2: Implement The Static Report

**Files:**

- Modify `packages/zigeffect/tools/causal_production_capacity_planning.zig`

- [ ] Fill source contracts:
  - `production-artifact-aggregation`;
  - `durable-production-retention`;
  - `wall-clock-benchmark-baselines`;
  - `live-dashboard-stream`;
  - `agent-query`;
  - `human-agent-feedback-loop`;
  - `alerting-integrations`;
  - `rollout-automation-guardrails`.

- [ ] Fill capacity domains:
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

- [ ] Fill storage growth assumptions:
  - known NenDB retention policy values;
  - formula-only fields for retained bundle count, average events, bytes per
    event, backup multiplier, and compaction overhead;
  - missing evidence action.

- [ ] Fill load-test fixture plan from the eight wall-clock scenario families.

- [ ] Fill concurrency assumptions for local workbench, stream windows, visual
  graph, agent queries, feedback clusters, and alert/rollout previews.

- [ ] Fill readiness gates.

- [ ] Fill negative capacity fixtures.

- [ ] Fill agent guidance and non-goals.

- [ ] Implement text formatter.

- [ ] Implement JSON formatter with safe JSON string escaping and booleans.

- [ ] Implement option parsing and `main`.

- [ ] Run:

  ```sh
  cd packages/zigeffect
  zig test tools/causal_production_capacity_planning.zig
  ```

## Task 3: Add Build Integration

**Files:**

- Modify `packages/zigeffect/build.zig`

- [ ] Add module for
  `tools/causal_production_capacity_planning.zig`.

- [ ] Add executable named
  `zigeffect-causal-production-capacity-planning`.

- [ ] Add build step:

  ```sh
  zig build causal-production-capacity-planning
  ```

- [ ] Add tool tests to `zig build test`.

- [ ] Run:

  ```sh
  cd packages/zigeffect
  zig build causal-production-capacity-planning
  zig build causal-production-capacity-planning -- --format json
  zig build test
  ```

## Task 4: Register Schema Governance

**Files:**

- Modify `packages/zigeffect/tools/causal_schema_governance.zig`
- Modify `packages/zigeffect/docs/schema-governance.md`

- [ ] Add schema entry:

  ```text
  zigeffect.causal.production-capacity-planning.v1
  ```

- [ ] Category: `production-hardening`.

- [ ] Emitted by:
  `causal-production-capacity-planning`.

- [ ] Consumed by:
  - agents;
  - reviewers;
  - production-hardening completion audit;
  - future load-test harnesses;
  - future production planning.

- [ ] Compatibility:
  - `strict-v1`;
  - `record-only`;
  - `mutation-authority-none`;
  - `planning-only`.

- [ ] Update schema count expectations.

- [ ] Run:

  ```sh
  cd packages/zigeffect
  zig build causal-schema-governance
  zig build causal-schema-governance -- --format json
  ```

## Task 5: Update Backlog And Roadmap Handoff

**Files:**

- Modify `packages/zigeffect/tools/causal_production_hardening_backlog.zig`
- Modify `packages/zigeffect/docs/production-hardening-backlog.md`
- Modify `packages/zigeffect/docs/roadmap.md`
- Modify `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`

- [ ] Change backlog recommendation to
  `start-production-hardening-completion-audit`.

- [ ] Change recommended next branch to
  `codex/zigeffect-causal-production-hardening-completion-audit`.

- [ ] Mark `production-capacity-planning` delivered.

- [ ] Expand evidence sources to include the new design, plan, tool, and docs.

- [ ] Add the new command to verification suites.

- [ ] Update immediate branch queue:
  - capacity planning delivered;
  - production hardening completion audit is current next branch.

- [ ] Run:

  ```sh
  cd packages/zigeffect
  zig build causal-production-hardening-backlog
  zig build causal-production-hardening-backlog -- --format json
  ```

## Task 6: Add User-Facing Docs

**Files:**

- Create `packages/zigeffect/docs/production-capacity-planning.md`
- Modify `packages/zigeffect/README.md`
- Modify `packages/zigeffect/docs/operations.md`

- [ ] Document command usage and schema.

- [ ] Explain that the report is a model and readiness contract, not a capacity
  claim.

- [ ] Document source contracts.

- [ ] Document capacity domains.

- [ ] Document storage growth assumptions and known retention constants.

- [ ] Document load-test fixture plan.

- [ ] Document concurrency assumptions.

- [ ] Document readiness gates and negative fixtures.

- [ ] Link to the production-hardening completion-audit handoff.

## Task 7: Focused Verification

- [ ] Run:

  ```sh
  cd packages/zigeffect
  zig test tools/causal_production_capacity_planning.zig
  zig build causal-production-capacity-planning
  zig build causal-production-capacity-planning -- --format json
  zig build causal-schema-governance -- --format json
  zig build causal-production-hardening-backlog -- --format json
  git diff --check
  ```

- [ ] Inspect generated text and JSON enough to confirm:
  - schema and schema version;
  - applied false;
  - mutation authority none;
  - source contracts;
  - capacity domains;
  - readiness gates;
  - negative fixtures;
  - next branch.

## Task 8: Full Verification

- [ ] Run:

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

- [ ] If any verification fails, use the systematic debugging flow.

## Task 9: Commit Implementation

- [ ] Confirm unrelated dirty files remain unstaged:
  - `docs/superpowers/specs/2026-06-09-zigeffect-causal-production-hardening-backlog-design.md`;
  - `docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md`.

- [ ] Stage only files touched for this milestone.

- [ ] Commit:

  ```sh
  git commit -m "feat(zigeffect): add production capacity planning contract"
  ```

## Acceptance Criteria

- Design and implementation plan are committed separately.
- `causal-production-capacity-planning` exists and emits text and JSON.
- JSON uses schema `zigeffect.causal.production-capacity-planning.v1`.
- Report remains record-only with `applied=false` and
  `mutation_authority="none"`.
- Schema governance includes the new schema.
- Production hardening backlog recommends the completion-audit branch next.
- Docs explain how agents should use the plan without treating it as measured
  capacity.
- Focused and full verification commands pass, or any remaining failure is
  clearly reported with evidence.
