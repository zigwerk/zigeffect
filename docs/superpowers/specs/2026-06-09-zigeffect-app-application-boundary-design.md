# zigeffect App Application Boundary Design

Date: 2026-06-09

## Purpose

The app remediation lane can now produce non-mutating readiness evidence:

```text
app causal artifact
  -> app remediation audit
  -> app policy decision
  -> app human review, when required
  -> app patch proposal
  -> app application readiness
```

The missing boundary is the guarded app application record. This boundary
consumes `zigeffect.causal.app-application-readiness.v1` and writes a new
artifact that says one of three things:

- the reviewed app change is planned but not applied;
- the reviewed app change is blocked and must not be claimed;
- the reviewed app change was applied, with before/after evidence and
  post-application verification recorded.

This is a record-only boundary. It does not edit source, config, migrations,
operations, rollback plans, deployment state, databases, queues, or any
external system. Its job is to make `applied=true` scarce and meaningful.

## Current Context

The closest precedent is `causal-registry-apply`. That tool has two modes:

- `plan`: preserve the application plan with `applied=false`;
- `record-applied`: emit `applied=true` only when source-state checks and
  verification evidence pass.

The app boundary follows the same shape, but app changes are broader than the
scenario registry. An app proposal can touch source files, config keys,
migration files, operational runbooks, and rollback plans. The app application
record therefore validates evidence by policy-gate category rather than by
inspecting one registry table.

## Chosen Approach

Implement a new Zig tool named:

```sh
zig build causal-app-apply -- \
  --from-readiness <app-application-readiness-json> \
  plan|record-applied \
  --reason <reason> \
  [--by <actor>] \
  [--policy <policy>] \
  [--verified-command <command>]... \
  [--source-change <path>]... \
  [--config-change <key-or-binding>]... \
  [--migration-change <path>]... \
  [--operation-change <runbook-or-operation>]... \
  [--rollback-change <path>]... \
  [--before <artifact-or-evidence>]... \
  [--after <artifact-or-evidence>]...
```

Default values:

- `--by`: `local-reviewer`
- `--policy`: `manual-app-application`

When the readiness path ends with:

```text
-app-application-readiness.json
```

the tool writes:

```text
<prefix>-app-application.json
<prefix>-app-application.txt
```

## Alternatives Considered

### A: Reuse `causal-registry-apply`

This would keep one command for all application records, but the registry
command has registry-specific source checks, scenario docs checks, and
not-applicable semantics. Adding app evidence categories there would blur the
boundary and make the command harder for agents to reason about.

### B: Make the app command actually apply changes

This is deliberately deferred. Source mutation, config updates, migration
runs, and external operations each need their own reviewed backend boundaries.
Combining them here would make `applied=true` too easy to emit without enough
domain-specific safety.

### C: New record-only app command

This is the selected approach. It mirrors the registry application artifact,
but stays honest about what can be checked locally today. It requires explicit
evidence from the real application step, then records the result for agents,
the workbench, CI, and future policy tools.

## Input Schema

The input artifact must be:

```text
zigeffect.causal.app-application-readiness.v1
```

Required readiness fields:

- `schema`
- `schema_version`
- `mode`
- `source_proposal`
- `decision`
- `readiness_status`
- `ready_for_application`
- `reviewed_by`
- `policy`
- `reason`
- `applied`
- `mutation_authority`
- `target`
- `summary`
- `change`
- `source`
- `policy_gates`
- `citations`
- `event_ids`
- `checks`
- `required_verification_commands`
- `verified_commands`
- `application_steps`
- `readiness_guardrails`

The input readiness artifact must satisfy:

```text
schema=zigeffect.causal.app-application-readiness.v1
schema_version=1
mode=local
applied=false
mutation_authority=none
source_proposal ends with -app-patch-proposal.json
readiness_status is ready or blocked
ready_for_application matches readiness_status=ready
```

For any applied result, the input must additionally satisfy:

```text
decision=approve
readiness_status=ready
ready_for_application=true
```

## Output Schema

The output schema is:

```text
zigeffect.causal.app-application.v1
```

JSON fields:

```json
{
  "schema": "zigeffect.causal.app-application.v1",
  "schema_version": 1,
  "source_readiness": ".zig-cache/causal-artifacts/yachdee-platform-app-application-readiness.json",
  "source_proposal": ".zig-cache/causal-artifacts/yachdee-platform-app-patch-proposal.json",
  "mode": "record-applied",
  "application_status": "applied",
  "applied": true,
  "mutation_authority": "record-only",
  "applied_by": "local-reviewer",
  "policy": "manual-app-application",
  "reason": "reviewed source/config update landed and post-apply verification passed",
  "readiness_status": "ready",
  "ready_for_application": true,
  "target": "yachdee-platform",
  "summary": "Fix request failure by adding missing service wiring",
  "change": "Update app source and config binding docs",
  "source": {
    "readiness": ".zig-cache/causal-artifacts/yachdee-platform-app-application-readiness.json",
    "proposal": ".zig-cache/causal-artifacts/yachdee-platform-app-patch-proposal.json",
    "policy": ".zig-cache/causal-artifacts/yachdee-platform-app-policy-decision.json",
    "human_review": ".zig-cache/causal-artifacts/yachdee-platform-app-human-review.json",
    "app_remediation_audit": ".zig-cache/causal-artifacts/yachdee-platform-app-remediation-audit.json",
    "app_artifact": ".zig-cache/causal-artifacts/yachdee-platform-app.json"
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
      "name": "readiness-schema",
      "status": "pass",
      "detail": "app application readiness schema is supported"
    },
    {
      "name": "readiness-ready",
      "status": "pass",
      "detail": "readiness is ready for app application"
    },
    {
      "name": "decision-approved",
      "status": "pass",
      "detail": "readiness decision approved application"
    },
    {
      "name": "change-evidence-present",
      "status": "pass",
      "detail": "caller recorded evidence for every policy-gate change category"
    },
    {
      "name": "before-after-evidence-present",
      "status": "pass",
      "detail": "caller recorded before and after evidence"
    },
    {
      "name": "post-verification-recorded",
      "status": "pass",
      "detail": "caller recorded required post-application verification commands"
    }
  ],
  "required_verification_commands": [
    "zig build causal-query -- --file .zig-cache/causal-artifacts/app.json cause 2"
  ],
  "verified_commands": [
    "zig build causal-query -- --file .zig-cache/causal-artifacts/app.json cause 2"
  ],
  "change_evidence": {
    "source_changes": ["apps/platform/src/worker.ts"],
    "config_changes": ["YACHDEE_API_BASE_URL"],
    "migration_changes": [],
    "operation_changes": [],
    "rollback_changes": []
  },
  "before_evidence": [
    ".zig-cache/causal-artifacts/yachdee-platform-before-app.json"
  ],
  "after_evidence": [
    ".zig-cache/causal-artifacts/yachdee-platform-after-app.json"
  ],
  "application_steps": [
    "Keep this application artifact with the reviewed change evidence.",
    "Do not rerun application unless source, external state, or verification evidence changes."
  ],
  "guardrails": [
    "applied=true means reviewed changes and before/after verification evidence passed every application check.",
    "This command records application state; it does not silently mutate source or external systems."
  ]
}
```

Text output should contain the same information in a scanner-friendly order:

```text
zigeffect app application
schema: zigeffect.causal.app-application.v1
source readiness: <path>
source proposal: <path>
mode: record-applied
application_status: applied
applied: true
mutation_authority: record-only
applied_by: local-reviewer
policy: manual-app-application
reason: ...
readiness_status: ready
ready_for_application: true
target: yachdee-platform
summary: ...
change: ...

checks:
- readiness-schema: pass - app application readiness schema is supported
- readiness-ready: pass - readiness is ready for app application
- decision-approved: pass - readiness decision approved application
- change-evidence-present: pass - caller recorded evidence for every policy-gate change category
- before-after-evidence-present: pass - caller recorded before and after evidence
- post-verification-recorded: pass - caller recorded required post-application verification commands

change evidence:
- source: apps/platform/src/worker.ts
- config: YACHDEE_API_BASE_URL

before evidence:
- .zig-cache/causal-artifacts/yachdee-platform-before-app.json

after evidence:
- .zig-cache/causal-artifacts/yachdee-platform-after-app.json

required verification:
- ...

verified commands:
- ...

application steps:
- ...

guardrails:
- ...
```

## Mode Semantics

### `plan`

Plan mode consumes readiness and writes an artifact with:

```text
mode=plan
application_status=planned
applied=false
mutation_authority=none
```

If readiness is blocked, the output becomes:

```text
application_status=blocked
applied=false
mutation_authority=none
```

Plan mode does not require before/after evidence because it does not claim an
application happened.

### `record-applied`

Record-applied mode is the only mode that may write:

```text
application_status=applied
applied=true
mutation_authority=record-only
```

It may do so only when every application check passes. If any check fails, the
artifact is still written as:

```text
application_status=blocked
applied=false
mutation_authority=none
```

`mutation_authority=record-only` means the command is authorized to record an
application claim after evidence exists. It does not mean the command mutated
the app.

## Application Checks

The tool records these checks:

- `readiness-schema`: input schema and version are supported.
- `readiness-ready`: readiness says `ready` and `ready_for_application=true`.
- `decision-approved`: readiness decision is `approve`.
- `change-evidence-present`: caller recorded evidence for each policy-gate
  category that requires a change.
- `before-after-evidence-present`: caller recorded at least one `--before` and
  at least one `--after` item in `record-applied` mode.
- `post-verification-recorded`: every readiness
  `required_verification_commands` entry appears in caller-supplied
  `--verified-command` values in `record-applied` mode.

`plan` mode records the first three checks and skips the evidence-only checks.
`record-applied` mode records every check.

## Evidence Rules

Policy gates map to required evidence categories:

- `source-only` requires at least one `--source-change`.
- `config-only` requires at least one `--config-change`.
- `migration-required` requires at least one `--migration-change`.
- `operational-human-required` requires at least one `--operation-change`.
- `rollback-required` requires at least one `--rollback-change`.

The change evidence does not need to duplicate every citation. It must prove
that each affected category was considered during real application. The
citations from readiness remain the authoritative proposal scope.

Before/after evidence is intentionally string-based in v1. It can point to:

- causal app artifacts captured before and after the change;
- command output files;
- migration dry-run or apply logs with secrets redacted;
- deployment or operations check records;
- rollback verification records.

The tool records paths or labels supplied by the caller. It does not read those
files in v1.

## Failure Posture

The command fails closed for malformed input:

- unsupported readiness schema or schema version;
- non-local readiness mode;
- empty target, summary, change, or reason;
- readiness already marked `applied=true`;
- readiness `mutation_authority` not equal to `none`;
- missing or invalid `source_proposal`;
- unknown mode or flag.

For valid but insufficient evidence, the command writes a blocked artifact
rather than crashing. This preserves the failed attempt as useful causal
evidence while preventing `applied=true`.

## Workbench Integration

The SolidJS workbench should recognize:

```text
zigeffect.causal.app-application.v1
```

as:

```text
app-application
```

Required model updates:

- add `app-application` to governance kinds;
- add `app-application` to app remediation kinds;
- surface `application_status`, `readiness_status`,
  `ready_for_application`, `applied`, and `mutation_authority`;
- include source links for readiness, proposal, policy, human review, app
  remediation audit, and app artifact when present;
- include citations, checks, required verification, verified commands,
  application steps, and guardrails;
- expose `change_evidence`, `before_evidence`, and `after_evidence`;
- add `?sample=app-application` resolving to
  `sample-app-application.json`.

The UI direction is SolidJS hosted by `webui-dev/zig-webui`. React remains a
reasonable future option for larger app surfaces, but it is out of scope for
this workbench. Unless a later design explicitly changes direction, zigeffect
inspection surfaces should continue to use the existing SolidJS renderer and
the Zig-hosted `zig-webui` local shell.

## Documentation Updates

Update:

- `packages/zigeffect/README.md`
- `packages/zigeffect/docs/agent-guide.md`
- `packages/zigeffect/docs/agent-observable-runtime.md`
- `packages/zigeffect/docs/roadmap.md`
- `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`

The roadmap should mark the app application boundary as delivered after this
branch and move the immediate queue to the next production operating-model
work, likely schema/versioning governance and operations docs before any deeper
automation.

## Non-Goals

- No React rewrite.
- No general patch application.
- No source editing from Zig.
- No config mutation.
- No migration runner.
- No deployment runner.
- No external-state mutation.
- No durable backend.
- No NenDB adapter work in this branch.
- No Cockroach adapter work.
- No production policy engine changes.

## Test Plan

Zig tests:

- plan mode creates a planned app application report for ready readiness;
- blocked readiness creates blocked application and keeps `applied=false`;
- record-applied without change evidence or before/after evidence blocks;
- record-applied with source/config evidence, before/after evidence, and every
  required verification command records `applied=true`;
- high-risk gates require migration, operation, and rollback evidence by
  category;
- output paths map `*-app-application-readiness.json` to
  `*-app-application.json` and `*-app-application.txt`;
- text output includes application status, evidence, verification, and
  guardrails.

Workbench tests:

- governance derivation detects `app-application`;
- app remediation derivation reads `application_status`, change evidence, and
  before/after evidence;
- `?sample=app-application` resolves to `sample-app-application.json`.

Verification commands:

```sh
zig build examples
zig build test
bun run zigeffect:workbench:test
bun run zigeffect:workbench:typecheck
bun run zigeffect:workbench:build
bun run check
bun run zig:test
git diff --check
```

Browser QA:

- launch `bun run zigeffect:workbench:dev`;
- open `http://127.0.0.1:5173/?sample=app-application`;
- verify desktop and mobile layouts show app application status, evidence,
  before/after evidence, source links, checks, verification, and guardrails
  without text overlap.

## Acceptance Criteria

- `zig build causal-app-apply -- --from-readiness <ready-readiness> plan
  --reason <reason>` writes `application_status=planned` and `applied=false`.
- `record-applied` never writes `applied=true` unless readiness is ready,
  decision is approved, required change evidence exists, before/after evidence
  exists, and required post-application verification commands are recorded.
- The artifact makes clear that this command records state but does not mutate
  source or external systems.
- The SolidJS `zig-webui` workbench can inspect the new artifact as part of the
  app remediation chain.
- Roadmap and guide docs explain that readiness is not application and that
  this boundary is the first place an app remediation lane may record
  `applied=true`.
