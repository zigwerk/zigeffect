# Zigeffect App-Facing Seven-Level Evaluator Design

## Context

The seven-level policy producer now emits ready, rejected, and blocked policy artifacts for the seven-level application-boundary evidence chain. Ready policy artifacts remain interpretation evidence only: they prove reviewed local policy evidence exists, while CI, GitHub, app runtime, storage, deployment, public upload, production-health, auto-apply, and mutation-authority surfaces remain disabled.

This milestone adds the matching seven-level evaluator producer. It consumes a ready seven-level policy artifact plus bounded local request and support evidence, then emits read-only evaluator artifacts for agents, reviewers, non-blocking CI advisory readers, and the SolidJS `webui-dev/zig-webui` workbench.

## Design

Promote the existing six-level evaluator producer by one evaluation-report level. The evaluator keeps the proven status model:

- `ready`: source policy is approved and ready, request evidence is safe and bounded, support evidence is present and bounded, and all authority flags remain disabled.
- `advisory-findings`: source policy and request evidence are safe, but optional support evidence is missing.
- `blocked`: source policy is rejected or blocked, request or support evidence is unsafe, required inherited evidence is missing, or any denied authority appears.

Alternative approaches were considered but rejected:

- Merge evaluator behavior into the policy producer. That would mix policy interpretation and request/support evidence classification.
- Start a new evaluator from scratch. That would risk drift from the existing classifier and artifact shape.
- Treat missing support evidence as fatal. The predecessor deliberately allows advisory evaluator output for incomplete support, which is useful for incremental local agent workflows.

## Components

- Tool: `packages/zigeffect/tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluator.zig`
- Docs: `packages/zigeffect/docs/app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator.md`
- Build step: `causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator`
- Output schema: `zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator.v1`
- Source schema: `zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy.v1`
- Next branch: `codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report`

## Behavior

The tool accepts:

```bash
zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator -- \
  --from-policy <consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy.json> \
  evaluate \
  --reason <reason> \
  --request <path>... \
  [--evidence <path>]... \
  [--by <actor>] \
  [--policy <policy>] \
  [--out-prefix <path-prefix>]
```

Ready output requires:

- source policy schema and version match the seven-level policy producer;
- source policy decision is `approve`;
- source policy status is `ready` and `ready_for_next_branch=true`;
- source policy and inherited application/report/evaluator evidence remain `mutation_authority=none`;
- inherited application-boundary, report, evaluator, policy, request, support evidence, denied claim, negative fixture, publication, and verification fields are present;
- at least one safe bounded request file is supplied;
- request and support evidence remain redacted or bounded;
- all CI, GitHub, app, runtime, durable storage, NenDB, adapter, public upload, deployment, hosted dashboard, production health, auto-apply, and mutation-authority flags stay disabled.

Missing support evidence produces an `advisory-findings` evaluator artifact when the source policy and request files are otherwise safe. Blocked source policy, rejected policy, unsafe request files, unsafe support evidence, unbounded redaction posture, public upload claims, app runtime claims, NenDB write claims, Cockroach claims, or authority drift produces blocked evaluator output.

## Data Flow

1. Read the seven-level policy artifact.
2. Read one or more request files and optional support evidence files from local paths.
3. Classify each input as request JSON, request text, policy JSON, causal JSON, causal text, workbench text, or denied content.
4. Evaluate source policy readiness and file posture.
5. Emit deterministic JSON and text evaluator artifacts.
6. Hand ready or advisory evaluator artifacts to the eight-level local report branch.

## Testing

Use TDD with the predecessor evaluator fixture classes:

- constants are stable;
- option parsing accepts request and evidence inputs;
- default output path promotes the seven-level policy suffix;
- safe request plus support evidence emits ready output;
- missing support evidence emits advisory findings without granting authority;
- blocked source policy or unsafe request evidence emits blocked output;
- generated JSON is parseable;
- schema governance contains the seven-level evaluator schema;
- production backlog recommendation moves to the eight-level report branch.

## Verification

Fresh verification for this milestone must include:

```bash
zig test tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluator.zig
zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator -- --help
zig build causal-schema-governance -- --format json
zig build causal-production-hardening-backlog -- --format json
zig build examples
zig build test
bun run check
bun run zig:test
git diff --check
```

## Non-Goals

This branch does not create required status checks, mutate workflows, call GitHub APIs, write PR comments, upload public artifacts, mutate app config or app data, integrate app runtime projections, capture raw prompts or payloads, write durable storage, write NenDB, execute NenDB adapters, add Cockroach work, deploy, prove production health, create hosted dashboards, auto-apply, or grant mutation authority.
