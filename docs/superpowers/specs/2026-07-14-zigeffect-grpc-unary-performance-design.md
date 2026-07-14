# ZigEffect gRPC Unary Performance Design

Date: 2026-07-14
Status: validated for implementation

## Problem

The current ARM64 differential receipt reports 4,094 RPC/s for a 1 KiB unary
call at 32-way client concurrency, versus 6,296 for Tonic and 7,402 for
grpc-go. ZigEffect uses less measured server CPU per RPC and has a competitive
median latency, but it exhibits 40--48 ms maximum latency stalls, executes
ordinary unary handlers on the nghttp2 connection owner thread, performs
linear stream lookup in every server callback, duplicates request metadata,
and copies large protobuf payloads several times.

The current 400-call Docker Desktop benchmark is suitable for a comparative
smoke test but is too short to establish a stable optimization result.

## Goals

1. Eliminate avoidable TCP small-write stalls on native client and server
   sockets.
2. Keep nghttp2 session access single-threaded while allowing independent
   unary handlers on one HTTP/2 connection to execute concurrently.
3. Make callback stream lookup constant time.
4. Remove duplicate ownership and copying from the common identity-compressed,
   OK-status unary path.
5. Produce repeatable performance evidence with warm-up outside the measured
   interval, long or duration-based samples, repetitions, and connection and
   concurrency sweeps.
6. Preserve all existing protocol, conformance, resource-limit, cancellation,
   graceful-drain, TLS-rotation, middleware, and causal-observability behavior.

## Non-goals

- Replacing nghttp2, OpenSSL, protobuf generation, or the public ZigEffect gRPC
  facade.
- Weakening bounds, retry commitment rules, certificate validation, or
  malformed-peer defenses for benchmark results.
- Claiming a throughput target before the changed committed source is measured
  on native Linux.

## Design

### Low-latency TCP and output batching

Every connected TCP socket is configured with `TCP_NODELAY` before TLS or
HTTP/2 processing. Failure to apply an explicitly enabled low-latency option is
reported rather than silently ignored. The option is exposed in client and
server configuration and defaults to enabled for gRPC.

`nghttp2_session_mem_send` fragments produced by one flush cycle are copied
into a reusable, bounded connection send buffer and written as one logical
operation. A fragment larger than the buffer is written directly after the
buffer is drained. TLS continues to use `SSL_write`; plaintext may later use a
vectored transport, but the first implementation keeps one shared batching
policy and no new platform-specific ownership contract.

### Constant-time stream callback lookup

The first request header creates a `ServerStream`, installs it with
`nghttp2_session_set_stream_user_data`, and all subsequent header, data, frame,
and close callbacks retrieve that pointer with
`nghttp2_session_get_stream_user_data`. The bounded connection list remains the
owner and supports drain/lifecycle scans. User data is cleared before stream
destruction.

### Unary execution and nghttp2 ownership

The existing bounded handler executor becomes the shared server handler
executor and is created for every native server, not only when incremental
routes are installed. Incremental and unary work share the declared worker and
queue bounds.

The default worker count is selected from a Linux 4/8/16/32/64 sweep at the
target 32-way concurrency. Eight workers minimize queue contention for the
synchronous handler contract while remaining explicitly configurable for
services whose handlers block on external systems.

An ordinary native gRPC unary request is admitted after its END_STREAM frame.
The connection thread pins its `ServerStream`, schedules a job, and returns to
HTTP/2 processing. A worker performs request validation, metadata preparation,
middleware, protobuf decoding, handler invocation, and response encoding. It
stores an owned completion on the pinned stream, publishes completion with
release ordering, enqueues the stream ID, and signals the existing nonblocking
self-pipe.

Only the connection owner thread calls nghttp2. It consumes completions,
constructs canonical response headers/data/trailers, submits them, and flushes
the session. HTTP/2 stream close while a job is running marks the stream as
peer-closed but defers destruction. Connection teardown waits for every pinned
job before freeing stream or connection storage. Cancellation remains
cooperative at the handler boundary; completed output for a reset stream is
discarded.

Connect unary and buffered streaming remain on their current paths in the
first change because they have different envelope and final-status contracts.
They use the same socket, output, lookup, and allocation improvements.

### Header and metadata ownership

Reserved HTTP/2/gRPC headers are classified before storage and retained once
in their dedicated fields. Common header values use bounded inline storage in
the pinned stream object and spill to the allocator only when their declared
header bound exceeds the inline capacity. Only non-reserved application
metadata enters the owned metadata list.

The common response with no initial metadata uses fixed response header fields.
The common OK trailer uses fixed fields. Dynamic header blocks remain bounded
and owned for custom metadata and non-OK status.

### Unary payload ownership

Identity-compressed unary decoding returns a borrowed slice into the complete
request body after validating its five-byte frame. Compressed requests retain
owned decompression storage.

`Grpc.UnaryResponse` gains an ownership-transferring constructor. Typed
bindings move their encoded protobuf buffer into the response rather than
duplicating it. Response framing reserves the five-byte gRPC prefix in the
same owned allocation where possible; compressed responses retain the existing
bounded compression path.

Ownership remains explicit in `deinit`; borrowed request memory never escapes
the pinned stream lifetime.

### Benchmark evidence

The Python driver creates its executor before the measured clock, performs a
configurable warm-up, supports repeated samples and duration-based runs, and
records p99.9, standard deviation, sample count, connection count, and each
repetition. A pool of channels enables 1/4/16 connection sweeps without
changing per-channel HTTP/2 multiplexing.

The cross-runtime harness defaults to a longer release lane while retaining a
short smoke configuration for local iteration. Performance budgets are
relative to comparison runtimes and are evaluated only within the same
receipt. Native Linux amd64 and arm64 remain required before marketing or
release promotion.

## Correctness invariants

- Exactly one thread owns and mutates each nghttp2 session.
- A `ServerStream` cannot be freed while a handler job may reference it.
- Each scheduled unary job publishes exactly one completion notification.
- Reset/cancelled streams never submit a late response.
- Queue and worker counts stay within `ServerOptions` bounds.
- Request and response buffers have one explicit owner at every transition.
- Compression and message-size limits apply before unbounded allocation.
- Canonical gRPC status remains in trailing metadata.

## Acceptance

- Focused deterministic tests prove socket configuration, one flush/write,
  constant-time callback lookup, concurrent unary execution, reset/teardown
  lifetime, queue bounds, and transferred response ownership.
- `zig build test` passes under the Testing v2 runner and its suite receipt is
  complete with equal discovered/executed counts, zero pending tests, zero
  leaks, and zero logged errors.
- Existing external/official/Connect interop gates remain green.
- A short benchmark smoke test produces the upgraded receipt schema.
- A release benchmark records native Linux evidence before any performance
  claim is changed.

## Communication and promotion

The implementation handoff updates the ZigEffect marketing page, repository
README, gRPC package README, Cloud Run guide, root agent guidance, and both
repository-owned `zigeffect-development` skill copies from the same benchmark
record.

The July ARM64 Docker schema-v2 run may be described as an optimization
diagnostic: 11,792 RPC/s, 2.42 ms p50, 6.06 ms p99, and 7.0 measured server
allocations per RPC for ZigEffect; 96.6% of grpc-go throughput in that receipt;
and 13.4% higher throughput than Tonic in that receipt. It must not be called a
release, native-Linux, Cloud Run, or production-verified result. Durable release
promotion still requires a checked-in schema-v2 receipt produced from committed
source on native Linux amd64 and arm64, plus the existing 24-hour and deployed
GCP gates.
