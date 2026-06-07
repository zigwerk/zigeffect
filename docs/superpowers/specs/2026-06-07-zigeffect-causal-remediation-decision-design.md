# zigeffect Causal Remediation Decision Design

## Purpose

`zigeffect` now has a local self-improvement chain that can capture causal
development evidence, synthesize diagnosis, write a remediation plan, and record
a pending proposal audit. The next control boundary is a decision artifact:
approve or reject the pending proposal without mutating source and without
rewriting the original audit record.

This slice adds:

```sh
zig build causal-remediation-decision -- local approve [scenario] [--by <actor>] [--policy <policy>] [--reason <reason>]
zig build causal-remediation-decision -- local reject [scenario] --reason <reason> [--by <actor>] [--policy <policy>]
```

The command reads the local remediation audit JSON, validates it, and writes
schema-versioned JSON plus a human text summary. It does not approve by
side-effect inside the audit file, apply patches, generate diffs, execute
verification commands, or touch source.

## Current State

The current local chain is:

```sh
zig build causal-dev-loop -- baseline [scenario]
zig build causal-dev-loop -- after [scenario]
zig build causal-dev-agent -- local [scenario]
zig build causal-diagnosis -- local [scenario]
zig build causal-remediation-plan -- local [scenario]
zig build causal-remediation-audit -- local [scenario]
```

The audit artifact records:

- `approval_status=pending`;
- `applied=false`;
- proposer;
- source verdict, diagnosis, remediation plan, advice, query, and compare paths;
- evidence event ids;
- required verification commands;
- claim guardrails.

The missing boundary is the next review result: did a human or local policy
approve the proposal for a future patch step, or reject it?

## Design Principles

- **Append-only decision record.** Keep the original audit immutable and write a
  separate decision artifact.
- **Still non-mutating.** Approval means "reviewed and allowed for a future
  patch proposal or source edit"; it does not apply anything.
- **Deterministic local artifacts.** Do not include wall-clock timestamps in
  this local slice. Durable storage adapters may add timestamps later.
- **Evidence continuity.** Copy event ids, verification commands, guardrails,
  and source artifact paths forward from the audit.
- **Explicit rejection reason.** Rejections require a reason so future agents do
  not re-propose the same path blindly.
- **Policy-ready but not a policy engine.** Accept an optional policy id, but do
  not evaluate policies in this command.

## Command Shape

Default dogfood approval:

```sh
zig build causal-remediation-decision -- local approve
```

Scenario approval:

```sh
zig build causal-remediation-decision -- local approve causal-scoped-fiber
```

Default rejection:

```sh
zig build causal-remediation-decision -- local reject --reason "audit evidence is intentional fixture behavior"
```

Scenario rejection:

```sh
zig build causal-remediation-decision -- local reject causal-scoped-fiber --reason "clear verdict does not need a patch"
```

Optional metadata:

```sh
zig build causal-remediation-decision -- local approve --by local-reviewer --policy manual-review
zig build causal-remediation-decision -- local reject causal-scoped-fiber --by local-reviewer --reason "clear verdict"
```

Defaults:

- `decided_by`: `local-reviewer`;
- `policy`: `none`;
- approve reason: `reviewed local remediation audit`;
- reject reason: required.

Usage errors print:

```text
causal-remediation-decision error: <error-name>
usage: zig build causal-remediation-decision -- local approve|reject [scenario] [--by <actor>] [--policy <policy>] [--reason <reason>]
```

Missing audit artifact, unsupported audit schema, unknown scenario, unsupported
decision, duplicate scenario argument, missing flag value, and missing rejection
reason should exit through this usage-style path.

## Inputs

Required:

- local remediation audit JSON.

Default audit path:

```text
.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-remediation-audit.json
```

Scenario audit path:

```text
.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-<scenario>-remediation-audit.json
```

The command validates:

- audit schema is `zigeffect.causal.remediation-audit.v1`;
- schema version is `1`;
- mode is `local`;
- `approval_status` is `pending`;
- `applied` is `false`;
- source paths, event ids, verification commands, and claim guardrails parse.

If an audit is already non-pending or applied, this command rejects it in this
first slice. Re-decisions and supersession chains can be added later.

## Outputs

Default decision paths:

```text
.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-remediation-decision.json
.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-remediation-decision.txt
```

Scenario decision paths:

```text
.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-<scenario>-remediation-decision.json
.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-<scenario>-remediation-decision.txt
```

The command may overwrite an existing local decision artifact for the same
current audit bundle. It must not overwrite the audit artifact itself.

## JSON Schema

Schema id:

```text
zigeffect.causal.remediation-decision.v1
```

Approved example:

```json
{
  "schema": "zigeffect.causal.remediation-decision.v1",
  "schema_version": 1,
  "mode": "local",
  "target": "dogfood",
  "decision": "approved",
  "approval_status": "approved",
  "decided_by": "local-reviewer",
  "policy": "manual-review",
  "reason": "reviewed local remediation audit",
  "applied": false,
  "source": {
    "audit": ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-remediation-audit.json",
    "verdict": ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-verdict.json",
    "diagnosis": ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-diagnosis.txt",
    "remediation_plan": ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-remediation-plan.md",
    "advice": ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-advice.txt",
    "query": ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-queries.txt",
    "compare": ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-compare.txt"
  },
  "event_ids": [3, 4, 5, 6],
  "verification_commands": [
    "zig build causal-dev-loop -- baseline",
    "zig build causal-dev-loop -- after",
    "zig build causal-diagnosis -- local",
    "zig build test --summary none"
  ],
  "claim_guardrails": [
    "Do not claim this patch fixed persisting evidence unless the after verdict is clear or the compare report shows fewer findings."
  ],
  "decision_guardrails": [
    "Approval does not apply source changes.",
    "Run required verification after any future patch before claiming a fix."
  ]
}
```

Rejected example:

```json
{
  "schema": "zigeffect.causal.remediation-decision.v1",
  "schema_version": 1,
  "mode": "local",
  "target": "causal-scoped-fiber",
  "decision": "rejected",
  "approval_status": "rejected",
  "decided_by": "local-reviewer",
  "policy": "none",
  "reason": "clear verdict does not need a patch",
  "applied": false,
  "source": {
    "audit": ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-remediation-audit.json",
    "verdict": ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-verdict.json",
    "diagnosis": ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-diagnosis.txt",
    "remediation_plan": ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-remediation-plan.md",
    "advice": ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-advice.txt",
    "query": ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-queries.txt",
    "compare": ".zig-cache/causal-artifacts/zigeffect-causal-dev-loop-causal-scoped-fiber-compare.txt"
  },
  "event_ids": [],
  "verification_commands": [
    "zig build causal-dev-loop -- baseline causal-scoped-fiber",
    "zig build causal-dev-loop -- after causal-scoped-fiber",
    "zig build causal-diagnosis -- local causal-scoped-fiber",
    "zig build test --summary none"
  ],
  "claim_guardrails": [
    "Do not patch unrelated subsystems when the causal verdict is clear."
  ],
  "decision_guardrails": [
    "Rejected proposals must not be used as permission for source edits.",
    "Create a new audit if evidence changes."
  ]
}
```

## Text Report Shape

Approved:

```text
zigeffect causal remediation decision
schema: zigeffect.causal.remediation-decision.v1
mode: local
target: dogfood
decision: approved
approval_status: approved
decided_by: local-reviewer
policy: manual-review
reason: reviewed local remediation audit
applied: false

source:
- audit: .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-remediation-audit.json
- verdict: .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-verdict.json
- diagnosis: .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-diagnosis.txt
- remediation plan: .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-remediation-plan.md

evidence:
- event 3
- event 4
- event 5
- event 6

decision guardrails:
- Approval does not apply source changes.
- Run required verification after any future patch before claiming a fix.
```

Rejected:

```text
zigeffect causal remediation decision
schema: zigeffect.causal.remediation-decision.v1
mode: local
target: causal-scoped-fiber
decision: rejected
approval_status: rejected
decided_by: local-reviewer
policy: none
reason: clear verdict does not need a patch
applied: false
```

## Architecture

Create one new tool:

```text
packages/zigeffect/tools/causal_remediation_decision.zig
```

Responsibilities:

- parse CLI args;
- resolve default or scenario audit/decision paths;
- read and validate audit JSON;
- parse `approve` or `reject` decision metadata;
- format deterministic JSON and text decision reports;
- write decision artifacts and print the text report.

Modify `packages/zigeffect/build.zig` to add:

- tool module;
- test executable;
- executable;
- build step `causal-remediation-decision`;
- `examples` dependencies.

No existing runtime module needs to change.

## Docs And Manifest

Implementation should update:

- `zig build causal-artifacts` to list default and scenario decision JSON/text
  paths;
- `packages/zigeffect/README.md` to show decision after audit;
- `packages/zigeffect/docs/agent-guide.md` to describe approved versus rejected
  decision records;
- `packages/zigeffect/docs/causal-scenarios.md` to list the command and paths;
- `docs/superpowers/specs/2026-06-07-zigeffect-causal-self-improvement-roadmap.md`
  to record the delivered approval-boundary slice;
- `packages/zigeffect/docs/roadmap.md` to mention the delivered decision
  artifact.

## Non-Goals

- No source edits.
- No generated patch diffs.
- No patch application command.
- No policy evaluation engine.
- No timestamps in the first deterministic local artifact.
- No durable database adapter.
- No in-place audit mutation.
- No production self-healing.

## Verification

Implementation should prove:

- `zig build causal-remediation-decision -- local approve` works after the
  default local dev-loop, diagnosis, remediation-plan, and audit commands.
- `zig build causal-remediation-decision -- local reject causal-scoped-fiber
  --reason "clear verdict"` works after the scenario local chain.
- JSON includes schema/version, decision, approval status, decided_by, policy,
  reason, applied false, audit path, source paths, event ids, verification
  commands, claim guardrails, and decision guardrails.
- Reject without `--reason` fails with usage text.
- Missing audit input fails with usage text.
- Non-pending or applied audit input is rejected.
- `zig build causal-artifacts` lists default and scenario decision paths.
- `zig build examples` includes the new tests and executable.
- `zig build test --summary none` passes in `packages/zigeffect`.
- `bun run zig:test` passes at the repo root.

## Risks

- Approval can sound like source mutation. Keep `applied=false` and
  "Approval does not apply source changes" visible in JSON/text output.
- Decision artifacts can drift from their source audit if the audit is
  regenerated. Store the audit path and copy evidence fields forward so agents
  can inspect the exact bundle.
- Rejection reasons can leak sensitive context. This first local slice assumes
  users keep reasons suitable for local artifacts; broader redaction policy can
  be added when durable or CI decision artifacts exist.

## Alternatives Considered

### Append-Only Decision Artifact

Recommended. It preserves the audit as a proposal and records review outcome in
a separate artifact. This gives agents a clean causal chain and avoids erasing
pending-proposal evidence.

### Rewrite Audit In Place

Rejected for the first slice. It reduces artifact count, but makes local
history weaker and couples proposal creation to review state.

### Add Patch Proposal Now

Rejected for this slice. Patch proposals need a stable approval boundary first.
Adding diffs before decision artifacts risks making "approved" implicit.

## Self-Review

- Placeholder scan: no placeholder or deferred requirement text remains.
- Internal consistency: command name, schema id, artifact paths, defaults, and
  approval semantics are consistent throughout the design.
- Scope check: this is one non-mutating decision command plus docs/manifest
  catch-up, not a patch engine or policy engine.
- Ambiguity check: approval records permission for a future patch workflow only;
  it never edits source or marks anything applied.
