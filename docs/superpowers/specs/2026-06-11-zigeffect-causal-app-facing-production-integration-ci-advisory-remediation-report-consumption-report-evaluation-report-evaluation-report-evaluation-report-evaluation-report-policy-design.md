# Zigeffect App-Facing Evaluation Report Evaluation Report Evaluation Report Evaluation Report Policy Design

## Context

The current branch starts after the delivered four-level application-boundary milestone:

```text
causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary
```

That tool consumes a ready or advisory four-level evaluation-report artifact and records planned or reviewed local application evidence. The hardening backlog now recommends the matching policy branch.

## Goal

Add a record-only policy producer for the four-level evaluation-report application-boundary artifact. The policy must let agents, reviewers, non-blocking CI advisory readers, and the SolidJS `webui-dev/zig-webui` workbench interpret applied boundary evidence without granting mutation authority.

The policy must preserve the project direction: SolidJS inside WebUI, NenDB adapter direction only, no Cockroach expansion, no CI enforcement, no required status check, no GitHub mutation, no workflow mutation, no app runtime integration, no raw payload capture, no durable writes, no NenDB writes, no NenDB adapter execution, no public upload, no hosted dashboard, no deployment mutation, no production health claim, and no auto-apply.

## Source And Output

The tool consumes application-boundary artifacts with schema:

```text
zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary.v1
```

It emits:

```text
zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy.v1
```

The tool is registered as:

```text
causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy
```

The next branch after a ready policy is:

```text
codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator
```

## Decision Modes

`approve` records that the application-boundary artifact is suitable as bounded interpretation evidence for the next evaluator. It may emit `consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy_status = "ready"` only when all source checks pass and the caller provides every required verification command.

`reject` records an explicit reviewer stop. It must emit `consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy_status = "blocked"` and `ready_for_next_branch = false`.

## Source Contract

The source boundary must be a reviewed applied record:

- `mode = "record-applied"`
- `evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_status = "applied"`
- `applied = true`
- `ready_for_next_branch = true`
- `mutation_authority = "record-only"`

Current source lineage must include the four-level report:

- `source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report`
- `source_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_status`
- `evaluation_report_evaluation_report_evaluation_report_evaluation_report_after_digest`
- `evaluation_report_evaluation_report_evaluation_report_evaluation_report_after_present`
- `evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_changes`

Inherited triple-layer lineage must include:

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

The policy must also preserve request summary, support evidence summary, signal summary, source checks, application checks, publication channels, denied claims, negative fixtures, required verification commands, verified commands, and next-query guidance.

## Policy Rules

The policy catalog contains interpretation rules for maintainers, read-only agents, non-blocking CI advisory readers, the SolidJS workbench, and the future four-level evaluator input.

Consumption scopes are local and non-mutating:

- local JSON artifact
- local text report
- SolidJS WebUI read-only rendering
- bounded agent context
- non-blocking CI advisory reading
- future evaluator input

Denied inference rules explicitly block required status checks, merge blockers, CI enforcement, branch protection, workflow mutation, GitHub mutation, app mutation, runtime integration, raw payload capture, durable writes, NenDB writes, NenDB adapter execution, Cockroach work, non-NenDB durable storage, deployment success, production health, alternate renderers, auto-apply, and mutation authority.

## Output Contract

JSON output includes schema metadata, branch handoff, source boundary path and schema, current four-level source fields, inherited triple-layer fields, application evidence, before/after evidence, source checks, policy checks, interpretation rules, consumption scopes, denied inference rules, negative fixtures, required verification commands, verified commands, output paths, and agent guidance.

Text output mirrors the same high-signal fields for terminal review.

`mutation_authority` is always `none` in the policy artifact. The source boundary may have `record-only` authority, but the policy itself only interprets evidence; it does not apply, publish, enforce, upload, write, or mutate.

## Integration

Add the Zig tool, build step, tool tests, docs page, schema governance entry, production hardening backlog item, generated governance/backlog docs, and roadmap handoff.

The governance entry should count as a new app-runtime schema and point future consumers to the four-level evaluator milestone. The backlog should mark this policy delivered and recommend the four-level evaluator branch.

## Verification

Focused verification:

- `zig test tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy.zig`
- `zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy -- --help`
- Ready approval artifact generation from the applied four-level application-boundary artifact.
- Rejection artifact generation.
- Blocked source or missing verification generation.

Project verification:

- `zig build causal-schema-governance -- --format json`
- `zig build causal-production-hardening-backlog -- --format json`
- `zig build examples`
- `zig build test`
- `bun run check`
- `bun run zig:test`
- `git diff --check`

## Design Decision

Continue the concrete causal producer chain one branch at a time. The policy artifact is intentionally verbose because each handoff must remain independently inspectable by agents before a later schema-driven generator exists.
