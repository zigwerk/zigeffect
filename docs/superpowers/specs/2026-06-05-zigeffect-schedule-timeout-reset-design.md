# zigeffect Schedule Timeout And Reset Design

## Goal

Add timeout and reset policy vocabulary to `Schedule` while preserving the
current deterministic, stateless `nextDelay(attempt)` model.

## Chosen Approach

Introduce two practical policies:

- `Schedule.timeout`: fixed-delay retries capped by a maximum elapsed delay
  budget.
- `Schedule.reset`: fixed-delay retries plus `resetAttempt`, a helper that tells
  tests/runtimes when idle time should reset retry state back to attempt zero.

This avoids inventing a recursive schedule interpreter before the async backend
exists, but gives agents and future runtime work stable policy names.

## Contract

- `timeout` returns `null` when the next delay would exceed `timeout_ms`.
- `reset` behaves like fixed delay for `nextDelay`.
- `resetAttempt(attempt, idle_ms)` returns zero when the reset policy's idle
  threshold is reached; other schedule kinds keep the attempt unchanged.
- Existing schedule constructors and retry/repeat behavior remain unchanged.

## Tests

- Timeout schedules stop before exceeding elapsed delay budget.
- Reset schedules expose idle reset behavior.
- Non-reset schedules leave attempts unchanged through `resetAttempt`.
