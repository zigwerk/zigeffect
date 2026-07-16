# ZigEffect Runtime Introspection and Causal Architecture

Date: 2026-07-15
Status: validated for implementation

## Objective

Make a composed ZigEffect application self-describing from its managed runtime.
An application or transport adapter must be able to expose one bounded JSON
snapshot that lets a human or agent discover the service graph, layer graph,
runtime health, recent execution history, and actionable causal findings without
reconstructing the application from source files or chaining report tools.

The runtime must emit causal lifecycle facts by default through the same aspect
pipeline used by logging, metrics, tracing, and supervision.

## Review Findings

### Official Effect architecture

The pinned official Effect implementation under `packages/references/effect`
uses these boundaries:

- `Context` keys define service contracts independently of implementations.
- `Layer` is a scoped, memoized recipe for constructing a service context.
- `ManagedRuntime` owns the root scope, a layer scope, the memo map, cached
  service context, child fibers, and all edge runners.
- Logging, metrics, and tracing are runtime services; OpenTelemetry is an
  adapter package rather than part of the core interpreter.
- Testing integration is a separate package and runs ordinary effects with
  controlled services.

Those boundaries are suitable for Zig. JavaScript-specific machinery such as
global symbols, object-identity maps, promises, and weak references is not.
ZigEffect should use comptime service sets, numeric layer identities, explicit
allocation, bounded storage, and value/vtable adapters.

### Current ZigEffect strengths

- The canonical kernel has typed service requirements and outputs.
- `Layer.provide`, `provideMerge`, `mergeAll`, and memoization express an
  application graph compositionally.
- `ManagedRuntime` builds the graph once and reuses it across endpoint runs.
- Causal events already cover services, layers, effects, scopes, resources,
  fibers, schedules, I/O, tests, workflows, statecharts, and clusters.
- Testing v2 receipts already treat causal findings, pending fibers, leaks,
  dropped events, sampling, and truncation as evidence rather than prose.
- Causal exporters exist for JSONL, graph history, live streams, and OTEL.

### Current architectural faults

1. The public package still exposes both the legacy environment-coupled engine
   and the canonical service/layer kernel. Tests and libraries therefore use
   two different dependency and runtime models.
2. Canonical `ManagedRuntime` only records causal facts when a caller supplies
   a `CausalStore`. A normal application silently loses the runtime model.
3. Layer construction emits events but discards the static topology: provided
   services, required services, provider relationships, root exposure, layer
   state, and memoized reuse cannot be queried directly.
4. `CausalStore` serializes writes but its read APIs require a quiescent barrier.
   That cannot safely back a live introspection endpoint.
5. Scope and resource facts bypass `RuntimeAspect`, so logger, metrics, tracer,
   supervisor, and causal observers do not see the same lifecycle.
6. One `CausalStore` accepts only one backend, which makes live attach, history,
   and OTEL compete for the same slot. Fan-out belongs behind one backend
   adapter, not in application code.
7. Agent tools mostly consume saved event artifacts and then recommend further
   report queries. They can explain observed execution, but cannot answer
   “what is the whole application?” because no runtime topology exists.
8. Testing v2 semantic receipts are stronger than production introspection but
   are attached to the legacy test environment. Canonical runtime evidence and
   test evidence do not yet share one snapshot contract.

## Chosen Design

### Runtime-owned causal recorder

Every canonical `ManagedRuntime` owns a bounded `CausalStore` unless a caller
injects one. Causal recording is always installed as a runtime aspect. Defaults
are conservative and explicit:

- maximum retained events: 4096;
- maximum bytes per event string: 512;
- structural events are never sampled;
- supplied stores remain caller-owned;
- runtime-owned stores are released with the managed runtime.

There is intentionally no “remember to enable causal” path for a normal app.
Export is optional; recording the application’s semantic execution is not.

### Runtime topology catalog

Layer construction populates a compact catalog owned by `RuntimeCore`:

- one entry per unique leaf layer identity;
- layer kind, name, build status, and memoized reuse count;
- provided service key and API type;
- declared service requirements;
- whether the service is exposed by the root layer.

Dependency edges are derived deterministically by joining a consumer’s required
service keys to provider layer outputs. Container-only `merge` and `provide`
nodes are not retained: they add no runtime capability and would inflate the
graph. The resulting graph preserves the meaningful service/layer topology.

The catalog is mutable only during startup. Queries clone the compact arrays so
the returned snapshot remains valid independently of the runtime.

### One application snapshot

`ManagedRuntime.inspect`, `RuntimeHandle.inspect`, and `inspectJson` expose the
same versioned snapshot:

- schema and runtime status;
- root layer type;
- service nodes;
- layer nodes;
- dependency edges;
- causal health counters;
- collapsed fiber state and actionable findings;
- a bounded tail of recent causal events.

The query accepts a maximum recent-event count. Structural topology is never
truncated by this event limit. The JSON output is transport-neutral; HTTP,
gRPC, CLI, tests, and an agent control plane must adapt this API instead of
reimplementing graph inference.

The HTTP adapter exposes this contract through an `ApplicationMapHandler` that
requires a `Guard` at construction time, accepts only one configured GET path,
and enforces a response-size bound. There is no unguarded constructor.

### Consistent live reads

`CausalStore.inspect` takes the store lock once and clones the event tail,
findings, and fiber states with counters from one logical instant. Existing
specialized queries remain available, but the application snapshot is the
preferred live read and does not require a quiescent barrier.

### Unified runtime lifecycle

Canonical scopes attach a runtime signal sink instead of writing directly to
the causal store. Scope open/close and resource acquire/finalize events enter
the same `RuntimeAspect` pipeline as run, effect, layer, service, and fiber
events. The causal aspect assigns lineage IDs; logger, metrics, tracing, and
custom observers receive the same semantic lifecycle.

The legacy `Scope.attachCausal` path remains only as a migration surface until
the legacy engine is removed.

### Exporters and packages

Core owns semantic event production and the in-memory model. Exporters remain
separate:

- `zigeffect-otel`: OTEL encoding/export;
- `zigeffect-grpc` / `zigeffect-http`: endpoint adapters;
- `zigeffect-std`: application lifecycle, testing, and common services;
- agent/CLI surfaces: consumers of the snapshot contract.

No new report-only tool is introduced. The existing causal query tool may later
accept persisted application snapshots, but runtime capability is implemented
under `src/` first.

## Testing Contract

The canonical kernel tests must prove:

1. causal recording works without explicitly supplying a store;
2. a composed graph reports hidden dependency services and exposed root
   services correctly;
3. shared layers appear once with memoized reuse recorded;
4. dependency edges map provider layer to consumer layer;
5. the single JSON query contains topology, health, findings, and recent events;
6. scope/resource facts reach custom aspects and installed observability;
7. bounded event retention and bounded query tails report completeness counters;
8. a reference server can serve its application map from its existing runtime
   handle without rebuilding or reproviding layers.

Testing v2 remains the runner for every artifact. The semantic test receipt will
adopt the application snapshot summary after the canonical test environment is
migrated; it must not create a second topology schema.

## Migration Direction

1. Land runtime-owned causal recording, topology, and introspection in the
   canonical kernel.
2. Make standard-library services and transport adapters consume only the
   canonical kernel and expose the shared snapshot contract.
3. Move Testing v2 `TestContext` onto a canonical `ManagedRuntime` and cite the
   snapshot in receipts.
4. Migrate gRPC, HTTP, Ziac, and scaffolds to one application layer plus one
   managed runtime entry point.
5. Remove the legacy `core.Context`, legacy `Runtime`, environment graph, and
   duplicate public aliases once their consumers have migrated.
6. Consolidate report tools around the runtime snapshot; delete report-about-
   report surfaces instead of extending them.

## Non-goals for this slice

- A public unauthenticated production endpoint. The HTTP adapter requires a
  guard; deployments still own the authentication policy and network exposure.
- A distributed global graph across services. Cross-service `boundary_id` and
  trace correlation remain the join keys; aggregation belongs to an agent
  control plane or collector.
- Replacing OTEL. Causal is a semantic runtime signal that can also be exported
  through OTEL.
