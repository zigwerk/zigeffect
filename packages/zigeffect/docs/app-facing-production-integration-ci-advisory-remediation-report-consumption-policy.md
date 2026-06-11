# App-Facing CI Advisory Remediation Report Consumption Policy

`causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-policy`
consumes an applied app-facing advisory remediation report consumption-boundary
artifact and emits
`zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-policy.v1`.

The policy is an interpretation boundary. It tells reviewers, agents,
non-blocking CI advisory readers, and the local SolidJS
`webui-dev/zig-webui` workbench what applied read-only consumption evidence can
mean without converting that evidence into enforcement, runtime, storage,
deployment, adapter, or mutation authority.

It does not create required status checks, block merges, mutate workflows, call
the GitHub API, upload artifacts, write GitHub summaries, post pull request
comments, mutate app config or data, wire the app runtime, enable live agent
projection, capture raw prompts or responses, write durable storage, write
NenDB, execute a NenDB adapter, add Cockroach scope, deploy anything, prove
production health, auto-apply remediation, change the renderer away from
SolidJS, or grant mutation authority.

## Approve Command

```sh
cd packages/zigeffect
zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-policy -- \
  --from-boundary ../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures-readiness-review-implementation-proposal-app-facing-boundary-local-fixtures-nendb-handoff-fixtures-ci-advisory-remediation-report-consumption-boundary.json \
  approve \
  --reason "reviewed app-facing advisory remediation report consumption policy" \
  --verified-command "bun run zigeffect:workbench:typecheck" \
  --verified-command "bun run zigeffect:workbench:test" \
  --verified-command "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-boundary" \
  --verified-command "zig build causal-schema-governance -- --format json" \
  --verified-command "zig build causal-production-hardening-backlog -- --format json" \
  --verified-command "zig build examples" \
  --verified-command "zig build test"
```

Without `--out-prefix`, the tool writes sibling `.json` and `.txt` artifacts
beside the source consumption-boundary artifact. Long chained source names are
compacted to a deterministic filesystem-safe prefix with a source-path digest.

## Reject Command

Use `reject` to record a reviewed stop. Rejected records always emit blocked
status and never hand off to the evaluator branch.

```sh
cd packages/zigeffect
zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-policy -- \
  --from-boundary ../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures-readiness-review-implementation-proposal-app-facing-boundary-local-fixtures-nendb-handoff-fixtures-ci-advisory-remediation-report-consumption-boundary.json \
  reject \
  --reason "negative app-facing advisory remediation report consumption policy path" \
  --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-policy-negative
```

## Source Contract

The source artifact must use schema
`zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-boundary.v1`,
have `mode="record-applied"`, have
`consumption_boundary_status="applied"`, set `applied=true`, set
`ready_for_next_branch=true`, and keep `mutation_authority="record-only"`.

The source must carry:

- a consumption-readiness source ref with status `ready`;
- a publication-policy source ref;
- source after-report digest and consumer-after digest;
- consumer-change evidence;
- before and after evidence;
- passing boundary checks;
- boundary rules;
- source consumer profiles;
- source readiness dimensions;
- source consumption guardrails;
- source denied inference rules;
- denied boundary claims;
- blocked claims;
- negative fixtures;
- required and verified command evidence.

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
- `runtime_pipeline_enabled=false`
- `durable_write_enabled=false`
- `nendb_write_enabled=false`
- `nendb_adapter_execution_enabled=false`

The source must also keep `read_only_consumption_enabled=true`,
`solid_webui_enabled=true`, `solid_webui_renderer="solidjs"`, and
`webui_bridge="webui-dev/zig-webui"`.

## Interpretation

Ready policy artifacts allow:

- maintainer review of source ids, boundary checks, before/after evidence, and
  denied claims;
- agent read-only bounded context with source ids, guardrails, blocked claims,
  policy rules, and next-query guidance;
- non-blocking CI advisory reading;
- local SolidJS `zig-webui` read-only rendering;
- future read-only consumption evaluator input.

They deny required checks, merge blocking, CI enforcement, branch protection,
workflow mutation proof, GitHub API mutation proof, artifact upload proof,
GitHub summary or PR comment proof, app mutation proof, app runtime integration,
live projection, raw prompt/response/payload capture, durable write proof,
NenDB write proof, NenDB adapter execution proof, Cockroach adapter work,
non-NenDB durable storage, deployment success, production health, cluster
readiness, React or alternate renderer scope, auto-apply proof, and mutation
authority.

## Handoff

Ready consumption-policy artifacts hand off to:

```text
codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-evaluator
```

That branch should classify concrete read-only agent and workbench consumption
requests against this policy. It still must not create mutation authority,
required status checks, app runtime integration, GitHub mutation, NenDB writes,
NenDB adapter execution, Cockroach scope, deployment authority, production
health claims, or alternate renderer scope.

## Verification

```sh
cd packages/zigeffect
zig test tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_policy.zig
zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-policy -- --help
zig build causal-schema-governance -- --format json
zig build causal-production-hardening-backlog -- --format json
zig build examples
zig build test
cd ../..
bun run check
bun run zig:test
git diff --check
```
