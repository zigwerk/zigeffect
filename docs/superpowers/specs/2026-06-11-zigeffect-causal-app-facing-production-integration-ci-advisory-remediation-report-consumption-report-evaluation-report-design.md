# Zigeffect Causal App-Facing Production Integration CI Advisory Remediation Report Consumption Report Evaluation Report Design

## Goal

Add a local, read-only evaluation-report producer for app-facing advisory remediation report consumption-report evaluator artifacts. The producer turns ready or advisory evaluator evidence into a compact report artifact for agents, reviewers, non-blocking CI advisory readers, and the SolidJS `webui-dev/zig-webui` workbench.

## Context

The previous milestone added `causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluator`. That evaluator consumes ready report-policy artifacts plus explicit local request/support evidence and emits ready, advisory, or blocked evaluator evidence.

This branch consumes those evaluator artifacts. It does not reclassify raw request files and does not widen authority. It summarizes the evaluator result, preserves source policy/application/report refs, carries request/evidence summaries, carries blocked/advisory findings, and keeps publication local-only.

## Tool Contract

Command:

```bash
zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report -- \
  --from-evaluator <consumption-report-evaluator.json> \
  summarize \
  --reason <reason> \
  [--by <actor>] \
  [--policy <policy>] \
  [--out-prefix <path-prefix>]
```

Default output replaces:

```text
-ci-advisory-remediation-report-consumption-report-evaluator.json
```

with:

```text
-ci-advisory-remediation-report-consumption-report-evaluation-report
```

## Source Evaluator Preconditions

The source evaluator is reportable only when:

- `schema` is `zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluator.v1`.
- `schema_version` is `1`.
- `evaluation_status` is `ready` or `advisory-findings`.
- `ready_for_next_branch` is `true`.
- `blocked_findings_count` is `0`.
- No source finding has severity `blocked`.
- Source report-policy status, report application refs, report refs, digest refs, source application evidence, policy rule ids, consumption scope ids, denied claims, next queries, request summaries, signal summaries, and guidance are present.
- All CI, GitHub, app mutation, runtime, deployment, storage, NenDB write, NenDB adapter execution, public upload, hosted dashboard, production health, and auto-apply authority fields remain disabled.
- `mutation_authority` is `none`.
- SolidJS inside `webui-dev/zig-webui` remains the renderer direction.

## Output Schema

Schema:

```text
zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report.v1
```

Status values:

- `ready`: source evaluator is ready, has no blocked findings, has support evidence, and authority remains disabled.
- `advisory`: source evaluator is reportable but has advisory findings.
- `blocked`: source evaluator is blocked, malformed, missing required evidence, or authority drift is present.

The JSON and text artifacts include:

- Source evaluator path, schema, status, and ready flag.
- Source report-policy, report application boundary, consumption report, original consumption policy/boundary/readiness/publication refs, and digest refs.
- Request and support evidence summaries.
- Signal summaries, blocked/advisory findings, checks, policy rule ids, consumption scope ids, denied claims, and next queries.
- Local publication channels that explicitly deny public upload, GitHub summaries/comments, required status checks, and app runtime integration.
- Required verification commands and agent guidance.

## Handoff

Ready or advisory artifacts hand off to:

```text
codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-application-boundary
```

Recommendation string:

```text
start-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-application-boundary
```

## Non-Goals

- No CI enforcement.
- No required status checks.
- No workflow or GitHub API mutation.
- No GitHub step summary or pull request comment writing.
- No app mutation, app runtime integration, or live agent projection.
- No raw prompt, raw response, or raw payload capture.
- No deployment or production health claims.
- No public artifact upload or hosted live dashboard.
- No NenDB writes or adapter execution.
- No Cockroach adapter work.
- No alternate frontend renderer.
- No auto-apply.
- No mutation authority.

## Verification

Focused verification:

```bash
cd packages/zigeffect
zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report -- --help
zig build causal-schema-governance -- --format json
zig build causal-production-hardening-backlog -- --format json
zig build examples
zig build test
```

Repository verification:

```bash
bun run check
bun run zig:test
git diff --check
```
