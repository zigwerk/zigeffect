# ZigEffect gRPC, Connect And Cloud Run

`zigeffect-grpc` is the primary typed communication adapter for ZigEffect
backend services. It serves native gRPC for trusted service-to-service calls and
Connect for SolidJS browser clients from one Protobuf contract.

## Status

The generated bindings, clients, server host, incremental streaming, Connect
adapter and Cloud Run profile are `production_candidate`. They are not yet
`production_verified`. The live schema-v2 candidate is source-bound and records
the completed tests without replacing the v1 receipt prematurely.

Promotion requires native Linux amd64, the 24-hour mixed-shape soak, and a
deployed GCP service-to-service qualification, all run against committed source.
See [`packages/zigeffect-grpc/README.md`](../../zigeffect-grpc/README.md) for the
current exact matrix and receipt paths.

## Deployment Shape

```text
SolidJS + TanStack Solid Query
  -> generated Connect/Protobuf client
  -> Cloud Run HTTPS ingress
  -> ZigEffect generated service binding
  -> typed Effect handler, layers and scoped resources

Zig service
  -> persistent bounded gRPC channel
  -> Zig service
```

Cloud Run terminates external TLS. The container listens on
`0.0.0.0:$PORT` using the Cloud Run h2c contract and drains on SIGTERM. Direct
deployments outside Cloud Run can use peer-verified TLS and ALPN `h2`.

## Contract-First Workflow

1. Change the checked-in `.proto` contract. Do not edit generated Zig or
   Protobuf-ES output as if it were a separate API.
2. Preserve field numbers and use Buf breaking compatibility before publishing
   a contract change.
3. Generate typed Zig messages, clients and server bindings plus the browser
   package.
4. Implement handlers through the public `zigeffect_std.Grpc` facade using
   typed effects, layers, scoped resources and typed failures.
5. Emit redacted causal facts at resolve, connect, pick, attempt, stream,
   handler and drain boundaries.
6. Add a deterministic failing test before changing behavior. Use
   `VirtualWorld`, `FaultMatrix` or `Schedules` when the contract involves
   retry, concurrency, network faults, rotation or shutdown.

```sh
cd packages/zigeffect-grpc
zig build gen-proto
zig build schema-compatibility-test
bunx @bufbuild/buf generate
zig build test -Doptimize=ReleaseSafe --summary all
```

After the Zig gate, inspect
`.zigeffect/tests/suites/zigeffect-grpc-tests.json`. A valid pass is complete,
has equal discovered and executed counts, and has zero failed/pending tests,
leaks and logged errors.

## Server Boundary

Use `NativeServer.serve` for a supervised bounded accept loop. Install typed
routes, interceptors, standard health, reflection and Channelz before reporting
readiness. Configure maximum connections, concurrent streams, header/message
sizes, queue capacity, deadlines, connection age and drain time explicitly.

Incremental handlers are the production streaming primitive. They use bounded
queues and nghttp2 pause/resume for backpressure, propagate cancellation and
deadlines, and place final gRPC status in canonical trailing metadata. Buffered
streaming helpers remain useful for deliberately small bounded exchanges.

## Client Boundary

Long-lived services should own a scoped persistent channel or channel pool.
Ordinary concurrent calls multiplex across bounded HTTP/2 capacity. Reconnect,
GOAWAY handling, keepalive and idempotent retry are automatic within declared
limits. Transparent retry is allowed only before the commitment tracker observes
response headers or messages.

Attach audience-bound Google identity as sensitive authorization metadata for
private Cloud Run calls. Use client interceptors for metadata, trace context,
attempt reporting and completion. Never record token or metadata values in a
causal fact, receipt or fixture.

## Browser Boundary

Browser applications use generated Protobuf-ES v2 descriptors from
`packages/zigeffect-grpc-web`, a Connect-Web transport and
`@tanstack/solid-query`. They do not open native gRPC channels or receive
service credentials. Stable query keys are derived from the generated service,
method and request contract.

The official native Connect client qualification currently covers its declared
unary HTTP/1.1 Protobuf/identity surface. HTTP/2, TLS, GET, compression and
streaming are explicit unsupported cases in that client matrix; browser
Connect-ES and native gRPC have separate applicable gates.

## Observability And Diagnosis

The middleware exports native OTLP histograms, attempt and connection
instruments, trace propagation links and exemplars where the OTLP/HTTP schema
supports them. Causal facts describe semantic boundaries without payloads or
secrets. When a deterministic or live test fails:

1. inspect the Testing v2 receipt and exact replay metadata;
2. find the first failed assertion or causal boundary;
3. preserve the seed, fault and schedule bounds;
4. repair the smallest responsible transport, handler or lifecycle boundary;
5. rerun the focused test and then the package gate.

Live qualification adds official Python and grpc-go interop in both directions,
Connect conformance, malformed-peer/certificate-rotation campaigns, fuzzing,
mixed-shape load, bounded-memory soak and container deployment evidence. These
receipts qualify only their recorded source, platform, duration and supported
cases.
