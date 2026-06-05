# zigeffect Errors

`zigeffect` keeps errors Zig-native, then adds diagnostics around the places
where users usually need help: missing services, missing scopes, and readable
runtime reports.

## Missing Services

Every environment owns a typed `service` method. End it with
`fx.serviceNotFound`:

```zig
pub fn service(self: *Env, comptime Service: type) *Service {
    if (Service == fx.Logger) return &self.logger;
    if (Service == fx.Config) return &self.config;
    return fx.serviceNotFound(Env, Service);
}
```

If an effect asks for a service the environment does not provide, Zig stops at
compile time with a message that names the requested service, the environment,
and the branch to add.

The compile-fail fixture at `test/compile_fail/missing_service.zig` verifies this
diagnostic by compiling a bad environment and checking for the
`zigeffect service not found` report.

## Missing Declared Requirements

Production effects can declare service requirements:

```zig
const Program = LoadConfig.requires(.{ fx.Logger, fx.Config });
```

Layers and runtimes can declare providers:

```zig
const layer = AppLayer.provides(.{ fx.Logger });
```

If `Layer.provide` or `Runtime.run` sees a required service that is not declared
as provided, it returns `error.MissingServiceRequirement` before running the
effect. Generate a rich report with:

```zig
var report = try fx.validateLayerRequirements(allocator, layer, Program);
defer report.deinit();

const text = try fx.formatDependencyReport(allocator, "load config", report);
defer allocator.free(text);
```

When the provider and consumer are not specifically a layer/effect pair, use
the generic helpers:

```zig
const ok = try fx.requirementsSatisfiedBy(allocator, provider, consumer);
var report = try fx.validateRequirements(allocator, provider, consumer);
defer report.deinit();
```

When provider and consumer types expose static metadata, compile-time helpers
are available:

```zig
comptime {
    fx.assertStaticRequirementsSatisfied(ProviderType, ConsumerType);
}
```

Missing static services emit `zigeffect static requirements not satisfied`.

`LayerGraph` reports missing layer requirements and duplicate service providers
before app startup. Executable `fx.layerGraph` runs the same validation before
building any layer. Invalid executable graphs return
`error.MissingServiceRequirement` or `error.DuplicateServiceProvider`; typed
startup errors from member layers are preserved.

Duplicate providers remain errors unless the later provider declares an explicit
replacement with `.replaces(.{Service})`. In that case graph validation treats
the later layer as the owner for that service, and graph service lookup resolves
to the replacement.

Executable graph runtimes can format validation output directly:

```zig
const text = try graph.report("app startup");
defer allocator.free(text);
```

## Environment Mismatches

Runner APIs reject effects whose `EnvType` does not match the target layer or
runtime environment:

```zig
var runtime = fx.Runtime(AppEnv).init(allocator, &env);
_ = try runtime.run(OtherEnvProgram);
```

The compile-time diagnostic starts with `zigeffect environment mismatch`, names
the API, and shows both environment types. This is checked before dependency
validation in `Layer.provide`, `Runtime.run`, `Runtime.exit`,
`FiberRuntime.fork`, `LayerGraphRuntime.run`, and `LayerGraphRuntime.exit`.

## Invalid Service Tuples

Provider and requirement declarations expect tuples of service types:

```zig
const layer = AppLayer
    .provides(.{ fx.Logger, fx.Config })
    .requires(.{ Database });
```

Malformed declarations fail at compile time with stable diagnostics:

- `zigeffect service tuple must be a tuple`
- `zigeffect service tuple entries must be types`

The compile-fail fixture at `test/compile_fail/invalid_service_tuple.zig`
verifies these diagnostics for agent and CI workflows.

## Invalid Composition Shapes

Core composition APIs validate common shape mistakes at compile time before Zig
falls through to harder-to-read type errors.

- `Effect.fromFn` expects `fn (*fx.Context(Env)) Failure!Success`.
- `Layer.merge` expects
  `fn (Allocator, *fx.Scope, *LeftEnv, *RightEnv) Allocator.Error!*CombinedEnv`.
- `acquireRelease` and `acquireReleaseValue` require failure sets that include
  `MissingScope` and `OutOfMemory`.

These checks emit stable diagnostic anchors:

- `zigeffect invalid effect function`
- `zigeffect invalid layer merge function`
- `zigeffect resource failure set`

The compile-fail fixtures under `test/compile_fail/` verify those messages for
agent and CI workflows.

## Missing Scopes

Scoped finalizers require an active `Scope`. Prefer:

```zig
const result = try env.run(Program);
```

or:

```zig
var runtime = fx.Runtime(Env).init(allocator, &env);
const result = try runtime.run(Program);
```

If code registers a finalizer without a scope, `Context.addFinalizerFor` returns
`error.MissingScope`. `acquireRelease` releases the acquired resource
immediately before returning that error, so failed registration does not leak the
resource. A context whose scope has already been closed also returns
`error.MissingScope`, which protects shared runtime scopes from late
registration leaks.

## Runtime Reports

Effects return typed Zig errors. Reports are for people:

```zig
const exit = env.exit(Program);
const report = try fx.formatExit(allocator, "compile schema", exit);
defer allocator.free(report);
```

A failed report includes:

- program label
- status
- error name, defect message, or interrupted fiber id
- next-action hint

Use `formatCause` when working directly with `Cause`.

Recursive `Cause` fixtures use child pointers so tests can build literal
sequential or parallel reports without allocation. When a report must outlive
the source values, or when tooling needs to append cleanup failure to an
existing cause, use `CauseTree`:

```zig
var tree = fx.CauseTree(AppError).init(allocator);
defer tree.deinit();

const failure = try tree.failure(error.Boom);
const cleanup = try tree.finalizerFailure("CloseFailed");
_ = try tree.sequential(failure, cleanup);

const report = try tree.format("shutdown");
defer allocator.free(report);
```

Use `causeTreeWithFinalizerFailure` to preserve an existing `Exit` cause while
adding cleanup failure in an owned tree:

```zig
var tree = try fx.causeTreeWithFinalizerFailure(
    allocator,
    Result,
    AppError,
    exit,
    "CloseFailed",
);
defer tree.deinit();
```

## Recovery

Use recovery combinators at boundaries:

```zig
const Program = LoadConfig
    .tapError(logFailure)
    .mapError(AppError, toAppError)
    .catchAll(AppError, recover)
    .orElse(FallbackProgram);
```

`mapError` changes the error set, `catchAll` recovers with a function, `orElse`
runs a fallback effect, and `tapError` observes failures without swallowing
them.

## Config Errors

Typed config descriptors return `error.MissingConfig` when a key is absent and
no default is present, or `error.InvalidConfigValue` when parsing fails:

```zig
const port = fx.Config.int("http.port");
const value = config.read(port) catch |err| {
    const report = try fx.services.config.formatConfigError(allocator, port, err);
    defer allocator.free(report);
    return err;
};
```

Descriptors marked with `secret()` are redacted in formatted diagnostics.

## Cleanup Failures

Scopes can record fallible finalizers:

```zig
try scope.addFinalizerFallibleFor(Resource, resource, releaseMayFail);
scope.close();
```

Use `scope.firstFinalizerFailure()` or `scope.hasFinalizerFailure("CloseFailed")`
in low-level tests. Use `Runtime.exit` when application code needs cleanup
failures surfaced as `Cause.finalizer_failure`.

If the program fails, defects, or is interrupted and cleanup also fails, runtime
exit paths preserve both facts through direct combined cause variants such as
`Cause.failure_then_finalizer_failure`,
`Cause.defect_then_finalizer_failure`, and
`Cause.interrupted_then_finalizer_failure`:

```zig
const exit = runtime.exit(Program);
switch (exit) {
    .cause => |cause| switch (cause) {
        .failure_then_finalizer_failure => |both| {
            std.debug.print("program: {s}\ncleanup: {s}\n", .{
                @errorName(both.failure),
                both.finalizer_failure,
            });
        },
        else => {},
    },
    else => {},
}
```

Use `causeHasFinalizerFailure`, `causeHasDefect`, and
`causeHasInterruption` in tests when the exact cause shape is less important
than the facts preserved inside it.

When cleanup behavior depends on why the program ended, register an exit-aware
finalizer:

```zig
fn closeWithStatus(resource: *Resource, exit: fx.FinalizerExit) void {
    switch (exit) {
        .success => resource.closeCleanly(),
        .failure => resource.closeAfterFailure(),
        else => resource.closeCleanly(),
    }
}

try ctx.addFinalizerExitFor(Resource, resource, closeWithStatus);
```

`Runtime.run`, `Runtime.exit`, and `Layer.provide` close scopes with the effect
outcome. Manual `scope.close()` is treated as a successful close; use
`scope.closeWithExit(...)` in low-level tests or custom runtimes when the
outcome matters.

## Error Set Shape

Keep error sets honest and local:

```zig
const AppError = error{
    MissingScope,
    OutOfMemory,
    MissingConfig,
    InvalidInput,
};
```

Include `MissingScope` for resource registration paths. Include `OutOfMemory`
when allocating, logging, tracing, metrics, config, files, or scoped finalizer
registration can allocate.
