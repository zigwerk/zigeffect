# Production Telemetry CI Gate Advisory CI Report

`causal-production-telemetry-ci-gate-advisory-ci-report` consumes a ready or
advisory production telemetry CI gate dry-run evaluator artifact and renders
local JSON and text reports for reviewers and agents. It summarizes evaluator
signals, advisory findings, next queries, checks, blocked claims, and the
publication boundary before any CI report application work.

It does not enable CI gate enforcement, create required status checks, mutate
GitHub Actions workflows, upload CI artifacts, write GitHub step summaries,
post pull request comments, ingest live telemetry, call networks, write NenDB,
write durable production storage, orchestrate production clusters, claim
production readiness, or grant mutation authority.

## Command

Summarize a ready or advisory dry-run evaluator artifact:

```sh
cd packages/zigeffect
zig build causal-production-telemetry-ci-gate-advisory-ci-report -- \
  --from-evaluator ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures-nendb-retention-fixtures-workbench-readonly-preview-ci-artifact-preview-ci-harness-boundary-ci-gate-dry-run-evaluator.json \
  summarize \
  --reason "CI advisory report reviewed"
```

Use `--by` to name the reviewer, `--policy` to name the review policy, and
`--out-prefix` to choose an explicit output prefix. Without `--out-prefix`, the
tool writes sibling `*-ci-gate-advisory-ci-report.json` and `.txt` files beside
the source evaluator artifact.

## Source Evaluator

The source artifact must use schema
`zigeffect.causal.production-telemetry-ci-gate-dry-run-evaluator.v1`, have
`ready_for_next_branch=true`, and have `evaluation_status="ready"` or
`evaluation_status="advisory-findings"`.

The source must preserve disabled authority:

- `ci_gate_enabled=false`
- `ci_gate_enforcement_enabled=false`
- `ci_required_status_check_enabled=false`
- `ci_workflow_mutation_enabled=false`
- `ci_upload_execution_enabled=false`
- `production_telemetry_ingestion=false`
- `live_exporter_enabled=false`
- `network_send_enabled=false`
- `runtime_pipeline_enabled=false`
- `durable_write_enabled=false`
- `nendb_write_enabled=false`

The source must include signal evaluations, checks, next queries, and blocked
claims. Blocked findings or enabled authority produce a blocked advisory report.

## Statuses

- `ready`: source evaluator is ready, no advisory findings are present, and
  all report checks pass.
- `advisory`: source evaluator is reportable and contains advisory findings.
- `blocked`: source evaluator is invalid, blocked, missing required sections,
  or violates the disabled authority boundary.

`ready_for_next_branch=true` for `ready` and `advisory`. It is false for
`blocked`.

## Publication Boundary

The tool only writes local JSON and text artifacts. It records publication
channels so a later boundary branch can review them:

- `local-json-artifact`: allowed and executed by this tool
- `local-text-artifact`: allowed and executed by this tool
- `ci-upload-artifact`: not allowed and not executed
- `github-step-summary`: not allowed and not executed
- `pull-request-comment`: not allowed and not executed

This means the report is reviewer guidance only. CI upload, GitHub summary,
pull request comment, and required status check behavior all remain future
reviewed application work.

## Handoff

Ready or advisory report artifacts hand off to
`codex/zigeffect-causal-production-telemetry-ci-gate-advisory-ci-report-application-boundary`.
That branch is now delivered and records planned, applied, or blocked report
publication boundary evidence. Applied boundary artifacts hand off to
`codex/zigeffect-causal-production-telemetry-ci-gate-advisory-ci-report-publication-policy`.
That publication policy is now delivered and hands off to
`codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-policy`.
Required-status-check policy work must still preserve disabled workflow
mutation by the tool, artifact upload execution by the tool, required checks,
live telemetry, durable writes, NenDB writes, production cluster claims, and
mutation authority unless separate reviewed evidence records otherwise.

## Verification

```sh
cd packages/zigeffect
zig test tools/causal_production_telemetry_ci_gate_advisory_ci_report.zig
zig build causal-production-telemetry-ci-gate-advisory-ci-report -- --help
zig build causal-production-telemetry-ci-gate-advisory-ci-report -- \
  --from-evaluator ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures-nendb-retention-fixtures-workbench-readonly-preview-ci-artifact-preview-ci-harness-boundary-ci-gate-dry-run-evaluator.json \
  summarize \
  --reason "CI advisory report reviewed"
zig build causal-production-telemetry-ci-gate-advisory-ci-report -- \
  --from-evaluator ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-dry-run-evaluator-negative.json \
  summarize \
  --reason "negative CI advisory report path" \
  --out-prefix ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-advisory-ci-report-negative
zig build causal-schema-governance -- --format json
zig build causal-production-hardening-backlog -- --format json
zig build examples
zig build test
cd ../..
bun run check
bun run zig:test
git diff --check
```
