# Zigeffect App-Facing Evaluation Report Evaluation Report Evaluation Report Evaluation Report Evaluation Report Design

## Context

The active branch follows the delivered four-level evaluator milestone:

```text
codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator
```

That evaluator consumes a ready four-level policy artifact and classifies bounded request/support evidence. The production hardening backlog now recommends the matching five-level local report producer.

## Goal

Add a read-only report producer that consumes four-level evaluator artifacts and emits a compact five-level local evaluation-report artifact for agents, reviewers, non-blocking CI advisory readers, and the SolidJS `webui-dev/zig-webui` workbench.

The report must preserve the project direction: SolidJS inside WebUI, NenDB adapter direction only, no Cockroach expansion, no CI enforcement, no required status check, no GitHub mutation, no workflow mutation, no app mutation, no app runtime integration, no raw payload capture, no durable writes, no NenDB writes, no NenDB adapter execution, no public upload, no hosted dashboard, no deployment mutation, no production health claim, and no auto-apply.

## Source And Output

The tool consumes evaluator artifacts with schema:

```text
zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator.v1
```

It emits:

```text
zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report.v1
```

The build target is:

```text
causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report
```

The next branch after a ready or advisory report is:

```text
codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary
```

## Report Status

`ready` means the source evaluator is ready, non-mutating, locally bounded, and contains request/support evidence plus carried source lineage.

`advisory` means the source evaluator is advisory but safe for local review and next-step planning.

`blocked` means the source evaluator is blocked, unsafe, has authority drift, uses an unsupported schema, lacks required source evidence, or fails report preconditions.

## Source Contract

The source evaluator must provide:

- `schema` matching the four-level evaluator schema.
- `schema_version = 1`.
- `evaluation_status` of `ready` or `advisory-findings` for handoff.
- `ready_for_next_branch = true` for ready/advisory handoff.
- `mutation_authority = "none"`.
- current five-level source policy/application/report fields carried by the four-level evaluator.
- inherited four-level policy/application/report fields carried by the four-level evaluator.
- original advisory remediation consumption report lineage, before/after evidence, publication channels, denied claims, checks, signals, request files, support evidence, findings, and next queries.

Blocked evaluator artifacts must remain consumable for negative fixtures and produce blocked report artifacts with `ready_for_next_branch = false`.

## Output Contract

JSON output includes schema metadata, source evaluator path/schema/status, source branch, recommendation, next branch, authority flags, report status, source request/support summaries, carried source lineage, current and inherited application evidence, denied claims, checks, signals, findings, boundary rules, publication channel ids, next queries, and agent guidance.

Text output mirrors the same high-signal fields for terminal review.

`mutation_authority` is always `none`. The tool does not apply, publish, enforce, upload, write, deploy, integrate runtime state, mutate application state, execute adapters, or contact external services.

## Integration

Add the Zig tool, build step, tool tests, docs page, schema governance entry, production hardening backlog item, regenerated governance/backlog docs, and roadmap handoff.

The governance entry should count as a new app-runtime schema and point future consumers to the five-level application-boundary producer. The backlog should mark this report delivered and recommend the five-level application-boundary branch.

## Verification

Focused verification:

- `zig test tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report.zig`
- `zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report -- --help`
- Ready report generation from the real ready four-level evaluator artifact.
- Advisory report generation from the advisory four-level evaluator artifact.
- Blocked report generation from the blocked four-level evaluator artifact.

Project verification:

- `zig build causal-schema-governance -- --format json`
- `zig build causal-production-hardening-backlog -- --format json`
- `zig build examples`
- `zig build test`
- `bun run check`
- `bun run zig:test`
- `git diff --check`

## Design Decision

Continue the concrete causal producer chain one branch at a time. The report remains verbose because the runtime is currently optimized for agent inspection, provenance preservation, and bounded local evidence before template generation exists.
