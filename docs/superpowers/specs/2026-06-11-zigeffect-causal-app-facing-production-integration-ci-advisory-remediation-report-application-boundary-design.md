# Zigeffect Causal App-Facing CI Advisory Remediation Report Application Boundary Design

## Problem

The app-facing integration chain can now produce a CI advisory remediation
report from the SolidJS read-only preview. The next step is a guarded
application boundary that records either publication intent or reviewed external
publication evidence for that report.

The boundary must keep agents honest. A report can help reviewers and agents
triage app-facing remediation evidence, but it must not imply CI enforcement,
GitHub mutation, app mutation, NenDB writes, deployment, production health, or
`applied=true` without reviewed before/after evidence.

## Goals

- Consume
  `zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report.v1`.
- Emit
  `zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-application-boundary.v1`.
- Support `plan` mode for non-applied application-boundary intent.
- Support `record-applied` mode only when reviewed publication-change evidence,
  before evidence, after evidence, safe report-after content, and required
  verification commands are present.
- Keep the tool record-only: it never publishes, uploads, comments, mutates
  workflows, mutates app data/config, executes a NenDB adapter, writes NenDB, or
  deploys.
- Preserve source report checks, bridge refs, blocked claims, application
  boundary rules, negative fixtures, and agent guidance.
- Advance the roadmap to an app-facing advisory report publication-policy
  branch only when an applied boundary is recorded.

## Non-Goals

- No required status check enablement.
- No CI workflow edits.
- No GitHub API mutation, step summary write, PR comment, or artifact upload.
- No app config or app data writes.
- No live app runtime integration or live agent projection.
- No NenDB adapter execution or NenDB writes.
- No Cockroach scope.
- No deployment mutation, production-health proof, mutation proof, auto-apply,
  or production readiness claim.

## Modes

### Plan

`plan` mode validates that the source report is ready and authority-disabled. It
emits `report_application_status="planned"`, `applied=false`, and
`mutation_authority="none"`. It may include optional safe report-after content,
but it never records applied state.

### Record Applied

`record-applied` mode is still record-only. It records that a reviewed external
publication boundary exists. It requires:

- at least one `--publication-change`;
- at least one `--before`;
- at least one `--after`;
- `--report-after` pointing to `.txt`, `.md`, or `.json` content;
- report-after content containing app-facing causal advisory markers and no
  prohibited authority markers or secret markers;
- all required verification commands.

When every gate passes, the artifact emits
`report_application_status="applied"`, `applied=true`, and
`mutation_authority="record-only"`. This is not mutation authority for zigeffect
itself; it is evidence that a human-reviewed external boundary was recorded.

## Source Checks

The source report must prove:

- schema version 1;
- ready status and `ready_for_next_branch=true`;
- disabled CI enforcement, required checks, workflow mutation, upload execution,
  report publication, GitHub step summary, PR comment, GitHub API mutation, app
  mutation, app config/data write, deployment mutation, live runtime integration,
  live agent projection, durable write, NenDB write, and NenDB adapter execution;
- source checks have no failures;
- bridge records include `ci-advisory-remediation-report-bridge`;
- blocked claims are carried forward;
- source verification evidence is present.

## Output Contract

The output artifact includes:

- source report path and status;
- mode and application status;
- applied flag and mutation authority;
- disabled authority booleans;
- reviewer, policy, reason;
- report-after path, digest, and presence flag;
- publication changes, before evidence, after evidence;
- source checks and application checks;
- retained bridge records;
- application boundary rules;
- denied publication/application claims;
- negative fixtures;
- required and verified commands;
- next branch if applied.

## Verification

Required verification:

- `zig test tools/causal_app_facing_production_integration_ci_advisory_remediation_report_application_boundary.zig`
- plan and record-applied artifact generation
- negative blocked artifact generation
- `zig build test`
- `zig build examples`
- `zig build causal-schema-governance -- --format json`
- `zig build causal-production-hardening-backlog -- --format json`
- `bun run check`
- `bun run zig:test`
- `git diff --check`
