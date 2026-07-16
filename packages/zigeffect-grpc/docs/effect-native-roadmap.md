# Native gRPC Canonical ZigEffect Roadmap

**Reviewed:** 2026-07-15
**Status:** canonical composition gates G0-G5 complete; qualification gates
G6-G7 remain active.

## Shipped architecture

| Boundary | Canonical API | Ownership |
| --- | --- | --- |
| Portable unary client | `zstd.Grpc.GrpcClient`, `clientLayer`, `call` | consuming application layer graph |
| Generated client | `Typed.GeneratedClientService`, `generatedClientLayer`, generated call effects | consuming application layer graph |
| Registries | `Typed.UnaryRegistry`, `StreamingRegistry`, `IncrementalRegistry` | scoped registry layers |
| Generated handlers | `Typed.generatedRoutesLayer` | generated route layer plus method requirements |
| Native client resources | `PersistentChannelService`, `ChannelPoolService` | scoped channel/pool layers |
| Native server | `NativeServerService`, `nativeServerLayer` | scoped server layer |
| Standard services | `StandardServices.Service`, `StandardServices.layer` | scoped health/reflection layer |
| Channelz | `NativeChannelzService`, `nativeChannelzLayer` | scoped server-inspection layer |
| Process interpreter | `zstd.ManagedRuntime` | exactly one per deployable application |
| Causal graph | embedded NenDB through the managed runtime | exactly one per deployable application |

Generated clients, server handlers, registries, channels, pools, and server
lifecycle APIs contain no application environment type. Libraries describe
effects and layers; they never construct a private process runtime or graph.

## Composition model

```text
domain/config layers
        |
registry layers ---> generated route layer ---> standard service layer
        |                    |                         |
        +--------------------+-------------------------+
                             |
                    native server layer
                             |
                   one zstd.ManagedRuntime
                             |
            child RuntimeHandle run per RPC/stream
                             |
              one durable application causal graph
```

`generatedRoutesLayer` computes the union of method requirement tags. It
resolves the implementation once during layer acquisition and derives a
requirements-limited runtime handle. Each unary request or full streaming
lifetime runs through that handle in a fresh child scope. Unary protobuf
encoding remains inside the effect so request-scoped finalizers cannot release
borrowed response storage before encoding completes.

## Automatic causal boundary integration

Every canonical persistent channel, channel pool, and native server layer
derives a recording-only capability from its owning runtime. There is no normal
application path that requires a caller to remember causal middleware.

Transport facts cover resolve, connect, pick, attempt, retry, stream, handler,
status, drain, and shutdown. Incoming `x-request-id` and valid W3C
`traceparent` headers are converted to bounded numeric `boundary_id`,
`trace_id`, and `span_id` values on both transport and generated handler facts.
Raw identifiers, authorities, metadata values, credentials, request payloads,
and response payloads are not retained.

The browser Connect package installs these headers automatically. Deterministic
factories are injectable for tests.

## Retained imperative driver boundary

Effects do not wrap tight protocol machinery merely for appearance. These stay
ordinary Zig below the capability boundary:

- protobuf encoding/decoding and generated message contracts;
- gRPC/Connect framing, compression, metadata and status mapping;
- HPACK, HTTP/2, nghttp2/OpenSSL callbacks and connection state machines;
- bounded queues, cancellation, deadlines, flow control and shutdown; and
- low-level manual driver APIs used by focused conformance and benchmark tests.

`Typed.GeneratedDriverBinding` is explicitly named as a low-level adapter.
Application code uses `generatedRoutesLayer`.

## Gate status

- **G0 — kernel admission:** complete. Stable runtime core, service registry,
  layer topology, memoization, child runtime handles, scopes and aspects.
- **G1 — canonical registries:** complete. Unary, streaming and incremental
  registries are stable scoped service layers.
- **G2 — generated handler/client effects:** complete. Requirements are tags,
  not environment types; generated route/client layers are public.
- **G3 — server layer and lifecycle effects:** complete. Native server,
  readiness, serve, drain and shutdown use canonical services/effects.
- **G4 — client layers:** complete. Persistent channel and pool are canonical
  scoped layers and can provide the portable client service.
- **G5 — Cloud Run root:** complete. The example has one root layer, one
  durable runtime, generated routes, health/reflection/Channelz and bounded SIGTERM
  drain.
- **G6 — scope and observability qualification:** in progress. Unary child
  scope ordering, stream lifetime, causal redaction and boundary correlation
  are covered. Complete OTLP/supervisor/deadline/cancellation qualification
  across the platform matrix remains.
- **G7 — interop and performance qualification:** in progress. Existing unit,
  Connect/browser, schema and Cloud Run build gates remain mandatory. Native
  Linux amd64/arm64 evidence, the complete 24-hour mixed-shape soak and deployed
  GCP qualification remain production-promotion gates.

## Verification

From the repository root:

```sh
bun run zigeffect:architecture:test
bun run zigeffect:grpc:test
```

The gRPC command runs the native Testing v2 suite, builds the canonical Cloud
Run example, checks schema compatibility, and runs browser client typechecking
and tests. The architecture guard rejects legacy environment-shaped APIs in
the canonical gRPC and standard-library gRPC surfaces and ratchets remaining
package migrations downward.
