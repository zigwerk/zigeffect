# zigeffect Causal Advice Design

## Summary

Add a deterministic `causal-advice` tool that turns saved causal artifacts into
bounded next-action guidance for development agents.

The command is:

```sh
cd packages/zigeffect
zig build causal-advice -- --file <causal-json-artifact>
```

It reads a causal JSON artifact, identifies evidence-shaped events, and prints
actionable but non-mutating advice with event ids and exact follow-up commands.
The causal development loop should also write an advice report during the
`after` phase beside the existing compare and query reports.

## Problem

`zigeffect` now emits causal artifacts, query reports, compare reports, and
package-test failure artifacts. Agents can inspect evidence, but the loop still
leaves the final triage step implicit:

- which finding should be inspected first;
- which query should be run next;
- which runtime subsystem likely owns the issue;
- whether the next action is to fix provider wiring, resource finalization,
  fiber lifecycle, retry policy, command failure, or finalizer failure.

That missing bridge matters for self-improvement. A development agent should be
able to run the loop and receive deterministic next actions grounded in causal
events before editing zigeffect internals.

## Goals

- Add `zig build causal-advice -- --file <path>`.
- Produce line-oriented text optimized for agents and humans.
- Keep advice deterministic and rule-based.
- Include event ids, event kinds, labels, and exact `causal-query` commands.
- Integrate advice report generation into `zig build causal-dev-loop -- after`.
- Preserve the current query and compare tools as separate evidence tools.

## Non-Goals

- Do not call an LLM.
- Do not generate patches.
- Do not retry, restart, mutate runtime memory, or apply remediation.
- Do not rank advice with probabilistic scoring.
- Do not introduce a stable JSON advice schema in this slice.
- Do not replace the query report; advice should summarize what to inspect, not
  duplicate all query output.

## Architecture

Create `packages/zigeffect/tools/causal_advice.zig`.

The tool owns:

- causal JSON parsing for the current artifact shape;
- deterministic event classification;
- duplicate action suppression;
- text report formatting;
- CLI argument parsing;
- tests for every advice class.

It imports `causal_artifact` for taxonomy-version warnings and uses the same
artifact-reading style as `causal_query`.

The causal loop imports `causal_advice` and writes:

- default loop advice:
  `.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-advice.txt`
- scenario loop advice:
  `.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-<scenario>-advice.txt`

## Advice Rules

For each event in the artifact:

- `service_required` with `status = "missing"`
  emits `provide-missing-service`.
- `resource_acquired` without a matching `resource_finalized` event in the same
  scope and type emits `close-resource`.
- `fiber_forked` or `fiber_started` with `status = "pending"` or `"running"`
  emits `resolve-scoped-fiber`.
- `schedule_decision` with `status = "exhausted"` emits
  `inspect-retry-exhaustion`.
- `assertion_recorded` with `status = "failure"` emits
  `inspect-command-failure`.
- `resource_finalized` with `status = "failure"` emits
  `inspect-finalizer-failure`.

Each action includes:

- `event=<id>`;
- `kind=<event_kind>`;
- a short `why`;
- one or more exact `zig build causal-query -- --file <path> ...` commands.

When no advice rules match, the report must say:

```txt
actions: 0
- no causal advice selected
```

## Output Shape

```txt
zigeffect causal advice report
artifact: .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-after.json
actions: 1
- action provide-missing-service event=3 kind=service_required label=Config
  why: service requirement is missing a provider
  run: zig build causal-query -- --file .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-after.json cause 3
  run: zig build causal-query -- --file .zig-cache/causal-artifacts/zigeffect-causal-dev-loop-after.json requirements 1
```

## Development Loop Integration

`zig build causal-dev-loop -- after` should print the advice report path in its
summary after the query report path. This makes the normal development loop:

1. capture after evidence;
2. compare before and after;
3. run follow-up queries;
4. write deterministic advice;
5. rerun package tests.

## Testing

Tests should cover:

- advice for missing services;
- advice for unfinalized resources;
- advice for pending fibers;
- advice for exhausted retries;
- advice for command assertion failures;
- advice for finalizer failures;
- empty advice output;
- taxonomy-version warning propagation;
- loop advice report paths and after-summary output.

Runtime verification should cover:

- `zig build causal-advice -- --file .zig-cache/causal-artifacts/zigeffect-causal-package-tests-failure-fixture.json`;
- `zig build causal-dev-loop -- baseline`;
- `zig build causal-dev-loop -- after`;
- query/advice artifacts exist after the after phase;
- `zig build examples`;
- `zig build test`;
- `bun run zig:test`.

## Acceptance Criteria

- `zig build causal-advice -- --file <artifact>` prints deterministic advice.
- Advice includes event ids and exact query commands.
- `zig build causal-dev-loop -- after` writes an advice report artifact.
- Loop summaries include the advice report path.
- No remediation or patch generation occurs.
- Existing causal query, compare, package test, and fixture commands still pass.

## Roadmap Position

This is the next Milestone 7 slice after automatic query reports. It turns
agent-observable evidence into deterministic next actions while keeping the
system policy-safe and non-mutating.

## Spec Self-Review

- Placeholder scan: no unresolved placeholders remain.
- Internal consistency: command names, artifact paths, and advice rule names are
  stable across sections.
- Scope check: this is one focused local tooling slice. App-facing loops remain
  future work.
- Ambiguity check: advice is deterministic text guidance only; remediation is
  explicitly out of scope.
