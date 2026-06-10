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
Include `MissingScope` when using `acquireRelease`, `acquireReleaseValue`, or
direct scoped finalizer registration. Let Zig prove that a function only throws
errors listed in the error set.

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

Use `requirementsSatisfiedBy` for a boolean preflight check when both sides have
declared metadata:

```zig
if (!try fx.requirementsSatisfiedBy(allocator, layer, Program)) {
    return error.InvalidDependencyGraph;
}
```

When both sides are compile-time known wrapper types, use the static helper:

```zig
comptime {
    fx.assertStaticRequirementsSatisfied(@TypeOf(layer), @TypeOf(Program));
}
```

## Typed Config

`Config` still supports direct string reads, and typed descriptors can parse the
same provider values:

```zig
try config.set("http.port", "8080");
try config.set("feature.enabled", "true");

const port = try config.read(fx.Config.int("http.port"));
const enabled = try config.read(fx.Config.boolean("feature.enabled"));
const region = try config.read(fx.Config.string("region").withDefault("local"));
```

Load a whole typed struct from descriptors when startup code wants one config
value object:

```zig
const AppConfig = struct {
    name: []const u8,
    port: i64,
    enabled: bool,
};

const schema = fx.Config.schema(AppConfig, .{
    .name = fx.Config.string("app.name"),
    .port = fx.Config.int("http.port"),
    .enabled = fx.Config.boolean("feature.enabled").withDefault(false),
});

const app = try config.readSchema(schema);
```

Use `secret()` when formatting diagnostics for sensitive keys:

```zig
const password = fx.Config.string("database.password").secret();
const report = try fx.services.config.formatConfigError(
    allocator,
    password,
    error.MissingConfig,
);
defer allocator.free(report);
```

Load provider data from explicit entries or dotenv/file text supplied by the
caller:

```zig
const entries = [_]fx.ConfigEntry{
    .{ .key = "http.port", .value = "8080" },
    .{ .key = "feature.enabled", .value = "true" },
};
try config.loadEntries(&entries);

try config.loadDotEnv(
    \\database.dsn = postgres://local
    \\feature.enabled = false
);
```

Use `ConfigEnv` when config should participate in normal layer graph startup:

```zig
var configEnv = fx.ConfigEnv.init(allocator);
defer configEnv.deinit();
try configEnv.config.loadDotEnv(dotenvText);

const configLayer = fx.Layer(fx.ConfigEnv)
    .fromEnv(&configEnv)
    .provides(.{fx.Config});
```

For a compile-checked startup example that combines config, logger, a database
layer, graph startup validation, narrowed app execution, and fake test layers,
see [`../examples/readiness.zig`](../examples/readiness.zig).

## Observability

Logger keeps plain messages for simple assertions and also records structured
entries:

```zig
try logger.logFields(.info, "request handled", &.{
    .{ .key = "route", .value = "/health" },
});

try logger.logWithContext(
    .info,
    "request handled",
    &.{.{ .key = "status", .value = "200" }},
    .{ .timestamp_ms = 1234, .trace_id = trace_id, .span_id = span_id },
);
```

Runtimes can carry trace metadata into effect contexts:

```zig
var runtime = fx.Runtime(AppEnv)
    .init(allocator, &env)
    .withTraceContext(trace_id, span_id);

try runtime.run(Program);
```

Inside `Program`, read `ctx.trace_id` and `ctx.span_id` when service calls need
to attach the active trace context. `FiberRuntime` and `LayerGraphRuntime`
propagate the same metadata into the contexts they create.

Metrics supports counters, gauges, histograms, and deterministic snapshots:

```zig
try metrics.increment("requests.total", 1);
try metrics.observe("request.ms", 25);

var snapshot = try metrics.snapshot(allocator);
defer snapshot.deinit();
```

Tracing supports plain events plus span ids and parent relationships:

```zig
const root = try tracing.startSpanWithAttributes("compile", null, &.{
    .{ .key = "component", .value = "compiler" },
});
const child = try tracing.startSpan("parse", root);
try tracing.endSpan(child);
```

Root spans allocate trace ids. Child spans inherit their parent's trace id.

Format captured observability state for CLI diagnostics, test snapshots, or
agent-readable reports:

```zig
const report = try fx.formatObservabilityReport(
    allocator,
    "health check",
    logger,
    metrics,
    tracing,
);
defer allocator.free(report);
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

Use `fromContextBuilder` when a layer needs services that were built by earlier
layers in a graph:

```zig
const StartupError = error{ConnectionFailed};

const Database = struct {
    dsn: []const u8,
};

const DatabaseEnv = struct {
    allocator: std.mem.Allocator,
    database: Database,

    pub fn service(self: *DatabaseEnv, comptime Service: type) *Service {
        if (Service == Database) return &self.database;
        return fx.serviceNotFound(DatabaseEnv, Service);
    }
};

fn releaseDatabase(env: *DatabaseEnv) void {
    env.allocator.destroy(env);
}

fn buildDatabase(
    allocator: std.mem.Allocator,
    scope: *fx.Scope,
    ctx: anytype,
) (std.mem.Allocator.Error || StartupError)!*DatabaseEnv {
    const config = ctx.service(fx.Config);
    const logger = ctx.service(fx.Logger);

    try logger.info("database layer starting");
    const dsn = config.require("database.dsn") catch return error.ConnectionFailed;

    const env = try allocator.create(DatabaseEnv);
    errdefer allocator.destroy(env);
    env.* = .{
        .allocator = allocator,
        .database = .{ .dsn = dsn },
    };
    try scope.addFinalizerFor(DatabaseEnv, env, releaseDatabase);
    return env;
}

const databaseLayer = fx.LayerWithError(DatabaseEnv, StartupError)
    .fromContextBuilder(buildDatabase)
    .requires(.{ fx.Config, fx.Logger })
    .provides(.{Database});
```

Use `fromEffect` when startup is easier to express as an effect over a narrowed
service environment:

```zig
const StartupEnv = fx.ServiceEnv(.{ fx.Config, fx.Logger });

const BuildDatabase = fx.Effect(*DatabaseEnv, std.mem.Allocator.Error || StartupError, StartupEnv)
    .fromFn(buildDatabaseEffect)
    .requires(.{ fx.Config, fx.Logger });

const databaseLayer = fx.LayerWithError(DatabaseEnv, StartupError)
    .fromEffect(BuildDatabase)
    .provides(.{Database});
```

The builder receives the graph startup context, not a per-run context. Services
come from already-started dependency layers, and finalizers registered into the
provided `scope` live until `graph.deinit()`. If a later builder fails,
`layerGraph` closes already-started dependencies before returning the startup
error.

Use `ServiceEnv` when an app effect should depend on a narrow service slice
instead of the whole generated graph environment:

```zig
const DatabaseOnly = fx.ServiceEnv(.{Database});

const Program = fx.Effect([]const u8, AppError, DatabaseOnly)
    .fromFn(loadFromDatabase)
    .requires(.{Database});

const value = try graph.runNarrowed(.{Database}, Program);
```

`runNarrowed` and `exitNarrowed` build a normal per-run scope, project the
requested service pointers from the graph context, and keep startup resources
owned by `graph.deinit()`.

The scope owns teardown. Close the scope manually only in low-level tests; app
runtime paths should normally use `Runtime.run` or `TestEnv.run`.
For deeper ownership rules, see [Resource Ownership](resource-ownership.md).

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

Executable graph runtimes can format the same report directly:

```zig
var graph = fx.layerGraph(allocator, .{ loggerLayer, appLayer });
defer graph.deinit();

const report = try graph.report("app startup");
defer allocator.free(report);
```

Duplicate providers are invalid unless the later graph layer explicitly replaces
the service:

```zig
const baseConfig = fx.Layer(BaseConfigEnv)
    .fromEnv(&base)
    .provides(.{fx.Config});

const overrideConfig = fx.Layer(OverrideConfigEnv)
    .fromEnv(&override)
    .provides(.{fx.Config})
    .replaces(.{fx.Config});
```

Replacement is graph-local metadata. Validation accepts the duplicate only for
services named in `.replaces`, and generated graph environments resolve that
service to the latest provider.

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

Use `graph.runtime()` when a graph-started environment should run through the
regular runtime API:

```zig
var runtime = try graph.runtime();
const result = try runtime.run(Program);
```

Use `graph.fiberRuntime()` when the same graph-started environment should run
through deterministic fibers:

```zig
var fiber_runtime = try graph.fiberRuntime();
defer fiber_runtime.deinit();

const fiber = try fiber_runtime.fork(Program);
const exit = fiber_runtime.join(fiber);
```

Both adapters validate effect requirements against the graph's declared
providers. Runtime and fiber scopes are per-run or parent/child scopes; graph
startup resources remain owned by the graph startup scope and are released only
when `graph.deinit()` closes that scope.

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

Use `Runtime.withScope` when an application lifecycle should own resources
across multiple runs:

```zig
var appScope = fx.Scope.init(allocator);
defer appScope.deinit();

var runtime = fx.Runtime(AppEnv)
    .init(allocator, &env)
    .withScope(&appScope);

_ = try runtime.run(OpenHandle);

appScope.close();
```

Shared runtime scopes are explicit: the runtime does not close the scope after
each run, and `Runtime.exit` does not include finalizer failures until the
caller closes the shared scope. If a shared scope is already closed, resource
registration returns `error.MissingScope` and `acquireRelease` immediately
releases the acquired handle.

If you run `OpenHandle` against a context without a scope, the effect returns
`error.MissingScope` and immediately releases the acquired handle.

Use `acquireReleaseValue` for small handle-like values where copying the value
into a finalizer box is acceptable:

```zig
const Permit = struct {
    id: u32,
};

fn acquirePermit(ctx: *fx.Context(AppEnv)) ResourceError!Permit {
    _ = ctx;
    return .{ .id = 1 };
}

fn releasePermit(permit: Permit) void {
    _ = permit;
}

const OpenPermit = fx.acquireReleaseValue(
    Permit,
    ResourceError,
    AppEnv,
    acquirePermit,
    releasePermit,
);
```

The returned value is a copy. The scope owns a boxed copy for cleanup and closes
resources in reverse acquisition order. Use this helper only for values where
that copy-based cleanup model is safe; use pointer `acquireRelease` when a
resource needs identity or unique mutable ownership.

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

Use `forkInScope` when a layer builder or low-level owner already has the
parent scope:

```zig
const fiber = try runtime.forkInScope(startup_scope, Program);
```

If the parent scope closes before the child is joined, the runtime interrupts
the child and closes the child scope with `FinalizerExit.interrupted`.

Use `LocalAsyncBackendState` when a local runtime, workflow scheduler, or
cluster transport wait needs backend-owned suspension, timer wakeups, typed
network/file waits, or cancellation wakeups:

```zig
var async_state = fx.LocalAsyncBackendState.init(allocator, .{ .now_ms = 1_000 });
defer async_state.deinit();
const backend = async_state.backend();
var runtime = fx.Runtime(AppEnv).init(allocator, &env).withAsyncBackend(backend);
```

Direct-style effects stay synchronous unless they explicitly use
`ctx.suspendRuntime`, `ctx.registerIoWait`, or return
`RuntimeDecision.suspended`.

The current backend is explicit and deterministic:

```zig
const backend = fx.deterministicBackend();
try std.testing.expect(!backend.can_suspend);
```

`Runtime.backendCapabilities()` and `FiberRuntime.backendCapabilities()` expose
the same capability contract. Async backend additions should preserve `Scope`,
`Exit`, `Cause`, and service lookup contracts.

## Production Shard Lease Guards

Cluster-owned durable writes should validate a storage-backed fence immediately
before mutation. Use `LocalShardLeaseManager.fenceForShard` to derive the
current token, then use `ShardLeaseWriteGuard` or the higher-level runtime and
workflow APIs:

```zig
const fence = try lease_manager.fenceForShard(shard_id);
const guard = fx.ShardLeaseWriteGuard.init(
    lease_manager.storage,
    fence,
    .message_submit,
);

var submitted = try fx.guardMessageSubmit(message_storage, .{
    .guard = guard,
    .request = .{
        .shard_id = shard_id,
        .envelope = envelope,
        .now_ms = now_ms,
    },
});
defer submitted.deinit(allocator);
```

Successful guarded writes stamp `lease_epoch` on message/mailbox envelopes and
append `lease_epoch=<epoch>` to workflow journal details. `ClusterRuntime` and
`ClusterWorkflowEntityHandler` already use these guards for shard-owned message,
queue, timer, and journal mutation paths.

Use `auditOwnedLeases` to inspect local ownership against durable storage:

```zig
var audit = try lease_manager.auditOwnedLeases(allocator, now_ms);
defer audit.deinit();

if (audit.stale_owner != 0 or audit.stale_epoch != 0 or audit.expired != 0) {
    // Drain or reacquire according to the runner policy.
}
```

Use `forceReleaseStaleShard` only after the stored lease has expired past the
configured clock-skew tolerance. Health-inspector recovery by owner still uses
`recoverDeadRunner`.

Core coordination primitives are deterministic:

```zig
var deferred = fx.Deferred(u32, AppError).init();
try deferred.completeSuccess(1);
const deferred_exit = try deferred.awaitExit();

var queue = fx.Queue(u32).bounded(allocator, 16);
defer queue.deinit();
try queue.offer(1);
const value = try queue.take();
queue.shutdown();
try std.testing.expectError(error.QueueShutdown, queue.take());

var semaphore = fx.Semaphore.init(4);
try semaphore.acquire(1);
try semaphore.release(1);

var scope = fx.Scope.init(allocator);
defer scope.deinit();
try semaphore.acquireScoped(&scope, 2);
scope.close();
```

A shut down queue rejects new offers but still lets callers drain already
buffered items. `Semaphore.acquireScoped` releases permits through the supplied
scope, which is useful when a permit should be tied to a runtime, graph, or
fiber lifetime.

Deterministic coordination never suspends. Inspect wait states before deciding
whether an operation would proceed, fail immediately, or suspend in a future
backend:

```zig
try std.testing.expectEqual(fx.DeferredAwaitState.pending, deferred.awaitState());
try std.testing.expectEqual(fx.QueueOfferState.backpressured, queue.offerState());
try std.testing.expectEqual(fx.QueueTakeState.empty, queue.takeState());
try std.testing.expectEqual(fx.SemaphoreAcquireState.unavailable, semaphore.acquireState(8));
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

Use `timeout` when a fixed-delay retry policy must stop before exceeding an
elapsed delay budget, and `reset` when a runtime/test needs to know when idle
time should reset retry state:

```zig
var timeout = fx.Schedule.timeout(.{
    .max_retries = 5,
    .delay_ms = 100,
    .timeout_ms = 250,
});

var reset = fx.Schedule.reset(.{
    .max_retries = 3,
    .delay_ms = 50,
    .reset_after_ms = 1_000,
});

const next_attempt = reset.resetAttempt(attempt, idle_ms);
```

Inspect schedule decisions in tests:

```zig
const decision = schedule.decision(2);
try std.testing.expect(decision.continues);
try std.testing.expectEqual(@as(?u64, 100), decision.delay_ms);
```

Compose two schedules at a decision point when a boundary needs simple algebra:

```zig
var retry_a = fx.Schedule.recurs(3);
var retry_b = fx.Schedule.spaced(.{ .max_retries = 2, .delay_ms = 50 });

const earlier = retry_a.unionNextDelay(&retry_b, attempt);
const later_when_both_continue = retry_a.intersectionNextDelay(&retry_b, attempt);
```

`unionNextDelay` continues while either schedule continues and chooses the
earlier available delay. `intersectionNextDelay` continues only while both
schedules continue and chooses the later delay.

Use `ScheduleProgram` when composition should be an owned recursive program:

```zig
var program = fx.ScheduleProgram.init(allocator);
defer program.deinit();

const fast = try program.schedule(fx.Schedule.fixed(.{
    .max_retries = 3,
    .delay_ms = 10,
}));
const slow = try program.schedule(fx.Schedule.fixed(.{
    .max_retries = 2,
    .delay_ms = 25,
}));

const either = try program.unionWith(fast, slow);
const both = try program.intersectionWith(fast, slow);
_ = try program.sequence(either, both);

const delay = program.nextDelay(attempt);
```

`sequence` runs the first child until it is exhausted, then runs the second
child with attempts reset to zero.

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

Useful deterministic assertions live on `TestEnv` and `fx.testing`:

```zig
try env.expectStructuredLog(.info, "request handled");
try env.expectHistogram("request.ms", 2, 35, 10, 25);
try env.expectSpanEnded(span_id);
try env.expectSpanParent(child_span, root_span);
try env.putFixture("report", "expected output");
try env.expectGolden("report", actual_output);

try fx.testing.expectDependencyReportMissing(&report, @typeName(fx.Config));
try fx.testing.expectCauseFinalizerFailure(cause, "CloseFailed");
try fx.testing.expectScheduleDelay(&schedule, 0, 25);
try fx.testing.expectFiberStatus(fiber, .done);
try fx.testing.expectQueueLen(&queue, 0);
try fx.testing.expectQueueShutdown(&queue, true);
```

When an agent-facing harness needs a readable failure body, format assertion
reports explicitly:

```zig
const log_report = try env.formatLogAssertionReport("request handled");
defer allocator.free(log_report);

const schedule_report = try fx.testing.formatScheduleDelayAssertionReport(
    allocator,
    attempt,
    25,
    schedule.nextDelay(attempt),
);
defer allocator.free(schedule_report);
```

Use `TestEnv` service layers when tests need normal layer graph wiring with
fake services:

```zig
var graph = fx.layerGraph(allocator, .{
    env.loggerLayer(),
    env.configLayer(),
});

const logger_and_config = env.serviceLayer(.{ fx.Logger, fx.Config });
```
