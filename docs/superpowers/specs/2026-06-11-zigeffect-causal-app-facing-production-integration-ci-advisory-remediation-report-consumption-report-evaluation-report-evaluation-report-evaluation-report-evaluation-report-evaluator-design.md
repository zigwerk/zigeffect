# Zigeffect App-Facing Evaluation Report Evaluation Report Evaluation Report Evaluation Report Evaluator Design

## Context

The current branch starts after the delivered four-level policy milestone:

```text
causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy
```

That tool consumes an applied four-level application-boundary artifact and emits ready or blocked record-only policy evidence. The hardening backlog now recommends the matching evaluator branch.

## Goal

Add a read-only evaluator for the four-level policy artifact. The evaluator must classify bounded local request and support evidence, preserve the source policy lineage, and emit an artifact that agents, reviewers, non-blocking CI advisory readers, and the SolidJS `webui-dev/zig-webui` workbench can inspect before the next evaluation-report producer.

The evaluator must preserve the project direction: SolidJS inside WebUI, NenDB adapter direction only, no Cockroach expansion, no CI enforcement, no required status check, no GitHub mutation, no workflow mutation, no app mutation, no app runtime integration, no raw payload capture, no durable writes, no NenDB writes, no NenDB adapter execution, no public upload, no hosted dashboard, no deployment mutation, no production health claim, and no auto-apply.

## Source And Output

The tool consumes policy artifacts with schema:

```text
zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy.v1
```

It emits:

```text
zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator.v1
```

The tool is registered as:

```text
causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator
```

The next branch after a ready or advisory evaluator artifact is:

```text
codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report
```

## Evaluation Status

`ready` means the source policy is approved, ready, local-only, fully verified, and the supplied request/support files are bounded and safe.

`advisory-findings` means the source policy is ready and safe, but support evidence is missing or advisory signals should be preserved for reviewers.

`blocked` means the source policy is blocked, has authority drift, lacks required verification, has invalid schema, lacks request evidence, or includes denied request/evidence content.

## Source Contract

The source policy must provide:

- `decision = "approve"`
- `consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy_status = "ready"`
- `ready_for_next_branch = true`
- `mutation_authority = "none"`
- `source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_boundary`
- `source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report`
- `source_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_status`
- `source_evaluation_report_evaluation_report_evaluation_report_evaluation_report_after_digest`
- `source_evaluation_report_evaluation_report_evaluation_report_evaluation_report_after_present`
- `source_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_changes`

Inherited triple-layer lineage must also remain available:

- `source_consumption_report_evaluation_report_evaluation_report_evaluation_report_policy`
- `source_consumption_report_evaluation_report_evaluation_report_evaluation_report_policy_schema`
- `source_evaluation_report_evaluation_report_evaluation_report_policy_status`
- `source_consumption_report_evaluation_report_evaluation_report_evaluation_report_application_boundary`
- `source_consumption_report_evaluation_report_evaluation_report_evaluation_report_application_boundary_schema`
- `source_consumption_report_evaluation_report_evaluation_report_evaluation_report`
- `source_consumption_report_evaluation_report_evaluation_report_evaluation_report_status`
- `source_evaluation_report_evaluation_report_evaluation_report_application_status`
- `source_evaluation_report_evaluation_report_evaluation_report_application_changes`

The evaluator also preserves policy checks, interpretation rules, consumption scopes, denied inference rules, source request/support/signal summaries, source findings, source publication channels, negative fixtures, required verification commands, verified commands, and next-query guidance.

## File Classification

Request files are required and must be local bounded artifacts. JSON request files may contain causal schema, policy, evaluator, or workbench request context. Text request files must avoid denied claims and secret-looking content.

Support evidence is optional. Missing support evidence yields advisory findings rather than readiness failure when the source policy and request files are otherwise safe.

Denied request or evidence content blocks the evaluator. Denied content includes required-status-check claims, CI enforcement, GitHub mutation, workflow mutation, app mutation, runtime integration, raw payload capture, durable writes, NenDB writes, NenDB adapter execution, Cockroach work, public upload, deployment success, production health, hosted dashboard, alternate renderer direction, auto-apply, mutation authority, and secrets.

## Output Contract

JSON output includes schema metadata, branch handoff, source policy path/schema/status, current four-level source fields, inherited triple-layer source fields, source checks, file summaries, signals, blocked/advisory findings, denied claims, policy rules, consumption scopes, required verification commands, output paths, and agent guidance.

Text output mirrors the same high-signal fields for terminal review.

`mutation_authority` is always `none`. The evaluator does not apply, publish, enforce, upload, write, deploy, integrate runtime state, or mutate any application or external service.

## Integration

Add the Zig tool, build step, tool tests, docs page, schema governance entry, production hardening backlog item, generated governance/backlog docs, and roadmap handoff.

The governance entry should count as a new app-runtime schema and point future consumers to the five-level evaluation-report producer. The backlog should mark this evaluator delivered and recommend the five-level evaluation-report branch.

## Verification

Focused verification:

- `zig test tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluator.zig`
- `zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator -- --help`
- Ready evaluator artifact generation from the ready four-level policy artifact.
- Advisory evaluator artifact generation without support evidence.
- Blocked evaluator artifact generation from blocked policy evidence.

Project verification:

- `zig build causal-schema-governance -- --format json`
- `zig build causal-production-hardening-backlog -- --format json`
- `zig build examples`
- `zig build test`
- `bun run check`
- `bun run zig:test`
- `git diff --check`

## Design Decision

Continue the concrete causal producer chain one branch at a time. The evaluator remains verbose because the runtime is intentionally optimized for agent inspection, provenance preservation, and bounded local evidence before template generation exists.
