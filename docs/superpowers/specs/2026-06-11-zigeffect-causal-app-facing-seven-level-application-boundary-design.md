# Zigeffect App-Facing Seven-Level Application Boundary Design

## Context

The seven-level report producer now emits `zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report.v1` as local, read-only context for agents, reviewers, non-blocking CI advisory readers, and the SolidJS `webui-dev/zig-webui` workbench.

The next milestone is the matching guarded application-boundary artifact. It records how a reviewed local application of that report would be planned or externally applied, while preserving the central invariant of this roadmap: report readiness alone never becomes mutation authority, app runtime integration, storage writes, CI enforcement, deployment mutation, public upload, or `applied=true`.

## Design

Promote the existing six-level application-boundary producer by one evaluation-report level. This keeps the established report -> application-boundary -> policy -> evaluator -> report rhythm intact, preserves the negative fixture catalog, and gives future agents one more explicit causal handoff to reason over.

The new tool has two modes:

- `plan`: records intended local consumption of a ready or advisory seven-level report and always emits `applied=false`.
- `record-applied`: records externally reviewed application evidence only when all guard checks pass, then emits `applied=true` and `ready_for_next_branch=true` as record-only evidence for the next policy branch.

`record-applied` is not an auto-apply mechanism. It records reviewer-supplied evidence after a local application has already been reviewed outside the tool.

## Components

- Tool: `packages/zigeffect/tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_boundary.zig`
- Docs: `packages/zigeffect/docs/app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary.md`
- Build step: `causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary`
- Output schema: `zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary.v1`
- Source schema: `zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report.v1`
- Next branch: `codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-policy`

## Behavior

The tool accepts:

```bash
zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary -- \
  --from-report <consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report.json> \
  plan|record-applied \
  --reason <reason> \
  [--by <actor>] \
  [--policy <policy>] \
  [--evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-after <path>] \
  [--evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-change <text>] \
  [--before <text>] \
  [--after <text>] \
  [--verified-command <command>] \
  [--out-prefix <path-prefix>]
```

Required `record-applied` gates:

- source schema and version match the seven-level report;
- source status is ready or advisory;
- source has no blocked findings;
- source `ready_for_next_branch=true`;
- source evidence, policy evidence, application-boundary evidence, evaluator evidence, request summaries, signal summaries, denied claims, and local publication channels are carried forward;
- source authority flags keep CI enforcement, required status checks, workflow mutation, GitHub mutation, app mutation, runtime integration, live projection, raw payload capture, deployment mutation, durable writes, NenDB writes, NenDB adapter execution, public upload, hosted dashboards, production health claims, and auto-apply disabled;
- reviewed application-change evidence is present;
- before evidence and after evidence are present;
- after-report content is present and does not claim unsafe authority;
- every required verification command is recorded;
- publication remains local-only and read-only for agent and SolidJS WebUI consumption.

Blocked source reports, unsafe after-report content, missing evidence, incomplete verification, unsafe publication claims, or authority drift emit a blocked boundary artifact with `applied=false`.

## Data Flow

1. Read the seven-level report artifact.
2. Parse report status, inherited source chain evidence, checks, findings, denied claims, required verification commands, and publication channels.
3. In `plan` mode, emit planned local application-boundary evidence.
4. In `record-applied` mode, require reviewed local evidence and verification commands before marking applied.
5. Emit deterministic JSON and text artifacts under `.zig-cache/causal-artifacts/`.
6. Hand ready applied evidence to the seven-level policy branch.

## Tests

Focused Zig tests must cover:

- stable schema, branch, recommendation, and next-branch constants;
- option parsing for `plan` and `record-applied`;
- default output path replacement from seven-level report suffix to seven-level application-boundary suffix;
- plan mode records planned state without applied authority;
- record-applied requires reviewed evidence before applied can be true;
- missing evidence blocks application;
- unsafe after-report text blocks application;
- blocked source report blocks application;
- source authority drift blocks application;
- generated JSON is parseable.

Registry tests must also prove:

- schema governance count increments from 126 to 127;
- generated schema docs contain the new schema;
- production backlog recommendation moves to the seven-level policy branch;
- generated backlog docs contain the seven-level application-boundary item and build commands.

## Verification

Fresh verification for the branch must include:

```bash
cd packages/zigeffect
zig test tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_evaluation_report_application_boundary.zig
zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report-application-boundary -- --help
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

This milestone does not mutate GitHub, create required status checks, upload public artifacts, enforce CI, write app config or app data, execute NenDB adapters, add Cockroach work, deploy services, host dashboards, or claim production health.
