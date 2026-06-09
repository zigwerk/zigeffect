# zigeffect App Remediation Audit Design

Date: 2026-06-09

## Purpose

M7 made application evidence observable: `CausalAppTrace` can capture bounded
request/job traces, app examples emit standard causal JSON, and app incident
mapping turns config, requirement, response, retry, resource, finalizer, and
fiber evidence into app-specific advice and diagnosis actions.

M8 starts the controlled app remediation lane. The first branch adds a
non-mutating app remediation audit artifact:

```sh
zig build causal-app-remediation-audit -- local --artifact <causal-json> --target <app-target>
```

The command reads a saved app causal artifact, derives app-specific remediation
actions through the same app action vocabulary used by `causal-advice` and
`causal-diagnosis`, and writes schema-versioned JSON plus a human text report.
It does not approve, reject, apply, patch source, edit config, run migrations,
call external services, or mutate application state.

## Current State

The core self-improvement lane already has this controlled chain:

```text
dev-loop verdict -> diagnosis -> remediation plan -> remediation audit
-> manual decision -> patch proposal -> audit chain -> registry readiness
-> registry application -> policy decision
```

That chain is centered on registered local `zigeffect` scenarios. Application
incidents are different: they may come from Worker requests, background jobs,
R2/Durable Object logs, app-owned CI artifacts, or later durable history stores.
They need an audit entry point that can start from a single app causal JSON file
without requiring a dev-loop verdict or a registered core scenario.

## Design Choice

Three approaches were considered:

- **Extend `causal-remediation-audit` directly.** This would reuse many helper
  shapes, but it would overload a dev-loop command with app artifact semantics
  and make the required input bundle ambiguous.
- **Build the complete app remediation chain at once.** This would cover audit,
  decision, proposal, policy, and workbench integration in one branch, but it
  would blur the `applied=false` boundary and make review too large.
- **Add a sibling app audit command first.** This keeps the first M8 artifact
  small, deterministic, and reviewable while preserving a stable schema for the
  upcoming app decision, policy, patch proposal, and workbench branches.

The chosen path is the sibling app audit command.

## Command Shape

Required:

```sh
zig build causal-app-remediation-audit -- local --artifact .zig-cache/causal-artifacts/app.json --target yachdee-platform
```

Optional:

```sh
zig build causal-app-remediation-audit -- local \
  --artifact .zig-cache/causal-artifacts/app.json \
  --target yachdee-platform \
  --proposer local-agent \
  --out-prefix .zig-cache/causal-artifacts/yachdee-platform
```

Defaults:

- `mode` is `local`.
- `proposer` is `local-agent`.
- output prefix is the artifact path without `.json`.
- JSON output is `<prefix>-app-remediation-audit.json`.
- text output is `<prefix>-app-remediation-audit.txt`.

Usage errors print:

```text
causal-app-remediation-audit error: <error-name>
usage: zig build causal-app-remediation-audit -- local --artifact <path> --target <name> [--proposer <id>] [--out-prefix <path-prefix>]
```

## Inputs

The first implementation reads one app causal artifact with:

- `schema = "zigeffect.causal.v1"`;
- `schema_version <= 1`;
- `event_taxonomy_version <= 1`;
- an `events` array.

The command may use `causal_advice.buildAdviceReport` internally so app action
selection stays aligned with the advice tool. It then filters to app actions:

- `fix-app-config`;
- `wire-app-requirement`;
- `inspect-app-response-failure`;
- `inspect-app-retry-exhaustion`;
- `close-app-resource`;
- `resolve-app-fiber`.

The command should reject artifacts that produce no app remediation actions with
`NoAppRemediationActions`. A future no-op audit mode can be added if application
operators need explicit "no app action" artifacts.

## JSON Schema

Schema id:

```text
zigeffect.causal.app-remediation-audit.v1
```

Fields:

```json
{
  "schema": "zigeffect.causal.app-remediation-audit.v1",
  "schema_version": 1,
  "mode": "local",
  "target": "yachdee-platform",
  "proposer": "local-agent",
  "source": {
    "app_artifact": ".zig-cache/causal-artifacts/app.json",
    "advice": "inline-generated"
  },
  "approval_status": "pending",
  "applied": false,
  "mutation_authority": "none",
  "incident_count": 3,
  "incidents": [
    {
      "action": "fix-app-config",
      "event_id": 2,
      "event_kind": "assertion_recorded",
      "label": "YACHDEE_ENV",
      "subsystem": "app_config",
      "fix_category": "config-or-secret-binding",
      "policy_gate": "config-only",
      "query_commands": [
        "zig build causal-query -- --file .zig-cache/causal-artifacts/app.json cause 2",
        "zig build causal-query -- --file .zig-cache/causal-artifacts/app.json lineage 2"
      ]
    }
  ],
  "policy_gates": ["config-only", "source-only"],
  "verification_commands": [
    "zig build causal-query -- --file .zig-cache/causal-artifacts/app.json cause 2",
    "zig build causal-query -- --file .zig-cache/causal-artifacts/app.json lineage 2"
  ],
  "claim_guardrails": [
    "Do not claim an app fix without rerunning the app request/job scenario that produced the cited artifact.",
    "Do not expose secret values while fixing config or binding incidents.",
    "Do not set applied=true from this audit; only a later reviewed application artifact may do that."
  ]
}
```

The schema intentionally has no timestamps. Deterministic local output is easier
for agents to diff, test, and cite.

## Incident Mapping

The app audit layer maps advice actions to app remediation metadata:

| Action | Subsystem | Fix category | Policy gate |
| --- | --- | --- | --- |
| `fix-app-config` | `app_config` | `config-or-secret-binding` | `config-only` |
| `wire-app-requirement` | `app_service_layer` | `service-provider-or-layer` | `source-only` |
| `inspect-app-response-failure` | `app_request_path` | `response-or-handler-failure` | `source-only` |
| `inspect-app-retry-exhaustion` | `app_dependency` | `retry-policy-or-upstream` | `source-only` |
| `close-app-resource` | `app_resource_scope` | `resource-finalizer` | `source-only` |
| `resolve-app-fiber` | `app_fiber_runtime` | `structured-concurrency` | `source-only` |

`migration-required`, `operational-human-required`, and `rollback-required`
remain future policy outcomes. This branch may name them in documentation, but
it should not emit them unless an action clearly proves that gate.

## Text Report Shape

```text
zigeffect app remediation audit
schema: zigeffect.causal.app-remediation-audit.v1
mode: local
target: yachdee-platform
proposer: local-agent
approval_status: pending
applied: false
mutation_authority: none
incidents: 3

source:
- app artifact: .zig-cache/causal-artifacts/app.json
- advice: inline-generated

policy gates:
- config-only
- source-only

incidents:
- event 2 action=fix-app-config gate=config-only subsystem=app_config label=YACHDEE_ENV

verification:
- `zig build causal-query -- --file .zig-cache/causal-artifacts/app.json cause 2`
- `zig build causal-query -- --file .zig-cache/causal-artifacts/app.json lineage 2`

claim guardrails:
- Do not claim an app fix without rerunning the app request/job scenario that produced the cited artifact.
- Do not expose secret values while fixing config or binding incidents.
- Do not set applied=true from this audit; only a later reviewed application artifact may do that.

next:
- review app incident evidence before proposing source, config, migration, or operational changes
- run the cited causal-query commands before drafting a patch proposal
- hand this audit to the later app policy gate before any apply step
```

## Bounded And Redacted Output

The tool should:

- read input files with the same 1 MiB ceiling used by nearby causal tools;
- cap app incidents in the first audit at 64 actions;
- cap copied labels, action names, subsystem names, fix categories, and policy
  gates at 256 bytes;
- omit raw `redacted_detail` from audit records;
- preserve app causal event ids and query commands so agents can inspect causes
  in the original artifact instead of copying sensitive details forward.

## Workbench Integration

The SolidJS workbench already detects governance artifacts. This branch should
add `zigeffect.causal.app-remediation-audit.v1` to that detection so app audit
artifacts are visible in the Chain/Governance tab with:

- kind `app-remediation-audit`;
- target;
- `applied=false`;
- `mutation_authority=none`;
- a summary naming incident count when present.

Detailed app audit visualization can come later with the broader app incident
workbench branch.

## Tests And Verification

Focused tests should prove:

- command usage text is stable;
- output paths derive from the input artifact path and `--out-prefix`;
- app advice lines are parsed into app incidents;
- JSON preserves `approval_status=pending`, `applied=false`, and
  `mutation_authority=none`;
- incidents include event ids, policy gates, query commands, and bounded labels;
- no raw `redacted_detail` is copied into the audit;
- the workbench governance model recognizes the app audit schema.

Verification commands:

```sh
cd packages/zigeffect && zig build causal-app-remediation-audit -- local --artifact .zig-cache/causal-artifacts/app.json --target yachdee-platform
cd packages/zigeffect && zig build examples
cd packages/zigeffect && zig build test
bun run zigeffect:workbench:test
bun run zigeffect:workbench:typecheck
bun run check
bun run zig:test
git diff --check
```

The first command requires a saved app artifact. Unit tests should cover the
formatter and parser even when no local app artifact exists.

## Future Branch Handoff

Next M8 branches should build on this artifact:

- `codex/zigeffect-app-policy-gates`: enforce source/config/migration/
  operational/rollback policy outcomes over app audit records.
- `codex/zigeffect-app-patch-proposal`: cite app files, config, migrations, or
  operational runbooks after policy review.
- A later workbench branch can render incident rows, gate chips, and causal
  query commands from app audit JSON directly.
