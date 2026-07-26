# zgroach

`zgroach` is the separate Zig RoachGraph compiler/toolchain package.

It depends on `zigeffect`, but `zigeffect` stays generic and RoachGraph-free.
The production TypeScript implementation remains at `packages/roachgraph`; this
package is the Zig port, and the two share a design rather than code.

## One query, several stores

The model is Prisma's: a query is written once against a neutral vocabulary, and
a *connector* answers it. What each connector can do is **declared**, so a query
a store cannot serve is a typed error naming the feature and the store — not an
empty result, and not a failure halfway through execution.

- `Plan` — the backend-neutral query plan, ported from roachgraph's IR. Pure
  data: build it anywhere, validate it on arrival, lower it wherever. A textual
  query language, if one is ever wanted, is a frontend that lowers to this type.
- `Backend` — the connector boundary and the `Capabilities` model. Capabilities
  are compile-time constants, because what a store can answer is a property of
  the connector, not of a connection.
- `backends.embedded` — the local causal graph: index columns for predicates,
  CSR adjacency for traversal, no daemon. It declares no vectors and no
  full-text, because a causal log stores execution, not documents.

A CockroachDB connector is the same plan lowered to SQL, which is what
`packages/roachgraph` already does.

```zig
var connector = zgroach.backends.embedded.Connector.init(&snapshot);
const store = connector.backend();

// Everything caused by any failure for one requirement.
var result = try store.execute(allocator, try zgroach.Plan.Builder
    .matching(&.{
        .{ .field = .requirement_id, .match = .{ .id = requirement } },
        .{ .field = .status, .match = .{ .text = "failure" } },
    })
    .traverse(&.{.{ .direction = .children, .max_depth = 16 }})
    .build());
defer result.deinit(allocator);
```

## Compiler scaffold

- `validateSource(ctx, source)`: validates non-empty source and records
  telemetry through `zigeffect` services.
- `validateCurrentSource()`: returns a `zigeffect.Effect` that reads
  `schema.path` from config, reads the source from the memory filesystem, and
  validates it.

Run tests:

```bash
bun run zgroach:test
```
