# zigeffect Architecture Breakout Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restructure `packages/zigeffect` into a facade plus domain modules and split tests by subsystem without changing public behavior.

**Architecture:** `src/zigeffect.zig` becomes a public facade that re-exports domain namespaces and existing top-level aliases. Implementation moves into `core`, `dependency`, `effect`, `runtime`, `layer`, `services`, and `testing` modules with one-way imports. Tests move behind `test/all_test.zig` with a new architecture contract test and shared support fixtures.

**Tech Stack:** Zig 0.16, Bun workspace scripts, `bun run zigeffect:test`, `bun run zig:test`, `bun run typecheck`.

---

## File Structure

- Modify `packages/zigeffect/build.zig`: point tests at `test/all_test.zig`.
- Replace `packages/zigeffect/src/zigeffect.zig`: root facade only.
- Create `packages/zigeffect/src/core/result.zig`: `Cause`, `Exit`, `FinalizerExit`, `formatCause`, `formatExit`.
- Create `packages/zigeffect/src/core/scope.zig`: `Scope`, `ScopeError`, finalizer registration APIs.
- Create `packages/zigeffect/src/core/context.zig`: `Context` and `serviceNotFound`.
- Create `packages/zigeffect/src/dependency/services.zig`: service set builders, `ServiceSet`, `DependencyError`.
- Create `packages/zigeffect/src/dependency/report.zig`: dependency issue/report types and formatting.
- Create `packages/zigeffect/src/dependency/validation.zig`: requirement extraction and validation helpers.
- Create `packages/zigeffect/src/effect/effect.zig`: `Effect`, combinator wrapper types, retry/repeat.
- Create `packages/zigeffect/src/effect/resource.zig`: `acquireRelease`.
- Create `packages/zigeffect/src/effect/schedule.zig`: `Schedule`.
- Create `packages/zigeffect/src/runtime/coordination.zig`: `Deferred`, `Queue`, `Semaphore`, `FiberPrimitiveError`.
- Create `packages/zigeffect/src/runtime/fiber.zig`: `FiberId`, `FiberStatus`, `Fiber`, `FiberRuntime`.
- Create `packages/zigeffect/src/runtime/runtime.zig`: `Runtime`.
- Create `packages/zigeffect/src/layer/layer.zig`: `Layer`, `LayerWithError`, declaration wrappers, merge.
- Create `packages/zigeffect/src/layer/graph.zig`: graph metadata, generated graph environment, graph runtime.
- Create `packages/zigeffect/src/services/clock.zig`: `Clock`, `FakeClock`.
- Create `packages/zigeffect/src/services/logger.zig`: `Logger`.
- Create `packages/zigeffect/src/services/config.zig`: `Config`, `ConfigError`.
- Create `packages/zigeffect/src/services/metrics.zig`: `Metrics`.
- Create `packages/zigeffect/src/services/tracing.zig`: `Tracing`.
- Create `packages/zigeffect/src/services/memory_file_system.zig`: `MemoryFileSystem`.
- Create `packages/zigeffect/src/testing/test_env.zig`: `TestServices`, `TestEnv`.
- Create `packages/zigeffect/test/all_test.zig`: aggregate all test modules.
- Create `packages/zigeffect/test/architecture_test.zig`: facade and namespace contract tests.
- Later split `packages/zigeffect/test/core_test.zig` into domain test files and `test/support/fixtures.zig`.
- Create `packages/zigeffect/docs/architecture.md`: folder ownership, import direction, and roadmap landing zones.
- Modify `packages/zigeffect/README.md`: link to architecture guide.
- Modify `packages/zigeffect/docs/roadmap.md`: mark architecture breakout as current first milestone.

## Tasks

### Task 1: Add Structural Contract Test

- [ ] **Step 1: Write the failing test**

Create `packages/zigeffect/test/architecture_test.zig`:

```zig
const std = @import("std");
const fx = @import("zigeffect");

test "root facade exposes domain namespaces and compatibility aliases" {
    const RootEffect = fx.Effect(u32, error{}, fx.TestServices);
    const DomainEffect = fx.effect.effect.Effect(u32, error{}, fx.TestServices);
    try std.testing.expect(RootEffect == DomainEffect);

    try std.testing.expect(fx.Context(fx.TestServices) == fx.core.context.Context(fx.TestServices));
    try std.testing.expect(fx.Scope == fx.core.scope.Scope);
    try std.testing.expect(fx.Runtime(fx.TestServices) == fx.runtime.runtime.Runtime(fx.TestServices));
    try std.testing.expect(fx.FiberRuntime(fx.TestServices) == fx.runtime.fiber.FiberRuntime(fx.TestServices));
    try std.testing.expect(fx.Layer(fx.TestServices) == fx.layer.layer.Layer(fx.TestServices));
    try std.testing.expect(fx.Schedule == fx.effect.schedule.Schedule);
    try std.testing.expect(fx.Logger == fx.services.logger.Logger);
    try std.testing.expect(fx.Config == fx.services.config.Config);
    try std.testing.expect(fx.Metrics == fx.services.metrics.Metrics);
    try std.testing.expect(fx.Tracing == fx.services.tracing.Tracing);
    try std.testing.expect(fx.MemoryFileSystem == fx.services.memory_file_system.MemoryFileSystem);
    try std.testing.expect(fx.Clock == fx.services.clock.Clock);
    try std.testing.expect(fx.TestEnv == fx.testing.test_env.TestEnv);
}
```

- [ ] **Step 2: Add the test aggregator**

Create `packages/zigeffect/test/all_test.zig`:

```zig
comptime {
    _ = @import("architecture_test.zig");
    _ = @import("core_test.zig");
}
```

- [ ] **Step 3: Point the build at the aggregator**

In `packages/zigeffect/build.zig`, change the test root source file to:

```zig
.root_source_file = b.path("test/all_test.zig"),
```

- [ ] **Step 4: Verify RED**

Run:

```bash
bun run zigeffect:test
```

Expected: FAIL because `fx.effect`, `fx.core`, `fx.runtime`, `fx.layer`,
`fx.services`, and `fx.testing` are not exported yet.

### Task 2: Split Source Behind A Facade

- [ ] **Step 1: Create domain folders**

Run:

```bash
mkdir -p packages/zigeffect/src/core packages/zigeffect/src/dependency packages/zigeffect/src/effect packages/zigeffect/src/runtime packages/zigeffect/src/layer packages/zigeffect/src/services packages/zigeffect/src/testing
```

- [ ] **Step 2: Move implementation into domain files**

Move the current implementation by subsystem:

```text
ServiceSet and DependencyError        -> src/dependency/services.zig
DependencyReport and formatting       -> src/dependency/report.zig
validateLayerRequirements helpers     -> src/dependency/validation.zig
Cause, Exit, formatExit/formatCause   -> src/core/result.zig
serviceNotFound and Context           -> src/core/context.zig
Scope and finalizer registration      -> src/core/scope.zig
Effect and combinator wrappers        -> src/effect/effect.zig
acquireRelease                        -> src/effect/resource.zig
Schedule                              -> src/effect/schedule.zig
Deferred, Queue, Semaphore            -> src/runtime/coordination.zig
Fiber and FiberRuntime                -> src/runtime/fiber.zig
Runtime                               -> src/runtime/runtime.zig
Layer and declaration wrappers        -> src/layer/layer.zig
LayerGraph and graph runtime          -> src/layer/graph.zig
Clock and FakeClock                   -> src/services/clock.zig
Logger                                -> src/services/logger.zig
Config                                -> src/services/config.zig
Metrics                               -> src/services/metrics.zig
Tracing                               -> src/services/tracing.zig
MemoryFileSystem                      -> src/services/memory_file_system.zig
TestServices and TestEnv              -> src/testing/test_env.zig
```

- [ ] **Step 3: Replace root file with facade**

`packages/zigeffect/src/zigeffect.zig` must define namespace exports and
top-level compatibility aliases. The facade body should be imports and aliases,
not implementation logic.

- [ ] **Step 4: Verify GREEN**

Run:

```bash
bun run zigeffect:test
```

Expected: PASS with the architecture test and existing behavior tests.

### Task 3: Split Test Tree By Domain

- [ ] **Step 1: Create shared fixtures**

Create `packages/zigeffect/test/support/fixtures.zig` for shared test helpers,
resource probes, layer envs, and fiber finalizer probes that multiple domain
test files use.

- [ ] **Step 2: Move tests by subsystem**

Move tests from `core_test.zig` into:

```text
effect_test.zig      effect constructors, combinators, recovery, retry/repeat
scope_test.zig       scope finalizers and acquireRelease resource cleanup
runtime_test.zig     Runtime.run/exit finalizer behavior
fiber_test.zig       FiberRuntime, Deferred, Queue, Semaphore
layer_test.zig       Layer, LayerGraph, startup errors, compile-fail fixture
schedule_test.zig    schedule policies
services_test.zig    TestEnv and service helpers
```

- [ ] **Step 3: Update aggregator**

`packages/zigeffect/test/all_test.zig` should import:

```zig
comptime {
    _ = @import("architecture_test.zig");
    _ = @import("effect_test.zig");
    _ = @import("scope_test.zig");
    _ = @import("runtime_test.zig");
    _ = @import("fiber_test.zig");
    _ = @import("layer_test.zig");
    _ = @import("schedule_test.zig");
    _ = @import("services_test.zig");
}
```

- [ ] **Step 4: Verify GREEN**

Run:

```bash
bun run zigeffect:test
```

Expected: PASS with the split test tree.

### Task 4: Document Folder Contracts

- [ ] **Step 1: Add architecture guide**

Create `packages/zigeffect/docs/architecture.md` with:

```markdown
# zigeffect Architecture

## Public Import

Users import `zigeffect` through `src/zigeffect.zig`. That file is a facade:
domain namespaces plus compatibility aliases.

## Source Domains

Describe `core`, `dependency`, `effect`, `runtime`, `layer`, `services`, and
`testing`, including what each owns and what future roadmap work belongs there.

## Import Direction

Document that implementation modules must not import `src/zigeffect.zig`.

## Tests

Explain `test/all_test.zig`, domain test files, and `test/support/fixtures.zig`.
```

- [ ] **Step 2: Link docs**

Update `packages/zigeffect/README.md` and
`packages/zigeffect/docs/roadmap.md` to reference the architecture guide and
state that feature milestones should land in the new domain folders.

- [ ] **Step 3: Verify docs and tests**

Run:

```bash
bun run zigeffect:test
```

Expected: PASS.

### Task 5: Full Verification

- [ ] **Step 1: Run package verification**

Run:

```bash
bun run zigeffect:test
```

Expected: PASS.

- [ ] **Step 2: Run Zig workspace verification**

Run:

```bash
bun run zig:test
```

Expected: PASS.

- [ ] **Step 3: Run repository typecheck**

Run:

```bash
bun run typecheck
```

Expected: PASS.

- [ ] **Step 4: Inspect final structure**

Run:

```bash
find packages/zigeffect/src packages/zigeffect/test -maxdepth 3 -type f | sort
```

Expected: shows facade, domain source files, `test/all_test.zig`, split domain
tests, support fixtures, and compile-fail fixtures.
