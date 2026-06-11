# Zigeffect App-Facing Evaluation Report Evaluation Report Evaluation Report Evaluation Report Evaluation Report Evaluation Report Application Boundary Design

## Context

The six-level report producer now emits `zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report.v1` as local, read-only context for agents, reviewers, non-blocking CI advisory readers, and the SolidJS `webui-dev/zig-webui` workbench. The next milestone needs a guarded application-boundary artifact that records how that report is used without granting runtime, storage, GitHub, CI, deployment, or auto-apply authority.

The predecessor five-level application-boundary tool already establishes the desired shape. This branch promotes the lineage by one evaluation-report level and keeps the same safety semantics: `plan` records intent only with `applied=false`; `record-applied` records `applied=true` only when reviewed local application evidence, before evidence, after evidence, safe after-report content, and every required verification command are present.

## Design

Recommended approach: copy the five-level application-boundary producer and mechanically promote lineage tokens by one level, then update constants, docs, build registration, schema governance, backlog, and roadmap. This is better than inventing a new boundary shape because the existing report/application-boundary/policy/evaluator/report rhythm is now the project convention and its negative fixtures already encode the required guardrails.

Alternative approaches were considered but rejected for this milestone:

- Extend the six-level report producer directly with application-boundary fields. That would blur report presentation with application evidence and make the next policy branch less explicit.
- Start the policy branch immediately. That would skip the reviewed local application-boundary evidence layer that prevents `applied=true` from being inferred from readiness alone.

## Components

- New tool: `packages/zigeffect/tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_boundary.zig`
- New docs: `packages/zigeffect/docs/app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary.md`
- Build step: `causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary`
- Output schema: `zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary.v1`
- Source schema: `zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report.v1`
- Next branch: `codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy`

## Behavior

The tool accepts:

```bash
zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary -- \
  --from-report <consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report.json> \
  plan|record-applied \
  --reason <reason> \
  [--by <actor>] \
  [--policy <policy>] \
  [--evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-after <path>] \
  [--evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-change <text>] \
  [--before <text>] \
  [--after <text>] \
  [--verified-command <command>] \
  [--out-prefix <path-prefix>]
```

`plan` mode succeeds for ready or advisory source reports, records the local application intent, keeps `applied=false`, and skips post-application verification checks. It must still preserve `mutation_authority = none`.

`record-applied` mode succeeds only when all of these are true:

- the source report schema and version match the six-level report producer;
- the source report is ready or advisory and has no blocked findings;
- the source report keeps CI enforcement, required status checks, GitHub mutation, app mutation, runtime integration, live projection, raw payload capture, deployment mutation, durable writes, NenDB writes, NenDB adapter execution, public upload, hosted dashboards, production health claims, and auto-apply disabled;
- report application changes, before evidence, after evidence, and safe after-report text are present;
- every required verification command is recorded after the application evidence;
- publication remains local-only and read-only for the SolidJS WebUI surface.

Blocked source reports, unsafe after-report content, missing evidence, incomplete verification, or authority drift must produce a blocked boundary with `applied=false`.

## Data Flow

1. Read the six-level report artifact.
2. Parse source metadata, checks, findings, denied claims, required verification commands, and publication channels.
3. In `plan` mode, emit planned local application-boundary evidence.
4. In `record-applied` mode, validate reviewed local evidence and post-application verification before setting `applied=true`.
5. Emit deterministic JSON and text artifacts under `.zig-cache/causal-artifacts/`.
6. Hand ready applied evidence to the next six-level policy branch.

## Testing

Use TDD with the same fixture classes as the predecessor:

- constants are stable;
- option parsing accepts `plan` and `record-applied`;
- default output path promotes the six-level report suffix;
- plan mode records `applied=false`;
- record-applied requires reviewed evidence and all verification commands;
- missing evidence blocks applied state;
- unsafe after-report content blocks applied state;
- blocked source reports and authority drift block applied state;
- generated JSON is parseable.

## Verification

Fresh verification for this milestone must include:

```bash
zig test tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_boundary.zig
zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary -- --help
zig build causal-schema-governance -- --format json
zig build causal-production-hardening-backlog -- --format json
zig build examples
zig build test
bun run check
bun run zig:test
git diff --check
```

## Non-Goals

This branch does not mutate GitHub, create required status checks, upload public artifacts, run CI enforcement, write app config/data, execute NenDB adapters, add Cockroach work, deploy services, host dashboards, or claim production health.
