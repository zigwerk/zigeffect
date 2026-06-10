# zigeffect Causal Load-Test Observation Harness

`causal-load-test-observation-harness` is a schema-governed local observation
harness for the production-hardening roadmap. It turns the capacity-planning
fixture plan and wall-clock baseline assumptions into bounded local records
that agents can cite while building zigeffect.

The harness is deliberately record-only. It does not run production load,
ingest production telemetry, size production capacity, fail CI, execute shell
strings, write durable stores, introduce non-NenDB adapter work, change the
SolidJS `webui-dev/zig-webui` workbench direction, or grant mutation authority.

## Command

```sh
cd packages/zigeffect
zig build causal-load-test-observation-harness
zig build causal-load-test-observation-harness -- --format json
zig build causal-load-test-observation-harness -- observe app-request-trace --iterations 1 --format json
```

The catalog and observation records use schema
`zigeffect.causal.load-test-observation-harness.v1`.

## Modes

Catalog mode is the default. It prints source contracts, scenario families,
curated argv arrays, execution constraints, review gates, negative fixtures,
agent guidance, non-goals, and verification commands.

Observation mode is opt-in:

```sh
zig build causal-load-test-observation-harness -- observe <scenario-id> --iterations <n> --format text|json
```

Observation mode runs one warmup plus the requested measured iterations. The
measured iterations are capped at `10`, stdout and stderr snippets are capped,
and every live command comes from a curated argv array.

## Scenario Catalog

- `app-request-trace`: executable local request-trace example.
- `background-job-trace`: executable scoped-fiber local runtime scenario.
- `causal-artifact-formatting`: executable local causal report formatting path.
- `causal-query-agent-slices`: executable bounded local agent-query slice.
- `causal-compare-before-after`: cataloged, blocked until reviewed paired
  artifacts exist.
- `causal-dev-loop-package-tests`: executable package test command.
- `workbench-solid-build`: cataloged, blocked in v1 because it runs from the
  repository root rather than `packages/zigeffect`.
- `ci-baseline-capture`: cataloged as future CI-only work.

## Observation Record

Observation records include:

- schema and schema version;
- `applied=false`;
- `mutation_authority="none"`;
- scenario id and category;
- command status and exit code;
- warmup and measured iteration counts;
- sample count, median, p95, min, and max milliseconds;
- bounded stdout and stderr snippets;
- local environment class;
- review gate;
- `capacity_claim=false`, `production_telemetry=false`, and
  `production_load=false`.

For small sample counts the review gate is `needs-more-samples`. Failed
commands become `failed-command-finding`. Larger successful local samples remain
`needs-review` until a human decides how to interpret them.

## Source Contracts

The harness consumes these upstream contracts:

- `zigeffect.causal.wall-clock-benchmark-baselines.v1` for advisory timing and
  environment-comparison rules.
- `zigeffect.causal.production-capacity-planning.v1` for scenario families,
  fixture planning, and capacity non-claims.
- `zigeffect.causal.production-hardening-completion-audit.v1` for delivered
  milestone boundaries and remaining gaps.

## Negative Fixtures

The harness rejects these claims:

- local observations prove production load behavior;
- local timings size production capacity;
- live production telemetry was captured;
- agents can pass arbitrary shell commands;
- advisory timings can fail CI;
- raw environment or secret material can be dumped;
- non-NenDB durable adapter work is authorized;
- React or another renderer is authorized for the workbench path;
- mutation authority has been granted.

## Agent Guidance

Agents may cite local observation records to explain what happened in a local
development loop. They should include the scenario id, command status, sample
count, median, p95, and review gate.

Agents must compare only compatible scenario ids, environment classes, optimize
modes, and artifact shapes. They must not convert local observations into
production capacity claims. The telemetry capture design handoff is delivered
as `codex/zigeffect-causal-production-telemetry-capture-design`, the fixture
handoff is delivered as
`codex/zigeffect-causal-production-telemetry-capture-fixtures`, and the
readiness-review handoff is delivered as
`codex/zigeffect-causal-production-telemetry-readiness-review`. The
implementation-proposal handoff is delivered as
`codex/zigeffect-causal-production-telemetry-implementation-proposal`. The
exporter-boundary handoff is delivered as
`codex/zigeffect-causal-production-telemetry-exporter-boundary`. The local
pipeline fixture handoff is delivered as
`codex/zigeffect-causal-production-telemetry-local-pipeline-fixtures`. The
NenDB retention fixture handoff is delivered as
`codex/zigeffect-causal-production-telemetry-nendb-retention-fixtures`. The
workbench read-only preview handoff is delivered as
`codex/zigeffect-causal-production-telemetry-workbench-readonly-preview`. The
CI artifact preview handoff is delivered as
`codex/zigeffect-causal-production-telemetry-ci-artifact-preview`. The
current next branch is
`codex/zigeffect-causal-production-telemetry-ci-harness-boundary`.

## Verification

```sh
cd packages/zigeffect
zig test tools/causal_load_test_observation_harness.zig
zig build causal-load-test-observation-harness
zig build causal-load-test-observation-harness -- --format json
zig build causal-load-test-observation-harness -- observe app-request-trace --iterations 1 --format json
zig build causal-production-telemetry-capture-design
zig build causal-production-telemetry-capture-design -- --format json
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
