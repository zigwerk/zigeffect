# Zigeffect Causal App-Facing CI Advisory Remediation Report Consumption Readiness Design

## Problem

The app-facing advisory remediation report chain now has a ready publication
policy. That policy defines how reviewed advisory evidence may be interpreted,
but it does not yet define the readiness contract for actual read-only
consumption by agents, reviewers, CI readers, or the local SolidJS
`webui-dev/zig-webui` workbench.

Without a consumption-readiness artifact, a future agent or workbench could
over-infer from the policy and treat advisory report evidence as runtime
integration, mutation authority, required CI enforcement, production-health
proof, raw payload access, or NenDB adapter execution. This milestone creates a
record-only readiness gate that says what can be consumed, by whom, and under
which bounded evidence constraints.

## Approaches Considered

1. **Adapt production required-status-check readiness.** This reuses the proven
   publication-policy-to-readiness shape, but changes the domain from required
   CI checks to read-only app-facing consumption. This is the recommended
   approach because it follows local code patterns while avoiding enforcement.
2. **Add workbench parsing directly.** This would make the SolidJS workbench
   consume publication-policy artifacts immediately. It is premature because it
   skips the agent/workbench contract and risks UI assumptions becoming policy.
3. **Fold consumption into publication policy.** This would avoid another
   artifact, but it would blur interpretation and consumption readiness. The
   extra boundary is useful because the next steps involve agents and UI
   surfaces.

## Goals

- Consume
  `zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-publication-policy.v1`.
- Require source decision `approve`,
  `ci_advisory_remediation_report_publication_policy_status="ready"`,
  `ready_for_next_branch=true`, and `mutation_authority="none"`.
- Emit
  `zigeffect.causal.app-facing-production-integration-ci-advisory-remediation-report-consumption-readiness.v1`.
- Define explicit read-only consumer profiles for reviewers, agents, CI
  readers, the SolidJS workbench, and future consumption-boundary tooling.
- Define readiness dimensions for bounded queries, source ids, redaction,
  retention, denied-claim carryover, allowed evidence refs, and next-query
  hints.
- Define guardrails that deny app mutation, app runtime integration, live agent
  projections, raw payload capture, NenDB writes, NenDB adapter execution,
  Cockroach scope, required status checks, deployment authority, production
  health, alternate renderers, and mutation authority.
- Preserve source interpretation rules, publication surfaces, denied inference
  rules, negative fixtures, blocked claims, and verification commands.
- Hand off to a guarded consumption boundary branch:
  `codex/zigeffect-causal-app-facing-production-integration-ci-advisory-remediation-report-consumption-boundary`.

## Non-Goals

- No required status checks, CI gate enforcement, merge blocking, or branch
  protection work.
- No GitHub API calls, workflow edits, check-run creation, artifact uploads,
  step summaries, or pull request comments.
- No app config writes, app data writes, app mutation controls, app runtime
  integration, live agent projections, or raw payload capture.
- No NenDB writes, NenDB adapter execution, durable writes, Cockroach adapter
  work, or non-NenDB durable adapter scope.
- No production health, deployment success, customer impact, capacity, or
  cluster readiness claims.
- No React or alternate renderer support.

## Source Contract

The source publication policy must prove:

- schema version 1;
- `decision="approve"`;
- `ci_advisory_remediation_report_publication_policy_status="ready"`;
- `ready_for_next_branch=true`;
- `mutation_authority="none"`;
- source application-boundary path and after-report digest are present;
- source policy checks contain no failures;
- source interpretation rules, publication surfaces, denied inference rules,
  negative fixtures, blocked claims, required verification commands, and
  verified commands are present;
- CI enforcement, report publication execution, GitHub mutation, app mutation,
  app runtime integration, live projection, raw payload capture, runtime
  pipeline, durable writes, NenDB writes, NenDB adapter execution, deployment
  mutation, and alternate renderer scope remain disabled.

## Readiness Output

The output artifact includes:

- source publication-policy path, decision, status, ready flag, mutation
  authority, and after-report digest;
- readiness decision, reviewer, policy, and reason;
- `consumption_readiness_status` and `ready_for_next_branch`;
- disabled authority booleans for CI, GitHub, app, deployment, runtime,
  storage, and renderer behavior;
- readiness checks;
- consumer profiles;
- readiness dimensions;
- consumption guardrails;
- denied inference rules;
- negative fixtures;
- carried blocked claims;
- required and verified commands;
- recommendation and next branch.

## Verification

Required verification:

- `zig test tools/causal_app_facing_production_integration_ci_advisory_remediation_report_consumption_readiness.zig`
- approval artifact generation from the ready publication-policy artifact
- rejected negative artifact generation
- `zig build causal-schema-governance -- --format json`
- `zig build causal-production-hardening-backlog -- --format json`
- `zig build examples`
- `zig build test`
- `bun run check`
- `bun run zig:test`
- `git diff --check`
