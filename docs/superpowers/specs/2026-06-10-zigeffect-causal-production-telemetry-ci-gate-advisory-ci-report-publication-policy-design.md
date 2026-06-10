# zigeffect Causal Production Telemetry CI Gate Advisory CI Report Publication Policy Design

## Summary

Create `causal-production-telemetry-ci-gate-advisory-ci-report-publication-policy`,
a guarded, record-only policy tool that consumes an applied
`zigeffect.causal.production-telemetry-ci-gate-advisory-ci-report-application-boundary.v1`
artifact and defines how an externally published advisory CI report may be
interpreted by humans, agents, and future readiness tools.

This branch approves interpretation policy only. It does not publish reports,
upload artifacts, write GitHub step summaries, post pull request comments,
mutate workflows, create required status checks, enable CI gate enforcement,
ingest live telemetry, call networks, configure collector endpoints, serialize
OTLP, write durable production storage, write NenDB, claim production health,
claim cluster readiness, add non-NenDB durable adapter scope, add alternate
renderer scope, or grant production mutation authority.

## Goals

- Consume applied advisory CI report application-boundary artifacts.
- Reject planned, blocked, non-applied, or mutation-authority-bearing source
  artifacts.
- Emit deterministic JSON and text artifacts with policy status, source checks,
  interpretation rules, denied inference rules, publication surface policy,
  negative fixtures, required verification commands, and next-branch guidance.
- Make advisory CI report publication useful for reviewer and agent triage
  without creating merge-blocking semantics.
- Preserve the user's platform constraints: NenDB adapter only for durable
  direction and SolidJS inside `webui-dev/zig-webui` for workbench direction.
- Hand off only ready policy artifacts to a future required-status-check
  readiness branch.

## Non-Goals

- No report publication execution by this tool.
- No GitHub step-summary writing by this tool.
- No pull request comments by this tool.
- No CI artifact upload execution by this tool.
- No required status checks, branch protection, or merge-blocking gate.
- No CI gate enforcement.
- No live telemetry, runtime pipeline execution, network send, collector
  configuration, or OTLP serialization.
- No durable writes and no NenDB writes.
- No production health, deployment success, capacity, customer impact, or
  production cluster readiness claims.
- No Cockroach, non-NenDB durable adapter, React, or alternate frontend
  renderer work.
- No mutation authority. Policy readiness is record-only evidence.

## CLI

```sh
zig build causal-production-telemetry-ci-gate-advisory-ci-report-publication-policy -- \
  --from-application <advisory-ci-report-application-boundary.json> \
  approve|reject \
  --reason <reason>
```

Optional flags:

- `--by <actor>`: reviewer or agent id. Defaults to
  `ci-gate-advisory-ci-report-publication-policy-reviewer`.
- `--policy <policy>`: policy id. Defaults to
  `manual-production-telemetry-ci-gate-advisory-ci-report-publication-policy`.
- `--verified-command <command>`: post-policy verification evidence.
- `--out-prefix <path-prefix>`: override output paths.

Default output path replacement:

- `*-ci-gate-advisory-ci-report-application-boundary.json` becomes
  `*-ci-gate-advisory-ci-report-publication-policy.json`.
- Deeply chained implicit output names should be compacted to a deterministic
  filesystem-safe prefix with a short source-path digest.

## Source Application Boundary Contract

The source artifact is publication-policy-ready when:

- `schema` is
  `zigeffect.causal.production-telemetry-ci-gate-advisory-ci-report-application-boundary.v1`.
- `schema_version` is `1`.
- `mode` is `record-applied`.
- `report_application_status` is `applied`.
- `applied=true`.
- `mutation_authority="record-only"`.
- `ci_report_publication_enabled=false`.
- `github_step_summary_write_enabled=false`.
- `pull_request_comment_enabled=false`.
- `ci_upload_execution_enabled=false`.
- `ci_gate_enabled=false`.
- `ci_gate_enforcement_enabled=false`.
- `ci_required_status_check_enabled=false`.
- `ci_workflow_mutation_enabled=false`.
- `production_telemetry_ingestion=false`.
- `network_send_enabled=false`.
- `runtime_pipeline_enabled=false`.
- `durable_write_enabled=false`.
- `nendb_write_enabled=false`.
- `after_report_digest` is present.
- `publication_changes`, `before_evidence`, and `after_evidence` are present.
- Source checks have no `fail` statuses.
- `blocked_claims`, `negative_fixtures`, and `required_verification_commands`
  are present.
- The source records every required application-boundary verification command.

Blocked or invalid source reports produce
`advisory_ci_report_publication_policy_status="blocked"` and
`ready_for_next_branch=false`.

## Decisions

### Approve

`approve` records that the interpretation policy is reviewed and ready. It
requires a valid applied source artifact and every required post-policy
verification command.

Output:

- `advisory_ci_report_publication_policy_status="ready"` when all checks pass.
- `ready_for_next_branch=true`.
- `mutation_authority="none"`.
- all publication, CI enforcement, workflow mutation, upload, live telemetry,
  durable, and NenDB flags remain false.

### Reject

`reject` records a reviewed stop. It always emits blocked policy status, even
when the source artifact is otherwise valid.

Output:

- `advisory_ci_report_publication_policy_status="blocked"`.
- `ready_for_next_branch=false`.
- `mutation_authority="none"`.

## Interpretation Rules

The policy artifact carries explicit allowed interpretation rules:

- `reviewer-triage-summary`: maintainers may inspect the advisory report as a
  non-blocking review aid.
- `agent-readonly-context`: agents may cite report ids, checks, denied claims,
  and next-query guidance.
- `non-blocking-ci-advisory`: CI may surface the report as advisory context
  only; failure effect is informational.
- `before-after-review-evidence`: reviewers may compare the source boundary,
  after-report digest, and verification commands.
- `future-readiness-input`: future readiness tools may use the policy artifact
  as an input to required-status-check readiness analysis.

The policy artifact carries denied inference rules:

- advisory reports are not required status checks
- advisory reports are not merge blockers
- advisory reports are not branch protection
- advisory reports are not workflow mutation proof
- advisory reports are not artifact upload execution proof
- advisory reports are not GitHub step-summary or PR-comment proof by this tool
- advisory reports are not production health proof
- advisory reports are not deployment success proof
- advisory reports are not capacity proof
- advisory reports are not customer impact proof
- advisory reports are not production cluster readiness proof
- advisory reports are not live telemetry coverage proof
- advisory reports are not durable write or NenDB write proof
- advisory reports do not grant mutation authority

## Policy Checks

The tool emits these checks:

- `source-schema`: source schema and version are supported.
- `source-applied`: source is `record-applied`, `applied=true`, and
  `report_application_status="applied"`.
- `source-record-only-authority`: source mutation authority is record-only and
  this policy grants no mutation authority.
- `source-publication-execution-disabled`: source preserves disabled report
  publication by the tool, CI upload execution, GitHub step-summary writes,
  and pull request comments.
- `source-ci-enforcement-disabled`: source preserves disabled CI gate
  enforcement, required checks, and workflow mutation.
- `source-runtime-and-storage-disabled`: source preserves disabled live
  telemetry, network send, runtime pipeline, durable writes, and NenDB writes.
- `source-application-evidence-present`: source has publication changes,
  before evidence, after evidence, and after-report digest.
- `source-checks-passed`: source checks have no `fail` status.
- `source-catalogs-present`: source blocked claims, negative fixtures, and
  verification catalogs are present.
- `decision-approved`: reviewer selected `approve`.
- `policy-verification-recorded`: every required post-policy verification
  command is present.
- `interpretation-rules-present`: allowed and denied interpretation catalogs
  are complete.

## Required Verification Commands

The policy requires these post-policy commands:

- `zig build causal-production-telemetry-ci-gate-advisory-ci-report-application-boundary`
- `zig build causal-artifacts`
- `zig build release-gate --summary none`
- `zig build release-gate-report`
- `zig build causal-schema-governance -- --format json`
- `zig build causal-production-hardening-backlog -- --format json`
- `zig build examples`
- `zig build test`

## Schema And Handoff

The tool emits
`zigeffect.causal.production-telemetry-ci-gate-advisory-ci-report-publication-policy.v1`.

Ready policy artifacts recommend:

- recommendation:
  `start-production-telemetry-ci-gate-required-status-check-readiness`
- next branch:
  `codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-readiness`

That future branch may evaluate readiness for required status check semantics,
but it must still be a readiness/evidence branch, not enforcement.

## Testing

Focused tests should cover:

- constants and branch handoff strings
- CLI parsing for approval and rejection
- default output path replacement and long-name compaction
- approved source produces ready policy
- rejected decision blocks policy
- planned source blocks policy
- blocked source blocks policy
- source authority or publication execution flags block policy
- missing verification commands block policy
- interpretation catalogs include required allowed and denied rules

Full verification should run:

```sh
cd packages/zigeffect
zig test tools/causal_production_telemetry_ci_gate_advisory_ci_report_publication_policy.zig
zig build causal-production-telemetry-ci-gate-advisory-ci-report-publication-policy -- --help
zig build causal-schema-governance -- --format json
zig build causal-production-hardening-backlog -- --format json
zig build examples
zig build test
cd ../..
bun run check
bun run zig:test
git diff --check
```
