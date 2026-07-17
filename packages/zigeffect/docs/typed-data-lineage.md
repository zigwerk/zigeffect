# Typed data lineage

Typed lineage is the application-facing marker for a domain identity whose
causal journey matters: a product ID, order ID, tenant ID, workflow ID or
another stable business reference. The application names the identity and
scopes an effect with it. ZigEffect performs the recording, fiber inheritance,
graph persistence, gRPC propagation and optional OTEL export automatically.

This is not manual causal instrumentation. The one explicit
`.track(Key, value)` call tells the runtime which value has business identity;
the runtime cannot safely infer that from an arbitrary string or integer.

## Declare and attach a key

```zig
const zstd = @import("zigeffect_std");

const ProductId = zstd.Lineage.Key([]const u8, .{
    .name = "commerce.product.id",
    .privacy = .internal,
    .propagation = .distributed,
    .export_policy = .otel,
});

const OrderId = zstd.Lineage.Key([]const u8, .{
    .name = "commerce.order.id",
    .privacy = .internal,
    .propagation = .distributed,
    .export_policy = .graph_only,
});

const program = createOrder(command)
    .track(ProductId, command.product_id)
    .track(OrderId, command.order_id)
    .named("orders.create");

const result = try runtime.run(program);
```

Everything inside the tracked scope, including service lookups, nested effects,
scoped resources and child fibers, carries both opaque references. Overlapping
keys express an association without adding an application event: agents can see
that this product and order participated in the same causal slice.

Register effect-owned resources through `ctx.addFinalizerFor(...)` (or its
fallible/exit variants). This is the normal scoped-resource API, not causal
instrumentation: it captures the current immutable effect context at
acquisition so finalization retains the right IDs after the effect returns.
The capture is per resource, so sibling or concurrent fibers cannot leak their
tracked values into one another.

Use stable reverse-domain key names. A key name is observable metadata; do not
put a value, username, email address or secret in it. Supported values are byte
slices and byte arrays, integers, booleans and enums.

## Privacy and export policy

| Privacy | Project identity required | Intended use |
|---|---:|---|
| `public` | no | identifiers already safe to correlate across projects |
| `internal` | yes | ordinary private business identifiers |
| `personal` | yes | data-subject identifiers requiring the strictest policy |

`internal` and `personal` values are projected with the managed runtime's
project identity. The graph, OTEL records and W3C baggage contain only a stable
key ID and a project-scoped 126-bit value fingerprint. The source value is never
stored in causal events. Personal keys are compile-time restricted to
`graph_only`.

A fingerprint is not encryption or anonymization. Low-entropy values can be
guessed by a party that already has graph access. Prefer high-entropy immutable
IDs; map usernames, email addresses and similar data to a protected stable
subject ID before tracking. Keep graph and lookup endpoints authenticated and
authorized even when no raw value is stored.

Propagation and export are independent:

- `fiber` remains inside the process; `distributed` crosses trusted gRPC
  boundaries in the reserved `zigeffect-lineage` W3C baggage member.
- `graph_only` remains in the embedded graph; `otel` also emits fixed indexed
  `zigeffect.lineage.*` attributes.

The context is allocation-free and bounded to eight active references. Child
scopes take priority when the same key is rebound. Truncation is recorded and
exported; it is never silently presented as complete evidence.

## Query a complete causal slice

An authorized agent endpoint converts the user-supplied lookup value into the
same opaque reference, then asks the runtime for bounded durable pages:

```zig
const reference = try runtime.lineageReference(ProductId, requested_product_id);
const page = try runtime.graphLineageJsonAlloc(
    allocator,
    reference,
    after_durable_event_id,
    128, // matches returned
    2048, // records scanned
);
defer allocator.free(page);
```

The result uses schema `zigeffect.causal.local-graph-lineage.v1` and includes
`scanned`, `matched`, `truncated` and `next_after_event_id`. Pagination advances
over scanned durable records, so sparse searches always make progress. Returned
records preserve their parent IDs, trace context, fiber/scope IDs and other
lineage keys; graph path and child queries can then reconstruct the wider flow.

Do not expose an unrestricted raw-value lookup endpoint. Authenticate and
authorize the domain lookup first, compute the reference inside the application,
and return only the evidence that caller is allowed to inspect.

## Transport behavior

`zstd.Grpc.call` automatically adds distributed references to outbound baggage.
Generated ZigEffect gRPC handlers parse the reserved member and install the
resulting causal context before the handler effect runs. The handler, services,
child fibers and downstream calls therefore remain correlated without accepting
lineage parameters in business APIs. Malformed or duplicate reserved baggage
fails closed and is omitted; raw metadata and raw identifiers are not recorded.

## Testing

Tests should track a known value through the real effect, inspect the causal
snapshot or durable graph by its computed reference, and assert that the source
value is absent from serialized evidence. Direct `CausalStore` construction is
still limited to framework conformance tests; application acceptance tests use
the one managed runtime and its controlled `TestContext` injection.

See [runtime-owned causal applications](runtime-owned-causal-applications.md)
for the ownership boundary and [gRPC and Cloud Run](grpc-cloud-run.md) for the
transport architecture.
