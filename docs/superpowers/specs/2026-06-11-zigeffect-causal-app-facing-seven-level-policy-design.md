# Zigeffect App-Facing Seven-Level Policy Design

## Context

The seven-level application-boundary producer now emits `zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary.v1`. Applied boundary artifacts record reviewed local evidence, but they still do not grant CI, GitHub, app, runtime, storage, deployment, public upload, production-health, or auto-apply authority.

This milestone adds the matching seven-level policy producer. It interprets applied application-boundary evidence for agents, reviewers, non-blocking CI advisory readers, and the SolidJS `webui-dev/zig-webui` workbench, then hands approved policy evidence to the seven-level evaluator branch.

## Design

Promote the existing six-level policy producer by one evaluation-report level. The policy remains record-only and has two decisions:

- `approve`: emits ready policy evidence only when the source application-boundary is applied, ready for the next branch, locally published, and carries complete verification evidence.
- `reject`: emits blocked policy evidence as an explicit reviewer decision.

The tool never mutates an app, workflow, GitHub state, storage, deployment, adapter, CI setting, public artifact host, or production system.

## Components

- Tool: `packages/zigeffect/tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy.zig`
- Docs: `packages/zigeffect/docs/app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy.md`
- Build step: `causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy`
- Output schema: `zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy.v1`
- Source schema: `zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary.v1`
- Next branch: `codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator`

## Behavior

The tool accepts:

```bash
zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy -- \
  --from-application <consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary.json> \
  approve|reject \
  --reason <reason> \
  [--by <actor>] \
  [--policy <policy>] \
  [--verified-command <command>]... \
  [--out-prefix <path-prefix>]
```

Approval requires:

- source schema and version match the seven-level application-boundary producer;
- source application status is `applied`;
- source `ready_for_next_branch=true`;
- source application evidence, before evidence, after evidence, safe after-report evidence, checks, denied claims, boundary rules, publication channels, negative fixtures, and required verification commands are present;
- policy invocation records every required verification command;
- source and policy authority flags keep CI enforcement, required status checks, workflow mutation, GitHub mutation, app mutation, runtime integration, live projection, raw payload capture, deployment mutation, durable writes, NenDB writes, NenDB adapter execution, public upload, hosted dashboards, production health claims, and auto-apply disabled.

Planned, blocked, unsafe, incomplete, or authority-drift source boundaries produce blocked policy output. `reject` also produces blocked policy output and preserves denied inference guidance.

## Data Flow

1. Read the seven-level application-boundary artifact.
2. Parse source status, inherited evidence, checks, denied claims, publication posture, negative fixtures, and verification commands.
3. Apply the local reviewer decision.
4. Emit deterministic JSON and text policy artifacts.
5. Hand approved policy evidence to the seven-level evaluator branch.

## Tests

Focused Zig tests must cover:

- stable schema, branch, recommendation, and next-branch constants;
- `approve` and `reject` option parsing;
- default output path replacement from seven-level application-boundary suffix to seven-level policy suffix;
- approved policy is ready only with applied source evidence and verification commands;
- rejected policy is blocked and preserves denied inference rules;
- unsafe source or missing verification blocks approval;
- generated JSON is parseable.

Registry tests must prove:

- schema governance count increments from 127 to 128;
- schema governance contains the seven-level policy schema;
- production backlog recommendation moves to the seven-level evaluator branch;
- generated backlog docs contain the seven-level policy item and build commands.

## Verification

Fresh verification must include:

```bash
cd packages/zigeffect
zig test tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_policy.zig
zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy -- --help
zig build causal-schema-governance -- --format json
zig build causal-production-hardening-backlog -- --format json
zig build examples
zig build test
cd ../..
bun run check
bun run zig:test
git diff --check
```

## Non-Goals

This branch does not create required status checks, mutate workflows, call GitHub APIs, mutate app config or app data, integrate app runtime projections, capture raw payloads, write durable storage, write NenDB, execute NenDB adapters, add Cockroach work, upload public artifacts, deploy, prove production health, auto-apply, or grant mutation authority.
