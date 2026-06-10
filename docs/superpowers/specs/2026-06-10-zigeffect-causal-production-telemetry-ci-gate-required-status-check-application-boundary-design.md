# Production Telemetry CI Gate Required Status Check Application Boundary Design

## Purpose

This branch builds the guarded application-boundary layer after
`causal-production-telemetry-ci-gate-required-status-check-readiness`.

The tool should let agents and reviewers record that required-status-check
activation is still only planned, or record that a separately reviewed external
update has been applied. It must not create GitHub required checks, mutate
branch protection, create check runs, call GitHub APIs, mutate workflows, upload
artifacts, write GitHub step summaries, post pull request comments, enable CI
gate enforcement, ingest live telemetry, call networks, write NenDB, write
durable production storage, or grant mutation authority.

The practical value is to make the transition from advisory CI telemetry to
required-status-check governance auditable. Agents get a machine-readable
boundary that answers: what source readiness was used, which required-check
profile is being considered, what external change evidence exists, whether
before/after verification is complete, and whether the record is still planned,
applied, or blocked.

## Current Context

The previous branch delivered
`zigeffect.causal.production-telemetry-ci-gate-required-status-check-readiness.v1`.
Ready artifacts contain candidate profiles with `activation_enabled=false`,
readiness dimensions, activation guardrails, denied inference rules, negative
fixtures, complete verification evidence, and a handoff to this branch.

Existing application-boundary tools establish the local pattern:

- `causal-production-telemetry-ci-gate-application-boundary` consumes CI gate
  readiness artifacts and records planned or externally applied workflow
  boundary evidence.
- `causal-production-telemetry-ci-gate-advisory-ci-report-application-boundary`
  consumes advisory CI report artifacts and records planned or externally
  applied publication evidence.
- Both tools use `plan|record-applied`, keep mutation authority as `none`, and
  only set `applied=true` when source checks, change evidence, before/after
  evidence, after-state safety checks, and post-application verification all
  pass.

## Design Options Considered

### Option A: Direct Required Check Applicator

Build a tool that edits GitHub branch protection or workflow configuration.
This is not acceptable for this milestone. It would cross the established
record-only boundary, require network credentials, and create too much blast
radius before the evidence contract is stable.

### Option B: Readiness-Only Extension

Extend the readiness tool with more guardrails. This would keep the system
safe, but it would blur two distinct concepts: deciding whether application
work can start, and recording whether externally reviewed application evidence
exists.

### Option C: Guarded Application Boundary

Add a new record-only tool that consumes ready required-status-check readiness
artifacts, supports `plan` and `record-applied`, and only records
`applied=true` after reviewed external evidence and before/after verification.
This matches the established causal production hardening pattern and gives
agents a clear handoff without giving the tool mutation authority.

Chosen approach: Option C.

## Artifact Contract

The tool emits schema:

`zigeffect.causal.production-telemetry-ci-gate-required-status-check-application-boundary.v1`

The build step is:

`causal-production-telemetry-ci-gate-required-status-check-application-boundary`

The source branch is:

`codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-application-boundary`

The recommendation after a planned or applied boundary should be:

`start-production-telemetry-ci-gate-required-status-check-policy`

The next branch should be:

`codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-policy`

The emitted artifact must include:

- source readiness schema, status, decision, ready flag, reviewer, policy, and
  source digest;
- `mode="plan"` or `mode="record-applied"`;
- `required_status_check_application_status="planned" | "applied" | "blocked"`;
- `applied=false` for plan or blocked records, and `applied=true` only for
  passing `record-applied`;
- disabled authority booleans for CI gate enforcement, workflow mutation,
  GitHub API mutation, check-run creation, artifact upload execution, GitHub
  step summary write, pull request comment write, live telemetry ingestion,
  network send, runtime pipeline, durable write, NenDB write, and mutation
  authority;
- required-check profile evidence;
- branch-protection review evidence;
- workflow/check-run review evidence;
- before and after evidence;
- post-application verification commands;
- denied inference rules;
- negative fixtures;
- agent guidance.

## CLI

The command shape is:

```sh
zig build causal-production-telemetry-ci-gate-required-status-check-application-boundary -- \
  --from-readiness <required-status-check-readiness.json> \
  plan|record-applied \
  --reason <reason> \
  [--by <actor>] \
  [--policy <policy>] \
  [--required-check-profile <profile-id>] \
  [--branch-protection-change <evidence>] \
  [--workflow-change <path-or-evidence>] \
  [--check-run-change <evidence>] \
  [--before <evidence>] \
  [--after <evidence>] \
  [--branch-protection-after <branch-protection.json|branch-protection.md|branch-protection.txt>] \
  [--workflow-after <workflow.yml|workflow.yaml>] \
  [--verified-command <command>]... \
  [--out-prefix <path-prefix>]
```

`plan` may be used with only source readiness and a reason. It emits a planned
boundary and keeps `applied=false`.

`record-applied` requires reviewed change evidence, before evidence, after
evidence, after-state files where provided, and every required post-application
verification command. Missing evidence blocks the artifact.

## Source Readiness Checks

The source artifact must:

- use schema
  `zigeffect.causal.production-telemetry-ci-gate-required-status-check-readiness.v1`;
- have `required_status_check_readiness_status="ready"`;
- set `ready_for_next_branch=true`;
- have `decision="approve"`;
- keep `mutation_authority="none"`;
- keep every execution and mutation authority disabled;
- include candidate required-check profiles with `activation_enabled=false`;
- include readiness dimensions, activation guardrails, denied inference rules,
  negative fixtures, blocked claims, required verification commands, and
  matching verified commands.

Source checks:

- `source-schema`
- `source-readiness-ready`
- `source-decision-approved`
- `source-required-checks-disabled`
- `source-branch-protection-disabled`
- `source-github-api-disabled`
- `source-ci-execution-disabled`
- `source-runtime-and-storage-disabled`
- `source-catalogs-present`
- `source-verification-recorded`

## Application Evidence Checks

`plan` checks:

- source checks pass;
- mode is `plan`;
- selected required-check profile exists when supplied;
- selected profile still has `activation_enabled=false`;
- mutation authority is `none`.

`record-applied` checks:

- every source check passes;
- mode is `record-applied`;
- `--required-check-profile` names one of the source profiles;
- branch-protection change evidence is present;
- workflow or check-run change evidence is present;
- before evidence is present;
- after evidence is present;
- post-application verification contains every required command;
- branch-protection after-state, when supplied, is locally parseable/safe;
- workflow after-state, when supplied, is locally parseable/safe;
- no prohibited marker grants this tool network, GitHub API, workflow mutation,
  artifact upload, live telemetry, durable write, NenDB write, alternate
  renderer scope, production cluster claims, or mutation authority.

Required post-application verification commands:

- `zig build causal-production-telemetry-ci-gate-required-status-check-readiness`
- `zig build causal-artifacts`
- `zig build release-gate --summary none`
- `zig build release-gate-report`
- `zig build causal-schema-governance -- --format json`
- `zig build causal-production-hardening-backlog -- --format json`
- `zig build examples`
- `zig build test`

## After-State Safety

The tool is still record-only. It can inspect local evidence files but cannot
apply them.

`--branch-protection-after` may point to `.json`, `.md`, or `.txt`. It must be
local, bounded, and free of secrets. It should contain evidence words such as
`required`, `status`, `check`, and `branch protection`. It must not contain
markers for GitHub API tokens, live production telemetry endpoints, deployment
success, production health, production cluster readiness, durable write
credentials, NenDB write credentials, or mutation authority grants.

`--workflow-after` may point to `.yml` or `.yaml`. It must be local, bounded,
and free of secrets. It should contain evidence words such as `zigeffect`,
`causal`, and `release-gate` or `required`. It must not contain markers that
claim this tool mutated workflows, created check runs, uploaded artifacts,
wrote GitHub summaries, posted pull request comments, opened networks, wrote
durable production storage, wrote NenDB, enabled alternate renderers, or gained
mutation authority.

## Denied Inferences

The artifact must deny:

- GitHub API mutation by the tool;
- branch protection mutation by the tool;
- workflow mutation by the tool;
- GitHub check-run creation by the tool;
- artifact upload execution by the tool;
- GitHub step summary write by the tool;
- pull request comment write by the tool;
- CI gate enforcement by this tool;
- live telemetry ingestion;
- network send;
- runtime pipeline activation;
- durable production writes;
- NenDB writes;
- non-NenDB durable adapter scope;
- alternate renderer scope;
- deployment success proof;
- production health proof;
- production cluster readiness proof;
- customer impact proof;
- capacity proof;
- mutation authority.

## Negative Fixtures

The tool should include negative fixtures for:

- blocked source readiness;
- missing required-check profile;
- active source required-check profile;
- missing branch-protection change evidence;
- missing workflow or check-run change evidence;
- missing before evidence;
- missing after evidence;
- missing release-gate report verification;
- unsafe branch-protection after-state with secrets;
- unsafe workflow after-state with upload or summary execution;
- GitHub API mutation claim;
- live telemetry claim;
- durable write claim;
- NenDB write claim;
- production health claim;
- production cluster readiness claim;
- alternate renderer claim;
- mutation authority claim.

## Documentation Updates

Update:

- `packages/zigeffect/build.zig`
- `packages/zigeffect/tools/causal_schema_governance.zig`
- `packages/zigeffect/tools/causal_production_hardening_backlog.zig`
- `packages/zigeffect/README.md`
- `packages/zigeffect/docs/operations.md`
- `packages/zigeffect/docs/schema-governance.md`
- `packages/zigeffect/docs/production-hardening-backlog.md`
- `packages/zigeffect/docs/roadmap.md`
- `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`

Create:

- `packages/zigeffect/tools/causal_production_telemetry_ci_gate_required_status_check_application_boundary.zig`
- `packages/zigeffect/docs/production-telemetry-ci-gate-required-status-check-application-boundary.md`

Predecessor docs that currently point at this branch as the active next branch
should be updated to point at
`codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-policy`
after this milestone is delivered.

## Testing Strategy

Use TDD:

1. Start with a failing constants test for schema, branch, recommendation, and
   next branch.
2. Add parser tests for `plan`, `record-applied`, custom actor, policy,
   profile, evidence, after-state files, verified commands, and output prefix.
3. Add source readiness fixture tests for ready and blocked inputs.
4. Add plan-mode tests proving planned artifacts preserve disabled authority.
5. Add record-applied negative tests proving missing evidence and unsafe
   after-state files block.
6. Add record-applied positive tests proving `applied=true` only with complete
   source, change, before/after, safe after-state, and verification evidence.
7. Run focused and broad verification:

```sh
cd packages/zigeffect
zig test tools/causal_production_telemetry_ci_gate_required_status_check_application_boundary.zig
zig build causal-production-telemetry-ci-gate-required-status-check-application-boundary -- --help
zig build causal-schema-governance -- --format json
zig build causal-production-hardening-backlog -- --format json
zig build examples
zig build test
cd ../..
bun run check
bun run zig:test
git diff --check
```

## Success Criteria

- Ready source artifacts can produce planned application-boundary artifacts.
- `record-applied` can produce `applied=true` only after complete reviewed
  evidence and verification.
- Blocked or incomplete evidence produces blocked artifacts with
  `applied=false`.
- The tool never mutates GitHub, workflows, branch protection, CI, storage, or
  telemetry.
- Schema governance reports the new schema.
- The hardening backlog marks this milestone delivered and recommends the next
  required-status-check policy branch.
- Docs teach agents that this is an evidence boundary, not an applicator.
