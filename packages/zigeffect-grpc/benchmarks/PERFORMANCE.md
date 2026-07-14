# Performance engineering record

This record explains the optimizations behind the current benchmark receipt.
It is not a promise of absolute throughput: compare runtimes only inside one
receipt, where architecture, container runtime, load, payload, and concurrency
are held constant.

## Profile-driven changes

Native macOS `sample` captures were taken around the mixed streaming workload
before and after the transport changes:

```sh
sample <benchmark-server-pid> 10 -file /tmp/zigeffect-grpc-before.sample
sample <benchmark-server-pid> 10 -file /tmp/zigeffect-grpc-after-wakeup.sample
```

The initial capture showed two dominant avoidable costs: a fixed two
millisecond active-stream poll and one operating-system thread per streaming
handler. The follow-up capture no longer showed the fixed poll. The resulting
changes are:

- a nonblocking self-pipe wakes nghttp2 when stream data or cancellation is
  available;
- a bounded executor reuses a fixed worker set for incremental handlers;
- the persistent client operation queue advances a FIFO head and compacts
  periodically instead of copying the remaining queue after every operation;
- persistent-channel pump ownership is handed off with an event and a wakeup
  pipe instead of millisecond polling;
- the server advertises 4 MiB stream and 16 MiB connection flow-control
  windows, avoiding the 64 KiB HTTP/2 throughput cliff.

The July 2026 unary pass then removed costs that the original 400-call receipt
could not isolate reliably:

- TCP_NODELAY is applied to client and accepted server sockets;
- nghttp2 output from one flush cycle is coalesced into one logical write;
- callback stream lookup uses nghttp2 stream user data instead of a linear
  scan;
- unary handlers run concurrently on the bounded shared executor while the
  connection thread remains the only nghttp2 owner;
- identity request payloads are borrowed, typed response payloads transfer
  ownership into the transport frame, and declared message lengths reserve
  exact request capacity;
- common request header values use bounded inline storage, common response
  headers/trailers use fixed fields, and route dispatch uses a hash index.

Every changed primitive has a deterministic regression test. TLS contexts and
message-frame storage were not pooled speculatively: the profile did not
identify them as dominant costs, and extending their lifetime would increase
credential-rotation and ownership risk. They remain candidates for a future
profile if workload evidence changes.

## July 2026 diagnostic unary result

After a Linux 4/8/16/32/64 handler-worker sweep, eight workers became the
configurable default. The common 1 KiB unary path fell from 43.1 measured
allocations per RPC in the v1 receipt to 7.0 in a 50,000-call schema-v2
diagnostic run.

On the same ARM64 Docker Desktop host, with 32 client workers, one persistent
HTTP/2 connection, 512 warm-up calls plus two warm-up seconds, and five 10,000
call repetitions, the diagnostic result was:

| Runtime | Throughput | p50 | p99 |
| --- | ---: | ---: | ---: |
| grpc-go | 12,206 RPC/s | 2.35 ms | 5.67 ms |
| ZigEffect | 11,792 RPC/s | 2.42 ms | 6.06 ms |
| Tonic | 10,403 RPC/s | 2.69 ms | 8.54 ms |
| gRPC C++ | 10,394 RPC/s | 2.82 ms | 6.33 ms |

This same-receipt result passed the enforced unary budget at 96.6% of
grpc-go's throughput and 1.07x its p99, while exceeding Tonic throughput by
13.4% with a lower p99 in that run. It remains an uncommitted diagnostic
measurement, not a release or marketing receipt. Host contention affects tail
latency, so only a schema-v2 run from committed source on native Linux amd64
and arm64 may replace the checked-in v1 receipt or support a durable
comparative claim.

## Observed effect

On the same ARM64 Docker Desktop harness, the 64 KiB four-shape throughput
(calls/second) changed as follows. These runs are diagnostic samples, not the
cross-runtime release receipt.

| Shape | Before | After |
| --- | ---: | ---: |
| Unary | 133.0 | 1,050.2 |
| Client streaming | 35.8 | 165.0 |
| Server streaming | 283.6 | 1,210.0 |
| Bidirectional streaming | 32.7 | 202.0 |

The content-bound full matrix is
`conformance/benchmarks-linux-arm64.v1.json`. It covers grpc-go, tonic, gRPC
C++, and ZigEffect; all four RPC shapes; 0 byte, 1 KiB, and 64 KiB payloads;
latency percentiles, throughput, cgroup CPU and memory, and server allocator
statistics.
