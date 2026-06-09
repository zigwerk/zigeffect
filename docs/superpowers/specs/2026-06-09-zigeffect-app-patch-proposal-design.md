# zigeffect App Patch Proposal Design

## Context

M8 now has two app remediation artifacts:

- `zigeffect.causal.app-remediation-audit.v1` records app incidents, policy
  gates, causal event ids, and required verification while preserving
  `mutation_authority=none` and `applied=false`.
- `zigeffect.causal.app-policy-decision.v1` evaluates those gates and only
  returns `approve` when every gate is low-risk (`source-only` or
  `config-only`).

The next step is a non-mutating app patch proposal artifact. It should consume
an approved app policy decision and turn it into a reviewable, citation-rich
proposal that tells a developer or agent what app files, config keys,
migration files, operational runbooks, or rollback plans are involved. It must
not edit the app, write a registry entry, apply infrastructure, run migrations,
or claim remediation.

The workbench direction remains SolidJS hosted by `webui-dev/zig-webui`.
`zig-webui` is appropriate for this roadmap because it keeps Zig in the local
backend and uses modern web frontend technology for inspection surfaces. The app
patch proposal schema should be frontend-agnostic so the SolidJS workbench can
render it later without changing the causal control boundary.

## Goals

- Add `zig build causal-app-patch-proposal -- local --policy
  <app-policy-decision-json> --summary <summary> --change <description>` with
  repeated citation flags for app source, config, migrations, runbooks, and
  rollback plans.
- Emit schema-versioned JSON and a concise human text report.
- Preserve the safety posture:
  - `proposal_status=draft`
  - `approval_status=pending`
  - `approved=false`
  - `applied=false`
  - `mutation_authority=none`
- Require a policy decision with `decision=approve`, `approval_status=approve`,
  `applied=false`, and `mutation_authority=none`.
- Validate that policy gates are matched by the minimum needed citations:
  - `source-only` requires at least one `--file`.
  - `config-only` requires at least one `--config`.
  - high-risk gates are rejected until a later human-reviewed workflow exists.
- Register the schema in the workbench governance detector.
- Update docs and roadmaps so the next M8 branch is the detailed SolidJS
  app-remediation workbench surface.

## Non-Goals

- No automatic source edits.
- No config, secret, binding, migration, deployment, or rollback mutation.
- No React rewrite. The chosen workbench path remains SolidJS plus
  `zig-webui`.
- No CockroachDB-specific adapter work. Durable database work remains limited to
  the planned NenDB adapter path unless explicitly changed later.
- No human-review bypass for `migration-required`, `operational-human-required`,
  or `rollback-required` gates.

## Proposed CLI

```sh
zig build causal-app-patch-proposal -- local \
  --policy .zig-cache/causal-artifacts/app-app-remediation-audit-app-policy-decision.json \
  --summary "Wire missing HealthService provider and document YACHDEE_ENV binding" \
  --change "Add the missing app layer provider and update local config binding docs." \
  --file apps/platform/src/worker.ts \
  --config YACHDEE_ENV
```

Optional repeated citations:

```sh
--file <path>
--config <key-or-binding-name>
--migration <path>
--runbook <path>
--rollback <path>
--out-prefix <path-prefix>
```

Default output paths derive from the policy path:

```text
<policy-prefix>-app-patch-proposal.json
<policy-prefix>-app-patch-proposal.txt
```

For example:

```text
.zig-cache/causal-artifacts/app-app-remediation-audit-app-policy-decision-app-patch-proposal.json
.zig-cache/causal-artifacts/app-app-remediation-audit-app-policy-decision-app-patch-proposal.txt
```

## JSON Schema Shape

```json
{
  "schema": "zigeffect.causal.app-patch-proposal.v1",
  "schema_version": 1,
  "mode": "local",
  "target": "yachdee-platform",
  "proposal_status": "draft",
  "approval_status": "pending",
  "approved": false,
  "applied": false,
  "mutation_authority": "none",
  "summary": "Wire missing HealthService provider and document YACHDEE_ENV binding",
  "change": "Add the missing app layer provider and update local config binding docs.",
  "source": {
    "policy": ".zig-cache/causal-artifacts/app-policy.json",
    "app_remediation_audit": ".zig-cache/causal-artifacts/app-audit.json",
    "app_artifact": ".zig-cache/causal-artifacts/app.json"
  },
  "policy_gates": ["config-only", "source-only"],
  "citations": {
    "source_files": ["apps/platform/src/worker.ts"],
    "config_keys": ["YACHDEE_ENV"],
    "migration_files": [],
    "runbooks": [],
    "rollback_plans": []
  },
  "event_ids": [2, 3],
  "required_verification_commands": [
    "zig build causal-query -- --file .zig-cache/causal-artifacts/app.json cause 2"
  ],
  "claim_guardrails": [
    "Do not claim an app fix without rerunning the app request/job scenario."
  ],
  "proposal_guardrails": [
    "This proposal does not edit app source, config, migrations, operations, or rollback plans.",
    "Policy approval only authorizes drafting; the proposal still requires review before application.",
    "Config citations name keys or bindings only; never include secret values."
  ]
}
```

## Validation Rules

The tool should reject:

- unsupported schema or schema version;
- non-local policy records;
- `decision` values other than `approve`;
- `approval_status` values other than `approve`;
- `applied=true`;
- `mutation_authority` values other than `none`;
- missing summary or change text;
- no citations at all;
- `source-only` policy gates without a source file citation;
- `config-only` policy gates without a config citation;
- any high-risk or unknown gate, even if a malformed policy says `approve`.

High-risk gate names are:

- `migration-required`
- `operational-human-required`
- `rollback-required`

## Tool Boundary

Create `packages/zigeffect/tools/causal_app_patch_proposal.zig` as a sibling of
the core `causal_patch_proposal.zig`. The new tool should duplicate only the
small app-specific JSON structs it needs instead of importing private structs
from the policy tool. That keeps each CLI artifact boundary stable and avoids a
large shared abstraction before the schema settles.

The tool should include tests for:

- usage text;
- repeated citation parsing;
- default output path derivation;
- successful proposal formatting from an approved app policy;
- rejection of non-approved policy decisions;
- rejection of missing required citations for source/config gates;
- JSON/text report fields that prove the mutation boundary is preserved.

## Workbench Impact

This branch should only register the new schema in
`packages/zigeffect/workbench/src/causalArtifact.ts` and add focused tests.
Detailed UI rendering belongs in the next branch:

```text
codex/zigeffect-app-remediation-workbench
```

That branch should use the existing SolidJS workbench hosted by `zig-webui`,
not React, and should render app audit, policy, and proposal details together.

## Documentation Impact

Update:

- `packages/zigeffect/README.md`
- `packages/zigeffect/docs/agent-guide.md`
- `packages/zigeffect/docs/agent-observable-runtime.md`
- `packages/zigeffect/docs/roadmap.md`
- `docs/superpowers/specs/2026-06-08-zigeffect-causal-agent-runtime-master-roadmap.md`

The docs should make the chain explicit:

```text
app causal artifact
  -> app remediation audit
  -> app policy decision
  -> app patch proposal
  -> future reviewed application boundary
```

## Verification

Required verification before completion:

```sh
cd packages/zigeffect && zig build examples
cd packages/zigeffect && zig build test
bun run zigeffect:workbench:test
bun run zigeffect:workbench:typecheck
bun run check
bun run zig:test
git diff --check
```

## Self-Review

- No placeholders remain.
- The proposal boundary is explicitly non-mutating.
- The policy `approve` meaning is narrow: it permits draft proposal creation,
  not application.
- SolidJS plus `zig-webui` is preserved as the workbench direction.
- NenDB remains the only durable database adapter direction in scope; Cockroach
  adapter work is not introduced here.
