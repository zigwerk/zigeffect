# Zigeffect App-Facing Evaluation Report Evaluation Report Evaluation Report Evaluation Report Application Boundary Design

## Context

The local `master` branch has been merged into this work branch; Git reported it was already up to date because `master` is an ancestor of the current causal branch.

The previous milestone delivered:

```text
causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report
```

That tool emits a deterministic local four-level evaluation-report artifact for agents, reviewers, non-blocking CI advisory readers, and the SolidJS `webui-dev/zig-webui` workbench. The hardening backlog now recommends the matching guarded application-boundary branch.

## Goal

Add a record-only application boundary for the four-level evaluation-report artifact. The boundary must let agents distinguish planned local application from reviewed local application while preserving the current safety posture: no app mutation, no CI enforcement, no GitHub mutation, no workflow mutation, no public upload, no deployment mutation, no production health claim, no runtime integration, no NenDB write or adapter execution, and no Cockroach work.

## Source And Output

The tool consumes source reports with schema:

```text
zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report.v1
```

It emits:

```text
zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary.v1
```

The tool should be registered as:

```text
causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary
```

The next branch after a reviewed applied record is:

```text
codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy
```

## Modes

`plan` records local intent only. It must emit `evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_status = "planned"`, keep `applied = false`, keep `ready_for_next_branch = false`, and keep `mutation_authority = "none"`.

`record-applied` records reviewed local application evidence. It may emit `evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_status = "applied"` only when all source, authority, local publication, application evidence, after-report, and verification command checks pass. If any guard fails, it emits a blocked record with `applied = false`.

## Source Contract

The source report must provide the four-level report status:

```text
consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_status
```

Current source lineage comes from the triple evaluation-report layer:

- `source_consumption_report_evaluation_report_evaluation_report_evaluation_report_policy`
- `source_consumption_report_evaluation_report_evaluation_report_evaluation_report_policy_schema`
- `source_evaluation_report_evaluation_report_evaluation_report_policy_status`
- `source_consumption_report_evaluation_report_evaluation_report_evaluation_report_application_boundary`
- `source_consumption_report_evaluation_report_evaluation_report_evaluation_report_application_boundary_schema`
- `source_consumption_report_evaluation_report_evaluation_report_evaluation_report`
- `source_consumption_report_evaluation_report_evaluation_report_evaluation_report_status`
- `source_evaluation_report_evaluation_report_evaluation_report_application_status`
- `source_evaluation_report_evaluation_report_evaluation_report_after_digest`
- `source_evaluation_report_evaluation_report_evaluation_report_after_present`
- `source_evaluation_report_evaluation_report_evaluation_report_application_changes`

Inherited double-layer lineage must remain available:

- `source_consumption_report_evaluation_report_evaluation_report_policy`
- `source_consumption_report_evaluation_report_evaluation_report_policy_schema`
- `source_evaluation_report_evaluation_report_policy_status`
- `source_consumption_report_evaluation_report_evaluation_report_application_boundary`
- `source_consumption_report_evaluation_report_evaluation_report_application_boundary_schema`
- `source_consumption_report_evaluation_report_evaluation_report`
- `source_consumption_report_evaluation_report_evaluation_report_status`
- `source_evaluation_report_evaluation_report_application_status`
- `source_evaluation_report_evaluation_report_application_changes`

The boundary must also preserve request summary, support evidence summary, signal summary, blocked and advisory findings, denied claims, source checks, publication channels, required verification commands, next queries, and agent guidance.

## Safety Rules

The source report is acceptable only when it is ready or advisory, has zero blocked findings, preserves read-only SolidJS webui posture, has local-only publication channels, and keeps every mutation or production authority flag disabled.

The after-report text supplied to `record-applied` must be a bounded local artifact. It must include zigeffect causal application markers and must not claim active required status checks, CI enforcement, workflow mutation, GitHub mutation, app runtime integration, raw payload capture, durable writes, NenDB writes, NenDB adapter execution, Cockroach work, public uploads, hosted dashboards, auto-apply, production health, deployment mutation, mutation authority, React renderer direction, or secrets.

## Output Contract

JSON output includes schema metadata, branch handoff, source report path/schema/status, current and inherited lineage fields, source summaries, source checks, application checks, publication channels, denied claims, verification commands, output paths, and agent guidance. Text output mirrors the same high-signal fields for terminal review.

`mutation_authority` may become `record-only` in an applied record, but that is evidence classification only. It does not grant runtime, app, CI, GitHub, deployment, storage, or production mutation authority.

## Integration

Add the Zig tool, build step, tool tests, docs page, schema governance entry, production hardening backlog item, generated governance/backlog docs, and roadmap handoff.

The governance entry should count as a new app-runtime schema and point future consumers to the four-level policy milestone. The backlog should mark this application-boundary delivered and recommend the four-level policy branch.

## Verification

Focused verification:

- `zig test tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_boundary.zig`
- `zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary -- --help`
- Ready plan artifact generation.
- Ready record-applied artifact generation.
- Blocked source artifact generation.

Project verification:

- `zig build causal-schema-governance -- --format json`
- `zig build causal-production-hardening-backlog -- --format json`
- `zig build examples`
- `zig build test`
- `bun run check`
- `bun run zig:test`
- `git diff --check`

## Design Decision

Continue the concrete causal producer chain for this milestone. The repeated shape is verbose, but it makes each runtime boundary independently inspectable by agents before a later generator or schema-driven template exists.
