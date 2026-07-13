# Differential benchmarks

This harness compares ZigEffect gRPC with pinned grpc-go, tonic, and gRPC C++
servers that implement the same Protobuf contract. It runs unary,
client-streaming, server-streaming, and bidirectional-streaming calls and
reports p50/p95/p99 latency, throughput, server cgroup CPU, cgroup memory, and
instrumented allocator counts/bytes. All targets run in fresh local containers
through the same Python gRPC load driver.

```sh
GRPC_BENCH_CALLS=400 \
GRPC_BENCH_WORKERS=32 \
GRPC_BENCH_MESSAGE_SIZES="0 1024 65536" \
GRPC_BENCH_RECEIPT=/tmp/zigeffect-grpc-benchmarks.json \
benchmarks/run_benchmarks.sh /path/to/python-with-grpcio
```

The output is evidence, not a hard-coded performance claim. Compare results
only within one receipt: container runtime, host load, architecture, compiler,
and library versions affect the measurements.

See `PERFORMANCE.md` for the profile captures, the optimizations they justified,
and before/after diagnostic measurements.
