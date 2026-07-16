# ZigEffect usage

This is the authoritative application-facing guide for the canonical ZigEffect
kernel. New code uses `kernel.Service`, `kernel.Effect`, `kernel.Layer`, and one
process-level `zstd.ManagedRuntime`. The I/O-free `kernel.ManagedRuntime` is the
lower-level interpreter used by framework tests and custom platform adapters.
The older environment-parameterized interpreter is quarantined as a
framework-internal verification surface. It is not part of the standard-library
application model, adapter contracts, scaffolds, or architecture admission
gate.

For a larger example, read [Compositional applications](compositional-applications.md).

## Mental model

| Concept | Purpose |
| --- | --- |
| Service | A stable tag and abstract API contract |
| Effect | A lazy description with success, typed failure, and required services |
| Layer | A resource-safe implementation of one or more services |
| Managed runtime | The single process root that builds layers and interprets effects |
| Runtime inspection | A bounded map of services, layers, operations, fibers, and causal evidence |

Application modules describe programs. Layers select implementations. Only a
runtime or runtime-backed transport interprets a program.

## Complete minimal application

```zig
const std = @import("std");
const zstd = @import("zigeffect_std");
const kernel = zstd.fx.kernel;

const Greeting = kernel.Service("application/Greeting", struct {
    prefix: []const u8,
});

const GreetBase = kernel.Effect([]const u8, error{}, .{Greeting});
const Greet = GreetBase.Stateful([]const u8);

fn greet(name: []const u8) Greet {
    return Greet.init(name, struct {
        fn run(value: []const u8, ctx: *Greet.Context) error{}![]const u8 {
            _ = ctx.service(Greeting).prefix;
            return value;
        }
    }.run);
}

pub fn main(init: std.process.Init) !void {
    const MainLayer = kernel.Layer.succeed(Greeting, .{ .prefix = "hello" });
    var runtime = try zstd.ManagedRuntime(@TypeOf(MainLayer)).make(
        init.gpa,
        init.io,
        std.Io.Dir.cwd(),
        MainLayer,
        .{},
    );
    defer runtime.deinit();

    _ = try runtime.run(greet("Zig").named("application.greet"));
    try runtime.shutdown();
}
```

The service requirement appears in `GreetBase`. A different layer can replace
the implementation without changing the operation or any composed program.

## Define services around capabilities

A service tag contains a globally stable key and the implementation API:

```zig
const Repository = kernel.Service("orders/Repository", struct {
    pub const operations: []const []const u8 = &.{
        "Repository.find",
        "Repository.save",
    };

    first_id: u64,
});
```

Use domain-oriented tags rather than implementation names. Put public operation
names in `operations` when they should appear in the application snapshot.

An effect may access only its declared tags. Attempting to resolve another
service produces a compile-time diagnostic.

## Describe operations as effects

```zig
const FindBase = kernel.Effect(Order, error{NotFound}, .{Repository});
const Find = FindBase.Stateful(u64);

fn find(id: u64) Find {
    return Find.init(id, struct {
        fn run(value: u64, ctx: *Find.Context) error{NotFound}!Order {
            const repository = ctx.service(Repository);
            if (value < repository.first_id) return error.NotFound;
            return .{ .id = value };
        }
    }.run);
}
```

Use `fromFn` for stateless operations and `Stateful`/`fromState` when an
operation captures input. The returned value is inert until a runtime runs it.

## Compose programs fluently

```zig
const program = find(order_id)
    .flatMap(loadCustomer)
    .tap(auditCustomer)
    .map(toResponse)
    .mapError(toPublicError)
    .named("orders.customer-view");
```

The canonical combinators are:

- `map` transforms a success value;
- `flatMap` selects the next effect from a success value;
- `tap` runs an effect while retaining the original success value;
- `andThen` sequences two effects and returns the second result;
- `zip` runs two effects and returns `{ left, right }`;
- `catchAll` recovers from the complete typed failure channel;
- `mapError` transforms the typed failure channel; and
- `named` creates a stable semantic causal parent.

Composition infers the combined service and error sets. Pure combinators do not
allocate and do not add meaningless implementation nodes to the causal graph.

## Build layers once

```zig
const ConfigLive = kernel.Layer.succeed(Config, .{ .first_id = 100 });
const RepositoryLive = kernel.Layer.sync(
    Repository,
    .{Config},
    makeRepository,
).provide(ConfigLive);
const AuditLive = kernel.Layer.sync(
    Audit,
    .{Config},
    makeAudit,
).provide(ConfigLive);

const MainLayer = RepositoryLive.merge(AuditLive);
```

Layer constructors cover constant, synchronous, fallible, effectful, and scoped
service acquisition. Their types expose output services, startup failures, and
unsatisfied construction inputs.

- `provide` satisfies and hides a construction dependency;
- `provideMerge` satisfies it and also exposes it to the runtime; and
- `merge` combines independent outputs.

Reusing the same layer value shares it by identity during a root build. A
scoped layer registers its finalizer before it is made available:

```zig
const DatabaseLive = kernel.Layer.scoped(
    Database,
    error{ConnectFailed},
    .{Config},
    connectDatabase,
    closeDatabase,
).provide(ConfigLive);
```

Finalizers run in reverse acquisition order during runtime disposal, including
after partial startup failure.

## Create one managed runtime

```zig
var runtime = try zstd.ManagedRuntime(@TypeOf(MainLayer)).make(
    allocator,
    io,
    root,
    MainLayer,
    .{ .observability = production_observability },
);
defer runtime.deinit();

const get_result = try runtime.run(getProgram(request));
const post_result = try runtime.run(postProgram(request));
try runtime.shutdown();
```

Do not rebuild or re-provide the root layer for every endpoint. HTTP, gRPC,
queue, and workflow adapters derive a bounded `RuntimeHandle` and interpret each
request or job in a fresh child scope.

Application code never calls `runIn`; it is an interpreter protocol. A service
may request `ctx.runtime()` only when it is itself a transport or dispatcher
that must interpret a child program.

## Defaults and observability

Every application runtime installs default clock, config, console, random, and
tracing services and owns an embedded durable NenDB causal graph. Overrides are
runtime configuration, not service parameters threaded through business
functions.

Runtime observability is an aspect fanout for causal storage, logging, metrics,
tracing, and supervision. Structural events are emitted automatically for:

- layer construction and memoization;
- service provision and resolution;
- run, scope, fiber, resource, and finalizer lifecycle; and
- typed completion and failure.

Domain operations should add stable, redacted semantic facts at external
boundaries. They should not pass a causal store, logger, registry, or tracer
through every service merely to be observable.

## Inspect a running application

```zig
const json = try runtime.agentMapJsonAlloc(allocator, .{
    .max_recent_events = 128,
});
defer allocator.free(json);
```

The versioned agent map contains the validated project manifest and exact agent
workflow alongside the layer topology, services, advertised operations,
dependency edges, memoized reuse, causal health, findings, unresolved fibers,
a bounded recent-event tail, the embedded NenDB summary, and durable follow-up
query contracts. Expose it only through an
authenticated, bounded diagnostics route such as
`zigeffect-http.ApplicationMapHandler`.

Capture `newest_durable_event_id` with `zigeffect graph status --json` before a
focused change and inspect the ordered causal delta afterward with `zigeffect
graph since <id> --limit 256 --json`. See [NenDB-backed agent
development](nendb-agent-development.md).

## Typed failures and structured causes

Zig error sets are the typed effect failure channel. Use `catchAll` or
`mapError` when the program owns recovery or translation. Use runtime `exit`
APIs when the caller must inspect success, typed failure, interruption, defect,
or finalizer failure without immediately returning it.

`Exit`, `Cause`, and `CauseTree` retain structure. Do not flatten failures into
log strings before the application boundary. See [Errors](errors.md).

## Resources, fibers, and durable work

Managed-runtime resources live for the runtime lifetime. Each run has a child
scope; forked fibers are supervised beneath it. Use scoped acquisition for
files, sockets, channels, pools, exporters, and child processes. Never return a
borrowed value whose owner ends before the consumer.

For specialized runtime features, continue with:

- [Resource ownership](resource-ownership.md)
- [Statecharts in production](statecharts-production.md)
- [Migration to durable runtime](migration-to-durable-runtime.md)
- [gRPC, Connect, and Cloud Run](grpc-cloud-run.md)

## Deterministic testing

Use ordinary `std.testing` for focused unit assertions and Testing v2 for
semantic acceptance evidence. First-party and generated test artifacts use the
`zigeffect_test_runner` in server mode and produce suite receipts under
`.zigeffect/tests/suites/`.

After `zig build test`, require a complete passing receipt with equal discovered
and executed counts, zero pending tests, zero leaks, and zero logged errors.
Application projects additionally use manifest-owned scenarios and
`zstd.Testing.TestContext`. See [Agent-first testing](agent-first-testing.md).

## Legacy framework surface

The repository still contains `fx.Effect(..., Env)`, `ServiceEnv`,
`LayerWithError`, `LayerGraph`, and `layerGraph` in quarantined engine
regression domains. Canonical standard-library and adapter packages do not use
that surface. It may be documented in a historical design or internal
compatibility note, but must not appear as the recommended shape for new
applications, packages, services, examples, or scaffolds.

Migration status is tracked in:

- [Standard-library canonical migration](../../zigeffect-std/docs/effect-native-roadmap.md)
- [Native gRPC canonical migration](../../zigeffect-grpc/docs/effect-native-roadmap.md)
- [Ziac canonical composition migration](../../ziac/docs/zigeffect-composition-roadmap.md)

## Reading order

1. [Compositional applications](compositional-applications.md)
2. [Module pattern](module-pattern.md)
3. [Architecture](architecture.md)
4. [Agent-observable runtime](agent-observable-runtime.md)
5. [Agent-first application development](agent-first-application-development.md)
6. [Agent-first testing](agent-first-testing.md)
