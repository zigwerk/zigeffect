# Production Telemetry CI Gate Advisory CI Report Application Boundary

`causal-production-telemetry-ci-gate-advisory-ci-report-application-boundary`
consumes a ready or advisory CI gate advisory CI report artifact and emits a
guarded, record-only application boundary artifact for report publication
evidence.

It does not publish CI reports, upload artifacts, write GitHub step summaries,
post pull request comments, mutate workflows, create required status checks,
enable CI gate enforcement, ingest live telemetry, call networks, write NenDB,
write durable production storage, orchestrate production clusters, or grant
production mutation authority.

## Command

Plan the boundary from an advisory CI report artifact:

```sh
cd packages/zigeffect
zig build causal-production-telemetry-ci-gate-advisory-ci-report-application-boundary -- \
  --from-report ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures-nendb-retention-fixtures-workbench-readonly-preview-ci-artifact-preview-ci-harness-boundary-ci-gate-advisory-ci-report.json \
  plan \
  --reason "CI advisory report application boundary planned"
```

Use `record-applied` only for a separately reviewed publication/update that has
publication-change evidence, before evidence, after evidence, local
report-after content, and all post-application verification commands.

Use `--out-prefix <path-prefix>` to choose an explicit artifact prefix. Without
`--out-prefix`, the tool writes sibling `.json` and `.txt` artifacts beside the
source advisory CI report. Deeply chained source artifact names are compacted to
a deterministic filesystem-safe prefix with a short source-path digest.

## Modes

- `plan`: emits `report_application_status="planned"`, `applied=false`, and
  `mutation_authority="none"` when the source report is ready or advisory.
- `record-applied`: emits `report_application_status="applied"` only when
  source checks, publication evidence, before/after evidence, report-after
  safety, and verification evidence all pass. Otherwise it emits `blocked` and
  keeps `applied=false`.

Applied records are evidence records only. This command never publishes the
report or mutates CI.

## Source Report

The source artifact must use schema
`zigeffect.causal.production-telemetry-ci-gate-advisory-ci-report.v1`, have
`report_status="ready"` or `report_status="advisory"`, and set
`ready_for_next_branch=true`.

The source must preserve disabled authority:

- `ci_gate_enabled=false`
- `ci_gate_enforcement_enabled=false`
- `ci_required_status_check_enabled=false`
- `ci_workflow_mutation_enabled=false`
- `ci_upload_execution_enabled=false`
- `ci_report_publication_enabled=false`
- `github_step_summary_write_enabled=false`
- `pull_request_comment_enabled=false`
- `production_telemetry_ingestion=false`
- `network_send_enabled=false`
- `runtime_pipeline_enabled=false`
- `durable_write_enabled=false`
- `nendb_write_enabled=false`

Source publication channels must be present and external channels such as CI
upload, GitHub step summary, and pull request comment must remain not allowed
and not executed by the source report tool.

## Report-After Safety

`--report-after` may point only to explicit local `.txt`, `.md`, or `.json`
files. The file must contain `zigeffect`, `causal`, `advisory`, and `report`.
It is blocked when it contains markers for required checks, CI gate
enablement, step-summary writes, PR comments, upload execution, live telemetry,
network send, durable writes, NenDB writes, production health, production
cluster readiness, mutation authority grants, secrets, production telemetry
tokens, or OTLP endpoints.

## Handoff

Applied application-boundary artifacts hand off to
`codex/zigeffect-causal-production-telemetry-ci-gate-advisory-ci-report-publication-policy`.
That branch is now delivered and hands off to
`codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-policy`.
The readiness branch must still treat required status checks as future
readiness evidence, not enforcement.

## Verification

```sh
cd packages/zigeffect
zig test tools/causal_production_telemetry_ci_gate_advisory_ci_report_application_boundary.zig
zig build causal-production-telemetry-ci-gate-advisory-ci-report-application-boundary -- --help
zig build causal-production-telemetry-ci-gate-advisory-ci-report-application-boundary -- \
  --from-report ../../.zig-cache/causal-artifacts/production-telemetry-capture-fixtures-readiness-review-implementation-proposal-exporter-boundary-local-pipeline-fixtures-nendb-retention-fixtures-workbench-readonly-preview-ci-artifact-preview-ci-harness-boundary-ci-gate-advisory-ci-report.json \
  plan \
  --reason "CI advisory report application boundary planned"
zig build causal-production-telemetry-ci-gate-advisory-ci-report-application-boundary -- \
  --from-report ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-advisory-ci-report-negative.json \
  record-applied \
  --reason "negative CI advisory report application boundary path" \
  --out-prefix ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-advisory-ci-report-application-boundary-negative
zig build causal-schema-governance -- --format json
zig build causal-production-hardening-backlog -- --format json
zig build examples
zig build test
cd ../..
bun run check
bun run zig:test
git diff --check
```
