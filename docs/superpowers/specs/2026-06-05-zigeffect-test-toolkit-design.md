# zigeffect Test Toolkit Design

Date: 2026-06-05

## Goal

Deliver a focused roadmap section 11 slice by adding small assertion helpers
over existing deterministic services and reports.

## Contracts

- `TestEnv` gains structured log and histogram assertions.
- `fx.testing` gains standalone helpers for dependency reports, causes, and
  schedule decisions.
- Helpers use existing public contracts; they do not introduce test-only
  semantics that production code cannot exercise.

## Non-Goals

- No golden-file framework yet.
- No fixture registry yet.
- No custom test runner yet.

## Tests

- Structured log and histogram assertions pass for matching data.
- Dependency report helper checks missing services.
- Cause helpers check finalizer failures, defects, and interruptions.
- Schedule helper checks expected delay decisions.

