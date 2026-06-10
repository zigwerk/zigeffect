# zigeffect Causal Production Telemetry CI Gate Readiness Design

## Goal

Create a record-only `causal-production-telemetry-ci-gate-readiness` milestone
that consumes ready CI archive evidence policy artifacts and proves the project
has the evidence, semantics, and verification commands needed to design a
future CI telemetry gate.

This branch must not enable a CI gate. It must not mutate GitHub Actions,
execute artifact uploads, introduce required status checks, read secrets,
ingest live telemetry, write NenDB, write durable production storage, add
non-NenDB adapter scope, add alternate workbench renderers, or grant mutation
authority.

## Context

The delivered archive evidence policy branch now emits
`zigeffect.causal.production-telemetry-ci-archive-evidence-policy.v1` and
hands off to
`codex/zigeffect-causal-production-telemetry-ci-gate-readiness`.

The source policy already defines allowed archive evidence classes, required
metadata, interpretation rules, negative fixtures, and blocked claims. It also
keeps `ci_gate_enabled=false`, `ci_upload_execution_enabled=false`,
`ci_workflow_mutation_enabled=false`, `production_telemetry_ingestion=false`,
`runtime_pipeline_enabled=false`, `durable_write_enabled=false`, and
`nendb_write_enabled=false`.

The existing clustering-aware CI workflow already runs
`zig build release-gate --summary none`. That build step depends on the normal
test step, public API review, storage conformance, property crash testing,
performance bounds, examples, causal tests, causal artifacts, and
`release-gate-report`, which writes `.zig-cache/release-gate` text and JSON
artifacts.

## Recommended Approach

Implement a new deterministic Zig tool:

```sh
zig build causal-production-telemetry-ci-gate-readiness -- \
  --from-archive-evidence-policy <archive-evidence-policy.json> \
  approve|reject \
  --reason <reason> \
  --verified-command <command>...
```

The tool should emit text and JSON artifacts with schema
`zigeffect.causal.production-telemetry-ci-gate-readiness.v1`.

It should accept a source archive evidence policy only when:

- source schema is `zigeffect.causal.production-telemetry-ci-archive-evidence-policy.v1`;
- source status is `ready`;
- `ready_for_next_branch=true`;
- source authority flags remain disabled;
- source evidence classes include causal JSON, causal text, release-gate JSON,
  release-gate text, CI handoff text, and source preview JSON;
- source metadata includes schema, source artifact path, workflow digest, run
  context, commit or branch ref, redaction state, retention days, visibility
  class, consumer role, and interpretation scope;
- source negative fixtures include secret-shaped content denial, retention over
  fourteen days denial, public upload denial, telemetry gate claim denial,
  production health denial, non-NenDB durable denial, and alternate renderer
  denial;
- source blocked claims remain non-empty;
- required verification commands are recorded.

## Output Contract

The JSON artifact should include:

- `schema`, `schema_version`, and source artifact path;
- `gate_readiness_status`: `ready` or `blocked`;
- `ready_for_next_branch`;
- reviewer decision, reviewer id, policy id, and reason;
- source policy status and source workflow digest;
- disabled authority fields:
  - `applied=false`
  - `mutation_authority="none"`
  - `ci_gate_enabled=false`
  - `ci_gate_enforcement_enabled=false`
  - `ci_required_status_check_enabled=false`
  - `ci_workflow_mutation_enabled=false`
  - `ci_upload_execution_enabled=false`
  - `production_telemetry_ingestion=false`
  - `runtime_pipeline_enabled=false`
  - `durable_write_enabled=false`
  - `nendb_write_enabled=false`
- readiness dimensions;
- candidate gate signals;
- gate semantics;
- negative fixtures;
- checks;
- required and verified commands;
- blocked claims;
- `recommendation="start-production-telemetry-ci-gate-application-boundary"`;
- `next_branch_if_ready="codex/zigeffect-causal-production-telemetry-ci-gate-application-boundary"`.

## Readiness Dimensions

The readiness report should define these dimensions:

- `source-policy-ready`: the archive evidence policy is approved and ready.
- `archive-evidence-bounded`: evidence class and metadata contracts exist.
- `release-gate-contract-present`: `zig build release-gate --summary none`
  and `release-gate-report` are verified.
- `cluster-workflow-aligned`: the existing release gate remains the clustering
  execution body.
- `gate-semantics-limited`: future gates can evaluate artifact/schema/policy
  readiness only, not production health.
- `redaction-retention-reviewed`: redaction state and retention days are
  required before agent use.
- `human-review-before-application`: a later branch must review workflow
  changes before any gate application claim.

## Candidate Gate Signals

Candidate signals are design-only. They should be recorded with
`enforcement_enabled=false`:

- `release-gate-artifact-present`: release-gate text and JSON artifacts exist
  after `zig build release-gate --summary none`.
- `causal-artifact-schema-parse`: causal JSON artifacts use known schemas.
- `archive-policy-conformance`: archived evidence carries required metadata
  and allowed extensions.
- `redaction-retention-conformance`: archived evidence is redacted and bounded
  to the approved retention window.
- `ci-handoff-present`: failure handoff text exists for agent triage.

These candidate signals may support future CI gate design. They do not fail CI
in this branch.

## Negative Fixtures

The tool should record deny fixtures for:

- blocked or missing source archive evidence policy;
- missing `zig build release-gate --summary none` verification;
- missing `zig build release-gate-report` verification;
- attempting to set `ci_gate_enabled=true`;
- claiming CI pass/fail semantics are already active;
- claiming production health, production capacity, customer impact, deployment
  success, live telemetry coverage, or production cluster readiness;
- missing redaction or retention metadata;
- retention over fourteen days;
- public upload claims;
- non-NenDB durable adapter scope;
- React or alternate renderer scope.

## Handoff

If ready, this branch unlocks only:

`codex/zigeffect-causal-production-telemetry-ci-gate-application-boundary`

That next branch should design the reviewed application boundary for a future
CI telemetry gate. It must still separate a proposed workflow/gate change from
any applied state and require before/after verification if it ever records
application.

## Testing

The implementation should follow the existing TDD pattern for causal production
telemetry tools:

- unit tests for constants, option parsing, ready and rejected reports;
- regression test for safe output path length, replacing the
  `-ci-archive-evidence-policy` suffix with `-ci-gate-readiness`;
- blocked-source test;
- missing verification command test;
- build-wired help command;
- real artifact generation from the ready archive evidence policy artifact;
- governance/backlog tests and docs updates.

## Non-Goals

- No CI workflow edits.
- No artifact upload execution changes.
- No required status checks.
- No live telemetry ingestion.
- No production runtime pipeline.
- No NenDB writes.
- No durable production writes.
- No Cockroach or non-NenDB adapter work.
- No React or alternate renderer work.
- No production dashboard hosting.
- No mutation authority.
