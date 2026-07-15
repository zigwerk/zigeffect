# ZigEffect-Owned gRPC Design

Date: 2026-07-12
Status: validated for implementation

## Goal

Create a repository-owned, Zig 0.16-native gRPC implementation derived from the
public-domain `ziglana/gRPC-zig` source material and integrated through
`zigeffect-std` services, effects, causal evidence, deterministic testing, and
capability qualification.

The resulting public contract is `zstd.Grpc`. Applications do not import the
upstream package and ZigEffect does not inherit its build, API, or compatibility
constraints.

## Provenance And License

The inspected upstream revision is
`ab34a7778193a309fc61117230643d2cbb5c2aaf`. It is released under the Unlicense.
`packages/zigeffect-std/THIRD_PARTY_NOTICES.md` records that provenance.

Upstream code is source material rather than an API compatibility target. The
rewrite keeps useful concepts such as length-prefixed messages, method
handlers, bounded message streams, health state, and compression selection.
Incorrect or incomplete behavior is replaced:

- HTTP/2 integers and gRPC message lengths use network byte order;
- reads and writes never assume a single socket operation completes a frame;
- method routing uses the canonical `/package.Service/Method` path;
- status is carried in response trailers, including trailers-only failures;
- metadata distinguishes ASCII and `-bin` values and bounds decoded size;
- authentication is ordinary metadata/interceptor policy, not a bespoke token;
- compression is per-message and negotiated through declared encodings;
- diagnostics and receipts never contain payloads, credentials, or raw metadata.

## Architecture

### `zstd.Grpc` protocol and Effect boundary

`packages/zigeffect-std/src/grpc/root.zig` owns the stable application-facing
contract:

- canonical status codes and typed status failures;
- bounded message framing and incremental multi-message decoding;
- ASCII and binary metadata validation;
- timeout encoding and parsing;
- request, response, and trailer validation;
- unary and streaming call shapes;
- erased client and server-handler interfaces;
- fake, scripted, and in-process deterministic providers;
- exact service/method registry routing;
- health service state;
- transport qualification and capability descriptors;
- Effect-native invocation with causal service-operation facts;
- redacted, bounded call receipts.

The core accepts protobuf-encoded payload bytes. Generated message types or
other codecs sit above this boundary, so gRPC transport correctness is not
coupled to a particular code generator.

### `zigeffect-grpc` native adapter

The optional native package owns operating-system networking and HTTP/2:

- client and server connection prefaces and settings;
- bounded frame parsing and serialization;
- HPACK request/response header blocks;
- stream state, multiplexing, flow control, cancellation, and GOAWAY handling;
- TLS/ALPN provider integration;
- connection reuse and graceful drain;
- unary, client-streaming, server-streaming, and bidirectional calls.

The adapter implements `zstd.Grpc.Transport`. It cannot advertise a qualified
production gRPC capability until live interoperability proves every required
feature. Until then, deterministic and local-development maturity remain
explicit.

## Ownership And Bounds

- Owned responses and metadata expose `deinit` methods.
- Every message, metadata block, frame, stream buffer, and connection has an
  explicit configurable bound.
- Incremental decoders retain only incomplete bounded input.
- Unknown status values, malformed frames, invalid metadata, missing trailers,
  unsupported compression, exhausted streams, and cancellation remain typed
  failures.
- Retry helpers never retry a call unless the method is explicitly declared
  idempotent and the failure is safe to retry.

## Security And Observability

- Authorization and binary metadata are marked sensitive by default.
- Receipts contain authority, service, method, call shape, status code, message
  counts, byte counts, duration, compression name, and retry classification.
- Receipts never contain payloads or metadata values.
- Causal facts use the stable `grpc.call` operation and redacted structural
  detail.
- Transport qualification fails closed for missing HTTP/2, TLS, trailers,
  deadlines, cancellation, multiplexing, reuse, flow control, message bounds,
  or redacted diagnostics.

## Deterministic Testing

The standard-library tests cover:

- known gRPC message framing vectors and fragmented decoding;
- malformed flags, lengths, bounds, metadata, timeouts, and trailers;
- all canonical status codes and retry classes;
- exact routing and unknown service/method failures;
- fake, scripted, and in-process unary calls;
- cancellation and deadline rejection;
- bounded streaming buffers and ordering;
- causal facts and secret-free receipts;
- fail-closed transport qualification.

Native adapter tests add byte-level HTTP/2 vectors, process-local client/server
interoperability, and external `grpcurl` or another maintained gRPC client
before any production claim.

## Acceptance Criteria

- `zstd.Grpc` is available from the one-import standard-library facade.
- Existing Ziac gRPC qualification code aliases the shared standard-library
  contract instead of maintaining a private copy.
- Standard-library tests and examples pass under Zig 0.16 with the Testing v2
  server runner and a complete suite receipt.
- A deterministic in-process call exercises the same request/status/metadata
  contract as a native transport.
- No upstream dependency is required to build `zigeffect-std`.
- Provenance is recorded and the implementation is maintained as ZigEffect
  code.
- Live native capability remains unqualified until the interoperability receipt
  exists; incomplete evidence is never presented as full compatibility.
