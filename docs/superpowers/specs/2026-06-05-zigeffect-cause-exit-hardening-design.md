# zigeffect Cause And Exit Hardening Design

Date: 2026-06-05

## Goal

Deliver a focused roadmap section 6 slice by making runtime-generated cleanup
causes preserve the original exit status without introducing a half-finished
owned recursive cause tree.

## Contracts

- `exitWithFinalizerFailure` preserves typed failures, defects, and
  interruptions when cleanup also fails.
- Cleanup-only failures remain `Cause.finalizer_failure`.
- Program failure plus cleanup failure remains
  `Cause.failure_then_finalizer_failure`.
- Defect plus cleanup failure becomes `Cause.defect_then_finalizer_failure`.
- Interruption plus cleanup failure becomes
  `Cause.interrupted_then_finalizer_failure`.
- Small cause-inspection helpers make tests less dependent on matching a single
  direct variant.

## Non-Goals

- Do not replace pointer-backed recursive `sequential`, `parallel`, or
  `annotated` causes yet. That is still a larger owned-cause migration.
- Do not allocate cause trees in runtime exits yet.

## Tests

- `exitWithFinalizerFailure` preserves defect plus cleanup failure.
- `exitWithFinalizerFailure` preserves interruption plus cleanup failure.
- Cause helper functions find finalizer failures, defects, and interruptions
  through direct and combined variants.
