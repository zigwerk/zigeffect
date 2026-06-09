# zigeffect App Application Readiness Design

Date: 2026-06-09

## Purpose

M8 now has a complete non-mutating app remediation proposal lane:

- `zigeffect.causal.app-remediation-audit.v1`
- `zigeffect.causal.app-policy-decision.v1`
- `zigeffect.causal.app-human-review.v1`
- `zigeffect.causal.app-patch-proposal.v1`

The next boundary is app application readiness. It consumes a draft app patch
proposal and records whether a reviewed human or local policy owner believes
the proposal is ready to attempt. It does not edit source files, config,
migrations, runbooks, rollback plans, deployments, databases, queues, or any
external app state.

The output remains an evidence artifact:

```text
applied=false
mutation_authority=none
```

Only the later guarded app application boundary may record `applied=true`, and
only after a real reviewed source or external-state update plus before/after
verification evidence.

## Current Chain

The app remediation chain becomes:

```text
app causal artifact
  -> app remediation audit
  -> app policy decision
  -> app human review, when policy says needs-human-review
  -> app patch proposal
  -> app application readiness
  -> future guarded app application record
```

This mirrors the registry lane:

```text
registry patch
  -> registry application readiness
  -> guarded registry application record
```

The app lane is deliberately broader than the registry lane because app
proposals can involve source, config bindings, data migrations, operational
runbooks, and rollback plans. Readiness therefore must re-check the proposal
shape and citations before a future application artifact can consume it.

## Command

Add a new Zig tool:

```sh
zig build causal-app-application-readiness -- local \
  --proposal <app-patch-proposal-json> \
  approve|reject \
  --reason <reason> \
  [--by <actor>] \
  [--policy <policy>] \
  [--verified <command>]... \
  [--out-prefix <path-prefix>]
```

Default values:

- `--by`: `local-reviewer`
- `--policy`: `manual-app-application-readiness`

The input proposal path must normally end with:

```text
-app-patch-proposal.json
```

When `--out-prefix` is omitted, the tool strips that suffix and writes:

```text
<prefix>-app-application-readiness.json
<prefix>-app-application-readiness.txt
```

When `--out-prefix` is provided, the tool writes:

```text
<out-prefix>-app-application-readiness.json
<out-prefix>-app-application-readiness.txt
```

## Input Artifact

The input schema is:

```text
zigeffect.causal.app-patch-proposal.v1
```

Required proposal fields:

- `schema`
- `schema_version`
- `mode`
- `target`
- `proposal_status`
- `approval_status`
- `approved`
- `applied`
- `mutation_authority`
- `summary`
- `change`
- `source`
- `policy_gates`
- `citations`
- `event_ids`
- `required_verification_commands`

Required `source` fields:

- `policy`
- `app_remediation_audit`
- `app_artifact`

Optional `source` field:

- `human_review`

The proposal must remain:

```text
proposal_status=draft
approval_status=pending
approved=false
applied=false
mutation_authority=none
mode=local
```

High-risk gates require `source.human_review` to be present. This should
already be enforced by `causal-app-patch-proposal`, but readiness validates the
artifact again so downstream agents can trust the readiness contract directly.

## Gate Rules

Known policy gates:

- `source-only`
- `config-only`
- `migration-required`
- `operational-human-required`
- `rollback-required`

Citation requirements:

- `source-only` requires at least one `citations.source_files` entry.
- `config-only` requires at least one `citations.config_keys` entry.
- `migration-required` requires at least one `citations.migration_files` entry
  and a linked human-review artifact path.
- `operational-human-required` requires at least one `citations.runbooks` entry
  and a linked human-review artifact path.
- `rollback-required` requires at least one `citations.rollback_plans` entry
  and a linked human-review artifact path.

Unknown gates block readiness.

## Readiness Evaluation

The reviewer decision is either:

- `approve`
- `reject`

`reject` always produces `readiness_status=blocked`.

`approve` produces `readiness_status=ready` only when every readiness check
passes. Any failed check produces `readiness_status=blocked`.

Checks:

- `app-proposal-schema`: proposal schema and version are supported.
- `proposal-state`: proposal is draft, pending, unapproved, unapplied, and
  non-mutating.
- `reviewer-decision`: caller supplied a decision and non-empty reason.
- `decision-approved`: reviewer chose `approve`.
- `source-chain-present`: proposal links policy, app remediation audit, and app
  artifact sources.
- `policy-gates-known`: every policy gate is known.
- `citations-complete`: every policy gate has the required citations.
- `high-risk-human-review-linked`: high-risk gates have human-review evidence.
- `required-verification-recorded`: every proposal
  `required_verification_commands` entry appears in caller-supplied
  `--verified` commands.

The readiness tool does not execute verification commands. It records that the
reviewer saw and supplied the command evidence needed before attempting
application.

## Output Schema

The output schema is:

```text
zigeffect.causal.app-application-readiness.v1
```

JSON fields:

```json
{
  "schema": "zigeffect.causal.app-application-readiness.v1",
  "schema_version": 1,
  "mode": "local",
  "source_proposal": ".zig-cache/causal-artifacts/yachdee-platform-app-patch-proposal.json",
  "decision": "approve",
  "readiness_status": "ready",
  "ready_for_application": true,
  "reviewed_by": "local-reviewer",
  "policy": "manual-app-application-readiness",
  "reason": "reviewed proposal citations and verification evidence",
  "applied": false,
  "mutation_authority": "none",
  "target": "yachdee-platform",
  "summary": "Fix request failure by adding missing service wiring",
  "change": "Update app source and config binding docs",
  "source": {
    "proposal": ".zig-cache/causal-artifacts/yachdee-platform-app-patch-proposal.json",
    "policy": ".zig-cache/causal-artifacts/yachdee-platform-app-policy-decision.json",
    "app_remediation_audit": ".zig-cache/causal-artifacts/yachdee-platform-app-remediation-audit.json",
    "app_artifact": ".zig-cache/causal-artifacts/yachdee-platform-app.json",
    "human_review": ".zig-cache/causal-artifacts/yachdee-platform-app-human-review.json"
  },
  "policy_gates": ["source-only", "config-only"],
  "citations": {
    "source_files": ["apps/platform/src/worker.ts"],
    "config_keys": ["YACHDEE_API_BASE_URL"],
    "migration_files": [],
    "runbooks": [],
    "rollback_plans": []
  },
  "event_ids": [2, 3],
  "checks": [
    {
      "name": "proposal-state",
      "status": "pass",
      "detail": "proposal is draft, pending, unapplied, and non-mutating"
    }
  ],
  "required_verification_commands": [
    "zig build causal-query -- --file .zig-cache/causal-artifacts/app.json cause 2"
  ],
  "verified_commands": [
    "zig build causal-query -- --file .zig-cache/causal-artifacts/app.json cause 2"
  ],
  "application_steps": [
    "Apply the reviewed source, config, migration, operational, or rollback changes outside this readiness command.",
    "Run every required verification command after applying the real change.",
    "Record a guarded app application artifact only after before/after evidence exists."
  ],
  "readiness_guardrails": [
    "Readiness does not edit app source, config, migrations, operations, rollback plans, deployments, databases, queues, or external state.",
    "ready_for_application=true means the proposal is ready to attempt, not that it was applied.",
    "applied=true is reserved for a future guarded app application artifact with before/after verification."
  ]
}
```

Text output should include the same fields in a scanner-friendly order:

```text
zigeffect app application readiness
schema: zigeffect.causal.app-application-readiness.v1
source proposal: <path>
decision: approve
readiness_status: ready
ready_for_application: true
reviewed_by: local-reviewer
policy: manual-app-application-readiness
reason: reviewed proposal citations and verification evidence
applied: false
mutation_authority: none
target: yachdee-platform
summary: ...
change: ...

checks:
- proposal-state: pass - proposal is draft, pending, unapplied, and non-mutating

required verification commands:
- ...

verified commands:
- ...

application steps:
- ...

readiness guardrails:
- ...
```

## Workbench Integration

The SolidJS workbench should recognize:

```text
zigeffect.causal.app-application-readiness.v1
```

as:

```text
app-application-readiness
```

Required model updates:

- add `app-application-readiness` to governance kinds;
- add `app-application-readiness` to app remediation kinds;
- surface `readiness_status`, `ready_for_application`, `applied`, and
  `mutation_authority`;
- include source links for proposal, policy, app remediation audit, app
  artifact, and human review when present;
- include citations, checks, required verification, verified commands,
  application steps, and readiness guardrails;
- add `?sample=app-readiness` resolving to
  `sample-app-application-readiness.json`.

The UI direction remains SolidJS hosted by `zig-webui`. React is out of scope
for this branch. Future desktop expansion should keep the existing SolidJS
renderer and use `webui-dev/zig-webui` as the Zig-hosted local shell unless a
later design explicitly revisits that choice.

## Documentation Updates

Update:

- `packages/zigeffect/README.md`
- `packages/zigeffect/docs/agent-guide.md`
- `packages/zigeffect/docs/agent-observable-runtime.md`
- `packages/zigeffect/docs/roadmap.md`
- `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`

The roadmap immediate queue should move to:

```text
codex/zigeffect-app-application-boundary
```

That next branch consumes app readiness artifacts and records a guarded app
application artifact with `applied=true` only after real reviewed changes and
post-apply verification are present.

## Non-Goals

- No automatic source edits.
- No config, secret, binding, migration, deployment, operational, rollback,
  database, queue, or external-state mutation.
- No `applied=true` artifacts.
- No claim that `ready_for_application=true` means the fix is complete.
- No React rewrite.
- No broad workbench redesign.
- No Cockroach adapter work.
- No durable backend change; NenDB adapter direction remains separate.

## Tests And Verification

Focused Zig tests should prove:

- usage text and schema ids are stable;
- option parsing accepts reviewer, policy, decision, reason, repeated verified
  commands, and `--out-prefix`;
- output paths derive from `-app-patch-proposal.json` and `--out-prefix`;
- approved low-risk proposals with matching verification produce
  `readiness_status=ready`, `ready_for_application=true`, `applied=false`, and
  `mutation_authority=none`;
- rejected proposals produce `readiness_status=blocked`;
- missing required verification blocks readiness;
- already-applied, approved, or mutating proposals are rejected or blocked;
- unknown policy gates block readiness;
- source/config/high-risk gates require the correct citations;
- high-risk gates require a linked human-review path;
- formatted text output includes checks, verification, application steps, and
  guardrails.

Workbench tests should prove:

- `app-application-readiness` is recognized as governance and app remediation
  kind;
- `?sample=app-readiness` resolves to
  `sample-app-application-readiness.json`;
- readiness status, ready flag, checks, citations, source steps, verification,
  and guardrails are exposed through the derived model.

Required verification before completion:

```sh
cd packages/zigeffect && zig build examples
cd packages/zigeffect && zig build test
bun run zigeffect:workbench:test
bun run zigeffect:workbench:typecheck
bun run zigeffect:workbench:build
bun run check
bun run zig:test
git diff --check
```

Because this branch touches the workbench sample/model layer, run browser QA
against:

```text
?sample=app-readiness
```

on desktop and narrow mobile viewports.

## Self-Review

- The readiness artifact consumes draft proposal evidence and stays
  non-mutating.
- The design re-checks proposal state instead of trusting upstream tools
  blindly.
- High-risk gates remain tied to human-review evidence.
- Verification commands are recorded, not executed by the readiness tool.
- The next `applied=true` boundary is explicit and separate.
- The workbench direction remains SolidJS plus `zig-webui`.
- The design excludes Cockroach work and does not expand the NenDB adapter
  scope.
