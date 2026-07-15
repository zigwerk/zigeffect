# Differential benchmarks

This harness compares ZigEffect gRPC with pinned grpc-go, tonic, and gRPC C++
servers that implement the same Protobuf contract. It runs unary,
client-streaming, server-streaming, and bidirectional-streaming calls and
reports p50/p95/p99 latency, throughput, server cgroup CPU, cgroup memory, and
instrumented allocator counts/bytes. All targets run in fresh local containers
through the same Python gRPC load driver.

```sh
GRPC_BENCH_CALLS=10000 \
GRPC_BENCH_WORKERS=32 \
GRPC_BENCH_HANDLER_WORKERS=8 \
GRPC_BENCH_CONNECTIONS="1 4 16" \
GRPC_BENCH_WARMUP_CALLS=512 \
GRPC_BENCH_WARMUP_SECONDS=2 \
GRPC_BENCH_REPETITIONS=5 \
GRPC_BENCH_SHAPES="unary,client_streaming,server_streaming,bidirectional_streaming" \
GRPC_BENCH_MESSAGE_SIZES="0 1024 65536" \
GRPC_BENCH_RECEIPT=/tmp/zigeffect-grpc-benchmarks.json \
benchmarks/run_benchmarks.sh /path/to/python-with-grpcio
```

The output is evidence, not a hard-coded performance claim. Compare results
only within one receipt: container runtime, host load, architecture, compiler,
and library versions affect the measurements.

The schema-v2 receipt includes every repetition, p99.9, mean and standard
deviation, sample counts, connection counts, warm-up configuration, and a
same-receipt budget against the better of grpc-go and Tonic. Set
`GRPC_BENCH_ENFORCE_BUDGETS=1` only in a qualification lane where a failed
relative budget should fail the command.

See `PERFORMANCE.md` for the profile captures, the optimizations they justified,
and before/after diagnostic measurements.
