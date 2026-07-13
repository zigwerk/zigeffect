# ZigEffect gRPC Cloud Run + Connect Implementation Plan

**Goal:** Promote `zigeffect-grpc` from a raw-byte production candidate to the
primary generated, operational backend transport for Zig Cloud Run services and
Solid Connect clients.

## 1. Contract Toolchain

- [x] Pin Zig 0.16-compatible `Arwalk/zig-protobuf` and record its MIT notice.
- [x] Add a representative proto3 service with all four RPC shapes.
- [x] Add deterministic Zig generation and generated typed message/service tests.
- [x] Add Buf v2 lint/breaking/Protobuf-ES configuration and Solid Query helpers.

## 2. Typed Zig Adapters

- [x] Add typed codec/service adapter contracts above `zstd.Grpc` byte payloads.
- [x] Generate or expose typed unary client stubs and server registration.
- [x] Prove generated clients interoperate with generated handlers.

## 3. Production Server Supervisor

- [x] Add failing lifecycle/concurrency/resource-limit tests.
- [x] Implement bounded concurrent accept, active-socket tracking and reports.
- [x] Implement readiness, graceful GOAWAY drain and forced shutdown.
- [x] Add Cloud Run `$PORT`, h2c and container entrypoint support.

## 4. Persistent Channels

- [x] Add failing reuse/reconnect/keepalive/pool-exhaustion tests.
- [x] Implement persistent HTTP/2 session ownership and automatic reconnect.
- [x] Implement bounded channel pool, idempotent retry and metrics snapshots.

## 5. Incremental Streams

- [x] Add byte-stream reader/writer and bounded backpressure contracts.
- [x] Drive DATA fragments into message readers before request EOS.
- [x] Stream handler output without assembling the whole response.
- [x] Prove ordering and capacity-one pause/resume backpressure.
- [x] Emit non-OK incremental status as canonical trailing metadata.
- [x] Preserve server streams through request half-close and wake Health Watch on cancellation/deadline.

## 6. Compression

- [x] Add failing identity/gzip/deflate and adversarial expansion tests.
- [x] Implement per-message gzip/deflate and bounded decompression.
- [x] Advertise only verified encodings and reject invalid negotiation.

## 7. Middleware And Standard Services

- [x] Add composable server interceptors and typed call context.
- [x] Add bearer authentication policy and secret-redaction tests.
- [x] Add gRPC health Check/Watch and reflection v1 from the descriptor set.
- [x] Add trace-context validation and measured in-process metrics.
- [x] Add client interceptors, IAP verification, live Health Watch, OTLP export, and causal boundary facts.

## 8. Connect + Solid

- [x] Add Connect unary and streaming protocol codecs and error mappings.
- [x] Add explicit CORS/preflight policy.
- [x] Run a generated Connect-ES v2 client against the Zig server.
- [x] Document `@tanstack/solid-query` integration with generated descriptors.

## 9. Linux, Cloud Run And Adversarial Qualification

- [x] Add native Linux amd64/arm64 compile/test/container CI gates.
- [x] Add Cloud Run h2c container smoke and deployment configuration.
- [x] Add scheduled repeated tests, a 256-call/32-worker container load smoke, malformed HTTP/2 peer coverage, and atomic certificate rotation.
- [x] Add a 15-minute scheduled soak plus repeated malformed-frame and certificate-rotation campaigns.
- [x] Run package, std, Ziac, migration, hygiene, macOS and native Linux ARM64 receipt gates.
- [x] Bound the live stream registry, advertise the HTTP/2 stream limit, and qualify sustained RSS after the soak exposed linear retention.
- [ ] Run the committed GitHub native Linux amd64/arm64 matrix and scheduled campaign.
- [ ] Write a new live conformance receipt and promote maturity only if complete.
