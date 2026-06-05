# Zigeffect Fiber Core Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the Stage 1 zigeffect-owned deterministic fiber core: typed fiber handles, fork/join/interrupt, scoped leases, and basic coordination primitives.

**Architecture:** Keep `packages/zigeffect` as the semantic owner and do not add zio. `FiberRuntime(Env)` stores typed child fiber states behind handles, executes pending effects deterministically on join, and binds scoped fibers to the existing `Scope` finalizer system. `Deferred`, `Queue`, and `Semaphore` are deterministic core primitives that later adapters can replace or back with real async primitives.

**Tech Stack:** Zig 0.16.0, Zig build system, Bun scripts, existing `packages/zigeffect/src/zigeffect.zig` and `packages/zigeffect/test/core_test.zig`.

---

### Task 1: Add Fiber Lifecycle Tests

**Files:**
- Modify: `packages/zigeffect/test/core_test.zig`

- [ ] **Step 1: Add test helpers near the existing direct-style effect helpers**

```zig
var fiber_success_finalizer_probe = ExitFinalizerProbe{};
var fiber_failure_finalizer_probe = ExitFinalizerProbe{};
var fiber_scoped_finalizer_probe = ExitFinalizerProbe{};

fn observeTypedFinalizerExit(probe: *ExitFinalizerProbe, exit: fx.FinalizerExit) void {
    probe.status = switch (exit) {
        .success => "success",
        .failure => |name| name,
        .defect => |message| message,
        .interrupted => "interrupted",
        .cause => |name| name,
    };
}

fn succeedsWithFiberFinalizer(ctx: *fx.Context(fx.TestServices)) TestError!u32 {
    fiber_success_finalizer_probe = .{};
    try ctx.addFinalizerExitFor(ExitFinalizerProbe, &fiber_success_finalizer_probe, observeTypedFinalizerExit);
    return 42;
}

fn failsWithFiberFinalizer(ctx: *fx.Context(fx.TestServices)) TestError!u32 {
    fiber_failure_finalizer_probe = .{};
    try ctx.addFinalizerExitFor(ExitFinalizerProbe, &fiber_failure_finalizer_probe, observeTypedFinalizerExit);
    return error.Boom;
}

fn pendingScopedFiber(ctx: *fx.Context(fx.TestServices)) TestError!u32 {
    fiber_scoped_finalizer_probe = .{};
    try ctx.addFinalizerExitFor(ExitFinalizerProbe, &fiber_scoped_finalizer_probe, observeTypedFinalizerExit);
    return 7;
}
```

- [ ] **Step 2: Add failing tests for fork/join success and failure**

```zig
test "fiber runtime forks and joins successful effects" {
    var env = try fx.TestEnv.init(std.testing.allocator);
    defer env.deinit();

    var runtime = fx.FiberRuntime(fx.TestServices)
        .init(std.testing.allocator, &env.services)
        .withClock(&env.services.clock)
        .provides(.{ fx.Logger, fx.Config, fx.Metrics, fx.Tracing, fx.MemoryFileSystem, fx.Clock });
    defer runtime.deinit();

    const program = fx.Effect(u32, TestError, fx.TestServices).fromFn(succeedsWithFiberFinalizer);
    const fiber = try runtime.fork(program);

    try std.testing.expectEqual(@as(fx.FiberId, 1), fiber.id);
    try std.testing.expectEqual(fx.FiberStatus.pending, fiber.status());

    const exit = runtime.join(fiber);
    switch (exit) {
        .success => |value| try std.testing.expectEqual(@as(u32, 42), value),
        else => return error.Empty,
    }
    try std.testing.expectEqual(fx.FiberStatus.done, fiber.status());
    try std.testing.expectEqualStrings("success", fiber_success_finalizer_probe.status);
}

test "fiber runtime preserves typed failure exits" {
    var env = try fx.TestEnv.init(std.testing.allocator);
    defer env.deinit();

    var runtime = fx.FiberRuntime(fx.TestServices)
        .init(std.testing.allocator, &env.services)
        .withClock(&env.services.clock)
        .provides(.{ fx.Logger, fx.Config, fx.Metrics, fx.Tracing, fx.MemoryFileSystem, fx.Clock });
    defer runtime.deinit();

    const program = fx.Effect(u32, TestError, fx.TestServices).fromFn(failsWithFiberFinalizer);
    const fiber = try runtime.fork(program);
    const exit = runtime.join(fiber);

    switch (exit) {
        .failure => |err| try std.testing.expectEqual(error.Boom, err),
        else => return error.Empty,
    }
    try std.testing.expectEqual(fx.FiberStatus.failed, fiber.status());
    try std.testing.expectEqualStrings("Boom", fiber_failure_finalizer_probe.status);
}
```

- [ ] **Step 3: Add failing tests for interruption, scoped leases, requirements, and formatting**

```zig
test "fiber runtime interrupts pending fibers" {
    var env = try fx.TestEnv.init(std.testing.allocator);
    defer env.deinit();

    var runtime = fx.FiberRuntime(fx.TestServices)
        .init(std.testing.allocator, &env.services)
        .withClock(&env.services.clock)
        .provides(.{ fx.Logger, fx.Config, fx.Metrics, fx.Tracing, fx.MemoryFileSystem, fx.Clock });
    defer runtime.deinit();

    const program = fx.Effect(u32, TestError, fx.TestServices).fromFn(succeedsWithFiberFinalizer);
    const fiber = try runtime.fork(program);

    runtime.interrupt(fiber);

    const exit = runtime.join(fiber);
    switch (exit) {
        .interrupted => |id| try std.testing.expectEqual(fiber.id, id),
        else => return error.Empty,
    }
    try std.testing.expectEqual(fx.FiberStatus.interrupted, fiber.status());
}

test "forkScoped leases children to the parent scope" {
    var env = try fx.TestEnv.init(std.testing.allocator);
    defer env.deinit();

    var runtime = fx.FiberRuntime(fx.TestServices)
        .init(std.testing.allocator, &env.services)
        .withClock(&env.services.clock)
        .provides(.{ fx.Logger, fx.Config, fx.Metrics, fx.Tracing, fx.MemoryFileSystem, fx.Clock });
    defer runtime.deinit();

    var ctx = env.context();
    const program = fx.Effect(u32, TestError, fx.TestServices).fromFn(pendingScopedFiber);
    const fiber = try runtime.forkScoped(&ctx, program);

    env.scope.closeWithExit(.success);

    const exit = runtime.join(fiber);
    switch (exit) {
        .interrupted => |id| try std.testing.expectEqual(fiber.id, id),
        else => return error.Empty,
    }
    try std.testing.expectEqual(fx.FiberStatus.interrupted, fiber.status());
}

test "fiber runtime validates dependency requirements before forking" {
    var env = try fx.TestEnv.init(std.testing.allocator);
    defer env.deinit();

    var runtime = fx.FiberRuntime(fx.TestServices)
        .init(std.testing.allocator, &env.services)
        .withClock(&env.services.clock)
        .provides(.{ fx.Logger });
    defer runtime.deinit();

    const program = fx.Effect(u32, TestError, fx.TestServices)
        .fromFn(succeeds)
        .requires(.{ fx.Logger, fx.Config });

    try std.testing.expectError(error.MissingServiceRequirement, runtime.fork(program));
}

test "interrupted fiber exits format with fiber id" {
    const report = try fx.formatExit(
        std.testing.allocator,
        "load profile fiber",
        fx.Exit(u32, TestError){ .interrupted = 22 },
    );
    defer std.testing.allocator.free(report);

    try std.testing.expect(std.mem.indexOf(u8, report, "status: interrupted") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "fiber: 22") != null);
}
```

- [ ] **Step 4: Run tests and verify the expected red state**

Run:

```bash
bun run zigeffect:test
```

Expected: FAIL because `FiberRuntime`, `FiberId`, and `FiberStatus` are not implemented.

### Task 2: Implement Deterministic Fiber Runtime

**Files:**
- Modify: `packages/zigeffect/src/zigeffect.zig`

- [ ] **Step 1: Add public fiber declarations near the existing error declarations**

```zig
pub const FiberId = u64;

pub const FiberStatus = enum {
    pending,
    running,
    done,
    failed,
    interrupted,
};
```

- [ ] **Step 2: Add the typed fiber state and handle before `Runtime(Env)`**

Implement `FiberState(Success, Failure, Env)` with:

- `id`
- child `Scope`
- `status`
- optional `Exit(Success, Failure)`
- type-erased task pointer
- task runner
- task deinitializer
- `run(ctx)`
- `interrupt()`
- `deinit()`

Implement `Fiber(Success, Failure, Env)` with:

- `id`
- `state`
- `runtime`
- `status()`
- `joinExit()`
- `interrupt()`

- [ ] **Step 3: Add `FiberRuntime(Env)` before the existing `Runtime(Env)`**

Implement the runtime with:

- `allocator`
- `env`
- optional `clock`
- service metadata builder
- monotonically increasing `next_fiber_id`
- owned type-erased fiber records
- `init`
- `deinit`
- `withClock`
- `provides`
- `providedServices`
- `context`
- `fork`
- `forkScoped`
- `join`
- `interrupt`

The core deterministic rule is:

- `fork` validates requirements and stores a pending child.
- `join` runs a pending child to completion and returns its `Exit`.
- `interrupt` changes pending or running children to `Exit.interrupted(id)`.
- `forkScoped` registers a parent-scope finalizer that interrupts unfinished
  children.

- [ ] **Step 4: Run tests and verify green**

Run:

```bash
bun run zigeffect:test
```

Expected: PASS.

### Task 3: Add Coordination Primitive Tests

**Files:**
- Modify: `packages/zigeffect/test/core_test.zig`

- [ ] **Step 1: Add failing tests for `Deferred`**

```zig
test "deferred completes once with structured exits" {
    var deferred = fx.Deferred(u32, TestError).init();

    try std.testing.expectError(error.DeferredNotCompleted, deferred.awaitExit());
    try deferred.completeSuccess(55);
    try std.testing.expectError(error.DeferredAlreadyCompleted, deferred.completeFailure(error.Boom));

    const exit = try deferred.awaitExit();
    switch (exit) {
        .success => |value| try std.testing.expectEqual(@as(u32, 55), value),
        else => return error.Empty,
    }
}
```

- [ ] **Step 2: Add failing tests for `Queue`**

```zig
test "queue preserves fifo order and reports empty or full" {
    var queue = fx.Queue(u32).bounded(std.testing.allocator, 2);
    defer queue.deinit();

    try std.testing.expectError(error.QueueEmpty, queue.take());
    try queue.offer(1);
    try queue.offer(2);
    try std.testing.expectError(error.QueueFull, queue.offer(3));

    try std.testing.expectEqual(@as(u32, 1), try queue.take());
    try std.testing.expectEqual(@as(u32, 2), try queue.take());
    try std.testing.expectError(error.QueueEmpty, queue.take());
}
```

- [ ] **Step 3: Add failing tests for `Semaphore`**

```zig
test "semaphore acquires and releases bounded permits" {
    var semaphore = fx.Semaphore.init(2);

    try std.testing.expectEqual(@as(usize, 2), semaphore.available());
    try semaphore.acquire(2);
    try std.testing.expectEqual(@as(usize, 0), semaphore.available());
    try std.testing.expectError(error.SemaphoreUnavailable, semaphore.acquire(1));
    try semaphore.release(1);
    try std.testing.expectEqual(@as(usize, 1), semaphore.available());
    try std.testing.expectError(error.SemaphoreOverRelease, semaphore.release(2));
}
```

- [ ] **Step 4: Run tests and verify the expected red state**

Run:

```bash
bun run zigeffect:test
```

Expected: FAIL because `Deferred`, `Queue`, and `Semaphore` are not implemented.

### Task 4: Implement Coordination Primitives

**Files:**
- Modify: `packages/zigeffect/src/zigeffect.zig`

- [ ] **Step 1: Add deterministic primitive errors**

```zig
pub const FiberPrimitiveError = error{
    DeferredAlreadyCompleted,
    DeferredNotCompleted,
    QueueEmpty,
    QueueFull,
    SemaphoreUnavailable,
    SemaphoreOverRelease,
};
```

- [ ] **Step 2: Implement `Deferred(Success, Failure)`**

The type stores `?Exit(Success, Failure)` and exposes:

- `init()`
- `isCompleted()`
- `completeExit(exit)`
- `completeSuccess(value)`
- `completeFailure(err)`
- `awaitExit()`

- [ ] **Step 3: Implement `Queue(T)`**

The type stores an `ArrayList(T)` and optional capacity. It exposes:

- `init(allocator)`
- `bounded(allocator, capacity)`
- `deinit()`
- `len()`
- `offer(value)`
- `take()`

- [ ] **Step 4: Implement `Semaphore`**

The type stores `permits` and `max_permits`. It exposes:

- `init(permits)`
- `available()`
- `acquire(permits)`
- `release(permits)`

- [ ] **Step 5: Run tests and verify green**

Run:

```bash
bun run zigeffect:test
```

Expected: PASS.

### Task 5: Documentation And Verification

**Files:**
- Modify: `packages/zigeffect/README.md`
- Modify: `packages/zigeffect/docs/usage.md`
- Modify: `packages/zigeffect/docs/effectts-parity.md`

- [ ] **Step 1: Update README feature list**

Add bullets for:

- deterministic `FiberRuntime`, `Fiber`, `fork`, `join`, `interrupt`, and scoped leases
- `Deferred`, `Queue`, and `Semaphore`
- zio remaining an optional future backend

- [ ] **Step 2: Add usage docs for core fibers**

Add a short section showing:

```zig
var runtime = fx.FiberRuntime(fx.TestServices)
    .init(std.testing.allocator, &env.services)
    .withClock(&env.services.clock)
    .provides(.{ fx.Logger, fx.Config, fx.Metrics, fx.Tracing, fx.MemoryFileSystem, fx.Clock });
defer runtime.deinit();

const fiber = try runtime.fork(Program);
const exit = runtime.join(fiber);
```

Explain that the core runtime is deterministic and semantic-first. It does not
claim real green-thread suspension; the zio adapter will provide real async
execution later.

- [ ] **Step 3: Update EffectTS parity docs**

Add a fiber section that marks Stage 1 as core semantic parity for lifecycle,
leases, and structured exits, with true async scheduling deferred to the zio
backend.

- [ ] **Step 4: Run package verification**

Run:

```bash
bun run zigeffect:test
```

Expected: PASS.

- [ ] **Step 5: Run repository Zig verification**

Run:

```bash
bun run zig:test
```

Expected: PASS for `zigeffect` and `zgroach`.
