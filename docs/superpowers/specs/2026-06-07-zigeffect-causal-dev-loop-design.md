# zigeffect Causal Dev Loop Design

## Summary

Add the first automated development loop command for `zigeffect`:

```sh
zig build causal-dev-loop -- baseline
zig build causal-dev-loop -- after
```

The command gives agents a repeatable way to capture a causal baseline before a
runtime patch, rerun the same evidence lane after the patch, compare the saved
artifacts, and keep package tests in the same local loop.

## Problem

The current causal dogfood branch can emit artifacts, query them, compare two
JSON files, and run package tests through causal failure capture. An agent still
has to manage the before/after artifact names manually and remember which
commands belong together.

That leaves the workflow useful but fragile: a patch summary can cite evidence,
but the evidence loop is not yet a single project command.

## Goals

- Add `zig build causal-dev-loop -- baseline`.
- Add `zig build causal-dev-loop -- after`.
- Persist stable before/after JSON paths under `.zig-cache/causal-artifacts/`.
- Write a stable compare report on the `after` phase.
- Run the package-test development gate in both phases.
- Print an agent-readable summary with artifact paths and next actions.
- Keep the loop local, deterministic, and network-free.

## Non-Goals

- Do not apply patches or watch the filesystem.
- Do not require a Git diff or Git worktree to run.
- Do not compare passing command traces that do not yet emit causal artifacts.
- Do not replace `causal-test`, `causal-dev-test`, `causal-query`, or
  `causal-compare`.
- Do not add CI upload, retention, or schema-version hardening yet.

## Command Shape

Baseline phase:

```sh
zig build causal-dev-loop -- baseline
```

The command should:

- build the deterministic dogfood causal artifact;
- write the normal dogfood artifacts;
- write `.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-before.json`;
- run the package-test scenario from the registry;
- print a summary that tells the agent to make the patch and run the after
  phase.

After phase:

```sh
zig build causal-dev-loop -- after
```

The command should:

- require the before JSON path to exist;
- build the deterministic dogfood causal artifact again;
- write the normal dogfood artifacts;
- write `.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-after.json`;
- compare before and after JSON with the existing compare engine;
- write `.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-compare.txt`;
- run the package-test scenario from the registry;
- print a summary that points at the compare report and useful next queries.

## Artifact Paths

Use these stable paths:

- `.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-before.json`
- `.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-after.json`
- `.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-compare.txt`

The normal dogfood artifacts should continue to be written through
`causal_test`:

- `.zig-cache/causal-artifacts/zigeffect-causal-dogfood.txt`
- `.zig-cache/causal-artifacts/zigeffect-causal-dogfood.json`
- `.zig-cache/causal-artifacts/zigeffect-causal-dogfood.dot`

## Package-Test Gate

The loop should run the existing `package-tests` scenario from
`tools/causal_run.zig`. If package tests fail, the command should write the same
scenario-specific failure artifacts as `zig build causal-dev-test` and exit
nonzero.

When package tests pass, the loop summary should say `package-tests: pass`.

## Summary Output

Baseline summary should include:

- header: `zigeffect causal dev loop`;
- `phase: baseline`;
- dogfood finding count;
- before JSON path;
- package-test status;
- next command: `zig build causal-dev-loop -- after`.

After summary should include:

- header: `zigeffect causal dev loop`;
- `phase: after`;
- dogfood finding count;
- after JSON path;
- compare report path;
- package-test status;
- suggested follow-up query commands against the after artifact.

## Design Boundaries

`causal-dev-loop` is an orchestrator. It should reuse:

- `causal_test.buildDogfoodArtifacts` for deterministic causal evidence;
- `causal_compare.runCompare` for before/after diffing;
- `causal_run.scenarioByName("package-tests")` and
  `causal_run.buildFailureArtifacts` for package-test failure capture.

The compare engine should remain independent so agents can compare arbitrary
artifacts manually.

## Testing

Tests should cover:

- stable dev-loop artifact paths;
- baseline summary formatting;
- after summary formatting with compare path and query hints;
- package-test exit code policy.

The CLI should also be verified manually with:

```sh
cd packages/zigeffect
zig build causal-dev-loop -- baseline
zig build causal-dev-loop -- after
```

## Acceptance Criteria

- `zig build causal-dev-loop -- baseline` exits zero when package tests pass.
- `zig build causal-dev-loop -- after` exits zero when package tests pass and a
  before artifact exists.
- Baseline and after JSON artifacts are written to stable paths.
- The compare report is written to a stable path during the after phase.
- Package-test failure still produces causal failure artifacts.
- `zig build examples`, `zig build test`, and `bun run zig:test` pass.

## Roadmap Position

This is the first concrete slice of Milestone 7. It does not finish the full
self-improving system, but it turns the existing causal runtime artifacts into
a repeatable local development loop that agents can run before and after
changes.
