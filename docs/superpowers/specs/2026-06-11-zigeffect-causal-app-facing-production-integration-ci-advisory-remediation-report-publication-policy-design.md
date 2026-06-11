# Zigeffect Causal App-Facing CI Advisory Remediation Report Publication Policy Design

## Problem

The app-facing chain can now record an applied, record-only application boundary
for a reviewed CI advisory remediation report. The next step is an
interpretation policy that tells agents and reviewers how that evidence may be
surfaced or consumed without turning it into CI enforcement, GitHub mutation,
app mutation, deployment authority, NenDB writes, or production-health proof.

The production telemetry chain has an advisory CI report publication-policy
tool, but its next step is required-status-check readiness. That is not the
right app-facing direction yet. This branch should keep the app-facing path
read-only and hand off to consumption readiness for agents and reviewers.

## Goals

- Consume
  `zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-application-boundary.v1`.
- Require the source boundary to be `record-applied`, `applied=true`, and
  `mutation_authority="record-only"`.
- Emit
  `zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-publication-policy.v1`.
- Define allowed interpretation rules for maintainers, read-only agents,
  local CI viewers, SolidJS workbench views, and future consumption-readiness
  tools.
- Define denied inference rules for required status checks, merge blockers,
  branch protection, workflow mutation, GitHub mutation, app mutation, NenDB
  writes, NenDB adapter execution, deployment success, production health,
  auto-apply, mutation proof, app runtime integration, live agent projection,
  raw payload capture, React/alternate renderers, and non-NenDB durable scope.
- Define non-executing publication surfaces that describe where already-reviewed
  advisory evidence may be read, without this tool publishing anything.
- Preserve source blocked claims, source checks, boundary rules, verification
  commands, and before/after evidence references.
- Hand off to
  `codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-readiness`.

## Non-Goals

- No required status check or merge-blocking behavior.
- No GitHub workflow edits, check-run creation, step summary writes, PR
  comments, artifact uploads, or GitHub API mutation.
- No app config writes, app data writes, app mutation controls, or app runtime
  integration.
- No live agent projection, raw payload capture, raw prompt capture, or raw
  response capture.
- No NenDB writes, NenDB adapter execution, durable writes, non-NenDB durable
  adapters, or Cockroach scope.
- No deployment mutation, production-health proof, mutation proof, or
  remediation auto-apply.
- No React or alternate renderer scope.

## Source Contract

The source boundary must prove:

- schema version 1;
- `mode="record-applied"`;
- `report_application_status="applied"`;
- `applied=true`;
- `mutation_authority="record-only"`;
- source report path and after-report digest are present;
- publication-change, before, and after evidence arrays are non-empty;
- source checks and application checks have no failures;
- CI publication, required checks, workflow mutation, upload execution, step
  summary writes, PR comments, GitHub API mutation, app mutation, app config/data
  writes, deployment mutation, live runtime flags, durable writes, NenDB writes,
  NenDB adapter execution, and raw payload capture are disabled;
- source catalogs for rules, denied claims, negative fixtures, blocked claims,
  and verification commands are present.

## Policy Output

The output artifact includes:

- source application-boundary path, mode, status, applied flag, mutation
  authority, source report path, and after-report digest;
- decision, reviewer, policy, and reason;
- policy status and `ready_for_next_branch`;
- disabled authority booleans for CI, GitHub, app, deployment, runtime, and
  storage behavior;
- policy checks;
- interpretation rules;
- publication surfaces;
- denied inference rules;
- negative fixtures;
- carried blocked claims;
- required and verified commands;
- recommendation and next branch.

## Verification

Required verification:

- `zig test tools/causal_app_facing_production_integration_ci_advisory_remediation_report_publication_policy.zig`
- approval artifact generation from the applied application-boundary artifact
- rejected negative artifact generation
- `zig build causal-schema-governance -- --format json`
- `zig build causal-production-hardening-backlog -- --format json`
- `zig build examples`
- `zig build test`
- `bun run check`
- `bun run zig:test`
- `git diff --check`
