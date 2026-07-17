# ZigEffect module pattern

Use this shape when a capability grows beyond one operation. A module owns its
service contract, effects, layers, errors, tests, and public facade. The
application root imports only module facades and composes their layers once.

This guide uses the canonical kernel. New modules must not introduce
environment-parameterized effects, provider tuples, `LayerGraph`, or
application-level interpreter calls.

## Folder shape

```text
orders/
  root.zig          # public facade
  service.zig       # service tag and API contract
  operations.zig    # effect constructors
  layers.zig        # live and local implementations
  errors.zig        # domain failure sets
  test/
    operations_test.zig
```

Keep generated protocol types or driver internals behind the module boundary.
Other modules import `orders/root.zig`, not sibling implementation files.

## Service contract

```zig
const fx = @import("zigeffect");
const kernel = fx.kernel;

pub const Repository = kernel.Service("orders/Repository", struct {
    pub const operations: []const []const u8 = &.{
        "Orders.find",
        "Orders.save",
    };

    first_id: u64,
});
```

The stable tag identifies the capability. The API describes only what an
implementation must provide. Do not put process-global initialization or a
runtime inside the service contract.

## Operations

```zig
const FindBase = kernel.Effect(Order, error{NotFound}, .{Repository});
pub const Find = FindBase.Stateful(u64);

pub fn find(id: u64) Find {
    return Find.init(id, struct {
        fn run(value: u64, ctx: *Find.Context) error{NotFound}!Order {
            const repository = ctx.service(Repository);
            if (value < repository.first_id) return error.NotFound;
            return .{ .id = value };
        }
    }.run);
}
```

Operation constructors return descriptions. They never create a root runtime,
run a nested application, or select a live implementation.

## Layers

```zig
pub const live = kernel.Layer.sync(
    Repository,
    .{Config},
    makeRepository,
);

pub fn memory(first_id: u64) @TypeOf(
    kernel.Layer.succeed(Repository, .{ .first_id = first_id }),
) {
    return kernel.Layer.succeed(Repository, .{ .first_id = first_id });
}
```

Export layer values or constructors through the facade. Name implementations by
their environment or behavior—`live`, `memory`, `fake`, `local`—not by a second
service identity.

Scoped implementations acquire and release their resource through
`kernel.Layer.scoped`. The finalizer belongs to the same module as acquisition.

## Public facade

```zig
pub const Repository = @import("service.zig").Repository;
pub const Find = @import("operations.zig").Find;
pub const find = @import("operations.zig").find;
pub const live = @import("layers.zig").live;
pub const memory = @import("layers.zig").memory;
```

The facade is the compatibility boundary. Application code should not need to
know how an operation is represented internally.

## Application root

```zig
const ConfigLive = Config.layer(config);
const OrdersLive = Orders.live.provide(ConfigLive);
const AuditLive = Audit.live.provide(ConfigLive);
const MainLayer = OrdersLive.merge(AuditLive);

var runtime = try zstd.ManagedRuntime(@TypeOf(MainLayer)).make(
    allocator,
    io,
    root,
    MainLayer,
    .{ .observability = observability },
);
defer runtime.deinit();

const program = Orders.find(order_id)
    .flatMap(loadCustomer)
    .tap(Audit.customerRead)
    .named("orders.customer-view");

const result = try runtime.run(program);
try runtime.shutdown();
```

There is one composition root per process or long-lived daemon session. Tests
compose the same program with deterministic layers.

## Testing contract

- Unit-test pure helpers with `std.testing`.
- Run effects against memory or fake layers without changing the program.
- Give semantic acceptance assertions stable IDs and repair hints.
- Assert no pending fibers or causal findings when those are acceptance
  properties.
- Verify the Testing v2 suite receipt after the package-native test command.

## Review checklist

- Does every external capability have one stable service tag?
- Are effect requirements and typed failures visible in the operation type?
- Are live resources acquired by scoped layers and finalized once?
- Does application code compose descriptions without calling `runIn` or
  `ctx.runEffect`?
- Is there one named root program and one managed runtime?
- Are implementation modules hidden behind a public facade?
- Can tests replace every external boundary with a deterministic layer?
- Do reusable boundary adapters automatically emit bounded, redacted causal
  facts without exposing a store or recorder to business code?
