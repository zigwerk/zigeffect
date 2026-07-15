# ZigEffect gRPC Production Architecture

## Objective

Make `zigeffect-grpc` the primary typed backend communication stack for native
Zig services on Google Cloud Run and for Solid applications using Connect RPC
and TanStack Query. A single checked-in Protobuf schema is the contract source
for Zig service/client bindings and Protobuf-ES browser bindings.

This milestone replaces the earlier transport-only production-candidate claim
with an operational contract. It must not advertise general availability until
the target Linux/Cloud Run and Connect interoperability evidence is complete.

## Deployment Shape

```text
Solid + @tanstack/solid-query
  -> Connect-ES v2 transport (Connect protocol, binary Protobuf)
  -> Google HTTPS / Cloud Run ingress
  -> cleartext HTTP/2 (h2c) container port from $PORT
  -> ZigEffect multi-protocol host
       -> Connect unary/server-streaming routes
       -> native gRPC unary/client/server/bidi routes
       -> typed generated Zig service bindings
       -> ZigEffect effects, layers, tracing, metrics, auth and causal facts

Zig Cloud Run service
  -> pooled persistent native gRPC channel
  -> another Zig Cloud Run service
```

Cloud Run terminates TLS. The container listens on `0.0.0.0:$PORT` without a
certificate and accepts HTTP/2 prior knowledge. Direct non-Cloud-Run deployments
may still enable the existing peer-verified OpenSSL TLS mode.

## Contract And Code Generation

- Adopt the MIT-licensed `Arwalk/zig-protobuf` package pinned to an immutable
  Zig-0.16-compatible revision. It owns proto3 binary encoding/decoding and
  generated message/service types; ZigEffect owns transport adapters and
  effect integration.
- `RunProtocStep` downloads a pinned `protoc` when no local compiler is supplied.
- Generated Zig bindings are build artifacts or deliberately checked-in output;
  applications never hand-write wire codecs.
- Buf v2 configuration generates Protobuf-ES v2 service/message descriptors for
  Solid clients. `buf lint` and `buf breaking` are required schema gates.
- Generated Zig adapters expose typed unary and streaming clients plus typed
  registration helpers over `zstd.Grpc`.
- Reflection consumes the same descriptor set used by generation, preventing
  schema/runtime drift.

## Server Host

The production host owns:

- a supervised, bounded accept loop with a fixed maximum of active connections;
- one isolated connection execution context per accepted socket;
- readiness only after listener, registries and interceptors are installed;
- graceful drain: stop accepting, send GOAWAY, finish accepted streams until a
  deadline, then interrupt remaining sockets;
- configurable limits for connections, streams, headers, messages, buffered
  bytes, handler duration, idle time, connection age and shutdown duration;
- Cloud Run `$PORT` parsing and `0.0.0.0` binding;
- standard gRPC health `Check` and `Watch`, server reflection v1, and a minimal
  HTTP-compatible readiness response for platform probes;
- structured reports without payloads, credentials or metadata values.

The active-stream registry is bounded by the advertised HTTP/2 concurrent
stream limit and stores only live streams. It must not retain entries,
tombstones, or per-stream buffers after close. Long-running qualification
samples container memory after warm-up and rejects sustained growth above the
configured budget.

Handlers run through interceptors. Interceptors can reject before application
execution, enrich context, and observe completion. Built-ins cover bearer/IAP
authentication policy, request IDs, trace-context propagation, metrics and
redacted causal facts.

## Client Channels

A `ChannelPool` owns bounded persistent HTTP/2 sessions. Calls select a healthy
session, reuse it, and reconnect with capped exponential backoff after GOAWAY or
transport failure. It supports:

- configurable pool size and maximum concurrent streams;
- HTTP/2 PING keepalive with server-safe defaults;
- explicit deadlines and cancellation;
- retry only for idempotent calls and failures known not to have completed;
- connection generation, readiness, in-flight and reconnect metrics;
- graceful close and deterministic fake clock/backoff testing.

Each persistent session supports simultaneous ordinary calls up to its bounded
concurrent-stream limit. A single pump owner serializes nghttp2/OpenSSL access
while independent callers enqueue streams and wait concurrently; the live test
must prove overlapping streams on one connection. Keepalive PINGs count only
after a matching peer ACK and time out a dead channel.

## Incremental Streaming

The byte-stream API uses bounded reader/writer interfaces instead of slices of
all messages. Each message is framed independently. The reader decodes
fragmented DATA incrementally; the writer blocks or fails when its bounded
queue is full, providing backpressure. Cancellation and deadlines close both
directions and wake blocked producers/consumers. Buffered compatibility helpers
remain available but are not the production streaming primitive.

## Compression

Identity, gzip and deflate are implemented per message with independent
compression contexts. Negotiation is fail-closed:

- only implemented encodings are advertised;
- a compressed flag without a declared supported encoding is rejected;
- decompressed output is bounded independently of compressed input;
- compression bombs, malformed payloads and expansion-ratio violations are
  typed resource-exhaustion or internal failures.

## Connect Protocol

The same generated service registry serves Connect alongside gRPC:

- unary binary Protobuf and JSON-compatible error envelopes;
- streaming envelopes and end-stream responses;
- POST routing at `/{package.Service}/{Method}`;
- `connect-timeout-ms`, metadata, compression and canonical Connect error/HTTP
  mappings;
- CORS preflight with an explicit origin/header/method policy;
- server streaming for browser clients; client and bidirectional streaming are
  available when the client/runtime transport supports them.

Solid integration is framework-native: `@connectrpc/connect-web` provides the
v2 transport and generated service descriptors; `@tanstack/solid-query` owns
query lifecycle. The React-only `@connectrpc/connect-query` provider/hooks are
not used. Shared helpers produce stable query keys and unary query functions.

## Verification And Promotion

Required deterministic evidence:

- generated proto3 scalar, enum, nested, repeated, map, optional, oneof and
  unknown-field round trips;
- generated unary and all streaming-shape adapters;
- bounded concurrent accept, readiness, drain and forced shutdown;
- pool reuse, reconnect, GOAWAY, keepalive, idempotent retry and exhaustion;
- incremental fragmentation, ordering, backpressure, cancellation and bounds;
- gzip/deflate round trips and malformed/bomb rejection;
- auth/interceptor ordering, health, reflection, trace and metric redaction;
- Connect unary and streaming protocol vectors and CORS.

Required live evidence:

- Python or Go native gRPC in both directions;
- Connect-ES v2 client against the Zig server;
- Linux amd64 container build and execution using Cloud Run's h2c contract;
- Linux arm64 compile and container smoke test where the runner supports it;
- concurrent load, bounded soak, malformed peers and certificate rotation;
- zero leaks, logged errors or pending tests in Testing v2 receipts.

Promotion to `production` requires an unexpired checked-in conformance receipt
covering the deployment target. ARM64 macOS evidence alone remains
`production_candidate`.
