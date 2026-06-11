# Zigeffect App-Facing Evaluation Report Evaluation Report Evaluation Report Policy Design

## Context

The previous milestone delivered `causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-application-boundary`. Its applied artifact records reviewed local application evidence for the triple evaluation-report layer and points to this policy branch.

This branch consumes that applied application-boundary evidence and emits deterministic, record-only policy evidence. It follows the existing evaluation-report evaluation-report policy producer, retargeted one generation deeper.

## Goal

Add a policy producer for the evaluation-report evaluation-report evaluation-report application-boundary artifact. The policy should approve only when the source boundary is applied, ready, locally published only, fully verified, and still denied any mutation authority. It should reject or block otherwise while preserving enough lineage for the next evaluator branch.

## Approach

The new tool consumes:

```text
zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-application-boundary.v1
```

It emits:

```text
zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-policy.v1
```

It supports `approve` and `reject` decisions. `approve` emits ready policy evidence only if every source and verification gate passes. `reject` preserves an explicit reviewer rejection as blocked policy evidence.

## Source Contract

The source application-boundary artifact must provide the current triple application fields:

- `evaluation_report_evaluation_report_evaluation_report_application_status`;
- `evaluation_report_evaluation_report_evaluation_report_after_digest`;
- `evaluation_report_evaluation_report_evaluation_report_after_present`;
- `evaluation_report_evaluation_report_evaluation_report_application_changes`;
- `applied`, `ready_for_next_branch`, and `mutation_authority`.

It must also carry inherited double-layer lineage without over-expanding those names:

- `source_consumption_report_evaluation_report_evaluation_report`;
- `source_consumption_report_evaluation_report_evaluation_report_status`;
- `source_consumption_report_evaluation_report_evaluation_report_policy`;
- `source_consumption_report_evaluation_report_evaluation_report_policy_schema`;
- `source_evaluation_report_evaluation_report_policy_status`;
- `source_consumption_report_evaluation_report_evaluation_report_application_boundary`;
- `source_consumption_report_evaluation_report_evaluation_report_application_boundary_schema`;
- `source_evaluation_report_evaluation_report_application_status`;
- `source_evaluation_report_evaluation_report_after_digest`;
- `source_evaluation_report_evaluation_report_after_present`;
- `source_evaluation_report_evaluation_report_application_changes`.

The new policy output introduces the current source boundary reference:

```text
source_consumption_report_evaluation_report_evaluation_report_evaluation_report_application_boundary
```

That reference is the consumed application-boundary path, not a field expected inside the source JSON.

## Policy Rules

Approved policy evidence requires:

- source schema/version matches the triple application-boundary schema;
- source `evaluation_report_evaluation_report_evaluation_report_application_status=applied`;
- `applied=true`, `ready_for_next_branch=true`, and `mutation_authority=record-only`;
- CI, GitHub, app, runtime, storage, deployment, public upload, NenDB write, NenDB adapter execution, hosted dashboard, production health, auto-apply, and mutation flags remain disabled;
- SolidJS `webui-dev/zig-webui` read-only posture remains intact;
- source application and inherited application evidence are present;
- source application checks contain no failures;
- local-only publication evidence remains present;
- all required verification commands are cited.

## Output Contract

The policy JSON includes:

- source application-boundary reference and schema;
- source triple application status and after-report digest evidence;
- inherited double-layer policy and application references;
- `decision`, `source_policy_decision`, and `consumption_report_evaluation_report_evaluation_report_evaluation_report_policy_status`;
- interpretation rules, consumption scopes, denied inference rules, negative fixtures, verification commands, and next queries;
- `ready_for_next_branch=true` only for approved, fully verified evidence.

The text report mirrors the same high-signal fields for terminal review.

## Safety Rules

This policy remains record-only. It does not create required status checks, workflow mutations, GitHub API mutations, app mutations, app runtime integrations, live projections, raw payload capture, durable writes, NenDB writes, NenDB adapter execution, public uploads, hosted dashboards, deployment authority, production-health claims, Cockroach scope, alternate renderer scope, auto-apply, or mutation authority.

## Integration

The build target is:

```text
causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-policy
```

Schema governance increments to 112 schemas. The production hardening backlog marks this branch delivered and recommends:

```text
codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluator
```

The master roadmap marks item 76 delivered and adds the evaluator branch as the next item.

## Verification

Focused verification:

- `zig test tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_policy.zig`
- `zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-policy -- --help`
- approve, reject, and blocked-source artifact runs.

Project verification:

- `zig build causal-schema-governance -- --format json`
- `zig build causal-production-hardening-backlog -- --format json`
- `zig build examples`
- `zig build test`
- `bun run check`
- `bun run zig:test`
- `git diff --check`
