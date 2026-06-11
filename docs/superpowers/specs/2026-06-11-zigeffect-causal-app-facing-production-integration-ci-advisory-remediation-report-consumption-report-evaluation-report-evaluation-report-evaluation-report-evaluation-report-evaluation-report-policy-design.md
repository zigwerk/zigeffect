# Zigeffect App-Facing Evaluation Report Evaluation Report Evaluation Report Evaluation Report Evaluation Report Policy Design

## Context

The five-level application-boundary producer now emits planned, applied, and blocked artifacts for local use of the five-level evaluation-report artifact. Applied boundary artifacts use `mutation_authority = "record-only"` to indicate reviewed local evidence recording; all actual app, CI, GitHub, storage, deployment, and adapter mutation surfaces remain disabled.

This branch adds the matching five-level policy producer. It interprets applied application-boundary evidence as approve/reject policy context for agents, reviewers, non-blocking CI advisory readers, and the SolidJS `webui-dev/zig-webui` workbench. It prepares the next evaluator branch without changing app state or creating any runtime authority.

## Design

Recommended approach: copy the four-level policy producer and promote every evaluation-report lineage token by one level. This keeps the report/application-boundary/policy/evaluator sequence consistent and preserves the predecessor's tested approve/reject guardrails.

Alternative approaches were considered but rejected:

- Merge policy interpretation into the application-boundary tool. That would blur evidence recording with policy review and make evaluator inputs less explicit.
- Skip policy and go straight to evaluator. That would force the evaluator to infer whether applied boundary evidence was approved or rejected, weakening the causal chain.

## Components

- New tool: `packages/zigeffect/tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy.zig`
- New docs: `packages/zigeffect/docs/app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy.md`
- Build step: `causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy`
- Output schema: `zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy.v1`
- Source schema: `zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary.v1`
- Next branch: `codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator`

## Behavior

The tool accepts:

```bash
zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy -- \
  --from-application <consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary.json> \
  approve|reject \
  --reason <reason> \
  [--by <actor>] \
  [--policy <policy>] \
  [--verified-command <command>]... \
  [--out-prefix <path-prefix>]
```

`approve` emits ready policy evidence only when:

- the source application-boundary schema and version match;
- the source boundary is applied and ready for the next branch;
- the source boundary carries reviewed application changes, before evidence, after evidence, safe after-report evidence, publication channel evidence, denied claims, negative fixtures, and required verification commands;
- all required verification commands are supplied again as policy verification evidence;
- the source keeps CI enforcement, required status checks, GitHub mutation, app mutation, runtime integration, live projection, raw payload capture, deployment mutation, durable writes, NenDB writes, NenDB adapter execution, public upload, hosted dashboards, production health claims, and auto-apply disabled.

`reject` emits blocked policy evidence. Rejection is a first-class policy decision, not a tool failure.

Blocked, planned, unsafe, or incomplete source boundaries must produce blocked policy output. Missing verification evidence must also block approval.

## Data Flow

1. Read the five-level application-boundary artifact.
2. Parse source boundary status, applied state, checks, denied claims, boundary rules, publication channels, negative fixtures, and verification command evidence.
3. Apply the local reviewer decision.
4. Emit deterministic JSON and text policy artifacts.
5. Hand approved policy artifacts to the five-level evaluator branch.

## Testing

Use TDD with the predecessor policy fixture classes:

- constants are stable;
- option parsing accepts approve and reject;
- default output path promotes the five-level boundary suffix;
- approved policy output is ready only with applied source boundary and complete verification evidence;
- rejected policy output is blocked and preserves denied inference rules;
- unsafe source or missing verification blocks approval;
- generated JSON is parseable.

## Verification

Fresh verification for this milestone must include:

```bash
zig test tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy.zig
zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy -- --help
zig build causal-schema-governance -- --format json
zig build causal-production-hardening-backlog -- --format json
zig build examples
zig build test
bun run check
bun run zig:test
git diff --check
```

## Non-Goals

This branch does not create required status checks, mutate workflows, call GitHub APIs, mutate app config or app data, integrate app runtime projections, capture raw payloads, write durable storage, write NenDB, execute NenDB adapters, add Cockroach work, upload public artifacts, deploy, prove production health, auto-apply, or grant mutation authority.
