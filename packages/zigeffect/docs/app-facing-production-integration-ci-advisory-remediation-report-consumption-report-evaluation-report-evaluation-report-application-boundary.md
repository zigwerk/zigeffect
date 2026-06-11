# App-Facing Evaluation Report Evaluation Report Application Boundary

`causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-application-boundary` records reviewed local application evidence for the evaluation-report-evaluation-report artifact.

It consumes:

```text
zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report.v1
```

It emits:

```text
zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-application-boundary.v1
```

## Usage

Plan only:

```bash
zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-application-boundary -- --from-report <evaluation-report-evaluation-report.json> plan --reason "<reason>"
```

Record a reviewed local application:

```bash
zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-application-boundary -- --from-report <evaluation-report-evaluation-report.json> record-applied --reason "<reason>" --evaluation-report-evaluation-report-after <after.txt> --evaluation-report-evaluation-report-application-change "<reviewed change>" --before "<before evidence>" --after "<after evidence>" --verified-command "bun run zigeffect:workbench:typecheck" --verified-command "bun run zigeffect:workbench:test" --verified-command "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report -- --help" --verified-command "zig build causal-schema-governance -- --format json" --verified-command "zig build causal-production-hardening-backlog -- --format json" --verified-command "zig build examples" --verified-command "zig build test"
```

## Boundary

`plan` records intent only. It always emits `applied=false`, `ready_for_next_branch=false`, and `mutation_authority=none`.

`record-applied` emits `applied=true` only when the source report is ready or advisory, has no blocked findings, preserves disabled authority, includes local-only publication evidence, cites reviewed application changes, includes before/after evidence, includes safe after-report content, and cites every required verification command.

The artifact remains record-only. It does not mutate CI, GitHub, app configuration, app data, runtime integration, durable storage, NenDB adapters, deployments, public uploads, hosted dashboards, or production-health state.

## Next Branch

Successful applied evidence prepares:

```text
codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-policy
```
