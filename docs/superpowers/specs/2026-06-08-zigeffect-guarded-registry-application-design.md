# zigeffect Guarded Registry Application Design

Date: 2026-06-08

## Purpose

This design implements M0 from the causal agent runtime master roadmap:
guarded registry application. The readiness gate already answers whether a
reviewed registry patch is applicable, blocked, or not applicable. This next
boundary records what happened after readiness without pretending that review
evidence is the same thing as a source change.

The new command consumes
`zigeffect.causal.registry-application-readiness.v1` artifacts and writes
`zigeffect.causal.registry-application.v1` artifacts. It keeps mutation narrow:
the first slice does not auto-edit source. It emits either a manual application
plan with `applied=false` or a post-application record with `applied=true` only
after the current source registry and docs already prove the reviewed patch was
applied.

## Command Shape

The public command is:

```sh
zig build causal-registry-apply -- --from-readiness <registry-application-readiness.json> plan --reason <reason>
zig build causal-registry-apply -- --from-readiness <registry-application-readiness.json> record-applied --reason <reason> --verified-command <command>...
```

Optional metadata:

```sh
--by <actor>
--policy <policy>
```

Defaults:

- `--by local-reviewer`
- `--policy manual-application`

Mode semantics:

- `plan`: reads readiness and writes an application plan. It never reports
  source mutation and always writes `applied=false`.
- `record-applied`: reads readiness, verifies current source state and supplied
  verification commands, and writes `applied=true` only if evidence proves the
  registry/docs have already been updated.

No direct source-writing mode is included in this slice. A later branch may add
a narrow guarded mutation backend, but this branch establishes the evidence
contract first.

## Input Artifact

The input schema is `zigeffect.causal.registry-application-readiness.v1`.

Required fields:

- `schema`
- `schema_version`
- `source_registry_patch`
- `decision`
- `readiness_status`
- `decided_by`
- `policy`
- `reason`
- `applied`
- `target`
- `scenario_slug`
- `checks`
- `required_verification_commands`
- `verified_commands`
- `guardrails`

Validation rules:

- `schema` must equal `zigeffect.causal.registry-application-readiness.v1`.
- `schema_version` must equal `1`.
- `applied` must be `false`; readiness cannot already be an applied artifact.
- `readiness_status=blocked` blocks both `plan` and `record-applied`.
- `readiness_status=not-applicable` produces a no-op application report.
- `readiness_status=applicable` is required before `record-applied` can emit
  `applied=true`.
- `decision` must be `approve` for applicable records.
- The source registry patch path must end in `-registry-patch.json`.

## Output Artifacts

Output paths derive from the readiness path:

```text
<prefix>-registry-application.json
<prefix>-registry-application.txt
```

Example:

```text
.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-registry-application.json
.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-registry-application.txt
```

Scenario-specific examples:

```text
.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-registry-application.json
.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-registry-application.txt
```

Output schema:

```text
zigeffect.causal.registry-application.v1
```

Required JSON fields:

- `schema`
- `schema_version`
- `source_readiness`
- `source_registry_patch`
- `mode`
- `application_status`
- `applied`
- `applied_by`
- `policy`
- `reason`
- `readiness_status`
- `target`
- `scenario_slug`
- `checks`
- `required_verification_commands`
- `verified_commands`
- `application_steps`
- `guardrails`

Application statuses:

- `planned`: manual application plan written; `applied=false`.
- `applied`: source state and verification evidence prove application;
  `applied=true`.
- `blocked`: readiness or application checks prevent application;
  `applied=false`.
- `not-applicable`: readiness was no-op; `applied=false`.

## Application Checks

The application command adds checks beyond readiness:

- `readiness-schema`: readiness schema is supported.
- `readiness-applicable`: readiness status permits the requested mode.
- `decision-approved`: readiness decision was approved when application is
  requested.
- `source-registry-present`: current `causal_run` registry contains the
  scenario slug.
- `source-placeholder-cleared`: current scenario argv is not the generated
  placeholder.
- `source-invariants-known`: readiness/patch invariant ids are known by the
  current runtime.
- `source-docs-present`: `docs/causal-scenarios.md` mentions the scenario slug.
- `post-verification-recorded`: caller supplied every required verification
  command for `record-applied`.

No-op reports skip source checks and write `application_status=not-applicable`.

Plan reports do not require post-application verification because they are not
claiming application. They still preserve the required verification commands
from readiness.

## Source Inspection

The first slice inspects current source through the compiled `causal_run`
module and the checked-in scenario docs:

- `causal_run.scenarioByName(slug)` proves scenario presence.
- Scenario argv comparison proves the generated placeholder was replaced.
- `causal_run.invariantById(id)` proves invariant ids are known.
- Reading `docs/causal-scenarios.md` proves docs mention the slug.

The command does not edit `tools/causal_run.zig` or docs. It records whether
current source already matches the reviewed readiness evidence.

## Safety Rules

- Blocked readiness cannot become an application plan.
- Applicable readiness cannot become `applied=true` without source-state checks
  and verification command evidence.
- No-op readiness cannot become `applied=true`.
- Plan mode must not be mistaken for application.
- The application artifact must keep the source readiness path and source
  registry patch path.
- Guardrails must explicitly state whether the artifact is a plan, no-op,
  block, or applied record.

## Integration Points

Build wiring:

- Add `tools/causal_registry_apply.zig`.
- Add the tool module and tests to `packages/zigeffect/build.zig`.
- Add the executable step:
  - `zig build causal-registry-apply`
- Include the executable and tests in `zig build examples`.

Artifact manifest:

- Add default registry application JSON/text paths.
- Add scenario registry application JSON/text paths.
- Add tests for default and `package-tests` paths.

Docs:

- Update `packages/zigeffect/README.md`.
- Update `packages/zigeffect/docs/agent-guide.md`.
- Update `packages/zigeffect/docs/causal-scenarios.md`.
- Update `packages/zigeffect/docs/roadmap.md`.
- Update the master roadmap progress ledger after merge.

## Acceptance Criteria

- `plan` mode writes JSON/text artifacts with `application_status=planned` and
  `applied=false` for applicable readiness.
- `record-applied` mode writes `application_status=applied` and `applied=true`
  only when current source state and supplied verification commands satisfy all
  checks.
- Blocked readiness writes or fails as blocked without `applied=true`.
- No-op readiness writes `application_status=not-applicable` and
  `applied=false`.
- Invalid schema, unsupported version, missing reason, invalid path, and
  missing verification command inputs fail with stable usage errors.
- The artifact manifest lists registry application artifacts.
- The docs explain that this branch records application state but does not
  auto-edit source.
- `zig build examples` passes.
- `zig build test --summary none` passes.
- `bun run check` passes before merge.
- `bun run zig:test` passes before merge.
