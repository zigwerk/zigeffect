# Zigeffect Causal App-Facing Production Integration Local Fixtures Design

## Purpose

The app-facing production integration local fixtures branch consumes the
approved guarded app-facing boundary artifact and emits deterministic local
fixture evidence for the app-facing integration surface. It proves that the
next implementation branches have concrete local fixture families to reason
from. It does not wire ZigEffect into an application, mutate app state, capture
raw app payloads, write NenDB production history, change deployments, enable CI
gates, or mark any remediation as applied.

The branch is:

`codex/zigeffect-causal-app-facing-production-integration-local-fixtures`

The emitted schema is:

`zigeffect.causal.app-facing-production-integration-local-fixtures.v1`

The command is:

`zig build causal-app-facing-production-integration-local-fixtures`

## Source Artifact

The local-fixtures tool consumes only an approved
`zigeffect.causal.app-facing-production-integration-boundary.v1` artifact.

The source boundary must prove:

- The boundary status is `approved` and `approved_for_next_branch=true`.
- The source proposal, readiness, and fixture JSON paths remain linked.
- All boundary checks passed.
- The source boundary recorded every required verification command.
- The source app boundary contract includes app runtime refs, bounded
  agent-query projection, NenDB ref-only handoff, audit/remediation
  evidence-only review links, SolidJS read-only preview scope, and advisory CI
  artifact scope.
- The source local projection fixture labels include the six required fixture
  families.
- Authority fields remain record-only: no app mutation, no raw payload capture,
  no app config writes, no app data writes, no deployment mutation, no NenDB
  production writes, no live telemetry, no durable writes, and no CI gates.

If any source property is missing or fails, the local-fixtures report is emitted
as blocked.

## Fixture Families

The artifact emits a local fixture catalog with one fixture for each boundary
projection label:

- `worker-request-runtime-ref-fixture`
- `background-job-runtime-ref-fixture`
- `agent-query-bounded-projection-fixture`
- `nendb-history-handoff-ref-fixture`
- `audit-remediation-review-link-fixture`
- `solid-webui-readonly-preview-fixture`
- `ci-advisory-artifact-preview-fixture`

Each fixture declares:

- a stable `id`;
- the boundary label it satisfies;
- an input reference shape;
- a local output artifact shape;
- required output fields;
- blocked fields and denied claims.

The catalog is intentionally local and static. It gives agents and reviewers
evidence labels and fields they can cite before later branches implement
runtime adapters, query surfaces, NenDB handoff logic, or workbench views.

## Authority Model

The artifact always emits:

- `applied = false`
- `mutation_authority = "none"`
- `production_telemetry_ingestion = false`
- `live_exporter_enabled = false`
- `durable_write_enabled = false`
- `app_mutation_enabled = false`
- `ci_gate_enabled = false`
- `raw_payload_capture_enabled = false`
- `app_config_write_enabled = false`
- `app_data_write_enabled = false`
- `deployment_mutation_enabled = false`
- `nendb_write_enabled = false`
- `app_runtime_integration_enabled = false`
- `agent_query_live_projection_enabled = false`
- `solid_webui_preview_enabled = false`
- `local_fixture_mode = true`

The authority check fails if the source boundary has any authority field
enabled or if the local fixture constants drift from the disabled state.

## Required Checks

The local-fixtures report evaluates:

- Source boundary schema and version.
- Source boundary approved status and decision.
- Local fixture decision reason and approval.
- Source and local authority fields.
- Source chain links to proposal, readiness, and fixture JSON artifacts.
- Required source boundary checks.
- Required source app boundary contract entries.
- Required source local projection fixture labels.
- Required local fixture catalog entries.
- Runtime ref fixture fields and blocked raw payload fields.
- Agent query bounded projection fixture fields and blocked raw scrape fields.
- NenDB handoff ref fixture fields and blocked production write fields.
- Audit/remediation review link fields and blocked mutation proof claims.
- SolidJS read-only preview fixture fields and blocked live dashboard claims.
- CI advisory artifact fixture fields and blocked enforcement claims.
- Local fixture validation checks.
- Source boundary verification command evidence.
- Local fixture verification command evidence.
- NenDB-only durable direction.
- SolidJS `webui-dev/zig-webui` direction.

Ready reports set `ready_for_next_branch = true` only when every check passes
and the reviewer decision is `approve`.

Rejected reports are valid negative artifacts. They keep the same schema but
set status to `blocked` and `ready_for_next_branch = false`.

## CLI Shape

The command mirrors the existing production telemetry local-pipeline fixtures:

```sh
zig build causal-app-facing-production-integration-local-fixtures -- \
  --from-boundary <boundary.json> \
  approve|reject \
  --reason <reason> \
  [--by <actor>] \
  [--policy <policy>] \
  [--verified-command <command>]... \
  [--out-prefix <path-without-extension>]
```

Without `--out-prefix`, output paths append `-local-fixtures` to the source
boundary artifact path.

## JSON And Text Reports

The JSON report includes:

- Schema metadata, branch, generator, reviewer, policy, decision, and reason.
- Source boundary, source proposal, source readiness, and source fixture paths.
- Fixture status and ready-next-branch flag.
- Authority booleans.
- Boundary summary counts.
- Checks with pass/fail status and detail.
- Fixture catalog entries.
- Fixture validation checks.
- Implementation gates, non-goals, blocked claims, required commands, verified
  commands, and agent guidance.

The text report is the human-readable companion. It must include the same
decision, status, source chain, checks, fixture catalog, gates, and blocked
claims so reviewers can inspect the artifact without parsing JSON.

## Schema Governance

`causal-schema-governance` gains one schema entry in the `app-runtime`
category. The compatibility policy is:

- strict v1
- record-only
- local-fixtures
- fixture-only
- NenDB-only
- no Cockroach adapter
- no live telemetry
- no production mutation

The schema count moves from 86 to 87.

## Production Hardening Backlog

The hardening backlog marks
`app-facing-production-integration-local-fixtures` as delivered after the
boundary. It updates the recommended next branch to:

`codex/zigeffect-causal-app-facing-production-integration-nendb-handoff-fixtures`

The backlog verification commands include both approved and rejected local
fixture paths.

## Documentation Updates

This branch adds:

- `packages/zigeffect/docs/app-facing-production-integration-local-fixtures.md`

It updates:

- `packages/zigeffect/docs/app-facing-production-integration-boundary.md`
- `packages/zigeffect/docs/schema-governance.md`
- `packages/zigeffect/docs/production-hardening-backlog.md`
- `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`

Documentation must keep the branch sequence explicit: fixtures, readiness,
proposal, boundary, local fixtures, then NenDB handoff fixtures.

## Non-Goals

This branch does not:

- Modify an app runtime.
- Capture raw application payloads.
- Write app config or app data.
- Mutate deployments, registries, rollback state, or health state.
- Enable production telemetry ingestion or live exporter behavior.
- Serialize OTLP or send network telemetry.
- Write durable production history.
- Implement a Cockroach adapter.
- Implement a production NenDB writer.
- Build the SolidJS workbench.
- Enable a live agent-query projection.
- Enforce CI gates.
- Claim any issue is fixed, deployed, healthy, integrated, or applied.

## Success Criteria

The milestone is complete when:

- The design and implementation plan are committed.
- The new local-fixtures tool follows the existing artifact-review CLI pattern.
- Unit tests cover option parsing, output paths, ready reports, rejected
  reports, unsupported source artifacts, failed source checks, authority drift,
  missing source verification, missing local verification, and missing fixture
  catalog requirements.
- Schema governance reports 87 schemas and includes the new schema.
- The hardening backlog recommends the app-facing NenDB handoff fixtures branch.
- The approved end-to-end artifact chain can be generated locally from fixtures
  through app-facing local fixtures.
- The rejected local-fixtures path emits a blocked artifact.
- `zig build examples`, `zig build test`, root `bun run check`, root
  `bun run zig:test`, and `git diff --check` pass.
