# ZigEffect App-Facing Consumption Report Evaluation Report Evaluator Design

## Goal

Build the next read-only evaluator in the app-facing causal feedback chain:
`causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluator`.

The evaluator consumes a ready `consumption-report-evaluation-report-policy` artifact plus explicit local request/evidence files, classifies the request as `ready`, `advisory-findings`, or `blocked`, and emits local JSON/text artifacts that agents, reviewers, non-blocking CI advisory readers, and the SolidJS `webui-dev/zig-webui` workbench can consume.

## Non-Goals

- No CI enforcement, required status checks, branch protection, workflow mutation, GitHub API mutation, or PR comments.
- No app mutation, app runtime integration, app config writes, app data writes, live projection, or raw prompt/response/payload capture.
- No public artifact upload, hosted live dashboard, deployment mutation, production telemetry ingestion, production health claim, or auto-apply.
- No storage writes, no NenDB adapter execution, and no Cockroach scope.
- No renderer drift: the workbench direction remains SolidJS inside `webui-dev/zig-webui`.

## Source Contract

The source policy must use:

```text
zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-policy.v1
```

It must be approved, have `consumption_report_evaluation_report_policy_status = ready`, set `ready_for_next_branch = true`, and preserve `mutation_authority = none`.

The evaluator also requires the policy artifact to carry:

- evaluation-report application-boundary refs and applied status;
- inherited consumption-report and evaluation-report refs;
- evaluation-report application changes, before/after evidence, after digest, and after presence;
- source report application evidence, next queries, boundary rules, and publication channels;
- request/support/signal summaries plus advisory and blocked findings;
- interpretation rules, consumption scopes, denied claims, negative fixtures, and verification command evidence;
- all authority flags disabled and SolidJS/webui read-only flags enabled.

## Command Shape

```bash
zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluator -- \
  --from-policy <consumption-report-evaluation-report-policy.json> \
  evaluate \
  --reason <reason> \
  --request <path>... \
  [--evidence <path>]... \
  [--by <actor>] \
  [--policy <policy>] \
  [--out-prefix <path-prefix>]
```

Input files must be `.json` or `.txt` under `.zig-cache/causal-artifacts/`.

## Output Contract

The new artifact schema is:

```text
zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluator.v1
```

Ready or advisory outputs hand off to:

```text
codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report
```

The output must preserve the source policy evidence, request/evidence classification, checks, signal evaluations, findings, denied claims, next-query guidance, and local artifact paths.

## Status Semantics

- `ready`: source policy is valid, request files are safe, support evidence is present, and redaction posture is bounded.
- `advisory-findings`: source policy and request files are safe, but support evidence is missing.
- `blocked`: source policy or any request/evidence file crosses a denied boundary.

## Verification

Focused verification:

```bash
cd packages/zigeffect
zig test tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluator.zig
zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluator -- --help
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
