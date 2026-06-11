# App-Facing Production Integration NenDB Handoff Fixtures

`causal-app-facing-production-integration-nendb-handoff-fixtures` consumes a
ready app-facing local-fixtures JSON artifact and emits
`zigeffect.causal.app-facing-production-integration-nendb-handoff-fixtures.v1`.

It is a record-only NenDB handoff fixture milestone. It maps local app-facing
runtime refs, bounded agent-query refs, audit/remediation review refs, SolidJS
read-only preview refs, and advisory CI artifact refs into deterministic NenDB
node and edge handoff records. It does not execute a NenDB adapter, write
NenDB, write durable history, integrate a live app runtime, query live app data,
mutate app config/data, enforce CI, deploy anything, or mark anything as
applied.

## Command

```sh
cd packages/zigeffect
zig build causal-app-facing-production-integration-nendb-handoff-fixtures -- \
  --from-local-fixtures ../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures-readiness-review-implementation-proposal-app-facing-boundary-local-fixtures.json \
  approve \
  --reason "ready local app-facing fixtures reviewed for NenDB handoff fixtures" \
  --verified-command "zig build causal-app-facing-production-integration-local-fixtures" \
  --verified-command "zig build causal-schema-governance -- --format json" \
  --verified-command "zig build causal-production-hardening-backlog -- --format json" \
  --verified-command "zig build examples" \
  --verified-command "zig build test"
```

The command writes:

- `<local-fixtures-base>-nendb-handoff-fixtures.json`;
- `<local-fixtures-base>-nendb-handoff-fixtures.txt`.

Use `--out-prefix <path-prefix>` to choose a different output path.

Use `reject --reason <reason>` to produce a blocked negative artifact:

```sh
zig build causal-app-facing-production-integration-nendb-handoff-fixtures -- \
  --from-local-fixtures ../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures-readiness-review-implementation-proposal-app-facing-boundary-local-fixtures.json \
  reject \
  --reason "negative nendb handoff path" \
  --out-prefix ../../.zig-cache/causal-artifacts/app-facing-production-integration-nendb-handoff-fixtures-negative
```

## Authority

The handoff artifact keeps these authority fields fixed:

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
- `local_fixture_mode=true`
- `nendb_handoff_fixture_mode=true`

`nendb_handoff_fixture_mode=true` means the artifact is deterministic handoff
evidence for the next planning branch. It is not proof of a live adapter,
runtime integration, workbench host, production health, or applied state.

## Handoff Catalog

The emitted `nendb_handoff_fixtures` catalog contains node handoff fixtures:

- `nendb-worker-request-node-handoff-fixture`
- `nendb-background-job-node-handoff-fixture`
- `nendb-agent-query-projection-node-handoff-fixture`
- `nendb-audit-remediation-node-handoff-fixture`
- `nendb-solid-webui-preview-node-handoff-fixture`
- `nendb-ci-advisory-node-handoff-fixture`

It also contains edge handoff fixtures:

- `nendb-runtime-to-agent-query-edge-handoff-fixture`
- `nendb-runtime-to-audit-remediation-edge-handoff-fixture`
- `nendb-artifact-preview-edge-handoff-fixture`

Each fixture records the source local fixture, target NenDB schema, handoff
kind, label, retained fields, and blocked fields. Blocked fields include raw
payloads, raw prompts/responses, mutation claims, app writes, workflow
mutation, live dashboard hosting, NenDB writes, and adapter execution.

## Checks

The handoff report evaluates:

- source local-fixtures schema, ready status, and approved decision;
- reviewer decision and reason;
- disabled source and handoff authority fields;
- linked boundary, proposal, readiness, and fixture JSON paths;
- all required source local-fixtures checks;
- source local-fixtures verification command evidence;
- source fixture catalog coverage;
- NenDB node and edge handoff catalog coverage;
- worker request and background job runtime ref handoffs;
- bounded agent-query projection handoffs;
- audit/remediation review-only handoffs;
- SolidJS `webui-dev/zig-webui` read-only preview handoffs;
- advisory CI artifact handoffs;
- handoff validation checks;
- handoff verification command evidence;
- disabled NenDB writes, adapter execution, and durable writes;
- NenDB-only durable direction;
- SolidJS workbench direction.

## Status

- `ready`: the source local-fixtures artifact is ready, every required source
  check passed, source and handoff verification commands were recorded, the
  source fixture catalog is complete, and every required NenDB node/edge handoff
  fixture is present.
- `blocked`: the reviewer rejected, source evidence is blocked, a required
  check failed, a handoff fixture family is missing, or required verification
  command evidence is missing.

`ready_for_next_branch=true` means the next branch may be:

`codex/zigeffect-causal-app-facing-production-integration-audit-remediation-bridge`

It does not mean app runtime integration, live agent projection, raw payload
capture, production NenDB writes, NenDB adapter execution, app mutation, CI
enforcement, deployment, or SolidJS live preview has been implemented.

## Blocked Claims

The artifact blocks app runtime integration, live agent-query projection,
SolidJS preview serving, app mutation, raw payload capture, app config writes,
app data writes, deployment mutation, durable production writes, NenDB
production writes, NenDB adapter execution, non-NenDB adapters, Cockroach
adapter work, CI required status checks, React or alternate renderer work,
mutation authority, and `applied=true`.

## Agent Guidance

Agents may use a ready handoff artifact to start the app-facing
audit/remediation bridge. They must cite the source local-fixtures path,
check names, source fixture catalog ids, NenDB node/edge handoff ids,
validation checks, required commands, and recorded commands.

Blocked handoff artifacts can guide repair work only. They cannot justify app
integration, production writes, adapter execution, CI gates, deployment
changes, raw payload capture, Cockroach work, alternate renderer work, or
`applied=true`.

## Verification

```sh
cd packages/zigeffect
zig test tools/causal_app_facing_production_integration_nendb_handoff_fixtures.zig
zig build test
zig build causal-schema-governance -- --format json
zig build causal-production-hardening-backlog -- --format json
zig build examples
cd ../..
bun run check
bun run zig:test
git diff --check
```
