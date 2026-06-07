# Causal Scenarios

The causal scenario registry is the local map that tells agents what zigeffect
development checks exist, which subsystem owns each one, what invariant the
scenario protects, and where failure artifacts will be written.

## Commands

Print the scenario and invariant catalog:

```sh
zig build causal-catalog
```

Run a registered scenario:

```sh
zig build causal-run -- <scenario>
```

Run the current package-test development gate:

```sh
zig build test
```

Capture the expected missing-service compile-fail scenario:

```sh
zig build causal-capture-missing-service
```

Capture the expected package-test failure fixture:

```sh
zig build causal-package-failure-fixture
```

Compare two saved causal JSON artifacts:

```sh
zig build causal-compare -- <before.json> <after.json>
```

Run the two-phase causal development loop:

```sh
zig build causal-dev-loop -- baseline
zig build causal-dev-loop -- after
```

## Registered Scenarios

- `missing-service-compile-fail`
  Owner: `service_resolution`
  Purpose: prove missing service diagnostics become causal command evidence.
- `package-tests`
  Owner: `package`
  Purpose: run the broad zigeffect test suite with causal failure capture.
- `package-tests-failure-fixture`
  Owner: `package`
  Purpose: prove package-shaped test failures write causal command artifacts
  without breaking the real package gate.
- `causal-scoped-fiber`
  Owner: `fiber_runtime`
  Purpose: verify scoped fiber interruption causal examples stay healthy.
- `causal-retry-exhaustion`
  Owner: `schedule_retry`
  Purpose: verify retry exhaustion causal examples stay healthy.
- `causal-cleanup-failure`
  Owner: `scope_lifecycle`
  Purpose: verify cleanup failure causal examples stay healthy.
- `causal-missing-config`
  Owner: `service_resolution`
  Purpose: verify missing config causal examples stay healthy.

Each scenario has stable artifact paths under `.zig-cache/causal-artifacts/`.
Passing scenarios may write no runner failure artifact; failing scenarios write
text, JSON, and DOT artifacts before the command exits.

## Invariants

- `resource-finalized-after-acquire`
  Every `resource_acquired` event must have a matching `resource_finalized`
  event in the same scope.
- `scoped-fiber-must-finish-before-scope-close`
  Scoped fibers must complete, join, or interrupt before their owning scope
  closes.
- `finalizer-failures-are-causal-evidence`
  Finalizer failures must be preserved in the causal graph.
- `retry-exhaustion-is-recorded`
  Retry schedules must record exhaustion decisions.
- `service-requirement-has-provider`
  Required services must have matching providers or explicit missing-service
  diagnostics.
- `command-failure-is-causal-evidence`
  Development command failures must emit assertion findings with scenario
  context.
- `package-tests-are-development-gate`
  The package test suite remains the broad local regression gate.

## Adding A Scenario From A Bug

When a zigeffect bug reveals a new runtime rule:

1. Add or identify the smallest command that reproduces the behavior.
2. Add a scenario entry in `tools/causal_run.zig` with owner, purpose, expected
   finding policy, invariant ids, and argv.
3. Add an invariant entry if the bug teaches a new rule.
4. Run `zig build causal-catalog` and confirm the scenario appears.
5. Run `zig build causal-run -- <scenario>` before and after the fix.
6. Query any failure artifact with `zig build causal-query -- --file <path>
   <query>`.
7. Compare before and after artifacts with `zig build causal-compare --
   <before.json> <after.json>`.

The scenario should describe the runtime invariant, not merely the symptom that
happened to fail first.

## Comparing Before And After

Use comparison after a fix when the claim is about runtime behavior, not just
source code shape. Capture a before artifact from the smallest relevant
scenario, apply the fix, capture the after artifact, then run:

```sh
zig build causal-compare -- <before.json> <after.json>
```

The report is intentionally text-first for agents. It shows event count deltas,
finding count deltas, added events, removed events, and changed events. A good
patch summary should cite the comparison and the event ids that explain the
behavior change.

## Development Loop

Use the development loop for ordinary runtime patches. Run the baseline phase
before editing, then run the after phase once the patch is in place:

```sh
zig build causal-dev-loop -- baseline
zig build causal-dev-loop -- after
```

For targeted runtime work, pass a registered scenario slug:

```sh
zig build causal-dev-loop -- baseline causal-scoped-fiber
zig build causal-dev-loop -- after causal-scoped-fiber
```

The no-scenario loop compares the deterministic dogfood causal artifact and
runs the `package-tests` scenario as the package gate. It writes:

- `.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-before.json`
- `.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-after.json`
- `.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-compare.txt`
- `.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-queries.txt`

Scenario loops compare command-level artifacts for the selected scenario and
write slug-specific loop artifacts:

- `.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-<scenario>-before.json`
- `.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-<scenario>-after.json`
- `.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-<scenario>-compare.txt`
- `.zig-cache/causal-artifacts/zigeffect-causal-dev-loop-<scenario>-queries.txt`

The `*-queries.txt` artifact contains executed `causal-query` output selected
from the after artifact's evidence events.

Expected-failure scenarios are valid loop targets. For example,
`missing-service-compile-fail` reports `expected_failure_observed` when the
compile failure occurs as intended.

If package tests fail, the loop writes the same `package-tests` failure
artifacts as the default `zig build test` causal wrapper and exits nonzero.
Use `zig build test-raw` only when debugging the unwrapped package-test binary;
`zig build causal-dev-test` remains an explicit alias for the causal wrapper.

Use `zig build causal-package-failure-fixture` when an agent needs to prove the
package failure capture lane itself. It writes:

- `.zig-cache/causal-artifacts/zigeffect-causal-package-tests-failure-fixture.txt`
- `.zig-cache/causal-artifacts/zigeffect-causal-package-tests-failure-fixture.json`
- `.zig-cache/causal-artifacts/zigeffect-causal-package-tests-failure-fixture.dot`
