# Zigeffect App-Facing Eight-Level Report Design

## Context

The seven-level evaluator now emits ready, advisory, and blocked artifacts for
agents, reviewers, non-blocking CI advisory readers, and the SolidJS
`webui-dev/zig-webui` workbench. Ready and advisory evaluator artifacts are
read-only evidence for the next local report branch. Blocked evaluator artifacts
are stop signs.

This milestone adds the eight-level report producer. It consumes a seven-level
evaluator artifact and emits a compact local report artifact that preserves the
source evaluator status, request and support evidence summaries, inherited
policy/application/report references, denied claims, findings, next queries, and
publication boundaries.

## Design

Promote the existing seven-level report producer by one lineage level. The
producer keeps the established report status model:

- `ready`: source evaluator is ready, all required source references and
  inherited evidence are present, blocked findings are absent, and all mutation
  surfaces remain disabled.
- `advisory`: source evaluator is `advisory-findings` or carries advisory
  findings, but remains reportable and non-mutating.
- `blocked`: source evaluator is blocked, missing required evidence, carries
  blocked findings, crosses a denied authority boundary, or is not the expected
  seven-level evaluator schema.

The implementation must promote every evaluation-report lineage token by one
level, including nested source-evaluator fields. A top-level-only replacement is
not enough because the report producer parses inherited policy/application
fields from the source evaluator artifact.

## Components

- Tool:
  `packages/zigeffect/tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report.zig`
- Docs:
  `packages/zigeffect/docs/app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report.md`
- Build step:
  `causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report`
- Output schema:
  `zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report.v1`
- Source schema:
  `zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator.v1`
- Next branch:
  `codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary`

## Behavior

The tool accepts:

```bash
zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report -- \
  --from-evaluator <consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator.json> \
  summarize \
  --reason <reason> \
  [--by <actor>] \
  [--policy <policy>] \
  [--out-prefix <path-prefix>]
```

Ready output requires:

- source evaluator schema and version match the seven-level evaluator producer;
- source evaluator status is `ready`;
- source evaluator has `ready_for_next_branch=true`;
- source evaluator has no blocked findings;
- source policy decision is `approve`;
- inherited seven-level application-boundary, policy, report, request, support,
  denied-claim, next-query, publication, and verification evidence is present;
- source and inherited mutation authority remain `none`;
- CI enforcement, required status checks, workflow mutation, GitHub API
  mutation, app mutation, app runtime integration, live projection, raw payload
  capture, Durable Object writes, NenDB writes, NenDB adapter execution, public
  upload, hosted dashboard, production health, auto-apply, and deployment
  mutation remain disabled.

Advisory output is reportable when the source evaluator is `advisory-findings`
or contains advisory findings without blocked findings. Blocked output preserves
the blocked source and must not hand off to the application-boundary branch.

## Data Flow

1. Read the seven-level evaluator JSON artifact.
2. Parse source evaluator evidence with unknown fields ignored.
3. Evaluate schema, reportability, source readiness, inherited refs, evidence,
   disabled authority, SolidJS read-only posture, and local publication posture.
4. Emit deterministic JSON and text report artifacts.
5. Hand ready or advisory report artifacts to the eight-level
   application-boundary branch.

## Testing

Use TDD with the previous report producer as the fixture source:

- constants are stable;
- option parsing accepts `--from-evaluator`, `summarize`, `--reason`, `--by`,
  `--policy`, and `--out-prefix`;
- default output path replaces the seven-level evaluator suffix;
- overly long default names compact deterministically;
- ready evaluator input produces ready report output;
- advisory evaluator input produces advisory report output;
- blocked evaluator input produces blocked report output;
- authority drift in the source evaluator blocks the report;
- publication channels remain local-only and record-only;
- generated JSON is parseable;
- schema governance contains the eight-level report schema;
- production backlog recommendation moves to the eight-level
  application-boundary branch.

## Verification

Fresh verification for this milestone must include:

```bash
zig test tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report.zig
zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report -- --help
zig build causal-schema-governance -- --format json
zig build causal-production-hardening-backlog -- --format json
zig build examples
zig build test
bun run check
bun run zig:test
git diff --check
```

## Non-Goals

This branch does not create required status checks, mutate workflows, call
GitHub APIs, write PR comments, upload public artifacts, mutate app config or
app data, integrate app runtime projections, capture raw prompts or payloads,
write durable storage, write NenDB, execute NenDB adapters, add Cockroach work,
deploy, prove production health, create hosted dashboards, auto-apply, or grant
mutation authority.
