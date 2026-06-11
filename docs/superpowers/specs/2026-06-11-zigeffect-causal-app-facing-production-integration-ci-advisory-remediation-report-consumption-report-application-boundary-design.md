# Zigeffect App-Facing Advisory Report Consumption Report Application Boundary Design

## Goal

Add a guarded, record-only application boundary for app-facing advisory remediation report consumption reports. The branch consumes ready or advisory `consumption-report` artifacts and emits planned, applied, or blocked evidence for reviewed local report use by agents, reviewers, non-blocking CI advisory readers, and the SolidJS `webui-dev/zig-webui` workbench.

This branch does not wire reports into apps, mutate workbench state, publish artifacts, create CI status checks, call GitHub APIs, write NenDB, execute a NenDB adapter, add Cockroach scope, deploy anything, or prove production health.

## Context

The source producer is:

- Tool: `causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report`
- Schema: `zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report.v1`
- Handoff branch: `codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-application-boundary`

The new producer follows the existing application-boundary pattern used by:

- `causal-app-facing-production-integration-ci-advisory-remediation-report-application-boundary`
- `causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-boundary`
- `causal-production-telemetry-ci-gate-advisory-ci-report-application-boundary`

Those tools establish the local convention: `plan` records intent only, `record-applied` records evidence only after source checks, before evidence, after evidence, safe after-content, and verification commands pass.

## Command

```bash
zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-application-boundary -- \
  --from-report <consumption-report.json> \
  plan|record-applied \
  --reason <reason> \
  [--report-after <report.txt|report.md|report.json>] \
  [--report-application-change <evidence>]... \
  [--before <evidence>]... \
  [--after <evidence>]... \
  [--verified-command <command>]... \
  [--by <actor>] \
  [--policy <policy>] \
  [--out-prefix <path-prefix>]
```

The default output prefix replaces `-ci-advisory-remediation-report-consumption-report.json` with `-ci-advisory-remediation-report-consumption-report-application-boundary`. Long generated file names collapse to a compact deterministic prefix using the existing short path digest pattern.

## Output Schema

The new schema is:

`zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-application-boundary.v1`

Required top-level fields include:

- `schema`
- `schema_version`
- `generated_by`
- `source_consumption_report`
- `source_consumption_report_status`
- `source_ready_for_next_branch`
- `source_mutation_authority`
- `source_evaluator_status`
- `source_consumption_policy`
- `source_consumption_boundary`
- `source_consumption_readiness`
- `source_publication_policy`
- `source_after_report_digest`
- `source_consumer_after_digest`
- `mode`
- `report_application_status`
- `applied`
- `ready_for_next_branch`
- `mutation_authority`
- disabled authority booleans
- `reviewed_by`
- `policy`
- `reason`
- `report_after_path`
- `report_after_digest`
- `report_after_present`
- `report_application_changes`
- `before_evidence`
- `after_evidence`
- `application_checks`
- source summaries, findings, checks, denied claims, publication channels, and next queries
- `boundary_rules`
- `denied_application_claims`
- `negative_fixtures`
- `required_verification_commands`
- `verified_commands`
- `source_branch`
- `recommendation`
- `next_branch_if_applied`
- `json_output`
- `text_output`
- `agent_guidance`

## Source Contract

A source report is usable when all of these are true:

- `schema` is `zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report.v1`.
- `schema_version` is `1`.
- `consumption_report_status` is `ready` or `advisory`.
- `ready_for_next_branch` is `true`.
- `blocked_findings_count` is `0`.
- `mutation_authority` is `none`.
- All mutation, runtime, deployment, durable write, CI enforcement, GitHub mutation, app mutation, public upload, and adapter execution booleans remain false.
- `advisory_report`, `read_only_preview`, `read_only_consumption_enabled`, and `solid_webui_enabled` remain true.
- `solid_webui_renderer` is `solidjs`.
- `webui_bridge` is `webui-dev/zig-webui`.
- `source_evaluator_status`, `source_consumption_policy`, `source_consumption_boundary`, `source_consumption_readiness`, and `source_publication_policy` are present.
- `source_after_report_digest` and `source_consumer_after_digest` are present.
- `request_summary`, `support_evidence_summary`, and `signal_summary` are present.
- Source report `checks` contain no `fail`.
- `denied_claims`, `next_queries`, `publication_channels`, and `required_verification_commands` are present.
- Source report `publication_channels` remain local-only and do not claim execution, upload, GitHub write, public publication, or app/runtime mutation.

Advisory source reports are allowed only when they are still ready for next branch and have zero blocked findings. This preserves the difference between "advisory information exists" and "blocked source cannot be applied".

## Modes

### Plan

`plan` records intent only:

- `report_application_status` is `planned` when source checks pass.
- `applied` is always `false`.
- `ready_for_next_branch` is always `false`.
- `mutation_authority` is always `none`.
- before/after/change/verification checks are skipped.
- optional after-report content may be checked if supplied.

Plan output cannot be consumed as applied evidence by the next branch.

### Record Applied

`record-applied` records reviewed evidence only:

- `report_application_status` is `applied` only when every source, evidence, safety, and verification check passes.
- `applied` is true only for the all-pass case.
- `ready_for_next_branch` is true only for the all-pass case.
- `mutation_authority` is `record-only` only for the all-pass case.
- failed gates produce `report_application_status="blocked"`, `applied=false`, `ready_for_next_branch=false`, and `mutation_authority="none"`.

`record-applied` requires:

- at least one `--report-application-change`
- at least one `--before`
- at least one `--after`
- `--report-after`
- safe after-report content
- all required verification commands

## After-Report Safety

After-report content must include all required markers:

- `zigeffect`
- `causal`
- `read-only`
- `consumption`
- `report`
- `application`

After-report content must not contain prohibited markers for:

- required status checks
- CI gate enforcement
- workflow mutation
- GitHub API mutation
- step summary writes
- pull request comments
- CI artifact upload execution
- public artifact publication
- app mutation
- app config writes
- app data writes
- app runtime integration
- live agent projection
- raw prompt, response, or payload capture
- deployment mutation
- production health proof
- durable writes
- NenDB writes
- NenDB adapter execution
- Cockroach scope
- non-NenDB durable scope
- alternate renderers including React
- auto-apply
- mutation authority grants
- secrets or telemetry tokens

## Authority Model

The artifact is evidence, not authority.

Always false:

- `ci_gate_enabled`
- `ci_gate_enforcement_enabled`
- `ci_required_status_check_enabled`
- `ci_workflow_mutation_enabled`
- `ci_upload_execution_enabled`
- `ci_report_publication_enabled`
- `github_step_summary_write_enabled`
- `pull_request_comment_enabled`
- `github_api_mutation_enabled`
- `app_mutation_controls_enabled`
- `app_mutation_enabled`
- `app_config_write_enabled`
- `app_data_write_enabled`
- `app_runtime_integration_enabled`
- `agent_query_live_projection_enabled`
- `raw_payload_capture_enabled`
- `deployment_mutation_enabled`
- `production_telemetry_ingestion`
- `live_exporter_enabled`
- `network_send_enabled`
- `collector_endpoint_configured`
- `otlp_serialization_enabled`
- `runtime_pipeline_enabled`
- `durable_write_enabled`
- `nendb_write_enabled`
- `nendb_adapter_execution_enabled`
- `public_artifact_upload_enabled`
- `hosted_live_dashboard_enabled`
- `production_health_claim_enabled`
- `auto_apply_enabled`

Positive identity booleans remain descriptive only:

- `advisory_report=true`
- `read_only_preview=true`
- `read_only_consumption_enabled=true`
- `solid_webui_enabled=true`
- `solid_webui_renderer="solidjs"`
- `webui_bridge="webui-dev/zig-webui"`

## Negative Fixtures

The tool must deny:

- blocked source reports
- advisory source reports with blocked findings
- source reports not ready for next branch
- source mutation authority drift
- source public publication or upload claims
- plan mode claiming applied
- missing report application change evidence
- missing before evidence
- missing after evidence
- missing after-report content
- unsafe after-report content
- incomplete verification commands
- app runtime integration claims
- live projection claims
- raw prompt, response, or payload capture
- NenDB writes
- NenDB adapter execution
- Cockroach or non-NenDB durable scope
- React or alternate renderer scope
- auto-apply claims
- production health proof
- mutation authority grants

## Next Branch

When applied evidence exists, the next branch should be:

`codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-policy`

That branch should interpret applied report-application-boundary evidence and define how agents, reviewers, advisory CI readers, and the SolidJS webui can consume applied local report records without mutation authority.

## Verification

Required verification commands for applied records:

```bash
bun run zigeffect:workbench:typecheck
bun run zigeffect:workbench:test
zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report -- --help
zig build causal-schema-governance -- --format json
zig build causal-production-hardening-backlog -- --format json
zig build examples
zig build test
```

Branch completion verification also runs:

```bash
zig test tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_application_boundary.zig
zig test tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report.zig
zig test --dep causal_artifact -Mroot=tools/causal_schema_governance.zig -Mcausal_artifact=tools/causal_artifact.zig
zig test tools/causal_production_hardening_backlog.zig
zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-application-boundary -- --help
zig build test
zig build examples
bun run check
bun run zig:test
git diff --check
```
