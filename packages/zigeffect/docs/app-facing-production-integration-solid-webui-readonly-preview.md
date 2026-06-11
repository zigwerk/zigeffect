# App-Facing Production Integration SolidJS Read-Only Preview

`causal-app-facing-production-integration-solid-webui-readonly-preview`
consumes a ready app-facing audit/remediation bridge JSON artifact and emits
`zigeffect.causal.app-facing-production-integration-solid-webui-readonly-preview.v1`.

It is a read-only preview artifact for the local SolidJS workbench running
inside `webui-dev/zig-webui`. It lets humans and agents inspect app-facing
runtime remediation evidence, bridge records, authority boundaries, checks,
blocked claims, and next-step commands without granting app, CI, deployment, or
durable-write authority.

It does not run a hosted live dashboard, mutate app config or data, execute a
NenDB adapter, write NenDB, write durable history, read production data, deploy
anything, enforce CI, prove production health, prove a mutation, auto-apply
remediation, enable React or an alternate renderer, or mark anything as applied.

## Command

```sh
cd packages/zigeffect
zig build causal-app-facing-production-integration-solid-webui-readonly-preview -- \
  --from-bridge ../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures-readiness-review-implementation-proposal-app-facing-boundary-local-fixtures-nendb-handoff-fixtures-audit-remediation-bridge.json \
  approve \
  --reason "ready app-facing audit remediation bridge reviewed for SolidJS read-only preview" \
  --verified-command "bun run zigeffect:workbench:typecheck" \
  --verified-command "bun run zigeffect:workbench:test" \
  --verified-command "zig build causal-app-facing-production-integration-audit-remediation-bridge" \
  --verified-command "zig build causal-schema-governance -- --format json" \
  --verified-command "zig build causal-production-hardening-backlog -- --format json" \
  --verified-command "zig build examples" \
  --verified-command "zig build test"
```

The command writes:

- `<bridge-base>-solid-webui-readonly-preview.json`;
- `<bridge-base>-solid-webui-readonly-preview.txt`.

Use `--out-prefix <path-prefix>` to choose a different output path.

Use `reject --reason <reason>` to produce a blocked negative artifact:

```sh
zig build causal-app-facing-production-integration-solid-webui-readonly-preview -- \
  --from-bridge ../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures-readiness-review-implementation-proposal-app-facing-boundary-local-fixtures-nendb-handoff-fixtures-audit-remediation-bridge.json \
  reject \
  --reason "negative fixture keeps preview blocked after reviewer rejection" \
  --out-prefix ../../.zig-cache/causal-artifacts/app-facing-production-integration-solid-webui-readonly-preview-negative \
  --verified-command "zig build test"
```

## Input Contract

The input bridge must use
`zigeffect.causal.app-facing-production-integration-audit-remediation-bridge.v1`
and be ready and approved. The producer rejects authority drift if the source
bridge enables app writes, NenDB writes, NenDB adapter execution, durable
writes, deployment mutation, app runtime integration, live agent projection,
SolidJS preview serving, auto-apply, mutation-proof claims, production health
claims, or `applied=true`.

The source bridge catalog must include:

- `audit-chain-comparison-review-bridge`
- `remediation-review-policy-gate-bridge`
- `runtime-to-remediation-evidence-bridge`
- `agent-query-to-remediation-next-query-bridge`
- `solid-webui-review-preview-bridge`
- `ci-advisory-remediation-report-bridge`

## Authority

The preview artifact keeps these authority fields fixed:

- `applied=false`
- `mutation_authority="none"`
- `read_only_preview=true`
- `solid_webui_enabled=true`
- `solid_webui_renderer="solidjs"`
- `webui_bridge="webui-dev/zig-webui"`
- `hosted_live_dashboard_enabled=false`
- `app_mutation_controls_enabled=false`
- `production_telemetry_ingestion=false`
- `live_exporter_enabled=false`
- `network_send_enabled=false`
- `collector_endpoint_configured=false`
- `otlp_serialization_enabled=false`
- `durable_write_enabled=false`
- `app_mutation_enabled=false`
- `ci_gate_enabled=false`
- `raw_payload_capture_enabled=false`
- `app_config_write_enabled=false`
- `app_data_write_enabled=false`
- `deployment_mutation_enabled=false`
- `nendb_write_enabled=false`
- `nendb_adapter_execution_enabled=false`
- `app_runtime_integration_enabled=false`
- `agent_query_live_projection_enabled=false`
- `mutation_proof_claim_enabled=false`
- `auto_apply_enabled=false`
- `production_health_claim_enabled=false`
- `react_renderer_enabled=false`
- `alternate_renderer_enabled=false`

## Workbench View

The SolidJS workbench can derive an app-facing preview model from either:

- a ready SolidJS read-only preview artifact;
- the source audit/remediation bridge artifact, shown as pre-preview source
  mode.

The new `app-preview` tab appears only for those artifact families. It renders
status metrics, authority flags, bridge records, preview sections, checks,
validation checks, implementation gates, blocked claims, non-goals, verification
commands, and the next branch. It has no mutation buttons and no hosted live
dashboard controls.

The development sample is:

`packages/zigeffect/workbench/public/sample-app-facing-solid-webui-readonly-preview.json`

It is reachable through the local workbench sample route:

`?sample=app-preview`

## Status

- `ready`: the source bridge is ready and approved, every source bridge check
  passed, source and preview verification commands were recorded, all six bridge
  records are present, and every authority or write field remains disabled.
- `blocked`: the reviewer rejected, source evidence is blocked, a required
  bridge record is missing, required verification evidence is missing, or any
  authority/write/apply/deployment/health claim is enabled.

`ready_for_next_branch=true` means the next branch may be:

`codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report`

It does not mean app runtime integration, live agent projection, raw payload
capture, production NenDB writes, NenDB adapter execution, app mutation, CI
enforcement, deployment, production health, mutation proof, auto-apply, hosted
live dashboard, React renderer, alternate renderer, or `applied=true`.

## Blocked Claims

The artifact blocks app runtime integration, live agent-query projection, app
mutation, raw payload capture, raw prompt/response capture, app config writes,
app data writes, remediation auto-apply, mutation proof, fixed/deployed/healthy
claims, deployment mutation, durable production writes, NenDB production writes,
NenDB adapter execution, non-NenDB adapters, Cockroach adapter work, CI required
status checks, CI enforcement, GitHub workflow mutation, hosted live dashboard,
React or alternate renderer work, app mutation buttons, mutation authority, and
`applied=true`.

## Agent Guidance

Agents may use a ready preview artifact to reason about app-facing runtime and
remediation evidence in the local workbench. They must cite the source bridge
path, bridge record ids, preview section ids, checks, validation checks,
required commands, and recorded commands.

Blocked preview artifacts can guide repair work only. They cannot justify app
integration, production writes, adapter execution, CI gates, deployment changes,
raw payload capture, Cockroach work, alternate renderer work, production health
claims, mutation proof, auto-apply, hosted live dashboard work, or
`applied=true`.

## Verification

```sh
cd packages/zigeffect
zig test tools/causal_app_facing_production_integration_solid_webui_readonly_preview.zig
bun run zigeffect:workbench:typecheck
bun run zigeffect:workbench:test
zig build causal-app-facing-production-integration-solid-webui-readonly-preview
zig build causal-schema-governance -- --format json
zig build causal-production-hardening-backlog -- --format json
zig build examples
zig build test
cd ../..
bun run check
bun run zig:test
git diff --check
```
