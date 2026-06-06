# zigeffect Guide For Agents

Use this guide when building with `zigeffect`.

## Rules

- Keep app logic as normal Zig functions: `fn run(ctx) Error!A`.
- Use `Effect.fromFn` to make direct-style functions composable.
- Use `Effect.requires(.{ ... })` for production effects that depend on
  services.
- Use `Effect.succeed`, `Effect.fail`, and `Effect.sync` for small reusable
  helpers instead of writing tiny wrapper functions.
- Use `mapError`, `catchAll`, `orElse`, and `tapError` for recovery boundaries.
- Use `onExit` when logic needs the structured `Exit`; use `ensuring` when an
  effect-local finalizer must run on success and failure.
- Use `Layer.fromBuilder` for dependencies that need allocation, startup, or
  teardown.
- Use `LayerWithError` when dependency startup can fail with app-specific
  errors.
- Use `Layer.provides(.{ ... })`, `Layer.requires(.{ ... })`, and `LayerGraph`
  to validate production dependency boundaries before startup.
- Use `fx.layerGraph` when production startup should build heterogeneous
  declared layers automatically and reuse the started dependencies across runs.
- Use `Layer.provide` for tests or tools that should run a program directly from
  a layer. Use `Layer.merge` when a module needs multiple dependency groups.
- Use Zig error sets for typed errors. Do not hide failures in strings or status
  booleans.
- Include `OutOfMemory` when code allocates or registers scoped resources.
- Include `MissingScope` when code registers scoped resources or uses
  `acquireRelease`.
- Use `acquireRelease` for any resource that must be closed, destroyed, or
  returned to a pool.
- Use fallible finalizers when cleanup can fail, then inspect `Runtime.exit` or
  `Scope.firstFinalizerFailure`.
- Use exit-aware finalizers when cleanup behavior depends on success versus
  typed failure.
- Prefer `Runtime.run` or `TestEnv.run` so cleanup is engine-managed.
- Only close scopes manually in low-level scope tests or special runtime code.
- Use `fx.serviceNotFound(Env, Service)` as the final branch of every custom
  environment `service` method.
- Use `fx.formatExit` or `fx.formatCause` for CLI/test reports instead of
  inventing one-off error strings.
- Use `fx.validateLayerRequirements` and `fx.formatDependencyReport` before
  running large application graphs.
- Use `Schedule.repeat` for successful polling/repetition and `Schedule.backoff`
  or `Schedule.jitteredBackoff` for retry loops.
- Use `Schedule.once`, `recurs`, `spaced`, `duration`, and `fibonacci` when
  those names make the retry/repeat policy easier to scan.
- Use `fx.Clock` as the clock service; do not reach directly for OS time inside
  effectful code.
- Add tests before implementation.
- Update usage docs when adding public API.
- Prefer small service structs over global state.

## App Shape

```zig
const AppError = error{ MissingScope, OutOfMemory, MissingConfig, InvalidInput };

fn app(ctx: *fx.Context(AppEnv)) AppError!AppResult {
    const logger = ctx.service(fx.Logger);
    try logger.info("running");
    return .{};
}

const App = fx.Effect(AppResult, AppError, AppEnv).fromFn(app);
```

## Recovery Shape

```zig
fn recover(err: AppError, ctx: *fx.Context(AppEnv)) AppError!AppResult {
    _ = err;
    const logger = ctx.service(fx.Logger);
    try logger.warn("recovering");
    return .{};
}

const Program = App
    .tapError(logFailure)
    .catchAll(AppError, recover);
```

For production modules, attach requirements:

```zig
const Program = App
    .requires(.{ fx.Logger, fx.Config });
```

Custom environments should make missing services obvious:

```zig
const AppEnv = struct {
    logger: fx.Logger,

    pub fn service(self: *AppEnv, comptime Service: type) *Service {
        if (Service == fx.Logger) return &self.logger;
        return fx.serviceNotFound(AppEnv, Service);
    }
};
```

## Layer Shape

```zig
fn buildEnv(allocator: std.mem.Allocator, scope: *fx.Scope) std.mem.Allocator.Error!*AppEnv {
    const env = try allocator.create(AppEnv);
    env.* = .{ .logger = fx.Logger.init(allocator) };

    scope.addFinalizerFor(AppEnv, env, releaseEnv) catch |err| {
        releaseEnv(env);
        return err;
    };

    return env;
}

fn releaseEnv(env: *AppEnv) void {
    const allocator = env.logger.allocator;
    env.logger.deinit();
    allocator.destroy(env);
}

const AppLayer = fx.Layer(AppEnv).fromBuilder(buildEnv);
```

Use `Layer.fromEnv` only when the caller already owns the environment lifetime.

Use `Layer.provide` to run from a layer:

```zig
const result = try AppLayer
    .provides(.{fx.Logger})
    .provide(allocator, App);
```

Use metadata validation before app startup:

```zig
var graph = fx.LayerGraph.init(allocator);
defer graph.deinit();

try graph.addLayer("app", AppLayer.provides(.{fx.Logger}));
try graph.addLayer("program", AppLayer.requires(.{fx.Logger}));

var report = try graph.validate(allocator);
defer report.deinit();

if (!report.isValid()) return error.InvalidDependencyGraph;
```

Use executable graph startup when callers should not hand-write a merged
environment:

```zig
var graph = fx.layerGraph(allocator, .{
    AppLayer.requires(.{ fx.Logger }).provides(.{AppService}),
    LoggerLayer.provides(.{fx.Logger}),
});
defer graph.deinit();

const GraphEnv = @TypeOf(graph).EnvType;
const Program = fx.Effect(AppResult, AppError, GraphEnv)
    .fromFn(app)
    .requires(.{ AppService, fx.Logger });

const result = try graph.run(Program);
```

## Resource Shape

```zig
const ResourceError = error{ MissingScope, OutOfMemory };

fn acquire(ctx: *fx.Context(AppEnv)) ResourceError!*Resource {
    const resource = try ctx.allocator.create(Resource);
    resource.* = .{ .allocator = ctx.allocator };
    return resource;
}

fn release(resource: *Resource) void {
    resource.allocator.destroy(resource);
}

const OpenResource = fx.acquireRelease(Resource, ResourceError, AppEnv, acquire, release);
```

Run `OpenResource` through the runtime. The runtime opens a scope and closes it
in reverse registration order even when the program fails.

```zig
_ = try env.run(OpenResource);
```

If a resource effect returns `error.MissingScope`, the program was run against a
context without an active `Scope`. Run it through `Runtime.run`, `TestEnv.run`,
or construct a context with a scope.

For fallible cleanup:

```zig
try scope.addFinalizerFallibleFor(Resource, resource, releaseMayFail);
```

For exit-aware cleanup:

```zig
fn releaseWithExit(resource: *Resource, exit: fx.FinalizerExit) void {
    switch (exit) {
        .success => resource.releaseCleanly(),
        .failure => resource.releaseAfterFailure(),
        else => resource.releaseCleanly(),
    }
}

try ctx.addFinalizerExitFor(Resource, resource, releaseWithExit);
```

Prefer `Runtime.exit` when a caller needs to inspect cleanup failures as
structured causes.

## Diagnostic Reports

```zig
const exit = env.exit(Program);
const report = try fx.formatExit(std.testing.allocator, "program name", exit);
defer std.testing.allocator.free(report);
```

Use stable program labels like `"compile schema"` or `"load config"` so humans
and agents can connect the report back to the failing workflow.

## Causal Runtime Direction

The long-term agent workflow is documented in
`docs/agent-observable-runtime.md`. The first causal runtime APIs are now
available through `fx.CausalStore`, graph/runtime `.withCausalStore`, query
helpers, and causal report/JSON/DOT formatters. Agents should use them with
this discipline:

- Prefer structured `Exit`, `Cause`, dependency, observability, and test reports
  over ad hoc log scraping.
- Preserve stable labels for effects, layers, resources, schedules, and test
  workflows.
- Keep typed Zig errors visible instead of converting them into strings.
- Add service requirements and provider declarations so future causal queries
  can explain where dependencies came from.
- Use scopes and `acquireRelease` for owned resources so resource lineage can be
  observed later.
- Use tracing spans and trace context where a workflow crosses service or fiber
  boundaries.
- Attach a `CausalStore` to runtime, fiber runtime, or layer graph paths when a
  test or example needs agent-readable evidence.
- Record app-level log, metric, span, config, or assertion facts with
  `ctx.recordCausal` until those services have automatic adapters.

The shortest useful query loop is:

```text
run effect -> inspect causal snapshot -> query lineage -> inspect cause
-> propose test or code fix
```

Attach and report with the public API:

```zig
var store = fx.CausalStore.init(allocator);
defer store.deinit();

var runtime = env.runtime().withCausalStore(&store);
const exit = runtime.exit(Program);
_ = exit;

const report = try fx.formatCausalCiReport(allocator, "program name", &store);
defer allocator.free(report);
```

For broader diagnosis, use:

```text
inspect failing run -> query cause -> query lineage -> inspect requirements
-> inspect resources -> inspect fibers -> inspect retries -> propose fix
```

The runnable example is
[`../examples/causal_readiness.zig`](../examples/causal_readiness.zig). It
starts a graph with config, logger, metrics, tracing, and a database-like
service, runs a readiness effect through a causal store, preserves
`error.MissingConfig` as a typed app failure, and prints `formatCausalReport`
plus `formatCausalJson`.

Use `formatCausalCiReport` when an agent or CI job needs a compact artifact:
it includes event counts, finding counts, citation ids, and recommended next
queries while avoiding raw `redacted_detail` payloads.

## Causal Dogfood Harness

Run the local dogfood harness before changing causal runtime behavior:

```sh
cd packages/zigeffect
zig build causal-test
```

The harness writes:

- `.zig-cache/causal-artifacts/zigeffect-causal-dogfood.txt`
- `.zig-cache/causal-artifacts/zigeffect-causal-dogfood.json`
- `.zig-cache/causal-artifacts/zigeffect-causal-dogfood.dot`

Use the text report for finding summaries and next-query suggestions. Use the
JSON artifact when citing event ids in a fix proposal. Use the DOT artifact
when checking graph shape.

Follow the report's next-query hints with:

```sh
zig build causal-query -- cause 3
zig build causal-query -- lineage 2
zig build causal-query -- resources 1
zig build causal-query -- fibers pending
zig build causal-query -- requirements 1
zig build causal-query -- retries 1
```

Use `zig build causal-query -- --file <path> <query> [argument]` when querying
an artifact from CI or a non-default harness run.

This is the Phase 0 self-improving feedback lane: agents use `zigeffect`'s own
causal runtime as evidence while improving `zigeffect`, then rerun the harness
and package tests to compare behavior.

Backend adapters are sinks, not the source of truth. Keep tests and local agent
queries against the in-memory `CausalStore`; use `store.attachBackend` for
JSONL, DOT, OpenTelemetry, embedded graph, durable-history, or future async
adapters. Do not put CockroachDB, RoachGraph, NenDB, or OpenTelemetry inside
the deterministic core.

Future causal findings should be treated as evidence pointers, not conclusions.
An agent should cite event ids, explain whether an edge is causal or merely
correlated by trace context, and then propose a source, config, test, or runtime
policy change.

When a report contains findings, use this workflow:

```text
start with finding -> cite event id -> query lineage -> query cause
-> inspect scope/resource/fiber/retry evidence -> propose code or config fix
```

The most useful first scenario fixtures are:

- `../examples/causal_missing_config.zig`: missing config during layer startup
- `../examples/causal_cleanup_failure.zig`: cleanup failure after a typed
  program failure
- `../examples/causal_scoped_fiber.zig`: parent scope interrupting a child fiber
- `../examples/causal_retry_exhaustion.zig`: retry exhaustion masking the first
  typed failure
- app incident with trace context linking domain effect, service provider,
  resource scope, and schedule decisions

The intended result is that agents can improve `zigeffect` itself and apps built
with `zigeffect` from typed runtime evidence, not from guesses assembled from
stdout.

## Schedule Shape

```zig
var retry = fx.Schedule.jitteredBackoff(.{
    .max_retries = 5,
    .base_delay_ms = 25,
    .factor = 2,
    .max_delay_ms = 1_000,
    .jitter_ms = 50,
    .seed = 1,
});

const result = try Program.retry(&ctx, &retry);
```

For successful repetition:

```zig
var repeat = fx.Schedule.repeat(.{ .max_repeats = 2, .delay_ms = 10 });
const final = try Program.repeat(&ctx, &repeat);
```

For common retry names:

```zig
var once = fx.Schedule.once();
var recurs = fx.Schedule.recurs(3);
var spaced = fx.Schedule.spaced(.{ .max_retries = 3, .delay_ms = 25 });
var fibonacci = fx.Schedule.fibonacci(.{
    .max_retries = 5,
    .base_delay_ms = 25,
    .max_delay_ms = 1_000,
});
```

## Testing Pattern

```zig
test "program records telemetry" {
    var env = try fx.TestEnv.init(std.testing.allocator);
    defer env.deinit();

    _ = try env.run(Program);

    try env.expectLog("running");
    try env.expectMetric("program.count", 1);
}
```

## Design Review Checklist

Before adding a public API, check:

- Does this still read like Zig?
- Can a user write the body with `try` instead of a combinator chain?
- Are errors statically typed?
- Does cleanup happen through `Runtime`/`Scope` instead of manual calls?
- If cleanup can fail, is it registered as a fallible finalizer?
- Does dependency startup happen through a `Layer` when ownership is not already
  clear?
- Do production effects declare service requirements?
- Do production layers/runtimes declare provided services?
- Is the layer graph validated before app startup?
- Can recovery be expressed with `catchAll`/`orElse` instead of scattered
  conditionals?
- Does cleanup that needs the program outcome use `onExit`, `ensuring`, or
  exit-aware scope finalizers?
- Does repeated/retried work use `Schedule` instead of a hand-rolled loop?
- Do missing services use `fx.serviceNotFound`?
- Do runtime reports use `formatExit`/`formatCause` when shown to users?
- Can `TestEnv` make the behavior deterministic?
- Can an LLM infer the correct usage from the README and tests?

If any answer is no, improve the API or docs before moving on.
