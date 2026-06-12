# Zigeffect App-Facing Nine-Level Report Design

## Context

The eight-level evaluator now emits ready, advisory, and blocked local evaluator
artifacts from approved eight-level policy evidence plus bounded request and
support evidence. Ready and advisory evaluator artifacts are still evidence
only. They do not grant CI, GitHub, app runtime, storage, deployment, public
upload, production-health, auto-apply, registry, or mutation authority.

This milestone adds the matching nine-level report producer. It consumes a
ready or advisory eight-level evaluator artifact, summarizes the ninth
`evaluation-report` layer for agents, reviewers, non-blocking CI advisory
readers, and the local SolidJS `webui-dev/zig-webui` workbench, then hands off
to the nine-level application-boundary branch.

## Design

Promote the existing eight-level report pattern into a short physical alias
while preserving the fully expanded artifact schema lineage. The old report
tool uses the full expanded filename because it predates the alias boundary.
This branch uses aliases for the physical file, build step, executable, docs
path, branch, and next branch because the expanded nine-level name is not
ergonomic for branch or filesystem work.

- Tool: `packages/zigeffect/tools/causal_app_facing_nine_level_report.zig`
- Build step: `causal-app-facing-nine-level-report`
- Executable: `zigeffect-causal-app-facing-nine-level-report`
- Docs: `packages/zigeffect/docs/app-facing-nine-level-report.md`
- Current branch: `codex/zigeffect-causal-app-facing-nine-level-report`
- Next branch if ready: `codex/zigeffect-causal-app-facing-nine-level-application-boundary`
- Recommendation: `start-app-facing-nine-level-application-boundary`

The source evaluator uses the eight-level alias tool. The report emits the
fully expanded nine-level schema because evaluator-to-report handoff adds one
more `evaluation-report` layer to the artifact lineage.

## Schemas

The source evaluator schema is:

```text
zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator.v1
```

The emitted report schema is:

```text
zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report.v1
```

The output status field is:

```text
consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_status
```

## Behavior

The command shape is:

```bash
zig build causal-app-facing-nine-level-report -- \
  --from-evaluator <eight-level-evaluator.json> \
  summarize \
  --reason <reason> \
  [--by <actor>] \
  [--policy <policy>] \
  [--out-prefix <path-prefix>]
```

Ready output requires:

- source schema equals the eight-level evaluator schema and version `1`;
- source evaluator status is `ready` or `advisory-findings`;
- source `ready_for_next_branch=true`;
- source has no blocked findings;
- source eight-level policy status is `ready`, source policy decision is
  `approve`, and source mutation authority remains `none`;
- source eight-level application-boundary and report refs are present;
- inherited policy, application-boundary, report, report application,
  request/support summaries, signal summaries, checks, denied claims, next
  queries, and publication channels are present;
- request analysis is present;
- SolidJS `webui-dev/zig-webui` read-only posture remains present;
- all CI, GitHub, app, runtime, durable storage, NenDB, adapter, deployment,
  hosted dashboard, production-health, public-upload, auto-apply, and mutation
  authority flags stay disabled;
- publication channels stay local-only and non-mutating.

Advisory source evaluator artifacts produce an advisory report when all hard
checks pass. Blocked source evaluator artifacts, authority drift, unsafe source
evidence, missing required evidence, unsupported schema, or disabled local-only
publication posture produce a blocked report.

## Data Flow

1. Read the eight-level evaluator artifact from a local JSON file.
2. Parse the evaluator artifact with alias-aware source fields:
   `source_eight_level_policy`, `source_eight_level_application_boundary`,
   `source_eight_level_report`, and normalized inherited refs.
3. Preserve fallback parsing for older fully expanded source field names.
4. Evaluate source reportability, inherited evidence, request/support summary
   carryover, denied claims, and disabled authority posture.
5. Emit deterministic JSON and text nine-level report artifacts.
6. Hand ready or advisory report artifacts to the nine-level
   application-boundary branch.

## Governance

Schema governance must register the nine-level report schema with
`emitted_by = causal-app-facing-nine-level-report`. The production hardening
backlog must mark `app-facing-nine-level-report` delivered, update the
recommendation to `start-app-facing-nine-level-application-boundary`, and point
the next branch to
`codex/zigeffect-causal-app-facing-nine-level-application-boundary`.

Compatibility tags must preserve the current posture: `strict-v1`,
`record-only`, `advisory-only`, `source-eight-level-evaluator`,
`local-report-only`, `read-only-consumption`, `bounded-agent-context`,
`app-facing`, `solid-webui`, `webui-dev/zig-webui`, and all no-authority tags.

## Testing

Use TDD:

- stable schema, branch, recommendation, next-branch, and alias constants;
- option parsing accepts `--from-evaluator`, `summarize`, `--reason`, `--by`,
  `--policy`, and `--out-prefix`;
- default output path replaces the eight-level evaluator suffix with the
  nine-level report suffix and compacts long paths;
- ready evaluator evidence emits a ready report;
- advisory evaluator evidence emits an advisory report without authority;
- blocked evaluator evidence emits a blocked report;
- authority drift in the source evaluator blocks the report;
- generated JSON is parseable;
- schema governance contains the nine-level report schema;
- production backlog recommendation moves to the nine-level application-boundary
  branch.

## Verification

Fresh verification for this milestone must include:

```bash
cd packages/zigeffect
zig test tools/causal_app_facing_nine_level_report.zig
zig build causal-app-facing-nine-level-report -- --help
zig build causal-schema-governance -- --format json
zig build causal-production-hardening-backlog -- --format json
zig build examples
zig build test
cd ../..
bun run check
bun run zig:test
git diff --check
```

The real artifact check must generate ready, advisory, and blocked nine-level
report artifacts from:

- `.zig-cache/causal-artifacts/app-facing-ci-eight-level-evaluator.json`
- `.zig-cache/causal-artifacts/app-facing-ci-eight-level-evaluator-advisory.json`
- `.zig-cache/causal-artifacts/app-facing-ci-eight-level-evaluator-blocked.json`

The ready artifact must have status `ready`, `ready_for_next_branch=true`, and
no failed report checks.

## Non-Goals

This branch does not create the nine-level application-boundary tool, required
status checks, workflow mutations, GitHub API calls, PR comments, public
artifact uploads, app config or app data mutations, app runtime projections, raw
prompt or payload capture, durable storage writes, NenDB writes, NenDB adapter
execution, Cockroach work, deployments, production-health claims, hosted
dashboards, auto-apply behavior, registry mutation, or mutation authority.
