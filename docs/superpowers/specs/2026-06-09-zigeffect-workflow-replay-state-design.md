# zigeffect Workflow Replay State Design

Date: 2026-06-09

## Purpose

Milestone 3 turns workflow journal events into deterministic in-memory replay
state. This validates the event vocabulary before any journal store persists it.

## Design

Add `packages/zigeffect/src/workflow/replay.zig` and expose it through
`fx.workflow`.

The replay module owns:

- `WorkflowStatus`: `pending`, `running`, `suspended`, `completed`, `failed`,
  `interrupted`, `defect`;
- `ActivityStatus`: `scheduled`, `running`, `completed`, `failed`,
  `retry_ready`;
- `TimerStatus`: `scheduled`, `fired`, `cancelled`;
- `DeferredStatus`: `pending`, `completed`, `failed`, `cancelled`;
- `QueueStatus`: `offered`, `claimed`, `completed`, `failed`, `acked`;
- state rows for activities, timers, deferreds, and queues;
- `ReplayError` for malformed histories;
- `WorkflowReplayState`;
- `WorkflowReplayState.apply(event)`;
- `WorkflowReplayState.fold(allocator, events)`.

Use allocator-owned `std.ArrayList` rows and simple linear lookup. This is
deliberate: later milestones can replace storage internals without changing the
fold contract.

## Folding Rules

- `workflow_started` transitions `pending` to `running` and records workflow and
  execution ids.
- workflow terminal events transition to `completed`, `failed`,
  `interrupted`, or `cancelled`.
- `workflow_suspended` transitions `running` to `suspended`.
- `workflow_resumed` transitions `suspended` to `running`.
- activity scheduled/started/completed/failed events update an activity row by
  `activity_id`.
- timer scheduled/fired/cancelled events update a timer row by `timer_id`.
- deferred created/awaited/completed/failed/cancelled events update a deferred
  row by `deferred_id`.
- queue offered/claimed/completed/failed/acked events update a queue row by
  `queue_id`.

## Malformed Histories

The fold rejects:

- events before `workflow_started`;
- duplicate `workflow_started`;
- events after terminal workflow status;
- missing target ids for activity, timer, deferred, or queue events;
- duplicate creation/scheduling/offering for the same target id;
- updates to unknown target ids.

The first version returns typed errors and keeps detailed diagnostics for a
future report formatter.

## Non-Goals

- No journal store.
- No parsing.
- No compaction or snapshots.
- No workflow execution.
- No retry schedule math.
- No persistence.

## Acceptance

- Tests cover lifecycle, activities, timers, deferreds, queues, and malformed
  histories.
- `bun run zigeffect:test` passes.
- `cd packages/zigeffect && zig build examples` passes.
- `bun run zig:test` passes.
- Milestone 3 is marked complete in the roadmap.
