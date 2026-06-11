# Zigeffect App-Facing Evaluation Report Evaluation Report Evaluation Report Application Boundary Design

## Context

The previous milestone added `causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report`, a deterministic local report that summarizes the evaluation-report evaluation-report evaluator evidence for app-facing CI advisory remediation report consumption. The hardening backlog now recommends the application-boundary branch for that report.

This branch should follow the existing guarded application-boundary pattern. The closest template is `packages/zigeffect/tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_application_boundary.zig`, retargeted one generation deeper.

## Goal

Add a guarded, record-only application boundary for the evaluation-report evaluation-report evaluation-report artifact. It lets agents and reviewers distinguish planned local application from reviewed local application, while keeping runtime, GitHub, CI, storage, deployment, public publication, NenDB writes, adapter execution, Cockroach scope, and mutation authority disabled.

## Approach

The new tool consumes a source artifact with schema:

```text
zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report.v1
```

It emits:

```text
zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-application-boundary.v1
```

It supports two modes:

- `plan`: records local application intent, never sets `applied=true`, and never makes the next branch ready.
- `record-applied`: sets `applied=true` only if the source is ready or advisory with no blocked findings, authority remains disabled, local-only publication evidence is intact, reviewed application changes exist, before/after evidence exists, safe after-report content is present, and every required verification command is cited.

## Source Contract

The source report must carry the triple report fields:

- `consumption_report_evaluation_report_evaluation_report_evaluation_report_status`;
- `source_consumption_report_evaluation_report_evaluation_report_policy`;
- `source_evaluation_report_evaluation_report_policy_status`;
- `source_consumption_report_evaluation_report_evaluation_report_application_boundary`;
- `source_evaluation_report_evaluation_report_application_status`;
- `source_consumption_report_evaluation_report_evaluation_report`;
- `source_consumption_report_evaluation_report_evaluation_report_status`;
- `source_evaluation_report_evaluation_report_after_digest` and `source_evaluation_report_evaluation_report_after_present`;
- source request/support/signal summaries, blocked/advisory findings, denied claims, local publication channels, and required verification commands.

The boundary preserves inherited report, evaluation-report, and application evidence so the next policy can reason about lineage without inferring runtime or mutation authority.

## Output Contract

The JSON report includes source references, source status, inherited evaluation-report evidence, application checks, local publication channels, denied claims, verification commands, output paths, and agent guidance. The text report mirrors high-signal fields for terminal review.

The boundary may set `mutation_authority` to `record-only` after a successful reviewed application record. That does not grant app mutation, CI mutation, GitHub mutation, runtime integration, NenDB writes, adapter execution, public uploads, deployment authority, or production-health claims.

## Safety Rules

The source report must keep these authority flags disabled: CI gate/enforcement/workflow/upload/publication, GitHub step summary/comment/API mutation, app mutation/config/data/runtime integration, raw payload capture, deployment mutation, production telemetry, live exporter, network send, OTLP serialization, runtime pipeline, durable writes, NenDB writes, adapter execution, public uploads, hosted dashboard, production health, and auto-apply.

The after-report text must include bounded read-only zigeffect causal application markers and must not include forbidden claims such as active required status checks, workflow mutation, app runtime integration, durable writes, NenDB adapter execution, Cockroach work, React renderer direction, auto-apply, mutation authority, production health, or secrets.

## Integration

The build target is added to `packages/zigeffect/build.zig`. Schema governance gets one new schema entry, and the production hardening backlog marks this branch delivered while recommending the next triple policy branch:

```text
codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-policy
```

The master roadmap advances this item to Delivered and adds the policy branch as the new Next item.

## Verification

Focused verification:

- `zig test tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_application_boundary.zig`
- `zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-application-boundary -- --help`
- ready, blocked, and unsafe-after-report fixture runs.

Project verification:

- `zig build causal-schema-governance -- --format json`
- `zig build causal-production-hardening-backlog -- --format json`
- `zig build examples`
- `zig build test`
- `bun run check`
- `bun run zig:test`
- `git diff --check`
