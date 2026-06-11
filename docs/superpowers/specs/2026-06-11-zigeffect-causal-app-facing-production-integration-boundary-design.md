# Zigeffect Causal App-Facing Production Integration Boundary Design

## Purpose

The app-facing production integration boundary turns the approved app-facing
implementation proposal into a guarded handoff artifact. It does not wire
ZigEffect into an application, capture live app payloads, write to NenDB, change
deployment state, or mark any remediation as applied. Its job is to make the
next implementation branch precise enough that an agent can reason from
reviewed evidence instead of inventing authority.

The branch is:

`codex/zigeffect-causal-app-facing-production-integration-boundary`

The emitted schema is:

`zigeffect.causal.app-facing-production-integration-boundary.v1`

The command is:

`zig build causal-app-facing-production-integration-boundary`

## Source Artifact

The boundary consumes only an approved
`zigeffect.causal.app-facing-production-integration-implementation-proposal.v1`
artifact.

The source proposal must prove:

- The source readiness review was approved.
- The source fixture catalog was linked as JSON evidence.
- Every required readiness and proposal verification command was recorded.
- The proposal checks for app runtime scope, bounded agent query scope,
  NenDB-only direction, and SolidJS inside `webui-dev/zig-webui` passed.
- The proposal phases include app runtime boundary, agent query projection, and
  NenDB history handoff.
- Authority fields remain record-only: no production telemetry ingestion, live
  exporter, durable write, app mutation, or CI enforcement authority.

If any source property is missing or fails, the boundary report is emitted as
blocked.

## Boundary Contract

The boundary artifact records a single app-facing contract:

- App runtime evidence is referenced by trace ids and causal event ids only.
- Raw application payload capture is blocked.
- Agent query projection is bounded to redacted trace data, findings, next-query
  hints, and reviewed artifact links.
- NenDB handoff is reference-only and cannot write production data.
- Audit-chain and remediation links are evidence for review, not proof that a
  fix was applied.
- SolidJS workbench direction remains read-only preview inside
  `webui-dev/zig-webui`.
- CI artifacts remain advisory until a later explicitly reviewed CI gate branch.

This contract is intentionally narrower than a real production integration. It
creates a stable boundary for the next local-fixtures branch without implying
that any app, deployment, registry, or durable store has been mutated.

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

The boundary check fails if the source proposal has any authority field enabled
or if the boundary constants drift from the disabled state.

## Local Projection Fixtures

The boundary report names the fixture families the next branch must build:

- `worker-request-runtime-ref-boundary`
- `background-job-runtime-ref-boundary`
- `agent-query-bounded-projection-boundary`
- `nendb-history-handoff-ref-boundary`
- `audit-remediation-review-link-boundary`
- `solid-webui-readonly-handoff-boundary`

These are labels and acceptance targets only. This branch does not implement the
fixtures themselves.

## Required Checks

The boundary evaluates:

- Source proposal schema and version.
- Source proposal approval status and decision.
- Boundary decision reason and approval.
- Source and boundary authority fields.
- Source chain links to readiness and fixture JSON artifacts.
- Required source proposal checks.
- Required source proposal phases.
- Source proposal verification command evidence.
- Boundary verification command evidence.
- App runtime reference-only boundary.
- Bounded agent query projection boundary.
- NenDB handoff boundary.
- Audit/remediation evidence-only boundary.
- No production mutation boundary.
- NenDB-only durable scope.
- SolidJS webui scope.

Approved reports set `approved_for_next_branch = true` only when every check
passes and the reviewer decision is `approve`.

Rejected reports are valid negative artifacts. They keep the same schema but set
status to `blocked` and `approved_for_next_branch = false`.

## CLI Shape

The command mirrors the existing production telemetry exporter boundary:

```sh
zig build causal-app-facing-production-integration-boundary -- \
  --from-proposal <proposal.json> \
  approve|reject \
  --reason <reason> \
  [--by <actor>] \
  [--policy <policy>] \
  [--verified-command <command>]... \
  [--out-prefix <path-without-extension>]
```

Without `--out-prefix`, output paths append `-app-facing-boundary` to the source
proposal artifact path.

## JSON And Text Reports

The JSON report includes:

- Schema metadata, branch, generator, reviewer, policy, decision, and reason.
- Source proposal, source readiness, and source fixture paths.
- Boundary status and approved-next-branch flag.
- Authority booleans.
- Source summary counts.
- Boundary contract key/value entries.
- Local projection fixture labels.
- Checks with pass/fail status and detail.
- Required and verified command lists.
- Implementation gates, non-goals, blocked claims, and agent guidance.

The text report is the human-readable companion. It must include the same
decision, status, source chain, checks, gates, and blocked claims so reviewers
can inspect the artifact without parsing JSON.

## Schema Governance

`causal-schema-governance` gains one schema entry in the `app-runtime`
category. The compatibility policy is:

- strict v1
- record-only
- guarded-boundary
- NenDB-only
- no Cockroach adapter
- no live telemetry
- no production mutation

The schema count moves from 85 to 86.

## Production Hardening Backlog

The hardening backlog marks
`app-facing-production-integration-boundary` as delivered after the
implementation proposal. It updates the recommended next branch to:

`codex/zigeffect-causal-app-facing-production-integration-local-fixtures`

The backlog verification commands include both approved and rejected boundary
paths.

## Documentation Updates

This branch adds:

- `packages/zigeffect/docs/app-facing-production-integration-boundary.md`

It updates:

- `packages/zigeffect/docs/app-facing-production-integration-implementation-proposal.md`
- `packages/zigeffect/docs/schema-governance.md`
- `packages/zigeffect/docs/production-hardening-backlog.md`
- `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`

Documentation must keep the branch sequence explicit: fixtures, readiness,
proposal, boundary, then local fixtures.

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
- Enforce CI gates.
- Claim any issue is fixed, deployed, healthy, integrated, or applied.

## Success Criteria

The milestone is complete when:

- The design and implementation plan are committed.
- The new boundary tool follows the existing artifact-review CLI pattern.
- Unit tests cover option parsing, output paths, approved reports, rejected
  reports, unsupported source artifacts, failed source checks, authority drift,
  missing source verification, and missing boundary verification.
- Schema governance reports 86 schemas and includes the new schema.
- The hardening backlog recommends the app-facing local-fixtures branch.
- The approved end-to-end artifact chain can be generated locally from fixtures
  through boundary.
- The rejected boundary path emits a blocked artifact.
- `zig build examples`, `zig build test`, root `bun run check`, root
  `bun run zig:test`, and `git diff --check` pass.
