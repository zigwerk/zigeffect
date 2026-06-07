# zigeffect Causal Audit Chain Comparison Design

Date: 2026-06-07

## Purpose

The local self-improvement loop can now capture a session, produce an audit,
record a decision, and write a non-mutating patch proposal. The next missing
step is a chain comparison report that lets an agent answer, from one artifact,
whether the proposed remediation actually moved the causal evidence:

- which proposal evidence event ids disappeared, persisted, appeared, or went
  missing after an after-phase run;
- whether the underlying causal compare report shows improved, unchanged,
  regressed, or inconclusive findings;
- whether the proposal, decision, and audit still preserve `applied=false`;
- which guardrails should constrain any claim about the change.

This is the first slice of the remediation workbench loop. It is deliberately
read-only: the causal runtime may summarize evidence and constrain claims, but
it may not edit source, mark a proposal applied, or approve a patch.

## Roadmap Position

The broader self-improving harness now has four delivered control points:

1. `causal-dev-session` creates the repeatable before/after local session.
2. `causal-remediation-audit` records pending review evidence.
3. `causal-remediation-decision` records approval or rejection while preserving
   `applied=false`.
4. `causal-patch-proposal` records draft or approved patch intent without
   applying source changes.

`causal-audit-chain` is the fifth control point. It closes the first
measurement loop by comparing the patch proposal's cited event ids with the
latest before/after artifacts and compare report. A future application boundary
can consume this report, but this branch only produces the workbench evidence.

## Use Cases

### Runtime Patch Review

After an agent or human edits core `zigeffect` runtime code, the report should
state whether the event ids that justified the proposed change disappeared,
persisted, or became stale. This prevents a patch summary from claiming "fixed"
when the cited evidence is still present.

### Regression Triage

If a patch introduces new findings, the report should classify the chain as
`regressed` even when the proposal itself is approved. Approval means a patch is
allowed to be attempted; the audit chain decides whether the evidence improved.

### Stale Proposal Detection

If the proposal cites event ids that are absent from both before and after
artifacts, the report should put those ids in `missing_event_ids`. That tells an
agent the proposal is probably based on stale or mismatched artifacts and should
not be used as proof.

### Future App Debugging

Apps built with `zigeffect` should later use the same vocabulary: session,
audit, decision, proposal, before/after evidence, and chain assessment. This
branch keeps the schema general enough to reuse while staying focused on local
runtime development.

## Command

```sh
zig build causal-audit-chain -- local [scenario]
```

The command is local and deterministic in this slice. It reads existing causal
artifacts and writes a report. It does not edit source, approve decisions, apply
patches, or run verification commands.

## Inputs

Default input paths:

- `.zig-cache/causal-artifacts/zigeffect-causal-dev-session.json`
- `.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-remediation-audit.json`
- `.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-patch-proposal.json`
- `.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-before.json`
- `.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-after.json`

Scenario input paths:

- `.zig-cache/causal-artifacts/zigeffect-causal-dev-session-<scenario>.json`
- `.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-<scenario>-remediation-audit.json`
- `.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-<scenario>-patch-proposal.json`
- `.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-<scenario>-before.json`
- `.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-<scenario>-after.json`

The decision artifact is optional because draft proposals have
`source.decision=null`. Approved proposals must reference a decision artifact.
The compare report is optional but normally comes from `source.compare` in the
proposal. When it is present, the command parses `finding delta: <n>`.

## Outputs

Default output paths:

- `.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-audit-chain.json`
- `.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-audit-chain.txt`

Scenario output paths:

- `.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-<scenario>-audit-chain.json`
- `.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-<scenario>-audit-chain.txt`

Schema id:

```text
zigeffect.causal.audit-chain.v1
```

Required JSON fields:

- `schema`
- `schema_version`
- `mode`
- `target`
- `assessment`
- `source`
- `proposal_status`
- `approval_status`
- `approved`
- `applied`
- `finding_delta`
- `event_ids`
- `disappeared_event_ids`
- `persisting_event_ids`
- `appeared_event_ids`
- `missing_event_ids`
- `verification_commands`
- `claim_guardrails`
- `proposal_guardrails`
- `chain_guardrails`

## Assessment Rules

Finding delta from the compare report is the strongest signal when available:

- negative finding delta -> `improved`;
- positive finding delta -> `regressed`;
- zero finding delta plus persisting evidence -> `unchanged`;
- zero finding delta with no proposal evidence -> `inconclusive`.

When no finding delta is available, event classification provides the fallback:

- more disappeared ids than appeared ids -> `improved`;
- more appeared ids than disappeared ids -> `regressed`;
- any persisting ids -> `unchanged`;
- otherwise -> `inconclusive`.

The report must still list disappeared, persisting, appeared, and missing ids
even when the assessment is decided by finding delta.

## Text Report

The text report starts with:

```text
zigeffect causal audit-chain report
schema: zigeffect.causal.audit-chain.v1
mode: local
target: dogfood
assessment: unchanged
proposal_status: approved
approval_status: approved
approved: true
applied: false
finding_delta: +0
```

It then lists source paths, event-id classification, verification commands,
claim guardrails, proposal guardrails, and chain guardrails.

## Validation

The command validates:

- session schema is `zigeffect.causal.dev-session.v1`;
- audit schema is `zigeffect.causal.remediation-audit.v1`;
- proposal schema is `zigeffect.causal.patch-proposal.v1`;
- decision schema is `zigeffect.causal.remediation-decision.v1` when a decision
  is referenced;
- target values match across session, audit, proposal, and decision;
- `proposal.applied=false`;
- `approved` proposals have a decision path.

Validation does not require a decision for draft proposals. A draft proposal can
still be compared, but its report must keep `approved=false`,
`approval_status=pending`, and chain guardrails that prevent treating it as
authorization for source edits.

## Acceptance Criteria

- `zig build causal-audit-chain -- local` writes deterministic default JSON and
  text reports after the normal local dev-loop artifacts exist.
- `zig build causal-audit-chain -- local causal-scoped-fiber` writes
  deterministic scenario JSON and text reports.
- The JSON report uses schema `zigeffect.causal.audit-chain.v1`.
- The text report is a useful first-read summary for an agent and includes the
  exact source artifact paths.
- Proposal event ids are classified into disappeared, persisting, appeared, and
  missing sets.
- Finding delta is parsed from the proposal's compare report when available.
- The command fails cleanly for missing required artifacts, malformed schemas,
  mismatched targets, applied proposals, and approved proposals without a
  decision path.
- No source files are edited and no proposal is marked applied.

## Future Direction

This command becomes the read-only workbench handoff before a future explicit
patch-application boundary. Later slices can compare two named chain snapshots,
record `applied=true` after an explicit executor, and reuse the same chain
report for applications built with `zigeffect`.
