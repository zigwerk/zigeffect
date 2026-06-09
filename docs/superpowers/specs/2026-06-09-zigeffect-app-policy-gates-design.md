# zigeffect App Policy Gates Design

Date: 2026-06-09

## Purpose

M8 now has a non-mutating app remediation audit artifact:
`zigeffect.causal.app-remediation-audit.v1`. It records app incident event ids,
query commands, advisory app gates, and the review boundary with
`approval_status=pending`, `applied=false`, and `mutation_authority=none`.

This branch adds the next controlled step:

```sh
zig build causal-app-policy-decision -- local --audit <app-remediation-audit-json>
```

The command evaluates app remediation audit artifacts against the five M8 gate
families:

- `source-only`;
- `config-only`;
- `migration-required`;
- `operational-human-required`;
- `rollback-required`.

It writes schema-versioned JSON plus text. It does not approve source mutation,
apply patches, edit config, run migrations, execute operational actions, or mark
the app audit as applied.

## Current State

The core `causal-policy-decision` tool evaluates the full local
self-improvement chain: remediation audit, manual decision, patch proposal,
audit chain, registry patch, readiness, and registry application artifacts.
That is appropriate for registered `zigeffect` scenarios.

Application remediation starts earlier. An app agent may only have a saved app
causal artifact and a derived app remediation audit. App policy needs to answer
one narrower question before app patch proposals exist: what kind of review or
proposal is allowed next, given the gates cited by this app audit?

## Design Choice

Three approaches were considered:

- **Extend `causal-policy-decision`.** This keeps one policy command, but it
  would force app audits into the core scenario chain and require artifacts
  that app incidents do not have yet.
- **Add gate enforcement inside `causal-app-remediation-audit`.** This is
  tempting because the audit already emits gates, but it mixes evidence capture
  with policy evaluation and makes it harder to review policy changes.
- **Add a sibling app policy command.** This keeps a clean boundary: app audit
  records evidence; app policy evaluates gates; app patch proposals come next.

The chosen approach is the sibling app policy command.

## Command Shape

Required:

```sh
zig build causal-app-policy-decision -- local --audit .zig-cache/causal-artifacts/app-app-remediation-audit.json
```

Optional:

```sh
zig build causal-app-policy-decision -- local \
  --audit .zig-cache/causal-artifacts/app-app-remediation-audit.json \
  --policy local-app-remediation-policy-v1 \
  --by local-policy-engine \
  --out-prefix .zig-cache/causal-artifacts/yachdee-platform
```

Defaults:

- `mode` is `local`.
- `policy` is `local-app-remediation-policy-v1`.
- `evaluated_by` is `local-app-policy-engine`.
- output prefix is the audit path without `.json`.
- JSON output is `<prefix>-app-policy-decision.json`.
- text output is `<prefix>-app-policy-decision.txt`.

Usage errors print:

```text
causal-app-policy-decision error: <error-name>
usage: zig build causal-app-policy-decision -- local --audit <app-remediation-audit-json> [--policy <policy>] [--by <actor>] [--out-prefix <path-prefix>]
```

## Input Schema

The command reads one `zigeffect.causal.app-remediation-audit.v1` artifact with
schema version 1.

Required fields:

- `mode`;
- `target`;
- `source.app_artifact`;
- `approval_status`;
- `applied`;
- `mutation_authority`;
- `incidents`;
- `policy_gates`;
- `verification_commands`;
- `claim_guardrails`.

The policy command validates:

- audit schema and version are supported;
- `mode = "local"`;
- audit is still pending;
- audit is not applied;
- audit mutation authority is `none`;
- all incident gates are known;
- top-level `policy_gates` include every incident gate.

## Output Schema

Schema id:

```text
zigeffect.causal.app-policy-decision.v1
```

Fields:

```json
{
  "schema": "zigeffect.causal.app-policy-decision.v1",
  "schema_version": 1,
  "mode": "local",
  "target": "yachdee-platform",
  "decision": "approve",
  "approval_status": "approve",
  "evaluated_by": "local-app-policy-engine",
  "policy": "local-app-remediation-policy-v1",
  "reason": "app audit is eligible for proposal drafting",
  "reason_codes": ["app-gates-proposal-eligible"],
  "mutation_authority": "none",
  "applied": false,
  "source": {
    "app_remediation_audit": ".zig-cache/causal-artifacts/app-app-remediation-audit.json",
    "app_artifact": ".zig-cache/causal-artifacts/app.json"
  },
  "policy_gates": ["config-only", "source-only"],
  "gate_results": [
    {
      "gate": "config-only",
      "status": "allow-proposal",
      "detail": "configuration proposal may be drafted without exposing secrets"
    }
  ],
  "event_ids": [2, 3, 4],
  "required_verification_commands": [
    "zig build causal-query -- --file .zig-cache/causal-artifacts/app.json cause 2"
  ],
  "guardrails": [
    "Policy approval is advisory and does not apply app source, config, migrations, operations, or rollback actions."
  ]
}
```

No timestamps are included.

## Gate Semantics

Gate outcomes:

| Gate | Status | Decision effect | Meaning |
| --- | --- | --- | --- |
| `source-only` | `allow-proposal` | can approve | Source-only app patch proposal may be drafted. |
| `config-only` | `allow-proposal` | can approve | Config/secret-binding proposal may be drafted, but secrets must not be exposed. |
| `migration-required` | `human-review-required` | needs human review | A data/schema migration plan is required before proposals proceed. |
| `operational-human-required` | `human-review-required` | needs human review | An operator-run action or runbook is required. |
| `rollback-required` | `human-review-required` | needs human review | A rollback plan or incident response review is required first. |
| unknown gate | `blocked` | reject | The policy cannot classify the remediation safely. |

Decision rules:

- `reject` if the audit schema is unsupported, the audit is already applied, the
  audit mutation authority is not `none`, or an unknown gate appears.
- `needs-human-review` if any known high-risk gate appears:
  `migration-required`, `operational-human-required`, or `rollback-required`.
- `approve` only when all gates are known and limited to `source-only` and/or
  `config-only`.

`approve` authorizes only the next artifact step: drafting an app patch proposal
for review. It never authorizes applying a change.

## Text Report Shape

```text
zigeffect app policy decision
schema: zigeffect.causal.app-policy-decision.v1
target: yachdee-platform
decision: approve
approval_status: approve
evaluated_by: local-app-policy-engine
policy: local-app-remediation-policy-v1
reason: app audit is eligible for proposal drafting
mutation_authority: none
applied: false

source:
- app remediation audit: .zig-cache/causal-artifacts/app-app-remediation-audit.json
- app artifact: .zig-cache/causal-artifacts/app.json

policy gates:
- config-only allow-proposal
- source-only allow-proposal

event ids:
- 2
- 3
- 4

required verification commands:
- zig build causal-query -- --file .zig-cache/causal-artifacts/app.json cause 2

guardrails:
- Policy approval is advisory and does not apply app source, config, migrations, operations, or rollback actions.
```

## Workbench Integration

The SolidJS workbench should recognize
`zigeffect.causal.app-policy-decision.v1` as kind `app-policy-decision`.
The first UI pass only needs governance summary support:

- target;
- decision;
- applied;
- mutation authority;
- summary such as `approve app policy decision for yachdee-platform`.

Detailed gate tables can come with the app patch proposal or app incident
workbench branch.

## Tests And Verification

Focused tests should prove:

- command usage text is stable;
- output paths derive from audit path and `--out-prefix`;
- supported app audits with `source-only` and `config-only` approve proposal
  drafting while preserving `mutation_authority=none` and `applied=false`;
- audits with `migration-required`, `operational-human-required`, or
  `rollback-required` return `needs-human-review`;
- unknown gates are rejected;
- applied audits are rejected;
- workbench governance detection recognizes the app policy decision schema.

Verification commands:

```sh
cd packages/zigeffect && zig build causal-app-policy-decision
cd packages/zigeffect && zig build examples
cd packages/zigeffect && zig build test
bun run zigeffect:workbench:test
bun run zigeffect:workbench:typecheck
bun run check
bun run zig:test
git diff --check
```

The no-argument build step should be treated as argument-gated, like other
policy/remediation tools. Unit tests provide the content verification.

## Future Branch Handoff

The next M8 branch, `codex/zigeffect-app-patch-proposal`, should consume
`app-policy-decision` artifacts. It should allow source/config proposal
drafting only when the app policy decision is `approve`, and require separate
human-reviewed inputs for migration, operational, or rollback gates.
