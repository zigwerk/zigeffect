# App-Facing CI Advisory Remediation Report Consumption Report Evaluation Report Evaluation Report Policy

`causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-policy`
reviews an applied consumption-report evaluation-report-evaluation-report application-boundary
artifact and emits a record-only approve/reject policy artifact.

Schema:

```text
zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-policy.v1
```

## Purpose

This policy is the review layer after
`causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-application-boundary`.
It lets agents, reviewers, non-blocking CI advisory readers, and the local
SolidJS workbench treat an already-applied local evaluation-report-evaluation-report boundary as
bounded evidence for the next evaluator branch.

It does not apply app changes, mutate GitHub, publish public artifacts, run
adapters, write storage, start runtime projections, configure CI enforcement, or
claim production health.

## CLI

Approve a reviewed source:

```bash
zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-policy -- \
  --from-application ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-application-boundary.json \
  approve \
  --reason "reviewed app-facing advisory remediation report consumption report evaluation report evaluation report policy" \
  --verified-command "bun run zigeffect:workbench:typecheck" \
  --verified-command "bun run zigeffect:workbench:test" \
  --verified-command "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-application-boundary -- --help" \
  --verified-command "zig build causal-schema-governance -- --format json" \
  --verified-command "zig build causal-production-hardening-backlog -- --format json" \
  --verified-command "zig build examples" \
  --verified-command "zig build test"
```

Reject a reviewed source:

```bash
zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-policy -- \
  --from-application ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-application-boundary.json \
  reject \
  --reason "negative app-facing advisory remediation report consumption report evaluation report evaluation report policy path" \
  --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-policy-negative
```

## Ready Gates

Approval is ready only when:

- source schema is `consumption-report-evaluation-report-evaluation-report-application-boundary.v1`
- source mode is `record-applied`
- source evaluation-report-evaluation-report application status is `applied`
- source has `applied = true`, `ready_for_next_branch = true`, and `mutation_authority = "record-only"`
- source evaluation-report-evaluation-report, evaluator, report policy, report application, consumption report, readiness, publication policy, and digest refs are present
- evaluation-report-evaluation-report application changes, before evidence, after evidence, after-report digest, summaries, denied claims, next queries, publication channels, and negative fixtures are present
- application checks pass and source checks have no failures
- CI, GitHub, app, runtime, storage, deployment, public upload, auto-apply, and adapter authority are disabled
- workbench scope remains SolidJS inside `webui-dev/zig-webui`
- publication channels remain local-only
- source and policy verification commands are recorded

## Denied Claims

The artifact denies inference of:

- required status checks or merge blocking
- CI enforcement or workflow mutation
- GitHub API mutation, step summaries, PR comments, or artifact uploads
- app config writes, data writes, runtime integration, or mutation controls
- live agent projection or raw payload capture
- durable writes, NenDB writes, NenDB adapter execution, Cockroach work, or non-NenDB durable storage
- deployment success, production health, cluster readiness, public artifact upload, hosted dashboards, auto-apply, alternate renderers, or mutation authority

## Next Branch

Ready output recommends:

```text
codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluator
```

The next branch should consume this policy artifact plus explicit local request
and evidence files, then classify evaluation-report-evaluation-report consumption evidence as
ready, advisory, or blocked for agents and the SolidJS workbench.

## Verification

```bash
zig test tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_policy.zig
zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-policy -- --help
zig build causal-schema-governance -- --format json
zig build causal-production-hardening-backlog -- --format json
zig build test
zig build examples
```
