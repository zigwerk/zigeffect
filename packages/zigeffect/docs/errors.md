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

`LayerGraph` reports missing layer requirements and duplicate service providers
before app startup. Executable `fx.layerGraph` runs the same validation before
building any layer. Invalid executable graphs return
`error.MissingServiceRequirement` or `error.DuplicateServiceProvider`; typed
startup errors from member layers are preserved.

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
resource.

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

## Cleanup Failures

Scopes can record fallible finalizers:

```zig
try scope.addFinalizerFallibleFor(Resource, resource, releaseMayFail);
scope.close();
```

Use `scope.firstFinalizerFailure()` or `scope.hasFinalizerFailure("CloseFailed")`
in low-level tests. Use `Runtime.exit` when application code needs cleanup
failures surfaced as `Cause.finalizer_failure`.

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
