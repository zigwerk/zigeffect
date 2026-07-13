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

Every changed primitive has a deterministic regression test. TLS contexts and
message-frame storage were not pooled speculatively: the profile did not
identify them as dominant costs, and extending their lifetime would increase
credential-rotation and ownership risk. They remain candidates for a future
profile if workload evidence changes.

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
