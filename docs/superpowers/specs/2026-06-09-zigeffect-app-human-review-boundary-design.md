# zigeffect App Human Review Boundary Design

Date: 2026-06-09

## Purpose

The app remediation lane can already produce three non-mutating artifacts:

- `zigeffect.causal.app-remediation-audit.v1`
- `zigeffect.causal.app-policy-decision.v1`
- `zigeffect.causal.app-patch-proposal.v1`

The current policy command correctly returns `needs-human-review` when an app
audit cites `migration-required`, `operational-human-required`, or
`rollback-required`. The patch proposal command still rejects those gates
entirely. This branch adds the missing human-review boundary so high-risk app
remediation can become reviewable without granting mutation authority.

The branch must preserve the core invariant:

```text
human review evidence may approve proposal drafting, but it never applies app
source, config, migrations, operational actions, rollback plans, or deployment
state.
```

## Current State

`causal-app-policy-decision` already classifies app policy gates:

- `source-only` and `config-only` produce `decision=approve`;
- `migration-required`, `operational-human-required`, and `rollback-required`
  produce `decision=needs-human-review`;
- unknown gates produce `decision=reject`.

`causal-app-patch-proposal` currently accepts only `decision=approve` policy
artifacts and rejects every high-risk gate, even if a malformed policy says it
is approved. That is safe, but it leaves no artifact contract for a reviewer to
record migration, runbook, or rollback evidence.

## Design Options

### Option A: Extend The Policy Decision Artifact

The policy artifact could grow reviewer fields such as `reviewed_by` and
`review_status`. This keeps one schema, but it muddles automated policy
evaluation with human judgment. It also makes it hard to tell whether a policy
decision was deterministic or manually reviewed.

### Option B: Add A Review Artifact Only

A new artifact could record review evidence while leaving patch proposals
unchanged. This is simple and useful for documentation, but it does not yet
create a real path to high-risk proposals.

### Option C: Add A Review Artifact And Require It For High-Risk Proposals

This adds a dedicated review boundary and teaches patch proposals to accept
high-risk gates only when a matching, approved, non-mutating review artifact is
provided. It preserves the existing low-risk path, keeps automated policy and
human review separate, and creates a concrete contract for the later app
application-readiness branch.

The chosen approach is Option C.

## New CLI

Add a sibling command:

```sh
zig build causal-app-human-review -- local \
  --policy .zig-cache/causal-artifacts/app-policy.json \
  --reviewer local-reviewer \
  --decision approve \
  --reason "migration plan and rollback notes reviewed" \
  --migration packages/app/migrations/001_add_status.sql \
  --runbook docs/runbooks/yachdee-migration.md \
  --rollback docs/runbooks/yachdee-rollback.md
```

Optional repeated citations:

```text
--file <path>
--config <key-or-binding-name>
--migration <path>
--runbook <path>
--rollback <path>
--verified <command>
--out-prefix <path-prefix>
```

Defaults:

- output prefix is the policy path without `.json`;
- JSON output is `<prefix>-app-human-review.json`;
- text output is `<prefix>-app-human-review.txt`.

Usage errors print:

```text
causal-app-human-review error: <error-name>
usage: zig build causal-app-human-review -- local --policy <app-policy-decision-json> --reviewer <actor> --decision <approve|reject|changes-requested> --reason <reason> [--file <path>] [--config <key>] [--migration <path>] [--runbook <path>] [--rollback <path>] [--verified <command>] [--out-prefix <path-prefix>]
```

## Input Validation

The human-review tool reads exactly one
`zigeffect.causal.app-policy-decision.v1` artifact with schema version 1.

It rejects:

- unsupported schema or schema version;
- non-local policy records;
- policy decisions other than `needs-human-review`;
- `approval_status` values other than `needs-human-review`;
- `applied=true`;
- `mutation_authority` values other than `none`;
- empty reviewer;
- empty reason;
- unknown review decision;
- policies with no high-risk gates;
- unknown policy gates;
- `migration-required` without at least one migration citation;
- `operational-human-required` without at least one runbook citation;
- `rollback-required` without at least one rollback citation.

The tool may carry through source/config citations, but those do not satisfy
the high-risk gates.

## Review Decision Semantics

The supported reviewer decisions are:

| CLI value | `review_status` | `approval_status` | `approved` | Meaning |
| --- | --- | --- | --- | --- |
| `approve` | `approved` | `approved` | `true` | Evidence is sufficient to draft a high-risk proposal. |
| `reject` | `rejected` | `rejected` | `false` | The remediation should not proceed. |
| `changes-requested` | `changes-requested` | `changes-requested` | `false` | More evidence or a different plan is needed. |

All outcomes preserve:

```json
{
  "applied": false,
  "mutation_authority": "none"
}
```

## Output Schema

Schema id:

```text
zigeffect.causal.app-human-review.v1
```

JSON shape:

```json
{
  "schema": "zigeffect.causal.app-human-review.v1",
  "schema_version": 1,
  "mode": "local",
  "target": "yachdee-platform",
  "review_status": "approved",
  "approval_status": "approved",
  "approved": true,
  "applied": false,
  "mutation_authority": "none",
  "reviewed_by": "local-reviewer",
  "reason": "migration plan and rollback notes reviewed",
  "source": {
    "policy": ".zig-cache/causal-artifacts/app-policy.json",
    "app_remediation_audit": ".zig-cache/causal-artifacts/app-audit.json",
    "app_artifact": ".zig-cache/causal-artifacts/app.json"
  },
  "policy_gates": ["migration-required", "rollback-required"],
  "citations": {
    "source_files": [],
    "config_keys": [],
    "migration_files": ["packages/app/migrations/001_add_status.sql"],
    "runbooks": ["docs/runbooks/yachdee-migration.md"],
    "rollback_plans": ["docs/runbooks/yachdee-rollback.md"]
  },
  "event_ids": [4],
  "required_verification_commands": [
    "zig build causal-query -- --file .zig-cache/causal-artifacts/app.json cause 4"
  ],
  "reviewed_verification_commands": [
    "zig build causal-query -- --file .zig-cache/causal-artifacts/app.json cause 4"
  ],
  "review_guardrails": [
    "Human review approves proposal drafting only; it does not apply app source, config, migrations, operations, rollback plans, or deployment state.",
    "Mutation authority remains none until a later reviewed application artifact records actual source/external-state changes and post-apply verification.",
    "High-risk citations must name files, runbooks, rollback plans, or command strings only; do not include secret values."
  ]
}
```

No timestamps are included.

## Text Report

```text
zigeffect app human review
schema: zigeffect.causal.app-human-review.v1
target: yachdee-platform
review_status: approved
approval_status: approved
approved: true
applied: false
mutation_authority: none
reviewed_by: local-reviewer
reason: migration plan and rollback notes reviewed

source:
- policy: .zig-cache/causal-artifacts/app-policy.json
- app remediation audit: .zig-cache/causal-artifacts/app-audit.json
- app artifact: .zig-cache/causal-artifacts/app.json

policy gates:
- migration-required
- rollback-required

citations:
- migration: packages/app/migrations/001_add_status.sql
- runbook: docs/runbooks/yachdee-migration.md
- rollback: docs/runbooks/yachdee-rollback.md

event ids:
- 4

required verification commands:
- zig build causal-query -- --file .zig-cache/causal-artifacts/app.json cause 4

reviewed verification commands:
- zig build causal-query -- --file .zig-cache/causal-artifacts/app.json cause 4

review guardrails:
- Human review approves proposal drafting only; it does not apply app source, config, migrations, operations, rollback plans, or deployment state.
```

## Patch Proposal Integration

Extend `causal-app-patch-proposal` with optional:

```text
--review <app-human-review-json>
```

Rules:

- Existing low-risk `decision=approve` policy decisions keep working without
  a review artifact.
- `decision=needs-human-review` policy decisions require a review artifact.
- The review artifact must use `zigeffect.causal.app-human-review.v1`, schema
  version 1, `mode=local`, `review_status=approved`,
  `approval_status=approved`, `approved=true`, `applied=false`, and
  `mutation_authority=none`.
- The review source policy path must match the policy path passed to
  `causal-app-patch-proposal`.
- The review target and policy gates must match the policy record.
- High-risk gate citations are satisfied by the review artifact:
  - `migration-required` requires `citations.migration_files`;
  - `operational-human-required` requires `citations.runbooks`;
  - `rollback-required` requires `citations.rollback_plans`.
- The generated patch proposal remains a draft and keeps
  `approved=false`, `applied=false`, and `mutation_authority=none`.
- The proposal `source` object includes `human_review` when a review artifact
  is used.

Malformed policy decisions that claim `approve` while carrying high-risk gates
remain rejected. The safe path is policy `needs-human-review` plus approved
human review evidence.

## Workbench Integration

The SolidJS workbench should recognize
`zigeffect.causal.app-human-review.v1` as kind `app-human-review`. The existing
app remediation Chain tab can render it with the same sections used for app
policy and app patch proposal artifacts:

- status metrics;
- source artifacts;
- policy gates;
- citations;
- verification commands;
- guardrails.

Add one development sample route:

```text
?sample=app-review
```

It should load `sample-app-human-review.json`.

## Documentation Impact

Update:

- `packages/zigeffect/README.md`
- `packages/zigeffect/docs/agent-guide.md`
- `packages/zigeffect/docs/agent-observable-runtime.md`
- `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`

The app remediation chain becomes:

```text
app causal artifact
  -> app remediation audit
  -> app policy decision
  -> app human review, when policy says needs-human-review
  -> app patch proposal
  -> future app application readiness
  -> future guarded app application record
```

## Non-Goals

- No automatic source edits.
- No config, secret, binding, migration, deployment, operational, or rollback
  mutation.
- No `applied=true` artifacts.
- No Cockroach adapter work.
- No durable backend changes; NenDB adapter direction remains separate and
  unchanged.
- No React rewrite. The workbench remains SolidJS hosted by `zig-webui`.
- No broad UI redesign.

## Tests And Verification

Focused Zig tests should prove:

- human-review usage text and schema id are stable;
- option parsing accepts repeated citations and reviewed commands;
- output paths derive from policy path and `--out-prefix`;
- `needs-human-review` policies with migration, runbook, and rollback
  citations produce non-mutating review artifacts;
- review artifacts reject low-risk approved policies;
- review artifacts reject missing high-risk citations;
- review artifacts reject already-applied or mutation-authority policy records;
- patch proposal rejects high-risk `needs-human-review` policies without a
  review artifact;
- patch proposal accepts high-risk policies with matching approved review
  evidence and still writes a draft, unapplied proposal;
- patch proposal rejects rejected or mismatched review artifacts.

Workbench tests should prove:

- `app-human-review` is recognized as governance/app remediation kind;
- `?sample=app-review` resolves to `sample-app-human-review.json`;
- citations and guardrails are exposed through the derived app model.

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

## Self-Review

- The review artifact is separate from deterministic app policy decisions.
- High-risk proposals require approved human review evidence.
- Approved human review still does not mutate anything.
- `applied=true` is reserved for a future application artifact after actual
  source or external-state changes and post-apply verification.
- The design preserves the SolidJS plus `zig-webui` workbench direction.
- The design does not introduce Cockroach adapter work and does not change the
  existing NenDB adapter scope.
