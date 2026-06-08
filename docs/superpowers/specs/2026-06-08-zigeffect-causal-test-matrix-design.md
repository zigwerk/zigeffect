# zigeffect Causal Test Matrix Design

## Purpose

M2 makes causal evidence part of normal `zigeffect` regression work instead of
leaving it as a side harness that agents consult only after something fails.
The existing runtime already records causal events, formats reports, runs
registered scenarios, and writes remediation artifacts. What is still missing
is a tested coverage layer that answers:

- which runtime subsystems are protected by causal scenarios;
- which important subsystems are uncovered or only partially covered;
- whether tests assert causal structure directly rather than brittle text;
- when an ordinary failing test should become a scenario or invariant.

This milestone should make the system more self-improving without adding broad
source mutation or durable state. It gives agents a deterministic map of causal
coverage and gives core package tests reusable assertions for event patterns,
findings, and quiet passing traces.

## Current Context

The causal harness already has useful foundations:

- `packages/zigeffect/tools/causal_run.zig` owns the scenario registry,
  invariant catalog, artifact paths, and `zig build causal-run`.
- `zig build causal-catalog` prints scenarios and invariant metadata.
- Existing scenarios cover package tests, service resolution, scope lifecycle,
  fibers, schedules, cleanup failures, and missing config examples.
- `packages/zigeffect/src/services/causal.zig` owns `CausalStore`, event kinds,
  finding extraction, redaction, sampling, and bounded retention.
- Package tests already assert causal behavior in `runtime_test.zig`,
  `fiber_test.zig`, `layer_test.zig`, and `schedule_test.zig`, but each file has
  its own local helper.
- `packages/zigeffect/docs/causal-scenarios.md` documents how to add scenarios,
  but it does not yet define a coverage matrix or a bug graduation standard.

The current registry is scenario-first. M2 adds a coverage view over that
registry and makes test assertions reusable.

## Goals

- Add a deterministic causal coverage matrix for these domains:
  - service;
  - layer;
  - scope;
  - fiber;
  - schedule;
  - config;
  - resource;
  - retry;
  - cause;
  - observability.
- Add a local command, preferably `zig build causal-test-matrix`, that prints
  an agent-readable matrix and returns nonzero only for internal registry
  inconsistency.
- Extend the scenario registry model enough to express coverage domains without
  losing the existing owner/invariant shape.
- Add reusable test helpers for causal event patterns and findings.
- Convert a focused set of existing causal assertions to the shared helper.
- Add or expand small deterministic scenarios where the matrix reveals obvious
  gaps.
- Document when a failing test should become:
  - an ordinary unit regression;
  - a causal assertion inside an existing test;
  - a new causal scenario;
  - a new invariant.

## Non-Goals

- No durable backend.
- No browser or visual workbench.
- No AI policy decisions.
- No automatic source edits.
- No attempt to register every package test as a causal scenario.
- No expensive scenario suite by default.
- No success artifacts for every passing scenario unless a later milestone needs
  it.
- No broad refactor of `causal_run.zig` unless the matrix additions make a
  small split clearly simpler.

## Approach Options

### Option A: Matrix View Over The Existing Registry

Add coverage-domain metadata to the existing registry and derive a matrix from
`scenarioRegistry()` and `invariantCatalog()`.

Benefits:

- smallest change;
- preserves existing command and artifact conventions;
- makes coverage visible immediately;
- avoids a separate source of truth.

Tradeoff:

- `causal_run.zig` grows a bit more before it is split.

### Option B: Separate External Matrix File

Create a standalone JSON or Zig data file that maps domains to scenarios.

Benefits:

- cleaner separation from command running;
- future schema export could become easier.

Tradeoff:

- risks drift between registry and matrix;
- more validation is required before it can be trusted.

### Option C: Runtime-Instrumented Coverage From Test Execution

Compute matrix coverage by running scenarios and inspecting produced events.

Benefits:

- strongest proof that a scenario still emits the claimed event shapes.

Tradeoff:

- slower;
- can become flaky if tied too tightly to exact event ordering;
- too large for the first M2 slice.

## Selected Design

Use Option A for this branch. The matrix is a deterministic view over the
existing scenario registry, backed by new tests that prevent drift. Where event
shape proof is needed, use reusable test assertions inside fast package tests
and scenario example tests.

This keeps M2 useful immediately while leaving room for M6 replay/snapshot work
to add deeper trace-derived coverage later.

## Coverage Model

Add a small coverage-domain enum:

```zig
pub const CausalCoverageDomain = enum {
    service,
    layer,
    scope,
    fiber,
    schedule,
    config,
    resource,
    retry,
    cause,
    observability,
};
```

Extend `Scenario` with:

```zig
coverage_domains: []const CausalCoverageDomain,
```

Each scenario must declare at least one coverage domain. The matrix command
derives per-domain status:

- `covered`: at least one scenario covers the domain and at least one invariant
  or test assertion is linked to it.
- `partial`: at least one scenario covers the domain but coverage is indirect,
  broad, or missing a specific invariant.
- `missing`: no scenario declares the domain.

The first matrix can treat `config`, `cause`, and `observability` as partial if
they are exercised through service/layer/runtime tests but lack a dedicated
scenario. That is more honest than pretending they are fully covered.

## Initial Matrix Expectations

The first branch should target this baseline:

| Domain | Expected M2 Status | Initial Evidence |
| --- | --- | --- |
| service | covered | `missing-service-compile-fail`, `causal-missing-config` |
| layer | covered | `causal-missing-config`, layer graph causal tests |
| scope | covered | `causal-cleanup-failure`, scoped runtime tests |
| fiber | covered | `causal-scoped-fiber`, fiber runtime causal tests |
| schedule | covered | `causal-retry-exhaustion`, schedule decision tests |
| config | partial | `causal-missing-config`, config diagnostics tests |
| resource | covered | `causal-cleanup-failure`, runtime resource tests |
| retry | covered | `causal-retry-exhaustion`, retry decision tests |
| cause | partial | cleanup failure and runtime cause tests |
| observability | partial | observability services tests, no dedicated scenario |

This matrix is allowed to expose partials. The value is that partials become
visible work items for later causal scenario branches.

## Command Shape

Add:

```sh
zig build causal-test-matrix
```

The command prints text similar to:

```text
zigeffect causal test matrix
schema: zigeffect.causal.test-matrix.v1
coverage domains: 10
scenarios: 7
invariants: 7

- domain service
  status: covered
  scenarios: missing-service-compile-fail causal-missing-config
  invariants: service-requirement-has-provider
  notes: service requirements have compile-fail and runtime graph evidence
```

JSON output is not required for the first slice unless implementation pressure
is low after the text path lands. If JSON is added, it should use:

```text
zigeffect.causal.test-matrix.v1
```

The command fails only when the registry is internally inconsistent:

- a scenario has no coverage domains;
- a scenario references an unknown invariant;
- an invariant references an unsupported subsystem;
- a matrix domain has invalid status data;
- duplicate scenario slugs or invariant ids are detected.

Partial or missing coverage should be reported but should not fail the command
in M2. Later hardening can add an optional `--fail-on-missing`.

## Test Assertion Helper

Create a package test helper under:

```text
packages/zigeffect/test/support/causal_assertions.zig
```

The helper should focus on structural assertions, not report formatting. Initial
API:

```zig
pub const EventPattern = struct {
    kind: fx.CausalEventKind,
    label: ?[]const u8 = null,
    type_name: ?[]const u8 = null,
    status: ?[]const u8 = null,
};

pub fn expectEvent(snapshot: fx.CausalSnapshot, pattern: EventPattern) !fx.CausalEvent;
pub fn expectEventSequence(snapshot: fx.CausalSnapshot, expected: []const fx.CausalEventKind) !void;
pub fn expectFinding(store: *const fx.CausalStore, kind: fx.CausalFindingKind) !fx.CausalFinding;
pub fn expectNoFindings(store: *const fx.CausalStore) !void;
```

Rules:

- optional fields match only when present;
- returned events/findings let tests continue with id, run, scope, fiber, trace,
  and span assertions;
- helpers should emit specific error names such as
  `ExpectedCausalEventMissing`, `ExpectedCausalFindingMissing`, and
  `UnexpectedCausalFinding`;
- helpers must not format or parse CI reports.

The first conversion target should be a small set of existing helper users:

- `runtime_test.zig` event sequence checks;
- `fiber_test.zig` event sequence checks;
- `layer_test.zig` event lookup checks;
- `schedule_test.zig` schedule decision lookup if the helper can support it
  cleanly without over-generalizing.

## Scenario Expansion

Add only the smallest new scenario if the matrix needs it to avoid misleading
coverage. The most useful candidate is an observability-focused causal scenario
because observability is one of the requested M2 domains and currently has
tests but no registered scenario.

Proposed scenario:

```text
causal-observability-context
```

Purpose:

- prove logs, metrics, spans, and trace context can be observed without
  producing causal findings in a healthy run;
- keep observability coverage visible in the scenario registry.

Expected behavior:

- command passes;
- scenario is quiet on success;
- test asserts log/metric/span causal events or observability service output,
  depending on the current runtime boundary;
- no causal findings for a healthy observability scenario.

If the current runtime does not naturally record log/metric/span causal events
without a larger instrumentation change, the branch should document
observability as partial and defer the dedicated scenario rather than fake it.

## Package Test Integration

The package test gate already runs through:

```sh
zig build test
```

which delegates to the causal package scenario and writes artifacts only on
failure. M2 should keep that behavior but improve the quality of causal
assertions inside tests:

- use `expectNoFindings` for healthy causal stores where the absence of advice
  matters;
- use `expectFinding` for intentionally unhealthy local stores;
- assert event ids, parent ids, run ids, scope ids, fiber ids, and trace ids
  through returned events instead of indexing raw arrays everywhere;
- keep exact ordering checks only when ordering is part of the contract.

Selected assertion failures should be easy to diagnose from event ids because
the helper returns the matched event before downstream assertions.

## Documentation

Update `packages/zigeffect/docs/causal-scenarios.md` with:

- the matrix command;
- the coverage status vocabulary;
- the initial domain table;
- a "failure graduation" guide.

Failure graduation guide:

- Keep it as an ordinary unit test when the failure is local, deterministic, and
  does not teach a runtime causality rule.
- Add a causal assertion to an existing test when the runtime behavior already
  has a causal store and the invariant is local to that test.
- Add a scenario when the failure teaches a reusable runtime rule, crosses a
  service/layer/scope/fiber/schedule boundary, or should produce artifacts for
  agents in CI.
- Add a new invariant when the rule should be named, queried, and reused across
  multiple scenarios or findings.

Update the master roadmap to mark M2 design/plan as active and to state that M2
will produce a coverage matrix before deeper scenario expansion.

## Testing Strategy

Use test-driven development for implementation:

1. Write failing tests for matrix validation and text output.
2. Implement coverage-domain metadata and matrix formatting.
3. Write failing tests for causal assertion helpers.
4. Implement helpers and convert selected local helpers.
5. Write failing tests for any new scenario registration.
6. Add scenario example only if it can stay deterministic and honest.
7. Update docs and manifest/build wiring.

Required verification before merge:

```sh
git diff --check HEAD
zig build causal-test-matrix
zig build causal-catalog
zig build examples
zig build test --summary none
bun run check
bun run zig:test
```

## Acceptance Criteria

- `zig build causal-test-matrix` prints all requested domains and current
  coverage status.
- Registry tests prove every scenario has coverage domains and all invariant ids
  resolve.
- Shared causal assertion helpers are used by at least two core package test
  files.
- Healthy causal tests can assert no findings without inspecting formatted
  reports.
- Any new scenario is deterministic, fast, quiet on success, and registered in
  the matrix.
- Docs explain when failures become scenarios or invariants.
- The branch does not claim complete observability/cause/config coverage unless
  there is direct causal evidence for that claim.

## Future Direction

M2 should set up three follow-on branches if needed:

- `codex/zigeffect-causal-runtime-regression-scenarios`: add deeper scenarios
  for cause/config/observability once instrumentation boundaries are clear.
- `codex/zigeffect-causal-test-assertion-helpers`: broaden helper adoption if
  the first branch keeps conversion intentionally narrow.
- `codex/zigeffect-causal-matrix-json`: emit stable JSON matrix artifacts for
  later durable backend and workbench milestones.
