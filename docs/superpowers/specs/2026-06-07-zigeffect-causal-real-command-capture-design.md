# zigeffect Causal Real Command Capture Design

## Summary

Add the first real command failure-capture harness for `zigeffect` development.
The harness should run selected local development commands, emit
scenario-specific causal artifacts when a command fails, and let agents inspect
those artifacts with the existing `causal-query` tool.

This milestone moves beyond the deterministic dogfood fixture. It starts using
`zigeffect`'s causal runtime to reason about actual zigeffect development
commands.

## Problem

`zig build causal-test` and `zig build causal-check` prove causal artifact
generation, but they only run a deterministic fixture. A development agent still
does not have a command that says:

- "I ran this real zigeffect scenario."
- "The scenario command failed."
- "Here are scenario-specific causal artifacts for that failure."
- "Here are the event ids to inspect next."

Milestone 4 needs that bridge before broader scenario registries, invariant
catalogs, and before/after trace comparisons can be useful.

## Goals

- Add a Zig-native harness for selected real zigeffect development commands.
- Keep artifact paths scenario-specific so fixture artifacts and real command
  artifacts cannot be confused.
- Prove the harness with an existing compile-fail fixture that is expected to
  fail.
- Add a package-test scenario that runs `zig build test` and emits artifacts if
  it fails during development.
- Keep the normal `zig build test`, `zig build examples`, and `bun run zig:test`
  flows green.
- Make scenario metadata and artifact path decisions testable without spawning
  a process.

## Non-Goals

- Do not implement the full scenario registry yet.
- Do not compare before/after artifacts yet.
- Do not upload CI artifacts.
- Do not parse every Zig diagnostic into structured sub-events.
- Do not change the dogfood artifact paths.

## Design

Create a new focused tool:

```txt
packages/zigeffect/tools/causal_run.zig
```

The dogfood fixture remains in `causal_test.zig`. The new tool owns command
execution and scenario-specific capture. Keeping those separate avoids mixing
deterministic fixture generation with process orchestration.

## Scenarios

### `missing-service-compile-fail`

Runs the existing compile-fail fixture:

```sh
zig build-exe \
  --dep zigeffect \
  -Mroot=test/compile_fail/missing_service.zig \
  -Mzigeffect=src/zigeffect.zig \
  -fno-emit-bin \
  --cache-dir .zig-cache/causal-run-compile-fail-cache \
  --global-cache-dir .zig-cache/causal-run-global-cache
```

This command is expected to fail. The harness exits zero when the fixture fails
and artifacts are written. If the fixture unexpectedly passes, the harness exits
nonzero because the scenario contract was violated.

Artifacts:

- `.zig-cache/causal-artifacts/zigeffect-causal-missing-service-compile-fail.txt`
- `.zig-cache/causal-artifacts/zigeffect-causal-missing-service-compile-fail.json`
- `.zig-cache/causal-artifacts/zigeffect-causal-missing-service-compile-fail.dot`

### `package-tests`

Runs:

```sh
zig build test
```

This command is expected to pass. The harness is quiet when it passes. If it
fails, it writes artifacts and exits nonzero.

Artifacts:

- `.zig-cache/causal-artifacts/zigeffect-causal-package-tests.txt`
- `.zig-cache/causal-artifacts/zigeffect-causal-package-tests.json`
- `.zig-cache/causal-artifacts/zigeffect-causal-package-tests.dot`

## Causal Event Shape

On command failure, the harness records:

1. `run_started` for the scenario.
2. `effect_started` for the command invocation.
3. `assertion_recorded` with `status = "failure"` and a redacted command exit
   summary.
4. `exit_recorded` with `status = "failure"`.

The existing finding system should learn that `assertion_recorded` with
`status = "failure"` is a finding. That gives the report a finding event id
without changing dogfood fixture finding counts.

## Build Steps

Add:

```sh
zig build causal-run -- <scenario>
zig build causal-capture-missing-service
zig build causal-dev-test
```

`causal-run` forwards args to the new executable.

`causal-capture-missing-service` runs the expected-failure compile fixture and
should exit zero after writing artifacts.

`causal-dev-test` runs `zig build test`. It should exit zero and write no
failure artifact while the package tests pass. If tests fail in future
development, it should write `package-tests` artifacts and exit nonzero.

`causal-dev-test` should not be added to `examples`; it may recursively invoke
`zig build test` and should remain an explicit agent/developer command.

## Error Handling

- Unknown scenario names print usage and exit `2`.
- Spawn failures record a causal artifact and exit nonzero.
- Command failures for `expected_pass` scenarios write artifacts and exit
  nonzero.
- Command failures for `expected_failure` scenarios write artifacts and exit
  zero.
- Unexpected success for `expected_failure` scenarios records a failure artifact
  and exits nonzero.
- Captured stdout/stderr are truncated before being placed in `redacted_detail`.

## Acceptance Criteria

- `zig build causal-capture-missing-service` exits zero.
- The missing-service capture command writes `.txt`, `.json`, and `.dot`
  artifacts with the `missing-service-compile-fail` slug.
- The missing-service report includes `program: zigeffect command: missing-service-compile-fail`.
- The missing-service report includes `findings: 1`.
- `zig build causal-query -- --file .zig-cache/causal-artifacts/zigeffect-causal-missing-service-compile-fail.json cause 3` can inspect the scenario artifact.
- `zig build causal-dev-test` exits zero while package tests are green.
- `zig build test`, `zig build examples`, and `bun run zig:test` pass.

## Roadmap Position

This implements the first concrete slice of Milestone 4. It does not yet
implement a complete scenario registry, but it establishes the command runner,
scenario-specific artifact naming, real command failure artifacts, and the first
package-test development hook.
