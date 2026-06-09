# zigeffect Durable Clock And Timers Design

Date: 2026-06-09

## Purpose

Milestone 14 adds durable sleep. Workflows can schedule a timer, suspend while
the timer is pending, resume after a local scheduler appends `timer_fired`, and
replay without scheduling duplicate timers.

## Design

Add `workflow/clock.zig`:

- `timerId(label)`;
- `TimerSleepResult`;
- `DurableClock`;
- due timer query and fire APIs.

Timer scheduled rows use:

```text
redacted_detail = "fire_at_ms=<timestamp>"
```

`WorkflowContext.sleep(label, delay_ms)` computes `fire_at_ms` from the optional
context clock, appends `timer_scheduled` when absent, appends
`workflow_suspended`, and returns `.suspended`.

`WorkflowContext.sleepUntil(label, fire_at_ms)` uses the provided timestamp.

If replay history contains `timer_fired`, sleep returns `.fired`. If it contains
`timer_cancelled`, sleep returns `.cancelled`.

`DurableClock.fireDueTimers(now_ms)` reads the journal, finds scheduled timers
whose `fire_at_ms <= now_ms`, skips fired/cancelled timers, and appends
`timer_fired`.

The file-store wake-up loop for this milestone is a synchronous local helper:
`fireDueTimers` works against any `JournalStore`, including `FileJournalStore`.

## Non-Goals

- No background thread.
- No OS event loop.
- No distributed timer ownership.
- No clustered scheduler.

## Acceptance

- Sleeping on a missing timer appends scheduled and suspended rows.
- Replaying before fire returns suspension without duplicate schedule rows.
- Firing due timers appends `timer_fired`.
- Replaying after fire returns `.fired`.
- Cancelling a timer appends `timer_cancelled` and replay returns cancelled.
- Due timer query reports pending due timers.
- The same helper works with `FileJournalStore`.
- `bun run zigeffect:test` passes.
- `cd packages/zigeffect && zig build examples` passes.
- `bun run zig:test` passes.
- Milestone 14 is marked complete in the roadmap.
