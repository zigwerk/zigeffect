# zigeffect Causal App-Facing Production Integration Readiness Review Design

## Status

Design for branch:
`codex/zigeffect-causal-app-facing-production-integration-readiness-review`

This milestone consumes the delivered
`zigeffect.causal.app-facing-production-integration-fixtures.v1` catalog and
emits a record-only readiness review artifact. A ready review is permission to
start an implementation-proposal branch only. It is not permission to mutate an
app, ingest live telemetry, configure exporters, write durable production
storage, enforce CI gates, or introduce Cockroach adapter work.

## Context

The previous branch delivered deterministic app-facing production integration
fixtures. Those fixtures tie together:

- app runtime semantic traces;
- bounded agent query evidence;
- audit-chain before/after comparison;
- NenDB durable-history handoff;
- production telemetry fixture boundaries;
- app remediation governance artifacts.

That catalog is intentionally fixture-only. It proves that we have a common
evidence vocabulary for agents and reviewers, but it does not prove the
integration is ready to become implementation work. The missing step is a
review gate that reads the fixture JSON, evaluates exact coverage and authority
boundaries, records a reviewer decision, records verification evidence, and
then emits either `ready` or `blocked`.

## Problem

Without a readiness-review artifact, the next branch can accidentally treat
fixtures as implementation approval. That creates several risks:

- an agent might infer app mutation authority from governance evidence;
- fixture-only production telemetry boundaries might be misread as live
  telemetry ingestion or exporter setup;
- NenDB-compatible durable references might be misread as durable production
  writes;
- the app-facing roadmap could drift into Cockroach adapter work even though
  the current durable scope is NenDB only;
- SolidJS inside `webui-dev/zig-webui` could drift into React or another
  renderer before the workbench boundary is reviewed;
- reviewers could lack a small, deterministic artifact that says which checks
  passed and what to do next.

## Goals

- Add a CLI tool named
  `causal-app-facing-production-integration-readiness-review`.
- Consume fixture JSON emitted by
  `causal-app-facing-production-integration-fixtures`.
- Emit `zigeffect.causal.app-facing-production-integration-readiness-review.v1`
  as JSON and text reports.
- Require a reviewer decision and reason.
- Require a fixed set of verification commands for a ready decision.
- Preserve source fixture counts and check details for agents.
- Mark `ready_for_implementation_proposal=true` only when every check passes
  and the reviewer decision is `approve`.
- Keep `applied=false`, `mutation_authority=none`,
  `production_telemetry_ingestion=false`, `live_exporter_enabled=false`,
  `durable_write_enabled=false`, `app_mutation_enabled=false`, and
  `ci_gate_enabled=false`.
- Update schema governance, backlog, roadmap, and operator docs so this becomes
  the next formal step in the long-running causal roadmap.

## Non-Goals

- No app source/config/migration/deployment/rollout/rollback mutation.
- No live production telemetry ingestion.
- No OTLP serialization, collector endpoint configuration, exporter setup, or
  network send.
- No durable production writes.
- No non-NenDB durable adapter work.
- No Cockroach adapter work.
- No CI enforcement gate.
- No production workbench hosting.
- No React or alternate renderer work.
- No claim that readiness proves a production app is healthy or integrated.

## CLI Contract

The tool should follow the existing production telemetry readiness-review
pattern:

```sh
zig build causal-app-facing-production-integration-readiness-review -- \
  --from-fixtures <fixtures.json> \
  approve|reject \
  --reason <reason> \
  [--by <actor>] \
  [--policy <policy>] \
  [--verified-command <command>]... \
  [--out-prefix <path-prefix>]
```

Default output paths should be derived from the fixture path:

- `<fixtures-base>-readiness-review.json`
- `<fixtures-base>-readiness-review.txt`

With `--out-prefix`, the tool should write:

- `<out-prefix>.json`
- `<out-prefix>.txt`

The text report should also be printed to stderr/std.debug output, matching the
existing tool convention.

## Input Contract

The source fixture catalog is parsed with unknown fields ignored, but the
readiness checks depend on these fields:

- `schema`
- `schema_version`
- `status`
- `source_branch`
- `recommendation`
- `next_branch`
- `applied`
- `mutation_authority`
- `production_telemetry_ingestion`
- `live_exporter_enabled`
- `durable_write_enabled`
- `app_mutation_enabled`
- `ci_gate_enabled`
- `source_contracts[].id`
- `positive_fixtures[].fixture_id`
- `positive_fixtures[].integration_surface_id`
- `positive_fixtures[].retention_policy`
- `positive_fixtures[].telemetry_transport_state`
- `positive_fixtures[].durable_write_state`
- `positive_fixtures[].app_mutation_state`
- `negative_fixtures[].id`
- `validation_checks[].id`
- `validation_checks[].status`
- `non_goals[]`

## Output Schema

The readiness review artifact should include:

- `schema`:
  `zigeffect.causal.app-facing-production-integration-readiness-review.v1`
- `schema_version`: `1`
- `generated_by`:
  `causal-app-facing-production-integration-readiness-review`
- `source_fixtures`: source fixture path
- `source_fixture_schema`:
  `zigeffect.causal.app-facing-production-integration-fixtures.v1`
- `decision`: `approve` or `reject`
- `readiness_status`: `ready` or `blocked`
- `ready_for_implementation_proposal`: boolean
- `reviewed_by`
- `policy`
- `reason`
- `applied`: always `false`
- `mutation_authority`: always `none`
- `production_telemetry_ingestion`: always `false`
- `live_exporter_enabled`: always `false`
- `durable_write_enabled`: always `false`
- `app_mutation_enabled`: always `false`
- `ci_gate_enabled`: always `false`
- `source_branch`:
  `codex/zigeffect-causal-app-facing-production-integration-readiness-review`
- `recommendation`:
  `start-app-facing-production-integration-implementation-proposal`
- `next_branch_if_ready`:
  `codex/zigeffect-causal-app-facing-production-integration-implementation-proposal`
- `fixture_summary`
- `checks`
- `required_verification_commands`
- `verified_commands`
- `implementation_proposal_steps`
- `readiness_guardrails`

## Readiness Checks

The review should append named checks in a stable order. A ready result requires
every check to pass.

1. `fixture-schema`
   The source artifact must be
   `zigeffect.causal.app-facing-production-integration-fixtures.v1` with
   schema version `1`.

2. `fixture-status`
   The source artifact status must be `fixtures-only`.

3. `reviewer-decision`
   The reviewer must supply a non-empty decision reason.

4. `decision-approved`
   The decision must be `approve`. A `reject` decision is a valid blocked
   artifact.

5. `authority-boundary`
   The source fixture catalog must keep `applied=false`,
   `mutation_authority=none`, and all live authority booleans disabled.

6. `source-contracts-present`
   Required source contract ids:
   `app-runtime`, `agent-query`, `audit-chain-snapshot-compare`,
   `nendb-durable-history`, `production-telemetry-capture-fixtures`,
   `app-remediation-chain`.

7. `positive-fixture-coverage`
   Required positive fixture ids:
   `worker-request-redacted-lineage`,
   `background-job-nendb-history-handoff`,
   `agent-query-app-trace-data`,
   `audit-chain-before-after-app-review`,
   `app-remediation-governance-bridge`,
   `production-telemetry-fixture-boundary`.

8. `integration-surface-coverage`
   Required integration surfaces:
   `worker-request`, `background-job`, `agent-query`,
   `audit-chain-compare`, `app-remediation`,
   `production-telemetry-boundary`.

9. `negative-fixture-coverage`
   Required negative fixture ids:
   `raw-request-body-capture`, `raw-header-capture`, `raw-prompt-capture`,
   `credential-token-capture`, `pii-or-tenant-identity-capture`,
   `live-production-telemetry-ingestion`, `live-exporter-enabled`,
   `production-durable-write`, `non-nendb-durable-storage`,
   `cockroach-adapter-work`, `app-mutation-authority`,
   `audit-chain-compare-as-mutation-proof`,
   `agent-query-raw-payload-scrape`, `ci-gate-enforcement`,
   `react-or-alternate-renderer`.

10. `validation-checks-passed`
    Required validation ids:
    `source-contract-coverage`, `positive-fixture-surface-coverage`,
    `redaction-ref-only-lineage`, `blocked-claim-coverage`,
    `forbidden-value-absence`, `nendb-only-durable-direction`,
    `no-live-authority`, `next-branch-handoff`.
    All parsed validation checks must have status `passed`.

11. `nendb-only-durable-direction`
    Every positive fixture retention policy must include `nendb`, the negative
    fixture catalog must contain `non-nendb-durable-storage` and
    `cockroach-adapter-work`, and non-goals must mention both non-NenDB durable
    adapter work and Cockroach adapter work.

12. `app-mutation-disabled`
    All positive fixtures must have `app_mutation_state=disabled-fixture`, and
    the source artifact must keep `app_mutation_enabled=false`.

13. `telemetry-and-durable-disabled`
    All positive fixtures must have
    `telemetry_transport_state=disabled-fixture` and
    `durable_write_state=disabled-fixture`.

14. `solid-webui-direction`
    The negative fixture catalog and non-goals must block React or alternate
    renderer work.

15. `required-verification-recorded`
    The reviewer must provide every required verification command exactly.

## Required Verification Commands

The required commands for a ready review are:

```sh
zig build causal-app-facing-production-integration-fixtures -- validate --format json
zig build causal-schema-governance -- --format json
zig build causal-production-hardening-backlog -- --format json
zig build examples
zig build test
```

The tool should not run these commands. It records reviewer-supplied evidence
that they were run. Final branch verification still runs the relevant commands
fresh before claiming completion.

## Ready vs Blocked Semantics

`readiness_status=ready` means:

- the fixture catalog is supported and complete;
- reviewer decision is `approve`;
- verification evidence is recorded;
- the next branch may be an implementation-proposal branch.

`readiness_status=blocked` means:

- the artifact is still useful evidence;
- agents should cite failed checks directly;
- no implementation-proposal branch should start from that artifact.

Neither status grants mutation authority.

## Documentation Updates

The implementation should update:

- `packages/zigeffect/docs/app-facing-production-integration-readiness-review.md`
- `packages/zigeffect/docs/app-facing-production-integration-fixtures.md`
- `packages/zigeffect/docs/agent-observable-runtime.md`
- `packages/zigeffect/docs/schema-governance.md`
- `packages/zigeffect/docs/production-hardening-backlog.md`
- `packages/zigeffect/README.md`
- `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`

## Roadmap Handoff

After this branch, the backlog recommendation should become:

- `start-app-facing-production-integration-implementation-proposal`
- `codex/zigeffect-causal-app-facing-production-integration-implementation-proposal`

The delivered backlog should include a new item:
`app-facing-production-integration-readiness-review`.

The next branch should consume a ready readiness-review artifact and emit an
implementation proposal only. It should still preserve no app mutation, no live
telemetry, no durable production writes, NenDB-only durable direction, and
SolidJS/webui direction.
