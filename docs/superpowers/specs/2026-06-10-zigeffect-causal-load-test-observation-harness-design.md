# zigeffect Causal Load-Test Observation Harness Design

## Context

The production-hardening completion audit now recommends
`codex/zigeffect-causal-load-test-observation-harness` as the next
evidence-producing branch. The audit closes the static hardening contract
sweep and preserves these boundaries:

- all reports remain record-only;
- `mutation_authority=none`;
- durable direction remains NenDB adapter only;
- workbench direction remains SolidJS inside `webui-dev/zig-webui`;
- capacity planning is not production capacity evidence;
- no live production telemetry is ingested;
- no production load is executed.

The production capacity planning contract provides the scenario and evidence
shape that this branch should consume. The wall-clock benchmark baseline
contract defines safe observation fields, environment metadata, calibration
policy, advisory review gates, and the initial eight scenario families.

This milestone is the first local observation harness. It should turn planned
scenario families into bounded local observation records while keeping all
capacity, telemetry, rollout, alerting, RBAC, encryption, durable-store, and
production claims out of scope.

## Goals

- Add a schema-governed command:
  `zig build causal-load-test-observation-harness`.
- Emit schema `zigeffect.causal.load-test-observation-harness.v1`.
- Provide a default catalog report that lists approved local observation
  scenarios without executing them.
- Provide JSON output for agents and roadmap checks.
- Define an opt-in local observation mode for approved scenario ids only.
- Keep observation execution bounded:
  - argv arrays only, no shell strings;
  - package-root working directory;
  - capped stdout/stderr snippets;
  - capped iterations;
  - explicit warmup and measured iteration counts;
  - deterministic review gate classification;
  - redaction-safe environment metadata only.
- Consume the eight scenario families from wall-clock benchmark baselines and
  production capacity planning:
  - `app-request-trace`;
  - `background-job-trace`;
  - `causal-artifact-formatting`;
  - `causal-query-agent-slices`;
  - `causal-compare-before-after`;
  - `causal-dev-loop-package-tests`;
  - `workbench-solid-build`;
  - `ci-baseline-capture`.
- Record why each scenario is local-safe, fixture-only, or future-CI-only.
- Emit negative fixtures that block production load, live telemetry, capacity
  claims, arbitrary commands, unredacted environment dumps, CI gates,
  non-NenDB adapter scope, and alternate renderer scope.
- Update schema governance, production-hardening backlog, README, operations,
  roadmap, and dedicated docs.
- Hand off to `codex/zigeffect-causal-production-telemetry-capture-design`
  after local observations exist.

## Non-Goals

- No production load tests.
- No live production telemetry ingestion.
- No reviewed production capacity sizing.
- No production cost, autoscaling, incident-volume, dashboard-hosting, or
  traffic estimates.
- No source, config, registry, app, deployment, rollout, alert, ticket, page,
  RBAC, encryption, durable-store, CI-policy, or production mutation.
- No automatic CI timing gates.
- No arbitrary user-supplied command execution.
- No shell invocation.
- No environment dumps, hostnames, usernames, home directories, tokens, secrets,
  raw process lists, or raw request payloads.
- No non-NenDB durable adapter work.
- No Cockroach adapter work.
- No alternate frontend renderer work.
- No claim that local observations prove production readiness.

## Considered Approaches

### Approach A: Bounded local harness with catalog and opt-in observation

Create one Zig tool with two safe surfaces:

- default/catalog output: deterministic scenario catalog, policy boundaries,
  review gates, negative fixtures, verification commands, and next-branch
  handoff;
- opt-in observation output: run one approved local scenario through a curated
  argv list with warmups, measured iterations, bounded output snippets, median
  and p95 calculation, command status, environment metadata fields, and review
  gate classification.

This is the recommended approach. It creates genuine local observation records
without widening authority. Tests can exercise the observation engine through a
fake runner, while the default build step stays deterministic and does not run
benchmarks accidentally.

### Approach B: Static report only

Create another deterministic report that describes the future harness but never
runs a local command.

This is too weak for the branch name and roadmap position. The completion audit
already created the static bridge. This milestone should begin producing local
observation evidence, even if that evidence remains advisory and bounded.

### Approach C: Full load-test runner and CI gate

Create a benchmark runner that executes all scenarios, writes artifacts, and
fails CI on timing regressions.

This jumps too far. The upstream wall-clock baseline contract explicitly says
timing observations are advisory and require human review before gating. It
would also blur local observation with production capacity evidence.

## Architecture

Create
`packages/zigeffect/tools/causal_load_test_observation_harness.zig`.

The tool owns both the catalog and observation record schema for v1. It should
not import the other report tools; instead, it cites upstream schemas,
commands, and docs. It should use the same text/JSON formatting style as the
existing production-hardening tools.

The default invocation should be deterministic:

```sh
zig build causal-load-test-observation-harness
zig build causal-load-test-observation-harness -- --format json
```

Observation execution should require an explicit subcommand:

```sh
zig build causal-load-test-observation-harness -- observe app-request-trace --iterations 5 --format json
```

The first implementation should support fake-runner tests for observation
math and command classification. The live process runner should be restricted
to the curated scenario catalog and must never accept arbitrary command text.

## Schema Shape

Top-level catalog fields:

- `schema`
- `schema_version`
- `producer`
- `mode`
- `applied`
- `mutation_authority`
- `source_branch`
- `status`
- `recommendation`
- `next_branch`
- `source_contracts`
- `scenario_catalog`
- `observation_record_fields`
- `execution_constraints`
- `review_gates`
- `negative_observation_fixtures`
- `agent_guidance`
- `non_goals`
- `verification_commands`

Observation record fields:

- `schema`
- `schema_version`
- `producer`
- `mode = "local-observation"`
- `applied = false`
- `mutation_authority = "none"`
- `scenario_id`
- `scenario_category`
- `command_status`
- `exit_code`
- `warmup_iterations`
- `measured_iterations`
- `sample_count`
- `median_ms`
- `p95_ms`
- `min_ms`
- `max_ms`
- `stdout_snippet`
- `stderr_snippet`
- `artifact_refs`
- `environment`
- `review_gate`
- `capacity_claim = false`
- `production_telemetry = false`
- `production_load = false`
- `agent_guidance`

Constants:

- `schema = "zigeffect.causal.load-test-observation-harness.v1"`
- `schema_version = 1`
- `producer = "causal-load-test-observation-harness"`
- `mode = "local-record"` for catalog output
- `applied = false`
- `mutation_authority = "none"`
- `source_branch = "codex/zigeffect-causal-load-test-observation-harness"`
- `recommendation = "start-production-telemetry-capture-design"`
- `next_branch = "codex/zigeffect-causal-production-telemetry-capture-design"`

## Scenario Catalog

Each scenario should include:

- `id`
- `category`
- `status`
- `upstream_source`
- `argv`
- `measurement_kind`
- `required_evidence`
- `local_safety_boundary`
- `blocked_claim`
- `agent_guidance`

Initial statuses:

- `app-request-trace`: `local-safe`
- `background-job-trace`: `local-safe`
- `causal-artifact-formatting`: `local-safe`
- `causal-query-agent-slices`: `local-safe`
- `causal-compare-before-after`: `local-safe`
- `causal-dev-loop-package-tests`: `local-safe`
- `workbench-solid-build`: `local-safe`
- `ci-baseline-capture`: `future-ci-only`

`ci-baseline-capture` should be in the catalog but not executable locally by
default. It needs CI runner metadata and PR base/head checkout semantics before
it can produce comparable records.

## Observation Execution

The execution engine should be deliberately small:

- Parse only catalog/report options and `observe <scenario-id>`.
- Reject unknown scenarios.
- Reject missing or invalid iteration counts.
- Cap measured iterations at `10` for v1.
- Run warmups before measured iterations.
- Collect elapsed milliseconds for each measured iteration.
- Sort measured samples to calculate min, max, median, and p95.
- Capture stdout and stderr snippets only, capped at 240 bytes each.
- Convert command failure into a record with `command_status = "failed"` and
  `review_gate = "failed-command-finding"`.
- Keep successful observations advisory with `review_gate = "needs-review"`.
- Mark `ci-baseline-capture` as `future-ci-only` and reject local observation
  attempts with a deterministic error.

The process runner should be hidden behind a small runner interface so tests
can use a fake runner. The fake runner should prove that commands are invoked
with curated argv arrays and that observation math is independent of live
machine timing.

## Review Gates

Initial gates:

- `record-only`: all observations are advisory records.
- `needs-more-samples`: sample count below reviewed threshold.
- `needs-review`: local observation exists but is not capacity evidence.
- `failed-command-finding`: scenario command failed and should be investigated.
- `environment-drift-review`: compatible comparison cannot be made.
- `ready-for-telemetry-design`: local observations cover runnable scenarios
  and remaining production telemetry questions are explicit.

No review gate can fail CI, mutate source, size production capacity, or grant
authority.

## Negative Observation Fixtures

The report should reject:

- `production-load-claim`: local observation treated as production load.
- `capacity-sizing-claim`: local timings treated as production capacity.
- `live-telemetry-claim`: local harness treated as telemetry capture.
- `arbitrary-command-execution`: user-supplied shell or command text accepted.
- `ci-gate-claim`: advisory timings treated as release blockers.
- `unredacted-environment`: raw environment or host identity captured.
- `non-nendb-adapter`: local observations used to authorize other durable
  adapter work.
- `alternate-renderer`: local observations used to authorize React or another
  workbench renderer.
- `mutation-authority`: harness treated as source, config, deployment,
  rollout, app, registry, or production mutation authority.

## Documentation Updates

- Add `packages/zigeffect/docs/load-test-observation-harness.md`.
- Update `packages/zigeffect/README.md`.
- Update `packages/zigeffect/docs/operations.md`.
- Update `packages/zigeffect/docs/schema-governance.md`.
- Update `packages/zigeffect/docs/production-hardening-backlog.md`.
- Update `packages/zigeffect/docs/production-hardening-completion-audit.md`.
- Update `packages/zigeffect/docs/roadmap.md`.
- Update
  `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`.

## Verification

Focused verification:

```sh
cd packages/zigeffect
zig test tools/causal_load_test_observation_harness.zig
zig build causal-load-test-observation-harness
zig build causal-load-test-observation-harness -- --format json
zig build causal-load-test-observation-harness -- observe app-request-trace --iterations 1 --format json
zig build causal-schema-governance -- --format json
zig build causal-production-hardening-backlog -- --format json
```

Broad verification:

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

## Open Follow-Up

After this milestone, the next branch should design privacy-safe production
telemetry capture. Reviewed production capacity sizing should remain blocked
until both local observations and production telemetry capture contracts exist.
