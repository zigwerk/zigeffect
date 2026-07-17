# Runtime-owned causal applications

This is the canonical observability boundary for ZigEffect applications.
Application code declares services, effects, layers, statecharts, workflows and
business policy. It does not construct a causal store, attach a graph backend,
forward a recorder through business APIs or reproduce lifecycle events.

## Ownership

| Owner | What it records |
|---|---|
| `zstd.ManagedRuntime` | runs, effects, scopes, fibers, resources, layers, services, exits, supervision, graph health and shutdown |
| Standard-library and transport adapters | config, Schema, HTTP, gRPC, SQL, process, storage, retry and protocol boundaries |
| Domain frameworks such as Ziac | plans, resource operations, provider RPCs, retry/LRO, drift, workflow checkpoints and state commits |
| Application | business declarations, typed policy and composition |
| Test harness | controlled store injection, assertions, graph-ID mapping and proof publication |

The runtime-owned recorder and embedded NenDB graph are always installed for a
canonical application. Logger, metrics, tracing and causal recording are one
runtime aspect fanout. An adapter receives a narrow recording capability from
the effect context when it must add semantics the runtime cannot infer; the
adapter cannot inspect, configure or release the store.

## Canonical application

```zig
const std = @import("std");
const zstd = @import("zigeffect_std");
const kernel = zstd.fx.kernel;

const TodoRepository = kernel.Service("todo/Repository", RepositoryApi);
const TodoService = kernel.Service("todo/Service", TodoApi);

const RepositoryLive = kernel.Layer.scoped(
    TodoRepository,
    ConnectError,
    .{},
    acquireRepository,
    releaseRepository,
);
const TodoLive = kernel.Layer.sync(
    TodoService,
    .{TodoRepository},
    makeTodoService,
).provide(RepositoryLive);

var runtime = try zstd.ManagedRuntime(@TypeOf(TodoLive)).make(
    allocator,
    io,
    project_root,
    TodoLive,
    .{},
);
defer runtime.deinit();

try runtime.run(serve().named("todo.serve"));
try runtime.shutdown();
```

The business service does not know a causal store exists. The runtime records
the effect/service/scope path; the HTTP, gRPC and repository adapters record
their boundaries automatically. Stable effect and service names provide domain
meaning without mirrored `recordCausal` calls.

When a particular business identity must be queryable across that structure,
scope the business effect with a typed marker:

```zig
const ProductId = zstd.Lineage.Key([]const u8, .{
    .name = "commerce.product.id",
    .privacy = .internal,
    .propagation = .distributed,
    .export_policy = .otel,
});

try runtime.run(createOrder(command).track(ProductId, command.product_id));
```

This is the only application annotation. It declares that a value has domain
identity; it does not manipulate a store, graph, span or header. The runtime
projects the value to an opaque project-scoped reference, carries it through
effects and fibers, persists it in NenDB, propagates it through standard gRPC
adapters, and exports it to OTEL only when the key opts in. See
[typed data lineage](typed-data-lineage.md).

For infrastructure applications the same rule becomes:

```zig
const live = Ziac.Application.layer(.{
    .stack = &stack,
    .state = &state,
    .providers = providers,
});
var runtime = try zstd.ManagedRuntime(@TypeOf(live)).make(
    allocator,
    io,
    project_root,
    live,
    .{},
);
try Ziac.Application.run(&runtime);
```

Ziac's reusable adapters produce the queryable chain `plan -> resource
operation -> provider RPC -> retry/LRO -> state commit`. The explicit state
capability is infrastructure authority, not observability plumbing.

## Semantic facts

Do not mirror facts the runtime or a reusable adapter already knows. In
particular, application code must not manually record run/effect completion,
service lookup, layer startup, request lifecycle, transport attempts, retry
decisions, workflow journal appends, statechart transitions or Ziac provider
operations.

When genuinely application-specific meaning cannot be derived from a stable
effect, service or adapter operation, expose it through a narrow typed domain
event service implemented by the platform layer. Keep that service about the
domain (`OrderEvents.orderAccepted`), not about storage (`CausalStore.record`).
The live adapter adds bounded, redacted semantic references through the
runtime recorder; tests may replace it with a deterministic fake.

## Runtime configuration

Applications tune retention and sampling through managed-runtime options:

```zig
const options = zstd.CausalRuntime.Options{
    .causal_options = .{
        .max_events = 4096,
        .max_event_string_bytes = 512,
    },
};
```

Applications do not call `CausalStore.init*`, `attachBackend`,
`withCausalStore`, `ctx.recordCausal`, `CausalJournalStore`, or
`recordDecisionCausal`. Those APIs remain available to runtime internals,
adapter conformance tests and low-level embedded hosts.

## Testing exception

Deterministic acceptance tests may inject `context.causalStore()` exactly once
at the canonical root runtime. This keeps assertions and the durable project
graph on the same execution:

```zig
var runtime = try zstd.ManagedRuntime(@TypeOf(MainLayer)).make(
    std.testing.allocator,
    std.testing.io,
    std.Io.Dir.cwd(),
    MainLayer,
    .{ .causal_store = context.causalStore() },
);
try runtime.run(program);
try context.mapCausalEventIds(&runtime);
try runtime.shutdown();
try context.publish(std.testing.io, std.Io.Dir.cwd(), 1);
```

This is proof-harness injection, not application wiring. Focused framework
tests may also construct stores directly to test retention, redaction,
sampling, backends or causal algorithms.

## Agent rule

When an agent sees causal plumbing in an application or provider entry point,
it should move structural recording into the runtime and domain/protocol
recording into the reusable owning adapter. It must preserve test-only
injection and low-level framework conformance fixtures.

See the business-only gRPC example in
[`apps/todo-grpc-backend`](../../../apps/todo-grpc-backend/README.md), the Ziac
composition in [`packages/ziac`](../../ziac/README.md), and the general
[compositional application guide](compositional-applications.md).
