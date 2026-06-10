# Production Telemetry CI Gate Application Boundary

`causal-production-telemetry-ci-gate-application-boundary` consumes a ready
production telemetry CI gate readiness artifact and emits a guarded,
record-only boundary artifact for future CI telemetry gate work.

It does not edit `.github/workflows/zigeffect-causal.yml`, enable CI telemetry
gate enforcement, create required status checks, execute artifact uploads,
configure secrets, ingest live telemetry, write NenDB, write durable
production storage, orchestrate production clusters, or grant production
mutation authority.

## Command

Plan the boundary from the ready gate readiness artifact:

```sh
cd packages/zigeffect
zig build causal-production-telemetry-ci-gate-application-boundary -- \
  --from-gate-readiness ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures-nendb-retention-fixtures-workbench-readonly-preview-ci-artifact-preview-ci-harness-boundary-ci-gate-readiness.json \
  plan \
  --reason "CI gate application boundary planned"
```

Use `record-applied` only for a separately reviewed workflow change that has
workflow-change evidence, before evidence, after evidence, an after-workflow
file, and all post-application verification commands.

## Modes

- `plan`: emits `gate_application_status="planned"`, `applied=false`, and
  `mutation_authority="none"`.
- `record-applied`: emits `gate_application_status="applied"` only when every
  source, evidence, after-workflow, and verification check passes. Otherwise it
  emits `blocked` and keeps `applied=false`.

Applied records are evidence records only. This command never mutates the
workflow itself.

## Source Evidence

The source artifact must use schema
`zigeffect.causal.production-telemetry-ci-gate-readiness.v1`, have
`gate_readiness_status="ready"`, set `ready_for_next_branch=true`, preserve
disabled enforcement and write flags, carry readiness dimensions, candidate
gate signals, gate semantics, negative fixtures, blocked claims, and record all
required verification commands.

## Boundary Rules

The report records that planned evidence can feed dry-run policy work only. It
also records that `record-applied` requires reviewed workflow-change evidence,
before evidence, after evidence, after-workflow content, safe after-workflow
checks, and full post-application verification.

Future work may evaluate candidate signals as a dry run. This branch does not
approve CI required checks, CI pass/fail enforcement, live telemetry, durable
writes, NenDB writes, production health claims, deployment success claims, or
production cluster readiness.

## Verification

```sh
cd packages/zigeffect
zig test tools/causal_production_telemetry_ci_gate_application_boundary.zig
zig build causal-production-telemetry-ci-gate-application-boundary -- --help
zig build causal-production-telemetry-ci-gate-application-boundary -- \
  --from-gate-readiness ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures-nendb-retention-fixtures-workbench-readonly-preview-ci-artifact-preview-ci-harness-boundary-ci-gate-readiness.json \
  plan \
  --reason "CI gate application boundary planned"
zig build causal-production-telemetry-ci-gate-application-boundary -- \
  --from-gate-readiness ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures-nendb-retention-fixtures-workbench-readonly-preview-ci-artifact-preview-ci-harness-boundary-ci-gate-readiness.json \
  record-applied \
  --reason "negative CI gate application boundary path" \
  --out-prefix ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-application-boundary-negative
zig build causal-schema-governance -- --format json
zig build causal-production-hardening-backlog -- --format json
zig build examples
zig build test
cd ../..
bun run check
bun run zig:test
git diff --check
```
