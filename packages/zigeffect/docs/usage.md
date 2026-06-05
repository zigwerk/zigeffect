# zigeffect Usage

`zigeffect` is built around direct-style Zig. Write normal functions, use `try`,
and make resources explicit.

## Minimal Program

```zig
const std = @import("std");
const fx = @import("zigeffect");

const AppError = error{ OutOfMemory, MissingConfig };

fn program(ctx: *fx.Context(fx.TestServices)) AppError![]const u8 {
    const config = ctx.service(fx.Config);
    const logger = ctx.service(fx.Logger);

    const name = try config.require("app.name");
    try logger.info("app started");

    return name;
}

const Program = fx.Effect([]const u8, AppError, fx.TestServices).fromFn(program);
```

Use constructors for simple stdlib helpers and tests:

```zig
const Ready = fx.Effect(bool, AppError, fx.TestServices).succeed(true);
const Failed = fx.Effect(bool, AppError, fx.TestServices).fail(error.InvalidInput);
const Count = fx.Effect(u32, AppError, fx.TestServices).sync(currentCount);
```

Run it in tests:

```zig
var env = try fx.TestEnv.init(std.testing.allocator);
defer env.deinit();

try env.services.config.set("app.name", "zgroach");

const name = try env.run(Program);

try std.testing.expectEqualStrings("zgroach", name);
try env.expectLog("app started");
```

## Typed Errors

Errors are Zig error sets. Keep them local and explicit:

```zig
const CompileError = error{
    OutOfMemory,
    MissingConfig,
    EmptySource,
    InvalidSyntax,
};
```

Include `OutOfMemory` when the program allocates or registers scoped finalizers.
Let Zig prove that a function only throws errors listed in the error set.

## Services

Services live on an environment struct. The environment owns a `service` method:

```zig
const Env = struct {
    logger: fx.Logger,
    config: fx.Config,

    pub fn service(self: *Env, comptime Service: type) *Service {
        if (Service == fx.Logger) return &self.logger;
        if (Service == fx.Config) return &self.config;
        return fx.serviceNotFound(Env, Service);
    }
};
```

Call services from a program through `ctx.service(Service)`.

If the program asks for a service that the environment does not provide,
`serviceNotFound` emits a compile-time diagnostic naming the requested service,
the environment type, and the branch to add.

For production paths, declare service requirements on the effect and declared
providers on the layer/runtime:

```zig
const Program = fx.Effect(Result, AppError, AppEnv)
    .fromFn(program)
    .requires(.{ fx.Logger, fx.Config });

const layer = fx.Layer(AppEnv)
    .fromEnv(&env)
    .provides(.{ fx.Logger, fx.Config });

const result = try layer.provide(allocator, Program);
```

If `Program` requires a service the layer does not declare, `Layer.provide`
returns `error.MissingServiceRequirement` before building or running the effect.
Use `validateLayerRequirements` when you need a rich report:

```zig
var report = try fx.validateLayerRequirements(allocator, layer, Program);
defer report.deinit();

if (!report.isValid()) {
    const text = try fx.formatDependencyReport(allocator, "app startup", report);
    defer allocator.free(text);
    std.debug.print("{s}\n", .{text});
}
```

## Layers

Use `Layer.fromEnv` when a test or app already owns the environment:

```zig
const layer = fx.Layer(Env).fromEnv(&env);
var ctx = layer.context(allocator, &scope);
```

Use `Layer.fromBuilder` when dependencies need construction and scoped cleanup:

```zig
fn buildEnv(allocator: std.mem.Allocator, scope: *fx.Scope) std.mem.Allocator.Error!*Env {
    const env = try allocator.create(Env);
    env.* = .{ .logger = fx.Logger.init(allocator) };

    scope.addFinalizerFor(Env, env, releaseEnv) catch |err| {
        releaseEnv(env);
        return err;
    };

    return env;
}

fn releaseEnv(env: *Env) void {
    const allocator = env.logger.allocator;
    env.logger.deinit();
    allocator.destroy(env);
}

const layer = fx.Layer(Env).fromBuilder(buildEnv);
var ctx = try layer.buildContext(allocator, &scope);
```

Use `LayerWithError` when startup can fail with application errors:

```zig
const StartupError = error{ConnectionFailed};

fn buildEnv(allocator: std.mem.Allocator, scope: *fx.Scope)
    (std.mem.Allocator.Error || StartupError)!*Env
{
    _ = scope;
    const env = try allocator.create(Env);
    errdefer allocator.destroy(env);
    return error.ConnectionFailed;
}

const layer = fx.LayerWithError(Env, StartupError).fromBuilder(buildEnv);
```

The scope owns teardown. Close the scope manually only in low-level tests; app
runtime paths should normally use `Runtime.run` or `TestEnv.run`.

Run a program directly from a layer:

```zig
const result = try layer.provide(allocator, Program);
```

Merge layers by explicitly combining their environments:

```zig
const merged = loggerLayer.merge(ConfigEnv, AppEnv, configLayer, combineAppEnv);
const result = try merged.provide(allocator, AppProgram);
```

Validate larger app graphs before startup with metadata:

```zig
var graph = fx.LayerGraph.init(allocator);
defer graph.deinit();

try graph.addLayer("logger", loggerLayer.provides(.{fx.Logger}));
try graph.addLayer("config", configLayer.provides(.{fx.Config}));
try graph.addLayer("app", appLayer.requires(.{ fx.Logger, fx.Config }));

var report = try graph.validate(allocator);
defer report.deinit();
```

Build and memoize a heterogeneous graph when callers should not hand-write a
merged environment:

```zig
var graph = fx.layerGraph(allocator, .{
    appLayer.requires(.{ fx.Logger, fx.Config }).provides(.{AppService}),
    loggerLayer.provides(.{fx.Logger}),
    configLayer.provides(.{fx.Config}),
});
defer graph.deinit();

const AppEnv = @TypeOf(graph).EnvType;
const Program = fx.Effect(Result, AppError, AppEnv)
    .fromFn(program)
    .requires(.{ AppService, fx.Logger });

const result = try graph.run(Program);
```

`graph.start()` validates duplicates and missing requirements, builds layers in
dependency order, and reuses the same started environments for later `run`
calls. `graph.deinit()` closes the startup scope and releases layer resources.

## Scoped Resources

Use `acquireRelease` for resources that must always be released. Include
`MissingScope` because registering a finalizer requires an active runtime scope.

```zig
const ResourceError = error{ MissingScope, OutOfMemory };

const Handle = struct {
    allocator: std.mem.Allocator,
};

fn acquireHandle(ctx: *fx.Context(fx.TestServices)) ResourceError!*Handle {
    const handle = try ctx.allocator.create(Handle);
    handle.* = .{ .allocator = ctx.allocator };
    return handle;
}

fn releaseHandle(handle: *Handle) void {
    handle.allocator.destroy(handle);
}

const OpenHandle = fx.acquireRelease(
    Handle,
    ResourceError,
    fx.TestServices,
    acquireHandle,
    releaseHandle,
);
```

Run scoped resources through the runtime:

```zig
const handle = try env.run(OpenHandle);
```

The runtime creates a scope, runs the effect, and closes the scope automatically
on success or failure. Manual scope closing is reserved for low-level tests and
advanced cases.

If you run `OpenHandle` against a context without a scope, the effect returns
`error.MissingScope` and immediately releases the acquired handle.

Fallible cleanup can be recorded by the scope:

```zig
try scope.addFinalizerFallibleFor(Handle, handle, closeHandle);
scope.close();

if (scope.firstFinalizerFailure()) |name| {
    std.debug.print("cleanup failed: {s}\n", .{name});
}
```

Exit-aware cleanup receives the outcome that closed the scope:

```zig
fn closeWithStatus(handle: *Handle, exit: fx.FinalizerExit) void {
    switch (exit) {
        .success => handle.closeCleanly(),
        .failure => handle.closeAfterFailure(),
        else => handle.closeCleanly(),
    }
}

try ctx.addFinalizerExitFor(Handle, handle, closeWithStatus);
```

For a custom environment:

```zig
var runtime = fx.Runtime(AppEnv).init(allocator, &env);
const result = try runtime.run(Program);
```

## Fibers

Use `FiberRuntime` when a program needs Effect-style child work with structured
exits and scoped leases:

```zig
var runtime = fx.FiberRuntime(fx.TestServices)
    .init(std.testing.allocator, &env.services)
    .withClock(&env.services.clock)
    .provides(.{ fx.Logger, fx.Config, fx.Metrics, fx.Tracing, fx.MemoryFileSystem, fx.Clock });
defer runtime.deinit();

const fiber = try runtime.fork(Program);
const exit = runtime.join(fiber);
```

The core runtime is deterministic. `fork` creates a pending child and `join`
runs that child to completion if it has not already completed or been
interrupted. This gives tests and tooling stable fiber ids, typed exits,
interruption causes, and child scope cleanup without depending on a platform
event loop.

Use `forkScoped` to lease a child to an active parent scope:

```zig
var ctx = env.context();
const fiber = try runtime.forkScoped(&ctx, Program);
```

If the parent scope closes before the child is joined, the runtime interrupts
the child and closes the child scope with `FinalizerExit.interrupted`.

The zio adapter is the planned real async backend. Libraries that do IO should
prefer `std.Io` at their boundaries so the zio-backed runtime can provide
stackful coroutine execution later without changing application code.

Core coordination primitives are deterministic:

```zig
var deferred = fx.Deferred(u32, AppError).init();
try deferred.completeSuccess(1);
const deferred_exit = try deferred.awaitExit();

var queue = fx.Queue(u32).bounded(allocator, 16);
defer queue.deinit();
try queue.offer(1);
const value = try queue.take();

var semaphore = fx.Semaphore.init(4);
try semaphore.acquire(1);
try semaphore.release(1);
```

## Composition

Prefer direct-style function bodies. Use composition at boundaries:

```zig
const Program = fx.Effect(u32, AppError, fx.TestServices)
    .fromFn(loadCount)
    .map(u64, widenCount)
    .tap(recordTelemetry);
```

If a chain gets hard to read, move the logic back into a named direct-style
function.

## Recovery

Keep errors typed while composing recovery:

```zig
const Program = LoadConfig
    .tapError(logConfigFailure)
    .mapError(AppError, configToAppError)
    .catchAll(AppError, recoverWithDefaults)
    .orElse(FallbackProgram);
```

Use direct-style recovery functions:

```zig
fn recoverWithDefaults(err: ConfigError, ctx: *fx.Context(AppEnv)) AppError!Config {
    _ = err;
    const logger = ctx.service(fx.Logger);
    try logger.warn("using default config");
    return Config.defaults();
}
```

Use `onExit` when an observer needs to know whether the effect succeeded or
failed:

```zig
fn recordExit(exit: fx.Exit(Config, AppError), ctx: *fx.Context(AppEnv)) AppError!void {
    const logger = ctx.service(fx.Logger);
    switch (exit) {
        .success => try logger.info("config loaded"),
        .failure => |err| {
            _ = err;
            try logger.warn("config failed");
        },
        else => try logger.warn("config ended without a typed result"),
    }
}

const Observed = LoadConfig.onExit(recordExit);
```

Use `ensuring` for an effect-local finalizer that must run on both success and
failure:

```zig
fn flushTelemetry(ctx: *fx.Context(AppEnv)) AppError!void {
    const logger = ctx.service(fx.Logger);
    try logger.info("telemetry flushed");
}

const Program = LoadConfig.ensuring(flushTelemetry);
```

## Runtime Reports

Use `formatExit` when a CLI, test, or agent workflow needs a readable report:

```zig
const exit = env.exit(Program);
const report = try fx.formatExit(allocator, "compile schema", exit);
defer allocator.free(report);

std.debug.print("{s}\n", .{report});
```

The report keeps the typed Zig error intact in `Exit`, but prints the program
label, status, error name, and a next-action hint.

## Schedules

Retry uses `Schedule`:

```zig
var retry = fx.Schedule.exponential(.{
    .max_retries = 3,
    .base_delay_ms = 50,
    .max_delay_ms = 1_000,
});

const result = try Program.retry(&ctx, &retry);
```

Common schedule names are available for Effect-style readability:

```zig
var once = fx.Schedule.once();
var recurs = fx.Schedule.recurs(3);
var spaced = fx.Schedule.spaced(.{ .max_retries = 3, .delay_ms = 50 });
var every = fx.Schedule.duration(.{ .max_retries = 3, .duration_ms = 50 });
var fibonacci = fx.Schedule.fibonacci(.{
    .max_retries = 5,
    .base_delay_ms = 25,
    .max_delay_ms = 1_000,
});
```

Repeat reruns successful programs and returns the last success:

```zig
var repeat = fx.Schedule.repeat(.{
    .max_repeats = 2,
    .delay_ms = 10,
});

const final = try Program.repeat(&ctx, &repeat);
```

Use `backoff` or `jitteredBackoff` for retry paths that should spread load:

```zig
var schedule = fx.Schedule.jitteredBackoff(.{
    .max_retries = 5,
    .base_delay_ms = 25,
    .factor = 2,
    .max_delay_ms = 1_000,
    .jitter_ms = 50,
    .seed = 1,
});
```

`TestEnv` wires the fake clock into the context, so retry sleeps are deterministic
in tests.

For runtime-managed cleanup plus retries, put the retry in a direct-style
program or use the low-level context form when you need to share the retry scope.

## Clock

`Clock` is a service. `TestEnv` uses a fake clock, so schedules are
deterministic:

```zig
var ctx = env.context();
const clock = ctx.service(fx.Clock);

clock.sleep(25);
try std.testing.expectEqual(@as(u64, 25), clock.nowMs());
```

Use `fx.Clock.system()` for a wall-clock service in real environments.

## Test Loop

Use this loop for new behavior:

1. Write the failing Zig test.
2. Run `bun run zigeffect:test`.
3. Implement the smallest API that makes the test pass.
4. Run `bun run zig:test`.
5. Update docs if the public API changed.
