# zigeffect Causal Production Telemetry CI Gate Advisory CI Report Design

## Summary

Create `causal-production-telemetry-ci-gate-advisory-ci-report`, a bounded,
record-only report renderer that consumes a dry-run evaluator artifact and
emits deterministic JSON and text advisory CI report artifacts for reviewers
and agents.

This branch still does not enable CI gate enforcement, required status checks,
workflow mutation, artifact upload execution, GitHub step-summary writes, pull
request comments, live telemetry ingestion, network calls, collector
configuration, OTLP serialization, durable writes, NenDB writes, production
health claims, production cluster readiness claims, non-NenDB durable adapter
scope, alternate renderer scope, or mutation authority.

## Goals

- Consume
  `zigeffect.causal.production-telemetry-ci-gate-dry-run-evaluator.v1`
  artifacts.
- Accept evaluator artifacts with `evaluation_status="ready"` or
  `evaluation_status="advisory-findings"` when `ready_for_next_branch=true`
  and `blocked_findings_count=0`.
- Emit a reviewer-facing report artifact with a compact status headline,
  source summary, signal summary, advisory finding summary, next queries, and
  blocked claims.
- Preserve enough structured JSON for agents to decide which follow-up queries
  or evidence files to inspect.
- Convert blocked or invalid evaluator artifacts into blocked advisory-report
  artifacts rather than treating them as reportable CI guidance.
- Keep publication local and record-only. The tool writes JSON and text output
  files only.

## Non-Goals

- No CI enforcement.
- No required GitHub status checks.
- No workflow edits or workflow mutation by the tool.
- No artifact upload execution.
- No GitHub step-summary writes.
- No pull request comments.
- No network calls, live telemetry ingestion, collector endpoint probing, or
  OTLP serialization.
- No durable production storage writes and no NenDB writes.
- No production health, deployment success, capacity, customer impact, or
  production cluster readiness claims.
- No Cockroach, non-NenDB durable adapter, or alternate frontend renderer work.
- No mutation authority.

## CLI

```sh
zig build causal-production-telemetry-ci-gate-advisory-ci-report -- \
  --from-evaluator <dry-run-evaluator.json> \
  summarize \
  --reason <reason>
```

Optional flags:

- `--by <actor>`: reviewer or agent id. Defaults to
  `ci-gate-advisory-ci-report`.
- `--policy <policy>`: policy id. Defaults to
  `manual-production-telemetry-ci-gate-advisory-ci-report`.
- `--out-prefix <path-prefix>`: override output paths.

Default output path replacement:

- `*-ci-gate-dry-run-evaluator.json` becomes
  `*-ci-gate-advisory-ci-report.json`.
- Text output uses the same prefix with `.txt`.

## Source Evaluator Contract

The source evaluator artifact is reportable when:

- `schema` is
  `zigeffect.causal.production-telemetry-ci-gate-dry-run-evaluator.v1`.
- `schema_version` is `1`.
- `evaluation_status` is `ready` or `advisory-findings`.
- `ready_for_next_branch=true`.
- `blocked_findings_count=0`.
- `ci_gate_enforcement_enabled=false`.
- `ci_required_status_check_enabled=false`.
- `ci_workflow_mutation_enabled=false`.
- `ci_upload_execution_enabled=false`.
- `production_telemetry_ingestion=false`.
- `live_exporter_enabled=false`.
- `network_send_enabled=false`.
- `collector_endpoint_configured=false`.
- `otlp_serialization_enabled=false`.
- `runtime_pipeline_enabled=false`.
- `durable_write_enabled=false`.
- `nendb_write_enabled=false`.
- `signal_evaluations`, `findings`, `next_queries`, `checks`, and
  `blocked_claims` are present.
- No source finding has `severity="blocked"`.

Blocked evaluator artifacts are consumed as negative evidence and produce
`report_status="blocked"` with `ready_for_next_branch=false`.

## Report Status

- `ready`: source evaluator status is `ready`, has no advisory findings, and
  all report checks pass.
- `advisory`: source evaluator status is `advisory-findings`, has no blocked
  findings, and all report checks pass.
- `blocked`: source evaluator is invalid, blocked, contains blocked findings,
  violates authority flags, or lacks required report sections.

`ready_for_next_branch=true` for `ready` and `advisory`. It is false for
`blocked`.

## Report Sections

The JSON report includes:

- `schema`
- `schema_version`
- `source_evaluator`
- `source_evaluation_status`
- `report_status`
- `ready_for_next_branch`
- disabled authority flags
- `reviewed_by`
- `policy`
- `reason`
- `headline`
- `report_sections`
- `signal_summary`
- `advisory_findings`
- `next_queries`
- `checks`
- `blocked_claims`
- `publication_channels`
- `required_verification_commands`
- `generated_by`
- `source_branch`
- `recommendation`
- `next_branch_if_ready`
- `json_output`
- `text_output`
- `agent_guidance`

The text report is optimized for local CI artifact review. It is not written
to GitHub step summary or a pull request by this tool.

## Publication Channels

The report records publication channels as data:

- `local-json-artifact`: allowed, written by the tool.
- `local-text-artifact`: allowed, written by the tool.
- `ci-upload-artifact`: proposed only, not executed by the tool.
- `github-step-summary`: proposed only, not written by the tool.
- `pull-request-comment`: proposed only, not posted by the tool.

The tool must emit:

- `ci_report_publication_enabled=false`
- `github_step_summary_write_enabled=false`
- `pull_request_comment_enabled=false`
- `ci_upload_execution_enabled=false`
- `ci_workflow_mutation_enabled=false`

## Checks

The advisory report performs these checks:

- `source-evaluator-schema`: source schema and version are supported.
- `source-evaluator-reportable`: source status is `ready` or
  `advisory-findings`.
- `source-ready-for-next-branch`: source is ready for advisory CI report work.
- `source-no-blocked-findings`: source has zero blocked findings and no
  blocked-severity finding entries.
- `source-disabled-authority`: all CI enforcement, workflow mutation, upload,
  live telemetry, network, runtime pipeline, durable, and NenDB authority flags
  are false.
- `source-report-sections-present`: source has signal evaluations, findings,
  next queries, checks, and blocked claims.
- `report-publication-record-only`: report publication fields are all
  record-only and non-executing.

## Handoff

Ready or advisory report artifacts hand off to
`codex/zigeffect-causal-production-telemetry-ci-gate-advisory-ci-report-application-boundary`.
That next branch should define how a reviewed CI workflow or external process
may attach the report artifact to CI without this tool mutating workflows,
creating required checks, uploading artifacts, posting comments, writing step
summaries, enabling live telemetry, writing durable stores, writing NenDB, or
granting mutation authority.

## Tests

Focused Zig tests must cover:

- schema and branch constants
- CLI parsing
- default output path replacement
- ready report from a ready evaluator artifact
- advisory report from an advisory evaluator artifact
- blocked report from a blocked evaluator artifact
- blocked report when source authority flags are enabled
- publication channels remain record-only

Build-level verification must include:

- `zig test tools/causal_production_telemetry_ci_gate_advisory_ci_report.zig`
- `zig build causal-production-telemetry-ci-gate-advisory-ci-report -- --help`
- ready or advisory report artifact generation
- blocked report artifact generation
- `zig build causal-schema-governance -- --format json`
- `zig build causal-production-hardening-backlog -- --format json`
- `zig build examples`
- `zig build test`
- `bun run check`
- `bun run zig:test`
- `git diff --check`
