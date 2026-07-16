# Compositional ZigEffect applications

ZigEffect applications are values assembled from services, effects, and
layers. Application code describes work; `ManagedRuntime` is the only process
root that builds dependencies and interprets those descriptions. Canonical
applications use `zstd.ManagedRuntime`; the I/O-free kernel runtime beneath it
is a framework and custom-platform boundary.

## Service contract and operation

```zig
const std = @import("std");
const zstd = @import("zigeffect_std");
const kernel = zstd.fx.kernel;

const OrdersApi = struct {
    pub const operations: []const []const u8 = &.{"Orders.find"};
    first_id: u64,
};

pub const Orders = kernel.Service("application/Orders", OrdersApi);
const FindBase = kernel.Effect(u64, error{NotFound}, .{Orders});
pub const Find = FindBase.Stateful(u64);

pub fn find(id: u64) Find {
    return Find.init(id, struct {
        fn run(value: u64, ctx: *Find.Context) error{NotFound}!u64 {
            const orders = ctx.service(Orders);
            if (value < orders.first_id) return error.NotFound;
            _ = ctx.recordCausal(.{
                .kind = .activity_completed,
                .service_key = Orders.service_key,
                .label = "Orders.find",
                .status = "success",
            });
            return value;
        }
    }.run);
}
```

The tag is the dependency identity. The API is the replaceable implementation
contract. The operation returns a lazy effect whose service and error types are
visible to the compiler. Live and fake layers can replace `OrdersApi` without
changing `find` or any program built from it.

## Programs compose without an interpreter

```zig
fn loadCustomer(order_id: u64) Customer.Find {
    return Customer.findForOrder(order_id);
}

fn audit(customer: Customer.Value) Audit.Record {
    return Audit.record(customer.id);
}

pub fn program(id: u64) @TypeOf(
    find(id)
        .flatMap(loadCustomer)
        .tap(audit)
        .named("orders.customer-view"),
) {
    return find(id)
        .flatMap(loadCustomer)
        .tap(audit)
        .named("orders.customer-view");
}
```

`flatMap`, `tap`, `andThen`, `zip`, `map`, `mapError`, and `catchAll` infer the
combined success, typed failure, and required-service sets. They allocate
nothing and execute nothing. Application code never calls `runIn`; that method
is the interpreter protocol used by the runtime.

`named` creates a stable semantic parent in the causal graph. Primitive service
operations remain visible beneath it, while pure combinator implementation
nodes are omitted. This keeps graphs meaningful and instrumentation cost tied
to actual operations.

## Layers compose once

```zig
const ConfigLive = kernel.Layer.succeed(Config, .{ .first_id = 100 });
const OrdersLive = kernel.Layer.sync(Orders, .{Config}, makeOrders)
    .provide(ConfigLive);
const AuditLive = kernel.Layer.sync(Audit, .{Config}, makeAudit)
    .provide(ConfigLive);
const MainLayer = OrdersLive.merge(AuditLive);
```

`provide` satisfies construction inputs and hides the dependency from the
result's outputs. `provideMerge` also exposes the dependency. Reusing the same
layer value shares it by identity during the one root build, including across
separate branches.

## One managed runtime, many entry points

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

Long-lived HTTP, gRPC, queue, and workflow adapters keep a bounded
`RuntimeHandle` derived from this runtime and run each request or job in a fresh
child scope. They do not rebuild or re-provide the root layer per endpoint.

The application runtime always installs defaults, structural causal recording,
scope/resource/fiber lifecycle, the embedded NenDB graph, and the configured
logger, metrics, tracer, and supervisor aspects. Semantic facts inherit the
same run, fiber, scope, trace, and parent lineage.

## One application-map endpoint for people and agents

```zig
const json = try runtime.agentMapJsonAlloc(allocator, .{
    .max_recent_events = 128,
});
defer allocator.free(json);
```

The bounded snapshot contains the root layer, every layer and service,
dependency edges, exposed services, advertised operations, memoized reuse,
causal health counters, findings, unresolved fibers, recent events, embedded
NenDB provenance and graph cursor. An application may expose this through one
authenticated diagnostics endpoint; agents can map the application first and
request bounded `since`, event, or children evidence only when needed.

## Ownership and hot-path guarantees

- layers and application resources are built and finalized once per managed
  runtime;
- every run gets a child scope and supervised fiber lifecycle;
- combinators perform no heap allocation;
- every retained causal event owns all non-empty text in one packed allocation;
- causal text is redacted and bounded before backend delivery or retention;
- `inspect` is the consistent live-read API; historical store queries require a
  quiescent writer barrier; and
- `shutdown` verifies graph persistence before cleanup, while `deinit` is the
  idempotent best-effort error-path fallback.
