# App-Facing CI Advisory Remediation Report Publication Policy

`causal-app-facing-production-integration-ci-advisory-remediation-report-publication-policy`
consumes an applied app-facing advisory remediation report application-boundary
artifact and emits
`zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-publication-policy.v1`.

The policy is an interpretation boundary. It lets agents, reviewers, CI
readers, and the local SolidJS `webui-dev/zig-webui` workbench consume reviewed
advisory report evidence without converting that evidence into enforcement or
runtime authority.

It does not create required status checks, block merges, mutate workflows, call
the GitHub API, publish reports, upload artifacts, write GitHub summaries, post
pull request comments, mutate app config or data, run a NenDB adapter, write
NenDB, add non-NenDB durable scope, add Cockroach scope, deploy anything, prove
production health, auto-apply remediation, enable live projections, capture raw
payloads, or grant app runtime integration.

## Approve Command

```sh
cd packages/zigeffect
zig build causal-app-facing-production-integration-ci-advisory-remediation-report-publication-policy -- \
  --from-application ../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures-readiness-review-implementation-proposal-app-facing-boundary-local-fixtures-nendb-handoff-fixtures-ci-advisory-remediation-report-application-boundary.json \
  approve \
  --reason "reviewed app-facing advisory remediation report publication policy" \
  --verified-command "bun run zigeffect:workbench:typecheck" \
  --verified-command "bun run zigeffect:workbench:test" \
  --verified-command "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-application-boundary" \
  --verified-command "zig build causal-schema-governance -- --format json" \
  --verified-command "zig build causal-production-hardening-backlog -- --format json" \
  --verified-command "zig build examples" \
  --verified-command "zig build test"
```

Without `--out-prefix`, the tool writes sibling `.json` and `.txt` artifacts
beside the source application-boundary artifact. Long chained source names are
compacted to a deterministic filesystem-safe prefix with a source-path digest.

## Reject Command

Use `reject` to record a reviewed stop. Rejected records always emit blocked
status and never hand off to the next branch.

```sh
cd packages/zigeffect
zig build causal-app-facing-production-integration-ci-advisory-remediation-report-publication-policy -- \
  --from-application ../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures-readiness-review-implementation-proposal-app-facing-boundary-local-fixtures-nendb-handoff-fixtures-ci-advisory-remediation-report-application-boundary.json \
  reject \
  --reason "negative app-facing advisory remediation report publication policy path" \
  --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-publication-policy-negative
```

## Source Contract

The source artifact must use schema
`zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-application-boundary.v1`,
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
- `github_api_mutation_enabled=false`
- `app_mutation_controls_enabled=false`
- `app_mutation_enabled=false`
- `app_config_write_enabled=false`
- `app_data_write_enabled=false`
- `deployment_mutation_enabled=false`
- `app_runtime_integration_enabled=false`
- `agent_query_live_projection_enabled=false`
- `raw_payload_capture_enabled=false`
- `production_telemetry_ingestion=false`
- `runtime_pipeline_enabled=false`
- `durable_write_enabled=false`
- `nendb_write_enabled=false`
- `nendb_adapter_execution_enabled=false`

The source must also carry publication-change evidence, before evidence, after
evidence, an after-report digest, passing source/application checks, blocked
claims, negative fixtures, and verification catalogs.

## Interpretation

Ready policy artifacts allow:

- reviewer triage summaries;
- agent read-only context with event ids, checks, denied claims, and next
  queries;
- non-blocking CI advisory context;
- local SolidJS `zig-webui` read-only context;
- before/after review evidence;
- future app-facing advisory report consumption-readiness input.

They deny required checks, merge blocking, branch protection, workflow mutation
proof, GitHub API mutation proof, app mutation proof, app runtime integration,
live projection, raw payload capture, production health, deployment success,
live telemetry coverage, durable write proof, NenDB write proof, NenDB adapter
execution proof, Cockroach adapter work, non-NenDB durable adapter scope, React
or alternate renderer scope, auto-apply proof, and mutation authority.

## Handoff

Ready publication-policy artifacts hand off to:

```text
codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-readiness
```

That branch should define exactly how app-facing advisory report evidence can be
consumed by agents and the SolidJS workbench as read-only context, still without
mutation authority, required status checks, NenDB writes, adapter execution, or
runtime integration.

## Verification

```sh
cd packages/zigeffect
zig test tools/causal_app_facing_production_integration_ci_advisory_remediation_report_publication_policy.zig
zig build causal-app-facing-production-integration-ci-advisory-remediation-report-publication-policy -- --help
zig build causal-schema-governance -- --format json
zig build causal-production-hardening-backlog -- --format json
zig build examples
zig build test
cd ../..
bun run check
bun run zig:test
git diff --check
```
