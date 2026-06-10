# zigeffect Causal Production Telemetry CI Gate Application Boundary Design

## Goal

Create a guarded, record-only `causal-production-telemetry-ci-gate-application-boundary`
milestone that consumes ready CI gate readiness artifacts and defines the
reviewed application boundary for future CI telemetry gates.

This branch must not enable CI telemetry gate enforcement. It must not edit
GitHub Actions, create required status checks, execute uploads, read secrets,
ingest live telemetry, write NenDB, write durable production storage, add
non-NenDB adapter scope, add alternate workbench renderers, claim production
cluster readiness, or grant mutation authority.

## Context

The delivered gate readiness branch emits
`zigeffect.causal.production-telemetry-ci-gate-readiness.v1` and hands off to
`codex/zigeffect-causal-production-telemetry-ci-gate-application-boundary`.
That source artifact records advisory candidate gate signals, limited gate
semantics, release-gate verification evidence, negative fixtures, blocked
claims, and disabled enforcement flags.

The application boundary is the point where agents need a precise rule for
when a future CI telemetry gate proposal is merely planned, when it is blocked,
and what evidence would be required before any later artifact can honestly
record `applied=true`.

## Recommended Approach

Implement a deterministic Zig CLI:

```sh
zig build causal-production-telemetry-ci-gate-application-boundary -- \
  --from-gate-readiness <ci-gate-readiness.json> \
  plan|record-applied \
  --reason <reason>
```

The tool should emit text and JSON artifacts with schema:

`zigeffect.causal.production-telemetry-ci-gate-application-boundary.v1`

It should mirror the existing archive application pattern:

- `plan` records a reviewed boundary proposal and never marks applied.
- `record-applied` may mark `applied=true` only when reviewed workflow-change
  evidence, before evidence, after evidence, an after-workflow file, safe
  after-workflow checks, and all required post-application verification
  commands are present.
- Any missing source evidence, unsafe source flag, missing verification command,
  unsafe after workflow, or reviewer rejection yields a blocked artifact.

## Source Validation

The source CI gate readiness artifact must satisfy all of these:

- schema is `zigeffect.causal.production-telemetry-ci-gate-readiness.v1`;
- `gate_readiness_status="ready"`;
- `ready_for_next_branch=true`;
- reviewer decision is `approve`;
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
- readiness dimensions, candidate gate signals, gate semantics, negative
  fixtures, and blocked claims are present;
- source checks all pass;
- required verification commands are recorded and verified.

## Boundary Contract

The JSON artifact should include:

- schema, schema version, and source gate readiness path;
- source status and source workflow digest when available;
- mode: `plan` or `record-applied`;
- `gate_application_status`: `planned`, `applied`, or `blocked`;
- `applied`;
- reviewer, policy, and reason;
- workflow path, optional after-workflow path, and optional after-workflow
  digest;
- workflow changes, before evidence, after evidence;
- disabled authority fields:
  - `mutation_authority="none"` for planned or blocked artifacts;
  - `mutation_authority="record-only"` only when record-applied evidence fully
    passes;
  - `ci_gate_enabled=false`;
  - `ci_gate_enforcement_enabled=false`;
  - `ci_required_status_check_enabled=false`;
  - `ci_workflow_mutation_enabled=false`;
  - `ci_upload_execution_enabled=false`;
  - `production_telemetry_ingestion=false`;
  - `runtime_pipeline_enabled=false`;
  - `durable_write_enabled=false`;
  - `nendb_write_enabled=false`;
- source checks and boundary checks;
- application boundary rules;
- denied application claims;
- required and verified commands;
- blocked claims;
- `recommendation="start-production-telemetry-ci-gate-dry-run-policy"`;
- `next_branch_if_applied="codex/zigeffect-causal-production-telemetry-ci-gate-dry-run-policy"`.

The next branch name is intentionally a dry-run policy, not enforcement. It
should define advisory policy evaluation for candidate gate signals before any
required status check, workflow mutation, or live production telemetry path is
allowed.

## Application Boundary Rules

Record these rules in every artifact:

- A planned boundary is sufficient for design and agent review, not CI
  enforcement.
- `record-applied` requires reviewed workflow-change evidence, before evidence,
  after evidence, after-workflow content, safe after-workflow checks, and full
  post-application verification.
- Applied records are evidence records only; the tool itself does not mutate
  workflows.
- Future dry-run policy work may evaluate candidate signals locally or in CI
  artifacts, but it must not create required checks.
- CI evidence may support agent triage, not production health, capacity,
  customer-impact, deployment success, or production cluster-readiness claims.

## After-Workflow Safety Checks

If `record-applied` is used, the provided after-workflow file must still show:

- the existing `zigeffect causal` workflow identity;
- pull request, master push, and workflow dispatch triggers;
- read-only contents permissions;
- Zig 0.16 setup;
- `zig build causal-test`;
- `zig build causal-artifacts`;
- `zig build release-gate --summary none`;
- `zig build release-gate-report`;
- failure-only CI handoff and artifact upload;
- bounded artifact retention of fourteen days;
- causal JSON/text and release-gate JSON/text artifact globs.

It must not contain:

- secret references;
- write-all, contents write, or id-token write permissions;
- schedule triggers;
- production telemetry tokens;
- OTLP collector endpoint configuration;
- deployment actions;
- required status check configuration;
- phrases that claim production telemetry gate enforcement is active.

## Negative Fixtures

Record deny fixtures for:

- blocked source gate readiness;
- missing source approval;
- missing source release-gate verification;
- `plan` mode attempting `applied=true`;
- `record-applied` without workflow-change evidence;
- `record-applied` without before evidence;
- `record-applied` without after evidence;
- `record-applied` without after-workflow content;
- unsafe after-workflow with secrets or write permissions;
- unsafe after-workflow with production telemetry endpoint or token;
- unsafe after-workflow with required status checks;
- missing post-application verification;
- CI gate enforcement enabled;
- required status check enabled;
- public upload claim;
- production health or cluster readiness claim;
- non-NenDB durable adapter scope;
- alternate renderer scope.

## Testing

The implementation should include:

- unit tests for constants and option parsing;
- TDD red test for the missing schema constant before full implementation;
- plan-mode report test that proves `applied=false` and enforcement disabled;
- record-applied positive test requiring workflow changes, before/after
  evidence, after-workflow content, and all verification commands;
- blocked record-applied tests for missing evidence and unsafe after workflow;
- default output path test that replaces the terminal
  `-ci-gate-readiness.json` suffix with
  `-ci-gate-application-boundary.json`;
- build-wired help command;
- real artifact generation from the ready gate readiness artifact;
- schema governance and production hardening backlog updates.

## Non-Goals

- No CI workflow edits.
- No artifact upload execution changes.
- No required status checks.
- No CI telemetry gate enforcement.
- No live telemetry ingestion.
- No production runtime pipeline.
- No NenDB writes.
- No durable production writes.
- No Cockroach or non-NenDB adapter work.
- No React or alternate renderer work.
- No hosted production dashboard.
- No mutation authority beyond record-only evidence for a fully verified
  external application record.
