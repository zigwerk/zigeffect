# ZigEffect Durable Causal Application Runtime

Date: 2026-07-15
Status: implemented and verified

## Objective

Every normal ZigEffect application must persist the semantic events emitted by
its runtime into the Zig-native causal graph. Application code must not create a
parallel `CausalStore`, attach a backend, remember to flush it, or reconstruct
the application graph for an agent endpoint.

An authenticated external agent must be able to obtain the static service/layer
topology, live causal health, durable graph summary, and bounded recent
execution from one runtime query, then traverse durable event records and child
edges without reading application source.

## Architectural Boundary

ZigEffect has two runtime levels:

- `fx.kernel.ManagedRuntime` is the low-level, I/O-independent interpreter. It
  owns layer scope, service registry, topology, aspects, and a bounded in-memory
  causal recorder. It is appropriate for framework tests, embedded runtimes,
  and custom platform integrations.
- `zstd.ManagedRuntime` is the canonical application runtime. Its constructor
  requires the process `std.Io` and application root and always opens a bounded
  `zstd.CausalGraph.LocalDatabase`. It owns the database, NenDB graph adapter,
  causal store, and underlying kernel runtime as one resource.

This preserves dependency direction: `zigeffect` never imports
`zigeffect-std`, while the application runtime can compose the kernel with the
standard library's filesystem-backed graph database.

New applications, servers, workers, APIs, and generated scaffolds use
`zstd.ManagedRuntime`. Direct construction of `fx.kernel.ManagedRuntime` is an
explicit memory-only or custom-platform decision.

## Runtime Ownership

`zstd.ManagedRuntime.make(allocator, io, root, root_layer, options)` constructs,
in order:

1. a bounded `CausalGraph.LocalDatabase` containing the embedded NenDB
   struct-of-arrays topology and crash-safe property WAL;
2. a `CausalNendbStorageBackendState` targeting that database;
3. a bounded `CausalStore` with the graph backend attached;
4. the kernel managed runtime with that store installed as its mandatory causal
   aspect.

All state is heap-stable before pointers are connected. The returned runtime is
the only owner. A successful constructor transfers no cleanup obligations to
the caller beyond runtime shutdown.

Default bounds are explicit:

- 4,096 events retained in memory;
- 512 bytes per retained event string field;
- 65,536 durable graph records by default (generated projects explicitly use
  the manifest's 100,000-event bound);
- 64 MiB WAL;
- 512 KiB per graph record;
- synchronous durable writes;
- recovery of an incomplete final WAL record after interruption.

Structural events are never sampled. The same stream includes runtime, layer,
service, effect, scope, resource, fiber, standard-library operation, domain,
workflow, statechart, boundary, logging, metric, and tracing facts when those
facts are emitted through the runtime.

## Shutdown and Failure Semantics

`shutdown()` emits the kernel disposal lifecycle, flushes the graph backend,
checks both backend state and store-level failure counters, and then releases
the backend, store, database, and runtime in dependency order. A persistence or
flush failure makes `shutdown()` fail after cleanup.

`deinit()` is idempotent, performs the same cleanup, and is the best-effort
fallback for error paths. Process roots call `shutdown()` on the success path so
lost causal evidence cannot silently accompany a successful application exit.

Graph write failures do not mutate an effect's typed failure channel while it
is executing. They immediately mark runtime causal health as degraded and fail
the checked shutdown boundary.

## Live and Durable Queries

The application runtime exposes:

- `inspect` / `inspectJson` for the versioned kernel application snapshot;
- `causalHealth` for durable record/edge counts and backend failures;
- `graphSummaryJsonAlloc`;
- `graphRecordJsonAlloc(durable_event_id)`;
- `graphSinceJsonAlloc(durable_event_id, limit)`;
- `graphChildrenJsonAlloc(durable_event_id)`;
- `agentMapJsonAlloc`, the single discovery document.

The agent map contains the complete application snapshot, durable graph
summary, persistence health, ID-space descriptions, and supported follow-up
query kinds. It is transport-neutral. Guarded HTTP/gRPC/CLI adapters serialize
this runtime API instead of building a second schema.

`LocalDatabase` serializes live readers with writers. CLI snapshots remain
read-only consumers of the same WAL after or during application execution.

## Embedded NenDB decision

The official `Nen-Co/nen-db` repository is pinned at commit
`c990ef87d74e4dd7e77d3d8d1aafea2d57d12af7` under
`packages/references/nen-db`. Upstream currently targets Zig 0.15.1, has no
package manifest, and its filesystem/WAL code does not compile under the
repository's Zig 0.16 toolchain. The standard library therefore carries an
Apache-2.0, narrow Zig 0.16 port of the actual data-oriented node/edge core.

The port makes capacity allocator-owned rather than constructing the upstream
multi-megabyte fixed value on a thread stack, omits unused embedding and
placeholder property blocks from the hot topology, and keeps complete redacted
properties in ZigEffect's durable WAL. Runtime health publishes the exact
upstream commit and version. This is an embedded application dependency, never
a daemon, container, or Docker requirement.

## Generated Application Contract

Generated application and service roots:

1. compose one root layer;
2. construct one `zstd.ManagedRuntime`;
3. run the named root program and every endpoint through that runtime;
4. inspect or serve the runtime's agent map;
5. call checked `shutdown()` once.

They do not instantiate `LocalDatabase`, `CausalNendbStorageBackendState`, or
`CausalStore` directly. A small generated `causal_graph.zig` may retain only
application-specific graph options and artifact constants.

## Acceptance Contract

1. A canonical application persists startup, layer, service, effect, scope,
   domain, and shutdown events without manual causal wiring.
2. Runtime and durable graph counts agree when no retention bound is crossed.
3. Parent relationships are queryable by durable ID after runtime shutdown and
   process restart.
4. One agent-map query contains topology, recent causal execution, graph
   summary, health, and supported durable query kinds.
5. Concurrent live summary/event/children queries do not race graph writes.
6. A backend write or flush failure produces degraded health and a failing
   checked shutdown.
7. Generated application and service roots contain one application runtime and
   no manual store/backend attachment.
8. Kernel, standard-library, HTTP, CLI scaffold, and generated-project Testing
   v2 gates remain complete and green.

## Non-goals

- Replacing OTEL. OTEL receives the same runtime events through another aspect
  or fan-out exporter.
- A public unauthenticated agent endpoint. Transport adapters keep mandatory
  guards and response bounds.
- A global cross-service database. Service graphs join through boundary, trace,
  deployment, and domain references; aggregation remains a collector concern.
- Pretending a failed durable write succeeded. Degraded evidence remains
  explicit even when the domain effect itself completed.
