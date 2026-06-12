# App-Facing Ten-Level Report

`causal-app-facing-ten-level-report` consumes a ready or advisory nine-level
evaluator artifact and emits a compact local ten-level report for agents,
reviewers, non-blocking CI advisory readers, and the SolidJS
`webui-dev/zig-webui` workbench.

The artifact schema remains fully expanded. The physical tool, build step,
executable, docs path, and branch use short aliases because the expanded
ten-level lineage is not ergonomic for filesystems or branch handling.

## Command

```bash
zig build causal-app-facing-ten-level-report -- \
  --from-evaluator <nine-level-evaluator.json> \
  summarize \
  --reason <reason> \
  [--by <actor>] \
  [--policy <policy>] \
  [--out-prefix <path-prefix>]
```

## Consumes

```text
zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator.v1
```

The source evaluator artifact must be local JSON. Ready and advisory evaluator
artifacts are reportable. Blocked evaluator artifacts remain stop signs.

## Emits

```text
zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report.v1
```

The status field is:

```text
consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_status
```

## Ready Gates

Ready output requires a supported nine-level evaluator schema, a ready or
advisory source status, `ready_for_next_branch=true`, no blocked findings,
approved ready nine-level policy evidence, applied nine-level application
evidence, ready nine-level report evidence, inherited eight-level evidence,
request/support summaries, denied claims, next queries, local publication
channels, and disabled authority flags.

Advisory evaluator artifacts produce advisory ten-level reports when all hard
checks pass. Unsupported source schema, blocked source status, blocked
findings, authority drift, missing evidence, or non-local publication posture
produces a blocked report.

## Authority

This tool writes local JSON and text artifacts only.

It does not create required status checks, mutate workflows, call GitHub APIs,
write PR comments, upload public artifacts, mutate app config or app data,
integrate app runtime projections, capture raw payloads, write durable storage,
write NenDB, execute NenDB adapters, add Cockroach scope, deploy, prove
production health, create hosted dashboards, auto-apply, mutate registries, or
grant mutation authority.

## Handoff

Ready or advisory report artifacts may feed:

```text
codex/zigeffect-causal-app-facing-ten-level-application-boundary
```

Blocked report artifacts must be repaired before any application-boundary work.
