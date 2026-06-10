# zigeffect Causal Wall Clock Benchmark Baselines Design

Date: 2026-06-10

## Purpose

This branch adds a record-only wall-clock benchmark baseline contract for
zigeffect production hardening. The existing `causal-performance-budget` report
is deterministic by design: it verifies stable runtime constants and operating
assumptions. It intentionally does not claim request latency, throughput, CI
runner speed, host capacity, or production sizing.

The missing layer is a schema-stable evidence record that lets humans and
agents compare observed local and CI timings without confusing those timings for
hard deterministic budgets. This branch should make benchmark baselines useful
for review and future capacity planning while preserving the current authority
boundary.

It should answer:

- which benchmark scenarios define the initial zigeffect timing surface;
- what environment metadata must travel with every wall-clock record;
- how agents should compare local and CI observations without over-claiming;
- when an observation should trigger review rather than fail CI automatically;
- how benchmark evidence hands off to production capacity planning.

Mutation authority remains `none`.

## Existing Evidence

The handoff comes from:

- `packages/zigeffect/tools/causal_performance_budget.zig`, which emits
  `zigeffect.causal.performance-budget.v1` and explicitly keeps wall-clock
  latency gates out of the deterministic budget;
- `packages/zigeffect/docs/performance-budget.md`, which documents stable
  retention, string-bound, sampling, backend, workbench, and CI artifact
  budgets;
- `packages/zigeffect/tools/causal_production_hardening_backlog.zig`, which
  names `wall-clock-benchmark-baselines` as the next planned production
  hardening item;
- `packages/zigeffect/docs/production-hardening-backlog.md`, which says this
  branch should add local and CI wall-clock benchmark baselines to complement
  deterministic performance budget constants;
- `.github/workflows/zigeffect-causal.yml`, which already captures PR base
  causal artifacts before running current-branch checks;
- `docs/roachgraph/performance-baseline.md`, which provides a useful pattern
  for recording baseline inventory separately from optimization claims;
- `packages/zigeffect/docs/production-artifact-aggregation.md`, which names
  benchmarks and capacity planning as future consumers of aggregated evidence.

## Design Brief

- Product: schema-governed wall-clock benchmark baseline evidence for
  zigeffect.
- Command: `zig build causal-wall-clock-benchmark-baselines`.
- Schema: `zigeffect.causal.wall-clock-benchmark-baselines.v1`.
- Work mode: local, deterministic report of benchmark definitions and review
  policy; no live timing collection in the report tool.
- Produces:
  - benchmark scenario catalog;
  - baseline record contract for local and CI observations;
  - environment capture requirements;
  - noise and calibration policy;
  - review thresholds;
  - agent comparison guidance;
  - capacity-planning handoff.
- Consumes:
  - `zigeffect.causal.performance-budget.v1`;
  - existing causal CI artifacts when available;
  - future benchmark observation artifacts produced by separate harnesses.
- Mutation authority: `none`.

## In Scope

- Add a Zig report tool:

  ```sh
  zig build causal-wall-clock-benchmark-baselines
  zig build causal-wall-clock-benchmark-baselines -- --format json
  ```

- Emit text and JSON reports.
- Register the schema in schema governance.
- Document the relationship between deterministic performance budgets and
  observed wall-clock baselines.
- Define initial benchmark scenario families:
  - app request trace recording;
  - background job trace recording;
  - causal artifact formatting and query;
  - causal compare and dev-loop artifact generation;
  - SolidJS workbench build and test boundaries;
  - CI causal artifact capture overhead.
- Define baseline record fields for local developer machines and CI runners.
- Define minimum environment metadata:
  - runner class;
  - operating system;
  - CPU architecture;
  - Zig version;
  - Bun version where relevant;
  - build optimize mode;
  - iteration count;
  - warmup count;
  - timestamp or externally supplied observation id for future dynamic records.
- Define calibration guidance:
  - warmups before measured iterations;
  - median, p95, min, and max summaries;
  - sample count disclosure;
  - local-vs-CI separation;
  - comparison only against the same scenario family and compatible
    environment class.
- Define review gates that produce advisory status only:
  - `record-only`;
  - `needs-more-samples`;
  - `review-regression`;
  - `review-environment-drift`;
  - `ready-for-capacity-planning`.
- Update production-hardening backlog status and handoff to
  `codex/zigeffect-causal-production-capacity-planning`.

## Out Of Scope

- Live production benchmarking.
- Automatic CI failure gates from wall-clock timing.
- Network calls or external service probes.
- Load testing.
- Capacity sizing or production cost estimates.
- Durable writes.
- Non-NenDB durable adapter work.
- Deployment, rollout, source, config, app, registry, or production mutation.
- Workbench runtime mutation.
- Alternate frontend renderer support.

## Architecture

This branch adds a static contract report, not a timing runner:

```text
deterministic performance budget
  + causal CI artifact capture pattern
  + production hardening backlog
  + scenario catalog
  -> wall-clock benchmark baseline contract
  -> future benchmark observation harness
  -> future production capacity planning
```

The command should be stable in local development and CI. It should not inspect
clocks, run timed loops, read the host environment, or make the current machine
part of the report. Instead it defines the artifact shape that future dynamic
harnesses can write and that agents can consume.

That separation matters. A CI runner can be noisy, throttled, or moved to a
different host class without any zigeffect runtime change. Local laptops vary
even more. The wall-clock baseline contract therefore records evidence and
review guidance; it does not enforce performance promises.

## Output Schema

Schema:

```text
zigeffect.causal.wall-clock-benchmark-baselines.v1
```

Top-level fields:

```json
{
  "schema": "zigeffect.causal.wall-clock-benchmark-baselines.v1",
  "schema_version": 1,
  "producer": "causal-wall-clock-benchmark-baselines",
  "mode": "local-record",
  "applied": false,
  "mutation_authority": "none",
  "source_branch": "codex/zigeffect-causal-wall-clock-benchmark-baselines",
  "source_contracts": [],
  "scenario_families": [],
  "baseline_record_contract": [],
  "environment_fields": [],
  "calibration_policy": [],
  "review_gates": [],
  "agent_guidance": [],
  "verification_commands": [],
  "next_branch": "codex/zigeffect-causal-production-capacity-planning"
}
```

## Record Families

### Scenario Family

Purpose: name the benchmark surfaces that should be measured consistently once
a dynamic harness exists.

Initial scenarios:

- `app-request-trace`: records bounded request-path causal events with app
  semantic fields and redaction metadata;
- `background-job-trace`: records larger bounded background-job traces with
  retained event and drop metadata;
- `causal-artifact-formatting`: formats text, JSON, and DOT artifacts from
  representative retained traces;
- `causal-query-agent-slices`: runs bounded agent query shapes such as
  summarize, find failures, explain event, trace cause, and trace data;
- `causal-compare-before-after`: compares baseline and after artifacts for
  regression review;
- `causal-dev-loop-package-tests`: produces before/after development-loop
  artifacts around package tests;
- `workbench-solid-build`: measures SolidJS workbench build/test boundaries
  separately from Zig runtime scenarios;
- `ci-baseline-capture`: records the overhead of PR base causal artifact
  capture separately from current-branch checks.

Required fields:

- `id`;
- `category`;
- `description`;
- `command`;
- `measurement_kind`;
- `baseline_scope`;
- `primary_metric`;
- `secondary_metrics`;
- `agent_guidance`.

### Baseline Record Contract

Purpose: define the shape of a future observation without collecting one in the
static report.

Required fields:

- `scenario_id`;
- `baseline_id`;
- `environment_class`;
- `runner_class`;
- `optimize_mode`;
- `warmup_iterations`;
- `measured_iterations`;
- `median_ms`;
- `p95_ms`;
- `min_ms`;
- `max_ms`;
- `stddev_ms` when available;
- `artifact_refs`;
- `source_commit`;
- `observed_at`;
- `measurement_notes`;
- `redaction_review`;
- `schema_ref`.

Agent guidance:

- compare only records with the same `scenario_id`;
- prefer CI-to-CI and local-to-local comparisons;
- call out environment drift before calling out runtime regression;
- treat missing sample counts or missing environment metadata as
  `needs-more-samples`;
- cite artifact refs and command refs in every benchmark finding.

### Environment Field

Purpose: make wall-clock observations explainable before humans or agents draw
conclusions.

Required environment metadata:

- `machine_class`;
- `runner_class`;
- `os_name`;
- `os_version`;
- `cpu_arch`;
- `cpu_model` when safely available;
- `cpu_count`;
- `memory_class` when safely available;
- `zig_version`;
- `bun_version` for workbench and package-level commands;
- `shell`;
- `optimize_mode`;
- `thermal_or_load_notes` for local observations;
- `ci_provider`;
- `ci_runner_image`;
- `ci_run_id`.

Privacy guidance: environment metadata must not include usernames, hostnames,
home directories, secrets, tokens, full environment dumps, or raw process
lists.

### Calibration Policy

Purpose: prevent noisy measurements from being converted into false
regressions.

Policy:

- run warmups before measured iterations;
- record at least five measured iterations for local exploratory records;
- record at least ten measured iterations before a CI baseline is treated as
  reviewable;
- report median and p95 rather than a single elapsed time;
- keep command output artifacts separate from timing metadata;
- store failed benchmark commands as causal findings, not missing data;
- compare against the most recent compatible baseline and the last reviewed
  baseline;
- require human review before any timing delta is called release-blocking.

### Review Gate

Purpose: convert timing observations into advisory next steps.

Initial gates:

- `record-only`: default state for all observations;
- `needs-more-samples`: sample count, environment metadata, or artifact refs are
  incomplete;
- `review-regression`: median or p95 changes exceed the configured advisory
  threshold for compatible records;
- `review-environment-drift`: runner, OS, compiler, package manager, or
  optimize mode changed;
- `ready-for-capacity-planning`: reviewed baseline records exist for the core
  request, job, artifact, query, compare, CI capture, and workbench boundaries.

No gate can mutate source, CI policy, deployment state, rollout state, registry
state, or production state.

## Threshold Policy

The first version should define advisory thresholds, not enforcement gates.

Recommended defaults:

- median regression review threshold: `15%`;
- p95 regression review threshold: `25%`;
- absolute minimum review floor: `5ms`, so tiny measurements do not create
  noisy percentage-only findings;
- CI environment drift: always review before comparison;
- local environment drift: warn and keep the record, but do not compare it as a
  regression baseline.

The thresholds belong in the report as policy text and JSON fields. A future
dynamic harness may make them configurable after enough evidence exists.

## Agent Use Cases

Agents should use the report to:

- discover which scenario families need benchmark evidence;
- decide whether an observed timing artifact is comparable to a baseline;
- explain why a possible regression is noisy, incomplete, or reviewable;
- recommend the next query or benchmark record to collect;
- separate deterministic runtime budget drift from wall-clock observation drift;
- hand reviewed timing evidence to production capacity planning.

Agents should not use the report to:

- fail CI automatically;
- claim production capacity;
- compare unrelated machines or optimize modes;
- hide missing sample counts;
- infer raw system details from environment metadata;
- mutate source or deployment systems.

## CI Integration

The existing CI workflow already captures PR base causal artifacts. This branch
should document a future CI baseline capture step but should not make timing
failures block CI.

The eventual CI flow should look like:

```text
checkout PR base
  -> run deterministic causal artifact baseline capture
  -> run wall-clock benchmark observation capture
  -> checkout PR head
  -> run current deterministic checks
  -> run current wall-clock benchmark observation capture
  -> emit advisory comparison artifact
  -> upload artifacts on failure or explicit benchmark workflow
```

This branch may add the command to the workflow documentation and verification
suite. If the workflow itself is updated, it should only print or archive the
static baseline contract and must not introduce timing-dependent required
checks.

## Documentation Updates

Add:

- `packages/zigeffect/docs/wall-clock-benchmark-baselines.md`

Update:

- `packages/zigeffect/docs/performance-budget.md`;
- `packages/zigeffect/docs/schema-governance.md`;
- `packages/zigeffect/docs/operations.md`;
- `packages/zigeffect/docs/production-hardening-backlog.md`;
- `packages/zigeffect/docs/roadmap.md`;
- `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`.

The docs should repeat the central rule: deterministic budgets verify stable
runtime constants; wall-clock baselines record noisy observations for review.

## Tests And Verification

Focused tests:

```sh
cd packages/zigeffect
zig test tools/causal_wall_clock_benchmark_baselines.zig
zig build causal-wall-clock-benchmark-baselines
zig build causal-wall-clock-benchmark-baselines -- --format json
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

- Risk: agents treat wall-clock data as deterministic.
  - Mitigation: schema, docs, review gates, and JSON fields distinguish
    deterministic budget checks from observed timings.
- Risk: CI becomes flaky if timings become required checks too early.
  - Mitigation: this branch emits a contract only and makes all timing gates
    advisory.
- Risk: local environment metadata leaks sensitive details.
  - Mitigation: environment fields are curated and explicitly exclude usernames,
    hostnames, full paths, secrets, and environment dumps.
- Risk: capacity planning starts from insufficient data.
  - Mitigation: the `ready-for-capacity-planning` gate requires reviewed
    baseline records across the core scenario families.

## Acceptance Criteria

- `causal-wall-clock-benchmark-baselines` exists as a Zig build step with text
  and JSON output.
- The report emits
  `zigeffect.causal.wall-clock-benchmark-baselines.v1`.
- The report includes scenario families, baseline record fields, environment
  fields, calibration policy, review gates, agent guidance, verification
  commands, and the next branch.
- Schema governance includes the new schema.
- Production hardening backlog marks the item delivered and recommends
  `codex/zigeffect-causal-production-capacity-planning`.
- Docs explain how the report complements `causal-performance-budget`.
- Tests and the full verification suite pass.
