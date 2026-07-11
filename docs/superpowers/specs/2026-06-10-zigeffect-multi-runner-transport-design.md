# zigeffect Multi-Runner Transport Design

Date: 2026-06-10

Milestone: 49 - Multi-Runner Transport

Status: superseded for production-readiness claims by
`docs/superpowers/specs/2026-07-11-zigeffect-production-application-platform-design.md`.
The delivered transports below are encoded in-process compatibility models,
not production network transports.

## Goal

Promote the existing deterministic cluster transport boundary into a
production-grade multi-runner transport layer. Runners must be able to submit
entity messages, workflow commands, interrupts, queue completions, and replies
through a byte protocol that carries authentication, trace context, envelope
limits, backpressure, retry evidence, and lifecycle metrics without bypassing
durable `MessageStorage`.

## Current Foundation

The current cluster stack already provides the pieces this milestone must reuse:

- `ClusterTransport`, `ClusterTransportRequest`, `ClusterTransportResponse`,
  request/response JSON schemas, and deterministic HTTP-shaped codecs.
- `InProcessClusterTransport` for single-process embeddings and
  `LoopbackHttpClusterTransport` for byte-boundary compatibility tests.
- `LocalClusterRunner` and `MessageStorage`, which remain the durable handoff
  point for all runner-to-runner submissions.
- `AsyncBackend` network waits, used by `registerClusterTransportWait` and
  `completeClusterTransportWait`.
- Lease epoch fencing from Milestone 48, which protects durable writes after a
  shard lease moves to another runner.
- Message envelope trace fields, chunk fields, and durable file JSON support.

The transport layer should stay small and storage-backed. It must not introduce
a second message queue or direct entity execution path.

## Public Surface

Extend `packages/zigeffect/src/cluster/transport.zig` with:

- `ClusterTransportKind.production_http`
- `ClusterTransportKind.production_socket`
- `ClusterTransportAuthMode`
- `ClusterTransportAuth`
- `ClusterTransportLimits`
- `ClusterTransportLifecycleState`
- `ClusterTransportMetricsSnapshot`
- `ClusterTransportFailureReport`
- `ProductionHttpClusterTransportOptions`
- `ProductionHttpClusterTransport`
- `ProductionSocketClusterTransportOptions`
- `ProductionSocketClusterTransport`
- `formatClusterTransportSocketFrame`
- `clusterTransportSocketFrameBody`
- `formatClusterTransportFailureReport`
- `chunkedClusterTransportRequest`

Export the new symbols through `fx.cluster` and top-level `fx`.

## Transport Kinds

`in_process` remains the direct local transport. `loopback_http` remains the
compatibility transport that exercises request/response HTTP bytes without
production policies.

`production_http` uses the same stable JSON request/response schema, wraps it in
HTTP-shaped bytes, enforces production policies, and returns
`transport = .production_http`.

`production_socket` uses the same stable JSON request/response schema, wraps it
in a deterministic socket frame, enforces production policies, and returns
`transport = .production_socket`.

The socket frame format is:

```text
ZIGFX/1 <body-byte-count>\n<body>
```

The frame parser rejects malformed prefixes, invalid lengths, and truncated
bodies with `error.CorruptTransportMessage`.

Both production transports route accepted messages to `MessageStorage.submit`
through the existing in-process handler. This preserves idempotency,
correlation ids, runner processing, workflow command execution, interrupt
delivery, queue completion delivery, and lease-guarded follow-up writes.

## Authentication

Authentication is intentionally hook-shaped and deterministic:

```zig
pub const ClusterTransportAuthMode = enum {
    none,
    bearer_token,
    shared_secret,
};

pub const ClusterTransportAuth = struct {
    mode: ClusterTransportAuthMode = .none,
    credential: ?[]const u8 = null,
};
```

Each request carries client auth. Each production transport has required auth.
Validation rules:

- `.none` accepts requests with `.none`.
- `.bearer_token` requires the same non-empty credential.
- `.shared_secret` requires the same non-empty credential.
- mismatch returns `error.TransportUnauthorized`.

Auth credentials are never copied into failure detail strings, metrics labels,
or redacted diagnostics. JSON serialization includes `auth_mode` and
`auth_credential` because this local deterministic protocol exercises the
actual byte boundary; failure reporting must only mention mode names.

## Limits, Backpressure, and Chunking

Add:

```zig
pub const ClusterTransportLimits = struct {
    max_envelope_bytes: usize = 1024 * 1024,
    max_chunk_bytes: usize = 64 * 1024,
    max_in_flight: usize = 1024,
};
```

Validation rules:

- `max_envelope_bytes == 0` returns `error.InvalidTransportLimits` at init.
- `max_chunk_bytes == 0` returns `error.InvalidTransportLimits` at init.
- `max_chunk_bytes > max_envelope_bytes` returns
  `error.InvalidTransportLimits` at init.
- `max_in_flight == 0` returns `error.InvalidTransportLimits` at init.
- request payload larger than `max_envelope_bytes` returns
  `error.TransportPayloadTooLarge` before durable storage mutation.
- `in_flight >= max_in_flight` returns `error.TransportBackpressured` before
  durable storage mutation.

`chunkedClusterTransportRequest` returns a cloned request with:

- `chunk_index = 0`
- `chunk_count = ceil(payload.len / max_chunk_bytes)` when chunking is needed
- unchanged payload bytes

The first milestone step stores payloads whole while propagating chunk metadata.
That gives large replies and queue completions a stable protocol signal while
preserving current durable storage semantics. A transport adapter can stream or
split bytes underneath the same request metadata without changing entity
handlers.

`ClusterTransportRequest` and `ClusterTransportResponse` gain `trace_id`,
`span_id`, `chunk_index`, and `chunk_count`, mirroring `MessageEnvelope`.
Accepted sends copy those fields into the durable envelope and response JSON.

## Retry Policy and Failure Evidence

Production transports reuse `ClusterTransportPolicy.max_retries`. The first
attempt is attempt `1`; retry budget adds additional attempts. Configurable
`failures_before_success` remains a deterministic test hook for transient
transport errors.

Errors are classified:

- `TransportUnavailable`, `TransportBackpressured`, and `TransportTimeout` are
  retryable.
- `TransportUnauthorized`, `TransportPayloadTooLarge`,
  `InvalidTransportLimits`, `CorruptTransportMessage`,
  `IncompatibleTransportSchema`, and `UnsupportedIngressKind` are terminal.
- `RetryLimitExceeded` is terminal and records the retryable cause that
  exhausted the budget.

Add:

```zig
pub const ClusterTransportFailureReport = struct {
    transport: ClusterTransportKind,
    retryable: bool,
    attempts: usize,
    error_name: []const u8,
    redacted_detail: []const u8 = "",
};
```

`formatClusterTransportFailureReport` produces a secret-free one-line report.
Each production transport stores its last failure report for tests and
diagnostics.

## Metrics and Lifecycle

Add:

```zig
pub const ClusterTransportLifecycleState = struct {
    started: bool = true,
    stopped: bool = false,
    sends: usize = 0,
    successes: usize = 0,
    failures: usize = 0,
    retries: usize = 0,
    backpressured: usize = 0,
    bytes_sent: usize = 0,
    bytes_received: usize = 0,
    in_flight: usize = 0,
    last_error_name: []const u8 = "",
};
```

Concrete transports expose:

- `snapshotMetrics() ClusterTransportMetricsSnapshot`
- `stop() void`

`send` on a stopped production transport returns `error.TransportUnavailable`
without durable storage mutation. Each accepted request increments `sends`,
tracks encoded bytes, increments `successes`, and decrements `in_flight` before
returning. Failure paths increment `failures`, update `last_error_name`, and
record a failure report.

## Compatibility Matrix

Acceptance tests must run the same cluster runner ask through:

- in-process transport
- loopback HTTP transport
- production HTTP transport
- production socket transport

The helper must prove:

- the send returns the expected transport kind;
- the owning runner processes the durable request;
- the reply is stored in `MessageStorage`;
- trace id and chunk metadata survive the transport boundary.

## Documentation

Update:

- `packages/zigeffect/docs/architecture.md`
- `packages/zigeffect/docs/effectts-parity.md`
- `packages/zigeffect/docs/usage.md`
- `docs/superpowers/plans/2026-06-07-zigeffect-durable-workflows-clustering-roadmap.md`

The docs should describe production HTTP and socket transports as durable,
storage-backed runner ingress paths with auth hooks, limit checks, backpressure,
retry evidence, metrics, and trace/chunk propagation.

## Completion Definition

Milestone 49 is complete when production HTTP and production socket transports
are public, auth-protected, limit-checked, backpressure-aware, retrying with
causal failure evidence, metrics-reporting, trace/chunk preserving, and covered
by runner compatibility tests across all four transport modes. The full release
gate must pass before moving to the next milestone.
