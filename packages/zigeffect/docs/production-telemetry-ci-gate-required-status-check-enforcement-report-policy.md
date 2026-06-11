# Production Telemetry CI Gate Required Status Check Enforcement Report Policy

Schema:
`zigeffect.causal.production-telemetry-ci-gate-required-status-check-enforcement-report-policy.v1`

Build step:
`causal-production-telemetry-ci-gate-required-status-check-enforcement-report-policy`

This tool consumes required status check enforcement report application-boundary
artifacts and emits record-only policy artifacts. It interprets planned or
externally applied report evidence for reviewers and agents. It does not publish
reports, upload artifacts, write GitHub summaries, post pull request comments,
create check runs, mutate workflows, mutate branch protection, or create
required status checks.

## Commands

Approve a source application-boundary artifact:

```sh
zig build causal-production-telemetry-ci-gate-required-status-check-enforcement-report-policy -- \
  --from-application-boundary ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-enforcement-report-application-boundary.json \
  approve \
  --reason "required status check enforcement report policy reviewed" \
  --verified-command "zig build causal-production-telemetry-ci-gate-required-status-check-enforcement-report-application-boundary" \
  --verified-command "zig build causal-artifacts" \
  --verified-command "zig build release-gate --summary none" \
  --verified-command "zig build release-gate-report" \
  --verified-command "zig build causal-schema-governance -- --format json" \
  --verified-command "zig build causal-production-hardening-backlog -- --format json" \
  --verified-command "zig build examples" \
  --verified-command "zig build test"
```

Negative path:

```sh
zig build causal-production-telemetry-ci-gate-required-status-check-enforcement-report-policy -- \
  --from-application-boundary ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-enforcement-report-application-boundary-negative.json \
  reject \
  --reason "negative required status check enforcement report policy path" \
  --out-prefix ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-enforcement-report-policy-negative
```

## Readiness

The output has two readiness signals:

- `ready_for_next_branch`: all policy checks passed and the artifact is safe to
  consume as interpretation evidence.
- `published_report_policy_ready`: the source artifact was externally applied,
  `applied=true`, and the source policy checks passed.

A planned source can be policy-ready without proving that a report was
published. An applied source can record published report policy readiness, but
only as evidence that an external review happened. It is not proof that this
tool published anything.

## Authority Boundary

The report policy keeps these disabled:

- `github_api_mutation_enabled`
- `github_check_run_creation_enabled`
- `branch_protection_mutation_by_tool_enabled`
- `ci_workflow_mutation_enabled`
- `ci_upload_execution_enabled`
- `ci_report_publication_enabled`
- `github_step_summary_write_enabled`
- `pull_request_comment_enabled`
- `production_telemetry_ingestion`
- `runtime_pipeline_enabled`
- `durable_write_enabled`
- `nendb_write_enabled`

`mutation_authority` is always `none`.

## Next Branch

The policy hands off to:

`codex/zigeffect-causal-production-hardening-backlog-refresh`

That branch should refresh the production hardening backlog and choose the next
unresolved roadmap item. Do not treat report policy readiness as production
health, deployment success, customer impact, capacity, or cluster readiness.

## Verification

```sh
zig test tools/causal_production_telemetry_ci_gate_required_status_check_enforcement_report_policy.zig
zig test tools/causal_production_hardening_backlog.zig
zig build causal-production-telemetry-ci-gate-required-status-check-enforcement-report-policy -- --help
zig build causal-schema-governance -- --format json
zig build causal-production-hardening-backlog -- --format json
zig build examples
zig build test
```
