# zigeffect Schedule Algebra Design

Date: 2026-06-05

## Goal

Deliver a small roadmap section 7 slice that makes schedule behavior easier to
inspect and combine without introducing recursive schedule objects before the
runtime backend needs them.

## Contracts

- Existing schedule constructors and `nextDelay(attempt)` behavior remain
  unchanged.
- `decision(attempt)` returns a small value describing the attempt, optional
  delay, and whether the schedule continues.
- `isExhausted(attempt)` is a readable helper for tests and control paths.
- `unionNextDelay(other, attempt)` composes two schedules by allowing either
  schedule to continue and choosing the earlier available delay.
- `intersectionNextDelay(other, attempt)` composes two schedules by requiring
  both schedules to continue and choosing the later delay.

## Non-Goals

- No recursive schedule AST yet.
- No timeout/reset/backend-sleep changes yet.
- No stateful schedule mutation yet; the core remains deterministic and
  attempt-index driven.

## Tests

- Decision/state inspection reports continuing and exhausted attempts.
- Union-style composition continues while either schedule continues.
- Intersection-style composition continues only while both schedules continue.

