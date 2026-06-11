# App-Facing CI Advisory Remediation Report Consumption Readiness

`causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-readiness`
consumes a ready app-facing advisory remediation report publication-policy
artifact and emits
`zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-readiness.v1`.

This is a read-only consumption gate. It proves that reviewers, agents,
non-blocking CI advisory readers, and the local SolidJS
`webui-dev/zig-webui` workbench can consume policy evidence as bounded context
without turning that evidence into app mutation, runtime integration, storage
writes, deployment authority, or CI enforcement.

It does not create required status checks, block merges, mutate workflows, call
the GitHub API, upload artifacts, publish reports, write GitHub summaries, post
pull request comments, mutate app config or app data, enable app runtime
integration, enable live agent projections, capture raw payloads, write NenDB,
execute a NenDB adapter, add non-NenDB durable storage, add Cockroach scope,
deploy anything, prove production health, auto-apply remediation, switch away
from SolidJS in `webui-dev/zig-webui`, or grant mutation authority.

## Approve Command

```sh
cd packages/zigeffect
zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-readiness -- \
  --from-publication-policy ../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures-readiness-review-implementation-proposal-app-facing-boundary-local-fixtures-nendb-handoff-fixtures-ci-advisory-remediation-report-publication-policy.json \
  approve \
  --reason "reviewed app-facing advisory remediation report consumption readiness" \
  --verified-command "bun run zigeffect:workbench:typecheck" \
  --verified-command "bun run zigeffect:workbench:test" \
  --verified-command "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-publication-policy" \
  --verified-command "zig build causal-schema-governance -- --format json" \
  --verified-command "zig build causal-production-hardening-backlog -- --format json" \
  --verified-command "zig build examples" \
  --verified-command "zig build test"
```

Without `--out-prefix`, the tool writes sibling `.json` and `.txt` artifacts
beside the source publication-policy artifact. Long chained source names are
compacted to a deterministic filesystem-safe prefix with a source-path digest.

## Reject Command

Use `reject` to record a reviewed stop. Rejected records always emit blocked
status and never hand off to the next branch.

```sh
cd packages/zigeffect
zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-readiness -- \
  --from-publication-policy ../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures-readiness-review-implementation-proposal-app-facing-boundary-local-fixtures-nendb-handoff-fixtures-ci-advisory-remediation-report-publication-policy.json \
  reject \
  --reason "negative app-facing advisory remediation report consumption readiness path" \
  --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-readiness-negative
```

## Source Contract

The source artifact must use schema
`zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-publication-policy.v1`,
have `decision="approve"`, set
`ci_advisory_remediation_report_publication_policy_status="ready"`, set
`ready_for_next_branch=true`, and keep `mutation_authority="none"`.

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
- `app_runtime_integration_enabled=false`
- `agent_query_live_projection_enabled=false`
- `raw_payload_capture_enabled=false`
- `deployment_mutation_enabled=false`
- `production_telemetry_ingestion=false`
- `live_exporter_enabled=false`
- `network_send_enabled=false`
- `collector_endpoint_configured=false`
- `otlp_serialization_enabled=false`
- `runtime_pipeline_enabled=false`
- `durable_write_enabled=false`
- `nendb_write_enabled=false`
- `nendb_adapter_execution_enabled=false`

The source must also carry application-boundary evidence refs, an after-report
digest, passing policy checks, interpretation rules, publication surfaces,
denied inference rules, negative fixtures, blocked claims, required
verification commands, and verified command evidence.

## Read-Only Consumers

Ready consumption-readiness artifacts define these consumer profiles:

- reviewer triage: source ids, checks, denied claims, and digest refs;
- agent read-only: bounded source refs, findings, checks, and next-query hints;
- CI advisory: non-blocking advisory context only;
- SolidJS workbench: local redacted policy evidence rendered in
  `webui-dev/zig-webui`;
- future consumption boundary: record-only input to the next reviewed tool.

Every consumer must cite source ids, carry denied claims forward, avoid raw
payloads, and treat the artifact as advisory context only.

## Denied Claims

Ready consumption does not prove required status checks, merge blocking, branch
protection changes, GitHub API mutation, workflow mutation, app mutation, app
runtime integration, live projection, raw payload capture, deployment success,
production health, durable writes, NenDB writes, NenDB adapter execution,
Cockroach adapter work, React or alternate renderer scope, auto-apply behavior,
or mutation authority.

## Handoff

Ready consumption-readiness artifacts hand off to:

```text
codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-boundary
```

That branch should define the guarded application boundary for actual read-only
consumption by agents and the SolidJS workbench. It still must not grant app
mutation, runtime integration, required CI enforcement, NenDB writes, adapter
execution, deployment authority, production health claims, or mutation
authority.

## Verification

```sh
cd packages/zigeffect
zig test tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_readiness.zig
zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-readiness -- --help
zig build causal-schema-governance -- --format json
zig build causal-production-hardening-backlog -- --format json
zig build examples
zig build test
cd ../..
bun run check
bun run zig:test
git diff --check
```
