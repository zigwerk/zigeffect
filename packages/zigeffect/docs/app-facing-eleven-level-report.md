# App-Facing Eleven-Level Report

`causal-app-facing-eleven-level-report` consumes ten-level evaluator artifacts,
emits local eleven-level report JSON/Markdown, and hands ready or advisory
evidence to
`codex/zigeffect-causal-app-facing-eleven-level-application-boundary`.

The artifact schema remains fully expanded. The physical tool, build step,
executable, docs path, and branch use short aliases because the expanded
eleven-level lineage is not ergonomic for filesystems or branch handling.

## Command

```bash
zig build causal-app-facing-eleven-level-report -- \
  --from-evaluator <ten-level-evaluator.json> \
  summarize \
  --reason <reason> \
  [--by <actor>] \
  [--policy <policy>] \
  [--out-prefix <path-prefix>]
```

## Consumes

```text
zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator.v1
```

The source evaluator artifact must be local JSON. Ready and advisory evaluator
artifacts are reportable. Blocked evaluator artifacts remain stop signs.

## Emits

```text
zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report.v1
```

The status field is:

```text
consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_status
```

## Ready Gates

Ready output requires a supported ten-level evaluator schema, a ready or
advisory source status, `ready_for_next_branch=true`, no blocked findings,
ready ten-level policy evidence, ready ten-level report evidence, ready
ten-level application-boundary refs, inherited nine-level lineage, inherited
request/support summaries, denied claims, next queries, local publication
channels, SolidJS `webui-dev/zig-webui` read-only posture, and disabled
authority flags.

Advisory evaluator artifacts produce advisory eleven-level reports when all
hard checks pass. Unsupported source schema, blocked source status, blocked
findings, authority drift, missing required source evidence, or non-local
publication posture produces a blocked report.

## Artifacts

```bash
zig build causal-app-facing-eleven-level-report -- --from-evaluator ../../.zig-cache/causal-artifacts/app-facing-ci-ten-level-evaluator.json summarize --reason "reviewed app-facing eleven-level report" --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-eleven-level-report
zig build causal-app-facing-eleven-level-report -- --from-evaluator ../../.zig-cache/causal-artifacts/app-facing-ci-ten-level-evaluator-advisory.json summarize --reason "advisory app-facing eleven-level report source" --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-eleven-level-report-advisory
zig build causal-app-facing-eleven-level-report -- --from-evaluator ../../.zig-cache/causal-artifacts/app-facing-ci-ten-level-evaluator-blocked.json summarize --reason "blocked app-facing eleven-level report source" --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-eleven-level-report-blocked
```

Expected local outputs include `.json` and `.txt` files under
`.zig-cache/causal-artifacts/`. They are local evidence for agents, reviewers,
non-blocking CI advisory readers, and the SolidJS workbench only.

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
codex/zigeffect-causal-app-facing-eleven-level-application-boundary
```

Blocked report artifacts must be repaired before any application-boundary work.
