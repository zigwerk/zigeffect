# ZigEffect gRPC Excellence Design

Date: 2026-07-13
Status: validated by user direction for implementation
Supersedes: the incomplete portions and over-broad completion claims in the
2026-07-12 owned-gRPC and Cloud Run + Connect milestones

## Objective

Make `zigeffect-grpc` a truthful, standards-conformant, typed, effect-native RPC
platform for Zig services on Google Cloud Run and Solid applications using
Connect-ES and TanStack Query. The implementation must first achieve protocol
and operational parity with maintained gRPC stacks, then exceed them through
bounded ownership, deterministic distributed-systems testing, causal evidence,
and a single generated contract across Zig and TypeScript.

The package may describe itself as the leading Zig-native gRPC implementation
only when every required gate in this design has a complete, content-bound
receipt. Feature names, capability descriptors, documentation, and receipts are
part of the public contract and must never claim behavior that a particular
client, channel, server, or protocol mode does not implement.

## Requirements

### GRPC-EX-1: Complete wire semantics

The native client and server preserve the complete gRPC call model:

- validated initial metadata and trailing metadata in both directions;
- ASCII and binary metadata, including repeated values and decoded size bounds;
- percent-encoded `grpc-message` and raw decoded `grpc-status-details-bin`;
- trailers-only success and failure responses;
- canonical HTTP status/content-type validation and mapping;
- server parsing and enforcement of `grpc-timeout`;
- cancellation propagation through `RST_STREAM`, handler scopes, and blocked
  stream readers/writers;
- correct cleartext/TLS `:scheme`, authority, method, path, `te`, encoding, and
  user-agent behavior;
- per-message compression negotiation with bounded decompression;
- header count and byte limits on both endpoints.

Acceptance requires byte-level vectors, loopback tests, and official external
interoperability cases. Response status messages, details, and metadata must be
observable from generated typed clients without falling back to raw headers.

### GRPC-EX-2: First-class typed generated APIs

A `.proto` contract generates:

- messages and enums with deterministic ownership helpers;
- immutable method descriptors containing fully-qualified paths, call shape,
  idempotency, and default policy;
- a typed client with unary, client-streaming, server-streaming, and
  bidirectional methods;
- typed client/server stream handles with send, receive, half-close,
  cancellation, headers, trailers, status, and scoped deinitialization;
- a typed server interface and one-call registration helper for all methods;
- typed status failures that preserve code, message, details, initial metadata,
  and trailing metadata;
- generated Connect-ES v2 descriptors plus Solid Query option helpers from the
  same schema and descriptor set.

Manual registration by service/method strings remains available as a low-level
escape hatch but is not the primary application API.

### GRPC-EX-3: Incremental persistent streaming

Persistent channels and pools carry all four call shapes. Streaming never
requires buffering the complete request or response. Consumption controls
HTTP/2 flow-control credit through bounded queues. Independent streams share a
connection safely while one pump serializes nghttp2/OpenSSL access.

Every blocked operation wakes on message availability, half-close, local or
remote cancellation, deadline, channel failure, or shutdown. Backpressure,
ordering, stream-local failure, and memory bounds are proven under concurrent
load.

### GRPC-EX-4: Production channel policy

The channel owns an inspectable connectivity state machine:

`idle -> connecting -> ready -> transient_failure -> shutdown`.

It supports:

- URI targets and pluggable resolvers, with DNS refresh and multiple addresses;
- `pick_first` and `round_robin` subchannel selection;
- wait-for-ready and bounded connection establishment;
- exponential reconnect backoff with deterministic jitter;
- JSON gRPC service config with per-service/per-method timeouts, retry,
  hedging, health, and load-balancing policy;
- transparent retry only before commitment, configured retry only for declared
  safe methods, retry throttling, and server pushback;
- bounded hedging for explicitly non-mutating calls;
- client-side Health Watch gating;
- keepalive and idle/age policies that respect peer limits;
- channel, subchannel, attempt, and picker snapshots.

Cloud Run does not require xDS for the first production release. The resolver,
picker, and service-config interfaces must permit a later xDS implementation
without changing generated service clients.

### GRPC-EX-5: Cloud Run and identity security

The security boundary supports:

- TLS 1.2/1.3 with hostname verification and ALPN;
- optional server and client mTLS with client-certificate verification;
- atomic certificate, trust-bundle, and identity rotation;
- composable channel credentials and per-call credentials;
- Google metadata-server/ADC ID-token acquisition for a configured audience,
  bounded caching, pre-expiry refresh, and single-flight refresh;
- generic OIDC JWT verification with issuer, audience, algorithm, lifetime,
  subject, and JWKS rotation policy;
- IAP ES256 verification as a specialization;
- fail-closed origin, metadata, and credential redaction rules;
- no credential material in receipts, telemetry, errors, or test fixtures.

### GRPC-EX-6: Production server policy

The supervised server adds per-method and global admission control, rate and
concurrency limits, overload/load-shedding status, connection idle and age
limits, keepalive enforcement, graceful GOAWAY, bounded shutdown, and
event-driven readiness/health transitions. Handler execution is scoped so no
fiber, thread, stream, or allocation escapes completion.

### GRPC-EX-7: Complete standard services and observability

- Health `Check` and event-driven live `Watch`, including shutdown transition.
- Reflection v1 and v1alpha with exact file/symbol/extension indexes.
- Channelz-compatible channel, subchannel, socket, server, and call snapshots.
- OpenTelemetry client/server spans, propagation (`traceparent`, `tracestate`,
  and opt-in baggage), attempt/call histograms, message-size metrics, connection
  metrics, retry events, bounded cardinality, exemplars where supported, and
  secure OTLP export through `zigeffect-otel`.
- Redacted causal facts at resolve, connect, pick, attempt, retry, stream,
  handler, status, drain, and shutdown boundaries.

### GRPC-EX-8: Connect and Solid conformance

The server passes the applicable stable Connect conformance suite as a server
and, where a Zig client is exposed, as a client. Binary Protobuf unary and
streaming requests support metadata, timeout, compression, end-stream errors,
and canonical error details. Browser-facing behavior is verified directly with
Connect-ES, not only through a hand-written unary smoke.

The generated web package provides stable query keys, query/mutation option
helpers, abort propagation, server-stream subscription helpers, SSR-safe
transport construction, and no React dependency.

### GRPC-EX-9: Evidence, fuzzing, and performance

Required evidence includes:

- all applicable official gRPC interoperability cases in both client and
  server roles;
- Connect conformance in supported protocol/HTTP/compression combinations;
- differential tests against grpc-go and at least Python or Java;
- deterministic malformed header/frame/message/metadata/property tests;
- coverage-guided fuzz targets for gRPC framing, metadata, HPACK-facing input,
  Connect envelopes, Protobuf decode boundaries, channel state, and service
  config;
- deterministic virtual-network and schedule exploration for drop, delay,
  duplicate, reorder, partition, GOAWAY, RST_STREAM, timeout, retry, hedging,
  shutdown, and certificate/JWKS rotation;
- Linux amd64 and arm64 native CI, container smoke, and checked-in receipts;
- a 24-hour scheduled soak with unary and every streaming shape, connection
  churn, fault injection, bounded memory, zero leaked work, and zero errors;
- reproducible benchmarks against grpc-go, tonic, and gRPC C++ reporting p50,
  p95, p99, throughput, CPU, allocations, resident memory, message size, and
  concurrency. Results are evidence, never hard-coded marketing claims.

## Architecture

### Portable protocol core

`zstd.Grpc` owns transport-independent call, metadata, status, policy,
generated-descriptor, deterministic fake, and effect contracts. It must not
depend on nghttp2, OpenSSL, a particular resolver, or real time.

### Native transport

`zigeffect-grpc` is decomposed into focused modules for wire metadata/status,
TLS, client connection, channel state/policy, server connection/supervisor,
incremental streams, Connect, standard services, credentials, observability,
and qualification. `root.zig` remains the stable facade instead of the sole
implementation unit.

### Generated layer

The protobuf generation pipeline emits message code and a ZigEffect-specific
service companion. Generated service code depends only on public `zstd.Grpc`
and `zigeffect-grpc` facades. The checked-in descriptor set drives reflection,
Connect-ES generation, schema lint/breaking gates, and conformance adapters.

### Effect-native differentiation

Calls are scoped effects with typed environment requirements and failures.
Channel and server lifecycle use inspectable statecharts. Deterministic clocks,
resolvers, credentials, backoff, and transports allow exact replay. Causal
receipts identify the failed boundary without payloads or secrets. This
evidence model is the primary advantage over mature language implementations.

## Truthful maturity model

- `experimental`: compiles but lacks live protocol evidence.
- `production_candidate`: deterministic suite and partial live interoperability
  pass, with every unsupported behavior explicitly listed.
- `production`: official applicable conformance, target-platform CI, security,
  and bounded soak receipts are checked in and unexpired.
- `leading`: production requirements plus public differential performance and
  deterministic fault/schedule evidence pass on the released source.

Maturity is assigned per capability: ephemeral unary client, persistent
channel, streaming channel, Connect server, native server, generated bindings,
and Cloud Run profile. One capable adapter must not promote every adapter.

## Non-goals for the first production release

- xDS, RLS, ORCA, and custom service-mesh control planes;
- native HTTP/3/QUIC gRPC transport;
- every optional compression codec supported by Connect;
- replacing Connect-ES in browsers.

The extension points must remain viable, but these do not block the Cloud Run
and Solid architecture selected by the user.

## Gap-closure acceptance addendum

The final release audit tightens three earlier acceptance claims:

- Buf compatibility is evidence only when the public schema passes against a
  checked-in immutable descriptor baseline and a deliberately breaking fixture
  is rejected by the same executable gate. A configured `FILE` rule alone is
  insufficient.
- A causal `stream` boundary is evidence only when a real native stream emits
  it through the production causal sink. Directly emitting every enum value in
  a unit test does not qualify.
- Connect client conformance requires a client-under-test process that speaks
  the conformance runner's length-delimited protocol and invokes the reference
  server through Zig-owned Connect client code. The checked-in feature matrix
  must declare only implemented protocol, HTTP, codec, compression, TLS, and
  stream combinations; all other combinations remain explicitly unsupported.

The schema-v2 candidate remains a working-tree candidate until its exact source
is committed and all external gates declared by the receipt have run on that
commit. Local regeneration must never promote that candidate to a release
receipt or imply that native Linux, GCP, or 24-hour evidence has run.
