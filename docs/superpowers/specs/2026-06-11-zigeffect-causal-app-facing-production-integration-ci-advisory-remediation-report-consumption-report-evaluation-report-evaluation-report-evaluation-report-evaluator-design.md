# Zigeffect App-Facing Evaluation Report Evaluation Report Evaluation Report Evaluator Design

## Context

The previous milestone delivered `causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-policy` and committed it on branch `codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-policy`.

This branch consumes that policy evidence and evaluates explicit local request and support evidence files. It is the read-only evaluator handoff before the next report summarizer branch:

`codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report`

The source policy artifact schema is:

`zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-policy.v1`

The evaluator output schema will be:

`zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluator.v1`

## Goals

- Consume a ready, approved triple evaluation-report policy artifact.
- Require at least one explicit request file under `.zig-cache/causal-artifacts`.
- Optionally consume support evidence files from the same bounded local artifact directory.
- Emit deterministic local JSON and text evaluator artifacts.
- Classify the evaluator status as `ready`, `advisory-findings`, or `blocked`.
- Preserve all no-mutation, no-publication, and no-production-health boundaries.
- Handoff only to the next report summarizer branch.

## Non-Goals

- No runtime app integration.
- No GitHub API mutation.
- No CI enforcement, required status check, workflow write, step summary write, PR comment, or artifact upload.
- No durable writes, NenDB writes, NenDB adapter execution, or Cockroach work.
- No public dashboard, hosted dashboard, production telemetry ingestion, or production health claim.
- No React or alternate renderer; the workbench direction remains SolidJS inside `webui-dev/zig-webui`.
- No raw prompt, raw response, or raw payload capture.

## Architecture

The evaluator should follow the existing predecessor pattern in:

`packages/zigeffect/tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_report_evaluation_report_evaluation_report_evaluator.zig`

It remains a single self-contained Zig CLI tool because the surrounding causal chain already uses single-file deterministic producers. The new tool should be a mechanical depth increment of that predecessor, not a new abstraction.

The command shape is:

```bash
zig build causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluator -- \
  --from-policy <consumption-report-evaluation-report-evaluation-report-evaluation-report-policy.json> \
  evaluate \
  --reason <reason> \
  --request <path>... \
  [--evidence <path>]...
```

The tool reads:

- One source policy JSON artifact.
- One or more request files.
- Zero or more evidence files.

It writes:

- A JSON evaluator artifact.
- A text evaluator artifact.

Default output paths should replace the source `-policy.json` suffix with `-evaluator`, using the same compact-path fallback used by the predecessor.

## Source Contract

The `SourcePolicyArtifact` parser must use the actual triple policy artifact fields. Required current-layer fields include:

- `consumption_report_evaluation_report_evaluation_report_evaluation_report_policy_status`
- `source_consumption_report_evaluation_report_evaluation_report_evaluation_report_application_boundary`
- `source_consumption_report_evaluation_report_evaluation_report_evaluation_report_application_boundary_schema`
- `source_consumption_report_evaluation_report_evaluation_report_evaluation_report`
- `source_consumption_report_evaluation_report_evaluation_report_evaluation_report_status`
- `source_evaluation_report_evaluation_report_evaluation_report_application_status`
- `source_evaluation_report_evaluation_report_evaluation_report_after_digest`
- `source_evaluation_report_evaluation_report_evaluation_report_after_present`
- `source_evaluation_report_evaluation_report_evaluation_report_application_changes`

Inherited double-layer fields must stay at the names emitted by the policy artifact:

- `source_consumption_report_evaluation_report_evaluation_report_policy`
- `source_consumption_report_evaluation_report_evaluation_report_policy_schema`
- `source_evaluation_report_evaluation_report_policy_status`
- `source_consumption_report_evaluation_report_evaluation_report_application_boundary`
- `source_consumption_report_evaluation_report_evaluation_report_application_boundary_schema`
- `source_consumption_report_evaluation_report_evaluation_report`
- `source_consumption_report_evaluation_report_evaluation_report_status`
- `source_evaluation_report_evaluation_report_application_status`
- `source_evaluation_report_evaluation_report_application_changes`

The parser should continue accepting inherited lower-layer source references, checks, summaries, denied claims, negative fixtures, interpretation rules, consumption scopes, required verification commands, and verified commands with `.ignore_unknown_fields = true`.

## Evaluation Rules

The evaluator is ready only when:

- Source schema and schema version match.
- Source policy status is `ready`.
- Source decision is `approve`.
- `ready_for_next_branch` is true.
- `mutation_authority` is `none`.
- Triple application-boundary source refs and digest evidence are present.
- Inherited source refs and summaries remain present.
- Source policy checks have no failures.
- Interpretation rules, consumption scopes, denied inference rules, negative fixtures, required commands, and verified commands are present.
- Every authority flag remains disabled.
- Advisory, read-only preview, read-only consumption, SolidJS, and `webui-dev/zig-webui` flags remain enabled.
- At least one safe request file is supplied.
- Any supplied support evidence is safe.
- Request/evidence redaction posture is bounded or redacted-bounded.

The evaluator is advisory when source policy is ready and request evidence is safe, but support evidence is absent.

The evaluator is blocked when source policy is not ready, source authority drifts, required source evidence is missing, request files are missing, request/evidence files are unsafe, or denied production/mutation claims appear.

## Input File Boundary

Request and evidence paths must be `.json` or `.txt` under `.zig-cache/causal-artifacts`. The tool should reject or block inputs containing:

- Secret-shaped markers such as `secrets.`, `PRODUCTION_`, `BEGIN PRIVATE KEY`, `Authorization:`, `sk-`, `ghp_`, or `xoxb-`.
- Raw prompt, raw response, or raw payload capture.
- CI enforcement, required status check, workflow mutation, GitHub API mutation, app mutation, app runtime integration, live agent projection, durable write, NenDB write, NenDB adapter execution, public upload, hosted dashboard, production health, deployment, auto-apply, mutation authority, Cockroach scope, or React renderer claims.

## Outputs

JSON output should include:

- Schema metadata.
- Source policy references and statuses.
- Triple current-layer refs and inherited source refs.
- Request file summaries.
- Evidence file summaries.
- Checks, signal evaluations, and findings.
- Source policy rule ids, source consumption scope ids, denied claims, next queries, required verification commands, and agent guidance.
- All authority booleans, preserving mutation authority as `none`.

Text output should provide the same information in a concise human-readable report.

## Governance And Roadmap

Schema governance must add the new evaluator schema and increment the schema count from 112 to 113.

Production hardening backlog must mark this evaluator item delivered and recommend the next report summarizer branch:

`codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-report-evaluation-report-evaluation-report-evaluation-report-evaluation-report`

The master roadmap must mark the evaluator branch delivered and add that report summarizer branch as the next item.

## Testing

Use TDD:

1. Add a minimal constants test first and verify it fails because the implementation constants do not exist.
2. Implement the evaluator by adapting the predecessor evaluator.
3. Run focused evaluator tests.
4. Register the build target and verify `--help`.
5. Generate ready, advisory, and blocked evaluator artifacts from the real triple policy artifact and bounded local request/evidence fixtures.
6. Verify schema governance and backlog JSON.
7. Run `zig build examples`, `zig build test`, `bun run check`, `bun run zig:test`, and `git diff --check`.

## Open Decisions

The current branch should stay conservative. It should not add a new shared abstraction across the long evaluator/report chain yet; that can happen later when the repeated pattern stabilizes enough to justify extracting a reusable producer framework.
