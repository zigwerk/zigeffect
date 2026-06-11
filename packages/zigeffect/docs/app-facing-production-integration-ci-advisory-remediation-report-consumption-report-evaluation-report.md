# App-Facing CI Advisory Remediation Report Consumption Report Evaluation Report

`causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report` consumes a consumption-report evaluator artifact and emits a compact local evaluation report for agents, reviewers, non-blocking CI advisory readers, and the SolidJS `webui-dev/zig-webui` workbench.

## Command

```bash
zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report -- \
  --from-evaluator <consumption-report-evaluator.json> \
  summarize \
  --reason <reason> \
  [--by <actor>] \
  [--policy <policy>] \
  [--out-prefix <path-prefix>]
```

## Source Gate

The source evaluator must use schema `zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluator.v1`, preserve `mutation_authority = none`, and keep CI enforcement, required status checks, workflow mutation, GitHub API mutation, app mutation, app runtime integration, live projection, raw payload capture, deployment mutation, durable writes, NenDB writes, NenDB adapter execution, public artifact upload, hosted live dashboards, production health claims, and auto-apply disabled.

The report preserves source report-policy refs, source report application refs, source consumption-report status, source before/after evidence, source next queries, source boundary rules, local publication channels, denied claims, request/evidence summaries, findings, and verification commands.

## Statuses

- `ready`: the source evaluator is ready, source application evidence is present, support evidence is present, and authority remains disabled.
- `advisory-findings`: the source evaluator is safe but contains advisory findings or missing support evidence.
- `blocked`: the source evaluator is blocked, missing required source refs, or crosses any denied authority boundary.

## Handoff

Ready or advisory evaluation-report artifacts hand off to:

```text
codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-application-boundary
```

The evaluation report is local, read-only, and advisory. It does not publish artifacts, mutate app state, enforce CI, execute adapters, host dashboards, apply changes, or claim production health.
