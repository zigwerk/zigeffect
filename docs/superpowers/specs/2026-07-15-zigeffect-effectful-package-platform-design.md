# ZigEffect Effectful Package Platform

Date: 2026-07-15
Status: validated by product direction

## Objective

The `zigeffect` CLI scaffold is the executable architecture contract for every
new application, service, library, package, and system. First-party framework
packages must expose the same public shape even when they predate the CLI:
stable services, typed effect descriptions, construction layers, deterministic
test layers, one process runtime, and causal evidence produced by execution.

Every deployable application owns exactly one `zstd.ManagedRuntime` and
therefore exactly one embedded NenDB causal graph. Libraries, the standard
library, gRPC, HTTP, database drivers, and other adapters never open a second
runtime or graph. Their effects execute inside the consuming application's
runtime so structural and semantic events share one lineage.

## Canonical development contract

New work begins with `zigeffect new`, `zigeffect add`, or `zigeffect generate`.
The generated manifest, compatibility record, requirements, acceptance checks,
test scenarios, public component facades, and Testing v2 runner are executable
intent rather than disposable boilerplate.

Application code uses only:

- `fx.kernel.Service` for stable dependency identities;
- `fx.kernel.Effect<Success, Failure, Requirements>` values for programs;
- `fx.kernel.Layer<Output, Error, Input>` constructors for implementations;
- `zstd.ManagedRuntime` once at a deployable process root; and
- `zstd.Testing` plus Testing v2 receipts for acceptance evidence.

`Service.Provider`, `ValueProvider`, `ServiceEnv`, `EffectEnv`, `Context(Env)`,
`LayerGraphEnv`, `LayerWithError`, `layerGraph`, `Runtime(Env)`, `ctx.runEffect`,
manual `CausalStore` attachment, and per-handler runtimes are migration-only
APIs. They are forbidden in generated code and in newly canonical package
surfaces.

## Package boundary

Pure codecs, protocol state machines, allocators, parsers, and data structures
remain ordinary Zig. Effect boundaries begin where an operation depends on an
external capability, owns a resource, can be substituted, crosses a service
boundary, or contributes semantic execution evidence.

A canonical library or adapter exports:

1. stable service tags whose APIs advertise operation names;
2. module-level effects that require only those tags;
3. live scoped layers and deterministic layers for the same tags;
4. typed, redacted failures;
5. no hidden runtime, graph, global registry, or initialized singleton; and
6. tests that run one unchanged program against live/fake layers and inspect
   causal evidence.

Construction dependencies belong to layer inputs. They do not leak into every
operation's requirements. App-scoped pools, listeners, channels, registries,
and exporters finalize once. Request, RPC, transaction, and stream resources
live in child run scopes.

## Repository conformance

The repository owns a machine-readable package policy and one architecture
gate. The gate inventories every first-party ZigEffect package and verifies:

- deployable examples and generated applications use one `zstd.ManagedRuntime`;
- library/package sources do not construct runtimes or causal stores;
- admitted canonical modules contain stable tags, effects, and layers;
- no forbidden legacy symbol is added outside an explicit migration allowlist;
- every `b.addTest` uses Testing v2 server mode; and
- CLI templates preserve the canonical application/library split.

The allowlist is a ratchet, not an approval. Each migrated module removes its
entries and lowers the repository count. New legacy references fail the gate.
Completion means the allowlist reaches zero and the compatibility APIs can be
deleted.

## Standard-library migration

The existing `FileSystem` and `Process` modules remain the implementation
oracles. Migration proceeds dependency-first:

1. runtime-default facades;
2. Env/Secrets/IDs and local data capabilities;
3. Queue/PubSub/Sink/Broker/ObjectStorage;
4. HTTP, SQL, and gRPC portable contracts;
5. CLI/Application/Agent/Statechart programs; and
6. deletion of the legacy environment kernel.

Each migrated module must pass the admission checklist in
`packages/zigeffect-std/docs/effect-native-roadmap.md`. A legacy behavior test
does not count as canonical migration evidence.

## Canonical gRPC architecture

Protocol codecs, protobuf messages, HTTP/2 state machines, native drivers,
bounded queues, and interop harnesses remain imperative below the boundary.
The public boundary is effectful:

- `zstd.Grpc.GrpcClient` is the portable client service and `Grpc.call` is its
  module-level unary effect;
- native persistent-channel and pool layers produce client resources and then
  derive the portable client service;
- unary, streaming, and incremental registries are stable scoped services;
- generated handler effects declare method requirement tags, never `Env`;
- generated route layers acquire the implementation service and registries,
  retain a requirements-limited `RuntimeHandle`, and register stable adapters;
- native server layers depend on completed route-set tags, registries, and
  configuration;
- `serve`, readiness, snapshot, drain, and shutdown are effects; and
- every RPC is interpreted through `RuntimeHandle.run`, producing one child
  scope and one causal subtree for the complete unary or streaming lifetime.

The Cloud Run example is a real generated-style application root: one root
layer, one managed runtime, effectful route/server lifecycle, checked shutdown,
and no manual causal objects. Browser `zigeffect-grpc-web` remains a generated
Connect/Protobuf client package rather than pretending to own a Zig runtime; it
propagates cancellation and correlation to the server-side causal graph.

## Test-driven causal development

Every migration begins with a failing deterministic test that asserts both
behavior and architecture. Tests prove service requirements, layer inputs and
outputs, memoized acquisition, reverse finalization, child-scope lifetime,
redacted boundary facts, graph persistence, and application-map visibility.

Before a change, agents retain the durable graph cursor and state the expected
causal delta. After the test, they query `graph since`, traverse relevant
children, and compare the actual graph with the counterfactual. A green value
assertion with missing, unhealthy, dropped, or unread causal evidence is not a
pass.

## Acceptance contract

1. CLI-generated deployable projects own one managed runtime and graph.
2. CLI-generated libraries/packages own neither and export composable services,
   effects, and layers.
3. Canonical package sources cannot add legacy environment APIs.
4. Portable gRPC client calls and generated server handlers are canonical
   effects with explicit tag requirements.
5. gRPC registries, channels, pools, and servers are scoped canonical layers.
6. The Cloud Run example uses one managed runtime and no legacy layer graph.
7. Native and browser contracts remain generated from `.proto` sources.
8. Testing v2, Buf, native/Connect interop, resource-bound, leak, causal, and
   generated-project gates remain complete and green.

## Non-goals

- Effect-wrapping pure codecs or per-frame transport internals.
- Giving libraries independent causal databases.
- Claiming browser TypeScript executes on the ZigEffect runtime.
- Preserving compatibility with the legacy environment kernel.
- Promoting gRPC production maturity without the existing Linux, soak, and GCP
  qualification evidence.
