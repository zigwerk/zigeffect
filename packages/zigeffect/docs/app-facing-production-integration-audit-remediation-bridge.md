# App-Facing Production Integration Audit Remediation Bridge

`causal-app-facing-production-integration-audit-remediation-bridge` consumes a
ready app-facing NenDB handoff fixtures JSON artifact and emits
`zigeffect.causal.app-facing-production-integration-audit-remediation-bridge.v1`.

It is a record-only audit/remediation bridge. It links audit-chain comparison
refs, remediation review refs, runtime evidence refs, bounded agent-query
next-query refs, SolidJS read-only preview refs, and advisory CI refs so agents
can reason about app issues without inferring mutation authority.

It does not apply fixes, mutate app config or data, execute a NenDB adapter,
write NenDB, write durable history, read production data, deploy anything,
enforce CI, prove production health, prove a mutation, auto-apply remediation,
or mark anything as applied.

## Command

```sh
cd packages/zigeffect
zig build causal-app-facing-production-integration-audit-remediation-bridge -- \
  --from-handoff ../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures-readiness-review-implementation-proposal-app-facing-boundary-local-fixtures-nendb-handoff-fixtures.json \
  approve \
  --reason "ready app-facing NenDB handoff fixtures reviewed for audit remediation bridge" \
  --verified-command "zig build causal-app-facing-production-integration-nendb-handoff-fixtures" \
  --verified-command "zig build causal-schema-governance -- --format json" \
  --verified-command "zig build causal-production-hardening-backlog -- --format json" \
  --verified-command "zig build examples" \
  --verified-command "zig build test"
```

The command writes:

- `<handoff-base>-audit-remediation-bridge.json`;
- `<handoff-base>-audit-remediation-bridge.txt`.

Use `--out-prefix <path-prefix>` to choose a different output path.

Use `reject --reason <reason>` to produce a blocked negative artifact:

```sh
zig build causal-app-facing-production-integration-audit-remediation-bridge -- \
  --from-handoff ../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures-readiness-review-implementation-proposal-app-facing-boundary-local-fixtures-nendb-handoff-fixtures.json \
  reject \
  --reason "negative audit remediation bridge path" \
  --out-prefix ../../.zig-cache/causal-artifacts/app-facing-production-integration-audit-remediation-bridge-negative
```

## Authority

The bridge artifact keeps these authority fields fixed:

- `applied=false`
- `mutation_authority="none"`
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
- `solid_webui_preview_enabled=false`
- `audit_remediation_bridge_mode=true`
- `mutation_proof_claim_enabled=false`
- `auto_apply_enabled=false`
- `production_health_claim_enabled=false`

`audit_remediation_bridge_mode=true` means the artifact is review-only
evidence for the next planning branch. It is not proof of a fix, deployed
state, live app integration, production health, or applied mutation.

## Bridge Catalog

The emitted `audit_remediation_bridge_records` catalog contains:

- `audit-chain-comparison-review-bridge`
- `remediation-review-policy-gate-bridge`
- `runtime-to-remediation-evidence-bridge`
- `agent-query-to-remediation-next-query-bridge`
- `solid-webui-review-preview-bridge`
- `ci-advisory-remediation-report-bridge`

Each record includes the source NenDB handoff fixture, audit ref,
remediation ref, bridge kind, review state, retained refs, and blocked claims.

## SolidJS Read-Only Preview Consumer

The next consumer is
`causal-app-facing-production-integration-solid-webui-readonly-preview`, which
emits
`zigeffect.causal.app-facing-production-integration-solid-webui-readonly-preview.v1`.

That consumer validates this bridge artifact before rendering app-facing
evidence in the local SolidJS workbench. The bridge remains record-only until
the preview producer confirms source readiness, bridge record coverage,
authority-disabled fields, and preview verification commands.

The preview consumer still does not grant app runtime integration, live agent
projection, app mutation controls, hosted live dashboard hosting, CI
enforcement, deployment mutation, NenDB writes, NenDB adapter execution,
Cockroach scope, React renderer support, alternate renderer support, production
health claims, mutation proof, auto-apply, or `applied=true`.

## Checks

The bridge report evaluates:

- source NenDB handoff schema, ready status, and approved decision;
- reviewer decision and reason;
- disabled source and bridge authority fields;
- linked boundary, proposal, readiness, and fixture JSON paths;
- source handoff check and verification evidence;
- source NenDB handoff catalog coverage;
- audit/remediation node and runtime edge coverage;
- audit-chain comparison and remediation review refs;
- bounded agent-query next-query evidence refs;
- SolidJS `webui-dev/zig-webui` read-only preview refs;
- advisory CI remediation report refs;
- bridge validation checks;
- bridge verification command evidence;
- disabled mutation proof, auto-apply, app writes, NenDB writes, NenDB adapter
  execution, durable writes, deployment mutation, and production health claims;
- NenDB-only durable direction;
- SolidJS read-only preview direction.

## Status

- `ready`: the source NenDB handoff fixture artifact is ready, every required
  source check passed, source and bridge verification commands were recorded,
  required audit/remediation refs are present, and every authority or write
  field remains disabled.
- `blocked`: the reviewer rejected, source evidence is blocked, a required
  check failed, audit/remediation refs are missing, required verification
  evidence is missing, or any authority/write/apply/deployment/health claim is
  enabled.

`ready_for_next_branch=true` means the next branch may be:

`codex/zigeffect-causal-app-facing-production-integration-solid-webui-readonly-preview`

It does not mean app runtime integration, live agent projection, raw payload
capture, production NenDB writes, NenDB adapter execution, app mutation, CI
enforcement, deployment, production health, mutation proof, auto-apply, or
`applied=true`.

## Blocked Claims

The artifact blocks app runtime integration, live agent-query projection,
SolidJS preview serving, app mutation, raw payload capture, raw prompt/response
capture, app config writes, app data writes, remediation auto-apply, mutation
proof, fixed/deployed/healthy claims, deployment mutation, durable production
writes, NenDB production writes, NenDB adapter execution, non-NenDB adapters,
Cockroach adapter work, CI required status checks, React or alternate renderer
work, mutation authority, and `applied=true`.

## Agent Guidance

Agents may use a ready bridge artifact to start the app-facing SolidJS
read-only preview branch. They must cite the source handoff path, check names,
bridge record ids, validation checks, required commands, and recorded commands.

Blocked bridge artifacts can guide repair work only. They cannot justify app
integration, production writes, adapter execution, CI gates, deployment
changes, raw payload capture, Cockroach work, alternate renderer work,
production health claims, mutation proof, auto-apply, or `applied=true`.

## Verification

```sh
cd packages/zigeffect
zig test tools/causal_app_facing_production_integration_audit_remediation_bridge.zig
zig build test
zig build causal-schema-governance -- --format json
zig build causal-production-hardening-backlog -- --format json
zig build examples
cd ../..
bun run check
bun run zig:test
git diff --check
```
