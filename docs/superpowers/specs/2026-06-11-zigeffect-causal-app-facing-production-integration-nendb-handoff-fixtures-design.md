# Zigeffect Causal App-Facing Production Integration NenDB Handoff Fixtures Design

## Context

Branch:
`codex/zigeffect-causal-app-facing-production-integration-nendb-handoff-fixtures`

The previous milestone,
`causal-app-facing-production-integration-local-fixtures`, emits
`zigeffect.causal.app-facing-production-integration-local-fixtures.v1`. It
proves that app-facing local fixture families exist for worker request runtime
refs, background job refs, bounded agent queries, NenDB handoff refs,
audit/remediation review links, SolidJS read-only preview handoff, and advisory
CI artifact previews.

This milestone consumes that ready local-fixtures artifact and turns it into a
NenDB handoff fixture catalog. It is still record-only. It does not execute the
NenDB adapter, write production history, capture raw payloads, integrate with
an app runtime, query live app data, mutate deployments, enforce CI, or mark
anything as applied.

## Selected Approach

Use the existing artifact-review CLI pattern, following
`causal-production-telemetry-nendb-retention-fixtures` for parsing, checks,
paired JSON/text output, and blocked negative paths. Specialize the new tool for
app-facing local fixture ids and NenDB node/edge handoff records.

Alternatives considered:

- Reuse the production telemetry retention tool directly. This would save code
  but would overfit the app-facing milestone to telemetry retention policies and
  envelope names.
- Implement live NenDB adapter writes. This is explicitly out of scope; the
  branch is a reviewed handoff fixture layer only.
- Skip the handoff layer and jump to audit/remediation or workbench branches.
  That would leave agents without a stable record shape for how app-facing refs
  become future NenDB graph history records.

## Artifact Contract

New schema:
`zigeffect.causal.app-facing-production-integration-nendb-handoff-fixtures.v1`

Command:

```sh
zig build causal-app-facing-production-integration-nendb-handoff-fixtures -- \
  --from-local-fixtures <local-fixtures.json> \
  approve \
  --reason "<review reason>" \
  --verified-command "<command>"...
```

Default outputs:

- `<local-fixtures-base>-nendb-handoff-fixtures.json`
- `<local-fixtures-base>-nendb-handoff-fixtures.txt`

Rejected path:

```sh
zig build causal-app-facing-production-integration-nendb-handoff-fixtures -- \
  --from-local-fixtures <local-fixtures.json> \
  reject \
  --reason "negative nendb handoff path" \
  --out-prefix <path-prefix>
```

## Source Requirements

The source artifact must satisfy:

- `schema="zigeffect.causal.app-facing-production-integration-local-fixtures.v1"`
- `schema_version=1`
- `decision="approve"`
- `fixture_status="ready"`
- `ready_for_next_branch=true`
- `applied=false`
- `mutation_authority="none"`
- all local-fixtures authority booleans remain disabled except
  `local_fixture_mode=true`
- all required local-fixtures checks are present and pass
- required local-fixtures verification commands are present and recorded
- `fixture_catalog` contains all seven local fixture families

Required source check names:

- `boundary-schema`
- `boundary-status`
- `boundary-decision-approved`
- `fixture-decision`
- `decision-approved`
- `authority-boundary`
- `source-chain-linked`
- `boundary-checks-passed`
- `boundary-contract-present`
- `projection-fixtures-present`
- `fixture-catalog-present`
- `runtime-ref-fixtures-present`
- `agent-query-fixture-present`
- `nendb-handoff-fixture-present`
- `audit-remediation-fixture-present`
- `solid-webui-fixture-present`
- `ci-advisory-fixture-present`
- `fixture-validation-passed`
- `boundary-verification-recorded`
- `fixture-verification-recorded`
- `nendb-only-scope`
- `solid-webui-scope`

## Handoff Catalog

The emitted `nendb_handoff_fixtures` catalog contains node and edge handoff
records. These are shapes for future NenDB adapter work; they are not writes.

Node handoff fixtures:

- `nendb-worker-request-node-handoff-fixture`
  - source fixture: `worker-request-runtime-ref-fixture`
  - target schema: `zigeffect.causal.nendb_node.v1`
  - retained fields: `trace_id_ref`, `causal_event_ref`, `route_ref`,
    `redaction_state`, `sample_state`
- `nendb-background-job-node-handoff-fixture`
  - source fixture: `background-job-runtime-ref-fixture`
  - target schema: `zigeffect.causal.nendb_node.v1`
  - retained fields: `job_ref`, `trace_id_ref`, `causal_event_ref`,
    `retry_ref`, `redaction_state`
- `nendb-agent-query-projection-node-handoff-fixture`
  - source fixture: `agent-query-bounded-projection-fixture`
  - target schema: `zigeffect.causal.nendb_node.v1`
  - retained fields: `query_ref`, `trace_data_refs`, `finding_refs`,
    `next_query_refs`, `truncation_state`, `redaction_state`
- `nendb-audit-remediation-node-handoff-fixture`
  - source fixture: `audit-remediation-review-link-fixture`
  - target schema: `zigeffect.causal.nendb_node.v1`
  - retained fields: `audit_chain_ref`, `remediation_review_ref`,
    `comparison_ref`, `evidence_state=review-only`
- `nendb-solid-webui-preview-node-handoff-fixture`
  - source fixture: `solid-webui-readonly-preview-fixture`
  - target schema: `zigeffect.causal.nendb_node.v1`
  - retained fields: `webui_sample_ref`, `solid_view_ref`,
    `read_only_state`, `selection_ref`, `artifact_ref`
- `nendb-ci-advisory-node-handoff-fixture`
  - source fixture: `ci-advisory-artifact-preview-fixture`
  - target schema: `zigeffect.causal.nendb_node.v1`
  - retained fields: `ci_artifact_ref`, `advisory_status_ref`,
    `local_report_ref`, `non_blocking_state`

Edge handoff fixtures:

- `nendb-runtime-to-agent-query-edge-handoff-fixture`
  - target schema: `zigeffect.causal.nendb_edge.v1`
  - retained fields: `from_trace_ref`, `to_query_ref`, `causal_event_ref`,
    `redaction_state`
- `nendb-runtime-to-audit-remediation-edge-handoff-fixture`
  - target schema: `zigeffect.causal.nendb_edge.v1`
  - retained fields: `from_trace_ref`, `to_audit_chain_ref`,
    `to_remediation_review_ref`, `comparison_ref`
- `nendb-artifact-preview-edge-handoff-fixture`
  - target schema: `zigeffect.causal.nendb_edge.v1`
  - retained fields: `from_artifact_ref`, `to_webui_sample_ref`,
    `to_ci_artifact_ref`, `advisory_status_ref`

Every handoff fixture blocks raw payloads, credentials, app mutation,
production history mutation, adapter execution, durable writes, NenDB writes,
Cockroach adapters, CI enforcement, deployment mutation, and live dashboard
hosting.

## Authority Fields

The new artifact fixes:

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

## Validation Checks

The report emits checks:

- `local-fixtures-schema`
- `local-fixtures-status`
- `local-fixtures-decision-approved`
- `handoff-decision`
- `decision-approved`
- `authority-boundary`
- `source-chain-linked`
- `local-fixtures-checks-passed`
- `local-fixtures-verification-recorded`
- `source-fixture-catalog-present`
- `nendb-handoff-catalog-present`
- `nendb-node-handoffs-present`
- `nendb-edge-handoffs-present`
- `runtime-ref-handoff-covered`
- `agent-query-handoff-covered`
- `audit-remediation-handoff-covered`
- `solid-webui-handoff-covered`
- `ci-advisory-handoff-covered`
- `handoff-validation-passed`
- `handoff-verification-recorded`
- `nendb-write-disabled`
- `nendb-adapter-execution-disabled`
- `durable-write-disabled`
- `nendb-only-scope`
- `solid-webui-scope`

The artifact is `ready` only when every check passes and the reviewer chose
`approve`. A rejected review produces `blocked`.

## Required Verification Commands

The handoff review must record:

- exact approved local-fixtures command
- `zig build causal-schema-governance -- --format json`
- `zig build causal-production-hardening-backlog -- --format json`
- `zig build examples`
- `zig build test`

The tool validates that the source local-fixtures artifact itself recorded its
own required verification commands.

## Backlog And Roadmap

Schema governance moves from 87 to 88 schemas.

The production hardening backlog marks
`app-facing-production-integration-nendb-handoff-fixtures` as delivered and
updates the recommendation to:

`start-app-facing-production-integration-audit-remediation-bridge`

Next branch:

`codex/zigeffect-causal-app-facing-production-integration-audit-remediation-bridge`

## Non-Goals

- live app runtime integration
- live agent-query projection over production data
- raw app payload capture
- app config writes
- app data writes
- deployment mutation
- NenDB adapter execution
- NenDB production writes
- durable production writes
- non-NenDB durable adapter work
- Cockroach adapter work
- CI enforcement gates or required status checks
- hosted dashboard or live SolidJS preview
- React or alternate renderer work
- `applied=true`

## Testing Strategy

Use TDD:

1. Start with constants and option/output path tests for the new CLI.
2. Add evaluator/report tests over a ready local-fixtures sample artifact.
3. Add negative tests for unsupported schema, failed source check, authority
   drift, missing source verification evidence, missing handoff verification
   evidence, and missing source fixture catalog ids.
4. Wire into `zig build test`.
5. Generate approved and rejected artifact-chain outputs.
6. Run the broader package and root verification commands before committing.
