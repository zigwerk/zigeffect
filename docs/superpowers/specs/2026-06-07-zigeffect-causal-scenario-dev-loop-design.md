# zigeffect Scenario-Aware Causal Dev Loop Design

## Summary

Extend the causal development loop so agents can run before/after evidence for
a selected scenario:

```sh
zig build causal-dev-loop -- baseline causal-scoped-fiber
zig build causal-dev-loop -- after causal-scoped-fiber
```

The existing no-argument form remains the default dogfood loop:

```sh
zig build causal-dev-loop -- baseline
zig build causal-dev-loop -- after
```

## Problem

The current loop compares only the deterministic dogfood artifact and runs the
package-test gate. That is useful as a default proof that the loop works, but it
does not yet let an agent focus evidence on the runtime subsystem being
changed, such as fiber runtime, retry scheduling, scope cleanup, or service
resolution.

The scenario registry already knows the available scenarios, owners,
expectations, invariants, and command arguments. The loop should use that
registry instead of staying hardcoded.

## Goals

- Add optional scenario arguments to both loop phases.
- Preserve the existing no-scenario dogfood behavior.
- Write stable per-scenario loop artifacts.
- Compare selected scenario artifacts in the after phase.
- Keep the package-test gate in the loop.
- Treat expected-failure scenarios as successful evidence when the expected
  failure is observed.
- Print scenario-aware next-query hints.

## Non-Goals

- Do not add watch mode or patch application.
- Do not emit full internal traces for passing example tests yet; this slice
  captures command-level causal evidence for each scenario.
- Do not replace the `causal-run` command.
- Do not add CI upload or artifact retention.

## Command Shape

Default dogfood loop:

```sh
zig build causal-dev-loop -- baseline
zig build causal-dev-loop -- after
```

Scenario loop:

```sh
zig build causal-dev-loop -- baseline <scenario>
zig build causal-dev-loop -- after <scenario>
```

Examples:

```sh
zig build causal-dev-loop -- baseline causal-scoped-fiber
zig build causal-dev-loop -- after causal-scoped-fiber

zig build causal-dev-loop -- baseline missing-service-compile-fail
zig build causal-dev-loop -- after missing-service-compile-fail
```

## Artifact Paths

Default dogfood loop keeps the existing paths:

- `.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-before.json`
- `.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-after.json`
- `.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-compare.txt`

Scenario loop uses slug-specific paths:

- `.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-<scenario>-before.json`
- `.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-<scenario>-after.json`
- `.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-<scenario>-compare.txt`

The selected scenario should also write its normal `causal-run` artifacts under
the existing scenario paths:

- `.zig-cache/causal-artifacts/zigeffect-causal-<scenario>.txt`
- `.zig-cache/causal-artifacts/zigeffect-causal-<scenario>.json`
- `.zig-cache/causal-artifacts/zigeffect-causal-<scenario>.dot`

## Scenario Status Policy

The loop should distinguish scenario status from package-test status:

- `pass`: expected-pass scenario exited zero.
- `expected_failure_observed`: expected-failure scenario exited nonzero.
- `failure`: expected-pass scenario failed, expected-failure scenario passed, or
  the command could not be spawned.

The loop exits nonzero when either the selected scenario status is `failure` or
the package-test status is `failure`.

## Data Flow

Baseline with a scenario:

1. Resolve the scenario from `causal_run.scenarioByName`.
2. Run the scenario command.
3. Build command-level causal artifacts from the result.
4. Write normal scenario artifacts.
5. Copy the scenario JSON into the loop's before path.
6. Run the package-test gate unless the selected scenario is `package-tests`.
7. Print a summary with scenario status, package status, and the after command.

After with a scenario:

1. Read the scenario before artifact.
2. Run the scenario command again.
3. Build and write scenario artifacts.
4. Copy the scenario JSON into the loop's after path.
5. Compare before and after JSON.
6. Write the compare report.
7. Run the package-test gate unless the selected scenario is `package-tests`.
8. Print scenario-aware query hints.

## Required Runner Support

`causal_run.zig` currently exposes `buildFailureArtifacts`. The loop needs a
general command artifact builder so passing scenarios can also leave JSON
evidence. Add `buildCommandArtifacts`, and keep `buildFailureArtifacts` as a
compatibility wrapper.

For a passing command, the artifact should record a successful `exit_recorded`
event with zero findings. For a failing command, it should preserve the current
assertion-failure finding behavior.

## Testing

Tests should cover:

- default loop paths still match the current dogfood paths;
- scenario loop paths include the scenario slug;
- summaries include target/scenario status and scenario-aware next commands;
- expected-failure scenarios map to `expected_failure_observed`;
- passing command artifacts can be produced with zero findings.

## Acceptance Criteria

- Existing `zig build causal-dev-loop -- baseline` and `-- after` still work.
- `zig build causal-dev-loop -- baseline causal-scoped-fiber` works.
- `zig build causal-dev-loop -- after causal-scoped-fiber` works and writes a
  scenario-specific compare report.
- `zig build causal-dev-loop -- baseline missing-service-compile-fail` treats
  the expected compile failure as successful evidence.
- `zig build examples`, `zig build test`, and `bun run zig:test` pass.

## Roadmap Position

This is the second Milestone 7 slice. It closes the gap called out after the
first dev-loop slice: scenario-specific before/after traces beyond the
deterministic dogfood artifact. The next gap is automatic query execution based
on changed findings.
