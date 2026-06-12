# zigeffect Causal Dev Harness Recovery Design

## Goal

Return the roadmap to the intended self-improving zigeffect development loop and
make the existing causal harness the default agent workflow for local zigeffect
changes.

## Current Context

The useful harness already exists:

- `zig build causal-test` writes dogfood causal CI reports, JSON, and DOT.
- `zig build causal-dev-test` wraps package tests through `causal-run`.
- `zig build causal-dev-loop -- baseline|after [scenario]` records before/after
  JSON, compare reports, query reports, advice reports, and verdict JSON.
- `zig build causal-ci-handoff` reads available causal artifacts and generates a
  first-read report for agents.
- `zig build causal-query`, `causal-compare`, and `causal-advice` provide the
  machine-readable analysis surface.

The problem is not missing infrastructure. The problem is discoverability and
roadmap drift: agents need a small, stable entrypoint from the repo root and a
clear written workflow that says "use the harness now" instead of continuing
recursive app-facing report levels.

## Design

This recovery pass keeps the harness local and non-mutating.

1. Add root Bun scripts for the common causal development commands so agents can
   obey the repository rule to use Bun for project tasks while still reaching
   the zigeffect Zig harness.
2. Tighten `causal-dev-loop` query report output so every generated query line
   is a directly runnable `zig build causal-query -- ...` command.
3. Add a focused harness guide that names the primary flows:
   `causal-dev-test` for package-test failures, `causal-dev-loop` for
   before/after work, `causal-ci-handoff` for first-read artifact triage, and
   `causal-run catalog` for scenario selection.
4. Keep all behavior deterministic and local. The recovery pass must not add
   CI enforcement, workflow mutation, app runtime mutation, production telemetry,
   Cockroach scope, durable writes, or auto-apply behavior.

## Data And Artifact Flow

For a normal zigeffect change:

1. Run a baseline capture before editing when the change is behavior-sensitive.
2. Make the code change.
3. Run the after capture.
4. Inspect the compare report, query report, advice report, and verdict JSON.
5. Run the regular package and repo checks.

For a failure:

1. Run `causal-dev-test` or the relevant `causal-run` scenario.
2. Read the generated `.txt` report first.
3. Use the `.json` artifact with `causal-query --agent` for bounded machine
   analysis.
4. Use `causal-ci-handoff` when multiple artifacts exist.

## Non-Goals

- No new production adapter.
- No Cockroach work.
- No NenDB writes or adapter execution in this pass.
- No GitHub workflow mutation.
- No required status checks or CI gate enforcement.
- No source mutation from advice, verdict, or handoff reports.
- No continuation of recursive app-facing levels unless a human explicitly asks
  for that chain again.

## Acceptance Criteria

- Root scripts expose the causal harness from the repository root.
- `causal-dev-loop` query reports print runnable `zig build causal-query -- ...`
  commands.
- The docs describe the intended self-improving loop and the failure triage
  path.
- Focused Zig tests and root Bun verification pass.
