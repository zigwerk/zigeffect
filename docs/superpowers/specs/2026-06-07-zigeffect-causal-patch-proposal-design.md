# zigeffect Causal Patch Proposal Design

Date: 2026-06-07

## Purpose

`zigeffect` now has a local causal development session that can capture
before/after evidence, produce verdicts, guide an agent through diagnosis, write
a remediation plan, create a pending remediation audit, and record an approval
or rejection decision.

The missing boundary is the first artifact that says what a development agent
would change next. This design adds a deterministic, non-mutating patch proposal
artifact:

```sh
zig build causal-patch-proposal -- local draft [scenario] --summary <summary> --file <path> --change <description>
zig build causal-patch-proposal -- local approved [scenario] --summary <summary> --file <path> --change <description>
```

The command records a proposed source change and links it back to audit or
decision evidence. It does not edit files, apply patches, run verification, or
claim that the issue is fixed.

## Current State

The current local self-improvement chain is:

```sh
zig build causal-dev-session -- start [scenario]
zig build causal-dev-session -- assess [scenario]
zig build causal-remediation-decision -- local approve|reject [scenario]
```

`assess` runs the read-only analysis chain:

```sh
zig build causal-dev-loop -- after [scenario]
zig build causal-dev-agent -- local [scenario]
zig build causal-diagnosis -- local [scenario]
zig build causal-remediation-plan -- local [scenario]
zig build causal-remediation-audit -- local [scenario]
```

The audit artifact has `approval_status=pending` and `applied=false`. The
decision artifact has `approval_status=approved|rejected` and still has
`applied=false`. Neither artifact describes the exact code change that an agent
intends to make. That is intentional so far: the existing chain is evidence and
review control, not patch generation.

## Design Options

### Option A: Draft-Only Proposal From Audit

The command would only read the pending audit and write an unapproved draft
proposal.

Tradeoff: this is the simplest implementation, but it does not connect to the
decision boundary that was just added. It lets agents create useful notes, but
not approved patch-ready handoffs.

### Option B: Approved-Only Proposal From Decision

The command would require an approved decision before writing any proposal.

Tradeoff: this is strict and safe, but too stiff for development. Agents often
need to draft a proposed change so reviewers can approve, reject, or redirect
it.

### Option C: Draft And Approved Modes

The command supports both `draft` and `approved` modes. Draft proposals read a
pending audit and explicitly mark themselves as unapproved. Approved proposals
read an approved decision and carry the decision metadata forward.

This is the chosen design. It preserves the review boundary while still making
the system useful during active development.

## Chosen Command Shape

Default dogfood draft:

```sh
zig build causal-patch-proposal -- local draft --summary "tighten scope close ordering" --file packages/zigeffect/src/core/scope.zig --change "ensure child finalizers run before parent close is reported"
```

Scenario draft:

```sh
zig build causal-patch-proposal -- local draft causal-scoped-fiber --summary "record scoped fiber interruption" --file packages/zigeffect/src/runtime/fiber.zig --change "emit the fiber interrupted event before resource release evidence"
```

Approved proposal:

```sh
zig build causal-patch-proposal -- local approved --summary "tighten scope close ordering" --file packages/zigeffect/src/core/scope.zig --change "ensure child finalizers run before parent close is reported"
```

Rules:

- `local` is the only mode in this slice.
- `draft` reads `*-remediation-audit.json`.
- `approved` reads `*-remediation-decision.json`.
- `draft` requires audit `approval_status=pending` and `applied=false`.
- `approved` requires decision `approval_status=approved`, `decision=approved`,
  and `applied=false`.
- rejected or applied decisions are rejected by the CLI.
- `--summary`, `--file`, and `--change` are required.
- one file/change pair is enough for the first slice.
- future slices may add repeated `--file/--change` pairs, `--diff-file`, and
  machine-readable structured edit hunks.

The command name uses `patch` rather than `remediation` because the existing
remediation chain already owns plan, audit, and decision records. This artifact
is the first patch-intent record, while still remaining non-mutating.

## Artifact Paths

Default outputs:

```text
.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-patch-proposal.json
.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-patch-proposal.txt
```

Scenario outputs:

```text
.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-<scenario>-patch-proposal.json
.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-<scenario>-patch-proposal.txt
```

The command may overwrite the current local proposal artifact for the same
target. It must not overwrite audit, decision, verdict, diagnosis, plan, advice,
query, compare, or session artifacts.

## JSON Schema

Schema id:

```text
zigeffect.causal.patch-proposal.v1
```

Required fields:

- `schema`
- `schema_version`
- `mode`
- `target`
- `proposal_status`
- `approval_status`
- `approved`
- `applied`
- `summary`
- `source`
- `proposed_changes`
- `event_ids`
- `verification_commands`
- `claim_guardrails`
- `proposal_guardrails`

Drafts set:

- `proposal_status=draft`
- `approval_status=pending`
- `approved=false`
- `applied=false`
- `source.decision=null`

Approved proposals set:

- `proposal_status=approved`
- `approval_status=approved`
- `approved=true`
- `applied=false`
- `source.decision=<decision artifact path>`

## Text Report

The text report should be the first thing a human or agent reads:

```text
zigeffect causal patch proposal
schema: zigeffect.causal.patch-proposal.v1
mode: local
target: dogfood
proposal_status: approved
approval_status: approved
approved: true
applied: false
summary: tighten scope close ordering

source:
- audit: .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-remediation-audit.json
- decision: .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-remediation-decision.json
- verdict: .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-verdict.json
- diagnosis: .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-diagnosis.txt
- remediation plan: .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-remediation-plan.md
- advice: .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-advice.txt
- query: .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-queries.txt
- compare: .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-compare.txt

proposed changes:
- packages/zigeffect/src/core/scope.zig: ensure child finalizers run before parent close is reported

evidence:
- event 3
- event 4
- event 5
- event 6

verification:
- `zig build causal-dev-loop -- baseline`
- `zig build causal-dev-loop -- after`
- `zig build causal-diagnosis -- local`
- `zig build test --summary none`

proposal guardrails:
- This proposal does not apply source changes.
- Approval permits reviewable patch work but does not prove the fix.
- Run required verification after any future patch before claiming a fix.
```

## Error Handling

Usage errors print:

```text
causal-patch-proposal error: <error-name>
usage: zig build causal-patch-proposal -- local draft|approved [scenario] --summary <summary> --file <path> --change <description>
```

Stable errors:

- `MissingMode`
- `UnknownMode`
- `MissingProposalStatus`
- `UnknownProposalStatus`
- `DuplicateScenarioArgument`
- `UnknownFlag`
- `MissingFlagValue`
- `MissingSummary`
- `MissingFile`
- `MissingChange`
- `MissingPatchProposalInput`
- `UnsupportedAuditSchema`
- `UnsupportedDecisionSchema`
- `AuditNotPending`
- `AuditAlreadyApplied`
- `DecisionNotApproved`
- `DecisionAlreadyApplied`
- `InvalidArtifactPath`

## Agent Protocol

1. Run `zig build causal-dev-session -- start [scenario]`.
2. Make no source edits yet when exploring a remediation hypothesis.
3. Run `zig build causal-dev-session -- assess [scenario]`.
4. Read the session, verdict, diagnosis, remediation plan, and audit.
5. Create a draft proposal when the intended change is clear.
6. Record a review decision:
   `zig build causal-remediation-decision -- local approve|reject [scenario]`.
7. Create an approved proposal only after an approved decision.
8. Apply source edits manually or through a future explicit patch executor.
9. Rerun `causal-dev-session -- assess [scenario]` and compare evidence before
   claiming that the patch fixed anything.

## Milestone Roadmap For This Slice

### Milestone 3.1: Proposal Schema And CLI Parser

Deliver path helpers, CLI parsing, proposal status validation, and formatter
tests for default and scenario targets.

Exit criteria:

- default and scenario paths are deterministic;
- `draft` and `approved` parse correctly;
- missing summary/file/change values produce stable errors;
- the usage string documents the exact command shape.

### Milestone 3.2: Draft Proposal From Audit

Read the pending audit artifact and write draft proposal JSON/text.

Exit criteria:

- audit schema and `applied=false` are validated;
- draft proposals set `approved=false`, `approval_status=pending`, and
  `proposal_status=draft`;
- source artifact paths, event ids, verification commands, and claim guardrails
  copy forward from the audit;
- no source files are edited.

### Milestone 3.3: Approved Proposal From Decision

Read the approved decision artifact and write approved proposal JSON/text.

Exit criteria:

- decision schema, `decision=approved`, `approval_status=approved`, and
  `applied=false` are validated;
- rejected decisions fail with `DecisionNotApproved`;
- approved proposals set `approved=true`, `approval_status=approved`, and
  `proposal_status=approved`;
- decision source paths, event ids, verification commands, and guardrails copy
  forward.

### Milestone 3.4: Manifest, Docs, And Session Visibility

Add proposal artifacts to the retention manifest and update the agent-facing
docs.

Exit criteria:

- `zig build causal-artifacts` lists default and scenario proposal artifacts;
- docs show where proposal fits after audit/decision and before manual source
  edits;
- `causal-dev-session -- status` can mention whether a proposal artifact exists
  in a later follow-up slice.

### Milestone 3.5: Integration Verification

Verify the default and scenario workflows.

Exit criteria:

- default draft proposal command succeeds after `assess`;
- default approved proposal command succeeds after an approved decision;
- scenario draft and approved proposal commands succeed;
- rejected decision path fails cleanly;
- aggregate tests and repo checks pass.

## Future Direction

This slice should lead to three follow-up capabilities:

- **Patch application boundary:** a separate explicit executor that can apply an
  approved proposal, record `applied=true`, and require post-apply verification.
- **Audit chain comparison:** a tool that compares audit, decision, proposal,
  before, and after artifacts so agents can say which evidence disappeared or
  persisted.
- **App support:** the same proposal workflow for apps built with `zigeffect`,
  where proposed changes may target service wiring, layer composition,
  resource scoping, retry policy, or request/job handlers.

The key invariant stays the same: causal tools may propose, explain, and verify
evidence, but source mutation is an explicit later boundary.

## Self-Review

- Placeholder scan: no placeholder tokens or incomplete requirements remain.
- Consistency: command name, schema id, artifact paths, and status names are
  consistent across examples and roadmap sections.
- Scope check: this is one focused implementation slice. Patch application and
  audit-chain comparison are explicitly deferred.
- Ambiguity check: draft reads audit; approved reads decision; neither mode
  edits source.
