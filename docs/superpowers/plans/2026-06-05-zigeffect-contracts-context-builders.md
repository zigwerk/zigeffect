# zigeffect Contracts And Context Builders Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver roadmap sections 1-3: API hardening, requirement/provider helpers, graph reports, and dependency-injected layer builders.

**Architecture:** Service tuple validation lives in `src/dependency/services.zig`, requirement comparison in `src/dependency/validation.zig`, graph reporting/startup contexts in `src/layer/graph.zig`, and context-builder layer wrappers in `src/layer/layer.zig`. The root facade only re-exports the new contracts.

**Tech Stack:** Zig 0.16, Bun workspace scripts, `bun run zigeffect:test`, `bun run zig:test`, `bun run typecheck`.

---

## File Structure

- Modify `packages/zigeffect/src/dependency/services.zig`: add service tuple assertions and call them from service-set builders.
- Modify `packages/zigeffect/src/dependency/validation.zig`: add `validateRequirements` and `requirementsSatisfiedBy`.
- Modify `packages/zigeffect/src/layer/layer.zig`: add context-builder layer type and `buildWithContext` delegation.
- Modify `packages/zigeffect/src/layer/graph.zig`: add startup context and `report(label)`.
- Modify `packages/zigeffect/src/zigeffect.zig`: facade aliases for new helper APIs.
- Modify `packages/zigeffect/test/all_test.zig`: import new dependency and invariants tests.
- Create `packages/zigeffect/test/dependency_test.zig`: requirement helper coverage.
- Create `packages/zigeffect/test/invariants_test.zig`: focused internal invariants coverage.
- Create `packages/zigeffect/test/compile_fail/invalid_service_tuple.zig`: malformed service tuple fixture.
- Modify `packages/zigeffect/test/layer_test.zig`: graph report and context-builder tests.
- Modify `packages/zigeffect/test/support/fixtures.zig`: database/context-builder fixtures.
- Update package docs after implementation.

## Tasks

### Task 1: Requirement Helper Tests And Implementation

- [ ] **Step 1: Write failing tests**

Create `packages/zigeffect/test/dependency_test.zig`:

```zig
const std = @import("std");
const fx = @import("zigeffect");
const fixtures = @import("support/fixtures.zig");

test "requirements helpers compare declared requirements against providers" {
    var env = try fx.TestEnv.init(std.testing.allocator);
    defer env.deinit();

    const program = fx.Effect(u32, fixtures.TestError, fx.TestServices)
        .fromFn(fixtures.succeeds)
        .requires(.{ fx.Logger, fx.Config });

    const logger_only = env.layer().provides(.{fx.Logger});
    var missing = try fx.validateRequirements(std.testing.allocator, logger_only, program);
    defer missing.deinit();
    try std.testing.expect(!missing.isValid());
    try std.testing.expect(missing.hasMissing(@typeName(fx.Config)));
    try std.testing.expect(!try fx.requirementsSatisfiedBy(std.testing.allocator, logger_only, program));

    const full = env.layer().provides(.{ fx.Logger, fx.Config });
    var satisfied = try fx.validateRequirements(std.testing.allocator, full, program);
    defer satisfied.deinit();
    try std.testing.expect(satisfied.isValid());
    try std.testing.expect(try fx.requirementsSatisfiedBy(std.testing.allocator, full, program));
}
```

Update `packages/zigeffect/test/all_test.zig` to import it.

- [ ] **Step 2: Verify RED**

Run `bun run zigeffect:test`.

Expected: FAIL because `fx.validateRequirements` and
`fx.requirementsSatisfiedBy` are missing.

- [ ] **Step 3: Implement helpers**

Add `validateRequirements` and `requirementsSatisfiedBy` to
`src/dependency/validation.zig`, then expose them through `src/zigeffect.zig`.

- [ ] **Step 4: Verify GREEN**

Run `bun run zigeffect:test`.

Expected: PASS.

### Task 2: Graph Report And Service Tuple Diagnostics

- [ ] **Step 1: Write failing graph report test**

Add to `packages/zigeffect/test/layer_test.zig`:

```zig
test "graph runtime formats dependency reports directly" {
    var env = try fx.TestEnv.init(std.testing.allocator);
    defer env.deinit();

    const logger_layer = env.layer().provides(.{fx.Logger});
    const metrics_layer = env.layer().requires(.{fx.Config}).provides(.{fx.Metrics});

    var graph = fx.layerGraph(std.testing.allocator, .{ logger_layer, metrics_layer });
    defer graph.deinit();

    const formatted = try graph.report("app startup");
    defer std.testing.allocator.free(formatted);

    try std.testing.expect(std.mem.indexOf(u8, formatted, "program: app startup") != null);
    try std.testing.expect(std.mem.indexOf(u8, formatted, "missing service requirement") != null);
    try std.testing.expect(std.mem.indexOf(u8, formatted, @typeName(fx.Config)) != null);
}
```

- [ ] **Step 2: Write compile-fail fixture**

Create `packages/zigeffect/test/compile_fail/invalid_service_tuple.zig`:

```zig
const fx = @import("zigeffect");

const Env = struct {
    logger: fx.Logger,

    pub fn service(self: *Env, comptime Service: type) *Service {
        if (Service == fx.Logger) return &self.logger;
        return fx.serviceNotFound(Env, Service);
    }
};

pub fn main() void {
    var env: Env = undefined;
    _ = fx.Layer(Env).fromEnv(&env).provides(.{ fx.Logger, 123 });
}
```

Add a test in `layer_test.zig` that compiles this fixture and checks for
`zigeffect service tuple entries must be types`.

- [ ] **Step 3: Verify RED**

Run `bun run zigeffect:test`.

Expected: FAIL because `graph.report` and package-owned service tuple
diagnostics are missing.

- [ ] **Step 4: Implement diagnostics**

Add `assertServiceTuple(api, services)` to `src/dependency/services.zig`. Call it
from `serviceSetBuilder`, `ServiceSet.fromTypes`, `Layer.provides`,
`Layer.requires`, runtime `.provides`, and graph helpers through existing paths.
Add `LayerGraphRuntime.report(label)` in `src/layer/graph.zig`.

- [ ] **Step 5: Verify GREEN**

Run `bun run zigeffect:test`.

Expected: PASS.

### Task 3: Context Builder Tests And Implementation

- [ ] **Step 1: Add fixtures**

Add database-style fixtures to `packages/zigeffect/test/support/fixtures.zig`:

```zig
pub const Database = struct {
    dsn: []const u8,
};

pub const DatabaseLayerEnv = struct {
    database: Database,
    released: *bool,

    pub fn service(self: *DatabaseLayerEnv, comptime Service: type) *Service {
        if (Service == Database) return &self.database;
        return fx.serviceNotFound(DatabaseLayerEnv, Service);
    }
};

pub var database_layer_released = false;
pub var database_layer_builds: usize = 0;

pub fn releaseDatabaseLayerEnv(env: *DatabaseLayerEnv) void {
    env.released.* = true;
    env.database.dsn = "";
    env.allocator.destroy(env);
}
```

Use the concrete implementation from the task body when editing: the fixture
must include an allocator field so release can destroy the env.

- [ ] **Step 2: Write failing context-builder tests**

Add tests to `packages/zigeffect/test/layer_test.zig` covering:

- database layer consumes `Config` and `Logger` through `fromContextBuilder`
- database finalizer runs on `graph.deinit`, not after `graph.run`
- failing context builder returns `error.ConnectionFailed` and closes already
  started dependencies

- [ ] **Step 3: Verify RED**

Run `bun run zigeffect:test`.

Expected: FAIL because `fromContextBuilder` is missing.

- [ ] **Step 4: Implement context builders**

In `src/layer/layer.zig`, add `ContextBuilderLayer` and
`fromContextBuilder(comptime builder: anytype)`. Add `buildWithContext` to base
layers and declaration wrappers.

In `src/layer/graph.zig`, add startup env/context support and call
`layer.buildWithContext(...)` during graph startup.

- [ ] **Step 5: Verify GREEN**

Run `bun run zigeffect:test`.

Expected: PASS.

### Task 4: Invariants Tests

- [ ] **Step 1: Write invariants tests**

Create `packages/zigeffect/test/invariants_test.zig` with tests for:

- `Scope.close` is idempotent and finalizers run once in reverse order
- graph validation rejects invalid metadata before builders run
- scoped fiber interruption closes child finalizers with interruption
- runtime finalizers observe success in reverse order

Import this file in `test/all_test.zig`.

- [ ] **Step 2: Verify GREEN**

Run `bun run zigeffect:test`.

Expected: PASS. These characterize existing behavior and should not require
production changes.

### Task 5: Documentation And Full Verification

- [ ] **Step 1: Update docs**

Update README, usage, errors, EffectTS parity, and roadmap with:

- `validateRequirements`
- `requirementsSatisfiedBy`
- `graph.report(label)`
- `fromContextBuilder`
- graph startup scope ownership

- [ ] **Step 2: Run package verification**

Run `bun run zigeffect:test`.

Expected: PASS.

- [ ] **Step 3: Run workspace verification**

Run:

```bash
bun run zig:test
bun run typecheck
```

Expected: both PASS.
