# Zigeffect Causal App-Facing Production Integration CI Advisory Remediation Report Consumption Report Evaluator Design

## Goal

Add a bounded, read-only evaluator for ready app-facing advisory remediation report consumption-report policy artifacts. The evaluator lets local agents, reviewers, non-blocking CI advisory readers, and the SolidJS `webui-dev/zig-webui` workbench decide whether an explicit report-consumption request has enough safe evidence to hand off to the next local summary/report milestone.

## Context

The previous milestone added `causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-policy`. That tool consumes applied consumption-report application-boundary evidence and emits approve/reject policy artifacts. This branch consumes only those policy artifacts plus explicit local request/evidence files under `.zig-cache/causal-artifacts/`.

The evaluator does not execute application code, mutate GitHub, publish public artifacts, make CI checks required, write NenDB state, execute a NenDB adapter, configure a runtime pipeline, or claim production health. It is an evidence classifier and handoff artifact only.

## Tool Contract

Command:

```bash
zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluator -- \
  --from-policy <consumption-report-policy.json> \
  evaluate \
  --reason <reason> \
  --request <path>... \
  [--evidence <path>]... \
  [--by <actor>] \
  [--policy <policy>] \
  [--out-prefix <path-prefix>]
```

Input limits:

- Source policy must be JSON.
- Request and evidence files must be `.json` or `.txt`.
- Request and evidence files must live under `.zig-cache/causal-artifacts/`.
- Each input is bounded to 1 MiB.
- Total request plus evidence inputs are capped at 32 files.

## Source Policy Preconditions

The evaluator accepts the source policy only when all of these are true:

- `schema` is `zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-policy.v1`.
- `schema_version` is `1`.
- `consumption_report_policy_status` is `ready`.
- `ready_for_next_branch` is `true`.
- `decision` is `approve`.
- `mutation_authority` is `none`.
- Source report application refs and digest fields are present.
- Source application/report evidence arrays are present.
- `policy_checks` exists and contains no failures.
- `interpretation_rules`, `consumption_scopes`, `denied_inference_rules`, `source_denied_claims`, `source_denied_application_claims`, `negative_fixtures`, and verification catalogs are present.
- Required source verification commands are present in `verified_commands`.
- All CI, GitHub, app mutation, runtime, deployment, durable storage, NenDB write, NenDB adapter execution, public upload, hosted dashboard, production health, and auto-apply authority fields remain disabled.
- SolidJS inside `webui-dev/zig-webui` remains the only workbench renderer direction.

## Request And Evidence Classification

The evaluator classifies bounded local files as:

- `request_json`
- `request_text`
- `policy_json`
- `causal_json`
- `causal_text`
- `workbench_text`
- `denied`

The evaluator blocks files that contain secret-shaped material, raw prompt/response capture, raw payload capture, authority escalation fields, Cockroach scope, React renderer scope, deployment/production-health claims, public artifact claims, auto-apply claims, or mutation authority grants.

## Output Schema

Schema:

```text
zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluator.v1
```

Status values:

- `ready`: source policy is valid, request files are safe, support evidence is present, and redaction posture is bounded.
- `advisory-findings`: source policy and request files are safe, but support evidence is missing.
- `blocked`: source policy is invalid or any request/evidence file crosses a denied boundary.

The artifact records:

- Source policy path, schema, status, decision, source refs, digest evidence, and source evidence summaries.
- Request and evidence file analysis with SHA-256 digests, detected schema, detected role, redaction posture, and denied reason.
- Checks, signal evaluations, findings, denied claims, policy rule ids, consumption scope ids, next queries, required verification commands, and agent guidance.
- All authority flags, preserving `mutation_authority = none`.

## Handoff

Ready or advisory artifacts hand off to:

```text
codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report
```

Recommendation string:

```text
start-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report
```

## Non-Goals

- No CI enforcement.
- No required status checks.
- No workflow or GitHub API mutation.
- No app mutation, app runtime integration, or live agent projection.
- No raw payload, raw prompt, or raw response capture.
- No deployment or production health claims.
- No public artifact upload.
- No NenDB writes or adapter execution.
- No Cockroach adapter work.
- No alternate frontend renderer.
- No auto-apply.

## Verification

Focused verification:

```bash
cd packages/zigeffect
zig build test
zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluator -- --help
zig build causal-schema-governance -- --format json
zig build causal-production-hardening-backlog -- --format json
zig build examples
```

Repository verification:

```bash
bun run check
bun run zig:test
```
