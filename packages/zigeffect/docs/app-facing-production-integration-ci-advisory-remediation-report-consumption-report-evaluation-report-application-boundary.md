# App-Facing CI Advisory Remediation Report Consumption Report Evaluation Report Application Boundary

`causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-application-boundary` consumes a local consumption-report evaluation-report artifact and emits guarded application-boundary evidence.

## Command

```bash
zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-application-boundary -- \
  --from-report <consumption-report-evaluation-report.json> \
  plan|record-applied \
  --reason <reason> \
  [--evaluation-report-after <report.txt|report.md|report.json>] \
  [--evaluation-report-application-change <evidence>]... \
  [--before <evidence>]... \
  [--after <evidence>]... \
  [--verified-command <command>]... \
  [--by <actor>] \
  [--policy <policy>] \
  [--out-prefix <path-prefix>]
```

## Source Gate

The source artifact must use schema `zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report.v1`, be ready or advisory, be ready for the next branch, contain no blocked findings, and preserve `mutation_authority = none`.

It must also carry source evaluator refs, report-policy refs, report-application refs, consumption-report refs, request/evidence summaries, checks, findings, denied claims, next queries, local publication channels, inherited report-application evidence, and required verification commands.

## Application Gate

`plan` mode records local intent only. It always emits `applied=false` and `ready_for_next_branch=false`.

`record-applied` only emits `applied=true` when all of these are present:

- reviewed evaluation-report application change evidence;
- before evidence;
- after evidence;
- safe evaluation-report-after content;
- every required verification command.

The after-report content is blocked if it claims CI enforcement, required status checks, workflow mutation, GitHub mutation, app mutation, app runtime integration, raw payload capture, public upload, hosted dashboards, deployment success, production health, durable writes, NenDB writes, NenDB adapter execution, Cockroach work, React or alternate renderer scope, auto-apply, secrets, or mutation authority.

## Handoff

Applied artifacts hand off to:

```text
codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-policy
```

The application boundary is still record-only. It does not publish artifacts, mutate app state, enforce CI, execute adapters, host dashboards, apply changes automatically, or claim production health.
