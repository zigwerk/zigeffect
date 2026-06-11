# Zigeffect App-Facing Evaluation Report Evaluation Report Application Boundary Design

## Context

The previous milestone added `causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report`, a deterministic report that summarizes the evaluator evidence for app-facing CI advisory remediation report consumption. The hardening backlog now recommends the application-boundary branch for that report.

This branch should follow the existing application-boundary pattern rather than inventing a new authority model. The closest template is `packages/zigeffect/tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_application_boundary.zig`.

## Goal

Add a guarded, record-only application boundary for the evaluation-report-evaluation-report artifact. It lets agents and reviewers distinguish planned local application from reviewed local application, while keeping runtime, GitHub, CI, storage, deployment, and public publication authority disabled.

## Approach

The new tool consumes a source artifact with schema `zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report.v1` and emits schema `zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-application-boundary.v1`.

It supports two modes:

- `plan`: records local application intent, never sets `applied=true`, and does not make the next branch ready.
- `record-applied`: sets `applied=true` only if the source is ready or advisory with no blocked findings, authority remains disabled, local-only publication evidence is intact, reviewed application changes exist, before/after evidence exists, safe after-report content is present, and every required verification command is cited.

## Output Contract

The JSON report includes source references, source status, inherited evaluation-report and report-application evidence, application checks, local publication channels, denied claims, verification commands, and agent guidance. The text report mirrors the high-signal fields for quick terminal review.

The boundary may set `mutation_authority` to `record-only` after a successful reviewed application record. That does not grant app mutation, CI mutation, GitHub mutation, runtime integration, NenDB writes, adapter execution, public uploads, or production-health claims.

## Safety Rules

The source report must keep these authority flags disabled: CI gate/enforcement/workflow/upload/publication, GitHub step summary/comment/API mutation, app mutation/config/data/runtime integration, raw payload capture, deployment mutation, production telemetry, live exporter, network send, OTLP serialization, runtime pipeline, durable writes, NenDB writes, adapter execution, public uploads, hosted dashboard, production health, and auto-apply.

The after-report text must include the bounded read-only zigeffect causal application markers and must not include forbidden claims such as active required status checks, workflow mutation, app runtime integration, durable writes, NenDB adapter execution, Cockroach work, React renderer direction, auto-apply, mutation authority, production health, or secrets.

## Integration

The build target is added to `packages/zigeffect/build.zig`. Schema governance gets one new schema entry, and the production hardening backlog marks this branch delivered while recommending the next policy branch. The master roadmap advances this item to Delivered and adds the next policy branch as the new Next item.

## Verification

Focused verification:

- `zig test tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_application_boundary.zig`
- `zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-application-boundary -- --help`
- Ready, blocked, and unsafe-after-report fixture runs.

Project verification:

- `zig build causal-schema-governance -- --format json`
- `zig build causal-production-hardening-backlog -- --format json`
- `zig build examples`
- `zig build test`
- `bun run check`
- `bun run zig:test`
