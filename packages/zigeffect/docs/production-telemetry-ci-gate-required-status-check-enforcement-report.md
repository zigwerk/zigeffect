# Production Telemetry CI Gate Required Status Check Enforcement Report

Schema:
`zigeffect.causal.production-telemetry-ci-gate-required-status-check-enforcement-report.v1`

`causal-production-telemetry-ci-gate-required-status-check-enforcement-report`
consumes a required-status-check enforcement evaluator artifact and renders
local JSON and text reports for reviewers and agents. It summarizes evaluator
status, signals, findings, checks, blocked claims, publication channels, and
the next branch handoff before any CI publication or required-status-check
application work.

The report is record-only. It does not mutate GitHub, branch protection,
workflows, check runs, CI uploads, GitHub step summaries, pull-request
comments, live telemetry, runtime storage, durable stores, NenDB, non-NenDB
adapters, renderer choices, or production systems. It grants no mutation
authority.

## Command

Summarize a ready or advisory enforcement evaluator artifact:

```sh
cd packages/zigeffect
zig build causal-production-telemetry-ci-gate-required-status-check-enforcement-report -- \
  --from-evaluator ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-enforcement-evaluator.json \
  summarize \
  --reason "required status check enforcement report reviewed"
```

Negative path:

```sh
cd packages/zigeffect
zig build causal-production-telemetry-ci-gate-required-status-check-enforcement-report -- \
  --from-evaluator ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-enforcement-evaluator-negative.json \
  summarize \
  --reason "negative required status check enforcement report path" \
  --out-prefix ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-enforcement-report-negative
```

Use `--by` to name the reviewer, `--policy` to name the report policy, and
`--out-prefix` to choose an explicit output prefix. Without `--out-prefix`,
the tool writes sibling `*-required-status-check-enforcement-report.json` and
`.txt` artifacts beside the source evaluator artifact.

## Source Evaluator

The source artifact must use schema
`zigeffect.causal.production-telemetry-ci-gate-required-status-check-enforcement-evaluator.v1`.

Reportable source states are:

- `ready`, when `ready_for_next_branch=true` and no blocked findings exist;
- `advisory-findings`, when reviewer-visible advisory findings need to be
  carried into the report application-boundary review;
- `blocked`, which still renders a local blocked report so reviewers can see
  the preserved blocked findings and failed checks.

The source and report must preserve disabled authority:

- `ci_gate_enabled=false`
- `ci_gate_enforcement_enabled=false`
- `ci_required_status_check_enabled=false`
- `ci_workflow_mutation_enabled=false`
- `ci_upload_execution_enabled=false`
- `ci_report_publication_enabled=false`
- `github_api_mutation_enabled=false`
- `github_check_run_creation_enabled=false`
- `branch_protection_mutation_by_tool_enabled=false`
- `github_step_summary_write_enabled=false`
- `pull_request_comment_enabled=false`
- `production_telemetry_ingestion=false`
- `live_exporter_enabled=false`
- `network_send_enabled=false`
- `runtime_pipeline_enabled=false`
- `durable_write_enabled=false`
- `nendb_write_enabled=false`
- `mutation_authority=none`

The source must include evidence files, signal evaluations, checks, blocked
claims, and required verification commands. Missing sections or enabled
authority produce a blocked report.

## Statuses

- `ready`: source evaluator is ready, no blocked/advisory findings are
  present, required sections are present, authority is disabled, and
  publication remains local-only.
- `advisory`: source evaluator is reportable and contains advisory findings,
  but no blocked findings.
- `blocked`: source evaluator is invalid, blocked, missing required sections,
  contains blocked findings, or violates the disabled authority/publication
  boundary.

`ready_for_next_branch=true` only for `ready` and `advisory`. It is false for
`blocked`, but blocked reports still preserve source findings and evidence so
reviewers and agents can explain what failed.

## Publication Boundary

The tool only writes local JSON and text artifacts. It records publication
channels so a later boundary branch can review them:

- `local-json-artifact`: allowed and executed by this tool
- `local-text-artifact`: allowed and executed by this tool
- `ci-upload-artifact`: not allowed and not executed
- `github-step-summary`: not allowed and not executed
- `pull-request-comment`: not allowed and not executed
- `required-status-check`: not allowed and not executed
- `branch-protection-update`: not allowed and not executed

This means the report is reviewer guidance only. CI upload, GitHub summary,
pull request comment, required status check, and branch protection behavior all
remain future reviewed application-boundary work.

## Handoff

Ready or advisory report artifacts hand off to:

`codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-enforcement-report-application-boundary`

That branch should consume report artifacts and only mark publication or
required-check application as applied after reviewed evidence and before/after
verification exist. The report branch itself must not create CI checks, mutate
branch protection, write GitHub summaries, comment on pull requests, upload CI
artifacts, write NenDB, or grant mutation authority.

## Verification

```sh
cd packages/zigeffect
zig test tools/causal_production_telemetry_ci_gate_required_status_check_enforcement_report.zig
zig test tools/causal_production_hardening_backlog.zig
zig build causal-production-telemetry-ci-gate-required-status-check-enforcement-report -- --help
zig build causal-production-telemetry-ci-gate-required-status-check-enforcement-report -- \
  --from-evaluator ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-enforcement-evaluator.json \
  summarize \
  --reason "required status check enforcement report reviewed"
zig build causal-production-telemetry-ci-gate-required-status-check-enforcement-report -- \
  --from-evaluator ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-enforcement-evaluator-negative.json \
  summarize \
  --reason "negative required status check enforcement report path" \
  --out-prefix ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-enforcement-report-negative
zig build causal-schema-governance -- --format json
zig build causal-production-hardening-backlog -- --format json
zig build examples
zig build test
cd ../..
bun run check
bun run zig:test
git diff --check
```
