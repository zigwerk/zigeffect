# zigeffect Causal Production Telemetry CI Gate Required Status Check Enforcement Readiness Design

## Summary

Create `causal-production-telemetry-ci-gate-required-status-check-enforcement-readiness`,
a guarded, record-only readiness tool that consumes
`zigeffect.causal.production-telemetry-ci-gate-required-status-check-policy.v1`
artifacts and determines whether the project has enough reviewed evidence to
start a future required-status-check enforcement application-boundary branch.

This branch does not create GitHub required checks, update branch protection,
mutate workflows, create check runs, call GitHub APIs, upload CI artifacts,
write GitHub step summaries, post pull request comments, enable merge blocking,
ingest live telemetry, call networks, configure collectors, serialize OTLP,
write durable production storage, write NenDB, claim production health, claim
deployment success, claim customer impact, claim production cluster readiness,
add non-NenDB durable adapter scope, add alternate renderer scope, or grant
mutation authority.

`enforcement_readiness_status="ready"` means only that a future guarded
application-boundary branch may be prepared from reviewed evidence. It does
not mean a required status check is active, that a merge is blocked, or that
GitHub branch protection has been changed by zigeffect.

## Goals

- Consume ready required-status-check policy artifacts.
- Preserve the distinction between planned policy sources and externally
  applied policy sources.
- Keep planned policy sources useful for diagnostics while blocking active
  enforcement-readiness claims.
- Require externally applied source evidence before readiness can become
  `ready`.
- Require explicit branch-protection evidence, required check names,
  workflow or check-run evidence, failure-mode evidence, owner approval,
  rollback evidence, and verification command evidence.
- Emit deterministic JSON and text artifacts with readiness status, source
  policy checks, enforcement evidence checks, active-claim boundaries, denied
  inference rules, negative fixtures, required verification commands, and
  next-branch guidance.
- Give agents a precise answer to: "Can I prepare the enforcement
  application-boundary work?" without letting them claim: "GitHub is already
  enforcing this."
- Preserve the user constraints already selected for the roadmap: NenDB
  adapter direction only, no Cockroach work in this milestone, and future
  workbench direction through SolidJS inside `webui-dev/zig-webui`.
- Hand off only ready artifacts to a future required-status-check enforcement
  application-boundary branch.

## Non-Goals

- No GitHub branch-protection mutation by this tool.
- No workflow mutation by this tool.
- No check-run creation by this tool.
- No GitHub API calls by this tool.
- No required status check activation by this tool.
- No active merge-blocking claim.
- No CI artifact upload execution.
- No GitHub step-summary writes or pull request comments.
- No live telemetry, runtime pipeline execution, network send, collector
  configuration, or OTLP serialization.
- No durable writes and no NenDB writes.
- No production health, deployment success, capacity, customer impact, or
  production cluster readiness claims.
- No Cockroach, non-NenDB durable adapter, React, or alternate frontend
  renderer work.
- No mutation authority. Readiness is evidence for a later review branch, not
  permission to mutate infrastructure.

## Current Context

The active branch was created after merging local `master` into the causal
roadmap line. Git confirmed `master` is an ancestor of the required-status-check
policy branch before this enforcement-readiness branch was created. No remote
is configured in this checkout, so this context means "latest local master",
not a fresh GitHub fetch.

The previous branch delivered
`causal-production-telemetry-ci-gate-required-status-check-policy`. That tool
consumes planned or externally applied required-status-check
application-boundary artifacts and emits record-only interpretation policy:

- planned source policy emits `source_applied=false` and may only be used for
  enforcement-readiness design;
- applied source policy emits `source_applied=true` and may be cited as
  reviewed external evidence;
- both paths keep `merge_blocker_claim_allowed=false`;
- both paths keep every GitHub, workflow, check-run, CI upload, live telemetry,
  durable, and NenDB authority field disabled.

The new branch must sit one layer after that policy: it validates whether the
evidence is strong enough to begin a future enforcement application-boundary
review while still refusing to claim active enforcement.

## Design Options Considered

### Option A: Direct Enforcement Activator

Build a tool that edits GitHub branch protection or workflow configuration and
marks the required status check active. This is rejected because it crosses the
record-only boundary, needs credentials and network mutation, and would make a
local zigeffect tool the authority for repository protection state.

### Option B: Applied-Only Parser

Reject planned policy artifacts at parse time and only accept applied policy
sources. This is safe, but it gives agents a poor diagnostic path while the
chain is still being built locally. Planned sources should produce a clear
blocked artifact that explains what evidence is missing.

### Option C: Dual-Lane Evidence Readiness

Accept both planned and applied policy artifacts, but make readiness conditional
on `source_applied=true` plus additional explicit enforcement evidence. Planned
sources emit `enforcement_readiness_status="blocked"` with design-only agent
guidance. Applied sources can emit ready only when all enforcement evidence and
verification checks pass.

Chosen approach: Option C.

## Artifact Contract

The tool emits schema:

`zigeffect.causal.production-telemetry-ci-gate-required-status-check-enforcement-readiness.v1`

The build step is:

`causal-production-telemetry-ci-gate-required-status-check-enforcement-readiness`

The source branch is:

`codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-enforcement-readiness`

The recommendation after a ready artifact should be:

`start-production-telemetry-ci-gate-required-status-check-enforcement-application-boundary`

The next branch should be:

`codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-enforcement-application-boundary`

The emitted artifact must include:

- source policy path, schema, decision, status, ready flag, source application
  state, and source applied flag;
- `decision="approve" | "reject"`;
- `enforcement_readiness_status="ready" | "blocked"`;
- `ready_for_next_branch=true` only for fully reviewed applied-source
  readiness;
- `source_applied=true | false`;
- `active_enforcement_claim_allowed=false`;
- `merge_blocker_claim_allowed=false`;
- `mutation_authority="none"`;
- required check names;
- branch-protection evidence;
- workflow or check-run evidence;
- failure-mode evidence;
- owner approval evidence;
- rollback evidence;
- evidence requirement catalog;
- denied inference rules;
- negative fixtures;
- required verification commands;
- verified commands;
- agent guidance.

## CLI

The command shape is:

```sh
zig build causal-production-telemetry-ci-gate-required-status-check-enforcement-readiness -- \
  --from-policy <required-status-check-policy.json> \
  approve|reject \
  --reason <reason> \
  [--by <actor>] \
  [--policy <policy>] \
  [--required-check-name <name>]... \
  [--branch-protection-evidence <path-or-summary>]... \
  [--workflow-evidence <path-or-summary>]... \
  [--check-run-evidence <path-or-summary>]... \
  [--failure-mode-evidence <path-or-summary>]... \
  [--owner-approval <path-or-summary>]... \
  [--rollback-evidence <path-or-summary>]... \
  [--verified-command <command>]... \
  [--out-prefix <path-prefix>]
```

Default values:

- `--by` defaults to
  `ci-gate-required-status-check-enforcement-readiness-reviewer`.
- `--policy` defaults to
  `manual-production-telemetry-ci-gate-required-status-check-enforcement-readiness`.

Default output path replacement:

- `*-required-status-check-policy.json` becomes
  `*-required-status-check-enforcement-readiness.json`.
- Deeply chained implicit output names should be compacted to a deterministic
  filesystem-safe prefix with a short source-path digest.

## Source Policy Contract

The source artifact is enforcement-readiness eligible when:

- `schema` is
  `zigeffect.causal.production-telemetry-ci-gate-required-status-check-policy.v1`.
- `schema_version` is `1`.
- `decision` is `approve`.
- `required_status_check_policy_status` is `ready`.
- `ready_for_next_branch=true`.
- `source_applied=true`.
- `source_application_status="applied"`.
- `source_application_mode="record-applied"`.
- `source_application_mutation_authority="record-only"`.
- `source_readiness` and `source_after_report_digest` are present.
- `required_check_surface_policy` is present and every entry has
  `tool_mutation_enabled=false` and `merge_blocker_claim_allowed=false`.
- `checks` contains no `fail` statuses.
- `source_application_checks` contains no `fail` statuses.
- denied inference rules, negative fixtures, blocked claims, required
  verification commands, and verified commands are present.
- every policy required verification command is recorded.
- every source authority boolean remains disabled:
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

Planned policy artifacts are parseable but not readiness eligible. They should
fail the `source-policy-applied` check and emit blocked, design-only guidance.

## Enforcement Evidence Checks

An approved ready artifact requires:

- at least one `--required-check-name`;
- at least one `--branch-protection-evidence`;
- at least one `--workflow-evidence` or `--check-run-evidence`;
- at least one `--failure-mode-evidence`;
- at least one `--owner-approval`;
- at least one `--rollback-evidence`;
- every required verification command listed below;
- no evidence string with secret-shaped values;
- no evidence string that claims this tool performed GitHub API mutation,
  branch-protection mutation, workflow mutation, check-run creation, CI upload
  execution, live telemetry ingestion, durable writes, NenDB writes, production
  health, deployment success, customer impact, or production cluster readiness.

Required verification commands:

- `zig build causal-production-telemetry-ci-gate-required-status-check-policy`
- `zig build causal-artifacts`
- `zig build release-gate --summary none`
- `zig build release-gate-report`
- `zig build causal-schema-governance -- --format json`
- `zig build causal-production-hardening-backlog -- --format json`
- `zig build examples`
- `zig build test`

## Decisions

### Approve

`approve` records that the enforcement-readiness evidence was reviewed. It only
emits ready when the source policy is applied and every source, evidence, and
verification check passes.

Output:

- `enforcement_readiness_status="ready"` when all checks pass.
- `ready_for_next_branch=true`.
- `active_enforcement_claim_allowed=false`.
- `merge_blocker_claim_allowed=false`.
- `mutation_authority="none"`.
- all CI enforcement, required-check, branch-protection mutation, workflow
  mutation, GitHub API mutation, check-run creation, publication, upload, live
  telemetry, durable, and NenDB flags remain false.

### Reject

`reject` records a reviewed stop. It always emits blocked readiness status,
even when the source artifact and evidence are otherwise valid.

Output:

- `enforcement_readiness_status="blocked"`.
- `ready_for_next_branch=false`.
- `active_enforcement_claim_allowed=false`.
- `merge_blocker_claim_allowed=false`.
- `mutation_authority="none"`.

## Evidence Catalog

Allowed evidence:

- bounded causal JSON and text artifacts;
- release-gate JSON and text artifacts;
- local or externally reviewed branch-protection snapshots;
- local or externally reviewed workflow snippets;
- local or externally reviewed check-run summaries;
- failure-mode evidence that proves the future required check has a defined
  failure behavior;
- owner approval records;
- rollback or removal instructions;
- policy artifacts from the required-status-check chain.

Denied evidence:

- secret values, tokens, credentials, raw private headers, and unredacted
  URLs with credentials;
- network calls made by this tool;
- live telemetry ingestion;
- production database writes;
- durable writes;
- NenDB writes;
- non-NenDB durable adapter evidence;
- production health, deployment success, capacity, customer impact, or cluster
  readiness claims;
- alternate renderer scope such as React workbench replacement.

## Denied Inferences

The output must explicitly deny:

- enforcement readiness is active required-status-check enforcement;
- enforcement readiness is active merge blocking;
- enforcement readiness proves GitHub mutation by this tool;
- enforcement readiness proves branch-protection mutation by this tool;
- enforcement readiness proves workflow mutation by this tool;
- enforcement readiness proves check-run creation by this tool;
- enforcement readiness proves CI upload execution by this tool;
- enforcement readiness proves GitHub step-summary or pull-request comment
  writes by this tool;
- enforcement readiness proves live production health;
- enforcement readiness proves deployment success;
- enforcement readiness proves customer impact;
- enforcement readiness proves production cluster readiness;
- enforcement readiness proves live telemetry coverage;
- enforcement readiness proves durable or NenDB writes;
- enforcement readiness grants mutation authority.

## Negative Fixtures

The tool tests and artifact must include fixtures for:

- planned source policy denied for readiness;
- blocked source policy denied;
- rejected reviewer decision denied;
- active enforcement claim denied;
- merge blocker claim denied;
- missing required check name denied;
- missing branch-protection evidence denied;
- missing workflow or check-run evidence denied;
- missing failure-mode evidence denied;
- missing owner approval denied;
- missing rollback evidence denied;
- missing release-gate verification denied;
- GitHub API mutation claim denied;
- branch-protection mutation by tool denied;
- workflow mutation by tool denied;
- check-run creation by tool denied;
- CI upload execution denied;
- secret-shaped evidence denied;
- live telemetry denied;
- durable write denied;
- NenDB write denied;
- non-NenDB durable adapter denied;
- alternate renderer denied.

## Agent Guidance

Ready artifacts tell agents:

- the evidence is strong enough to prepare the enforcement application-boundary
  branch;
- do not claim a required status check is active;
- do not claim merges are blocked;
- do not call GitHub APIs or mutate workflows;
- preserve the evidence catalog, denied inference rules, and verification
  command list in the next branch.

Blocked artifacts tell agents:

- stop before enforcement application-boundary work;
- inspect failed checks and missing evidence;
- if `source_applied=false`, return to the application-boundary branch and
  record reviewed external application evidence before proceeding;
- do not infer production health, cluster readiness, or mutation authority from
  a blocked readiness artifact.

## Implementation Scope

Create:

- `packages/zigeffect/tools/causal_production_telemetry_ci_gate_required_status_check_enforcement_readiness.zig`
- `packages/zigeffect/docs/production-telemetry-ci-gate-required-status-check-enforcement-readiness.md`

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
- adjacent required-status-check docs that name the current next branch.

## Testing

Focused tests in the new Zig tool should cover:

- constants and default CLI values;
- option parsing for all evidence flags;
- implicit output path replacement;
- approved applied-source readiness produces ready JSON and text;
- approved planned-source policy produces blocked JSON and text;
- rejected reviewer decision blocks even with otherwise valid evidence;
- unsafe source authority booleans block readiness;
- missing required check name blocks readiness;
- missing branch-protection evidence blocks readiness;
- missing workflow or check-run evidence blocks readiness;
- missing failure-mode, owner approval, rollback, or verification evidence
  blocks readiness;
- secret-shaped and denied-claim evidence blocks readiness;
- denied inference, negative fixture, and evidence requirement catalogs are
  emitted.

Build-level verification should run:

```sh
cd packages/zigeffect
zig test tools/causal_production_telemetry_ci_gate_required_status_check_enforcement_readiness.zig
zig build causal-production-telemetry-ci-gate-required-status-check-enforcement-readiness -- --help
zig build causal-production-telemetry-ci-gate-required-status-check-enforcement-readiness -- \
  --from-policy ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-policy.json \
  approve \
  --reason "required status check enforcement readiness reviewed" \
  --required-check-name "zigeffect causal release gate" \
  --branch-protection-evidence "reviewed branch protection required status check evidence" \
  --workflow-evidence "reviewed release gate workflow evidence" \
  --failure-mode-evidence "reviewed failing release gate blocks future required check" \
  --owner-approval "reviewed owner approval for future required check enforcement" \
  --rollback-evidence "reviewed rollback removes required status check from branch protection" \
  --verified-command "zig build causal-production-telemetry-ci-gate-required-status-check-policy" \
  --verified-command "zig build causal-artifacts" \
  --verified-command "zig build release-gate --summary none" \
  --verified-command "zig build release-gate-report" \
  --verified-command "zig build causal-schema-governance -- --format json" \
  --verified-command "zig build causal-production-hardening-backlog -- --format json" \
  --verified-command "zig build examples" \
  --verified-command "zig build test"
zig build causal-production-telemetry-ci-gate-required-status-check-enforcement-readiness -- \
  --from-policy ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-policy-negative.json \
  reject \
  --reason "negative required status check enforcement readiness path" \
  --out-prefix ../../.zig-cache/causal-artifacts/production-telemetry-ci-gate-required-status-check-enforcement-readiness-negative
zig build causal-schema-governance -- --format json
zig build causal-production-hardening-backlog -- --format json
zig build examples
zig build test
cd ../..
bun run check
bun run zig:test
git diff --check
```

The ready CLI example above requires a policy artifact whose source policy is
externally applied. When the existing local generated policy artifact is based
on planned application-boundary evidence, the command should intentionally emit
blocked readiness until applied evidence exists.

## Documentation

The user-facing docs should explain:

- enforcement-readiness is not active enforcement;
- planned policy sources are design-only and blocked for readiness;
- applied policy sources can become ready only with complete enforcement
  evidence;
- evidence surfaces that agents may cite;
- denied inferences and negative fixtures;
- next branch guidance.

README, operations, roadmap, schema governance, backlog, and master roadmap
references should advance the current next branch from policy to
enforcement-readiness and then from enforcement-readiness to the future
enforcement application-boundary branch.

## Spec Self-Review

- Placeholder scan: no placeholder sections or deferred requirements remain.
- Consistency check: the design keeps all authority booleans disabled and
  distinguishes readiness from active enforcement throughout.
- Scope check: this is one bounded artifact/tool/docs/schema/backlog milestone.
- Ambiguity check: planned policy artifacts are parseable but blocked; ready
  readiness requires `source_applied=true` and complete enforcement evidence.
