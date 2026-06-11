# Zigeffect Causal App-Facing Production Integration SolidJS Read-Only Preview Design

## Summary

Build the app-facing SolidJS read-only preview milestone for zigeffect's causal
self-improvement roadmap.

The milestone consumes a ready
`zigeffect.causal.app-facing-production-integration-audit-remediation-bridge.v1`
artifact and emits
`zigeffect.causal.app-facing-production-integration-solid-webui-readonly-preview.v1`.
It also teaches the existing SolidJS workbench to render that preview as a
local, bounded, read-only app-facing evidence surface.

The preview helps agents and humans inspect how app runtime refs, bounded
agent-query refs, audit/remediation refs, advisory CI refs, and blocked claims
fit together. It does not host a live dashboard, mutate app state, execute a
NenDB adapter, write durable history, enforce CI, deploy, prove production
health, auto-apply remediation, or mark anything as applied.

## Branch

`codex/zigeffect-causal-app-facing-production-integration-solid-webui-readonly-preview`

## Design Options

### Recommended: Artifact plus workbench model/view

Build a Zig artifact gate and a SolidJS workbench reader in one milestone.
This follows the production telemetry read-only preview pattern while making
the app-facing path useful immediately. The Zig artifact proves source bridge
readiness and records preview authority. The SolidJS workbench parses the
artifact, shows bridge records, authority state, verification commands, blocked
claims, and next-branch guidance.

This is the best fit because the roadmap branch name promises a SolidJS
read-only preview, not only a planning artifact.

### Artifact only

Emit the preview artifact but leave workbench rendering for a later branch.
This is easier, but it leaves the milestone less useful and forces agents to
inspect raw JSON rather than a purpose-built app-facing preview model.

### Workbench only

Teach the workbench to read the previous audit/remediation bridge artifact
directly without a new schema. This is quick but skips schema governance,
backlog sequencing, and review evidence. It would weaken the causal artifact
chain and make the next branch harder to validate.

## Schema

`zigeffect.causal.app-facing-production-integration-solid-webui-readonly-preview.v1`

Version: `1`

Category: `app-runtime`

Producer:

- `causal-app-facing-production-integration-solid-webui-readonly-preview`

Consumers:

- agents
- reviewers
- SolidJS workbench
- production-hardening backlog
- future app-facing CI advisory remediation report
- future guarded app remediation planning

Compatibility:

- `strict-v1`
- `record-only`
- `solid-webui`
- `workbench-readonly-preview`
- `app-facing-evidence`
- `audit-remediation-bridge-source`
- `nendb-only`
- `no-cockroach`
- `no-live-dashboard`
- `no-production-mutation`
- `no-nendb-write`
- `no-auto-apply`

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

Output path suffix:

`-solid-webui-readonly-preview`

Rejected path:

```sh
zig build causal-app-facing-production-integration-solid-webui-readonly-preview -- \
  --from-bridge ../../.zig-cache/causal-artifacts/app-facing-production-integration-fixtures-readiness-review-implementation-proposal-app-facing-boundary-local-fixtures-nendb-handoff-fixtures-audit-remediation-bridge.json \
  reject \
  --reason "negative SolidJS read-only preview path" \
  --out-prefix ../../.zig-cache/causal-artifacts/app-facing-production-integration-solid-webui-readonly-preview-negative
```

## Source Contract

The source bridge artifact must be:

- schema `zigeffect.causal.app-facing-production-integration-audit-remediation-bridge.v1`;
- `audit_remediation_bridge_status="ready"`;
- `ready_for_next_branch=true`;
- `decision="approve"`;
- `applied=false`;
- `mutation_authority="none"`;
- `audit_remediation_bridge_mode=true`;
- `mutation_proof_claim_enabled=false`;
- `auto_apply_enabled=false`;
- `production_health_claim_enabled=false`;
- `nendb_write_enabled=false`;
- `nendb_adapter_execution_enabled=false`;
- `durable_write_enabled=false`;
- `app_mutation_enabled=false`;
- `app_config_write_enabled=false`;
- `app_data_write_enabled=false`;
- `deployment_mutation_enabled=false`;
- `app_runtime_integration_enabled=false`;
- `agent_query_live_projection_enabled=false`;
- `solid_webui_preview_enabled=false`;
- every required source check must be `pass`;
- source required verification commands must be recorded in source verified
  commands;
- source bridge records must contain all six expected ids.

The preview reads only the source bridge artifact and bundled local workbench
sample files. It does not read live app state, production telemetry, databases,
GitHub APIs, CI APIs, network resources, or hosted dashboards.

## Authority Fields

The preview artifact must emit:

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

## Preview Model

The emitted `app_preview_panels` catalog should contain:

- `status`
- `source-artifacts`
- `authority-boundary`
- `audit-remediation-bridge-records`
- `runtime-remediation-evidence`
- `agent-query-next-queries`
- `solid-webui-preview-state`
- `ci-advisory-state`
- `verification`
- `blocked-claims`
- `non-goals`
- `next-branch`

The emitted `app_preview_sections` catalog should contain:

- `audit-chain-comparison`
  - retains `audit_chain_ref`, `comparison_ref`, and review state;
  - blocks mutation proof and fixed/deployed claims.
- `remediation-review`
  - retains `remediation_review_ref`, policy gate refs, and review status refs;
  - blocks auto-apply and app writes.
- `runtime-evidence`
  - retains runtime trace refs and causal event refs;
  - blocks raw payload joins and source database reads.
- `agent-query-evidence`
  - retains bounded trace refs, finding refs, and next-query refs;
  - blocks raw prompts, raw responses, and unbounded queries.
- `solid-webui-preview`
  - retains `webui_sample_ref`, `solid_view_ref`, and read-only state;
  - blocks live dashboard hosting, app mutation buttons, React, and alternate
    renderer work.
- `ci-advisory`
  - retains `ci_artifact_ref`, advisory status refs, and review state;
  - blocks required status checks, CI enforcement, workflow mutation, and
    GitHub API mutation.

Each preview section should include:

- `id`
- `source_bridge_record`
- `title`
- `summary`
- `retained_refs`
- `blocked_claims`
- `panel`

## Workbench Surface

The existing SolidJS workbench should gain an app-facing read-only preview
model and view:

- `deriveAppFacingPreviewModel(raw, options)` in
  `packages/zigeffect/workbench/src/causalArtifact.ts`;
- exported types for app-facing preview authority, checks, bridge records, and
  preview sections;
- a new `app-preview` tab shown only when an app-facing preview artifact or its
  source audit/remediation bridge artifact is loaded;
- read-only panels for status, source chain, authority boundary, bridge
  records, preview sections, checks, verification commands, blocked claims,
  non-goals, warnings, and next branch;
- no app mutation controls, no hosted live dashboard controls, no React or
  alternate renderer toggle, and no CI enforcement controls.

The UI should reuse the existing workbench style primitives:

- `Metric`
- `ChainSources`
- `CommandList`
- `TelemetryStringPanel`
- card/grid layouts already used by the Telemetry tab

The preview tab should remain dense and operational. It should not become a
landing page, marketing page, or decorative product UI.

## Checks

The emitted `checks` array must include:

- `bridge-schema`
- `bridge-status`
- `bridge-decision-approved`
- `preview-decision`
- `decision-approved`
- `authority-boundary`
- `source-chain-linked`
- `bridge-checks-passed`
- `bridge-verification-recorded`
- `bridge-catalog-present`
- `preview-panels-present`
- `preview-sections-present`
- `solid-webui-readonly`
- `solid-renderer`
- `webui-bridge-scope`
- `app-mutation-controls-disabled`
- `hosted-live-dashboard-disabled`
- `react-renderer-disabled`
- `alternate-renderer-disabled`
- `preview-verification-recorded`
- `nendb-write-disabled`
- `nendb-adapter-execution-disabled`
- `durable-write-disabled`
- `deployment-mutation-disabled`
- `auto-apply-disabled`
- `mutation-proof-disabled`
- `production-health-claim-disabled`
- `nendb-only-scope`

## Validation Checks

The preview validation catalog must include:

- `source-bridge-ready`
- `source-authority-disabled`
- `source-bridge-catalog-covered`
- `source-bridge-verification-recorded`
- `preview-panels-covered`
- `preview-sections-covered`
- `audit-chain-comparison-section-present`
- `remediation-review-section-present`
- `runtime-evidence-section-present`
- `agent-query-evidence-section-present`
- `solid-webui-preview-section-present`
- `ci-advisory-section-present`
- `solid-webui-readonly`
- `solidjs-renderer-only`
- `webui-bridge-local-only`
- `hosted-live-dashboard-disabled`
- `app-mutation-controls-disabled`
- `react-renderer-disabled`
- `alternate-renderer-disabled`
- `raw-sensitive-fields-blocked`
- `production-mutation-fields-blocked`
- `auto-apply-disabled`
- `mutation-proof-disabled`
- `production-health-claim-disabled`
- `nendb-write-disabled`
- `nendb-adapter-execution-disabled`
- `durable-write-disabled`
- `deployment-mutation-disabled`
- `ci-enforcement-disabled`
- `cockroach-scope-rejected`

## Status

The output status field is `solid_webui_readonly_preview_status`.

`ready` means:

- source bridge schema/status/decision are valid;
- source and preview verification evidence is recorded;
- all required bridge records, preview panels, and preview sections are present;
- SolidJS/WebUI scope is explicit;
- app mutation controls, hosted live dashboard, React/alternate renderer work,
  CI enforcement, app writes, NenDB writes, adapter execution, durable writes,
  deployment mutation, auto-apply, mutation proof, and production health claims
  remain disabled.

`blocked` means:

- reviewer rejected;
- source bridge is blocked;
- source or preview checks failed;
- source or preview verification evidence is missing;
- required preview panels or sections are missing;
- any authority/write/apply/deployment/health/mutation-proof/apply claim is
  enabled.

## Next Branch

Recommendation:

`start-app-facing-production-integration-ci-advisory-remediation-report`

Next branch:

`codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report`

That branch should consume ready SolidJS read-only preview artifacts and build
an advisory CI remediation report artifact only. It should not enforce required
status checks, mutate workflows, call GitHub APIs, apply remediation, write
production app data, deploy, or mark `applied=true`.

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
- GitHub API mutation;
- workflow mutation;
- NenDB production writes;
- NenDB adapter execution;
- durable production writes;
- non-NenDB durable adapters;
- Cockroach adapter work;
- hosted live dashboard;
- React or alternate renderer work;
- app mutation buttons;
- `applied=true`.

## Tests

Focused Zig tool tests should cover:

- constants preserve schema, branch, recommendation, and next branch;
- option parser requires `--from-bridge <json>`, decision, and reason;
- output path suffix is `-solid-webui-readonly-preview`;
- ready source bridge plus approve decision emits
  `solid_webui_readonly_preview_status="ready"`;
- reject decision emits `blocked`;
- source bridge with `app_data_write_enabled=true` blocks readiness;
- source bridge with `solid_webui_preview_enabled=true` blocks readiness because
  live/hosted preview is still not allowed;
- preview panels and preview sections are complete;
- JSON/text reports preserve disabled authority fields.

Workbench tests should cover:

- `deriveAppFacingPreviewModel` reads ready preview artifacts;
- `deriveAppFacingPreviewModel` reads ready source bridge artifacts as a
  source preview model;
- blocked artifacts preserve blocked status;
- app-facing preview tabs appear only for app-facing preview/bridge artifacts;
- app-facing preview UI helper rows mark mutation/write/CI/renderer controls as
  disabled;
- sample app-facing preview artifact can be loaded through the WebUI bridge.

Integration tests should cover:

- `zig build causal-app-facing-production-integration-solid-webui-readonly-preview`;
- schema governance count bump;
- production hardening backlog next recommendation bump;
- approved artifact generation;
- rejected artifact generation;
- `bun run zigeffect:workbench:typecheck`;
- `bun run zigeffect:workbench:test`;
- full package and root verification.

## Documentation Updates

Add:

- `packages/zigeffect/docs/app-facing-production-integration-solid-webui-readonly-preview.md`
- `packages/zigeffect/workbench/public/sample-app-facing-solid-webui-readonly-preview.json`

Update:

- `packages/zigeffect/docs/app-facing-production-integration-audit-remediation-bridge.md`
- `packages/zigeffect/docs/schema-governance.md`
- `packages/zigeffect/docs/production-hardening-backlog.md`
- `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`

## Rollout

1. Commit this design.
2. Write the implementation plan.
3. Build the Zig preview artifact tool with TDD.
4. Wire the build step.
5. Add workbench parsing, sample artifact, UI helpers, and preview tab with TDD.
6. Add schema governance and backlog entries.
7. Add docs and regenerate generated docs.
8. Generate approved and rejected artifacts.
9. Run full verification.
10. Commit the feature milestone.
