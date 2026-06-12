# zigeffect Causal Dev Harness

The causal dev harness is the local feedback loop for improving zigeffect with
zigeffect's own causal runtime evidence. Use it before adding another governance
or report layer.

## Root Commands

From the repository root, prefer the Bun scripts:

```sh
bun run zigeffect:causal-test
bun run zigeffect:causal-dev-test
bun run zigeffect:causal-catalog
bun run zigeffect:causal-artifacts
bun run zigeffect:causal-ci-handoff
bun run zigeffect:causal-loop:baseline
bun run zigeffect:causal-loop:after
```

The scripts delegate to the Zig build steps under `packages/zigeffect`.

## Failure Triage

Use `bun run zigeffect:causal-dev-test` when a zigeffect package test failure
needs agent-readable evidence. It wraps the package tests through `causal-run`
and writes artifacts under `.zig-cache/causal-artifacts/` when the package test
command fails.

Read artifacts in this order:

1. `zigeffect-causal-package-tests.txt` for the human report.
2. `zigeffect-causal-package-tests.json` for event ids, finding details, and
   bounded agent queries.
3. `zigeffect-causal-package-tests.dot` when graph shape helps.
4. `zigeffect-causal-ci-handoff.txt` after running
   `bun run zigeffect:causal-ci-handoff` when several artifacts exist.

The report's query lines should be treated as evidence gathering, not as fix
instructions. Cite event ids and findings before changing code.

## Before And After Loop

For behavior-sensitive changes:

```sh
bun run zigeffect:causal-loop:baseline
# edit zigeffect
bun run zigeffect:causal-loop:after
```

The after phase writes:

- `zigeffect-causal-dev-loop-after.json`
- `zigeffect-causal-dev-loop-compare.txt`
- `zigeffect-causal-dev-loop-queries.txt`
- `zigeffect-causal-dev-loop-advice.txt`
- `zigeffect-causal-dev-loop-verdict.json`

Use the compare report to separate new evidence from baseline evidence. Use the
query report for exact `zig build causal-query -- ...` commands. Use the advice
and verdict as deterministic, non-mutating triage summaries.

## Scenario Selection

Run `bun run zigeffect:causal-catalog` to choose a smaller scenario when a
change touches one runtime area. The scenario registry names owners, invariant
ids, expected pass/failure behavior, and coverage domains.

Common direct scenario workflow from `packages/zigeffect`:

```sh
zig build causal-run -- causal-scoped-fiber
zig build causal-dev-loop -- baseline causal-scoped-fiber
zig build causal-dev-loop -- after causal-scoped-fiber
```

## Safety Boundary

This harness is local and evidence-only.

- It does not mutate source.
- It does not apply registry patches.
- It does not enforce CI gates.
- It does not mutate GitHub workflows.
- It does not send production telemetry.
- It does not write NenDB records or execute a NenDB adapter.
- It does not introduce Cockroach scope.

Keep future harness work inside this boundary unless a reviewed authority branch
explicitly changes it.
