# App-Facing Evaluation Report Evaluation Report Evaluation Report Evaluation Report Evaluation Report Evaluation Report Application Boundary

`causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary` records planned or reviewed local application evidence for the seven-level evaluation-report artifact.

It consumes:

```text
zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report.v1
```

It emits:

```text
zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary.v1
```

## Usage

Plan a local application record:

```sh
cd packages/zigeffect
zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary -- \
  --from-report ../../.zig-cache/causal-artifacts/app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-703575bb1247cd12.json \
  plan \
  --reason "app-facing advisory remediation report consumption report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report application boundary planned"
```

Record reviewed local application evidence:

```sh
cd packages/zigeffect
zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary -- \
  --from-report ../../.zig-cache/causal-artifacts/app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-703575bb1247cd12.json \
  record-applied \
  --reason "reviewed app-facing advisory remediation report consumption report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report application boundary" \
  --evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-after test/fixtures/app-facing-seven-level-application-boundary-after-safe.txt \
  --evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-change "reviewed local evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report application boundary for agents reviewers CI advisory readers and SolidJS webui" \
  --before "before local evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report application boundary evidence" \
  --after "after local evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report evaluation report application boundary evidence" \
  --verified-command "bun run zigeffect:workbench:typecheck" \
  --verified-command "bun run zigeffect:workbench:test" \
  --verified-command "zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report -- --help" \
  --verified-command "zig build causal-schema-governance -- --format json" \
  --verified-command "zig build causal-production-hardening-backlog -- --format json" \
  --verified-command "zig build examples" \
  --verified-command "zig build test"
```

## Boundary Rules

- `plan` never sets `applied=true` and never marks the next branch ready.
- `record-applied` requires a ready or advisory source report with no blocked findings.
- Reviewed local application changes, before evidence, after evidence, safe after-report content, and every required verification command must be present before `applied=true`.
- The source must preserve read-only SolidJS `webui-dev/zig-webui` posture.
- Publication remains local JSON/text plus read-only workbench viewing.
- App runtime, CI, GitHub, deployment, public upload, production health, NenDB writes, NenDB adapter execution, Cockroach scope, and mutation authority remain disabled.
- The after artifact must be bounded local text/Markdown/JSON and must not claim live runtime integration, status check enforcement, production mutation, or secrets.

## Handoff

When the reviewed application record is applied, it points agents to:

```text
codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy
```
