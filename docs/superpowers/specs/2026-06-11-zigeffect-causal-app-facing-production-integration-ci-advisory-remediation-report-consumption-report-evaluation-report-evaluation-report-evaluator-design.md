# Zigeffect App-Facing Evaluation Report Evaluation Report Evaluator Design

## Purpose

This milestone adds the evaluator after the app-facing consumption-report evaluation-report evaluation-report policy. It consumes ready policy artifacts plus explicit local request and support-evidence files, then emits bounded evaluator evidence for agents, reviewers, advisory CI readers, and the SolidJS `webui-dev/zig-webui` workbench.

## Scope

The tool is named `causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluator`.

It consumes:

```text
zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-policy.v1
```

It emits:

```text
zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluator.v1
```

The next branch is:

```text
codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report
```

## Behavior

The evaluator reads a source policy, one or more request files, and optional support-evidence files. A source is ready only when the policy schema matches, the policy status is `ready`, the policy decision is `approve`, `ready_for_next_branch=true`, blocked findings are absent, policy checks have no failures, policy catalogs are present, verification commands are recorded, authority flags remain disabled, publication stays local-only, and SolidJS WebUI read-only scope is preserved.

The emitted evaluator status is `ready` when the source policy is ready and the request/evidence files are bounded, redacted, and relevant. It is `advisory-findings` when the source policy is ready but support evidence is missing or weak. It is `blocked` when the source policy is blocked, authority drift is present, required request evidence is missing, or denied content appears.

## Artifact Contract

The evaluator artifact carries source policy evidence, policy checks, interpretation rules, consumption scopes, denied claims, negative fixtures, request and support-evidence summaries, signal summaries, blocked/advisory findings, next queries, and verification guidance. The JSON must be parseable by local agents and the workbench. The text report must explain the status and name the next branch only when the evaluator is ready.

## Safety Constraints

The evaluator is record-only and read-only. It cannot mutate CI, GitHub, workflows, app config, app data, runtime integrations, deployment state, durable stores, NenDB, adapters, public artifacts, or hosted dashboards. It also cannot claim production health, required status checks, branch protection, live agent projection, raw payload capture, auto-apply, alternate renderer support, Cockroach work, or mutation authority.

## Verification

The branch is complete when focused evaluator tests pass, the build target help works, ready/advisory/blocked artifacts are generated from real policy sources, schema governance reports the new schema count, production hardening backlog points to the next evaluation-report branch, generated docs are refreshed, `zig build examples`, `zig build test`, `bun run check`, `bun run zig:test`, and `git diff --check` pass.
