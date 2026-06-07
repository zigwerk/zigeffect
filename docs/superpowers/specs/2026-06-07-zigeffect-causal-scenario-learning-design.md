# zigeffect Causal Scenario Learning Design

Date: 2026-06-07

## Purpose

`zigeffect` can now capture a causal development session, diagnose findings,
record remediation review state, propose a patch, and compare the proposal
against before/after evidence. The next self-improvement step is to let that
same evidence teach the project when a new scenario or invariant should be
created.

This design adds a read-only scenario-learning proposal artifact. It makes
"add a scenario or invariant" a first-class causal outcome while preserving the
current safety boundary: causal tools may recommend and explain, but they do
not edit `tools/causal_run.zig`, update docs, or mark a scenario as added.

## Roadmap Position

This is Milestone 5 of the self-improving development harness:

- Milestone 1: local session coordinator delivered.
- Milestone 2: failure bundle completeness delivered through local/CI causal
  artifacts.
- Milestone 3: non-mutating patch proposal artifact delivered.
- Milestone 4: audit-chain comparison delivered.
- Milestone 5: scenario learning loop begins here.

The first slice should produce a reviewable proposal, not a registry patch.
Automatic source edits, policy-backed approval, and registry mutation remain
future work.

## Use Cases

### Repeated Persisting Evidence

When the audit chain says evidence is `unchanged` and event ids persist, an
agent should be able to propose a regression scenario that captures the runtime
rule being violated. The proposal should cite the audit-chain and diagnosis
artifacts so the reviewer can decide whether to create a new scenario.

### New Regression Evidence

When the audit chain says `regressed`, or the local verdict has `new_actions`,
the proposal should recommend a scenario with `expectation=expected_pass` and a
finding policy that fails when the command emits findings. The reviewer can
then add the smallest reproducing scenario in a later patch.

### Clear Evidence

When the target is already clear and the audit chain is `inconclusive` only
because there is no evidence, the proposal should say `recommendation=none`.
This prevents agents from inventing scenarios for healthy paths.

### Existing Scenario Refinement

When the work is already scoped to a scenario, the proposal can recommend
refining that scenario's invariant, label, or command rather than adding a new
scenario. This is still a proposal artifact, not a source edit.

## Command

```sh
zig build causal-scenario-proposal -- local [scenario]
```

The command reads existing local causal artifacts and writes JSON/text
proposal reports. It is deterministic and non-mutating.

## Inputs

Default input paths:

- `.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-verdict.json`
- `.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-diagnosis.txt`
- `.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-remediation-plan.md`
- `.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-audit-chain.json`

Scenario input paths:

- `.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-<scenario>-verdict.json`
- `.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-<scenario>-diagnosis.txt`
- `.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-<scenario>-remediation-plan.md`
- `.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-<scenario>-audit-chain.json`

The audit-chain artifact is preferred because it contains the strongest
before/after posture. If it is missing, the command should fail with a stable
missing-input error in this first slice rather than guessing from diagnosis
alone.

## Outputs

Default output paths:

- `.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-scenario-proposal.json`
- `.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-scenario-proposal.txt`

Scenario output paths:

- `.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-<scenario>-scenario-proposal.json`
- `.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-<scenario>-scenario-proposal.txt`

Schema id:

```text
zigeffect.causal.scenario-proposal.v1
```

Required JSON fields:

- `schema`
- `schema_version`
- `mode`
- `target`
- `recommendation`
- `reason`
- `source`
- `evidence`
- `proposed_scenario`
- `proposed_invariants`
- `review_checklist`
- `guardrails`

## Recommendation Values

- `add-scenario`: evidence is new, regressed, or persisting and no existing
  scenario slug was requested.
- `refine-scenario`: evidence is new, regressed, or persisting and an existing
  scenario slug was requested.
- `none`: verdict and audit-chain evidence do not justify scenario work.

## Proposed Scenario Shape

When `recommendation` is not `none`, the proposed scenario object contains:

- `slug`: deterministic suggestion such as
  `learned-<target>-<dominant-subsystem>`.
- `label`: readable title derived from target and subsystem.
- `owner`: dominant subsystem from diagnosis evidence, or `command_harness`
  when evidence is missing.
- `expectation`: `expected_pass` for regression scenarios.
- `finding_policy`: `failure_artifact_on_command_failure`.
- `purpose`: one-sentence runtime rule to capture.
- `minimal_command`: a review prompt for the smallest reproducing command.

The first slice intentionally does not infer exact Zig command arguments for a
new scenario. The proposal should guide the reviewer to choose the smallest
reproducer.

## Proposed Invariants

The command should reuse known invariant ids when the dominant subsystem maps
to one:

- `scope_lifecycle` -> `resource-finalized-after-acquire` or
  `finalizer-failures-are-causal-evidence`, depending on evidence kind.
- `fiber_runtime` -> `scoped-fiber-must-finish-before-scope-close`.
- `schedule_retry` -> `retry-exhaustion-is-recorded`.
- `service_resolution` -> `service-requirement-has-provider`.
- `package` or `command_harness` -> `command-failure-is-causal-evidence`.

If no known invariant matches, the proposal should include a new invariant
draft with an id, subsystem, rule, and detection query. The new invariant is
still only a proposal.

## Text Report

The text report starts with:

```text
zigeffect causal scenario proposal
schema: zigeffect.causal.scenario-proposal.v1
mode: local
target: dogfood
recommendation: refine-scenario
reason: persisting evidence should become reviewed regression coverage
```

It then lists source paths, evidence summary, proposed scenario, proposed
invariants, review checklist, and guardrails.

## Validation

The command validates:

- verdict schema is `zigeffect.causal.dev-loop-verdict.v1`;
- audit-chain schema is `zigeffect.causal.audit-chain.v1`;
- target values match across verdict and audit-chain;
- scenario slug, when supplied, exists in the current scenario registry;
- remediation plan and diagnosis files exist and are readable.

## Acceptance Criteria

- `zig build causal-scenario-proposal -- local` writes deterministic default
  JSON and text reports after local dev-loop artifacts exist.
- `zig build causal-scenario-proposal -- local causal-scoped-fiber` writes
  deterministic scenario JSON and text reports.
- Clear scenario evidence produces `recommendation=none`.
- Persisting dogfood evidence produces a scenario-learning recommendation with
  copied event ids and review guardrails.
- The command is listed by `zig build causal-artifacts`.
- README, agent guide, causal scenario docs, and roadmaps document the command.
- No source registry or invariant files are edited by the command.

## Future Direction

A later slice can add a registry patch generator that consumes the proposal and
writes a reviewable diff. That later tool should require explicit approval and
should reuse the same proposal schema rather than re-analyzing evidence from
scratch.
