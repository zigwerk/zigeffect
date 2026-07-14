#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/../../.." && pwd)"
python="${1:-python3}"
calls="${GRPC_BENCH_CALLS:-10000}"
workers="${GRPC_BENCH_WORKERS:-32}"
handler_workers="${GRPC_BENCH_HANDLER_WORKERS:-8}"
connections="${GRPC_BENCH_CONNECTIONS:-1 4 16}"
warmup_calls="${GRPC_BENCH_WARMUP_CALLS:-512}"
warmup_seconds="${GRPC_BENCH_WARMUP_SECONDS:-2}"
repetitions="${GRPC_BENCH_REPETITIONS:-5}"
duration_seconds="${GRPC_BENCH_DURATION_SECONDS:-0}"
stream_messages="${GRPC_BENCH_STREAM_MESSAGES:-8}"
shapes="${GRPC_BENCH_SHAPES:-unary,client_streaming,server_streaming,bidirectional_streaming}"
sizes="${GRPC_BENCH_MESSAGE_SIZES:-0 1024 65536}"
enforce_budgets="${GRPC_BENCH_ENFORCE_BUDGETS:-0}"
receipt="${GRPC_BENCH_RECEIPT:-/tmp/zigeffect-grpc-benchmarks.json}"
work="$(mktemp -d)"
containers=()

cleanup() {
  for container in "${containers[@]:-}"; do docker rm -f "$container" >/dev/null 2>&1 || true; done
  rm -rf "$work"
}
trap cleanup EXIT

targets=(zig grpc-go tonic grpc-cpp)
dockerfiles=(Dockerfile.zig Dockerfile.go Dockerfile.tonic Dockerfile.cpp)

for index in "${!targets[@]}"; do
  target="${targets[$index]}"
  image="zigeffect-grpc-benchmark-${target}:local"
  docker build --progress=plain \
    -f "$repo_root/packages/zigeffect-grpc/benchmarks/${dockerfiles[$index]}" \
    -t "$image" "$repo_root"
  for size in $sizes; do
    for connection_count in $connections; do
      container="zigeffect-grpc-benchmark-${target}-${size}-${connection_count}-$$"
      port=$((46000 + (($$ + index * 101 + size + connection_count * 17) % 1500)))
      containers+=("$container")
      docker run --name "$container" -d -e PORT=8080 -e HANDLER_WORKERS="$handler_workers" -p "127.0.0.1:${port}:8080" "$image" >/dev/null
      "$python" "$repo_root/packages/zigeffect-grpc/benchmarks/driver.py" \
        --target "$target" \
        --address "127.0.0.1:${port}" \
        --container "$container" \
        --calls "$calls" \
        --workers "$workers" \
        --connections "$connection_count" \
        --warmup-calls "$warmup_calls" \
        --warmup-seconds "$warmup_seconds" \
        --repetitions "$repetitions" \
        --duration-seconds "$duration_seconds" \
        --stream-messages "$stream_messages" \
        --shapes "$shapes" \
        --payload-size "$size" \
        --output "$work/${target}-${size}-${connection_count}.json"
      docker rm -f "$container" >/dev/null
      containers=("${containers[@]:0:${#containers[@]}-1}")
    done
  done
done

"$python" - "$work" "$receipt" "$repo_root" "$sizes" "$connections" "$enforce_budgets" <<'PY'
import glob
import hashlib
import json
import os
import platform
import re
import sys

work, receipt_path, repo_root, sizes_text, connections_text, enforce_text = sys.argv[1:]
results = []
for path in sorted(glob.glob(os.path.join(work, "*.json"))):
    with open(path, encoding="utf-8") as source:
        results.append(json.load(source))
expected = 4 * len(sizes_text.split()) * len(connections_text.split())
if len(results) != expected or any(not result.get("complete") for result in results):
    raise SystemExit("all runtimes, message sizes, and connection sweeps are required")
hasher = hashlib.sha256()
for relative in (
    "packages/zigeffect-grpc/src",
    "packages/zigeffect-grpc/benchmarks",
    "packages/zigeffect-grpc/build.zig",
    "packages/zigeffect-grpc/build.zig.zon",
):
    path = os.path.join(repo_root, relative)
    files = [path] if os.path.isfile(path) else sorted(
        candidate for candidate in glob.glob(os.path.join(path, "**"), recursive=True)
        if os.path.isfile(candidate)
    )
    for candidate in files:
        hasher.update(os.path.relpath(candidate, repo_root).encode())
        with open(candidate, "rb") as source:
            content = source.read()
        if os.path.relpath(candidate, repo_root) == "packages/zigeffect-grpc/src/root.zig":
            content = re.sub(
                rb'\.content_sha256\s*=\s*"sha256:[0-9a-f]{64}"',
                b'.content_sha256 = "sha256:' + (b"0" * 64) + b'"',
                content,
            )
        hasher.update(content)
by_key = {}
for target in results:
    for result in target["results"]:
        key = (
            target["target"],
            result["request_payload_bytes"],
            result["connections"],
            result["shape"],
        )
        by_key[key] = result

budget_checks = []
for key, zig in sorted(by_key.items()):
    target, payload, connection_count, shape = key
    if target != "zig":
        continue
    comparators = [
        by_key[(candidate, payload, connection_count, shape)]
        for candidate in ("grpc-go", "tonic")
    ]
    best_throughput = max(item["throughput_calls_per_second"] for item in comparators)
    best_p99 = min(item["latency_ms"]["p99"] for item in comparators)
    throughput_ratio = zig["throughput_calls_per_second"] / best_throughput
    p99_ratio = zig["latency_ms"]["p99"] / best_p99 if best_p99 else 0
    passed = throughput_ratio >= 0.90 and p99_ratio <= 1.50
    budget_checks.append({
        "shape": shape,
        "request_payload_bytes": payload,
        "connections": connection_count,
        "minimum_throughput_ratio": 0.90,
        "observed_throughput_ratio": throughput_ratio,
        "maximum_p99_ratio": 1.50,
        "observed_p99_ratio": p99_ratio,
        "status": "passed" if passed else "failed",
    })

budget_status = "passed" if all(check["status"] == "passed" for check in budget_checks) else "failed"
enforced = enforce_text == "1"
receipt = {
    "schema": "zigeffect.grpc-differential-benchmarks",
    "version": 2,
    "status": "failed" if enforced and budget_status == "failed" else "passed",
    "complete": True,
    "source_sha256": hasher.hexdigest(),
    "host": {"system": platform.system(), "machine": platform.machine()},
    "methodology": {
        "transport": "plaintext HTTP/2 loopback through Docker port forwarding",
        "latency": "end-to-end client-observed per RPC",
        "cpu": "server cgroup usage_usec delta",
        "memory": "server cgroup current and peak bytes",
        "allocations": "runtime-instrumented server allocator delta",
        "source_binding": "implementation bytes with only the embedded conformance receipt digest normalized",
        "warmup": "configured warm-up calls complete before cgroup snapshots and measured intervals",
        "executor": "client executor construction and teardown are excluded from measured intervals",
        "statistics": "aggregate and per-repetition throughput plus p50/p95/p99/p99.9/max/mean/standard-deviation",
    },
    "budgets": {
        "enforced": enforced,
        "status": budget_status,
        "checks": budget_checks,
    },
    "targets": results,
}
with open(receipt_path, "w", encoding="utf-8") as output:
    json.dump(receipt, output, sort_keys=True)
    output.write("\n")
print(receipt_path)
if enforced and budget_status == "failed":
    raise SystemExit("ZigEffect gRPC performance budget failed")
PY

trap - EXIT
cleanup
