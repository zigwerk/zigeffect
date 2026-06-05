# zigeffect Architecture Breakout Design

Date: 2026-06-05

## Goal

Restructure `packages/zigeffect` before delivering deeper roadmap features so
the package is easy for humans, agents, and LLMs to reason about. The new layout
must make subsystem ownership clear, keep public API compatibility, reduce
cross-subsystem blast radius, and give future roadmap work a predictable place
to land.

This architecture breakout becomes the first roadmap delivery milestone. The
feature roadmap still follows afterward: API hardening, requirement algebra,
dependency-injected layer builders, runtime/fiber cohesion, resource expansion,
owned causes, schedule algebra, production services, the test toolkit, async
backend boundaries, and application patterns.

## Current Problem

`packages/zigeffect/src/zigeffect.zig` currently contains the whole engine in
one file: dependency metadata, `Exit`/`Cause`, `Context`, `Effect`
combinators, scoped resources, coordination primitives, fiber runtime, normal
runtime, layers, graph startup, schedules, test services, and helper services.

`packages/zigeffect/test/core_test.zig` similarly contains nearly all tests in
one file. Shared test environments, fixtures, layer builders, fiber probes,
resource probes, and schedule tests are intertwined.

That was useful for bootstrapping, but it is now a delivery risk. Future
roadmap work will touch multiple independent subsystems, and a single large
source/test pair makes it too easy for a small change to disturb unrelated
behavior.

## Chosen Approach

Use a public facade plus domain modules:

- `src/zigeffect.zig` remains the single import path for package users.
- Domain files own implementation details and expose small contracts.
- The root facade re-exports both domain namespaces and existing top-level API
  names, so current callers keep working.
- Tests move to a domain test tree with shared fixtures.
- Documentation records where each roadmap feature belongs.

This is intentionally a behavior-preserving architecture milestone. It should
not add dependency-injected builders or requirement algebra yet. Those features
come next, once the file tree can absorb them cleanly.

## Source Tree

Target layout:

```text
packages/zigeffect/src/
  zigeffect.zig
  core/
    result.zig
    scope.zig
    context.zig
  dependency/
    services.zig
    report.zig
    validation.zig
  effect/
    effect.zig
    resource.zig
    schedule.zig
  runtime/
    runtime.zig
    fiber.zig
    coordination.zig
  layer/
    layer.zig
    graph.zig
  services/
    clock.zig
    logger.zig
    config.zig
    metrics.zig
    tracing.zig
    memory_file_system.zig
  testing/
    test_env.zig
```

The first split may keep closely coupled layer wrappers and graph helpers in
the same file if extracting them separately would create artificial churn, but
the public tree should still establish the domain folders above. The rule is:
split by engine responsibility, not by type size alone.

## Public Facade Contract

`src/zigeffect.zig` should contain imports, namespace exports, and compatibility
aliases only. It should not contain implementation bodies after the breakout.

The facade exports domain namespaces:

```zig
pub const core = struct {
    pub const result = @import("core/result.zig");
    pub const scope = @import("core/scope.zig");
    pub const context = @import("core/context.zig");
};

pub const dependency = struct {
    pub const services = @import("dependency/services.zig");
    pub const report = @import("dependency/report.zig");
    pub const validation = @import("dependency/validation.zig");
};
```

It also preserves existing top-level names such as `Effect`, `Context`,
`Scope`, `Runtime`, `FiberRuntime`, `Layer`, `LayerWithError`, `layerGraph`,
`Schedule`, `Logger`, `Config`, `Metrics`, `Tracing`, `MemoryFileSystem`,
`Clock`, `TestEnv`, `Exit`, and `Cause`.

Future code can choose either:

```zig
const fx = @import("zigeffect");
const program = fx.Effect(u32, AppError, AppEnv).fromFn(run);
```

or, for maintainers and focused tests:

```zig
const fx = @import("zigeffect");
const Schedule = fx.effect.schedule.Schedule;
```

## Dependency Direction

Allowed import direction:

- `core/*` imports only `std` and lower-level core files.
- `dependency/*` imports `std` and `core` only.
- `effect/*` imports `core`, `dependency`, and `services/clock` only where
  needed.
- `runtime/*` imports `core`, `dependency`, `effect`, and `services/clock`.
- `layer/*` imports `core` and `dependency`; graph runtime can import
  `runtime` only if it uses a shared runner helper.
- `services/*` imports `std` and service-local dependencies.
- `testing/*` may import any public domain needed to assemble test services.
- The root facade imports every domain but no domain imports the root facade.

No implementation module should import `src/zigeffect.zig`. That prevents
cycles and keeps domain contracts explicit.

## Test Tree

Target layout:

```text
packages/zigeffect/test/
  all_test.zig
  support/
    fixtures.zig
  architecture_test.zig
  effect_test.zig
  scope_test.zig
  runtime_test.zig
  fiber_test.zig
  layer_test.zig
  schedule_test.zig
  services_test.zig
  compile_fail/
    missing_service.zig
```

`all_test.zig` imports each domain test file so `zig build test` still has one
test artifact. `support/fixtures.zig` owns shared test-only services, layer
environments, resource probes, and helper functions that multiple test files
need.

The existing tests should move without changing behavior. New
`architecture_test.zig` asserts the facade contract and domain namespace
availability so future refactors cannot accidentally collapse the layout.

## Build Contract

`packages/zigeffect/build.zig` should point its test module at
`test/all_test.zig` and keep the public module root at `src/zigeffect.zig`.

Repository commands stay the same:

```bash
bun run zigeffect:test
bun run zig:test
```

## Documentation Contract

Add a package architecture guide at:

```text
packages/zigeffect/docs/architecture.md
```

The guide should explain:

- which folder owns each subsystem
- import direction rules
- where future roadmap milestones should land
- how to add tests without growing a monolithic test file
- how to preserve the public facade when moving implementation details

Update `packages/zigeffect/README.md` and
`packages/zigeffect/docs/roadmap.md` to point to the architecture guide.

## Testing Strategy

This is a refactor milestone, so the test strategy is characterization plus one
new structural contract:

- Add `architecture_test.zig` first and watch it fail because domain namespaces
  do not exist yet.
- Move implementation into domain files while keeping public top-level aliases.
- Move tests into domain test files and shared fixtures.
- Run the full existing suite after every major move.
- Keep compile-fail diagnostics running through the same build step.

The existing behavioral suite is the safety net for behavior preservation. The
new architecture test is the failing test that drives the new file-tree
contract.

## Non-Goals

- No dependency-injected layer builders in this milestone.
- No requirement algebra changes beyond preserving existing metadata behavior.
- No production logger/config/metrics/tracing rewrite.
- No async runtime boundary.
- No broad API rename for existing users.
- No generated code.

## Completion Evidence

This milestone is complete when current-state evidence proves:

- `src/zigeffect.zig` is a facade, not a monolithic implementation file.
- Domain source files exist under the target folders.
- Existing public top-level imports still compile.
- Domain namespace imports compile.
- Tests are split by domain and run through `test/all_test.zig`.
- `packages/zigeffect/docs/architecture.md` documents the layout and contracts.
- `bun run zigeffect:test` passes.
- `bun run zig:test` passes.
- `bun run typecheck` passes.

The broader roadmap goal remains active after this architecture milestone.
