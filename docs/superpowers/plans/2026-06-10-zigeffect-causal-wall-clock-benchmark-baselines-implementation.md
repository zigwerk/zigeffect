# zigeffect Causal Wall Clock Benchmark Baselines Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a schema-governed, record-only wall-clock benchmark baseline contract that complements the deterministic `causal-performance-budget` report and hands off to production capacity planning.

**Architecture:** Implement a small Zig report tool with text and JSON output. The report defines benchmark scenario families, future baseline observation fields, environment metadata, calibration policy, advisory review gates, and agent guidance. It does not collect timings, inspect clocks, fail CI, or claim production capacity. Register the schema, update docs, mark the backlog item delivered, and point the next branch at capacity planning.

**Tech Stack:** Zig 0.16 build steps and tests, existing zigeffect causal tool patterns, Markdown docs, Bun verification commands, SolidJS workbench docs hosted by `webui-dev/zig-webui`.

---

## Files And Responsibilities

- Create `packages/zigeffect/tools/causal_wall_clock_benchmark_baselines.zig`
  - Owns `zigeffect.causal.wall-clock-benchmark-baselines.v1`.
  - Provides text and JSON report formatting.
  - Exposes static records for scenario families, baseline record fields,
    environment fields, calibration policy, review gates, agent guidance,
    non-goals, and verification commands.
  - Tests option parsing, schema metadata, inventory coverage, advisory gates,
    text output, JSON output, and mutation-authority boundaries.

- Modify `packages/zigeffect/build.zig`
  - Adds the `causal-wall-clock-benchmark-baselines` executable step.
  - Adds tool tests to `zig build test`.

- Modify `packages/zigeffect/tools/causal_schema_governance.zig`
  - Registers the new wall-clock baseline schema.
  - Updates schema-count expectations.
  - Adds representative test expectations.

- Modify `packages/zigeffect/tools/causal_production_hardening_backlog.zig`
  - Marks `wall-clock-benchmark-baselines` delivered.
  - Updates recommendation to `start-production-capacity-planning`.
  - Updates recommended next branch to
    `codex/zigeffect-causal-production-capacity-planning`.
  - Adds the new tool and docs to evidence sources.
  - Adds the new build step to verification commands.

- Create `packages/zigeffect/docs/wall-clock-benchmark-baselines.md`
  - Documents command usage, schema, scenario families, environment fields,
    calibration policy, advisory gates, agent use cases, and capacity-planning
    handoff.

- Modify `packages/zigeffect/docs/performance-budget.md`
  - Explains how deterministic budgets and wall-clock baselines differ.
  - Links the new command.

- Modify `packages/zigeffect/docs/schema-governance.md`
  - Adds the official schema entry.

- Modify `packages/zigeffect/docs/operations.md`
  - Adds the new command to the local/CI operating model.
  - Notes that timing records are advisory and record-only.

- Modify `packages/zigeffect/docs/production-hardening-backlog.md`
  - Marks the wall-clock item delivered.
  - Updates next branch and verification suite.

- Modify `packages/zigeffect/docs/roadmap.md`
  - Records delivery and next branch.

- Modify `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`
  - Marks the immediate branch delivered.
  - Names production capacity planning as the next active branch.

## TDD Strategy

The tool is a static contract report. The useful red/green loop is:

1. create the tool file with tests that reference the target schema, public
   inventories, and formatting functions;
2. run `zig test tools/causal_wall_clock_benchmark_baselines.zig` and observe
   expected failures;
3. implement the records and formatters;
4. add the build step and integrate into `zig build test`;
5. update schema governance and backlog with tests protecting the new schema
   and handoff;
6. update docs and run the focused plus full verification suite.

## Task 1: Add Failing Tool Tests

**Files:**

- Create `packages/zigeffect/tools/causal_wall_clock_benchmark_baselines.zig`

- [ ] Add schema constants:
  - `wall_clock_benchmark_baselines_schema`;
  - `wall_clock_benchmark_baselines_schema_version`;
  - `source_branch`;
  - `next_branch`.

- [ ] Add type declarations for:
  - `ScenarioFamily`;
  - `BaselineRecordField`;
  - `EnvironmentField`;
  - `CalibrationPolicy`;
  - `ReviewGate`;
  - `AgentGuidance`.

- [ ] Add stub inventory functions returning empty slices:
  - `scenarioFamilies`;
  - `baselineRecordFields`;
  - `environmentFields`;
  - `calibrationPolicy`;
  - `reviewGates`;
  - `agentGuidance`;
  - `nonGoals`;
  - `verificationCommands`.

- [ ] Add stub formatting functions that return `error.ExpectedRedFailure`.

- [ ] Add tests that should fail until implementation exists:
  - usage names `causal-wall-clock-benchmark-baselines` and `--format text|json`;
  - schema metadata matches
    `zigeffect.causal.wall-clock-benchmark-baselines.v1`;
  - scenario families include request, job, artifact, query, compare,
    dev-loop, workbench, and CI capture scenarios;
  - baseline record fields include median, p95, sample count, environment class,
    artifact refs, and source commit;
  - environment fields exclude unsafe raw environment dumps and include Zig and
    Bun version fields;
  - review gates include `record-only`, `needs-more-samples`,
    `review-regression`, `review-environment-drift`, and
    `ready-for-capacity-planning`;
  - text output includes deterministic-vs-wall-clock guidance;
  - JSON output includes `applied=false`, `mutation_authority="none"`, and the
    next branch;
  - option parsing rejects unknown formats and flags.

- [ ] Run the expected red command:

  ```sh
  cd packages/zigeffect
  zig test tools/causal_wall_clock_benchmark_baselines.zig
  ```

## Task 2: Implement The Static Report

**Files:**

- Modify `packages/zigeffect/tools/causal_wall_clock_benchmark_baselines.zig`

- [ ] Fill scenario family records:
  - `app-request-trace`;
  - `background-job-trace`;
  - `causal-artifact-formatting`;
  - `causal-query-agent-slices`;
  - `causal-compare-before-after`;
  - `causal-dev-loop-package-tests`;
  - `workbench-solid-build`;
  - `ci-baseline-capture`.

- [ ] Fill baseline record field records:
  - scenario and baseline ids;
  - environment class;
  - runner class;
  - optimize mode;
  - warmups and measured iterations;
  - median, p95, min, max, and optional stddev;
  - artifact refs;
  - source commit;
  - observed-at marker;
  - measurement notes;
  - redaction review;
  - schema ref.

- [ ] Fill environment field records:
  - machine and runner class;
  - OS and CPU fields;
  - Zig version;
  - Bun version where relevant;
  - optimize mode;
  - CI provider, runner image, and run id;
  - safe local load notes.

- [ ] Fill calibration policy records:
  - warmups;
  - local sample minimum;
  - CI sample minimum;
  - median and p95 reporting;
  - environment-compatible comparison;
  - failed command handling;
  - human review before release-blocking claims.

- [ ] Fill review gate records:
  - `record-only`;
  - `needs-more-samples`;
  - `review-regression`;
  - `review-environment-drift`;
  - `ready-for-capacity-planning`.

- [ ] Fill agent guidance and non-goals.

- [ ] Implement text formatter.

- [ ] Implement JSON formatter with safe JSON string escaping and boolean
  output.

- [ ] Implement option parsing and `main`.

- [ ] Run:

  ```sh
  cd packages/zigeffect
  zig test tools/causal_wall_clock_benchmark_baselines.zig
  ```

## Task 3: Add Build Integration

**Files:**

- Modify `packages/zigeffect/build.zig`

- [ ] Add module for
  `tools/causal_wall_clock_benchmark_baselines.zig`.

- [ ] Add executable named
  `zigeffect-causal-wall-clock-benchmark-baselines`.

- [ ] Add build step:

  ```sh
  zig build causal-wall-clock-benchmark-baselines
  ```

- [ ] Add tool tests to `zig build test`.

- [ ] Run:

  ```sh
  cd packages/zigeffect
  zig build causal-wall-clock-benchmark-baselines
  zig build causal-wall-clock-benchmark-baselines -- --format json
  zig build test
  ```

## Task 4: Register Schema Governance

**Files:**

- Modify `packages/zigeffect/tools/causal_schema_governance.zig`
- Modify `packages/zigeffect/docs/schema-governance.md`

- [ ] Add schema entry:

  ```text
  zigeffect.causal.wall-clock-benchmark-baselines.v1
  ```

- [ ] Category: `production-hardening`.

- [ ] Emitted by:
  `causal-wall-clock-benchmark-baselines`.

- [ ] Consumed by:
  - agents;
  - reviewers;
  - future benchmark observation harness;
  - future production capacity planning.

- [ ] Compatibility:
  - `strict-v1`;
  - `record-only`;
  - `mutation-authority-none`;
  - `advisory-wall-clock`.

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
  `start-production-capacity-planning`.

- [ ] Change recommended next branch to
  `codex/zigeffect-causal-production-capacity-planning`.

- [ ] Mark `wall-clock-benchmark-baselines` delivered.

- [ ] Expand evidence sources to include the new design, plan, tool, and docs.

- [ ] Add the new command to verification suites.

- [ ] Update immediate branch queue:
  - wall-clock branch delivered;
  - capacity planning is current next branch.

- [ ] Run:

  ```sh
  cd packages/zigeffect
  zig build causal-production-hardening-backlog
  zig build causal-production-hardening-backlog -- --format json
  ```

## Task 6: Add User-Facing Docs

**Files:**

- Create `packages/zigeffect/docs/wall-clock-benchmark-baselines.md`
- Modify `packages/zigeffect/docs/performance-budget.md`
- Modify `packages/zigeffect/docs/operations.md`

- [ ] Document command usage and schema.

- [ ] Explain deterministic budget vs wall-clock baseline separation.

- [ ] Document scenario families.

- [ ] Document baseline record fields and environment metadata.

- [ ] Document calibration policy and thresholds.

- [ ] Document review gates and agent guidance.

- [ ] Document the future CI observation flow as advisory only.

- [ ] Link to production capacity planning as the next branch.

## Task 7: Focused Verification

- [ ] Run:

  ```sh
  cd packages/zigeffect
  zig test tools/causal_wall_clock_benchmark_baselines.zig
  zig build causal-wall-clock-benchmark-baselines
  zig build causal-wall-clock-benchmark-baselines -- --format json
  zig build causal-schema-governance -- --format json
  zig build causal-production-hardening-backlog -- --format json
  git diff --check
  ```

- [ ] Inspect generated text and JSON enough to confirm:
  - schema and schema version;
  - applied false;
  - mutation authority none;
  - deterministic-vs-wall-clock separation;
  - all scenario families;
  - all review gates;
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

- [ ] If any verification fails, use the systematic debugging flow:
  reproduce, inspect, form one hypothesis, make the smallest fix, and rerun the
  failed command.

## Task 9: Commit Implementation

- [ ] Confirm unrelated dirty files remain unstaged:
  - `docs/superpowers/specs/2026-06-09-zigeffect-causal-production-hardening-backlog-design.md`;
  - `docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md`.

- [ ] Stage only files touched for this milestone.

- [ ] Commit:

  ```sh
  git commit -m "feat(zigeffect): add wall clock benchmark baselines contract"
  ```

## Acceptance Criteria

- Design and implementation plan are committed separately.
- `causal-wall-clock-benchmark-baselines` exists and emits text and JSON.
- JSON uses schema `zigeffect.causal.wall-clock-benchmark-baselines.v1`.
- Report remains record-only with `applied=false` and
  `mutation_authority="none"`.
- Schema governance includes the new schema.
- Production hardening backlog recommends production capacity planning next.
- Docs explain how agents should use benchmark evidence without treating it as
  deterministic budget proof.
- Focused and full verification commands pass, or any remaining failure is
  clearly reported with evidence.
