# zigeffect Causal Production Telemetry CI Gate Dry-Run Policy Design

## Goal

Create a record-only `causal-production-telemetry-ci-gate-dry-run-policy`
milestone that consumes CI gate application boundary artifacts and defines the
advisory policy rules for future dry-run evaluation of CI telemetry gate
candidate signals.

This branch must not enable CI gate enforcement, create required status checks,
mutate workflows, execute artifact uploads, read secrets, ingest live
telemetry, write NenDB, write durable production storage, claim production
readiness, or grant mutation authority.

## Context

The delivered gate application boundary emits
`zigeffect.causal.production-telemetry-ci-gate-application-boundary.v1`. It
records planned, applied, or blocked boundary evidence, and only permits
`applied=true` when reviewed workflow-change evidence, before evidence, after
evidence, safe after-workflow checks, and post-application verification
commands exist.

The next safe step is not enforcement. It is a policy artifact that tells
agents how a future dry-run evaluator may interpret candidate CI gate signals
without changing CI pass/fail behavior.

## Recommended Approach

Implement a deterministic Zig CLI:

```sh
zig build causal-production-telemetry-ci-gate-dry-run-policy -- \
  --from-gate-application-boundary <gate-application-boundary.json> \
  approve|reject \
  --reason <reason> \
  --verified-command <command>...
```

The tool should emit text and JSON artifacts with schema:

`zigeffect.causal.production-telemetry-ci-gate-dry-run-policy.v1`

It should accept source boundary artifacts when:

- source schema is
  `zigeffect.causal.production-telemetry-ci-gate-application-boundary.v1`;
- source status is `planned` or `applied`, not `blocked`;
- source mode is `plan` or `record-applied`;
- `applied=false` has `mutation_authority="none"`;
- `applied=true` has `mutation_authority="record-only"`;
- source CI gate, enforcement, required status check, workflow mutation, upload
  execution, live telemetry, runtime, durable, and NenDB flags remain disabled;
- source boundary checks contain no failures;
- application boundary rules, denied application claims, negative fixtures, and
  blocked claims are present.

## Output Contract

The JSON artifact should include:

- schema, schema version, and source gate application boundary path;
- source boundary status, mode, applied state, and mutation authority;
- reviewer decision, reviewer id, policy id, and reason;
- `dry_run_policy_status`: `ready` or `blocked`;
- `ready_for_next_branch`;
- disabled authority fields:
  - `applied=false`;
  - `mutation_authority="none"`;
  - `ci_gate_enabled=false`;
  - `ci_gate_enforcement_enabled=false`;
  - `ci_required_status_check_enabled=false`;
  - `ci_workflow_mutation_enabled=false`;
  - `ci_upload_execution_enabled=false`;
  - `production_telemetry_ingestion=false`;
  - `runtime_pipeline_enabled=false`;
  - `durable_write_enabled=false`;
  - `nendb_write_enabled=false`;
- dry-run policy rules;
- candidate signal policies;
- evidence requirements;
- negative fixtures;
- checks;
- required and verified commands;
- blocked claims;
- `recommendation="start-production-telemetry-ci-gate-dry-run-evaluator"`;
- `next_branch_if_ready="codex/zigeffect-causal-production-telemetry-ci-gate-dry-run-evaluator"`.

## Candidate Signal Policies

Record these policies with `evaluation_mode="dry-run"`,
`enforcement_enabled=false`, `required_status_check_enabled=false`, and
`failure_effect="advisory"`:

- `release-gate-artifact-present`: release-gate text and JSON reports exist.
- `causal-artifact-schema-parse`: causal JSON artifacts parse as known schemas.
- `archive-policy-conformance`: archived evidence follows the archive evidence
  policy.
- `redaction-retention-conformance`: evidence carries redaction and bounded
  retention metadata.
- `ci-handoff-present`: failure handoff evidence exists for agent triage.
- `boundary-source-valid`: the application boundary source remains planned or
  record-only applied.

## Evidence Requirements

A future dry-run evaluator may only read local or CI artifact files already
allowed by the archive evidence policy:

- causal JSON and text artifacts;
- release-gate JSON and text reports;
- CI handoff text;
- source preview JSON;
- this policy artifact and its source chain.

It may not read secrets, network endpoints, live telemetry collectors,
deployment credentials, production databases, or non-NenDB durable stores.

## Negative Fixtures

Record deny fixtures for:

- blocked source application boundary;
- source boundary missing application rules;
- source boundary claiming CI gate enforcement;
- required status check enabled;
- workflow mutation enabled by the tool;
- missing release-gate verification;
- missing release-gate-report verification;
- dry-run policy claiming CI pass/fail behavior;
- dry-run policy claiming production health;
- public artifact upload claim;
- retention over fourteen days;
- secret-shaped evidence;
- live telemetry ingestion;
- durable write or NenDB write claim;
- non-NenDB durable adapter scope;
- alternate renderer scope.

## Handoff

If ready, this branch unlocks only:

`codex/zigeffect-causal-production-telemetry-ci-gate-dry-run-evaluator`

That next branch should evaluate the dry-run policy against bounded local/CI
artifacts and produce advisory pass/fail findings. It must still avoid CI
required status checks, enforcement, workflow mutation, live telemetry, durable
writes, and mutation authority.

## Testing

The implementation should include:

- unit tests for constants and option parsing;
- TDD red test for the missing schema constant;
- ready and rejected policy report tests;
- blocked source boundary test;
- missing verification command test;
- output path regression test replacing
  `-ci-gate-application-boundary.json` with
  `-ci-gate-dry-run-policy.json`;
- build-wired help command;
- real artifact generation from the planned gate application boundary artifact;
- schema governance, backlog, docs, and roadmap updates.

## Non-Goals

- No CI workflow edits.
- No required status checks.
- No CI telemetry gate enforcement.
- No artifact upload execution changes.
- No live telemetry ingestion.
- No production runtime pipeline.
- No NenDB writes.
- No durable production writes.
- No Cockroach or non-NenDB adapter work.
- No React or alternate renderer work.
- No hosted production dashboard.
- No mutation authority.
