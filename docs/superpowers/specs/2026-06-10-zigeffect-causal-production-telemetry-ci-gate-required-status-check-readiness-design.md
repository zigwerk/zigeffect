# Production Telemetry CI Gate Required Status Check Readiness Design

## Summary

`causal-production-telemetry-ci-gate-required-status-check-readiness` is a
record-only readiness artifact for the next step after advisory CI report
publication policy. It consumes a ready
`zigeffect.causal.production-telemetry-ci-gate-advisory-ci-report-publication-policy.v1`
artifact and determines whether the project has enough reviewed evidence to
start designing a guarded required-status-check application boundary.

This milestone does not create GitHub required status checks, update branch
protection, mutate workflows, upload artifacts, write GitHub step summaries,
post pull request comments, call networks, ingest live telemetry, write NenDB,
write durable storage, or grant mutation authority.

## Goals

- Emit schema
  `zigeffect.causal.production-telemetry-ci-gate-required-status-check-readiness.v1`.
- Consume ready advisory CI report publication-policy artifacts.
- Preserve the advisory/non-blocking interpretation of the published report.
- Define the evidence dimensions that must be present before a future required
  status check boundary can even be planned.
- Define candidate required-check profiles with `activation_enabled=false`.
- Deny all claims that a required check, merge blocker, branch protection
  update, GitHub check-run mutation, workflow mutation, production-health
  signal, cluster readiness signal, durable write, NenDB write, or mutation
  authority exists.
- Hand off to
  `codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-application-boundary`
  only when readiness is approved and verification evidence is complete.

## Non-Goals

- No branch protection mutation.
- No GitHub API calls or check-run creation.
- No workflow mutation.
- No CI upload execution.
- No required status check activation.
- No live telemetry ingestion.
- No production health, deployment success, capacity, customer impact, or
  cluster readiness claims.
- No durable production writes.
- No NenDB writes.
- No non-NenDB durable adapter work.
- No alternate frontend renderer work.

## Source Contract

The source artifact must:

- use schema
  `zigeffect.causal.production-telemetry-ci-gate-advisory-ci-report-publication-policy.v1`;
- have decision `approve`;
- have `advisory_ci_report_publication_policy_status="ready"`;
- set `ready_for_next_branch=true`;
- set `mutation_authority="none"`;
- keep disabled authority booleans false for CI gate enforcement, required
  status checks, workflow mutation, CI uploads, report publication by the tool,
  GitHub step summary writes, pull request comments, live telemetry, network
  send, runtime pipeline, durable writes, and NenDB writes;
- include interpretation rules, publication surfaces, denied inference rules,
  negative fixtures, blocked claims, required verification commands, and
  matching verified commands;
- deny required-status-check, merge-blocking, branch-protection, production
  health, cluster readiness, mutation authority, non-NenDB durable scope, and
  alternate renderer claims.

## Output Contract

The readiness artifact must include:

- `schema`
- `schema_version`
- `generated_by`
- `source_publication_policy`
- `source_publication_policy_status`
- `decision`
- `required_status_check_readiness_status`
- `ready_for_next_branch`
- `reviewed_by`
- `policy`
- `reason`
- disabled authority booleans
- `mutation_authority="none"`
- `readiness_checks`
- `required_status_check_profiles`
- `readiness_dimensions`
- `activation_guardrails`
- `denied_inference_rules`
- `negative_fixtures`
- `blocked_claims`
- `required_verification_commands`
- `verified_commands`
- `recommendation`
- `next_branch_if_ready`
- `agent_guidance`

The text report must mirror the same fields in deterministic order.

## Readiness Checks

The tool must evaluate these checks:

- `source-schema`: source artifact uses the publication-policy schema.
- `source-policy-ready`: source policy is approved, ready, and ready for next
  branch.
- `source-advisory-non-blocking`: source preserves non-blocking advisory
  interpretation rules and denied merge-blocker claims.
- `source-required-status-check-disabled`: source keeps required status checks
  disabled.
- `source-ci-enforcement-disabled`: source keeps CI gate enforcement, workflow
  mutation, and CI uploads disabled.
- `source-publication-execution-disabled`: source does not claim tool-executed
  GitHub step summaries, pull request comments, or report publication.
- `source-runtime-and-storage-disabled`: source keeps live telemetry, network
  send, runtime pipeline, durable writes, and NenDB writes disabled.
- `source-interpretation-catalogs-present`: source has interpretation rules,
  publication surfaces, denied inference rules, blocked claims, and negative
  fixtures.
- `required-status-check-semantics-defined`: this artifact defines candidate
  check profiles and activation guardrails.
- `required-verification-recorded`: every required verification command is
  cited by `--verified-command`.
- `decision-approved`: reviewer chose `approve`.

Any failed check yields
`required_status_check_readiness_status="blocked"` and
`ready_for_next_branch=false`.

## Candidate Check Profiles

The tool must define candidate profiles only as readiness records:

- `zigeffect-causal-telemetry-advisory-report`
  - `activation_enabled=false`
  - source: ready advisory CI report publication policy
  - intended future signal: advisory report artifact exists, parses, and
    preserves non-blocking interpretation policy
  - denied claim: merge blocking is active
- `zigeffect-causal-release-gate-report`
  - `activation_enabled=false`
  - source: `zig build release-gate --summary none` and
    `zig build release-gate-report`
  - intended future signal: release-gate report exists and parses
  - denied claim: production deployment success
- `zigeffect-causal-required-check-contract`
  - `activation_enabled=false`
  - source: this readiness artifact and the future application-boundary
  - intended future signal: required-check name, failure semantics, bypass
    policy, retry policy, and rollback plan are reviewed
  - denied claim: branch protection is updated

## Activation Guardrails

The readiness artifact must catalog guardrails a later application-boundary
branch must satisfy before it can record applied required-check evidence:

- stable check names and owning workflow paths;
- explicit pass/fail semantics that do not imply production health;
- advisory-to-required escalation review;
- branch protection before/after evidence;
- workflow before/after evidence if workflow changes are proposed;
- manual rollback and disable plan;
- bypass policy for maintainers;
- flake/noise policy and retry expectations;
- redaction and retention policy for surfaced artifacts;
- no GitHub mutation by this readiness tool;
- no mutation authority unless granted by a later reviewed boundary.

## Required Verification Commands

Ready artifacts require these command citations:

```sh
zig build causal-production-telemetry-ci-gate-advisory-ci-report-publication-policy
zig build causal-artifacts
zig build release-gate --summary none
zig build release-gate-report
zig build causal-schema-governance -- --format json
zig build causal-production-hardening-backlog -- --format json
zig build examples
zig build test
```

## Recommendation

If all checks pass, the artifact should recommend
`start-production-telemetry-ci-gate-required-status-check-application-boundary`
and hand off to
`codex/zigeffect-causal-production-telemetry-ci-gate-required-status-check-application-boundary`.

If any check fails, the artifact should recommend repairing source policy,
verification evidence, check-profile semantics, or guardrails before continuing.

## Testing Strategy

- Start with a failing constants test for schema, branch, recommendation, and
  next-branch constants.
- Add CLI parser tests for approve/reject, custom actor/policy/out-prefix,
  verified commands, unknown decision, and missing reason.
- Add source evaluation tests for ready publication policy, blocked source,
  missing denied inference rules, enabled required checks, and incomplete
  verification.
- Add render tests for ready/blocked status, disabled authority booleans,
  candidate profiles, activation guardrails, denied rules, and next-branch
  handoff.
- Update build wiring, schema governance, backlog, README, operations, roadmap,
  and predecessor docs.
- Run focused Zig tests, generated positive/negative artifact commands, broad
  Zig builds, root Bun checks, and `git diff --check`.

## Agent Guidance

Agents may use a ready required-status-check readiness artifact to start the
next application-boundary design. They must not infer that required checks are
active, that merge blocking exists, that branch protection has changed, that
production is healthy, that a production cluster is ready, or that any mutation
authority has been granted.
