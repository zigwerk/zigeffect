# Zigeffect App-Facing Evaluation Report Evaluation Report Policy Design

## Purpose

This milestone adds the record-only policy layer after the app-facing consumption-report evaluation-report evaluation-report application boundary. It consumes only reviewed local application-boundary artifacts and emits a bounded policy artifact that agents, reviewers, advisory CI readers, and the SolidJS `webui-dev/zig-webui` workbench can interpret without gaining mutation authority.

## Scope

The tool is named `causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-policy`.

It consumes:

```text
zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-application-boundary.v1
```

It emits:

```text
zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-policy.v1
```

The next branch is:

```text
codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluator
```

## Behavior

The policy command accepts `approve` and `reject`. Approval is allowed only when the source application-boundary artifact is `applied=true`, `ready_for_next_branch=true`, uses the expected schema, has no blocked findings, keeps authority record-only or none, preserves local-only publication, carries reviewed application change evidence, includes before/after evidence, includes a safe after-report, and records the required verification commands.

Rejected or invalid sources emit a blocked policy artifact. A blocked artifact must keep `ready_for_next_branch=false`, must include concrete failed gates, and must not imply CI enforcement, branch protection, GitHub mutations, app mutations, runtime integration, deployment health, durable writes, NenDB writes, NenDB adapter execution, Cockroach work, public artifact upload, hosted dashboards, auto-apply, or mutation authority.

## Artifact Contract

The artifact carries policy checks, interpretation rules, consumption scopes, denied claims, negative fixtures, source application evidence, inherited report/evaluation evidence, and next queries. The generated JSON remains parseable by local agents and the workbench. The text report names the recommendation, next branch, status, failed checks, denied claims, and verification posture.

## Safety Constraints

All authority flags remain disabled. This policy is advisory and record-only. It can help future evaluators interpret local evidence, but it cannot execute an adapter, write to NenDB, mutate app configuration, publish public artifacts, alter CI, call GitHub APIs, deploy, or mark production healthy.

## Verification

The branch is complete when focused policy tests pass, the build target help works, schema governance reports the new schema count, production hardening backlog points to the evaluator branch, generated docs are refreshed, app-facing policy artifacts are generated for approve/reject/blocked paths, `zig build examples`, `zig build test`, `bun run check`, `bun run zig:test`, and `git diff --check` pass.
