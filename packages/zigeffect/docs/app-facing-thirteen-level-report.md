# App-Facing Thirteen-Level Report

`causal-app-facing-thirteen-level-report` consumes twelve-level evaluator
artifacts, emits local thirteen-level report JSON/text, and hands ready or
advisory evidence to
`codex/zigeffect-causal-app-facing-thirteen-level-application-boundary`.

The artifact schema remains fully expanded. The physical tool, build step,
executable, docs path, and branch use short aliases because the expanded
thirteen-level lineage is not ergonomic for filesystems or branch handling.

## Aliases

- Tool file: `packages/zigeffect/tools/causal_app_facing_thirteen_level_report.zig`
- Build step: `causal-app-facing-thirteen-level-report`
- Executable: `zigeffect-causal-app-facing-thirteen-level-report`
- Docs: `packages/zigeffect/docs/app-facing-thirteen-level-report.md`
- Current branch: `codex/zigeffect-causal-app-facing-thirteen-level-report`
- Next branch: `codex/zigeffect-causal-app-facing-thirteen-level-application-boundary`

## Command

```bash
zig build causal-app-facing-thirteen-level-report -- \
  --from-evaluator <twelve-level-evaluator.json> \
  summarize \
  --reason <reason> \
  [--by <actor>] \
  [--policy <policy>] \
  [--out-prefix <path-prefix>]
```

## Consumes

```text
zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator.v1
```

The source evaluator artifact must be local JSON. Ready and advisory evaluator
artifacts are reportable. Blocked evaluator artifacts remain stop signs.

## Emits

```text
zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report.v1
```

The status field is:

```text
consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_status
```

## Ready Gates

Ready output requires a supported twelve-level evaluator schema, a ready or
advisory source status, `ready_for_next_branch=true`, no blocked findings,
ready direct twelve-level policy evidence, ready twelve-level
application-boundary and report refs, twelve-level application-change evidence,
eleven-level lineage, ten-level lineage, nine-level lineage, inherited
lower-level evidence, request/support summaries, denied claims, next queries,
local publication channels, SolidJS `webui-dev/zig-webui` read-only posture,
and disabled authority flags.

Advisory evaluator artifacts produce advisory thirteen-level reports when all
hard checks pass. Unsupported source schema, blocked source status, blocked
findings, authority drift, missing required source evidence, or non-local
publication posture produces a blocked report.

## Artifacts

```bash
zig build causal-app-facing-thirteen-level-report -- --from-evaluator ../../.zig-cache/causal-artifacts/app-facing-ci-twelve-level-evaluator.json summarize --reason "reviewed app-facing thirteen-level report" --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-thirteen-level-report
zig build causal-app-facing-thirteen-level-report -- --from-evaluator ../../.zig-cache/causal-artifacts/app-facing-ci-twelve-level-evaluator-advisory.json summarize --reason "advisory app-facing thirteen-level report source" --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-thirteen-level-report-advisory
zig build causal-app-facing-thirteen-level-report -- --from-evaluator ../../.zig-cache/causal-artifacts/app-facing-ci-twelve-level-evaluator-blocked.json summarize --reason "blocked app-facing thirteen-level report source" --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-thirteen-level-report-blocked
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
codex/zigeffect-causal-app-facing-thirteen-level-application-boundary
```

Blocked report artifacts must be repaired before any application-boundary work.
