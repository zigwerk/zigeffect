# zigeffect Workflow Lifecycle Controls Design

Date: 2026-06-09

## Purpose

Milestone 17 exposes durable lifecycle controls for workflow executions:
suspend, resume, interrupt, and cancel. These controls are append-only journal
operations that survive restart and make pending durable work behavior explicit.

## Design

Add `workflow/lifecycle.zig`:

- `WorkflowLifecycle`;
- `LifecycleActionResult`;
- helpers for current lifecycle status;
- pending-work cancellation helpers.

`WorkflowLifecycle.suspendWorkflow(reason)` appends `workflow_suspended` when the
workflow is running and returns `false` when it is already suspended or
terminal.

`WorkflowLifecycle.resumeWorkflow(reason)` appends `workflow_resumed` when the
workflow is suspended and returns `false` when it is running or terminal.

`WorkflowLifecycle.interrupt(reason)` appends terminal pending-work rows and
then `workflow_interrupted` with an interruption detail.

`WorkflowLifecycle.cancel(reason)` appends terminal pending-work rows and then
`workflow_cancelled` with a cancellation detail.

Pending work policy for `interrupt` and `cancel`:

- scheduled timers get `timer_cancelled`;
- pending/awaited deferreds get `deferred_cancelled`;
- offered/claimed/retry-ready queues get `queue_failed`;
- scheduled/running/retry-ready activities get `activity_failed`.

All pending terminal rows use lifecycle-specific detail text so later
inspectors can explain why work stopped. Terminal workflows reject further
lifecycle transitions by returning `false` rather than appending duplicate rows.

## Acceptance

- Suspend and resume append durable lifecycle rows and replay correctly before
  and after restart.
- Interrupt appends a terminal workflow row with cause detail.
- Cancel appends a terminal workflow row with reason detail.
- Pending timers, deferreds, queues, and activities receive explicit terminal
  rows during interrupt/cancel.
- Repeating a lifecycle action after restart does not duplicate rows.
- `bun run zigeffect:test` passes.
- `cd packages/zigeffect && zig build examples` passes.
- `bun run zig:test` passes.
- Milestone 17 is marked complete in the roadmap.
