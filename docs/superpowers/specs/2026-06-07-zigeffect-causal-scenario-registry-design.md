# zigeffect Causal Scenario Registry Design

## Summary

Add a first scenario registry and invariant catalog for the `zigeffect` causal
development harness. The registry should make `causal_run.zig` more than a pair
of hard-coded commands: each scenario should have an owner, purpose, expected
finding policy, invariant ids, and stable artifact paths.

This milestone turns the causal harness into something agents can reason about
before execution. Agents should be able to ask "what scenarios exist, which
subsystems do they cover, what invariant is being checked, and where will
artifacts appear if it fails?"

## Problem

`zig build causal-run -- <scenario>` can execute real commands and capture
failure artifacts, but the scenario knowledge is still embedded in ad hoc
branches. That limits the self-improving loop:

- agents cannot list registered scenarios;
- scenarios do not declare owners or purposes;
- findings are not mapped to named runtime invariants;
- adding a new bug-derived regression scenario has no documented shape.

## Goals

- Add a first-class scenario registry inside `causal_run.zig`.
- Add an invariant catalog that maps causal findings to runtime rules and query
  hints.
- Add a catalog command so agents can inspect the registry locally.
- Register existing causal examples as quiet-on-success development scenarios.
- Preserve the existing command behavior for `missing-service-compile-fail` and
  `package-tests`.
- Document how future bugs become scenarios and invariants.

## Non-Goals

- Do not add before/after trace comparison.
- Do not persist the registry as JSON yet.
- Do not make every scenario write artifacts on success.
- Do not split `causal_run.zig` until registry growth creates a real pressure to
  do so.
- Do not add CI upload behavior.

## Registry Model

Extend `Scenario` with:

```zig
owner: RuntimeSubsystem,
purpose: []const u8,
finding_policy: ExpectedFindingsPolicy,
invariant_ids: []const []const u8,
```

Add:

```zig
pub const RuntimeSubsystem = enum {
    command_harness,
    service_resolution,
    scope_lifecycle,
    fiber_runtime,
    schedule_retry,
    package,
};

pub const ExpectedFindingsPolicy = enum {
    none_when_command_passes,
    failure_artifact_on_command_failure,
    expected_failure_command_emits_assertion,
};
```

## Invariant Model

Add:

```zig
pub const Invariant = struct {
    id: []const u8,
    subsystem: RuntimeSubsystem,
    finding_kind: ?fx.CausalFindingKind,
    rule: []const u8,
    detection_query: []const u8,
};
```

The first invariant catalog should cover current finding kinds:

- `resource-finalized-after-acquire`
- `scoped-fiber-must-finish-before-scope-close`
- `finalizer-failures-are-causal-evidence`
- `retry-exhaustion-is-recorded`
- `service-requirement-has-provider`
- `command-failure-is-causal-evidence`

## Registered Scenarios

The first registry should include:

- `missing-service-compile-fail`
- `package-tests`
- `causal-scoped-fiber`
- `causal-retry-exhaustion`
- `causal-cleanup-failure`
- `causal-missing-config`

The four causal example scenarios run existing `examples/causal_*.zig` tests.
They are expected to pass and write no runner failure artifact while healthy.
If a future change breaks one, the runner emits scenario-specific artifacts.

## Command Surface

Keep:

```sh
zig build causal-run -- <scenario>
zig build causal-capture-missing-service
zig build causal-dev-test
```

Add:

```sh
zig build causal-run -- catalog
zig build causal-catalog
```

The catalog output should include:

- scenario slug;
- owner;
- purpose;
- expectation;
- finding policy;
- artifact paths;
- invariant ids;
- invariant rules and query hints.

## Testing

Tests should prove:

- the registry includes the current scenarios;
- each scenario has owner, purpose, policy, invariant ids, and stable artifact
  path;
- the invariant catalog maps findings to runtime rules;
- catalog output is agent-readable and includes scenarios, invariants, and
  artifact paths;
- existing command capture behavior still works.

## Acceptance Criteria

- `zig build causal-catalog` exits zero and prints the scenario registry and
  invariant catalog.
- `zig build causal-run -- catalog` exits zero.
- `zig build causal-run -- causal-scoped-fiber` exits zero while the example
  passes.
- `zig build causal-capture-missing-service` still exits zero and writes
  missing-service artifacts.
- `zig build causal-dev-test` still exits zero while package tests pass.
- `zig build test`, `zig build examples`, and `bun run zig:test` pass.

## Roadmap Position

This implements the first concrete slice of Milestone 5. It gives the
self-improving development harness a named scenario and invariant layer. The
next milestone should use this registry for before/after trace comparison and
for adding bug-derived regression scenarios without duplicating harness logic.
