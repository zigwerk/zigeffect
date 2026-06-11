# Zigeffect App-Facing Evaluation Report Evaluation Report Evaluation Report Evaluation Report Evaluation Report Evaluation Report Evaluation Report Design

## Context

The six-level evaluator now emits ready, advisory, and blocked artifacts for agents, reviewers, non-blocking CI advisory readers, and the SolidJS `webui-dev/zig-webui` workbench. Those evaluator artifacts classify bounded local request and support evidence, carry forward the reviewed policy/application/report lineage, and keep app, CI, GitHub, runtime, storage, deployment, NenDB, adapter, public upload, hosted dashboard, and auto-apply authority disabled.

This branch adds the seven-level local report producer. It consumes a ready or advisory six-level evaluator artifact and emits a compact, deterministic report artifact that agents can read as bounded context before the matching application-boundary branch.

## Design

Recommended approach: copy the six-level report producer and promote every evaluation-report lineage token by one level. This preserves the existing read-only summary format, ready/advisory/blocked status model, source-evaluator checks, denied-authority catalog, publication boundary, and local JSON/text artifact behavior.

Alternative approaches were considered but rejected:

- Collapse the seven-level report into the evaluator. That would mix request classification with report publication and make the next application-boundary less explicit.
- Start a new report schema without lineage carryover. That would make agents lose the prior policy/application/report evidence trail.
- Grant CI or app authority from a ready report. Reports are context only; application authority still requires a reviewed boundary branch.

## Components

- New tool: `packages/zigeffect/tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report.zig`
- New docs: `packages/zigeffect/docs/app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report.md`
- Build step: `causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report`
- Output schema: `zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report.v1`
- Source schema: `zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator.v1`
- Next branch: `codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary`

## Behavior

The tool accepts:

```bash
zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report -- \
  --from-evaluator <consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator.json> \
  summarize \
  --reason <reason> \
  [--by <actor>] \
  [--policy <policy>] \
  [--out-prefix <path-prefix>]
```

Ready output requires:

- the source evaluator schema and version match;
- the source evaluator status is `ready`;
- `ready_for_next_branch=true`;
- blocked findings are absent;
- inherited six-level policy, application-boundary, report, request, support evidence, denied claim, publication, and verification fields are present;
- source policy status is ready and policy decision is approve;
- source application-boundary status is applied;
- request and support-evidence summaries are bounded;
- CI, GitHub, app, runtime, durable storage, NenDB, adapter, public upload, deployment, hosted dashboard, production health, auto-apply, and mutation-authority flags stay disabled;
- `advisory_report=true`, `read_only_preview=true`, `read_only_consumption_enabled=true`, `solid_webui_enabled=true`, `solid_webui_renderer="solidjs"`, and `webui_bridge="webui-dev/zig-webui"`.

If the source evaluator is advisory but still reportable, the report status is advisory and remains eligible for the next application-boundary branch. If the source evaluator is blocked, malformed, missing required lineage evidence, or grants authority, the report is blocked and `ready_for_next_branch=false`.

## Data Flow

1. Read the six-level evaluator artifact from a local JSON path.
2. Validate source schema, reportable status, and ready-for-next-branch posture.
3. Carry forward request, support-evidence, signal, finding, denied-claim, policy-rule, consumption-scope, next-query, and publication-boundary summaries.
4. Re-check authority and SolidJS WebUI posture.
5. Emit deterministic JSON and text report artifacts.
6. Hand ready or advisory report artifacts to the seven-level application-boundary branch.

## Testing

Use TDD with the predecessor report fixture shape:

- constants are stable;
- option parsing requires `--from-evaluator`, `summarize`, and `--reason`;
- default output path promotes the six-level evaluator suffix into a compact seven-level report suffix when needed;
- ready source evaluator emits ready output;
- advisory source evaluator emits advisory output without granting authority;
- blocked source evaluator emits blocked output;
- generated JSON is parseable and preserves no-mutation authority.

## Verification

Fresh verification for this milestone must include:

```bash
zig test tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report.zig
zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report -- --help
zig build causal-schema-governance -- --format json
zig build causal-production-hardening-backlog -- --format json
zig build examples
zig build test
bun run check
bun run zig:test
git diff --check
```

## Non-Goals

This branch does not create required status checks, mutate workflows, call GitHub APIs, write PR comments, upload public artifacts, mutate app config or app data, integrate app runtime projections, capture raw prompts or payloads, write durable storage, write NenDB, execute NenDB adapters, add Cockroach work, deploy, prove production health, create hosted dashboards, auto-apply, update registries, or grant mutation authority.
