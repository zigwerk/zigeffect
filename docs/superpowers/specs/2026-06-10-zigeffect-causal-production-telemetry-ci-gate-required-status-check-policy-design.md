# zigeffect Causal Production Telemetry CI Gate Required Status Check Policy Design

## Summary

Create `causal-production-telemetry-ci-gate-required-status-check-policy`, a
guarded, record-only policy tool that consumes
`zigeffect.causal.production-telemetry-ci-gate-required-status-check-application-boundary.v1`
artifacts and defines how humans, agents, and future enforcement-readiness
tools may interpret required-status-check application evidence.

This branch approves interpretation policy only. It does not create GitHub
required checks, update branch protection, mutate workflows, create check runs,
call GitHub APIs, upload CI artifacts, write GitHub step summaries, post pull
request comments, enable CI gate enforcement, ingest live telemetry, call
networks, configure collectors, serialize OTLP, write durable production
storage, write NenDB, claim production health, claim deployment success, claim
cluster readiness, add non-NenDB durable adapter scope, add alternate renderer
scope, or grant mutation authority.

## Goals

- Consume planned or applied required-status-check application-boundary
  artifacts.
- Preserve the difference between `source_applied=false` planned records and
  `source_applied=true` externally applied records.
- Reject blocked, malformed, mutation-authority-bearing, or unsafe source
  artifacts.
- Emit deterministic JSON and text artifacts with policy status, source checks,
  source application mode, interpretation rules, denied inference rules,
  required-check surface policy, negative fixtures, required verification
  commands, and next-branch guidance.
- Let agents reason about required-status-check governance without assuming the
  tool mutated GitHub or that a merge-blocking branch protection rule is active.
- Preserve the platform constraints already chosen for this roadmap: NenDB
  adapter direction only, no Cockroach work in this milestone, and future
  workbench direction through SolidJS inside `webui-dev/zig-webui`.
- Hand off ready policy artifacts only to a future required-status-check
  enforcement-readiness branch.

## Non-Goals

- No GitHub branch-protection mutation by this tool.
- No workflow mutation by this tool.
- No check-run creation by this tool.
- No GitHub API calls by this tool.
- No required status check activation by this tool.
- No CI pass/fail or merge-blocking enforcement.
- No CI artifact upload execution.
- No GitHub step-summary writes or pull request comments.
- No live telemetry, runtime pipeline execution, network send, collector
  configuration, or OTLP serialization.
- No durable writes and no NenDB writes.
- No production health, deployment success, capacity, customer impact, or
  production cluster readiness claims.
- No Cockroach, non-NenDB durable adapter, React, or alternate frontend
  renderer work.
- No mutation authority. Policy readiness is record-only evidence.

## Current Context

The active branch was synced against local `master` before this design was
written. Git reported `master` is already an ancestor of the current causal
branch, and `codex/roachgraph-roadmap-completion` is also already an ancestor,
so the policy work starts from the latest local master and clustering workflow
lineage available in this checkout.

The previous branch delivered
`causal-production-telemetry-ci-gate-required-status-check-application-boundary`.
That tool consumes ready required-status-check readiness artifacts and emits a
planned or externally applied boundary record:

- `plan` emits
  `required_status_check_application_status="planned"`,
  `applied=false`, and `mutation_authority="none"`.
- `record-applied` emits
  `required_status_check_application_status="applied"` and `applied=true` only
  when separately reviewed branch-protection, workflow, or check-run evidence
  includes before/after verification and all required post-application commands.
- blocked source evidence or missing application evidence emits
  `required_status_check_application_status="blocked"` and `applied=false`.

Existing policy tools establish the local pattern:

- `causal-production-telemetry-ci-gate-dry-run-policy` accepts planned or
  applied gate application-boundary artifacts and defines advisory dry-run
  interpretation rules.
- `causal-production-telemetry-ci-gate-advisory-ci-report-publication-policy`
  accepts applied advisory report application-boundary artifacts and defines
  publication interpretation rules.
- Both tools emit ready or blocked policy artifacts, keep all authority fields
  disabled, include explicit denied inference catalogs, and hand off to the
  next branch only through record-only evidence.

## Design Options Considered

### Option A: Direct Required Check Applicator

Build a tool that edits GitHub branch protection, workflows, or check-run
configuration. This is not acceptable for this milestone because it would cross
the record-only boundary, require network credentials, and collapse policy
review into mutation authority.

### Option B: Applied-Only Policy

Accept only `record-applied` source artifacts. This is stricter, but it would
block local development of the policy chain until a reviewed external GitHub
change exists. It would also make planned application-boundary records less
useful for agent reasoning while the system is still being assembled.

### Option C: Planned-Or-Applied Interpretation Policy

Accept both planned and applied application-boundary records, but expose
`source_applied` and restrict allowed interpretations based on that value. A
planned source may only be used to design the next readiness step. An applied
source may be used as reviewed external evidence that a required-status-check
application was recorded, but still cannot prove mutation by this tool,
production health, deployment success, or cluster readiness.

Chosen approach: Option C.

## CLI

```sh
zig build causal-production-telemetry-ci-gate-required-status-check-policy -- \
  --from-application-boundary <required-status-check-application-boundary.json> \
  approve|reject \
  --reason <reason>
```

Optional flags:

- `--by <actor>`: reviewer or agent id. Defaults to
  `required-status-check-policy-reviewer`.
- `--policy <policy>`: policy id. Defaults to
  `manual-production-telemetry-ci-gate-required-status-check-policy`.
- `--verified-command <command>`: post-policy verification evidence.
- `--out-prefix <path-prefix>`: override output paths.

Default output path replacement:

- `*-required-status-check-application-boundary.json` becomes
  `*-required-status-check-policy.json`.
- Deeply chained implicit output names should be compacted to a deterministic
  filesystem-safe prefix with a short source-path digest.

## Source Application Boundary Contract

The source artifact is policy-ready when:

- `schema` is
  `zigeffect.causal.production-telemetry-ci-gate-required-status-check-application-boundary.v1`.
- `schema_version` is `1`.
- `mode` is `plan` or `record-applied`.
- `required_status_check_application_status` is `planned` or `applied`.
- `required_status_check_application_status="planned"` implies
  `applied=false` and `mutation_authority="none"`.
- `required_status_check_application_status="applied"` implies
  `applied=true` and `mutation_authority="record-only"`.
- `ci_gate_enabled=false`.
- `ci_gate_enforcement_enabled=false`.
- `ci_required_status_check_enabled=false`.
- `ci_workflow_mutation_enabled=false`.
- `ci_upload_execution_enabled=false`.
- `ci_report_publication_enabled=false`.
- `github_api_mutation_enabled=false`.
- `github_check_run_creation_enabled=false`.
- `branch_protection_mutation_by_tool_enabled=false`.
- `github_step_summary_write_enabled=false`.
- `pull_request_comment_enabled=false`.
- `production_telemetry_ingestion=false`.
- `live_exporter_enabled=false`.
- `network_send_enabled=false`.
- `collector_endpoint_configured=false`.
- `otlp_serialization_enabled=false`.
- `runtime_pipeline_enabled=false`.
- `durable_write_enabled=false`.
- `nendb_write_enabled=false`.
- source checks have no `fail` statuses.
- `source_required_status_check_profiles`, `application_checks`,
  `denied_inference_rules`, `negative_fixtures`, `blocked_claims`, and
  `required_verification_commands` are present.
- applied source artifacts include reviewed branch-protection evidence,
  before evidence, after evidence, and workflow or check-run evidence.
- every required application-boundary verification command is recorded.

Blocked or invalid source reports produce
`required_status_check_policy_status="blocked"` and
`ready_for_next_branch=false`.

## Decisions

### Approve

`approve` records that the interpretation policy is reviewed and ready. It
requires a valid planned or applied source artifact and every required
post-policy verification command.

Output:

- `required_status_check_policy_status="ready"` when all checks pass.
- `ready_for_next_branch=true`.
- `source_applied=false` for planned sources.
- `source_applied=true` for externally applied sources.
- `mutation_authority="none"`.
- all CI enforcement, required-check, branch-protection mutation, workflow
  mutation, GitHub API mutation, check-run creation, publication, upload,
  live telemetry, durable, and NenDB flags remain false.

### Reject

`reject` records a reviewed stop. It always emits blocked policy status, even
when the source artifact is otherwise valid.

Output:

- `required_status_check_policy_status="blocked"`.
- `ready_for_next_branch=false`.
- `mutation_authority="none"`.

## Interpretation Rules

The policy artifact carries explicit allowed interpretation rules:

- `planned-policy-design-input`: planned boundary records may inform the next
  enforcement-readiness design only.
- `applied-evidence-review-input`: applied boundary records may be cited as
  reviewed external evidence of required-status-check application work.
- `agent-readonly-context`: agents may cite source ids, profiles, checks,
  denied claims, and next-query guidance.
- `before-after-review-evidence`: reviewers may compare source change evidence,
  before evidence, after evidence, and verification commands.
- `future-enforcement-readiness-input`: future readiness tools may use the
  policy artifact as input to evaluate whether required status checks can
  become a real protected-branch requirement.

The policy artifact carries denied inference rules:

- planned policy records are not active required status checks.
- applied source records are external evidence records, not proof that this
  tool mutated GitHub.
- policy readiness is not branch protection mutation.
- policy readiness is not workflow mutation.
- policy readiness is not check-run creation.
- policy readiness is not GitHub API mutation.
- policy readiness is not CI artifact upload execution.
- policy readiness is not GitHub step-summary or PR-comment proof by this tool.
- policy readiness is not production health proof.
- policy readiness is not deployment success proof.
- policy readiness is not capacity proof.
- policy readiness is not customer impact proof.
- policy readiness is not production cluster readiness proof.
- policy readiness is not live telemetry coverage proof.
- policy readiness is not durable write or NenDB write proof.
- policy readiness does not grant mutation authority.

## Required-Check Surface Policy

The policy emits required-check surface entries with:

- `surface="branch-protection-required-status-check"`;
- `source_state="planned"` or `source_state="applied"`;
- `source_applied=false` or `source_applied=true`;
- `allowed_use` describing whether the surface is only design input or reviewed
  external evidence;
- `failure_effect="none"` for planned sources;
- `failure_effect="external-record-only"` for applied sources;
- `tool_mutation_enabled=false`;
- `merge_blocker_claim_allowed=false`.

`merge_blocker_claim_allowed` remains false in this milestone because even an
applied source only records reviewed external evidence. A later
enforcement-readiness branch may decide what additional GitHub and CI evidence
is required before agents may describe a check as an active merge blocker.

## Policy Checks

The tool emits these checks:

- `source-schema`: source schema and version are supported.
- `source-boundary-status-valid`: source status is planned or applied, not
  blocked.
- `source-application-state-consistent`: planned sources are non-applied with
  no mutation authority, and applied sources are applied with record-only
  authority.
- `source-tool-authority-disabled`: source preserves disabled GitHub API,
  branch-protection mutation, workflow mutation, check-run creation, CI upload,
  step-summary, and pull-request comment authority.
- `source-ci-enforcement-disabled`: source preserves disabled CI gate
  enforcement and required-check authority by the tool.
- `source-runtime-and-storage-disabled`: source preserves disabled live
  telemetry, network send, collector, OTLP, runtime pipeline, durable writes,
  and NenDB writes.
- `source-checks-passed`: source application checks have no `fail` status.
- `source-catalogs-present`: source blocked claims, denied inference rules,
  negative fixtures, profiles, and verification catalogs are present.
- `source-applied-evidence-present`: applied sources include branch-protection,
  before, after, and workflow or check-run evidence.
- `decision-approved`: reviewer selected `approve`.
- `policy-verification-recorded`: every required post-policy verification
  command is present.
- `interpretation-rules-present`: allowed and denied interpretation catalogs
  are complete.
- `required-check-surface-policy-present`: required-check surface entries are
  present and keep merge-blocking claims disabled.

## Required Verification Commands

The policy requires these post-policy commands:

- `zig build causal-production-telemetry-ci-gate-required-status-check-application-boundary`
- `zig build causal-artifacts`
- `zig build release-gate --summary none`
- `zig build release-gate-report`
- `zig build causal-schema-governance -- --format json`
- `zig build causal-production-hardening-backlog -- --format json`
- `zig build examples`
- `zig build test`

## Schema And Handoff

The tool emits:

`zigeffect.causal.production-telemetry-ci-gate-required-status-check-policy.v1`

Ready policy artifacts recommend:

- recommendation:
  `start-production-telemetry-ci-gate-required-status-check-enforcement-readiness`
- next branch:
  `codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-enforcement-readiness`

That next branch should decide what additional externally verifiable GitHub,
branch-protection, workflow, and CI evidence is required before an agent may
describe a required status check as active enforcement. It must still avoid
tool-side GitHub mutation, workflow mutation, live telemetry, durable writes,
NenDB writes, production cluster claims, and mutation authority unless a later
reviewed milestone explicitly changes that boundary.

## Documentation And Registry Updates

Implementation must update:

- `packages/zigeffect/tools/causal_production_telemetry_ci_gate_required_status_check_policy.zig`
- `packages/zigeffect/build.zig`
- `packages/zigeffect/tools/causal_schema_governance.zig`
- `packages/zigeffect/tools/causal_production_hardening_backlog.zig`
- `packages/zigeffect/docs/production-telemetry-ci-gate-required-status-check-policy.md`
- roadmap and backlog docs that mention the current recommended branch.

Schema governance should increase the schema count from `71` to `72` and
register compatibility tags including `required-status-check-policy`,
`interpretation-policy`, `planned-or-applied-source`, `branch-protection-evidence`,
`no-tool-github-api-mutation`, `no-tool-branch-protection-mutation`,
`no-tool-workflow-mutation`, `no-tool-ci-upload`, `no-live-ingestion`,
`no-durable-write`, and `no-nendb-write`.

## Testing

Use TDD for implementation. The first red test should assert the new schema
constant, recommendation, and next branch constants before the tool exists.

The implementation test suite should include:

- constants and branch handoff tests;
- option parsing tests for approve, reject, missing source, invalid source
  extension, missing reason, repeated verified commands, and out-prefix;
- ready planned-source policy report test;
- ready applied-source policy report test using a compact fixture;
- rejected policy report test;
- blocked source boundary test;
- unsafe source authority test;
- missing verification command test;
- missing applied evidence test;
- output path replacement test;
- JSON and text renderer tests for `source_applied`, denied inference rules,
  required-check surface policy, and next branch.

Build-level verification should run:

```sh
cd packages/zigeffect
zig test tools/causal_production_telemetry_ci_gate_required_status_check_policy.zig
zig build causal-production-telemetry-ci-gate-required-status-check-policy -- --help
zig build causal-production-telemetry-ci-gate-required-status-check-policy -- \
  --from-application-boundary ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-application-boundary.json \
  approve \
  --reason "required status check policy reviewed" \
  --verified-command "zig build causal-production-telemetry-ci-gate-required-status-check-application-boundary" \
  --verified-command "zig build causal-artifacts" \
  --verified-command "zig build release-gate --summary none" \
  --verified-command "zig build release-gate-report" \
  --verified-command "zig build causal-schema-governance -- --format json" \
  --verified-command "zig build causal-production-hardening-backlog -- --format json" \
  --verified-command "zig build examples" \
  --verified-command "zig build test"
zig build causal-production-telemetry-ci-gate-required-status-check-policy -- \
  --from-application-boundary ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-application-boundary-negative.json \
  reject \
  --reason "negative required status check policy path" \
  --out-prefix ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-policy-negative
zig build causal-schema-governance -- --format json
zig build causal-production-hardening-backlog -- --format json
zig build examples
zig build test
cd ../..
bun run check
bun run zig:test
git diff --check
```
