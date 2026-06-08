# zigeffect Causal Policy Engine Design

## Purpose

M1 adds a deterministic policy-decision layer to the causal self-improvement
loop. The current chain can diagnose a causal run, propose remediation, audit
the proposal, record a manual decision, draft a scenario registry patch, check
registry application readiness, and record application state. The missing piece
is a policy artifact that lets agents explain why a branch is safe, blocked, or
still needs a human without granting mutation authority.

The policy engine is an evidence interpreter, not an applier. It reads existing
causal artifacts, evaluates named local rules, and writes JSON/text reports that
can be cited by agents, CI, and future gates.

## Current Context

The existing causal tools follow a useful pattern:

- narrow CLI parsing in `packages/zigeffect/tools/*.zig`;
- deterministic path derivation under `.zig-cache/causal-artifacts`;
- schema/version validation before reading artifact content;
- JSON plus text reports;
- explicit `applied=false` for review artifacts;
- build integration through `packages/zigeffect/build.zig`;
- tests colocated in the tool module.

M0 added `causal-registry-apply`, which records registry application state and
only sets `applied=true` when readiness, source-state checks, and verification
evidence pass. M1 should consume that application evidence where relevant, but
it must not become another route for source edits.

## Goals

- Add schema `zigeffect.causal.policy-decision.v1`.
- Add `zig build causal-policy-decision -- local [scenario]`.
- Produce deterministic JSON/text artifacts:
  - `.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-policy-decision.json`
  - `.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-policy-decision.txt`
  - scenario variants using `zigeffect-causal-dev-loop-<scenario>-policy-decision.*`
- Reuse the manual-review vocabulary:
  - reviewer or evaluator identity;
  - policy name;
  - reason and reason codes;
  - approval posture;
  - required verification commands;
  - guardrails.
- Default `mutation_authority` to `none`.
- Make every decision cite source artifact paths and deterministic rule ids.
- Keep policy output useful to agents reading the runtime without letting an
  agent silently apply patches.

## Non-Goals

- No source mutation.
- No registry patch application.
- No durable backend.
- No remote policy service.
- No general-purpose policy language.
- No AI-generated policy judgments inside the command.
- No timestamped or nondeterministic data in the artifact.

## Command Shape

M1 introduces:

```sh
zig build causal-policy-decision -- local [scenario] [--policy <policy>] [--by <actor>]
```

The default policy is `local-causal-self-improvement-v1`. The default actor is
`local-policy-engine`. The optional scenario argument follows the same behavior
as the other local causal dev-loop commands: no scenario means default dev-loop
artifact paths; a scenario name derives scenario-specific paths.

The command writes both JSON and text reports. It exits non-zero only for
invalid invocation, unsupported schemas, unreadable required artifacts, or
inconsistent source artifact shape. A policy outcome of reject or
needs-human-review is a successful report, not a process error.

## Inputs

The first implementation reads the existing local artifact chain:

- remediation audit: required;
- remediation decision: optional;
- patch proposal: required;
- audit chain: required;
- scenario proposal: optional;
- registry patch: optional;
- registry application readiness: optional;
- registry application: optional.

Required artifacts match the core remediation path. Optional artifacts let the
policy decision explain downstream state when the branch is already moving into
scenario-registry learning.

The command validates any present artifact schema and version:

- `zigeffect.causal.remediation-audit.v1`
- `zigeffect.causal.remediation-decision.v1`
- `zigeffect.causal.patch-proposal.v1`
- `zigeffect.causal.audit-chain.v1`
- `zigeffect.causal.scenario-proposal.v1`
- `zigeffect.causal.registry-patch.v1`
- `zigeffect.causal.registry-application-readiness.v1`
- `zigeffect.causal.registry-application.v1`

Optional artifacts are ignored when absent but rejected when present with an
unsupported schema. This keeps the policy record honest without requiring the
whole later registry chain for every local remediation.

## Policy Catalog

The policy catalog is code-first for M1. Documentation should list the catalog,
but the executable rules live in Zig so tests can prove determinism.

### `local-causal-self-improvement-v1`

This is the default local policy for building `zigeffect` with its own causal
runtime.

It emits one of three decisions:

- `approve`: evidence is internally consistent and a human has already approved
  the manual remediation decision or the proposal is only a non-applying no-op.
- `reject`: evidence proves the chain is unsafe, already applied where it should
  still be review-only, schemas are unsupported, or a present manual decision is
  rejected.
- `needs-human-review`: evidence is plausible but lacks a manual approval,
  downstream readiness/application evidence is blocked, or the policy sees a
  registry proposal that still requires review.

The default policy never grants mutation authority. `approve` means "an agent
may cite this as a policy recommendation"; it does not mean source can be
edited or registry changes can be applied.

## Decision Rules

Rules are deterministic and named. The JSON output includes rule ids, statuses,
and details so agents can cite the exact reason.

Initial rules:

- `audit-schema-supported`: remediation audit schema/version is valid.
- `audit-pending-review`: audit remains pending and unapplied.
- `patch-proposal-schema-supported`: patch proposal schema/version is valid.
- `patch-proposal-unapplied`: patch proposal has not been applied.
- `proposal-source-matches-audit`: patch proposal points back to the same audit.
- `audit-chain-schema-supported`: audit-chain schema/version is valid.
- `audit-chain-target-matches`: audit chain target matches the audit/proposal.
- `manual-decision-consistent`: optional manual decision is supported, unapplied,
  targets the same audit, and is either approved or rejected.
- `registry-readiness-consistent`: optional readiness report is supported,
  unapplied, and references a supported registry patch.
- `registry-application-consistent`: optional application report is supported and
  does not claim applied state unless the application checks passed.
- `mutation-authority-none`: the policy result does not authorize mutation.

Decision folding:

- Any schema or target mismatch is a reject.
- Any `applied=true` on audit, decision, proposal, or readiness is a reject.
- A rejected manual decision is a reject.
- A blocked readiness or blocked application report is `needs-human-review`
  unless it also contains an invalid schema/target condition.
- An approved manual decision plus consistent audit/proposal/audit-chain
  evidence is approve.
- No manual approval is `needs-human-review`, even when other evidence is clean.
- A no-op registry proposal may be approve only when the remediation proposal is
  otherwise consistent and the registry patch/readiness/application artifacts
  all agree that no application is needed.

## Output Schema

The JSON report shape is intentionally explicit:

```json
{
  "schema": "zigeffect.causal.policy-decision.v1",
  "schema_version": 1,
  "mode": "local",
  "target": "causal-scoped-fiber",
  "decision": "needs-human-review",
  "approval_status": "needs-human-review",
  "evaluated_by": "local-policy-engine",
  "policy": "local-causal-self-improvement-v1",
  "reason": "manual approval is required before policy can recommend approval",
  "reason_codes": ["manual-decision-missing"],
  "mutation_authority": "none",
  "applied": false,
  "source": {
    "audit": ".zig-cache/causal-artifacts/...",
    "decision": null,
    "proposal": ".zig-cache/causal-artifacts/...",
    "audit_chain": ".zig-cache/causal-artifacts/...",
    "scenario_proposal": null,
    "registry_patch": null,
    "registry_application_readiness": null,
    "registry_application": null
  },
  "event_ids": [1, 2, 3],
  "required_verification_commands": ["zig build examples"],
  "rules": [
    {
      "id": "mutation-authority-none",
      "status": "pass",
      "detail": "policy decisions do not authorize source mutation"
    }
  ],
  "guardrails": [
    "Policy approval is advisory and does not apply source changes."
  ]
}
```

Text output should summarize the same evidence for humans:

- schema and target;
- decision and approval status;
- policy, evaluator, reason, and reason codes;
- mutation authority;
- source artifact paths;
- event ids;
- required verification commands;
- rule statuses;
- guardrails.

## Path Derivation

Default paths:

- audit: `zigeffect-causal-dev-loop-remediation-audit.json`
- decision: `zigeffect-causal-dev-loop-remediation-decision.json`
- proposal: `zigeffect-causal-dev-loop-patch-proposal.json`
- audit chain: `zigeffect-causal-dev-loop-audit-chain.json`
- scenario proposal: `zigeffect-causal-dev-loop-scenario-proposal.json`
- registry patch: `zigeffect-causal-dev-loop-registry-patch.json`
- registry readiness:
  `zigeffect-causal-dev-loop-registry-application-readiness.json`
- registry application: `zigeffect-causal-dev-loop-registry-application.json`
- output: `zigeffect-causal-dev-loop-policy-decision.json/.txt`

Scenario paths insert `-<scenario>` after `zigeffect-causal-dev-loop`, matching
the existing local artifact convention.

## Failure And Safety Behavior

- Unsupported required-artifact schemas fail the command.
- Unsupported optional-artifact schemas fail the command when the optional file
  exists, because silently ignoring bad evidence would produce a misleading
  policy report.
- Missing required artifacts fail the command.
- Missing optional artifacts are recorded as absent source paths in the report.
- Policy decisions always set `applied=false`.
- Policy decisions always set `mutation_authority="none"` in M1.
- Future policy engines may add stricter named policies, but they must preserve
  this no-silent-mutation boundary unless a later milestone explicitly designs a
  stronger operation gate.

## Build And Docs Integration

`packages/zigeffect/build.zig` should add:

- module `tools/causal_policy_decision.zig`;
- test artifact `zigeffect-causal-policy-decision-tests`;
- executable `zigeffect-causal-policy-decision`;
- build step `causal-policy-decision`;
- examples step dependency on the executable and tests.

Docs should update:

- `packages/zigeffect/README.md`;
- `packages/zigeffect/docs/agent-guide.md`;
- `packages/zigeffect/docs/causal-scenarios.md`;
- `packages/zigeffect/docs/roadmap.md`;
- the master causal agent runtime roadmap progress ledger.

`packages/zigeffect/tools/causal_artifacts.zig` should list default and
scenario policy-decision artifacts.

## Testing Strategy

Use TDD for the Zig tool.

Core tests:

- option parsing accepts default and scenario local invocations;
- default and scenario output paths are stable;
- unsupported policy names are rejected;
- clean audit/proposal/audit-chain evidence without manual decision yields
  `needs-human-review`;
- approved manual decision with matching source evidence yields `approve`;
- rejected manual decision yields `reject`;
- source target mismatch yields `reject`;
- optional registry readiness/application blocked state yields
  `needs-human-review`;
- any supported optional artifact with unsupported schema fails validation;
- JSON contains schema, policy, mutation authority, decision, reason codes,
  source paths, event ids, verification commands, and rule ids;
- text output contains the same operational summary;
- artifact manifest includes policy-decision paths.

Verification commands for the branch:

```sh
zig build causal-policy-decision -- local causal-scoped-fiber
zig build examples
zig build test --summary none
bun run check
bun run zig:test
```

## Open Decisions Resolved For M1

- Policy catalog is Zig code, not a user-authored DSL.
- Policies are advisory and cannot apply source.
- Missing optional downstream artifacts do not block policy output.
- Present but invalid optional downstream artifacts block output.
- Approval requires manual approval evidence unless the chain is explicitly a
  consistent no-op.
