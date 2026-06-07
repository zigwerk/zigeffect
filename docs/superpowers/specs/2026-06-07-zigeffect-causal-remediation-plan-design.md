# zigeffect Causal Remediation Plan Design

## Purpose

`zigeffect` now uses its causal runtime during local development: agents can
capture before/after artifacts, read verdicts, route inspection, synthesize a
diagnosis, and cite event evidence. The next useful step is not automatic
patching. It is a deterministic, non-mutating remediation plan that turns a
diagnosis into an evidence-bound engineering brief.

This slice adds:

```sh
zig build causal-remediation-plan -- local [scenario]
```

The command reads local dev-loop artifacts and writes a Markdown remediation
plan. The plan proposes patch strategy, required tests, and claim guardrails,
but never edits source, invokes an LLM, executes remediation commands, or marks
an issue fixed.

## Current State

The current local self-improvement path is:

```sh
zig build causal-dev-loop -- baseline [scenario]
zig build causal-dev-loop -- after [scenario]
zig build causal-dev-agent -- local [scenario]
zig build causal-diagnosis -- local [scenario]
```

The after phase writes the local bundle:

- `*-before.json`;
- `*-after.json`;
- `*-compare.txt`;
- `*-queries.txt`;
- `*-advice.txt`;
- `*-verdict.json`.

`causal-diagnosis` adds `*-diagnosis.txt` by summarizing the verdict, advice,
query, and compare artifacts. It cites event ids and maps advice actions to
subsystems and fix categories.

Agents still need to convert that diagnosis into a disciplined implementation
plan. That conversion should be deterministic and inspectable before any code
changes happen.

## Design Principles

- **Non-mutating by default.** The tool writes a plan artifact only.
- **Evidence first.** Every proposed remediation item cites event ids or the
  artifact path that justifies it.
- **Controlled remediation.** This is a planning boundary, not a patch executor.
- **Before-aware claims.** `new`, `persisting`, and `observed` evidence produce
  different patch posture and verification language.
- **Local and offline.** The command uses saved artifacts only; it does not
  require network, app services, or external agents.
- **Readable Markdown.** The output is meant for humans and agents to review
  before a branch begins implementation.

## Command Shape

Default dogfood target:

```sh
zig build causal-remediation-plan -- local
```

Scenario target:

```sh
zig build causal-remediation-plan -- local causal-scoped-fiber
```

The command reads the matching local dev-loop bundle and writes:

```text
.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-remediation-plan.md
.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-<scenario>-remediation-plan.md
```

Usage errors print:

```text
causal-remediation-plan error: <error-name>
usage: zig build causal-remediation-plan -- local [scenario]
```

The command should fail with usage-style exit code `2` when required local
artifacts are missing, malformed, or from an unsupported schema.

## Inputs

The remediation planner reads these artifacts:

- local verdict JSON;
- local diagnosis report;
- local advice report;
- local query report;
- local compare report when the verdict names one.

The verdict remains the schema anchor:

```text
zigeffect.causal.dev-loop-verdict.v1
```

The diagnosis and advice reports are text artifacts, so the first
implementation should parse only stable line prefixes:

- `target:`;
- `status:`;
- `next_action:`;
- `actions:`;
- `new_actions:`;
- `persisting_actions:`;
- `observed_actions:`;
- `- action ... status=... event=... kind=... label=...`;
- `subsystem:`;
- `fix category:`;
- `diagnosis:`;
- `patch prompt:`;
- `citations:`.

If a text field is missing, the planner should keep the report readable and
fall back to the verdict or advice path rather than inventing evidence.

## Remediation Posture

The report should classify the overall plan with one posture:

- `do-not-patch`: verdict is clear or there are no advice actions.
- `regression-candidate`: one or more actions are `status=new`.
- `investigate`: actions are `status=observed` without a baseline comparison.
- `patch-candidate`: actions are `status=persisting` and the agent wants to
  remove existing causal findings.

Posture rules:

- `new` evidence must be described as a possible regression introduced by the
  current patch.
- `persisting` evidence must be described as existing evidence that the current
  patch did not fix.
- `observed` evidence must be described as evidence without before/after proof.
- `clear` verdicts must not produce a patch strategy.

## Report Shape

Example attention report:

```markdown
# zigeffect causal remediation plan

mode: local
target: dogfood
posture: patch-candidate
verdict: .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-verdict.json
diagnosis: .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-diagnosis.txt

## Summary

- status: attention
- next action: inspect-persisting-advice
- evidence posture: persisting
- compare guardrail: no before/after event or finding delta

## Evidence

- event 4 `resource_acquired` status=persisting
  - subsystem: scope_lifecycle
  - fix category: resource-finalizer
  - label: dogfood database
  - citation: .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-advice.txt

## Proposed Remediation

1. Patch candidate: scope_lifecycle / resource-finalizer
   - Inspect acquire/release ownership around the cited resource event.
   - Add or wire the missing finalizer only if the fixture is meant to be
     healthy.
   - Add a focused causal scenario or assertion before changing runtime logic.

## Required Verification

- `zig build causal-dev-loop -- baseline`
- `zig build causal-dev-loop -- after`
- `zig build causal-diagnosis -- local`
- `zig build test --summary none`

## Claim Guardrails

- Do not claim this patch fixed persisting evidence unless the after verdict is
  clear or the compare report shows fewer findings.
- Cite event ids from the remediation evidence section in the patch summary.
- Treat this plan as guidance, not permission to edit unrelated subsystems.
```

For scenario targets, the verification commands use the scenario slug:

```sh
zig build causal-dev-loop -- baseline causal-scoped-fiber
zig build causal-dev-loop -- after causal-scoped-fiber
zig build causal-diagnosis -- local causal-scoped-fiber
zig build test --summary none
```

## Action Strategy Mapping

The first implementation should reuse the same action vocabulary as diagnosis:

- `provide-missing-service`
  - patch area: service or layer provider wiring;
  - required check: requirements query and package tests.
- `close-resource`
  - patch area: scope ownership or finalizer registration;
  - required check: resources query and causal dev-loop.
- `resolve-scoped-fiber`
  - patch area: structured concurrency, join, interrupt, or parent scope close;
  - required check: `causal-scoped-fiber` scenario when relevant.
- `inspect-retry-exhaustion`
  - patch area: retry policy, schedule boundary, or failure specificity;
  - required check: retry query and scenario when relevant.
- `inspect-command-failure`
  - patch area: test failure, fixture, command harness, or source behavior;
  - required check: the failing command plus package tests.
- `inspect-finalizer-failure`
  - patch area: cleanup cause preservation or finalizer error handling;
  - required check: cleanup-failure scenario when relevant.

Unknown actions remain inspectable and should produce `investigate` strategy
text rather than a confident patch category.

## Docs And Manifest Catch-Up

This slice should also keep public artifact documentation aligned:

- `zig build causal-artifacts` should list default and scenario diagnosis paths.
- `zig build causal-artifacts` should list default and scenario remediation-plan
  paths.
- `packages/zigeffect/README.md` should document verdict, dev-agent,
  diagnosis, and remediation-plan workflow together.
- `packages/zigeffect/docs/agent-guide.md` and
  `packages/zigeffect/docs/causal-scenarios.md` should show the new command
  after diagnosis.
- The self-improvement roadmap should record the delivered slice after
  implementation.

## Non-Goals

- No automatic source edits.
- No generated patch diffs.
- No LLM invocation.
- No policy approval engine.
- No production self-healing.
- No durable remediation history yet.

Those belong after the remediation plan format is stable and reviewed.

## Verification

Implementation should prove:

- `zig build causal-remediation-plan -- local` works after a default after-phase
  run and diagnosis run.
- `zig build causal-remediation-plan -- local causal-scoped-fiber` works after a
  scenario after-phase run and diagnosis run.
- Missing inputs fail with usage text.
- The default artifact manifest lists diagnosis and remediation-plan paths.
- Scenario artifact manifest entries list diagnosis and remediation-plan paths.
- `zig build examples` includes the new tests and executable.
- `zig build test --summary none` passes in `packages/zigeffect`.
- `bun run zig:test` passes at the repo root.

## Risks

- Text parsing can drift if diagnosis output changes. Keep parsing to stable
  prefixes and add tests for multi-word labels.
- A plan can sound more authoritative than the evidence supports. Use posture
  language and guardrails to keep uncertainty visible.
- The tool can duplicate diagnosis mapping. Keep strategy mapping small and
  consistent with the existing action vocabulary until a shared helper is worth
  extracting.

## Alternatives Considered

### Extend `causal-diagnosis`

This would reduce executable count, but it would mix explanation with planning.
Diagnosis should stay the evidence synthesis layer; remediation planning is a
separate approval boundary.

### Extend `causal-dev-agent`

This would make the first-read router too broad. `causal-dev-agent` should tell
agents what to inspect; the remediation planner should produce the engineering
brief after the evidence has been inspected.

### Generate Source Patches

This is intentionally deferred. The runtime design says remediation must be
controlled and evidence-cited, and arbitrary hot-patching is a non-goal. A
reviewable plan artifact is the safer next maturity step.

## Self-Review

- Placeholder scan: no placeholder sections or deferred requirements are used.
- Internal consistency: command name, artifact names, and posture names are
  consistent throughout the design.
- Scope check: this is one command plus documentation/manifest catch-up, not a
  policy engine or source-editing system.
- Ambiguity check: the command writes a plan artifact only and never applies
  remediation.
