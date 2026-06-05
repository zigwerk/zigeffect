# zigeffect Schedule Programs Design

Date: 2026-06-05

## Goal

Move schedule composition from one-off decision helpers to an owned recursive
program shape while preserving the existing `Schedule` value API.

## Design

Add `ScheduleProgram` in `packages/zigeffect/src/effect/schedule.zig`. It owns a
set of allocated nodes and exposes explicit `deinit`.

Node variants:

- `schedule`: a concrete `Schedule`
- `union`: continue while either child continues, choosing the shorter delay
- `intersection`: continue only while both children continue, choosing the
  longer delay
- `sequence`: run the first child until exhausted, then run the second child
  with attempts reset to zero

The program exposes:

- `init(allocator)`
- `deinit()`
- `schedule(schedule)`
- `unionWith(left, right)`
- `intersectionWith(left, right)`
- `sequence(first, second)`
- `nextDelay(attempt)` for the current root
- `nextDelayFor(node, attempt)` for a specific node
- `decision(attempt)` for root-level state inspection

`Schedule` also gains `maxContinuations()` so sequence can reset the second
program after the first child is exhausted without probing arbitrary attempts.

## Non-Goals

- Do not change retry/repeat signatures in this slice.
- Do not add infinite schedules yet.
- Do not add async sleep behavior; retry/repeat already route delays through
  the active context clock when available.

## Tests

Add tests in `packages/zigeffect/test/schedule_test.zig` for recursive union,
intersection, and sequence programs, including root decisions and direct node
inspection.
