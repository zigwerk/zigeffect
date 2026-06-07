# zigeffect Causal Remediation Audit Design

## Purpose

`zigeffect` can now use its causal runtime during local development to capture
before/after evidence, produce verdicts, route agent inspection, synthesize
diagnosis, and generate a non-mutating remediation plan. The next controlled
remediation step is an audit record: a durable local artifact that records who
or what proposed remediation, which causal evidence justified it, what artifact
bundle it came from, and whether approval is still pending.

This slice adds:

```sh
zig build causal-remediation-audit -- local [scenario]
```

The command reads the local dev-loop verdict, diagnosis, and remediation-plan
artifacts. It writes schema-versioned JSON plus a human text summary. It does
not approve, reject, apply, execute, or mutate source.

## Current State

The current local self-improvement path is:

```sh
zig build causal-dev-loop -- baseline [scenario]
zig build causal-dev-loop -- after [scenario]
zig build causal-dev-agent -- local [scenario]
zig build causal-diagnosis -- local [scenario]
zig build causal-remediation-plan -- local [scenario]
```

The remediation plan answers "what should a developer inspect or patch next?"
It includes event ids, posture, patch strategy, verification commands, and
claim guardrails. It intentionally does not answer the audit questions from the
causal runtime design:

- who proposed a remediation action?
- which event ids justified the proposal?
- was the action approved by policy or a human?

This slice records those answers locally with `approval_status=pending` and
`applied=false`.

## Design Principles

- **Non-mutating audit boundary.** The command writes audit artifacts only.
- **Schema first.** JSON is the canonical machine-readable record.
- **Human-readable mirror.** Text output summarizes the same record for branch
  handoff and review.
- **Evidence-cited proposals.** Every record includes event ids parsed from the
  remediation plan.
- **No approval engine yet.** Approval remains pending; approve/reject/apply are
  future commands.
- **Local and deterministic.** The command reads saved local artifacts only and
  does not require network or external services.

## Command Shape

Default dogfood target:

```sh
zig build causal-remediation-audit -- local
```

Scenario target:

```sh
zig build causal-remediation-audit -- local causal-scoped-fiber
```

The command writes and prints:

```text
.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-remediation-audit.json
.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-remediation-audit.txt
.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-<scenario>-remediation-audit.json
.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-<scenario>-remediation-audit.txt
```

Usage errors print:

```text
causal-remediation-audit error: <error-name>
usage: zig build causal-remediation-audit -- local [scenario]
```

Missing local artifacts, invalid verdict schema, invalid scenario slug, and
invalid artifact paths should exit through the same usage-style error path as
`causal-diagnosis` and `causal-remediation-plan`.

## Inputs

Required local artifacts:

- local verdict JSON;
- local diagnosis report;
- local remediation plan Markdown;
- local advice report from the verdict artifact;
- local query report derived from the verdict artifact;
- local compare report when the verdict names one.

The command should validate the full bundle exists before writing an audit
record. The first implementation only needs to parse stable lines from the
verdict and remediation plan. Advice/query/compare reads are still useful as
bundle-presence validation.

## JSON Schema

Schema id:

```text
zigeffect.causal.remediation-audit.v1
```

Fields:

```json
{
  "schema": "zigeffect.causal.remediation-audit.v1",
  "schema_version": 1,
  "mode": "local",
  "target": "dogfood",
  "proposer": "local-agent",
  "approval_status": "pending",
  "applied": false,
  "posture": "patch-candidate",
  "source": {
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
  ]
}
```

The first implementation can keep the schema flat and deterministic. It should
not include wall-clock timestamps because that makes local artifacts noisier and
less comparable. A future durable history adapter can add timestamps at the
storage boundary.

## Text Report Shape

Example:

```text
zigeffect causal remediation audit
schema: zigeffect.causal.remediation-audit.v1
mode: local
target: dogfood
proposer: local-agent
approval_status: pending
applied: false
posture: patch-candidate

source:
- verdict: .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-verdict.json
- diagnosis: .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-diagnosis.txt
- remediation plan: .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-remediation-plan.md
- advice: .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-advice.txt
- query: .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-queries.txt
- compare: .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-compare.txt

evidence:
- event 3
- event 4
- event 5
- event 6

approval:
- status: pending
- approved_by: none
- policy: none
- applied: false

next:
- review remediation plan before source edits
- cite event ids when opening or summarizing a patch
- rerun the required verification commands before claiming a fix
```

## Parsing Rules

The command should parse stable prefixes from `*-remediation-plan.md`:

- `target: `;
- `posture: `;
- `verdict: `;
- `diagnosis: `;
- `- event <id> `;
- backticked verification commands under `## Required Verification`;
- claim guardrail bullet text under `## Claim Guardrails`.

If the remediation plan has no event ids, the JSON should emit an empty
`event_ids` array. That is valid for `do-not-patch` plans.

## Approval Semantics

This slice only emits:

```text
approval_status: pending
applied: false
approved_by: none
policy: none
```

Future commands may append or rewrite approval records, but this command should
not modify an existing audit record in place beyond regenerating it from the
current local bundle. The first useful invariant is simple: a proposal exists
before approval and application exist.

## Docs And Manifest

The implementation should update:

- `zig build causal-artifacts` to list default and scenario audit paths;
- `packages/zigeffect/README.md` to show audit after remediation-plan;
- `packages/zigeffect/docs/agent-guide.md` to describe the audit command;
- `packages/zigeffect/docs/causal-scenarios.md` to list commands and paths;
- `docs/superpowers/specs/2026-06-07-zigeffect-causal-self-improvement-roadmap.md`
  to record this delivered slice;
- `packages/zigeffect/docs/roadmap.md` to mention the delivered audit artifact.

## Non-Goals

- No approval or rejection command.
- No source edits.
- No generated patch diffs.
- No policy engine.
- No timestamps in the first deterministic local artifact.
- No durable database adapter.
- No production self-healing.

## Verification

Implementation should prove:

- `zig build causal-remediation-audit -- local` works after default
  dev-loop, diagnosis, and remediation-plan commands.
- `zig build causal-remediation-audit -- local causal-scoped-fiber` works after
  scenario dev-loop, diagnosis, and remediation-plan commands.
- JSON includes schema/version, target, pending approval status, applied false,
  source paths, event ids, verification commands, and claim guardrails.
- Clear/do-not-patch scenario records can emit an empty `event_ids` array.
- Missing inputs fail with usage text.
- `zig build causal-artifacts` lists default and scenario audit paths.
- `zig build examples` includes the new tests and executable.
- `zig build test --summary none` passes in `packages/zigeffect`.
- `bun run zig:test` passes at the repo root.

## Risks

- Parsing Markdown can drift. Keep parsing to stable prefixes and test the
  default and clear-plan forms.
- JSON array formatting can become hand-rolled and fragile. Keep the schema
  small and use deterministic string formatting only for the first slice.
- An audit artifact can sound like approval. Keep `approval_status=pending`,
  `applied=false`, `approved_by=none`, and `policy=none` visible in both JSON
  and text output.

## Alternatives Considered

### Extend `causal-remediation-plan`

This would reduce command count but blur planning and audit responsibilities.
The plan answers "what should be done"; the audit answers "who proposed it and
what evidence justifies review."

### Add Approval Commands Now

Approval commands are useful, but they need a stable proposal schema first.
Adding approval before the audit record exists risks coupling policy semantics
to a moving target.

### Store Audit In A Durable Backend

Durable histories belong after local semantics are stable. The local artifact is
enough for the zigeffect self-improvement loop and can later be consumed by a
Cockroach/RoachGraph or other history adapter.

## Self-Review

- Placeholder scan: no placeholder or deferred requirement text remains.
- Internal consistency: command name, artifact names, schema id, and approval
  defaults are consistent throughout the design.
- Scope check: this is one non-mutating audit command plus docs/manifest
  catch-up, not an approval engine.
- Ambiguity check: the command records pending proposals only; it never approves
  or applies remediation.
