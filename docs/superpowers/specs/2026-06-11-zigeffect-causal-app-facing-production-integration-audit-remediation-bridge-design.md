# Zigeffect Causal App-Facing Production Integration Audit/Remediation Bridge Design

## Summary

Build the app-facing audit/remediation bridge artifact for zigeffect's causal
self-improvement roadmap.

The bridge consumes a ready
`zigeffect.causal.app-facing-production-integration-nendb-handoff-fixtures.v1`
artifact and emits
`zigeffect.causal.app-facing-production-integration-audit-remediation-bridge.v1`.
It connects audit-chain comparison refs and remediation review refs into a
review-only bridge that agents can use to understand app issues, propose next
queries, and prepare later guarded remediation work.

This branch does not apply fixes, mutate app state, execute a NenDB adapter,
write durable history, deploy, enforce CI, or prove production health. It makes
the causal evidence more useful to agents and reviewers while preserving the
same no-authority boundary that made the previous branches safe.

## Why This Exists

The previous branch produced record-only NenDB node and edge handoff fixtures
for app runtime refs, agent-query refs, audit/remediation refs, SolidJS preview
refs, and advisory CI refs. That proved the graph handoff shape, but agents
still need a narrower bridge that answers:

- Which audit-chain comparison ref should I cite?
- Which remediation review ref is associated with it?
- Which runtime or agent-query refs explain the issue?
- Which claims are blocked until a later reviewed application branch?
- What should the next branch build?

Without this bridge, an agent can see the handoff catalog but must infer how to
join audit comparison evidence to remediation review evidence. This milestone
makes that join explicit, bounded, schema-governed, and non-mutating.

## Branch

`codex/zigeffect-causal-app-facing-production-integration-audit-remediation-bridge`

## Schema

`zigeffect.causal.app-facing-production-integration-audit-remediation-bridge.v1`

Version: `1`

Category: `app-runtime`

Producer:

- `causal-app-facing-production-integration-audit-remediation-bridge`

Consumers:

- agents
- reviewers
- production-hardening backlog
- future app-facing SolidJS read-only preview
- future app-facing CI advisory report
- future guarded app remediation planning

Compatibility:

- `strict-v1`
- `record-only`
- `audit-remediation-bridge`
- `evidence-only`
- `nendb-handoff-fixture-source`
- `no-cockroach`
- `no-live-telemetry`
- `no-production-mutation`
- `no-nendb-write`
- `no-auto-apply`

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

Output path suffix:

`-audit-remediation-bridge`

Rejected path:

```sh
zig build causal-app-facing-production-integration-audit-remediation-bridge -- \
  --from-handoff ../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures-readiness-review-implementation-proposal-app-facing-boundary-local-fixtures-nendb-handoff-fixtures.json \
  reject \
  --reason "negative audit remediation bridge path" \
  --out-prefix ../../.zig-cache/causal-artifacts/app-facing-production-integration-audit-remediation-bridge-negative
```

## Source Contract

The source handoff artifact must be:

- schema `zigeffect.causal.app-facing-production-integration-nendb-handoff-fixtures.v1`;
- `nendb_handoff_status="ready"`;
- `ready_for_next_branch=true`;
- `decision="approve"`;
- `applied=false`;
- `mutation_authority="none"`;
- `nendb_handoff_fixture_mode=true`;
- `nendb_write_enabled=false`;
- `nendb_adapter_execution_enabled=false`;
- `durable_write_enabled=false`;
- `app_mutation_enabled=false`;
- `app_runtime_integration_enabled=false`;
- `agent_query_live_projection_enabled=false`;
- `solid_webui_preview_enabled=false`;
- all required source checks must be `pass`;
- source required verification commands must be recorded in source verified
  commands.

The bridge reads only the source artifact. It does not read live app state,
production telemetry, databases, GitHub APIs, CI APIs, web dashboards, or
network resources.

## Authority Fields

The bridge artifact must emit:

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

## Bridge Catalog

The emitted `audit_remediation_bridge_records` catalog should contain:

- `audit-chain-comparison-review-bridge`
  - links `audit_chain_ref`, `comparison_ref`, and
    `nendb-runtime-to-audit-remediation-edge-handoff-fixture`;
  - blocks mutation proof and deployed/fixed claims.
- `remediation-review-policy-gate-bridge`
  - links `remediation_review_ref`, policy gate refs, and review status refs;
  - blocks auto-apply and app writes.
- `runtime-to-remediation-evidence-bridge`
  - links runtime trace refs to remediation review refs;
  - blocks raw payload joins and source database reads.
- `agent-query-to-remediation-next-query-bridge`
  - links bounded agent-query refs, finding refs, and next-query refs to
    remediation review refs;
  - blocks raw prompts, raw responses, and unbounded queries.
- `solid-webui-review-preview-bridge`
  - links read-only SolidJS preview refs to bridge review state;
  - blocks live dashboard host, app mutation buttons, React, and alternate
    renderer work.
- `ci-advisory-remediation-report-bridge`
  - links advisory CI artifact refs to bridge review state;
  - blocks required status checks, CI enforcement, workflow mutation, and
    GitHub API mutation.

Each bridge record should include:

- `id`
- `source_handoff_fixture`
- `audit_ref`
- `remediation_ref`
- `bridge_kind`
- `review_state`
- `retained_refs`
- `blocked_claims`

## Checks

The emitted `checks` array must include:

- `handoff-schema`
- `handoff-status`
- `handoff-decision-approved`
- `bridge-decision`
- `decision-approved`
- `authority-boundary`
- `source-chain-linked`
- `handoff-checks-passed`
- `handoff-verification-recorded`
- `handoff-catalog-present`
- `audit-remediation-handoff-present`
- `audit-chain-comparison-ref-present`
- `remediation-review-ref-present`
- `runtime-remediation-edge-present`
- `agent-query-remediation-edge-present`
- `solid-webui-review-preview-covered`
- `ci-advisory-remediation-covered`
- `bridge-catalog-present`
- `bridge-validation-passed`
- `bridge-verification-recorded`
- `mutation-proof-disabled`
- `auto-apply-disabled`
- `app-writes-disabled`
- `nendb-write-disabled`
- `nendb-adapter-execution-disabled`
- `durable-write-disabled`
- `deployment-mutation-disabled`
- `production-health-claim-disabled`
- `nendb-only-scope`
- `solid-webui-scope`

## Validation Checks

The bridge validation catalog must include:

- `source-handoff-ready`
- `source-authority-disabled`
- `source-handoff-catalog-covered`
- `audit-remediation-node-handoff-present`
- `runtime-to-audit-remediation-edge-present`
- `audit-chain-comparison-ref-present`
- `remediation-review-ref-present`
- `runtime-remediation-evidence-linked`
- `agent-query-remediation-evidence-linked`
- `solid-webui-review-preview-linked`
- `ci-advisory-remediation-linked`
- `mutation-proof-disabled`
- `auto-apply-disabled`
- `app-writes-disabled`
- `nendb-write-disabled`
- `nendb-adapter-execution-disabled`
- `durable-write-disabled`
- `deployment-mutation-disabled`
- `production-health-claim-disabled`
- `raw-sensitive-fields-blocked`
- `production-mutation-fields-blocked`
- `non-nendb-scope-rejected`
- `cockroach-scope-rejected`
- `solid-webui-readonly-preview-next-only`

## Status

The output status field is `audit_remediation_bridge_status`.

`ready` means:

- source handoff is ready;
- source handoff checks passed;
- source verification evidence is recorded;
- bridge decision is approve;
- bridge verification evidence is recorded;
- required audit/remediation handoff fixtures and refs are present;
- all authority, write, apply, deployment, production-health, and mutation-proof
  claims remain disabled.

`blocked` means:

- reviewer rejected;
- source handoff is blocked;
- source or bridge checks failed;
- source or bridge verification evidence is missing;
- audit/remediation refs are missing;
- any authority/write/apply/deployment/health/mutation-proof claim is enabled.

## Next Branch

Recommendation:

`start-app-facing-production-integration-solid-webui-readonly-preview`

Next branch:

`codex/zigeffect-causal-app-facing-production-integration-solid-webui-readonly-preview`

That branch should consume ready audit/remediation bridge artifacts and build a
read-only SolidJS preview model inside `webui-dev/zig-webui` without a hosted
live dashboard, app mutation controls, React/alternate renderer work, CI
enforcement, production writes, deployment mutation, or `applied=true`.

## Non-Goals

- live app runtime integration;
- live agent query projection;
- raw app payload capture;
- raw prompt or raw response capture;
- app config writes;
- app data writes;
- remediation auto-apply;
- mutation proof;
- fixed, deployed, or healthy app claims;
- deployment mutation;
- CI enforcement or required status checks;
- NenDB production writes;
- NenDB adapter execution;
- durable production writes;
- non-NenDB durable adapters;
- Cockroach adapter work;
- hosted live dashboard;
- React or alternate renderer work;
- `applied=true`.

## Tests

Focused tool tests should cover:

- constants preserve schema, branch, recommendation, and next branch;
- option parser requires `--from-handoff <json>`, decision, and reason;
- output path suffix is `-audit-remediation-bridge`;
- ready source handoff plus approve decision emits
  `audit_remediation_bridge_status="ready"`;
- reject decision emits `blocked`;
- missing audit/remediation handoff refs blocks readiness;
- source handoff with `nendb_adapter_execution_enabled=true` blocks readiness;
- source handoff with `applied=true` blocks readiness;
- bridge catalog contains every required bridge record;
- JSON/text reports preserve disabled authority fields.

Integration tests should cover:

- `zig build causal-app-facing-production-integration-audit-remediation-bridge`;
- schema governance count bump;
- production hardening backlog next recommendation bump;
- approved artifact generation;
- rejected artifact generation;
- full package and root verification.

## Documentation Updates

Add:

- `packages/zigeffect/docs/app-facing-production-integration-audit-remediation-bridge.md`

Update:

- `packages/zigeffect/docs/app-facing-production-integration-nendb-handoff-fixtures.md`
- `packages/zigeffect/docs/schema-governance.md`
- `packages/zigeffect/docs/production-hardening-backlog.md`
- `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`

## Rollout

1. Commit this design.
2. Write the implementation plan.
3. Build the tool with TDD.
4. Wire the build step.
5. Add schema governance and backlog entries.
6. Add docs and regenerate generated docs.
7. Generate approved and rejected artifacts.
8. Run full verification.
9. Commit the feature milestone.
