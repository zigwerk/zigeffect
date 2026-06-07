# zigeffect Self-Improving Development Harness Roadmap

Date: 2026-06-07

## Purpose

`zigeffect` now has enough causal runtime surface to become its own development
assistant substrate. The missing piece is not more isolated evidence commands;
it is a repeatable local harness that agents can run while changing
`zigeffect`, then use to explain what changed, what persisted, and what should
be inspected next.

This roadmap defines that harness. It treats the current causal commands as
the raw runtime senses and adds a session coordinator around them. The
coordinator must be useful immediately for core `zigeffect` development, while
preserving the safety boundary that causal tools may explain and propose, but
must not edit source or apply remediation without a later explicit policy
system.

## Current Surface

The merged causal runtime work already provides:

- `zig build causal-dev-loop -- baseline [scenario]`
- `zig build causal-dev-loop -- after [scenario]`
- `zig build causal-dev-agent -- local [scenario]`
- `zig build causal-diagnosis -- local [scenario]`
- `zig build causal-remediation-plan -- local [scenario]`
- `zig build causal-remediation-audit -- local [scenario]`
- `zig build causal-remediation-decision -- local approve|reject [scenario]`
- `zig build causal-query -- --file <artifact> <query> [argument]`
- `zig build causal-advice -- --before <before.json> --file <after.json>`
- `zig build causal-compare -- <before.json> <after.json>`
- `zig build causal-artifacts`
- CI handoff, advice, verdict, baseline-compare, redaction, sampling,
  bounded-store, and taxonomy-versioning slices.

Those commands prove the causal graph can guide an agent. They still require a
human or agent to remember the sequence, rerun the right steps, locate the
right artifacts, and keep claims aligned with before/after evidence.

## Use Cases

### Core Runtime Change

An agent preparing to edit scope, fiber, service, schedule, layer, or runtime
code should capture a baseline before touching source, make the change, then
run an assessment that produces one compact session report. The report should
name the scenario, artifact paths, event ids, advice status, diagnosis,
remediation-plan path, audit path, and required verification commands.

### Failed Local Test

When a zigeffect package test or scenario fails, the harness should still leave
behind queryable artifacts. The agent should not need to infer from terminal
text alone. The report must point to causal JSON, advice, compare, verdict, and
handoff-style next queries.

### Regression Triage

When before/after traces show new findings, the harness should highlight new
event ids and prioritize the scenario owner and invariant. When findings
persist, it should prevent overclaiming by saying the patch did not resolve
that evidence.

### Scenario Learning

When development uncovers a new class of issue, the agent should add or update
a causal scenario and invariant so future runs catch it. The harness should
make this a normal remediation option, not an afterthought.

### Future App Support

The same workflow should later run against apps built with `zigeffect`: capture
app request/job traces, diagnose service/layer/resource/fiber/retry problems,
and produce reviewable remediation artifacts using the same vocabulary.

## Chosen First Project

The first project is a local session coordinator:

```sh
zig build causal-dev-session -- start [scenario]
zig build causal-dev-session -- assess [scenario]
zig build causal-dev-session -- status [scenario]
```

This is the coordinator-first path. It is preferred over hardening-first or
patch-proposal-first because the underlying safety work is already strong
enough for local use, and the existing commands need a single ergonomic loop
before patch proposal formats become useful.

## Harness V1 Contract

### `start [scenario]`

Runs the baseline half of the development loop and writes a session artifact
with `phase=baseline-captured`.

Required behavior:

- run `zig build causal-dev-loop -- baseline [scenario]`;
- record command argv, exit status, stdout/stderr snippets, and expected
  baseline artifact paths;
- write default artifacts:
  - `.zig-cache/causal-artifacts/zigeffect-causal-dev-session.json`
  - `.zig-cache/causal-artifacts/zigeffect-causal-dev-session.txt`
- write scenario artifacts:
  - `.zig-cache/causal-artifacts/zigeffect-causal-dev-session-<scenario>.json`
  - `.zig-cache/causal-artifacts/zigeffect-causal-dev-session-<scenario>.txt`
- never delete existing causal artifacts unless the user explicitly does so.

### `assess [scenario]`

Runs the after half and, if after artifacts exist, executes the read-only
analysis chain.

Required behavior:

- fail with a stable message if the baseline artifact is missing;
- run `zig build causal-dev-loop -- after [scenario]`;
- run, in order:
  - `zig build causal-dev-agent -- local [scenario]`
  - `zig build causal-diagnosis -- local [scenario]`
  - `zig build causal-remediation-plan -- local [scenario]`
  - `zig build causal-remediation-audit -- local [scenario]`
- write a session artifact with all command outcomes and all expected output
  paths;
- exit nonzero if any required command failed, but only after writing the
  session report;
- stop before `causal-remediation-decision`; approval is a review action, not
  an automatic assessment action.

### `status [scenario]`

Reads the latest session JSON and prints the current next actions.

Required behavior:

- show whether baseline, after, verdict, diagnosis, plan, and audit artifacts
  exist;
- show the exact next command to run;
- show whether a decision artifact exists;
- show whether source edits remain outside the causal tool boundary.

## Session Artifact Schema

Schema name:

```text
zigeffect.causal.dev-session.v1
```

Required JSON fields:

- `schema`
- `schema_version`
- `mode`
- `target`
- `phase`
- `status`
- `commands`
- `artifacts`
- `next_actions`
- `guardrails`

The schema must avoid wall-clock timestamps in v1 so local outputs remain
stable. A future durable backend can add run metadata when there is a policy
for comparing it.

## Agent Protocol

1. Run `zig build causal-dev-session -- start [scenario]` before editing a
   runtime subsystem.
2. Make the smallest source change needed for the issue.
3. Run `zig build causal-dev-session -- assess [scenario]`.
4. Read the session text first, then the verdict, advice, diagnosis, and
   remediation plan.
5. Cite event ids and before/after posture in the patch summary.
6. Run the required verification commands from the remediation plan.
7. Record a decision only after review:
   `zig build causal-remediation-decision -- local approve|reject [scenario]`.
8. Do not claim a fix for persisting evidence unless a later after artifact is
   clear or the compare report shows fewer findings.

## Milestone Roadmap

### Milestone 1: Local Session Coordinator

Deliver `causal-dev-session` with `start`, `assess`, and `status` modes.

Exit criteria:

- default and scenario paths are deterministic;
- command outcomes are recorded even on failure;
- assessment writes session JSON/text after running the analysis chain;
- no source edits or decisions are applied.

### Milestone 2: Failure Bundle Completeness

Make failed package-test and scenario runs produce a complete first-read bundle
even when one command in the chain fails.

Exit criteria:

- failed after-phase package tests still produce session, verdict, advice,
  query, and handoff-style pointers where possible;
- missing baseline and malformed artifact failures are stable and tested;
- agents can answer "what should I inspect first?" from the session text.

### Milestone 3: Non-Mutating Patch Proposal Artifact

Add a patch proposal artifact that links a proposed diff or file-level action
to audit evidence, event ids, and verification commands.

Exit criteria:

- proposal artifacts require an approved decision or explicitly say they are
  unapproved drafts;
- proposals never apply source changes;
- proposals can be compared before and after actual human/agent edits.

First-slice contract:

```sh
zig build causal-patch-proposal -- local draft [scenario] --summary <summary> --file <path> --change <description>
zig build causal-patch-proposal -- local approved [scenario] --summary <summary> --file <path> --change <description>
```

Draft proposals read pending remediation audits and write
`proposal_status=draft`, `approval_status=pending`, `approved=false`, and
`applied=false`. Approved proposals read approved remediation decisions and
write `proposal_status=approved`, `approval_status=approved`, `approved=true`,
and `applied=false`. Both modes copy source artifact paths, event ids,
verification commands, and guardrails forward from the causal chain.

Detailed design and execution plan:

- `docs/superpowers/specs/2026-06-07-zigeffect-causal-patch-proposal-design.md`
- `docs/superpowers/plans/2026-06-07-zigeffect-causal-patch-proposal.md`

### Milestone 4: Audit Chain Comparison

Compare session, audit, decision, proposal, and after artifacts across a
development cycle.

Exit criteria:

- agents can say which event ids disappeared, persisted, or appeared;
- a remediation can be classified as improved, unchanged, regressed, or
  inconclusive;
- reports retain the claim guardrails from the source audit.

### Milestone 5: Scenario Learning Loop

Make "add a scenario or invariant" a first-class outcome of diagnosis.

Exit criteria:

- remediation plans can recommend a new scenario when evidence is too broad;
- scenario registry entries include owner, invariant, artifact path, and
  expected findings policy;
- a new regression scenario can be added without duplicating harness logic.

### Milestone 6: Policy And Approval Engine

Add local policy-backed decision records after the artifact vocabulary is
stable.

Exit criteria:

- policy decisions use the same decision schema as manual review;
- policy reasons are deterministic and cite evidence;
- policy cannot approve source mutation by itself.

### Milestone 7: App-Facing Reuse

Expose the same session, diagnosis, remediation, audit, decision, and proposal
loop to apps built with `zigeffect`.

Exit criteria:

- app request/job traces can enter causal artifacts;
- app-facing reports keep redaction and bounded-memory guarantees;
- agents can use the same query vocabulary for runtime and app issues.

## Planning Sessions

### Session 1: Coordinator Contract Review

Review command names, artifact names, schema fields, and failure semantics.

Questions:

- Is `causal-dev-session` the right public command name?
- Confirm that `assess` should create an audit automatically after the
  remediation plan.
- Which artifact paths must be present for an assessment to exit zero?

Output:

- final v1 command contract;
- approved schema field list;
- exact verification matrix.

### Session 2: Failure Matrix

Walk through default, clear scenario, expected-failure scenario, missing
baseline, malformed verdict, and command failure cases.

Output:

- expected status value for every case;
- nonzero exit rules;
- report snippets agents should read first.

### Session 3: Agent Ergonomics Review

Run the coordinator on a real zigeffect change and inspect whether the report
helps an agent make better next decisions.

Output:

- wording changes for session text;
- missing query commands;
- any duplicated or noisy artifact references to remove.

### Session 4: Remediation Safety Review

Confirm that session, audit, decision, and future proposal artifacts preserve
the non-mutating boundary.

Output:

- guardrail language for every artifact;
- explicit policy for rejected audits;
- approval vocabulary for future policy engine work.

### Session 5: Scenario Learning Review

Choose the first runtime bug class that should graduate into a new scenario.

Output:

- new scenario template;
- invariant authoring checklist;
- test and artifact expectations.

## Success Metrics

- A development agent can run one baseline command before editing and one
  assessment command after editing.
- Every assessment leaves a stable JSON/text session report.
- Patch summaries cite event ids and compare posture without manual artifact
  hunting.
- Persisting findings are not mislabeled as fixed.
- Clear scenarios do not produce speculative patch advice.
- Approval and application remain separate from evidence generation.

## First Branch Recommendation

Build Milestone 1 only:

- create `tools/causal_dev_session.zig`;
- add `zig build causal-dev-session`;
- add session JSON/text paths to `causal-artifacts`;
- update README, agent guide, causal scenarios, and roadmap docs;
- verify default and `causal-scoped-fiber` flows.

Do not implement patch proposals, policy decisions, app-facing adapters, or
source mutation in the first branch.
