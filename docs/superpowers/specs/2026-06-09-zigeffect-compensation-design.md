# zigeffect Compensation Design

Date: 2026-06-09

## Purpose

Milestone 12 adds durable compensation registration and execution. Workflows can
record cleanup actions after successful durable work, run those cleanup actions
in reverse registration order, replay completed compensations without running
them again, and preserve compensation failures through the existing `Exit` and
`Cause` failure detail vocabulary.

## Design

Add compensation identity:

- `CompensationId = u64`;
- `WorkflowEvent.compensation_id: ?CompensationId = null`;
- `compensationId(label)` derived with FNV-1a over the label.

Add workflow journal event kinds:

- `compensation_registered`;
- `compensation_started`;
- `compensation_completed`;
- `compensation_failed`.

Add replay state:

- `CompensationStatus = registered | running | completed | failed`;
- `CompensationState` containing id, status, last sequence, and name.

Checkpoint JSON preserves compensation state alongside activities, timers,
deferreds, and queues.

Add workflow context APIs:

```zig
try context.registerCompensation("refund-charge");
try context.runCompensations(.{
    .{ .label = "refund-charge", .run = RefundCharge.run },
});
```

`runCompensations` reads registered compensation rows from replay history,
walks them in reverse registration order, skips rows already completed in the
journal, appends `compensation_started`, runs the matching handler, and appends
`compensation_completed` or `compensation_failed`.

Handlers are zero-argument functions returning `!void`. This milestone does
not add payload codecs for compensation inputs; handlers close over their own
test or application state.

## Failure Semantics

Failed compensations append `compensation_failed` with:

```text
exit.cause.failure:<error-name>
```

The detail is produced through the same `Exit.cause.failure` formatting path
used for steps and activities.

`runCompensations` returns the typed handler error after the failed event is
journaled. Previously completed compensation rows remain complete and are not
re-run on replay.

## Ordering

Compensations execute in reverse registration order. If a workflow registers:

1. `release-seat`;
2. `refund-charge`;

then `runCompensations` runs `refund-charge` first and `release-seat` second.

## Non-Goals

- No compensation payload serialization.
- No automatic workflow failure hook in `WorkflowEngine`.
- No distributed compensation runner.
- No retry schedule for compensation.

## Acceptance

- Event kind names and JSON/text formatting cover compensation events.
- Replay state and checkpoint JSON preserve compensation rows.
- Registered compensations run in reverse order.
- Re-running compensation after crash skips completed rows.
- Compensation failure appends `compensation_failed` with `Exit`/`Cause`
  detail and returns the typed error.
- `bun run zigeffect:test` passes.
- `cd packages/zigeffect && zig build examples` passes.
- `bun run zig:test` passes.
- Milestone 12 is marked complete in the roadmap.
