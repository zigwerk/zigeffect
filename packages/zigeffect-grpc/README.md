# zigeffect-grpc

Native gRPC-over-HTTP/2 client and server adapter for `zstd.Grpc`.

For the application architecture, contract-first workflow, service boundaries
and evidence rules, read the
[ZigEffect gRPC, Connect and Cloud Run guide](../zigeffect/docs/grpc-cloud-run.md).

The adapter uses nghttp2 for RFC-compliant HPACK, multiplexing, frame parsing,
and flow control, plus OpenSSL 3 for TLS 1.2/1.3 and ALPN `h2`. Capability
maturity is derived from the checked-in live interoperability receipt.

It supports unary, client-streaming, server-streaming, and bidirectional RPCs,
generated Protobuf messages and service declarations, persistent channels and
bounded pools, gzip/deflate message compression, Connect protocol requests,
CORS, client/server interceptors, IAP ES256/JWKS verification, live health
Watch, reflection v1/v1alpha, the canonical Channelz service, W3C trace
context, generic ES256/RS256 OIDC, metrics counters, and typed OTLP export over
plaintext collector links or peer-verified TLS. Incremental client
interceptors cover open, metadata injection, send/receive failures, final
status, cancellation, and reverse-order completion.
Queue-backed incremental gRPC handlers use nghttp2 pause/resume to propagate
backpressure through a fixed-capacity pipe and send final status in canonical
gRPC trailing metadata. The original bounded buffered streaming API remains
available for simpler handlers. Connect streaming uses the same bounded
incremental runtime, including cancellation, deadlines, initial metadata, and
canonical EndStream trailing metadata.

`NativeServer.serve` supervises a bounded accept pool. Readiness, active
connections, graceful drain, forced shutdown, and atomic TLS certificate
context rotation are explicit APIs. Deadlines and cancellation interrupt
blocked reads, and TLS clients verify both the certificate chain and hostname.
Persistent sessions multiplex ordinary concurrent calls and count keepalive
PINGs only after the matching peer ACK. Servers advertise and enforce a
bounded concurrent-stream limit, rotate aged HTTP/2 sessions with two-phase
GOAWAY, and retain storage only for live streams.

Maturity is assigned per public capability slice. Ephemeral and persistent
clients, the native server, incremental streaming, generated bindings,
Connect, and the Cloud Run container profile are `production_candidate` on the
content-bound v2 candidate receipt. They are not `production_verified`: native
Linux amd64, the 24-hour campaign, and a deployed GCP Cloud Run receipt remain
explicit promotion gates. A workflow definition is never treated as a passed
receipt.

```sh
zig build test
zig build external-test -Dpython=/path/to/python-with-grpcio
zig build official-interop-test -Dpython=/path/to/python-with-official-grpc-dependencies
zig build grpc-go-interop-test -Dgrpc-go-client=/path/to/grpc-go-client -Dgrpc-go-server=/path/to/grpc-go-server
zig build connect-test
zig build connect-conformance-test -Dconnect-conformance-runner=/path/to/pinned/connectconformance
zig build test --fuzz=100K
zig build install-cloud-run -Doptimize=ReleaseSafe
GRPC_ADVERSARIAL_ITERATIONS=1000 tests/run_adversarial_campaign.sh
python3 tests/source_digest.py ../..
```

The external gate runs all four RPC shapes in both directions between Zig and
Python gRPC, over plaintext and peer-verified TLS. The official gRPC gate runs
the 14 applicable portable interoperability cases in both client/server roles,
in both plaintext and TLS modes (56 role/mode cases total). The stable Connect
server gate runs all 120 cases selected by
`tests/connect-conformance/server-config.yaml`; the native Zig client gate runs
all 55 stable unary cases selected by
`tests/connect-conformance/client-config.yaml`. Neither uses skipped,
known-failing, or known-flaky cases. The client matrix explicitly supports
Connect/Protobuf/identity over plaintext HTTP/1.1 with unary cancellation,
deadlines, response metadata, trailer-prefixed metadata, details, and receive
limits. HTTP/2, TLS, GET, compression, and streaming remain excluded from that
native Connect client matrix (browser Connect-ES and native gRPC have separate
gates). CI pins the Connect runner to the revision recorded in
`THIRD_PARTY_NOTICES.md`.

## Generated contracts

```sh
cd packages/zigeffect-grpc
zig build gen-proto
zig build schema-compatibility-test
bunx @bufbuild/buf generate
```

`schema-compatibility-test` runs lint, checks the public schema against the
immutable `conformance/buf-v1.binpb` baseline, and proves the gate rejects a
fixture that deletes a published field.

Zig bindings are generated under `src/generated`; Protobuf-ES v2 bindings are
generated in `packages/zigeffect-grpc-web/src/gen`. The Solid package provides
a Connect-Web transport and `@tanstack/solid-query` option helpers.

## Application composition status

Native gRPC now uses the same canonical composition model as a generated
ZigEffect application:

- `Typed.generatedRoutesLayer` registers generated unary and streaming effects
  from an implementation service tag;
- `Typed.generatedClientLayer` supplies a generated client capability;
- `persistentChannelLayer`, `channelPoolLayer`, and `nativeServerLayer` acquire
  resources with canonical scoped layers;
- `StandardServices.layer` owns health and reflection registration; and
- one `zstd.ManagedRuntime` owns the process scope, runtime aspects, and durable
  embedded NenDB graph.

Generated method effects carry service requirements directly. The route layer
derives a requirements-limited runtime handle once, then runs every unary RPC
and complete streaming lifetime in a fresh child scope. Unary response encoding
occurs inside that scope, before handler finalizers run.

Channel, pool, and native-server layers automatically derive a recording-only
causal capability from their owning runtime. Resolve, connect, attempt,
handler, status, drain, and shutdown facts therefore enter the same graph as
the handler effects without an opt-in recorder path. Incoming `x-request-id`
and W3C `traceparent` values become bounded numeric correlation keys; their raw
header values, credentials, metadata, and payloads are not retained.

Manual `init`/`deinit` remains the driver API for focused adapter work.
`Typed.GeneratedDriverBinding` is the explicitly low-level generated adapter;
application code should use `Typed.generatedRoutesLayer`.

See [`docs/effect-native-roadmap.md`](docs/effect-native-roadmap.md) for the
completed composition gates and remaining platform qualification work.

## Performance

The latest schema-v2 ARM64 Docker optimization diagnostic held the container
images, driver, 1 KiB payload, 32 client workers, one persistent connection,
warm-up, and 50,000 measured calls constant. It measured ZigEffect at 11,792
RPC/s, 2.42 ms p50, 6.06 ms p99, and 7.0 server allocations per RPC. That is
96.6% of grpc-go in the same receipt and 13.4% higher throughput than Tonic.

This is candidate engineering evidence, not the checked-in release benchmark,
native Linux evidence, or deployed Cloud Run latency. Comparative claims must
come from one complete receipt; promotion still requires native Linux amd64,
the complete 24-hour mixed-shape campaign, and deployed GCP qualification on
committed source. See [`benchmarks/PERFORMANCE.md`](benchmarks/PERFORMANCE.md)
for the profile, optimization decisions, exact runtime table, and measurement
boundary.

## Cloud Run

The example in `examples/cloud_run` binds `0.0.0.0:$PORT`, serves h2c behind
Cloud Run's TLS termination, installs generated routes plus health,
reflection, and Channelz before readiness, and drains on SIGTERM. It is the
canonical one-root-layer, one-managed-runtime composition example. Every
handler and transport boundary writes to that runtime's application graph.
Build its multi-architecture image from the repository root and deploy with
Cloud Run end-to-end HTTP/2 enabled (`--use-http2`).

Cloud Run service-to-service ID tokens can be injected as sensitive
`authorization` metadata with `Middleware.AppendClientMetadata`. For services
behind IAP, `Iap.Verifier` strictly verifies the
`x-goog-iap-jwt-assertion` ES256 signature, issuer, audience, lifetime and
identity claims; supply a trusted HTTPS `Iap.JwksSource` to enable automatic key
refresh. `Oidc.Verifier` generalizes the same bounded rotating-JWKS policy to an
explicit ES256 or RS256 allowlist. `Otlp.exporterSink` connects typed gRPC
middleware spans, metrics, and logs to `zigeffect-otel`. Configure
`zigeffect_otel.Options.tls` with the verified server name and either platform
trust or a private CA for direct export; bounded custom headers and bearer
authentication are supported. Plain HTTP remains available only for an
explicitly trusted same-node collector.

The manual `zigeffect grpc gcp qualification` workflow builds immutable server
and probe images in Artifact Registry, deploys a private end-to-end HTTP/2
Cloud Run service, grants only the selected runtime service account invocation,
and executes a Cloud Run Job that obtains an audience-bound ID token from the
metadata server. The job verifies unary, client-streaming, server-streaming,
and bidirectional calls over platform-verified TLS and emits a retained receipt.
It optionally removes the temporary service and job; images remain immutable
qualification evidence. Merely defining this workflow does not satisfy the GCP
promotion gate.

## Qualification

The scheduled workflow runs a 1,000-iteration malformed-frame/certificate-
rotation campaign in one compiled test process and a 15-minute, 64-worker Cloud
Run container prequalification. This avoids thousands of redundant compiler
processes while preserving every defensive iteration. Its separate Testing v2
receipt is written to
`.zigeffect/tests/suites/zigeffect-grpc-adversarial-tests.json`. The load driver
distributes work across unary, client-streaming, server-streaming, and
bidirectional-streaming calls. For a short local container check with a JSON
receipt:

```sh
GRPC_LOAD_CALLS=1000 \
GRPC_LOAD_WORKERS=32 \
GRPC_SOAK_SECONDS=30 \
GRPC_MAX_MEMORY_GROWTH_BYTES=67108864 \
GRPC_LOAD_RECEIPT=/tmp/zigeffect-grpc-soak.json \
tests/run_cloud_run_container.sh /path/to/python-with-grpcio
```

The receipt includes cgroup memory samples after warm-up and fails when
steady-state growth exceeds the configured budget.

The release soak is deliberately a separate gate because a hosted CI workflow
cannot honestly substitute fifteen minutes for 24 hours. Run it on a durable
Linux qualification host:

```sh
GRPC_LOAD_RECEIPT=/evidence/zigeffect-grpc-24h.json \
tests/run_24h_soak.sh /path/to/python-with-grpcio
```

The wrapper rejects durations below 86,400 seconds and rejects receipts that
do not contain every call shape, bounded-memory evidence, and zero failures.

## Remaining promotion gates

The checked-in v2 candidate receipt binds the normalized implementation source
and records the completed official gRPC, grpc-go, Connect, Linux ARM64,
adversarial, fuzz, load, benchmark, browser-client, and downstream gates.
Promotion to `production_verified` still requires three artifacts on committed
source: native Linux amd64, the completed 24-hour mixed-shape campaign, and a
deployed GCP Cloud Run service-to-service run. The monthly 24-hour workflow is
self-contained: it repeats native amd64/arm64 preflight, official interop,
Connect, grpc-go, the 1,000-iteration defensive campaign, generated Solid
checks, five sequential soak segments, bounded memory, and aggregate receipt
validation.

Profile captures and the optimization record are in
`benchmarks/PERFORMANCE.md`; the full four-runtime receipt remains evidence,
not a marketing ranking.
