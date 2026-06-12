# App-Facing Twelve-Level Report

`causal-app-facing-twelve-level-report` consumes eleven-level evaluator
artifacts, emits local twelve-level report JSON/Markdown, and hands ready or
advisory evidence to
`codex/zigeffect-causal-app-facing-twelve-level-application-boundary`.

The artifact schema remains fully expanded. The physical tool, build step,
executable, docs path, and branch use short aliases because the expanded
twelve-level lineage is not ergonomic for filesystems or branch handling.

## Aliases

- Tool file: `packages/zigeffect/tools/causal_app_facing_twelve_level_report.zig`
- Build step: `causal-app-facing-twelve-level-report`
- Executable: `zigeffect-causal-app-facing-twelve-level-report`
- Docs: `packages/zigeffect/docs/app-facing-twelve-level-report.md`
- Current branch: `codex/zigeffect-causal-app-facing-twelve-level-report`
- Next branch: `codex/zigeffect-causal-app-facing-twelve-level-application-boundary`

## Command

```bash
zig build causal-app-facing-twelve-level-report -- \
  --from-evaluator <eleven-level-evaluator.json> \
  summarize \
  --reason <reason> \
  [--by <actor>] \
  [--policy <policy>] \
  [--out-prefix <path-prefix>]
```

## Consumes

```text
zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator.v1
```

The source evaluator artifact must be local JSON. Ready and advisory evaluator
artifacts are reportable. Blocked evaluator artifacts remain stop signs.

## Emits

```text
zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report.v1
```

The status field is:

```text
consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_status
```

## Usage

```bash
cd packages/zigeffect
zig build causal-app-facing-twelve-level-report -- --from-evaluator ../../.zig-cache/causal-artifacts/app-facing-ci-eleven-level-evaluator.json summarize --reason "reviewed app-facing twelve-level report" --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-twelve-level-report
```

## Ready Gates

Ready output requires a supported eleven-level evaluator schema, a ready or
advisory source status, `ready_for_next_branch=true`, no blocked findings,
ready direct eleven-level policy evidence, ready eleven-level report evidence,
ready eleven-level application-boundary refs, ten-level lineage, nine-level
lineage, inherited lower-level evidence, request/support summaries, denied
claims, next queries, local publication channels, SolidJS
`webui-dev/zig-webui` read-only posture, and disabled authority flags.

Advisory evaluator artifacts produce advisory twelve-level reports when all
hard checks pass. Unsupported source schema, blocked source status, blocked
findings, authority drift, missing required source evidence, or non-local
publication posture produces a blocked report.

## Artifacts

```bash
zig build causal-app-facing-twelve-level-report -- --from-evaluator ../../.zig-cache/causal-artifacts/app-facing-ci-eleven-level-evaluator.json summarize --reason "reviewed app-facing twelve-level report" --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-twelve-level-report
zig build causal-app-facing-twelve-level-report -- --from-evaluator ../../.zig-cache/causal-artifacts/app-facing-ci-eleven-level-evaluator-advisory.json summarize --reason "advisory app-facing twelve-level report source" --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-twelve-level-report-advisory
zig build causal-app-facing-twelve-level-report -- --from-evaluator ../../.zig-cache/causal-artifacts/app-facing-ci-eleven-level-evaluator-blocked.json summarize --reason "blocked app-facing twelve-level report source" --out-prefix ../../.zig-cache/causal-artifacts/app-facing-ci-twelve-level-report-blocked
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
codex/zigeffect-causal-app-facing-twelve-level-application-boundary
```

Blocked report artifacts must be repaired before any application-boundary work.
