# zigeffect Resource Ownership

Resource ownership in `zigeffect` follows one rule: the scope that registers a
finalizer owns the resource. The public APIs differ mainly in which scope they
create or receive.

## Graph Startup Resources

Use graph startup resources for long-lived dependencies such as database pools,
clients, caches, or background coordination state.

Register them from `Layer.fromBuilder` or `Layer.fromContextBuilder` with the
startup `scope` argument:

```zig
fn buildDatabase(
    allocator: std.mem.Allocator,
    scope: *fx.Scope,
    ctx: anytype,
) (std.mem.Allocator.Error || StartupError)!*DatabaseEnv {
    const env = try allocator.create(DatabaseEnv);
    errdefer allocator.destroy(env);

    env.* = .{ .allocator = allocator, .database = try connect(ctx) };
    try scope.addFinalizerFor(DatabaseEnv, env, releaseDatabase);
    return env;
}
```

The graph startup scope closes when `graph.deinit()` runs. It does not close
after each `graph.run`, `graph.runtime().run`, or `graph.fiberRuntime().join`.
If a later startup layer fails, `layerGraph` closes already-started graph
resources before returning the typed startup error.

## Per-Run Resources

Use per-run resources for values acquired by an effect body for one request,
job, command, or test run.

Acquire them through `acquireRelease`, `acquireReleaseValue`, or by registering
finalizers on the active context:

```zig
const Program = fx.acquireRelease(
    Resource,
    AppError,
    AppEnv,
    acquireResource,
    releaseResource,
);
```

`Runtime.run`, `Layer.provide`, `graph.run`, and `graph.runNarrowed` create a
fresh per-run scope. That scope closes with `.success` when the effect succeeds
or with `.failure` when the effect returns a typed error.

## Shared Runtime Scopes

Use `Runtime.withScope` only when a caller deliberately wants resources to live
across multiple `runtime.run` calls.

```zig
var app_scope = fx.Scope.init(allocator);
defer app_scope.deinit();

var runtime = fx.Runtime(AppEnv)
    .init(allocator, &env)
    .withScope(&app_scope);
```

The runtime does not close a shared scope after each run. The caller must close
it. If the scope is already closed, registering a finalizer returns
`error.MissingScope`, and resource helpers release newly acquired resources
before returning that error.

## Fiber-Owned Resources

Each deterministic fiber has a child scope. Resources acquired by the fiber
close when the fiber completes, fails, or is interrupted.

`forkScoped` registers a lease in the active context scope. `forkInScope`
registers the same lease when a layer builder or low-level owner already has a
parent scope. Closing the parent scope interrupts an unfinished child fiber,
which then closes the child scope with an interruption exit.

Graph startup resources are not owned by fiber scopes. A graph-backed fiber can
use a graph service, but that service remains alive until `graph.deinit()`.
When a graph-provided service starts background fiber work during startup, fork
it with `forkInScope(startup_scope, Program)` and register the service release
finalizer before forking. The graph startup scope then interrupts unfinished
children before releasing the owning service runtime.

## Ownership Checklist

- Startup dependency: register in a layer builder startup scope.
- One run/request/job: acquire inside the effect's active context.
- Multiple runs owned by an app lifecycle: pass an explicit shared runtime
  scope and close it yourself.
- Fiber-local work: acquire inside the fiber effect.
- Graph-started child work: attach it to the graph startup scope with
  `forkInScope`.
- Test fake services: use `TestEnv` service layers; `TestEnv.deinit()` owns the
  fake service values.
