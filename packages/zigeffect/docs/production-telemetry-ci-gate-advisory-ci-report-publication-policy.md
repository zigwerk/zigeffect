# Production Telemetry CI Gate Advisory CI Report Publication Policy

`causal-production-telemetry-ci-gate-advisory-ci-report-publication-policy`
consumes an applied advisory CI report application-boundary artifact and emits
a guarded, record-only interpretation policy for externally published advisory
CI reports.

It does not publish reports, upload artifacts, write GitHub step summaries,
post pull request comments, mutate workflows, create required status checks,
enable CI gate enforcement, ingest live telemetry, call networks, write NenDB,
write durable production storage, orchestrate production clusters, or grant
production mutation authority.

## Command

Approve interpretation policy from an applied application-boundary artifact:

```sh
cd packages/zigeffect
zig build causal-production-telemetry-ci-gate-advisory-ci-report-publication-policy -- \
  --from-application ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-advisory-ci-report-application-boundary-applied.json \
  approve \
  --reason "CI advisory report publication policy reviewed" \
  --verified-command "zig build causal-production-telemetry-ci-gate-advisory-ci-report-application-boundary" \
  --verified-command "zig build causal-artifacts" \
  --verified-command "zig build release-gate --summary none" \
  --verified-command "zig build release-gate-report" \
  --verified-command "zig build causal-schema-governance -- --format json" \
  --verified-command "zig build causal-production-hardening-backlog -- --format json" \
  --verified-command "zig build examples" \
  --verified-command "zig build test"
```

Use `reject` to record a reviewed stop. Rejected records always emit blocked
status and never hand off to the next branch.

Use `--out-prefix <path-prefix>` to choose an explicit artifact prefix. Without
`--out-prefix`, the tool writes sibling `.json` and `.txt` artifacts beside the
source application-boundary artifact. Deeply chained source names are compacted
to a deterministic filesystem-safe prefix with a short source-path digest.

## Source Contract

The source artifact must use schema
`zigeffect.causal.production-telemetry-ci-gate-advisory-ci-report-application-boundary.v1`,
have `mode="record-applied"`, have
`report_application_status="applied"`, set `applied=true`, and keep
`mutation_authority="record-only"`.

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

The source must also carry publication-change evidence, before evidence, after
evidence, after-report digest, passing source/application checks, blocked
claims, negative fixtures, and verification catalogs.

## Interpretation

Ready policy artifacts allow advisory reports to be used for reviewer triage,
agent read-only context, non-blocking CI advisory context, before/after review,
and future required-status-check readiness analysis.

They deny required checks, merge blocking, branch protection, workflow mutation
proof, upload proof, GitHub summary proof by this tool, PR comment proof by
this tool, production health, deployment success, capacity, customer impact,
cluster readiness, live telemetry coverage, durable write proof, NenDB write
proof, alternate renderer scope, non-NenDB durable adapter scope, and mutation
authority.

## Handoff

Ready publication-policy artifacts hand off to
`codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-readiness`.
That branch is now delivered and evaluates readiness for required status check
semantics as record-only evidence, not enforcement. Ready readiness artifacts
hand off to
`codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-application-boundary`.

## Verification

```sh
cd packages/zigeffect
zig test tools/causal_production_telemetry_ci_gate_advisory_ci_report_publication_policy.zig
zig build causal-production-telemetry-ci-gate-advisory-ci-report-publication-policy -- --help
zig build causal-schema-governance -- --format json
zig build causal-production-hardening-backlog -- --format json
zig build examples
zig build test
cd ../..
bun run check
bun run zig:test
git diff --check
```
