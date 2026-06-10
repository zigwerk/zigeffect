# zigeffect Causal Production Telemetry CI Gate Required Status Check Enforcement Application Boundary Design

## Summary

Create `causal-production-telemetry-ci-gate-required-status-check-enforcement-application-boundary`,
a guarded, record-only application-boundary tool that consumes
`zigeffect.causal.production-telemetry-ci-gate-required-status-check-enforcement-readiness.v1`
artifacts and records either planned enforcement application work or reviewed
external evidence that required-status-check enforcement has been applied.

This branch is the first required-status-check milestone allowed to record an
externally active enforcement state. It still does not create GitHub required
checks, update branch protection, mutate workflows, create check runs, call
GitHub APIs, upload CI artifacts, write GitHub step summaries, post pull
request comments, ingest live telemetry, call networks, configure collectors,
serialize OTLP, write durable production storage, write NenDB, claim
production health, claim deployment success, claim customer impact, claim
production cluster readiness, add non-NenDB durable adapter scope, add
alternate renderer scope, or grant mutation authority.

`record-applied` means a reviewed external update has evidence. It does not
mean this tool performed the update.

## Goals

- Consume ready enforcement-readiness artifacts.
- Support `plan` and `record-applied` modes.
- Emit `required_status_check_enforcement_application_status` as `planned`,
  `applied`, or `blocked`.
- Keep `applied=false` for planned and blocked records.
- Set `applied=true` only when source readiness is ready, reviewer mode is
  `record-applied`, and every required external enforcement evidence gate
  passes.
- Record externally active required-status-check evidence without claiming
  GitHub mutation by this tool.
- Preserve clear fields for `active_enforcement_recorded`,
  `merge_blocking_recorded`, `active_enforcement_claim_allowed`, and
  `merge_blocker_claim_allowed`.
- Require required check names, branch-protection before and after evidence,
  workflow or check-run evidence, failure-mode evidence, owner approval,
  rollback evidence, and post-application verification.
- Reject unsafe evidence that contains secrets, mutation-by-tool claims, live
  telemetry claims, durable writes, NenDB writes, production health, deployment
  success, customer impact, production cluster readiness, non-NenDB durable
  adapter claims, or alternate renderer scope.
- Emit deterministic JSON and text artifacts with checks, evidence catalogs,
  denied inference rules, negative fixtures, blocked claims, required
  verification commands, and next-branch guidance.
- Preserve the current user constraints: NenDB adapter direction only, no
  Cockroach work in this milestone, and future workbench direction through
  SolidJS inside `webui-dev/zig-webui`.
- Hand off ready applied artifacts to a future required-status-check
  enforcement policy branch.

## Non-Goals

- No GitHub branch-protection mutation by this tool.
- No workflow mutation by this tool.
- No check-run creation by this tool.
- No GitHub API calls by this tool.
- No CI artifact upload execution.
- No GitHub step-summary writes or pull request comments.
- No live telemetry, runtime pipeline execution, network send, collector
  configuration, or OTLP serialization.
- No durable writes and no NenDB writes.
- No production health, deployment success, capacity, customer impact, or
  production cluster readiness claims.
- No Cockroach, non-NenDB durable adapter, React, or alternate frontend
  renderer work.
- No source, workflow, GitHub, CI, deployment, storage, or production mutation
  authority.

## Current Context

The previous branch delivered
`causal-production-telemetry-ci-gate-required-status-check-enforcement-readiness`.
That tool consumes required-status-check policy artifacts and only becomes
ready when the source policy is externally applied and explicit evidence exists
for required check names, branch-protection state, workflow or check-run state,
failure behavior, owner approval, rollback, and verification commands.

The enforcement-readiness artifact deliberately keeps:

- `active_enforcement_claim_allowed=false`;
- `merge_blocker_claim_allowed=false`;
- every tool-side GitHub, branch-protection, workflow, check-run, CI upload,
  live telemetry, durable, and NenDB authority disabled;
- `mutation_authority="none"`.

This branch consumes that readiness evidence and records the next boundary:
planned enforcement application or reviewed external application. It follows
the existing application-boundary pattern used by CI archive application,
CI-gate application boundary, advisory CI report application boundary, and
required-status-check application boundary.

## Design Options Considered

### Option A: Direct GitHub Applicator

Build a tool that calls GitHub APIs, updates branch protection, writes
workflows, or creates check runs. This is rejected because it requires network
credentials and would collapse a record-only governance chain into a mutating
operator.

### Option B: Readiness-Only Extension

Extend enforcement-readiness with more evidence fields. This is safe, but it
blurs two separate questions: "Do we have enough evidence to prepare
application?" and "Was the external application actually reviewed and
recorded?"

### Option C: Guarded Plan-Or-Record-Applied Boundary

Add a new record-only application-boundary artifact. `plan` records intended
work. `record-applied` records reviewed external enforcement evidence and sets
`applied=true` only after every source, evidence, and verification gate passes.

Chosen approach: Option C.

## Artifact Contract

The tool emits schema:

`zigeffect.causal.production-telemetry-ci-gate-required-status-check-enforcement-application-boundary.v1`

The build step is:

`causal-production-telemetry-ci-gate-required-status-check-enforcement-application-boundary`

The source branch is:

`codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-enforcement-application-boundary`

The recommendation after an applied artifact should be:

`start-production-telemetry-ci-gate-required-status-check-enforcement-policy`

The next branch should be:

`codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-enforcement-policy`

The emitted artifact must include:

- source enforcement-readiness path, schema, decision, status, ready flag, and
  source applied flag;
- `mode="plan" | "record-applied"`;
- `required_status_check_enforcement_application_status="planned" | "applied" | "blocked"`;
- `applied=false` for plan or blocked records;
- `applied=true` only for passing `record-applied`;
- `active_enforcement_recorded=false` for plan or blocked records;
- `active_enforcement_recorded=true` only for passing `record-applied`;
- `merge_blocking_recorded=false` for plan or blocked records;
- `merge_blocking_recorded=true` only when passing `record-applied` includes
  explicit merge-blocking evidence;
- `active_enforcement_claim_allowed=false` for plan or blocked records;
- `active_enforcement_claim_allowed=true` only for passing `record-applied`;
- `merge_blocker_claim_allowed=false` for plan or blocked records;
- `merge_blocker_claim_allowed=true` only for passing `record-applied` with
  merge-blocking evidence;
- `mutation_authority="none"`;
- required check names;
- branch-protection before and after evidence;
- workflow or check-run evidence;
- failure-mode evidence;
- owner approval;
- rollback evidence;
- required verification commands;
- verified commands;
- denied inference rules;
- negative fixtures;
- agent guidance.

## CLI

```sh
zig build causal-production-telemetry-ci-gate-required-status-check-enforcement-application-boundary -- \
  --from-readiness <required-status-check-enforcement-readiness.json> \
  plan|record-applied \
  --reason <reason> \
  [--by <actor>] \
  [--policy <policy>] \
  [--required-check-name <name>]... \
  [--branch-protection-before <path-or-summary>]... \
  [--branch-protection-after <path-or-summary>]... \
  [--workflow-evidence <path-or-summary>]... \
  [--check-run-evidence <path-or-summary>]... \
  [--failure-mode-evidence <path-or-summary>]... \
  [--owner-approval <path-or-summary>]... \
  [--rollback-evidence <path-or-summary>]... \
  [--merge-blocking-evidence <path-or-summary>]... \
  [--verified-command <command>]... \
  [--out-prefix <path-prefix>]
```

Defaults:

- `--by` defaults to
  `ci-gate-required-status-check-enforcement-application-boundary-reviewer`.
- `--policy` defaults to
  `manual-production-telemetry-ci-gate-required-status-check-enforcement-application-boundary`.

Default output path replacement:

- `*-required-status-check-enforcement-readiness.json` becomes
  `*-required-status-check-enforcement-application-boundary.json`.
- `foo.json` becomes
  `foo-ci-gate-required-status-check-enforcement-application-boundary.json`.

## Source Readiness Contract

The source artifact is valid when:

- `schema` is
  `zigeffect.causal.production-telemetry-ci-gate-required-status-check-enforcement-readiness.v1`.
- `schema_version` is `1`.
- `decision` is `approve`.
- `enforcement_readiness_status` is `ready`.
- `ready_for_next_branch=true`.
- `source_applied=true`.
- `active_enforcement_claim_allowed=false`.
- `merge_blocker_claim_allowed=false`.
- `mutation_authority="none"`.
- source authority booleans remain disabled:
  `ci_gate_enabled`, `ci_gate_enforcement_enabled`,
  `ci_required_status_check_enabled`, `ci_workflow_mutation_enabled`,
  `ci_upload_execution_enabled`, `ci_report_publication_enabled`,
  `github_api_mutation_enabled`, `github_check_run_creation_enabled`,
  `branch_protection_mutation_by_tool_enabled`,
  `github_step_summary_write_enabled`, `pull_request_comment_enabled`,
  `production_telemetry_ingestion`, `live_exporter_enabled`,
  `network_send_enabled`, `collector_endpoint_configured`,
  `otlp_serialization_enabled`, `runtime_pipeline_enabled`,
  `durable_write_enabled`, and `nendb_write_enabled`.
- source checks contain no `fail` statuses.
- source required check names and evidence arrays are present.
- source denied inference rules, negative fixtures, blocked claims, required
  verification commands, and verified commands are present.
- every source required verification command is recorded.

Blocked or invalid source artifacts emit
`required_status_check_enforcement_application_status="blocked"`.

## Mode Semantics

### `plan`

`plan` records that enforcement application work is planned from ready source
evidence.

Required checks:

- source readiness checks pass;
- mode is `plan`;
- reason is present.

Output:

- `required_status_check_enforcement_application_status="planned"`;
- `applied=false`;
- `active_enforcement_recorded=false`;
- `merge_blocking_recorded=false`;
- `active_enforcement_claim_allowed=false`;
- `merge_blocker_claim_allowed=false`;
- `mutation_authority="none"`.

### `record-applied`

`record-applied` records that a separately reviewed external enforcement
application occurred. It sets active enforcement fields only when all evidence
gates pass.

Required checks:

- source readiness checks pass;
- mode is `record-applied`;
- at least one required check name is present;
- branch-protection before evidence is present;
- branch-protection after evidence is present;
- workflow or check-run evidence is present;
- failure-mode evidence is present;
- owner approval is present;
- rollback evidence is present;
- post-application verification contains every required command;
- evidence is safe and contains no denied markers;
- merge-blocking evidence is present if `merge_blocker_claim_allowed=true`.

Output when every check passes:

- `required_status_check_enforcement_application_status="applied"`;
- `applied=true`;
- `active_enforcement_recorded=true`;
- `active_enforcement_claim_allowed=true`;
- `merge_blocking_recorded=true` only when merge-blocking evidence is present;
- `merge_blocker_claim_allowed=true` only when merge-blocking evidence is
  present;
- `mutation_authority="none"`;
- all tool-side mutation booleans remain false.

## Required Post-Application Verification

`record-applied` requires:

- `zig build causal-production-telemetry-ci-gate-required-status-check-enforcement-readiness`
- `zig build causal-artifacts`
- `zig build release-gate --summary none`
- `zig build release-gate-report`
- `zig build causal-schema-governance -- --format json`
- `zig build causal-production-hardening-backlog -- --format json`
- `zig build examples`
- `zig build test`

## Denied Evidence

Evidence is unsafe if it contains:

- secret-shaped values such as `secret=`, `token=`, `password=`, `ghp_`,
  `sk-`, or `BEGIN PRIVATE KEY`;
- claims that this tool performed GitHub API mutation, branch-protection
  mutation, workflow mutation, check-run creation, CI upload execution, GitHub
  step-summary writes, or pull-request comment writes;
- live telemetry, collector endpoint, OTLP send, or runtime pipeline claims;
- durable writes or NenDB writes;
- non-NenDB durable adapter scope;
- production health, deployment success, customer impact, capacity, or
  production cluster readiness claims;
- alternate renderer scope such as React workbench replacement.

## Denied Inferences

The output must explicitly deny:

- applied enforcement evidence is GitHub mutation by this tool;
- applied enforcement evidence is branch-protection mutation by this tool;
- applied enforcement evidence is workflow mutation by this tool;
- applied enforcement evidence is check-run creation by this tool;
- applied enforcement evidence is CI upload execution by this tool;
- applied enforcement evidence is GitHub step-summary or PR comment write by
  this tool;
- active required-check evidence proves production health;
- active required-check evidence proves deployment success;
- active required-check evidence proves customer impact;
- active required-check evidence proves production cluster readiness;
- active required-check evidence proves live telemetry coverage;
- active required-check evidence proves durable or NenDB writes;
- applied evidence grants mutation authority.

## Negative Fixtures

The tool tests and artifact must include fixtures for:

- blocked source readiness denied;
- planned source readiness denied;
- source active-claim fields already true denied;
- `record-applied` without required check names denied;
- `record-applied` without branch-protection before evidence denied;
- `record-applied` without branch-protection after evidence denied;
- `record-applied` without workflow or check-run evidence denied;
- `record-applied` without failure-mode evidence denied;
- `record-applied` without owner approval denied;
- `record-applied` without rollback evidence denied;
- `record-applied` without verification denied;
- merge-blocking claim without merge-blocking evidence denied;
- GitHub mutation by tool evidence denied;
- workflow mutation by tool evidence denied;
- check-run creation by tool evidence denied;
- CI upload execution evidence denied;
- secret-shaped evidence denied;
- live telemetry evidence denied;
- durable write denied;
- NenDB write denied;
- non-NenDB durable adapter denied;
- alternate renderer denied.

## Agent Guidance

Planned artifacts tell agents:

- enforcement application is not active;
- use the artifact to prepare external review work only;
- do not claim merge blocking or required-check enforcement.

Applied artifacts tell agents:

- required-status-check enforcement was recorded from reviewed external
  evidence;
- cite evidence ids and checks when describing active enforcement;
- do not claim zigeffect mutated GitHub, workflows, branch protection, check
  runs, CI uploads, telemetry, storage, or runtime state;
- do not claim production health, deployment success, customer impact, or
  cluster readiness.

Blocked artifacts tell agents:

- stop before enforcement policy work;
- inspect failed checks and missing evidence;
- return to enforcement-readiness or external review evidence collection as
  needed.

## Implementation Scope

Create:

- `packages/zigeffect/tools/causal_production_telemetry_ci_gate_required_status_check_enforcement_application_boundary.zig`
- `packages/zigeffect/docs/production-telemetry-ci-gate-required-status-check-enforcement-application-boundary.md`

Modify:

- `packages/zigeffect/build.zig`
- `packages/zigeffect/tools/causal_schema_governance.zig`
- `packages/zigeffect/tools/causal_production_hardening_backlog.zig`
- `packages/zigeffect/docs/schema-governance.md`
- `packages/zigeffect/docs/production-hardening-backlog.md`
- `packages/zigeffect/README.md`
- `packages/zigeffect/docs/operations.md`
- `packages/zigeffect/docs/roadmap.md`
- `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`
- adjacent current-next docs that still name this branch.

## Testing

Focused tests in the new Zig tool should cover:

- constants and default CLI values;
- option parsing for `plan`, `record-applied`, all evidence flags, and output
  prefix;
- implicit output path replacement;
- planned application from ready source emits planned status and keeps active
  claims false;
- applied application from ready source plus complete evidence emits applied
  status and records active enforcement;
- applied application with merge-blocking evidence allows merge-blocker claim;
- blocked source readiness emits blocked status;
- missing required check names, before evidence, after evidence, workflow or
  check-run evidence, failure-mode evidence, owner approval, rollback evidence,
  or verification blocks applied status;
- unsafe evidence blocks applied status;
- denied inference, negative fixture, blocked claim, and evidence requirement
  catalogs are emitted.

Build-level verification should run:

```sh
cd packages/zigeffect
zig test tools/causal_production_telemetry_ci_gate_required_status_check_enforcement_application_boundary.zig
zig build causal-production-telemetry-ci-gate-required-status-check-enforcement-application-boundary -- --help
zig build causal-production-telemetry-ci-gate-required-status-check-enforcement-application-boundary -- \
  --from-readiness ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-enforcement-readiness.json \
  plan \
  --reason "required status check enforcement application boundary planned"
zig build causal-production-telemetry-ci-gate-required-status-check-enforcement-application-boundary -- \
  --from-readiness ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-enforcement-readiness-negative.json \
  record-applied \
  --reason "negative required status check enforcement application boundary path" \
  --out-prefix ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-enforcement-application-boundary-negative
zig build causal-schema-governance -- --format json
zig build causal-production-hardening-backlog -- --format json
zig build examples
zig build test
cd ../..
bun run check
bun run zig:test
git diff --check
```

When the local enforcement-readiness artifact is blocked because the policy
source is planned, the `plan` command above should intentionally emit blocked
application status. A ready source fixture in unit tests proves the positive
planned and applied paths.

## Documentation

Docs should explain:

- the tool records external application evidence only;
- `record-applied` does not mean mutation by this tool;
- active enforcement claims are allowed only by applied records with reviewed
  evidence;
- merge-blocker claims are allowed only with explicit merge-blocking evidence;
- denied inferences and negative fixtures remain part of the artifact;
- the next branch is the required-status-check enforcement policy branch.

## Spec Self-Review

- Placeholder scan: no placeholder sections or deferred requirements remain.
- Consistency check: the design permits externally applied active enforcement
  records while keeping every mutation-by-tool claim denied.
- Scope check: this is one bounded artifact/tool/docs/schema/backlog
  milestone.
- Ambiguity check: `plan` never allows active claims; `record-applied` can
  allow active and merge-blocker claims only from complete reviewed external
  evidence, not from tool-side mutation.
