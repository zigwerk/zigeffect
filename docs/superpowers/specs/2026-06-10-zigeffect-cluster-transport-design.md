# zigeffect Cluster Transport Design

Date: 2026-06-10

Milestone: 34 - Transport Abstraction

## Goal

Separate cluster message ingress from the local file/shared-storage execution
model. Cluster callers should send entity messages through a `ClusterTransport`
contract instead of depending directly on `LocalClusterRouter`, while preserving
the durable storage semantics that Milestones 31-33 established.

This milestone introduces the protocol and deterministic local transports. It
does not introduce production networking, authentication, backpressure, socket
servers, or real async IO. Those remain later roadmap items, especially the
production multi-runner transport milestone.

## Existing Foundation

The current cluster runtime already provides:

- `MessageEnvelope`, `MessageEnvelopeKind`, message ids, correlation ids, and
  clone/deinit helpers.
- `MessageStorage` with in-memory and file-backed stores.
- `LocalClusterRouter`, which computes a shard id for any entity address and
  appends tell, request, or interrupt envelopes to shared durable storage.
- `LocalClusterRunner`, which owns leases, loads shards, processes stored
  messages, writes replies, and acknowledges durable messages.

The transport layer should reuse those pieces instead of inventing a separate
delivery path.

## Public Surface

Add `packages/zigeffect/src/cluster/transport.zig` and export it from:

- `fx.cluster.transport`
- `fx.cluster.ClusterTransport`
- `fx.cluster.ClusterTransportPolicy`
- `fx.cluster.ClusterTransportRequest`
- `fx.cluster.ClusterTransportResponse`
- `fx.cluster.ClusterTransportError`
- `fx.cluster.InProcessClusterTransport`
- `fx.cluster.LoopbackHttpClusterTransport`
- top-level `fx` aliases for the same public types that users need to build and
  test a cluster transport.

## Transport Contract

`ClusterTransport` is a small vtable:

```zig
pub const ClusterTransport = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        send: *const fn (*anyopaque, Allocator, ClusterTransportRequest) anyerror!ClusterTransportResponse,
    };
};
```

The contract is intentionally synchronous and deterministic for this milestone.
The request path can still report timeout and retry behavior through policy and
metadata, but it does not suspend on an async backend yet.

## Request Shape

`ClusterTransportRequest` contains:

- `kind: MessageEnvelopeKind`
- `address: EntityAddress`
- `payload_type_name: []const u8`
- `payload: []const u8`
- `redacted_detail: []const u8`
- `idempotency_key: ?[]const u8`
- `policy: ClusterTransportPolicy`

`kind` supports `.tell`, `.request`, and `.interrupt`. Reply, ack, and chunk
reply envelopes are not accepted as ingress messages.

If `idempotency_key` is null, the transport implementation derives a stable
implementation-specific key from its local sequence. If it is present, duplicate
submissions must be delegated to `MessageStorage.submit`, preserving the
existing durable duplicate behavior.

## Response Shape

`ClusterTransportResponse` contains:

- `shard_id: ShardId`
- `envelope: MessageEnvelope`
- `correlation_id: ?MessageCorrelationId`
- `duplicate: bool`
- `attempts: usize`
- `transport: ClusterTransportKind`

The response owns `envelope` and exposes `deinit(allocator)`.

## Policy

`ClusterTransportPolicy` contains:

- `timeout_ms: u64 = 30_000`
- `max_retries: usize = 0`

The first send attempt counts as attempt 1. `max_retries` controls additional
attempts after retryable transport failures. A policy with `timeout_ms == 0`
returns `error.TransportTimeout` before submitting to durable storage.

For deterministic tests, in-process transport normally succeeds on the first
attempt, while loopback HTTP transport can be configured to fail a fixed number
of attempts before accepting a request.

## In-Process Transport

`InProcessClusterTransport` wraps:

- allocator
- `MessageStorage`
- shard count
- next message sequence

It computes the shard id, builds a durable message submit request, and calls
`MessageStorage.submit`. This is the production-neutral local path for tests and
single-process cluster embeddings.

## Loopback HTTP Transport

`LoopbackHttpClusterTransport` is HTTP-shaped but in-process:

- The client serializes a transport request as an HTTP-like payload.
- A loopback handler parses the payload, submits to durable storage, and
  serializes a response.
- The client parses the response into `ClusterTransportResponse`.

No sockets are opened in this milestone. The value is the compatibility
boundary: the same bytes that would be sent by a future HTTP client/server are
validated today, while real network IO stays out of the deterministic runtime
until the later transport milestone.

## Wire Compatibility

Use stable JSON schemas:

- `zigeffect.cluster.transport.request.v1`
- `zigeffect.cluster.transport.response.v1`

The request JSON includes:

- `schema`
- `schema_version`
- `kind`
- `entity_type`
- `entity_id`
- `payload_type_name`
- `payload`
- `redacted_detail`
- `idempotency_key`
- `timeout_ms`
- `max_retries`

The response JSON includes:

- `schema`
- `schema_version`
- `shard_id`
- `kind`
- `message_id`
- `correlation_id`
- `entity_type`
- `entity_id`
- `idempotency_key`
- `payload_type_name`
- `payload`
- `redacted_detail`
- `duplicate`
- `attempts`
- `transport`

Unknown fields are ignored when parsing. Unknown schema names, unsupported
versions, malformed kinds, and unsupported ingress kinds produce transport
compatibility errors.

The HTTP-shaped codec uses deterministic text:

```text
POST /cluster/messages HTTP/1.1\r\n
Content-Type: application/json\r\n
Content-Length: <n>\r\n
\r\n
<json>
```

Responses use:

```text
HTTP/1.1 200 OK\r\n
Content-Type: application/json\r\n
Content-Length: <n>\r\n
\r\n
<json>
```

The parser requires the blank line separator and uses the body after it.

## Error Model

`ClusterTransportError` includes:

- `InvalidShardCount`
- `UnsupportedIngressKind`
- `TransportTimeout`
- `TransportUnavailable`
- `RetryLimitExceeded`
- `CorruptTransportMessage`
- `IncompatibleTransportSchema`

Allocator and storage errors pass through naturally.

## Acceptance Tests

Add `packages/zigeffect/test/cluster_transport_test.zig` covering:

1. Public exports exist.
2. Transport request and response JSON round-trip with schema/version checks.
3. In-process transport writes tell/request/interrupt messages to
   `MessageStorage`.
4. Duplicate idempotency keys round-trip through the transport as duplicate
   durable submissions.
5. Loopback HTTP transport serializes request bytes, parses them in the
   handler, stores the durable message, serializes a response, and parses it
   client-side.
6. Timeout policy rejects before storage mutation.
7. Retry policy retries deterministic transient loopback failures and reports
   attempt count.
8. The same cluster runner acceptance helper can send an ask through both
   in-process and loopback transports, tick the owning runner, and read the
   durable reply.

## Documentation

Update `packages/zigeffect/docs/architecture.md` to document
`cluster/transport.zig` as the deterministic transport boundary between routing
and future production networking.

Update the roadmap milestone when the full gate passes.

## Completion Definition

Milestone 34 is complete when cluster messages can be submitted through a
public `ClusterTransport` contract, both in-process and loopback HTTP
implementations use the same versioned wire codec, timeout/retry policies are
exercised by tests, and cluster runner acceptance passes through both
transports.
