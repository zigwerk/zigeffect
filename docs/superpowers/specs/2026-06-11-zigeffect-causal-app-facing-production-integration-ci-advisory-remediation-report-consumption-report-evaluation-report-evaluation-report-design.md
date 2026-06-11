# ZigEffect App-Facing Consumption Report Evaluation Report Evaluation Report Design

## Goal

Build the next local report producer in the app-facing causal feedback chain:
`causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report`.

The producer consumes a ready or advisory `consumption-report-evaluation-report-evaluator` artifact and emits local JSON/text reports that let agents, reviewers, non-blocking CI advisory readers, and the SolidJS `webui-dev/zig-webui` workbench inspect whether the evaluation-report policy consumption path is sufficiently evidenced for the next guarded application-boundary step.

## Non-Goals

- No CI enforcement, required status checks, branch protection, workflow mutation, GitHub API mutation, PR comments, or artifact upload.
- No app mutation, app runtime integration, app config writes, app data writes, live projection, raw prompt/response/payload capture, or auto-apply.
- No public artifact upload, hosted live dashboard, deployment mutation, production telemetry ingestion, production health claim, or production mutation.
- No storage writes, no NenDB adapter execution, and no Cockroach scope.
- No renderer drift: app-facing UI context remains SolidJS inside `webui-dev/zig-webui`.

## Source Contract

The source evaluator must use:

```text
zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluator.v1
```

It must have `evaluation_status` equal to `ready` or `advisory-findings`, `ready_for_next_branch = true`, no blocked findings, `mutation_authority = none`, all authority flags disabled, and SolidJS/webui read-only flags enabled.

The report also requires the evaluator artifact to carry:

- source evaluation-report policy refs, ready policy status, and approve decision;
- applied evaluation-report application-boundary refs, evaluation-report status, after digest, after presence, and application changes;
- inherited consumption-report application refs and source consumption-report status;
- inherited source report application changes, before/after evidence, next queries, boundary rules, and local publication channel ids;
- source application/report checks, source request/support/signal summaries, blocked/advisory findings, denied claims, denied application claims, and next-query guidance;
- current evaluator request/evidence classifications, checks, signal evaluations, findings, policy rule ids, consumption scope ids, denied claims, next queries, and agent guidance.

## Command Shape

```bash
zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report -- \
  --from-evaluator <consumption-report-evaluation-report-evaluator.json> \
  summarize \
  --reason <reason> \
  [--by <actor>] \
  [--policy <policy>] \
  [--out-prefix <path-prefix>]
```

## Output Contract

The new artifact schema is:

```text
zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report.v1
```

Ready or advisory outputs hand off to:

```text
codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-application-boundary
```

The output must preserve source evaluator evidence, inherited application evidence, request/evidence summaries, checks, signal evaluations, findings, denied claims, next-query guidance, local publication posture, required verification commands, and local output paths.

## Status Semantics

- `ready`: source evaluator is ready, required source refs/evidence are present, support evidence is present, no blocked findings exist, and authority remains disabled.
- `advisory`: source evaluator is safe and reportable but contains advisory findings or missing support evidence.
- `blocked`: source evaluator is blocked, missing required source refs/evidence, has blocked findings, or crosses any denied authority boundary.

## Verification

Focused verification:

```bash
cd packages/zigeffect
zig test tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report.zig
zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report -- --help
```

Branch verification:

```bash
cd packages/zigeffect
zig build causal-schema-governance -- --format json
zig build causal-production-hardening-backlog -- --format json
zig build examples
zig build test
cd ../..
bun run check
bun run zig:test
git diff --check
```
