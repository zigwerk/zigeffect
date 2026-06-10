# zigeffect Causal Wall Clock Benchmark Baselines

`causal-wall-clock-benchmark-baselines` is the record-only contract for local
and CI wall-clock benchmark evidence. It complements
`causal-performance-budget`, which remains the deterministic report for stable
runtime constants and operating assumptions.

This command does not run a benchmark. It defines the schema, scenario
families, environment metadata, calibration policy, advisory review gates, and
agent guidance that future benchmark observation harnesses must follow.

## Command

```sh
cd packages/zigeffect
zig build causal-wall-clock-benchmark-baselines
zig build causal-wall-clock-benchmark-baselines -- --format json
```

The default text report is for maintainers. The JSON report uses schema
`zigeffect.causal.wall-clock-benchmark-baselines.v1` and is the agent-readable
contract.

## Relationship To Performance Budget

Use `causal-performance-budget` for deterministic checks:

- retained event count defaults;
- event string bounds;
- sampling posture;
- artifact size limits;
- backend sink failure posture;
- CI artifact upload and retention policy;
- workbench host and renderer direction.

Use `causal-wall-clock-benchmark-baselines` for noisy observation contracts:

- what timing scenarios should be measured;
- what metadata makes an observation comparable;
- what sample counts and warmups are required;
- what deltas require review;
- how benchmark evidence feeds the production capacity planning contract.

Do not use wall-clock baselines as automatic CI failure gates. Wall-clock
observations are advisory until reviewed by a human.

## Scenario Families

Initial scenario families:

- `app-request-trace`: bounded app request causal trace recording.
- `background-job-trace`: larger bounded background-job trace recording.
- `causal-artifact-formatting`: text, JSON, and DOT artifact formatting.
- `causal-query-agent-slices`: bounded agent query surfaces.
- `causal-compare-before-after`: baseline and after artifact comparison.
- `causal-dev-loop-package-tests`: before/after dev-loop package-test artifact
  generation.
- `workbench-solid-build`: SolidJS workbench build and test boundaries hosted
  by `webui-dev/zig-webui`.
- `ci-baseline-capture`: PR base causal artifact capture overhead.

Each family declares a category, future command shape, measurement kind,
baseline scope, primary metric, secondary metrics, and agent guidance.

## Baseline Record Fields

Future dynamic observation artifacts should include:

- scenario id and baseline id;
- environment class and runner class;
- optimize mode;
- warmup iterations;
- measured iterations and sample count;
- median, p95, min, max, and optional standard deviation;
- artifact refs;
- source commit;
- observed-at marker;
- bounded measurement notes;
- redaction review;
- observation schema ref.

Agents should compare only matching scenario ids with compatible environment
class, optimize mode, compiler version, package-manager version, and artifact
shape.

## Environment Metadata

Safe environment fields include:

- machine class;
- runner class;
- operating system name and version;
- CPU architecture, coarse CPU model, and CPU count;
- coarse memory class;
- Zig version;
- Bun version for package and workbench commands;
- shell family;
- optimize mode;
- bounded thermal or load notes;
- CI provider, runner image, and run id for CI observations.

Do not include usernames, hostnames, home directories, secrets, tokens, full
environment dumps, raw process lists, or unbounded machine details.

## Calibration Policy

The baseline contract defines advisory calibration rules:

- run warmups before measured iterations;
- use at least five measured iterations for local exploratory records;
- use at least ten measured iterations before treating CI records as
  reviewable;
- report median and p95 rather than a single elapsed time;
- compare only compatible environment classes;
- record failed benchmark commands as causal findings;
- require human review before any timing delta becomes release blocking.

The first advisory thresholds are:

- median regression review threshold: `15%`;
- p95 regression review threshold: `25%`;
- absolute minimum review floor: `5ms`.

These thresholds are review triggers, not enforcement gates.

## Review Gates

- `record-only`: default state for every wall-clock observation.
- `needs-more-samples`: sample count, warmups, environment metadata, or artifact
  refs are incomplete.
- `review-regression`: compatible records exceed the advisory median or p95
  threshold.
- `review-environment-drift`: runner, OS, compiler, package manager, or
  optimize mode changed.
- `ready-for-capacity-planning`: reviewed baselines cover the core request, job,
  artifact, query, compare, dev-loop, workbench, and CI capture surfaces.

No gate mutates source, CI policy, deployment state, rollout state, registry
state, app state, durable storage, or production state.

## Agent Guidance

Agents should:

- use `causal-performance-budget` for deterministic constants;
- use this report for wall-clock observation contracts;
- compare like with like;
- cite source commit, artifact refs, sample count, median, p95, and environment
  metadata;
- explain environment drift before claiming runtime regression;
- recommend human review rather than automatic CI failure;
- hand off to production capacity planning only after reviewed coverage exists.

Agents should not:

- claim production capacity from local or CI timing records;
- compare unrelated machines or optimize modes;
- hide missing sample counts;
- infer secrets or host identity from environment metadata;
- mutate source, registry, app, CI, deployment, rollout, or production systems.

## Future CI Observation Flow

The current CI workflow captures PR base causal artifacts before current-branch
checks. A future dynamic benchmark harness can extend that pattern:

```text
checkout PR base
  -> capture deterministic causal artifact baseline
  -> capture wall-clock benchmark observation
  -> checkout PR head
  -> run deterministic current checks
  -> capture current wall-clock benchmark observation
  -> emit advisory comparison artifact
```

This branch does not make timing observations required CI checks.

## Capacity Planning Handoff

The next branch is
`codex/zigeffect-causal-production-capacity-planning`.

Capacity planning should consume reviewed benchmark baseline evidence alongside
production artifact aggregation, NenDB retention policy, dashboard/workbench
evidence, graph visualization behavior, agent query behavior, and alerting or
rollout handoffs. It should not estimate capacity from unreviewed or
environment-drifted timing records.

## Verification

```sh
cd packages/zigeffect
zig test tools/causal_wall_clock_benchmark_baselines.zig
zig build causal-wall-clock-benchmark-baselines
zig build causal-wall-clock-benchmark-baselines -- --format json
zig build causal-schema-governance -- --format json
zig build causal-production-hardening-backlog -- --format json
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
