# zigeffect Deterministic Workflow Step Runner Design

Date: 2026-06-09

## Purpose

Milestone 9 adds the first replay-aware workflow context. Pure steps can record
their result once, then replay from the journal without re-running the step.

## Design

Add `packages/zigeffect/src/workflow/context.zig` and expose it through
`fx.workflow`.

Extend `WorkflowEventKind` with:

- `step_started`;
- `step_completed`;
- `step_failed`.

`WorkflowContext` owns:

- allocator;
- journal store;
- workflow id;
- execution id;
- next journal sequence;
- a caller-owned replay batch read during initialization.

The first step API is:

```zig
try context.stepU64("load-account", loadAccount);
```

`stepU64` is intentionally narrow: it proves deterministic replay mechanics
before payload codecs/general result serialization land.

## Replay Semantics

On `stepU64(label, run_fn)`:

- if replay history already contains `step_completed` for `label`, parse and
  return the recorded `redacted_detail` value without calling `run_fn`;
- otherwise append `step_started`, call `run_fn`, then append `step_completed`;
- if `run_fn` returns an error, append `step_failed` with an
  `Exit.cause.failure:<error-name>` detail and return the typed error.

Sequence numbers are assigned from the latest event in the journal plus one.

## Non-Goals

- No activity execution.
- No generic payload/result codecs.
- No workflow engine integration.
- No durable queues/timers.
- No completion events.

## Acceptance

- A first run records step events.
- A replay returns the recorded result without calling the step function again.
- Failed steps append `step_failed` with the typed error represented through
  `Exit` and `Cause`.
- `bun run zigeffect:test` passes.
- `cd packages/zigeffect && zig build examples` passes.
- `bun run zig:test` passes.
- Milestone 9 is marked complete in the roadmap.
