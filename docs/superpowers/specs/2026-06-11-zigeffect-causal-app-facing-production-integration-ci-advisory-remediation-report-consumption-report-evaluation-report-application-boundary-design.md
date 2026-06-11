# Zigeffect Causal App-Facing Advisory Report Consumption Report Evaluation Report Application Boundary Design

## Context

The previous branch delivered `causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report`, a local read-only report over consumption-report evaluator artifacts. The next roadmap step needs a guarded application boundary that can either record intent (`plan`) or record a reviewed local application (`record-applied`) without granting mutation authority.

This follows the existing application-boundary pattern used by `causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-application-boundary`.

## Goals

- Add schema `zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-application-boundary.v1`.
- Add tool `causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-application-boundary`.
- Consume source schema `zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report.v1`.
- Support `plan` and `record-applied` modes.
- Keep `plan` mode non-applied with `applied=false` and `ready_for_next_branch=false`.
- Only allow `record-applied` to set `applied=true` after reviewed application-change evidence, before evidence, after evidence, safe after-report content, and all required verification commands are present.
- Preserve app-facing constraints: SolidJS inside `webui-dev/zig-webui`, local artifacts only, NenDB adapter only, no Cockroach scope, no public upload, no hosted live dashboard, no CI enforcement, no workflow/GitHub/app/runtime/storage/deployment mutation, no auto-apply, and no mutation authority.

## Non-Goals

- No GitHub API calls, PR comments, step summaries, artifact uploads, or required status checks.
- No app runtime integration, app config writes, app data writes, or app mutation controls.
- No durable writes, NenDB writes, NenDB adapter execution, or Cockroach work.
- No hosted dashboard, live telemetry, deployment mutation, or production-health claim.
- No new workbench renderer or React path.

## Command Shape

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

The source evaluation report must:

- use the expected schema and schema version;
- be `ready` or `advisory`, `ready_for_next_branch=true`, and have no blocked findings;
- preserve `mutation_authority="none"`;
- carry source report-policy, report-application, consumption-report, evaluator, request/evidence summary, checks, findings, denied claims, next queries, publication channels, and required verification commands;
- keep all authority booleans disabled;
- keep local JSON/text publication only, with SolidJS webui read-only viewing allowed but not executed by the tool.

Blocked source reports, authority drift, missing summaries, missing verification contracts, failed source checks, and unsafe publication channels produce `status=blocked`.

## Application Gate

`record-applied` additionally requires:

- at least one `--evaluation-report-application-change`;
- at least one `--before`;
- at least one `--after`;
- `--evaluation-report-after` content that includes safe markers for zigeffect causal read-only consumption report evaluation-report application;
- no prohibited after-report markers such as CI enforcement, public upload, hosted dashboards, app runtime integration, raw payload capture, deployment mutation, production health, Cockroach, React renderer, auto-apply, or mutation authority;
- every required verification command.

Only when every source and application check passes does the tool emit:

```json
{
  "evaluation_report_application_status": "applied",
  "applied": true,
  "ready_for_next_branch": true,
  "mutation_authority": "record-only"
}
```

## Outputs

The JSON/text artifacts include source refs, source status, application mode, application status, applied flag, after-report digest, before/after evidence, checks, source checks/findings, denied claims, boundary rules, negative fixtures, required verification commands, verified commands, and next branch guidance.

The next branch after a valid applied record is:

```text
codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-policy
```

## Verification

The milestone is complete only when these pass:

- `zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-application-boundary -- --help`
- ready plan generation from the ready evaluation report
- ready record-applied generation with before/after/after-report/verification evidence
- blocked generation from the blocked evaluation report
- `zig build causal-schema-governance -- --format json`
- `zig build causal-production-hardening-backlog -- --format json`
- `zig build examples`
- `zig build test`
- `bun run check`
- `bun run zig:test`
- `git diff --check`
