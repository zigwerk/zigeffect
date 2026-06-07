# zigeffect Causal Default Test Harness Design

Date: 2026-06-07

## Problem

`zig build causal-dev-test` already runs the broad package tests through the
causal command harness. If package tests fail, it writes
`zigeffect-causal-package-tests.{txt,json,dot}` with a causal CI report, JSON
events, and graph output.

The ordinary `zig build test` step still runs the raw unit-test binary directly.
That means the most natural development command can fail without writing causal
evidence. For zigeffect to use its own causal runtime while building zigeffect,
the default local test gate should preserve causal failure artifacts.

## Goals

- Make `zig build test` run package tests through the causal command harness.
- Keep an explicit raw package-test step for the harness to call without
  recursion.
- Preserve `zig build causal-dev-test` as a named alias for the same causal
  package-test gate.
- On package-test failure, continue writing
  `.zig-cache/causal-artifacts/zigeffect-causal-package-tests.{txt,json,dot}`.
- Keep the passing path quiet: no package-test artifacts are required when tests
  pass.
- Document the new command split for agents and developers.

## Non-Goals

- Do not intentionally break tests to verify the failure path end-to-end.
- Do not change test runtime behavior inside `test/all_test.zig`.
- Do not add persistent CI upload or artifact retention policies.
- Do not remove `causal-dev-test`; it remains useful as an explicit name.

## Design

Add a raw package-test build step:

```zig
const raw_test_step = b.step("test-raw", "Run zigeffect tests without causal wrapping");
raw_test_step.dependOn(&run_unit_tests.step);
```

Change the package-test scenario command from:

```zig
zig build test
```

to:

```zig
zig build test-raw
```

Then make the default `test` build step depend on the existing
`causal_run package-tests` run artifact:

```zig
const run_causal_package_test_tool = b.addRunArtifact(causal_run_tool);
run_causal_package_test_tool.addArg("package-tests");

const test_step = b.step("test", "Run zigeffect tests with causal failure capture");
test_step.dependOn(&run_causal_package_test_tool.step);

const causal_dev_test_step = b.step("causal-dev-test", "Run zigeffect tests with causal failure capture");
causal_dev_test_step.dependOn(&run_causal_package_test_tool.step);
```

The important safety property is no recursion:

- `zig build test` runs the causal harness.
- The causal harness invokes `zig build test-raw`.
- `test-raw` runs the unit-test binary directly.

## Artifact Behavior

When `test-raw` passes, `zig build test` exits zero and does not need to write
package-test artifacts.

When `test-raw` fails, the existing `causal_run` failure path records:

- `run_started`
- `effect_started`
- `assertion_recorded`
- `exit_recorded`

It then formats:

- `.zig-cache/causal-artifacts/zigeffect-causal-package-tests.txt`
- `.zig-cache/causal-artifacts/zigeffect-causal-package-tests.json`
- `.zig-cache/causal-artifacts/zigeffect-causal-package-tests.dot`

The text artifact is already produced with `formatCausalCiReport`, so it
includes finding counts, event ids, citation lines, and next query suggestions.

## Acceptance Criteria

- `package-tests` scenario argv uses `test-raw`, not `test`.
- `zig build test-raw` runs the unit-test suite directly.
- `zig build test` runs the causal package-test harness and exits zero while
  tests pass.
- `zig build causal-dev-test` remains an alias for the causal package-test
  harness and exits zero while tests pass.
- Existing causal dev-loop package-test gate still passes.
- Docs explain that `zig build test` is causal-wrapped and `test-raw` is the
  underlying raw test step.

## Future Directions

- Add a controlled failing fixture build step that intentionally exercises the
  package-test failure path without breaking the main suite.
- Add optional query-report generation for command-failure artifacts.
- Add CI upload/retention guidance for `.zig-cache/causal-artifacts`.
