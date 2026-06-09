# zigeffect Activity Retry And Timeout Design

Date: 2026-06-09

## Purpose

Milestone 11 connects durable activities to existing `Schedule` and `Clock`
behavior. Failed activity attempts can produce durable retry decisions, fake or
system clocks can observe retry delays, exhausted retry budgets are journaled,
and timeout metadata can terminate an activity durably.

## Design

Add workflow journal event kinds:

- `activity_retry_scheduled`;
- `activity_timed_out`.

`activity_retry_scheduled` records a schedule decision after a failed activity
attempt. It uses the activity id as replay identity, the failed activity attempt
as `attempt`, status `retry`, and detail:

```text
attempt=<schedule-attempt> delay_ms=<delay> decision=retry
```

When the retry budget is exhausted, `WorkflowContext.activity` appends
`activity_failed` with status `exhausted` and detail:

```text
attempt=<schedule-attempt> delay_ms=null decision=exhausted;exit.cause.failure:<error-name>
```

Timeouts append `activity_timed_out` with status `timeout` and detail:

```text
exit.cause.failure:ActivityTimeout
```

Replay treats `activity_retry_scheduled` as `ActivityStatus.retry_ready` and
`activity_timed_out` as `ActivityStatus.failed`.

`WorkflowContextOptions` gains optional durable runtime integrations:

- `clock: ?*Clock = null`;
- `causal_store: ?*CausalStore = null`;
- `causal_run_id: ?u64 = null`.

The context records retry and exhausted decisions into `CausalStore` as
`schedule_decision` events, using the same detail string as the journal. This
keeps workflow retry diagnostics aligned with existing Effect retry diagnostics.

## Execution Semantics

`WorkflowContext.activity` keeps one-based activity attempts. Schedule
decisions remain zero-based, matching `Effect.retry`:

- activity attempt `1` fails;
- schedule decision attempt `0` decides whether to retry;
- after a retry delay, activity attempt `2` runs.

If an activity has no retry schedule, the first failure remains the terminal
`activity_failed` event from Milestone 10.

If an activity has a retry schedule:

- on failure with a continuing schedule decision, append
  `activity_retry_scheduled`, record causal `schedule_decision`, sleep the
  configured clock when present, increment the activity attempt, and run again;
- on failure with an exhausted schedule decision, append terminal
  `activity_failed` with status `exhausted`, record causal
  `schedule_decision`, and return the typed error.

If an activity has timeout metadata:

- a timeout of `0` terminates before the runner is called;
- if a clock is present, elapsed time after a runner call is compared to the
  timeout and a timeout terminal event is appended when elapsed time exceeds
  the limit.

Timeout activities must use an error set containing `ActivityTimeout`, allowing
replay to return the typed timeout error.

## Non-Goals

- No async cancellation of a currently running synchronous function.
- No worker polling.
- No timers as separate durable wakeup resources.
- No compensation.
- No cluster coordination.

## Acceptance

- Event kind names cover retry scheduling and timeout.
- Replay folds retry scheduled events to `retry_ready`.
- Replay folds timeout events to failed activity state.
- Retry success records a retry decision, sleeps a fake clock, and completes a
  later attempt.
- Retry exhaustion records an exhausted schedule decision and returns the typed
  error on first run and replay.
- Timeout records `activity_timed_out` and returns `error.ActivityTimeout` on
  first run and replay.
- Causal store retry snapshots include workflow activity schedule decisions.
- `bun run zigeffect:test` passes.
- `cd packages/zigeffect && zig build examples` passes.
- `bun run zig:test` passes.
- Milestone 11 is marked complete in the roadmap.
