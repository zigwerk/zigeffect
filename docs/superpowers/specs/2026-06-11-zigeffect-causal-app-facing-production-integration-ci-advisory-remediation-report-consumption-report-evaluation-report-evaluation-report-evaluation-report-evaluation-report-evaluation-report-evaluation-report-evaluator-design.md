# Zigeffect App-Facing Evaluation Report Evaluation Report Evaluation Report Evaluation Report Evaluation Report Evaluation Report Evaluator Design

## Context

The six-level policy producer now emits ready, rejected, and blocked policy artifacts for the six-level application-boundary evidence chain. Ready policy artifacts are interpretation evidence only: they say a reviewed local policy decision exists, while app, CI, GitHub, storage, deployment, runtime, and adapter mutation surfaces remain disabled.

This branch adds the matching six-level evaluator producer. It consumes a ready six-level policy artifact plus bounded local request and support evidence, then emits read-only evaluator artifacts for agents, reviewers, non-blocking CI advisory readers, and the SolidJS `webui-dev/zig-webui` workbench.

## Design

Recommended approach: copy the five-level evaluator producer and promote every evaluation-report lineage token by one level. This preserves the existing request/evidence classifier, source-policy checks, redaction posture rules, ready/advisory/blocked status model, denied authority catalog, and generated text/JSON shape.

Alternative approaches were considered but rejected:

- Merge evaluator logic into the policy producer. That would make policy review responsible for request/evidence classification and weaken the evidence chain.
- Start a new evaluator from scratch. That would risk drift from the proven predecessor status model and parser surface.
- Make missing support evidence fatal. The predecessor treats missing support as advisory when the source policy and request are otherwise safe, and that behavior is useful for incremental agent workflows.

## Components

- New tool: `packages/zigeffect/tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluator.zig`
- New docs: `packages/zigeffect/docs/app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator.md`
- Build step: `causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator`
- Output schema: `zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator.v1`
- Source schema: `zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy.v1`
- Next branch: `codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report`

## Behavior

The tool accepts:

```bash
zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator -- \
  --from-policy <consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy.json> \
  evaluate \
  --reason <reason> \
  --request <path>... \
  [--evidence <path>]... \
  [--by <actor>] \
  [--policy <policy>] \
  [--out-prefix <path-prefix>]
```

Ready output requires:

- the source policy schema and version match;
- the source policy decision is `approve`;
- the source policy status is ready and `ready_for_next_branch=true`;
- mutation authority remains `none`;
- inherited application-boundary, report, evaluator, policy, request, support evidence, denied claim, negative fixture, publication, and verification fields are present;
- at least one safe bounded request file is supplied;
- request and support evidence remain redacted or bounded;
- all CI, GitHub, app, runtime, durable storage, NenDB, adapter, public upload, deployment, hosted dashboard, production health, auto-apply, and mutation-authority flags stay disabled.

Missing support evidence produces an advisory evaluator artifact when the source policy and request files are otherwise safe. Blocked source policy, rejected policy, unsafe request files, unsafe support evidence, unbounded redaction posture, or authority drift produces blocked evaluator output.

## Data Flow

1. Read the six-level policy artifact.
2. Read one or more request files and optional support evidence files from local paths.
3. Classify each input as request JSON, request text, policy JSON, causal JSON, causal text, workbench text, or denied content.
4. Evaluate the source policy and file posture.
5. Emit deterministic JSON and text evaluator artifacts.
6. Hand ready or advisory evaluator artifacts to the seven-level local report branch.

## Testing

Use TDD with the predecessor evaluator fixture classes:

- constants are stable;
- option parsing accepts request and evidence inputs;
- default output path promotes the six-level policy suffix;
- safe request plus support evidence emits ready output;
- missing support evidence emits advisory findings without granting authority;
- blocked source policy or unsafe request evidence emits blocked output;
- generated JSON is parseable.

## Verification

Fresh verification for this milestone must include:

```bash
zig test tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluator.zig
zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluator -- --help
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
