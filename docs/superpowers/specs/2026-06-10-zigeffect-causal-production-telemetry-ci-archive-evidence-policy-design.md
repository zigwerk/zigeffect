# zigeffect Causal Production Telemetry CI Archive Evidence Policy Design

## Summary

Add a production telemetry CI archive evidence policy contract for zigeffect.
The contract consumes a
`zigeffect.causal.production-telemetry-ci-archive-application.v1` artifact and
emits a record-only policy report that defines what archived CI causal
evidence is allowed to mean, who may consume it, which evidence classes are
allowed, and which conclusions remain blocked.

This branch does not edit `.github/workflows/zigeffect-causal.yml`, run CI,
upload artifacts, enable CI gates, configure secrets, ingest live telemetry,
write NenDB, write durable state, deploy infrastructure, or grant mutation
authority.

## Branch

- Branch:
  `codex/zigeffect-causal-production-telemetry-ci-archive-evidence-policy`
- Schema:
  `zigeffect.causal.production-telemetry-ci-archive-evidence-policy.v1`
- Command:
  `zig build causal-production-telemetry-ci-archive-evidence-policy`
- Recommendation after delivery:
  `start-production-telemetry-ci-gate-readiness`
- Next branch if ready:
  `codex/zigeffect-causal-production-telemetry-ci-gate-readiness`

## Context

The archive application milestone created a guarded application artifact. In
`plan` mode it records that a reviewed archive application can be prepared
from a ready CI harness boundary. In `record-applied` mode it can only set
`applied=true` when real workflow-change evidence, before evidence, after
evidence, safe after-workflow checks, and post-application verification
commands exist.

The evidence policy milestone answers the next question: "Once CI archive
evidence exists, what can agents and humans safely infer from it?" This must be
defined before any CI telemetry gate readiness branch, because gate work must
not accidentally treat archived artifacts as production telemetry, capacity
evidence, public evidence, or mutation authority.

## Goals

1. Add a schema-governed CI archive evidence policy record.
2. Consume a CI archive application artifact from disk.
3. Accept a planned or applied archive application as a valid source for policy
   design, while recording whether the source application is actually applied.
4. Require explicit reviewer decision and non-empty reason.
5. Require explicit verification command evidence before policy status can be
   `ready`.
6. Verify the source application schema, status, authority boundary, source
   checks, blocked claims, and source verification posture.
7. Define allowed evidence classes:
   - causal text report;
   - causal JSON artifact;
   - causal DOT graph;
   - release-gate text report;
   - release-gate JSON report;
   - CI handoff text;
   - source workbench/preview JSON.
8. Define required evidence metadata:
   - schema;
   - source artifact path;
   - workflow digest;
   - run context reference;
   - commit or branch reference;
   - redaction state;
   - retention days;
   - visibility class;
   - consumer role;
   - interpretation scope.
9. Define interpretation rules:
   - archived evidence may support local diagnosis, failure triage, causal
     query hints, before/after comparison, and release-gate debugging;
   - archived evidence may not prove production health, capacity, no-defect
     claims, live telemetry coverage, customer impact, deployment success, or
     CI gate pass/fail semantics.
10. Define negative fixtures that block policy readiness:
    - secret-shaped content visible;
    - missing source path;
    - retention over 14 days;
    - public upload claim;
    - telemetry gate claim;
    - production health claim;
    - non-NenDB durable scope;
    - alternate renderer scope.
11. Preserve disabled authority:
    `applied=false`, `mutation_authority="none"`,
    `ci_gate_enabled=false`, `ci_upload_execution_enabled=false`,
    `ci_workflow_mutation_enabled=false`, `production_telemetry_ingestion=false`,
    `live_exporter_enabled=false`, `network_send_enabled=false`,
    `collector_endpoint_configured=false`, `otlp_serialization_enabled=false`,
    `runtime_pipeline_enabled=false`, `durable_write_enabled=false`, and
    `nendb_write_enabled=false`.
12. Update schema governance, production hardening backlog, README,
    operations, roadmap, completion audit, archive application docs, and the
    master roadmap.

## Non-Goals

- No workflow mutation.
- No artifact upload execution.
- No GitHub artifact storage inspection.
- No CI gate, threshold, required check, protected-branch rule, or failure
  semantics.
- No live telemetry ingestion, runtime telemetry pipeline, exporter network
  send, OTLP serialization, collector endpoint, or production instrumentation.
- No NenDB writes, durable writes, production retention execution, backup,
  restore, compaction, or migration.
- No hosted dashboard, alert delivery, rollout automation, production cluster
  orchestration, RBAC enforcement, or encrypted byte implementation.
- No non-NenDB durable adapter scope and no Cockroach durable scope.
- No React renderer or alternate renderer scope.

## Recommended Approach

Create one deterministic Zig tool,
`causal-production-telemetry-ci-archive-evidence-policy`, that mirrors recent
record-only policy tools and source-artifact review tools:

1. Read a CI archive application JSON artifact.
2. Parse and validate
   `zigeffect.causal.production-telemetry-ci-archive-application.v1`.
3. Fail closed unless the source application status is `planned` or `applied`
   and all source checks are non-failing.
4. Record whether the source application is actually applied, but do not
   require application for policy design.
5. Require reviewer `approve` or `reject`, non-empty reason, and required
   verification command evidence.
6. Emit a JSON/text report with evidence classes, metadata fields,
   interpretation rules, negative fixtures, checks, blocked claims, required
   commands, recorded commands, and next branch.
7. Mark the policy `ready` only when reviewer decision is `approve`, source
   evidence is valid, policy fixtures are internally consistent, and every
   required verification command is recorded.

This approach lets agents reason safely about archived CI evidence before a
later gate-readiness branch decides whether any policy can become a CI gate.

Rejected approaches:

- Enabling gates in this branch. Evidence meaning must exist before threshold
  or fail/pass semantics.
- Requiring `applied=true` source application for policy design. Planned
  archive application evidence is enough to define interpretation policy, while
  later gate readiness can require an applied archive if needed.
- Inspecting GitHub artifact storage. This policy must remain deterministic
  and local.
- Treating archive evidence as production telemetry. CI artifacts are local/CI
  diagnostic records, not production observations.

## Command Contract

```sh
cd packages/zigeffect
zig build causal-production-telemetry-ci-archive-evidence-policy -- \
  --from-archive-application ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures-nendb-retention-fixtures-workbench-readonly-preview-ci-artifact-preview-ci-harness-boundary-ci-archive-application.json \
  approve \
  --reason "CI archive evidence policy reviewed" \
  --verified-command "zig build causal-production-telemetry-ci-archive-application" \
  --verified-command "zig build causal-artifacts" \
  --verified-command "zig build release-gate --summary none" \
  --verified-command "zig build causal-schema-governance -- --format json" \
  --verified-command "zig build causal-production-hardening-backlog -- --format json" \
  --verified-command "zig build examples" \
  --verified-command "zig build test"
```

Parser rules:

- `--from-archive-application <ci-archive-application.json>` is required.
- Decision must be `approve` or `reject`.
- `--reason <reason>` is required and non-empty.
- `--by <actor>` defaults to `ci-archive-evidence-policy-reviewer`.
- `--policy <policy>` defaults to
  `manual-production-telemetry-ci-archive-evidence-policy`.
- `--verified-command <command>` may be supplied multiple times.
- `--out-prefix <path-prefix>` overrides default output paths.

## Testing

- Unit tests cover constants, option parsing, ready policy reports, rejected
  policy reports, and blocked source application evidence.
- Red path: before build wiring, `zig build
  causal-production-telemetry-ci-archive-evidence-policy -- --help` must fail
  with an unknown step.
- Green path:
  `zig test tools/causal_production_telemetry_ci_archive_evidence_policy.zig`,
  ready policy command, rejected policy command,
  `zig build causal-schema-governance -- --format json`,
  `zig build causal-production-hardening-backlog -- --format json`,
  `zig build examples`, `zig build test`, `bun run check`,
  `bun run zig:test`, and `git diff --check`.

